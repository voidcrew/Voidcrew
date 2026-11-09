// The ordinary hit with a Mantis blade: the hand that hit swings its blade. The held blade cocks back, cuts
// through and follows down, then is back in the guard. Only the picture: the damage and tg's attack step land
// at the click as before. See mantis_core.dm for the overview.
//
// The swing is a fresh picture on the bearer (a fresh object always plays its frames from the first, an
// overlay does not), the held blade hidden under it while it plays. Its last frame is the guard itself, so the
// held blade comes back under an exact copy of itself whichever reaches the client first.

/// 64x64 frames on the bearer's tile: "[model]_swing_[side]" and its "_blood" and "_soak" coats.
#define MANTIS_SWING_ICON 'voidcrew/modules/mantis_gore/icons/mantis_swing.dmi'
/// How long the held blade is hidden: the cock, the strike and the follow-through.
#define MANTIS_SWING_TIME (2.5 DECISECONDS)
/// How long the swing picture stays: one beat of the guard frame past the hide.
#define MANTIS_SWING_LIFETIME (3 DECISECONDS)
/// The impact over the target waits for the strike frame.
#define MANTIS_SWING_IMPACT_DELAY (0.5 DECISECONDS)
/// The X-slash's other blade swings one beat behind the first, so the two cross.
#define MANTIS_XSLASH_SWING_DELAY (0.5 DECISECONDS)
/// The arm on the far side of the body swings under the near arm's held blade.
#define MANTIS_SWING_FAR_LAYER (-(HANDS_LAYER + 0.5))

/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	/// The swing playing for this blade right now, if any. Weak: it deletes itself.
	var/datum/weakref/swing_ref

/// The swing playing for this blade right now, if any.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing()
	return swing_ref?.resolve()

/**
 * The hand holding this blade swings it at [attacked_atom]. Called with tg's attack step, so it plays for
 * every swing that steps, landed or blocked. Only from the guard, and never over a blade already drawn
 * elsewhere (the unfold, the impale, the scissor). Returns the swing, or null if none plays.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_play_swing(mob/living/attacker, atom/attacked_atom)
	if(!isliving(attacker) || QDELETED(attacker) || attacked_atom == attacker)
		return null
	var/held_index = attacker.get_held_index_of_item(src)
	if(!held_index || mantis_pose != MANTIS_POSE_GUARD || world.time < inhand_hidden_until)
		return null
	var/side = IS_LEFT_INDEX(held_index) ? "left" : "right"
	var/state = "[base_icon_state]_swing_[side]"
	if(!icon_exists(MANTIS_SWING_ICON, state))
		return null
	qdel(mantis_swing())
	var/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/housing = housing_ref?.resolve()
	housing?.unfold_overtaken(src)
	// Side on, the arm behind the body swings under the near arm's blade.
	var/far = (attacker.dir == EAST && side == "left") || (attacker.dir == WEST && side == "right")
	var/swing_layer = far ? MANTIS_SWING_FAR_LAYER : MANTIS_ANIM_BLADE_LAYER
	var/obj/effect/abstract/cyberware_anim/mantis_swing/swing = new(null)
	swing.start(attacker, src, state, swing_layer)
	if(is_bloody())
		var/coat_state = "[state]_[world.time < drenched_until ? "soak" : "blood"]"
		if(icon_exists(MANTIS_SWING_ICON, coat_state))
			swing.add_coat(coat_state, get_blood_dna_color())
	swing_ref = WEAKREF(swing)
	hide_inhand_for(MANTIS_SWING_TIME)
	return swing

/// The impact over [attacked_atom], when the swing's strike frame is up.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing_impact(atom/movable/attacker, atom/attacked_atom)
	if(!impact_state || !ismovable(attacked_atom))
		return
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_play_impact), attacker, attacked_atom, impact_state), MANTIS_SWING_IMPACT_DELAY)

/**
 * The X-slash as it looks: the other blade swings a beat behind this one and the crossed slash lands with its
 * strike. Without a swing playing (a blade out of its guard) it lands at once, as before the swing.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_cross(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade)
	if(!mantis_swing())
		mantis_xslash_fx(user, victim, impact_state)
		return
	addtimer(CALLBACK(off_blade, PROC_REF(mantis_play_swing), user, victim), MANTIS_XSLASH_SWING_DELAY)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_xslash_fx), user, victim, impact_state), MANTIS_XSLASH_SWING_DELAY + MANTIS_SWING_IMPACT_DELAY)

// =========================================================================
// THE PICTURE
// =========================================================================

/// One swing of one blade on its bearer, and the blood on it. Ends early if the blade leaves the hand.
/obj/effect/abstract/cyberware_anim/mantis_swing
	icon = MANTIS_SWING_ICON
	// The frames are 64x64 around the bearer's tile. Centred with pixel_w/pixel_z, which only draw elsewhere:
	// the picture stays on the bearer's row, so it sorts against other mobs as the bearer does.
	pixel_w = -16
	pixel_z = -16
	/// The blade swinging.
	var/obj/item/blade
	/// The blood on it, a picture of its own so its frames start with the swing's.
	var/obj/effect/abstract/cyberware_anim/mantis_swing/coat

/obj/effect/abstract/cyberware_anim/mantis_swing/Destroy()
	if(blade)
		UnregisterSignal(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		blade = null
	QDEL_NULL(coat)
	return ..()

/// Starts playing [state] for [swung] on [bearer] at [swing_layer].
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/start(mob/living/bearer, obj/item/swung, state, swing_layer)
	icon_state = state
	layer = swing_layer
	blade = swung
	RegisterSignals(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_blade_gone))
	attach(bearer)

/// Lays the blood coat [coat_state] in [blood_color] over the swing.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/add_coat(coat_state, blood_color)
	coat = new(null)
	coat.icon = MANTIS_SWING_ICON
	coat.icon_state = coat_state
	coat.layer = layer + 0.01
	coat.pixel_w = pixel_w
	coat.pixel_z = pixel_z
	coat.color = blood_color
	coat.appearance_flags |= RESET_COLOR
	coat.attach(bearer)

/obj/effect/abstract/cyberware_anim/mantis_swing/proc/on_blade_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/// Puts this picture on [target] for the swing's lifetime.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/attach(atom/movable/target)
	bearer = target
	RegisterSignal(bearer, COMSIG_QDELETING, PROC_REF(on_bearer_deleted))
	bearer.vis_contents += src
	QDEL_IN(src, MANTIS_SWING_LIFETIME)

#undef MANTIS_SWING_ICON
#undef MANTIS_SWING_TIME
#undef MANTIS_SWING_LIFETIME
#undef MANTIS_SWING_IMPACT_DELAY
#undef MANTIS_XSLASH_SWING_DELAY
#undef MANTIS_SWING_FAR_LAYER
