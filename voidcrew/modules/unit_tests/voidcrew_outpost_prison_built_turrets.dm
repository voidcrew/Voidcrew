/**
 * Turrets players build, in and around a prison wing (outpost_prison_security.dm): whom the stock
 * scan leaves them among the prison's mobs, the stun shot at prisoners whatever the mode and gun,
 * shots passing through anyone the prison spares, the warning and what a warned prisoner does
 * about it, rioters going for turrets, and a turret's controls on an outpost.
 *
 * Voidcrew defines are not visible from test files, so values appear as literals with the define
 * named beside them: the verdicts are 0 (OUTPOST_PRISON_TURRET_NOT_MINE), 1 (_SPARE) and 2
 * (_SHOOT). Turrets are driven by calling process() and shootAt() directly; the ones that could
 * fire are switched off so the machine clock never does. Fixtures are in
 * voidcrew_outpost_prison_helpers.dm, trouble_awake_prisoner() in voidcrew_outpost_prison_trouble.dm
 * and guard_test_spawn() in voidcrew_outpost_prison_guards.dm. The wing's authored layout has the
 * cells on rows 13 to 15, the yard on rows 7 to 11 and the warden's office on rows 2 to 5.
 */

/// A built turret that notes every target the stock scan and the prison's rule leave it, and shoots none
/obj/machinery/porta_turret/prison_test_probe
	var/list/offered = list()

/obj/machinery/porta_turret/prison_test_probe/target(atom/movable/target)
	offered |= target
	return FALSE

/// One look round by `probe`, powered whatever the wing's APC says; returns what it was left to shoot at
/datum/unit_test/voidcrew_outpost_management/proc/probe_targets(obj/machinery/porta_turret/prison_test_probe/probe)
	probe.set_machine_stat(probe.machine_stat & ~NOPOWER)
	probe.offered.Cut()
	probe.process()
	return probe.offered.Copy()

/// A turret as players build one, standing at `spot`, switched off so only the test fires it, and up
/datum/unit_test/voidcrew_outpost_management/proc/still_turret(turf/spot)
	var/obj/machinery/porta_turret/turret = allocate(/obj/machinery/porta_turret, spot)
	turret.locked = FALSE
	turret.on = FALSE
	turret.check_should_process()
	turret.raised = TRUE
	return turret

/// Lets `turret`'s warning to `prisoner` run out, and its gun cool down
/datum/unit_test/voidcrew_outpost_management/proc/warning_over(obj/machinery/porta_turret/turret, mob/living/basic/outpost_prisoner/prisoner)
	LAZYSET(turret.prison_warned_at, REF(prisoner), world.time - 30) // past OUTPOST_PRISON_TURRET_WARN_TIME 2 s
	turret.last_fired = 0

/// Forgets `turret`'s warning to `prisoner` and what they did about it
/datum/unit_test/voidcrew_outpost_management/proc/forget_warning(obj/machinery/porta_turret/turret, mob/living/basic/outpost_prisoner/prisoner)
	LAZYREMOVE(turret.prison_warned_at, REF(prisoner))
	prisoner.clear_turret_reaction()

// ===== WHOM A BUILT TURRET SHOOTS =====

