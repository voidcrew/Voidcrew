// The impaling lunge. A lunge that arrives with both blades on someone already hurt or down skewers them:
// held up on the blades for a beat (pinned to the wall for longer, if one is right behind them), then the
// blades rip out with a spray and they drop. The bearer is rooted with full hands the whole time, and
// the victim's hands stay free, so they can still shoot.

/// Whether a lunge arriving with [housings] skewers [victim]: both blades out and able, a person no bigger
/// than a person, and already hurt or down.
/proc/mantis_can_impale(mob/living/lunger, mob/living/victim, list/housings)
	if(!iscarbon(victim) || victim.stat == DEAD || victim.mob_size > MOB_SIZE_HUMAN)
		return FALSE
	if(!lunger.hv_can_land_aimed_crits())
		return FALSE
	var/list/blades = mantis_housing_blades(housings)
	if(length(blades) < 2)
		return FALSE
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in blades)
		if(!(blade.gore_moves & MANTIS_MOVE_IMPALE))
			return FALSE
	if(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT) || victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	if(victim.buckled || !isturf(victim.loc))
		return FALSE
	if(victim.health <= victim.maxHealth * MANTIS_IMPALE_HEALTH_FRACTION)
		return TRUE
	return victim.body_position == LYING_DOWN || victim.stat >= SOFT_CRIT || HAS_TRAIT(victim, TRAIT_INCAPACITATED)

/// Skewers [victim] on the blades of [housings]. Returns TRUE if it took hold. [from] is where the lunge set
/// out, for the [glide] the lunging body takes to reach them (mantis_lunge_dash_fx()).
/proc/mantis_start_impale(datum/action/cooldown/cyberware/mantis_lunge/lunge, mob/living/carbon/lunger, mob/living/carbon/victim, list/housings, knockdown, turf/from, glide = MANTIS_LUNGE_GLIDE)
	var/datum/mantis_impale/skewer = new(lunger, victim, housings, knockdown)
	var/turf/landed = get_turf(lunger)
	if(from && landed && from != landed)
		skewer.glide_w = (from.x - landed.x) * ICON_SIZE_X
		skewer.glide_z = (from.y - landed.y) * ICON_SIZE_Y
		skewer.glide_time = glide
	if(!skewer.start())
		qdel(skewer)
		return FALSE
	lunge?.impale = skewer
	return TRUE

/datum/action/cooldown/cyberware/mantis_lunge
	/// The skewer this lunge is holding, while it holds.
	var/datum/mantis_impale/impale

/**
 * # The skewer
 *
 * The beats, from the approved storyboard: the lunging body glides in, blades out; the points reach them
 * and go in, and the two are drawn together; the victim is held up on the blades; the bearer pulls back, rips
 * the blades out and the victim drops. From the glide to the drop the bearer is drawn by the blade rig
 * (mantis_rig.dm): the far blade, the far arm and the bearer's body under the victim, the near arm and the
 * near blade over them, the steel inside them cut out.
 */
/datum/mantis_impale
	var/mob/living/carbon/bearer
	var/mob/living/carbon/victim
	/// The housings whose blades went in.
	var/list/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housings
	/// The way the lunge travelled. The tips come out on that side.
	var/lunge_dir
	/// The way it is drawn (mantis_rig_facing()).
	var/facing
	/// TRUE when a wall right behind them takes the points.
	var/wall_pin = FALSE
	/// How long they are held.
	var/hold_time = MANTIS_IMPALE_HOLD
	/// How long they go down for when the blades come out.
	var/knockdown = 2 SECONDS
	var/started_at = 0
	/// Damage the bearer has taken since it began.
	var/taken = 0
	var/tick_timer
	/// The bearer drawn around the victim, from the start of the glide in.
	var/datum/mantis_rig/rig
	/// The landing, when the points reach them.
	var/rig_timer
	/// Where the lunging body glides in from, in pixels off the bearer's tile, and how long it takes.
	var/glide_w = 0
	var/glide_z = 0
	var/glide_time = 0
	/// The beat drawn now.
	var/beat
	/// How far tg had them turned to lie down when they came up on the blades, or 0.
	var/hoist_angle = 0
	/// Degrees they are tipped back about their feet at the rip, to take back out.
	var/tilt_angle = 0
	/// The way they faced before they were turned onto the blades.
	var/prior_dir
	var/running = FALSE
	/// TRUE from the pull-back until the blades are out.
	var/ripping = FALSE
	/// Pixels they hang up from where the hold has them: -1 while they sag on the blades (set_sag()).
	var/sag = 0

