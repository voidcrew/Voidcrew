/**
 * Outpost jobs tests: sabotage (voidcrew/modules/outpost_jobs/job_sabotage.dm). Owner: P3.
 * Helpers are in voidcrew_outpost_jobs_helpers.dm. Fork defines are included after the tests: use literal values
 * with a comment naming the define.
 *
 * The test room is 5 by 5 (offsets 0 to 4). The tests put the set on tiles by hand (build_targets()) and call the
 * part of each action after its wait (advance_tamper()), so none depends on the spot finder, the ship or an AI walk.
 * The ones that read who is on the roster (an outsider's ruin spoils) are written for P2's on_roster(), which reads
 * the job's `roster`; against P0's stub it answers FALSE for everyone.
 */

/// Every sabotage test: metrics off while jobs are made, and the helpers they share
/datum/unit_test/voidcrew_outpost_jobs_sabotage
	abstract_type = /datum/unit_test/voidcrew_outpost_jobs_sabotage
	var/old_accepting

/datum/unit_test/voidcrew_outpost_jobs_sabotage/New()
	. = ..()
	old_accepting = SSmetrics.accepting
	SSmetrics.accepting = FALSE

/datum/unit_test/voidcrew_outpost_jobs_sabotage/Destroy()
	SSmetrics.accepting = old_accepting
	return ..()

/// A sabotage job at `outpost` of `set_kind` ("crates", "kiosk" or "rack": SABOTAGE_SET_*) with its set on `spots`
/datum/unit_test/voidcrew_outpost_jobs_sabotage/proc/sabotage_job(obj/structure/overmap/trader_outpost/outpost, set_kind, list/turf/spots)
	var/datum/mission/fixer_job/sabotage/job = allocate(/datum/mission/fixer_job/sabotage)
	job.job_outpost = outpost
	job.set_kind = set_kind
	job.build_targets(spots)
	return job

/// Three tiles in a row on the room's second row
/datum/unit_test/voidcrew_outpost_jobs_sabotage/proc/crate_spots()
	return list(jobs_spot(0, 2), jobs_spot(1, 2), jobs_spot(2, 2))

/// A tool of `tool_type` made for the test
/datum/unit_test/voidcrew_outpost_jobs_sabotage/proc/tool(tool_type)
	return allocate(tool_type)

/// Enough damage ruins a target, which is wrecked where it stands, never deleted, and takes no more harm
/datum/unit_test/voidcrew_outpost_jobs_sabotage/damage

/datum/unit_test/voidcrew_outpost_jobs_sabotage/damage/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/person = jobs_person(jobs_spot(0, 0))
	var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, "crates", crate_spots()) // SABOTAGE_SET_CRATES
	var/obj/structure/fixer_target/crate = job.live_target_at(1)
	TEST_ASSERT_NOTNULL(crate, "The job did not put its crates down")
	TEST_ASSERT_EQUAL(crate.max_integrity, 150, "A target's integrity is not FIXER_TARGET_INTEGRITY") // FIXER_TARGET_INTEGRITY

	crate.take_damage(30, BRUTE, MELEE)
	TEST_ASSERT(!crate.ruined, "A little damage ruined a crate")
	TEST_ASSERT_EQUAL(crate.get_integrity(), 120, "30 damage did not leave a 150 crate at 120")

	var/obj/item/crowbar/swung = tool(/obj/item/crowbar)
	swung.force = 500
	crate.attacked_by(swung, person)
	TEST_ASSERT(crate.ruined, "A blow that overcame its integrity did not ruin the crate")
	TEST_ASSERT(!QDELETED(crate), "A ruined crate was deleted instead of wrecked")
	TEST_ASSERT(crate.get_integrity() > 0, "A ruined crate is left at no integrity, so the next blow would crash")
	TEST_ASSERT_EQUAL(crate.icon_state, "crateopen", "A ruined crate is not shown with its lid off")
	TEST_ASSERT(crate.density && crate.anchored, "A ruined crate is no longer in the way")
	crate.take_damage(50, BRUTE, MELEE)
	TEST_ASSERT(!QDELETED(crate) && crate.ruined, "A blow on a wreck undid it")
	TEST_ASSERT(!job.deed_done, "One crate of three ruined was the deed")

