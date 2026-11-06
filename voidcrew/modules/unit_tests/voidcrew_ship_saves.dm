// Voidcrew defines load after the unit tests, so these mirror them.
#define SHIP_SAVE_TEST_SLOTS 3 // SHIP_SAVE_SLOTS
#define SHIP_SAVE_TEST_PRICE_MIN 5 // SHIP_SAVE_PRICE_MIN
#define SHIP_SAVE_TEST_MASS_PER_PART 150 // SHIP_SAVE_MASS_PER_PART
#define SHIP_SAVE_TEST_MACHINES_PER_PART 15 // SHIP_SAVE_MACHINES_PER_PART
#define SHIP_SAVE_TEST_PLAN_MAX 8000 // SHIP_SAVE_PLAN_MAX_LENGTH
#define SHIP_SAVE_TEST_PASSWORD_PRICE 3 // SHIP_PASSWORD_PRICE
#define SHIP_SAVE_TEST_FORMAT 1 // SHIP_SAVE_FORMAT
#define SHIP_SAVE_TEST_TILE_IRON 100 // SHIP_RTD_TILE_IRON
/// GLOB.round_id for the length of these tests. It is null on a world with no database.
#define SHIP_SAVE_TEST_ROUND 777
/// One more than RESERVE_DOCK_MAX_SIZE_LONG.
#define SHIP_SAVE_TEST_TOO_LONG 57

/// The save table, in memory. Nothing here needs a database.
/datum/ship_save_store/fake
	/// "ckey|slot" -> list("meta", "payload")
	var/list/saved = list()
	var/fail_writes = FALSE
	var/fail_reads = FALSE
	var/fail_removes = FALSE
	var/offline = FALSE
	/// Whether the slot was locked when the last remove() ran.
	var/locked_during_remove = FALSE

/datum/ship_save_store/fake/online()
	return !offline

/datum/ship_save_store/fake/read_meta(ckey)
	var/list/rows = list()
	for(var/slot in 1 to SHIP_SAVE_TEST_SLOTS)
		var/list/entry = saved["[ckey]|[slot]"]
		if(entry)
			var/list/row = entry["meta"]
			row = row.Copy()
			row["slot"] = slot
			row["survey"] = ship_save_read_summary(row["summary"])
			row -= "summary"
			rows += list(row)
	return rows

/datum/ship_save_store/fake/read_payload(ckey, slot)
	if(fail_reads)
		return null
	var/list/entry = saved["[ckey]|[slot]"]
	return entry?["payload"]

/datum/ship_save_store/fake/write(ckey, slot, list/meta, payload, overwrite = FALSE)
	if(fail_writes || (!overwrite && saved["[ckey]|[slot]"]))
		return FALSE
	saved["[ckey]|[slot]"] = list("meta" = meta.Copy(), "payload" = payload)
	return TRUE

/datum/ship_save_store/fake/remove(ckey, slot)
	locked_during_remove = !!GLOB.ship_saves.retrievals[GLOB.ship_saves.slot_key(ckey, slot)]
	if(fail_removes || !saved["[ckey]|[slot]"])
		return FALSE
	saved -= "[ckey]|[slot]"
	return TRUE

/// Parts in memory. The real spend_parts() is a pair of SQL statements with no database to run on.
/datum/ship_economy_db/fake
	var/list/held = list()
	var/spends = 0

/datum/ship_economy_db/fake/get_parts(ckey)
	return held.Copy()

/datum/ship_economy_db/fake/spend_parts(ckey, list/requirements)
	for(var/part_class in requirements)
		if(held[part_class] < requirements[part_class])
			return FALSE
	for(var/part_class in requirements)
		held[part_class] -= requirements[part_class]
	spends++
	return TRUE

/datum/ship_economy_db/fake/add_part(ckey, part_class, quantity = 1, method = "unspecified")
	held[part_class] += quantity
	return TRUE

/datum/ship_economy_db/fake/proc/total()
	. = 0
	for(var/part_class in held)
		. += held[part_class]

/// A stale type from an older deploy, as the database would hand it back.
#define SHIP_SAVE_TEST_GONE_PATH "/datum/outfit/job/this_was_removed_long_ago"

/datum/unit_test/voidcrew_ship_saves
	var/datum/ship_save_store/old_store
	var/datum/ship_saves/old_saves
	var/datum/ship_economy_db/old_economy
	var/datum/ship_save_store/fake/store
	var/datum/ship_economy_db/fake/economy
	var/old_round_id

/datum/unit_test/voidcrew_ship_saves/New()
	. = ..()
	old_round_id = GLOB.round_id
	GLOB.round_id = "[SHIP_SAVE_TEST_ROUND]"
	old_store = GLOB.ship_save_store
	old_saves = GLOB.ship_saves
	old_economy = GLOB.ship_economy_db
	store = new
	economy = new
	GLOB.ship_save_store = store
	GLOB.ship_saves = new /datum/ship_saves
	GLOB.ship_economy_db = economy

/datum/unit_test/voidcrew_ship_saves/Destroy()
	GLOB.round_id = old_round_id
	GLOB.ship_save_store = old_store
	GLOB.ship_saves = old_saves
	GLOB.ship_economy_db = old_economy
	return ..()

/datum/unit_test/voidcrew_ship_saves/proc/set_parts(combat = 0, science = 0, trade = 0, misc = 0)
	economy.held = list("combat" = combat, "science" = science, "trade" = trade, "misc" = misc)

/// A snapshot that needs no hull, with one room of the given size.
/datum/unit_test/voidcrew_ship_saves/proc/make_snapshot(tiles = 10)
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	snapshot.ship_name = "Test Hull"
	snapshot.class_name = "Test Class"
	snapshot.width = 3
	snapshot.height = 2
	snapshot.port_x = 1
	snapshot.port_y = 2
	var/list/room_tiles = list()
	for(var/i in 1 to tiles)
		room_tiles += list(list(1, 1))
	snapshot.rooms = list(list("name" = "Bridge", "type" = /area/shuttle/voidcrew, "tiles" = room_tiles))
	snapshot.jobs = list(list("name" = "Captain", "officer" = TRUE, "outfit" = /datum/outfit/job/assistant, "category" = "Assistant", "slots" = 2))
	snapshot.tgm = "//[DMM2TGM_MESSAGE]\n\"aaa\" = (\n/turf/template_noop,\n/area/template_noop)\n\n(1,1,1) = {\"\naaa\n\"}"
	return snapshot

/datum/unit_test/voidcrew_ship_saves/Run()
	check_round_trip()
	check_stale_types()
	check_stale_map()
	check_rejected_payloads()
	check_salvage()
	check_second_generation()
	check_board_salvage()
	check_saved_vars()
	check_survey()
	check_bill_rounding()
	check_plan()
	check_summary()
	check_part_plans()
	check_commit()
	check_overwrite()
	check_retrieval_rules()

/datum/unit_test/voidcrew_ship_saves/proc/check_round_trip()
	var/datum/ship_checkpoint/snapshot = make_snapshot()
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(GLOB.ship_saves.encode(snapshot))
	TEST_ASSERT_NOTNULL(decoded, "A fresh payload did not decode")
	TEST_ASSERT_EQUAL(decoded.ship_name, snapshot.ship_name, "Decoding lost the ship's name")
	TEST_ASSERT_EQUAL(decoded.class_name, snapshot.class_name, "Decoding lost the ship's class")
	TEST_ASSERT_EQUAL(decoded.width, snapshot.width, "Decoding lost the width")
	TEST_ASSERT_EQUAL(decoded.height, snapshot.height, "Decoding lost the height")
	TEST_ASSERT_EQUAL(decoded.port_x, snapshot.port_x, "Decoding lost the port's x")
	TEST_ASSERT_EQUAL(decoded.port_y, snapshot.port_y, "Decoding lost the port's y")
	TEST_ASSERT_EQUAL(decoded.tgm, snapshot.tgm, "Decoding changed the map text")
	TEST_ASSERT_EQUAL(decoded.owned_tile_count(), snapshot.owned_tile_count(), "Decoding lost room tiles")
	var/list/room = decoded.rooms[1]
	TEST_ASSERT_EQUAL(room["type"], /area/shuttle/voidcrew, "A room's type did not come back as a path")
	var/list/job = decoded.jobs[1]
	TEST_ASSERT_EQUAL(job["outfit"], /datum/outfit/job/assistant, "A job's outfit did not come back as a path")
	TEST_ASSERT_EQUAL(job["slots"], 2, "A job's slots changed")
	TEST_ASSERT_NULL(ship_job_definition_error(job), "A decoded job is not a valid definition")
	qdel(decoded)

/datum/unit_test/voidcrew_ship_saves/proc/check_stale_types()
	var/datum/ship_checkpoint/snapshot = make_snapshot()
	var/list/room = snapshot.rooms[1]
	room["type"] = "/area/shuttle/voidcrew/this_was_removed_long_ago"
	snapshot.jobs += list(list("name" = "Ghost", "outfit" = SHIP_SAVE_TEST_GONE_PATH, "category" = "Assistant", "slots" = 1))
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(GLOB.ship_saves.encode(snapshot))
	var/list/decoded_room = decoded.rooms[1]
	TEST_ASSERT_EQUAL(decoded_room["type"], /area/shuttle/voidcrew, "A removed room type did not fall back to a plain ship room")
	TEST_ASSERT_EQUAL(length(decoded.jobs), 1, "A job with a removed outfit was not dropped")
	qdel(decoded)
	snapshot.jobs = list(list("name" = "Ghost", "outfit" = SHIP_SAVE_TEST_GONE_PATH, "category" = "Assistant", "slots" = 1))
	decoded = GLOB.ship_saves.decode(GLOB.ship_saves.encode(snapshot))
	TEST_ASSERT_NULL(decoded.jobs, "With no jobs left the commissioned default should apply")
	qdel(decoded)

/// A removed area or turf on a tile would lose the tile, so decoding swaps in plain ones, whole paths only.
/datum/unit_test/voidcrew_ship_saves/proc/check_stale_map()
	var/datum/ship_checkpoint/snapshot = make_snapshot()
	// "plati" is a turf path that is missing, and the start of one that isn't.
	snapshot.tgm = "//[DMM2TGM_MESSAGE]\n\"aaa\" = (\n/obj/docking_port/mobile/voidcrew{\n\tarea_type = /area/shuttle/voidcrew/this_was_removed_long_ago;\n\tdir = 1\n\t},\n/turf/open/floor/plati{\n\tdir = 2;\n\tsheet_type = /obj/item/stack/sheet/iron\n\t},\n/area/shuttle/voidcrew/this_was_removed_long_ago)\n\"aab\" = (\n/turf/open/floor/plating,\n/area/shuttle/voidcrew)\n\n(1,1,1) = {\"\naaa\naab\n\"}"
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(GLOB.ship_saves.encode(snapshot))
	TEST_ASSERT_NOTNULL(decoded, "A map with removed types did not decode")
	var/expected = "//[DMM2TGM_MESSAGE]\n\"aaa\" = (\n/obj/docking_port/mobile/voidcrew{\n\tarea_type = /area/shuttle/voidcrew;\n\tdir = 1\n\t},\n/turf/open/floor/plating,\n/area/shuttle/voidcrew)\n\"aab\" = (\n/turf/open/floor/plating,\n/area/shuttle/voidcrew)\n\n(1,1,1) = {\"\naaa\naab\n\"}"
	TEST_ASSERT(decoded.tgm == expected, "Removed types were not replaced in the map text: [decoded.tgm]")
	qdel(decoded)

/datum/unit_test/voidcrew_ship_saves/proc/check_rejected_payloads()
	var/datum/ship_checkpoint/snapshot = make_snapshot()
	TEST_ASSERT_NULL(GLOB.ship_saves.decode("not json"), "Junk text decoded")
	var/list/data = json_decode(GLOB.ship_saves.encode(snapshot))
	var/real_format = data["format"]
	data["format"] = real_format + 1
	TEST_ASSERT_NULL(GLOB.ship_saves.decode(json_encode(data)), "An unknown format decoded")
	data["format"] = real_format
	data["width"] = SHIP_SAVE_TEST_TOO_LONG
	TEST_ASSERT_NULL(GLOB.ship_saves.decode(json_encode(data)), "An oversized hull decoded")

