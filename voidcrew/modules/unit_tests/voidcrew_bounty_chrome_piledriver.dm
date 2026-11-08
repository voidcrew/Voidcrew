/// Meteor Piledriver on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_piledriver.dm)
/datum/unit_test/voidcrew_bounty_chrome_piledriver

/datum/unit_test/voidcrew_bounty_chrome_piledriver/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["piledriver"], "No Meteor Piledriver prototype") // BOUNTY_CHROME_PILEDRIVER
