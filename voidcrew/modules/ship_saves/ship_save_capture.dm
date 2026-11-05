/// Hull pieces a saved ship always keeps, whatever they are made of. Windows and grilles stay as
/// they are; false walls and mineral doors are saved as their plain iron versions.
GLOBAL_LIST_INIT(ship_save_sealing_structures, typecacheof(list(
	/obj/structure/window,
	/obj/structure/grille,
	/obj/structure/falsewall,
	/obj/structure/mineral_door,
)))

/// Build a statue of gold and save it for two parts, and you could break it down next round.
/proc/ship_save_refuses_object(obj/object)
	if(!isstructure(object) || is_type_in_typecache(object, GLOB.ship_save_sealing_structures))
		return FALSE
	for(var/material_key in object.custom_materials)
		var/datum/material/material = GET_MATERIAL_REF(material_key)
		if(!istype(material, /datum/material/iron) && !istype(material, /datum/material/glass))
			return TRUE
	return FALSE

/// Text macros are raw bytes the database connection would mangle. A saved name goes without them.
/proc/ship_save_plain_text(text)
	return replacetext(replacetext(text, "\improper", ""), "\proper", "")

/// Tiles in the rooms this hull owns, which is what a save is priced on.
/proc/hull_owned_tile_count(obj/docking_port/mobile/port)
	. = 0
	if(QDELETED(port) || !port.z)
		return
	for(var/area/room as anything in hull_owned_areas(port))
		. += length(room.get_turfs_by_zlevel(port.z))

/datum/ship_checkpoint/proc/owned_tile_count()
	. = 0
	for(var/list/room as anything in rooms)
		var/list/tiles = room["tiles"]
		. += length(tiles)

/**
 * A saved hull keeps its look but only ever comes apart into iron, so nothing valuable carries
 * into the next round. Takes the keys and properties atom_text() is building.
 * Returns the type to save the atom as.
 */
/datum/ship_checkpoint/proc/strip_salvage(atom/object, saved_type, list/keys, list/properties)
	var/plain_type
	if(istype(object, /turf/closed/wall))
		var/turf/closed/wall/wall = object
		if(wall.sheet_type != /obj/item/stack/sheet/iron)
			properties += "sheet_type = /obj/item/stack/sheet/iron"
	else if(istype(object, /turf/open/floor/mineral))
		properties += "floor_tile = /obj/item/stack/tile/iron"
	else if(istype(object, /obj/structure/falsewall))
		plain_type = /obj/structure/falsewall
	else if(istype(object, /obj/structure/mineral_door))
		plain_type = /obj/structure/mineral_door/iron
	if(!plain_type || plain_type == object.type)
		return saved_type
	// Not "gold door" on a plain iron door, or a state the plain type doesn't have.
	keys -= list("name", "icon_state")
	return plain_type

// A shuttle move rebuilds every turf from its type, which would undo strip_salvage() the first
// time a saved hull is placed or flown.
/turf/closed/wall/copyTurf(turf/closed/wall/copy_to_turf, copy_air = FALSE, flags = null)
	. = ..()
	if(istype(copy_to_turf))
		copy_to_turf.sheet_type = sheet_type

/turf/open/floor/copyTurf(turf/open/floor/copy_to_turf, copy_air = FALSE, flags = null)
	. = ..()
	if(istype(copy_to_turf))
		copy_to_turf.floor_tile = floor_tile

/// The text stored for a captured ship. Paths become text so saves outlive code changes.
/datum/ship_saves/proc/encode(datum/ship_checkpoint/snapshot)
	var/list/rooms = list()
	for(var/list/room as anything in snapshot.rooms)
		rooms += list(list("name" = ship_save_plain_text(room["name"]), "type" = "[room["type"]]", "tiles" = room["tiles"]))
	var/list/jobs = list()
	for(var/list/definition in snapshot.jobs)
		var/list/job = list()
		for(var/key in definition)
			var/value = definition[key]
			job[key] = ispath(value) ? "[value]" : value
		jobs += list(job)
	return json_encode(list(
		"format" = SHIP_SAVE_FORMAT,
		"name" = snapshot.ship_name,
		"class" = snapshot.class_name,
		"width" = snapshot.width,
		"height" = snapshot.height,
		"port_x" = snapshot.port_x,
		"port_y" = snapshot.port_y,
		"rooms" = rooms,
		"jobs" = jobs,
		"tgm" = snapshot.tgm,
	))

/**
 * Turns stored text back into a checkpoint, or null if this build can't use it. Can sleep. Types
 * removed since the save fall back where they can: unknown rooms become plain ship rooms, a job
 * whose outfit is gone is dropped, and the map reader skips unknown objects.
 */
/datum/ship_saves/proc/decode(text)
	var/list/data = safe_json_decode(text)
	if(!islist(data) || data["format"] != SHIP_SAVE_FORMAT)
		return null
	var/width = data["width"]
	var/height = data["height"]
	if(!isnum(width) || !isnum(height) || min(width, height) < 1)
		return null
	if(max(width, height) > RESERVE_DOCK_MAX_SIZE_LONG || min(width, height) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return null
	if(!istext(data["tgm"]) || !isnum(data["port_x"]) || !isnum(data["port_y"]) || !islist(data["rooms"]))
		return null
	var/datum/ship_checkpoint/snapshot = new
	snapshot.persistent = TRUE
	snapshot.ship_name = data["name"]
	snapshot.class_name = data["class"]
	snapshot.width = width
	snapshot.height = height
	snapshot.port_x = data["port_x"]
	snapshot.port_y = data["port_y"]
	snapshot.tgm = data["tgm"]
	for(var/list/room in data["rooms"])
		var/room_type = text2path(room["type"])
		if(!ispath(room_type, /area))
			room_type = /area/shuttle/voidcrew
		snapshot.rooms += list(list("name" = room["name"], "type" = room_type, "tiles" = room["tiles"]))
	var/list/jobs = list()
	for(var/list/definition in data["jobs"])
		var/list/job = definition.Copy()
		job["outfit"] = text2path(job["outfit"])
		job["borg_model"] = text2path(job["borg_model"])
		if(!ship_job_definition_error(job))
			jobs += list(job)
	// With none left, the commissioned default applies.
	snapshot.jobs = length(jobs) ? jobs : null
	log_missing_types(snapshot)
	return snapshot

/// The map reader skips types removed since the save. Say which, so a missing fitting is explainable.
/datum/ship_saves/proc/log_missing_types(datum/ship_checkpoint/snapshot)
	var/list/seen = list()
	var/list/missing = list()
	var/regex/atom_path = new(@"^/\w[\w/]*", "gm")
	while(atom_path.Find(snapshot.tgm))
		var/path_text = atom_path.match
		if(!seen[path_text])
			seen[path_text] = TRUE
			if(!text2path(path_text))
				missing += path_text
		CHECK_TICK
	if(length(missing))
		log_game("Ship save [snapshot.ship_name] has types that no longer exist: [missing.Join(", ")]")
