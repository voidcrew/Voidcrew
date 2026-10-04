/// A registry snapshot deliberately serializes a small set of construction data.
/// It never calls admin-export hooks (silos emit stock) or turf get_save_vars (air).

/// Ship wiring, plumbing and doors: rebuilt in the Systems stage, before other machinery.
GLOBAL_LIST_INIT(outpost_checkpoint_infrastructure, typecacheof(list(
	/obj/machinery/door,
	/obj/machinery/atmospherics,
	/obj/machinery/disposal,
	/obj/machinery/power/apc,
	/obj/machinery/power/terminal,
	/obj/machinery/airalarm,
	/obj/machinery/firealarm,
	/obj/machinery/light,
	/obj/machinery/button,
	/obj/machinery/camera,
	/obj/machinery/power/shuttle_engine,
	/obj/machinery/light_switch,
	// A meter lands with its pipe, or it cannot find one and drops itself as an item.
	/obj/machinery/meter,
)))

/**
 * Everything built into a hull is saved except these: movable gas stock, and things that make
 * creatures or resources. Whatever a saved object holds is scrubbed on load (see clear_stock()),
 * so new fixtures need no entry here unless they invent supplies some other way.
 */
GLOBAL_LIST_INIT(outpost_checkpoint_excluded, typecacheof(list(
	/obj/machinery/portable_atmospherics,
	/obj/machinery/computer/ship_checkpoint,
	// Made by its turret.
	/obj/machinery/porta_turret_cover,
	// Never rebuilt: user decision, 2026-09-24.
	/obj/machinery/syndicatebomb,
	/obj/machinery/power/supermatter_crystal,
	/obj/structure/disposalholder,
	/obj/structure/spawner,
	/obj/structure/alien,
	/obj/structure/spider,
	/obj/structure/blob,
	/obj/structure/flora,
	/obj/structure/geyser,
	/obj/structure/ore_vent,
	/obj/structure/holosign,
	/obj/structure/trap,
	// Made of the spear and head it holds; clear_stock() takes those and it falls apart.
	/obj/structure/headpike,
	// Outpost property that works a ship bay's side rooms, never a ship's fitting.
	/obj/structure/outpost_yard_droid,
)))

/**
 * Hull terrain a checkpoint cannot rebuild. Any other turf is saved as it is, so ship features
 * such as pools, hot springs and dirt planters need no entry anywhere.
 * - Mineable rock and asteroid ground hand out ore or sand on every rebuild.
 * - Planetary atmosphere regenerates air forever wherever it is placed.
 * - Lava, chasms and open space are hazards or multi-level holes, not hull.
 */
GLOBAL_LIST_INIT(outpost_checkpoint_refused_terrain, typecacheof(list(
	/turf/closed/mineral,
	/turf/open/misc/asteroid,
	/turf/open/lava,
	/turf/open/chasm,
	/turf/open/openspace,
)))

/proc/checkpoint_refuses_terrain(turf/tile)
	if(is_type_in_typecache(tile, GLOB.outpost_checkpoint_refused_terrain))
		return TRUE
	if(isopenturf(tile))
		var/turf/open/open_tile = tile
		return open_tile.planetary_atmos
	return FALSE

/// Whether a checkpoint keeps this object. Machinery also needs a type to rebuild as.
/proc/outpost_checkpoint_saves(obj/object)
	if(object.flags_1 & HOLOGRAM_1 || is_type_in_typecache(object, GLOB.outpost_checkpoint_excluded))
		return FALSE
	if(ismachinery(object))
		var/obj/machinery/machine = object
		return !!machine.checkpoint_type()
	return isstructure(object)

/datum/ship_checkpoint
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/datum/weakref/source_ship
	var/captain_ckey
	var/ship_name
	var/saved_at
	var/tgm
	var/width
	var/height
	var/port_x
	var/port_y
	var/list/rooms = list()
	/// Construction parts only; no live references or saved inventories.
	var/list/machines = list()
	var/busy = FALSE
	var/error

/datum/ship_checkpoint/Destroy()
	if(outpost)
		outpost.checkpoints -= src
	var/obj/structure/overmap/ship/original = source_ship?.resolve()
	if(original?.checkpoint_ref?.resolve() == src)
		original.checkpoint_ref = null
	outpost = null
	source_ship = null
	tgm = null
	rooms = null
	machines = null
	return ..()

/// Ports are handled separately and cannot carry NPC types.
/datum/ship_checkpoint/proc/includes_object(obj/object)
	return outpost_checkpoint_saves(object)

