/**
 * The Outpost Manipulator's Prison section: everything about a prison wing an admin needs to
 * test it without waiting, from spawning prisoners to breaking the lights. R_ADMIN only, through
 * the manipulator's own authorization, and every action is logged.
 */

/// Most debt prison_debt sets, in credits
#define OUTPOST_ADMIN_PRISON_MAX_DEBT 1000000
/// Longest prison_subdue and prison_outage, in seconds
#define OUTPOST_ADMIN_PRISON_MAX_SECONDS 3600

/// Admin actions handled here; every one names its params in the comment beside it
GLOBAL_LIST_INIT(outpost_admin_prison_actions, list(
	"prison_intake", // {open}
	"prison_spawn", // {}
	"prison_fill", // {}
	"prison_release", // {ref}
	"prison_kill", // {ref}
	"prison_remove", // {ref}
	"prison_set", // {ref, field: hunger|grime|health|sentence|mood|locked_in|lockdown, value}: lockdown 0 clears it
	"prison_all", // {what: starve|feed|dirty|clean|hurt|heal|enrage|calm}
	"prison_advance", // {minutes}
	"prison_pay_now", // {}
	"prison_mess", // {}
	"prison_break_lights", // {}
	"prison_power", // {on}
	"prison_fight", // {ref}: that prisoner and the nearest other who can
	"prison_riot", // {}: everyone able joins
	"prison_calm", // {}: ends riots and fights, moods back to PRISONER_MOOD_START
	"prison_breakout", // {ref}: that prisoner riots alone and goes for the ways out of the cell block
	"prison_crew_home", // {mode: auto|home|away}: crew_home_override
	"prison_debt", // {amount}: the treasury's debt, 0 clears it
	"prison_transfer", // {}: transfers the rioters out now, as a sit-in nobody came back for
	"prison_subdue", // {seconds}: the quiet after a riot, 0 ends it
	"prison_fill_hatch", // {}: every serving hatch to capacity
	"prison_spawn_rat", // {}
	"prison_outage", // {seconds}: the power outage debt
	"prison_wreck", // {ref}: that prisoner starts wrecking their cell
	"prison_researcher", // {}: the researcher beams in with an offer, past the visit's gates
	"prison_experiment", // {ref, form: hulk|fly|nightmare|changeling}: that prisoner is dosed now
	"prison_changeling_stage", // {stage: burst|horror}: the changeling event skips ahead
	"prison_experiment_end", // {}: ends the experiment with no fee
	"prison_incident", // {kind: stab|snap|fight, tell}: a wildcard incident now, past its clock; tell 1 plays the tell first
	"prison_wing_event", // {kind: lights|scrubber|toilet}: a wing event now, past its clock
	"prison_horror", // {what: kill|regen}: kills the horror for good, or drops it to regenerate (gets it up if it is down)
	// The extras (outpost_prison_extras.dm); each package validates its own params
	"prison_guard_spawn", // {}: a free guard, ignoring the cap
	"prison_guard_remove", // {ref}
	"prison_guard_down", // {ref}
	"prison_rep", // {key, score}: -10 to 10
	"prison_affinity", // {a_ref, b_ref, value}: -100 to 100
	"prison_birthday", // {ref}
	"prison_party", // {ref}: a cake at the birthday prisoner's feet, and the party starts
	"prison_cards", // {}: a card game at the table with the deck, if two can play
	"prison_stash", // {cell, kind: shiv|pruno|clear}
	"prison_mail", // {ref, kind: good|kid|news|bad|contraband}: a letter for that prisoner on the office table
	"prison_mail_wave", // {}: a mail pod now, with letters for a share of the prisoners
	"prison_lead", // {ref}: that prisoner carries a lead and the wing is ready to give one
	// Bounty prisoners (outpost_prison_bounty.dm)
	"prison_bounty_admit", // {id}: that pool record beams into the first free cell now
	"prison_bounty_make", // {tier}: a test record of that tier joins the pool, reserved for this wing
	"prison_bounty_intake", // {setting: all|no_most_wanted|none}
	"prison_bounty_clear", // {}: every record in the pool is closed
))

