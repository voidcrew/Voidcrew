/**
 * Wildcard incidents and wing events: the chance and the clock that rolls it, what holds the clock,
 * who a stabbing picks, each kind from the admin panel, a stabbing stopped in its tell, a lone snap
 * in a happy wing, blown lights, an overflowing scrubber (or a backed-up Kessler vent) and an
 * overflowing toilet.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Prisons are driven with the procs tick() calls, with their own
 * processing stopped; the rolls are forced through wildcard_force_roll and wing_event_force_kind.
 * The prison fixture turns wildcards and wing events off, so each test turns on what it tests.
 * Fixtures are in voidcrew_outpost_prison_helpers.dm and voidcrew_outpost_prison_trouble.dm.
 */

/// Whether any kind of wildcard is under way: a tell, a fight or a riot
/datum/unit_test/voidcrew_outpost_management/proc/wildcard_started(datum/outpost_prison/prison)
	return !!prison.wildcard || length(prison.fights) || prison.riot_active

/// Ends whatever a wildcard started, and the quiet after it
/datum/unit_test/voidcrew_outpost_management/proc/wildcard_reset(datum/outpost_prison/prison)
	prison.wildcard_destroy()
	prison.admin_calm()
	prison.set_subdued(0)

/// How many lights in the wing work
/datum/unit_test/voidcrew_outpost_management/proc/working_lights(datum/outpost_prison/prison)
	var/count = 0
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		if(fixture.status == LIGHT_OK)
			count++
	return count

/// Takes every piece of mess off the wing's floor
/datum/unit_test/voidcrew_outpost_management/proc/clear_wing_mess(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.wing_turfs())
		for(var/obj/effect/decal/cleanable/mess in tile)
			qdel(mess)
		for(var/obj/item/litter in tile)
			if(istype(litter, /obj/item/trash) || istype(litter, /obj/item/cigbutt) || istype(litter, /obj/item/shard))
				qdel(litter)

/// Whether one of the warden log's last few lines mentions `text`
/datum/unit_test/voidcrew_outpost_management/proc/wildcard_logged(datum/outpost_prison/prison, text)
	for(var/index in 1 to min(3, length(prison.entries)))
		var/list/entry = prison.entries[index]
		if(findtext(entry["text"], text))
			return TRUE
	return FALSE

// ===== THE CHANCE AND THE CLOCK =====

