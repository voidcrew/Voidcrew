// Voidcrew defines load after the unit tests, so these mirror them.
#define SHIP_SAVE_TEST_SLOTS 3 // SHIP_SAVE_SLOTS
#define SHIP_SAVE_TEST_PRICE_MIN 2 // SHIP_SAVE_PRICE_MIN
#define SHIP_SAVE_TEST_PRICE_MAX 15 // SHIP_SAVE_PRICE_MAX
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
			rows += list(row)
	return rows

/datum/ship_save_store/fake/read_payload(ckey, slot)
	if(fail_reads)
		return null
	var/list/entry = saved["[ckey]|[slot]"]
	return entry?["payload"]

/datum/ship_save_store/fake/write(ckey, slot, list/meta, payload)
	if(fail_writes || saved["[ckey]|[slot]"])
		return FALSE
	saved["[ckey]|[slot]"] = list("meta" = meta.Copy(), "payload" = payload)
	return TRUE

/datum/ship_save_store/fake/remove(ckey, slot)
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
	snapshot.persistent = TRUE
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
	check_saved_vars()
	check_prices()
	check_part_plans()
	check_commit()
	check_retrieval_rules()

/datum/unit_test/voidcrew_ship_saves/proc/check_round_trip()
	var/datum/ship_checkpoint/snapshot = make_snapshot()
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(GLOB.ship_saves.encode(snapshot))
	TEST_ASSERT_NOTNULL(decoded, "A fresh payload did not decode")
	TEST_ASSERT(decoded.persistent, "A decoded save is not marked persistent")
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
	var/datum/ship_checkpoint/in_round = allocate(/datum/ship_checkpoint)

	// Machines carry nothing per machine, and the in-round kind is untouched.
	var/obj/machinery/autolathe/lathe = allocate(/obj/machinery/autolathe)
	TEST_ASSERT(!findtext(saved.atom_text(lathe), "checkpoint_load_id"), "A saved machine stored a load id")
	TEST_ASSERT_EQUAL(length(saved.machines), 0, "A saved machine stored its parts")
	TEST_ASSERT(findtext(in_round.atom_text(lathe), "checkpoint_load_id"), "An in-round checkpoint lost its load id")

	// Valuable structures stay behind unless they seal the hull.
	var/obj/structure/statue/gold/hos/statue = allocate(/obj/structure/statue/gold/hos)
	TEST_ASSERT(!saved.includes_object(statue), "A gold statue was saved")
	TEST_ASSERT(in_round.includes_object(statue), "An in-round checkpoint stopped keeping statues")
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
	TEST_ASSERT(!findtext(in_round.atom_text(diamond_wall), "sheet_type"), "An in-round checkpoint changed a wall's salvage")
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
	TEST_ASSERT(!findtext(in_round.atom_text(gold_floor), "floor_tile"), "An in-round checkpoint changed a floor's tile")
	gold_floor.floor_tile = /obj/item/stack/tile/iron
	gold_floor.copyTurf(copy_tile)
	var/turf/open/floor/moved_floor = copy_tile
	TEST_ASSERT_EQUAL(moved_floor.floor_tile, /obj/item/stack/tile/iron, "A shuttle move gave a saved floor its tile back")
	wall_tile.ChangeTurf(wall_tile_type)
	copy_tile.ChangeTurf(copy_tile_type)

