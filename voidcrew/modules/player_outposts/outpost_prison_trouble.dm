/**
 * # Prison trouble, the prisoner's side
 *
 * Mood, 0 to 100, drifts every minute with how a prisoner is kept (hunger, uniform, injuries,
 * being bolted in) and how the wing is kept (dark, dirty, unpowered, or all good), and jumps with
 * events: a meal, a clean uniform, treatment, a talk with staff, being hit by staff, seeing a
 * fight. Personality scales the losses. See the numbers in voidcrew/_DEFINES/outpost_prison_trouble.dm.
 *
 * Unhappy prisoners make trouble:
 * - Below PRISONER_THREAT_MOOD, staff who come within two tiles in the cell block get threatened
 *   first; a few seconds later the prisoner may swing. Nobody squares up to someone who just fed,
 *   treated or clothed them.
 * - Two prisoners below PRISONER_FIGHT_MOOD near each other may argue, then scuffle until one
 *   yields. Prisoners never kill each other.
 * - At PRISONER_BEATEN_BELOW percent health they collapse for a while and can be dragged.
 * - No single blow kills a prisoner on their feet: it leaves them at 1 health, collapsed. Only a
 *   prisoner who is already down can be killed.
 * - Below PRISONER_CLIMB_MOOD, a serving hatch left open on both sides gets climbed.
 * Staff who hit a prisoner making trouble, or one who just struck them, cost that prisoner no mood.
 * A player's blow on a calm prisoner on their feet makes them hit back for a while, or back off
 * (react_to_hit()); one already making trouble turns on whoever hit them.
 * A member of the wing can talk an unhappy prisoner down ("Calm down" on the talk menu).
 * The wing-wide side (tension, stages, fights, riots, escapes, wrecked cells) is in
 * outpost_prison_riot.dm.
 *
 * Timers count in seconds through the prison's tick(), so tests can run them forward. Walking to a
 * target and striking it is done by the AI (the trouble subtree below) while anyone is on the
 * level; confront() is the strike itself.
 */

/// Trait source for a prisoner lying beaten
#define PRISONER_BEATEN_TRAIT "outpost_prisoner_beaten"
/// Offset source for a prisoner half way over a serving hatch
#define PRISONER_CLIMB_OFFSET "outpost_prisoner_climb"
#define PRISONER_CLIMB_HOP_OFFSET "outpost_prisoner_climb_hop"
/// How long after a staff hit a collapse or death is put down to staff (deciseconds)
#define PRISONER_STAFF_BLAME_TIME (5 SECONDS)
/// Blackboard key: what a prisoner in trouble is going for
#define BB_OUTPOST_PRISONER_TROUBLE_TARGET "outpost_prisoner_trouble_target"
// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1

/mob/living/basic/outpost_prisoner
	// Swings at staff and each other; rioters with a shiv hit harder, and can wound (update_melee()).
	melee_damage_lower = PRISONER_PUNCH_MIN
	melee_damage_upper = PRISONER_PUNCH_MAX
	attack_verb_continuous = "punches"
	attack_verb_simple = "punch"
	attack_sound = 'sound/items/weapons/punch1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	/// 0 (furious) to 100 (content)
	var/mood = PRISONER_MOOD_START
	/// What trouble they are in: null, or PRISONER_TROUBLE_FIGHT, _RIOT, _BREAKOUT, _LOOSE or _WRECK
	var/trouble
	/// world.time their last trouble ended; staff finishing a subdual just after it are not to blame
	var/trouble_ended_at = 0
	/// Seconds left lying beaten, or 0
	var/beaten_left = 0
	/// The member of staff they are squaring up to, and the seconds before they decide to swing
	var/datum/weakref/threat_ref
	var/threat_left = 0
	/// Who they decided to swing at, and the seconds left to close in
	var/datum/weakref/swing_ref
	var/swing_left = 0
	/// Seconds before they threaten anyone again
	var/threat_cooldown = 0
	/// The fight they are in
	var/datum/outpost_prison_fight/fight
	/// Seconds before they will start another fight
	var/fight_cooldown = 0
	/// The serving hatch they are climbing over, and the seconds left
	var/datum/weakref/climb_ref
	var/climb_left = 0
	/// The fixture or door a rioter is working on, and the blows it has had from them
	var/datum/weakref/riot_target_ref
	var/riot_target_hits = 0
	/// The member of staff a rioter is going for, so no more than PRISON_RIOT_MAX_ATTACKERS go for one
	var/datum/weakref/riot_victim_ref
	/// REF() of targets they could not get to -> world.time they may try again
	var/list/riot_skips
	/// Tries at a target that is next to them but out of reach, before they give up on it
	var/confront_waits = 0
	/// Seconds left before a breakout rioter or loose prisoner is gone for good; 0 when not counting
	var/loose_left = 0
	/// world.time of the last hit by staff, or 0, and whether that hit was deserved
	var/last_staff_hit = 0
	var/last_hit_justified = FALSE
	/// Who they last swung at themselves, and when: hitting back is not held against staff
	var/datum/weakref/struck_ref
	var/struck_at = 0
	/// A baton hit stops their blows until this world.time
	var/baton_stop_until = 0
	/// REF() of people who fed, treated or clothed them -> world.time; they are not threatened for a while
	var/list/helped_by
	/// A member of staff is talking them down right now
	var/talking = FALSE
	/// Shut in their cell at the last confinement check
	var/was_confined = FALSE
	/// Wrecking their cell: seconds before the bolts shear, and to the next bang on the door
	var/wreck_left = 0
	var/wreck_bang_left = 0
	/// world.time they last collapsed or died, and whether staff got the blame for it
	var/collapsed_at = 0
	var/beaten_by_staff = FALSE
	var/died_at = 0
	var/death_blamed = FALSE
	/// One hit can arrive by two routes (a baton sends two signals), and a subdual takes several; count it once
	COOLDOWN_DECLARE(staff_hit_cooldown)
	/// Lines said while fighting or rioting, so they don't shout every blow
	COOLDOWN_DECLARE(trouble_speech_cooldown)
	/// Talked down recently; another talk does no more good for a while
	COOLDOWN_DECLARE(talk_cooldown)

/// Hooks up what trouble needs: who hit them, the baton, turret fire, help and talk from staff
/mob/living/basic/outpost_prisoner/proc/setup_trouble()
	AddElement(/datum/element/relay_attackers)
	AddElement(/datum/element/outpost_prisoner_gratitude)
	RegisterSignal(src, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	RegisterSignal(src, COMSIG_MOB_BATONED, PROC_REF(on_batoned))
	RegisterSignal(src, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_prehit))
	// A member's empty hand opens the talk menu (on_talk_menu_click() in outpost_prison_warden_tools.dm), where the talk-down is.

/**
 * Whether an outpost prison NPC's AI is running, which it is only while someone is on the level to
 * see them. tg's controller also switches itself off for AI_FAILED_PLANNING_COOLDOWN after any plan
 * that queued nothing (an activity that would not start, a walk given up, a prisoner knocked down),
 * and that blink still counts as running while anyone is on the level. Counted as asleep, it let
 * the empty-level shortcuts run in front of people: fend_for_self() had prisoners eat food and
 * change into uniforms off a hatch across the yard, without walking over.
 */
/proc/outpost_prison_ai_running(mob/living/basic/npc)
	var/datum/ai_controller/controller = npc?.ai_controller
	if(!controller || npc.stat == DEAD)
		return FALSE
	if(controller.ai_status == AI_STATUS_ON)
		return TRUE
	var/turf/here = get_turf(npc)
	if(!here || here.z > length(SSmobs.clients_by_zlevel))
		return FALSE
	return length(SSmobs.clients_by_zlevel[here.z]) > 0

/// Whether their AI is running, which it is only while someone is on the level to see them
/mob/living/basic/outpost_prisoner/proc/ai_running()
	return outpost_prison_ai_running(src)

/// Whether anything about trouble has them busy, so their routine waits: trouble itself, being talked to, cuffs going on or off, or going at a creature (outpost_prison_panic.dm)
/mob/living/basic/outpost_prisoner/proc/in_trouble()
	return trouble || threat_ref || swing_ref || climb_ref || beaten_left > 0 || talking || cuff_work || creature_foe()

/// Whether they are on their feet and able to go after a target
/mob/living/basic/outpost_prisoner/proc/trouble_can_act()
	return stat == CONSCIOUS && phase == PRISONER_PRESENT && !can_be_dragged() && !pulledby && !climb_ref

