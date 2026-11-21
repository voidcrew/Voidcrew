/**
 * # Hostages (stealth step 5, decisions 47+)
 *
 * Holding one of the guards' own people at gunpoint: tg's neck grab (they are on your tile, held in front of you)
 * with a gun in hand. Anyone can do it, and the hold is drawn as such (stealth_hostage_pose.dm). Everything stays
 * tg's: the grab, the hostage's own struggling (tg's resist, through escape_captivity), and a shot into them is a
 * real shot.
 *
 * A stealth guard alert on whoever holds a friend of his (same faction) goes into a standoff instead of fighting:
 * - he holds fire and keeps his distance (never closer than STEALTH_HOSTAGE_HOLD_RANGE), facing the holder, and
 *   talks ("Let him go!");
 * - told to drop it, he drops what he holds, once; told to back off, he backs off to STEALTH_HOSTAGE_BACK_OFF_RANGE,
 *   once. Plain words the holder says out loud within STEALTH_HOSTAGE_DEMAND_RANGE;
 * - the hostage let go alive, or slipping free: the fight picks up where it was;
 * - the holder hurting or killing the hostage (a shot, a blow, a strangle, a slam, setting him alight), or the
 *   hostage dying in his hands, or the holder attacking the guard himself or one of his people he can see: no more
 *   deals with that holder, ever, for that guard. He fights.
 * - anyone else attacking the guard or one of his people he can see: he turns on them.
 * - out of sight of the holder, he chases as usual and stands off again when he sees them.
 *
 * Only for their own people. Someone they don't count as one of theirs (a player, a stranger) held up in front is
 * no reason to hold fire: they shoot. Never a fake state on anyone: the hostage is only held, and the guards only
 * choose not to shoot.
 */

/// Stealth AIs in a standoff now, so an attack by a holder reaches every guard standing off against him.
GLOBAL_LIST_EMPTY(stealth_standoffs)

/datum/ai_controller/basic_controller/human_npc/stealth
	/// The holder it is standing off against, and the friend they hold.
	var/datum/weakref/standoff_holder
	var/datum/weakref/standoff_hostage
	/// What it already gave in to this standoff.
	var/standoff_dropped = FALSE
	var/standoff_backed_off = FALSE
	/// world.time of its next standoff line.
	var/next_standoff_bark = 0
	/// REFs of holders who hurt or killed a hostage in front of it: it never stands off against them again.
	var/list/no_deals

/datum/ai_controller/basic_controller/human_npc/stealth/init_subtrees()
	if(LAZYLEN(planning_subtrees) && !(/datum/ai_planning_subtree/stealth_hostage in planning_subtrees))
		var/list/subtrees = planning_subtrees.Copy()
		var/at = subtrees.Find(/datum/ai_planning_subtree/human_npc_arm)
		if(at)
			subtrees.Insert(at, /datum/ai_planning_subtree/stealth_hostage)
		planning_subtrees = subtrees
	return ..()

/// The body `holder` holds at gunpoint now: a neck grab or tighter on a living body on their tile, a gun in a hand.
/// `at` asks about the body on another tile instead (the one he has just stepped off).
/proc/stealth_hostage_of(mob/living/holder, atom/at)
	if(!isliving(holder) || holder.stat != CONSCIOUS)
		return null
	var/mob/living/held = holder.pulling
	if(!isliving(held) || held.stat == DEAD || holder.grab_state < GRAB_NECK || held.loc != (at || holder.loc))
		return null
	if(!isgun(holder.get_active_held_item()) && !isgun(holder.get_inactive_held_item()))
		return null
	return held

/// Whether it stands off against `holder` holding `hostage`: one of its own, and a holder it still deals with.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_with(mob/living/holder, mob/living/hostage)
	var/mob/living/guard = pawn
	if(isnull(hostage) || hostage == guard || LAZYFIND(no_deals, REF(holder)))
		return FALSE
	return guard.faction_check_atom(hostage)