/// prison_crew_home modes and the crew_home_override each sets
GLOBAL_LIST_INIT(outpost_admin_prison_crew_modes, list("auto" = null, "home" = TRUE, "away" = FALSE))

/// The running prison of an outpost, if it has one
/obj/structure/overmap/dynamic/player_outpost/proc/running_prison()
	var/datum/outpost_upgrade/prison/wing = outpost_upgrades["prison"]
	return istype(wing) && !QDELETED(wing.prison) ? wing.prison : null

/// The selected outpost's `prison` entry for OutpostManipulator.tsx, or null without a prison
/datum/outpost_manipulator/proc/prison_admin_data(obj/structure/overmap/dynamic/player_outpost/home)
	var/datum/outpost_prison/prison = home.running_prison()
	return prison?.admin_payload()

/datum/outpost_manipulator/proc/manage_prison(obj/structure/overmap/dynamic/player_outpost/home, mob/user, action, list/params)
	if(!valid_selection(home, user))
		return
	error = null
	var/datum/outpost_prison/prison = home.running_prison()
	if(!prison)
		error = "This outpost has no prison wing."
		return
	switch(action)
		if("prison_intake")
			var/open = admin_bool(params["open"])
			if(isnull(open))
				error = "Invalid intake setting."
				return
			prison.set_intake(open, user)
			record(user, home, "[open ? "open" : "close"] prison intake")
		if("prison_spawn")
			// Forced: an admin spawn ignores the cell's ready time and a running experiment
			var/mob/living/basic/outpost_prisoner/arrival = prison.admit_next(TRUE)
			if(!arrival)
				error = "No free cell."
				return
			record(user, home, "beam prisoner [arrival.real_name] into cell [arrival.cell?.number]")
		if("prison_fill")
			var/count = 0
			while(prison.admit_next(TRUE))
				count++
			if(!count)
				error = "No free cell."
				return
			record(user, home, "fill [count] prison cell\s")
		if("prison_release", "prison_kill", "prison_remove", "prison_set", "prison_fight", "prison_breakout", "prison_wreck")
			var/mob/living/basic/outpost_prisoner/prisoner = locate(params["ref"]) in prison.prisoners
			if(QDELETED(prisoner))
				error = "That prisoner is gone."
				return
			switch(action)
				if("prison_wreck")
					if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT || !prisoner.cell)
						error = "Only a living prisoner with a cell can wreck it."
						return
					if(prisoner.trouble)
						error = "That prisoner is already in trouble."
						return
					prison.start_wreck(prisoner)
					record(user, home, "have prisoner [prisoner.real_name] wreck cell [prisoner.cell.number]")
				if("prison_fight")
					if(!prisoner.can_join_riot() || prisoner.trouble)
						error = "That prisoner can't fight now."
						return
					var/mob/living/basic/outpost_prisoner/partner = prison.nearest_fight_partner(prisoner)
					if(!partner)
						error = "No other prisoner can fight."
						return
					if(!prison.start_fight(prisoner, partner))
						error = "The fight did not start."
						return
					record(user, home, "start a prison fight between [prisoner.real_name] and [partner.real_name]")
				if("prison_breakout")
					if(prisoner.trouble == PRISONER_TROUBLE_LOOSE || prisoner.trouble == PRISONER_TROUBLE_BREAKOUT)
						error = "That prisoner is already breaking out."
						return
					if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
						error = "Only a living prisoner in the wing can break out."
						return
					if(!prison.start_breakout(prisoner))
						error = "That prisoner can't break out now: shut in a cell, down, cuffed, or outside the cell block."
						return
					record(user, home, "have prisoner [prisoner.real_name] break out of the cell block")
				if("prison_release")
					if(prisoner.phase != PRISONER_PRESENT || prisoner.stat == DEAD)
						error = "Only a living prisoner in the wing can be released."
						return
					if(hascall(prison, "held_for_experiment") && call(prison, "held_for_experiment")(prisoner))
						error = "The experiment still needs this prisoner. End it first."
						return
					var/bonus = prison.release(prisoner)
					record(user, home, "release prisoner [prisoner.real_name] (+[bonus] cr)")
				if("prison_kill")
					if(prisoner.stat == DEAD)
						error = "Already dead."
						return
					prisoner.death()
					record(user, home, "kill prisoner [prisoner.real_name]")
				if("prison_remove")
					var/removed_name = prisoner.real_name
					close_bounty_record(prisoner, BOUNTY_RECORD_CLOSED)
					prison.forget(prisoner)
					qdel(prisoner)
					record(user, home, "remove prisoner [removed_name] without a bonus")
				if("prison_set")
					var/field = params["field"]
					var/value = admin_number(params["value"])
					if(!(field in list("hunger", "grime", "health", "sentence", "mood", "locked_in", "lockdown")) || isnull(value))
						error = "Invalid prisoner setting."
						return
					if(!prison.admin_set(prisoner, field, value))
						error = "That prisoner can't take that setting."
						return
					record(user, home, "set prisoner [prisoner.real_name]'s [field] to [value]")
		if("prison_all")
			var/what = params["what"]
			if(!(what in list("starve", "feed", "dirty", "clean", "hurt", "heal", "enrage", "calm")))
				error = "Invalid prisoner-wide action."
				return
			var/count = prison.admin_all(what)
			record(user, home, "[what] all prisoners ([count])")
		if("prison_riot")
			if(prison.riot_active)
				error = "A riot is already on."
				return
			if(!prison.start_riot("started by an admin", everyone = TRUE))
				error = "Nobody in the cell block can riot."
				return
			record(user, home, "start a prison riot")
		if("prison_calm")
			var/calmed = prison.admin_calm()
			record(user, home, "calm the prison wing ([calmed] prisoner\s)")
		if("prison_advance")
			var/minutes = admin_number(params["minutes"])
			if(isnull(minutes) || minutes != round(minutes) || minutes < 1 || minutes > 60)
				error = "Advance by 1 to 60 whole minutes."
				return
			prison.admin_advance(minutes)
			record(user, home, "advance the prison by [minutes] min")
		if("prison_pay_now")
			var/paid = prison.admin_pay_now()
			record(user, home, "pay a prison minute now ([paid] cr)")
		if("prison_mess")
			var/made = prison.admin_mess()
			record(user, home, "make [made] piece\s of prison mess")
		if("prison_break_lights")
			var/broken = prison.admin_break_lights()
			record(user, home, "break [broken] prison light\s")
		if("prison_power")
			var/on = admin_bool(params["on"])
			if(isnull(on))
				error = "Invalid power setting."
				return
			if(!prison.admin_set_power(on))
				error = "The prison wing has no APC."
				return
			record(user, home, "[on ? "restore" : "cut"] prison power")
		if("prison_crew_home")
			var/mode = params["mode"]
			if(!istext(mode) || !(mode in GLOB.outpost_admin_prison_crew_modes))
				error = "Invalid crew setting."
				return
			prison.crew_home_override = GLOB.outpost_admin_prison_crew_modes[mode]
			record(user, home, "set the prison wing's crew presence to [mode]")
		if("prison_debt")
			var/amount = admin_number(params["amount"])
			if(isnull(amount) || amount != round(amount) || amount < 0 || amount > OUTPOST_ADMIN_PRISON_MAX_DEBT)
				error = "Debt is 0 to [OUTPOST_ADMIN_PRISON_MAX_DEBT] whole credits."
				return
			home.ensure_home_services()
			home.treasury.account_debt = amount
			record(user, home, "set the treasury's debt to [amount] cr")
		if("prison_transfer")
			if(!prison.riot_active)
				error = "No riot to transfer."
				return
			prison.transfer_rioters()
			record(user, home, "transfer the prison wing's rioters out")
		if("prison_subdue")
			var/seconds = admin_number(params["seconds"])
			if(isnull(seconds) || seconds != round(seconds) || seconds < 0 || seconds > OUTPOST_ADMIN_PRISON_MAX_SECONDS)
				error = "Subdue for 0 to [OUTPOST_ADMIN_PRISON_MAX_SECONDS] whole seconds."
				return
			prison.set_subdued(seconds)
			record(user, home, seconds ? "subdue the prison wing for [seconds] s" : "end the prison wing's subdued time")
		if("prison_fill_hatch")
			prison.fill_hatches()
			record(user, home, "fill the prison wing's serving hatches")
		if("prison_spawn_rat")
			if(!prison.spawn_rat())
				error = "No rat was placed."
				return
			record(user, home, "spawn a rat in the prison wing")
		if("prison_outage")
			var/seconds = admin_number(params["seconds"])
			if(isnull(seconds) || seconds != round(seconds) || seconds < 0 || seconds > OUTPOST_ADMIN_PRISON_MAX_SECONDS)
				error = "Outage debt is 0 to [OUTPOST_ADMIN_PRISON_MAX_SECONDS] whole seconds."
				return
			prison.outage_debt = seconds
			prison.refresh_conditions()
			record(user, home, "set the prison wing's outage debt to [seconds] s")
		if("prison_researcher")
			if(!hascall(prison, "spawn_researcher"))
				error = "Experiments are not installed."
				return
			var/list/block = prison.experiment_block()
			if(islist(block) && block["researcher_present"])
				error = "The researcher is already here."
				return
			if(prison.admin_experiment_running())
				error = "An experiment is under way."
				return
			// Forced: past the visit's gates (conditions, a member on the level, the wait between visits)
			if(!call(prison, "spawn_researcher")(TRUE) && !prison.admin_researcher_present())
				error = "The researcher did not come."
				return
			record(user, home, "beam in the prison researcher")
		if("prison_experiment")
			var/form = params["form"]
			if(!istext(form) || !(form in list("hulk", "fly", "nightmare", "changeling")))
				error = "Invalid experiment form."
				return
			var/mob/living/basic/outpost_prisoner/subject = locate(params["ref"]) in prison.prisoners
			if(QDELETED(subject))
				error = "That prisoner is gone."
				return
			if(subject.stat == DEAD || subject.phase != PRISONER_PRESENT || subject.trouble == PRISONER_TROUBLE_LOOSE)
				error = "Only a living prisoner in the wing can be dosed."
				return
			if(subject.experiment_subject)
				error = "That prisoner is already a subject."
				return
			if(prison.admin_experiment_running())
				error = "An experiment is under way."
				return
			if(!hascall(prison, "start_experiment"))
				error = "Experiments are not installed."
				return
			if(!call(prison, "start_experiment")(form, subject, TRUE) && !subject.experiment_subject)
				error = "The experiment did not start."
				return
			record(user, home, "start a [form] experiment on prisoner [subject.real_name]")
		if("prison_changeling_stage")
			var/stage = params["stage"]
			if(!istext(stage) || !(stage in list("burst", "horror")))
				error = "Invalid changeling stage."
				return
			var/datum/changeling = prison.admin_changeling_event()
			if(!changeling)
				error = "No changeling event is running."
				return
			var/stage_before = changeling.vars["stage"]
			if(stage_before == "done")
				error = "The changeling event is over."
				return
			if(stage_before == "horror")
				error = "The horror is already out."
				return
			if(stage == "burst" && stage_before != "incubating")
				error = "The host has already burst."
				return
			if(!hascall(changeling, "force_stage"))
				error = "The changeling event can't skip ahead."
				return
			if(!call(changeling, "force_stage")(stage) && changeling.vars["stage"] == stage_before)
				error = "The changeling event did not move on."
				return
			record(user, home, "force the changeling event to its [stage] stage")
		if("prison_experiment_end")
			if(!islist(prison.experiment_block()))
				error = "No experiment to end."
				return
			if(!hascall(prison, "experiment_end_admin"))
				error = "Experiments are not installed."
				return
			if(!call(prison, "experiment_end_admin")() && prison.admin_experiment_running())
				error = "The experiment did not end."
				return
			record(user, home, "end the prison experiment without a fee")
		if("prison_incident")
			var/kind = params["kind"]
			if(!istext(kind) || !(kind in list("stab", "snap", "fight")))
				error = "Invalid incident kind."
				return
			var/with_tell = admin_bool(params["tell"]) == TRUE
			var/refusal = prison.wildcard_refusal(kind)
			if(refusal)
				error = refusal
				return
			// Past the clock; the tell only when asked for (a fight's argument always plays)
			if(!prison.start_wildcard(kind, skip_tell = !with_tell))
				error = "Nobody in the cell block can do that now."
				return
			record(user, home, "start a prison [kind] incident[with_tell ? " with its tell" : ""]")
		if("prison_wing_event")
			var/kind = params["kind"]
			if(!istext(kind) || !(kind in list("lights", "scrubber", "toilet")))
				error = "Invalid wing event."
				return
			var/refusal = prison.wing_event_refusal(kind)
			if(refusal)
				error = refusal
				return
			if(!prison.start_wing_event(kind))
				error = "The wing event did not start."
				return
			prison.wing_event_admin_started()
			record(user, home, "start a prison wing event ([kind])")
		if("prison_horror")
			var/what = params["what"]
			if(!istext(what) || !(what in list("kill", "regen")))
				error = "Invalid horror action."
				return
			if(!hascall(prison, "admin_horror"))
				error = "Experiments are not installed."
				return
			if(!call(prison, "admin_horror")(what))
				error = "No horror is out."
				return
			record(user, home, what == "kill" ? "kill the prison horror for good" : "force the prison horror's regeneration")
		else
			// The extras' own actions: a log line when done, list("error" = text) when refused
			var/result = prison.extras_admin_act(action, params, user)
			if(islist(result))
				var/list/refusal = result
				error = refusal["error"] || "Invalid prison action."
				return
			if(!istext(result))
				error = "Invalid prison action."
				return
			record(user, home, result)

