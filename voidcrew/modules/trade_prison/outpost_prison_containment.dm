/**
 * # Prison wing containment
 *
 * What keeps prisoners in and who may deal with them: where a prisoner can stand, walk and reach,
 * the cell block, whether a prisoner is confined to their cell, who counts as a member of the
 * wing, and what stops a prisoner being teleported, polymorphed or brought back from the dead.
 * The wing's doors and bolt buttons are in outpost_prison_doors.dm.
 *
 * The cell block is everything prisoners can reach from the cells without passing a staff door, a
 * serving hatch or a window, plus the walls, windows and doors along its edge. A hole knocked in
 * one of those walls is still inside it; the office past the hole is not. The open ground that was
 * outside the cell block when the wing was placed (the office side) never joins it, however the
 * wing is rebuilt. A prisoner outside the cell block on their own feet has escaped
 * (outpost_prison_riot.dm).
 *
 * The wing may be rebuilt (an admin, a test). An airlock built where a staff door or a cell door stood becomes
 * one again, and every PRISON_LAYOUT_CHECK_SECONDS the wing's walls and doors are compared with
 * the last look; when they changed, the cells and the cell block are worked out again.
 */

/// How often every prisoner's reach is refreshed, in seconds
#define PRISON_REACH_REFRESH_SECONDS 5
/// How often the wing's walls and doors are checked for rebuilding, in seconds
#define PRISON_LAYOUT_CHECK_SECONDS 30

/datum/outpost_prison
	/// The cell block: turf = TRUE, for every tile inside it and the walls, windows and doors along its edge
	var/list/cell_block = list()
	/// Open ground of the wing outside the cell block when it was placed (turf = TRUE): the office side
	var/list/staff_ground
	/// Where the wing's staff doors stood (turf = TRUE): an airlock built on one becomes a staff door
	var/list/staff_door_turfs = list()
	/// Door and serving hatch tiles watched for rebuilt airlocks and window doors (turf = TRUE)
	var/list/door_watch_turfs = list()
	/// md5 of the wing's walls and airlocks at the last look (layout_signature())
	var/layout_hash
	/// Seconds since every prisoner's reach was refreshed, and since the layout was checked
	var/containment_clock = 0
	var/layout_clock = 0

/**
 * Advances containment by `seconds`: every prisoner's reach is refreshed every
 * PRISON_REACH_REFRESH_SECONDS, and the layout is checked every PRISON_LAYOUT_CHECK_SECONDS.
 */
/datum/outpost_prison/proc/containment_tick(seconds)
	layout_clock += seconds
	if(layout_clock >= PRISON_LAYOUT_CHECK_SECONDS)
		layout_clock = 0
		if(layout_signature() != layout_hash)
			containment_clock = 0
			refresh_layout()
			return
	containment_clock += seconds
	if(containment_clock < PRISON_REACH_REFRESH_SECONDS)
		return
	containment_clock = 0
	refresh_reach()

// ===== STAFF AND INMATES =====

/**
 * Whether `person` is one of the wing's staff: its guards, the outpost's own officers, and an admin
 * ghost. Never a player: nobody owns a wing, and a player in one is an inmate or a visitor.
 */
/datum/outpost_prison/proc/is_staff(mob/person)
	if(!ismob(person) || is_outpost_prisoner(person))
		return FALSE
	if(isAdminGhostAI(person))
		return TRUE
	if(person.mind || person.client)
		return FALSE
	var/mob/living/carbon/human/npc/outpost_prison_guard/guard = person
	if(istype(guard))
		return guard.prison == src
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/lockup_warden/warden = person
	if(istype(warden))
		return !QDELETED(outpost) && warden.outpost == outpost
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = person
	return istype(officer) && !QDELETED(outpost) && officer.police?.outpost == outpost

/// Whether anyone is held in this wing right now (a live prisoner on the roster, or a player inmate)
/datum/outpost_prison/proc/holds_anyone()
	if(has_inmates())
		return TRUE
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
		if(!QDELETED(prisoner) && prisoner.stat != DEAD && prisoner.phase != PRISONER_LEAVING)
			return TRUE
	return FALSE

/**
 * Whether `accessor` may open a staff door or the office side of a hatch: the wing's staff. A
 * cleanbot nobody is driving may always go through, or one in the office would bump the door
 * forever trying to reach the yard's mess.
 */
