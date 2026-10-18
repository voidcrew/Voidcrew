GLOBAL_DATUM(voidcrew_starting_gun_audit, /datum/unit_test/voidcrew_ship_starting_guns)

/// This policy is independent of fabrication/cargo restrictions and their allowlist.
/proc/vc_test_lethal_starting_gun(item_type)
	if(!ispath(item_type, /obj/item/gun))
		return FALSE
	var/obj/item/gun/gun_type = item_type
	// NOT_A_REAL_GUN also marks the lethal Russian-roulette revolver.
	if(initial(gun_type.gun_flags) & TOY_FIREARM_OVERLAY)
		return FALSE
	var/static/list/allowed = typecacheof(list(
		/obj/item/gun/energy/disabler,
		/obj/item/gun/energy/taser,
		/obj/item/gun/energy/floragun,
		/obj/item/gun/energy/wiremod_gun,
		/obj/item/gun/energy/plasmacutter,
		/obj/item/gun/energy/recharge/kinetic_accelerator,
		/obj/item/gun/energy/recharge/fisher,
		/obj/item/gun/medbeam,
		/obj/item/gun/syringe,
		/obj/item/gun/energy/laser/bluetag,
		/obj/item/gun/energy/laser/redtag,
		/obj/item/gun/energy/laser/chameleon,
		/obj/item/gun/energy/laser/practice,
		/obj/item/gun/energy/e_gun/mini/practice_phaser,
		/obj/item/gun/magic/wand/nothing,
		// Borderline starting equipment is reserved for a separate owner decision.
		/obj/item/gun/ballistic/rifle/boltaction/harpoon,
	))
	if(is_type_in_typecache(item_type, allowed))
		return FALSE
	// The fleet's four stock double-barrels start with beanbags. Do not exempt
	// their lethal-ammunition subtypes (or a mapped magazine override).
	return item_type != /obj/item/gun/ballistic/shotgun/doublebarrel

/// Keep audit spawners until their full loot table can be inspected outside
/// Initialize; expanding nested vendors there could yield during atom initialization.
/obj/effect/spawner/random/Initialize(mapload)
	. = ..()
	if(GLOB.voidcrew_starting_gun_audit && get_turf(src) == GLOB.voidcrew_starting_gun_audit.run_loc_floor_bottom_left)
		return INITIALIZE_HINT_NORMAL

/// Ordinary tests and world initialization retain the normal random spawning path.
/obj/effect/spawner/random/spawn_loot(lootcount_override)
	if(GLOB.voidcrew_starting_gun_audit && get_turf(src) == GLOB.voidcrew_starting_gun_audit.run_loc_floor_bottom_left)
		return
	return ..()

/datum/unit_test/voidcrew_ship_starting_guns
	priority = TEST_LONGER
	var/list/checked_sources = list()
	var/list/checked_spawners = list()
	var/list/inspected_atoms = list()
	var/source_description
	var/maps_checked = 0
	var/kilo_maps_checked = 0
	var/mapload_source = "starting gun audit"

/datum/unit_test/voidcrew_ship_starting_guns/Destroy()
	SSatoms.map_loader_stop(mapload_source)
	if(GLOB.voidcrew_starting_gun_audit == src)
		GLOB.voidcrew_starting_gun_audit = null
	return ..()

/// Only lists are recursive here; weights are never treated as additional loot.
/datum/unit_test/voidcrew_ship_starting_guns/proc/loot_paths(list/loot)
	. = list()
	for(var/entry in loot)
		if(islist(entry))
			. |= loot_paths(entry)
		else if(ispath(entry, /atom/movable))
			. |= entry

/datum/unit_test/voidcrew_ship_starting_guns/proc/inspect_spawner(obj/effect/spawner/random/spawner)
	var/list/choices = loot_paths(spawner.loot)
	if(spawner.loot_type_path)
		choices |= typesof(spawner.loot_type_path)
	if(spawner.loot_subtype_path)
		choices |= subtypesof(spawner.loot_subtype_path)
	var/signature = "[spawner.type]:[json_encode(choices)]"
	if(checked_spawners[signature])
		return
	checked_spawners[signature] = TRUE
	for(var/choice in choices)
		if(!spawner.can_spawn(choice))
			continue
		// Exercise make_item: LO replaces some raw loot-table entries here.
		var/atom/movable/spawned = spawner.make_item(get_turf(spawner), choice)
		if(!QDELETED(spawned))
			inspect_contents(spawned)

