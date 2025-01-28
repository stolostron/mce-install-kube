#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail
set -o xtrace

kubectl get namespace hypershift

if [ $? -ne 0 ];
then
echo "$(date) hypershift namespace not found"
exit 1
fi

# Get a running hypershift operator pod
HO_POD_NAME=$(kubectl get pod -n hypershift --no-headers=true --field-selector=status.phase=Running -l app=operator -o custom-columns="NAME:.metadata.name" | head -n 1)

if [[ -n $HO_POD_NAME ]];
then
echo "$(date) Found a running hypershift operator pod: \"$HO_POD_NAME\""
else
echo "$(date) No running hypershift operator pod found."
exit 1
fi

# Extract the hypershift CLI from the hypershift operator pod. 
# Try to get the hypershift-no-cgo first which is no CGO enabled. This is available only in the downstream image.
# If not found, then get the hypershift binary (upstream image case) 

kubectl cp ${HO_POD_NAME}:/usr/bin/hypershift-no-cgo /tmp/hypershift

if [ ! -f /tmp/hypershift ]; then
    kubectl cp -n hypershift ${HO_POD_NAME}:/usr/bin/hypershift /tmp/hypershift
fi

if [ ! -f ./hypershift ]; then
    echo "$(date) failed to extract the hypershift binary from the hypershift operator pod"
    exit 1
fi

chmod +x /tmp/hypershift
if [ $? -ne 0 ]; then
echo "$(date) failed to chmod +x /tmp/hypershift"
exit 1
fi

mv /tmp/hypershift /bin
if [ $? -ne 0 ]; then
echo "$(date) failed to mv extracted hypershift binary to /bin"
exit 1
fi