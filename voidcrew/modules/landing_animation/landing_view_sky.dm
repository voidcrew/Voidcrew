/**
 * What the landing view is made of, for a descent and a climb alike: a planet's colours, the planet itself,
 * its clouds, the hull's shadow, and the heat on the hull's edge.
 */

/**
 * The colours of a planet seen from above. The planet texture holds three kinds of surface; each gets a colour.
 */
/datum/landing_view_palette
	/// The two kinds of land
	var/surface_a = "#b0a48c"
	var/surface_b = "#8c8474"
	/// What lies between: sea, lava, ice
	var/surface_c = "#5a6a7a"
	var/cloud = "#f2f2f2"
	/// The glow of air around the planet's rim
	var/air = "#b8d4f0"
	/// The sky from inside it, and the haze over the ground
	var/sky = "#9db4cc"
	/// The hull's glow on the way in
	var/heat = "#ffa64d"

/datum/landing_view_palette/beach
	surface_a = "#d9c48a"
	surface_b = "#5f9a4c"
	surface_c = "#1f6fb0"
	cloud = "#ffffff"
	air = "#8fc8ff"
	sky = "#7fb4e6"

/datum/landing_view_palette/jungle
	surface_a = "#2f6b2c"
	surface_b = "#6da043"
	surface_c = "#1d4a3a"
	cloud = "#f4fbf0"
	air = "#a5e0c0"
	sky = "#86c7b0"

/datum/landing_view_palette/ice
	surface_a = "#eef4fa"
	surface_b = "#b9d3e8"
	surface_c = "#5b88b5"
	cloud = "#ffffff"
	air = "#cfe6ff"
	sky = "#bcd6ee"

/datum/landing_view_palette/lava
	surface_a = "#3a2c2a"
	surface_b = "#5d4a44"
	surface_c = "#ff6a1a"
	cloud = "#6b5b57"
	air = "#ff9a5a"
	sky = "#7a4a3c"
	heat = "#ff8a3c"

/datum/landing_view_palette/wasteland
	surface_a = "#b59a6a"
	surface_b = "#7a6a4e"
	surface_c = "#5d7a3a"
	cloud = "#d9c9a0"
	air = "#e0c890"
	sky = "#c9b98a"

/// The palette for [site], by the kind of planet it is
/proc/landing_view_palette_for(obj/structure/overmap/planet/site)
	var/static/list/by_planet = list(
		/datum/overmap/planet/beach = /datum/landing_view_palette/beach,
		/datum/overmap/planet/jungle = /datum/landing_view_palette/jungle,
		/datum/overmap/planet/ice = /datum/landing_view_palette/ice,
		/datum/overmap/planet/lava = /datum/landing_view_palette/lava,
		/datum/overmap/planet/wasteland = /datum/landing_view_palette/wasteland,
	)
	var/palette_type = (istype(site) && site.planet) ? by_planet[site.planet] : null
	palette_type ||= /datum/landing_view_palette
	return new palette_type

/// The colour matrix that paints the planet texture's three surfaces in our colours
/datum/landing_view_palette/proc/surface_matrix()
	var/list/first = rgb2num(surface_a)
	var/list/second = rgb2num(surface_b)
	var/list/third = rgb2num(surface_c)
	return list(
		first[1] / 255, first[2] / 255, first[3] / 255, 0,
		second[1] / 255, second[2] / 255, second[3] / 255, 0,
		third[1] / 255, third[2] / 255, third[3] / 255, 0,
		0, 0, 0, 1,
		0, 0, 0, 0,
	)

/**
 * The planet seen whole: surface, cloud and shading drawn as one ball. Returns two pieces showing the same
 * ball: the whole of it, and its middle at twice the grain for when it fills the screen. Give both to
 * chain_detail() with the size track of the first.
 */
