/**
 * The ground around a berth, as pictures for the landing view (see landing_view.dm).
 *
 * Three pictures of the same ground, drawn about the same middle, each finer and reaching less far:
 *
 * - From afar: two small images of the country around the berth in its own colours, a couple of pixels to the
 *   tile for the whole of it and a quarter of full size for the part nearer the berth. Single sprites, so the
 *   whole planet can be on the screen at once for nothing. Scaled up smooth they look like ground seen through
 *   a mile of air, which it is.
 * - Close up: the real tiles near the berth and everything standing on them, copied, in small chunks. Exact, so
 *   the hull can move onto it without anything changing, and costly to draw, so it is only shown once the
 *   ground is near, and each viewer only holds the chunks their own screen can show
 *   (see /datum/landing_view/proc/give_picture).
 *
 * The first fades into the second as the ground comes up (see chain_ground()).
 *
 * None of them carries any light. The view is lit like the rest of the game, by the lighting plate, which over
 * transit space is full light. So the light on the ground is a picture too (see bake_light()): two small images
 * of it, drawn on a plane of their own over the lighting of the transit space around the hull. The game's own
 * lighting then does the rest, for every kind of eye: a cave is as dark to its crew, and as dim to a ghost, in
 * the picture as it will be when the hull is down in it.
 */

/// Tiles per side of one chunk of the close-up picture
#define LANDING_VIEW_CHUNK 8
/// How far from the hull's box the cordon strip at the edge of a site is still drawn in the close-up picture
#define LANDING_VIEW_CORDON_REACH 14
/// The two pictures from afar: how far each reaches from the berth's middle, in tiles, and its pixels to the tile
#define LANDING_AERIAL_FAR_REACH 64
#define LANDING_AERIAL_FAR_GRAIN 2
#define LANDING_AERIAL_NEAR_REACH 36
#define LANDING_AERIAL_NEAR_GRAIN 8
/// How long a picture from afar may be used again for the same berth
#define LANDING_AERIAL_KEEP (10 MINUTES)
/// The two pictures of the light: how far each reaches from the berth's middle, in tiles, and its pixels to the tile
#define LANDING_LIGHT_FAR_REACH 64
#define LANDING_LIGHT_FAR_GRAIN 2
#define LANDING_LIGHT_NEAR_REACH 36
#define LANDING_LIGHT_NEAR_GRAIN 4
/// The ground's size between which the close-up picture fades in over the ones from afar
#define LANDING_DETAIL_FROM 0.75
#define LANDING_DETAIL_FULL 0.9
/// The most tiles a viewer sees each way; with LANDING_DETAIL_FROM it sets how far the close-up picture has to reach
#define LANDING_DETAIL_SIGHT 14
/// And the most it will reach past the hull's box, however big the hull
#define LANDING_DETAIL_MOST 30

/// How far past the hull's box the close-up picture reaches
/datum/landing_view/proc/detail_reach()
	var/half = max(ground_half_w, ground_half_h)
	return min(LANDING_DETAIL_MOST, CEILING((half + LANDING_DETAIL_SIGHT) / LANDING_DETAIL_FROM - half, 1))

/**
 * Sets [close]'s opacity and the moments it is handed to viewers and taken back, from the size of the ground
 * over time: the close-up picture is there while the ground is big enough to tell it from the picture from afar.
 * * far - the picture from afar, whose size track both share
 */
/datum/landing_view/proc/chain_ground(datum/landing_view_piece/far, datum/landing_view_piece/close)
	close.scale = far.scale
	close.slide_x = far.slide_x
	close.slide_y = far.slide_y
	close.alpha = new
	close.cull_from = LANDING_DETAIL_FROM
	var/datum/landing_track/size = far.scale
	var/start = size.times[1]
	var/finish = size.end_time()
	var/first_seen
	var/last_seen
	var/last_share
	var/last_when
	for(var/moment = start, moment < finish + 1, moment += 1)
		var/when = min(moment, finish)
		var/share = clamp((size.at(when) - LANDING_DETAIL_FROM) / (LANDING_DETAIL_FULL - LANDING_DETAIL_FROM), 0, 1)
		if(isnull(last_share))
			close.alpha.mark(when, share * 255)
		else if(share != last_share)
			// leaving a level stretch: pin where it ended. Arriving on one: pin where it begins.
			if(last_share <= 0 || last_share >= 1)
				close.alpha.mark(last_when, last_share * 255)
			if(share <= 0 || share >= 1)
				close.alpha.mark(when, share * 255)
		last_share = share
		last_when = when
		if(share > 0)
			first_seen ||= when
			last_seen = when
	close.alpha.mark(finish, last_share * 255)
	if(isnull(first_seen))
		close.give_at = INFINITY
		return
	// held from the start if it starts in sight, to the end if it ends in sight. Handed over a little early,
	// still clear, a few chunks a tick
	close.give_at = first_seen > start ? first_seen - 0.8 SECONDS : 0
	close.drop_at = last_seen < finish ? last_seen + 2 : INFINITY

/**
 * Before the ground's motion is known (a hull still on its berth), its pictures can be handed out, clear and
 * still, so the people aboard already hold them when it lifts.
 */
/datum/landing_view/proc/hold_ground(datum/landing_view_piece/far, datum/landing_view_piece/close, datum/landing_view_piece/light)
	far.held_back = TRUE
	close.held_back = TRUE
	close.cull_from = LANDING_DETAIL_FROM
	light.held_back = TRUE

