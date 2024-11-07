# mce-install-kube
The manifests of add-ons or components deployed on k8s platform like AKS etc.

# Prerequisites

The MCE operator is required to be installed on the Hub cluster. 

[Here](configuration/multiclusterengine.yaml) is the MCE CR sample.

# Configure the MCE 

1. Set the hub api server to the `spec.hubKubeAPIServerURL` in the `global` `klusterletConfig`, and then apply it.

```
kubectl apply -f ./configuration/klusterletconfig.yaml
```

2. Apply a `AddOnDeploymentConfig` for add-ons working in hosted mode.

```
kubectl apply -f ./configuration/addonhostedconfig.yaml
```

3. Patch work-manager add-on to support hosted mode.
   
```
kubectl patch clustermanagementaddon work-manager --type merge -p '{"spec":{"supportedConfigs":[{"defaultConfig":{"name":"addon-hosted-config","namespace":"multicluster-engine"},"group":"addon.open-cluster-management.io","resource":"addondeploymentconfigs"}]}}'
```
or

```
kubectl apply -f ./configuration/workmanagercma.yaml
```
# Install Policy after MCE is installed

```
helm install policy ./policy
```

# Enable policy addon for local-cluster

```
kubectl apply -f ./configuration/klusterletaddonconfig.yaml
```
