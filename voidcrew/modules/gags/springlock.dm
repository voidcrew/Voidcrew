/**
 * *springlock: the springlocks give. They're laughing (the clip's laugh, not theirs), it creaks, and
 * then the suit's parts snap into where their insides were, one after another: every crunch a
 * spasm and blood out of them, gibs and the suit's metal thrown off every which way, their organs pushed out onto
 * the floor, the puddle under them growing. Their knees go; they reach out for something; they
 * fold over. They don't get up.
 */
/datum/emote/living/carbon/human/springlock
	key = "springlock"
	message = "laughs... and something inside clicks."
	emote_type = EMOTE_VISIBLE
	cooldown = 30 SECONDS

/datum/emote/living/carbon/human/springlock/can_run_emote(mob/user, status_check = TRUE, intentional, params)
	var/mob/living/carbon/human/human_user = user
	// Only ever on purpose: nothing makes anyone do this.
	if(!intentional || !istype(human_user) || human_user.current_gag || human_user.body_position == LYING_DOWN || !isturf(human_user.loc))
		return FALSE
	return ..()

/datum/emote/living/carbon/human/springlock/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	new /datum/gag/springlock(user)

/// Every crunch, in seconds into springlock.ogg (measured off the clip).
GLOBAL_LIST_INIT(gag_springlock_crunches, list(8.12, 8.86, 9.9, 10.24, 10.66, 11.46, 11.76, 13, 14.4, 14.8, 15.16, 15.48, 16.14, 16.42, 17.4, 18.2, 18.52, 19.06, 20.42, 22.4, 23.18, 24.28, 24.74, 25.04, 25.36, 25.68, 27.4))
/// The crunches that push an organ out.
GLOBAL_LIST_INIT(gag_springlock_spills, list(11.46, 16.42, 22.4))

/datum/gag/springlock
	var/obj/effect/decal/cleanable/blood/puddle
	/// Whether their knees have gone, and whether they're reaching out.
	var/knelt = FALSE
	var/reaching = FALSE

/datum/gag/springlock/act()
	playsound(victim, 'voidcrew/modules/gags/sound/springlock.ogg', 80, FALSE)
	// Laughing: head back, hands to the belly, shaking with it.
	var/list/laugh_in = list(RIG_HEAD = list("nod" = -28), RIG_CHEST = list("bend" = -8, "breath" = 0.05), RIG_L_ARM = list("swing" = 30, "elbow" = 110), RIG_R_ARM = list("swing" = 30, "elbow" = 110))
	var/list/laugh_out = list(RIG_HEAD = list("nod" = -18), RIG_CHEST = list("bend" = -2), RIG_L_ARM = list("swing" = 25, "elbow" = 105), RIG_R_ARM = list("swing" = 25, "elbow" = 105))
	victim.limb_rig?.play(list(list(laugh_in, 2), list(laugh_out, 2)), loop = -1, settle_after = FALSE)
	// It creaks: they stop, and look down at themselves.
	GAG_AT(5.4 SECONDS)
	gag_pose(victim, list(RIG_HEAD = list("nod" = 32), RIG_L_ARM = list("swing" = 15, "raise" = 20), RIG_R_ARM = list("swing" = 15, "raise" = 20)), 1)
	shake(1)
	GAG_AT(7 SECONDS)
	// The first one goes.
	puddle = new(get_turf(victim))
	if(QDELETED(puddle))
		puddle = locate() in get_turf(victim)
	if(puddle)
		puddle.transform = matrix() * 0.3
		animate(puddle, transform = matrix() * 2.2, time = 22 SECONDS)
	crunch(TRUE)
	for(var/when in GLOB.gag_springlock_crunches)
		GAG_AT(when SECONDS)
		if(when >= 18.2)
			knelt = TRUE
		if(when >= 20.42)
			reaching = TRUE
		crunch(when in GLOB.gag_springlock_spills)
	// They fold over, and that's it.
	GAG_AT(28 SECONDS)
	gag_pose(victim, list(RIG_CHEST = list("bend" = 60), RIG_HEAD = list("nod" = 40), RIG_L_ARM = list("swing" = 10, "raise" = 5), RIG_R_ARM = list("swing" = 10, "raise" = 5)), 10)
	GAG_AT(29.5 SECONDS)
	UnregisterSignal(victim, COMSIG_LIVING_SET_BODY_POSITION)
	give_back_transform()
	victim.limb_rig?.set_seated(null)
	var/mob/living/carbon/human/dead = victim
	dead.adjustBruteLoss(150)
	if(dead.stat != DEAD)
		dead.death()
	qdel(src)