/**
 * Builds the pictures of the ground from afar and hands them to [piece]. Takes a few ticks; [then] is called
 * when it is done.
 */
/datum/landing_view/proc/bake_far(datum/landing_view_piece/piece, datum/callback/then)
	set waitfor = FALSE
	var/tone = ground_tone() || palette?.sky || "#808080"
	var/list/berth_set = list()
	for(var/turf/berth_turf as anything in berth_turfs)
		berth_set[berth_turf] = TRUE
	var/middle_x = round(ground_x)
	var/middle_y = round(ground_y)
	// under them and beyond their edges: more of the same, out of focus
	var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
	sheet.color = tone
	sheet.transform = matrix().Scale(400)
	var/mutable_appearance/beyond = landing_view_world_look(new /mutable_appearance, LANDING_VIEW_LAYER_GROUND)
	beyond.overlays = list(sheet)
	var/list/parts = list(list(beyond, 0, 0, 1, 0))
	var/list/grains = list(list(LANDING_AERIAL_FAR_REACH, LANDING_AERIAL_FAR_GRAIN), list(LANDING_AERIAL_NEAR_REACH, LANDING_AERIAL_NEAR_GRAIN))
	for(var/rank in 1 to length(grains))
		var/list/grain = grains[rank]
		var/icon/aerial = landing_view_aerial(middle_x, middle_y, ground_z, berth_set, tone, grain[1], grain[2])
		if(QDELETED(src) || ended)
			return
		if(!aerial)
			continue
		var/size = aerial.Width()
		var/mutable_appearance/country = mutable_appearance(aerial)
		// its own middle on the image's, and drawn at a tile's worth of pixels to the tile
		country.pixel_w = -(size - ICON_SIZE_X) / 2
		country.pixel_z = -(size - ICON_SIZE_Y) / 2
		country.transform = matrix().Scale(ICON_SIZE_X / grain[2])
		var/mutable_appearance/far = landing_view_world_look(new /mutable_appearance, LANDING_VIEW_LAYER_GROUND + 0.02 * rank)
		far.overlays = list(country)
		// the picture's middle is the corner between four tiles; ours is the middle of the hull's box
		parts += list(list(far, (middle_x - 0.5 - ground_x) * ICON_SIZE_X, (middle_y - 0.5 - ground_y) * ICON_SIZE_Y, 1, 0))
	piece.parts = parts
	then?.Invoke()

/**
 * A small picture of the ground for [reach] tiles each way from [mid_x], [mid_y], [grain] pixels to the tile:
 * every tile and what stands on it, shrunk, in its own colours with no light on it (see bake_light()). Kept a
 * while and used again for the same spot. Takes a few ticks. Null if it could not be made.
 * * under_hull - the berth's turfs: where a hull stands on them, the ground it stands on is drawn instead
 * * fill_tone - the colour of everything that is not this site's ground
 */