/datum/unit_test/voidcrew_ship_saves/proc/check_salvage()
	var/datum/ship_checkpoint/saved = make_snapshot()

	// Valuable structures stay behind unless they seal the hull.
	var/obj/structure/statue/gold/hos/statue = allocate(/obj/structure/statue/gold/hos)
	TEST_ASSERT(!saved.includes_object(statue), "A gold statue was saved")
	var/obj/structure/window/plasma/window = allocate(/obj/structure/window/plasma)
	TEST_ASSERT(saved.includes_object(window), "A plasma window was refused: it seals the hull")
	var/obj/structure/grille/grille = allocate(/obj/structure/grille)
	TEST_ASSERT(saved.includes_object(grille), "A grille was refused")

	// What a ship is ordinarily furnished in stays, and a med bay keeps its table whatever it is made of.
	var/obj/structure/table/wood/wood_table = allocate(/obj/structure/table/wood)
	TEST_ASSERT(saved.includes_object(wood_table), "A wood table was refused")
	var/obj/structure/chair/comfy/shuttle/shuttle_chair = allocate(/obj/structure/chair/comfy/shuttle)
	TEST_ASSERT(saved.includes_object(shuttle_chair), "A titanium shuttle chair was refused")
	var/obj/structure/table/optable/operating_table = allocate(/obj/structure/table/optable)
	TEST_ASSERT(saved.includes_object(operating_table), "A silver operating table was refused")

	// False walls and mineral doors stay, as plain iron.
	var/obj/structure/falsewall/gold/fake_wall = allocate(/obj/structure/falsewall/gold)
	TEST_ASSERT(saved.includes_object(fake_wall), "A gold false wall was refused: it seals the hull")
	var/wall_text = saved.atom_text(fake_wall)
	TEST_ASSERT(findtext(wall_text, "/obj/structure/falsewall{"), "A gold false wall was not saved as a plain one: [wall_text]")
	TEST_ASSERT(!findtext(wall_text, "gold"), "A gold false wall kept its name or look: [wall_text]")
	var/obj/structure/mineral_door/gold/door = allocate(/obj/structure/mineral_door/gold)
	TEST_ASSERT(saved.includes_object(door), "A gold door was refused: it seals the hull")
	var/door_text = saved.atom_text(door)
	TEST_ASSERT(findtext(door_text, "/obj/structure/mineral_door/iron{"), "A gold door was not saved as an iron one: [door_text]")
	TEST_ASSERT(!findtext(door_text, "gold"), "A gold door kept its name or look: [door_text]")

	// An emergency closet saves as a plain closet but keeps its look: only false walls and doors go plain.
	var/obj/structure/closet/emcloset/closet = allocate(/obj/structure/closet/emcloset)
	TEST_ASSERT(findtext(saved.atom_text(closet), "name = "), "An emergency closet lost its name")

	// A mineral wall and floor keep their look but come apart into iron, even after a shuttle move.
	var/turf/wall_tile = run_loc_floor_bottom_left
	var/turf/copy_tile = get_step(wall_tile, EAST)
	var/wall_tile_type = wall_tile.type
	var/copy_tile_type = copy_tile.type
	wall_tile.ChangeTurf(/turf/closed/wall/mineral/diamond)
	var/turf/closed/wall/mineral/diamond/diamond_wall = wall_tile
	TEST_ASSERT(findtext(saved.atom_text(diamond_wall), "sheet_type = /obj/item/stack/sheet/iron"), "A diamond wall was saved with its own salvage")
	diamond_wall.sheet_type = /obj/item/stack/sheet/iron
	diamond_wall.copyTurf(copy_tile)
	var/turf/closed/wall/moved_wall = copy_tile
	TEST_ASSERT_EQUAL(moved_wall.type, /turf/closed/wall/mineral/diamond, "A moved wall changed type")
	TEST_ASSERT_EQUAL(moved_wall.sheet_type, /obj/item/stack/sheet/iron, "A shuttle move gave a saved wall its salvage back")
	moved_wall.break_wall()
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/iron) in moved_wall, "A saved wall dropped no iron")
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet/mineral/diamond) in moved_wall, "A saved wall dropped diamond")
	for(var/obj/thing in moved_wall)
		qdel(thing)

	wall_tile.ChangeTurf(/turf/open/floor/mineral/gold)
	var/turf/open/floor/mineral/gold/gold_floor = wall_tile
	TEST_ASSERT(findtext(saved.atom_text(gold_floor), "floor_tile = /obj/item/stack/tile/iron"), "A gold floor was saved with its own tile")
	gold_floor.floor_tile = /obj/item/stack/tile/iron
	gold_floor.copyTurf(copy_tile)
	var/turf/open/floor/moved_floor = copy_tile
	TEST_ASSERT_EQUAL(moved_floor.floor_tile, /obj/item/stack/tile/iron, "A shuttle move gave a saved floor its tile back")
	wall_tile.ChangeTurf(wall_tile_type)
	copy_tile.ChangeTurf(copy_tile_type)

/// A hull that was saved once, loaded and saved again must not get its salvage back.
/datum/unit_test/voidcrew_ship_saves/proc/check_second_generation()
	var/datum/ship_checkpoint/saved = make_snapshot()
	var/turf/tile = run_loc_floor_bottom_left
	var/tile_type = tile.type
	var/obj/item/construction/rcd/internal/ship/rcd = allocate(/obj/item/construction/rcd/internal/ship)

	tile.ChangeTurf(/turf/closed/wall/mineral/diamond)
	var/turf/closed/wall/wall = tile
	wall.sheet_type = /obj/item/stack/sheet/iron
	TEST_ASSERT(findtext(saved.atom_text(wall), "sheet_type = /obj/item/stack/sheet/iron"), "A wall saved a second time got its salvage back")
	// A drone refunds a stripped wall as the iron wall it comes apart into, and a real mineral wall as before.
	var/list/refund = rcd.get_deconstruction_materials(wall)
	TEST_ASSERT_EQUAL(refund[/datum/material/iron], 200, "A stripped diamond wall was not refunded as an iron wall")
	TEST_ASSERT_EQUAL(length(refund), 1, "A stripped diamond wall was refunded more than iron")
	tile.ChangeTurf(/turf/closed/wall/mineral/plastitanium)
	refund = rcd.get_deconstruction_materials(tile)
	TEST_ASSERT_EQUAL(refund[/datum/material/plasma], 100, "A real plastitanium wall stopped refunding plasma")
	wall = tile
	wall.sheet_type = /obj/item/stack/sheet/iron
	refund = rcd.get_deconstruction_materials(tile)
	TEST_ASSERT_EQUAL(refund[/datum/material/iron], 200, "A stripped plastitanium wall was not refunded as an iron wall")
	TEST_ASSERT_NULL(refund[/datum/material/plasma], "A stripped plastitanium wall was refunded plasma")
	tile.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_EQUAL(rcd.get_deconstruction_materials(tile)[/datum/material/iron], 200, "A real iron wall stopped refunding iron")

	tile.ChangeTurf(/turf/open/floor/mineral/plastitanium)
	var/turf/open/floor/floor = tile
	refund = rcd.get_deconstruction_materials(tile)
	TEST_ASSERT_EQUAL(refund[/datum/material/plasma], 25, "A real plastitanium floor stopped refunding plasma")
	floor.floor_tile = /obj/item/stack/tile/iron
	TEST_ASSERT(findtext(saved.atom_text(floor), "floor_tile = /obj/item/stack/tile/iron"), "A floor saved a second time got its tile back")
	refund = rcd.get_deconstruction_materials(tile)
	TEST_ASSERT_EQUAL(refund[/datum/material/iron], SHIP_SAVE_TEST_TILE_IRON, "A stripped plastitanium floor was not refunded as an iron tile")
	TEST_ASSERT_NULL(refund[/datum/material/plasma], "A stripped plastitanium floor was refunded plasma")
	tile.ChangeTurf(/turf/open/floor/iron)
	TEST_ASSERT_EQUAL(rcd.get_deconstruction_materials(tile)[/datum/material/iron], SHIP_SAVE_TEST_TILE_IRON, "A real iron floor stopped refunding iron")
	tile.ChangeTurf(tile_type)

	// A mineral airlock keeps its look, and an unfinished one is refused.
	var/obj/machinery/door/airlock/gold/gold_airlock = allocate(/obj/machinery/door/airlock/gold)
	var/airlock_text = saved.atom_text(gold_airlock)
	TEST_ASSERT(findtext(airlock_text, "assemblytype = /obj/structure/door_assembly;") || findtext(airlock_text, "assemblytype = /obj/structure/door_assembly\n"), "A gold airlock kept its gold assembly: [airlock_text]")
	TEST_ASSERT(!findtext(airlock_text, "door_assembly_gold"), "A gold airlock was saved with a gold assembly: [airlock_text]")
	TEST_ASSERT(!findtext(saved.atom_text(allocate(/obj/machinery/door/airlock)), "assemblytype"), "A plain airlock was given another assembly")
	TEST_ASSERT(ship_save_refuses_object(allocate(/obj/structure/door_assembly/door_assembly_gold)), "A gold airlock assembly was saved")
	TEST_ASSERT(!ship_save_refuses_object(allocate(/obj/structure/door_assembly)), "A plain airlock assembly was refused")
	// The plain assembly it falls back to comes apart into iron alone. The assemblies above share this tile.
	for(var/obj/structure/door_assembly/leftover in tile)
		qdel(leftover)
	var/obj/machinery/door/airlock/gold/breaking = new(tile)
	breaking.assemblytype = /obj/structure/door_assembly
	breaking.deconstruct(TRUE)
	var/obj/structure/door_assembly/dropped = locate() in tile
	TEST_ASSERT_NOTNULL(dropped, "A gold airlock with a plain assembly left nothing behind")
	TEST_ASSERT_EQUAL(dropped?.type, /obj/structure/door_assembly, "The airlock did not fall back to a plain assembly")
	dropped?.deconstruct(TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/iron) in tile, "A plain assembly dropped no iron")
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet/mineral/gold) in tile, "A plain assembly dropped gold")
	// Not effects: the test room's own marker is on this tile, and every later test finds the room by it.
	for(var/obj/loose in tile)
		if(!iseffect(loose))
			qdel(loose)

/// A saved RTG still makes power, and taking it apart hands back no uranium. An ordinary one still does.
/datum/unit_test/voidcrew_ship_saves/proc/check_board_salvage()
	var/turf/tile = run_loc_floor_bottom_left
	// Not effects: the test room's own marker is on this tile, and every later test finds the room by it.
	for(var/obj/loose in tile)
		if(!iseffect(loose))
			qdel(loose)
	var/obj/machinery/power/rtg/saved = new(tile)
	checkpoint_restore_machine(saved)
	TEST_ASSERT(saved.power_gen > 0, "A saved RTG makes no power")
	saved.deconstruct(TRUE)
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet/mineral/uranium) in tile, "A saved RTG handed back uranium")
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/cable_coil) in tile, "A saved RTG stopped handing back its ordinary stacks")
	// Not effects: the test room's own marker is on this tile, and every later test finds the room by it.
	for(var/obj/loose in tile)
		if(!iseffect(loose))
			qdel(loose)
	var/obj/machinery/power/rtg/ordinary = new(tile)
	ordinary.deconstruct(TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/mineral/uranium) in tile, "An ordinary RTG stopped handing back its uranium")
	// Not effects: the test room's own marker is on this tile, and every later test finds the room by it.
	for(var/obj/loose in tile)
		if(!iseffect(loose))
			qdel(loose)

/// Loading a map with a var its type doesn't have throws, so each one a save writes must exist.
/datum/unit_test/voidcrew_ship_saves/proc/check_saved_vars()
	var/list/saved_vars = list(
		/obj/machinery/power/smes = list("dir", "color", "pixel_x", "pixel_y", "name", "icon_state", "anchored", "req_access", "id_tag", "input_level", "output_level", "cable_layer"),
		/obj/machinery/light = list("start_with_cell"),
		/obj/machinery/atmospherics/pipe/smart = list("piping_layer", "pipe_color"),
		/obj/machinery/atmospherics/components/trinary/filter = list("flipped"),
		/obj/machinery/atmospherics/components/tank = list("open_ports"),
		/obj/machinery/duct = list("duct_layer", "duct_color", "connects"),
		/obj/structure/closet/crate = list("lid_icon", "lid_icon_state", "icon", "icon_door", "base_icon_state", "enable_door_overlay", "has_opened_overlay", "has_closed_overlay", "wall_mounted", "horizontal", "locked", "req_one_access", "contents_initialized"),
	)
	for(var/thing_type in saved_vars)
		var/datum/thing = allocate(thing_type)
		for(var/var_name in saved_vars[thing_type])
			TEST_ASSERT(var_name in thing.vars, "A saved hull writes [var_name], which [thing_type] does not have")
	// Allocating a mobile port would register it with the shuttle subsystem, so check it by compiling.
	var/obj/docking_port/mobile/voidcrew/port_vars = /obj/docking_port/mobile/voidcrew
	TEST_ASSERT(isnull(initial(port_vars.area_type)) || ispath(initial(port_vars.area_type)), "A port's area_type has moved")
	TEST_ASSERT(isnum(initial(port_vars.preferred_direction)) || isnull(initial(port_vars.preferred_direction)), "A port's preferred_direction has moved")
	TEST_ASSERT(isnum(initial(port_vars.port_direction)) || isnull(initial(port_vars.port_direction)), "A port's port_direction has moved")
	var/turf/closed/wall/wall_vars = /turf/closed/wall
	TEST_ASSERT_EQUAL(initial(wall_vars.sheet_type), /obj/item/stack/sheet/iron, "A wall's sheet_type has moved")
	var/turf/open/floor/mineral/gold/floor_vars = /turf/open/floor/mineral/gold
	TEST_ASSERT_NOTNULL(initial(floor_vars.floor_tile), "A floor's floor_tile has moved")

/// One class's entry on a bill, or null.
/datum/unit_test/voidcrew_ship_saves/proc/bill_class(list/survey, part_class)
	for(var/list/entry as anything in survey["bill"])
		if(entry["class"] == part_class)
			return entry
	return null

/// One line of one class's entry, or null.
/datum/unit_test/voidcrew_ship_saves/proc/bill_line(list/survey, part_class, line_name)
	var/list/entry = bill_class(survey, part_class)
	for(var/list/item as anything in entry?["items"])
		if(item["name"] == line_name)
			return item
	return null

