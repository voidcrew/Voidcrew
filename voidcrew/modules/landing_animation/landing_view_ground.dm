/**
 * The ground around a berth, as pictures for the landing view (see landing_view.dm).
 *
 * Two pictures of the same ground, drawn about the same middle:
 *
 * - From afar: one small image, a couple of pixels to the tile, of the whole country around the berth in its
 *   own colours and light. A single sprite, however far it reaches, so the whole planet can be on the screen
 *   at once for nothing. Scaled up smooth it looks like ground seen through a mile of air, which it is.
 * - Close up: the real tiles near the berth and everything standing on them, copied and lit as they are lit,
 *   in chunks. Exact, so the hull can move onto it without anything changing, and costly to draw, so it only
 *   reaches as far as a viewer can see once the ground is near, and is only shown then.
 *
 * The first fades into the second as the ground comes up (see chain_ground()).
 */

/// Tiles per side of one chunk of the close-up picture
#define LANDING_VIEW_CHUNK 16
/// How far from the hull's box the cordon strip at the edge of a site is still drawn in the close-up picture
#define LANDING_VIEW_CORDON_REACH 14
/// How far the picture from afar reaches from the berth's middle, in tiles, and its pixels to the tile
#define LANDING_AERIAL_REACH 64
#define LANDING_AERIAL_GRAIN 2
/// How long a picture from afar may be used again for the same berth
#define LANDING_AERIAL_KEEP (10 MINUTES)
/// The ground's size between which the close-up picture fades in over the one from afar
#define LANDING_DETAIL_FROM 0.6
#define LANDING_DETAIL_FULL 0.75
/// A viewer sees this many tiles each way; with LANDING_DETAIL_FROM it sets how far the close-up picture has to reach
#define LANDING_DETAIL_SIGHT 11
/// And the most it will reach past the hull's box, however big the hull
#define LANDING_DETAIL_MOST 28

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
	// held from the start if it starts in sight, to the end if it ends in sight
	close.give_at = first_seen > start ? first_seen - 2 : 0
	close.drop_at = last_seen < finish ? last_seen + 2 : INFINITY

/**
 * Builds the picture of the ground from afar and hands it to [piece]. Takes a few ticks; [then] is called when
 * it is done.
 */
/datum/landing_view/proc/bake_far(datum/landing_view_piece/piece, datum/callback/then)
	set waitfor = FALSE
	var/tone = ground_tone() || palette?.sky || COLOR_GRAY
	var/list/berth_set = list()
	for(var/turf/berth_turf as anything in berth_turfs)
		berth_set[berth_turf] = TRUE
	var/icon/aerial = landing_view_aerial(round(ground_x), round(ground_y), ground_z, berth_set, tone)
	if(QDELETED(src) || ended)
		return
	// under it and beyond its edges: more of the same, out of focus
	var/mutable_appearance/sheet = mutable_appearance('icons/effects/alphacolors.dmi', "white", appearance_flags = RESET_COLOR)
	sheet.color = tone
	sheet.transform = matrix().Scale(400)
	var/mutable_appearance/beyond = landing_view_world_look(new /mutable_appearance, LANDING_VIEW_LAYER_GROUND)
	beyond.overlays = list(sheet)
	var/list/parts = list(list(beyond, 0, 0, 1))
	if(aerial)
		var/size = aerial.Width()
		var/mutable_appearance/country = mutable_appearance(aerial)
		// its own middle on the image's, and drawn at a tile's worth of pixels to the tile
		country.pixel_w = -(size - ICON_SIZE_X) / 2
		country.pixel_z = -(size - ICON_SIZE_Y) / 2
		country.transform = matrix().Scale(ICON_SIZE_X / LANDING_AERIAL_GRAIN)
		var/mutable_appearance/far = landing_view_world_look(new /mutable_appearance, LANDING_VIEW_LAYER_GROUND + 0.05)
		far.overlays = list(country)
		// the picture's middle is the corner between four tiles; ours is the middle of the hull's box
		parts += list(list(far, (round(ground_x) - 0.5 - ground_x) * ICON_SIZE_X, (round(ground_y) - 0.5 - ground_y) * ICON_SIZE_Y, 1))
	piece.parts = parts
	then?.Invoke()

