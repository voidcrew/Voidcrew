// The blade side of the Mantis line's gore: what a landed cut does to the body (arterial gashes, the
// X-slash), the held poses, the glint, and blood on the blade. See mantis_core.dm for the overview.

/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	// tg's energy weapons refuse blood. This one takes it, and shows it in the hand.
	item_flags = NONE
	/// What this blade can do beyond cutting: MANTIS_MOVE_* flags.
	var/gore_moves = MANTIS_MOVES_ALL
	/// The wound a torn arm or leg artery is.
	var/artery_wound_type = /datum/wound/slash/flesh/critical/hv_carotid/limb
	/// The held pose: MANTIS_POSE_*. The held sprite is "[base_icon_state]_[mantis_pose]".
	var/mantis_pose = MANTIS_POSE_GUARD
	/// The housing that made this blade.
	var/datum/weakref/housing_ref
	/// The wielder of the swing being resolved, while it resolves.
	var/datum/weakref/cut_wielder
	/// Until this world.time the blade drips.
	var/drenched_until = 0
	/// Until this world.time the blade is drawn soaked, not just bloodied.
	var/soaked_until = 0
	/// Drops it can still leave from this drench.
	var/drips_left = 0
	/// Timer of the next drop.
	var/drip_timer

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/Destroy()
	if(drip_timer)
		deltimer(drip_timer)
		drip_timer = null
	housing_ref = null
	cut_wielder = null
	return ..()

// ---- The models ----------------------------------------------------------

// The Shiv only bleeds people: no torn arteries, no X-slash, no scissor (owner D34). It still takes
// blood and holds the guard.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/street
	gore_moves = NONE

// The Scorch's cuts burn and half-seal what they open, and the heat keeps the blade clean.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch
	item_flags = NO_BLOOD_ON_ITEM
	artery_wound_type = /datum/wound/slash/flesh/critical/hv_carotid/limb/seared

// =========================================================================
// THE CUT
// =========================================================================

/// Whether this swing is not a cut at all: the bearer is busy finishing someone, or it starts the scissor.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing_taken(mob/living/target, mob/living/user)
	if(!isliving(user) || !isliving(target))
		return FALSE
	// The blades are already at someone's neck.
	if(user.has_status_effect(/datum/status_effect/hv_finishing))
		return TRUE
	return mantis_try_scissor(target, user)

/// Listens to [target] while this blade's swing resolves on them.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_watch_cut(mob/living/target, mob/living/user)
	if(!isliving(target) || !isliving(user) || target == user)
		return
	cut_wielder = WEAKREF(user)
	RegisterSignal(target, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_cut_damage_pre), override = TRUE)
	RegisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_cut_damage), override = TRUE)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_unwatch_cut(mob/living/target)
	cut_wielder = null
	if(isliving(target))
		UnregisterSignal(target, list(COMSIG_MOB_APPLY_DAMAGE, COMSIG_MOB_AFTER_APPLY_DAMAGE))

/// Before the cut lands: a death from it counts as the wielder's kill, and only this blade runs red for it.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/on_cut_damage_pre(mob/living/source, damage_amount, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(attacking_item != src)
		return
	var/mob/living/user = cut_wielder?.resolve()
	if(user)
		mantis_note_hit(source, user, list(src))

/// The cut has landed, while its attack line is still held: what it does goes into the same message.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/on_cut_damage(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	// The X-slash's follow-through comes from the other blade, so it never counts here.
	if(attacking_item != src || damage_dealt <= 0 || damagetype != BRUTE)
		return
	var/mob/living/user = cut_wielder?.resolve()
	if(isnull(user) || QDELETED(source))
		return
	mantis_cut_landed(source, user, isbodypart(def_zone) ? def_zone : null, damage_dealt, attack_direction || get_dir(user, source))

/// A cut that did damage: the artery count, the scorch seam and the X-slash count.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_cut_landed(mob/living/victim, mob/living/user, obj/item/bodypart/limb, damage, attack_direction)
	if(limb && iscarbon(victim))
		// The swing's slash goes on the part it cut (mantis_swing.dm).
		mantis_swing_impact_onto(victim, limb.body_zone)
		cut_fx(victim, limb)
		if(gore_moves & MANTIS_MOVE_ARTERY)
			mantis_gash(victim, user, limb, damage, attack_direction)
	if(gore_moves & MANTIS_MOVE_XSLASH)
		mantis_xslash_count(victim, user, limb, attack_direction)

