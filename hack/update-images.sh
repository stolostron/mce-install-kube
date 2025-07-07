#!/bin/bash
# filepath: /Users/zyin/code/mce-install-kube/hack/update-images.sh

set -e

update_upstream_mce_images() {
  local YAML_FILE="$1"
  local NEW_TAG="$2"

  if [[ ! -f "$YAML_FILE" ]]; then
    echo "YAML file not found: $YAML_FILE"
    return 1
  fi

  # Get all keys under images.overrides
  KEYS=$(yq e '.images.overrides | keys | .[]' "$YAML_FILE")

  for KEY in $KEYS; do
    CURRENT=$(yq e ".images.overrides.${KEY}" "$YAML_FILE")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $KEY"
      continue
    fi

    IMG_NAME="${CURRENT%%:*}"
    NEW_VALUE="${IMG_NAME}:${NEW_TAG}"

    yq e -i ".images.overrides.${KEY} = \"${NEW_VALUE}\"" "$YAML_FILE"
  done

  echo "All image tags updated to '$NEW_TAG' in $YAML_FILE"
}

update_downstream_mce_images() {
  local YAML_FILE="$1"
  local CSV_FILE="$2"

  if [[ ! -f "$YAML_FILE" ]]; then
    echo "YAML file not found: $YAML_FILE"
    return 1
  fi

 if [[ ! -f "$CSV_FILE" ]]; then
    echo "YAML file not found: $CSV_FILE"
    return 1
  fi


  # Get all keys under images.overrides
  KEYS=$(yq e '.images.overrides | keys | .[]' "$YAML_FILE")

  for KEY in $KEYS; do
    CURRENT=$(yq e ".images.overrides.${KEY}" "$YAML_FILE")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $KEY"
      continue
    fi

    if [[ "$KEY" == "backplane_operator" ]]; then
      IMAGE=$(yq e '.spec.install.spec.deployments[0].spec.template.spec.containers[0].image' "$CSV_FILE" | sed 's|registry.redhat.io/multicluster-engine/||')
    else
      IMAGE=$(yq e ".spec.relatedImages[] | select(.name == \"$KEY\") | .image" "$CSV_FILE" | sed 's|registry.redhat.io/multicluster-engine/||')
    fi 

    if [[ -z "$IMAGE" ]]; then
      echo "No image found in CSV for key: $KEY"
      continue
    fi

    yq e -i ".images.overrides.${KEY} = \"${IMAGE}\"" "$YAML_FILE"

    echo "image $KEY tags updated to $IMAGE  in $YAML_FILE"
  done
}

update_policy_images() {
  local YAML_FILE="$1"
  local NEW_TAG="$2"

  if [[ ! -f "$YAML_FILE" ]]; then
    echo "YAML file not found: $YAML_FILE"
    return 1
  fi

  # Get all keys under images.overrides
  KEYS=$(yq e '.global.imageOverrides | keys | .[]' "$YAML_FILE")

  for KEY in $KEYS; do
    CURRENT=$(yq e ".global.imageOverrides.${KEY}" "$YAML_FILE")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $KEY"
      continue
    fi

    IMG_NAME="${CURRENT%%:*}"
    NEW_VALUE="${IMG_NAME}:${NEW_TAG}"

    yq e -i ".global.imageOverrides.${KEY} = \"${NEW_VALUE}\"" "$YAML_FILE"
  done

  echo "All image tags updated to '$NEW_TAG' in $YAML_FILE"
}

update_downstream_policy_images() {
  local YAML_FILE="$1"
  local CSV_FILE="$2"

  if [[ ! -f "$YAML_FILE" ]]; then
    echo "YAML file not found: $YAML_FILE"
    return 1
  fi

 if [[ ! -f "$CSV_FILE" ]]; then
    echo "YAML file not found: $CSV_FILE"
    return 1
  fi


  # Get all keys under images.overrides
  KEYS=$(yq e '.global.imageOverrides | keys | .[]' "$YAML_FILE")

  for KEY in $KEYS; do
    CURRENT=$(yq e ".global.imageOverrides.${KEY}" "$YAML_FILE")
    if [[ "$CURRENT" == "null" ]]; then
      echo "Key not found: $KEY"
      continue
    fi

    IMAGE=$(yq e ".spec.relatedImages[] | select(.name == \"$KEY\") | .image" "$CSV_FILE" | sed 's|registry.redhat.io/rhacm2/||')
    if [[ -z "$IMAGE" ]]; then
      echo "No image found in CSV for key: $KEY"
      continue
    fi

    yq e -i ".global.imageOverrides.${KEY} = \"${IMAGE}\"" "$YAML_FILE"

    echo "image $KEY tags updated to $IMAGE  in $YAML_FILE"
  done
}

# override the image tags.
UPSTREAM_TAG=$(curl -s -X GET "https://quay.io/api/v1/repository/stolostron/acm-custom-registry/tag/?limit=10" | jq -r ".tags | .[] | select(.name | startswith(\"$POLICY_VERSION\")) | .name" | head -n 1)

if [[ -z "$UPSTREAM_TAG" ]]; then
  echo "Error: No tag found for POLICY_VERSION '${POLICY_VERSION}'"
  exit 1
fi

echo "The latest upstream image tag is $UPSTREAM_TAG, update the values.yaml"
update_upstream_mce_images "./test/configuration/mce-values.yaml" "$UPSTREAM_TAG"
update_policy_images "./test/configuration/policy-values.yaml" "$UPSTREAM_TAG"

echo "Get the MCE downstream image from the repo:github.com/stolostron/mce-operator-bundle"
rm -rf mce-operator-bundle

git clone --depth 1 --branch "backplane-$MCE_VERSION" https://github.com/stolostron/mce-operator-bundle.git

update_downstream_mce_images "./test/configuration/mce-ds-values.yaml" "./mce-operator-bundle/manifests/multicluster-engine.v$MCE_VERSION.0.clusterserviceversion.yaml"


echo "Get the ACM downstream image from the repo:github.com/stolostron/acm-operator-bundle"
rm -rf acm-operator-bundle

git clone --depth 1 --branch "release-$ACM_VERSION" https://github.com/stolostron/acm-operator-bundle.git

update_downstream_policy_images "./test/configuration/policy-ds-values.yaml" "./acm-operator-bundle/manifests/advanced-cluster-management.v$ACM_VERSION.0.clusterserviceversion.yaml"
