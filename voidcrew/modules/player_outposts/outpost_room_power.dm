/**
 * # Outpost room power
 *
 * Every upgrade room with its own area (the service rooms, the cargo dock, the prison wing) has one
 * room APC, and protected cable runs from it to under the room's exterior door. A room whose door lands
 * on the tile outside a habitat airlock (or another room's door) joins the habitat's grid when it
 * loads: the cables link and the template's powernet pass merges the nets. A room placed away from the
 * habitat joins once the owner builds a floor path to it: the feeder lays protected cable along it,
 * once per room. Until then a room runs on its APC's cell, and an outage in a room stays in that room.
 *
 * The shells run a protected trunk from the power room to under every outer airlock, so a room docked
 * at any of them meets the grid.
 */

// ===== AREAS =====

/// A service room's own area, one instance per installed room (no UNIQUE_AREA). Named for the room, so its APC is too.
/area/voidcrew/player_outpost/service_room
	name = "\improper Service Room"

/area/voidcrew/player_outpost/service_room/cloning_bay
	name = "\improper Cloning Bay"

/area/voidcrew/player_outpost/service_room/medical_lab
	name = "\improper Medical Lab"

/area/voidcrew/player_outpost/service_room/shop
	name = "\improper Shop"

/area/voidcrew/player_outpost/service_room/storage
	name = "\improper Safe Storage"

/area/voidcrew/player_outpost/service_room/teleporter
	name = "\improper Teleporter"

// ===== THE ROOM APC =====

/// A room's APC: outpost property, run only by the outpost's owner and stewards
/obj/machinery/power/apc/outpost
	auto_name = TRUE
	aidisabled = TRUE
	start_charge = 100

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/power/apc/outpost, APC_PIXEL_OFFSET)

/obj/machinery/power/apc/outpost/Initialize(mapload, ndir)
	. = ..()
	// Same protection as every other outpost fixture (outpost_service_rooms.dm), applied here
	// directly: the cargo dock and prison APCs never call protect_fixtures() on themselves.
	AddElement(/datum/element/outpost_property)
	flags_1 |= PREVENT_CONTENTS_EXPLOSION_1
	ADD_TRAIT(src, TRAIT_SINGULARITY_IMMUNE, OUTPOST_SERVICE_TRAIT)

/// Whether `user` may run this APC: an admin ghost, or the outpost's owner or a steward
/obj/machinery/power/apc/outpost/proc/outpost_admits(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	return !!home?.may_set_door_access(user)

/// Replaces req_access: an engineer's ID swipe or right-click unlock only works for the outpost's own people
/obj/machinery/power/apc/outpost/allowed(mob/user)
	return outpost_admits(user)

/obj/machinery/power/apc/outpost/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!outpost_admits(ui.user))
		return
	return ..()

/obj/machinery/power/apc/outpost/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "no effect!")
	return FALSE

// ===== THE PROTECTED CABLE =====

/// Outpost wiring: only the outpost's builders can cut it, and bombs, fire, acid and rats can't
/obj/structure/cable/outpost
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/structure/cable/outpost/Initialize(mapload)
	. = ..()
	// Spared like every other outpost fixture; a singularity must not pull a room off the grid
	ADD_TRAIT(src, TRAIT_SINGULARITY_IMMUNE, OUTPOST_SERVICE_TRAIT)

