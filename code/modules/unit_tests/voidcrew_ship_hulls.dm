/**
 * # Purchasable hull conformance
 *
 * Three properties of the hull shelf that are enforced by convention today:
 *
 * 1. **Catalog rules.** Only curated `force_purchasable` gag hulls are free,
 *    and those must never be on the starting line, the roundstart fleet rolls
 *    hull, theme and modules at random, so a hull with no themes and no slots
 *    hands a crew four tiles and no way to configure anything.
 * 2. **Dock rotation.** A hull whose `preferred_direction` disagrees with the
 *    aspect-ratio guess in adjust_reserve_dock_to_shuttle() spins 90 degrees on
 *    every dock and undock, forever, and nothing says so.
 * 3. **Starting equipment.** Every purchasable hull launches with a mission
 *    board and pad, a bank machine, a cargo console and an R&D board kit,
 *    either on the hull itself, or (the Delta pattern) guaranteed by every
 *    module that can fill one of its slots.
 */

/// TOML `directory` key in voidcrew/modules/ship_upgrades/ship_upgrades.toml
#define SHIP_MODULE_MAP_ROOT "_maps/voidcrew/ship_modules/"

/datum/unit_test/voidcrew_ship_catalog_rules

/datum/unit_test/voidcrew_ship_catalog_rules/Run()
	ensure_ship_upgrades_initialized()
	var/list/purchasable = get_purchasable_ship_templates()
	TEST_ASSERT(length(purchasable) >= 5, "the hull shelf collapsed to [length(purchasable)] hulls")

	for(var/datum/map_template/shuttle/voidcrew/hull as anything in purchasable)
		if(hull.player_hidden)
			TEST_FAIL("[hull.type] is player_hidden but is still on the shelf")
			continue
		if(hull.force_purchasable)
			// Curated gag hulls: free on the shelf on purpose, never roundstart.
			if(is_roundstart_eligible_hull(hull))
				TEST_FAIL("[hull.type] is force_purchasable (curated back onto the shelf by hand) but is roundstart-eligible. The roundstart fleet rolls hull, theme and modules at random and these hulls have none of that to roll.")
			continue
		if(ship_template_total_part_cost(hull) <= 0)
			TEST_FAIL("[hull.type] is on the shelf for nothing. Only curated force_purchasable hulls are free. There is deliberately no free starter hull.")
		if(!length(hull.catalog_desc))
			TEST_FAIL("[hull.type] has no catalog_desc, so the shelf falls back to a generated 'N-class with capacity for N crew' line")

	var/list/roundstart = get_roundstart_hull_templates()
	TEST_ASSERT(length(roundstart) >= 4, "the roundstart hull pool collapsed to [length(roundstart)] hulls. The fleet is sized to turnout and needs variety to deal from")
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in roundstart)
		if(!length(hull.upgrade_slot_ids))
			TEST_FAIL("[hull.type] is roundstart-eligible with no upgrade slots. There is nothing to roll modules into")
		if(!length(hull.available_themes))
			TEST_FAIL("[hull.type] is roundstart-eligible with no themes to roll")
			continue
		var/datum/ship_theme/theme = get_default_theme_for_ship(hull.type)
		if(!theme)
			TEST_FAIL("[hull.type] has no default theme, so a roundstart roll has no baseline to fall back to")
			continue
		var/seats = 0
		for(var/list/job_definition as anything in theme.job_slots)
			if(!islist(job_definition))
				TEST_FAIL("[hull.type]'s default theme has a malformed job slot definition")
				continue
			seats += job_definition["slots"] || 1
		if(seats < 4)
			TEST_FAIL("[hull.type]'s default theme seats only [seats], too small to deal a roundstart crew into")

	// Pricing shape: exactly one free default theme per hull, everything else priced.
	for(var/hull_type in GLOB.ship_themes)
		var/list/themes = GLOB.ship_themes[hull_type]
		var/defaults = 0
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			if(theme.is_default)
				defaults++
				if(length(theme.part_cost))
					TEST_FAIL("[hull_type]'s default theme '[theme_id]' costs parts; the default is what a hull's owner gets for free with the hull")
			else if(!length(theme.part_cost))
				TEST_FAIL("[hull_type] theme '[theme_id]' is not the default and costs nothing. Every alternative look is meant to be earned")
		if(defaults != 1)
			TEST_FAIL("[hull_type] has [defaults] default themes, expected exactly 1")

	// Same shape one layer down, for modules.
	for(var/hull_type in GLOB.ship_upgrade_modules)
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			if(module.is_default && length(module.part_cost))
				TEST_FAIL("default module '[module_id]' ([hull_type]) costs parts, but it is what loads when a player selects nothing")
			if(!module.is_default && !length(module.part_cost))
				TEST_FAIL("module '[module_id]' ([hull_type]) is not a slot default and costs nothing")

