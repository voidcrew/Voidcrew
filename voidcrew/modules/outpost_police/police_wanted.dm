/**
 * # Outpost police: warrants, heat and stars
 *
 * Owner: P1 (wanted core). Every crime at a trader outpost reaches report_crime(); this file turns it into
 * heat on the offender's warrant (GLOB.outpost_crimes), fades it, fines it, bars and embargoes for it.
 * Spec sections 2, 4, 6.2, 9 (the embargo half) and 15.
 *
 * report_crime() runs inside signal handlers (the PvP watcher, outpost property, the armed sweep): it and
 * everything it calls must never sleep.
 *
 * Round metrics written here (METRIC_COMBAT, voidcrew/modules/metrics; the event catalog lives in the kit
 * vault page for metrics):
 *   police_warrant_ended    A wanted record ended. ckey = the suspect, subject = how ("faded", "served",
 *                           "closed"), points = peak stars, quantity = officers they killed.
 *   police_officer_killed   An officer was killed by someone with a record. ckey = the killer, quantity = 1.
 *   police_embargo          A four or five star incident put a crew under embargo. ckey = the suspect,
 *                           points = stars, quantity = minutes.
 * Fines show up as the ship account's own ship_account_change row ("Fine: <force name>").
 */

// =========================================================================
// P1'S OWN STATE (vars on the shared types, kept here because police_core.dm is frozen)
// =========================================================================

/datum/outpost_police
	/// weakref to a mind -> list(world.time, POLICE_REPORT_*, the crime, weakref to the victim or null, weakref to the
	/// pending report or null, baseline heat before the grace window): folds the same offender's reports within a half
	/// second, while letting a graver witnessed crime in that window upgrade the charge.
	var/list/recent_reports = list()
	/// Reports waiting on a witness's delay (/datum/outpost_pending_report), confirmed in tick_warrants()
	var/list/pending_reports = list()
	/// Four and five star incidents: crew record -> /datum/outpost_incident
	var/list/incidents = list()
	/// Crew records whose deletion we listen for
	var/list/watched_crews = list()
	/// Whether the death hook is registered
	var/events_hooked = FALSE

/datum/outpost_police/Destroy()
	if(events_hooked)
		UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH)
		events_hooked = FALSE
	for(var/datum/voidcrew_crew_record/crew as anything in watched_crews.Copy())
		if(!QDELETED(crew))
			UnregisterSignal(crew, COMSIG_QDELETING)
	watched_crews.Cut()
	for(var/datum/mind/mind as anything in warrants)
		if(!QDELETED(mind))
			UnregisterSignal(mind, list(COMSIG_QDELETING, COMSIG_MIND_TRANSFERRED))
	QDEL_LIST(pending_reports)
	QDEL_LIST_ASSOC_VAL(incidents)
	recent_reports.Cut()
	case_holds = null
	return ..()

/**
 * A report that waits for its witnesses (perception.report_delay() above 0, or perception.reports_by_call()). Until
 * it counts, the warrant exists for nobody but those witnesses: no stars, no dispatch, no bar (spec-stealth 2.3).
 */
/datum/outpost_pending_report
	/// world.time the crime happened and the report was queued
	var/created_at = 0
	/// world.time the witness finishes reporting (a witness that reports by call waits for `confirmed` instead)
	var/due = 0
	/// world.time it is dropped if nobody has made it: a witness out cold may come round meanwhile
	var/expires = 0
	/// Set when a witness's radio call went out (confirm_reports())
	var/confirmed = FALSE
	/// world.time a radioless witness started telling someone in person, or 0
	var/relay_since = 0
	/// Baseline heat when upgrading an already-counted crime from the same grace window, or -1
	var/upgrade_base = -1
	var/crime
	var/datum/weakref/offender
	var/datum/weakref/victim
	var/datum/weakref/source
	/// Weakrefs to everyone who saw it (one is enough to make it)
	var/list/datum/weakref/witnesses
	/// What followed while it waited, counted with it: list(crime, weakref to the victim) each (a killing)
	var/list/followups
	/// Victims and weapons of the offender's reports folded into this one (report_crime()), weakrefs: they join the
	/// warrant when it is made, as a folded report's do on a counted one
	var/list/datum/weakref/folded_victims
	var/list/datum/weakref/folded_sources

/datum/outpost_pending_report/Destroy()
	offender = null
	victim = null
	source = null
	witnesses = null
	followups = null
	folded_victims = null
	folded_sources = null
	return ..()

/// One four or five star incident of one crew at this outpost: the embargo here (decision 25: this outpost only)
/datum/outpost_incident
	var/datum/voidcrew_crew_record/crew
	/// Highest tier applied: 4 or 5 stars
	var/stars = 0
	var/started_at = 0
	/// world.time the embargo ends
	var/ends_at = 0
	var/officers_killed = 0
	/// Weakrefs to the crew's ships this incident has embargoed, so a ship the crew gets later is embargoed once and an
	/// admin's lift on one sticks
	var/list/datum/weakref/ships_embargoed = list()

/datum/outpost_incident/Destroy()
	crew = null
	ships_embargoed = null
	return ..()

// =========================================================================
// REPORTING A CRIME
// =========================================================================

/**
 * `offender` did `crime` (OUTPOST_CRIME_*) to `victim` (or to nobody in particular) with `source` (the item
 * used, or null). Returns the offender's stars here after it, 0 for a counted crime still under one star, or
 * null when it did not count (no mind, no witness, folded into the last one, waiting on a witness's report).
 * A counted `source` joins the warrant's evidence. Never sleeps.
 */
