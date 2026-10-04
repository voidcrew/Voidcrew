/**
 * # Derelict outpost: themes
 *
 * Owner: P3. One theme per round dresses the derelict and spawns its fixed, leashed hostiles.
 *
 * Everything placed is ordinary and removable once the outpost is claimed: plain weeds with no node (they never
 * spread), hatched eggs, crayon runes, plain altars, eternal candles, dried blood, dust, cobwebs and remains.
 * No rune, cult structure, growing egg or facehugger is ever placed. Dense dressing only goes where it cannot cut a path
 * (see /datum/derelict_scene/proc/can_fill()).
 *
 * The hostiles are basic mobs. Their AI is off while no client is on the level, crate mimics start paused,
 * and none starts near the elevator, the arrival point or the generator.
 */

/// Dresses the derelict for its theme and spawns its hostiles. Returns the number of dressing atoms placed.
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/apply_derelict_theme()
	var/datum/derelict_theme/theme = derelict_theme_by_id(theme_id)
	if(!theme)
		log_mapping("Derelict outpost [true_name]: unknown theme \"[theme_id]\"; it was left undressed.")
		return 0
	var/datum/derelict_scene/scene = new(src)
	if(!length(scene.open_tiles))
		log_mapping("Derelict outpost [true_name]: no open floor to dress.")
		return 0
	scene.pick_anchors()
	scene.break_lights(theme.broken_light_percent)
	theme.dress(scene)
	scene.spawn_hostiles(theme)
	return scene.placed

/// The theme with this DERELICT_THEME_* id, or null. The instances are built once and shared.
/proc/derelict_theme_by_id(id)
	var/static/list/themes
	if(!themes)
		themes = list()
		for(var/theme_type in subtypesof(/datum/derelict_theme))
			var/datum/derelict_theme/theme = new theme_type
			themes[theme.id] = theme
	if(!istext(id))
		return null
	return themes[id]

/**
 * # Derelict theme
 *
 * What took the derelict over: the boss and roster it spawns, how it dresses the floor and how many lights it breaks.
 * Shared, stateless instances; each build's working state lives in its /datum/derelict_scene.
 */
/datum/derelict_theme
	/// DERELICT_THEME_*
	var/id
	/// Admin-facing name
	var/name
	/// Starts at the boss anchor, deepest in the place
	var/boss_type
	/// Hostile type = list(yellow count, red count), in spawn order. The boss is not in here.
	var/list/roster
	/// Roster types that start anywhere rather than round the anchors
	var/list/roamers = list()
	/// Roster types that start against a wall when there is room
	var/list/lurkers = list()
	/// Percent of the light fixtures in the derelict's areas that are broken
	var/broken_light_percent = 0

/// Places this theme's dressing through `scene`, which keeps it within the dressing budget
/datum/derelict_theme/proc/dress(datum/derelict_scene/scene)
	return

/// Readies one of this theme's hostiles before it is scaled and leashed
/datum/derelict_theme/proc/prepare_hostile(mob/living/hostile)
	return

/// The nest's empress: the big queen sprite, at the small queen's strength
/mob/living/basic/alien/queen/large/derelict
	maxHealth = 250
	health = 250

/mob/living/basic/alien/queen/large/derelict/Initialize(mapload)
	. = ..()
	// The sprite is two tiles wide; centre it on her tile
	SET_BASE_PIXEL(-16, 0)

/// Xenomorphs: weeds thick round the queen and two lesser nests, resin on the walls, a hatched clutch and the dead
/datum/derelict_theme/xeno
	id = DERELICT_THEME_XENO
	name = "Xeno nest"
	boss_type = /mob/living/basic/alien/queen/large/derelict
	roster = list(
		/mob/living/basic/alien = list(3, 5),
		/mob/living/basic/alien/sentinel = list(2, 3),
		/mob/living/basic/alien/drone = list(2, 2),
	)
	broken_light_percent = 30