/// What a landed cut looks like on the limb, beyond the impact. Nothing for a plain blade.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/cut_fx(mob/living/carbon/victim, obj/item/bodypart/limb)
	return

// The cut sears: a glowing seam across the limb that cools to char, and a hiss.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/scorch/cut_fx(mob/living/carbon/victim, obj/item/bodypart/limb)
	mantis_scorch_seam_fx(victim, limb)
	playsound(victim, pick('sound/effects/wounds/sizzle1.ogg', 'sound/effects/wounds/sizzle2.ogg'), 40, TRUE)

// ---- Arterial gashes ----------------------------------------------------

/// How many cuts tear the artery of [limb], or 0 if the cover on it never lets them.
/proc/mantis_cuts_to_tear(mob/living/carbon/victim, obj/item/bodypart/limb, armour_penetration)
	var/cover = hv_crit_cover_rating(victim, limb, MELEE, armour_penetration)
	if(cover >= MANTIS_COVER_STOP)
		return 0
	if(cover >= MANTIS_COVER_LIGHT)
		return MANTIS_TEAR_CUTS_COVERED
	return MANTIS_TEAR_CUTS_BARE

/// Counts a cut on [limb], and tears its artery when enough have landed. Returns TRUE if it tore.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_gash(mob/living/carbon/victim, mob/living/user, obj/item/bodypart/limb, damage, attack_direction)
	if(damage < MANTIS_CUT_MIN_DAMAGE || victim.stat == DEAD || limb.owner != victim || !limb.can_bleed())
		return FALSE
	if(!user.hv_can_land_aimed_crits())
		return FALSE
	var/needed = mantis_cuts_to_tear(victim, limb, armour_penetration)
	if(!needed)
		return FALSE
	var/datum/status_effect/mantis_cuts/cuts = victim.has_status_effect(/datum/status_effect/mantis_cuts)
	if(isnull(cuts) || cuts.add_cut(limb.body_zone) < needed)
		return FALSE
	cuts.clear_cuts(limb.body_zone)
	return mantis_tear_artery(victim, user, limb, attack_direction)

/// What the torn artery of [limb] is: the throat and the aorta are #509's own wounds.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/artery_wound_for(obj/item/bodypart/limb)
	switch(limb.body_zone)
		if(BODY_ZONE_HEAD)
			return /datum/wound/slash/flesh/critical/hv_carotid
		if(BODY_ZONE_CHEST)
			return /datum/wound/pierce/bleed/critical/hv_aorta
	return artery_wound_type

/// Where the artery of [limb] is, as the line names it.
/proc/mantis_artery_place(obj/item/bodypart/limb)
	return limb.body_zone == BODY_ZONE_HEAD ? "neck" : limb.plaintext_zone

/// Tears the artery of [limb]. Returns TRUE if it tore.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_tear_artery(mob/living/carbon/victim, mob/living/user, obj/item/bodypart/limb, attack_direction)
	// A sealed helmet or an armoured collar still saves the throat, as it does from #509's slit throat.
	if(limb.body_zone == BODY_ZONE_HEAD)
		var/datum/hv_crit/throat/throat = locate() in GLOB.hv_crits
		if(throat?.blocked_on_carbon(victim, limb, src))
			return FALSE
	var/datum/wound/wound_type = artery_wound_for(limb)
	var/datum/wound_pregen_data/pregen = GLOB.all_wound_pregen_data[wound_type]
	if(!pregen?.can_be_applied_to(limb, list(WOUND_SLASH)))
		return FALSE
	var/datum/wound/torn = hv_crit_apply_wound(limb, wound_type, attack_direction, src)
	if(!torn)
		return FALSE
	var/seared = ispath(artery_wound_type, /datum/wound/slash/flesh/critical/hv_carotid/limb/seared)
	var/place = mantis_artery_place(limb)
	if(seared)
		// The throat and aorta wounds are #509's; the heat closes part of them.
		if(!istype(torn, /datum/wound/slash/flesh/critical/hv_carotid/limb))
			torn.adjust_blood_flow(-torn.blood_flow * 0.4)
		victim.hv_add_hit_line("[victim]'s [place] is seared open to the artery!", HV_LINE_BOLD, "Your [place] is seared open to the artery!", DEFAULT_MESSAGE_RANGE)
	else
		victim.hv_add_hit_line("The artery in [victim]'s [place] is cut!", HV_LINE_BOLD, "The artery in your [place] is cut!", DEFAULT_MESSAGE_RANGE)
		drench(victim)
	// What it looks like: one spurt of drops the way the cut went, then the blood runs down the body.
	mantis_spurt_fx(victim, limb.body_zone, attack_direction, seared)
	mantis_artery_run_fx(victim, limb.body_zone, torn)
	log_combat(user, victim, "tore an artery in", src, "([limb.plaintext_zone])")
	return TRUE