/**
 * A ship rotates on dock whenever the stationary port it lands on faces a
 * different way than it does. Both docks it cycles between are derived the
 * same way: the transit dock from `preferred_direction`, the reserve dock from
 * adjust_reserve_dock_to_shuttle()'s aspect-ratio guess (EAST for a hull that
 * is longer fore-to-aft than it is abeam, NORTH otherwise). If those two
 * disagree, the hull spins 90 degrees every single time, forever.
 */
/datum/unit_test/voidcrew_hull_dock_rotation
	priority = TEST_LONGER

/datum/unit_test/voidcrew_hull_dock_rotation/Run()
	var/checked = 0
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		var/text = vc_test_file_text(hull.mappath)
		if(!text)
			TEST_FAIL("[hull.type] points at a missing map [hull.mappath]")
			continue
		// Exactly one mobile port per hull map, the same assumption
		// /datum/map_template/discover_offset() is built on.
		var/path_start = findtext(text, "/obj/docking_port/mobile/")
		if(!path_start)
			TEST_FAIL("[hull.mappath] places no mobile docking port")
			continue
		var/index = path_start
		var/limit = length(text)
		while(index <= limit)
			var/char = copytext(text, index, index + 1)
			if(char == "," || char == "{" || char == "\n" || char == ascii2text(13)) // 13 = carriage return; DM has no \r escape
				break
			index++
		var/obj/docking_port/mobile/port_type = text2path(trim(copytext(text, path_start, index)))
		if(!ispath(port_type, /obj/docking_port/mobile))
			TEST_FAIL("[hull.mappath]'s docking port entry did not resolve to a mobile port type")
			continue
		// The port's mapped dir, if its entry carries a var block. /obj/docking_port
		// defaults to NORTH.
		var/mapped_dir = NORTH
		if(copytext(text, index, index + 1) == "{")
			var/block_end = findtext(text, "}", index)
			var/dir_at = findtext(text, "dir = ", index, block_end)
			// skip hits inside a longer var name (cyclelinkeddir and friends):
			// the character before the match must not be part of an identifier
			while(dir_at && vc_test_is_identifier_char(text2ascii(text, dir_at - 1)))
				dir_at = findtext(text, "dir = ", dir_at + 1, block_end)
			if(dir_at)
				mapped_dir = vc_test_read_number(text, dir_at + length("dir = ")) || NORTH
		checked++

		// calculate_docking_port_information() takes the hull's .dmm bounds and
		// swaps them for an east/west-facing port.
		var/port_width = hull.width
		var/port_height = hull.height
		if(mapped_dir & (EAST|WEST))
			port_width = hull.height
			port_height = hull.width
		// adjust_reserve_dock_to_shuttle() then re-measures fore-to-aft against
		// abeam through port_direction, and guesses from the ratio.
		var/port_direction = initial(port_type.port_direction)
		var/true_height = port_height
		var/true_width = port_width
		if(port_direction & (EAST|WEST))
			true_height = port_width
			true_width = port_height
		var/aspect_guess = (true_height > true_width) ? EAST : NORTH
		var/preferred = initial(port_type.preferred_direction)
		if(preferred != aspect_guess)
			TEST_FAIL("[hull.type] ([port_type]): preferred_direction [preferred] does not match the [aspect_guess] that adjust_reserve_dock_to_shuttle() guesses for its [hull.width]x[hull.height] hull. This ship rotates 90 degrees on every dock and every undock, for the whole round.")
	TEST_ASSERT(checked >= 5, "only [checked] purchasable hulls were checked for dock rotation")

/datum/unit_test/voidcrew_ship_standard_equipment
	priority = TEST_LONGER
	/**
	 * What every purchasable hull owes a crew at roundstart. Real typepaths
	 * rather than strings so a rename breaks the compile here instead of
	 * silently turning this test into a no-op.
	 */
	var/static/list/required_equipment = list(
		/obj/machinery/computer/mission_board = "mission board",
		/obj/machinery/mission_pad = "mission pad",
		/obj/machinery/computer/bank_machine = "bank machine",
		/obj/machinery/computer/voidcrew_cargo = "cargo console",
		/obj/item/storage/box/rndboards/all = "R&D board kit",
	)

/**
 * Whether some upgrade slot on this hull guarantees the fitting: the Delta
 * carries no cargo console on the hull, but all three modules that can fill
 * `delta_cargo` carry one, so no configuration can launch without it.
 */