/datum/mantis_impale/New(mob/living/carbon/bearer, mob/living/carbon/victim, list/housings, knockdown)
	. = ..()
	src.bearer = bearer
	src.victim = victim
	src.housings = housings.Copy()
	if(isnum(knockdown))
		src.knockdown = knockdown

/datum/mantis_impale/Destroy()
	if(running)
		finish()
	QDEL_NULL(rig)
	bearer = null
	victim = null
	housings = null
	return ..()

/datum/mantis_impale/proc/start()
	if(running || QDELETED(bearer) || QDELETED(victim))
		return FALSE
	lunge_dir = get_dir(bearer, victim) || bearer.dir
	facing = mantis_rig_facing(bearer, victim)
	var/turf/behind = get_step(victim, lunge_dir)
	wall_pin = !isnull(behind) && hv_blood_spray_blocked(behind)
	hold_time = wall_pin ? MANTIS_IMPALE_PIN_HOLD : MANTIS_IMPALE_HOLD
	running = TRUE
	started_at = world.time
	bearer.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), MANTIS_IMPALE_TRAIT)
	ADD_TRAIT(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT)
	// Turned onto the blades and brought up off the floor if they were on it. The rig draws the lunging body
	// gliding in, blades out and short of them (the bearer's own lunge pose would lie over them); the points
	// reach them as it lands (begin_rig()).
	prior_dir = victim.dir
	victim.setDir(mantis_face_dir(victim, bearer))
	hoist()
	place_victim(0, 0)
	mantis_pose_blades(housings, MANTIS_POSE_LUNGE)
	put_up_rig()
	if(rig)
		show_beat("arrive", glide_time, glide_w, glide_z)
	rig_timer = addtimer(CALLBACK(src, PROC_REF(begin_rig)), max(glide_time, world.tick_lag), TIMER_STOPPABLE|TIMER_DELETE_ME)
	// The lunge's own slash, drawn as it landed, would float over the blades.
	for(var/obj/effect/abstract/cyberware_anim/picture in victim.vis_contents)
		if(findtext(picture.icon_state, "impact_") == 1)
			qdel(picture)
	RegisterSignal(bearer, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_bearer_damaged))
	RegisterSignals(bearer, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_lost))
	RegisterSignals(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED), PROC_REF(on_lost))
	RegisterSignal(victim, COMSIG_LIVING_POST_UPDATE_TRANSFORM, PROC_REF(on_victim_turned))
	if(wall_pin)
		victim.visible_message(
			span_danger("[bearer] drives both blades through [victim] and pins [victim.p_them()] to the wall!"),
			span_userdanger("Two blades punch through you and into the wall!"),
		)
	else
		victim.visible_message(
			span_danger("[bearer] drives both blades through [victim] and lifts [victim.p_them()] off [victim.p_their()] feet!"),
			span_userdanger("Two blades punch through you!"),
		)
	schedule_tick()
	return TRUE

/// The bearer is drawn by the rig from here to the drop.
/datum/mantis_impale/proc/put_up_rig()
	if(rig)
		return
	rig = new(bearer, victim, facing, model(), "impale")
	if(!rig.start())
		QDEL_NULL(rig)

/// The lunging body has landed: the two are drawn together, and the victim slides onto the blades.
/datum/mantis_impale/proc/begin_rig()
	rig_timer = null
	if(!running || ripping)
		return
	put_up_rig()
	// Whole blades, the victim over the steel they have slid onto: they cover it as they come.
	show_beat("contact", MANTIS_IMPALE_CONTACT_BEAT)
	addtimer(CALLBACK(src, PROC_REF(stab)), MANTIS_IMPALE_CONTACT_BEAT, TIMER_DELETE_ME)

