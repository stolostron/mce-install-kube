#!/bin/bash

set -o nounset
set -o errexit
set -o xtrace

## Azure creds
AZURE_SUBSCRIPTION_ID=
AZURE_TENANT_ID=
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=

# Pull secret JSON content
OCP_PULL_SECRET=
BASE_DOMAIN=
EXT_DNS_RECORD_NAME=
RESOURCE_GROUP=

# Key vault name
KV_NAME=

KV_TENANT_ID=${AZURE_TENANT_ID}

# INPUT
HOSTING_CLUSTER_NAME=local_cluster
RELEASE_IMAGE="quay.io/openshift-release-dev/ocp-release:4.18.0-rc.4-multi"

CLUSTER_NAME_PREFIX="aro-test-"

# Generate a hosted cluster name
CLUSTER_NAME_1=${CLUSTER_NAME_PREFIX}$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
INFRA_ID_1=$(cat /dev/urandom | env LC_ALL=C tr -dc 'a-z0-9' | fold -w 32 | head -n 1)
INFRA_OUTPUT_FILE_1=${CLUSTER_NAME_1}-infraout


# Create service principals for managed identities
CLOUD_PROVIDER_SP_NAME="cloud-provider-"${CLUSTER_NAME_1}
CNCC_NAME="cncc-"${CLUSTER_NAME_1}
CONTROL_PLANE_SP_NAME="cpo-"${CLUSTER_NAME_1}
IMAGE_REGISTRY_SP_NAME="ciro-"${CLUSTER_NAME_1}
INGRESS_SP_NAME="ingress-"${CLUSTER_NAME_1}
AZURE_DISK_SP_NAME="azure-disk-"${CLUSTER_NAME_1}
AZURE_FILE_SP_NAME="azure-file-"${CLUSTER_NAME_1}
NODEPOOL_MGMT="nodepool-mgmt-"${CLUSTER_NAME_1}

