package e2e

import (
	"os"
	"testing"
	"time"

	"github.com/onsi/ginkgo/v2"
	"github.com/onsi/gomega"
	"k8s.io/client-go/tools/clientcmd"
)

var (
	hubKubeConfig string
	HubClients    *Clients
)

const (
	LocalClusterName                   = "local-cluster"
	ConfigPolicyAddonName              = "config-policy-controller"
	GovernancePolicyFrameworkAddonName = "governance-policy-framework"
	HypershiftAddonName                = "hypershift-addon"
	WorkManagerAddonName               = "work-manager"
)

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

	ginkgo.By("Check Hub Ready")
	gomega.Eventually(func() error {
		return nil
	}).Should(gomega.Succeed())

})

var _ = ginkgo.AfterSuite(func() {
	ginkgo.By("clean created resources")
})
