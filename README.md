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


# Install Policy after MCE is installed

```
helm install policy ./policy
```

# Enable policy addon for local-cluster

```
kubectl apply -f ./configuration/klusterletaddonconfig.yaml
```
