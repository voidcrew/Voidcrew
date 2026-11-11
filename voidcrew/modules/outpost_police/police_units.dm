/**
 * # Outpost police: units
 *
 * Owner: P2. The officer bodies (types are declared in police_core.dm: /police/beat, /sergeant, /officer,
 * /tactical, /marshal), their kit, the three zone profiles and the police cuffs. Spec 5.1 and 5.5.
 */

// ===== PROFILES =====

/// Waystation Halcyon (green)
/datum/outpost_police_profile/halcyon
	voice_section = "halcyon"

/// Quartermain Depot (yellow)
/datum/outpost_police_profile/quartermain
	voice_section = "quartermain"

/// The Undertow Exchange (red)
/datum/outpost_police_profile/undertow
	voice_section = "undertow"

/// The profile for this outpost's zone (called once, from /datum/outpost_police/New())
/datum/outpost_police/proc/make_profile()
	if(istype(outpost, /obj/structure/overmap/trader_outpost/general))
		return new /datum/outpost_police_profile/halcyon
	if(istype(outpost, /obj/structure/overmap/trader_outpost/outfitter))
		return new /datum/outpost_police_profile/quartermain
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return new /datum/outpost_police_profile/undertow
	return new /datum/outpost_police_profile

// ===== KIT =====

/// Police cuffs: the pair put on a suspect is /used
/obj/item/restraints/handcuffs/outpost_police

/// The pair on a suspect; gone when it comes off
/obj/item/restraints/handcuffs/outpost_police/used

/// Their baton, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_baton()
	return locate(/obj/item/melee/baton) in get_all_contents()

/// Their cuffs, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_cuffs()
	return locate(/obj/item/restraints/handcuffs) in get_all_contents()

/// Their sidearm, or null
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/get_sidearm()
	return locate(/obj/item/gun/energy) in get_all_contents()