/datum/derelict_theme/xeno/dress(datum/derelict_scene/scene)
	var/turf/heart = scene.boss_anchor
	// Acid on the floor where the crew comes in
	scene.scatter(/obj/effect/decal/cleanable/blood/xeno, 3, scene.telegraph_tiles())
	// The hive round the queen: resin, the hatched clutch and what it fed on
	scene.put_dense(/obj/structure/alien/resin/wall, 4, heart, 7)
	scene.put_dense(/obj/structure/alien/resin/membrane, 2, heart, 7)
	scene.scatter(/obj/structure/alien/egg/burst, 6, scene.near(heart, 3, 1))
	scene.scatter(/obj/effect/decal/remains/human, 3, scene.near(heart, 4, 1))
	scene.scatter(/obj/effect/decal/cleanable/blood/gibs, 1, scene.near(heart, 4, 2))
	scene.scatter(/obj/effect/decal/cleanable/blood/xeno, 1, scene.near(heart, 5, 2))
	// Two lesser nests out in the habitat
	for(var/turf/den as anything in scene.anchors)
		scene.put_dense(/obj/structure/alien/resin/wall, 1, den, 6)
		scene.put_dense(/obj/structure/alien/resin/membrane, 1, den, 6)
		scene.scatter(/obj/structure/alien/egg/burst, 1, scene.near(den, 2, 1))
		scene.scatter(/obj/effect/decal/cleanable/blood/gibs, 1, scene.near(den, 3))
		scene.scatter(/obj/effect/decal/cleanable/blood/xeno, 3, scene.near(den, 4))
	// Weeds last, with what the budget has left
	spread_weeds(scene, 120)

/// Weeds: nearly solid close to the queen and the nests, thinning as they creep out along the floor and under doors,
/// a stray patch here and there
/datum/derelict_theme/xeno/proc/spread_weeds(datum/derelict_scene/scene, limit)
	var/list/steps_to_nest = list()
	for(var/turf/post as anything in scene.posts())
		// the queen's weeds reach a step further
		var/head_start = post == scene.boss_anchor ? 1 : 0
		var/list/steps_to = scene.walk_from(post, 7 + head_start, through_doors = TRUE)
		for(var/turf/tile as anything in steps_to)
			var/steps = steps_to[tile] - head_start
			if(isnull(steps_to_nest[tile]) || steps < steps_to_nest[tile])
				steps_to_nest[tile] = steps
	var/list/turf/thick = list()
	var/list/turf/middling = list()
	var/list/turf/thin = list()
	var/list/turf/stray = list()
	for(var/turf/tile as anything in scene.cover_tiles)
		if(scene.filled[tile])
			continue
		var/distance = isnull(steps_to_nest[tile]) ? INFINITY : steps_to_nest[tile]
		if(distance <= 2)
			if(prob(95))
				thick += tile
		else if(distance <= 5)
			if(prob(75))
				middling += tile
		else if(distance <= 7)
			if(prob(35))
				thin += tile
		else if(prob(8))
			stray += tile
	var/placed = 0
	for(var/list/turf/band as anything in list(thick, middling, thin, stray))
		if(placed >= limit)
			return
		shuffle_inplace(band)
		placed += length(scene.scatter(/obj/structure/alien/weeds, limit - placed, band, cover = TRUE))

/datum/derelict_theme/xeno/prepare_hostile(mob/living/hostile)
	if(!istype(hostile, /mob/living/basic/alien))
		return
	// Nodes spread and eggs hatch facehuggers; neither may appear
	var/mob/living/basic/alien/xeno = hostile
	xeno.can_plant_weeds = FALSE
	xeno.can_lay_eggs = FALSE

/// Constructs: two draped altars near the juggernaut, a ring of candles round the rune it stands on, lesser circles,
/// and lone runes through the rest of the place
/datum/derelict_theme/cult
	id = DERELICT_THEME_CULT
	name = "Cult"
	boss_type = /mob/living/basic/construct/juggernaut/hostile
	roster = list(
		/mob/living/basic/construct/wraith/hostile = list(2, 4),
		/mob/living/basic/construct/proteon/hostile = list(4, 5),
	)
	broken_light_percent = 20

/datum/derelict_theme/cult/dress(datum/derelict_scene/scene)
	var/turf/heart = scene.boss_anchor
	// Runes and candles where the crew comes in, and something dragged away deeper
	var/list/turf/entry = scene.telegraph_tiles()
	scene.scatter_runes(2, entry)
	scene.scatter_candles(2, entry)
	scene.scatter(/obj/effect/decal/cleanable/blood/old, 2, entry)
	if(length(entry))
		scene.drag_trail(/obj/effect/decal/cleanable/blood/old, 5, entry[1], scene.nearest_post(entry[1]))
	// The altars, draped red, with candles, blood and the dead beside them
	for(var/obj/structure/altar/altar as anything in scene.put_dense(/obj/structure/altar, 2, heart, 6))
		altar.icon_state = "convertaltar-red"
		var/list/turf/beside = scene.near(get_turf(altar), 1)
		scene.scatter_candles(2, beside)
		scene.scatter(/obj/effect/decal/cleanable/blood/splatter, 3, beside)
		scene.scatter(/obj/effect/decal/remains/human, 1, beside)
	// The circle the juggernaut stands in: a rune, a candle at each corner, old blood round it
	if(heart)
		scene.put_rune(heart)
		var/list/turf/corners = list()
		for(var/direction in GLOB.diagonals)
			corners += get_step(heart, direction)
		scene.scatter_candles(4, corners)
	scene.scatter_runes(2, scene.near(heart, 3, 2))
	scene.scatter(/obj/effect/decal/remains/human, 1, scene.near(heart, 2, 1))
	scene.scatter(/obj/effect/decal/cleanable/blood/old, 6, scene.near(heart, 3, 1))
	// Two lesser circles out in the habitat
	for(var/turf/den as anything in scene.anchors)
		scene.put_rune(den)
		scene.scatter_runes(1, scene.near(den, 2, 1))
		scene.scatter_candles(2, scene.near(den, 1, 1))
		scene.scatter(/obj/effect/decal/cleanable/blood/old, 2, scene.near(den, 3, 1))
	// Lone runes through the rest of the place, each with a candle beside it
	for(var/turf/spot as anything in scene.far_flung(3, 8))
		scene.put_rune(spot)
		scene.scatter_candles(1, scene.near(spot, 1, 1))