/datum/unit_test/voidcrew_outpost_prison_wildcard_clock
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_wildcard_clock/Run()
	// Above nothing in a perfect wing, flat to tension 20, higher at 50, capped at 30.
	var/calm = outpost_prison_wildcard_chance(0)
	TEST_ASSERT(calm > 0, "A perfect wing has no chance of an incident")
	TEST_ASSERT_EQUAL(outpost_prison_wildcard_chance(20), calm, "Tension 20 changed the calm chance") // PRISON_INCIDENT_CALM_TENSION
	TEST_ASSERT(outpost_prison_wildcard_chance(50) > calm, "Tension 50 is no likelier than a perfect wing")
	TEST_ASSERT(abs(outpost_prison_wildcard_chance(50) - 20) < 0.01, "Tension 50 has a chance of [outpost_prison_wildcard_chance(50)], not 20") // PRISON_INCIDENT_CHANCE_TENSE
	TEST_ASSERT(outpost_prison_wildcard_chance(100) <= 30, "Tension 100 has a chance over the cap") // PRISON_INCIDENT_CHANCE_MAX

	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("wildclockowner")
	TEST_ASSERT_NOTNULL(home, "The incident clock test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.wildcards_enabled = TRUE
	prison.wildcard_force_roll = TRUE
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	set_moods(list(first, second), 90)
	prison.refresh_reach()

	// A new wing starts with the gap (PRISON_INCIDENT_GAP), and the gap only counts down with the crew home.
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 600, "A new wing starts [prison.wildcard_gap_left] s from its first incident")
	prison.crew_home_override = FALSE
	prison.wildcard_tick(600)
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 600, "The gap ran down with nobody home")
	prison.crew_home_override = TRUE
	prison.wildcard_tick(300)
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 300, "Five minutes home left the gap at [prison.wildcard_gap_left]")
	TEST_ASSERT(!wildcard_started(prison), "An incident started inside the gap")
	prison.wildcard_gap_left = 0

	// Nobody home, a riot, the quiet after a riot, one prisoner, trouble off: no rolls. An experiment
	// holds nothing (owner, 2026-09-25): a roll that comes up during one starts an incident.
	prison.crew_home_override = FALSE
	prison.wildcard_tick(300)
	TEST_ASSERT(!wildcard_started(prison), "An incident started with nobody home")
	prison.crew_home_override = TRUE
	prison.riot_active = TRUE
	prison.wildcard_tick(300)
	prison.riot_active = FALSE
	TEST_ASSERT(!wildcard_started(prison), "An incident started during a riot")
	var/datum/outpost_experiment/trial = allocate(/datum/outpost_experiment, prison, "hulk", null)
	prison.experiment = trial
	TEST_ASSERT(prison.experiment_active(), "The test experiment is not under way")
	TEST_ASSERT_NULL(prison.wildcard_clock_paused(), "The incident clock waits for an experiment ([prison.wildcard_clock_paused()])")
	prison.wildcard_tick(60) // PRISON_INCIDENT_ROLL_TIME
	prison.experiment = null
	TEST_ASSERT(wildcard_started(prison), "No incident started during an experiment")
	wildcard_reset(prison)
	set_moods(list(first, second), 90)
	prison.wildcard_gap_left = 0
	prison.set_subdued(360)
	prison.wildcard_tick(300)
	prison.set_subdued(0)
	TEST_ASSERT(!wildcard_started(prison), "An incident started in the quiet after a riot")
	var/turf/second_spot = get_turf(second)
	var/turf/outside = prison.outside_spot_near(second)
	TEST_ASSERT_NOTNULL(outside, "Nowhere outside the cell block to put the second prisoner")
	second.forceMove(outside)
	prison.wildcard_tick(300)
	second.forceMove(second_spot)
	TEST_ASSERT(!wildcard_started(prison), "An incident started with one prisoner in the cell block") // PRISON_INCIDENT_MIN_PRISONERS
	prison.trouble_enabled = FALSE
	prison.wildcard_tick(300)
	prison.trouble_enabled = TRUE
	TEST_ASSERT(!wildcard_started(prison), "An incident started with trouble off")
	prison.wildcard_force_roll = FALSE
	prison.wildcard_tick(600)
	TEST_ASSERT(!wildcard_started(prison), "A failed roll started an incident")
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 0, "Failed rolls started the gap")

	// With everything clear, a roll that comes up starts one within the minute, and the gap again.
	prison.wildcard_force_roll = TRUE
	prison.wildcard_tick(60) // PRISON_INCIDENT_ROLL_TIME
	TEST_ASSERT(wildcard_started(prison), "A roll that came up with the crew home started nothing")
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 600, "An incident did not start the gap") // PRISON_INCIDENT_GAP
	wildcard_reset(prison)

	// Rivals are picked first, and a shiv under the mattress makes its owner likelier to be the one.
	var/mob/living/basic/outpost_prisoner/third = trouble_prisoner(prison, prison_spot(home, 11, 8))
	prison.refresh_reach()
	prison.set_affinity(first, third, -100)
	for(var/i in 1 to 30)
		var/list/pair = prison.pick_stab_pair()
		TEST_ASSERT(pair && !(second in pair), "A stabbing left the rivals alone for [pair ? "[pair[1]] and [pair[2]]" : "nobody"]")
	prison.set_affinity(first, third, 0)
	qdel(third)
	prison.refresh_reach()
	TEST_ASSERT_NOTNULL(first.cell, "The first test prisoner has no cell")
	first.cell.stash_shiv = TRUE
	var/first_picked = 0
	for(var/i in 1 to 300)
		var/list/pair = prison.pick_stab_pair()
		if(pair?[1] == first)
			first_picked++
	TEST_ASSERT(first_picked > 165, "A prisoner with a stashed shiv was the stabber [first_picked] times in 300, not about 225") // PRISON_INCIDENT_STASH_PICK_MULT
	var/list/weights = prison.wildcard_kind_weights()
	TEST_ASSERT_EQUAL(weights["stab"], 6, "A stashed shiv left the stabbing weight at [weights["stab"]], not 6") // PRISON_INCIDENT_WEIGHT_STAB x PRISON_INCIDENT_STASH_KIND_MULT
	first.cell.stash_shiv = FALSE
	weights = prison.wildcard_kind_weights()
	TEST_ASSERT_EQUAL(weights["stab"], 3, "With no shiv hidden the stabbing weight is [weights["stab"]], not 3") // PRISON_INCIDENT_WEIGHT_STAB
	settle_prison_air(home)

