/**
 * # Rotated template loading
 *
 * /datum/map_template/proc/load() can only stamp a map the way it was drawn. Outpost upgrades
 * (see voidcrew/modules/player_outposts/outpost_upgrades.dm) are placed at any of four
 * orientations, so this loads a parsed map with every tile moved to its rotated position and
 * every atom the load created turned with it, before anything initializes.
 *
 * Rotation is in degrees CLOCKWISE, the same sense as shuttleRotate(): 90 turns NORTH into EAST
 * and puts the template's south edge on the west side of the footprint.
 */

/// Yield the way the reader's MAPLOADING_CHECK_TICK does (it is #undef'd at the end of reader.dm).
#define ROTATED_LOAD_CHECK_TICK(parsed) \
	if(TICK_CHECK) { \
		SSatoms.map_loader_stop(REF(parsed)); \
		stoplag(); \
		SSatoms.map_loader_begin(REF(parsed)); \
	}

/**
 * Loads this template turned `rotation` degrees clockwise (0, 90, 180 or 270), with the rotated
 * footprint's bottom-left corner on `bottom_left`. The footprint is width x height, or
 * height x width for 90 and 270.
 *
 * Mirrors load(): clears border atmos, parses, builds every tile under SSatoms.map_loader_begin(),
 * then initializes the bounds. Atoms the load created are turned before initialization, so
 * directional objects, wall mounts and pixel offsets come out as if the map had been drawn
 * rotated. Atoms already standing on the footprint are left alone.
 *
 * Returns the loaded bounds (MAP_MINX..MAP_MAXZ) or null. Single-z maps only. Never call this
 * inside try/catch: a warning during the load would unwind it and leave a half-built map.
 */
/datum/map_template/proc/load_rotated(turf/bottom_left, rotation = 0)
	rotation = SIMPLIFY_DEGREES(rotation)
	if(rotation % 90)
		CRASH("[name] asked for a [rotation] degree rotation; only right angles are supported")
	if(!bottom_left || !width || !height)
		return null
	var/turned = (rotation == 90 || rotation == 270)
	var/footprint_width = turned ? height : width
	var/footprint_height = turned ? width : height
	var/turf/top_right = locate(bottom_left.x + footprint_width - 1, bottom_left.y + footprint_height - 1, bottom_left.z)
	if(!top_right)
		return null

	var/datum/worldgen_probe/probe = worldgen_begin("template", "[name] [footprint_width]x[footprint_height] rotated [rotation] @ [bottom_left.x],[bottom_left.y],[bottom_left.z]")

	// Same border atmos cleanup as load()
	var/list/to_rebuild = SSair.adjacent_rebuild
	for(var/turf/border_turf as anything in CORNER_BLOCK_OFFSET(bottom_left, footprint_width + 2, footprint_height + 2, -1, -1))
		SSair.remove_from_active(border_turf)
		to_rebuild -= border_turf
		for(var/turf/sub_turf as anything in border_turf.atmos_adjacent_turfs)
			sub_turf.atmos_adjacent_turfs?.Remove(border_turf)
		border_turf.atmos_adjacent_turfs?.Cut()

	// A fresh parse (or a copy of the cached one) per load. The parsed map remembers the areas it
	// created, so reusing one would make every load share a single non-unique area instance.
	var/datum/parsed_map/parsed = cached_map ? cached_map.copy() : new(file(mappath))
	if(!parsed.bounds)
		worldgen_end(probe, "parse-failed")
		return null
	var/list/source_bounds = parsed.bounds
	if(source_bounds[MAP_MINZ] != 1 || source_bounds[MAP_MAXZ] != 1)
		worldgen_end(probe, "multi-z")
		CRASH("[name] has more than one z-level; load_rotated() only handles single-level maps")
	var/map_width = source_bounds[MAP_MAXX]
	var/map_height = source_bounds[MAP_MAXY]
	if(map_width != width || map_height != height)
		worldgen_end(probe, "size-mismatch")
		CRASH("[name] parsed as [map_width]x[map_height] but the template expects [width]x[height]")
	// reader.dm #undefs its format names; these are the values of MAP_TGM and MAP_DMM there.
	var/tgm = (parsed.map_format == "tgm")
	if(!tgm && parsed.map_format != "dmm")
		worldgen_end(probe, "unknown-format")
		CRASH("[name] has unknown map format [parsed.map_format]")
	parsed.turf_blacklist = null

	var/list/footprint_turfs = block(bottom_left, top_right)
	// Anything already standing here keeps its own orientation.
	var/list/preexisting = list()
	for(var/turf/footprint_turf as anything in footprint_turfs)
		for(var/atom/movable/resident as anything in footprint_turf)
			preexisting[resident] = TRUE

	var/no_changeturf = (SSatoms.initialized == INITIALIZATION_INSSATOMS)
	var/place_on_top = should_place_on_top
	var/list/placed_turfs = list()

	Master.StartLoadingMap()
	// build_coordinate() yields through the reader's own tick check, which only hands SSatoms
	// back while `loading` is set.
	parsed.loading = TRUE
	SSatoms.map_loader_begin(REF(parsed))
	var/list/model_cache = parsed.build_cache(no_changeturf)
	var/space_key = model_cache[SPACE_KEY]
	var/key_len = parsed.key_len
	for(var/datum/grid_set/grid_set as anything in parsed.gridSets)
		var/list/lines = grid_set.gridLines
		for(var/line_index in 1 to length(lines))
			// grid_set.ycrd is the top row; each line goes one row down
			var/map_y = grid_set.ycrd - (line_index - 1)
			var/line = lines[line_index]
			// TGM stores one tile per line (a column); DMM stores a whole row per line
			var/cells = tgm ? 1 : length(line) / key_len
			for(var/cell in 1 to cells)
				var/map_x = grid_set.xcrd + cell - 1
				var/model_key = tgm ? line : copytext(line, (cell - 1) * key_len + 1, cell * key_len + 1)
				if(no_changeturf && model_key == space_key)
					continue
				var/list/model = model_cache[model_key]
				if(!model)
					SSatoms.map_loader_stop(REF(parsed))
					parsed.loading = FALSE
					Master.StopLoadingMap()
					worldgen_end(probe, "bad-key")
					CRASH("Undefined model key in [name]: [model_key]")
				var/turf/target = rotated_template_turf(bottom_left, map_x - 1, map_y - 1, rotation)
				var/list/members = model[1]
				// The reader always puts the turf right before the area
				if(members[length(members) - 1] != /turf/template_noop)
					placed_turfs += target
				parsed.build_coordinate(model, target, no_changeturf, place_on_top, FALSE)
				ROTATED_LOAD_CHECK_TICK(parsed)
	SSatoms.map_loader_stop(REF(parsed))
	parsed.loading = FALSE
	Master.StopLoadingMap()

	if(!no_changeturf)
		for(var/turf/changed as anything in footprint_turfs)
			changed.AfterChange(CHANGETURF_IGNORE_AIR)

	var/list/bounds = list(bottom_left.x, bottom_left.y, bottom_left.z, top_right.x, top_right.y, top_right.z)
	parsed.bounds = bounds
	require_area_resort()

	// Turn what the load created while it is still uninitialized. Anything initialized got here
	// on its own while the load yielded, and keeps its facing like the preexisting atoms.
	if(rotation)
		for(var/turf/placed as anything in placed_turfs)
			placed.template_load_rotate(rotation)
		for(var/turf/footprint_turf as anything in footprint_turfs)
			for(var/atom/movable/created as anything in footprint_turf)
				if(!preexisting[created] && !(created.flags_1 & INITIALIZED_1))
					created.template_load_rotate(rotation)

	// Initialization yields with SSatoms' mapload state cleared, so SSicon_smooth can run in the
	// middle of it. An initialized smoother on or beside the footprint that is still queued (a wall
	// the room joins) would then read a neighbour that has not initialized yet, whose smoothing
	// groups are still raw text: "bad index" in bitmask_smooth(). Hold those until the room is up.
	var/list/atom/held_smoothers = list()
	for(var/turf/near_turf as anything in CORNER_BLOCK_OFFSET(bottom_left, footprint_width + 2, footprint_height + 2, -1, -1))
		if((near_turf.smoothing_flags & SMOOTH_QUEUED) && (near_turf.flags_1 & INITIALIZED_1))
			held_smoothers += near_turf
		for(var/atom/movable/near_thing as anything in near_turf)
			if((near_thing.smoothing_flags & SMOOTH_QUEUED) && (near_thing.flags_1 & INITIALIZED_1))
				held_smoothers += near_thing
	for(var/atom/held as anything in held_smoothers)
		SSicon_smooth.remove_from_queues(held)

	initTemplateBounds(bounds)

	for(var/atom/held as anything in held_smoothers)
		if(!QDELETED(held))
			QUEUE_SMOOTH(held)

	if(has_ceiling)
		generate_ceiling(footprint_turfs)

	log_game("[name] loaded rotated [rotation] at [bottom_left.x],[bottom_left.y],[bottom_left.z]")
	worldgen_end(probe)
	return bounds