/datum/outpost_police/proc/report_crime(mob/living/offender, crime, atom/victim, obj/item/source)
	SHOULD_NOT_SLEEP(TRUE)
	if(QDELETED(src) || !offender?.mind)
		return null
	if(!GLOB.outpost_crimes[crime])
		stack_trace("OUTPOST POLICE: unknown crime '[crime]'")
		return null
	switch(crime)
		if(OUTPOST_CRIME_WEAPON_DRAWN, OUTPOST_CRIME_GUNFIRE, OUTPOST_CRIME_VANDALISM)
			// A hunter in the kingpin's shootout is excused strays from that fight (abuse M16)
			if(bounty_kingpin_excuses_aggression(outpost, offender))
				return null
	var/datum/mind/mind = offender.mind
	var/datum/weakref/mind_ref = WEAKREF(mind)
	// One report per offender per half second; a folded one still lends its weapon and victim to the report it joins,
	// while a graver witnessed crime in the same window (e.g. a shot hitting an officer right after gunfire) upgrades it.
	// After an unseen one, a different crime or victim is looked at again: someone else may see that one (a struck officer).
	prune_recent_reports()
	var/list/last = recent_reports[mind_ref]
	if(last)
		switch(last[2])
			if(POLICE_REPORT_COUNTED)
				var/base_heat = last[6]
				var/datum/outpost_warrant/warrant = warrants[mind]
				if(warrant && crime != last[3] && heat_after(base_heat, crime) > warrant.heat)
					return upgrade_counted_crime(offender, mind_ref, last, crime, victim, source)
				fold_crime(mind, victim, source)
				return null
			if(POLICE_REPORT_PENDING)
				var/datum/weakref/report_ref = last[5]
				var/datum/outpost_pending_report/pending = report_ref?.resolve()
				var/base_heat = last[6]
				if(!QDELETED(pending) && (pending in pending_reports) && crime != pending.crime && heat_after(base_heat, crime) > heat_after(base_heat, pending.crime))
					return upgrade_pending_crime(offender, mind_ref, last, pending, crime, victim, source)
				fold_pending(pending, victim, source)
				return null
		if(last[3] == crime && last[4] == (victim ? WEAKREF(victim) : null))
			return null
	var/base_heat = baseline_heat_for(mind, crime)
	var/witnessed = perception.witness_of(offender, crime, victim, source)
	if(witnessed == POLICE_WITNESS_NONE)
		recent_reports[mind_ref] = list(world.time, POLICE_REPORT_UNSEEN, crime, victim ? WEAKREF(victim) : null, null, base_heat)
		log_game("OUTPOST POLICE: [key_name(offender)] committed [crime] at [outpost] ([AREACOORD(offender)]) and nobody saw.")
		return null
	var/atom/witness = perception.last_witness
	var/list/witnesses = perception.last_witnesses
	// Abuse SF4: the perception keeps no hard reference to a witness once read (a deleted officer or player would hang on it)
	perception.last_witness = null
	perception.last_witnesses = null
	// An officer who saw it says so to their face (police_life.dm)
	shout_for_witnesses(witness, witnesses, offender, crime)
	var/delay = perception.report_delay(witness, crime)
	if(delay > 0 || perception.reports_by_call(witness))
		var/datum/outpost_pending_report/report = queue_report(offender, crime, victim, source, witnesses || list(witness), delay)
		recent_reports[mind_ref] = list(world.time, POLICE_REPORT_PENDING, crime, victim ? WEAKREF(victim) : null, WEAKREF(report), base_heat)
		return null
	recent_reports[mind_ref] = list(world.time, POLICE_REPORT_COUNTED, crime, victim ? WEAKREF(victim) : null, null, base_heat)
	return count_crime(offender, crime, victim, source)

/// Baseline heat `crime` would build on for `mind` right now
/datum/outpost_police/proc/baseline_heat_for(datum/mind/mind, crime)
	var/datum/outpost_warrant/warrant = warrants[mind]
	if(!warrant)
		return 0
	return crime == OUTPOST_CRIME_ACCOMPLICE ? warrant.heat : max(warrant.heat, current_prior(warrant))

/// Tells the first police officer among the witnesses to call out `crime` to `offender`
/datum/outpost_police/proc/shout_for_witnesses(atom/witness, list/witnesses, mob/living/offender, crime)
	if(!perception.is_officer(witness))
		var/seen_by_person = ismob(witness)
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in witnesses)
			if(perception.is_officer(officer))
				witness = officer
				break
		// A trader or a player made the report, but an officer watching it happen still calls it out
		if(seen_by_person && !perception.is_officer(witness))
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
				if(perception.is_officer(officer) && perception.sees(officer, offender))
					witness = officer
					break
	witness_shout(witness, offender, crime)

/// Upgrades an already-counted grace-window report when a graver crime in the same instant is also witnessed
/datum/outpost_police/proc/upgrade_counted_crime(mob/living/offender, datum/weakref/mind_ref, list/last, crime, atom/victim, obj/item/source)
	var/witnessed = perception.witness_of(offender, crime, victim, source)
	if(witnessed == POLICE_WITNESS_NONE)
		// Unseen: it folds into the counted one, as any other hit in the half second does
		fold_crime(offender.mind, victim, source)
		return null
	var/atom/witness = perception.last_witness
	var/list/witnesses = perception.last_witnesses
	perception.last_witness = null
	perception.last_witnesses = null
	shout_for_witnesses(witness, witnesses, offender, crime)
	var/base_heat = last[6]
	var/delay = perception.report_delay(witness, crime)
	if(delay > 0 || perception.reports_by_call(witness))
		var/datum/outpost_pending_report/report = queue_report(offender, crime, victim, source, witnesses || list(witness), delay)
		report.upgrade_base = base_heat
		recent_reports[mind_ref] = list(last[1], POLICE_REPORT_PENDING, crime, victim ? WEAKREF(victim) : null, WEAKREF(report), base_heat)
		return null
	last[3] = crime
	last[4] = victim ? WEAKREF(victim) : null
	return apply_upgraded_crime(offender, base_heat, crime, victim, source)

/// Upgrades a pending grace-window report when a graver crime in the same instant is witnessed
/datum/outpost_police/proc/upgrade_pending_crime(mob/living/offender, datum/weakref/mind_ref, list/last, datum/outpost_pending_report/report, crime, atom/victim, obj/item/source)
	var/witnessed = perception.witness_of(offender, crime, victim, source)
	if(witnessed == POLICE_WITNESS_NONE)
		// Unseen: it folds into the pending one, as any other hit in the half second does
		fold_pending(report, victim, source)
		return null
	var/atom/witness = perception.last_witness
	var/list/witnesses = perception.last_witnesses
	perception.last_witness = null
	perception.last_witnesses = null
	shout_for_witnesses(witness, witnesses, offender, crime)
	var/base_heat = last[6]
	if(report.source)
		LAZYOR(report.folded_sources, report.source)
	if(report.victim)
		LAZYOR(report.folded_victims, report.victim)
	var/delay = perception.report_delay(witness, crime)
	if(delay <= 0 && !perception.reports_by_call(witness))
		pending_reports -= report
		recent_reports[mind_ref] = list(last[1], POLICE_REPORT_COUNTED, crime, victim ? WEAKREF(victim) : null, null, base_heat)
		var/stars = report.upgrade_base >= 0 ? apply_upgraded_crime(offender, report.upgrade_base, crime, victim, source) : count_crime(offender, crime, victim, source)
		apply_report_extras(report, offender)
		qdel(report)
		return stars
	report.crime = crime
	report.source = source ? WEAKREF(source) : null
	report.victim = victim ? WEAKREF(victim) : null
	if(delay > 0)
		var/had_non_call = FALSE
		for(var/datum/weakref/existing_ref as anything in report.witnesses)
			var/atom/existing_witness = existing_ref.resolve()
			if(existing_witness && !perception.reports_by_call(existing_witness))
				had_non_call = TRUE
				break
		if(!had_non_call)
			report.due = world.time + delay
			report.expires = max(report.expires, world.time + max(delay, OUTPOST_POLICE_PENDING_KEEP))
	for(var/atom/new_witness as anything in (witnesses || list(witness)))
		if(!new_witness)
			continue
		var/datum/weakref/new_ref = WEAKREF(new_witness)
		if(new_ref in report.witnesses)
			continue
		report.witnesses += new_ref
		if(perception.is_officer(new_witness))
			INVOKE_ASYNC(new_witness, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_witness_saw), offender)
	last[3] = crime
	last[4] = victim ? WEAKREF(victim) : null
	return null

