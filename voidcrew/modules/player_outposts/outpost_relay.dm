GLOBAL_LIST_EMPTY(outpost_research_relays)

/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/outpost_research_link/research_links = list()
	/// Pending requests do not evict the active ship until its replacement approves.
	var/datum/outpost_research_link/active_research_link
	var/home_service_timer

/obj/structure/overmap/dynamic/player_outpost/proc/process_home_services()
	freight?.check_stalled()
	for(var/datum/outpost_research_link/link as anything in research_links.Copy())
		link.reconcile()

/obj/structure/overmap/dynamic/player_outpost/proc/revoke_research_links()
	for(var/datum/outpost_research_link/link as anything in research_links.Copy())
		qdel(link)

/// The request records exactly the disk and relay the manager selected.
/obj/structure/overmap/dynamic/player_outpost/proc/propose_research_link(mob/user, obj/machinery/rnd/server/ship/server, obj/machinery/rnd/server/relay/relay, obj/item/computer_disk/ship_disk/expected_disk)
	var/obj/structure/overmap/ship/ship = astype(get_service_site(relay))
	if(!can_manage(user) || QDELETED(server) || QDELETED(relay) || !ship || ship.docked != src || ship.state != OVERMAP_SHIP_IDLE)
		return null
	if(get_outpost_from_atom(server) != src || !expected_disk || server.source_code_hdd != expected_disk || expected_disk.loc != server)
		return null
	// A relay cannot have simultaneous requests against several outposts.
	if(relay.connection)
		return null
	var/datum/outpost_research_link/link = new(src, server, relay, ship)
	research_links += link
	relay.connection = link
	ship.ship_notify("[name] requests a research connection. Captain approval is available at [relay].", "RESEARCH")
	return link

/datum/outpost_research_link
	var/datum/weakref/home_ref
	var/datum/weakref/ship_ref
	var/datum/weakref/home_server
	var/datum/weakref/home_disk
	var/datum/weakref/ship_relay
	var/datum/weakref/captain_ref
	var/owner_ckey
	var/ship_approved = FALSE

/datum/outpost_research_link/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/rnd/server/ship/server, obj/machinery/rnd/server/relay/relay, obj/structure/overmap/ship/ship)
	home_ref = WEAKREF(home)
	ship_ref = WEAKREF(ship)
	home_server = WEAKREF(server)
	home_disk = WEAKREF(server.source_code_hdd)
	ship_relay = WEAKREF(relay)
	owner_ckey = home.founder_ckey
	RegisterSignal(server, COMSIG_QDELETING, PROC_REF(endpoint_deleted))
	RegisterSignal(server.source_code_hdd, COMSIG_QDELETING, PROC_REF(endpoint_deleted))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(endpoint_deleted))

/datum/outpost_research_link/Destroy()
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay?.resolve()
	ship_approved = FALSE
	if(home?.active_research_link == src)
		home.active_research_link = null
	home?.research_links.Remove(src)
	if(relay?.connection == src)
		relay.connection = null
		relay.disconnect_research()
	for(var/datum/weakref/endpoint as anything in list(home_server, home_disk, ship_ref))
		var/datum/target = endpoint?.resolve()
		if(target)
			UnregisterSignal(target, COMSIG_QDELETING)
	return ..()

/datum/outpost_research_link/proc/endpoint_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Undocking does not change approval. Physical replacement and command changes do.
/datum/outpost_research_link/proc/valid_endpoints()
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	var/obj/machinery/rnd/server/ship/server = home_server?.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay?.resolve()
	var/obj/item/computer_disk/ship_disk/disk = home_disk?.resolve()
	if(!home || !ship || !server || !relay || !disk || relay.connection != src || owner_ckey != home.founder_ckey)
		return FALSE
	if(server.source_code_hdd != disk || disk.loc != server || server.stored_research != disk.stored_research)
		return FALSE
	if(get_outpost_from_atom(server) != home)
		return FALSE
	// A shuttle relocates its turfs in stages. Check its final footprint when idle.
	if(ship.state == OVERMAP_SHIP_IDLE && get_service_site(relay) != ship)
		return FALSE
	if(ship_approved)
		var/datum/mind/captain = captain_ref?.resolve()
		if(home.active_research_link != src || !captain || !ship.is_ship_captain(captain.current))
			return FALSE
	return TRUE