/// The blades are in: the points come out of the back wet, with a burst of blood and a crackle of their light.
/datum/mantis_impale/proc/stab()
	if(!running || ripping)
		return
	if(rig)
		rig.wet = TRUE
	show_beat("enter", 0)
	// The crackle is at the points, so it lasts only while they are still: it is gone as the hoist begins.
	switch(facing)
		if(NORTH)
			rig?.burst("enter_puff", 0.25 SECONDS, "T", under = TRUE)
			rig?.burst("enter_spark", MANTIS_IMPALE_ENTER_BEAT, "tips", blood = FALSE)
		if(SOUTH)
			rig?.burst("enter_puff", 0.25 SECONDS, "tips")
			rig?.burst("enter_spark", MANTIS_IMPALE_ENTER_BEAT, "tips", blood = FALSE)
		else
			rig?.burst("enter_puff", 0.25 SECONDS, "T")
			rig?.burst("enter_spark", MANTIS_IMPALE_ENTER_BEAT, "near", blood = FALSE)
	addtimer(CALLBACK(src, PROC_REF(lift), 1), MANTIS_IMPALE_ENTER_BEAT, TIMER_DELETE_ME)

/**
 * The hoist from the stab to the hold, a frame at a time in the side views: the victim and the blades in them
 * rise together, so the steel stays where it went in. Seen from the front or back it is one step.
 */
/datum/mantis_impale/proc/lift(step)
	if(!running || ripping)
		return
	if(!mantis_rig_beat("impale", "lift[step]", facing))
		hang()
		return
	show_beat("lift[step]", 0)
	addtimer(CALLBACK(src, PROC_REF(lift), step + 1), MANTIS_IMPALE_STEP, TIMER_DELETE_ME)

/**
 * Held up: the victim hangs on the blades until the pull-back. Twice they sag a pixel and are heaved back up,
 * and the blades and the arms holding them dip with them in the same frame (set_sag()).
 */
/datum/mantis_impale/proc/hang()
	show_beat("hold", 0)
	if(!running || ripping || QDELETED(victim))
		return
	for(var/again in 0 to 1)
		var/at = MANTIS_IMPALE_SAG_AFTER + again * MANTIS_IMPALE_SAG_EVERY
		addtimer(CALLBACK(src, PROC_REF(set_sag), -1), at, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(set_sag), 0), at + MANTIS_IMPALE_SAG_FOR, TIMER_DELETE_ME)

/// In the hold they hang [new_sag] pixels up from where the hold has them (a sag is negative).
/datum/mantis_impale/proc/set_sag(new_sag)
	if(!running || ripping || beat != "hold" || sag == new_sag)
		return
	sag = new_sag
	show_beat("hold", 0)

/**
 * Draws [new_beat] (mantis_rig_beat()): the bearer's arms and lean, and the victim drawn onto the blades.
 * Up against a wall the victim stays where they are and the bearer comes the whole way; from a diagonal the
 * two meet halfway up or down the screen. Pictures only.
 */
/datum/mantis_impale/proc/show_beat(new_beat, time = 0.1 SECONDS, from_w = 0, from_z = 0)
	if(!running || (ripping && (new_beat == "hold" || findtext(new_beat, "lift") == 1)))
		return
	var/list/spec = mantis_rig_beat("impale", new_beat, facing)
	if(!spec)
		return
	beat = new_beat
	var/target_w = spec[MANTIS_RIG_TARGET_W]
	var/target_z = spec[MANTIS_RIG_TARGET_Z]
	var/extra_w = 0
	var/extra_z = 0
	if((facing & (EAST|WEST)) && (lunge_dir & (NORTH|SOUTH)))
		var/half = (lunge_dir & NORTH) ? ICON_SIZE_Y / 2 : -ICON_SIZE_Y / 2
		extra_z = half
		target_z -= half
	if(wall_pin)
		extra_w -= target_w
		extra_z -= target_z
		target_w = 0
		target_z = 0
	// Sagging in the hold (set_sag()): the steel in them and the arms holding them go with them. Not against a
	// wall: the points are in it.
	var/dip = (new_beat == "hold" && !wall_pin) ? sag : 0
	rig?.show(new_beat, extra_w, extra_z, time, from_w, from_z, ride_z = dip)
	place_victim(target_w, target_z + dip, time)
	set_tilt(spec[MANTIS_RIG_TILT])