/// Applies `crime` onto `offender`'s warrant from `base_heat`, raising heat without stacking onto a weaker crime from the same act
/datum/outpost_police/proc/apply_upgraded_crime(mob/living/offender, base_heat, crime, atom/victim, obj/item/source)
	var/datum/mind/mind = offender?.mind
	if(!mind || QDELETED(src))
		return null
	var/datum/outpost_warrant/warrant = ensure_warrant(mind)
	var/old_stars = stars_of(warrant.heat)
	warrant.heat = max(warrant.heat, heat_after(base_heat, crime))
	warrant.peak = max(warrant.peak, warrant.heat)
	warrant.last_crime_at = world.time
	warrant.last_seen_at = world.time
	warrant.last_seen_turf = get_turf(offender)
	warrant.unseen_since = 0
	if(source)
		note_evidence(warrant, source)
	if(isliving(victim) && victim != offender)
		record_victim(warrant, victim)
	log_game("OUTPOST POLICE: [key_name(offender)] committed [crime][victim ? " against [victim]" : ""][source ? " with [source] ([source.type])" : ""] at [outpost] ([AREACOORD(offender)]): [warrant.heat] heat.")
	var/new_stars = stars_of(warrant.heat)
	if(new_stars >= 3)
		warrant.barred_until = max(warrant.barred_until, world.time + OUTPOST_POLICE_BAR_TIME)
	if(new_stars != old_stars)
		stars_changed(warrant, old_stars, new_stars)
	wake()
	return new_stars

/// Forgets reports older than the grace
/datum/outpost_police/proc/prune_recent_reports()
	for(var/datum/weakref/mind_ref as anything in recent_reports.Copy())
		var/list/seen = recent_reports[mind_ref]
		var/datum/mind/mind = mind_ref.resolve()
		if(QDELETED(mind) || world.time - seen[1] >= OUTPOST_AGGRESSION_GRACE)
			recent_reports -= mind_ref

/// A report folded into the offender's last counted one: its weapon is evidence, its victim a victim
/datum/outpost_police/proc/fold_crime(datum/mind/mind, atom/victim, obj/item/source)
	var/datum/outpost_warrant/warrant = warrants[mind]
	if(!warrant)
		return
	if(source)
		note_evidence(warrant, source)
	if(isliving(victim))
		record_victim(warrant, victim)

/// A report folded into the offender's pending one: its weapon and victim join that report (count_report())
/datum/outpost_police/proc/fold_pending(datum/outpost_pending_report/report, atom/victim, obj/item/source)
	if(QDELETED(report) || !(report in pending_reports))
		return
	if(source)
		LAZYOR(report.folded_sources, WEAKREF(source))
	if(isliving(victim))
		var/datum/weakref/victim_ref = WEAKREF(victim)
		if(victim_ref != report.victim)
			LAZYOR(report.folded_victims, victim_ref)

/// Whether `victim_ref` was hit in `report`: its own victim or a folded one
/datum/outpost_police/proc/report_hit(datum/outpost_pending_report/report, datum/weakref/victim_ref)
	return report.victim == victim_ref || (victim_ref in report.folded_victims)

/**
 * Queues a report that `witnesses` will make in `delay` deciseconds, or (perception.reports_by_call()) when the first
 * of them gets the call out. An officer who saw it acts on it at once (police_stealth.dm, police_witness_saw()).
 */
/datum/outpost_police/proc/queue_report(mob/living/offender, crime, atom/victim, obj/item/source, list/witnesses, delay)
	var/datum/outpost_pending_report/report = new
	report.created_at = world.time
	report.due = world.time + delay
	report.expires = world.time + max(delay, OUTPOST_POLICE_PENDING_KEEP)
	report.crime = crime
	report.offender = WEAKREF(offender)
	if(victim)
		report.victim = WEAKREF(victim)
	if(source)
		report.source = WEAKREF(source)
	report.witnesses = list()
	for(var/atom/witness as anything in witnesses)
		if(witness)
			report.witnesses += WEAKREF(witness)
	pending_reports += report
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in witnesses)
		if(perception.is_officer(officer))
			INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_witness_saw), offender)
	wake()
	return report

/// Confirms the reports whose witness has finished their call; drops those nobody can make any more
/datum/outpost_police/proc/process_pending_reports()
	for(var/datum/outpost_pending_report/report as anything in pending_reports.Copy())
		if(QDELETED(report))
			pending_reports -= report
			continue
		var/mob/living/offender = report.offender?.resolve()
		var/list/atom/able = list()
		var/non_call_able = FALSE
		var/any_alive = !length(report.witnesses)
		for(var/datum/weakref/ref as anything in report.witnesses)
			var/atom/witness = ref.resolve()
			if(QDELETED(witness))
				continue
			var/mob/living/living_witness = witness
			if(isliving(witness) && living_witness.stat == DEAD)
				continue
			any_alive = TRUE
			if(perception.can_report(witness))
				able += witness
				if(!perception.reports_by_call(witness))
					non_call_able = TRUE
		var/made = !!length(able) && (report.confirmed || (non_call_able && world.time >= report.due))
		if(!made && length(able) && !report.confirmed)
			// Officers: a call going, or the words said in person
			var/telling = FALSE
			for(var/atom/witness as anything in able)
				if(perception.nudge_witness(witness, report))
					telling = TRUE
			if(!telling)
				report.relay_since = 0
			else if(!report.relay_since)
				report.relay_since = world.time
			else if(world.time - report.relay_since >= OUTPOST_POLICE_RADIOLESS_TIME)
				made = TRUE
		if(made && !QDELETED(offender))
			pending_reports -= report
			count_report(report, offender)
			qdel(report)
			continue
		if(QDELETED(offender) || !any_alive || world.time >= report.expires)
			pending_reports -= report
			log_game("OUTPOST POLICE: a report of [report.crime] at [outpost] was never made.")
			qdel(report)

/// Counts a pending report that was made, and what followed it while it waited
/datum/outpost_police/proc/count_report(datum/outpost_pending_report/report, mob/living/offender)
	if(report.upgrade_base >= 0)
		apply_upgraded_crime(offender, report.upgrade_base, report.crime, report.victim?.resolve(), report.source?.resolve())
	else
		count_crime(offender, report.crime, report.victim?.resolve(), report.source?.resolve())
	apply_report_extras(report, offender)

/// Folds `report`'s extra weapons, victims and followup killings onto `offender`'s warrant
/datum/outpost_police/proc/apply_report_extras(datum/outpost_pending_report/report, mob/living/offender)
	var/datum/outpost_warrant/warrant = warrants[offender.mind]
	if(warrant)
		for(var/datum/weakref/source_ref as anything in report.folded_sources)
			var/obj/item/source = source_ref.resolve()
			if(source)
				note_evidence(warrant, source)
		for(var/datum/weakref/victim_ref as anything in report.folded_victims)
			var/mob/living/victim = victim_ref.resolve()
			if(isliving(victim) && victim != offender)
				record_victim(warrant, victim)
	for(var/list/followup as anything in report.followups)
		var/datum/weakref/victim_ref = followup[2]
		count_crime(offender, followup[1], victim_ref?.resolve(), derived = TRUE)
		warrant = warrants[offender.mind]
		if(followup[1] == OUTPOST_CRIME_KILL_OFFICER && warrant)
			warrant.officers_killed++
			officer_killed_by(warrant)

