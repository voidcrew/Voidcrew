/**
 * Outpost police tests: police_wanted.dm and police_perception.dm (voidcrew/modules/outpost_police/). Owner: P1.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 *
 * Every test builds a fake trader outpost around the test room (the self-defense test's pattern), calls the
 * police procs with the mobs already in place and steps the clocks by writing the warrant's start times; none
 * of them waits.
 */

// ===== FIXTURES =====

/// A fake trader outpost over the test room (a `size` by `size` template from the room's corner), with its police
/datum/unit_test/proc/wanted_outpost(size = 20)
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = size
	outpost.outpost_template.height = size
	outpost.template_bottom_left = run_loc_floor_bottom_left
	return outpost

/// The test room's tile `dx`, `dy` from its corner
/datum/unit_test/proc/wanted_spot(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/// A conscious human with a mind at `where`
/datum/unit_test/proc/wanted_person(turf/where)
	var/mob/living/carbon/human/person = allocate(/mob/living/carbon/human/consistent, where)
	person.mind_initialize()
	allocated += person.mind
	return person

/**
 * A ship with an account holding `balance`. With `person`, they join its crew; with `join_record`, the ship's
 * team takes that crew record (a second ship of one crew).
 */
/datum/unit_test/proc/wanted_ship(mob/living/carbon/human/person, balance = 0, datum/voidcrew_crew_record/join_record)
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = ship
	ship.ship_team = team
	var/datum/bank_account/account = allocate(/datum/bank_account, "Police test [REF(ship)]", null, 1, FALSE)
	account.account_balance = balance
	ship.ship_account = account
	if(person)
		team.join_member(person.mind)
	else if(join_record)
		team.set_crew_record(join_record)
	return ship

/// Takes the ships' teams and their crew records apart, or none of them is ever collected
/datum/unit_test/proc/wanted_cleanup(list/ships)
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		var/datum/team/voidcrew/team = ship.ship_team
		if(!team)
			continue
		var/datum/voidcrew_crew_record/record = team.crew_record
		for(var/datum/mind/member as anything in team.members.Copy())
			team.remove_member(member)
		team.ship = null
		ship.ship_team = null
		if(record)
			qdel(record)

/// A beat officer on `outpost`'s roster at `where`
/datum/unit_test/proc/wanted_officer(obj/structure/overmap/trader_outpost/outpost, turf/where)
	return police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, where)

// ===== THE HEAT TABLE =====

/// The sim's 22 rows (balance/output_final.txt): the same heat and the same stars
/datum/unit_test/voidcrew_outpost_police_heat_table

/datum/unit_test/voidcrew_outpost_police_heat_table/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(police, "The fake outpost has no police")
	// name, crimes (OUTPOST_CRIME_*), heat, stars
	var/list/rows = list(
		list("one shove", list("unarmed"), 6, 0),
		list("two punches", list("unarmed", "unarmed"), 12, 1),
		list("bar fight, 6 punches", list("unarmed", "unarmed", "unarmed", "unarmed", "unarmed", "unarmed"), 36, 2),
		list("one stab", list("armed"), 9, 0),
		list("two stabs", list("armed", "armed"), 18, 1),
		list("three stabs", list("armed", "armed", "armed"), 27, 2),
		list("one shot into a visitor", list("shot"), 25, 2),
		list("two shots into a visitor", list("shot", "shot"), 50, 3),
		list("shoot a visitor dead", list("shot", "shot", "murder"), 110, 4),
		list("kick a vending machine 10x", list("vandalism", "vandalism", "vandalism", "vandalism", "vandalism", "vandalism", "vandalism", "vandalism", "vandalism", "vandalism"), 49, 2),
		list("gun drawn past the checkpoint", list("weapon_drawn"), 10, 1),
		list("gun drawn, then fired twice", list("weapon_drawn", "gunfire", "gunfire"), 40, 2),
		list("forced checkpoint", list("breach"), 25, 2),
		list("punch an officer once", list("resist"), 8, 0),
		list("2 punches, then shove the officer 3x", list("unarmed", "unarmed", "resist", "resist", "resist"), 36, 2),
		list("shoot an officer", list("officer"), 50, 3),
		list("kill one officer", list("officer", "officer_kill"), 95, 4),
		list("kill two officers", list("officer", "officer_kill", "officer_kill"), 140, 5),
		list("kill three officers", list("officer", "officer_kill", "officer_kill", "officer_kill"), 180, 5),
		list("murder, then kill one officer", list("shot", "murder", "officer", "officer_kill"), 160, 5),
		list("break out of the cell", list("unarmed", "unarmed", "jailbreak"), 50, 3),
		list("crewmate of a 4-star offender", list("accomplice"), 25, 2),
	)
	for(var/list/row as anything in rows)
		var/heat = 0
		for(var/crime in row[2])
			heat = police.heat_after(heat, crime)
		TEST_ASSERT_EQUAL(heat, row[3], "'[row[1]]' came to [heat] heat, not [row[3]]")
		TEST_ASSERT_EQUAL(police.stars_of(heat), row[4], "'[row[1]]' is [police.stars_of(heat)] stars, not [row[4]]")

/// Ceilings, floors and the cap
/datum/unit_test/voidcrew_outpost_police_ceilings

/datum/unit_test/voidcrew_outpost_police_ceilings/Run()
	var/datum/outpost_police/police = wanted_outpost().police
	TEST_ASSERT_EQUAL(police.heat_after(60, "vandalism"), 60, "A crime with a two-star ceiling lowered a three-star warrant")
	TEST_ASSERT_EQUAL(police.heat_after(40, "gunfire"), 49, "A two-star ceiling let heat reach three stars")
	TEST_ASSERT_EQUAL(police.heat_after(30, "gunfire"), 45, "A crime under its ceiling did not add its points")
	TEST_ASSERT_EQUAL(police.heat_after(0, "jailbreak"), 50, "A three-star floor did not lift an empty warrant")
	TEST_ASSERT_EQUAL(police.heat_after(0, "weapon_drawn"), 10, "A drawn gun is not one star")
	TEST_ASSERT_EQUAL(police.heat_after(175, "officer_kill"), 180, "Heat went past the cap")
	TEST_ASSERT_EQUAL(police.heat_after(0, "murder"), 60, "A killing is not at least three stars")

// ===== WITNESSES =====

/// A crime counts only when someone saw it; the victim is a witness unless they are a crewmate or cannot see
/datum/unit_test/voidcrew_outpost_police_witness

