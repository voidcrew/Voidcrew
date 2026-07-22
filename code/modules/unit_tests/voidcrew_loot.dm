/**
 * # Voidcrew loot audit tests
 *
 * Guards the invariants the 2026-07 loot audit found broken by hand:
 *
 * 1. Table hygiene: every loot theme (voidcrew/modules/loot/themes/) has all
 *    six tables populated with sane weighted entries, every guard table
 *    holds real mobs, and — hard design rule — NO megafauna anywhere in the
 *    zone system (that includes this fork's /mob/living/basic/boss tier).
 * 2. Reachability: every authored cache/marker subtype is actually placed in
 *    a shipped ruin .dmm, sold as a shop SKU, or spawned at runtime — so
 *    "fully authored, sprited, and unobtainable" (the wardrobe-rare bug)
 *    can't happen silently again.
 * 3. Guarding: every ruin map that carries a cache carries a guard marker
 *    (or a hand-placed setpiece: an elite, or a whitelisted megafauna),
 *    every map with a /rare cache carries a /boss-tier guard, and megafauna
 *    only ever appear in the enumerated legacy boss-arena ruins — never as
 *    generic cache guards in new maps.
 * 4. Rumor charts: every chart points at a registered template whose map
 *    actually contains caches (including a rare one) and guards.
 */

/// Ruin maps root scanned by the reachability test
#define VOIDCREW_RUIN_MAP_ROOT "_maps/voidcrew/RandomRuins/"

/datum/unit_test/voidcrew_loot_themes

/datum/unit_test/voidcrew_loot_themes/Run()
	if(!length(GLOB.loot_themes))
		TEST_FAIL("GLOB.loot_themes is empty — theme registry never initialized")
		return
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		for(var/table_name in list("loot_green", "loot_yellow", "loot_red", "rare_loot_green", "rare_loot_yellow", "rare_loot_red"))
			var/list/table = theme.vars[table_name]
			if(!length(table))
				TEST_FAIL("[theme_path] has an empty [table_name] table")
				continue
			for(var/entry in table)
				if(!ispath(entry, /atom/movable))
					TEST_FAIL("[theme_path].[table_name] entry [entry] is not an /atom/movable path")
				var/weight = table[entry]
				if(!isnum(weight) || weight <= 0)
					TEST_FAIL("[theme_path].[table_name] entry [entry] has bad weight [weight]")
		for(var/guard in theme.guard_themes)
			if(!ispath(guard, /obj/effect/zone_mobs))
				TEST_FAIL("[theme_path].guard_themes entry [guard] is not a zone_mobs marker")
		for(var/sku in theme.theme_skus)
			if(!ispath(sku, /datum/shop_sku))
				TEST_FAIL("[theme_path].theme_skus entry [sku] is not a shop SKU")

	// every crate subtype must point at a registered theme
	for(var/obj/structure/closet/crate/zone_loot/crate_path as anything in subtypesof(/obj/structure/closet/crate/zone_loot))
		var/theme = initial(crate_path.theme)
		TEST_ASSERT(!isnull(GLOB.loot_themes[theme]), "[crate_path] has no registered loot theme (theme = [theme])")

	// guard tables: real mobs only, and NEVER megafauna — megafauna
	// (including the /mob/living/basic/boss tier) are planet apex content,
	// banned from the zone system by design. initial() can't read list vars,
	// so probe a nullspace instance: with no loc it can never resolve a zone
	// or spawn anything, and its own QDELETED guard covers the late resolver
	// callback after we delete it.
	for(var/marker_path in subtypesof(/obj/effect/zone_mobs))
		var/obj/effect/zone_mobs/marker = new marker_path()
		for(var/table in list(marker.mobs_green, marker.mobs_yellow, marker.mobs_red))
			for(var/entry in table)
				if(!ispath(entry, /mob/living))
					TEST_FAIL("[marker_path] table entry [entry] is not a mob path")
					continue
				if(ispath(entry, /mob/living/simple_animal/hostile/megafauna) || ispath(entry, /mob/living/basic/boss))
					TEST_FAIL("[marker_path] table entry [entry] is MEGAFAUNA — banned from the zone mob system")
		qdel(marker)

