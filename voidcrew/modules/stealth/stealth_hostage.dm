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
 * - the holder hurting or killing the hostage, or the hostage dying in his hands: no more deals with that holder,
 *   ever, for that guard. He fights.
 * - out of sight of the holder, he chases as usual and stands off again when he sees them.
 *
 * Only for their own people. Someone they don't count as one of theirs (a player, a stranger) held up in front is
 * no reason to hold fire: they shoot. Never a fake state on anyone: the hostage is only held, and the guards only
 * choose not to shoot.
 */

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
/proc/stealth_hostage_of(mob/living/holder)
	if(!isliving(holder) || holder.stat != CONSCIOUS)
		return null
	var/mob/living/held = holder.pulling
	if(!isliving(held) || held.stat == DEAD || holder.grab_state < GRAB_NECK || held.loc != holder.loc)
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
	RegisterSignal(hostage, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_hostage_hurt))
	RegisterSignal(hostage, COMSIG_LIVING_DEATH, PROC_REF(on_hostage_died))
	var/mob/living/guard = pawn
	log_combat(guard, holder, "held fire on a hostage holder", null, "(hostage [key_name(hostage)], [get_area_name(guard, TRUE)])")

/// Ends the standoff, if any. `line` is the bark it says as it does.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_end(line)
	var/mob/living/holder = standoff_holder?.resolve()
	var/mob/living/hostage = standoff_hostage?.resolve()
	if(holder)
		UnregisterSignal(holder, COMSIG_MOB_SAY)
	if(hostage)
		UnregisterSignal(hostage, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_DEATH))
	var/was_on = !isnull(standoff_holder)
	standoff_holder = null
	standoff_hostage = null
	if(was_on)
		stealth_drop_walk()
		if(line)
			stealth_bark(line, always = TRUE)

/// The holder hurt or killed the hostage: no more deals with them.
/datum/ai_controller/basic_controller/human_npc/stealth/proc/stealth_standoff_broken(mob/living/holder)
	if(holder)
		LAZYOR(no_deals, REF(holder))
		var/mob/living/guard = pawn
		log_combat(guard, holder, "stopped holding fire: the hostage was hurt", null, "([get_area_name(guard, TRUE)])")
	stealth_set_wary()
	stealth_standoff_end(STEALTH_BARK_HOSTAGE_EXECUTED)

/datum/ai_controller/basic_controller/human_npc/stealth/proc/on_hostage_hurt(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item)
	SIGNAL_HANDLER
	if(damage_dealt <= 0)
		return
	var/mob/living/holder = standoff_holder?.resolve()
	if(holder && hv_vis_attacker_of(attacking_item) == holder)
		stealth_standoff_broken(holder)

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
	var/static/regex/drop_words = regex(@"\b(drop|guns?|weapons?|piece|disarm)\b", "i")
	var/static/regex/back_words = regex(@"\b(back|away|off|step|move|leave|go)\b", "i")
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
	emotes[STEALTH_BARK_HOSTAGE] = list("raises a hand slowly.", "keeps their gun low.")
	emotes[STEALTH_BARK_HOSTAGE_DROP] = list("puts their weapon down.")

// ---------------------------------------------------------------------------------------------
// Held at gunpoint, held upright (decision 62)

/**
 * tg's neck grab floors the held body (TRAIT_FLOORED from CHOKEHOLD_TRAIT). Held at gunpoint as a hostage, it is held
 * up on its feet instead: still tg's chokehold (immobilized, hands blocked), only not floored, so it stands in front of
 * its holder and takes the shots that come at them (tg's projectiles skip a floored, pinned body). Called every time
 * tg places a held body (the grab, each step, each turn: set_pull_offsets() in stealth_hostage_pose.dm); tg's own
 * release clears the chokehold either way. Puts tg's chokehold floor back when it is no longer held at gunpoint.
 */
/mob/living/proc/stealth_hold_upright(mob/living/held)
	if(!isliving(held) || pulling != held)
		return
	if(stealth_hostage_of(src) == held)
		if(HAS_TRAIT_FROM(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT))
			REMOVE_TRAIT(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT)
			// tg's own stand-up after the floor goes is a 1 s do_after; held up, they're on their feet at once.
			// get_up() still refuses a body that is resting or floored by anything else (a stun, crit).
			held.get_up(instant = TRUE)
	else if(grab_state >= GRAB_NECK && !HAS_TRAIT_FROM(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT))
		ADD_TRAIT(held, TRAIT_FLOORED, CHOKEHOLD_TRAIT)
