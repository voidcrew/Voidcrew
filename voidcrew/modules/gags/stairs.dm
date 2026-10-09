/**
 * Fall Down The Stairs: Peter Griffin's fall (Family Guy, "The Blind Side"). They walk along the
 * upstairs hallway to the top of the stairs, trip, and go all the way down, hitting every step, to
 * land in his pose: face down, arms twisted up behind their back, a leg folded up over it. Then
 * they're put back where they were, still in it, hurt.
 *
 * In stairs.dmm: the hallway's along y 26, the top of the stairs is (10, 25), the eighteen steps
 * run down from y 24 to y 7, and the living room's below.
 */
/datum/smite/fall_down_stairs
	name = "Fall Down The Stairs"

/datum/smite/fall_down_stairs/effect(client/user, mob/living/target)
	. = ..()
	var/mob/living/carbon/human/victim = target
	if(!istype(victim) || victim.current_gag)
		to_chat(user, span_warning("This must be used on a human who isn't in the middle of another gag."), confidential = TRUE)
		return
	new /datum/gag/stairs(victim)

/// Everything they hit on the way down, in seconds into peter_stairs.ogg (measured off the clip):
/// the trip at the top, seventeen more steps, then the floor.
GLOBAL_LIST_INIT(gag_stairs_hits, list(0.12, 0.5, 0.84, 1.18, 1.54, 2.2, 2.54, 3.08, 3.46, 3.82, 4.18, 4.56, 5.34, 5.66, 6.26, 6.56, 7.08, 7.52, 7.9))

/// The pose they end up in, seen from the side: on their front, both arms wrenched up behind their
/// back, one leg folded up over it, the other out straight.
/proc/gag_stairs_pose()
	return list(
		RIG_L_ARM = list("swing" = -135, "raise" = 10, "elbow" = 100),
		RIG_R_ARM = list("swing" = -115, "raise" = 20, "elbow" = 125),
		RIG_L_LEG = list("swing" = -95, "knee" = 115),
		RIG_R_LEG = list("swing" = 5, "knee" = 10),
		RIG_HEAD = list("nod" = -20),
		RIG_CHEST = list("bend" = -10),
	)

/datum/gag/stairs/act()
	room = gag_load_room("stairs.dmm")
	if(!room)
		qdel(src)
		return
	came_from = get_turf(victim)
	// Nothing's to stop it partway.
	victim.add_traits(list(TRAIT_GODMODE), GAG_TRAIT)
	victim.forceMove(gag_room_turf(room, 3, 26))
	victim.setDir(EAST)
	sleep(1 SECONDS)
	// Along the hallway to the top of the stairs.
	victim.set_glide_size(DELAY_TO_GLIDE_SIZE(4))
	for(var/x in 4 to 10)
		victim.Move(gag_room_turf(room, x, 26), EAST)
		sleep(4)
		if(QDELETED(src))
			return
	victim.Move(gag_room_turf(room, 10, 25), SOUTH)
	sleep(4)
	if(QDELETED(src))
		return
	// Side on, for the fall.
	victim.setDir(EAST)
	started = world.time
	SEND_SOUND(victim, sound('voidcrew/modules/gags/sound/peter_stairs.ogg'))
	var/list/hits = GLOB.gag_stairs_hits
	var/angle = 0
	for(var/index in 1 to length(hits))
		GAG_AT(hits[index] SECONDS)
		var/landed = index == length(hits)
		var/next_hit = landed ? 0.4 SECONDS : (hits[index + 1] - hits[index]) SECONDS
		victim.forceMove(gag_room_turf(room, 10, 25 - index))
		var/matrix/turned = matrix(old_transform)
		if(landed)
			// Face down.
			turned.Turn(90)
			animate(victim, transform = turned, pixel_z = victim.base_pixel_z, time = 1)
			gag_pose(victim, gag_stairs_pose(), 1)
			break
		// Tumbling end over end, bouncing off each step.
		angle += pick(90, 135, 180)
		turned.Turn(angle)
		animate(victim, transform = turned, pixel_z = victim.base_pixel_z + 6, time = next_hit / 2, easing = SINE_EASING | EASE_OUT)
		animate(pixel_z = victim.base_pixel_z, time = next_hit / 2, easing = SINE_EASING | EASE_IN)
		gag_pose(victim, gag_flail_pose(), next_hit)
		shake_camera(victim, 1, 1)
	// A step on, sliding across the floor; then the hiss through his teeth.
	GAG_AT(8.1 SECONDS)
	victim.forceMove(gag_room_turf(room, 10, 5))
	GAG_AT(11 SECONDS)
	// Home, still in it.
	UnregisterSignal(victim, COMSIG_LIVING_SET_BODY_POSITION)
	give_back_transform()
	victim.remove_traits(list(TRAIT_GODMODE, TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), GAG_TRAIT)
	victim.forceMove(came_from)
	victim.adjustBruteLoss(25)
	victim.Paralyze(8 SECONDS)
	QDEL_NULL(room)
	sleep(8 SECONDS)
	if(QDELETED(src))
		return
	victim.limb_rig?.settle()
	qdel(src)
