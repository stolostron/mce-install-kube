#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# env
export HELM=_output/bin/helm
# export KUBECONFIG=kubeconfig

function waitForReady() {
    FOUND=1
    SECOND=0
    local cmd="$1"
    local rst="$2"

    echo "check if \"$cmd\" ==  $rst"

    while [ ${FOUND} -eq 1 ]; do
        if [ $SECOND -gt 240 ]; then
            echo "Timeout waiting for the result of cmd. "
        
            kubectl get pods -A
            kubectl get mcl
            kubectl get mce multiclusterengine -o yaml
  
            exit 1
        fi

        result=$(bash -c "$cmd" 2>/dev/null || true) 
        if [ "$rst" -eq "$result" ]; then
            echo "pass "
            break
        fi
        
        echo "expected $rst, but got $result, re-try after 5 seconds..."
        sleep 5
        (( SECOND = SECOND + 5 ))
    done
}


echo ""
echo "#### Install MCE on Hub cluster ####"
make ensure-helm

# install released mce
# helm install mce ./hack/mce-chart --set-file images.imageCredentials.dockerConfigJson=pullsecret.json

# install upstream mce 
$HELM install mce ./hack/mce-chart -f ./test/configuration/mce-values.yaml


echo ""
echo "###### Wait until MCE pod is running ######"
waitForReady "kubectl get pods -n multicluster-engine | grep multicluster-engine-operator | grep -c \"Running\"" 1

echo ""
echo "###### Wait unitl cluster-manager is created ######"
waitForReady "kubectl get clustermanagers.operator.open-cluster-management.io  | grep -c \"cluster-manager\"" 1

echo ""
echo "#### Configure MCE ####"

echo ""
echo "###### Wait until klusterletconfig CRD is installed ######"
waitForReady "kubectl get crds | grep -c \"klusterletconfigs\"" 1

echo ""
echo "###### Create global klusterletconfig ######"
kubectl apply -f ./test/configuration/klusterletconfig.yaml

echo ""
echo "###### Wait unitl local-cluster is created ######"
waitForReady "kubectl get mcl local-cluster | grep -c \"True\"" 1


echo ""
echo "###### Wait unitl MCE CR is Available ######"
waitForReady "kubectl get mce multiclusterengine | grep -c \"Available\""  1

echo ""
echo "###### create addonhostedconfig ######"
kubectl apply -f ./configuration/addonhostedconfig.yaml

echo ""
echo "###### patch clustermanagementaddon work-manager ######"
#kubectl patch clustermanagementaddon work-manager --type merge -p '{"spec":{"supportedConfigs":[{"defaultConfig":{"name":"addon-hosted-config","namespace":"multicluster-engine"},"group":"addon.open-cluster-management.io","resource":"addondeploymentconfigs"}]}}'
kubectl apply -f ./configuration/workmanagercma.yaml

echo ""
echo "#### Install Policy addons #####"
make ensure-helm
$HELM install policy ./policy -f ./test/configuration/policy-values.yaml


echo ""
echo "###### Enable policy addons for local-cluster ######"
kubectl apply -f ./configuration/klusterletaddonconfig.yaml

echo ""
echo "###### Wait unitl 4 addons in local-cluster is Available ######"
waitForReady "kubectl get mca -n local-cluster | grep -c \"True\"" 4

echo ""
echo "!!!!!!!!!! MCE + policy is installed succussfully !!!!!!!!!!!!"
echo ""