/// A hull of a few known machines, in the test room.
/datum/unit_test/voidcrew_ship_saves/proc/check_survey()
	var/turf/tile = run_loc_floor_bottom_left
	// Earlier checks leave what they allocated here. Not effects: the test room's own marker is on this tile.
	for(var/obj/loose in tile)
		if(!iseffect(loose))
			qdel(loose)
	var/list/rooms = list()
	rooms[tile.loc] = TRUE
	var/obj/machinery/ship_combat/laser_turret/laser = allocate(/obj/machinery/ship_combat/laser_turret, tile)
	// The bill never uses a name a player gave it.
	laser.name = "Big Bertha"
	for(var/i in 1 to 3)
		allocate(/obj/machinery/porta_turret/ship_defense, tile)
	allocate(/obj/machinery/chem_dispenser, tile)
	allocate(/obj/machinery/chem_dispenser/drinks, tile)
	allocate(/obj/machinery/computer/voidcrew_cargo, tile)
	// Infrastructure, and things a save refuses, cost nothing and aren't counted.
	allocate(/obj/machinery/door/airlock, tile)
	allocate(/obj/machinery/portable_atmospherics/canister, tile)
	var/obj/machinery/ship_combat/laser_turret/hologram = allocate(/obj/machinery/ship_combat/laser_turret, tile)
	hologram.flags_1 |= HOLOGRAM_1
	var/list/jobs = list(list("name" = "Captain", "slots" = 2), list("name" = "Deckhand"))
	var/list/survey = ship_save_survey_block(tile, 1, 1, rooms, jobs)

	TEST_ASSERT_EQUAL(survey["crew"], 3, "Crew is not the total slots in the job definitions")
	TEST_ASSERT_EQUAL(survey["mass"], 0, "A tile that isn't hull has mass")
	var/list/classes = list()
	for(var/list/entry as anything in survey["bill"])
		classes += entry["class"]
	TEST_ASSERT_EQUAL(classes.Join(","), "combat,science,trade,misc", "The bill's classes are in the wrong order")
	TEST_ASSERT_EQUAL(bill_class(survey, "combat")["parts"], 3, "Wrong combat total")
	var/list/combat_items = bill_class(survey, "combat")["items"]
	var/list/first_combat = combat_items[1]
	TEST_ASSERT_EQUAL(first_combat["name"], "Defense turret", "The biggest line is not first")
	TEST_ASSERT_EQUAL(first_combat["count"], 3, "Wrong count of defense turrets")
	TEST_ASSERT_EQUAL(first_combat["parts"], 2, "Three defense turrets at 1 per 2 did not round up to 2")
	var/list/laser_line = bill_line(survey, "combat", "Laser turret")
	TEST_ASSERT_NOTNULL(laser_line, "The laser turret has no line under its own name")
	TEST_ASSERT_EQUAL(laser_line["count"], 1, "A hologram counted as a laser turret")
	TEST_ASSERT_EQUAL(bill_line(survey, "science", "Chem dispenser")?["parts"], 1, "A chem dispenser did not cost 1 science")
	TEST_ASSERT_EQUAL(bill_class(survey, "science")["parts"], 1, "A drink dispenser counted as a chem dispenser")
	TEST_ASSERT_EQUAL(bill_line(survey, "trade", "Cargo console")?["parts"], 1, "A cargo console did not cost 1 trade")
	var/list/others = bill_line(survey, "misc", "Other machines")
	TEST_ASSERT_EQUAL(others?["count"], 1, "Only the drink dispenser should be an other machine")
	TEST_ASSERT_EQUAL(others?["parts"], 1, "One other machine did not round up to a part")
	TEST_ASSERT_NULL(bill_line(survey, "misc", "Yard minimum"), "A hull over the minimum paid it")
	TEST_ASSERT_EQUAL(survey["total"], 6, "Wrong total")
	TEST_ASSERT_EQUAL(survey["cost"]["combat"], 3, "The charge disagrees with the bill")
	TEST_ASSERT_EQUAL(survey["cost"]["science"], 1, "The charge disagrees with the bill")
	TEST_ASSERT_EQUAL(survey["cost"]["trade"], 1, "The charge disagrees with the bill")
	TEST_ASSERT_EQUAL(survey["cost"]["misc"], 1, "The charge disagrees with the bill")
	TEST_ASSERT_EQUAL(ship_save_cost_text(survey["cost"]), "3 combat, 1 science, 1 trade and 1 misc parts", "Wrong words for the price")

	// A label wins, a subtype inherits, and a name with no label comes from the type.
	var/list/price = GLOB.ship_save_priced_machines[/obj/machinery/rnd/production/protolathe/department/science]
	TEST_ASSERT_EQUAL(price?["class"], "science", "A subtype did not inherit its price")
	TEST_ASSERT_NULL(GLOB.ship_save_priced_machines[/obj/machinery/chem_dispenser/drinks/beer], "A beer dispenser is on the price table")
	TEST_ASSERT_NULL(GLOB.ship_save_priced_machines[/obj/machinery/chem_master/condimaster], "A CondiMaster is on the price table")
	TEST_ASSERT_EQUAL(ship_save_machine_line_name(GLOB.ship_save_priced_machines[/obj/machinery/dna_scannernew], /obj/machinery/dna_scannernew), "DNA scanner", "A name from its type kept a text macro")

	for(var/obj/thing in tile)
		if(!iseffect(thing))
			qdel(thing)

/// The misc lines and the minimum, with nothing but numbers.
/datum/unit_test/voidcrew_ship_saves/proc/check_bill_rounding()
	var/list/kitted = ship_save_price_bill(list(), 650, 25)
	var/list/hull_line = bill_line(kitted, "misc", "Hull, 650 t")
	TEST_ASSERT_EQUAL(hull_line?["parts"], 5, "650 t did not round up to 5 parts")
	TEST_ASSERT_NULL(hull_line?["count"], "The hull line has a count")
	var/list/other_line = bill_line(kitted, "misc", "Other machines")
	TEST_ASSERT_EQUAL(other_line?["parts"], 2, "25 machines did not round up to 2 parts")
	TEST_ASSERT_EQUAL(other_line?["count"], 25, "The other machines line lost its count")
	TEST_ASSERT_EQUAL(kitted["total"], 7, "Wrong total for a kitted hull")
	var/list/exact = ship_save_price_bill(list(), SHIP_SAVE_TEST_MASS_PER_PART * 5, SHIP_SAVE_TEST_MACHINES_PER_PART)
	TEST_ASSERT_EQUAL(exact["total"], 6, "An exact multiple was rounded up again")

	// A tiny hull pays the minimum exactly, and the bill says why.
	var/list/tiny = ship_save_price_bill(list(), 150, 1)
	TEST_ASSERT_EQUAL(tiny["total"], SHIP_SAVE_TEST_PRICE_MIN, "A tiny hull did not pay exactly the minimum")
	TEST_ASSERT_EQUAL(tiny["cost"]["misc"], SHIP_SAVE_TEST_PRICE_MIN, "The minimum isn't paid in misc parts")
	TEST_ASSERT_EQUAL(bill_line(tiny, "misc", "Yard minimum")?["parts"], SHIP_SAVE_TEST_PRICE_MIN - 2, "The minimum line doesn't make up the difference")
	TEST_ASSERT_NULL(bill_line(tiny, "misc", "Yard minimum")?["count"], "The minimum line has a count")
	var/list/nothing = ship_save_price_bill(list(), 0, 0)
	TEST_ASSERT_EQUAL(length(bill_class(nothing, "misc")["items"]), 1, "An empty hull billed lines for nothing")
	TEST_ASSERT_EQUAL(nothing["total"], SHIP_SAVE_TEST_PRICE_MIN, "An empty hull did not pay the minimum")
	var/list/lines = list("Defense turret" = list("class" = "combat", "each" = 0.5, "count" = 6))
	TEST_ASSERT_EQUAL(bill_line(ship_save_price_bill(lines, 0, 0), "combat", "Defense turret")?["parts"], 3, "Six turrets at 1 per 2 are not one line of 3")

	set_parts(misc = SHIP_SAVE_TEST_PRICE_MIN)
	GLOB.ship_saves.refresh("tinyhull")
	TEST_ASSERT_NULL(GLOB.ship_saves.commit_save("tinyhull", make_snapshot(), null, 1, tiny), "A tiny hull could not pay the minimum")
	TEST_ASSERT_EQUAL(economy.total(), 0, "A tiny hull did not pay exactly the minimum")

/// Encodes rows given as text, one mark per character.
/datum/unit_test/voidcrew_ship_saves/proc/encode_rows(...)
	var/list/rows = list()
	for(var/text in args)
		var/list/row = list()
		for(var/i in 1 to length(text))
			row += copytext(text, i, i + 1)
		rows += list(row)
	return ship_save_encode_plan(rows)

/datum/unit_test/voidcrew_ship_saves/proc/check_plan()
	TEST_ASSERT_EQUAL(encode_rows(".....###oo"), "5.3#2o", "Runs are wrong")
	TEST_ASSERT_EQUAL(encode_rows("....", "..##", "....", "oo..", "...."), "2.2#//2o", "Empty rows and trailing empties were not trimmed")
	TEST_ASSERT_NULL(encode_rows("....", "...."), "An empty plan was not null")
	var/too_long = ""
	for(var/i in 1 to (SHIP_SAVE_TEST_PLAN_MAX / 10 + 1))
		too_long += "wswswswsws"
	TEST_ASSERT_NULL(encode_rows(too_long), "An oversized plan was sent")

	// A small known hull: priority on a shared tile, then walls, windows and plain floor.
	var/turf/corner = run_loc_floor_bottom_left
	var/turf/up_one = get_step(corner, NORTH)
	var/turf/wall_tile = get_step(up_one, EAST)
	var/turf/engine_tile = get_step(wall_tile, EAST)
	var/wall_tile_type = wall_tile.type
	var/list/rooms = list()
	rooms[corner.loc] = TRUE
	var/turf/second = get_step(corner, EAST)
	var/turf/third = get_step(second, EAST)
	var/turf/fourth = get_step(third, EAST)
	allocate(/obj/machinery/ship_combat/laser_turret, corner)
	allocate(/obj/machinery/chem_dispenser, corner)
	allocate(/obj/machinery/computer/voidcrew_cargo, corner)
	allocate(/obj/machinery/chem_dispenser, second)
	allocate(/obj/machinery/computer/voidcrew_cargo, second)
	allocate(/obj/structure/grille, second)
	allocate(/obj/machinery/computer/voidcrew_cargo, third)
	allocate(/obj/structure/grille, third)
	allocate(/obj/structure/grille, fourth)
	// A refused object draws nothing.
	allocate(/obj/structure/statue/gold/hos, up_one)
	allocate(/obj/machinery/power/shuttle_engine/ship, engine_tile)
	wall_tile.ChangeTurf(/turf/closed/wall)
	allocate(/obj/structure/grille, wall_tile)
	var/list/survey = ship_save_survey_block(corner, 4, 2, rooms, null)
	TEST_ASSERT_EQUAL(survey["plan"], "o#eo/wstg", "A small hull's plan is wrong")
	// Outside the owned rooms is empty, and an empty top row is trimmed.
	survey = ship_save_survey_block(corner, 4, 2, list(), null)
	TEST_ASSERT_NULL(survey["plan"], "A hull with no rooms has a plan")
	for(var/turf/tile as anything in list(corner, second, third, fourth, up_one, wall_tile, engine_tile))
		for(var/obj/thing in tile)
			if(!iseffect(thing))
				qdel(thing)
	wall_tile.ChangeTurf(wall_tile_type)

/datum/unit_test/voidcrew_ship_saves/proc/check_summary()
	TEST_ASSERT_NULL(ship_save_read_summary(null), "A row with no summary has a survey")
	var/bad_json = "{not json"
	TEST_ASSERT_NULL(ship_save_read_summary(bad_json), "Bad JSON has a survey")
	TEST_ASSERT_NULL(ship_save_read_summary("5"), "A number has a survey")
	TEST_ASSERT_NULL(ship_save_read_summary(json_encode(list(1, 2))), "A list has a survey")
	TEST_ASSERT_NULL(ship_save_read_summary(json_encode(list("mass" = "heavy", "crew" = 1, "total" = 1, "bill" = list()))), "A text mass has a survey")
	var/list/good = ship_save_read_summary(json_encode(make_survey(list("misc" = 5))))
	TEST_ASSERT_EQUAL(good?["mass"], 650, "A good summary lost its mass")
	TEST_ASSERT_EQUAL(good?["plan"], "2#/2o", "A good summary lost its plan")
	TEST_ASSERT(!("cost" in good), "A read summary can charge something")

	// Through the table: the row still lists, without a survey, and the screens get no survey keys.
	var/player_ckey = "summarytester"
	add_stored_save(player_ckey, 1)
	var/list/entry = store.saved["[player_ckey]|1"]
	var/list/meta = entry["meta"]
	meta["summary"] = "{not json"
	GLOB.ship_saves.refresh(player_ckey)
	var/list/row = GLOB.ship_saves.saved_row(player_ckey, 1)
	TEST_ASSERT_NOTNULL(row, "Bad JSON lost the row")
	TEST_ASSERT_NULL(row["survey"], "Bad JSON came back as a survey")
	var/list/listed = GLOB.ship_saves.saved_ship_entry(player_ckey, row, null)
	TEST_ASSERT_EQUAL(listed["slot"], 1, "An old row did not list")
	TEST_ASSERT(!("mass" in listed), "A row with no survey sent survey keys")
	TEST_ASSERT_NULL(GLOB.ship_saves.retrieve_denial(player_ckey, 1), "A row with no survey can't be retrieved")

