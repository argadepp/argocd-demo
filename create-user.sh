#!/bin/bash
user=$1
## create role with name
aws iam create-role --role-name $user --assume-role-policy-document file://manifest/trust-policy.yaml 

aws iam attach-role-policy --role-name $user --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

aws iam attach-role-policy --role-name $user --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

aws iam attach-role-policy --role-name $user --policy-arn arn:aws:iam::637423592422:policy/eks-role-policy

kubectl annotate serviceaccount $user -n utilities   eks.amazonaws.com/role-arn=arn:aws:iam::637423592422:role/$user

aws eks update-kubeconfig \
  --region ap-south-1 \
  --name eks-monitoring-cluster \
  --role-arn arn:aws:iam::637423592422:role/$user \
  --kubeconfig ~/.kube/$user
  
eksctl create iamidentitymapping \
--region ap-south-1 \
--cluster eks-monitoring-cluster \
--arn arn:aws:iam::637423592422:role/$user \
--group system:masters \
--username $user

export KUBECONFIG=~/.kube/$user