/// A damaging blow, and each tamper step, is a sabotage crime with the target as its victim
/datum/unit_test/voidcrew_outpost_jobs_sabotage/report

/datum/unit_test/voidcrew_outpost_jobs_sabotage/report/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/outpost_police/police = outpost.police
	var/datum/jobs_test_listener/listener = allocate(/datum/jobs_test_listener)
	listener.listen(police, "outpost_police_crime") // COMSIG_OUTPOST_POLICE_CRIME
	var/mob/living/carbon/human/basher = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/tamperer = jobs_person(jobs_spot(1, 0))
	var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, "crates", crate_spots()) // SABOTAGE_SET_CRATES
	var/obj/structure/fixer_target/hit_crate = job.live_target_at(1)
	var/obj/structure/fixer_target/prised_crate = job.live_target_at(2)

	var/obj/item/crowbar/swung = tool(/obj/item/crowbar)
	hit_crate.attacked_by(swung, basher)
	TEST_ASSERT_EQUAL(length(listener.heard), 1, "A blow on a crate was [length(listener.heard)] counted crimes, not one")
	var/list/first = listener.last()
	TEST_ASSERT_EQUAL(first[1], basher.mind, "The crime was not the basher's")
	TEST_ASSERT_EQUAL(first[2], "sabotage", "A blow on a crate was not the sabotage crime") // OUTPOST_CRIME_SABOTAGE
	TEST_ASSERT_EQUAL(first[3], hit_crate, "The crime did not name the crate as its victim")
	TEST_ASSERT_EQUAL(first[4], 1, "One seen blow on a crate was not one star") // 12 heat, floor and ceiling of 1 and 2

	// A tamper step is the same crime
	TEST_ASSERT(prised_crate.advance_tamper(tamperer, tool(/obj/item/crowbar)), "The crowbar was not the crate's tamper tool")
	TEST_ASSERT_EQUAL(length(listener.heard), 2, "Prising a crate open was not a counted crime")
	var/list/second = listener.last()
	TEST_ASSERT_EQUAL(second[1], tamperer.mind, "The tamper crime was not the tamperer's")
	TEST_ASSERT_EQUAL(second[3], prised_crate, "The tamper crime did not name the crate as its victim")
	TEST_ASSERT(prised_crate.ruined, "Prising the lid did not ruin the crate")

	// Nobody saw: nothing is counted, and the crate is ruined all the same
	var/mob/living/carbon/human/sneak = jobs_person(jobs_spot(2, 0))
	jobs_witness(outpost).seen = FALSE
	var/obj/structure/fixer_target/quiet_crate = job.live_target_at(3)
	TEST_ASSERT(quiet_crate.advance_tamper(sneak, tool(/obj/item/crowbar)), "The crowbar was not the crate's tamper tool the third time")
	TEST_ASSERT_EQUAL(length(listener.heard), 2, "An unseen tamper was counted")
	TEST_ASSERT(quiet_crate.ruined, "An unseen tamper did not ruin the crate")

/// Each target takes its own tool or tools, in order; a wrong tool does nothing
/datum/unit_test/voidcrew_outpost_jobs_sabotage/tamper

