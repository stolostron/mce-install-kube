package e2e

import ()

var _ = Describe("Check the status of mce.", Label("multicluster-engine"), func() {
	By("Check the status of mce.")
	Eventually(func() error {
		CheckMCE()
	}).Should(Succeed())

})
