// Voidcrew extensions to code/modules/shuttle/mobile_port/shuttle_move.dm.

/**
 * VOIDCREW ADDITION. Does this powernet have a member that will NOT travel with the hull?
 *
 * A net whose every cable and machine sits on a moving hull tile is carried across the
 * move intact: nothing in a powernet is positional, so there is nothing to rebuild, and
 * the machines on it never see the netless window that cutting opens (an emitter that
 * sees no powernet switches itself off and stays off). Only a net that reaches past the
 * hull - a cable run onto the berth, a docked neighbour wired across the airlock - has to
 * be severed, and then every hull cable of that net is cut so the two halves rebuild
 * separately as before. The walk is over the net's own members, once per net per move.
 *
 * "Moving hull tile" is the same test fromShuttleMove() applies: an area registered on
 * this port AND the shuttle skipover in the baseturfs. A breached tile adopted into a ship
 * area (see /area/onShuttleMove) has the area but no skipover, so a cable lying on it
 * counts as staying behind - which it does.
 */
/obj/docking_port/mobile/proc/powernet_leaves_hull(datum/powernet/net)
	if(isnull(net))
		return FALSE
	if(isnull(move_powernet_verdicts))
		return TRUE // not inside a preflight pass: keep upstream's cut-everything behaviour
	var/verdict = move_powernet_verdicts[net]
	if(!isnull(verdict))
		return verdict
	verdict = FALSE
	for(var/obj/structure/cable/member as anything in net.cables)
		if(isnull(member)) // a hard-deleted member is nulled in place, not removed
			continue
		if(!hull_tile_moves(member.loc))
			verdict = TRUE
			break
	if(!verdict)
		for(var/obj/machinery/power/member as anything in net.nodes)
			if(isnull(member))
				continue
			if(!hull_tile_moves(member.loc))
				verdict = TRUE
				break
	move_powernet_verdicts[net] = verdict
	return verdict

/// Voidcrew: will this turf's contents be carried by the move? Mirrors fromShuttleMove().
/obj/docking_port/mobile/proc/hull_tile_moves(turf/tile)
	if(!isturf(tile))
		return FALSE
	if(!shuttle_areas[tile.loc])
		return FALSE
	return isshuttleturf(tile)

/**
 * Rebuild the hull's powernets and plumbing after a move aborts between preflight_check()
 * and takeoff().
 *
 * By then beforeShuttleMove() has severed every hull cable of any net that reached past the
 * hull (see powernet_leaves_hull(); self-contained nets are left alone), and it deliberately
 * skips the deferred neighbour re-propagation (see /obj/structure/cable/beforeShuttleMove)
 * that used to heal exactly this window - so without this pass an aborted dock leaves the
 * whole grid cut, machines disconnected, until the next successful move. Nothing has moved
 * yet, so propagating from any severed cable rebuilds its grid in place; the rest of that
 * grid then short-circuits on the net it built, and untouched cables never had theirs cut.
 *
 * Plumbing components disconnect in beforeShuttleMove() the same way and are re-enabled
 * in place by restore_plumbing_after_aborted_move() (voidcrew/edits/machinery/plumbing_shuttle_move.dm).
 */
/obj/docking_port/mobile/proc/repair_networks_after_aborted_move(list/old_turfs)
	for(var/i in 1 to length(old_turfs))
		CHECK_TICK
		var/turf/oldT = old_turfs[i]
		if(!oldT)
			continue
		for(var/obj/structure/cable/cut_cable in oldT)
			cut_cable.propagate_if_no_network()
	restore_plumbing_after_aborted_move(old_turfs)

/obj/docking_port/mobile/var/list/move_powernet_verdicts
