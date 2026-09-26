/**
 * Teleports never cross an overmap zone boundary.
 *
 * Ships pay a 10 second wait to cross a band (ZONE_TRANSITION_TIME) so nobody can dart into
 * safe space mid-fight. A hand teleporter, quantum pad or fulton aimed at a ship parked in
 * green skipped that wait entirely, so crews bailed out of every lawless fight the moment it
 * went badly. Every teleport now asks this first.
 *
 * Both ends are resolved with get_zone_type_for_player_turf(), which follows ship interiors to
 * their hull's overmap tile and planets, ruins and outposts to theirs. A teleport is refused
 * only when both ends resolve and differ: places that belong to no zone (CentCom, transit,
 * unclaimed build-out levels) are left alone so this cannot wedge a system teleport.
 */

/// Zone type (ZONE_GREEN/YELLOW/RED) the turf under an atom belongs to, or null.
/proc/get_teleport_zone_type(atom/checked)
	var/turf/checked_turf = get_turf(checked)
	// Overmap objects (ships, sites) answer straight from their tile, skipping the ship search
	if(istype(checked_turf, /turf/open/overmap))
		return SSovermap_zones.resolve_zone_for_overmap_turf(checked_turf)
	return get_zone_type_for_player_turf(checked_turf)

/// Whether moving from `origin` to `destination` would change overmap zone.
/proc/teleport_crosses_zone(atom/origin, atom/destination)
	var/turf/origin_turf = get_turf(origin)
	var/turf/destination_turf = get_turf(destination)
	if(!origin_turf || !destination_turf)
		return FALSE
	var/origin_zone = get_teleport_zone_type(origin_turf)
	if(isnull(origin_zone))
		return FALSE
	var/destination_zone = get_teleport_zone_type(destination_turf)
	if(isnull(destination_zone))
		return FALSE
	return origin_zone != destination_zone

/// Tells a mob its teleport bounced off a zone boundary. Every refusal uses the same wording.
/proc/zone_teleport_refused(atom/movable/teleatom)
	if(!ismob(teleatom))
		return
	teleatom.balloon_alert(teleatom, "bluespace disruption!")
	to_chat(teleatom, span_warning("Bluespace disruption along the zone boundary throws you back."))

/**
 * Whether an atom is, or is carrying, a mob (a folded bluespace body bag, a mob holder, a pAI
 * card, a brain). Corpses count: a body sent ahead can be revived on the other side.
 */
/proc/atom_carries_living_mob(atom/movable/checked)
	if(isliving(checked))
		return TRUE
	for(var/mob/living/passenger in checked.get_all_contents())
		return TRUE
	return FALSE

/**
 * The paradox bag's two halves share one storage wherever they are, so anything put in one
 * comes out of the other in any zone. Items are fine; people folded into a bluespace body bag
 * or a mob holder are a zone crossing, so the bag refuses them.
 */
/datum/storage/can_insert(obj/item/to_insert, mob/user, messages = TRUE, force = STORAGE_NOT_LOCKED)
	if(istype(parent, /obj/item/shared_storage) && istype(to_insert) && atom_carries_living_mob(to_insert))
		if(messages && user)
			parent.balloon_alert(user, "won't fit!")
		return FALSE
	return ..()

/// The jaunter picks a random beacon on any ship level. Only offer ones in its own zone, so a
/// chasm save does not pick a beacon it cannot reach and let its owner fall anyway.
/obj/item/wormhole_jaunter/get_destinations()
	var/list/in_zone = list()
	for(var/beacon in ..())
		if(!teleport_crosses_zone(src, beacon))
			in_zone += beacon
	return in_zone

/// A linked pad in another zone would take the charge and move nothing, so say why up front.
/obj/machinery/quantumpad/doteleport(mob/user = null, obj/machinery/quantumpad/target_pad = linked_pad)
	if(target_pad && teleport_crosses_zone(src, target_pad))
		if(user)
			to_chat(user, span_warning("Bluespace disruption along the zone boundary blocks the link to the target pad."))
		return
	return ..()

/area/misc/hilbertshotel
	/// Where the latest arrival came in from, so a sphere carried into itself goes back there
	var/turf/last_entry_turf

/area/misc/hilbertshotel/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	last_entry_turf = get_turf(old_loc)
	return ..()

/**
 * A sphere carried into its own hotel is flung to a random safe turf on any ship level, and
 * everyone checked in walks out wherever it lands. Keep it in the zone it was carried in from.
 */
/area/misc/hilbertshotel/relocate(obj/item/hilbertshotel/H)
	var/turf/entry = last_entry_turf
	..()
	if(QDELETED(H) || !entry)
		return
	if(teleport_crosses_zone(entry, H))
		H.forceMove(entry)
