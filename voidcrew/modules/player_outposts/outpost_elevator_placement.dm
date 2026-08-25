/**
 * # Outpost Hangar Elevator Placement
 *
 * Construction-console workflow that lets a player outpost install the hangar
 * elevator used by trader outposts. Three drone actions:
 *
 * - Plan: projects a survey-console-style overlay of the elevator kit under the
 *   drone, a 3x3 alcove, a 3-tile backing wall and a ghost of the wall panel.
 *   Tinted green/red per tile as the drone moves.
 * - Rotate: turns the kit so the panel wall faces another side.
 * - Confirm: stamps the kit down, overwriting the turfs and clearing anchored
 *   obstructions, then wires the panel and alcove into the outpost.
 *
 * Once installed, visiting ships are allocated per-ship hangar berths (see
 * outpost_hangar.dm) instead of the outpost's two reserve pads, the elevator
 * connects the concourse to every berth, exactly like the trader outposts.
 */

/// Side length of the elevator alcove (matches the hangar template's 3x3 alcove)
#define ELEVATOR_ALCOVE_SIZE 3

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost
	/// Whether the elevator blueprint overlay is currently projected
	var/elevator_planning = FALSE
	/// Side of the alcove the panel wall sits on (rotated by the Rotate action)
	var/elevator_preview_dir = NORTH
	/// Live blueprint overlay images (shown to current_user while planning)
	var/list/elevator_preview_images

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/populate_actions_list()
	..()
	actions += new /datum/action/innate/construction/ship/elevator_plan(src)
	actions += new /datum/action/innate/construction/ship/elevator_rotate(src)
	actions += new /datum/action/innate/construction/ship/elevator_confirm(src)

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/remove_eye_control(mob/living/user)
	stop_elevator_planning()
	return ..()

// ===== BLUEPRINT PREVIEW =====

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/start_elevator_planning()
	if(elevator_planning || !eyeobj)
		return
	elevator_planning = TRUE
	RegisterSignal(eyeobj, COMSIG_MOVABLE_MOVED, PROC_REF(on_elevator_eye_moved))
	update_elevator_preview()

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/stop_elevator_planning()
	if(!elevator_planning)
		return
	elevator_planning = FALSE
	if(eyeobj)
		UnregisterSignal(eyeobj, COMSIG_MOVABLE_MOVED)
	clear_elevator_preview()

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/on_elevator_eye_moved(datum/source)
	SIGNAL_HANDLER
	update_elevator_preview()

/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/clear_elevator_preview()
	if(length(elevator_preview_images) && current_user?.client)
		current_user.client.images -= elevator_preview_images
	elevator_preview_images = null

