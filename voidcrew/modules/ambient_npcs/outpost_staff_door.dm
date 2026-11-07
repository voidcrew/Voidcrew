/**
 * A door into a trader's back room (Splice's booth behind the Chop Shop counter). Players use it
 * like any other door; the outpost's ambient NPCs never path through it, open it or step through
 * it, even while someone holds it open.
 */
/obj/machinery/door/airlock/centcom/outpost_staff
	// Asked even while open, so an open door is no shortcut for them
	can_astar_pass = CANASTARPASS_ALWAYS_PROC

/// Whether `thing` is one of the ambient NPCs this door keeps out
/proc/outpost_staff_door_blocks(atom/thing)
	return istype(thing, /mob/living/basic/ambient_npc)

/obj/machinery/door/airlock/centcom/outpost_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(outpost_staff_door_blocks(pass_info.requester_ref?.resolve()))
		return FALSE
	return ..()

/obj/machinery/door/airlock/centcom/outpost_staff/CanAllowThrough(atom/movable/mover, border_dir)
	if(outpost_staff_door_blocks(mover))
		return FALSE
	return ..()

/obj/machinery/door/airlock/centcom/outpost_staff/bumpopen(mob/user)
	if(outpost_staff_door_blocks(user))
		return
	return ..()
