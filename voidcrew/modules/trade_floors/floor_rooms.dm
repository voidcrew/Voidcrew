/**
 * # Outpost floors: rooms and trading
 *
 * Owner: P4 (spec 4). Rooms are the player outposts' own /datum/outpost_upgrade blueprints. The base procs on
 * /obj/structure/overmap/dynamic/player_outpost (offers_upgrade(), pad_follows_dock_modes(), pad_admits(),
 * advert_place(), ship_is_home()) and /obj/structure/overmap/proc/network_zone_turf() answer as before floors;
 * P4 overrides them on the host here.
 *
 * Stub below is P0's.
 */

/// What this floor offers visitors, as words for the board (Shop, Clinic, Cloning, Lockers, Teleporter, Canteen).
/// Shop only while the shop is open. Stub: an empty list.
/datum/outpost_floor/proc/offers()
	return list()