/// Rioting or breaking out, inside the cell block
/mob/living/basic/outpost_prisoner/proc/is_rioting()
	return trouble == PRISONER_TROUBLE_RIOT || trouble == PRISONER_TROUBLE_BREAKOUT

/// Whether the treasury is paid for them now: not while fighting, rioting, loose or wrecking their cell
/mob/living/basic/outpost_prisoner/proc/earning_pay()
	return !trouble

/// Whether their sentence runs: not while rioting or loose, or while an experiment under way needs them (outpost_prison_experiments.dm)
/mob/living/basic/outpost_prisoner/proc/serving_sentence()
	return !is_rioting() && trouble != PRISONER_TROUBLE_LOOSE && !prison?.held_for_experiment(src)

/// Their trouble just ended; staff finishing it off in the next few seconds are not to blame
/mob/living/basic/outpost_prisoner/proc/note_trouble_ended()
	trouble_ended_at = world.time

/// Says a line for `context`, or failing that one for `fallback`
/mob/living/basic/outpost_prisoner/proc/say_context_or(context, fallback, mob/living/basic/outpost_prisoner/other)
	if(say_context(context, other))
		return TRUE
	return fallback ? say_context(fallback, other) : FALSE

// ===== MOOD =====

/// How hard losses hit them, by personality, and harder or softer for some bounty prisoners (outpost_prison_bounty.dm)
/mob/living/basic/outpost_prisoner/proc/mood_scale()
	. = 1
	switch(personality)
		if("grumpy")
			. = 1.4
		if("nervous")
			. = 1.2
		if("quiet")
			. = 0.9
		if("cheerful")
			. = 0.7
	. *= bounty_mood_scale()

/// Changes their mood at once. Losses are scaled by personality.
/mob/living/basic/outpost_prisoner/proc/adjust_mood(amount)
	if(amount < 0)
		amount *= mood_scale()
	mood = clamp(mood + amount, 0, 100)
	return mood

/mob/living/basic/outpost_prisoner/proc/set_mood(amount)
	mood = clamp(amount, 0, 100)

/**
 * What their mood does per minute as things stand, personality included: their needs
 * (needs_mood_per_minute()), the state of the wing (wing_mood_per_minute()) and the rest below.
 * In the quiet after a riot the wing's state costs nothing and every other loss is halved.
 */
/mob/living/basic/outpost_prisoner/proc/mood_drift_per_minute()
	var/list/from_needs = needs_mood_per_minute()
	var/list/from_wing = wing_mood_per_minute()
	var/subdued = prison?.subdued_left > 0
	var/gain = from_needs[1] + from_wing[1]
	var/loss = from_needs[2]
	if(!subdued)
		loss += from_wing[2]
	// Hiding in their own cell from a creature, they wanted the door bolted (outpost_prison_panic.dm).
	if(locked_in_seconds > OUTPOST_PRISON_LOCKED_IN_COMPLAINT && !sheltering_from_creature())
		loss += PRISONER_MOOD_LOCKED_IN + round((locked_in_seconds - OUTPOST_PRISON_LOCKED_IN_COMPLAINT) / 60)
	// Cuffs kept on without good reason sour them like a lock-in (outpost_prison_capture.dm).
	if(cuffs_souring())
		loss += PRISONER_MOOD_CUFFED + round((cuffed_seconds - PRISONER_CUFFED_GRACE) / 60)
	// Bodies nobody has carried out of the cell block (outpost_prison_economy.dm)
	var/bodies = prison?.bodies_in_cell_block()
	if(bodies)
		loss += min(bodies * PRISONER_MOOD_BODY, PRISONER_MOOD_BODIES_MAX)
	if(activity?.mood_activity)
		gain += PRISONER_MOOD_ACTIVITY
	if(sentence_left <= PRISONER_RELEASE_SOON_TIME)
		gain += PRISONER_MOOD_RELEASE_SOON
	if(subdued)
		loss *= 0.5
	return gain - loss * mood_scale()

/// Time passing: their mood drifts
/mob/living/basic/outpost_prisoner/proc/drift_mood(seconds)
	if(stat == DEAD)
		return
	mood = clamp(mood + mood_drift_per_minute() * seconds / 60, 0, 100)

// ===== BEING HIT =====

/**
 * No single blow kills a prisoner on their feet: damage that would leaves them at 1 health, and
 * they collapse. A prisoner who is already down can be killed, which is always someone's choice.
 * Forced damage (admin tools) and gibbing are not spared.
 */
/mob/living/basic/outpost_prisoner/adjust_health(amount, updating_health = TRUE, forced = FALSE)
	var/spared = FALSE
	// Cuffed but on their feet still counts as on their feet.
	if(amount > 0 && !forced && stat == CONSCIOUS && phase == PRISONER_PRESENT && !is_down())
		var/health_left = maxHealth - bruteloss
		if(amount >= health_left)
			amount = max(0, health_left - 1)
			spared = TRUE
	. = ..()
	if(spared)
		INVOKE_ASYNC(src, PROC_REF(collapse))

/// Anyone on staff hitting them is noted (hit_by_staff()), and a player's blow may make them hit back (react_to_hit())
/mob/living/basic/outpost_prisoner/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)))
		return
	hit_by_staff(attacker)
	react_to_hit(attacker, stamina_only = !(attack_flags & ATTACKER_DAMAGING_ATTACK))

/// A baton hit: noted like any other, and whatever blows they were throwing stop at once
/mob/living/basic/outpost_prisoner/proc/on_batoned(datum/source, mob/living/user, obj/item/melee/baton/baton)
	SIGNAL_HANDLER
	hit_by_staff(user)
	stop_blows()
	// Still on their feet once the knockdown would have landed, they may hit back.
	react_to_hit(user, stamina_only = TRUE)
	// A stabbing or a snap they were working up to is off (outpost_prison_incidents.dm).
	prison?.wildcard_batoned(src, user)

/// Drops the shiv and pauses their attacks for PRISONER_BATON_STOP
/mob/living/basic/outpost_prisoner/proc/stop_blows()
	drop_shiv()
	baton_stop_until = world.time + PRISONER_BATON_STOP
	changeNext_move(PRISONER_BATON_STOP)

/**
 * Shots from machines (outpost turrets) put a death down to staff, but never cost mood. A machine
 * never finishes off a prisoner who is already down: its shots pass over them, so a turret stops
 * a runner and does not kill them.
 */
/mob/living/basic/outpost_prisoner/proc/on_projectile_prehit(datum/source, obj/projectile/shot)
	SIGNAL_HANDLER
	if(!shot.is_hostile_projectile() || !ismachinery(shot.firer))
		return NONE
	if(can_be_dragged())
		return PROJECTILE_INTERRUPT_HIT_PHASE
	// Someone watching may remark on a turret's shot (outpost_prison_security.dm)
	if(istype(shot.firer, /obj/machinery/porta_turret))
		prison?.note_turret_hit(src)
	hit_by_staff(shot.firer)
	return NONE

/// Whether an attacker counts as staff: people, borgs, anyone with a mind, and mechs
/mob/living/basic/outpost_prisoner/proc/is_staff_attacker(atom/attacker)
	return ismecha(attacker) || is_outpost_prison_staff(attacker)

/**
 * Whether staff hitting them now is deserved: they are fighting, rioting, breaking out, loose,
 * climbing out, wrecking their cell or swinging at staff (hitting back included), were doing so a
 * moment ago, or struck this attacker themselves in the last PRISONER_PROVOKED_TIME. Hitting back
 * at the player who started it by hitting them while calm is no excuse for that player (provoker_ref).
 */
/mob/living/basic/outpost_prisoner/proc/hit_justified(atom/attacker)
	// A guard only ever strikes violence already under way (outpost_prison_guards.dm).
	if(is_outpost_prison_guard(attacker))
		return TRUE
	if(trouble || climb_ref)
		return TRUE
	// Whoever started it gets no self-defence out of the fight they picked.
	if(provoker_ref && world.time < provoker_until && provoker_ref.resolve() == attacker)
		return FALSE
	// Coming at staff, before the first blow lands too: hitting them now is self-defence.
	if(swing_ref?.resolve())
		return TRUE
	// Working up to a stabbing or a snap (outpost_prison_incidents.dm)
	if(prison?.wildcard_brooding(src))
		return TRUE
	if(trouble_ended_at && world.time - trouble_ended_at <= PRISONER_PROVOKED_TIME)
		return TRUE
	var/atom/struck = struck_ref?.resolve()
	return struck && struck == attacker && world.time - struck_at <= PRISONER_PROVOKED_TIME

