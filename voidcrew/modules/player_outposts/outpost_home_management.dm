/// Numbered labels distinguish otherwise identical machines.
/obj/structure/overmap/dynamic/player_outpost/proc/research_server_options()
	var/list/options = list()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(!server.source_code_hdd || server.source_code_hdd.loc != server || get_outpost_from_atom(server) != src)
			continue
		options["[length(options) + 1]. [server.source_code_hdd.name] ([get_area(server)])"] = server
	return options

/obj/structure/overmap/dynamic/player_outpost/proc/research_ship_options()
	var/list/options = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!QDELETED(ship) && ship.docked == src && ship.state == OVERMAP_SHIP_IDLE)
			options["[length(options) + 1]. [ship.name]"] = ship
	return options

/obj/structure/overmap/dynamic/player_outpost/proc/research_connection_summary()
	var/connected = 0
	var/offline = 0
	var/invited = 0
	for(var/datum/outpost_research_link/link as anything in research_links)
		if(!link.valid_endpoints())
			continue
		if(!link.ship_approved)
			invited++
		else if(link.available())
			connected++
		else
			offline++
	return "[connected] connected / [offline] offline / [invited] invited"