/// What commit_save() is told a hull costs.
/datum/unit_test/voidcrew_ship_saves/proc/make_survey(list/cost)
	var/total = 0
	var/list/bill = list()
	for(var/part_class in cost)
		total += cost[part_class]
		bill += list(list("class" = part_class, "parts" = cost[part_class], "items" = list()))
	return list("mass" = 650, "crew" = 3, "plan" = "2#/2o", "bill" = bill, "total" = total, "cost" = cost)

/datum/unit_test/voidcrew_ship_saves/proc/check_part_plans()
	set_parts(combat = 2, science = 9, trade = 4)
	var/list/plan = economy.spend_any_parts("savetester", 12)
	TEST_ASSERT_NOTNULL(plan, "12 parts could not be paid from 15")
	TEST_ASSERT_EQUAL(plan["science"], 9, "The largest stack was not taken first")
	TEST_ASSERT_EQUAL(plan["trade"], 3, "The next largest stack was not taken second")
	TEST_ASSERT(!("combat" in plan), "A stack the price didn't reach was charged")
	TEST_ASSERT_EQUAL(economy.total(), 3, "The plan and the charge disagree")
	economy.refund_parts("savetester", plan)
	TEST_ASSERT_EQUAL(economy.total(), 15, "A refund did not put the parts back")
	TEST_ASSERT_NULL(economy.spend_any_parts("savetester", 16), "A price over everything held was paid")
	TEST_ASSERT_EQUAL(economy.total(), 15, "A refused price still took parts")

/datum/unit_test/voidcrew_ship_saves/proc/check_commit()
	var/player_ckey = "savetester"
	var/datum/ship_saves/saves = GLOB.ship_saves
	var/list/price = make_survey(list("combat" = 1, "science" = 2, "misc" = 3))
	saves.refresh(player_ckey)
	TEST_ASSERT_EQUAL(length(saves.saves_for(player_ckey)), 0, "A new player was not loaded with no saves")

	// Not enough parts: nothing is written.
	set_parts()
	TEST_ASSERT_EQUAL(saves.commit_save(player_ckey, make_snapshot(275), null, 2, price), "You need 1 combat, 2 science and 3 misc parts.", "A save with no parts went through")
	TEST_ASSERT_NULL(store.saved["[player_ckey]|2"], "A save nobody paid for reached the table")

	// Short of one class: plenty of the rest doesn't help, and nothing is taken.
	set_parts(combat = 50, science = 1, trade = 50, misc = 50)
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(275), null, 2, price), "A save short of one class went through")
	TEST_ASSERT_EQUAL(economy.total(), 151, "A refused save took parts")
	TEST_ASSERT_NULL(store.saved["[player_ckey]|2"], "A save short of one class reached the table")

	// A failed write takes nothing.
	set_parts(combat = 5, science = 5, trade = 5, misc = 5)
	store.fail_writes = TRUE
	TEST_ASSERT_EQUAL(saves.commit_save(player_ckey, make_snapshot(275), null, 2, price), "Shipyard records are offline.", "A failed write reported success")
	TEST_ASSERT_EQUAL(economy.total(), 20, "A failed write kept the payment")
	TEST_ASSERT_EQUAL(length(saves.saves_for(player_ckey)), 0, "A failed write reached the cache")
	store.fail_writes = FALSE
	TEST_ASSERT(!saves.retrievals[saves.slot_key(player_ckey, 2)], "A failed write kept the slot locked")

	// A failed read is not "no saves".
	var/list/loaded = saves.saves_for(player_ckey)
	TEST_ASSERT_NOTNULL(loaded, "The cache was lost")
	TEST_ASSERT_NULL(saves.saves_for("nobodyatall"), "An unloaded player reads as having no saves")

	// The chosen slot is used, and the matching classes pay.
	TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(275), null, 2, price), "A paid save failed")
	TEST_ASSERT_NOTNULL(store.saved["[player_ckey]|2"], "The save did not go to the chosen slot")
	TEST_ASSERT_NULL(store.saved["[player_ckey]|1"], "The save went to the lowest slot instead")
	TEST_ASSERT_EQUAL(economy.held["combat"], 4, "Combat parts were charged wrong")
	TEST_ASSERT_EQUAL(economy.held["science"], 3, "Science parts were charged wrong")
	TEST_ASSERT_EQUAL(economy.held["trade"], 5, "A class the hull doesn't need was charged")
	TEST_ASSERT_EQUAL(economy.held["misc"], 2, "Misc parts were charged wrong")
	TEST_ASSERT(!saves.retrievals[saves.slot_key(player_ckey, 2)], "A finished save kept the slot locked")
	var/list/entry = store.saved["[player_ckey]|2"]
	var/list/meta = entry["meta"]
	TEST_ASSERT_EQUAL(meta["tile_count"], 275, "The row has the wrong tile count")
	TEST_ASSERT_EQUAL(meta["ship_name"], "Test Hull", "The row has the wrong name")
	var/list/stored = json_decode(entry["payload"])
	TEST_ASSERT_EQUAL(meta["format_version"], stored["format"], "The row has the wrong format")
	TEST_ASSERT_EQUAL(meta["raw_bytes"], length(entry["payload"]), "The row has the wrong size")
	var/list/stored_summary = json_decode(meta["summary"])
	TEST_ASSERT_EQUAL(stored_summary["total"], 6, "The row's summary lost its total")
	TEST_ASSERT(!("cost" in stored_summary), "The row's summary kept the charge")
	var/list/row = saves.saved_row(player_ckey, 2)
	TEST_ASSERT_EQUAL(row?["survey"]["total"], 6, "The cached row lost its survey")

	// A locked slot takes no save and no parts, and neither does a slot that isn't one.
	var/parts_before = economy.total()
	TEST_ASSERT(saves.begin_retrieval(player_ckey, 3), "A free slot could not be locked")
	TEST_ASSERT_EQUAL(saves.commit_save(player_ckey, make_snapshot(275), null, 3, price), "Already under way.", "A save went to a locked slot")
	TEST_ASSERT_EQUAL(saves.slot_denial(player_ckey, 3), "Already under way.", "A locked slot was offered")
	saves.cancel_retrieval(player_ckey, 3)
	TEST_ASSERT_EQUAL(economy.total(), parts_before, "A save to a locked slot was charged")
	TEST_ASSERT_NULL(saves.slot_denial(player_ckey, 3), "A free slot was refused")
	for(var/bad_slot in list(0, SHIP_SAVE_TEST_SLOTS + 1, 1.5, "text", null))
		TEST_ASSERT_EQUAL(saves.slot_denial(player_ckey, bad_slot), "No such slot.", "Slot [bad_slot] was accepted")

/// Saving over a used slot: a new charge, one row, and nothing lost if it fails.
/datum/unit_test/voidcrew_ship_saves/proc/check_overwrite()
	var/player_ckey = "overwritetester"
	var/datum/ship_saves/saves = GLOB.ship_saves
	var/list/price = make_survey(list("misc" = 5))
	saves.refresh(player_ckey)
	set_parts(misc = 20)
	TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(10), null, 1, price), "The first save failed")
	var/key = saves.slot_key(player_ckey, 1)
	// The old row's source, as if saved from a real hull.
	var/datum/weakref/old_source = WEAKREF(allocate(/datum/ship_checkpoint))
	saves.live_sources[key] = old_source

	// A write that fails refunds and keeps everything about the old row.
	store.fail_writes = TRUE
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(99), null, 1, price), "A failed overwrite reported success")
	store.fail_writes = FALSE
	TEST_ASSERT_EQUAL(economy.total(), 15, "A failed overwrite kept the payment")
	TEST_ASSERT_EQUAL(saves.saved_row(player_ckey, 1)?["tile_count"], 10, "A failed overwrite changed the cached row")
	var/list/entry = store.saved["[player_ckey]|1"]
	TEST_ASSERT_EQUAL(entry["meta"]["tile_count"], 10, "A failed overwrite changed the stored row")
	TEST_ASSERT_EQUAL(saves.live_sources[key], old_source, "A failed overwrite lost the old row's source")

	// An overwrite replaces the row, charges again and forgets the old row's source.
	TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(99), null, 1, price), "An overwrite failed")
	TEST_ASSERT_EQUAL(economy.total(), 10, "An overwrite was not charged")
	entry = store.saved["[player_ckey]|1"]
	TEST_ASSERT_EQUAL(entry["meta"]["tile_count"], 99, "An overwrite did not replace the stored row")
	var/list/rows = saves.saves_for(player_ckey)
	TEST_ASSERT_EQUAL(length(rows), 1, "An overwrite appended a second row")
	TEST_ASSERT_EQUAL(saves.saved_row(player_ckey, 1)?["tile_count"], 99, "An overwrite did not replace the cached row")
	TEST_ASSERT(!saves.live_sources[key], "An overwrite kept the old row's source")

	// Overwrite only goes through what the cache knows: a row it can't see is not overwritten.
	saves.cache[player_ckey] = list()
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(5), null, 1, price), "A row the cache didn't show was overwritten")
	TEST_ASSERT_EQUAL(economy.total(), 10, "A refused write kept the payment")
	saves.refresh(player_ckey)

	// A used save stays locked until its row is gone, and a failed delete doesn't block the slot for good.
	saves.spend(player_ckey, 1)
	TEST_ASSERT(store.locked_during_remove, "The slot wasn't locked while its row was being deleted")
	TEST_ASSERT(!saves.retrievals[key], "A finished delete kept the slot locked")
	TEST_ASSERT_NULL(store.saved["[player_ckey]|1"], "A used save stayed in the table")
	saves.refresh(player_ckey)
	TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(7), null, 1, price), "A freed slot could not be saved to")
	store.fail_removes = TRUE
	saves.spend(player_ckey, 1)
	store.fail_removes = FALSE
	TEST_ASSERT(!saves.retrievals[key], "A failed delete kept the slot locked")
	TEST_ASSERT_NOTNULL(store.saved["[player_ckey]|1"], "The failed delete removed the row anyway")
	TEST_ASSERT_NULL(saves.saved_row(player_ckey, 1), "A spent save stayed in the cache")
	TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(8), null, 1, price), "A failed delete blocked the slot")
	TEST_ASSERT(!saves.spent_rows[key], "A new save left the slot marked as spent")
	entry = store.saved["[player_ckey]|1"]
	TEST_ASSERT_EQUAL(entry["meta"]["tile_count"], 8, "A failed delete's row was not replaced")

/// Puts a row in the table, as if saved in an earlier round unless told otherwise.
/datum/unit_test/voidcrew_ship_saves/proc/add_stored_save(player_ckey, slot, saved_round = SHIP_SAVE_TEST_ROUND - 1, format = SHIP_SAVE_TEST_FORMAT)
	store.saved["[player_ckey]|[slot]"] = list(
		"meta" = list("ship_name" = "Test Hull", "ship_class" = "Test Class", "tile_count" = 10, "format_version" = format, "saved_round" = saved_round, "raw_bytes" = 1),
		"payload" = GLOB.ship_saves.encode(make_snapshot()),
	)

/datum/unit_test/voidcrew_ship_saves/proc/check_retrieval_rules()
	var/player_ckey = "retrievetester"
	var/datum/ship_saves/saves = GLOB.ship_saves
	add_stored_save(player_ckey, 1)
	add_stored_save(player_ckey, 2, saved_round = SHIP_SAVE_TEST_ROUND)
	add_stored_save(player_ckey, 3, format = SHIP_SAVE_TEST_FORMAT + 1)
	saves.refresh(player_ckey)

	// Every denial.
	TEST_ASSERT_NULL(saves.retrieve_denial(player_ckey, 1), "A save from an earlier round was refused")
	TEST_ASSERT_NULL(saves.retrieve_denial(player_ckey, 2), "A save from this round with no ship behind it was refused")
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, 3), "This record can't be read.", "An unknown format was offered")
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, SHIP_SAVE_TEST_SLOTS + 1), "No such record.", "An empty slot was offered")
	TEST_ASSERT_EQUAL(saves.retrieve_denial("nobodyatall", 1), "No such record.", "An unloaded player was offered a save")
	store.offline = TRUE
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, 1), "Shipyard records are offline.", "A save was offered with the records down")
	store.offline = FALSE

	// One retrieval at a time, whoever asks.
	TEST_ASSERT(saves.begin_retrieval(player_ckey, 1), "A free save could not be claimed")
	TEST_ASSERT(!saves.begin_retrieval(player_ckey, 1), "One save was claimed twice")
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, 1), "Already under way.", "A claimed save was offered")
	TEST_ASSERT_NULL(saves.retrieve_denial(player_ckey, 1, allow_busy = TRUE), "The holder of a claim was refused by it")
	TEST_ASSERT(saves.begin_retrieval(player_ckey, 2), "A claim on one slot blocked another")
	saves.cancel_retrieval(player_ckey, 2)
	saves.cancel_retrieval(player_ckey, 1)
	TEST_ASSERT_NULL(saves.retrieve_denial(player_ckey, 1), "A cancelled retrieval kept its claim")

	// A read that can't be used costs nothing and says why.
	store.fail_reads = TRUE
	TEST_ASSERT_EQUAL(saves.read_save(player_ckey, 1), "Shipyard records are offline.", "A failed read was not reported")
	store.fail_reads = FALSE
	var/list/entry = store.saved["[player_ckey]|1"]
	var/good_payload = entry["payload"]
	entry["payload"] = "not json"
	TEST_ASSERT_EQUAL(saves.read_save(player_ckey, 1), "This record can't be read.", "A junk payload was not reported")
	entry["payload"] = good_payload
	var/datum/ship_checkpoint/read_back = saves.read_save(player_ckey, 1)
	TEST_ASSERT(istype(read_back), "A good payload did not read: [read_back]")
	TEST_ASSERT_EQUAL(read_back.captain_ckey, player_ckey, "A read save does not know its owner")
	qdel(read_back)
	TEST_ASSERT_NOTNULL(store.saved["[player_ckey]|1"], "Reading a save spent it")

	// Spending clears the row, the cache and the claim, and frees the slot.
	TEST_ASSERT(saves.begin_retrieval(player_ckey, 1), "A free save could not be claimed")
	saves.spend(player_ckey, 1)
	TEST_ASSERT_NULL(saves.saved_row(player_ckey, 1), "A spent save stayed in the cache")
	TEST_ASSERT_NULL(store.saved["[player_ckey]|1"], "A spent save stayed in the table")
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, 1), "No such record.", "A spent save was still offered")
	TEST_ASSERT(saves.begin_retrieval(player_ckey, 1), "Spending kept the claim")
	saves.cancel_retrieval(player_ckey, 1)

	// A delete that fails must not hand the save back on the next read.
	store.fail_removes = TRUE
	saves.spend(player_ckey, 2)
	store.fail_removes = FALSE
	TEST_ASSERT_NOTNULL(store.saved["[player_ckey]|2"], "The failed delete removed the row anyway")
	saves.refresh(player_ckey)
	TEST_ASSERT_NULL(saves.saved_row(player_ckey, 2), "A later read gave back a spent save")