/datum/unit_test/voidcrew_outpost_jobs_sabotage/tamper/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/person = jobs_person(jobs_spot(0, 0))
	var/datum/mission/fixer_job/sabotage/crates = sabotage_job(outpost, "crates", crate_spots()) // SABOTAGE_SET_CRATES
	var/datum/mission/fixer_job/sabotage/kiosk_job = sabotage_job(outpost, "kiosk", list(jobs_spot(4, 3))) // SABOTAGE_SET_KIOSK
	var/datum/mission/fixer_job/sabotage/rack_job = sabotage_job(outpost, "rack", list(jobs_spot(4, 1))) // SABOTAGE_SET_RACK
	var/obj/structure/fixer_target/crate = crates.live_target_at(1)
	var/obj/structure/fixer_target/kiosk = kiosk_job.live_target_at(1)
	var/obj/structure/fixer_target/rack = rack_job.live_target_at(1)
	TEST_ASSERT(istype(kiosk, /obj/structure/fixer_target/kiosk) && istype(rack, /obj/structure/fixer_target/rack), "The sets did not make their own targets")

	// The crate: a crowbar, 8 seconds
	var/obj/item/crowbar/pry_bar = tool(/obj/item/crowbar)
	TEST_ASSERT_EQUAL(crate.step_time(pry_bar), 80, "Prising a crate is not 8 seconds") // FIXER_TAMPER_CRATE
	TEST_ASSERT(!crate.advance_tamper(person, tool(/obj/item/wrench)), "A wrench worked on a crate")
	TEST_ASSERT(!crate.ruined, "A wrench ruined a crate")
	TEST_ASSERT(crate.advance_tamper(person, pry_bar), "A crowbar did not work on a crate")
	TEST_ASSERT(crate.ruined, "A crowbar did not ruin a crate")
	TEST_ASSERT(!crate.advance_tamper(person, pry_bar), "A crowbar worked on a wrecked crate")

	// The drinks machine: a screwdriver, then wirecutters, 6 seconds each
	var/obj/item/screwdriver/driver = tool(/obj/item/screwdriver)
	var/obj/item/wirecutters/cutters = tool(/obj/item/wirecutters)
	TEST_ASSERT_EQUAL(kiosk.step_time(driver), 60, "The drinks machine's panel is not 6 seconds") // FIXER_TAMPER_KIOSK
	TEST_ASSERT_EQUAL(kiosk.step_time(cutters), 0, "Wirecutters were the drinks machine's first step")
	TEST_ASSERT(!kiosk.advance_tamper(person, cutters), "Wirecutters worked before the panel was open")
	TEST_ASSERT(kiosk.advance_tamper(person, driver), "A screwdriver did not open the drinks machine's panel")
	TEST_ASSERT(!kiosk.ruined, "The drinks machine was ruined by its first step")
	TEST_ASSERT(!kiosk.advance_tamper(person, driver), "A screwdriver did the second step")
	TEST_ASSERT_EQUAL(kiosk.step_time(cutters), 60, "The drinks machine's wires are not 6 seconds") // FIXER_TAMPER_KIOSK
	TEST_ASSERT(kiosk.advance_tamper(person, cutters), "Wirecutters did not finish the drinks machine")
	TEST_ASSERT(kiosk.ruined, "The drinks machine was not ruined after both steps")
	TEST_ASSERT_EQUAL(kiosk.icon_state, "soda-broken", "A ruined drinks machine is not shown broken")
	TEST_ASSERT(kiosk_job.deed_done, "A job of one ruined target is not done")

	// The drive rack: a multitool, 12 seconds
	var/obj/item/multitool/probe = tool(/obj/item/multitool)
	TEST_ASSERT_EQUAL(rack.step_time(probe), 120, "Probing the rack is not 12 seconds") // FIXER_TAMPER_RACK
	TEST_ASSERT(!rack.advance_tamper(person, driver), "A screwdriver worked on the rack")
	TEST_ASSERT(rack.advance_tamper(person, probe), "A multitool did not work on the rack")
	TEST_ASSERT(rack.ruined, "A multitool did not ruin the rack")
	TEST_ASSERT_EQUAL(rack.icon_state, "server-nopower", "A ruined rack is not shown dead")
	TEST_ASSERT(rack_job.deed_done, "A job of one ruined target is not done")

/// An outsider's ruin spoils the job; a roster member's does not
/datum/unit_test/voidcrew_outpost_jobs_sabotage/spoil

