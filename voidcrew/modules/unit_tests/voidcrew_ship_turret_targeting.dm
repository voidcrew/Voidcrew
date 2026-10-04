/**
 * Hull defense turrets only shoot creatures that would start a fight on their own.
 *
 * The rule is read off the mob's AI planning subtrees rather than its type or its melee
 * damage (voidcrew/machinery/ship_defense_turret.dm), which means an upstream merge that
 * reshuffles the basic-mob AI tree can silently flip a goat into a target or a boarding
 * party into a bystander. Neither failure is visible without standing next to a turret,
 * so pin both ends down here.
 */
/datum/unit_test/voidcrew_ship_turret_targeting

/datum/unit_test/voidcrew_ship_turret_targeting/Run()
	var/obj/machinery/porta_turret/ship_defense/turret = allocate(/obj/machinery/porta_turret/ship_defense)

	// Things that come looking for a fight. A goliath and a carp never had a quarrel with
	// anyone before they saw one; a pirate is the whole reason these get bolted on.
	var/static/list/threats = list(
		/mob/living/basic/bear,
		/mob/living/basic/carp,
		/mob/living/basic/mining/goliath,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
	)
	for(var/mob_type in threats)
		var/mob/living/threat = allocate(mob_type)
		TEST_ASSERT(turret.valid_target(threat), "the turret refused to shoot [mob_type], which hunts targets unprovoked")

	// Livestock, pets and small-fry predators. A goose bites and a stoat hunts, but neither
	// is a reason for a hull turret to open fire.
	var/static/list/bystanders = list(
		/mob/living/basic/cow,
		/mob/living/basic/goat,
		/mob/living/basic/goose,
		/mob/living/basic/pet/cat,
		/mob/living/basic/stoat,
	)
	for(var/mob_type in bystanders)
		var/mob/living/bystander = allocate(mob_type)
		TEST_ASSERT(!turret.valid_target(bystander), "the turret opened fire on [mob_type], which only fights if provoked")

	// A retaliator that has settled on someone to maul is a live threat like anything else.
	var/mob/living/basic/goat/angry_goat = allocate(/mob/living/basic/goat)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(angry_goat.ai_controller, "the test goat spawned without an AI controller")
	angry_goat.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, victim)
	TEST_ASSERT(turret.valid_target(angry_goat), "the turret held fire on a goat that had already picked a victim")

	// Players are never targets, whatever they are riding.
	var/mob/living/basic/bear/possessed = allocate(/mob/living/basic/bear)
	possessed.mind_initialize()
	TEST_ASSERT(!turret.valid_target(possessed), "the turret targeted a creature with a mind attached")
