/**
 * Planet-native factions are additive, per footprint, and independent of spawn source.
 *
 * This models the reported wasteland-bar case: a mapped hermit with a `saloon` override
 * exists before its planet is registered, then a pirate is spawned there later. They must
 * retain those distinct role factions while sharing the planet alliance. A pirate born on
 * a second footprint on the same z-level must not receive the first planet's alliance.
 */
/datum/unit_test/voidcrew_planetary_factions

/datum/unit_test/voidcrew_planetary_factions/Run()
	var/datum/space_level/test_level = SSmapping.z_list[run_loc_floor_bottom_left.z]
	if(!test_level)
		TEST_FAIL("The unit-test z-level has no /datum/space_level to attach footprints to")
		return

	// String literals because voidcrew defines are included after the unit-test files in
	// the DME. set_rect() reduces each temporary planet to one unambiguous test tile.
	var/datum/map_footprint/bar_planet = allocate(/datum/map_footprint, null, "planet", 1)
	bar_planet.attach_level(test_level)
	bar_planet.set_rect(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y, 1, 1)

	var/datum/map_footprint/distant_planet = allocate(/datum/map_footprint, null, "planet", 2)
	distant_planet.attach_level(test_level)
	distant_planet.set_rect(run_loc_floor_top_right.x, run_loc_floor_top_right.y, 1, 1)
	distant_planet.enable_planetary_faction()

	// This represents a mob already initialized from a preloaded ruin before the planet's
	// footprint was enabled. The mapped override replaces its normal type factions.
	var/mob/living/simple_animal/hostile/asteroid/hermit/survivor/mapped_hermit = allocate(
		/mob/living/simple_animal/hostile/asteroid/hermit/survivor,
		run_loc_floor_bottom_left,
	)
	mapped_hermit.faction = list("saloon", "[REF(mapped_hermit)]")

	bar_planet.enable_planetary_faction()
	bar_planet.add_planetary_faction_to_existing_mobs()

	// These two go through /mob/living/Initialize after both footprint factions exist.
	var/mob/living/basic/trooper/pirate/melee/local_pirate = allocate(
		/mob/living/basic/trooper/pirate/melee,
		run_loc_floor_bottom_left,
	)
	var/mob/living/basic/trooper/pirate/melee/distant_pirate = allocate(
		/mob/living/basic/trooper/pirate/melee,
		run_loc_floor_top_right,
	)

	TEST_ASSERT(bar_planet.planetary_faction != distant_planet.planetary_faction, \
		"Two planetary footprints generated the same native faction token")
	TEST_ASSERT("saloon" in mapped_hermit.faction, \
		"The preloaded hermit's mapped saloon faction was replaced by the planet faction")
	TEST_ASSERT("pirate" in local_pirate.faction, \
		"The dynamically spawned pirate lost its pirate role faction")
	TEST_ASSERT(bar_planet.planetary_faction in mapped_hermit.faction, \
		"The preloaded hermit did not receive its footprint's planet faction")
	TEST_ASSERT(bar_planet.planetary_faction in local_pirate.faction, \
		"A mob created on the bar planet did not inherit its footprint faction")
	TEST_ASSERT(distant_planet.planetary_faction in distant_pirate.faction, \
		"A mob created on the second planet did not inherit that footprint's faction")
	TEST_ASSERT(!(bar_planet.planetary_faction in distant_pirate.faction), \
		"A mob on the second footprint inherited the neighbouring planet's faction")
	TEST_ASSERT(mapped_hermit.faction_check_atom(local_pirate), \
		"The saloon hermit and dynamically spawned pirate on one planet still consider each other hostile")
	TEST_ASSERT(!mapped_hermit.faction_check_atom(distant_pirate), \
		"The saloon hermit became friendly with a mob on a different planetary footprint")