/// Draws the victim [w], [z] pixels off their tile (and upright, if brought up off the floor), over [time].
/datum/mantis_impale/proc/place_victim(w, z, time = 0.1 SECONDS)
	// Brought upright off the floor: tg draws someone lying down a little low.
	var/upright = hoist_angle ? -PIXEL_Y_OFFSET_LYING : 0
	// Drawn onto the blades as fast as the rig leans in (tg's own glide takes twice as long), so the points
	// are at their front as they arrive, not after.
	var/from_w = victim.pixel_w
	var/from_z = victim.pixel_z
	victim.add_offsets(MANTIS_IMPALE_TRAIT, w_add = w, z_add = z + upright, animate = FALSE)
	var/to_w = victim.pixel_w
	var/to_z = victim.pixel_z
	if((to_w == from_w && to_z == from_z) || !time)
		return
	victim.pixel_w = from_w
	victim.pixel_z = from_z
	animate(victim, pixel_w = to_w, pixel_z = to_z, time = time, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// The matrix tipping a body [angle] degrees about its feet (clockwise), after [base].
/proc/mantis_tip_matrix(matrix/base, angle)
	var/matrix/turned = matrix(base)
	turned.Translate(0, MANTIS_TIP_FEET)
	turned.Turn(angle)
	turned.Translate(0, -MANTIS_TIP_FEET)
	return turned

/// Where the point [x], [y] (pixels from a sprite's middle, y up) is drawn once the sprite is turned [angle]
/// degrees clockwise about [about_x], [about_y].
/proc/mantis_turn_point(x, y, angle, about_x, about_y)
	var/dx = x - about_x
	var/dy = y - about_y
	return list(about_x + dx * cos(angle) + dy * sin(angle), about_y - dx * sin(angle) + dy * cos(angle))

/**
 * [body] falls in one motion from how it was drawn on the blades (offsets [from_w], [from_z], [from_y], upright
 * and tipped back [from_angle] degrees about its feet) to how tg has it now, lying or standing, turning about
 * the point [pivot] pixels under its middle (its feet for a fall backwards, 0 for a drop in place). It is the
 * real body the whole way and ends on tg's own turn and offsets, so nothing takes over at the end. Gravity:
 * slow off the blades, fast at the floor. A picture only: tg's lying state is set before this.
 */
/proc/mantis_drop_body(mob/living/body, from_w, from_z, from_y, from_angle, pivot, time)
	if(QDELETED(body))
		return
	var/matrix/to_transform = matrix(body.transform)
	var/to_w = body.pixel_w
	var/to_z = body.pixel_z
	var/to_y = body.pixel_y
	var/to_angle = (body.body_position == LYING_DOWN && body.rotate_on_lying) ? body.lying_angle : 0
	if(to_angle > 180)
		to_angle -= 360
	// The turning point at the start (the picture tipped about the feet) and at the end (tg turns about the middle).
	var/list/start = mantis_turn_point(0, -pivot, from_angle, 0, -MANTIS_TIP_FEET)
	var/start_x = start[1] + from_w
	var/start_y = start[2] + from_z + from_y
	var/list/end = mantis_turn_point(0, -pivot, to_angle, 0, 0)
	var/end_x = end[1] + to_w
	var/end_y = end[2] + to_z + to_y
	var/steps = 4
	for(var/step in 0 to steps)
		var/fallen = (step / steps) ** 2
		var/matrix/turned = to_transform
		var/step_w = to_w
		var/step_z = to_z
		if(step < steps)
			turned = matrix()
			turned.Translate(0, pivot)
			turned.Turn(from_angle + (to_angle - from_angle) * fallen)
			turned.Translate(0, -pivot)
			step_w = round(start_x + (end_x - start_x) * fallen, 1)
			step_z = round(start_y + (end_y - start_y) * fallen + pivot - to_y, 1)
		// The first step puts the picture back where it was drawn at once: it replaces tg's own turn, and
		// whatever else this tick started on the body.
		if(step == 0)
			animate(body, transform = turned, pixel_w = step_w, pixel_z = step_z, pixel_y = to_y, time = 0)
		else
			animate(transform = turned, pixel_w = step_w, pixel_z = step_z, time = time / steps)

/// Tips the victim back to [angle] degrees about their feet.
/datum/mantis_impale/proc/set_tilt(angle)
	if(angle == tilt_angle || QDELETED(victim))
		return
	var/matrix/turned = mantis_tip_matrix(victim.transform, angle - tilt_angle)
	tilt_angle = angle
	animate(victim, transform = turned, time = 0.1 SECONDS, flags = ANIMATION_PARALLEL)

/// Takes the tip back out at once, before anything else turns them.
/datum/mantis_impale/proc/untilt()
	if(tilt_angle && !QDELETED(victim))
		victim.transform = mantis_tip_matrix(victim.transform, -tilt_angle)
	tilt_angle = 0

/**
 * Someone skewered off the floor comes up with the blades and is drawn upright for the hold. Only the
 * picture turns: tg still has them lying down, with everything that goes with it. Skipped for a resized
 * body, whose lying turn carries a shift that wouldn't come back out cleanly.
 */
/datum/mantis_impale/proc/hoist()
	if(hoist_angle || victim.body_position != LYING_DOWN || !victim.rotate_on_lying || !victim.lying_angle)
		return
	if(victim.current_size != RESIZE_DEFAULT_SIZE)
		return
	hoist_angle = victim.lying_angle
	var/matrix/upright = matrix(victim.transform)
	upright.Turn(-hoist_angle)
	victim.transform = upright

/// Gives back tg's lying turn. [fall] drops them into it instead of snapping.
/datum/mantis_impale/proc/unhoist(fall = FALSE)
	if(!hoist_angle)
		return
	var/matrix/lying = matrix(victim.transform)
	lying.Turn(hoist_angle)
	hoist_angle = 0
	if(fall)
		animate(victim, transform = lying, time = 0.2 SECONDS, easing = EASE_IN, flags = ANIMATION_PARALLEL)
	else
		victim.transform = lying

/// tg turned them while they hang on the blades (got up, or went down): its turn stands, the picture stays upright.
/datum/mantis_impale/proc/on_victim_turned(datum/source, resize, new_lying_angle, is_opposite_angle)
	SIGNAL_HANDLER
	if(!running)
		return
	// tg turned the upright picture by the change, and turns add up: undoing the hoist leaves tg's own.
	untilt()
	unhoist()
	hoist()
	if(beat)
		show_beat(beat)
	else
		place_victim(0, 0)

/// The model of the blades in them, for the pictures.
/datum/mantis_impale/proc/model()
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
		return blade.base_icon_state
	return "mantis"

/datum/mantis_impale/proc/schedule_tick()
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), 0.2 SECONDS, TIMER_STOPPABLE|TIMER_DELETE_ME)