/// TRUE, FALSE or null for a tgui boolean param (0/1, "0"/"1", true/false)
/datum/outpost_manipulator/proc/admin_bool(value)
	if(istext(value))
		value = text2num(value)
	if(value == 0 || value == 1)
		return value
	return null

/// A finite number from a tgui param, or null
/datum/outpost_manipulator/proc/admin_number(value)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || value != value || value == INFINITY || value == -INFINITY)
		return null
	return value

// ===== PRISON SIDE =====

/// The Prison section's data: everything about the wing and each prisoner
/datum/outpost_prison/proc/admin_payload()
	var/list/cell_rows = list()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		cell_rows += list(list("number" = cell.number, "occupant_ref" = cell.occupant ? REF(cell.occupant) : null))
	var/list/prisoner_rows = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner as anything in roster_order())
		prisoner_rows += list(list(
			"ref" = REF(prisoner),
			"name" = prisoner.real_name,
			"cell" = prisoner.cell?.number || 0,
			"personality" = prisoner.personality,
			"crime" = prisoner.crime,
			"activity" = prisoner.admin_activity_text(),
			"hunger" = round(prisoner.hunger),
			"grime" = round(prisoner.uniform_grime),
			"health" = round(prisoner.health_factor()),
			"care" = round(prisoner.care()),
			"grade" = round(prisoner.admin_care_grade(), 0.01),
			"pay_factor" = round(pay_factor(prisoner), 0.01),
			"sentence_left" = max(0, round(prisoner.sentence_left)),
			"dead" = prisoner.stat == DEAD,
			"locked_in" = prisoner.locked_in_seconds > 0,
			"confined_seconds" = round(prisoner.locked_in_seconds),
			"confined" = !!prisoner.is_confined(),
			"mood" = round(prisoner.mood),
			"state" = prisoner.trouble_state(),
			"loose_left" = prisoner.loose_seconds_shown(),
			"cuffed" = !!prisoner.cuffs,
			"lockdown_left" = max(0, round(prisoner.lockdown_left)),
		))
	var/list/trouble_block = trouble_payload()
	// The console's own intake state once the economy package sends it; open or closed until then
	var/list/console = ui_payload(null)
	var/intake_state = console["intake_state"] || (intake_open ? "open" : "closed")
	return list(
		"tension" = round(tension),
		"stage" = stage,
		"breakout_in" = (riot_active && !breaking_out) ? max(0, round(PRISON_RIOT_BREAKOUT_TIME - riot_elapsed)) : null,
		"intake_open" = intake_open,
		"intake_state" = intake_state,
		"next_arrival" = (intake_open && !isnull(arrival_countdown)) ? round(arrival_countdown) : null,
		"pay_rate" = round(pay_rate(), 0.1),
		"paid_total" = paid_total,
		"powered" = is_powered(),
		"conditions" = conditions_payload(),
		"cells" = cell_rows,
		"prisoners" = prisoner_rows,
		"crew_home" = !!crew_home(),
		"crew_mode" = isnull(crew_home_override) ? "auto" : (crew_home_override ? "home" : "away"),
		"riot_active" = riot_active,
		"riot_elapsed" = round(riot_elapsed),
		"riot_absent" = round(riot_absent),
		"subdued_left" = trouble_block["subdued_left"],
		"incident_fined" = incident_fined,
		"lost_recent" = lost_recently(),
		"debt" = outpost?.treasury?.account_debt || 0,
		"hatch" = hatch_stock(),
		"mess_units" = round(mess_load, 0.1),
		"floor_size" = mess_floor_size,
		"lit_samples" = lit_samples,
		"outage_debt" = round(outage_debt),
		"extras" = extras_admin_payload(),
		"experiment" = experiment_block(),
		"incidents" = incidents_admin_payload(),
	)

