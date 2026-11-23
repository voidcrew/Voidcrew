/**
 * Outpost police tests: looking for a wanted person nobody has eyes on (voidcrew/modules/outpost_police/police_search.dm,
 * and what uses it in police_stealth.dm, police_arrest.dm and police_dispatch.dm). Owner playtest 4: two stars for an
 * emagged gate, the suspect ran to the top of Waystation Halcyon, and no officer ever came.
 *
 * The tests under /datum/unit_test/voidcrew_outpost_police_search are live: a real outpost map, the police's own
 * one-second tick and the officers' own AI, with a body listed as a player so the level stays awake. Their sight is
 * the real stealth sight (the perception's test_plain off) on a floor marked lit.
 *
 * Fork defines are included after the tests, so values are written out: heat 40 is two stars and 60 is three
 * (OUTPOST_POLICE_STAR_HEAT 10, 25, 50, 90, 140); two stars last 45 s unseen (OUTPOST_POLICE_HIDE_2); a wave may be
 * checked for a blocked lift 10 s after it leaves (OUTPOST_POLICE_LIFT_BLOCKED); sectors "concourse" and "lobby".
 */

/datum/unit_test/voidcrew_outpost_police_search
	abstract_type = /datum/unit_test/voidcrew_outpost_police_search
	/// Bodies listed as players: body -> the level they were listed on
	var/list/listed = list()
	/// Turfs this test marked lit
	var/list/turf/lit = list()

/datum/unit_test/voidcrew_outpost_police_search/Destroy()
	for(var/mob/living/body as anything in listed)
		SSmobs.clients_by_zlevel[listed[body]] -= body
	listed = null
	for(var/turf/tile as anything in lit)
		GLOB.stealth_test_dark_turfs -= tile
	lit = null
	return ..()

/**
 * A real outpost of `outpost_type` with no officers yet, its police seeing by the stealth rules on a lit floor, its
 * people going about as if someone were there, and a body listed as a player so the AI on its level runs. Null (and
 * the test has failed) if the map did not load.
 */
/datum/unit_test/voidcrew_outpost_police_search/proc/search_outpost(outpost_type = /obj/structure/overmap/trader_outpost/general)
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
	if(!outpost)
		return null
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	police.dispatch_build_now = TRUE
	police.perception.test_plain = FALSE
	var/turf/corner = outpost.template_bottom_left
	var/turf/far_corner = locate(corner.x + outpost.outpost_template.width - 1, corner.y + outpost.outpost_template.height - 1, corner.z)
	for(var/turf/tile as anything in block(corner, far_corner))
		GLOB.stealth_test_dark_turfs[tile] = FALSE
		lit += tile
	var/mob/living/carbon/human/consistent/onlooker = allocate(/mob/living/carbon/human/consistent, corner)
	SSmobs.clients_by_zlevel[corner.z] += onlooker
	listed[onlooker] = corner.z
	SSambient_npcs.wake_outpost(SSambient_npcs.outpost_place(outpost))
	return outpost

/// The tile `x`, `y` of `outpost`'s map, counted as the map editor does (from 1, 1 at its bottom left)
/datum/unit_test/voidcrew_outpost_police_search/proc/map_tile(obj/structure/overmap/trader_outpost/outpost, x, y)
	var/turf/corner = outpost.template_bottom_left
	return locate(corner.x + x - 1, corner.y + y - 1, corner.z)

/// An officer of `officer_type` at `where`, on duty and awake
/datum/unit_test/voidcrew_outpost_police_search/proc/duty_officer(obj/structure/overmap/trader_outpost/outpost, officer_type, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, officer_type, where)
	officer.resume_routine()
	officer.ai_controller.reset_ai_status()
	return officer

/// The outpost's beat officers, each made on the first stop of a route of its own and walking it
/datum/unit_test/voidcrew_outpost_police_search/proc/beat_officers(obj/structure/overmap/trader_outpost/outpost)
	. = list()
	var/datum/outpost_police/police = outpost.police
	for(var/i in 1 to (police.profile?.beat_count || 2))
		var/turf/start = police.free_route_start()
		if(!start)
			break
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, start)
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
		brain.stealth_setup()
		. += officer

/**
 * Someone wanted at `outpost` with `heat`, standing on `where`, whom the police last saw on `last_seen` a moment ago
 * and nobody sees now.
 */
/datum/unit_test/voidcrew_outpost_police_search/proc/wanted_at(obj/structure/overmap/trader_outpost/outpost, turf/where, turf/last_seen, heat)
	var/mob/living/carbon/human/suspect = dispatch_suspect(outpost, 0, where)
	var/datum/outpost_warrant/warrant = police_pin_warrant(outpost.police, suspect.mind, heat)
	warrant.last_seen_turf = last_seen
	warrant.last_seen_at = world.time
	warrant.unseen_since = world.time
	return suspect

