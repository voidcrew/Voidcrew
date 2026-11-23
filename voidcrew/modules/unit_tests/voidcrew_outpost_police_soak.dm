/**
 * Outpost police soak: the harness (voidcrew/modules/outpost_police/, voidcrew/modules/stealth_police/).
 *
 * The other police tests check one piece in a small room, stepped by hand. These run the whole thing: each real
 * trader outpost is loaded with its own people, a scripted suspect (a human body with a mind and no client) does
 * what a player might, and the police's own tick and the officers' own AI answer in real game time. Nothing here
 * steps an officer, pins a warrant or stands in for a walk.
 *
 * Three parts:
 * - /datum/police_soak: one outpost and one suspect. It keeps the outpost awake (a test world has no client, so the
 *   ambient subsystem is driven by hand, as in every ambient test), drives the suspect through tg's own procs (the
 *   click, the client's step), and once a second writes one line per officer to a trace and checks the invariants.
 * - /datum/police_soak_invariant (voidcrew_outpost_police_soak_invariants.dm): one thing that must never be seen,
 *   one subtype each.
 * - /datum/police_soak_scenario (voidcrew_outpost_police_soak_scenarios.dm): what the suspect does.
 *
 * A break fails the test with the officers' trace for the seconds around it. The full trace of every run lands in
 * the world's log folder as police_soak_<map>_<scenario>.log (the job runner copies that folder to
 * data/jobruns/<id>/logs/).
 *
 * Fork defines are included after the tests, so their values are written out with a comment naming the define.
 * The tests are slow (a minute or two each): they are not in the police's everyday test lists. Their own list is
 * voidcrew/modules/unit_tests/voidcrew_outpost_police_soak.txt.
 */

/// The three real outposts: short name -> overmap type
/proc/police_soak_maps()
	return list(
		"halcyon" = /obj/structure/overmap/trader_outpost/general,
		"quartermain" = /obj/structure/overmap/trader_outpost/outfitter,
		"undertow" = /obj/structure/overmap/trader_outpost/black_market,
	)

/// Every invariant, one instance each
/proc/police_soak_invariants()
	var/static/list/invariants
	if(isnull(invariants))
		invariants = list()
		for(var/invariant_type in subtypesof(/datum/police_soak_invariant))
			invariants += new invariant_type
	return invariants

/// template text -> line kind, for one voice section of the police lines (AMBIENT_STRINGS_POLICE is "outpost_police.json")
/proc/police_soak_line_kinds(section)
	var/static/list/by_section = list()
	if(by_section[section])
		return by_section[section]
	var/list/kinds = list()
	var/list/entry = ambient_dialogue_section("outpost_police.json", section)
	for(var/kind in entry)
		var/list/lines = entry[kind]
		if(!islist(lines))
			continue
		for(var/line in lines)
			if(istext(line))
				kinds[line] = kind
	by_section[section] = kinds
	return kinds

// =========================================================================
// ONE TRACKED BODY
// =========================================================================

/// What the sampler remembers about one officer or outpost NPC between samples
/datum/police_soak_track
	/// Its short name in the trace: B1, W1 (the desk), O2, T1, M1, H1; N3 for one of the outpost's people
	var/id
	/// world.time it was last seen on another tile than before
	var/moved_at = 0
	/// The tile it was on at the last sample
	var/turf/last_turf
	/// The kind of the last line it said ("warn", "stealth_body", "?" for a line that is not in the police file)
	var/said_kind
	/// The words of that line
	var/said_text
	/// world.time it said it
	var/said_at = 0
	/// Whether that line has been written to the trace yet
	var/said_new = FALSE
	/// Whether an invariant has looked at that line yet
	var/said_unchecked = FALSE
	/// The last tiles it stepped onto, oldest first, and when: to tell pacing between two tiles
	var/list/turf/steps = list()
	var/list/step_times = list()
	/// Its distance to where the suspect was last seen, at the last samples (oldest first)
	var/list/scene_dists = list()
	/// Samples in a row it has stood on `stuck_turf` with somewhere to walk to
	var/stuck_ticks = 0
	var/turf/stuck_turf

/datum/police_soak_track/Destroy()
	last_turf = null
	stuck_turf = null
	steps = null
	return ..()

// =========================================================================
// ONE RUN: ONE OUTPOST, ONE SUSPECT, ONE SCENARIO
// =========================================================================

/datum/police_soak
	/// The test this run reports to
	var/datum/unit_test/voidcrew_police_soak/test
	/// "halcyon", "quartermain" or "undertow"
	var/map_name
	var/outpost_type
	var/datum/police_soak_scenario/scenario
	var/obj/structure/overmap/trader_outpost/outpost
	var/datum/outpost_police/police
	var/datum/ambient_place/outpost/place
	/// The scripted suspect: a human with a mind and no client
	var/mob/living/carbon/human/suspect
	/// The outpost's corner: trace positions are counted from it
	var/turf/origin
	var/started_at = 0
	/// Set up and not yet torn down
	var/ready = FALSE
	/// The scenario's script has returned
	var/played = FALSE
	/// Torn down: the sampler and the script stop
	var/finished = FALSE
	/// The z-level the suspect was put on SSmobs' list of players for
	var/listed_z
	/// Trace rows: list(second, id, text)
	var/list/rows = list()
	/// mob -> /datum/police_soak_track
	var/list/tracks = list()
	/// Counters for the trace ids, by letter
	var/list/id_counts = list()
	/// Breaks found: list("name", "rank", "at", "text", "ids")
	var/list/breaks = list()
	/// "invariant|key" of every break already reported
	var/list/break_keys = list()
	/// "invariant|key" -> world.time its condition became true (held())
	var/list/held_since = list()
	/// "x,y>x,y" -> list(mob, world.time) of the last step along that edge, to tell two bodies trading tiles
	var/list/edges = list()
	/// "idA|idB" -> list of world.times they traded tiles
	var/list/swaps = list()
	/// Things the script could not do (the scenario was not driven as written)
	var/list/script_failures = list()
	/// Whether anyone was ever wanted and at large during the run
	var/ever_wanted = FALSE
	/// Every time an officer hit the suspect: list(world.time, officer, what with, what the suspect was to the police then or null)
	var/list/force_events = list()
	/// How many of them the force invariant has looked at
	var/force_checked = 0
	/// world.time of the suspect's last step of their own (own_step())
	var/own_step_at = 0
	/// Whether an officer had hold of the suspect at the last sample
	var/was_held = FALSE
	/// world.times an officer lost hold of a suspect in custody who had not taken a step of their own
	var/list/hold_losses = list()
	/// GLOB.total_runtimes when the run began
	var/runtimes_before = 0
	/// A stand-in hangar berth built for this run (make_hangar()), its lift panel and the berths the outpost had
	var/datum/outpost_berth/hangar
	var/obj/machinery/outpost_elevator/hangar_panel
	var/list/old_berths
	/// Whether the outpost's berths were swapped for the stand-in
	var/berths_swapped = FALSE

