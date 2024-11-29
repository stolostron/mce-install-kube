package e2e

import (
	"context"
	"fmt"
	"os"

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

	_, err := HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
	if err != nil && errors.IsNotFound(err) {
		return HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Create(context.TODO(), obj, metav1.CreateOptions{})
	}
	if err == nil {
		return nil, nil
	}

	return nil, err
}

func DeleteResource(gvr schema.GroupVersionResource, namespace, name string) error {
	return HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Delete(context.TODO(), name, metav1.DeleteOptions{})
}

func GetResource(gvr schema.GroupVersionResource, namespace, name string) (*unstructured.Unstructured, error) {
	obj, err := HubClients.DynamicClient.Resource(gvr).Namespace(namespace).Get(context.TODO(), name, metav1.GetOptions{})
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

func GetManagedClusterName() string {
	if HostedClusterName == "" {
		return os.Getenv("MANAGED_CLUSTER_NAME")
	}
	return HostedClusterName
}