/// The dead: bones and old blood, cobwebs in the corners, dust along every wall, and ghosts drifting through it
/datum/derelict_theme/haunted
	id = DERELICT_THEME_HAUNTED
	name = "Haunted"
	boss_type = /mob/living/basic/skeleton/templar
	roster = list(
		/mob/living/basic/skeleton = list(3, 5),
		/mob/living/basic/zombie/rotten = list(2, 3),
		/mob/living/basic/ghost = list(3, 4),
	)
	roamers = list(/mob/living/basic/ghost)
	broken_light_percent = 40

/datum/derelict_theme/haunted/dress(datum/derelict_scene/scene)
	var/turf/heart = scene.boss_anchor
	// Bones by the door
	var/list/turf/entry = scene.telegraph_tiles()
	scene.scatter(/obj/effect/decal/remains/human, 1, entry)
	scene.scatter(/obj/effect/decal/cleanable/blood/old, 2, entry)
	// The dead where the templar keeps watch, in the other rooms, and one nobody found
	lay_bones(scene, scene.near(heart, 3, 1), 2)
	for(var/turf/den as anything in scene.anchors)
		lay_bones(scene, scene.near(den, 3), 1)
	var/list/turf/anywhere = scene.open_tiles.Copy()
	shuffle_inplace(anywhere)
	lay_bones(scene, anywhere, 1)
	// Cobwebs in the corners of the rooms
	var/list/turf/nooks = list()
	for(var/turf/tile as anything in scene.open_tiles)
		if(cobweb_for(tile))
			nooks += tile
	shuffle_inplace(nooks)
	var/webs = 0
	for(var/turf/tile as anything in nooks)
		if(webs >= 16)
			break
		var/list/hung = scene.scatter(cobweb_for(tile), 1, list(tile))
		if(!length(hung))
			continue
		webs++
		// The sprites are drawn for a wall above; a corner with the wall below takes them upside down
		if(!isclosedturf(get_step(tile, NORTH)))
			var/obj/effect/decal/cleanable/cobweb/web = hung[1]
			web.transform = matrix(1, 0, 0, 0, -1, 0)
	// Dust last, thickest along the walls, with what the budget has left
	var/list/turf/dusty = list()
	for(var/turf/tile as anything in scene.cover_tiles)
		var/by_wall = FALSE
		for(var/direction in GLOB.cardinals)
			if(isclosedturf(get_step(tile, direction)))
				by_wall = TRUE
				break
		if(prob(by_wall ? 45 : 15))
			dusty += tile
	shuffle_inplace(dusty)
	scene.scatter(/obj/effect/decal/cleanable/dirt/dust, 90, dusty, cover = TRUE)

/// Lays `count` remains from `tiles`, each with old blood beside it
/datum/derelict_theme/haunted/proc/lay_bones(datum/derelict_scene/scene, list/turf/tiles, count)
	for(var/obj/effect/decal/remains/bones as anything in scene.scatter(/obj/effect/decal/remains/human, count, tiles))
		scene.scatter(/obj/effect/decal/cleanable/blood/old, 1, scene.near(get_turf(bones), 1))

/// The cobweb that fits `tile`'s corner, or null: a wall above or below, and a wall on one side only
/datum/derelict_theme/haunted/proc/cobweb_for(turf/tile)
	if(isclosedturf(get_step(tile, NORTH)) == isclosedturf(get_step(tile, SOUTH)))
		return null
	var/west = isclosedturf(get_step(tile, WEST))
	var/east = isclosedturf(get_step(tile, EAST))
	if(west && !east)
		return /obj/effect/decal/cleanable/cobweb
	if(east && !west)
		return /obj/effect/decal/cleanable/cobweb/cobweb2
	return null