/**
 * Staff hit them. A collapse or death that follows is put down to staff. Unless the hit was
 * deserved their mood drops and the wing gets tenser, once per PRISONER_STAFF_HIT_COOLDOWN.
 * Other prisoners, creatures and NPCs are not staff. Machines (turrets) get the blame for a death
 * but do not cost mood. Returns TRUE if it cost mood.
 */
/mob/living/basic/outpost_prisoner/proc/hit_by_staff(atom/attacker)
	if(phase != PRISONER_PRESENT || is_outpost_prisoner(attacker))
		return FALSE
	var/machine = ismachinery(attacker)
	if(!machine && !is_staff_attacker(attacker))
		return FALSE
	last_staff_hit = world.time
	if(!machine)
		last_staff_attacker_ref = WEAKREF(attacker)
	last_hit_justified = machine || hit_justified(attacker)
	// A weapon's damage lands before its attacker is reported, so a collapse or death at this
	// same moment was that blow, and goes down to staff now.
	if(stat == DEAD)
		if(died_at == world.time)
			prison?.blame_death(src)
		return FALSE
	if(beaten_left > 0 && collapsed_at == world.time)
		blame_collapse()
	if(machine || !COOLDOWN_FINISHED(src, staff_hit_cooldown))
		return FALSE
	COOLDOWN_START(src, staff_hit_cooldown, PRISONER_STAFF_HIT_COOLDOWN)
	if(last_hit_justified)
		return FALSE
	adjust_mood(-PRISONER_MOOD_HIT_BY_STAFF)
	prison?.note_staff_hit(attacker, src)
	prison?.add_tension_spike(PRISON_SPIKE_STAFF_HIT)
	return TRUE

/// Whether staff hit them in the last few seconds, so what happens next is on staff
/mob/living/basic/outpost_prisoner/proc/staff_to_blame()
	return last_staff_hit && world.time - last_staff_hit <= PRISONER_STAFF_BLAME_TIME

// ===== HITTING BACK =====

/mob/living/basic/outpost_prisoner
	/// The player they are hitting back at, the same weakref as swing_ref while it lasts
	var/datum/weakref/retaliate_ref
	/// Seconds that player has been out of reach or out of sight
	var/retaliate_lost = 0
	/// Blows that land together (a baton reports its hit twice) get one reaction
	COOLDOWN_DECLARE(hit_reaction_cooldown)
	/// The player who hit them while they were calm, and the world.time until which that player's blows stay unprovoked (hit_justified())
	var/datum/weakref/provoker_ref
	var/provoker_until = 0

/datum/outpost_prison
	/// For tests: what a blow makes a calm prisoner do (PRISONER_HIT_FIGHT or _COWER) instead of rolling for it
	var/forced_hit_reaction

/**
 * A calm prisoner's odds when a player hits them, as weights: list(hit back, back off). A worse
 * mood leans to hitting back and a better one to backing off; nervous prisoners back off more,
 * grumpy ones hit back more. Neither drops below PRISONER_HIT_REACTION_MIN_WEIGHT.
 */
/proc/outpost_prisoner_hit_reaction_weights(mood, personality)
	var/shift = (PRISONER_HIT_REACTION_MID_MOOD - clamp(mood, 0, 100)) * PRISONER_HIT_REACTION_PER_MOOD
	var/fight = PRISONER_HIT_FIGHT_WEIGHT + shift
	var/cower = PRISONER_HIT_COWER_WEIGHT - shift
	if(personality == "nervous")
		cower *= PRISONER_HIT_REACTION_PERSONALITY_MULT
	else if(personality == "grumpy")
		fight *= PRISONER_HIT_REACTION_PERSONALITY_MULT
	return list(
		PRISONER_HIT_FIGHT = max(round(fight), PRISONER_HIT_REACTION_MIN_WEIGHT),
		PRISONER_HIT_COWER = max(round(cower), PRISONER_HIT_REACTION_MIN_WEIGHT),
	)

/**
 * Whether a blow from `attacker` gets a reaction: trouble is on in the wing, they are present,
 * awake, on their feet and free, and the attacker is a player. Guards, machines, mechs, creatures
 * and other prisoners are not players.
 */
/mob/living/basic/outpost_prisoner/proc/may_react_to_hit(atom/attacker)
	if(!prison?.trouble_enabled || phase != PRISONER_PRESENT || stat != CONSCIOUS || can_be_dragged() || climb_ref || beaten_left > 0)
		return FALSE
	if(!isliving(attacker) || is_outpost_prison_guard(attacker))
		return FALSE
	return is_outpost_prison_staff(attacker)

/**
 * A player's blow landed. After a stamina-only hit (a baton, a disabler) they react only if still
 * standing PRISONER_STAMINA_REACT_DELAY later, so a baton that puts them down gets nothing. The
 * reaction itself is hit_reaction(). Returns TRUE if one is coming.
 */
/mob/living/basic/outpost_prisoner/proc/react_to_hit(atom/attacker, stamina_only = FALSE)
	if(!may_react_to_hit(attacker) || !COOLDOWN_FINISHED(src, hit_reaction_cooldown))
		return FALSE
	COOLDOWN_START(src, hit_reaction_cooldown, PRISONER_HIT_REACTION_GAP)
	if(stamina_only)
		addtimer(CALLBACK(src, PROC_REF(react_after_stamina_hit), WEAKREF(attacker)), PRISONER_STAMINA_REACT_DELAY, TIMER_DELETE_ME)
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(hit_reaction), attacker)
	return TRUE

/// A stamina hit's reaction, if they are still standing
/mob/living/basic/outpost_prisoner/proc/react_after_stamina_hit(datum/weakref/attacker_ref)
	var/mob/living/attacker = attacker_ref?.resolve()
	if(QDELETED(src) || !attacker)
		return
	hit_reaction(attacker)

/**
 * What they do about a player's blow. A calm prisoner rolls (outpost_prisoner_hit_reaction_weights(),
 * or the prison's forced_hit_reaction): hit back (start_retaliation()) or back off (cower_from()).
 * One already rioting, fighting, squaring up or wrecking goes for the attacker instead, and a
 * loose one's own AI takes the attacker as its target. Returns PRISONER_HIT_FIGHT, _COWER or null.
 */
/mob/living/basic/outpost_prisoner/proc/hit_reaction(mob/living/attacker)
	if(QDELETED(src) || QDELETED(attacker) || !may_react_to_hit(attacker))
		return null
	if(trouble == PRISONER_TROUBLE_LOOSE)
		ai_controller?.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, attacker)
		return PRISONER_HIT_FIGHT
	if(trouble || threat_ref || swing_ref)
		start_retaliation(attacker, quiet = TRUE)
		return PRISONER_HIT_FIGHT
	// Hit while calm and for nothing: that player started it, whatever the prisoner does next.
	if(!last_hit_justified)
		provoker_ref = WEAKREF(attacker)
		provoker_until = world.time + PRISONER_RETALIATE_TIME SECONDS + PRISONER_PROVOKED_TIME
	// Meek bounty prisoners back off more, Wanted and Most Wanted hit back more (outpost_prison_bounty.dm).
	var/reaction = prison.forced_hit_reaction || pick_weight(bounty_hit_reaction_weights(outpost_prisoner_hit_reaction_weights(mood, personality)))
	if(reaction == PRISONER_HIT_COWER)
		cower_from(attacker)
		return PRISONER_HIT_COWER
	start_retaliation(attacker)
	return PRISONER_HIT_FIGHT

/**
 * Goes for `attacker` for PRISONER_RETALIATE_TIME: a swing at staff (swing_ref) that one blow does
 * not end, so the swing's walk and blows, and the turrets and guards that answer a swing, all
 * apply. They chase only PRISONER_RETALIATE_CHASE tiles, inside the cell block. `quiet`: already
 * in trouble, they turn on the attacker without squaring up.
 */
