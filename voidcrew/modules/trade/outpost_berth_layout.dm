/**
 * # Ship-sized standard berths
 *
 * A standard hangar berth is built for the ship that is docking, so a small hull is not
 * parked in the middle of an empty field. The landing pad is exactly the ground the hull
 * covers once adjust_reserve_dock_to_shuttle() has turned it, with OUTPOST_BERTH_MARGIN
 * tiles of clear deck on every side for walking round the hull and working on it.
 *
 * Layout, bottom to top (local coordinates, 1-based):
 *   rows 1 .. strip_height-2   the exit strip's airlock vestibule and elevator alcove,
 *                              set in solid wall across the whole width
 *   row  strip_height-1        south wall; the strip's recess cuts into it and its two
 *                              airlocks sit one row further south
 *   row  strip_height          south walkway (the strip decorates its own stretch)
 *   next margin-1 rows         deck, then the hazard-striped band round the pad
 *   pad rows                   landing pad, dock landmark on its bottom-left tile
 *   margin rows above the pad  band, deck, north walkway, then the north wall
 * The width is the pad plus a margin and a wall on each side, never less than the strip.
 */

/// Where each part of a standard berth goes. Pure numbers, so tests can check the formula.
/datum/outpost_berth_layout
	/// Landing pad size along x and y (the docked hull's footprint)
	var/pad_width
	var/pad_height
	/// Whole hangar size, walls and exit strip included; this is the reservation size
	var/width
	var/height
	/// Local coordinates of the pad's bottom-left tile
	var/pad_x
	var/pad_y
	/// Local x of the exit strip's left column; the strip always starts on row 1
	var/strip_x
	var/strip_width
	var/strip_height
	/// Clear deck between the pad and each wall
	var/margin = OUTPOST_BERTH_MARGIN

/datum/outpost_berth_layout/New(pad_width, pad_height, strip_width, strip_height)
	src.pad_width = max(round(pad_width), 1)
	src.pad_height = max(round(pad_height), 1)
	src.strip_width = strip_width
	src.strip_height = strip_height
	var/snug_width = src.pad_width + 2 * (margin + 1)
	width = max(snug_width, strip_width)
	height = strip_height + src.pad_height + 2 * margin
	pad_x = 2 + margin + round((width - snug_width) / 2)
	pad_y = strip_height + margin
	strip_x = 1 + round((width - strip_width) / 2)

/// Local y of the south wall; the strip's airlocks are set into it.
/datum/outpost_berth_layout/proc/south_wall_y()
	return strip_height - 1

/**
 * The landing pad a ship needs, as list(x extent, y extent), or null when the ship is
 * too big for any berth. A berth allocated without a shuttle gets the largest pad.
 */
