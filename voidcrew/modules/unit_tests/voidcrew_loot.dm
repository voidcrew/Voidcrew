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
				TEST_ASSERT(findtext("[entry]/", "/obj/item/blueprint/gun/") != 1, "[theme_path].[table_name] still drops a gun schematic: [entry]")
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
			else
				var/datum/shop_sku/sku_path = sku
				TEST_ASSERT(findtext("[initial(sku_path.item_path)]/", "/obj/item/blueprint/gun/") != 1, "[theme_path] still references a gun schematic SKU: [sku]")

	for(var/list/table as anything in list(GLOB.abandoned_crate_common, GLOB.abandoned_crate_uncommon, GLOB.abandoned_crate_prime))
		for(var/entry in table)
			TEST_ASSERT(findtext("[entry]/", "/obj/item/blueprint/gun/") != 1, "Freight still drops a gun schematic: [entry]")
	var/datum/loot_theme/syndicate/syndicate = GLOB.loot_themes[/datum/loot_theme/syndicate]
	var/datum/loot_theme/plunder/plunder = GLOB.loot_themes[/datum/loot_theme/plunder]
	var/datum/loot_theme/research/research = GLOB.loot_themes[/datum/loot_theme/research]
	var/list/weapons = syndicate.get_weapon_pool(TRUE, "2") // LOOT_WEAPON_YELLOW
	TEST_ASSERT(weapons[/obj/item/gun/ballistic/automatic/c20r/unrestricted], "Schematic removal also removed the finished C-20r")
	weapons = syndicate.get_weapon_pool(TRUE, "3") // LOOT_WEAPON_RED
	TEST_ASSERT(weapons[/obj/item/gun/ballistic/automatic/l6_saw/unrestricted], "Schematic removal also removed the finished L6")
	TEST_ASSERT(weapons[/obj/item/gun/ballistic/rifle/sniper_rifle], "Schematic removal also removed the finished sniper rifle")
	weapons = plunder.get_weapon_pool(TRUE, "3")
	TEST_ASSERT(weapons[/obj/item/gun/ballistic/shotgun/bulldog/unrestricted], "Schematic removal also removed the finished Bulldog")
	weapons = research.get_weapon_pool(TRUE, "3")
	TEST_ASSERT(weapons[/obj/item/gun/energy/laser/carbine], "Schematic removal also removed the finished laser carbine")

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
		for(var/list/count_range in list(marker.count_green, marker.count_yellow, marker.count_red))
			TEST_ASSERT_EQUAL(length(count_range), 2, "[marker_path] has no minimum/maximum guard count")
			TEST_ASSERT_EQUAL(count_range[1], 1, "[marker_path] minimum guard count must be one in every band")
			TEST_ASSERT_EQUAL(count_range[2], 2, "[marker_path] maximum guard count must be two in every band")
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

/// Enumerate the Bernoulli and conditional class rolls; no statistical tolerance.
/datum/unit_test/voidcrew_cache_weapon_odds/Run()
	// Zone and weapon-class literals compile before Voidcrew's defines.
	var/list/chances = list(
		/datum/loot_theme/armory = list(12, 32, 55),
		/datum/loot_theme/syndicate = list(6, 18, 36),
		/datum/loot_theme/plunder = list(6, 18, 36),
		/datum/loot_theme/expedition = list(4, 12, 24),
		/datum/loot_theme/industrial = list(2, 6, 12),
		/datum/loot_theme/medical = list(1, 4, 8),
		/datum/loot_theme/research = list(2, 8, 18),
		/datum/loot_theme/occult = list(2, 6, 12),
		/datum/loot_theme/wardrobe = list(2, 6, 12),
	)
	var/list/freight_chances = list(8, 19, 33)
	for(var/theme_path in chances)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		var/list/expected = chances[theme_path]
		for(var/zone in list(1, 2, 3))
			TEST_ASSERT_EQUAL(get_cache_gun_chance(zone, theme), expected[zone], "[theme_path] gun chance changed in zone [zone]")
			TEST_ASSERT_EQUAL(get_cache_gun_chance(zone, theme, TRUE), freight_chances[zone], "Purchased cache did not use freight odds")
			for(var/freight in list(FALSE, TRUE))
				var/guns = 0
				for(var/roll in 1 to 100)
					var/weapon = select_cache_weapon(zone, theme, freight, roll, 1)
					TEST_ASSERT_NOTNULL(weapon, "Weapon roll paid nothing")
					if(ispath(weapon, /obj/item/gun))
						guns++
				TEST_ASSERT_EQUAL(guns, freight ? freight_chances[zone] : expected[zone], "[theme_path] has the wrong per-cache gun probability")
		TEST_ASSERT_EQUAL(get_cache_gun_chance(null, theme), expected[1], "Unresolved cache did not fall back to green")

	var/list/gun_classes = list(list(940, 59, 1), list(450, 540, 10), list(150, 350, 500))
	var/list/melee_classes = list(list(900, 99, 1), list(350, 640, 10), list(100, 450, 450))
	for(var/gun in list(FALSE, TRUE))
		for(var/zone in list(1, 2, 3))
			var/list/counts = list("1" = 0, "2" = 0, "3" = 0)
			for(var/roll in 1 to 1000)
				counts[get_cache_weapon_class(zone, gun, roll)]++
			var/list/expected = gun ? gun_classes[zone] : melee_classes[zone]
			for(var/class in list("1", "2", "3"))
				TEST_ASSERT_EQUAL(counts[class], expected[text2num(class)], "Conditional weapon class [class] changed in zone [zone], gun=[gun]")
	TEST_ASSERT_EQUAL(get_cache_weapon_class(null, TRUE, 941), "2", "Unresolved class roll did not use green odds")

