.PHONY: cluster-create cluster-delete

KIND_CLUSTER_NAME = gcsfileproxy-dev

cluster-create:
	@if ! kind get clusters | grep -qE "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Creating kind cluster..."; \
		kind create cluster --config kind-config.yaml --name $(KIND_CLUSTER_NAME); \
	else \
		echo "Kind cluster $(KIND_CLUSTER_NAME) already exists."; \
	fi

cluster-delete:
	@echo "Deleting kind cluster..."
	@kind delete cluster --name $(KIND_CLUSTER_NAME)
