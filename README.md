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

The Makefile installs the chart directly from the official OCI registry (`oci://ghcr.io/argoproj/argo-helm/argo-cd`) and pins the Argo CD Helm chart to `10.10.5` and the Argo CD application image to `v3.5.6` by default. Using the OCI registry avoids the GitHub release-assets download redirect that can fail if a signed download URL is stale or a proxy caches it. These are separate version numbers: the former is the chart package, the latter is the Argo CD application version. The chart's upstream `appVersion` is currently `v3.5.5`, so the Makefile explicitly overrides `global.image.tag` to use the newer Argo CD patch release. Test this combination in a disposable local cluster before applying it to an important environment, and follow Argo CD's upgrade guidance when crossing a major version.

```bash
make install-argocd PROVIDER=kind
# or
make install-argocd PROVIDER=k3d

# Override the pinned versions when needed
make install-argocd PROVIDER=k3d ARGOCD_CHART_VERSION=10.10.5 ARGOCD_VERSION=v3.5.6

# Check the generated Ingress object
make argocd-ingress-status PROVIDER=k3d CLUSTER_NAME=argocd-lab

# If using the configured host argo.devopspratik.tech, add this entry to your local hosts file:
# 127.0.0.1 argo.devopspratik.tech
# Then access http://argo.devopspratik.tech:8081

# Or expose Argo CD through a local port-forward at http://localhost:8080
make argocd-port-forward PROVIDER=k3d
```

The Makefile keeps ingress enabled for both providers and selects the matching controller class: NGINX for Kind, and Traefik for k3d. Check the resulting object with `make argocd-ingress-status PROVIDER=k3d CLUSTER_NAME=argocd-lab`. The `argocd-port-forward` target remains available as a fallback.

## Ingress behavior

- **Kind:** `make install-ingress PROVIDER=kind` applies the ingress-nginx manifest for Kind.
- **k3d:** `make install-ingress PROVIDER=k3d` verifies the bundled Traefik deployment instead of installing a Kind-specific controller.

The legacy `ingress-patch` target is Kind-specific and is guarded accordingly.

## Kargo credentials and AWS registry configuration

The Kargo manifest is now a template. Do **not** put a real GitHub token or account ID in the tracked file. First revoke the previously exposed GitHub token, then create a replacement with only the permissions the private repository needs. Supply the new value through the environment when deploying.

```bash
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export KARGO_GIT_USERNAME="your-github-username"
read -rsp "New GitHub token: " KARGO_GIT_PASSWORD; echo
export KARGO_GIT_PASSWORD
make apply-kargo-resources PROVIDER=k3d
unset KARGO_GIT_PASSWORD
```

This renders the manifest with `envsubst` and applies it to the provider-specific Kubernetes context. Install `envsubst` (usually included in the `gettext` package) first. Never paste the token into shell history or commit it to Git.

## AWS IAM role mapping without committed account IDs

The `eks-access` target no longer contains a hard-coded AWS account number. Supply the full IAM role ARN when invoking it:

```bash
make eks-access AWS_ROLE_ARN=arn:aws:iam::<account-id>:role/<role-name>
```

Replace the placeholders with the role ARN for your AWS environment. The ARN must include a real 12-digit AWS account ID at execution time; this change removes the ID from tracked source rather than creating an invalid ARN. The helper script also expects `AWS_ACCOUNT_ID`, `EKS_OIDC_PROVIDER_ID`, and `TRUSTED_DEPLOY_PRINCIPAL_ARN` in the environment. Avoid committing account-specific identifiers or credentials.

## Progressive Sync demo (dev → QA → production)

This lab demonstrates ApplicationSet `RollingSync`. The QA deployment is intentionally configured with a readiness probe that fails, so the production Application should remain unsynced until QA becomes Healthy. The feature is enabled in `cluster/argo-values.yaml` using `applicationsetcontroller.enable.progressive.syncs: "true"`.

### 1. Update the feature branch and install the configuration

Run these from your repository checkout. Review or commit any local work before switching branches.

```bash
git fetch origin
git checkout feat/k3d-provider-support
git pull --ff-only origin feat/k3d-provider-support

make install-argocd PROVIDER=k3d CLUSTER_NAME=argocd-lab

# Restart the controller so it reads the progressive-sync feature flag.
kubectl --context k3d-argocd-lab -n argocd rollout restart deployment/argocd-applicationset-controller
kubectl --context k3d-argocd-lab -n argocd rollout status deployment/argocd-applicationset-controller --timeout=180s

# Verify the feature flag appears in the command-parameters ConfigMap.
kubectl --context k3d-argocd-lab -n argocd get configmap argocd-cmd-params-cm -o yaml | grep -i progressive
```

### 2. Apply the ApplicationSet

```bash
kubectl --context k3d-argocd-lab apply -f kargotest/progressive-sync/applicationset.yaml

# Watch the three generated Applications
kubectl --context k3d-argocd-lab -n argocd get applications.argoproj.io -L demo-environment -w
```

The ApplicationSet creates `progressive-dev`, `progressive-qa`, and `progressive-prod`. Dev is synced first. Once Dev is Healthy, QA is synced. QA's intentionally bad readiness probe keeps it Progressing, so RollingSync should hold Production until QA is Healthy.

In a second terminal, inspect the deployments and Application status:

```bash
kubectl --context k3d-argocd-lab -n progressive-dev get deploy
kubectl --context k3d-argocd-lab -n progressive-qa get deploy
kubectl --context k3d-argocd-lab -n progressive-prod get deploy

kubectl --context k3d-argocd-lab -n argocd get application progressive-dev
kubectl --context k3d-argocd-lab -n argocd get application progressive-qa
kubectl --context k3d-argocd-lab -n argocd get application progressive-prod
```

### 3. Release the QA gate

After observing QA remain unhealthy and Production remain OutOfSync, fix the QA readiness probe from `/intentionally-not-ready` to `/`:

```bash
sed -i 's#/intentionally-not-ready#/#' progressive-sync-demo/qa/deployment.yaml
git add progressive-sync-demo/qa/deployment.yaml
git commit -m "fix: pass QA readiness gate in progressive sync demo"
git push origin feat/k3d-provider-support
```

Watch the Applications again. Once QA becomes Healthy, RollingSync should proceed to Production. If QA does not refresh after the commit, inspect the QA Application's Events and refresh it in the UI/CLI to check repository revision and sync status.

### 4. Cleanup

Delete the ApplicationSet first. Its generated Applications and their workload resources may also be removed depending on ApplicationSet deletion policy, so inspect the result before deleting namespaces.

```bash
kubectl --context k3d-argocd-lab delete -f kargotest/progressive-sync/applicationset.yaml
kubectl --context k3d-argocd-lab delete namespace progressive-dev progressive-qa progressive-prod
```

This is a local demonstration, not a production rollout policy. Run it in the disposable `argocd-lab` cluster, and do not point this test at production workloads.

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
