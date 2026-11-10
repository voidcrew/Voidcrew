/**
 * # The garrote
 *
 * A Widowline wielder standing over someone lying on the floor who can't fight back (in crit, or stunned:
 * lying down alone isn't enough; on their feet, or strapped into a chair or bed, never) loops the wire round
 * their neck with a combat click at the head or mouth. It is #509's finisher engine (hyperviolence/finishers/)
 * run by a person: a real aggressive grab, interruptible the same ways.
 *
 * - Wind-up (1 s): the wire loops round the neck and glints. No mark over the victim (owner D34): the loop
 *   and the struggle are the tell. It holds nobody, so pulling the victim clear, or them coming round, ends it.
 * - Hold (1.5 s): the grab, the wire goes taut and bites, the victim thrashes. The garroter stays leaned in over
 *   them from the throw to the cut, and leans further in for the kill: never back.
 * - Kill (0.5 s into the stage): in hard crit the head comes off (an Atlas frame keeps it); otherwise the
 *   throat is slit, #509's carotid crit. A sealed helmet, an armoured collar or plating that would stop
 *   the throat crit turns the wire, and it lands as an ordinary blow at the head instead.
 * - Broken by #509's rules: the grab broken or pulled apart, the garroter hurt (WIRE_GARROTE_INTERRUPT
 *   health), stunned, cuffed or out of their wire, the victim dying first, the timeout. Also by the victim
 *   getting up off the floor or being strapped to something, at any point before the kill.
 *
 * Only wielders that hv_wire_moves_allowed() lets use the wire's moves (wire_users.dm) can start one. It
 * refuses allies, starts the outpost's self-defence clock like any attack, and the wielder waits
 * WIRE_GARROTE_COOLDOWN after one that got a grip, WIRE_GARROTE_MISS_COOLDOWN after one that didn't.
 */

/// Health the garroter can lose before letting go.
#define WIRE_GARROTE_INTERRUPT 20
/// The wind-up: the wire shoots from the hand to the neck, then winds round it.
#define WIRE_GARROTE_REACH_TIME (0.3 SECONDS)
/// The garroter leans in (the wind-up's lunge, drawn over tg's offset time) before the wire leaves the hand.
#define WIRE_GARROTE_LEAN_TIME UPDATE_TRANSFORM_ANIMATION_TIME
#define WIRE_GARROTE_WIND_TIME (0.3 SECONDS)
/// Steps the flying wire is drawn out in.
#define WIRE_GARROTE_THROW_BEATS 6
/// Steps a strand slides in with the body in, as the hold pulls it to the garroter's feet.
#define WIRE_GARROTE_SLIDE_BEATS 8
/// A body turned end for end at the wind-up swings round over this long, not in one frame.
#define WIRE_GARROTE_TURN_TIME (0.24 SECONDS)
/// The pool under the neck spreads from a spot to its full size over this long.
#define WIRE_GARROTE_POOL_TIME (1.8 SECONDS)
/// The head's drop from the neck to the floor.
#define WIRE_GARROTE_HEAD_FALL_TIME (0.2 SECONDS)
/// Pixels below the neck the pool goes facing away, where the dropped head lies against the stump.
#define WIRE_GARROTE_POOL_DROP_NORTH 6
/// One beat of the victim's thrashing in the hold.
#define WIRE_GARROTE_JOLT_TIME (0.05 SECONDS)
/// A garroted body's last twitches begin this long after it has slumped back onto its tile.
#define WIRE_GARROTE_TWITCH_WAIT (0.6 SECONDS)
/// A line of wire starts this far before the middle of the pixel at its base, so that pixel is always drawn.
#define WIRE_LINE_BACK 0.5
/// Trait source: a body held still from bobbing while wire_shake() shakes it.
#define WIRE_SHAKE_TRAIT "wire_shake"

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

/// Someone the wire can be looped round: lying on the floor (wire_garrote_on_floor()) and unable to fight it off, in
/// crit or stunned. Lying down alone doesn't count, and neither does a stun that leaves them on their feet.
/proc/wire_garrote_helpless(mob/living/victim)
	return wire_garrote_on_floor(victim) && (victim.stat >= SOFT_CRIT || HAS_TRAIT(victim, TRAIT_INCAPACITATED))

/// Lying on the floor, not strapped into a chair or bed: where a garrote's victim has to stay from the first loop to the cut.
/proc/wire_garrote_on_floor(mob/living/victim)
	return victim.body_position == LYING_DOWN && !victim.buckled

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
	/// The wire in flight from the hand to the neck: one straight line. It lies there, slack, until the hold pulls it taut.
	var/list/reach_refs
	/// Timers of the wind-up's beats
	var/list/windup_timers
	/// The strands of wire from the garroter's hands to the neck
	var/list/strand_refs
	/// The far side of the loop, drawn among the victim's own overlays under the body
	var/mutable_appearance/loop_back
	/// The victim's layer before the hold drew them over a garroter facing the viewer, or null
	var/victim_old_layer
	/// Timer of the victim's struggle in the hold
	var/struggle_timer
	/// Where the two were drawn as the grip was taken, before the hold drew them into place:
	/// list(garroter pixel_x, pixel_y, victim pixel_x, pixel_y)
	var/list/pull_from
	/// TRUE from the hold's strands until the wire comes off the neck: no wire is drawn hanging in the garroter's hands
	var/hands_hidden = FALSE
	/// Other Widowlines the garroter holds, hidden from their hands meanwhile
	var/list/off_hand_refs

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
	if(!gripped && !QDELETED(user) && !QDELETED(victim))
		pull_from = drawn_offsets()
	. = ..()
	if(. && !QDELETED(user))
		user.wire_garrote_ready_at = world.time + WIRE_GARROTE_COOLDOWN

/datum/hv_finisher/garrote/safety_check()
	. = ..()
	if(. || completed)
		return
	if(QDELETED(wire) || !user.is_holding(wire))
		return HV_FINISHER_ATTACKER_DOWN
	// Up off the floor or strapped to something, they're out of it, held or not: the grab alone doesn't keep them down.
	if(!wire_garrote_on_floor(victim))
		return HV_FINISHER_LOST_GRIP
	// The wind-up holds nobody: come round enough to fight it off, they're out of it.
	if(!gripped && !wire_garrote_helpless(victim))
		return HV_FINISHER_LOST_GRIP

/datum/hv_finisher/garrote/stop(reason)
	clear_wire_fx()
	restore_victim_layer()
	return ..()

/**
 * Letting go puts the body back all at once: the grab's pull, the hold's drag and the layer it was drawn on go
 * together, so nothing moves again when the finisher ends. The kill lets go itself (let_go_at_kill()); this is for
 * any other way the grip ends.
 */
/datum/hv_finisher/garrote/release_grip()
	. = ..()
	if(!QDELETED(victim))
		victim.remove_offsets(HV_FINISHER_OFFSET)
	restore_victim_layer()

/**
 * The kill lets the body go as the wire goes through: the grab's pull and the hold's drag come off together, and
 * it slumps back onto its own tile in one short move. The garroter straightens out of the lean over the same move,
 * here rather than as the finisher ends, so neither of them moves again after it. Returns how long the move takes:
 * the head, the pool and anything else laid out after the kill wait for it and go where the body rests.
 */