// ===== EXPERIMENTS =====
// The experiments core (outpost_prison_experiments.dm) and the changeling event
// (outpost_prison_changeling.dm) own these procs. This file calls them by name through hascall()
// and call(), so it builds with or without them and never declares a proc of theirs.

/// The experiments core's console block (experiment_payload()), or null with no experiment
/datum/outpost_prison/proc/experiment_block()
	return hascall(src, "experiment_payload") ? call(src, "experiment_payload")() : null

/// Whether an experiment is under way: dosed through a live creature, not offered, contained or failed
/datum/outpost_prison/proc/admin_experiment_running()
	var/list/block = experiment_block()
	return islist(block) && (block["stage"] in list("dosed", "twitching", "incubating", "live", "vents", "horror"))

/// Whether the researcher is in the wing now, by the console block
/datum/outpost_prison/proc/admin_researcher_present()
	var/list/block = experiment_block()
	return islist(block) && !!block["researcher_present"]

/**
 * The wing's running changeling event, or null. The experiments core decides where it keeps it,
 * so this looks through the prison's vars and, one step down, the vars of the datums they hold.
 */
/datum/outpost_prison/proc/admin_changeling_event()
	var/event_type = text2path("/datum/outpost_changeling_event")
	if(!event_type)
		return null
	var/list/holders = list(src)
	for(var/name in vars)
		var/datum/held = vars[name]
		if(istype(held, /datum) && !isatom(held))
			holders |= held
	for(var/datum/holder as anything in holders)
		for(var/name in holder.vars)
			var/datum/held = holder.vars[name]
			if(istype(held, event_type) && !QDELETED(held))
				return held
	return null

