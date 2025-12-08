// Ship Combat Missile Effect
// Flying missile projectile that travels toward a target turf
// Based on meteor movement patterns - spawns at edge of target ship and flies in

/obj/effect/ship_missile
	name = "ship missile"
	desc = "A ship-to-ship missile streaking through space."
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	icon_state = "missile"
	density = TRUE
	anchored = TRUE
	pass_flags = PASSTABLE
	layer = ABOVE_MOB_LAYER

	/// The target turf we're flying toward
	var/turf/target_turf
	/// The ship we're targeting (for signal purposes)
	var/obj/structure/overmap/ship/target_ship
	/// The ship that fired us
	var/obj/structure/overmap/ship/source_ship
	/// Damage dealt on impact
	var/damage = MISSILE_DAMAGE_STANDARD
	/// Explosion devastation range
	var/explosion_devastation = MISSILE_EXPLOSION_DEVASTATION
	/// Explosion heavy range
	var/explosion_heavy = MISSILE_EXPLOSION_HEAVY
	/// Explosion light range
	var/explosion_light = MISSILE_EXPLOSION_LIGHT
	/// Explosion flame range
	var/explosion_flame = MISSILE_EXPLOSION_FLAME
	/// Sound to play on impact
	var/impact_sound = 'sound/effects/meteorimpact.ogg'
	/// Our starting z level
	var/z_original
	/// Lifetime before auto-deletion (in deciseconds)
	var/lifetime = 30 SECONDS
	/// Have we already exploded?
	var/exploded = FALSE

/obj/effect/ship_missile/New()
	// Add hyperspace traits in New() BEFORE the object is placed on the turf
	// This is critical because transit turfs check for TRAIT_HYPERSPACED on COMSIG_ATOM_ENTERED
	// which fires before Initialize() runs
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_FREE_HYPERSPACE_SOFTCORDON_MOVEMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_HYPERSPACED, INNATE_TRAIT)
	return ..()

/obj/effect/ship_missile/Initialize(mapload, turf/target, obj/structure/overmap/ship/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, missile_damage, dev_range, heavy_range, light_range, flame_range, missile_icon)
	. = ..()

	// Store our starting z-level (we're spawned directly at our start position by the launcher)
	z_original = z

	target_turf = target
	target_ship = target_ship_ref
	source_ship = source_ship_ref

	// Apply damage parameters if provided
	if(missile_damage)
		damage = missile_damage
	if(!isnull(dev_range))
		explosion_devastation = dev_range
	if(!isnull(heavy_range))
		explosion_heavy = heavy_range
	if(!isnull(light_range))
		explosion_light = light_range
	if(!isnull(flame_range))
		explosion_flame = flame_range
	if(missile_icon)
		icon_state = missile_icon

	// Rotate to face the target direction
	if(target_turf)
		var/turf/our_turf = get_turf(src)
		if(our_turf)
			var/angle = get_angle(our_turf, target_turf)
			// The missile sprite points down (south) by default
			// get_angle returns 0 for north, 90 for east, etc.
			// Add 180 to flip the sprite to face the target
			var/matrix/M = matrix()
			M.Turn(angle + 180)
			transform = M

	// Start moving toward target
	if(target_turf)
		chase_target(target_turf)

	// Send fired signal
	if(source_ship)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_MISSILE_FIRED, src, target_ship)
		SEND_SIGNAL(source_ship, COMSIG_SHIP_WEAPON_FIRED)

/obj/effect/ship_missile/Destroy()
	var/datum/move_loop/moveloop = GLOB.move_manager.processing_on(src, SSmovement)
	if(!isnull(moveloop))
		UnregisterSignal(moveloop, COMSIG_MOVELOOP_STOP)
	target_turf = null
	target_ship = null
	source_ship = null
	return ..()

/obj/effect/ship_missile/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(QDELETED(src))
		return

	// Check if we've left the z-level (but only after we've been set up)
	if(z_original && z != z_original)
		qdel(src)
		return

	// Check if we've hit the target turf
	var/turf/current = get_turf(src)
	if(current == target_turf)
		impact()

/obj/effect/ship_missile/Process_Spacemove(movement_dir = 0, continuous_move = FALSE)
	return TRUE // Don't drift

/// Allow other missiles to pass through us - prevents missile-on-missile collisions
/obj/effect/ship_missile/CanAllowThrough(atom/movable/mover, border_dir)
	if(istype(mover, /obj/effect/ship_missile))
		return TRUE
	return ..()

/obj/effect/ship_missile/Bump(atom/A)
	// Ignore collisions with other missiles
	if(istype(A, /obj/effect/ship_missile))
		return ..()

	// If we hit something dense, we need to explode ON it, not next to it in space
	if(A && A.density && !exploded)
		// Get the turf of the thing we hit
		var/turf/impact_turf = get_turf(A)
		if(impact_turf)
			// Force move to that turf so the explosion epicenter is on the ship
			forceMove(impact_turf)
		impact()
		return

	return ..()