/proc/outpost_berth_pad_size(obj/docking_port/mobile/shuttle)
	if(QDELETED(shuttle))
		return list(RESERVE_DOCK_MAX_SIZE_LONG, RESERVE_DOCK_MAX_SIZE_SHORT)
	if(max(shuttle.width, shuttle.height) > RESERVE_DOCK_MAX_SIZE_LONG || min(shuttle.width, shuttle.height) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return null
	var/list/ground = reserve_dock_ground_size(shuttle)
	return list(max(ground[1], 1), max(ground[2], 1))

#define BERTH_AREA "/area/voidcrew/outpost_hangar/berth"
#define BERTH_WALL "/turf/closed/indestructible/reinforced/titanium/outpost"
#define BERTH_WALKWAY_TURF "/turf/open/indestructible/dark"
#define BERTH_DECK_TURF "/turf/open/indestructible/dark/smooth_large"
#define BERTH_PAD_TURF "/turf/open/indestructible/plating"
/// Walkway lights hang on every Nth tile of each wall
#define BERTH_LIGHT_SPACING 6

GLOBAL_DATUM(outpost_berth_strip_template, /datum/map_template/outpost_berth_strip)

/**
 * The fixed exit strip: airlock, elevator alcove and panel, berth displays. It is never
 * loaded on its own. Its tiles are merged into the berth's generated map text, so the
 * whole berth loads in one pass (a second load over an initialised hangar smooths walls
 * against half-initialised neighbours) and shares one area instance.
 */
/datum/map_template/outpost_berth_strip
	name = "Outpost Berth Exit Strip"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_berth_strip.dmm"
	/// "x,y" -> tile stack text for every strip tile that is not template_noop
	var/list/tiles

/proc/get_outpost_berth_strip()
	if(!GLOB.outpost_berth_strip_template)
		GLOB.outpost_berth_strip_template = new
	return GLOB.outpost_berth_strip_template

/// The strip's tile stack at a strip-local coordinate, or null where the body shows through.
/datum/map_template/outpost_berth_strip/proc/tile_at(strip_x, strip_y)
	if(isnull(tiles))
		read_tiles()
	return tiles["[strip_x],[strip_y]"]

/// Reads the strip map into per-tile stacks. Its template_noop area becomes the berth's area.
/datum/map_template/outpost_berth_strip/proc/read_tiles()
	tiles = list()
	var/datum/parsed_map/parsed = new(file(mappath))
	var/key_len = parsed.key_len
	for(var/datum/grid_set/column as anything in parsed.gridSets)
		var/list/lines = column.gridLines
		for(var/line_index in 1 to length(lines))
			var/line = lines[line_index]
			var/tile_y = column.ycrd - (line_index - 1)
			for(var/key_index in 1 to length(line) / key_len)
				var/key = copytext(line, (key_index - 1) * key_len + 1, key_index * key_len + 1)
				var/model = replacetext(replacetext(parsed.grid_models[key], "\n", ""), "\t", "")
				if(findtext(model, "/turf/template_noop"))
					continue
				tiles["[column.xcrd + key_index - 1],[tile_y]"] = replacetext(model, "/area/template_noop", BERTH_AREA)

/**
 * One berth, written as map text and loaded like any template, so the berth gets its own
 * area instance and the usual atom, lighting and air setup.
 * Single use: generate() parses the map and load() drops it again.
 */
/datum/map_template/outpost_berth_body
	name = "Outpost Berth"

/datum/map_template/outpost_berth_body/proc/generate(datum/outpost_berth_layout/layout, datum/map_template/outpost_berth_strip/strip)
	width = layout.width
	height = layout.height
	cached_map = new /datum/parsed_map(outpost_berth_map_text(layout, strip))

/// DMM text for a berth. Two-letter keys are handed out as tile stacks first appear.
/proc/outpost_berth_map_text(datum/outpost_berth_layout/layout, datum/map_template/outpost_berth_strip/strip)
	var/list/keys = list()
	var/list/rows = list()
	var/key_pool = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
	var/pool_size = length(key_pool)
	for(var/y in layout.height to 1 step -1)
		var/list/row = list()
		for(var/x in 1 to layout.width)
			var/stack
			if(strip && y <= layout.strip_height && x >= layout.strip_x && x < layout.strip_x + layout.strip_width)
				stack = strip.tile_at(x - layout.strip_x + 1, y)
			stack ||= outpost_berth_tile(layout, x, y)
			var/key = keys[stack]
			if(!key)
				var/index = length(keys)
				key = key_pool[round(index / pool_size) % pool_size + 1] + key_pool[index % pool_size + 1]
				keys[stack] = key
			row += key
		rows += jointext(row, "")
	var/list/text = list()
	for(var/stack in keys)
		text += "\"[keys[stack]]\" = ([stack])"
	text += "(1,1,1) = {\"\n[jointext(rows, "\n")]\n\"}"
	return jointext(text, "\n") + "\n"

/// The tile stack at one local coordinate: movables, then the turf, then the area.
/proc/outpost_berth_tile(datum/outpost_berth_layout/layout, x, y)
	var/south_wall = layout.south_wall_y()
	var/in_strip_columns = x >= layout.strip_x && x < layout.strip_x + layout.strip_width
	// Walls all round, and solid wall round the strip's vestibule and alcove. Every tile of
	// the reservation belongs to the berth's area, so none of it reads as open space.
	if(y <= south_wall || y == layout.height || x == 1 || x == layout.width)
		return "[BERTH_WALL],[BERTH_AREA]"

	var/walkway_south = south_wall + 1
	var/walkway_north = layout.height - 1
	var/walkway_west = 2
	var/walkway_east = layout.width - 1
	if(x == walkway_west || x == walkway_east || y == walkway_south || y == walkway_north)
		var/facing = NONE
		if(y == walkway_north)
			facing |= NORTH
		else if(y == walkway_south)
			facing |= SOUTH
		if(x == walkway_west)
			facing |= WEST
		else if(x == walkway_east)
			facing |= EAST
		var/list/stack = list("/obj/effect/turf_decal/siding/wideplating_new/dark{dir = [facing]}")
		if(y == walkway_north && (x == walkway_west || x == walkway_east))
			stack += "/obj/item/kirbyplants/organic/plant22"
		else if(facing in GLOB.cardinals)
			// Lights along each wall; the strip lights its own stretch of the south wall.
			var/along = (facing & (NORTH|SOUTH)) ? x - walkway_west : y - walkway_south
			if(along % BERTH_LIGHT_SPACING == BERTH_LIGHT_SPACING / 2 && !(facing == SOUTH && in_strip_columns))
				stack += "/obj/machinery/light/warm/directional/[dir2text(facing)]"
		stack += BERTH_WALKWAY_TURF
		stack += BERTH_AREA
		return jointext(stack, ",")

	var/pad_right = layout.pad_x + layout.pad_width - 1
	var/pad_top = layout.pad_y + layout.pad_height - 1
	if(x >= layout.pad_x && x <= pad_right && y >= layout.pad_y && y <= pad_top)
		var/list/stack = list()
		if(x == layout.pad_x && y == layout.pad_y)
			stack += "/obj/effect/landmark/outpost_berth_dock"
		var/edge = NONE
		if(layout.pad_width > 1)
			if(x == layout.pad_x)
				edge |= WEST
			else if(x == pad_right)
				edge |= EAST
		if(layout.pad_height > 1)
			if(y == layout.pad_y)
				edge |= SOUTH
			else if(y == pad_top)
				edge |= NORTH
		if(edge)
			stack += "/obj/effect/turf_decal/siding/thinplating_new/dark{dir = [edge]}"
		stack += BERTH_PAD_TURF
		stack += BERTH_AREA
		return jointext(stack, ",")

	// Hazard band hugging the pad; stripes face the pad.
	if(x >= layout.pad_x - 1 && x <= pad_right + 1 && y >= layout.pad_y - 1 && y <= pad_top + 1)
		var/west = x == layout.pad_x - 1
		var/east = x == pad_right + 1
		var/south = y == layout.pad_y - 1
		var/north = y == pad_top + 1
		var/stripe
		if(north && west)
			stripe = "/obj/effect/turf_decal/stripes/corner{dir = 2}"
		else if(north && east)
			stripe = "/obj/effect/turf_decal/stripes/corner{dir = 8}"
		else if(south && west)
			stripe = "/obj/effect/turf_decal/stripes/corner{dir = 4}"
		else if(south && east)
			stripe = "/obj/effect/turf_decal/stripes/corner{dir = 1}"
		else if(north)
			stripe = "/obj/effect/turf_decal/stripes/line{dir = 2}"
		else if(south)
			stripe = "/obj/effect/turf_decal/stripes/line{dir = 1}"
		else if(west)
			stripe = "/obj/effect/turf_decal/stripes/line{dir = 4}"
		else
			stripe = "/obj/effect/turf_decal/stripes/line{dir = 8}"
		return "[stripe],[BERTH_DECK_TURF],[BERTH_AREA]"

	return "[BERTH_DECK_TURF],[BERTH_AREA]"

#undef BERTH_AREA
#undef BERTH_WALL
#undef BERTH_WALKWAY_TURF
#undef BERTH_DECK_TURF
#undef BERTH_PAD_TURF
#undef BERTH_LIGHT_SPACING
