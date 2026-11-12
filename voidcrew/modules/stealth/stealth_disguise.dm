/**
 * # Stealth guards: disguises (owner decision 40)
 *
 * Guards look at what someone wears. It is guard AI perception only: nothing here touches the wearer's body, and
 * nothing but the stealth controller reads it, so a disguise does nothing against players or any other NPC.
 *
 * The pieces (STEALTH_PIECE_*):
 * - clothing: the scavs' own fatigues, showing, with nothing over them but what the guards' own outfits wear over
 *   theirs (stealth_guard_suits());
 * - mask: tg's own "face hidden" (get_face_name() finds no face), whatever hides it;
 * - ID: a scav pass in the ID slot.
 *
 * A disguise holds for a guard while the clothing is on and the guard hasn't seen through it (stealth_fooled()).
 * While it holds, notice fills slower by stage (stealth_look()), never jumps to an alert, and stops at suspicious,
 * where the guard stops them and asks for their pass instead (stealth_challenge()). In the full set, beyond the
 * guard's near range, they are one of its own: no notice, and a nod.
 *
 * What ends it for a guard (stealth_blow(), stealth_make()): a weapon in hand, pulling a fallen guard, an off-limits
 * room, being seen laying hands on a guard, standing over a body as it is found, running in earshot, a failed
 * challenge, and a face it has gone alert on before (a mask hides the face). The guard remembers faces for good and a
 * blown disguise's wearer for STEALTH_MADE_TIME. Its group keeps the same list, which only a wary guard reads: wary
 * is what a shout, a radio call or a hold leaves behind, so word of it reaches exactly the guards the alarm did.
 *
 * Cost: what someone wears is cached on them (/datum/component/stealth_disguise) and thrown away when they put
 * anything on or take anything off; a guard's scan reads two numbers and a list or two.
 */

// ===== The pieces =====

/// The scavs' own clothes: the only uniform guards take for theirs.
/obj/item/clothing/under/syndicate/scav
	name = "scav fatigues"
	desc = "A patched black turtleneck and cargo trousers. Half the den wears the same pair."

/obj/item/clothing/mask/balaclava/scav
	name = "scav balaclava"
	desc = "A black balaclava that has seen a lot of dust."

/// A guard's card. It opens the den's own doors (ACCESS_SCAV).
/obj/item/card/id/advanced/black/scav
	name = "scav pass"
	desc = "A scratched black card on a cord, punched with a den's mark."
	assignment = "Scav"
	access = list(ACCESS_SCAV)

/obj/item/card/id/advanced/black/scav/update_label()
	name = initial(name)

/// The suit types the guards' own outfits wear over their fatigues: type => TRUE. Read from the scav types' outfit
/// tables, so a new dress is picked up. Not kept in a static: the unit test build has no room for one more
/// (data/stealth/STATUS.md, "Decision 40"), and it is only asked for someone wearing a suit over the fatigues.
/proc/stealth_guard_suits()
	var/list/suits = list()
	for(var/mob/living/carbon/human/npc/guard_type as anything in typesof(/mob/living/carbon/human/npc/ruin/trooper/scav))
		var/table_type = initial(guard_type.npc_outfit_table)
		if(!ispath(table_type, /datum/human_npc_outfit_table))
			continue
		var/datum/human_npc_outfit_table/table = human_npc_singleton(table_type)
		for(var/list/outfits as anything in list(table.green, table.yellow, table.red))
			for(var/datum/outfit/outfit as anything in outfits)
				var/suit = initial(outfit.suit)
				if(suit)
					suits[suit] = TRUE
	return suits

/// What a human wears of the scavs' own, kept until they change clothes.
/datum/component/stealth_disguise
	/// STEALTH_PIECE_* flags, or null when they have changed since it was last worked out
	var/pieces
	/// The name tg reads off their face, or "" when it can't be seen
	var/face
	/// world.time it was last worked out
	var/checked_at = 0

/datum/component/stealth_disguise/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/stealth_disguise/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM), PROC_REF(on_change))

/datum/component/stealth_disguise/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOB_EQUIPPED_ITEM, COMSIG_MOB_UNEQUIPPED_ITEM))

/datum/component/stealth_disguise/proc/on_change(datum/source)
	SIGNAL_HANDLER
	pieces = null

