/**
 * # Landing view
 *
 * What the people aboard see around their hull while it lands on a planet or leaves one. The hull spends the
 * whole manoeuvre in transit space, so without this they watch hyperspace until the ground appears under them.
 *
 * Two kinds of thing are drawn, both on LANDING_VIEW_PLANE (see landing_view_planes.dm for how it is cut to
 * what a viewer can see):
 *
 * - The sky: the planet seen whole, its air, clouds. Far away, so it does not move when a viewer walks about.
 *   Screen objects, shared by every viewer, held by one home object in each viewer's screen.
 * - World pictures: the real terrain around the berth, lit as it is lit, scaled about the middle of the hull,
 *   and the hull's shadow on it. They have to stay put against the hull as viewers walk, and anything standing
 *   on a turf is only drawn for people who can see that turf, so each viewer gets them as images standing on
 *   the turf under their own eye, shifted back to the hull's middle and moved along when they move.
 *
 * Motion is described once, as tracks over world.time, and sampled into short straight animation steps for
 * whoever is watching. Someone who starts watching halfway through gets the rest of the same motion.
 *
 * Visual only. Nothing here can be clicked, nothing blocks, and every way a landing or a takeoff can end
 * removes it.
 */

/// Length of one straight step of a sampled track
#define LANDING_VIEW_STEP (0.2 SECONDS)
/// How often the list of viewers is brought up to date
#define LANDING_VIEW_SYNC (0.5 SECONDS)
/// How long the view takes to fade away when its manoeuvre is called off
#define LANDING_VIEW_FADE (1.2 SECONDS)
/// How many steps the light on the hull's edge is changed in
#define LANDING_VIEW_LIGHT_STEPS 8
/// How many chunks of a picture that cannot be seen yet a viewer is handed in one tick
#define LANDING_VIEW_HANDOVER 12
/// How far ahead a viewer's chunks are picked for
#define LANDING_VIEW_AHEAD (1.5 SECONDS)
/// Tiles past the edge of a viewer's screen their chunks cover: a shaking camera, a step half made
#define LANDING_VIEW_MARGIN 1.5
/// And how much further off than that a chunk has to be before it is taken back
#define LANDING_VIEW_KEEP 3

/**
 * One value over time: keys of (world.time, value), each reached along a curve from the key before.
 */
/datum/landing_track
	var/list/times = list()
	var/list/values = list()
	var/list/curves = list()

/datum/landing_track/proc/mark(time, value, curve = LANDING_CURVE_LINEAR)
	times += time
	values += value
	curves += curve
	return src

/// The value at [time]; held at the first key before it and at the last key after it
/datum/landing_track/proc/at(time)
	var/count = length(times)
	if(!count)
		return 0
	if(time <= times[1])
		return values[1]
	if(time >= times[count])
		return values[count]
	for(var/i in 2 to count)
		if(time > times[i])
			continue
		var/span = times[i] - times[i - 1]
		if(span <= 0)
			return values[i]
		var/along = (time - times[i - 1]) / span
		switch(curves[i])
			if(LANDING_CURVE_OUT)
				along = 1 - (1 - along) ** 2
			if(LANDING_CURVE_IN)
				along = along ** 2
			if(LANDING_CURVE_BOTH)
				along = along * along * (3 - 2 * along)
		return values[i - 1] + (values[i] - values[i - 1]) * along
	return values[count]

/datum/landing_track/proc/end_time()
	return length(times) ? times[length(times)] : 0

/**
 * One thing the view shows, and how it moves: its size, its opacity and how far it has slid, each a track.
 *
 * Either a piece of sky (one screen object everyone watching shares) or a world picture (the ground, the
 * hull's shadow on it: an image per viewer, see /datum/landing_view).
 */
/datum/landing_view_piece
	/// Size, 1 = as drawn
	var/datum/landing_track/scale = new
	/// 0-255
	var/datum/landing_track/alpha = new
	/// How far it has slid away: tiles of the picture for a world picture, pixels for a piece of sky
	var/datum/landing_track/slide_x = new
	var/datum/landing_track/slide_y = new
	/// Another piece's size track this one's size is multiplied by: a shadow lying on ground that is itself scaled
	var/datum/landing_track/scale_with
	/// And a plain number it is multiplied by: a closer-up texture of the same thing is drawn that much smaller
	var/scale_factor = 1
	/// Clockwise degrees it is turned, for a hull that lands turned
	var/turn = 0
	/// Sky: the screen object
	var/atom/movable/screen/landing_view_sky/sky
	/**
	 * World picture: its parts, each a list(look, offset w, offset z, opacity 0-1, reach): what it shows, where
	 * its middle lies from the hull's middle in pixels, and how far it reaches from that middle in tiles (0: no
	 * telling, everyone holds it). An overlay's offset is not scaled with its parent, so a big picture cannot be
	 * one scaled appearance; every part is scaled and moved on its own to the same effect. Null until it is ready.
	 */
	var/list/parts
	/// World picture: TRUE while viewers hold it
	var/shown = FALSE
	/// World picture: TRUE once its taking back is booked, and once its handing over is
	var/dropping = FALSE
	var/give_booked = FALSE
	/**
	 * World picture: the smallest size it is ever seen at, if its parts are only handed to the viewers whose
	 * screen they are on. A picture of real tiles costs a client its frame rate by the tile, seen or not.
	 * 0: every viewer holds every part.
	 */
	var/cull_from = 0
	/// World picture: TRUE while it is handed out ahead of its motion being known: clear, and still
	var/held_back = FALSE
	/// World picture: world.time before which it is not handed to viewers, and after which it is taken back.
	/// A picture nobody can see yet still costs every viewer its drawing.
	var/give_at = 0
	var/drop_at = INFINITY

