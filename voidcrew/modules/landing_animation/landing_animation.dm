/**
 * # Planet landing and takeoff visuals
 *
 * Seen from the ground, a ship docking on a planet used to pop onto its berth. Now a soft shadow of the hull
 * spreads over the berth during the dock warmup, then the ship itself drops out of the sky and the real hull
 * replaces it the moment it lands. On takeoff it lifts off on its thrusters, pitches its nose up and flies away
 * toward its bow.
 *
 * The falling ship is a proxy: one object carrying a picture of the hull, taken from its transit turfs when it
 * comes into sight, so it is the ship as it really looks, crew and all. Nothing here changes docking: the
 * warmup, the move and its crush are untouched.
 *
 * Visual only. Proxies and shadows are mouse-transparent, not dense, and every path that ends a dock
 * (arrival, refusal, cancellation, a deleted ship or site) removes them.
 */

/// The descending ship comes into sight this long before the expected touchdown (deciseconds)
#define LANDING_PROXY_LEAD (3 SECONDS)
/// The shadow starts fading in this long before the expected touchdown
#define LANDING_SHADOW_LEAD (6 SECONDS)
/// Height the descending ship starts at, in pixels: well out of sight of anyone near the berth, so it flies
/// in and out of view rather than popping in
#define LANDING_PROXY_START_HEIGHT 1100
/// Height of the ship one second before touchdown
#define LANDING_PROXY_FINAL_HEIGHT 64
/// Takeoff, in three beats: a level lift on the thrusters, the nose pitching up, then off toward the bow
#define LAUNCH_LIFT_TIME (1 SECONDS)
#define LAUNCH_TILT_TIME (1 SECONDS)
#define LAUNCH_GO_TIME (1.5 SECONDS)
/// Height of the leaving ship, in pixels, at the end of each beat
#define LAUNCH_LIFT_HEIGHT 20
#define LAUNCH_TILT_HEIGHT 44
#define LAUNCH_GO_HEIGHT 140
/// How far the whole hull turns (degrees) as its nose comes up, and how much nearer (bigger) it looks then
#define LAUNCH_TILT_ANGLE 10
#define LAUNCH_TILT_SCALE 1.04
/// How far the ship creeps toward its bow while it pitches up
#define LAUNCH_TILT_CREEP 24
/// Size of the ship as it leaves the screen
#define LAUNCH_GO_SCALE 0.9
/// Tiles past the hull's own length it flies before it is removed: off the screen of anyone near the berth
#define LAUNCH_GO_TILES 30
/// How far the shadow slides after it, in tiles
#define LAUNCH_SHADOW_SLIDE_TILES 10
/// Thruster wash: most puffs per wave (three waves), the chance an engine-end tile throws one, how far they blow
#define LAUNCH_WASH_PER_WAVE 9
#define LAUNCH_WASH_CHANCE 100
#define LAUNCH_WASH_PUSH 1.8
/// Width of the shadow at its widest, relative to the hull
#define LANDING_SHADOW_WIDE 1.35
/// Width of the shadow just before touchdown
#define LANDING_SHADOW_NEAR 1.15
/// The shadow's darkness (alpha) when the ship is high up and when it is about to land
#define LANDING_SHADOW_FAINT 56
#define LANDING_SHADOW_DARK 100
/// The layer the proxy draws its ship turfs at. Everything standing on the hull sorts above it.
#define LANDING_PROXY_TURF_LAYER 2.05
/// Above everything on a hull tile: the tile's light, multiplied over it in the picture
#define LANDING_PROXY_LIGHT_LAYER 100
/// Just above bullet holes and floor clutter, below every object and mob
#define LANDING_SHADOW_LAYER 2.07
/// Height the descending ship waits at until the move starts
#define LANDING_PROXY_HOVER 10
/// How long the picture takes to give way to the real hull
#define LANDING_PICTURE_FADE (0.8 SECONDS)
/// How long the picture covers a landed hull while its lighting is rebuilt
#define LANDING_LIGHTING_SETTLE (2 SECONDS)
/// Chance an edge tile kicks up a puff of dust, and the most puffs one landing makes
#define LANDING_DUST_CHANCE 20
#define LANDING_DUST_MAX 12
/// How hard the screen shakes for those who feel a landing or a takeoff (tiles)
#define LANDING_SHAKE 0.4
/// How far from the hull people on the ground feel and hear it land or leave
#define LANDING_HEAR_RANGE 12

/// Running descent for this ship, if any
/obj/structure/overmap/ship/var/datum/landing_animation/landing_animation

/// Whether docking at this overmap object plays the planet landing. Terrain planets only; outposts,
/// empty space and flat encounters keep their plain dock.
/proc/landing_animation_wanted(obj/structure/overmap/site)
	var/obj/structure/overmap/planet/planet = astype(site, /obj/structure/overmap/planet)
	return !!planet?.is_terrain_planet()

