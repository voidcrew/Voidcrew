/**
 * # Outpost floors: the directory board
 *
 * Owner: P11 (spec 5.2, 12; L22, L31). One board on each concourse lists the building: every floor of that outpost,
 * an Open floor with its name, crew, colour, what it offers and the crew's own line, an Invited floor by invitation,
 * a Crew only floor as private, a tenant's floor by its business. Its window is OutpostDirectory.tsx (build plan, data
 * contracts). No prices, no rules, nothing typed but the floor's own cleaned name and line.
 *
 * A concourse map hangs its board with /obj/effect/landmark/outpost_directory. place_outpost_directory() hangs one
 * beside the first lobby lift panel for a map without one; it is safe to call for any outpost, any number of times.
 *
 * The board is also the building's clock for NPC custom: its process() ticks each floor (npc_custom_tick(),
 * floor_customers.dm). One board an outpost does this, the first; any other only shows the list.
 *
 * Its face is the status display frame with a short bar a floor, floor 1 at the bottom: a floor's colour while it is
 * Open (dimmer while Invited), grey for a private floor or a tenant, nothing for an empty one.
 */

/// How often the board's face is checked against the building
#define DIRECTORY_FACE_CHECK (10 SECONDS)
/// The screen inside the frame, in pixels from the bottom left of the sprite
#define DIRECTORY_SCREEN_LEFT 3
#define DIRECTORY_SCREEN_BOTTOM 7
#define DIRECTORY_ROW_HEIGHT 2
#define DIRECTORY_ROW_GAP 1
#define DIRECTORY_BAR_LEFT 7
#define DIRECTORY_BAR_MAX 20
/// What each floor kind's bar looks like on the board's face
#define DIRECTORY_PRIVATE_BAR "#7b8494"
#define DIRECTORY_TENANT_BAR "#566072"
#define DIRECTORY_NUMBER_MARK "#a9b4c2"
/// Longest text the board sends: the window cuts shorter, these only keep a bad name from growing the message
#define DIRECTORY_CREW_MAX 48
#define DIRECTORY_TENANT_MAX 32
#define DIRECTORY_BUILDING_MAX 40

/// Trader outpost -> its directory board (the first hung). That board ticks the outpost's floors.
GLOBAL_LIST_EMPTY(outpost_directories)

/// The board on a concourse wall
/obj/machinery/outpost_directory
	name = "directory"
	desc = "The building's directory. Who has each floor upstairs."
	icon = 'icons/obj/machines/status_display.dmi'
	icon_state = "frame"
	layer = ABOVE_WINDOW_LAYER
	density = FALSE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	interaction_flags_machine = INTERACT_MACHINE_OFFLINE | INTERACT_MACHINE_ALLOW_SILICON
	/// The trader outpost it lists
	var/datum/weakref/outpost_ref
	/// What its face shows now (directory_face_state())
	var/face_shown
	/// world.time its face is next checked
	var/face_check_at = 0

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/outpost_directory, 32)

/obj/machinery/outpost_directory/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	update_appearance(UPDATE_OVERLAYS)

/obj/machinery/outpost_directory/Destroy()
	for(var/outpost in GLOB.outpost_directories)
		if(GLOB.outpost_directories[outpost] == src)
			GLOB.outpost_directories -= outpost
			break
	outpost_ref = null
	return ..()

/// The trader outpost whose building it lists: the one whose concourse it hangs on. The first board an outpost has
/// is its board (GLOB.outpost_directories).
/obj/machinery/outpost_directory/proc/directory_outpost()
	var/obj/structure/overmap/trader_outpost/outpost = outpost_ref?.resolve()
	if(QDELETED(outpost))
		outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost_ref = outpost ? WEAKREF(outpost) : null
	if(!outpost)
		return null
	var/obj/machinery/outpost_directory/listed = GLOB.outpost_directories[outpost]
	if(QDELETED(listed))
		GLOB.outpost_directories[outpost] = src
	return outpost

/obj/machinery/outpost_directory/process(seconds_per_tick)
	var/obj/structure/overmap/trader_outpost/outpost = directory_outpost()
	if(!outpost)
		return
	if(GLOB.outpost_directories[outpost] == src)
		for(var/datum/outpost_floor/floor in outpost.floors)
			floor.npc_custom_tick()
	if(world.time >= face_check_at)
		face_check_at = world.time + DIRECTORY_FACE_CHECK
		if(directory_face_state() != face_shown)
			update_appearance(UPDATE_OVERLAYS)

/// Each floor's row, in floor order (build plan, OutpostDirectory)
/obj/machinery/outpost_directory/proc/directory_rows()
	. = list()
	var/obj/structure/overmap/trader_outpost/outpost = directory_outpost()
	for(var/datum/outpost_floor/floor in outpost?.floors)
		var/list/row = floor.directory_row()
		if(row)
			. += list(row)