/datum/unit_test/voidcrew_outpost_police_witness/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/stranger = wanted_person(wanted_spot(1, 0))

	// A conscious victim is a witness
	var/mob/living/carbon/human/puncher = wanted_person(wanted_spot(0, 0))
	var/result = police.report_crime(puncher, "unarmed", stranger)
	TEST_ASSERT_NOTNULL(result, "A punch in front of its victim did not count")
	TEST_ASSERT_EQUAL(result, 0, "One punch is not under one star")
	TEST_ASSERT_EQUAL(police.warrants[puncher.mind].heat, 6, "A counted punch is not 6 heat")
	// Abuse SF4: the perception lets go of the witness once the report has read it
	TEST_ASSERT_NULL(police.perception.last_witness, "The perception still holds the last witness")
	TEST_ASSERT_NULL(police.perception.last_witnesses, "The perception still holds the last witnesses")

	// Nobody there, no heat
	var/mob/living/carbon/human/hidden = wanted_person(wanted_spot(0, 1))
	var/mob/living/carbon/human/mindless = allocate(/mob/living/carbon/human/consistent, wanted_spot(1, 1))
	TEST_ASSERT_NULL(police.report_crime(hidden, "unarmed", mindless), "A punch on someone with no mind, seen by nobody, counted")
	TEST_ASSERT_NULL(police.warrants[hidden.mind], "An unseen crime made a warrant")
	TEST_ASSERT_NULL(police.report_crime(hidden, "armed"), "A crime against nobody, seen by nobody, counted")

	// A crewmate victim is not a witness
	var/mob/living/carbon/human/captain = wanted_person(wanted_spot(0, 2))
	var/mob/living/carbon/human/crewmate = wanted_person(wanted_spot(1, 2))
	var/obj/structure/overmap/ship/ship = wanted_ship(captain)
	ship.ship_team.join_member(crewmate.mind)
	TEST_ASSERT_NULL(police.report_crime(captain, "unarmed", crewmate), "A crewmate victim witnessed their own crewmate")

	// An unconscious victim is not a witness
	var/mob/living/carbon/human/knocked = wanted_person(wanted_spot(2, 0))
	var/mob/living/carbon/human/sleeper = wanted_person(wanted_spot(2, 1))
	sleeper.stat = UNCONSCIOUS
	TEST_ASSERT_NULL(police.report_crime(knocked, "unarmed", sleeper), "An unconscious victim witnessed the crime")
	sleeper.stat = CONSCIOUS

	// The scanner and the cell need no one in sight
	var/mob/living/carbon/human/armed = wanted_person(wanted_spot(2, 2))
	TEST_ASSERT_EQUAL(police.report_crime(armed, "weapon_drawn"), 1, "A drawn gun with nobody about is not one star") // OUTPOST_CRIME_WEAPON_DRAWN

	// A crime on an officer needs a living officer
	var/mob/living/carbon/human/brawler = wanted_person(wanted_spot(3, 0))
	TEST_ASSERT_NULL(police.report_crime(brawler, "resist"), "A shove on an officer counted with no officer alive") // OUTPOST_CRIME_RESIST
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(3, 3))
	var/mob/living/carbon/human/brawler_two = wanted_person(wanted_spot(3, 1))
	TEST_ASSERT_NOTNULL(police.report_crime(brawler_two, "resist", officer), "A shove on an officer did not count with an officer alive")
	officer.stat = DEAD
	var/mob/living/carbon/human/brawler_three = wanted_person(wanted_spot(3, 2))
	TEST_ASSERT_NULL(police.report_crime(brawler_three, "resist", officer), "A shove on a dead officer, with none left alive, counted")
	officer.stat = CONSCIOUS
	wanted_cleanup(list(ship))

/// A person with no mind cannot have a record
/datum/unit_test/voidcrew_outpost_police_no_mind

/datum/unit_test/voidcrew_outpost_police_no_mind/Run()
	var/datum/outpost_police/police = wanted_outpost().police
	var/mob/living/carbon/human/mindless = allocate(/mob/living/carbon/human/consistent, wanted_spot(0, 0))
	var/mob/living/carbon/human/victim = wanted_person(wanted_spot(1, 0))
	TEST_ASSERT_NULL(police.report_crime(mindless, "unarmed", victim), "Someone with no mind got a record")
	TEST_ASSERT_EQUAL(length(police.warrants), 0, "A mindless offender made a warrant")

// ===== DEDUPE AND EVIDENCE =====

/// Same offender within half a second folds; a folded report still lends its weapon; only a counted crime's weapon is evidence, eight at most
/datum/unit_test/voidcrew_outpost_police_dedupe

/datum/unit_test/voidcrew_outpost_police_dedupe/Run()
	var/datum/outpost_police/police = wanted_outpost().police
	var/mob/living/carbon/human/stabber = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/victim = wanted_person(wanted_spot(1, 0))
	var/obj/item/crowbar/first = allocate(/obj/item/crowbar)
	var/obj/item/wrench/second = allocate(/obj/item/wrench)

	TEST_ASSERT_EQUAL(police.report_crime(stabber, "armed", victim, first), 0, "The first stab did not count")
	var/datum/outpost_warrant/warrant = police.warrants[stabber.mind]
	TEST_ASSERT_EQUAL(warrant.heat, 9, "One stab is not 9 heat")
	TEST_ASSERT(WEAKREF(first) in warrant.evidence, "The weapon of a counted crime is not evidence")
	// OUTPOST_AGGRESSION_GRACE is half a second
	TEST_ASSERT_NULL(police.report_crime(stabber, "armed", victim, second), "A second report in the same instant counted")
	TEST_ASSERT_EQUAL(warrant.heat, 9, "A folded report added heat")
	TEST_ASSERT(WEAKREF(second) in warrant.evidence, "A folded report's weapon was lost")
	police.recent_reports.Cut()
	TEST_ASSERT_EQUAL(police.report_crime(stabber, "armed", victim, first), 1, "A report after the grace did not count")
	TEST_ASSERT_EQUAL(warrant.heat, 18, "Two stabs are not 18 heat")
	TEST_ASSERT_EQUAL(length(warrant.evidence), 2, "The same weapon was listed twice")

	// An unwitnessed crime's weapon is not evidence
	var/mob/living/carbon/human/lurker = wanted_person(wanted_spot(0, 1))
	TEST_ASSERT_NULL(police.report_crime(lurker, "armed", null, first), "An unseen stab counted")
	TEST_ASSERT_NULL(police.warrants[lurker.mind], "An unseen stab made a warrant")

	// Eight at most, the oldest out
	var/list/tools = list()
	for(var/i in 1 to 9)
		var/obj/item/crowbar/tool = allocate(/obj/item/crowbar)
		tools += tool
		police.recent_reports.Cut()
		police.report_crime(stabber, "armed", victim, tool)
	TEST_ASSERT_EQUAL(length(warrant.evidence), 8, "A warrant remembers [length(warrant.evidence)] weapons, not 8") // OUTPOST_POLICE_EVIDENCE_MAX
	TEST_ASSERT(!(WEAKREF(tools[1]) in warrant.evidence), "The oldest weapon was kept past the cap")
	TEST_ASSERT(WEAKREF(tools[9]) in warrant.evidence, "The newest weapon was dropped")

// ===== A WITNESS WHO TAKES TIME TO REPORT =====

/// A perception that makes its witness wait three seconds, and can be told the witness can no longer report
/datum/outpost_police_perception/test_delayed
	var/witness_can_report = TRUE

/datum/outpost_police_perception/test_delayed/report_delay(atom/witness, crime)
	return 3 SECONDS

/datum/outpost_police_perception/test_delayed/can_report(atom/witness)
	return witness_can_report

/// A report with a delay is queued and confirmed on the tick if its witness can still report; otherwise it is dropped
/datum/unit_test/voidcrew_outpost_police_pending

/datum/unit_test/voidcrew_outpost_police_pending/Run()
	var/datum/outpost_police/police = wanted_outpost().police
	var/datum/outpost_police_perception/test_delayed/slow = new(police)
	qdel(police.perception)
	police.perception = slow

	var/mob/living/carbon/human/victim = wanted_person(wanted_spot(1, 0))
	var/mob/living/carbon/human/reported = wanted_person(wanted_spot(0, 0))
	TEST_ASSERT_NULL(police.report_crime(reported, "unarmed", victim), "A report with a delay counted at once")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "A report with a delay was not queued")
	TEST_ASSERT_NULL(police.warrants[reported.mind], "A queued report made a warrant before its witness finished")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	report.due = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A due report stayed queued")
	TEST_ASSERT_EQUAL(police.warrants[reported.mind]?.heat, 6, "A due report was not confirmed")

	var/mob/living/carbon/human/silenced = wanted_person(wanted_spot(0, 1))
	TEST_ASSERT_NULL(police.report_crime(silenced, "unarmed", victim), "A second report with a delay counted at once")
	slow.witness_can_report = FALSE
	var/datum/outpost_pending_report/dropped = police.pending_reports[1]
	dropped.due = world.time
	police.tick_warrants()
	TEST_ASSERT_NULL(police.warrants[silenced.mind], "A witness who could no longer report still got a warrant made")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "A report was dropped while its witness might still come round")
	// Kept OUTPOST_POLICE_PENDING_KEEP for the witness to come round, then dropped
	dropped.expires = world.time
	police.tick_warrants()
	TEST_ASSERT_NULL(police.warrants[silenced.mind], "A witness who never came round still got a warrant made")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 0, "A dropped report stayed queued")

