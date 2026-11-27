/**
 * Helpers the ported outpost tests share (the self-defence, bounty, kingpin, checkpoint, ambient and camo
 * files). Owner: P10. Fork defines are included after the tests, so these use literals with the define named.
 */

/**
 * Lets the police's dedupe on one offender's reports lapse (OUTPOST_AGGRESSION_GRACE, half a second), so the
 * next report from them counts. The police tick is stopped first: a test that waits must not have units
 * ordered by a warrant it only made to count.
 */
/datum/unit_test/proc/police_port_wait_out_dedupe(datum/outpost_police/police)
	police.sleep_tick()
	sleep(6) // a little over OUTPOST_AGGRESSION_GRACE (5 deciseconds)

/// An officer to witness a crime at `outpost`, at `where` (a crime counts only if somebody saw it: spec 3)
/datum/unit_test/proc/police_port_witness(obj/structure/overmap/trader_outpost/outpost, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)
	TEST_ASSERT_NOTNULL(officer, "No officer could be put at [outpost.type] to see the crime")
	return officer

/// Whether `officer`'s targeting strategy would attack `target` as things stand: the question the outpost turret's valid_target() used to answer
/datum/unit_test/proc/police_port_may_attack(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, atom/target)
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(officer.ai_controller?.blackboard[BB_TARGETING_STRATEGY])
	TEST_ASSERT_NOTNULL(strategy, "[officer.type] has no targeting strategy")
	return strategy.can_attack(officer, target)

/// Personal retaliation must not punish the victim or excuse the original attacker.
/datum/unit_test/voidcrew_outpost_self_defense/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 1
	outpost.outpost_template.height = 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(police, "The outpost has no police")
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/defender = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent)
	attacker.mind_initialize()
	defender.mind_initialize()
	bystander.mind_initialize()
	// A crime counts only if somebody sees it
	police_port_witness(outpost, run_loc_floor_bottom_left)
	var/datum/outpost_pvp_enforcement/enforcement = GLOB.outpost_pvp_enforcement

	// Exercise the normal location-based route, including the first hit.
	enforcement.register_pvp_aggression(defender, attacker)
	var/datum/outpost_warrant/attacker_warrant = police.get_warrant(attacker.mind)
	TEST_ASSERT_NOTNULL(attacker_warrant, "The initiating attack must still be a crime")
	var/first_heat = attacker_warrant.heat
	TEST_ASSERT(first_heat > 0, "The initiating attack must still add heat")
	var/list/defender_targets = outpost.self_defense_targets[defender.mind]
	// Fork defines are included after unit tests: OUTPOST_SELF_DEFENSE_DURATION = 2 minutes.
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "The first attack must immediately allow personal retaliation")
	defender_targets[attacker.mind] = world.time + 1 MINUTES
	var/original_expiry = defender_targets[attacker.mind]
	for(var/hit in 1 to 4)
		enforcement.register_pvp_aggression(attacker, defender)
	TEST_ASSERT_NULL(police.get_warrant(defender.mind), "Returning fire must not put the victim on record")
	TEST_ASSERT_EQUAL(attacker_warrant.heat, first_heat, "Returning fire must not add to the aggressor's heat")
	TEST_ASSERT_NULL(outpost.self_defense_targets[attacker.mind], "Lawful retaliation must not give the initiator a self-defense exemption")
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], original_expiry, "Retaliation must not prolong its own exemption")
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(attacker_warrant.heat, first_heat, "Attacks inside the report grace period must not add more heat")
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "Attacks inside the report grace period must still refresh self-defense")

	// Further initiating attacks still escalate: two armed hits are one star (spec 2), and the defender is no suspect
	police_port_wait_out_dedupe(police)
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT(attacker_warrant.heat > first_heat, "The initiator's second attack must still add heat after retaliation")
	TEST_ASSERT_EQUAL(police.get_stars(attacker.mind), 1, "Two initiating attacks are not one star")
	TEST_ASSERT(outpost.is_user_barred(attacker), "Repeated initiating attacks must still bring the police down on the initiator")
	TEST_ASSERT(!outpost.is_user_barred(defender), "Defending oneself must not bring the police down")
	defender_targets[attacker.mind] = world.time + 1 SECONDS
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "An already wanted aggressor must still refresh their victim's exemption")

	// A third person cannot join the fight under someone else's exemption.
	enforcement.register_pvp_aggression(attacker, bystander)
	TEST_ASSERT_NOTNULL(police.get_warrant(bystander.mind), "A bystander must not inherit the victim's exemption")
	enforcement.register_pvp_aggression(bystander, defender)
	var/datum/outpost_warrant/defender_warrant = police.get_warrant(defender.mind)
	TEST_ASSERT_NOTNULL(defender_warrant, "A victim's exemption must not cover attacks on unrelated people")

	// Property damage goes directly to the existing police path.
	police_port_wait_out_dedupe(police)
	var/heat_before_property = defender_warrant.heat
	outpost.register_aggression(defender)
	TEST_ASSERT(defender_warrant.heat > heat_before_property, "Self-defense must not excuse damaging outpost property")

	// Expiry is exclusive: attacking at the deadline is a fresh infraction.
	police_port_wait_out_dedupe(police)
	var/heat_before_expiry = defender_warrant.heat
	defender_targets[attacker.mind] = world.time
	enforcement.register_pvp_aggression(attacker, defender)
	TEST_ASSERT(defender_warrant.heat > heat_before_expiry, "Retaliation at the expiry time must no longer be exempt")
	TEST_ASSERT(!LAZYACCESS(defender_targets, attacker.mind), "Expired retaliation permission must be pruned")
	var/list/attacker_targets = outpost.self_defense_targets[attacker.mind]
	TEST_ASSERT(attacker_targets[defender.mind] > world.time, "A new attack after expiry must let its victim defend themselves")
