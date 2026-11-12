/**
 * Outpost floors (voidcrew/modules/trade_floors/): tests of package P14.
 * Owner: P14. Subtype /datum/unit_test/voidcrew_outpost_floors and use the helpers in
 * voidcrew_outpost_floors_helpers.dm (P0, frozen). Fork defines are included after the tests: write the literal
 * value with a comment naming the define. Pin other packages' outputs directly and never wait for an AI walk.
 *
 * The quarters, the workshop and the canteen (floor_base_rooms.dm) are placed for real, with place_outpost_upgrade(),
 * on a P0 test floor. The room style test (voidcrew_outpost_room_styles) also places them, in every turn, on a plain
 * claim: these check what is particular to a floor.
 *
 * What these lean on from other packages, so a failure can be traced:
 * - P4: the floor host's offers_upgrade() sells them, and its upgrade_footprint_near_outpost() lets a room go on a
 *   floor. At P0 alone the host refuses both, so base_rooms_catalogue and base_rooms_place fail until P4 is merged.
 */

/// P14's fixtures. It never runs.
/datum/unit_test/voidcrew_outpost_floors/base_rooms
	abstract_type = /datum/unit_test/voidcrew_outpost_floors/base_rooms
	/// The turfs of every room placed, so their air can settle before the ground goes
	var/list/turf/base_built = list()

/datum/unit_test/voidcrew_outpost_floors/base_rooms/Destroy()
	base_built.Cut()
	return ..()

/// The three rooms, id -> price (OUTPOST_FLOOR_QUARTERS_COST, OUTPOST_FLOOR_WORKSHOP_COST, OUTPOST_FLOOR_CANTEEN_COST)
/datum/unit_test/voidcrew_outpost_floors/base_rooms/proc/base_room_prices()
	return list("quarters" = 1500, "workshop" = 2500, "canteen" = 2000)

/**
 * Floor `number` of `outpost`, 30 by 14 with its host, owned by `owner_key` (a ckey with nobody behind it), loaded and
 * drawn in `style`. Its landing is at the middle of the south wall, well east of where base_place() puts a room.
 */
/datum/unit_test/voidcrew_outpost_floors/base_rooms/proc/base_floor(obj/structure/overmap/trader_outpost/outpost, number, owner_key, style)
	var/datum/outpost_floor/floor = test_floor(outpost, number, 30, 14, TRUE)
	if(!floor)
		return null
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	host.founder_ckey = owner_key
	host.founder_name = owner_key
	host.loaded = TRUE
	host.outpost_style = style
	return floor

/**
 * Places `upgrade_type`'s room unturned on `floor`, its footprint's bottom left at 1, 4 (rooms are 11 by 9, so it
 * stands against the west and north hull with three rows of deck under its door). The room, or the refusal as text.
 */
/datum/unit_test/voidcrew_outpost_floors/base_rooms/proc/base_place(datum/outpost_floor/floor, upgrade_type)
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/datum/outpost_upgrade/blueprint = new upgrade_type(host)
	host.outpost_upgrades[blueprint.key] = blueprint
	var/refusal = host.place_outpost_upgrade(blueprint, floor_tile(floor, 1, 4), 0, null)
	if(refusal)
		if(!QDELETED(blueprint))
			host.outpost_upgrades -= blueprint.key
			qdel(blueprint)
		return refusal
	var/list/footprint = blueprint.footprint_bounds
	base_built += block(footprint[1], footprint[2], footprint[5], footprint[3], footprint[4], footprint[5])
	return blueprint

/// The three rooms are in the catalogue at their prices, drawn in both styles, sold on a floor and nowhere else
/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_catalogue

/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_catalogue/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = base_floor(outpost, 1, "baseroomscatalogue", "clean") // OUTPOST_STYLE_CLEAN
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/obj/structure/overmap/dynamic/player_outpost/claim = new(null)
	made_hosts += claim
	var/list/prices = base_room_prices()
	for(var/room_id in prices)
		var/datum/outpost_upgrade/service/floor_room/room = GLOB.outpost_upgrade_catalog[room_id]
		if(!istype(room))
			TEST_FAIL("The [room_id] room is not in the catalogue as a floor room")
			continue
		TEST_ASSERT_EQUAL(room.price, prices[room_id], "The [room.name] has the wrong price")
		TEST_ASSERT(room.floors_only, "The [room.name] is not floors-only")
		TEST_ASSERT_NOTNULL(room.area_type, "The [room.name] has no area of its own")
		var/list/maps = outpost_style_maps(room.template_type)
		TEST_ASSERT_EQUAL(length(maps), 2, "The [room.name] is not drawn in exactly two styles")
		for(var/style in list("clean", "rundown")) // OUTPOST_STYLE_CLEAN, OUTPOST_STYLE_RUNDOWN
			var/datum/map_template/template = room.get_template(style = style)
			TEST_ASSERT_NOTNULL(template, "The [room.name] has no [style] map")
			if(template)
				TEST_ASSERT_EQUAL(template.width, 11, "The [style] [room.name] is not 11 wide")
				TEST_ASSERT_EQUAL(template.height, 9, "The [style] [room.name] is not 9 deep")
		TEST_ASSERT(host.offers_upgrade(room), "A floor does not sell the [room.name]")
		TEST_ASSERT(!claim.offers_upgrade(room), "A player outpost sells the [room.name]")
		TEST_ASSERT_NULL(room.purchase_requirement(host), "A floor may not buy the [room.name]")
		TEST_ASSERT_NOTNULL(room.purchase_requirement(claim), "A player outpost may buy the [room.name]")