/// Absorbs any pending reports of `crime` against `offender` once the same act has already been counted directly, keeping their folded tools, victims and followups
/datum/outpost_police/proc/absorb_pending_crime(mob/living/offender, crime)
	if(!offender || !length(pending_reports))
		return
	var/datum/weakref/mind_ref = offender.mind ? WEAKREF(offender.mind) : null
	var/list/seen = mind_ref ? recent_reports[mind_ref] : null
	for(var/datum/outpost_pending_report/report as anything in pending_reports.Copy())
		if(QDELETED(report) || report.crime != crime || report.offender?.resolve() != offender)
			continue
		pending_reports -= report
		if(seen && seen[2] == POLICE_REPORT_PENDING)
			var/datum/weakref/pending_ref = seen[5]
			if(pending_ref?.resolve() == report)
				seen[2] = POLICE_REPORT_COUNTED
				seen[5] = null
		if(offender.mind)
			fold_crime(offender.mind, report.victim?.resolve(), report.source?.resolve())
			apply_report_extras(report, offender)
		qdel(report)

/// `witness` has made its call (police_stealth.dm): every report it was waiting to make counts now
/datum/outpost_police/proc/confirm_reports(atom/witness)
	if(!witness || !length(pending_reports))
		return
	var/datum/weakref/witness_ref = WEAKREF(witness)
	var/found = FALSE
	for(var/datum/outpost_pending_report/report as anything in pending_reports)
		// A radio that was down (an EMP, a jammer) still calls it in once it is back, inside the keep (owner decision 42)
		if(witness_ref in report.witnesses)
			report.confirmed = TRUE
			found = TRUE
	if(found)
		process_pending_reports()

/**
 * The stars `officer` believes `mind` has: the warrant's, raised by the reports this officer is waiting to make
 * (spec-stealth 2.3: a witness acts on what it saw before anyone else knows).
 */
/datum/outpost_police/proc/officer_knows(mob/living/officer, datum/mind/mind)
	if(!mind)
		return 0
	var/datum/outpost_warrant/warrant = warrants[mind]
	var/heat = warrant ? warrant.heat : 0
	if(officer && length(pending_reports))
		var/datum/weakref/officer_ref = WEAKREF(officer)
		var/raised = FALSE
		for(var/datum/outpost_pending_report/report as anything in pending_reports)
			if(!(officer_ref in report.witnesses))
				continue
			var/mob/living/offender = report.offender?.resolve()
			if(offender?.mind != mind)
				continue
			if(!raised)
				raised = TRUE
				heat = max(heat, warrant ? current_prior(warrant) : 0)
			if(report.upgrade_base >= 0)
				heat = max(heat, heat_after(report.upgrade_base, report.crime))
			else
				heat = heat_after(heat, report.crime)
			for(var/list/followup as anything in report.followups)
				heat = heat_after(heat, followup[1])
	return stars_of(heat)

/**
 * Puts a witnessed crime on `offender`'s warrant. `derived` marks a crime that follows from one already
 * counted (a killing, an accomplice): it is not seen again and does not say where the offender is.
 * Returns the stars after.
 */