// ===== SELF-DEFENCE (abuse M14) =====

/// The victim's self-defence window opens whether or not anyone saw the first hit, and hitting back inside it records nothing
/datum/unit_test/voidcrew_outpost_police_self_defence

/datum/unit_test/voidcrew_outpost_police_self_defence/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/attacker = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/defender = wanted_person(wanted_spot(1, 0))
	// The only person who could have seen it is out cold
	defender.stat = UNCONSCIOUS
	outpost.register_pvp_aggression(defender, attacker, "unarmed")
	TEST_ASSERT_NULL(police.warrants[attacker.mind], "An unseen first hit made a warrant")
	var/list/defender_targets = outpost.self_defense_targets[defender.mind]
	// OUTPOST_SELF_DEFENSE_DURATION is 2 minutes
	TEST_ASSERT_EQUAL(defender_targets[attacker.mind], world.time + 2 MINUTES, "An unseen first hit did not open the victim's window")
	defender.stat = CONSCIOUS
	outpost.register_pvp_aggression(attacker, defender, "unarmed")
	TEST_ASSERT_NULL(police.warrants[defender.mind], "Hitting back inside the window made the defender a suspect")
	TEST_ASSERT_NULL(outpost.self_defense_targets[attacker.mind], "Hitting back gave the attacker a window of their own")
	// A later hit by the attacker (past the half-second fold, OUTPOST_AGGRESSION_GRACE), with the defender watching, counts
	police.recent_reports.Cut()
	outpost.register_pvp_aggression(defender, attacker, "unarmed")
	TEST_ASSERT_NOTNULL(police.warrants[attacker.mind], "A seen hit by the first aggressor did not count")

// ===== FADING, PRIORS AND THE BAR =====

/// Hide 30 s at one star and 45 at two, nothing at three at the outpost, away 10 s whatever the level; the prior; the bar; an empty warrant is dropped
/datum/unit_test/voidcrew_outpost_police_fade

/datum/unit_test/voidcrew_outpost_police_fade/Run()
	// A template of one tile: the corner is the outpost, the rest of the room is away
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost(1)
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/suspect = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/witness = wanted_person(wanted_spot(3, 3))
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 15)

	// One star: hidden 29 s, nothing; 30 s, a point a second
	warrant.unseen_since = world.time - 29 SECONDS // OUTPOST_POLICE_HIDE_1 is 30 seconds
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 15, "Heat faded before the one-star hide time")
	warrant.unseen_since = world.time - 30 SECONDS
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 14, "Heat did not fade after the one-star hide time")

	// Two stars: 45 s
	warrant.heat = 30
	warrant.unseen_since = world.time - 44 SECONDS // OUTPOST_POLICE_HIDE_2 is 45 seconds
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 30, "Heat faded before the two-star hide time")
	warrant.unseen_since = world.time - 45 SECONDS
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 29, "Heat did not fade after the two-star hide time")

	// Three stars at the outpost never fade, and the bar starts to run
	warrant.heat = 60
	warrant.unseen_since = world.time - 10 MINUTES
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 60, "Heat faded at three stars with the suspect at the outpost")
	TEST_ASSERT_EQUAL(warrant.barred_until, world.time + 15 MINUTES, "Three stars did not start the 15 minute bar") // OUTPOST_POLICE_BAR_TIME

	// Away: 9 s, nothing; 10 s, a point a second, at any level
	suspect.forceMove(wanted_spot(2, 2))
	police.tick_warrants()
	TEST_ASSERT(warrant.away_since, "Leaving the outpost did not start the away clock")
	warrant.away_since = world.time - 9 SECONDS // OUTPOST_POLICE_AWAY_GRACE is 10 seconds
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 60, "Heat faded before the away grace")
	warrant.away_since = world.time - 10 SECONDS
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 59, "Heat did not fade away from the outpost")

	// Fading to nothing leaves a prior, and the next crime starts from it
	warrant.heat = 1
	warrant.peak = 36
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 0, "Heat did not reach 0")
	TEST_ASSERT_EQUAL(warrant.prior, 36, "A faded warrant did not leave its peak as a prior")
	TEST_ASSERT_NOTNULL(police.warrants[suspect.mind], "A warrant with a prior was dropped")
	TEST_ASSERT_EQUAL(police.report_crime(suspect, "unarmed", witness), 2, "A punch on top of a prior of 36 is not two stars")
	TEST_ASSERT_EQUAL(warrant.heat, 42, "The next crime did not start from the prior")
	warrant.prior_set_at = world.time - 10 MINUTES // half of OUTPOST_POLICE_PRIOR_TIME
	TEST_ASSERT_EQUAL(police.current_prior(warrant), 18, "The prior did not wear down linearly")
	warrant.prior_set_at = world.time - 20 MINUTES
	TEST_ASSERT_EQUAL(police.current_prior(warrant), 0, "The prior outlived its time")

	// A bar refuses service with no stars, and the empty warrant goes when it ends
	warrant.heat = 0
	warrant.prior = 0
	warrant.barred_until = world.time + 5 MINUTES
	TEST_ASSERT_EQUAL(police.get_stars(suspect.mind), 0, "A barred person with no heat has stars")
	TEST_ASSERT(police.is_barred(suspect), "A bar did not refuse service")
	police.tick_warrants()
	TEST_ASSERT_NOTNULL(police.warrants[suspect.mind], "A warrant was dropped while its bar ran")
	warrant.barred_until = world.time - 1
	police.tick_warrants()
	TEST_ASSERT_NULL(police.warrants[suspect.mind], "A warrant with no heat, prior or bar was kept")
	TEST_ASSERT(!police.is_barred(suspect), "A finished bar still refused service")

/// An officer in sight keeps the suspect seen: nothing fades at one star while they stay in view
/datum/unit_test/voidcrew_outpost_police_seen

/datum/unit_test/voidcrew_outpost_police_seen/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/suspect = wanted_person(wanted_spot(0, 0))
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 15)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(2, 0))
	warrant.unseen_since = world.time - 10 MINUTES
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 15, "Heat faded while an officer watched")
	TEST_ASSERT_EQUAL(warrant.unseen_since, 0, "An officer in view did not clear the unseen clock")
	TEST_ASSERT_EQUAL(warrant.last_seen_turf, get_turf(suspect), "The sighting did not record where the suspect was")
	// The officer is knocked out: seen no more, and the clock starts
	officer.stat = UNCONSCIOUS
	police.tick_warrants()
	TEST_ASSERT(warrant.unseen_since, "An unconscious officer still saw the suspect")
	officer.stat = CONSCIOUS

// ===== THE RECORD OF A CREW: ACCOMPLICES AND THE EMBARGO =====

/// Four stars puts the crew's ships under embargo here and makes the crewmates at the outpost accomplices; five stars lengthens it but never spreads it to other outposts; a dead officer lengthens it; it lapses on its own
/datum/unit_test/voidcrew_outpost_police_incident
	/// What COMSIG_OUTPOST_POLICE_OFFICER_DOWN told us
	var/list/down_log = list()

/datum/unit_test/voidcrew_outpost_police_incident/proc/on_down(datum/source, mob/living/officer, mob/living/killer)
	SIGNAL_HANDLER
	down_log += list(list(officer, killer))