/**
 * Starts the descent for a warmup that is about to run. Called by dock() and on_planet_loaded() as they
 * start their warmup timer.
 * * site - the overmap object being docked at
 * * dock_to_use - the berth the hull will land on
 * * warmup - the warmup length; touchdown is expected one SSshuttle second after it
 */
/obj/structure/overmap/ship/proc/start_landing_animation(obj/structure/overmap/site, obj/docking_port/stationary/dock_to_use, warmup)
	QDEL_NULL(landing_animation)
	if(!shuttle || !dock_to_use || !landing_animation_wanted(site))
		return
	landing_animation = new(src, site, dock_to_use, warmup + 1 SECONDS)

/// Ends the descent, removing every proxy and the shadow.
/obj/structure/overmap/ship/proc/end_landing_animation()
	QDEL_NULL(landing_animation)

/obj/structure/overmap/ship/Destroy()
	QDEL_NULL(landing_animation)
	return ..()

/**
 * The hull starts to move. This is the touchdown everyone sees: a descent's picture settles on the ground and
 * covers the real hull until its lighting is rebuilt, and a launch takes its picture of the hull before the
 * move touches it.
 */
/obj/docking_port/mobile/voidcrew/initiate_docking(obj/docking_port/stationary/new_dock, movement_direction, force = FALSE)
	var/obj/structure/overmap/ship/ship = current_ship
	if(!ship || !new_dock || move_in_flight())
		return ..()
	var/obj/docking_port/stationary/old_dock = get_docked()
	var/datum/landing_animation/descent
	var/datum/launch_animation/launch
	if(ship.state == OVERMAP_SHIP_DOCKING && istype(old_dock, /obj/docking_port/stationary/transit) && !istype(new_dock, /obj/docking_port/stationary/transit) && landing_animation_wanted(ship.docked))
		var/list/pairs = landing_hull_pairs(src, new_dock)
		descent = ship.landing_animation
		descent?.freeze()
		landing_touchdown(pairs[2])
		// the crew aboard feel it too, though they are still in transit for the moment
		landing_jolt(pairs[1], 'sound/effects/meteorimpact.ogg', 60, shake_strength = LANDING_SHAKE)
	else if(ship.state == OVERMAP_SHIP_UNDOCKING && old_dock && !istype(old_dock, /obj/docking_port/stationary/transit) && istype(new_dock, /obj/docking_port/stationary/transit) && landing_animation_wanted(ship.undock_origin?.resolve()))
		launch = new(landing_hull_pairs(src, new_dock)[1], src)
	. = ..()
	if(launch)
		if(. == DOCKING_SUCCESS)
			launch.lift_off(landing_hull_pairs(src, old_dock)[1])
		else
			qdel(launch)
	if(descent && !QDELETED(descent) && . == DOCKING_SUCCESS)
		descent.landed()

/// Hull on the ground: dust off the edges, and a jolt for everyone aboard and nearby.
/proc/landing_touchdown(list/hull_turfs)
	landing_dust(hull_turfs)
	landing_jolt(hull_turfs, 'sound/effects/meteorimpact.ogg', 60, reach = LANDING_HEAR_RANGE, shake_strength = LANDING_SHAKE)

/**
 * Shakes the camera of, and plays [sound_file] to, every player on [hull_turfs] and, with [reach], everyone within
 * that many tiles of the hull on the same level.
 */
/proc/landing_jolt(list/hull_turfs, sound_file, volume, reach = 0, shake_time = 3, shake_strength = 0)
	if(!length(hull_turfs))
		return
	var/list/hull_set = list()
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_set[hull_turf] = TRUE
		min_x = min(min_x, hull_turf.x)
		max_x = max(max_x, hull_turf.x)
		min_y = min(min_y, hull_turf.y)
		max_y = max(max_y, hull_turf.y)
	var/turf/first = hull_turfs[1]
	var/turf/middle = locate(round((min_x + max_x) / 2), round((min_y + max_y) / 2), first.z)
	// a packed level holds other sites a few tiles away; they neither hear nor feel it
	var/datum/own_region = map_region_for_turf(first)
	// ghosts too, as with explosions (SSmobs.clients_by_zlevel only holds living mobs)
	for(var/mob/listener as anything in GLOB.player_list)
		var/turf/where = get_turf(listener)
		if(!where || where.z != first.z)
			continue
		if(!hull_set[where] && (!reach || map_region_excludes_turf(own_region, where) || where.x < min_x - reach || where.x > max_x + reach || where.y < min_y - reach || where.y > max_y + reach))
			continue
		if(shake_strength)
			shake_camera(listener, shake_time, shake_strength)
		if(sound_file)
			listener.playsound_local(hull_set[where] ? where : middle, sound_file, volume, TRUE, pressure_affected = FALSE, max_distance = reach + max(max_x - min_x, max_y - min_y))