/// Where their care falls between no pay and full pay, 0 to 1 (section 1's G(care))
/mob/living/basic/outpost_prisoner/proc/admin_care_grade()
	return clamp((care() - OUTPOST_PRISON_GRADE_FLOOR) / (OUTPOST_PRISON_GRADE_FULL - OUTPOST_PRISON_GRADE_FLOOR), 0, 1)

/// What they are up to, in a few words
/mob/living/basic/outpost_prisoner/proc/admin_activity_text()
	if(stat == DEAD)
		return "dead"
	if(phase == PRISONER_ARRIVING)
		return "beaming in"
	if(phase == PRISONER_LEAVING)
		return "beaming out"
	if(pulledby)
		return "being dragged"
	if(beaten_left > 0)
		return "beaten ([round(beaten_left)] s)"
	if(cuffs)
		if(trouble == PRISONER_TROUBLE_LOOSE)
			return "cuffed, loose"
		return is_rioting() ? "cuffed, rioting" : "cuffed"
	if(can_be_dragged())
		return "down"
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return prison?.in_cell_block(src) ? "loose, back in the cell block" : "loose"
	if(climb_ref)
		return "climbing over a hatch"
	if(is_rioting())
		var/atom/target = riot_target_ref?.resolve()
		return trouble == PRISONER_TROUBLE_BREAKOUT ? "breaking out" : (target ? "rioting: [target.name]" : "rioting")
	if(fight)
		var/mob/living/opponent = fight.opponent_of(src)
		return "[fight.fighting ? "fighting" : "arguing with"] [opponent?.real_name]"
	var/mob/living/threatened = threat_ref?.resolve() || swing_ref?.resolve()
	if(threatened)
		return "threatening [threatened.name]"
	var/text = activity?.name || "idle"
	if(ai_controller?.ai_status != AI_STATUS_ON)
		text += " (AI asleep)"
	return text

