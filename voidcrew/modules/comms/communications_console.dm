/// Console announcements follow physical ship ownership, including while docked.
/// Off-ship consoles use the local site's network, never the entire player list.
/proc/voidcrew_communications_ship(atom/source)
	var/area/source_area = get_area(source)
	if(!source_area)
		return null
	for(var/obj/docking_port/mobile/ship as anything in SSshuttle.mobile_docking_ports)
		if(ship.shuttle_areas[source_area])
			return ship
	return null

/proc/voidcrew_local_comms_net(atom/source)
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(source)
	if(ship)
		return "ship_[REF(ship)]"
	return voidcrew_physical_comms_net(get_turf(source))

/proc/voidcrew_announcement_players(atom/source)
	var/list/players = list()
	var/network = voidcrew_local_comms_net(source)
	if(!network)
		return players
	for(var/mob/player as anything in GLOB.player_list)
		if(voidcrew_local_comms_net(player) == network)
			players += player
	return players

/obj/docking_port/mobile
	/// All consoles aboard share an announcement cooldown, independent of other ships.
	var/datum/communciations_controller/announcement_controller
	/// Last status message entered at any console aboard this ship.
	var/list/last_comms_status_display
	/// Alert and maintenance access state belong to the hull, so all its consoles agree.
	var/comms_security_level = SEC_LEVEL_GREEN
	var/comms_emergency_access = FALSE

/obj/machinery/computer/communications/proc/get_announcement_controller()
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(src)
	if(!ship)
		return GLOB.communications_controller
	if(!ship.announcement_controller)
		ship.announcement_controller = new
	return ship.announcement_controller

/obj/machinery/computer/communications/proc/get_status_display_message()
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(src)
	return ship ? ship.last_comms_status_display : last_status_display

/obj/machinery/computer/communications/proc/get_communications_security_level()
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(src)
	if(!ship)
		return SSsecurity_level.current_security_level
	return SSsecurity_level.available_levels[SSsecurity_level.number_level_to_text(ship.comms_security_level)]

/obj/machinery/computer/communications/proc/set_communications_security_level(new_level)
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(src)
	if(!ship)
		SSsecurity_level.set_level(new_level)
		return
	var/datum/security_level/selected_level = SSsecurity_level.available_levels[SSsecurity_level.number_level_to_text(new_level)]
	if(!selected_level || ship.comms_security_level == new_level)
		return
	level_announce(selected_level, ship.comms_security_level, get_communication_players())
	ship.comms_security_level = new_level
	for(var/area/ship_area as anything in ship.shuttle_areas)
		for(var/obj/machinery/status_display/evac/display in ship_area)
			display.on_sec_level_change(ship, new_level)
	SSblackbox.record_feedback("tally", "security_level_changes", 1, selected_level.name)

/obj/machinery/computer/communications/proc/get_communications_emergency_access()
	var/obj/docking_port/mobile/ship = voidcrew_communications_ship(src)
	return ship ? ship.comms_emergency_access : GLOB.emergency_access

/obj/docking_port/mobile/proc/set_communications_emergency_access(enabled)
	comms_emergency_access = enabled
	for(var/area/ship_area as anything in shuttle_areas)
		for(var/obj/machinery/door/airlock/airlock in ship_area)
			if(!istype(ship_area, /area/station/maintenance) \
				&& !(ACCESS_MAINT_TUNNELS in airlock.req_access) && !(ACCESS_MAINT_TUNNELS in airlock.req_one_access) \
				&& !(ACCESS_EXTERNAL_AIRLOCKS in airlock.req_access) && !(ACCESS_EXTERNAL_AIRLOCKS in airlock.req_one_access))
				continue
			airlock.emergency = enabled
			airlock.update_icon(ALL, 0)
	minor_announce(
		enabled ? "Access restrictions on maintenance and external airlocks have been lifted." : "Access restrictions on maintenance and external airlocks have been restored.",
		enabled ? "Attention! Ship-wide emergency declared!" : "Attention! Ship-wide emergency rescinded:",
		alert = enabled,
		players = voidcrew_announcement_players(src),
	)
	SSblackbox.record_feedback("nested tally", "keycard_auths", 1, list("emergency maintenance access", enabled ? "enabled" : "disabled"))