/datum/outpost_police/proc/count_crime(mob/living/offender, crime, atom/victim, obj/item/source, derived = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/mind/mind = offender?.mind
	if(!mind || QDELETED(src))
		return null
	var/datum/outpost_warrant/warrant = ensure_warrant(mind)
	var/old_stars = stars_of(warrant.heat)
	// An accomplice is counted as a crewmate with a clean record: their old prior stays out of it (owner decision 44)
	var/from_heat = crime == OUTPOST_CRIME_ACCOMPLICE ? warrant.heat : max(warrant.heat, current_prior(warrant))
	warrant.heat = heat_after(from_heat, crime)
	warrant.peak = max(warrant.peak, warrant.heat)
	warrant.last_crime_at = world.time
	if(!derived)
		warrant.last_seen_at = world.time
		warrant.last_seen_turf = get_turf(offender)
		warrant.unseen_since = 0
	if(source)
		note_evidence(warrant, source)
	if(isliving(victim) && victim != offender)
		record_victim(warrant, victim)
	log_game("OUTPOST POLICE: [key_name(offender)] committed [crime][victim ? " against [victim]" : ""][source ? " with [source] ([source.type])" : ""] at [outpost] ([AREACOORD(offender)]): [warrant.heat] heat.")
	var/new_stars = stars_of(warrant.heat)
	if(new_stars >= 3)
		warrant.barred_until = max(warrant.barred_until, world.time + OUTPOST_POLICE_BAR_TIME)
	if(new_stars != old_stars)
		stars_changed(warrant, old_stars, new_stars)
	wake()
	return new_stars

/**
 * `warrant` went from `old_stars` to `new_stars`: tell the listeners and the HUD. The radio call of a rise is
 * police_life.dm's (tick_life() calls each change of the outpost's alert level), not made here.
 */
/datum/outpost_police/proc/stars_changed(datum/outpost_warrant/warrant, old_stars, new_stars)
	SEND_SIGNAL(src, COMSIG_OUTPOST_POLICE_STARS, warrant.mind, old_stars, new_stars)
	update_hud(warrant.mind)
	if(new_stars >= 4)
		escalate_incident(warrant, new_stars)

/// The warrant of `mind`, made if they have none, with the crew they are on (current_warrant_crew() keeps it current, abuse MF6)
/datum/outpost_police/proc/ensure_warrant(datum/mind/mind)
	var/datum/outpost_warrant/warrant = warrants[mind]
	if(!warrant)
		warrant = new
		warrant.mind = mind
		warrants[mind] = warrant
		RegisterSignal(mind, COMSIG_QDELETING, PROC_REF(on_warrant_mind_deleted), override = TRUE)
		RegisterSignal(mind, COMSIG_MIND_TRANSFERRED, PROC_REF(on_warrant_mind_transferred), override = TRUE)
	if(!warrant.crew)
		set_warrant_crew(warrant, mind.get_reputation_crew())
	return warrant

/datum/outpost_police/proc/on_warrant_mind_deleted(datum/mind/mind)
	SIGNAL_HANDLER
	LAZYREMOVE(case_holds, WEAKREF(mind))
	close_case(mind)
	var/datum/outpost_warrant/warrant = warrants[mind]
	warrants -= mind
	if(warrant)
		warrant.mind = null
		qdel(warrant)

/datum/outpost_police/proc/on_warrant_mind_transferred(datum/mind/mind, mob/previous_body)
	SIGNAL_HANDLER
	clear_outpost_wanted_alert(previous_body)
	update_hud(mind)

/**
 * The crew `warrant`'s holder is on now, kept on the warrant (abuse MF6): the fine, the embargo and the accomplices
 * follow it, never a crew the holder has left or been kicked from. Leaving dodges nothing (M7): with no crew there
 * is nobody to pay, and an unpaid fine is jail. Null if they have no crew.
 */
/datum/outpost_police/proc/current_warrant_crew(datum/outpost_warrant/warrant)
	var/datum/voidcrew_crew_record/current = warrant?.mind?.get_reputation_crew()
	if(QDELETED(current))
		current = null
	if(warrant && warrant.crew != current)
		warrant.crew = null
		set_warrant_crew(warrant, current)
	return current

/// Remembers `crew` on `warrant` and watches for the record being deleted
/datum/outpost_police/proc/set_warrant_crew(datum/outpost_warrant/warrant, datum/voidcrew_crew_record/crew)
	if(QDELETED(crew))
		return
	warrant.crew = crew
	watch_crew(crew)

/datum/outpost_police/proc/watch_crew(datum/voidcrew_crew_record/crew)
	if(crew in watched_crews)
		return
	watched_crews += crew
	RegisterSignal(crew, COMSIG_QDELETING, PROC_REF(on_crew_deleted))

/datum/outpost_police/proc/on_crew_deleted(datum/voidcrew_crew_record/crew)
	SIGNAL_HANDLER
	watched_crews -= crew
	for(var/datum/mind/mind as anything in warrants)
		var/datum/outpost_warrant/warrant = warrants[mind]
		if(warrant?.crew == crew)
			warrant.crew = null
	var/datum/outpost_incident/incident = incidents[crew]
	if(incident)
		end_incident(incident)

/// `item` is evidence on `warrant`: newest last, the oldest out past OUTPOST_POLICE_EVIDENCE_MAX
/datum/outpost_police/proc/note_evidence(datum/outpost_warrant/warrant, obj/item/item)
	var/datum/weakref/ref = WEAKREF(item)
	if(!ref)
		return
	if(!warrant.evidence)
		warrant.evidence = list()
	warrant.evidence -= ref
	warrant.evidence += ref
	while(length(warrant.evidence) > OUTPOST_POLICE_EVIDENCE_MAX)
		warrant.evidence.Cut(1, 2)

/// `victim` was hit by this warrant's holder just now: a death inside OUTPOST_POLICE_KILL_WINDOW is theirs
/datum/outpost_police/proc/record_victim(datum/outpost_warrant/warrant, mob/living/victim)
	if(!warrant.recent_victims)
		warrant.recent_victims = list()
	prune_victims(warrant)
	warrant.recent_victims[WEAKREF(victim)] = world.time
	while(length(warrant.recent_victims) > 24)
		warrant.recent_victims.Cut(1, 2)

/datum/outpost_police/proc/prune_victims(datum/outpost_warrant/warrant)
	if(!length(warrant.recent_victims))
		return
	for(var/datum/weakref/ref as anything in warrant.recent_victims.Copy())
		if(world.time - warrant.recent_victims[ref] > OUTPOST_POLICE_KILL_WINDOW)
			warrant.recent_victims -= ref

// =========================================================================
// HEAT AND STARS
// =========================================================================

/// Stars (0 to 5) a given heat is worth
/datum/outpost_police/proc/stars_of(heat)
	var/list/thresholds = OUTPOST_POLICE_STAR_HEAT
	. = 0
	for(var/star in 1 to length(thresholds))
		if(heat >= thresholds[star])
			. = star

/// Heat after `crime` on top of `heat`: its points up to its ceiling, never below its floor, never past the cap
/datum/outpost_police/proc/heat_after(heat, crime)
	var/list/entry = GLOB.outpost_crimes[crime]
	if(!entry)
		return heat
	var/list/thresholds = OUTPOST_POLICE_STAR_HEAT
	var/points = entry[1]
	var/ceiling_stars = entry[2]
	var/floor_stars = entry[3]
	var/top = ceiling_stars < 5 ? thresholds[ceiling_stars + 1] - 1 : OUTPOST_POLICE_HEAT_CAP
	var/new_heat = heat
	if(points)
		new_heat = max(heat, min(heat + points, top))
	if(floor_stars)
		new_heat = max(new_heat, thresholds[floor_stars])
	return min(new_heat, OUTPOST_POLICE_HEAT_CAP)

/// The prior a faded warrant left, worn down linearly over OUTPOST_POLICE_PRIOR_TIME
/datum/outpost_police/proc/current_prior(datum/outpost_warrant/warrant)
	if(warrant.prior <= 0)
		return 0
	var/elapsed = world.time - warrant.prior_set_at
	if(elapsed >= OUTPOST_POLICE_PRIOR_TIME)
		return 0
	return round(warrant.prior * (1 - elapsed / OUTPOST_POLICE_PRIOR_TIME))

/// Stars `who` has here, 0 to 5
/datum/outpost_police/proc/get_stars(datum/mind/who)
	var/datum/outpost_warrant/warrant = warrants[who]
	return warrant ? stars_of(warrant.heat) : 0

/// `who`'s warrant here, or null
/datum/outpost_police/proc/get_warrant(datum/mind/who)
	return warrants[who]

/**
 * How hard officers may go at `target`: POLICE_FORCE_* (NONE for no mind, in custody or dead). With `officer`, what
 * that officer knows counts too: a crime it saw and has not yet got out on the radio (officer_knows()).
 */
/datum/outpost_police/proc/force_level(mob/living/target, mob/living/officer)
	if(!target?.mind || target.stat == DEAD || in_custody(target))
		return POLICE_FORCE_NONE
	var/stars = officer ? officer_knows(officer, target.mind) : get_stars(target.mind)
	switch(stars)
		if(0)
			return POLICE_FORCE_NONE
		if(1)
			return POLICE_FORCE_ARREST
		if(2)
			return POLICE_FORCE_STUN
	return POLICE_FORCE_LETHAL

/**
 * Whether `user` is refused service here (shops, the permit desk, the checkpoint): stars, a bar, or crew
 * of an embargoed ship.
 */
/datum/outpost_police/proc/is_barred(mob/user)
	if(!user?.mind || !outpost)
		return FALSE
	if(get_stars(user.mind) >= 1)
		return TRUE
	return barred_by_record(user)

/// Whether a faded record's bar, or an embargo on their crew's ship, refuses `user`
/datum/outpost_police/proc/barred_by_record(mob/user)
	if(!user?.mind || !outpost)
		return FALSE
	var/datum/outpost_warrant/warrant = warrants[user.mind]
	if(warrant && warrant.barred_until > world.time)
		return TRUE
	var/datum/voidcrew_crew_record/crew = user.mind.get_reputation_crew()
	for(var/datum/team/voidcrew/team in crew?.teams)
		if(team.ship && outpost.is_ship_embargoed(team.ship))
			return TRUE
	return FALSE

/// An officer (or the checkpoint's scan) sees `who` at `where` now
/datum/outpost_police/proc/note_seen(datum/mind/who, turf/where)
	var/datum/outpost_warrant/warrant = warrants[who]
	if(!warrant)
		return
	var/was_unseen = warrant.unseen_since
	warrant.last_seen_at = world.time
	warrant.last_seen_turf = where
	warrant.unseen_since = 0
	if(was_unseen)
		update_hud(who)

/// Warrants of one star or more whose holder is at this outpost
/datum/outpost_police/proc/suspects_at_outpost()
	. = list()
	for(var/datum/mind/mind as anything in warrants)
		var/datum/outpost_warrant/warrant = warrants[mind]
		if(!warrant || stars_of(warrant.heat) < 1)
			continue
		if(holder_at_outpost(mind.current))
			. += warrant

/// Whether `body` is a living mob standing in this outpost's concourse, lobby, hangars or a ship docked in one
/datum/outpost_police/proc/holder_at_outpost(mob/body)
	if(!isliving(body))
		return FALSE
	var/turf/where = get_turf(body)
	return !!where && get_trader_outpost_for_turf(where) == outpost

/// `who`'s heat goes to 0; their prior stays. `served`: they did their time (a bar from an earlier record stays);
/// not served (an admin lifting it, a case dropped): a bar goes too. An emptied warrant is dropped on the next tick.
/datum/outpost_police/proc/close_warrant(datum/mind/who, served)
	var/datum/outpost_warrant/warrant = warrants[who]
	if(!warrant)
		return
	var/old_stars = stars_of(warrant.heat)
	if(warrant.peak > 0)
		warrant_ended(warrant, served ? "served" : "closed")
	warrant.heat = 0
	warrant.peak = 0
	warrant.unseen_since = 0
	warrant.away_since = 0
	warrant.fine_level = 0
	warrant.evidence = null
	if(!served)
		warrant.barred_until = 0
	if(old_stars)
		stars_changed(warrant, old_stars, 0)
	else
		update_hud(who)
	wake()

/// An admin lifts `who`'s record here: warrant, prior and bar. A prisoner's cell lets them out on its next tick.
/datum/outpost_police/proc/admin_lift(datum/mind/who)
	var/datum/outpost_warrant/warrant = warrants[who]
	if(!warrant)
		return
	if(warrant.peak > 0)
		warrant_ended(warrant, "closed")
	remove_warrant(warrant)

/**
 * An admin puts `who` on the wanted list here at `stars` (1-5): the heat that earns exactly those stars, seen
 * now, and everything a counted crime brings after it (the alert, the embargo at four and five, the tick).
 */
/datum/outpost_police/proc/admin_set_stars(datum/mind/who, stars)
	if(!who)
		return
	var/list/star_heat = OUTPOST_POLICE_STAR_HEAT
	var/datum/outpost_warrant/warrant = ensure_warrant(who)
	var/old_stars = stars_of(warrant.heat)
	warrant.heat = star_heat[clamp(stars, 1, 5)]
	warrant.peak = max(warrant.peak, warrant.heat)
	warrant.last_crime_at = world.time
	warrant.last_seen_at = world.time
	warrant.unseen_since = 0
	warrant.away_since = 0
	var/mob/body = who.current
	if(body)
		warrant.last_seen_turf = get_turf(body)
	var/new_stars = stars_of(warrant.heat)
	if(new_stars >= 3)
		warrant.barred_until = max(warrant.barred_until, world.time + OUTPOST_POLICE_BAR_TIME)
	if(new_stars != old_stars)
		stars_changed(warrant, old_stars, new_stars)
	else
		update_hud(who)
	wake()

/// Drops `warrant` and clears its holder's HUD
/datum/outpost_police/proc/remove_warrant(datum/outpost_warrant/warrant)
	var/datum/mind/mind = warrant.mind
	if(mind)
		warrants -= mind
	if(!QDELETED(mind))
		UnregisterSignal(mind, list(COMSIG_QDELETING, COMSIG_MIND_TRANSFERRED))
		update_hud(mind)
	qdel(warrant)

/// A record ended: count it
/datum/outpost_police/proc/warrant_ended(datum/outpost_warrant/warrant, how)
	var/mob/living/body = warrant.mind?.current
	record_metric(METRIC_COMBAT, "police_warrant_ended", actor = isliving(body) ? body : null, subject = how, points = stars_of(warrant.peak), quantity = warrant.officers_killed)

// =========================================================================
// THE ONE-SECOND TICK
// =========================================================================

/// Once a second (police_core.dm tick()): sightings, fading, priors, bars, accomplices, pending reports
/datum/outpost_police/proc/tick_warrants()
	if(QDELETED(src) || !outpost)
		return
	process_pending_reports()
	var/list/stand_at_four = list()
	for(var/datum/mind/mind as anything in warrants.Copy())
		var/datum/outpost_warrant/warrant = warrants[mind]
		if(!warrant)
			continue
		if(QDELETED(mind))
			warrants -= mind
			qdel(warrant)
			continue
		tick_warrant(warrant)
		if(QDELETED(warrant))
			continue
		var/stars = stars_of(warrant.heat)
		if(stars >= 4)
			// Holds the embargo while they stay at four or five (it lapses and is laid again after its time)
			escalate_incident(warrant, stars)
			// Only a leader alive and free at the outpost makes accomplices: one in a cell (or our cuffs), or a body,
			// does not keep sweeping up the crew that comes for them (review-1 M2)
			var/mob/living/leader_body = mind.current
			if(holder_at_outpost(leader_body) && leader_body.stat != DEAD && !in_custody(leader_body))
				stand_at_four += warrant
	for(var/datum/outpost_warrant/leader as anything in stand_at_four)
		abet_crew(leader)
	for(var/datum/voidcrew_crew_record/crew as anything in incidents.Copy())
		var/datum/outpost_incident/incident = incidents[crew]
		if(!incident)
			continue
		if(world.time >= incident.ends_at)
			end_incident(incident)
			continue
		sync_incident(incident)

/// One warrant's clocks for one second
/datum/outpost_police/proc/tick_warrant(datum/outpost_warrant/warrant)
	var/mob/living/body = warrant.mind.current
	if(!isliving(body))
		body = null
	prune_victims(warrant)
	if(body && in_custody(body))
		// The cells keep the prisoner's time (police_cell.dm); nothing fades and nothing is dropped meanwhile
		return
	var/turf/where = body ? get_turf(body) : null
	var/here = !!where && get_trader_outpost_for_turf(where) == outpost
	var/downed = !body || body.stat == DEAD || body.stat == HARD_CRIT
	// In crit at the outpost with an arrest on its way to cuff them where they lie (owner decision 34): as good as in
	// custody, so nothing fades before the cuffs are on. Lying there uncuffed, the warrant would drain as "away" and
	// the arrest close at no stars, or a three-star suspect fall to two and be fined instead of jailed (decision 37).
	if(here && downed && body && body.stat != DEAD && arrest_on(body))
		return
	var/old_stars = stars_of(warrant.heat)
	var/was_away = !!warrant.away_since
	var/was_unseen = !!warrant.unseen_since

	// Away: not at the outpost, or dead or in crit. Cleared only by a return.
	if(!here || downed)
		if(!warrant.away_since)
			warrant.away_since = world.time
	else
		warrant.away_since = 0
	// Seen: an officer sees them, or a checkpoint scan has them. Cleared only by a sighting.
	var/seen = FALSE
	if(here && !downed)
		seen = suspect_seen(body)
	if(seen)
		warrant.last_seen_at = world.time
		warrant.last_seen_turf = where
		warrant.unseen_since = 0
	else if(!warrant.unseen_since)
		warrant.unseen_since = world.time
	if(was_away != !!warrant.away_since || was_unseen != !!warrant.unseen_since)
		update_hud(warrant.mind)

	// A faded record's bar runs from the last moment at three stars
	if(old_stars >= 3)
		warrant.barred_until = max(warrant.barred_until, world.time + OUTPOST_POLICE_BAR_TIME)
	// A barred person an officer sees on secured turf is an arrest
	if(here && !downed && seen && old_stars < 2 && barred_by_record(body) && outpost.is_secured_turf(where))
		count_crime(body, OUTPOST_CRIME_TRESPASS)
		old_stars = stars_of(warrant.heat)

	// Fading
	if(warrant.heat > 0)
		var/draining = FALSE
		if(warrant.away_since && world.time - warrant.away_since >= OUTPOST_POLICE_AWAY_GRACE)
			draining = TRUE
		else if(!warrant.away_since && !seen && warrant.unseen_since && old_stars <= 2)
			var/hide_time = old_stars >= 2 ? OUTPOST_POLICE_HIDE_2 : OUTPOST_POLICE_HIDE_1
			if(world.time - warrant.unseen_since >= hide_time)
				draining = TRUE
		if(draining)
			warrant.heat = max(0, warrant.heat - OUTPOST_POLICE_FADE_PER_SECOND)
			if(warrant.heat <= 0)
				warrant_faded(warrant)
			var/new_stars = stars_of(warrant.heat)
			if(new_stars != old_stars)
				stars_changed(warrant, old_stars, new_stars)

	if(warrant.heat <= 0 && current_prior(warrant) <= 0 && warrant.barred_until <= world.time)
		remove_warrant(warrant)

/// Whether an open arrest is on `body` (cuffed or not yet)
/datum/outpost_police/proc/arrest_on(mob/living/body)
	if(!body?.mind)
		return FALSE
	var/datum/outpost_police_case/case = cases[body.mind]
	return !QDELETED(case) && case.get_suspect() == body

/// Heat just reached 0 by fading: the peak becomes the prior
/datum/outpost_police/proc/warrant_faded(datum/outpost_warrant/warrant)
	if(warrant.peak > 0)
		warrant.prior = warrant.peak
		warrant.prior_set_at = world.time
		warrant_ended(warrant, "faded")
	warrant.peak = 0
	warrant.evidence = null
	warrant.fine_level = 0

/// Whether an officer sees `body` now, or a checkpoint scan has them
/datum/outpost_police/proc/suspect_seen(mob/living/body)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != DEAD && perception.sees(officer, body))
			return TRUE
	return perception.scanned(body)