/// Each room places on a floor in both styles, keeps its contract and is outpost property throughout
/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_place

/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_place/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/number = 0
	for(var/style in list("clean", "rundown")) // OUTPOST_STYLE_CLEAN, OUTPOST_STYLE_RUNDOWN
		for(var/room_id in base_room_prices())
			number++
			var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[room_id]
			if(!prototype)
				TEST_FAIL("The [room_id] room is not in the catalogue")
				continue
			var/datum/outpost_floor/floor = base_floor(outpost, number, "baseroomsplace[number]", style)
			if(!floor)
				continue
			var/result = base_place(floor, prototype.type)
			if(!istype(result, /datum/outpost_upgrade))
				TEST_FAIL("The [style] [prototype.name] could not be placed on a floor: [result]")
				continue
			var/datum/outpost_upgrade/service/room = result
			TEST_ASSERT(room.installed, "The [style] [room.name] is not installed")
			TEST_ASSERT(istype(room.installed_area, room.area_type), "The [style] [room.name] has no area of its own")
			for(var/problem in room.contract_problems())
				TEST_FAIL("The [style] [room.name] on a floor: [problem]")
			// The quarters and the workshop are the crew's own; the canteen takes customers
			var/wanted_access = (room_id == "canteen") ? null : "members" // OUTPOST_DOOR_MEMBERS
			for(var/datum/weakref/door_ref as anything in room.doors)
				var/obj/machinery/door/door = door_ref.resolve()
				var/datum/component/outpost_door_access/lock = door?.GetComponent(/datum/component/outpost_door_access)
				TEST_ASSERT_EQUAL(lock?.access, wanted_access, "The [style] [room.name]'s door does not start at [wanted_access || "public"]")
			for(var/turf/tile as anything in room.room_turfs())
				if(get_outpost_floor_for_turf(tile) != floor)
					TEST_FAIL("The [style] [room.name] runs off its floor at [tile.x],[tile.y]")
					break
				for(var/obj/fixture in tile)
					if(!ismachinery(fixture) && !isstructure(fixture))
						continue
					// Outpost cable protects itself (outpost_room_power.dm)
					if(istype(fixture, /obj/structure/cable))
						continue
					if(!HAS_TRAIT(fixture, "outpost_property")) // TRAIT_OUTPOST_PROPERTY
						TEST_FAIL("The [fixture.name] in the [style] [room.name] at [tile.x],[tile.y] is not outpost property")
					if(isstructure(fixture) && !fixture.anchored)
						TEST_FAIL("The [fixture.name] in the [style] [room.name] at [tile.x],[tile.y] is not bolted down")
	settle_room_air(base_built)

/// The quarters' two cryopods take residents for the floor they stand on
/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_quarters_pods

/datum/unit_test/voidcrew_outpost_floors/base_rooms/base_rooms_quarters_pods/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = base_floor(outpost, 1, "baseroomspods", "rundown") // OUTPOST_STYLE_RUNDOWN
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/pods_before = length(host.resident_pods)
	var/result = base_place(floor, /datum/outpost_upgrade/service/floor_room/quarters)
	if(!istype(result, /datum/outpost_upgrade/service/floor_room/quarters))
		TEST_FAIL("The quarters could not be placed on a floor: [result]")
		return
	var/datum/outpost_upgrade/service/floor_room/quarters/quarters = result
	var/list/pods = quarters.room_pods()
	TEST_ASSERT_EQUAL(length(pods), 2, "The quarters do not hold two cryopods")
	TEST_ASSERT_EQUAL(length(host.resident_pods), pods_before + 2, "The quarters' cryopods did not join the floor's resident pods")
	for(var/obj/machinery/cryopod/pod as anything in pods)
		TEST_ASSERT_EQUAL(pod.linked_outpost, host, "A quarters cryopod is not linked to its floor")
		TEST_ASSERT(pod in host.resident_pods, "A quarters cryopod takes no resident arrivals")
		TEST_ASSERT_NULL(pod.linked_ship, "A quarters cryopod is linked to a ship")
	for(var/turf/tile as anything in quarters.room_turfs())
		for(var/obj/structure/closet/secure_closet/personal/bunk/locker in tile)
			TEST_ASSERT(!length(locker.contents), "A bunk locker in the quarters came with something in it")
	settle_room_air(base_built)
	// A pod that goes stops taking arrivals
	var/obj/machinery/cryopod/gone = pods[1]
	qdel(gone)
	TEST_ASSERT(!(gone in host.resident_pods), "A deleted quarters cryopod still takes resident arrivals")
	TEST_ASSERT_EQUAL(length(quarters.room_pods()), 1, "The quarters still count a deleted cryopod")