/// What its face would show now, as one string
/obj/machinery/outpost_directory/proc/directory_face_state()
	var/list/parts = list()
	for(var/list/row as anything in directory_rows())
		parts += "[row["number"]]:[row["kind"]]:[row["accent"]]:[length_char(row["name"])]"
	return jointext(parts, "|")

/obj/machinery/outpost_directory/update_overlays()
	. = ..()
	face_shown = directory_face_state()
	for(var/list/row as anything in directory_rows())
		var/number = row["number"]
		if(!isnum(number) || number < 1 || number > OUTPOST_FLOORS_PER_OUTPOST)
			continue
		var/bottom = DIRECTORY_SCREEN_BOTTOM + (number - 1) * (DIRECTORY_ROW_HEIGHT + DIRECTORY_ROW_GAP)
		. += directory_bar(DIRECTORY_SCREEN_LEFT, bottom, 2, DIRECTORY_NUMBER_MARK)
		var/bar_colour
		var/bar_length = 0
		var/name_length = length_char(row["name"])
		switch(row["kind"])
			if("open")
				bar_colour = row["accent"]
				bar_length = clamp(6 + round(name_length * 0.6), 8, DIRECTORY_BAR_MAX)
			if("invited")
				bar_colour = row["accent"]
				bar_length = clamp(6 + round(name_length * 0.6), 8, DIRECTORY_BAR_MAX)
			if("private")
				bar_colour = DIRECTORY_PRIVATE_BAR
				bar_length = 7
			if("tenant")
				bar_colour = DIRECTORY_TENANT_BAR
				bar_length = clamp(6 + round(name_length * 0.4), 8, 14)
		if(!bar_colour || !bar_length)
			continue
		var/mutable_appearance/bar = directory_bar(DIRECTORY_BAR_LEFT, bottom, bar_length, bar_colour)
		if(row["kind"] == "invited")
			bar.alpha = 130
		. += bar

/// A solid bar `width` pixels long on the board's face, its bottom left corner at `left`, `bottom`
/obj/machinery/outpost_directory/proc/directory_bar(left, bottom, width, colour)
	var/mutable_appearance/bar = mutable_appearance('icons/effects/alphacolors.dmi', "white")
	bar.color = colour
	bar.appearance_flags |= PIXEL_SCALE | RESET_COLOR
	// The 32 pixel square shrunk to the bar and moved so its corner sits at left, bottom
	bar.transform = matrix(width / 32, 0, left + width / 2 - 16, 0, DIRECTORY_ROW_HEIGHT / 32, bottom + DIRECTORY_ROW_HEIGHT / 2 - 16)
	return bar

/obj/machinery/outpost_directory/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostDirectory", name)
		ui.open()

/obj/machinery/outpost_directory/ui_data(mob/user)
	var/obj/structure/overmap/trader_outpost/outpost = directory_outpost()
	return list(
		"building" = outpost ? directory_cut(outpost.name, DIRECTORY_BUILDING_MAX) : null,
		"rows" = directory_rows(),
	)

/// Where a concourse map hangs its board: the board takes the mark's direction and hangs on that wall
/obj/effect/landmark/outpost_directory
	name = "outpost directory"
	icon = 'icons/obj/machines/status_display.dmi'
	icon_state = "frame"

/obj/effect/landmark/outpost_directory/Initialize(mapload)
	..()
	var/obj/machinery/outpost_directory/board = new(loc)
	directory_hang(board, dir)
	return INITIALIZE_HINT_QDEL

/// Turns `board` to `wall_dir` and shifts it onto that wall, as the directional mapping helpers do
/proc/directory_hang(obj/machinery/outpost_directory/board, wall_dir)
	board.setDir(wall_dir)
	board.pixel_x = 0
	board.pixel_y = 0
	switch(wall_dir)
		if(NORTH)
			board.pixel_y = 32
		if(SOUTH)
			board.pixel_y = -32
		if(EAST)
			board.pixel_x = 32
		if(WEST)
			board.pixel_x = -32

/**
 * Hangs `outpost`'s board beside its first lobby lift panel if it has none yet, and returns its board. The board goes
 * on the same wall, the nearest free spot along it within three tiles, off the lift's own tiles where it can. Safe to
 * call again: an outpost has one board. Null when there is no panel, or no wall beside it.
 */
/proc/place_outpost_directory(obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(outpost))
		return null
	var/obj/machinery/outpost_directory/board = GLOB.outpost_directories[outpost]
	if(!QDELETED(board))
		return board
	var/list/bounds = bounty_outpost_bounds(outpost)
	if(bounds)
		for(var/obj/machinery/outpost_directory/mapped as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/outpost_directory))
			if(ambient_in_bounds(get_turf(mapped), bounds) && mapped.directory_outpost() == outpost)
				return mapped
	var/obj/machinery/outpost_elevator/panel = length(outpost.lobby_panels) ? outpost.lobby_panels[1] : null
	var/turf/panel_turf = get_turf(panel)
	if(!panel_turf)
		return null
	var/turf/spot = directory_spot_beside(panel_turf, panel.dir, outpost.lobby_alcove_turfs)
	if(!spot)
		return null
	board = new(spot)
	directory_hang(board, panel.dir)
	board.directory_outpost()
	return board

