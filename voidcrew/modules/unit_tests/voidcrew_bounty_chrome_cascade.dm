/// Cascade lattice on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_cascade.dm)
/datum/unit_test/voidcrew_bounty_chrome_cascade

/datum/unit_test/voidcrew_bounty_chrome_cascade/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["cascade"], "No Cascade lattice prototype") // BOUNTY_CHROME_CASCADE