/// Preserve placement and construction settings; inventories are never serialized.
/datum/ship_checkpoint/proc/atom_text(atom/object)
	var/list/properties = list()
	var/list/keys = list("dir", "color", "pixel_x", "pixel_y", "name")
	var/saved_type = object.type
	if(ismachinery(object))
		var/obj/machinery/machine = object
		saved_type = machine.checkpoint_type()
		machines += list(capture_machine(machine))
		properties += "checkpoint_load_id = [length(machines)]"
		if(istype(machine, /obj/machinery/power/smes))
			keys += list("input_level", "output_level")
		if(istype(machine, /obj/machinery/power))
			keys += "cable_layer"
	if(istype(object, /obj/structure/closet))
		// Closets keep their own type, so they look the same; their stock is never generated
		// (below) and anything they spawn is scrubbed on load. Emergency closets are the
		// exception: they can delete or replace themselves as they initialize.
		if(istype(object, /obj/structure/closet/emcloset))
			saved_type = /obj/structure/closet
		if(istype(object, /obj/structure/closet/crate))
			keys += list("lid_icon", "lid_icon_state")
		keys += list("icon", "icon_door", "base_icon_state", "enable_door_overlay", "has_opened_overlay", "has_closed_overlay", "wall_mounted", "horizontal", "locked", "req_one_access")
		// Closet stock is otherwise generated lazily on first opening.
		properties += "contents_initialized = 1"
	if(istype(object, /obj/machinery/light))
		// Lights otherwise materialize a charged mock battery after map loading.
		properties += "start_with_cell = 0"
	if(!object.smoothing_flags)
		keys += "icon_state"
	if(isobj(object))
		keys += list("anchored", "req_access", "id_tag")
	if(istype(object, /obj/machinery/atmospherics))
		keys += list("piping_layer", "pipe_color")
	// Which side each port faces: a flipped filter or mixer, and the ports opened on a tank.
	if(istype(object, /obj/machinery/atmospherics/components/trinary))
		keys += "flipped"
	if(istype(object, /obj/machinery/atmospherics/components/tank))
		keys += "open_ports"
	if(istype(object, /obj/machinery/duct))
		keys += list("duct_layer", "duct_color", "connects")
	for(var/key in keys)
		var/value = object.vars[key]
		// Always encode direction: an oriented source must survive a round trip.
		if(saved_type == object.type && key != "dir" && value == initial(object.vars[key]))
			continue
		if(istext(value))
			value = replacetext(value, "\\", "")
		var/encoded = tgm_encode(value)
		if(encoded)
			properties += "[key] = [encoded]"
	return "[saved_type]{\n\t[properties.Join(";\n\t")]\n\t}"

/// A captain saves their own ship.
/datum/ship_checkpoint/proc/capture(obj/structure/overmap/ship/ship, mob/living/captain)
	if(QDELETED(ship?.shuttle) || !ship.is_ship_captain(captain) || !captain.ckey)
		return "Only the ship's captain can save a checkpoint."
	return capture_hull(ship, captain.ckey)