// ===== THE ADMIN TRIGGERS =====

/datum/unit_test/voidcrew_outpost_prison_wildcard_admin
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_wildcard_admin/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("wildadminowner")
	TEST_ASSERT_NOTNULL(home, "The incident admin test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/first = trouble_prisoner(prison, prison_spot(home, 7, 8))
	var/mob/living/basic/outpost_prisoner/second = trouble_prisoner(prison, prison_spot(home, 9, 8))
	set_moods(list(first, second), 90)
	prison.refresh_reach()
	var/mob/living/carbon/human/operator = make_player(prison_spot(home, 8, 4), "wildadmin")
	var/datum/outpost_manipulator/unit_test/prison/panel = allocate(__IMPLIED_TYPE__, operator)
	panel.selected = home

	// The Prison section carries the incident block.
	var/list/data = panel.ui_data(operator)
	var/list/block = data["selected"]["prison"]["incidents"]
	TEST_ASSERT(islist(block), "The prison section sends no incident block")
	for(var/key in list("chance", "gap_left", "paused", "running", "actor", "target", "tell_left", "wing_event_in", "wing_event_paused", "wing_event_pending"))
		TEST_ASSERT(key in block, "The incident block sends no [key]")

	// A stabbing, straight to the attack: the stashed shiv comes out and it is a fight past its argument.
	first.cell.stash_shiv = TRUE
	second.cell.stash_shiv = TRUE
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "stab"))
	TEST_ASSERT_NULL(panel.error, "The stab button was refused: [panel.error]")
	var/datum/outpost_prison_wildcard/stab = prison.wildcard
	TEST_ASSERT_NOTNULL(stab, "The stab button started no stabbing")
	TEST_ASSERT_EQUAL(stab.stage, "attack", "The stab button did not skip the tell")
	TEST_ASSERT_EQUAL(prison.wildcard_gap_left, 600, "An admin stabbing did not start the gap") // PRISON_INCIDENT_GAP
	var/mob/living/basic/outpost_prisoner/attacker = stab.actor()
	var/mob/living/basic/outpost_prisoner/victim = stab.target()
	TEST_ASSERT(attacker.has_shiv(), "The stabber has no shiv")
	TEST_ASSERT(!attacker.cell.stash_shiv, "The stabber did not draw the shiv under their mattress")
	TEST_ASSERT(attacker.fight && attacker.fight == victim.fight, "The stabbing is not a fight between the two")
	TEST_ASSERT(attacker.fight.fighting, "The stabbing started with an argument")
	// A shiv hits a prisoner harder than a fist, and softer than it hits staff (PRISONER_STAB_MIN/MAX).
	var/health_before = victim.health
	TEST_ASSERT(attacker.strike(victim), "The stabber could not strike")
	TEST_ASSERT(health_before - victim.health >= 7 && health_before - victim.health <= 10, "A stab did [health_before - victim.health] damage, not 7-10")
	// The fight over, the stabber drops the shiv and the incident is done.
	prison.end_fight(attacker.fight)
	prison.wildcard_tick(1)
	TEST_ASSERT_NULL(prison.wildcard, "The stabbing outlasted its fight")
	TEST_ASSERT(!attacker.has_shiv(), "The stabber kept the shiv after the fight")
	TEST_ASSERT_NOTNULL(locate(/obj/item/knife/shiv) in get_turf(attacker), "The stabber's shiv is not on the floor")
	wildcard_reset(prison)
	first.cell.stash_shiv = FALSE
	second.cell.stash_shiv = FALSE

	// A snap: a riot at once.
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "snap"))
	TEST_ASSERT_NULL(panel.error, "The snap button was refused: [panel.error]")
	TEST_ASSERT(prison.riot_active, "The snap button started no riot")
	// Nothing else while a riot is on.
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "fight"))
	TEST_ASSERT_NOTNULL(panel.error, "A fight started from the panel during a riot")
	wildcard_reset(prison)

	// A fight: its argument first, whatever their moods.
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "fight"))
	TEST_ASSERT_NULL(panel.error, "The fight button was refused: [panel.error]")
	TEST_ASSERT_EQUAL(length(prison.fights), 1, "The fight button started [length(prison.fights)] fights")
	var/datum/outpost_prison_fight/brawl = prison.fights[1]
	TEST_ASSERT(!brawl.fighting, "An incident fight skipped its argument")
	wildcard_reset(prison)

	// With its tell asked for, a stabbing waits, and nothing else starts meanwhile.
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "stab", "tell" = 1))
	TEST_ASSERT_NULL(panel.error, "The stab button with a tell was refused: [panel.error]")
	TEST_ASSERT_EQUAL(prison.wildcard?.stage, "tell", "The stab button with a tell went straight to the attack")
	var/mob/living/basic/outpost_prisoner/brooder = prison.wildcard.actor()
	TEST_ASSERT(!brooder.has_shiv(), "A shiv came out before the tell was over")
	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "snap"))
	TEST_ASSERT_NOTNULL(panel.error, "A second incident started while one was in its tell")
	// The tell runs out: the stabbing.
	prison.wildcard_tick(20) // PRISON_INCIDENT_TELL_MAX
	TEST_ASSERT_EQUAL(prison.wildcard?.stage, "attack", "The tell ran out and no stabbing followed")
	TEST_ASSERT(brooder.has_shiv(), "The stabber pulled no shiv at the end of the tell")
	wildcard_reset(prison)

	panel.manage_outpost(home, operator, "prison_incident", list("kind" = "arson"))
	TEST_ASSERT_NOTNULL(panel.error, "An unknown incident kind was accepted")
	panel.manage_outpost(home, operator, "prison_wing_event", list("kind" = "flood"))
	TEST_ASSERT_NOTNULL(panel.error, "An unknown wing event was accepted")
	panel.manage_outpost(home, operator, "prison_wing_event", list("kind" = "lights"))
	TEST_ASSERT_NULL(panel.error, "The lights button was refused: [panel.error]")
	// The vent backup is now the scrubber overflow
	panel.manage_outpost(home, operator, "prison_wing_event", list("kind" = "vent"))
	TEST_ASSERT_NOTNULL(panel.error, "The old vent wing event was accepted")
	panel.manage_outpost(home, operator, "prison_wing_event", list("kind" = "scrubber"))
	TEST_ASSERT_NULL(panel.error, "The scrubber button was refused: [panel.error]")
	TEST_ASSERT_EQUAL(prison.wing_event_pending, "scrubber", "The scrubber button started no overflow")
	prison.wing_events_destroy()
	settle_prison_air(home)