/// Starts (or keeps) the standoff against `holder` holding `hostage`.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_start(mob/living/holder, mob/living/hostage)
	var/mob/living/old_holder = standoff_holder?.resolve()
	var/mob/living/old_hostage = standoff_hostage?.resolve()
	if(old_holder == holder && old_hostage == hostage)
		return
	stealth_standoff_end()
	standoff_holder = WEAKREF(holder)
	standoff_hostage = WEAKREF(hostage)
	standoff_dropped = FALSE
	standoff_backed_off = FALSE
	next_standoff_bark = 0
	stealth_drop_walk()
	RegisterSignal(holder, COMSIG_MOB_SAY, PROC_REF(on_standoff_demand))
	RegisterSignal(holder, COMSIG_MOVABLE_SET_GRAB_STATE, PROC_REF(on_holder_grab_state))
	RegisterSignal(hostage, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_hostage_hurt))
	RegisterSignal(hostage, COMSIG_LIVING_IGNITED, PROC_REF(on_hostage_ignited))
	GLOB.stealth_standoffs |= src
	RegisterSignal(hostage, COMSIG_LIVING_DEATH, PROC_REF(on_hostage_died))
	var/mob/living/guard = pawn
	log_combat(guard, holder, "held fire on a hostage holder", null, "(hostage [key_name(hostage)], [get_area_name(guard, TRUE)])")

/// Ends the standoff, if any. `line` is the bark it says as it does.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_end(line)
	var/mob/living/holder = standoff_holder?.resolve()
	var/mob/living/hostage = standoff_hostage?.resolve()
	GLOB.stealth_standoffs -= src
	if(holder)
		UnregisterSignal(holder, list(COMSIG_MOB_SAY, COMSIG_MOVABLE_SET_GRAB_STATE))
	if(hostage)
		UnregisterSignal(hostage, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_IGNITED, COMSIG_LIVING_DEATH))
	var/was_on = !isnull(standoff_holder)
	standoff_holder = null
	standoff_hostage = null
	if(was_on)
		stealth_drop_walk()
		if(line)
			stealth_bark(line, always = TRUE)

