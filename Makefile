# Tool paths (override on the command line if needed)
KIND ?= kind
K3D ?= k3d
KUBECTL ?= kubectl
HELM ?= helm

# Local cluster provider: kind (default, backwards compatible) or k3d.
PROVIDER ?= kind
CLUSTER_NAME ?= demo-stuff
KIND_CONFIG ?= cluster/cluster.yaml
TRACE_KIND_CONFIG ?= cluster/trace-cluster.yaml

# k3d cluster settings. Ports default to 8081/8444 to avoid requiring root
# privileges or conflicting with services already listening on 80/443.
K3D_SERVERS ?= 1
K3D_AGENTS ?= 2
K3D_HTTP_PORT ?= 8081
K3D_HTTPS_PORT ?= 8444
PROM_INGRESS_CLASS ?= $(if $(filter k3d,$(PROVIDER)),traefik,nginx)

NAMESPACE ?= default
TARGET ?= utilities
K8S_DIR ?= k8s

ifeq ($(PROVIDER),kind)
LOCAL_CONTEXT ?= kind-$(CLUSTER_NAME)
else ifeq ($(PROVIDER),k3d)
LOCAL_CONTEXT ?= k3d-$(CLUSTER_NAME)
else
$(error Unsupported PROVIDER '$(PROVIDER)'. Choose PROVIDER=kind or PROVIDER=k3d.)
endif

LOCAL_KUBECTL = $(KUBECTL) --context $(LOCAL_CONTEXT)
LOCAL_HELM = $(HELM) --kube-context $(LOCAL_CONTEXT)

.PHONY: all
all: create-cluster

# Create a local cluster. Existing Kind behavior remains the default.
.PHONY: create-cluster
create-cluster:
	@case "$(PROVIDER)" in \
	  kind) command -v "$(KIND)" >/dev/null || { echo "ERROR: $(KIND) is not installed"; exit 1; }; \
	        "$(KIND)" create cluster --name "$(CLUSTER_NAME)" --config "$(KIND_CONFIG)" ;; \
	  k3d)  command -v "$(K3D)" >/dev/null || { echo "ERROR: $(K3D) is not installed"; exit 1; }; \
	        "$(K3D)" cluster create "$(CLUSTER_NAME)" --servers "$(K3D_SERVERS)" --agents "$(K3D_AGENTS)" \
	          --port "$(K3D_HTTP_PORT):80@loadbalancer" --port "$(K3D_HTTPS_PORT):443@loadbalancer" ;; \
	esac

.PHONY: cluster-status
cluster-status:
	$(LOCAL_KUBECTL) cluster-info
	$(LOCAL_KUBECTL) get nodes -o wide

.PHONY: show-context
show-context:
	@echo "Provider: $(PROVIDER)"
	@echo "Expected context: $(LOCAL_CONTEXT)"
	@$(KUBECTL) config get-contexts "$(LOCAL_CONTEXT)"

.PHONY: eks-cluster
eks-cluster:
	eksctl create cluster -f cluster/eksctl-cluster.yaml

.PHONY: eks-ingress
eks-ingress:
	helm install nginx-ingress ingress-nginx/ingress-nginx \
      --namespace ingress-nginx \
      --create-namespace \
      --set controller.service.type=LoadBalancer

eks-ebs-addon:
	eksctl create addon --name aws-ebs-csi-driver --cluster eks-monitoring-cluster --region ap-south-1 --force

eks-access:
	eksctl create iamidentitymapping \
      --region ap-south-1 \
      --cluster eks-monitoring-cluster \
      --arn arn:aws:iam::637423592422:role/$(USER) \
      --group system:masters \
      --username $(USER)

keycloak:
	$(LOCAL_HELM) upgrade --install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 17.0.0 -n keycloak --create-namespace -f cluster/keycloak-values.yaml

# Deploy InfluxDB to store k6 results.
deploy-influx:
	$(LOCAL_HELM) upgrade --install influxdb influxdata/influxdb --namespace utilities --create-namespace

deploy-test-app:
	$(LOCAL_KUBECTL) apply -f manifest/nginx-app.yaml

deploy-kafka:
	$(LOCAL_HELM) upgrade --install kafka bitnami/kafka -n kafka --create-namespace

