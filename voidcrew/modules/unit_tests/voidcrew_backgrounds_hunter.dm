/// Backgrounds: owned by P3. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_hunter_placeholder

/datum/unit_test/voidcrew_backgrounds_hunter_placeholder/Run()
	var/datum/background/background = background_by_key("bounty_hunter") // BACKGROUND_BOUNTY_HUNTER
	TEST_ASSERT_NOTNULL(background, "No background is registered under \"bounty_hunter\"")
	TEST_ASSERT_EQUAL(background.name, "Bounty Hunter", "The bounty_hunter background has the wrong name")
