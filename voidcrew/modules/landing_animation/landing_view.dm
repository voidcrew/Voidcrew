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
/// Tiles per side of one chunk of ground picture
#define LANDING_VIEW_CHUNK 16

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
	/// Clockwise degrees it is turned, for a hull that lands turned
	var/turn = 0
	/// Sky: the screen object
	var/atom/movable/screen/landing_view_sky/sky
	/**
	 * World picture: its parts, each a list(look, offset w, offset z, opacity 0-1): what it shows, and where its
	 * middle lies from the hull's middle in pixels. An overlay's offset is not scaled with its parent, so a big
	 * picture cannot be one scaled appearance; every part is scaled and moved on its own to the same effect.
	 * Null until it is ready.
	 */
	var/list/parts
	/// World picture: TRUE once it is handed to viewers
	var/shown = FALSE

/datum/landing_view_piece/Destroy(force)
	QDEL_NULL(sky)
	parts = null
	return ..()

/datum/landing_view_piece/proc/end_time()
	return max(scale.end_time(), alpha.end_time(), slide_x.end_time(), slide_y.end_time(), scale_with ? scale_with.end_time() : 0)

/// list(size, alpha, slide x, slide y) at [time]
/datum/landing_view_piece/proc/state_at(time)
	var/size = length(scale.times) ? scale.at(time) : 1
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
	/// world picture -> list of images, one per part
	var/list/images = list()

/// Holds the sky for one viewer's screen. One object for everyone watching.
/atom/movable/screen/landing_view_home
	name = ""
	icon = null
	screen_loc = "CENTER"
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
	var/atom/movable/screen/landing_view_home/home
	/// Things standing in transit space for the view (heat on the hull's edge, dust): deleted with it
	var/list/props = list()
	/// TRUE once nothing more should be shown
	var/ended = FALSE

/datum/landing_view/New(obj/docking_port/mobile/shuttle, list/hull_turfs, list/berth_turfs, rotation)
	. = ..()
	src.shuttle = shuttle
	src.hull_turfs = hull_turfs
	src.berth_turfs = berth_turfs
	src.rotation = rotation
	if(!length(hull_turfs) || length(hull_turfs) != length(berth_turfs))
		ended = TRUE
		return
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
	transit_z = hull_turfs[1].z
	pivot_x = (min_x + max_x) / 2
	pivot_y = (min_y + max_y) / 2
	low_x = max(1, min_x - SHUTTLE_TRANSIT_BORDER)
	low_y = max(1, min_y - SHUTTLE_TRANSIT_BORDER)
	high_x = min(world.maxx, max_x + SHUTTLE_TRANSIT_BORDER)
	high_y = min(world.maxy, max_y + SHUTTLE_TRANSIT_BORDER)
	min_x = INFINITY
	max_x = -INFINITY
	min_y = INFINITY
	max_y = -INFINITY
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
	home = new
	mask_areas()
	addtimer(CALLBACK(src, PROC_REF(sync_viewers)), LANDING_VIEW_SYNC, TIMER_DELETE_ME | TIMER_LOOP)

/datum/landing_view/Destroy(force)
	ended = TRUE
	for(var/client/watcher as anything in viewers)
		drop_viewer(watcher)
	viewers = null
	unmask_areas()
	QDEL_LIST(props)
	QDEL_LIST(pieces)
	QDEL_NULL(home)
	shuttle = null
	hull_turfs = null
	berth_turfs = null
	hull_set = null
	return ..()

/// The mask tile every turf of a landing ship carries, through its area
/proc/landing_view_mask_tile()
	var/static/mutable_appearance/tile
	if(!tile)
		tile = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR | RESET_ALPHA | RESET_TRANSFORM)
		tile.plane = LANDING_VIEW_MASK_PLANE
	return tile

/datum/landing_view/proc/mask_areas()
	var/list/area/wanted = list()
	if(shuttle.assigned_transit?.assigned_area)
		wanted += shuttle.assigned_transit.assigned_area
	for(var/area/hull_area as anything in shuttle.shuttle_areas)
		wanted |= hull_area
	for(var/turf/hull_turf as anything in hull_turfs)
		wanted |= hull_turf.loc
	// the transit space around the hull, whoever's area it is
	var/turf/outside = locate(low_x, low_y, transit_z)
	if(outside)
		wanted |= outside.loc
	for(var/area/to_mask as anything in wanted)
		to_mask.add_overlay(landing_view_mask_tile())
		masked += to_mask

