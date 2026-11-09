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
		show_beat("arrive")
		rig.glide_from(glide_w, glide_z, glide_time)
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

/// The lunging body has landed: the points are at their front.
/datum/mantis_impale/proc/begin_rig()
	rig_timer = null
	if(!running || ripping)
		return
	put_up_rig()
	show_beat("contact")
	addtimer(CALLBACK(src, PROC_REF(stab)), MANTIS_IMPALE_CONTACT_BEAT, TIMER_DELETE_ME)

/// The blades go in: the points come out of the back wet, with a burst of blood and a crackle of their light.
/datum/mantis_impale/proc/stab()
	if(!running || ripping)
		return
	if(rig)
		rig.wet = TRUE
	show_beat("enter")
	switch(facing)
		if(NORTH)
			rig?.burst("enter_puff", 0.25 SECONDS, "T", under = TRUE)
			rig?.burst("enter_spark", 0.2 SECONDS, "tips", blood = FALSE)
		if(SOUTH)
			rig?.burst("enter_puff", 0.25 SECONDS, "tips")
			rig?.burst("enter_spark", 0.2 SECONDS, "tips", blood = FALSE)
		else
			rig?.burst("enter_puff", 0.25 SECONDS, "T")
			rig?.burst("enter_spark", 0.2 SECONDS, "near", blood = FALSE)
	addtimer(CALLBACK(src, PROC_REF(hang)), MANTIS_IMPALE_ENTER_BEAT, TIMER_DELETE_ME)

/**
 * Held up: the victim is drawn up onto the blades, then hangs there, sagging and jerking on them until the
 * pull-back. The sag is relative and ends where it began.
 */
/datum/mantis_impale/proc/hang()
	show_beat("hold")
	if(!running || ripping || QDELETED(victim))
		return
	animate(victim, time = UPDATE_TRANSFORM_ANIMATION_TIME, flags = ANIMATION_PARALLEL)
	animate(pixel_z = -1, time = 0.2 SECONDS, easing = SINE_EASING, flags = ANIMATION_RELATIVE)
	animate(pixel_z = 1, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)
	animate(pixel_z = -1, time = 0.1 SECONDS, easing = SINE_EASING, flags = ANIMATION_RELATIVE)
	animate(pixel_z = 1, time = 0.05 SECONDS, flags = ANIMATION_RELATIVE)

/**
 * Draws [new_beat] (mantis_rig_beat()): the bearer's arms and lean, and the victim drawn onto the blades.
 * Up against a wall the victim stays where they are and the bearer comes the whole way; from a diagonal the
 * two meet halfway up or down the screen. Pictures only.
 */
/datum/mantis_impale/proc/show_beat(new_beat)
	if(!running || (ripping && new_beat == "hold"))
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
	rig?.show(new_beat, extra_w, extra_z)
	place_victim(target_w, target_z)
	set_tilt(spec[MANTIS_RIG_TILT])

/// Draws the victim [w], [z] pixels off their tile (and upright, if brought up off the floor).
/datum/mantis_impale/proc/place_victim(w, z)
	// Brought upright off the floor: tg draws someone lying down a little low.
	var/upright = hoist_angle ? -PIXEL_Y_OFFSET_LYING : 0
	// Drawn onto the blades as fast as the rig leans in (tg's own glide takes twice as long), so the points
	// are at their front as they arrive, not after.
	var/from_w = victim.pixel_w
	var/from_z = victim.pixel_z
	victim.add_offsets(MANTIS_IMPALE_TRAIT, w_add = w, z_add = z + upright, animate = FALSE)
	var/to_w = victim.pixel_w
	var/to_z = victim.pixel_z
	if(to_w == from_w && to_z == from_z)
		return
	victim.pixel_w = from_w
	victim.pixel_z = from_z
	animate(victim, pixel_w = to_w, pixel_z = to_z, time = 0.1 SECONDS, easing = SINE_EASING, flags = ANIMATION_PARALLEL)

/// The matrix tipping a body [angle] degrees about its feet (clockwise), after [base].
/proc/mantis_tip_matrix(matrix/base, angle)
	var/matrix/turned = matrix(base)
	var/feet = ICON_SIZE_Y / 2 - 4
	turned.Translate(0, feet)
	turned.Turn(angle)
	turned.Translate(0, -feet)
	return turned

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
	finish()
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
			held.Knockdown(knockdown)
			playsound(held, 'sound/items/weapons/bladeslice.ogg', 70, TRUE)
			for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in blades)
				blade.drench(held, light = TRUE)
			if(half && !QDELETED(holder))
				holder.set_staggered_if_lower(1.5 SECONDS)
			log_combat(holder, held, half ? "lost the grip on" : "ripped the mantis blades out of")
	// The drop, drawn once they are down (their layer is the floor's now).
	if(dropping && !QDELETED(dropping))
		dropping.show("drop", time = MANTIS_IMPALE_DROP_BEAT)
		QDEL_IN(dropping, MANTIS_IMPALE_DROP_BEAT)

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

/// Lets go of both, puts everything back, and ends.
/datum/mantis_impale/proc/finish()
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
		victim.remove_offsets(MANTIS_IMPALE_TRAIT)
		if(!QDELETED(victim))
			untilt()
			unhoist(fall = TRUE)
			// Still on the floor: back to the way tg laid them.
			if(victim.body_position == LYING_DOWN && prior_dir)
				victim.setDir(prior_dir)
	if(housings)
		mantis_pose_blades(housings, MANTIS_POSE_GUARD)
		for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
			blade.show_inhand()
	if(!QDELETED(src))
		qdel(src)
