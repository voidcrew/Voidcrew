/**
 * Ship Construction Drone Tools
 *
 * The ship console's drone works where the operator clicks: left-click any tile within
 * SHIP_CONSTRUCTION_DRONE_REACH of the drone to use the tool picked in the console's Tools tab,
 * right-click for that tool's removal (click handling lives in construction_console.dm).
 * Every tool is a proc here, taking the target turf and returning TRUE when it did something.
 * Location validation is ship-specific (shuttle areas + 1 adjacent tile).
 * The only HUD buttons left are Log out and Open Console.
 */

/// Base ship construction action - ships can be anywhere, not just on station z-levels
/datum/action/innate/construction/ship
	only_station_z = FALSE

/// Brings the console's window back up without leaving the drone.
/datum/action/innate/construction/ship/open_console
	name = "Open Console"
	button_icon = 'voidcrew/icons/obj/tools.dmi'
	button_icon_state = "rcd_config"

/datum/action/innate/construction/ship/open_console/Activate()
	if(..())
		return
	base_console.ui_interact(owner)

/// Balloon alert over the drone, or over the console when no drone is out.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_alert(mob/user, message)
	var/atom/anchor = eyeobj || src
	anchor.balloon_alert(user, message)

/// The console always has an RCD; the drone tools lean on it.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/check_internal_rcd()
	if(!internal_rcd)
		CRASH("Ship construction console is missing its internal RCD!")

/// Whether the drone may work on this tile: inside the ship or on a valid adjacent tile, and no blast door.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_can_work_at(mob/user, turf/target)
	if(!can_build_at(target))
		target.balloon_alert(user, "can't build there!")
		return FALSE

	// Check for blast doors - don't allow construction/deconstruction on tiles with blast doors
	for(var/obj/machinery/door/poddoor/blast_door in target)
		drone_alert(user, "blocked by blast door!")
		return FALSE

	return TRUE

