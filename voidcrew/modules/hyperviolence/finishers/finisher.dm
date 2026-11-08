/**
 * # Hyperviolence finishers
 *
 * A boss or elite gets hold of someone who is down and kills them in stages: a wind-up everyone
 * can see, the pin, a beat or two, then the gore. Each stage is a /datum/hv_finisher_stage with a
 * duration, a line and an effect (finisher_stages.dm).
 *
 * The rules that keep it fair:
 * - It only starts on someone alive and down (crit, knocked over or stunned), and never on an
 *   ally or on someone another finisher already has (hv_finisher_valid_victim()).
 * - The wind-up holds nobody: pull the victim clear and it never starts.
 * - Every tick a safety check can call it off: the attacker died, was stunned or was knocked
 *   away, the victim was dragged off, died first or was deleted.
 * - Damage on the attacker breaks its hold ([var/interrupt_damage]), and it reels for a moment.
 *   While it works it is rooted and takes [var/vulnerability] times the damage, so the victim's
 *   crew can save them.
 * - Both mobs carry a status effect that expires on its own (finisher_effects.dm), and the
 *   finisher stops itself after its longest possible length, so nothing holds a victim forever.
 * - The kill never destroys the brain: a torn-off head lands at the victim's feet with the brain
 *   inside, and hv_burst_head() drops it intact.
 *
 * Design adapted from Dead Space 13's execution framework (DS-13-Dev-Team/DS13 @ 1751066f68b8,
 * AGPL-3.0: code/modules/mob/living/abilities/execution/execution.dm and execution_stage.dm):
 * stage datums run in order, a safety check, a damage interrupt and extra incoming damage while
 * busy. Rewritten for tg's basic mobs; no DS13 art or sound is used.
 *
 * Who finishes whom, and walking up to them: finisher_ai.dm. The bosses that use it:
 * finisher_users.dm.
 */

/// How often a running finisher checks itself
#define HV_FINISHER_TICK (0.2 SECONDS)
/// Slack on top of the stage durations before the timeout safety net ends it
#define HV_FINISHER_SLACK (5 SECONDS)

/datum/hv_finisher
	/// For logs only
	var/name = "finisher"
	/// The mob doing it
	var/mob/living/user
	/// The person being finished
	var/mob/living/carbon/victim
	/// Stage types in order. Each instance gets its own stage datums in New().
	var/list/stages = list()
	/// Index of the stage running now, 0 before the first
	var/stage_index = 0
	/// The stage running now
	var/datum/hv_finisher_stage/current_stage
	/// world.time the current stage began
	var/stage_started_at = 0
	/// world.time it began
	var/started_at = 0
	/// TRUE from start() until stop()
	var/running = FALSE
	/// TRUE once the killing blow has landed. After that nothing calls it off.
	var/completed = FALSE
	/// TRUE while the victim is held down
	var/gripped = FALSE
	/// TRUE once the victim has been held down at all
	var/ever_gripped = FALSE
	/// Health the attacker can lose before it lets go
	var/interrupt_damage = 40
	/// Multiplier on damage the attacker takes while it works
	var/vulnerability = 1.5
	/// How long the attacker reels after being made to let go
	var/stagger_time = 2 SECONDS
	/// The attacker's health when it began
	var/start_health = 0
	/// Body zones the kill goes for, in order of preference. pick_zone() takes the first the victim can lose.
	var/list/zone_preference = list(BODY_ZONE_HEAD)
	/// The zone picked at the start, or null if the victim has none of them to lose
	var/target_zone
	/// telegraph.dmi state marking the victim during the wind-up
	var/telegraph_state = "skull"
	/// The wind-up's mark on the victim
	var/obj/effect/temp_visual/telegraphing/hv_finisher_mark/mark
	/// Timer id of the next tick
	var/tick_timer
	/// How it ended (HV_FINISHER_*), once it has
	var/result
	/// Called once when it ends: (datum/hv_finisher/finisher, result)
	var/datum/callback/on_end

/datum/hv_finisher/New(mob/living/user, mob/living/carbon/victim, datum/callback/on_end)
	. = ..()
	src.user = user
	src.victim = victim
	src.on_end = on_end
	var/list/stage_types = stages
	stages = list()
	for(var/stage_type in stage_types)
		stages += new stage_type(src)

/datum/hv_finisher/Destroy()
	if(running)
		stop(HV_FINISHER_TIMED_OUT)
	on_end = null
	current_stage = null
	QDEL_LIST(stages)
	QDEL_NULL(mark)
	user = null
	victim = null
	return ..()

/// Sum of every stage's duration
/datum/hv_finisher/proc/total_duration()
	. = 0
	for(var/datum/hv_finisher_stage/stage as anything in stages)
		. += stage.duration

/// The longest it can possibly run before the timeout safety net ends it
/datum/hv_finisher/proc/longest_duration()
	return total_duration() + HV_FINISHER_SLACK

/// Whether it can begin right now: a valid victim, right next to a conscious attacker
/datum/hv_finisher/proc/can_start()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED))
		return FALSE
	if(!hv_finisher_valid_victim(user, victim))
		return FALSE
	return get_dist(user, victim) <= 1 && user.Adjacent(victim)