/datum/unit_test/voidcrew_ship_standard_equipment/proc/slot_guarantees(datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, theme_id, equipment_path)
	for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
		var/list/candidates = get_modules_for_ship_slot(hull.type, theme_id, slot_key)
		if(!length(candidates))
			continue
		var/all_carry = TRUE
		for(var/datum/ship_upgrade_module/module as anything in candidates)
			var/map_file = "[SHIP_MODULE_MAP_ROOT][vc_test_themed_module_filename(module.map_file, theme_id)]"
			if(!fexists(map_file))
				map_file = "[SHIP_MODULE_MAP_ROOT][module.map_file]"
			var/text = vc_test_file_text(map_file)
			if(!text || !vc_test_map_has_path(text, equipment_path))
				all_carry = FALSE
				break
		if(all_carry)
			return TRUE
	return FALSE

/datum/unit_test/voidcrew_ship_standard_equipment/Run()
	ensure_ship_upgrades_initialized()
	var/checked = 0
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		// The curated gag hulls are three or four tiles and a joke; they carry
		// none of this on purpose.
		if(hull.force_purchasable)
			continue
		var/list/themes = GLOB.ship_themes[hull.type]
		if(!length(themes))
			TEST_FAIL("[hull.type] is a purchasable modular hull with no themes registered")
			continue
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			var/map_text = vc_test_file_text("[hull.prefix]ship_[theme.template_suffix].dmm")
			if(!map_text)
				continue // the module-map test owns missing theme maps
			checked++
			for(var/equipment_path in required_equipment)
				if(vc_test_map_has_path(map_text, equipment_path))
					continue
				if(slot_guarantees(hull, theme, theme_id, equipment_path))
					continue
				TEST_FAIL("[theme.template_suffix] ships without a [required_equipment[equipment_path]] ([equipment_path]), and no upgrade slot guarantees one. Every purchasable hull launches with a mission board and pad, a bank machine, a cargo console and an R&D board kit, either on the hull, or on every module that can fill one of its slots.")
	TEST_ASSERT(checked >= 15, "only [checked] hull/theme maps were checked for starting equipment")

/**
 * # The docking port's own tile
 *
 * /datum/map_template/shuttle/dispatch() walks the loaded block and skips space
 * turfs before it stamps baseturfs. A hull that maps its mobile port onto space
 * therefore never gets its port tile stamped with the shuttle skipover, so that
 * tile does not travel with the ship.
 *
 * It used to be far worse: the port setup lived below that skip, so such a hull
 * also never got calculate_docking_port_information() - no dimensions, no
 * shuttle_areas - and linkup() then walked zero areas, leaving every machine
 * that binds through connect_to_shuttle() unbound. Round 809's Scarab-C reached
 * roundstart with no cryopod spawn points at all and could not be joined.
 * dispatch() now hoists the port setup above the skip, but the tile is still
 * wrong, so keep it mapped as real deck.
 *
 * Checked per theme, not per template: a hull's themes are separate .dmm files
 * and only the default one is reachable through `mappath`.
 */
/datum/unit_test/voidcrew_hull_port_tile

/datum/unit_test/voidcrew_hull_port_tile/Run()
	ensure_ship_upgrades_initialized()
	var/checked = 0
	var/list/hulls = vc_test_voidcrew_hull_templates() // keyed by typepath, templates are the values
	for(var/hull_type in hulls)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		var/list/map_paths = list(hull.mappath)
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			map_paths |= "[hull.prefix]ship_[theme.template_suffix].dmm"
		for(var/map_path in map_paths)
			var/text = vc_test_file_text(map_path)
			if(!text)
				continue // missing theme maps are the module-map test's business
			var/port_at = findtext(text, "/obj/docking_port/mobile/")
			if(!port_at)
				continue // the dock rotation test owns portless hulls
			checked++
			// TGM lists every obj on a tile before the tile's single /turf line, so
			// the first /turf after the port entry is the turf the port stands on.
			var/turf_at = findtext(text, "\n/turf/", port_at)
			if(!turf_at)
				TEST_FAIL("[map_path] has a mobile docking port entry with no turf")
				continue
			turf_at++ // step over the newline
			var/index = turf_at
			var/limit = length(text)
			while(index <= limit)
				var/char = copytext(text, index, index + 1)
				if(char == "," || char == "{" || char == "\n" || char == ascii2text(13)) // 13 = carriage return; DM has no \r escape
					break
				index++
			var/turf/tile_type = text2path(trim(copytext(text, turf_at, index)))
			if(!ispath(tile_type, /turf))
				TEST_FAIL("[map_path]'s docking port tile did not resolve to a turf type")
				continue
			if(ispath(tile_type, /turf/open/space) || ispath(tile_type, /turf/template_noop))
				TEST_FAIL("[map_path] maps its mobile docking port onto [tile_type]. The port tile must be real deck - dispatch() skips space turfs when it stamps the shuttle skipover baseturf, so this tile does not move with the ship.")
	TEST_ASSERT(checked >= 15, "only [checked] hull/theme maps were checked for their docking port tile")