/datum/mantis_impale/proc/tick()
	tick_timer = null
	if(!running)
		return
	if(!holds())
		finish()
		return
	if(world.time - started_at >= hold_time)
		rip()
		return
	schedule_tick()

/// Whether the hold still holds: both alive and side by side, the blades still out, the bearer on their feet.
/datum/mantis_impale/proc/holds()
	if(QDELETED(bearer) || QDELETED(victim) || bearer.stat != CONSCIOUS || victim.stat == DEAD)
		return FALSE
	if(HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || HAS_TRAIT(bearer, TRAIT_FLOORED))
		return FALSE
	if(!isturf(bearer.loc) || !isturf(victim.loc) || bearer.z != victim.z || get_dist(bearer, victim) > 1)
		return FALSE
	return length(mantis_housing_blades(housings)) >= 1

/**
 * The blades rip out. [half] when the bearer lost their grip: it tears less on the way out, with no
 * pull-back. Otherwise first the pull-back: the bearer draws back while they still hang there, then tears
 * the blades out, and a beat later they come free and the body drops (tear_out()).
 */
/datum/mantis_impale/proc/rip(half = FALSE)
	if(!running || ripping)
		return
	// A lost grip is a jolt, not a pull: they come straight off.
	if(half)
		tear_out(TRUE)
		return
	ripping = TRUE
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	// The side views draw the pull-back in steps, the steel coming out a little at a time.
	if(rig && mantis_rig_beat("impale", "pull1", facing))
		for(var/step in 1 to 3)
			addtimer(CALLBACK(src, PROC_REF(show_beat), "pull[step]", 0), (step - 1) * MANTIS_IMPALE_PULL_STEP, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(show_rip)), 3 * MANTIS_IMPALE_PULL_STEP, TIMER_DELETE_ME)
		addtimer(CALLBACK(src, PROC_REF(tear_out), half), 3 * MANTIS_IMPALE_PULL_STEP + MANTIS_IMPALE_PULL_BEAT - MANTIS_IMPALE_RIP_BEAT, TIMER_DELETE_ME)
		return
	show_beat("pull")
	addtimer(CALLBACK(src, PROC_REF(show_rip)), MANTIS_IMPALE_RIP_BEAT, TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(tear_out), half), MANTIS_IMPALE_PULL_BEAT, TIMER_DELETE_ME)