// ---- X-slash -----------------------------------------------------------

/// Counts a landed cut toward the X-slash. Every third on one target, with both blades out, is one.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_count(mob/living/victim, mob/living/user, obj/item/bodypart/limb, attack_direction)
	var/datum/mantis_bearer/state = user.get_mantis_state()
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/held as anything in mantis_held_blades(user, MANTIS_MOVE_XSLASH))
		if(held != src)
			off_blade = held
			break
	if(isnull(off_blade) || !user.hv_can_land_aimed_crits() || victim.stat == DEAD)
		state.xslash_count = 0
		return FALSE
	if(state.xslash_target?.resolve() != victim || world.time - state.xslash_last > MANTIS_XSLASH_WINDOW)
		state.xslash_count = 0
	state.xslash_target = WEAKREF(victim)
	state.xslash_last = world.time
	state.xslash_count++
	if(state.xslash_count < MANTIS_XSLASH_EVERY)
		return FALSE
	state.xslash_count = 0
	mantis_xslash(victim, user, off_blade, limb, attack_direction)
	return TRUE

/// The off blade follows through across the first cut, and the target reels.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash(mob/living/victim, mob/living/user, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade, obj/item/bodypart/limb, attack_direction)
	var/zone = limb ? limb.body_zone : BODY_ZONE_CHEST
	var/place = limb ? limb.plaintext_zone : "body"
	// The attack line being held for this hit becomes the crossed slash.
	var/datum/hv_hit/hit = victim.hv_hit
	if(hit?.others_text && hit.attacker == user)
		hit.others_text = "[user] crosses both blades through [victim]'s [place]!"
		hit.victim_text = "[user] crosses both blades through your [place]!"
		if(hit.attacker_text)
			hit.attacker_text = "You cross both blades through [victim]'s [place]!"
	victim.hv_add_hit_line("[victim] reels!", HV_LINE_BOLD, "You reel!")
	var/armour = victim.run_armor_check(zone, MELEE, armour_penetration = off_blade.armour_penetration, silent = TRUE)
	victim.apply_damage(
		off_blade.force * 0.5,
		BRUTE,
		limb || zone,
		armour,
		wound_bonus = 10,
		sharpness = SHARP_EDGED,
		attack_direction = attack_direction,
		attacking_item = off_blade,
	)
	if(!QDELETED(victim))
		victim.set_staggered_if_lower(MANTIS_XSLASH_STAGGER)
	mantis_xslash_cross(user, victim, off_blade, zone)
	log_combat(user, victim, "x-slashed", src)

// =========================================================================
// POSES AND THE GLINT
// =========================================================================

/// Puts the held blade in [pose] (MANTIS_POSE_*), or back in the guard if this model has no such pose.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/set_mantis_pose(pose = MANTIS_POSE_GUARD)
	var/state = "[base_icon_state]_[pose]"
	if(pose != MANTIS_POSE_GUARD && !icon_exists(righthand_file, state))
		pose = MANTIS_POSE_GUARD
		state = "[base_icon_state]_[pose]"
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = housing_ref?.resolve()
	housing?.set_stance_raise(mantis_stance_raise(pose))
	if(mantis_pose == pose && inhand_icon_state == state)
		return
	housing?.unfold_overtaken(src)
	mantis_pose = pose
	inhand_icon_state = state
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()

/// How far the fists ride up in [pose], in pixels. Matches the held sprites.
/proc/mantis_stance_raise(pose)
	switch(pose)
		if(MANTIS_POSE_RAISE)
			return 3
		if(MANTIS_POSE_COIL)
			return 1
	return 2

/// Puts every blade of [housings] in [pose].
/proc/mantis_pose_blades(list/housings, pose)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/blade as anything in mantis_housing_blades(housings))
		blade.set_mantis_pose(pose)

/// The hand this blade sits in, as the art names it.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/hand_side()
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = housing_ref?.resolve()
	return housing?.zone == BODY_ZONE_L_ARM ? "left" : "right"

