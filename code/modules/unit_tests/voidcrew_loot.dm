/**
 * # Voidcrew loot audit tests
 *
 * Guards the invariants the 2026-07 loot audit found broken by hand:
 *
 * 1. Table hygiene: every loot theme (voidcrew/modules/loot/themes/) has all
 *    four tiers populated with sane weighted entries, no entry appears in
 *    two tiers of the same theme, every guard table holds real mobs, and,
 *    hard design rule, NO megafauna anywhere in the zone system (that
 *    includes this fork's /mob/living/basic/boss tier).
 * 2. Reachability: every authored cache/marker subtype is actually placed in
 *    a shipped ruin .dmm, sold as a shop SKU, or spawned at runtime, so
 *    "fully authored, sprited, and unobtainable" (the wardrobe-rare bug)
 *    can't happen silently again.
 * 3. Guarding: every ruin map that carries a cache carries a guard marker
 *    (or a hand-placed setpiece: an elite, or a whitelisted megafauna), and
 *    megafauna only ever appear in the enumerated legacy boss-arena ruins,
 *    never as generic cache guards in new maps.
 * 4. Rumor charts: every chart points at a registered template whose map
 *    actually contains caches and a /boss-tier guard. Charts are the paid
 *    channel, so their ruins are the one place a boss is mandatory rather
 *    than a mapper's call.
 */

/// Ruin maps root scanned by the reachability test
#define VOIDCREW_RUIN_MAP_ROOT "_maps/voidcrew/RandomRuins/"

/datum/unit_test/voidcrew_loot_themes

/datum/unit_test/voidcrew_loot_themes/Run()
	if(!length(GLOB.loot_themes))
		TEST_FAIL("GLOB.loot_themes is empty, theme registry never initialized")
		return
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		// tier -> the tier that already claimed it, so a cross-tier duplicate
		// names both sides. Tiers are working pools inside ONE cache now, not
		// per-band tables: an entry in two of them can be drawn twice by the
		// same crate, breaking the no-replacement guarantee.
		var/list/claimed_by = list()
		for(var/table_name in list("loot_common", "loot_uncommon", "loot_prime", "loot_uniques"))
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
				var/already = claimed_by["[entry]"]
				if(already)
					TEST_FAIL("[theme_path] lists [entry] in both [already] and [table_name]. One cache could roll it twice")
				else
					claimed_by["[entry]"] = table_name
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

	// guard tables: real mobs only, and NEVER megafauna, megafauna
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
					TEST_FAIL("[marker_path] table entry [entry] is MEGAFAUNA, banned from the zone mob system")
		qdel(marker)

/datum/unit_test/voidcrew_loot_reachability
	priority = TEST_LONGER
	/// Cache/marker types that are legitimately spawned only at runtime or
	/// over the counter, so map placement isn't required for them
	var/static/list/runtime_spawned = list(
		// meteor storm fields spawn these (overmap/events.dm)
		/obj/structure/closet/crate/zone_loot/expedition,
		/obj/effect/zone_mobs/asteroid,
		// the collapsing icemoon portal can spawn any crate + wave; listed
		// here are only the ones with no mapped placements otherwise
	)
	/// Purpose-built boss-arena ruins: the ruin exists to host its megafauna
	/// fight (blood-drunk shrines, the hierophant arena, the wendigo's cave,
	/// Outpost 31, the last ash drake...). Megafauna are allowed ONLY here.
	/// Anywhere else they're banned from ruin maps outright (owner rule:
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
/// (last path in the block). Matching against those avoids prefix hits
/// (e.g. /armory matching /armory/rare)
/datum/unit_test/voidcrew_loot_reachability/proc/has_path(text, path)
	return findtext(text, "[path],") || findtext(text, "[path]{") || findtext(text, "[path])")