DISK_SP_APP_ID=$(az ad sp create-for-rbac --name "${AZURE_DISK_SP_NAME}" --create-cert --cert "${AZURE_DISK_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
FILE_SP_APP_ID=$(az ad sp create-for-rbac --name "${AZURE_FILE_SP_NAME}" --create-cert --cert "${AZURE_FILE_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
NODEPOOL_MGMT_APP_ID=$(az ad sp create-for-rbac --name "${NODEPOOL_MGMT}" --create-cert --cert "${NODEPOOL_MGMT}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
CLOUD_PROVIDER_APP_ID=$(az ad sp create-for-rbac --name "${CLOUD_PROVIDER_SP_NAME}" --create-cert --cert "${CLOUD_PROVIDER_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
CNCC_APP_ID=$(az ad sp create-for-rbac --name "${CNCC_NAME}" --create-cert --cert "${CNCC_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
CONTROL_PLANE_APP_ID=$(az ad sp create-for-rbac --name "${CONTROL_PLANE_SP_NAME}" --create-cert --cert "${CONTROL_PLANE_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
IMAGE_REGISTRY_APP_ID=$(az ad sp create-for-rbac --name "${IMAGE_REGISTRY_SP_NAME}" --create-cert --cert "${IMAGE_REGISTRY_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')
INGRESS_APP_ID=$(az ad sp create-for-rbac --name "${INGRESS_SP_NAME}" --create-cert --cert "${INGRESS_SP_NAME}" --keyvault ${KV_NAME} --output json --only-show-errors | jq '.appId' | sed 's/"//g')


SP_OUTPUT_FILE="sp-output-file.json"

cat <<EOF > $SP_OUTPUT_FILE
{
    "cloudProvider": {
        "certificateName": "${CLOUD_PROVIDER_SP_NAME}",
        "clientID": "${CLOUD_PROVIDER_APP_ID}"
    },
    "controlPlaneOperator": {
        "certificateName": "${CONTROL_PLANE_SP_NAME}",
        "clientID": "${CONTROL_PLANE_APP_ID}"
    },
    "disk": {
        "certificateName": "${AZURE_DISK_SP_NAME}",
        "clientID": "${DISK_SP_APP_ID}"
    },
    "file": {
        "certificateName": "${AZURE_FILE_SP_NAME}",
        "clientID": "${FILE_SP_APP_ID}"
    },
    "imageRegistry": {
        "certificateName": "${IMAGE_REGISTRY_SP_NAME}",
        "clientID": "${IMAGE_REGISTRY_APP_ID}"
    },
    "ingress": {
        "certificateName": "${INGRESS_SP_NAME}",
        "clientID": "${INGRESS_APP_ID}"
    },
    "network": {
        "certificateName": "${CNCC_NAME}",
        "clientID": "${CNCC_APP_ID}"
    },
    "nodePoolManagement": {
        "certificateName": "${NODEPOOL_MGMT}",
        "clientID": "${NODEPOOL_MGMT_APP_ID}"
    },
    "managedIdentitiesKeyVault": {
        "name": "${KV_NAME}",
        "tenantID": "${KV_TENANT_ID}"
    }
}
EOF

SP_AKS_CREDS="sp-aks-creds.json"

cat <<EOF > $SP_AKS_CREDS
{
  "subscriptionId": "$AZURE_SUBSCRIPTION_ID",
  "tenantId": "$AZURE_TENANT_ID",
  "clientId": "$AZURE_CLIENT_ID",
  "clientSecret": "$AZURE_CLIENT_SECRET"
}
EOF


# Create infrastructure resources for the hosted cluster
/Users/rj/go/src/github.com/openshift/hypershift/bin/hypershift create infra azure \
--azure-creds $SP_AKS_CREDS \
--base-domain $BASE_DOMAIN \
--name $CLUSTER_NAME_1 \
--output-file $INFRA_OUTPUT_FILE_1 \
--resource-group-name $RESOURCE_GROUP \
--infra-id $INFRA_ID_1

# Make a copy of the template hosted cluster creation manifestwork YAML
cp ./resources/hosted_cluster_manifestwork.yaml ./hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to copy hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__INFRA_ID__|${INFRA_ID_1}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __INFRA_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__HOSTING_CLUSTER_NAME__|${HOSTING_CLUSTER_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __HOSTING_CLUSTER_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CLUSTER_NAME__|${CLUSTER_NAME_1}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CLUSTER_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__OCP_PULL_SECRET__|${OCP_PULL_SECRET}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __OCP_PULL_SECRET__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

# Create ssh keys
ssh-keygen -t rsa -b 4096 -f ssh-privatekey -q -N "" <<< y
if [ $? -ne 0 ]; then
  echo "failed to generate ssh keys"
  exit 1
fi

PRIVATE_KEY=$(base64 -i ssh-privatekey -w 0)
PUBLIC_KEY=$(base64 -i ssh-privatekey.pub -w 0)

BASE64_AZURE_CLIENT_ID=$(echo $AZURE_CLIENT_ID | base64)
BASE64_AZURE_CLIENT_SECRET=$(echo $AZURE_CLIENT_SECRET | base64)
BASE64_AZURE_SUBSCRIPTION_ID=$(echo $AZURE_SUBSCRIPTION_ID | base64)
BASE64_AZURE_TENANT_ID=$(echo $AZURE_TENANT_ID | base64)

sed -i -e "s|__PRIVATE_KEY__|${PRIVATE_KEY}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __PRIVATE_KEY__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__PUBLIC_KEY__|${PUBLIC_KEY}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __PUBLIC_KEY__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_CLIENT_ID__|${BASE64_AZURE_CLIENT_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_CLIENT_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_CLIENT_SECRET__|${BASE64_AZURE_CLIENT_SECRET}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_CLIENT_SECRET__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_SUBSCRIPTION_ID_BASE64__|${BASE64_AZURE_SUBSCRIPTION_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_SUBSCRIPTION_ID_BASE64__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_TENANT_ID__|${BASE64_AZURE_TENANT_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_TENANT_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CLOUD_PROVIDER_SP_NAME__|${CLOUD_PROVIDER_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CLOUD_PROVIDER_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CLOUD_PROVIDER_APP_ID__|${CLOUD_PROVIDER_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CLOUD_PROVIDER_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CONTROL_PLANE_APP_ID__|${CONTROL_PLANE_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CONTROL_PLANE_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CONTROL_PLANE_SP_NAME__|${CONTROL_PLANE_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CONTROL_PLANE_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_DISK_SP_NAME__|${AZURE_DISK_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_DISK_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__DISK_SP_APP_ID__|${DISK_SP_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __DISK_SP_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_FILE_SP_NAME__|${AZURE_FILE_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_FILE_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__FILE_SP_APP_ID__|${FILE_SP_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __FILE_SP_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__IMAGE_REGISTRY_SP_NAME__|${IMAGE_REGISTRY_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __IMAGE_REGISTRY_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__IMAGE_REGISTRY_APP_ID__|${IMAGE_REGISTRY_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __IMAGE_REGISTRY_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__INGRESS_SP_NAME__|${INGRESS_SP_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __INGRESS_SP_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__INGRESS_APP_ID__|${INGRESS_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __INGRESS_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__KV_NAME__|${KV_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __KV_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__KV_TENANT_ID__|${KV_TENANT_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __KV_TENANT_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CNCC_NAME__|${CNCC_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CNCC_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__CNCC_APP_ID__|${CNCC_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __CNCC_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__NODEPOOL_MGMT__|${NODEPOOL_MGMT}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __NODEPOOL_MGMT__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__NODEPOOL_MGMT_APP_ID__|${NODEPOOL_MGMT_APP_ID}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __NODEPOOL_MGMT_APP_ID__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

cat $INFRA_OUTPUT_FILE_1 | tr ":" "  "| while read key value 
do
    if [ "$key" = "privateZoneID" ]; then
        sed -i -e "s|__PRIVATE_ZONE_ID__|${value}|" hosted_cluster_manifestwork.yaml
        if [ $? -ne 0 ]; then
            echo "$(date) failed to substitue __PRIVATE_ZONE_ID__ in hosted_cluster_manifestwork.yaml"
            exit 1
        fi
    elif [ "$key" = "publicZoneID" ]; then
        sed -i -e "s|__PUBLIC_ZONE_ID__|${value}|" hosted_cluster_manifestwork.yaml
        if [ $? -ne 0 ]; then
            echo "$(date) failed to substitue __PUBLIC_ZONE_ID__ in hosted_cluster_manifestwork.yaml"
            exit 1
        fi
    elif [ "$key" = "securityGroupID" ]; then
        sed -i -e "s|__SECURITY_GROUP_ID__|${value}|" hosted_cluster_manifestwork.yaml
        if [ $? -ne 0 ]; then
            echo "$(date) failed to substitue __SECURITY_GROUP_ID__ in hosted_cluster_manifestwork.yaml"
            exit 1
        fi
    elif [ "$key" = "subnetID" ]; then
        sed -i -e "s|__SUBNET_ID__|${value}|" hosted_cluster_manifestwork.yaml
        if [ $? -ne 0 ]; then
            echo "$(date) failed to substitue __SUBNET_ID__ in hosted_cluster_manifestwork.yaml"
            exit 1
        fi
    elif [ "$key" = "vnetID" ]; then
        sed -i -e "s|__VNET_ID__|${value}|" hosted_cluster_manifestwork.yaml
        if [ $? -ne 0 ]; then
            echo "$(date) failed to substitue __VNET_ID__ in hosted_cluster_manifestwork.yaml"
            exit 1
        fi
    fi
done

sed -i -e "s|__RELEASE_IMAGE__|${RELEASE_IMAGE}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __RELEASE_IMAGE__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__EXT_DNS_RECORD_NAME__|${EXT_DNS_RECORD_NAME}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __EXT_DNS_RECORD_NAME__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi

sed -i -e "s|__BASE_DOMAIN__|${BASE_DOMAIN}|" hosted_cluster_manifestwork.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __BASE_DOMAIN__ in hosted_cluster_manifestwork.yaml"
    exit 1
fi


kubectl create secret generic ${CLUSTER_NAME_1}-cloud-credentials --namespace ocm-${INFRA_ID_1} --from-file $SP_AKS_CREDS
kubectl create secret generic aro-test-snaq57-cloud-credentials --namespace ocm-5wjbiyzxhzsrgjb91z18jrraayo4nywi --from-file sp-aks-creds.json