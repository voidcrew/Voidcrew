/**
 * # Assembled-ship conformance
 *
 * A modular hull is never played in the shape it is stored in. What a crew
 * boards is hull + one module per slot, stitched together at roundstart by
 * /obj/modular_map_root/ship_upgrade. Every invariant that matters - can you
 * get out of your cryopod, does your room have air, does the generator reach
 * the wire - is a property of that *assembly*, and no gate in this repo had
 * ever looked at one. Six families were audited by hand and every defect found
 * had been invisible to CI:
 *
 * - Kilo: ten service-module files put a dense structure on the one tile that
 *   connects the dorms to the rest of the ship, sealing all three crew spawns
 *   behind it. Renders fine, loads fine, traps the whole crew.
 * - Goon: a hull vent and two scrubbers pointed at tiles with no pipe on them,
 *   and the north thruster's SMES terminal sat on a one-tile powernet.
 * - Phalanx: the *default* medbay module had a one-tile hole in its cable and
 *   pipe run, leaving the medbay APC on a dead net and the operating theatre
 *   with no air supply, on all four themes.
 * - Blackpill: the ship's only generator was mapped unanchored, so it could not
 *   join a powernet and its own UI refused to start it.
 * - Scarab: three "syndicate" module variants were verbatim copies of the
 *   medical ones.
 *
 * Nothing in this file loads a ship. It reads the shipped `.dmm` files, runs
 * the same placement arithmetic /datum/map_template/map_module/load() runs, and
 * asserts against the result - the static-scan style of
 * voidcrew_ship_modules.dm and voidcrew_ship_hulls.dm, one layer up.
 *
 * The fitout space swept is "defaults", plus every single-slot substitution off
 * defaults, per hull, per theme. That breadth is what catches Kilo: its default
 * service module is the one that does *not* seal the dorms.
 */

/// TOML `directory` key in voidcrew/modules/ship_upgrades/ship_upgrades.toml
#define SHIP_MODULE_MAP_ROOT "_maps/voidcrew/ship_modules/"
/// Mirrors /datum/map_template/shuttle/voidcrew's `prefix`
#define SHIP_HULL_MAP_ROOT "_maps/voidcrew/ships/"

/// The tile carries a floor a crewman can stand on (open, and not space).
#define VC_TILE_OPEN (1<<0)
/// The tile carries a closed turf, or a dense movable nobody can walk through.
#define VC_TILE_BLOCKED (1<<1)
#define VC_TILE_CRYOPOD (1<<2)
#define VC_TILE_CABLE (1<<3)
#define VC_TILE_APC (1<<4)
#define VC_TILE_SMES (1<<5)
#define VC_TILE_TERMINAL (1<<6)
/// A machine that makes power, as opposed to storing or spending it.
#define VC_TILE_GENERATOR (1<<7)
/// Any atmospherics machine on piping layer 4 / layer 2 - pipes, pumps, valves
/// and connectors alike, because every one of them carries a network across a tile.
#define VC_TILE_ATMOS_L4 (1<<8)
#define VC_TILE_ATMOS_L2 (1<<9)
/// A *pipe* belonging to the hull trunk: blue supply on 4, red scrubbers on 2.
#define VC_TILE_TRUNK_L4 (1<<10)
#define VC_TILE_TRUNK_L2 (1<<11)
#define VC_TILE_MACHINE (1<<12)

/**
 * ## A parsed .dmm
 *
 * TGM (and plain DMM) is a dictionary of `"key" = (atom, atom, turf, area)`
 * entries followed by grid blocks of those keys. This holds both, plus a flat
 * grid indexed `(y - 1) * width + x`, and memoises derived per-key data so a
 * hull read once is cheap to assemble fifty times.
 *
 * Atoms are kept as their raw map text ("/obj/foo{dir = 4}") rather than
 * resolved types, because a mapped var edit is half the meaning: an unanchored
 * generator and an anchored one are the same typepath.
 */
/datum/vc_test_dmm
	/// Where this was read from, for failure messages.
	var/map_path
	var/width = 0
	var/height = 0
	/// key -> /list of atom entry text. The turf is second-last, the area last.
	var/list/dictionary
	/// flat, (y - 1) * width + x -> dictionary key
	var/list/grid
	/// dictionary key -> tile flag bitfield, built on demand
	var/list/key_flag_cache
	/// path prefix -> /list of list(x, y, entry), built on demand
	var/list/instance_cache
	/// md5 of the content, with TGM key letters and atom order normalised out
	var/content_fingerprint

/**
 * Reads a `.dmm` into a /datum/vc_test_dmm, once per path per round.
 *
 * Line-oriented on purpose: splittext() and findtext() are native, and the
 * fleet is ~250 files. Everything here works on whole lines rather than
 * walking characters.
 */
/proc/vc_test_parse_dmm(path)
	var/static/list/cache = list()
	if(path in cache)
		return cache[path]
	cache[path] = null
	var/text = vc_test_file_text(path)
	if(!text)
		return null

	var/datum/vc_test_dmm/map = new
	map.map_path = path
	map.dictionary = list()
	map.key_flag_cache = list()
	map.instance_cache = list()

	// Grid blocks are collected raw first: a block's rows are numbered downward
	// from its header's y and the whole map is flipped at the end, which is what
	// tools/mapmerge2/dmm.py does and therefore what the game sees.
	var/list/blocks = list()
	var/list/block_rows
	var/block_x = 0
	var/block_y = 0
	var/key_length = 0

	var/entry_key
	var/entry_body
	var/entry_depth = 0

	for(var/raw_line in splittext(text, "\n"))
		var/line = trim(raw_line) // also eats the \r of a CRLF checkout
		if(!length(line))
			continue

		if(entry_key)
			entry_depth += vc_test_count_occurrences(line, "{") - vc_test_count_occurrences(line, "}")
			entry_body += line
			if(entry_depth <= 0 && copytext(line, -1) == ")")
				map.dictionary[entry_key] = vc_test_split_tile_atoms(copytext(entry_body, 1, length(entry_body)))
				entry_key = null
				entry_body = null
				entry_depth = 0
			continue

		if(block_rows)
			if(line == "\"}")
				blocks += list(list(block_x, block_y, block_rows))
				block_rows = null
			else
				block_rows += line
			continue

		if(copytext(line, 1, 2) == "\"")
			var/close_at = findtext(line, "\"", 2)
			if(!close_at)
				continue
			entry_key = copytext(line, 2, close_at)
			key_length = max(key_length, length(entry_key))
			var/open_at = findtext(line, "(", close_at)
			entry_body = open_at ? copytext(line, open_at + 1) : ""
			entry_depth = vc_test_count_occurrences(entry_body, "{") - vc_test_count_occurrences(entry_body, "}")
			if(entry_depth <= 0 && length(entry_body) && copytext(entry_body, -1) == ")")
				map.dictionary[entry_key] = vc_test_split_tile_atoms(copytext(entry_body, 1, length(entry_body)))
				entry_key = null
				entry_body = null
				entry_depth = 0
			continue

		if(copytext(line, 1, 2) == "(")
			var/head_at = findtext(line, ") = {\"")
			if(!head_at)
				continue
			var/list/coordinates = splittext(copytext(line, 2, head_at), ",")
			if(length(coordinates) < 3)
				continue
			block_x = text2num(trim(coordinates[1]))
			block_y = text2num(trim(coordinates[2]))
			// Ship maps are single-z; a z2+ block is consumed and discarded.
			block_x = (text2num(trim(coordinates[3])) == 1) ? block_x : null
			block_rows = list()
			continue

	if(!key_length || !length(blocks))
		return null

	var/max_x = 0
	var/max_raw_y = 0
	for(var/list/block as anything in blocks)
		if(isnull(block[1]))
			continue
		var/list/rows = block[3]
		max_raw_y = max(max_raw_y, block[2] + length(rows) - 1)
		for(var/row in rows)
			max_x = max(max_x, block[1] + round(length(row) / key_length) - 1)
	if(max_x < 1 || max_raw_y < 1)
		return null

	map.width = max_x
	map.height = max_raw_y
	map.grid = new /list(max_x * max_raw_y)
	for(var/list/block as anything in blocks)
		if(isnull(block[1]))
			continue
		var/list/rows = block[3]
		for(var/row_index in 1 to length(rows))
			var/row = rows[row_index]
			// the first row printed is the top of the map, i.e. the highest y
			var/y = max_raw_y + 1 - (block[2] + row_index - 1)
			if(y < 1 || y > max_raw_y)
				continue
			for(var/key_index in 1 to round(length(row) / key_length))
				var/x = block[1] + key_index - 1
				if(x < 1 || x > max_x)
					continue
				map.grid[(y - 1) * max_x + x] = copytext(row, (key_index - 1) * key_length + 1, key_index * key_length + 1)

	cache[path] = map
	return map