/// A hull that was saved once, loaded and saved again must not get its salvage back, nor an in-round checkpoint of it.
/datum/unit_test/voidcrew_ship_saves/proc/check_second_generation()
	var/datum/ship_checkpoint/saved = make_snapshot()
	var/datum/ship_checkpoint/in_round = allocate(/datum/ship_checkpoint)
	var/turf/tile = run_loc_floor_bottom_left
	var/tile_type = tile.type
	var/obj/item/construction/rcd/internal/ship/rcd = allocate(/obj/item/construction/rcd/internal/ship)

	tile.ChangeTurf(/turf/closed/wall/mineral/diamond)
	var/turf/closed/wall/wall = tile
	wall.sheet_type = /obj/item/stack/sheet/iron
	TEST_ASSERT(findtext(saved.atom_text(wall), "sheet_type = /obj/item/stack/sheet/iron"), "A wall saved a second time got its salvage back")
	TEST_ASSERT(findtext(in_round.atom_text(wall), "sheet_type = /obj/item/stack/sheet/iron"), "An in-round checkpoint gave a stripped wall its salvage back")
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
	TEST_ASSERT(findtext(in_round.atom_text(floor), "floor_tile = /obj/item/stack/tile/iron"), "An in-round checkpoint gave a stripped floor its tile back")
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
	TEST_ASSERT(!findtext(in_round.atom_text(gold_airlock), "assemblytype"), "An in-round checkpoint changed an airlock's assembly")
	TEST_ASSERT(!findtext(saved.atom_text(allocate(/obj/machinery/door/airlock)), "assemblytype"), "A plain airlock was given another assembly")
	TEST_ASSERT(ship_save_refuses_object(allocate(/obj/structure/door_assembly/door_assembly_gold)), "A gold airlock assembly was saved")
	TEST_ASSERT(!ship_save_refuses_object(allocate(/obj/structure/door_assembly)), "A plain airlock assembly was refused")
	// The plain assembly it falls back to comes apart into iron alone.
	var/obj/machinery/door/airlock/gold/breaking = new(tile)
	breaking.assemblytype = /obj/structure/door_assembly
	breaking.deconstruct(TRUE)
	var/obj/structure/door_assembly/dropped = locate() in tile
	TEST_ASSERT_NOTNULL(dropped, "A gold airlock with a plain assembly left nothing behind")
	TEST_ASSERT_EQUAL(dropped?.type, /obj/structure/door_assembly, "The airlock did not fall back to a plain assembly")
	dropped?.deconstruct(TRUE)
	TEST_ASSERT_NOTNULL(locate(/obj/item/stack/sheet/iron) in tile, "A plain assembly dropped no iron")
	TEST_ASSERT_NULL(locate(/obj/item/stack/sheet/mineral/gold) in tile, "A plain assembly dropped gold")
	for(var/obj/loose in tile)
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