/datum/landing_view/proc/new_planet()
	var/list/pieces = list()
	for(var/grain in list("planet", "planet_near"))
		var/datum/landing_view_piece/planet = add_sky(LANDING_VIEW_LAYER_PLANET + length(pieces) * 0.01, LANDING_VIEW_ICON, grain, LANDING_VIEW_ICON_SIZE)
		var/atom/movable/screen/landing_view_sky/ball = planet.sky
		var/mutable_appearance/surface = mutable_appearance(LANDING_VIEW_ICON, grain, appearance_flags = RESET_COLOR)
		surface.color = palette.surface_matrix()
		var/mutable_appearance/cloud = mutable_appearance(LANDING_VIEW_ICON, "[grain]_clouds", appearance_flags = RESET_COLOR)
		cloud.color = palette.cloud
		var/mutable_appearance/shade = mutable_appearance(LANDING_VIEW_ICON, "[grain]_shade", appearance_flags = RESET_COLOR)
		shade.blend_mode = BLEND_MULTIPLY
		ball.icon_state = "blank"
		ball.appearance_flags |= KEEP_TOGETHER
		ball.overlays = list(surface, cloud, shade)
		if(length(pieces))
			planet.scale = pieces[1].scale
			planet.slide_x = pieces[1].slide_x
			planet.slide_y = pieces[1].slide_y
			planet.scale_factor = 0.5
		pieces += planet
	return pieces

/**
 * A deck of cloud seen from above, in the planet's cloud colour. Returns three pieces showing the same clouds,
 * each at twice the grain of the one before. Give them to chain_detail() with the size track of the first.
 */
/datum/landing_view/proc/new_clouds()
	var/list/pieces = list()
	for(var/grain in list("clouds_far", "clouds_mid", "clouds_near"))
		var/datum/landing_view_piece/clouds = add_sky(LANDING_VIEW_LAYER_CLOUD + length(pieces) * 0.01, LANDING_VIEW_ICON, grain, LANDING_VIEW_ICON_SIZE)
		clouds.sky.color = palette.cloud
		if(length(pieces))
			clouds.scale = pieces[1].scale
			clouds.slide_x = pieces[1].slide_x
			clouds.slide_y = pieces[1].slide_y
			clouds.scale_factor = 0.5 ** length(pieces)
		pieces += clouds
	return pieces

/**
 * Sets the opacity of [pieces], which show one thing at finer and finer grain, so that as it grows each closer-up
 * texture fades in over the one before, which is then dropped; and the other way about as it shrinks. A texture
 * is never stretched far, and the picture never thins in the changeover, because the one underneath stays whole
 * until the one on top has covered it.
 * * size - the size track of the first piece
 * * opacity - how opaque the whole thing is over time (0-255)
 * * switches - one list(from, to) per changeover: the sizes of the first piece between which the next takes over
 */
/datum/landing_view/proc/chain_detail(list/datum/landing_view_piece/pieces, datum/landing_track/size, datum/landing_track/opacity, list/switches)
	var/start = min(size.times[1], opacity.times[1])
	var/finish = max(size.end_time(), opacity.end_time())
	for(var/moment = start, moment < finish + 2, moment += 2)
		var/when = min(moment, finish)
		var/now_size = size.at(when)
		var/now_opacity = opacity.at(when)
		for(var/i in 1 to length(pieces))
			var/share = 1
			if(i > 1)
				var/list/rising = switches[i - 1]
				share = clamp((now_size - rising[1]) / (rising[2] - rising[1]), 0, 1)
			if(i < length(pieces))
				var/list/falling = switches[i]
				if(now_size >= falling[2])
					share = 0
			pieces[i].alpha.mark(when, now_opacity * share)
	for(var/datum/landing_view_piece/piece as anything in pieces)
		show(piece)

/// The glow of air around [planet]'s rim, growing and shrinking with it
/datum/landing_view/proc/new_air(datum/landing_view_piece/planet)
	var/datum/landing_view_piece/air = add_sky(LANDING_VIEW_LAYER_AIR, LANDING_VIEW_ICON, "planet_air", LANDING_VIEW_ICON_SIZE)
	air.sky.color = palette.air
	air.scale = planet.scale
	air.slide_x = planet.slide_x
	air.slide_y = planet.slide_y
	return air