/// Every living crewmate of someone at four stars or more, at the outpost, is an accomplice: two stars, arrested
/datum/outpost_police/proc/abet_crew(datum/outpost_warrant/leader)
	var/datum/voidcrew_crew_record/crew = current_warrant_crew(leader)
	if(QDELETED(crew))
		return
	for(var/datum/mind/mate as anything in crew.minds)
		if(mate == leader.mind || get_stars(mate) >= 2)
			continue
		var/mob/living/body = mate.current
		if(!isliving(body) || body.stat == DEAD || !holder_at_outpost(body))
			continue
		count_crime(body, OUTPOST_CRIME_ACCOMPLICE, derived = TRUE)

// =========================================================================
// KILLINGS
// =========================================================================

/// Starts listening for deaths (called once from police_core.dm's New())
/datum/outpost_police/proc/hook_events()
	if(events_hooked)
		return
	events_hooked = TRUE
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_wanted_death))

/**
 * Someone died. An officer of ours going down is announced whoever did it; a visitor, an ambient person or an
 * officer who dies within OUTPOST_POLICE_KILL_WINDOW of a counted hit from someone with a record at this
 * outpost is that person's MURDER, KILL_CIVILIAN or KILL_OFFICER. The hit was seen already, so the killing is
 * not tested for witnesses again.
 */