/// Every tile a visitor can walk to from `from` on `outpost`'s concourse, in the order a flood finds them: the last is the furthest walk
/datum/unit_test/voidcrew_outpost_police_search/proc/concourse_from(obj/structure/overmap/trader_outpost/outpost, turf/from)
	var/datum/can_pass_info/pass = new(null, list())
	var/list/found = list()
	var/list/turf/frontier = list(from)
	found[from] = TRUE
	var/at = 1
	while(at <= length(frontier))
		var/turf/here = frontier[at]
		at++
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || found[next] || !outpost.is_secured_turf(next))
				continue
			if(!CAN_STEP(here, next, TRUE, pass, null))
				continue
			found[next] = TRUE
			frontier += next
	return frontier

/// Waits until an officer of `police` sees `suspect`, `limit` at most. Returns how long it took, or -1.
/datum/unit_test/voidcrew_outpost_police_search/proc/wait_seen(datum/outpost_police/police, mob/living/suspect, limit)
	var/started = world.time
	while(world.time - started < limit)
		if(police.suspect_seen(suspect))
			return world.time - started
		sleep(0.5 SECONDS)
	return police.suspect_seen(suspect) ? world.time - started : -1

/// Where every officer of `police` is and what it is doing, for a failure message
/datum/unit_test/voidcrew_outpost_police_search/proc/officers_report(obj/structure/overmap/trader_outpost/outpost)
	var/list/lines = list()
	var/turf/corner = outpost.template_bottom_left
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in outpost.police.officers)
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
		var/turf/here = get_turf(officer)
		lines += "[officer.unit_kind] at [here.x - corner.x + 1],[here.y - corner.y + 1] ([istype(brain) ? brain.stealth_state() : "no brain"][officer.case ? ", on the arrest" : ""])"
	return lines.Join("; ")

// ===== THE ROUND =====

/**
 * Owner playtest 4 as the round's log has it. Waystation Halcyon, a warden at the desk and one beat officer just off
 * the east police lift. Two stars for an emagged gate: last seen on the scanner's tile, inside the scan chamber. The
 * suspect is up in the north wing, behind the bar. The officer leaves its lift, no lift is called blocked, and well
 * inside the 45 s the stars last unseen an officer has the suspect in sight.
 */
/datum/unit_test/voidcrew_outpost_police_search/gate

/datum/unit_test/voidcrew_outpost_police_search/gate/Run()
	var/obj/structure/overmap/trader_outpost/outpost = search_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
	TEST_ASSERT_NOTNULL(post?.sensor, "Halcyon's lobby checkpoint has no scanner")
	var/turf/scanner = get_turf(post.sensor)
	TEST_ASSERT(scanner in post.chamber_turfs, "Fixture: Halcyon's scanner is not on a tile of its scan chamber")
	var/turf/east_lift
	for(var/turf/lift as anything in police.lift_turfs)
		if(!east_lift || lift.x > east_lift.x)
			east_lift = lift
	TEST_ASSERT_NOTNULL(east_lift, "Halcyon has no police lift")
	duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant, police.desk_turf)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat = duty_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, east_lift)
	var/turf/bar = map_tile(outpost, 43, 57)
	TEST_ASSERT(outpost.is_secured_turf(bar) && !bar.is_blocked_turf(exclude_mobs = TRUE), "Fixture: 43,57 of Halcyon is not open floor behind the north wing's bar")
	var/mob/living/carbon/human/suspect = wanted_at(outpost, bar, scanner, 40)
	police.wake()

	var/started = world.time
	var/left_lift_after = -1
	var/seen_after = -1
	while(world.time - started < 45 SECONDS)
		if(left_lift_after < 0 && get_dist(beat, east_lift) > 3)
			left_lift_after = world.time - started
		if(police.suspect_seen(suspect))
			seen_after = world.time - started
			break
		sleep(0.5 SECONDS)
	police.sleep_tick()
	TEST_ASSERT(left_lift_after >= 0 && left_lift_after <= 12 SECONDS, "The officer sent after someone last seen in the scan chamber [left_lift_after < 0 ? "never left its lift" : "took [left_lift_after / 10] s to leave its lift"]")
	TEST_ASSERT(!length(police.dispatch_skipped), "A lift point was called blocked with nothing in its way")
	TEST_ASSERT(seen_after >= 0, "Two stars at the gate, the suspect in the north wing: no officer had them in sight in 45 s. [officers_report(outpost)]")
	log_test("Halcyon, gate to north wing at two stars: left the lift after [left_lift_after / 10] s, in sight after [seen_after / 10] s")
	dispatch_clear(police)

