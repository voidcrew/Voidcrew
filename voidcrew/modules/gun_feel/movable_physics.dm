/**
 * Movable physics
 *
 * Ported from Shiptest (shiptest-ss13/Shiptest, code/datums/components/movable_physics.dm and
 * code/controllers/subsystem/processing/movable_physics.dm), AGPL-3.0 like this codebase.
 *
 * Throws a movable along the floor by its pixel offsets: it arcs up on pixel_z under gravity,
 * bounces, slides to a stop, and steps into the next turf with Move() whenever its offset crosses
 * a tile edge. Walls and anything else that refuses the Move() reflect it.
 *
 * Changes from Shiptest: wall reflections use the right axis, bounces lose speed instead of
 * gaining it, offsets are kept as floats and written as whole pixels, and the component always
 * deletes itself once the movable settles (or after MOVABLE_PHYSICS_TIMEOUT), so a settled movable
 * costs nothing. It also lets go the moment anything else moves, picks up or throws the movable.
 */
/datum/component/movable_physics
	/// Speed along the floor, in pixels per step.
	var/horizontal_velocity = 0
	/// Speed up (positive) or down along pixel_z, in pixels per step.
	var/vertical_velocity = 0
	/// Direction of travel along the floor, in degrees clockwise from north.
	var/angle_of_movement = 0
	/// Current height above the floor, in pixels.
	var/height = 0
	/// Offsets from the movable's base pixel position, kept unrounded between steps.
	var/offset_x = 0
	var/offset_y = 0
	var/gravity = MOVABLE_PHYSICS_GRAVITY
	var/air_drag = MOVABLE_PHYSICS_AIR_DRAG
	var/ground_friction = MOVABLE_PHYSICS_GROUND_FRICTION
	/// Sound for floor bounces. Null uses the turf's bullet_bounce_sound.
	var/bounce_sound
	/// A hot casing sizzles on the first landing if the floor is wet or icy.
	var/hot = FALSE
	/// Spin on launch and on each real bounce.
	var/spin = TRUE
	var/bounces = 0
	/// The movable's animate_movement before we started; Move() must not glide while we steer it by pixels.
	var/cached_animate_movement
	/// TRUE while we are the ones calling Move(), so on_moved() knows the move was ours.
	var/moving_self = FALSE
	/// world.time after which we give up and settle wherever we are.
	var/give_up_at = 0

/datum/component/movable_physics/Initialize(horizontal_velocity = 0, vertical_velocity = 0, angle_of_movement = 0, start_height = 0, hot = FALSE, spin = TRUE, bounce_sound = null)
	var/atom/movable/body = parent
	if(!ismovable(body) || !isturf(body.loc))
		return COMPONENT_INCOMPATIBLE
	src.horizontal_velocity = max(horizontal_velocity, 0)
	src.vertical_velocity = vertical_velocity
	src.angle_of_movement = SIMPLIFY_DEGREES(angle_of_movement)
	src.hot = hot
	src.spin = spin
	src.bounce_sound = bounce_sound
	height = max(start_height, 0)
	offset_x = body.pixel_x - body.base_pixel_x
	offset_y = body.pixel_y - body.base_pixel_y
	cached_animate_movement = body.animate_movement
	body.animate_movement = NO_STEPS
	body.pixel_z = body.base_pixel_z + round(height)
	give_up_at = world.time + MOVABLE_PHYSICS_TIMEOUT
	if(spin)
		body.SpinAnimation(speed = 0.4 SECONDS, loops = 2)
	START_PROCESSING(SSmovable_physics, src)

/datum/component/movable_physics/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(parent, COMSIG_MOVABLE_PRE_THROW, PROC_REF(on_thrown))

/datum/component/movable_physics/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_MOVABLE_PRE_THROW))

/datum/component/movable_physics/Destroy(force)
	STOP_PROCESSING(SSmovable_physics, src)
	var/atom/movable/body = parent
	if(!QDELETED(body))
		body.animate_movement = cached_animate_movement
		body.pixel_z = body.base_pixel_z
		if(isturf(body.loc))
			body.pixel_x = body.base_pixel_x + round(clamp(offset_x, -16, 16))
			body.pixel_y = body.base_pixel_y + round(clamp(offset_y, -16, 16))
		else
			body.pixel_x = body.base_pixel_x
			body.pixel_y = body.base_pixel_y
	return ..()

/// Anything other than our own stepping that moves the body (a hand, a broom, a conveyor, a shuttle) ends the flight.
/datum/component/movable_physics/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	if(moving_self)
		return
	qdel(src)