/// The hull's outline in soft black, as one part of a world picture drawn about [mid_x], [mid_y]
/proc/landing_view_shadow_look(list/hull_turfs, mid_x, mid_y)
	var/list/squares = list()
	for(var/turf/hull_turf as anything in hull_turfs)
		var/mutable_appearance/square = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
		square.color = COLOR_BLACK
		square.pixel_w = (hull_turf.x - mid_x) * ICON_SIZE_X
		square.pixel_z = (hull_turf.y - mid_y) * ICON_SIZE_Y
		squares += square
	var/mutable_appearance/look = landing_view_world_look(new /mutable_appearance, LANDING_VIEW_LAYER_SHADOW)
	look.appearance_flags = KEEP_TOGETHER
	look.overlays = squares
	look.filters = gauss_blur_filter(size = 12)
	return look

/**
 * The hull's edge glows from [start] to [end] (world.time): a tile of glow, shedding sparks, on every tile of
 * transit space that touches the hull.
 */
/datum/landing_view/proc/heat_hull(start, end)
	if(ended)
		return
	if(world.time < start)
		addtimer(CALLBACK(src, PROC_REF(heat_hull), start, end), start - world.time, TIMER_DELETE_ME)
		return
	var/burn = end - world.time
	if(burn < 1 SECONDS)
		return
	for(var/x in low_x to high_x)
		for(var/y in low_y to high_y)
			var/turf/spot = locate(x, y, transit_z)
			if(!spot || hull_set[spot])
				continue
			var/list/sides = list()
			var/hull_dirs = NONE
			for(var/side in GLOB.cardinals)
				if(hull_set[get_step(spot, side)])
					hull_dirs |= side
					sides += mutable_appearance('voidcrew/icons/effects/landing_view_glow.dmi', "glow_[landing_view_side_name(side)]")
			for(var/corner in GLOB.diagonals)
				// a corner only where the hull is not already alongside
				if((hull_dirs & corner) || !hull_set[get_step(spot, corner)])
					continue
				sides += mutable_appearance('voidcrew/icons/effects/landing_view_glow.dmi', "glow_[landing_view_side_name(corner)]")
			if(!length(sides))
				continue
			var/obj/effect/abstract/landing_heat/glow = new(spot)
			glow.color = palette.heat
			glow.overlays = sides
			if(hull_dirs)
				glow.throw_sparks(hull_dirs)
			props += glow
			var/peak = rand(200, 255)
			animate(glow, alpha = peak, time = 0.8 SECONDS, easing = SINE_EASING)
			for(var/i in 1 to round((burn - 1.8 SECONDS) / 3))
				animate(alpha = peak * rand(55, 100) / 100, time = rand(1, 2))
				animate(alpha = peak, time = rand(1, 2))
			animate(alpha = 0, time = 1 SECONDS, easing = SINE_EASING)
			QDEL_IN(glow, burn + 0.5 SECONDS)

/proc/landing_view_side_name(side)
	switch(side)
		if(NORTH)
			return "n"
		if(SOUTH)
			return "s"
		if(EAST)
			return "e"
		if(WEST)
			return "w"
		if(NORTHEAST)
			return "ne"
		if(NORTHWEST)
			return "nw"
		if(SOUTHEAST)
			return "se"
		if(SOUTHWEST)
			return "sw"

/// One tile of the hull's glow on the way down, standing in transit space against the hull
/obj/effect/abstract/landing_heat
	name = ""
	icon = 'voidcrew/icons/effects/landing_view_glow.dmi'
	icon_state = ""
	anchored = TRUE
	density = FALSE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// the floor plane, under anything adrift there; transit space is lit throughout
	plane = FLOOR_PLANE
	layer = TOPDOWN_LAYER + 0.5
	alpha = 0
	vis_flags = NONE

