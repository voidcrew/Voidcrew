/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

/// Whether this outpost refuses this user service at its counters, lift and network pad
/obj/structure/overmap/trader_outpost/proc/background_service_refused(mob/user)
	return FALSE

/// What the trader says when refusing this user, or null
/obj/structure/overmap/trader_outpost/proc/background_refusal_line(mob/user)
	return null

/// Why this outpost refuses this ship a berth, or null
/obj/structure/overmap/trader_outpost/proc/background_docking_refusal(obj/structure/overmap/ship/acting)
	return null
