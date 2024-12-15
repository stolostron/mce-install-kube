package e2e

import (
	"fmt"
	"os"
	"testing"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	"k8s.io/client-go/tools/clientcmd"
)

// - KUBECONFIG is the location of the kubeconfig file to use
// - MANAGED_CLUSTER_NAME is the name of managed cluster
func TestE2E(tt *testing.T) {
	OutputFail := func(message string, callerSkip ...int) {
		Fail(message, callerSkip...)
	}

	RegisterFailHandler(OutputFail)
	RunSpecs(tt, "ocm E2E Suite")
}

var _ = BeforeSuite(func() {
	HostedClusterName = os.Getenv("MANAGED_CLUSTER_NAME")

	if hubKubeConfig == "" {
		hubKubeConfig = os.Getenv("KUBECONFIG")
	}
	Expect(hubKubeConfig).ToNot(BeEmpty())

	clusterCfg, err := clientcmd.BuildConfigFromFlags("", hubKubeConfig)
	Expect(err).ToNot(HaveOccurred())

	HubClients, err = NewClients(clusterCfg)
	Expect(err).ToNot(HaveOccurred())

	Default.SetDefaultEventuallyTimeout(90 * time.Second)
	Default.SetDefaultEventuallyPollingInterval(5 * time.Second)

	By("Check if MCE is Ready")
	Eventually(func() error {
		return CheckMCE()
	}).Should(Succeed())
})

var _ = AfterSuite(func() {
	By("clean created resources")
})

var _ = ReportAfterSuite("MCE on ARO E2E Test Report", func(report Report) {
	junitReportFile := os.Getenv("JUNIT_REPORT_FILE")
	if junitReportFile != "" {
		err := GenerateJUnitReport(report, junitReportFile)
		if err != nil {
			fmt.Printf("Failed to generate the report due to: %v", err)
		}
	}
})