/**
 * Splits one dictionary entry's body into atom entries.
 *
 * Commas inside a var block belong to that block, so pieces are re-joined until
 * their braces balance. A comma inside a quoted string is always inside braces
 * (typepaths carry no quotes), so `name = "a, b"` comes out right for free.
 */
/proc/vc_test_split_tile_atoms(body)
	var/list/atoms = list()
	var/pending = ""
	var/depth = 0
	for(var/piece in splittext(body, ","))
		pending = length(pending) ? "[pending],[piece]" : piece
		depth += vc_test_count_occurrences(piece, "{") - vc_test_count_occurrences(piece, "}")
		if(depth > 0)
			continue
		depth = 0
		var/atom_text = trim(pending)
		pending = ""
		if(length(atom_text))
			atoms += atom_text
	if(length(trim(pending)))
		atoms += trim(pending)
	return atoms

/// The typepath text of a map atom entry, without its var block.
/proc/vc_test_entry_path_text(entry)
	if(!entry)
		return ""
	var/brace_at = findtext(entry, "{")
	return trim(brace_at ? copytext(entry, 1, brace_at) : entry)

/// The resolved typepath of a map atom entry, or null if the type no longer exists.
/proc/vc_test_entry_type(entry)
	var/static/list/cache = list()
	var/path_text = vc_test_entry_path_text(entry)
	if(!(path_text in cache))
		cache[path_text] = text2path(path_text)
	return cache[path_text]

/// Whether a map atom entry is `path` or a subtype of it.
/proc/vc_test_entry_is(entry, path)
	var/resolved = vc_test_entry_type(entry)
	return resolved && ispath(resolved, path)

/// A mapped var edit's raw text ("dir = 4" -> "4"), or null if it was not edited.
/proc/vc_test_entry_var(entry, var_name)
	var/brace_at = findtext(entry, "{")
	if(!brace_at)
		return null
	var/needle = "[var_name] = "
	var/at = findtext(entry, needle, brace_at)
	// skip hits inside a longer var name (dir vs cyclelinkeddir)
	while(at && vc_test_is_identifier_char(text2ascii(entry, at - 1)))
		at = findtext(entry, needle, at + 1)
	if(!at)
		return null
	var/start = at + length(needle)
	var/index = start
	var/limit = length(entry)
	while(index <= limit)
		var/char = copytext(entry, index, index + 1)
		if(char == ";" || char == "}")
			break
		index++
	return trim(copytext(entry, start, index))

/// A mapped boolean var edit, falling back to the type's compiled value.
/proc/vc_test_entry_boolean(entry, var_name, type_default)
	var/text = vc_test_entry_var(entry, var_name)
	if(isnull(text))
		return type_default
	if(text == "0" || text == "FALSE" || text == "null")
		return FALSE
	return TRUE

/// The `dir` a mapped atom spawns with: mapped edit first, compiled default second.
/proc/vc_test_entry_dir(entry)
	var/text = vc_test_entry_var(entry, "dir")
	if(text)
		return text2num(text)
	var/atom/probe = vc_test_entry_type(entry)
	return probe ? initial(probe.dir) : SOUTH

/// The piping layer a mapped atmospherics machine spawns on.
/proc/vc_test_entry_piping_layer(entry)
	var/text = vc_test_entry_var(entry, "piping_layer")
	if(text)
		return text2num(text)
	var/obj/machinery/atmospherics/probe = vc_test_entry_type(entry)
	return probe ? initial(probe.piping_layer) : PIPING_LAYER_DEFAULT

/**
 * Dense movables a crewman still gets past.
 *
 * Doors open. Tables and railings are climbed over. Windows and grilles block a
 * whole tile only when they are fulltile, and counting every one of them as
 * passable keeps the reachability check permissive on purpose: it exists to
 * prove a crew spawn is *not* walled in, so it must never invent a wall that
 * is not there. Everything else falls through to the type's own `density`.
 */
/proc/vc_test_is_passable_when_dense(atom/movable/resolved)
	return ispath(resolved, /obj/machinery/door) \
		|| ispath(resolved, /obj/structure/window) \
		|| ispath(resolved, /obj/structure/grille) \
		|| ispath(resolved, /obj/structure/table) \
		|| ispath(resolved, /obj/structure/railing) \
		|| ispath(resolved, /obj/structure/mineral_door) \
		|| ispath(resolved, /obj/structure/holosign) \
		|| ispath(resolved, /obj/machinery/power/shuttle_engine)

/// Machines that make power. Storage (SMES) and draw (thrusters) are not here.
/proc/vc_test_is_power_generator(atom/movable/resolved)
	return ispath(resolved, /obj/machinery/power/port_gen) \
		|| ispath(resolved, /obj/machinery/power/rtg) \
		|| ispath(resolved, /obj/machinery/power/thermoelectric_generator) \
		|| ispath(resolved, /obj/machinery/power/solar) \
		|| ispath(resolved, /obj/machinery/power/energy_accumulator) \
		|| ispath(resolved, /obj/machinery/power/supermatter_crystal)

/// Everything one mapped atom contributes to its tile, memoised by entry text.
/proc/vc_test_entry_flags(entry)
	var/static/list/cache = list()
	if(entry in cache)
		return cache[entry]
	var/tile_flags = NONE
	var/resolved = vc_test_entry_type(entry)
	if(!resolved)
		cache[entry] = tile_flags
		return tile_flags

	if(ispath(resolved, /turf))
		if(ispath(resolved, /turf/closed))
			tile_flags |= VC_TILE_BLOCKED
		else if(ispath(resolved, /turf/open) && !ispath(resolved, /turf/open/space))
			tile_flags |= VC_TILE_OPEN
		cache[entry] = tile_flags
		return tile_flags

	if(!ispath(resolved, /atom/movable))
		cache[entry] = tile_flags
		return tile_flags

	var/atom/movable/probe = resolved
	if(vc_test_entry_boolean(entry, "density", initial(probe.density)) && !vc_test_is_passable_when_dense(resolved))
		tile_flags |= VC_TILE_BLOCKED
	if(ispath(resolved, /obj/machinery))
		tile_flags |= VC_TILE_MACHINE
	if(ispath(resolved, /obj/machinery/cryopod))
		tile_flags |= VC_TILE_CRYOPOD
	if(ispath(resolved, /obj/structure/cable))
		tile_flags |= VC_TILE_CABLE
	if(ispath(resolved, /obj/machinery/power/apc))
		tile_flags |= VC_TILE_APC
	if(ispath(resolved, /obj/machinery/power/smes))
		tile_flags |= VC_TILE_SMES
	if(ispath(resolved, /obj/machinery/power/terminal))
		tile_flags |= VC_TILE_TERMINAL
	if(vc_test_is_power_generator(resolved))
		tile_flags |= VC_TILE_GENERATOR
	if(ispath(resolved, /obj/machinery/atmospherics))
		var/piping_layer = vc_test_entry_piping_layer(entry)
		if(piping_layer == 4)
			tile_flags |= VC_TILE_ATMOS_L4
		else if(piping_layer == 2)
			tile_flags |= VC_TILE_ATMOS_L2
		if(ispath(resolved, /obj/machinery/atmospherics/pipe))
			// The colour subtypes (/supply, /scrubbers) only set pipe_color; the
			// layer comes from /layerN. The trunk needs both halves of the name.
			var/path_text = vc_test_entry_path_text(entry)
			if(piping_layer == 4 && findtext(path_text, "/supply/"))
				tile_flags |= VC_TILE_TRUNK_L4
			if(piping_layer == 2 && findtext(path_text, "/scrubbers/"))
				tile_flags |= VC_TILE_TRUNK_L2
	cache[entry] = tile_flags
	return tile_flags

