#!/bin/bash
# filepath: /Users/zyin/code/mce-install-kube/hack/update-images.sh

set -e

update_mce_images() {
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


# override the image tags.

update_mce_images "./test/configuration/mce-values.yaml" "$UPSTREAM_TAG"
update_mce_images "./test/configuration/mce-ds-values.yaml" "$DOWNSTREAM_MCE_TAG"
update_policy_images "./test/configuration/policy-values.yaml" "$UPSTREAM_TAG"
update_policy_images "./test/configuration/policy-ds-values.yaml" "$DOWNSTREAM_POLICY_TAG"
