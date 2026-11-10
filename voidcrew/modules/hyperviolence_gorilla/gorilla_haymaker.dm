/**
 * # The charged haymaker
 *
 * A chrome wheel chip on each real Gorilla arm. Hold Use chrome to wind up and let go to throw it at
 * whoever is in the tile you face; or tap Use chrome (or pick the chip) and click someone next to you.
 * The wind-up slows the bearer, lets go of any grab and leans back, so the target has a
 * beat to step out of line. The hit sends the body flying along the safe path, further for a full
 * charge; into a wall it hits harder and cracks the chest. A swing at nobody staggers the bearer.
 * Held too long, or called off, the charge is lost.
 *
 * The arm shows it. A bearer who stands their ground is drawn on the puppet rig (chrome_puppet_rig.dm, with the swing
 * of gorilla_swing.dm): the punching arm draws back as the charge builds and is held there, the other comes up as a
 * guard, and on the release the fist is thrown onto the part it hits with a step in behind it, stays there a beat,
 * follows through and comes back to rest. The blow lands with the fist on it, a tick after the release. A bearer who
 * walks or turns while winding up keeps the lean alone, and their blow is tg's lunge.
 *
 * The haymaker and every Gorilla finisher share one cooldown, kept on the bearer, so they never chain.
 */

/datum/action/cooldown/cyberware/gorilla_haymaker
	name = "Haymaker"
	desc = "Wind up one fist and put everything behind it."
	button_icon = GORILLA_GORE_ICON
	button_icon_state = "chip_haymaker"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED
	cooldown_time = GORILLA_PISTONS_COOLDOWN
	click_to_activate = TRUE
	unset_after_click = TRUE
	/// world.time the wind-up began, 0 when not winding up
	var/charge_started = 0
	/// world.time Use chrome went down for this charge, so a short press reads as a tap
	var/pressed_at = 0
	/// Set while a release unsets the click ability, so that doesn't read as calling it off
	var/releasing = FALSE
	/// Timer that vents a charge held too long
	var/vent_timer
	/// Timer for a release made before the minimum wind-up: it lands when the wind-up is done
	var/release_timer
	/// The bearer's arm rig while the wind-up and the swing are drawn
	var/datum/chrome_rig/rig
	/// Timer that takes the rig down when the arms are back at rest
	var/rig_timer
	/// Timer that lands a thrown blow
	var/land_timer
	/// The part the blow must land on, for an AI that picks one. Else it is rolled from the part the bearer aims at
	var/aimed_zone

/datum/action/cooldown/cyberware/gorilla_haymaker/Destroy()
	stop_charge()
	if(land_timer)
		deltimer(land_timer)
		land_timer = null
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/Remove(mob/remove_from)
	if(charge_started)
		stop_charge()
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return
	if(!TIMER_COOLDOWN_FINISHED(owner, COOLDOWN_GORILLA_PISTONS))
		if(feedback)
			owner.balloon_alert(owner, "pistons still hot!")
		return FALSE
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	if(!istype(arm) || !arm.heavy_moves || !gorilla_may_use_heavy_moves(owner) || HAS_TRAIT(owner, TRAIT_PACIFISM))
		return FALSE
	return TRUE

/// Whether a wind-up is running.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/charging()
	return charge_started > 0

// A second press while winding up throws it at the tile you face.
/datum/action/cooldown/cyberware/gorilla_haymaker/Trigger(mob/clicker, trigger_flags, atom/target)
	if(charging() && !target && owner)
		if(!IsAvailable(feedback = TRUE))
			return FALSE
		release(get_step(owner, owner.dir))
		return TRUE
	return ..()

/datum/action/cooldown/cyberware/gorilla_haymaker/set_click_ability(mob/on_who)
	. = ..()
	start_charge()

/datum/action/cooldown/cyberware/gorilla_haymaker/unset_click_ability(mob/on_who, refund_cooldown = TRUE)
	. = ..()
	// Called off by hand (the chip again, a stun, the arm going dark): the pistons vent.
	if(charging() && !releasing && !release_timer)
		vent()

/datum/action/cooldown/cyberware/gorilla_haymaker/Activate(atom/target)
	return release(target)