/datum/police_soak/New(datum/unit_test/voidcrew_police_soak/new_test, new_map_name, new_outpost_type, scenario_type)
	. = ..()
	test = new_test
	map_name = new_map_name
	outpost_type = new_outpost_type
	scenario = new scenario_type

/datum/police_soak/Destroy()
	finished = TRUE
	if(suspect && listed_z)
		SSmobs.clients_by_zlevel[listed_z] -= suspect
	if(!QDELETED(suspect))
		UnregisterSignal(suspect, list(COMSIG_ATOM_BULLET_ACT, COMSIG_ATOM_AFTER_ATTACKEDBY))
	for(var/mob/living/body as anything in tracks)
		if(!QDELETED(body))
			UnregisterSignal(body, list(COMSIG_MOVABLE_MOVED, COMSIG_MOB_SAY, COMSIG_QDELETING))
	QDEL_LIST_ASSOC_VAL(tracks)
	if(berths_swapped && !QDELETED(outpost))
		outpost.berths = old_berths
	QDEL_NULL(hangar_panel)
	QDEL_NULL(hangar)
	QDEL_NULL(scenario)
	old_berths = null
	test = null
	outpost = null
	police = null
	place = null
	suspect = null
	origin = null
	return ..()

// ----- setting up -----

/**
 * Loads the outpost, fills it with its own people the way an empty outpost fills (settle_outpost()), puts the
 * suspect on the concourse and wakes the place as a player stepping onto it does. FALSE (and the test has failed)
 * if the outpost did not load.
 */
/datum/police_soak/proc/setup()
	outpost = test.police_loaded_outpost(outpost_type)
	if(!outpost)
		return FALSE
	police = outpost.police
	place = SSambient_npcs.outpost_place(outpost)
	origin = outpost.template_bottom_left
	if(!police || !place || !origin)
		test.Fail("[map_name]: the loaded outpost has no police, no ambient place or no corner", __FILE__, __LINE__)
		return FALSE
	// The police see by the stealth rules, as in a round (a test world defaults to plain sight)
	police.perception.test_plain = FALSE
	// Its people, made in place while nobody is there: the desk and the beat first, then the crowd
	for(var/pass in 1 to 30)
		if(!SSambient_npcs.update_outpost(place, 0, null, 40))
			break
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint(null)
	var/turf/start = scenario.start_turf(src, post) || post?.secured_turf || test.police_floor(outpost)
	if(!start)
		test.Fail("[map_name]: nowhere to put the suspect", __FILE__, __LINE__)
		return FALSE
	suspect = test.police_arrest_person(start)
	suspect.real_name = "Soak Suspect"
	suspect.name = suspect.real_name
	// tg's AI runs only on a level with a player on it: the suspect stands in for one, as in voidcrew_stealth_live
	listed_z = start.z
	SSmobs.clients_by_zlevel[listed_z] += suspect
	RegisterSignal(suspect, COMSIG_ATOM_BULLET_ACT, PROC_REF(on_suspect_shot))
	RegisterSignal(suspect, COMSIG_ATOM_AFTER_ATTACKEDBY, PROC_REF(on_suspect_struck))
	runtimes_before = GLOB.total_runtimes
	started_at = world.time
	ready = TRUE
	header()
	keep_awake()
	return TRUE

/// The first lines of the trace: the map's kit and who is on it
/datum/police_soak/proc/header()
	var/list/cells = list()
	for(var/datum/outpost_police_cell/cell as anything in police.cells)
		cells += "[cell.cell_id]@[where(cell.door)]"
	var/list/lifts = list()
	for(var/turf/lift as anything in police.lift_turfs)
		lifts += where(lift)
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint(null)
	var/dark = 0
	var/floor = 0
	for(var/turf/open/tile in block(origin.x, origin.y, origin.z, origin.x + outpost.outpost_template.width - 1, origin.y + outpost.outpost_template.height - 1, origin.z))
		floor++
		if(stealth_tile_is_dark(tile))
			dark++
	note("#", "[map_name] / [scenario.name]: box [outpost.outpost_template.width]x[outpost.outpost_template.height], desk [where(police.desk_turf)], cells [cells.Join(" ")], police lifts [lifts.Join(" ")], gate lobby [where(post?.lobby_turf)] concourse [where(post?.secured_turf)], public lift [where(length(outpost.lobby_alcove_turfs) ? outpost.lobby_alcove_turfs[1] : null)], [dark]/[floor] open tiles dark, voice [police.profile?.voice_section], suspect starts [where(suspect)]")

// ----- once a second -----

/// The sampler: runs beside the script until the run is torn down
/datum/police_soak/proc/sample_loop()
	while(!finished && !QDELETED(src))
		tick()
		sleep(1 SECONDS)

