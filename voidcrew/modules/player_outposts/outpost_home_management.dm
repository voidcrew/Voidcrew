/// Numbered labels distinguish otherwise identical machines.
/obj/structure/overmap/dynamic/player_outpost/proc/research_server_options()
	var/list/options = list()
	for(var/obj/machinery/rnd/server/ship/server as anything in GLOB.ship_research_servers)
		if(!server.source_code_hdd || server.source_code_hdd.loc != server || get_outpost_from_atom(server) != src)
			continue
		options["[length(options) + 1]. [server.source_code_hdd.name] ([get_area(server)])"] = server
	return options

/obj/structure/overmap/dynamic/player_outpost/proc/research_relay_options()
	var/list/options = list()
	for(var/obj/machinery/rnd/server/relay/relay as anything in GLOB.outpost_research_relays)
		var/obj/structure/overmap/ship/ship = astype(get_service_site(relay))
		if(!ship || ship.docked != src || ship.state != OVERMAP_SHIP_IDLE || relay.connection)
			continue
		options["[length(options) + 1]. [ship.name]: [relay.name] ([get_area(relay)])"] = relay
	return options