/datum/unit_test/voidcrew_outpost_prison_built_turret_targets
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_built_turret_targets/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("btturrettargets")
	TEST_ASSERT_NOTNULL(home, "The built turret targets test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.riot_windup_left = 0
	var/obj/machinery/porta_turret/prison_test_probe/probe = allocate(/obj/machinery/porta_turret/prison_test_probe, prison_spot(home, 9, 8))
	TEST_ASSERT(probe.turret_flags & (1<<4), "A built turret does not look for unidentified life signs by default") // TURRET_FLAG_SHOOT_ANOMALOUS

	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 9, 10))
	var/mob/living/basic/outpost_prisoner/calm = trouble_awake_prisoner(prison, prison_spot(home, 10, 10))
	var/mob/living/basic/outpost_prisoner/cuffed = trouble_awake_prisoner(prison, prison_spot(home, 11, 10))
	var/mob/living/basic/outpost_prisoner/downed = trouble_awake_prisoner(prison, prison_spot(home, 8, 10))
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 11, 8), awake = FALSE)
	TEST_ASSERT_NOTNULL(guard, "The guard did not arrive")
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = allocate(/mob/living/basic/outpost_kessler_staff/researcher, prison_spot(home, 10, 7), null)
	var/mob/living/basic/outpost_kessler_staff/agent/agent = allocate(/mob/living/basic/outpost_kessler_staff/agent, prison_spot(home, 11, 7), null)
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 7, 7), prison, null)
	var/mob/living/basic/mouse/mouse = allocate(/mob/living/basic/mouse, prison_spot(home, 8, 7))
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	TEST_ASSERT(cuffed.apply_cuffs(allocate(/obj/item/restraints/handcuffs)), "The prisoner could not be cuffed")
	ADD_TRAIT(downed, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	prison.refresh_reach()
	TEST_ASSERT(rioter.reachable?[get_turf(probe)], "A rioter in the yard cannot reach the turret standing in it")

	// One look round: the rioter and the creature, and none of the rest
	var/list/offered = probe_targets(probe)
	TEST_ASSERT(rioter in offered, "A built turret left a rioter it can see alone")
	TEST_ASSERT(hulk in offered, "A built turret left an experiment creature alone")
	TEST_ASSERT(!(calm in offered), "A built turret went for a calm prisoner")
	TEST_ASSERT(!(cuffed in offered), "A built turret went for a cuffed prisoner")
	TEST_ASSERT(!(downed in offered), "A built turret went for a downed prisoner")
	TEST_ASSERT(!(guard in offered), "A built turret went for a guard")
	TEST_ASSERT(!(doctor in offered), "A built turret went for the Kessler researcher")
	TEST_ASSERT(!(agent in offered), "A built turret went for a Kessler agent")

	// The verdicts behind it; anything that is not the prison's is left to the turret's own settings
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(rioter, probe), 2, "The rule does not shoot a rioter")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(calm, probe), 1, "The rule does not spare a calm prisoner")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(guard, probe), 1, "The rule does not spare a guard")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(agent, probe), 1, "The rule does not spare a Kessler agent")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(hulk, probe), 2, "The rule does not shoot the hulk")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(mouse, probe), 0, "The rule claimed a mouse that is not the prison's")
	hulk.subdued = TRUE
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(hulk, probe), 1, "The rule shoots a subdued hulk")
	hulk.subdued = FALSE

	// A turret they cannot walk up to, such as one behind the office glass, covers them too
	rioter.reachable = list()
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(rioter, probe), 2, "The rule spares a rioter who cannot reach the turret")
	TEST_ASSERT(rioter in probe_targets(probe), "A turret the rioter cannot reach left them alone")
	prison.refresh_prisoner_reach(rioter)

	// The kinds of trouble: threats, arguments and wrecking a cell are not worth a shot; the rest are
	REMOVE_TRAIT(downed, TRAIT_INCAPACITATED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 1, "The rule shoots a prisoner doing nothing")
	downed.threat_ref = WEAKREF(guard)
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 1, "The rule shoots a prisoner who is only threatening")
	downed.threat_ref = null
	downed.swing_ref = WEAKREF(guard)
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 2, "The rule does not shoot a prisoner swinging at someone")
	downed.swing_ref = null
	downed.trouble = "wreck" // PRISONER_TROUBLE_WRECK
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 1, "The rule shoots a prisoner wrecking their cell")
	downed.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 2, "The rule does not shoot a loose prisoner")
	downed.trouble = null
	var/obj/structure/table/reinforced/prison_hatch/hatch
	for(var/turf/tile as anything in prison.wing_turfs())
		hatch = locate() in tile
		if(hatch)
			break
	TEST_ASSERT_NOTNULL(hatch, "The wing has no serving hatch")
	downed.climb_ref = WEAKREF(hatch)
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 2, "The rule does not shoot a prisoner climbing a hatch")
	downed.climb_ref = null
	var/datum/outpost_prison_fight/brawl = new(prison, downed, rioter)
	downed.fight = brawl
	downed.trouble = "fight" // PRISONER_TROUBLE_FIGHT
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 1, "The rule shoots a prisoner who is only arguing")
	brawl.fighting = TRUE
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(downed, probe), 2, "The rule does not shoot a prisoner throwing blows")
	downed.trouble = null
	qdel(brawl)

	// A prisoner shut in a cell is never shot, even by a turret shut in with them
	var/datum/outpost_prison_cell/holding = calm.cell
	TEST_ASSERT_NOTNULL(holding, "The calm prisoner has no cell")
	var/list/free_tiles = list()
	for(var/turf/tile as anything in holding.turfs)
		if(!tile.is_blocked_turf(TRUE))
			free_tiles += tile
	TEST_ASSERT(length(free_tiles) >= 2, "The calm prisoner's cell has no room for them and a turret")
	calm.forceMove(free_tiles[1])
	var/obj/machinery/porta_turret/prison_test_probe/cell_probe = allocate(/obj/machinery/porta_turret/prison_test_probe, free_tiles[2])
	var/obj/machinery/door/airlock/cell_door = holding.door()
	if(!cell_door.density)
		cell_door.close()
	cell_door.bolt()
	prison.refresh_reach()
	calm.trouble = "riot" // PRISONER_TROUBLE_RIOT
	TEST_ASSERT(calm.is_confined(), "A prisoner bolted in their cell is not confined")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(calm, cell_probe), 1, "The rule shoots a rioter bolted in their cell")
	var/list/from_the_cell = probe_targets(cell_probe)
	TEST_ASSERT(!(calm in from_the_cell), "A turret in a bolted cell went for the rioter shut in with it")
	calm.trouble = null
	cell_door.unbolt()
	settle_prison_air(home)