/proc/may_use_outpost_prison_staff_door(atom/door, mob/accessor)
	if(!ismob(accessor) || is_outpost_prisoner(accessor))
		return FALSE
	if(isAdminGhostAI(accessor))
		return TRUE
	if(istype(accessor, /mob/living/basic/bot/cleanbot) && isnull(accessor.mind) && isnull(accessor.client))
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(door)
	if(prison)
		return prison.is_staff(accessor)
	return is_ai_outpost_prison_guard(accessor)

/**
 * Whether a prisoner is being taken through a staff door: down or cuffed (can_be_dragged()) and
 * pulled by one of the wing's staff, so nobody else can drag one out of the cell block.
 */
/proc/outpost_prisoner_escorted(atom/door, mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	if(!istype(prisoner) || !prisoner.can_be_dragged())
		return FALSE
	var/mob/living/puller = prisoner.pulledby
	if(!istype(puller) || !may_use_outpost_prison_staff_door(door, puller))
		return FALSE
	if(isAdminGhostAI(puller))
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(door) || prisoner.prison
	return !!prison?.is_staff(puller)

// ===== THE PRISON'S OWN MOBS =====

/**
 * Whether a mob belongs to an outpost prison: its prisoners and guards. The prison deletes them
 * with the outpost, so they never block deleting it.
 */
/proc/is_outpost_prison_mob(atom/thing)
	// Guards count too, so a live
	// one holds the outpost like a prisoner does.
	return is_outpost_prisoner(thing) || is_outpost_prison_guard(thing)

// ===== REACH =====

/**
 * Whether a prisoner could stand on this tile. Cell doors open for them unless bolted, welded or
 * unpowered; staff doors never do unless breached.
 */
/datum/outpost_prison/proc/prisoner_can_stand(turf/tile)
	if(isclosedturf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			var/obj/machinery/door/airlock/security/prison_staff/staff_door = thing
			if(!staff_door.rioter_broken && !(staff_door.lockup_breached() && !staff_door.density))
				return FALSE
			continue
		if(istype(thing, /obj/machinery/door/airlock))
			var/obj/machinery/door/airlock/airlock = thing
			if(airlock.density && (airlock.locked || airlock.welded || !airlock.hasPower()))
				return FALSE
			continue
		if(istype(thing, /obj/machinery/door) || ismob(thing))
			continue
		if(thing.density)
			return FALSE
	return TRUE

/// Refreshes where every prisoner can walk and reach. The prisoners share one look at each tile.
/datum/outpost_prison/proc/refresh_reach()
	var/list/standable = list()
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prisoners)
		refresh_prisoner_reach(prisoner, standable)

/**
 * Floods out from a prisoner to the ground they can walk on, then adds each tile beside it
 * (tables, the serving hatch). Items on those tiles are the ones they can go and pick up; food
 * seen through the office windows is not. `standable` (turf = whether a prisoner can stand there)
 * is shared by every prisoner in one refresh, so each tile is looked at once.
 */
/datum/outpost_prison/proc/refresh_prisoner_reach(mob/living/carbon/human/npc/outpost_prisoner/prisoner, list/standable)
	var/list/walked = list()
	var/list/reach = list()
	var/turf/start = get_turf(prisoner)
	if(start?.loc == wing)
		var/list/queue = list(start)
		walked[start] = TRUE
		var/index = 1
		while(index <= length(queue))
			var/turf/current = queue[index++]
			for(var/direction in GLOB.cardinals)
				var/turf/next = get_step(current, direction)
				if(!next || walked[next] || next.loc != wing)
					continue
				var/can_stand = standable ? standable[next] : null
				if(isnull(can_stand))
					can_stand = prisoner_can_stand(next)
					if(standable)
						standable[next] = can_stand
				if(!can_stand)
					continue
				walked[next] = TRUE
				queue += next
		for(var/turf/standing as anything in walked)
			reach[standing] = TRUE
			for(var/direction in GLOB.cardinals)
				var/turf/beside = get_step(standing, direction)
				if(beside?.loc == wing)
					reach[beside] = TRUE
	prisoner.walkable = walked
	prisoner.reachable = reach

// ===== THE CELL BLOCK =====

/**
 * Floods out from the cells, and from what was the cell block before, across everything prisoners
 * could walk, whatever the bolts. Walls, windows, staff doors and serving hatches are its edge:
 * part of it, but not flooded through. It never floods into the office side (staff_ground), so a
 * hole into the office leaves the office outside.
 */
/datum/outpost_prison/proc/refresh_cell_block()
	var/list/found = list()
	var/list/queue = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		for(var/turf/tile as anything in cell.turfs)
			if(!found[tile])
				found[tile] = TRUE
				queue += tile
	// What was inside stays inside, even if new walls cut it off from the cells.
	for(var/turf/tile as anything in cell_block)
		if(!found[tile] && tile.loc == wing && !isclosedturf(tile) && cell_block_passable(tile))
			found[tile] = TRUE
			queue += tile
	var/index = 1
	while(index <= length(queue))
		var/turf/current = queue[index++]
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || found[next] || next.loc != wing || staff_ground?[next])
				continue
			found[next] = TRUE
			if(!isclosedturf(next) && cell_block_passable(next))
				queue += next
	cell_block = found
	if(isnull(staff_ground) && length(found))
		staff_ground = list()
		for(var/turf/tile as anything in wing_turfs())
			if(!found[tile] && !isclosedturf(tile))
				staff_ground[tile] = TRUE
	record_layout()
	// Masks and tanks for a breach (outpost_prison_breach.dm)
	ensure_emergency_lockers()

