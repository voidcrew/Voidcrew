/**
 * Cyberware phase 2: optical camo hides its bearer from more than basic mobs.
 *
 * The Ghostskin weave (and anything else that grants TRAIT_CYBER_CAMO) is also invisible to
 * human NPCs (their targeting strategy, pirate crews included), simple_animal hostiles, every
 * porta_turret, the outpost experiment forms and the club's people, beyond
 * CYBERWARE_CAMO_SPOT_RANGE, except to megafauna, elites and bosses (human NPCs of boss rank).
 * The street Flickerskin grants no trait, so none of this applies to it. voidcrew/modules/
 * cyberware/cyberware_stealth.dm owns the helper and most of the hooks.
 *
 * Literals (unit tests are included before the fork's defines): the trait is TRAIT_CYBER_CAMO
 * ("cyber_camo"); the spot range is CYBERWARE_CAMO_SPOT_RANGE (2); HUMAN_NPC_RANK_BOSS is 2.
 * The test room is 5x5, so the far corner is 4 tiles from the near one. Every mob and turret here
 * is clientless and every human NPC has its AI switched off: this proves the targeting gates, not
 * how an AI walks.
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

/// A human NPC of `npc_type` at `where`, built the way the spawn queue builds one, with its AI off
/datum/unit_test/voidcrew_cyberware_camo/proc/human_npc(npc_type, turf/where)
	var/datum/human_npc_order/order = spawn_human_npc(npc_type, where, immediate = TRUE)
	var/mob/living/carbon/human/npc/npc = order?.spawned_ref?.resolve()
	TEST_ASSERT_NOTNULL(npc, "[npc_type] wasn't built")
	allocated += npc
	npc.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return npc

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
		/mob/living/basic/trooper/pirate/faction/boss,
		/mob/living/basic/bounty_lair_boss/mafia_mech,
		/mob/living/basic/outpost_experiment/horror,
		/mob/living/basic/alien/queen/large/derelict,
		/mob/living/basic/vestige_oracle,
		/mob/living/basic/vestige_mutant,
		/mob/living/basic/vestige_warframe,
	)
	for(var/seer_type in piercing)
		TEST_ASSERT(is_type_in_typecache(seer_type, GLOB.cyberware_camo_piercing_types), "[seer_type] is fooled by camo")
	var/static/list/fooled = list(
		/mob/living/simple_animal/hostile/asteroid/old_demon,
		/mob/living/simple_animal/hostile/asteroid/polarbear,
		/mob/living/carbon/human/npc,
	)
	for(var/fooled_type in fooled)
		TEST_ASSERT(!is_type_in_typecache(fooled_type, GLOB.cyberware_camo_piercing_types), "[fooled_type] sees through camo and shouldn't")

	// Bosses that are people see through it by rank, not by type: every human NPC boss is rank 2.
	var/static/list/human_bosses = list(
		/mob/living/carbon/human/npc/faction_pirate/silverscale/boss,
		/mob/living/carbon/human/npc/faction_pirate/skeleton/boss,
		/mob/living/carbon/human/npc/faction_pirate/grey/boss,
		/mob/living/carbon/human/npc/faction_pirate/lustrous/boss,
		/mob/living/carbon/human/npc/faction_pirate/interdyne/boss,
		/mob/living/carbon/human/npc/faction_pirate/irs/boss,
		/mob/living/carbon/human/npc/faction_pirate/medieval/boss,
		/mob/living/carbon/human/npc/faction_pirate/nt_customs/director,
		/mob/living/carbon/human/npc/bounty_criminal/boss/ghost,
		/mob/living/carbon/human/npc/bounty_criminal/kingpin,
		/mob/living/carbon/human/npc/bounty_mafia/don,
	)
	for(var/mob/living/carbon/human/npc/boss_type as anything in human_bosses)
		TEST_ASSERT_EQUAL(initial(boss_type.npc_rank), 2, "[boss_type] isn't boss rank, so camo fools it")
	var/static/list/human_regulars = list(
		/mob/living/carbon/human/npc/faction_pirate/silverscale/captain,
		/mob/living/carbon/human/npc/faction_pirate/grey/ranged,
		/mob/living/carbon/human/npc/bounty_mafia/pistol,
		/mob/living/carbon/human/npc/bounty_mafia/lieutenant,
	)
	for(var/mob/living/carbon/human/npc/regular_type as anything in human_regulars)
		TEST_ASSERT(initial(regular_type.npc_rank) < 2, "[regular_type] is boss rank and sees through camo")

/// Simple animal hostiles: fooled beyond range, not by megafauna, not by the street weave, and
/// whoever strikes from under the field is seen again. (The hermits are people now, so a polar
/// bear stands in for them.)
/datum/unit_test/voidcrew_cyberware_camo/hostiles

/datum/unit_test/voidcrew_cyberware_camo/hostiles/Run()
	var/mob/living/simple_animal/hostile/asteroid/polarbear/bear = allocate(/mob/living/simple_animal/hostile/asteroid/polarbear, spot(0, 0))
	var/mob/living/simple_animal/hostile/megafauna/boss = allocate(/mob/living/simple_animal/hostile/megafauna, spot(0, 1))
	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT(bear.CanAttack(plain), "Fixture: the bear won't pick a plain human to begin with")
	TEST_ASSERT(boss.CanAttack(plain), "Fixture: the megafauna won't pick a plain human to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(!bear.CanAttack(ghost), "A bear picked a camo'd human 4 tiles off")
	TEST_ASSERT(boss.CanAttack(ghost), "A megafauna was fooled by a camo'd human")
	ghost.forceMove(spot(0, 2))
	TEST_ASSERT(bear.CanAttack(ghost), "A bear missed a camo'd human 2 tiles off")
	ghost.forceMove(spot(4, 4))
	TEST_ASSERT(!bear.CanAttack(ghost), "A bear that lost sight of a camo'd human picked them up again")

	// A hostile already chasing loses the target the moment the field goes up: FindTarget and
	// MoveToTarget both ask CanAttack().
	bear.target = ghost
	TEST_ASSERT(!bear.CanAttack(bear.target), "A bear kept chasing a human who cloaked")
	bear.target = null

	// Striking from under the field drops it, so retaliation still lands.
	SEND_SIGNAL(ghost, COMSIG_MOB_FIRED_GUN)
	TEST_ASSERT(!HAS_TRAIT(ghost, "cyber_camo"), "Firing a gun didn't drop the field")
	TEST_ASSERT(bear.CanAttack(ghost), "A bear couldn't retaliate against someone who fired from under the field")

	// Throwing from under the field drops it too: a thrown brick is an attack like any other.
	var/mob/living/carbon/human/consistent/pitcher = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(HAS_TRAIT(pitcher, "cyber_camo"), "Fixture: the second Ghostskin bearer isn't camo'd")
	SEND_SIGNAL(pitcher, COMSIG_MOB_THROW, spot(0, 0))
	TEST_ASSERT(!HAS_TRAIT(pitcher, "cyber_camo"), "Throwing didn't drop the field")

	// A weave knocked into a reboot drops its field too.
	var/mob/living/carbon/human/consistent/glitched = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	var/obj/item/organ/cyberimp/cyberware/ghostskin/weave = locate() in glitched.organs
	var/datum/component/cyberware/chrome = weave?.GetComponent(/datum/component/cyberware)
	TEST_ASSERT_NOTNULL(chrome, "Fixture: the Ghostskin has no chrome component")
	chrome.start_emp_reboot(EMP_HEAVY)
	TEST_ASSERT(!weave.camo_active, "A rebooting weave kept its field up")
	TEST_ASSERT(!HAS_TRAIT(glitched, "cyber_camo"), "A rebooting weave left its bearer hidden from mobs")

	// The street weave never grants the trait, so nothing here hides it.
	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 4))
	TEST_ASSERT(!HAS_TRAIT(flicker, "cyber_camo"), "The Flickerskin granted the camo trait")
	TEST_ASSERT(bear.CanAttack(flicker), "A bear was fooled by the Flickerskin")
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

/// Human NPCs: tg's basic targeting through the human NPC strategy, which pirate crews and boarders,
/// ruin troopers and the club's people all run on. A regular NPC is fooled beyond range; a boss
/// (by rank) is not; the street weave fools nobody.
/datum/unit_test/voidcrew_cyberware_camo/human_npcs

/datum/unit_test/voidcrew_cyberware_camo/human_npcs/Run()
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/basic/human_npc)
	TEST_ASSERT_NOTNULL(strategy, "The human NPC targeting strategy is gone")
	var/mob/living/carbon/human/npc/gunner = human_npc(/mob/living/carbon/human/npc/faction_pirate/grey/ranged, spot(0, 0))
	var/mob/living/carbon/human/npc/boss = human_npc(/mob/living/carbon/human/npc/faction_pirate/grey/boss, spot(0, 1))
	var/mob/living/carbon/human/npc/director = human_npc(/mob/living/carbon/human/npc/faction_pirate/nt_customs/director, spot(1, 0))
	TEST_ASSERT_EQUAL(gunner.ai_controller?.blackboard[BB_TARGETING_STRATEGY], /datum/targeting_strategy/basic/human_npc, "A pirate gunner doesn't target through the human NPC strategy")

	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT(strategy.can_attack(gunner, plain), "Fixture: a pirate gunner won't target a plain human to begin with")
	TEST_ASSERT(strategy.can_attack(boss, plain), "Fixture: a pirate boss won't target a plain human to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(!strategy.can_attack(gunner, ghost), "A pirate gunner targeted a camo'd human 4 tiles off")
	TEST_ASSERT(cyberware_camo_hides(ghost, gunner), "Camo didn't hide its bearer from a pirate gunner")
	TEST_ASSERT(strategy.can_attack(boss, ghost), "A pirate boss was fooled by camo")
	TEST_ASSERT(!cyberware_camo_hides(ghost, director), "The NT patrol's director was fooled by camo")
	ghost.forceMove(spot(2, 0))
	TEST_ASSERT(strategy.can_attack(gunner, ghost), "A pirate gunner missed a camo'd human 2 tiles off")
	ghost.forceMove(spot(4, 4))

	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	TEST_ASSERT(strategy.can_attack(gunner, flicker), "A pirate gunner was fooled by the Flickerskin")

/// The experiment forms' own strategy (it never calls the basic one): a serum-turned body picks a
/// plain person, not a camo'd one beyond range.
/datum/unit_test/voidcrew_cyberware_camo/experiments

/datum/unit_test/voidcrew_cyberware_camo/experiments/Run()
	var/mob/living/carbon/human/consistent/creature = allocate(/mob/living/carbon/human/consistent, spot(0, 0))
	var/datum/component/outpost_experiment_form/form = outpost_experiment_turn(creature, "hulk", null, null)
	TEST_ASSERT_NOTNULL(form, "The hulk serum didn't take on a test body")
	creature.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(/datum/targeting_strategy/outpost_experiment_form)
	TEST_ASSERT_NOTNULL(strategy, "The experiment forms' targeting strategy is gone")

	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	TEST_ASSERT(strategy.can_attack(creature, plain), "Fixture: an experiment won't target a plain human to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	TEST_ASSERT(!strategy.can_attack(creature, ghost), "An experiment targeted a camo'd human 4 tiles off")
	TEST_ASSERT(!form.can_target(ghost), "An experiment would pick a camo'd human 4 tiles off")
	ghost.forceMove(spot(2, 0))
	TEST_ASSERT(strategy.can_attack(creature, ghost), "An experiment missed a camo'd human 2 tiles off")
	ghost.forceMove(spot(4, 4))

	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	TEST_ASSERT(strategy.can_attack(creature, flicker), "An experiment was fooled by the Flickerskin")

/// The club's people: the scripted pick, mafia_target_ok(), skips a camo'd hunter beyond range,
/// and the don, a boss, sees through it.
/datum/unit_test/voidcrew_cyberware_camo/mobsters

/datum/unit_test/voidcrew_cyberware_camo/mobsters/Run()
	var/mob/living/carbon/human/npc/bounty_mafia/pistol/gunman = allocate(/mob/living/carbon/human/npc/bounty_mafia/pistol, spot(0, 0))
	gunman.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/npc/bounty_mafia/don/don = allocate(/mob/living/carbon/human/npc/bounty_mafia/don, spot(0, 1))
	don.ai_controller?.set_ai_status(AI_STATUS_OFF)
	var/mob/living/carbon/human/consistent/plain = allocate(/mob/living/carbon/human/consistent, spot(4, 4))
	plain.mind_initialize()
	TEST_ASSERT(gunman.mafia_target_ok(plain), "Fixture: a goon won't go after a plain hunter to begin with")

	var/mob/living/carbon/human/consistent/ghost = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin, spot(4, 4))
	ghost.mind_initialize()
	TEST_ASSERT(!gunman.mafia_target_ok(ghost), "A goon went after a camo'd hunter 4 tiles off")
	TEST_ASSERT(!cyberware_camo_hides(ghost, don), "The don was fooled by camo")
	ghost.forceMove(spot(0, 2))
	TEST_ASSERT(gunman.mafia_target_ok(ghost), "A goon missed a camo'd hunter 2 tiles off")
	ghost.forceMove(spot(4, 4))

	var/mob/living/carbon/human/consistent/flicker = cloaked_human(/obj/item/organ/cyberimp/cyberware/ghostskin/street, spot(4, 3))
	flicker.mind_initialize()
	TEST_ASSERT(gunman.mafia_target_ok(flicker), "A goon was fooled by the Flickerskin")