// ===== THE SHOT =====

/datum/unit_test/voidcrew_outpost_prison_built_turret_shots
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_built_turret_shots/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("btturretshots")
	TEST_ASSERT_NOTNULL(home, "The built turret shots test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.riot_windup_left = 0
	prison.forced_turret_reaction = "defy" // OUTPOST_PRISON_TURRET_DEFY

	// Which shots count as stuns
	TEST_ASSERT(outpost_prison_stun_projectile(/obj/projectile/beam/disabler), "A disabler beam is not a stun shot")
	TEST_ASSERT(outpost_prison_stun_projectile(/obj/projectile/energy/electrode), "An electrode is not a stun shot")
	TEST_ASSERT(!outpost_prison_stun_projectile(/obj/projectile/beam/laser), "A laser counts as a stun shot")
	TEST_ASSERT(!outpost_prison_stun_projectile(null), "Nothing counts as a stun shot")

	// A lethal turret with a laser gun, whose stun setting is a laser too
	var/obj/machinery/porta_turret/turret = still_turret(prison_spot(home, 9, 8))
	turret.setup(allocate(/obj/item/gun/energy/laser))
	turret.mode = 1 // TURRET_LETHAL
	var/stun_before = turret.stun_projectile
	TEST_ASSERT(!outpost_prison_stun_projectile(stun_before), "The laser gun's stun setting is a stun shot, so this test proves nothing")

	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 9, 10))
	var/mob/living/basic/outpost_prisoner/calm = trouble_awake_prisoner(prison, prison_spot(home, 10, 10))
	var/mob/living/basic/outpost_prison_guard/guard = guard_test_spawn(prison, prison_spot(home, 11, 8), awake = FALSE)
	var/mob/living/basic/outpost_kessler_staff/researcher/doctor = allocate(/mob/living/basic/outpost_kessler_staff/researcher, prison_spot(home, 10, 7), null)
	var/mob/living/basic/outpost_experiment/hulk/hulk = allocate(/mob/living/basic/outpost_experiment/hulk, prison_spot(home, 7, 7), prison, null)
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	prison.refresh_reach()

	// The first look at a rioter is a warning, and it holds fire while that runs
	TEST_ASSERT_NULL(turret.shootAt(rioter), "The turret fired at a rioter it had not warned")
	TEST_ASSERT(LAZYACCESS(turret.prison_warned_at, REF(rioter)), "The turret did not note its warning")
	TEST_ASSERT_EQUAL(rioter.turret_reaction, "defy", "The rioter did not defy the turret as forced") // OUTPOST_PRISON_TURRET_DEFY
	turret.last_fired = 0
	TEST_ASSERT_NULL(turret.shootAt(rioter), "The turret fired while its warning was still running")

	// Then a stun shot, whatever the mode and the gun, and the turret is left as it was
	warning_over(turret, rioter)
	var/obj/projectile/at_rioter = turret.shootAt(rioter)
	TEST_ASSERT(istype(at_rioter, /obj/projectile/beam/disabler), "A lethal laser turret fired [at_rioter?.type || "nothing"] at a rioter, not a disabler beam")
	TEST_ASSERT_EQUAL(turret.mode, 1, "Shooting a prisoner left the turret out of lethal mode")
	TEST_ASSERT_EQUAL(turret.stun_projectile, stun_before, "Shooting a prisoner changed the turret's stun setting")

	// Anything that is not a prisoner gets the turret's own mode
	turret.last_fired = 0
	var/obj/projectile/at_hulk = turret.shootAt(hulk)
	TEST_ASSERT(istype(at_hulk, /obj/projectile/beam/laser), "A lethal laser turret fired [at_hulk?.type || "nothing"] at the hulk, not its laser")

	// Its shots pass through everyone the prison spares, and a lethal one through every prisoner
	var/obj/projectile/beam/disabler/stun_shot = allocate(/obj/projectile/beam/disabler, prison_spot(home, 9, 9))
	stun_shot.firer = turret
	TEST_ASSERT(stun_shot.can_hit_target(rioter, TRUE, TRUE), "A turret's stun shot could not land on a rioter")
	TEST_ASSERT(!stun_shot.can_hit_target(calm, TRUE, TRUE), "A turret's stun shot could land on a calm prisoner")
	TEST_ASSERT(!stun_shot.can_hit_target(guard, TRUE, TRUE), "A turret's stun shot could land on a guard")
	TEST_ASSERT(!stun_shot.can_hit_target(doctor, TRUE, TRUE), "A turret's stun shot could land on the Kessler researcher")
	var/obj/projectile/beam/laser/lethal_shot = allocate(/obj/projectile/beam/laser, prison_spot(home, 9, 9))
	lethal_shot.firer = turret
	TEST_ASSERT(!lethal_shot.can_hit_target(rioter, TRUE, TRUE), "A turret's lethal shot could land on a rioter")
	TEST_ASSERT(lethal_shot.can_hit_target(hulk, TRUE, TRUE), "A turret's lethal shot could not land on the hulk")
	// Anyone else's shots are none of the prison's business
	var/obj/projectile/beam/laser/stray_shot = allocate(/obj/projectile/beam/laser, prison_spot(home, 9, 9))
	TEST_ASSERT(stray_shot.can_hit_target(calm, TRUE, TRUE), "A shot nobody fired from a turret passed through a calm prisoner")

	// Never a shot at a prisoner the rule spares, however the turret is aimed
	warning_over(turret, calm)
	TEST_ASSERT_NULL(turret.shootAt(calm), "The turret fired at a calm prisoner it was aimed at")
	settle_prison_air(home)