/// A light runs along the edge, if this model has an edge that catches the light in [pose].
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/play_glint(pose = mantis_pose)
	var/mob/living/holder = loc
	if(!isliving(holder) || !holder.is_holding(src))
		return null
	var/state = "[base_icon_state]_[pose]_glint_[hand_side()]"
	if(!icon_exists(MANTIS_GORE_ICON, state))
		return null
	var/obj/effect/abstract/cyberware_anim/glint = cyberware_anim_play(holder, MANTIS_GORE_ICON, state, MANTIS_ANIM_BLADE_LAYER, 0.3 SECONDS, glow = TRUE)
	// Side on, the far blade's light stays behind the near blade.
	glint?.sort_as_arm(hand_side())
	return glint

// =========================================================================
// BLOOD
// =========================================================================

/// Whether there is blood on the blade to show.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/is_bloody()
	return !(item_flags & NO_BLOOD_ON_ITEM) && GET_ATOM_BLOOD_DECAL_LENGTH(src)

/// A kill, a torn artery, a rip, the scissor or the X-slash: the blade runs red with [source]'s blood and drips
/// for a while. Only the blade that did it: the other keeps whatever it had.
/// [light]: the steel that went through is bloodied (the lighter coat), not soaked: the impale and the scissor,
/// so the held blade matches the one the finisher drew.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/drench(mob/living/source, light = FALSE)
	if(item_flags & NO_BLOOD_ON_ITEM)
		return FALSE
	if(isliving(source) && source.can_bleed(BLOOD_COVER_ITEMS) == BLEED_SPLATTER)
		add_mob_blood(source)
	if(!is_bloody())
		return FALSE
	drenched_until = world.time + MANTIS_DRENCH_TIME
	if(!light)
		soaked_until = drenched_until
	drips_left = MANTIS_DRIP_MAX
	if(!drip_timer)
		drip_timer = addtimer(CALLBACK(src, PROC_REF(drip)), MANTIS_DRIP_INTERVAL, TIMER_STOPPABLE|TIMER_DELETE_ME)
	refresh_held()
	return TRUE

/// One drop off the blade onto the floor under its wielder, while it is still drenched.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/drip()
	drip_timer = null
	if(world.time >= drenched_until || drips_left <= 0 || !is_bloody())
		stop_dripping()
		return
	var/mob/living/holder = loc
	if(isliving(holder) && holder.is_holding(src) && isturf(holder.loc))
		var/turf/floor = holder.loc
		if(!isgroundlessturf(floor) && floor.has_gravity())
			var/list/blood_dna = blood_dna_copy()
			var/obj/effect/decal/cleanable/blood/drip/drop = locate() in floor
			if(drop)
				drop.add_blood_DNA(blood_dna)
			else
				new /obj/effect/decal/cleanable/blood/drip(floor, null, blood_dna)
			drips_left--
	drip_timer = addtimer(CALLBACK(src, PROC_REF(drip)), MANTIS_DRIP_INTERVAL, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The blade stops dripping.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/stop_dripping()
	if(drip_timer)
		deltimer(drip_timer)
		drip_timer = null
	var/was_drenched = drenched_until
	drenched_until = 0
	soaked_until = 0
	drips_left = 0
	if(was_drenched)
		refresh_held()

/// The blood on the blade, as a list of its own (a decal keeps the list it is given).
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/blood_dna_copy()
	var/list/blood_dna = GET_ATOM_BLOOD_DNA(src)
	return blood_dna ? blood_dna.Copy() : list()

/// The held sprite redraws.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/refresh_held()
	var/mob/holder = loc
	if(ismob(holder))
		holder.update_held_items()

/// The blade is back in its housing: the guard, and no more drops.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_stowed()
	stop_dripping()
	mantis_pose = MANTIS_POSE_GUARD
	inhand_icon_state = "[base_icon_state]_[MANTIS_POSE_GUARD]"

// tg's item blood is drawn on the item only. In the hand, a coat of blood drawn for the pose, heavier and
// dripping while drenched. Drawn as its own state: an inset overlay inside a whole body masks against the
// body, not the blade.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file)
	. = ..()
	if(!isinhands || !is_bloody())
		return
	var/blood_color = get_blood_dna_color()
	var/drenched = world.time < drenched_until
	var/coat_state = "[standing.icon_state]_[world.time < soaked_until ? "soak" : "blood"]"
	if(icon_exists(icon_file, coat_state))
		var/mutable_appearance/coat = mutable_appearance(icon_file, coat_state, appearance_flags = RESET_COLOR)
		coat.color = blood_color
		. += coat
	if(drenched && icon_exists(icon_file, "[standing.icon_state]_drip"))
		var/mutable_appearance/drops = mutable_appearance(icon_file, "[standing.icon_state]_drip", appearance_flags = RESET_COLOR)
		drops.color = blood_color
		. += drops