/datum/unit_test/voidcrew_loot_reachability
	priority = TEST_LONGER
	/// Cache/marker types that are legitimately spawned only at runtime or
	/// over the counter, so map placement isn't required for them
	var/static/list/runtime_spawned = list(
		// meteor storm fields spawn these (overmap/events.dm)
		/obj/structure/closet/crate/zone_loot/expedition,
		/obj/structure/closet/crate/zone_loot/expedition/rare,
		/obj/effect/zone_mobs/asteroid,
		// the collapsing icemoon portal can spawn any crate + wave; listed
		// here are only the ones with no mapped placements otherwise
	)
	/// Purpose-built boss-arena ruins: the ruin exists to host its megafauna
	/// fight (blood-drunk shrines, the hierophant arena, the wendigo's cave,
	/// Outpost 31, the last ash drake...). Megafauna are allowed ONLY here —
	/// anywhere else they're banned from ruin maps outright (owner rule:
	/// megafauna are never generic loot guards; elites are the ceiling).
	/// Adding a map to this list is a deliberate design decision.
	var/static/list/megafauna_arena_maps = list(
		"icemoon_surface_asteroid.dmm", // clockwork defender
		"icemoon_underground_lavaland.dmm", // the last ash drake
		"icemoon_underground_mining_site.dmm", // demonic frost miner
		"icemoon_underground_outpost31.dmm", // The Thing
		"icemoon_underground_wendigo_cave.dmm", // wendigo
		"lavaland_surface_blooddrunk1.dmm", // blood-drunk miner
		"lavaland_surface_blooddrunk2.dmm",
		"lavaland_surface_blooddrunk3.dmm",
		"lavaland_surface_hierophant.dmm", // hierophant
		"wasteland_heirophant.dmm",
		"wasteland_chaosmarine.dmm", // legion
		"wasteland_surface_bloodrunk1.dmm", // blood-drunk miner
		"wasteland_surface_bloodrunk2.dmm",
		"wasteland_surface_bloodrunk3.dmm",
	)

/datum/unit_test/voidcrew_loot_reachability/proc/collect_dmm_files(root, list/out)
	for(var/entry in flist(root))
		if(copytext(entry, -1) == "/")
			collect_dmm_files("[root][entry]", out)
		else if(copytext(entry, -4) == ".dmm")
			out["[root][entry]"] = file2text("[root][entry]")

/// TGM entries terminate in "," (list continues), "{" (var edits) or ")"
/// (last path in the block) — matching against those avoids prefix hits
/// (e.g. /armory matching /armory/rare)
/datum/unit_test/voidcrew_loot_reachability/proc/has_path(text, path)
	return findtext(text, "[path],") || findtext(text, "[path]{") || findtext(text, "[path])")

