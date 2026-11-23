/**
 * The outpost's own people at the checkpoint's doors and at doors in general (voidcrew/modules/trade/
 * outpost_checkpoint_npcs.dm, voidcrew/modules/ambient_npcs/outpost_doorways.dm): a place in the chamber is kept for
 * each of them before they set off for it, the tile furthest in first; with no place they wait in the lobby; nobody
 * stands in a doorway (two seconds is the most anyone may be seen in one: OUTPOST_DOORWAY_LINGER is 1.5).
 *
 * These run the NPCs' real AI and real walking in a walled fixture with room to walk (queue_fixture()). Its chamber is
 * two tiles, as the base fixture's: the one between the doors, and one beside it. Defines are included after the
 * tests, so values are written out with a comment naming them.
 */

/datum/unit_test/voidcrew_trader_checkpoint/queue
	abstract_type = /datum/unit_test/voidcrew_trader_checkpoint/queue
	/// Someone on SSmobs' list of players, so the NPCs' AI runs -> the z-level they were listed on
	var/list/listed = list()
	/// REF of each watched NPC -> how long they have stood in a doorway now, and the longest they ever did
	var/list/doorway_run = list()
	var/list/doorway_worst = list()

/datum/unit_test/voidcrew_trader_checkpoint/queue/Destroy()
	for(var/mob/living/person as anything in listed)
		SSmobs.clients_by_zlevel[listed[person]] -= person
	listed = null
	return ..()

/// The fixture tile `dx`, `dy` from the inside corner of its walls
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/spot(dx, dy)
	return locate(host.template_bottom_left.x + 1 + dx, host.template_bottom_left.y + 1 + dy, host.template_bottom_left.z)

/**
 * A walled fixture, seven wide inside: a lobby two deep (rows 0 and 1), the outer door at 3,2, the chamber at 3,3
 * (between the doors) and 4,3 (beside it), the inner door at 3,4, and a concourse six deep (rows 5 to 10). Its floor
 * is the outpost's, the outpost counts as having someone on it, and someone listed as a player keeps the NPCs' AI on.
 */
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/queue_fixture()
	host = allocate(/obj/structure/overmap/trader_outpost/general)
	host.outpost_template = new /datum/map_template/trader_outpost
	host.outpost_template.width = 9
	host.outpost_template.height = 13
	host.reservation = SSmapping.request_turf_block_reservation(9, 13, 1)
	TEST_ASSERT_NOTNULL(host.reservation, "Could not reserve the checkpoint fixture")
	host.template_bottom_left = host.reservation.bottom_left_turfs[1]
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(host)
	place.occupied = TRUE
	place.public_floor = list()
	for(var/dx in -1 to 7)
		for(var/dy in -1 to 11)
			var/turf/tile = spot(dx, dy)
			var/inside = dx >= 0 && dx <= 6 && dy >= 0 && dy <= 10
			var/open = inside && (dy <= 1 || dy >= 5 || dx == 3 || (dx == 4 && dy == 3))
			tile = tile.ChangeTurf(open ? /turf/open/indestructible : /turf/closed/indestructible)
			put_in_area(tile, dy >= 5 ? /area/voidcrew/trader_outpost : /area/voidcrew/trader_outpost/checkpoint)
			if(open && dy >= 5)
				place.public_floor[tile] = TRUE
	place.floor_built_at = world.time
	lobby = spot(3, 1)
	secured = spot(3, 5)
	chamber = list(spot(3, 3), spot(4, 3))
	outer = allocate(/obj/machinery/door/airlock/outpost/checkpoint/outer, spot(3, 2))
	outer.checkpoint_id = "test_checkpoint"
	outer.set_machine_stat(NONE)
	inner = allocate(/obj/machinery/door/airlock/outpost/checkpoint/inner, spot(3, 4))
	inner.checkpoint_id = "test_checkpoint"
	inner.set_machine_stat(NONE)
	for(var/turf/tile as anything in chamber)
		var/obj/effect/landmark/outpost_checkpoint_chamber/marker = allocate(/obj/effect/landmark/outpost_checkpoint_chamber, tile)
		marker.checkpoint_id = "test_checkpoint"
	sensor = allocate(/obj/machinery/outpost_checkpoint_sensor/directional/west, chamber[1])
	sensor.checkpoint_id = "test_checkpoint"
	guard = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/halcyon, spot(6, 10))
	guard.checkpoint_id = "test_checkpoint"
	host.link_interior_machinery()
	checkpoint = host.checkpoints["test_checkpoint"]
	TEST_ASSERT_NOTNULL(checkpoint, "The fixture checkpoint did not assemble")
	TEST_ASSERT_EQUAL(checkpoint.lobby_turf, lobby, "The outer door's far side is not the lobby")
	TEST_ASSERT_EQUAL(checkpoint.secured_turf, secured, "The inner door's far side is not the concourse")
	TEST_ASSERT_EQUAL(length(checkpoint.chamber_turfs), 2, "The chamber is not its two marked tiles")
	// Out of everyone's way, in the concourse's far corner
	var/mob/living/carbon/human/consistent/watcher = allocate(/mob/living/carbon/human/consistent, spot(0, 10))
	watcher.AddElement(/datum/element/forced_gravity, 1)
	var/turf/where = get_turf(watcher)
	SSmobs.clients_by_zlevel[where.z] += watcher
	listed[watcher] = where.z
	return TRUE