/**
 * Where the template tile at zero-based offset (column, row) lands for a clockwise rotation,
 * with the rotated footprint's bottom-left on `bottom_left`.
 */
/datum/map_template/proc/rotated_template_turf(turf/bottom_left, column, row, rotation)
	var/offset_x = column
	var/offset_y = row
	switch(rotation)
		if(90)
			offset_x = row
			offset_y = width - 1 - column
		if(180)
			offset_x = width - 1 - column
			offset_y = height - 1 - row
		if(270)
			offset_x = height - 1 - row
			offset_y = column
	return locate(bottom_left.x + offset_x, bottom_left.y + offset_y, bottom_left.z)

/**
 * The same as rotated_template_turf() without a turf: where the tile at zero-based (column, row)
 * of a `width` x `height` template lands for a clockwise rotation, as list(dx, dy) from the rotated
 * footprint's bottom-left. Run backwards from a known tile, it finds the bottom-left.
 */
/proc/rotated_template_offset(column, row, rotation, width, height)
	switch(rotation)
		if(90)
			return list(row, width - 1 - column)
		if(180)
			return list(width - 1 - column, height - 1 - row)
		if(270)
			return list(height - 1 - row, column)
	return list(column, row)

/**
 * Turns an atom a rotated template load just created, before it initializes, as if it had been
 * mapped that way. Same geometry as shuttleRotate(); smoothing is left to initialization.
 */
/atom/proc/template_load_rotate(rotation)
	shuttleRotate(rotation, ROTATE_DIR | ROTATE_OFFSET)

// Pipe nodes only exist after Initialize(), which derives them from dir, so turning dir is the
// whole job. shuttleRotate() here would runtime on the null nodes list. Layer offsets are also
// recomputed at initialization, so pixel offsets stay put.
/obj/machinery/atmospherics/template_load_rotate(rotation)
	setDir(angle2dir(rotation + dir2angle(dir)))

#undef ROTATED_LOAD_CHECK_TICK
