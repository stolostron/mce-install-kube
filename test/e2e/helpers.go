package e2e

import (
	"fmt"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
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
	var okCount = 0
	for _, condition := range addon.Status.Conditions {
		if (condition.Type == v1alpha1.ManagedClusterAddOnConditionAvailable ||
			condition.Type == v1alpha1.ManagedClusterAddOnManifestApplied) &&
			condition.Status == metav1.ConditionTrue {
			okCount++
		}
	}

	if okCount == 2 {
		return nil
	}

	return fmt.Errorf("cluster %s condtions are not ready: %v", addon.Name, addon.Status.Conditions)
}