/// Sets one of a prisoner's values. Returns FALSE if it can't take it.
/datum/outpost_prison/proc/admin_set(mob/living/basic/outpost_prisoner/prisoner, field, value)
	switch(field)
		if("hunger")
			prisoner.set_hunger(clamp(value, 0, 100))
		if("grime")
			prisoner.set_uniform_grime(clamp(value, 0, 100))
		if("health")
			// 1 to 100 percent; killing has its own button.
			if(prisoner.stat == DEAD)
				return FALSE
			var/target_loss = prisoner.maxHealth * (100 - clamp(value, 1, 100)) / 100
			prisoner.adjustBruteLoss(target_loss - prisoner.getBruteLoss(), forced = TRUE)
		if("sentence")
			if(prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
				return FALSE
			prisoner.sentence_left = clamp(round(value), 0, 24 * 60 * 60)
			prisoner.said_release_soon = prisoner.sentence_left <= 90
		if("mood")
			if(prisoner.stat == DEAD)
				return FALSE
			prisoner.set_mood(value)
		if("locked_in")
			// Seconds on the confinement clock
			if(prisoner.stat == DEAD)
				return FALSE
			prisoner.locked_in_seconds = clamp(round(value), 0, OUTPOST_ADMIN_PRISON_MAX_SECONDS)
		if("lockdown")
			// Seconds of lockdown owed (outpost_prison_capture.dm); 0 clears it
			if(prisoner.stat == DEAD)
				return FALSE
			prisoner.lockdown_left = clamp(round(value), 0, OUTPOST_ADMIN_PRISON_MAX_SECONDS)
			prisoner.lockdown_out = 0
		else
			return FALSE
	return TRUE

/// Applies one change to every living prisoner. Returns how many.
/datum/outpost_prison/proc/admin_all(what)
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == DEAD || prisoner.phase == PRISONER_LEAVING)
			continue
		count++
		switch(what)
			if("starve")
				prisoner.set_hunger(0)
			if("feed")
				prisoner.set_hunger(100)
			if("dirty")
				prisoner.set_uniform_grime(100)
			if("clean")
				prisoner.set_uniform_grime(0)
			if("hurt")
				// A real hit, so they bleed, never a killing one.
				var/damage = min(30, prisoner.health - 1)
				if(damage > 0)
					prisoner.apply_damage(damage, BRUTE)
			if("heal")
				prisoner.adjustBruteLoss(-prisoner.getBruteLoss(), forced = TRUE)
				prisoner.setStaminaLoss(0)
			if("enrage")
				// Low enough to threaten staff, fight, and riot once it has held for half a minute.
				prisoner.set_mood(10)
			if("calm")
				prisoner.set_mood(100)
	return count

