/**
 * # GPS Signal Locality
 *
 * Upstream, a GPS in MAXIMUM (global) range lists every signal in the world.
 * On the overmap that means a crewman sitting on their ship in deep space sees
 * every ruin beacon, planet signal and other ship's crew GPS in the sector.
 * Pure noise, and sector-level detection is the helm's job (ship sensors, star
 * charts), not the handheld GPS's.
 *
 * Signals are listed when both ends belong to the same overmap object (a
 * planet's footprint, a ruin's reservation, a trader outpost). This used to
 * carry a same-z fast path in front of that test, justified in this file as
 * safe because "docking physically moves the ship onto that z-level" - true
 * while one encounter owned one z-level, and false the moment four of them
 * share one. The fast path handed every GPS on a packed level the other three
 * crews' beacons, which is precisely the sector-wide noise this file exists to
 * remove. The overmap-object comparison already covers the case it was there
 * for: a ship docked at a site resolves to that site, and so does its own away
 * team standing in the ruin.
 *
 * The z comparison survives only as the fallback for ground that resolves to no
 * overmap object at all - a ship flying in deep space, a roundstart level, a
 * transit reservation - where it means what it always meant. Two hulls CAN share
 * that ground (transit levels are shared), so it is narrowed one further step by
 * map region before it answers.
 *
 * Local (non-global) mode is untouched: it has always meant "this z-level only".
 *
 * Mission beacons uploaded to a specific unit (see
 * voidcrew/modules/missions/gps_link.dm) are appended separately and are
 * intentionally unaffected, they're how you navigate to mission targets.
 */
/datum/component/gps/item/is_signal_visible(turf/curr, turf/pos)
	if(!global_mode)
		return pos.z == curr.z
	var/obj/structure/overmap/local_object = SSovermap_zones?.get_overmap_object_for_turf(curr)
	if(!isnull(local_object))
		return local_object == SSovermap_zones.get_overmap_object_for_turf(pos)
	if(pos.z != curr.z)
		return FALSE
	return map_regions_match(curr, pos)