/datum/hv_finisher/garrote/proc/let_go_at_kill()
	if(QDELETED(victim))
		return 0
	var/old_x = victim.pixel_x
	var/old_y = victim.pixel_y
	victim.remove_offsets(HV_FINISHER_OFFSET, animate = FALSE)
	// Taken off here rather than by tg's let-go, which would slide it back on its own clock.
	if(user?.pulling == victim)
		victim.remove_offsets(GRABBING_TRAIT, animate = FALSE)
	// A body drawn up over a garroter facing the viewer stays over their legs until it has dropped clear.
	var/drawn_up_from = victim_old_layer
	victim_old_layer = null
	release_grip()
	var/new_x = victim.pixel_x
	var/new_y = victim.pixel_y
	var/settle_time = 0
	if(new_x != old_x || new_y != old_y)
		settle_time = clamp(round(sqrt((new_x - old_x) ** 2 + (new_y - old_y) ** 2) / 6, 0.5), 2, 4)
		victim.pixel_x = old_x
		victim.pixel_y = old_y
		// Parallel, like tg's own offset moves, so the turn of a body falling or a death shudder runs on beside it.
		animate(victim, pixel_x = new_x, pixel_y = new_y, time = settle_time, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	if(!isnull(drawn_up_from))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_garrote_lay_back), victim, drawn_up_from), settle_time)
	// The lean off now: the recover stage's pose and the finisher's end then find nothing left to move.
	if(!QDELETED(user))
		var/user_old_x = user.pixel_x
		var/user_old_y = user.pixel_y
		user.add_offsets(HV_FINISHER_OFFSET, null, 0, 0, animate = FALSE)
		if(user.pixel_x != user_old_x || user.pixel_y != user_old_y)
			var/user_new_x = user.pixel_x
			var/user_new_y = user.pixel_y
			user.pixel_x = user_old_x
			user.pixel_y = user_old_y
			animate(user, pixel_x = user_new_x, pixel_y = user_new_y, time = max(settle_time, 2), easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)
	return settle_time

/// A body the garrote drew up over its garroter goes back to `old_layer`, unless something else has changed it since.
/proc/wire_garrote_lay_back(mob/living/body, old_layer)
	if(!QDELETED(body) && body.layer == WIRE_PULLED_LAYER)
		body.layer = old_layer

/datum/hv_finisher/garrote/proc/restore_victim_layer()
	if(isnull(victim_old_layer))
		return
	if(!QDELETED(victim) && victim.layer == WIRE_PULLED_LAYER)
		victim.layer = victim_old_layer
	victim_old_layer = null

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
 * No mark over the victim (owner D34). The garroter leans in (the stage's lunge) and the wire shoots straight from the
 * hand to the neck. Once it is there it drags the body round head first to them, if it lay the other way, and winds
 * round the neck; then it hangs there loose, glinting, while they struggle.
 */
/datum/hv_finisher/garrote/place_mark(duration)
	QDEL_NULL(mark)
	// Thrown once the lean has carried the hand to where the throw starts.
	throw_wire(WIRE_GARROTE_LEAN_TIME)
	// The wire leaves its hand: from then on it is drawn in flight and round the neck, not hanging there. A wire in the
	// other hand hangs on until the hold runs a strand from that hand too (draw_wire()).
	LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(hide_thrown_wire)), WIRE_GARROTE_LEAN_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME))
	LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(wire_arrives), duration - WIRE_GARROTE_LEAN_TIME - WIRE_GARROTE_REACH_TIME), WIRE_GARROTE_LEAN_TIME + WIRE_GARROTE_REACH_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME))

/**
 * The throw: the thrown wire is drawn in flight and then round the neck, so its hand doesn't draw it hanging there. Only
 * that hand's: a second Widowline in the other hand hangs there through the throw and the wind-up, until the hold runs a
 * strand from that hand too (hide_hands()). show_hands() puts it back, however the garrote ends.
 */
/datum/hv_finisher/garrote/proc/hide_thrown_wire()
	if(hands_hidden || !running || QDELETED(user) || QDELETED(wire) || !user.is_holding(wire))
		return
	hide_held_wire(wire)

/**
 * From the hold on, a strand runs from each hand to the neck, so neither hand draws a wire hanging in it: not the one
 * thrown, nor a second Widowline in the other hand, held now or taken up while the garrote lasts. Hidden as the strands
 * go up (draw_wire()), so a wire never shows in a hand and as a strand from it at once, nor in neither. show_hands()
 * puts them back, however the garrote ends.
 */
/datum/hv_finisher/garrote/proc/hide_hands()
	if(hands_hidden || !running || QDELETED(user))
		return
	hands_hidden = TRUE
	for(var/obj/item/melee/cyberware_monowire/held in user.held_items)
		hide_held_wire(held)
	RegisterSignal(user, COMSIG_MOB_EQUIPPED_ITEM, PROC_REF(on_user_equipped))

/datum/hv_finisher/garrote/proc/hide_held_wire(obj/item/melee/cyberware_monowire/held)
	// The timeout only backs show_hands() up.
	held.hide_inhand_for(longest_duration())
	if(held != wire)
		LAZYOR(off_hand_refs, WEAKREF(held))

/// A Widowline swung out into a hand while the strands run isn't drawn there either: a strand runs from that hand.
/datum/hv_finisher/garrote/proc/on_user_equipped(mob/living/source, obj/item/equipped, slot)
	SIGNAL_HANDLER
	if((slot & ITEM_SLOT_HANDS) && istype(equipped, /obj/item/melee/cyberware_monowire))
		hide_held_wire(equipped)

/// The wire is off the neck: every wire the garroter holds is drawn in the hand again.
/datum/hv_finisher/garrote/proc/show_hands()
	if(hands_hidden)
		hands_hidden = FALSE
		if(user)
			UnregisterSignal(user, COMSIG_MOB_EQUIPPED_ITEM)
	if(!QDELETED(wire))
		wire.show_inhand()
	for(var/datum/weakref/held_ref as anything in off_hand_refs)
		var/obj/item/melee/cyberware_monowire/held = held_ref.resolve()
		if(!QDELETED(held))
			held.show_inhand()
	off_hand_refs = null

/// TRUE while the garrote is still in its wind-up, the wire loose round the neck.
/datum/hv_finisher/garrote/proc/winding_up()
	return running && !QDELETED(user) && !QDELETED(victim) && istype(current_stage, /datum/hv_finisher_stage/windup)

/**
 * The thrown wire reaches the neck: it drags the body round head first to the garroter, if it lay the other way, and
 * then winds round the neck. `rest` is what is left of the wind-up.
 */
/datum/hv_finisher/garrote/proc/wire_arrives(rest)
	if(!winding_up())
		return
	var/turn_time = face_victim_in()
	if(!turn_time)
		wind_loop(rest)
		return
	LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(wind_loop), rest - turn_time), turn_time, TIMER_STOPPABLE | TIMER_DELETE_ME))

/**
 * The pixel the wire leaves the garroter's `side` hand from (wire_hand_point(), wire_held.dm): the one the held wire's
 * spool lights for each facing, by its lower left corner in pixels from the middle of the tile. A line of wire is
 * drawn from the middle of this pixel. Facing the viewer both hands show at the sides. Facing away they show at the
 * sides too, but the wire runs forward from them, through the garroter's body, so both count as behind it; in profile
 * the far hand does. list(x, y, behind)
 */
/datum/hv_finisher/garrote/proc/hand_point(side)
	return wire_hand_point(user, side)

/**
 * Where a line of wire from the garroter's `side` hand is drawn from: the hand (hand_point()), except facing away.
 * Facing away it runs from the hands, hidden in front of the garroter, to the neck beyond their head; drawn from the
 * hands it showed through the gaps between head and shoulders as a stray pixel each. It is drawn from behind the head
 * instead, on the same line, so it shows only once it clears the head. list(x, y, behind)
 */
/datum/hv_finisher/garrote/proc/line_origin(side)
	if(user.dir == NORTH)
		return side == "left" ? list(-4, 8, TRUE) : list(2, 8, TRUE)
	return hand_point(side)

/**
 * The world layer for wire leaving a hand. Wire from a hand in front goes over both bodies. Wire from a hand behind
 * the garroter goes under them, so their torso, back and head hide it:
 * - Facing away (both hands) it goes over the one lying beyond them, so it shows from where it clears the garroter to
 *   the neck.
 * - In profile (the far hand) it goes round the back of the neck: under the one lying there too, so it shows between
 *   the hand and the head, and their head and neck hide the rest, while the near hand's runs over them.
 */
/datum/hv_finisher/garrote/proc/strand_layer(behind)
	if(!behind)
		return wire_line_layer(FALSE)
	return wire_behind_neck(behind) ? BELOW_MOB_LAYER : WIRE_BETWEEN_LAYER

/// TRUE for wire from a hand `behind` the garroter that goes round the back of the neck, under the body lying there:
/// the far hand's, in profile.
/datum/hv_finisher/garrote/proc/wire_behind_neck(behind)
	return behind && (user.dir & (EAST | WEST))