/// A working copy may be consumed without damaging another crate's singleton tables.
/datum/unit_test/voidcrew_cache_weapon_pools/Run()
	var/list/main_counts = list("armory" = list(1, 3, 5), "syndicate" = list(1, 2, 3), "plunder" = list(2, 2, 2), "freight" = list(4, 3))
	for(var/family in main_counts)
		var/list/counts = main_counts[family]
		var/list/classes = GLOB.loot_gun_pools[family]
		TEST_ASSERT_EQUAL(length(classes), length(counts), "Main gun family gained an unexpected class")
		for(var/class in classes)
			var/list/pool = classes[class]
			TEST_ASSERT_EQUAL(length(pool), counts[text2num(class)], "Main gun class changed size")
			for(var/entry in pool)
				TEST_ASSERT_EQUAL(pool[entry], 10, "Main gun class is not uniform")
	var/list/melee_counts = list(4, 6, 6)
	for(var/class in GLOB.loot_melee_pools)
		var/list/pool = GLOB.loot_melee_pools[class]
		TEST_ASSERT_EQUAL(length(pool), melee_counts[text2num(class)], "Main melee class changed size")
		for(var/entry in pool)
			TEST_ASSERT_EQUAL(pool[entry], 10, "Main melee class is not uniform")
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		for(var/gun in list(FALSE, TRUE))
			for(var/class in list("1", "2", "3"))
				var/list/pool = theme.get_weapon_pool(gun, class)
				TEST_ASSERT(length(pool), "[theme_path] lost weapon class [class], gun=[gun]")
				var/list/snapshot = pool.Copy()
				for(var/entry in pool)
					TEST_ASSERT(ispath(entry, /obj/item), "Weapon pool contains a non-item: [entry]")
					TEST_ASSERT(pool[entry] == 10 || pool[entry] == 1, "Weapon [entry] has an unexpected weight")
				pool.Cut()
				pool = theme.get_weapon_pool(gun, class)
				TEST_ASSERT_EQUAL(length(pool), length(snapshot), "Consuming a working pool changed the singleton")
				for(var/entry in snapshot)
					TEST_ASSERT_EQUAL(pool[entry], snapshot[entry], "Consuming a working pool changed [entry]'s weight")
				var/list/freight_pool = theme.get_weapon_pool(gun, class, TRUE)
				var/list/freight_main = get_cache_weapon_pool(gun, class, "freight")
				TEST_ASSERT_EQUAL(length(freight_pool), length(freight_main), "Freight inherited weapon extras")
				for(var/entry in freight_pool)
					TEST_ASSERT_EQUAL(freight_pool[entry], freight_main[entry], "Freight inherited a themed weapon")
					TEST_ASSERT(!ispath(entry, /obj/item/organ) && !ispath(entry, /obj/item/cyberware_pair_case), "Freight paid weapon chrome")
	var/list/yellow = get_cache_weapon_pool(TRUE, "2", "freight")
	var/list/red = get_cache_weapon_pool(TRUE, "3", "freight")
	TEST_ASSERT_EQUAL(length(yellow), 3, "Freight ordinary gun pool changed")
	TEST_ASSERT_EQUAL(length(red), length(yellow), "Freight did not substitute ordinary guns for advanced guns")
	for(var/entry in yellow)
		TEST_ASSERT_EQUAL(red[entry], yellow[entry], "Freight advanced-class substitution changed [entry]")

/datum/unit_test/voidcrew_cache_weapon_population
	var/datum/loot_theme/saved_theme

/datum/unit_test/voidcrew_cache_weapon_population/Destroy()
	if(saved_theme)
		GLOB.loot_themes[/datum/loot_theme/armory] = saved_theme
	return ..()

