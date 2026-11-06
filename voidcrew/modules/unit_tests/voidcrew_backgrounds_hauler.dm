/// Backgrounds: owned by P5. See data/backgrounds/spec.md.

/// Placeholder until the package's own tests land
/datum/unit_test/voidcrew_backgrounds_hauler_placeholder

/datum/unit_test/voidcrew_backgrounds_hauler_placeholder/Run()
	TEST_ASSERT_EQUAL(length(hauler_live_haulers()), 0, "Haulers exist before the hauler package")