/datum/landing_view/proc/unmask_areas()
	for(var/area/was_masked as anything in masked)
		if(!QDELETED(was_masked))
			was_masked.cut_overlay(landing_view_mask_tile())
	masked = list()

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
		sky.pixel_w = -(size - ICON_SIZE_X) / 2
		sky.pixel_z = -(size - ICON_SIZE_Y) / 2
	else
		// one white tile, big enough for any screen
		sky.color = fill
		var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white")
		sheet.transform = matrix().Scale(64)
		sky.icon_state = "transparent"
		sky.overlays = list(sheet)
	home.vis_contents += sky
	pieces += piece
	return piece

/// A new world picture. Set its parts, then show() it.
/datum/landing_view/proc/add_picture()
	var/datum/landing_view_piece/piece = new
	// the ground reaches the hull the way round it will lie once the hull has turned onto its berth
	piece.turn = -rotation
	pieces += piece
	return piece

/// [piece]'s motion is set, or has changed: (re)start it for everyone watching
/datum/landing_view/proc/show(datum/landing_view_piece/piece)
	if(ended)
		return
	if(piece.sky)
		piece.play_on(piece.sky)
		return
	if(!length(piece.parts))
		return
	piece.shown = TRUE
	for(var/client/watcher as anything in viewers)
		var/datum/landing_view_viewer/viewer = viewers[watcher]
		if(!viewer || !watcher)
			continue
		give_picture(viewer, piece)

/datum/landing_view/proc/give_picture(datum/landing_view_viewer/viewer, datum/landing_view_piece/piece)
	var/list/image/shown = viewer.images[piece]
	if(shown)
		for(var/i in 1 to length(shown))
			var/list/part = piece.parts[i]
			piece.play_on(shown[i], part[2], part[3], part[4])
		return
	shown = list()
	viewer.images[piece] = shown
	for(var/list/part as anything in piece.parts)
		var/image/part_image = image(loc = viewer.anchor)
		part_image.appearance = part[1]
		part_image.loc = viewer.anchor
		place_image(part_image, viewer.anchor)
		piece.play_on(part_image, part[2], part[3], part[4])
		shown += part_image
	viewer.client.images += shown

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
	if(ended)
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
		if(viewer.anchor != eye_turf)
			move_viewer(viewer, eye_turf)

/datum/landing_view/proc/add_viewer(client/watcher, turf/eye_turf)
	var/datum/landing_view_viewer/viewer = new
	viewer.client = watcher
	viewer.anchor = eye_turf
	viewers[watcher] = viewer
	follow(viewer, watcher.mob)
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
			watcher.images -= viewer.images[piece]
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
	for(var/piece in viewer.images)
		for(var/image/shown as anything in viewer.images[piece])
			shown.loc = eye_turf
			place_image(shown, eye_turf)

/**
 * Builds the picture of the ground around the berth and hands it to [piece] as its look. Takes a few ticks;
 * [then] is called when it is done.
 * * reach - how many tiles past the hull's box the picture goes
 * * detail_reach - how far past the hull's box things standing on the ground are drawn as well
 * * backdrop_color - under and beyond the ground, as far as anyone can see
 */