/datum/landing_view_piece/Destroy(force)
	QDEL_NULL(sky)
	parts = null
	return ..()

/datum/landing_view_piece/proc/end_time()
	return max(scale.end_time(), alpha.end_time(), slide_x.end_time(), slide_y.end_time(), scale_with ? scale_with.end_time() : 0)

/// list(size, alpha, slide x, slide y) at [time]
/datum/landing_view_piece/proc/state_at(time)
	var/size = (length(scale.times) ? scale.at(time) : 1) * scale_factor
	if(scale_with)
		size *= scale_with.at(time)
	return list(size, length(alpha.times) ? alpha.at(time) : 255, slide_x.at(time), slide_y.at(time))

/// The transform for a part whose middle lies [off_w], [off_z] pixels from the middle of the whole
/datum/landing_view_piece/proc/matrix_of(list/state, off_w = 0, off_z = 0)
	var/size = state[1]
	var/matrix/placed = matrix()
	if(turn)
		placed.Turn(turn)
	placed.Scale(size)
	// it slides away, so it is drawn moved the other way; the ground at the size it is drawn
	var/unit = sky ? 1 : ICON_SIZE_X * size
	var/shift_w = off_w * size - state[3] * unit
	var/shift_z = off_z * size - state[4] * unit
	if(shift_w || shift_z)
		if(turn)
			var/turned_w = shift_w * cos(turn) + shift_z * sin(turn)
			shift_z = -shift_w * sin(turn) + shift_z * cos(turn)
			shift_w = turned_w
		placed.Translate(shift_w, shift_z)
	return placed

/// Every moment the motion has to pass through from [now] on: a steady beat, and each key of each track
/datum/landing_view_piece/proc/sample_times(now)
	var/end = end_time()
	var/list/moments = list()
	for(var/beat = now + LANDING_VIEW_STEP, beat < end, beat += LANDING_VIEW_STEP)
		moments += beat
	for(var/datum/landing_track/track as anything in list(scale, alpha, slide_x, slide_y, scale_with))
		for(var/key_time in track?.times)
			if(key_time > now && key_time <= end)
				moments |= key_time
	if(end > now)
		moments |= end
	return sort_list(moments, GLOBAL_PROC_REF(cmp_numeric_asc))

/**
 * Puts [target] (the sky object, or a viewer's image of one part) where the piece is now and queues the rest of
 * its motion.
 * * off_w, off_z, opacity - the part's place and opacity, from the piece's parts list
 */
/datum/landing_view_piece/proc/play_on(target, off_w = 0, off_z = 0, opacity = 1)
	var/now = world.time
	var/list/state = state_at(now)
	var/atom/movable/moving = target // an image animates the same way
	moving.transform = matrix_of(state, off_w, off_z)
	moving.alpha = state[2] * opacity
	animate(moving, transform = matrix_of(state, off_w, off_z), alpha = state[2] * opacity, time = 0, flags = ANIMATION_LINEAR_TRANSFORM)
	var/last = now
	var/held = 0
	for(var/moment in sample_times(now))
		var/list/next_state = state_at(moment)
		if(next_state[1] == state[1] && next_state[2] == state[2] && next_state[3] == state[3] && next_state[4] == state[4])
			held += moment - last
			last = moment
			continue
		if(held)
			animate(time = held)
			held = 0
		animate(transform = matrix_of(next_state, off_w, off_z), alpha = next_state[2] * opacity, time = moment - last, flags = ANIMATION_LINEAR_TRANSFORM)
		state = next_state
		last = moment

/// One person watching: the images of the world pictures made for them, standing on the turf under their eye
/datum/landing_view_viewer
	var/client/client
	/// The mob whose moves we follow
	var/mob/followed
	/// The turf the images stand on
	var/turf/anchor
	/// Tiles they see each way from it, with a margin
	var/half_w = 11
	var/half_h = 9
	/// world picture -> the images of its parts they hold, by the part's number in the picture as text
	var/list/images = list()

