package e2e

import (
	"context"
	"fmt"
	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/util/intstr"

	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"open-cluster-management.io/api/addon/v1alpha1"
	clusterv1 "open-cluster-management.io/api/cluster/v1"
)

func CheckManagedClusterStatus(cluster *clusterv1.ManagedCluster) error {
	var okCount = 0
	for _, condition := range cluster.Status.Conditions {
		if (condition.Type == clusterv1.ManagedClusterConditionHubAccepted ||
			condition.Type == clusterv1.ManagedClusterConditionJoined ||
			condition.Type == clusterv1.ManagedClusterConditionAvailable) &&
			condition.Status == metav1.ConditionTrue {
			okCount++
		}
	}

	if okCount != 3 {
		return fmt.Errorf("cluster %s condtions are not ready: %v", cluster.Name, cluster.Status.Conditions)
	}

	okCount = 0

	for _, claim := range cluster.Status.ClusterClaims {
		switch claim.Name {
		case "id.k8s.io", "kubeversion.open-cluster-management.io",
			"platform.open-cluster-management.io", "product.open-cluster-management.io":
			if claim.Value != "" {
				okCount++
			}
		}
	}
	if okCount != 4 {
		return fmt.Errorf("cluster %s claims are not ready: %v", cluster.Name, cluster.Status.ClusterClaims)
	}
	return nil
}

func CheckAddonStatus(addon v1alpha1.ManagedClusterAddOn) error {
	if !meta.IsStatusConditionTrue(addon.Status.Conditions, v1alpha1.ManagedClusterAddOnConditionAvailable) {
		return fmt.Errorf("addon %s is not Available: %v", addon.Name, addon.Status.Conditions)
	}

	return nil
}

func ApplyResource(gvr schema.GroupVersionResource, obj *unstructured.Unstructured) (*unstructured.Unstructured, error) {
	namespace := obj.GetNamespace()
	name := obj.GetName()

	oldObj, err := HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		return HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Create(context.TODO(), obj, metav1.CreateOptions{})
	}

	return oldObj, err
}

func DeleteResource(gvr schema.GroupVersionResource, namespace, name string) error {
	return HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Delete(context.TODO(), name, metav1.DeleteOptions{})
}

func GetResource(gvr schema.GroupVersionResource, namespace, name string) (*unstructured.Unstructured, error) {
	if namespace != "" {
		obj, err := HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
		if err != nil {
			return nil, err
		}

		return obj, nil
	}
	obj, err := HubClients.DynamicClient.Resource(gvr).Get(context.TODO(), name, metav1.GetOptions{})
	if err != nil {
		return nil, err
	}

	return obj, nil

}

func LoadResourceFromJSON(json string) (*unstructured.Unstructured, error) {
	obj := unstructured.Unstructured{}
	err := obj.UnmarshalJSON([]byte(json))
	return &obj, err
}

func CheckManagedClusterInfo(clusterName string) error {
	clusterInfo, err := GetResource(ClusterInfoGVR, clusterName, clusterName)
	if err != nil {
		return err
	}

	kubeVersion, found, err := unstructured.NestedString(clusterInfo.Object, "status", "version")
	if !found || err != nil || kubeVersion == "" {
		return fmt.Errorf("failed get kubeVersion in clusterinfo %v, found:%v, err:%v, kubeVersion:%v",
			clusterName, found, err, kubeVersion)
	}

	return nil
}

func CheckMCE() error {
	mce, err := GetResource(MCEGVR, "", MCEName)
	if err != nil {
		return err
	}
	mcePhase, found, err := unstructured.NestedString(mce.Object, "status", "phase")
	if err != nil {
		return fmt.Errorf("failed to get mce status: %v", err)
	}
	if !found {
		return fmt.Errorf("failed found phase in the status of mce")
	}
	if mcePhase != "Available" {
		return fmt.Errorf("the mce status is not Available")
	}
	return nil
}

