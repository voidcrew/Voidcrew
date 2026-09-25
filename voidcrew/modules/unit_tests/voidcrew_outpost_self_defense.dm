/// Personal retaliation must not punish the victim or excuse the original attacker.
/datum/unit_test/voidcrew_outpost_self_defense/Run()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 1
	outpost.outpost_template.height = 1
	outpost.template_bottom_left = run_loc_floor_bottom_left
	var/mob/living/carbon/human/attacker = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/defender = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent)
	attacker.mind_initialize()
	defender.mind_initialize()
	bystander.mind_initialize()
	var/datum/outpost_pvp_enforcement/enforcement = GLOB.outpost_pvp_enforcement

	// Exercise the normal location-based route, including the first warning hit.
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[attacker.mind], 1, "The initiating attack must still earn a strike")
	var/list/defender_targets = outpost.self_defense_targets[defender.mind]
	// Fork defines are included after unit tests: OUTPOST_SELF_DEFENSE_DURATION = 2 minutes.
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "The first attack must immediately allow personal retaliation")
	defender_targets[attacker.mind] = world.time + 1 MINUTES
	var/original_expiry = defender_targets[attacker.mind]
	for(var/hit in 1 to 4)
		enforcement.register_pvp_aggression(attacker, defender)
	TEST_ASSERT_NULL(outpost.aggressor_strikes[defender.mind], "Returning fire must not earn the victim strikes")
	TEST_ASSERT_NULL(outpost.self_defense_targets[attacker.mind], "Lawful retaliation must not give the initiator a self-defense exemption")
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], original_expiry, "Retaliation must not prolong its own exemption")
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[attacker.mind], 1, "Attacks during the strike grace period must not add another strike")
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "Attacks during the strike grace period must still refresh self-defense")

	// Further initiating attacks still escalate through the normal warning ladder.
	outpost.aggressor_strike_times.Cut()
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[attacker.mind], 2, "The initiator's second attack must still earn a strike after retaliation")
	outpost.aggressor_strike_times.Cut()
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT(outpost.is_user_barred(attacker), "Repeated initiating attacks must still trigger enforcement")
	TEST_ASSERT(!outpost.is_user_barred(defender), "Defending oneself must not trigger enforcement")
	defender_targets[attacker.mind] = world.time + 1 SECONDS
	enforcement.register_pvp_aggression(defender, attacker)
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "An already marked aggressor must still refresh their victim's exemption")

	// A third person cannot join the fight under someone else's exemption.
	enforcement.register_pvp_aggression(attacker, bystander)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[bystander.mind], 1, "A bystander must not inherit the victim's exemption")
	enforcement.register_pvp_aggression(bystander, defender)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[defender.mind], 1, "A victim's exemption must not cover attacks on unrelated people")

	// Property damage goes directly to the existing enforcement path.
	outpost.aggressor_strike_times.Cut()
	outpost.register_aggression(defender)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[defender.mind], 2, "Self-defense must not excuse damaging outpost property")

	// Expiry is exclusive: attacking at the deadline is a fresh infraction.
	defender_targets[attacker.mind] = world.time
	outpost.aggressor_strike_times.Cut()
	enforcement.register_pvp_aggression(attacker, defender)
	TEST_ASSERT_EQUAL(outpost.aggressor_strikes[defender.mind], 3, "Retaliation at the expiry time must no longer be exempt")
	TEST_ASSERT(!LAZYACCESS(defender_targets, attacker.mind), "Expired retaliation permission must be pruned")
	var/list/attacker_targets = outpost.self_defense_targets[attacker.mind]
	TEST_ASSERT(attacker_targets[defender.mind] > world.time, "A new attack after expiry must let its victim defend themselves")
