# mce-install-kube
The manifests of add-ons or components deployed on k8s platform like AKS etc.

# Prerequisites

The MCE operator is required to be installed on the Hub cluster.

# Install

1. Install CRDs

```bash
kubectl apply -k manifests/crds
```

2. Install MCE CR and klusterletConfig

```bash
kubectl apply -k manifests/cluster-resources
```

3. Install klusterlet addon controller

```bash
kubectl apply -k manifests/addon-controller
```

4. Install policy controller

```bash
```

5. Install klusterletAddonConfig for local-cluster

```bash
kubectl apply -k manifests/local-cluster
```