/datum/component/stealth_disguise/proc/refresh()
	var/mob/living/carbon/human/wearer = parent
	checked_at = world.time
	face = wearer.get_face_name("")
	pieces = face ? NONE : STEALTH_PIECE_MASK
	if(istype(wearer.w_uniform, /obj/item/clothing/under/syndicate/scav) && !(wearer.check_obscured_slots() & ITEM_SLOT_ICLOTHING))
		if(isnull(wearer.wear_suit) || stealth_guard_suits()[wearer.wear_suit.type])
			pieces |= STEALTH_PIECE_CLOTHES
	if(istype(wearer.wear_id?.GetID(), /obj/item/card/id/advanced/black/scav))
		pieces |= STEALTH_PIECE_ID

/// The cache on `who`, worked out afresh if they changed clothes or it is older than STEALTH_DISGUISE_CACHE_TIME
/// (a mask pulled down, a face wrecked). Null for anyone but a human.
/proc/stealth_disguise_cache(mob/living/carbon/human/who)
	if(!ishuman(who))
		return null
	var/datum/component/stealth_disguise/cache = who.GetComponent(/datum/component/stealth_disguise) || who.AddComponent(/datum/component/stealth_disguise)
	if(isnull(cache.pieces) || world.time - cache.checked_at > STEALTH_DISGUISE_CACHE_TIME)
		cache.refresh()
	return cache

/// What `who` wears of the scavs' own: STEALTH_PIECE_* flags, 0 for anyone but a human.
/proc/stealth_disguise_of(mob/living/who)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(who)
	return cache ? cache.pieces : NONE

/// The stage of `pieces`, for admins and tests: 0 nothing, 1 mask, 2 clothing, 3 clothing and mask, 4 with the pass too.
/proc/stealth_disguise_stage(pieces)
	if(!(pieces & STEALTH_PIECE_CLOTHES))
		return (pieces & STEALTH_PIECE_MASK) ? 1 : 0
	if(!(pieces & STEALTH_PIECE_MASK))
		return 2
	return (pieces & STEALTH_PIECE_ID) ? 4 : 3

// ===== Off-limits rooms =====

/// Marks the room it stands in as off limits: a disguise seen in it is blown. Its room is every open tile it can
/// reach within `reach` without passing a door, a window or a grille.
/obj/effect/landmark/stealth_restricted
	name = "stealth off-limits room"
	icon_state = "x2"
	/// Tiles from here its room is followed, at most
	var/reach = 6
	/// Whether wearing a scav pass excuses being here
	var/allowed = TRUE

/datum/stealth_group
	/// Face name => TRUE, or REF(mob) => world.time the mark runs out: disguises its guards have seen through.
	/// Read only by a guard that is wary (stealth_knows()).
	var/list/made
	/// Off-limits turf => whether a pass excuses being there. Null until first asked for.
	var/list/restricted

/// Its off-limits tiles, worked out once from the marks in its region.
/datum/stealth_group/proc/off_limits()
	if(!isnull(restricted))
		return restricted
	restricted = list()
	for(var/obj/effect/landmark/stealth_restricted/mark in GLOB.landmarks_list)
		var/turf/origin = get_turf(mark)
		if(isnull(origin) || origin.z != home?.z || get_dist(origin, home) > STEALTH_GROUP_RADIUS || !region_matches(origin))
			continue
		var/list/frontier = list(origin)
		restricted[origin] = mark.allowed
		while(length(frontier))
			var/turf/here = frontier[1]
			frontier.Cut(1, 2)
			for(var/turf/open/next as anything in get_adjacent_open_turfs(here))
				if(!isnull(restricted[next]) || get_dist(next, origin) > mark.reach)
					continue
				if((locate(/obj/machinery/door) in next) || (locate(/obj/structure/window) in next) || (locate(/obj/structure/grille) in next))
					continue
				restricted[next] = mark.allowed
				frontier += next
	return restricted

/// One of its guards has been touched or hit by `attacker`: every other guard that sees them do it in a disguise
/// that still held sees through it.
/datum/stealth_group/proc/witness(mob/living/attacker, mob/living/victim)
	if(!(stealth_disguise_of(attacker) & STEALTH_PIECE_CLOTHES))
		return
	for(var/mob/living/friend as anything in living_members())
		var/datum/ai_controller/basic_controller/human_npc/stealth/friend_ai = friend.ai_controller
		if(friend == victim || !istype(friend_ai) || friend.client || friend_ai.stealth_captive())
			continue
		if(friend_ai.stealth_fooled(attacker) && friend_ai.stealth_sees(attacker))
			friend_ai.stealth_blow(attacker)