/// The union of every atom's flags on one tile.
/proc/vc_test_atoms_flags(list/atoms)
	var/tile_flags = NONE
	for(var/entry in atoms)
		tile_flags |= vc_test_entry_flags(entry)
	return tile_flags

/// The flags of a dictionary key's tile, memoised per map.
/datum/vc_test_dmm/proc/flags_for_key(key)
	if(isnull(key))
		return NONE
	if(key in key_flag_cache)
		return key_flag_cache[key]
	var/tile_flags = vc_test_atoms_flags(dictionary[key])
	key_flag_cache[key] = tile_flags
	return tile_flags

/// The flags of one tile of this map.
/datum/vc_test_dmm/proc/flags_at(x, y)
	if(x < 1 || y < 1 || x > width || y > height)
		return NONE
	return flags_for_key(grid[(y - 1) * width + x])

/// Every placement of `path_prefix` on this map, as list(x, y, entry text).
/datum/vc_test_dmm/proc/find_instances(path_prefix)
	if(path_prefix in instance_cache)
		return instance_cache[path_prefix]
	var/list/found = list()
	var/list/matching_keys = list()
	for(var/key in dictionary)
		for(var/entry in dictionary[key])
			if(findtextEx(vc_test_entry_path_text(entry), path_prefix) == 1)
				matching_keys[key] = TRUE
				break
	if(length(matching_keys))
		for(var/y in 1 to height)
			for(var/x in 1 to width)
				var/key = grid[(y - 1) * width + x]
				if(isnull(key) || !matching_keys[key])
					continue
				for(var/entry in dictionary[key])
					if(findtextEx(vc_test_entry_path_text(entry), path_prefix) == 1)
						found += list(list(x, y, entry))
	instance_cache[path_prefix] = found
	return found

/**
 * The map's content with TGM key letters and within-tile atom order removed.
 *
 * Two files that hash the same here are the same room whatever their letters
 * say, which is how a "themed" variant that is a verbatim copy of its sibling
 * gets caught - the raw files are not byte-identical.
 */
/datum/vc_test_dmm/proc/fingerprint()
	if(content_fingerprint)
		return content_fingerprint
	var/list/rows = list()
	for(var/y in 1 to height)
		for(var/x in 1 to width)
			var/key = grid[(y - 1) * width + x]
			var/list/atoms = isnull(key) ? null : dictionary[key]
			rows += length(atoms) ? jointext(sort_list(atoms), "|") : ""
	content_fingerprint = md5(jointext(rows, "\n"))
	return content_fingerprint

/**
 * ## One hull plus one module per slot, as the loader builds it
 *
 * /datum/map_template/map_module/load() offsets the module so its single
 * /obj/modular_map_connector lands on the hull's slot marker tile, and the map
 * reader skips /turf/template_noop and /area/template_noop so the hull's own
 * turf and area show through. Nothing is cleared first: module movables stack
 * on top of whatever the hull already had there. Both markers then qdel.
 */
/datum/vc_test_ship
	var/label
	var/width = 0
	var/height = 0
	/// flat, index -> /list of atom entry text
	var/list/tiles
	/// flat, index -> tile flag bitfield
	var/list/tile_flags
	/// flat, index -> /list of the atoms the *module* placed there (null elsewhere)
	var/list/module_atoms
	/// flat, index -> /list of the atoms the *hull* had there before the module landed
	var/list/hull_atoms
	/// flat, index -> the slot key whose module wrote this tile
	var/list/module_slots

/// One playable configuration: a hull map plus a choice of module per slot.
/datum/vc_test_fitout
	var/hull_type
	var/theme_id
	var/hull_map
	var/label
	/// slot key -> module `.dmm` path
	var/list/slot_maps

/datum/vc_test_ship/proc/tile_x(index)
	return ((index - 1) % width) + 1

/datum/vc_test_ship/proc/tile_y(index)
	return round((index - 1) / width) + 1

/// A tile's coordinates as "(x,y)", for failure messages.
/datum/vc_test_ship/proc/tile_coords(index)
	return "([tile_x(index)],[tile_y(index)])"

/// The `.dmm` a module resolves to on a theme: `<base>_<theme>.dmm`, else `<base>.dmm`.
/proc/vc_test_module_map_path(datum/ship_upgrade_module/module, theme_id)
	var/themed = "[SHIP_MODULE_MAP_ROOT][vc_test_themed_module_filename(module.map_file, theme_id)]"
	if(fexists(themed))
		return themed
	var/base = "[SHIP_MODULE_MAP_ROOT][module.map_file]"
	return fexists(base) ? base : null

/proc/vc_test_build_fitout(hull_type, theme_id, hull_map, label, list/slot_maps)
	var/datum/vc_test_fitout/fitout = new
	fitout.hull_type = hull_type
	fitout.theme_id = theme_id
	fitout.hull_map = hull_map
	fitout.label = label
	fitout.slot_maps = slot_maps
	return fitout

/**
 * Every fitout worth checking: for each hull and theme, the all-defaults ship,
 * plus one ship per non-default module with that module in its slot and
 * defaults everywhere else.
 *
 * Sweeping single substitutions rather than the full product keeps this at a
 * couple of hundred assemblies instead of millions and still reaches every
 * module file at least once, which is the point. Kilo's default service module
 * is the one that does not seal the dorms; only substituting the other three
 * finds the trap.
 */
/proc/vc_test_ship_fitouts()
	var/static/list/fitouts
	if(fitouts)
		return fitouts
	fitouts = list()
	ensure_ship_upgrades_initialized()
	var/list/hulls = vc_test_voidcrew_hull_templates()

	for(var/hull_type in GLOB.ship_themes)
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		if(!hull)
			continue
		var/list/themes = GLOB.ship_themes[hull_type]
		for(var/theme_id in themes)
			var/datum/ship_theme/theme = themes[theme_id]
			var/hull_map = "[hull.prefix]ship_[theme.template_suffix].dmm"
			if(!fexists(hull_map))
				continue // voidcrew_ship_modules.dm owns missing theme maps
			var/list/slot_ids = get_upgrade_slot_ids_for_theme(hull, theme)
			var/list/defaults = list()
			for(var/slot_key in slot_ids)
				for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull_type, theme_id, slot_key))
					if(!module.is_default)
						continue
					var/map_path = vc_test_module_map_path(module, theme_id)
					if(map_path)
						defaults[slot_key] = map_path
			fitouts += vc_test_build_fitout(hull_type, theme_id, hull_map, "[theme.template_suffix] (slot defaults)", defaults)
			for(var/slot_key in slot_ids)
				for(var/datum/ship_upgrade_module/module as anything in get_modules_for_ship_slot(hull_type, theme_id, slot_key))
					if(module.is_default)
						continue
					var/map_path = vc_test_module_map_path(module, theme_id)
					if(!map_path)
						continue // voidcrew_ship_modules.dm owns modules with no map on disk
					var/list/choices = defaults.Copy()
					choices[slot_key] = map_path
					fitouts += vc_test_build_fitout(hull_type, theme_id, hull_map, "[theme.template_suffix] with [slot_key] = [module.id]", choices)

	// Themeless modular hulls (the Pill, the dev fixture) never enter the loop
	// above, but they have slots, and their crew has to get out of the cryopod too.
	for(var/hull_type in GLOB.ship_upgrade_modules)
		if(length(GLOB.ship_themes[hull_type]))
			continue
		var/datum/map_template/shuttle/voidcrew/hull = hulls[hull_type]
		if(!hull || !fexists(hull.mappath))
			continue
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		var/list/defaults = list()
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			if(!module.is_default)
				continue
			var/map_path = vc_test_module_map_path(module, null)
			if(map_path)
				defaults[module.slot] = map_path
		fitouts += vc_test_build_fitout(hull_type, null, hull.mappath, "[hull_type] (slot defaults)", defaults)
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			if(module.is_default)
				continue
			var/map_path = vc_test_module_map_path(module, null)
			if(!map_path)
				continue
			var/list/choices = defaults.Copy()
			choices[module.slot] = map_path
			fitouts += vc_test_build_fitout(hull_type, null, hull.mappath, "[hull_type] with [module.slot] = [module_id]", choices)

	return fitouts

