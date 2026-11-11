/**
 * # Lockers and crates a guard saw someone get into (owner decision 33)
 *
 * An alert guard, or a searching one that glimpses someone, that sees its target get into a locker, a crate, a
 * coffin, a body bag or a cardboard box (any /obj/structure/closet), or sees the door shut on them, remembers
 * that container. It walks up and opens it with tg's own open(). If it won't open (locked or welded), it hits it
 * with what it holds, through tg's click path: with a loaded gun it steps back to two tiles off and shoots it (tg
 * never fires a gun at a thing beside you: that click is a gun-butt blow, which can't dent a secure locker), or
 * it hits it with its melee weapon when that can dent it. A locker that breaks bursts open through tg's atom_break(). It gives up after
 * STEALTH_CLOSET_GIVE_UP_TIME and searches round it.
 *
 * Someone who gets in unseen is still hidden (decision 22): an alert guard whose target is in a container it
 * didn't see them get into treats them as out of sight, and never shoots at the container (tg's own
 * find_hidden_mobs() would have it shoot any locker its target is in, from across the room).
 *
 * With several guards on one container the one that claimed it first opens it; the rest stand close and cover it.
 */

/datum/ai_controller/basic_controller/human_npc/stealth
	/// The locker or crate it saw its target get into, or null. Cleared when it is deleted.
	var/obj/structure/closet/shut_in
	/// Who it saw get in
	var/datum/weakref/shut_who
	/// world.time it saw them get in
	var/shut_in_at = 0
	/// Alert: world.time it last saw its target on open ground
	var/target_free_seen_at = 0
	/// Its container wouldn't open for it (locked or welded): a gunner steps back to shoot it
	var/closet_stuck = FALSE

/// The locker, crate or box `who` is shut in (the outermost, if one is inside another), or null.
/proc/stealth_closet_of(mob/living/who)
	if(!isliving(who))
		return null
	var/atom/movable/shell = stealth_shell_of(who)
	return istype(shell, /obj/structure/closet) ? shell : null

/// Whether it has `box` in view (all round, as it keeps an alert target in view).
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sees_closet(obj/structure/closet/box)
	var/mob/living/guard = pawn
	if(QDELETED(box) || !isturf(guard.loc) || get_dist(guard, box) > HUMAN_NPC_SIGHT_RANGE)
		return FALSE
	return can_see(guard, box, HUMAN_NPC_SIGHT_RANGE)

/// Remembers that it saw `who` get into `box`.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_claim_closet(obj/structure/closet/box, mob/living/who)
	if(shut_in == box)
		shut_who = WEAKREF(who)
		return
	stealth_drop_closet()
	shut_in = box
	shut_who = WEAKREF(who)
	shut_in_at = world.time
	RegisterSignal(box, COMSIG_QDELETING, PROC_REF(on_closet_deleted))

/// Forgets the container it was after.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_drop_closet()
	if(shut_in)
		UnregisterSignal(shut_in, COMSIG_QDELETING)
	shut_in = null
	shut_who = null
	shut_in_at = 0
	closet_stuck = FALSE

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_closet_deleted(datum/source)
	SIGNAL_HANDLER
	stealth_drop_closet()