/datum/outpost_research_link/proc/available()
	if(!ship_approved || !valid_endpoints())
		return FALSE
	var/obj/machinery/rnd/server/ship/server = home_server.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay.resolve()
	return server.is_operational && relay.is_operational && !server.research_disabled && !relay.research_disabled \
		&& get_service_site(relay) == ship_ref.resolve()

/datum/outpost_research_link/proc/approve(mob/living/user)
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(ship_approved || !valid_endpoints() || !ship.is_ship_captain(user) || ship.docked != home || ship.state != OVERMAP_SHIP_IDLE)
		return FALSE
	var/obj/machinery/rnd/server/ship/server = home_server.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay.resolve()
	if(!server.is_operational || !relay.is_operational || server.research_disabled || relay.research_disabled)
		return FALSE
	QDEL_NULL(home.active_research_link)
	home.active_research_link = src
	captain_ref = WEAKREF(user.mind)
	ship_approved = TRUE
	relay.stored_research = server.stored_research
	relay.stored_research.techweb_servers |= relay
	relay.update_appearance()
	home.notify_owner("Research connected to [ship.name].", "RESEARCH")
	ship.ship_notify("Research connected to [home.name].", "RESEARCH")
	return TRUE

/datum/outpost_research_link/proc/reconcile()
	if(!valid_endpoints())
		qdel(src)
		return
	var/obj/machinery/rnd/server/relay/relay = ship_relay.resolve()
	if(ship_approved && !available())
		relay.disconnect_consumers()
	relay.update_appearance()

/datum/outpost_research_link/proc/status_text()
	if(!valid_endpoints())
		return "Disconnected"
	if(!ship_approved)
		return "Awaiting captain"
	return available() ? "Connected" : "Offline"

/// This machine exposes a disk, never owns or copies one. It cannot serve another relay.
/obj/machinery/rnd/server/relay
	name = "R&D relay"
	desc = "Connects ship equipment to an outpost's R&D server. Copy its link with a multitool, then link equipment normally. The outpost requests a connection at its server; the ship captain approves or disconnects with a secondary multitool click here."
	circuit = /obj/item/circuitboard/machine/rdserver/relay
	var/datum/outpost_research_link/connection

/obj/machinery/rnd/server/relay/Initialize(mapload)
	stored_research = new /datum/techweb
	. = ..()
	// The server parent allocates a temporary web. Never retain a relay-owned disk.
	stored_research.techweb_servers -= src
	QDEL_NULL(stored_research)
	GLOB.outpost_research_relays += src

/obj/machinery/rnd/server/relay/Destroy()
	GLOB.outpost_research_relays -= src
	QDEL_NULL(connection)
	disconnect_research()
	return ..()

/obj/machinery/rnd/server/relay/proc/connection_available()
	return !QDELETED(connection) && connection.available()

/obj/machinery/rnd/server/relay/research_link_available(atom/machine)
	return connection_available() && same_service_site(machine, src)

/// Relays cannot be pointed at raw web buffers, even by crafted connection calls.
/obj/machinery/rnd/server/relay/connect_techweb(datum/techweb/new_techweb)
	return FALSE

/obj/machinery/rnd/server/relay/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!connection_available())
		balloon_alert(user, "relay offline")
		return TRUE
	return ..()

/obj/machinery/rnd/server/relay/unsync_research_servers()
	QDEL_NULL(connection)
	disconnect_research()

/obj/machinery/rnd/server/relay/proc/disconnect_research()
	if(!stored_research)
		return
	stored_research.techweb_servers -= src
	disconnect_consumers()
	// The physical outpost disk owns this web; parent destruction must not delete it.
	stored_research = null
	update_appearance()

/obj/machinery/rnd/server/relay/proc/disconnect_consumers()
	if(!stored_research)
		return
	for(var/datum/consumer as anything in stored_research.connected_machines.Copy())
		var/atom/location = consumer.research_link_location()
		if(!can_link_site_techweb(location, stored_research))
			consumer.unsync_research_servers()
	for(var/datum/component/experiment_handler/handler as anything in GLOB.experiment_handlers)
		if(handler.linked_web == stored_research && !can_link_site_techweb(handler.parent, stored_research))
			handler.unlink_techweb()

/obj/machinery/rnd/server/relay/update_icon_state()
	. = ..()
	icon_state = "[base_icon_state]-[connection_available() ? "on" : "off"]"

