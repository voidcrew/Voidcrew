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

	// Check for blast doors - don't allow construction/deconstruction on tiles with blast doors
	for(var/obj/machinery/door/poddoor/blast_door in build_target)
		remote_eye.balloon_alert(owner, "blocked by blast door!")
		return FALSE

	return TRUE

/// Ship-specific RCD build action
/datum/action/innate/construction/ship/build
	name = "RCD Build"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rcd_construct"

/datum/action/innate/construction/ship/build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console
	var/obj/item/construction/rcd/internal/ship/ship_rcd = base_console.internal_rcd

	owner.changeNext_move(CLICK_CD_RANGE)
	check_rcd()

	// Store turf state before building to detect if we built something new
	var/was_in_shuttle = ship_console.is_in_shuttle_area(target_turf)

	// If building outside shuttle, check dimension limits BEFORE building
	if(!was_in_shuttle)
		if(!ship_console.check_expansion_dimensions(target_turf, ship_console.get_docking_port()))
			remote_eye.balloon_alert(owner, "exceeds max dimensions!")
			return

	// Check if we should use custom wall/floor building based on current RCD mode
	var/rcd_mode = ship_rcd.construction_mode

	// RCD_TURF is not one design, it is two: the plating blueprint the console's own
	// material picker covers, and the catwalk. The shortcuts below exist only to honour that
	// picker (iron/titanium/plastitanium), so they have to be gated on the plating design as
	// well as the mode - a catwalk selection falling into them silently laid a floor, or a
	// wall over the floor already there, and never a catwalk (issue #251).
	var/building_plating = (ship_rcd.rcd_design_path == /turf/open/floor/plating/rcd)

	// Build floor: RCD is in turf mode and target is space (need to create floor first)
	if(rcd_mode == RCD_TURF && building_plating && isspaceturf(target_turf))
		if(!ship_rcd.build_floor(target_turf, owner))
			return
		playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
		// Expand shuttle if building outside
		if(!was_in_shuttle)
			ship_console.expand_shuttle_to_turf(target_turf, owner)
		return

	// Build wall: RCD is in turf mode and target is any open floor (including plating)
	if(rcd_mode == RCD_TURF && building_plating && istype(target_turf, /turf/open/floor))
		if(!ship_rcd.build_wall(target_turf, owner))
			return
		playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
		// Expand shuttle if building outside
		if(!was_in_shuttle)
			ship_console.expand_shuttle_to_turf(target_turf, owner)
		return

	// For other build types (catwalks, airlocks, windows, etc.), use standard RCD system
	var/atom/rcd_target = target_turf

	// Find airlocks and other structures that can be RCD'd
	for(var/obj/S in target_turf)
		if(LAZYLEN(S.rcd_vals(owner, base_console.internal_rcd)))
			rcd_target = S

	// Check if we have enough resources before attempting to build
	var/list/rcd_results = rcd_target.rcd_vals(owner, base_console.internal_rcd)
	if(!rcd_results)
		// Silence here reads as a dead button. A catwalk over an existing floor is the case
		// that gets clicked - /turf/open/floor/rcd_vals() refuses every RCD_TURF design but
		// plating - and the player has no other way to learn the blueprint does not apply.
		remote_eye.balloon_alert(owner, "can't build that here!")
		return
	var/cost = rcd_results["cost"]
	if(!base_console.internal_rcd.checkResource(cost, owner))
		remote_eye.balloon_alert(owner, "not enough resources!")
		return

	// Perform the RCD action
	base_console.internal_rcd.rcd_create(rcd_target, owner)
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Expand shuttle if building outside. Re-read the tile: rcd_create() may have replaced
	// the turf datum under us, and a catwalk leaves it space. A space turf pulled into a
	// shuttle area never gets the /turf/baseturf_skipover/shuttle stamp (dispatch() skips
	// space), so it would be silently left behind on the ship's next move.
	var/turf/built_turf = locate(target_turf.x, target_turf.y, target_turf.z)
	if(!was_in_shuttle && built_turf && !isspaceturf(built_turf))
		ship_console.expand_shuttle_to_turf(built_turf, owner)
	else if(was_in_shuttle && built_turf && rcd_mode == RCD_AIRLOCK)
		// The overhang warning tells the operator to fit an airlock on the new outermost
		// plating - and that tile is already hull, so it never reaches
		// expand_shuttle_to_turf() and nothing would have noticed them doing it. Recheck on
		// an airlock build so following the instruction actually reseats the port, rather
		// than leaving them to work out the console's port relocator. Only on RCD_AIRLOCK:
		// no other design can produce a door for the port to sit on. door_built skips the
		// "is this tile past the port's plane" gate, because a seat on another face - which
		// the port may now turn onto - is by definition not on that plane. (issue #130)
		ship_console.check_port_after_build(built_turf, owner, door_built = TRUE)

