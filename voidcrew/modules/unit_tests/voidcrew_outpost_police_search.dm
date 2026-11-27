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
	// As in a round: the floor is read over the ticks after it is first asked for, and whoever needs it waits
	police.search_read_now = FALSE
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
	// The gate is down, as the emag left it (OUTPOST_CHECKPOINT_EMAG_TIME)
	post.disabled_until = world.time + 3 MINUTES
	police.wake()

	var/started = world.time
	var/left_lift_after = -1
	var/at_gate_after = -1
	var/seen_after = -1
	var/list/turf/looked_at = list()
	while(world.time - started < 45 SECONDS)
		if(left_lift_after < 0 && get_dist(beat, east_lift) > 3)
			left_lift_after = world.time - started
		if(at_gate_after < 0)
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
				if(officer.z == post.secured_turf.z && get_dist(officer, post.secured_turf) <= 2)
					at_gate_after = world.time - started
					break
		var/datum/outpost_police_search/search = police.searches[suspect.mind]
		for(var/turf/place as anything in search?.done)
			looked_at |= place
		if(police.suspect_seen(suspect))
			seen_after = world.time - started
			break
		sleep(0.5 SECONDS)
	police.sleep_tick()
	TEST_ASSERT(left_lift_after >= 0 && left_lift_after <= 12 SECONDS, "The officer sent after someone last seen in the scan chamber [left_lift_after < 0 ? "never left its lift" : "took [left_lift_after / 10] s to leave its lift"]")
	TEST_ASSERT(!length(police.dispatch_skipped), "A lift point was called blocked with nothing in its way")
	// Someone comes to look, well inside the 45 s the stars last unseen
	TEST_ASSERT(at_gate_after >= 0 && at_gate_after <= 25 SECONDS, "Two stars for the gate: [at_gate_after < 0 ? "no officer came to the gate in 45 s" : "the first officer took [at_gate_after / 10] s to get to the gate"]. [officers_report(outpost)]")
	// And the search goes outward from there: found, or by now looking well away from the gate
	var/furthest = 0
	for(var/turf/place as anything in looked_at)
		furthest = max(furthest, get_dist(place, post.secured_turf))
	TEST_ASSERT(seen_after >= 0 || (length(looked_at) >= 4 && furthest >= 10), "Two stars for the gate, the suspect in the north wing: in 45 s the search looked at [length(looked_at)] places, none further than [furthest] tiles from the gate. [officers_report(outpost)]")
	log_test("Halcyon, gate to north wing at two stars: left the lift after [left_lift_after / 10] s, at the gate after [at_gate_after / 10] s, [seen_after >= 0 ? "in sight after [seen_after / 10] s" : "not in sight in 45 s"]; [length(looked_at)] places looked at, the furthest [furthest] tiles from the gate")
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

// ===== THE FLOOR OF EVERY MAP =====

/**
 * Every tile that can be walked to from `seeds` inside the box `low`..`high`, by tg's own pathfinding rule
 * (CAN_STEP): for `walker` carrying `access`, or, with no walker, for a visitor who works the checkpoint's doors
 * and (`climbs`) gets over a counter. Kept apart from police_search.dm's own flood, which these tests check.
 */
/datum/unit_test/proc/police_search_walk(list/turf/seeds, turf/low, turf/high, mob/living/walker, list/access, climbs = FALSE)
	var/datum/can_pass_info/pass = new(walker, access || list())
	if(climbs)
		pass.pass_flags |= PASSTABLE
	var/list/found = list()
	var/list/turf/frontier = list()
	for(var/turf/seed as anything in seeds)
		if(!found[seed])
			found[seed] = TRUE
			frontier += seed
	var/at = 1
	while(at <= length(frontier))
		var/turf/here = frontier[at]
		at++
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(here, direction)
			if(!next || found[next] || next.x < low.x || next.y < low.y || next.x > high.x || next.y > high.y)
				continue
			if(!CAN_STEP(here, next, TRUE, pass, null))
				continue
			found[next] = TRUE
			frontier += next
	return found

