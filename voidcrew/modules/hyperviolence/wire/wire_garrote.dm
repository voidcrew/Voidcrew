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
/// The wind-up: the wire shoots from the hand to the neck, then winds round it.
#define WIRE_GARROTE_REACH_TIME (0.3 SECONDS)
#define WIRE_GARROTE_WIND_TIME (0.3 SECONDS)

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
	/// The loop drawn round the neck: its far side, behind the neck, and its near side
	var/list/loop_refs
	/// The wire in flight from the hand to the neck
	var/datum/weakref/reach_ref
	/// Timers of the wind-up's beats
	var/list/windup_timers
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

/**
 * No mark over the victim (owner D34). The garroter leans in (the stage's lunge) and the wire shoots from the hand,
 * arcs through the air to the neck and winds round it; then it hangs there loose, glinting, while they struggle.
 */
/datum/hv_finisher/garrote/place_mark(duration)
	QDEL_NULL(mark)
	face_victim_in()
	// The wire leaves the hand: from here it is drawn in flight and round the neck, not hanging.
	wire?.hide_inhand_for(longest_duration())
	throw_wire()
	LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(wind_loop), duration - WIRE_GARROTE_REACH_TIME), WIRE_GARROTE_REACH_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME))
	victim.Shake(1, 0, duration)

/**
 * The world layer for wire leaving a hand. Facing away, the hands are hidden in front of the garroter and the body lies
 * beyond them: the wire runs between the two bodies, under the garroter and over the one lying there.
 */
/datum/hv_finisher/garrote/proc/strand_layer(behind)
	if(behind && user.dir == NORTH)
		return WIRE_BETWEEN_LAYER
	return wire_line_layer(behind)

/// "left" or "right": the hand the wire is in.
/datum/hv_finisher/garrote/proc/wire_side()
	return wire?.held_side(user) || "right"

/**
 * The wire in flight: a line from the hand whose end runs out to the neck along a short arc. One sprite of a
 * straight line, stretched and turned each beat, so the line stays as thin as the hanging filament.
 */
/datum/hv_finisher/garrote/proc/throw_wire()
	qdel(reach_ref?.resolve())
	reach_ref = null
	var/turf/from = get_turf(user)
	if(!from || QDELETED(victim))
		return
	var/list/hand = wire_hand_point(user, wire_side())
	var/hand_x = user.pixel_x + hand[1]
	var/hand_y = user.pixel_y + hand[2]
	var/list/neck = neck_point()
	var/obj/effect/abstract/wire_reach/reach = new(from)
	reach.icon_state = "wire_reach[wire_suffix()]"
	reach.layer = strand_layer(hand[3])
	reach.add_overlay(emissive_appearance(reach.icon, reach.icon_state, reach))
	reach.pixel_x = hand_x
	reach.pixel_y = hand_y
	var/span_x = neck[1] - hand_x
	var/span_y = neck[2] - hand_y
	var/span = max(sqrt(span_x ** 2 + span_y ** 2), 1)
	// Out of the hand, up over the middle, down onto the neck.
	reach.transform = wire_reach_shape(span_x * 2 / span, span_y * 2 / span)
	animate(reach, transform = wire_reach_shape(span_x / 2, span_y / 2 + 6), time = WIRE_GARROTE_REACH_TIME / 2, easing = SINE_EASING | EASE_OUT)
	animate(transform = wire_reach_shape(span_x, span_y), time = WIRE_GARROTE_REACH_TIME / 2, easing = SINE_EASING | EASE_IN)
	reach_ref = WEAKREF(reach)
	QDEL_IN(reach, WIRE_GARROTE_REACH_TIME + 1)

/// The flying wire's line drawn from its start to (`span_x`, `span_y`) pixels away: the sprite is half a tile of
/// line running up from the middle, so it is stretched to the length and turned to the bearing.
/proc/wire_reach_shape(span_x, span_y)
	var/matrix/shape = matrix()
	shape.Scale(1, max(sqrt(span_x ** 2 + span_y ** 2), 1) / 16)
	shape.Turn(arctan(span_y, span_x))
	return shape

/// The end of the throw: the wire winds round the neck and is held there, loose, for the rest of the wind-up.
/datum/hv_finisher/garrote/proc/wind_loop(rest)
	if(QDELETED(user) || QDELETED(victim) || !running)
		return
	show_loop("draw")
	LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(show_loop), "loop"), WIRE_GARROTE_WIND_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME))
	draw_wire(rest, both_hands = FALSE)
	var/obj/effect/abstract/cyberware_anim/glint = cyberware_anim_play(user, WIRE_GORE_ICON, "wire_glint[wire_suffix()]", WIRE_FX_LAYER, 0.3 SECONDS, glow = TRUE)
	if(glint)
		glint.pixel_y = -4