/// Netherworld things: feeding sites heaped with gore, a drag trail from the door, lone kills all through the place,
/// and crates that are not crates
/datum/derelict_theme/monsters
	id = DERELICT_THEME_MONSTERS
	name = "Monsters"
	boss_type = /mob/living/basic/migo
	roster = list(
		/mob/living/basic/migo = list(0, 1),
		/mob/living/basic/creature = list(2, 3),
		/mob/living/basic/blankbody = list(2, 3),
		/mob/living/basic/mimic/crate = list(2, 2),
	)
	roamers = list(/mob/living/basic/migo)
	lurkers = list(/mob/living/basic/mimic/crate)
	broken_light_percent = 30

/datum/derelict_theme/monsters/dress(datum/derelict_scene/scene)
	var/turf/heart = scene.boss_anchor
	// Gore where the crew comes in, and a trail where something was dragged off
	var/list/turf/entry = scene.telegraph_tiles()
	scene.scatter(/obj/effect/decal/cleanable/blood/splatter, 2, entry)
	scene.scatter(/obj/effect/decal/cleanable/blood/gibs, 1, entry)
	scene.scatter(/obj/effect/decal/cleanable/blood/old, 1, entry)
	if(length(entry))
		scene.drag_trail(/obj/effect/decal/cleanable/blood/old, 4, entry[1], scene.nearest_post(entry[1]))
	// The main feeding site, then the lesser ones
	feeding_site(scene, heart, 2, 2, 5, 3)
	for(var/turf/den as anything in scene.anchors)
		feeding_site(scene, den, 1, 1, 3, 2)
	// Something fed all through the place: lone splatters, with gibs or bones beside them
	var/list/turf/strays = scene.far_flung(4, 8)
	for(var/i in 1 to length(strays))
		var/turf/spot = strays[i]
		scene.scatter(/obj/effect/decal/cleanable/blood/splatter, 1, list(spot))
		var/leftover = /obj/effect/decal/remains/human
		if(i % 2)
			leftover = /obj/effect/decal/cleanable/blood/gibs
		scene.scatter(leftover, 1, scene.near(spot, 1, 1))

/// Heaps a feeding site's remains, gibs, splatter and old blood round `center`
/datum/derelict_theme/monsters/proc/feeding_site(datum/derelict_scene/scene, turf/center, remains, gibs, splatter, old)
	if(!center)
		return
	scene.scatter(/obj/effect/decal/remains/human, remains, scene.near(center, 2))
	scene.scatter(/obj/effect/decal/cleanable/blood/gibs, gibs, scene.near(center, 2))
	scene.scatter(/obj/effect/decal/cleanable/blood/splatter, splatter, scene.near(center, 3))
	scene.scatter(/obj/effect/decal/cleanable/blood/old, old, scene.near(center, 3, 1))

/**
 * # Derelict scene
 *
 * One build's working state while a theme dresses the derelict: the floor as it was, the anchors, the tiles filled
 * with dense dressing, and the dressing budget (DERELICT_MAX_DRESSING). Thrown away when the build is done.
 */
/datum/derelict_scene
	/// The derelict being dressed
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site
	/// Where the boss starts: the prison wing when there is one, else the far end of the habitat
	var/turf/boss_anchor
	/// Up to two lesser clusters out in the habitat
	var/list/turf/anchors = list()
	/// The derelict's unprotected floor, as it was before any dressing
	var/list/turf/open_tiles = list()
	/// open_tiles as turf = TRUE
	var/list/open_lookup = list()
	/// Floor a flat covering (weeds, dust) can lie on: open_tiles, plus walkable tiles under chairs, wall mounts and the like.
	/// Never the arrival point, the elevator alcove's ring or a doorway.
	var/list/turf/cover_tiles = list()
	/// cover_tiles as turf = TRUE
	var/list/cover_lookup = list()
	/// Every floor turf of the derelict's areas, as turf = TRUE
	var/list/floor_lookup = list()
	/// Tiles given dense dressing, as turf = TRUE
	var/list/filled = list()
	/// Dressing atoms placed so far
	var/placed = 0

/datum/derelict_scene/New(obj/structure/overmap/dynamic/player_outpost/derelict/site)
	src.site = site
	for(var/turf/tile as anything in site.derelict_floor_turfs())
		floor_lookup[tile] = TRUE
		if(!site.is_derelict_protected_turf(tile))
			open_tiles += tile
			open_lookup[tile] = TRUE
		if(tile == site.arrival_turf || has_dense(tile) || (locate(/obj/machinery/door) in tile))
			continue
		var/by_alcove = FALSE
		for(var/turf/alcove as anything in site.lobby_alcove_turfs)
			if(get_dist(tile, alcove) <= 1)
				by_alcove = TRUE
				break
		if(by_alcove)
			continue
		cover_tiles += tile
		cover_lookup[tile] = TRUE