/**
 * On each of the three outposts, the floor a search works from: its places can all be walked to from every police
 * lift and every stop of the beat; every tile a visitor can get to (over the counters too) is within six tiles of a
 * place, in a clear line; and someone last seen on the scanner's tile inside the lobby checkpoint is looked for from
 * a tile an officer can stand on. No public tile is somewhere a search never looks.
 */
/datum/unit_test/voidcrew_outpost_police_search_floors

/datum/unit_test/voidcrew_outpost_police_search_floors/Run()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/outpost_police/police = outpost.police
		dispatch_clear(police)
		var/turf/low = outpost.template_bottom_left
		var/turf/high = locate(low.x + outpost.outpost_template.width - 1, low.y + outpost.outpost_template.height - 1, low.z)
		TEST_ASSERT(length(police.lift_turfs), "[outpost_type] has no police lift")
		TEST_ASSERT(length(outpost.lobby_alcove_turfs), "[outpost_type] has no lobby lift")
		TEST_ASSERT(length(police.stop_activities), "[outpost_type] has no beat")
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, police.lift_turfs[1])
		var/read_from = TICK_USAGE_REAL
		var/datum/outpost_police_floor/floor = police.search_floor(police.desk_turf, officer)
		var/read_ms = TICK_DELTA_TO_MS(TICK_USAGE_REAL - read_from)
		TEST_ASSERT_NOTNULL(floor, "[outpost_type]: the police could not read their own floor")
		TEST_ASSERT(length(floor.places), "[outpost_type]: a search has no places to look at")

		// Walked to from every police lift, with an officer's own keys
		for(var/turf/lift as anything in police.lift_turfs)
			var/list/reach = police_search_walk(list(lift), low, high, officer, officer.get_access())
			var/list/missed = list()
			for(var/turf/place as anything in floor.places)
				if(!reach[place])
					missed += "[place.x - low.x + 1],[place.y - low.y + 1]"
			TEST_ASSERT(!length(missed), "[outpost_type]: from the police lift at [lift.x - low.x + 1],[lift.y - low.y + 1] an officer cannot walk to the search places at [missed.Join(" ")]")
			for(var/turf/stop as anything in police.stop_activities)
				TEST_ASSERT(reach[stop], "[outpost_type]: from the police lift at [lift.x - low.x + 1],[lift.y - low.y + 1] an officer cannot walk to the beat stop at [stop.x - low.x + 1],[stop.y - low.y + 1]")
		// And from any stop of the beat
		var/turf/a_stop = police.stop_activities[1]
		var/list/from_beat = police_search_walk(list(a_stop), low, high, officer, officer.get_access())
		for(var/turf/place as anything in floor.places)
			TEST_ASSERT(from_beat[place], "[outpost_type]: from the beat an officer cannot walk to the search place at [place.x - low.x + 1],[place.y - low.y + 1]")
		// No place behind the police's own doors that a visitor cannot get into: the lifts are not searched
		for(var/turf/lift as anything in police.lift_turfs)
			TEST_ASSERT(!(lift in floor.places), "[outpost_type]: the police lift at [lift.x - low.x + 1],[lift.y - low.y + 1] is a place the search looks at")
		// And none in an exit gate, which walks whoever steps into it on through
		for(var/turf/place as anything in floor.places)
			TEST_ASSERT(!(locate(/obj/structure/outpost_exit_gate) in place), "[outpost_type]: the exit gate at [place.x - low.x + 1],[place.y - low.y + 1] is a place the search stands on")
		// From the lobby lift the lobby's places are a walk, and the rest are through the checkpoint
		var/list/from_lobby = police_search_walk(list(outpost.lobby_alcove_turfs[1]), low, high, officer, officer.get_access())
		var/lobby_places = 0
		for(var/turf/place as anything in floor.places)
			if(police.sector_of(place) != "lobby")
				continue
			lobby_places++
			TEST_ASSERT(from_lobby[place], "[outpost_type]: from the lobby lift an officer cannot walk to the lobby's search place at [place.x - low.x + 1],[place.y - low.y + 1]")
		TEST_ASSERT(lobby_places, "[outpost_type]: no search place in the lobby")
		officer.forceMove(outpost.lobby_alcove_turfs[1])
		TEST_ASSERT_NOTNULL(police.checkpoint_step_to_concourse(officer), "[outpost_type]: an officer in the lobby has no way through the checkpoint to the concourse")
		police.clear_checkpoint_crossing(officer)

		// Every tile a visitor can get to is in sight of a place. Whoever stands in a scan chamber is seen by its scanner.
		var/list/turf/seeds = list()
		seeds += outpost.lobby_alcove_turfs
		for(var/turf/stop as anything in police.stop_activities)
			seeds += stop
		var/list/public = police_search_walk(seeds, low, high, null, null, TRUE)
		var/datum/outpost_checkpoint/lobby_post = outpost.lobby_checkpoint()
		for(var/checkpoint_id in outpost.checkpoints)
			var/datum/outpost_checkpoint/post = outpost.checkpoints[checkpoint_id]
			for(var/turf/tile as anything in post.chamber_turfs)
				public -= tile
			public -= get_turf(post.inner_door)
			public -= get_turf(post.outer_door)
		TEST_ASSERT(length(public) > 200, "[outpost_type]: only [length(public)] tiles a visitor can get to: the fixture's flood is broken")
		var/list/unseen = list()
		for(var/turf/tile as anything in public)
			var/shown = FALSE
			for(var/turf/place as anything in floor.places)
				if(get_dist(place, tile) <= 6 && stealth_can_see(place, tile, 6)) // POLICE_SEARCH_SIGHT
					shown = TRUE
					break
			if(!shown)
				unseen += "[tile.x - low.x + 1],[tile.y - low.y + 1]"
		TEST_ASSERT(!length(unseen), "[outpost_type]: [length(unseen)] of the [length(public)] tiles a visitor can get to are in sight of no search place: [unseen.Join(" ")]")

		// The round: last seen on the scanner's tile, in the chamber no NPC walks into
		TEST_ASSERT_NOTNULL(lobby_post?.sensor, "[outpost_type]: the lobby checkpoint has no scanner")
		var/turf/scanner = get_turf(lobby_post.sensor)
		TEST_ASSERT(!floor.walkable[scanner], "[outpost_type]: an officer can now walk onto the scanner's tile: this test's premise is gone")
		var/turf/start = police.search_start(scanner, officer)
		TEST_ASSERT(start && floor.walkable[start], "[outpost_type]: someone last seen in the scan chamber is looked for from a tile no officer can stand on")
		TEST_ASSERT(get_dist(start, scanner) <= 3, "[outpost_type]: someone last seen in the scan chamber is looked for [get_dist(start, scanner)] tiles away")
		TEST_ASSERT_EQUAL(police.sector_of(start), "lobby", "[outpost_type]: with the gate working, someone last seen in the scan chamber is looked for past the inner door that never opened for them")
		// The gate down (an emag on its scanner): they are through it
		lobby_post.disabled_until = world.time + 1 MINUTES
		start = police.search_start(scanner, officer)
		TEST_ASSERT(start && floor.walkable[start], "[outpost_type]: with the gate down, someone last seen in the scan chamber is looked for from a tile no officer can stand on")
		TEST_ASSERT(get_dist(start, scanner) <= 3, "[outpost_type]: with the gate down, someone last seen in the scan chamber is looked for [get_dist(start, scanner)] tiles away")
		TEST_ASSERT_EQUAL(police.sector_of(start), "concourse", "[outpost_type]: with the gate down, someone last seen in the scan chamber is looked for on the lobby side of it")
		lobby_post.disabled_until = 0
		var/list/place_list = list()
		for(var/turf/place as anything in floor.places)
			place_list += "[place.x - low.x + 1],[place.y - low.y + 1]"
		log_test("[outpost_type]: [length(floor.places)] search places for [length(public)] public tiles ([length(floor.walkable)] an officer can walk to), read in [read_ms] ms: [place_list.Join(" ")]")
		dispatch_clear(police)

