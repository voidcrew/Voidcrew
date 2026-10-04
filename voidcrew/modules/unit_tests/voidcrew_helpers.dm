/**
 * # Shared helpers for the voidcrew conformance tests
 *
 * The fork's unit tests are data/template-conformance tests rather than
 * simulations: a CIBUILDING world boots MetaStation, not the voidcrew overmap,
 * so nothing may assume a ship, a planet or a live SSovermap exists. What they
 * do instead is walk registries with subtypesof()/initial() and text-scan the
 * shipped `.dmm`/`.dm` files, the pattern voidcrew_loot.dm established.
 *
 * These are global procs rather than procs on a shared /datum/unit_test parent
 * because the runner executes every /datum/unit_test subtype, so an abstract
 * "helpers" test type would show up in the results as a hollow pass.
 *
 * NOTE: unit-test files compile at their `code/modules/unit_tests` include
 * position, which is BEFORE `voidcrew/_DEFINES/`. Fork defines are not
 * available in any of these files. Use literals with a comment naming the
 * define, per the voidcrew_loot.dm convention.
 */

/**
 * Recursively reads every `.dm` file under `root` into `out` as path -> text.
 *
 * Only descends into real directories: flist() returns loose files alongside
 * them, and recursing into a file is what hung the missing_icons suite for a
 * week (see code/modules/unit_tests/missing_icons.dm).
 */
/proc/vc_test_collect_dm_files(root, list/out)
	for(var/entry in flist(root))
		if(copytext(entry, -1) == "/")
			vc_test_collect_dm_files("[root][entry]", out)
		else if(copytext(entry, -3) == ".dm")
			out["[root][entry]"] = file2text("[root][entry]")

/// Same, for `.dmm` map files.
/proc/vc_test_collect_dmm_files(root, list/out)
	for(var/entry in flist(root))
		if(copytext(entry, -1) == "/")
			vc_test_collect_dmm_files("[root][entry]", out)
		else if(copytext(entry, -4) == ".dmm")
			out["[root][entry]"] = file2text("[root][entry]")

/**
 * File text, read once per path per round.
 *
 * The map scans below read the same module `.dmm` from several angles; without
 * this the equipment test alone would re-read ~200 files.
 */
/proc/vc_test_file_text(path)
	var/static/list/cache = list()
	if(!(path in cache))
		cache[path] = fexists(path) ? file2text(path) : null
	return cache[path]

/**
 * Whether a TGM map's text places the given typepath.
 *
 * TGM entries terminate in "," (the list continues), "{" (var edits) or ")"
 * (last path in the block), so matching against those avoids prefix hits,
 * `/armory` would otherwise match `/armory/rare`. Same helper voidcrew_loot.dm
 * carries for its reachability scan.
 */
/proc/vc_test_map_has_path(text, path)
	return findtext(text, "[path],") || findtext(text, "[path]{") || findtext(text, "[path])")

/// How many times `needle` appears in `haystack`.
/proc/vc_test_count_occurrences(haystack, needle)
	var/count = 0
	var/position = findtext(haystack, needle)
	while(position)
		count++
		position = findtext(haystack, needle, position + length(needle))
	return count

/// Whether an ascii code could be part of a DM identifier (a-z A-Z 0-9 _).
/proc/vc_test_is_identifier_char(code)
	if(code >= 48 && code <= 57) // 0-9
		return TRUE
	if(code >= 65 && code <= 90) // A-Z
		return TRUE
	if(code >= 97 && code <= 122) // a-z
		return TRUE
	return code == 95 // _

/// Reads the run of digits starting at `start` as a number, or null.
/proc/vc_test_read_number(text, start)
	var/index = start
	var/limit = length(text)
	while(index <= limit)
		var/code = text2ascii(text, index)
		if(code < 48 || code > 57) // "0".."9"
			break
		index++
	if(index == start)
		return null
	return text2num(copytext(text, start, index))

/// Every typepath token in a comma-separated source fragment.
/proc/vc_test_split_paths(chunk)
	var/list/found = list()
	for(var/token in splittext(chunk, ","))
		token = trim(token)
		if(!length(token) || copytext(token, 1, 2) != "/")
			continue
		var/resolved = text2path(token)
		if(resolved)
			found += resolved
	return found

/**
 * Reads a `<list_var> = list(...)` block off every definition under
 * `prefix_path` in a pre-read source tree, as typepath -> list of typepaths.
 *
 * DM's initial() cannot read a list var, and the alternative, instantiating
 * the type to read the list off the instance. Is not safe for every type
 * (a vestige patron dresses an appearance dummy through an async callback that
 * must not outlive the qdel), so some list-shaped invariants can only be
 * checked against the source. Callers MUST assert on the number of definitions
 * matched: a scan that silently matches nothing is the exact failure mode that
 * left the rumor-chart guard passing vacuously for months.
 */
/proc/vc_test_scan_list_var(list/sources, prefix_path, list_var)
	var/list/result = list()
	var/opener = "[list_var] = list("
	var/prefix_length = length(prefix_path)
	for(var/file_path in sources)
		var/current
		var/collecting = FALSE
		var/list/collected
		for(var/line in splittext(sources[file_path], "\n"))
			if(copytext(line, 1, 2) == "/")
				// a new definition ends whatever block we were reading
				collecting = FALSE
				collected = null
				current = null
				if(findtextEx(line, "(")) // a proc definition, not a type block
					continue
				if(copytext(line, 1, prefix_length + 1) != prefix_path)
					continue
				var/header = line
				var/comment_at = findtextEx(header, "//")
				if(comment_at)
					header = copytext(header, 1, comment_at)
				var/space_at = findtextEx(header, " ")
				if(space_at)
					header = copytext(header, 1, space_at)
				current = text2path(trim(header))
				continue
			if(!current)
				continue
			var/trimmed = trim(line)
			if(collecting)
				if(trimmed == ")")
					result[current] = collected
					collecting = FALSE
					collected = null
				else
					collected += vc_test_split_paths(trimmed)
				continue
			if(findtextEx(trimmed, opener) != 1)
				continue
			var/tail = copytext(trimmed, length(opener) + 1)
			var/close_at = findtextEx(tail, ")")
			if(close_at) // single-line list
				result[current] = vc_test_split_paths(copytext(tail, 1, close_at))
				continue
			collecting = TRUE
			collected = list()
			collected += vc_test_split_paths(tail)
	return result

/// Every registered voidcrew hull template, keyed by typepath.
/proc/vc_test_voidcrew_hull_templates()
	var/list/by_type = list()
	for(var/shuttle_id in SSmapping.shuttle_templates)
		var/datum/map_template/shuttle/voidcrew/template = SSmapping.shuttle_templates[shuttle_id]
		if(!istype(template))
			continue
		by_type[template.type] = template
	return by_type

/**
 * Mirrors /obj/modular_map_root/ship_upgrade/proc/get_themed_filename: the
 * loader prefers `<base>_<theme>.dmm` and falls back to the base file.
 */
/proc/vc_test_themed_module_filename(base_file, theme_id)
	if(!theme_id)
		return base_file
	var/extension_at = findtextEx(base_file, ".dmm")
	if(!extension_at)
		return "[base_file]_[theme_id].dmm"
	return "[copytext(base_file, 1, extension_at)]_[theme_id].dmm"