/**
 * A new line of wire from a hand `behind` or not. It goes on the garroter's turf, except wire round the back of the
 * neck (wire_behind_neck()) with the body on the row behind the garroter's (lying a tile up and to the side): that goes
 * on the body's row, since the map sorts a row in front over a row behind whatever their layers. pixel_z draws it back
 * where it would be on the garroter's turf, so its pixel_x and pixel_y count from there as ever.
 */
/datum/hv_finisher/garrote/proc/new_line(behind)
	var/turf/from = get_turf(user)
	if(!from)
		return null
	if(wire_behind_neck(behind) && !QDELETED(victim) && victim.y > user.y)
		from = locate(user.x, victim.y, user.z) || from
	var/obj/effect/abstract/wire_reach/line = new(from)
	line.pixel_z = (user.y - from.y) * ICON_SIZE_Y
	return line

/// "left" or "right": the hand the wire is in.
/datum/hv_finisher/garrote/proc/wire_side()
	return wire?.held_side(user) || "right"

/**
 * The wire in flight: thrown from the hand, its end flies straight to the neck, the line paying out behind it. One
 * sprite, stretched and turned every beat, so the line stays as thin as the hanging filament. It lies there, slack,
 * until the hold. Unseen for `delay` first.
 */
/datum/hv_finisher/garrote/proc/throw_wire(delay = 0)
	clear_reach()
	var/turf/from = get_turf(user)
	if(!from || QDELETED(victim))
		return
	var/side = wire_side()
	var/list/hand = line_origin(side)
	var/hand_x = user.pixel_x + hand[1]
	var/hand_y = user.pixel_y + hand[2]
	// Thrown at the pixel of the loop this hand's strand will meet, so it lands on the loop as it winds on.
	var/list/meet = loop_point(side)
	var/span_x = meet[1] - (hand_x + 0.5)
	var/span_y = meet[2] - (hand_y + 0.5)
	var/step = WIRE_GARROTE_REACH_TIME / WIRE_GARROTE_THROW_BEATS
	var/obj/effect/abstract/wire_reach/line = new_line(hand[3])
	line.icon_state = "wire_reach[wire_suffix()]"
	// In flight, wire from a hand behind the garroter passes over the body lying there and under the garroter. In profile
	// it goes round the back of the neck once it winds on (land_reach()).
	line.layer = hand[3] ? WIRE_BETWEEN_LAYER : strand_layer(FALSE)
	line.add_overlay(emissive_appearance(line.icon, line.icon_state, line))
	line.pixel_x = hand_x
	line.pixel_y = hand_y
	// A pixel of wire leaving the hand toward the neck.
	line.transform = wire_throw_shape(span_x, span_y, 1)
	if(delay)
		line.alpha = 0
		animate(line, alpha = 0, time = delay)
	for(var/beat in 1 to WIRE_GARROTE_THROW_BEATS)
		var/flown = beat / WIRE_GARROTE_THROW_BEATS
		var/matrix/shape = wire_throw_shape(span_x, span_y, flown * wire_line_length(span_x, span_y))
		if(beat == 1 && !delay)
			animate(line, transform = shape, time = step)
		else
			animate(alpha = 255, transform = shape, time = step)
	LAZYADD(reach_refs, WEAKREF(line))
	// Never outlives the garrote, whatever ends it.
	QDEL_IN(line, longest_duration())

/datum/hv_finisher/garrote/proc/clear_reach()
	for(var/datum/weakref/line_ref as anything in reach_refs)
		qdel(line_ref.resolve())
	reach_refs = null

/**
 * The garrote's thrown wire (wire_reach, half a tile of line running up a half pixel left of the middle) drawn from
 * the middle of the pixel at its base to the middle of the pixel (`span_x`, `span_y`) away and half a pixel on, so it
 * covers the pixel it lands on. `length` draws only that much of it along the same bearing. It starts half a pixel
 * before the middle of its base pixel too: a line that starts on the middle itself draws that pixel on some bearings
 * and not on others, and the wire would leave the hand a pixel out.
 */
/proc/wire_throw_shape(span_x, span_y, length)
	var/matrix/shape = matrix()
	shape.Translate(0.5, 0)
	shape.Scale(1, (max(isnull(length) ? wire_line_length(span_x, span_y) : length, 1) + WIRE_LINE_BACK) / 16)
	shape.Translate(0, -WIRE_LINE_BACK)
	shape.Turn(arctan(span_y, span_x))
	shape.Translate(0.5, 0.5)
	return shape

/// How long a line of wire from the middle of one pixel to the middle of another (`span_x`, `span_y`) away is drawn:
/// half a pixel more, to the far side of the pixel it ends on.
/proc/wire_line_length(span_x, span_y)
	return sqrt(span_x ** 2 + span_y ** 2) + 0.5

/**
 * The thrown wire's end put on the loop where the neck is drawn as it lands. It was aimed where the neck was drawn as
 * it left the hand, and anything that moves the body in flight leaves it short of the loop (recorded once, two pixels
 * short facing the viewer). Wound on, it is drawn as the hold's strand from its hand will be: from the far hand in
 * profile, round the back of the neck, under the body it flew over.
 */
/datum/hv_finisher/garrote/proc/land_reach()
	var/datum/weakref/line_ref = LAZYACCESS(reach_refs, 1)
	var/obj/effect/abstract/wire_reach/line = line_ref?.resolve()
	if(!line)
		return
	// The throw's beats end here anyway; ended now, it is drawn as they leave it (whole, lit) before it is moved.
	animate(line)
	line.transform = reach_to_neck(line, victim.transform)
	line.layer = strand_layer(line_origin(wire_side())[3])

/// The end of the throw: the wire winds round the neck and is held there, loose, for the rest of the wind-up (`rest`).
/datum/hv_finisher/garrote/proc/wind_loop(rest)
	if(!winding_up())
		return
	land_reach()
	show_loop("draw")
	// Wound on, it hangs loose until the hold pulls it tight. With no time left for that, the hold takes it from here.
	if(rest > WIRE_GARROTE_WIND_TIME)
		LAZYADD(windup_timers, addtimer(CALLBACK(src, PROC_REF(show_loop), "loop"), WIRE_GARROTE_WIND_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME))
	var/obj/effect/abstract/cyberware_anim/glint = cyberware_anim_play(user, WIRE_GORE_ICON, "wire_glint[wire_suffix()]", WIRE_FX_LAYER, 0.3 SECONDS, glow = TRUE)
	if(glint)
		// On the hand's pixel: the glint's picture is centred on the pixel down and right of its icon's middle.
		var/list/hand = hand_point(wire_side())
		glint.pixel_x = hand[1]
		glint.pixel_y = hand[2] + 1

/// The wire in flight. Nothing to click.
/obj/effect/abstract/wire_reach
	name = "wire"
	icon = WIRE_GORE_ICON
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	appearance_flags = PIXEL_SCALE | TILE_BOUND
	/// A taut strand's far end, on the neck, from its base in the hand: list(x, y) pixels. Null for any other line.
	var/list/span
	/// "left" or "right": the hand a taut strand runs from. Null for any other line.
	var/hand_side

/**
 * A taut strand on a neck that thrashes: its far end jolts by each of `jolts` (wire_jolts()) in turn, a beat apart,
 * as the body does, while its base stays in the hand. Linear, so the end runs straight to each spot, as the body does.
 */
/obj/effect/abstract/wire_reach/proc/jolt_end(list/jolts)
	if(!span)
		return
	var/first = TRUE
	for(var/list/jolt as anything in jolts)
		var/matrix/shape = wire_strand_shape(span[1] + jolt[1], span[2] + jolt[2])
		if(first)
			animate(src, transform = shape, time = WIRE_GARROTE_JOLT_TIME, flags = ANIMATION_LINEAR_TRANSFORM)
			first = FALSE
		else
			animate(transform = shape, time = WIRE_GARROTE_JOLT_TIME, flags = ANIMATION_LINEAR_TRANSFORM)

