/*
 * Stationary pressure tanks (code/modules/atmospherics/machinery/components/tank.dm)
 *
 * The tank is already deconstructable - a right-click welder cuts it open into a tank
 * frame - but that dumps every mole it was holding into the room, and there was no way
 * at all to just move one. Its left-click wrench is taken: on a tank that opens and
 * closes the side pipe ports. Right-click wrench is free, so that is the bolt toggle.
 *
 * The tank will only unbolt with all of its ports closed. toggle_side_port() nulls the
 * tank's pipe nodes as it closes each one, so a tank with open_ports == NONE is attached
 * to nothing and can be dragged away without stranding half a pipenet behind it.
 */

/obj/machinery/atmospherics/components/tank/examine(mob/user, thats)
	. = ..()
	if(!anchored)
		. += span_notice("It is <i>unbolted</i> from the floor and can be dragged elsewhere.")
	else if(!open_ports)
		. += span_notice("With every pipe port closed it can be <b>right-click wrenched</b> to unbolt it from the floor.")

/obj/machinery/atmospherics/components/tank/wrench_act_secondary(mob/living/user, obj/item/tool)
	. = ..()
	if(.)
		return .
	if(open_ports)
		balloon_alert(user, "close its ports first!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool, time = 4 SECONDS) == SUCCESSFUL_UNFASTEN)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/*
 * Movables do not re-queue icon smoothing when they change tile - nothing that smooths
 * was expected to move under its own power - so a dragged tank would stay smoothed to
 * the neighbours it left behind. Destroy() already does this for the tile it vacates.
 */
/obj/machinery/atmospherics/components/tank/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(isturf(old_loc))
		QUEUE_SMOOTH_NEIGHBORS(old_loc)
	QUEUE_SMOOTH(src)
	QUEUE_SMOOTH_NEIGHBORS(src)
