// The ordinary hit with a Mantis blade: the hand that hit swings its blade. The held blade cocks back, cuts
// through and follows down, then is back in the guard. Only the picture: the damage and tg's attack step land
// at the click as before. See mantis_core.dm for the overview.
//
// The swing is a fresh picture on the bearer (a fresh object always plays its frames from the first, an
// overlay does not), the held blade hidden under it while it plays. Its last frame is the guard itself, so the
// held blade comes back under an exact copy of itself whichever reaches the client first.
//
// Side on, the arm on the far side of the body swings under the near arm's swing, and whatever the near hand
// holds is cut out of it (sort_as_arm(), voidcrew/modules/cyberware/cyberware_anim.dm). The blood coat goes on
// after its swing, so it draws over it.

/// 64x64 frames on the bearer's tile: "[model]_swing_[side]" and its "_blood" and "_soak" coats. And the slash
/// over the target, by the blade's impact_state: the impact art after half a beat of nothing, the swing's cock.
#define MANTIS_SWING_ICON 'voidcrew/modules/mantis_gore/icons/mantis_swing.dmi'
/// How long the held blade is hidden: the cock, the strike and the follow-through.
#define MANTIS_SWING_TIME (2.5 DECISECONDS)
/// How long the swing picture stays: one beat of the guard frame past the hide.
#define MANTIS_SWING_LIFETIME (3 DECISECONDS)
/// The impact over the target waits for the strike frame.
#define MANTIS_SWING_IMPACT_DELAY (0.5 DECISECONDS)
/// How long the slash over the target stays: that half beat, then its four frames.
#define MANTIS_SWING_IMPACT_LIFETIME (4.5 DECISECONDS)
/// How much bigger each stroke of the X-slash is drawn.
#define MANTIS_XSLASH_SCALE 1.4
/// The two strokes of the X-slash cross this many pixels above the middle of the chest when drawn that big: they
/// are set this much lower, so they cross on the part cut.
#define MANTIS_XSLASH_DROP 5
/// The X-slash's other blade swings one beat behind the first, so the two cross.
#define MANTIS_XSLASH_SWING_DELAY (0.5 DECISECONDS)

/obj/item/melee/energy/blade/hardlight/cyberware_mantis
	/// The swing playing for this blade right now, if any. Weak: it deletes itself.
	var/datum/weakref/swing_ref
	/// The slash over the target of that swing, if any. Weak: it deletes itself.
	var/datum/weakref/swing_impact_ref

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
		var/coat_state = "[state]_[world.time < soaked_until ? "soak" : "blood"]"
		if(icon_exists(MANTIS_SWING_ICON, coat_state))
			swing.add_coat(coat_state, get_blood_dna_color())
	swing_ref = WEAKREF(swing)
	// This blade leaves its guard, so a far swing behind it is no longer cut around it: its own swing is in
	// front now. The hands redraw, and every arm's picture on the bearer sorts itself again.
	hide_inhand_for(MANTIS_SWING_TIME)
	return swing

/**
 * The slash over [attacked_atom] for this blade's swing, cut the way the blade crosses the target in the strike
 * frame for the way [attacker] faces now, or [mirrored] if given. It goes up with the swing and shows nothing
 * for the half beat the blade cocks back: the client plays both pictures from the same moment, so the slash
 * comes up with the strike frame and never ahead of it (a timer on the server could). Returns it, or null.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing_impact(atom/movable/attacker, atom/attacked_atom, mirrored = null)
	if(!impact_state || !ismovable(attacked_atom))
		return null
	if(!icon_exists(MANTIS_SWING_ICON, impact_state))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_play_impact), attacker, attacked_atom, impact_state, mirrored), MANTIS_SWING_IMPACT_DELAY)
		return null
	if(isnull(mirrored))
		var/obj/effect/abstract/cyberware_anim/mantis_swing/swing = mantis_swing()
		if(swing && !QDELETED(attacker))
			mirrored = mantis_swing_impact_mirrored(attacker.dir, swing.side)
		else
			// Turned as any chrome hit's is (cyberware_play_impact()).
			var/direction = get_dir(attacker, attacked_atom)
			mirrored = (direction & WEST) || (!(direction & EAST) && prob(50))
	var/obj/effect/abstract/cyberware_anim/impact = cyberware_anim_play(attacked_atom, MANTIS_SWING_ICON, impact_state, MANTIS_ANIM_TOP_LAYER, MANTIS_SWING_IMPACT_LIFETIME, glow = impact_state != "impact_shiv")
	if(isnull(impact))
		return null
	// 64x64 around the target's tile, upright even on someone lying down.
	impact.pixel_w = -16
	impact.pixel_z = -16
	impact.appearance_flags |= RESET_TRANSFORM
	if(mirrored)
		impact.transform = matrix(-1, 0, 0, 0, 1, 0)
	swing_impact_ref = WEAKREF(impact)
	return impact

/**
 * How far the [zone] part of [body] is drawn from the middle of its chest, as it stands, faces and lies now
 * (wire_part_offset(), hyperviolence/wire/wire_held.dm): list(x, y) in pixels. The body's left and right swap
 * on screen as it turns.
 */
