/**
 * Working NPCs (outpost_ambient_work.dm): the ship bay droids (outpost_yard_droids.dm) and the
 * trader outposts' mechanics (outpost_amenities.dm).
 *
 * Voidcrew defines are not visible from test files: a worker's range is 6 tiles, a bay's landing
 * pad is at most 56 by 40 (RESERVE_DOCK_MAX_SIZE_LONG by RESERVE_DOCK_MAX_SIZE_SHORT) and workers
 * keep 2 tiles clear of it (OUTPOST_WORK_PAD_MARGIN).
 */

/// Every droid in each ship bay keeps to its own side room, clear of the docking floor: never onto
/// the pad or the open hangar floor joined to it, through a door, onto the lift or out of its area.
/// It walks, it finds work, nothing moves it off its room, and it is still there and still working
/// after a real visit: its AI running with a player near, a hull landing, staying and leaving.
/datum/unit_test/voidcrew_outpost_yard_droids
	parent_type = /datum/unit_test/voidcrew_outpost_management
	/// Hulls landed in the bays, deleted before their bays are
	var/list/obj/structure/overmap/ship/test_ships = list()
	/// Stand-ins for players, counted on their level so the droids' AI runs
	var/list/mob/living/present = list()

/datum/unit_test/voidcrew_outpost_yard_droids/Destroy()
	for(var/mob/living/someone as anything in present)
		for(var/level in 1 to length(SSmobs.clients_by_zlevel))
			SSmobs.clients_by_zlevel[level] -= someone
	present = null
	for(var/obj/structure/overmap/ship/ship as anything in test_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_outpost_yard_droids/Run()
	for(var/datum/map_template/bay_type as anything in outpost_style_maps(/datum/map_template/outpost_hangar/ship_bay))
		check_bay(bay_type)

/datum/unit_test/voidcrew_outpost_yard_droids/proc/check_bay(datum/map_template/bay_type)
	var/style = initial(bay_type.outpost_style)
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("yarddroids[style]")
	TEST_ASSERT_NOTNULL(home, "The [style] droid test claim did not load")
	home.outpost_style = style
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The [style] ship bay did not load")
	var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
	TEST_ASSERT(bay?.dock, "The [style] ship bay has no dock")
	var/list/droids = bay_droids(bay)
	// The Grease Pit's six are mapped; the clean bay's are up to its mapper
	var/least = bay_type == /datum/map_template/outpost_hangar/ship_bay/rundown ? 6 : 1
	TEST_ASSERT(length(droids) >= least, "The [style] bay has [length(droids)] working droids, not [least]")
	var/list/floor = docking_floor(bay)
	var/list/near_pad = pad_surrounds(bay)
	for(var/obj/structure/outpost_yard_droid/droid as anything in droids)
		check_droid(droid, floor, near_pad, bay.alcove_turfs, style)

	// A visit: a player comes down the lift, so every droid's AI runs
	var/list/tracked = list()
	for(var/obj/structure/outpost_yard_droid/droid as anything in droids)
		tracked[WEAKREF(droid)] = "The [style] bay's [droid] from [droid.x],[droid.y]"
	var/mob/living/carbon/human/visitor = allocate(/mob/living/carbon/human/consistent, pick(bay.alcove_turfs))
	present += visitor
	SSmobs.clients_by_zlevel[visitor.z] += visitor
	for(var/obj/structure/outpost_yard_droid/droid as anything in droids)
		// A test world has no client for the droids to notice up close
		droid.ai_controller.can_idle = FALSE
		droid.ai_controller.reset_ai_status()
		TEST_ASSERT_EQUAL(droid.ai_controller.ai_status, AI_STATUS_ON, "[tracked[WEAKREF(droid)]] does not work with a player near")
	sleep(15 SECONDS)
	still_working(tracked, floor, style, "after working a while")

	// A hull lands, stays and leaves
	var/obj/structure/overmap/ship/ship = dock_hull(home, bay, style)
	still_working(tracked, floor, style, "after a hull landed", ship)
	sleep(10 SECONDS)
	still_working(tracked, floor, style, "with a hull docked", ship)
	undock_hull(home, bay, ship, style)
	still_working(tracked, floor, style, "after the hull left")

/// Droids anywhere in the bay's ground
/datum/unit_test/voidcrew_outpost_yard_droids/proc/bay_droids(datum/outpost_berth/ship_bay/bay)
	. = list()
	for(var/turf/tile as anything in bay.get_block())
		for(var/obj/structure/outpost_yard_droid/droid in tile)
			. += droid

/**
 * The bay's docking floor, worked out here without the worker code: the landing pad at its largest
 * and every open tile joined to it without a door, window or fence between.
 */
/datum/unit_test/voidcrew_outpost_yard_droids/proc/docking_floor(datum/outpost_berth/ship_bay/bay)
	. = list()
	var/obj/docking_port/stationary/dock = bay.dock
	var/turf/low = locate(dock.reserve_home_x, dock.reserve_home_y, dock.reserve_home_z)
	var/turf/high = locate(dock.reserve_home_x + 55, dock.reserve_home_y + 39, dock.reserve_home_z)
	if(!low || !high)
		TEST_FAIL("The bay's dock has no home to measure its pad from")
		return
	var/list/queue = list()
	for(var/turf/tile as anything in block(low, high))
		.[tile] = TRUE
		queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/tile = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(!next || .[next] || !bay.contains_turf(next) || !isopenturf(next) || floor_barrier(next))
				continue
			.[next] = TRUE
			queue += next

/// The landing pad at its largest and the 2 tiles round it, as list(min x, min y, max x, max y)
/datum/unit_test/voidcrew_outpost_yard_droids/proc/pad_surrounds(datum/outpost_berth/ship_bay/bay)
	var/obj/docking_port/stationary/dock = bay.dock
	return list(dock.reserve_home_x - 2, dock.reserve_home_y - 2, dock.reserve_home_x + 55 + 2, dock.reserve_home_y + 39 + 2)

/// Whether `tile` closes the docking floor off: a door, a full window, a fence, a grille or flaps
/datum/unit_test/voidcrew_outpost_yard_droids/proc/floor_barrier(turf/tile)
	for(var/obj/thing in tile)
		if(istype(thing, /obj/machinery/door) || istype(thing, /obj/structure/fence) || istype(thing, /obj/structure/grille) || istype(thing, /obj/structure/plasticflaps))
			return TRUE
		if(istype(thing, /obj/structure/window))
			var/obj/structure/window/pane = thing
			if(pane.fulltile)
				return TRUE
	return FALSE

/datum/unit_test/voidcrew_outpost_yard_droids/proc/check_droid(obj/structure/outpost_yard_droid/droid, list/floor, list/near_pad, list/lift, style)
	var/turf/home = get_turf(droid)
	var/label = "The [style] bay's [droid] at [home.x],[home.y]"
	TEST_ASSERT(droid.anchored && !droid.density, "[label] is not anchored and walk-through")
	TEST_ASSERT(droid.resistance_flags & INDESTRUCTIBLE, "[label] can be destroyed")
	TEST_ASSERT(!floor[home], "[label] is mapped on the docking floor")
	TEST_ASSERT(looks_right(droid), "[label] cannot be seen")
	var/datum/component/outpost_ambient_worker/worker = droid.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(worker, "[label] does not work")
	var/area/home_area = get_area(home)
	var/list/room = worker.get_room()
	TEST_ASSERT(length(room) > 1, "[label] has nowhere to walk")
	for(var/turf/tile as anything in room)
		TEST_ASSERT_EQUAL(get_area(tile), home_area, "[label] can walk out of its area at [tile.x],[tile.y]")
		TEST_ASSERT(!floor[tile], "[label] can walk onto the docking floor at [tile.x],[tile.y]")
		var/by_pad = tile.x >= near_pad[1] && tile.x <= near_pad[3] && tile.y >= near_pad[2] && tile.y <= near_pad[4]
		TEST_ASSERT(!by_pad, "[label] can walk up to the landing pad at [tile.x],[tile.y]")
		TEST_ASSERT(!(tile in lift), "[label] can walk onto the lift at [tile.x],[tile.y]")
		TEST_ASSERT(!(locate(/obj/machinery/door) in tile), "[label] can walk through the door at [tile.x],[tile.y]")
		TEST_ASSERT(get_dist(tile, home) <= 6, "[label] can wander to [tile.x],[tile.y]")

	var/list/job = worker.find_work()
	TEST_ASSERT(length(job) == 3, "[label] finds nothing to work on")
	TEST_ASSERT(room[job[2]], "[label] would work from [job[2]], outside its room")

	// It walks about, and every step stays in its room
	var/list/visited = list()
	for(var/step in 1 to 200)
		worker.wander_step()
		var/turf/here = get_turf(droid)
		visited[here] = TRUE
		TEST_ASSERT(room[here], "[label] wandered out of its room to [here.x],[here.y]")
		TEST_ASSERT(!floor[here], "[label] wandered onto the docking floor at [here.x],[here.y]")
	TEST_ASSERT(length(visited) > 1, "[label] never moved")

	// A step off its room is refused, onto the docking floor above all
	for(var/turf/tile as anything in room)
		for(var/direction in GLOB.cardinals)
			var/turf/outside = get_step(tile, direction)
			if(!outside || room[outside] || !isopenturf(outside) || outside.is_blocked_turf())
				continue
			droid.forceMove(tile)
			TEST_ASSERT(!droid.Move(outside, direction), "[label] stepped out of its room to [outside.x],[outside.y]")
			TEST_ASSERT_EQUAL(get_turf(droid), tile, "[label] left its room")
	droid.forceMove(home)

	// Nothing carries it off, and if something did it would come back
	var/turf/far = pick(floor) || run_loc_floor_bottom_left
	TEST_ASSERT(!do_teleport(droid, far, forced = TRUE, no_effects = TRUE), "[label] was teleported")
	TEST_ASSERT_EQUAL(get_turf(droid), home, "[label] moved when teleported")
	var/mob/living/carbon/human/puller = allocate(/mob/living/carbon/human/consistent, home)
	puller.start_pulling(droid)
	TEST_ASSERT(puller.pulling != droid, "[label] can be pulled")
	droid.forceMove(run_loc_floor_bottom_left)
	TEST_ASSERT(worker.check_leash(), "[label] stayed where it was dropped")
	TEST_ASSERT_EQUAL(get_turf(droid), home, "[label] did not go back to its room")

	// Working shows and stops cleanly, and hands nothing out
	var/turf/spot = job[2]
	var/items_before = 0
	for(var/obj/item/thing in spot)
		items_before++
	droid.forceMove(spot)
	worker.planned_work = job[3]
	TEST_ASSERT(worker.start_work(job[1]), "[label] could not start work")
	TEST_ASSERT(worker.continue_work(), "[label] stopped work at once")
	worker.stop_work()
	TEST_ASSERT_NULL(worker.work, "[label] kept working after stopping")
	TEST_ASSERT_NULL(worker.work_overlay, "[label] kept its work sparks")
	var/items_after = 0
	for(var/obj/item/thing in spot)
		items_after++
	TEST_ASSERT_EQUAL(items_after, items_before, "[label] left something behind at work")
	droid.forceMove(home)

/// Whether a player can see the droid: its sprite exists, it is not hidden and not pushed off its tile
/datum/unit_test/voidcrew_outpost_yard_droids/proc/looks_right(obj/structure/outpost_yard_droid/droid)
	if(!icon_exists(droid.icon, droid.icon_state) || droid.invisibility || droid.alpha != 255)
		return FALSE
	return max(abs(droid.pixel_x), abs(droid.pixel_y), abs(droid.pixel_w), abs(droid.pixel_z)) <= 8

/// Every tracked droid still exists, stands in its room clear of the docking floor and any hull,
/// can be seen, and is working. Checks every droid rather than stopping at the first.
/datum/unit_test/voidcrew_outpost_yard_droids/proc/still_working(list/tracked, list/floor, style, when, obj/structure/overmap/ship/ship)
	for(var/datum/weakref/ref as anything in tracked)
		var/label = tracked[ref]
		var/obj/structure/outpost_yard_droid/droid = ref.resolve()
		if(QDELETED(droid))
			TEST_FAIL("[label] was deleted [when]")
			continue
		var/turf/here = droid.loc
		if(!isturf(here))
			TEST_FAIL("[label] is off the map [when] (in [droid.loc || "nullspace"])")
			continue
		var/datum/component/outpost_ambient_worker/worker = droid.GetComponent(/datum/component/outpost_ambient_worker)
		var/list/room = worker?.get_room()
		if(!room || !room[here])
			TEST_FAIL("[label] is out of its room at [here.x],[here.y] [when]")
		if(floor[here])
			TEST_FAIL("[label] is on the docking floor at [here.x],[here.y] [when]")
		if(ship && (get_area(here) in ship.shuttle?.shuttle_areas))
			TEST_FAIL("[label] is inside the hull at [here.x],[here.y] [when]")
		if(!looks_right(droid))
			TEST_FAIL("[label] cannot be seen [when]: [droid.icon_state], invisibility [droid.invisibility], alpha [droid.alpha], offset [droid.pixel_x + droid.pixel_w],[droid.pixel_y + droid.pixel_z]")
		if(droid.ai_controller?.ai_status != AI_STATUS_ON)
			TEST_FAIL("[label] stopped working [when] (AI [droid.ai_controller?.ai_status || "gone"])")

/// Lands a Scarab in the bay the way a docking ship does
/datum/unit_test/voidcrew_outpost_yard_droids/proc/dock_hull(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_berth/ship_bay/bay, style)
	var/obj/structure/overmap/ship/ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/scarab)
	if(!ship)
		TEST_FAIL("No Scarab could be spawned for the [style] bay")
		return null
	test_ships += ship
	if(home.allocate_ship_bay(ship) != bay)
		TEST_FAIL("The [style] bay would not take a Scarab")
		return ship
	adjust_reserve_dock_to_shuttle(bay.dock, ship.shuttle)
	ship.shuttle.mode = SHUTTLE_PREARRIVAL
	var/docked = ship.shuttle.initiate_docking(bay.dock)
	ship.shuttle.mode = SHUTTLE_IDLE
	if(docked != DOCKING_SUCCESS)
		TEST_FAIL("A Scarab could not land in the [style] bay ([docked])")
		return ship
	ship.docked = home
	ship.forceMove(home)
	ship.state = "idle"
	bay.on_ship_docked(ship)
	TEST_ASSERT(bay.is_ship_present(), "The Scarab did not land in the [style] bay")
	return ship

