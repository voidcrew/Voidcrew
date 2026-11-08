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
	/// The taut line from the hand to the neck
	var/datum/weakref/taut_ref

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
	show_loop(tight = FALSE)
	var/obj/effect/abstract/cyberware_anim/glint = cyberware_anim_play(user, WIRE_GORE_ICON, "wire_glint[wire_suffix()]", WIRE_FX_LAYER, 0.3 SECONDS, glow = TRUE)
	if(glint)
		glint.pixel_y = -4
	victim.Shake(1, 0, duration)

/// "" for the plain wire's colours, "_live" for the Arc's.
/datum/hv_finisher/garrote/proc/wire_suffix()
	return istype(wire, /obj/item/melee/cyberware_monowire/live) ? "_live" : ""

/// Draws the loop round the victim's neck: hanging loose, or pulled tight.
/datum/hv_finisher/garrote/proc/show_loop(tight)
	qdel(loop_ref?.resolve())
	loop_ref = null
	if(QDELETED(victim))
		return
	var/obj/effect/abstract/cyberware_anim/loop = cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_[tight ? "tight" : "loop"][wire_suffix()]", WIRE_FX_LAYER, longest_duration(), glow = TRUE)
	loop_ref = WEAKREF(loop)

/// The wire drawn taut from the garroter's hand to the victim's neck.
/datum/hv_finisher/garrote/proc/draw_taut(duration)
	qdel(taut_ref?.resolve())
	taut_ref = null
	if(QDELETED(user) || QDELETED(victim))
		return
	// The neck sits 6 px above the middle of an upright body; a lying body is turned, so turn that with it.
	var/matrix/shape = victim.transform
	var/x_offset = round(shape.b * 6 + shape.c)
	var/y_offset = round(shape.e * 6 + shape.f)
	var/datum/beam/taut = user.Beam(victim, icon_state = "wire_taut[wire_suffix()]", icon = WIRE_GORE_ICON, time = duration, override_origin_pixel_x = user.pixel_x, override_origin_pixel_y = user.pixel_y - 2, override_target_pixel_x = victim.pixel_x + x_offset, override_target_pixel_y = victim.pixel_y + y_offset)
	taut_ref = WEAKREF(taut)

/datum/hv_finisher/garrote/proc/clear_wire_fx()
	qdel(loop_ref?.resolve())
	loop_ref = null
	qdel(taut_ref?.resolve())
	taut_ref = null

/**
 * The kill: the head off in hard crit, else the throat slit, else (turned by a helmet, collar or plating) an
 * ordinary blow with the wire. Lines go out while the head is still on, since they name it.
 */
/datum/hv_finisher/garrote/proc/kill(spray_dir)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	var/seared = wire.wire_sears(victim)
	if(victim.stat >= HARD_CRIT && head.can_dismember())
		victim.hv_add_hit_line("[user] draws the wire through [victim]'s neck!", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
		if(seared)
			LAZYSET(victim.hv_stump_burnt, BODY_ZONE_HEAD, TRUE)
		// Dropped where the body lies, brain and all, as #509's finishers drop a head; one bleed's worth, a quarter seared.
		if(hv_wire_take_part(head, seared ? WOUND_BURN : WOUND_SLASH, seared ? WIRE_ARC_BLEED_MULT * 0.5 : 0.5, !seared))
			if(!seared)
				victim.hv_wire_spray(spray_dir, 3)
			log_combat(user, victim, "garroted the head off", wire)
			return
		LAZYREMOVE(victim.hv_stump_burnt, BODY_ZONE_HEAD)
	var/datum/hv_crit/throat/throat = locate() in GLOB.hv_crits
	var/blocker = wire_turned_by(head, throat)
	if(!blocker && throat)
		if(hv_crit_apply_wound(head, throat.wound_type, spray_dir, wire))
			victim.hv_add_hit_line("[user] jerks the wire across [victim]'s throat!")
			throat.announce(victim, spray_dir)
			if(!seared)
				victim.hv_wire_spray(spray_dir, 3)
			log_combat(user, victim, "garroted the throat of", wire)
			return
	if(blocker)
		victim.hv_add_hit_line("The wire catches on [victim]'s [blocker]!", HV_LINE_BOLD, "The wire catches on your [blocker]!")
	real_blow(BODY_ZONE_HEAD, kill_wound_bonus)

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
	garrote.show_loop(tight = TRUE)
	garrote.draw_taut(duration + 1 SECONDS)
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
