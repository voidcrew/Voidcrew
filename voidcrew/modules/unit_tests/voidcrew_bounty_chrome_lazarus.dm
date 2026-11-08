/// Lazarus on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_lazarus.dm)
/datum/unit_test/voidcrew_bounty_chrome_lazarus

/datum/unit_test/voidcrew_bounty_chrome_lazarus/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["lazarus"], "No Lazarus prototype") // BOUNTY_CHROME_LAZARUS
