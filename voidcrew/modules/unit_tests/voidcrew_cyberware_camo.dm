/**
 * Cyberware phase 2: optical camo hides its bearer from more than basic mobs.
 *
 * The Ghostskin weave (and anything else that grants TRAIT_CYBER_CAMO) is also invisible to
 * simple_animal hostiles, every porta_turret, the outpost experiments and the club's mobsters,
 * beyond CYBERWARE_CAMO_SPOT_RANGE, except to megafauna, elites and bosses. The street
 * Flickerskin grants no trait, so none of this applies to it. voidcrew/modules/cyberware/
 * cyberware_stealth.dm owns the helper and most of the hooks.
 *
 * Literals (unit tests are included before the fork's defines): the trait is TRAIT_CYBER_CAMO
 * ("cyber_camo"); the spot range is CYBERWARE_CAMO_SPOT_RANGE (2). The test room is 5x5, so the
 * far corner is 4 tiles from the near one. Every mob and turret here is clientless: this proves
 * the targeting gates, not how an AI walks.
 */

/// Shared helpers; not a test itself
/datum/unit_test/voidcrew_cyberware_camo
	abstract_type = /datum/unit_test/voidcrew_cyberware_camo

/// The floor `dx`, `dy` tiles from the test room's bottom-left corner
/datum/unit_test/voidcrew_cyberware_camo/proc/spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A human wearing `weave_type` with its field up
/datum/unit_test/voidcrew_cyberware_camo/proc/cloaked_human(weave_type, turf/where)
	var/mob/living/carbon/human/consistent/bearer = allocate(/mob/living/carbon/human/consistent, where)
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = allocate(weave_type)
	TEST_ASSERT(weave.Insert(bearer, special = TRUE), "[weave_type] staging insert was refused")
	weave.engage_camo(bearer)
	TEST_ASSERT(weave.camo_active, "[weave_type] never raised its field")
	return bearer

/// The helper itself: range, trait, null viewer, non-living target, and who sees through
/datum/unit_test/voidcrew_cyberware_camo/helper

/datum/unit_test/voidcrew_cyberware_camo/helper/Run()
	var/mob/living/carbon/human/consistent/bearer = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	var/mob/living/simple_animal/hostile/megafauna/boss = allocate(/mob/living/simple_animal/hostile/megafauna, spot(0, 0))
	var/mob/living/basic/bystander = allocate(/mob/living/basic, spot(0, 0))
	TEST_ASSERT(!cyberware_camo_hides(bearer, bystander), "A bearer with no field was hidden")

	ADD_TRAIT(bearer, "cyber_camo", "camo_helper_test")
	TEST_ASSERT(cyberware_camo_hides(bearer, bystander), "A camo'd bearer, 4 tiles off, was not hidden")
	TEST_ASSERT(cyberware_camo_hides(bearer, null), "A camo'd bearer was not hidden from nobody in particular")
	TEST_ASSERT(!cyberware_camo_hides(bearer, boss), "A megafauna was fooled by camo")
	TEST_ASSERT(!cyberware_camo_hides(null, bystander), "A null target was hidden")
	TEST_ASSERT(!cyberware_camo_hides(allocate(/obj/item), bystander), "An object was hidden")

	// The spot range is inclusive: 3 tiles hides, 2 does not.
	bearer.forceMove(spot(3, 0))
	TEST_ASSERT(cyberware_camo_hides(bearer, bystander), "A camo'd bearer 3 tiles off was spotted")
	bearer.forceMove(spot(2, 0))
	TEST_ASSERT(!cyberware_camo_hides(bearer, bystander), "A camo'd bearer 2 tiles off stayed hidden")
	bearer.forceMove(spot(1, 1))
	TEST_ASSERT(!cyberware_camo_hides(bearer, bystander), "A camo'd bearer 1 tile off stayed hidden")
	REMOVE_TRAIT(bearer, "cyber_camo", "camo_helper_test")

	// Everything in the list sees through it, and so do its subtypes.
	var/static/list/piercing = list(
		/mob/living/simple_animal/hostile/megafauna/bubblegum,
		/mob/living/simple_animal/hostile/asteroid/elite/herald,
		/mob/living/basic/boss/thing,
		/mob/living/basic/lich,
		/mob/living/basic/hoarfrost_matriarch,
		/mob/living/basic/bounty_criminal/boss/ghost,
		/mob/living/basic/bounty_criminal/kingpin,
		/mob/living/basic/bounty_lair_boss/mafia_don,
		/mob/living/basic/outpost_experiment/horror,
		/mob/living/basic/alien/queen/large/derelict,
		/mob/living/basic/vestige_oracle,
		/mob/living/basic/vestige_mutant,
		/mob/living/basic/vestige_warframe,
	)
	for(var/seer_type in piercing)
		TEST_ASSERT(is_type_in_typecache(seer_type, GLOB.cyberware_camo_piercing_types), "[seer_type] is fooled by camo")
	var/static/list/fooled = list(
		/mob/living/simple_animal/hostile/asteroid/hermit,
		/mob/living/simple_animal/hostile/asteroid/old_demon,
		/mob/living/simple_animal/hostile/asteroid/polarbear,
		/mob/living/basic/trooper/russian/mafia,
		/mob/living/basic/outpost_experiment/hulk,
	)
	for(var/fooled_type in fooled)
		TEST_ASSERT(!is_type_in_typecache(fooled_type, GLOB.cyberware_camo_piercing_types), "[fooled_type] sees through camo and shouldn't")

