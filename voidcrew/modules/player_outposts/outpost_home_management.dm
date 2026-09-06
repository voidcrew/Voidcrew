/// Numbered choices keep identical disk/ship names selectable, even at the same location.
/obj/structure/overmap/dynamic/player_outpost/proc/research_pair_server_options(remote = FALSE)
	var/list/options = list()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(!server.source_code_hdd || server.source_code_hdd.loc != server)
			continue
		var/obj/structure/overmap/ship/ship = astype(get_service_site(server))
		if(remote ? (!ship || ship.docked != src) : get_outpost_from_atom(server) != src)
			continue
		var/turf/location = get_turf(server)
		var/disk_label = "[server.source_code_hdd.name] at [get_area(server)] ([location.x], [location.y], [location.z])"
		options["[length(options) + 1]. [remote ? "[ship.name]: " : ""][disk_label]"] = server
	return options