// ===== The guard's side =====

/datum/ai_controller/basic_controller/human_npc/stealth
	/// Face name => TRUE, or REF(mob) => world.time the mark runs out: disguises it has seen through itself
	var/list/made
	/// REF(mob) => world.time until which it lets them be, after it checked their pass
	var/list/passes
	/// REF(mob) => list of world.time it waved them on after reading their pass (stealth_rechecked())
	var/list/waved
	/// Weakref to whoever it has stopped to check
	var/datum/weakref/challenge
	/// Where they stood when it stopped them
	var/turf/start_turf
	/// world.time it got near enough to look at their pass, or 0
	var/checked_at = 0
	/// Whether it has asked a second time
	var/warned = FALSE
	/// world.time it may next greet one of its own
	var/greeted = 0

/// Whether it sees through `who`: it knows the face, or the wearer of a disguise it saw blown; and, while it is
/// wary, anyone its group does.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_knows(mob/living/who)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(who)
	if(isnull(cache))
		return FALSE
	var/key = REF(who)
	var/face = cache.face
	if(made && ((face && made[face]) || made[key] > world.time))
		return TRUE
	var/list/told = blackboard[BB_STEALTH_WARY] ? group?.made : null
	return !!(told && ((face && told[face]) || told[key] > world.time))

/// `who`'s STEALTH_PIECE_* flags if their disguise holds for this guard: the clothing is on and it hasn't seen
/// through them. 0 otherwise.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_fooled(mob/living/who)
	var/pieces = stealth_disguise_of(who)
	if(!(pieces & STEALTH_PIECE_CLOTHES) || stealth_knows(who))
		return NONE
	return pieces

