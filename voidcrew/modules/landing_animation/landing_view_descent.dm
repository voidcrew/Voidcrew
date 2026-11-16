/**
 * # The descent, seen from aboard
 *
 * Laid out against the moment the hull is expected to touch down (T), in the order a falling ship meets things:
 *
 * | from     | what                                                                                    |
 * |----------|-----------------------------------------------------------------------------------------|
 * | start    | the planet, whole, swelling under the ship until its rim has left the screen            |
 * | T-9.2s   | heat: the hull's edge glows and sheds sparks, streaks fly out past it                    |
 * | T-8.4s   | the planet thins into the colour of its own sky                                          |
 * | T-7.4s   | a deck of cloud comes up from below, then the ship is in it: everything white           |
 * | T-5.2s   | out of the cloud's underside over the real ground, small and hazy, rushing up            |
 * | T-1.4s   | the thrusters reach the ground: dust blows out from under the hull                       |
 * | T-0.8s   | the ground is at full size; the ship hangs on its thrusters until the hull really moves |
 *
 * The ground is the real terrain around the berth, so when the hull moves onto it nothing outside changes.
 */

#define LANDING_VIEW_ICON 'voidcrew/icons/effects/landing_view.dmi'
#define LANDING_VIEW_ICON_SIZE 480
/// Size of the ground when it comes out of the cloud
#define DESCENT_GROUND_START 0.3
/// How far past the hull's box the ground picture reaches, and how far things on it are drawn
#define DESCENT_GROUND_REACH 34
#define DESCENT_GROUND_DETAIL 16

/// The view from aboard, for the length of this descent
/datum/landing_animation/var/datum/landing_view/descent/inside_view

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

/// The colour matrix that paints the planet texture's three surfaces in [palette]'s colours
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

/datum/landing_view/descent
	var/datum/landing_view_palette/palette
	/// world.time the hull is expected to move
	var/touchdown
	/// The real ground around the berth
	var/datum/landing_view_piece/ground
	/// The hull's shadow on it
	var/datum/landing_view_piece/shadow

/datum/landing_view/descent/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation, obj/structure/overmap/site, touchdown)
	. = ..()
	if(ended)
		return
	src.touchdown = touchdown
	palette = landing_view_palette_for(site)
	add_planet()
	add_heat()
	add_clouds()
	add_ground()
	sync_viewers()
	cue_at(touchdown - 9.2 SECONDS, 'voidcrew/sound/effects/landing/entry.ogg', 55, 3.6 SECONDS, 0.08)
	cue_at(touchdown - 6.6 SECONDS, 'voidcrew/sound/effects/landing/clouds.ogg', 45, 1.4 SECONDS, 0.05)
	cue_at(touchdown - 4.6 SECONDS, 'voidcrew/sound/effects/landing/thrusters.ogg', 50)

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

/// The planet whole, growing under the ship, then thinning into its own sky
/datum/landing_view/descent/proc/add_planet()
	var/now = world.time
	var/datum/landing_view_piece/planet = add_sky(LANDING_VIEW_LAYER_PLANET, LANDING_VIEW_ICON, "planet", LANDING_VIEW_ICON_SIZE)
	var/atom/movable/screen/landing_view_sky/ball = planet.sky
	// surface, cloud and shading drawn as one ball
	var/mutable_appearance/surface = mutable_appearance(LANDING_VIEW_ICON, "planet", appearance_flags = RESET_COLOR)
	surface.color = palette.surface_matrix()
	var/mutable_appearance/cloud = mutable_appearance(LANDING_VIEW_ICON, "planet_clouds", appearance_flags = RESET_COLOR)
	cloud.color = palette.cloud
	var/mutable_appearance/shade = mutable_appearance(LANDING_VIEW_ICON, "planet_shade", appearance_flags = RESET_COLOR)
	shade.blend_mode = BLEND_MULTIPLY
	ball.icon_state = "blank"
	ball.appearance_flags |= KEEP_TOGETHER
	ball.overlays = list(surface, cloud, shade)
	planet.scale.mark(now, 0.3)
	planet.scale.mark(touchdown - 6.2 SECONDS, 6.4, LANDING_CURVE_IN)
	planet.alpha.mark(now, 0)
	planet.alpha.mark(now + 0.6 SECONDS, 255)
	planet.alpha.mark(touchdown - 7.6 SECONDS, 255)
	planet.alpha.mark(touchdown - 6.2 SECONDS, 0)
	show(planet)

	var/datum/landing_view_piece/air = add_sky(LANDING_VIEW_LAYER_AIR, LANDING_VIEW_ICON, "planet_air", LANDING_VIEW_ICON_SIZE)
	air.sky.color = palette.air
	air.scale = planet.scale
	air.alpha.mark(now, 0)
	air.alpha.mark(now + 0.6 SECONDS, 235)
	air.alpha.mark(touchdown - 8 SECONDS, 235)
	air.alpha.mark(touchdown - 6.6 SECONDS, 0)
	show(air)

	// inside its air: the sky's own colour over everything, until the ground shows under it
	var/datum/landing_view_piece/sky = add_sky(LANDING_VIEW_LAYER_SKY, fill = palette.sky)
	sky.alpha.mark(touchdown - 8.4 SECONDS, 0)
	sky.alpha.mark(touchdown - 6.2 SECONDS, 255, LANDING_CURVE_BOTH)
	sky.alpha.mark(touchdown - 5.2 SECONDS, 255)
	sky.alpha.mark(touchdown - 4.4 SECONDS, 0)
	show(sky)

