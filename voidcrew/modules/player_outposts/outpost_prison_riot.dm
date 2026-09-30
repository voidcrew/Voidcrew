/**
 * # Prison trouble, the wing's side
 *
 * Tension is 100 minus the mean mood of the prisoners in the cell block, plus spikes from events
 * (staff hitting someone unprovoked, a fight, a power cut, the lights going out, someone beaten
 * or killed by staff) that decay over a couple of minutes. It sets the wing's stage, with
 * PRISON_TENSION_HYSTERESIS points of slack on the way down so stages do not flicker:
 * - calm, below PRISON_TENSION_GRUMBLING;
 * - grumbling: complaints, pacing, banging on doors;
 * - restless: shouting at staff, gathering in the yard, threats. The warden's log says why.
 * - riot: tension held at PRISON_TENSION_RIOT for PRISON_RIOT_HOLD seconds (the crew is told a
 *   riot is brewing when the hold starts), or a spark while restless (power cut, lights out, a
 *   prisoner beaten down or killed by staff).
 * Arguments between sour prisoners (spats) and fights come before any of that.
 *
 * In a riot the wing's lights strobe red (outpost_prison_conditions.dm, not the fire alarm, so no
 * firelocks drop), an alarm sounds and the outpost is told. Rioters pull shivs and shout for a few
 * seconds before the first blow, then go for staff (two at most on one person) and try to break out:
 * they hammer at the staff doors, serving hatches and windows out of the cell block, smashing the
 * wing's fixtures on the side (outpost_prison_breakout.dm). Once through, out they go, and escape.
 * Prisoners who don't join sit it out in their cells. A rioter
 * who is stunned, beaten or cuffed drops the shiv, but riots on once up and free again. Shut in a
 * cell they go for nothing, so the cell holds them, and they owe a lockdown (outpost_prison_capture.dm).
 * The riot is over once every rioter is dealt with (riot_handled()): shut in a cell, cuffed, down,
 * dead or gone; then every rioter calms, and the wing is subdued for PRISON_SUBDUED_TIME: no riots
 * or fights, time for the crew to clean up.
 *
 * The riot's clock runs only while a member of the wing is home (crew_home()) and a rioter is
 * free, on their feet and uncuffed. Left PRISON_RIOT_BREAKOUT_TIME it turns into a breakout: every
 * rioter goes all out for the exits, and each has OUTPOST_PRISON_LOOSE_TIME seconds free before
 * they are gone for good. A riot nobody comes home to, or one whose last rioters gave up at a
 * turret's warning, is a sit-in; after PRISON_RIOT_TRANSFER_TIME the corrections service transfers
 * the rioters not yet in a cell out, for a fee.
 *
 * The cell block (outpost_prison_containment.dm) is everything prisoners can reach from the cells
 * without passing a staff door or a serving hatch. A prisoner outside it on their own feet, or
 * outside the wing in any state, has escaped: they go loose on the outpost patrol AI and have the
 * rest of their clock before they are gone for good, which fines the treasury; cuffed, the clock
 * waits. Brought back into the cell block down or cuffed, they are recaptured. A riot, its
 * breakout and its escapes are one incident, whose fines are capped together
 * (outpost_prison_economy.dm).
 *
 * A prisoner bolted into their cell long enough, and miserable enough, wrecks it; the bolts shear
 * PRISONER_WRECK_TIME seconds later and they come out rioting.
 *
 * Tests turn trouble_enabled off to test the quiet side of the prison on its own.
 */

/// Minimum time between escape announcements, so a mass breakout is one message
#define PRISON_ESCAPE_ANNOUNCE_GAP (20 SECONDS)
/// Minimum time between "a riot is brewing" announcements, when tension hovers on the line
#define PRISON_BREWING_ANNOUNCE_GAP (2 MINUTES)
/// Seconds between the lines of a spat
#define PRISON_SPAT_LINE_GAP 3

/datum/outpost_prison
	/// Whether moods turn into trouble: threats, fights, riots, escapes, collapses
	var/trouble_enabled = TRUE
	/// 0 to 100, as of the last tick
	var/tension = 0
	/// Tension from recent events, decaying
	var/tension_spike = 0
	/// PRISON_STAGE_CALM, _GRUMBLING, _RESTLESS or _RIOT
	var/stage = PRISON_STAGE_CALM
	/// Seconds tension has been at riot level
	var/riot_hold = 0
	/// Tension is at riot level and the hold is running: the console shows "riot imminent"
	var/riot_imminent = FALSE
	/// A riot is on
	var/riot_active = FALSE
	/// Seconds of shivs out and shouting left before the rioters' first blows
	var/riot_windup_left = 0
	/// The riot has turned into a breakout
	var/breaking_out = FALSE
	/// Seconds the riot has lasted while the crew was home, and while nobody was
	var/riot_elapsed = 0
	var/riot_absent = 0
	/// The crew has been told the rioters are at the doors
	var/riot_warned = FALSE
	/// Seconds left of the quiet after a riot: no riots or fights
	var/subdued_left = 0
	/// Rioters got out: an escape alarm reads as a breakout until they are dealt with
	var/broke_out = FALSE
	/// Seconds to the next riot alarm
	var/alarm_left = 0
	/// Fights going on, /datum/outpost_prison_fight
	var/list/fights = list()
	/// Seconds to the next look for a fight, and before any fight may start after the last one
	var/fight_check_left = PRISONER_FIGHT_CHECK
	var/fight_gap_left = 0
	/// A spat: the two prisoners, the lines left, seconds to the next line and before another spat
	var/datum/weakref/spat_first_ref
	var/datum/weakref/spat_second_ref
	var/spat_lines_left = 0
	var/spat_lines_said = 0
	var/spat_line_left = 0
	var/spat_gap_left = 0
	/// Whether a member of the wing was home at the last presence check
	var/crew_present = FALSE
	/// Admin and test override of crew_home(): null follows the crew, TRUE or FALSE forces it
	var/crew_home_override = null
	COOLDOWN_DECLARE(escape_announce_cooldown)
	COOLDOWN_DECLARE(restless_announce_cooldown)
	COOLDOWN_DECLARE(brewing_announce_cooldown)

// ===== THE CREW, ARRIVALS AND CONFINEMENT =====

/// Advances presence by `seconds`: works out whether a member of the wing is home
/datum/outpost_prison/proc/presence_tick(seconds)
	crew_present = find_crew_home()
	// For the extensions' intake, which waits for staff (extension_staffed())
	if(crew_home())
		last_crew_home_at = world.time

/// The z-level the wing is on, or 0
/datum/outpost_prison/proc/wing_z()
	var/list/bounds = upgrade?.footprint_bounds
	return length(bounds) >= 5 ? bounds[5] : 0

/// Whether a member of the wing (is_member()) is awake, playing and on the wing's level
/datum/outpost_prison/proc/find_crew_home()
	var/z = wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel))
		return FALSE
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || !person.client || person.stat != CONSCIOUS || is_outpost_prisoner(person))
			continue
		if(is_member(person))
			return TRUE
	return FALSE

/// Whether a member of the wing is home: awake and playing on the wing's level. Trouble's clocks wait for them.
/datum/outpost_prison/proc/crew_home()
	if(!isnull(crew_home_override))
		return crew_home_override
	return crew_present

/**
 * The mood a new arrival starts with: part of the way from PRISONER_MOOD_START to the yard's
 * mean mood, so a neglected wing sours its newcomers. `newcomer` is left out of the mean, as is
 * anyone who has not served a moment yet.
 */
/datum/outpost_prison/proc/arrival_mood(mob/living/basic/outpost_prisoner/newcomer)
	var/total = 0
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner == newcomer || prisoner.served_seconds <= 0 || !counts_for_tension(prisoner))
			continue
		total += prisoner.mood
		count++
	if(!count)
		return PRISONER_MOOD_START
	return clamp(PRISONER_MOOD_START + PRISONER_ARRIVAL_PULL * (total / count - PRISONER_MOOD_START), 0, 100)

/**
 * Advances a prisoner's confinement clock by `seconds`. Shut in their cell it counts up, unless
 * that is for their own safety, they owe lockdown, or they are hiding in their own cell from a
 * creature (sheltering_from_creature(), outpost_prison_panic.dm); out of it, it falls
 * PRISONER_LOCKED_IN_RECOVERY seconds a second, so letting them out for a moment does not reset it.
 * A rioter just shut in a cell is in custody, and owes lockdown for it (outpost_prison_capture.dm).
 */