/// The wire in flight. Nothing to click.
/obj/effect/abstract/wire_reach
	name = "wire"
	icon = WIRE_GORE_ICON
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = PIXEL_SCALE | TILE_BOUND

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
		// Facing away the neck is beyond the garroter: drawn just over their head, not hidden behind it.
		front_y = 16
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

/**
 * Draws the loop round the victim's neck: `kind` "draw" (winding on), "loop" (hanging loose) or "tight" (drawing
 * tight over the hold). Its far side is drawn under the body, so the neck hides it and only its ends show; its near
 * side over the body.
 */
/datum/hv_finisher/garrote/proc/show_loop(kind)
	clear_loop()
	if(QDELETED(victim) || !running)
		return
	var/lifetime = longest_duration()
	var/obj/effect/abstract/cyberware_anim/far_side = cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_[kind]_back[wire_suffix()]", -(TOTAL_LAYERS + 0.5), lifetime, glow = TRUE)
	// Over the garroter's legs, which the body lies against; facing away, over the neck but under the garroter.
	var/near_layer = user.dir == NORTH ? WIRE_BETWEEN_LAYER : ABOVE_MOB_LAYER
	var/obj/effect/abstract/cyberware_anim/near_side = cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_[kind]_front[wire_suffix()]", near_layer, lifetime, glow = TRUE)
	loop_refs = list(WEAKREF(far_side), WEAKREF(near_side))

/datum/hv_finisher/garrote/proc/clear_loop()
	for(var/datum/weakref/loop_ref as anything in loop_refs)
		qdel(loop_ref.resolve())
	loop_refs = null

/**
 * The wire from the garroter's hands to the neck, one strand a hand (or only the wire's hand), in the wire's own
 * colour. A strand from a hand behind the garroter's body (the far hand in profile, both facing away) is drawn under
 * the bodies, so the torso hides it.
 */
/datum/hv_finisher/garrote/proc/draw_wire(duration, both_hands = TRUE)
	clear_strands()
	if(QDELETED(user) || QDELETED(victim))
		return
	var/list/neck = neck_offset()
	var/list/sides = both_hands ? list("left", "right") : list(wire_side())
	for(var/side in sides)
		var/list/hand = wire_hand_point(user, side)
		var/datum/beam/strand = user.Beam(victim, icon_state = "wire_taut[wire_suffix()]", icon = WIRE_GORE_ICON, time = duration, beam_type = /obj/effect/ebeam/wire_line, override_origin_pixel_x = user.pixel_x + hand[1], override_origin_pixel_y = user.pixel_y + hand[2], override_target_pixel_x = victim.pixel_x + neck[1], override_target_pixel_y = victim.pixel_y + neck[2], layer = strand_layer(hand[3]))
		LAZYADD(strand_refs, WEAKREF(strand))

/datum/hv_finisher/garrote/proc/clear_strands()
	for(var/datum/weakref/strand_ref as anything in strand_refs)
		qdel(strand_ref.resolve())
	strand_refs = null

/datum/hv_finisher/garrote/proc/clear_wire_fx()
	for(var/timer in windup_timers)
		deltimer(timer)
	windup_timers = null
	qdel(reach_ref?.resolve())
	reach_ref = null
	clear_loop()
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
	// Where the body is drawn while the wire goes through, for where the head lands.
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
			wire_drop_head(head, victim, body_offsets, head_side)
			finish_blood(spray_dir, seared)
			log_combat(user, victim, "garroted the head off", wire)
			return
		LAZYREMOVE(victim.hv_stump_burnt, BODY_ZONE_HEAD)
	var/datum/hv_crit/throat/throat = locate() in GLOB.hv_crits
	var/blocker = wire_turned_by(head, throat)
	if(!blocker && throat)
		// No direction: tg would throw its flying splatter down a straight line. The garrote's blood is finish_blood().
		var/datum/wound/slit = hv_crit_apply_wound(head, throat.wound_type, null, wire)
		if(slit)
			victim.hv_add_hit_line("[user] jerks the wire across [victim]'s throat!")
			throat.announce(victim, spray_dir)
			wire_open_throat(victim, slit)
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
/proc/wire_drop_head(obj/item/bodypart/head/head, mob/living/body, list/body_offsets, side)
	if(QDELETED(head) || !isturf(head.loc))
		return
	// On the body its middle is 9 px up; it lies 4 px further out, off the end of the neck. Its picture is
	// shifted by (px_x, px_y) to sit mid-tile, after its transform.
	head.transform = wire_part_pose(list(0, 9), side * 10, list(side * 2, 13), body, head.px_x, head.px_y)
	head.pixel_x = body_offsets[1]
	head.pixel_y = body_offsets[2]
	head.pixel_w = body_offsets[3]
	head.pixel_z = body_offsets[4]
	head.RegisterSignal(head, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item/bodypart, wire_stand_up), override = TRUE)

