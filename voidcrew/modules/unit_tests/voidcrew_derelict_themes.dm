/// Derelict outpost tests. Owner: P3. Voidcrew defines are not visible here: literals, with the define named beside them.

/**
 * The theme tests share one body: build a derelict with no theme, apply one, and check what the theme promises.
 * Paths stay open, the roster is exact and leashed, the dressing is within its caps, nothing banned appears,
 * blood is dry, and the crew sees the theme's signs by the arrival point before anything can reach them.
 */
/datum/unit_test/voidcrew_derelict_theme
	parent_type = /datum/unit_test/voidcrew_derelict
	abstract_type = /datum/unit_test/voidcrew_derelict_theme
	/// The shell the derelict is built from
	var/shell_type
	/// DERELICT_THEME_* id
	var/theme_id
	/// ZONE_YELLOW (2) or ZONE_RED (3)
	var/band = 2
	/// The theme's boss
	var/boss_type
	/// Hostile type = list(yellow count, red count), the boss not included
	var/list/roster
	/// The theme's broken_light_percent
	var/light_percent = 0
	/// Dressing the theme leaves by the arrival point
	var/list/entry_types

/datum/unit_test/voidcrew_derelict_theme/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = built_derelict(shell_type, null, band)
	TEST_ASSERT_NOTNULL(site, "The [theme_id] test derelict did not build")
	TEST_ASSERT(length(site.lobby_alcove_turfs), "The [theme_id] test derelict has no elevator alcove")
	site.theme_id = theme_id
	var/turf/start = site.lobby_alcove_turfs[1]
	var/list/before = derelict_reach(site, start)
	var/dressing_before = count_dressing(site)
	var/list/lights_before = count_lights(site)
	var/placed = site.apply_derelict_theme()
	var/list/after = derelict_reach(site, start)
	check_reach(site, before, after)
	check_roster(site)
	check_dressing(site, placed, dressing_before, lights_before)
	check_bans(site)
	check_entry(site)
	check_theme(site)

/// Dense dressing only ever removed its own tile from the walkable floor, and the console and generator stay reachable
/datum/unit_test/voidcrew_derelict_theme/proc/check_reach(obj/structure/overmap/dynamic/player_outpost/derelict/site, list/before, list/after)
	for(var/turf/tile as anything in after)
		TEST_ASSERT(before[tile], "[theme_id]: ([tile.x], [tile.y]) became reachable after dressing")
	for(var/turf/tile as anything in before)
		if(after[tile])
			continue
		TEST_ASSERT((locate(/obj/structure/alien/resin) in tile) || (locate(/obj/structure/altar) in tile), "[theme_id]: ([tile.x], [tile.y]) was cut off without being filled")
	var/list/obj/machinery/landmarks = derelict_atoms(site, /obj/machinery/computer/player_outpost_management) + derelict_atoms(site, /obj/machinery/power/port_gen/pacman)
	for(var/obj/machinery/landmark as anything in landmarks)
		var/turf/spot = get_turf(landmark)
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(spot, direction)
			if(beside && before[beside])
				TEST_ASSERT(after[beside], "[theme_id]: the [landmark] lost its approach from ([beside.x], [beside.y])")