// ===== DEALING THE PLACES =====

/// A wanted person nobody sees, in the stealth police room: last seen at (dx, dy), two stars
/datum/unit_test/voidcrew_stealth_live/police/proc/unseen_suspect(dx, dy, at_dx, at_dy)
	var/mob/living/carbon/human/suspect = visitor_at(at_dx, at_dy)
	var/datum/outpost_warrant/warrant = police_pin_warrant(police, suspect.mind, 40)
	warrant.last_seen_turf = at(dx, dy)
	warrant.last_seen_at = world.time
	warrant.unseen_since = world.time
	return suspect

/**
 * The search for someone nobody sees: the first officer is sent to where they were last seen, the next somewhere
 * else, and each keeps its place until it has looked there. Every place is looked at once before any is looked at
 * again, the nearest to the start first. A new sighting starts over from there; in someone's sight, everyone goes to
 * where they are seen; with no sighting nobody is sent anywhere. Last seen somewhere no officer can walk to, the
 * search starts from the nearest tile one can.
 */
/datum/unit_test/voidcrew_stealth_live/police/search_deal

/datum/unit_test/voidcrew_stealth_live/police/search_deal/Run()
	TEST_ASSERT(police_room(40, 9), "No room for the test")
	// A cell nobody can walk into, built before the floor is first read
	for(var/dx in 29 to 31)
		for(var/dy in 3 to 5)
			if(dx == 30 && dy == 4)
				continue
			var/turf/wall_spot = at(dx, dy)
			wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/first = officer_at(4, 4)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = officer_at(5, 6)
	var/mob/living/carbon/human/suspect = unseen_suspect(2, 4, 38, 7)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/turf/last = warrant.last_seen_turf

	var/turf/first_place = police.search_place(warrant, first)
	TEST_ASSERT_EQUAL(first_place, last, "The first officer is not sent to where they were last seen")
	var/turf/second_place = police.search_place(warrant, second)
	TEST_ASSERT_NOTNULL(second_place, "The second officer was sent nowhere")
	TEST_ASSERT_NOTEQUAL(second_place, last, "Both officers were sent to the same tile")
	TEST_ASSERT_EQUAL(police.search_place(warrant, first), last, "An officer was given a new place before it had looked at its own")
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), second_place, "An officer was given a new place before it had looked at its own")

	// Looked at, one after another: every place once before any twice, and never further from the start than the next
	var/datum/outpost_police_floor/floor = police.search_floor(last, first)
	TEST_ASSERT_NOTNULL(floor, "The room's floor was not read")
	TEST_ASSERT(length(floor.places) >= 3, "A 40x9 room has only [length(floor.places)] places to look at")
	var/list/turf/visited = list()
	var/turf/place = first_place
	var/widest = 0
	for(var/i in 1 to length(floor.places) + 3)
		if(place in visited)
			break
		visited += place
		// Outward: never back toward the start by more than the width of the room while there are places further out
		var/spread = get_dist(last, place)
		TEST_ASSERT(spread >= widest - 9, "A place [spread] tiles from the start was dealt after one [widest] tiles from it")
		widest = max(widest, spread)
		// The officer walks there and looks
		first.forceMove(place)
		police.search_looked(warrant, first, place)
		place = police.search_place(warrant, first)
	for(var/turf/known as anything in floor.places)
		TEST_ASSERT((known in visited) || get_dist(known, second_place) <= 2 || length(visited & RANGE_TURFS(2, known)), "The search started over without the place at [known.x],[known.y]")
	TEST_ASSERT(place in visited, "With every place looked at the search did not start over")
	TEST_ASSERT(widest >= 24, "The search never got further than [widest] tiles from where it started in a 40-tile room")

	// A place an officer could not get to (shut in, a crate across the way) is not looked at: it is not that
	// officer's again, and the next officer is sent there
	TEST_ASSERT_EQUAL(place, last, "Fixture: the search did not start over from where they were last seen")
	police.search_looked(warrant, first, null)
	TEST_ASSERT_NOTEQUAL(police.search_place(warrant, first), last, "An officer was sent again to a place it could not get to")
	police.search_looked(warrant, second, null)
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), last, "A place one officer could not get to was counted as looked at")

	// A new sighting: from there
	warrant.last_seen_turf = at(20, 7)
	warrant.last_seen_at = world.time + 1
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), at(20, 7), "A new sighting did not start the search over from there")
	// In someone's sight: everyone to where they are seen
	warrant.unseen_since = 0
	TEST_ASSERT_EQUAL(police.search_place(warrant, first), at(20, 7), "With eyes on the suspect an officer was sent somewhere else")
	TEST_ASSERT_EQUAL(police.search_place(warrant, second), at(20, 7), "With eyes on the suspect an officer was sent somewhere else")
	// Last seen where nobody can walk: the nearest tile an officer can stand on
	warrant.unseen_since = world.time
	warrant.last_seen_turf = at(30, 4)
	warrant.last_seen_at = world.time + 2
	var/turf/reached = police.search_place(warrant, first)
	TEST_ASSERT(reached && reached != at(30, 4) && floor.walkable[reached], "Last seen in a walled-off cell: the officer was sent to [reached ? "[reached.x],[reached.y]" : "nowhere"], not to a tile it can stand on")
	TEST_ASSERT_EQUAL(get_dist(reached, at(30, 4)), 2, "The search for someone last seen in a walled-off cell starts [get_dist(reached, at(30, 4))] tiles from it")
	// Nobody has seen them at all (owner decision 52): nobody is sent
	warrant.last_seen_turf = null
	TEST_ASSERT_NULL(police.search_place(warrant, first), "An officer was sent to look for someone nobody has seen")
	TEST_ASSERT(!first.police_search_for(suspect.mind), "An officer went looking for someone nobody has seen")

