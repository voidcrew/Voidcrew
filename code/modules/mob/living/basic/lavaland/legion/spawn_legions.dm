/// Spawns a little worm nearby
/datum/action/cooldown/mob_cooldown/skull_launcher
	name = "Launch Legion"
	desc = "Propel a living piece of your body to a distant location."
	button_icon = 'icons/mob/simple/lavaland/lavaland_monsters.dmi'
	button_icon_state = "legion_head"
	background_icon_state = "bg_demon"
	overlay_icon_state = "bg_demon_border"
	click_to_activate = TRUE
	cooldown_time = 4 SECONDS
	melee_cooldown_time = 0
	shared_cooldown = NONE
	/// If a mob is not clicked directly, inherit targeting data from this blackboard key and setting it upon this target key
	var/ai_target_key = BB_BASIC_MOB_CURRENT_TARGET
	/// What are we actually spawning?
	var/spawn_type = /mob/living/basic/legion_brood
	/// How far can we fire?
	var/max_range = 7

/datum/action/cooldown/mob_cooldown/skull_launcher/IsAvailable(feedback)
	. = ..()
	if (!.)
		return
	if (!isturf(owner.loc))
		owner.balloon_alert(owner, "no room!")
		return FALSE
	return TRUE

/**
 * Walks the line from the owner to `destination` and returns the last turf the skull can
 * actually reach, or null if it cannot leave the owner's tile at all.
 *
 * Targeting is done with can_see(), which passes through anything non-opaque. A window is
 * transparent and solid at the same time, so without this the launcher happily deposits
 * brood on the other side of a hull - the "skulls spawned inside my ship" case. Dense mobs
 * are not obstacles; a thrown skull goes over them.
 */
/datum/action/cooldown/mob_cooldown/skull_launcher/proc/clamp_to_reachable_turf(turf/destination)
	var/turf/origin = get_turf(owner)
	if (isnull(destination) || destination == origin)
		return destination

	var/turf/furthest = null
	// get_line()'s first entry is the origin itself, which is not a candidate landing spot.
	var/list/path = get_line(origin, destination)
	for (var/i in 2 to length(path))
		var/turf/step = path[i]
		if (step.is_blocked_turf(exclude_mobs = TRUE, source_atom = owner))
			break
		furthest = step

	return furthest

/datum/action/cooldown/mob_cooldown/skull_launcher/Activate(atom/target)
	var/turf/target_turf = get_turf(target)

	if (get_dist(owner, target_turf) > max_range)
		target_turf = get_ranged_target_turf_direct(owner, target_turf, max_range)

	// The skull is thrown, so it has to be able to physically get there. Targeting only
	// needs line of sight, and glass is transparent but solid - without this a legion
	// stood outside a window drops brood on the far side of the hull.
	target_turf = clamp_to_reachable_turf(target_turf)
	if (isnull(target_turf))
		owner.balloon_alert(owner, "no room!")
		StartCooldown(0.5 SECONDS)
		return

	// Only a dense mob can be in the way now - clamp_to_reachable_turf() already rejected
	// anything solid. Shuffle off it if there's a free neighbour we can also reach.
	if (target_turf.is_blocked_turf())
		var/list/near_turfs = RANGE_TURFS(1, target_turf) - target_turf
		for (var/turf/check_turf as anything in near_turfs)
			if (check_turf.is_blocked_turf() || clamp_to_reachable_turf(check_turf) != check_turf)
				near_turfs -= check_turf
		if (length(near_turfs))
			target_turf = pick(near_turfs)
		else if(target_turf.is_blocked_turf(exclude_mobs = TRUE))
			owner.balloon_alert(owner, "no room!")
			StartCooldown(0.5 SECONDS)
			return

	var/ai_target = isliving(target) ? target : null
	if (isnull(ai_target))
		ai_target = owner.ai_controller?.blackboard[ai_target_key]

	var/target_dir = get_dir(owner, target)

	var/obj/effect/temp_visual/legion_skull_depart/launch = new(get_turf(owner))
	launch.set_appearance(spawn_type)
	launch.dir = target_dir
	new /obj/effect/temp_visual/legion_brood_indicator(target_turf)
	var/obj/effect/temp_visual/legion_skull_land/land = new(target_turf)
	land.dir = target_dir
	land.set_appearance(spawn_type, CALLBACK(src, PROC_REF(spawn_skull), target_turf, ai_target))
	StartCooldown()

/// Actually create a mob
/datum/action/cooldown/mob_cooldown/skull_launcher/proc/spawn_skull(turf/spawn_location, target)
	var/mob/living/basic/legion_brood/brood = new spawn_type(spawn_location)
	if (istype(brood))
		brood.assign_creator(owner)
	brood.ai_controller?.set_blackboard_key(ai_target_key, target)
	brood.dir = get_dir(owner, spawn_location)
	if (!isnull(target))
		brood.face_atom(target)
	else
		brood.dir = get_dir(owner, spawn_location)


/// Animation for launching a skull
/obj/effect/temp_visual/legion_skull_depart
	name = "legion brood launch"
	icon = 'icons/mob/simple/lavaland/lavaland_monsters.dmi'
	icon_state = "legion_head"
	duration = 0.25 SECONDS

/// Copy appearance from the passed atom type
/obj/effect/temp_visual/legion_skull_depart/proc/set_appearance(atom/spawned_type)
	icon = initial(spawned_type.icon)
	icon_state = initial(spawned_type.icon_state)
	animate(src, alpha = 0, pixel_y = 72, time = duration)

/// Animation for landing a skull
/obj/effect/temp_visual/legion_skull_land
	name = "legion brood land"
	duration = 0.5 SECONDS
	icon = 'icons/mob/simple/lavaland/lavaland_monsters.dmi'
	icon_state = "legion_head"
	alpha = 0
	pixel_y = 72

/// Copy appearance from the passed atom type and store what to do on animation complete
/obj/effect/temp_visual/legion_skull_land/proc/set_appearance(atom/spawned_type, datum/callback/on_completed)
	icon = initial(spawned_type.icon)
	icon_state = initial(spawned_type.icon_state)
	animate(src, alpha = 0, pixel_y = 72, time = duration / 2)
	animate(alpha = 255, pixel_y = 0, time = duration / 2)
	addtimer(on_completed, duration, TIMER_DELETE_ME)

/// A skull is going to be here! Oh no!
/obj/effect/temp_visual/legion_brood_indicator
	name = "legion brood land"
	duration = 0.75 SECONDS
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	icon = 'icons/mob/telegraphing/telegraph.dmi'
	icon_state = "skull"

/obj/effect/temp_visual/legion_brood_indicator/Initialize(mapload)
	. = ..()
	animate(src, alpha = 255, time = 0.5 SECONDS)
	animate(alpha = 0, time = 0.25 SECONDS)
