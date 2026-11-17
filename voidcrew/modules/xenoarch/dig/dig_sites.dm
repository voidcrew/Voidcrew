/**
 * # Dig sites
 *
 * A planet-generator pass that runs after the anomalies, once per surface build. Each site is a
 * short run of mountain wall facing open ground: the walls get a vein overlay and one find each,
 * and two or three survey stakes and a spoil heap go on the ground in front, so a site reads from
 * across the map. Copies place_budgeted_anomalies(): random draws, then an exhaustive scan,
 * keeping off rivers, the landing strip and ruins, and spacing sites XENOARCH_SITE_SPACING apart.
 *
 * What a site holds comes from the planet's /datum/planet_dig_reserve, never from the build, so a
 * planet rebuilt after everyone left has only what was not yet dug. A planet whose overmap object
 * cannot be found gets no sites at all, since nothing could keep count of them.
 *
 * Hooked by chaining populate_terrain() from this file (included after PlanetGenerator.dm): the
 * original runs first, then the dig pass. The cave area's own population call is skipped; its
 * walls are reached from the surface ground that faces them.
 */

/// Random tries for a site's spot before the exhaustive scan.
#define DIG_SITE_RANDOM_ATTEMPTS 250
/// Tiles of plain planet a site keeps between itself and ruins or the landing strip.
#define DIG_SITE_CLEARANCE 4
/// How far from its anchor tile a site's walls may run.
#define DIG_SITE_REACH 3

/// Wall to build an outcrop from on a planet with no usable cliff, by planet type.
GLOBAL_LIST_INIT(xenoarch_outcrop_walls, list(
	/datum/planet/beach = /turf/closed/mineral/random/beach,
	/datum/planet/jungle = /turf/closed/mineral/random/jungle,
	/datum/planet/lava = /turf/closed/mineral/random/volcanic/voidcrew,
	/datum/planet/snow = /turf/closed/mineral/random/snow,
	/datum/planet/wasteland = /turf/closed/mineral/random/high_chance/wasteland,
))

/datum/map_generator/planet_generator/populate_terrain(list/turfs, area/generate_in, zone_band)
	. = ..()
	if(istype(generate_in, /area/overmap_encounter/planetoid/cave))
		return
	place_dig_sites(turfs, generate_in)

/**
 * Places every site that still holds something. Returns how many were placed.
 */
/datum/map_generator/planet_generator/proc/place_dig_sites(list/turfs, area/overmap_encounter/planetoid/surface)
	if(!length(turfs) || !istype(surface))
		return 0
	var/obj/structure/overmap/planet/planet = SSovermap_zones?.get_overmap_object_for_turf(turfs[1])
	if(!istype(planet))
		return 0
	var/datum/planet_dig_reserve/reserve = planet.get_dig_reserve()
	reserve.seed(surface.planet_type)
	var/list/to_place = reserve.sites_with_finds()
	if(!length(to_place))
		return 0

	var/datum/map_footprint/footprint = planet.footprint
	var/list/placed_at = list()
	var/placed = 0
	for(var/datum/dig_site_record/site as anything in to_place)
		var/list/spot = find_dig_site_spot(turfs, site, placed_at, footprint)
		if(!spot)
			spot = build_dig_outcrop(turfs, site, placed_at, surface.planet_type)
		if(!spot)
			continue
		var/turf/anchor = spot[1]
		build_dig_site(site, anchor, spot[2])
		site.x = anchor.x - (footprint ? footprint.low_x : 0)
		site.y = anchor.y - (footprint ? footprint.low_y : 0)
		placed_at += anchor
		placed++
	if(placed < length(to_place))
		log_world("[name] dig site shortfall: [placed]/[length(to_place)] sites placed.")
	return placed

/**
 * Finds an anchor (the open tile a site is worked from) and its walls: the site's last spot if it
 * still fits, then random draws, then every tile in turn. Returns list(anchor, walls) or null.
 */
