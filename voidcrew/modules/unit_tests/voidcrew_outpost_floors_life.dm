/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P8.
 * Owner: P8. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * `floor.life_audience` stands in for the players who would see a visit (an empty list: nobody is there).
 */

/// A floor with a goods lift and a placed room on it, for the fitter tests. The room is a 4 x 4 walled box.
/datum/unit_test/voidcrew_outpost_floors/proc/life_floor_with_room(obj/structure/overmap/trader_outpost/outpost, list/room_out)
	var/datum/outpost_floor/floor = test_floor(outpost, 1, 20, 16, TRUE)
	if(!floor)
		return null
	floor.goods_turfs = list(floor_tile(floor, 15, 4), floor_tile(floor, 16, 4))
	var/turf/bottom_left = floor_tile(floor, 6, 7)
	var/turf/top_right = floor_tile(floor, 9, 10)
	for(var/turf/tile as anything in block(bottom_left.x, bottom_left.y, bottom_left.z, top_right.x, top_right.y, top_right.z))
		if(tile.x == bottom_left.x || tile.y == bottom_left.y || tile.x == top_right.x || tile.y == top_right.y)
			tile.ChangeTurf(/turf/closed/wall)
	var/datum/outpost_upgrade/room = new(floor.host)
	room.installed = TRUE
	room.footprint_bounds = list(bottom_left.x, bottom_left.y, top_right.x, top_right.y, bottom_left.z)
	room_out += room
	return floor

/// Fitters of `floor` alive now
/datum/unit_test/voidcrew_outpost_floors/proc/life_fitters(datum/outpost_floor/floor)
	. = 0
	if(!floor.life_place)
		return
	for(var/mob/living/carbon/human/npc/ambient_npc/npc as anything in floor.life_place.living_npcs())
		if(istype(npc, /mob/living/carbon/human/npc/ambient_npc/outpost/worker/floor_fitter))
			.++

/// Every floor gets a tenant from its own outpost's list, no two alike, and keeps it
/datum/unit_test/voidcrew_outpost_floors/life_tenant_names

/datum/unit_test/voidcrew_outpost_floors/life_tenant_names/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost(/obj/structure/overmap/trader_outpost/black_market)
	outpost.make_floors()
	outpost.name_tenants()
	var/list/allowed = floor_life_strings("tenants_black_market")
	TEST_ASSERT(length(allowed) >= 6, "The Undertow has a business for each of its six floors") // OUTPOST_FLOORS_PER_OUTPOST
	var/list/seen = list()
	var/list/first_names = list()
	for(var/datum/outpost_floor/floor in outpost.floors)
		TEST_ASSERT(istext(floor.tenant_name) && length(floor.tenant_name), "Floor [floor.number] has a tenant")
		TEST_ASSERT(floor.tenant_name in allowed, "Floor [floor.number]'s tenant is from the Undertow's own list")
		TEST_ASSERT(!seen[floor.tenant_name], "No two floors share a tenant")
		seen[floor.tenant_name] = TRUE
		first_names += floor.tenant_name
	outpost.name_tenants()
	for(var/i in 1 to length(outpost.floors))
		var/datum/outpost_floor/floor = outpost.floors[i]
		TEST_ASSERT_EQUAL(floor.tenant_name, first_names[i], "Naming again keeps floor [i]'s tenant")
	var/datum/outpost_floor/let_floor = outpost.floors[1]
	let_floor.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	TEST_ASSERT(!(let_floor.tenant_name in outpost.tenant_businesses()), "A let floor's old tenant is no longer one of the outpost's businesses")
	TEST_ASSERT_EQUAL(length(outpost.tenant_businesses()), length(outpost.floors) - 1, "The other floors are still let to their tenants")

/// Fitters come once for a placed room, and only while someone is upstairs
/datum/unit_test/voidcrew_outpost_floors/life_fitters_once

/datum/unit_test/voidcrew_outpost_floors/life_fitters_once/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/list/rooms = list()
	var/datum/outpost_floor/floor = life_floor_with_room(outpost, rooms)
	if(!floor)
		return
	var/datum/outpost_upgrade/room = rooms[1]
	var/mob/living/carbon/human/crew = test_person(deck_tile(floor, 3))
	floor.life_audience = list(crew)
	floor.on_room_placed(room)
	TEST_ASSERT_EQUAL(life_fitters(floor), 2, "Two fitters come up for a placed room") // OUTPOST_FLOOR_FITTERS
	for(var/mob/living/carbon/human/npc/ambient_npc/fitter as anything in floor.life_place.living_npcs())
		TEST_ASSERT(get_turf(fitter) in floor.goods_turfs, "A fitter steps off the goods lift")
	floor.on_room_placed(room)
	floor.life_tick()
	TEST_ASSERT_EQUAL(life_fitters(floor), 2, "Placing the same room again brings nobody more")
	QDEL_NULL(floor.life_place)
	floor.on_room_placed(room)
	floor.life_tick()
	TEST_ASSERT_EQUAL(life_fitters(floor), 0, "Killing or losing the fitters never brings them back for that room")
	TEST_ASSERT(!length(floor.life_visits), "Nothing is left waiting")
	QDEL_NULL(room)

/// Nothing comes with nobody there to see it, and nothing comes later for it
/datum/unit_test/voidcrew_outpost_floors/life_nobody_there

