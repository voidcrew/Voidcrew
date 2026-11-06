/// Backgrounds: owned by P2. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_convict_placeholder

/datum/unit_test/voidcrew_backgrounds_convict_placeholder/Run()
	var/datum/background/background = background_by_key("convict") // BACKGROUND_CONVICT
	TEST_ASSERT_NOTNULL(background, "No background is registered under \"convict\"")
	TEST_ASSERT_EQUAL(background.name, "Convict", "The convict background has the wrong name")