/// Exactly the rostered hostiles for the band, the boss first; each leashed, clear of the arrival and the generator, and scaled
/datum/unit_test/voidcrew_derelict_theme/proc/check_roster(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	var/list/mob/living/hostiles = list()
	for(var/datum/weakref/ref as anything in site.derelict_hostiles)
		var/mob/living/hostile = ref.resolve()
		TEST_ASSERT_NOTNULL(hostile, "[theme_id]: a spawned hostile was gone before the checks")
		hostiles += hostile
	TEST_ASSERT(length(hostiles), "[theme_id]: no hostiles spawned")
	// DERELICT_MAX_HOSTILES
	TEST_ASSERT(length(hostiles) <= 14, "[theme_id]: [length(hostiles)] hostiles spawned, over the cap of 14")
	var/red = band == 3 // ZONE_RED
	var/list/expected = list()
	expected[boss_type] = 1
	for(var/hostile_type in roster)
		var/list/counts = roster[hostile_type]
		expected[hostile_type] = (expected[hostile_type] || 0) + counts[red ? 2 : 1]
	var/list/found = list()
	for(var/mob/living/hostile as anything in hostiles)
		// A mi-go can come out as its rare variant; it counts as a mi-go
		var/found_type = istype(hostile, /mob/living/basic/migo) ? /mob/living/basic/migo : hostile.type
		found[found_type] = (found[found_type] || 0) + 1
	for(var/hostile_type in expected)
		TEST_ASSERT_EQUAL(found[hostile_type] || 0, expected[hostile_type], "[theme_id]: count of [hostile_type] in band [band]")
	for(var/hostile_type in found)
		TEST_ASSERT(expected[hostile_type], "[theme_id]: [hostile_type] is not on the roster")
	var/mob/living/first = hostiles[1]
	TEST_ASSERT(istype(first, boss_type), "[theme_id]: the first hostile is [first.type], not the boss [boss_type]")
	var/datum/outpost_upgrade/wing = site.outpost_upgrades["prison"]
	if(wing?.installed_area)
		TEST_ASSERT_EQUAL(get_area(first), wing.installed_area, "[theme_id]: the boss is not in the prison wing")
	var/obj/machinery/power/port_gen/pacman/generator = site.derelict_generator()
	for(var/i in 1 to length(hostiles))
		var/mob/living/hostile = hostiles[i]
		TEST_ASSERT_NOTNULL(hostile.GetComponent(/datum/component/derelict_leash), "[theme_id]: [hostile] is not leashed")
		// DERELICT_SAFE_RADIUS (8) is near_derelict_arrival()'s default
		TEST_ASSERT(!site.near_derelict_arrival(get_turf(hostile)), "[theme_id]: [hostile] starts within 8 of the elevator or arrival point")
		if(generator)
			// DERELICT_GENERATOR_CLEAR_RADIUS
			TEST_ASSERT(get_dist(hostile, generator) > 4, "[theme_id]: [hostile] starts within 4 of the generator")
		// DERELICT_BOSS_HEALTH_MULT_* 1.5 / 2, DERELICT_HEALTH_MULT_* 1.5 / 1.8
		var/multiplier = i == 1 ? (red ? 2 : 1.5) : (red ? 1.8 : 1.5)
		TEST_ASSERT_EQUAL(hostile.maxHealth, round(initial(hostile.maxHealth) * multiplier), "[theme_id]: [hostile]'s health was not scaled by [multiplier]")

/// Dressing stays under DERELICT_MAX_DRESSING (160); lights break at the theme's rate, give or take one fixture
/datum/unit_test/voidcrew_derelict_theme/proc/check_dressing(obj/structure/overmap/dynamic/player_outpost/derelict/site, placed, dressing_before, list/lights_before)
	TEST_ASSERT(placed > 0, "[theme_id]: no dressing was placed")
	TEST_ASSERT(placed <= 160, "[theme_id]: [placed] dressing atoms placed, over the cap of 160")
	var/added = count_dressing(site) - dressing_before
	TEST_ASSERT(added <= 160, "[theme_id]: [added] dressing atoms on the floor, over the cap of 160")
	var/list/lights_after = count_lights(site)
	var/total = lights_after[1]
	var/broken = lights_after[2] - lights_before[2]
	TEST_ASSERT(broken <= round(total * light_percent / 100) + 1, "[theme_id]: [broken] of [total] lights broken, more than [light_percent]%")

/// No weed node, unhatched egg, facehugger, cult rune, cult structure or sacrificial altar; every stain is dry
/datum/unit_test/voidcrew_derelict_theme/proc/check_bans(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	TEST_ASSERT(!length(derelict_atoms(site, /obj/structure/alien/weeds/node)), "[theme_id]: a weed node was placed")
	for(var/obj/structure/alien/egg/egg as anything in derelict_atoms(site, /obj/structure/alien/egg))
		TEST_ASSERT(istype(egg, /obj/structure/alien/egg/burst), "[theme_id]: an unhatched [egg.type] was placed")
	TEST_ASSERT(!length(derelict_atoms(site, /obj/item/clothing/mask/facehugger)), "[theme_id]: a facehugger was placed")
	TEST_ASSERT(!length(derelict_atoms(site, /obj/effect/rune)), "[theme_id]: a cult rune was placed")
	TEST_ASSERT(!length(derelict_atoms(site, /obj/structure/destructible/cult)), "[theme_id]: a cult structure was placed")
	TEST_ASSERT(!length(derelict_atoms(site, /obj/structure/sacrificealtar)), "[theme_id]: a sacrificial altar was placed")
	for(var/obj/effect/decal/cleanable/blood/stain as anything in derelict_atoms(site, /obj/effect/decal/cleanable/blood))
		TEST_ASSERT(stain.dried, "[theme_id]: [stain] at ([stain.x], [stain.y]) is still wet")

/// At least two of the theme's signs within 5 of the arrival point
/datum/unit_test/voidcrew_derelict_theme/proc/check_entry(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	if(!site.arrival_turf)
		return
	var/signs = 0
	for(var/turf/tile as anything in site.derelict_floor_turfs())
		if(get_dist(tile, site.arrival_turf) > 5)
			continue
		for(var/atom/movable/thing as anything in tile)
			if(is_type_in_list(thing, entry_types))
				signs++
	TEST_ASSERT(signs >= 2, "[theme_id]: only [signs] signs of the theme by the arrival point")

/// The theme's own promises
/datum/unit_test/voidcrew_derelict_theme/proc/check_theme(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	return

/// Theme dressing on the derelict's floor, by count
/datum/unit_test/voidcrew_derelict_theme/proc/count_dressing(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	var/static/list/dressing_types = typecacheof(list(
		/obj/effect/decal/cleanable/blood,
		/obj/effect/decal/cleanable/cobweb,
		/obj/effect/decal/cleanable/crayon,
		/obj/effect/decal/cleanable/dirt/dust,
		/obj/effect/decal/remains,
		/obj/item/flashlight/flare/candle,
		/obj/structure/alien/egg,
		/obj/structure/alien/resin,
		/obj/structure/alien/weeds,
		/obj/structure/altar,
	))
	. = 0
	for(var/turf/tile as anything in site.derelict_floor_turfs())
		for(var/atom/movable/thing as anything in tile)
			if(dressing_types[thing.type])
				.++

/// list(fixtures, broken fixtures) in the derelict's areas
/datum/unit_test/voidcrew_derelict_theme/proc/count_lights(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	var/total = 0
	var/broken = 0
	var/z = site.upgrade_level_z()
	for(var/area/place as anything in site.derelict_areas())
		for(var/turf/tile as anything in place.get_turfs_by_zlevel(z))
			for(var/obj/machinery/light/fixture in tile)
				total++
				if(fixture.status == LIGHT_BROKEN)
					broken++
	return list(total, broken)

/// T3.1: a yellow xeno nest in the rundown shell
/datum/unit_test/voidcrew_derelict_theme_xeno
	parent_type = /datum/unit_test/voidcrew_derelict_theme
	shell_type = /datum/map_template/player_outpost/rundown
	theme_id = "xeno" // DERELICT_THEME_XENO
	band = 2
	boss_type = /mob/living/basic/alien/queen/large/derelict
	roster = list(
		/mob/living/basic/alien = list(3, 5),
		/mob/living/basic/alien/sentinel = list(2, 3),
		/mob/living/basic/alien/drone = list(2, 2),
	)
	light_percent = 30
	entry_types = list(/obj/effect/decal/cleanable/blood/xeno, /obj/structure/alien/weeds)

/datum/unit_test/voidcrew_derelict_theme_xeno/check_theme(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	TEST_ASSERT(length(derelict_atoms(site, /obj/structure/alien/weeds)), "xeno: no weeds were placed")
	TEST_ASSERT(length(derelict_atoms(site, /obj/structure/alien/egg/burst)), "xeno: no hatched eggs were placed")
	for(var/mob/living/basic/alien/xeno as anything in derelict_atoms(site, /mob/living/basic/alien))
		TEST_ASSERT(!xeno.can_plant_weeds, "xeno: [xeno] can still plant weeds")
		TEST_ASSERT(!xeno.can_lay_eggs, "xeno: [xeno] can still lay eggs")

/// T3.2: a red cult in the clean shell
/datum/unit_test/voidcrew_derelict_theme_cult
	parent_type = /datum/unit_test/voidcrew_derelict_theme
	shell_type = /datum/map_template/player_outpost/clean
	theme_id = "cult" // DERELICT_THEME_CULT
	band = 3
	boss_type = /mob/living/basic/construct/juggernaut/hostile
	roster = list(
		/mob/living/basic/construct/wraith/hostile = list(2, 4),
		/mob/living/basic/construct/proteon/hostile = list(4, 5),
	)
	light_percent = 20
	entry_types = list(/obj/effect/decal/cleanable/crayon, /obj/effect/decal/cleanable/blood/old, /obj/item/flashlight/flare/candle)

/datum/unit_test/voidcrew_derelict_theme_cult/check_theme(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	var/list/candles = derelict_atoms(site, /obj/item/flashlight/flare/candle)
	TEST_ASSERT(length(candles), "cult: no candles were placed")
	for(var/obj/item/flashlight/flare/candle/candle as anything in candles)
		TEST_ASSERT(istype(candle, /obj/item/flashlight/flare/candle/infinite), "cult: [candle.type] is not an eternal candle")
		TEST_ASSERT(candle.light_on, "cult: a candle at ([candle.x], [candle.y]) is not lit")
	var/runes = 0
	for(var/obj/effect/decal/cleanable/crayon/rune as anything in derelict_atoms(site, /obj/effect/decal/cleanable/crayon))
		if(rune.name != "rune")
			continue
		runes++
		TEST_ASSERT_EQUAL(rune.desc, "Drawn in dried blood.", "cult: a rune's description")
	TEST_ASSERT(runes, "cult: no runes were drawn")
	TEST_ASSERT(length(derelict_atoms(site, /obj/structure/altar)) <= 2, "cult: more than two altars")

/// T3.3: a red haunted station in the rundown shell
/datum/unit_test/voidcrew_derelict_theme_haunted
	parent_type = /datum/unit_test/voidcrew_derelict_theme
	shell_type = /datum/map_template/player_outpost/rundown
	theme_id = "haunted" // DERELICT_THEME_HAUNTED
	band = 3
	boss_type = /mob/living/basic/skeleton/templar
	roster = list(
		/mob/living/basic/skeleton = list(3, 5),
		/mob/living/basic/zombie/rotten = list(2, 3),
		/mob/living/basic/ghost = list(3, 4),
	)
	light_percent = 40
	entry_types = list(/obj/effect/decal/remains/human, /obj/effect/decal/cleanable/blood/old)

/datum/unit_test/voidcrew_derelict_theme_haunted/check_theme(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	TEST_ASSERT(length(derelict_atoms(site, /obj/effect/decal/cleanable/cobweb)), "haunted: no cobwebs were placed")
	TEST_ASSERT(length(derelict_atoms(site, /obj/effect/decal/remains/human)), "haunted: no remains were placed")

/// T3.4: yellow monsters in the clean shell
/datum/unit_test/voidcrew_derelict_theme_monsters
	parent_type = /datum/unit_test/voidcrew_derelict_theme
	shell_type = /datum/map_template/player_outpost/clean
	theme_id = "monsters" // DERELICT_THEME_MONSTERS
	band = 2
	boss_type = /mob/living/basic/migo
	roster = list(
		/mob/living/basic/migo = list(0, 1),
		/mob/living/basic/creature = list(2, 3),
		/mob/living/basic/blankbody = list(2, 3),
		/mob/living/basic/mimic/crate = list(2, 2),
	)
	light_percent = 30
	entry_types = list(/obj/effect/decal/cleanable/blood/splatter, /obj/effect/decal/cleanable/blood/gibs, /obj/effect/decal/cleanable/blood/old)

/datum/unit_test/voidcrew_derelict_theme_monsters/check_theme(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	var/list/mimics = derelict_atoms(site, /mob/living/basic/mimic/crate)
	TEST_ASSERT(length(mimics), "monsters: no crate mimics spawned")
	for(var/mob/living/basic/mimic/crate/mimic as anything in mimics)
		TEST_ASSERT_EQUAL(mimic.ai_controller?.ai_status, AI_STATUS_OFF, "monsters: a crate mimic's AI is awake")
