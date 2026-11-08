/**
 * # The garrote
 *
 * A Widowline wielder standing over someone who can't fight back (in crit, or stunned: lying down alone
 * isn't enough) loops the wire round their neck with a combat click at the head or mouth. It is #509's
 * finisher engine (hyperviolence/finishers/) run by a person: a real aggressive grab, interruptible the
 * same ways.
 *
 * - Wind-up (1 s): the wire loops round the neck and glints. No mark over the victim (owner D34): the loop
 *   and the struggle are the tell. It holds nobody, so pulling the victim clear, or them getting up, ends it.
 * - Hold (1.5 s): the grab, the wire goes taut and bites, the victim thrashes.
 * - Kill (0.5 s into the stage): in hard crit the head comes off (an Atlas frame keeps it); otherwise the
 *   throat is slit, #509's carotid crit. A sealed helmet, an armoured collar or plating that would stop
 *   the throat crit turns the wire, and it lands as an ordinary blow at the head instead.
 * - Broken by #509's rules: the grab broken or pulled apart, the garroter hurt (WIRE_GARROTE_INTERRUPT
 *   health), stunned, cuffed or out of their wire, the victim dying first, the timeout.
 *
 * Only wielders that hv_wire_moves_allowed() lets use the wire's moves (wire_users.dm) can start one. It
 * refuses allies, starts the outpost's self-defence clock like any attack, and the wielder waits
 * WIRE_GARROTE_COOLDOWN after one that got a grip, WIRE_GARROTE_MISS_COOLDOWN after one that didn't.
 */

/// Health the garroter can lose before letting go.
#define WIRE_GARROTE_INTERRUPT 20

/mob/living
	/// The garrote can be tried again from this world.time.
	var/wire_garrote_ready_at = 0

/obj/item/melee/cyberware_monowire
	/// The garrote this wire is in, if any.
	var/datum/hv_finisher/garrote/garrote_running
	/// TRUE while the garrote swings the wire for real, so the swing isn't taken for a new garrote.
	var/garrote_blow = FALSE

/obj/item/melee/cyberware_monowire/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(. || garrote_blow)
		return
	// Busy round someone's neck.
	if(garrote_running)
		return TRUE
	if(wire_try_garrote(target, user))
		return TRUE

/// Someone who can't fight the wire off: in crit, or stunned. Lying down alone doesn't count.
/proc/wire_garrote_helpless(mob/living/victim)
	return victim.stat >= SOFT_CRIT || HAS_TRAIT(victim, TRAIT_INCAPACITATED)

/// Starts a garrote on `target` if this click asks for one (combat mode, the head or mouth on the target doll)
/// and it can begin. Returns TRUE if it began.
/obj/item/melee/cyberware_monowire/proc/wire_try_garrote(atom/target, mob/living/user)
	if(!isliving(user) || !user.combat_mode)
		return FALSE
	if(user.zone_selected != BODY_ZONE_HEAD && user.zone_selected != BODY_ZONE_PRECISE_MOUTH)
		return FALSE
	return wire_start_garrote(user, target)

/**
 * The garrote itself, with no click behind it: the entry point for anything that isn't a mouse (an NPC's AI,
 * later). Same rules as a player's: the wielder's moves gate (wire_users.dm), no pacifists, the wait between
 * tries, and the finisher's own can_start(). Returns TRUE if it began.
 */
/obj/item/melee/cyberware_monowire/proc/wire_start_garrote(mob/living/user, mob/living/target)
	if(!iscarbon(target) || !iscarbon(user) || HAS_TRAIT(user, TRAIT_PACIFISM) || garrote_running)
		return FALSE
	if(!hv_wire_moves_allowed(user))
		return FALSE
	if(world.time < user.wire_garrote_ready_at)
		return FALSE
	var/datum/hv_finisher/garrote/garrote = new(user, target, CALLBACK(src, PROC_REF(garrote_ended)))
	garrote.wire = src
	if(!garrote.start())
		qdel(garrote)
		return FALSE
	garrote_running = garrote
	return TRUE