func ApplyHostedManagedCluster(name string) (*clusterv1.ManagedCluster, error) {
	cluster, err := HubClients.ClusterClient.ClusterV1().ManagedClusters().Get(context.TODO(), name, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		return HubClients.ClusterClient.ClusterV1().ManagedClusters().Create(
			context.TODO(),
			&clusterv1.ManagedCluster{
				ObjectMeta: metav1.ObjectMeta{
					Name: name,
					Annotations: map[string]string{
						"addon.open-cluster-management.io/enable-hosted-mode-addons": "true",
						"import.open-cluster-management.io/hosting-cluster-name":     "local-cluster",
						"import.open-cluster-management.io/klusterlet-deploy-mode":   "Hosted",
					},
				},
				Spec: clusterv1.ManagedClusterSpec{
					HubAcceptsClient: true,
				},
			},
			metav1.CreateOptions{},
		)
	}

	return cluster, err
}

func ApplyNamespace(ns string) error {
	_, err := HubClients.KubeClient.CoreV1().Namespaces().Get(context.TODO(), ns, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		ns := &v1.Namespace{
			ObjectMeta: metav1.ObjectMeta{
				Name: ns,
			},
		}
		_, err := HubClients.KubeClient.CoreV1().Namespaces().Create(context.TODO(), ns, metav1.CreateOptions{})
		return err
	}
	return err
}

var (
	hostedClusterNamespace   = "hosted-clusters"
	hostedClusterServiceName = "kube-apiserver"
)

func ApplyHostedService(ns string) error {
	_, err := HubClients.KubeClient.CoreV1().Services(ns).Get(context.TODO(), hostedClusterServiceName, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		apiService := &v1.Service{
			TypeMeta: metav1.TypeMeta{
				Kind:       "Service",
				APIVersion: "v1",
			},
			ObjectMeta: metav1.ObjectMeta{
				Name:      hostedClusterServiceName,
				Namespace: ns,
			},
			Spec: v1.ServiceSpec{
				Ports: []v1.ServicePort{
					{
						Name:     "https",
						Port:     443,
						Protocol: "TCP",
						TargetPort: intstr.IntOrString{
							IntVal: 6443,
						},
					},
				},
			},
		}
		_, err := HubClients.KubeClient.CoreV1().Services(ns).Create(context.TODO(), apiService, metav1.CreateOptions{})
		return err
	}
	return err
}

func ApplyHostedClusterKubeConfigSecret(clusterName string) error {
	secretName := clusterName + "-admin-kubeconfig"
	_, err := HubClients.KubeClient.CoreV1().Secrets(hostedClusterNamespace).Get(context.TODO(), secretName, metav1.GetOptions{})
	if errors.IsNotFound(err) {
		secret := &v1.Secret{
			TypeMeta: metav1.TypeMeta{},
			ObjectMeta: metav1.ObjectMeta{
				Name:      secretName,
				Namespace: hostedClusterNamespace,
			},
			Data: map[string][]byte{
				"kubeconfig": []byte(`apiVersion: v1
clusters:
- cluster:
    server: https://kube-apiserver.ocm-dev-1sv4l4ldnr6rd8ni12ndo4vtiq2gd7a4-sbarouti267.svc.cluster.local:7443
  name: cluster
contexts:
- context:
    cluster: cluster
    namespace: default
    user: admin
  name: admin
current-context: admin
kind: Config`),
			},
			Type: v1.SecretTypeOpaque,
		}
		_, err := HubClients.KubeClient.CoreV1().Secrets(hostedClusterNamespace).Create(context.TODO(), secret, metav1.CreateOptions{})
		return err
	}

	return err
}

