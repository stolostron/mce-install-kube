package e2e

import (
	"context"
	"fmt"
	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
)

var _ = Describe("Check the status of hosted cluster.", Label("hosted cluster"), Ordered, func() {
	BeforeEach(func() {
		if HostedClusterName == "" {
			Skip("There is no hosted cluster.")
		}

		By(fmt.Sprintf("Check the status of the hosted cluster %s.", HostedClusterName))
		Eventually(func() error {
			cluster, err := HubClients.ClusterClient.ClusterV1().ManagedClusters().Get(context.Background(),
				HostedClusterName, metav1.GetOptions{})
			if err != nil {
				return fmt.Errorf("failed get hosted cluster: %v", err)
			}
			return CheckManagedClusterStatus(cluster)
		}).Should(Succeed())

		By(fmt.Sprintf("Check the status of addons on the hosted cluster %s.", HostedClusterName))
		Eventually(func() error {
			addons, err := HubClients.AddonClient.AddonV1alpha1().ManagedClusterAddOns(HostedClusterName).
				List(context.Background(), metav1.ListOptions{})
			if err != nil {
				return fmt.Errorf("failed list addons: %v", err)
			}

			if len(addons.Items) != 3 {
				return fmt.Errorf("expect 3 addons but got %v", len(addons.Items))
			}

			for _, addon := range addons.Items {
				switch addon.Name {
				case WorkManagerAddonName, GovernancePolicyFrameworkAddonName, ConfigPolicyAddonName:
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
				return CheckManagedClusterInfo(HostedClusterName)
			}).Should(Succeed())
		})
	})

	Context("Create policy and check the policy.", func() {
		var policyName, policyNamespace, policyInClusterName string
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
				policyInClusterNs, err := GetResource(PolicyGVR, HostedClusterName, policyInClusterName)
				if err != nil {
					return fmt.Errorf("failed to get policy in hosted cluster ns %v. %v", HostedClusterName, err)
				}
				compliant, found, err := unstructured.NestedString(policyInClusterNs.Object, "status", "compliant")
				if err != nil {
					return fmt.Errorf("failed to get policy in hosted cluster ns %v: %v", HostedClusterName, err)
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
		It("Check the policy in the klusterlet ns.", func() {
			Eventually(func() error {
				klusterletNs := fmt.Sprintf("klusterlet-%s", HostedClusterName)
				policyInKlusterletNs, err := GetResource(PolicyGVR, klusterletNs, policyInClusterName)
				if err != nil {
					return fmt.Errorf("failed to get policy in klusterlet ns %v. %v", klusterletNs, err)
				}
				compliant, found, err := unstructured.NestedString(policyInKlusterletNs.Object, "status", "compliant")
				if err != nil {
					return fmt.Errorf("failed to get policy in klusterlet ns %v. %v", klusterletNs, err)
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
	})
})