/datum/police_soak/proc/tick()
	if(finished || QDELETED(outpost) || QDELETED(police))
		return
	keep_awake()
	var/now = now()
	for(var/mob/living/body as anything in tracks)
		var/datum/police_soak_track/found = tracks[body]
		var/turf/here = get_turf(body)
		if(here != found.last_turf)
			found.last_turf = here
			found.moved_at = world.time
	if(length(at_large()))
		ever_wanted = TRUE
	// An officer walking someone in who lets go of them, with the suspect standing where they were put
	var/held_now = !QDELETED(suspect) && is_outpost_police_npc(suspect.pulledby)
	if(was_held && !held_now && !QDELETED(suspect) && police.in_custody(suspect) && !police.cell_holding(suspect.mind) && world.time - own_step_at > 5 SECONDS)
		hold_losses += world.time
		note(">>", "the officer's hold on the suspect is gone at [where(suspect)]")
	was_held = held_now
	sample_suspect(now)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		sample_officer(officer, now)
	for(var/datum/police_soak_invariant/invariant as anything in police_soak_invariants())
		if(!(invariant.type in scenario.skipped_invariants))
			invariant.check(src)
	for(var/mob/living/body as anything in tracks)
		var/datum/police_soak_track/found = tracks[body]
		found.said_unchecked = FALSE

/// Seconds since the run began
/datum/police_soak/proc/now()
	return round((world.time - started_at) / (1 SECONDS))

/**
 * A player is on the concourse, as far as the outpost can tell. The ambient subsystem does not run outposts by
 * itself in a test world (ambient_auto): this is its own update, with one player counted. Its people's AI would
 * also idle with no client near (tg's can_idle): they are kept awake, as a player in the room keeps them.
 */
/datum/police_soak/proc/keep_awake()
	SSambient_npcs.update_outpost(place, 1)
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in place.npcs)
		track(npc)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		track(officer)

/// The track of `body`, made (and its steps and speech listened to) the first time it is seen
/datum/police_soak/proc/track(mob/living/carbon/human/npc/body)
	if(QDELETED(body))
		return null
	var/datum/police_soak_track/found = tracks[body]
	if(found)
		return found
	found = new
	var/letter = "N"
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = body
	if(istype(officer))
		// POLICE_UNIT_*: "beat", "sergeant" (the warden at the desk), "officer", "tactical", "marshal", "armour"
		letter = list("beat" = "B", "sergeant" = "W", "officer" = "O", "tactical" = "T", "marshal" = "M", "armour" = "H")[officer.unit_kind] || "P"
	id_counts[letter]++
	found.id = "[letter][id_counts[letter]]"
	found.last_turf = get_turf(body)
	found.moved_at = world.time
	tracks[body] = found
	RegisterSignal(body, COMSIG_MOVABLE_MOVED, PROC_REF(on_tracked_moved))
	RegisterSignal(body, COMSIG_MOB_SAY, PROC_REF(on_tracked_said))
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_tracked_deleted))
	var/datum/ai_controller/brain = body.ai_controller
	if(brain?.can_idle)
		brain.can_idle = FALSE
		brain.reset_ai_status()
	if(istype(officer))
		note("#", "[found.id] = [body.real_name] ([officer.unit_kind]) at [where(body)]")
	return found

/datum/police_soak/proc/on_tracked_deleted(mob/living/source)
	SIGNAL_HANDLER
	var/datum/police_soak_track/found = tracks[source]
	tracks -= source
	if(found)
		qdel(found)

/// A tracked body said something: its kind is looked up from the template the police code just used
/datum/police_soak/proc/on_tracked_said(mob/living/carbon/human/npc/ambient_npc/source, list/speech_args)
	SIGNAL_HANDLER
	var/datum/police_soak_track/found = tracks[source]
	if(!found)
		return
	var/message = html_decode("[speech_args[SPEECH_MESSAGE]]")
	if(findtext(message, ";") == 1)
		message = copytext(message, 2)
	found.said_text = message
	found.said_at = world.time
	found.said_new = TRUE
	found.said_unchecked = TRUE
	found.said_kind = "?"
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = source
	if(!istype(officer))
		return
	var/list/kinds = police_soak_line_kinds(officer.life_voice_section())
	for(var/template in list(officer.last_police_line, officer.last_line))
		if(!istext(template) || !kinds[template])
			continue
		// A template's words up to its first %VALUE% are the start of what was said
		var/cut = findtext(template, "%")
		var/lead = cut ? copytext(template, 1, cut) : template
		if(!length(lead) || findtext(message, lead) == 1)
			found.said_kind = kinds[template]
			return

