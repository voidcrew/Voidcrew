// Tutorial checklist hooks. Part C: R&D setup (kit, ship server, disk, console, protolathe, multitool
// links) and surveys (research node, survey console, notes).
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

// ---------------------------------------------------------------------------
// R&D setup
// ---------------------------------------------------------------------------

/// The autolathe builds on a timer with no user, so the kit counts once a player picks it up or opens it.
/obj/item/storage/box/rndboards/all/pickup(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_KIT)

/datum/storage/box/rndkit/open_storage(mob/living/to_show)
	. = ..()
	if(.)
		tutorial_credit(to_show, TUTORIAL_STEP_RESEARCH_KIT)

/// on_construction() runs for flatpack deploys and frame builds, never for mapped machines.
/obj/machinery/rnd/server/ship/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_SERVER)

/obj/machinery/computer/rdconsole/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_CONSOLE)

/obj/machinery/rnd/production/protolathe/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_PROTOLATHE)

/// The ship server takes its source disk in attacked_by (voidcrew/modules/research/server.dm).
/obj/machinery/rnd/server/ship/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	var/had_disk = !!source_code_hdd
	. = ..()
	if(!had_disk && source_code_hdd && source_code_hdd == attacking_item)
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_DISK)

/// The ship server's multitool_act stores its disk's techweb in the multitool buffer.
/obj/machinery/rnd/server/ship/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && source_code_hdd?.stored_research && tool.buffer == source_code_hdd.stored_research)
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_MULTITOOL)

/obj/machinery/computer/rdconsole/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && stored_research && stored_research == tool.buffer && tutorial_ship_rnd_linked(get_ship_from_atom(src), stored_research))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_LINK)

/obj/machinery/rnd/production/protolathe/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	if(. && stored_research && stored_research == tool.buffer && tutorial_ship_rnd_linked(get_ship_from_atom(src), stored_research))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_LINK)

/**
 * TRUE when the ship has an R&D console and a protolathe both on a techweb served by a ship
 * R&D server. With no web given, the ship's own research web is used.
 * Walks the hull's machines, so only call it on a player action or a panel open.
 */
/proc/tutorial_ship_rnd_linked(obj/structure/overmap/ship/ship, datum/techweb/web)
	if(QDELETED(ship))
		return FALSE
	if(!web)
		web = ship.get_research_web()
	if(!web || !(locate(/obj/machinery/rnd/server/ship) in web.techweb_servers))
		return FALSE
	var/console_linked = FALSE
	for(var/obj/machinery/computer/rdconsole/console as anything in ship.get_ship_machines(/obj/machinery/computer/rdconsole))
		if(console.stored_research == web)
			console_linked = TRUE
			break
	if(!console_linked)
		return FALSE
	for(var/obj/machinery/rnd/production/protolathe/lathe as anything in ship.get_ship_machines(/obj/machinery/rnd/production/protolathe))
		if(lathe.stored_research == web)
			return TRUE
	return FALSE

// ---------------------------------------------------------------------------
// Surveys
// ---------------------------------------------------------------------------

/// Research notes are redeemed (and deleted) by the Voidcrew override in research/edits/_rd_consoles.dm.
/// Notes of any origin count, because merged notes change origin.
/obj/machinery/computer/rdconsole/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	var/is_notes = istype(attacking_item, /obj/item/research_notes)
	. = ..()
	if(is_notes && QDELETED(attacking_item))
		tutorial_credit(user, TUTORIAL_STEP_SURVEYS_NOTES)

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SURVEY_CONSOLE)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_SURVEYS_NODE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_SURVEYS_BUILD)
