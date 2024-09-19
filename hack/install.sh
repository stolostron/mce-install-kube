#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

kubectl apply -k ./manifests/crds
kubectl apply -k ./manifests/addon-controller
kubectl apply -k ./manifests/policy

#TODO: set hub api server to manifests/cluster-resources/klusterletconfig.yaml
kubectl apply -k ./manifests/cluster-resources

#TODO: enable policy addon after local-cluster is created
kubectl apply -k manifests/local-cluster
