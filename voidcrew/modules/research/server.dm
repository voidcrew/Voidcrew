/// Points siphoned out of a victim's techweb per successful theft. A theft no longer needs the
/// server to be holding some large minimum - the thief just keeps pulling, one siphon at a time,
/// and each pull takes this much or whatever is actually left if that's less.
#define RESEARCH_STOLEN_PER_THEFT 100

/**
 * Every ship R&D server in the world.
 *
 * Exists so "does this hull have a techweb" can be answered by walking a list a few
 * entries long instead of every turf of every shuttle area. That question is asked on a
 * timer by SSmissions (per ship, per fire), by the sensor range and ruin-identification
 * readouts, and by the zone advisory - see /obj/structure/overmap/ship/find_research_web().
 * The old hull-wide scan measured 5.7 ms per call and was 99% of SSmissions' entire cost.
 *
 * Membership is Initialize/Destroy, so a destroyed server drops out before anything can
 * read it - leaving one in here would pin it soft-deleted until the GC hard-deleted it.
 */
GLOBAL_LIST_EMPTY(ship_research_servers)

/obj/machinery/rnd/server/ship
	desc = "A computer system that hosts a source R&D server drive, allowing research to be loaded and saved onto a disk, and shared within a vessel."
	circuit = /obj/item/circuitboard/machine/rdserver/ship
	///Installed source code files that hosts our research.
	var/obj/item/computer_disk/ship_disk/source_code_hdd

/obj/machinery/rnd/server/ship/Initialize(mapload)
	. = ..()
	QDEL_NULL(stored_research)
	GLOB.ship_research_servers += src
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY, PROC_REF(on_attack_hand_secondary))

/obj/machinery/rnd/server/ship/Destroy()
	GLOB.ship_research_servers -= src
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

/**
 * Siphons a slice of the victim's actual point balance into a research-notes item.
 *
 * The theft is drawn from what the server is really holding rather than paid out as a flat grant,
 * so a ship that has already spent its research is not worth robbing, and a rich one can be milked
 * repeatedly - each right-click is one siphon.
 */
/obj/machinery/rnd/server/ship/proc/steal_research(mob/thief)
	// A server with no disk holds no techweb at all. The old code walked straight through
	// source_code_hdd.stored_research and runtimed on any empty server.
	if(isnull(source_code_hdd))
		balloon_alert(thief, "no disk!")
		return
	var/datum/techweb/victim_web = source_code_hdd.stored_research
	if(isnull(victim_web))
		balloon_alert(thief, "no research!")
		return
	if(victim_web.research_points[TECHWEB_POINT_TYPE_GENERIC] < 1)
		balloon_alert(thief, "no points to steal!")
		return
	balloon_alert(thief, "siphoning research points!")
	if(!do_after(thief, (10 SECONDS), src))
		balloon_alert(thief, "interrupted!")
		return
	// Re-read the balance after the do_after rather than trusting the pre-check: the crew can spend
	// or bank points during those ten seconds. Taking the minimum means a server drained mid-theft
	// pays out nothing instead of minting points the web never had.
	var/available = victim_web.research_points[TECHWEB_POINT_TYPE_GENERIC] || 0
	var/stolen = FLOOR(min(RESEARCH_STOLEN_PER_THEFT, available), 1)
	if(stolen < 1)
		balloon_alert(thief, "no points to steal!")
		return
	victim_web.remove_point_list(list(TECHWEB_POINT_TYPE_GENERIC = stolen))
	new /obj/item/research_notes(loc, stolen, "thievery")
	balloon_alert(thief, "siphoned [stolen] points!")

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