/datum/outpost_prison/proc/update_locked_in(mob/living/basic/outpost_prisoner/prisoner, seconds)
	var/confined = prisoner.is_confined()
	if(confined)
		if(!prisoner.was_confined && prisoner.is_rioting())
			start_lockdown(prisoner)
		if(!protective_custody() && prisoner.lockdown_left <= 0 && !prisoner.sheltering_from_creature())
			prisoner.locked_in_seconds += seconds
	else
		if(prisoner.was_confined && prisoner.locked_in_seconds >= OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
			on_unbolted(prisoner)
		prisoner.locked_in_seconds = max(0, prisoner.locked_in_seconds - PRISONER_LOCKED_IN_RECOVERY * seconds)
	prisoner.was_confined = confined

/**
 * Whether shutting prisoners in their cells is for their own safety right now, so it costs
 * nothing: a riot, or someone loose and not yet caught (cuffed). An experiment is not: a prisoner
 * a creature has frightened into their own cell is spared on their own (sheltering_from_creature()).
 */
/datum/outpost_prison/proc/protective_custody()
	return riot_active || runners_at_large() > 0

/// A prisoner is let out after a long lock-in: some relief, and they say so
/datum/outpost_prison/proc/on_unbolted(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.stat != CONSCIOUS || prisoner.phase != PRISONER_PRESENT || prisoner.trouble)
		return FALSE
	prisoner.adjust_mood(PRISONER_MOOD_UNBOLTED)
	prisoner.say_context("unbolted")
	return TRUE

// ===== TENSION AND STAGES =====

/datum/outpost_prison/proc/add_tension_spike(amount)
	tension_spike = clamp(tension_spike + amount, 0, 100)

/**
 * Something happened that sets the wing on edge. While the wing is restless it is also a spark,
 * and the riot starts, unless the wing is subdued.
 */
/datum/outpost_prison/proc/trouble_event(spike, reason)
	if(!length(prisoners))
		return FALSE
	add_tension_spike(spike)
	if(trouble_enabled && !riot_active && stage == PRISON_STAGE_RESTLESS && subdued_left <= 0)
		return start_riot(reason)
	return FALSE

/**
 * Staff killed a prisoner. No fine: the cost is the worst spark there is, the pay and bonus they
 * forfeit, and a body to deal with (body_tick()).
 */
/datum/outpost_prison/proc/blame_death(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.death_blamed)
		return FALSE
	prisoner.death_blamed = TRUE
	note_staff_blamed(prisoner, "killed")
	if(!prisoner.experiment_subject)
		add_log("The yard blames staff for [prisoner.real_name]'s death.")
	return trouble_event(PRISON_SPIKE_KILLED, "[prisoner.real_name] was killed by staff")

/// Whether a prisoner's mood counts toward the wing's tension: present, alive and not loose
/datum/outpost_prison/proc/counts_for_tension(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD && prisoner.trouble != PRISONER_TROUBLE_LOOSE

/// 100 minus the mean mood of the prisoners in the cell block, plus the spike and any shivs hidden in the wing
/datum/outpost_prison/proc/compute_tension()
	var/total = 0
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!counts_for_tension(prisoner))
			continue
		total += prisoner.mood
		count++
	if(!count)
		return 0
	return clamp(100 - total / count + tension_spike + contraband_tension() + bounty_tension(), 0, 100)

/// The stage for `tension`. Coming from `previous`, a stage holds until tension falls PRISON_TENSION_HYSTERESIS below its line.
/proc/outpost_prison_stage_for(tension, previous)
	if(tension >= PRISON_TENSION_RESTLESS || (previous == PRISON_STAGE_RESTLESS && tension >= PRISON_TENSION_RESTLESS - PRISON_TENSION_HYSTERESIS))
		return PRISON_STAGE_RESTLESS
	var/was_up = previous == PRISON_STAGE_GRUMBLING || previous == PRISON_STAGE_RESTLESS
	if(tension >= PRISON_TENSION_GRUMBLING || (was_up && tension >= PRISON_TENSION_GRUMBLING - PRISON_TENSION_HYSTERESIS))
		return PRISON_STAGE_GRUMBLING
	return PRISON_STAGE_CALM

/**
 * Works out tension and the stage. Turning restless is logged with why; tension held at riot
 * level for PRISON_RIOT_HOLD seconds starts a riot, and the hold itself is announced.
 */
/datum/outpost_prison/proc/update_stage(seconds)
	var/old_stage = stage
	tension = compute_tension()
	if(riot_active)
		stage = PRISON_STAGE_RIOT
		riot_hold = 0
		riot_imminent = FALSE
		return
	stage = outpost_prison_stage_for(tension, old_stage)
	if(trouble_enabled && stage == PRISON_STAGE_RESTLESS && old_stage != PRISON_STAGE_RESTLESS && old_stage != PRISON_STAGE_RIOT)
		note_restless()
	if(!trouble_enabled || tension < PRISON_TENSION_RIOT || subdued_left > 0)
		riot_hold = 0
		riot_imminent = FALSE
		return
	if(!riot_imminent)
		riot_imminent = TRUE
		riot_brewing()
	riot_hold += seconds
	if(riot_hold >= PRISON_RIOT_HOLD)
		start_riot("tension boiled over")

/**
 * The wing turned restless: the warden's log says so, at most every PRISON_RESTLESS_ANNOUNCE_GAP.
 * Not why: the guards say the worst of it aloud (guard_report()), and prisoners answer "How are
 * you doing?".
 */
/datum/outpost_prison/proc/note_restless()
	if(!COOLDOWN_FINISHED(src, restless_announce_cooldown))
		return FALSE
	COOLDOWN_START(src, restless_announce_cooldown, PRISON_RESTLESS_ANNOUNCE_GAP)
	add_log("The prisoners are restless.")
	return TRUE

/// What the wing is unhappy about, in a few words each: "3 hungry", "dirty floor", ... For the guards' reports.
/datum/outpost_prison/proc/restless_causes()
	var/hungry = 0
	var/dirty = 0
	var/hurt = 0
	var/locked = 0
	var/cuffed = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!counts_for_tension(prisoner))
			continue
		if(prisoner.hunger < PRISONER_HUNGER_HUNGRY)
			hungry++
		if(prisoner.uniform_grime >= PRISONER_GRIME_DIRTY)
			dirty++
		if(prisoner.health_factor() < PRISONER_HURT_MOOD_BELOW)
			hurt++
		if(prisoner.locked_in_seconds > OUTPOST_PRISON_LOCKED_IN_COMPLAINT)
			locked++
		if(prisoner.cuffed_seconds > PRISONER_CUFFED_GRACE)
			cuffed++
	var/list/causes = list()
	if(hungry)
		causes += "[hungry] hungry"
	if(dirty)
		causes += "[dirty] in dirty uniforms"
	if(hurt)
		causes += "[hurt] hurt"
	var/list/conditions = conditions_payload()
	if(conditions["clean"] < PRISON_WING_MOOD_LINE)
		causes += "dirty floor"
	if(conditions["lit"] < PRISON_DARK_BELOW)
		causes += "lights out"
	else if(conditions["lit"] < PRISON_WING_MOOD_LINE)
		causes += "too dark"
	if(conditions["powered"] < 100)
		causes += "no power"
	if(locked)
		causes += "[locked] locked in"
	var/extra_cause = contraband_cause()
	if(extra_cause)
		causes += extra_cause
	causes += bounty_restless_causes()
	if(cuffed)
		causes += "[cuffed] cuffed"
	var/bodies = bodies_in_cell_block()
	if(bodies)
		causes += bodies == 1 ? "a body in the cell block" : "[bodies] bodies in the cell block"
	return causes

/// Tension reached riot level: the crew is warned, and the yard gathers at the staff door
/datum/outpost_prison/proc/riot_brewing()
	if(COOLDOWN_FINISHED(src, brewing_announce_cooldown))
		COOLDOWN_START(src, brewing_announce_cooldown, PRISON_BREWING_ANNOUNCE_GAP)
		add_log("A riot is brewing in the yard.")
		announce("Prison wing: a riot is brewing.", SHIP_NOTIFY_DANGER)
	var/shouts = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.routine_allowed() || cell_at(get_turf(prisoner)))
			continue
		// Leisure makes way, so the gathering (three times as likely now) gets picked.
		if(prisoner.activity?.leisure && !istype(prisoner.activity, /datum/prisoner_activity/gather))
			prisoner.end_activity()
		if(shouts < 2 && prisoner.ai_running() && prisoner.say_context_or("riot_imminent", "restless"))
			shouts++