/// The boss anchor then the lesser anchors, whichever exist
/datum/derelict_scene/proc/posts()
	. = anchors.Copy()
	if(boss_anchor)
		. = list(boss_anchor) + .

/// The anchor nearest `tile`, or null
/datum/derelict_scene/proc/nearest_post(turf/tile)
	for(var/turf/post as anything in posts())
		if(!. || get_dist(tile, post) < get_dist(tile, .))
			. = post

/// Up to `count` open habitat tiles spread through the outpost: `gap` or more tiles from each other, from every anchor
/// and from the arrival point and the elevator
/datum/derelict_scene/proc/far_flung(count, gap)
	. = list()
	var/list/turf/candidates = list()
	for(var/turf/tile as anything in open_tiles)
		if(!filled[tile] && get_area(tile) == site.outpost_area && !site.near_derelict_arrival(tile, gap))
			candidates += tile
	shuffle_inplace(candidates)
	var/list/turf/taken = posts()
	for(var/turf/tile as anything in candidates)
		if(length(.) >= count)
			return
		var/spaced = TRUE
		for(var/turf/other as anything in taken)
			if(get_dist(tile, other) < gap)
				spaced = FALSE
				break
		if(spaced)
			. += tile
			taken += tile

/// Picks the boss anchor and the lesser anchors (spec 4.3)
/datum/derelict_scene/proc/pick_anchors()
	var/obj/machinery/power/port_gen/pacman/generator = site.derelict_generator()
	// The boss: in the prison wing, in its most open part and clear of its doors. The wing's cells are the only
	// tiles 4 from every door; a boss behind a cell door would be caged, so 3 from the doors is far enough.
	var/datum/outpost_upgrade/wing = site.outpost_upgrades["prison"]
	var/area/wing_area = wing?.installed ? wing.installed_area : null
	if(wing_area)
		var/list/turf/doorways = list()
		for(var/turf/tile as anything in floor_lookup)
			if(locate(/obj/machinery/door) in tile)
				doorways += tile
		var/list/turf/wing_tiles = list()
		for(var/turf/tile as anything in open_tiles)
			if(get_area(tile) == wing_area)
				wing_tiles += tile
		var/best_score = -1
		var/list/turf/scores = list()
		for(var/turf/tile as anything in wing_tiles)
			if(!hostile_can_start(tile, generator))
				continue
			var/gap = 3
			for(var/turf/doorway as anything in doorways)
				gap = min(gap, get_dist(tile, doorway))
			var/room = 0
			for(var/turf/other as anything in wing_tiles)
				if(get_dist(tile, other) <= 2)
					room++
			scores[tile] = gap * 100 + room
			best_score = max(best_score, scores[tile])
		var/list/turf/best = list()
		for(var/turf/tile as anything in scores)
			if(scores[tile] >= best_score - 2)
				best += tile
		if(length(best))
			boss_anchor = pick(best)
	// No wing: the habitat tile farthest from the arrival point
	if(!boss_anchor)
		var/best_distance = -1
		var/list/turf/best = list()
		for(var/turf/tile as anything in open_tiles)
			if(get_area(tile) != site.outpost_area || !hostile_can_start(tile, generator))
				continue
			var/distance = site.arrival_turf ? get_dist(tile, site.arrival_turf) : 0
			if(distance > best_distance)
				best_distance = distance
				best = list(tile)
			else if(distance == best_distance)
				best += tile
		if(length(best))
			boss_anchor = pick(best)
	// Two lesser anchors in the habitat, 10 or more tiles from the arrival point and from each other,
	// and away from the boss when the habitat allows
	var/list/turf/candidates = list()
	for(var/turf/tile as anything in open_tiles)
		if(get_area(tile) == site.outpost_area && hostile_can_start(tile, generator) && !site.near_derelict_arrival(tile, 9))
			candidates += tile
	shuffle_inplace(candidates)
	for(var/boss_gap in list(8, 0))
		for(var/turf/tile as anything in candidates)
			if(length(anchors) >= 2)
				return
			if(boss_anchor && get_dist(tile, boss_anchor) < boss_gap)
				continue
			var/spaced = TRUE
			for(var/turf/other as anything in anchors)
				if(get_dist(tile, other) < 10)
					spaced = FALSE
					break
			if(spaced)
				anchors += tile