/datum/unit_test/voidcrew_cache_weapon_population/Run()
	saved_theme = GLOB.loot_themes[/datum/loot_theme/armory]
	var/datum/loot_theme/armory/test_theme = allocate(/datum/loot_theme/armory)
	// Freight's main guns all have one boxed reload. The test controls the
	// Bernoulli outcome while retaining the real cache population path.
	test_theme.gun_pool = "freight"
	test_theme.gun_extras = null
	test_theme.melee_extras = null
	GLOB.loot_themes[/datum/loot_theme/armory] = test_theme
	var/list/minimums = list(2, 3, 4)
	var/list/maximums = list(3, 4, 5)
	for(var/gun in list(FALSE, TRUE))
		test_theme.gun_chance = gun ? list(100, 100, 100) : list(0, 0, 0)
		for(var/zone in list(1, 2, 3))
			for(var/bonus in list(0, 2))
				var/obj/structure/closet/crate/zone_loot/cache = allocate(/obj/structure/closet/crate/zone_loot/armory)
				cache.theme = /datum/loot_theme/armory
				cache.bonus_draws = bonus
				cache.loot_zone = zone
				cache.PopulateContents()
				var/weapons = 0
				for(var/obj/item/item in cache)
					if(istype(item, /obj/item/gun) && !istype(item, /obj/item/gun/energy/disabler))
						weapons++
					else if(item.type in GLOB.loot_melee_pools["1"] || item.type in GLOB.loot_melee_pools["2"] || item.type in GLOB.loot_melee_pools["3"])
						weapons++
				TEST_ASSERT_EQUAL(weapons, 1, "Cache did not pay exactly one weapon, bonus=[bonus]")
				var/prizes = length(cache.contents) - (gun ? 1 : 0)
				TEST_ASSERT(prizes >= minimums[zone] + bonus && prizes <= maximums[zone] + bonus, "Weapon roll changed the cache's draw count")
				var/list/contents = cache.contents.Copy()
				cache.PopulateContents()
				TEST_ASSERT_EQUAL(length(cache.contents), length(contents), "Repeated population paid again")
				for(var/atom/movable/item as anything in contents)
					qdel(item)
				cache.dump_contents()
				cache.PopulateContents()
				TEST_ASSERT_EQUAL(length(cache.contents), 0, "Emptying a cache allowed replenishment")

	var/turf/origin = SSovermap.get_unused_overmap_square_in_zone_band(1)
	var/turf/destination = SSovermap.get_unused_overmap_square_in_zone_band(3)
	TEST_ASSERT(origin && destination, "Missing overmap test squares")
	var/obj/structure/closet/crate/zone_loot/armory/moved = allocate(/obj/structure/closet/crate/zone_loot/armory, origin)
	moved.forceMove(destination)
	moved.PopulateContents()
	TEST_ASSERT_EQUAL(moved.loot_zone, 1, "Moving a cache upgraded its spawn band")

/// All three bought caches must be stamped before their first opening.
/datum/unit_test/voidcrew_purchased_cache_weapons/Run()
	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	for(var/sku_path in list(/datum/shop_sku/general/rotating/freight_crate, /datum/shop_sku/black_market/mystery_cache, /datum/shop_sku/black_market/mystery_cache_rare))
		var/datum/shop_sku/sku = allocate(sku_path)
		var/obj/structure/closet/crate/zone_loot/cache = sku.dispense(buyer, null)
		allocated += cache
		TEST_ASSERT(cache.freight_weapons, "[sku_path] dispensed guarded weapon odds over the counter")
		TEST_ASSERT(!cache.loot_consumed && !cache.contents_initialized, "Bought cache populated before freight rules were applied")
		TEST_ASSERT_EQUAL(cache.theme, /datum/loot_theme/syndicate, "Bought cache lost its themed nonweapon supplies")
		TEST_ASSERT_EQUAL(cache.bonus_draws, sku_path == /datum/shop_sku/black_market/mystery_cache_rare ? 2 : 0, "Bought cache lost its bonus draws")

/// Every ballistic outcome has a usable reload, including retained specialist guns.
/datum/unit_test/voidcrew_cache_weapon_ammunition/Run()
	var/list/weapons = list()
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		for(var/class in list("1", "2", "3"))
			weapons |= theme.get_weapon_pool(TRUE, class)
	for(var/weapon_path in weapons)
		if(!ispath(weapon_path, /obj/item/gun/ballistic))
			continue
		var/obj/structure/closet/crate/box = allocate(/obj/structure/closet/crate)
		var/obj/item/gun/ballistic/gun = spawn_loot_prize(box, weapon_path)
		TEST_ASSERT(!istype(gun.pin, /obj/item/firing_pin/implant), "Loot gun [weapon_path] requires an implant")
		var/obj/item/ammo_box/magazine/magazine_path = gun.accepted_magazine_type
		var/has_reload = FALSE
		var/list/spares = box.get_all_contents() - gun.get_all_contents()
		for(var/obj/item/ammo_casing/casing in spares)
			if(casing.caliber == initial(magazine_path.caliber))
				has_reload = TRUE
		// Boxes may store rounds as paths until first accessed.
		for(var/obj/item/ammo_box/ammo in spares)
			var/obj/item/ammo_casing/casing_path = ammo.ammo_type
			if(initial(casing_path.caliber) == initial(magazine_path.caliber) && length(ammo.stored_ammo))
				has_reload = TRUE
		TEST_ASSERT(has_reload, "Loot gun [weapon_path] has no compatible spare reload")