/// Simple animal hostiles: fooled beyond range, not by megafauna, not by the street weave, and
/// whoever strikes from under the field is seen again.
/datum/unit_test/voidcrew_cyberware_camo/hostiles

/datum/unit_test/voidcrew_cyberware_camo/hostiles/Run()
	var/mob/living/simple_animal/hostile/asteroid/hermit/survivor/hermit = allocate(/mob/living/simple_animal/hostile/asteroid/hermit/survivor, spot(0, 0))
	var/mob/living/simple_animal/hostile/megafauna/boss = allocate(/mob/living/simple_animal/hostile/megafauna, spot(0, 1))
	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT(hermit.CanAttack(plain), "Fixture: the hermit won't pick a plain human to begin with")
	TEST_ASSERT(boss.CanAttack(plain), "Fixture: the megafauna won't pick a plain human to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(!hermit.CanAttack(ghost), "A hermit picked a camo'd human 4 tiles off")
	TEST_ASSERT(boss.CanAttack(ghost), "A megafauna was fooled by a camo'd human")
	ghost.forceMove(spot(0, 2))
	TEST_ASSERT(hermit.CanAttack(ghost), "A hermit missed a camo'd human 2 tiles off")
	ghost.forceMove(spot(4, 4))
	TEST_ASSERT(!hermit.CanAttack(ghost), "A hermit that lost sight of a camo'd human picked them up again")

	// A hostile already chasing loses the target the moment the field goes up: FindTarget and
	// MoveToTarget both ask CanAttack().
	hermit.target = ghost
	TEST_ASSERT(!hermit.CanAttack(hermit.target), "A hermit kept chasing a human who cloaked")
	hermit.target = null

	// Striking from under the field drops it, so retaliation still lands.
	SEND_SIGNAL(ghost, COMSIG_MOB_FIRED_GUN)
	TEST_ASSERT(!HAS_TRAIT(ghost, "cyber_camo"), "Firing a gun didn't drop the field")
	TEST_ASSERT(hermit.CanAttack(ghost), "A hermit couldn't retaliate against someone who fired from under the field")

	// Throwing from under the field drops it too: a thrown brick is an attack like any other.
	var/mob/living/carbon/human/consistent/pitcher = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(HAS_TRAIT(pitcher, "cyber_camo"), "Fixture: the second Ghostskin bearer isn't camo'd")
	SEND_SIGNAL(pitcher, COMSIG_MOB_THROW, spot(0, 0))
	TEST_ASSERT(!HAS_TRAIT(pitcher, "cyber_camo"), "Throwing didn't drop the field")

	// The street weave never grants the trait, so nothing here hides it.
	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 4))
	TEST_ASSERT(!HAS_TRAIT(flicker, "cyber_camo"), "The Flickerskin granted the camo trait")
	TEST_ASSERT(hermit.CanAttack(flicker), "A hermit was fooled by the Flickerskin")
	TEST_ASSERT(boss.CanAttack(flicker), "A megafauna was fooled by the Flickerskin")