/datum/landing_view/proc/bake_ground(datum/landing_view_piece/piece, reach, detail_reach, backdrop_color, datum/callback/then)
	set waitfor = FALSE
	var/started = REALTIMEOFDAY
	var/reach_x = CEILING(ground_half_w + reach, LANDING_VIEW_CHUNK)
	var/reach_y = CEILING(ground_half_h + reach, LANDING_VIEW_CHUNK)
	var/detail_x = ground_half_w + detail_reach
	var/detail_y = ground_half_h + detail_reach
	var/list/parts = list()
	// under the ground: the haze it fades into at its edges
	var/mutable_appearance/backdrop = new()
	var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
	sheet.color = backdrop_color
	sheet.transform = matrix().Scale(400)
	backdrop.overlays = list(sheet)
	parts += list(list(landing_view_world_look(backdrop, LANDING_VIEW_LAYER_GROUND), 0, 0, 1))
	var/datum/own_region = map_region_for_turf(berth_turfs[1])
	var/middle_x = round(ground_x)
	var/middle_y = round(ground_y)
	for(var/chunk_x = middle_x - reach_x, chunk_x < middle_x + reach_x, chunk_x += LANDING_VIEW_CHUNK)
		for(var/chunk_y = middle_y - reach_y, chunk_y < middle_y + reach_y, chunk_y += LANDING_VIEW_CHUNK)
			var/centre_off_x = chunk_x + LANDING_VIEW_CHUNK / 2 - ground_x
			var/centre_off_y = chunk_y + LANDING_VIEW_CHUNK / 2 - ground_y
			var/detail = abs(centre_off_x) <= detail_x + LANDING_VIEW_CHUNK / 2 && abs(centre_off_y) <= detail_y + LANDING_VIEW_CHUNK / 2
			var/mutable_appearance/chunk = landing_view_chunk(chunk_x, chunk_y, ground_z, detail, own_region)
			if(chunk)
				// the outermost chunks are thin, so the picture has no hard edge
				var/rings_in = min((reach_x - abs(centre_off_x)) / LANDING_VIEW_CHUNK, (reach_y - abs(centre_off_y)) / LANDING_VIEW_CHUNK)
				parts += list(list(landing_view_world_look(chunk, LANDING_VIEW_LAYER_GROUND + 0.1), centre_off_x * ICON_SIZE_X, centre_off_y * ICON_SIZE_Y, rings_in < 1 ? 0.5 : 1))
			if(TICK_CHECK)
				stoplag()
				if(QDELETED(src) || ended)
					return
	piece.parts = parts
	log_world("LANDING_DEBUG: ground picture of [length(parts)] parts, reach [reach_x]x[reach_y], built in [(REALTIMEOFDAY - started) / 10]s")
	then?.Invoke()

/// Readies [look] to be one part of a world picture
/proc/landing_view_world_look(mutable_appearance/look, part_layer)
	look.plane = LANDING_VIEW_PLANE
	look.layer = part_layer
	look.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	return look

/**
 * One chunk of ground picture: the planet tiles from [low_x], [low_y] up, one row and column past
 * LANDING_VIEW_CHUNK so neighbouring chunks overlap and no seam opens between them when they are scaled.
 * Drawn about its own middle. Null if there is no ground there.
 * * detail - draw what stands on the ground as well
 * * own_region - the site the berth is in; ground belonging to another site is left out
 */
/proc/landing_view_chunk(low_x, low_y, z, detail, datum/own_region)
	var/centre_x = low_x + LANDING_VIEW_CHUNK / 2
	var/centre_y = low_y + LANDING_VIEW_CHUNK / 2
	// one group per world plane, floor first, as the world draws them (see /obj/effect/abstract/landing_proxy)
	var/list/plane_parts = new /list(ABOVE_GAME_PLANE - FLOOR_PLANE + 1)
	for(var/rank in 1 to length(plane_parts))
		plane_parts[rank] = list()
	var/found = FALSE
	// the light every tile here shares, if they all share one: then the whole chunk is tinted once
	var/shared_light
	var/mixed_light = FALSE
	var/list/tile_lights = list()
	for(var/tile_x in low_x to low_x + LANDING_VIEW_CHUNK)
		for(var/tile_y in low_y to low_y + LANDING_VIEW_CHUNK)
			var/turf/ground = locate(tile_x, tile_y, z)
			if(!ground || (own_region && map_region_excludes_turf(own_region, ground)))
				continue
			found = TRUE
			var/offset_w = (tile_x - centre_x) * ICON_SIZE_X
			var/offset_z = (tile_y - centre_y) * ICON_SIZE_Y
			var/turf_plane = clamp(PLANE_TO_TRUE(ground.plane), FLOOR_PLANE, ABOVE_GAME_PLANE)
			plane_parts[turf_plane - FLOOR_PLANE + 1] += landing_view_part(ground, offset_w, offset_z, TRUE)
			if(detail)
				for(var/atom/movable/thing as anything in ground)
					if(thing.invisibility > SEE_INVISIBLE_LIVING || !thing.icon || thing.alpha < 20)
						continue
					if(istype(thing, /obj/effect/abstract) || istype(thing, /obj/effect/temp_visual) || istype(thing, /obj/docking_port))
						continue
					var/true_plane = PLANE_TO_TRUE(thing.plane)
					if(true_plane < FLOOR_PLANE || true_plane > ABOVE_GAME_PLANE)
						continue
					plane_parts[true_plane - FLOOR_PLANE + 1] += landing_view_part(thing, offset_w, offset_z, FALSE)
			var/tile_light = landing_view_light(ground)
			tile_lights[++tile_lights.len] = list(tile_light, offset_w, offset_z)
			if(length(tile_lights) == 1)
				shared_light = tile_light
			else if(tile_light != shared_light)
				mixed_light = TRUE
	if(!found)
		return null
	var/list/parts = list()
	for(var/rank in 1 to length(plane_parts))
		if(!length(plane_parts[rank]))
			continue
		var/mutable_appearance/plane_group = new()
		plane_group.plane = FLOAT_PLANE
		plane_group.layer = rank
		plane_group.appearance_flags = KEEP_TOGETHER
		plane_group.overlays = plane_parts[rank]
		parts += plane_group
	var/mutable_appearance/chunk = new()
	chunk.plane = FLOAT_PLANE
	chunk.appearance_flags = KEEP_TOGETHER
	if(mixed_light || istype(shared_light, /mutable_appearance))
		for(var/list/tile_light as anything in tile_lights)
			var/light = tile_light[1]
			if(isnull(light))
				continue
			var/mutable_appearance/quad
			if(istext(light))
				quad = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
				quad.color = light
			else
				quad = new(light)
			quad.plane = FLOAT_PLANE
			quad.layer = 100
			quad.blend_mode = BLEND_MULTIPLY
			quad.pixel_w = tile_light[2]
			quad.pixel_z = tile_light[3]
			parts += quad
	else if(istext(shared_light))
		chunk.color = shared_light
	chunk.overlays = parts
	return chunk