/// "" for the plain wire's colours, "_live" for the Arc's.
/datum/hv_finisher/garrote/proc/wire_suffix()
	return istype(wire, /obj/item/melee/cyberware_monowire/live) ? "_live" : ""

/**
 * A body lying beside the garroter is turned head first to them, as tg turns a body dragged sideways: the wire on its
 * neck drags it round. tg turns one lying the other way round in a single frame; this swings it round instead, through
 * head toward the viewer, and the thrown wire's end stays on the neck as it goes. Returns how long the turn takes, 0 if
 * it already lay that way.
 */
/datum/hv_finisher/garrote/proc/face_victim_in()
	if(QDELETED(victim) || victim.body_position != LYING_DOWN)
		return 0
	var/toward = get_dir(victim, user)
	var/new_angle
	if(toward & EAST)
		new_angle = LYING_ANGLE_EAST
	else if(toward & WEST)
		new_angle = LYING_ANGLE_WEST
	if(isnull(new_angle) || victim.lying_angle == new_angle)
		return 0
	var/end_for_end = REVERSE_ANGLE(new_angle) == victim.lying_angle
	var/matrix/before = matrix(victim.transform)
	victim.set_lying_angle(new_angle)
	var/matrix/after = matrix(victim.transform)
	var/datum/weakref/line_ref = LAZYACCESS(reach_refs, 1)
	var/obj/effect/abstract/wire_reach/line = line_ref?.resolve()
	if(!end_for_end)
		// tg's own turn.
		if(line)
			animate(line, transform = reach_to_neck(line, after), time = UPDATE_TRANSFORM_ANIMATION_TIME)
		return UPDATE_TRANSFORM_ANIMATION_TIME
	var/matrix/halfway = matrix(before)
	halfway.Turn(new_angle == LYING_ANGLE_WEST ? 90 : -90)
	victim.transform = before
	animate(victim, transform = halfway, time = WIRE_GARROTE_TURN_TIME / 2, easing = SINE_EASING | EASE_IN)
	animate(transform = after, time = WIRE_GARROTE_TURN_TIME / 2, easing = SINE_EASING | EASE_OUT)
	if(line)
		animate(line, transform = reach_to_neck(line, halfway), time = WIRE_GARROTE_TURN_TIME / 2, easing = SINE_EASING | EASE_IN)
		animate(transform = reach_to_neck(line, after), time = WIRE_GARROTE_TURN_TIME / 2, easing = SINE_EASING | EASE_OUT)
	return WIRE_GARROTE_TURN_TIME

/// The thrown wire `line` drawn from where it left the hand to the loop on the neck of the victim turned to `body_shape`.
/datum/hv_finisher/garrote/proc/reach_to_neck(obj/effect/abstract/wire_reach/line, matrix/body_shape)
	var/list/meet = loop_point(wire_side(), body_shape)
	return wire_throw_shape(meet[1] - (line.pixel_x + 0.5), meet[2] - (line.pixel_y + 0.5))

/**
 * Where the strand from the garroter's `side` hand meets the loop, as the loop is drawn now (or with the body turned
 * to `shape`): the middle of one of the near half's pixels, in pixels from the middle of the garroter's tile.
 * list(x, y)
 *
 * On a body lying down the loop shows as a short line up and down across the neck. In profile the near hand's strand
 * meets its lower end over the head, and the far hand's its upper end round the back of the neck, the head hiding it
 * (strand_layer()), so the two show as two strands. Facing the viewer both meet its top, the end toward the garroter;
 * facing away both meet it at the neck, since its lower end is hidden behind the garroter's head. On a body on its feet
 * (none is garroted: only for one getting up before the garrote lets go) the loop lies across the neck: facing toward or
 * away each strand meets the end on its own side, and in profile the near one the end toward the garroter, the far one
 * the middle.
 */
/datum/hv_finisher/garrote/proc/loop_point(side, matrix/shape)
	if(!shape)
		shape = victim.transform
	var/list/drawn = list()
	for(var/list/spot as anything in wire_loop_line(victim.dir))
		drawn += list(wire_pixel_drawn(shape, spot[1], spot[2]))
	var/list/first = drawn[1]
	var/list/middle = drawn[2]
	var/list/last = drawn[3]
	var/behind = hand_point(side)[3]
	var/list/meet
	if(abs(first[2] - last[2]) > abs(first[1] - last[1]))
		var/list/upper = first[2] > last[2] ? first : last
		var/list/lower = upper == first ? last : first
		switch(user.dir)
			if(NORTH)
				meet = middle
			if(SOUTH)
				meet = upper
			else
				meet = behind ? upper : lower
	else
		var/list/leftmost = first[1] < last[1] ? first : last
		var/list/rightmost = leftmost == first ? last : first
		if(user.dir & (EAST | WEST))
			meet = behind ? middle : ((user.dir & EAST) ? leftmost : rightmost)
		else
			meet = hand_point(side)[1] < 0 ? leftmost : rightmost
	return list(meet[1] + victim.pixel_x + (victim.x - user.x) * ICON_SIZE_X, meet[2] + victim.pixel_y + (victim.y - user.y) * ICON_SIZE_Y)

/**
 * The loop's near half as wire_gore.dmi draws it (garrote_tight_front): a line of wire one pixel high and seven long
 * across the neck, a pixel below where the jaw meets it, on the row the slit throat is drawn on. The middles of its
 * end pixels and of its middle one, in pixels from the middle of the icon, for the body facing `facing` (its picture
 * facing east is a pixel to the right). list(list(x, y) first, middle, last)
 */
/proc/wire_loop_line(facing)
	var/left = facing == EAST ? -2.5 : -3.5
	return list(list(left, 5.5), list(left + 3, 5.5), list(left + 6, 5.5))

/**
 * The middle of the pixel that a picture's pixel, its middle (`x`, `y`) from the middle of the icon, is drawn on once
 * `shape` turns and moves it, from the same middle. list(x, y)
 * Rounded down, not to the nearest: a quarter turn leaves the middle of a pixel on the middle of another, give or take
 * the rounding in the turn.
 */
/proc/wire_pixel_drawn(matrix/shape, x, y)
	return list(round(shape.a * x + shape.b * y + shape.c) + 0.5, round(shape.d * x + shape.e * y + shape.f) + 0.5)

/// Where the victim's neck is drawn, in pixels from the middle of its tile before its own offsets: 6 px above the
/// middle of an upright body, turned with a lying one (or as `shape`, a transform, would turn it). list(x, y)
/datum/hv_finisher/garrote/proc/neck_offset(matrix/shape)
	if(!shape)
		shape = victim.transform
	return list(round(shape.b * 6 + shape.c), round(shape.e * 6 + shape.f))

/**
 * Where the neck should be in the hold, in pixels from the middle of the garroter's tile. list(x, y)
 * - In profile the body stays on the floor: drawn in until its head lies just clear of the garroter's feet, never
 *   lifted, so the wire runs taut down from the hands to the neck.
 * - Facing away the neck is beyond the garroter, drawn just over their head, not hidden behind it.
 * - Facing the viewer the body is drawn up against the garroter's shins, the neck between their feet, under the
 *   hands held apart.
 */
/datum/hv_finisher/garrote/proc/hold_point()
	if(user.dir & (EAST | WEST))
		return list((user.dir & EAST ? 17 : -17) + user.pixel_x, neck_point()[2])
	if(user.dir & NORTH)
		return list(user.pixel_x, 16 + user.pixel_y)
	return list(user.pixel_x, -13 + user.pixel_y)

/// Where the neck is drawn now (or with the body turned to `shape`), in pixels from the middle of the garroter's tile.
/// list(x, y)
/datum/hv_finisher/garrote/proc/neck_point(matrix/shape)
	var/list/neck = neck_offset(shape)
	return list(neck[1] + victim.pixel_x + (victim.x - user.x) * ICON_SIZE_X, neck[2] + victim.pixel_y + (victim.y - user.y) * ICON_SIZE_Y)

/// Where the neck is drawn now, in pixels from the middle of the victim's own tile. list(x, y)
/datum/hv_finisher/garrote/proc/neck_on_tile()
	var/list/neck = neck_offset()
	return list(neck[1] + victim.pixel_x, neck[2] + victim.pixel_y)