/datum/unit_test/voidcrew_ship_starting_guns/proc/inspect_contents(atom/root)
	var/list/pending = root.get_all_contents()
	for(var/index = 1; index <= length(pending); index++)
		var/atom/entry = pending[index]
		if(QDELETED(entry) || inspected_atoms[entry])
			continue
		inspected_atoms[entry] = TRUE
		TEST_ASSERT(!vc_test_lethal_starting_gun(entry.type), "[source_description] supplies [entry.type].")
		if(istype(entry, /obj/effect/spawner/random))
			inspect_spawner(entry)
		if(entry.type == /obj/item/gun/ballistic/shotgun/doublebarrel)
			var/obj/item/gun/ballistic/shotgun/doublebarrel/shotgun = entry
			TEST_ASSERT_EQUAL(shotgun.magazine.ammo_type, /obj/item/ammo_casing/shotgun/beanbag, "[source_description] overrides the borderline shotgun's beanbags.")
		if(istype(entry, /obj/structure/closet/crate/secure/loot))
			// A correct code can roll a gun even when opening/forcing the crate
			// during initialization would leave it empty. No random trial can prove safety.
			TEST_FAIL("[source_description] supplies an abandoned crate with gun-bearing freight pools.")
		if(istype(entry, /obj/structure/closet))
			var/obj/structure/closet/closet = entry
			if(!closet.contents_initialized)
				closet.contents_initialized = TRUE
				closet.PopulateContents()
				SEND_SIGNAL(closet, COMSIG_CLOSET_CONTENTS_INITIALIZED)
		if(istype(entry, /obj/machinery/vending))
			var/obj/machinery/vending/vendor = entry
			for(var/item_type in vendor.products + vendor.contraband + vendor.premium)
				inspect_source(item_type)
			if(istype(vendor, /obj/machinery/vending/security/marine))
				var/obj/machinery/vending/security/marine/marine = vendor
				for(var/choice in marine.voucher_items)
					inspect_source(marine.voucher_items[choice])
		pending |= entry.contents

/// Instantiate stock-bearing map objects once per type AND mapped variable set.
/// Other placed objects still have every mapped item path checked by inspect_map.
/datum/unit_test/voidcrew_ship_starting_guns/proc/inspect_source(source_type, list/attributes = list())
	if(!ispath(source_type, /atom/movable))
		return
	TEST_ASSERT(!vc_test_lethal_starting_gun(source_type), "[source_description] places [source_type].")
	var/static/list/stock_sources = typecacheof(list(
		/obj/item,
		/obj/structure/closet,
		/obj/structure/guncase,
		/obj/structure/safe,
		/obj/structure/secure_safe,
		/obj/structure/displaycase,
		/obj/structure/fireaxecabinet,
		/obj/machinery/vending,
		/obj/machinery/suit_storage_unit,
		/obj/machinery/smartfridge,
		/obj/effect/spawner/random,
		/obj/effect/spawner/costume,
		/obj/effect/spawner/surgery_tray,
		/obj/effect/mob_spawn,
	))
	if(!is_type_in_typecache(source_type, stock_sources))
		return
	var/signature = "[source_type]:[json_encode(attributes)]"
	if(checked_sources[signature])
		return
	checked_sources[signature] = TRUE
	SSatoms.map_loader_begin(mapload_source)
	world.preloader_setup(attributes, source_type)
	var/atom/movable/source = new source_type(run_loc_floor_bottom_left)
	if(GLOB.use_preloader && source)
		world.preloader_load(source)
	SSatoms.map_loader_stop(mapload_source)
	SSatoms.InitializeAtoms(list(source))
	if(!QDELETED(source))
		inspect_contents(source)