/**
 * Whether the cell block flood carries on through a tile. Only the wing's structure stops it:
 * staff doors, serving hatches, windows and grilles. Furniture, crates and machines do not, so
 * moving them about never changes what counts as inside.
 */
/datum/outpost_prison/proc/cell_block_passable(turf/tile)
	for(var/obj/thing in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff) || istype(thing, /obj/structure/table/reinforced/prison_hatch) || istype(thing, /obj/structure/grille))
			return FALSE
		if(istype(thing, /obj/structure/window))
			var/obj/structure/window/pane = thing
			if(pane.fulltile)
				return FALSE
	return TRUE

/// Whether something is in the cell block. A wing without cells has no cell block: then anywhere in the wing counts.
/datum/outpost_prison/proc/in_cell_block(atom/thing)
	var/turf/tile = get_turf(thing)
	if(!tile)
		return FALSE
	if(!length(cell_block))
		return !!wing && tile.loc == wing
	return !!cell_block[tile]

/// Whether a tile on the cell block's edge has the outside of the cell block beyond it
/datum/outpost_prison/proc/leads_out_of_cell_block(turf/tile)
	for(var/direction in GLOB.cardinals)
		var/turf/beside = get_step(tile, direction)
		if(beside && beside.loc == wing && !isclosedturf(beside) && !cell_block[beside])
			return TRUE
	return FALSE

/// The nearest free tile of the wing outside the cell block, for an admin breakout
/datum/outpost_prison/proc/outside_spot_near(atom/from)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/open/tile in wing_turfs())
		if(cell_block[tile] || tile.is_blocked_turf(TRUE) || (locate(/obj/machinery/door) in tile))
			continue
		var/distance = get_dist(from, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

// ===== REBUILDING =====

/// A hash of where the wing's walls and airlocks are, to notice them being taken down or rebuilt
/datum/outpost_prison/proc/layout_signature()
	var/list/parts = list()
	for(var/turf/tile as anything in wing_turfs())
		if(isclosedturf(tile))
			parts += "[tile.x],[tile.y]#"
			continue
		for(var/obj/machinery/door/airlock/door in tile)
			parts += "[tile.x],[tile.y]:[door.type]"
	return md5(jointext(parts, ";"))

/// Notes where the doors are, watches their tiles for rebuilt airlocks, and remembers the layout
/datum/outpost_prison/proc/record_layout()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		watch_door_turf(cell.door_turf)
	for(var/turf/tile as anything in wing_turfs())
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = locate() in tile
		if(staff_door)
			staff_door_turfs[tile] = staff_door.type
			watch_door_turf(tile)
	// A window door fitted to a serving hatch (outpost_prison_breakout.dm)
	watch_hatch_turfs()
	layout_hash = layout_signature()

/datum/outpost_prison/proc/watch_door_turf(turf/tile)
	if(!tile || door_watch_turfs[tile])
		return
	door_watch_turfs[tile] = TRUE
	RegisterSignal(tile, COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON, PROC_REF(on_door_turf_initialized))

/// The wing's walls or doors changed: the cells and the cell block are worked out again
/datum/outpost_prison/proc/refresh_layout()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		var/obj/machinery/door/airlock/door = cell.door()
		if(!door)
			continue
		// A cell that can no longer be told apart (merged with the next, or opened up) keeps its old tiles.
		var/list/inside = cell_inside(door)
		if(inside)
			cell.set_inside(inside)
	refresh_cell_block()
	office_cache = null
	front_room_cache = null
	refresh_reach()

/**
 * Something was built on a door tile. A plain airlock becomes the door that stood there, and a
 * window door on a serving hatch the hatch's own (restore_hatch_windoor()), once its builder is
 * done with it.
 */
/datum/outpost_prison/proc/on_door_turf_initialized(turf/source, atom/created, mapload)
	SIGNAL_HANDLER
	if(istype(created, /obj/machinery/door/window))
		if(!is_outpost_prison_windoor(created))
			addtimer(CALLBACK(src, PROC_REF(restore_hatch_windoor), created), 1)
		return
	if(!istype(created, /obj/machinery/door/airlock) || is_outpost_prison_airlock(created))
		return
	addtimer(CALLBACK(src, PROC_REF(restore_prison_door), created), 1)

/proc/is_outpost_prison_airlock(atom/thing)
	return istype(thing, /obj/machinery/door/airlock/security/prison_staff) || istype(thing, /obj/machinery/door/airlock/security/glass/outpost_prison_cell)

/// The cell whose door stood on `tile`, if any
/datum/outpost_prison/proc/cell_with_door_turf(turf/tile)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.door_turf == tile)
			return cell
	return null

