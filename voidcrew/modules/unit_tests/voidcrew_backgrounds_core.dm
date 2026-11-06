/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_core_placeholder

/datum/unit_test/voidcrew_backgrounds_core_placeholder/Run()
	var/datum/background/background = background_by_key("spacefarer") // BACKGROUND_SPACEFARER
	TEST_ASSERT_NOTNULL(background, "No background is registered under \"spacefarer\"")
	TEST_ASSERT_EQUAL(background.name, "Spacefarer", "The spacefarer background has the wrong name")
