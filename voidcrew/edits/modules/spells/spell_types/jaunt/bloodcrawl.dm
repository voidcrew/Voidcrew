// Voidcrew extensions to code/modules/spells/spell_types/jaunt/bloodcrawl.dm.

/// Blood pools can be across an area boundary, beyond the holder's phased movement checks.
/datum/action/cooldown/spell/jaunt/bloodcrawl/proc/is_valid_blood_destination(atom/origin, obj/effect/decal/cleanable/blood)
	if(QDELETED(blood) || !blood.can_bloodcrawl_in())
		return FALSE
	var/turf/destination = get_turf(blood)
	if(!destination || (destination.turf_flags & NOJAUNT) || SSmapping.level_trait(destination.z, ZTRAIT_NOPHASE))
		return FALSE
	return check_teleport_valid(origin, destination, TELEPORT_CHANNEL_MAGIC)
