/**
 * # Derelict leash
 *
 * Owner: P4. Keeps a derelict's hostile inside that derelict's habitat.
 */
/datum/component/derelict_leash
	/// Weakref to the derelict this hostile belongs to
	var/datum/weakref/home
	/// Set while forceMove-ing a hostile back onto the habitat, so that return trip doesn't re-trigger the leash
	var/returning = FALSE

/datum/component/derelict_leash/Initialize(obj/structure/overmap/dynamic/player_outpost/derelict/home_site)
	if(!isliving(parent) || !istype(home_site))
		return COMPONENT_INCOMPATIBLE
	home = WEAKREF(home_site)

/datum/component/derelict_leash/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_MOVABLE_TELEPORTING, PROC_REF(on_teleporting))
	RegisterSignal(parent, COMSIG_MOB_LOGIN, PROC_REF(on_login))

/datum/component/derelict_leash/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_TELEPORTING, COMSIG_MOB_LOGIN))

/datum/component/derelict_leash/Destroy(force = FALSE)
	home = null
	return ..()

/// A hostile leaving the habitat is returned to it; carried off-site entirely, it is removed (§8 F2)
/datum/component/derelict_leash/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(returning)
		return
	var/mob/living/pawn = parent
	if(pawn.stat == DEAD)
		return
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = home?.resolve()
	if(!site)
		qdel(src)
		return
	var/turf/here = get_turf(pawn)
	if(!here || site.is_habitat_turf(here))
		return
	var/turf/back = get_turf(old_loc)
	if(back && site.is_habitat_turf(back))
		returning = TRUE
		pawn.forceMove(back)
		returning = FALSE
		return
	log_game("DERELICT OUTPOST: [pawn] ([pawn.type]) was carried off [site.name] and removed at [AREACOORD(here)]")
	returning = TRUE
	pawn.moveToNullspace()
	returning = FALSE
	QDEL_IN(pawn, 1)

/// Refuses every teleport, forced ones included (same contract as outpost_ambient_work.dm)
/datum/component/derelict_leash/proc/on_teleporting(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/// A player took the body; it is theirs now
/datum/component/derelict_leash/proc/on_login(datum/source)
	SIGNAL_HANDLER
	qdel(src)