/// A customer at `where`, one of the outpost's people. `awake`: their AI runs.
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/customer(turf/where, awake = TRUE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, where)
	npc.AddElement(/datum/element/forced_gravity, 1)
	npc.set_place(SSambient_npcs.outpost_place(host))
	if(awake)
		// No client is near (the watcher is only on the list of players): they would idle, and an idle NPC does nothing
		npc.ai_controller?.can_idle = FALSE
		npc.ai_controller?.reset_ai_status()
	else
		npc.ai_controller?.set_ai_status(AI_STATUS_OFF)
	return npc

/// Someone who only stands there (no AI of their own)
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/bystander(turf/where)
	var/mob/living/carbon/human/consistent/person = allocate(/mob/living/carbon/human/consistent, where)
	person.AddElement(/datum/element/forced_gravity, 1)
	return person

/// Opens the outer door and keeps it open (its closing timer is taken off)
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/hold_outer_open()
	checkpoint.request_outer(visitor(spot(0, 0)))
	sleep(2 SECONDS)
	deltimer(checkpoint.phase_timer)
	checkpoint.phase_timer = null
	return !outer.density

/// One tick of watching `people`: counts how long each stands in a doorway
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/watch_doorways(list/people)
	for(var/mob/living/person as anything in people)
		if(QDELETED(person))
			continue
		var/key = REF(person)
		if(isturf(person.loc) && (locate(/obj/machinery/door/airlock) in person.loc))
			doorway_run[key] += world.tick_lag
			doorway_worst[key] = max(doorway_worst[key], doorway_run[key])
		else
			doorway_run[key] = 0

/// The longest anyone watched stood in a doorway, in deciseconds
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/longest_in_doorway()
	. = 0
	for(var/key in doorway_worst)
		. = max(., doorway_worst[key])

/// "dx,dy" of `thing` in the fixture, for a failure message
/datum/unit_test/voidcrew_trader_checkpoint/queue/proc/where_is(atom/thing)
	var/turf/where = get_turf(thing)
	if(!where)
		return "gone"
	return "[where.x - host.template_bottom_left.x - 1],[where.y - host.template_bottom_left.y - 1]"

// ===== A PLACE EACH =====

/// The chamber fills from the far end; nobody is given a place they cannot walk to or one someone else is on their way to; someone caught in the outer doorway with no place is sent back out, an officer too
/datum/unit_test/voidcrew_trader_checkpoint/queue/places