/**
 * The open neck empties. Blood bursts out all round it and lands in a rough ring of drops and splats over the floor
 * about the neck, the garroter included; it soaks the garroter's hands and clothes; and a pool spreads under the
 * neck over the next couple of seconds. A seared one only smokes.
 */
/datum/hv_finisher/garrote/proc/finish_blood(spray_dir, seared)
	if(QDELETED(victim))
		return
	if(seared)
		wire_stump_smoke(victim, BODY_ZONE_HEAD)
		playsound(victim, 'sound/effects/wounds/sizzle1.ogg', 60, TRUE)
		return
	var/turf/neck_turf = get_turf(victim)
	if(!neck_turf || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/list/blood_dna = victim.get_blood_dna_list()
	var/list/viruses = victim.get_static_viruses()
	var/list/neck = neck_point()
	var/turf/user_turf = get_turf(user)
	// Where the neck is, from the middle of the victim's tile.
	var/neck_x = neck[1] - (victim.x - user.x) * ICON_SIZE_X
	var/neck_y = neck[2] - (victim.y - user.y) * ICON_SIZE_Y
	wire_pool_under(neck_turf, neck_x, neck_y, blood_dna, viruses)
	wire_blood_burst(neck_turf, neck_x, neck_y, wire_blood_color(victim), blood_dna)
	if(!QDELETED(user))
		user.hv_blood_drench(blood_dna, viruses)
		if(ishuman(user))
			var/mob/living/carbon/human/soaked = user
			soaked.add_blood_DNA_to_items(blood_dna, ITEM_SLOT_ICLOTHING | ITEM_SLOT_OCLOTHING | ITEM_SLOT_GLOVES | ITEM_SLOT_HANDS | ITEM_SLOT_FEET, viruses)
		// A few splats round the garroter's own feet.
		if(user_turf && user_turf != neck_turf && !isgroundlessturf(user_turf))
			for(var/i in 1 to 2)
				var/obj/effect/decal/cleanable/blood/drip/wire_flick/drop = new(user_turf, null, blood_dna)
				if(!QDELETED(drop))
					drop.pixel_x = rand(-9, 9)
					drop.pixel_y = rand(-12, 0)

/**
 * The pool under the neck: tg's blood decal for the tile, centred on the neck, filled over a couple of seconds so it
 * steps up through the pool sizes (blood/blood_pools.dm) as it spreads, to one that keeps to the tile.
 */
/proc/wire_pool_under(turf/neck_turf, neck_x, neck_y, list/blood_dna, list/viruses)
	if(isgroundlessturf(neck_turf))
		return
	var/obj/effect/decal/cleanable/blood/pool
	for(var/obj/effect/decal/cleanable/blood/found in neck_turf)
		if(found.type == /obj/effect/decal/cleanable/blood && !found.dried && !QDELETED(found))
			pool = found
			break
	if(!pool)
		pool = new /obj/effect/decal/cleanable/blood(neck_turf, viruses, blood_dna)
		if(QDELETED(pool))
			return
		// A fresh pool sits under the neck rather than mid-tile; a pool already there stays put.
		pool.base_pixel_x = clamp(neck_x, -8, 8)
		pool.base_pixel_y = clamp(neck_y, -8, 8)
		pool.pixel_x = pool.base_pixel_x
		pool.pixel_y = pool.base_pixel_y
	else
		pool.add_blood_DNA(blood_dna)
	for(var/step in 0 to 3)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_pool_fill), pool), step * 0.45 SECONDS)

/// One beat of the garrote's pool filling, never past WIRE_GARROTE_POOL_CAP.
/proc/wire_pool_fill(obj/effect/decal/cleanable/blood/pool)
	if(QDELETED(pool) || pool.bloodiness >= WIRE_GARROTE_POOL_CAP)
		return
	pool.adjust_bloodiness(min(40, WIRE_GARROTE_POOL_CAP - pool.bloodiness))