/**
 * Holds the sky for one viewer's screen. One object for everyone watching.
 *
 * Anchored seven tiles down and left of the middle, as the parallax is: the sky's textures are fifteen tiles
 * across, and a screen object whose icon reaches past the edge of the view makes the client widen the view to
 * fit it, which pushes everything else off centre.
 */
/atom/movable/screen/landing_view_home
	name = ""
	icon = null
	screen_loc = "CENTER-7,CENTER-7"
	plane = LANDING_VIEW_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/// A piece of sky, drawn by the home it is in
/atom/movable/screen/landing_view_sky
	name = ""
	icon = 'icons/effects/alphacolors.dmi'
	icon_state = "white"
	plane = LANDING_VIEW_PLANE
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = RESET_COLOR | RESET_TRANSFORM | NO_CLIENT_COLOR
	alpha = 0

/datum/landing_view
	/// The hull
	var/obj/docking_port/mobile/shuttle
	/// The hull's turfs in transit and the berth turfs they pair with, in the same order
	var/list/hull_turfs
	var/list/berth_turfs
	/// transit turf -> TRUE
	var/list/hull_set = list()
	/// Clockwise degrees the landing turns the hull
	var/rotation = 0
	/// The box of transit space the view covers: the hull's box and its border
	var/transit_z
	var/low_x
	var/low_y
	var/high_x
	var/high_y
	/// The middle of the hull's box in transit, in tiles (may end in .5)
	var/pivot_x
	var/pivot_y
	/// The middle of the berth's box on the planet, the same point once landed
	var/ground_x
	var/ground_y
	var/ground_z
	/// Half the hull's size as it stands on the planet, in tiles
	var/ground_half_w
	var/ground_half_h
	/// Areas carrying the mask overlay
	var/list/area/masked = list()
	/// client -> /datum/landing_view_viewer
	var/list/viewers = list()
	/// Everything shown: sky and world pictures
	var/list/datum/landing_view_piece/pieces = list()
	/// The planet's colours
	var/datum/landing_view_palette/palette
	/// The ground around the berth from afar, the same ground close up, the light on it, and the hull's shadow on it
	var/datum/landing_view_piece/ground
	var/datum/landing_view_piece/close
	var/datum/landing_view_piece/light
	var/datum/landing_view_piece/shadow
	/// Areas carrying the overlay that marks transit space outside the hull
	var/list/area/marked_outside = list()
	var/atom/movable/screen/landing_view_home/home
	/// Things standing in transit space for the view (heat on the hull's edge, dust): deleted with it
	var/list/props = list()
	/// The timer that keeps the viewers up to date
	var/sync_timer
	/// The transit turfs around the hull whose light this has changed, and their planet twins (see fade_light())
	var/list/light_twins
	/// TRUE once nothing more should be shown
	var/ended = FALSE

/**
 * * hull_turfs - the hull's turfs in transit; null to attach() it later, once it is there
 * * berth_turfs - the berth turfs they pair with, in the same order
 * * rotation - clockwise degrees from the hull's heading in transit to its heading on the berth
 */
/datum/landing_view/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation)
	. = ..()
	src.shuttle = shuttle
	home = new
	if(berth_turfs && !set_ground(berth_turfs))
		ended = TRUE
	else if(hull_turfs)
		if(!attach(hull_turfs, rotation))
			ended = TRUE
	else if(berth_turfs)
		stand_on_berth()
	else
		ended = TRUE

/// The berth the hull will stand on, or stood on. FALSE if there is none.
/datum/landing_view/proc/set_ground(list/berth_turfs)
	if(!length(berth_turfs))
		return FALSE
	src.berth_turfs = berth_turfs
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	for(var/turf/berth_turf as anything in berth_turfs)
		min_x = min(min_x, berth_turf.x)
		max_x = max(max_x, berth_turf.x)
		min_y = min(min_y, berth_turf.y)
		max_y = max(max_y, berth_turf.y)
	ground_z = berth_turfs[1].z
	ground_x = (min_x + max_x) / 2
	ground_y = (min_y + max_y) / 2
	ground_half_w = (max_x - min_x + 1) / 2
	ground_half_h = (max_y - min_y + 1) / 2
	return TRUE

/**
 * The hull is still on its berth: the people aboard are found there, so they can be handed what they will need
 * before it lifts. Nothing can be seen until attach().
 */
/datum/landing_view/proc/stand_on_berth()
	transit_z = ground_z
	pivot_x = ground_x
	pivot_y = ground_y
	low_x = ground_x - ground_half_w + 0.5
	low_y = ground_y - ground_half_h + 0.5
	high_x = ground_x + ground_half_w - 0.5
	high_y = ground_y + ground_half_h - 0.5
	start_sync()

/datum/landing_view/proc/start_sync()
	if(!sync_timer)
		sync_timer = addtimer(CALLBACK(src, PROC_REF(sync_viewers)), LANDING_VIEW_SYNC, TIMER_DELETE_ME | TIMER_LOOP | TIMER_STOPPABLE)

