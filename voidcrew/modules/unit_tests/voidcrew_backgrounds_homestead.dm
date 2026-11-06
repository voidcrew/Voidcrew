/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_homestead_placeholder

/datum/unit_test/voidcrew_backgrounds_homestead_placeholder/Run()
	var/datum/background/background = background_by_key("homesteader") // BACKGROUND_HOMESTEADER
	TEST_ASSERT_NOTNULL(background, "No background is registered under \"homesteader\"")
	TEST_ASSERT_EQUAL(background.name, "Homesteader", "The homesteader background has the wrong name")
