/// Backgrounds: owned by P3.

/**
 * Whether `user` is on the roster of `ship`. The Marshal's brig gear opens for nobody else: every
 * req_access lock on a crewed hull opens for anyone (voidcrew/edits/ship_access.dm), prisoners
 * included, so these ignore access lists and ask the roster.
 */
/proc/marshal_roster_admits(obj/structure/overmap/ship/ship, mob/user)
	if(!user)
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	return !!(ship && user.mind && (user.mind in ship.ship_team?.members))

// ===== CELL DOOR =====

/// A brig cell's door on a Marshal-class hull: opens for the hull's crew only
/obj/machinery/door/airlock/security/glass/marshal_brig
	name = "brig cell"

/// The hull whose crew this door answers to
/obj/machinery/door/airlock/security/glass/marshal_brig/proc/owning_ship()
	return get_ship_from_atom(src)

// The roster or nothing: no emergency access, no unrestricted side, no ship waiver
/obj/machinery/door/airlock/security/glass/marshal_brig/allowed(mob/user)
	return marshal_roster_admits(owning_ship(), user)

// No ID, item or door remote opens a cell (door.dm Bumped() and the door remote read access lists, never allowed())
/obj/machinery/door/airlock/security/glass/marshal_brig/check_access_list(list/access_list)
	return FALSE

// ===== MARSHAL'S LOCKER [ECO-12] =====

/// The hull's weapons: stocked once, opened by its crew only. Checkpoint rebuilds never restock a closet (outpost_checkpoint_snapshot.dm).
/obj/structure/closet/secure_closet/marshal_arms
	name = "marshal's locker"
	icon_state = "sec"
	anchored = TRUE
	req_access = null
	req_one_access = null
	access_choices = FALSE

/obj/structure/closet/secure_closet/marshal_arms/allowed(mob/user)
	return marshal_roster_admits(get_ship_from_atom(src), user)

/obj/structure/closet/secure_closet/marshal_arms/PopulateContents()
	..()
	for(var/i in 1 to 2)
		new /obj/item/gun/energy/disabler(src)
		new /obj/item/assembly/flash/handheld(src)
	for(var/i in 1 to 4)
		new /obj/item/restraints/legcuffs/bola(src)
