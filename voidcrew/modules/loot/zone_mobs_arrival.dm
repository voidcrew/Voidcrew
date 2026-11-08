/**
 * # Zone Mob Wave Arrivals
 *
 * Runtime waves (new /obj/effect/zone_mobs/<theme>(T, count, TRUE)) are called
 * in while players are standing right there, so the pack has to visibly get
 * there instead of appearing beside them. Crews drop in by pod; beasts, bugs
 * and the dead dig up out of the ground after a short rumble.
 */

/// How long the ground shakes before something digs out of it
#define ZONE_MOBS_EMERGE_TIME (2.5 SECONDS)
/// How far below the tile an emerging mob starts
#define ZONE_MOBS_EMERGE_DEPTH 16

/**
 * Loads one mob into a pod and drops it on the spot. The pod shows its usual
 * landing marker, does no damage or explosion, opens, then leaves, so it never
 * stays behind as free furniture.
 */
/proc/zone_mobs_pod_drop(mob_path, turf/spot, datum/npc_spawn_context/context, datum/pod_style/style = /datum/pod_style)
	var/obj/structure/closet/supplypod/podspawn/pod = new(null, style)
	spawn_npc_in_zone(mob_path, pod, context)
	new /obj/effect/pod_landingzone(spot, pod)

/**
 * The ground rumbles, then the mob climbs out of it and leaves rubble behind.
 */
/proc/zone_mobs_emerge(mob_path, turf/spot, datum/npc_spawn_context/context)
	new /obj/effect/temp_visual/zone_mobs_emerge(spot)
	playsound(spot, 'sound/effects/break_stone.ogg', 50, TRUE)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(zone_mobs_emerge_finish), mob_path, spot, context), ZONE_MOBS_EMERGE_TIME)

/proc/zone_mobs_emerge_finish(mob_path, turf/spot, datum/npc_spawn_context/context)
	if(!spot)
		return
	playsound(spot, 'sound/effects/shovel_dig.ogg', 60, TRUE)
	new /obj/effect/decal/cleanable/rubble(spot)
	var/mob/living/body = spawn_npc_in_zone(mob_path, spot, context)
	if(!isliving(body) || QDELETED(body))
		return
	// Parallel and relative so a mob's own idle animation (floating, bobbing) survives
	var/final_alpha = body.alpha
	body.alpha = 0
	body.pixel_z -= ZONE_MOBS_EMERGE_DEPTH
	animate(body, pixel_z = ZONE_MOBS_EMERGE_DEPTH, time = 0.6 SECONDS, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(body, alpha = final_alpha, time = 0.4 SECONDS, flags = ANIMATION_PARALLEL)

/// The shaking dirt that gives away something digging up
/obj/effect/temp_visual/zone_mobs_emerge
	name = "shifting ground"
	icon = 'icons/obj/debris.dmi'
	icon_state = "rubble_bounce"
	layer = ABOVE_OPEN_TURF_LAYER
	plane = FLOOR_PLANE
	randomdir = FALSE
	duration = ZONE_MOBS_EMERGE_TIME

/obj/effect/temp_visual/zone_mobs_emerge/Initialize(mapload)
	. = ..()
	animate(src, pixel_x = 1, time = 0.5, loop = -1)
	animate(pixel_x = -1, time = 1)
	animate(pixel_x = 0, time = 0.5)

#undef ZONE_MOBS_EMERGE_TIME
#undef ZONE_MOBS_EMERGE_DEPTH