/// A tracked body stepped: remembered to tell two of them trading tiles, and one pacing between two tiles
/datum/police_soak/proc/on_tracked_moved(mob/living/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	var/datum/police_soak_track/found = tracks[source]
	var/turf/from = old_loc
	var/turf/to_turf = source.loc
	if(!found || !isturf(from) || !isturf(to_turf) || from.z != to_turf.z || get_dist(from, to_turf) > 1)
		return
	found.steps += to_turf
	found.step_times += world.time
	if(length(found.steps) > 8)
		found.steps.Cut(1, 2)
		found.step_times.Cut(1, 2)
	var/list/back = edges["[to_turf.x],[to_turf.y]>[from.x],[from.y]"]
	edges["[from.x],[from.y]>[to_turf.x],[to_turf.y]"] = list(source, world.time)
	if(!back || back[1] == source || world.time - back[2] > 2)
		return
	var/datum/police_soak_track/other = tracks[back[1]]
	if(!other)
		return
	var/pair = found.id < other.id ? "[found.id]|[other.id]" : "[other.id]|[found.id]"
	LAZYADD(swaps[pair], world.time)
	rows += list(list(now(), found.id, "<> trades tiles with [other.id] at [where(from)]/[where(to_turf)]"))

// ----- force on the suspect -----

/datum/police_soak/proc/on_suspect_shot(mob/living/source, obj/projectile/shot, def_zone, piercing_hit, blocked)
	SIGNAL_HANDLER
	force_used(shot.firer, shot.name)

/datum/police_soak/proc/on_suspect_struck(mob/living/source, obj/item/weapon, mob/user, list/modifiers)
	SIGNAL_HANDLER
	force_used(user, weapon.name)

/// An officer hit the suspect: written to the trace with what the suspect was to the police at that moment
/datum/police_soak/proc/force_used(atom/by, what_with)
	if(!is_outpost_police_npc(by) || QDELETED(suspect) || finished)
		return
	var/state = held_state()
	note(">>", "is hit by [who(by)]'s [what_with][state ? " while [state]" : ""]")
	force_events += list(list(world.time, by, what_with, state))

/// What the police have the suspect as, if they are someone no officer should be using force on; null otherwise
/datum/police_soak/proc/held_state()
	if(police.cell_holding(suspect.mind))
		return "in a cell"
	if(police.in_custody(suspect))
		return "in custody"
	if(police.has_in_hand(suspect))
		return "down with an arrest on them"
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	// A shot already in the air when the order was given, or when they gave up, is nobody's fault: a second's grace
	if(police.order_pending(suspect) && world.time - case.order_at > 1 SECONDS)
		return "[round((world.time - case.order_at) / (1 SECONDS))]s into the time to comply with an order"
	// CASE_STEP_CUFF: they did as told and the cuffs are going on
	if(case && !QDELETED(case) && case.step == "cuff" && world.time - case.step_started_at > 1 SECONDS)
		return "being cuffed after giving up"
	return null

// ----- the trace -----

/// A tile as the trace writes it: counted from the outpost's corner, "x,y". Another level is "z3:x,y".
/datum/police_soak/proc/where(atom/thing)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return "-"
	if(!origin || tile.z != origin.z)
		return "z[tile.z]:[tile.x],[tile.y]"
	return "[tile.x - origin.x],[tile.y - origin.y]"

/// Someone as the trace writes them: S for the suspect, a tracked body's id, else their name
/datum/police_soak/proc/who(atom/thing)
	if(isnull(thing))
		return "-"
	if(thing == suspect)
		return "S"
	var/datum/police_soak_track/found = tracks[thing]
	if(found)
		return found.id
	if(isturf(thing))
		return where(thing)
	return "[thing]"

/// A line of the trace that is not a sample: what the script did (">>"), a break ("!!"), the header ("#")
/datum/police_soak/proc/note(id, text)
	rows += list(list(now(), id, text))

/// The script could not do what the scenario says: reported, and the run goes on
/datum/police_soak/proc/script_failed(text)
	script_failures += "[now()]s: [text]"
	note(">>", "SCRIPT FAILED: [text]")
	return FALSE

/// The suspect's line for this second
/datum/police_soak/proc/sample_suspect(now)
	if(QDELETED(suspect))
		rows += list(list(now, "S", "gone"))
		return
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/datum/outpost_police_case/case = police.cases[suspect.mind]
	var/list/flags = list()
	if(suspect.stat == DEAD)
		flags += "dead"
	else if(HAS_TRAIT(suspect, TRAIT_CRITICAL_CONDITION))
		flags += "crit"
	else if(suspect.stat != CONSCIOUS)
		flags += "out"
	if(HAS_TRAIT(suspect, TRAIT_INCAPACITATED))
		flags += "stunned"
	if(suspect.body_position == LYING_DOWN)
		flags += "lying"
	if(suspect.handcuffed)
		flags += "cuffed"
	if(suspect.pulledby)
		flags += "held:[who(suspect.pulledby)]"
	if(suspect.pulling)
		flags += "holds:[who(suspect.pulling)]"
	if(police.cell_holding(suspect.mind))
		flags += "cell"
	if(police.has_in_hand(suspect))
		flags += "in_hand"
	var/list/seen_by = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(officer.stat == CONSCIOUS && police.perception.sees(officer, suspect))
			seen_by += who(officer)
	rows += list(list(now, "S", "stars=[police.get_stars(suspect.mind)] heat=[warrant ? round(warrant.heat) : 0] at=[where(suspect)] [length(flags) ? flags.Join(",") : "up"] seen_by=[length(seen_by) ? seen_by.Join(",") : "-"] last_seen=[where(warrant?.last_seen_turf)] case=[case ? "[case.step]/[round((world.time - case.step_started_at) / (1 SECONDS))]s/r[case.resets]" : "-"] hp=[round(suspect.health)] stam=[round(suspect.getStaminaLoss())]"))

/// One officer's line for this second
/datum/police_soak/proc/sample_officer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, now)
	var/datum/police_soak_track/found = track(officer)
	if(!found)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	var/turf/here = get_turf(officer)
	var/list/flags = list()
	if(officer.stat == DEAD)
		flags += "dead"
	else if(HAS_TRAIT(officer, TRAIT_CRITICAL_CONDITION))
		flags += "crit"
	else if(officer.stat != CONSCIOUS)
		flags += "out"
	if(HAS_TRAIT(officer, TRAIT_INCAPACITATED))
		flags += "stunned"
	if(officer.body_position == LYING_DOWN)
		flags += "lying"
	if(HAS_TRAIT(officer, TRAIT_AI_PAUSED))
		flags += "paused"
	if(officer.npc_exit)
		flags += "leaving"
	if(officer.dispatch_riding)
		flags += "riding"
	if(officer.fading)
		flags += "fading"
	if(officer.pulling)
		flags += "holds:[who(officer.pulling)]"
	if(officer.pulledby)
		flags += "held:[who(officer.pulledby)]"
	if(istype(brain) && brain.ai_status != AI_STATUS_ON)
		flags += "ai:[brain.ai_status]"
	if(officer.activity)
		flags += "doing:[officer.activity.name]"
	var/state = istype(brain) ? brain.stealth_state() : "no brain"
	var/atom/target = istype(brain) ? brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET] : null
	var/datum/mind/hunted = istype(brain) ? brain.police_hunt?.resolve() : null
	var/datum/mind/sent = officer.dispatch_mind?.resolve()
	var/datum/outpost_police_case/case = officer.case
	var/case_text = "-"
	if(case && !QDELETED(case))
		var/part = case.arresting() == officer ? "arresting" : "cover"
		case_text = "[case.step]/[round((world.time - case.step_started_at) / (1 SECONDS))]s/[part][case.acting ? "/[case.acting]" : ""]"
	var/turf/walking_to = istype(brain) ? get_turf(brain.current_movement_target) : null
	var/walk_text = "-"
	if(walking_to)
		walk_text = where(walking_to)
		if(brain.goto_turf == walking_to && brain.goto_purpose)
			walk_text += ":[brain.goto_purpose]"
	var/said = "-"
	if(found.said_at)
		said = "[found.said_kind]@[round((found.said_at - started_at) / (1 SECONDS))]"
		if(found.said_new)
			said += " \"[found.said_text]\""
			found.said_new = FALSE
	rows += list(list(now, found.id, "[state] tgt=[who(target)] hunt=[who(hunted?.current)] sent=[who(sent?.current)] case=[case_text] at=[where(here)] to=[walk_text] [length(flags) ? flags.Join(",") : "up"] said=[said]"))

