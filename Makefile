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
sleep1:
	sleep 20
#install specific utility on cluster
install-argocd:
	helm repo add argocd https://argoproj.github.io/argo-helm
	helm upgrade -i argocd argocd/argo-cd --version 7.3.4 -n argocd --create-namespace -f cluster/argo-values.yaml
sleep2:
	sleep 60
install-apps:
	kubectl apply -f apps/monitoring-app.yaml
	kubectl apply -f apps/grafana-ds-app.yaml
get-pass:
	kubectl get secret -n utilities std-practice-grafana-operator-grafana-admin-credentials -o json | jq -r .data.GF_SECURITY_ADMIN_PASSWORD | base64 -d

#Delete kind cluster
.PHONY: delete-cluster
delete-cluster:
	$(KIND) delete cluster --name $(CLUSTER_NAME)

# Delete all resources and cluster
.PHONY: reset
reset: clean delete-cluster
