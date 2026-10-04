/**
 * # Outpost room power
 *
 * Every upgrade room joins the habitat grid by contact (its door lands on the tile outside a
 * habitat outer airlock) or by feeder (the owner builds a floor path to it), runs on its own APC
 * until then, and is wired with protected cable only the outpost's builders can cut.
 *
 * Voidcrew defines are not visible from test files, so ids and literals appear as written values.
 */

/// Outer external airlocks under `home`: an external airlock with space on one side and not on the
/// other (the derelict prison's own candidate method, derelict_layout.dm), as list(door, direction).
/datum/unit_test/proc/outpost_outer_airlocks(obj/structure/overmap/dynamic/player_outpost/home)
	. = list()
	var/z = home.upgrade_level_z()
	if(!z || !home.outpost_area)
		return
	for(var/turf/tile as anything in home.outpost_area.get_turfs_by_zlevel(z))
		for(var/obj/machinery/door/airlock/external/door in tile)
			for(var/direction in GLOB.cardinals)
				var/turf/outside = get_step(tile, direction)
				var/turf/inside = get_step(tile, REVERSE_DIR(direction))
				if(!outside || !inside || !isspaceturf(outside) || isspaceturf(inside) || !home.is_turf_buildable(outside))
					continue
				. += list(list(door, direction))

/// Cuts `cable` as `user`, who is given insulated gloves first: a live net's handlecable() shocks
/// half the time on a bare-handed cutter and returns without cutting, which would make this flaky.
/datum/unit_test/voidcrew_outpost_management/proc/outpost_cut_cable_as(obj/structure/cable/cable, mob/living/carbon/human/user)
	if(!user.gloves)
		user.equip_to_slot_or_del(allocate(/obj/item/clothing/gloves/color/yellow), ITEM_SLOT_GLOVES)
	var/obj/item/wirecutters/cutters = allocate(/obj/item/wirecutters)
	cable.handlecable(cutters, user)

/**
 * A storage room placed so its door lands on the tile outside a habitat's outer airlock joins the
 * grid with no code: the cables touch and the template's powernet pass merges the nets. One claim
 * per airlock, for every selectable shell.
 */
/datum/unit_test/voidcrew_outpost_room_power_contact
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_room_power_contact/Run()
	for(var/datum/map_template/player_outpost/shell_type as anything in outpost_selectable_shells())
		var/label = initial(shell_type.name)
		var/obj/structure/overmap/dynamic/player_outpost/scan = allocate(/obj/structure/overmap/dynamic/player_outpost)
		scan.shell_template = allocate(shell_type)
		TEST_ASSERT(scan.load_level(), "The [label] did not load to scan its airlocks")
		var/list/candidates = outpost_outer_airlocks(scan)
		TEST_ASSERT(length(candidates), "The [label] has no outer external airlock")
		var/turf/scan_corner = scan.template_bottom_left
		var/list/offsets = list()
		for(var/list/candidate as anything in candidates)
			var/turf/door_turf = get_turf(candidate[1])
			offsets += list(list(door_turf.x - scan_corner.x, door_turf.y - scan_corner.y, candidate[2]))

		// Every airlock a storage room fits at joins it; an airlock in a notch too narrow for the room
		// is refused before anything loads, so only the ones that fit are tested, and at least one must.
		var/joined = 0
		for(var/list/offset as anything in offsets)
			var/direction = offset[3]
			var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
			home.shell_template = allocate(shell_type)
			TEST_ASSERT(home.load_level(), "The [label] did not load for its [dir2text(direction)] airlock")
			var/turf/corner = home.template_bottom_left
			var/turf/door_tile = locate(corner.x + offset[1], corner.y + offset[2], corner.z)
			var/turf/outside = get_step(door_tile, direction)
			TEST_ASSERT_NOTNULL(outside, "No tile outside the [label]'s [dir2text(direction)] airlock")
			var/rotation = SIMPLIFY_DEGREES(dir2angle(direction))
			var/datum/outpost_upgrade/service/storage/room = new(home)
			home.outpost_upgrades[room.id] = room
			var/list/door_offsets = room.template_door_offsets()
			TEST_ASSERT_EQUAL(length(door_offsets), 1, "The storage room does not have exactly one door")
			var/datum/map_template/template = room.get_template()
			TEST_ASSERT_NOTNULL(template, "The storage room has no map for the [label]'s style")
			var/list/room_offset = rotated_template_offset(door_offsets[1][1], door_offsets[1][2], rotation, template.width, template.height)
			var/turf/bottom_left = locate(outside.x - room_offset[1], outside.y - room_offset[2], outside.z)
			var/result = home.place_outpost_upgrade(room, bottom_left, rotation, null)
			if(result == "Position obstructed.")
				continue
			TEST_ASSERT_NULL(result, "A storage room could not join the [label] at its [dir2text(direction)] airlock: [result]")
			joined++
			TEST_ASSERT(room.on_grid(), "The storage room did not join the grid at the [label]'s [dir2text(direction)] airlock")
			var/obj/machinery/power/smes/smes = locate() in home.outpost_area
			TEST_ASSERT(home.outpost_area.apc?.terminal?.powernet && home.outpost_area.apc.terminal.powernet == smes?.terminal?.powernet, "The [label]'s habitat APC left the SMES's net once a room joined at its [dir2text(direction)] airlock")
			settle_room_air(room.room_turfs())
		TEST_ASSERT(joined > 0, "No outer airlock of the [label] has room for a storage room")

