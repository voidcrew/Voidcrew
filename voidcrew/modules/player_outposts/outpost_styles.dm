/**
 * # Outpost styles
 *
 * A player outpost has a style (voidcrew/_DEFINES/outpost_styles.dm), taken from the shell its
 * founder picked. Everything the outpost builds afterwards loads the map drawn for that style: its
 * upgrade rooms and its ship bay.
 *
 * A room or bay is a family of map templates: an abstract base type with no map, and one subtype per
 * style that sets `outpost_style` and `mappath`. outpost_style_map() picks the member for a style.
 * A family with no map for a style falls back to OUTPOST_STYLE_DEFAULT, then to any member, so a
 * new style works before every room has been drawn for it. A template with a map and no style (a
 * test room, say) serves every style.
 *
 * Adding a style: a define, a shell template (outpost_shells.dm) with that style, and a subtype per
 * room family with a map. Nothing else changes.
 */

/// The outpost style this map is drawn in, or null for a map that serves every style
/datum/map_template/var/outpost_style

/// The template type in `base_type`'s family drawn for `style` (see the file comment), or null when the family has no map at all
/proc/outpost_style_map(base_type, style)
	var/static/list/resolved = list()
	var/key = "[base_type]|[style]"
	if(key in resolved)
		return resolved[key]
	var/exact
	var/fallback
	var/unstyled
	var/any
	for(var/datum/map_template/candidate as anything in outpost_style_maps(base_type))
		var/candidate_style = initial(candidate.outpost_style)
		if(!exact && candidate_style == style)
			exact = candidate
		if(!fallback && candidate_style == OUTPOST_STYLE_DEFAULT)
			fallback = candidate
		if(!unstyled && !candidate_style)
			unstyled = candidate
		any ||= candidate
	. = exact || fallback || unstyled || any
	resolved[key] = .

/// Every template type in `base_type`'s family whose map file exists, the base included
/proc/outpost_style_maps(base_type)
	var/static/list/families = list()
	if(families[base_type])
		return families[base_type]
	var/list/members = list()
	for(var/datum/map_template/candidate as anything in typesof(base_type))
		var/map_path = initial(candidate.mappath)
		if(map_path && fexists(map_path))
			members += candidate
	families[base_type] = members
	return members

/// The baked preview's base name for a template type: its map file's name without the extension
/proc/outpost_map_preview_name(datum/map_template/template_type)
	var/map_path = initial(template_type.mappath)
	if(!map_path)
		return null
	var/list/parts = splittext(map_path, "/")
	var/file_name = parts[length(parts)]
	return copytext(file_name, 1, length(file_name) - 3) // drop ".dmm"
