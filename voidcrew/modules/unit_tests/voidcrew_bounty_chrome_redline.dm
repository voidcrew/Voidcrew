/// Redline core on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_redline.dm)
/datum/unit_test/voidcrew_bounty_chrome_redline

/datum/unit_test/voidcrew_bounty_chrome_redline/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["redline"], "No Redline core prototype") // BOUNTY_CHROME_REDLINE