/**
 * A room placed away from the habitat stays on its own cell until the owner's floor reaches it: the
 * feeder then lays protected cable along the path, once, and never re-lays cable the owner cuts.
 */
/datum/unit_test/voidcrew_outpost_room_power_feeder
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_room_power_feeder/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
	home.shell_template = allocate(/datum/map_template/player_outpost/rundown)
	home.founder_ckey = "feederowner"
	TEST_ASSERT(home.load_level(), "The rundown feeder test outpost did not load")

	var/obj/machinery/door/airlock/external/west_door
	for(var/list/candidate as anything in outpost_outer_airlocks(home))
		if(candidate[2] == WEST)
			west_door = candidate[1]
			break
	TEST_ASSERT_NOTNULL(west_door, "The rundown shell has no west outer airlock")
	var/turf/door_tile = get_turf(west_door)

	// The room's door lands 4 tiles further west: 3 gap tiles of unbuilt space sit between them.
	var/turf/room_door_tile = door_tile
	for(var/step in 1 to 4)
		room_door_tile = get_step(room_door_tile, WEST)
	var/list/gap_tiles = list()
	var/turf/walker = door_tile
	for(var/step in 1 to 3)
		walker = get_step(walker, WEST)
		gap_tiles += walker

	var/rotation = SIMPLIFY_DEGREES(dir2angle(WEST))
	var/datum/outpost_upgrade/service/storage/room = new(home)
	home.outpost_upgrades[room.id] = room
	var/list/door_offsets = room.template_door_offsets()
	TEST_ASSERT_EQUAL(length(door_offsets), 1, "The storage room does not have exactly one door")
	var/datum/map_template/template = room.get_template()
	TEST_ASSERT_NOTNULL(template, "The storage room has no map for the rundown style")
	var/list/room_offset = rotated_template_offset(door_offsets[1][1], door_offsets[1][2], rotation, template.width, template.height)
	var/turf/bottom_left = locate(room_door_tile.x - room_offset[1], room_door_tile.y - room_offset[2], room_door_tile.z)
	var/result = home.place_outpost_upgrade(room, bottom_left, rotation, null)
	TEST_ASSERT_NULL(result, "The storage room could not be placed 4 tiles from the west airlock: [result]")
	TEST_ASSERT(!room.on_grid(), "The storage room started on the grid with no path to the habitat")
	TEST_ASSERT(!room.feeder_laid, "The feeder ran with no path to walk")

	for(var/turf/gap as anything in gap_tiles)
		gap.ChangeTurf(/turf/open/floor/plating)
		home.adopt_turf(gap)
	home.join_rooms_to_grid()

	TEST_ASSERT(room.on_grid(), "The room did not join the grid once a floor path reached it")
	TEST_ASSERT(room.feeder_laid, "Joining the grid did not mark the feeder laid")
	for(var/turf/gap as anything in gap_tiles)
		var/cable_count = 0
		for(var/obj/structure/cable/outpost/cable in gap)
			cable_count++
		TEST_ASSERT_EQUAL(cable_count, 1, "The feeder did not lay exactly one cable at [gap.x],[gap.y]")

	// A second call lays nothing more.
	home.join_rooms_to_grid()
	for(var/turf/gap as anything in gap_tiles)
		var/cable_count = 0
		for(var/obj/structure/cable/outpost/cable in gap)
			cable_count++
		TEST_ASSERT_EQUAL(cable_count, 1, "A second join duplicated feeder cable at [gap.x],[gap.y]")

	// Cutting a feeder cable is never overruled by a later join.
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "feederowner")
	var/turf/cut_gap = gap_tiles[2]
	var/obj/structure/cable/outpost/cut_cable = locate() in cut_gap
	TEST_ASSERT_NOTNULL(cut_cable, "No feeder cable to cut at [cut_gap.x],[cut_gap.y]")
	outpost_cut_cable_as(cut_cable, owner)
	TEST_ASSERT(QDELETED(cut_cable), "The owner could not cut a feeder cable")
	home.join_rooms_to_grid()
	TEST_ASSERT_NULL(locate(/obj/structure/cable/outpost) in cut_gap, "The feeder relaid cable the owner cut on purpose")
	settle_room_air(room.room_turfs())