/// A few light puffs of dust kicked out from the hull's edges
/proc/landing_dust(list/hull_turfs)
	var/list/hull_set = list()
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_set[hull_turf] = TRUE
	var/puffs = 0
	for(var/turf/hull_turf as anything in shuffle(hull_turfs.Copy()))
		if(puffs >= LANDING_DUST_MAX)
			break
		for(var/edge_dir in GLOB.cardinals)
			var/turf/outside = get_step(hull_turf, edge_dir)
			if(!outside || hull_set[outside] || isclosedturf(outside))
				continue
			if(!prob(LANDING_DUST_CHANCE))
				break
			new /obj/effect/temp_visual/landing_dust(outside, edge_dir)
			puffs++
			break

/// Pairs each hull tile's current turf with the turf it covers on [dock], the same pairing the move uses.
/// Returns list(current turfs, destination turfs).
/proc/landing_hull_pairs(obj/docking_port/mobile/shuttle, obj/docking_port/stationary/dock)
	var/list/from_turfs = shuttle.return_ordered_turfs(shuttle.x, shuttle.y, shuttle.z, shuttle.dir)
	var/list/to_turfs = shuttle.return_ordered_turfs(dock.x, dock.y, dock.z, dock.dir)
	var/list/hull_from = list()
	var/list/hull_to = list()
	for(var/i in 1 to min(length(from_turfs), length(to_turfs)))
		var/turf/from_turf = from_turfs[i]
		var/turf/to_turf = to_turfs[i]
		if(!from_turf || !to_turf)
			continue
		if(!istype(from_turf.loc, shuttle.area_type) || istype(from_turf.loc, /area/shuttle/transit))
			continue
		hull_from += from_turf
		hull_to += to_turf
	return list(hull_from, hull_to)

/// The rotation, in degrees clockwise, a move from [shuttle]'s heading onto [dock] applies to the hull.
/proc/landing_rotation(obj/docking_port/mobile/shuttle, obj/docking_port/stationary/dock)
	if(dock.dir == shuttle.dir)
		return 0
	var/rotation = dir2angle(dock.dir) - dir2angle(shuttle.dir)
	if(rotation % 90)
		rotation += rotation % 90
	return SIMPLIFY_DEGREES(rotation)

/**
 * # Ship proxy
 *
 * A still picture of a whole hull, drawn somewhere else: every visible thing on each hull tile, copied as an
 * overlay at that tile's spot. It is one object, so the whole picture moves as one (separate tiles tweened
 * separately round to different pixels and open seams between the rows), and it is a picture rather than a
 * live view, because a hull's lighting is torn down and rebuilt row by row around every move.
 */
/obj/effect/abstract/landing_proxy
	name = ""
	anchored = TRUE
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Above the game world and its lighting: the ship is in the air, over everyone, ripples included. On any
	// lit plane the ground's light at the spot it passes over (lava glow, a dark patch) shows on the hull and
	// it reads as see-through. It carries its own light instead; see picture().
	plane = ABOVE_LIGHTING_PLANE
	layer = LANDING_PROXY_TURF_LAYER
	// one picture, so each tile's light multiplies only the tile under it
	appearance_flags = KEEP_TOGETHER | PIXEL_SCALE
	vis_flags = NONE

/// A launch's picture stands on the hull it shows: it stays on the ground when the hull leaves
/obj/effect/abstract/landing_proxy/onShuttleMove(turf/newT, turf/oldT, list/movement_force, move_dir, obj/docking_port/stationary/old_dock, obj/docking_port/mobile/moving_dock)
	return

/**
 * Draws the hull standing on [sources] as it will stand on [places] (same order, all on one z), turned
 * [rotation] degrees clockwise. Returns FALSE with nothing to draw.
 */