/datum/unit_test/voidcrew_outpost_jobs_sabotage/spoil/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/insider = jobs_person(jobs_spot(0, 0))
	var/mob/living/carbon/human/outsider = jobs_person(jobs_spot(1, 0))
	var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, "crates", crate_spots()) // SABOTAGE_SET_CRATES
	job.roster = list(WEAKREF(insider.mind))
	var/obj/structure/fixer_target/first = job.live_target_at(1)
	var/obj/structure/fixer_target/second = job.live_target_at(2)

	TEST_ASSERT(first.advance_tamper(insider, tool(/obj/item/crowbar)), "The crowbar did not work on the first crate")
	TEST_ASSERT(first.ruined, "The first crate was not ruined")
	TEST_ASSERT_NULL(job.fail_reason, "A roster member ruining a crate spoiled the job")
	TEST_ASSERT(!job.deed_done, "One crate of three was the deed")

	TEST_ASSERT(second.advance_tamper(outsider, tool(/obj/item/crowbar)), "The crowbar did not work on the second crate")
	TEST_ASSERT(second.ruined, "The second crate was not ruined")
	TEST_ASSERT_EQUAL(job.fail_reason, "spoiled", "An outsider's ruin did not spoil the job") // FIXER_FAIL_SPOILED
	TEST_ASSERT(!job.deed_done, "An outsider's ruin was the crew's deed")

	// What was ruined stays a wreck, and everything let go is carted off once nobody is looking
	TEST_ASSERT(first.released && second.released, "The wrecks were not let go when the job ended")
	for(var/obj/structure/fixer_target/target as anything in list(first, second))
		target.cart_off()
		TEST_ASSERT(QDELETED(target), "A wreck nobody is watching was not carted off")

/// The last target ruined, by a hand that is not a player or is on the roster, is the deed
/datum/unit_test/voidcrew_outpost_jobs_sabotage/deed

/datum/unit_test/voidcrew_outpost_jobs_sabotage/deed/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, "crates", crate_spots()) // SABOTAGE_SET_CRATES
	TEST_ASSERT_EQUAL(length(job.targets), 3, "The consignment is not three crates") // SABOTAGE_CRATE_COUNT
	var/list/crates = list()
	for(var/index in 1 to 3)
		crates += job.live_target_at(index)
	// No player's hand (an explosion, a fall): counts as the crew's
	var/obj/structure/fixer_target/first = crates[1]
	first.take_damage(INFINITY, BRUTE, BOMB, 0)
	TEST_ASSERT(first.ruined, "A blast did not ruin a crate")
	var/obj/structure/fixer_target/second = crates[2]
	second.ruin()
	TEST_ASSERT(!job.deed_done, "Two crates of three were the deed")
	var/obj/structure/fixer_target/third = crates[3]
	third.ruin()
	TEST_ASSERT(job.deed_done, "Every crate ruined was not the deed")
	TEST_ASSERT_NULL(job.fail_reason, "A deed with no player's hand failed the job")

/// A target cannot be pulled, pushed or unfastened
/datum/unit_test/voidcrew_outpost_jobs_sabotage/fixed

/datum/unit_test/voidcrew_outpost_jobs_sabotage/fixed/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/mob/living/carbon/human/person = jobs_person(jobs_spot(1, 3))
	var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, "kiosk", list(jobs_spot(1, 4))) // SABOTAGE_SET_KIOSK
	var/obj/structure/fixer_target/kiosk = job.live_target_at(1)
	TEST_ASSERT(kiosk.anchored, "A target is not anchored")
	TEST_ASSERT_EQUAL(kiosk.move_resist, INFINITY, "A target can be shoved")
	TEST_ASSERT(!kiosk.can_be_pulled(person, MOVE_FORCE_STRONG), "A target can be pulled")
	person.start_pulling(kiosk)
	TEST_ASSERT(person.pulling != kiosk, "Someone got a grip on a target")
	kiosk.wrench_act(person, tool(/obj/item/wrench))
	TEST_ASSERT(kiosk.anchored, "A wrench unfastened a target")
	// Wrecked, it stays where it is as well
	kiosk.ruin()
	TEST_ASSERT(kiosk.anchored && !kiosk.can_be_pulled(person, MOVE_FORCE_STRONG), "A wreck can be dragged off")