/**
 * Advances trouble by `seconds`, after the prison's tick has moved needs and moods on: timers,
 * escapes, the loose clocks and recaptures, the stage, the riot, fights, spats, threats and
 * wrecked cells.
 */
/datum/outpost_prison/proc/trouble_tick(seconds)
	tension_spike = max(0, tension_spike - PRISON_SPIKE_DECAY * seconds)
	subdued_left = max(0, subdued_left - seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		prisoner.trouble_counters(seconds)
	if(trouble_enabled)
		// The clocks first, so one that starts this tick starts full.
		loose_tick(seconds)
		check_escapes(seconds)
	update_stage(seconds)
	if(!trouble_enabled)
		return
	riot_tick(seconds)
	fights_tick(seconds)
	threats_tick(seconds)
	wreck_tick(seconds)
	check_incident_over()

/// A prisoner's own trouble timers
/mob/living/basic/outpost_prisoner/proc/trouble_counters(seconds)
	threat_cooldown = max(0, threat_cooldown - seconds)
	fight_cooldown = max(0, fight_cooldown - seconds)
	if(swing_ref)
		swing_left -= seconds
		var/mob/living/target = swing_ref.resolve()
		if(swing_left <= 0 || !target || target.stat == DEAD)
			swing_ref = null
			swing_left = 0
	if(beaten_left > 0)
		beaten_left -= seconds
		if(beaten_left <= 0 || health_factor() > PRISONER_RECOVER_ABOVE)
			recover()
	if(climb_ref)
		climb_tick(seconds)

// ===== THREATS =====

/**
 * Unhappy prisoners square up to staff near them in the cell block, then maybe swing. Only while
 * their AI runs, and never at someone who just helped them. A talk with staff holds the threat.
 */
/datum/outpost_prison/proc/threats_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		// Someone in trouble keeps a swing only while hitting back at a player (outpost_prison_trouble.dm).
		// Running from a creature, staff are the least of their worries (outpost_prison_panic.dm).
		if(prisoner.phase != PRISONER_PRESENT || (prisoner.trouble && !prisoner.retaliating()) || !prisoner.trouble_can_act() || !prisoner.ai_running() || !in_cell_block(prisoner) || prisoner.is_panicking())
			prisoner.cancel_threat()
			continue
		if(prisoner.threat_ref)
			var/mob/living/person = prisoner.threat_ref.resolve()
			if(!is_outpost_prison_staff(person) || get_dist(prisoner, person) > PRISONER_THREAT_RANGE || !in_cell_block(person) || prisoner.mood >= threat_mood_for(prisoner, person) || prisoner.recently_helped_by(person))
				prisoner.cancel_threat()
				continue
			prisoner.face_atom(person)
			// A talk, or a member picking one from the talk menu (outpost_prison_warden_tools.dm), holds the threat
			if(prisoner.talking || prisoner.held_by_talk_menu())
				continue
			prisoner.threat_left -= seconds
			if(prisoner.threat_left <= 0)
				prisoner.decide_swing(person)
			continue
		if(prisoner.talking || prisoner.held_by_talk_menu() || prisoner.swing_ref || prisoner.threat_cooldown > 0 || prisoner.mood >= threat_mood_ceiling(prisoner))
			continue
		var/mob/living/nearby = prisoner.staff_nearby(PRISONER_THREAT_RANGE, spare_helpers = TRUE)
		// Who they square up to depends on who it is (outpost_prison_social.dm).
		if(nearby && prisoner.mood < threat_mood_for(prisoner, nearby))
			prisoner.threaten(nearby)

// ===== FIGHTS =====

/// Two prisoners squaring off: an argument, then blows until one yields
/datum/outpost_prison_fight
	var/datum/outpost_prison/prison
	var/mob/living/basic/outpost_prisoner/first
	var/mob/living/basic/outpost_prisoner/second
	/// What it is about, for the argument's lines: "food", "ball", "bed" or "none"
	var/cause = "none"
	/// Past the argument: blows are being thrown
	var/fighting = FALSE
	/// Seconds of arguing left, and to the next line
	var/argue_left = PRISONER_ARGUE_TIME
	var/line_left = 0
	var/first_speaks = TRUE
	/// Seconds it has lasted
	var/elapsed = 0

/datum/outpost_prison_fight/New(datum/outpost_prison/owner, mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two, cause = "none")
	. = ..()
	prison = owner
	first = one
	second = two
	src.cause = cause

/datum/outpost_prison_fight/Destroy()
	if(first?.fight == src)
		first.fight = null
	if(second?.fight == src)
		second.fight = null
	first = null
	second = null
	prison = null
	return ..()

/datum/outpost_prison_fight/proc/opponent_of(mob/living/basic/outpost_prisoner/fighter)
	if(fighter == first)
		return second
	if(fighter == second)
		return first
	return null

/// Still up for it: awake, on their feet, in this fight
/datum/outpost_prison_fight/proc/fighter_ok(mob/living/basic/outpost_prisoner/fighter)
	return !QDELETED(fighter) && fighter.stat == CONSCIOUS && fighter.phase == PRISONER_PRESENT && fighter.fight == src && fighter.trouble == PRISONER_TROUBLE_FIGHT && !fighter.can_be_dragged()

/// The argument, then the fight. FALSE once it is over.
/datum/outpost_prison_fight/proc/tick(seconds)
	if(!fighter_ok(first) || !fighter_ok(second))
		return FALSE
	elapsed += seconds
	if(elapsed >= PRISONER_FIGHT_MAX_TIME)
		return FALSE
	if(fighting)
		for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(first, second))
			if(fighter.health_factor() <= PRISONER_FIGHT_YIELD)
				fighter.yield_fight()
				return FALSE
		return TRUE
	argue_left -= seconds
	line_left -= seconds
	if(line_left <= 0)
		line_left = 3
		var/mob/living/basic/outpost_prisoner/speaker = first_speaks ? first : second
		var/mob/living/basic/outpost_prisoner/listener = opponent_of(speaker)
		first_speaks = !first_speaks
		speaker.face_atom(listener)
		speaker.say_context_or("fight_argue_[cause]", "fight_argue", listener)
	if(argue_left <= 0)
		fighting = TRUE
		first.manual_emote("goes for [second]!")
		// A scuffle on the floor is dirty work.
		for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(first, second))
			fighter.set_uniform_grime(fighter.uniform_grime + PRISONER_FIGHT_GRIME)
	return TRUE

/// Starts a fight between two prisoners over `cause`, telling everyone in sight. Returns the fight, or null.
/datum/outpost_prison/proc/start_fight(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two, cause = "none")
	if(!trouble_enabled || one == two || one.fight || two.fight || riot_active)
		return null
	var/datum/outpost_prison_fight/brawl = new(src, one, two, cause)
	fights += brawl
	for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(one, two))
		fighter.cancel_threat()
		fighter.end_activity()
		fighter.stand_up()
		fighter.trouble = PRISONER_TROUBLE_FIGHT
		fighter.fight = brawl
	one.face_atom(two)
	two.face_atom(one)
	add_tension_spike(PRISON_SPIKE_FIGHT)
	for(var/mob/living/basic/outpost_prisoner/onlooker in prisoners)
		if(onlooker == one || onlooker == two || onlooker.stat != CONSCIOUS || onlooker.phase != PRISONER_PRESENT)
			continue
		if((onlooker in view(7, one)) || (onlooker in view(7, two)))
			onlooker.adjust_mood(-PRISONER_MOOD_SAW_FIGHT)
	note_fight(one, two)
	add_log("[one.real_name] and [two.real_name] got into a fight.")
	return brawl

/// Ends a fight: the fighters cool off for PRISONER_FIGHT_COOLDOWN, and the wing for PRISON_FIGHT_GAP
/datum/outpost_prison/proc/end_fight(datum/outpost_prison_fight/brawl)
	if(QDELETED(brawl))
		return
	fights -= brawl
	fight_gap_left = PRISON_FIGHT_GAP
	for(var/mob/living/basic/outpost_prisoner/fighter as anything in list(brawl.first, brawl.second))
		if(QDELETED(fighter))
			continue
		if(fighter.fight == brawl)
			fighter.fight = null
		if(fighter.trouble == PRISONER_TROUBLE_FIGHT)
			fighter.trouble = null
			fighter.note_trouble_ended()
		fighter.fight_cooldown = PRISONER_FIGHT_COOLDOWN
		fighter.update_bubble()
	qdel(brawl)

