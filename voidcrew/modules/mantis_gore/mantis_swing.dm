// The ordinary hit with a Mantis blade: the hand that hit swings its blade. The held blade cocks back, cuts
// through and follows down, then is back in the guard. Only the picture: the damage and tg's attack step land
// at the click as before. See mantis_core.dm for the overview.
//
// The swing is a fresh picture on the bearer (a fresh object always plays its frames from the first, an
// overlay does not), the held blade hidden under it while it plays. Its last frame is the guard itself, so the
// held blade comes back under an exact copy of itself whichever reaches the client first.
//
// A picture in vis_contents draws over every overlay of its bearer whatever its own float layer, held items
// included. The art already leaves out the body where it hides a far arm; what the near hand holds is cut out
// of a far arm's swing in game, with a mask of that item's held sprite, for as long as it is drawn there.

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
/// The arm on the far side of the body swings under the near arm's swing.
#define MANTIS_SWING_FAR_LAYER (-(HANDS_LAYER + 0.5))
/// The mask on a far arm's swing: the near hand's held item, cut out of it.
#define MANTIS_SWING_COVER_FILTER "mantis_swing_cover"

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
	var/obj/effect/abstract/cyberware_anim/mantis_swing/swing = new(null)
	swing.start(attacker, src, state, side)
	if(is_bloody())
		var/coat_state = "[state]_[world.time < drenched_until ? "soak" : "blood"]"
		if(icon_exists(MANTIS_SWING_ICON, coat_state))
			swing.add_coat(coat_state, get_blood_dna_color())
	swing_ref = WEAKREF(swing)
	hide_inhand_for(MANTIS_SWING_TIME)
	// This blade has left its guard, so a far swing behind it is no longer cut around it: its own swing is in
	// front now.
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/other as anything in mantis_held_blades(attacker))
		if(other != src)
			other.mantis_swing()?.fit_to_facing()
	return swing

/// The impact over [attacked_atom], when the swing's strike frame is up, its slash cut the way this blade swings.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing_impact(atom/movable/attacker, atom/attacked_atom)
	if(!impact_state || !ismovable(attacked_atom))
		return
	var/obj/effect/abstract/cyberware_anim/mantis_swing/swing = mantis_swing()
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(mantis_swing_play_impact), attacker, attacked_atom, impact_state, swing?.side), MANTIS_SWING_IMPACT_DELAY)

/**
 * The impact over [attacked_atom] for a swing of the [side] hand's blade, its slash cut the way that blade
 * crosses the target in the strike frame, for the way [attacker] faces now. Without a side, or without the
 * attacker, it is turned as any chrome hit's is.
 */
/proc/mantis_swing_play_impact(atom/movable/attacker, atom/attacked_atom, impact_state, side)
	var/mirrored = (side && !QDELETED(attacker)) ? mantis_swing_impact_mirrored(attacker.dir, side) : null
	return cyberware_play_impact(attacker, attacked_atom, impact_state, mirrored)

/**
 * Whether the [side] hand's swing, its bearer facing [facing], shows the impact art mirrored. The art cuts
 * clockwise: in along the top from the left, then down on the right. In mantis_swing.dmi, from the cock frame
 * to the strike frame, facing south or north each hand cuts across the body toward the other: facing south the
 * right hand cuts clockwise and the left anticlockwise, facing north the other way round. Side on both hands
 * chop down in front, clockwise facing east and anticlockwise facing west.
 */
/proc/mantis_swing_impact_mirrored(facing, side)
	if(facing & WEST)
		return TRUE
	if(facing & EAST)
		return FALSE
	return (facing == NORTH) == (side == "right")