// ===== STOPPING A STABBING =====

/datum/unit_test/voidcrew_outpost_prison_wildcard_stopped
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_wildcard_stopped/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("wildstopowner")
	TEST_ASSERT_NOTNULL(home, "The stopped stabbing test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/attacker = trouble_prisoner(prison, prison_spot(home, 8, 8))
	var/mob/living/basic/outpost_prisoner/victim = trouble_prisoner(prison, prison_spot(home, 10, 8))
	set_moods(list(attacker, victim), 60)
	prison.refresh_reach()
	var/mob/living/carbon/human/warden = make_player(prison_spot(home, 9, 8), "wildstopowner")
	warden.drop_all_held_items()
	warden.set_combat_mode(FALSE)

	// The tell: a stare and the shadowing, no shiv yet.
	var/datum/outpost_prison_wildcard/stab = new(prison, "stab", attacker, victim)
	prison.wildcard = stab
	stab.begin_tell()
	TEST_ASSERT(prison.wildcard_brooding(attacker), "The stabber is not working up to it")
	TEST_ASSERT(istype(attacker.activity, /datum/prisoner_activity/wildcard_shadow), "The stabber is not keeping close to the victim")
	prison.wildcard_tick(5)
	TEST_ASSERT_EQUAL(prison.wildcard, stab, "The tell ended in 5 seconds") // PRISON_INCIDENT_TELL_MIN
	TEST_ASSERT(!attacker.has_shiv(), "A shiv came out during the tell")

	// A talk calls it off, and nothing follows when the tell would have run out.
	TEST_ASSERT(attacker.talk_down(warden), "Talking to a prisoner working up to a stabbing did nothing")
	TEST_ASSERT_NULL(prison.wildcard, "The talk did not stop the stabbing")
	prison.wildcard_tick(30)
	TEST_ASSERT(!attacker.has_shiv(), "A talked-down stabber pulled a shiv")
	TEST_ASSERT(isnull(attacker.fight) && isnull(victim.fight), "A talked-down stabbing turned into a fight")
	TEST_ASSERT(wildcard_logged(prison, "talked"), "The talk-down was not logged")

	// A baton during the tell stops it too, and costs no mood: they had it coming.
	stab = new(prison, "stab", attacker, victim)
	prison.wildcard = stab
	stab.begin_tell()
	var/mood_before = attacker.mood
	trouble_baton(warden, attacker)
	TEST_ASSERT_NULL(prison.wildcard, "A baton did not stop the stabbing")
	TEST_ASSERT(attacker.mood >= mood_before - 0.01, "Batoning a prisoner about to stab someone cost [mood_before - attacker.mood] mood")
	prison.wildcard_tick(30)
	TEST_ASSERT(!attacker.has_shiv(), "A batoned stabber pulled a shiv")
	settle_prison_air(home)

// ===== A SNAP IN A HAPPY WING =====

/datum/unit_test/voidcrew_outpost_prison_wildcard_snap
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_wildcard_snap/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("wildsnapowner")
	TEST_ASSERT_NOTNULL(home, "The snap test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	prison.crew_home_override = TRUE
	var/mob/living/basic/outpost_prisoner/snapper = trouble_prisoner(prison, prison_spot(home, 8, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/buddy = trouble_prisoner(prison, prison_spot(home, 10, 8), "grumpy")
	var/mob/living/basic/outpost_prisoner/pal = trouble_prisoner(prison, prison_spot(home, 12, 8), "chatty")
	var/list/everyone = list(snapper, buddy, pal)
	// Well above every riot line (PRISON_RIOT_JOIN_GRUMPY is the highest)
	set_moods(everyone, 90)
	prison.refresh_reach()

	var/datum/outpost_prison_wildcard/brewing = new(prison, "snap", snapper)
	prison.wildcard = brewing
	brewing.begin_tell()
	TEST_ASSERT(prison.wildcard_brooding(snapper), "The snapper is not working up to it")
	prison.wildcard_tick(10)
	TEST_ASSERT(!prison.riot_active, "A snap rioted before its tell was over") // PRISON_INCIDENT_TELL_MIN
	prison.wildcard_tick(10)
	TEST_ASSERT(prison.riot_active, "A snap never rioted") // PRISON_INCIDENT_TELL_MAX
	TEST_ASSERT_NULL(prison.wildcard, "The snap outlasted its riot's start")
	var/rioters = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in everyone)
		if(prisoner.is_rioting())
			rioters++
	TEST_ASSERT(snapper.is_rioting(), "The snapper is not rioting")
	TEST_ASSERT_EQUAL(rioters, 1, "A snap in a happy wing drew in [rioters - 1] others")
	wildcard_reset(prison)
	settle_prison_air(home)

// ===== BLOWN LIGHTS =====

/datum/unit_test/voidcrew_outpost_prison_wing_lights
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_prison_wing_lights/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = trouble_test_claim("winglightsowner")
	TEST_ASSERT_NOTNULL(home, "The blown lights test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	trouble_prisoner(prison, prison_spot(home, 8, 8))

	// 1 to 3 working lights blow each time (PRISON_WING_LIGHTS_MIN, PRISON_WING_LIGHTS_MAX).
	for(var/i in 1 to 3)
		for(var/obj/machinery/light/fixture as anything in all_lights(prison))
			fixture.fix()
		var/before = working_lights(prison)
		TEST_ASSERT(before >= 3, "The wing has only [before] lights")
		TEST_ASSERT_EQUAL(prison.start_wing_event("lights"), "lights", "The lights did not blow")
		var/blown = before - working_lights(prison)
		TEST_ASSERT(blown >= 1 && blown <= 3, "[blown] lights blew, not 1 to 3")
		TEST_ASSERT(wildcard_logged(prison, "blew"), "Blown lights were not logged")

	// The clock: only with the crew home, then one comes and the next is 20 to 40 minutes off.
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		fixture.fix()
	prison.wing_events_enabled = TRUE
	prison.wing_event_force_kind = "lights"
	prison.crew_home_override = FALSE
	prison.wing_event_left = 1
	var/before = working_lights(prison)
	prison.wing_events_tick(600)
	TEST_ASSERT_EQUAL(working_lights(prison), before, "Lights blew with nobody home")
	prison.crew_home_override = TRUE
	prison.wing_events_tick(1)
	TEST_ASSERT(working_lights(prison) < before, "The wing event clock ran out and no lights blew")
	TEST_ASSERT(prison.wing_event_left >= 1200 && prison.wing_event_left <= 2400, "The next wing event is [prison.wing_event_left] s off") // PRISON_WING_EVENT_GAP_MIN, PRISON_WING_EVENT_GAP_MAX
	settle_prison_air(home)

// ===== AN OVERFLOWING SCRUBBER, A BACKED-UP KESSLER VENT AND AN OVERFLOWING TOILET =====

/datum/unit_test/voidcrew_outpost_prison_wing_backups
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Set once overflow foam is seen anywhere in the wing outside the cell block
	var/foam_strayed = FALSE

/datum/unit_test/voidcrew_outpost_prison_wing_backups/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("wingventowner")
	TEST_ASSERT_NOTNULL(home, "The scrubber overflow test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	clear_wing_mess(prison)
	prison.refresh_conditions()
	var/clean_before = prison.clean_score

	// Every piece of filth a vent or the foam leaves is mess the scan counts, and the foam carries
	// nothing dangerous: no toxin, acid, drug, fuel, alcohol, lube, pepper or medicine.
	for(var/filth_type in GLOB.outpost_prison_vent_filth)
		TEST_ASSERT(GLOB.outpost_prison_mess_weights[filth_type] > 0, "[filth_type] from a vent is not counted as mess")
	TEST_ASSERT(length(GLOB.outpost_prison_overflow_reagents), "The overflow foam has no reagents")
	for(var/reagent_type in GLOB.outpost_prison_overflow_reagents)
		for(var/banned in list(/datum/reagent/toxin, /datum/reagent/drug, /datum/reagent/fuel, /datum/reagent/consumable/ethanol, /datum/reagent/lube, /datum/reagent/consumable/condensedcapsaicin, /datum/reagent/medicine))
			TEST_ASSERT(!ispath(reagent_type, banned), "The overflow foam can carry [reagent_type]")

	// What can overflow: the map's seven scrubbers, all in the cell block, and none that is welded.
	var/list/sources = prison.overflow_sources()
	TEST_ASSERT_EQUAL(length(sources), 7, "The wing has [length(sources)] scrubbers that can overflow, not 7")
	for(var/obj/source as anything in sources)
		TEST_ASSERT(istype(source, /obj/machinery/atmospherics/components/unary/vent_scrubber), "[source] can overflow while the wing has scrubbers")
		TEST_ASSERT(prison.in_cell_block(source), "A scrubber outside the cell block can overflow")
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/yard_scrubber = locate() in prison_spot(home, 13, 11)
	TEST_ASSERT_NOTNULL(yard_scrubber, "No yard scrubber at (13,11)")
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in sources)
		if(scrubber != yard_scrubber)
			scrubber.welded = TRUE
	var/list/unwelded = prison.overflow_sources()
	TEST_ASSERT(length(unwelded) == 1 && unwelded[1] == yard_scrubber, "Welded scrubbers can still overflow")

	// The yard scrubber gurgles for 5 seconds (PRISON_WING_GURGLE_TIME) and nothing comes up meanwhile.
	var/mob/living/carbon/human/bystander = make_player(prison_spot(home, 12, 11), "wingventbystander")
	prison.wing_event_force_second = FALSE
	TEST_ASSERT_EQUAL(prison.start_wing_event("scrubber"), "scrubber", "No scrubber started to overflow")
	var/list/gurgling = prison.wing_event_source_objects()
	TEST_ASSERT(length(gurgling) == 1 && gurgling[1] == yard_scrubber, "The wrong thing started to overflow")
	TEST_ASSERT_NULL(prison.start_wing_event("toilet"), "A second event started while a scrubber gurgled")
	prison.wing_events_tick(3)
	TEST_ASSERT(!foam_left(prison), "Foam came up after 3 seconds of gurgling")
	var/list/yard_tiles = prison.backup_tiles(get_turf(yard_scrubber), 5)
	TEST_ASSERT_EQUAL(count_filth(yard_tiles), 0, "Filth came up while the scrubber was still gurgling")

	// Then it overflows: tg's foam, which keeps to the cell block, slips nobody and leaves filth.
	prison.wing_events_tick(3)
	TEST_ASSERT_NULL(prison.wing_event_pending, "The scrubber is still gurgling after 6 seconds")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison) in get_turf(yard_scrubber), "No foam came up out of the scrubber")
	TEST_ASSERT(wildcard_logged(prison, "scrubber"), "The overflow was not logged")
	foam_strayed = FALSE
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(foam_gone), prison), 15 SECONDS), "The overflow foam never went away")
	TEST_ASSERT(!foam_strayed, "The overflow foam spread outside the cell block")
	// A piece on each open tile the foam covered: about 10 tiles (PRISON_OVERFLOW_FOAM), a few more
	// as the last ring spreads, less the tables and the water cooler it passes over
	var/filth = count_filth(prison.wing_turfs())
	TEST_ASSERT(filth >= 5 && filth <= 14, "The overflow foam left [filth] pieces of filth, not 5 to 14")
	for(var/turf/tile as anything in prison.wing_turfs())
		if(!prison.in_cell_block(tile))
			TEST_ASSERT_EQUAL(count_filth(list(tile)), 0, "The overflow left filth outside the cell block")
	prison.refresh_conditions()
	TEST_ASSERT(prison.clean_score < clean_before, "A scrubber overflow left the wing [prison.clean_score] clean")
	TEST_ASSERT(bystander.body_position == STANDING_UP && !bystander.IsKnockdown() && !bystander.IsParalyzed(), "The overflow foam knocked a bystander down")
	TEST_ASSERT_EQUAL(bystander.get_total_damage(), 0, "The overflow foam hurt a bystander")
	for(var/datum/reagent/taken as anything in bystander.reagents.reagent_list)
		TEST_ASSERT(GLOB.outpost_prison_overflow_reagents[taken.type], "A bystander in the foam took in [taken.type]")

	// Sometimes a second scrubber overflows with the first.
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in sources)
		scrubber.welded = FALSE
	prison.wing_event_force_second = TRUE
	TEST_ASSERT_EQUAL(prison.start_wing_event("scrubber"), "scrubber", "No scrubbers started to overflow")
	var/list/pair = prison.wing_event_source_objects()
	TEST_ASSERT_EQUAL(length(pair), 2, "[length(pair)] scrubbers gurgled, not 2")
	TEST_ASSERT(pair[1] != pair[2], "The same scrubber was picked twice")
	prison.wing_events_tick(6)
	TEST_ASSERT(wildcard_logged(prison, "2 scrubbers"), "Two scrubbers overflowing was not logged")
	TEST_ASSERT(wait_until(CALLBACK(src, PROC_REF(foam_gone), prison), 15 SECONDS), "The foam from two scrubbers never went away")
	TEST_ASSERT(!foam_strayed, "The foam from two scrubbers spread outside the cell block")

	// Welded shut while it gurgles, a scrubber stays quiet.
	prison.wing_event_force_second = FALSE
	clear_wing_mess(prison)
	TEST_ASSERT_EQUAL(prison.start_wing_event("scrubber"), "scrubber", "No scrubber started to overflow")
	var/obj/machinery/atmospherics/components/unary/vent_scrubber/stopped = prison.wing_event_source_objects()[1]
	stopped.welded = TRUE
	TEST_ASSERT_EQUAL(prison.finish_backup(), 0, "A scrubber welded while it gurgled still overflowed")
	TEST_ASSERT(!foam_left(prison), "A welded scrubber brought up foam")

	// With every scrubber welded shut a sealed Kessler vent backs up instead: 6 to 12 pieces of
	// filth (PRISON_VENT_MESS_MIN, _MAX) within 3 steps (PRISON_VENT_MESS_RANGE).
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in sources)
		scrubber.welded = TRUE
	var/list/fallback = prison.overflow_sources()
	TEST_ASSERT(length(fallback), "With the scrubbers welded, nothing in the cell block can back up")
	for(var/obj/source as anything in fallback)
		TEST_ASSERT(istype(source, /obj/structure/outpost_kessler_vent), "[source] backs up with every scrubber welded")
	TEST_ASSERT_EQUAL(prison.start_wing_event("scrubber"), "scrubber", "No Kessler vent started to back up")
	var/obj/vent = prison.wing_event_source_objects()[1]
	TEST_ASSERT(istype(vent, /obj/structure/outpost_kessler_vent), "The fallback was not a Kessler vent")
	TEST_ASSERT(prison.in_cell_block(vent), "A vent outside the cell block backed up")
	var/list/tiles = prison.backup_tiles(get_turf(vent), 3) // PRISON_VENT_MESS_RANGE
	TEST_ASSERT(length(tiles), "The vent has no floor around it")
	TEST_ASSERT_EQUAL(count_filth(tiles), 0, "Filth came out while the vent was still gurgling")
	prison.wing_events_tick(6)
	TEST_ASSERT_NULL(prison.wing_event_pending, "The vent is still gurgling after 6 seconds")
	filth = count_filth(tiles)
	TEST_ASSERT(filth >= min(6, length(tiles)) && filth <= 12, "The vent spewed [filth] pieces of filth over [length(tiles)] tiles")
	for(var/turf/tile as anything in tiles)
		TEST_ASSERT(get_dist(tile, vent) <= 3 && prison.in_cell_block(tile), "Filth landed off the cell block or too far from the vent")
	TEST_ASSERT(wildcard_logged(prison, "vent"), "The backup was not logged")

	// A toilet floods its own cell: wet floor and a little dirt.
	var/list/toilets = prison.cell_toilets()
	TEST_ASSERT(length(toilets), "No cell has a toilet")
	TEST_ASSERT_EQUAL(prison.start_wing_event("toilet"), "toilet", "No toilet started to overflow")
	var/obj/structure/toilet/toilet = prison.wing_event_source_objects()[1]
	var/datum/outpost_prison_cell/cell = prison.cell_at(get_turf(toilet))
	TEST_ASSERT_NOTNULL(cell, "The overflowing toilet is not in a cell")
	prison.wing_events_tick(6)
	var/wet = 0
	for(var/turf/open/floor in cell.turfs)
		if(floor.GetComponent(/datum/component/wet_floor))
			wet++
	TEST_ASSERT(wet > 0, "The overflowing toilet left its cell dry")
	for(var/turf/open/floor in prison.backup_tiles(get_turf(vent), 3))
		if(!cell.turf_set[floor])
			TEST_ASSERT_NULL(floor.GetComponent(/datum/component/wet_floor), "The toilet flooded floor outside its cell")
	for(var/obj/machinery/atmospherics/components/unary/vent_scrubber/scrubber as anything in sources)
		scrubber.welded = FALSE
	prison.wing_event_force_second = null
	settle_prison_air(home)

/// Pieces of a vent's or the foam's filth on `tiles`
/datum/unit_test/voidcrew_outpost_prison_wing_backups/proc/count_filth(list/tiles)
	var/count = 0
	for(var/turf/tile as anything in tiles)
		for(var/obj/effect/decal/cleanable/mess in tile)
			if(GLOB.outpost_prison_vent_filth[mess.type])
				count++
	return count

/// Whether overflow foam is anywhere in the wing
/datum/unit_test/voidcrew_outpost_prison_wing_backups/proc/foam_left(datum/outpost_prison/prison)
	for(var/turf/tile as anything in prison.wing_turfs())
		if(locate(/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison) in tile)
			return TRUE
	return FALSE

/// Whether the overflow foam has all gone; notes any seen outside the cell block on the way
/datum/unit_test/voidcrew_outpost_prison_wing_backups/proc/foam_gone(datum/outpost_prison/prison)
	var/any = FALSE
	for(var/turf/tile as anything in prison.wing_turfs())
		if(!(locate(/obj/effect/particle_effect/fluid/foam/short_life/outpost_prison) in tile))
			continue
		any = TRUE
		if(!prison.in_cell_block(tile))
			foam_strayed = TRUE
	return !any