/// Contraband and low-zone guards cannot bypass the ladder.
/datum/unit_test/voidcrew_loot_weapon_bypasses/Run()
	var/list/before = run_loc_floor_top_right.contents.Copy()
	var/obj/effect/spawner/random/contraband/armory/spawner = new(run_loc_floor_top_right)
	var/list/green_melee = GLOB.loot_melee_pools["1"]
	TEST_ASSERT_EQUAL(length(spawner.loot), 4, "Contraband armory is no longer uniform green melee")
	for(var/entry in spawner.loot)
		TEST_ASSERT(entry in green_melee, "Contraband bypass pays [entry]")
		TEST_ASSERT_EQUAL(spawner.loot[entry], 1, "Contraband green melee is not uniform")
	var/spawned = 0
	for(var/obj/item/item in run_loc_floor_top_right.contents - before)
		allocated += item
		spawned++
		TEST_ASSERT(item.type in green_melee, "Contraband spawned a weapon outside green melee")
	TEST_ASSERT_EQUAL(spawned, 1, "Contraband did not pay exactly one green melee weapon")
	for(var/marker_path in list(/obj/effect/zone_mobs/syndicate, /obj/effect/zone_mobs/syndicate/boss))
		var/obj/effect/zone_mobs/marker = new marker_path()
		TEST_ASSERT_EQUAL(length(marker.mobs_green), 1, "Green syndicate pool still includes sword guards")
		TEST_ASSERT(marker.mobs_green[/mob/living/basic/trooper/syndicate/melee], "Green syndicate guards lost their knives")
		for(var/entry in marker.mobs_yellow)
			TEST_ASSERT(!ispath(entry, /mob/living/basic/trooper/syndicate/ranged/smg) && !ispath(entry, /mob/living/basic/trooper/syndicate/ranged/shotgun), "Yellow syndicate guard has an advanced ranged weapon")
		TEST_ASSERT(marker.mobs_red[/mob/living/basic/trooper/syndicate/ranged/smg] || marker.mobs_red[/mob/living/basic/trooper/syndicate/ranged/smg/space/stormtrooper], "Red syndicate pool lost its SMG guards")
		qdel(marker)

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

/// Control when the real resolver starts, including after moving the machine.
/obj/machinery/suit_storage_unit/ruin_zone/stock_test/LateInitialize()
	return

