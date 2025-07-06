.PHONY: cluster-create cluster-delete

KIND_CLUSTER_NAME = gcsfileproxy-dev

.PHONY: create-cluster
cluster-create:
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Creating kind cluster..."; \
		kind create cluster --config kind-config.yaml --name $(KIND_CLUSTER_NAME); \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) already exists."; \
	fi

.PHONY: cluster-delete
cluster-delete: tilt-down
	@echo "Deleting kind cluster..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME)

.PHONY: tilt-up
tilt-up: create-cluster
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
tilt-down:
	@echo "Checking if kind cluster exists..."
	@if kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Kind cluster $(KIND_CLUSTER_NAME) exists. Deleting it..."; \
		$(MAKE) cluster-delete; \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) does not exist."; \
	fi
	@echo "Stopping Tilt..."
	@tilt down