/// Breaks `percent` of the light fixtures in the derelict's areas. They spark once power is back. Returns how many broke.
/datum/derelict_scene/proc/break_lights(percent)
	. = 0
	var/z = site.upgrade_level_z()
	if(!z || percent <= 0)
		return
	var/total = 0
	var/list/obj/machinery/light/whole = list()
	for(var/area/place as anything in site.derelict_areas())
		for(var/turf/tile as anything in place.get_turfs_by_zlevel(z))
			for(var/obj/machinery/light/fixture in tile)
				total++
				if(fixture.status == LIGHT_OK || fixture.status == LIGHT_BURNED)
					whole += fixture
	var/to_break = min(round(total * percent / 100), length(whole))
	shuffle_inplace(whole)
	for(var/i in 1 to to_break)
		var/obj/machinery/light/fixture = whole[i]
		fixture.break_light_tube(TRUE)
	return to_break

/// Whether `tile` holds anything dense but a mob
/datum/derelict_scene/proc/has_dense(turf/tile)
	for(var/atom/movable/thing as anything in tile)
		if(thing.density && !ismob(thing))
			return TRUE
	return FALSE

/// Whether `tile` is a wall or holds dense dressing
/datum/derelict_scene/proc/is_shut(turf/tile)
	return tile && (isclosedturf(tile) || filled[tile])

/// Whether `tile` is the derelict's floor with nothing dense on it but mobs
/datum/derelict_scene/proc/is_walkable(turf/tile)
	return tile && floor_lookup[tile] && !filled[tile] && !has_dense(tile)

/**
 * Whether `tile` can take something dense without cutting any path. It must stand against a wall (or earlier
 * dense dressing), have no door and nothing dense but walls and dressing within a tile, and every open side must
 * be the derelict's walkable floor. Its open sides must also stay joined round the ring of eight tiles about it,
 * so anything that walked through it walks round it, and filling it takes only itself off the walkable floor.
 */
/datum/derelict_scene/proc/can_fill(turf/tile)
	if(!open_lookup[tile] || filled[tile] || tile == boss_anchor || has_dense(tile))
		return FALSE
	// Doors, machines and furniture keep every approach they had
	for(var/turf/close as anything in RANGE_TURFS(1, tile))
		if(close == tile || isclosedturf(close) || filled[close])
			continue
		if(has_dense(close) || (locate(/obj/machinery/door) in close))
			return FALSE
	var/against_wall = FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(is_shut(beside))
			against_wall = TRUE
		else if(!is_walkable(beside))
			return FALSE
	if(!against_wall)
		return FALSE
	// Walk the ring from a shut side; every open side must fall in the same run of walkable tiles
	var/static/list/ring = list(NORTH, NORTHEAST, EAST, SOUTHEAST, SOUTH, SOUTHWEST, WEST, NORTHWEST)
	var/list/walkable_ring = new /list(8)
	var/start = 0
	for(var/i in 1 to 8)
		walkable_ring[i] = is_walkable(get_step(tile, ring[i])) ? TRUE : FALSE
		if(!start && !walkable_ring[i])
			start = i
	var/run = 0
	var/open_side_run = 0
	for(var/offset in 1 to 7)
		var/i = (start + offset - 1) % 8 + 1
		if(!walkable_ring[i])
			continue
		if(!walkable_ring[(start + offset - 2) % 8 + 1])
			run++
		// odd ring places are the four sides
		if(i % 2)
			if(open_side_run && open_side_run != run)
				return FALSE
			open_side_run = run
	return TRUE

/// The open tiles `min_range` to `max_range` steps on foot from `center` with no dense dressing, shuffled
/datum/derelict_scene/proc/near(turf/center, max_range, min_range = 0)
	. = list()
	var/list/steps_to = walk_from(center, max_range)
	for(var/turf/tile as anything in steps_to)
		if(open_lookup[tile] && !filled[tile] && steps_to[tile] >= min_range)
			. += tile
	shuffle_inplace(.)

/**
 * Steps on foot from `center` to each tile within `max_range` steps, as turf = steps. Walks the derelict's floor
 * round anything dense, so a cluster stays in its own room; closed doors stop it unless `through_doors`.
 */
/datum/derelict_scene/proc/walk_from(turf/center, max_range, through_doors = FALSE)
	var/list/steps_to = list()
	if(!center)
		return steps_to
	steps_to[center] = 0
	var/list/turf/queue = list(center)
	var/index = 1
	while(index <= length(queue))
		var/turf/tile = queue[index]
		index++
		var/steps = steps_to[tile]
		if(steps >= max_range)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(tile, direction)
			if(!next || !isnull(steps_to[next]))
				continue
			if(!is_walkable(next) && !(through_doors && floor_lookup[next] && (locate(/obj/machinery/door) in next)))
				continue
			steps_to[next] = steps + 1
			queue += next
	return steps_to