/**
 * The tile beside `panel_turf` along the wall at `wall_dir` where a board can hang, the nearest first: off `avoid`
 * (the lift's tiles) if it can be. Each way along the wall stops at a wall, a door or another room, so the board is
 * always in sight of the panel. Null when there is no spot within three tiles.
 */
/proc/directory_spot_beside(turf/panel_turf, wall_dir, list/avoid)
	var/area/panel_area = get_area(panel_turf)
	var/turf/fallback
	for(var/side in list(turn(wall_dir, 90), turn(wall_dir, -90)))
		for(var/steps in 1 to 3)
			var/turf/tile = get_ranged_target_turf(panel_turf, side, steps)
			if(!isopenturf(tile) || get_area(tile) != panel_area || (locate(/obj/machinery/door) in tile))
				break
			if(!directory_spot_ok(tile, wall_dir))
				continue
			if(!(tile in avoid))
				if(!fallback || (fallback in avoid) || get_dist(tile, panel_turf) < get_dist(fallback, panel_turf))
					fallback = tile
				break
			fallback ||= tile
	return fallback

/// Whether a board could hang on the `wall_dir` wall of `tile`: open ground, a wall behind, nothing else hung there
/proc/directory_spot_ok(turf/tile, wall_dir)
	if(!isopenturf(tile) || !isclosedturf(get_step(tile, wall_dir)))
		return FALSE
	for(var/obj/thing in tile)
		if((ismachinery(thing) || isstructure(thing)) && thing.dir == wall_dir && (thing.pixel_x || thing.pixel_y || thing.pixel_w || thing.pixel_z))
			return FALSE
	return TRUE

/// `text`, `max_length` characters at most, cut with an ellipsis
/proc/directory_cut(text, max_length)
	if(!istext(text))
		return null
	if(length_char(text) <= max_length)
		return text
	return "[trim(copytext_char(text, 1, max_length))]…"

/**
 * This floor's row for the board (build plan, OutpostDirectory). Only the floor's own cleaned name and line are typed
 * text; the crew is a ship's name, cleaned where it was typed. A shut shop is out of what it offers (offers(), P4).
 */
/datum/outpost_floor/proc/directory_row()
	var/list/row = list(
		"number" = number,
		"kind" = "private",
		"name" = null,
		"crew" = null,
		"accent" = null,
		"line" = null,
		"offers" = list(),
		"busy" = FALSE,
	)
	switch(state)
		if(OUTPOST_FLOOR_STATE_TENANT)
			row["kind"] = "tenant"
			row["name"] = directory_cut(tenant_name, DIRECTORY_TENANT_MAX)
		if(OUTPOST_FLOOR_STATE_VACANT)
			row["kind"] = "vacant"
		if(OUTPOST_FLOOR_STATE_OWNED)
			switch(entry_policy)
				if(OUTPOST_FLOOR_ENTRY_OPEN)
					row["kind"] = "open"
				if(OUTPOST_FLOOR_ENTRY_INVITED)
					row["kind"] = "invited"
	if(row["kind"] != "open" && row["kind"] != "invited")
		return row
	row["name"] = directory_cut(floor_name || "Floor [number]", OUTPOST_FLOOR_NAME_MAX)
	row["crew"] = directory_cut(crew_name(), DIRECTORY_CREW_MAX)
	row["accent"] = accent_colour()
	if(row["kind"] == "open")
		row["line"] = length(board_line) ? directory_cut(board_line, OUTPOST_FLOOR_LINE_MAX) : null
		var/static/list/known_offers = list("Shop", "Clinic", "Cloning", "Lockers", "Teleporter", "Canteen")
		var/list/offered = list()
		for(var/offer in offers())
			if((offer in known_offers) && !(offer in offered))
				offered += offer
		row["offers"] = offered
		row["busy"] = length(visitors_upstairs()) >= OUTPOST_FLOOR_BUSY_AT
	return row

#undef DIRECTORY_FACE_CHECK
#undef DIRECTORY_SCREEN_LEFT
#undef DIRECTORY_SCREEN_BOTTOM
#undef DIRECTORY_ROW_HEIGHT
#undef DIRECTORY_ROW_GAP
#undef DIRECTORY_BAR_LEFT
#undef DIRECTORY_BAR_MAX
#undef DIRECTORY_PRIVATE_BAR
#undef DIRECTORY_TENANT_BAR
#undef DIRECTORY_NUMBER_MARK
#undef DIRECTORY_CREW_MAX
#undef DIRECTORY_TENANT_MAX
#undef DIRECTORY_BUILDING_MAX