/datum/unit_test/voidcrew_outpost_police_incident/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/obj/structure/overmap/trader_outpost/other = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/leader = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/mate = wanted_person(wanted_spot(1, 0))
	var/mob/living/carbon/human/absent = wanted_person(wanted_spot(1, 1))
	var/obj/structure/overmap/ship/ship = wanted_ship(leader)
	ship.ship_team.join_member(mate.mind)
	ship.ship_team.join_member(absent.mind)
	absent.moveToNullspace()
	var/datum/voidcrew_crew_record/crew = leader.mind.get_reputation_crew()
	TEST_ASSERT_NOTNULL(crew, "The test crew has no record")
	RegisterSignal(police, "outpost_police_officer_down", PROC_REF(on_down)) // COMSIG_OUTPOST_POLICE_OFFICER_DOWN

	// Four stars
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, leader.mind, 100)
	warrant.crew = crew
	police.tick_warrants()
	TEST_ASSERT(outpost.is_ship_embargoed(ship), "Four stars did not embargo the crew's ship here")
	TEST_ASSERT(!other.is_ship_embargoed(ship), "Four stars embargoed the ship at another outpost")
	var/datum/outpost_incident/incident = police.incidents[crew]
	TEST_ASSERT_NOTNULL(incident, "Four stars made no incident")
	TEST_ASSERT_EQUAL(incident.ends_at, world.time + 15 MINUTES, "The four-star embargo is not 15 minutes") // OUTPOST_POLICE_EMBARGO
	TEST_ASSERT_EQUAL(police.get_stars(mate.mind), 2, "A crewmate at the outpost is not an accomplice at two stars")
	TEST_ASSERT_EQUAL(police.force_level(mate), 2, "An accomplice would be shot, not arrested") // POLICE_FORCE_STUN
	TEST_ASSERT_NULL(police.get_warrant(absent.mind), "A crewmate away from the outpost is an accomplice")

	// Five stars
	warrant.heat = 150
	police.tick_warrants()
	TEST_ASSERT(outpost.is_ship_embargoed(ship), "Five stars lifted the embargo here")
	TEST_ASSERT(!other.is_ship_embargoed(ship), "Five stars spread the embargo to another outpost")
	TEST_ASSERT_EQUAL(incident.ends_at, world.time + 30 MINUTES, "The five-star embargo is not 30 minutes")

	// An officer killed by the leader: five minutes more, announced
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(3, 3))
	police.record_victim(warrant, officer)
	police.on_wanted_death(null, officer, FALSE)
	TEST_ASSERT_EQUAL(warrant.officers_killed, 1, "A dead officer was not counted against their killer")
	TEST_ASSERT_EQUAL(incident.ends_at, world.time + 35 MINUTES, "A dead officer did not add 5 minutes") // OUTPOST_POLICE_EMBARGO_PER_KILL
	TEST_ASSERT_EQUAL(outpost.embargoed_ships[ship], incident.ends_at, "The longer embargo did not reach the ship here")
	TEST_ASSERT(!other.is_ship_embargoed(ship), "A dead officer spread the embargo to another outpost")
	TEST_ASSERT_EQUAL(warrant.heat, 180, "Killing an officer did not take the warrant to the cap")
	TEST_ASSERT_EQUAL(length(down_log), 1, "The officer's death was not announced once")
	TEST_ASSERT_EQUAL(down_log[1][2], leader, "The announcement did not name the killer")

	// It runs out on its own: the next tick after its end forgets the incident, and the embargo has lapsed
	police.remove_warrant(warrant)
	incident.ends_at = world.time
	outpost.embargoed_ships[ship] = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(length(police.incidents), 0, "A lapsed embargo left the incident")
	TEST_ASSERT(!outpost.is_ship_embargoed(ship), "The embargo here outlived its time")
	wanted_cleanup(list(ship))

/// A killing is the killer's MURDER when the victim died within 30 seconds of a counted hit
/datum/unit_test/voidcrew_outpost_police_murder

/datum/unit_test/voidcrew_outpost_police_murder/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/killer = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/victim = wanted_person(wanted_spot(1, 0))
	police.report_crime(killer, "unarmed", victim)
	var/datum/outpost_warrant/warrant = police.warrants[killer.mind]
	TEST_ASSERT_EQUAL(warrant.heat, 6, "The test's first hit is not 6 heat")
	police.on_wanted_death(null, victim, FALSE)
	TEST_ASSERT_EQUAL(warrant.heat, 66, "A victim dying right after a hit was not a murder") // OUTPOST_CRIME_MURDER: 60 points
	TEST_ASSERT_EQUAL(police.get_stars(killer.mind), 3, "A murder is not three stars")

	// Too late, nothing
	var/mob/living/carbon/human/other_killer = wanted_person(wanted_spot(0, 1))
	var/mob/living/carbon/human/other_victim = wanted_person(wanted_spot(1, 1))
	police.report_crime(other_killer, "unarmed", other_victim)
	var/datum/outpost_warrant/other_warrant = police.warrants[other_killer.mind]
	other_warrant.recent_victims[WEAKREF(other_victim)] = world.time - 31 SECONDS // OUTPOST_POLICE_KILL_WINDOW is 30 seconds
	police.on_wanted_death(null, other_victim, FALSE)
	TEST_ASSERT_EQUAL(other_warrant.heat, 6, "A death after the window was a murder")

// ===== STRIKES ON OFFICERS (abuse M3) =====

/// A stamina weapon or a weapon hit on an officer is an assault; a shove or bare fists are resisting; a cuff attempt is an assault
/datum/unit_test/voidcrew_outpost_police_officer_struck

