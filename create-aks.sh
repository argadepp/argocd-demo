#!/bin/bash

export RANDOM_ID="$(openssl rand -hex 3)"
export MY_RESOURCE_GROUP_NAME="pratik-argade-rg$RANDOM_ID"
export REGION="westeurope"
export MY_AKS_CLUSTER_NAME="pratik-argade$RANDOM_ID"
export MY_DNS_LABEL="mydnslabel$RANDOM_ID"

az group create \
--name $MY_RESOURCE_GROUP_NAME \
--location $REGION

az aks create \
--resource-group $MY_RESOURCE_GROUP_NAME \
--name $MY_AKS_CLUSTER_NAME \
--enable-asm \
--node-count 2 \
--kubernetes-version 1.30 \
--revision asm-1-22

az aks get-credentials \
--resource-group $MY_RESOURCE_GROUP_NAME \
--name $MY_AKS_CLUSTER_NAME

az aks mesh enable-ingress-gateway \
--resource-group $MY_RESOURCE_GROUP_NAME \
--name $MY_AKS_CLUSTER_NAME \
--ingress-gateway-type external
