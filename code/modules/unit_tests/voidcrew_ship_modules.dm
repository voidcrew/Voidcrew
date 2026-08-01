/**
 * # Modular fleet conformance
 *
 * Five modular hulls x 19 theme maps x 67 modules x 126 module `.dmm` files,
 * wired together by string ids (slot keys, theme ids, map filenames) that no
 * compiler checks. Rename a `.dmm`, add a theme, or forget a default and the
 * failure is silent: the slot loads nothing, or the purchase screen shows a
 * card for a hull that no longer looks like that.
 *
 * Nothing here loads a ship. A CIBUILDING world boots MetaStation, but
 * SSmapping.shuttle_templates is built from subtypesof() and is therefore
 * populated on any map, with each template's width/height already preloaded
 * from its `.dmm` bounds.
 */

/// TOML `directory` key in voidcrew/modules/ship_upgrades/ship_upgrades.toml
#define SHIP_MODULE_MAP_ROOT "_maps/voidcrew/ship_modules/"
/// Where generate_ship_previews.py writes the baked purchase-screen art
#define SHIP_PREVIEW_ROOT "voidcrew/modules/ship_upgrades/previews/"

/datum/unit_test/voidcrew_ship_module_maps
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_module_maps/Run()
	ensure_ship_upgrades_initialized()
	TEST_ASSERT(length(GLOB.ship_themes), "no ship themes are registered — the whole modular layer is missing")
	TEST_ASSERT(length(GLOB.ship_upgrade_modules), "no ship upgrade modules are registered")

	var/list/hulls = vc_test_voidcrew_hull_templates()
	var/checked_slots = 0
	for(var/hull_type in GLOB.ship_themes)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		if(!hull)
			TEST_FAIL("[hull_type] has themes registered but no shuttle template — nothing can ever load it")
			continue
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			var/theme_map = "[hull.prefix]ship_[theme.template_suffix].dmm"
			var/map_text = vc_test_file_text(theme_map)
			if(!map_text)
				TEST_FAIL("[hull_type] theme '[theme_id]' points at a missing map: [theme_map]")
				continue
			if(!(theme_id in hull.available_themes))
				TEST_FAIL("theme '[theme_id]' is registered for [hull_type] but is not in the hull's available_themes, so the upgrade selector never offers it")
			for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
				checked_slots++
				if(!findtext(map_text, "key = \"[slot_key]\""))
					TEST_FAIL("[theme_map] has no /obj/modular_map_root/ship_upgrade marker keyed '[slot_key]' — that slot silently loads nothing on this theme")
				var/defaults = 0
				var/list/candidates = get_modules_for_ship_slot(hull_type, theme_id, slot_key)
				if(!length(candidates))
					TEST_FAIL("[hull_type] slot '[slot_key]' has no module available on theme '[theme_id]' — the slot loads nothing at all")
				for(var/datum/ship_upgrade_module/module as anything in candidates)
					if(module.is_default)
						defaults++
					var/base_file = "[SHIP_MODULE_MAP_ROOT][module.map_file]"
					var/themed_file = "[SHIP_MODULE_MAP_ROOT][vc_test_themed_module_filename(module.map_file, theme_id)]"
					if(!fexists(base_file) && !fexists(themed_file))
						TEST_FAIL("module '[module.id]' has no map for theme '[theme_id]' — the loader looks for [themed_file], then [base_file], then quietly deletes the marker")
				if(defaults != 1)
					TEST_FAIL("[hull_type] slot '[slot_key]' on theme '[theme_id]' has [defaults] default modules, expected exactly 1. The loader falls back to a slot's default whenever a player selected nothing, and on some hulls (goon's cockpit and engineering) that fallback is the only guarantee of a helm and a power plant.")
	TEST_ASSERT(checked_slots > 20, "only [checked_slots] hull/theme/slot combinations were checked — the registry walk is not seeing the fleet")

	// Themeless hulls (the dev fixture, the pill) never enter the loop above, so
	// sweep every registered module once for a map that exists at all.
	for(var/hull_type in GLOB.ship_upgrade_modules)
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			if(fexists("[SHIP_MODULE_MAP_ROOT][module.map_file]"))
				continue
			var/list/declared_themes = islist(module.for_theme) ? module.for_theme : list(module.for_theme)
			var/resolved = FALSE
			for(var/theme_id in declared_themes)
				if(theme_id && fexists("[SHIP_MODULE_MAP_ROOT][vc_test_themed_module_filename(module.map_file, theme_id)]"))
					resolved = TRUE
					break
			if(!resolved)
				TEST_FAIL("module '[module_id]' ([hull_type]) has no map on disk under any theme: [SHIP_MODULE_MAP_ROOT][module.map_file]")

	// Every shipped module map, whether or not anything references it.
	var/list/module_maps = list()
	vc_test_collect_dmm_files(SHIP_MODULE_MAP_ROOT, module_maps)
	TEST_ASSERT(length(module_maps) > 50, "the module map scan found only [length(module_maps)] .dmm files under [SHIP_MODULE_MAP_ROOT] — wrong root?")
	for(var/map_file in module_maps)
		var/text = module_maps[map_file]
		// A module loads into an already-built hull. Every tile must carry the
		// no-op area or the module stamps its own area over the hull's and takes
		// that room's APC, air alarm and atmos with it (MAPPER_GUIDE).
		var/total_areas = vc_test_count_occurrences(text, "/area/")
		var/noop_areas = vc_test_count_occurrences(text, "/area/template_noop")
		if(total_areas != noop_areas)
			TEST_FAIL("[map_file] uses [total_areas - noop_areas] area path(s) other than /area/template_noop — a module must never stamp its own area over the hull's")
		var/connectors = vc_test_count_occurrences(text, "/obj/modular_map_connector")
		if(connectors != 1)
			TEST_FAIL("[map_file] places [connectors] /obj/modular_map_connector, expected exactly 1 — the connector is how the module anchors onto its slot marker")

