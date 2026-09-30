/**
 * What prisoners say: the dialogue file's contexts and lines, and when they complain.
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with
 * the define named beside them. Prisons are driven with tick(seconds) with their own processing
 * stopped, never by waiting in real time, except for beams, which run on timers. Fixtures are
 * in voidcrew_outpost_prison_helpers.dm.
 */

// ===== CONTEXTS AND LINES =====

/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts
	parent_type = /datum/unit_test/voidcrew_outpost_management

/**
 * Contexts other prison files say by name, spoken by prisoners. Most are from the balance spec's
 * dialogue package; hatch_empty, subdued, fight_argue_none (a fight with no cause) and
 * threat_backed_down (a threat called off by a talk) are spares for the same systems.
 * turret_backs_off, turret_gives_up and turret_defies answer a turret's warning (outpost_prison_security.dm).
 * creature_flee is the moment a prisoner breaks and runs from a creature (outpost_prison_panic.dm).
 * riot_break_door is a rioter hammering at a way out of the cell block (outpost_prison_breakout.dm).
 */
/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts/proc/prisoner_contexts()
	return list(
		"food_up", "suits_up", "good_food", "poor_food", "sick_call", "tidy", "bin_full", "mess_hall",
		"spat", "fight_argue_food", "fight_argue_ball", "fight_argue_bed", "fight_yield",
		"fight_talked_down", "calm_talk", "talk_refuse", "unbolted", "wreck", "riot_imminent",
		"riot_bystander", "rat", "no_air", "lights_flicker", "arrival_stained", "arrival_hurt",
		"creature_panic", "creature_flee", "vent_noise", "horror", "absorbed", "horror_down", "horror_rises",
		"hatch_empty", "subdued", "fight_argue_none", "threat_backed_down",
		"cuffed", "cuffs_off", "lockdown", "lockdown_over",
		"turret_backs_off", "turret_gives_up", "turret_defies",
		// Hit by a player (outpost_prison_trouble.dm)
		"retaliate", "cower_hit",
		// A rioter hammering at a door or window out (outpost_prison_breakout.dm)
		"riot_break_door",
		// Wildcard incidents and wing events (outpost_prison_incidents.dm, outpost_prison_wing_events.dm)
		"incident_brooding", "incident_stab", "incident_stopped", "incident_pacing", "incident_snap",
		"wing_lights_blown", "wing_scrubber_overflow", "wing_toilet_flood",
	)

/// Contexts said by the researcher and the Kessler team, who have no personality or prisoner details
/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts/proc/visitor_contexts()
	return list("researcher_offer", "researcher_sweetened", "researcher_accept", "researcher_leave", "researcher_no_data", "researcher_pigsty", "kessler_recovery", "kessler_collect")

/// A line with the four placeholders taken out
/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts/proc/without_placeholders(line)
	for(var/placeholder in list("{name}", "{other}", "{crime}", "{time_left}"))
		line = replacetext(line, placeholder, "")
	return line

/// Checks one line of the file: plain ASCII, at most 20 words, only known placeholders, and filled completely
/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts/proc/check_line(line, where, mob/living/basic/outpost_prisoner/talker, mob/living/basic/outpost_prisoner/listener)
	TEST_ASSERT(istext(line) && length(line), "[where] has an empty or non-text line")
	TEST_ASSERT_EQUAL(length(line), length_char(line), "[where] has a line that is not plain ASCII: [line]")
	TEST_ASSERT(length(splittext(line, " ")) <= 20, "[where] has a line over 20 words: [line]")
	var/bare = without_placeholders(line)
	TEST_ASSERT(!findtext(bare, "{") && !findtext(bare, "}"), "[where] has a line with an unknown placeholder: [line]")
	var/filled = talker.fill_line(line, listener)
	TEST_ASSERT(!findtext(filled, "{") && !findtext(filled, "}"), "[where] has a line that did not fill: [filled]")