/**
 * Ends every riot and fight, clears every lockdown owed and puts every mood back to
 * PRISONER_MOOD_START. Loose prisoners stay loose, and cuffs stay on.
 */
/datum/outpost_prison/proc/admin_calm()
	var/count = 0
	for(var/datum/outpost_prison_fight/brawl as anything in fights.Copy())
		end_fight(brawl)
	if(riot_active)
		end_riot()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.stat == DEAD || prisoner.phase == PRISONER_LEAVING)
			continue
		prisoner.cancel_threat()
		prisoner.calm_down()
		prisoner.set_mood(PRISONER_MOOD_START)
		prisoner.lockdown_left = 0
		prisoner.lockdown_out = 0
		count++
	tension_spike = 0
	riot_hold = 0
	update_stage(0)
	return count

/// The nearest other prisoner who could fight, for the admin fight button
/datum/outpost_prison/proc/nearest_fight_partner(mob/living/basic/outpost_prisoner/prisoner)
	var/mob/living/basic/outpost_prisoner/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/basic/outpost_prisoner/other in prisoners)
		if(other == prisoner || !other.can_join_riot() || other.trouble)
			continue
		var/distance = get_dist(prisoner, other)
		if(distance < nearest_distance)
			nearest = other
			nearest_distance = distance
	return nearest

