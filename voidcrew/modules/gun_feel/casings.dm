// Flying casings. A casing a ballistic gun spits out (when firing or racking) leaves the right side of
// the gun, arcs, bounces and skids to a stop instead of popping onto the shooter's tile.
// After Shiptest's /obj/item/ammo_casing/on_eject(). The flight is /datum/component/movable_physics.

/obj/item/ammo_casing
	/// Set only while a gun is ejecting this casing: the direction it should fly, in degrees clockwise from north.
	var/gun_feel_eject_angle

/obj/item/gun/ballistic/handle_chamber(empty_chamber = TRUE, from_firing = TRUE, chamber_next_round = TRUE)
	var/obj/item/ammo_casing/casing = chambered
	if(istype(casing))
		casing.gun_feel_eject_angle = gun_feel_eject_angle()
	. = ..()
	if(istype(casing) && !QDELETED(casing))
		casing.gun_feel_eject_angle = null

/// Out of the right side of the gun and a little back, from the holder's facing.
/obj/item/gun/ballistic/proc/gun_feel_eject_angle()
	var/atom/holder = ismob(loc) ? loc : src
	var/facing = dir2angle(holder.dir)
	if(isnull(facing))
		facing = rand(0, 359)
	return SIMPLIFY_DEGREES(facing + GUN_FEEL_CASING_EJECT_ANGLE + (rand() * 2 - 1) * GUN_FEEL_CASING_EJECT_SCATTER)

/obj/item/ammo_casing/bounce_away(still_warm = FALSE, bounce_delay = 3)
	if(!isnull(gun_feel_eject_angle))
		var/angle = gun_feel_eject_angle
		gun_feel_eject_angle = null
		if(gun_feel_launch(angle, still_warm))
			update_appearance()
			return
	return ..()

/// Sends this casing flying. Returns FALSE (and the caller drops it the old way) if it can't fly here.
/obj/item/ammo_casing/proc/gun_feel_launch(angle, still_warm)
	var/turf/floor = loc
	if(!isturf(floor) || floor.density || !has_gravity(floor))
		return FALSE
	if(length(SSmovable_physics.processing) >= GUN_FEEL_CASING_CAP)
		return FALSE
	pixel_x = base_pixel_x + rand(-4, 4)
	pixel_y = base_pixel_y + rand(-4, 4)
	var/speed = GUN_FEEL_CASING_SPEED_MIN + (GUN_FEEL_CASING_SPEED_MAX - GUN_FEEL_CASING_SPEED_MIN) * rand()
	var/lift = GUN_FEEL_CASING_LIFT_MIN + (GUN_FEEL_CASING_LIFT_MAX - GUN_FEEL_CASING_LIFT_MIN) * rand()
	var/datum/component/movable_physics/flight = AddComponent(/datum/component/movable_physics, speed, lift, angle, GUN_FEEL_CASING_START_HEIGHT, !!still_warm, TRUE)
	return !QDELETED(flight)
