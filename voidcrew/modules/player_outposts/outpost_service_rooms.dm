/**
 * # Outpost service rooms
 *
 * Prefab rooms that sell a service to visitors (cloning bay, shop, medical lab, storage). They are
 * outpost upgrades (outpost_upgrades.dm) with three differences from the cargo dock:
 *
 * * The room gets its own area and its own APC, wired to its exterior door
 *   (outpost_room_power.dm). Room maps carry no light switch, and an outage in one room stays in
 *   that room until it joins the habitat's grid.
 * * Everything fixed in the room (machines and structures, never items or mobs) becomes
 *   outpost property. Walls and floors are indestructible turfs in the map itself; only the
 *   outpost's construction drone takes them apart (outpost_drone_may_strip()).
 * * Doors are service airlocks (outpost_service_doors.dm), keyed like any outpost door
 *   (outpost_door_access.dm): the entrance starts public, staff doors staff, and every door opens
 *   from the inside.
 *
 * Deleting the outpost deletes the rooms and everything in them. Nothing is refunded.
 */

/// Abstract: no id, so it never enters the catalog.
/datum/outpost_upgrade/service
	area_type = /area/voidcrew/player_outpost/service_room
	entrance_side = SOUTH
	/// The room's service airlocks, found at install
	var/list/datum/weakref/doors

/datum/outpost_upgrade/service/Destroy()
	doors = null
	return ..()

/datum/outpost_upgrade/service/on_installed(mob/user)
	protect_fixtures()
	adopt_doors()
	on_service_installed(user)

/// The placed room's turfs, or an empty list before placement
/datum/outpost_upgrade/service/proc/room_turfs()
	if(!footprint_bounds)
		return list()
	return block(footprint_bounds[1], footprint_bounds[2], footprint_bounds[5], footprint_bounds[3], footprint_bounds[4], footprint_bounds[5])

/// Makes every machine and structure in the room outpost property (protect_fixture())
/datum/outpost_upgrade/service/proc/protect_fixtures()
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/fixture in tile)
			protect_fixture(fixture)

/**
 * Makes one machine or structure outpost property. Rooms call it on everything they load; call it
 * again on anything a room spawns later. Anything that is not a machine or structure is ignored.
 *
 * * INDESTRUCTIBLE set after a machine's Initialize() misses its own explosion guard
 *   (_machinery.dm), so the contents flag is set here too, or an explosion could delete a part and
 *   the machine with it.
 * * A singularity or reality tear ignores it: /obj/singularity_act() deletes anything, whatever
 *   its resistance flags (see singularity_spares()).
 * * Structures are bolted down for good, so nobody drags the dressing out or parks it in a doorway.
 */
/datum/outpost_upgrade/service/proc/protect_fixture(obj/fixture)
	// The element refuses anything else, and a refused AddElement crashes
	if(QDELETED(fixture) || (!ismachinery(fixture) && !isstructure(fixture)))
		return
	// Outpost cable protects itself (outpost_room_power.dm): the element would block the owner's
	// own wirecutters too, and stop the drone stripping floors over it.
	if(istype(fixture, /obj/structure/cable))
		return
	fixture.AddElement(/datum/element/outpost_property)
	fixture.flags_1 |= PREVENT_CONTENTS_EXPLOSION_1
	ADD_TRAIT(fixture, TRAIT_SINGULARITY_IMMUNE, OUTPOST_SERVICE_TRAIT)
	if(istype(fixture, /obj/machinery/atmospherics/pipe/smart))
		seal_smart_pipe(fixture)
	if(!isstructure(fixture))
		return
	// Placing someone on a table puts them on its tile past any window on it: the shop counter
	// would let a visitor into the staff back room (abuse review B-13). Climbing still steps.
	if(istype(fixture, /obj/structure/table))
		qdel(fixture.GetComponent(/datum/component/table_smash))
	if(!fixture.anchored)
		fixture.set_anchored(TRUE)
	if(istype(fixture, /obj/structure/closet))
		var/obj/structure/closet/closet = fixture
		closet.anchorable = FALSE

/**
 * A smart pipe links in every direction (smart.dm), so a fitting a visitor wrenches down beside
 * it would join the room's loop: a vent dumps the loop's gas into the room, a connector takes a
 * canister of anything. Locking the pipe to the links it has now shuts every other side, since
 * connection_check() needs both ends to face each other. can_unwrench is off (outpost_property),
 * so the lock cannot be undone by re-laying the pipe.
 */
/datum/outpost_upgrade/service/proc/seal_smart_pipe(obj/machinery/atmospherics/pipe/smart/pipe)
	var/linked = NONE
	for(var/obj/machinery/atmospherics/node as anything in pipe.nodes)
		if(node)
			linked |= get_dir(pipe, node)
	if(!linked)
		log_mapping("OUTPOST SERVICE ROOM: [pipe] at [AREACOORD(pipe)] in the [name] has no links; left unsealed")
		return
	pipe.set_init_directions(linked)