/datum/map_generator/planet_generator/proc/find_dig_site_spot(list/turfs, datum/dig_site_record/site, list/placed_at, datum/map_footprint/footprint)
	var/needed = max(site.large_left + site.small_left, 1)
	if(!isnull(site.x) && !isnull(site.y) && length(turfs))
		var/turf/first = turfs[1]
		var/turf/last_spot = locate((footprint ? footprint.low_x : 0) + site.x, (footprint ? footprint.low_y : 0) + site.y, first.z)
		var/list/walls = dig_site_walls_at(last_spot, needed, placed_at)
		if(walls)
			return list(last_spot, walls)
	var/random_attempts = length(turfs) ? DIG_SITE_RANDOM_ATTEMPTS : 0
	for(var/attempt in 1 to random_attempts + length(turfs))
		SSovermap.worldgen_yield(throttled)
		var/turf/candidate = attempt <= random_attempts ? pick(turfs) : turfs[attempt - random_attempts]
		var/list/walls = dig_site_walls_at(candidate, needed, placed_at)
		if(walls)
			return list(candidate, walls)
	return null

/// The walls a site anchored on `anchor` would use, or null if the spot is no good.
/datum/map_generator/planet_generator/proc/dig_site_walls_at(turf/anchor, needed, list/placed_at)
	if(!dig_site_ground_ok(anchor))
		return null
	for(var/turf/taken as anything in placed_at)
		if(taken.z == anchor.z && get_dist(anchor, taken) < XENOARCH_SITE_SPACING)
			return null
	var/list/walls = collect_dig_site_walls(anchor, needed)
	if(!walls || !dig_site_clear_of_ruins(anchor))
		return null
	return walls

/// Open ground the generator laid down: not water, lava, a river, a ruin or the landing strip.
/proc/dig_site_ground_ok(turf/ground)
	if(!isopenturf(ground) || isgroundlessturf(ground) || ground.planet_river)
		return FALSE
	if(istype(ground, /turf/open/water) || istype(ground, /turf/open/lava))
		return FALSE
	if(ground.turf_flags & NO_RUINS)
		return FALSE
	var/datum/biome/biome = ground.generating_biome
	if(!biome || !(ground.type in biome.open_turf_types))
		return FALSE
	if(ground.is_blocked_turf(exclude_mobs = TRUE))
		return FALSE
	return TRUE

/// Plain mountain rock that faces open ground and isn't already part of a site or a special vein.
/proc/dig_site_wall_ok(turf/closed/mineral/wall)
	if(!istype(wall) || wall.dig_find)
		return FALSE
	if(istype(wall, /turf/closed/mineral/gibtonite) || istype(wall, /turf/closed/mineral/strong))
		return FALSE
	if(wall.spawned_boulder || (wall.mineralType && !is_ordinary_ore(wall.mineralType)))
		return FALSE
	if(wall.turf_flags & NO_RUINS)
		return FALSE
	if(!istype(wall.loc, /area/overmap_encounter/planetoid))
		return FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/side = get_step(wall, direction)
		if(isopenturf(side) && !isgroundlessturf(side) && !side.planet_river && !istype(side, /turf/open/lava))
			return TRUE
	return FALSE

/// A connected run of usable face walls within DIG_SITE_REACH of the anchor, or null if too short.
/proc/collect_dig_site_walls(turf/anchor, needed)
	var/list/queue = list()
	for(var/direction in GLOB.cardinals)
		var/turf/closed/mineral/wall = get_step(anchor, direction)
		if(dig_site_wall_ok(wall))
			queue += wall
	var/list/walls = list()
	var/list/seen = list()
	while(length(queue) && length(walls) < needed)
		var/turf/closed/mineral/wall = queue[1]
		queue.Cut(1, 2)
		if(seen[wall])
			continue
		seen[wall] = TRUE
		walls += wall
		for(var/direction in GLOB.alldirs)
			var/turf/closed/mineral/next = get_step(wall, direction)
			if(!next || seen[next] || get_dist(next, anchor) > DIG_SITE_REACH)
				continue
			if(dig_site_wall_ok(next))
				queue += next
	return length(walls) >= needed ? walls : null

/// Nothing within DIG_SITE_CLEARANCE belongs to a ruin, the landing strip or the world border.
/proc/dig_site_clear_of_ruins(turf/anchor)
	for(var/turf/near as anything in RANGE_TURFS(DIG_SITE_CLEARANCE, anchor))
		if(near.turf_flags & NO_RUINS)
			return FALSE
		if(!istype(near.loc, /area/overmap_encounter/planetoid))
			return FALSE
	return TRUE