/// Runs the loader's placement arithmetic and hands back the assembled ship.
/proc/vc_test_assemble_ship(datum/vc_test_fitout/fitout)
	var/datum/vc_test_dmm/hull = vc_test_parse_dmm(fitout.hull_map)
	if(!hull)
		return null

	var/datum/vc_test_ship/ship = new
	ship.label = fitout.label
	ship.width = hull.width
	ship.height = hull.height
	var/tile_count = hull.width * hull.height
	ship.tiles = new /list(tile_count)
	ship.tile_flags = new /list(tile_count)
	ship.module_atoms = new /list(tile_count)
	ship.hull_atoms = new /list(tile_count)
	ship.module_slots = new /list(tile_count)
	for(var/index in 1 to tile_count)
		var/key = hull.grid[index]
		if(isnull(key))
			continue
		ship.tiles[index] = hull.dictionary[key]
		ship.tile_flags[index] = hull.flags_for_key(key)

	for(var/list/marker as anything in hull.find_instances("/obj/modular_map_root/ship_upgrade"))
		var/marker_x = marker[1]
		var/marker_y = marker[2]
		var/marker_entry = marker[3]
		var/marker_index = (marker_y - 1) * hull.width + marker_x
		// the marker qdels itself after loading, filled slot or not
		var/list/without_marker = list()
		for(var/entry in ship.tiles[marker_index])
			if(entry != marker_entry)
				without_marker += entry
		ship.tiles[marker_index] = without_marker
		ship.tile_flags[marker_index] = vc_test_atoms_flags(without_marker)

		var/slot_key = vc_test_unquote(vc_test_entry_var(marker_entry, "key"))
		var/module_map = slot_key ? fitout.slot_maps[slot_key] : null
		if(!module_map)
			continue
		var/datum/vc_test_dmm/module = vc_test_parse_dmm(module_map)
		if(!module)
			continue
		var/list/connectors = module.find_instances("/obj/modular_map_connector")
		if(length(connectors) != 1)
			continue // voidcrew_ship_modules.dm owns the connector count
		var/list/connector = connectors[1]
		var/connector_x = connector[1]
		var/connector_y = connector[2]

		for(var/module_y in 1 to module.height)
			for(var/module_x in 1 to module.width)
				var/module_key = module.grid[(module_y - 1) * module.width + module_x]
				if(isnull(module_key))
					continue
				var/ship_x = marker_x + module_x - connector_x
				var/ship_y = marker_y + module_y - connector_y
				if(ship_x < 1 || ship_y < 1 || ship_x > hull.width || ship_y > hull.height)
					continue // overhang; there is no hull tile to check it against
				var/ship_index = (ship_y - 1) * hull.width + ship_x
				var/list/module_tile = module.dictionary[module_key]
				if(length(module_tile) < 2)
					continue
				var/list/module_movables = list()
				for(var/atom_index in 1 to length(module_tile) - 2)
					var/entry = module_tile[atom_index]
					if(vc_test_entry_is(entry, /obj/modular_map_connector))
						continue
					module_movables += entry
				var/module_turf = module_tile[length(module_tile) - 1]
				var/module_area = module_tile[length(module_tile)]

				var/list/hull_tile = ship.tiles[ship_index] || list()
				var/list/hull_movables = list()
				for(var/atom_index in 1 to max(length(hull_tile) - 2, 0))
					hull_movables += hull_tile[atom_index]
				var/hull_turf = length(hull_tile) >= 2 ? hull_tile[length(hull_tile) - 1] : null
				var/hull_area = length(hull_tile) >= 1 ? hull_tile[length(hull_tile)] : null

				var/list/merged = hull_movables + module_movables
				var/resolved_turf = vc_test_entry_is(module_turf, /turf/template_noop) ? hull_turf : module_turf
				var/resolved_area = vc_test_entry_is(module_area, /area/template_noop) ? hull_area : module_area
				if(resolved_turf)
					merged += resolved_turf
				if(resolved_area)
					merged += resolved_area

				ship.tiles[ship_index] = merged
				ship.tile_flags[ship_index] = vc_test_atoms_flags(merged)
				ship.module_atoms[ship_index] = module_movables
				ship.hull_atoms[ship_index] = hull_movables
				ship.module_slots[ship_index] = slot_key
	return ship

/// Strips the quotes off a mapped string var edit.
/proc/vc_test_unquote(text)
	if(!text)
		return null
	if(copytext(text, 1, 2) == "\"")
		text = copytext(text, 2)
	if(copytext(text, -1) == "\"")
		text = copytext(text, 1, length(text))
	return text

/// The tile index one step in `direction`, or null off the edge or on a diagonal.
/datum/vc_test_ship/proc/step_index(index, direction)
	var/x = tile_x(index)
	switch(direction)
		if(NORTH)
			return (index + width <= length(tile_flags)) ? index + width : null
		if(SOUTH)
			return (index > width) ? index - width : null
		if(EAST)
			return (x < width) ? index + 1 : null
		if(WEST)
			return (x > 1) ? index - 1 : null
	return null

/**
 * Flood-fills the walkable deck.
 *
 * Returns list(component id by tile index, id of the largest component).
 */
/datum/vc_test_ship/proc/walkable_components()
	var/tile_count = length(tile_flags)
	var/list/components = new /list(tile_count)
	var/next_id = 0
	var/largest_id = 0
	var/largest_size = 0
	for(var/start in 1 to tile_count)
		if(components[start])
			continue
		var/start_flags = tile_flags[start]
		if(!(start_flags & VC_TILE_OPEN) || (start_flags & VC_TILE_BLOCKED))
			continue
		next_id++
		var/size = 0
		var/list/frontier = list(start)
		while(length(frontier))
			var/index = frontier[length(frontier)]
			frontier.len--
			if(components[index])
				continue
			var/flags_here = tile_flags[index]
			if(!(flags_here & VC_TILE_OPEN) || (flags_here & VC_TILE_BLOCKED))
				continue
			components[index] = next_id
			size++
			var/x = tile_x(index)
			if(x > 1)
				frontier += index - 1
			if(x < width)
				frontier += index + 1
			if(index > width)
				frontier += index - width
			if(index + width <= tile_count)
				frontier += index + width
		if(size > largest_size)
			largest_size = size
			largest_id = next_id
	return list(components, largest_id)

/**
 * Flood-fills a network over every tile carrying `required_flags`.
 *
 * `cut_edges` is an optional set of "low|high" tile-index pairs the fill must
 * not cross, which is how Connect_cable()'s SMES/own-terminal severance is
 * modelled. Returns list(component id by tile index, id of the largest).
 */