/// The holder hurt or killed the hostage, or attacked one of them: no more deals with them. `why` goes in the log.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_broken(mob/living/holder, why = "the hostage was hurt")
	if(holder)
		LAZYOR(no_deals, REF(holder))
		var/mob/living/guard = pawn
		log_combat(guard, holder, "stopped holding fire: [why]", null, "([get_area_name(guard, TRUE)])")
	stealth_set_wary()
	stealth_standoff_end(STEALTH_BARK_HOSTAGE_EXECUTED)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_hostage_hurt(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	if(damage_dealt <= 0)
		return
	var/mob/living/holder = standoff_holder?.resolve()
	if(isnull(holder))
		return
	// A blow with no hand or item behind it (slammed on a table) while he holds him: his doing.
	if(hv_vis_attacker_of(attacking_item) == holder || (isnull(attacking_item) && damagetype == BRUTE && source.pulledby == holder))
		stealth_standoff_broken(holder)

/// The hostage catches fire in the holder's hands.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_hostage_ignited(mob/living/source)
	SIGNAL_HANDLER
	var/mob/living/holder = standoff_holder?.resolve()
	if(holder && source.pulledby == holder)
		stealth_standoff_broken(holder, "the hostage was set alight")

/// The holder tightens his grip on the hostage into tg's strangle (GRAB_KILL, the squeeze among them): hurting him.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_holder_grab_state(mob/living/source, new_state)
	SIGNAL_HANDLER
	if(new_state >= GRAB_KILL && source.pulling == standoff_hostage?.resolve())
		stealth_standoff_broken(source, "the hostage was strangled")

/**
 * `attacker` attacked `victim` (tg's relay_attackers: a blow in combat mode, a shot, a throw; not a shove). Every
 * guard standing off stops if `victim` is the hostage, the guard himself, or one of his people he can see: against
 * the holder for good; against anyone else, he leaves the holder be for now and turns on them.
 */
/proc/stealth_standoff_witness(mob/living/victim, mob/living/attacker, attack_flags)
	if(!isliving(attacker) || !(attack_flags & (ATTACKER_DAMAGING_ATTACK|ATTACKER_STAMINA_ATTACK)))
		return
	for(var/datum/ai_controller/basic_controller/human_npc/stealth/brain as anything in GLOB.stealth_standoffs.Copy())
		var/mob/living/guard = brain.pawn
		if(QDELETED(guard))
			continue
		if(brain.standoff_holder?.resolve() != attacker)
			if(victim == guard || brain.stealth_standoff_sees_friend(victim))
				brain.stealth_standoff_interrupted(victim, attacker)
			continue
		if(victim == brain.standoff_hostage?.resolve())
			brain.stealth_standoff_broken(attacker, "the hostage was hurt")
		else if(victim == guard)
			brain.stealth_standoff_broken(attacker, "the holder attacked them")
		else if(brain.stealth_standoff_sees_friend(victim))
			brain.stealth_standoff_broken(attacker, "the holder attacked one of theirs")

/// Whether `victim` is one of its own people it can see now: as stealth_has_in_view() sees, without its targeting
/// check (which skips its own people).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_sees_friend(mob/living/victim)
	var/mob/living/guard = pawn
	return guard.faction_check_atom(victim) && stealth_alert_lit(victim) && can_see(guard, victim, HUMAN_NPC_SIGHT_RANGE)

/// Someone other than the holder attacked it or one of its people in view: the standoff is off (the holder isn't to
/// blame) and it turns on them. Not for one of its own hitting a friend by mistake.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_interrupted(mob/living/victim, mob/living/attacker)
	var/mob/living/guard = pawn
	if(guard.stat != CONSCIOUS || guard.faction_check_atom(attacker))
		return
	var/atom/who = bounty_ai_target_for(attacker)
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(!strategy?.can_attack(guard, who))
		return
	log_combat(guard, attacker, "stopped standing off to fight", null, "(attacked [victim == guard ? "them" : key_name(victim)], [get_area_name(guard, TRUE)])")
	stealth_standoff_end()
	stealth_switch_target(who)

/datum/ai_controller/basic_controller/human_npc/stealth/Destroy()
	GLOB.stealth_standoffs -= src
	return ..()

// Every attack on a stealth guard (human_npc_ai.dm hooks tg's COMSIG_ATOM_WAS_ATTACKED), standing off or not.
/datum/ai_controller/basic_controller/human_npc/stealth/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	stealth_standoff_witness(source, attacker, attack_flags)
	return ..()

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_hostage_died(mob/living/source, gibbed)
	SIGNAL_HANDLER
	var/mob/living/holder = standoff_holder?.resolve()
	if(holder?.pulling == source)
		stealth_standoff_broken(holder)
	else
		stealth_standoff_end()

/// The holder says something. A demand it hears gets done once each: drop the weapon, or back off.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_standoff_demand(mob/living/source, list/speech_args)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/guard = pawn
	if(guard.stat != CONSCIOUS || HAS_TRAIT(guard, TRAIT_DEAF) || get_dist(guard, source) > STEALTH_HOSTAGE_DEMAND_RANGE)
		return
	if(stealth_hostage_of(source) != standoff_hostage?.resolve())
		return
	var/message = speech_args[SPEECH_MESSAGE]
	if(!istext(message))
		return
	// An order to drop it, not any sentence with a gun in it ("You piece of junk" isn't one).
	var/static/regex/drop_words = regex(@"\b(drop\s+(it|that|them|(the|your|ur|that|those)\s+(guns?|weapons?|piece|rifles?|pistols?|knife|knives))|put\s+(it|that|them|(the|your|ur|that|those)\s+(guns?|weapons?|piece|rifles?|pistols?|knife|knives))\s+down|put\s+down\s+(the|your|ur|that|those)\s+(guns?|weapons?|piece|rifles?|pistols?|knife|knives)|(lose|ditch)\s+(the|your|ur|that)\s+(guns?|weapons?|piece)|(guns?|weapons?)\s+down)\b", "i")
	var/static/regex/back_words = regex(@"\b(back\s+(off|up|away)|(step|get|stand|move)\s+back|move\s+away)\b", "i")
	if(!standoff_dropped && drop_words.Find(message))
		INVOKE_ASYNC(src, PROC_REF(stealth_standoff_drop))
	else if(!standoff_backed_off && back_words.Find(message))
		standoff_backed_off = TRUE
		stealth_drop_walk()
		stealth_bark(STEALTH_BARK_HOSTAGE_BACK, always = TRUE)
		log_combat(guard, source, "backed off from a hostage holder")

/// Drops what it holds in its hands, through tg's own drop. Gear locked to its body (human_npc_gear.dm, decision D3)
/// can't leave it, so that goes away onto its belt, back or suit instead: empty hands either way, and no loot.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_drop()
	var/mob/living/carbon/human/guard = pawn
	if(QDELETED(guard) || standoff_dropped)
		return
	standoff_dropped = TRUE
	var/dropped = FALSE
	for(var/obj/item/held in guard.held_items)
		if(guard.dropItemToGround(held) || guard.equip_to_appropriate_slot(held))
			dropped = TRUE
	if(dropped)
		stealth_bark(STEALTH_BARK_HOSTAGE_DROP, always = TRUE)
		var/mob/living/holder = standoff_holder?.resolve()
		log_combat(guard, holder, "dropped their weapon for a hostage holder")

/// Where it stands in the standoff: the band of distance it keeps from the holder.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_band()
	return standoff_backed_off ? list(STEALTH_HOSTAGE_BACK_OFF_RANGE, STEALTH_HOSTAGE_BACK_OFF_RANGE + 2) : list(STEALTH_HOSTAGE_HOLD_RANGE, STEALTH_HOSTAGE_DEMAND_RANGE - 1)

/**
 * Alert on someone holding one of its own at gunpoint, in view: the standoff. Holds fire (ends planning before the
 * arming, shooting and melee subtrees), keeps its distance, faces them and talks. Placed before human_npc_arm, so a
 * guard that dropped its weapon doesn't pick another up while the standoff lasts.
 */
/datum/ai_planning_subtree/stealth_hostage

/datum/ai_planning_subtree/stealth_hostage/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	if(!istype(controller))
		return
	var/mob/living/carbon/human/guard = controller.pawn
	var/mob/living/holder = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/hostage = isliving(holder) ? stealth_hostage_of(holder) : null
	var/in_standoff = !isnull(controller.standoff_holder)
	if(guard.stat != CONSCIOUS || controller.stealth_state() != STEALTH_ALERT || isnull(hostage) \
		|| !controller.stealth_standoff_with(holder, hostage) || !controller.stealth_has_in_view(holder))
		if(in_standoff)
			var/mob/living/old_hostage = controller.standoff_hostage?.resolve()
			var/mob/living/old_holder = controller.standoff_holder?.resolve()
			var/released = old_hostage && old_hostage.stat != DEAD && old_holder && stealth_hostage_of(old_holder) != old_hostage
			controller.stealth_standoff_end(released ? STEALTH_BARK_HOSTAGE_RELEASED : null)
		return
	controller.stealth_standoff_start(holder, hostage)
	controller.last_seen_turf = get_turf(holder)
	controller.stealth_set_wary()
	if(world.time >= controller.next_standoff_bark)
		controller.next_standoff_bark = world.time + STEALTH_HOSTAGE_BARK_INTERVAL
		controller.stealth_bark(STEALTH_BARK_HOSTAGE)
	var/list/band = controller.stealth_standoff_band()
	var/distance = get_dist(guard, holder)
	var/turf/dest
	if(distance < band[1])
		dest = stealth_open_near(get_ranged_target_turf_direct(holder, guard, band[1]), 1)
	else if(distance > band[2])
		dest = stealth_open_near(get_ranged_target_turf_direct(holder, guard, band[2]), 1)
	if(dest && dest != get_turf(guard) && !controller.stealth_walk_over(dest))
		controller.stealth_walk(dest, STEALTH_GOTO_INVESTIGATE)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.stealth_drop_walk()
	controller.stand_dir = stealth_dir_to(guard, holder)
	controller.look_until = 0
	if(guard.dir != controller.stand_dir)
		controller.stealth_turn_to(controller.stand_dir)
	controller.queue_behavior(/datum/ai_behavior/stealth_stand)
	return SUBTREE_RETURN_FINISH_PLANNING

// ---------------------------------------------------------------------------------------------
// What they say

/datum/human_npc_voice/scav/New()
	. = ..()
	lines[STEALTH_BARK_HOSTAGE] = list("Let 'em go!", "Easy. Easy now.", "Put the gun down!", "You won't get far.", "Nobody has to die here.")
	lines[STEALTH_BARK_HOSTAGE_DROP] = list("All right! It's down!", "Okay, okay. It's down.", "There. Happy?")
	lines[STEALTH_BARK_HOSTAGE_BACK] = list("I'm backing off.", "Okay. Backing up.", "Fine. Fine.")
	lines[STEALTH_BARK_HOSTAGE_EXECUTED] = list("You son of a-", "Take them down!", "No more talking!")
	lines[STEALTH_BARK_HOSTAGE_RELEASED] = list("Now!", "Take them!", "Get clear!")
	lines[STEALTH_BARK_HOSTAGE_PLEA] = list("Don't shoot!", "Easy! Easy!", "Do what they say!", "Please...", "Don't do anything stupid!", "I don't want to die!")
	lines[STEALTH_BARK_HOSTAGE_MUFFLED] = list("Help!", "Help me!", "Let me go!", "Get off me!", "Somebody help!", "Please, no!")
	emotes[STEALTH_BARK_HOSTAGE] = list("raises a hand slowly.", "keeps their gun low.")
	emotes[STEALTH_BARK_HOSTAGE_DROP] = list("puts their weapon down.")

// ---------------------------------------------------------------------------------------------
// Held at gunpoint, held upright (decision 62)

/**
 * tg's neck grab floors the held body (TRAIT_FLOORED from CHOKEHOLD_TRAIT). Held at gunpoint as a hostage, it is held
 * up on its feet instead: still tg's chokehold (immobilized, hands blocked), only not floored, so it stands in front of
 * its holder and takes the shots that come at them (tg's projectiles skip a floored, pinned body). Called every time
 * tg places a held body (the grab, each step, each turn: set_pull_offsets() in stealth_hostage_pose.dm); tg's own
 * release clears the chokehold either way. Puts tg's chokehold floor back when it is no longer held at gunpoint. A body
 * held with a hand over its mouth (stealth_grip.dm) is held up the same way.
 */
/mob/living/proc/stealth_hold_upright(mob/living/held)
	if(!isliving(held) || pulling != held)
		return
	// Held up in front: at gunpoint, or with a hand over the mouth (stealth_grip.dm).
	if(stealth_held_in_front(src) == held)
		held.stealth_hostage_voice_start()
		stealth_hold_no_swap(held, TRUE)
		if(HAS_TRAIT_FROM(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT))
			REMOVE_TRAIT(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT)
			// tg's own stand-up after the floor goes is a 1 s do_after; held up, they're on their feet at once.
			// get_up() still refuses a body that is resting or floored by anything else (a stun, crit).
			held.get_up(instant = TRUE)
	else
		stealth_hold_no_swap(held, FALSE)
		if(grab_state >= GRAB_NECK && !HAS_TRAIT_FROM(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT))
			ADD_TRAIT(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT)

/**
 * Held in front, neither he nor the body he holds can be swapped past (tg's mob swap, can_mobswap_with()): the swap
 * moves one of them only and leaves the body behind. Bumped, he is pushed as anyone is, and the body comes along.
 * On from stealth_hold_upright(), off there and when tg lets the body go (reset_pull_offsets()) or loosens the grab.
 */
/mob/living/proc/stealth_hold_no_swap(mob/living/held, on)
	if(on)
		ADD_TRAIT(src, TRAIT_NOMOBSWAP, STEALTH_HOLDING_IN_FRONT_TRAIT)
		ADD_TRAIT(held, TRAIT_NOMOBSWAP, STEALTH_HELD_IN_FRONT_TRAIT)
		return
	REMOVE_TRAIT(src, TRAIT_NOMOBSWAP, STEALTH_HOLDING_IN_FRONT_TRAIT)
	if(held)
		REMOVE_TRAIT(held, TRAIT_NOMOBSWAP, STEALTH_HELD_IN_FRONT_TRAIT)

/**
 * Walking with a body held in front. tg's pull only drags a pulled thing after its puller once it is a tile apart or
 * diagonal (atom/movable/Move()), so a body held on the holder's own tile is left on the tile he steps off, and is no
 * longer held in front. Held in front (at gunpoint, or with a hand over the mouth), it comes along onto his new tile
 * in the same step (Moved(), before tg turns him to face his step, so the pose just swings round), and after any move
 * of his a body he still holds that way but that ended up on a tile next to his is brought back onto it (Move()).
 * Each step of a diagonal move is a step of its own here, so a crate on one leg of it changes nothing.
 */
/mob/living/carbon/human/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(!forced && isturf(old_loc))
		stealth_hold_close()

/mob/living/carbon/human/Move(atom/newloc, direct, glide_size_override)
	. = ..()
	stealth_hold_close()
	// Held in front, pushed off and brought straight back (Moved() below): tg turned him to face the push.
	var/mob/living/carbon/human/holder = pulledby
	if(hostage_pose_dir && !moving_from_pull && ishuman(holder) && dir != holder.dir && stealth_held_in_front(holder) == src)
		holder.hostage_pose_face(src, hostage_pose_serial, holder.dir)

/**
 * The body held in front moved off its holder's tile by someone else (a shove, a push, wind): back onto his tile at
 * once, as when he steps (stealth_hold_close()). Not a move his own hold makes (moving_from_pull), nor a forced one.
 */
/mob/living/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	if(forced || moving_from_pull || !ishuman(pulledby))
		return
	var/mob/living/carbon/human/holder = pulledby
	if(old_loc == holder.loc && loc != holder.loc)
		holder.stealth_hold_close()

/**
 * Brings the body this holder neck-grabs, at gunpoint or with a hand over its mouth, onto his tile from the tile next
 * to it, as tg's own pull moves a pulled thing (move_from_pull()), only without turning it to face the way it is
 * dragged: the pose keeps it facing his way. FALSE if there was nothing to bring in or it didn't move.
 */
/mob/living/carbon/human/proc/stealth_hold_close()
	var/mob/living/held = pulling
	if(!isliving(held) || held.loc == loc || held.moving_from_pull || held.buckled || !isturf(loc) || !isturf(held.loc))
		return FALSE
	if(held.z != z || get_dist(held, src) > 1)
		return FALSE
	if(stealth_hostage_of(src, held.loc) != held && !stealth_grip_holds(src, held, held.loc))
		return FALSE
	held.moving_from_pull = src
	held.Move(loc, get_dir(held, loc), glide_size, FALSE)
	held.moving_from_pull = null
	return held.loc == loc

/// Clicking a tile next to him with a body held in front (tg's Move_Pulled()) turns him to face it, the body swinging
/// round with him; it never pushes the body off his tile.
/mob/living/carbon/human/Move_Pulled(atom/moving_atom)
	var/mob/living/held = pulling
	if(!isliving(held) || !isturf(held.loc) || (stealth_hostage_of(src, held.loc) != held && !stealth_grip_holds(src, held, held.loc)))
		return ..()
	stealth_hold_close()
	face_atom(moving_atom)
	return FALSE

/// The body held in front is dragged onto its holder's tile (stealth_hold_close() above): he lets it in, as he lets in
/// a body lying at his feet.
/mob/living/carbon/human/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(!. && mover == pulling && mover.moving_from_pull == src && grab_state >= GRAB_NECK)
		return TRUE

// ---------------------------------------------------------------------------------------------
// The hostage's own voice

/**
 * A body held up in front makes sound. Under the hand over the mouth (stealth_grip.dm) he is still TRAIT_MUTE (no
 * shout, no radio, no alarm): every few seconds he mumbles against the hand, an audible message heard only right
 * next to him, his words garbled by the rule tg's muffles_speech element uses for a muzzle. Held at gunpoint with an
 * ordinary neck grab and able to talk, an NPC now and then says a scared line out loud through tg's say(). Neither
 * reaches a guard's awareness: the stealth AI doesn't listen to speech (stealth_noise_sources.dm), and only the
 * holder's own words are heard as standoff demands (on_standoff_demand()). One timer per held body, from the moment
 * the hold puts him in front (stealth_hold_upright()) until he is no longer held in front.
 */
/mob/living
	/// The timer for this body's next stealth_hostage_voice_tick(), while it is held up in front.
	var/stealth_hostage_voice_timer
	/// world.time this body may next say a scared line at gunpoint.
	var/stealth_hostage_next_plea = 0

/// Starts this body's hostage voice, if it isn't running.
/mob/living/proc/stealth_hostage_voice_start()
	if(stealth_hostage_voice_timer)
		return
	stealth_hostage_voice_timer = addtimer(CALLBACK(src, PROC_REF(stealth_hostage_voice_tick)), rand(STEALTH_HOSTAGE_VOICE_MIN, STEALTH_HOSTAGE_VOICE_MAX), TIMER_STOPPABLE|TIMER_DELETE_ME)

/// One beat of the hostage voice: a sound if there is one, then the next beat while he is still held in front.
/mob/living/proc/stealth_hostage_voice_tick()
	stealth_hostage_voice_timer = null
	var/mob/living/holder = pulledby
	if(QDELETED(src) || stat == DEAD || isnull(holder) || stealth_held_in_front(holder) != src)
		return
	stealth_hostage_sound(holder)
	stealth_hostage_voice_start()

/**
 * The sound this body makes now, held up in front of `holder`: "mumble" under the hand, "plea" for a scared line at
 * gunpoint, or null for none (out cold, can't talk, a player in the body, nothing to say yet).
 */
/mob/living/proc/stealth_hostage_sound(mob/living/holder)
	if(stat != CONSCIOUS || isnull(holder))
		return null
	if(stealth_grip_holds(holder, src))
		// Mute from anything but the hand (a cut throat): not even a mumble.
		if(HAS_TRAIT_NOT_FROM(src, TRAIT_MUTE, STEALTH_GRIP_TRAIT))
			return null
		var/muffled = stealth_muffle_words(pick(stealth_hostage_lines(STEALTH_BARK_HOSTAGE_MUFFLED) || list("Help!")))
		audible_message(
			span_emote("<b>[src]</b> mumbles against [holder]'s hand, \"[muffled]\""),
			hearing_distance = STEALTH_HOSTAGE_MUMBLE_RANGE,
			self_message = span_emote("You mumble against [holder]'s hand, \"[muffled]\""),
		)
		return "mumble"
	// A player speaks for himself.
	if(client || stealth_hostage_of(holder) != src || world.time < stealth_hostage_next_plea || !human_npc_can_talk(src))
		return null
	var/list/pleas = stealth_hostage_lines(STEALTH_BARK_HOSTAGE_PLEA)
	if(!length(pleas))
		return null
	stealth_hostage_next_plea = world.time + rand(STEALTH_HOSTAGE_PLEA_MIN, STEALTH_HOSTAGE_PLEA_MAX)
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), pick(pleas))
	return "plea"