// ===== THE WARNING, AND WHAT PRISONERS DO ABOUT IT =====

/datum/unit_test/voidcrew_outpost_prison_built_turret_warning
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_built_turret_warning/Run()
	// The odds: mood tilts them, and never settles them, at either end and for every personality
	TEST_ASSERT(outpost_prisoner_turret_backoff_chance(100) > outpost_prisoner_turret_backoff_chance(0), "A better mood does not make backing off likelier")
	for(var/mood in list(0, 100))
		var/chance = outpost_prisoner_turret_backoff_chance(mood)
		TEST_ASSERT(chance > 0 && chance < 100, "At mood [mood] a swinger backs off [chance]% of the time")
		for(var/personality in outpost_prisoner_dialogue("personalities"))
			var/list/weights = outpost_prisoner_turret_riot_weights(mood, personality)
			var/total = 0
			for(var/outcome in list("give_up", "back_off", "defy"))
				TEST_ASSERT(weights[outcome] > 0, "At mood [mood] a [personality] rioter never does [outcome]")
				total += weights[outcome]
			for(var/outcome in list("give_up", "back_off", "defy"))
				TEST_ASSERT(weights[outcome] < total, "At mood [mood] a [personality] rioter always does [outcome]")
	var/list/content = outpost_prisoner_turret_riot_weights(100, "chatty")
	var/list/furious = outpost_prisoner_turret_riot_weights(0, "chatty")
	TEST_ASSERT(content["give_up"] > furious["give_up"] && content["defy"] < furious["defy"], "Mood does not tilt a rioter from defying to giving up")
	var/list/chatty = outpost_prisoner_turret_riot_weights(40, "chatty")
	var/list/nervous = outpost_prisoner_turret_riot_weights(40, "nervous")
	var/list/grumpy = outpost_prisoner_turret_riot_weights(40, "grumpy")
	TEST_ASSERT(nervous["give_up"] > chatty["give_up"], "Nervous rioters do not give up more")
	TEST_ASSERT(grumpy["defy"] > chatty["defy"], "Grumpy rioters do not defy more")

	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("btturretwarning")
	TEST_ASSERT_NOTNULL(home, "The built turret warning test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.riot_windup_left = 0
	var/obj/machinery/porta_turret/turret = still_turret(prison_spot(home, 9, 8))
	turret.setup(allocate(/obj/item/gun/energy/disabler))
	var/mob/living/carbon/human/staff = make_player(prison_spot(home, 7, 9), "btturretwarning")
	var/mob/living/basic/outpost_prisoner/swinger = trouble_awake_prisoner(prison, prison_spot(home, 9, 10))
	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 10, 10))
	var/mob/living/basic/outpost_prisoner/first = trouble_awake_prisoner(prison, prison_spot(home, 8, 10))
	var/mob/living/basic/outpost_prisoner/second = trouble_awake_prisoner(prison, prison_spot(home, 11, 10))
	prison.refresh_reach()

	// A swinger who backs off drops it, steps away, won't square up again for a while, and is not shot
	prison.forced_turret_reaction = "back_off" // OUTPOST_PRISON_TURRET_BACK_OFF
	swinger.set_mood(30)
	swinger.swing_ref = WEAKREF(staff)
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(swinger, turret), 2, "The rule does not shoot a prisoner swinging at staff")
	TEST_ASSERT_NULL(turret.shootAt(swinger), "The turret fired at a swinger without a warning")
	TEST_ASSERT_NULL(swinger.swing_ref, "A swinger who backed off is still swinging")
	TEST_ASSERT(swinger.threat_cooldown >= 20, "A swinger who backed off may square up again at once") // PRISONER_THREAT_COOLDOWN 20 s
	TEST_ASSERT_NOTNULL(swinger.turret_retreat_spot, "A swinger who backed off has nowhere to step back to")
	if(swinger.turret_retreat_spot)
		TEST_ASSERT(get_dist(swinger, swinger.turret_retreat_spot) <= 2, "A swinger stepped back more than two tiles") // OUTPOST_PRISON_TURRET_STEP_BACK
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(swinger, turret), 1, "The rule still shoots a swinger who backed off")
	warning_over(turret, swinger)
	TEST_ASSERT_NULL(turret.shootAt(swinger), "The turret shot a swinger who backed off once the warning ran out")

	// A swinger who defies it keeps swinging and takes the stun
	forget_warning(turret, swinger)
	prison.forced_turret_reaction = "defy" // OUTPOST_PRISON_TURRET_DEFY
	swinger.set_mood(10)
	swinger.swing_ref = WEAKREF(staff)
	TEST_ASSERT_NULL(turret.shootAt(swinger), "The turret fired at a swinger without a warning")
	TEST_ASSERT_NOTNULL(swinger.swing_ref, "A swinger who defied the turret stopped swinging")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(swinger, turret), 2, "The rule spares a swinger who defied the turret")
	warning_over(turret, swinger)
	var/obj/projectile/at_swinger = turret.shootAt(swinger)
	TEST_ASSERT(at_swinger && outpost_prison_stun_projectile(at_swinger.type), "The turret did not stun a swinger who defied it")
	swinger.swing_ref = null

	// Two fighters: backing off ends the fight for both
	prison.forced_turret_reaction = "back_off" // OUTPOST_PRISON_TURRET_BACK_OFF
	var/datum/outpost_prison_fight/brawl = prison.start_fight(first, second)
	TEST_ASSERT_NOTNULL(brawl, "The two prisoners did not get into a fight")
	if(brawl)
		brawl.fighting = TRUE
		turret.shootAt(first)
		TEST_ASSERT_NULL(first.fight, "A fighter who backed off is still in the fight")
		TEST_ASSERT_NULL(second.fight, "Their opponent is still in the fight")
		TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(second, turret), 1, "The rule shoots the other fighter once the fight is off")

	// A climber who backs off climbs down
	var/obj/structure/table/reinforced/prison_hatch/hatch
	for(var/turf/tile as anything in prison.wing_turfs())
		hatch = locate() in tile
		if(hatch)
			break
	TEST_ASSERT_NOTNULL(hatch, "The wing has no serving hatch")
	forget_warning(turret, second)
	second.climb_ref = WEAKREF(hatch)
	turret.shootAt(second)
	TEST_ASSERT_NULL(second.climb_ref, "A climber who backed off is still climbing")

	// A rioter who gives up puts the shiv down and heads for their own cell; they are not shot
	prison.forced_turret_reaction = "give_up" // OUTPOST_PRISON_TURRET_GIVE_UP
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	rioter.draw_shiv()
	TEST_ASSERT(rioter.has_shiv(), "The rioter has no shiv")
	TEST_ASSERT_NULL(turret.shootAt(rioter), "The turret fired at a rioter without a warning")
	TEST_ASSERT(rioter.surrendered_to_turret(), "A rioter who gave up did not")
	TEST_ASSERT(!rioter.has_shiv(), "A rioter who gave up kept the shiv out")
	TEST_ASSERT(rioter.is_rioting(), "Giving up took a rioter out of the riot before anyone bolted them in")
	TEST_ASSERT(rioter.cell?.contains(rioter.turret_retreat_spot), "A rioter who gave up is not heading for their own cell")
	TEST_ASSERT(!rioter.riot_free(), "A rioter who gave up still counts as free to riot")
	TEST_ASSERT_NULL(rioter.riot_target(), "A rioter who gave up still goes for something")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(rioter, turret), 1, "The rule shoots a rioter who gave up")
	warning_over(turret, rioter)
	TEST_ASSERT_NULL(turret.shootAt(rioter), "The turret shot a rioter who gave up")

	// A rioter who backs off keeps rioting, out of the turret's sight and away from what it sees
	forget_warning(turret, rioter)
	prison.forced_turret_reaction = "back_off" // OUTPOST_PRISON_TURRET_BACK_OFF
	turret.shootAt(rioter)
	TEST_ASSERT(rioter.is_rioting() && !rioter.surrendered_to_turret(), "A rioter who backed off stopped rioting")
	TEST_ASSERT(LAZYACCESS(rioter.riot_skips, REF(turret)) > world.time, "A rioter who backed off would still go for the turret")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(rioter, turret), 1, "The rule shoots a rioter walking away")
	if(rioter.turret_retreat_spot)
		TEST_ASSERT(!(rioter.turret_retreat_spot in view(turret.scan_range, turret)), "A rioter who backed off is heading somewhere the turret can see")

	// A rioter who defies it goes for the turret first, and is shot
	forget_warning(turret, rioter)
	LAZYREMOVE(rioter.riot_skips, REF(turret))
	prison.forced_turret_reaction = "defy" // OUTPOST_PRISON_TURRET_DEFY
	turret.shootAt(rioter)
	TEST_ASSERT_EQUAL(rioter.riot_target(), turret, "A rioter who defied the turret did not go for it")
	TEST_ASSERT_EQUAL(outpost_prison_turret_verdict(rioter, turret), 2, "The rule spares a rioter who defied the turret")
	settle_prison_air(home)