/obj/effect/abstract/landing_proxy/proc/picture(list/sources, list/places, rotation = 0)
	if(!length(places))
		return FALSE
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	for(var/turf/place as anything in places)
		min_x = min(min_x, place.x)
		max_x = max(max_x, place.x)
		min_y = min(min_y, place.y)
		max_y = max(max_y, place.y)
	// stand in the middle, so anyone who can see much of the hull can see the picture
	var/turf/anchor = locate(round((min_x + max_x) / 2), round((min_y + max_y) / 2), places[1].z)
	if(!anchor)
		return FALSE
	abstract_move(anchor)
	SET_PLANE_IMPLICIT(src, ABOVE_LIGHTING_PLANE)
	var/matrix/turn = rotation ? matrix().Turn(rotation) : null
	// One group per world plane, floor first. In the world each plane draws whole over the one below, whatever
	// the layers; in one picture everything would sort by layer alone, and floor things (cables, catwalks,
	// blood, all on TOPDOWN_LAYER) would paint over every machine on the game plane.
	var/list/plane_parts = new /list(ABOVE_GAME_PLANE - FLOOR_PLANE + 1)
	for(var/rank in 1 to length(plane_parts))
		plane_parts[rank] = list()
	var/list/parts = list()
	for(var/i in 1 to length(places))
		var/turf/source = sources[i]
		var/turf/place = places[i]
		var/offset_w = (place.x - anchor.x) * ICON_SIZE_X
		var/offset_z = (place.y - anchor.y) * ICON_SIZE_Y
		var/turf_plane = clamp(PLANE_TO_TRUE(source.plane), FLOOR_PLANE, ABOVE_GAME_PLANE)
		var/mutable_appearance/floor = new(source)
		floor.underlays = list() // its lighting; drawn below as a multiply over the whole tile
		floor.plane = FLOAT_PLANE
		floor.pixel_w += offset_w
		floor.pixel_z += offset_z
		if(turn)
			floor.transform = turn
		plane_parts[turf_plane - FLOOR_PLANE + 1] += floor
		for(var/atom/movable/thing as anything in source)
			if(thing.invisibility > SEE_INVISIBLE_LIVING || !thing.icon)
				continue
			// only what is drawn on the world itself; light glows and other effect planes would paint as images
			var/true_plane = PLANE_TO_TRUE(thing.plane)
			if(true_plane < FLOOR_PLANE || true_plane > ABOVE_GAME_PLANE)
				continue
			var/mutable_appearance/part = new(thing)
			part.plane = FLOAT_PLANE
			part.pixel_w += offset_w
			part.pixel_z += offset_z
			if(turn)
				part.transform = turn
			plane_parts[true_plane - FLOOR_PLANE + 1] += part
	for(var/rank in 1 to length(plane_parts))
		if(!length(plane_parts[rank]))
			continue
		var/mutable_appearance/plane_group = new()
		plane_group.plane = FLOAT_PLANE
		plane_group.layer = rank
		plane_group.appearance_flags = KEEP_TOGETHER | PIXEL_SCALE
		plane_group.overlays = plane_parts[rank]
		parts += plane_group
	for(var/i in 1 to length(places))
		var/turf/source = sources[i]
		var/turf/place = places[i]
		var/offset_w = (place.x - anchor.x) * ICON_SIZE_X
		var/offset_z = (place.y - anchor.y) * ICON_SIZE_Y
		// the tile's own light as the hull has it now, laid over the tile the way the lighting plane would
		// (rooms lit by their area as a whole, or not lit at all, have no darkness of their own to carry)
		var/area/source_area = source.loc
		var/mutable_appearance/light = source.lighting_object?.current_underlay
		if(light && source_area.static_lighting && !source_area.base_lighting_alpha)
			var/mutable_appearance/tile_light = new(light)
			tile_light.plane = FLOAT_PLANE
			tile_light.layer = LANDING_PROXY_LIGHT_LAYER
			tile_light.blend_mode = BLEND_MULTIPLY
			tile_light.pixel_w += offset_w
			tile_light.pixel_z += offset_z
			if(turn)
				tile_light.transform = turn
			parts += tile_light
	overlays = parts
	return TRUE

/**
 * # Ship shadow
 *
 * The hull's outline in soft black on the ground. One object: a black square overlay per hull tile, kept
 * together and blurred, so scaling it spreads the whole outline about the hull's middle.
 */
/obj/effect/abstract/landing_shadow
	name = ""
	anchored = TRUE
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Game plane, under everything standing there. The floor plane would add it to the light mask and
	// light up ground that is meant to stay dark.
	plane = GAME_PLANE
	layer = LANDING_SHADOW_LAYER
	appearance_flags = KEEP_TOGETHER | PIXEL_SCALE
	alpha = 0
	vis_flags = NONE

/// Builds the outline from [hull_turfs] (the turfs the hull covers, all on one z). Returns FALSE with nothing to draw.
/obj/effect/abstract/landing_shadow/proc/outline(list/hull_turfs)
	if(!length(hull_turfs))
		return FALSE
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	for(var/turf/hull_turf as anything in hull_turfs)
		min_x = min(min_x, hull_turf.x)
		max_x = max(max_x, hull_turf.x)
		min_y = min(min_y, hull_turf.y)
		max_y = max(max_y, hull_turf.y)
	// The middle of the bounding box, in tiles, which the shadow spreads and shrinks about
	var/mid_x = (min_x + max_x) / 2
	var/mid_y = (min_y + max_y) / 2
	var/anchor_x = round(mid_x)
	var/anchor_y = round(mid_y)
	var/turf/anchor = locate(anchor_x, anchor_y, hull_turfs[1].z)
	if(!anchor)
		return FALSE
	abstract_move(anchor)
	SET_PLANE_IMPLICIT(src, GAME_PLANE)
	// Pivot on the box's middle: transforms scale about our own tile's centre, so shift that onto it
	pixel_w = (mid_x - anchor_x) * ICON_SIZE_X
	pixel_z = (mid_y - anchor_y) * ICON_SIZE_Y
	var/list/squares = list()
	for(var/turf/hull_turf as anything in hull_turfs)
		var/mutable_appearance/square = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
		square.color = COLOR_BLACK
		square.pixel_w = (hull_turf.x - mid_x) * ICON_SIZE_X
		square.pixel_z = (hull_turf.y - mid_y) * ICON_SIZE_Y
		squares += square
	overlays = squares
	add_filter("landing_shadow_blur", 1, gauss_blur_filter(size = 8))
	return TRUE