/// Heat of entry: streaks flying out past the hull, an orange cast over the sky, and the hull's edge glowing
/datum/landing_view/descent/proc/add_heat()
	var/datum/landing_view_piece/cast = add_sky(LANDING_VIEW_LAYER_HEAT, fill = palette.heat)
	cast.alpha.mark(touchdown - 9.2 SECONDS, 0)
	cast.alpha.mark(touchdown - 8.2 SECONDS, 50)
	cast.alpha.mark(touchdown - 6.6 SECONDS, 60)
	cast.alpha.mark(touchdown - 5.6 SECONDS, 0)
	show(cast)
	for(var/turned in list(0, 137))
		var/datum/landing_view_piece/streaks = add_sky(LANDING_VIEW_LAYER_HEAT + 1, LANDING_VIEW_ICON, "streaks", LANDING_VIEW_ICON_SIZE)
		streaks.sky.color = palette.heat
		streaks.turn = turned
		// they fly outward: each sheet grows, and the second follows the first so there is always one coming
		var/lead = turned ? 0.9 SECONDS : 0
		streaks.scale.mark(touchdown - 9.2 SECONDS + lead, 1.5)
		streaks.scale.mark(touchdown - 5.6 SECONDS + lead, 3.4)
		streaks.alpha.mark(touchdown - 9.2 SECONDS + lead, 0)
		streaks.alpha.mark(touchdown - 8.4 SECONDS + lead, 190)
		streaks.alpha.mark(touchdown - 6.6 SECONDS, 190)
		streaks.alpha.mark(touchdown - 5.6 SECONDS, 0)
		show(streaks)
	addtimer(CALLBACK(src, PROC_REF(heat_hull)), max(0, touchdown - 9.2 SECONDS - world.time), TIMER_DELETE_ME)

/// The hull's edge glows: a tile of glow on every tile of transit space that touches the hull
/datum/landing_view/descent/proc/heat_hull()
	if(ended)
		return
	var/burn = max(0, touchdown - 5.6 SECONDS - world.time)
	if(burn < 1 SECONDS)
		return
	for(var/x in low_x to high_x)
		for(var/y in low_y to high_y)
			var/turf/spot = locate(x, y, transit_z)
			if(!spot || hull_set[spot])
				continue
			var/obj/effect/abstract/landing_heat/glow
			var/list/sides = list()
			var/hull_dirs = NONE
			for(var/side in GLOB.cardinals)
				if(hull_set[get_step(spot, side)])
					hull_dirs |= side
					sides += mutable_appearance('voidcrew/icons/effects/landing_view_glow.dmi', "glow_[dir2text(side)[1]]")
			for(var/corner in GLOB.diagonals)
				// a corner only where the hull is not already alongside
				if((hull_dirs & corner) || !hull_set[get_step(spot, corner)])
					continue
				sides += mutable_appearance('voidcrew/icons/effects/landing_view_glow.dmi', "glow_[landing_view_corner_name(corner)]")
			if(!length(sides))
				continue
			glow = new(spot)
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

/proc/landing_view_corner_name(corner)
	switch(corner)
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