/// A copy of [thing]'s look for a ground picture, shifted by [offset_w], [offset_z]: only what the world planes
/// would draw of it, without its light or anything that glows on a plane of its own
/proc/landing_view_part(atom/thing, offset_w, offset_z, is_turf)
	var/mutable_appearance/part = new(thing)
	part.plane = FLOAT_PLANE
	part.pixel_w += offset_w
	part.pixel_z += offset_z
	part.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	if(is_turf && length(part.underlays))
		var/list/kept = list()
		for(var/mutable_appearance/under as anything in part.underlays)
			if(PLANE_TO_TRUE(under.plane) != LIGHTING_PLANE)
				kept += under
		part.underlays = kept
	if(length(part.overlays))
		var/list/kept
		for(var/mutable_appearance/over as anything in part.overlays)
			var/keep = !(over.appearance_flags & KEEP_APART)
			if(keep && over.plane != FLOAT_PLANE)
				var/true_plane = PLANE_TO_TRUE(over.plane)
				keep = (true_plane >= FLOOR_PLANE && true_plane <= ABOVE_GAME_PLANE)
			if(keep)
				continue
			kept ||= part.overlays.Copy()
			kept -= over
		if(kept)
			part.overlays = kept
	return part

/**
 * The light on [ground], to multiply over its tile in a picture: null for full light, a colour for a flat one
 * (daylight on open ground), or an appearance to lay over the tile (ground with a lighting object of its own).
 */
/proc/landing_view_light(turf/ground)
	var/area/ground_area = ground.loc
	var/ambient
	if(ground_area.base_lighting_alpha)
		var/list/parts = rgb2num(ground_area.base_lighting_color == COLOR_STARLIGHT ? GLOB.starlight_color : ground_area.base_lighting_color)
		var/strength = ground_area.base_lighting_alpha / 255
		ambient = rgb(parts[1] * strength, parts[2] * strength, parts[3] * strength)
	var/mutable_appearance/own = ground.lighting_object?.current_underlay
	if(!own)
		if(ambient)
			return ambient == "#ffffff" ? null : ambient
		// no light of any kind reaches it: space and the like light themselves, anything else is dark
		return (ground_area.static_lighting && !isspaceturf(ground)) ? "#000000" : null
	if(!ambient)
		var/mutable_appearance/quad = new(own)
		quad.appearance_flags = RESET_COLOR
		return quad
	// both: its own light with the daylight added
	var/mutable_appearance/base = new(own)
	base.plane = FLOAT_PLANE
	base.layer = 1
	base.appearance_flags = RESET_COLOR
	var/mutable_appearance/day = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
	day.color = ambient
	day.blend_mode = BLEND_ADD
	day.layer = 2
	var/mutable_appearance/both = new()
	both.appearance_flags = KEEP_TOGETHER | RESET_COLOR
	both.overlays = list(base, day)
	return both

#undef LANDING_VIEW_STEP
#undef LANDING_VIEW_SYNC
#undef LANDING_VIEW_CHUNK