/**
 * The hold draws the neck to hold_point(). The grab already pulls the body 12 px toward the garroter (and turns a
 * body dragged sideways head first); this corrects it from there, either way. Drawn only, and taken off with the
 * grab's pull at the kill (let_go_at_kill()).
 */
/datum/hv_finisher/garrote/proc/pull_close()
	if(QDELETED(user) || QDELETED(victim))
		return
	var/list/neck = neck_point()
	var/list/target = hold_point()
	victim.add_offsets(HV_FINISHER_OFFSET, x_add = clamp(target[1] - neck[1], -12, 12), y_add = clamp(target[2] - neck[2], -12, 12), animate = FALSE)
	slide_in()
	// Facing the viewer, the body is drawn up in front of the garroter's legs, not behind them.
	if(user.dir == SOUTH && victim.y < user.y && isnull(victim_old_layer))
		victim_old_layer = victim.layer
		victim.layer = WIRE_PULLED_LAYER

/**
 * The body slides in as one move, from where it was drawn before the grab (pull_from) to where the grab's pull and the
 * hold's drag put it, over the time the strands slide in with it (draw_wire()). tg slides the grab's pull (passive,
 * then aggressive) and the drag as separate moves on top of each other, and recorded, the body fell a pixel behind
 * the strands' ends on the neck for the first frames of the longest pull.
 */
/datum/hv_finisher/garrote/proc/slide_in()
	if(!pull_from)
		return
	var/to_x = victim.pixel_x
	var/to_y = victim.pixel_y
	if(to_x == pull_from[3] && to_y == pull_from[4])
		return
	// Ends tg's own slides, so they don't run on top of this one.
	animate(victim)
	// No floating bob meanwhile, as tg's own offset moves hold it off.
	ADD_TRAIT(victim, TRAIT_NO_FLOATING_ANIM, WIRE_SHAKE_TRAIT)
	addtimer(TRAIT_CALLBACK_REMOVE(victim, TRAIT_NO_FLOATING_ANIM, WIRE_SHAKE_TRAIT), UPDATE_TRANSFORM_ANIMATION_TIME, TIMER_UNIQUE | TIMER_OVERRIDE)
	victim.pixel_x = pull_from[3]
	victim.pixel_y = pull_from[4]
	animate(victim, pixel_x = to_x, pixel_y = to_y, time = UPDATE_TRANSFORM_ANIMATION_TIME)