/**
 * An officer dispatch has after someone looks at the place it was sent to, then is sent on to the next; it does not
 * give the search up while they are wanted; a fresher sighting turns it; and an officer nobody sent searches as it
 * always did.
 */
/datum/unit_test/voidcrew_stealth_live/police/search_widens

/datum/unit_test/voidcrew_stealth_live/police/search_widens/Run()
	TEST_ASSERT(police_room(40, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 4)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	var/mob/living/carbon/human/suspect = unseen_suspect(2, 4, 38, 7)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/turf/last = warrant.last_seen_turf
	officer.dispatch_mind = WEAKREF(suspect.mind)

	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "An officer sent after someone nobody sees is not searching")
	TEST_ASSERT_EQUAL(brain.search_center, last, "It is not looking where they were last seen")
	TEST_ASSERT_EQUAL(length(brain.search_queue), 1, "A place the police dealt has [length(brain.search_queue)] spots to look at, not the one")
	// Nothing new: it stays on its place
	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.search_center, last, "It was sent on before it had looked")
	// It has looked (the search asks for its spots again once the last is done)
	brain.stealth_search_spots(brain.search_center)
	TEST_ASSERT(brain.police_looked, "Asking for a search's spots a second time did not mark it looked at")
	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "An officer stopped searching with the suspect still wanted")
	TEST_ASSERT_NOTEQUAL(brain.search_center, last, "With its place looked at the officer was not sent on")
	var/turf/second_center = brain.search_center
	// The time a search lasts runs out on the way: it goes on
	brain.blackboard["stealth_state_since"] = world.time - 10 MINUTES // BB_STEALTH_STATE_SINCE
	police.stealth_tick_officer(officer)
	brain.stealth_scan_once()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "An officer on its way to a place gave the search up")
	TEST_ASSERT(!brain.stealth_bark("stealth_give_up"), "An officer said it was giving up with its suspect still wanted") // STEALTH_BARK_GIVE_UP

	// A fresher sighting, lost again: it turns to that
	warrant.last_seen_turf = at(30, 2)
	warrant.last_seen_at = world.time + 1
	police.stealth_tick_officer(officer)
	TEST_ASSERT_EQUAL(brain.search_center, at(30, 2), "A fresher sighting did not turn the search")
	TEST_ASSERT_NOTEQUAL(second_center, at(30, 2), "Fixture: the second place was the new sighting")

	// An officer nobody sent: its own search, as before
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/loner = officer_at(10, 6)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/loner_brain = loner.ai_controller
	loner_brain.stealth_setup()
	loner_brain.stealth_go_searching(at(12, 6))
	TEST_ASSERT(length(loner_brain.search_queue) > 1, "A search nobody dealt has only its centre to look at")
	loner_brain.stealth_search_spots(loner_brain.search_center)
	police.stealth_tick_officer(loner)
	TEST_ASSERT_EQUAL(loner_brain.search_center, at(12, 6), "An officer dispatch never sent was dealt a place")