/**
 * The hull in transit, which everything is drawn around: from here on there are viewers. FALSE if [hull_turfs]
 * do not pair with the berth's.
 */
/datum/landing_view/proc/attach(list/hull_turfs, rotation)
	if(!length(hull_turfs) || (berth_turfs && length(hull_turfs) != length(berth_turfs)))
		return FALSE
	src.hull_turfs = hull_turfs
	src.rotation = rotation
	var/min_x = INFINITY
	var/max_x = -INFINITY
	var/min_y = INFINITY
	var/max_y = -INFINITY
	hull_set = list()
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_set[hull_turf] = TRUE
		min_x = min(min_x, hull_turf.x)
		max_x = max(max_x, hull_turf.x)
		min_y = min(min_y, hull_turf.y)
		max_y = max(max_y, hull_turf.y)
	transit_z = hull_turfs[1].z
	pivot_x = (min_x + max_x) / 2
	pivot_y = (min_y + max_y) / 2
	low_x = max(1, min_x - SHUTTLE_TRANSIT_BORDER)
	low_y = max(1, min_y - SHUTTLE_TRANSIT_BORDER)
	high_x = min(world.maxx, max_x + SHUTTLE_TRANSIT_BORDER)
	high_y = min(world.maxy, max_y + SHUTTLE_TRANSIT_BORDER)
	// the ground reaches the hull the way round it lies when the hull is on its berth
	for(var/datum/landing_view_piece/piece as anything in pieces)
		if(!piece.sky)
			piece.turn = -rotation
	mask_areas()
	start_sync()
	return TRUE

/datum/landing_view/Destroy(force)
	ended = TRUE
	for(var/client/watcher as anything in viewers)
		drop_viewer(watcher)
	viewers = null
	unmask_areas()
	if(light_twins)
		// left as they were found
		landing_view_restore_light(light_twins)
		light_twins = null
	QDEL_LIST(props)
	QDEL_LIST(pieces)
	ground = null
	close = null
	light = null
	shadow = null
	palette = null
	QDEL_NULL(home)
	shuttle = null
	hull_turfs = null
	berth_turfs = null
	hull_set = null
	return ..()

/**
 * The manoeuvre was called off: everything fades away, back to plain space, and then the view deletes itself.
 * Whoever held it should let go of it now.
 */
/datum/landing_view/proc/fade_away()
	if(ended)
		return
	ended = TRUE
	for(var/datum/landing_view_piece/piece as anything in pieces)
		if(piece.sky)
			animate(piece.sky, alpha = 0, time = LANDING_VIEW_FADE)
	for(var/client/watcher as anything in viewers)
		var/datum/landing_view_viewer/viewer = viewers[watcher]
		for(var/piece in viewer?.images)
			var/list/held = viewer.images[piece]
			for(var/slot in held)
				animate(held[slot], alpha = 0, time = LANDING_VIEW_FADE)
	for(var/atom/movable/prop as anything in props)
		if(!QDELETED(prop))
			animate(prop, alpha = 0, time = LANDING_VIEW_FADE)
	// a hard reference: by now nothing else holds us
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), LANDING_VIEW_FADE)

/**
 * In transit the stars light the hull's outer edge; on the ground, the ground beside it does (warm daylight off
 * grass, blue off water). Left alone the hull changes colour the instant it lands or lifts. So for the last of
 * a descent the space around the hull casts, tile for tile, the light the ground around the berth will, and
 * after a takeoff it goes on casting it and lets it go slowly.
 * * start, finish - how far from the stars' light to the ground's, 0-1
 */
/datum/landing_view/proc/fade_light(start, finish, time, stage = 0)
	if(QDELETED(src) || ended || !hull_turfs || !berth_turfs)
		return
	light_twins ||= landing_view_light_twins(hull_turfs, berth_turfs, rotation)
	landing_view_blend_light(light_twins, start + (finish - start) * stage / LANDING_VIEW_LIGHT_STEPS)
	if(stage < LANDING_VIEW_LIGHT_STEPS)
		addtimer(CALLBACK(src, PROC_REF(fade_light), start, finish, time, stage + 1), time / LANDING_VIEW_LIGHT_STEPS, TIMER_DELETE_ME)

/**
 * The transit turfs around a hull, each with the planet turf that lies in its place beside the berth:
 * transit turf -> list(planet turf, TRUE if the stars light the hull from there).
 * * rotation - clockwise degrees from the hull's heading in transit to its heading on the berth
 */