/**
 * A small picture of the ground for [LANDING_AERIAL_REACH] tiles each way from [mid_x], [mid_y]: a few pixels
 * to the tile, each the colour of that part of the tile as it is lit. Kept a while and used again for the same
 * spot. Takes a few ticks. Null if it could not be made.
 * * skip - turfs to paint in [fill_tone]: the berth itself, where a hull may be standing
 * * fill_tone - also the colour of everything that is not this site's ground
 */
/proc/landing_view_aerial(mid_x, mid_y, z, list/skip, fill_tone)
	var/static/list/kept = list()
	var/key = "[mid_x],[mid_y],[z]"
	var/list/had = kept[key]
	if(had && had[2] > world.time)
		return had[1]
	var/turf/middle = locate(mid_x, mid_y, z)
	if(!middle)
		return null
	var/datum/own_region = map_region_for_turf(middle)
	var/list/fill_pair = list(fill_tone, fill_tone)
	// rows of pixels, top row first; each tile gives two pixels to each of two rows
	var/list/rows = list()
	for(var/tile_y = mid_y + LANDING_AERIAL_REACH - 1, tile_y >= mid_y - LANDING_AERIAL_REACH, tile_y--)
		var/list/upper = list()
		var/list/lower = list()
		for(var/tile_x in mid_x - LANDING_AERIAL_REACH to mid_x + LANDING_AERIAL_REACH - 1)
			var/turf/ground = locate(tile_x, tile_y, z)
			if(!ground || skip[ground] || istype(ground, /turf/cordon) || (own_region && map_region_excludes_turf(own_region, ground)))
				upper += fill_pair
				lower += fill_pair
				continue
			var/list/tones = landing_view_tile_tones(ground)
			upper += tones[1]
			upper += tones[2]
			lower += tones[3]
			lower += tones[4]
		rows += upper.Join("")
		rows += lower.Join("")
		if(TICK_CHECK)
			stoplag()
	var/side = LANDING_AERIAL_REACH * 2 * LANDING_AERIAL_GRAIN
	var/path = "data/landing_view/[z]_[mid_x]_[mid_y].png"
	if(!fexists("data/landing_view/made"))
		text2file("", "data/landing_view/made") // makes the folder
	var/failed = rustg_dmi_create_png(path, "[side]", "[side]", rows.Join(""))
	if(failed)
		stack_trace("No picture of the ground for a landing view: [failed]")
		return null
	var/icon/aerial = new(path)
	kept[key] = list(aerial, world.time + LANDING_AERIAL_KEEP)
	return aerial

/**
 * The four colours of [ground] seen from afar, as it is lit: its upper left, upper right, lower left and lower
 * right quarters. Whatever big thing stands on it (a tree, a rock) colours it too.
 */
/proc/landing_view_tile_tones(turf/ground)
	var/list/own = landing_view_icon_tones(ground.icon, ground.icon_state)
	var/obj/structure/standing = locate(/obj/structure/flora) in ground
	var/list/over = standing ? landing_view_icon_tones(standing.icon, standing.icon_state) : null
	var/list/light = landing_view_light_factor(ground)
	. = list()
	for(var/quarter in 1 to 4)
		var/list/tint = own[quarter]
		if(over)
			var/list/top = over[quarter]
			. += rgb((tint[1] * 0.35 + top[1] * 0.65) * light[1], (tint[2] * 0.35 + top[2] * 0.65) * light[2], (tint[3] * 0.35 + top[3] * 0.65) * light[3])
		else
			. += rgb(tint[1] * light[1], tint[2] * light[2], tint[3] * light[3])

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
 * The colours of the four quarters of an icon state (upper left, upper right, lower left, lower right), each a
 * list of red, green and blue. Worked out once for each state.
 */