/datum/unit_test/voidcrew_ship_starting_guns/proc/inspect_map(map_path)
	source_description = map_path
	var/datum/parsed_map/map = new(file(map_path))
	TEST_ASSERT_NOTNULL(map.parsed_bounds, "Cannot parse [map_path].")
	var/list/bad_paths = list()
	var/list/cache = map.build_cache(TRUE, bad_paths)
	var/list/placed_keys = list()
	for(var/datum/grid_set/grid as anything in map.gridSets)
		for(var/line in grid.gridLines)
			for(var/offset = 1; offset <= length(line); offset += map.key_len)
				placed_keys[copytext(line, offset, offset + map.key_len)] = TRUE
	for(var/path in bad_paths)
		if(findtext(path, "/gun/"))
			for(var/key in bad_paths[path])
				if(placed_keys[key])
					TEST_FAIL("[map_path] contains an unresolvable gun path: [path].")
	for(var/key in placed_keys)
		if(key == cache[SPACE_KEY])
			continue
		var/list/model = cache[key]
		TEST_ASSERT_NOTNULL(model, "[map_path] uses missing map key [key].")
		var/list/members = model[1]
		var/list/attributes = model[2]
		for(var/index in 1 to length(members))
			inspect_source(members[index], attributes[index])
	qdel(map)
	maps_checked++
	if(findtext(map_path, "/ship_kilo_"))
		kilo_maps_checked++
	// Include results ejected onto the floor by spawners and filled containers.
	inspect_contents(run_loc_floor_bottom_left)
	for(var/atom/movable/created in run_loc_floor_bottom_left)
		if(!istype(created, /obj/effect/landmark))
			qdel(created)
	inspected_atoms.Cut()
	CHECK_TICK

/datum/unit_test/voidcrew_ship_starting_guns/proc/inspect_directory(directory)
	for(var/filename in flist(directory))
		if(copytext(filename, -1) == "/")
			inspect_directory("[directory][filename]")
		else if(endswith(filename, ".dmm"))
			inspect_map("[directory][filename]")

/datum/unit_test/voidcrew_ship_starting_guns/Run()
	TEST_ASSERT(vc_test_lethal_starting_gun(/obj/item/gun/energy/e_gun/mini), "Mini e-guns must be detected even when their selected mode is nonlethal.")
	TEST_ASSERT(vc_test_lethal_starting_gun(/obj/item/gun/energy/laser/retro), "Retro lasers must be detected.")
	TEST_ASSERT(vc_test_lethal_starting_gun(/obj/item/gun/energy/ionrifle), "Ion guns must be detected.")
	TEST_ASSERT(vc_test_lethal_starting_gun(/obj/item/gun/ballistic/revolver/russian), "The Russian-roulette revolver is lethal despite NOT_A_REAL_GUN.")
	GLOB.voidcrew_starting_gun_audit = src
	inspect_directory("_maps/voidcrew/ships/")
	inspect_directory("_maps/voidcrew/ship_modules/")
	GLOB.voidcrew_starting_gun_audit = null
	TEST_ASSERT(maps_checked >= 443, "Only [maps_checked] hull/module maps were audited.")
	TEST_ASSERT_EQUAL(kilo_maps_checked, 4, "The audit must include all four Kilo themes.")

/// Authored reload placements (including filled boxes) must serve a starting gun.
/// Shop stock and crew outfits are separate supply channels, not map placements.
/datum/unit_test/voidcrew_ship_starting_ammo
	priority = TEST_LONGER
	var/list/map_inventories = list()
	var/list/source_inventories = list()

/datum/unit_test/voidcrew_ship_starting_ammo/proc/merge_inventory(list/target, list/addition)
	for(var/category in list("ammo", "magazines", "mounted"))
		target[category] |= addition[category]

/datum/unit_test/voidcrew_ship_starting_ammo/proc/empty_inventory()
	return list("ammo" = list(), "magazines" = list(), "mounted" = list())