/// Records the room's service airlocks and keys them to their defaults. A door out of the room whose map forgot its unrestricted-side helper gets one pointing inside.
/datum/outpost_upgrade/service/proc/adopt_doors()
	doors = list()
	var/list/room = room_turfs()
	var/list/inside = list()
	for(var/turf/tile as anything in room)
		inside[tile] = TRUE
	for(var/turf/tile as anything in room)
		for(var/obj/machinery/door/airlock/outpost/service/door in tile)
			doors += WEAKREF(door)
			// A door button whose id matched would open, bolt and shock it (doorcontrol.dm)
			door.id_tag = null
			if(door.unres_sides)
				continue
			for(var/direction in GLOB.cardinals)
				if(inside[get_step(tile, direction)])
					continue
				// This door's own inside: a side or back door does not face the way the entrance does
				var/inward = turn(direction, 180)
				door.unres_sides = inward
				door.update_appearance()
				log_mapping("OUTPOST SERVICE ROOM: [door] at [AREACOORD(door)] in the [name] had no unrestricted side; set to [dir2text(inward)]")
				break
	apply_door_defaults()

/datum/outpost_upgrade/service/proc/is_inside(atom/thing)
	return contains_turf(get_turf(thing))

/// The turfs just outside the room's exterior service doors, one per door and side off the room
/datum/outpost_upgrade/service/proc/exit_turfs()
	var/list/exits = list()
	for(var/list/route as anything in exit_routes())
		exits += route[2]
	return exits

/**
 * One list(inside, outside) per exterior door and side off the room: the room tile in front of the
 * door and the tile beyond it. `inside` is null when the door has no room tile behind it.
 */