/// A puff of dust thrown off a hull's edge as it lands or lifts off, drifting away from the hull
/obj/effect/temp_visual/landing_dust
	name = ""
	icon = 'icons/effects/96x96.dmi'
	icon_state = "smoke"
	color = "#c9b79c"
	// over a climbing ship as well
	plane = ABOVE_LIGHTING_PLANE
	layer = LANDING_PROXY_LIGHT_LAYER + 1
	pixel_w = -32
	pixel_z = -32
	alpha = 0
	duration = 2.4 SECONDS

/// [push] scales how far it is blown: thruster wash drifts further than a settling hull's dust
/obj/effect/temp_visual/landing_dust/Initialize(mapload, push_dir = NORTH, push = 1)
	. = ..()
	SET_PLANE_IMPLICIT(src, ABOVE_LIGHTING_PLANE)
	var/drift = round(rand(14, 28) * push)
	if(push > 1) // thruster wash: as much air as dust, paler so it shows on sand too
		color = "#e4ded2"
	var/drift_w = (push_dir & EAST) ? drift : ((push_dir & WEST) ? -drift : rand(-6, 6))
	var/drift_z = (push_dir & NORTH) ? drift : ((push_dir & SOUTH) ? -drift : rand(-6, 6))
	transform = matrix().Scale(0.45)
	animate(src, alpha = push > 1 ? rand(110, 150) : rand(80, 120), transform = matrix().Scale(0.7), time = 0.3 SECONDS, easing = SINE_EASING | EASE_OUT)
	animate(alpha = 0, transform = matrix().Scale(1.1), pixel_w = pixel_w + drift_w, pixel_z = pixel_z + drift_z, time = duration - 0.3 SECONDS, easing = SINE_EASING | EASE_OUT)

/**
 * # Descent
 *
 * Owned by the ship for the length of one planet dock warmup. Removed by the hull's move (takeoff()), or by
 * its own watch the moment the ship stops docking at this site.
 */
/datum/landing_animation
	/// The ship coming down
	var/obj/structure/overmap/ship/ship
	/// Where it is docking
	var/datum/weakref/site_ref
	/// The hull's turfs in transit, in the same order as [berth_turfs]
	var/list/hull_turfs
	/// The berth turfs each hull tile lands on
	var/list/berth_turfs
	/// Clockwise degrees the landing turns the hull
	var/rotation = 0
	/// world.time the hull is expected to touch down
	var/touchdown_time
	/// world.time after which the descent gives up waiting for the hull
	var/give_up_time
	var/obj/effect/abstract/landing_shadow/shadow
	/// The falling hull
	var/obj/effect/abstract/landing_proxy/proxy
	/// client -> the image that hides the picture from them: the crew aboard, who would otherwise see a still
	/// copy of their ship, themselves included, over the real one for a moment after landing
	var/list/hidden_from = list()
	/// TRUE once the move has started and the picture is on the ground
	var/frozen = FALSE
	/// TRUE once the hull is down and the picture only covers it while its lighting catches up
	var/landed = FALSE

/datum/landing_animation/New(obj/structure/overmap/ship/ship, obj/structure/overmap/site, obj/docking_port/stationary/dock, until_touchdown)
	. = ..()
	src.ship = ship
	site_ref = WEAKREF(site)
	var/list/pairs = landing_hull_pairs(ship.shuttle, dock)
	hull_turfs = pairs[1]
	berth_turfs = pairs[2]
	rotation = landing_rotation(ship.shuttle, dock)
	touchdown_time = world.time + until_touchdown
	give_up_time = touchdown_time + 60 SECONDS
	addtimer(CALLBACK(src, PROC_REF(show_shadow)), max(0, until_touchdown - LANDING_SHADOW_LEAD), TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(show_proxies)), max(0, until_touchdown - LANDING_PROXY_LEAD), TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(watch)), 0.5 SECONDS, TIMER_DELETE_ME | TIMER_LOOP)

/datum/landing_animation/Destroy(force)
	QDEL_NULL(shadow)
	for(var/client/crew_client as anything in hidden_from)
		crew_client?.images -= hidden_from[crew_client]
	hidden_from = null
	QDEL_NULL(proxy)
	hull_turfs = null
	berth_turfs = null
	if(ship?.landing_animation == src)
		ship.landing_animation = null
	ship = null
	return ..()

/// Ends the descent when the dock it belongs to is no longer happening
/datum/landing_animation/proc/watch()
	if(landed)
		return
	var/obj/structure/overmap/site = site_ref?.resolve()
	if(QDELETED(ship) || QDELETED(ship.shuttle) || !site || ship.state != OVERMAP_SHIP_DOCKING || ship.docked != site || world.time > give_up_time)
		qdel(src)