/// The trace as text: every row, or only rows of `ids` (and breaks and script notes) between seconds `first` and `last`
/datum/police_soak/proc/trace_text(first = 0, last = INFINITY, list/ids)
	var/list/out = list()
	for(var/list/row as anything in rows)
		if(row[1] < first || row[1] > last)
			continue
		if(ids && !(row[2] in ids) && row[2] != "!!" && row[2] != ">>")
			continue
		out += "[add_leading("[row[1]]", 3, "0")] [row[2]] [row[3]]"
	return out.Join("\n")

// ----- what the invariants ask -----

/// Seconds `condition` has been true without a break, for `key`; 0 (and the clock is reset) when it is false
/datum/police_soak/proc/held(key, condition)
	if(!condition)
		held_since -= key
		return 0
	if(isnull(held_since[key]))
		held_since[key] = world.time
	return (world.time - held_since[key]) / (1 SECONDS)

/// An invariant broke. Each `key` of each invariant is reported once a run. `involved` are the bodies whose trace to print. `rank` overrides the invariant's.
/datum/police_soak/proc/breach(datum/police_soak_invariant/invariant, key, text, list/involved, rank)
	var/full_key = "[invariant.name]|[key]"
	if(break_keys[full_key])
		return
	break_keys[full_key] = TRUE
	var/list/ids = list("S")
	for(var/body in involved)
		ids |= istext(body) ? body : who(body)
	breaks += list(list("name" = invariant.name, "rank" = rank || invariant.rank, "at" = now(), "text" = text, "ids" = ids))
	note("!!", "BREAK [invariant.name]: [text]")

/// Conscious officers who are part of the scene: not fading out
/datum/police_soak/proc/officers_up()
	. = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(officer.stat == CONSCIOUS && !officer.fading && !QDELETED(officer))
			. += officer

/// Living wanted people at the outpost whom the police do not have in hand
/datum/police_soak/proc/at_large()
	. = list()
	for(var/datum/outpost_warrant/warrant as anything in police.suspects_at_outpost())
		var/mob/living/body = warrant.mind?.current
		if(isliving(body) && body.stat != DEAD && !police.has_in_hand(body))
			. += body

/// The officer's stealth state: "unaware", "suspicious", "alert" or "searching" (STEALTH_*); null with no police brain
/datum/police_soak/proc/state_of(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	return istype(brain) ? brain.stealth_state() : null

/// Whether `officer` has `person` in mind: as its target, its stealth focus, the one the police set it on, or the one dispatch sent it after
/datum/police_soak/proc/minds(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, mob/living/person)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || !person)
		return FALSE
	// BB_STEALTH_FOCUS is "stealth_focus"
	if(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == person || brain.blackboard["stealth_focus"] == person)
		return TRUE
	var/datum/mind/hunted = brain.police_hunt?.resolve()
	return !!person.mind && hunted == person.mind

// ----- ending -----

/// Stops the run, writes the trace file and fails the test once for every break and every thing the script could not do
/datum/police_soak/proc/finish()
	if(finished)
		return
	finished = TRUE
	if(!ready)
		return
	var/new_runtimes = GLOB.total_runtimes - runtimes_before
	note("#", "end: [length(breaks)] breaks, [length(script_failures)] script failures, [new_runtimes] runtimes in the world meanwhile")
	var/label = "[map_name]/[scenario.name]"
	rustg_file_write(trace_text(), "[GLOB.log_directory]/police_soak_[map_name]_[scenario.name].log")
	sortTim(breaks, GLOBAL_PROC_REF(cmp_police_soak_breaks))
	for(var/list/found as anything in breaks)
		// The officers concerned, for the seconds around it (the whole squad's trace is in the file)
		var/excerpt = trace_text(found["at"] - 8, found["at"] + 1, found["ids"])
		test.Fail("[label] BREAK [found["name"]] at [found["at"]]s: [found["text"]]\n[excerpt]", __FILE__, __LINE__)
	for(var/failure in script_failures)
		test.Fail("[label] SCRIPT: [failure]", __FILE__, __LINE__)

/// Worst first (lowest rank), then earliest first
/proc/cmp_police_soak_breaks(list/a, list/b)
	if(a["rank"] != b["rank"])
		return a["rank"] - b["rank"]
	return a["at"] - b["at"]

// =========================================================================
// THE SUSPECT'S HANDS AND FEET
// Every act is tg's own proc for it: a click is ClickOn(), a step is the client's pre-move signal and Move().
// =========================================================================

/// Waits `time` of game time, or until the run is torn down
/datum/police_soak/proc/stand(time)
	var/until = world.time + time
	while(!finished && world.time < until)
		sleep(min(5, until - world.time))

/// Whether the suspect can act: there, awake and not stunned
/datum/police_soak/proc/suspect_able()
	return !finished && !QDELETED(suspect) && suspect.stat == CONSCIOUS && !HAS_TRAIT(suspect, TRAIT_INCAPACITATED)