/// Sends the hull off the way a departing ship goes
/datum/unit_test/voidcrew_outpost_yard_droids/proc/undock_hull(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_berth/ship_bay/bay, obj/structure/overmap/ship/ship, style)
	if(QDELETED(ship?.shuttle))
		return
	var/obj/docking_port/stationary/transit/transit = ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(ship.shuttle)
	ship.shuttle.mode = SHUTTLE_PREARRIVAL
	var/left = ship.shuttle.initiate_docking(transit)
	ship.shuttle.mode = SHUTTLE_IDLE
	ship.docked = null
	ship.forceMove(get_turf(home))
	ship.state = "flying"
	home.on_ship_undock_complete(ship)
	TEST_ASSERT_EQUAL(left, DOCKING_SUCCESS, "The Scarab could not leave the [style] bay")
	TEST_ASSERT(!bay.dock.get_docked(), "The Scarab is still in the [style] bay")
	ship.shuttle.admin_delete_shuttle()

/// Mechanics each wear one of several outfits, change looks to work, keep to their room and stay
/// out of doorways.
/datum/unit_test/voidcrew_outpost_mechanic_work

/datum/unit_test/voidcrew_outpost_mechanic_work/Run()
	// One person three ways: working looks differ from the idle one, the visor comes down to weld
	var/list/looks = get_outpost_worker_looks(/datum/outfit/outpost_mechanic, FEMALE, 1)
	TEST_ASSERT_EQUAL(length(looks), 3, "A mechanic has [length(looks)] looks, not 3")
	for(var/look_name in list("idle", "weld", "tool"))
		TEST_ASSERT_NOTNULL(looks[look_name], "A mechanic has no [look_name] look")
	TEST_ASSERT(signature(looks["idle"]) != signature(looks["weld"]), "A mechanic welds with empty hands")
	TEST_ASSERT(signature(looks["idle"]) != signature(looks["tool"]), "A mechanic works with empty hands")
	TEST_ASSERT(has_state(looks["weld"], "weldvisor"), "A mechanic welds with the visor up")
	TEST_ASSERT(!has_state(looks["idle"], "weldvisor"), "A mechanic walks about with the visor down")
	TEST_ASSERT(get_outpost_worker_looks(/datum/outfit/outpost_mechanic, FEMALE, 1) == looks, "Working looks are not cached")

	// In a room with a door on its east wall: never through it, never stopping beside it
	var/turf/start = locate(run_loc_floor_bottom_left.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/door_turf = locate(run_loc_floor_top_right.x, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	allocate(/obj/machinery/door/airlock, door_turf)
	var/mob/living/basic/ambient_npc/mechanic = allocate(/mob/living/basic/ambient_npc, start)
	mechanic.AddComponent(/datum/component/outpost_ambient_worker, list(
		/datum/outpost_ambient_work/weld = 3,
		/datum/outpost_ambient_work/wrench = 2,
		/datum/outpost_ambient_work/panel = 2,
		/datum/outpost_ambient_work/pipe = 2,
	), TRUE)
	var/datum/component/outpost_ambient_worker/worker = mechanic.GetComponent(/datum/component/outpost_ambient_worker)
	TEST_ASSERT_NOTNULL(worker, "A worker does not work")
	var/list/room = worker.get_room()
	TEST_ASSERT(!room[door_turf], "A worker's room runs through a door")
	var/list/visited = list()
	for(var/step in 1 to 150)
		worker.wander_step()
		var/turf/here = get_turf(mechanic)
		visited[here] = TRUE
		TEST_ASSERT(here != door_turf, "A worker walked into the doorway")
		var/beside_door = get_dist(here, door_turf) == 1 && (here.x == door_turf.x || here.y == door_turf.y)
		TEST_ASSERT(!beside_door, "A worker stopped beside the door at [here.x],[here.y]")
	TEST_ASSERT(length(visited) > 1, "A worker never moved")
	var/turf/before_teleport = get_turf(mechanic)
	TEST_ASSERT(!do_teleport(mechanic, run_loc_floor_top_right, forced = TRUE, no_effects = TRUE), "A worker was teleported")
	TEST_ASSERT_EQUAL(get_turf(mechanic), before_teleport, "A worker moved when teleported")

/// What a look is drawn from: every overlay's icon, state and colour, nested overlays included
/datum/unit_test/voidcrew_outpost_mechanic_work/proc/signature(mutable_appearance/look, depth = 0)
	var/list/parts = list()
	for(var/mutable_appearance/overlay as anything in look.overlays)
		parts += "[overlay.icon]:[overlay.icon_state]:[overlay.color]"
		if(depth < 2)
			parts += signature(overlay, depth + 1)
	return jointext(parts, "|")

/// Whether any overlay of `look`, nested ones included, has an icon state containing `fragment`
/datum/unit_test/voidcrew_outpost_mechanic_work/proc/has_state(mutable_appearance/look, fragment, depth = 0)
	for(var/mutable_appearance/overlay as anything in look.overlays)
		if(findtext(overlay.icon_state, fragment))
			return TRUE
		if(depth < 2 && has_state(overlay, fragment, depth + 1))
			return TRUE
	return FALSE
