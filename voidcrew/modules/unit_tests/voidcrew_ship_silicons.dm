/datum/unit_test/voidcrew_ship_silicon_maps
	priority = TEST_LONGER

/// Validate source definitions as well as effective rosters, including unused overrides.
/datum/unit_test/voidcrew_ship_silicon_maps/proc/check_roster(list/jobs, label)
	for(var/list/definition as anything in jobs)
		var/error = ship_job_definition_error(definition)
		if(error)
			TEST_FAIL("[label]: [error]")

/proc/vc_test_ai_slots(list/jobs)
	var/count = 0
	for(var/list/definition as anything in jobs)
		if(definition["role"] == "ai")
			count += definition["slots"]
	return count

/// Only grid instances on a ship floor count; dictionary-only atoms do not.
/proc/vc_test_crew_core_locations(datum/vc_test_ship/ship, from_module = FALSE)
	var/list/result = list()
	for(var/index in 1 to length(ship.tiles))
		var/list/tile = ship.tiles[index]
		if(length(tile) < 2 || !vc_test_entry_is(tile[length(tile) - 1], /turf/open/floor) || !vc_test_entry_is(tile[length(tile)], /area/shuttle/voidcrew))
			continue
		var/list/atoms = tile
		if(from_module)
			atoms = ship.module_atoms[index]
		else if(ship.module_slots[index])
			atoms = ship.hull_atoms[index]
		for(var/entry in atoms)
			var/obj/structure/ai_core/latejoin_inactive/core = vc_test_entry_type(entry)
			if(!ispath(core, /obj/structure/ai_core/latejoin_inactive))
				continue
			if(!vc_test_entry_boolean(entry, "active", initial(core.active)) || !vc_test_entry_boolean(entry, "available", initial(core.available)))
				continue
			var/key = "[index]"
			result[key] = (result[key] || 0) + 1
	return result

/datum/unit_test/voidcrew_ship_silicon_maps/Run()
	ensure_ship_upgrades_initialized()
	var/list/hulls = vc_test_voidcrew_hull_templates()
	for(var/hull_type in hulls)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		check_roster(hull.job_slots, "[hull_type]")
		var/list/themes = GLOB.ship_themes[hull_type]
		var/list/theme_ids = length(themes) ? assoc_to_keys(themes) : list("")
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			check_roster(module.job_slots_add, "[hull_type]/[module_id]")
			for(var/theme_id in module.job_slots_add_by_theme)
				check_roster(module.job_slots_add_by_theme[theme_id], "[hull_type]/[module_id]/[theme_id]")
		for(var/theme_id in theme_ids)
			var/datum/ship_theme/theme = themes?[theme_id]
			check_roster(theme?.job_slots, "[hull_type]/[theme_id]")
			var/error = vc_test_silicon_theme_error(hull, theme_id, theme)
			if(error)
				TEST_FAIL(error)

/proc/vc_test_silicon_theme_error(datum/map_template/shuttle/voidcrew/hull, theme_id, datum/ship_theme/theme)
	var/hull_type = hull.type
	var/list/base_jobs = length(theme?.job_slots) ? theme.job_slots : hull.job_slots
	var/has_ai = vc_test_ai_slots(base_jobs)
	var/list/slots = get_upgrade_slot_ids_for_theme(hull, theme)
	for(var/slot in slots)
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull_type, theme_id || null, slot))
			has_ai += vc_test_ai_slots(module.crew_for_theme(theme_id || null))
	if(!has_ai)
		return null
	var/hull_map = theme ? "[hull.prefix]ship_[theme.template_suffix].dmm" : hull.mappath
	var/datum/vc_test_fitout/fitout = vc_test_build_fitout(hull_type, theme_id, hull_map, "[hull_type]/[theme_id]", list())
	var/datum/vc_test_ship/bare = vc_test_assemble_ship(fitout)
	if(!bare)
		return "[fitout.label]: cannot read AI crew hull map"
	var/list/permanent = vc_test_crew_core_locations(bare)
	var/required = vc_test_ai_slots(base_jobs)
	for(var/slot in slots)
		var/deficit = 0
		for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull_type, theme_id || null, slot))
			var/map_path = vc_test_module_map_path(module, theme_id || null)
			if(!map_path)
				return "[fitout.label]/[module.id]: cannot read AI crew module map"
			fitout.slot_maps = list()
			fitout.slot_maps[slot] = map_path
			var/datum/vc_test_ship/pair = vc_test_assemble_ship(fitout)
			var/list/surviving = vc_test_crew_core_locations(pair)
			for(var/key in permanent)
				permanent[key] = min(permanent[key], surviving[key] || 0)
			var/own = 0
			var/list/own_cores = vc_test_crew_core_locations(pair, TRUE)
			for(var/key in own_cores)
				own += own_cores[key]
			deficit = max(deficit, vc_test_ai_slots(module.crew_for_theme(theme_id || null)) - own)
		required += deficit
	var/available = 0
	for(var/key in permanent)
		available += permanent[key]
	if(required > available)
		return "[fitout.label]: AI crew needs [required - available] more mapped networked AI cores in the permanent hull or the module adding the role"
	return null