/datum/unit_test/voidcrew_outpost_police_officer_struck/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(3, 3))

	var/mob/living/carbon/human/stunner = wanted_person(wanted_spot(0, 0))
	police.officer_struck(officer, stunner, ATTACKER_STAMINA_ATTACK)
	TEST_ASSERT_EQUAL(police.warrants[stunner.mind]?.heat, 50, "A stamina hit on an officer was not an assault with a three-star floor") // OUTPOST_CRIME_ASSAULT_OFFICER

	var/mob/living/carbon/human/shover = wanted_person(wanted_spot(0, 1))
	police.officer_struck(officer, shover, ATTACKER_SHOVING)
	TEST_ASSERT_EQUAL(police.warrants[shover.mind]?.heat, 8, "A shove on an officer was not resisting") // OUTPOST_CRIME_RESIST

	var/mob/living/carbon/human/fighter = wanted_person(wanted_spot(0, 2))
	police.officer_struck(officer, fighter, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(police.warrants[fighter.mind]?.heat, 8, "Bare fists on an officer were not resisting")

	var/mob/living/carbon/human/swinger = wanted_person(wanted_spot(1, 0))
	var/obj/item/crowbar/bar = allocate(/obj/item/crowbar)
	swinger.put_in_active_hand(bar)
	police.officer_struck(officer, swinger, ATTACKER_DAMAGING_ATTACK)
	TEST_ASSERT_EQUAL(police.warrants[swinger.mind]?.heat, 50, "A weapon hit on an officer was not an assault")
	TEST_ASSERT(WEAKREF(bar) in police.warrants[swinger.mind]?.evidence, "The weapon that hit an officer is not evidence")

	var/mob/living/carbon/human/cuffer = wanted_person(wanted_spot(1, 1))
	police.officer_cuff_attempt(officer, cuffer)
	TEST_ASSERT_EQUAL(police.warrants[cuffer.mind]?.heat, 50, "Trying to cuff an officer was not an assault")

// ===== THE FINE (abuse M6, M7) =====

/// All or nothing from the current crew's accounts pooled, richest first; one credit short takes nothing; a crew the offender left never pays (abuse MF6)
/datum/unit_test/voidcrew_outpost_police_fine

/datum/unit_test/voidcrew_outpost_police_fine/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	police.profile.fine_multiplier = 1
	var/mob/living/carbon/human/payer = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/witness = wanted_person(wanted_spot(1, 0))
	var/obj/structure/overmap/ship/rich = wanted_ship(payer, 500)
	var/obj/structure/overmap/ship/poor = wanted_ship(null, 400, payer.mind.get_reputation_crew())

	// One star: 300, from the richer ship alone
	police.report_crime(payer, "unarmed", witness)
	police.recent_reports.Cut()
	police.report_crime(payer, "unarmed", witness)
	var/datum/outpost_warrant/warrant = police.warrants[payer.mind]
	TEST_ASSERT_EQUAL(police.get_stars(payer.mind), 1, "The test warrant is not one star")
	var/datum/voidcrew_crew_record/old_crew = payer.mind.get_reputation_crew()
	TEST_ASSERT_EQUAL(warrant.crew, old_crew, "The warrant does not know the offender's crew")
	// The offender leaves the crew: it never pays for them, and with no crew nobody does (jail)
	payer.mind.leave_reputation_crew()
	TEST_ASSERT(!police.charge_fine(warrant), "A crew the offender left paid their fine")
	TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 500, "A crew the offender left lost money to their fine")
	TEST_ASSERT_NULL(warrant.crew, "The warrant still names a crew the offender left")
	// They join another crew: that one pays
	var/obj/structure/overmap/ship/other = wanted_ship(payer, 1000)
	TEST_ASSERT(police.charge_fine(warrant), "The offender's new crew did not pay their fine")
	TEST_ASSERT_EQUAL(other.ship_account.account_balance, 700, "The new crew did not pay the whole fine") // OUTPOST_POLICE_FINES: 300 at one star
	TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 500, "The old crew paid part of the new crew's fine")
	// Back on the old crew
	rich.ship_team.join_member(payer.mind)
	TEST_ASSERT_EQUAL(payer.mind.get_reputation_crew(), old_crew, "Setup: the offender did not rejoin their old crew")
	TEST_ASSERT(police.charge_fine(warrant), "The fine was not charged to the offender's crew")
	TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 200, "The richer ship did not pay the whole fine")
	TEST_ASSERT_EQUAL(poor.ship_account.account_balance, 400, "The poorer ship paid part of a fine the richer one covered")
	TEST_ASSERT_EQUAL(warrant.fine_level, 1, "The fine's level was not fixed at the first charge")

	// Two stars: 800 across both, all or nothing
	rich.ship_account.account_balance = 500
	poor.ship_account.account_balance = 299
	warrant.heat = 30
	warrant.fine_level = 0
	TEST_ASSERT(!police.charge_fine(warrant), "A fine one credit beyond the pooled accounts was charged")
	TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 500, "A fine that could not be paid took money from the richer ship")
	TEST_ASSERT_EQUAL(poor.ship_account.account_balance, 299, "A fine that could not be paid took money from the poorer ship")
	rich.ship_account.account_balance = 501
	TEST_ASSERT(police.charge_fine(warrant), "A fine the pooled accounts exactly cover was refused")
	TEST_ASSERT_EQUAL(rich.ship_account.account_balance, 0, "The richer ship was not drawn first")
	TEST_ASSERT_EQUAL(poor.ship_account.account_balance, 0, "The poorer ship did not pay the rest")

	// No crew, no fine
	payer.mind.leave_reputation_crew()
	TEST_ASSERT(!police.charge_fine(warrant), "An offender with no crew was charged a fine")
	wanted_cleanup(list(rich, poor, other))

// ===== WHO IS REFUSED SERVICE =====

/// Stars, the bar and the embargo each refuse service; force follows the stars
/datum/unit_test/voidcrew_outpost_police_barred

/datum/unit_test/voidcrew_outpost_police_barred/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/clean = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/starred = wanted_person(wanted_spot(1, 0))
	var/mob/living/carbon/human/barred = wanted_person(wanted_spot(0, 1))
	var/mob/living/carbon/human/embargoed = wanted_person(wanted_spot(1, 1))
	TEST_ASSERT(!police.is_barred(clean), "A clean visitor is refused service")
	TEST_ASSERT_EQUAL(police.force_level(clean), 0, "A clean visitor can be arrested") // POLICE_FORCE_NONE

	police_pin_warrant(police, starred.mind, 10)
	TEST_ASSERT(police.is_barred(starred), "A star did not refuse service")
	TEST_ASSERT_EQUAL(police.force_level(starred), 1, "One star is not an arrest") // POLICE_FORCE_ARREST
	police.warrants[starred.mind].heat = 25
	TEST_ASSERT_EQUAL(police.force_level(starred), 2, "Two stars are not a stun") // POLICE_FORCE_STUN
	police.warrants[starred.mind].heat = 50
	TEST_ASSERT_EQUAL(police.force_level(starred), 3, "Three stars are not lethal") // POLICE_FORCE_LETHAL
	starred.stat = DEAD
	TEST_ASSERT_EQUAL(police.force_level(starred), 0, "A dead suspect can be arrested") // POLICE_FORCE_NONE
	starred.stat = CONSCIOUS

	var/datum/outpost_warrant/bar_warrant = police_pin_warrant(police, barred.mind, 0)
	bar_warrant.barred_until = world.time + 5 MINUTES
	TEST_ASSERT(police.is_barred(barred), "A bar did not refuse service")
	TEST_ASSERT_EQUAL(police.force_level(barred), 0, "A bar with no stars can be arrested") // POLICE_FORCE_NONE

	var/obj/structure/overmap/ship/ship = wanted_ship(embargoed)
	outpost.embargo_ship(ship, 15 MINUTES)
	TEST_ASSERT(police.is_barred(embargoed), "An embargo did not refuse the crew service")
	outpost.embargoed_ships -= ship
	TEST_ASSERT(!police.is_barred(embargoed), "A lifted embargo still refuses service")
	wanted_cleanup(list(ship))

// ===== THE KINGPIN'S SHOOTOUT (abuse M16) =====

/// A hunter engaged in the kingpin's shootout is excused a drawn gun, gunfire and vandalism; one who is not is not; a hit on a person still counts
/datum/unit_test/voidcrew_bounty_kingpin/police_excuse

/datum/unit_test/voidcrew_bounty_kingpin/police_excuse/Run()
	kingpin_test_begin()
	var/obj/structure/overmap/trader_outpost/outpost = allocate(/obj/structure/overmap/trader_outpost)
	outpost.outpost_template = allocate(/datum/map_template/trader_outpost)
	outpost.outpost_template.width = 5
	outpost.outpost_template.height = 5
	outpost.template_bottom_left = run_loc_floor_bottom_left
	var/datum/outpost_police/police = outpost.police

	var/datum/criminal_bounty/kingpin/posting = kingpin_test_posting()
	var/mob/living/carbon/human/npc/bounty_criminal/kingpin/kingpin = kingpin_test_lounge(posting, 2)
	var/datum/bounty_kingpin_crew/crew = kingpin.kingpin_crew
	var/list/goons = crew.goons()
	var/mob/living/carbon/human/npc/bounty_kingpin_goon/goon = goons[1]
	var/mob/living/carbon/human/hunter = kingpin_test_person(kingpin_test_spot(2, 2), null)
	var/mob/living/carbon/human/idle_hunter = kingpin_test_person(kingpin_test_spot(1, 3), null)
	var/mob/living/carbon/human/brawler = kingpin_test_person(kingpin_test_spot(1, 2), null)
	var/mob/living/carbon/human/victim = kingpin_test_person(kingpin_test_spot(3, 2), null)
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(crew.crew_seat), outpost, "The test lounge isn't at the test outpost")
	crew.start_shootout(hunter, TRUE)
	crew.add_hunter(idle_hunter)
	crew.add_hunter(brawler)
	crew.member_attacked(goon, list(hunter, brawler))
	TEST_ASSERT(crew.engaged(hunter), "A hunter who just shot a goon isn't counted in the fight")

	for(var/stray in list("weapon_drawn", "gunfire", "vandalism")) // OUTPOST_CRIME_WEAPON_DRAWN, _GUNFIRE, _VANDALISM
		police.recent_reports.Cut()
		TEST_ASSERT_NULL(police.report_crime(hunter, stray), "An engaged hunter was reported for '[stray]'")
	TEST_ASSERT_NULL(police.warrants[hunter.mind], "An engaged hunter's stray fire made a warrant")
	TEST_ASSERT_NOTNULL(police.report_crime(idle_hunter, "weapon_drawn"), "A hunter not in the fight was excused a drawn gun")
	// A hit on a person still counts
	outpost.register_pvp_aggression(victim, brawler, "unarmed")
	TEST_ASSERT_NOTNULL(police.warrants[brawler.mind], "An engaged hunter's hit on a person was excused")
	crew.stand_down()
	kingpin_test_end()