/// Use chrome came back up: a held press throws it at the tile you face, a tap waits for a click.
/datum/action/cooldown/cyberware/gorilla_haymaker/chrome_use_released(mob/living/carbon/bearer)
	if(!charging() || bearer != owner || release_timer)
		return FALSE
	if(world.time - pressed_at < GORILLA_HAYMAKER_TAP || !IsAvailable(feedback = TRUE))
		return FALSE
	release(get_step(owner, owner.dir))
	return TRUE

/**
 * Winds up and lands the blow on [target] after [hold_time], with no click or key: the same wind-up anyone can see
 * and dodge. On [zone], if one is given. For an AI. Returns TRUE if the wind-up began.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/wind_up_at(atom/target, hold_time = GORILLA_HAYMAKER_FULL_CHARGE, zone)
	if(charging() || !IsAvailable())
		return FALSE
	start_charge()
	if(!charging())
		return FALSE
	aimed_zone = zone
	// Thrown a throw's length early, so the blow lands when the hold is up
	release_timer = addtimer(CALLBACK(src, PROC_REF(queued_release), WEAKREF(target)), max(hold_time, GORILLA_HAYMAKER_MIN_CHARGE) - GORILLA_HAYMAKER_THROW, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// Begins the wind-up.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/start_charge()
	var/mob/living/carbon/bearer = owner
	if(!iscarbon(bearer) || charging())
		return
	charge_started = world.time
	pressed_at = world.time
	aimed_zone = null
	// Before the lean: the puppets come up where the body rests, and lean with it from there
	raise_rig(bearer)
	bearer.apply_status_effect(/datum/status_effect/gorilla_windup, src)
	if(!bearer.has_status_effect(/datum/status_effect/gorilla_windup))
		drop_rig()
	vent_timer = addtimer(CALLBACK(src, PROC_REF(vent)), GORILLA_HAYMAKER_VENT_AFTER, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Ends the wind-up without throwing anything. Clears every timer and the look; with [keep_rig] the arms stay up, for a swing or to come down.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/stop_charge(keep_rig = FALSE)
	if(!keep_rig)
		drop_rig()
	charge_started = 0
	pressed_at = 0
	if(vent_timer)
		deltimer(vent_timer)
		vent_timer = null
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	var/mob/living/bearer = owner
	if(!QDELETED(bearer))
		var/datum/status_effect/gorilla_windup/windup = bearer.has_status_effect(/datum/status_effect/gorilla_windup)
		if(windup?.action == src)
			qdel(windup)

/// Held too long, or called off: a short cooldown, nothing thrown.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/vent()
	vent_timer = null
	if(!charging())
		return
	var/mob/living/bearer = owner
	stop_charge(keep_rig = TRUE)
	lower_rig()
	if(QDELETED(bearer))
		return
	gorilla_spend_pistons(bearer, GORILLA_PISTONS_VENTED)
	if(bearer.click_intercept == src)
		releasing = TRUE
		unset_click_ability(bearer, refund_cooldown = FALSE)
		releasing = FALSE

/// The wind-up's status effect went away under it (a stun, death): end quietly, no vent.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/windup_lost()
	if(!charging())
		return
	drop_rig()
	charge_started = 0
	pressed_at = 0
	if(vent_timer)
		deltimer(vent_timer)
		vent_timer = null
	if(release_timer)
		deltimer(release_timer)
		release_timer = null
	if(owner?.click_intercept == src)
		releasing = TRUE
		unset_click_ability(owner, refund_cooldown = FALSE)
		releasing = FALSE

/**
 * Lets it go at [target] (a mob, or a tile to swing into). Before the minimum wind-up the blow waits
 * and lands when it is done. Returns TRUE if anything was thrown or queued.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/release(atom/target)
	if(!charging() || release_timer)
		return FALSE
	var/held = world.time - charge_started
	// Thrown a throw's length before the minimum, so the blow lands on it
	if(held < GORILLA_HAYMAKER_MIN_CHARGE - GORILLA_HAYMAKER_THROW)
		var/datum/weakref/target_ref = WEAKREF(target)
		release_timer = addtimer(CALLBACK(src, PROC_REF(queued_release), target_ref), GORILLA_HAYMAKER_MIN_CHARGE - GORILLA_HAYMAKER_THROW - held, TIMER_STOPPABLE|TIMER_DELETE_ME)
		return TRUE
	throw_haymaker(target, max(held, GORILLA_HAYMAKER_MIN_CHARGE))
	return TRUE

/datum/action/cooldown/cyberware/gorilla_haymaker/proc/queued_release(datum/weakref/target_ref)
	release_timer = null
	if(!charging() || !IsAvailable())
		stop_charge()
		return
	// The charge it has when the blow lands
	throw_haymaker(target_ref?.resolve(), world.time - charge_started + GORILLA_HAYMAKER_THROW)

/**
 * The swing itself, for a charge of [held] deciseconds. The fist is thrown now and the blow lands as it arrives
 * (land()). Who it hits and where is settled here.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/throw_haymaker(atom/target, held)
	var/mob/living/carbon/human/bearer = owner
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	var/zone = aimed_zone
	stop_charge(keep_rig = TRUE)
	if(bearer?.click_intercept == src)
		releasing = TRUE
		unset_click_ability(bearer, refund_cooldown = FALSE)
		releasing = FALSE
	if(!ishuman(bearer) || !istype(arm) || arm.owner != bearer)
		drop_rig()
		return
	gorilla_spend_pistons(bearer, GORILLA_PISTONS_COOLDOWN)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/both as anything in gorilla_heavy_arms(bearer))
		COOLDOWN_START(both, slam_cooldown, both.punch_cooldown_time)
	bearer.changeNext_move(CLICK_CD_MELEE)
	// Swinging from inside a camo field drops it, as any blow does
	cyberware_camo_drop(bearer, "haymaker")
	var/mob/living/victim = gorilla_haymaker_victim(bearer, target)
	if(isnull(victim))
		var/turf/swing_at = isturf(target) ? target : get_step(bearer, bearer.dir)
		if(swing_at)
			// A turn takes the rig down (it is a picture of the old facing), and the swing is tg's lunge
			bearer.face_atom(swing_at)
			// The arm and the step in, or the lunge only: a fist that met nothing leaves no mark on the floor
			if(!swing())
				bearer.do_attack_animation(swing_at)
		else
			drop_rig()
		playsound(bearer, 'sound/items/weapons/punchmiss.ogg', 50, TRUE)
		bearer.visible_message(span_danger("[bearer]'s fist hits nothing but air!"), span_userdanger("Your fist hits nothing but air!"))
		bearer.adjust_staggered_up_to(1 SECONDS, 1 SECONDS)
		return
	var/charge = clamp((held - GORILLA_HAYMAKER_MIN_CHARGE) / (GORILLA_HAYMAKER_FULL_CHARGE - GORILLA_HAYMAKER_MIN_CHARGE), 0, 1)
	zone ||= victim.get_random_valid_zone(bearer.zone_selected)
	bearer.face_atom(victim)
	// The lunge only, as with the piston punch, when the arm can't be drawn: the sparks are the blow's mark
	if(!swing(victim, zone))
		bearer.do_attack_animation(victim)
	if(land_timer)
		deltimer(land_timer)
	land_timer = addtimer(CALLBACK(src, PROC_REF(land), WEAKREF(victim), charge, zone), GORILLA_HAYMAKER_THROW, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The thrown fist arrives on [zone] of the victim: the blow, as it was settled at the release.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/land(datum/weakref/victim_ref, charge, zone)
	land_timer = null
	var/mob/living/victim = victim_ref?.resolve()
	var/mob/living/carbon/human/bearer = owner
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	if(QDELETED(victim) || !ishuman(bearer) || !istype(arm) || arm.owner != bearer)
		return
	gorilla_haymaker_hit(bearer, victim, arm, charge, zone)

// =========================================================================
// THE ARM
// =========================================================================

/// The punching arm's side on the rig: the arm that carries this chip.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/punching_side()
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm = organ
	return (istype(arm) && arm.zone == BODY_ZONE_L_ARM) ? "l" : "r"

/**
 * The wind-up's poses for the way the rig faces: list(punching arm half drawn, punching arm drawn, guard arm half
 * up, guard arm up, punching arm thrown at nobody, guard arm at the throw, degrees the punching arm carries on by,
 * its piston then), each list(degrees up from hanging, pixels of piston) but the seventh.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/swing_poses()
	var/static/list/side_on = list(list(-60, -1), list(-115, 0), list(45, -1), list(70, -1), list(92, 7), list(20, 0), 43, 2)
	var/static/list/away = list(list(70, -3), list(115, -2), list(8, 0), list(12, 0), list(174, 6), list(5, 0), -14, 1)
	var/static/list/toward = list(list(70, -3), list(120, -2), list(8, 0), list(12, 0), list(14, 6), list(5, 0), -22, 2)
	if(rig.facing & (EAST|WEST))
		return side_on
	return rig.facing == NORTH ? away : toward

/**
 * Draws the bearer on the rig and starts the wind-up: after a beat with the real body still on show, the punching
 * arm draws back, half way by GORILLA_HAYMAKER_DRAW and all the way by GORILLA_HAYMAKER_DRAWN, and the other arm
 * comes up as a guard. Returns TRUE if the rig is up.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/raise_rig(mob/living/carbon/human/bearer)
	drop_rig()
	if(!ishuman(bearer) || bearer.body_position == LYING_DOWN || !isturf(bearer.loc) || !(bearer.dir in GLOB.cardinals))
		return FALSE
	// Faded (a camo field, a cloak): puppets would stand there in plain sight. Taller or shorter than the rig's cuts:
	// the picture is of a body of the usual height
	if(bearer.alpha < 255 || bearer.invisibility || bearer.mob_height != HUMAN_HEIGHT_MEDIUM)
		return FALSE
	rig = new(bearer, bearer.dir)
	if(!rig.rig_arms(GORILLA_HAYMAKER_RIG_HOLD))
		QDEL_NULL(rig)
		return FALSE
	// A step, a turn or a fall: the drawing comes down at once and the lean carries the rest of the wind-up
	rig.watch_body(CALLBACK(src, PROC_REF(drop_rig)), turns = TRUE)
	var/side = punching_side()
	var/guard = side == "l" ? "r" : "l"
	var/list/poses = swing_poses()
	// Facing the viewer the arm is drawn back behind its own shoulder
	var/back_layer = rig.facing == SOUTH ? bearer.layer - 0.01 : null
	var/datum/chrome_swing_beat/hold = new(GORILLA_HAYMAKER_RIG_HOLD)
	var/datum/chrome_swing_beat/half = new(GORILLA_HAYMAKER_DRAW - GORILLA_HAYMAKER_RIG_HOLD, CHROME_SWING_EASE_OUT)
	half.arm(side, rig.pose_of(side, poses[1][1], poses[1][2]), back_layer)
	half.arm(guard, rig.pose_of(guard, poses[3][1], poses[3][2]))
	var/datum/chrome_swing_beat/drawn = new(GORILLA_HAYMAKER_DRAWN - GORILLA_HAYMAKER_DRAW, CHROME_SWING_EASE_OUT)
	drawn.arm(side, rig.pose_of(side, poses[2][1], poses[2][2]))
	drawn.arm(guard, rig.pose_of(guard, poses[4][1], poses[4][2]))
	play_rig(list(hold, half, drawn))
	return TRUE

/// Plays [beats] on the rig from where its arms are, the body starting [shift_x], [shift_y] pixels from its rest. With [settle], every puppet eases onto the body's own offsets over the first frame.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/play_rig(list/beats, shift_x = 0, shift_y = 0, settle = FALSE)
	var/list/arms_from = list()
	var/list/arms = list()
	for(var/arm_side in list("l", "r"))
		arms_from[arm_side] = rig.arm_poses[arm_side] || list(0, 1)
		arms[arm_side] = rig.puppet("arm_[arm_side]")
	var/list/frames = chrome_swing_frames(beats, arms_from, shift_x, shift_y)
	var/list/rest
	if(settle)
		rest = list()
		var/list/offsets = list(rig.body.pixel_w, rig.body.pixel_x, rig.body.pixel_y, rig.body.pixel_z)
		for(var/key in rig.puppets)
			rest[rig.puppets[key]] = offsets
	chrome_swing_play(rig, frames, list(rig.puppet("body")), arms, null, rest)
	// Where the arms end up
	for(var/datum/chrome_swing_beat/beat as anything in beats)
		for(var/arm_side in beat.arms)
			var/list/pose = beat.arms[arm_side]
			rig.arm_poses[arm_side] = list(pose[1], pose[2])

/// How far the rig's puppets stand from where the hidden body is now: list(across, up). The lean and the tremble they still carry once the wind-up has let the body go.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/rig_leant()
	var/obj/effect/abstract/chrome_puppet/puppet = rig.puppet("body")
	var/mob/living/body = rig.body
	if(isnull(puppet))
		return list(0, 0)
	return list(puppet.pixel_x + puppet.pixel_w - body.pixel_x - body.pixel_w, puppet.pixel_y + puppet.pixel_z - body.pixel_y - body.pixel_z)

/// The wind-up's lean or tremble moved the hidden body: its puppets go with it ([eased] as tg eases an offset, or at once).
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/rig_follow(eased = TRUE)
	rig?.follow_offsets(eased)

/**
 * The swing on the rig, from where the wind-up left the arms: the fist thrown onto [zone] of [victim] (or through the
 * empty tile ahead) with a step in behind it, the follow-through, and back to rest; then the rig comes down. Called
 * once the wind-up has ended. Returns FALSE, with the rig down, if it can't be drawn: no rig, a bearer who has
 * turned away from the way it faces, or a victim who isn't straight ahead.
 */
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/swing(mob/living/victim, zone)
	var/mob/living/carbon/human/bearer = owner
	if(isnull(rig) || rig.body != bearer || rig.facing != bearer.dir || !isturf(bearer.loc))
		drop_rig()
		return FALSE
	// The arm is thrown the way the rig faces. A body a corner away, or on the bearer's own tile, isn't there
	if(victim && get_turf(victim) != get_step(bearer.loc, rig.facing))
		drop_rig()
		return FALSE
	var/list/leant = rig_leant()
	var/side = punching_side()
	var/guard = side == "l" ? "r" : "l"
	var/list/poses = swing_poses()
	var/list/way = chrome_swing_way(rig.facing)
	// The throw: onto the part, the body stepping in as far as it takes
	var/list/thrown = rig.pose_of(side, poses[5][1], poses[5][2])
	var/step = rig.facing & (EAST|WEST) ? GORILLA_HAYMAKER_STEP_MAX - 2 : GORILLA_HAYMAKER_STEP_MIN
	var/list/point = victim && gorilla_fist_target(bearer, victim, zone)
	if(point)
		var/list/reach = chrome_swing_reach(rig, side, point[1], point[2], way, GORILLA_HAYMAKER_STEP_MIN, (rig.facing & (EAST|WEST)) ? GORILLA_HAYMAKER_STEP_MAX : GORILLA_SWING_STEP_UPRIGHT, 0, GORILLA_SWING_EASY_LENGTH, GORILLA_SWING_MAX_LENGTH, thrown[1])
		step = reach[1]
		thrown = list(reach[2], reach[3])
	// The layers. Seen from the side the near arm is over everything and the far one under its own body; facing away
	// the thrown arm passes behind its own head; facing the viewer it comes out from behind its own shoulder
	var/over = bearer.layer + 0.01
	var/under = bearer.layer - 0.01
	var/throw_layer
	switch(rig.facing)
		if(NORTH)
			throw_layer = under
		if(SOUTH)
			throw_layer = over
		else
			throw_layer = rig.behind_body(side) ? under : max(bearer.layer, victim?.layer) + 0.01
	var/datum/chrome_swing_beat/throw_beat = new(GORILLA_HAYMAKER_OUT, CHROME_SWING_LINEAR, way[1] * step, way[2] * step)
	throw_beat.arm(side, thrown, throw_layer)
	throw_beat.arm(guard, rig.pose_of(guard, poses[6][1], poses[6][2]))
	// The fist is there a moment before the blow is due, and stays as it lands
	var/datum/chrome_swing_beat/dwell_beat = new(GORILLA_HAYMAKER_DWELL, CHROME_SWING_LINEAR, way[1] * step, way[2] * step)
	// The follow-through carries the fist on the way it was going, and the body half way back
	var/follow_step = round(step * 0.4)
	var/datum/chrome_swing_beat/follow_beat = new(GORILLA_HAYMAKER_FOLLOW, CHROME_SWING_EASE_OUT, way[1] * follow_step, way[2] * follow_step)
	follow_beat.arm(side, list(thrown[1] + poses[7] * rig.raise_sign(side), max(1, 1 + poses[8] / (GLOB.chrome_rig_arm_length["[rig.facing]"] || 10))))
	follow_beat.arm(guard, list(0, 1))
	var/datum/chrome_swing_beat/return_beat = new(GORILLA_HAYMAKER_RETURN, CHROME_SWING_EASE_IN_OUT)
	return_beat.arm(side, list(0, 1))
	return_beat.arm(guard, list(0, 1))
	if(rig.facing == NORTH)
		// Out from behind the head once it is clear of it
		return_beat.layer_once_under = list()
		return_beat.layer_once_under[side] = list(120, over)
	play_rig(list(throw_beat, dwell_beat, follow_beat, return_beat), leant[1], leant[2], settle = TRUE)
	if(rig_timer)
		deltimer(rig_timer)
	rig_timer = addtimer(CALLBACK(src, PROC_REF(drop_rig)), GORILLA_HAYMAKER_OUT + GORILLA_HAYMAKER_DWELL + GORILLA_HAYMAKER_FOLLOW + GORILLA_HAYMAKER_RETURN, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// A wind-up that ended with nothing thrown: the arms come down, then the rig does.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/lower_rig()
	if(isnull(rig) || QDELETED(rig.body))
		drop_rig()
		return
	var/list/leant = rig_leant()
	var/datum/chrome_swing_beat/lower = new(GORILLA_HAYMAKER_LOWER, CHROME_SWING_EASE_IN_OUT)
	for(var/arm_side in list("l", "r"))
		lower.arm(arm_side, list(0, 1), rig.body.layer + (rig.behind_body(arm_side) ? -0.01 : 0.01))
	play_rig(list(lower), leant[1], leant[2], settle = TRUE)
	if(rig_timer)
		deltimer(rig_timer)
	rig_timer = addtimer(CALLBACK(src, PROC_REF(drop_rig)), GORILLA_HAYMAKER_LOWER, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// Takes the rig down and shows the real body.
/datum/action/cooldown/cyberware/gorilla_haymaker/proc/drop_rig()
	if(rig_timer)
		deltimer(rig_timer)
		rig_timer = null
	QDEL_NULL(rig)

/// Who a haymaker at [target] hits: the clicked body if it is next to the bearer, else whoever stands in that tile.
/proc/gorilla_haymaker_victim(mob/living/bearer, atom/target)
	if(isliving(target) && target != bearer && bearer.Adjacent(target))
		return target
	var/turf/swing_at = isturf(target) ? target : get_turf(target)
	if(isnull(swing_at) || get_dist(bearer, swing_at) != 1)
		swing_at = get_step(bearer, get_dir(bearer, target) || bearer.dir)
	if(isnull(swing_at) || !bearer.Adjacent(swing_at))
		return null
	var/mob/living/lying
	for(var/mob/living/body in swing_at)
		if(body == bearer || body.stat == DEAD)
			continue
		if(body.body_position != LYING_DOWN)
			return body
		lying ||= body
	return lying

/// A haymaker lands on [victim]: [charge] 0 to 1 sets the damage and the reach. On [zone], else a part rolled from the one the bearer aims at. Only the blow: the swing is the caller's.
/proc/gorilla_haymaker_hit(mob/living/carbon/human/bearer, mob/living/victim, obj/item/organ/cyberimp/cyberware/gorilla_arms/arm, charge, zone)
	var/obj/item/bodypart/hand = bearer.get_bodypart(arm.zone)
	var/damage = round(GORILLA_HAYMAKER_MIN_DAMAGE + (GORILLA_HAYMAKER_MAX_DAMAGE - GORILLA_HAYMAKER_MIN_DAMAGE) * charge)
	var/reach = charge >= 1 ? GORILLA_HAYMAKER_MAX_RANGE : GORILLA_HAYMAKER_MIN_RANGE
	var/direction = get_dir(bearer, victim) || bearer.dir
	if(ishuman(victim))
		var/mob/living/carbon/human/human_victim = victim
		if(human_victim.check_block(bearer, damage, "[bearer]'s haymaker"))
			playsound(victim, 'sound/items/weapons/punchmiss.ogg', 40, TRUE)
			log_combat(bearer, victim, "attempted a haymaker on", "gorilla arms")
			return FALSE
	var/list/plan = gorilla_plan_knockback(victim, direction, reach)
	var/flies = plan[2] > 0 && victim.body_position != LYING_DOWN && !victim.buckled && !victim.anchored
	if(flies)
		victim.hv_hold_attack_message("[bearer] drives a fist into [victim] and sends [victim.p_them()] flying!", "[bearer] drives a fist into you and sends you flying!", "You drive a fist into [victim] and send [victim.p_them()] flying!", bearer, vision_range = DEFAULT_MESSAGE_RANGE)
	else
		victim.hv_hold_attack_message("[bearer] drives a fist into [victim]!", "[bearer] drives a fist into you!", "You drive a fist into [victim]!", bearer, vision_range = DEFAULT_MESSAGE_RANGE)
	zone ||= victim.get_random_valid_zone(bearer.zone_selected)
	var/armour = victim.run_armor_check(zone, MELEE, armour_penetration = hand?.unarmed_effectiveness)
	var/list/wounds_before
	if(iscarbon(victim))
		var/mob/living/carbon/carbon_victim = victim
		wounds_before = carbon_victim.gorilla_wound_snapshot()
	if(flies)
		// The flight leaves its own trail and the wall its own marks; no #509 fan on top of them
		gorilla_hold_spray(victim)
	var/dealt = victim.apply_damage(damage, BRUTE, zone, armour, wound_bonus = GORILLA_PUNCH_WOUND_BONUS + 5, attack_direction = direction, attacking_item = hand)
	var/wounded = FALSE
	if(iscarbon(victim) && !QDELETED(victim))
		var/mob/living/carbon/carbon_victim = victim
		if(dealt >= GORILLA_STRAIN_MIN_DAMAGE)
			gorilla_add_strain(carbon_victim, check_zone(zone), bearer, arm.snap_strain, hand, direction)
		wounded = gorilla_new_wound(carbon_victim, wounds_before)
	victim.hv_flush_hit()
	gorilla_register_aggression(victim, bearer)
	gorilla_haymaker_impact_sound(victim)
	arm.gorilla_punch_fx(bearer, victim, TRUE, zone)
	cyberware_flash_fx(victim, 0.2 SECONDS)
	shake_camera(victim, 3, 2)
	if(flies && !QDELETED(victim))
		gorilla_launch(victim, bearer, direction, reach, GORILLA_HAYMAKER_SPEED, FALSE, TRUE, wounded)
	log_combat(bearer, victim, "landed a haymaker on", "gorilla arms", "(charge [round(charge * 100)]%)")
	return TRUE

/// A haymaker from [bearer] at [target] with whichever arm is ready, wound up for [hold_time], onto [zone] if one is given. For an AI. Returns TRUE if it began.
/proc/gorilla_try_haymaker(mob/living/carbon/human/bearer, atom/target, hold_time = GORILLA_HAYMAKER_FULL_CHARGE, zone)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		for(var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker in arm.actions)
			if(haymaker.owner == bearer && haymaker.wind_up_at(target, hold_time, zone))
				return TRUE
	return FALSE

/// Starts the pistons' shared cooldown on [bearer] and shows it on every haymaker chip.
/proc/gorilla_spend_pistons(mob/living/bearer, time)
	gorilla_cooldown(bearer, COOLDOWN_GORILLA_PISTONS, time)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		for(var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker in arm.actions)
			haymaker.StartCooldownSelf(time)

// =========================================================================
// THE WIND-UP
// =========================================================================

/// The bearer winding up a haymaker: slowed, empty-handed of grabs, leaning back, trembling at full charge.
/datum/status_effect/gorilla_windup
	id = "gorilla_windup"
	alert_type = null
	duration = GORILLA_HAYMAKER_VENT_AFTER + 1 SECONDS
	tick_interval = 0.2 SECONDS
	status_type = STATUS_EFFECT_UNIQUE
	/// The haymaker winding up
	var/datum/action/cooldown/cyberware/gorilla_haymaker/action
	/// Trembling at full charge
	var/trembling = FALSE
	/// Which way the tremble's next pixel goes
	var/tremble_side = 1

/datum/status_effect/gorilla_windup/on_creation(mob/living/new_owner, datum/action/cooldown/cyberware/gorilla_haymaker/action)
	src.action = action
	return ..()

/datum/status_effect/gorilla_windup/on_apply()
	if(owner.stat != CONSCIOUS)
		return FALSE
	owner.add_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup)
	if(owner.pulling)
		owner.stop_pulling()
	RegisterSignal(owner, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))
	RegisterSignal(owner, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_turned))
	lean()
	return TRUE

