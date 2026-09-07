GLOBAL_LIST_EMPTY(outpost_research_relays)

/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/outpost_research_link/research_links = list()
	var/home_service_timer

/obj/structure/overmap/dynamic/player_outpost/proc/process_home_services()
	freight?.check_stalled()
	for(var/datum/outpost_research_link/link as anything in research_links.Copy())
		link.reconcile()

/obj/structure/overmap/dynamic/player_outpost/proc/revoke_research_links()
	for(var/datum/outpost_research_link/link as anything in research_links.Copy())
		qdel(link)

/// Invitations bind a docked ship and physical source disk, even before a relay exists.
/obj/structure/overmap/dynamic/player_outpost/proc/propose_research_link(mob/user, obj/machinery/rnd/server/ship/server, obj/structure/overmap/ship/ship, obj/item/computer_disk/ship_disk/expected_disk)
	if(!can_manage(user) || QDELETED(server) || QDELETED(ship) || ship.docked != src || ship.state != OVERMAP_SHIP_IDLE)
		return null
	if(get_research_service_site(server) != src || !expected_disk || server.source_code_hdd != expected_disk || expected_disk.loc != server)
		return null
	for(var/datum/outpost_research_link/existing as anything in research_links)
		if(!existing.ship_approved && existing.ship_ref.resolve() == ship && existing.home_server.resolve() == server && existing.valid_endpoints())
			return existing
	var/datum/outpost_research_link/link = new(src, server, ship)
	research_links += link
	ship.ship_notify("[name] invites you to share research. A crew member can accept at an R&D relay.", "RESEARCH")
	return link

/datum/outpost_research_link
	var/datum/weakref/home_ref
	var/datum/weakref/ship_ref
	var/datum/weakref/home_server
	var/datum/weakref/home_disk
	var/datum/weakref/ship_relay
	var/owner_ckey
	var/ship_approved = FALSE

/datum/outpost_research_link/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/rnd/server/ship/server, obj/structure/overmap/ship/ship)
	home_ref = WEAKREF(home)
	ship_ref = WEAKREF(ship)
	home_server = WEAKREF(server)
	home_disk = WEAKREF(server.source_code_hdd)
	owner_ckey = home.founder_ckey
	RegisterSignal(server, COMSIG_QDELETING, PROC_REF(endpoint_deleted))
	RegisterSignal(server.source_code_hdd, COMSIG_QDELETING, PROC_REF(endpoint_deleted))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(endpoint_deleted))

/datum/outpost_research_link/Destroy()
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay?.resolve()
	ship_approved = FALSE
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

/// Invitations survive departure; connected relays retain access until revoked or replaced.
/datum/outpost_research_link/proc/valid_endpoints()
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	var/obj/machinery/rnd/server/ship/server = home_server?.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay?.resolve()
	var/obj/item/computer_disk/ship_disk/disk = home_disk?.resolve()
	if(!home || !ship || !server || !disk || owner_ckey != home.founder_ckey || !(src in home.research_links))
		return FALSE
	if(server.source_code_hdd != disk || disk.loc != server || server.stored_research != disk.stored_research)
		return FALSE
	if(get_research_service_site(server) != home)
		return FALSE
	if(ship_approved)
		if(!relay || relay.connection != src)
			return FALSE
		// A shuttle relocates its turfs in stages. Check its final footprint when idle.
		if(ship.state == OVERMAP_SHIP_IDLE && get_service_site(relay) != ship)
			return FALSE
	return TRUE

/datum/outpost_research_link/proc/available()
	if(!ship_approved || !valid_endpoints())
		return FALSE
	var/obj/machinery/rnd/server/ship/server = home_server.resolve()
	var/obj/machinery/rnd/server/relay/relay = ship_relay.resolve()
	return server.is_operational && relay.is_operational && !server.research_disabled && !relay.research_disabled \
		&& ship_contains_endpoint(relay)

/// Hull areas move before the mobile port's bounds during a yielding shuttle move.
/datum/outpost_research_link/proc/ship_contains_endpoint(atom/machine)
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(!ship || !machine)
		return FALSE
	if(get_service_site(machine) == ship)
		return TRUE
	var/area/location = get_area(machine)
	return ship_is_moving() && location && (location in ship.shuttle?.shuttle_areas)

/datum/outpost_research_link/proc/ship_is_moving()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	return ship && (ship.state in list(OVERMAP_SHIP_DOCKING, OVERMAP_SHIP_UNDOCKING))