/**
 * Abuse review 3 MF1: a bomb is blamed on whoever armed it, never on the last hand to touch it. A primed grenade picked
 * up by someone standing beside an officer, which then catches the officer, puts no stars on the one holding it; the
 * one who primed it, out of sight, gets none either. Primed in view, the officer it catches sees who did it.
 */
/datum/unit_test/voidcrew_outpost_police_bomb_blame

/datum/unit_test/voidcrew_outpost_police_bomb_blame/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	police.sleep_tick()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost)
	var/mob/living/carbon/human/thrower = police_arrest_person(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/hero = police_arrest_person(police_arrest_beside(officer))
	TEST_ASSERT(get_trader_outpost_for_turf(get_turf(thrower)) != outpost, "Setup: the one who primed it is at the outpost")

	// A smoke grenade: armed the same way as any, with no shrapnel cloud to tidy up
	var/obj/item/grenade/smokebomb/grenade = allocate(/obj/item/grenade/smokebomb, get_turf(thrower))
	grenade.arm_grenade(thrower, 1 HOURS, FALSE)
	grenade.forceMove(get_turf(hero))
	hero.put_in_hands(grenade)
	grenade.add_fingerprint(hero)
	TEST_ASSERT_EQUAL(outpost_bomber_of(grenade), thrower, "A primed grenade was blamed on [outpost_bomber_of(grenade)], not whoever primed it")

	GLOB.outpost_pvp_enforcement.on_outpost_bombing(grenade, list(officer))
	police.process_pending_reports()
	TEST_ASSERT_EQUAL(police.get_stars(hero.mind), 0, "Holding someone else's primed grenade when it went off put [police.get_stars(hero.mind)] stars on them")
	TEST_ASSERT_EQUAL(police.get_stars(thrower.mind), 0, "A bomber nobody saw is wanted")

	// The same grenade primed by someone in view of the officer it catches
	sleep(1 SECONDS) // past the half-second report fold
	thrower.forceMove(get_turf(hero))
	var/obj/item/grenade/smokebomb/seen = allocate(/obj/item/grenade/smokebomb, get_turf(thrower))
	seen.arm_grenade(thrower, 1 HOURS, FALSE)
	GLOB.outpost_pvp_enforcement.on_outpost_bombing(seen, list(officer))
	police.process_pending_reports()
	TEST_ASSERT(police.get_stars(thrower.mind) >= 3, "A bomber the officer saw is at [police.get_stars(thrower.mind)] stars, not three") // ASSAULT_OFFICER's floor
	TEST_ASSERT_EQUAL(police.get_stars(hero.mind), 0, "A bystander was charged for a bomb someone else primed")
	police.close_warrant(thrower.mind, FALSE)

/**
 * Review-1 M2: a four-star leader in custody or dead makes no accomplices, so crewmates are not swept up again and
 * again while the leader sits out a sentence. Free and alive at the outpost, the leader still does.
 */
/datum/unit_test/voidcrew_outpost_police_abet_leader_held

/datum/unit_test/voidcrew_outpost_police_abet_leader_held/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/leader = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/mate = wanted_person(wanted_spot(1, 0))
	var/obj/structure/overmap/ship/ship = wanted_ship(leader)
	ship.ship_team.join_member(mate.mind)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, leader.mind, 100) // four stars
	warrant.crew = leader.mind.get_reputation_crew()

	// In custody (an arrest has them in hand)
	var/datum/outpost_police_case/case = new(police, warrant)
	police.cases[leader.mind] = case
	case.cuffed = TRUE
	TEST_ASSERT(police.in_custody(leader), "Setup: the leader is not in custody")
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_stars(mate.mind), 0, "A crewmate was made an accomplice of a leader in custody")
	police.close_case(leader.mind)

	// Free and alive: the crewmate is an accomplice, as before. Owner decision 44: an old prior (five stars, faded a
	// moment ago) stays out of it, and the accomplice is arrested at two stars like a crewmate with a clean record.
	var/datum/outpost_warrant/mate_warrant = police_pin_warrant(police, mate.mind, 0)
	mate_warrant.prior = 140
	mate_warrant.prior_set_at = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_stars(mate.mind), 2, "A crewmate at the outpost is not an accomplice of a free four-star leader at two stars")
	police.remove_warrant(police.get_warrant(mate.mind))

	// Dead: their body makes no accomplices
	leader.death()
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.get_stars(mate.mind), 0, "A crewmate was made an accomplice of a dead leader")
	wanted_cleanup(list(ship))

/**
 * Owner decisions 34 and 37: someone in crit with an arrest on its way to cuff them keeps their stars until the cuffs
 * are on. Before, crit counted as away: a one-star warrant drained to nothing and the arrest closed with them left
 * lying, and three stars fell to two and were fined instead of jailed. With no arrest on them, crit still fades.
 */
/datum/unit_test/voidcrew_outpost_police_crit_arrest_holds

/datum/unit_test/voidcrew_outpost_police_crit_arrest_holds/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/suspect = wanted_person(wanted_spot(0, 0))
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 50) // three stars
	suspect.stat = HARD_CRIT
	warrant.away_since = world.time - 10 MINUTES

	var/datum/outpost_police_case/case = new(police, warrant)
	police.cases[suspect.mind] = case
	TEST_ASSERT(police.arrest_on(suspect), "Setup: no arrest on the suspect")
	TEST_ASSERT(!police.in_custody(suspect), "Setup: the suspect is already in custody")
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 50, "Heat faded from someone in crit with an arrest on its way to them")
	TEST_ASSERT_EQUAL(police.get_stars(suspect.mind), 3, "A three-star suspect in crit fell below three stars before the cuffs")
	police.close_case(suspect.mind)

	// Nobody coming for them: in crit is away, and it fades as before
	police.tick_warrants()
	TEST_ASSERT_EQUAL(warrant.heat, 49, "Heat did not fade from someone in crit with no arrest on them")
	suspect.stat = CONSCIOUS

// ===== THE HALF-SECOND FOLD =====

/// A perception in which only `seen_victim` sees the crime done to them
/datum/outpost_police_perception/test_victim_sees
	var/atom/seen_victim

/datum/outpost_police_perception/test_victim_sees/witness_of(mob/living/offender, crime, atom/victim, obj/item/source)
	last_witness = null
	last_witnesses = null
	if(victim && victim == seen_victim)
		last_witness = victim
		return 1 // POLICE_WITNESS_SAW
	return 0 // POLICE_WITNESS_NONE

/**
 * Inside the half second: a hit folded into a pending report brings its weapon and victim to it, and after an unseen
 * hit a hit on someone else is looked at again (it used to be dropped, whoever saw it).
 */
/datum/unit_test/voidcrew_outpost_police_fold_pending