func ApplyHostedClusterResources(hostedClusterName string) (*unstructured.Unstructured, error) {
	err := ApplyNamespace(hostedClusterNamespace)
	if err != nil {
		return nil, fmt.Errorf("failed to create ns %s. %v", hostedClusterNamespace, err)
	}

	err = ApplyHostedClusterKubeConfigSecret(hostedClusterName)
	if err != nil {
		return nil, fmt.Errorf("failed to create kubeconfig secret %s. %v", hostedClusterName, err)
	}

	serviceNamespace := hostedClusterNamespace + "-" + hostedClusterName
	err = ApplyNamespace(serviceNamespace)
	if err != nil {
		return nil, fmt.Errorf("failed to create ns %s. %v", serviceNamespace, err)
	}
	err = ApplyHostedService(serviceNamespace)
	if err != nil {
		return nil, fmt.Errorf("failed to create service in ns %s. %v", serviceNamespace, err)
	}

	hostedCluster, err := LoadResourceFromJSON(HostedClusterTemplate)
	if err != nil {
		return nil, fmt.Errorf("failed to load hostedCluster. %v", err)
	}

	err = unstructured.SetNestedField(hostedCluster.Object, hostedClusterName, "metadata", "name")
	if err != nil {
		return nil, err
	}
	err = unstructured.SetNestedField(hostedCluster.Object, hostedClusterNamespace, "metadata", "namespace")
	if err != nil {
		return nil, err
	}
	annotations := map[string]string{
		"cluster.open-cluster-management.io/managedcluster-name": hostedClusterName,
	}
	err = unstructured.SetNestedStringMap(hostedCluster.Object, annotations, "metadata", "annotations")
	if err != nil {
		return nil, err
	}

	hostedCluster, err = ApplyResource(HostedClusterGVR, hostedCluster)
	if err != nil {
		return nil, fmt.Errorf("failed to create hostedCluster. %v", err)
	}

	conditions := []interface{}{
		map[string]interface{}{
			"lastTransitionTime": "2024-12-10T16:22:32Z",
			"message":            "AsExpected",
			"reason":             "AsExpected",
			"status":             "True",
			"type":               "Available",
		},
	}

	err = unstructured.SetNestedSlice(hostedCluster.Object, conditions, "status", "conditions")
	if err != nil {
		return nil, err
	}
	return HubClients.DynamicClient.Resource(HostedClusterGVR).Namespace(hostedClusterNamespace).
		UpdateStatus(context.TODO(), hostedCluster, metav1.UpdateOptions{})

}

const HostedClusterTemplate = `{
    "apiVersion": "hypershift.openshift.io/v1beta1",
    "kind": "HostedCluster",
    "metadata": {
        "name": "spoke",
        "namespace": "hosted-spoke"
    },
    "spec": {
        "clusterID": "89693e2e-1198-4710-a254-c8277db50779",
        "controllerAvailabilityPolicy": "HighlyAvailable",
        "etcd": {
            "managementType": "Managed"
        },
        "fips": false,
        "infraID": "spoke-abc",
        "infrastructureAvailabilityPolicy": "SingleReplica",
        "issuerURL": "https://kubernetes.default.svc",
        "networking": {
            "clusterNetwork": [
                {
                    "cidr": "10.132.0.0/14"
                }
            ],
            "networkType": "OpenShiftSDN",
            "serviceNetwork": [
                {
                    "cidr": "172.31.0.0/16"
                }
            ]
        },
        "olmCatalogPlacement": "management",
        "platform": {
            "type": "Azure"
        },
        "pullSecret": {
            "name": "hosted-ipv4-pull-secret"
        },
        "release": {
            "image": "registry.hypershiftbm.lab:5000/openshift/release-images:4.14.0-0.nightly-2023-08-29-102237"
        },
        "services": [
            {
                "service": "APIServer",
                "servicePublishingStrategy": {
                    "route": {
                        "hostname": "api.hosted-ipv4.hypershiftbm.lab"
                    },
                    "type": "Route"
                }
            },
            {
                "service": "OIDC",
                "servicePublishingStrategy": {
                    "route": {
                        "hostname": "api.hosted-ipv4.hypershiftbm.lab"
                    },
                    "type": "Route"
                }
            },
            {
                "service": "OAuthServer",
                "servicePublishingStrategy": {
                    "route": {
                        "hostname": "api.hosted-ipv4.hypershiftbm.lab"
                    },
                    "type": "Route"
                }
            },
            {
                "service": "Konnectivity",
                "servicePublishingStrategy": {
                    "route": {
                        "hostname": "api.hosted-ipv4.hypershiftbm.lab"
                    },
                    "type": "Route"
                }
            },
            {
                "service": "Ignition",
                "servicePublishingStrategy": {
                    "route": {
                        "hostname": "api.hosted-ipv4.hypershiftbm.lab"
                    },
                    "type": "Route"
                }
            }
        ],
        "sshKey": {
            "name": "sshkey-cluster-hosted-ipv4"
        }
    },
    "status": {
        "conditions": [
            {
                "lastTransitionTime": "2024-12-10T16:22:32Z",
                "message": "AsExpected",
                "reason": "AsExpected",
                "status": "True",
                "type": "Available"
            }
        ]
    }
}`