/// Respect mapped overrides and lazy ammo boxes, just as the gun audit does.
/datum/unit_test/voidcrew_ship_starting_ammo/proc/source_inventory(source_type, list/attributes)
	var/signature = "[source_type]:[json_encode(attributes)]"
	if(source_inventories[signature])
		return source_inventories[signature]
	var/list/inventory = empty_inventory()
	SSatoms.map_loader_begin("starting ammo audit")
	world.preloader_setup(attributes, source_type)
	var/atom/movable/source = new source_type(run_loc_floor_bottom_left)
	if(GLOB.use_preloader && source)
		world.preloader_load(source)
	SSatoms.map_loader_stop("starting ammo audit")
	SSatoms.InitializeAtoms(list(source))
	var/list/pending = source.get_all_contents()
	for(var/atom/entry in pending)
		if(istype(entry, /obj/item/gun/ballistic))
			var/obj/item/gun/ballistic/gun = entry
			inventory["magazines"] |= gun.accepted_magazine_type
		if(istype(entry, /obj/structure/mounted_gun))
			var/obj/structure/mounted_gun/gun = entry
			inventory["mounted"] |= gun.ammo_type
		if(istype(entry, /obj/item/ammo_box))
			var/obj/item/ammo_box/box = entry
			pending |= box.ammo_list()
	// ammo_list may have materialized casings that were absent from get_all_contents.
	for(var/obj/item/ammo_casing/round in pending)
		var/list/ammo = inventory["ammo"]
		ammo["[round.type]:[round.caliber]"] = list("type" = round.type, "caliber" = round.caliber)
	qdel(source)
	source_inventories[signature] = inventory
	return inventory

/datum/unit_test/voidcrew_ship_starting_ammo/proc/map_inventory(map_path)
	if(map_inventories[map_path])
		return map_inventories[map_path]
	var/list/inventory = empty_inventory()
	var/datum/parsed_map/map = new(file(map_path))
	TEST_ASSERT_NOTNULL(map.parsed_bounds, "Cannot parse starting ammo in [map_path].")
	var/list/cache = map.build_cache(TRUE)
	var/list/placed_keys = list()
	for(var/datum/grid_set/grid as anything in map.gridSets)
		for(var/line in grid.gridLines)
			for(var/offset = 1; offset <= length(line); offset += map.key_len)
				placed_keys[copytext(line, offset, offset + map.key_len)] = TRUE
	var/static/list/sources = typecacheof(list(
		/obj/item/gun/ballistic,
		/obj/item/ammo_box,
		/obj/item/ammo_casing,
		/obj/item/storage/box,
		/obj/structure/mounted_gun,
	))
	for(var/key in placed_keys)
		if(key == cache[SPACE_KEY])
			continue
		var/list/model = cache[key]
		TEST_ASSERT_NOTNULL(model, "[map_path] uses missing ammo map key [key].")
		var/list/members = model[1]
		var/list/attributes = model[2]
		for(var/index in 1 to length(members))
			if(is_type_in_typecache(members[index], sources))
				merge_inventory(inventory, source_inventory(members[index], attributes[index]))
	qdel(map)
	map_inventories[map_path] = inventory
	return inventory

/datum/unit_test/voidcrew_ship_starting_ammo/proc/check_ammo(list/inventory, label)
	var/list/ammunition = inventory["ammo"]
	for(var/signature in ammunition)
		var/list/round_info = ammunition[signature]
		var/round_type = round_info["type"]
		var/fits = FALSE
		for(var/mounted_ammo in inventory["mounted"])
			if(ispath(round_type, mounted_ammo))
				fits = TRUE
		if(fits)
			continue
		var/obj/item/ammo_casing/round = allocate(round_type)
		round.caliber = round_info["caliber"]
		for(var/magazine_type in inventory["magazines"])
			var/obj/item/ammo_box/magazine/magazine = allocate(magazine_type)
			for(var/obj/item/ammo_casing/stock as anything in magazine.ammo_list())
				qdel(stock)
			magazine.stored_ammo.Cut()
			fits = magazine.give_round(round)
			qdel(magazine)
			if(fits)
				break
		qdel(round)
		TEST_ASSERT(fits, "[label] starts with [round_type] but no compatible gun in any theme/module option.")

