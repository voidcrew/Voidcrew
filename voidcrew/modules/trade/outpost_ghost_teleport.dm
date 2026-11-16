/**
 * Ghost Teleport menu entries for trader outposts (hooked from /mob/dead/observer/verb/dead_tele).
 *
 * Every trader outpost shares the one UNIQUE_AREA /area/voidcrew/trader_outpost, so the plain
 * area list showed a single "Trader Outpost" that dropped the ghost into whichever outpost a
 * random turf belonged to. This swaps the shared outpost areas for one entry per loaded outpost,
 * named after it.
 */

/// Takes the ghost menu's area list and returns it with each loaded trader outpost listed by name at the top
/proc/add_trader_outposts_to_ghost_teleport(list/areas)
	var/list/options = list()
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		if(outpost.is_loaded() && outpost.ghost_teleport_turf())
			options += outpost
	for(var/area/listed as anything in areas)
		if(istype(listed, /area/voidcrew/trader_outpost))
			continue
		options += listed
	return options

/// Where a ghost lands when it picks this outpost: the public pad, the main trader, or the middle of the concourse
/obj/structure/overmap/trader_outpost/proc/ghost_teleport_turf()
	if(network_pad_spot)
		return network_pad_spot
	var/turf/trader_turf = get_turf(trader)
	if(trader_turf && reservation?.contains_turf(trader_turf))
		return trader_turf
	if(!template_bottom_left || !outpost_template?.width || !outpost_template?.height)
		return null
	return locate(
		template_bottom_left.x + round(outpost_template.width / 2),
		template_bottom_left.y + round(outpost_template.height / 2),
		template_bottom_left.z
	)