/datum/unit_test/voidcrew_outpost_floors/life_nobody_there/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/list/rooms = list()
	var/datum/outpost_floor/floor = life_floor_with_room(outpost, rooms)
	if(!floor)
		return
	var/datum/outpost_upgrade/room = rooms[1]
	var/mob/living/carbon/human/buyer = test_person(deck_tile(floor, 3))
	floor.life_audience = list()
	floor.on_let(buyer)
	TEST_ASSERT(!length(floor.life_visits), "No movers come with nobody on the concourse")
	floor.on_room_placed(room)
	TEST_ASSERT(!length(floor.life_visits), "No fitters come with nobody upstairs")
	TEST_ASSERT_EQUAL(life_fitters(floor), 0, "No fitter was made")
	floor.life_audience = list(buyer)
	floor.on_room_placed(room)
	TEST_ASSERT_EQUAL(life_fitters(floor), 0, "A room nobody saw placed brings no fitters later")
	// The note waits for the new holder whoever is about
	var/obj/item/paper/note
	for(var/turf/tile as anything in block(floor.bounds[1], floor.bounds[2], floor.bounds[5], floor.bounds[3], floor.bounds[4], floor.bounds[5]))
		note = locate(/obj/item/paper) in tile
		if(note)
			break
	TEST_ASSERT_NOTNULL(note, "A note from the outpost waits on the new floor")
	TEST_ASSERT(findtext(note?.get_raw_text(), buyer.real_name), "The note is to the new holder")
	QDEL_NULL(room)

/// Movers and fitters never take the outpost over its cap: when it is full, they wait while room is made
/datum/unit_test/voidcrew_outpost_floors/life_under_cap

/datum/unit_test/voidcrew_outpost_floors/life_under_cap/Run()
	var/cap = 8 // AMBIENT_OUTPOST_TRANSIENT_CAP
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/list/rooms = list()
	var/datum/outpost_floor/floor = life_floor_with_room(outpost, rooms)
	if(!floor)
		return
	var/datum/outpost_upgrade/room = rooms[1]
	var/datum/ambient_place/outpost/concourse = SSambient_npcs.outpost_place(outpost)
	var/list/locals = list()
	for(var/i in 1 to cap)
		var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/shopper = new(deck_tile(floor, 1 + (i % 3)))
		shopper.set_place(concourse)
		locals += shopper
	var/mob/living/carbon/human/crew = test_person(deck_tile(floor, 12))
	floor.life_audience = list(crew)
	floor.on_room_placed(room)
	TEST_ASSERT(floor_life_npc_count(outpost) <= cap, "A full outpost stays at its cap when fitters are due")
	TEST_ASSERT_EQUAL(life_fitters(floor), 0, "No fitter comes while the outpost is full")
	TEST_ASSERT(length(floor.life_visits), "The fitters wait for room")
	var/leaving = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/shopper as anything in locals)
		if(istype(shopper.activity, /datum/ambient_activity/leave))
			leaving++
	TEST_ASSERT_EQUAL(leaving, 2, "Two shoppers head off to make room, and no more")
	floor.life_tick()
	leaving = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/shopper as anything in locals)
		if(istype(shopper.activity, /datum/ambient_activity/leave))
			leaving++
	TEST_ASSERT_EQUAL(leaving, 2, "Waiting longer sends nobody more")
	// One shopper is gone: one fitter fits
	qdel(locals[1])
	floor.life_tick()
	TEST_ASSERT_EQUAL(life_fitters(floor), 1, "One fitter comes for the one free place")
	TEST_ASSERT(floor_life_npc_count(outpost) <= cap, "Still at the cap")
	qdel(locals[2])
	floor.life_tick()
	TEST_ASSERT_EQUAL(life_fitters(floor), 2, "The second follows when the next place frees")
	TEST_ASSERT(floor_life_npc_count(outpost) <= cap, "Still at the cap")
	TEST_ASSERT(!length(floor.life_visits), "Nothing is left waiting")
	for(var/mob/living/carbon/human/npc/ambient_npc/shopper as anything in locals)
		if(!QDELETED(shopper))
			qdel(shopper)
	QDEL_NULL(room)

/// The lift chimes on arrival, not on every rider's step; the buzzer sounds on the floor
/datum/unit_test/voidcrew_outpost_floors/life_chime_and_buzzer

/datum/unit_test/voidcrew_outpost_floors/life_chime_and_buzzer/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	floor.on_lift_arriving()
	var/chimed = floor.life_chimed_at
	TEST_ASSERT(chimed > 0, "The lift chimes when the car comes up")
	floor.on_lift_arriving()
	TEST_ASSERT_EQUAL(floor.life_chimed_at, chimed, "A second arrival at once does not chime again")
	var/obj/structure/outpost_floor_buzzer/buzzer = allocate(/obj/structure/outpost_floor_buzzer, deck_tile(floor, 4))
	buzzer.floor_ref = WEAKREF(floor)
	var/mob/living/carbon/human/visitor = test_person(deck_tile(floor, 5))
	floor.life_audience = list()
	TEST_ASSERT(buzzer.buzz(visitor), "The buzzer sounds")
	TEST_ASSERT(!buzzer.buzz(visitor), "Leaning on it does not")