/datum/unit_test/voidcrew_trader_checkpoint/queue/places/Run()
	TEST_ASSERT(queue_fixture(), "Could not prepare the checkpoint")
	var/turf/between_doors = chamber[1]
	var/turf/beside = chamber[2]
	var/turf/outer_turf = get_turf(outer)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/first = customer(lobby, FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/second = customer(spot(2, 1), FALSE)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/third = customer(spot(4, 1), FALSE)

	// The far tile first: the one between the doors is the only way to it
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, first), beside, "The first one in was not sent to the far tile of the chamber")
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, first), beside, "Asked again, the first one in was given another place")
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, second), between_doors, "The second one in was not given the tile left")
	TEST_ASSERT_NULL(outpost_checkpoint_chamber_entry(checkpoint, third), "A third was given a place in a chamber of two tiles")

	// Someone standing just inside the door: nobody can walk past them, so nobody is sent in
	checkpoint.chamber_places = null
	checkpoint.chamber_places_at = null
	var/mob/living/carbon/human/blocker = bystander(between_doors)
	TEST_ASSERT_NULL(outpost_checkpoint_chamber_entry(checkpoint, first), "Someone was sent in past a person standing just inside the outer door")
	blocker.forceMove(beside)
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, first), between_doors, "With the far tile taken, the tile between the doors was not given")
	TEST_ASSERT_NULL(outpost_checkpoint_chamber_entry(checkpoint, second), "The last place in the chamber was given twice")

	// A place nobody asks for any more is free again (OUTPOST_CHECKPOINT_NPC_PLACE_TIME is 4 seconds)
	checkpoint.chamber_places_at[between_doors] = world.time - 5 SECONDS
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, second), between_doors, "A place nobody asked for in five seconds was still kept")

	// Inside, on the tile between the doors, with the far tile free: further in, out of the next one's way
	checkpoint.chamber_places = null
	checkpoint.chamber_places_at = null
	blocker.forceMove(spot(0, 1))
	first.forceMove(between_doors)
	TEST_ASSERT_EQUAL(outpost_checkpoint_chamber_entry(checkpoint, first), beside, "Someone standing just inside the outer door, the far tile free, was not sent further in")
	first.forceMove(lobby)

	// In the outer doorway with no place to be had: back out to the lobby, never a wait in the door
	checkpoint.chamber_places = null
	checkpoint.chamber_places_at = null
	blocker.forceMove(beside)
	var/mob/living/carbon/human/other_blocker = bystander(between_doors)
	TEST_ASSERT(hold_outer_open(), "Setup: the outer door did not open")
	first.forceMove(outer_turf)
	ambient_cross_checkpoint_on_arrival(first, host)
	var/datum/ambient_activity/cross_checkpoint/crossing = first.activity
	TEST_ASSERT(istype(crossing), "Setup: someone in the doorway did not set off through the checkpoint")
	TEST_ASSERT_EQUAL(first.activity_step(1), 1, "Someone in the outer doorway of a full chamber waited there") // AMBIENT_STEP_MOVE
	TEST_ASSERT_EQUAL(crossing.spot, lobby, "Someone in the outer doorway of a full chamber was not sent back out to the lobby")
	first.end_activity()
	first.forceMove(spot(0, 1))

	// An officer the same
	host.ensure_police()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, outer_turf)
	cop.ai_controller?.set_ai_status(AI_STATUS_OFF)
	host.police.add_officer(cop)
	TEST_ASSERT_EQUAL(host.police.checkpoint_step_to_concourse(cop), lobby, "An officer in the outer doorway of a full chamber was not sent back out to the lobby")
	// With room, on in
	qdel(other_blocker)
	TEST_ASSERT_EQUAL(host.police.checkpoint_step_to_concourse(cop), between_doors, "An officer in the outer doorway was not sent on in to the free tile")
	host.police.clear_checkpoint_crossing(cop)

// ===== THE WHOLE WALK =====

/// Three of them off the lift at once, a chamber of two tiles: all three are through in good time, and nobody stands in a doorway on the way
/datum/unit_test/voidcrew_trader_checkpoint/queue/three_arrive