/// The hull has started to move onto the berth: the picture is on the ground now, and stays put.
/datum/landing_animation/proc/freeze()
	if(frozen)
		return
	frozen = TRUE
	if(shadow) // under the hull now; let its blurred rim go gently
		animate(shadow, alpha = 0, time = 0.4 SECONDS)
		QDEL_IN(shadow, 0.4 SECONDS)
		shadow = null
	if(proxy)
		animate(proxy, pixel_z = 0, time = 0.2 SECONDS, easing = QUAD_EASING | EASE_IN)
		var/list/aboard = list()
		for(var/turf/hull_turf as anything in hull_turfs)
			aboard[hull_turf] = TRUE
		// every player aboard, ghosts included (they are not in SSmobs.clients_by_zlevel)
		for(var/mob/crew as anything in GLOB.player_list)
			if(!crew.client || !aboard[get_turf(crew)])
				continue
			var/image/hide = image(loc = proxy)
			hide.override = TRUE
			crew.client.images += hide
			hidden_from[crew.client] = hide

/// The hull is down. The picture covers it a moment longer while its lighting is rebuilt, then goes.
/datum/landing_animation/proc/landed()
	if(ship?.landing_animation == src)
		ship.landing_animation = null
	landed = TRUE
	addtimer(CALLBACK(src, PROC_REF(fade_out)), LANDING_LIGHTING_SETTLE, TIMER_DELETE_ME)

/// The real hull is lit again: the picture gives way to it
/datum/landing_animation/proc/fade_out()
	if(proxy)
		animate(proxy, alpha = 0, time = LANDING_PICTURE_FADE)
	// a hard reference: QDEL_IN keeps only a weakref past a second, and nothing else holds this datum by now
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), LANDING_PICTURE_FADE)

/datum/landing_animation/proc/show_shadow()
	if(!length(berth_turfs) || frozen)
		return
	shadow = new(berth_turfs[1])
	if(!shadow.outline(berth_turfs))
		QDEL_NULL(shadow)
		return
	// engines heard on the ground before the ship is in sight; the crew aboard hear nothing new
	landing_jolt(berth_turfs, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 25, reach = LANDING_HEAR_RANGE)
	var/time_left = max(1, touchdown_time - world.time)
	var/fade_in = min(1.5 SECONDS, time_left / 4)
	var/spread_end = max(0, time_left - LANDING_PROXY_LEAD - fade_in)
	shadow.transform = matrix().Scale(LANDING_SHADOW_WIDE)
	animate(shadow, alpha = LANDING_SHADOW_FAINT, time = fade_in)
	animate(time = max(1, spread_end))
	animate(transform = matrix().Scale(LANDING_SHADOW_NEAR), alpha = 80, time = min(LANDING_PROXY_LEAD, time_left) * 2 / 3, easing = SINE_EASING)
	animate(transform = matrix(), alpha = LANDING_SHADOW_DARK, time = min(LANDING_PROXY_LEAD, time_left) / 3, easing = SINE_EASING | EASE_OUT)

/datum/landing_animation/proc/show_proxies()
	if(!length(hull_turfs) || frozen)
		return
	proxy = new(berth_turfs[1])
	if(!proxy.picture(hull_turfs, berth_turfs, rotation))
		QDEL_NULL(proxy)
		return
	var/time_left = max(1, touchdown_time - world.time)
	var/high_part = time_left * 2 / 3
	proxy.pixel_z = LANDING_PROXY_START_HEIGHT
	animate(proxy, pixel_z = LANDING_PROXY_FINAL_HEIGHT, time = high_part, easing = QUAD_EASING | EASE_OUT)
	// it hovers just off the ground until the move actually starts, which is when it touches down
	animate(pixel_z = LANDING_PROXY_HOVER, time = time_left - high_part, easing = SINE_EASING | EASE_OUT)

/**
 * # Takeoff
 *
 * The hull has just left the berth for transit. A picture of it lifts off level on its thrusters, blowing dust
 * out from under its engine end, pitches its nose up and flies off toward its bow, solid all the way, until it
 * is off the screen. Its shadow stays on the berth, then slides after it and pales. Then everything deletes
 * itself.
 */
/datum/launch_animation
	var/obj/effect/abstract/landing_shadow/shadow
	/// The leaving hull
	var/obj/effect/abstract/landing_proxy/proxy
	/// The berth turfs the hull is leaving
	var/list/berth_turfs
	/// The way the ship's bow points (a cardinal): away from its engines
	var/bow_dir = NORTH

/// Built just before [shuttle] leaves [hull_turfs]: a picture of it, standing on it
/datum/launch_animation/New(list/hull_turfs, obj/docking_port/mobile/shuttle)
	. = ..()
	berth_turfs = hull_turfs
	if(!length(hull_turfs))
		return
	bow_dir = landing_bow_dir(shuttle, hull_turfs)
	proxy = new(hull_turfs[1])
	if(!proxy.picture(hull_turfs, hull_turfs))
		QDEL_NULL(proxy)