// ===== EVERY MAP =====

/**
 * On each of the three outposts: three stars, last seen stepping out of the lobby checkpoint, and the suspect stands
 * as far from there as a visitor can walk on the concourse. The squad (the beat, and the units that come up by lift)
 * has them in sight inside two minutes: no part of the concourse is somewhere the search never gets to.
 */
/datum/unit_test/voidcrew_outpost_police_search/far_end

/datum/unit_test/voidcrew_outpost_police_search/far_end/Run()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = search_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/outpost_police/police = outpost.police
		var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
		TEST_ASSERT_NOTNULL(post?.secured_turf, "[outpost_type] has no lobby checkpoint onto its concourse")
		var/list/turf/floor = concourse_from(outpost, post.secured_turf)
		var/turf/far = floor[length(floor)]
		TEST_ASSERT(get_dist(far, post.secured_turf) > 13, "Fixture: [outpost_type]'s furthest concourse tile is only [get_dist(far, post.secured_turf)] tiles from its checkpoint")
		beat_officers(outpost)
		var/mob/living/carbon/human/suspect = wanted_at(outpost, far, post.secured_turf, 60)
		police.wake()
		var/seen_after = wait_seen(police, suspect, 2 MINUTES)
		police.sleep_tick()
		var/turf/corner = outpost.template_bottom_left
		TEST_ASSERT(seen_after >= 0, "[outpost_type]: three stars, last seen at the checkpoint, the suspect at [far.x - corner.x + 1],[far.y - corner.y + 1]: no officer had them in sight in two minutes. [officers_report(outpost)]")
		log_test("[outpost_type]: the far end of the concourse ([far.x - corner.x + 1],[far.y - corner.y + 1], [get_dist(far, post.secured_turf)] tiles off) in sight after [seen_after / 10] s")
		qdel(suspect)
		dispatch_clear(police)

// ===== THE LIFT =====

/**
 * A unit that has not left its lift because of where it was sent, with nothing across its door, is not a blocked
 * lift: the point is not skipped. (The round's log: "lift point Outpost Checkpoint (50,55,2) is blocked", 14 s
 * after the crime, with the lobby lift standing open.)
 */
/datum/unit_test/voidcrew_outpost_police_search_lift_open

/datum/unit_test/voidcrew_outpost_police_search_lift_open/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	TEST_ASSERT(length(outpost.lobby_alcove_turfs), "Halcyon has no lobby lift alcove")
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint()
	TEST_ASSERT_NOTNULL(post?.sensor, "Halcyon's lobby checkpoint has no scanner")
	var/turf/point = outpost.lobby_alcove_turfs[1]
	var/mob/living/suspect = dispatch_suspect(outpost, 40)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	warrant.last_seen_turf = get_turf(post.sensor)
	warrant.last_seen_at = world.time
	warrant.unseen_since = world.time
	var/datum/outpost_police_wave/wave = police.dispatch_new_wave("lobby", point)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/unit = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, point)
	unit.dispatch_mind = WEAKREF(suspect.mind)
	wave.members += WEAKREF(unit)
	wave.released_at = world.time - 11 SECONDS
	police.dispatch_check_waves()
	TEST_ASSERT(!(police.dispatch_skipped[point] > world.time), "A lift point was skipped as blocked when its unit could walk out of it")
	TEST_ASSERT_EQUAL(get_turf(unit), point, "A unit standing in an open lift was moved as if it were shut in")
	dispatch_clear(police)

// ===== THE BEAT =====

/// A beat officer who comes up by police lift with nobody wanted (the police's tick asleep) takes a free route at once, and does not stand in the lift
/datum/unit_test/voidcrew_outpost_police_search_beat_arrival

/datum/unit_test/voidcrew_outpost_police_search_beat_arrival/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	police.sleep_tick()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	var/datum/ambient_outpost_role/role = SSambient_npcs.get_outpost_role(/datum/ambient_outpost_role/police_beat)
	TEST_ASSERT_NOTNULL(role, "No police beat role")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = role.arrive(place, null)
	TEST_ASSERT_NOTNULL(officer, "No beat officer came up by police lift")
	allocated += officer
	TEST_ASSERT(get_turf(officer) in police.lift_turfs, "Fixture: the beat officer did not arrive on a police lift")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	// Its first thought
	brain.stealth_setup()
	TEST_ASSERT_NOTNULL(brain.route_id, "A beat officer off the police lift has no route until the police's tick next wakes: it stands in the lift")
	var/datum/stealth_stop/first = brain.group.routes[brain.route_id][1]
	TEST_ASSERT_EQUAL(brain.home_turf, first.spot, "A beat officer off the police lift is not headed for the first stop of its route")
	dispatch_clear(police)
