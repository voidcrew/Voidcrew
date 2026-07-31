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
		claim_unlinked_experiment_handlers()
		return
	return ..()

/**
 * Adopts every experiment handler aboard this ship that has no techweb link.
 *
 * Experiment handlers (Experi-Scanners, destructive scanners, operating computers) are the only
 * research machinery that links itself, at Initialize, by looking for a server on its z-level. A crew
 * that prints a scanner before assembling the R&D kit gets an unlinked one, and nothing would ever
 * link it again - so run the same match from the other side the moment this server gets a techweb.
 *
 * Only null links are claimed: a handler someone deliberately multitooled to another web is left alone.
 */
/obj/machinery/rnd/server/ship/proc/claim_unlinked_experiment_handlers()
	if(!stored_research)
		return
	var/turf/our_turf = get_turf(src)
	if(!our_turf)
		return
	// get_voidcrew_ship_for_turf() is the multi-z-aware "which ship is this inside" test
	// (voidcrew/modules/overmap/code/modules/overmap/_overmap.dm). Servers standing somewhere that
	// isn't a ship - an outpost, a ruin - fall back to plain z matching, which is what the
	// self-link in CONNECT_TO_RND_SERVER_ROUNDSTART uses.
	var/obj/structure/overmap/ship/our_ship = get_voidcrew_ship_for_turf(our_turf)
	for(var/datum/component/experiment_handler/handler as anything in GLOB.experiment_handlers)
		if(handler.linked_web)
			continue
		var/atom/holder = handler.parent
		if(QDELETED(holder))
			continue
		var/turf/holder_turf = get_turf(holder)
		if(!holder_turf)
			continue
		if(our_ship)
			if(get_voidcrew_ship_for_turf(holder_turf) != our_ship)
				continue
		else if(!is_valid_z_level(holder_turf, our_turf))
			continue
		handler.link_techweb(stored_research, TRUE)

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