/// The blades tear up and down out of them: blood sprays out of the back as they come free.
/datum/mantis_impale/proc/show_rip()
	if(!running)
		return
	show_beat("rip")
	rig?.burst("rip_spray", 0.4 SECONDS, "T", under = (facing == NORTH))

/// The blades come out after the pull-back: the damage, the spray and the fall. The bearer holds the
/// last pose for the drop, then is drawn as usual again.
/datum/mantis_impale/proc/tear_out(half = FALSE)
	if(!running)
		return
	var/list/blades = mantis_housing_blades(housings)
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/first_blade = length(blades) ? blades[1] : null
	var/damage = half ? MANTIS_IMPALE_RIP_DAMAGE * 0.5 : MANTIS_IMPALE_RIP_DAMAGE
	var/mob/living/carbon/held = victim
	var/mob/living/carbon/holder = bearer
	var/rip_dir = lunge_dir
	// The rig stays up for the drop; finish() would take it down.
	var/datum/mantis_rig/dropping = rig
	rig = null
	// They fall from where they are drawn now: tipped back about their feet, up on the blades.
	var/fall_w = held?.pixel_w
	var/fall_z = held?.pixel_z
	var/fall_y = held?.pixel_y
	var/fall_tilt = tilt_angle
	// Only a body drawn upright on the blades (brought up off the floor, or standing) at its usual size.
	var/can_fall = held && held.current_size == RESIZE_DEFAULT_SIZE && (hoist_angle || held.body_position != LYING_DOWN || !held.rotate_on_lying || !held.lying_angle)
	var/side = facing & (EAST|WEST)
	var/face = held?.dir
	finish(settle = !can_fall)
	if(!QDELETED(held) && held.stat != DEAD)
		mantis_note_hit(held, holder)
		if(half)
			held.hv_hold_attack_message("[holder] loses [holder.p_their()] grip on [held]!", "[holder] loses [holder.p_their()] grip on you!", null, null, null, COMBAT_MESSAGE_RANGE)
		else
			held.hv_hold_attack_message("[holder] rips both blades out of [held]!", "[holder] rips both blades out of you!", null, null, null, COMBAT_MESSAGE_RANGE)
		var/armour = held.run_armor_check(BODY_ZONE_CHEST, MELEE, armour_penetration = first_blade?.armour_penetration, silent = TRUE)
		for(var/i in 1 to max(1, length(blades)))
			held.apply_damage(
				damage,
				BRUTE,
				BODY_ZONE_CHEST,
				armour,
				wound_bonus = MANTIS_IMPALE_RIP_WOUND_BONUS,
				sharpness = SHARP_EDGED,
				attack_direction = rip_dir,
				attacking_item = first_blade,
			)
			if(QDELETED(held))
				break
		if(!QDELETED(held))
			held.hv_flush_hit()
		if(!QDELETED(held))
			held.hv_blood_spray(rip_dir, half ? 2 : 3)
			if(wall_pin)
				held.hv_blood_lay_wall_spray(get_turf(held), rip_dir, held.get_blood_dna_list(), held.get_static_viruses())
			// Someone held up standing goes down now. tg would slide them the 6 px down into its lying offset
			// on its own clock while the fall draws them; give them the offset first, so the fall draws it.
			var/was_standing = can_fall && held.body_position != LYING_DOWN && held.rotate_on_lying
			if(was_standing)
				held.add_offsets(LYING_DOWN_TRAIT, y_add = PIXEL_Y_OFFSET_LYING, animate = FALSE)
			held.Knockdown(knockdown)
			if(was_standing && held.body_position != LYING_DOWN)
				held.remove_offsets(LYING_DOWN_TRAIT, animate = FALSE)
			playsound(held, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
			for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in blades)
				blade.drench(held, light = TRUE)
			if(half && !QDELETED(holder))
				holder.set_staggered_if_lower(1.5 SECONDS)
			log_combat(holder, held, half ? "lost the grip on" : "ripped the mantis blades out of")
	// The fall: one motion from the blades to the floor, ending where tg lays them. Seen from the side they
	// were tipped back, so they land on their back, head away from the bearer, still facing them.
	if(can_fall && !QDELETED(held))
		if(side && held.body_position == LYING_DOWN && held.rotate_on_lying)
			held.set_lying_angle(side == EAST ? LYING_ANGLE_EAST : LYING_ANGLE_WEST)
		if(face)
			held.setDir(face)
		mantis_drop_body(held, fall_w, fall_z, fall_y, fall_tilt, side ? MANTIS_TIP_FEET : 0, MANTIS_IMPALE_DROP_BEAT)
	// The drop, drawn once they are down (their layer is the floor's now), then the real bearer fades back in.
	if(dropping && !QDELETED(dropping))
		dropping.show("drop", time = MANTIS_IMPALE_DROP_BEAT)
		addtimer(CALLBACK(dropping, TYPE_PROC_REF(/datum/mantis_rig, hand_back)), MANTIS_IMPALE_DROP_BEAT, TIMER_DELETE_ME)