/**
 * The X-slash as it looks: the other blade swings a beat behind this one and the crossed slash lands with its
 * strike. Without a swing playing (a blade out of its guard) it lands at once, as before the swing.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_cross(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade)
	if(!mantis_swing())
		mantis_xslash_land(user, victim, off_blade)
		return
	addtimer(CALLBACK(off_blade, PROC_REF(mantis_play_swing), user, victim), MANTIS_XSLASH_SWING_DELAY)
	addtimer(CALLBACK(src, PROC_REF(mantis_xslash_land), user, victim, off_blade), MANTIS_XSLASH_SWING_DELAY + MANTIS_SWING_IMPACT_DELAY)

/// The crossed slash lands on [victim]: both blades cut, so both run red.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_land(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade)
	if(QDELETED(victim))
		return
	mantis_xslash_fx(user, victim, impact_state)
	for(var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/crossed as anything in list(src, off_blade))
		if(!QDELETED(crossed) && user?.is_holding(crossed))
			crossed.drench(victim)

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
	/// The hand it swings in: "left" or "right".
	var/side
	/// The blood on it, a picture of its own so its frames start with the swing's.
	var/obj/effect/abstract/cyberware_anim/mantis_swing/coat
	/// What the near hand holds while this is a far arm's swing: it is cut out of the swing.
	var/obj/item/cover

/obj/effect/abstract/cyberware_anim/mantis_swing/Destroy()
	if(blade)
		UnregisterSignal(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		blade = null
	if(bearer)
		UnregisterSignal(bearer, COMSIG_ATOM_POST_DIR_CHANGE)
	set_cover(null)
	QDEL_NULL(coat)
	return ..()

/// Starts playing [state] for [swung], held in [bearer]'s [hand_side] hand.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/start(mob/living/bearer, obj/item/swung, state, hand_side)
	icon_state = state
	side = hand_side
	blade = swung
	RegisterSignals(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_blade_gone))
	attach(bearer)
	RegisterSignal(bearer, COMSIG_ATOM_POST_DIR_CHANGE, PROC_REF(on_bearer_turned))
	fit_to_facing()

/// Lays the blood coat [coat_state] in [blood_color] over the swing.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/add_coat(coat_state, blood_color)
	coat = new(null)
	coat.icon = MANTIS_SWING_ICON
	coat.icon_state = coat_state
	coat.pixel_w = pixel_w
	coat.pixel_z = pixel_z
	coat.color = blood_color
	coat.appearance_flags |= RESET_COLOR
	coat.attach(bearer)
	fit_to_facing()

/**
 * Sorts the swing for the way its bearer faces now. Side on, the arm on the far side of the body swings
 * under the near arm's swing, and whatever the near hand holds is cut out of it while that is drawn in the
 * hand. A near blade's own swing hides it from the hand; the cut comes back when the blade does.
 */
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/fit_to_facing()
	if(QDELETED(bearer))
		return
	var/far = (bearer.dir == EAST && side == "left") || (bearer.dir == WEST && side == "right")
	layer = far ? MANTIS_SWING_FAR_LAYER : MANTIS_ANIM_BLADE_LAYER
	if(coat)
		coat.layer = layer + 0.01
	var/obj/item/near_item = far ? near_held_item() : null
	var/obj/item/melee/energy/blade/hardlight/cyberware_mantis/near_blade = near_item
	if(istype(near_blade) && world.time < near_blade.inhand_hidden_until)
		// Not drawn in the hand right now: nothing to cut out until it is back.
		addtimer(CALLBACK(src, PROC_REF(fit_to_facing)), near_blade.inhand_hidden_until - world.time, TIMER_DELETE_ME)
		near_item = null
	set_cover(near_item)

/// What the bearer holds in a hand on the other side from this swing.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/near_held_item()
	var/mob/living/holder = bearer
	if(!isliving(holder))
		return null
	for(var/obj/item/held in holder.held_items)
		if(held == blade)
			continue
		if(IS_LEFT_INDEX(holder.get_held_index_of_item(held)) != (side == "left"))
			return held
	return null

/// Cuts [item]'s held sprite out of the swing and its coat, or nothing out of them if null.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/set_cover(obj/item/item)
	if(cover)
		UnregisterSignal(cover, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
	var/icon/mask = item && mantis_held_mask(item, bearer)
	cover = mask ? item : null
	if(cover)
		RegisterSignals(cover, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_cover_gone))
	for(var/obj/effect/abstract/cyberware_anim/mantis_swing/picture as anything in list(src, coat))
		if(isnull(picture))
			continue
		if(mask)
			picture.add_filter(MANTIS_SWING_COVER_FILTER, 1, alpha_mask_filter(icon = mask, flags = MASK_INVERSE))
		else
			picture.remove_filter(MANTIS_SWING_COVER_FILTER)

/obj/effect/abstract/cyberware_anim/mantis_swing/proc/on_cover_gone(datum/source)
	SIGNAL_HANDLER
	set_cover(null)

/obj/effect/abstract/cyberware_anim/mantis_swing/proc/on_bearer_turned(datum/source, old_dir, new_dir)
	SIGNAL_HANDLER
	fit_to_facing()

/obj/effect/abstract/cyberware_anim/mantis_swing/proc/on_blade_gone(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/**
 * The shape [item] has in [holder]'s hand, facing the way [holder] faces now, as a mask: the first frame of
 * its held sprite. Null if it has none. Each sprite and facing is made once.
 */
/proc/mantis_held_mask(obj/item/item, mob/living/holder)
	if(!isliving(holder))
		return null
	var/index = holder.get_held_index_of_item(item)
	if(!index)
		return null
	var/file = IS_RIGHT_INDEX(index) ? item.righthand_file : item.lefthand_file
	var/state = item.inhand_icon_state || item.icon_state
	if(!file || !state || !icon_exists(file, state))
		return null
	var/static/list/masks = list()
	var/list/by_state = masks[file]
	if(!by_state)
		by_state = list()
		masks[file] = by_state
	var/key = "[state]-[holder.dir]"
	. = by_state[key]
	if(!.)
		. = icon(file, state, holder.dir, 1)
		by_state[key] = .

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
#undef MANTIS_SWING_COVER_FILTER