/datum/unit_test/voidcrew_outpost_police_fold_pending/Run()
	var/datum/outpost_police/police = wanted_outpost().police
	var/datum/outpost_police_perception/test_delayed/slow = new(police)
	qdel(police.perception)
	police.perception = slow
	var/mob/living/carbon/human/brawler = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/first_victim = wanted_person(wanted_spot(1, 0))
	var/mob/living/carbon/human/second_victim = wanted_person(wanted_spot(0, 1))
	var/obj/item/crowbar/first = allocate(/obj/item/crowbar)
	var/obj/item/wrench/second = allocate(/obj/item/wrench)

	TEST_ASSERT_NULL(police.report_crime(brawler, "unarmed", first_victim, first), "A report with a delay counted at once")
	TEST_ASSERT_NULL(police.report_crime(brawler, "unarmed", second_victim, second), "A folded report counted")
	TEST_ASSERT_EQUAL(length(police.pending_reports), 1, "A report in the same instant was queued on its own")
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	report.due = world.time
	police.tick_warrants()
	var/datum/outpost_warrant/warrant = police.warrants[brawler.mind]
	TEST_ASSERT_EQUAL(warrant?.heat, 6, "A folded report added heat, or the report was not made")
	TEST_ASSERT(WEAKREF(second) in warrant.evidence, "A weapon folded into a pending report was lost")
	TEST_ASSERT(warrant.recent_victims?[WEAKREF(second_victim)], "A victim folded into a pending report was lost")
	police.remove_warrant(warrant)
	police.recent_reports.Cut()

	var/datum/outpost_police_perception/test_victim_sees/picky = new(police)
	qdel(police.perception)
	police.perception = picky
	picky.seen_victim = second_victim
	TEST_ASSERT_NULL(police.report_crime(brawler, "armed", first_victim, first), "An unseen hit counted")
	TEST_ASSERT_NULL(police.warrants[brawler.mind], "An unseen hit made a warrant")
	TEST_ASSERT_EQUAL(police.report_crime(brawler, "armed", second_victim, first), 0, "A seen hit on someone else just after an unseen one was dropped")
	TEST_ASSERT_EQUAL(police.warrants[brawler.mind]?.heat, 9, "A seen hit after an unseen one put the wrong heat on")
	picky.seen_victim = null

/**
 * Inside the half second: a graver witnessed crime (a bullet hitting a visitor or officer right after gunfire) upgrades
 * the warrant from the pre-window baseline instead of being swallowed by the weaker first report, while same-crime
 * pellets still fold without double-counting and an unseen impact never upgrades.
 */
/datum/unit_test/voidcrew_outpost_police_grace_upgrade

/datum/unit_test/voidcrew_outpost_police_grace_upgrade/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(3, 3))
	var/mob/living/carbon/human/visitor = wanted_person(wanted_spot(1, 0))
	var/obj/item/crowbar/gun_standin = allocate(/obj/item/crowbar)

	// Gunfire (15 heat, 1 star) followed in the same instant by a seen shot into a visitor (25 heat, 2 stars)
	var/mob/living/carbon/human/shooter = wanted_person(wanted_spot(0, 0))
	TEST_ASSERT_EQUAL(police.report_crime(shooter, "gunfire", null, gun_standin), 1, "Gunfire did not put one star on the shooter")
	TEST_ASSERT_EQUAL(police.report_crime(shooter, "shot", visitor, gun_standin), 2, "A bullet hitting a visitor right after gunfire was swallowed by the grace fold")
	TEST_ASSERT_EQUAL(police.warrants[shooter.mind]?.heat, 25, "Upgrading gunfire to a visitor shot came to [police.warrants[shooter.mind]?.heat] heat, not 25")
	// A second shotgun pellet in the same instant folds without adding another 25 heat
	TEST_ASSERT_NULL(police.report_crime(shooter, "shot", visitor, gun_standin), "A second pellet of the same crime counted again inside the grace")
	TEST_ASSERT_EQUAL(police.warrants[shooter.mind]?.heat, 25, "A second pellet stacked heat inside the grace")

	// Gunfire (15 heat, 1 star) followed in the same instant by hitting an officer (50 heat floor, 3 stars)
	var/mob/living/carbon/human/cop_shooter = wanted_person(wanted_spot(0, 1))
	TEST_ASSERT_EQUAL(police.report_crime(cop_shooter, "gunfire", null, gun_standin), 1, "Gunfire did not put one star on the cop shooter")
	TEST_ASSERT_EQUAL(police.report_crime(cop_shooter, "officer", officer, gun_standin), 3, "A bullet hitting an officer right after gunfire stayed below three stars")
	TEST_ASSERT_EQUAL(police.warrants[cop_shooter.mind]?.heat, 50, "Upgrading gunfire to an officer hit came to [police.warrants[cop_shooter.mind]?.heat] heat, not 50")

	// An unseen impact inside the grace never upgrades a seen crime
	var/datum/outpost_police_perception/test_victim_sees/picky = new(police)
	qdel(police.perception)
	police.perception = picky
	var/mob/living/carbon/human/stray_shooter = wanted_person(wanted_spot(0, 2))
	var/mob/living/carbon/human/seen_target = wanted_person(wanted_spot(1, 2))
	var/mob/living/carbon/human/unseen_target = wanted_person(wanted_spot(2, 2))
	picky.seen_victim = seen_target
	TEST_ASSERT_EQUAL(police.report_crime(stray_shooter, "unarmed", seen_target), 0, "Setup: the seen punch did not count")
	TEST_ASSERT_NULL(police.report_crime(stray_shooter, "shot", unseen_target), "An unseen shot upgraded an earlier report")
	TEST_ASSERT_EQUAL(police.warrants[stray_shooter.mind]?.heat, 6, "An unseen shot changed the warrant's heat")
	picky.seen_victim = null

/// A killing while the first crime is still a pending report (with no warrants at the outpost yet) still counts when confirmed
/datum/unit_test/voidcrew_outpost_police_pending_kill

