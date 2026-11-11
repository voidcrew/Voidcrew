/**
 * # Outpost police: the cutter
 *
 * Owner: P9. At four and five stars a police cutter chases the crew's ship when it undocks (spec 9). Its ship
 * subtype (/obj/structure/overmap/ship/npc/pirate/nt_patrol/police), director (/datum/nt_patrol_director/police)
 * and template (/datum/map_template/shuttle/voidcrew/police_cutter, voidcrew/mapping/shuttles/police_cutter.dm)
 * are P9's to declare: subtypes of those are enumerated by ship lists, admin spawners and tests, so P0 left
 * them out.
 */

/// Sends the cutter after `ship` once per incident
/datum/outpost_police/proc/start_pursuit(obj/structure/overmap/ship/ship, stars, officers_killed)
	return