/proc/landing_view_aerial(mid_x, mid_y, z, list/under_hull, fill_tone, reach, grain)
	var/static/list/kept = list()
	var/key = "[mid_x],[mid_y],[z],[reach],[grain]"
	var/list/had = kept[key]
	if(had && had[2] > world.time)
		return had[1]
	var/turf/middle = locate(mid_x, mid_y, z)
	if(!middle)
		return null
	var/datum/own_region = map_region_for_turf(middle)
	var/static/list/unlit = list(1, 1, 1)
	var/side = reach * 2 * grain
	// every pixel, top row first
	var/list/cells = new /list(side * side)
	var/low_x = mid_x - reach
	var/low_y = mid_y - reach
	// tiles with something standing on them, north to south, so what stands nearer is drawn over what is behind
	var/list/turf/occupied = list()
	// tiles whose own icon reaches past them (grass and its fringe) -> list(its tones, cells it is drawn right, cells up)
	var/list/fringed = list()
	for(var/tile_y = mid_y + reach - 1, tile_y >= low_y, tile_y--)
		var/cell_y = (tile_y - low_y) * grain
		for(var/tile_x in low_x to mid_x + reach - 1)
			var/turf/ground = locate(tile_x, tile_y, z)
			var/list/tones
			// how far the icon is drawn from the tile's corner, in pixels
			var/off_x = 0
			var/off_y = 0
			if(ground && !istype(ground, /turf/cordon) && !(own_region && map_region_excludes_turf(own_region, ground)))
				var/turf/bare = under_hull[ground] ? landing_view_ground_under(ground) : null
				if(bare)
					tones = landing_view_tones(initial(bare.icon), initial(bare.icon_state), SOUTH, null, unlit, grain)
					off_x = initial(bare.pixel_x)
					off_y = initial(bare.pixel_y)
				else if(!under_hull[ground] || !istype(ground.loc, /area/shuttle))
					tones = landing_view_tones(ground.icon, ground.icon_state, ground.dir, ground.color, unlit, grain)
					off_x = ground.pixel_x + ground.pixel_w
					off_y = ground.pixel_y + ground.pixel_z
					if(!under_hull[ground] && length(ground.contents))
						occupied += ground
			var/cell_x = (tile_x - low_x) * grain
			var/tone_rows = length(tones)
			var/shift_x = round(off_x * grain / ICON_SIZE_X, 1)
			var/shift_y = round(off_y * grain / ICON_SIZE_Y, 1)
			if(tone_rows && (shift_x || shift_y || tone_rows > grain || length(tones[1]) > grain))
				fringed[ground] = list(tones, shift_x, shift_y)
			for(var/row in 1 to grain)
				var/from_row = row - shift_y
				var/list/line = (from_row >= 1 && from_row <= tone_rows) ? tones[from_row] : null
				var/line_length = length(line)
				var/base = (side - cell_y - row) * side + cell_x
				for(var/col in 1 to grain)
					var/from_col = col - shift_x
					cells[base + col] = (from_col >= 1 && from_col <= line_length && line[from_col]) || fill_tone
		if(TICK_CHECK)
			stoplag()
	// the fringes, over the tiles beside them
	for(var/turf/ground as anything in fringed)
		var/list/fringe = fringed[ground]
		landing_view_stamp(cells, side, fringe[1], (ground.x - low_x) * grain + fringe[2], (ground.y - low_y) * grain + fringe[3])
		if(TICK_CHECK)
			stoplag()
	for(var/turf/ground as anything in occupied)
		var/list/standing
		for(var/atom/movable/thing as anything in ground)
			// nothing that moves about, and nothing too small to tell from up here
			if(ismob(thing) || isitem(thing) || thing.invisibility > SEE_INVISIBLE_LIVING || !thing.icon || thing.alpha < 128)
				continue
			if(istype(thing, /obj/effect/abstract) || istype(thing, /obj/effect/temp_visual) || istype(thing, /obj/docking_port))
				continue
			var/true_plane = PLANE_TO_TRUE(thing.plane)
			if(true_plane < FLOOR_PLANE || true_plane > ABOVE_GAME_PLANE)
				continue
			// lowest first
			var/place = 1
			for(var/atom/movable/other as anything in standing)
				if(other.layer > thing.layer)
					break
				place++
			LAZYINITLIST(standing)
			standing.Insert(place, thing)
		if(!standing)
			continue
		for(var/atom/movable/thing as anything in standing)
			var/list/tones = landing_view_tones(thing.icon, thing.icon_state, thing.dir, thing.color, unlit, grain)
			var/shift_x = (ground.x - low_x) * grain + round((thing.pixel_x + thing.pixel_w) * grain / ICON_SIZE_X, 1)
			var/shift_y = (ground.y - low_y) * grain + round((thing.pixel_y + thing.pixel_z) * grain / ICON_SIZE_Y, 1)
			landing_view_stamp(cells, side, tones, shift_x, shift_y)
		if(TICK_CHECK)
			stoplag()
	var/path = "data/landing_view/[z]_[mid_x]_[mid_y]_[grain].png"
	if(!fexists("data/landing_view/made"))
		text2file("", "data/landing_view/made") // makes the folder
	var/failed = rustg_dmi_create_png(path, "[side]", "[side]", cells.Join(""))
	if(failed)
		stack_trace("No picture of the ground for a landing view: [failed]")
		return null
	var/icon/aerial = new(path)
	// gone over once by the engine, which then keeps it as a picture of its own making: the few colours it has
	// make that a far smaller file for a client to fetch than the one written above
	aerial.Blend("#ffffff", ICON_MULTIPLY)
	kept[key] = list(aerial, world.time + LANDING_AERIAL_KEEP)
	return aerial

/// Draws [tones] (see landing_view_tones()) into a picture's [cells], its lower left corner [shift_x] cells in and [shift_y] up
/proc/landing_view_stamp(list/cells, side, list/tones, shift_x, shift_y)
	for(var/row in 1 to length(tones))
		var/at_y = shift_y + row - 1
		if(at_y < 0 || at_y >= side)
			continue
		var/list/line = tones[row]
		var/base = (side - 1 - at_y) * side + shift_x
		for(var/col in 1 to length(line))
			var/tone = line[col]
			if(!tone || shift_x + col < 1 || shift_x + col > side)
				continue
			cells[base + col] = tone

/// The kind of ground a hull standing on [ground] landed on, if one stands there
/proc/landing_view_ground_under(turf/ground)
	var/list/under = ground.baseturfs
	if(!islist(under))
		return null
	var/marker = under.Find(/turf/baseturf_skipover/shuttle)
	return marker > 1 ? under[marker - 1] : null

/**
 * An icon state shrunk to [grain] pixels to the tile, as it looks under [light] (see landing_view_light_factor())
 * and tinted [tint]: its rows, bottom row first, each a list of colours with null where nothing is drawn.
 * Worked out once for each look.
 */
/proc/landing_view_tones(icon_file, state, dir, tint, list/light, grain)
	var/static/list/known = list()
	// a sixteenth of full light is as fine as anyone can tell
	var/red = round(light[1] * 16)
	var/green = round(light[2] * 16)
	var/blue = round(light[3] * 16)
	if(!istext(tint))
		tint = null
	var/key = "[icon_file]|[state]|[dir]|[grain]|[tint]|[red],[green],[blue]"
	var/list/tones = known[key]
	if(tones)
		return tones
	var/list/tint_parts = tint ? rgb2num(tint) : null
	var/red_share = red / 16 * (tint_parts ? tint_parts[1] / 255 : 1)
	var/green_share = green / 16 * (tint_parts ? tint_parts[2] / 255 : 1)
	var/blue_share = blue / 16 * (tint_parts ? tint_parts[3] / 255 : 1)
	tones = list()
	for(var/list/line as anything in landing_view_icon_grid(icon_file, state, dir, grain))
		var/list/lit = new /list(length(line))
		for(var/col in 1 to length(line))
			var/list/cell = line[col]
			if(cell)
				// sixteen levels of each: few enough colours that the picture is a small file for a client to fetch
				lit[col] = rgb(round(cell[1] * red_share, 17), round(cell[2] * green_share, 17), round(cell[3] * blue_share, 17))
		tones += list(lit)
	known[key] = tones
	return tones

