#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -o xtrace

# This script is run once to setup Azure environment. What is created by this script can be re-used for multiple AKS and hosted clusters.

# The parent or top-level resource group name
PERSISTENT_RG_NAME=
PARENT_DNS_RG=

# Key vault name
KV_NAME=

# Azure account credentials
USER_ACCOUNT_ID=
OBJECT_ID=
APP_ID=

# External DNS record name
DNS_RECORD_NAME=ext-dns
# Base DNS zone name
PARENT_DNS_ZONE="xyz.com"
DNS_ZONE_NAME=${DNS_RECORD_NAME}".xyz.com"

# Test service principal name to use
TEST_SP_NAME=rj-hypershift-sp

LOCATION="eastus"
RESOURCE_PREFIX="test"

AKS_CP_MI_NAME="${RESOURCE_PREFIX}-aks-cp-mi"
AKS_KUBELET_MI_NAME="${RESOURCE_PREFIX}-aks-kubelet-mi"

# Generated credential file name
SP_AKS_CREDS="sp-aks-creds.json"

ACCOUNT_DETAILS=$(az account show --query '{subscriptionId: id, tenantId: tenantId}' -o json)
SUBSCRIPTION_ID=$(echo "$ACCOUNT_DETAILS" | jq -r '.subscriptionId')
TENANT_ID=$(echo "$ACCOUNT_DETAILS" | jq -r '.tenantId')

# Create a service principal
SP_DETAILS=$(az ad sp create-for-rbac --name "$TEST_SP_NAME" --role Contributor --scopes "/subscriptions/$SUBSCRIPTION_ID" -o json)
CLIENT_ID=$(echo "$SP_DETAILS" | jq -r '.appId')
CLIENT_SECRET=$(echo "$SP_DETAILS" | jq -r '.password')


cat <<EOF > $SP_AKS_CREDS
{
  "subscriptionId": "$SUBSCRIPTION_ID",
  "tenantId": "$TENANT_ID",
  "clientId": "$CLIENT_ID",
  "clientSecret": "$CLIENT_SECRET"
}
EOF

az identity create --name $AKS_CP_MI_NAME --resource-group $PERSISTENT_RG_NAME
az identity create --name $AKS_KUBELET_MI_NAME --resource-group $PERSISTENT_RG_NAME

az keyvault create --name $KV_NAME --resource-group $PERSISTENT_RG_NAME --location $LOCATION --enable-rbac-authorization
az role assignment create --assignee ${OBJECT_ID} --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${PERSISTENT_RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME} --role "Key Vault Administrator"
az role assignment create --assignee ${USER_ACCOUNT_ID} --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${PERSISTENT_RG_NAME}/providers/Microsoft.KeyVault/vaults/${KV_NAME} --role "Key Vault Administrator"

az network dns zone create --resource-group $PERSISTENT_RG_NAME --name $DNS_ZONE_NAME

# az network dns record-set ns delete --resource-group $PARENT_DNS_RG --zone-name $PARENT_DNS_ZONE --name $DNS_RECORD_NAME -y

name_servers=$(az network dns zone show --resource-group $PERSISTENT_RG_NAME --name $DNS_ZONE_NAME --query nameServers --output tsv)
ns_array=()
while IFS= read -r ns; do
    ns_array+=("$ns")
done <<< "$name_servers"

for ns in "${ns_array[@]}"; do
    az network dns record-set ns add-record --resource-group $PARENT_DNS_RG --zone-name $PARENT_DNS_ZONE --record-set-name $DNS_RECORD_NAME --nsdname "$ns"
done

EXTERNAL_DNS_SP_NAME="ext-dns-"${TEST_SP_NAME}
EXTERNAL_DNS_CREDS="ext-dns-creds.json"

DNS_SP=$(az ad sp create-for-rbac --name $EXTERNAL_DNS_SP_NAME)
EXTERNAL_DNS_SP_APP_ID=$(echo "$DNS_SP" | jq -r '.appId')
EXTERNAL_DNS_SP_PASSWORD=$(echo "$DNS_SP" | jq -r '.password')

DNS_ID=$(az network dns zone show --name ${DNS_ZONE_NAME} --resource-group ${PERSISTENT_RG_NAME} --query "id" --output tsv)
az role assignment create --role "Reader" --assignee "${EXTERNAL_DNS_SP_APP_ID}" --scope "${DNS_ID}"
az role assignment create --role "Contributor" --assignee "${EXTERNAL_DNS_SP_APP_ID}" --scope "${DNS_ID}"

cat <<-EOF > $EXTERNAL_DNS_CREDS
{
"tenantId": "$(az account show --query tenantId -o tsv)",
"subscriptionId": "$(az account show --query id -o tsv)",
"resourceGroup": "$PERSISTENT_RG_NAME",
"aadClientId": "$EXTERNAL_DNS_SP_APP_ID",
"aadClientSecret": "$EXTERNAL_DNS_SP_PASSWORD"
}
EOF