/**
 * Begins: marks both mobs, enters the first stage and starts ticking.
 * Returns FALSE, having changed nothing, if it cannot begin.
 */
/datum/hv_finisher/proc/start()
	if(running || completed || !length(stages) || !can_start())
		return FALSE
	running = TRUE
	started_at = world.time
	start_health = user.health
	pick_zone()
	var/longest = longest_duration()
	user.apply_status_effect(/datum/status_effect/hv_finishing, longest, vulnerability)
	victim.apply_status_effect(/datum/status_effect/hv_finisher_hold, longest)
	RegisterSignals(user, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_user_down))
	RegisterSignal(user, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_user_damaged))
	RegisterSignal(victim, COMSIG_LIVING_DEATH, PROC_REF(on_victim_died))
	RegisterSignal(victim, COMSIG_QDELETING, PROC_REF(on_victim_deleted))
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	RegisterSignal(victim, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	user.face_atom(victim)
	log_combat(user, victim, "began a finisher on", addition = "([name])")
	advance()
	if(running)
		schedule_tick()
	return TRUE

/// Picks the body zone the kill goes for from [var/zone_preference]
/datum/hv_finisher/proc/pick_zone()
	target_zone = null
	for(var/zone in zone_preference)
		var/obj/item/bodypart/part = victim.get_bodypart(zone)
		if(part?.can_dismember())
			target_zone = zone
			return zone

/datum/hv_finisher/proc/schedule_tick()
	tick_timer = addtimer(CALLBACK(src, PROC_REF(tick)), HV_FINISHER_TICK, TIMER_STOPPABLE|TIMER_DELETE_ME)

/// The safety check, the damage check, the stage's beat and the move to the next stage
/datum/hv_finisher/proc/tick()
	tick_timer = null
	if(!running)
		return
	var/reason = safety_check()
	if(!reason && !completed && took_too_much_damage())
		reason = HV_FINISHER_DAMAGED
	if(reason)
		end_early(reason)
		return
	if(world.time - started_at > longest_duration())
		stop(HV_FINISHER_TIMED_OUT)
		return
	var/elapsed = world.time - stage_started_at
	if(!current_stage.effect_done && elapsed >= current_stage.effect_delay)
		fire_effect()
		if(!running)
			return
	if(elapsed >= current_stage.duration)
		advance()
		if(!running)
			return
	schedule_tick()

/**
 * Leaves the current stage (firing its beat first if it never fired) and enters the next.
 * Past the last stage, it is done.
 */
/datum/hv_finisher/proc/advance()
	if(!running)
		return
	if(current_stage)
		if(!current_stage.effect_done)
			fire_effect()
			if(!running)
				return
		current_stage.exit()
	stage_index++
	if(stage_index > length(stages))
		current_stage = null
		completed = TRUE
		stop(HV_FINISHER_DONE)
		return
	current_stage = stages[stage_index]
	stage_started_at = world.time
	if(current_stage.pins)
		take_grip()
	else
		release_grip()
	current_stage.enter()
	if(!running)
		return
	if(current_stage.effect_delay <= 0)
		fire_effect()

/// Fires the current stage's beat. A killing blow marks it complete before it lands, so the death it causes doesn't call it off.
/datum/hv_finisher/proc/fire_effect()
	current_stage.effect_done = TRUE
	if(current_stage.killing_blow && !completed)
		completed = TRUE
		log_combat(user, victim, "finished", addition = "([name])")
	current_stage.effect()

/// Holds the victim down from here on
/datum/hv_finisher/proc/take_grip()
	if(gripped)
		return
	gripped = TRUE
	ever_gripped = TRUE
	QDEL_NULL(mark)
	var/datum/status_effect/hv_finisher_hold/hold = victim.has_status_effect(/datum/status_effect/hv_finisher_hold)
	hold?.set_gripped(TRUE)

/// Lets the victim go, for any stages after the kill
/datum/hv_finisher/proc/release_grip()
	if(!gripped)
		return
	gripped = FALSE
	var/datum/status_effect/hv_finisher_hold/hold = victim.has_status_effect(/datum/status_effect/hv_finisher_hold)
	hold?.set_gripped(FALSE)

/// Returns the HV_FINISHER_* reason it can't go on, or 0 if all is well
/datum/hv_finisher/proc/safety_check()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED))
		return HV_FINISHER_ATTACKER_DOWN
	if(QDELETED(victim))
		return HV_FINISHER_VICTIM_GONE
	if(!completed && victim.stat == DEAD)
		return HV_FINISHER_VICTIM_GONE
	if(!isturf(user.loc) || !isturf(victim.loc) || user.z != victim.z || get_dist(user, victim) > 1)
		return HV_FINISHER_LOST_GRIP
	// An admin heal, or anything else that took the hold off, frees them
	if(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return HV_FINISHER_LOST_GRIP
	return 0

/// Whether the attacker has lost [var/interrupt_damage] health since it began
/datum/hv_finisher/proc/took_too_much_damage()
	return (start_health - user.health) >= interrupt_damage

/// Ends it before it is done. After the killing blow there is nothing left to save, so it simply stops.
/datum/hv_finisher/proc/end_early(reason)
	if(!running)
		return
	if(completed)
		stop(HV_FINISHER_DONE)
		return
	interrupt(reason)

/// Calls it off before the killing blow, with what the room sees
/datum/hv_finisher/proc/interrupt(reason)
	if(!running || completed)
		return
	for(var/datum/hv_finisher_stage/stage as anything in stages)
		if(stage.entered)
			stage.on_interrupt()
	switch(reason)
		if(HV_FINISHER_DAMAGED)
			user.visible_message(span_danger("[user] staggers back and lets go of [victim]!"))
			// Before stop(), so the AI stays held through the hand-over
			user.apply_status_effect(/datum/status_effect/hv_finisher_reeling, stagger_time)
		if(HV_FINISHER_LOST_GRIP)
			if(gripped && !QDELETED(user) && !QDELETED(victim))
				user.visible_message(span_danger("[user] loses [user.p_their()] grip on [victim]."))
	stop(reason)

/// Ends it for any reason: frees both mobs, puts their poses back and reports the result
/datum/hv_finisher/proc/stop(reason)
	if(!running)
		return
	running = FALSE
	result = reason
	if(tick_timer)
		deltimer(tick_timer)
		tick_timer = null
	QDEL_NULL(mark)
	if(user)
		UnregisterSignal(user, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_MOVABLE_MOVED))
		if(!QDELETED(user))
			user.remove_status_effect(/datum/status_effect/hv_finishing)
			user.remove_offsets(HV_FINISHER_OFFSET)
	if(victim)
		UnregisterSignal(victim, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING, COMSIG_MOVABLE_MOVED))
		if(!QDELETED(victim))
			victim.remove_status_effect(/datum/status_effect/hv_finisher_hold)
			victim.remove_offsets(HV_FINISHER_OFFSET)
	gripped = FALSE
	for(var/datum/hv_finisher_stage/stage as anything in stages)
		if(stage.entered)
			stage.on_stop()
	if(on_end)
		var/datum/callback/callback = on_end
		on_end = null
		callback.Invoke(src, reason)