/datum/unit_test/voidcrew_trader_checkpoint/queue/three_arrive/Run()
	TEST_ASSERT(queue_fixture(), "Could not prepare the checkpoint")
	var/list/crowd = list(customer(spot(3, 0)), customer(spot(2, 0)), customer(spot(4, 0)))
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in crowd)
		ambient_cross_checkpoint_on_arrival(npc, host)
		TEST_ASSERT(istype(npc.activity, /datum/ambient_activity/cross_checkpoint), "Setup: someone off the lift did not set off through the checkpoint")
	var/list/through = list()
	var/most_inside = 0
	var/deadline = world.time + 75 SECONDS
	while(world.time < deadline && length(through) < 3)
		sleep(world.tick_lag)
		watch_doorways(crowd)
		var/inside = 0
		for(var/mob/living/npc as anything in crowd)
			if(QDELETED(npc))
				continue
			if(npc.loc in chamber)
				inside++
			else if(host.is_secured_turf(get_turf(npc)))
				through |= npc
		most_inside = max(most_inside, inside)
	var/list/where = list()
	for(var/mob/living/npc as anything in crowd)
		where += where_is(npc)
	TEST_ASSERT_EQUAL(length(through), 3, "Only [length(through)] of three got through the checkpoint in 75 seconds (they are at [where.Join(" ")], [most_inside] at most in the chamber, checkpoint [checkpoint.state], outer door [outer.density ? "shut" : "open"])")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "Someone stood in a doorway for [longest_in_doorway() / 10] seconds on the way through")

/**
 * A full chamber and one more arriving, the outer door open: they wait in the lobby, off the door tile, and go in
 * when a tile is free. And one already on their way in when someone steps into their way turns back at the door.
 */
/datum/unit_test/voidcrew_trader_checkpoint/queue/full_chamber

/datum/unit_test/voidcrew_trader_checkpoint/queue/full_chamber/Run()
	TEST_ASSERT(queue_fixture(), "Could not prepare the checkpoint")
	var/turf/between_doors = chamber[1]
	var/turf/beside = chamber[2]
	var/turf/outer_turf = get_turf(outer)
	var/mob/living/carbon/human/far_one = bystander(beside)
	var/mob/living/carbon/human/near_one = bystander(between_doors)
	TEST_ASSERT(hold_outer_open(), "Setup: the outer door did not open")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/late = customer(spot(3, 0))
	ambient_cross_checkpoint_on_arrival(late, host)
	var/list/watched = list(late)
	var/deadline = world.time + 12 SECONDS
	while(world.time < deadline)
		sleep(world.tick_lag)
		watch_doorways(watched)
	TEST_ASSERT(late.loc != outer_turf, "With the chamber full, the one arriving stands in the outer doorway")
	TEST_ASSERT(!(late.loc in chamber), "Setup: the one arriving is in a full chamber")
	TEST_ASSERT(get_dist(late, lobby) <= 1, "With the chamber full, the one arriving is not waiting by the outer door (at [where_is(late)])")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "With the chamber full, the one arriving stood in a doorway for [longest_in_doorway() / 10] seconds")

	// A tile comes free: in they go
	qdel(near_one)
	deadline = world.time + 15 SECONDS
	while(world.time < deadline && late.loc != between_doors)
		sleep(world.tick_lag)
		watch_doorways(watched)
	TEST_ASSERT_EQUAL(late.loc, between_doors, "With a tile free again, the one waiting did not go in (at [where_is(late)])")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "Going in, they stood in a doorway for [longest_in_doorway() / 10] seconds")

	// On their way in when someone steps into the way: they turn back at the door
	late.end_activity()
	late.forceMove(spot(3, 0))
	qdel(far_one)
	var/mob/living/carbon/human/in_the_way = bystander(spot(6, 1))
	ambient_cross_checkpoint_on_arrival(late, host)
	var/datum/ambient_activity/cross_checkpoint/crossing = late.activity
	TEST_ASSERT(istype(crossing), "Setup: the one arriving did not set off through the checkpoint again")
	deadline = world.time + 15 SECONDS
	var/set_off = FALSE
	while(world.time < deadline)
		sleep(world.tick_lag)
		watch_doorways(watched)
		// The moment they are in front of the door, headed for the chamber, someone is standing just inside it
		if(!set_off && late.activity == crossing && (crossing.spot in chamber) && late.loc == lobby)
			set_off = TRUE
			in_the_way.forceMove(between_doors)
			deadline = world.time + 8 SECONDS
	TEST_ASSERT(set_off, "Setup: the one arriving never set off for the chamber (at [where_is(late)])")
	TEST_ASSERT(late.loc != outer_turf, "Their way in taken as they walked up, they stand in the outer doorway")
	TEST_ASSERT(!(late.loc in chamber), "Setup: they got in past someone standing just inside the door")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "Their way in taken as they walked up, they stood in a doorway for [longest_in_doorway() / 10] seconds")