/**
 * Swaps an airlock built on a door tile for the wing's own door: a cell door with its number, or
 * a staff door (glass if the new one is glass). The new door keeps the builder's electronics.
 */
/datum/outpost_prison/proc/restore_prison_door(obj/machinery/door/airlock/built)
	if(QDELETED(built) || QDELETED(src))
		return null
	var/turf/tile = built.loc
	if(!isturf(tile) || !door_watch_turfs[tile])
		return null
	var/datum/outpost_prison_cell/cell = cell_with_door_turf(tile)
	if(!cell && !staff_door_turfs[tile])
		return null
	var/obj/machinery/door/airlock/restored
	if(cell)
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = new(tile)
		cell_door.cell_number = cell.number
		cell_door.name = "Cell [cell.number]"
		restored = cell_door
	else
		var/saved_type = staff_door_turfs[tile]
		var/staff_type = ispath(saved_type, /obj/machinery/door/airlock/security/prison_staff/processing) ? saved_type : (built.glass ? /obj/machinery/door/airlock/security/prison_staff/glass : /obj/machinery/door/airlock/security/prison_staff)
		restored = new staff_type(tile)
	restored.setDir(built.dir)
	if(built.electronics)
		var/obj/item/electronics/airlock/parts = built.electronics
		built.electronics = null
		restored.electronics = parts
		parts.forceMove(restored)
	qdel(built)
	if(cell)
		cell.door_ref = WEAKREF(restored)
	add_log(cell ? "A new door was fitted to cell [cell.number]." : "A new staff door was fitted.")
	refresh_reach()
	return restored

/// Takes new tiles for the inside of the cell, and a bed from them if its own bed is gone
/datum/outpost_prison_cell/proc/set_inside(list/inside)
	turfs = inside
	turf_set = list()
	for(var/turf/tile as anything in inside)
		turf_set[tile] = TRUE
	if(bed())
		return
	bed_ref = null
	for(var/turf/tile as anything in inside)
		var/obj/structure/bed/bed = locate() in tile
		if(bed)
			bed_ref = WEAKREF(bed)
			return

// ===== THE PRISONER =====

/// Whether `body` is a living lockup inmate, prisoner or guard that cannot be folded into pocket storage or beamed onto a ship pad
/proc/outpost_lockup_body_bound(mob/living/body)
	if(!isliving(body) || QDELETED(body) || body.stat == DEAD)
		return FALSE
	if(istype(body, /mob/living/carbon/human/npc/outpost_prisoner))
		var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = body
		return !!prisoner.prison
	if(istype(body, /mob/living/carbon/human/npc/outpost_prison_guard))
		var/mob/living/carbon/human/npc/outpost_prison_guard/guard = body
		return !!guard.prison
	for(var/datum/outpost_prison/prison as anything in GLOB.outpost_prisons)
		if(prison?.is_inmate(body))
			return TRUE
	return FALSE