/// A deck of cloud coming up from below, the white of being inside it, and the last of it rushing past
/datum/landing_view/descent/proc/add_clouds()
	// one sheet of cloud, always bigger than the screen: small and sharp far below, huge as the ship reaches it
	var/datum/landing_view_piece/deck = add_sky(LANDING_VIEW_LAYER_CLOUD, LANDING_VIEW_ICON, "clouds_a", LANDING_VIEW_ICON_SIZE)
	deck.sky.color = palette.cloud
	deck.scale.mark(touchdown - 7.4 SECONDS, 1.8)
	deck.scale.mark(touchdown - 4.6 SECONDS, 11, LANDING_CURVE_IN)
	deck.alpha.mark(touchdown - 7.4 SECONDS, 0)
	deck.alpha.mark(touchdown - 6.4 SECONDS, 235)
	deck.alpha.mark(touchdown - 5 SECONDS, 235)
	deck.alpha.mark(touchdown - 4.4 SECONDS, 0)
	show(deck)

	var/datum/landing_view_piece/inside = add_sky(LANDING_VIEW_LAYER_CLOUD + 1, fill = palette.cloud)
	inside.alpha.mark(touchdown - 5.8 SECONDS, 0)
	inside.alpha.mark(touchdown - 5 SECONDS, 250, LANDING_CURVE_IN)
	inside.alpha.mark(touchdown - 4.6 SECONDS, 250)
	inside.alpha.mark(touchdown - 3.8 SECONDS, 0, LANDING_CURVE_OUT)
	show(inside)

	// the underside of the deck, torn into wisps, flying up and out past the ship
	var/datum/landing_view_piece/wisps = add_sky(LANDING_VIEW_LAYER_CLOUD, LANDING_VIEW_ICON, "clouds_b", LANDING_VIEW_ICON_SIZE)
	wisps.sky.color = palette.cloud
	wisps.scale.mark(touchdown - 4.8 SECONDS, 2)
	wisps.scale.mark(touchdown - 3 SECONDS, 9, LANDING_CURVE_IN)
	wisps.alpha.mark(touchdown - 4.8 SECONDS, 0)
	wisps.alpha.mark(touchdown - 4.4 SECONDS, 210)
	wisps.alpha.mark(touchdown - 3 SECONDS, 0)
	show(wisps)

	// haze between the ship and the ground, clearing as it comes down
	var/datum/landing_view_piece/haze = add_sky(LANDING_VIEW_LAYER_HAZE, fill = palette.sky)
	haze.alpha.mark(touchdown - 5.2 SECONDS, 0)
	haze.alpha.mark(touchdown - 5 SECONDS, 170)
	haze.alpha.mark(touchdown - 1.2 SECONDS, 0)
	show(haze)

/// The real ground, rushing up to full size, and the hull's shadow tightening on it
/datum/landing_view/descent/proc/add_ground()
	ground = add_picture()
	ground.scale.mark(touchdown - 5.2 SECONDS, DESCENT_GROUND_START)
	ground.scale.mark(touchdown - 0.3 SECONDS, 1, LANDING_CURVE_OUT)
	// under the sky until the sky has covered everything
	ground.alpha.mark(touchdown - 5.4 SECONDS, 0)
	ground.alpha.mark(touchdown - 5.3 SECONDS, 255)
	bake_ground(ground, DESCENT_GROUND_REACH, DESCENT_GROUND_DETAIL, palette.sky, CALLBACK(src, PROC_REF(show), ground))

	// the same shadow the people on the ground see spreading over the berth (see /datum/landing_animation)
	shadow = add_picture()
	shadow.parts = list(list(landing_view_shadow_look(berth_turfs, ground_x, ground_y), 0, 0, 1))
	shadow.scale.mark(touchdown - 3 SECONDS, 1.35)
	shadow.scale.mark(touchdown - 1 SECONDS, 1.15, LANDING_CURVE_BOTH)
	shadow.scale.mark(touchdown, 1, LANDING_CURVE_OUT)
	shadow.scale_with = ground.scale
	shadow.alpha.mark(touchdown - 5 SECONDS, 0)
	shadow.alpha.mark(touchdown - 4.4 SECONDS, 56)
	shadow.alpha.mark(touchdown - 3 SECONDS, 56)
	shadow.alpha.mark(touchdown - 1 SECONDS, 80, LANDING_CURVE_BOTH)
	shadow.alpha.mark(touchdown, 100, LANDING_CURVE_OUT)
	show(shadow)

/// The hull's outline in soft black, as a world picture drawn about [mid_x], [mid_y]
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

/// The hull has started to move onto the berth
/datum/landing_view/descent/proc/touchdown()
	return

/// The hull is down: the people aboard are looking at the real ground now
/datum/landing_view/descent/proc/landed()
	qdel(src)

#undef LANDING_VIEW_ICON
#undef LANDING_VIEW_ICON_SIZE
#undef DESCENT_GROUND_START
#undef DESCENT_GROUND_REACH
#undef DESCENT_GROUND_DETAIL
