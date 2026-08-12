/**
 * # GPS Signal Locality
 *
 * Upstream, a GPS in MAXIMUM (global) range lists every signal in the world.
 * On the overmap that means a crewman sitting on their ship in deep space sees
 * every ruin beacon, planet signal and other ship's crew GPS in the sector.
 * Pure noise, and sector-level detection is the helm's job (ship sensors, star
 * charts), not the handheld GPS's.
 *
 * Cross-z signals are now only listed when both ends belong to the same
 * overmap object (a planet's mapzone, a ruin's reservation, a trader outpost).
 * Same-z signals are always listed, which also covers ships docked at a
 * planet/outpost, since docking physically moves the ship onto that z-level.
 * A ship flying in deep space resolves to no overmap object, so only same-z
 * signals (your own ship's) show.
 *
 * Mission beacons uploaded to a specific unit (see
 * voidcrew/modules/missions/gps_link.dm) are appended separately and are
 * intentionally unaffected, they're how you navigate to mission targets.
 */
/datum/component/gps/item/is_signal_visible(turf/curr, turf/pos)
	if(pos.z == curr.z)
		return TRUE
	if(!global_mode)
		return FALSE
	var/obj/structure/overmap/local_object = SSovermap_zones?.get_overmap_object_for_turf(curr)
	if(isnull(local_object))
		return FALSE
	return local_object == SSovermap_zones.get_overmap_object_for_turf(pos)
