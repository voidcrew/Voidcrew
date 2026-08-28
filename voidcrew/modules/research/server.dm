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
	var/obj/item/disk/computer/ship_disk/source_code_hdd

/obj/machinery/rnd/server/ship/Initialize(mapload)
	. = ..()
	QDEL_NULL(stored_research)
	GLOB.ship_research_servers += src
	RegisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY, PROC_REF(on_attack_hand_secondary))

/**
 * Correct the inherited hint. /obj/machinery/rnd/examine offers "a multitool with techweb designs
 * can be uploaded here", which is true of every other R&D machine and false of this one: the
 * multitool_act override below only ever reads the techweb OUT. The disk is the way in, and this
 * is the exact step crews get stuck on.
 */
/obj/machinery/rnd/server/ship/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		return
	if(isnull(source_code_hdd))
		. += span_warning("It holds no source code drive, so there is no research on it yet. Slot an R&D server source code disk into it.")
		return
	. += span_notice("Copy its techweb out with a [EXAMINE_HINT("multitool")], then use that multitool on a console, fabricator or scanner to link it.")

/obj/machinery/rnd/server/ship/Destroy()
	GLOB.ship_research_servers -= src
	UnregisterSignal(src, COMSIG_ATOM_ATTACK_HAND_SECONDARY)
	if(stored_research)
		stored_research.techweb_servers -= src
	// Local, because ejecting the disk fires our own Exited(), which clears source_code_hdd
	// under us.
	var/obj/item/disk/computer/ship_disk/ejecting = source_code_hdd
	if(ejecting)
		// Only a LIVE disk gets handed back to the world. forceMove()ing a destroyed one plants a
		// zombie on the floor that nothing can ever clear - qdel() early-returns on anything whose
		// gc_destroyed is already set - and the next thing to sweep that turf files it away
		// permanently (/obj/structure/safe swallows loose items in its Initialize), which is a
		// hard delete plus a "taking damage after deletion" runtime for every hit the tile takes.
		if(!QDELETED(ejecting))
			// Guarded: a disk whose techweb has already been destroyed (it was incinerated in here,
			// say) has a null stored_research, and this used to runtime on the way out.
			var/datum/techweb/disk_web = ejecting.stored_research
			for(var/atom/everything_connected in disk_web?.connected_machines)
				everything_connected.unsync_research_servers()
			ejecting.forceMove(loc)
		set_source_code_hdd(null)
	stored_research = null
	return ..()

/**
 * Adopts `new_disk` as our source code drive, releasing whatever we held before.
 *
 * Always go through this rather than assigning source_code_hdd. It is a plain typed var, so a disk
 * destroyed while slotted stays pinned soft-deleted until the GC gives up and hard-deletes it -
 * and on the way out our Destroy() would hand that corpse back to the world.
 */
/obj/machinery/rnd/server/ship/proc/set_source_code_hdd(obj/item/disk/computer/ship_disk/new_disk)
	if(source_code_hdd == new_disk)
		return
	if(source_code_hdd)
		UnregisterSignal(source_code_hdd, COMSIG_QDELETING)
	source_code_hdd = new_disk
	if(source_code_hdd)
		RegisterSignal(source_code_hdd, COMSIG_QDELETING, PROC_REF(on_source_code_hdd_deleted))

/// The drive was destroyed while slotted - let go of it, and of the techweb that lived on it.
/obj/machinery/rnd/server/ship/proc/on_source_code_hdd_deleted(datum/source)
	SIGNAL_HANDLER
	release_stored_research()
	set_source_code_hdd(null)

/// The drive left by some route other than attacked_by - deconstruction's dump_contents(),
/// atom_break, an admin move. Keeping the pointer would leave us claiming a techweb we no longer
/// hold, and would pin the disk if it were destroyed somewhere else later.
/obj/machinery/rnd/server/ship/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != source_code_hdd)
		return
	release_stored_research()
	set_source_code_hdd(null)

/// Drops our claim on the disk's techweb, unregistering us as one of its servers.
/obj/machinery/rnd/server/ship/proc/release_stored_research()
	if(!stored_research)
		return
	stored_research.techweb_servers -= src
	stored_research = null

// Full parent signature (code/_onclick/item_attack.dm) - declaring fewer params here would drop
// modifiers/attack_modifiers on the way through ..() for every melee hit on the server.
/obj/machinery/rnd/server/ship/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(istype(attacking_item, /obj/item/disk/computer/ship_disk))
		if(source_code_hdd)
			balloon_alert(user, "disk already installed!")
			return
		// forceMove's return value cannot be trusted for a held item: upstream's
		// /obj/item/doMove (code/game/objects/items.dm, tg #93967) reroutes anything with
		// IN_INVENTORY through owner.transferItemToLoc() and returns null even when the
		// move succeeds. Checking `!forceMove(src)` here ate the disk - it landed in the
		// server's contents but was never registered as the HDD. Verify the loc instead.
		attacking_item.forceMove(src)
		if(attacking_item.loc != src)
			balloon_alert(user, "won't fit!")
			return
		set_source_code_hdd(attacking_item)
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
	// set_buffer(), not a raw assignment: it registers COMSIG_QDELETING on the techweb so the
	// multitool drops the reference when the disk dies, and unregisters whatever was in the
	// buffer before. Assigning through left the old buffer's registration live, so the next
	// legitimate set_buffer() of that same datum tripped a duplicate-registration stack trace.
	multi.set_buffer(source_code_hdd.stored_research)
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
	// Upstream dropped remove_point_list(); adjust_points() floors at 0, so a negative
	// adjustment is the subtraction. `stolen` is already clamped to the live balance above.
	victim_web.adjust_multiple_points(list(TECHWEB_POINT_TYPE_GENERIC = -stolen))
	new /obj/item/research_notes(loc, stolen, "thievery")
	balloon_alert(thief, "siphoned [stolen] points!")

#undef RESEARCH_STOLEN_PER_THEFT

/**
 * Hard drive
 * What actually stores all the techweb data.
 */
/obj/item/disk/computer/ship_disk
	name = "R&D server source code"
	// It goes in the SERVER, not the console - the console is then multitooled to the server.
	// The old wording sent people to the R&D console, which since upstream gave /obj/item/disk an
	// item_interaction answers "Machine cannot accept disks in that format" and reads as broken.
	desc = "The source code on this drive stores all the research from a ship. Slot it into an R&D server, then link consoles and fabricators to that server with a multitool."
	// Matches /datum/design/ship_disk's cost so a hand-spawned disk is worth the same at
	// the ORM as a printed one (the printed disk already inherits these).
	custom_materials = list(/datum/material/glass = SHEET_MATERIAL_AMOUNT * 2)

	///The techweb we create on initialize and store everything to.
	var/datum/techweb/stored_research

/obj/item/disk/computer/ship_disk/Initialize(mapload)
	. = ..()
	name += " [num2hex(rand(1,65535), -1)]"
	stored_research = new()
	stored_research.id = "[name]"
	stored_research.organization = "Server Disk"

/obj/item/disk/computer/ship_disk/Destroy(force)
	// Refs go before ..(), the tg convention: the parent nullspaces us and disposes of our
	// contents, so anything released afterwards is released against a half-torn-down atom.
	QDEL_NULL(stored_research)
	return ..()