/// The victim thrashes in the wire from `delay` on, for `duration`.
/datum/hv_finisher/garrote/proc/struggle(delay, duration)
	if(struggle_timer)
		deltimer(struggle_timer)
	struggle_timer = addtimer(CALLBACK(src, PROC_REF(thrash), duration), delay, TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * The victim thrashes in the wire for `duration`: the body jolts round wherever it is drawn now, and the ends of the
 * strands on its neck jolt with it, beat for beat, so the wire stays on the neck. The hands' ends stay put.
 */
/datum/hv_finisher/garrote/proc/thrash(duration)
	struggle_timer = null
	if(QDELETED(victim) || !running)
		return
	var/list/jolts = wire_jolts(2, 1, duration)
	wire_shake(victim, jolts = jolts)
	for(var/datum/weakref/strand_ref as anything in strand_refs)
		var/obj/effect/abstract/wire_reach/strand = strand_ref.resolve()
		strand?.jolt_end(jolts)

/// A shake's beats, one each WIRE_GARROTE_JOLT_TIME for `duration`: list(x, y) offsets of up to `shift_x` and `shift_y`
/// pixels from where the shaken thing is drawn, the last one back where it was.
/proc/wire_jolts(shift_x, shift_y, duration)
	. = list()
	for(var/i in 1 to max(round(duration / WIRE_GARROTE_JOLT_TIME) - 1, 2))
		. += list(list(rand(-shift_x, shift_x), rand(-shift_y, shift_y)))
	. += list(list(0, 0))

/**
 * tg's Shake() without its slip (its first beat sets pixel_y from pixel_x, a jump on a body drawn off its tile's
 * middle): jitters `body` up to `shift_x` and `shift_y` pixels round where it is drawn now, then puts it back there.
 * `jolts` (wire_jolts()) are the beats to use, for something else drawn on the body to follow them.
 *
 * Its own animation, not one run in parallel as tg's is: recorded on a lying body, a parallel shake (absolute or
 * relative steps alike) showed each jolt at about twice its size, so nothing following the jolts could keep with it.
 * Being its own animation it would stop a floating body's bob, so the bob is held off until the shake is over.
 */
/proc/wire_shake(atom/movable/body, shift_x, shift_y, duration, list/jolts)
	if(QDELETED(body))
		return
	if(!length(jolts))
		jolts = wire_jolts(shift_x, shift_y, duration)
	ADD_TRAIT(body, TRAIT_NO_FLOATING_ANIM, WIRE_SHAKE_TRAIT)
	addtimer(TRAIT_CALLBACK_REMOVE(body, TRAIT_NO_FLOATING_ANIM, WIRE_SHAKE_TRAIT), length(jolts) * WIRE_GARROTE_JOLT_TIME, TIMER_UNIQUE | TIMER_OVERRIDE)
	var/start_x = body.pixel_x
	var/start_y = body.pixel_y
	var/first = TRUE
	for(var/list/jolt as anything in jolts)
		if(first)
			animate(body, pixel_x = start_x + jolt[1], pixel_y = start_y + jolt[2], time = WIRE_GARROTE_JOLT_TIME)
			first = FALSE
		else
			animate(pixel_x = start_x + jolt[1], pixel_y = start_y + jolt[2], time = WIRE_GARROTE_JOLT_TIME)

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
	// One of the body's own overlays, so the neck and head drawn over it hide it.
	loop_back = mutable_appearance(WIRE_GORE_ICON, "garrote_[kind]_back[wire_suffix()]", -(TOTAL_LAYERS + 0.5))
	victim.add_overlay(loop_back)
	// Over the garroter's legs, which the body lies against; facing away, over the neck but under the garroter.
	var/near_layer = user.dir == NORTH ? WIRE_BETWEEN_LAYER : ABOVE_MOB_LAYER
	var/obj/effect/abstract/cyberware_anim/near_side = cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_[kind]_front[wire_suffix()]", near_layer, lifetime, glow = TRUE)
	loop_refs = list(WEAKREF(near_side))

/datum/hv_finisher/garrote/proc/clear_loop()
	for(var/datum/weakref/loop_ref as anything in loop_refs)
		qdel(loop_ref.resolve())
	loop_refs = null
	if(loop_back)
		victim?.cut_overlay(loop_back)
		loop_back = null

/// Where the garroter and the victim are drawn now: list(garroter pixel_x, pixel_y, victim pixel_x, pixel_y)
/datum/hv_finisher/garrote/proc/drawn_offsets()
	return list(user.pixel_x, user.pixel_y, victim.pixel_x, victim.pixel_y)

/**
 * The wire from the garroter's hands to the neck, one strand a hand, in the wire's own colour: one line of wire
 * each, stretched from the hand to the neck. A strand from a hand behind the garroter's body (the far hand in profile,
 * both facing away) is drawn under the garroter, so the torso hides it (strand_layer()). Whatever wire was drawn before (the
 * slack throw, or the strands before a lean) goes as these go up.
 *
 * `slide_from` (drawn_offsets(), or null) is where the two were drawn before a move that is sliding them into place
 * now, over tg's offset time: the strands start from there and slide with them, so they stay on the hands and the
 * neck all the way.
 */
/datum/hv_finisher/garrote/proc/draw_wire(duration, list/slide_from)
	clear_reach()
	clear_strands()
	var/turf/from = get_turf(user)
	if(!from || QDELETED(user) || QDELETED(victim))
		return
	// Never a strand from a hand that still draws a wire hanging in it.
	hide_hands()
	var/list/start = slide_from || drawn_offsets()
	for(var/side in list("left", "right"))
		var/list/hand = line_origin(side)
		var/hand_x = user.pixel_x + hand[1]
		var/hand_y = user.pixel_y + hand[2]
		// From the middle of the hand's pixel to the middle of the loop's, where the loop is drawn: whole pixels.
		var/list/meet = loop_point(side)
		var/span_x = meet[1] - (hand_x + 0.5)
		var/span_y = meet[2] - (hand_y + 0.5)
		var/start_hand_x = hand_x + start[1] - user.pixel_x
		var/start_hand_y = hand_y + start[2] - user.pixel_y
		var/start_span_x = span_x + (start[3] - victim.pixel_x) - (start[1] - user.pixel_x)
		var/start_span_y = span_y + (start[4] - victim.pixel_y) - (start[2] - user.pixel_y)
		var/obj/effect/abstract/wire_reach/strand = new_line(hand[3])
		strand.icon_state = "wire_taut[wire_suffix()]"
		strand.layer = strand_layer(hand[3])
		strand.add_overlay(emissive_appearance(strand.icon, strand.icon_state, strand))
		strand.pixel_x = start_hand_x
		strand.pixel_y = start_hand_y
		strand.span = list(span_x, span_y)
		strand.hand_side = side
		strand.transform = wire_strand_shape(start_span_x, start_span_y)
		if(start_hand_x != hand_x || start_hand_y != hand_y || start_span_x != span_x || start_span_y != span_y)
			// Linear, as the body's slide in is (slide_in()), so the far end keeps step with the neck all the way. In beats:
			// each beat ends on the strand's true shape for where its two ends are by then, and the matrix is blended
			// straight from one beat's shape to the next. Blended in one go from the first shape to the last, a strand that
			// turns far on the way (40 degrees, facing the viewer) is drawn thinner than a pixel in between, and recorded
			// it showed a pixel missing for the first frames of the pull.
			var/beat_time = UPDATE_TRANSFORM_ANIMATION_TIME / WIRE_GARROTE_SLIDE_BEATS
			for(var/beat in 1 to WIRE_GARROTE_SLIDE_BEATS)
				var/done = beat / WIRE_GARROTE_SLIDE_BEATS
				var/beat_x = start_hand_x + (hand_x - start_hand_x) * done
				var/beat_y = start_hand_y + (hand_y - start_hand_y) * done
				var/matrix/shape = wire_strand_shape(start_span_x + (span_x - start_span_x) * done, start_span_y + (span_y - start_span_y) * done)
				if(beat == 1)
					animate(strand, pixel_x = beat_x, pixel_y = beat_y, transform = shape, time = beat_time, flags = ANIMATION_LINEAR_TRANSFORM)
				else
					animate(pixel_x = beat_x, pixel_y = beat_y, transform = shape, time = beat_time, flags = ANIMATION_LINEAR_TRANSFORM)
		LAZYADD(strand_refs, WEAKREF(strand))
		QDEL_IN(strand, duration)

/**
 * A taut strand of wire from the middle of the pixel at its base to the middle of the pixel (`span_x`, `span_y`) away,
 * and half a pixel past each, so it covers the pixel it starts on and the pixel it ends on whatever its bearing (a line
 * that starts on the middle of a pixel draws that pixel on some bearings and not on others: recorded, the strand's end
 * in the hand blinked a pixel off the hand as its other end thrashed with the neck). The sprite is a tile-long line
 * running up a half pixel left of the middle: it is moved onto the middle and up to start there, stretched, moved back
 * half a pixel and turned, then moved to the middle of the base pixel. The base pixel stays covered under any blend of
 * two of these, so a strand tweened between two keeps its base in the hand and runs its far end straight from one spot
 * to the other.
 */
/proc/wire_strand_shape(span_x, span_y)
	var/matrix/shape = matrix()
	shape.Translate(0.5, ICON_SIZE_Y / 2)
	shape.Scale(1, (wire_line_length(span_x, span_y) + WIRE_LINE_BACK) / ICON_SIZE_Y)
	shape.Translate(0, -WIRE_LINE_BACK)
	shape.Turn(arctan(span_y, span_x))
	shape.Translate(0.5, 0.5)
	return shape

/**
 * The garroter has just been leaned somewhere else (the kill's lean), sliding there over tg's offset time: each strand's
 * end in the hand slides with the hand, and its end on the neck stays put. The strands already up are moved, not drawn
 * again: a picture a client already has moves in step with the body, a new one starts a frame behind it. Returns FALSE
 * if there are none to move.
 */
/datum/hv_finisher/garrote/proc/lean_wire()
	if(QDELETED(user) || QDELETED(victim))
		return FALSE
	var/moved = FALSE
	for(var/datum/weakref/strand_ref as anything in strand_refs)
		var/obj/effect/abstract/wire_reach/strand = strand_ref.resolve()
		if(QDELETED(strand) || !strand.hand_side)
			continue
		var/list/hand = line_origin(strand.hand_side)
		var/hand_x = user.pixel_x + hand[1]
		var/hand_y = user.pixel_y + hand[2]
		var/list/meet = loop_point(strand.hand_side)
		strand.span = list(meet[1] - (hand_x + 0.5), meet[2] - (hand_y + 0.5))
		animate(strand, pixel_x = hand_x, pixel_y = hand_y, transform = wire_strand_shape(strand.span[1], strand.span[2]), time = UPDATE_TRANSFORM_ANIMATION_TIME, flags = ANIMATION_LINEAR_TRANSFORM)
		moved = TRUE
	return moved

/datum/hv_finisher/garrote/proc/clear_strands()
	for(var/datum/weakref/strand_ref as anything in strand_refs)
		qdel(strand_ref.resolve())
	strand_refs = null

/datum/hv_finisher/garrote/proc/clear_wire_fx()
	for(var/timer in windup_timers)
		deltimer(timer)
	windup_timers = null
	if(struggle_timer)
		deltimer(struggle_timer)
		struggle_timer = null
	clear_reach()
	clear_loop()
	clear_strands()
	show_hands()

/**
 * The kill: the head off in hard crit, else the throat slit, else (turned by a helmet, collar or plating) an
 * ordinary blow with the wire. Lines go out while the head is still on, since they name it.
 */
/datum/hv_finisher/garrote/proc/kill(spray_dir)
	var/obj/item/bodypart/head/head = victim.get_bodypart(BODY_ZONE_HEAD)
	if(!head)
		return
	var/seared = wire.wire_sears(victim)
	// Where the body is drawn while the wire goes through, for where the head comes off and the blood bursts from.
	var/list/body_offsets = list(victim.pixel_x, victim.pixel_y, victim.pixel_w, victim.pixel_z)
	var/list/cut_neck = neck_on_tile()
	var/head_side = (get_dir(victim, user) & (EAST | NORTH)) ? 1 : -1
	var/facing = user.dir
	clear_wire_fx()
	// The garroter lets go as the wire goes through, and the body drops back once, here. The pool and the smoke go
	// where it comes to rest, once it is there.
	var/settle_time = let_go_at_kill()
	var/list/rest_neck = neck_on_tile()
	// Facing away, the snap is between the two bodies, not over the garroter's head.
	cyberware_anim_play(victim, WIRE_GORE_ICON, "garrote_snap[wire_suffix()]", facing == NORTH ? WIRE_BETWEEN_LAYER : ABOVE_MOB_LAYER, 0.6 SECONDS, glow = TRUE)
	if(victim.stat >= HARD_CRIT && head.can_dismember())
		victim.hv_add_hit_line("[user] draws the wire through [victim]'s neck!", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
		if(seared)
			LAZYSET(victim.hv_stump_burnt, BODY_ZONE_HEAD, TRUE)
		// What tg pulls off a head as it comes off: laid by the dropped head, not stood up on the body.
		var/list/worn = list()
		for(var/obj/item/thing in list(victim.glasses, victim.ears, victim.wear_mask, victim.head))
			worn += thing
		// Dropped, brain and all, as #509's finishers drop a head: where the neck was, at the garroter's feet. None of
		// tg's own blood on the floor (a seared neck doesn't bleed there at all); the garrote lays its own.
		if(hv_wire_take_part(head, seared ? WOUND_BURN : WOUND_SLASH, 0, FALSE))
			// The animation pass twitches a fresh corpse a few times, starting at once. Not while the body is still
			// slumping back onto its tile: its twitches begin once it lies still.
			if(victim.stat == DEAD)
				victim.hv_vis_twitches(2, settle_time + WIRE_GARROTE_TWITCH_WAIT)
			wire_neck_blood_loss(victim, seared)
			wire_drop_head(head, victim, body_offsets, head_side, facing, worn, list(rest_neck[1] - cut_neck[1], rest_neck[2] - cut_neck[2]))
			// Facing away, the head lies against the stump, below the body's line, with the garroter just beyond it: a pool
			// centred on the neck would show only above the shoulders. It goes a little lower, and shows round the head.
			var/list/pool_at = facing == NORTH ? list(rest_neck[1], rest_neck[2] - WIRE_GARROTE_POOL_DROP_NORTH) : rest_neck
			finish_blood(spray_dir, seared, cut_neck, rest_neck, settle_time, pool_at)
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
			finish_blood(spray_dir, seared, cut_neck, rest_neck, settle_time)
			log_combat(user, victim, "garroted the throat of", wire)
			return
	if(blocker)
		victim.hv_add_hit_line("The wire catches on [victim]'s [blocker]!", HV_LINE_BOLD, "The wire catches on your [blocker]!")
	real_blow(BODY_ZONE_HEAD, kill_wound_bonus)

/// The blood a head coming off loses, as tg's dismemberment bleeds it, without the floor splatter tg's bleed() lays
/// (the garrote lays its own blood). A seared neck loses a little.
/proc/wire_neck_blood_loss(mob/living/carbon/body, seared)
	if(QDELETED(body) || HAS_TRAIT(body, TRAIT_GODMODE) || !body.can_bleed())
		return
	body.blood_volume = max(body.blood_volume - round(rand(40, 80) * (seared ? WIRE_ARC_BLEED_MULT : 1)), 0)

/**
 * The head comes off the end of the neck where the wire cut it, a few pixels clear of it, and drops to the floor at
 * the garroter's feet: it doesn't follow the body as that falls back (`settle`, the body's move after the cut), except
 * facing away, where the garroter's feet are the wrong side of them and it would lie against their own head. Turned
 * as the body lay; an ordinary head again once moved. What the head wore (`worn`, already on the floor) lies beside
 * it. `facing` is the garroter's.
 */
/proc/wire_drop_head(obj/item/bodypart/head/head, mob/living/body, list/body_offsets, side, facing, list/worn, list/settle)
	if(QDELETED(head) || !isturf(head.loc))
		return
	// On the body its middle is 9 px up; it lies 4 px further out, off the end of the neck. Its picture is
	// shifted by (px_x, px_y) to sit mid-tile, after its transform.
	head.transform = wire_part_pose(list(0, 9), side * 10, list(side * 2, 13), body, head.px_x, head.px_y)
	head.pixel_x = body_offsets[1]
	head.pixel_y = body_offsets[2]
	head.pixel_w = body_offsets[3]
	head.pixel_z = body_offsets[4]
	// Down to the floor: furthest facing the viewer, where the hold drew the body up off it.
	var/shift_x = 0
	var/fall = facing == SOUTH ? 8 : 5
	if(facing == NORTH)
		shift_x = LAZYACCESS(settle, 1) || 0
		fall = 2 - (LAZYACCESS(settle, 2) || 0)
	animate(head, pixel_x = head.pixel_x + shift_x, pixel_y = head.pixel_y - fall, time = WIRE_GARROTE_HEAD_FALL_TIME, easing = QUAD_EASING | EASE_IN)
	head.RegisterSignal(head, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item/bodypart, wire_stand_up), override = TRUE)
	if(!length(worn))
		return
	// Where its middle lands, and which way along the floor the head points from the neck.
	var/matrix/shape = body.transform
	var/head_x = shape.a * side * 2 + shape.b * 13 + shape.c + body_offsets[1] + shift_x
	var/head_y = shape.d * side * 2 + shape.e * 13 + shape.f + body_offsets[2] - fall
	var/away_x = shape.b > 0.5 ? 1 : (shape.b < -0.5 ? -1 : 0)
	var/laid = 0
	for(var/obj/item/thing as anything in worn)
		if(QDELETED(thing) || thing.loc != head.loc)
			continue
		wire_lay_by_head(thing, round(head_x - away_x * (7 + laid * 5)), round(head_y - 3), away_x)
		laid++

/**
 * Something that came off with the head lies on the floor at (`spot_x`, `spot_y`) on its tile, on its side and a little
 * smaller than tg's dropped-item picture, unseen until the head has landed. Drawn as any item again once moved.
 */
/proc/wire_lay_by_head(obj/item/thing, spot_x, spot_y, away_x)
	var/matrix/lying = matrix()
	lying.Scale(0.7)
	lying.Turn(away_x < 0 ? -90 : 90)
	thing.transform = lying
	thing.pixel_x = spot_x
	thing.pixel_y = spot_y
	thing.alpha = 0
	animate(thing, alpha = 0, time = WIRE_GARROTE_HEAD_FALL_TIME)
	animate(alpha = 255, time = 0.1 SECONDS)
	thing.RegisterSignal(thing, COMSIG_MOVABLE_MOVED, TYPE_PROC_REF(/obj/item, wire_garrote_pick_up), override = TRUE)

/// An item wire_lay_by_head() laid out, once moved: drawn as any item.
/obj/item/proc/wire_garrote_pick_up()
	SIGNAL_HANDLER
	UnregisterSignal(src, COMSIG_MOVABLE_MOVED)
	animate(src, alpha = 255, time = 0)
	transform = matrix()
	pixel_x = base_pixel_x
	pixel_y = base_pixel_y

/**
 * The open neck empties. Blood bursts out all round where the wire cut it (`cut_neck`, from the middle of the victim's
 * tile) and lands in a rough ring of drops and splats over the floor about the neck, the garroter included; it wets
 * the garroter's hands, then their clothes and feet as the drops come down; and once the body has come to rest
 * (`settle_time` on), a pool spreads under the neck there (`rest_neck`, or `pool_at`) over the next couple of seconds.
 * A seared one only smokes, from there.
 */
/datum/hv_finisher/garrote/proc/finish_blood(spray_dir, seared, list/cut_neck, list/rest_neck, settle_time = 0, list/pool_at)
	if(QDELETED(victim))
		return
	if(seared)
		if(settle_time)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_neck_smoke), victim, rest_neck), settle_time)
		else
			wire_neck_smoke(victim, rest_neck)
		playsound(victim, 'sound/effects/wounds/sizzle1.ogg', 60, TRUE)
		return
	var/turf/neck_turf = get_turf(victim)
	if(!neck_turf || victim.can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	var/list/blood_dna = victim.get_blood_dna_list()
	var/list/viruses = victim.get_static_viruses()
	if(!pool_at)
		pool_at = rest_neck
	if(settle_time)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_pool_under), neck_turf, pool_at[1], pool_at[2], blood_dna, viruses), settle_time)
	else
		wire_pool_under(neck_turf, pool_at[1], pool_at[2], blood_dna, viruses)
	wire_blood_burst(neck_turf, cut_neck[1], cut_neck[2], wire_blood_color(victim), blood_dna)
	if(QDELETED(user))
		return
	// The hands are at the neck: wet at once. The clothes and feet as the drops come down on them.
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_garrote_soak), user, neck_turf, blood_dna, viruses, 1), 0.15 SECONDS)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_garrote_soak), user, neck_turf, blood_dna, viruses, 2), 0.45 SECONDS)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_garrote_soak), user, neck_turf, blood_dna, viruses, 3), 0.8 SECONDS)

