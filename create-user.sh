#!/usr/bin/env bash
set -euo pipefail

user="${1:?Usage: $0 <role-and-service-account-name>}"

: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID to your 12-digit AWS account ID.}"
: "${EKS_OIDC_PROVIDER_ID:?Set EKS_OIDC_PROVIDER_ID to the OIDC provider ID (without the URL prefix).}"
: "${TRUSTED_DEPLOY_PRINCIPAL_ARN:?Set TRUSTED_DEPLOY_PRINCIPAL_ARN to the trusted AWS principal ARN.}"

AWS_REGION="${AWS_REGION:-ap-south-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-eks-monitoring-cluster}"
K8S_NAMESPACE="${K8S_NAMESPACE:-utilities}"
EKS_ROLE_POLICY_NAME="${EKS_ROLE_POLICY_NAME:-eks-role-policy}"

command -v envsubst >/dev/null 2>&1 || {
  echo "ERROR: envsubst is required (install the gettext package)." >&2
  exit 1
}

trust_policy="$(mktemp)"
trap 'rm -f "$trust_policy"' EXIT

export AWS_ACCOUNT_ID AWS_REGION EKS_OIDC_PROVIDER_ID K8S_NAMESPACE user TRUSTED_DEPLOY_PRINCIPAL_ARN
envsubst < manifest/trust-policy.yaml > "$trust_policy"

aws iam create-role \
  --role-name "$user" \
  --assume-role-policy-document "file://$trust_policy"

aws iam attach-role-policy \
  --role-name "$user" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy \
  --role-name "$user" \
  --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy \
  --role-name "$user" \
  --policy-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${EKS_ROLE_POLICY_NAME}"

aws eks update-kubeconfig \
  --region "$AWS_REGION" \
  --name "$EKS_CLUSTER_NAME" \
  --role-arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${user}" \
  --kubeconfig "$HOME/.kube/$user"

kubectl annotate serviceaccount "$user" \
  --namespace "$K8S_NAMESPACE" \
  --overwrite \
  "eks.amazonaws.com/role-arn=arn:aws:iam::${AWS_ACCOUNT_ID}:role/${user}"

eksctl create iamidentitymapping \
  --region "$AWS_REGION" \
  --cluster "$EKS_CLUSTER_NAME" \
  --arn "arn:aws:iam::${AWS_ACCOUNT_ID}:role/${user}" \
  --group system:masters \
  --username "$user"

echo "Kubeconfig written to: $HOME/.kube/$user"
echo "To use it in your current shell, run: export KUBECONFIG=\"$HOME/.kube/$user\""
