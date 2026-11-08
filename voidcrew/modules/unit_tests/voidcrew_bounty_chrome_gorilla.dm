/// Gorilla Arms on a bounty fighter (voidcrew/modules/bounties/chrome/bounty_chrome_gorilla.dm)
/datum/unit_test/voidcrew_bounty_chrome_gorilla

/datum/unit_test/voidcrew_bounty_chrome_gorilla/Run()
	TEST_ASSERT_NOTNULL(GLOB.bounty_chrome_protos["gorilla"], "No Gorilla Arms prototype") // BOUNTY_CHROME_GORILLA
