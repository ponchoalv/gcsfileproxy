.PHONY: setup dev test build deploy clean cluster-create cluster-delete tilt-up tilt-down

KIND_CLUSTER_NAME = gcsfileproxy-dev
DOCKER_REGISTRY ?= local
PROJECT_NAME = gcsfileproxy

# Help target
.PHONY: help
help: ## Show this help message
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

# Setup targets
.PHONY: setup
setup: cluster-create ## Create Kind cluster and setup environment
	@echo "Setting up development environment..."
	@kubectl cluster-info --context kind-$(KIND_CLUSTER_NAME)
	@echo "Environment setup complete!"

.PHONY: dev
dev: setup tilt-up ## Start development environment with Tilt
	@echo "Development environment started!"
	@echo "Tilt UI available at: http://localhost:10350"

# Build targets
.PHONY: build
build: build-proxy build-tests build-verification ## Build all Docker images
	@echo "All images built successfully!"

.PHONY: build-proxy
build-proxy: ## Build the main proxy Docker image
	@echo "Building proxy image..."
	docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME):latest .
	@if kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Loading image into Kind cluster..."; \
		kind load docker-image $(DOCKER_REGISTRY)/$(PROJECT_NAME):latest --name $(KIND_CLUSTER_NAME); \
	fi

.PHONY: build-tests
build-tests: ## Build the test Docker image
	@echo "Building test image..."
	docker build -t $(DOCKER_REGISTRY)/$(PROJECT_NAME)-tests:latest -f tests/Dockerfile .
	@if kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Loading test image into Kind cluster..."; \
		kind load docker-image $(DOCKER_REGISTRY)/$(PROJECT_NAME)-tests:latest --name $(KIND_CLUSTER_NAME); \
	fi

.PHONY: build-verification
build-verification: ## Build the verification service Docker image
	@echo "Building verification service image..."
	docker build -t $(DOCKER_REGISTRY)/verification-service:latest -f mocks/verification-service/Dockerfile mocks/verification-service/
	@if kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Loading verification image into Kind cluster..."; \
		kind load docker-image $(DOCKER_REGISTRY)/verification-service:latest --name $(KIND_CLUSTER_NAME); \
	fi

# Test targets
.PHONY: test
test: build-tests ## Run integration tests
	@echo "Running integration tests..."
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster not found. Setting up environment..."; \
		$(MAKE) setup; \
	fi
	@echo "Ensuring all services are deployed..."
	@$(MAKE) deploy
	@echo "Running test job..."
	@kubectl delete job integration-tests --ignore-not-found=true
	@kubectl apply -f kubernetes/tests-job.yaml
	@echo "Waiting for test job to complete..."
	@kubectl wait --for=condition=complete --timeout=300s job/integration-tests || \
		(echo "Test job failed or timed out. Checking logs:"; kubectl logs job/integration-tests; exit 1)
	@echo "Tests completed successfully!"
	@kubectl logs job/integration-tests

.PHONY: test-local
test-local: ## Run tests locally with npm
	@echo "Running tests locally..."
	npm test

# Deploy targets
.PHONY: deploy
deploy: ## Deploy to Kubernetes
	@echo "Deploying to Kubernetes..."
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster not found. Creating cluster first..."; \
		$(MAKE) setup; \
	fi
	@echo "Applying Kubernetes manifests..."
	@kubectl apply -f kubernetes/gcs-emulator-pvc.yaml
	@kubectl apply -f kubernetes/gcs-emulator-deployment.yaml
	@kubectl apply -f kubernetes/gcs-emulator-service.yaml
	@kubectl apply -f kubernetes/verification-deployment.yaml
	@kubectl apply -f kubernetes/verification-service.yaml
	@kubectl apply -f kubernetes/proxy-deployment.yaml
	@kubectl apply -f kubernetes/proxy-service.yaml
	@echo "Waiting for deployments to be ready..."
	@kubectl rollout status deployment/gcs-emulator
	@kubectl rollout status deployment/verification-service
	@kubectl rollout status deployment/gcsfileproxy
	@echo "All services deployed and ready!"

