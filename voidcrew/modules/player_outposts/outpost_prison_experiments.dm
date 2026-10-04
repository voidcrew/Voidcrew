/**
 * # Prison wing experiments
 *
 * The researcher who visits the wing with serums and specimens, and what comes of them. Numbers
 * are in voidcrew/_DEFINES/outpost_prison_experiments.dm, which also defines OUTPOST_EXPERIMENT_API.
 *
 * - The researcher (outpost_prison_researcher.dm) comes 15-25 minutes after the wing's first
 *   arrival, then 35-50 minutes after each experiment ends or offer is turned down, if the wing
 *   passes the gates (researcher_gate_failure()). A manager takes the offer or declines it.
 * - The serum, the specimen jar and the food it taints (outpost_prison_serum.dm) only work in a
 *   member's hands, on this wing's prisoners, for 10 minutes, and never leave the level.
 * - A serum subject twitches for a minute, with the form's tells in the last 40 seconds, then
 *   turns into a hulk, a fly person or a nightmare (outpost_prison_creatures.dm). A specimen host
 *   goes to the changeling event (outpost_changeling_infect(), outpost_prison_changeling.dm).
 * - The wing is paid a fee when a creature shows (experiment_creature_appeared()) and a bonus when
 *   it is put down (experiment_creature_down()) if the crew did half its damage or more
 *   (/datum/component/experiment_damage_ledger). Each is paid once per experiment. Put down, it
 *   lies there, "awaiting pickup" on the console, until Kessler's team beams in for it (kessler_collect()).
 * - A creature stays until the crew puts it down or an admin ends the experiment. One that gets out
 *   of the wing sets off the containment breach alarm. One taken off the outpost (onto a ship, say)
 *   is recovered by Kessler at once, for a fee that becomes debt (experiment_recover()). The one
 *   exception is the changeling's horror, down and regenerating, out in open space: it dies there
 *   for good, which puts it down (outpost_prison_horror.dm).
 * - The dosed subject or the specimen's host is the experiment's until it ends
 *   (held_for_experiment()): not released, transferred, beamed out as escaped or dropped from the roster dead.
 * - An experiment pauses no trouble: riots, fights, incidents and wing events go on as ever. A
 *   creature frightens the prisoners it threatens, who run from it (outpost_prison_panic.dm). When
 *   it ends, everyone who saw a prisoner die loses mood and each death adds tension.
 * Every clock here counts only while a member of the wing is home (crew_home()).
 */

/mob/living/basic/outpost_prisoner
	/// Dosed or carrying a specimen: their death is the experiment's, not staff's
	var/experiment_subject = FALSE

/datum/outpost_prison
	/// The experiment under way, or just ended (the console shows the result for a while)
	var/datum/outpost_experiment/experiment
	/// The researcher, while visiting with an offer
	var/mob/living/basic/outpost_kessler_staff/researcher/researcher
	/// Crew-home seconds until the researcher is due; null before the first arrival and while an offer, item or experiment is out
	var/researcher_wait
	/// The researcher's visits have been scheduled: the wing has had its first arrival
	var/visits_started = FALSE
	/// Offers made in this wing; the first is never a specimen
	var/offers_made = 0
	/// Share added to the next offer's pay by offers declined or ignored since the last one taken
	var/sweetener = 0
	/// The visiting researcher's offer: "serum" or "specimen", and the form it will turn out to be
	var/offer_kind
	var/offer_form
	/// Crew-home seconds the researcher has waited
	var/researcher_stay = 0
	/// Seconds to the researcher's next pitch
	var/pitch_left = 0
	/// The manager reading the offer. Claimed before the prompt, so two managers cannot both take it.
	var/datum/weakref/offer_claim
	/// The researcher has already turned up their nose at the wing's state for this visit
	var/pigsty_shown = FALSE
	/// The pay multiplier of the offer taken, for the experiment its item starts
	var/pending_multiplier = 1
	/// Weakrefs to the serum, the specimen jar and tainted food out now
	var/list/experiment_items = list()

/// Whether an experiment is under way in the wing: from the dose until it is contained or fails
/datum/outpost_prison/proc/experiment_active()
	return !!experiment && !experiment.resolved

/// Whether a creature is loose in the experiment under way
/datum/outpost_prison/proc/creature_live()
	return experiment_active() && length(experiment.live_creatures())

/// The changeling event of the experiment under way, for the admin panel's stage buttons
/datum/outpost_prison/proc/changeling_event()
	return experiment?.changeling

// ===== THE CLOCK =====

/**
 * Advances the researcher's visits and any live experiment by `seconds`. The items' lives run in
 * real time; everything else waits while nobody from the wing is home.
 */
/datum/outpost_prison/proc/experiments_tick(seconds)
	var/home = crew_home()
	items_tick()
	if(experiment)
		if(experiment.resolved)
			experiment.result_left -= seconds
			if(experiment.result_left <= 0)
				clear_experiment()
		else
			experiment_tick(seconds, home)
	researcher_tick(seconds, home)
	creature_panic_tick(seconds)

/// The experiment under way: the subject, the twitch, the changeling's stages and the creatures
/datum/outpost_prison/proc/experiment_tick(seconds, home)
	var/datum/outpost_experiment/current = experiment
	current.follow_changeling()
	if(current.stage in list("dosed", "twitching", "incubating"))
		if(!subject_tick(seconds, home))
			return
	if(QDELETED(current) || current.resolved)
		return
	if(current.stage in list("dosed", "twitching"))
		twitch_tick(seconds, home)
		return
	creatures_tick(seconds, home)

/**
 * The dosed subject or host: gone before the change, and the experiment fails; outside the cell
 * block, and it waits, failing after OUTPOST_EXPERIMENT_OUTSIDE_LIMIT seconds. Returns TRUE if the
 * experiment goes on this tick. A changeling host who died is the changeling event's business: it
 * bursts from the body.
 */
/datum/outpost_prison/proc/subject_tick(seconds, home)
	var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
	if(!subject || subject.prison != src || subject.phase != PRISONER_PRESENT)
		experiment_failed("the subject is gone")
		return FALSE
	if(subject.stat == DEAD)
		return experiment.form == "changeling"
	if(!home)
		return FALSE
	if(get_area(subject) == wing && in_cell_block(subject))
		experiment.outside_seconds = 0
		return TRUE
	experiment.outside_seconds += seconds
	if(experiment.outside_seconds >= OUTPOST_EXPERIMENT_OUTSIDE_LIMIT)
		experiment_failed("the subject was taken out of the cell block")
	return FALSE

