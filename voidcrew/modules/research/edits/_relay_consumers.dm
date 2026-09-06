/// Return the physical atom whose location authorizes this research consumer.
/// Relay revocation uses this to disconnect consumers without requiring every
/// datum type to expose its own site lookup.
/datum/proc/research_link_location()
	return isatom(src) ? src : null

/datum/computer_file/program/science/research_link_location()
	return computer

/// Exporting a techweb copies its state onto a portable disk. Relay access is
/// intentionally one-way: a ship may use the authoritative outpost web while
/// the relay is valid, but may not remove a portable copy after that access.
/// Keep the ordinary no-site/no-server fallback used by local standalone webs.
/proc/can_export_site_techweb(atom/machine, datum/techweb/web)
	if(!machine || !web)
		return FALSE
	for(var/obj/machinery/rnd/server/server as anything in web.techweb_servers)
		if(istype(server, /obj/machinery/rnd/server/relay))
			continue
		if(same_service_site(machine, server))
			return TRUE
	return !web.requires_physical_server && !length(web.techweb_servers) && !get_service_site(machine)

/// The server controller is a research consumer even though it is not an R&D
/// machine subtype. Register it so relay revocation can disconnect it, and
/// revalidate before exposing or mutating the server list through its UI.
/obj/machinery/computer/rdservercontrol/post_machine_initialize()
	. = ..()
	if(stored_research)
		stored_research.connected_machines |= src

/obj/machinery/computer/rdservercontrol/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/computer/rdservercontrol/unsync_research_servers()
	if(stored_research)
		stored_research.connected_machines -= src
		stored_research = null

/obj/machinery/computer/rdservercontrol/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb))
		if(!can_link_site_techweb(src, tool.buffer))
			balloon_alert(user, "server belongs to another site")
			return FALSE
		unsync_research_servers()
		stored_research = tool.buffer
		stored_research.connected_machines |= src
		balloon_alert(user, "techweb connected")
		return TRUE
	return TRUE

/obj/machinery/computer/rdservercontrol/ui_data(mob/user)
	validate_research_site(stored_research)
	. = ..()
	var/list/data = .
	for(var/list/server_data as anything in data["servers"]?.Copy())
		var/obj/machinery/rnd/server/server = locate(server_data["server_ref"])
		if(!same_service_site(src, server))
			data["servers"] -= list(server_data)
	for(var/list/console_data as anything in data["consoles"]?.Copy())
		var/obj/machinery/computer/rdconsole/console = locate(console_data["console_ref"])
		if(!same_service_site(src, console))
			data["consoles"] -= list(console_data)

/obj/machinery/computer/rdservercontrol/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(!validate_research_site(stored_research))
		return TRUE
	// Sharing research does not grant control over the other site's equipment.
	if(action == "lockdown_server")
		var/obj/machinery/rnd/server/server = locate(params["selected_server"])
		if(!same_service_site(src, server))
			return TRUE
	if(action == "lock_console")
		var/obj/machinery/computer/rdconsole/console = locate(params["selected_console"])
		if(!same_service_site(src, console))
			return TRUE
	return ..()