/**
 * An icon state shrunk to [grain] pixels to the tile: its rows, bottom row first, each a list of
 * list(red, green, blue) with null where it is clear. Worked out once for each state.
 */
/proc/landing_view_icon_grid(icon_file, state, dir, grain)
	var/static/list/known = list()
	// some things keep a bitmask in their dir (pipes), and asking an icon for a pixel facing a way that is no
	// way at all never comes back
	var/static/list/real_dirs = list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
	if(!(dir in real_dirs))
		dir = SOUTH
	var/key = "[icon_file]|[state]|[dir]|[grain]"
	var/list/grid = known[key]
	if(grid)
		return grid
	grid = list()
	known[key] = grid
	if(!icon_file)
		return grid
	// one icon for the whole file, read a state at a time: cutting a state out into an icon of its own is slow
	var/static/list/sheets = list()
	var/icon/sample = sheets["[icon_file]"]
	if(!sample)
		sample = icon(icon_file)
		sheets["[icon_file]"] = sample
	var/width = sample.Width()
	var/height = sample.Height()
	var/stride = ICON_SIZE_X / grain
	var/near = 1 + round(stride * 0.3)
	var/far = 1 + round(stride * 0.7)
	for(var/row in 1 to CEILING(height / stride, 1))
		var/list/line = new /list(CEILING(width / stride, 1))
		var/from_y = (row - 1) * stride
		for(var/col in 1 to length(line))
			var/from_x = (col - 1) * stride
			// two pixels on the cell's diagonal
			var/list/total
			var/found = 0
			for(var/reach in list(near, far))
				var/pixel = sample.GetPixel(min(width, from_x + reach), min(height, from_y + reach), state, dir, 1)
				if(!pixel)
					continue
				var/list/parts = rgb2num(pixel)
				if(length(parts) > 3 && parts[4] < 128)
					continue
				if(total)
					total[1] += parts[1]
					total[2] += parts[2]
					total[3] += parts[3]
				else
					total = list(parts[1], parts[2], parts[3])
				found++
			if(found > 1)
				total[1] /= found
				total[2] /= found
				total[3] /= found
			line[col] = total
		grid += list(line)
	return grid

/// How much of each of red, green and blue reaches [ground], each 0-1
/proc/landing_view_light_factor(turf/ground)
	var/static/list/full = list(1, 1, 1)
	var/static/list/none = list(0, 0, 0)
	var/area/ground_area = ground.loc
	var/list/day
	if(ground_area.base_lighting_alpha)
		var/list/parts = rgb2num(ground_area.base_lighting_color == COLOR_STARLIGHT ? GLOB.starlight_color : ground_area.base_lighting_color)
		var/strength = ground_area.base_lighting_alpha / 255 / 255
		day = list(parts[1] * strength, parts[2] * strength, parts[3] * strength)
	if(!ground.lighting_object)
		if(day)
			return day
		return (ground_area.static_lighting && !isspaceturf(ground)) ? none : full
	var/own = ground.get_lumcount()
	if(!day)
		return list(own, own, own)
	return list(min(1, day[1] + own), min(1, day[2] + own), min(1, day[3] + own))

/**
 * The tone of the ground around the berth: the colour of a few tiles of it, some way out all round, as they are
 * lit. Null if there is none to be found.
 */
/datum/landing_view/proc/ground_tone()
	var/datum/own_region = map_region_for_turf(berth_turfs[1])
	var/list/total = list(0, 0, 0)
	var/found = 0
	for(var/bearing in 0 to 315 step 45)
		for(var/far in list(10, 22, 34))
			var/turf/ground = locate(round(ground_x + sin(bearing) * (ground_half_w + far)), round(ground_y + cos(bearing) * (ground_half_h + far)), ground_z)
			if(!ground || isclosedturf(ground) || istype(ground, /turf/cordon) || (own_region && map_region_excludes_turf(own_region, ground)))
				continue
			for(var/list/line as anything in landing_view_tones(ground.icon, ground.icon_state, ground.dir, ground.color, landing_view_light_factor(ground), LANDING_AERIAL_FAR_GRAIN))
				for(var/tone in line)
					if(!tone)
						continue
					var/list/parts = rgb2num(tone)
					total[1] += parts[1]
					total[2] += parts[2]
					total[3] += parts[3]
					found++
	if(!found)
		return null
	return rgb(total[1] / found, total[2] / found, total[3] / found)

/**
 * Builds the close-up picture of the ground around the berth and adds it to [piece]'s parts. Takes a few ticks;
 * [then] is called when it is done.
 * * reach - how many tiles past the hull's box the picture goes
 * * which - LANDING_GROUND_ALL, or one of the two halves a takeoff draws it in: the ground around the hull
 *   before it lifts, and the ground under it once it has
 * * in_one_go - build it all now, however long it takes, instead of over a few ticks
 */