/datum/unit_test/voidcrew_outpost_prison_dialogue_contexts/Run()
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/personalities = outpost_prisoner_dialogue("personalities")
	var/list/conversations = outpost_prisoner_dialogue("conversations")
	TEST_ASSERT(length(lines), "The dialogue file has no lines")

	// Every context the other files say by name is there, with at least 8 shared lines. Prisoner
	// contexts have lines for at least two personalities. The visitors' lines are one plain
	// sentence each, with no placeholders and no numbers (owner, 2026-09-25: no over-explaining).
	var/list/prisoner_contexts = prisoner_contexts()
	var/list/visitor_contexts = visitor_contexts()
	var/regex/digit = regex(@"[0-9]")
	var/regex/second_sentence = regex(@"[.?!] ")
	for(var/context in prisoner_contexts + visitor_contexts)
		var/list/entry = lines[context]
		TEST_ASSERT(islist(entry), "The dialogue file has no [context] context")
		TEST_ASSERT(length(entry["any"]) >= 8, "[context] has [length(entry["any"])] shared lines, not 8 or more")
		var/own_pools = 0
		for(var/pool in entry)
			TEST_ASSERT(pool == "any" || (pool in personalities), "[context] has lines for [pool], which is not a personality")
			if(pool != "any")
				own_pools++
		if(context in visitor_contexts)
			for(var/line in entry["any"])
				TEST_ASSERT(!findtext(line, "{"), "[context] is said by a visitor but has a placeholder: [line]")
				TEST_ASSERT(!digit.Find(line), "[context] is said by a visitor but has a number: [line]")
				TEST_ASSERT(!second_sentence.Find(line), "[context] is said by a visitor but is more than one sentence: [line]")
		else
			TEST_ASSERT(own_pools >= 2, "[context] has lines for [own_pools] personalities, not 2 or more")

	// Every line in the file fills its placeholders, for any speaker.
	var/mob/living/basic/outpost_prisoner/talker = allocate(/mob/living/basic/outpost_prisoner, run_loc_floor_bottom_left)
	var/mob/living/basic/outpost_prisoner/listener = allocate(/mob/living/basic/outpost_prisoner, run_loc_floor_bottom_left)
	talker.sentence_left = 600
	for(var/context in lines)
		var/list/entry = lines[context]
		for(var/pool in entry)
			for(var/line in entry[pool])
				check_line(line, "[context]/[pool]", talker, listener)
	for(var/list/conversation as anything in conversations)
		check_line(conversation["opener"], "A conversation opener", talker, listener)
		for(var/reply in conversation["replies"])
			check_line(reply, "A conversation reply", talker, listener)

	// Each personality gets a line for every prisoner context, alone or talking to someone.
	for(var/personality in personalities)
		talker.personality = personality
		for(var/context in prisoner_contexts)
			for(var/i in 1 to 3)
				var/alone = talker.pick_line(context, null)
				TEST_ASSERT(alone && !findtext(alone, "{"), "A [personality] prisoner had no usable [context] line alone ([alone])")
				var/together = talker.pick_line(context, listener)
				TEST_ASSERT(together && !findtext(together, "{"), "A [personality] prisoner had no usable [context] line with company ([together])")

// ===== COMPLAINTS =====

/datum/unit_test/voidcrew_outpost_prison_dialogue_complaints
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Whether `prisoner` picks `context` at least once in `tries` goes at pick_speech()
/datum/unit_test/voidcrew_outpost_prison_dialogue_complaints/proc/ever_says(mob/living/basic/outpost_prisoner/prisoner, context, tries = 200)
	for(var/i in 1 to tries)
		var/list/choice = prisoner.pick_speech()
		if(choice && choice[1] == context)
			return TRUE
	return FALSE