/**
 * Remembers `who`: their face for good, if it shows. `blown`: also the wearer, face or no face, for
 * STEALTH_MADE_TIME (a disguise it saw through; a mask won't fix that). `word`: its group gets the same, for the
 * guards an alarm reaches.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_make(mob/living/who, blown = TRUE, word = TRUE)
	var/datum/component/stealth_disguise/cache = stealth_disguise_cache(who)
	if(isnull(cache))
		return
	var/key = REF(who)
	if(cache.face)
		LAZYSET(made, cache.face, TRUE)
		if(word && group)
			LAZYSET(group.made, cache.face, TRUE)
	if(!blown)
		return
	LAZYSET(made, key, world.time + STEALTH_MADE_TIME)
	if(word && group)
		LAZYSET(group.made, key, world.time + STEALTH_MADE_TIME)
	if(passes)
		passes -= key

/// Whether it sees `who` plainly now: eyes open, in its cone, in the light it needs, nothing in the way.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_sees(mob/living/who)
	var/mob/living/guard = pawn
	var/turf/where = who.loc
	if(!isturf(where) || !isturf(guard.loc) || guard.stat != CONSCIOUS || !stealth_eyes_open() || stealth_is_cloaked(who))
		return FALSE
	var/dist = get_dist(guard, where)
	if(dist > STEALTH_ADJACENT_RANGE && dist > stealth_range_onto(where))
		return FALSE
	if(!stealth_in_cone(guard, where, stealth_half_angle()))
		return FALSE
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	return !!strategy?.can_attack(guard, who, stealth_skill().sight_range)

/// Whether `who`, seen on `where` in a disguise of `pieces`, is doing something no guard of the den would: a weapon
/// in hand, pulling a fallen guard, or standing in an off-limits room the pass doesn't excuse.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_breaker(mob/living/carbon/human/who, pieces, turf/where)
	for(var/obj/item/held in who.held_items)
		if(isgun(held) || istype(held, /obj/item/melee) || (held.force >= STEALTH_WEAPON_FORCE && held.get_sharpness()))
			return TRUE
	var/mob/living/pulled = who.pulling
	var/mob/living/guard = pawn
	if(isliving(pulled) && guard.faction_check_atom(pulled) && (pulled.stat != CONSCIOUS || pulled.body_position == LYING_DOWN || HAS_TRAIT(pulled, TRAIT_RESTRAINED)))
		return TRUE
	var/list/rooms = group?.off_limits()
	var/excused = rooms?[where]
	return !isnull(excused) && !(excused && (pieces & STEALTH_PIECE_ID))

/**
 * It has seen through `who`. It remembers them, says so, and goes alert if they are near enough to be sure of and
 * can be fought. Already fighting someone, it only remembers them. Returns TRUE if it went alert on them.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_blow(mob/living/who)
	var/mob/living/guard = pawn
	stealth_make(who)
	challenge = null
	start_turf = null
	if(stealth_state() == STEALTH_ALERT)
		stealth_remember(who)
		return FALSE
	stealth_bark(STEALTH_BARK_BLOWN, null, null, TRUE)
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(blackboard[BB_TARGETING_STRATEGY])
	if(get_dist(guard, who) > stealth_skill().alert_max_range || !strategy?.can_attack(guard, who, HUMAN_NPC_SIGHT_RANGE))
		return FALSE
	stealth_go_alert(bounty_ai_target_for(who))
	return stealth_state() == STEALTH_ALERT

/// The tiles within which it stops someone in a disguise of `pieces` that it sees plainly.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_challenge_range(pieces)
	. = STEALTH_CHALLENGE_RANGE_CLOTHES
	if(pieces & STEALTH_PIECE_MASK)
		. = (pieces & STEALTH_PIECE_ID) ? STEALTH_CHALLENGE_RANGE_FULL : STEALTH_CHALLENGE_RANGE_MASKED
	. = max(1, . + stealth_skill().challenge + (blackboard[BB_STEALTH_WARY] ? 1 : 0))

/// How much of its usual notice someone in a disguise of `pieces` gains at `dist` tiles.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_disguise_mult(pieces, dist)
	var/datum/stealth_skill/profile = stealth_skill()
	if(!(pieces & STEALTH_PIECE_MASK))
		return STEALTH_DISGUISE_FILL_CLOTHES * profile.disguise
	if(!(pieces & STEALTH_PIECE_ID))
		return STEALTH_DISGUISE_FILL_MASKED * profile.disguise
	// The whole set: one of its own at a distance, whatever its skill.
	return dist > profile.near_range ? 0 : STEALTH_DISGUISE_FILL_FULL * profile.disguise

/// The name on the pass `who` wears, if it is one of its group's own: what its friends called them. An NPC's
/// name, never player text; null for a pass in nobody's name or a guard with only its type's name.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_card_name(mob/living/carbon/human/who)
	var/obj/item/card/id/card = ishuman(who) ? who.wear_id?.GetID() : null
	if(!istype(card) || !card.registered_name)
		return null
	for(var/mob/living/carbon/human/npc/friend as anything in group?.living_members())
		if(friend != pawn && friend.real_name == card.registered_name)
			return stealth_first_name(friend)
	return null

/// One of its own goes by (so it thinks): a nod or a word, now and then.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_greet(mob/living/who)
	if(world.time < greeted || stealth_state() != STEALTH_UNAWARE)
		return
	greeted = world.time + STEALTH_GREET_COOLDOWN
	stealth_bark(prob(25) ? STEALTH_BARK_SMOKE : STEALTH_BARK_GREET, null, stealth_card_name(who))

/**
 * Whether stopping the one under `key` again is a stop too many: it waved them on within
 * STEALTH_PASS_RECHECK_COOLDOWN, or STEALTH_PASS_RECHECK_MAX times within STEALTH_PASS_RECHECK_MEMORY. The same shape
 * as a door's cue throttle (stealth_doors.dm), so taking the pass off and on can't pull a guard over again and again.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_rechecked(key)
	var/list/stamps = waved?[key]
	if(!stamps)
		return FALSE
	for(var/index in length(stamps) to 1 step -1)
		if(world.time - stamps[index] > STEALTH_PASS_RECHECK_MEMORY)
			stamps.Cut(index, index + 1)
	if(!length(stamps))
		LAZYREMOVE(waved, key)
		return FALSE
	return length(stamps) >= STEALTH_PASS_RECHECK_MAX || world.time - stamps[length(stamps)] < STEALTH_PASS_RECHECK_COOLDOWN

/**
 * Stops `who` to see their pass: suspicious of them, facing and pointing at them, with the challenge line. From
 * here stealth_check_challenge() decides, once a scan.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_challenge(mob/living/who)
	var/mob/living/guard = pawn
	if(QDELETED(who) || stealth_driven() || stealth_state() == STEALTH_ALERT || challenge?.resolve() == who)
		return
	// Waved on a moment ago, or too often: a pass that keeps coming off is no pass (decision 40 throttle).
	if(stealth_rechecked(REF(who)))
		stealth_blow(who)
		return
	var/turf/where = get_turf(who)
	if(stealth_state() == STEALTH_SUSPICIOUS)
		investigated = FALSE
		stealth_drop_walk()
		stealth_aim_at(where)
		stealth_bark(STEALTH_BARK_CHALLENGE, null, null, TRUE)
	else
		// The line always comes with the stop.
		bark_ready_at -= STEALTH_BARK_CHALLENGE
		stealth_go_suspicious(where, STEALTH_GOTO_INVESTIGATE, STEALTH_BARK_CHALLENGE)
	if(stealth_state() != STEALTH_SUSPICIOUS)
		return
	challenge = WEAKREF(who)
	start_turf = where
	checked_at = 0
	warned = FALSE
	suspicion_heard = FALSE
	goto_purpose = STEALTH_GOTO_INVESTIGATE
	stealth_remember(who)
	notice_map[REF(who)][STEALTH_ENTRY_NOTICE] = STEALTH_SUSPICIOUS_AT
	set_blackboard_key(BB_STEALTH_FOCUS, who)
	INVOKE_ASYNC(guard, TYPE_PROC_REF(/mob, _pointed), who)
	stealth_meter_update()

/**
 * The scan, while it has someone stopped. Blown: the clothing is off, it knows them now, they run, they are more
 * than STEALTH_CHALLENGE_LEASH from where it stopped them, it can't see them, they do what no guard would, or
 * they still show no pass STEALTH_CHALLENGE_FAIL_TIME after it got to them. Passed: the pass is on them and it has
 * looked at it for STEALTH_CHALLENGE_CHECK_TIME from within STEALTH_CHALLENGE_CHECK_RANGE.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_check_challenge()
	var/mob/living/carbon/human/who = challenge?.resolve()
	if(isnull(who))
		challenge = null
		return
	var/mob/living/guard = pawn
	if(QDELETED(who) || who.stat == DEAD || stealth_state() != STEALTH_SUSPICIOUS)
		challenge = null
		start_turf = null
		return
	var/key = REF(who)
	var/list/entry = notice_map[key]
	var/turf/where = get_turf(who)
	var/pieces = stealth_fooled(who)
	// It keeps its eyes on them.
	if(get_turf(guard) != where)
		stand_dir = stealth_dir_to(guard, where)
		guard.setDir(stand_dir)
	var/ran = who.move_intent == MOVE_INTENT_RUN && entry && entry[STEALTH_ENTRY_TURF] != where
	var/late = checked_at && !(pieces & STEALTH_PIECE_ID) && world.time - checked_at >= STEALTH_CHALLENGE_FAIL_TIME
	if(!pieces || ran || late || get_dist(where, start_turf) > STEALTH_CHALLENGE_LEASH || !stealth_sees(who) || stealth_breaker(who, pieces, where))
		if(!stealth_blow(who) && stealth_state() == STEALTH_SUSPICIOUS)
			stealth_go_searching(where)
			stealth_first_hand(where)
		return
	last_gain = world.time
	investigate_turf = where
	last_seen_turf = where
	stealth_remember(who)
	notice_map[key][STEALTH_ENTRY_NOTICE] = STEALTH_SUSPICIOUS_AT
	if(get_dist(guard, where) > STEALTH_CHALLENGE_CHECK_RANGE)
		return
	if(!checked_at)
		checked_at = world.time
	if(pieces & STEALTH_PIECE_ID)
		if(world.time - checked_at < STEALTH_CHALLENGE_CHECK_TIME)
			return
		stealth_bark(STEALTH_BARK_ID_PASS, null, stealth_card_name(who), TRUE)
		LAZYSET(passes, key, world.time + STEALTH_PASS_TIME)
		LAZYADDASSOCLIST(waved, key, world.time)
		stealth_go_unaware()
		return
	if(!warned && world.time - checked_at >= STEALTH_CHALLENGE_WARN_TIME)
		warned = TRUE
		stealth_bark(STEALTH_BARK_ID_FAIL, null, null, TRUE)