/**
 * The purchase screen does not render maps live: it shows committed PNGs and
 * manifest.json out of voidcrew/modules/ship_upgrades/previews/. Any edit to a
 * hull or module map is invisible there until the previews are regenerated, so
 * this pins the manifest to the maps by content rather than by mtime.
 */
/datum/unit_test/voidcrew_ship_previews
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_previews/Run()
	ensure_ship_upgrades_initialized()
	var/manifest_text = vc_test_file_text("[SHIP_PREVIEW_ROOT]manifest.json")
	TEST_ASSERT_NOTNULL(manifest_text, "the baked ship-preview manifest is missing — every card on the purchase screen renders blank")
	var/list/manifest = json_decode(manifest_text)
	TEST_ASSERT(islist(manifest), "manifest.json did not parse into a list")
	var/list/hull_entries = manifest["hulls"]
	var/list/module_entries = manifest["modules"]
	TEST_ASSERT(length(hull_entries), "manifest.json lists no hulls")
	TEST_ASSERT(length(module_entries), "manifest.json lists no modules")

	var/list/hulls = vc_test_voidcrew_hull_templates()
	for(var/hull_type in GLOB.ship_themes)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		if(!hull)
			continue
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			var/list/entry = hull_entries[theme.template_suffix]
			if(!islist(entry))
				TEST_FAIL("the preview manifest has no entry for '[theme.template_suffix]' — that hull/theme is a blank card on the purchase screen. Regenerate with tools/ship_previews/generate_ship_previews.py and commit the PNGs with the map change.")
				continue
			if(!fexists("[SHIP_PREVIEW_ROOT][entry["png"]]"))
				TEST_FAIL("manifest entry '[theme.template_suffix]' names [entry["png"]], which is not on disk")
			var/map_text = vc_test_file_text("[hull.prefix]ship_[theme.template_suffix].dmm")
			if(!map_text)
				continue
			var/list/baked_slots = entry["slots"] || list()
			for(var/slot_key in baked_slots)
				if(!findtext(map_text, "key = \"[slot_key]\""))
					TEST_FAIL("the preview manifest bakes a slot '[slot_key]' onto [theme.template_suffix] that the map no longer has — the previews are stale")
			for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
				if(!(slot_key in baked_slots))
					TEST_FAIL("[theme.template_suffix] declares slot '[slot_key]' but the preview manifest has no position baked for it — the selector cannot composite that module onto the hull")

	for(var/hull_type in GLOB.ship_upgrade_modules)
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			var/list/entry = module_entries[module.map_file]
			if(!islist(entry))
				TEST_FAIL("the preview manifest has no entry for module map '[module.map_file]' ([module_id]) — it composites as an empty slot in the selector")
				continue
			if(!fexists("[SHIP_PREVIEW_ROOT][entry["png"]]"))
				TEST_FAIL("module '[module_id]' names preview [entry["png"]], which is not on disk")
			var/list/themed_entries = entry["themes"]
			for(var/theme_id in themed_entries)
				var/list/themed_entry = themed_entries[theme_id]
				if(!islist(themed_entry) || !fexists("[SHIP_PREVIEW_ROOT][themed_entry["png"]]"))
					TEST_FAIL("module '[module_id]' theme '[theme_id]' names a preview that is not on disk")

#undef SHIP_MODULE_MAP_ROOT
#undef SHIP_PREVIEW_ROOT