/proc/landing_view_icon_tones(icon_file, state)
	var/static/list/known = list()
	var/key = "[icon_file]|[state]"
	var/list/tones = known[key]
	if(tones)
		return tones
	tones = list()
	var/icon/sample = icon(icon_file, state, SOUTH, 1)
	var/width = sample.Width()
	var/height = sample.Height()
	var/list/whole = list(0, 0, 0)
	var/found_any = 0
	// each quarter from three pixels spread over it
	for(var/list/quarter as anything in list(list(0, 0.5), list(0.5, 0.5), list(0, 0), list(0.5, 0)))
		var/list/total = list(0, 0, 0)
		var/found = 0
		for(var/list/spot as anything in list(list(0.25, 0.25), list(0.15, 0.4), list(0.4, 0.15)))
			var/pixel = sample.GetPixel(1 + round((quarter[1] + spot[1]) * width), 1 + round((quarter[2] + spot[2]) * height))
			if(!pixel)
				continue
			var/list/tint = rgb2num(pixel)
			for(var/channel in 1 to 3)
				total[channel] += tint[channel]
			found++
		if(found)
			for(var/channel in 1 to 3)
				total[channel] /= found
				whole[channel] += total[channel]
			found_any++
			tones += list(total)
		else
			tones += null
	// a quarter with nothing in it takes the colour of the rest; an icon with nothing in it is grey
	for(var/channel in 1 to 3)
		whole[channel] = found_any ? whole[channel] / found_any : 128
	for(var/quarter in 1 to 4)
		if(!tones[quarter])
			tones[quarter] = whole
	known[key] = tones
	return tones

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
			var/list/tones = landing_view_icon_tones(ground.icon, ground.icon_state)
			var/list/light = landing_view_light_factor(ground)
			for(var/quarter in 1 to 4)
				for(var/channel in 1 to 3)
					total[channel] += tones[quarter][channel] * light[channel] / 4
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
				parts += list(list(landing_view_world_look(chunk, LANDING_VIEW_LAYER_GROUND + 0.1), centre_off_x * ICON_SIZE_X, centre_off_y * ICON_SIZE_Y, 1))
			if(!in_one_go && TICK_CHECK)
				stoplag()
				if(QDELETED(src) || ended)
					return
	piece.parts = (piece.parts || list()) + parts
	then?.Invoke()

/// Readies [look] to be one part of a world picture
/proc/landing_view_world_look(mutable_appearance/look, part_layer)
	look.plane = LANDING_VIEW_PLANE
	look.layer = part_layer
	look.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	return look

/**
 * One chunk of the close-up picture: the planet tiles from [low_x], [low_y] up, one row and column past
 * LANDING_VIEW_CHUNK so neighbouring chunks overlap and no seam opens between them when they are scaled.
 * Drawn about its own middle, with everything standing on it. Null if there is no ground there.
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
	// the light every tile here shares, if they all share one: then the whole chunk is tinted once
	var/shared_light
	var/mixed_light = FALSE
	var/list/tile_lights = list()
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
	if(length(storm_parts))
		// over everything standing there and under its light, as the world draws weather
		var/mutable_appearance/storm_group = new()
		storm_group.plane = FLOAT_PLANE
		storm_group.layer = 50
		storm_group.appearance_flags = KEEP_TOGETHER
		storm_group.overlays = storm_parts
		parts += storm_group
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

#undef LANDING_VIEW_CHUNK
#undef LANDING_VIEW_CORDON_REACH
#undef LANDING_AERIAL_REACH
#undef LANDING_AERIAL_GRAIN
#undef LANDING_AERIAL_KEEP
#undef LANDING_DETAIL_FROM
#undef LANDING_DETAIL_FULL
#undef LANDING_DETAIL_SIGHT
#undef LANDING_DETAIL_MOST