/// Whether `user` may cut this cable
/obj/structure/cable/outpost/proc/outpost_cut_allowed(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	return !home || home.can_build(user)

/// A wirecutter cut only goes through for the outpost's builders; multitool readings stay open to everyone
/obj/structure/cable/outpost/handlecable(obj/item/W, mob/user, list/modifiers)
	if(W.tool_behaviour == TOOL_WIRECUTTER && !outpost_cut_allowed(user))
		balloon_alert(user, "outpost property!")
		return
	return ..()

// Regal rats otherwise deconstruct any cable they interact with (cable.dm); outpost wiring is proof against them.
/obj/structure/cable/outpost/on_rat_eat(datum/source, mob/living/basic/regal_rat/king)
	SIGNAL_HANDLER
	return COMPONENT_RAT_INTERACTED

// ===== JOINING THE GRID =====

/datum/outpost_upgrade
	/// The feeder has joined this room to the grid, or found it already joined: it is never laid again
	var/feeder_laid = FALSE

/// The habitat's grid: the powernet on the habitat APC's terminal, or null
/obj/structure/overmap/dynamic/player_outpost/proc/main_grid()
	return outpost_area?.apc?.terminal?.powernet

/**
 * Lays feeder cable to every installed room that is not on the grid and has not been fed yet.
 * A room already touching the grid by contact (section 2.5) is marked fed without laying anything,
 * so an owner who later cuts its feed on purpose is never overruled by the next call.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/join_rooms_to_grid()
	var/datum/powernet/grid = main_grid()
	if(!grid)
		return
	for(var/upgrade_key in outpost_upgrades)
		var/datum/outpost_upgrade/upgrade = outpost_upgrades[upgrade_key]
		if(!upgrade?.installed || upgrade.snap_group || upgrade.feeder_laid || !upgrade.room_apc())
			continue
		if(upgrade.on_grid())
			upgrade.feeder_laid = TRUE
			continue
		upgrade.lay_feeder(grid)

/// Runs join_rooms_to_grid() shortly, once, however many turfs join the outpost meanwhile
/obj/structure/overmap/dynamic/player_outpost/proc/queue_room_power_join()
	addtimer(CALLBACK(src, PROC_REF(join_rooms_to_grid)), 2 SECONDS, TIMER_UNIQUE)

/// This room's own APC, or null (prison extensions run off the wing's, outside their own footprint)
/datum/outpost_upgrade/proc/room_apc()
	var/obj/machinery/power/apc/outpost/candidate = installed_area?.apc
	if(!istype(candidate) || installed_area == outpost?.outpost_area || !contains_turf(get_turf(candidate)))
		return null
	return candidate

/// Footprint tiles holding an airlock with a neighbour outside the footprint
/datum/outpost_upgrade/proc/exterior_door_turfs()
	. = list()
	for(var/turf/tile as anything in room_lookup())
		if(!(locate(/obj/machinery/door/airlock) in tile))
			continue
		for(var/direction in GLOB.cardinals)
			if(!contains_turf(get_step(tile, direction)))
				. += tile
				break

/// Whether this room's APC is on the habitat's grid
/datum/outpost_upgrade/proc/on_grid()
	var/datum/powernet/grid = outpost?.main_grid()
	return grid && room_apc()?.terminal?.powernet == grid

/// Whether `tile` holds a layer-2 cable whose powernet is exactly `net`
/datum/outpost_upgrade/proc/tile_cable_on_net(turf/tile, datum/powernet/net)
	if(!tile || !net)
		return FALSE
	for(var/obj/structure/cable/wire in tile)
		if((wire.cable_layer & CABLE_LAYER_2) && wire.powernet == net)
			return TRUE
	return FALSE

/// Whether `tile` holds a layer-2 cable of any kind
/datum/outpost_upgrade/proc/tile_has_any_cable(turf/tile)
	for(var/obj/structure/cable/wire in tile)
		if(wire.cable_layer & CABLE_LAYER_2)
			return TRUE
	return FALSE

/// Whether an outpost feeder may cross this tile: unclaimed outpost floor, not another room or the lobby alcove
/datum/outpost_upgrade/proc/feeder_tile_walkable(turf/tile)
	if(!tile || !isopenturf(tile) || isspaceturf(tile))
		return FALSE
	if(!outpost || get_area(tile) != outpost.outpost_area)
		return FALSE
	if(outpost.upgrade_at_turf(tile))
		return FALSE
	if(tile in outpost.lobby_alcove_turfs)
		return FALSE
	return TRUE

/// Whether `tile` or one of its cardinal neighbours already carries a layer-2 cable on `grid`
/datum/outpost_upgrade/proc/feeder_reaches_grid(turf/tile, datum/powernet/grid)
	if(tile_cable_on_net(tile, grid))
		return TRUE
	for(var/direction in GLOB.cardinals)
		if(tile_cable_on_net(get_step(tile, direction), grid))
			return TRUE
	return FALSE

/**
 * Lays protected cable from this room's door(s) along outpost floor to `grid`. TRUE if it joined.
 *
 * Breadth-first from the tile just outside each exterior door, over floor the feeder may cross
 * (feeder_tile_walkable()), stopping at the first tile that touches the grid (feeder_reaches_grid()).
 * Gives up past OUTPOST_ROOM_FEEDER_MAX tiles of path, or if no start tile is walkable yet: a room
 * floating in space with no path stays on its own cell until the owner builds one. No sleeps: this
 * never yields, so nothing else can see the room half-wired.
 */
/datum/outpost_upgrade/proc/lay_feeder(datum/powernet/grid)
	if(!grid || QDELETED(outpost))
		return FALSE
	var/list/distance = list()
	var/list/parent = list()
	var/list/queue = list()
	for(var/turf/door_tile as anything in exterior_door_turfs())
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(door_tile, direction)
			if(!beyond || distance[beyond] || contains_turf(beyond) || !feeder_tile_walkable(beyond))
				continue
			distance[beyond] = 1
			queue += beyond
	var/turf/found
	var/head = 1
	while(head <= length(queue))
		var/turf/current = queue[head]
		head++
		if(feeder_reaches_grid(current, grid))
			found = current
			break
		if(distance[current] >= OUTPOST_ROOM_FEEDER_MAX)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || distance[next] || !feeder_tile_walkable(next))
				continue
			distance[next] = distance[current] + 1
			parent[next] = current
			queue += next
	if(!found)
		return FALSE

	var/list/path = list(found)
	var/turf/walker = found
	while(parent[walker])
		walker = parent[walker]
		path += walker

	var/list/new_cables = list()
	for(var/turf/tile as anything in path)
		if(!tile_has_any_cable(tile))
			new_cables += new /obj/structure/cable/outpost(tile)
	if(length(new_cables))
		SSmachines.setup_template_powernets(new_cables)
	feeder_laid = TRUE
	return TRUE