/// Whether they are angry enough, free and able to start a fight, with someone around to see it, and no creature frightening them
/mob/living/basic/outpost_prisoner/proc/can_start_fight()
	return prison && mood < PRISONER_FIGHT_MOOD && !in_trouble() && fight_cooldown <= 0 && trouble_can_act() && health_factor() > PRISONER_FIGHT_YIELD && !activity?.sleeping && ai_running() && prison.in_cell_block(src) && !is_panicking()

/// Chasing the ball, or holding it
/mob/living/basic/outpost_prisoner/proc/after_ball()
	return istype(activity, /datum/prisoner_activity/basketball) || istype(held_item, /obj/item/toy/basketball)

/// What two prisoners would fight about: both hungry ("food"), both after the ball ("ball"), one in the other's cell ("bed"), or nothing ("none")
/datum/outpost_prison/proc/fight_cause(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(one.hunger < PRISONER_HUNGER_HUNGRY && two.hunger < PRISONER_HUNGER_HUNGRY)
		return "food"
	if(one.after_ball() && two.after_ball())
		return "ball"
	if(two.cell?.contains(one) || one.cell?.contains(two))
		return "bed"
	var/extra = fight_cause_extra(one, two)
	if(extra)
		return extra
	return "none"

/datum/outpost_prison/proc/fights_tick(seconds)
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		if(!brawl.tick(seconds))
			end_fight(brawl)
	fight_gap_left = max(0, fight_gap_left - seconds)
	spat_tick(seconds)
	if(riot_active)
		return
	fight_check_left -= seconds
	if(fight_check_left > 0)
		return
	fight_check_left = PRISONER_FIGHT_CHECK
	if(!try_start_fight())
		try_start_spat()

/**
 * One look for a fight in the wing: one fight at a time, PRISON_FIGHT_GAP after the last, none in
 * the quiet after a riot. A random pair of angry prisoners close enough to get at each other has
 * PRISONER_FIGHT_CHANCE percent, doubled when they contest the food or the ball.
 */
/datum/outpost_prison/proc/try_start_fight()
	if(!trouble_enabled || riot_active || subdued_left > 0 || length(fights) || fight_gap_left > 0)
		return null
	var/list/angry = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.can_start_fight())
			angry += prisoner
	var/list/pairs = list()
	for(var/i in 1 to length(angry) - 1)
		var/mob/living/basic/outpost_prisoner/one = angry[i]
		for(var/j in i + 1 to length(angry))
			var/mob/living/basic/outpost_prisoner/two = angry[j]
			if(get_dist(one, two) <= PRISONER_FIGHT_RANGE && one.walkable?[get_turf(two)])
				pairs += list(list(one, two))
	if(!length(pairs))
		return null
	var/list/pair = pick(pairs)
	var/cause = fight_cause(pair[1], pair[2])
	var/chance = PRISONER_FIGHT_CHANCE * extras_fight_mult(pair[1], pair[2])
	if(cause == "food" || cause == "ball")
		chance *= PRISONER_FIGHT_CONTEST_MULT
	if(!prob(chance))
		return null
	return start_fight(pair[1], pair[2], cause)

// ===== SPATS =====

/// Whether a prisoner is sour enough and free to argue, and no creature is frightening them
/datum/outpost_prison/proc/can_spat(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.phase == PRISONER_PRESENT && prisoner.mood < PRISONER_SPAT_MOOD && !prisoner.in_trouble() && prisoner.trouble_can_act() && !prisoner.activity?.sleeping && prisoner.ai_running() && !prisoner.is_panicking()

/**
 * Two sour prisoners in sight of each other trade a few words: no blows, no mood, only noise.
 * One per PRISON_SPAT_GAP in the wing. Returns TRUE if one started.
 */
/datum/outpost_prison/proc/try_start_spat()
	if(!trouble_enabled || riot_active || spat_lines_left > 0 || spat_gap_left > 0 || !prob(PRISON_SPAT_CHANCE * contraband_spat_mult()))
		return FALSE
	var/list/sour = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(can_spat(prisoner))
			sour += prisoner
	var/list/pairs = list()
	for(var/i in 1 to length(sour) - 1)
		var/mob/living/basic/outpost_prisoner/one = sour[i]
		for(var/j in i + 1 to length(sour))
			var/mob/living/basic/outpost_prisoner/two = sour[j]
			if(get_dist(one, two) <= PRISONER_FIGHT_RANGE && (two in view(PRISONER_FIGHT_RANGE, one)))
				pairs += list(list(one, two))
	if(!length(pairs))
		return FALSE
	var/list/pair = pick_spat_pair(pairs)
	spat_first_ref = WEAKREF(pair[1])
	spat_second_ref = WEAKREF(pair[2])
	note_spat(pair[1], pair[2])
	spat_lines_left = rand(2, 3)
	spat_lines_said = 0
	spat_line_left = 0
	spat_gap_left = PRISON_SPAT_GAP / (1 SECONDS)
	spat_tick(0)
	return TRUE

/// The next line of a spat, when it is due
/datum/outpost_prison/proc/spat_tick(seconds)
	spat_gap_left = max(0, spat_gap_left - seconds)
	if(spat_lines_left <= 0)
		return
	spat_line_left -= seconds
	if(spat_line_left > 0)
		return
	var/mob/living/basic/outpost_prisoner/one = spat_first_ref?.resolve()
	var/mob/living/basic/outpost_prisoner/two = spat_second_ref?.resolve()
	if(!one || !two || one.stat != CONSCIOUS || two.stat != CONSCIOUS || one.phase != PRISONER_PRESENT || two.phase != PRISONER_PRESENT || one.in_trouble() || two.in_trouble())
		spat_lines_left = 0
		return
	var/mob/living/basic/outpost_prisoner/speaker = (spat_lines_said % 2) ? two : one
	var/mob/living/basic/outpost_prisoner/listener = speaker == one ? two : one
	speaker.face_atom(listener)
	speaker.say_context("spat", listener)
	spat_lines_said++
	spat_lines_left--
	spat_line_left = PRISON_SPAT_LINE_GAP

// ===== RIOTS =====

/// Whether they are shut in a cell with its door bolted
/mob/living/basic/outpost_prisoner/proc/in_bolted_cell()
	var/datum/outpost_prison_cell/holding = prison?.cell_at(get_turf(src))
	return holding?.is_bolted()

/**
 * A rioter not yet in custody: present, alive, rioting and not shut in a cell (is_confined(), so a
 * door bolted open does not count). Down or cuffed, they are still at large, though the riot may
 * count them dealt with (riot_handled()).
 */
/mob/living/basic/outpost_prisoner/proc/riot_at_large()
	return phase == PRISONER_PRESENT && stat != DEAD && is_rioting() && !is_confined()

/// A rioter at large and free to act: on their feet, uncuffed, and not given up at a turret's warning (outpost_prison_security.dm)
/mob/living/basic/outpost_prisoner/proc/riot_free()
	return riot_at_large() && stat == CONSCIOUS && !can_be_dragged() && !surrendered_to_turret()

/**
 * Whether the riot counts them dealt with: shut in a cell, dead, calmed or loose (not rioting),
 * leaving, deleted or nowhere at all; cuffed, wherever they are; or down for real, out cold or
 * unable to act (in crit, stamina crit, collapsed or stunned). A knockdown they are straight back
 * up from is not enough. The riot is over once every rioter is (riot_tick()).
 */
/mob/living/basic/outpost_prisoner/proc/riot_handled()
	if(QDELETED(src) || isnull(get_turf(src)))
		return TRUE
	if(!riot_at_large() || cuffs)
		return TRUE
	return stat != CONSCIOUS || HAS_TRAIT(src, TRAIT_INCAPACITATED)

/**
 * Whether they can join a riot now. Not from a cell they are shut in: a riot that nobody can take
 * out of a cell would be over as soon as it began, so they bang on the door and shout instead.
 */
/mob/living/basic/outpost_prisoner/proc/can_join_riot()
	return prison && stat == CONSCIOUS && phase == PRISONER_PRESENT && !can_be_dragged() && beaten_left <= 0 && !climb_ref && (!trouble || trouble == PRISONER_TROUBLE_FIGHT) && prison.in_cell_block(src) && !is_confined()

/// Below this mood they join a riot, by personality, raised by a shiv under their mattress (outpost_prison_contraband.dm)
/mob/living/basic/outpost_prisoner/proc/riot_join_mood()
	var/line = PRISON_RIOT_JOIN_CHATTY
	switch(personality)
		if("grumpy")
			line = PRISON_RIOT_JOIN_GRUMPY
		if("quiet")
			line = PRISON_RIOT_JOIN_QUIET
		if("cheerful")
			line = PRISON_RIOT_JOIN_CHEERFUL
		if("nervous")
			line = PRISON_RIOT_JOIN_NERVOUS
	return line + (prison ? prison.riot_join_bonus(src) : 0)

/**
 * Who joins a riot: everyone below their personality's line (everyone able, for an admin riot),
 * plus `forced`, else the unhappiest alone.
 */
/datum/outpost_prison/proc/riot_candidates(everyone = FALSE, mob/living/basic/outpost_prisoner/forced)
	var/list/joining = list()
	var/mob/living/basic/outpost_prisoner/unhappiest
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!prisoner.can_join_riot())
			continue
		if(everyone || prisoner == forced || prisoner.mood < prisoner.riot_join_mood())
			joining += prisoner
		if(!unhappiest || prisoner.mood < unhappiest.mood)
			unhappiest = prisoner
	if(!length(joining) && unhappiest)
		joining += unhappiest
	return joining