/// The hull is gone (it now stands on [hull_turfs], in transit): the picture flies off and its shadow follows
/datum/launch_animation/proc/lift_off(list/hull_turfs)
	if(!proxy)
		qdel(src)
		return
	var/bow_x = (bow_dir & EAST) ? 1 : ((bow_dir & WEST) ? -1 : 0)
	var/bow_y = (bow_dir & NORTH) ? 1 : ((bow_dir & SOUTH) ? -1 : 0)
	// the hull's length along its bow, for how far it has to fly
	var/min_along = INFINITY
	var/max_along = -INFINITY
	for(var/turf/berth_turf as anything in berth_turfs)
		var/along = berth_turf.x * bow_x + berth_turf.y * bow_y
		min_along = min(min_along, along)
		max_along = max(max_along, along)
	var/length_tiles = max_along - min_along + 1
	// The nose comes up as an angle: the whole hull turns, rigid, so its bow swings toward the top of the
	// screen (a ship pointing up or down the screen turns clockwise). Turn() is clockwise.
	var/angle = bow_x ? -bow_x * LAUNCH_TILT_ANGLE : LAUNCH_TILT_ANGLE
	var/matrix/tilted = matrix()
	tilted.Scale(LAUNCH_TILT_SCALE)
	tilted.Turn(angle)
	var/matrix/leaving = matrix()
	leaving.Scale(LAUNCH_GO_SCALE)
	leaving.Turn(angle)
	// it flies where its nose points: the bow direction turned by the same angle
	var/head_x = bow_x * cos(angle) + bow_y * sin(angle)
	var/head_y = -bow_x * sin(angle) + bow_y * cos(angle)
	var/fly = (length_tiles + LAUNCH_GO_TILES) * ICON_SIZE_X
	// 1. level lift on the thrusters
	animate(proxy, pixel_z = LAUNCH_LIFT_HEIGHT, time = LAUNCH_LIFT_TIME, easing = SINE_EASING | EASE_OUT)
	// 2. nose up, creeping toward the bow
	animate(transform = tilted, pixel_w = round(head_x * LAUNCH_TILT_CREEP), pixel_z = LAUNCH_TILT_HEIGHT + round(head_y * LAUNCH_TILT_CREEP), time = LAUNCH_TILT_TIME, easing = SINE_EASING)
	// 3. off the way it points, still climbing; solid until it is gone from view
	animate(transform = leaving, pixel_w = round(head_x * fly), pixel_z = LAUNCH_GO_HEIGHT + round(head_y * fly), time = LAUNCH_GO_TIME, easing = QUAD_EASING | EASE_IN)
	landing_wash(berth_turfs, bow_dir)
	landing_jolt(berth_turfs, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 70, reach = LANDING_HEAR_RANGE, shake_strength = LANDING_SHAKE)
	landing_jolt(hull_turfs, 'voidcrew/sound/machines/rocket/rocket_launch.ogg', 50, shake_strength = LANDING_SHAKE)
	shadow = new(berth_turfs[1])
	if(shadow.outline(berth_turfs))
		var/slide = LAUNCH_SHADOW_SLIDE_TILES * ICON_SIZE_X
		shadow.alpha = LANDING_SHADOW_DARK
		// stays on the berth while the ship hangs over it, then slides after it and pales
		animate(shadow, time = LAUNCH_LIFT_TIME)
		var/matrix/shadow_turn = matrix()
		shadow_turn.Turn(angle)
		animate(transform = shadow_turn, pixel_w = round(head_x * LAUNCH_TILT_CREEP), pixel_z = round(head_y * LAUNCH_TILT_CREEP), time = LAUNCH_TILT_TIME, easing = SINE_EASING)
		animate(pixel_w = round(head_x * slide), pixel_z = round(head_y * slide), time = LAUNCH_GO_TIME, easing = QUAD_EASING | EASE_IN)
		// pales on its own curve, from the moment the nose comes up, so it is gone before the ship is
		animate(shadow, time = LAUNCH_LIFT_TIME, flags = ANIMATION_PARALLEL)
		animate(alpha = 0, time = LAUNCH_TILT_TIME + LAUNCH_GO_TIME * 0.6, easing = SINE_EASING)
	else
		QDEL_NULL(shadow)
	// a hard reference: QDEL_IN keeps only a weakref past a second, and nothing else holds this datum, so it
	// would be garbage collected without Destroy() and leave its picture and shadow on the map
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), LAUNCH_LIFT_TIME + LAUNCH_TILT_TIME + LAUNCH_GO_TIME + 0.2 SECONDS)

/**
 * The way a hull's bow points: away from the middle of its engines, as a cardinal. A hull with no engines, or
 * engines dead in its middle, leaves straight up the screen.
 */