# Development helpers
.PHONY: logs
logs: ## Show logs from all services
	@echo "=== GCS Proxy Logs ==="
	@kubectl logs deployment/gcsfileproxy --tail=50 || echo "Proxy not deployed"
	@echo "=== GCS Emulator Logs ==="
	@kubectl logs deployment/gcs-emulator --tail=50 || echo "Emulator not deployed"
	@echo "=== Verification Service Logs ==="
	@kubectl logs deployment/verification-service --tail=50 || echo "Verification service not deployed"

.PHONY: status
status: ## Show status of all services
	@echo "=== Cluster Status ==="
	@kubectl cluster-info --context kind-$(KIND_CLUSTER_NAME) 2>/dev/null || echo "Cluster not running"
	@echo "=== Pod Status ==="
	@kubectl get pods
	@echo "=== Service Status ==="
	@kubectl get services
	@echo "=== Deployment Status ==="
	@kubectl get deployments

.PHONY: port-forward
port-forward: ## Forward ports for local access
	@echo "Setting up port forwarding..."
	@echo "Proxy will be available at http://localhost:3000"
	@echo "GCS Emulator will be available at http://localhost:4443"
	@echo "Press Ctrl+C to stop port forwarding"
	@kubectl port-forward service/gcsfileproxy 3000:80 &
	@kubectl port-forward service/gcs-emulator 4443:4443 &
	@wait

# Cluster management
.PHONY: cluster-create
cluster-create: ## Create Kind cluster
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Creating kind cluster..."; \
		kind create cluster --config kind-config.yaml --name $(KIND_CLUSTER_NAME); \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) already exists."; \
	fi

.PHONY: cluster-delete
cluster-delete: ## Delete Kind cluster
	@echo "Deleting kind cluster..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME)

.PHONY: tilt-up
tilt-up: cluster-create ## Start Tilt for development
	@echo "Checking if kind cluster exists..."
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster $(KIND_CLUSTER_NAME) does not exist. Creating it..."; \
		$(MAKE) cluster-create; \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) already exists."; \
	fi
	@echo "Starting Tilt..."
	@tilt up --port 10350

.PHONY: tilt-down
tilt-down: ## Stop Tilt
	@echo "Stopping Tilt..."
	@tilt down

# Clean up
.PHONY: clean
clean: tilt-down cluster-delete ## Clean up all resources
	@echo "Cleaning up Docker images..."
	@docker rmi $(DOCKER_REGISTRY)/$(PROJECT_NAME):latest 2>/dev/null || true
	@docker rmi $(DOCKER_REGISTRY)/$(PROJECT_NAME)-tests:latest 2>/dev/null || true
	@docker rmi $(DOCKER_REGISTRY)/verification-service:latest 2>/dev/null || true
	@echo "Cleanup complete!"

.PHONY: clean-images
clean-images: ## Clean up Docker images only
	@echo "Cleaning up Docker images..."
	@docker rmi $(DOCKER_REGISTRY)/$(PROJECT_NAME):latest 2>/dev/null || true
	@docker rmi $(DOCKER_REGISTRY)/$(PROJECT_NAME)-tests:latest 2>/dev/null || true
	@docker rmi $(DOCKER_REGISTRY)/verification-service:latest 2>/dev/null || true
	@echo "Docker images cleaned up!"

# Install dependencies
.PHONY: install
install: ## Install npm dependencies
	@echo "Installing npm dependencies..."
	@npm install

# Development setup
.PHONY: dev-setup
dev-setup: install setup build deploy ## Complete development setup from scratch
	@echo "Development environment is ready!"
	@echo "Run 'make port-forward' to access services locally"
	@echo "Run 'make test' to run integration tests"