/datum/unit_test/voidcrew_loot_reachability/Run()
	var/list/map_texts = list()
	collect_dmm_files(VOIDCREW_RUIN_MAP_ROOT, map_texts)
	TEST_ASSERT(length(map_texts) > 100, "Ruin map scan found only [length(map_texts)] .dmm files under [VOIDCREW_RUIN_MAP_ROOT] — wrong root?")

	// which crate types are sold over a counter
	var/list/sku_sold = list()
	for(var/datum/shop_sku/sku_path as anything in subtypesof(/datum/shop_sku))
		var/item_path = initial(sku_path.item_path)
		if(ispath(item_path, /obj/structure/closet/crate/zone_loot))
			sku_sold[item_path] = TRUE

	var/list/crate_types = subtypesof(/obj/structure/closet/crate/zone_loot)
	var/list/marker_types = subtypesof(/obj/effect/zone_mobs)
	var/list/rare_crate_types = list()
	for(var/obj/structure/closet/crate/zone_loot/crate_path as anything in crate_types)
		if(initial(crate_path.rare))
			rare_crate_types += crate_path

	// ---- reachability: authored means obtainable ----
	for(var/spawnable_path in crate_types + marker_types)
		if((spawnable_path in runtime_spawned) || sku_sold[spawnable_path])
			continue
		var/found = FALSE
		for(var/map_file in map_texts)
			if(has_path(map_texts[map_file], spawnable_path))
				found = TRUE
				break
		if(!found)
			TEST_FAIL("[spawnable_path] is authored but appears in no ruin map, SKU or runtime spawner — dead content")

	// ---- per-map: guards, bosses, and the megafauna arena whitelist ----
	for(var/map_file in map_texts)
		var/text = map_texts[map_file]
		var/short_name = copytext(map_file, findlasttext(map_file, "/") + 1)
		var/has_megafauna = findtext(text, "/mob/living/simple_animal/hostile/megafauna") || findtext(text, "/mob/living/basic/boss")
		if(has_megafauna && !(short_name in megafauna_arena_maps))
			TEST_FAIL("[map_file] places MEGAFAUNA outside the legacy arena whitelist — new ruins use themed /boss zone_mobs markers (elite-tier at most)")
		var/has_cache = FALSE
		for(var/crate_path in crate_types)
			if(has_path(text, crate_path))
				has_cache = TRUE
				break
		if(!has_cache)
			continue
		// a hand-placed setpiece (elite, or an arena's megafauna) counts as
		// the guard/boss — e.g. Pandora's ruin, the blood-drunk shrines
		var/has_setpiece = has_megafauna || findtext(text, "/mob/living/simple_animal/hostile/asteroid/elite")
		if(!findtext(text, "/obj/effect/zone_mobs") && !has_setpiece)
			TEST_FAIL("[map_file] places a loot cache but no zone_mobs guard marker or hand-placed setpiece")
		var/has_rare = FALSE
		for(var/rare_path in rare_crate_types)
			if(has_path(text, rare_path))
				has_rare = TRUE
				break
		if(has_rare)
			var/has_boss = findtext(text, "/boss,") || findtext(text, "/boss{") || findtext(text, "/boss)")
			if(!has_boss && !has_setpiece)
				TEST_FAIL("[map_file] places a /rare cache but no /boss marker or hand-placed setpiece — top loot must be guarded")

	// ---- rumor charts point at real, stocked, guarded ruins ----
	for(var/datum/rumor_chart/chart_path as anything in subtypesof(/datum/rumor_chart))
		var/datum/map_template/ruin/space/template_path = initial(chart_path.ruin_template_path)
		if(isnull(template_path))
			continue
		var/map_path = "[initial(template_path.prefix)][initial(template_path.suffix)]"
		var/text = map_texts[map_path]
		TEST_ASSERT_NOTNULL(text, "[chart_path] points at [map_path], which the map scan never found")
		var/chart_has_cache = FALSE
		var/chart_has_rare = FALSE
		for(var/crate_path in crate_types)
			if(!has_path(text, crate_path))
				continue
			chart_has_cache = TRUE
			if(crate_path in rare_crate_types)
				chart_has_rare = TRUE
		if(!chart_has_cache)
			TEST_FAIL("[map_path] (rumor chart [chart_path]) contains no zone loot caches — the chart sells an empty prize")
		if(!chart_has_rare)
			TEST_FAIL("[map_path] (rumor chart [chart_path]) contains no /rare cache — every chart ruin should carry its themed rare")
		if(!findtext(text, "/obj/effect/zone_mobs"))
			TEST_FAIL("[map_path] (rumor chart [chart_path]) has no zone_mobs guards")

#undef VOIDCREW_RUIN_MAP_ROOT
