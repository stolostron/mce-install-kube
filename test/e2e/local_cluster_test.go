package e2e

import (
	"context"
	"fmt"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var _ = Describe("Check the status of local-cluster.", Label("local-cluster"), func() {
	BeforeEach(func() {
		By("Check the status of local-cluster.")
		Eventually(func() error {
			cluster, err := HubClients.ClusterClient.ClusterV1().ManagedClusters().Get(context.Background(),
				LocalClusterName, metav1.GetOptions{})
			if err != nil {
				return fmt.Errorf("failed get local-cluster: %v", err)
			}
			return CheckManagedClusterStatus(cluster)
		}).Should(Succeed())

		By("Check status of the addons in local-cluster.")
		Eventually(func() error {
			addons, err := HubClients.AddonClient.AddonV1alpha1().ManagedClusterAddOns(LocalClusterName).
				List(context.Background(), metav1.ListOptions{})
			if err != nil {
				return fmt.Errorf("failed list addons: %v", err)
			}

			if len(addons.Items) != 4 {
				return fmt.Errorf("expect 4 addons but got %v", len(addons.Items))
			}

			for _, addon := range addons.Items {
				switch addon.Name {
				case WorkManagerAddonName, HypershiftAddonName, GovernancePolicyFrameworkAddonName, ConfigPolicyAddonName:
					if err := CheckAddonStatus(addon); err != nil {
						return err
					}

				default:
					return fmt.Errorf("unexpected addon: %s", addon.Name)
				}
			}
			return nil
		}).Should(Succeed())
	})

	AfterEach(func() {

	})

	Context("Test cases for the work manager addon.", func() {
		It("Check the manangedClusterInfo status.", func() {
			Eventually(func() error {
				return CheckManagedClusterInfo(LocalClusterName)
			}).Should(Succeed())
		})
	})
})