/// Ship-specific RCD build
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_rcd_build(mob/user, turf/target)
	if(!drone_can_work_at(user, target))
		return FALSE
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd

	user.changeNext_move(CLICK_CD_RANGE)
	check_internal_rcd()
	if(queue_enabled || build_size > 1)
		queue_construction(target, user)
		return TRUE

	// Store turf state before building to detect if we built something new
	var/was_in_shuttle = is_in_shuttle_area(target)

	// If building outside shuttle, check dimension limits BEFORE building
	if(!was_in_shuttle)
		if(!check_expansion_dimensions(target, get_docking_port()))
			drone_alert(user, "exceeds max dimensions!")
			return FALSE

	// Check if we should use custom wall/floor building based on current RCD mode
	var/rcd_mode = ship_rcd.construction_mode

	// RCD_TURF is not one design, it is two: the plating blueprint the console's own
	// material picker covers, and the catwalk. The shortcuts below exist only to honour that
	// picker (iron/titanium/plastitanium), so they have to be gated on the plating design as
	// well as the mode - a catwalk selection falling into them silently laid a floor, or a
	// wall over the floor already there, and never a catwalk (issue #251).
	var/building_plating = (ship_rcd.rcd_design_path == /turf/open/floor/plating/rcd)

	// Space and bare hangar deck need ship flooring before walls can be built.
	var/floor_target = ship_rcd.can_build_floor(target) || (turf_build_mode == "floor" && ship_rcd.can_refloor(target))
	if(rcd_mode == RCD_TURF && building_plating && floor_target && turf_build_mode != "wall")
		if(!ship_rcd.build_floor(target, user))
			return FALSE
		playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
		// Expand shuttle if building outside
		if(!was_in_shuttle)
			expand_shuttle_to_turf(target, user)
		return TRUE

	// Build wall: RCD is in turf mode and target is any open floor (including plating)
	if(rcd_mode == RCD_TURF && building_plating && istype(target, /turf/open/floor) && turf_build_mode != "floor")
		if(!ship_rcd.build_wall(target, user))
			return FALSE
		playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
		// Expand shuttle if building outside
		if(!was_in_shuttle)
			expand_shuttle_to_turf(target, user)
		return TRUE

	// An explicit intent must not fall through to the RCD's floor/wall toggle.
	if(rcd_mode == RCD_TURF && building_plating && turf_build_mode != "auto")
		drone_alert(user, "can't build that here!")
		return FALSE

	// Hull windows: grille and window in one action, paid for out of the silo by recipe
	// rather than as generic RCD matter. Same shortcut the wall and floor pickers get.
	if(rcd_mode == RCD_WINDOWGRILLE && ship_rcd.is_hull_window(ship_rcd.rcd_design_path))
		if(!ship_rcd.build_hull_window(target, user))
			return FALSE
		playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
		// Expand shuttle if building outside
		if(!was_in_shuttle)
			expand_shuttle_to_turf(target, user)
		return TRUE

	// For other build types (catwalks, airlocks, windows, etc.), use standard RCD system
	var/atom/rcd_target = target

	// Find airlocks and other structures that can be RCD'd
	for(var/obj/S in target)
		if(LAZYLEN(S.rcd_vals(user, internal_rcd)))
			rcd_target = S

	// Check if we have enough resources before attempting to build
	var/list/rcd_results = rcd_target.rcd_vals(user, internal_rcd)
	if(!rcd_results)
		// Silence here reads as a dead button. A catwalk over an existing floor is the case
		// that gets clicked - /turf/open/floor/rcd_vals() refuses every RCD_TURF design but
		// plating - and the player has no other way to learn the blueprint does not apply.
		drone_alert(user, "can't build that here!")
		return FALSE
	var/cost = rcd_results["cost"]
	if(!internal_rcd.checkResource(cost, user))
		drone_alert(user, "not enough resources!")
		return FALSE

	// Perform the RCD action
	internal_rcd.rcd_create(rcd_target, user)
	playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Expand shuttle if building outside. Re-read the tile: rcd_create() may have replaced
	// the turf datum under us, and a catwalk leaves it space. A space turf pulled into a
	// shuttle area never gets the /turf/baseturf_skipover/shuttle stamp (dispatch() skips
	// space), so it would be silently left behind on the ship's next move.
	var/turf/built_turf = locate(target.x, target.y, target.z)
	if(!was_in_shuttle && built_turf && !isspaceturf(built_turf))
		expand_shuttle_to_turf(built_turf, user)
	else if(was_in_shuttle && built_turf && rcd_mode == RCD_AIRLOCK)
		// The overhang warning tells the operator to fit an airlock on the new outermost
		// plating - and that tile is already hull, so it never reaches
		// expand_shuttle_to_turf() and nothing would have noticed them doing it. Recheck on
		// an airlock build so following the instruction actually reseats the port, rather
		// than leaving them to work out the console's port relocator. Only on RCD_AIRLOCK:
		// no other design can produce a door for the port to sit on. door_built skips the
		// "is this tile past the port's plane" gate, because a seat on another face - which
		// the port may now turn onto - is by definition not on that plane. (issue #130)
		check_port_after_build(built_turf, user, door_built = TRUE)
	return TRUE

/// Delay to deconstruct an airlock
#define SHIP_RCD_AIRLOCK_DECONSTRUCT_DELAY (5 SECONDS)