/// A lobby player with nobody connected: joining a ship needs a real client, so seating only records.
/mob/dead/new_player/ship_save_test
	var/obj/structure/overmap/ship/seated_on
	var/datum/job/seated_as

/mob/dead/new_player/ship_save_test/select_ship()
	return

/mob/dead/new_player/ship_save_test/AttemptSpawnOnShip(datum/job/job, obj/structure/overmap/ship/joined_ship)
	seated_on = joined_ship
	seated_as = job
	return TRUE

/datum/ship_checkpoint_ui/registry_test/create_retrieval_job(mob/living/user, datum/ship_checkpoint/snapshot, slot)
	return new /datum/checkpoint_construction/saved(src, snapshot, user, slot, manual_jobs)

/// Sees the question, and can change things while the box is open.
/datum/ship_checkpoint_ui/registry_test/save_prompt
	var/last_prompt
	var/datum/callback/while_open

/datum/ship_checkpoint_ui/registry_test/save_prompt/Destroy()
	while_open = null
	return ..()

/datum/ship_checkpoint_ui/registry_test/save_prompt/confirm_save(mob/user, prompt_text, title = "Shipyard")
	last_prompt = prompt_text
	while_open?.Invoke()
	return ..()

/// The panel and the password, on a real hull in a real bay.
/datum/unit_test/voidcrew_ship_saves_hull
	parent_type = /datum/unit_test/voidcrew_outpost_management
	var/datum/ship_save_store/old_store
	var/datum/ship_saves/old_saves
	var/datum/ship_economy_db/old_economy
	var/datum/ship_save_store/fake/store
	var/datum/ship_economy_db/fake/economy
	var/obj/structure/overmap/ship/test_ship

/datum/unit_test/voidcrew_ship_saves_hull/New()
	. = ..()
	old_store = GLOB.ship_save_store
	old_saves = GLOB.ship_saves
	old_economy = GLOB.ship_economy_db
	store = new
	economy = new
	GLOB.ship_save_store = store
	GLOB.ship_saves = new /datum/ship_saves
	GLOB.ship_economy_db = economy

/datum/unit_test/voidcrew_ship_saves_hull/Destroy()
	if(!QDELETED(test_ship))
		qdel(test_ship)
	GLOB.ship_save_store = old_store
	GLOB.ship_saves = old_saves
	GLOB.ship_economy_db = old_economy
	return ..()

/datum/unit_test/voidcrew_ship_saves_hull/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "savecaptain"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/obj/machinery/computer/ship_checkpoint/terminal = outpost_bay_shipyard_console(LAZYACCESS(home.bay_berths, 1))
	TEST_ASSERT_NOTNULL(terminal, "The ship bay has no shipyard console")
	var/turf/terminal_turf = get_turf(terminal)
	var/mob/living/carbon/human/captain = make_player(terminal_turf, "savecaptain")
	var/mob/living/carbon/human/deckhand = make_player(terminal_turf, "savedeckhand")
	test_ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(test_ship, "Could not create the hull")
	test_ship.enlist_crewmember(captain)
	test_ship.claimed_captain = captain.mind
	test_ship.enlist_crewmember(deckhand)
	var/datum/ship_checkpoint_ui/registry_test/save_prompt/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	var/datum/ship_checkpoint_ui/registry_test/deckhand_panel = allocate(__IMPLIED_TYPE__, home, terminal, deckhand)
	TEST_ASSERT_NOTNULL(GLOB.ship_saves.saves_for(captain.ckey), "Opening the panel did not load the captain's saves")

	// Not in the bay, whatever else is true. A berth is not in bay_berths, so it arrives as null.
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, null), "Dock your ship in a ship bay first.", "A berthed ship could be saved")
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(test_ship)
	TEST_ASSERT_NOTNULL(bay, "The hull was not given a bay")
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay), "Dock your ship in a ship bay first.", "A ship that hasn't landed could be saved")
	adjust_reserve_dock_to_shuttle(bay.dock, test_ship.shuttle)
	test_ship.shuttle.mode = SHUTTLE_PREARRIVAL
	test_ship.shuttle.initiate_docking(bay.dock)
	test_ship.shuttle.mode = SHUTTLE_IDLE
	test_ship.docked = home
	test_ship.forceMove(home)
	test_ship.state = "idle"
	bay.on_ship_docked(test_ship)
	TEST_ASSERT(bay.is_ship_present(), "The hull did not land in the bay")

	TEST_ASSERT_NULL(panel.saved_ship_denial(captain, bay, 1), "The captain could not save a docked ship")
	TEST_ASSERT_EQUAL(deckhand_panel.saved_ship_denial(deckhand, bay, 1), "Only the ship's current captain can save it.", "A deckhand could save the ship")

	// No cryopods, no way to spawn on it later.
	var/list/spawn_points = test_ship.shuttle.spawn_points
	test_ship.shuttle.spawn_points = list()
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay, 1), "This hull has no cryopods.", "A hull without cryopods could be saved")
	test_ship.shuttle.spawn_points = spawn_points

	// The survey of a real hull.
	var/list/survey = test_ship.save_survey(fresh = TRUE)
	TEST_ASSERT_NOTNULL(survey, "A docked hull has no survey")
	TEST_ASSERT_EQUAL(survey["mass"], test_ship.calculate_mass(), "The survey's mass isn't the hull's")
	TEST_ASSERT(survey["total"] >= SHIP_SAVE_TEST_PRICE_MIN, "A real hull is priced under the minimum")
	var/plan = survey["plan"]
	TEST_ASSERT(istext(plan) && length(plan), "A real hull has no plan")
	TEST_ASSERT(!findtext(plan, "./") && copytext(plan, -1) != "." && copytext(plan, -1) != "/" && copytext(plan, 1, 2) != "/", "The plan was not trimmed: [plan]")
	TEST_ASSERT(survey == test_ship.save_survey(), "An open window rescanned the hull inside its cache time")

	// A slot is a whole number from 1 to 3.
	set_each_part(40)
	for(var/bad_slot in list(0, SHIP_SAVE_TEST_SLOTS + 1, 1.5, "text", null))
		TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay, bad_slot), "No such slot.", "Slot [bad_slot] was accepted")
		TEST_ASSERT(!panel.save_ship(captain, bay, bad_slot), "A ship was saved to slot [bad_slot]")
		TEST_ASSERT_EQUAL(panel.error, "No such slot.", "Slot [bad_slot] was refused with the wrong words")
	TEST_ASSERT_EQUAL(length(store.saved), 0, "A bad slot reached the table")

	// Declining costs nothing; accepting charges once and saves the real hull to the chosen slot.
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_ship(captain, bay, 2), "Declining still saved the ship")
	TEST_ASSERT_EQUAL(length(store.saved), 0, "Declining reached the table")
	TEST_ASSERT_EQUAL(parts_held(), 160, "Declining was charged")
	TEST_ASSERT_EQUAL(panel.last_prompt, "Save [test_ship.name] to slot 2 for [ship_save_cost_text(survey["cost"])]?", "Wrong question for a new slot")
	panel.accept_save = TRUE
	TEST_ASSERT(panel.save_ship(captain, bay, 2), "Saving failed: [panel.error]")
	TEST_ASSERT_NULL(panel.error, "A successful save left an error")
	TEST_ASSERT_EQUAL(panel.notice, "[test_ship.name] saved.", "A successful save said nothing")
	TEST_ASSERT(!panel.working, "The panel stayed busy after saving")
	var/list/entry = store.saved["savecaptain|2"]
	TEST_ASSERT_NOTNULL(entry, "The save did not reach slot 2")
	TEST_ASSERT_NULL(store.saved["savecaptain|1"], "The save ignored the chosen slot")
	TEST_ASSERT_EQUAL(parts_held(), 160 - survey["total"], "The hull was charged the wrong price")
	for(var/list/billed as anything in survey["bill"])
		TEST_ASSERT_EQUAL(economy.held[billed["class"]], 40 - billed["parts"], "Wrong charge in [billed["class"]] parts")
	var/datum/weakref/live_source = GLOB.ship_saves.live_sources[GLOB.ship_saves.slot_key("savecaptain", 2)]
	TEST_ASSERT_EQUAL(live_source?.resolve(), test_ship, "The save does not remember the hull it came from")

	// What was stored is a usable copy with nothing per machine in it.
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(entry["payload"])
	TEST_ASSERT_NOTNULL(decoded, "The stored hull did not decode")
	TEST_ASSERT_EQUAL(owned_tiles(test_ship.shuttle), decoded.owned_tile_count(), "The stored hull lost tiles")
	TEST_ASSERT_EQUAL(decoded.class_name, test_ship.source_template.short_name, "The stored hull lost its class")
	TEST_ASSERT_EQUAL(length(decoded.jobs), length(test_ship.job_definitions), "The stored hull lost its roster")
	var/datum/parsed_map/parsed = new(decoded.tgm)
	TEST_ASSERT_EQUAL(parsed.bounds?[MAP_MAXX], decoded.width, "The stored map does not read back")
	qdel(parsed)
	var/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/template = new(decoded)
	TEST_ASSERT_EQUAL(template.short_name, test_ship.source_template.short_name, "The rebuilt template lost its class")
	TEST_ASSERT_EQUAL(length(template.job_slots), length(decoded.jobs), "The rebuilt template lost its roster")
	qdel(template)
	qdel(decoded)

	// A full set of slots is no refusal: any of them can be overwritten. Records offline still are.
	var/list/rows = GLOB.ship_saves.saves_for(captain.ckey)
	for(var/slot in list(1, 3))
		rows += list(list("slot" = slot, "ship_name" = "Filler", "ship_class" = null, "saved_round" = 1))
	TEST_ASSERT_NULL(panel.saved_ship_denial(captain, bay, 1), "Full slots were refused")
	TEST_ASSERT(panel.save_ship(captain, bay, 1), "A used slot could not be overwritten: [panel.error]")
	TEST_ASSERT_EQUAL(panel.last_prompt, "Overwrite Filler with [test_ship.name] for [ship_save_cost_text(survey["cost"])]?", "Wrong question for a used slot")
	TEST_ASSERT_EQUAL(parts_held(), 160 - survey["total"] * 2, "An overwrite was not charged again")
	TEST_ASSERT_EQUAL(GLOB.ship_saves.saved_row(captain.ckey, 1)["ship_name"], test_ship.name, "An overwrite left the old row in the cache")
	TEST_ASSERT_EQUAL(length(store.saved), 2, "An overwrite left the wrong rows in the table")

	// A locked slot is refused, and so is one that changes while the box is open.
	GLOB.ship_saves.refresh(captain.ckey)
	var/parts_before = parts_held()
	TEST_ASSERT(GLOB.ship_saves.begin_retrieval(captain.ckey, 1), "A free slot could not be locked")
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay, 1), "Already under way.", "A locked slot could be overwritten")
	TEST_ASSERT(!panel.save_ship(captain, bay, 1), "A locked slot was overwritten")
	GLOB.ship_saves.cancel_retrieval(captain.ckey, 1)
	panel.while_open = CALLBACK(src, PROC_REF(change_slot), captain.ckey, 3)
	TEST_ASSERT(!panel.save_ship(captain, bay, 3), "A slot that changed under the box was written")
	TEST_ASSERT_EQUAL(panel.error, "That slot changed. Try again.", "A changed slot gave the wrong refusal")
	TEST_ASSERT(!panel.working, "A refused save left the panel busy")
	panel.while_open = null
	TEST_ASSERT_EQUAL(parts_held(), parts_before, "A refused save was charged")
	TEST_ASSERT_NULL(store.saved["savecaptain|3"], "A refused save reached the table")
	GLOB.ship_saves.refresh(captain.ckey)
	TEST_ASSERT_EQUAL(panel.saved_ship_changed_denial(captain, bay, null, 1), "The docked ship changed. Try again.", "A ship swapped under the box was saved")

	GLOB.ship_saves.cache -= captain.ckey
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay, 1), "Shipyard records are offline.", "An unloaded player read as having slots")

	// The panel's data never needs the database, and matches what the screen is promised.
	GLOB.ship_saves.refresh(captain.ckey)
	economy.parts_cache[captain.ckey] = list("combat" = 1, "science" = 2, "trade" = 3, "misc" = 4)
	var/list/saved_ships = panel.saved_ships_data(captain)
	TEST_ASSERT_EQUAL(saved_ships["slots"], SHIP_SAVE_TEST_SLOTS, "The panel has the wrong slot count")
	TEST_ASSERT_EQUAL(saved_ships["parts"]["trade"], 3, "The panel does not show parts by class")
	TEST_ASSERT_EQUAL(length(saved_ships["saves"]), 2, "The panel did not list the saves")
	var/list/listed_save = saved_ships["saves"][1]
	TEST_ASSERT_EQUAL(listed_save["slot"], 1, "The first listed save is not in slot 1")
	TEST_ASSERT_EQUAL(listed_save["name"], test_ship.name, "A listed save lost its name")
	TEST_ASSERT_EQUAL(listed_save["mass"], survey["mass"], "A listed save lost its mass")
	TEST_ASSERT_EQUAL(listed_save["locked"], 0, "A free save is listed as locked")
	TEST_ASSERT(!("cost" in listed_save), "A listed save carries the charge")
	var/list/listed_ships = saved_ships["ships"]
	TEST_ASSERT_EQUAL(length(listed_ships), 1, "The panel did not list the docked ship")
	var/list/listed_ship = listed_ships[1]
	TEST_ASSERT_EQUAL(listed_ship["total"], survey["total"], "The price on the screen differs from the price charged")
	TEST_ASSERT_EQUAL(listed_ship["class"], test_ship.source_template.short_name, "The docked ship lost its class")
	TEST_ASSERT(!("cost" in listed_ship), "The docked ship carries the charge")
	TEST_ASSERT(GLOB.ship_saves.begin_retrieval(captain.ckey, 1), "A free save could not be locked")
	var/list/locked_view = panel.saved_ships_data(captain)
	var/list/locked_save = locked_view["saves"][1]
	TEST_ASSERT_EQUAL(locked_save["locked"], 1, "A locked save is not listed as locked")
	GLOB.ship_saves.cancel_retrieval(captain.ckey, 1)
	var/list/deckhand_view = panel.saved_ships_data(deckhand)
	TEST_ASSERT_EQUAL(length(deckhand_view["ships"]), 0, "The panel offered a deckhand the ship")

	check_password(captain, deckhand)