/datum/outpost_police/proc/on_wanted_death(datum/source, mob/living/dead, gibbed)
	SIGNAL_HANDLER
	if(QDELETED(src) || !outpost || !istype(dead))
		return
	// The outpost's recovery tracks its dead (recovery_core.dm, R2); it checks the turf itself
	outpost.recovery?.note_death(dead)
	var/is_ours = (dead in officers) && perception.is_officer(dead)
	if(!is_ours && !length(warrants) && !length(pending_reports))
		return
	var/crime
	if(is_ours)
		crime = OUTPOST_CRIME_KILL_OFFICER
	else if(perception.is_officer(dead))
		return
	else
		var/turf/where = get_turf(dead)
		if(!where || get_trader_outpost_for_turf(where) != outpost)
			return
		if(dead.mind)
			crime = OUTPOST_CRIME_MURDER
		else if(istype(dead, OUTPOST_TRADER_MOB)) // a trader or checkpoint guard (spec-rehydrate 1.4)
			crime = OUTPOST_CRIME_KILL_STAFF
		else if(istype(dead, /mob/living/carbon/human/npc/ambient_npc))
			crime = OUTPOST_CRIME_KILL_CIVILIAN
		else
			return
	var/datum/weakref/dead_ref = WEAKREF(dead)
	var/mob/living/killer
	// Minds whose counted hit made this killing theirs now: a pending report of theirs does not count it again
	var/list/datum/mind/counted = list()
	for(var/datum/mind/mind as anything in warrants.Copy())
		var/datum/outpost_warrant/warrant = warrants[mind]
		var/hit_at = warrant?.recent_victims?[dead_ref]
		if(!hit_at || world.time - hit_at > OUTPOST_POLICE_KILL_WINDOW)
			continue
		warrant.recent_victims -= dead_ref
		var/mob/living/offender = mind.current
		if(!isliving(offender))
			continue
		counted += mind
		count_crime(offender, crime, dead, derived = TRUE)
		if(is_ours)
			killer = offender
			warrant.officers_killed++
			officer_killed_by(warrant)
	// A hit still waiting on its witness's call: the killing goes with it, and counts if the report is made
	for(var/datum/outpost_pending_report/report as anything in pending_reports)
		if(!report_hit(report, dead_ref) || world.time - report.created_at > OUTPOST_POLICE_KILL_WINDOW)
			continue
		var/mob/living/offender = report.offender?.resolve()
		if(offender?.mind && (offender.mind in counted))
			continue
		var/already = FALSE
		for(var/list/followup as anything in report.followups)
			if(followup[2] == dead_ref)
				already = TRUE
		if(!already)
			LAZYADD(report.followups, list(list(crime, dead_ref)))
	if(is_ours)
		SEND_SIGNAL(src, COMSIG_OUTPOST_POLICE_OFFICER_DOWN, dead, killer)

/// `warrant`'s holder killed an officer: the embargo of their crew runs longer
/datum/outpost_police/proc/officer_killed_by(datum/outpost_warrant/warrant)
	record_metric(METRIC_COMBAT, "police_officer_killed", actor = warrant.mind?.current, quantity = 1)
	var/datum/voidcrew_crew_record/crew = current_warrant_crew(warrant)
	var/datum/outpost_incident/incident = crew ? incidents[crew] : null
	if(!incident)
		return
	incident.officers_killed++
	incident.ends_at = min(incident.ends_at + OUTPOST_POLICE_EMBARGO_PER_KILL, incident.started_at + OUTPOST_POLICE_EMBARGO_MAX)
	for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(incident.crew))
		if(outpost.is_ship_embargoed(ship))
			outpost.embargoed_ships[ship] = incident.ends_at

// =========================================================================
// OFFICERS STRUCK (abuse M3; called from the officer's body, police_units.dm)
// =========================================================================

/**
 * An officer was hit (relay_attackers): a stamina weapon or disabler, or a weapon, bullet or bomb (`armed`), is
 * ASSAULT_OFFICER; a shove, or bare fists, is RESIST (abuse M3). `source` is the weapon when the caller knows it;
 * without it (and when not `armed`) the attacker's held weapon is taken.
 */