/**
 * Blood bursts from a wound at (`from_x`, `from_y`) pixels from the middle of `origin` and lands round it: `count` drops
 * thrown at uneven reach (`reach` pixels, give or take a few), landing as drips, and every third a heavier splat. With
 * no `bearing` they go every way, no two in a row alike, so it lands as a broken ring; with one (degrees, 0 north)
 * they go within `spread` degrees either side of it, a short spray rather than a line.
 */
/proc/wire_blood_burst(turf/origin, from_x, from_y, blood_color, list/blood_dna, count = 10, bearing = null, spread = 0, list/reach = list(9, 13, 17, 22, 26))
	var/start = rand(0, 359)
	var/list/splatted = list()
	for(var/i in 1 to count)
		var/angle = isnull(bearing) ? start + i * (360 / count) + rand(-14, 14) : bearing + rand(-spread, spread)
		var/distance = pick(reach) + rand(-2, 2)
		var/land_x = from_x + round(sin(angle) * distance)
		var/land_y = from_y + round(cos(angle) * distance)
		var/height = 3 + rand(0, 5)
		var/flight = round(1.5 + distance / 14, 0.5)
		new /obj/effect/temp_visual/wire_blood_drop(origin, list(from_x, from_y, land_x, land_y, height, flight, 0), blood_color, blood_dna)
		if(i % 3)
			continue
		// One splat to a tile.
		var/tile_x = floor((land_x + 16) / 32)
		var/tile_y = floor((land_y + 16) / 32)
		var/turf/landing = locate(origin.x + tile_x, origin.y + tile_y, origin.z)
		if(!landing || (landing in splatted) || isgroundlessturf(landing) || (landing != origin && hv_blood_spray_blocked(landing)))
			continue
		splatted += landing
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_ring_splat), landing, land_x - tile_x * 32, land_y - tile_y * 32, blood_dna), flight)

/// A heavy splat of the ring, tg's small splatter, landing at (`pixel_x`, `pixel_y`) on `landing`.
/proc/wire_ring_splat(turf/landing, pixel_x, pixel_y, list/blood_dna)
	if(!landing)
		return
	var/obj/effect/decal/cleanable/blood/splatter/splat = new(landing, null, blood_dna)
	if(QDELETED(splat))
		return
	// tg's splatter art is drawn round the middle of its tile.
	splat.pixel_x = clamp(pixel_x, -12, 12)
	splat.pixel_y = clamp(pixel_y, -12, 12)

/// The open throat, drawn on the neck for as long as the wound in it is there.
/obj/effect/abstract/cyberware_anim/wire_throat
	name = "slit throat"
	icon = WIRE_GORE_ICON
	icon_state = "throat_open"
	/// The wound it shows
	var/datum/wound/slit

/obj/effect/abstract/cyberware_anim/wire_throat/Destroy()
	slit = null
	return ..()

/obj/effect/abstract/cyberware_anim/wire_throat/proc/on_lose_wound(datum/source, datum/wound/lost)
	SIGNAL_HANDLER
	if(lost == slit)
		qdel(src)

/obj/effect/abstract/cyberware_anim/wire_throat/proc/on_lose_limb(datum/source, obj/item/bodypart/lost)
	SIGNAL_HANDLER
	if(lost?.body_zone == BODY_ZONE_HEAD)
		qdel(src)

/// Draws the throat `slit` opened on `victim`, in their blood's colour, until the wound closes or the head is gone.
/proc/wire_open_throat(mob/living/carbon/victim, datum/wound/slit)
	if(QDELETED(victim) || !slit)
		return
	var/obj/effect/abstract/cyberware_anim/wire_throat/mark = new(null)
	mark.slit = slit
	// Over the collar of whatever they wear, under anything worn round the neck.
	mark.layer = -(NECK_LAYER + 0.5)
	mark.appearance_flags |= RESET_COLOR
	mark.color = wire_blood_color(victim)
	mark.bearer = victim
	mark.RegisterSignal(victim, COMSIG_QDELETING, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim, on_bearer_deleted))
	mark.RegisterSignal(victim, COMSIG_CARBON_LOSE_WOUND, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_throat, on_lose_wound))
	mark.RegisterSignal(victim, COMSIG_CARBON_REMOVE_LIMB, TYPE_PROC_REF(/obj/effect/abstract/cyberware_anim/wire_throat, on_lose_limb))
	victim.vis_contents += mark

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
	lunge = 3
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
	garrote.show_loop("tight")
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
#undef WIRE_GARROTE_REACH_TIME
#undef WIRE_GARROTE_WIND_TIME