/datum/unit_test/voidcrew_outpost_prison_dialogue_complaints/Run()
	// The chance: none at 70 (PRISON_WING_MOOD_LINE) and above, rising in a line to 50 at 0
	// (PRISONER_COMPLAINT_MAX_CHANCE).
	TEST_ASSERT_EQUAL(outpost_prisoner_complaint_chance(75), 0, "A score of 75 has a complaint chance")
	TEST_ASSERT_EQUAL(outpost_prisoner_complaint_chance(70), 0, "A score of 70 has a complaint chance")
	TEST_ASSERT_EQUAL(outpost_prisoner_complaint_chance(100), 0, "A score of 100 has a complaint chance")
	TEST_ASSERT(abs(outpost_prisoner_complaint_chance(35) - 25) < 0.01, "A score of 35 has a complaint chance of [outpost_prisoner_complaint_chance(35)], not 25")
	TEST_ASSERT(abs(outpost_prisoner_complaint_chance(0) - 50) < 0.01, "A score of 0 has a complaint chance of [outpost_prisoner_complaint_chance(0)], not 50")

	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("complaintowner")
	TEST_ASSERT_NOTNULL(home, "The complaint test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/basic/outpost_prisoner/prisoner = test_prisoner(prison, prison_spot(home, 8, 8))
	for(var/obj/machinery/light/fixture as anything in all_lights(prison))
		if(fixture.status != LIGHT_OK)
			fixture.fix()

	// The wing's scores are pinned here; nothing refreshes them while the prison's clock is stopped.
	// A fed, clean, healthy prisoner in a wing at 75 never brings up the floor or the lights.
	prison.powered_score = 100
	prison.clean_score = 75
	prison.lit_score = 75
	for(var/i in 1 to 200)
		var/list/choice = prisoner.pick_speech()
		var/context = choice ? choice[1] : null
		TEST_ASSERT(context != "dirty_prison" && context != "dark", "A prisoner complained about a wing at 75 clean and 75 lit ([context])")
	prison.clean_score = 0
	TEST_ASSERT(ever_says(prisoner, "dirty_prison"), "Nobody complained about a wing at 0 clean in 200 tries")
	prison.clean_score = 100
	prison.lit_score = 0
	TEST_ASSERT(ever_says(prisoner, "dark"), "Nobody complained about a wing at 0 lit in 200 tries")
	prison.lit_score = 100

	// With staff in sight, a complaint about the floor points at the worst mess nearby.
	var/obj/effect/decal/cleanable/dirt/dirt = allocate(/obj/effect/decal/cleanable/dirt, prison_spot(home, 7, 8))
	var/obj/effect/decal/cleanable/vomit/vomit = allocate(/obj/effect/decal/cleanable/vomit, prison_spot(home, 10, 8))
	TEST_ASSERT(prison.in_cell_block(dirt) && prison.in_cell_block(vomit), "The test mess is not in the cell block")
	TEST_ASSERT_NULL(prisoner.show_complaint("dirty_prison"), "A prisoner pointed at the mess with no staff in sight")
	allocate(/mob/living/carbon/human/consistent, prison_spot(home, 8, 7))
	var/atom/pointed = prisoner.show_complaint("dirty_prison")
	TEST_ASSERT_EQUAL(pointed, vomit, "A complaining prisoner pointed at [pointed || "nothing"], not the vomit")
	TEST_ASSERT_NOTNULL(locate(/obj/effect/temp_visual/point) in get_turf(prisoner), "Pointing at the mess showed no pointer")
	TEST_ASSERT_NULL(prisoner.show_complaint("idle"), "A prisoner pointed at something for an idle line")

	// A complaint about the dark points at the dead light near them.
	var/obj/machinery/light/dead_light
	for(var/obj/machinery/light/fixture in view(5, prisoner))
		if(get_area(fixture) == prison.wing)
			dead_light = fixture
			break
	TEST_ASSERT_NOTNULL(dead_light, "The test prisoner can see no light")
	TEST_ASSERT_NULL(prisoner.show_complaint("dark"), "A prisoner pointed at a light while every light works")
	dead_light.break_light_tube()
	pointed = prisoner.show_complaint("dark")
	TEST_ASSERT_EQUAL(pointed, dead_light, "A prisoner complaining about the dark pointed at [pointed || "nothing"], not the broken light")
	dead_light.fix()
	settle_prison_air(home)