/datum/unit_test/voidcrew_outpost_police_pending_kill/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_police_perception/test_delayed/slow = new(police)
	qdel(police.perception)
	police.perception = slow

	var/mob/living/carbon/human/killer = wanted_person(wanted_spot(0, 0))
	var/mob/living/carbon/human/victim = wanted_person(wanted_spot(1, 0))
	TEST_ASSERT_EQUAL(length(police.warrants), 0, "Setup: warrants is not empty")
	TEST_ASSERT_NULL(police.report_crime(killer, "shot", victim), "A delayed report counted at once")
	police.on_wanted_death(null, victim, FALSE)
	var/datum/outpost_pending_report/report = police.pending_reports[1]
	report.due = world.time
	police.tick_warrants()
	TEST_ASSERT_EQUAL(police.warrants[killer.mind]?.heat, 85, "A murder before the witness finished reporting was lost when warrants was empty") // 25 + 60
	TEST_ASSERT_EQUAL(police.get_stars(killer.mind), 3, "A confirmed pending murder did not reach three stars")
	police.remove_warrant(police.warrants[killer.mind])
	police.recent_reports.Cut()

	// Killing an officer while the officer assault is still pending counts officers_killed and extends the crew's embargo
	var/mob/living/carbon/human/cop_killer = wanted_person(wanted_spot(0, 1))
	var/obj/structure/overmap/ship/ship = wanted_ship(cop_killer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = wanted_officer(outpost, wanted_spot(2, 1))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/backup = wanted_officer(outpost, wanted_spot(2, 2))
	TEST_ASSERT_NOTNULL(backup, "Setup: no backup officer")
	TEST_ASSERT_NULL(police.report_crime(cop_killer, "officer", officer), "A delayed officer assault counted at once")
	police.on_wanted_death(null, officer, FALSE)
	var/datum/outpost_pending_report/cop_report = police.pending_reports[1]
	cop_report.due = world.time
	police.tick_warrants()
	var/datum/outpost_warrant/cop_warrant = police.warrants[cop_killer.mind]
	TEST_ASSERT_EQUAL(cop_warrant?.heat, 95, "A pending officer kill did not come to 95 heat") // 50 + 45
	TEST_ASSERT_EQUAL(cop_warrant?.officers_killed, 1, "A pending officer kill did not increment officers_killed")
	TEST_ASSERT_EQUAL(outpost.embargoed_ships[ship], world.time + 20 MINUTES, "A pending officer kill did not add 5 minutes to the 15-minute embargo")
	wanted_cleanup(list(ship))

/// A new ship acquired by an embargoed crew during an active incident is embargoed on the next tick, and wanted HUD alerts follow mind transfers
/datum/unit_test/voidcrew_outpost_police_incident_ship_and_hud

/datum/unit_test/voidcrew_outpost_police_incident_ship_and_hud/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/leader = wanted_person(wanted_spot(0, 0))
	var/obj/structure/overmap/ship/first_ship = wanted_ship(leader)
	var/datum/voidcrew_crew_record/crew = leader.mind.get_reputation_crew()
	police.admin_set_stars(leader.mind, 4)
	TEST_ASSERT(outpost.is_ship_embargoed(first_ship), "Four stars did not embargo the first ship")
	var/obj/structure/overmap/ship/second_ship = wanted_ship(null, 0, crew)
	TEST_ASSERT(!outpost.is_ship_embargoed(second_ship), "Setup: the newly joined ship started embargoed")
	police.tick_warrants()
	TEST_ASSERT(outpost.is_ship_embargoed(second_ship), "A ship acquired during an active incident escaped the embargo")
	// An admin's lift on one ship sticks: the incident does not put it back
	outpost.embargoed_ships -= second_ship
	police.tick_warrants()
	TEST_ASSERT(!outpost.is_ship_embargoed(second_ship), "A lifted embargo came back on the next tick")

	// HUD alert follows a mind transfer immediately and clears from the old body
	TEST_ASSERT_NOTNULL(leader.alerts["outpost_wanted"], "Four stars threw no wanted alert on the leader")
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent, wanted_spot(1, 0))
	leader.mind.transfer_to(new_body)
	TEST_ASSERT_NULL(leader.alerts["outpost_wanted"], "The old body kept the wanted alert after mind transfer")
	TEST_ASSERT_NOTNULL(new_body.alerts["outpost_wanted"], "The new body did not receive the wanted alert on mind transfer")

	// Deleting a wanted mind drops its warrant cleanly
	var/mob/living/carbon/human/temp = allocate(/mob/living/carbon/human/consistent, wanted_spot(2, 0))
	temp.mind_initialize()
	var/datum/mind/temp_mind = temp.mind
	police.admin_set_stars(temp_mind, 2)
	TEST_ASSERT_NOTNULL(police.warrants[temp_mind], "Setup: temp mind has no warrant")
	qdel(temp_mind)
	TEST_ASSERT_EQUAL(length(police.warrants), 1, "Deleting a mind left its warrant behind")
	wanted_cleanup(list(first_ship, second_ship))

/// Abuse SF3: a player mind in an officer's body is treated as a visitor (self-defence, murder, arrest interference, faction), and killing an officer never revives an expired ship embargo
/datum/unit_test/voidcrew_outpost_police_transplanted_officer_and_expired_embargo

/datum/unit_test/voidcrew_outpost_police_transplanted_officer_and_expired_embargo/Run()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/outpost_police/police = outpost.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/real_officer = wanted_officer(outpost, wanted_spot(4, 4))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/transplanted = wanted_officer(outpost, wanted_spot(1, 0))
	var/mob/living/carbon/human/donor = wanted_person(wanted_spot(0, 4))
	donor.mind.transfer_to(transplanted)

	TEST_ASSERT(!(transplanted in police.officers), "A mind transferred into an officer's body stayed on the police roster")
	TEST_ASSERT(!police.perception.is_officer(transplanted), "Perception still treated a player in an officer's body as an NPC officer")
	TEST_ASSERT(!real_officer.faction_check_atom(transplanted), "An NPC officer treated a player in an officer's body as faction-allied")

	// Provoked self-defence against a player in an officer's body does not trigger ASSAULT_OFFICER
	var/mob/living/carbon/human/defender = wanted_person(wanted_spot(1, 1))
	outpost.register_pvp_aggression(defender, transplanted, "unarmed")
	SEND_SIGNAL(transplanted, COMSIG_ATOM_WAS_ATTACKED, defender, ATTACKER_STAMINA_ATTACK)
	SEND_SIGNAL(transplanted, COMSIG_CARBON_CUFF_ATTEMPTED, defender)
	outpost.register_pvp_aggression(transplanted, defender, "unarmed")
	TEST_ASSERT_NULL(police.warrants[defender.mind], "Defending against a player in an officer's body raised an officer-assault warrant")

	// Murdering a player in an officer's body is witnessed by them and counts as MURDER (+60), not dropped as a foreign officer
	var/mob/living/carbon/human/murderer = wanted_person(wanted_spot(2, 0))
	TEST_ASSERT_EQUAL(police.report_crime(murderer, "shot", transplanted), 2, "A player in an officer's body did not witness being shot")
	transplanted.death()
	TEST_ASSERT_EQUAL(police.warrants[murderer.mind]?.heat, 85, "Killing a player in an officer's body did not count as murder") // 25 + 60
	TEST_ASSERT_EQUAL(police.warrants[murderer.mind]?.officers_killed, 0, "Killing a player in an officer's body counted as killing a police officer")

	// A player in an officer's body pulling a cuffed prisoner away from an arrest is charged RESIST
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/meddler = wanted_officer(outpost, wanted_spot(2, 2))
	var/mob/living/carbon/human/second_donor = wanted_person(wanted_spot(0, 5))
	second_donor.mind.transfer_to(meddler)
	var/mob/living/carbon/human/suspect = wanted_person(wanted_spot(2, 3))
	var/datum/outpost_warrant/suspect_warrant = police_pin_warrant(police, suspect.mind, 15)
	var/datum/outpost_police_case/case = new(police, suspect_warrant)
	police.cases[suspect.mind] = case
	case.cuffed = TRUE
	suspect.pulledby = meddler
	case.check_interference(suspect)
	suspect.pulledby = null
	police.close_case(suspect.mind)
	TEST_ASSERT_EQUAL(police.warrants[meddler.mind]?.heat, 8, "A player in an officer's body interfering with an arrest was excused") // OUTPOST_CRIME_RESIST

	// officer_killed_by() extends active embargoes without reviving an already-expired custom ship embargo
	var/mob/living/carbon/human/leader = wanted_person(wanted_spot(3, 0))
	var/obj/structure/overmap/ship/active_ship = wanted_ship(leader)
	var/datum/voidcrew_crew_record/crew = leader.mind.get_reputation_crew()
	var/obj/structure/overmap/ship/expired_ship = wanted_ship(null, 0, crew)
	var/datum/outpost_warrant/leader_warrant = police_pin_warrant(police, leader.mind, 100) // four stars
	leader_warrant.crew = crew
	police.tick_warrants()
	outpost.embargoed_ships[expired_ship] = world.time - 1 // lapsed custom embargo not yet lazily pruned
	police.officer_killed_by(leader_warrant)
	TEST_ASSERT_EQUAL(outpost.embargoed_ships[active_ship], world.time + 20 MINUTES, "Killing an officer did not extend the active ship embargo")
	TEST_ASSERT(!outpost.is_ship_embargoed(expired_ship), "Killing an officer resurrected an already-expired ship embargo")
	wanted_cleanup(list(active_ship, expired_ship))
