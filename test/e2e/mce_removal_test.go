package e2e

import ()

var _ = Describe("Check whether mce has been removed.", Label("multicluster-engine"), func() {
	By("Check whether mce has been removed.")
	Eventually(func() error {
		CheckMCERemoval()
	}).Should(Succeed())

})