/// One click of the suspect's on `target` (`params` as a client sends them: "left=1", "right=1", "ctrl=1"), once tg's click cooldown allows
/datum/police_soak/proc/click(atom/target, params = "left=1")
	if(!suspect_able() || QDELETED(target))
		return FALSE
	var/until = world.time + 3 SECONDS
	while(world.time < until && (suspect.next_move > world.time || suspect.next_click > world.time))
		sleep(1)
	if(!suspect_able() || QDELETED(target))
		return FALSE
	suspect.ClickOn(target, params)
	return TRUE

/// One step of the suspect's own onto `next`, as their player's key press makes it. FALSE if they did not get there.
/datum/police_soak/proc/own_step(turf/next)
	if(!suspect_able() || suspect.buckled || !(suspect.mobility_flags & MOBILITY_MOVE) || !isturf(suspect.loc))
		return FALSE
	var/direction = get_dir(suspect, next)
	SEND_SIGNAL(suspect, COMSIG_MOB_CLIENT_PRE_MOVE, list(next, direction))
	suspect.Move(next, direction)
	if(suspect.loc != next)
		return FALSE
	own_step_at = world.time
	return TRUE

/// Tenths of a second a step of the suspect's takes: tg's speed for them, and never faster than a run (config RUN_DELAY, 1.5; a test world loads none)
/datum/police_soak/proc/step_delay()
	return max(1.5, suspect.cached_multiplicative_slowdown)

/**
 * The suspect walks to `goal` (or within `reach` of it) on their own feet, by tg's pathfinder, bumping doors open
 * as anyone does. TRUE once there; FALSE if `limit` ran out, they went down, or there is no way.
 */
/datum/police_soak/proc/go_to(atom/goal, reach = 0, limit = 45 SECONDS)
	var/turf/end = get_turf(goal)
	if(!end)
		return FALSE
	var/until = world.time + limit
	var/no_path = 0
	while(!finished && world.time < until && !QDELETED(suspect))
		var/turf/here = get_turf(suspect)
		if(here == end || (reach && here.z == end.z && get_dist(here, end) <= reach))
			return TRUE
		if(!suspect_able() || !(suspect.mobility_flags & MOBILITY_MOVE))
			sleep(5)
			continue
		var/list/turf/path = get_path_to(suspect, end, 200, reach)
		if(!length(path))
			no_path++
			if(no_path >= 4)
				return FALSE
			sleep(1 SECONDS)
			continue
		for(var/turf/next as anything in path)
			if(finished || world.time >= until)
				break
			if(own_step(next))
				sleep(step_delay())
				continue
			// A door opening, someone in the way: try the same tile once more, then look for another way
			sleep(4)
			if(own_step(next))
				sleep(step_delay())
				continue
			break
	var/turf/ended = get_turf(suspect)
	return ended == end || (reach && ended && ended.z == end.z && get_dist(ended, end) <= reach)

/// The suspect walks up to `target`, who may be walking too, until they are beside them. TRUE once beside them.
/datum/police_soak/proc/go_up_to(mob/living/target, limit = 45 SECONDS)
	var/until = world.time + limit
	while(!finished && world.time < until && !QDELETED(target) && !QDELETED(suspect))
		if(suspect.Adjacent(target))
			return TRUE
		go_to(target, 1, min(4 SECONDS, until - world.time))
	return !QDELETED(target) && !QDELETED(suspect) && suspect.Adjacent(target)

/// One step of the suspect's own to a free tile beside them, any way
/datum/police_soak/proc/fidget()
	for(var/direction in shuffle(GLOB.cardinals.Copy()))
		var/turf/open/next = get_step(suspect, direction)
		if(istype(next) && !next.is_blocked_turf(TRUE) && own_step(next))
			return TRUE
	return FALSE

/// A free tile of the gate's scanner room beside its wall scanner (any free tile of the room if none is), or null
/datum/police_soak/proc/scanner_room_tile(datum/outpost_checkpoint/post)
	var/turf/any
	for(var/turf/tile as anything in post?.chamber_turfs)
		if(tile.is_blocked_turf(TRUE))
			continue
		if(post.sensor && tile.Adjacent(post.sensor))
			return tile
		any ||= tile
	return any

/// One more of the outpost's people comes up the public lift, by their role's own arrival. The NPC, or null.
/datum/police_soak/proc/arrival()
	var/turf/lift = SSambient_npcs.lift_arrival_turf(outpost)
	if(!lift)
		note(">>", "nobody could arrive: the public lift is not free")
		return null
	for(var/datum/ambient_outpost_role/role as anything in shuffle(SSambient_npcs.get_outpost_roles()))
		if(is_outpost_police_role(role) || !role.npc_type || !role.applies_to(outpost) || ispath(role.npc_type, /mob/living/carbon/human/npc/ambient_npc/outpost/trader))
			continue
		var/mob/living/arrived = role.arrive(place, lift)
		if(arrived)
			note(">>", "[who(arrived) == "[arrived]" ? "someone" : who(arrived)] ([arrived.real_name]) arrives by the public lift at [where(lift)]")
			return arrived
	note(">>", "nobody could arrive: no role took the arrival")
	return null

/// Fists down and hands empty: what the order asks for
/datum/police_soak/proc/give_up()
	if(QDELETED(suspect))
		return
	suspect.set_combat_mode(FALSE)
	suspect.drop_all_held_items()
	note(">>", "gives up: fists down, hands empty")

/// Waits until `what` is true of the suspect, `limit` at most. TRUE if it came true.
/datum/police_soak/proc/wait_for(what, limit = 60 SECONDS)
	var/until = world.time + limit
	while(!finished && world.time < until)
		if(QDELETED(suspect))
			return FALSE
		if(is_now(what))
			note(">>", "[what]")
			return TRUE
		sleep(2)
	note(">>", "never [what] in [limit / (1 SECONDS)]s")
	return FALSE

