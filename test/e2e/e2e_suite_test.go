package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	hubKubeConfig     string
	HubClients        *Clients
	HostedClusterName string
)

const (
	LocalClusterName                   = "local-cluster"
	ConfigPolicyAddonName              = "config-policy-controller"
	GovernancePolicyFrameworkAddonName = "governance-policy-framework"
	HypershiftAddonName                = "hypershift-addon"
	WorkManagerAddonName               = "work-manager"
	mceName                            = "multiclusterengine"
)

var mceGVR = schema.GroupVersionResource{Group: "multicluster.openshift.io", Version: "v1", Resource: "multiclusterengines"}

// - KUBECONFIG is the location of the kubeconfig file to use
// - MANAGED_CLUSTER_NAME is the name of managed cluster
func TestE2E(tt *testing.T) {
	OutputFail := func(message string, callerSkip ...int) {
		ginkgo.Fail(message, callerSkip...)
	}

	gomega.RegisterFailHandler(OutputFail)
	ginkgo.RunSpecs(tt, "ocm E2E Suite")
}

var _ = ginkgo.BeforeSuite(func() {
	if hubKubeConfig == "" {
		hubKubeConfig = os.Getenv("KUBECONFIG")
	}
	gomega.Expect(hubKubeConfig).ToNot(gomega.BeEmpty())

	clusterCfg, err := clientcmd.BuildConfigFromFlags("", hubKubeConfig)
	gomega.Expect(err).ToNot(gomega.HaveOccurred())

	HubClients, err = NewClients(clusterCfg)
	gomega.Expect(err).ToNot(gomega.HaveOccurred())

	gomega.Default.SetDefaultEventuallyTimeout(90 * time.Second)
	gomega.Default.SetDefaultEventuallyPollingInterval(5 * time.Second)

	ginkgo.By("Check if MCE is Ready")
	gomega.Eventually(func() error {
		mce, err := HubClients.DynamicClient.Resource(mceGVR).Get(context.TODO(), mceName, metav1.GetOptions{})
		if err != nil {
			return fmt.Errorf("failed to get mce: %v", err)
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
	}).Should(gomega.Succeed())
})

var _ = ginkgo.AfterSuite(func() {
	ginkgo.By("clean created resources")
})

var _ = ginkgo.ReportAfterSuite("MCE on ARO E2E Test Report", func(report ginkgo.Report) {
	junitReportFile := os.Getenv("JUNIT_REPORT_FILE")
	if junitReportFile != "" {
		err := GenerateJUnitReport(report, junitReportFile)
		if err != nil {
			fmt.Printf("Failed to generate the report due to: %v", err)
		}
	}
})