/**
 * A planet with no cliff to dig into (a thin beach) gets a short outcrop of its own rock, raised
 * on open ground. Returns list(anchor, walls) or null.
 */
/datum/map_generator/planet_generator/proc/build_dig_outcrop(list/turfs, datum/dig_site_record/site, list/placed_at, planet_type)
	var/needed = max(site.large_left + site.small_left, 1)
	var/wall_type = GLOB.xenoarch_outcrop_walls[planet_type] || /turf/closed/mineral/random
	var/width = needed + 2
	for(var/attempt in 1 to DIG_SITE_RANDOM_ATTEMPTS)
		SSovermap.worldgen_yield(throttled)
		var/turf/anchor = pick(turfs)
		if(!dig_site_ground_ok(anchor))
			continue
		var/too_close = FALSE
		for(var/turf/taken as anything in placed_at)
			if(taken.z == anchor.z && get_dist(anchor, taken) < XENOARCH_SITE_SPACING)
				too_close = TRUE
				break
		if(too_close || !dig_site_clear_of_ruins(anchor))
			continue
		// A row of rock just north of the anchor, centred on it.
		var/list/row = list()
		var/start_x = anchor.x - round(width / 2)
		for(var/offset in 0 to width - 1)
			var/turf/tile = locate(start_x + offset, anchor.y + 1, anchor.z)
			if(!dig_site_ground_ok(tile))
				row = null
				break
			row += tile
		if(!row)
			continue
		for(var/turf/tile as anything in row)
			var/turf/raised = tile.ChangeTurf(wall_type, flags = CHANGETURF_IGNORE_AIR)
			raised.assemble_baseturfs(initial(raised.baseturfs) || raised.type)
		// Rarely a raised wall rolls a special vein and the run comes up short. One outcrop is
		// enough rock to leave on a planet: the site waits for the next build rather than another.
		var/list/walls = collect_dig_site_walls(anchor, needed)
		return walls ? list(anchor, walls) : null
	return null

/**
 * Flags the walls, puts back any boulders already cut loose, and dresses the ground in front:
 * stakes at the ends of the face and a spoil heap a step back.
 */
/datum/map_generator/planet_generator/proc/build_dig_site(datum/dig_site_record/site, turf/anchor, list/walls)
	var/list/kinds = list()
	for(var/i in 1 to site.large_left)
		kinds += XENOARCH_FIND_LARGE
	for(var/i in 1 to site.small_left)
		kinds += XENOARCH_FIND_SMALL
	shuffle_inplace(kinds)
	for(var/i in 1 to min(length(kinds), length(walls)))
		var/turf/closed/mineral/wall = walls[i]
		wall.make_dig_site_wall(site, kinds[i])
	return dress_dig_site(site, anchor, walls)

/// Places loose boulders, stakes and the spoil heap around a site. Returns the decorations placed.
/proc/dress_dig_site(datum/dig_site_record/site, turf/anchor, list/walls)
	// Ground right against the face, where the work happens, and a ring a step back for the dressing.
	var/list/front = list()
	var/list/back = list()
	for(var/turf/closed/mineral/wall as anything in walls)
		for(var/direction in GLOB.cardinals)
			var/turf/side = get_step(wall, direction)
			if(dig_site_dressing_ok(side))
				front |= side
	for(var/turf/near as anything in RANGE_TURFS(2, anchor))
		if(!(near in front) && dig_site_dressing_ok(near))
			back += near
	var/rock_color = "#8f8a83"
	var/turf/closed/mineral/first_wall = walls[1]
	if(istype(first_wall))
		rock_color = first_wall.dig_rock_color()

	. = list()
	for(var/datum/dig_boulder_record/boulder as anything in site.loose)
		var/turf/spot = length(front) ? pick_n_take(front) : (length(back) ? pick_n_take(back) : null)
		if(!spot)
			break
		if(!boulder.rock_color)
			boulder.rock_color = rock_color
		. += new /obj/structure/xenoarch_boulder(spot, boulder, site)

	// Stakes go on the two back tiles furthest apart, so the face is bracketed by them.
	if(length(back) >= 2)
		var/turf/stake_a
		var/turf/stake_b
		var/best = -1
		for(var/turf/one as anything in back)
			for(var/turf/two as anything in back)
				var/distance = get_dist(one, two)
				if(distance > best)
					best = distance
					stake_a = one
					stake_b = two
		back -= stake_a
		back -= stake_b
		var/tape = pick("orange", "red")
		. += new /obj/structure/xenoarch_stake(stake_a, tape)
		. += new /obj/structure/xenoarch_stake(stake_b, tape)
		if(length(back) && prob(50))
			. += new /obj/structure/xenoarch_stake(pick_n_take(back), tape)
	if(length(back))
		. += new /obj/structure/xenoarch_spoil_heap(pick_n_take(back))