/mob/living/basic/outpost_prisoner/proc/start_retaliation(mob/living/attacker, quiet = FALSE)
	threat_ref = null
	threat_left = 0
	if(trouble)
		ai_controller?.CancelActions()
	else
		// end_activity() stops their walk too.
		end_activity()
		ai_controller?.CancelActions()
		stand_up()
	retaliate_ref = WEAKREF(attacker)
	retaliate_lost = 0
	swing_ref = retaliate_ref
	swing_left = PRISONER_RETALIATE_TIME
	face_atom(attacker)
	if(quiet)
		trouble_line("retaliate")
		return
	manual_emote("squares up to [attacker]!")
	say_context("retaliate")

/// Whether they are hitting back at a player now
/mob/living/basic/outpost_prisoner/proc/retaliating()
	return !!retaliate_ref && swing_ref == retaliate_ref

/// Whether `target` is close enough to go after: in sight, within PRISONER_RETALIATE_CHASE tiles, and in the cell block
/mob/living/basic/outpost_prisoner/proc/retaliation_in_reach(atom/target)
	if(!target || target.z != z || get_dist(src, target) > PRISONER_RETALIATE_CHASE || !prison?.in_cell_block(target))
		return FALSE
	return (target in view(PRISONER_RETALIATE_CHASE, src))

/**
 * Hitting back runs its course. It is over when the swing's PRISONER_RETALIATE_TIME runs out
 * (trouble_counters()) or it is called off (down, cuffed, a turret's warning, a talk), when either
 * of them is down, or once the attacker has been out of reach for PRISONER_RETALIATE_LOST_TIME.
 * Called every tick of the prison.
 */
/mob/living/basic/outpost_prisoner/proc/retaliation_tick(seconds)
	if(!retaliate_ref)
		return
	var/mob/living/attacker = retaliate_ref.resolve()
	if(!retaliating() || !attacker || attacker.stat != CONSCIOUS || stat != CONSCIOUS || can_be_dragged() || beaten_left > 0)
		end_retaliation()
		return
	if(retaliation_in_reach(attacker))
		retaliate_lost = 0
		return
	retaliate_lost += seconds
	if(retaliate_lost >= PRISONER_RETALIATE_LOST_TIME)
		end_retaliation()

/// Lets it drop: the swing ends, and they won't square up to anyone for the threat cooldown
/mob/living/basic/outpost_prisoner/proc/end_retaliation()
	if(retaliating())
		swing_ref = null
		swing_left = 0
		threat_cooldown = max(threat_cooldown, PRISONER_THREAT_COOLDOWN)
	retaliate_ref = null
	retaliate_lost = 0

/// Backs off a few tiles from `attacker` with a line, and stays there a moment
/mob/living/basic/outpost_prisoner/proc/cower_from(mob/living/attacker)
	end_activity()
	stand_up()
	face_atom(attacker)
	say_context("cower_hit")
	var/datum/prisoner_activity/cower/backing = new(src)
	backing.from_ref = WEAKREF(attacker)
	if(!backing.setup())
		qdel(backing)
		return FALSE
	start_activity(backing)
	// Nowhere to go: they cower where they stand, and the clock starts now.
	if(!backing.spot)
		backing.arrive()
	return TRUE

/// Backing off from someone who hit them: up to PRISONER_COWER_STEP tiles away from them, for PRISONER_COWER_TIME
/datum/prisoner_activity/cower
	name = "backing off"
	weight = 0
	interruptible = FALSE
	min_duration = PRISONER_COWER_TIME
	max_duration = PRISONER_COWER_TIME
	var/datum/weakref/from_ref

/datum/prisoner_activity/cower/setup()
	var/atom/from = from_ref?.resolve()
	var/turf/here = get_turf(prisoner)
	if(!from || !here)
		return FALSE
	if(!prisoner.walkable)
		prisoner.prison?.refresh_prisoner_reach(prisoner)
	var/best_distance = get_dist(here, from)
	for(var/turf/tile as anything in prisoner.walkable)
		if(get_dist(here, tile) > PRISONER_COWER_STEP || prisoner.tile_taken(tile) || !prisoner.may_loiter(tile))
			continue
		var/distance = get_dist(tile, from)
		if(distance > best_distance)
			spot = tile
			best_distance = distance
	return TRUE

// ===== BEATEN =====

/// Collapses when a hit leaves them at PRISONER_BEATEN_BELOW percent or less
/mob/living/basic/outpost_prisoner/proc/check_beaten()
	if(stat == DEAD || beaten_left > 0 || phase != PRISONER_PRESENT || !prison?.trouble_enabled)
		return FALSE
	if(health_factor() > PRISONER_BEATEN_BELOW)
		return FALSE
	collapse()
	return TRUE

/**
 * Down for `down_time` seconds, or until treated above PRISONER_RECOVER_ABOVE percent. `quiet`
 * leaves the message and line to the caller (a fighter yielding).
 */
/mob/living/basic/outpost_prisoner/proc/collapse(down_time = PRISONER_BEATEN_TIME, quiet = FALSE)
	if(stat == DEAD || beaten_left > 0)
		return
	beaten_left = down_time
	collapsed_at = world.time
	beaten_by_staff = FALSE
	if(!quiet)
		visible_message(span_danger("[src] collapses!"))
	// Being down ends whatever they were up to (on_downed()).
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEATEN_TRAIT)
	ADD_TRAIT(src, TRAIT_FLOORED, PRISONER_BEATEN_TRAIT)
	ADD_TRAIT(src, TRAIT_INCAPACITATED, PRISONER_BEATEN_TRAIT)
	update_bubble()
	if(staff_to_blame())
		blame_collapse()
	if(!quiet)
		say_context("beaten")

/// Staff beat them down. Unless they had it coming, their mood drops, and while the wing is restless it riots.
/mob/living/basic/outpost_prisoner/proc/blame_collapse()
	if(beaten_by_staff)
		return
	beaten_by_staff = TRUE
	if(last_hit_justified)
		return
	prison?.note_staff_blamed(src, "beaten")
	adjust_mood(-PRISONER_MOOD_BEATEN_BY_STAFF)
	prison?.trouble_event(PRISON_SPIKE_BEATEN, "[real_name] was beaten down by staff")

/// Gets up again
/mob/living/basic/outpost_prisoner/proc/recover()
	if(beaten_left <= 0 && !HAS_TRAIT_FROM(src, TRAIT_INCAPACITATED, PRISONER_BEATEN_TRAIT))
		return
	beaten_left = 0
	REMOVE_TRAIT(src, TRAIT_INCAPACITATED, PRISONER_BEATEN_TRAIT)
	REMOVE_TRAIT(src, TRAIT_FLOORED, PRISONER_BEATEN_TRAIT)
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEATEN_TRAIT)
	if(stat == CONSCIOUS)
		say_context("recovered")
	prison?.refresh_prisoner_reach(src)
	update_bubble()

/**
 * Knocked down, stunned, beaten, cuffed or dead: whatever trouble they were making stops. A rioter
 * drops their shiv and stops swinging, but stays a rioter until shut in a cell: up and free again,
 * they riot on (back_to_rioting()). A fight is over; a wreck stops.
 */
/mob/living/basic/outpost_prisoner/proc/on_downed()
	if(QDELETED(src))
		return
	cancel_threat()
	stop_climb(fell = TRUE)
	if(is_rioting())
		drop_shiv()
		riot_target_ref = null
		riot_target_hits = 0
		riot_victim_ref = null
	if(fight)
		prison?.end_fight(fight)
	if(trouble == PRISONER_TROUBLE_WRECK)
		prison?.stop_wreck(src)

/// Drops every kind of trouble at once, for a prisoner who died or is leaving
/mob/living/basic/outpost_prisoner/proc/clear_trouble()
	cancel_threat()
	stop_climb()
	clear_turret_reaction()
	if(fight)
		if(prison)
			prison.end_fight(fight)
		else
			QDEL_NULL(fight)
	if(trouble == PRISONER_TROUBLE_LOOSE)
		clear_outpost_patrol(src)
	trouble = null
	loose_left = 0
	wreck_left = 0
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	if(beaten_left > 0 || HAS_TRAIT_FROM(src, TRAIT_INCAPACITATED, PRISONER_BEATEN_TRAIT))
		beaten_left = 0
		REMOVE_TRAIT(src, TRAIT_INCAPACITATED, PRISONER_BEATEN_TRAIT)
		REMOVE_TRAIT(src, TRAIT_FLOORED, PRISONER_BEATEN_TRAIT)
		REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_BEATEN_TRAIT)
	update_bubble()