/// The states wait_for() knows
/datum/police_soak/proc/is_now(what)
	switch(what)
		if("wanted")
			return police.get_stars(suspect.mind) >= 1
		if("not wanted")
			return police.get_stars(suspect.mind) < 1
		if("cuffed")
			return !!suspect.handcuffed
		if("in a cell")
			return !!police.cell_holding(suspect.mind)
		if("uncuffed in a cell")
			var/datum/outpost_police_cell/cell = police.cell_holding(suspect.mind)
			return cell && !suspect.handcuffed && (get_turf(suspect) in cell.tiles)
		if("down")
			return police_suspect_down(suspect)
		if("up")
			return !police_suspect_down(suspect) && suspect.body_position != LYING_DOWN
		if("seen by an officer")
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
				if(officer.stat == CONSCIOUS && police.perception.sees(officer, suspect))
					return TRUE
			return FALSE
		if("dead")
			return suspect.stat == DEAD
	CRASH("police soak: wait_for() does not know \"[what]\"")

/// The conscious officer nearest the suspect (not one in `except`), or null
/datum/police_soak/proc/nearest_officer(list/except)
	var/best_distance = INFINITY
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(officer.stat != CONSCIOUS || officer.fading || officer.z != suspect.z || (officer in except))
			continue
		var/distance = get_dist(officer, suspect)
		if(distance < best_distance)
			best_distance = distance
			. = officer

/// One of the outpost's townspeople, awake: one an officer has in sight if there is any, the nearest such to the suspect
/datum/police_soak/proc/townsperson()
	var/mob/living/best
	var/best_score = INFINITY
	var/list/officers = officers_up()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/local in place.living_npcs())
		if(istype(local, /mob/living/carbon/human/npc/ambient_npc/outpost/trader) || local.stat != CONSCIOUS || local.z != suspect.z || !isturf(local.loc))
			continue
		var/watched = FALSE
		for(var/mob/living/officer as anything in officers)
			if(police.perception.sees(officer, local))
				watched = TRUE
				break
		var/score = get_dist(local, suspect) + (watched ? 0 : 1000)
		if(score < best_score)
			best_score = score
			best = local
	return best

/**
 * A crime in plain sight: the suspect walks up to a townsperson an officer can see and punches them (combat mode,
 * a click) until `blows` have landed. TRUE if they landed.
 */
/datum/police_soak/proc/punch_townsperson(blows = 2)
	var/mob/living/carbon/human/victim = townsperson()
	if(!victim)
		return script_failed("no townsperson on the concourse to hit")
	if(!go_up_to(victim))
		return script_failed("could not walk up to [victim] at [where(victim)] from [where(suspect)]")
	suspect.set_combat_mode(TRUE)
	var/landed = 0
	for(var/attempt in 1 to blows * 4)
		if(landed >= blows || !suspect_able() || QDELETED(victim) || victim.stat == DEAD)
			break
		if(!suspect.Adjacent(victim) && !go_up_to(victim, 10 SECONDS))
			break
		var/before = victim.getBruteLoss() + victim.getStaminaLoss()
		click(victim)
		if(victim.getBruteLoss() + victim.getStaminaLoss() > before)
			landed++
			note(">>", "punches [who(victim)] ([victim.real_name]) at [where(victim)]: blow [landed]")
		// OUTPOST_AGGRESSION_GRACE folds blows closer than half a second into one
		sleep(1 SECONDS)
	if(landed < blows)
		return script_failed("only [landed] of [blows] punches landed on [victim]")
	return TRUE

/**
 * The owner's own first crime: an emag on the checkpoint's wall scanner, from inside the scanner room. TRUE if the
 * gate went down.
 */
/datum/police_soak/proc/emag_gate()
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint(null)
	if(!post?.sensor)
		return script_failed("the outpost has no checkpoint scanner")
	var/obj/item/card/emag/card = test.allocate(/obj/item/card/emag, get_turf(suspect))
	suspect.put_in_active_hand(card, forced = TRUE)
	if(!suspect.Adjacent(post.sensor))
		var/turf/beside
		for(var/turf/tile as anything in post.chamber_turfs)
			if(tile.Adjacent(post.sensor) && !tile.is_blocked_turf(TRUE))
				beside = tile
				break
		if(!beside || !go_to(beside, 0, 20 SECONDS))
			return script_failed("could not get beside the checkpoint scanner at [where(post.sensor)] from [where(suspect)]")
	click(post.sensor)
	note(">>", "emags the checkpoint scanner at [where(post.sensor)]")
	if(!post.is_disabled())
		return script_failed("the emag did not take the gate down")
	return TRUE

/**
 * A shove (a right click) on `target`, until they are on the floor or `tries` are spent. tg's shove sends someone
 * back a tile and floors them when there is no tile to go back to, so the suspect follows and keeps shoving the
 * same way until they are against something. TRUE if they went down.
 */
/datum/police_soak/proc/shove_down(mob/living/target, tries = 14)
	var/push
	for(var/attempt in 1 to tries)
		if(QDELETED(target) || !suspect_able())
			return FALSE
		if(target.body_position == LYING_DOWN)
			return TRUE
		if(!suspect.Adjacent(target))
			var/turf/after = push ? get_step(suspect, push) : null
			if(!(after && own_step(after) && suspect.Adjacent(target)) && !go_up_to(target, 10 SECONDS))
				return FALSE
		push = get_dir(suspect, target)
		click(target, "right=1")
		note(">>", "shoves [who(target)] at [where(target)]")
		sleep(2)
	return !QDELETED(target) && target.body_position == LYING_DOWN

