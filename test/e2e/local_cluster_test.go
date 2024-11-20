package e2e

import (
	"context"
	"fmt"
	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

var _ = ginkgo.Describe("check if local-cluster is healthy", func() {

	ginkgo.BeforeEach(func() {

	})
	ginkgo.AfterEach(func() {

	})

	ginkgo.It("check status of the local-cluster", func() {
		cluster, err := HubClients.ClusterClient.ClusterV1().ManagedClusters().Get(context.Background(),
			LocalClusterName, metav1.GetOptions{})
		gomega.Expect(err).ToNot(gomega.HaveOccurred())
		gomega.Expect(CheckManagedClusterStatus(cluster)).ToNot(gomega.HaveOccurred())
	})

	ginkgo.It("check status of the addons in local-cluster", func() {
		addons, err := HubClients.AddonClient.AddonV1alpha1().ManagedClusterAddOns(LocalClusterName).
			List(context.Background(), metav1.ListOptions{})
		gomega.Expect(err).ToNot(gomega.HaveOccurred())
		gomega.Expect(len(addons.Items)).Should(gomega.Equal(4))

		for _, addon := range addons.Items {
			switch addon.Name {
			case WorkManagerAddonName, GovernancePolicyFrameworkAddonName, ConfigPolicyAddonName:
				gomega.Expect(CheckAddonStatus(addon)).ToNot(gomega.HaveOccurred())
			case HypershiftAddonName:
				// TODO: is not ready since there is no hyperShiftOperator ?
			default:
				err := fmt.Errorf("unexpected addon: %s", addon.Name)
				gomega.Expect(err).ToNot(gomega.HaveOccurred())
			}
		}
	})
})