/obj/machinery/rnd/server/relay/refresh_working()
	. = ..()
	connection?.reconcile()

/obj/machinery/rnd/server/relay/get_status_text()
	return connection?.status_text() || "Unpaired"

/obj/machinery/rnd/server/relay/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = connection?.home_ref.resolve()
	. += span_notice("[home ? "[home.name]: [connection.status_text()]" : "Unpaired"].")

/obj/machinery/rnd/server/relay/multitool_act_secondary(mob/living/user, obj/item/multitool/tool)
	var/obj/structure/overmap/ship/ship = astype(get_service_site(src))
	if(!ship?.is_ship_captain(user) || !user.can_perform_action(src))
		balloon_alert(user, "ship captain required")
		return ITEM_INTERACT_BLOCKING
	var/datum/outpost_research_link/selected = connection
	if(QDELETED(selected))
		balloon_alert(user, "no connection request")
		return ITEM_INTERACT_BLOCKING
	var/obj/structure/overmap/dynamic/player_outpost/home = selected.home_ref.resolve()
	var/action = selected.ship_approved ? "Disconnect" : "Approve"
	var/choice = tgui_alert(user, "[action] research with [home.name]?", "R&D Relay", list(action, "Cancel"))
	if(QDELETED(src) || QDELETED(selected) || QDELETED(user) || !user.can_perform_action(src) || get_service_site(src) != ship || !ship.is_ship_captain(user) || connection != selected || choice != action)
		return ITEM_INTERACT_BLOCKING
	if(action == "Disconnect")
		qdel(selected)
	else if(!selected.approve(user))
		balloon_alert(user, "connection refused: check docking and power")
		return ITEM_INTERACT_BLOCKING
	balloon_alert(user, action == "Disconnect" ? "disconnected" : "connected")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/rnd/server/ship/multitool_act_secondary(mob/living/user, obj/item/multitool/tool)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home?.can_manage(user) || !user.can_perform_action(src))
		balloon_alert(user, "outpost management permission required")
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(home, TYPE_PROC_REF(/obj/structure/overmap/dynamic/player_outpost, prompt_research_relay), user, src)
	return ITEM_INTERACT_SUCCESS

/obj/structure/overmap/dynamic/player_outpost/proc/prompt_research_relay(mob/living/user, obj/machinery/rnd/server/ship/server)
	var/obj/item/computer_disk/ship_disk/expected_disk = server.source_code_hdd
	var/list/options = list("Connect ship" = "connect")
	for(var/datum/outpost_research_link/link as anything in research_links)
		var/obj/structure/overmap/ship/ship = link.ship_ref.resolve()
		options["[length(options)]. Disconnect [ship?.name] ([link.status_text()])"] = link
	var/choice = tgui_input_list(user, "Connection", "Outpost R&D", options)
	if(QDELETED(src) || QDELETED(server) || QDELETED(user) || !user.can_perform_action(server) || !can_manage(user) || get_outpost_from_atom(server) != src)
		return
	var/datum/outpost_research_link/selected = options[choice]
	if(istype(selected) && !QDELETED(selected) && (selected in research_links))
		qdel(selected)
		server.balloon_alert(user, "disconnected")
		return
	if(options[choice] != "connect")
		return
	var/list/relays = research_relay_options()
	if(!length(relays))
		server.balloon_alert(user, "no available docked ship relay")
		return
	var/obj/machinery/rnd/server/relay/relay = relays[tgui_input_list(user, "Ship relay", "Outpost R&D", relays)]
	if(QDELETED(src) || QDELETED(server) || QDELETED(relay) || QDELETED(user) || !user.can_perform_action(server))
		return
	if(!propose_research_link(user, server, relay, expected_disk))
		server.balloon_alert(user, "connection request refused")
		return
	server.balloon_alert(user, "awaiting ship captain")

/obj/machinery/rnd/server/ship/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home)
		return
	. += span_notice("An outpost manager can connect a docked ship's R&D relay with a secondary multitool click. The captain approves at the relay. One ship stays connected, including after departure.")
	for(var/datum/outpost_research_link/link as anything in home.research_links)
		if(link.home_server.resolve() == src)
			var/obj/structure/overmap/ship/ship = link.ship_ref.resolve()
			. += span_notice("[ship?.name]: [link.status_text()].")
