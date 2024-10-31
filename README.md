# 🎉 Project Title

## 🚀 Overview

This project demonstrates a microservices-based application deployment on a local Kubernetes environment using **KIND** (Kubernetes in Docker). It includes multiple applications such as **SockShop**, **Grafana Dashboard**, and **Truedesk**, along with observability tools like **Loki** and **Grafana**. Deployment and setup scripts are managed using a **Makefile** for ease of use.

---

## 📁 Project Structure

```plaintext
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

📋 Prerequisites
Before you begin, ensure you have the following installed:

Docker 🐳
KIND 🌟
kubectl 🔧
Make sure that both KIND and kubectl are in your system's PATH.