/**
 * Its claim, still good: `who` is still inside it (or inside something that went into it, which it then goes
 * after instead). Drops a claim that no longer holds and returns null.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_check(mob/living/who)
	var/obj/structure/closet/box = shut_in
	if(isnull(box))
		return null
	if(!isliving(who) || QDELETED(who) || who.stat == DEAD || shut_who?.resolve() != who)
		stealth_drop_closet()
		return null
	var/atom/holder = who.loc
	while(holder && holder != box && !isturf(holder))
		holder = holder.loc
	var/obj/structure/closet/outer = stealth_closet_of(who)
	if(holder != box || isnull(outer))
		// They got out, or someone opened it, or it went into something that isn't a locker.
		stealth_drop_closet()
		return null
	if(outer != box)
		// The box it watched was shut inside another one: that is the one to open now.
		var/claimed_at = shut_in_at
		stealth_claim_closet(outer, who)
		shut_in_at = claimed_at
	return shut_in

/// Searching: whether it saw `candidate` on open ground a moment ago, close to the `shell` it can see them in now.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_glimpsed(mob/living/candidate, atom/movable/shell)
	if(!istype(shell, /obj/structure/closet))
		return FALSE
	var/list/entry = notice_map[REF(candidate)]
	if(isnull(entry) || entry[STEALTH_ENTRY_NOTICE] < STEALTH_SUSPICIOUS_AT)
		return FALSE
	if(world.time - entry[STEALTH_ENTRY_SEEN_AT] > STEALTH_CLOSET_SEEN_WINDOW)
		return FALSE
	var/turf/was = entry[STEALTH_ENTRY_TURF]
	if(isnull(was) || get_dist(was, shell) > 2)
		return FALSE
	return can_see(pawn, shell, stealth_skill().sight_range)

/// Just went alert on `target` (always first hand: sight, a touch, a hit). If they are in a container, that's the one.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_alerted(atom/target)
	var/mob/living/who = target
	if(!isliving(who))
		stealth_drop_closet()
		return
	if(isturf(who.loc))
		stealth_drop_closet()
		target_free_seen_at = world.time
		return
	var/obj/structure/closet/box = stealth_closet_of(who)
	if(box && stealth_sees_closet(box))
		stealth_claim_closet(box, who)
	else if(shut_in && shut_who?.resolve() != who)
		stealth_drop_closet()

/**
 * Alert, from stealth_keep_target(): its target `remembered` is in a container. Returns FALSE if they are not
 * (the usual can_attack() tracking goes on). A container it saw them get into is kept in view like the target
 * itself; any other hides them, and they are lost after STEALTH_LOSE_TARGET_TIME as if they had run off.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_track(atom/remembered)
	var/mob/living/guard = pawn
	var/mob/living/who = remembered
	var/obj/structure/closet/outer = stealth_closet_of(who)
	if(isnull(outer))
		if(shut_in)
			stealth_drop_closet()
		return FALSE
	var/obj/structure/closet/box = stealth_closet_check(who)
	// On open ground a moment ago, and the door shut on them in front of it.
	if(isnull(box) && world.time - target_free_seen_at <= STEALTH_CLOSET_SEEN_WINDOW && stealth_eyes_open() && stealth_sees_closet(outer))
		stealth_claim_closet(outer, who)
		box = outer
	if(box && stealth_sees_closet(box))
		lost_since = 0
		last_seen_turf = get_turf(box)
		blackboard[BB_STEALTH_LAST_SEEN_AT] = world.time
		if(!blackboard[BB_BASIC_MOB_CURRENT_TARGET])
			set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, who)
		return TRUE
	if(!lost_since)
		lost_since = world.time
	if(world.time - lost_since < STEALTH_LOSE_TARGET_TIME)
		return TRUE
	stealth_drop_closet()
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_bark(STEALTH_BARK_LOST)
	stealth_go_searching(last_seen_turf || get_turf(guard))
	return TRUE

/// Whether it is the one to open `box`: of its group's guards after it, the one that saw them get in first.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_opener(obj/structure/closet/box)
	if(isnull(group))
		return TRUE
	var/seen_self = FALSE
	for(var/datum/weakref/ref as anything in group.members)
		var/mob/living/member = ref?.resolve()
		if(isnull(member))
			continue
		if(member == pawn)
			seen_self = TRUE
			continue
		var/datum/ai_controller/basic_controller/human_npc/stealth/other = member.ai_controller
		if(!istype(other) || other.shut_in != box || member.stat != CONSCIOUS || member.client || other.stealth_captive())
			continue
		if(other.shut_in_at < shut_in_at || (other.shut_in_at == shut_in_at && !seen_self))
			return FALSE
	return TRUE

/// Out of time on its container: it says so and searches round it.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_give_up()
	var/turf/where = get_turf(shut_in) || last_seen_turf
	stealth_drop_closet()
	clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
	stealth_bark(STEALTH_BARK_CLOSET_GIVE_UP)
	stealth_go_searching(where)
	// It knows someone is in there: its search doesn't end with "Nothing."
	search_for_body = TRUE

/**
 * Beside its container: opens it with tg's open(), as a hand on the door would. Locked or welded shut, it hits
 * it once with what it holds, through tg's click path: a point-blank shot from a loaded gun, or its melee
 * weapon if that hits hard enough to dent it (a gun butt can't: a secure locker shrugs off anything under its
 * damage_deflection). Bare-handed it can only wait.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_try_closet()
	var/mob/living/carbon/human/guard = pawn
	var/obj/structure/closet/box = shut_in
	if(QDELETED(box) || HAS_TRAIT(guard, TRAIT_HANDS_BLOCKED) || guard.incapacitated)
		return
	var/obj/item/gun/gun = human_npc_loaded_gun(guard)
	var/adjacent = guard.Adjacent(box)
	// Stepped back to shoot it (stealth_closet_fire_spot()).
	if(!adjacent && !(closet_stuck && gun && stealth_closet_in_fire_spot(box)))
		return
	var/mob/living/who = shut_who?.resolve()
	guard.face_atom(box)
	if(adjacent && box.open(guard))
		stealth_drop_closet()
		stealth_bark(STEALTH_BARK_CLOSET_OPEN)
		if(isliving(who) && !QDELETED(who))
			// Out on the floor in front of it, or still in a box that was inside: either way, in plain view.
			if(isturf(who.loc))
				target_free_seen_at = world.time
				lost_since = 0
			else
				stealth_closet_alerted(who)
		return
	closet_stuck = TRUE
	if(world.time < guard.next_move)
		return
	if(gun)
		if(adjacent || world.time < blackboard[BB_HUMAN_NPC_NEXT_SHOT] || !human_npc_ready_item(guard, gun))
			return
		guard.zone_selected = BODY_ZONE_CHEST
		ai_interact(target = box, combat_mode = TRUE)
		set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + (blackboard[BB_HUMAN_NPC_SHOT_DELAY] || 3 SECONDS))
		return
	var/obj/item/weapon = human_npc_held_melee_weapon(guard)
	if(isnull(weapon) || (weapon.item_flags & NOBLUDGEON) || weapon.force < max(box.damage_deflection, 1))
		return
	human_npc_ready_item(guard, weapon)
	human_npc_ready_weapon(guard, weapon)
	ai_interact(target = box, combat_mode = TRUE)

/// Whether it stands two tiles from `box` with a clear line to it: where it shoots a container that won't open.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_in_fire_spot(obj/structure/closet/box)
	var/mob/living/guard = pawn
	return isturf(guard.loc) && get_dist(guard, box) == 2 && can_see(guard, box, 2)

/// The nearest open tile two tiles from `box` with a clear line to it, or null.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_closet_fire_spot(obj/structure/closet/box)
	var/mob/living/guard = pawn
	var/turf/center = get_turf(box)
	var/turf/best
	var/best_dist = INFINITY
	for(var/turf/open/spot in RANGE_TURFS(2, center))
		if(get_dist(spot, center) != 2 || spot.is_blocked_turf(exclude_mobs = TRUE) || !can_see(spot, center, 2))
			continue
		var/dist = get_dist(guard, spot)
		if(dist < best_dist)
			best = spot
			best_dist = dist
	return best

/**
 * Alert with its target in a container. One it saw them get into: the guard that saw first walks over and opens
 * it, the others close in to STEALTH_CLOSET_COVER_RANGE and cover it. One it didn't: it holds its fire and watches
 * where it last saw them, rather than shoot whatever its target hides in. Ends planning either way, so the
 * shooting and melee subtrees after it never aim at the container from range.
 */