/datum/unit_test/voidcrew_ruin_suit_stock/Run()
	var/list/expected = list(
		/obj/item/mod/control/pre_equipped/standard,
		/obj/item/mod/control/pre_equipped/civilian,
		/obj/item/mod/control/pre_equipped/engineering,
		/obj/item/mod/control/pre_equipped/atmospheric,
		/obj/item/mod/control/pre_equipped/mining,
		/obj/item/mod/control/pre_equipped/medical,
	)
	TEST_ASSERT_EQUAL(length(GLOB.base_tier_modsuits), 6, "Base-tier allowlist changed")
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	for(var/suit_path in expected)
		TEST_ASSERT(suit_path in GLOB.base_tier_modsuits, "Base-tier allowlist lost [suit_path]")
		TEST_ASSERT_NULL(GLOB.base_tier_modsuits[suit_path], "Base-tier selection must be uniform")
		var/obj/item/mod/control/suit = allocate(suit_path)
		TEST_ASSERT(suit.allowed(user), "Base reward [suit_path] is access-locked")
	var/obj/machinery/suit_storage_unit/base_tier/base = allocate(/obj/machinery/suit_storage_unit/base_tier)
	TEST_ASSERT(base.mod?.type in expected, "Base unit did not select its suit before parent initialization")
	TEST_ASSERT_EQUAL(base.mod.loc, base, "Base unit did not stock its selected suit")

	var/before_loose = 0
	for(var/obj/item/mod/control/suit in run_loc_floor_top_right)
		before_loose++
	new /obj/effect/spawner/random/modsuit/base_tier(run_loc_floor_top_right)
	var/after_loose = 0
	for(var/obj/item/mod/control/suit in run_loc_floor_top_right)
		after_loose++
		TEST_ASSERT(suit.type in expected, "Loose spawner selected a suit outside the allowlist")
	TEST_ASSERT_EQUAL(after_loose, before_loose + 1, "Loose spawner did not pay exactly one suit")
	TEST_ASSERT_EQUAL(length(GLOB.base_tier_modsuits), 6, "Loose spawner mutated the shared allowlist")
	for(var/suit_path in expected)
		TEST_ASSERT_NULL(GLOB.base_tier_modsuits[suit_path], "Loose spawner changed shared weights")

	// Literals 1/2/3 are ZONE_GREEN/YELLOW/RED, defined after unit-test includes.
	for(var/zone in list(1, 2, 3))
		var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(zone)
		TEST_ASSERT_NOTNULL(spawn_turf, "No test square in zone [zone]")
		var/obj/machinery/suit_storage_unit/ruin_zone/stock_test/unit = allocate(/obj/machinery/suit_storage_unit/ruin_zone/stock_test, spawn_turf)
		TEST_ASSERT_NULL(unit.mod, "Ruin unit stocked before resolution")
		unit.state_open = TRUE
		TEST_ASSERT(!unit.check_interactable(user), "Unresolved unit permits retrieval")
		TEST_ASSERT_EQUAL(unit.stock_spawn_turf, spawn_turf, "Unit did not pin its spawn turf")
		unit.forceMove(run_loc_floor_bottom_left)
		new /datum/zone_resolver(unit.stock_spawn_turf, CALLBACK(unit, TYPE_PROC_REF(/obj/machinery/suit_storage_unit/ruin_zone, stock_for_zone)))
		TEST_ASSERT(unit.stock_consumed, "Resolver did not complete stock resolution")
		if(zone == 1)
			TEST_ASSERT(unit.mod?.type in expected, "Moved green unit did not retain base-tier stock")
		else
			var/expected_type = zone == 2 ? /obj/item/mod/control/pre_equipped/security : /obj/item/mod/control/pre_equipped/nuclear/unrestricted
			TEST_ASSERT_EQUAL(unit.mod?.type, expected_type, "Moved unit changed suit tier")
		TEST_ASSERT(unit.check_interactable(user) && unit.access_check(user), "Resolved unit blocks retrieval")
		TEST_ASSERT(unit.mod.allowed(user), "Zone [zone] suit is access-locked")
		var/obj/item/mod/control/reward = unit.mod
		unit.stock_for_zone(3)
		TEST_ASSERT_EQUAL(unit.mod, reward, "Repeated callback created another suit")
		unit.dump_inventory_contents()
		unit.stock_for_zone(3)
		TEST_ASSERT_NULL(unit.mod, "Retrieving the suit allowed replenishment")

	var/obj/machinery/suit_storage_unit/ruin_zone/stock_test/fallback = allocate(/obj/machinery/suit_storage_unit/ruin_zone/stock_test)
	fallback.stock_for_zone(null)
	TEST_ASSERT(fallback.mod?.type in expected, "Unresolved zone did not fall back to base-tier stock")

/// A real yielding creation window exercises the registry's claim.
/datum/ruin_chart_site/concurrency_test
	var/creations = 0

/datum/ruin_chart_site/concurrency_test/create_site(spawn_zone)
	creations++
	sleep(2)
	return ..()

/datum/unit_test/voidcrew_named_chart_registry
	var/list/saved_registry
	var/obj/structure/overmap/space_ruin/created_site

/datum/unit_test/voidcrew_named_chart_registry/Destroy()
	if(!QDELETED(created_site))
		qdel(created_site)
	if(saved_registry)
		for(var/template_path in GLOB.ruin_chart_sites.Copy())
			qdel(GLOB.ruin_chart_sites[template_path])
		GLOB.ruin_chart_sites = saved_registry
	return ..()