/**
 * The arrest that has not found its suspect: the arresting officer goes to where they were last seen, looks about,
 * and goes on to the next place. It used to stand on the first until the step timed out.
 */
/datum/unit_test/voidcrew_stealth_live/police/search_arrest

/datum/unit_test/voidcrew_stealth_live/police/search_arrest/Run()
	TEST_ASSERT(police_room(40, 9), "No room for the test")
	// A wall across the room with a gap, so the suspect at the far end is out of sight
	for(var/dy in 0 to 6)
		var/turf/wall_spot = at(24, dy)
		wall_spot.ChangeTurf(/turf/closed/wall)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(8, 4, WEST)
	var/mob/living/carbon/human/suspect = unseen_suspect(2, 4, 38, 1)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/turf/last = warrant.last_seen_turf
	var/datum/outpost_police_case/case = police.open_case(warrant)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	TEST_ASSERT_EQUAL(case.arresting(), officer, "Fixture: the officer is not the arresting officer")

	case.process_case()
	TEST_ASSERT_EQUAL(case.search_at, last, "The arresting officer is not sent to where the suspect was last seen")
	TEST_ASSERT_EQUAL(get_turf(case.goal), last, "The arresting officer's walk is not to where the suspect was last seen")
	// There: a look about, standing
	officer.forceMove(at(3, 4))
	case.process_case()
	TEST_ASSERT(case.search_look_until > world.time, "At the place it was sent to, the arresting officer did not look about")
	TEST_ASSERT_NULL(case.goal, "The arresting officer walks on while it looks about")
	// Looked: the next place, somewhere else
	case.search_look_until = world.time - 1
	case.process_case()
	case.process_case()
	TEST_ASSERT_NOTNULL(case.search_at, "With its place looked at the arresting officer was sent nowhere")
	TEST_ASSERT_NOTEQUAL(case.search_at, last, "With its place looked at the arresting officer was sent to it again")
	TEST_ASSERT_EQUAL(get_turf(case.goal), case.search_at, "The arresting officer does not walk to its next place")
	// A place it gets no nearer to is given up for the next
	var/turf/stuck_on = case.search_at
	case.search_best_at = world.time - 1 MINUTES
	case.search_best = 0
	case.process_case()
	case.process_case()
	TEST_ASSERT_NOTEQUAL(case.search_at, stuck_on, "The arresting officer kept to a place it was getting no nearer to")
	// Someone has eyes on them: straight there
	warrant.last_seen_turf = at(30, 2)
	warrant.last_seen_at = world.time
	warrant.unseen_since = 0
	case.process_case()
	TEST_ASSERT_EQUAL(get_turf(case.goal), at(30, 2), "With a colleague's eyes on the suspect the arresting officer does not go to where they are seen")
	police.close_case(suspect.mind)