/// The bearer is hit while holding them up. Enough of it and they lose the grip.
/datum/mantis_impale/proc/on_bearer_damaged(datum/source, damage_dealt, damagetype)
	SIGNAL_HANDLER
	if(!running || damage_dealt <= 0)
		return
	taken += damage_dealt
	if(taken >= MANTIS_IMPALE_BREAK_DAMAGE)
		INVOKE_ASYNC(src, PROC_REF(rip), TRUE)

/// Either of them died, was deleted or was moved off the other.
/datum/mantis_impale/proc/on_lost(datum/source)
	SIGNAL_HANDLER
	if(!running)
		return
	// Moving within the hold (a nudge onto the same spot) is fine; apart is not.
	if(!holds())
		finish()

/**
 * Lets go of both, puts everything back, and ends. Without [settle] the victim's picture is put back at once
 * for the drop to draw the fall from (tear_out()); with it they ease back the way tg would.
 */
/datum/mantis_impale/proc/finish(settle = TRUE)
	if(!running)
		return
	running = FALSE
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	if(rig_timer)
		deltimer(rig_timer)
		rig_timer = null
	QDEL_NULL(rig)
	if(bearer)
		UnregisterSignal(bearer, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		bearer.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_HANDS_BLOCKED), MANTIS_IMPALE_TRAIT)
		for(var/datum/action/cooldown/cyberware/mantis_lunge/lunge as anything in mantis_lunge_actions(bearer))
			if(lunge.impale == src)
				lunge.impale = null
	if(victim)
		UnregisterSignal(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_POST_UPDATE_TRANSFORM))
		REMOVE_TRAIT(victim, TRAIT_IMMOBILIZED, MANTIS_IMPALE_TRAIT)
		victim.remove_offsets(MANTIS_IMPALE_TRAIT, animate = settle)
		if(!QDELETED(victim))
			untilt()
			unhoist(fall = settle)
			// Still on the floor: back to the way tg laid them.
			if(settle && victim.body_position == LYING_DOWN && prior_dir)
				victim.setDir(prior_dir)
	if(housings)
		mantis_pose_blades(housings, MANTIS_POSE_GUARD)
		for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
			blade.show_inhand()
	if(!QDELETED(src))
		qdel(src)
