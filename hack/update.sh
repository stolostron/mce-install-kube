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

GRC_FILES="grc-clusterrole.yaml
grc-policy-addon-role.yaml
grc-policy-addon-clusterrole.yaml
grc-role.yaml
"

for f in $GRC_FILES
do 
    cp ./multiclusterhub-operator/pkg/templates/charts/toggle/grc/templates/$f ./policy/charts/grc/templates/
    $SED -i '/^\s*chart:/d' ./policy/charts/grc/templates/$f
    $SED -i '/^\s*release:/d' ./policy/charts/grc/templates/$f
    $SED -i '/^\s*app.kubernetes.io/d' ./policy/charts/grc/templates/$f
done

$SED -i '/^\s*namespace:/d' ./policy/charts/grc/templates/grc-clusterrole.yaml
$SED -i '/^\s*namespace:/d' ./policy/charts/grc/templates/grc-policy-addon-clusterrole.yaml


# update cluster-lifecycle sub-chart
CLUSTER_LIFECYCLE_FILES="./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-role.yaml 
./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-role_binding.yaml 
./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle/templates/klusterlet-addon-deployment.yaml"

for f in $CLUSTER_LIFECYCLE_FILES
do 
    cp $f ./policy/charts/cluster-lifecycle/templates/
done

#!/bin/bash

$SED -E -i 's|^(\s*image:\s*).*|\1"{{ .Values.global.registryOverride }}/{{ .Values.global.imageOverrides.klusterlet_addon_controller }}"|' "./policy/charts/cluster-lifecycle/templates/klusterlet-addon-deployment.yaml"

rm -rf multiclusterhub-operator


# update version in policy chart
CHART_FILES="./policy/Chart.yaml
./policy/charts/grc/Chart.yaml
./policy/charts/cluster-lifecycle/Chart.yaml"

for f in $CHART_FILES
do
    $SED -E -i "s/version: .*/version: v$POLICY_VERSION/" "$f"
    $SED -E -i "s/appVersion: .*/appVersion: v$POLICY_VERSION/" "$f"
done


# update e2e mce chart
rm -rf backplane-operator

git clone --depth 1 --branch "backplane-$MCE_VERSION" https://github.com/stolostron/backplane-operator.git

cp ./backplane-operator/config/crd/bases/multicluster.openshift.io_multiclusterengines.yaml ./hack/mce-chart/crds/
cp ./backplane-operator/config/rbac/role.yaml ./hack/mce-chart/templates/clusterrole.yaml


rm -rf backplane-operator