/datum/landing_view/proc/bake_near(datum/landing_view_piece/piece, reach, datum/callback/then, which = LANDING_GROUND_ALL, in_one_go = FALSE)
	set waitfor = FALSE
	var/reach_x = CEILING(ground_half_w + reach, LANDING_VIEW_CHUNK)
	var/reach_y = CEILING(ground_half_h + reach, LANDING_VIEW_CHUNK)
	// the edge of a site's ground is a strip of cordon. Near the berth it is drawn, as it will be seen once the
	// hull is down; further off it is left out, so the ground does not end in a painted line seen from above
	var/list/cordon_box = list(ground_x - ground_half_w - LANDING_VIEW_CORDON_REACH, ground_y - ground_half_h - LANDING_VIEW_CORDON_REACH, ground_x + ground_half_w + LANDING_VIEW_CORDON_REACH, ground_y + ground_half_h + LANDING_VIEW_CORDON_REACH)
	var/list/parts = list()
	// the chunks the hull's own box touches
	var/under_x = CEILING(ground_half_w + 1, LANDING_VIEW_CHUNK)
	var/under_y = CEILING(ground_half_h + 1, LANDING_VIEW_CHUNK)
	var/datum/own_region = map_region_for_turf(berth_turfs[1])
	// area -> the weather over it, found once
	var/list/weather_by_area = list()
	var/middle_x = round(ground_x)
	var/middle_y = round(ground_y)
	for(var/chunk_x = middle_x - reach_x, chunk_x < middle_x + reach_x, chunk_x += LANDING_VIEW_CHUNK)
		for(var/chunk_y = middle_y - reach_y, chunk_y < middle_y + reach_y, chunk_y += LANDING_VIEW_CHUNK)
			if(which != LANDING_GROUND_ALL)
				var/under_hull = chunk_x >= middle_x - under_x && chunk_x < middle_x + under_x && chunk_y >= middle_y - under_y && chunk_y < middle_y + under_y
				if(under_hull != (which == LANDING_GROUND_UNDER))
					continue
			var/mutable_appearance/chunk = landing_view_chunk(chunk_x, chunk_y, ground_z, own_region, weather_by_area, cordon_box)
			if(chunk)
				var/centre_off_x = chunk_x + LANDING_VIEW_CHUNK / 2 - ground_x
				var/centre_off_y = chunk_y + LANDING_VIEW_CHUNK / 2 - ground_y
				// the last number: how far it reaches from its middle, in tiles, with room for what overhangs it
				parts += list(list(landing_view_world_look(chunk, LANDING_VIEW_LAYER_GROUND + 0.1), centre_off_x * ICON_SIZE_X, centre_off_y * ICON_SIZE_Y, 1, LANDING_VIEW_CHUNK / 2 + 2))
			if(!in_one_go && TICK_CHECK)
				stoplag()
				if(QDELETED(src) || ended)
					return
	piece.parts = (piece.parts || list()) + parts
	then?.Invoke()

/// The furthest from the berth's middle the ground is seen, in tiles: past it there is only cloud
#define LANDING_VEIL_HOLE 30
/// One billow of the cloud's edge, in tiles across, and how far apart they stand along it
#define LANDING_VEIL_PUFF 16
#define LANDING_VEIL_STEP 5
/// The ground's size between which the cloud around it is there in full and gone
#define LANDING_VEIL_FULL 0.8
#define LANDING_VEIL_GONE 0.97

/**
 * How far this site's own ground reaches from the berth's middle, in tiles, each way: list(east, west, north,
 * south), none more than LANDING_VEIL_HOLE. A berth can stand right by the edge of its site, and past that edge
 * there is nothing to show.
 */
