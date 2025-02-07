#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -o xtrace

# Parent resource group name
RESOURCE_GROUP=
# AKS cluster name
AKS_CLUSTER_NAME=
# The external DNS credential file created by the azureConfiguration.sh script
EXTERNAL_DNS_CREDS=ext-dns-creds.json
EXT_DNS_ZONE_NAME=
# Pull secret file path
PULL_SECRET_FILE_PATH=
# Hypershift operator image file 
HYPERSHIFT_OPERATOR_IMAGE=


LOCATION="eastus"

if [ -z ${AKS_CLUSTER_NAME+x} ]; then
  echo "AKS_CLUSTER_NAME is not defined"
  exit 1
fi

if [ -z ${RESOURCE_GROUP+x} ]; then
  echo "RESOURCE_GROUP is not defined"
  exit 1
fi

if [ -z ${EXTERNAL_DNS_CREDS+x} ]; then
  echo "EXTERNAL_DNS_CREDS is not defined"
  exit 1
fi

if [ -z ${EXT_DNS_ZONE_NAME+x} ]; then
  echo "EXT_DNS_ZONE_NAME is not defined"
  exit 1
fi

if [ -z ${PULL_SECRET_FILE_PATH+x} ]; then
  echo "PULL_SECRET_FILE_PATH is not defined"
  exit 1
fi

if [ -z ${HYPERSHIFT_OPERATOR_IMAGE+x} ]; then
  echo "HYPERSHIFT_OPERATOR_IMAGE is not defined"
  exit 1
fi

kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_prometheusrules.yaml
kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply -f https://raw.githubusercontent.com/openshift/api/master/route/v1/zz_generated.crd-manifests/routes-Default.crd.yaml

AZURE_KEY_VAULT_AUTHORIZED_USER_ID=$(az aks show -n ${AKS_CLUSTER_NAME} -g ${RESOURCE_GROUP} | jq .addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -r)
echo $AZURE_KEY_VAULT_AUTHORIZED_USER_ID
kubectl create ns hypershift
kubectl create secret generic external-dns-credentials --from-file=credentials=$EXTERNAL_DNS_CREDS -n hypershift
kubectl create secret docker-registry pull-secret --from-file=.dockerconfigjson=$PULL_SECRET_FILE_PATH -n hypershift 

# Make a copy of the template hypershift operator install job YAML
cp ./resources/hoInstallJobTemplate.yaml ./hoInstallJob.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to copy hoInstallJobTemplate.yaml"
    exit 1
fi

sed -i -e "s|__EXT_DNS_ZONE_NAME__|${EXT_DNS_ZONE_NAME}|" hoInstallJob.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __EXT_DNS_ZONE_NAME__ in hoInstallJob.yaml"
    exit 1
fi

sed -i -e "s|__AZURE_KEY_VAULT_AUTHORIZED_USER_ID__|${AZURE_KEY_VAULT_AUTHORIZED_USER_ID}|" hoInstallJob.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __AZURE_KEY_VAULT_AUTHORIZED_USER_ID__ in hoInstallJob.yaml"
    exit 1
fi

sed -i -e "s|__HYPERSHIFT_OPERATOR_IMAGE__|${HYPERSHIFT_OPERATOR_IMAGE}|" hoInstallJob.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to substitue __HYPERSHIFT_OPERATOR_IMAGE__ in hoInstallJob.yaml"
    exit 1
fi

# Create RBAC for the hypershift installation
kubectl apply -f ./resources/ho-clusterrole.yaml
kubectl apply -f ./resources/ho-clusterrolebinding.yaml
kubectl apply -f ./resources/ho-sa.yaml

# Apply the hypershift operator install job
kubectl apply -f hoInstallJob.yaml
if [ $? -ne 0 ]; then
    echo "$(date) failed to apply hoInstallJob.yaml"
    exit 1
fi

sleep 5 

JOB_POD_NAME=$(kubectl get pod -n multicluster-engine --no-headers=true -l job-name=hypershift-install-job -o custom-columns="NAME:.metadata.name" | head -n 1)

if [[ -n $JOB_POD_NAME ]];
then
    echo "$(date) Found the install job pod: \"$JOB_POD_NAME\""
else
    echo "$(date) No hypershift operator install job pod found."
    exit 1
fi

# Wait for the hypershift operator install job to complete
FOUND=1
MINUTE=0

while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for the hypershift operator install job pod ${JOB_POD_NAME}."
        kubectl get pod -n multicluster-engine ${JOB_POD_NAME} -o jsonpath="Name: {.metadata.name} Status: {.status.phase}"
        echo
        exit 1
    fi

    status=`kubectl get pod -n multicluster-engine ${JOB_POD_NAME} -o jsonpath="{.status.phase}"`

    if [ "${status}" = "Succeeded" ]; then 
        echo "${JOB_POD_NAME} is completed"
        break
    fi
    sleep 3
    (( MINUTE = MINUTE + 3 ))
done

# # Get pod names
HO_POD_NAME=$(kubectl get pod -n hypershift --no-headers=true -l app=operator -o custom-columns="NAME:.metadata.name" | head -n 1)

if [[ -n $HO_POD_NAME ]];
then
    echo "$(date) Found the hypershift operator pod: \"$HO_POD_NAME\""
else
    echo "$(date) No hypershift operator pod found."
    exit 1
fi


# # Wait for the hypershift operator pod to be running
FOUND=1
MINUTE=0
while [ ${FOUND} -eq 1 ]; do
    # Wait up to 5min
    if [ $MINUTE -gt 300 ]; then
        echo "Timeout waiting for the hypershift operator pod ${HO_POD_NAME}."
        kubectl get pod -n hypershift ${HO_POD_NAME} -o jsonpath="Name: {.metadata.name} Status: {.status.phase}"
        echo
        exit 1
    fi

    status=`kubectl get pod -n hypershift ${HO_POD_NAME} -o jsonpath="{.status.phase}"`

    if [ "${status}" = "Running" ]; then
        echo "${HO_POD_NAME} is running"
        break
    fi
    sleep 3
    (( MINUTE = MINUTE + 3 ))
done