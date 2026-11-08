/// Deadeye optics on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_deadeye.dm)
/datum/unit_test/voidcrew_bounty_chrome_deadeye

/datum/unit_test/voidcrew_bounty_chrome_deadeye/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["deadeye"], "No Deadeye optics prototype") // BOUNTY_CHROME_DEADEYE