/**
 * Starts a riot. `everyone` pulls in every prisoner able to riot, as the admin button does, and
 * ignores the quiet after a riot; `forced` joins whatever their mood, and with `alone` nobody else
 * does. `ignore_quiet` starts it in the quiet after a riot too, for a prisoner let out of lockdown
 * early. An experiment under way stops nothing.
 */
/datum/outpost_prison/proc/start_riot(reason, everyone = FALSE, mob/living/basic/outpost_prisoner/forced, ignore_quiet = FALSE, alone = FALSE)
	if(!trouble_enabled || riot_active)
		return FALSE
	if(!everyone && subdued_left > 0 && !ignore_quiet)
		return FALSE
	var/list/joining = (alone && forced) ? list(forced) : riot_candidates(everyone, forced)
	// A kingpin joining gives the word, and prisoners on the fence join too (outpost_prison_boss_moves.dm)
	joining = boss_kingpin_word(joining, everyone || alone)
	if(!length(joining))
		return FALSE
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		end_fight(brawl)
	riot_active = TRUE
	breaking_out = FALSE
	riot_elapsed = 0
	riot_absent = 0
	riot_warned = FALSE
	reset_exit_alerts()
	riot_hold = 0
	riot_imminent = FALSE
	riot_windup_left = PRISON_RIOT_WINDUP
	stage = PRISON_STAGE_RIOT
	open_incident()
	var/shouts = 0
	// A Most Wanted ringleader is among the first to shout (outpost_prison_bounty.dm).
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in bounty_ringleaders_first(joining))
		rioter.start_rioting(shouts++ < 2)
	send_bystanders_home(joining)
	add_log("Riot in the yard: [length(joining)] prisoner\s.")
	log_game("PLAYER OUTPOST PRISON: riot at '[outpost?.name]' ([reason])")
	play_alarm()
	announce("Riot in the prison wing!", SHIP_NOTIFY_DANGER)
	update_riot_lights()
	return TRUE

/// Joins the riot: a shiv out, everything else dropped
/mob/living/basic/outpost_prisoner/proc/start_rioting(shout = TRUE)
	cancel_threat()
	end_activity()
	stand_up()
	trouble = PRISONER_TROUBLE_RIOT
	clear_turret_reaction()
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	// A shiv they hid in their cell is the one they draw (outpost_prison_contraband.dm).
	if(!prison?.draw_stashed_shiv(src))
		draw_shiv()
	update_bubble()
	if(shout)
		say_context("riot")

/// Prisoners who stay out of a riot go back to their own cells and sit it out on the bed. Anyone running from a creature keeps running (outpost_prison_panic.dm).
/datum/outpost_prison/proc/send_bystanders_home(list/rioters)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if((prisoner in rioters) || prisoner.phase != PRISONER_PRESENT || !prisoner.routine_allowed() || prisoner.is_confined() || prisoner.is_panicking())
			continue
		var/datum/prisoner_activity/hide/hide = new(prisoner)
		if(hide.setup())
			prisoner.start_activity(hide)
		else
			qdel(hide)

/**
 * The riot's clocks. It is over once every rioter is dealt with (riot_handled()): shut in a cell,
 * cuffed, down, dead or gone, in any mix. The breakout clock runs only while the crew is home and
 * at least one rioter is free (on their feet and uncuffed); otherwise the sit-in clock runs, and
 * ends in a transfer of the rioters not yet in a cell.
 */
/datum/outpost_prison/proc/riot_tick(seconds)
	if(!riot_active)
		return
	riot_windup_left = max(0, riot_windup_left - seconds)
	var/unhandled = 0
	var/free = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.riot_handled())
			continue
		unhandled++
		if(prisoner.riot_free())
			free++
	if(!unhandled)
		end_riot()
		return
	if(crew_home() && free)
		riot_elapsed += seconds
		if(!breaking_out && !riot_warned && riot_elapsed >= PRISON_RIOT_BREAKOUT_WARNING)
			riot_warned = TRUE
			add_log("The rioters are at the doors.")
			announce("Prison wing: the rioters are at the doors.", SHIP_NOTIFY_DANGER)
		if(!breaking_out && riot_elapsed >= PRISON_RIOT_BREAKOUT_TIME)
			begin_breakout()
	else
		riot_absent += seconds
		if(riot_absent >= PRISON_RIOT_TRANSFER_TIME)
			transfer_rioters()
			return
	// Rioters starting on a door or window (outpost_prison_breakout.dm)
	exit_alert_tick(seconds)
	alarm_left -= seconds
	if(alarm_left <= 0)
		play_alarm()

/**
 * Every rioter is dealt with: every rioter, shut in a cell or anywhere else, calms to
 * PRISONER_RIOT_CALM_MOOD, the spikes clear and the wing is subdued for PRISON_SUBDUED_TIME.
 * Lockdown they owe stands (outpost_prison_capture.dm), and so do cuffs.
 */
/datum/outpost_prison/proc/end_riot()
	if(!riot_active)
		return
	riot_active = FALSE
	breaking_out = FALSE
	riot_elapsed = 0
	riot_absent = 0
	riot_warned = FALSE
	riot_hold = 0
	riot_imminent = FALSE
	riot_windup_left = 0
	tension_spike = 0
	subdued_left = PRISON_SUBDUED_TIME / (1 SECONDS)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.is_rioting())
			prisoner.calm_down()
	stage = outpost_prison_stage_for(compute_tension())
	if(loose_count())
		add_log("The rioters are out of the cell block.")
	else
		add_log("The riot is over.")
	update_riot_lights()
	check_incident_over()

/// Puts the wing in the quiet that follows a riot for `seconds`, or ends it with 0. The admin panel's hook.
/datum/outpost_prison/proc/set_subdued(seconds)
	subdued_left = max(0, seconds)
	if(subdued_left)
		riot_hold = 0
		riot_imminent = FALSE
	return subdued_left

/// The riot went on too long: the rioters go all out for the exits, and each one's loose clock starts
/datum/outpost_prison/proc/begin_breakout()
	breaking_out = TRUE
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		// Rioters who gave up at a turret's warning stay where they are (outpost_prison_security.dm)
		if(prisoner.trouble != PRISONER_TROUBLE_RIOT || prisoner.surrendered_to_turret())
			continue
		prisoner.trouble = PRISONER_TROUBLE_BREAKOUT
		prisoner.riot_target_ref = null
		prisoner.riot_target_hits = 0
		prisoner.loose_left = OUTPOST_PRISON_LOOSE_TIME
	add_log("The riot is turning into a breakout.")
	announce("The prison riot is turning into a breakout!", SHIP_NOTIFY_DANGER)

/**
 * `prisoner` breaks out on their own, the admin panel's hook: they riot (alone, if no riot is on) and
 * go straight for the ways out of the cell block with their loose clock running, as every rioter does
 * once a riot turns into a breakout. Anyone else in a riot already on carries on as before. Returns
 * TRUE if they are breaking out.
 */
/datum/outpost_prison/proc/start_breakout(mob/living/basic/outpost_prisoner/prisoner)
	if(!trouble_enabled || QDELETED(prisoner) || !(prisoner in prisoners))
		return FALSE
	if(!prisoner.is_rioting())
		if(!prisoner.can_join_riot())
			return FALSE
		if(riot_active)
			if(prisoner.fight)
				end_fight(prisoner.fight)
			prisoner.start_rioting()
		else if(!start_riot("a breakout started by an admin", forced = prisoner, ignore_quiet = TRUE, alone = TRUE))
			return FALSE
	prisoner.trouble = PRISONER_TROUBLE_BREAKOUT
	prisoner.riot_target_ref = null
	prisoner.riot_target_hits = 0
	prisoner.loose_left = OUTPOST_PRISON_LOOSE_TIME
	add_log("[prisoner.real_name] is breaking out.")
	return TRUE