/**
 * Ship-specific RCD deconstruct. `clicked` is what the operator clicked: a wall-mounted camera or
 * an airlock, or any RCD-able object, is taken in preference to whatever else shares the tile.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_deconstruct(mob/user, turf/target, atom/clicked)
	if(!drone_can_work_at(user, target))
		return FALSE
	var/atom/rcd_target = target
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd

	// Check for indestructible objects blocking deconstruction (blast doors, r-walls, etc.)
	for(var/obj/blocker in target)
		if(blocker.resistance_flags & INDESTRUCTIBLE)
			drone_alert(user, "blocked by [blocker.name]!")
			return FALSE

	// Also check if the turf itself is indestructible
	if(target.resistance_flags & INDESTRUCTIBLE)
		drone_alert(user, "can't deconstruct that!")
		return FALSE

	// Cameras and airlocks are removed directly; airlocks retain the console's
	// existing ability to bypass reinforcement and seals.
	var/obj/machinery/camera/target_camera
	var/obj/machinery/door/airlock/target_airlock
	if(istype(clicked, /obj/machinery/camera) && clicked.loc == target)
		target_camera = clicked
	else if(istype(clicked, /obj/machinery/door/airlock) && clicked.loc == target)
		target_airlock = clicked
	else
		target_camera = locate() in target
		target_airlock = locate() in target
	var/obj/fixture = target_camera || target_airlock
	if(fixture)
		return drone_remove_fixture(user, target, fixture)

	user.changeNext_move(CLICK_CD_RANGE)
	check_internal_rcd()

	// Select targets in demolition mode so windows and girders take priority over the floor.
	var/old_mode = ship_rcd.mode
	ship_rcd.mode = RCD_DECONSTRUCT

	// The clicked object wins when it can be taken apart; otherwise find structures that can be
	// deconstructed (wall-mounted sprites belong to the tile they stand on, so on a crowded
	// tile the operator picks by clicking).
	if(isobj(clicked) && clicked.loc == target && LAZYLEN(clicked.rcd_vals(user, internal_rcd)))
		rcd_target = clicked
	else
		for(var/obj/S in target)
			if(LAZYLEN(S.rcd_vals(user, internal_rcd)))
				rcd_target = S

	// Check if we can deconstruct this target
	var/list/rcd_results = rcd_target.rcd_vals(user, internal_rcd)
	if(!rcd_results)
		internal_rcd.mode = old_mode
		drone_alert(user, "can't deconstruct that!")
		return FALSE

	if(!ship_rcd.can_refund_materials(user))
		ship_rcd.mode = old_mode
		return FALSE

	// Perform the RCD deconstruction
	internal_rcd.rcd_create(rcd_target, user)
	playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)

	// Restore original mode
	internal_rcd.mode = old_mode

	// Clean up any empty shuttle turfs after deconstruction
	cleanup_deconstructed_turfs()
	return TRUE

/// Takes a camera or airlock down directly and refunds it to the silo.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_remove_fixture(mob/user, turf/target, obj/fixture)
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd
	user.changeNext_move(CLICK_CD_RANGE)
	check_internal_rcd()
	if(!ship_rcd.can_refund_materials(user))
		return FALSE
	var/decon_time = (istype(fixture, /obj/machinery/camera) ? SHIP_CAMERA_DECONSTRUCT_DELAY : SHIP_RCD_AIRLOCK_DECONSTRUCT_DELAY) * ship_rcd.get_build_speed_mod()
	var/obj/effect/constructing_effect/rcd_effect = new(target, decon_time, RCD_DECONSTRUCT)
	if(!ship_rcd.build_delay(user, decon_time, fixture))
		qdel(rcd_effect)
		return FALSE
	if(QDELETED(fixture) || !ship_rcd.can_refund_materials(user))
		qdel(rcd_effect)
		return FALSE
	var/list/materials = ship_rcd.get_deconstruction_materials(fixture)
	forget_repair_record(repair_coordinate_key(target))
	playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
	rcd_effect.end_animation()
	qdel(fixture)
	ship_rcd.refund_materials(materials, user)
	cleanup_deconstructed_turfs()
	return TRUE

/**
 * Where a wall fixture goes when the operator clicks `clicked`: list(open turf it stands on, dir of the wall it hangs on), or null.
 *
 * click_point is where on the tile the operator clicked, as list(x, y) in pixels from its bottom left (drone_click_point()).
 * forced_dir, when set, names the wall the fixture hangs on from the fixture's point of view: NORTH means "on the north wall",
 * like /obj/machinery/light/directional/north.
 *
 * A clicked wall is fitted on the open tile beyond one of its faces, facing back at the wall. That face is forced_dir's,
 * else the one nearest the click point, else (no click position) the one toward the drone - or the drone's own facing if it sits inside that wall.
 * A clicked open tile hangs the fixture on forced_dir's wall if one is there, else on the wall nearest the click point,
 * else (no click position) the wall the drone is facing.
 */
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_wall_mount(turf/clicked, list/click_point, forced_dir = NONE)
	if(!clicked)
		return null
	if(forced_dir && ISDIAGONALDIR(forced_dir))
		return null
	if(isclosedturf(clicked))
		if(forced_dir)
			var/turf/beyond = get_step(clicked, REVERSE_DIR(forced_dir))
			if(isopenturf(beyond) && !isspaceturf(beyond))
				return list(beyond, forced_dir)
			return null
		if(click_point)
			var/list/open_faces = list()
			for(var/face in GLOB.cardinals)
				var/turf/beyond_face = get_step(clicked, face)
				if(isopenturf(beyond_face) && !isspaceturf(beyond_face))
					open_faces += face
			// A click in the middle of a wall is a tie; the face toward the drone wins it.
			var/nearest_face = nearest_tile_edge(click_point, open_faces, clicked, eyeobj)
			if(!nearest_face)
				return null
			return list(get_step(clicked, nearest_face), REVERSE_DIR(nearest_face))
		if(!eyeobj)
			return null
		var/list/sides
		if(get_turf(eyeobj) == clicked)
			sides = list(eyeobj.dir)
		else
			var/dx = eyeobj.x - clicked.x
			var/dy = eyeobj.y - clicked.y
			var/horizontal = dx > 0 ? EAST : (dx < 0 ? WEST : NONE)
			var/vertical = dy > 0 ? NORTH : (dy < 0 ? SOUTH : NONE)
			sides = abs(dx) > abs(dy) ? list(horizontal, vertical) : list(vertical, horizontal)
			sides -= NONE
		for(var/side in sides)
			if(ISDIAGONALDIR(side))
				continue
			var/turf/open_turf = get_step(clicked, side)
			if(isopenturf(open_turf) && !isspaceturf(open_turf))
				return list(open_turf, REVERSE_DIR(side))
		return null
	if(isopenturf(clicked) && !isspaceturf(clicked))
		if(forced_dir)
			return isclosedturf(get_step(clicked, forced_dir)) ? list(clicked, forced_dir) : null
		if(click_point)
			var/list/walled_sides = list()
			for(var/wall_side in GLOB.cardinals)
				if(isclosedturf(get_step(clicked, wall_side)))
					walled_sides += wall_side
			var/nearest_wall = nearest_tile_edge(click_point, walled_sides)
			return nearest_wall ? list(clicked, nearest_wall) : null
		if(!eyeobj)
			return null
		var/wall_dir = eyeobj.dir
		if(ISDIAGONALDIR(wall_dir) || !isclosedturf(get_step(clicked, wall_dir)))
			return null
		return list(clicked, wall_dir)
	return null