/// Leans the attacker `lunge` pixels toward the victim and lifts it `rise` pixels. Each call replaces the last pose.
/datum/hv_finisher/proc/pose_user(lunge = 0, rise = 0)
	if(QDELETED(user) || QDELETED(victim))
		return
	var/toward = get_dir(user, victim)
	var/dx = (toward & EAST) ? 1 : ((toward & WEST) ? -1 : 0)
	var/dy = (toward & NORTH) ? 1 : ((toward & SOUTH) ? -1 : 0)
	user.add_offsets(HV_FINISHER_OFFSET, null, dx * lunge, dy * lunge + rise)

/// Puts the wind-up's mark on the victim, following them until it is taken off
/datum/hv_finisher/proc/place_mark(duration)
	QDEL_NULL(mark)
	var/turf/spot = get_turf(victim)
	if(spot)
		mark = new(spot, victim, telegraph_state, duration)

// ===== Signal handlers =====

/datum/hv_finisher/proc/on_user_down(datum/source)
	SIGNAL_HANDLER
	end_early(HV_FINISHER_ATTACKER_DOWN)

/datum/hv_finisher/proc/on_user_damaged(datum/source)
	SIGNAL_HANDLER
	if(running && !completed && took_too_much_damage())
		end_early(HV_FINISHER_DAMAGED)

/datum/hv_finisher/proc/on_victim_died(datum/source)
	SIGNAL_HANDLER
	if(!completed)
		end_early(HV_FINISHER_VICTIM_GONE)

/datum/hv_finisher/proc/on_victim_deleted(datum/source)
	SIGNAL_HANDLER
	end_early(HV_FINISHER_VICTIM_GONE)

/// Either of them moved: dragged off, thrown or pushed apart
/datum/hv_finisher/proc/on_moved(datum/source)
	SIGNAL_HANDLER
	var/reason = safety_check()
	if(reason)
		end_early(reason)

/**
 * Whether `user` may start a finisher on `victim`: a carbon who is alive, down and on the floor
 * where `user` stands, not an ally, not strapped to anything and not already being finished.
 */
/proc/hv_finisher_valid_victim(mob/living/user, mob/living/carbon/victim)
	if(!iscarbon(victim) || !isliving(user) || QDELETED(victim) || QDELETED(user) || victim == user)
		return FALSE
	if(victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(!hv_finisher_is_down(victim))
		return FALSE
	if(victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	if(victim.buckled || !isturf(victim.loc) || !isturf(user.loc) || victim.z != user.z)
		return FALSE
	if(user.faction_check_atom(victim))
		return FALSE
	return TRUE

/// Whether `victim` is down: in crit, on the floor, or stunned
/proc/hv_finisher_is_down(mob/living/victim)
	return victim.stat >= SOFT_CRIT || victim.body_position == LYING_DOWN || HAS_TRAIT(victim, TRAIT_INCAPACITATED)

#undef HV_FINISHER_TICK
#undef HV_FINISHER_SLACK