/datum/vc_test_ship/proc/flag_network(required_flags, list/cut_edges)
	var/tile_count = length(tile_flags)
	var/list/components = new /list(tile_count)
	var/next_id = 0
	var/largest_id = 0
	var/largest_size = 0
	for(var/start in 1 to tile_count)
		if(components[start] || !(tile_flags[start] & required_flags))
			continue
		next_id++
		var/size = 0
		var/list/frontier = list(start)
		while(length(frontier))
			var/index = frontier[length(frontier)]
			frontier.len--
			if(components[index] || !(tile_flags[index] & required_flags))
				continue
			components[index] = next_id
			size++
			var/x = tile_x(index)
			var/list/neighbours = list()
			if(x > 1)
				neighbours += index - 1
			if(x < width)
				neighbours += index + 1
			if(index > width)
				neighbours += index - width
			if(index + width <= tile_count)
				neighbours += index + width
			for(var/neighbour in neighbours)
				if(cut_edges && cut_edges["[min(index, neighbour)]|[max(index, neighbour)]"])
					continue
				frontier += neighbour
		if(size > largest_size)
			largest_size = size
			largest_id = next_id
	return list(components, largest_id)

/**
 * Where an SMES's input terminal is, by /obj/machinery/power/smes/Initialize()'s
 * rule: a terminal on a cardinally adjacent tile whose own `dir` points back at
 * the SMES. An SMES that finds none calls atom_break() and spawns broken.
 */
/datum/vc_test_ship/proc/smes_terminal_index(index)
	var/x = tile_x(index)
	var/tile_count = length(tile_flags)
	// neighbour tile index (as text, so it is a key and not a list position) ->
	// the dir that neighbour's terminal must face to be ours
	var/list/candidates = list()
	if(index + width <= tile_count)
		candidates[num2text(index + width)] = SOUTH
	if(index > width)
		candidates[num2text(index - width)] = NORTH
	if(x < width)
		candidates[num2text(index + 1)] = WEST
	if(x > 1)
		candidates[num2text(index - 1)] = EAST
	for(var/candidate_text in candidates)
		var/candidate = text2num(candidate_text)
		if(!(tile_flags[candidate] & VC_TILE_TERMINAL))
			continue
		for(var/entry in tiles[candidate])
			if(!vc_test_entry_is(entry, /obj/machinery/power/terminal))
				continue
			if(vc_test_entry_dir(entry) == candidates[candidate_text])
				return candidate
	return null

/**
 * The cable links Connect_cable() refuses to make.
 *
 * A cable under an SMES never links to the cable under that SMES's own input
 * terminal (code/modules/power/cable.dm:96-114). That severance is deliberate -
 * it is how charge goes in one side and out the other - and it means an SMES
 * terminal genuinely needs its own run back to the net, which is exactly what
 * the Goon's north thruster never had.
 */
/datum/vc_test_ship/proc/smes_terminal_cuts()
	var/list/cuts = list()
	for(var/index in 1 to length(tile_flags))
		if(!(tile_flags[index] & VC_TILE_SMES))
			continue
		var/terminal_index = smes_terminal_index(index)
		if(terminal_index)
			cuts["[min(index, terminal_index)]|[max(index, terminal_index)]"] = TRUE
	return cuts

/// Whether any tile in `component_id` carries `wanted_flags`, ignoring one tile.
/datum/vc_test_ship/proc/network_carries(list/components, component_id, wanted_flags, ignore_index)
	if(!component_id)
		return FALSE
	for(var/index in 1 to length(components))
		if(index == ignore_index)
			continue
		if(components[index] == component_id && (tile_flags[index] & wanted_flags))
			return TRUE
	return FALSE

/**
 * Every run the module laid that stops at the seam instead of crossing it.
 *
 * Returns list(tile index -> message fragment) so the caller can raise them
 * through TEST_FAIL with its own file and line.
 */
/datum/vc_test_ship/proc/module_runs_left_stranded(run_flag, list/fill)
	var/list/stranded = list()
	var/list/components = fill[1]
	var/largest = fill[2]
	if(!largest)
		return stranded
	for(var/index in 1 to length(tile_flags))
		var/list/placed = module_atoms[index]
		if(!length(placed) || !(vc_test_atoms_flags(placed) & run_flag))
			continue
		if(!components[index] || components[index] == largest)
			continue
		stranded[num2text(index)] = TRUE
	return stranded

/**
 * # Every crew spawn can walk out of the room it spawns in
 *
 * Kilo's dorms wing has exactly one usable opening: a shuttle airlock at (13,4)
 * whose only approach from the cafe side is (12,4), because (13,3) and (13,5)
 * are wall. Ten of the fifteen kilo_service module files put a rack or a
 * freezer crate on (12,4). Take Hydroponics, Surgery or the Saloon Bar on any
 * theme but pink and all three cryopods - the entire crew - spawn into a
 * nine-tile pocket with no way out, on a ship that renders and loads perfectly.
 *
 * The assertion is reachability, not a coordinate: every cryopod must touch the
 * ship's largest walkable area. A pod behind a window or a closed airlock
 * passes. A pod behind a rack does not.
 */
/datum/unit_test/voidcrew_ship_cryopod_egress
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_cryopod_egress/Run()
	var/list/fitouts = vc_test_ship_fitouts()
	TEST_ASSERT(length(fitouts) >= 40, "only [length(fitouts)] hull/theme/module fitouts were built - the modular registry walk is not seeing the fleet")
	var/pods_checked = 0
	for(var/datum/vc_test_fitout/fitout as anything in fitouts)
		var/datum/vc_test_ship/ship = vc_test_assemble_ship(fitout)
		if(!ship)
			continue
		var/list/fill = ship.walkable_components()
		var/list/components = fill[1]
		var/largest = fill[2]
		if(!largest)
			continue // no walkable deck at all; the hull tests own that
		var/list/stranded = list()
		for(var/index in 1 to length(ship.tile_flags))
			if(!(ship.tile_flags[index] & VC_TILE_CRYOPOD))
				continue
			pods_checked++
			if(ship.tile_reaches_component(index, components, largest))
				continue
			stranded += ship.tile_coords(index)
		if(length(stranded))
			TEST_FAIL("[fitout.label]: [length(stranded)] cryopod\s, at [jointext(stranded, ", ")], cannot reach the ship's largest walkable area. \
				Every one of those is a crew spawn point, so a crew that picks this fitout wakes up sealed in. Something dense - a rack, \
				a crate, a closet - is standing on the one tile that connects that room to the rest of the hull. Move it: a module tile \
				that carries a room's only doorway approach has to stay walkable, however roomy the rest of the module looks.")
	TEST_ASSERT(pods_checked >= 40, "only [pods_checked] cryopods were reached across [length(fitouts)] fitouts - the assembly walk is not finding crew spawns")

/// Whether a tile, or any tile cardinally next to it, is in `component_id`.
/datum/vc_test_ship/proc/tile_reaches_component(index, list/components, component_id)
	if(components[index] == component_id)
		return TRUE
	var/x = tile_x(index)
	if(x > 1 && components[index - 1] == component_id)
		return TRUE
	if(x < width && components[index + 1] == component_id)
		return TRUE
	if(index > width && components[index - width] == component_id)
		return TRUE
	if(index + width <= length(components) && components[index + width] == component_id)
		return TRUE
	return FALSE