/// Ship-specific RCD deconstruct action
/datum/action/innate/construction/ship/deconstruct
	name = "Deconstruct"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rcd_remove"

/// Base cost to deconstruct an airlock (standard RCD cost, before the ship
/// deconstruction discount in deconstruct_cost() is applied)
#define SHIP_RCD_AIRLOCK_DECONSTRUCT_COST 32
/// Delay to deconstruct an airlock
#define SHIP_RCD_AIRLOCK_DECONSTRUCT_DELAY (5 SECONDS)

/datum/action/innate/construction/ship/deconstruct/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/atom/rcd_target = target_turf
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	// Check for indestructible objects blocking deconstruction (blast doors, r-walls, etc.)
	for(var/obj/blocker in target_turf)
		if(blocker.resistance_flags & INDESTRUCTIBLE)
			remote_eye.balloon_alert(owner, "blocked by [blocker.name]!")
			return

	// Also check if the turf itself is indestructible
	if(target_turf.resistance_flags & INDESTRUCTIBLE)
		remote_eye.balloon_alert(owner, "can't deconstruct that!")
		return

	// Special handling for cameras - cut them off the wall, no material cost
	var/obj/machinery/camera/target_camera = locate() in target_turf
	if(target_camera)
		owner.changeNext_move(CLICK_CD_RANGE)
		check_rcd()

		// Show deconstruction effect
		var/obj/effect/constructing_effect/camera_rcd_effect = new(target_turf, SHIP_CAMERA_DECONSTRUCT_DELAY, RCD_DECONSTRUCT)

		// Delay for deconstruction
		if(!base_console.internal_rcd.build_delay(owner, SHIP_CAMERA_DECONSTRUCT_DELAY, target_camera))
			qdel(camera_rcd_effect)
			return

		// Remove the camera (cameranet cleanup happens in its Destroy)
		playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
		qdel(target_camera)

		// Clean up any empty shuttle turfs after deconstruction
		ship_console.cleanup_deconstructed_turfs()
		return

	// Special handling for airlocks - bypass reinforcement/seal checks for remote construction
	var/obj/machinery/door/airlock/target_airlock = locate() in target_turf
	if(target_airlock)
		owner.changeNext_move(CLICK_CD_RANGE)
		check_rcd()

		// This branch charges directly rather than going through rcd_create(), so it
		// never sets RCD_DECONSTRUCT mode - apply the deconstruction discount by hand.
		var/obj/item/construction/rcd/internal/ship/ship_rcd = base_console.internal_rcd
		var/airlock_cost = ship_rcd.deconstruct_cost(SHIP_RCD_AIRLOCK_DECONSTRUCT_COST)

		// Check resources
		if(!ship_rcd.checkResource(airlock_cost, owner))
			remote_eye.balloon_alert(owner, "not enough resources!")
			return

		// Say what the tear-out costs before it happens
		remote_eye.balloon_alert(owner, "cost: [ship_rcd.charge_readout(airlock_cost)]")

		// Show construction effect
		var/obj/effect/constructing_effect/rcd_effect = new(target_turf, SHIP_RCD_AIRLOCK_DECONSTRUCT_DELAY, RCD_DECONSTRUCT)

		// Delay for deconstruction
		if(!ship_rcd.build_delay(owner, SHIP_RCD_AIRLOCK_DECONSTRUCT_DELAY, target_airlock))
			qdel(rcd_effect)
			return

		// Use resources after delay
		if(!ship_rcd.useResource(airlock_cost, owner))
			qdel(rcd_effect)
			remote_eye.balloon_alert(owner, "not enough resources!")
			return

		// Remove the airlock
		playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
		rcd_effect.end_animation()
		qdel(target_airlock)

		// Clean up any empty shuttle turfs after deconstruction
		ship_console.cleanup_deconstructed_turfs()
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

	// Say what the tear-out costs before it happens. useResource() applies the
	// deconstruction discount itself, so mirror it here for an honest number.
	var/obj/item/construction/rcd/internal/ship/decon_rcd = base_console.internal_rcd
	if(istype(decon_rcd))
		remote_eye.balloon_alert(owner, "cost: [decon_rcd.charge_readout(decon_rcd.deconstruct_cost(cost))]")

	// Perform the RCD deconstruction
	base_console.internal_rcd.rcd_create(rcd_target, owner)
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Restore original mode
	base_console.internal_rcd.mode = old_mode

	// Clean up any empty shuttle turfs after deconstruction
	ship_console.cleanup_deconstructed_turfs()