/// Whether the dosed subject's or host's clocks wait: nobody home, or the subject out of the cell block. For the changeling event.
/datum/outpost_prison/proc/experiment_paused()
	if(!experiment_active() || !crew_home())
		return TRUE
	var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
	return subject && subject.stat != DEAD && (get_area(subject) != wing || !in_cell_block(subject))

/// A minute of twitching, then the change. The form's tells show in the last OUTPOST_EXPERIMENT_TELLS seconds.
/datum/outpost_prison/proc/twitch_tick(seconds, home)
	if(!home)
		return
	var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
	experiment.twitch_left -= seconds
	experiment.stage = experiment.twitch_left > OUTPOST_EXPERIMENT_TELLS ? "dosed" : "twitching"
	if(experiment.twitch_left <= 0)
		transform_subject()
		return
	experiment.effect_left -= seconds
	if(experiment.effect_left > 0 || subject.stat != CONSCIOUS)
		return
	if(experiment.stage == "twitching")
		experiment.effect_left = rand(4, 6)
		var/progress = clamp(1 - experiment.twitch_left / OUTPOST_EXPERIMENT_TELLS, 0, 1)
		outpost_experiment_tell(experiment.form, subject, progress)
	else
		experiment.effect_left = rand(5, 8)
		subject.Shake(1, 1, 0.5 SECONDS)
		if(prob(40))
			subject.manual_emote(pick("twitches.", "shudders.", "scratches at [subject.p_their()] arm."))
		else
			subject.say_context("experiment_dose")

/// The serum takes: the subject becomes the creature where they stand
/datum/outpost_prison/proc/transform_subject()
	var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
	var/creature_type = outpost_experiment_creature_type(experiment.form)
	var/turf/spot = get_turf(subject)
	if(!subject || !creature_type || !spot)
		experiment_failed("the serum did not take")
		return null
	var/mob/living/basic/outpost_experiment/creature = new creature_type(spot, src, subject)
	add_log("[subject.real_name] turned into [creature.form_name].")
	log_game("PLAYER OUTPOST PRISON: [subject.real_name] turned into [creature.form_name] at '[outpost?.name]' [AREACOORD(spot)]")
	experiment.subject_ref = null
	qdel(subject)
	experiment_creature_appeared(creature, experiment.form)
	return creature

/**
 * The creatures and the leash. A creature off the outpost is recovered at once (for the fee only
 * if it walked while the crew was home), except the horror's body, down in open space, which dies
 * there for good instead. One out of the wing sets off the containment breach alarm, once.
 * Otherwise they stay until they are put down. A specimen whose creatures are all gone without
 * being put down (deleted outright) has failed.
 */
/datum/outpost_prison/proc/creatures_tick(seconds, home)
	var/list/live = experiment.live_creatures()
	if(!length(live))
		if(experiment.form != "changeling")
			if(!length(experiment.creature_refs))
				experiment_failed("the creature is gone")
		else if(QDELETED(experiment.changeling) || experiment.changeling.stage == "done")
			experiment_failed("the specimen is gone")
		return
	var/out_of_wing = FALSE
	for(var/mob/living/creature as anything in live)
		if(!outpost_holds(creature))
			// Its own move into space (on_moved()) usually got there first; this catches the rest.
			var/mob/living/basic/outpost_experiment/horror/spaced = creature
			if(istype(spaced) && spaced.die_if_spaced())
				return
			var/carried = !isturf(creature.loc) || !!creature.pulledby || !!creature.buckled
			add_log("[creature.name] was taken off the outpost.")
			// With nobody home to stop it, a visitor who led it onto their ship does not bill the owner.
			experiment_recover(charge = !carried && home)
			return
		if(get_area(creature) != wing)
			out_of_wing = TRUE
	if(out_of_wing && !experiment.breach_announced)
		experiment.breach_announced = TRUE
		add_log("An experiment creature got out of the wing.")
		announce("CONTAINMENT BREACH: the Kessler specimen has left the prison wing.", SHIP_NOTIFY_DANGER)

/// Whether a creature is still on the outpost's own ground: its areas, not a docked ship or open space
/datum/outpost_prison/proc/outpost_holds(atom/movable/creature)
	var/area/place = get_area(creature)
	if(!istype(place, /area/voidcrew/player_outpost))
		return FALSE
	if(place == wing)
		return TRUE
	return get_outpost_from_atom(creature) == outpost

// ===== STARTING =====

/**
 * Starts an experiment on `subject`: "hulk", "fly" or "nightmare" (a serum) or "changeling" (a
 * specimen, handed to outpost_changeling_infect()). The serum and the specimen call it, and so
 * does the admin panel with `forced`, which skips the cell block rule. One experiment at a time,
 * on a living prisoner of this wing. Returns TRUE if it started.
 */
/datum/outpost_prison/proc/start_experiment(form, mob/living/basic/outpost_prisoner/subject, forced = FALSE)
	if(!(form in list("hulk", "fly", "nightmare", "changeling")))
		return FALSE
	if(QDELETED(subject) || subject.prison != src || subject.phase != PRISONER_PRESENT || subject.stat == DEAD)
		return FALSE
	// Kessler won't touch a bounty prisoner: who they were would be lost (outpost_prison_bounty.dm).
	if(bounty_experiment_refusal(subject))
		return FALSE
	if(experiment_active())
		return FALSE
	if(!forced && (subject.trouble == PRISONER_TROUBLE_LOOSE || !in_cell_block(subject)))
		return FALSE
	if(experiment)
		clear_experiment()
	experiment = new(src, form, subject)
	experiment.multiplier = forced ? 1 : pending_multiplier
	experiment.forced = forced
	pending_multiplier = 1
	researcher_wait = null
	if(researcher)
		researcher.leave()
	subject.experiment_subject = TRUE
	subject.update_bubble()
	add_log(form == "changeling" ? "[subject.real_name] ate the Kessler specimen." : "[subject.real_name] was given the Kessler serum.")
	log_game("PLAYER OUTPOST PRISON: experiment ([form][forced ? ", forced" : ""]) started on [subject.real_name] at '[outpost?.name]'")
	if(form == "changeling")
		experiment.stage = "incubating"
		experiment.changeling = outpost_changeling_infect(subject, src)
	else
		experiment.stage = "dosed"
		experiment.twitch_left = OUTPOST_EXPERIMENT_TWITCH
		experiment.effect_left = rand(3, 5)
		INVOKE_ASYNC(subject, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "experiment_dose")
	return TRUE

