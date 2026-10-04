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
 * Owners may rebuild the wing. An airlock built where a staff door or a cell door stood becomes
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
	/// Whether people who are not members of the wing may use its staff doors and the office side of the hatches
	var/visitors_allowed = FALSE

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

// ===== MEMBERS AND VISITORS =====

/**
 * Whether `user` is a member of the wing: the outpost's owner, stewards, treasurers, residents and
 * authorised builders, and the owner's current shipmates. Prisoners never are.
 */
/datum/outpost_prison/proc/is_member(mob/user)
	if(!ismob(user) || is_outpost_prisoner(user) || QDELETED(outpost))
		return FALSE
	if(outpost.can_manage(user) || outpost.can_spend(user) || outpost.is_resident(user) || outpost.can_build(user))
		return TRUE
	return is_owner_shipmate(user)

/// Whether `user` crews the ship the outpost's owner crews now
/datum/outpost_prison/proc/is_owner_shipmate(mob/user)
	if(!user?.mind || !outpost?.founder_ckey)
		return FALSE
	var/datum/mind/owner_mind = outpost.founder_mind?.resolve()
	if(!owner_mind)
		return FALSE
	for(var/datum/team/voidcrew/team in owner_mind.ship_teams)
		if(!QDELETED(team.ship) && (user.mind in team.members))
			return TRUE
	return FALSE

/// Lets visitors use the staff doors and the office side of the hatches, or stops them. Returns whether it changed.
/datum/outpost_prison/proc/set_visitors_allowed(on, mob/user)
	on = !!on
	if(visitors_allowed == on)
		return FALSE
	visitors_allowed = on
	add_log(on ? "The staff doors were opened to visitors." : "The staff doors were closed to visitors.")
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] [on ? "let visitors into" : "closed visitors out of"] the prison wing at '[outpost?.name]'")
	return TRUE

/**
 * Whether `accessor` may open a staff door or the office side of a hatch: members, or anyone but
 * prisoners while visitors are allowed. A cleanbot nobody is driving may always go through, or one
 * built in the office would bump the door forever trying to reach the yard's mess.
 */
/proc/may_use_outpost_prison_staff_door(atom/door, mob/accessor)
	if(is_outpost_prisoner(accessor))
		return FALSE
	// The wing's own guards (outpost_prison_guards.dm)
	if(is_outpost_prison_guard(accessor))
		return TRUE
	if(isAdminGhostAI(accessor))
		return TRUE
	if(istype(accessor, /mob/living/basic/bot/cleanbot) && isnull(accessor.mind))
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(door)
	return !prison || prison.visitors_allowed || prison.is_member(accessor)

/**
 * Whether a prisoner is being taken through a staff door: down or cuffed (can_be_dragged()) and
 * pulled by a member of the wing who may use the door. Visitors let in may use the door, but
 * never take a prisoner with them, so nobody but the wing's own people can drag one off the outpost.
 */
/proc/outpost_prisoner_escorted(atom/door, mob/living/basic/outpost_prisoner/prisoner)
	if(!istype(prisoner) || !prisoner.can_be_dragged())
		return FALSE
	var/mob/living/puller = prisoner.pulledby
	if(!istype(puller) || !may_use_outpost_prison_staff_door(door, puller))
		return FALSE
	if(isAdminGhostAI(puller))
		return TRUE
	var/datum/outpost_prison/prison = get_outpost_prison(door) || prisoner.prison
	return !!prison?.is_member(puller)

// ===== THE PRISON'S OWN MOBS =====

/**
 * Whether a mob belongs to an outpost prison: its prisoners and guards, and later the experiments'
 * creatures and researcher. The prison deletes them with the outpost, so they never block deleting it.
 */
/proc/is_outpost_prison_mob(atom/thing)
	// Guards, experiment creatures (the ledger's trait) and the changeling's forms count too, so a live
	// one holds the outpost like a prisoner does.
	return is_outpost_prisoner(thing) || is_outpost_prison_guard(thing) || is_outpost_experiment_mob(thing) \
		|| istype(thing, /mob/living/basic/outpost_experiment) || istype(thing, /mob/living/basic/headslug/beakless/outpost)

