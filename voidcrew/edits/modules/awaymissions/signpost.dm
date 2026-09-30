// Voidcrew extensions to code/modules/awaymissions/signpost.dm.

/**
 * Where this signpost drops [user]. Voidcrew: aboard the ship they crew, and nowhere else.
 *
 * Upstream rolled a random safe turf on any ZTRAIT_STATION z-level, which on /tg/ means the
 * station. This fork stamps that trait onto every z-level that currently holds a ship -
 * link_to_z_level(), voidcrew/mapping/docking_port/_docking_port.dm - NPC hulls included, and
 * a ship interior is the only pressurised thing on such a level, so the old roll reliably
 * deposited whoever used it inside a random ship. Pirates counted. Resolve the user's own hull
 * through the same mind-to-ship mapping the shop and the outposts use; crewing nothing means
 * there is nowhere to go back to.
 */
/obj/structure/signpost/proc/get_destination_turf(mob/user)
	var/obj/structure/overmap/ship/home = get_crew_ship(user)
	if(!home?.shuttle?.shuttle_areas)
		return null

	var/list/habitable = list()
	var/list/breached = list() //A hull venting to space is still a better landing than none at all.
	for(var/area/ship_area in home.shuttle.shuttle_areas)
		for(var/turf/deck in ship_area)
			if(!isopenturf(deck) || deck.density || isspaceturf(deck))
				continue
			if(is_safe_turf(deck))
				habitable += deck
			else
				breached += deck

	if(length(habitable))
		return pick(habitable)
	return length(breached) ? pick(breached) : null

/// The meme signpost keeps its anywhere-at-all roll; it is not promising anyone a way home.
/obj/structure/signpost/exit/get_destination_turf(mob/user)
	return find_safe_turf(zlevels = zlevels)
