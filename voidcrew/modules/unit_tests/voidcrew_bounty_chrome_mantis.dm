/// Mantis Blades on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_mantis.dm)
/datum/unit_test/voidcrew_bounty_chrome_mantis

/datum/unit_test/voidcrew_bounty_chrome_mantis/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["mantis"], "No Mantis Blades prototype") // BOUNTY_CHROME_MANTIS