// ===== CREATURES AND PAY =====

/**
 * A creature showed: the serum's result, the headslug at the burst, or the horror. The first one
 * pays the fee. Anyone it frightens runs at once (creature_panic_tick()), and its death is watched;
 * the horror going down to regenerate is not one. `form` is the experiment's ("hulk", "fly", "nightmare",
 * "changeling") or the creature's ("headslug", "horror"). Returns TRUE if it is tracked.
 */
/datum/outpost_prison/proc/experiment_creature_appeared(mob/living/creature, form)
	if(QDELETED(creature) || !isliving(creature))
		return FALSE
	if(!experiment_active())
		// Not from an experiment (an admin spawn): tracked as one, without the researcher's sweetener.
		if(experiment)
			clear_experiment()
		experiment = new(src, outpost_experiment_family(form), null)
		experiment.forced = TRUE
		researcher_wait = null
	var/kind = outpost_experiment_creature_kind(creature, form)
	var/key = REF(creature)
	if(experiment.creature_refs[key])
		return TRUE
	experiment.creature_refs[key] = WEAKREF(creature)
	experiment.creature_kinds[key] = kind
	experiment.revealed = TRUE
	creature.AddComponent(/datum/component/experiment_damage_ledger)
	RegisterSignal(creature, COMSIG_LIVING_DEATH, PROC_REF(on_creature_death))
	RegisterSignal(creature, COMSIG_QDELETING, PROC_REF(on_creature_deleted))
	experiment.stage = kind == "horror" ? "horror" : "live"
	if(!experiment.fee_done)
		experiment.fee_done = TRUE
		var/fee = round(outpost_experiment_fee(experiment.form) * experiment.multiplier)
		if(pay_treasury(fee, "Kessler Biolabs data fee"))
			experiment.fee_paid = fee
			add_log("Kessler Biolabs paid a [fee] cr data fee.")
	creature_panic_tick(0)
	return TRUE

/**
 * A creature was put down: killed, or `subdued` alive (worn out on stamina). Pays the containment
 * bonus, once per experiment, if players did at least OUTPOST_EXPERIMENT_PLAYER_SHARE of its
 * damage. It lies there, and the console shows it awaiting pickup, until Kessler's team comes for
 * it OUTPOST_EXPERIMENT_PICKUP seconds later. With no creature left the experiment is over.
 * Returns TRUE if it counted.
 */
/datum/outpost_prison/proc/experiment_creature_down(mob/living/creature, subdued = FALSE)
	if(!experiment || !creature)
		return FALSE
	var/key = REF(creature)
	if(!experiment.creature_refs[key] || experiment.downed[key])
		return FALSE
	experiment.downed[key] = TRUE
	experiment.awaiting[key] = subdued ? "subdued" : "down"
	var/kind = experiment.creature_kinds[key]
	if(!experiment.bonus_done && !experiment.resolved)
		experiment.bonus_done = TRUE
		var/datum/component/experiment_damage_ledger/ledger = creature.GetComponent(/datum/component/experiment_damage_ledger)
		var/share = ledger ? ledger.player_share() : 1
		if(share >= OUTPOST_EXPERIMENT_PLAYER_SHARE)
			var/bonus = round(outpost_experiment_bonus(kind, subdued) * experiment.multiplier)
			if(pay_treasury(bonus, "Kessler Biolabs containment bonus"))
				experiment.bonus_paid = bonus
				add_log("[creature.name] was [subdued ? "subdued" : "put down"]. Kessler Biolabs paid a [bonus] cr containment bonus.")
		else
			add_log("[creature.name] was [subdued ? "subdued" : "put down"]. Kessler Biolabs paid no bonus.")
	addtimer(CALLBACK(src, PROC_REF(kessler_collect), WEAKREF(creature), FALSE), OUTPOST_EXPERIMENT_PICKUP SECONDS, TIMER_DELETE_ME)
	if(!experiment.resolved && !length(experiment.live_creatures()))
		resolve_experiment("contained")
	return TRUE

/**
 * A tracked creature died: that is it put down. Gibbed or dusted (a bomb, a shuttle), it never took
 * the health it still had as damage, so that goes on its ledger as damage that was not the players'.
 * For the horror down and regenerating, that is what is left of its body.
 */
/datum/outpost_prison/proc/on_creature_death(mob/living/creature, gibbed)
	SIGNAL_HANDLER
	var/unspent = creature.health
	var/mob/living/basic/outpost_experiment/experiment_creature = creature
	if(istype(experiment_creature))
		unspent = experiment_creature.unspent_health()
	if(gibbed && unspent > 0)
		var/datum/component/experiment_damage_ledger/ledger = creature.GetComponent(/datum/component/experiment_damage_ledger)
		ledger?.add_damage(unspent, FALSE)
	INVOKE_ASYNC(src, PROC_REF(experiment_creature_down), creature, FALSE)

