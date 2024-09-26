#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

rm -rf multiclusterhub-operator

git clone --depth 1 --branch "release-$ACM_VERSION" https://github.com/stolostron/multiclusterhub-operator.git


# update CRDs
CRD_FILES="./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_placementbindings.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policies.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policyautomations.yaml
./multiclusterhub-operator/pkg/templates/crds/grc/policy.open-cluster-management.io_policysets.yaml
./multiclusterhub-operator/pkg/templates/crds/cluster-lifecycle/agent.open-cluster-management.io_klusterletaddonconfigs_crd.yaml
./multiclusterhub-operator/pkg/templates/crds/multicloud-operators-subscription/apps.open-cluster-management.io_placementrules_crd_v1.yaml
"

for f in $CRD_FILES
do
    cp $f ./policy/crds/
done


# update grc sub-chart
#cp ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/Chart.yaml ./policy/charts/grc/
#cp ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/values.yaml ./policy/charts/grc/

GRC_FILES="./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/config-policy-clustermanagementaddon.yaml
./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/governance-policy-framework-clustermanagementaddon.yaml
"
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-clusterrole.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-clusterrolebinding.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-policy-addon-role.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-policy-addon-rolebinding.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-policy-addon-clusterrole.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-policy-addon-clusterrolebinding.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-policy-addon-sa.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-role.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-rolebinding.yaml
# ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/grc-sa.yaml
# "


for f in $GRC_FILES
do 
    cp $f ./policy/charts/grc/templates/
done

# update cluster-lifecycle sub-chart
#cp ./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/Chart.yaml ./policy/charts/cluster-lifecycle/
#cp ./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/values.yaml ./policy/charts/cluster-lifecycle/

CLUSTER_LIFECYCLE_FILES="./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-role.yaml
./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-role_binding.yaml
./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-deployment.yaml"

for f in $CLUSTER_LIFECYCLE_FILES
do 
    cp $f ./policy/charts/cluster-lifecycle/templates/
done

rm -rf multiclusterhub-operator


# update e2e mce chart

rm -rf backplane-operator

git clone --depth 1 --branch "backplane-$MCE_VERSION" https://github.com/stolostron/backplane-operator.git

cp ./backplane-operator/config/crd/bases/multicluster.openshift.io_multiclusterengines.yaml ./e2e/mce-chart/crds/
cp ./backplane-operator/config/rbac/role.yaml ./e2e/mce-chart/templates/clusterrole.yaml

$SED -i 's/multicluster-engine-operator-role/multicluster-engine-operator/' ./e2e/mce-chart/templates/clusterrole.yaml

rm -rf backplane-operator