/// Every turret type that can be handed a camo'd human drops them from the list it shoots at.
/// tryToShootAt() returns 1 once it has settled on a target, and nothing when it has none.
/datum/unit_test/voidcrew_cyberware_camo/turrets

/datum/unit_test/voidcrew_cyberware_camo/turrets/Run()
	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(3, 4))

	var/static/list/turret_types = list(
		/obj/machinery/porta_turret,
		/obj/machinery/porta_turret/ai,
		/obj/machinery/porta_turret/ruin,
		/obj/machinery/porta_turret/syndicate,
		/obj/machinery/porta_turret/outpost,
		/obj/machinery/porta_turret/ship_defense,
	)
	for(var/turret_type in turret_types)
		var/obj/machinery/porta_turret/turret = allocate(turret_type, spot(0, 0))
		// Unanchored, popUp() and shootAt() are no-ops: the test asks who it picks, not to be shot at.
		turret.anchored = FALSE
		TEST_ASSERT(turret.tryToShootAt(list(plain)), "[turret_type] skipped a plain human")
		TEST_ASSERT(!turret.tryToShootAt(list(ghost)), "[turret_type] picked a camo'd human 4 tiles off")
		TEST_ASSERT(turret.tryToShootAt(list(flicker)), "[turret_type] skipped a Flickerskin bearer")
		// Camo only takes the hidden one out of a mixed list.
		TEST_ASSERT(turret.tryToShootAt(list(ghost, plain)), "[turret_type] gave up on a list with a plain human in it")
		// Inside the spot range they are seen.
		ghost.forceMove(spot(0, 2))
		TEST_ASSERT(turret.tryToShootAt(list(ghost)), "[turret_type] missed a camo'd human 2 tiles off")
		ghost.forceMove(spot(4, 4))

/// The experiments' own strategy (it never calls the basic one): a creature picks a plain person,
/// not a camo'd one beyond range.
/datum/unit_test/voidcrew_cyberware_camo/experiments

/datum/unit_test/voidcrew_cyberware_camo/experiments/Run()
	var/mob/living/basic/outpost_experiment/hulk/creature = allocate(/mob/living/basic/outpost_experiment/hulk, spot(0, 0))
	var/datum/targeting_strategy/outpost_experiment/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/outpost_experiment)
	TEST_ASSERT_NOTNULL(strategy, "The experiments' targeting strategy is gone")

	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT(strategy.can_attack(creature, plain), "Fixture: an experiment won't target a plain human to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(!strategy.can_attack(creature, ghost), "An experiment targeted a camo'd human 4 tiles off")
	TEST_ASSERT(!creature.can_target(ghost), "An experiment would pick a camo'd human 4 tiles off")
	ghost.forceMove(spot(2, 0))
	TEST_ASSERT(strategy.can_attack(creature, ghost), "An experiment missed a camo'd human 2 tiles off")
	ghost.forceMove(spot(4, 4))

	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	TEST_ASSERT(strategy.can_attack(creature, flicker), "An experiment was fooled by the Flickerskin")

/// The club's mobsters: the scripted pick, mafia_target_ok(), skips a camo'd hunter beyond range.
/datum/unit_test/voidcrew_cyberware_camo/mobsters

/datum/unit_test/voidcrew_cyberware_camo/mobsters/Run()
	var/mob/living/basic/trooper/russian/mafia/pistol/gunman = allocate(/mob/living/basic/trooper/russian/mafia/pistol, spot(0, 0))
	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	plain.mind_initialize()
	TEST_ASSERT(gunman.mafia_target_ok(plain), "Fixture: a goon won't go after a plain hunter to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	ghost.mind_initialize()
	TEST_ASSERT(!gunman.mafia_target_ok(ghost), "A goon went after a camo'd hunter 4 tiles off")
	ghost.forceMove(spot(0, 2))
	TEST_ASSERT(gunman.mafia_target_ok(ghost), "A goon missed a camo'd hunter 2 tiles off")
	ghost.forceMove(spot(4, 4))

	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	flicker.mind_initialize()
	TEST_ASSERT(gunman.mafia_target_ok(flicker), "A goon was fooled by the Flickerskin")
