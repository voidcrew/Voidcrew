// Tutorial checklist hooks: the Repair drones item (voidcrew/modules/shuttle/construction).
// Overrides chain with any others of the same proc.

/datum/techweb/research_node(datum/techweb_node/node, force = FALSE, auto_adjust_cost = TRUE, get_that_dosh = TRUE, atom/research_source)
	. = ..()
	if(!. || !istype(node) || node.id != TECHWEB_NODE_SHIP_REPAIR_SWARM)
		return
	var/obj/structure/overmap/ship/ship = metric_techweb_ship(src)
	if(ship)
		tutorial_credit_crew(ship, TUTORIAL_STEP_REPAIR_DRONES_RESEARCH)

/// The final step spawns the drone and deletes the chassis this component sits on.
/datum/component/construction/ship_repair_drone/check_step(obj/item/item, mob/living/user)
	var/atom/chassis = parent
	. = ..()
	if(. && QDELETED(chassis) && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_REPAIR_DRONES_ASSEMBLE)

/obj/structure/ship_repair_drone/multitool_act(mob/living/user, obj/item/multitool/tool)
	var/was_linked = !!console
	. = ..()
	if(!was_linked && console && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_REPAIR_DRONES_LINK)

/// Drones call this when a repair finishes. Credits the crew aboard the console's ship.
/obj/machinery/computer/camera_advanced/base_construction/ship/perform_record_repair(datum/ship_repair_record/record)
	. = ..()
	if(. && current_ship)
		tutorial_credit_crew(current_ship, TUTORIAL_STEP_REPAIR_DRONES_REPAIR, aboard_only = TRUE)