/datum/unit_test/voidcrew_loot_reachability/Run()
	var/list/map_texts = list()
	collect_dmm_files(VOIDCREW_RUIN_MAP_ROOT, map_texts)
	TEST_ASSERT(length(map_texts) > 100, "Ruin map scan found only [length(map_texts)] .dmm files under [VOIDCREW_RUIN_MAP_ROOT], wrong root?")

	// which crate types are sold over a counter
	var/list/sku_sold = list()
	for(var/datum/shop_sku/sku_path as anything in subtypesof(/datum/shop_sku))
		var/item_path = initial(sku_path.item_path)
		if(ispath(item_path, /obj/structure/closet/crate/zone_loot))
			sku_sold[item_path] = TRUE

	var/list/crate_types = subtypesof(/obj/structure/closet/crate/zone_loot)
	var/list/marker_types = subtypesof(/obj/effect/zone_mobs)

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
			TEST_FAIL("[spawnable_path] is authored but appears in no ruin map, SKU or runtime spawner, dead content")

	// ---- per-map: guards, bosses, and the megafauna arena whitelist ----
	for(var/map_file in map_texts)
		var/text = map_texts[map_file]
		var/short_name = copytext(map_file, findlasttext(map_file, "/") + 1)
		var/has_megafauna = findtext(text, "/mob/living/simple_animal/hostile/megafauna") || findtext(text, "/mob/living/basic/boss")
		if(has_megafauna && !(short_name in megafauna_arena_maps))
			TEST_FAIL("[map_file] places MEGAFAUNA outside the legacy arena whitelist. New ruins use themed /boss zone_mobs markers (elite-tier at most)")
		var/has_cache = FALSE
		for(var/crate_path in crate_types)
			if(has_path(text, crate_path))
				has_cache = TRUE
				break
		if(!has_cache)
			continue
		// a hand-placed setpiece (elite, or an arena's megafauna) counts as
		// the guard/boss, e.g. Pandora's ruin, the blood-drunk shrines
		var/has_setpiece = has_megafauna || findtext(text, "/mob/living/simple_animal/hostile/asteroid/elite")
		if(!findtext(text, "/obj/effect/zone_mobs") && !has_setpiece)
			TEST_FAIL("[map_file] places a loot cache but no zone_mobs guard marker or hand-placed setpiece")

	// ---- rumor charts point at real, stocked, guarded ruins ----
	for(var/datum/shop_sku/ruin_chart/chart_path as anything in subtypesof(/datum/shop_sku/ruin_chart))
		var/datum/map_template/ruin/space/template_path = initial(chart_path.ruin_template_path)
		if(isnull(template_path))
			continue
		// reveal() finds the template by walking SSmapping.space_ruins_templates
		// (rumor_charts.dm): an unregistered one only stack_traces, after the
		// crew has already paid for the tip and pressed the helm's reveal button.
		var/registered = FALSE
		for(var/template_name in SSmapping.space_ruins_templates)
			var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
			if(candidate.type == template_path)
				registered = TRUE
				break
		if(!registered)
			TEST_FAIL("[chart_path] points at [template_path], which is not registered in SSmapping.space_ruins_templates, reveal() logs and spawns nothing")
		// Literals 1/2/3 = ZONE_GREEN/ZONE_YELLOW/ZONE_RED
		// (voidcrew/_DEFINES/overmap_zones.dm); unit tests compile before voidcrew/_DEFINES
		var/spawn_zone = initial(chart_path.spawn_zone)
		if(spawn_zone != 1 && spawn_zone != 2 && spawn_zone != 3)
			TEST_FAIL("[chart_path] has spawn_zone [spawn_zone]; get_unused_overmap_square_in_zone_band() only knows 1 (green), 2 (yellow) and 3 (red), so the ruin has nowhere to surface")
		var/map_path = "[initial(template_path.prefix)][initial(template_path.suffix)]"
		var/text = map_texts[map_path]
		TEST_ASSERT_NOTNULL(text, "[chart_path] points at [map_path], which the map scan never found")
		// Chart ruins are the paid channel: 3000-4800cr, one buyer per ruin
		// ever. There is no "rare cache" to guarantee any more, so what the
		// money buys is DENSITY in a guaranteed band, several caches, all
		// rolling the same tables everyone else rolls, behind a boss.
		var/chart_caches = 0
		for(var/crate_path in crate_types)
			if(has_path(text, crate_path))
				chart_caches++
		if(!chart_caches)
			TEST_FAIL("[map_path] (rumor chart [chart_path]) contains no zone loot caches. The chart sells an empty prize")
		if(!findtext(text, "/obj/effect/zone_mobs"))
			TEST_FAIL("[map_path] (rumor chart [chart_path]) has no zone_mobs guards")
		var/chart_has_boss = findtext(text, "/boss,") || findtext(text, "/boss{") || findtext(text, "/boss)")
		var/chart_setpiece = findtext(text, "/mob/living/simple_animal/hostile/megafauna") \
			|| findtext(text, "/mob/living/basic/boss") \
			|| findtext(text, "/mob/living/simple_animal/hostile/asteroid/elite")
		if(!chart_has_boss && !chart_setpiece)
			TEST_FAIL("[map_path] (rumor chart [chart_path]) has no /boss marker or hand-placed setpiece. A bought ruin must be defended")

#undef VOIDCREW_RUIN_MAP_ROOT

/**
 * # Outpost megafauna ban
 *
 * The other half of the megafauna containment rule above: outposts are
 * permanent, unbreachable and unfleeable, so a megafauna that walks into one
 * off a docked ship never leaves. voidcrew/area/megafauna_ban.dm removes them
 * at the area boundary, but only for areas that carry the flag, so a new
 * outpost area (or a flag lost in a merge) silently reopens the hole.
 */
/datum/unit_test/voidcrew_outpost_megafauna_ban

/datum/unit_test/voidcrew_outpost_megafauna_ban/Run()
	var/list/warded = list(
		/area/voidcrew/trader_outpost,
		/area/voidcrew/outpost_hangar,
		/area/voidcrew/player_outpost,
	)
	for(var/area/area_path as anything in warded)
		if(!initial(area_path.repels_megafauna))
			TEST_FAIL("[area_path] does not set repels_megafauna. A megafauna that reaches it can stay there for the rest of the round")