/// Capture only this port's owned tiles, including its docking tile and hull holes. The
/// caller decides who may save the ship and who owns the checkpoint.
/datum/ship_checkpoint/proc/capture_hull(obj/structure/overmap/ship/ship, owner_ckey)
	var/obj/docking_port/mobile/voidcrew/port = ship?.shuttle
	if(QDELETED(port) || !owner_ckey)
		return "The source hull is no longer available."
	if(port.z_levels_above || port.z_levels_below)
		return "Checkpoints currently support single-level ships only."
	var/list/bounds = port.return_coords()
	var/min_x = min(bounds[1], bounds[3])
	var/min_y = min(bounds[2], bounds[4])
	width = abs(bounds[3] - bounds[1]) + 1
	height = abs(bounds[4] - bounds[2]) + 1
	if(max(width, height) > RESERVE_DOCK_MAX_SIZE_LONG || min(width, height) > RESERVE_DOCK_MAX_SIZE_SHORT)
		return "This hull is too large for a ship bay."
	port_x = port.x - min_x + 1
	port_y = port.y - min_y + 1
	var/list/owned_areas = hull_owned_areas(port)
	var/list/area_ids = list()
	var/list/headers = list()
	var/list/header_keys = list()
	var/list/columns = list()
	var/ports_found = 0
	for(var/local_x in 1 to width)
		var/list/column = list()
		for(var/local_y in height to 1 step -1)
			CHECK_TICK
			var/turf/tile = locate(min_x + local_x - 1, min_y + local_y - 1, port.z)
			var/area/room = get_area(tile)
			var/list/atoms = list()
			if(!(room in owned_areas))
				atoms = list("/turf/template_noop", "/area/template_noop")
			else
				if(checkpoint_refuses_terrain(tile))
					return "Replace the hull's [tile.name] terrain with constructed flooring before saving a checkpoint."
				var/room_id = area_ids[room]
				if(!room_id)
					rooms += list(list("name" = room.name, "type" = room.type, "tiles" = list()))
					room_id = length(rooms)
					area_ids[room] = room_id
				var/list/room_data = rooms[room_id]
				var/list/room_tiles = room_data["tiles"]
				room_tiles += list(list(local_x, local_y))
				for(var/obj/object in tile)
					if(istype(object, /obj/docking_port/mobile))
						if(object != port)
							return "Another mobile docking port overlaps this hull."
						ports_found++
						// Rebuild a player port, never an NPC/event-specific port subtype.
						atoms += "/obj/docking_port/mobile/voidcrew{\n\tdir = [port.dir];\n\tarea_type = [port.area_type];\n\tpreferred_direction = [port.preferred_direction];\n\tport_direction = [port.port_direction]\n\t}"
					else if(includes_object(object))
						atoms += atom_text(object)
				atoms += atom_text(tile)
				atoms += "[room.type]"
			var/header = "(\n[atoms.Join(",\n")])\n"
			var/map_key = header_keys[header]
			if(!map_key)
				map_key = calculate_tgm_header_index(length(headers) + 1, 3)
				header_keys[header] = map_key
				headers += "\"[map_key]\" = [header]"
			column += map_key
		columns += "\n([local_x],1,1) = {\"\n[column.Join("\n")]\n\"}"
	if(ports_found != 1)
		return "The ship's mobile docking port is outside its hull."
	if(QDELETED(ship) || QDELETED(port))
		return "The source hull is no longer available."
	tgm = "//[DMM2TGM_MESSAGE]\n[headers.Join()][columns.Join()]"
	if(length(tgm) > OUTPOST_CHECKPOINT_MAX_TEXT)
		return "The hull design exceeds checkpoint capacity."
	var/datum/parsed_map/validated = new(tgm)
	var/valid = validated.bounds?[MAP_MAXX] == width && validated.bounds?[MAP_MAXY] == height
	qdel(validated)
	if(!valid)
		return "The hull design could not be read back. No payment was taken."
	source_ship = WEAKREF(ship)
	captain_ckey = owner_ckey
	ship_name = ship.name
	saved_at = world.time
	return null

/// The commissioned template supplies ship ownership without a disk-backed map.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint
	name = "Recovered Hull"
	abstract = /datum/map_template/shuttle/voidcrew/commissioned/checkpoint
	var/datum/ship_checkpoint/blueprint

/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/New(datum/ship_checkpoint/snapshot)
	..()
	blueprint = snapshot
	if(!snapshot)
		return
	name = snapshot.ship_name
	shuttle_id = "registry_[REF(snapshot)]"
	cached_map = new /datum/parsed_map(snapshot.tgm)
	width = snapshot.width
	height = snapshot.height
	port_x_offset = snapshot.port_x
	port_y_offset = snapshot.port_y

/// Restore distinct player-built rooms before machines initialize their APC links.
/// A plain TGM load otherwise merges rooms sharing one /area type.
/datum/map_template/shuttle/voidcrew/commissioned/checkpoint/initTemplateBounds(list/bounds)
	mark_phase("read")
	var/list/replaced_areas = list()
	for(var/list/room_data as anything in blueprint.rooms)
		var/area/room_type = room_data["type"]
		var/area/room = new room_type
		room.setup(room_data["name"])
		room.requires_power = TRUE
		for(var/list/coords as anything in room_data["tiles"])
			var/turf/tile = locate(bounds[MAP_MINX] + coords[1] - 1, bounds[MAP_MINY] + coords[2] - 1, bounds[MAP_MINZ])
			replaced_areas |= get_area(tile)
			tile.change_area(get_area(tile), room)
	for(var/area/old_room as anything in replaced_areas)
		if(!old_room.has_contained_turfs())
			qdel(old_room)
	if(spread_load)
		return init_bounds_spread(bounds)
	mark_phase("rooms")
	. = ..()
	mark_phase("init_bounds")