/**
 * A sit-in nobody dealt with: the corrections service beams every rioter still at large out, with
 * no bonus, for OUTPOST_PRISON_TRANSFER_FEE each as part of the incident. Rioters already shut in a
 * cell stay, and calm with the end of the riot, and so does an experiment's subject
 * (held_for_experiment()). Also the admin panel's hook. Returns how many went.
 */
/datum/outpost_prison/proc/transfer_rioters()
	var/list/rioters = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.riot_at_large() && !held_for_experiment(prisoner))
			rioters += prisoner
	if(!length(rioters))
		if(riot_active)
			end_riot()
		return 0
	open_incident()
	var/charged = 0
	for(var/mob/living/basic/outpost_prisoner/rioter as anything in rioters)
		close_bounty_record(rioter, BOUNTY_RECORD_CLOSED)
		charged += charge_fine(OUTPOST_PRISON_TRANSFER_FEE, "Prisoner transfer: [rioter.real_name]", TRUE)
		note_prisoner_lost(rioter, "transferred")
		add_log("[rioter.real_name] was transferred out.")
		if(rioter.has_shiv())
			qdel(rioter.held_item)
		rioter.beam_out()
	log_game("PLAYER OUTPOST PRISON: [length(rioters)] rioter\s transferred out of '[outpost?.name]' for [charged] cr")
	announce("The corrections service transferred [length(rioters)] rioter\s out of the prison wing. The outpost was charged [charged] cr.", SHIP_NOTIFY_WARNING)
	end_riot()
	return length(rioters)

/// A serving hatch left open on both sides that this prisoner can reach from the yard side
/datum/outpost_prison/proc/open_hatch_for(mob/living/basic/outpost_prisoner/prisoner)
	for(var/obj/structure/table/reinforced/prison_hatch/hatch in fixtures_of("hatch"))
		if(QDELETED(hatch) || !hatch.both_sides_open())
			continue
		var/turf/yard_side = hatch.yard_side_turf()
		if(yard_side && prisoner.walkable?[yard_side])
			return hatch
	return null

/**
 * What a rioter goes for: nothing during the wind-up, once they gave up at a turret's warning, while
 * shut in a cell (or they would smash the cell's own window and walk out), or once out of the cell
 * block (they have escaped; check_escapes() sees to it). Then a turret they defied, staff they can
 * get to (unless two rioters are on them already), an open hatch to climb, a gap out of the cell
 * block to walk through (escape_spot()), the way out they were already breaking, the fixture they
 * were smashing for a few more blows, or a new target (pick_smash_target(),
 * outpost_prison_breakout.dm). Turret warnings are in outpost_prison_security.dm.
 */
/mob/living/basic/outpost_prisoner/proc/riot_target()
	if(!prison)
		return null
	if(prison.riot_windup_left > 0 || surrendered_to_turret() || is_confined())
		riot_victim_ref = null
		return null
	if(length(prison.cell_block) && !prison.in_cell_block(src))
		return null
	if(!reachable)
		prison.refresh_prisoner_reach(src)
	var/obj/machinery/porta_turret/defied = defied_turret()
	if(defied)
		riot_victim_ref = null
		return defied
	var/mob/living/person = staff_in_reach()
	riot_victim_ref = person ? WEAKREF(person) : null
	if(person)
		return person
	var/obj/structure/table/reinforced/prison_hatch/open_hatch = prison.open_hatch_for(src)
	if(open_hatch)
		return open_hatch
	var/turf/way_out = prison.escape_spot(src)
	if(way_out)
		riot_target_ref = WEAKREF(way_out)
		riot_target_hits = 0
		return way_out
	var/atom/current = riot_target_ref?.resolve()
	if(isobj(current) && prison.still_smashable(current, src) && (trouble == PRISONER_TROUBLE_BREAKOUT || riot_target_hits < PRISON_RIOT_TARGET_HITS || prison.is_exit_blocker(current)))
		return current
	var/atom/next = prison.pick_smash_target(src)
	riot_target_ref = next ? WEAKREF(next) : null
	riot_target_hits = 0
	return next

/// The nearest member of staff in sight that they can get to, and that no more than PRISON_RIOT_MAX_ATTACKERS - 1 others are going for
/mob/living/basic/outpost_prisoner/proc/staff_in_reach()
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in view(7, src))
		if(!is_outpost_prison_staff(person) || !reachable?[get_turf(person)])
			continue
		if(prison && prison.attackers_on(person, src) >= PRISON_RIOT_MAX_ATTACKERS)
			continue
		// A brute seems nearer and a fair hand farther (outpost_prison_social.dm).
		var/distance = prison ? prison.riot_victim_distance(src, person, get_dist(src, person)) : get_dist(src, person)
		if(distance < nearest_distance)
			nearest = person
			nearest_distance = distance
	return nearest

/// How many rioters other than `except` are going for `person`
/datum/outpost_prison/proc/attackers_on(mob/living/person, mob/living/basic/outpost_prisoner/except)
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == except || !other.is_rioting() || !other.trouble_can_act())
			continue
		if(other.riot_victim_ref?.resolve() == person)
			count++
	return count

/// Whether a rioter's target is still worth hitting
/datum/outpost_prison/proc/still_smashable(atom/target, mob/living/basic/outpost_prisoner/rioter)
	if(QDELETED(target) || !rioter.reachable?[get_turf(target)] || LAZYACCESS(rioter.riot_skips, REF(target)) > world.time)
		return FALSE
	if(istype(target, /obj/machinery/light))
		var/obj/machinery/light/fixture = target
		return fixture.status != LIGHT_BROKEN
	if(istype(target, /obj/structure/table/reinforced/prison_hatch))
		var/obj/structure/table/reinforced/prison_hatch/hatch = target
		return !hatch.both_sides_open()
	// Open or shut, a prisoner never walks through a staff door on their own.
	if(istype(target, /obj/machinery/door/airlock/security/prison_staff))
		return TRUE
	if(istype(target, /obj/machinery/door) || istype(target, /obj/structure/window) || istype(target, /obj/structure/grille))
		var/obj/blocking = target
		return blocking.density
	if(istype(target, /obj/machinery/porta_turret))
		var/obj/machinery/porta_turret/turret = target
		return !(turret.machine_stat & BROKEN)
	return TRUE

/// Whether a door is one of the wing's cell doors, or stands where one did
/datum/outpost_prison/proc/is_cell_door(obj/machinery/door/door)
	var/turf/door_turf = get_turf(door)
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.door() == door || cell.door_turf == door_turf)
			return TRUE
	return FALSE

// ===== INCIDENTS =====

/// A riot or an escape opens an incident: its fines count together from here (incident_open and the cap live in the economy file)
/datum/outpost_prison/proc/open_incident()
	begin_incident()

/// The incident is over once nobody is rioting, breaking out or loose
/datum/outpost_prison/proc/check_incident_over()
	if(!incident_open || incident_ongoing())
		return FALSE
	end_incident()
	return TRUE

// ===== WRECKED CELLS =====

/**
 * Prisoners bolted in PRISONER_WRECK_AFTER seconds at mood PRISONER_WRECK_MOOD or less start
 * wrecking their cells; wrecks under way go on. Nothing happens while their AI sleeps.
 */