/obj/effect/abstract/landing_heat/Initialize(mapload)
	. = ..()
	SET_PLANE_IMPLICIT(src, FLOOR_PLANE)

/// Sparks torn off the hull's edge, flying out away from the hull (which lies to our [hull_dirs])
/obj/effect/abstract/landing_heat/proc/throw_sparks(hull_dirs)
	var/static/list/sparks_by_dir = list()
	var/away = REVERSE_DIR(hull_dirs & (NORTH | SOUTH)) | REVERSE_DIR(hull_dirs & (EAST | WEST))
	// hull on both sides of an axis: nowhere to fly on that axis
	if((hull_dirs & (NORTH | SOUTH)) == (NORTH | SOUTH))
		away &= ~(NORTH | SOUTH)
	if((hull_dirs & (EAST | WEST)) == (EAST | WEST))
		away &= ~(EAST | WEST)
	if(!away)
		return
	var/particles/landing_sparks/sparks = sparks_by_dir["[away]"]
	if(!sparks)
		sparks = new
		var/fly_x = (away & EAST) ? 1 : ((away & WEST) ? -1 : 0)
		var/fly_y = (away & NORTH) ? 1 : ((away & SOUTH) ? -1 : 0)
		sparks.velocity = generator(GEN_BOX, list(fly_x * 8 - 2, fly_y * 8 - 2, 0), list(fly_x * 16 + 2, fly_y * 16 + 2, 0), UNIFORM_RAND)
		// born along the edge that touches the hull
		sparks.position = generator(GEN_BOX, list(fly_x ? -fly_x * 14 : -16, fly_y ? -fly_y * 14 : -16, 0), list(fly_x ? -fly_x * 10 : 16, fly_y ? -fly_y * 10 : 16, 0), UNIFORM_RAND)
		sparks_by_dir["[away]"] = sparks
	particles = sparks

/particles/landing_sparks
	icon = 'icons/effects/particles/generic.dmi'
	icon_state = list("dot" = 5, "cross" = 1)
	width = 224
	height = 224
	count = 12
	spawning = 2.2
	lifespan = 0.7 SECONDS
	fade = 0.5 SECONDS
	fadein = 1
	color = 0
	color_change = 0.12
	gradient = list("#fff3c4", "#ffb347", "#ff5a1c")
	scale = generator(GEN_VECTOR, list(0.6, 0.6), list(1.4, 1.4), NORMAL_RAND)
	spin = generator(GEN_NUM, -20, 20)

/// Plays [sound_file] to, and shakes the camera of, everyone watching, at [time]
/datum/landing_view/proc/cue_at(time, sound_file, volume, shake_time = 0, shake_strength = 0)
	if(time < world.time - 1 SECONDS)
		return
	addtimer(CALLBACK(src, PROC_REF(cue), sound_file, volume, shake_time, shake_strength), max(0, time - world.time), TIMER_DELETE_ME)

/datum/landing_view/proc/cue(sound_file, volume, shake_time, shake_strength)
	if(ended)
		return
	for(var/client/watcher as anything in viewers)
		var/mob/listener = watcher?.mob
		if(!listener)
			continue
		if(sound_file)
			listener.playsound_local(get_turf(listener), sound_file, volume, FALSE, pressure_affected = FALSE, use_reverb = FALSE)
		if(shake_time)
			shake_camera(listener, shake_time, shake_strength)

/**
 * The twin, beside the hull in transit, of a puff of dust thrown on the planet from the [edge_dir] side of the
 * berth tile that pairs with [hull_turf].
 */
/datum/landing_view/proc/twin_dust(turf/hull_turf, edge_dir, push, list/shape)
	if(ended || !hull_turf)
		return
	// the same side of the same hull tile, as the hull lies in transit
	var/transit_dir = rotation ? turn(edge_dir, rotation) : edge_dir
	var/turf/transit_outside = get_step(hull_turf, transit_dir)
	if(transit_outside && !hull_set[transit_outside])
		props += new /obj/effect/temp_visual/landing_dust(transit_outside, transit_dir, push, shape)