// ===== RIOTERS GO FOR TURRETS =====

/datum/unit_test/voidcrew_outpost_prison_built_turret_smash
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_built_turret_smash/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("btturretsmash")
	TEST_ASSERT_NOTNULL(home, "The turret smashing test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.riot_windup_left = 0
	var/obj/machinery/porta_turret/turret = still_turret(prison_spot(home, 9, 8))
	var/mob/living/basic/outpost_prisoner/rioter = trouble_awake_prisoner(prison, prison_spot(home, 9, 9))
	rioter.trouble = "riot" // PRISONER_TROUBLE_RIOT
	prison.refresh_reach()

	// Before any fixture, and not once they have given up on it
	TEST_ASSERT_EQUAL(prison.priority_smash_target(rioter), turret, "A rioter beside a built turret did not go for it first")
	TEST_ASSERT_EQUAL(prison.pick_smash_target(rioter), turret, "pick_smash_target() did not start with the turret")
	LAZYSET(rioter.riot_skips, REF(turret), world.time + 100)
	TEST_ASSERT_NULL(prison.priority_smash_target(rioter), "A rioter went back to a turret they had given up on")
	LAZYREMOVE(rioter.riot_skips, REF(turret))

	// Eight blows break it (PRISON_SMASH_DAMAGE 10; 160 integrity, broken at half)
	for(var/blow in 1 to 7)
		rioter.smash(turret)
	TEST_ASSERT(!(turret.machine_stat & BROKEN), "The turret broke in seven blows")
	rioter.smash(turret)
	TEST_ASSERT(turret.machine_stat & BROKEN, "The turret did not break in eight blows")
	TEST_ASSERT_NULL(prison.priority_smash_target(rioter), "A rioter went for a broken turret")
	TEST_ASSERT(!prison.still_smashable(turret, rioter), "A broken turret was still worth smashing")
	rioter.trouble = null
	settle_prison_air(home)

// ===== WHO WORKS A TURRET ON AN OUTPOST =====

/datum/unit_test/voidcrew_outpost_prison_built_turret_controls
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_built_turret_controls/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("btcontrolowner")
	TEST_ASSERT_NOTNULL(home, "The turret controls test outpost did not load")
	var/mob/living/carbon/human/owner = make_player(prison_spot(home, 3, 5), "btcontrolowner")
	var/mob/living/carbon/human/stranger = make_player(prison_spot(home, 2, 5), "btcontrolstranger")
	// Built in the warden's office, switched on and unlocked as a finished frame leaves it, and
	// looking for nobody, so the machine clock never has it fire at the two of them
	var/obj/machinery/porta_turret/turret = allocate(/obj/machinery/porta_turret, prison_spot(home, 4, 4))
	turret.locked = FALSE
	turret.turret_flags = NONE
	TEST_ASSERT_EQUAL(get_outpost_from_atom(turret), home, "The test turret is not on the outpost")
	TEST_ASSERT(turret.on && turret.anchored, "The test turret did not start switched on and bolted")
	TEST_ASSERT(turret.outpost_controls_allowed(owner), "The owner may not work their outpost's turret")
	TEST_ASSERT(!turret.outpost_controls_allowed(stranger), "A stranger may work an outpost's turret")

	// The panel: a stranger's buttons do nothing, the owner's work
	var/datum/tgui/stranger_ui = allocate(/datum/tgui, stranger, turret, "PortableTurret")
	turret.ui_act("power", list(), stranger_ui, GLOB.always_state)
	TEST_ASSERT(turret.on, "A stranger switched an outpost's turret off")
	turret.ui_act("shootall", list(), stranger_ui, GLOB.always_state)
	TEST_ASSERT_EQUAL(turret.turret_flags, NONE, "A stranger changed an outpost turret's targets")
	var/datum/tgui/owner_ui = allocate(/datum/tgui, owner, turret, "PortableTurret")
	turret.ui_act("power", list(), owner_ui, GLOB.always_state)
	TEST_ASSERT(!turret.on, "The owner could not switch their turret off")

	// Tools: the wrench (it is off now), an ID swipe, the multitool
	var/obj/item/wrench/wrench = allocate(/obj/item/wrench)
	turret.attackby(wrench, stranger)
	TEST_ASSERT(turret.anchored, "A stranger unbolted an outpost's switched-off turret")
	var/obj/item/card/id/advanced/card = allocate(/obj/item/card/id/advanced)
	turret.attackby(card, stranger)
	TEST_ASSERT(!turret.locked, "A stranger's ID swipe locked an outpost's turret")
	var/obj/item/multitool/multitool = allocate(/obj/item/multitool)
	turret.multitool_act(stranger, multitool)
	TEST_ASSERT_NULL(multitool.buffer, "A stranger saved an outpost's turret to a multitool")
	turret.multitool_act(owner, multitool)
	TEST_ASSERT_EQUAL(multitool.buffer, turret, "The owner could not save their turret to a multitool")
	turret.attackby(wrench, owner)
	TEST_ASSERT(!turret.anchored, "The owner could not unbolt their switched-off turret")
	turret.attackby(wrench, owner)
	TEST_ASSERT(turret.anchored, "The owner could not bolt their turret back down")

	// A turret control panel on the outpost answers to the same people
	var/obj/machinery/turretid/panel = allocate(/obj/machinery/turretid, prison_spot(home, 6, 4))
	panel.locked = FALSE
	var/obj/item/multitool/strangers_tool = allocate(/obj/item/multitool)
	strangers_tool.set_buffer(turret)
	panel.multitool_act(stranger, strangers_tool)
	TEST_ASSERT(!length(panel.turrets), "A stranger linked a turret to an outpost's control panel")
	panel.multitool_act(owner, multitool)
	TEST_ASSERT_EQUAL(length(panel.turrets), 1, "The owner could not link their turret to the panel")
	var/was_lethal = panel.lethal
	panel.toggle_lethal(stranger)
	TEST_ASSERT_EQUAL(panel.lethal, was_lethal, "A stranger switched an outpost's turrets to lethal")
	panel.toggle_lethal(owner)
	TEST_ASSERT(panel.lethal != was_lethal, "The owner could not switch their turrets' mode")
	panel.toggle_lethal(owner)

	// A claim nobody holds is nobody's lock
	home.founder_ckey = null
	TEST_ASSERT(turret.outpost_controls_allowed(stranger), "A turret on a vacant claim is still locked")
	home.founder_ckey = "btcontrolowner"
	settle_prison_air(home)