/datum/component/movable_physics/proc/on_thrown(atom/movable/source, list/arguments)
	SIGNAL_HANDLER
	qdel(src)

/datum/component/movable_physics/process(seconds_per_tick)
	var/atom/movable/body = parent
	if(QDELETED(body) || !isturf(body.loc) || world.time >= give_up_at)
		qdel(src)
		return

	if(height > 0 || vertical_velocity > 0)
		vertical_velocity -= gravity
		height += vertical_velocity
		if(height <= 0)
			height = 0
			land(body)

	horizontal_velocity = max(0, horizontal_velocity - (height > 0 ? air_drag : ground_friction))
	if(horizontal_velocity)
		offset_x += sin(angle_of_movement) * horizontal_velocity
		offset_y += cos(angle_of_movement) * horizontal_velocity
		if(!cross_tiles(body))
			return

	body.pixel_x = body.base_pixel_x + round(offset_x)
	body.pixel_y = body.base_pixel_y + round(offset_y)
	body.pixel_z = body.base_pixel_z + round(height)

	if(!horizontal_velocity && height <= 0 && !vertical_velocity)
		qdel(src)

/// Hit the floor: make a noise, lose speed, maybe hop again.
/datum/component/movable_physics/proc/land(atom/movable/body)
	bounces++
	var/turf/floor = body.loc
	if(bounces <= 2)
		var/volume = bounces == 1 ? 20 : 10
		if(hot && bounces == 1 && floor.bullet_sizzle)
			playsound(body, 'sound/items/tools/welder.ogg', volume, TRUE)
		else
			var/landing_sound = bounce_sound || floor.bullet_bounce_sound
			if(landing_sound)
				playsound(body, landing_sound, volume, TRUE)
	vertical_velocity = -vertical_velocity * MOVABLE_PHYSICS_RESTITUTION
	if(vertical_velocity < MOVABLE_PHYSICS_MIN_BOUNCE)
		vertical_velocity = 0
	horizontal_velocity *= MOVABLE_PHYSICS_BOUNCE_KEEP
	angle_of_movement = SIMPLIFY_DEGREES(angle_of_movement + rand(-15, 15))
	if(spin && vertical_velocity)
		body.SpinAnimation(speed = 0.3 SECONDS, loops = 1)

/// Steps into the next turf when an offset passes a tile edge, or glances off whatever is in the way.
/// Returns FALSE if we stopped existing or lost the body on the way.
/datum/component/movable_physics/proc/cross_tiles(atom/movable/body)
	var/stepped = FALSE
	if(offset_x > 16 || offset_x < -16)
		var/step_dir = offset_x > 0 ? EAST : WEST
		if(step_body(body, step_dir))
			offset_x += step_dir == EAST ? -32 : 32
			stepped = TRUE
		else
			offset_x = clamp(offset_x, -16, 16)
			angle_of_movement = SIMPLIFY_DEGREES(360 - angle_of_movement)
			horizontal_velocity *= MOVABLE_PHYSICS_WALL_KEEP
		if(QDELETED(src) || QDELETED(body) || !isturf(body.loc))
			return FALSE
	if(offset_y > 16 || offset_y < -16)
		var/step_dir = offset_y > 0 ? NORTH : SOUTH
		if(step_body(body, step_dir))
			offset_y += step_dir == NORTH ? -32 : 32
			stepped = TRUE
		else
			offset_y = clamp(offset_y, -16, 16)
			angle_of_movement = SIMPLIFY_DEGREES(180 - angle_of_movement)
			horizontal_velocity *= MOVABLE_PHYSICS_WALL_KEEP
		if(QDELETED(src) || QDELETED(body) || !isturf(body.loc))
			return FALSE
	// Into space or a gravityless room: stop steering and let ordinary drift carry it.
	if(stepped && !body.has_gravity())
		qdel(src)
		return FALSE
	return TRUE

/// One Move() into the next turf. Dense turfs and blockers refuse it, so the body never ends up inside a wall.
/datum/component/movable_physics/proc/step_body(atom/movable/body, step_dir)
	var/turf/next = get_step(body, step_dir)
	if(!next)
		return FALSE
	moving_self = TRUE
	. = body.Move(next, step_dir, 0, FALSE)
	moving_self = FALSE

/// Fast processing for movable physics. Runs every 0.05 s while anything is in flight and idles otherwise.
PROCESSING_SUBSYSTEM_DEF(movable_physics)
	name = "Movable Physics"
	flags = SS_NO_INIT|SS_KEEP_TIMING
	wait = 0.05 SECONDS
	stat_tag = "MP"