/// Ship camera build action - mounts a finished camera on the wall the drone faces
/datum/action/innate/construction/ship/camera_build
	name = "Place Camera"
	button_icon = 'icons/obj/machines/camera.dmi'
	button_icon_state = "camera"

/datum/action/innate/construction/ship/camera_build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console
	var/obj/item/construction/rcd/internal/ship/ship_rcd = base_console.internal_rcd

	// The camera goes on the drone's own turf, hung on the wall the drone is facing,
	// so it watches the room the drone is in (mirrors handheld wallframe placement).
	if(!istype(target_turf, /turf/open) || isspaceturf(target_turf))
		remote_eye.balloon_alert(owner, "need open floor!")
		return

	var/wall_dir = remote_eye.dir
	if(ISDIAGONALDIR(wall_dir) || !isclosedturf(get_step(target_turf, wall_dir)))
		remote_eye.balloon_alert(owner, "face an adjacent wall!")
		return

	if(locate(/obj/machinery/camera) in target_turf)
		remote_eye.balloon_alert(owner, "camera already here!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)
	check_rcd()

	var/obj/machinery/camera/placed_camera = ship_rcd.build_camera(target_turf, wall_dir, owner)
	if(!placed_camera)
		return

	ship_console.setup_placed_camera(placed_camera)
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

/// Ship-specific RCD configure action
/datum/action/innate/construction/ship/configure_mode
	name = "Configure RCD"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rcd_config"

/datum/action/innate/construction/ship/configure_mode/Activate()
	if(..())
		return
	check_rcd()
	base_console.internal_rcd.owner = base_console
	base_console.internal_rcd.ui_interact(owner)

// ============================================
// RTD (Rapid Tiling Device) Actions
// ============================================

/// Ship RTD configure action - opens tile selection UI
/datum/action/innate/construction/ship/rtd_configure
	name = "Configure Tiles"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rtd_config"

/datum/action/innate/construction/ship/rtd_configure/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console
	if(!ship_console.internal_rtd)
		remote_eye.balloon_alert(owner, "no RTD installed!")
		return
	// Open the RTD UI directly (bypass attack_self which has proximity checks)
	ship_console.internal_rtd.ui_interact(owner)

/// Ship RTD build action - places floor tiles
/datum/action/innate/construction/ship/rtd_build
	name = "Place Tile"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rtd_construct"

/datum/action/innate/construction/ship/rtd_build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rtd)
		remote_eye.balloon_alert(owner, "no RTD installed!")
		return

	var/obj/item/construction/rtd/internal/rtd = ship_console.internal_rtd

	// RTD can only tile on plating
	if(!istype(target_turf, /turf/open/floor/plating))
		remote_eye.balloon_alert(owner, "need plating!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	// Check and use silo materials
	if(!rtd.check_tile_materials(owner))
		return
	if(!rtd.use_tile_materials(owner))
		return

	// Create and place the tile
	var/obj/item/stack/tile/final_tile = rtd.selected_design.new_tile(target_turf, rtd.selected_direction)
	if(QDELETED(final_tile))
		remote_eye.balloon_alert(owner, "tile creation failed!")
		return

	var/turf/open/new_turf = final_tile.place_tile(target_turf, owner)
	if(new_turf)
		// Apply any saved overlays
		for(var/datum/overlay_info/info in rtd.design_overlays)
			info.add_decal(new_turf)

	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

/// Ship RTD deconstruct action - removes floor tiles
/datum/action/innate/construction/ship/rtd_deconstruct
	name = "Remove Tile"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rtd_remove"

/datum/action/innate/construction/ship/rtd_deconstruct/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rtd)
		remote_eye.balloon_alert(owner, "no RTD installed!")
		return

	// Can't deconstruct plating - that's the RCD's job
	if(istype(target_turf, /turf/open/floor/plating))
		remote_eye.balloon_alert(owner, "nothing to remove!")
		return

	if(!istype(target_turf, /turf/open/floor))
		remote_eye.balloon_alert(owner, "can't remove that!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	// Tile deconstruction is free (no silo materials needed)

	// Remove decals
	var/list/all_decals = list()
	for(var/obj/effect/decal in target_turf.contents)
		all_decals += decal
	for(var/obj/effect/decal in all_decals)
		target_turf.contents -= decal
		qdel(decal)

	// Change turf to plating
	if(target_turf.baseturf_at_depth(1) == /turf/baseturf_bottom)
		target_turf.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR)
	else
		target_turf.ScrapeAway(flags = CHANGETURF_INHERIT_AIR)

	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)