/// Which of `candidates` (cardinal dirs) is nearest the click point, as list(x, y) pixels from the tile's bottom left, or NONE when there are none.
/// Ties go to the edge whose neighbouring tile (from `origin`) is nearer `prefer_near`, then to the earlier entry of GLOB.cardinals.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/nearest_tile_edge(list/click_point, list/candidates, turf/origin, atom/prefer_near)
	var/nearest = NONE
	var/nearest_distance = INFINITY
	for(var/edge in GLOB.cardinals)
		if(!(edge in candidates))
			continue
		var/distance
		switch(edge)
			if(NORTH)
				distance = ICON_SIZE_Y - click_point[2]
			if(SOUTH)
				distance = click_point[2]
			if(EAST)
				distance = ICON_SIZE_X - click_point[1]
			if(WEST)
				distance = click_point[1]
		// Click positions are whole pixels, so a bias under one only ever settles an exact tie.
		if(origin && prefer_near)
			distance += get_dist(get_step(origin, edge), prefer_near) / 100
		if(distance < nearest_distance)
			nearest = edge
			nearest_distance = distance
	return nearest

/// Ship camera build - mounts a finished camera on the wall nearest the click
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_place_camera(mob/user, turf/target, list/click_point)
	if(!drone_can_work_at(user, target))
		return FALSE
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd

	// The camera hangs on a wall like a handheld wallframe would be, so it watches the room
	// in front of that wall.
	var/list/mount = drone_wall_mount(target, click_point)
	if(!mount)
		drone_alert(user, "no wall to mount on!")
		return FALSE
	var/turf/mount_turf = mount[1]
	var/wall_dir = mount[2]
	if(!drone_can_work_at(user, mount_turf))
		return FALSE

	if(locate(/obj/machinery/camera) in mount_turf)
		drone_alert(user, "camera already here!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)
	check_internal_rcd()

	var/obj/machinery/camera/placed_camera = ship_rcd.build_camera(mount_turf, wall_dir, user)
	if(!placed_camera)
		return FALSE

	setup_placed_camera(placed_camera)
	playsound(mount_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
	return TRUE

/// Ship camera removal - takes the clicked camera, or any camera on the tile
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_remove_camera(mob/user, turf/target, atom/clicked)
	var/obj/machinery/camera/camera
	if(istype(clicked, /obj/machinery/camera) && clicked.loc == target)
		camera = clicked
	else
		camera = locate() in target
	if(!camera)
		drone_alert(user, "no camera here!")
		return FALSE
	if(!drone_can_work_at(user, target))
		return FALSE
	if(camera.resistance_flags & INDESTRUCTIBLE)
		drone_alert(user, "can't remove that!")
		return FALSE
	return drone_remove_fixture(user, target, camera)

// ============================================
// RTD (Rapid Tiling Device)
// ============================================

/// Ship RTD build - places floor tiles
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_place_tile(mob/user, turf/target)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rtd)
		drone_alert(user, "no RTD installed!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)
	return !!decorate_turf(target, user, "tile")

/// Whether the tile tool can lift the floor here: any finished floor that isn't plating, proofed or indestructible.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_can_lift_floor(turf/target)
	if(!istype(target, /turf/open/floor) || istype(target, /turf/open/floor/plating))
		return FALSE
	var/turf/open/floor/target_floor = target
	return !target_floor.rcd_proof && !(target_floor.resistance_flags & INDESTRUCTIBLE)

/// Lifts the floor tile to plating and refunds it to the silo. Returns the resulting turf, or null when nothing was lifted.
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_lift_floor(turf/target, mob/user)
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd
	if(!ship_rcd.can_refund_materials(user))
		return null
	var/list/materials = ship_rcd.get_deconstruction_materials(target)

	// Remove decals
	var/list/all_decals = list()
	for(var/obj/effect/decal in target.contents)
		all_decals += decal
	for(var/obj/effect/decal in all_decals)
		target.contents -= decal
		qdel(decal)

	// Change turf to plating
	var/original_turf_type = target.type
	var/original_layers = target.count_baseturfs()
	var/turf/new_turf
	if(target.baseturf_at_depth(1) == /turf/baseturf_bottom)
		new_turf = target.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR)
	else
		new_turf = target.ScrapeAway(flags = CHANGETURF_INHERIT_AIR)
	if(!new_turf || (new_turf.type == original_turf_type && new_turf.count_baseturfs() >= original_layers))
		return null
	ship_rcd.refund_materials(materials, user)

	playsound(new_turf, 'sound/items/deconstruct.ogg', 60, TRUE)
	return new_turf

/// Ship RTD deconstruct - removes floor tiles
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_remove_tile(mob/user, turf/target)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rtd)
		drone_alert(user, "no RTD installed!")
		return FALSE

	// Can't deconstruct plating - that's the RCD's job
	if(istype(target, /turf/open/floor/plating))
		drone_alert(user, "nothing to remove!")
		return FALSE

	if(!drone_can_lift_floor(target))
		drone_alert(user, "can't remove that!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)
	return !!drone_lift_floor(target, user)

// ============================================
// RPD (Rapid Pipe Dispenser)
// ============================================

/// Ship RPD build - places pipes
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_place_pipe(mob/user, turf/target)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rpd)
		drone_alert(user, "no RPD installed!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/pipe_dispenser/internal/rpd = internal_rpd

	// Use the RPD's interact_with_atom to handle pipe placement
	rpd.interact_with_atom(target, user)
	return TRUE

/// Ship RPD destroy - removes pipes
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_remove_pipe(mob/user, turf/target)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rpd)
		drone_alert(user, "no RPD installed!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/pipe_dispenser/rpd = internal_rpd

	// Check for placed/wrenched atmospherics pipes first
	var/obj/machinery/atmospherics/atmos_pipe = locate() in target
	if(atmos_pipe)
		// Need unwrench upgrade to remove placed pipes
		if(!(rpd.upgrade_flags & RPD_UPGRADE_UNWRENCH))
			drone_alert(user, "need unwrench upgrade!")
			return FALSE
		// Try to unwrench the pipe (converts it to an item)
		var/result = atmos_pipe.wrench_act(user, rpd)
		if(result)
			playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
			return TRUE
		drone_alert(user, "can't unwrench that!")
		return FALSE

	// Find and destroy unplaced pipe-related objects on this turf
	// Pipes are free to place and remove, so removal must not generate silo materials.
	var/destroyed_something = FALSE
	for(var/obj/item/pipe/P in target)
		qdel(P)
		destroyed_something = TRUE
		break
	if(!destroyed_something)
		for(var/obj/structure/disposalconstruct/D in target)
			qdel(D)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/c_transit_tube/T in target)
			qdel(T)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/c_transit_tube_pod/P in target)
			qdel(P)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/item/pipe_meter/M in target)
			qdel(M)
			destroyed_something = TRUE
			break
	if(!destroyed_something)
		for(var/obj/structure/disposalpipe/broken/B in target)
			qdel(B)
			destroyed_something = TRUE
			break

	if(destroyed_something)
		playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
		return TRUE
	drone_alert(user, "nothing to remove!")
	return FALSE