/// The open tiles 3 to 5 steps from the arrival point: where the theme shows itself before anything attacks
/datum/derelict_scene/proc/telegraph_tiles()
	if(!site.arrival_turf)
		return list()
	return near(site.arrival_turf, 5, 3)

/// Places one dressing atom of `path` on `tile` within the budget. Returns it, or null when out of budget or merged away.
/datum/derelict_scene/proc/put(path, turf/tile)
	if(placed >= DERELICT_MAX_DRESSING || !tile)
		return null
	var/atom/movable/thing = new path(tile)
	if(QDELETED(thing))
		return null
	placed++
	if(istype(thing, /obj/effect/decal/cleanable/blood))
		// Fresh blood processes while it dries and leaves footprints; this has been here a while
		var/obj/effect/decal/cleanable/blood/stain = thing
		stain.dry()
	return thing

/**
 * Places up to `count` of `path`, one each on tiles from `tiles` that do not already hold one. Returns the atoms placed.
 * Only open tiles take it, or with `cover` any of the cover tiles (for flat coverings).
 */
/datum/derelict_scene/proc/scatter(path, count, list/turf/tiles, cover = FALSE)
	. = list()
	var/list/allowed = cover ? cover_lookup : open_lookup
	for(var/turf/tile as anything in tiles)
		if(length(.) >= count || placed >= DERELICT_MAX_DRESSING)
			return
		if(!allowed[tile] || filled[tile] || (locate(path) in tile))
			continue
		var/atom/movable/thing = put(path, tile)
		if(thing)
			. += thing

/// Places up to `count` of dense `path` against the walls within `range` of `center`, mostly the nearest. Returns the atoms placed.
/datum/derelict_scene/proc/put_dense(path, count, turf/center, range)
	. = list()
	var/list/turf/rank = list()
	var/list/steps_to = walk_from(center, range)
	for(var/turf/tile as anything in steps_to)
		if(open_lookup[tile] && !filled[tile])
			rank[tile] = steps_to[tile] + rand(0, 3)
	while(length(.) < count && length(rank) && placed < DERELICT_MAX_DRESSING)
		var/turf/best
		for(var/turf/tile as anything in rank)
			if(!best || rank[tile] < rank[best])
				best = tile
		rank -= best
		// checked now, not up front: each piece placed changes what can be filled
		if(!can_fill(best))
			continue
		var/atom/movable/thing = put(path, best)
		if(!thing)
			return
		filled[best] = TRUE
		. += thing

/// Draws one rune in dried blood on `tile`. Returns it, or null.
/datum/derelict_scene/proc/put_rune(turf/tile)
	if(!tile || !open_lookup[tile] || filled[tile] || placed >= DERELICT_MAX_DRESSING)
		return null
	if(locate(/obj/effect/decal/cleanable/crayon) in tile)
		return null
	var/obj/effect/decal/cleanable/crayon/rune = new(tile, "#6b0000", "rune[rand(1, 6)]", "rune", 0, null, "Drawn in dried blood.")
	if(QDELETED(rune))
		return null
	placed++
	return rune

/// Draws up to `count` runes on tiles from `tiles`. Returns how many.
/datum/derelict_scene/proc/scatter_runes(count, list/turf/tiles)
	. = 0
	for(var/turf/tile as anything in tiles)
		if(. >= count)
			return
		if(put_rune(tile))
			.++

/// Stands up to `count` lit eternal candles on tiles from `tiles`, a little off centre so they look set down by hand
/datum/derelict_scene/proc/scatter_candles(count, list/turf/tiles)
	for(var/obj/item/flashlight/flare/candle/infinite/candle as anything in scatter(/obj/item/flashlight/flare/candle/infinite, count, tiles))
		candle.pixel_x = rand(-7, 7)
		candle.pixel_y = rand(-4, 8)

/// Lays `path` on up to `steps` tiles from `from` toward `toward`, stopping at a wall
/datum/derelict_scene/proc/drag_trail(path, steps, turf/from, turf/toward)
	if(!from || !toward)
		return
	var/turf/here = from
	for(var/i in 1 to steps)
		here = get_step_towards(here, toward)
		if(!here || here == toward || isclosedturf(here))
			return
		scatter(path, 1, list(here))