/datum/unit_test/voidcrew_ship_saves_hull/proc/set_parts(misc)
	economy.held = list("combat" = 0, "science" = 0, "trade" = 0, "misc" = misc)

/datum/unit_test/voidcrew_ship_saves_hull/proc/set_each_part(amount)
	economy.held = list("combat" = amount, "science" = amount, "trade" = amount, "misc" = amount)

/// Tiles in the rooms this hull owns.
/datum/unit_test/voidcrew_ship_saves_hull/proc/owned_tiles(obj/docking_port/mobile/port)
	. = 0
	for(var/area/room as anything in hull_owned_areas(port))
		. += length(room.get_turfs_by_zlevel(port.z))

/// Something else writes to the slot while the confirm box is open.
/datum/unit_test/voidcrew_ship_saves_hull/proc/change_slot(player_ckey, slot)
	var/list/rows = GLOB.ship_saves.saves_for(player_ckey)
	rows += list(list("slot" = slot, "ship_name" = "Interloper", "ship_class" = null, "saved_round" = 1))

/datum/unit_test/voidcrew_ship_saves_hull/proc/parts_held()
	return economy.total()

/datum/unit_test/voidcrew_ship_saves_hull/proc/check_password(mob/living/carbon/human/captain, mob/living/carbon/human/deckhand)
	// Fleet hulls stay public; the test hull must not be one, or nothing here is charged.
	TEST_ASSERT(test_ship.can_have_join_password(), "The test hull cannot carry a password")
	set_parts(10)
	test_ship.join_password = null
	TEST_ASSERT(test_ship.buy_join_password("hunter", captain), "A paid password was refused")
	TEST_ASSERT_EQUAL(test_ship.join_password, "hunter", "The password was not set")
	TEST_ASSERT_EQUAL(parts_held(), 10 - SHIP_SAVE_TEST_PASSWORD_PRICE, "A new password was not charged once")
	TEST_ASSERT(test_ship.buy_join_password(" HUNTER ", captain), "Entering the same password failed")
	TEST_ASSERT_EQUAL(parts_held(), 10 - SHIP_SAVE_TEST_PASSWORD_PRICE, "An unchanged password was charged")
	TEST_ASSERT(test_ship.buy_join_password("", captain), "Clearing the password failed")
	TEST_ASSERT_NULL(test_ship.join_password, "The password was not cleared")
	TEST_ASSERT_EQUAL(parts_held(), 10 - SHIP_SAVE_TEST_PASSWORD_PRICE, "Clearing the password was charged")

	// Can't pay: nothing changes.
	set_parts(SHIP_SAVE_TEST_PASSWORD_PRICE - 1)
	TEST_ASSERT(!test_ship.buy_join_password("hunter", captain), "A password nobody could pay for was set")
	TEST_ASSERT_NULL(test_ship.join_password, "An unpaid password took effect")
	TEST_ASSERT_EQUAL(parts_held(), SHIP_SAVE_TEST_PASSWORD_PRICE - 1, "A failed payment took parts")

	// Not the captain by the time the payment clears: the parts go back.
	set_parts(10)
	TEST_ASSERT(!test_ship.buy_join_password("hunter", deckhand), "A deckhand set a password")
	TEST_ASSERT_NULL(test_ship.join_password, "A deckhand's password took effect")
	TEST_ASSERT_EQUAL(parts_held(), 10, "The refund for a lost captaincy did not happen")

	// set_join_password itself stays free.
	TEST_ASSERT(test_ship.set_join_password("direct", captain), "The free setter was refused")
	TEST_ASSERT_EQUAL(parts_held(), 10, "The free setter charged")

/// Getting a saved ship back: built by drones in a bay, and loaded whole from the lobby.
/datum/unit_test/voidcrew_ship_saves_hull/retrieval
	var/old_round_id
	var/old_ticker_state
	var/list/obj/structure/overmap/ship/retrieved_ships = list()
	var/saved_name
	var/saved_class
	var/saved_jobs

/datum/unit_test/voidcrew_ship_saves_hull/retrieval/New()
	. = ..()
	old_round_id = GLOB.round_id
	GLOB.round_id = "[SHIP_SAVE_TEST_ROUND]"
	old_ticker_state = SSticker.current_state

/datum/unit_test/voidcrew_ship_saves_hull/retrieval/Destroy()
	GLOB.round_id = old_round_id
	SSticker.current_state = old_ticker_state
	for(var/obj/structure/overmap/ship/ship as anything in retrieved_ships)
		if(!QDELETED(ship))
			qdel(ship)
	return ..()

/datum/unit_test/voidcrew_ship_saves_hull/retrieval/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "savecaptain"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/obj/machinery/computer/ship_checkpoint/terminal = outpost_bay_shipyard_console(LAZYACCESS(home.bay_berths, 1))
	TEST_ASSERT_NOTNULL(terminal, "The ship bay has no shipyard console")
	var/mob/living/carbon/human/captain = make_player(get_turf(terminal), "savecaptain")
	test_ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(test_ship, "Could not create the hull")
	test_ship.enlist_crewmember(captain)
	test_ship.claimed_captain = captain.mind
	fit_source(test_ship.shuttle)
	var/datum/ship_checkpoint_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(test_ship)
	TEST_ASSERT_NOTNULL(bay, "The hull was not given a bay")
	adjust_reserve_dock_to_shuttle(bay.dock, test_ship.shuttle)
	test_ship.shuttle.mode = SHUTTLE_PREARRIVAL
	test_ship.shuttle.initiate_docking(bay.dock)
	test_ship.shuttle.mode = SHUTTLE_IDLE
	test_ship.docked = home
	test_ship.forceMove(home)
	test_ship.state = "idle"
	bay.on_ship_docked(test_ship)

	// A save made this round waits for the ship it came from.
	set_each_part(40)
	TEST_ASSERT(panel.save_ship(captain, bay, 1), "Saving failed: [panel.error]")
	saved_name = test_ship.name
	saved_class = test_ship.source_template.short_name
	saved_jobs = length(test_ship.job_definitions)
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "The original hull is still in service.", "A ship was offered while the one it came from is in service")

	// The same save as made last round, so with no ship behind it, in the other slots here and in a lobby
	// player's first. Slot 1 keeps its source, and is free once that hull is lost.
	var/list/first = store.saved["savecaptain|1"]
	var/list/first_meta = first["meta"]
	first_meta["saved_round"] = SHIP_SAVE_TEST_ROUND - 1
	for(var/slot in 2 to SHIP_SAVE_TEST_SLOTS)
		store.saved["savecaptain|[slot]"] = list("meta" = first_meta.Copy(), "payload" = first["payload"])
	store.saved["savelobby|1"] = list("meta" = first_meta.Copy(), "payload" = first["payload"])
	GLOB.ship_saves.refresh("savecaptain")
	GLOB.ship_saves.refresh("savelobby")

	// The source is still in the bay.
	var/list/panel_data = panel.saved_ships_data(captain)
	var/list/listed_saves = panel_data["saves"]
	var/list/second_listed = listed_saves[2]
	TEST_ASSERT_EQUAL(second_listed["denial"], "The ship bay is occupied.", "The panel offered a save with the bay full")
	TEST_ASSERT(!panel.retrieve_ship(captain, 2), "A save was built with the bay full")
	TEST_ASSERT_EQUAL(panel.error, "The ship bay is occupied.", "A full bay gave the wrong refusal")
	vacate_bay(home)
	TEST_ASSERT_NULL(panel.saved_ship_retrieve_denial(captain, 1), "The panel refused a save whose hull was lost, with the bay empty")

	// Stopped before the first piece: the save is untouched and can be tried again.
	TEST_ASSERT(panel.retrieve_ship(captain, 1), "Could not start building a save: [panel.error]")
	TEST_ASSERT_EQUAL(panel.notice, "Construction started.", "Starting a build said nothing")
	TEST_ASSERT(!panel.working, "The panel stayed busy after starting a build")
	var/datum/checkpoint_construction/saved/job = home.checkpoint_jobs[1]
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "Already under way.", "A save was offered while it was being built")
	TEST_ASSERT(!panel.retrieve_ship(captain, 1), "A second click started another build")
	TEST_ASSERT_NOTNULL(store.saved["savecaptain|1"], "The save was spent before the first piece")
	job.abort("Stopped for the test.")
	TEST_ASSERT(QDELETED(job), "A stopped build kept running")
	TEST_ASSERT_NOTNULL(store.saved["savecaptain|1"], "A build stopped before its first piece spent the save")
	TEST_ASSERT_NOTNULL(GLOB.ship_saves.saved_row("savecaptain", 1), "A build stopped before its first piece lost the cached save")
	TEST_ASSERT_NULL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "A stopped build kept its claim on the save")
	TEST_ASSERT(bay.is_available(), "A stopped build kept the bay")

	// Past the first piece the save is gone, and stopping the build does not bring it back.
	TEST_ASSERT(panel.retrieve_ship(captain, 2), "Could not start building a save: [panel.error]")
	job = home.checkpoint_jobs[1]
	job.fast_forward(1)
	TEST_ASSERT(job.committed, "The first piece did not commit the build")
	TEST_ASSERT_NULL(store.saved["savecaptain|2"], "The first piece did not spend the save")
	TEST_ASSERT_NULL(GLOB.ship_saves.saved_row("savecaptain", 2), "The first piece left the save in the cache")
	job.abort("Stopped for the test.")
	TEST_ASSERT_NULL(store.saved["savecaptain|2"], "Stopping a build gave back a spent save")
	TEST_ASSERT_NULL(GLOB.ship_saves.saved_row("savecaptain", 2), "Stopping a build put a spent save back in the cache")
	var/deadline = world.time + 30 SECONDS
	UNTIL(bay.is_available() || world.time > deadline)
	TEST_ASSERT(bay.is_available(), "A terminated build never gave the bay back")

	// A whole build.
	TEST_ASSERT(panel.retrieve_ship(captain, 1), "Could not start building a save: [panel.error]")
	job = home.checkpoint_jobs[1]
	job.fast_forward()
	TEST_ASSERT(QDELETED(job), "The build did not finish")
	TEST_ASSERT_NULL(store.saved["savecaptain|1"], "A finished build left its save in the table")
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT_NOTNULL(rebuilt, "The finished build is not in the bay")
	retrieved_ships += rebuilt
	TEST_ASSERT(rebuilt.is_ship_captain(captain), "The saving captain does not command the finished ship")
	check_retrieved(rebuilt, "Console")

	// The lobby: a read that fails costs nothing.
	SSticker.current_state = GAME_STATE_PLAYING
	var/mob/dead/new_player/ship_save_test/lobby = allocate(__IMPLIED_TYPE__)
	lobby.key = "savelobby"
	store.fail_reads = TRUE
	GLOB.ship_saves.launch(lobby, 1)
	store.fail_reads = FALSE
	TEST_ASSERT_NULL(lobby.seated_on, "A failed read seated the player on something")
	TEST_ASSERT(!lobby.spawning_ship, "A failed read left the player stuck preparing a ship")
	TEST_ASSERT_NOTNULL(store.saved["savelobby|1"], "A failed read spent the save")
	TEST_ASSERT_NULL(GLOB.ship_saves.retrieve_denial("savelobby", 1), "A failed read kept its claim on the save")

	// The lobby: the ship loads, the save goes, and the player is seated as the first job.
	GLOB.ship_saves.launch(lobby, 1)
	var/obj/structure/overmap/ship/launched = lobby.seated_on
	TEST_ASSERT_NOTNULL(launched, "The lobby did not seat the player on the saved ship")
	retrieved_ships += launched
	TEST_ASSERT_EQUAL(lobby.seated_as, launched.job_slots[1], "The player was not seated in the ship's first job")
	TEST_ASSERT(launched.password_cleared_ckeys["savelobby"], "The player is not cleared to board their own ship")
	TEST_ASSERT_NULL(store.saved["savelobby|1"], "The lobby did not spend the save")
	TEST_ASSERT_NULL(GLOB.ship_saves.saved_row("savelobby", 1), "The lobby left the save in the cache")
	check_retrieved(launched, "Lobby")

	// The same save after its room and floor types were removed from the code still loads whole.
	var/list/stale_data = json_decode(first["payload"])
	var/stale_tgm = stale_data["tgm"]
	var/regex/floor_path = new(@"^/turf/open/floor/[\w/]*", "gm")
	TEST_ASSERT(floor_path.Find(stale_tgm), "The saved hull has no floor to remove")
	var/gone_floor = floor_path.match
	var/regex/room_path = new(@"^/area/shuttle/voidcrew[\w/]*", "gm")
	TEST_ASSERT(room_path.Find(stale_tgm), "The saved hull has no room to remove")
	var/gone_room = room_path.match
	stale_data["tgm"] = replacetext(replacetext(stale_tgm, gone_floor, "/turf/this_was_removed_long_ago"), gone_room, "/area/shuttle/voidcrew/this_was_removed_long_ago")
	store.saved["savestale|1"] = list("meta" = first_meta.Copy(), "payload" = json_encode(stale_data))
	GLOB.ship_saves.refresh("savestale")
	var/mob/dead/new_player/ship_save_test/stale_lobby = allocate(__IMPLIED_TYPE__)
	stale_lobby.key = "savestale"
	GLOB.ship_saves.launch(stale_lobby, 1)
	var/obj/structure/overmap/ship/stale_ship = stale_lobby.seated_on
	TEST_ASSERT_NOTNULL(stale_ship, "A save with removed types did not load")
	retrieved_ships += stale_ship
	TEST_ASSERT_NULL(store.saved["savestale|1"], "A save with removed types was not spent")
	TEST_ASSERT_EQUAL(owned_tiles(stale_ship.shuttle), first_meta["tile_count"], "A save with removed types lost tiles")

