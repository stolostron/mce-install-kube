#!/bin/bash

oc apply -f ./resources/multiclusterengine.yaml
if [ $? != 0 ]; then
  echo "Failed to apply multicluster-engine. Failing test"
  exit 1
fi

# Loop for 10 minutes (600 seconds)
for (( i=0; i<600; i+=15 )); do
  oc get mce multiclusterengine -oyaml > ./tmp.yml
  export Status=$(yq eval '.status.phase' ./tmp.yml)
    if [ "$Status" == "Available" ]; then
      echo "Multi-cluster engine available and running"
      rm ./tmp.yml
      exit 0
    fi
  sleep 15
done

rm ./tmp.yml

echo "Multicluster-engine failed to install after 10 minutes. Failing test."
exit 1