/proc/landing_bow_dir(obj/docking_port/mobile/shuttle, list/hull_turfs)
	if(!shuttle || !length(shuttle.engine_list) || !length(hull_turfs))
		return NORTH
	var/hull_x = 0
	var/hull_y = 0
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_x += hull_turf.x
		hull_y += hull_turf.y
	hull_x /= length(hull_turfs)
	hull_y /= length(hull_turfs)
	var/engine_x = 0
	var/engine_y = 0
	var/engines = 0
	for(var/obj/machinery/power/shuttle_engine/engine as anything in shuttle.engine_list)
		var/turf/engine_turf = get_turf(engine)
		if(!engine_turf || engine_turf.z != hull_turfs[1].z)
			continue
		engine_x += engine_turf.x
		engine_y += engine_turf.y
		engines++
	if(!engines)
		return NORTH
	var/away_x = hull_x - engine_x / engines
	var/away_y = hull_y - engine_y / engines
	if(abs(away_x) < 0.5 && abs(away_y) < 0.5)
		return NORTH
	if(abs(away_x) > abs(away_y))
		return away_x > 0 ? EAST : WEST
	return away_y > 0 ? NORTH : SOUTH

/// Thruster wash: a few waves of dust blown out from under a lifting hull, most of it at its engine end
/proc/landing_wash(list/hull_turfs, bow_dir)
	landing_wash_wave(hull_turfs, bow_dir)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(landing_wash_wave), hull_turfs.Copy(), bow_dir), 0.35 SECONDS)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(landing_wash_wave), hull_turfs.Copy(), bow_dir), 0.7 SECONDS)

/proc/landing_wash_wave(list/hull_turfs, bow_dir)
	var/bow_x = (bow_dir & EAST) ? 1 : ((bow_dir & WEST) ? -1 : 0)
	var/bow_y = (bow_dir & NORTH) ? 1 : ((bow_dir & SOUTH) ? -1 : 0)
	var/list/hull_set = list()
	var/min_along = INFINITY
	var/max_along = -INFINITY
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_set[hull_turf] = TRUE
		var/along = hull_turf.x * bow_x + hull_turf.y * bow_y
		min_along = min(min_along, along)
		max_along = max(max_along, along)
	var/span = max(1, max_along - min_along)
	var/puffs = 0
	for(var/turf/hull_turf as anything in shuffle(hull_turfs.Copy()))
		if(puffs >= LAUNCH_WASH_PER_WAVE)
			break
		// 0 at the bow, 1 at the engines
		var/engine_end = (max_along - (hull_turf.x * bow_x + hull_turf.y * bow_y)) / span
		if(!prob(LAUNCH_WASH_CHANCE * engine_end * engine_end))
			continue
		for(var/edge_dir in shuffle(GLOB.cardinals.Copy()))
			if(edge_dir == bow_dir)
				continue
			var/turf/outside = get_step(hull_turf, edge_dir)
			if(!outside || hull_set[outside] || isclosedturf(outside))
				continue
			new /obj/effect/temp_visual/landing_dust(outside, edge_dir, LAUNCH_WASH_PUSH)
			puffs++
			break

/datum/launch_animation/Destroy(force)
	QDEL_NULL(shadow)
	QDEL_NULL(proxy)
	berth_turfs = null
	return ..()

#undef LANDING_PROXY_LEAD
#undef LANDING_SHADOW_LEAD
#undef LANDING_PROXY_START_HEIGHT
#undef LANDING_PROXY_FINAL_HEIGHT
#undef LAUNCH_LIFT_TIME
#undef LAUNCH_TILT_TIME
#undef LAUNCH_GO_TIME
#undef LAUNCH_LIFT_HEIGHT
#undef LAUNCH_TILT_HEIGHT
#undef LAUNCH_GO_HEIGHT
#undef LAUNCH_TILT_ANGLE
#undef LAUNCH_TILT_SCALE
#undef LAUNCH_TILT_CREEP
#undef LAUNCH_GO_SCALE
#undef LAUNCH_GO_TILES
#undef LAUNCH_SHADOW_SLIDE_TILES
#undef LAUNCH_WASH_PER_WAVE
#undef LAUNCH_WASH_CHANCE
#undef LAUNCH_WASH_PUSH
#undef LANDING_SHADOW_WIDE
#undef LANDING_SHADOW_NEAR
#undef LANDING_SHADOW_FAINT
#undef LANDING_SHADOW_DARK
#undef LANDING_PROXY_TURF_LAYER
#undef LANDING_PROXY_LIGHT_LAYER
#undef LANDING_SHADOW_LAYER
#undef LANDING_LIGHTING_SETTLE
#undef LANDING_PROXY_HOVER
#undef LANDING_PICTURE_FADE
#undef LANDING_DUST_CHANCE
#undef LANDING_DUST_MAX
#undef LANDING_SHAKE
#undef LANDING_HEAR_RANGE