/// What a player could try to carry between rounds: an upgraded machine, a tank of plasma beside a tank of air.
/datum/unit_test/voidcrew_ship_saves_hull/retrieval/proc/fit_source(obj/docking_port/mobile/voidcrew/port)
	var/list/fittings = list(/obj/machinery/autolathe, /obj/machinery/atmospherics/components/tank/plasma, /obj/machinery/atmospherics/components/tank/air)
	for(var/turf/open/floor/tile in port.return_turfs())
		if(!length(fittings))
			break
		if(!(get_area(tile) in port.shuttle_areas) || tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/fitting_type = fittings[1]
		fittings.Cut(1, 2)
		var/obj/machinery/fitting = new fitting_type(tile)
		if(istype(fitting, /obj/machinery/autolathe))
			var/datum/stock_part/old_bin = locate(/datum/stock_part/matter_bin) in fitting.component_parts
			TEST_ASSERT_NOTNULL(old_bin, "A new autolathe has no matter bin to upgrade")
			fitting.component_parts -= old_bin
			fitting.component_parts += GLOB.stock_part_datums[/datum/stock_part/matter_bin/tier4]
			fitting.RefreshParts()
	TEST_ASSERT(!length(fittings), "The test hull had no room for [length(fittings)] fittings")

/// As lose_original() does for the checkpoint tests: flies the source away and deletes it.
/datum/unit_test/voidcrew_ship_saves_hull/retrieval/proc/vacate_bay(obj/structure/overmap/dynamic/player_outpost/home)
	undock_source(home)
	test_ship.shuttle.admin_delete_shuttle()

/datum/unit_test/voidcrew_ship_saves_hull/retrieval/proc/undock_source(obj/structure/overmap/dynamic/player_outpost/home)
	var/obj/docking_port/stationary/transit/transit = test_ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(test_ship.shuttle)
	test_ship.shuttle.mode = SHUTTLE_PREARRIVAL
	test_ship.shuttle.initiate_docking(transit)
	test_ship.shuttle.mode = SHUTTLE_IDLE
	test_ship.docked = null
	test_ship.forceMove(get_turf(home))
	test_ship.state = "flying"
	home.on_ship_undock_complete(test_ship)

/// Everything a retrieved ship must be, however it got here.
/datum/unit_test/voidcrew_ship_saves_hull/retrieval/proc/check_retrieved(obj/structure/overmap/ship/ship, where)
	TEST_ASSERT_EQUAL(ship.name, saved_name, "[where]: the ship lost its name")
	TEST_ASSERT_EQUAL(ship.source_template.short_name, saved_class, "[where]: the ship lost its class")
	TEST_ASSERT_EQUAL(length(ship.job_definitions), saved_jobs, "[where]: the ship lost its roster")
	TEST_ASSERT_EQUAL(ship.ship_account.account_balance, 0, "[where]: the ship came with money")
	TEST_ASSERT(length(ship.shuttle.spawn_points), "[where]: nobody can spawn on the ship")
	var/lathes = 0
	var/plasma_tanks = 0
	var/air_tanks = 0
	var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
	for(var/turf/tile as anything in port.return_turfs())
		if(!(get_area(tile) in port.shuttle_areas))
			continue
		for(var/obj/item/loose in tile)
			TEST_FAIL("[where]: the ship came with a loose [loose.type]")
		for(var/obj/machinery/machine in tile)
			if(istype(machine, /obj/machinery/autolathe))
				lathes++
				TEST_ASSERT_NULL(locate(/datum/stock_part/matter_bin/tier4) in machine.component_parts, "[where]: an upgraded part came back")
			if(istype(machine, /obj/machinery/atmospherics/components/tank/plasma))
				plasma_tanks++
				var/obj/machinery/atmospherics/components/tank/plasma_tank = machine
				TEST_ASSERT_EQUAL(plasma_tank.air_contents.total_moles(), 0, "[where]: a plasma tank came back with gas in it")
			if(istype(machine, /obj/machinery/atmospherics/components/tank/air))
				air_tanks++
				var/obj/machinery/atmospherics/components/tank/air_tank = machine
				TEST_ASSERT(air_tank.air_contents.total_moles() > 0, "[where]: an air tank came back empty")
			if(istype(machine, /obj/machinery/power/apc))
				var/obj/machinery/power/apc/controller = machine
				TEST_ASSERT(controller.cell?.charge > 0, "[where]: an APC came back with no charged cell")
			if(istype(machine, /obj/machinery/vending))
				var/obj/machinery/vending/vendor = machine
				for(var/datum/data/vending_product/product as anything in vendor.product_records + vendor.hidden_records + vendor.coin_records)
					TEST_ASSERT_EQUAL(product.amount, 0, "[where]: a vending machine came back stocked")
			if(istype(machine, /obj/machinery/door))
				var/obj/machinery/door/door = machine
				TEST_ASSERT(!length(door.req_access) && !length(door.req_one_access), "[where]: a door kept its access")
			if(istype(machine, /obj/machinery/atmospherics/components/unary/shuttle/heater))
				var/obj/machinery/atmospherics/components/unary/shuttle/heater/heater = machine
				TEST_ASSERT(heater.fuel_tank?.air_contents.total_moles() > 0, "[where]: an engine heater came back with no fuel")
	TEST_ASSERT(lathes, "[where]: the upgraded autolathe did not come back")
	TEST_ASSERT(plasma_tanks, "[where]: the plasma tank did not come back")
	TEST_ASSERT(air_tanks, "[where]: the air tank did not come back")

/// A save loaded in the round it was made: only once the old hull is out of service, and it then replaces it.
/datum/unit_test/voidcrew_ship_saves_hull/retrieval/same_round

/datum/unit_test/voidcrew_ship_saves_hull/retrieval/same_round/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "savecaptain"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/obj/machinery/computer/ship_checkpoint/terminal = outpost_bay_shipyard_console(LAZYACCESS(home.bay_berths, 1))
	TEST_ASSERT_NOTNULL(terminal, "The ship bay has no shipyard console")
	var/mob/living/carbon/human/captain = make_player(get_turf(terminal), "savecaptain")
	test_ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(test_ship, "Could not create the hull")
	test_ship.enlist_crewmember(captain)
	test_ship.claimed_captain = captain.mind
	var/datum/ship_checkpoint_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
	var/datum/outpost_berth/ship_bay/bay = home.allocate_ship_bay(test_ship)
	TEST_ASSERT_NOTNULL(bay, "The hull was not given a bay")
	adjust_reserve_dock_to_shuttle(bay.dock, test_ship.shuttle)
	test_ship.shuttle.mode = SHUTTLE_PREARRIVAL
	test_ship.shuttle.initiate_docking(bay.dock)
	test_ship.shuttle.mode = SHUTTLE_IDLE
	test_ship.docked = home
	test_ship.forceMove(home)
	test_ship.state = "idle"
	bay.on_ship_docked(test_ship)
	test_ship.ship_account.account_balance = 500

	// Two saves of one hull.
	set_each_part(100)
	TEST_ASSERT(panel.save_ship(captain, bay, 1), "The first save failed: [panel.error]")
	TEST_ASSERT(panel.save_ship(captain, bay, 2), "The second save failed: [panel.error]")

	// In service, in the bay or out of it, nothing loads.
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "The original hull is still in service.", "A save was offered while its hull is in service")
	undock_source(home)
	TEST_ASSERT(!panel.retrieve_ship(captain, 1), "A save was built while its hull is in service")
	TEST_ASSERT_EQUAL(panel.error, "The original hull is still in service.", "An in-service hull gave the wrong refusal")
	TEST_ASSERT_NOTNULL(store.saved["savecaptain|1"], "A refused retrieval spent the save")
	TEST_ASSERT(!test_ship.checkpoint_rebuilding, "A refused retrieval locked the hull")

	// A job given a save of a crewed hull won't build it either, and lets go when it stops.
	var/datum/ship_checkpoint/in_service_copy = GLOB.ship_saves.read_save("savecaptain", 1)
	TEST_ASSERT(istype(in_service_copy), "A save would not read: [in_service_copy]")
	TEST_ASSERT(GLOB.ship_saves.begin_retrieval("savecaptain", 1), "A free save could not be claimed")
	var/datum/checkpoint_construction/saved/in_service = panel.create_retrieval_job(captain, in_service_copy, 1)
	TEST_ASSERT_NOTNULL(in_service.bay, "A job could not reserve the empty bay")
	TEST_ASSERT_NOTNULL(in_service.source_denial(), "A crewed original permitted a second hull")
	TEST_ASSERT(test_ship.checkpoint_rebuilding, "A job did not lock its original hull")
	qdel(in_service)
	TEST_ASSERT(!test_ship.checkpoint_rebuilding, "A cancelled job kept a lock on the original")
	TEST_ASSERT(!GLOB.ship_saves.retrievals[GLOB.ship_saves.slot_key("savecaptain", 1)], "A cancelled job kept its claim on the save")
	TEST_ASSERT(bay.is_available(), "A cancelled job kept the bay")

	// Abandoned, it can load.
	test_ship.abandon_ship(crash = FALSE)
	TEST_ASSERT_NULL(panel.saved_ship_retrieve_denial(captain, 1), "An abandoned hull blocks its save")

	// One build at a time from one hull, across its saves.
	TEST_ASSERT(panel.retrieve_ship(captain, 2), "Could not start building a save: [panel.error]")
	var/datum/checkpoint_construction/saved/job = home.checkpoint_jobs[1]
	TEST_ASSERT(test_ship.checkpoint_rebuilding, "A build did not lock the hull it replaces")
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "Already under way.", "A second save of a hull being replaced was offered")

	// Another build got to its first piece before this one did: refused there, with nothing spent.
	test_ship.retired_by_checkpoint = TRUE
	job.fast_forward(1)
	TEST_ASSERT(QDELETED(job), "A build of a replaced hull kept running")
	TEST_ASSERT(!job.committed, "A build of a replaced hull placed a piece")
	TEST_ASSERT_EQUAL(panel.error, "The original hull has already been replaced. Your saved ship is safe.", "The late refusal gave the wrong words")
	TEST_ASSERT_NOTNULL(store.saved["savecaptain|2"], "The late refusal spent the save")
	TEST_ASSERT_NOTNULL(GLOB.ship_saves.saved_row("savecaptain", 2), "The late refusal lost the cached save")
	TEST_ASSERT(!GLOB.ship_saves.retrievals[GLOB.ship_saves.slot_key("savecaptain", 2)], "The late refusal kept its claim on the save")
	TEST_ASSERT_EQUAL(test_ship.ship_account.account_balance, 500, "The late refusal moved the balance")
	test_ship.retired_by_checkpoint = FALSE
	var/deadline = world.time + 30 SECONDS
	UNTIL(bay.is_available() || world.time > deadline)
	TEST_ASSERT(bay.is_available(), "The late refusal kept the bay")

	// A whole build retires the old hull at the first piece and pays its balance to the new one.
	TEST_ASSERT(panel.retrieve_ship(captain, 1), "Could not start building a save: [panel.error]")
	job = home.checkpoint_jobs[1]
	job.fast_forward(1)
	TEST_ASSERT(job.committed, "The first piece did not commit the build")
	TEST_ASSERT(test_ship.retired_by_checkpoint, "The first piece did not retire the old hull")
	TEST_ASSERT(!test_ship.checkpoint_rebuilding, "A retired hull kept its lock")
	TEST_ASSERT_EQUAL(test_ship.ship_account.account_balance, 0, "The old hull kept its balance")
	TEST_ASSERT_EQUAL(job.held_balance, 500, "The build isn't holding the old hull's balance")
	TEST_ASSERT_NULL(GLOB.ship_saves.live_sources[GLOB.ship_saves.slot_key("savecaptain", 1)], "A spent save kept its source")
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 2), "The original hull has already been replaced.", "A second save of a replaced hull was offered")
	job.fast_forward()
	TEST_ASSERT(QDELETED(job), "The build did not finish")
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT_NOTNULL(rebuilt, "The finished build is not in the bay")
	retrieved_ships += rebuilt
	TEST_ASSERT_EQUAL(rebuilt.ship_account.account_balance, 500, "The new ship did not get the old hull's balance")

	// With the hull gone, the retired record still refuses. An unretired one wouldn't.
	var/obj/docking_port/mobile/old_port = test_ship.detach_shuttle()
	old_port.jumpToNullSpace()
	TEST_ASSERT(!QDELETED(test_ship) && !test_ship.shuttle, "The fixture still has a hull")
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 2), "The original hull has already been replaced.", "A retired hull-less record was bypassed")
	test_ship.retired_by_checkpoint = FALSE
	TEST_ASSERT_NULL(GLOB.ship_saves.retrieve_denial("savecaptain", 2), "A hull-less record blocks its save")

	// The lobby, with no job to do any of this for it.
	var/obj/structure/overmap/ship/lobby_source = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(lobby_source, "Could not create the lobby's hull")
	retrieved_ships += lobby_source
	lobby_source.ship_account.account_balance = 300
	var/datum/ship_checkpoint/lobby_copy = new
	var/capture_denial = lobby_copy.capture_hull(lobby_source, "savelobby")
	TEST_ASSERT_NULL(capture_denial, "The lobby's hull was not captured: [capture_denial]")
	GLOB.ship_saves.refresh("savelobby")
	var/commit_error = GLOB.ship_saves.commit_save("savelobby", lobby_copy, null, 1, lobby_source.save_survey(fresh = TRUE))
	qdel(lobby_copy)
	TEST_ASSERT_NULL(commit_error, "The lobby's save failed: [commit_error]")

	SSticker.current_state = GAME_STATE_PLAYING
	var/mob/dead/new_player/ship_save_test/lobby = allocate(__IMPLIED_TYPE__)
	lobby.key = "savelobby"
	GLOB.ship_saves.launch(lobby, 1)
	TEST_ASSERT_NULL(lobby.seated_on, "The lobby loaded a save while its hull is in service")
	TEST_ASSERT_NOTNULL(store.saved["savelobby|1"], "A refused launch spent the save")
	TEST_ASSERT(!lobby_source.checkpoint_rebuilding, "A refused launch locked the hull")
	TEST_ASSERT(!lobby.spawning_ship, "A refused launch left the player stuck preparing a ship")

	lobby_source.abandon_ship(crash = FALSE)
	GLOB.ship_saves.launch(lobby, 1)
	var/obj/structure/overmap/ship/launched = lobby.seated_on
	TEST_ASSERT_NOTNULL(launched, "The lobby did not load a save whose hull was abandoned")
	retrieved_ships += launched
	TEST_ASSERT(lobby_source.retired_by_checkpoint, "The lobby did not retire the old hull")
	TEST_ASSERT(!lobby_source.checkpoint_rebuilding, "The lobby left the old hull locked")
	TEST_ASSERT_EQUAL(lobby_source.ship_account.account_balance, 0, "The old hull kept its balance")
	TEST_ASSERT_EQUAL(launched.ship_account.account_balance, 300, "The new ship did not get the old hull's balance")
	TEST_ASSERT_NULL(store.saved["savelobby|1"], "The lobby did not spend the save")
	TEST_ASSERT_NULL(GLOB.ship_saves.live_sources[GLOB.ship_saves.slot_key("savelobby", 1)], "A spent save kept its source")