/datum/unit_test/voidcrew_ship_silicon_roles/Run()
	check_borg_spawn()
	var/list/jobs = list(
		list(name = "Engineering borg", role = "cyborg", borg_model = /obj/item/robot_model/engineering, category = "Silicon", slots = 2),
		list(name = "Ship AI", role = "ai", category = "Silicon", slots = 1),
	)
	var/list/assembled = assemble_job_slots_from_list(jobs)
	TEST_ASSERT_EQUAL(length(assembled), 2, "Silicon jobs were dropped for lacking human outfits")
	var/datum/job/borg = assembled[1]
	var/datum/job/ai = assembled[2]
	TEST_ASSERT(istype(borg, /datum/job/cyborg), "Borg role did not use the real cyborg job")
	TEST_ASSERT_EQUAL(borg.spawn_type, /mob/living/silicon/robot, "Borg would spawn human")
	TEST_ASSERT_EQUAL(borg.ship_borg_model, /obj/item/robot_model/engineering, "Chosen borg model lost")
	TEST_ASSERT_EQUAL(assembled[borg], 2, "Borg slot count lost")
	TEST_ASSERT(istype(ai, /datum/job/ai), "AI role did not use the real AI job")
	TEST_ASSERT(!(borg.job_flags & JOB_ASSIGN_QUIRKS), "Borg received human quirks")
	TEST_ASSERT(ship_job_definition_error(list(role = "cyborg", slots = 1)), "Missing borg model accepted")
	TEST_ASSERT(ship_job_definition_error(list(role = "ai", slots = 0)), "Zero AI slots accepted")
	TEST_ASSERT(ship_job_definition_error(list(role = "ai", slots = 1, officer = TRUE)), "Silicon officer accepted")
	TEST_ASSERT(ship_job_definition_error(list(role = "unknown", slots = 1)), "Unknown role accepted")
	for(var/datum/job/job as anything in assembled)
		qdel(job)

/datum/unit_test/voidcrew_ship_silicon_roles/proc/check_borg_spawn()
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	ship.ship_team = allocate(/datum/team/voidcrew)
	ship.ship_team.ship = ship
	ship.shuttle = allocate(/obj/docking_port/mobile/voidcrew)
	var/datum/job/cyborg/job = allocate(/datum/job/cyborg)
	job.ship_role = "cyborg"
	job.ship_borg_model = /obj/item/robot_model/engineering
	job.crew_ship_ref = WEAKREF(ship)
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot)
	borg.mind_initialize()
	borg.mind.set_assigned_role(job)
	job.finish_ship_silicon_spawn(borg, ship)
	TEST_ASSERT(istype(borg.model, /obj/item/robot_model/engineering), "Spawn did not install the mapper's borg model")
	TEST_ASSERT(borg.mind in ship.ship_team.members, "Borg did not join the ship crew")
	TEST_ASSERT_EQUAL(ship.manifest[borg.real_name], job, "Borg missing from ship manifest")
	TEST_ASSERT(!borg.connected_ai, "Borg connected to an AI from another ship")
	var/obj/structure/ai_core/latejoin_inactive/core = allocate(/obj/structure/ai_core/latejoin_inactive)
	ship.shuttle.shuttle_areas = list(get_area(core) = TRUE)
	TEST_ASSERT_EQUAL(ship.available_crew_ai_core(), core, "Available core on this ship was not found")
	core.available = FALSE
	TEST_ASSERT(!ship.available_crew_ai_core(), "Reserved core was reused")
	core.available = TRUE
	core.active = FALSE
	TEST_ASSERT(!ship.available_crew_ai_core(), "Disabled core was accepted")
	core.active = TRUE
	ship.shuttle.shuttle_areas = list()
	TEST_ASSERT(!ship.available_crew_ai_core(), "Core on another ship was accepted")