/**
 * Up and free again, a rioter grabs their shiv back if it lies at their feet. Returns TRUE if
 * they did. Staff who kick it away or pick it up leave them their fists.
 */
/mob/living/basic/outpost_prisoner/proc/back_to_rioting()
	if(QDELETED(src) || !is_rioting() || surrendered_to_turret() || stat != CONSCIOUS || can_be_dragged() || has_shiv() || held_item || !isturf(loc))
		return FALSE
	var/obj/item/knife/shiv/shiv = locate() in loc
	if(!shiv || !take_item(shiv))
		return FALSE
	update_melee()
	visible_message(span_warning("[src] snatches [shiv] back up!"))
	return TRUE

/// A rioter stops, when the riot is over: the shiv drops, any breakout clock stops, and they settle at PRISONER_RIOT_CALM_MOOD
/mob/living/basic/outpost_prisoner/proc/calm_down()
	if(!is_rioting())
		return
	trouble = null
	loose_left = 0
	note_trouble_ended()
	clear_turret_reaction()
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	drop_shiv()
	set_mood(PRISONER_RIOT_CALM_MOOD)
	update_melee()
	update_bubble()

/// Losing a fight: they give up and stay down for PRISONER_FIGHT_YIELD_TIME
/mob/living/basic/outpost_prisoner/proc/yield_fight()
	var/datum/outpost_prison_fight/brawl = fight
	visible_message(span_warning("[src] gives up and goes down."))
	say_context_or("fight_yield", "beaten")
	collapse(PRISONER_FIGHT_YIELD_TIME, quiet = TRUE)
	if(brawl && !QDELETED(brawl))
		prison?.end_fight(brawl)

// ===== WEAPONS =====

/// Whether they have a shiv out
/mob/living/basic/outpost_prisoner/proc/has_shiv()
	return istype(held_item, /obj/item/knife/shiv)

/// Pulls out a shiv made from who knows what, putting down whatever else they held
/mob/living/basic/outpost_prisoner/proc/draw_shiv()
	if(has_shiv())
		return held_item
	drop_held_item()
	var/obj/item/knife/shiv/shiv = new(src)
	held_item = shiv
	update_melee()
	update_appearance(UPDATE_OVERLAYS)
	return shiv

/// Drops a shiv they hold, as a real one on the floor
/mob/living/basic/outpost_prisoner/proc/drop_shiv()
	if(!has_shiv())
		return null
	var/obj/item/knife/shiv/shiv = drop_held_item()
	if(shiv)
		visible_message(span_warning("[src] drops [shiv]."))
	update_melee()
	return shiv

/**
 * Fists or a shiv, for the next blow. A shiv hits people as tg's glass shiv does in someone's hand,
 * only harder: each blow a stab or a slash (even odds) with the shiv's wound bonus, so it can leave
 * a puncture or a cut that bleeds. Fists are blunt and never wound. tg's basic mob attack
 * (/mob/living/attack_animal()) hands these vars to apply_damage(); a basic mob's wound_bonus starts
 * at CANT_WOUND, which is why a shiv never wounded anyone before. Blows at other prisoners are
 * strike()'s own and take only the verb and sound from here.
 */
/mob/living/basic/outpost_prisoner/proc/update_melee()
	if(has_shiv())
		melee_damage_lower = PRISONER_SHIV_MIN
		melee_damage_upper = PRISONER_SHIV_MAX
		wound_bonus = PRISONER_SHIV_WOUND_BONUS
		exposed_wound_bonus = PRISONER_SHIV_EXPOSED_WOUND_BONUS
		attack_sound = 'sound/items/weapons/bladeslice.ogg'
		attack_vis_effect = ATTACK_EFFECT_SLASH
		if(prob(50))
			sharpness = SHARP_POINTY
			attack_verb_continuous = "stabs"
			attack_verb_simple = "stab"
		else
			sharpness = SHARP_EDGED
			attack_verb_continuous = "slashes"
			attack_verb_simple = "slash"
	else
		melee_damage_lower = PRISONER_PUNCH_MIN
		melee_damage_upper = PRISONER_PUNCH_MAX
		wound_bonus = CANT_WOUND
		exposed_wound_bonus = 0
		attack_verb_continuous = "punches"
		attack_verb_simple = "punch"
		attack_sound = pick('sound/items/weapons/punch1.ogg', 'sound/items/weapons/punch2.ogg', 'sound/items/weapons/punch3.ogg')
		attack_vis_effect = ATTACK_EFFECT_PUNCH
		sharpness = NONE
	// Some bounty prisoners hit harder (outpost_prison_bounty.dm).
	melee_damage_lower *= bounty_damage_mult()
	melee_damage_upper *= bounty_damage_mult()

// Every blow is set up afresh, whether the trouble AI (strike()) or the breakout AI (the outpost
// patrol's melee) throws it: a new stab or slash, and never a shiv's edge on bare hands.
/mob/living/basic/outpost_prisoner/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	update_melee()
	return ..()

// ===== STRIKING =====

/**
 * What they are going for now, if they are in trouble and able: a creature they stood up to
 * (outpost_prison_panic.dm), the member of staff they decided to swing at, the other fighter, or a
 * rioter's target. Null means hold still.
 */
/mob/living/basic/outpost_prisoner/proc/trouble_target()
	if(!trouble_can_act())
		return null
	// A bounty boss winding up a riot move, running it or reeling from it holds still (outpost_prison_boss_moves.dm)
	if(boss_move_busy())
		return null
	var/mob/living/foe = creature_foe()
	if(foe)
		return foe
	var/mob/living/swing_at = swing_ref?.resolve()
	// Hitting back goes only so far (retaliation_in_reach()): past that they wait, or get on with their own trouble.
	if(swing_at && (!retaliating() || retaliation_in_reach(swing_at)))
		return swing_at
	if(trouble == PRISONER_TROUBLE_FIGHT)
		return fight?.opponent_of(src)
	if(is_rioting())
		return riot_target()
	return null

/**
 * One blow at `target`, which must be next to them: staff are hit for real, another prisoner is
 * hit but never killed, a serving hatch open on both sides is climbed, a tile (a rioter's way out
 * of the cell block) is stepped onto, and anything else is smashed. While a fight is still an
 * argument they only square up; in a riot's wind-up and after a baton hit, no blows land. Returns
 * TRUE if they acted.
 */
/mob/living/basic/outpost_prisoner/proc/confront(atom/target)
	if(QDELETED(target) || !trouble_can_act() || world.time < baton_stop_until)
		return FALSE
	if(is_rioting() && prison?.riot_windup_left > 0)
		return FALSE
	face_atom(target)
	if(fight && !fight.fighting && fight.opponent_of(src) == target)
		return FALSE
	if(!within_reach(target))
		return FALSE
	if(isturf(target))
		return step_to(src, target, 0)
	if(isliving(target))
		. = strike(target)
		// One blow ends a swing, but not hitting back (retaliation_tick()).
		if(swing_ref?.resolve() == target && !retaliating())
			swing_ref = null
			swing_left = 0
			threat_cooldown = PRISONER_THREAT_COOLDOWN
		return .
	var/obj/structure/table/reinforced/prison_hatch/hatch = target
	if(istype(hatch))
		return work_hatch(hatch)
	return smash(target)

/**
 * Whether a target is close enough to hit. A serving hatch counts from the next tile: its own
 * window door, shut, would otherwise keep them from touching the counter behind it.
 */
/mob/living/basic/outpost_prisoner/proc/within_reach(atom/target)
	if(istype(target, /obj/structure/table/reinforced/prison_hatch))
		return get_dist(src, target) <= 1
	return Adjacent(target)

/**
 * At a serving hatch, from straight in front of it on the yard side: over the counter if both
 * sides are open, otherwise another blow at its window doors.
 */
/mob/living/basic/outpost_prisoner/proc/work_hatch(obj/structure/table/reinforced/prison_hatch/hatch)
	var/turf/yard_side = hatch.yard_side_turf()
	if(!yard_side)
		return FALSE
	if(loc != yard_side)
		// Beside it on a diagonal: the way at it is from straight in front.
		return !tile_taken(yard_side) && step_to(src, yard_side, 0)
	if(hatch.both_sides_open())
		return start_climb(hatch)
	return smash(hatch)

