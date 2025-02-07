#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -o xtrace

# AKS cluster name
AKS_CLUSTER_NAME=
# The parent or top-level resource group name
PERSISTENT_RG_NAME=
# Key vault name
KV_NAME=

LOCATION="eastus"
RESOURCE_PREFIX="test"

AKS_CP_MI_NAME="${RESOURCE_PREFIX}-aks-cp-mi"
AKS_KUBELET_MI_NAME="${RESOURCE_PREFIX}-aks-kubelet-mi"

export AKS_CP_MI_ID=$(az identity show --name $AKS_CP_MI_NAME --resource-group $PERSISTENT_RG_NAME --query id -o tsv)
export AKS_KUBELET_MI_ID=$(az identity show --name $AKS_KUBELET_MI_NAME --resource-group $PERSISTENT_RG_NAME --query id -o tsv)

az aks create \
    --resource-group $PERSISTENT_RG_NAME \
    --name $AKS_CLUSTER_NAME \
    --node-count 3 \
    --generate-ssh-keys \
    --load-balancer-sku standard \
    --os-sku AzureLinux \
    --node-vm-size Standard_D4s_v4 \
    --enable-addons azure-keyvault-secrets-provider \
    --enable-fips-image \
    --enable-cluster-autoscaler \
    --min-count 2 \
    --max-count 6 \
    --enable-secret-rotation \
    --rotation-poll-interval 1m \
    --kubernetes-version 1.31.1 \
    --assign-identity $AKS_CP_MI_ID \
    --assign-kubelet-identity $AKS_KUBELET_MI_ID

az aks get-credentials --resource-group $PERSISTENT_RG_NAME --name $AKS_CLUSTER_NAME --overwrite-existing
export AZURE_KEY_VAULT_AUTHORIZED_USER_ID=$(az aks show -n $AKS_CLUSTER_NAME -g $PERSISTENT_RG_NAME | jq .addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -r)
export AZURE_KEY_VAULT_AUTHORIZED_OBJECT_ID=$(az aks show -n $AKS_CLUSTER_NAME -g $PERSISTENT_RG_NAME | jq .addonProfiles.azureKeyvaultSecretsProvider.identity.objectId -r)

az role assignment create --assignee-object-id $AZURE_KEY_VAULT_AUTHORIZED_OBJECT_ID --role "Key Vault Secrets User" --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${PERSISTENT_RG_NAME} --assignee-principal-type ServicePrincipal