/**
 * Outpost cable: only the outpost's builders cut it, bombs and rats cannot, a drone strip of a room
 * floor over it succeeds and leaves it in place, and a visitor's coil cannot tap a stripped tile.
 */
/datum/unit_test/voidcrew_outpost_room_power_cable
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_room_power_cable/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("cabletestowner")
	TEST_ASSERT_NOTNULL(home, "The cable test outpost did not load")
	var/mob/living/carbon/human/owner = market_test_owner(home, "cabletestowner")
	var/mob/living/carbon/human/builder = market_test_resident(home, "cabletestbuilder", null)
	home.authorized_builder_ckeys |= builder.ckey
	var/turf/spot = get_turf(home.management_console)
	// Cable under floor tiles can't be reached; these cuts happen on bare plating
	spot = spot.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR)
	var/mob/living/carbon/human/visitor = make_player(spot, "cabletestvisitor")
	for(var/mob/living/carbon/human/actor as anything in list(owner, builder, visitor))
		actor.equip_to_slot_or_del(allocate(/obj/item/clothing/gloves/color/yellow), ITEM_SLOT_GLOVES)

	// Owner cuts: gone, and a coil is dropped
	var/obj/structure/cable/outpost/owner_cable = allocate(/obj/structure/cable/outpost, spot)
	SSmachines.setup_template_powernets(list(owner_cable))
	outpost_cut_cable_as(owner_cable, owner)
	TEST_ASSERT(QDELETED(owner_cable), "The owner could not cut outpost cable")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/cable_coil) in spot, "Cutting outpost cable dropped no coil")

	// A named builder cuts: gone
	var/obj/structure/cable/outpost/builder_cable = allocate(/obj/structure/cable/outpost, spot)
	outpost_cut_cable_as(builder_cable, builder)
	TEST_ASSERT(QDELETED(builder_cable), "A named builder could not cut outpost cable")

	// A visitor cannot: still there
	var/obj/structure/cable/outpost/visitor_cable = allocate(/obj/structure/cable/outpost, spot)
	TEST_ASSERT(!visitor_cable.outpost_cut_allowed(visitor), "outpost_cut_allowed() let a visitor through")
	TEST_ASSERT(visitor_cable.outpost_cut_allowed(owner), "outpost_cut_allowed() refused the owner")
	TEST_ASSERT(visitor_cable.outpost_cut_allowed(builder), "outpost_cut_allowed() refused a named builder")
	outpost_cut_cable_as(visitor_cable, visitor)
	TEST_ASSERT(!QDELETED(visitor_cable), "A visitor cut protected outpost cable")
	qdel(visitor_cable)

	// A drone strip of a room floor over cable succeeds, and the cable stays.
	var/datum/outpost_upgrade/service/unit_test/room = new(home)
	room.id = "cable_strip_test"
	room.key = room.id
	var/placed = place_test_service_room(home, room, list(0, 90, 180, 270), owner)
	TEST_ASSERT_EQUAL(placed, room, "The cable strip test room was not placed: [placed]")
	var/turf/floor
	for(var/turf/tile as anything in room.room_turfs())
		if(locate(/obj/structure) in tile)
			continue
		if(locate(/obj/machinery) in tile)
			continue
		if(istype(tile, /turf/open/indestructible))
			floor = tile
			break
	TEST_ASSERT_NOTNULL(floor, "The cable strip test room has no bare indestructible floor")
	var/obj/structure/cable/outpost/room_cable = allocate(/obj/structure/cable/outpost, floor)

	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = home.construction_console
	TEST_ASSERT_NOTNULL(console, "The cable test outpost has no construction console")
	var/obj/item/construction/rcd/internal/ship/drone_rcd = console.internal_rcd
	var/obj/machinery/ore_silo/silo = console.get_linked_silo()
	if(!silo)
		silo = allocate(/obj/machinery/ore_silo, get_turf(console))
		TEST_ASSERT(console.link_internal_device(drone_rcd, drone_rcd.silo_mats, silo), "The construction console could not link a silo for the cable test")
	drone_rcd.silo_link = TRUE
	var/old_mode = drone_rcd.mode
	var/old_delay_mod = drone_rcd.delay_mod
	drone_rcd.mode = RCD_DECONSTRUCT
	drone_rcd.delay_mod = 0

	TEST_ASSERT(length(floor.rcd_vals(owner, drone_rcd)), "The drone could not strip a room floor with cable on it")
	drone_rcd.rcd_create(floor, owner)
	var/turf/stripped = get_turf(room_cable)
	TEST_ASSERT_EQUAL(stripped.type, /turf/open/floor/plating, "The drone did not strip a room floor with cable on it")
	TEST_ASSERT(!QDELETED(room_cable) && room_cable.loc == stripped, "Stripping a room floor over cable deleted or moved the cable")

	// A visitor's coil on stripped room plating is refused.
	var/cable_count_before = 0
	for(var/obj/structure/cable/existing in stripped)
		cable_count_before++
	var/obj/item/stack/cable_coil/thirty/visitor_coil = allocate(/obj/item/stack/cable_coil/thirty, spot)
	visitor_coil.place_turf(stripped, visitor)
	var/cable_count_after = 0
	for(var/obj/structure/cable/existing in stripped)
		cable_count_after++
	TEST_ASSERT_EQUAL(cable_count_after, cable_count_before, "A visitor's coil laid cable on stripped room plating")

	drone_rcd.mode = old_mode
	drone_rcd.delay_mod = old_delay_mod
	settle_room_air(room.room_turfs())