// ============================================
// RPD (Rapid Pipe Dispenser) Actions
// ============================================

/// Ship RPD configure action - opens pipe selection UI
/datum/action/innate/construction/ship/rpd_configure
	name = "Configure Pipes"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rpd_config"

/datum/action/innate/construction/ship/rpd_configure/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console
	if(!ship_console.internal_rpd)
		remote_eye.balloon_alert(owner, "no RPD installed!")
		return
	// Open the RPD UI directly (bypass attack_self which has proximity checks)
	ship_console.internal_rpd.ui_interact(owner)

/// Ship RPD build action - places pipes
/datum/action/innate/construction/ship/rpd_build
	name = "Place Pipe"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rpd_construct"

/datum/action/innate/construction/ship/rpd_build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rpd)
		remote_eye.balloon_alert(owner, "no RPD installed!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/pipe_dispenser/internal/rpd = ship_console.internal_rpd

	// Check and use silo materials before placing pipe
	if(!rpd.check_pipe_materials(owner))
		return
	if(!rpd.use_pipe_materials(owner))
		return

	// Use the RPD's interact_with_atom to handle pipe placement
	rpd.interact_with_atom(target_turf, owner)

/// Ship RPD destroy action - removes pipes
/datum/action/innate/construction/ship/rpd_destroy
	name = "Remove Pipe"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rpd_remove"

/datum/action/innate/construction/ship/rpd_destroy/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rpd)
		remote_eye.balloon_alert(owner, "no RPD installed!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/pipe_dispenser/rpd = ship_console.internal_rpd

	// Check for placed/wrenched atmospherics pipes first
	var/obj/machinery/atmospherics/atmos_pipe = locate() in target_turf
	if(atmos_pipe)
		// Need unwrench upgrade to remove placed pipes
		if(!(rpd.upgrade_flags & RPD_UPGRADE_UNWRENCH))
			remote_eye.balloon_alert(owner, "need unwrench upgrade!")
			return
		// Try to unwrench the pipe (converts it to an item)
		var/result = atmos_pipe.wrench_act(owner, rpd)
		if(result)
			playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
		else
			remote_eye.balloon_alert(owner, "can't unwrench that!")
		return

	// Find and destroy unplaced pipe-related objects on this turf
	var/destroyed_something = FALSE
	for(var/obj/item/pipe/P in target_turf)
		qdel(P)
		destroyed_something = TRUE
		break
	if(!destroyed_something)
		for(var/obj/structure/disposalconstruct/D in target_turf)
			qdel(D)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/c_transit_tube/T in target_turf)
			qdel(T)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/c_transit_tube_pod/P in target_turf)
			qdel(P)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/item/pipe_meter/M in target_turf)
			qdel(M)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/disposalpipe/broken/B in target_turf)
			qdel(B)
			destroyed_something = TRUE
			break

	if(destroyed_something)
		playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
	else
		remote_eye.balloon_alert(owner, "nothing to remove!")

// ============================================
// RLD (Rapid Lighting Device) Actions
// ============================================

/// Ship RLD color picker action - opens color selection directly
/datum/action/innate/construction/ship/rld_color
	name = "Light Color"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rld_config"

/datum/action/innate/construction/ship/rld_color/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console
	if(!ship_console.internal_rld)
		remote_eye.balloon_alert(owner, "no RLD installed!")
		return

	var/obj/item/construction/rld/rld = ship_console.internal_rld
	var/new_color = input(owner, "Choose light color", "Light Color", rld.color_choice) as color|null
	if(new_color == null)
		return

	rld.color_choice = new_color
	remote_eye.balloon_alert(owner, "color set")

/// Ship RLD build action - places lights using drone direction for wall lights
/datum/action/innate/construction/ship/rld_build
	name = "Place Light"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rld_construct"

