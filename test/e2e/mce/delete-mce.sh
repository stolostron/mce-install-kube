#!/bin/bash

oc delete mce multiclusterengine
if [ $? != 0 ]; then
  echo "Failed to delete multicluster-engine. Failing test"
  exit 1
fi


# Loop for 10 minutes (600 seconds)
for (( i=0; i<600; i+=15 )); do
  oc get mce multiclusterengine > /dev/null 2>&1
  if [ $? != 0 ]; then
  # Resource exists
    echo "MCE has been deleted. Test passed"
    exit 0
  fi
  sleep 15
done

 # Resource doesn't exist
echo "MCE has not been deleted after 10 minutes. Failing test."
exit 1