/**
 * The room APC: run only by the outpost's owner and stewards (never a visiting engineer's ID),
 * emag-proof, AI-disabled, outpost property, and named for its room.
 */
/datum/unit_test/voidcrew_outpost_room_power_apc
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_room_power_apc/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = market_test_claim("apctestowner")
	TEST_ASSERT_NOTNULL(home, "The APC test outpost did not load")
	var/mob/living/carbon/human/owner = market_test_owner(home, "apctestowner")
	var/mob/living/carbon/human/steward = market_test_resident(home, "apcteststeward", "steward")
	var/datum/outpost_upgrade/service/unit_test/room = new(home)
	room.id = "apc_test_room"
	room.key = room.id
	var/placed = place_test_service_room(home, room, list(0), owner)
	TEST_ASSERT_EQUAL(placed, room, "The APC test room was not placed: [placed]")

	var/obj/machinery/power/apc/outpost/apc
	for(var/turf/tile as anything in room.room_turfs())
		apc = locate() in tile
		if(apc)
			break
	TEST_ASSERT_NOTNULL(apc, "The placed room has no outpost APC")
	TEST_ASSERT_EQUAL(apc.name, "\improper [get_area_name(room.installed_area, TRUE)] APC", "The room APC is not named for its room")
	TEST_ASSERT(apc.aidisabled, "The room APC is not AI-disabled")
	TEST_ASSERT(HAS_TRAIT(apc, "outpost_property"), "The room APC is not outpost property")
	TEST_ASSERT(apc.resistance_flags & INDESTRUCTIBLE, "The room APC is not indestructible")

	var/turf/apc_turf = get_turf(apc)
	var/mob/living/carbon/human/visitor = make_player(apc_turf, "apctestvisitor")
	visitor.equip_to_slot_or_del(allocate(/obj/item/clothing/under/color/grey), ITEM_SLOT_ICLOTHING)
	var/obj/item/card/id/card = allocate(/obj/item/card/id)
	card.access = list(ACCESS_ENGINE_EQUIP)
	visitor.equip_to_slot_or_del(card, ITEM_SLOT_ID)
	TEST_ASSERT(!apc.allowed(visitor), "An engineer's ID opened a room APC")
	TEST_ASSERT(!apc.outpost_admits(visitor), "outpost_admits() let an engineer visitor through")
	TEST_ASSERT(apc.outpost_admits(owner), "outpost_admits() refused the owner")
	TEST_ASSERT(apc.outpost_admits(steward), "outpost_admits() refused a steward")
	TEST_ASSERT(apc.allowed(owner), "The room APC refused the owner")
	TEST_ASSERT(apc.allowed(steward), "The room APC refused a steward")

	TEST_ASSERT(!apc.emag_act(visitor, null), "Emagging a room APC succeeded")
	TEST_ASSERT(!(apc.obj_flags & EMAGGED), "A room APC was emagged")