/// A wrecked drinks machine drops no more than four cans
/datum/unit_test/voidcrew_outpost_jobs_sabotage/cans

/datum/unit_test/voidcrew_outpost_jobs_sabotage/cans/Run()
	var/turf/spot = jobs_spot(2, 2)
	for(var/attempt in 1 to 15)
		var/obj/structure/fixer_target/kiosk/machine = new(spot)
		machine.ruin()
		var/cans = 0
		for(var/obj/item/reagent_containers/cup/soda_cans/can in range(1, spot))
			cans++
			qdel(can)
		TEST_ASSERT(cans <= 4, "A wrecked drinks machine dropped [cans] cans") // FIXER_KIOSK_CANS
		TEST_ASSERT(cans >= 1, "A wrecked drinks machine dropped no cans")
		qdel(machine)

/// The keepers: each look is made with the job, works the set, reacts to a wreck, and goes with the job
/datum/unit_test/voidcrew_outpost_jobs_sabotage/keeper

/datum/unit_test/voidcrew_outpost_jobs_sabotage/keeper/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	var/list/sets = list("crates", "kiosk", "rack") // SABOTAGE_SET_CRATES, _KIOSK, _RACK
	var/list/keeper_types = list(
		/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/dock_hand,
		/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/fitter,
		/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/courier,
	)
	for(var/index in 1 to length(sets))
		var/list/turf/spots = sets[index] == "crates" ? crate_spots() : list(jobs_spot(2, 2)) // SABOTAGE_SET_CRATES
		var/datum/mission/fixer_job/sabotage/job = allocate(/datum/mission/fixer_job/sabotage)
		job.job_outpost = outpost
		job.set_kind = sets[index]
		TEST_ASSERT(job.build_targets(spots), "The [sets[index]] set was not put down")
		TEST_ASSERT(job.build_keeper(spots), "The [sets[index]] set's keeper was not made")
		var/mob/living/carbon/human/npc/ambient_npc/outpost/job_keeper/keeper = job.keeper_ref?.resolve()
		TEST_ASSERT_NOTNULL(keeper, "The [sets[index]] set has no keeper")
		TEST_ASSERT_EQUAL(keeper.type, keeper_types[index], "The [sets[index]] set has the wrong keeper")
		TEST_ASSERT_EQUAL(keeper.stat, CONSCIOUS, "The keeper is not on his feet")
		TEST_ASSERT_EQUAL(length(keeper.live_targets()), length(job.targets), "The keeper does not mind every target")
		TEST_ASSERT(length(keeper.get_lines("wreck")), "The [sets[index]] keeper has nothing to say at a wreck")
		TEST_ASSERT(length(keeper.get_lines("work")), "The [sets[index]] keeper has nothing to say at work")
		TEST_ASSERT(length(keeper.get_lines("break")), "The [sets[index]] keeper has nothing to say on a break")
		TEST_ASSERT(keeper.pick_activity(), "The keeper could not set himself to anything")
		keeper.end_activity()

		// A wreck: the dock hand and the courier go to an officer, the fitter packs up and goes
		var/obj/structure/fixer_target/first = job.live_target_at(1)
		first.ruin()
		TEST_ASSERT(first.ruined, "A target was not ruined")
		if(keeper.packs_up_on_wreck)
			TEST_ASSERT(istype(keeper.activity, /datum/ambient_activity/leave), "The fitter did not pack up at a wreck")
		else
			TEST_ASSERT(istype(keeper.activity, /datum/ambient_activity/job_wreck), "The keeper did not go for an officer at a wreck")
		keeper.end_activity()

		// The job ends: the keeper goes, every target is let go and is carted off once nobody is looking
		job.unstage()
		TEST_ASSERT(keeper.fading || istype(keeper.activity, /datum/ambient_activity/leave), "The keeper stayed after the job ended")
		for(var/datum/weakref/ref as anything in job.targets)
			var/obj/structure/fixer_target/target = ref.resolve()
			if(QDELETED(target))
				continue
			TEST_ASSERT(target.released, "A target was not let go when the job ended")
			target.cart_off()
			TEST_ASSERT(QDELETED(target), "A target nobody is watching was not carted off")
		qdel(keeper)

