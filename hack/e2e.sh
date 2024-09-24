#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

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
            kubectl get mce
  
            exit 1
        fi

        result=$(bash -c "$cmd" 2>/dev/null || true) 
        if [ "$rst" -eq "$result" ]; then
            echo "pass "
            break
        fi
        
        echo "failed, expected $rst, but got $result, re-try after 5 seconds."
        sleep 5
        (( SECOND = SECOND + 5 ))
    done
}


echo ""
echo "#### Install MCE ####"
make install-mce

echo ""
echo "###### Wait until MCE pod is running ######"
waitForReady "kubectl get pods -n multicluster-engine | grep multicluster-engine-operator | grep -c \"Running\"" 1

echo ""
echo "###### Wait unitl cluster-manager is created ######"
waitForReady "kubectl get clustermanagers.operator.open-cluster-management.io  | grep -c \"cluster-manager\"" 1

echo ""
echo "###### Wait unitl local-cluster is created ######"
waitForReady "kubectl get mcl  | grep -c \"local-cluster\"" 1

echo ""
echo "###### Wait unitl MCE CR is Available ######"
# TODO: set to 1 after MCE can be Available 
waitForReady "kubectl get mce multiclusterengine | grep -c \"Available\"" 0

echo ""
echo "#### Configure MCE ####"

echo ""
echo "###### Wait until klusterletconfig CRD is installed ######"
waitForReady "kubectl get crds | grep -c \"klusterletconfigs\"" 1

echo ""
echo "###### Create global klusterletconfig ######"
# set hub api server to ./configuration/klusterletconfig.yaml
kubectl apply -f ./configuration/klusterletconfig.yaml

echo ""
echo "###### Wait until addondeploymentconfigs CRD is installed ######"
waitForReady "kubectl get crds | grep -c \"addondeploymentconfigs\"" 1

echo ""
echo "###### Patch addondeploymentconfig for hypershift addon ######"
kubectl apply -f configuration/addondeploymentconfig.yaml


echo ""
echo "#### Install ACM addons #####"
make install-acm-addons

echo ""
echo "###### Enable policy for local-cluster ######"
kubectl apply -f ./configuration/klusterletaddonconfig.yaml

echo ""
echo "###### Wait unitl 4 addons in local-cluster is Available ######"
# TODO: set to 4 after hypershift addon is Available.
waitForReady "kubectl get mca -n local-cluster | grep -c \"True\"" 3

echo ""
echo "!!!!!!!!!! MCE + policy is installed succussfully !!!!!!!!!!!!"
echo ""
