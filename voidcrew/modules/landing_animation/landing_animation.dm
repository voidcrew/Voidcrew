/**
 * # Planet landing and takeoff visuals
 *
 * Seen from the ground, a ship docking on a planet used to pop onto its berth. Now a soft shadow of the hull
 * spreads over the berth during the dock warmup, then the ship itself drops out of the sky and the real hull
 * replaces it the moment it lands. Takeoff runs the same in reverse.
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
/// How long a takeoff takes to climb out of sight
#define LAUNCH_CLIMB_TIME (4.5 SECONDS)
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
/// How long the picture covers a landed hull while its lighting is rebuilt
#define LANDING_LIGHTING_SETTLE (2 SECONDS)
/// Chance an edge tile kicks up a puff of dust, and the most puffs one landing makes
#define LANDING_DUST_CHANCE 30
#define LANDING_DUST_MAX 18
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
		landing_jolt(pairs[1], null, 0, shake_strength = 0.2)
	else if(ship.state == OVERMAP_SHIP_UNDOCKING && old_dock && !istype(old_dock, /obj/docking_port/stationary/transit) && istype(new_dock, /obj/docking_port/stationary/transit) && landing_animation_wanted(ship.undock_origin?.resolve()))
		launch = new(landing_hull_pairs(src, new_dock)[1])
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
	landing_jolt(hull_turfs, 'sound/effects/meteorimpact.ogg', 60, reach = LANDING_HEAR_RANGE, shake_strength = 0.2)

/**
 * Shakes the camera of, and plays [sound_file] to, every player on [hull_turfs] and, with [reach], everyone within
 * that many tiles of the hull on the same level.
 */
/proc/landing_jolt(list/hull_turfs, sound_file, volume, reach = 0, shake_time = 3, shake_strength = 0)
	return // BLOCKING-GATE
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
	for(var/mob/listener as anything in SSmobs.clients_by_zlevel[first.z])
		var/turf/where = get_turf(listener)
		if(!where)
			continue
		if(!hull_set[where] && (!reach || where.x < min_x - reach || where.x > max_x + reach || where.y < min_y - reach || where.y > max_y + reach))
			continue
		if(shake_strength)
			shake_camera(listener, shake_time, shake_strength)
		if(sound_file)
			listener.playsound_local(hull_set[where] ? where : middle, sound_file, volume, TRUE, pressure_affected = FALSE, max_distance = reach + max(max_x - min_x, max_y - min_y))

/// A few light puffs of dust kicked out from the hull's edges
/proc/landing_dust(list/hull_turfs)
	return // BLOCKING-GATE
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
	var/list/parts = list()
	for(var/i in 1 to length(places))
		var/turf/source = sources[i]
		var/turf/place = places[i]
		var/offset_w = (place.x - anchor.x) * ICON_SIZE_X
		var/offset_z = (place.y - anchor.y) * ICON_SIZE_Y
		var/mutable_appearance/floor = new(source)
		floor.underlays = list() // its lighting; drawn below as a multiply over the whole tile
		floor.plane = FLOAT_PLANE
		floor.layer = LANDING_PROXY_TURF_LAYER
		floor.pixel_w += offset_w
		floor.pixel_z += offset_z
		if(turn)
			floor.transform = turn
		parts += floor
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
			parts += part
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

/obj/effect/temp_visual/landing_dust/Initialize(mapload, push_dir = NORTH)
	. = ..()
	SET_PLANE_IMPLICIT(src, ABOVE_LIGHTING_PLANE)
	var/drift = rand(14, 28)
	var/drift_w = (push_dir & EAST) ? drift : ((push_dir & WEST) ? -drift : rand(-6, 6))
	var/drift_z = (push_dir & NORTH) ? drift : ((push_dir & SOUTH) ? -drift : rand(-6, 6))
	transform = matrix().Scale(0.45)
	animate(src, alpha = rand(60, 95), transform = matrix().Scale(0.7), time = 0.3 SECONDS, easing = SINE_EASING | EASE_OUT)
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
	QDEL_NULL(shadow)
	if(proxy)
		animate(proxy)
		proxy.pixel_z = 0

/// The hull is down. The picture covers it a moment longer while its lighting is rebuilt, then goes.
/datum/landing_animation/proc/landed()
	if(ship?.landing_animation == src)
		ship.landing_animation = null
	landed = TRUE
	QDEL_IN(src, LANDING_LIGHTING_SETTLE)

/datum/landing_animation/proc/show_shadow()
	if(!length(berth_turfs) || frozen)
		return
	shadow = new(berth_turfs[1])
	if(!shadow.outline(berth_turfs))
		QDEL_NULL(shadow)
		return
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
	animate(pixel_z = 0, time = time_left - high_part, easing = SINE_EASING | EASE_OUT)

/**
 * # Takeoff
 *
 * The hull has just left the berth for transit. A proxy of it climbs from the berth and fades while its
 * shadow spreads and pales, then everything deletes itself.
 */
/datum/launch_animation
	var/obj/effect/abstract/landing_shadow/shadow
	/// The climbing hull
	var/obj/effect/abstract/landing_proxy/proxy
	/// The berth turfs the hull is leaving
	var/list/berth_turfs

/// Built just before the hull leaves [hull_turfs]: a picture of it, standing on it
/datum/launch_animation/New(list/hull_turfs)
	. = ..()
	berth_turfs = hull_turfs
	if(!length(hull_turfs))
		return
	proxy = new(hull_turfs[1])
	if(!proxy.picture(hull_turfs, hull_turfs))
		QDEL_NULL(proxy)

/// The hull is gone (it now stands on [hull_turfs], in transit): the picture climbs away and its shadow
/// spreads and fades
/datum/launch_animation/proc/lift_off(list/hull_turfs)
	if(!proxy)
		qdel(src)
		return
	animate(proxy, pixel_z = LANDING_PROXY_START_HEIGHT, time = LAUNCH_CLIMB_TIME, easing = QUAD_EASING | EASE_IN)
	shadow = new(berth_turfs[1])
	if(shadow.outline(berth_turfs))
		shadow.alpha = LANDING_SHADOW_DARK
		animate(shadow, transform = matrix().Scale(LANDING_SHADOW_WIDE), alpha = 0, time = LAUNCH_CLIMB_TIME, easing = SINE_EASING | EASE_IN)
	else
		QDEL_NULL(shadow)
	QDEL_IN(src, LAUNCH_CLIMB_TIME + 0.5 SECONDS)

/datum/launch_animation/Destroy(force)
	QDEL_NULL(shadow)
	QDEL_NULL(proxy)
	berth_turfs = null
	return ..()

#undef LANDING_PROXY_LEAD
#undef LANDING_SHADOW_LEAD
#undef LANDING_PROXY_START_HEIGHT
#undef LANDING_PROXY_FINAL_HEIGHT
#undef LAUNCH_CLIMB_TIME
#undef LANDING_SHADOW_WIDE
#undef LANDING_SHADOW_NEAR
#undef LANDING_SHADOW_FAINT
#undef LANDING_SHADOW_DARK
#undef LANDING_PROXY_TURF_LAYER
#undef LANDING_PROXY_LIGHT_LAYER
#undef LANDING_SHADOW_LAYER
#undef LANDING_LIGHTING_SETTLE
#undef LANDING_DUST_CHANCE
#undef LANDING_DUST_MAX
#undef LANDING_HEAR_RANGE
