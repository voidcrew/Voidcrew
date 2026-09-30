// Voidcrew extensions to code/game/objects/items/rcd/RCD.dm.

/**
 * Which way a directional build placed by this RCD should face.
 *
 * Directional windows, windoors, chairs, tables, racks and beds all take their facing from
 * whoever is building them, and for a handheld RCD that is simply the user's own dir. It is
 * not for an RCD driven remotely: the voidcrew ship construction console's drone is several
 * rooms away from the body holding the "user" role, so every directional structure it built
 * came out facing wherever the operator's body happened to be pointing at the console
 * (issue #224). Overriding this lets such an RCD name the thing that is actually doing the
 * building, without every rcd_act() implementation needing to know it exists.
 *
 * Arguments
 * * [mob][user]- the mob credited with the build
 */
/obj/item/construction/rcd/proc/rcd_build_dir(mob/user)
	return user?.dir

/**
 * The design tree this RCD offers, in the GLOB.rcd_designs shape.
 *
 * Read instead of GLOB.rcd_designs directly so a subtype can offer blueprints the handheld
 * RCD does not: the voidcrew ship construction console builds hull-grade windows that no
 * engineer should be able to print out of a pocket device.
 */
/obj/item/construction/rcd/proc/get_rcd_designs()
	return GLOB.rcd_designs

/// Resource checks use the captured action, which may differ from the current UI selection after a delay.
/obj/item/construction/rcd/proc/check_rcd_resources(list/rcd_results, mob/user)
	return checkResource(rcd_results["cost"], user)

/obj/item/construction/rcd/proc/use_rcd_resources(list/rcd_results, mob/user)
	return useResource(rcd_results["cost"], user)

/// Applies a validated, paid-for action. Subtypes can handle successful resource recovery here.
/obj/item/construction/rcd/proc/apply_rcd_action(atom/target, mob/user, list/rcd_results)
	var/turf/location = get_turf(target)
	. = target.rcd_act(user, src, rcd_results)
	// VOIDCREW: a successful deliberate removal supersedes an old repair order.
	if(. && rcd_results["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT)
		var/obj/machinery/computer/camera_advanced/base_construction/ship/controller = SSship_repairs.area_controllers[get_area(location)]
		controller?.forget_repair_record(controller.repair_coordinate_key(location))
