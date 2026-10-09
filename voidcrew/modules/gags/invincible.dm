/**
 * *invincible: the Invincible wobble edit. The whole spessman is a cut-out picture on a spring:
 * every move flicks it, and it overshoots and wobbles back and forth about its feet, leaning,
 * squashing and swinging, each swing smaller, until it settles or the next flick comes. A rigged
 * body strikes the edit's poses as well. They're held where they are while it lasts, and invincible
 * if they were fit to be (see run_emote()).
 *
 * The edit, as it goes: a fighting crouch, lunging twice; flying, fists up, swaying; zipping
 * across and back, one fist up; and a punch at whoever's watching, drawn half again as big.
 */
/// How long it lasts (invincible.ogg's length), how long until they can again, and how long until
/// they can be invincible in it again (until then they just wobble).
#define GAG_INVINCIBLE_LENGTH (11.3 SECONDS)
#define GAG_INVINCIBLE_COOLDOWN (10 SECONDS)
#define GAG_INVINCIBLE_GODMODE_COOLDOWN (3 MINUTES)
/// How many times it swings back and forth after a flick, and how much of each swing the next keeps.
#define GAG_INVINCIBLE_RINGS 7
#define GAG_INVINCIBLE_DECAY 0.62

/datum/emote/living/carbon/human/invincible
	key = "invincible"
	message = "becomes invincible."
	emote_type = EMOTE_VISIBLE | EMOTE_AUDIBLE
	cooldown = GAG_INVINCIBLE_COOLDOWN

/datum/emote/living/carbon/human/invincible/can_run_emote(mob/user, status_check = TRUE, intentional, params)
	var/mob/living/carbon/human/human_user = user
	if(!intentional || !istype(human_user) || human_user.current_gag || human_user.stat != CONSCIOUS || human_user.body_position == LYING_DOWN || human_user.buckled || !isturf(human_user.loc) || HAS_TRAIT(human_user, TRAIT_RESTRAINED))
		return FALSE
	return ..()

/datum/emote/living/carbon/human/invincible/run_emote(mob/user, params, type_override, intentional = FALSE)
	. = ..()
	var/mob/living/carbon/human/human_user = user
	// Invincible only when nothing's wrong, and only every so often: it's never a way out of a fight,
	// nor chained into a godmode. Otherwise they just wobble, held still and as hittable as ever.
	var/invincible = world.time >= human_user.next_invincible && human_user.health >= human_user.maxHealth * 0.9 && !human_user.pulledby && !human_user.on_fire
	if(invincible)
		human_user.next_invincible = world.time + GAG_INVINCIBLE_GODMODE_COOLDOWN
		human_user.log_message("became invincible for [DisplayTimeText(GAG_INVINCIBLE_LENGTH)] (*invincible).", LOG_EMOTE)
	new /datum/gag/invincible(user, invincible)

/mob/living/carbon/human
	/// When they can next be invincible (see *invincible).
	var/next_invincible = 0

/**
 * The wobble, flick by flick, in time with invincible.ogg: list(when, in seconds into the clip; how
 * long the move takes, in deciseconds (0 snaps); where it settles: shear, squash, turn (degrees),
 * size, pixel_w, pixel_z; how hard it's flicked: shear, squash, turn; and how long one swing back
 * and forth takes, in deciseconds). It moves to where it settles plus the flick, then swings to the
 * other side and back (see GAG_INVINCIBLE_RINGS and GAG_INVINCIBLE_DECAY) and settles. A flick of
 * nothing just moves. Shear leans the top over (1 being a pixel across for every pixel up), squash
 * below 1 squashes and above stretches, and all of it is about their feet.
 */
