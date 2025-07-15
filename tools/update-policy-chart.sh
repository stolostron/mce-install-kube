#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

work_dir="$PROJECT_ROOT/policy-update-tmp"
rm -rf $work_dir
mkdir $work_dir
cd $work_dir

policy_helm_charts_base_dir="../policy"
policy_helm_charts_dir="../policy/charts"

# Check required environment variables
if [[ -z "${ACM_VERSION:-}" ]]; then
  echo "Error: ACM_VERSION environment variable must be set."
  exit 1
fi

# Validate ACM_VERSION format (must be a.b.c, where a, b, c are numbers(e.g., 2.14.3).)
if ! [[ "$ACM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: ACM_VERSION must be in the format a.b.c (e.g., 2.14.3)."
  exit 1
fi

echo "# The ACM version is $ACM_VERSION."

if [[ -z "${ACM_OPERATOR_BUNDLE_IMAGE:-}" ]]; then
  echo "Error: ACM_OPERATOR_BUNDLE_IMAGE environment variable must be set."
  exit 1
fi

echo "# The ACM operator bundle image is $ACM_OPERATOR_BUNDLE_IMAGE."
echo "# Start update the Policy helm chart."

# Extract a.b as BRANCH
branch=$(echo "$ACM_VERSION" | awk -F. '{print $1"."$2}')

echo "## Sync the Policy helm chart from the branch release-$branch of multiclusterhub-operator repo."
git clone --depth 1 --branch "release-$branch" https://github.com/stolostron/multiclusterhub-operator.git

echo "## Update the CRDs."
crds_dir="./multiclusterhub-operator/pkg/templates/crds"
crd_files="$crds_dir/grc/policy.open-cluster-management.io_placementbindings.yaml
$crds_dir/grc/policy.open-cluster-management.io_policies.yaml
$crds_dir/grc/policy.open-cluster-management.io_policyautomations.yaml
$crds_dir/grc/policy.open-cluster-management.io_policysets.yaml
$crds_dir/cluster-lifecycle/agent.open-cluster-management.io_klusterletaddonconfigs_crd.yaml
$crds_dir/multicloud-operators-subscription/apps.open-cluster-management.io_placementrules_crd_v1.yaml
"

for file in $crd_files; do
    cp $file $policy_helm_charts_base_dir/crds/
done

echo "## Update the grc sub-chart."
grc_chart_dir="./multiclusterhub-operator/pkg/templates/charts/toggle/grc"
grc_files="grc-clusterrole.yaml
grc-policy-addon-role.yaml
grc-policy-addon-clusterrole.yaml
grc-role.yaml
"

for file in $grc_files; do 
    cp $grc_chart_dir/templates/$file $policy_helm_charts_dir/grc/templates/   
    sed -E '/^[[:space:]]*(chart:|release:|app.kubernetes.io)/d' $policy_helm_charts_dir/grc/templates/$file > tmp && mv tmp  $policy_helm_charts_dir/grc/templates/$file
done

# TODO: remove the namespace in the clusterrole and clusterrolebinding files of the upstream helm chart.
sed -E '/^[[:space:]]*(namespace:)/d' $policy_helm_charts_dir/grc/templates/grc-clusterrole.yaml > tmp && mv tmp  $policy_helm_charts_dir/grc/templates/grc-clusterrole.yaml
sed -E '/^[[:space:]]*(namespace:)/d' $policy_helm_charts_dir/grc/templates/grc-policy-addon-clusterrole.yaml > tmp && mv tmp  $policy_helm_charts_dir/grc/templates/grc-policy-addon-clusterrole.yaml

echo "## Update the cluster-lifecycle sub-chart."
cluster_lifecycle_dir="./multiclusterhub-operator/pkg/templates/charts/toggle/cluster-lifecycle"
cluster_lifecycle_files="$cluster_lifecycle_dir/templates/klusterlet-addon-role.yaml 
$cluster_lifecycle_dir/templates/klusterlet-addon-role_binding.yaml 
$cluster_lifecycle_dir/templates/klusterlet-addon-deployment.yaml"

for f in $cluster_lifecycle_files; do 
    cp $f $policy_helm_charts_dir/cluster-lifecycle/templates/
done

# the Values.global.registryOverride is not defined in the upstream helm chart so need override here.
sed -i.bak 's|^\([[:space:]]*image:[[:space:]]*\)"{{ .Values.global.imageOverrides.klusterlet_addon_controller }}"|\1"{{ .Values.global.registryOverride }}/{{ .Values.global.imageOverrides.klusterlet_addon_controller }}"|' $policy_helm_charts_dir/cluster-lifecycle/templates/klusterlet-addon-deployment.yaml
rm -f $policy_helm_charts_dir/cluster-lifecycle/templates/klusterlet-addon-deployment.yaml.bak


echo "## Update version in policy chart."

chart_files="$policy_helm_charts_base_dir/Chart.yaml
$policy_helm_charts_dir/grc/Chart.yaml
$policy_helm_charts_dir/cluster-lifecycle/Chart.yaml"

for f in $chart_files; do
    sed -E "s/version: .*/version: v$ACM_VERSION/" "$f" > tmp && mv tmp  $f
    sed -E "s/appVersion: .*/appVersion: v$ACM_VERSION/" "$f" > tmp && mv tmp  $f
done

echo "# The Policy helm chart is updated."
echo "# Clean up the download multiclusterhub-operator repo."
rm -rf multiclusterhub-operator

echo "# Update the images in the values.yaml."

echo "## Pull the acm-operator-bundle image $ACM_OPERATOR_BUNDLE_IMAGE."
podman pull --arch amd64 $ACM_OPERATOR_BUNDLE_IMAGE

echo "## Create a temporary container."
if podman container exists temp_acm_bundle; then
  podman rm -f temp_acm_bundle
fi

podman create --arch amd64 --name temp_acm_bundle $ACM_OPERATOR_BUNDLE_IMAGE

echo "## Copy the contents out of the container to a local directory."
image_json_file=$ACM_VERSION.json
podman cp temp_acm_bundle:/extras/$image_json_file ./

echo "Remove the temporary container."
podman rm temp_acm_bundle

values_file=$policy_helm_charts_base_dir/values.yaml

# Get all keys under .global.imageOverrides
keys=$(yq e '.global.imageOverrides | keys | .[]' "$values_file")

for key in $keys; do
    current_image=$(yq e ".global.imageOverrides.${key}" "$values_file")
    if [[ "$current_image" == "null" ]]; then
        echo "Error: Key not found: $key"
        exit 1
    fi

     image_name=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-name"' $image_json_file)
    if [[ -z "$image_name" ]]; then
        echo "Error: No image found in the image for key: $key"
        exit 1
    fi
    image_digest=$(jq -r '.[] | select(."image-key" == "'"$key"'") | ."image-digest"' $image_json_file)
    if [[ -z "$image_digest" ]]; then
        echo "Error: No image digest in the image for key: $key"
        exit 1
    fi

    yq e -i ".global.imageOverrides.${key} = \"${image_name}@${image_digest}\"" "$values_file"
    echo "### Update the image $key tags updated to ${image_name}@${image_digest} in $values_file"
done

cd ..
rm -rf $work_dir

echo "!!! Update finished !!!"