// ============================================
// RLD (Rapid Lighting Device)
// ============================================

/// Ship RLD build - places what the Lights tool is set to build: wall tubes and bulbs, floor lights, glow sticks
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_place_light(mob/user, turf/target, list/click_point)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rld)
		drone_alert(user, "no RLD installed!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)

	var/obj/item/construction/rld/internal/rld = internal_rld

	switch(light_build_type)
		if(SHIP_DRONE_LIGHT_GLOW) // throw glowstick
			if(!rld.check_glow_stick_materials(user))
				return FALSE
			if(!rld.use_glow_stick_materials(user))
				return FALSE
			// Create and throw glowstick
			var/obj/item/flashlight/glowstick/new_stick = new(get_turf(eyeobj))
			new_stick.color = rld.color_choice
			new_stick.set_light_color(new_stick.color)
			new_stick.throw_at(target, 9, 3, user)
			new_stick.turn_on()
			new_stick.update_brightness()
			rld.activate()
			return TRUE

		if(SHIP_DRONE_LIGHT_FLOOR)
			if(!isfloorturf(target))
				drone_alert(user, "needs a floor!")
				return FALSE
			if(locate(/obj/machinery/light/floor) in target)
				drone_alert(user, "light already there!")
				return FALSE

			if(!rld.check_floor_light_materials(user))
				return FALSE
			if(!rld.use_floor_light_materials(user))
				return FALSE

			var/obj/machinery/light/floor/FL = new(target)
			FL.color = rld.color_choice
			FL.set_light_color(rld.color_choice)
			rld.activate()
			return TRUE

		if(SHIP_DRONE_LIGHT_TUBE, SHIP_DRONE_LIGHT_BULB)
			// Wall light - on the open turf in front of the wall it hangs on
			var/list/mount = drone_wall_mount(target, click_point, light_build_dir)
			if(!mount)
				drone_alert(user, "no wall to mount on!")
				return FALSE
			var/turf/mount_turf = mount[1]
			var/wall_dir = mount[2]
			if(!drone_can_work_at(user, mount_turf))
				return FALSE

			// One wall light to a wall: floor lights and lights on the tile's other walls don't count
			for(var/obj/machinery/light/existing in mount_turf)
				if(istype(existing, /obj/machinery/light/floor) || existing.dir != wall_dir)
					continue
				drone_alert(user, "light already there!")
				return FALSE

			if(!rld.check_wall_light_materials(user))
				return FALSE
			if(!rld.use_wall_light_materials(user))
				return FALSE

			// Place wall light on the open turf, facing the wall
			var/light_path = light_build_type == SHIP_DRONE_LIGHT_BULB ? /obj/machinery/light/small : /obj/machinery/light
			var/obj/machinery/light/new_light = new light_path(mount_turf)
			new_light.setDir(wall_dir)
			new_light.color = rld.color_choice
			new_light.set_light_color(rld.color_choice)
			rld.activate()
			return TRUE

	drone_alert(user, "invalid mode!")
	return FALSE

/// Ship RLD remove - removes the clicked light, or any light on the tile
/obj/machinery/computer/camera_advanced/base_construction/ship/proc/drone_remove_light(mob/user, turf/target, atom/clicked)
	if(!drone_can_work_at(user, target))
		return FALSE

	if(!internal_rld)
		drone_alert(user, "no RLD installed!")
		return FALSE

	user.changeNext_move(CLICK_CD_RANGE)

	// Find a light fixture to remove
	var/obj/machinery/light/target_light
	if(istype(clicked, /obj/machinery/light) && clicked.loc == target)
		target_light = clicked
	else
		target_light = locate() in target
	if(!target_light)
		drone_alert(user, "no light here!")
		return FALSE

	if(target_light.resistance_flags & INDESTRUCTIBLE)
		drone_alert(user, "can't remove that!")
		return FALSE
	var/obj/item/construction/rcd/internal/ship/ship_rcd = internal_rcd
	if(!ship_rcd.can_refund_materials(user))
		return FALSE
	var/list/materials = ship_rcd.get_deconstruction_materials(target_light)

	// Remove the light
	playsound(target, 'sound/items/deconstruct.ogg', 60, TRUE)
	qdel(target_light)
	ship_rcd.refund_materials(materials, user)
	return TRUE
