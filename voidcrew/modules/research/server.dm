#define RESEARCH_STOLEN_PER_THEFT 2500

/obj/machinery/rnd/server/ship
	desc = "A computer system that hosts a source R&D server drive, allowing research to be loaded and saved onto a disk, and shared within a vessel."
	circuit = /obj/item/circuitboard/machine/rdserver/ship
	///Installed source code files that hosts our research.
	var/obj/item/computer_disk/ship_disk/source_code_hdd

/obj/machinery/rnd/server/ship/Initialize(mapload)
	. = ..()
	QDEL_NULL(stored_research)
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY, PROC_REF(on_attack_hand_secondary))

/obj/machinery/rnd/server/ship/Destroy()
	UnregisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY)
	if(stored_research)
		stored_research.techweb_servers -= src
	if(source_code_hdd)
		// Unlink ship from techweb before destroying
		var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
		if(ship && ship.linked_techweb == source_code_hdd.stored_research)
			ship.unlink_techweb()
		for(var/atom/everything_connected as anything in source_code_hdd.stored_research.connected_machines)
			everything_connected.unsync_research_servers()
		source_code_hdd.forceMove(loc)
		source_code_hdd = null
	stored_research = null
	return ..()

/obj/machinery/rnd/server/ship/attacked_by(obj/item/attacking_item, mob/living/user)
	if(istype(attacking_item, /obj/item/computer_disk/ship_disk))
		if(source_code_hdd)
			balloon_alert(user, "disk already installed!")
			return
		if(!attacking_item.forceMove(src))
			balloon_alert(user, "won't fit!")
			return
		source_code_hdd = attacking_item
		stored_research = source_code_hdd.stored_research
		stored_research.techweb_servers |= src
		balloon_alert(user, "disk uploaded!")
		// Link the ship to this techweb for auto-upgrades
		link_ship_to_techweb()
		return
	return ..()

/// Links any ship this server is on to our techweb for radiation shielding auto-upgrades
/obj/machinery/rnd/server/ship/proc/link_ship_to_techweb()
	if(!source_code_hdd?.stored_research)
		return

	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(ship)
		ship.link_techweb(source_code_hdd.stored_research)

/obj/machinery/rnd/server/ship/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	. = ..()
	// When server connects to a shuttle (on mapload), link the ship to our techweb
	if(source_code_hdd?.stored_research)
		addtimer(CALLBACK(src, PROC_REF(link_ship_to_techweb)), 1 SECONDS)

/obj/machinery/rnd/server/ship/multitool_act(mob/living/user, obj/item/multitool/multi)
	if(!source_code_hdd)
		balloon_alert(user, "no disk!")
		return
	multi.buffer = source_code_hdd.stored_research
	to_chat(user, span_notice("Stored [src]'s techweb information in [multi]."))
	return TRUE

/atom/proc/unsync_research_servers()
	return

/**
 * ##attackhand_secondary
 *
 * Attempting to steal research nodes from the server by right clicking it.
 */
/obj/machinery/rnd/server/ship/proc/on_attack_hand_secondary(datum/source, mob/user)
	SIGNAL_HANDLER

	var/mob/living/living_user = user

	if(DOING_INTERACTION_WITH_TARGET(user, source))
		return COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN
	if(istype(living_user) && !living_user.combat_mode)
		return COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN

	INVOKE_ASYNC(src, PROC_REF(steal_research), user)
	return COMPONENT_SECONDARY_CANCEL_ATTACK_CHAIN

/obj/machinery/rnd/server/ship/proc/steal_research(mob/thief)
	if(!source_code_hdd.stored_research.can_afford(list(TECHWEB_POINT_TYPE_GENERIC = RESEARCH_STOLEN_PER_THEFT)))
		balloon_alert(thief, "not enough points to steal!")
		return
	balloon_alert(thief, "attempting to steal research points!")
	if(!do_after(thief, (10 SECONDS), src))
		balloon_alert(thief, "interrupted!")
		return
	source_code_hdd.stored_research.remove_point_list(list(TECHWEB_POINT_TYPE_GENERIC = RESEARCH_STOLEN_PER_THEFT))
	new /obj/item/research_notes(loc, RESEARCH_STOLEN_PER_THEFT, "thievery")

#undef RESEARCH_STOLEN_PER_THEFT

/**
 * Hard drive
 * What actually stores all the techweb data.
 */
/obj/item/computer_disk/ship_disk
	name = "R&D server source code"
	desc = "The source code on this drive stores all the research from a ship, insert it into an R&D console to make use of it."

	///The techweb we create on initialize and store everything to.
	var/datum/techweb/stored_research
	///All machines connected to us and our techweb, to disconnect on destruction
	var/list/connected_research_machines = list()

/obj/item/computer_disk/ship_disk/Initialize(mapload)
	. = ..()
	name += " [num2hex(rand(1,65535), -1)]"
	stored_research = new()
	stored_research.id = "[name]"
	stored_research.organization = "Server Disk"

/obj/item/computer_disk/ship_disk/Destroy()
	. = ..()
	QDEL_NULL(stored_research)