/datum/outpost_prison/proc/wreck_tick(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
			continue
		if(prisoner.trouble == PRISONER_TROUBLE_WRECK)
			wreck_step(prisoner, seconds)
		else if(!prisoner.in_trouble() && prisoner.ai_running() && prisoner.locked_in_seconds >= PRISONER_WRECK_AFTER && prisoner.mood <= PRISONER_WRECK_MOOD && !prisoner.can_be_dragged() && prisoner.is_confined() && !prisoner.is_panicking())
			start_wreck(prisoner)

/**
 * A prisoner starts wrecking the cell they stand in: the cell's light breaks, the floor floods
 * and gets dirty, and they hammer on the door. The warden's log says so. Also the admin panel's hook.
 * Returns TRUE if they started.
 */
/datum/outpost_prison/proc/start_wreck(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS || prisoner.trouble)
		return FALSE
	var/datum/outpost_prison_cell/holding = cell_at(get_turf(prisoner))
	if(!holding)
		return FALSE
	prisoner.cancel_threat()
	prisoner.end_activity()
	prisoner.stand_up()
	prisoner.trouble = PRISONER_TROUBLE_WRECK
	prisoner.wreck_left = PRISONER_WRECK_TIME
	prisoner.wreck_bang_left = 0
	var/broke_light = FALSE
	for(var/turf/tile as anything in holding.turfs)
		for(var/obj/machinery/light/fixture in tile)
			if(!broke_light && fixture.status != LIGHT_BROKEN)
				fixture.break_light_tube()
				broke_light = TRUE
		var/turf/open/floor = tile
		if(istype(floor))
			floor.MakeSlippery(TURF_WET_WATER, min_wet_time = 20 SECONDS, wet_time_to_add = 10 SECONDS)
	var/turf/open/standing_on = get_turf(prisoner)
	if(istype(standing_on))
		new /obj/effect/decal/cleanable/dirt(standing_on)
	prisoner.visible_message(span_danger("[prisoner] starts wrecking the cell!"))
	prisoner.say_context_or("wreck", "locked_in")
	prisoner.update_bubble()
	add_log("[prisoner.real_name] is wrecking cell [holding.number].")
	return TRUE

/// A wreck goes on: bangs on the door every few seconds, and after PRISONER_WRECK_TIME the bolts shear
/datum/outpost_prison/proc/wreck_step(mob/living/basic/outpost_prisoner/prisoner, seconds)
	var/datum/outpost_prison_cell/holding = cell_at(get_turf(prisoner))
	if(!holding || !prisoner.is_confined())
		// Let out, or no longer in a cell: the wreck is over.
		stop_wreck(prisoner)
		return
	if(!prisoner.ai_running())
		return
	prisoner.wreck_left -= seconds
	prisoner.wreck_bang_left -= seconds
	var/obj/machinery/door/airlock/door = holding.door()
	if(prisoner.wreck_bang_left <= 0)
		prisoner.wreck_bang_left = rand(2, 4)
		if(door)
			prisoner.face_atom(door)
			playsound(door, 'sound/effects/bang.ogg', 50, TRUE)
			door.Shake(1, 1, 0.3 SECONDS)
		prisoner.trouble_line("wreck", fallback = "locked_in")
	if(prisoner.wreck_left <= 0)
		shear_bolts(prisoner, holding)

/// A wreck ends without the bolts shearing: let out, knocked down or gone
/datum/outpost_prison/proc/stop_wreck(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.trouble != PRISONER_TROUBLE_WRECK)
		return
	prisoner.trouble = null
	prisoner.wreck_left = 0
	prisoner.note_trouble_ended()
	prisoner.update_bubble()

/// The cell door gives, bolted or welded: out they come, and unless the wing is subdued they riot
/datum/outpost_prison/proc/shear_bolts(mob/living/basic/outpost_prisoner/prisoner, datum/outpost_prison_cell/holding)
	stop_wreck(prisoner)
	var/obj/machinery/door/airlock/door = holding.door()
	if(door && (door.locked || door.welded))
		if(door.locked)
			door.unbolt()
		if(door.welded)
			door.welded = FALSE
			door.update_appearance()
		door.visible_message(span_danger("The bolts of [door] shear off!"))
		playsound(door, 'sound/effects/bang.ogg', 70, TRUE)
	add_log("[prisoner.real_name] broke the bolts of cell [holding.number].")
	refresh_reach()
	if(subdued_left > 0)
		return
	if(riot_active)
		if(prisoner.can_join_riot())
			prisoner.start_rioting()
		return
	start_riot("[prisoner.real_name] broke out of cell [holding.number]", forced = prisoner)

// ===== ALARM AND ANNOUNCEMENTS =====

/// Where the wing's alarm sounds from: the warden's console, or the middle of the wing
/datum/outpost_prison/proc/alarm_turf()
	var/list/turfs = wing_turfs()
	for(var/turf/tile as anything in turfs)
		if(locate(/obj/machinery/computer/outpost_prison_warden) in tile)
			return tile
	return length(turfs) ? turfs[round(length(turfs) / 2) + 1] : null

/datum/outpost_prison/proc/play_alarm()
	alarm_left = PRISON_RIOT_ALARM_GAP
	var/turf/source = alarm_turf()
	if(source)
		playsound(source, 'sound/announcer/alarm/bloblarm.ogg', 50, FALSE, 8)

/// Tells everyone on the outpost and the owner's crew
/datum/outpost_prison/proc/announce(message, level = SHIP_NOTIFY_WARNING)
	if(QDELETED(outpost))
		return
	outpost.ship_notify(message, "PRISON", level, 'voidcrew/sound/notify.ogg', 50)

/// Prisoners on the patrol AI, still in the wing's custody
/datum/outpost_prison/proc/loose_count()
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE && prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD)
			count++
	return count

/// Loose prisoners nobody has caught yet: not cuffed. Caught ones, left cuffed somewhere, keep no protective custody going.
/datum/outpost_prison/proc/runners_at_large()
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE && prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD && !prisoner.cuffs)
			count++
	return count

/**
 * The warden console's alarm banner: list(alarm, text). In order: a breakout, an escape, a riot,
 * a riot brewing, a hatch someone is waiting at with nothing on it. The loose are named with where
 * they were last seen, three at most: "Loose: Tom Hale (Cargo Bay), and 2 more".
 */
/datum/outpost_prison/proc/alarm_state()
	var/list/sightings = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE && prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD)
			sightings += "[prisoner.real_name] ([get_area_name(prisoner)])"
	var/loose_text
	if(length(sightings) > 3)
		loose_text = "Loose: [jointext(sightings.Copy(1, 4), ", ")], and [length(sightings) - 3] more"
	else if(length(sightings))
		loose_text = "Loose: [jointext(sightings, ", ")]"
	if(breaking_out || (loose_text && broke_out))
		return list("breakout", loose_text || "Prisoners breaking out")
	if(loose_text)
		return list("escape", loose_text)
	if(riot_active)
		return list("riot", "Riot in the yard")
	if(riot_imminent)
		return list("riot_imminent", "Riot brewing")
	if(hatch_shortage())
		return list("hatch_empty", "Hatch empty")
	return list(null, null)

/// The trouble block for the admin panel and tests: the stage, tension, the riot's clocks and who is on a loose clock where
/datum/outpost_prison/proc/trouble_payload()
	var/list/loose = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD || prisoner.loose_left <= 0)
			continue
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE && prisoner.trouble != PRISONER_TROUBLE_BREAKOUT)
			continue
		loose += list(list(
			"name" = prisoner.real_name,
			"area" = get_area_name(prisoner),
			"time_left" = max(0, round(prisoner.loose_left)),
		))
	return list(
		"stage" = stage,
		"tension" = round(tension),
		"subdued_left" = subdued_left > 0 ? round(subdued_left) : null,
		"riot_imminent" = !!riot_imminent,
		"breakout_in" = (riot_active && !breaking_out) ? max(0, round(PRISON_RIOT_BREAKOUT_TIME - riot_elapsed)) : null,
		"loose" = loose,
	)

// ===== ESCAPES =====

/**
 * Anyone out of the wing, in whatever state, or outside the cell block on their own feet and
 * uncuffed, has escaped. The loose are recaptured once they are inside the cell block again, down
 * or cuffed (can_be_dragged()).
 */
/datum/outpost_prison/proc/check_escapes(seconds)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
			continue
		var/inside = in_cell_block(prisoner)
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
			if(inside && prisoner.can_be_dragged())
				recapture(prisoner)
			continue
		if(prisoner.climb_ref)
			continue
		if(get_area(prisoner) != wing)
			// Carried, dragged or knocked out, out of the wing is out.
			prisoner_escaped(prisoner)
			continue
		if(inside || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || prisoner.pulledby)
			continue
		prisoner_escaped(prisoner)

/**
 * The loose clocks of breakout rioters and loose prisoners. Once started they run whatever the
 * crew does and wherever the prisoner is, except that a caught prisoner's clock waits: a loose
 * one's while cuffed, a breakout rioter's while not free (down, cuffed or shut in a cell). With
 * PRISON_LOOSE_PING_1 seconds left the crew is told who is still loose and where; with
 * PRISON_LOOSE_PING_2 left a guard, or the wing's announcement, calls out that they are about to
 * get away (call_out_nearly_away()). Neither says how long. At 0 they are gone for good. An
 * experiment's subject (held_for_experiment()) is not: their clock stops just short of 0 and they
 * stay, loose, until the experiment is over.
 */