/datum/action/innate/construction/ship/rld_build/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rld)
		remote_eye.balloon_alert(owner, "no RLD installed!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/construction/rld/internal/rld = ship_console.internal_rld

	// RLD mode: 1 = GLOW_MODE, 2 = LIGHT_MODE
	switch(rld.mode)
		if(1) // GLOW_MODE - throw glowstick
			if(!rld.check_glow_stick_materials(owner))
				return
			if(!rld.use_glow_stick_materials(owner))
				return
			// Create and throw glowstick
			var/obj/item/flashlight/glowstick/new_stick = new(get_turf(remote_eye))
			new_stick.color = rld.color_choice
			new_stick.set_light_color(new_stick.color)
			new_stick.throw_at(target_turf, 9, 3, owner)
			new_stick.turn_on()
			new_stick.update_brightness()
			rld.activate()

		if(2) // LIGHT_MODE - place fixture
			if(iswallturf(target_turf))
				// Wall light - use drone's facing direction
				var/drone_dir = remote_eye.dir
				var/turf/light_turf = get_step(target_turf, drone_dir)

				// Check if the target turf is valid for a light
				if(!light_turf || iswallturf(light_turf) || isspaceturf(light_turf))
					remote_eye.balloon_alert(owner, "can't place light there!")
					return

				// Check for existing light
				if(locate(/obj/machinery/light) in light_turf)
					remote_eye.balloon_alert(owner, "light already there!")
					return

				if(!rld.check_wall_light_materials(owner))
					return
				if(!rld.use_wall_light_materials(owner))
					return

				// Place wall light on the open turf, facing the wall
				var/obj/machinery/light/L = new(light_turf)
				L.setDir(get_dir(light_turf, target_turf))
				L.color = rld.color_choice
				L.set_light_color(rld.color_choice)
				rld.activate()

			else if(isfloorturf(target_turf))
				// Floor light
				if(locate(/obj/machinery/light/floor) in target_turf)
					remote_eye.balloon_alert(owner, "light already there!")
					return

				if(!rld.check_floor_light_materials(owner))
					return
				if(!rld.use_floor_light_materials(owner))
					return

				var/obj/machinery/light/floor/FL = new(target_turf)
				FL.color = rld.color_choice
				FL.set_light_color(rld.color_choice)
				rld.activate()
			else
				remote_eye.balloon_alert(owner, "can't place light here!")

		else
			remote_eye.balloon_alert(owner, "invalid mode!")

/// Ship RLD remove action - removes lights
/datum/action/innate/construction/ship/rld_remove
	name = "Remove Light"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rld_remove"

/datum/action/innate/construction/ship/rld_remove/Activate()
	if(..())
		return
	if(!check_spot())
		return
	var/turf/target_turf = get_turf(remote_eye)
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	if(!ship_console.internal_rld)
		remote_eye.balloon_alert(owner, "no RLD installed!")
		return

	owner.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/construction/rld/rld = ship_console.internal_rld

	// Find a light fixture to remove
	var/obj/machinery/light/target_light = locate() in target_turf
	if(!target_light)
		remote_eye.balloon_alert(owner, "no light here!")
		return

	// Check resources (deconstruction costs 10 matter)
	if(!rld.checkResource(10, owner))
		remote_eye.balloon_alert(owner, "not enough resources!")
		return

	// Use resources
	if(!rld.useResource(10, owner))
		remote_eye.balloon_alert(owner, "not enough resources!")
		return

	// Remove the light
	playsound(target_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
	qdel(target_light)

// ============================================
// T-Ray Scanner Actions
// ============================================

/// Ship T-ray toggle action - cycles through scanner modes
/datum/action/innate/construction/ship/tray_toggle
	name = "Toggle Scanner"
	button_icon = 'icons/obj/devices/scanner.dmi'
	button_icon_state = "t-ray0"

/datum/action/innate/construction/ship/tray_toggle/Activate()
	if(..())
		return
	var/obj/machinery/computer/camera_advanced/base_construction/ship/ship_console = base_console

	// Cycle through modes: off -> t-ray -> pipe -> thermal -> off
	switch(ship_console.tray_mode)
		if(SHIP_TRAY_MODE_OFF)
			ship_console.tray_mode = SHIP_TRAY_MODE_TRAY
			remote_eye.balloon_alert(owner, "T-ray mode")
		if(SHIP_TRAY_MODE_TRAY)
			ship_console.tray_mode = SHIP_TRAY_MODE_PIPE
			remote_eye.balloon_alert(owner, "pipe connections mode")
		if(SHIP_TRAY_MODE_PIPE)
			ship_console.tray_mode = SHIP_TRAY_MODE_THERMAL
			remote_eye.balloon_alert(owner, "thermal mode")
		if(SHIP_TRAY_MODE_THERMAL)
			ship_console.tray_mode = SHIP_TRAY_MODE_OFF
			ship_console.tray_connection_images.Cut()
			remote_eye.balloon_alert(owner, "scanner off")
