// Tutorial checklist hooks. Part C: R&D console, protolathe, research node, survey console and notes hooks.
// Overrides chain with any others of the same proc; each returns the parent's value unchanged.

/obj/machinery/computer/rdconsole/ui_interact(mob/user, datum/tgui/ui = null)
	. = ..()
	if(stored_research)
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_CONSOLE)

/// Research notes are redeemed (and deleted) by the Voidcrew override in research/edits/_rd_consoles.dm.
/// Notes of any origin count, because merged notes change origin.
/obj/machinery/computer/rdconsole/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	var/is_notes = istype(attacking_item, /obj/item/research_notes)
	. = ..()
	if(is_notes && QDELETED(attacking_item))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_NOTES)

/obj/machinery/rnd/production/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(istype(src, /obj/machinery/rnd/production/protolathe))
		tutorial_credit(user, TUTORIAL_STEP_RESEARCH_LATHE)

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SURVEY_CONSOLE)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_RESEARCH_NODE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_RESEARCH_BUILD)