GLOBAL_LIST_INIT(gag_invincible_beats, list(
	// A fighting crouch, lunging twice.
	list(0, 1.5, 0.1, 0.95, 0, 1, 0, 0, 0.5, 0.25, 15, 2.6),
	list(0.2, 1.2, 0.35, 0.8, 5, 1, 6, 0, 0.6, 0.3, 20, 2.2),
	list(0.55, 1.2, 0.05, 1, 0, 1, 0, 0, -0.6, -0.25, -18, 2.6),
	list(1, 1.2, 0.35, 0.8, 5, 1, 7, 0, 0.7, 0.3, 22, 2.2),
	list(1.35, 1.2, 0.05, 1, 0, 1, 0, 0, -0.6, -0.25, -18, 2.6),
	list(2, 1, 0.1, 0.95, 0, 1, 0, 0, 0.4, 0.15, 12, 2.4),
	list(2.45, 1, 0.1, 0.95, 0, 1, 0, 0, -0.45, -0.2, -14, 2.4),
	list(2.85, 1, 0, 0.8, 0, 1, 0, 0, 0, 0.3, 0, 1.6),
	// Flying, fists up, flung from side to side.
	list(3, 0.8, 0, 1, 0, 1.1, 0, 10, 0.8, 0.3, 35, 3),
	list(3.6, 1, 0, 1, 0, 1.1, 0, 10, -0.6, 0.2, -25, 2.8),
	list(4.2, 1, 0, 1, 0, 1.1, 0, 10, 0.65, -0.2, 25, 2.8),
	list(4.8, 1, 0, 1, 0, 1.1, 0, 10, -0.7, 0.25, -28, 2.6),
	list(5.4, 1, 0, 1, 0, 1.1, 0, 10, 0.6, -0.2, 24, 2.8),
	list(6, 1, 0, 1, 0, 1.1, 0, 10, -0.5, 0.2, -20, 2.6),
	// Zipping across, landing with one fist up, and back.
	list(6.5, 0, 0, 1, 90, 1, -20, 4, 0, 0, 0, 0),
	list(6.52, 3, 0, 1, 85, 1, 20, 4, 0, 0, 0, 0),
	list(6.85, 0.5, 0, 1, 0, 1, 0, 10, 0.8, 0.3, 30, 2.6),
	list(7.6, 0, 0, 1, -95, 1, 20, 4, 0, 0, 0, 0),
	list(7.62, 3, 0, 1, -85, 1, -20, 4, 0, 0, 0, 0),
	list(7.95, 0.5, 0, 1, 0, 1, 0, 10, -0.8, 0.3, -30, 2.6),
	// The punch at the camera, shaken about.
	list(8.75, 0.5, 0, 1, 0, 1.6, 0, 0, 0.3, 0.4, 10, 3),
	list(9.4, 1, 0, 1, 0, 1.6, 0, 0, -0.6, 0.2, -20, 2.8),
	list(10.1, 1, 0, 1, 0, 1.6, 0, 0, 0.6, -0.2, 20, 2.8),
	list(10.7, 1, 0, 1, 0, 1.6, 0, 0, -0.4, 0.15, -12, 2.6),
	list(11.1, 1.5, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0),
))

/// When a rigged body strikes each pose: list(when, in seconds; facing; pose; how long it takes, in deciseconds).
GLOBAL_LIST_INIT(gag_invincible_posing, list(
	list(0, EAST, "stance", 1),
	list(0.2, EAST, "lunge", 1.5),
	list(0.45, EAST, "stance", 3),
	list(1, EAST, "lunge", 1.5),
	list(1.25, EAST, "stance", 3),
	list(3, SOUTH, "fists_up", 0.5),
	list(6.5, EAST, "dive", 0.5),
	list(6.85, SOUTH, "one_fist", 0.5),
	list(7.6, WEST, "dive", 0.5),
	list(7.95, SOUTH, "one_fist", 0.5),
	list(8.75, SOUTH, "punch", 0.5),
))

/// The poses, by name.
GLOBAL_LIST_INIT(gag_invincible_poses, list(
	"stance" = list(RIG_CHEST = list("bend" = 12), RIG_HEAD = list("nod" = -8), RIG_L_ARM = list("swing" = 60, "elbow" = 100), RIG_R_ARM = list("swing" = 35, "elbow" = 120), RIG_L_LEG = list("swing" = 35, "knee" = 55), RIG_R_LEG = list("swing" = -20, "knee" = 25)),
	"lunge" = list(RIG_CHEST = list("bend" = 35), RIG_HEAD = list("nod" = -15), RIG_L_ARM = list("swing" = 95, "elbow" = 5), RIG_R_ARM = list("swing" = 20, "elbow" = 130), RIG_L_LEG = list("swing" = 55, "knee" = 45), RIG_R_LEG = list("swing" = -45, "knee" = 5)),
	"fists_up" = list(RIG_HEAD = list("nod" = -10), RIG_L_ARM = list("raise" = 160, "elbow" = 30), RIG_R_ARM = list("raise" = 160, "elbow" = 30), RIG_L_LEG = list("swing" = -15, "knee" = 35), RIG_R_LEG = list("swing" = 10, "knee" = 50)),
	"dive" = list(RIG_CHEST = list("bend" = -10), RIG_HEAD = list("nod" = -20), RIG_L_ARM = list("swing" = 175), RIG_R_ARM = list("swing" = 165, "elbow" = 10), RIG_L_LEG = list("swing" = -20, "knee" = 10), RIG_R_LEG = list("swing" = -35, "knee" = 30)),
	"one_fist" = list(RIG_L_ARM = list("raise" = 30, "swing" = 20, "elbow" = 90), RIG_R_ARM = list("raise" = 170), RIG_L_LEG = list("swing" = -10, "knee" = 40), RIG_R_LEG = list("knee" = 20)),
	"punch" = list(RIG_CHEST = list("bend" = 15), RIG_HEAD = list("nod" = 5), RIG_L_ARM = list("swing" = 40, "raise" = 10, "elbow" = 110), RIG_R_ARM = list("swing" = 80, "raise" = 25), RIG_L_LEG = list("swing" = 20, "knee" = 30), RIG_R_LEG = list("swing" = -15, "knee" = 15)),
))