/**
 * The hangars: once the outpost's own floor has been looked at, a response unit is dealt the places of a hangar, and
 * a beat officer, who is never taken to one, starts the floor again. A beat officer is no part of the response to
 * someone last seen in a hangar: dispatch leaves it on its beat and sends the units the hangar is due.
 */
/datum/unit_test/voidcrew_stealth_live/police/search_hangar

/datum/unit_test/voidcrew_stealth_live/police/search_hangar/Run()
	TEST_ASSERT(police_room(14, 7), "No room for the test")
	var/datum/turf_reservation/claimed = SSmapping.request_turf_block_reservation(9, 9, 1, requester = "police search hangar test")
	TEST_ASSERT_NOTNULL(claimed, "Could not reserve a hangar")
	var/datum/outpost_berth/berth = new(outpost, 1, null)
	berth.reservation = claimed
	for(var/turf/tile as anything in berth.get_block())
		tile.ChangeTurf(/turf/open/floor/iron)
	var/turf/hangar_corner = berth.get_bottom_left()
	berth.alcove_turfs = list(hangar_corner, get_step(hangar_corner, EAST))
	var/list/old_berths = outpost.berths
	outpost.berths = list(berth)

	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/unit = officer_at(3, 3, EAST, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat = officer_at(5, 3)
	var/mob/living/carbon/human/suspect = unseen_suspect(2, 3, 12, 5)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	var/datum/outpost_police_floor/floor = police.search_floor(warrant.last_seen_turf, unit)
	TEST_ASSERT_NOTNULL(floor, "The room's floor was not read")

	// The response unit works through the room, then is sent to the hangar
	var/turf/place
	var/in_hangar = FALSE
	for(var/i in 1 to length(floor.places) + 3)
		place = police.search_place(warrant, unit)
		TEST_ASSERT_NOTNULL(place, "The response unit was sent nowhere")
		if(berth.contains_turf(place))
			in_hangar = TRUE
			break
		unit.forceMove(place)
		police.search_looked(warrant, unit, place)
	TEST_ASSERT(in_hangar, "With the outpost's own floor looked at, a response unit was not sent to the hangar")
	// The beat officer never is
	for(var/i in 1 to length(floor.places) + 3)
		place = police.search_place(warrant, beat)
		TEST_ASSERT_NOTNULL(place, "The beat officer was sent nowhere")
		TEST_ASSERT(!berth.contains_turf(place), "A beat officer was sent to look in a hangar")
		beat.forceMove(place)
		police.search_looked(warrant, beat, place)

	// Last seen in the hangar: the beat is no part of that response
	warrant.last_seen_turf = locate(hangar_corner.x + 4, hangar_corner.y + 4, hangar_corner.z)
	warrant.last_seen_at = world.time + 1
	TEST_ASSERT(police.dispatch_out_of_reach(beat, warrant), "A beat officer counts as part of the response to a hangar it is never taken to")
	TEST_ASSERT(!police.dispatch_out_of_reach(unit, warrant), "A response unit is not part of the response to a hangar")
	beat.resume_routine()
	unit.resume_routine()
	suspect.forceMove(warrant.last_seen_turf)
	police.dispatch_next_wave = world.time + 1 MINUTES
	police.dispatch_respond(police.alert_level())
	TEST_ASSERT(!beat.dispatch_responding(), "Dispatch sent a beat officer after someone last seen in a hangar")
	TEST_ASSERT(unit.dispatch_responding(), "Dispatch did not send the response unit after someone last seen in a hangar")
	TEST_ASSERT_EQUAL(police.search_place(warrant, unit), warrant.last_seen_turf, "The response unit is not sent to where they were last seen in the hangar")

	// On an arrest a beat officer rides to a hangar like anyone (police_arrest.dm route_to()): it is sent there
	qdel(unit)
	var/datum/outpost_police_case/case = police.open_case(warrant)
	TEST_ASSERT_NOTNULL(case, "Fixture: no arrest opened at two stars")
	TEST_ASSERT_EQUAL(case.arresting(), beat, "Fixture: the beat officer is not the arresting officer")
	TEST_ASSERT_EQUAL(police.search_place(warrant, beat), warrant.last_seen_turf, "The arresting officer is not sent to where the suspect was last seen in a hangar")
	police.close_case(suspect.mind)

	qdel(berth)
	outpost.berths = old_berths

/**
 * The last wanted person's stars fade while nobody at all is at the outpost (a suspect hiding with no client, or one
 * who left): the officer still searching for them stands down. The police's tick used to stop at the empty outpost
 * before the all clear and the officers' stand-downs, so it searched on.
 */
/datum/unit_test/voidcrew_stealth_live/police/search_ends_empty_outpost

/datum/unit_test/voidcrew_stealth_live/police/search_ends_empty_outpost/Run()
	TEST_ASSERT(police_room(40, 9), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(4, 4)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	var/mob/living/carbon/human/suspect = unseen_suspect(2, 4, 38, 7)
	var/datum/outpost_warrant/warrant = police.get_warrant(suspect.mind)
	officer.dispatch_mind = WEAKREF(suspect.mind)
	police.stealth_tick_officer(officer)
	police.stealth_tick_squad()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "Fixture: the officer sent after the suspect is not searching")
	TEST_ASSERT_EQUAL(brain.police_hunt?.resolve(), suspect.mind, "Fixture: the searching officer is not after the suspect")
	TEST_ASSERT(!length(police.dispatch_players_at_outpost()), "Fixture: someone with a client is at the outpost")
	// Sent back to its beat as one too many, then the stars fade with nobody about
	officer.dispatch_mind = null
	warrant.heat = 0
	police.tick_dispatch()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer searched on after the last wanted person's stars faded at an empty outpost")
	TEST_ASSERT_NULL(brain.police_hunt?.resolve(), "An officer kept hunting someone with no stars at an empty outpost")

/**
 * An officer's own bleeding (a wound from the fight it was in) is no harm to look round for: it used to go searching
 * and shout "Who threw that?" as it walked its prisoner to the cell, and searched on after the all clear. A blow it
 * feels land while it bleeds is still looked into.
 */
/datum/unit_test/voidcrew_stealth_live/police/own_bleed_no_search

/datum/unit_test/voidcrew_stealth_live/police/own_bleed_no_search/Run()
	TEST_ASSERT(police_room(8, 5), "No room for the test")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = officer_at(2, 2)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.stealth_setup()
	brain.stealth_ready = TRUE
	var/datum/wound/slash/flesh/severe/gash = new
	gash.apply_wound(officer.get_bodypart(BODY_ZONE_L_ARM), silent = TRUE)
	TEST_ASSERT(officer.get_bleed_rate() > 0, "Fixture: the officer is not bleeding")
	brain.harm_pending = FALSE
	brain.next_harm_at = 0
	brain.explained_at = 0
	brain.stealth_go_unaware()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "Fixture: the officer is not unaware")
	// Health slipping away as it bleeds (stealth_check_health())
	brain.stealth_note_harm(5 SECONDS, FALSE) // STEALTH_HARM_WINDOW
	brain.stealth_judge_harm()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "unaware", "An officer went searching because it was bleeding")
	TEST_ASSERT(!brain.harm_pending, "An officer's own bleeding left harm pending")
	// A blow it felt land, bleeding or not: it looks
	brain.stealth_note_harm()
	brain.stealth_judge_harm()
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "A bleeding officer did not look into a blow it could not name")
