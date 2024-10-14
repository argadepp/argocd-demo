# Variables
KIND = kind
KUBECTL = kubectl
CLUSTER_NAME ?= demo-stuff
KIND_CONFIG = cluster/cluster.yaml
K8S_DIR = k8s
NAMESPACE = default

TARGET ?= utilities
# Default target
.PHONY: all
all: create-cluster

# Create kind cluster
.PHONY: create-cluster
create-cluster:
	$(KIND) create cluster --name $(CLUSTER_NAME) --config $(KIND_CONFIG)

#install ingress controller
ingress: deploy ingress controller
install-ingress:
	kubectl create namespace ingress-nginx
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

#install specific utility on cluster
install-argocd:
	helm repo add argocd https://argoproj.github.io/argo-helm
	helm upgrade -i argocd argocd/argo-cd --version 7.3.4 -n argocd --create-namespace -f cluster/argo-values.yaml
		
# Delete kind cluster
.PHONY: delete-cluster
delete-cluster:
	$(KIND) delete cluster --name $(CLUSTER_NAME)

# Delete all resources and cluster
.PHONY: reset
reset: clean delete-cluster