/**
 * What is wrong with this room's area, APC and wiring, one line each; empty when fine
 * (outpost_room_contracts.dm). Never requires the room to be on the habitat's grid: an unfed room
 * off in space is still a working room on its own cell.
 */
/datum/outpost_upgrade/proc/power_problems()
	. = list()
	if(!installed)
		return
	var/list/inside = room_lookup()
	if(!length(inside))
		return

	var/own_area = installed_area && installed_area != outpost?.outpost_area
	if(own_area && outpost)
		for(var/upgrade_key in outpost.outpost_upgrades)
			var/datum/outpost_upgrade/other = outpost.outpost_upgrades[upgrade_key]
			// A prison extension joins the wing's area on purpose (outpost_prison_extension.dm)
			if(other != src && other?.installed && !other.snap_group && other.installed_area == installed_area)
				own_area = FALSE
				break
	if(!own_area)
		. += "the room has no area of its own"
	for(var/turf/tile as anything in inside)
		if(installed_area && tile.loc != installed_area)
			. += "[tile.x],[tile.y] is outside the room's area"

	var/list/found_apcs = list()
	for(var/turf/tile as anything in inside)
		for(var/obj/machinery/power/apc/candidate in tile)
			found_apcs += candidate

	var/obj/machinery/power/apc/outpost/apc
	if(length(found_apcs) != 1)
		. += "[length(found_apcs)] APCs in the room, not 1"
	else if(!istype(found_apcs[1], /obj/machinery/power/apc/outpost))
		var/obj/machinery/power/apc/wrong = found_apcs[1]
		. += "the [wrong.type] at [wrong.x],[wrong.y] is not an outpost APC"
	else
		apc = found_apcs[1]
		if(installed_area?.apc != apc)
			. += "the room's area APC is not the [apc.name]"
	if(apc)
		var/turf/wall = get_step(apc, apc.dir)
		if(!isclosedturf(wall))
			. += "the [apc.name] does not face a wall"
		var/datum/powernet/apc_net = apc.terminal?.powernet
		if(!apc_net)
			. += "the APC has no wire"

		var/list/door_tiles = list()
		for(var/turf/tile as anything in exterior_door_turfs())
			door_tiles[tile] = TRUE
			if(!tile_cable_on_net(tile, apc_net))
				. += "no wire under the door at [tile.x],[tile.y]"

		var/list/x_edges = list(footprint_bounds[1], footprint_bounds[3])
		var/list/y_edges = list(footprint_bounds[2], footprint_bounds[4])
		for(var/turf/tile as anything in inside)
			var/on_edge = (tile.x in x_edges) || (tile.y in y_edges)
			for(var/obj/structure/cable/wire in tile)
				if(on_edge && !door_tiles[tile])
					. += "a wire on the room's edge at [tile.x],[tile.y]"
				if(!istype(wire, /obj/structure/cable/outpost) || wire.powernet != apc_net)
					. += "a [wire.type] at [tile.x],[tile.y]"