/datum/unit_test/voidcrew_named_chart_registry/Run()
	saved_registry = GLOB.ruin_chart_sites
	GLOB.ruin_chart_sites = list()
	var/template_path = /datum/map_template/ruin/space/rare/hospice
	var/datum/ruin_chart_site/concurrency_test/entry = new(template_path)
	GLOB.ruin_chart_sites[template_path] = entry
	var/obj/structure/overmap/ship/first_ship = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/second_ship = allocate(/obj/structure/overmap/ship)
	var/datum/rumor_chart/first = allocate(/datum/rumor_chart)
	var/datum/rumor_chart/second = allocate(/datum/rumor_chart)
	first.ruin_template_path = template_path
	second.ruin_template_path = template_path
	first.spawn_zone = 1 // ZONE_GREEN
	second.spawn_zone = 1
	first_ship.add_pending_rumor(first)
	second_ship.add_pending_rumor(second)
	INVOKE_ASYNC(first_ship, TYPE_PROC_REF(/obj/structure/overmap/ship, reveal_pending_rumor), first)
	TEST_ASSERT(entry.claimed, "Creation yielded without claiming its template")
	TEST_ASSERT_NULL(second_ship.reveal_pending_rumor(second), "Competing reveal created a second site")
	TEST_ASSERT(!second.revealed && (second in second_ship.pending_rumors), "Competing reveal consumed its chart")
	sleep(3)
	created_site = entry.site_ref?.resolve()
	TEST_ASSERT_NOTNULL(created_site, "Claimed reveal did not finish")
	created_site.visited = TRUE
	TEST_ASSERT_EQUAL(second_ship.reveal_pending_rumor(second), created_site, "Retry failed to chart the registered site")
	TEST_ASSERT_EQUAL(entry.creations, 1, "Concurrent charts created more than one site")
	qdel(first_ship)
	TEST_ASSERT_EQUAL(get_ruin_chart_site(template_path), entry, "Ship deletion lost the round-wide registry")

	var/mob/living/carbon/human/buyer = allocate(/mob/living/carbon/human/consistent)
	buyer.mind_initialize()
	allocated += buyer.mind
	var/datum/team/voidcrew/team = allocate(/datum/team/voidcrew)
	team.ship = second_ship
	second_ship.ship_team = team
	team.join_member(buyer.mind)
	var/datum/bank_account/account = allocate(/datum/bank_account, "Chart refund test", null, 1, FALSE)
	account.account_balance = 20000
	second_ship.ship_account = account
	var/obj/item/card/id/advanced/id = allocate(/obj/item/card/id/advanced)
	qdel(id.registered_account)
	id.registered_account = account
	TEST_ASSERT(buyer.put_in_hands(id), "Buyer cannot hold their ID")
	var/obj/item/stack/trade_voucher/vouchers = allocate(/obj/item/stack/trade_voucher, buyer, 10)
	var/datum/outpost_shop/shop = allocate(/datum/outpost_shop)
	shop.add_sku(/datum/shop_sku/ruin_chart/biolab, "rotating")
	var/datum/shop_sku/ruin_chart/sku = shop.skus[1]
	sku.ruin_template_path = template_path
	sku.stock = 2
	var/price = sku.get_credit_price(buyer)
	var/voucher_price = sku.price_vouchers
	TEST_ASSERT(sku.try_purchase(buyer, null), "Live registered site refused a purchase")
	var/datum/rumor_chart/revealed_copy = second_ship.pending_rumors[1]
	TEST_ASSERT_EQUAL(second_ship.reveal_pending_rumor(revealed_copy), created_site, "Paid chart did not reuse the visited site")
	TEST_ASSERT(sku.try_purchase(buyer, null), "Pending refund purchase failed")
	var/datum/rumor_chart/pending = second_ship.pending_rumors[1]
	TEST_ASSERT_EQUAL(account.account_balance, 20000 - 2 * price, "Purchase charged the wrong credits")
	TEST_ASSERT_EQUAL(vouchers.amount, 10 - 2 * voucher_price, "Purchase charged the wrong vouchers")
	// Refund the actual bill, even after shelf prices change.
	sku.price_credits *= 2
	sku.price_vouchers *= 2
	qdel(created_site)
	TEST_ASSERT(entry.retired && isnull(entry.site_ref), "Deleted site did not leave a tombstone")
	TEST_ASSERT(QDELETED(pending) && !length(second_ship.pending_rumors), "Retired site retained a paid pending chart")
	TEST_ASSERT_EQUAL(account.account_balance, 20000 - price, "Retirement did not refund exactly the pending credit bill")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 10 - voucher_price, "Retirement did not refund exactly the pending voucher bill")
	sku.stock = 1
	TEST_ASSERT(sku.get_denial_reason(buyer), "Retired site has no purchase denial")
	TEST_ASSERT(!sku.try_purchase(buyer, null), "Retired site allowed another purchase")
	TEST_ASSERT_EQUAL(sku.stock, 1, "Refused purchase consumed stock")
	TEST_ASSERT_EQUAL(account.account_balance, 20000 - price, "Refused purchase charged credits")
	TEST_ASSERT_EQUAL(count_trade_vouchers(buyer), 10 - voucher_price, "Refused purchase charged vouchers")
	TEST_ASSERT_NULL(entry.get_or_create(1), "Retired template created another vault")
	TEST_ASSERT_EQUAL(entry.creations, 1, "Tombstone allowed another creation")
	buyer.mind.ship_teams = null
	team.ship = null