/// What the admin panel shows as their state
/mob/living/basic/outpost_prisoner/proc/trouble_state()
	if(trouble == PRISONER_TROUBLE_LOOSE)
		return "loose"
	if(beaten_left > 0)
		return "beaten"
	// is_rioting() covers a breakout too; the panel tells them apart, as admin_activity_text() does
	if(trouble == PRISONER_TROUBLE_BREAKOUT)
		return "breaking out"
	if(is_rioting())
		return "rioting"
	if(trouble == PRISONER_TROUBLE_FIGHT)
		return "fighting"
	// Any other trouble (wrecking their cell) by its own name
	return trouble || "normal"

/// Seconds left loose, shown only while they are out of the cell block
/mob/living/basic/outpost_prisoner/proc/loose_seconds_shown()
	if(trouble != PRISONER_TROUBLE_LOOSE || stat == DEAD || prison?.in_cell_block(src))
		return null
	return max(0, round(loose_left))

/// Runs the prison forward, in half-minute steps so arrivals and releases keep their order
/datum/outpost_prison/proc/admin_advance(minutes)
	var/left = minutes * 60
	while(left > 0)
		var/step = min(30, left)
		tick(step)
		left -= step
		CHECK_TICK

/// Pays a minute at the current rate straight away. Returns what was deposited.
/datum/outpost_prison/proc/admin_pay_now()
	pay_owed += pay_rate()
	return deposit_pay()

/// Leaves dirt, crumbs, blood and wrappers about the wing. Returns how many.
/datum/outpost_prison/proc/admin_mess()
	var/list/floors = list()
	for(var/turf/open/tile in wing_turfs())
		if(prisoner_can_stand(tile) && !cell_at(tile))
			floors += tile
	var/made = 0
	for(var/i in 1 to 5)
		if(!length(floors))
			break
		var/turf/open/tile = pick_n_take(floors)
		var/mess_type = pick(
			/obj/effect/decal/cleanable/dirt,
			/obj/effect/decal/cleanable/food/crumbs,
			/obj/effect/decal/cleanable/blood,
			/obj/item/trash/candy,
			/obj/item/trash/tray,
		)
		new mess_type(tile)
		made++
	refresh_conditions()
	return made

/// Breaks every working light in the wing. Returns how many.
/datum/outpost_prison/proc/admin_break_lights()
	var/broken = 0
	for(var/turf/tile as anything in wing_turfs())
		for(var/obj/machinery/light/fixture in tile)
			if(fixture.status == LIGHT_OK)
				// No sparks: they are lights too, and would count toward Lit until they fade
				fixture.break_light_tube(TRUE)
				broken++
	refresh_conditions()
	return broken

/// Switches the wing's APC off or on. FALSE if it has none.
/datum/outpost_prison/proc/admin_set_power(on)
	var/obj/machinery/power/apc/apc = wing?.apc
	if(!apc)
		return FALSE
	apc.operating = !!on
	apc.update()
	apc.update_appearance()
	refresh_conditions()
	return TRUE

#undef OUTPOST_ADMIN_PRISON_MAX_DEBT
#undef OUTPOST_ADMIN_PRISON_MAX_SECONDS