/**
 * # What a module brings aboard has to join what the hull already has
 *
 * Five assertions over one sweep of assembled fitouts:
 *
 * 1. **A module's vents connect.** atmos_init() finds a device's node with
 *    get_step() only (atmosmachinery.dm:287-295), never on its own tile, so a
 *    vent needs a matching-layer pipe on the tile it faces.
 * 2. **A module's cable and trunk pipes reach the hull's.** Phalanx's *default*
 *    medbay shipped a one-tile hole at (26,12) that split its service run in
 *    two: the medbay APC ended up on a dead net and the operating theatre's
 *    only supply vent on a three-tile island, on all four themes.
 * 3. **Every APC has power.** The same defect seen from the other end.
 * 4. **Every SMES can recharge.** Its input terminal has to sit on a powernet
 *    that reaches something which makes or stores power. The Goon's north
 *    thruster SMES sat on a one-tile net, so the thruster ran on stored charge
 *    until it was flat and then died for the rest of the round, silently.
 * 5. **A module does not restate what the hull already put on a tile.** Module
 *    movables stack on hull movables - the loader never clears the tile - so
 *    "both sides ship an autolathe" means two autolathes in one square.
 *
 * Bare hulls are deliberately not swept: several families put the whole power
 * plant in an engineering module, so an unfitted hull is *meant* to have dead
 * nets. What a crew flies is always hull plus a module in every slot.
 */
/datum/unit_test/voidcrew_ship_module_services
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_module_services/Run()
	var/list/fitouts = vc_test_ship_fitouts()
	TEST_ASSERT(length(fitouts) >= 40, "only [length(fitouts)] fitouts were built - the modular registry walk is not seeing the fleet")
	// One mapping mistake shows up in every fitout that loads that module, so
	// each distinct site is reported once.
	var/list/reported = list()
	var/smes_checked = 0
	var/apcs_checked = 0
	for(var/datum/vc_test_fitout/fitout as anything in fitouts)
		var/datum/vc_test_ship/ship = vc_test_assemble_ship(fitout)
		if(!ship)
			continue
		var/tile_count = length(ship.tile_flags)

		// --- 1. module-placed unary vents ------------------------------------
		for(var/index in 1 to tile_count)
			var/list/placed = ship.module_atoms[index]
			if(!length(placed))
				continue
			for(var/entry in placed)
				if(!vc_test_entry_is(entry, /obj/machinery/atmospherics/components/unary/vent_pump) \
					&& !vc_test_entry_is(entry, /obj/machinery/atmospherics/components/unary/vent_scrubber))
					continue
				var/piping_layer = vc_test_entry_piping_layer(entry)
				if(piping_layer != 4 && piping_layer != 2)
					continue // a local loop, not the hull trunk - see the hull vent test
				var/wanted = (piping_layer == 4) ? VC_TILE_ATMOS_L4 : VC_TILE_ATMOS_L2
				var/target = ship.step_index(index, vc_test_entry_dir(entry))
				if(target && (ship.tile_flags[target] & wanted))
					continue
				var/site = "vent|[ship.module_slots[index]]|[vc_test_entry_path_text(entry)]|[ship.tile_coords(index)]"
				if(reported[site])
					continue
				reported[site] = TRUE
				TEST_FAIL("[fitout.label]: the [vc_test_entry_path_text(entry)] that the [ship.module_slots[index]] module places at \
					[ship.tile_coords(index)] faces a tile with no atmospherics machine on piping layer [piping_layer], so it connects \
					to nothing and its room is never supplied or never scrubbed. atmos_init() resolves a device's node with get_step() \
					only - pipes on the vent's own tile do not count - and `dir` is SOUTH when a mapper leaves it off. Point the vent \
					at the trunk, or run the trunk to the tile it already faces.")

		// --- 2. cable and trunk pipe continuity across the seam ---------------
		var/list/cable_fill = ship.flag_network(VC_TILE_CABLE, null)
		var/list/supply_fill = ship.flag_network(VC_TILE_ATMOS_L4, null)
		var/list/scrubber_fill = ship.flag_network(VC_TILE_ATMOS_L2, null)
		var/list/runs = list(
			"cable" = list(VC_TILE_CABLE, cable_fill, "the module's APC and everything on its wire are cut off from the ship's power"),
			"supply pipe (layer 4)" = list(VC_TILE_TRUNK_L4, supply_fill, "the module's rooms are scrubbed but never resupplied with air"),
			"scrubbers pipe (layer 2)" = list(VC_TILE_TRUNK_L2, scrubber_fill, "the module's rooms fill with whatever is breathed or burned in them"),
		)
		for(var/run_name in runs)
			var/list/run = runs[run_name]
			var/list/stranded = ship.module_runs_left_stranded(run[1], run[2])
			for(var/index_text in stranded)
				var/index = text2num(index_text)
				var/site = "[fitout.hull_map]|[run_name]|[ship.module_slots[index]]|[ship.tile_coords(index)]"
				if(reported[site])
					continue
				reported[site] = TRUE
				TEST_FAIL("[fitout.label]: the [run_name] that the [ship.module_slots[index]] module lays at [ship.tile_coords(index)] \
					is on an island - it never joins the ship's main run, so [run[3]]. A one-tile hole anywhere between the module's own \
					run and the hull stub it is meant to meet does this, and it is invisible in a render because hidden pipe and cable \
					draw under the floor either way.")

		// --- 3 & 4. powernet: APCs and SMES terminals -------------------------
		var/list/powernet = ship.flag_network(VC_TILE_CABLE, ship.smes_terminal_cuts())
		var/list/powernet_components = powernet[1]
		for(var/index in 1 to tile_count)
			if(ship.tile_flags[index] & VC_TILE_APC)
				apcs_checked++
				var/site = "[fitout.hull_map]|apc|[ship.tile_coords(index)]"
				if(!(ship.tile_flags[index] & VC_TILE_CABLE))
					if(!reported[site])
						reported[site] = TRUE
						TEST_FAIL("[fitout.label]: the APC at [ship.tile_coords(index)] has no cable under it. An APC draws through a \
							terminal on its own turf, so with no wire there its area is unpowered from the moment the ship loads.")
				else if(!ship.network_carries(powernet_components, powernet_components[index], VC_TILE_GENERATOR | VC_TILE_SMES, 0))
					if(!reported[site])
						reported[site] = TRUE
						TEST_FAIL("[fitout.label]: the APC at [ship.tile_coords(index)] is on a powernet that reaches no generator and \
							no SMES, so that whole area is dark from roundstart. This is what a one-tile gap in a module's cable run \
							looks like from the other end - trace the wire from this APC back towards the hull and find where it stops.")

			if(!(ship.tile_flags[index] & VC_TILE_SMES))
				continue
			smes_checked++
			var/site = "[fitout.hull_map]|smes|[ship.tile_coords(index)]"
			var/terminal_index = ship.smes_terminal_index(index)
			if(!terminal_index)
				if(!reported[site])
					reported[site] = TRUE
					TEST_FAIL("[fitout.label]: the SMES at [ship.tile_coords(index)] has no input terminal facing it. \
						/obj/machinery/power/smes/Initialize() calls atom_break() when it cannot find one, so this SMES spawns broken \
						and never charges. Map an /obj/machinery/power/terminal on an adjacent tile with its `dir` pointing back at the SMES.")
				continue
			if(!(ship.tile_flags[terminal_index] & VC_TILE_CABLE))
				if(!reported[site])
					reported[site] = TRUE
					TEST_FAIL("[fitout.label]: the SMES at [ship.tile_coords(index)] has its input terminal on \
						[ship.tile_coords(terminal_index)], which has no cable under it. The terminal is the SMES's only way in; with no \
						wire there it charges from nothing.")
				continue
			if(ship.network_carries(powernet_components, powernet_components[terminal_index], VC_TILE_GENERATOR, 0) \
				|| ship.network_carries(powernet_components, powernet_components[terminal_index], VC_TILE_SMES, index))
				continue
			if(reported[site])
				continue
			reported[site] = TRUE
			TEST_FAIL("[fitout.label]: the SMES at [ship.tile_coords(index)] has its input terminal on a powernet that reaches no \
				generator and no other SMES, so it can never recharge - it runs on the charge it spawned with and then sits flat for the \
				rest of the round, which on a thruster SMES reads in-game as an engine that simply stopped. Note that Connect_cable() \
				deliberately refuses to link the cable under an SMES to the cable under its own terminal, so the terminal needs its own \
				run back to the main net; cabling it straight to the SMES does nothing.")

		// --- 5. module movables restating hull movables on one tile -----------
		for(var/index in 1 to tile_count)
			var/list/placed = ship.module_atoms[index]
			var/list/already = ship.hull_atoms[index]
			if(!length(placed) || !length(already))
				continue
			for(var/entry in placed)
				if(!(vc_test_entry_flags(entry) & VC_TILE_MACHINE))
					continue
				var/path_text = vc_test_entry_path_text(entry)
				var/doubled = FALSE
				for(var/hull_entry in already)
					if(vc_test_entry_path_text(hull_entry) == path_text)
						doubled = TRUE
						break
				if(!doubled)
					continue
				var/site = "[fitout.hull_map]|duplicate|[path_text]|[ship.tile_coords(index)]"
				if(reported[site])
					continue
				reported[site] = TRUE
				TEST_FAIL("[fitout.label]: the [ship.module_slots[index]] module places a second [path_text] on \
					[ship.tile_coords(index)], where the hull already has one. Module movables stack on top of hull movables - the loader \
					never clears the tile - so this ship sails with two of them in the same square, one of them buried and unusable. \
					Decide which side owns it and have the other drop its copy.")

	TEST_ASSERT(smes_checked >= 10, "only [smes_checked] SMES units were reached across [length(fitouts)] fitouts")
	TEST_ASSERT(apcs_checked >= 40, "only [apcs_checked] APCs were reached across [length(fitouts)] fitouts")