/proc/landing_view_light_twins(list/hull_turfs, list/berth_turfs, rotation)
	. = list()
	var/list/hull_set = list()
	var/list/berth_set = list()
	for(var/turf/hull_turf as anything in hull_turfs)
		hull_set[hull_turf] = TRUE
	for(var/turf/berth_turf as anything in berth_turfs)
		berth_set[berth_turf] = TRUE
	var/turned_cos = round(cos(rotation), 1)
	var/turned_sin = round(sin(rotation), 1)
	for(var/i in 1 to min(length(hull_turfs), length(berth_turfs)))
		var/turf/hull_turf = hull_turfs[i]
		var/turf/berth_turf = berth_turfs[i]
		for(var/off_x in -2 to 2)
			for(var/off_y in -2 to 2)
				var/turf/planet_side = locate(berth_turf.x + off_x, berth_turf.y + off_y, berth_turf.z)
				if(!planet_side || berth_set[planet_side])
					continue
				// the same step from the same hull tile, turned as the hull lies in transit
				var/turf/transit_side = locate(hull_turf.x + off_x * turned_cos - off_y * turned_sin, hull_turf.y + off_x * turned_sin + off_y * turned_cos, hull_turf.z)
				if(!transit_side || hull_set[transit_side] || !isspaceturf(transit_side))
					continue
				var/beside = abs(off_x) <= 1 && abs(off_y) <= 1
				var/list/twin = .[transit_side]
				if(!twin)
					.[transit_side] = list(planet_side, beside)
				else if(beside)
					twin[2] = TRUE

/// Sets the light each transit turf of [twins] casts: [share] of the way from the stars' to its planet twin's
/proc/landing_view_blend_light(list/twins, share)
	var/star_range = GLOB.starlight_range
	var/star_power = GLOB.starlight_power
	var/star_color = GLOB.starlight_color
	for(var/turf/transit_side as anything in twins)
		if(!isspaceturf(transit_side))
			continue
		var/list/twin = twins[transit_side]
		var/stars = twin[2] ? star_power : 0
		var/list/ground = landing_view_ground_light(twin[1], twin[2])
		if(!stars && !ground)
			continue
		var/from_reach = stars ? star_range : ground[1]
		var/to_reach = ground ? ground[1] : star_range
		var/to_power = ground ? ground[2] : 0
		var/tone = star_color
		if(ground && (!stars || share >= 1))
			tone = ground[3] || COLOR_WHITE
		else if(ground && share > 0)
			// never asked for the far end itself: the gradient loops, and gives the near end back for it
			tone = BlendRGB(star_color, ground[3] || COLOR_WHITE, share)
		// kept on even at no power: a turf whose light is off has the stars' put back by its neighbours
		transit_side.set_light(l_range = from_reach + (to_reach - from_reach) * share, l_power = max(stars + (to_power - stars) * share, 0), l_color = tone, l_on = TRUE)

/**
 * The light [planet_side] casts on a hull standing beside it, as list(range, power, colour), or null for none.
 * Daylit ground only lights what stands against it while something does (see voidcrew/edits/lighting.dm), so
 * for ground with nothing on it yet this is the light it will cast, not the light it has.
 * * beside - TRUE if the hull stands right against it
 */
/proc/landing_view_ground_light(turf/planet_side, beside)
	// ground that lights itself: lava, glowing water
	if(planet_side.light_range && planet_side.light_range != AMBIENT_BLEED_RANGE)
		if(!planet_side.light_on || planet_side.light_power <= 0)
			return null
		return list(planet_side.light_range, planet_side.light_power, planet_side.light_color)
	if(!beside)
		return null
	var/area/daylit = planet_side.ambient_bleed_area()
	if(!daylit)
		return null
	return list(AMBIENT_BLEED_RANGE, (daylit.base_lighting_alpha / 255) / AMBIENT_BLEED_OVERLAP_FACTOR, daylit.base_lighting_color == COLOR_STARLIGHT ? GLOB.starlight_color : daylit.base_lighting_color)

/// Gives the transit turfs of [twins] back the light they have by rights: the stars', beside a hull, or none
/proc/landing_view_restore_light(list/twins)
	for(var/turf/open/space/transit_side in twins)
		GLOB.starlight -= transit_side
		transit_side.set_light(l_on = FALSE)
		transit_side.update_starlight()

/// The mask tile every turf of a landing ship carries, through its area
/proc/landing_view_mask_tile()
	var/static/mutable_appearance/tile
	if(!tile)
		tile = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)
		tile.plane = LANDING_VIEW_MASK_PLANE
	return tile

/// The tile every turf of transit space around a landing ship carries, through its area: where the ground's light may fall
/proc/landing_view_outside_tile()
	var/static/mutable_appearance/tile
	if(!tile)
		tile = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)
		tile.plane = LANDING_VIEW_OUTSIDE_PLANE
	return tile

/datum/landing_view/proc/mask_areas()
	var/list/area/wanted = list()
	var/list/area/outside_areas = list()
	if(shuttle.assigned_transit?.assigned_area)
		wanted += shuttle.assigned_transit.assigned_area
		outside_areas += shuttle.assigned_transit.assigned_area
	for(var/area/hull_area as anything in shuttle.shuttle_areas)
		wanted |= hull_area
	for(var/turf/hull_turf as anything in hull_turfs)
		wanted |= hull_turf.loc
	// the transit space around the hull, whoever's area it is
	var/turf/outside = locate(low_x, low_y, transit_z)
	if(outside)
		wanted |= outside.loc
		outside_areas |= outside.loc
	for(var/area/to_mask as anything in wanted)
		to_mask.add_overlay(landing_view_mask_tile())
		masked += to_mask
	for(var/area/to_mark as anything in outside_areas)
		to_mark.add_overlay(landing_view_outside_tile())
		marked_outside += to_mark