/// A tile the dressing can stand on: open, walkable, unclaimed ground. Plants on it are cleared.
/proc/dig_site_dressing_ok(turf/tile)
	if(!isopenturf(tile) || isgroundlessturf(tile) || tile.planet_river)
		return FALSE
	if(istype(tile, /turf/open/water) || istype(tile, /turf/open/lava))
		return FALSE
	if(locate(/obj/structure/xenoarch_boulder) in tile)
		return FALSE
	if(locate(/obj/structure/xenoarch_stake) in tile)
		return FALSE
	if(locate(/obj/structure/xenoarch_spoil_heap) in tile)
		return FALSE
	for(var/obj/structure/flora/plant in tile)
		qdel(plant)
	return !tile.is_blocked_turf(exclude_mobs = TRUE)

/**
 * # Survey stake
 *
 * A wooden stake with flagging tape, left by whoever marked the site out. Pull it up by hand.
 */
/obj/structure/xenoarch_stake
	name = "survey stake"
	desc = "A wooden stake hammered into the ground, with a strip of flagging tape knotted near the top."
	icon = 'voidcrew/modules/xenoarch/icons/dig_site.dmi'
	icon_state = "stake_orange"
	anchored = TRUE
	density = FALSE
	layer = BELOW_MOB_LAYER
	max_integrity = 30
	resistance_flags = FLAMMABLE

/obj/structure/xenoarch_stake/Initialize(mapload, tape_color)
	. = ..()
	if(tape_color)
		icon_state = "stake_[tape_color]"
	pixel_x = base_pixel_x + rand(-5, 5)
	pixel_y = base_pixel_y + rand(-3, 4)

/obj/structure/xenoarch_stake/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	user.visible_message(
		span_notice("[user] works [src] loose from the ground."),
		span_notice("You start working [src] loose."),
	)
	if(!do_after(user, 2 SECONDS, target = src))
		return TRUE
	playsound(src, 'sound/effects/shovel_dig.ogg', 30, TRUE)
	user.visible_message(span_notice("[user] pulls up [src] and tosses it aside."), span_notice("You pull up [src]."))
	qdel(src)
	return TRUE

/**
 * # Spoil heap
 *
 * Earth and broken rock shovelled out of the dig. Scenery; a shovel clears it.
 */
/obj/structure/xenoarch_spoil_heap
	name = "spoil heap"
	desc = "A heap of earth and broken rock shovelled out of a dig."
	icon = 'voidcrew/modules/xenoarch/icons/dig_site.dmi'
	icon_state = "spoil1"
	anchored = TRUE
	density = FALSE
	layer = BELOW_OBJ_LAYER
	max_integrity = 60

/obj/structure/xenoarch_spoil_heap/Initialize(mapload)
	. = ..()
	icon_state = "spoil[rand(1, 2)]"
	pixel_x = base_pixel_x + rand(-4, 4)
	pixel_y = base_pixel_y + rand(-2, 3)

/obj/structure/xenoarch_spoil_heap/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour != TOOL_SHOVEL)
		return NONE
	if(!tool.use_tool(src, user, 3 SECONDS, volume = 50))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(span_notice("[user] spreads [src] flat."), span_notice("You spread [src] flat."))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

#undef DIG_SITE_RANDOM_ATTEMPTS
#undef DIG_SITE_CLEARANCE
#undef DIG_SITE_REACH