/// A tracked creature is gone. A serum creature deleted before it was put down or recovered takes the experiment with it.
/datum/outpost_prison/proc/on_creature_deleted(mob/living/creature)
	SIGNAL_HANDLER
	UnregisterSignal(creature, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	if(!experiment)
		return
	var/key = REF(creature)
	// A creature from an earlier experiment, collected after this one began, is none of its business.
	if(!experiment.creature_refs[key])
		return
	var/was_down = experiment.downed[key]
	experiment.forget_creature(key)
	if(was_down || experiment.resolved || experiment.form == "changeling")
		return
	if(!length(experiment.live_creatures()))
		INVOKE_ASYNC(src, PROC_REF(experiment_failed), "the creature is gone")

/**
 * The experiment failed (the subject died early or was taken away, a creature vanished): no more
 * pay, and any creature still about is taken away by Kessler at no charge. A fee already paid is
 * kept. Returns TRUE if there was one to fail.
 */
/datum/outpost_prison/proc/experiment_failed(reason)
	if(!experiment_active())
		return FALSE
	for(var/mob/living/creature as anything in experiment.live_creatures())
		experiment.downed[REF(creature)] = TRUE
		kessler_collect(WEAKREF(creature), FALSE)
	add_log("The experiment failed: [reason].")
	log_game("PLAYER OUTPOST PRISON: experiment failed at '[outpost?.name]' ([reason])")
	resolve_experiment("failed")
	return TRUE

/**
 * Kessler recovers the experiment's creatures: a team beams in and takes them away. `charge`
 * bills the treasury the creature's recovery fee (debt if it is short) through charge_fine();
 * no containment bonus. Returns the fee charged (TRUE if none), or FALSE with nothing to recover.
 */
/datum/outpost_prison/proc/experiment_recover(charge = TRUE)
	if(!experiment_active())
		return FALSE
	var/fee = 0
	var/list/names = list()
	for(var/mob/living/creature as anything in experiment.live_creatures())
		var/key = REF(creature)
		fee = max(fee, outpost_experiment_recovery_fee(experiment.creature_kinds[key]))
		names += creature.name
		experiment.downed[key] = TRUE
		kessler_collect(WEAKREF(creature), TRUE)
	var/charged = 0
	if(charge && fee > 0)
		charged = charge_fine(fee, "Kessler Biolabs recovery fee")
	var/what = length(names) ? english_list(names) : "the specimen"
	add_log(charged ? "Kessler Biolabs recovered [what]. Charged [charged] cr." : "Kessler Biolabs recovered [what].")
	announce(charged ? "Kessler Biolabs recovered [what] from the prison wing and charged the outpost [charged] cr." : "Kessler Biolabs recovered [what] from the prison wing.", SHIP_NOTIFY_WARNING)
	log_game("PLAYER OUTPOST PRISON: Kessler recovered [what] at '[outpost?.name]', charged [charged] cr")
	resolve_experiment("failed")
	return charged || TRUE

/// The admin panel calls off the experiment, the offer and any item out, with no fee. Returns TRUE if there was anything.
/datum/outpost_prison/proc/experiment_end_admin()
	var/had_any = !!experiment || !!researcher || length(live_items())
	end_experiments_quietly()
	if(had_any)
		add_log("The experiment was called off.")
	return had_any

/**
 * The admin panel's horror buttons. "kill" kills the experiment's horror for good, which pays the
 * containment bonus as any final death would. "regen" puts it down regenerating if it is up, or
 * gets it up now if it is down. Returns TRUE if it did something.
 */
/datum/outpost_prison/proc/admin_horror(what)
	var/mob/living/basic/outpost_experiment/horror/horror = experiment_active() ? experiment.live_horror() : null
	if(!horror)
		return FALSE
	switch(what)
		if("kill")
			return horror.die_for_good()
		if("regen")
			return horror.regenerating ? horror.rise_again() : horror.start_regenerating()
	return FALSE

/**
 * Ends everything to do with experiments at once, with no pay and no fee: for the admin panel,
 * abandoning and deleting. `instant` (the prison is being deleted) also deletes the bodies still
 * waiting for Kessler, whose collection timers go with the prison.
 */
/datum/outpost_prison/proc/end_experiments_quietly(instant = FALSE)
	if(experiment)
		if(instant)
			for(var/key in experiment.creature_refs.Copy())
				var/datum/weakref/creature_ref = experiment.creature_refs[key]
				var/mob/living/creature = creature_ref?.resolve()
				experiment.downed[key] = TRUE
				if(!QDELETED(creature))
					qdel(creature)
		for(var/mob/living/creature as anything in experiment.live_creatures())
			experiment.downed[REF(creature)] = TRUE
			kessler_collect(WEAKREF(creature), FALSE)
		var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
		if(subject)
			subject.experiment_subject = FALSE
			outpost_experiment_clear_tells(subject)
			subject.update_bubble()
		clear_experiment()
	if(researcher)
		if(instant)
			qdel(researcher)
		else
			researcher.leave()
		researcher = null
	offer_claim = null
	for(var/atom/thing as anything in live_items())
		qdel(thing)
	experiment_items.Cut()
	pending_multiplier = 1
	if(visits_started)
		researcher_wait = rand(OUTPOST_EXPERIMENT_GAP_MIN, OUTPOST_EXPERIMENT_GAP_MAX)

/**
 * The experiment is over, "contained" or "failed": the console shows it for a minute, the subject
 * (if still a prisoner) is theirs again, what the prisoners saw sinks in, and the researcher is due
 * again in 35-50 minutes.
 */
/datum/outpost_prison/proc/resolve_experiment(outcome)
	if(!experiment || experiment.resolved)
		return
	experiment.resolved = TRUE
	experiment.stage = outcome
	experiment.result_left = OUTPOST_EXPERIMENT_RESULT_SHOWN
	var/mob/living/basic/outpost_prisoner/subject = experiment.subject()
	if(subject && subject.stat != DEAD)
		subject.experiment_subject = FALSE
		outpost_experiment_clear_tells(subject)
		subject.update_bubble()
#ifdef OUTPOST_CHANGELING_API
	// The changeling event saw deaths this core does not hear of: the host's burst, and anyone
	// absorbed who was not a prisoner. Its witnesses join the experiment's, once each.
	if(!QDELETED(experiment.changeling))
		for(var/datum/weakref/witness_ref as anything in experiment.changeling.witnesses)
			var/mob/living/basic/outpost_prisoner/witness = witness_ref?.resolve()
			if(witness)
				experiment.witnesses[REF(witness)] = witness_ref
#endif
	if(outcome == "failed")
		QDEL_NULL(experiment.changeling)
	experiment_aftermath()
	researcher_wait = rand(OUTPOST_EXPERIMENT_GAP_MIN, OUTPOST_EXPERIMENT_GAP_MAX)
	log_game("PLAYER OUTPOST PRISON: experiment ended ([outcome]) at '[outpost?.name]': fee [experiment.fee_paid] cr, bonus [experiment.bonus_paid] cr")

/// Forgets the experiment for good
/datum/outpost_prison/proc/clear_experiment()
	QDEL_NULL(experiment)

/// What the prisoners saw: each witness to a death loses mood, and each prisoner a creature killed puts the wing on edge
/datum/outpost_prison/proc/experiment_aftermath()
	for(var/key in experiment.witnesses)
		var/datum/weakref/witness_ref = experiment.witnesses[key]
		var/mob/living/basic/outpost_prisoner/witness = witness_ref?.resolve()
		if(!witness || witness.prison != src || witness.stat == DEAD || witness.phase != PRISONER_PRESENT)
			continue
		witness.adjust_mood(-OUTPOST_EXPERIMENT_SAW_DEATH_MOOD)
	if(experiment.creature_kills)
		add_tension_spike(OUTPOST_EXPERIMENT_KILL_TENSION * experiment.creature_kills)
	experiment.witnesses.Cut()
	experiment.creature_kills = 0

/**
 * Kessler takes a creature away: a team beams in around it, and OUTPOST_KESSLER_TEAM_TIME later
 * the beam takes it. One that was put down is collected where it lies; one still on its feet (a
 * `recovery` off the outpost, or an experiment called off) is tranquilised and drops first. It is
 * held still and cannot be hurt meanwhile.
 */
/datum/outpost_prison/proc/kessler_collect(datum/weakref/creature_ref, recovery = FALSE)
	var/mob/living/creature = creature_ref?.resolve()
	if(QDELETED(creature) || HAS_TRAIT_FROM(creature, TRAIT_GODMODE, OUTPOST_KESSLER_TRAIT))
		return
	var/already_down = creature.stat == DEAD || creature.body_position == LYING_DOWN
	ADD_TRAIT(creature, TRAIT_GODMODE, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(creature, TRAIT_IMMOBILIZED, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(creature, TRAIT_INCAPACITATED, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(creature, TRAIT_HANDS_BLOCKED, OUTPOST_KESSLER_TRAIT)
	ADD_TRAIT(creature, TRAIT_FLOORED, OUTPOST_KESSLER_TRAIT)
	creature.ai_controller?.CancelActions()
	creature.pulledby?.stop_pulling()
	if(recovery)
		outpost_kessler_team(creature, "kessler_recovery", tranquilise = TRUE)
	else
		outpost_kessler_team(creature, "kessler_collect", tranquilise = !already_down)
	if(already_down && !recovery)
		add_log("Kessler Biolabs collected [creature.name].")
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(outpost_kessler_beam_away), creature), OUTPOST_KESSLER_TEAM_TIME, TIMER_DELETE_ME)

// ===== PRISONERS =====

/// Prisoners who could be the researcher's subjects: in the wing, alive, not loose and not dosed already
/datum/outpost_prison/proc/researcher_prisoner_count()
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase == PRISONER_PRESENT && prisoner.stat != DEAD && prisoner.trouble != PRISONER_TROUBLE_LOOSE && !prisoner.experiment_subject)
			count++
	return count

/**
 * A creature's victims. The serum subject dying while dosed is an abort: no fee, no bonus, and the
 * researcher says so. A changeling host dying is the changeling event's to handle. Anyone else a
 * creature (not staff) killed counts toward the aftermath, with everyone in sight of it a witness.
 */
/datum/outpost_prison/on_prisoner_death(mob/living/basic/outpost_prisoner/prisoner)
	. = ..()
	if(!experiment_active())
		return
	if(prisoner == experiment.subject())
		if(experiment.form != "changeling" && (experiment.stage in list("dosed", "twitching")))
			add_log("[prisoner.real_name] died before the serum took. No data, no fee.")
			var/line = outpost_experiment_line("researcher_no_data")
			if(line)
				add_log("Kessler Biolabs: \"[line]\"")
			experiment_failed("the subject died before the serum took")
		return
	if(!creature_live() || prisoner.death_blamed)
		return
	experiment.creature_kills++
	for(var/mob/living/basic/outpost_prisoner/witness in viewers(OUTPOST_EXPERIMENT_WITNESS_RANGE, get_turf(prisoner)))
		if(witness != prisoner && witness.prison == src && witness.stat != DEAD)
			experiment.witnesses[REF(witness)] = WEAKREF(witness)

/// A dosed subject earns nothing: their pay and release bonus are forfeit
/datum/outpost_prison/pay_factor(mob/living/basic/outpost_prisoner/prisoner)
	if(prisoner?.experiment_subject)
		return 0
	return ..()

/**
 * Whether the experiment under way still needs `prisoner`: its dosed subject, or the specimen's
 * host until the burst, dead or alive. Nobody beams them out meanwhile: their sentence holds
 * (serving_sentence()), and there is no release, riot transfer or escape for good, and a body out
 * of the cell block stays on the roster (body_tick()).
 * Once the experiment is over the usual rules apply again.
 */
/datum/outpost_prison/proc/held_for_experiment(mob/living/basic/outpost_prisoner/prisoner)
	if(!prisoner || !experiment_active())
		return FALSE
	if(prisoner == experiment.subject())
		return TRUE
#ifdef OUTPOST_CHANGELING_API
	if(!QDELETED(experiment.changeling) && experiment.changeling.host == prisoner)
		return TRUE
#endif
	return FALSE

/// A dosed subject is not released at the end of their sentence
/datum/outpost_prison/check_release(mob/living/basic/outpost_prisoner/prisoner)
	if(held_for_experiment(prisoner))
		return
	return ..()

/datum/outpost_prison/release(mob/living/basic/outpost_prisoner/prisoner)
	if(held_for_experiment(prisoner))
		return 0
	return ..()

/// Abandoned: the experiment, the offer and the items go, with no fee
/datum/outpost_prison/on_outpost_abandoned()
	end_experiments_quietly()
	return ..()

/datum/outpost_prison/Destroy()
	end_experiments_quietly(instant = TRUE)
	return ..()

// ===== ITEMS =====

/// Tracks a serum, specimen jar or tainted food: no new visit while one is out
/datum/outpost_prison/proc/track_experiment_item(atom/thing)
	experiment_items |= WEAKREF(thing)

/// The serum, specimen jars and tainted food out now
/datum/outpost_prison/proc/live_items()
	var/list/found = list()
	for(var/datum/weakref/thing_ref as anything in experiment_items.Copy())
		var/atom/thing = thing_ref.resolve()
		if(QDELETED(thing) || !thing.GetComponent(/datum/component/outpost_experiment_item))
			experiment_items -= thing_ref
			continue
		found += thing
	return found

/**
 * Items spoil after OUTPOST_EXPERIMENT_ITEM_LIFETIME and are destroyed off the wing's level (a ship,
 * another outpost, cryo). The last one gone without starting anything is a lapsed offer, which
 * researcher_tick() notices.
 */
/datum/outpost_prison/proc/items_tick()
	if(!length(experiment_items))
		return
	var/z = wing_z()
	for(var/atom/thing as anything in live_items())
		var/datum/component/outpost_experiment_item/label = thing.GetComponent(/datum/component/outpost_experiment_item)
		if(world.time >= label.expires_at)
			label.expire()
			continue
		var/turf/where = get_turf(thing)
		if(!where || where.z != z)
			log_game("PLAYER OUTPOST PRISON: a Kessler [label.kind] left the level of '[outpost?.name]' and was destroyed")
			label.destroy_item()

// ===== THE CONSOLE =====

/**
 * The warden console's and the admin panel's experiment block, or null:
 * list(form, stage, subject, time_left, researcher_present, fee_paid, bonus_paid). A serum's form
 * shows as "unknown" until the creature does. "offered" covers the researcher waiting with an
 * offer and an item taken but not used yet.
 */
/datum/outpost_prison/proc/experiment_payload()
	if(experiment)
		return experiment.payload()
	if(researcher && !QDELETED(researcher))
		var/limit = offer_claim?.resolve() ? OUTPOST_EXPERIMENT_STAY_OPEN : OUTPOST_EXPERIMENT_STAY
		return list(
			"form" = offer_kind == "specimen" ? "changeling" : "unknown",
			"stage" = "offered",
			"subject" = null,
			"time_left" = max(0, round(limit - researcher_stay)),
			"researcher_present" = TRUE,
			"fee_paid" = 0,
			"bonus_paid" = 0,
		)
	var/list/items = live_items()
	if(length(items))
		var/atom/thing = items[1]
		var/datum/component/outpost_experiment_item/label = thing.GetComponent(/datum/component/outpost_experiment_item)
		return list(
			"form" = label.kind == "serum" ? "unknown" : "changeling",
			"stage" = "offered",
			"subject" = null,
			"time_left" = max(0, round((label.expires_at - world.time) / (1 SECONDS))),
			"researcher_present" = FALSE,
			"fee_paid" = 0,
			"bonus_paid" = 0,
		)
	return null

// ===== THE EXPERIMENT =====

/// One experiment: its subject, stage, creatures, clocks and what it has paid
/datum/outpost_experiment
	var/datum/outpost_prison/prison
	/// "hulk", "fly", "nightmare" or "changeling"
	var/form
	/// "dosed", "twitching", "incubating", "live", "vents", "horror", "contained" or "failed"
	var/stage
	var/datum/weakref/subject_ref
	var/subject_name
	/// Seconds of twitch left, and to the next twitch or tell
	var/twitch_left = 0
	var/effect_left = 0
	/// Seconds the subject has spent outside the cell block
	var/outside_seconds = 0
	/// REF() of each creature -> its weakref, and -> its kind ("hulk", "fly", "nightmare", "headslug", "horror")
	var/list/creature_refs = list()
	var/list/creature_kinds = list()
	/// REF() of creatures put down, recovered or taken away -> TRUE
	var/list/downed = list()
	/// REF() of creatures put down and lying there until Kessler's beam takes them -> "subdued" or "down"
	var/list/awaiting = list()
	/// A creature has got out of the wing, and the outpost has been told
	var/breach_announced = FALSE
	/// The researcher's sweetener on the pay
	var/multiplier = 1
	var/fee_paid = 0
	var/bonus_paid = 0
	var/fee_done = FALSE
	var/bonus_done = FALSE
	/// Started from the admin panel
	var/forced = FALSE
	/// A creature has shown, so the console may name the form
	var/revealed = FALSE
	var/resolved = FALSE
	/// Seconds the console still shows how it ended
	var/result_left = 0
	/// The changeling event, for a specimen
	var/datum/outpost_changeling_event/changeling
	/// Prisoners who saw a prisoner die: REF() -> weakref; and how many prisoners the creatures killed
	var/list/witnesses = list()
	var/creature_kills = 0

/datum/outpost_experiment/New(datum/outpost_prison/owner, form, mob/living/basic/outpost_prisoner/subject)
	. = ..()
	prison = owner
	src.form = form
	if(subject)
		subject_ref = WEAKREF(subject)
		subject_name = subject.real_name

/datum/outpost_experiment/Destroy()
	QDEL_NULL(changeling)
	prison = null
	creature_refs = null
	creature_kinds = null
	downed = null
	awaiting = null
	witnesses = null
	return ..()

/datum/outpost_experiment/proc/subject()
	return subject_ref?.resolve()

/// The creatures still loose: alive, not put down, recovered or taken
/datum/outpost_experiment/proc/live_creatures()
	var/list/live = list()
	for(var/key in creature_refs)
		if(downed[key])
			continue
		var/datum/weakref/creature_ref = creature_refs[key]
		var/mob/living/creature = creature_ref?.resolve()
		if(QDELETED(creature) || creature.stat == DEAD)
			continue
		live += creature
	return live

/// The experiment's horror while it is out and not dead for good (up, or down regenerating), or null
/datum/outpost_experiment/proc/live_horror()
	for(var/mob/living/basic/outpost_experiment/horror/horror in live_creatures())
		return horror
	return null

/datum/outpost_experiment/proc/forget_creature(key)
	creature_refs -= key
	creature_kinds -= key
	downed -= key
	awaiting -= key

/// "subdued" or "down" while a creature that was put down still lies there for Kessler, else null
/datum/outpost_experiment/proc/awaiting_pickup()
	var/state
	for(var/key in awaiting)
		var/datum/weakref/creature_ref = creature_refs[key]
		if(QDELETED(creature_ref?.resolve()))
			continue
		if(awaiting[key] == "subdued")
			return "subdued"
		state = "down"
	return state

/// A specimen's stage follows the changeling event while it runs
/datum/outpost_experiment/proc/follow_changeling()
	if(form != "changeling" || resolved || QDELETED(changeling))
		return
	switch(changeling.stage)
		if("incubating")
			stage = "incubating"
		if("burst")
			stage = "live"
		if("vents")
			stage = "vents"
		if("horror")
			stage = "horror"

/**
 * The console block; see /datum/outpost_prison/proc/experiment_payload(). A horror down and
 * regenerating shows as "horror" = "regenerating", with the time until it gets up as time_left.
 * "pickup" is "subdued" or "down" while a creature that was put down lies there for Kessler.
 */
/datum/outpost_experiment/proc/payload()
	follow_changeling()
	var/time_left
	var/mob/living/basic/outpost_experiment/horror/horror = resolved ? null : live_horror()
	switch(stage)
		if("dosed", "twitching")
			time_left = twitch_left
		if("incubating", "vents")
			time_left = QDELETED(changeling) ? null : changeling.time_left
		if("live", "horror")
			if(horror?.regenerating)
				time_left = horror.regen_left
			else if(!QDELETED(changeling))
				time_left = changeling.time_left
	if(!isnull(time_left))
		time_left = max(0, round(time_left))
	return list(
		"form" = (form == "changeling" || revealed) ? form : "unknown",
		"stage" = stage,
		"subject" = subject_name,
		"time_left" = time_left,
		"researcher_present" = !!prison?.researcher,
		"fee_paid" = fee_paid,
		"bonus_paid" = bonus_paid,
		"horror" = horror ? (horror.regenerating ? "regenerating" : "up") : null,
		"pickup" = awaiting_pickup(),
	)

// ===== TABLES =====

/// "changeling" for the specimen's creatures, else the form itself
/proc/outpost_experiment_family(form)
	if(form in list("changeling", "headslug", "slug", "horror"))
		return "changeling"
	return form

/// What a creature is, from the form it was reported with and its type
/proc/outpost_experiment_creature_kind(mob/living/creature, form)
	if(form in list("hulk", "fly", "nightmare"))
		return form
	if(form == "headslug" || form == "slug" || istype(creature, /mob/living/basic/headslug))
		return "headslug"
	return "horror"

/// The fee when an experiment's first creature shows
/proc/outpost_experiment_fee(form)
	switch(form)
		if("fly")
			return OUTPOST_EXPERIMENT_FEE_FLY
		if("hulk")
			return OUTPOST_EXPERIMENT_FEE_HULK
		if("nightmare")
			return OUTPOST_EXPERIMENT_FEE_NIGHTMARE
	return OUTPOST_EXPERIMENT_FEE_CHANGELING

/// The containment bonus for putting a creature of `kind` down
/proc/outpost_experiment_bonus(kind, subdued = FALSE)
	switch(kind)
		if("fly")
			return OUTPOST_EXPERIMENT_BONUS_FLY
		if("hulk")
			return subdued ? OUTPOST_EXPERIMENT_BONUS_HULK_SUBDUED : OUTPOST_EXPERIMENT_BONUS_HULK
		if("nightmare")
			return OUTPOST_EXPERIMENT_BONUS_NIGHTMARE
		if("headslug")
			return OUTPOST_EXPERIMENT_BONUS_HEADSLUG
	return OUTPOST_EXPERIMENT_BONUS_HORROR

/// What Kessler charges to recover a creature of `kind`; nothing for the headslug
/proc/outpost_experiment_recovery_fee(kind)
	switch(kind)
		if("fly")
			return OUTPOST_EXPERIMENT_RECOVERY_FLY
		if("hulk")
			return OUTPOST_EXPERIMENT_RECOVERY_HULK
		if("nightmare")
			return OUTPOST_EXPERIMENT_RECOVERY_NIGHTMARE
		if("horror")
			return OUTPOST_EXPERIMENT_RECOVERY_HORROR
	return 0

/// A line from the dialogue file for someone who is not a prisoner (the researcher, a creature), from `personality`'s pool or the shared one
/proc/outpost_experiment_line(context, personality)
	var/list/lines = outpost_prisoner_dialogue("lines")
	var/list/entry = lines[context]
	if(!islist(entry))
		return null
	var/list/pool = entry["any"]
	if(personality && length(entry[personality]) && prob(60))
		pool = entry[personality]
	var/list/usable = list()
	for(var/line in pool)
		if(istext(line) && !findtext(line, "{"))
			usable += line
	return length(usable) ? pick(usable) : null

/// Whether a mob belongs to a prison experiment: its creatures, the researcher and Kessler's team
/proc/is_outpost_experiment_mob(atom/thing)
	return isliving(thing) && HAS_TRAIT(thing, TRAIT_OUTPOST_EXPERIMENT)

/**
 * Whether a creature may break `target` (a wall, window, grille, door, table or the like): only
 * the outpost's own interior. Never the wing's outer ring, never anything with space, a docked
 * ship or other ground beyond it, and never outside the outpost.
 */
/proc/outpost_experiment_can_smash(atom/target, datum/outpost_prison/prison)
	var/turf/place = get_turf(target)
	if(!place || !prison?.outpost)
		return FALSE
	if(place.loc == prison.wing && prison.on_wing_edge(place))
		return FALSE
	if(!istype(place.loc, /area/voidcrew/player_outpost) || (place.loc != prison.wing && get_outpost_from_atom(place) != prison.outpost))
		return FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/beyond = get_step(place, direction)
		if(!beyond)
			return FALSE
		if(isclosedturf(beyond))
			continue
		if(isspaceturf(beyond) || isopenspaceturf(beyond) || !istype(beyond.loc, /area/voidcrew/player_outpost))
			return FALSE
		if(beyond.loc != prison.wing && get_outpost_from_atom(beyond) != prison.outpost)
			return FALSE
	return TRUE

// ===== DAMAGE LEDGER =====

/**
 * Keeps track of who hurt a creature: players (people with a mind, borgs, piloted mechs) or not
 * (turrets, traps, explosions, fire, other creatures). The containment bonus needs players to have
 * done at least OUTPOST_EXPERIMENT_PLAYER_SHARE of it. Damage and the report of who did it arrive
 * in either order within one tick, so each waits a tick for the other; damage nobody claims is
 * not the players'. The horror's burning is the exception: it is the players' when one lit it or
 * hurt it lately (crediting_players). Prisoners' blows (a rioter's shiv) are nobody's: they are left
 * out of the share altogether, so they neither help nor hurt the crew's bonus. Also marks the mob as
 * an experiment's (TRAIT_OUTPOST_EXPERIMENT).
 */
/datum/component/experiment_damage_ledger
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Brute and burn damage done by players and by everything else
	var/player_damage = 0
	var/other_damage = 0
	/// Damage this tick that nobody has claimed yet, and the tick
	var/pending = 0
	var/pending_time = -1
	/// The last attack reported: when, whether a player made it, and whether a prisoner did (left out of the share)
	var/last_attack_time = -1
	var/last_attack_player = FALSE
	var/last_attack_prisoner = FALSE
	/// The last player who hurt it, and when
	var/datum/weakref/last_player_ref
	var/last_player_time = 0
	/// While set, the damage it takes is the players' whoever struck last: fire a player is credited
	/// with (the horror's take_fire_damage()). It is not a blow, so recent_player() keeps its time.
	var/crediting_players = FALSE

/datum/component/experiment_damage_ledger/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/experiment_damage_ledger/RegisterWithParent()
	var/mob/living/creature = parent
	creature.AddElement(/datum/element/relay_attackers)
	ADD_TRAIT(creature, TRAIT_OUTPOST_EXPERIMENT, OUTPOST_EXPERIMENT_LEDGER_TRAIT)
	RegisterSignal(creature, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_attacked))
	RegisterSignal(creature, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))