/datum/landing_view/proc/unmask_areas()
	for(var/area/was_masked as anything in masked)
		if(!QDELETED(was_masked))
			was_masked.cut_overlay(landing_view_mask_tile())
	masked = list()
	for(var/area/was_marked as anything in marked_outside)
		if(!QDELETED(was_marked))
			was_marked.cut_overlay(landing_view_outside_tile())
	marked_outside = list()

/**
 * A new piece of sky in the shared home, its middle on the middle of the screen. With no icon it is a flat
 * fill of [fill] over the whole screen.
 * * size - the icon's size in pixels
 */
/datum/landing_view/proc/add_sky(sky_layer, icon_file, state, size = ICON_SIZE_X, fill)
	var/datum/landing_view_piece/piece = new
	var/atom/movable/screen/landing_view_sky/sky = new
	piece.sky = sky
	sky.layer = sky_layer
	if(icon_file)
		sky.icon = icon_file
		sky.icon_state = state
		// its middle on the middle of the home's fifteen tiles
		sky.pixel_w = (LANDING_VIEW_ICON_SIZE - size) / 2
		sky.pixel_z = (LANDING_VIEW_ICON_SIZE - size) / 2
	else
		// one white tile in the middle, drawn big enough for any screen
		sky.color = fill
		sky.pixel_w = (LANDING_VIEW_ICON_SIZE - ICON_SIZE_X) / 2
		sky.pixel_z = (LANDING_VIEW_ICON_SIZE - ICON_SIZE_Y) / 2
		var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white")
		sheet.transform = matrix().Scale(64)
		sky.icon_state = "transparent"
		sky.overlays = list(sheet)
	home.vis_contents += sky
	pieces += piece
	return piece

/**
 * A sheet of full light over the ground's own light (see bake_light()), as opaque as [alpha] says: for the white
 * of a cloud, which is lit by the open sky whatever the ground under it is. Without it a cave turns the cloud
 * black and warm daylight turns it tan, a moment before either is seen.
 */
/datum/landing_view/proc/add_daylight(datum/landing_track/alpha)
	var/datum/landing_view_piece/daylight = add_sky(5, fill = COLOR_WHITE)
	daylight.sky.plane = LANDING_VIEW_LIGHT_PLANE
	daylight.alpha = alpha
	show(daylight)
	return daylight

/// A new world picture. Set its parts, then show() it.
/datum/landing_view/proc/add_picture()
	var/datum/landing_view_piece/piece = new
	// the ground reaches the hull the way round it will lie once the hull has turned onto its berth
	piece.turn = -rotation
	pieces += piece
	return piece

/**
 * [piece]'s motion is set, or has changed: (re)start it for everyone watching. A world picture is handed over at
 * its give_at and taken back at its drop_at.
 * * replay - FALSE if only new parts were added to a world picture: what is already showing is left alone
 */
/datum/landing_view/proc/show(datum/landing_view_piece/piece, replay = TRUE)
	if(ended)
		return
	if(piece.sky)
		piece.play_on(piece.sky)
		return
	if(!length(piece.parts) || world.time >= piece.drop_at)
		return
	if(world.time < piece.give_at)
		// booked once for each picture. Not as a unique timer: two pictures due at the same moment count as one, and the first is never shown
		if(piece.give_at < INFINITY && !piece.give_booked)
			piece.give_booked = TRUE
			addtimer(CALLBACK(src, PROC_REF(show), piece, replay), piece.give_at - world.time, TIMER_DELETE_ME)
		return
	if(!piece.dropping && piece.drop_at < INFINITY)
		piece.dropping = TRUE
		addtimer(CALLBACK(src, PROC_REF(take_back), piece), piece.drop_at - world.time, TIMER_DELETE_ME)
	piece.shown = TRUE
	for(var/client/watcher as anything in viewers)
		var/datum/landing_view_viewer/viewer = viewers[watcher]
		if(!viewer || !watcher)
			continue
		give_picture(viewer, piece, replay)

/// A picture handed out ahead of time (see held_back) starts to move, for everyone who holds it
/datum/landing_view/proc/reveal(datum/landing_view_piece/piece)
	if(ended || !piece.held_back)
		return
	piece.held_back = FALSE
	show(piece)

/// [piece] is out of sight for good: nobody holds its images any more
/datum/landing_view/proc/take_back(datum/landing_view_piece/piece)
	if(ended || !piece.shown)
		return
	piece.shown = FALSE
	for(var/client/watcher as anything in viewers)
		var/datum/landing_view_viewer/viewer = viewers[watcher]
		var/list/held = viewer?.images[piece]
		if(!held)
			continue
		for(var/slot in held)
			watcher?.images -= held[slot]
		viewer.images -= piece

