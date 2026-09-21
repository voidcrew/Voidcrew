/**
 * # Ship Preview Assets
 *
 * Serves pre-rendered ship hull and module PNGs to the ShipUpgradeSelector TGUI
 * so players can see the composited ship before buying.
 *
 * The PNGs and the compositing geometry (slot marker positions, module connector
 * offsets) are generated from the DMMs by tools/ship_previews/generate_ship_previews.py.
 * Re-run that script after editing modular hulls or module maps.
 */

#define SHIP_PREVIEW_DIR "voidcrew/modules/ship_upgrades/previews/"

GLOBAL_LIST(ship_preview_manifest)

/**
 * Combine independent hull/module metadata into the selector's cached index.
 * No shared file needs to change when an unrelated ship is added or edited.
 */
/proc/get_ship_preview_manifest()
	if(!isnull(GLOB.ship_preview_manifest))
		return GLOB.ship_preview_manifest
	GLOB.ship_preview_manifest = load_ship_preview_metadata(SHIP_PREVIEW_DIR)
	return GLOB.ship_preview_manifest

/proc/load_ship_preview_metadata(directory, list/manifest)
	var/is_root = isnull(manifest)
	if(is_root)
		manifest = list("tile_px" = 32, "hulls" = list(), "modules" = list())
	for(var/filename in flist(directory))
		if(endswith(filename, "/"))
			if(!is_root || (filename in list("hulls/", "modules/")))
				load_ship_preview_metadata("[directory][filename]", manifest)
			continue
		if(!endswith(filename, ".preview.json"))
			continue
		var/list/parsed = json_decode(file2text("[directory][filename]"))
		if(!islist(parsed) || parsed["tile_px"] != manifest["tile_px"])
			CRASH("Invalid ship preview metadata: [directory][filename]")
		var/entry_count = 0
		for(var/group in list("hulls", "modules"))
			var/list/entries = parsed[group]
			if(!islist(entries))
				CRASH("Invalid ship preview group in [directory][filename]")
			var/list/combined = manifest[group]
			for(var/key in entries)
				if(!islist(entries[key]) || !isnull(combined[key]))
					CRASH("Invalid or duplicate ship preview [key] in [directory][filename]")
				combined[key] = entries[key]
				entry_count++
		if(entry_count != 1)
			CRASH("Expected one hull or module in [directory][filename]")
	return manifest

/datum/asset/simple/ship_previews

/datum/asset/simple/ship_previews/register()
	assets = list()
	var/list/manifest = get_ship_preview_manifest()

	var/list/hulls = manifest["hulls"]
	for(var/hull_key in hulls)
		var/list/hull = hulls[hull_key]
		add_preview_png(hull["png"])

	var/list/modules = manifest["modules"]
	for(var/map_file in modules)
		var/list/entry = modules[map_file]
		add_preview_png(entry["png"])
		var/list/themed_variants = entry["themes"]
		for(var/theme_id in themed_variants)
			var/list/variant = themed_variants[theme_id]
			add_preview_png(variant["png"])

	return ..()

/datum/asset/simple/ship_previews/proc/add_preview_png(png_name)
	if(!png_name || assets[png_name])
		return
	var/png_path = SHIP_PREVIEW_DIR + png_name
	if(!fexists(png_path))
		log_asset("ship_previews: missing preview image [png_path]")
		return
	assets[png_name] = file(png_path)

#undef SHIP_PREVIEW_DIR
