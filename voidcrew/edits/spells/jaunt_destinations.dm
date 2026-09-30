/// Blood pools can be across an area boundary, beyond the holder's phased movement checks.
/datum/action/cooldown/spell/jaunt/bloodcrawl/proc/is_valid_blood_destination(atom/origin, obj/effect/decal/cleanable/blood)
	if(QDELETED(blood) || !blood.can_bloodcrawl_in())
		return FALSE
	var/turf/destination = get_turf(blood)
	if(!destination || (destination.turf_flags & NOJAUNT) || SSmapping.level_trait(destination.z, ZTRAIT_NOPHASE))
		return FALSE
	return check_teleport_valid(origin, destination, TELEPORT_CHANNEL_MAGIC)

// VOIDCREW EDIT: reclaim reference effects even when the action loses its owner first.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/Destroy()
	clear_exit_points()
	return ..()

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/proc/clear_exit_points()
	QDEL_NULL(start_point_anchor)
	QDEL_LIST(exit_point_list)
	exit_point_list = null

/// An invisible location reference, carried by ordinary shuttle movement and rotation.
/obj/effect/abstract/jaunt_exit
	name = "jaunt return reference"
	icon = null
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE

/datum/action/cooldown/spell/jaunt/ethereal_jaunt
	var/obj/effect/abstract/jaunt_exit/start_point_anchor

/// Removal, body changes and forced ejection can end the return animation early.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/on_jaunt_exited(obj/effect/dummy/phased_mob/jaunt, mob/living/unjaunter)
	UnregisterSignal(jaunt, COMSIG_MOVABLE_MOVED)
	clear_exit_points()
	REMOVE_TRAIT(unjaunter, TRAIT_IMMOBILIZED, REF(src))
	return ..()