/datum/unit_test/voidcrew_ship_saves/proc/check_prices()
	var/datum/ship_saves/saves = GLOB.ship_saves
	TEST_ASSERT_EQUAL(saves.price_for(275), 2, "Wrong price for a Goon-size hull")
	TEST_ASSERT_EQUAL(saves.price_for(340), 3, "Wrong price for a Kilo-size hull")
	TEST_ASSERT_EQUAL(saves.price_for(500), 6, "Wrong price for a Delta-size hull")
	TEST_ASSERT_EQUAL(saves.price_for(630), 9, "Wrong price for a Scarab-size hull")
	TEST_ASSERT_EQUAL(saves.price_for(850), 15, "Wrong price for a Phalanx-size hull")
	TEST_ASSERT_EQUAL(saves.price_for(1), SHIP_SAVE_TEST_PRICE_MIN, "The smallest hull went under the lowest price")
	TEST_ASSERT_EQUAL(saves.price_for(3000), SHIP_SAVE_TEST_PRICE_MAX, "The biggest hull went over the highest price")

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
	saves.refresh(player_ckey)
	TEST_ASSERT_EQUAL(length(saves.saves_for(player_ckey)), 0, "A new player was not loaded with no saves")
	TEST_ASSERT_EQUAL(saves.free_slot(player_ckey), 1, "The first free slot is not 1")

	// Not enough parts: nothing is written.
	set_parts()
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(275), null), "A save with no parts went through")
	TEST_ASSERT_EQUAL(length(store.saved), 0, "A save nobody paid for reached the table")

	// A failed write takes nothing.
	set_parts(combat = 20)
	store.fail_writes = TRUE
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(275), null), "A failed write reported success")
	TEST_ASSERT_EQUAL(economy.total(), 20, "A failed write kept the payment")
	TEST_ASSERT_EQUAL(length(saves.saves_for(player_ckey)), 0, "A failed write reached the cache")
	store.fail_writes = FALSE

	// A failed read is not "no saves".
	var/list/loaded = saves.saves_for(player_ckey)
	TEST_ASSERT_NOTNULL(loaded, "The cache was lost")
	TEST_ASSERT_NULL(saves.saves_for("nobodyatall"), "An unloaded player reads as having no saves")
	TEST_ASSERT_NULL(saves.free_slot("nobodyatall"), "An unloaded player has a free slot")

	// Three saves fill the slots in order, charging each one.
	for(var/slot in 1 to SHIP_SAVE_TEST_SLOTS)
		TEST_ASSERT_NULL(saves.commit_save(player_ckey, make_snapshot(275), null), "Save [slot] failed")
		TEST_ASSERT_NOTNULL(store.saved["[player_ckey]|[slot]"], "Save [slot] went to the wrong slot")
		TEST_ASSERT_EQUAL(economy.total(), 20 - 2 * slot, "Save [slot] charged the wrong amount")
	var/list/entry = store.saved["[player_ckey]|1"]
	var/list/meta = entry["meta"]
	TEST_ASSERT_EQUAL(meta["tile_count"], 275, "The row has the wrong tile count")
	TEST_ASSERT_EQUAL(meta["ship_name"], "Test Hull", "The row has the wrong name")
	var/list/stored = json_decode(entry["payload"])
	TEST_ASSERT_EQUAL(meta["format_version"], stored["format"], "The row has the wrong format")
	TEST_ASSERT_EQUAL(meta["raw_bytes"], length(entry["payload"]), "The row has the wrong size")
	TEST_ASSERT_NULL(saves.free_slot(player_ckey), "Three saves left a slot free")

	// Slots full: refused before any charge.
	var/parts_before = economy.total()
	TEST_ASSERT_EQUAL(saves.commit_save(player_ckey, make_snapshot(275), null), "All slots are full.", "A fourth save was not refused")
	TEST_ASSERT_EQUAL(economy.total(), parts_before, "A refused save was charged")

	// A paid save is never overwritten: a write to a taken slot fails, and refunds.
	saves.cache[player_ckey] = list()
	TEST_ASSERT_NOTNULL(saves.commit_save(player_ckey, make_snapshot(275), null), "A taken slot was overwritten")
	TEST_ASSERT_EQUAL(economy.total(), parts_before, "A duplicate key kept the payment")

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
	TEST_ASSERT_EQUAL(saves.retrieve_denial(player_ckey, 2), "Ready next round.", "A save made this round was offered")
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
	TEST_ASSERT_EQUAL(saves.free_slot(player_ckey), 1, "A spent save did not free its slot")
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
	var/datum/ship_checkpoint_ui/registry_test/panel = allocate(__IMPLIED_TYPE__, home, terminal, captain)
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

	TEST_ASSERT_NULL(panel.saved_ship_denial(captain, bay), "The captain could not save a docked ship")
	TEST_ASSERT_EQUAL(deckhand_panel.saved_ship_denial(deckhand, bay), "Only the ship's current captain can save it.", "A deckhand could save the ship")

	// No cryopods, no way to spawn on it later.
	var/list/spawn_points = test_ship.shuttle.spawn_points
	test_ship.shuttle.spawn_points = list()
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay), "This hull has no cryopods.", "A hull without cryopods could be saved")
	test_ship.shuttle.spawn_points = spawn_points

	// Declining costs nothing; accepting charges once and saves the real hull.
	set_parts(40)
	panel.accept_save = FALSE
	TEST_ASSERT(!panel.save_ship(captain, bay), "Declining still saved the ship")
	TEST_ASSERT_EQUAL(length(store.saved), 0, "Declining reached the table")
	TEST_ASSERT_EQUAL(parts_held(), 40, "Declining was charged")
	panel.accept_save = TRUE
	TEST_ASSERT(panel.save_ship(captain, bay), "Saving failed: [panel.error]")
	TEST_ASSERT_NULL(panel.error, "A successful save left an error")
	TEST_ASSERT_EQUAL(panel.notice, "[test_ship.name] saved.", "A successful save said nothing")
	TEST_ASSERT(!panel.working, "The panel stayed busy after saving")
	var/list/entry = store.saved["savecaptain|1"]
	TEST_ASSERT_NOTNULL(entry, "The save did not reach slot 1")

	// What was stored is a usable copy with nothing per machine in it.
	var/datum/ship_checkpoint/decoded = GLOB.ship_saves.decode(entry["payload"])
	TEST_ASSERT_NOTNULL(decoded, "The stored hull did not decode")
	TEST_ASSERT_EQUAL(parts_held(), 40 - GLOB.ship_saves.price_for(decoded.owned_tile_count()), "The hull was charged the wrong price")
	TEST_ASSERT_EQUAL(hull_owned_tile_count(test_ship.shuttle), decoded.owned_tile_count(), "The price on the screen would differ from the price charged")
	TEST_ASSERT(!findtext(decoded.tgm, "checkpoint_load_id"), "A stored hull has a machine load id")
	TEST_ASSERT_EQUAL(length(decoded.machines), 0, "A stored hull has per-machine data")
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

	// Slots full, and records offline, are refused by name.
	var/list/rows = GLOB.ship_saves.saves_for(captain.ckey)
	for(var/slot in 2 to SHIP_SAVE_TEST_SLOTS)
		rows += list(list("slot" = slot, "ship_name" = "Filler", "ship_class" = null))
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay), "All slots are full.", "Full slots were not refused")
	GLOB.ship_saves.cache -= captain.ckey
	TEST_ASSERT_EQUAL(panel.saved_ship_denial(captain, bay), "Shipyard records are offline.", "An unloaded player read as having slots")

	// The panel's data never needs the database, and matches what the screen is promised.
	GLOB.ship_saves.refresh(captain.ckey)
	var/list/saved_ships = panel.saved_ships_data(captain)
	TEST_ASSERT_EQUAL(saved_ships["slots"], SHIP_SAVE_TEST_SLOTS, "The panel has the wrong slot count")
	TEST_ASSERT_EQUAL(length(saved_ships["saves"]), 1, "The panel did not list the save")
	var/list/listed_ships = saved_ships["ships"]
	TEST_ASSERT_EQUAL(length(listed_ships), 1, "The panel did not list the docked ship")
	var/list/deckhand_view = panel.saved_ships_data(deckhand)
	TEST_ASSERT_EQUAL(length(deckhand_view["ships"]), 0, "The panel offered a deckhand the ship")

	check_password(captain, deckhand)

