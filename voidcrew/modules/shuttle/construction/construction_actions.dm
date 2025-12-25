/**
 * Ship Construction Actions
 *
 * Construction actions specific to ship construction consoles.
 * These override the standard construction actions to provide ship-specific
 * location validation (shuttle areas + 1 adjacent tile).
 */

/// Base ship construction action - overrides location checking for ship building
/datum/action/innate/construction/ship
	// Ships can be anywhere, not just station z-levels
	only_station_z = FALSE

/datum/action/innate/construction/ship/check_spot()
	var/turf/build_target = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.can_build_at(build_target))
		to_chat(owner, span_warning("You can only build within the shuttle or on valid adjacent tiles!"))
		return FALSE

	return TRUE

/// Ship-specific RCD build action
/datum/action/innate/construction/ship/build
	name = "Build"
	button_icon_state = "build"

/datum/action/innate/construction/ship/build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/atom/rcd_target = target_turf

	// Find airlocks and other structures that can be RCD'd
	for(var/obj/S in target_turf)
		if(LAZYLEN(S.rcd_vals(owner, base_console.internal_rcd)))
			rcd_target = S

	owner.changeNext_move(CLICK_CD_RANGE)
	check_rcd()

	// Check if we have enough resources before attempting to build
	var/list/rcd_results = rcd_target.rcd_vals(owner, base_console.internal_rcd)
	if(!rcd_results)
		return
	var/cost = rcd_results["cost"]
	if(!base_console.internal_rcd.checkResource(cost, owner))
		remote_eye.balloon_alert(owner, "not enough resources!")
		return

	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	// Store turf state before building to detect if we built something new
	var/was_in_shuttle = ship_console.is_in_shuttle_area(target_turf)

	// Check if this is a deconstruct action
	var/is_deconstruct = (base_console.internal_rcd.construction_mode == RCD_DECONSTRUCT)

	// If building outside shuttle, check dimension limits BEFORE building
	if(!is_deconstruct && !was_in_shuttle)
		if(!ship_console.check_expansion_dimensions(target_turf, ship_console.get_docking_port()))
			remote_eye.balloon_alert(owner, "exceeds max dimensions!")
			return

	// Perform the RCD action
	base_console.internal_rcd.rcd_create(rcd_target, owner)
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Handle post-RCD actions
	if(is_deconstruct)
		// After deconstruction, clean up any empty shuttle turfs
		ship_console.cleanup_deconstructed_turfs()
	else if(!was_in_shuttle)
		// Expand shuttle to include the new turf
		ship_console.expand_shuttle_to_turf(target_turf, owner)

/// Ship-specific RCD deconstruct action
/datum/action/innate/construction/ship/deconstruct
	name = "Deconstruct"
	button_icon = 'icons/mob/actions/actions_shuttle.dmi'
	button_icon_state = "clear_turf"

/datum/action/innate/construction/ship/deconstruct/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/atom/rcd_target = target_turf

	// Check for indestructible objects blocking deconstruction (blast doors, r-walls, etc.)
	for(var/obj/blocker in target_turf)
		if(blocker.resistance_flags & INDESTRUCTIBLE)
			remote_eye.balloon_alert(owner, "blocked by [blocker.name]!")
			return

	// Also check if the turf itself is indestructible
	if(target_turf.resistance_flags & INDESTRUCTIBLE)
		remote_eye.balloon_alert(owner, "can't deconstruct that!")
		return

	// Find structures that can be deconstructed
	for(var/obj/S in target_turf)
		if(LAZYLEN(S.rcd_vals(owner, base_console.internal_rcd)))
			rcd_target = S

	owner.changeNext_move(CLICK_CD_RANGE)
	check_rcd()

	// Temporarily set RCD to deconstruct mode
	var/old_mode = base_console.internal_rcd.mode
	base_console.internal_rcd.mode = RCD_DECONSTRUCT

	// Check if we can deconstruct this target
	var/list/rcd_results = rcd_target.rcd_vals(owner, base_console.internal_rcd)
	if(!rcd_results)
		base_console.internal_rcd.mode = old_mode
		remote_eye.balloon_alert(owner, "can't deconstruct that!")
		return

	var/cost = rcd_results["cost"]
	if(!base_console.internal_rcd.checkResource(cost, owner))
		base_console.internal_rcd.mode = old_mode
		remote_eye.balloon_alert(owner, "not enough resources!")
		return

	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	// Perform the RCD deconstruction
	base_console.internal_rcd.rcd_create(rcd_target, owner)
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Restore original mode
	base_console.internal_rcd.mode = old_mode

	// Clean up any empty shuttle turfs after deconstruction
	ship_console.cleanup_deconstructed_turfs()

/// Ship-specific RCD configure action
/datum/action/innate/construction/ship/configure_mode
	name = "Configure RCD"
	button_icon = 'icons/obj/tools.dmi'
	button_icon_state = "rcd"

/datum/action/innate/construction/ship/configure_mode/Activate()
	if(..())
		return
	check_rcd()
	base_console.internal_rcd.owner = base_console
	base_console.internal_rcd.ui_interact(owner)
