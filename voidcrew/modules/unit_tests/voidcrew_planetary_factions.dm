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

/// A surface cloning vat must not make its player kin to every local hunting target.
/datum/unit_test/voidcrew_planetary_factions_clone/Run()
	var/turf/surface = run_loc_floor_bottom_left
	var/datum/map_footprint/planet = allocate(/datum/map_footprint, null, "planet", 1)
	planet.attach_level(SSmapping.z_list[surface.z])
	planet.set_rect(surface.x, surface.y, 2, 1)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent, surface)
	donor.mind_initialize()
	planet.enable_planetary_faction()
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in donor.faction), "Registering a planet must not ally an existing player body with its wildlife.")
	var/obj/machinery/cloning_vat/vat = allocate(/obj/machinery/cloning_vat, surface)
	vat.do_imprint(donor)
	var/mob/living/carbon/human/clone = vat.create_clone_body()
	allocated += clone
	TEST_ASSERT_NULL(clone.mind, "The fresh clone must be checked before the player's mind arrives.")
	TEST_ASSERT(!(planet.planetary_faction in clone.faction), "A fresh clone inside a surface vat must not inherit the planet's faction.")
	donor.mind.transfer_to(clone)
	clone.forceMove(surface)
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in clone.faction), "A planet's later faction pass must also exclude the claimed clone.")
	TEST_ASSERT(REF(clone) in clone.faction, "The clone must retain its own faction identity.")
	var/mob/living/basic/carp/quarry = allocate(/mob/living/basic/carp, get_step(surface, EAST))
	TEST_ASSERT(planet.planetary_faction in quarry.faction, "The same planet must still ally its native wildlife.")
	var/list/quarry_gates = list(
		/proc/vestige_is_wild_quarry,
		/proc/vestige_comb_quarry,
		/proc/vestige_loom_is_wild_quarry,
		/proc/vestige_is_shambles_quarry,
		/proc/vestige_chrysalis_fauna,
	)
	for(var/quarry_gate in quarry_gates)
		TEST_ASSERT(call(quarry_gate)(quarry, clone), "[quarry_gate] must accept local wildlife for a planet-born clone.")
	quarry.befriend(clone)
	for(var/quarry_gate in quarry_gates)
		TEST_ASSERT(!call(quarry_gate)(quarry, clone), "[quarry_gate] must still reject the clone's own pet.")

/// The Broodwatch reward belongs to its keeper, not the planet where it hatches.
/datum/unit_test/voidcrew_planetary_factions_dragonet/Run()
	var/turf/nest = run_loc_floor_bottom_left
	var/datum/map_footprint/planet = allocate(/datum/map_footprint, null, "planet", 1)
	planet.attach_level(SSmapping.z_list[nest.z])
	planet.set_rect(nest.x, nest.y, 2, 2)
	planet.enable_planetary_faction()
	var/mob/living/carbon/human/keeper = allocate(/mob/living/carbon/human/consistent, get_step(nest, NORTH))
	var/mob/living/basic/carp/pet/vestige_hatchling/dragonet = allocate(/mob/living/basic/carp/pet/vestige_hatchling, nest, keeper)
	var/mob/living/basic/carp/native = allocate(/mob/living/basic/carp, get_step(nest, EAST))
	TEST_ASSERT(!(planet.planetary_faction in dragonet.faction), "A dragonet must not join the planet's native alliance at birth.")
	planet.add_planetary_faction_to_existing_mobs()
	TEST_ASSERT(!(planet.planetary_faction in dragonet.faction), "A later faction pass must not absorb the dragonet into the native alliance.")
	TEST_ASSERT(dragonet.faction_check_atom(keeper), "The constructor must still befriend the dragonet's keeper.")
	var/datum/targeting_strategy/native_strategy = GET_TARGETING_STRATEGY(native.ai_controller.blackboard[BB_TARGETING_STRATEGY])
	TEST_ASSERT(native_strategy.can_attack(native, dragonet), "Native wildlife must still recognize the dragonet as an enemy.")
	var/datum/targeting_strategy/pet_strategy = GET_TARGETING_STRATEGY(dragonet.ai_controller.blackboard[BB_PET_TARGETING_STRATEGY])
	TEST_ASSERT(pet_strategy.can_attack(dragonet, native), "The dragonet must accept attack commands against local wildlife.")
	TEST_ASSERT(!pet_strategy.can_attack(dragonet, keeper), "The dragonet must refuse attack commands against its keeper.")