// ===== REACH =====

/**
 * Whether a prisoner could stand on this tile. Cell doors open for them unless bolted, welded or
 * unpowered; staff doors never do.
 */
/datum/outpost_prison/proc/prisoner_can_stand(turf/tile)
	if(isclosedturf(tile))
		return FALSE
	for(var/atom/movable/thing as anything in tile)
		if(istype(thing, /obj/machinery/door/airlock/security/prison_staff))
			return FALSE
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
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		refresh_prisoner_reach(prisoner, standable)

/**
 * Floods out from a prisoner to the ground they can walk on, then adds each tile beside it
 * (tables, the serving hatch). Items on those tiles are the ones they can go and pick up; food
 * seen through the office windows is not. `standable` (turf = whether a prisoner can stand there)
 * is shared by every prisoner in one refresh, so each tile is looked at once.
 */
/datum/outpost_prison/proc/refresh_prisoner_reach(mob/living/basic/outpost_prisoner/prisoner, list/standable)
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
		if(locate(/obj/machinery/door/airlock/security/prison_staff) in tile)
			staff_door_turfs[tile] = TRUE
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
		var/staff_type = built.glass ? /obj/machinery/door/airlock/security/prison_staff/glass : /obj/machinery/door/airlock/security/prison_staff
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

/**
 * Hooks up what keeps a prisoner contained; called from Initialize(). Teleports fail, forced ones
 * included (drop pods, quantum pads); polymorph and type changes fail; and a dead prisoner stays
 * dead: anything that tries to bring them back gets the body collected at once instead.
 * TRAIT_NO_TRANSFORM would stop polymorph too, but it also stops their AI moving them.
 */
/mob/living/basic/outpost_prisoner/proc/setup_containment()
	RegisterSignal(src, COMSIG_MOVABLE_TELEPORTING, PROC_REF(refuse_teleport))
	RegisterSignal(src, COMSIG_LIVING_PRE_WABBAJACKED, PROC_REF(refuse_polymorph))
	RegisterSignal(src, COMSIG_PRE_MOB_CHANGED_TYPE, PROC_REF(refuse_type_change))
	RegisterSignal(src, COMSIG_LIVING_REVIVE, PROC_REF(on_revive_attempt))

/mob/living/basic/outpost_prisoner/proc/refuse_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	if(isturf(loc))
		visible_message(span_notice("[src] flickers for a moment, but stays where [p_they()] [p_are()]."))
	return TRUE

/mob/living/basic/outpost_prisoner/proc/refuse_polymorph(datum/source, what_to_randomize)
	SIGNAL_HANDLER
	visible_message(span_notice("[src] shimmers for a moment, then looks the same as before."))
	return STOP_WABBAJACK

/mob/living/basic/outpost_prisoner/proc/refuse_type_change(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_BLOCK_MOB_CHANGE

/// The dead stay dead: the corrections service has already logged the death, whether or not the body is still in the cell block
/mob/living/basic/outpost_prisoner/can_be_revived()
	if(died_at || (prison && phase == PRISONER_PRESENT))
		return FALSE
	return ..()

/// Someone tried to bring a dead prisoner back
/mob/living/basic/outpost_prisoner/proc/on_revive_attempt(datum/source, full_heal_flags)
	SIGNAL_HANDLER
	if(stat != DEAD || !prison || phase != PRISONER_PRESENT)
		return
	prison.add_log("Someone tried to revive [real_name]. The corrections service has already logged the death.")

/**
 * Whether they are shut in their cell: standing in a cell with its door bolted shut, or with
 * nowhere to walk but the cell and its doorway (a welded, walled-in or unpowered door).
 */
/mob/living/basic/outpost_prisoner/proc/is_confined()
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