/**
 * # Every unary vent and scrubber has a pipe to talk to
 *
 * atmos_init() resolves a device's node with `get_step(src, node_connects[i])`
 * and nothing else (atmosmachinery.dm:287-295), so a unary device connects to
 * the tile it *faces* and never to the pipes it is standing on. `dir` is SOUTH
 * when the mapper leaves it off, which is how the Goon's port pod ended up with
 * an air vent and a scrubber both aimed at the shower wall while three pipe
 * manifolds sat under them, unnoticed, on all four themes. That pod is the
 * ship's biggest room, and it had no air supply and no scrubbing in any fitout.
 *
 * This is a fleet-wide class rather than a Goon quirk: it was found on
 * twenty-one hulls at seventy instances.
 *
 * Only layer 4 (supply) and layer 2 (scrubbers) are asserted. Layers 1/3/5 are
 * self-contained local loops - Delta's Cryo Ward runs a closed layer-3 freezer
 * circuit on purpose, which physically cannot join the hull trunk and is right
 * not to.
 */
/datum/unit_test/voidcrew_hull_vent_connectivity
	priority = TEST_LONGER

/datum/unit_test/voidcrew_hull_vent_connectivity/Run()
	var/list/maps = vc_test_fleet_hull_maps()
	TEST_ASSERT(length(maps) > 20, "the hull map scan found only [length(maps)] .dmm files - wrong root?")
	var/checked = 0
	for(var/map_path in maps)
		var/datum/vc_test_dmm/map = vc_test_parse_dmm(map_path)
		if(!map)
			continue
		for(var/device_path in list(/obj/machinery/atmospherics/components/unary/vent_pump, /obj/machinery/atmospherics/components/unary/vent_scrubber))
			for(var/list/instance as anything in map.find_instances("[device_path]"))
				var/entry = instance[3]
				var/piping_layer = vc_test_entry_piping_layer(entry)
				if(piping_layer != 4 && piping_layer != 2)
					continue
				checked++
				var/facing = vc_test_entry_dir(entry)
				var/x = instance[1]
				var/y = instance[2]
				if(facing == NORTH)
					y++
				else if(facing == SOUTH)
					y--
				else if(facing == EAST)
					x++
				else if(facing == WEST)
					x--
				else
					TEST_FAIL("[map_path]: the [vc_test_entry_path_text(entry)] at ([x],[y]) is mapped facing dir [facing]. A unary \
						atmospherics device only ever looks for its node in one cardinal direction, so a diagonal `dir` leaves it \
						connected to nothing at all.")
					continue
				var/wanted = (piping_layer == 4) ? VC_TILE_ATMOS_L4 : VC_TILE_ATMOS_L2
				if(map.flags_at(x, y) & wanted)
					continue
				TEST_FAIL("[map_path]: the [vc_test_entry_path_text(entry)] at ([instance[1]],[instance[2]]) faces ([x],[y]), which \
					carries no atmospherics machine on piping layer [piping_layer]. atmos_init() finds a device's node with get_step() \
					only, so this vent is joined to nothing and the room it serves has no supply or no scrubbing whatsoever - the pipes \
					under the vent's own tile do not count, however many of them there are. `dir` defaults to SOUTH when it is left off, \
					which is usually the cause. Point it at the trunk.")
	TEST_ASSERT(checked >= 300, "only [checked] trunk-layer unary vents were checked across the fleet - the scan is not reading the maps")

/**
 * # Wired generators are bolted down
 *
 * /obj/machinery/power/port_gen ships `anchored = FALSE` and no PACMAN subtype
 * overrides it, which is right for the loose spare in a maintenance closet and
 * wrong for a ship's power plant. Unanchored, a generator is inert four ways:
 * should_have_node() returns `anchored`, connect_to_network() opens with
 * `if(!anchored) return FALSE`, process() switches it straight back off, and
 * its own TGUI gates `ready_to_boot = anchored && HasFuel()` - so a player
 * cannot even start it from the machine's own interface. It renders identically
 * to a working one, and power_audit.py, which only checks that a cable shares
 * the tile, calls the ship fine.
 *
 * The Blackpill's single generator shipped this way. The white Pill's, one map
 * over, writes `anchored = 1`.
 *
 * A generator standing on a cable is by definition wired into a plant, so that
 * is where the line is drawn: on a wire, it must be anchored. Off a wire it is
 * a spare and is allowed to be loose - Goon's TEG module ships exactly one.
 */
/datum/unit_test/voidcrew_ship_generators_anchored
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_generators_anchored/Run()
	var/list/maps = vc_test_fleet_hull_maps() + vc_test_fleet_module_maps()
	var/checked = 0
	for(var/map_path in maps)
		var/datum/vc_test_dmm/map = vc_test_parse_dmm(map_path)
		if(!map)
			continue
		for(var/list/instance as anything in map.find_instances("/obj/machinery/power/port_gen"))
			checked++
			var/entry = instance[3]
			var/obj/machinery/power/port_gen/probe = vc_test_entry_type(entry)
			if(!probe || vc_test_entry_boolean(entry, "anchored", initial(probe.anchored)))
				continue
			if(!(map.flags_at(instance[1], instance[2]) & VC_TILE_CABLE))
				continue // a loose spare on a bare tile, which is fine
			TEST_FAIL("[map_path]: the [vc_test_entry_path_text(entry)] at ([instance[1]],[instance[2]]) stands on a cable but is not \
				anchored. An unanchored generator fails should_have_node() and connect_to_network(), so it never joins the powernet \
				however much fuel it has, and its own UI refuses to boot it because ready_to_boot is `anchored && HasFuel()`. A ship \
				whose plant is mapped this way launches on stored SMES charge and goes dark when that runs out, with nothing anywhere \
				saying why. Add `anchored = 1`.")
	TEST_ASSERT(checked >= 20, "only [checked] mapped generators were found across the fleet - the scan is not reading the maps")

/**
 * # A themed variant is a different room, not a copy with different letters
 *
 * The loader prefers `<base>_<theme>.dmm` and falls back to `<base>.dmm`
 * (modular_map_root_ship.dm:85-90), so a theme file exists precisely to look
 * different. Three of Scarab's syndicate medical variants are content-identical
 * to the medical ones - the same objects on the same tiles, differing only in
 * TGM key letters and the order atoms happen to be listed within a tile - so
 * the syndicate refit buys a medbay in Nanotrasen livery and nothing says so.
 *
 * The fingerprint normalises both of those away, which is what makes this
 * catchable: the raw files are not byte-identical.
 *
 * There are two honest fixes and the message names both, because for a family
 * whose modules have no unthemed base file on disk, deleting the duplicate is
 * not one of them - load_module() hits `if(!fexists(mapfile))` and silently
 * qdels the slot marker, leaving a hole in the ship.
 */
