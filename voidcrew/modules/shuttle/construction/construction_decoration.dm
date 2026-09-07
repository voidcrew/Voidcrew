/// Remote painter uses the normal decal picker without consuming silo materials.
/obj/item/airlock_painter/decal/ship
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console

/obj/item/airlock_painter/decal/ship/Destroy()
	ship_console = null
	return ..()

/obj/item/airlock_painter/decal/ship/ui_state(mob/user)
	return GLOB.always_state

/obj/item/airlock_painter/decal/ship/ui_status(mob/user, datum/ui_state/state)
	if(!ship_console || ship_console.current_user != user || user.remote_control != ship_console.eyeobj)
		return UI_CLOSE
	return ..()

/datum/action/innate/construction/ship/decal_configure
	name = "Configure Decal Painter"
	button_icon = 'icons/obj/devices/tool.dmi'
	button_icon_state = "decal_sprayer"

/datum/action/innate/construction/ship/decal_configure/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = base_console
	console.internal_painter?.ui_interact(owner)

/datum/action/innate/construction/ship/decal_paint
	name = "Paint Decal"
	button_icon = 'icons/obj/devices/tool.dmi'
	button_icon_state = "decal_sprayer"

/datum/action/innate/construction/ship/decal_paint/Activate()
	if(..() || !check_spot())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = base_console
	if(!console.internal_painter)
		return
	console.decorate_turf(get_turf(remote_eye), owner, "decal")

/datum/action/innate/construction/ship/decal_remove
	name = "Remove Decals"
	desc = "Remove painted floor markings without lifting the tiles."
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rtd_remove"

/datum/action/innate/construction/ship/decal_remove/Activate()
	if(..() || !check_spot())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/console = base_console
	if(!console.internal_painter)
		return
	if(!console.decorate_turf(get_turf(remote_eye), owner, "decal_remove"))
		remote_eye.balloon_alert(owner, "no decals removed!")

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/decorate_turf(turf/target, mob/user, tool_kind)
	if(!can_operate() || !is_operational || !is_crew_member(user) || !can_build_at(target))
		return FALSE
	if(queue_enabled || build_size > 1)
		return queue_construction(target, user, tool_kind)
	var/datum/ship_construction_job/job = capture_construction_job(target, user, turf_build_mode, tool_kind)
	var/success = complete_decoration_job(job, target, user)
	qdel(job)
	return success

/// Read attached decals so duplicate detection and repainting work before overlay updates.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_has_decal(turf/target, list/decal, facing)
	// BYOND canonicalizes appearance colors (e.g. #FFFFFF becomes #ffffff).
	// Compare two native appearances, rather than an appearance against raw picker strings.
	var/image/expected = image('icons/turf/decals.dmi', icon_state = decal[DECAL_INFO_ICON_STATE], dir = facing)
	expected.color = decal[DECAL_INFO_COLOR]
	expected.alpha = decal[DECAL_INFO_ALPHA]
	for(var/datum/element/decal/applied as anything in construction_floor_decals(target))
		var/mutable_appearance/overlay = applied.pic
		if(overlay.icon == expected.icon && overlay.icon_state == expected.icon_state && overlay.dir == expected.dir && overlay.color == expected.color && overlay.alpha == expected.alpha)
			return TRUE
	return FALSE

/// Mapped and painted floor markings are elements, not objects in the turf's contents.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/construction_floor_decals(turf/target)
	var/list/decals = list()
	SEND_SIGNAL(target, COMSIG_ATOM_GET_DECALS, decals)
	. = list()
	for(var/datum/element/decal/decal as anything in decals)
		if(decal.pic.icon == 'icons/turf/decals.dmi' && !decal.cleanable)
			. += decal

/obj/machinery/computer/camera_advanced/base_construction/ship/proc/complete_decoration_job(datum/ship_construction_job/job, turf/target, mob/user)
	if(!construction_job_needed(job, target))
		return FALSE
	if(job.kind == "decal_remove")
		if(!internal_painter)
			return FALSE
		for(var/datum/element/decal/decal as anything in construction_floor_decals(target))
			decal.Detach(target)
		playsound(target, 'sound/effects/spray2.ogg', 30, TRUE)
		return TRUE
	var/obj/item/construction/rcd/internal/ship/rcd = internal_rcd
	var/facing = construction_direction(job.build_dir)
	if(job.kind == "tile")
		if(!internal_rtd || !job.tile_design)
			return FALSE
		var/list/materials = list(/datum/material/iron = SHIP_RTD_TILE_IRON)
		if(!rcd.check_materials(materials, user))
			return FALSE
		// Create in nullspace so a loose stack on the floor cannot absorb the new tile.
		var/obj/item/stack/tile/tile = job.tile_design.new_tile(null, facing)
		if(!ispath(tile.turf_type) || !rcd.use_materials(materials, user))
			qdel(tile)
			return FALSE
		var/turf/built = tile.place_tile(target, user)
		if(!built)
			qdel(tile)
			rcd.refund_materials(materials, user)
			return FALSE
		for(var/list/overlay as anything in job.tile_overlays)
			built.AddElement(/datum/element/decal, overlay["icon"], overlay["state"], construction_direction(overlay["dir"]), null, null, overlay["alpha"], overlay["color"], null, FALSE, null)
		return TRUE
	if(job.kind == "decal")
		if(!internal_painter)
			return FALSE
		var/list/decal = job.decal_data
		target.AddElement(/datum/element/decal, _icon = 'icons/turf/decals.dmi', _icon_state = decal[DECAL_INFO_ICON_STATE], _dir = facing, _alpha = decal[DECAL_INFO_ALPHA], _color = decal[DECAL_INFO_COLOR], _cleanable = FALSE)
		playsound(target, 'sound/effects/spray2.ogg', 30, TRUE)
		return TRUE
	return FALSE
