#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


# install MCE

kubectl apply -k ./e2e/prerequisites
kubectl apply -k ./e2e/mce


# install 

make install


# check the cluster and addon conditions
# TODO
