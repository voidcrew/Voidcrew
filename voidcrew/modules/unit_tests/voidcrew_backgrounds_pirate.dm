/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_pirate_placeholder

/datum/unit_test/voidcrew_backgrounds_pirate_placeholder/Run()
	var/datum/background/background = background_by_key("pirate") // BACKGROUND_PIRATE
	TEST_ASSERT_NOTNULL(background, "No background is registered under \"pirate\"")
	TEST_ASSERT_EQUAL(background.name, "Pirate", "The pirate background has the wrong name")