/datum/outpost_prison/proc/loose_tick(seconds)
	var/list/still_loose = list()
	var/list/nearly_away = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners.Copy())
		if(QDELETED(prisoner) || prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD || prisoner.loose_left <= 0)
			continue
		if(prisoner.trouble != PRISONER_TROUBLE_LOOSE && prisoner.trouble != PRISONER_TROUBLE_BREAKOUT)
			prisoner.loose_left = 0
			continue
		if(prisoner.trouble == PRISONER_TROUBLE_LOOSE ? prisoner.cuffs : !prisoner.riot_free())
			continue
		if(prisoner.loose_left <= seconds && held_for_experiment(prisoner))
			continue
		var/before = prisoner.loose_left
		prisoner.loose_left -= seconds
		if(prisoner.loose_left <= 0)
			escaped_for_good(prisoner)
			continue
		if(before > PRISON_LOOSE_PING_2 && prisoner.loose_left <= PRISON_LOOSE_PING_2)
			nearly_away += prisoner
		else if(before > PRISON_LOOSE_PING_1 && prisoner.loose_left <= PRISON_LOOSE_PING_1)
			still_loose += "[prisoner.real_name] ([get_area_name(prisoner)])"
	if(length(still_loose))
		announce("Prison wing: [english_list(still_loose)] still loose.", SHIP_NOTIFY_DANGER)
	call_out_nearly_away(nearly_away)

/**
 * Out of the cell block: loose on the outpost patrol AI, with their clock running. `breakout`
 * marks it as part of a breakout even if they were not rioting (the admin button).
 */
/datum/outpost_prison/proc/prisoner_escaped(mob/living/basic/outpost_prisoner/prisoner, breakout = FALSE)
	if(prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		return FALSE
	var/from_riot = breakout || prisoner.is_rioting()
	if(prisoner.fight)
		end_fight(prisoner.fight)
	if(prisoner.trouble == PRISONER_TROUBLE_WRECK)
		stop_wreck(prisoner)
	if(from_riot)
		broke_out = TRUE
	// Caught again, a runner from a riot (or from their lockdown) owes lockdown (outpost_prison_capture.dm).
	prisoner.escaped_rioting = from_riot || prisoner.lockdown_left > 0
	open_incident()
	prisoner.go_loose()
	add_log("[prisoner.real_name] escaped the cell block.")
	prisoner.say_context(from_riot ? "breakout" : "escape")
	if(COOLDOWN_FINISHED(src, escape_announce_cooldown))
		COOLDOWN_START(src, escape_announce_cooldown, PRISON_ESCAPE_ANNOUNCE_GAP)
		announce(from_riot ? "Prisoners are breaking out of the prison wing!" : "A prisoner has escaped the prison wing's cell block!", SHIP_NOTIFY_DANGER)
		var/turf/source = alarm_turf()
		if(source)
			playsound(source, 'sound/machines/warning-buzzer.ogg', 60, FALSE, 6)
	update_riot_lights()
	return TRUE

/// Goes loose: the outpost patrol AI takes over, and the clock starts, or carries on from the breakout
/mob/living/basic/outpost_prisoner/proc/go_loose()
	end_activity()
	stand_up()
	stop_climb()
	cancel_threat()
	riot_target_ref = null
	riot_target_hits = 0
	riot_victim_ref = null
	if(held_item && !has_shiv())
		drop_held_item()
	trouble = PRISONER_TROUBLE_LOOSE
	if(loose_left <= 0)
		loose_left = OUTPOST_PRISON_LOOSE_TIME
	// Wanted and Most Wanted bounty prisoners hit harder, and a meek one runs faster (outpost_prison_bounty.dm).
	obj_damage = PRISONER_LOOSE_OBJ_DAMAGE * bounty_breakout_mult()
	if(bounty_loose_speed())
		set_varspeed(bounty_base_speed())
	update_melee()
	update_bubble()
	// The outpost patrol AI (voidcrew/modules/npc_ships/code/outpost_patrol.dm). Finding the doors
	// yields on a big outpost, and this runs in the prison's tick on SSprocessing.
	swap_basic_ai_controller(src, /datum/ai_controller/basic_controller/outpost_breakout)
	assign_mob_to_outpost_patrol_async(src, prison?.outpost)

/// Back in the cell block, down or cuffed: in custody again, in a foul mood, and owing lockdown if they got out during a riot
/datum/outpost_prison/proc/recapture(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner.trouble != PRISONER_TROUBLE_LOOSE)
		return FALSE
	var/owes_lockdown = prisoner.escaped_rioting
	prisoner.back_in_custody()
	add_log("[prisoner.real_name] was recaptured.")
	if(owes_lockdown)
		start_lockdown(prisoner, quiet = TRUE)
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	return TRUE

/mob/living/basic/outpost_prisoner/proc/back_in_custody()
	clear_outpost_patrol(src)
	trouble = null
	loose_left = 0
	escaped_rioting = FALSE
	note_trouble_ended()
	obj_damage = initial(obj_damage)
	// A meek bounty prisoner slows back down (outpost_prison_bounty.dm).
	if(bounty_loose_speed())
		set_varspeed(bounty_base_speed())
	drop_shiv()
	set_mood(PRISONER_RECAPTURED_MOOD)
	swap_basic_ai_controller(src, /datum/ai_controller/basic_controller/outpost_prisoner)
	prison?.refresh_prisoner_reach(src)
	update_melee()
	update_bubble()
	say_context("recaptured")

/**
 * Out of time: gone for good, walls or no walls. No bonus; the treasury is fined
 * OUTPOST_PRISON_ESCAPE_FINE as part of the incident, and the corrections service counts them lost.
 */
/datum/outpost_prison/proc/escaped_for_good(mob/living/basic/outpost_prisoner/prisoner)
	close_bounty_record(prisoner, BOUNTY_RECORD_ESCAPED)
	var/fine = charge_fine(OUTPOST_PRISON_ESCAPE_FINE, "Prison escape fine: [prisoner.real_name]", TRUE)
	note_prisoner_lost(prisoner, "escaped")
	add_log("[prisoner.real_name] got away. Fined [fine] cr.")
	announce("[prisoner.real_name] has escaped custody. The outpost was fined [fine] cr.", SHIP_NOTIFY_WARNING)
	if(prisoner.has_shiv())
		qdel(prisoner.held_item)
	prisoner.beam_out()
	if(!loose_count() && !riot_active)
		broke_out = FALSE
	update_riot_lights()
	return fine

// ===== TURRETS =====

/**
 * The hull defense turret's rule (is_hostile_creature()): it leaves prisoners in their wing alone,
 * rioting or not, and treats a loose prisoner outside the wing as fair game until they are down, so
 * a runner is stopped rather than killed. Turrets players build follow outpost_prison_security.dm.
 */
/mob/living/basic/outpost_prisoner/proc/turret_target()
	if(stat == DEAD || trouble != PRISONER_TROUBLE_LOOSE || phase != PRISONER_PRESENT || can_be_dragged())
		return FALSE
	return !prison || get_area(src) != prison.wing

/proc/is_loose_outpost_prisoner(mob/living/creature)
	var/mob/living/basic/outpost_prisoner/prisoner = creature
	return istype(prisoner) && prisoner.turret_target()

// ===== SERVING HATCH =====

/// Where someone climbing over from the yard comes down: the tile beyond the staff side
/obj/structure/table/reinforced/prison_hatch/proc/staff_side_turf()
	var/obj/machinery/door/window/staff_door = staff_windoor()
	if(staff_door)
		return get_step(src, staff_door.dir)
	// The office side smashed out (outpost_prison_breakout.dm): the far side from the yard
	var/obj/machinery/door/window/yard_door = yard_windoor()
	var/facing = yard_door ? yard_door.dir : yard_dir
	return facing ? get_step(src, REVERSE_DIR(facing)) : null

/// Every window door left on it opens, and stays open until someone shuts it. Rioters do this by smashing the office side (take_rioter_blow()).
/obj/structure/table/reinforced/prison_hatch/proc/force_open()
	for(var/obj/machinery/door/window/windoor in loc)
		windoor.autoclose = FALSE
		if(windoor.density)
			INVOKE_ASYNC(windoor, TYPE_PROC_REF(/obj/machinery/door/window, open), BYPASS_DOOR_CHECKS)

#undef PRISON_ESCAPE_ANNOUNCE_GAP
#undef PRISON_BREWING_ANNOUNCE_GAP
#undef PRISON_SPAT_LINE_GAP