/datum/component/experiment_damage_ledger/UnregisterFromParent()
	REMOVE_TRAIT(parent, TRAIT_OUTPOST_EXPERIMENT, OUTPOST_EXPERIMENT_LEDGER_TRAIT)
	UnregisterSignal(parent, list(COMSIG_ATOM_WAS_ATTACKED, COMSIG_MOB_AFTER_APPLY_DAMAGE))

/datum/component/experiment_damage_ledger/Destroy(force)
	last_player_ref = null
	return ..()

/datum/component/experiment_damage_ledger/proc/on_attacked(datum/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(!(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK)))
		return
	note_attacker(attacker)

/// Someone attacked it: damage it takes this tick is theirs
/datum/component/experiment_damage_ledger/proc/note_attacker(atom/attacker)
	var/player = outpost_experiment_is_player(attacker)
	var/prisoner = is_outpost_prisoner(attacker)
	settle()
	last_attack_time = world.time
	last_attack_player = player
	last_attack_prisoner = prisoner
	if(pending > 0 && pending_time == world.time)
		if(!prisoner)
			add_damage(pending, player)
		pending = 0
	if(player)
		last_player_ref = WEAKREF(attacker)
		last_player_time = world.time

/datum/component/experiment_damage_ledger/proc/on_damaged(datum/source, damage, damagetype)
	SIGNAL_HANDLER
	if(damage <= 0 || (damagetype != BRUTE && damagetype != BURN))
		return
	if(crediting_players)
		add_damage(damage, TRUE)
		return
	if(last_attack_time == world.time)
		if(!last_attack_prisoner)
			add_damage(damage, last_attack_player)
		return
	settle()
	pending += damage
	pending_time = world.time