/datum/unit_test/voidcrew_ship_silicon_core_scan/Run()
	check_hull_requirement()
	var/datum/vc_test_ship/ship = new
	ship.tiles = list(list("/obj/structure/ai_core/latejoin_inactive", "/turf/open/floor/plating", "/area/shuttle/voidcrew"))
	ship.module_slots = new /list(1)
	ship.module_atoms = new /list(1)
	ship.hull_atoms = new /list(1)
	var/list/cores = vc_test_crew_core_locations(ship)
	TEST_ASSERT_EQUAL(cores["1"], 1, "Mapped hull core was not counted")
	TEST_ASSERT_EQUAL(length(vc_test_crew_core_locations(ship, TRUE)), 0, "Hull core was counted as a module core")
	for(var/bad_core in list("/obj/structure/ai_core", "/obj/structure/ai_core/deactivated", "/obj/structure/ai_core/latejoin_inactive{available = FALSE}", "/obj/structure/ai_core/latejoin_inactive{active = 0}"))
		ship.tiles[1] = list(bad_core, "/turf/open/floor/plating", "/area/shuttle/voidcrew")
		TEST_ASSERT_EQUAL(length(vc_test_crew_core_locations(ship)), 0, "Unusable core [bad_core] was accepted")
	ship.tiles[1] = list("/obj/structure/ai_core/latejoin_inactive", "/turf/open/space", "/area/shuttle/voidcrew")
	TEST_ASSERT_EQUAL(length(vc_test_crew_core_locations(ship)), 0, "Core floating in space was accepted")
	ship.tiles[1] = list("/obj/structure/ai_core/latejoin_inactive", "/turf/open/floor/plating", "/area/shuttle/voidcrew")
	ship.module_slots[1] = "robotics"
	ship.module_atoms[1] = list("/obj/structure/ai_core/latejoin_inactive")
	ship.hull_atoms[1] = list()
	TEST_ASSERT_EQUAL(length(vc_test_crew_core_locations(ship)), 0, "Optional module core was counted as a permanent hull core")
	cores = vc_test_crew_core_locations(ship, TRUE)
	TEST_ASSERT_EQUAL(cores["1"], 1, "Module core was lost")
	qdel(ship)

/// Exercise the actual CI rejection path using a copy of a parsed hull's grid.
/datum/unit_test/voidcrew_ship_silicon_core_scan/proc/check_hull_requirement()
	var/datum/map_template/shuttle/voidcrew/pill/hull = allocate(/datum/map_template/shuttle/voidcrew/pill)
	hull.upgrade_slot_ids = list()
	hull.job_slots = list(list(name = "AI", role = "ai", slots = 1))
	var/missing_error = vc_test_silicon_theme_error(hull)
	var/datum/vc_test_dmm/map = vc_test_parse_dmm(hull.mappath)
	TEST_ASSERT(map, "Could not parse the Pill test hull")
	var/list/original_grid = map.grid
	var/list/original_dictionary = map.dictionary
	map.grid = original_grid.Copy()
	map.dictionary = original_dictionary.Copy()
	var/placed = FALSE
	for(var/index in 1 to length(map.grid))
		var/list/tile = map.dictionary[map.grid[index]]
		if(length(tile) < 2 || !vc_test_entry_is(tile[length(tile) - 1], /turf/open/floor) || !vc_test_entry_is(tile[length(tile)], /area/shuttle/voidcrew))
			continue
		var/list/with_core = tile.Copy()
		with_core.Insert(1, "/obj/structure/ai_core/latejoin_inactive")
		map.dictionary["silicon-test"] = with_core
		map.grid[index] = "silicon-test"
		placed = TRUE
		break
	var/valid_error = vc_test_silicon_theme_error(hull)
	hull.job_slots = list(list(name = "AI", role = "ai", slots = 2))
	var/capacity_error = vc_test_silicon_theme_error(hull)
	map.grid = original_grid
	map.dictionary = original_dictionary
	TEST_ASSERT(placed, "Could not place test core on a ship floor")
	TEST_ASSERT(missing_error, "CI accepted AI crew without any mapped core")
	TEST_ASSERT(!valid_error, "CI rejected a hull with a mapped core: [valid_error]")
	TEST_ASSERT(capacity_error, "CI accepted two AI slots sharing one mapped core")