/proc/mantis_part_shift(mob/living/body, zone)
	var/list/part = wire_part_offset(zone, body.dir)
	var/list/chest = wire_part_offset(BODY_ZONE_CHEST, body.dir)
	var/across = part[1] - chest[1]
	var/up = part[2] - chest[2]
	var/matrix/shape = body.transform
	return list(round(shape.a * across + shape.b * up), round(shape.d * across + shape.e * up))

/// The slash of the swing playing now is set on the part of [victim] it cut ([zone]), [drop] pixels lower.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_swing_impact_onto(mob/living/victim, zone, drop = 0)
	var/obj/effect/abstract/cyberware_anim/impact = swing_impact_ref?.resolve()
	if(isnull(impact) || impact.bearer != victim || !zone)
		return
	var/list/shift = mantis_part_shift(victim, zone)
	impact.pixel_w = -16 + shift[1]
	impact.pixel_z = -16 + shift[2] - drop

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
 * The X-slash as it looks: this blade's own slash is the first stroke of the cross, drawn bigger; the other
 * blade swings a beat behind and its slash, turned the other way, is the second, up with its strike; the
 * flash lands then. The strokes cross on the part cut ([zone]). Without a swing playing (a blade out of its
 * guard) the whole cross lands at once, as before the swing.
 */
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_cross(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade, zone)
	var/obj/effect/abstract/cyberware_anim/first = swing_impact_ref?.resolve()
	if(!mantis_swing() || isnull(first) || first.bearer != victim)
		mantis_xslash_land(user, victim, off_blade, TRUE)
		return
	var/matrix/turned = first.transform
	mantis_xslash_stroke(victim, zone)
	addtimer(CALLBACK(src, PROC_REF(mantis_xslash_second), user, victim, off_blade, zone, turned.a > 0), MANTIS_XSLASH_SWING_DELAY)
	addtimer(CALLBACK(src, PROC_REF(mantis_xslash_land), user, victim, off_blade), MANTIS_XSLASH_SWING_DELAY + MANTIS_SWING_IMPACT_DELAY)

/// This blade's slash over [victim] becomes a stroke of the X-slash: bigger, and set so the two cross on [zone].
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_stroke(mob/living/victim, zone)
	var/obj/effect/abstract/cyberware_anim/impact = swing_impact_ref?.resolve()
	if(isnull(impact))
		return
	var/matrix/bigger = matrix(impact.transform)
	bigger.Scale(MANTIS_XSLASH_SCALE, MANTIS_XSLASH_SCALE)
	impact.transform = bigger
	mantis_swing_impact_onto(victim, zone, MANTIS_XSLASH_DROP)

/// The second stroke of the X-slash: [off_blade] swings, and its slash goes up [mirrored] to cross the first.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_second(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade, zone, mirrored)
	if(QDELETED(victim) || QDELETED(user) || QDELETED(off_blade) || !user.is_holding(off_blade))
		return
	off_blade.mantis_play_swing(user, victim)
	if(off_blade.mantis_swing_impact(user, victim, mirrored))
		off_blade.mantis_xslash_stroke(victim, zone)

/// The crossed slash lands on [victim]: both blades cut, so both run red. [strokes] draws both strokes here,
/// at once, when the blades' own swings haven't.
/obj/item/melee/energy/blade/hardlight/cyberware_mantis/proc/mantis_xslash_land(mob/living/user, mob/living/victim, obj/item/melee/energy/blade/hardlight/cyberware_mantis/off_blade, strokes = FALSE)
	if(QDELETED(victim))
		return
	mantis_xslash_fx(user, victim, impact_state, strokes)
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
	layer = MANTIS_ANIM_BLADE_LAYER
	/// The blade swinging.
	var/obj/item/blade
	/// The hand it swings in: "left" or "right".
	var/side
	/// The blood on it, a picture of its own so its frames start with the swing's.
	var/obj/effect/abstract/cyberware_anim/mantis_swing/coat

/obj/effect/abstract/cyberware_anim/mantis_swing/Destroy()
	if(blade)
		UnregisterSignal(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING))
		blade = null
	QDEL_NULL(coat)
	return ..()

/// Starts playing [state] for [swung], held in [bearer]'s [hand_side] hand.
/obj/effect/abstract/cyberware_anim/mantis_swing/proc/start(mob/living/bearer, obj/item/swung, state, hand_side)
	icon_state = state
	side = hand_side
	blade = swung
	RegisterSignals(blade, list(COMSIG_MOVABLE_MOVED, COMSIG_QDELETING), PROC_REF(on_blade_gone))
	attach(bearer)
	sort_as_arm(side)

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
	coat.sort_as_arm(side)

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
#undef MANTIS_SWING_IMPACT_LIFETIME
#undef MANTIS_XSLASH_SCALE
#undef MANTIS_XSLASH_DROP
#undef MANTIS_XSLASH_SWING_DELAY
