# Kubernetes GitOps and Observability Lab

A local Kubernetes lab for experimenting with Argo CD, ApplicationSets, Helm, observability, service meshes, and workload deployment workflows. The Makefile supports **Kind** (default) and **k3d** while retaining separate targets for optional EKS operations.

## Prerequisites

- Docker
- `kubectl` and `helm`
- Either `kind` or `k3d` (install both if you want to switch between providers)
- `make`

## Choose a local cluster provider

Kind remains the default to preserve existing usage:

```bash
# Create the existing Kind cluster (uses cluster/cluster.yaml)
make create-cluster

# Create a k3d cluster with 1 server and 2 agents
make create-cluster PROVIDER=k3d

# Use a different cluster name
make create-cluster PROVIDER=k3d CLUSTER_NAME=argo-lab

# Override published ports (defaults: HTTP 8081, HTTPS 8444)
make create-cluster PROVIDER=k3d K3D_HTTP_PORT=80 K3D_HTTPS_PORT=443

# Inspect the selected local cluster/context
make cluster-status PROVIDER=kind
make cluster-status PROVIDER=k3d
make show-context PROVIDER=k3d

# Delete only the selected cluster
make delete-cluster PROVIDER=kind
make delete-cluster PROVIDER=k3d
```

**Important:** use the same `PROVIDER` and `CLUSTER_NAME` values for subsequent Make targets. For example, `make install-argocd PROVIDER=k3d` targets context `k3d-demo-stuff`. The default k3d port mappings use `http://localhost:8081` and `https://localhost:8444`; ports can be overridden as shown above.

## Install Argo CD

The Makefile pins the Argo CD Helm chart to `10.10.5` and the Argo CD application image to `v3.5.6` by default. These are separate version numbers: the former is the chart package, the latter is the Argo CD application version. Override them when intentionally testing another release.

```bash
make install-argocd PROVIDER=kind
# or
make install-argocd PROVIDER=k3d

# Override the pinned versions when needed
make install-argocd PROVIDER=k3d ARGOCD_CHART_VERSION=10.10.5 ARGOCD_VERSION=v3.5.6

# Expose Argo CD locally and open http://localhost:8080
make argocd-port-forward PROVIDER=k3d
```

For Kind, the existing values file enables the configured ingress. For k3d, the Makefile disables Argo CD ingress because k3d provides Traefik by default while the current values file declares an NGINX ingress class. Port-forwarding is the simplest provider-neutral way to access Argo CD in the lab.

## Ingress behavior

- **Kind:** `make install-ingress PROVIDER=kind` applies the ingress-nginx manifest for Kind.
- **k3d:** `make install-ingress PROVIDER=k3d` verifies the bundled Traefik deployment instead of installing a Kind-specific controller.

The legacy `ingress-patch` target is Kind-specific and is guarded accordingly.

## AWS IAM role mapping without committed account IDs

The `eks-access` target no longer contains a hard-coded AWS account number. Supply the full IAM role ARN when invoking it:

```bash
make eks-access AWS_ROLE_ARN=arn:aws:iam::<account-id>:role/<role-name>
```

Replace the placeholders with the role ARN for your AWS environment. Avoid committing account-specific identifiers or credentials when they are not needed in source control.

## Existing capabilities

The repository includes application manifests, Helm-based Argo CD installation, monitoring Application resources, Prometheus, Istio, k6 test resources, Kafka, and Kargo/ApplicationSet experiments. Some targets are environment-specific: review their values, credentials, cluster context, and external hostnames before running them.

## Suggested learning path

1. Add drift detection and self-healing to a safe demo application.
2. Expand the existing ApplicationSet example to generate applications from Git directories or environments.
3. Test sync waves and health gates for ordered deployments.
4. Add Argo CD notifications and Prometheus/Grafana dashboards.
5. Add automated manifest validation and Makefile smoke checks.

## Repository layout

- `apps/` — Argo CD Application resources
- `applications/` — application manifests and charts
- `cluster/` — cluster and Helm values
- `kargotest/` — Kargo/ApplicationSet experiments
- `manifest/` — Kubernetes manifests
- `k6test/` — k6 load-testing resources
- `Makefile` — cluster and lab workflows

## Contributing

Create a feature branch, test the changes against the intended provider, and open a pull request. Do not commit real credentials or personal cluster configuration.