/**
 * The real table, through the real store and the game's database connection. Skipped with no database.
 * Everything it writes belongs to one test ckey, and is deleted before and after.
 */
/datum/unit_test/voidcrew_ship_saves_sql
	var/test_ckey = "shipsavesqltest"
	var/obj/structure/overmap/ship/test_ship

/datum/unit_test/voidcrew_ship_saves_sql/Destroy()
	if(!QDELETED(test_ship))
		qdel(test_ship)
	if(SSdbcore.IsConnected())
		wipe()
	return ..()

/// Deletes every row the test ckey owns.
/datum/unit_test/voidcrew_ship_saves_sql/proc/wipe()
	var/datum/db_query/query = SSdbcore.NewQuery(
		"DELETE FROM [format_table_name("player_ship_saves")] WHERE ckey = :ckey",
		list("ckey" = test_ckey)
	)
	query.Execute()
	qdel(query)

/// The size the database holds a row's map at, or null.
/datum/unit_test/voidcrew_ship_saves_sql/proc/stored_size(slot)
	var/datum/db_query/query = SSdbcore.NewQuery(
		"SELECT LENGTH(payload) FROM [format_table_name("player_ship_saves")] WHERE ckey = :ckey AND slot = :slot",
		list("ckey" = test_ckey, "slot" = slot)
	)
	var/size
	if(query.Execute() && query.NextRow())
		size = text2num(query.item[1])
	qdel(query)
	return size

/datum/unit_test/voidcrew_ship_saves_sql/Run()
	if(!SSdbcore.IsConnected())
		log_test("Ship saves SQL test skipped: no database connection.")
		return
	wipe()
	var/datum/ship_save_store/store = new
	test_ship = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/box)
	TEST_ASSERT_NOTNULL(test_ship, "Could not create the hull")
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	var/denial = snapshot.capture_hull(test_ship, test_ckey)
	TEST_ASSERT_NULL(denial, "The fixture hull was not captured: [denial]")
	var/payload = GLOB.ship_saves.encode(snapshot)
	var/list/meta = list(
		"ship_name" = snapshot.ship_name,
		"ship_class" = snapshot.class_name,
		"tile_count" = snapshot.owned_tile_count(),
		"format_version" = SHIP_SAVE_TEST_FORMAT,
		"saved_round" = SHIP_SAVE_TEST_ROUND,
		"raw_bytes" = length(payload),
	)

	// A real save comes back exactly, and decodes.
	TEST_ASSERT(store.write(test_ckey, 1, meta, payload), "A save was not written")
	var/read_back = store.read_payload(test_ckey, 1)
	TEST_ASSERT(read_back == payload, "A saved hull did not read back the same: [length(read_back)] bytes against [length(payload)]")
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(read_back)
	TEST_ASSERT_NOTNULL(decoded, "A saved hull read back from the table did not decode")
	TEST_ASSERT_EQUAL(decoded.ship_name, snapshot.ship_name, "The read back hull lost its name")
	TEST_ASSERT_EQUAL(decoded.width, snapshot.width, "The read back hull lost its width")
	TEST_ASSERT_EQUAL(decoded.height, snapshot.height, "The read back hull lost its height")
	qdel(decoded)
	var/stored = stored_size(1)
	log_test("Ship saves SQL: the fixture hull is [meta["raw_bytes"]] bytes of text, stored as [stored] bytes in the table.")

	// Quotes, backslashes and text that is not ASCII survive the round trip.
	var/awkward = "it's a \"quoted\" back\\slash, 'single' and \\\" both, [ascii2text(228)][ascii2text(26085)] and 100% done; DROP TABLE x;"
	TEST_ASSERT(store.write(test_ckey, 2, list("ship_name" = "Awkward", "ship_class" = null, "tile_count" = 1, "format_version" = SHIP_SAVE_TEST_FORMAT, "saved_round" = SHIP_SAVE_TEST_ROUND, "raw_bytes" = length(awkward)), awkward), "An awkward save was not written")
	TEST_ASSERT(store.read_payload(test_ckey, 2) == awkward, "Quotes, backslashes or non-ASCII text changed in the table")

	// The row is there, a second write to the slot fails and leaves the first.
	var/list/rows = store.read_meta(test_ckey)
	TEST_ASSERT_EQUAL(length(rows), 2, "The table does not hold both saves")
	var/list/first_row = rows[1]
	TEST_ASSERT_EQUAL(first_row["slot"], 1, "The first row is not slot 1")
	TEST_ASSERT_EQUAL(first_row["ship_name"], snapshot.ship_name, "The row has the wrong name")
	TEST_ASSERT_EQUAL(first_row["tile_count"], meta["tile_count"], "The row has the wrong tile count")
	TEST_ASSERT_EQUAL(first_row["format_version"], SHIP_SAVE_TEST_FORMAT, "The row has the wrong format")
	TEST_ASSERT_EQUAL(first_row["saved_round"], SHIP_SAVE_TEST_ROUND, "The row has the wrong round")
	TEST_ASSERT_EQUAL(first_row["raw_bytes"], meta["raw_bytes"], "The row has the wrong size")
	TEST_ASSERT(!store.write(test_ckey, 1, meta, "another hull"), "A taken slot was overwritten")
	TEST_ASSERT(store.read_payload(test_ckey, 1) == payload, "A refused write changed the saved hull")
	TEST_ASSERT_NULL(first_row["survey"], "A row with no summary has a survey")

	// An overwrite replaces every column and keeps one row, and the summary comes back.
	var/list/replacement = meta.Copy()
	replacement["ship_name"] = "Replacement"
	replacement["tile_count"] = 7
	replacement["raw_bytes"] = 12
	replacement["summary"] = json_encode(list("mass" = 650, "crew" = 3, "plan" = "2#/2o", "bill" = list(list("class" = "misc", "parts" = 5, "items" = list(list("name" = "Hull, 650 t", "count" = null, "parts" = 5)))), "total" = 5))
	TEST_ASSERT(store.write(test_ckey, 1, replacement, "another hull", overwrite = TRUE), "An overwrite was not written")
	rows = store.read_meta(test_ckey)
	TEST_ASSERT_EQUAL(length(rows), 2, "An overwrite did not keep one row per slot")
	first_row = rows[1]
	TEST_ASSERT_EQUAL(first_row["ship_name"], "Replacement", "An overwrite did not replace the name")
	TEST_ASSERT_EQUAL(first_row["tile_count"], 7, "An overwrite did not replace the tile count")
	TEST_ASSERT_EQUAL(first_row["raw_bytes"], 12, "An overwrite did not replace the size")
	TEST_ASSERT(store.read_payload(test_ckey, 1) == "another hull", "An overwrite did not replace the map")
	var/list/survey = first_row["survey"]
	TEST_ASSERT_EQUAL(survey?["mass"], 650, "The summary did not come back from the table")
	TEST_ASSERT_EQUAL(survey?["plan"], "2#/2o", "The plan did not come back from the table")
	var/list/bill_entry = survey?["bill"][1]
	TEST_ASSERT_EQUAL(bill_entry?["class"], "misc", "The bill did not come back from the table")

	// An overwrite of an empty slot is an ordinary write, and bad JSON in the column reads as no survey.
	replacement["summary"] = "{not json"
	TEST_ASSERT(store.write(test_ckey, 3, replacement, "a third hull", overwrite = TRUE), "An overwrite of an empty slot failed")
	rows = store.read_meta(test_ckey)
	var/list/third_row = rows[3]
	TEST_ASSERT_EQUAL(third_row["slot"], 3, "The third row is not slot 3")
	TEST_ASSERT_NULL(third_row["survey"], "Bad JSON in the column came back as a survey")
	TEST_ASSERT(store.remove(test_ckey, 3), "The third save was not removed")

	// A plain write to a used slot still fails, whatever overwrite did before it.
	TEST_ASSERT(!store.write(test_ckey, 1, meta, payload), "A plain write replaced a used slot")
	TEST_ASSERT(store.read_payload(test_ckey, 1) == "another hull", "A refused plain write changed the saved hull")

	// Using a save removes it once.
	TEST_ASSERT(store.remove(test_ckey, 1), "A save was not removed")
	TEST_ASSERT(!store.remove(test_ckey, 1), "A save was removed twice")
	TEST_ASSERT_NULL(store.read_payload(test_ckey, 1), "A removed save still read back")
	TEST_ASSERT(store.remove(test_ckey, 2), "The awkward save was not removed")
	TEST_ASSERT_EQUAL(length(store.read_meta(test_ckey)), 0, "Rows were left behind")
	qdel(store)

#undef SHIP_SAVE_TEST_ROUND
#undef SHIP_SAVE_TEST_FORMAT
#undef SHIP_SAVE_TEST_GONE_PATH
#undef SHIP_SAVE_TEST_SLOTS
#undef SHIP_SAVE_TEST_PRICE_MIN
#undef SHIP_SAVE_TEST_MASS_PER_PART
#undef SHIP_SAVE_TEST_MACHINES_PER_PART
#undef SHIP_SAVE_TEST_PLAN_MAX
#undef SHIP_SAVE_TEST_PASSWORD_PRICE
#undef SHIP_SAVE_TEST_TOO_LONG
#undef SHIP_SAVE_TEST_TILE_IRON