/datum/unit_test/voidcrew_ship_starting_ammo/Run()
	ensure_ship_upgrades_initialized()
	var/list/hulls = vc_test_voidcrew_hull_templates()
	for(var/hull_type in hulls)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		var/list/maps = list(hull.mappath)
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			maps |= "[hull.prefix]ship_[theme.template_suffix].dmm"
			for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
				for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull_type, theme_id, slot_key))
					maps |= vc_test_module_map_path(module, theme_id)
		if(!length(themes))
			var/list/modules = GLOB.ship_upgrade_modules[hull_type]
			for(var/module_id in modules)
				var/datum/ship_upgrade_module/module = modules[module_id]
				maps |= vc_test_module_map_path(module, null)
		// Keep reloads if ANY theme/module combination of this hull starts a fitting gun.
		var/list/inventory = empty_inventory()
		for(var/map_path in maps)
			if(map_path && fexists(map_path))
				merge_inventory(inventory, map_inventory(map_path))
		check_ammo(inventory, "[hull_type]")
		CHECK_TICK
	// Include unused legacy hulls and module variants as well as registered maps.
	var/list/all_maps = list()
	vc_test_collect_dmm_files("_maps/voidcrew/ships/", all_maps)
	vc_test_collect_dmm_files("_maps/voidcrew/ship_modules/", all_maps)
	for(var/map_path in all_maps)
		if(!map_inventories[map_path])
			check_ammo(map_inventory(map_path), map_path)
		CHECK_TICK
	TEST_ASSERT(length(map_inventories) >= 443, "The ammo audit missed hull or module maps.")

/// Discover crew equipment from all hulls, themes, modules and Workshop crew files.
/datum/unit_test/voidcrew_ship_starting_outfits
	parent_type = /datum/unit_test/voidcrew_ship_starting_guns
	priority = TEST_LONGER
	var/list/outfit_types = list()

/datum/unit_test/voidcrew_ship_starting_outfits/proc/add_jobs(list/jobs)
	for(var/list/job as anything in jobs)
		if(ispath(job["outfit"], /datum/outfit))
			outfit_types |= job["outfit"]

/datum/unit_test/voidcrew_ship_starting_outfits/Run()
	GLOB.voidcrew_starting_gun_audit = src
	ensure_ship_upgrades_initialized()
	var/list/hulls = vc_test_voidcrew_hull_templates()
	for(var/hull_type in hulls)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		add_jobs(hull.job_slots)
	for(var/hull_type in GLOB.ship_themes)
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			add_jobs(theme.job_slots)
	for(var/hull_type in GLOB.ship_upgrade_modules)
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			add_jobs(module.job_slots_add)
			for(var/theme_id in module.job_slots_add_by_theme)
				add_jobs(module.crew_for_theme(theme_id))
	for(var/outfit_type in subtypesof(/datum/outfit/job))
		if(findtext("[outfit_type]", "/datum/outfit/job/workshop_") == 1)
			outfit_types |= outfit_type
	TEST_ASSERT(length(outfit_types) > 50, "The ship crew outfit registry was not discovered.")
	for(var/outfit_type in outfit_types)
		source_description = "[outfit_type]"
		// Exercise species equipment before the job outfit, just like dress_up_as_job.
		for(var/species_type in list(/datum/species/human, /datum/species/plasmaman))
			var/datum/outfit/job/outfit = new outfit_type
			var/mob/living/carbon/human/consistent/wearer = allocate(__IMPLIED_TYPE__, run_loc_floor_bottom_left)
			wearer.set_species(species_type)
			var/datum/job/job = SSjob.get_job_type(outfit.jobtype)
			wearer.dna.species.pre_equip_species_outfit(job, wearer, FALSE)
			outfit.equip(wearer)
			source_description = "[outfit_type] ([species_type])"
			inspect_contents(wearer)
			// Also catch equipment dropped by post_equip, failed slots or full bags.
			inspect_contents(run_loc_floor_bottom_left)
			qdel(outfit)
			qdel(wearer)
			for(var/obj/item/item in run_loc_floor_bottom_left)
				qdel(item)
			inspected_atoms.Cut()
		CHECK_TICK
	GLOB.voidcrew_starting_gun_audit = null
