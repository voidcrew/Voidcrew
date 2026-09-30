/**
 * Free respawn after a death in the Neutral Zone.
 *
 * The respawn delay exists to make death in contested and lawless space cost something. Dying
 * in patrolled green space is almost always an accident or a tutorial mistake, so it is waived
 * there: the zone is recorded at the moment of death and [/mob/proc/check_respawn_delay] lets
 * the player straight back to the lobby.
 *
 * The zone is pinned to the death time so that the waiver only ever covers that one death.
 * Dying again, observing from the lobby, or ghosting out of a living body stamps a fresh
 * time_of_death that no longer matches, and the normal delay applies again. Re-entering the
 * corpse and ghosting again keeps the original death time (see respawn_timer.dm).
 */
/datum/persistent_client
	/// Overmap zone type (ZONE_GREEN/YELLOW/RED) the player's last death happened in, or null
	/// when it could not be tied to the overmap (CentCom, nullspace, ...).
	var/death_zone_type
	/// world.time of the death that death_zone_type describes.
	var/death_zone_time = 0

/// Whether the delay-free respawn applies to the death time_of_death currently points at.
/datum/persistent_client/proc/died_in_green_zone()
	return death_zone_type == ZONE_GREEN && time_of_death && death_zone_time == time_of_death

/**
 * Zone type for a turf a player is standing on, including ship interiors.
 *
 * [/datum/controller/subsystem/overmap_zones/proc/get_zone_type_anywhere] resolves ruins,
 * outposts and planets but not ships, which are where most deaths happen. Aboard a ship, the
 * ship's own overmap tile decides; get_turf() follows a docked ship to its carrier.
 */
/proc/get_zone_type_for_player_turf(turf/checked_turf)
	if(!checked_turf || !SSovermap_zones)
		return null
	var/obj/structure/overmap/ship/ship = get_voidcrew_ship_for_turf(checked_turf)
	return SSovermap_zones.get_zone_type_anywhere(ship ? get_turf(ship) : checked_turf)

/mob/living/death(gibbed)
	//death() can ghostize the player itself (lag switch), taking the persistent client with them.
	var/datum/persistent_client/player = persistent_client
	. = ..()
	if(!. || !player)
		return
	player.death_zone_type = get_zone_type_for_player_turf(get_turf(src))
	player.death_zone_time = timeofdeath

/mob/check_respawn_delay(override_delay = 0)
	if(!override_delay && persistent_client?.died_in_green_zone())
		return TRUE
	return ..()