/datum/outpost_research_link/proc/approve(mob/living/user, obj/machinery/rnd/server/relay/relay)
	var/obj/structure/overmap/dynamic/player_outpost/home = home_ref?.resolve()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	if(ship_approved || !valid_endpoints() || QDELETED(relay) || relay.connection || get_service_site(relay) != ship || !relay.can_manage_connection(user) || ship.docked != home || ship.state != OVERMAP_SHIP_IDLE)
		return FALSE
	var/obj/machinery/rnd/server/ship/server = home_server.resolve()
	if(!server.is_operational || !relay.is_operational || server.research_disabled || relay.research_disabled)
		return FALSE
	ship_relay = WEAKREF(relay)
	relay.connection = src
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
	if(!ship_approved)
		return
	var/obj/machinery/rnd/server/relay/relay = ship_relay.resolve()
	if(!available() && !ship_is_moving())
		relay.disconnect_consumers()
	relay.update_appearance()

/datum/outpost_research_link/proc/status_text()
	if(!valid_endpoints())
		return "Disconnected"
	if(!ship_approved)
		return "Invited"
	return available() ? "Connected" : "Offline"

/// This machine exposes a disk, never owns or copies one. It cannot serve another relay.
/obj/machinery/rnd/server/relay
	name = "R&D relay"
	desc = "Connects ship equipment to shared outpost research."
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
	return connection_available() && connection.ship_contains_endpoint(machine)

/// Relays cannot be pointed at raw web buffers, even by crafted connection calls.
/obj/machinery/rnd/server/relay/connect_techweb(datum/techweb/new_techweb)
	return FALSE

/obj/machinery/rnd/server/relay/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(QDELETED(connection))
		balloon_alert(user, "outpost connection required")
		return TRUE
	if(!connection.ship_approved)
		balloon_alert(user, "accept invitation empty-handed")
		return TRUE
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
	return connection ? connection.status_text() : "Unpaired"

/obj/machinery/rnd/server/relay/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = connection?.home_ref.resolve()
	. += span_notice("[home ? "[home.name]: [connection.status_text()]" : "Unpaired"].")

/// Ship membership grants control of the local relay, including after a captain change.
/obj/machinery/rnd/server/relay/proc/can_manage_connection(mob/living/user)
	var/obj/structure/overmap/ship/ship = astype(get_service_site(src))
	return user?.mind && ship && (user.mind in ship.ship_team?.members) && user.can_perform_action(src)

/obj/machinery/rnd/server/relay/proc/invitation_options()
	var/list/options = list()
	var/obj/structure/overmap/ship/ship = astype(get_service_site(src))
	if(!ship || ship.state != OVERMAP_SHIP_IDLE)
		return options
	var/obj/structure/overmap/dynamic/player_outpost/home = astype(ship.docked)
	for(var/datum/outpost_research_link/link as anything in home?.research_links)
		if(link.ship_approved || link.ship_ref.resolve() != ship || !link.valid_endpoints())
			continue
		var/obj/machinery/rnd/server/ship/server = link.home_server.resolve()
		options["[length(options) + 1]. [home.name] - [server.name]"] = link
	return options

/obj/machinery/rnd/server/relay/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	if(!can_manage_connection(user))
		balloon_alert(user, "ship crew required")
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(prompt_connection), user)
	return TRUE

/obj/machinery/rnd/server/relay/proc/prompt_connection(mob/living/user)
	if(!can_manage_connection(user))
		return
	var/datum/outpost_research_link/selected = connection
	if(selected)
		var/obj/structure/overmap/dynamic/player_outpost/home = selected.home_ref.resolve()
		var/confirmed = confirm_connection(user, home, TRUE)
		if(!QDELETED(src) && !QDELETED(selected) && connection == selected && can_manage_connection(user) && confirmed)
			qdel(selected)
			balloon_alert(user, "disconnected")
		return
	var/list/options = invitation_options()
	if(!length(options))
		balloon_alert(user, "no outpost invitation")
		return
	if(length(options) == 1)
		selected = options[options[1]]
	else
		selected = options[tgui_input_list(user, "Research invitation", "R&D Relay", options)]
	if(QDELETED(src) || QDELETED(selected) || !can_manage_connection(user))
		return
	var/obj/structure/overmap/dynamic/player_outpost/home = selected.home_ref.resolve()
	var/confirmed = confirm_connection(user, home)
	if(QDELETED(src) || QDELETED(selected) || !can_manage_connection(user) || !confirmed)
		return
	if(!selected.approve(user, src))
		balloon_alert(user, "invitation unavailable: check docking and power")
		return
	balloon_alert(user, "research connected")

/obj/machinery/rnd/server/ship/examine(mob/user)
	. = ..()
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(home)
		. += span_notice("Invite docked ships through Outpost Management to share this server's research.")

/obj/machinery/rnd/server/relay/proc/confirm_connection(mob/living/user, obj/structure/overmap/dynamic/player_outpost/home, disconnect = FALSE)
	var/action = disconnect ? "Disconnect" : "Accept"
	return tgui_alert(user, disconnect ? "Disconnect from [home?.name]?" : "Share research with [home?.name]?", "R&D Relay", list(action, "Cancel")) == action