/// tg's grab on `target`, tightened by taking hold again (a second ctrl-click) until it is `state` or `limit` runs out
/datum/police_soak/proc/grab(mob/living/target, state = GRAB_AGGRESSIVE, limit = 25 SECONDS)
	var/until = world.time + limit
	while(!finished && world.time < until && suspect_able() && !QDELETED(target))
		if(suspect.pulling == target && suspect.grab_state >= state)
			return TRUE
		if(!suspect.Adjacent(target) && !go_up_to(target, 10 SECONDS))
			return FALSE
		click(target, "ctrl=1")
		sleep(3)
	return !QDELETED(target) && suspect.pulling == target && suspect.grab_state >= state

/// The public floor tile of the concourse farthest from the suspect that no officer has in sight and the suspect can walk to, or null
/datum/police_soak/proc/far_corner()
	var/list/officers = officers_up()
	var/list/candidates = list()
	for(var/turf/open/tile in block(origin.x, origin.y, origin.z, origin.x + outpost.outpost_template.width - 1, origin.y + outpost.outpost_template.height - 1, origin.z))
		if(!outpost.is_secured_turf(tile) || tile.is_blocked_turf(TRUE) || !place.spot_allowed(tile, null))
			continue
		candidates[tile] = get_dist(tile, suspect)
	sortTim(candidates, GLOBAL_PROC_REF(cmp_numeric_dsc), TRUE)
	var/tried = 0
	for(var/turf/tile as anything in candidates)
		var/watched = FALSE
		for(var/mob/living/officer as anything in officers)
			if(can_see(officer, tile, 9))
				watched = TRUE
				break
		if(watched)
			continue
		tried++
		if(tried > 6)
			break
		if(length(get_path_to(suspect, tile, 250)))
			return tile
	return null

/**
 * A stand-in hangar berth for scenarios that go downstairs: a floored block with a lift alcove and its panel, as
 * berth 1 of the outpost. A real berth is built around a docked ship; this one has no ship, so anyone may ride to it.
 */
/datum/police_soak/proc/make_hangar()
	var/datum/turf_reservation/claimed = SSmapping.request_turf_block_reservation(9, 9, 1, requester = "police soak hangar")
	if(!claimed)
		return script_failed("no room for a stand-in hangar")
	hangar = new(outpost, 1, null)
	hangar.reservation = claimed
	var/turf/corner = hangar.get_bottom_left()
	for(var/turf/tile as anything in hangar.get_block())
		tile.ChangeTurf(/turf/open/floor/iron)
	hangar.alcove_turfs = block(corner.x + 7, corner.y + 7, corner.z, corner.x + 8, corner.y + 8, corner.z)
	old_berths = outpost.berths
	outpost.berths = list(hangar)
	berths_swapped = TRUE
	hangar_panel = new(hangar.alcove_turfs[1])
	hangar_panel.outpost = outpost
	hangar_panel.berth = hangar
	hangar.panel = hangar_panel
	return TRUE

/// The suspect walks into the public lift and rides it to the stand-in hangar, by the lift panel's own ride. TRUE once down there.
/datum/police_soak/proc/ride_to_hangar()
	if(!hangar && !make_hangar())
		return FALSE
	if(!length(outpost.lobby_alcove_turfs) || !length(outpost.lobby_panels))
		return script_failed("the outpost has no public lift")
	var/turf/car
	for(var/turf/tile as anything in outpost.lobby_alcove_turfs)
		if(!tile.is_blocked_turf(TRUE))
			car = tile
			break
	if(!car || !go_to(car, 0, 60 SECONDS))
		return script_failed("could not walk into the public lift at [where(car)] from [where(suspect)]")
	var/obj/machinery/outpost_elevator/panel = outpost.lobby_panels[1]
	if(!panel.start_ride(1, suspect))
		return script_failed("the public lift would not take the suspect down")
	note(">>", "rides the public lift down to the hangar")
	// OUTPOST_ELEVATOR_TRAVEL_TIME is 3 s
	stand(5 SECONDS)
	if(!hangar.contains_turf(get_turf(suspect)))
		return script_failed("the lift ride did not end in the hangar (the suspect is at [where(suspect)])")
	return TRUE

/// Plays the scenario's script, then marks the run played
/datum/police_soak/proc/play()
	note(">>", "script starts")
	scenario.play(src)
	note(">>", "script ends")
	played = TRUE

// =========================================================================
// THE TEST
// =========================================================================

/// One scenario on all three outposts at once (they share a round, as they do in play). Subtypes name the scenario.
/datum/unit_test/voidcrew_police_soak
	abstract_type = /datum/unit_test/voidcrew_police_soak
	/// The /datum/police_soak_scenario this test plays
	var/scenario_type
	var/list/datum/police_soak/runs = list()

/datum/unit_test/voidcrew_police_soak/Destroy()
	QDEL_LIST(runs)
	return ..()

/datum/unit_test/voidcrew_police_soak/Run()
	var/list/maps = police_soak_maps()
	var/longest = 0
	for(var/map_name in maps)
		var/datum/police_soak/run = new(src, map_name, maps[map_name], scenario_type)
		runs += run
		run.setup()
		longest = max(longest, run.scenario.limit)
	for(var/datum/police_soak/run as anything in runs)
		if(run.ready)
			INVOKE_ASYNC(run, TYPE_PROC_REF(/datum/police_soak, sample_loop))
			INVOKE_ASYNC(run, TYPE_PROC_REF(/datum/police_soak, play))
	var/deadline = world.time + longest
	while(world.time < deadline)
		var/waiting = FALSE
		for(var/datum/police_soak/run as anything in runs)
			if(run.ready && !run.played)
				waiting = TRUE
		if(!waiting)
			break
		sleep(1 SECONDS)
	for(var/datum/police_soak/run as anything in runs)
		if(run.ready && !run.played)
			run.script_failed("the script was still running at the scenario's limit of [longest / (1 SECONDS)]s")
		run.finish()
	// A script cut short at the limit gets a moment to see the run is over, before the runs are taken apart
	var/grace = world.time + 15 SECONDS
	while(world.time < grace)
		var/running = FALSE
		for(var/datum/police_soak/run as anything in runs)
			if(run.ready && !run.played)
				running = TRUE
		if(!running)
			break
		sleep(5)