/// One beat of the garroter getting the neck's blood on them: 1 the hands, 2 the front of the clothes and a few
/// splats round their feet, 3 the rest of them and their shoes.
/proc/wire_garrote_soak(mob/living/soaked, turf/neck_turf, list/blood_dna, list/viruses, beat)
	if(QDELETED(soaked))
		return
	var/mob/living/carbon/human/dressed = ishuman(soaked) ? soaked : null
	switch(beat)
		if(1)
			if(dressed)
				dressed.add_blood_DNA_to_items(blood_dna, ITEM_SLOT_GLOVES | ITEM_SLOT_HANDS, viruses)
			else
				soaked.add_blood_DNA(blood_dna, viruses)
		if(2)
			dressed?.add_blood_DNA_to_items(blood_dna, ITEM_SLOT_ICLOTHING | ITEM_SLOT_OCLOTHING, viruses)
			var/turf/feet = get_turf(soaked)
			if(feet && feet != neck_turf && !isgroundlessturf(feet))
				for(var/i in 1 to 2)
					var/obj/effect/decal/cleanable/blood/drip/wire_flick/drop = new(feet, null, blood_dna)
					if(!QDELETED(drop))
						drop.pixel_x = rand(-9, 9)
						drop.pixel_y = rand(-12, 0)
		if(3)
			soaked.hv_blood_drench(blood_dna, viruses)
			dressed?.add_blood_DNA_to_items(blood_dna, ITEM_SLOT_FEET, viruses)

