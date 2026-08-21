/*
 * # Crew monitoring is scoped to a hull, not to a z-level
 *
 * Upstream's crew console filters suit sensors with "same z-level, or both ends on a
 * station level" - there is one station, so anywhere on it counts as here. Voidcrew
 * flags EVERY ship interior as a station level (link_to_z_level(),
 * voidcrew/mapping/docking_port/_docking_port.dm, so stationloving and friends keep
 * working aboard a ship), which makes that second clause true for any two ships in the
 * round. The console listed every crewmember on the server - names, jobs, damage
 * breakdown and current area - to anyone who opened it.
 *
 * Same shape of leak as the AI camera one in silicon_ship_systems.dm, and the same fix:
 * scope against the hull the device is aboard rather than the level it happens to sit
 * on.
 *
 * The z-level stays in play as a second term rather than being dropped, because a
 * landed ship shares its z with whatever it landed on. Keeping it means an away team
 * out on the surface, or inside the ruin the ship is docked to, stays on the monitor -
 * that is the case suit sensors exist for. Anyone standing on another ship's deck is
 * that ship's crew and gets filtered back out, which also covers ship-to-ship docking
 * and shared transit levels.
 *
 * The z-level term alone stopped being enough once four encounters started sharing a
 * level: a crewman off their own hull is admitted by the isnull(their_hull) branch, and
 * on a packed level that branch equally admits the NEIGHBOUR's away team - names, jobs,
 * damage breakdown and current area, to a crew that has never met them. The off-hull
 * branch therefore also has to agree on the SITE, which is the map region under the two
 * of them (see map_region_for_turf). Ground that resolves to no region behaves exactly
 * as it did before.
 */

/**
 * The ship a crew monitor's sensors are wired into.
 *
 * Null when the device isn't aboard one at all - an outpost console, a ruin, an admin
 * spawn. Those fall back to the plain z-level test, which is what upstream already does
 * for anything off a station level.
 */
/proc/voidcrew_crew_sensor_hull(atom/source)
	var/obj/docking_port/mobile/voidcrew/hull = SSshuttle.get_containing_shuttle(source)
	return istype(hull) ? hull : null

/**
 * Cache key for one monitor's scope.
 *
 * The sensor sweep is cached for SENSORS_UPDATE_PERIOD and was keyed by z-level. Two
 * ships can share a level (docked together, parked at the same planet, sitting in
 * transit), so a level key would hand one ship's crew list straight to the other for the
 * next ten seconds - the leak this whole file exists to close. Key by hull wherever
 * there is one.
 */
/proc/voidcrew_crew_sensor_cache_key(obj/docking_port/mobile/voidcrew/hull, scope_z, turf/source_turf)
	if(hull)
		return "hull_[REF(hull)]"
	// No hull: an outpost console, a ruin, an admin spawn. Two of those on one packed
	// z-level would share a level key and hand each other's crew list over for the next
	// ten seconds, so narrow it to the site the console is standing on.
	var/datum/region = map_region_for_turf(source_turf)
	return region ? "site_[REF(region)]" : "z_[scope_z]"

/**
 * TRUE when `tracked` belongs on a monitor scoped to `hull` (may be null) standing on
 * z-level `scope_z`.
 *
 * TRAIT_MULTIZ_SUIT_SENSORS (kheiral cuffs) still waives the level test the way upstream
 * intends - it is the "I am off-site and want to stay on the board" opt-in. It does not
 * waive the other-hull test: it should keep the wearer on their own crew's monitor, not
 * put them on a stranger's. It equally does not have to satisfy the same-site test, which
 * only ever narrows the same-z case.
 *
 * `source_turf` is where the console itself is standing; null keeps the pre-packing
 * behaviour for any caller that cannot supply it.
 */
/proc/voidcrew_crew_sensor_in_scope(mob/living/tracked, turf/pos, obj/docking_port/mobile/voidcrew/hull, scope_z, turf/source_turf)
	if(hull?.is_in_shuttle_bounds(pos))
		return TRUE

	if(pos.z != scope_z && !HAS_TRAIT(tracked, TRAIT_MULTIZ_SUIT_SENSORS))
		return FALSE

	// Off our hull but in the same place: the away team on the surface, the boarding
	// party in the ruin. A neighbour's deck is a different crew.
	var/obj/docking_port/mobile/voidcrew/their_hull = voidcrew_crew_sensor_hull(tracked)
	if(!isnull(their_hull))
		return their_hull == hull

	// Off every hull, on our level. On a packed level "our level" is four sites, so it has
	// to be OUR site: our own away team in the ruin we are docked to stays on the board,
	// the crew working the encounter across the gutter does not. Deliberately scoped to the
	// same-z case - a multiz-sensors wearer genuinely off-site keeps their waiver.
	if(isnull(source_turf) || pos.z != scope_z)
		return TRUE
	// Refuses only ground that positively belongs to somebody else. A console standing on
	// ground that resolves to no site (a hull built out past its footprint, a roundstart
	// level) must not start dropping its own away team off the board.
	var/datum/monitor_site = map_region_for_turf(source_turf)
	var/datum/tracked_site = map_region_for_turf(pos)
	if(isnull(monitor_site) || isnull(tracked_site))
		return TRUE
	return monitor_site == tracked_site