/**
 * A punch or a stab at someone beside them. At staff it is a real attack, remembered so staff
 * hitting back is not held against them. At another prisoner it is a scuffle: PRISONER_FIGHT_HIT
 * brute, never a killing blow, and a fighter left at PRISONER_FIGHT_YIELD percent or less yields.
 */
/mob/living/basic/outpost_prisoner/proc/strike(mob/living/target)
	if(target.stat == DEAD)
		return FALSE
	update_melee()
	if(!is_outpost_prisoner(target))
		// A blow at an experiment's creature is no blow at staff (outpost_prison_panic.dm).
		if(!is_outpost_experiment_mob(target))
			struck_ref = WEAKREF(target)
			struck_at = world.time
		trouble_line("fight")
		return !!melee_attack(target)
	var/mob/living/basic/outpost_prisoner/other = target
	// Nobody puts the boot in on a prisoner who is already down, and no prisoner kills another.
	if(other.can_be_dragged())
		return FALSE
	// A shiv (a stabbing, outpost_prison_incidents.dm) hits harder than a fist, though not as hard as at staff.
	var/damage = min((has_shiv() ? rand(PRISONER_STAB_MIN, PRISONER_STAB_MAX) : rand(PRISONER_FIGHT_HIT_MIN, PRISONER_FIGHT_HIT_MAX)) * bounty_damage_mult(), other.health - 1)
	do_attack_animation(other, attack_vis_effect)
	playsound(other, attack_sound, 50, TRUE)
	other.visible_message(span_danger("[src] [attack_verb_continuous] [other]!"))
	changeNext_move(melee_attack_cooldown)
	trouble_line("fight", other)
	if(damage > 0)
		other.apply_damage(damage, BRUTE)
	if(fight && other.fight == fight && other.stat == CONSCIOUS && !other.can_be_dragged() && other.health_factor() <= PRISONER_FIGHT_YIELD)
		other.yield_fight()
	return TRUE

/**
 * A blow at a fixture, door or window beside them. A way out of the cell block is the prison's to
 * judge (hit_exit(), outpost_prison_breakout.dm). Any other door, and anything that is outpost
 * property, is only banged on: it shakes and booms but takes no damage.
 */
/mob/living/basic/outpost_prisoner/proc/smash(obj/target)
	if(!istype(target) || QDELETED(target))
		return FALSE
	do_attack_animation(target, ATTACK_EFFECT_SMASH)
	changeNext_move(melee_attack_cooldown)
	riot_target_hits++
	if(prison?.is_exit_blocker(target))
		return prison.hit_exit(src, target)
	trouble_line("riot")
	if(istype(target, /obj/machinery/light))
		var/obj/machinery/light/fixture = target
		if(fixture.status != LIGHT_BROKEN)
			fixture.break_light_tube()
		return TRUE
	if(istype(target, /obj/machinery/door) || istype(target, /obj/structure/table/reinforced/prison_hatch))
		playsound(target, 'sound/effects/bang.ogg', 50, TRUE)
		target.Shake(1, 1, 0.3 SECONDS)
		return TRUE
	if(target.resistance_flags & INDESTRUCTIBLE)
		playsound(target, 'sound/effects/bang.ogg', 40, TRUE)
		return TRUE
	// Straight damage: they keep at it, so no deflection threshold stops them.
	target.take_damage(PRISON_SMASH_DAMAGE, BRUTE, "", TRUE, get_dir(target, src))
	return TRUE

/// Now and then a line while fighting, rioting or wrecking, or one for `fallback` when `context` has none
/mob/living/basic/outpost_prisoner/proc/trouble_line(context, mob/living/basic/outpost_prisoner/other, fallback)
	if(!COOLDOWN_FINISHED(src, trouble_speech_cooldown) || !prob(35))
		return FALSE
	COOLDOWN_START(src, trouble_speech_cooldown, 8 SECONDS)
	return say_context_or(context, fallback, other)

// ===== THREATS =====

/**
 * Anyone awake who isn't a prisoner and could be on staff: people, borgs, anyone with a mind. A
 * monkey is a human by type, but only counts when a player is in it.
 */
/proc/is_outpost_prison_staff(mob/living/person)
	if(!istype(person) || is_outpost_prisoner(person) || person.stat != CONSCIOUS)
		return FALSE
	// A guard that is down, arriving or leaving is nobody's staff.
	if(is_outpost_prison_guard(person))
		return is_outpost_prison_guard(person, on_duty = TRUE)
	if(ismonkey(person) && isnull(person.mind))
		return FALSE
	return ishuman(person) || issilicon(person) || !isnull(person.mind)

/**
 * The nearest member of staff within `range` tiles who is in the cell block. `spare_helpers`
 * leaves out anyone who fed, treated or clothed them in the last PRISONER_HELPED_GRACE.
 */