/**
 * # Hull mount integrity at load
 *
 * Loads every purchasable hull as a real template (no placement move, no
 * reconcile pass - the pure state the map loader and the skipover stamping in
 * /datum/map_template/shuttle/load() produce) and asserts the two properties a
 * shuttle move needs to carry a tile: the shuttle skipover baseturf, and a
 * registered area. A mount tile born without either survives its first moves
 * only by the engine's MOVE_CONTENTS ride (the tile stays behind, the engine
 * hops onto the destination's raw ground) and eventually strands the engine at
 * whatever site unloads next - rounds 803/804's recurring thruster losses.
 */
/datum/unit_test/voidcrew_hull_mount_integrity
	priority = TEST_LONGER

/datum/unit_test/voidcrew_hull_mount_integrity/Run()
	ensure_ship_upgrades_initialized()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		// Full preview lifecycle both sides of the load: leftover preview state from
		// a previous iteration (or anything else) wedges load_template forever.
		SSshuttle.unload_preview()
		SSshuttle.load_template(hull)
		var/obj/docking_port/mobile/port = SSshuttle.preview_shuttle
		if(!port)
			TEST_FAIL("[hull.type] failed to load as a preview template")
			continue
		var/engines_seen = 0
		for(var/turf/hull_turf as anything in port.return_ordered_turfs(port.x, port.y, port.z, port.dir))
			if(!hull_turf)
				continue
			var/area/tile_area = hull_turf.loc
			var/registered = port.shuttle_areas[tile_area]
			var/is_hull_tile = isshuttleturf(hull_turf)
			if(registered && !is_hull_tile && !isspaceturf(hull_turf))
				TEST_FAIL("[hull.type]: [hull_turf.type] at ([hull_turf.x],[hull_turf.y]) loads in registered [tile_area.type] without the shuttle skipover - a move will leave it behind")
			for(var/obj/machinery/power/shuttle_engine/engine in hull_turf)
				engines_seen++
				if(!is_hull_tile)
					TEST_FAIL("[hull.type]: [engine.name] loads at ([hull_turf.x],[hull_turf.y]) on [hull_turf.type] without the shuttle skipover - its mount will be left behind by a move")
				else if(!registered)
					TEST_FAIL("[hull.type]: [engine.name] loads at ([hull_turf.x],[hull_turf.y]) in unregistered area [tile_area.type]")
		if(!engines_seen && !hull.force_purchasable)
			TEST_FAIL("[hull.type] loaded with no mapped engines anywhere in its footprint")
		SSshuttle.unload_preview()

/**
 * # Hull does not stand proud of its docking port
 *
 * Loads every purchasable hull and asserts nothing on it sits outward of the mobile
 * docking port's facing plane.
 *
 * Exit-to-exit berths are laid exactly one tile off the anchor - position_dock_across_from()
 * for ship-to-ship, position_cargo_dock_next_to_ship() for cargo deliveries - and docking
 * plants the mobile port's origin on that berth tile. So every tile of hull past the port
 * lands inside the ship being docked with and overwrites it. canDock() is blind to this:
 * both berth-placement procs derive the stationary port's dwidth/dheight from the mobile
 * port's own, so the bounds test compares a number against itself.
 *
 * The whole face is measured, not just the tile ahead of the port, because a room bolted to
 * one corner of the bow leaves that tile clear while its far corner still rams the neighbour.
 *
 * Players can reach this state by expanding a hull; hull_survey.dm refuses a claim that
 * would overhang with no door to reseat the port onto, and reseats it automatically when
 * there is one. A hull that ships this way out of its .dmm has no such recovery, so it is
 * caught here instead.
 */
/datum/unit_test/voidcrew_hull_port_overhang
	priority = TEST_LONGER

/datum/unit_test/voidcrew_hull_port_overhang/Run()
	ensure_ship_upgrades_initialized()
	var/checked = 0
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		// Full preview lifecycle both sides of the load: leftover preview state from a
		// previous iteration (or anything else) wedges load_template forever.
		SSshuttle.unload_preview()
		SSshuttle.load_template(hull)
		var/obj/docking_port/mobile/port = SSshuttle.preview_shuttle
		if(!port)
			TEST_FAIL("[hull.type] failed to load as a preview template")
			continue
		checked++
		var/list/overhang = hull_port_overhang(port, null)
		if(overhang[1] > 0)
			var/turf/worst = overhang[2]
			TEST_FAIL("[hull.type]: [overhang[1]] tile\s of hull stand out past the docking port, \
				worst at ([worst?.x],[worst?.y]) ([worst?.type]). Move the mapped port onto the \
				outermost hull door, or this ship overwrites whatever it docks with.")
		SSshuttle.unload_preview()
	TEST_ASSERT(checked >= 5, "only [checked] purchasable hulls were checked for port overhang")

#undef SHIP_MODULE_MAP_ROOT