/// Every retained path stays in its catalog class, including themed chrome and uniques.
/datum/unit_test/voidcrew_cache_weapon_classes/Run()
	var/list/expected = list(
		"1" = list(
			/obj/item/bambostaff,
			/obj/item/gun/ballistic/automatic/pistol,
			/obj/item/gun/ballistic/automatic/pistol/m1911,
			/obj/item/gun/ballistic/automatic/pistol/m1911/no_mag,
			/obj/item/gun/ballistic/automatic/pistol/no_mag,
			/obj/item/gun/ballistic/automatic/pistol/toy,
			/obj/item/gun/ballistic/automatic/toy,
			/obj/item/gun/ballistic/bow,
			/obj/item/gun/ballistic/revolver/c38,
			/obj/item/gun/ballistic/revolver/c38/detective,
			/obj/item/gun/ballistic/revolver/nagant,
			/obj/item/gun/ballistic/revolver/russian,
			/obj/item/gun/ballistic/revolver/russian/soul,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun/pistol,
			/obj/item/gun/ballistic/rifle/boltaction/surplus,
			/obj/item/gun/ballistic/shotgun/doublebarrel,
			/obj/item/gun/ballistic/shotgun/doublebarrel/breacherslug,
			/obj/item/gun/ballistic/shotgun/doublebarrel/slugs,
			/obj/item/gun/ballistic/shotgun/musket,
			/obj/item/gun/ballistic/shotgun/toy,
			/obj/item/gun/ballistic/shotgun/toy/crossbow,
			/obj/item/hatchet,
			/obj/item/knife/combat/bone,
			/obj/item/knife/combat/survival,
			/obj/item/knife/envy,
			/obj/item/lead_pipe,
			/obj/item/melee/baseball_bat,
			/obj/item/spear,
			/obj/item/spear/bamboospear,
			/obj/item/spear/bonespear,
			/obj/item/spear/military,
			/obj/item/storage/case/cyberware/scrapper,
			/obj/item/tailclub,
		),
		"2" = list(
			/obj/item/chainsaw,
			/obj/item/claymore/cutlass/old,
			/obj/item/claymore/shortsword,
			/obj/item/claymore/weak,
			/obj/item/crowbar/large/twenty_force,
			/obj/item/fireaxe,
			/obj/item/fireaxe/boardingaxe,
			/obj/item/fireaxe/boneaxe,
			/obj/item/gun/ballistic/automatic/ar,
			/obj/item/gun/ballistic/automatic/c20r/unrestricted,
			/obj/item/gun/ballistic/automatic/mini_uzi,
			/obj/item/gun/ballistic/automatic/pistol/aps,
			/obj/item/gun/ballistic/automatic/pistol/deagle,
			/obj/item/gun/ballistic/automatic/pistol/deagle/camo,
			/obj/item/gun/ballistic/automatic/pistol/deagle/gold,
			/obj/item/gun/ballistic/automatic/proto/unrestricted,
			/obj/item/gun/ballistic/automatic/smartgun,
			/obj/item/gun/ballistic/automatic/tommygun,
			/obj/item/gun/ballistic/automatic/wt550,
			/obj/item/gun/ballistic/revolver,
			/obj/item/gun/ballistic/revolver/c38/housecall,
			/obj/item/gun/ballistic/revolver/golden,
			/obj/item/gun/ballistic/revolver/mateba,
			/obj/item/gun/ballistic/rifle/boltaction,
			/obj/item/gun/ballistic/rifle/boltaction/donkrifle,
			/obj/item/gun/ballistic/rifle/boltaction/pipegun/prime,
			/obj/item/gun/ballistic/rifle/boltaction/prime,
			/obj/item/gun/ballistic/rifle/rebarxbow/forced,
			/obj/item/gun/ballistic/shotgun,
			/obj/item/gun/ballistic/shotgun/lethal,
			/obj/item/gun/ballistic/shotgun/musket/no_quarter,
			/obj/item/gun/ballistic/shotgun/riot,
			/obj/item/gun/energy/e_gun,
			/obj/item/gun/energy/e_gun/dragnet,
			/obj/item/gun/energy/e_gun/mini,
			/obj/item/gun/energy/e_gun/old,
			/obj/item/gun/energy/ionrifle,
			/obj/item/gun/energy/ionrifle/carbine,
			/obj/item/gun/energy/laser,
			/obj/item/gun/energy/laser/luxurypaywall,
			/obj/item/gun/energy/laser/retro,
			/obj/item/gun/energy/laser/retro/old,
			/obj/item/gun/magic/hook/marlinspike,
			/obj/item/gun/syringe/rapidsyringe,
			/obj/item/gun/syringe/syndicate,
			/obj/item/kinetic_crusher,
			/obj/item/knife/combat,
			/obj/item/melee/baseball_bat/ablative,
			/obj/item/melee/cleric_mace,
			/obj/item/melee/parsnip_sabre,
			/obj/item/melee/sabre,
			/obj/item/nullrod/claymore,
			/obj/item/nullrod/claymore/chainsaw_sword,
			/obj/item/nullrod/claymore/darkblade,
			/obj/item/nullrod/claymore/glowing,
			/obj/item/nullrod/claymore/katana,
			/obj/item/nullrod/claymore/multiverse,
			/obj/item/nullrod/claymore/saber,
			/obj/item/nullrod/claymore/saber/pirate,
			/obj/item/nullrod/claymore/saber/red,
			/obj/item/nullrod/hypertool,
			/obj/item/nullrod/vibro,
			/obj/item/nullrod/vibro/spellblade,
			/obj/item/nullrod/vibro/talking,
			/obj/item/pen/edagger,
			/obj/item/shield/buckler,
			/obj/item/shield/buckler/parmula,
			/obj/item/shield/kite,
			/obj/item/shield/riot,
			/obj/item/shield/riot/phalanx_buckler,
			/obj/item/shield/riot/tele,
			/obj/item/shield/roman,
			/obj/item/shovel/serrated,
			/obj/item/spear/grey_tide,
			/obj/item/switchblade,
		),
		"3" = list(
			/obj/item/claymore,
			/obj/item/claymore/cutlass,
			/obj/item/claymore/cutlass/parley,
			/obj/item/clothing/gloves/knock_knock,
			/obj/item/cursed_katana,
			/obj/item/cyberware_pair_case/gorilla_arms,
			/obj/item/cyberware_pair_case/mantis_blades,
			/obj/item/energy_katana,
			/obj/item/gun/ballistic/automatic/l6_saw/unrestricted,
			/obj/item/gun/ballistic/automatic/m90/unrestricted,
			/obj/item/gun/ballistic/rifle/sniper_rifle,
			/obj/item/gun/ballistic/shotgun/automatic/combat,
			/obj/item/gun/ballistic/shotgun/bulldog/unrestricted,
			/obj/item/gun/energy/e_gun/hos,
			/obj/item/gun/energy/e_gun/nuclear,
			/obj/item/gun/energy/event_horizon,
			/obj/item/gun/energy/laser/carbine,
			/obj/item/gun/energy/laser/carbine/cybersun/unrestricted,
			/obj/item/gun/energy/laser/hellgun,
			/obj/item/gun/energy/laser/scatter,
			/obj/item/gun/energy/lasercannon/unrestricted,
			/obj/item/gun/energy/recharge/ebow,
			/obj/item/gun/energy/temperature/unrestricted,
			/obj/item/gun/energy/xray,
			/obj/item/heave_ho,
			/obj/item/house_edge,
			/obj/item/katana,
			/obj/item/knife/bloodletter,
			/obj/item/knife/understudy,
			/obj/item/melee/energy/sword/pirate,
			/obj/item/melee/energy/sword/saber,
			/obj/item/melee/energy/sword/saber/blue,
			/obj/item/melee/energy/sword/saber/purple,
			/obj/item/melee/energy/sword/saber/red,
			/obj/item/melee/greykingsword,
			/obj/item/mjollnir,
			/obj/item/organ/cyberimp/arm/toolkit/cyberware/bunker_buster,
			/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire,
			/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin,
			/obj/item/shield/energy,
			/obj/item/singularityhammer,
			/obj/item/storage/toolbox/mechanical/old/clean,
			/obj/item/veilrender,
			/obj/item/veilrender/honkrender,
			/obj/item/veilrender/vealrender,
		),
	)
	var/list/all_weapons = list()
	for(var/class in expected)
		all_weapons += expected[class]
	var/list/seen = list()
	var/list/utility_guns = list(
		/obj/item/gun/energy/disabler,
		/obj/item/gun/energy/recharge/kinetic_accelerator,
		/obj/item/gun/energy/plasmacutter,
		/obj/item/gun/energy/plasmacutter/adv,
	)
	for(var/theme_path in GLOB.loot_themes)
		var/datum/loot_theme/theme = GLOB.loot_themes[theme_path]
		for(var/gun in list(FALSE, TRUE))
			for(var/class in expected)
				var/list/pool = theme.get_weapon_pool(gun, class)
				for(var/entry in pool)
					TEST_ASSERT(entry in expected[class], "[theme_path] weapon [entry] is outside catalog class [class]")
					seen |= entry
		for(var/list/pool as anything in list(theme.loot_common, theme.loot_uncommon, theme.loot_prime, theme.loot_uniques))
			for(var/entry in pool)
				TEST_ASSERT(!(entry in all_weapons), "[theme_path] can pay an extra weapon from its nonweapon draws: [entry]")
				if(ispath(entry, /obj/item/gun))
					TEST_ASSERT(entry in utility_guns, "[theme_path] bypasses its weapon roll with [entry]")
				TEST_ASSERT(entry != /obj/item/his_grace, "His Grace remains in ordinary cache loot")
	for(var/entry in all_weapons)
		TEST_ASSERT(entry in seen, "Retained weapon [entry] lost its guarded cache source")