/// One crunch: a spasm, blood out of them, something thrown off; with spill, an organ pushed out.
/datum/gag/springlock/proc/crunch(spill)
	var/list/spasm = list(
		RIG_CHEST = list("bend" = rand(-35, 35)),
		RIG_HEAD = list("nod" = rand(-40, 40), "tilt" = rand(-25, 25)),
		RIG_L_ARM = list("swing" = rand(-60, 140), "raise" = rand(0, 70), "elbow" = rand(0, 130)),
		RIG_R_ARM = list("swing" = rand(-60, 140), "raise" = rand(0, 70), "elbow" = rand(0, 130)),
	)
	if(reaching)
		// One arm out for something, shaking, whatever the rest of them does.
		spasm[RIG_L_ARM] = list("swing" = 95 + rand(-6, 6), "raise" = 25 + rand(-6, 6), "elbow" = rand(0, 10))
	if(knelt)
		victim.limb_rig?.set_seated("crouch")
	gag_pose(victim, spasm, 0.5)
	shake(2)
	var/turf/here = get_turf(victim)
	for(var/spurt in 1 to rand(1, 2))
		spurt(here, rand(2, 4))
	var/obj/effect/decal/cleanable/blood/gibs/thrown = prob(50) ? new /obj/effect/decal/cleanable/blood/gibs(here) : new /obj/effect/decal/cleanable/blood/gibs/robot_debris(here)
	if(!QDELETED(thrown))
		fling(thrown, here, rand(1, 3))
	playsound(victim, 'sound/effects/wounds/crack1.ogg', 40, TRUE)
	if(!spill)
		return
	for(var/slot in list(ORGAN_SLOT_STOMACH, ORGAN_SLOT_LIVER, ORGAN_SLOT_APPENDIX))
		var/obj/item/organ/organ = victim.get_organ_slot(slot)
		if(!organ)
			continue
		organ.Remove(victim)
		organ.forceMove(here)
		organ.throw_at(get_turf_in_angle(rand(0, 359), here, rand(2, 4)) || here, 4, 2)
		return

// Everything thrown off goes any which way, not just along the eight directions (which leaves a star).

/// Blood out of them, off at any angle, this many tiles.
/datum/gag/springlock/proc/spurt(turf/here, distance)
	if(victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/obj/effect/decal/cleanable/blood/hitsplatter/splatter = new(here, victim.get_static_viruses(), victim.get_blood_dna_list(), distance)
	if(!QDELETED(splatter))
		splatter.fly_towards(get_turf_in_angle(rand(0, 359), here, distance) || here, distance)

/// Sends some gibs sliding off at any angle, this many tiles, smearing as they go, and lands them anywhere on the tile.
/datum/gag/springlock/proc/fling(obj/effect/decal/cleanable/blood/gibs/thrown, turf/here, distance)
	thrown.pixel_w = rand(-10, 10)
	thrown.pixel_z = rand(-10, 10)
	var/turf/target = get_turf_in_angle(rand(0, 359), here, distance)
	if(!target || target == here)
		return
	var/datum/move_loop/loop = GLOB.move_manager.move_towards(thrown, target, 2, timeout = distance * 2 + 1, priority = MOVEMENT_ABOVE_SPACE_PRIORITY)
	if(loop && thrown.leave_blood)
		thrown.RegisterSignal(loop, COMSIG_MOVELOOP_POSTPROCESS, TYPE_PROC_REF(/obj/effect/decal/cleanable/blood/gibs, spread_movement_effects))

/// Jolts them where they stand, a few times, this many pixels each way.
/datum/gag/springlock/proc/shake(pixels)
	var/home = victim.base_pixel_w
	animate(victim, pixel_w = home + pixels, time = 0.5)
	for(var/i in 1 to 2)
		animate(pixel_w = home - pixels, time = 0.5)
		animate(pixel_w = home + pixels, time = 0.5)
	animate(pixel_w = home, time = 0.5)

/datum/gag/springlock/Destroy()
	puddle = null
	return ..()