/// Whether a hostile may start on `tile`: open floor, nothing dense, clear of the arrival point, the elevator and the generator
/datum/derelict_scene/proc/hostile_can_start(turf/tile, obj/machinery/power/port_gen/pacman/generator)
	if(!open_lookup[tile] || filled[tile] || has_dense(tile))
		return FALSE
	if(site.near_derelict_arrival(tile))
		return FALSE
	return !generator || get_dist(tile, generator) > DERELICT_GENERATOR_CLEAR_RADIUS

/// Spawns the theme's boss and its roster for the derelict's band, spread round the anchors, each scaled and leashed
/datum/derelict_scene/proc/spawn_hostiles(datum/derelict_theme/theme)
	var/red = site.derelict_band == ZONE_RED
	var/obj/machinery/power/port_gen/pacman/generator = site.derelict_generator()
	var/list/turf/legal = list()
	for(var/turf/tile as anything in open_tiles)
		if(hostile_can_start(tile, generator))
			legal += tile
	var/list/mob/living/spawned = list()
	// The boss first, at its anchor
	var/turf/boss_tile = (boss_anchor && hostile_can_start(boss_anchor, generator)) ? boss_anchor : pick_hostile_tile(legal, spawned, boss_anchor, FALSE)
	if(boss_tile)
		add_hostile(theme, theme.boss_type, boss_tile, red ? DERELICT_BOSS_HEALTH_MULT_RED : DERELICT_BOSS_HEALTH_MULT_YELLOW, spawned)
	else
		log_mapping("Derelict outpost [site.true_name]: no room for its [theme.name] boss.")
	// Then the roster, taking the anchors in turn so every cluster is guarded
	var/list/turf/guard_posts = posts()
	var/post_index = 0
	for(var/hostile_type in theme.roster)
		var/list/counts = theme.roster[hostile_type]
		for(var/i in 1 to counts[red ? 2 : 1])
			if(length(spawned) >= DERELICT_MAX_HOSTILES)
				log_mapping("Derelict outpost [site.true_name]: the [theme.name] roster is over [DERELICT_MAX_HOSTILES] hostiles.")
				return
			var/turf/center = null
			var/lurker = (hostile_type in theme.lurkers)
			if(!lurker && !(hostile_type in theme.roamers) && length(guard_posts))
				post_index = post_index % length(guard_posts) + 1
				center = guard_posts[post_index]
			var/turf/tile = pick_hostile_tile(legal, spawned, center, lurker)
			if(!tile)
				log_mapping("Derelict outpost [site.true_name]: no room for a [hostile_type].")
				continue
			add_hostile(theme, hostile_type, tile, red ? DERELICT_HEALTH_MULT_RED : DERELICT_HEALTH_MULT_YELLOW, spawned)

/**
 * A start tile for one hostile from `legal`, spaced DERELICT_HOSTILE_SPACING from the others (1 if nothing fits).
 * Prefers tiles within 6 of `center`, or tiles against a wall for a lurker; takes any legal tile otherwise. Null if none.
 */
/datum/derelict_scene/proc/pick_hostile_tile(list/turf/legal, list/mob/living/spawned, turf/center, lurker)
	for(var/spacing in list(DERELICT_HOSTILE_SPACING, 1))
		var/list/turf/preferred = list()
		var/list/turf/fallback = list()
		for(var/turf/tile as anything in legal)
			if(has_dense(tile))
				continue
			var/spaced = TRUE
			for(var/mob/living/other as anything in spawned)
				if(get_dist(tile, other) < spacing)
					spaced = FALSE
					break
			if(!spaced)
				continue
			if(lurker ? can_fill(tile) : (!center || get_dist(tile, center) <= 6))
				preferred += tile
			else
				fallback += tile
		if(length(preferred))
			return pick(preferred)
		if(length(fallback))
			return pick(fallback)
	return null

/// Spawns one hostile of `hostile_type` on `tile`, readies, scales and leashes it. Returns it, or null.
/datum/derelict_scene/proc/add_hostile(datum/derelict_theme/theme, hostile_type, turf/tile, multiplier, list/mob/living/spawned)
	var/mob/living/hostile = new hostile_type(tile)
	if(QDELETED(hostile))
		// A mi-go can come out as its rare variant, which takes its place on the tile
		hostile = null
		for(var/mob/living/replacement in tile)
			if(istype(replacement, hostile_type) && !QDELETED(replacement) && !(replacement in spawned))
				hostile = replacement
				break
		if(!hostile)
			return null
	theme.prepare_hostile(hostile)
	scale_npc_ship_pirate_health(hostile, multiplier)
	hostile.AddComponent(/datum/component/derelict_leash, site)
	site.derelict_hostiles += WEAKREF(hostile)
	spawned += hostile
	return hostile