/datum/ai_planning_subtree/stealth_closet

/datum/ai_planning_subtree/stealth_closet/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/controller, seconds_per_tick)
	if(!istype(controller) || controller.stealth_state() != STEALTH_ALERT)
		return
	var/mob/living/guard = controller.pawn
	if(guard.stat != CONSCIOUS)
		return
	var/mob/living/who = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET] || controller.blackboard[BB_STEALTH_FOCUS]
	var/obj/structure/closet/outer = stealth_closet_of(who)
	if(isnull(outer))
		return
	var/obj/structure/closet/box = controller.stealth_closet_check(who)
	if(isnull(box))
		controller.stealth_drop_walk()
		var/turf/last = controller.last_seen_turf
		if(last && last != get_turf(guard))
			controller.stand_dir = stealth_dir_to(guard, last)
		controller.queue_behavior(/datum/ai_behavior/stealth_stand)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(world.time - controller.shut_in_at >= STEALTH_CLOSET_GIVE_UP_TIME)
		controller.stealth_drop_walk()
		controller.stealth_closet_give_up()
		return SUBTREE_RETURN_FINISH_PLANNING
	var/turf/spot = get_turf(box)
	if(!controller.stealth_closet_opener(box))
		if(get_dist(guard, box) > STEALTH_CLOSET_COVER_RANGE && !controller.stealth_walk_gave_up(spot))
			controller.stealth_walk(spot, STEALTH_GOTO_CLOSET)
			return SUBTREE_RETURN_FINISH_PLANNING
		controller.stealth_drop_walk()
		if(spot != get_turf(guard))
			controller.stand_dir = stealth_dir_to(guard, box)
		controller.queue_behavior(/datum/ai_behavior/stealth_stand)
		return SUBTREE_RETURN_FINISH_PLANNING
	// It wouldn't open: a gunner shoots it from two tiles off.
	if(controller.closet_stuck && human_npc_loaded_gun(guard))
		if(controller.stealth_closet_in_fire_spot(box))
			controller.stealth_drop_walk()
			controller.queue_behavior(/datum/ai_behavior/stealth_open_closet)
			return SUBTREE_RETURN_FINISH_PLANNING
		var/turf/fire_spot = controller.stealth_closet_fire_spot(box)
		if(fire_spot && !controller.stealth_walk_gave_up(fire_spot))
			controller.stealth_walk(fire_spot, STEALTH_GOTO_CLOSET)
			return SUBTREE_RETURN_FINISH_PLANNING
	if(!guard.Adjacent(box))
		if(controller.stealth_walk_gave_up(spot))
			// No way to it: it gives up now rather than stand there.
			controller.stealth_drop_walk()
			controller.stealth_closet_give_up()
			return SUBTREE_RETURN_FINISH_PLANNING
		controller.stealth_walk(spot, STEALTH_GOTO_CLOSET)
		return SUBTREE_RETURN_FINISH_PLANNING
	controller.stealth_drop_walk()
	controller.queue_behavior(/datum/ai_behavior/stealth_open_closet)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Beside the container: one try a second (stealth_try_closet()). Never finishes by itself; planning replaces it.
/datum/ai_behavior/stealth_open_closet
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/stealth_open_closet/perform(seconds_per_tick, datum/ai_controller/basic_controller/human_npc/stealth/controller)
	if(istype(controller))
		controller.stealth_try_closet()
	return AI_BEHAVIOR_DELAY
