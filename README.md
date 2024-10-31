# 🎉 Kubernetes Microservices Deployment with Observability

## 🚀 Overview

This project demonstrates a microservices-based application deployment on a local Kubernetes environment using **KIND** (Kubernetes in Docker). It includes multiple applications such as **SockShop**, **Grafana Dashboard**, and **Truedesk**, along with observability tools like **Loki** and **Grafana**. Deployment and setup scripts are managed using a **Makefile** for ease of use.

---

## 📁 Project Structure
``` plaintext
.
├── applications                # Application Helm charts and deployment manifests
│   ├── grafana-dashboard       # Grafana dashboards and configs
│   ├── log-application         # Logging application deployment
│   ├── sockshop                # Sockshop microservices application
│   └── truedesk                # Truedesk application resources
├── apps                        # Pre-configured app files for Grafana, Istio, Loki, Prometheus, SockShop
├── cluster                     # KIND cluster configuration and ArgoCD values
├── kargotest                   # Test resources for Kargo setup
├── Makefile                    # Build and deployment commands
└── README.md                   # Project documentation
```

## 📋 Prerequisites
Before you begin, ensure you have the following installed:

- Docker 🐳
- KIND 🌟
- kubectl 🔧
Make sure that both KIND and kubectl are in your system's PATH.

## 🛠️ Setup Instructions
1. Create a KIND Cluster
To create the KIND cluster as defined in cluster/cluster.yaml, run:

  ```bash
  make create-cluster
  ```
This command creates a KIND cluster named demo-stuff (default name) using the specified configuration.

2. Install Ingress Controller
To deploy the Ingress-NGINX controller in the ingress-nginx namespace, execute:

```bash
make install-ingress
```
This command applies the official Ingress-NGINX manifest for KIND.

3. Install ArgoCD
To install ArgoCD using Helm with custom values from cluster/argo-values.yaml, run:

```bash
make install-argocd
```
ArgoCD will be installed in the argocd namespace, enabling GitOps-style application management.

4. Delete KIND Cluster
To delete the KIND cluster and all associated resources, run:

```bash
make delete-cluster
```
This command removes the cluster named demo-stuff from your local environment.

5. Reset: Clean Resources and Cluster
To delete all created resources and then remove the KIND cluster, use:

```bash
make reset
```
This command deletes Kubernetes resources and then removes the KIND cluster.

## 🛠️ Application Deployment
The applications directory contains multiple applications, including:

- **Grafana Dashboard:** Custom Grafana dashboard configurations.
- **Log Application:** A sample application to test Loki logging.
- **SockShop:** A microservices-based application mimicking an online shop.
- **Truedesk:** A support desk application with MongoDB and Elasticsearch resources.
You can find the complete project in the repository: [argocd-demo.git](https://github.com/argadepp/argocd-demo.git)
## 📦 Applications
🌟 Grafana Dashboard
The Grafana dashboard configuration can be found in applications/grafana-dashboard, including sample JSON dashboards and monitoring templates.

## 📜 Log Application
A sample log application is available in applications/log-application to test with Loki.

## 🛍️ SockShop Application
The SockShop application is configured as a Helm chart in applications/sockshop. It includes services like carts, orders, and user management.

## 💼 Truedesk
The Truedesk application is available in applications/truedesk, with supporting Elasticsearch and MongoDB stateful resources.

## 📊 Observability Stack
This project includes a powerful observability stack comprising:

- Loki: A logging backend for monitoring logs. 📝
- Grafana: A visualization tool with preconfigured dashboards. 📈
- Prometheus: For metric collection and alerting. 🚨
These components are configured in the apps/ directory with ready-to-apply manifests for observability setup.

## 🤝 Contributing
To contribute to this project, please follow these steps:

Fork the repository.
Create a new branch for your feature or bugfix.
Make your changes and commit them.
Submit a pull request for review.
## 📝 License
This project is licensed under the MIT License.
