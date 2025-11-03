package e2e

import (
	"context"
	"fmt"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
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

	Context("Create policy and check the policy.", func() {
		var policyName, policyNamespace, policyInClusterName, configurationPolicyName string
		var placementBindingName, placementBindingNamespace string

		BeforeEach(func() {
			By("Apply placementBinding and policy.")
			policy, err := LoadResourceFromJSON(PolicyTemplate)
			Expect(err).ToNot(HaveOccurred())
			_, err = ApplyResource(PolicyGVR, policy)
			Expect(err).ToNot(HaveOccurred())

			placementBinding, err := LoadResourceFromJSON(PlacementBindingTemplate)
			Expect(err).ToNot(HaveOccurred())
			_, err = ApplyResource(PlacementBindingGVR, placementBinding)
			Expect(err).ToNot(HaveOccurred())

			policyName = policy.GetName()
			policyNamespace = policy.GetNamespace()
			configurationPolicyName = "test-pod-policy-nginx-pod"
			policyInClusterName = fmt.Sprintf("%s.%s", policyNamespace, policyName)
			placementBindingName = placementBinding.GetName()
			placementBindingNamespace = placementBinding.GetNamespace()
		})

		AfterEach(func() {
			By("Delete policy")
			err := DeleteResource(PolicyGVR, policyNamespace, policyName)
			Expect(err).ToNot(HaveOccurred())
			err = DeleteResource(PlacementBindingGVR, placementBindingNamespace, placementBindingName)
			Expect(err).ToNot(HaveOccurred())
		})

		It("Check the policy in the cluster ns.", func() {
			Eventually(func() error {
				policyInClusterNs, err := GetResource(PolicyGVR, LocalClusterName, policyInClusterName)
				if err != nil {
					return fmt.Errorf("failed to get policy in local cluster ns. %v", err)
				}
				compliant, found, err := unstructured.NestedString(policyInClusterNs.Object, "status", "compliant")
				if err != nil {
					return fmt.Errorf("failed to get policy in local cluster ns: %v", err)
				}
				if !found {
					return fmt.Errorf("failed found compliant in the status of policy %v", policyInClusterName)
				}
				if compliant != "NonCompliant" {
					return fmt.Errorf("the policy status is not NonCompliant")
				}
				return nil
			}).Should(Succeed())
		})
		It("Check the configurationpolicy in the local cluster ns.", func() {
			Eventually(func() error {
				configurationPolicy, err := GetResource(ConfigurationPolicyGVR, LocalClusterName, configurationPolicyName)
				if err != nil {
					return fmt.Errorf("failed to get configurationPolicy in local cluster ns. %v", err)
				}
				compliant, found, err := unstructured.NestedString(configurationPolicy.Object, "status", "compliant")
				if err != nil {
					return fmt.Errorf("failed to get configurationPolicy in local cluster ns. %v", err)
				}
				if !found {
					return fmt.Errorf("failed found compliant in the status of configurationPolicy %v", configurationPolicyName)
				}
				if compliant != "NonCompliant" {
					return fmt.Errorf("the configurationPolicy status is not NonCompliant")
				}
				return nil
			}).Should(Succeed())
		})
	})
})