/mob/living/basic/outpost_prisoner/proc/staff_nearby(range, spare_helpers = FALSE)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(range, src))
		if(!is_outpost_prison_staff(person) || !prison?.in_cell_block(person))
			continue
		if(spare_helpers && recently_helped_by(person))
			continue
		var/distance = get_dist(src, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/// Squares up to `person`: a threat, and in a few seconds maybe a swing
/mob/living/basic/outpost_prisoner/proc/threaten(mob/living/person)
	end_activity()
	stand_up()
	threat_ref = WEAKREF(person)
	threat_left = PRISONER_THREAT_TIME
	face_atom(person)
	manual_emote("squares up to [person].")
	say_context("threaten_staff")
	return TRUE

/mob/living/basic/outpost_prisoner/proc/cancel_threat()
	if(!threat_ref && !swing_ref)
		return
	threat_ref = null
	threat_left = 0
	swing_ref = null
	swing_left = 0
	threat_cooldown = max(threat_cooldown, PRISONER_THREAT_COOLDOWN / 2)

/**
 * A threat's time is up: maybe a swing. Next to them it lands at once; a tile further off, the AI
 * closes in for it. Returns TRUE if they decided to swing.
 */
/mob/living/basic/outpost_prisoner/proc/decide_swing(mob/living/person)
	threat_ref = null
	threat_left = 0
	threat_cooldown = PRISONER_THREAT_COOLDOWN
	if(mood >= (prison ? prison.threat_mood_for(src, person) : PRISONER_THREAT_MOOD) || !prob(mood < PRISONER_THREAT_ANGRY_MOOD ? PRISONER_SWING_CHANCE_ANGRY : PRISONER_SWING_CHANCE))
		return FALSE
	swing_ref = WEAKREF(person)
	swing_left = PRISONER_SWING_TIMEOUT
	if(Adjacent(person))
		confront(person)
	return TRUE

// ===== HELP AND TALK =====

/// Someone fed, treated or clothed them (or tried to): no threats at them for a while, and a threat at them ends
/mob/living/basic/outpost_prisoner/proc/note_helped(mob/living/person)
	if(!istype(person))
		return
	LAZYSET(helped_by, REF(person), world.time)
	if(threat_ref?.resolve() == person || swing_ref?.resolve() == person)
		cancel_threat()

/mob/living/basic/outpost_prisoner/proc/recently_helped_by(mob/living/person)
	var/when = LAZYACCESS(helped_by, REF(person))
	return when && world.time - when <= PRISONER_HELPED_GRACE

/// Whether they will listen to anyone right now
/mob/living/basic/outpost_prisoner/proc/will_listen()
	return !is_rioting() && trouble != PRISONER_TROUBLE_LOOSE && trouble != PRISONER_TROUBLE_WRECK && mood >= PRISONER_TALK_MIN_MOOD

/**
 * A few seconds face to face with `user`. Calms them by PRISONER_MOOD_TALK, once per
 * PRISONER_TALK_COOLDOWN; ends a threat at `user` and a fight that is still an argument. Rioters,
 * the loose, cell wreckers and anyone below PRISONER_TALK_MIN_MOOD won't listen. Returns TRUE if
 * the talk did anything.
 */
/mob/living/basic/outpost_prisoner/proc/talk_down(mob/living/user)
	if(talking || QDELETED(user))
		return FALSE
	if(!will_listen())
		face_atom(user)
		say_context("talk_refuse")
		balloon_alert(user, "not listening")
		return FALSE
	// The yard's word on this person (outpost_prison_social.dm) can turn them away.
	if(prison?.refuses_talk_from(src, user))
		return FALSE
	if(fight?.fighting)
		balloon_alert(user, "they're fighting")
		return FALSE
	var/threatening = threat_ref?.resolve() == user || swing_ref?.resolve() == user
	var/arguing = fight && !fight.fighting
	// Working up to a stabbing or a snap: a talk can always call it off (outpost_prison_incidents.dm)
	var/brooding = prison?.wildcard_brooding(src)
	if(!threatening && !arguing && !brooding && !COOLDOWN_FINISHED(src, talk_cooldown))
		balloon_alert(user, "talked out for now")
		return FALSE
	talking = TRUE
	ai_controller?.CancelActions()
	face_atom(user)
	user.face_atom(src)
	user.visible_message(span_notice("[user] talks quietly with [src]."), span_notice("You talk with [src]."))
	var/finished = do_after(user, PRISONER_TALK_TIME, target = src)
	talking = FALSE
	if(!finished || QDELETED(src) || stat != CONSCIOUS || phase != PRISONER_PRESENT)
		return FALSE
	if(!will_listen())
		say_context("talk_refuse")
		return FALSE
	face_atom(user)
	var/said = FALSE
	if(fight && !fight.fighting)
		var/mob/living/basic/outpost_prisoner/opponent = fight.opponent_of(src)
		prison?.end_fight(fight)
		said = say_context("fight_talked_down", opponent)
		prison?.add_log("[user.name] talked down a fight between [real_name] and [opponent?.real_name].")
	else if(threat_ref?.resolve() == user || swing_ref?.resolve() == user)
		cancel_threat()
		say("Fine. Fine.")
		said = TRUE
	else if(prison?.wildcard_talked_down(src, user))
		// It says its own line
		said = TRUE
	if(COOLDOWN_FINISHED(src, talk_cooldown))
		COOLDOWN_START(src, talk_cooldown, PRISONER_TALK_COOLDOWN)
		adjust_mood(prison ? prison.talk_mood_for(src, user) : PRISONER_MOOD_TALK)
		prison?.note_staff_talk(user, src)
		if(!said)
			say_context("calm_talk")
	return TRUE

// ===== CLIMBING OUT =====

/**
 * Starts over a serving hatch left open on both sides, from the yard side. Takes PRISONER_CLIMB_TIME
 * seconds: they scramble up onto the counter halfway through, then drop down on the office side.
 */
/mob/living/basic/outpost_prisoner/proc/start_climb(obj/structure/table/reinforced/prison_hatch/hatch)
	if(climb_ref || !hatch?.both_sides_open() || loc != hatch.yard_side_turf() || !trouble_can_act())
		return FALSE
	stand_up()
	climb_ref = WEAKREF(hatch)
	// A meek bounty prisoner is quicker over it (outpost_prison_bounty.dm).
	climb_left = bounty_climb_time() || PRISONER_CLIMB_TIME
	face_atom(hatch)
	// Leaning onto the counter
	var/lean = get_dir(src, hatch)
	add_offsets(PRISONER_CLIMB_OFFSET, x_add = ((lean & EAST) ? 8 : ((lean & WEST) ? -8 : 0)), y_add = ((lean & NORTH) ? 8 : ((lean & SOUTH) ? -8 : 0)))
	playsound(hatch, 'sound/effects/footstep/catwalk1.ogg', 30, TRUE)
	visible_message(span_warning("[src] starts climbing over [hatch]!"))
	return TRUE

/// Whether a climber is up on the counter
/mob/living/basic/outpost_prisoner/proc/on_hatch_counter(obj/structure/table/reinforced/prison_hatch/hatch)
	return hatch && loc == hatch.loc

/// Advances a climb: up onto the counter halfway, down the office side when the time is up; back down to the yard if a side shuts or they are stopped
/mob/living/basic/outpost_prisoner/proc/climb_tick(seconds)
	var/obj/structure/table/reinforced/prison_hatch/hatch = climb_ref?.resolve()
	if(!hatch || !hatch.both_sides_open() || stat != CONSCIOUS || can_be_dragged() || pulledby || get_dist(src, hatch) > 1)
		stop_climb(fell = TRUE)
		return FALSE
	climb_left -= seconds
	if(!on_hatch_counter(hatch) && climb_left <= PRISONER_CLIMB_TIME / 2)
		remove_offsets(PRISONER_CLIMB_OFFSET, animate = FALSE)
		hop_to(get_turf(hatch))
		playsound(hatch, 'sound/effects/footstep/catwalk1.ogg', 40, TRUE)
		visible_message(span_warning("[src] scrambles up onto [hatch]!"))
	if(climb_left > 0)
		return FALSE
	var/turf/over = hatch.staff_side_turf()
	stop_climb()
	if(!over)
		return FALSE
	hop_to(over)
	visible_message(span_warning("[src] drops down off [hatch] on the far side!"))
	return TRUE

/// Moves them onto `destination` next to them, gliding over from where they stood rather than blinking there
/mob/living/basic/outpost_prisoner/proc/hop_to(turf/destination)
	var/turf/from = get_turf(src)
	forceMove(destination)
	if(!from || loc != destination)
		return
	add_offsets(PRISONER_CLIMB_HOP_OFFSET, x_add = (from.x - destination.x) * ICON_SIZE_X, y_add = (from.y - destination.y) * ICON_SIZE_Y, animate = FALSE)
	remove_offsets(PRISONER_CLIMB_HOP_OFFSET)

/mob/living/basic/outpost_prisoner/proc/stop_climb(fell = FALSE)
	if(!climb_ref)
		return
	var/obj/structure/table/reinforced/prison_hatch/hatch = climb_ref.resolve()
	climb_ref = null
	climb_left = 0
	note_trouble_ended()
	remove_offsets(PRISONER_CLIMB_OFFSET)
	// Stopped up on the counter: back down on the yard side
	if(fell && on_hatch_counter(hatch))
		var/turf/yard_side = hatch.yard_side_turf()
		if(yard_side)
			hop_to(yard_side)
	if(fell && hatch && stat == CONSCIOUS)
		visible_message(span_notice("[src] slides back down off [hatch]."))

// ===== AI =====

/// Walks to whatever trouble has them going for and strikes it; routine waits meanwhile
/datum/ai_planning_subtree/outpost_prisoner_trouble

/datum/ai_planning_subtree/outpost_prisoner_trouble/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	if(!istype(prisoner))
		return
	// Walking away from a turret's warning comes first (outpost_prison_security.dm), then a rioter
	// running from a creature (outpost_prison_panic.dm)
	if(prisoner.plan_turret_retreat(controller) || prisoner.plan_creature_retreat(controller))
		return SUBTREE_RETURN_FINISH_PLANNING
	if(!prisoner.in_trouble())
		return
	var/atom/target = prisoner.trouble_target()
	if(target)
		controller.set_blackboard_key(BB_OUTPOST_PRISONER_TROUBLE_TARGET, target)
		controller.queue_behavior(/datum/ai_behavior/outpost_prisoner_confront, BB_OUTPOST_PRISONER_TROUBLE_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Gets next to the target, then one blow
/datum/ai_behavior/outpost_prisoner_confront
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM
	required_distance = 1

/datum/ai_behavior/outpost_prisoner_confront/setup(datum/ai_controller/controller, target_key)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	if(QDELETED(target))
		return FALSE
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	prisoner.confront_waits = 0
	set_movement_target(controller, target)

/datum/ai_behavior/outpost_prisoner_confront/perform(seconds_per_tick, datum/ai_controller/controller, target_key)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	// Broken, or something else comes first now (staff in reach, a way out opened): not a failure to
	// reach it, so a rioter can come back to the door they were breaking.
	if(QDELETED(target) || target != prisoner.trouble_target())
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	if(!prisoner.within_reach(target))
		// Close by but blocked, round a corner or behind a window door: give it a few tries.
		if(get_dist(prisoner, target) <= 1 && ++prisoner.confront_waits > 6)
			return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_FAILED
		return AI_BEHAVIOR_DELAY
	if(world.time < prisoner.next_move)
		return AI_BEHAVIOR_DELAY
	if(prisoner.fight && !prisoner.fight.fighting && prisoner.fight.opponent_of(prisoner) == target)
		// Still arguing: face them and hold.
		prisoner.face_atom(target)
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	prisoner.confront(target)
	return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED

/datum/ai_behavior/outpost_prisoner_confront/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	var/atom/target = controller.blackboard[target_key]
	controller.clear_blackboard_key(target_key)
	if(!succeeded)
		var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
		prisoner?.trouble_move_failed(target)

/// Could not get to a target: a rioter leaves it alone for a while
/mob/living/basic/outpost_prisoner/proc/trouble_move_failed(atom/target)
	if(!target)
		return
	if(riot_target_ref?.resolve() == target)
		riot_target_ref = null
		riot_target_hits = 0
	if(riot_victim_ref?.resolve() == target)
		riot_victim_ref = null
	LAZYSET(riot_skips, REF(target), world.time + 30 SECONDS)

// ===== TELEGRAPHS: ACTIVITIES =====

/// Grumbling or restless: hammering on a door they can't open
/datum/prisoner_activity/bang_door
	name = "banging on a door"
	context = "grumbling"
	leisure = TRUE
	weight = 0
	personality_weights = list("grumpy" = 1.5, "cheerful" = 0.5, "quiet" = 0.7)
	min_duration = 15 SECONDS
	max_duration = 30 SECONDS
	var/datum/weakref/door_ref
	/// Seconds to the next bang
	var/bang_left = 0

/datum/prisoner_activity/bang_door/get_weight()
	var/datum/outpost_prison/prison = prisoner.prison
	var/base = 0
	switch(prison?.stage)
		if(PRISON_STAGE_GRUMBLING)
			base = 8
		if(PRISON_STAGE_RESTLESS)
			base = 12
	if(prisoner.locked_in_seconds >= OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
		base += 6
	if(!base)
		return 0
	var/scale = personality_weights ? (personality_weights[prisoner.personality] || 1) : 1
	return base * scale

/datum/prisoner_activity/bang_door/setup()
	var/list/doors = list()
	for(var/turf/tile as anything in prisoner.reachable)
		if(prisoner.walkable[tile])
			continue
		var/obj/machinery/door/airlock/door = locate() in tile
		if(door?.density && !prisoner.prison.claimed_by_other(door, prisoner))
			doors += door
	while(length(doors))
		var/obj/machinery/door/airlock/door = pick_n_take(doors)
		var/turf/stand = prisoner.approach_turf(door)
		if(!stand || !prisoner.may_loiter(stand) || !claim(door))
			continue
		door_ref = WEAKREF(door)
		spot = stand
		return TRUE
	return FALSE

/datum/prisoner_activity/bang_door/tick(seconds)
	var/obj/machinery/door/airlock/door = door_ref?.resolve()
	if(!door || !door.density || !prisoner.Adjacent(door))
		return ACTIVITY_DONE
	prisoner.face_atom(door)
	bang_left -= seconds
	if(bang_left <= 0)
		bang_left = rand(2, 4)
		playsound(door, 'sound/effects/bang.ogg', 40, TRUE)
		door.Shake(1, 1, 0.3 SECONDS)
		if(prob(30))
			prisoner.manual_emote("bangs on [door].")
	return ..()

/// Restless: gathering with the others in the yard, eyes on the staff door. Three times as likely while a riot is brewing.
/datum/prisoner_activity/gather
	name = "gathering in the yard"
	context = "restless"
	leisure = TRUE
	weight = 0
	personality_weights = list("nervous" = 0.6, "quiet" = 0.7, "grumpy" = 1.3)
	min_duration = 20 SECONDS
	max_duration = 45 SECONDS
	var/turf/focus

/datum/prisoner_activity/gather/get_weight()
	var/datum/outpost_prison/prison = prisoner.prison
	if(prison?.stage != PRISON_STAGE_RESTLESS)
		return 0
	var/scale = personality_weights ? (personality_weights[prisoner.personality] || 1) : 1
	return 12 * scale * (prison.riot_imminent ? 3 : 1)

/datum/prisoner_activity/gather/setup()
	// The door out of the yard, or failing that wherever the others are
	for(var/turf/tile as anything in prisoner.reachable)
		if(!prisoner.walkable[tile] && (locate(/obj/machinery/door/airlock/security/prison_staff) in tile))
			focus = tile
			break
	if(!focus)
		for(var/mob/living/basic/outpost_prisoner/other in prisoner.prison.prisoners)
			if(other != prisoner && prisoner.walkable[get_turf(other)])
				focus = get_turf(other)
				break
	if(!focus)
		return FALSE
	var/list/options = list()
	for(var/turf/tile as anything in prisoner.walkable)
		if(get_dist(tile, focus) <= 2 && !prisoner.tile_taken(tile) && prisoner.may_loiter(tile) && !prisoner.prison.cell_at(tile))
			options += tile
	if(!length(options))
		return FALSE
	spot = pick(options)
	return TRUE

/datum/prisoner_activity/gather/tick(seconds)
	var/mob/living/person = prisoner.staff_nearby(7)
	prisoner.face_atom(person || focus)
	return ..()

/datum/prisoner_activity/gather/Destroy()
	focus = null
	return ..()

/// Unhappy, with a serving hatch left open on both sides: over the counter
/datum/prisoner_activity/climb_hatch
	name = "climbing out"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/hatch_ref

/datum/prisoner_activity/climb_hatch/setup()
	if(prisoner.mood >= PRISONER_CLIMB_MOOD || !prisoner.prison?.trouble_enabled)
		return FALSE
	var/obj/structure/table/reinforced/prison_hatch/hatch = prisoner.prison.open_hatch_for(prisoner)
	if(!hatch)
		return FALSE
	hatch_ref = WEAKREF(hatch)
	spot = hatch.yard_side_turf()
	return TRUE

/datum/prisoner_activity/climb_hatch/arrive()
	spot = null
	var/obj/structure/table/reinforced/prison_hatch/hatch = hatch_ref?.resolve()
	if(hatch)
		prisoner.start_climb(hatch)
	// The climb carries on outside the routine; this activity is done either way.
	return FALSE

/// Not joining a riot: back to their own cell to sit it out in its chair (or on the bed)
/datum/prisoner_activity/hide
	name = "sitting out the riot"
	context = "riot_bystander"
	leisure = FALSE
	weight = 0
	interruptible = FALSE
	var/datum/weakref/seat_ref

/datum/prisoner_activity/hide/setup()
	var/datum/outpost_prison_cell/home = prisoner.cell
	if(!home)
		return FALSE
	var/obj/structure/seat = prisoner.home_seat()
	if(seat && claim(seat))
		seat_ref = WEAKREF(seat)
		spot = get_turf(seat)
		return TRUE
	for(var/turf/tile as anything in home.turfs)
		if(prisoner.walkable?[tile] && (tile == prisoner.loc || !prisoner.tile_taken(tile)))
			spot = tile
			return TRUE
	return FALSE

/datum/prisoner_activity/hide/begin()
	started = TRUE
	ends_at = INFINITY
	if(seat_ref?.resolve())
		var/obj/machinery/door/door = prisoner.cell?.door()
		prisoner.sit_in_cell(door ? get_cardinal_dir(prisoner, door) : SOUTH)
	prisoner.say_context("riot_bystander")

/datum/prisoner_activity/hide/tick(seconds)
	if(!prisoner.prison?.riot_active)
		return ACTIVITY_DONE
	return ACTIVITY_CONTINUE

// ===== GRATITUDE =====

/**
 * Notes who fed, treated or clothed a prisoner, so they don't square up to that person straight
 * after. An element, since the prisoner's own handler for item use (outpost_prison_prisoner.dm)
 * already takes the signal.
 */
/datum/element/outpost_prisoner_gratitude

/datum/element/outpost_prisoner_gratitude/Attach(datum/target)
	. = ..()
	if(!istype(target, /mob/living/basic/outpost_prisoner))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_ATOM_ITEM_INTERACTION, PROC_REF(on_item_interaction))

/datum/element/outpost_prisoner_gratitude/Detach(datum/source, ...)
	UnregisterSignal(source, COMSIG_ATOM_ITEM_INTERACTION)
	return ..()

/datum/element/outpost_prisoner_gratitude/proc/on_item_interaction(mob/living/basic/outpost_prisoner/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(user) || user.combat_mode)
		return NONE
	if(istype(tool, /obj/item/food) || istype(tool, /obj/item/stack/medical) || istype(tool, /obj/item/clothing/under/rank/prisoner))
		source.note_helped(user)
	return NONE

#undef PRISONER_BEATEN_TRAIT
#undef PRISONER_CLIMB_OFFSET
#undef PRISONER_CLIMB_HOP_OFFSET
#undef PRISONER_STAFF_BLAME_TIME
#undef BB_OUTPOST_PRISONER_TROUBLE_TARGET
#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