/// Damage from an earlier tick that nobody claimed was not the players'
/datum/component/experiment_damage_ledger/proc/settle()
	if(pending > 0 && pending_time != world.time)
		other_damage += pending
		pending = 0

/datum/component/experiment_damage_ledger/proc/add_damage(amount, player)
	if(player)
		player_damage += amount
	else
		other_damage += amount

/**
 * The players' share of its damage, 0 to 1. With no damage on record, 1 only if a player attacked
 * it in the last OUTPOST_EXPERIMENT_PLAYER_RECENT (a hulk worn down with batons alone), else 0.
 */
/datum/component/experiment_damage_ledger/proc/player_share()
	settle()
	var/total = player_damage + other_damage + pending
	if(total <= 0)
		return (last_player_time && world.time - last_player_time <= OUTPOST_EXPERIMENT_PLAYER_RECENT) ? 1 : 0
	return player_damage / total

/// The player who hurt it last, if within `within`
/datum/component/experiment_damage_ledger/proc/recent_player(within = 10 SECONDS)
	if(!last_player_time || world.time - last_player_time > within)
		return null
	return last_player_ref?.resolve()

/// Whether an attacker counts as a player for the containment bonus: people with a mind, borgs, piloted mechs
/proc/outpost_experiment_is_player(atom/attacker)
	if(ismecha(attacker))
		var/obj/vehicle/sealed/mecha/mech = attacker
		for(var/mob/living/pilot in mech.occupants)
			if(pilot.mind || pilot.ckey)
				return TRUE
		return FALSE
	if(!isliving(attacker))
		return FALSE
	var/mob/living/person = attacker
	if(is_outpost_prisoner(person) || HAS_TRAIT(person, TRAIT_OUTPOST_EXPERIMENT))
		return FALSE
	return !isnull(person.mind) || !isnull(person.ckey)

// ===== THE CHANGELING (until outpost_prison_changeling.dm is in) =====

#ifndef OUTPOST_CHANGELING_API
/// Stand-in for the changeling event (outpost_prison_changeling.dm), so the experiments core builds without it
/datum/outpost_changeling_event
	/// "incubating", "burst", "vents", "horror" or "done"
	var/stage = "incubating"
	/// Seconds left in the stage, or null
	var/time_left
	var/datum/outpost_prison/prison
	var/datum/weakref/host_ref

/datum/outpost_changeling_event/Destroy()
	prison = null
	return ..()

/// Jumps the event to a stage, for the admin panel: "burst" or "horror"
/datum/outpost_changeling_event/proc/force_stage(stage)
	src.stage = stage
	return TRUE

/// Starts a changeling event in `host`, a prisoner of `prison`, and returns it
/proc/outpost_changeling_infect(mob/living/basic/outpost_prisoner/host, datum/outpost_prison/prison)
	var/datum/outpost_changeling_event/event = new
	event.prison = prison
	event.host_ref = WEAKREF(host)
	return event
#endif