/// Whether `thing` holds a living lockup inmate, prisoner or guard anywhere inside it
/proc/outpost_lockup_holds_bound(atom/movable/thing)
	if(QDELETED(thing))
		return FALSE
	for(var/mob/living/passenger in thing.get_all_contents())
		if(passenger != thing && outpost_lockup_body_bound(passenger))
			return TRUE
	return FALSE

/mob/living/carbon/human/npc/outpost_prisoner
	/// Weakref to an outermost movable container watched while shut inside one, so container teleports fail too
	var/datum/weakref/watched_container_ref

/**
 * Hooks up what keeps a prisoner contained; called from Initialize(). Teleports fail, forced ones
 * included (drop pods, quantum pads, and containers holding them); polymorph and type changes fail.
 * A dead prisoner can be brought back like anyone (on_revived()). TRAIT_NO_TRANSFORM would stop
 * polymorph too, but it also stops their AI moving them.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/setup_containment()
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_MOVABLE_MOVED, PROC_REF(on_containment_moved))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revived))
	sync_container_watch()

/mob/living/carbon/human/npc/outpost_prisoner/proc/clear_containment()
	var/atom/movable/watched = watched_container_ref?.resolve()
	if(watched)
		UnregisterSignal(watched, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_TELEPORTING))
	watched_container_ref = null

/mob/living/carbon/human/npc/outpost_prisoner/proc/sync_container_watch()
	var/atom/movable/prev = watched_container_ref?.resolve()
	var/atom/movable/outermost
	if(!QDELETED(src) && !isturf(loc))
		var/atom/cursor = loc
		while(ismovable(cursor) && !isturf(cursor))
			outermost = cursor
			cursor = cursor.loc
	if(prev == outermost)
		return
	if(prev)
		UnregisterSignal(prev, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_TELEPORTING))
	watched_container_ref = outermost ? WEAKREF(outermost) : null
	if(outermost)
		RegisterSignal(outermost, COMSIG_MOVABLE_MOVED, PROC_REF(on_container_moved), override = TRUE)
		RegisterSignal(outermost, COMSIG_MOVABLE_TELEPORTING, PROC_REF(on_container_teleport), override = TRUE)

/mob/living/carbon/human/npc/outpost_prisoner/proc/on_containment_moved(datum/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	sync_container_watch()

/mob/living/carbon/human/npc/outpost_prisoner/proc/on_container_moved(atom/movable/container, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	sync_container_watch()

/mob/living/carbon/human/npc/outpost_prisoner/proc/on_container_teleport(atom/movable/container, atom/destination, channel)
	SIGNAL_HANDLER
	if(QDELETED(src) || QDELETED(container) || stat == DEAD || !(src in container.get_all_contents()))
		return NONE
	if(isturf(container.loc))
		container.visible_message(span_notice("[container] flickers for a moment, but stays where [container.p_they()] [container.p_are()]."))
	return TRUE

/mob/living/carbon/human/npc/outpost_prisoner/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(isturf(loc))
		visible_message(span_notice("[src] flickers for a moment, but stays where [p_they()] [p_are()]."))
	return TRUE

/mob/living/carbon/human/npc/outpost_prisoner/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	visible_message(span_notice("[src] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/mob/living/carbon/human/npc/outpost_prisoner/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/**
 * Brought back (a defibrillator, strange reagent: tg's revival works on them as on anyone). Still on the
 * roster, they are the same inmate again: the death stays on the books (its record closed, the yard's
 * blame not taken back) and the log says so. Revived after their body left the roster, they are nobody's
 * prisoner and slip away once nobody is looking (leave()).
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/on_revived(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	if(prison && phase == PRISONER_PRESENT)
		if(died_at)
			prison.add_log("[real_name] was revived. The corrections service has already logged the death.")
		died_at = 0
		return
	if(phase != PRISONER_LEAVING)
		INVOKE_ASYNC(src, PROC_REF(leave))

/**
 * Whether they are shut in their cell: standing in a cell with its door bolted shut, or with
 * nowhere to walk but the cell and its doorway (a welded, walled-in or unpowered door).
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/is_confined()
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(src))
	if(!holding)
		return FALSE
	var/obj/machinery/door/airlock/door = holding.door()
	if(door?.locked && door.density)
		return TRUE
	if(isnull(walkable))
		return FALSE
	for(var/turf/tile as anything in walkable)
		if(!holding.turf_set[tile] && tile != holding.door_turf)
			return FALSE
	return TRUE

#undef PRISON_REACH_REFRESH_SECONDS
#undef PRISON_LAYOUT_CHECK_SECONDS