/// When they're smeared across, zipping: list(from, to), in seconds.
GLOBAL_LIST_INIT(gag_invincible_smears, list(list(6.5, 6.85), list(7.6, 7.95)))

/datum/gag/invincible
	/// Ends it come what may, invincibility and all.
	var/failsafe

/datum/gag/invincible/New(mob/living/carbon/human/victim, invincible = FALSE)
	. = ..()
	if(invincible)
		ADD_TRAIT(victim, TRAIT_GODMODE, GAG_TRAIT)
	// Whatever happens to the rest of it, this ends when the clip does, and the invincibility with it
	// (see /datum/gag/Destroy()).
	failsafe = QDEL_IN_STOPPABLE(src, GAG_INVINCIBLE_LENGTH + 1 SECONDS)
	// Moved off their spot (pulled, thrown, teleported): over.
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))

/datum/gag/invincible/act()
	playsound(victim, 'voidcrew/modules/gags/sound/invincible.ogg', 80, FALSE)
	var/list/beats = GLOB.gag_invincible_beats
	var/list/posing = GLOB.gag_invincible_posing
	var/list/smears = GLOB.gag_invincible_smears
	var/next_beat = 1
	var/next_pose = 1
	var/next_smear = 1
	var/smearing = FALSE
	while(next_beat <= length(beats))
		// Whichever comes next: a beat, a pose or a smear starting or stopping.
		var/list/beat = beats[next_beat]
		var/list/pose = next_pose <= length(posing) ? posing[next_pose] : null
		var/list/smear = next_smear <= length(smears) ? smears[next_smear] : null
		var/smear_at = smear ? smear[smearing ? 2 : 1] : INFINITY
		var/at = min(beat[1], pose ? pose[1] : INFINITY, smear_at)
		GAG_AT(at SECONDS)
		if(smear_at == at)
			if(smearing)
				victim.remove_filter("gag_invincible_smear")
				next_smear++
			else
				victim.add_filter("gag_invincible_smear", 2, motion_blur_filter(x = 4, y = 0))
			smearing = !smearing
		if(pose && pose[1] == at)
			victim.setDir(pose[2])
			gag_pose(victim, GLOB.gag_invincible_poses[pose[3]], pose[4])
			next_pose++
		if(beat[1] == at)
			flick_to(beat)
			next_beat++
	GAG_AT(GAG_INVINCIBLE_LENGTH)
	qdel(src)

/**
 * One flick (see GLOB.gag_invincible_beats): over to where it settles plus the flick, then swinging
 * to the other side and back, smaller each time, and settling. Cuts off whatever swinging came before.
 */
/datum/gag/invincible/proc/flick_to(list/beat)
	var/pixel_w = victim.base_pixel_w + beat[7]
	var/pixel_z = victim.base_pixel_z + beat[8]
	var/half_swing = beat[12] / 2
	var/swing = 1
	animate(victim, transform = old_transform * gag_invincible_matrix(beat[3] + beat[9], beat[4] + beat[10], beat[5] + beat[11], beat[6]), pixel_w = pixel_w, pixel_z = pixel_z, time = beat[2], easing = SINE_EASING | EASE_OUT)
	if(!beat[9] && !beat[10] && !beat[11])
		return
	for(var/ring in 1 to GAG_INVINCIBLE_RINGS)
		swing *= -GAG_INVINCIBLE_DECAY
		animate(transform = old_transform * gag_invincible_matrix(beat[3] + beat[9] * swing, beat[4] + beat[10] * swing, beat[5] + beat[11] * swing, beat[6]), time = half_swing, easing = SINE_EASING)
	animate(transform = old_transform * gag_invincible_matrix(beat[3], beat[4], beat[5], beat[6]), time = half_swing, easing = SINE_EASING)

/datum/gag/invincible/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/gag/invincible/Destroy()
	deltimer(failsafe)
	if(victim)
		UnregisterSignal(victim, COMSIG_MOVABLE_MOVED)
		// Stops the wobble where it is, before they're put back.
		animate(victim)
		victim.remove_filter("gag_invincible_smear")
		victim.limb_rig?.settle()
	return ..()

/// Leans, squashes, turns and sizes something about its feet (the bottom of its tile), as the wobble does.
/proc/gag_invincible_matrix(shear, squash, turn, size)
	var/matrix/wobble = matrix(1, shear, 0, 0, 1, 0)
	wobble.Scale(size * (2 - squash), size * squash)
	wobble.Turn(turn)
	// Back onto its feet: whatever the rest did to the middle of the bottom edge, undone.
	wobble.Translate(16 * wobble.b, 16 * wobble.e - 16)
	return wobble

#undef GAG_INVINCIBLE_LENGTH
#undef GAG_INVINCIBLE_COOLDOWN
#undef GAG_INVINCIBLE_GODMODE_COOLDOWN
#undef GAG_INVINCIBLE_RINGS
#undef GAG_INVINCIBLE_DECAY