/datum/landing_view/proc/ground_extent()
	var/datum/own_region = map_region_for_turf(berth_turfs[1])
	var/middle_x = round(ground_x)
	var/middle_y = round(ground_y)
	var/list/extent = list()
	for(var/list/way as anything in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
		var/reach = LANDING_VEIL_HOLE
		// along the middle of the hull's box and along both its sides
		var/half_across = way[1] ? ground_half_h : ground_half_w
		for(var/out in 1 to LANDING_VEIL_HOLE)
			var/ended = FALSE
			for(var/across in list(0, -round(half_across), round(half_across)))
				var/turf/ground = locate(middle_x + way[1] * out + (way[2] ? across : 0), middle_y + way[2] * out + (way[1] ? across : 0), ground_z)
				if(!ground || istype(ground, /turf/cordon) || isspaceturf(ground) || (own_region && map_region_excludes_turf(own_region, ground)))
					ended = TRUE
					break
			if(ended)
				reach = out - 1
				break
		extent += reach
	return extent

/**
 * The cloud the ground is seen through: everything past the site's own ground, or past LANDING_VEIL_HOLE tiles
 * from the berth's middle if the site goes on further, with a billowing edge. The pictures of the ground only
 * reach so far, get coarser as they go, and end where the site ends; this lies over all of that, so no edge of
 * any of them is ever seen. The opening widens as the ground comes up and closes in as it falls away.
 * Returns the parts of a world picture.
 * * for_light - the same shapes in full light, for the light plane: cloud is lit by the sky, not by the ground under it
 */
/datum/landing_view/proc/cloud_veil(for_light = FALSE)
	var/list/parts = list()
	var/tone = for_light ? COLOR_WHITE : (palette?.cloud || COLOR_WHITE)
	var/part_layer = for_light ? 3 : LANDING_VIEW_LAYER_GROUND + 0.6
	var/list/extent = ground_extent()
	// where the cloud's sheets begin each way: their billows reach half a billow further in, to just short of the site's edge
	var/east = extent[1] + LANDING_VEIL_PUFF / 2 - 3
	var/west = extent[2] + LANDING_VEIL_PUFF / 2 - 3
	var/north = extent[3] + LANDING_VEIL_PUFF / 2 - 3
	var/south = extent[4] + LANDING_VEIL_PUFF / 2 - 3
	// four sheets around the opening: list(middle x, middle y, tiles wide, tiles high)
	for(var/list/sheet_at as anything in list(list(east + 100, 0, 200, 600), list(-west - 100, 0, 200, 600), list(0, north + 100, 600, 200), list(0, -south - 100, 600, 200)))
		var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
		sheet.color = tone
		sheet.transform = matrix().Scale(sheet_at[3], sheet_at[4])
		var/mutable_appearance/look = landing_view_world_look(new /mutable_appearance, part_layer)
		if(for_light)
			look.plane = LANDING_VIEW_LIGHT_PLANE
		look.overlays = list(sheet)
		parts += list(list(look, sheet_at[1] * ICON_SIZE_X, sheet_at[2] * ICON_SIZE_Y, 1, 0))
	// and billows all along its edge
	var/list/spots = list()
	for(var/along = -west, along <= east, along += LANDING_VEIL_STEP)
		spots += list(list(along, north), list(along, -south))
	for(var/along = -south, along <= north, along += LANDING_VEIL_STEP)
		spots += list(list(east, along), list(-west, along))
	var/turned = 0
	for(var/list/spot as anything in spots)
		var/mutable_appearance/puff = mutable_appearance(LANDING_VIEW_ICON, "puff", appearance_flags = RESET_COLOR)
		puff.color = tone
		puff.pixel_w = -(LANDING_VIEW_ICON_SIZE - ICON_SIZE_X) / 2
		puff.pixel_z = -(LANDING_VIEW_ICON_SIZE - ICON_SIZE_Y) / 2
		// no two alike: each turned and sized a little differently
		turned += 67
		var/matrix/billow = matrix()
		billow.Scale(LANDING_VEIL_PUFF * ICON_SIZE_X / 361 * (0.85 + (turned % 40) / 100))
		billow.Turn(turned)
		puff.transform = billow
		var/mutable_appearance/look = landing_view_world_look(new /mutable_appearance, part_layer + 0.01)
		if(for_light)
			look.plane = LANDING_VIEW_LIGHT_PLANE
		look.overlays = list(puff)
		parts += list(list(look, spot[1] * ICON_SIZE_X, spot[2] * ICON_SIZE_Y, 1, 0))
	return parts

/**
 * How opaque the cloud around the ground is over time, from the ground's [size]: whole while the ground is small,
 * gone by the time it is full size, when what lies past the site's edge is whatever the game itself shows there.
 */
/datum/landing_view/proc/veil_fade(datum/landing_track/size)
	var/datum/landing_track/fade = new
	var/start = size.times[1]
	var/finish = size.end_time()
	for(var/moment = start, moment < finish + 2, moment += 2)
		var/when = min(moment, finish)
		fade.mark(when, clamp((LANDING_VEIL_GONE - size.at(when)) / (LANDING_VEIL_GONE - LANDING_VEIL_FULL), 0, 1) * 255)
	return fade

/// Readies [look] to be one part of a world picture
/proc/landing_view_world_look(mutable_appearance/look, part_layer)
	look.plane = LANDING_VIEW_PLANE
	look.layer = part_layer
	look.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	return look

/**
 * One chunk of the close-up picture: the planet tiles from [low_x], [low_y] up, one row and column past
 * LANDING_VIEW_CHUNK so neighbouring chunks overlap and no seam opens between them when they are scaled.
 * Drawn about its own middle, with everything standing on it, and no light on any of it (see bake_light()).
 * Null if there is no ground there.
 * * own_region - the site the berth is in; ground belonging to another site is left out
 * * weather_by_area - area -> landing_view_weather() of it, filled in as areas are met
 * * cordon_box - list(low x, low y, high x, high y): cordon turfs outside it are left out
 */
/proc/landing_view_chunk(low_x, low_y, z, datum/own_region, list/weather_by_area, list/cordon_box)
	var/centre_x = low_x + LANDING_VIEW_CHUNK / 2
	var/centre_y = low_y + LANDING_VIEW_CHUNK / 2
	// one group per world plane, floor first, as the world draws them (see /obj/effect/abstract/landing_proxy)
	var/list/plane_parts = new /list(ABOVE_GAME_PLANE - FLOOR_PLANE + 1)
	for(var/rank in 1 to length(plane_parts))
		plane_parts[rank] = list()
	var/found = FALSE
	var/list/storm_parts = list()
	for(var/tile_x in low_x to low_x + LANDING_VIEW_CHUNK)
		for(var/tile_y in low_y to low_y + LANDING_VIEW_CHUNK)
			var/turf/ground = locate(tile_x, tile_y, z)
			if(!ground || (own_region && map_region_excludes_turf(own_region, ground)))
				continue
			if(istype(ground, /turf/cordon) && (tile_x < cordon_box[1] || tile_y < cordon_box[2] || tile_x > cordon_box[3] || tile_y > cordon_box[4]))
				continue
			found = TRUE
			var/offset_w = (tile_x - centre_x) * ICON_SIZE_X
			var/offset_z = (tile_y - centre_y) * ICON_SIZE_Y
			var/turf_plane = clamp(PLANE_TO_TRUE(ground.plane), FLOOR_PLANE, ABOVE_GAME_PLANE)
			plane_parts[turf_plane - FLOOR_PLANE + 1] += landing_view_part(ground, offset_w, offset_z, TRUE)
			for(var/atom/movable/thing as anything in ground)
				if(thing.invisibility > SEE_INVISIBLE_LIVING || !thing.icon || thing.alpha < 20)
					continue
				if(istype(thing, /obj/effect/abstract) || istype(thing, /obj/effect/temp_visual) || istype(thing, /obj/docking_port))
					continue
				var/true_plane = PLANE_TO_TRUE(thing.plane)
				if(true_plane < FLOOR_PLANE || true_plane > ABOVE_GAME_PLANE)
					continue
				plane_parts[true_plane - FLOOR_PLANE + 1] += landing_view_part(thing, offset_w, offset_z, FALSE)
			var/list/storm = weather_by_area[ground.loc]
			if(isnull(storm))
				storm = landing_view_weather(ground.loc)
				weather_by_area[ground.loc] = storm
			for(var/mutable_appearance/falling as anything in storm)
				var/mutable_appearance/over_tile = new(falling)
				over_tile.pixel_w = offset_w
				over_tile.pixel_z = offset_z
				storm_parts += over_tile
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
	if(length(storm_parts))
		// over everything standing there, as the world draws weather
		var/mutable_appearance/storm_group = new()
		storm_group.plane = FLOAT_PLANE
		storm_group.layer = 50
		storm_group.appearance_flags = KEEP_TOGETHER
		storm_group.overlays = storm_parts
		parts += storm_group
	var/mutable_appearance/chunk = new()
	chunk.plane = FLOAT_PLANE
	chunk.appearance_flags = KEEP_TOGETHER
	chunk.overlays = parts
	return chunk

/// The weather falling on every tile of [ground_area] right now, as looks for a ground picture (none: an empty list)
/proc/landing_view_weather(area/ground_area)
	. = list()
	for(var/mutable_appearance/over as anything in ground_area.overlays)
		if(over.plane != WEATHER_PLANE)
			continue
		var/mutable_appearance/falling = new(over)
		falling.plane = FLOAT_PLANE
		falling.appearance_flags = NONE
		. += falling

/**
 * A copy of [thing]'s look for a ground picture, shifted by [offset_w], [offset_z]: only what the world planes
 * would draw of it, without its light or anything that glows on a plane of its own.
 */
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
 * Builds the pictures of the light on the ground and hands them to [piece], whose parts go on the light plane.
 * Takes a few ticks; [then] is called when it is done.
 *
 * What a landed hull's own lamps throw on dark ground beside it is not in them: on a dark site that light comes
 * on as the hull touches down.
 */
/datum/landing_view/proc/bake_light(datum/landing_view_piece/piece, datum/callback/then)
	set waitfor = FALSE
	var/middle_x = round(ground_x)
	var/middle_y = round(ground_y)
	var/list/berth_set = list()
	for(var/turf/berth_turf as anything in berth_turfs)
		berth_set[berth_turf] = TRUE
	var/list/parts = list()
	var/list/grains = list(list(LANDING_LIGHT_FAR_REACH, LANDING_LIGHT_FAR_GRAIN), list(LANDING_LIGHT_NEAR_REACH, LANDING_LIGHT_NEAR_GRAIN))
	for(var/rank in 1 to length(grains))
		var/list/grain = grains[rank]
		var/icon/light_map = light_map(middle_x, middle_y, grain[1], grain[2], berth_set)
		if(QDELETED(src) || ended)
			return
		if(!light_map)
			continue
		var/size = light_map.Width()
		var/mutable_appearance/sheet = mutable_appearance(light_map)
		sheet.pixel_w = -(size - ICON_SIZE_X) / 2
		sheet.pixel_z = -(size - ICON_SIZE_Y) / 2
		sheet.transform = matrix().Scale(ICON_SIZE_X / grain[2])
		var/mutable_appearance/look = landing_view_world_look(new /mutable_appearance, rank)
		look.plane = LANDING_VIEW_LIGHT_PLANE
		look.overlays = list(sheet)
		parts += list(list(look, (middle_x - 0.5 - ground_x) * ICON_SIZE_X, (middle_y - 0.5 - ground_y) * ICON_SIZE_Y, 1, 0))
	piece.parts = parts
	then?.Invoke()

/**
 * A picture of the light on the ground for [reach] tiles each way from [mid_x], [mid_y], [grain] pixels to the
 * tile: for every tile, what the lighting plane holds over it. Daylight where the area gives it, the tile's own
 * four lit corners blended across it where it has them, both where it has both, and full light over ground that
 * glows (lava: the game cuts it out of the lighting altogether) and over everything that is not this site's
 * ground, which the pictures of the ground draw in a tone that is already lit.
 * Takes a few ticks. Null if it could not be made.
 * * berth_set - the berth's turfs: where a hull stands on them they take the light of the ground around the berth
 */
/datum/landing_view/proc/light_map(mid_x, mid_y, reach, grain, list/berth_set)
	var/turf/middle = locate(mid_x, mid_y, ground_z)
	if(!middle)
		return null
	var/datum/own_region = map_region_for_turf(middle)
	var/side = reach * 2 * grain
	var/list/cells = new /list(side * side)
	var/low_x = mid_x - reach
	var/low_y = mid_y - reach
	// area -> its daylight as list(red, green, blue), each 0-1, or FALSE for none
	var/list/daylight = list()
	// the light a hull on the berth hides: that of the ground around it
	var/list/around = list(0, 0, 0)
	var/around_count = 0
	for(var/turf/berth_turf as anything in berth_set)
		for(var/turf/beside as anything in RANGE_TURFS(1, berth_turf))
			if(berth_set[beside])
				continue
			var/list/there = landing_view_light_factor(beside)
			around[1] += there[1]
			around[2] += there[2]
			around[3] += there[3]
			around_count++
	var/under_hull = around_count ? rgb(round(around[1] / around_count * 255, 4), round(around[2] / around_count * 255, 4), round(around[3] / around_count * 255, 4)) : "#ffffff"
	for(var/tile_y = mid_y + reach - 1, tile_y >= low_y, tile_y--)
		var/cell_y = (tile_y - low_y) * grain
		for(var/tile_x in low_x to mid_x + reach - 1)
			var/turf/ground = locate(tile_x, tile_y, ground_z)
			var/cell_x = (tile_x - low_x) * grain
			var/flat = "#ffffff"
			var/list/corners
			if(ground && !istype(ground, /turf/cordon) && !(own_region && map_region_excludes_turf(own_region, ground)))
				if(berth_set[ground] && istype(ground.loc, /area/shuttle))
					flat = under_hull
				else if(landing_view_glows(ground))
					flat = "#ffffff"
				else
					var/area/place = ground.loc
					var/list/day = daylight[place]
					if(isnull(day))
						day = FALSE
						if(place.base_lighting_alpha)
							var/list/tint = rgb2num(place.base_lighting_color == COLOR_STARLIGHT ? GLOB.starlight_color : place.base_lighting_color)
							var/strength = place.base_lighting_alpha / 255 / 255
							day = list(tint[1] * strength, tint[2] * strength, tint[3] * strength)
						daylight[place] = day
					if(ground.lighting_object)
						// its own corners, with the daylight on top where there is any
						corners = list()
						for(var/datum/lighting_corner/corner as anything in list(ground.lighting_corner_SW, ground.lighting_corner_SE, ground.lighting_corner_NW, ground.lighting_corner_NE))
							if(corner)
								corners += list(list(corner.cache_r + (day ? day[1] : 0), corner.cache_g + (day ? day[2] : 0), corner.cache_b + (day ? day[3] : 0)))
							else
								corners += list(day || list(0, 0, 0))
					else if(day)
						flat = rgb(round(day[1] * 255, 4), round(day[2] * 255, 4), round(day[3] * 255, 4))
					else if(place.static_lighting && !isspaceturf(ground))
						// no light of any kind reaches it
						flat = "#000000"
			for(var/row in 1 to grain)
				var/base = (side - cell_y - row) * side + cell_x
				if(!corners)
					for(var/col in 1 to grain)
						cells[base + col] = flat
					continue
				var/up = (row - 0.5) / grain
				for(var/col in 1 to grain)
					var/right = (col - 0.5) / grain
					var/list/low_left = corners[1]
					var/list/low_right = corners[2]
					var/list/up_left = corners[3]
					var/list/up_right = corners[4]
					var/red = (low_left[1] * (1 - right) + low_right[1] * right) * (1 - up) + (up_left[1] * (1 - right) + up_right[1] * right) * up
					var/green = (low_left[2] * (1 - right) + low_right[2] * right) * (1 - up) + (up_left[2] * (1 - right) + up_right[2] * right) * up
					var/blue = (low_left[3] * (1 - right) + low_right[3] * right) * (1 - up) + (up_left[3] * (1 - right) + up_right[3] * right) * up
					cells[base + col] = rgb(round(min(red, 1) * 255, 4), round(min(green, 1) * 255, 4), round(min(blue, 1) * 255, 4))
		if(TICK_CHECK)
			stoplag()
	var/path = "data/landing_view/light_[ground_z]_[mid_x]_[mid_y]_[grain].png"
	if(!fexists("data/landing_view/made"))
		text2file("", "data/landing_view/made") // makes the folder
	var/failed = rustg_dmi_create_png(path, "[side]", "[side]", cells.Join(""))
	if(failed)
		stack_trace("No picture of the light for a landing view: [failed]")
		return null
	var/icon/light_map = new(path)
	// gone over once by the engine, as the pictures of the ground are: a far smaller file for a client to fetch
	light_map.Blend("#ffffff", ICON_MULTIPLY)
	return light_map

/// Whether [ground] glows of itself: the game draws such ground at full brightness whatever light falls on it
/proc/landing_view_glows(turf/ground)
	if(islava(ground))
		return TRUE
	for(var/mutable_appearance/over as anything in ground.overlays)
		if(PLANE_TO_TRUE(over.plane) == EMISSIVE_PLANE && over.color ~= GLOB.emissive_color)
			return TRUE
	return FALSE

#undef LANDING_VEIL_HOLE
#undef LANDING_VEIL_PUFF
#undef LANDING_VEIL_STEP
#undef LANDING_VEIL_FULL
#undef LANDING_VEIL_GONE
#undef LANDING_LIGHT_FAR_REACH
#undef LANDING_LIGHT_FAR_GRAIN
#undef LANDING_LIGHT_NEAR_REACH
#undef LANDING_LIGHT_NEAR_GRAIN
#undef LANDING_VIEW_CHUNK
#undef LANDING_VIEW_CORDON_REACH
#undef LANDING_AERIAL_FAR_REACH
#undef LANDING_AERIAL_FAR_GRAIN
#undef LANDING_AERIAL_NEAR_REACH
#undef LANDING_AERIAL_NEAR_GRAIN
#undef LANDING_AERIAL_KEEP
#undef LANDING_DETAIL_FROM
#undef LANDING_DETAIL_FULL
#undef LANDING_DETAIL_SIGHT
#undef LANDING_DETAIL_MOST