/// A seared neck smokes a little: thin wisps rising off the stump where the body lies, not turned with the body.
/obj/effect/abstract/wire_neck_smoke
	name = "smoke"
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	// Over the body on the floor, under anyone standing.
	layer = WIRE_BETWEEN_LAYER

/obj/effect/abstract/wire_neck_smoke/proc/stop_smoking()
	particles?.spawning = 0

/particles/smoke/steam/mild/wire_neck
	color = "#a29c98"
	scale = 0.4
	grow = 0.02
	spawning = 0.6
	lifespan = 1.2 SECONDS
	fade = 0.8 SECONDS
	position = list(0, 0, 0)
	velocity = list(0, 0.5, 0)
	gravity = list(0, 0.5)
	friction = 0.15
	drift = generator(GEN_SPHERE, 0, 0.5, NORMAL_RAND)

/// Smoke off a seared neck at (`neck[1]`, `neck[2]`) from the middle of `body`'s tile, for a second, gone soon after.
/proc/wire_neck_smoke(mob/living/body, list/neck)
	var/turf/spot = get_turf(body)
	if(!spot)
		return
	var/obj/effect/abstract/wire_neck_smoke/smoke = new(spot)
	smoke.pixel_x = neck[1]
	smoke.pixel_y = neck[2]
	smoke.particles = new /particles/smoke/steam/mild/wire_neck
	addtimer(CALLBACK(smoke, TYPE_PROC_REF(/obj/effect/abstract/wire_neck_smoke, stop_smoking)), 1.2 SECONDS)
	QDEL_IN(smoke, 2.4 SECONDS)

/**
 * The pool under the neck: tg's blood decal for the tile, filled to a pool size that keeps to the tile
 * (blood/blood_pools.dm). A fresh one is centred on the neck and spreads out from a spot under it over
 * WIRE_GARROTE_POOL_TIME; a pool already on the tile stays put and steps up through the sizes as it fills.
 */
/proc/wire_pool_under(turf/neck_turf, neck_x, neck_y, list/blood_dna, list/viruses)
	if(isgroundlessturf(neck_turf))
		return
	var/obj/effect/decal/cleanable/blood/pool
	for(var/obj/effect/decal/cleanable/blood/found in neck_turf)
		if(found.type == /obj/effect/decal/cleanable/blood && !found.dried && !QDELETED(found))
			pool = found
			break
	if(pool)
		pool.add_blood_DNA(blood_dna)
		pool.hv_pool_lobe_tried |= (NORTH | SOUTH | EAST | WEST)
		for(var/step in 0 to 3)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wire_pool_fill), pool), step * 0.45 SECONDS)
		return
	pool = new /obj/effect/decal/cleanable/blood(neck_turf, viruses, blood_dna)
	if(QDELETED(pool))
		return
	pool.base_pixel_x = clamp(neck_x, -8, 8)
	pool.base_pixel_y = clamp(neck_y, -12, 8)
	pool.pixel_x = pool.base_pixel_x
	pool.pixel_y = pool.base_pixel_y
	// It keeps to the neck's tile: it never runs onto the tiles beside it, however much the body bleeds into it.
	pool.hv_pool_lobe_tried |= (NORTH | SOUTH | EAST | WEST)
	// Its whole size at once, so the picture doesn't change as it spreads; the spreading is drawn.
	pool.adjust_bloodiness(WIRE_GARROTE_POOL_CAP - pool.bloodiness)
	var/matrix/spot = matrix()
	spot.Scale(0.15)
	pool.transform = spot
	// Parallel: tg's drying runs on the decal's own animation.
	animate(pool, transform = matrix(), time = WIRE_GARROTE_POOL_TIME, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_PARALLEL)

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
	// Leans in to throw the wire.
	lunge = 3
	enter_range = COMBAT_MESSAGE_RANGE

// The gore pass rears every finisher's attacker up for its wind-up, bigger and tipped back away from the victim
// (visuals/finisher_motion.dm): a beast looming over its kill. A garroter leans in to throw the wire, and the wire
// leaves the hand where the hand is drawn, so that picture is taken straight back off, before any client sees it.
/datum/hv_finisher_stage/windup/garrote/enter()
	. = ..()
	if(host && !QDELETED(host.user))
		host.user.hv_vis_stop(list(HV_VIS_TAG_REAR))

/datum/hv_finisher_stage/windup/garrote/enter_message()
	return "[host.user] loops the wire around [host.victim]'s neck."

/datum/hv_finisher_stage/windup/garrote/enter_self_message()
	return "A wire loops around your neck!"

/datum/hv_finisher_stage/hold/garrote
	duration = 1.5 SECONDS
	// Stays leaned in over the body, into the pull.
	lunge = 3
	enter_sound = 'voidcrew/sound/monowire2.ogg'
	enter_volume = 50
	enter_range = COMBAT_MESSAGE_RANGE

/datum/hv_finisher_stage/hold/garrote/enter()
	. = ..()
	var/datum/hv_finisher/garrote/garrote = host
	garrote.pull_close()
	garrote.show_loop("tight")
	// Taut until the kill beat cuts it (kill() takes them down; the time is only the garrote's own backstop), sliding in
	// with the bodies from where they were before the grab.
	garrote.draw_wire(garrote.longest_duration(), garrote.pull_from)
	// Drawn in to the hands first, then the thrashing.
	garrote.struggle(UPDATE_TRANSFORM_ANIMATION_TIME, duration - UPDATE_TRANSFORM_ANIMATION_TIME)

/datum/hv_finisher_stage/hold/garrote/enter_message()
	return "[host.user] pulls the wire tight!"

/datum/hv_finisher_stage/hold/garrote/enter_self_message()
	return "The wire bites into your neck!"

/datum/hv_finisher_stage/kill/garrote
	duration = 1 SECONDS
	effect_delay = 0.5 SECONDS
	// Leans further in as the wire goes through.
	lunge = 5

/datum/hv_finisher_stage/kill/garrote/enter()
	var/datum/hv_finisher/garrote/garrote = host
	var/list/before_lean = garrote.drawn_offsets()
	. = ..()
	// The strands stay on the hands as the lean takes them forward: the hold's own strands, which last until the cut.
	if(garrote.running && !garrote.lean_wire())
		garrote.draw_wire(effect_delay + 0.1 SECONDS, before_lean)

/datum/hv_finisher_stage/kill/garrote/effect()
	var/datum/hv_finisher/garrote/garrote = host
	garrote.kill(away_dir())

#undef WIRE_GARROTE_INTERRUPT
#undef WIRE_GARROTE_REACH_TIME
#undef WIRE_GARROTE_LEAN_TIME
#undef WIRE_GARROTE_WIND_TIME
#undef WIRE_GARROTE_THROW_BEATS
#undef WIRE_GARROTE_SLIDE_BEATS
#undef WIRE_GARROTE_TURN_TIME
#undef WIRE_GARROTE_POOL_TIME
#undef WIRE_GARROTE_HEAD_FALL_TIME
#undef WIRE_GARROTE_POOL_DROP_NORTH
#undef WIRE_GARROTE_JOLT_TIME
#undef WIRE_GARROTE_TWITCH_WAIT
#undef WIRE_LINE_BACK
#undef WIRE_SHAKE_TRAIT