// ===== ANY DOOR =====

/// At a walk nobody of the outpost's steps into a doorway with someone standing just beyond it; one left standing in a doorway steps off it
/datum/unit_test/voidcrew_trader_checkpoint/queue/doorways

/datum/unit_test/voidcrew_trader_checkpoint/queue/doorways/Run()
	TEST_ASSERT(queue_fixture(), "Could not prepare the checkpoint")
	// A plain airlock across the lobby: a wall on the row above it, the lobby's west end one side and its east end the other
	var/turf/door_turf = spot(3, 0)
	var/turf/west = spot(2, 0)
	var/turf/east = spot(4, 0)
	var/turf/above = spot(3, 1)
	above.ChangeTurf(/turf/closed/indestructible)
	var/obj/machinery/door/airlock/door = allocate(/obj/machinery/door/airlock, door_turf)
	door.set_machine_stat(NONE)
	door.open(BYPASS_DOOR_CHECKS)
	sleep(1 SECONDS)
	TEST_ASSERT(!door.density, "Setup: the plain airlock is not open")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/walker = customer(west, FALSE)
	var/mob/living/carbon/human/standing = bystander(east)

	// Someone stands beyond the door: no step into the doorway
	walker.Move(door_turf, EAST)
	TEST_ASSERT_EQUAL(walker.loc, west, "At a walk, someone stepped into a doorway with a person standing just beyond it")
	// Nobody beyond: in they step
	standing.forceMove(spot(6, 0))
	walker.Move(door_turf, EAST)
	TEST_ASSERT_EQUAL(walker.loc, door_turf, "Someone would not step into an empty doorway")
	// Left standing in it: off it again, on the way they were going (OUTPOST_DOORWAY_LINGER is 1.5 seconds)
	sleep(2.5 SECONDS)
	TEST_ASSERT_EQUAL(walker.loc, east, "Someone left standing in a doorway did not step on through it")
	// Put in it (shoved, dragged), one side taken: off it to the side they belong on
	walker.forceMove(west)
	standing.forceMove(east)
	walker.forceMove(door_turf)
	sleep(2.5 SECONDS)
	TEST_ASSERT_EQUAL(walker.loc, west, "Someone put in a doorway did not step off it to the free side")
	// Running, they go where they must
	walker.set_pace(TRUE)
	walker.Move(door_turf, EAST)
	TEST_ASSERT_EQUAL(walker.loc, door_turf, "Someone running would not step into a doorway")
	walker.set_pace(FALSE)
	// In cuffs, they are not theirs to move
	ADD_TRAIT(walker, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	sleep(2.5 SECONDS)
	TEST_ASSERT_EQUAL(walker.loc, door_turf, "Someone in cuffs walked off a doorway by themselves")
	REMOVE_TRAIT(walker, TRAIT_RESTRAINED, TRAIT_SOURCE_UNIT_TESTS)
	sleep(2.5 SECONDS)
	TEST_ASSERT(walker.loc != door_turf, "Free again, they went on standing in the doorway")

// ===== THE THREE OUTPOSTS =====

/**
 * On a real outpost's map: more people than its chamber holds come off the lift at once, with two officers among
 * them, and all of them get through to the concourse in good time without anyone standing in a doorway; then some
 * of them leave again by the exit gate, and nobody stands in a doorway or in the gate on the way out.
 */
/datum/unit_test/voidcrew_trader_checkpoint_maps
	abstract_type = /datum/unit_test/voidcrew_trader_checkpoint_maps
	/// The outpost whose map is walked
	var/outpost_type
	/// Someone on SSmobs' list of players, so the NPCs' AI runs -> the z-level they were listed on
	var/list/listed = list()
	/// REF of each watched NPC -> how long they have stood in a doorway or an exit gate now, and the longest they ever did
	var/list/doorway_run = list()
	var/list/doorway_worst = list()

/datum/unit_test/voidcrew_trader_checkpoint_maps/Destroy()
	for(var/mob/living/person as anything in listed)
		SSmobs.clients_by_zlevel[listed[person]] -= person
	listed = null
	return ..()

/// One tick of watching `people`: counts how long each stands in a doorway or in an exit gate
/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/watch_doorways(list/people)
	for(var/mob/living/person as anything in people)
		if(QDELETED(person))
			continue
		var/key = REF(person)
		if(isturf(person.loc) && ((locate(/obj/machinery/door/airlock) in person.loc) || (locate(/obj/structure/outpost_exit_gate) in person.loc)))
			doorway_run[key] += world.tick_lag
			doorway_worst[key] = max(doorway_worst[key], doorway_run[key])
		else
			doorway_run[key] = 0

/// The longest anyone watched stood in a doorway or a gate, in deciseconds
/datum/unit_test/voidcrew_trader_checkpoint_maps/proc/longest_in_doorway()
	. = 0
	for(var/key in doorway_worst)
		. = max(., doorway_worst[key])

/datum/unit_test/voidcrew_trader_checkpoint_maps/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
	if(!outpost)
		return
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	SSambient_npcs.wake_outpost(place)
	TEST_ASSERT(length(outpost.lobby_alcove_turfs), "[outpost_type] has no lift alcove in its lobby")
	var/turf/alcove = outpost.lobby_alcove_turfs[1]
	var/datum/outpost_checkpoint/post = outpost.lobby_checkpoint(alcove)
	TEST_ASSERT_NOTNULL(post, "[outpost_type] has no checkpoint in from its lift lobby")
	var/turf/outer_turf = get_turf(post.outer_door)
	var/turf/inner_turf = get_turf(post.inner_door)
	// Someone on the concourse, as a player there: the place is awake
	var/mob/living/carbon/human/consistent/watcher = allocate(/mob/living/carbon/human/consistent, police_floor(outpost))
	var/turf/watcher_turf = get_turf(watcher)
	TEST_ASSERT_NOTNULL(watcher_turf, "[outpost_type] has no free floor on its concourse")
	SSmobs.clients_by_zlevel[watcher_turf.z] += watcher
	listed[watcher] = watcher_turf.z

	// The lobby's free floor near the outer door, nearest first: where the crowd starts, as a lift load does
	var/list/turf/start_tiles = list()
	for(var/reach in 2 to 6)
		for(var/turf/open/tile in RANGE_TURFS(reach, post.lobby_turf))
			if((tile in start_tiles) || tile == post.lobby_turf || get_dist(tile, post.lobby_turf) < 2)
				continue
			if(!istype(tile.loc, /area/voidcrew/trader_outpost/checkpoint) || (tile in post.chamber_turfs) || tile.is_blocked_turf(exclude_mobs = FALSE))
				continue
			if((locate(/obj/machinery/door) in tile) || (locate(/obj/structure/outpost_exit_gate) in tile) || !can_see(post.lobby_turf, tile, reach + 1))
				continue
			start_tiles += tile
	var/wanted = length(post.chamber_turfs) + 3
	TEST_ASSERT(length(start_tiles) >= wanted + 2, "[outpost_type]'s lobby has only [length(start_tiles)] free tiles by its outer door for [wanted + 2] people")

	var/list/crowd = list()
	for(var/i in 1 to wanted)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/npc = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, start_tiles[i])
		npc.set_place(place)
		// No client is near (the watcher is only on the list of players): they would idle, and an idle NPC does nothing
		npc.ai_controller?.can_idle = FALSE
		npc.ai_controller?.reset_ai_status()
		ambient_cross_checkpoint_on_arrival(npc, outpost)
		TEST_ASSERT(istype(npc.activity, /datum/ambient_activity/cross_checkpoint), "[outpost_type]: someone in the lobby did not set off through the checkpoint")
		crowd += npc
	// Two officers off the same lift, sent to look at a spot on the concourse
	var/list/officers = list()
	for(var/i in 1 to 2)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer/cop = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, start_tiles[wanted + i])
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = cop.ai_controller
		brain.reset_ai_status()
		brain.stealth_setup()
		brain.stealth_go_searching(post.secured_turf)
		officers += cop
	var/list/everyone = crowd + officers

	var/list/through = list()
	var/most_inside = 0
	var/deadline = world.time + 150 SECONDS
	while(world.time < deadline && length(through) < length(everyone))
		sleep(world.tick_lag)
		watch_doorways(everyone)
		var/inside = 0
		for(var/mob/living/person as anything in everyone)
			if(QDELETED(person))
				continue
			if(person.loc in post.chamber_turfs)
				inside++
			else if(outpost.is_secured_turf(get_turf(person)))
				through |= person
		most_inside = max(most_inside, inside)
	var/list/stuck = list()
	for(var/mob/living/person as anything in everyone)
		if(!(person in through))
			var/turf/where = get_turf(person)
			stuck += "[person.type] at [where ? "[where.x - outer_turf.x],[where.y - outer_turf.y] from the outer door" : "nowhere"]"
	TEST_ASSERT(!length(stuck), "[outpost_type]: [length(stuck)] of [length(everyone)] did not get through the checkpoint in 150 seconds: [stuck.Join("; ")] (checkpoint [post.state], outer door [post.outer_door.density ? "shut" : "open"], [most_inside] at most in the chamber)")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "[outpost_type]: on the way in someone stood in a doorway for [longest_in_doorway() / 10] seconds")
	TEST_ASSERT(most_inside <= length(post.chamber_turfs), "[outpost_type]: [most_inside] people were in a chamber of [length(post.chamber_turfs)] tiles")

	// Out again: three of them leave for the lift, by the exit gate
	var/list/leaving = list()
	for(var/i in 1 to 3)
		var/mob/living/carbon/human/npc/ambient_npc/npc = crowd[i]
		if(QDELETED(npc))
			continue
		TEST_ASSERT(npc.start_activity(new /datum/ambient_activity/leave(npc)), "[outpost_type]: someone on the concourse could not be sent off")
		leaving += npc
	deadline = world.time + 150 SECONDS
	var/still_in = length(leaving)
	while(world.time < deadline && still_in)
		sleep(world.tick_lag)
		watch_doorways(leaving)
		still_in = 0
		for(var/mob/living/npc as anything in leaving)
			if(!QDELETED(npc) && outpost.is_secured_turf(get_turf(npc)))
				still_in++
	TEST_ASSERT(!still_in, "[outpost_type]: [still_in] of [length(leaving)] people leaving were still on the concourse after 150 seconds")
	TEST_ASSERT(longest_in_doorway() <= 2 SECONDS, "[outpost_type]: on the way out someone stood in a doorway or in the exit gate for [longest_in_doorway() / 10] seconds")
	// Nobody was left standing in either door of the chamber
	for(var/mob/living/person in outer_turf)
		TEST_FAIL("[outpost_type]: [person.type] is standing in the checkpoint's outer doorway at the end")
	for(var/mob/living/person in inner_turf)
		TEST_FAIL("[outpost_type]: [person.type] is standing in the checkpoint's inner doorway at the end")

/datum/unit_test/voidcrew_trader_checkpoint_maps/halcyon
	outpost_type = /obj/structure/overmap/trader_outpost/general

/datum/unit_test/voidcrew_trader_checkpoint_maps/quartermain
	outpost_type = /obj/structure/overmap/trader_outpost/outfitter

/datum/unit_test/voidcrew_trader_checkpoint_maps/undertow
	outpost_type = /obj/structure/overmap/trader_outpost/black_market