/**
 * Leans back from the way they face now, further as the charge builds, so the whole wind-up moves: away from the
 * target seen from the side (a pixel at once, GORILLA_HAYMAKER_LEAN at full charge), half as far up the screen when
 * they face the viewer and down it when they face away. A tracked offset tg eases to and removes cleanly.
 */
/datum/status_effect/gorilla_windup/proc/lean()
	var/charged = action?.charging() ? clamp((world.time - action.charge_started) / GORILLA_HAYMAKER_FULL_CHARGE, 0, 1) : 0
	var/back_by = 1 + round(charged * (GORILLA_HAYMAKER_LEAN - 1))
	var/up_by = CEILING(back_by / 2, 1)
	var/back = REVERSE_DIR(owner.dir)
	var/dx = (back & EAST) ? back_by : ((back & WEST) ? -back_by : 0)
	var/dz = (back & NORTH) ? up_by : ((back & SOUTH) ? -up_by : 0)
	owner.add_offsets(id, x_add = dx, z_add = dz)
	// Drawn on the rig, the puppets lean as the hidden body does
	action?.rig_follow(TRUE)

/// Turned mid wind-up: the lean turns with them.
/datum/status_effect/gorilla_windup/proc/on_turned(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	if(old_dir != new_dir)
		lean()

/datum/status_effect/gorilla_windup/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOB_STATCHANGE, COMSIG_ATOM_POST_DIR_CHANGE))
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/gorilla_windup)
	owner.remove_offsets("[id]_tremble", animate = FALSE)
	owner.remove_offsets(id)
	var/datum/action/cooldown/cyberware/gorilla_haymaker/haymaker = action
	action = null
	haymaker?.windup_lost()

/datum/status_effect/gorilla_windup/Destroy()
	action = null
	return ..()

/datum/status_effect/gorilla_windup/tick(seconds_between_ticks)
	// Stunned, cuffed or knocked down mid wind-up: the swing is lost
	if(HAS_TRAIT(owner, TRAIT_INCAPACITATED) || HAS_TRAIT(owner, TRAIT_HANDS_BLOCKED) || owner.body_position == LYING_DOWN)
		qdel(src)
		return
	if(!action?.charging())
		return
	lean()
	if(world.time - action.charge_started < GORILLA_HAYMAKER_FULL_CHARGE)
		return
	// Full: a tremble for as long as it is held, a pixel either way. A tracked offset, so it can't leave them
	// off their tile, and never the pixel of nothing tg's random jitter can roll
	trembling = TRUE
	tremble_side = -tremble_side
	owner.add_offsets("[id]_tremble", w_add = tremble_side, animate = FALSE)
	action.rig_follow(FALSE)

/datum/status_effect/gorilla_windup/proc/on_stat_change(datum/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat != CONSCIOUS)
		qdel(src)

/datum/movespeed_modifier/gorilla_windup
	multiplicative_slowdown = 1.5