/datum/outpost_police/proc/officer_struck(mob/living/officer, atom/attacker, attack_flags, obj/item/source, armed = FALSE)
	SHOULD_NOT_SLEEP(TRUE)
	if(ismecha(attacker))
		armed = TRUE
	var/mob/living/hitter = outpost_living_attacker(attacker)
	if(!hitter || hitter == officer)
		return
	if(!source && !armed)
		source = held_weapon_of(hitter)
	var/crime
	if(attack_flags & ATTACKER_STAMINA_ATTACK)
		crime = OUTPOST_CRIME_ASSAULT_OFFICER
	else if(attack_flags & ATTACKER_SHOVING)
		crime = OUTPOST_CRIME_RESIST
	else if(attack_flags & ATTACKER_DAMAGING_ATTACK)
		crime = (armed || source) ? OUTPOST_CRIME_ASSAULT_OFFICER : OUTPOST_CRIME_RESIST
	else
		return
	report_crime(hitter, crime, officer, crime == OUTPOST_CRIME_ASSAULT_OFFICER ? source : null)

/// Someone tried to cuff an officer: ASSAULT_OFFICER (abuse M3)
/datum/outpost_police/proc/officer_cuff_attempt(mob/living/officer, mob/living/user)
	SHOULD_NOT_SLEEP(TRUE)
	if(!isliving(user) || user == officer)
		return
	report_crime(user, OUTPOST_CRIME_ASSAULT_OFFICER, officer)

/// The weapon `hitter` holds, if it is one
/datum/outpost_police/proc/held_weapon_of(mob/living/hitter)
	var/obj/item/held = hitter.get_active_held_item()
	if(held && (held.force > 0 || istype(held, /obj/item/gun)))
		return held
	return null

// =========================================================================
// THE FINE (abuse M6, M7)
// =========================================================================

/// What `warrant` owes: the fine for its stars at booking (1 or 2), times the zone. The level is fixed at the first ask.
/datum/outpost_police/proc/fine_amount(datum/outpost_warrant/warrant)
	if(!warrant.fine_level)
		warrant.fine_level = clamp(stars_of(warrant.heat), 1, 2)
	var/list/fines = OUTPOST_POLICE_FINES
	return round(fines[warrant.fine_level] * profile.fine_multiplier)

/**
 * The fine for `warrant`'s stars and the zone, from the ship accounts of the crew its holder is on now (abuse MF6),
 * pooled, richest first, all or nothing. TRUE with the money gone, or FALSE with nothing taken. Never sleeps; no
 * debt anywhere.
 */
/datum/outpost_police/proc/charge_fine(datum/outpost_warrant/warrant)
	SHOULD_NOT_SLEEP(TRUE)
	if(!warrant || QDELETED(current_warrant_crew(warrant)))
		return FALSE
	var/amount = fine_amount(warrant)
	if(amount <= 0)
		return TRUE
	var/list/datum/bank_account/accounts = list()
	var/pool = 0
	for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(warrant.crew))
		var/datum/bank_account/account = ship.ship_account
		// A locked account can't be spent from, whatever it holds
		if(!account || (account in accounts) || account.account_balance <= 0 || !account.has_money(account.account_balance))
			continue
		accounts += account
		pool += account.account_balance
	if(pool < amount)
		return FALSE
	// Richest first
	var/list/datum/bank_account/ordered = list()
	while(length(accounts))
		var/datum/bank_account/richest = accounts[1]
		for(var/datum/bank_account/account as anything in accounts)
			if(account.account_balance > richest.account_balance)
				richest = account
		ordered += richest
		accounts -= richest
	var/reason = "Fine: [profile.force_name]"
	var/remaining = amount
	var/list/taken = list()
	for(var/datum/bank_account/account as anything in ordered)
		var/part = min(remaining, account.account_balance)
		if(part <= 0)
			continue
		if(!account.adjust_money(-part, reason))
			for(var/datum/bank_account/refund as anything in taken)
				refund.adjust_money(taken[refund], "[reason] (refunded)")
			return FALSE
		taken[account] = part
		remaining -= part
		if(remaining <= 0)
			break
	if(remaining > 0)
		for(var/datum/bank_account/refund as anything in taken)
			refund.adjust_money(taken[refund], "[reason] (refunded)")
		return FALSE
	return TRUE

/// The ships of `crew`'s hulls that still exist
/datum/outpost_police/proc/crew_ship_list(datum/voidcrew_crew_record/crew)
	. = list()
	for(var/datum/team/voidcrew/team in crew?.teams)
		if(team.ship && !QDELETED(team.ship))
			. += team.ship

// =========================================================================
// FOUR AND FIVE STARS: THE EMBARGO (spec 9; decision 25: at this outpost only, no cutter)
// =========================================================================

/// `warrant` reached four or five stars: its crew's ships are embargoed here
/datum/outpost_police/proc/escalate_incident(datum/outpost_warrant/warrant, stars)
	var/datum/voidcrew_crew_record/crew = current_warrant_crew(warrant)
	if(QDELETED(crew))
		return
	var/datum/outpost_incident/incident = incidents[crew]
	if(incident && world.time >= incident.ends_at)
		end_incident(incident)
		incident = null
	if(!incident)
		incident = new
		incident.crew = crew
		incident.started_at = world.time
		incident.officers_killed = warrant.officers_killed
		incidents[crew] = incident
		watch_crew(crew)
	if(stars <= incident.stars)
		return
	incident.stars = stars
	var/list/lengths = OUTPOST_POLICE_EMBARGO
	var/length_for = lengths[stars - 3] + incident.officers_killed * OUTPOST_POLICE_EMBARGO_PER_KILL
	incident.ends_at = min(max(incident.ends_at, world.time + length_for), incident.started_at + OUTPOST_POLICE_EMBARGO_MAX)
	for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(crew))
		outpost.embargo_ship(ship, max(1, incident.ends_at - world.time))
		incident.ships_embargoed |= WEAKREF(ship)
	sync_incident(incident)
	record_metric(METRIC_COMBAT, "police_embargo", actor = warrant.mind?.current, points = stars, quantity = round((incident.ends_at - world.time) / (1 MINUTES)))

/// Crewmates and ships of an embargoed crew at this outpost
/datum/outpost_police/proc/sync_incident(datum/outpost_incident/incident)
	// A ship the crew got during the incident is embargoed once, for what is left of it
	var/remaining = incident.ends_at - world.time
	if(remaining > 0)
		for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(incident.crew))
			var/datum/weakref/ship_ref = WEAKREF(ship)
			if(ship_ref in incident.ships_embargoed)
				continue
			incident.ships_embargoed += ship_ref
			outpost.embargo_ship(ship, remaining)
	// Crewmates who walked in past the embargo are barred from secured turf: an arrest
	for(var/datum/mind/mate as anything in incident.crew.minds)
		var/mob/living/body = mate.current
		if(!isliving(body) || body.stat == DEAD || warrants[mate] || !holder_at_outpost(body))
			continue
		if(outpost.is_secured_turf(get_turf(body)) && barred_by_record(body) && suspect_seen(body))
			count_crime(body, OUTPOST_CRIME_TRESPASS)

/// The incident is over: forget it
/datum/outpost_police/proc/end_incident(datum/outpost_incident/incident)
	if(incidents[incident.crew] == incident)
		incidents -= incident.crew
	incident.crew = null
	qdel(incident)