/// The garrote ended, however it ended.
/obj/item/melee/cyberware_monowire/proc/garrote_ended(datum/hv_finisher/garrote/garrote, result)
	if(garrote_running == garrote)
		garrote_running = null
	// Not from inside its own stop(): the engine still has a line or two to run.
	QDEL_IN(garrote, 1)

// ---- The finisher ----

/datum/hv_finisher/garrote
	name = "garrote"
	interrupt_damage = WIRE_GARROTE_INTERRUPT
	zone_preference = list(BODY_ZONE_HEAD)
	stages = list(
		/datum/hv_finisher_stage/windup/garrote,
		/datum/hv_finisher_stage/hold/garrote,
		/datum/hv_finisher_stage/kill/garrote,
		/datum/hv_finisher_stage/recover,
	)
	/// The wire round the neck
	var/obj/item/melee/cyberware_monowire/wire
	/// The loop drawn round the neck
	var/datum/weakref/loop_ref
	/// The strands of wire from the garroter's hands to the neck
	var/list/strand_refs

/datum/hv_finisher/garrote/Destroy()
	. = ..()
	clear_wire_fx()
	wire = null

/**
 * The finisher's own victim check (hv_finisher_valid_victim()) refuses anyone who shares a faction with the
 * attacker, which is every player with every other. This is the same check without that: alive, helpless,
 * on the floor beside the garroter with a head, not strapped down, not already being finished, not an ally.
 */