/datum/unit_test/voidcrew_ship_module_theme_variants
	priority = TEST_LONGER

/datum/unit_test/voidcrew_ship_module_theme_variants/Run()
	ensure_ship_upgrades_initialized()
	var/compared = 0
	for(var/hull_type in GLOB.ship_upgrade_modules)
		var/list/themes = GLOB.ship_themes[hull_type]
		if(!length(themes))
			continue
		var/list/modules = GLOB.ship_upgrade_modules[hull_type]
		for(var/module_id in modules)
			var/datum/ship_upgrade_module/module = modules[module_id]
			// fingerprint -> the name of the first file that produced it
			var/list/seen = list()
			var/base_path = "[SHIP_MODULE_MAP_ROOT][module.map_file]"
			var/datum/vc_test_dmm/base_map = fexists(base_path) ? vc_test_parse_dmm(base_path) : null
			if(base_map)
				seen[base_map.fingerprint()] = module.map_file
			for(var/theme_id in themes)
				var/themed_file = vc_test_themed_module_filename(module.map_file, theme_id)
				var/themed_path = "[SHIP_MODULE_MAP_ROOT][themed_file]"
				if(!fexists(themed_path))
					continue // this theme falls back to the base file, which is fine
				var/datum/vc_test_dmm/themed_map = vc_test_parse_dmm(themed_path)
				if(!themed_map)
					continue
				compared++
				var/print = themed_map.fingerprint()
				var/twin = seen[print]
				if(!twin)
					seen[print] = themed_file
					continue
				TEST_FAIL("[themed_file] is content-identical to [twin]: the same atoms on the same tiles, differing only in TGM key \
					letters and within-tile ordering. A `_[theme_id]` file exists only to make that theme look different, so as it \
					stands this one charges a player for a reskin and hands them the other theme's room. Either re-theme it - turfs, \
					decals and theme-appropriate kit swaps, never a changed layout - or delete it so the loader falls back to the base \
					file. Deleting is only safe when a base [module.map_file] actually exists on disk: with no base, load_module() hits \
					`if(!fexists(mapfile))` and quietly qdels the slot marker, leaving a hole in the ship.")
	TEST_ASSERT(compared >= 80, "only [compared] themed module variants were compared - the variant scan is not seeing the fleet")

/// Every hull `.dmm` the two whole-fleet scans above are responsible for.
/proc/vc_test_fleet_hull_maps()
	var/static/list/hull_maps
	if(hull_maps)
		return hull_maps
	hull_maps = list()
	var/list/unaudited = vc_test_unaudited_hull_maps()
	for(var/entry in flist(SHIP_HULL_MAP_ROOT))
		// flist() lists the backup/ directory alongside the maps; superseded
		// copies in there are not part of the fleet.
		if(copytext(entry, -4) != ".dmm")
			continue
		if(unaudited[entry])
			continue
		hull_maps += "[SHIP_HULL_MAP_ROOT][entry]"
	return hull_maps

/// Every module `.dmm` on disk, whether or not a datum references it.
/proc/vc_test_fleet_module_maps()
	var/static/list/module_maps
	if(module_maps)
		return module_maps
	var/list/collected = list()
	vc_test_collect_dmm_files(SHIP_MODULE_MAP_ROOT, collected)
	module_maps = list()
	for(var/map_path in collected)
		module_maps += map_path
	return module_maps

/**
 * Hull maps exempted from the two whole-fleet map scans above.
 *
 * Every entry is an NPC, derelict or event hull: none is on the purchase shelf,
 * none is rolled into the roundstart fleet, and none was part of the modular
 * fleet audit these tests come out of. They were inherited with the fork and
 * carry known instances of both defects - 22 disconnected unary vents and 51
 * unanchored wired generators between them. They are named here rather than
 * silently excluded so that the debt is written down, and so that a hull which
 * is *not* on this list has to pass: a newly authored hull with either defect
 * fails immediately.
 *
 * Delete an entry when its hull is brought up to fleet standard.
 */
/proc/vc_test_unaudited_hull_maps()
	var/static/list/unaudited = list(
		"ship_bogatyr.dmm" = TRUE, // Bogatyr NPC hull: 1 wired generator left unanchored
		"ship_box.dmm" = TRUE, // Box NPC hull: 1 vent facing a bare tile
		"ship_boyardee.dmm" = TRUE, // Boyardee NPC hull: 1 wired generator left unanchored
		"ship_boyardee_b.dmm" = TRUE, // Boyardee variant: 1 wired generator left unanchored
		"ship_dwayne.dmm" = TRUE, // Dwayne NPC hull: 2 wired generators left unanchored
		"ship_energia.dmm" = TRUE, // Energia NPC hull: 2 wired generators left unanchored
		"ship_high.dmm" = TRUE, // High NPC hull: 5 vents facing bare tiles
		"ship_hightide.dmm" = TRUE, // Hightide NPC hull: 2 wired generators left unanchored
		"ship_honk.dmm" = TRUE, // Honk NPC hull: 5 vents, 1 wired generator
		"ship_irish.dmm" = TRUE, // Irish NPC hull: 1 wired generator left unanchored
		"ship_lamia.dmm" = TRUE, // Lamia NPC hull: 1 wired generator left unanchored
		"ship_libertatia.dmm" = TRUE, // Libertatia NPC hull: 1 vent, 2 wired generators
		"ship_luxembourg.dmm" = TRUE, // Luxembourg NPC hull: 2 vents, 2 wired generators
		"ship_mechaton.dmm" = TRUE, // Mechaton NPC hull: 1 vent facing a bare tile
		"ship_metis.dmm" = TRUE, // Metis NPC hull: 2 wired generators left unanchored
		"ship_midway.dmm" = TRUE, // Midway NPC hull: 3 vents facing bare tiles
		"ship_nano_bead.dmm" = TRUE, // Bead NPC hull: 2 wired generators left unanchored
		"ship_nano_thunderbird.dmm" = TRUE, // Thunderbird NPC hull: 5 wired generators
		"ship_osprey.dmm" = TRUE, // Osprey NPC hull: 5 wired generators left unanchored
		"ship_pirate_geode.dmm" = TRUE, // pirate hull: 1 vent facing a bare tile
		"ship_pirate_grey.dmm" = TRUE, // pirate hull: 2 vents, 3 wired generators
		"ship_pirate_irs.dmm" = TRUE, // pirate hull: 1 vent, 1 wired generator
		"ship_spitfire.dmm" = TRUE, // Spitfire NPC hull: 1 wired generator left unanchored
		"ship_syndicate_geneva.dmm" = TRUE, // Geneva NPC hull: 1 wired generator left unanchored
		"ship_syndicate_hyena.dmm" = TRUE, // Hyena NPC hull: 1 wired generator left unanchored
	)
	return unaudited

#undef SHIP_MODULE_MAP_ROOT
#undef SHIP_HULL_MAP_ROOT
#undef VC_TILE_OPEN
#undef VC_TILE_BLOCKED
#undef VC_TILE_CRYOPOD
#undef VC_TILE_CABLE
#undef VC_TILE_APC
#undef VC_TILE_SMES
#undef VC_TILE_TERMINAL
#undef VC_TILE_GENERATOR
#undef VC_TILE_ATMOS_L4
#undef VC_TILE_ATMOS_L2
#undef VC_TILE_TRUNK_L4
#undef VC_TILE_TRUNK_L2
#undef VC_TILE_MACHINE