/datum/outpost_upgrade/service/proc/exit_routes()
	var/list/routes = list()
	for(var/datum/weakref/door_ref as anything in doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		var/turf/door_turf = get_turf(door)
		if(!door_turf || !contains_turf(door_turf))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(door_turf, direction)
			if(!beyond || contains_turf(beyond))
				continue
			var/turf/inside = get_step(door_turf, turn(direction, 180))
			routes += list(list(contains_turf(inside) ? inside : null, beyond))
	return routes

/**
 * One list(inside, outside) per opening the owner has made in the room's own walls: an open tile
 * of the room's area on the edge of its footprint, and the tile beyond it. Doors are exit_routes().
 */
/datum/outpost_upgrade/service/proc/wall_gap_routes()
	var/list/routes = list()
	if(!footprint_bounds || !installed_area)
		return routes
	for(var/turf/edge as anything in room_turfs())
		if(edge.loc != installed_area || isclosedturf(edge))
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(edge, direction)
			if(beyond && !contains_turf(beyond))
				routes += list(list(edge, beyond))
	return routes

/**
 * Why nobody could walk out of the room right now, or null when some exterior door or opened wall
 * lets them. "Exit blocked": every way out is walled off, inside or out, by a wall or something
 * fixed that nobody can move. Clutter a player can wrench or break away never counts. The cloning
 * chooser and the teleporter's destination list show it as a warning; the teleporter also refuses
 * arrivals on it.
 */
/datum/outpost_upgrade/service/proc/exit_denial()
	for(var/list/route as anything in exit_routes() + wall_gap_routes())
		var/turf/inside = route[1]
		var/turf/exit = route[2]
		if(outpost_exit_blocked(exit) || (inside && outpost_exit_blocked(inside)))
			continue
		return null
	return "Exit blocked"

/**
 * Placement refusal for this room at `footprint` (footprint_at()), or null. A closed turf just
 * outside any exterior service door would seal the room for good, so it refuses. Space and open
 * ground pass: a corridor can be built later.
 */
/datum/outpost_upgrade/service/placement_denial(list/footprint, rotation)
	var/datum/map_template/template = get_template()
	var/turf/bottom_left = footprint?["bottom_left"]
	if(!template || !bottom_left)
		return null
	var/list/room = list()
	for(var/turf/tile as anything in footprint["turfs"])
		room[tile] = TRUE
	for(var/list/offset as anything in template_door_offsets())
		var/turf/door_turf = template.rotated_template_turf(bottom_left, offset[1], offset[2], rotation)
		if(!door_turf)
			continue
		for(var/direction in GLOB.cardinals)
			var/turf/beyond = get_step(door_turf, direction)
			if(beyond && !room[beyond] && isclosedturf(beyond))
				return "Entrance blocked."
	return null

/**
 * Zero-based (column, row) offsets of the service airlocks in this room's map as drawn, read from
 * the map file once per map and cached. Room maps are small, so the one parse is cheap.
 */
/datum/outpost_upgrade/service/proc/template_door_offsets()
	var/static/list/offsets_by_map = list()
	var/datum/map_template/template = get_template()
	var/path = template?.mappath
	if(!path)
		return list()
	var/list/cached = offsets_by_map[path]
	if(cached)
		return cached
	cached = list()
	var/datum/parsed_map/parsed = new(file(path))
	var/list/door_keys = list()
	for(var/key in parsed.grid_models)
		if(findtext(parsed.grid_models[key], "/obj/machinery/door/airlock/outpost/service"))
			door_keys[key] = TRUE
	var/key_len = parsed.key_len
	if(length(door_keys) && key_len)
		for(var/datum/grid_set/grid as anything in parsed.gridSets)
			var/list/lines = grid.gridLines
			for(var/line_index in 1 to length(lines))
				var/line = lines[line_index]
				var/row = grid.ycrd - line_index // ycrd is the top line's y; rows are zero-based
				for(var/position in 1 to length(line) step key_len)
					if(!door_keys[copytext(line, position, position + key_len)])
						continue
					var/column = grid.xcrd - 1 + (position - 1) / key_len
					cached += list(list(column, row))
	qdel(parsed)
	offsets_by_map[path] = cached
	return cached

// ===== ROOM HOOKS (room packages override these) =====

/// Called once the room is placed, protected and its doors adopted. Wire the room here.
/datum/outpost_upgrade/service/proc/on_service_installed(mob/user)
	return

/// This room's settings for the management console's Rooms tab, or null
/datum/outpost_upgrade/service/proc/service_ui_data(mob/user)
	return null

/// A Rooms tab action for this room. TRUE when handled.
/datum/outpost_upgrade/service/proc/service_ui_act(mob/user, action, list/params)
	return FALSE

/// Rows for the admin Outpost Manipulator, or null
/datum/outpost_upgrade/service/proc/admin_ui_data()
	return null

/// An Outpost Manipulator action for this room. TRUE when handled.
/datum/outpost_upgrade/service/proc/admin_ui_act(mob/user, action, list/params)
	return FALSE

/// TRUE lets this visitor through the room's entrance whatever it is keyed to: they paid for what is inside
/datum/outpost_upgrade/service/proc/admits_visitor_extra(mob/user)
	return FALSE

/// The outpost was abandoned: put per-room settings back to their defaults
/datum/outpost_upgrade/service/proc/on_outpost_abandoned()
	return

// ===== EXITS =====

/// A closed turf, or something fixed in the way (outpost_exit_fixed_blocker())
/proc/outpost_exit_blocked(turf/exit)
	if(!exit || isclosedturf(exit))
		return TRUE
	for(var/obj/thing in exit)
		if(outpost_exit_fixed_blocker(thing))
			return TRUE
	return FALSE

/**
 * Something dense and bolted down that a person cannot open, climb, or take away: outpost property
 * or anything indestructible. A closet or frame a visitor wrenched down can be unwrenched or broken,
 * so it never closes a room or a pad (abuse review B-11). Doors open, so they never block.
 */
/proc/outpost_exit_fixed_blocker(obj/thing)
	if(!thing.density || !thing.anchored || istype(thing, /obj/machinery/door))
		return FALSE
	if((thing.flags_1 & ON_BORDER_1) || HAS_TRAIT(thing, TRAIT_CLIMBABLE))
		return FALSE
	return (thing.resistance_flags & INDESTRUCTIBLE) || HAS_TRAIT(thing, TRAIT_OUTPOST_PROPERTY)

// ===== SINGULARITY IMMUNITY =====

/**
 * Whether a singularity or reality tear must leave `thing` alone: neither eat it nor pull it.
 * Called from the singularity's consume and pull paths (code/, which cannot see Voidcrew
 * defines). Service room fixtures get the trait from protect_fixture().
 */
/proc/singularity_spares(atom/thing)
	return HAS_TRAIT(thing, TRAIT_SINGULARITY_IMMUNE)

/**
 * Whether `builder` may build or bolt something down on `target`. Inside an installed service room
 * only members may: a visitor's girder, wall or pipe in a room is grief against the owner and every
 * other visitor (abuse review B-12). Everywhere else this says yes.
 */
/proc/outpost_service_build_allowed(mob/builder, atom/target)
	if(!is_outpost_service_tile(target))
		return TRUE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(get_turf(target))
	return !!home?.is_outpost_member(builder)

/obj/item/stack/building_checks(mob/builder, datum/stack_recipe/recipe, multiplier)
	if(!outpost_service_build_allowed(builder, get_turf(builder)))
		builder.balloon_alert(builder, "outpost property!")
		return FALSE
	return ..()

/obj/structure/disposalconstruct/wrench_act(mob/living/user, obj/item/tool)
	if(!anchored && !outpost_service_build_allowed(user, src))
		balloon_alert(user, "outpost property!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/pipe/wrench_act(mob/living/user, obj/item/tool)
	if(!outpost_service_build_allowed(user, src))
		balloon_alert(user, "outpost property!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/// Visitors cannot tap a room's power run by laying their own cable on a stripped or plating tile (abuse review)
/obj/item/stack/cable_coil/place_turf(turf/T, mob/user, dirnew)
	if(!outpost_service_build_allowed(user, T))
		balloon_alert(user, "outpost property!")
		return
	return ..()

/// Whether `thing` stands inside an installed service room of a player outpost
/proc/is_outpost_service_tile(atom/thing)
	var/turf/location = get_turf(thing)
	if(!location)
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(location)
	var/datum/outpost_upgrade/service/room = home?.upgrade_at_turf(location)
	return istype(room) && room.installed