/**
 * Brings what [viewer] holds of [piece] up to date: the parts their screen can show, or all of them for a
 * picture that is not picked over. Parts gone out of their sight are taken back.
 * * replay - FALSE to leave alone what they already hold
 */
/datum/landing_view/proc/give_picture(datum/landing_view_viewer/viewer, datum/landing_view_piece/piece, replay = TRUE)
	var/client/watcher = viewer.client
	if(!watcher)
		return
	var/list/shown = viewer.images[piece]
	if(!shown)
		shown = list()
		viewer.images[piece] = shown
	var/list/sight = piece.cull_from ? sight_of(viewer, piece) : null
	// a picture already in sight has to be whole at once; one that is still clear can come a few parts a tick
	var/budget = (sight && (piece.held_back || piece.state_at(world.time)[2] <= 0)) ? LANDING_VIEW_HANDOVER : INFINITY
	var/more = FALSE
	var/list/image/added = list()
	for(var/i in 1 to length(piece.parts))
		var/list/part = piece.parts[i]
		var/slot = "[i]"
		var/image/part_image = shown[slot]
		// how far out of their sight it lies, in tiles
		var/out = 0
		if(sight && length(part) > 4 && part[5])
			out = max(abs(part[2] - sight[1]) - sight[3], abs(part[3] - sight[2]) - sight[4]) / ICON_SIZE_X - part[5]
		if(part_image)
			if(out > LANDING_VIEW_KEEP)
				watcher.images -= part_image
				shown -= slot
			else if(replay)
				play_part(piece, part_image, part)
			continue
		if(out > 0)
			continue
		if(budget <= 0)
			more = TRUE
			continue
		budget--
		part_image = image(loc = viewer.anchor)
		part_image.appearance = part[1]
		part_image.loc = viewer.anchor
		place_image(part_image, viewer.anchor)
		play_part(piece, part_image, part)
		shown[slot] = part_image
		added += part_image
	watcher.images += added
	if(more)
		addtimer(CALLBACK(src, PROC_REF(give_more), viewer, piece), world.tick_lag, TIMER_DELETE_ME)

/// The rest of a picture that is being handed over a few parts a tick
/datum/landing_view/proc/give_more(datum/landing_view_viewer/viewer, datum/landing_view_piece/piece)
	if(ended || QDELETED(piece) || !piece.shown || !viewer.client || viewers[viewer.client] != viewer)
		return
	give_picture(viewer, piece, FALSE)

/datum/landing_view/proc/play_part(datum/landing_view_piece/piece, image/part_image, list/part)
	if(piece.held_back)
		animate(part_image, alpha = 0, time = 0)
		part_image.alpha = 0
		return
	piece.play_on(part_image, part[2], part[3], part[4])

/**
 * The part of [piece] that [viewer]'s screen shows from now until a little later, in the picture's own pixels
 * from its middle: list(middle w, middle z, half width, half height).
 */
/datum/landing_view/proc/sight_of(datum/landing_view_viewer/viewer, datum/landing_view_piece/piece)
	var/now = world.time
	// their eye from the hull's middle, turned into the picture's frame
	var/eye_w = (viewer.anchor.x - pivot_x) * ICON_SIZE_X
	var/eye_z = (viewer.anchor.y - pivot_y) * ICON_SIZE_Y
	var/turned = piece.turn
	var/in_w = eye_w * cos(turned) - eye_z * sin(turned)
	var/in_z = eye_w * sin(turned) + eye_z * cos(turned)
	var/sideways = abs(round(turned / 90)) % 2
	var/half_w = (sideways ? viewer.half_h : viewer.half_w) * ICON_SIZE_X
	var/half_z = (sideways ? viewer.half_w : viewer.half_h) * ICON_SIZE_Y
	var/low_w = INFINITY
	var/low_z = INFINITY
	var/high_w = -INFINITY
	var/high_z = -INFINITY
	for(var/when in list(now, now + LANDING_VIEW_AHEAD))
		var/list/state = piece.state_at(when)
		var/size = piece.held_back ? piece.cull_from : max(piece.cull_from, state[1])
		// it is drawn slid and then scaled, so a point of the screen is that far into it
		var/mid_w = in_w / size + state[3] * ICON_SIZE_X
		var/mid_z = in_z / size + state[4] * ICON_SIZE_Y
		low_w = min(low_w, mid_w - half_w / size)
		high_w = max(high_w, mid_w + half_w / size)
		low_z = min(low_z, mid_z - half_z / size)
		high_z = max(high_z, mid_z + half_z / size)
	return list((low_w + high_w) / 2, (low_z + high_z) / 2, (high_w - low_w) / 2, (high_z - low_z) / 2)