/datum/unit_test/voidcrew_ship_saves_hull/proc/set_parts(misc)
	economy.held = list("combat" = 0, "science" = 0, "trade" = 0, "misc" = misc)

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

	// A save made this round waits for the next one.
	set_parts(40)
	TEST_ASSERT(panel.save_ship(captain, bay), "Saving failed: [panel.error]")
	saved_name = test_ship.name
	saved_class = test_ship.source_template.short_name
	saved_jobs = length(test_ship.job_definitions)
	TEST_ASSERT_EQUAL(GLOB.ship_saves.retrieve_denial("savecaptain", 1), "Ready next round.", "A ship was offered in the round it was saved")

	// The same save as made last round, in every slot here and in a lobby player's first.
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
	var/list/first_listed = listed_saves[1]
	TEST_ASSERT_EQUAL(first_listed["denial"], "The ship bay is occupied.", "The panel offered a save with the bay full")
	TEST_ASSERT(!panel.retrieve_ship(captain, 1), "A save was built with the bay full")
	TEST_ASSERT_EQUAL(panel.error, "The ship bay is occupied.", "A full bay gave the wrong refusal")
	vacate_bay(home)
	TEST_ASSERT_NULL(panel.saved_ship_retrieve_denial(captain, 1), "The panel refused a save with the bay empty")

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
	TEST_ASSERT_EQUAL(GLOB.ship_saves.free_slot("savecaptain"), 2, "The first piece did not free the slot")
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
	TEST_ASSERT_EQUAL(GLOB.ship_saves.free_slot("savelobby"), 1, "The lobby did not free the slot")
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
	TEST_ASSERT_EQUAL(hull_owned_tile_count(stale_ship.shuttle), first_meta["tile_count"], "A save with removed types lost tiles")

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
	var/obj/docking_port/stationary/transit/transit = test_ship.shuttle.assigned_transit || SSshuttle.generate_transit_dock(test_ship.shuttle)
	test_ship.shuttle.mode = SHUTTLE_PREARRIVAL
	test_ship.shuttle.initiate_docking(transit)
	test_ship.shuttle.mode = SHUTTLE_IDLE
	test_ship.docked = null
	test_ship.forceMove(get_turf(home))
	test_ship.state = "flying"
	home.on_ship_undock_complete(test_ship)
	test_ship.shuttle.admin_delete_shuttle()

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
	snapshot.persistent = TRUE
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
#undef SHIP_SAVE_TEST_PRICE_MAX
#undef SHIP_SAVE_TEST_PASSWORD_PRICE
#undef SHIP_SAVE_TEST_TOO_LONG
#undef SHIP_SAVE_TEST_TILE_IRON