/// Start chasing the target turf
/obj/effect/ship_missile/proc/chase_target(atom/chasing)
	if(!isatom(chasing))
		return
	var/datum/move_loop/new_loop = GLOB.move_manager.move_towards(src, chasing, MISSILE_SPEED, FALSE, lifetime)
	if(new_loop)
		RegisterSignal(new_loop, COMSIG_MOVELOOP_STOP, PROC_REF(on_loop_stopped))

/obj/effect/ship_missile/proc/on_loop_stopped(datum/source)
	SIGNAL_HANDLER
	if(!exploded)
		impact()

/// Called when the missile reaches its target or hits something
/obj/effect/ship_missile/proc/impact()
	if(exploded)
		return
	exploded = TRUE

	var/turf/impact_loc = get_turf(src)

	// Play impact sound
	playsound(impact_loc, impact_sound, 60, TRUE)

	// Send impact signal
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_MISSILE_IMPACT, src, impact_loc)

	// Create explosion - ignorecap = TRUE so ship missiles bypass the server bomb cap
	explosion(
		impact_loc,
		devastation_range = explosion_devastation,
		heavy_impact_range = explosion_heavy,
		light_impact_range = explosion_light,
		flame_range = explosion_flame,
		flash_range = explosion_light + 1,
		adminlog = TRUE,
		ignorecap = TRUE,
		explosion_cause = src
	)

	// Screen shake for nearby players
	for(var/mob/living/victim in range(7, impact_loc))
		shake_camera(victim, 3, 2)

	qdel(src)

// ========== EMP MISSILE VARIANT ==========

/obj/effect/ship_missile/emp
	name = "EMP ship missile"
	desc = "An electromagnetic pulse missile streaking through space."

/obj/effect/ship_missile/emp/impact()
	if(exploded)
		return
	exploded = TRUE

	var/turf/impact_loc = get_turf(src)

	// Play impact sound
	playsound(impact_loc, impact_sound, 60, TRUE)

	// Send impact signal
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_MISSILE_IMPACT, src, impact_loc)

	// Create smaller explosion
	explosion(
		impact_loc,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = explosion_light,
		flame_range = 0,
		flash_range = 3,
		adminlog = TRUE,
		ignorecap = TRUE,
		explosion_cause = src
	)

	// EMP pulse
	empulse(impact_loc, 2, 4)

	// Screen shake for nearby players
	for(var/mob/living/victim in range(7, impact_loc))
		shake_camera(victim, 2, 1)

	qdel(src)

// ========== CHEMICAL MISSILE VARIANT ==========

/obj/effect/ship_missile/chemical
	name = "chemical ship missile"
	desc = "A chemical warhead missile streaking through space."
	/// List of reagent holders from the payload's beakers
	var/list/datum/reagents/payload_reagents = list()
	/// Splash radius
	var/affected_area = 5
	/// Temperature added to reagents on impact
	var/ignition_temp = 100

/obj/effect/ship_missile/chemical/Initialize(mapload, turf/target, obj/structure/overmap/ship/target_ship_ref, obj/structure/overmap/ship/source_ship_ref, missile_damage, dev_range, heavy_range, light_range, flame_range, missile_icon, list/chem_reagents, chem_area, chem_temp)
	. = ..()
	if(chem_reagents)
		payload_reagents = chem_reagents
	if(chem_area)
		affected_area = chem_area
	if(chem_temp)
		ignition_temp = chem_temp

/obj/effect/ship_missile/chemical/impact()
	if(exploded)
		return
	exploded = TRUE

	var/turf/impact_loc = get_turf(src)

	// Play impact sound
	playsound(impact_loc, impact_sound, 60, TRUE)

	// Send impact signal
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_MISSILE_IMPACT, src, impact_loc)

	// Create small explosion first
	explosion(
		impact_loc,
		devastation_range = 0,
		heavy_impact_range = 0,
		light_impact_range = explosion_light,
		flame_range = 0,
		flash_range = 2,
		adminlog = TRUE,
		ignorecap = TRUE,
		explosion_cause = src
	)

	// Then do the chemical splash if we have reagents
	if(length(payload_reagents))
		// Create a temporary reagent holder for the splash proc
		var/datum/reagents/holder = new(1000)
		holder.my_atom = src
		chem_splash(impact_loc, holder, affected_area, payload_reagents, ignition_temp, 1)

	// Screen shake for nearby players
	for(var/mob/living/victim in range(7, impact_loc))
		shake_camera(victim, 2, 1)

	qdel(src)