install-k6-o:
	$(LOCAL_HELM) upgrade --install k6-operator grafana/k6-operator -n k6 --create-namespace

run-k6-test:
	$(LOCAL_KUBECTL) apply -f k6test/k6-test.yaml

# This specialised audit-tracing cluster uses Kind-specific configuration.
.PHONY: trace-cluster
trace-cluster:
	@test "$(PROVIDER)" = "kind" || { echo "ERROR: trace-cluster requires PROVIDER=kind because its configuration is Kind-specific"; exit 1; }
	$(KIND) create cluster --name $(CLUSTER_NAME) --config $(TRACE_KIND_CONFIG)

# Kind uses the ingress-nginx manifest intended for Kind. k3d ships with Traefik
# by default, so do not install the Kind-specific ingress controller there.
.PHONY: install-ingress
install-ingress:
ifeq ($(PROVIDER),kind)
	$(LOCAL_KUBECTL) apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
else
	@echo "k3d includes Traefik by default; skipping the Kind-specific ingress-nginx manifest."
	$(LOCAL_KUBECTL) -n kube-system get deploy traefik
endif

.PHONY: sleep1
sleep1:
	sleep 20

# Install Argo CD on the selected local cluster.
.PHONY: install-argocd
install-argocd:
	$(HELM) repo add argocd https://argoproj.github.io/argo-helm --force-update
ifeq ($(PROVIDER),kind)
	$(LOCAL_HELM) upgrade --install argocd argocd/argo-cd --version 8.2.0 -n argocd --create-namespace -f cluster/argo-values.yaml
else
	$(LOCAL_HELM) upgrade --install argocd argocd/argo-cd --version 8.2.0 -n argocd --create-namespace -f cluster/argo-values.yaml --set server.ingress.enabled=false
endif

.PHONY: sleep2
sleep2:
	sleep 60

.PHONY: install-apps
install-apps:
	$(LOCAL_KUBECTL) apply -f apps/monitoring-app.yaml
	$(LOCAL_KUBECTL) apply -f apps/grafana-ds-app.yaml

get-pass:
	$(LOCAL_KUBECTL) get secret -n utilities std-practice-grafana-operator-grafana-admin-credentials -o json | jq -r .data.GF_SECURITY_ADMIN_PASSWORD | base64 -d

# Legacy Kind-only ingress patch; the node selector is specific to the demo-stuff cluster.
.PHONY: ingress-patch
ingress-patch:
	@test "$(PROVIDER)" = "kind" || { echo "ERROR: ingress-patch is currently Kind-specific"; exit 1; }
	$(LOCAL_KUBECTL) patch deployment ingress-nginx-controller \
	-n ingress-nginx \
	--type='merge' \
	-p '{"spec":{"template":{"spec":{"nodeSelector":{"kubernetes.io/hostname":"$(CLUSTER_NAME)-control-plane"}}}}}'

install-prom:
	$(LOCAL_HELM) upgrade --install prometheus prometheus-community/prometheus \
	--namespace utilities --create-namespace \
	--set server.ingress.enabled=true \
	--set server.ingress.ingressClassName=$(PROM_INGRESS_CLASS) \
	--set server.ingress.hosts[0]="prom.devopspratik.tech" \
	--set server.ingress.paths[0]="/" \
	--set server.service.type=ClusterIP

install-istio:
	istioctl install -y --context $(LOCAL_CONTEXT)
	$(LOCAL_KUBECTL) apply -f manifest/gateway.yaml

.PHONY: delete-cluster
delete-cluster:
ifeq ($(PROVIDER),kind)
	$(KIND) delete cluster --name "$(CLUSTER_NAME)"
else
	$(K3D) cluster delete "$(CLUSTER_NAME)"
endif

.PHONY: reset
reset: delete-cluster

install-grafana-agent:
	$(LOCAL_KUBECTL) apply -f https://raw.githubusercontent.com/grafana/pdc-agent/main/production/kubernetes/pdc-agent-deployment.yaml

# Forward Argo CD to localhost:8080. Press Ctrl-C to stop.
.PHONY: argocd-port-forward
argocd-port-forward:
	$(LOCAL_KUBECTL) -n argocd port-forward svc/argocd-server 8080:80