/// The offer's tokens and the note stay within their bounds, for every set, and say what the job is
/datum/unit_test/voidcrew_outpost_jobs_sabotage/text

/datum/unit_test/voidcrew_outpost_jobs_sabotage/text/Run()
	var/obj/structure/overmap/trader_outpost/outpost = jobs_outpost()
	outpost.name = "A very long outpost name that goes on and on past any bound"
	var/datum/mission/fixer_job/sabotage/probe = allocate(/datum/mission/fixer_job/sabotage)
	TEST_ASSERT(probe.allowed_at(outpost, null), "Sabotage is not allowed at an outpost")
	for(var/set_kind in list("crates", "kiosk", "rack")) // SABOTAGE_SET_CRATES, _KIOSK, _RACK
		var/datum/mission/fixer_job/sabotage/job = sabotage_job(outpost, set_kind, set_kind == "crates" ? crate_spots() : list(jobs_spot(2, 2))) // SABOTAGE_SET_CRATES
		var/list/tokens = job.offer_tokens()
		for(var/token in list("{name}", "{look}", "{clock}", "{place}")) // FIXER_TOKEN_*
			TEST_ASSERT(istext(tokens[token]) && length(tokens[token]), "The [set_kind] offer has no [token]")
		TEST_ASSERT(length_char(tokens["{name}"]) <= 28, "The [set_kind] offer's name is over its bound") // FIXER_BOUND_NAME
		TEST_ASSERT(length_char(tokens["{look}"]) <= 32, "The [set_kind] offer's look is over its bound") // FIXER_BOUND_LOOK
		TEST_ASSERT(length_char(tokens["{place}"]) <= 24, "The [set_kind] offer's place is over its bound") // FIXER_BOUND_PLACE
		var/list/lines = job.note_lines()
		TEST_ASSERT(length(lines) >= 1 && length(lines) <= 3, "The [set_kind] note is [length(lines)] lines") // FIXER_NOTE_LINES
		for(var/line in lines)
			TEST_ASSERT(length_char(line) <= 64, "A [set_kind] note line is over its bound: [line]") // FIXER_BOUND_NOTE_LINE

/// The keepers' strings: every section has every moment, at least two lines each, within the bound and clear of the banned words
/datum/unit_test/voidcrew_outpost_jobs_sabotage/strings

/datum/unit_test/voidcrew_outpost_jobs_sabotage/strings/Run()
	var/list/data = json_decode(file2text("voidcrew/modules/outpost_jobs/strings/job_sabotage.json")) // FIXER_STRINGS_DIR, FIXER_STRINGS_SABOTAGE
	TEST_ASSERT(islist(data), "job_sabotage.json is not a list")
	var/list/banned = list("bonus", "clean", "stars", "witness", "noise", "grade", "tier", "trust", "cooldown", "mission")
	var/list/moments = list("idle", "talk", "work", "attacked", "violence", "wreck", "officer", "break", "back", "collect", "leave", "cover")
	for(var/who in list("dock_hand", "fitter", "courier"))
		var/list/section = data[who]
		TEST_ASSERT(islist(section), "job_sabotage.json has no [who]")
		for(var/moment in moments)
			var/list/lines = section[moment]
			TEST_ASSERT(islist(lines) && length(lines) >= 2, "[who] has fewer than two lines for [moment]")
			for(var/line in lines)
				TEST_ASSERT(istext(line) && length_char(line) <= 140, "A [who] [moment] line is over 140 characters: [line]") // FIXER_BOUND_LINE
				for(var/word in banned)
					TEST_ASSERT(!findtext(lowertext(line), word), "A [who] [moment] line has the banned word [word]: [line]")
	// The loader the keepers use puts the file where the dialogue code reads it
	job_sabotage_strings()
	TEST_ASSERT("job_sabotage.json" in GLOB.string_cache, "job_sabotage_strings() did not load the file") // FIXER_STRINGS_SABOTAGE