/datum/hv_finisher/garrote/can_start()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(!hv_wire_moves_allowed(user))
		return FALSE
	if(QDELETED(wire) || !user.is_holding(wire))
		return FALSE
	if(!iscarbon(victim) || QDELETED(victim) || victim == user || victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(!wire_garrote_helpless(victim) || victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	if(!victim.get_bodypart(BODY_ZONE_HEAD))
		return FALSE
	if(victim.buckled || !isturf(victim.loc) || !isturf(user.loc) || victim.z != user.z)
		return FALSE
	if(cyberware_is_ally(user, victim))
		return FALSE
	return get_dist(user, victim) <= 1 && user.Adjacent(victim)

/datum/hv_finisher/garrote/start()
	. = ..()
	if(!.)
		return
	user.wire_garrote_ready_at = world.time + WIRE_GARROTE_MISS_COOLDOWN
	// A garrote is an attack: the trader outpost's guards see it from the first loop.
	GLOB.outpost_pvp_enforcement?.register_pvp_aggression(victim, user)
	cyberware_camo_drop(user)

/datum/hv_finisher/garrote/take_grip()
	. = ..()
	if(. && !QDELETED(user))
		user.wire_garrote_ready_at = world.time + WIRE_GARROTE_COOLDOWN

/datum/hv_finisher/garrote/safety_check()
	. = ..()
	if(. || completed)
		return
	if(QDELETED(wire) || !user.is_holding(wire))
		return HV_FINISHER_ATTACKER_DOWN
	// The wind-up holds nobody: back on their feet, they're out of it.
	if(!gripped && !wire_garrote_helpless(victim))
		return HV_FINISHER_LOST_GRIP

/datum/hv_finisher/garrote/stop(reason)
	clear_wire_fx()
	return ..()

/// The wire's blow, never the heaviest thing in the garroter's hands.
/datum/hv_finisher/garrote/real_blow(zone, extra_wound_bonus = 0)
	if(QDELETED(user) || QDELETED(victim) || QDELETED(wire) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED) || !user.is_holding(wire))
		return FALSE
	var/mob/living/carbon/attacker = user
	if(attacker.get_active_held_item() != wire)
		var/index = attacker.get_held_index_of_item(wire)
		if(!index)
			return FALSE
		attacker.swap_hand(index, silent = TRUE)
	user.zone_selected = zone
	user.face_atom(victim)
	var/old_combat_mode = user.combat_mode
	user.set_combat_mode(TRUE)
	var/old_wound_bonus = wire.wound_bonus
	wire.wound_bonus += extra_wound_bonus
	wire.garrote_blow = TRUE
	wire.melee_attack_chain(user, victim)
	if(!QDELETED(wire))
		wire.garrote_blow = FALSE
		wire.wound_bonus = old_wound_bonus
	if(!QDELETED(user))
		user.set_combat_mode(old_combat_mode)
		user.changeNext_move(CLICK_CD_MELEE)
	return TRUE

/// No mark over the victim (owner D34): the wire loops round the neck and glints, and they struggle.
/datum/hv_finisher/garrote/place_mark(duration)
	QDEL_NULL(mark)
	face_victim_in()
	// The wire is round the neck now, not hanging from the hand.
	wire?.hide_inhand_for(longest_duration())
	show_loop(tight = FALSE)
	draw_wire(duration, both_hands = FALSE)
	var/obj/effect/abstract/cyberware_anim/glint = cyberware_anim_play(user, WIRE_GORE_ICON, "wire_glint[wire_suffix()]", WIRE_FX_LAYER, 0.3 SECONDS, glow = TRUE)
	if(glint)
		glint.pixel_y = -4
	victim.Shake(1, 0, duration)

/// "" for the plain wire's colours, "_live" for the Arc's.
/datum/hv_finisher/garrote/proc/wire_suffix()
	return istype(wire, /obj/item/melee/cyberware_monowire/live) ? "_live" : ""

/// A body lying beside the garroter is turned head first to them, as tg turns a body dragged sideways.
/datum/hv_finisher/garrote/proc/face_victim_in()
	if(QDELETED(victim) || victim.body_position != LYING_DOWN)
		return
	var/toward = get_dir(victim, user)
	if(toward & EAST)
		victim.set_lying_angle(LYING_ANGLE_EAST)
	else if(toward & WEST)
		victim.set_lying_angle(LYING_ANGLE_WEST)

/// Where the victim's neck is drawn, in pixels from the middle of its tile before its own offsets: 6 px above the
/// middle of an upright body, turned with a lying one. list(x, y)
/datum/hv_finisher/garrote/proc/neck_offset()
	var/matrix/shape = victim.transform
	return list(round(shape.b * 6 + shape.c), round(shape.e * 6 + shape.f))

/// The garroter's two hands, in pixels from the middle of its tile before its own offsets. list(list(x, y), list(x, y))
/datum/hv_finisher/garrote/proc/hand_offsets()
	if(user.dir & EAST)
		return list(list(2, -6), list(5, -5))
	if(user.dir & WEST)
		return list(list(-2, -6), list(-5, -5))
	if(user.dir & NORTH)
		return list(list(-7, -5), list(7, -5))
	return list(list(7, -5), list(-7, -5))

/// Where the neck should be in the hold, in pixels from the middle of the garroter's tile: just in front of it, at
/// its hands. list(x, y)
/datum/hv_finisher/garrote/proc/hold_point()
	var/front_x = 0
	var/front_y = -6
	if(user.dir & EAST)
		front_x = 9
	else if(user.dir & WEST)
		front_x = -9
	else if(user.dir & NORTH)
		front_y = 8
	else
		front_y = -14
	return list(front_x + user.pixel_x, front_y + user.pixel_y)

/// Where the neck is drawn now, in pixels from the middle of the garroter's tile. list(x, y)
/datum/hv_finisher/garrote/proc/neck_point()
	var/list/neck = neck_offset()
	return list(neck[1] + victim.pixel_x + (victim.x - user.x) * ICON_SIZE_X, neck[2] + victim.pixel_y + (victim.y - user.y) * ICON_SIZE_Y)

/**
 * The hold drags the neck in to the garroter's hands. The grab already pulls the body 12 px toward them (and turns a
 * body dragged sideways head first); this draws it the rest of the way. Drawn only, and taken off with the
 * finisher's other offsets when it ends.
 */
/datum/hv_finisher/garrote/proc/pull_close()
	if(QDELETED(user) || QDELETED(victim))
		return
	var/list/neck = neck_point()
	var/list/target = hold_point()
	victim.add_offsets(HV_FINISHER_OFFSET, x_add = clamp(target[1] - neck[1], -12, 12), y_add = clamp(target[2] - neck[2], -12, 12))

/// Draws the loop round the victim's neck: hanging loose, or drawing tight over the hold.
/datum/hv_finisher/garrote/proc/show_loop(tight)
	qdel(loop_ref?.resolve())
	loop_ref = null
	if(QDELETED(victim))
		return
	// Over the garroter's legs, which the body lies against.
	var/obj/effect/abstract/cyberware_anim/loop = cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_[tight ? "tight" : "loop"][wire_suffix()]", ABOVE_MOB_LAYER, longest_duration(), glow = TRUE)
	loop_ref = WEAKREF(loop)

/// The wire from the garroter's hands to the neck, one strand a hand, in the wire's own colour.
/datum/hv_finisher/garrote/proc/draw_wire(duration, both_hands = TRUE)
	clear_strands()
	if(QDELETED(user) || QDELETED(victim))
		return
	var/list/neck = neck_offset()
	var/list/hands = hand_offsets()
	if(!both_hands)
		hands.Cut(2)
	for(var/list/hand as anything in hands)
		var/datum/beam/strand = user.Beam(victim, icon_state = "wire_taut[wire_suffix()]", icon = WIRE_GORE_ICON, time = duration, override_origin_pixel_x = user.pixel_x + hand[1], override_origin_pixel_y = user.pixel_y + hand[2], override_target_pixel_x = victim.pixel_x + neck[1], override_target_pixel_y = victim.pixel_y + neck[2])
		LAZYADD(strand_refs, WEAKREF(strand))

/datum/hv_finisher/garrote/proc/clear_strands()
	for(var/datum/weakref/strand_ref as anything in strand_refs)
		qdel(strand_ref.resolve())
	strand_refs = null

/datum/hv_finisher/garrote/proc/clear_wire_fx()
	qdel(loop_ref?.resolve())
	loop_ref = null
	clear_strands()
	if(!QDELETED(wire))
		wire.show_inhand()

/**
 * The kill: the head off in hard crit, else the throat slit, else (turned by a helmet, collar or plating) an
 * ordinary blow with the wire. Lines go out while the head is still on, since they name it.
 */
/datum/hv_finisher/garrote/proc/kill(spray_dir)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	var/seared = wire.wire_sears(victim)
	// The body as it is drawn while the wire goes through, for where the head lands.
	var/matrix/body_shape = matrix(victim.transform)
	var/list/body_offsets = list(victim.pixel_x, victim.pixel_y, victim.pixel_w, victim.pixel_z)
	var/head_side = (get_dir(victim, user) & (EAST | NORTH)) ? 1 : -1
	clear_wire_fx()
	cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_snap[wire_suffix()]", ABOVE_MOB_LAYER, 0.6 SECONDS, glow = TRUE)
	if(victim.stat >= HARD_CRIT && head.can_dismember())
		victim.hv_add_hit_line("[user] draws the wire through [victim]'s neck!", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
		if(seared)
			LAZYSET(victim.hv_stump_burnt, BODY_ZONE_HEAD, TRUE)
		// Dropped, brain and all, as #509's finishers drop a head: where the neck was, at the garroter's feet.
		if(hv_wire_take_part(head, seared ? WOUND_BURN : WOUND_SLASH, seared ? WIRE_ARC_BLEED_MULT : 1, !seared))
			wire_drop_head(head, body_shape, body_offsets, head_side)
			finish_blood(spray_dir, seared)
			log_combat(user, victim, "garroted the head off", wire)
			return
		LAZYREMOVE(victim.hv_stump_burnt, BODY_ZONE_HEAD)
	var/datum/hv_crit/throat/throat = locate() in GLOB.hv_crits
	var/blocker = wire_turned_by(head, throat)
	if(!blocker && throat)
		if(hv_crit_apply_wound(head, throat.wound_type, spray_dir, wire))
			victim.hv_add_hit_line("[user] jerks the wire across [victim]'s throat!")
			throat.announce(victim, spray_dir)
			finish_blood(spray_dir, seared)
			log_combat(user, victim, "garroted the throat of", wire)
			return
	if(blocker)
		victim.hv_add_hit_line("The wire catches on [victim]'s [blocker]!", HV_LINE_BOLD, "The wire catches on your [blocker]!")
	real_blow(BODY_ZONE_HEAD, kill_wound_bonus)

/**
 * The head comes off the end of the neck and lies where it was drawn, a few pixels clear of it: at the garroter's
 * feet, since the hold drew the neck to their hands. Turned as the body lay; an ordinary head again once moved.
 */
/proc/wire_drop_head(obj/item/bodypart/head/head, matrix/body_shape, list/body_offsets, side)
	if(QDELETED(head) || !isturf(head.loc))
		return
	// Its picture is shifted by (px_x, px_y) to sit mid-tile; on the body its middle is 9 px up.
	var/list/pivot = list(head.px_x, 9 + head.px_y)
	head.transform = wire_limb_rest(pivot, list(0, 13), side, TRUE, body_shape)
	head.pixel_x = body_offsets[1]
	head.pixel_y = body_offsets[2]
	head.pixel_w = body_offsets[3]
	head.pixel_z = body_offsets[4]
	head.RegisterSignal(head, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item/bodypart, wire_stand_up), override = TRUE)

/// The open neck empties: a spray away from the garroter and a pool under the body. A seared one only smokes.
/datum/hv_finisher/garrote/proc/finish_blood(spray_dir, seared)
	if(QDELETED(victim))
		return
	if(seared)
		wire_stump_smoke(victim, BODY_ZONE_HEAD)
		playsound(victim, 'sound/effects/wounds/sizzle1.ogg', 60, TRUE)
		return
	victim.hv_wire_spray(spray_dir, 3)
	victim.add_splatter_floor(get_turf(victim))

/// What stops the wire at the throat ("helmet", "collar", "plating"), or null. The same gates as #509's
/// throat crit, with the wire's penetration not counted (the crit gates never count it).
/datum/hv_finisher/garrote/proc/wire_turned_by(obj/item/bodypart/head/head, datum/hv_crit/throat/throat)
	var/mob/living/carbon/human/dressed = ishuman(victim) ? victim : null
	if(throat?.blocked_on_carbon(victim, head, wire))
		if(victim.is_mouth_covered(ITEM_SLOT_HEAD))
			return "helmet"
		return "collar"
	if(hv_crit_cover_rating(victim, head, MELEE, 0) >= WIRE_GARROTE_COVER)
		if(dressed?.head || dressed?.wear_mask)
			return "helmet"
		if(dressed?.wear_neck)
			return "collar"
		return "plating"
	return null

// ---- Stages ----

/datum/hv_finisher_stage/windup/garrote
	duration = 1 SECONDS
	rise = 0
	lunge = 2
	enter_range = COMBAT_MESSAGE_RANGE

/datum/hv_finisher_stage/windup/garrote/enter_message()
	return "[host.user] loops the wire around [host.victim]'s neck."

/datum/hv_finisher_stage/windup/garrote/enter_self_message()
	return "A wire loops around your neck!"

/datum/hv_finisher_stage/hold/garrote
	duration = 1.5 SECONDS
	lunge = 4
	enter_sound = 'voidcrew/sound/monowire2.ogg'
	enter_volume = 50
	enter_range = COMBAT_MESSAGE_RANGE

/datum/hv_finisher_stage/hold/garrote/enter()
	. = ..()
	var/datum/hv_finisher/garrote/garrote = host
	garrote.pull_close()
	garrote.show_loop(tight = TRUE)
	// Taut until the kill beat cuts it.
	garrote.draw_wire(duration + 0.5 SECONDS)
	host.victim.Shake(2, 1, duration)

/datum/hv_finisher_stage/hold/garrote/enter_message()
	return "[host.user] pulls the wire tight!"

/datum/hv_finisher_stage/hold/garrote/enter_self_message()
	return "The wire bites into your neck!"

/datum/hv_finisher_stage/kill/garrote
	duration = 1 SECONDS
	effect_delay = 0.5 SECONDS
	lunge = 2

/datum/hv_finisher_stage/kill/garrote/effect()
	var/datum/hv_finisher/garrote/garrote = host
	garrote.kill(away_dir())

#undef WIRE_GARROTE_INTERRUPT