/// Shifts an image standing on [anchor] so its middle is the hull's middle
/datum/landing_view/proc/place_image(image/shown, turf/anchor)
	shown.pixel_w = (pivot_x - anchor.x) * ICON_SIZE_X
	shown.pixel_z = (pivot_y - anchor.y) * ICON_SIZE_Y

/// Whether [watcher] is looking at this hull's patch of transit space, and from which turf
/datum/landing_view/proc/eye_turf_of(client/watcher)
	var/turf/eye_turf = get_turf(watcher.eye)
	if(!eye_turf || eye_turf.z != transit_z)
		return null
	if(eye_turf.x < low_x || eye_turf.x > high_x || eye_turf.y < low_y || eye_turf.y > high_y)
		return null
	return eye_turf

/// Brings the viewers up to date: everyone whose eye is on or around the hull, living or not
/datum/landing_view/proc/sync_viewers()
	if(ended || !transit_z)
		return
	for(var/client/watcher as anything in viewers)
		if(!watcher || !eye_turf_of(watcher))
			drop_viewer(watcher)
	for(var/mob/player as anything in GLOB.player_list)
		var/client/watcher = player.client
		if(!watcher)
			continue
		var/turf/eye_turf = eye_turf_of(watcher)
		if(!eye_turf)
			continue
		var/datum/landing_view_viewer/viewer = viewers[watcher]
		if(!viewer)
			add_viewer(watcher, eye_turf)
			continue
		if(viewer.followed != watcher.mob)
			follow(viewer, watcher.mob)
		size_up(viewer)
		if(viewer.anchor != eye_turf)
			move_viewer(viewer, eye_turf)
		else
			for(var/datum/landing_view_piece/piece as anything in pieces)
				if(piece.shown && piece.cull_from)
					give_picture(viewer, piece, FALSE)

/// How much [viewer] sees each way
/datum/landing_view/proc/size_up(datum/landing_view_viewer/viewer)
	var/list/view_size = getviewsize(viewer.client?.view)
	viewer.half_w = view_size[1] / 2 + LANDING_VIEW_MARGIN
	viewer.half_h = view_size[2] / 2 + LANDING_VIEW_MARGIN

/datum/landing_view/proc/add_viewer(client/watcher, turf/eye_turf)
	var/datum/landing_view_viewer/viewer = new
	viewer.client = watcher
	viewer.anchor = eye_turf
	viewers[watcher] = viewer
	follow(viewer, watcher.mob)
	size_up(viewer)
	watcher.screen += home
	for(var/datum/landing_view_piece/piece as anything in pieces)
		if(piece.shown)
			give_picture(viewer, piece)
	on_viewer_added(watcher)

/// For the manoeuvre to greet a new viewer with its sounds
/datum/landing_view/proc/on_viewer_added(client/watcher)
	return

/datum/landing_view/proc/drop_viewer(client/watcher)
	var/datum/landing_view_viewer/viewer = viewers[watcher]
	viewers -= watcher
	if(!viewer)
		return
	follow(viewer, null)
	if(watcher)
		watcher.screen -= home
		for(var/piece in viewer.images)
			var/list/held = viewer.images[piece]
			for(var/slot in held)
				watcher.images -= held[slot]
	viewer.images = null
	viewer.client = null

/datum/landing_view/proc/follow(datum/landing_view_viewer/viewer, mob/to_follow)
	if(viewer.followed)
		UnregisterSignal(viewer.followed, COMSIG_MOVABLE_MOVED)
	viewer.followed = to_follow
	if(to_follow)
		RegisterSignal(to_follow, COMSIG_MOVABLE_MOVED, PROC_REF(on_viewer_moved), override = TRUE)

/datum/landing_view/proc/on_viewer_moved(mob/source)
	SIGNAL_HANDLER
	var/client/watcher = source.client
	var/datum/landing_view_viewer/viewer = watcher ? viewers[watcher] : null
	if(!viewer)
		return
	var/turf/eye_turf = eye_turf_of(watcher)
	if(eye_turf && eye_turf != viewer.anchor)
		move_viewer(viewer, eye_turf)

/// The viewer's eye is over a new turf: their images go with it, and stay where they were on the world
/datum/landing_view/proc/move_viewer(datum/landing_view_viewer/viewer, turf/eye_turf)
	viewer.anchor = eye_turf
	for(var/datum/landing_view_piece/piece as anything in viewer.images)
		var/list/held = viewer.images[piece]
		for(var/slot in held)
			var/image/shown = held[slot]
			shown.loc = eye_turf
			place_image(shown, eye_turf)
		if(piece.shown && piece.cull_from)
			give_picture(viewer, piece, FALSE)

#undef LANDING_VIEW_STEP
#undef LANDING_VIEW_SYNC
#undef LANDING_VIEW_FADE
#undef LANDING_VIEW_HANDOVER
#undef LANDING_VIEW_LIGHT_STEPS
#undef LANDING_VIEW_AHEAD
#undef LANDING_VIEW_MARGIN
#undef LANDING_VIEW_KEEP