/// This body's voice lines of `kind`, or null: a human NPC's own voice (the scavs' is in this file).
/mob/living/proc/stealth_hostage_lines(kind)
	return null

/mob/living/carbon/human/npc/stealth_hostage_lines(kind)
	if(!ispath(npc_voice, /datum/human_npc_voice))
		return null
	var/datum/human_npc_voice/voice = human_npc_singleton(npc_voice)
	var/list/found = voice.lines[kind]
	return length(found) ? found : null

/**
 * `text` as it comes out through a hand or a gag: the rule of tg's muffles_speech element (each word becomes its length
 * in "m", give or take one, and an "f"), kept to sentence case with the line's own punctuation. tg's own copy is a
 * signal handler on a worn item, so it is the same rule written here rather than a shared proc.
 */
/proc/stealth_muffle_words(text)
	var/list/words = splittext(text, " ")
	var/list/out = list()
	var/capital = TRUE
	for(var/word in words)
		var/letters = word
		var/tail = ""
		while(length(letters) && findtext("!?.,-", copytext(letters, length(letters))))
			tail = copytext(letters, length(letters)) + tail
			letters = copytext(letters, 1, length(letters))
		if(!length(letters))
			out += tail
			continue
		var/new_word = ""
		for(var/i in 1 to max(1, length(letters) + rand(-1, 1)))
			new_word += "m"
		new_word += "f"
		if(capital)
			new_word = capitalize(new_word)
		out += "[new_word][tail]"
		capital = length(tail) && findtext("!?.", copytext(tail, length(tail)))
	return jointext(out, " ")
