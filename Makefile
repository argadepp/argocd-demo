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
	#helm install keycloak codecentric/keycloak
	helm upgrade --install keycloak oci://registry-1.docker.io/bitnamicharts/keycloak --version 17.0.0 -n keycloak --create-namespace -f cluster/keycloak-values.yaml

#Deploy influxdb  to store k6 result
deploy-influx:
	helm install influxdb influxdata/influxdb --namespace utilities
# deploy test app for running k6 test		
deploy-test-app:
	kubectl apply -f manifest/nginx-app.yaml

deploy-kafka:
	helm upgrade -i kafka bitnami/kafka -n kafka --create-namespace

install-k6-o:
	helm upgrade --install k6-operator grafana/k6-operator -n k6 --create-namespace
# Run k6 test on deployed app
run-k6-test:
	kubectl apply -f k6test/k6-test.yaml

.PHONY: trace-cluster
trace-cluster:
	$(KIND) create cluster --name $(CLUSTER_NAME) --config cluster/trace-cluster.yaml
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
	helm upgrade -i argocd argocd/argo-cd --version 8.2.0 -n argocd --create-namespace -f cluster/argo-values.yaml
sleep2:
	sleep 60
install-apps:
	kubectl apply -f apps/monitoring-app.yaml
	kubectl apply -f apps/grafana-ds-app.yaml
get-pass:
	kubectl get secret -n utilities std-practice-grafana-operator-grafana-admin-credentials -o json | jq -r .data.GF_SECURITY_ADMIN_PASSWORD | base64 -d

ingress-patch:
	kubectl patch deployment ingress-nginx-controller \
	-n ingress-nginx \
	--type='merge' \
	-p '{
	  "spec": {
	    "template": {
	      "spec": {
	        "nodeSelector": {
	          "kubernetes.io/hostname": "demo-stuff-control-plane"
	        }
	      }
	    }
	  }
	}'

install-prom:
	helm upgrade --install prometheus prometheus-community/prometheus \
	--namespace utilities --create-namespace \
	--set server.ingress.enabled=true \
	--set server.ingress.ingressClassName=nginx \
	--set server.ingress.annotations."nginx\.ingress\.kubernetes\.io/rewrite-target"="/" \
	--set server.ingress.hosts[0]="prom.devopspratik.tech" \
	--set server.ingress.paths[0]="/" \
	--set server.service.type=ClusterIP

install-istio:
	istioctl install -y
	kubectl patch deployments.apps -n istio-system istio-ingressgateway -p '{"spec":{"template":{"spec":{"containers":[{"name":"istio-proxy","ports":[{"containerPort":8080,"hostPort":80},{"containerPort":8443,"hostPort":443}]}]}}}}'
	kubectl apply -f  manifest/gateway.yaml
#Delete kind cluster
.PHONY: delete-cluster
delete-cluster:
	$(KIND) delete cluster --name $(CLUSTER_NAME)

# Delete all resources and cluster
.PHONY: reset
reset: clean delete-cluster

install-grafana-agent:
	kubectl apply -f https://raw.githubusercontent.com/grafana/pdc-agent/main/production/kubernetes/pdc-agent-deployment.yaml

