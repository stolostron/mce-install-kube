#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CRD_FILES="./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_placementbindings.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policies.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policyautomations.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policysets.yaml
./multiclusterhub-operator/pkg/templates/crds/cluster-lifecycle/agent.open-cluster-management.io_klusterletaddonconfigs_crd.yaml
./multiclusterhub-operator/pkg/templates/crds/multicloud-operators-subscription/apps.open-cluster-management.io_placementrules_crd_v1.yaml
"

GRC_CMA_FILES="./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/config-policy-clustermanagementaddon.yaml
./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/governance-policy-framework-clustermanagementaddon.yaml
"

rm -rf multiclusterhub-operator

git clone --depth 1 --branch "release-$ACM_VERSION" https://github.com/stolostron/multiclusterhub-operator.git


for f in $CRD_FILES
do
    cp $f ./acm-addons/crds/
done

for f in $GRC_CMA_FILES
do 
    cp $f ./acm-addons/charts/grc/templates/
done


rm -rf multiclusterhub-operator