/**
 * Rebuilds the blueprint overlay at the drone's position: green/red validity
 * tint per tile (alcove faint, wall row strong) plus a ghost of the panel.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/update_elevator_preview()
	clear_elevator_preview()
	if(!elevator_planning || !current_user?.client)
		return
	var/list/footprint = get_elevator_footprint(get_turf(eyeobj), elevator_preview_dir)
	if(!footprint)
		return
	elevator_preview_images = list()
	for(var/turf/alcove_turf as anything in footprint["alcove"])
		elevator_preview_images += make_elevator_preview_image(alcove_turf, 110)
	for(var/turf/wall_turf as anything in footprint["wall"])
		elevator_preview_images += make_elevator_preview_image(wall_turf, 200)
	// Ghost of the panel itself so the orientation is readable at a glance
	var/turf/panel_turf = footprint["panel"]
	var/image/panel_ghost = image('icons/obj/wallmounts.dmi', panel_turf, "elevpanel0")
	panel_ghost.dir = elevator_preview_dir
	switch(elevator_preview_dir)
		if(NORTH)
			panel_ghost.pixel_y = 32
		if(SOUTH)
			panel_ghost.pixel_y = -32
		if(EAST)
			panel_ghost.pixel_x = 32
		if(WEST)
			panel_ghost.pixel_x = -32
	panel_ghost.alpha = 200
	panel_ghost.layer = NAVIGATION_EYE_LAYER
	SET_PLANE_EXPLICIT(panel_ghost, ABOVE_GAME_PLANE, panel_turf)
	panel_ghost.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	elevator_preview_images += panel_ghost
	current_user.client.images += elevator_preview_images

/// One validity-tinted overlay tile of the blueprint
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/make_elevator_preview_image(turf/tile, tile_alpha)
	var/image/tile_image = image('icons/effects/alphacolors.dmi', tile, is_elevator_turf_clear(tile) ? "green" : "red")
	tile_image.alpha = tile_alpha
	tile_image.layer = NAVIGATION_EYE_LAYER
	SET_PLANE_EXPLICIT(tile_image, ABOVE_GAME_PLANE, tile)
	tile_image.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	return tile_image

// ===== FOOTPRINT =====

/**
 * The elevator kit's footprint with its alcove centered on the given turf:
 * list("alcove" = 9 turfs in block() order, "wall" = 3 turfs on the panel_side
 * edge, "panel" = the alcove tile the panel spawns on). Null if any of it runs
 * off the map.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/get_elevator_footprint(turf/center, panel_side)
	if(!center)
		return null
	var/turf/alcove_bottom_left = locate(center.x - 1, center.y - 1, center.z)
	var/turf/alcove_top_right = locate(center.x + 1, center.y + 1, center.z)
	if(!alcove_bottom_left || !alcove_top_right)
		return null
	// block() order here matches the hangar template's alcove scan order, so
	// the elevator's tile-for-tile ride mapping lines up across floors
	var/list/turf/alcove_turfs = block(alcove_bottom_left, alcove_top_right)
	if(length(alcove_turfs) != ELEVATOR_ALCOVE_SIZE * ELEVATOR_ALCOVE_SIZE)
		return null
	var/list/turf/wall_turfs = list()
	for(var/offset in -1 to 1)
		var/turf/wall_turf
		switch(panel_side)
			if(NORTH)
				wall_turf = locate(center.x + offset, center.y + 2, center.z)
			if(SOUTH)
				wall_turf = locate(center.x + offset, center.y - 2, center.z)
			if(EAST)
				wall_turf = locate(center.x + 2, center.y + offset, center.z)
			if(WEST)
				wall_turf = locate(center.x - 2, center.y + offset, center.z)
		if(!wall_turf)
			return null
		wall_turfs += wall_turf
	return list(
		"alcove" = alcove_turfs,
		"wall" = wall_turfs,
		"panel" = get_step(center, panel_side),
	)

/**
 * Whether the kit may overwrite this tile: inside the build region, no living
 * mobs, and none of the machinery the outpost cannot function without.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/is_elevator_turf_clear(turf/tile)
	if(!tile || !outpost?.is_turf_buildable(tile))
		return FALSE
	if(locate(/mob/living) in tile)
		return FALSE
	if(locate(/obj/docking_port) in tile)
		return FALSE
	for(var/obj/machinery/computer/console in tile)
		if(console == src || istype(console, /obj/machinery/computer/player_outpost_management))
			return FALSE
	return TRUE

// ===== PLACEMENT =====

/// Validates the blueprint at the drone's current spot and stamps it if clear.
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/try_place_elevator(mob/user)
	if(!elevator_planning)
		eyeobj?.balloon_alert(user, "no elevator blueprint active!")
		return FALSE
	if(!outpost)
		return FALSE
	var/list/footprint = get_elevator_footprint(get_turf(eyeobj), elevator_preview_dir)
	if(!footprint)
		eyeobj.balloon_alert(user, "invalid position!")
		return FALSE
	for(var/turf/tile as anything in (footprint["alcove"] + footprint["wall"]))
		if(!is_elevator_turf_clear(tile))
			eyeobj.balloon_alert(user, "position obstructed!")
			return FALSE
	build_elevator(footprint, user)
	return TRUE

/**
 * Stamps the elevator kit: replaces any previous elevator, overwrites the
 * footprint turfs (clearing anchored/dense obstructions), spawns the wall
 * panel and wires it all into the outpost. From here on visiting ships get
 * hangar berths (see player_outpost ship_act).
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/build_elevator(list/footprint, mob/user)
	// The concourse supports exactly one elevator: re-placing moves it
	var/replacing = length(outpost.lobby_panels)
	for(var/obj/machinery/outpost_elevator/old_panel as anything in outpost.lobby_panels.Copy())
		qdel(old_panel)
	// Revert the old footprint back to bare plating so a relocated elevator
	// doesn't leave its old floor/wall behind
	for(var/turf/old_turf as anything in (outpost.lobby_alcove_turfs + outpost.lobby_wall_turfs))
		old_turf.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR)
	outpost.lobby_alcove_turfs.Cut()
	outpost.lobby_wall_turfs.Cut()

	for(var/turf/wall_turf as anything in footprint["wall"])
		clear_elevator_obstructions(wall_turf)
		wall_turf.ChangeTurf(/turf/closed/wall/mineral/titanium, flags = CHANGETURF_INHERIT_AIR)
	for(var/turf/alcove_turf as anything in footprint["alcove"])
		clear_elevator_obstructions(alcove_turf)
		alcove_turf.ChangeTurf(/turf/open/floor/light, flags = CHANGETURF_INHERIT_AIR)

	var/panel_type
	switch(elevator_preview_dir)
		if(SOUTH)
			panel_type = /obj/machinery/outpost_elevator/directional/south
		if(EAST)
			panel_type = /obj/machinery/outpost_elevator/directional/east
		if(WEST)
			panel_type = /obj/machinery/outpost_elevator/directional/west
		else
			panel_type = /obj/machinery/outpost_elevator/directional/north
	var/obj/machinery/outpost_elevator/panel = new panel_type(footprint["panel"])
	panel.outpost = outpost
	panel.is_lobby = TRUE
	outpost.lobby_panels += panel
	outpost.lobby_alcove_turfs = footprint["alcove"]
	outpost.lobby_wall_turfs = footprint["wall"]
	if(!outpost.berths)
		outpost.berths = new /list(OUTPOST_MAX_BERTHS)
	outpost.refresh_elevator_uis()

	playsound(footprint["panel"], 'sound/machines/ding.ogg', 60, TRUE)
	to_chat(user, span_notice("Hangar elevator [replacing ? "relocated" : "installed"]. Visiting ships will now be assigned hangar berths connected to the concourse."))
	log_shuttle("PLAYER OUTPOST: [key_name(user)] [replacing ? "relocated" : "installed"] the hangar elevator at '[outpost.name]'")
	stop_elevator_planning()

/// Sweeps a footprint tile of everything the new turf would trap or that would
/// block the alcove: anchored or dense non-mob movables. Loose items survive.
/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/proc/clear_elevator_obstructions(turf/tile)
	for(var/atom/movable/obstruction in tile.contents.Copy())
		if(ismob(obstruction))
			continue
		if(obstruction.anchored || obstruction.density)
			qdel(obstruction)

// ===== DRONE ACTIONS =====

/datum/action/innate/construction/ship/elevator_plan
	name = "Plan Hangar Elevator"
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_zoom_off"

/datum/action/innate/construction/ship/elevator_plan/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = base_console
	if(!istype(console) || !console.outpost)
		return
	if(console.elevator_planning)
		console.stop_elevator_planning()
		remote_eye.balloon_alert(owner, "elevator blueprint cleared")
	else
		console.start_elevator_planning()
		remote_eye.balloon_alert(owner, "elevator blueprint projected")

/datum/action/innate/construction/ship/elevator_rotate
	name = "Rotate Elevator Blueprint"
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_cycle_equip_off"

/datum/action/innate/construction/ship/elevator_rotate/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = base_console
	if(!istype(console))
		return
	if(!console.elevator_planning)
		remote_eye.balloon_alert(owner, "no elevator blueprint active!")
		return
	console.elevator_preview_dir = turn(console.elevator_preview_dir, -90)
	console.update_elevator_preview()
	remote_eye.balloon_alert(owner, "panel wall: [dir2text(console.elevator_preview_dir)]")

/datum/action/innate/construction/ship/elevator_confirm
	name = "Confirm Elevator Placement"
	button_icon = 'icons/mob/actions/actions_construction.dmi'
	button_icon_state = "build"

/datum/action/innate/construction/ship/elevator_confirm/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/console = base_console
	if(!istype(console))
		return
	console.try_place_elevator(owner)

#undef ELEVATOR_ALCOVE_SIZE
