/**
 * # Chrome Cradle
 *
 * The ripperdoc parlor's operating chair: an outpost machine that installs,
 * removes and services cyberware. Fast, safe and dramatic where DIY table
 * surgery is slow and fail-prone — the premium path, and in v1 the only
 * legit rig besides a real organ-manipulation operation.
 *
 * Outpost furniture rules apply: no power draw, indestructible, tools bounce
 * off, attacking it is aggression. Occupancy is the sealed-chamber idiom
 * (open_machine/close_machine) like the imprinter next door, but the UI is
 * NOT contained-state: bystanders may look on and pop the tray. This is a
 * PvP server, so consent is structural — Install, Remove and Tune-up can only
 * ever be initiated by the occupant, on their own conscious, unrestrained
 * body. Forced-buckle chrome robbery dies right there. A sequence commits
 * only at its very end; opening the frame mid-cycle cancels cleanly with the
 * ware safe in the tray.
 *
 * Evicted incumbents go to the machine tray, never the floor, and the tray
 * ejects on demand (anyone adjacent — a logged-off occupant can't hold your
 * chrome hostage) and dumps automatically when the frame opens.
 */

/// Bark stages for play_ripperdoc_bark(); W4 wires these to the Splice NPC.
#define CRADLE_BARK_START "start"
#define CRADLE_BARK_MID "mid"
#define CRADLE_BARK_DONE "done"

/obj/machinery/chrome_cradle
	name = "chrome cradle"
	desc = "An operating chair under a six-armed surgical rig, upholstery split and re-taped. The arms twitch when you get close, like they're sizing you up."
	icon = 'voidcrew/modules/cyberware/icons/cyberware_machines.dmi'
	icon_state = "cradle"
	base_icon_state = "cradle"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	occupant_typecache = list(/mob/living/carbon)
	state_open = TRUE
	// Works for the occupant while they're strapped down flat.
	interaction_flags_atom = parent_type::interaction_flags_atom | INTERACT_ATOM_IGNORE_MOBILITY
	processing_flags = NONE
	/// Evicted/canceled chrome parked in the machine, listed in the UI.
	var/list/obj/item/organ/tray = list()
	/// Physical credits loaded into the cradle, spent before the bank account.
	var/loaded_credits = 0
	/// Whether a sequence is running.
	var/busy = FALSE
	/// Which sequence: "install", "remove".
	var/busy_action
	/// The ware the running sequence is working on.
	var/obj/item/organ/busy_ware
	/// world.time the running sequence completes, for the UI progress bar.
	var/busy_until = 0
	/// Total length of the running sequence.
	var/busy_duration = 0
	/// TIMER_STOPPABLE handles for every pending stage of the sequence.
	var/list/stage_timers = list()

/obj/machinery/chrome_cradle/Initialize(mapload)
	. = ..()
	// INDESTRUCTIBLE doesn't stop tool acts — block deconstruction outright.
	var/static/list/blocked_tools = list(TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_CROWBAR, TOOL_WELDER, TOOL_WIRECUTTER, TOOL_MULTITOOL)
	for(var/tool_type in blocked_tools)
		RegisterSignal(src, COMSIG_ATOM_TOOL_ACT(tool_type), PROC_REF(block_tool_act))
		RegisterSignal(src, COMSIG_ATOM_SECONDARY_TOOL_ACT(tool_type), PROC_REF(block_tool_act))
	update_appearance()

/obj/machinery/chrome_cradle/Destroy()
	cancel_sequence()
	if(occupant || length(tray))
		dump_inventory_contents()
	tray.Cut()
	return ..()

/// Signal proc for [COMSIG_ATOM_TOOL_ACT]: the rig services itself.
/obj/machinery/chrome_cradle/proc/block_tool_act(datum/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	balloon_alert(user, "sealed unit!")
	return ITEM_INTERACT_BLOCKING

/obj/machinery/chrome_cradle/examine(mob/user)
	. = ..()
	. += span_notice("Climb on (or drag someone on) and click it to shut the rig. The occupant runs their own install from inside — the rig takes orders from nobody else.")
	. += span_notice("Tune-ups run [CYBERWARE_TUNEUP_FEE] cr: EMP-scrambled and damaged chrome comes back to spec. Load cash into the frame or pay by ID.")
	if(loaded_credits)
		. += span_notice("The frame holds <b>[loaded_credits] cr</b> in loaded cash.")
	if(length(tray))
		. += span_notice("The parts tray holds: <b>[english_list(tray)]</b>.")

// ---- Icon --------------------------------------------------------------

/obj/machinery/chrome_cradle/update_icon_state()
	if(busy)
		icon_state = "[base_icon_state]_active"
	else if(occupant)
		icon_state = "[base_icon_state]_occupied"
	else
		icon_state = base_icon_state
	return ..()

// ---- Occupancy ---------------------------------------------------------

/obj/machinery/chrome_cradle/mouse_drop_receive(atom/target, mob/user, params)
	if(!iscarbon(target) || occupant || !state_open)
		return
	close_machine(target)

/obj/machinery/chrome_cradle/interact(mob/user)
	if(user == occupant)
		return ..() // INTERACT_ATOM_UI_INTERACT opens the UI from inside
	add_fingerprint(user)
	if(state_open)
		if(!iscarbon(user))
			balloon_alert(user, "not rated for you!")
			return TRUE
		close_machine(user)
		return TRUE
	// Occupied: bystanders get the read-only UI (and the tray) rather than
	// popping the frame open by accident; the Open Frame button is in there.
	ui_interact(user)
	return TRUE

/obj/machinery/chrome_cradle/relaymove(mob/living/user, direction)
	open_machine()

// No lock; resisting pops the frame without having to crawl out.
/obj/machinery/chrome_cradle/container_resist_act(mob/living/user)
	open_machine()

/obj/machinery/chrome_cradle/Exited(atom/movable/gone, direction)
	. = ..()
	tray -= gone
	if(gone == occupant)
		cancel_sequence()
		set_occupant(null)
		update_appearance()
	else if(busy && gone == busy_ware)
		cancel_sequence()

// The chair is dense whether or not anyone's on it.
/obj/machinery/chrome_cradle/open_machine(drop = TRUE, density_to_set = TRUE)
	cancel_sequence()
	eject_cash()
	. = ..()
	tray.Cut() // contents just got dumped
	SStgui.update_uis(src)

/obj/machinery/chrome_cradle/close_machine(atom/movable/target, density_to_set = TRUE)
	. = ..()
	if(!occupant)
		return .
	playsound(src, 'sound/effects/servostep.ogg', 40, TRUE)
	ui_interact(occupant)
	return .

/**
 * Whether the occupant is in a state to consent to chrome work: conscious
 * and unrestrained at sequence start. The install sequence itself sedates
 * them — that's fine, consent was given standing up.
 */
/obj/machinery/chrome_cradle/proc/occupant_can_consent()
	var/mob/living/carbon/patient = occupant
	if(!istype(patient))
		return FALSE
	if(patient.stat != CONSCIOUS)
		return FALSE
	if(HAS_TRAIT(patient, TRAIT_RESTRAINED) || patient.handcuffed)
		return FALSE
	return TRUE

// ---- Cash / fees (the imprinter's pattern) -----------------------------

/obj/machinery/chrome_cradle/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(isorgan(attacking_item) && attacking_item.GetComponent(/datum/component/cyberware))
		if(!user.transferItemToLoc(attacking_item, src))
			return TRUE
		tray += attacking_item
		balloon_alert(user, "chrome racked in tray")
		SStgui.update_uis(src)
		return TRUE
	if(iscash(attacking_item))
		load_cash(attacking_item, user)
		return TRUE
	return ..()

/// Feed physical currency into the frame's cash reserve.
/obj/machinery/chrome_cradle/proc/load_cash(obj/item/money, mob/living/user)
	var/value = money.get_item_credit_value()
	if(!value)
		balloon_alert(user, "no value!")
		return
	loaded_credits += value
	qdel(money)
	balloon_alert(user, "loaded [value] cr")
	playsound(src, 'sound/effects/cashregister.ogg', 40, TRUE)
	SStgui.update_uis(src)

/// Hand back all loaded cash as a holochip.
/obj/machinery/chrome_cradle/proc/eject_cash(mob/living/to_hands)
	if(loaded_credits <= 0)
		return
	var/obj/item/holochip/chip = new(drop_location(), loaded_credits)
	loaded_credits = 0
	if(to_hands)
		to_hands.put_in_hands(chip)
	SStgui.update_uis(src)

/// Draw a fee from loaded cash first, then the payer's ID account for any
/// shortfall. Returns TRUE only if the whole fee was covered and charged.
/obj/machinery/chrome_cradle/proc/charge_fee(mob/living/carbon/user, fee, service_name)
	var/from_cash = min(loaded_credits, fee)
	var/remainder = fee - from_cash
	if(remainder > 0)
		var/obj/item/card/id/id_card = user.get_idcard(TRUE)
		var/datum/bank_account/account = id_card?.registered_account
		if(!account || !account.has_money(remainder))
			return FALSE
		if(!account.adjust_money(-remainder, "Chrome Cradle: [service_name]"))
			return FALSE
	loaded_credits -= from_cash
	return TRUE

// ---- Tray --------------------------------------------------------------

/// Dump the parts tray at the frame's feet, into the requester's hands when
/// they're close enough. Deliberately available to ANYONE adjacent, so an
/// evicted organ can't be held hostage by a logged-off occupant.
/obj/machinery/chrome_cradle/proc/eject_tray(mob/living/user)
	if(!length(tray))
		return
	for(var/obj/item/organ/ware as anything in tray.Copy())
		ware.forceMove(drop_location())
		if(user)
			try_put_in_hand(ware, user)
	tray.Cut()
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	SStgui.update_uis(src)

// ---- Sequences ---------------------------------------------------------

/**
 * The 4-second install theatre. Validation already happened in ui_act; this
 * moves the ware into the machine (an unconscious patient drops what they
 * hold, so it can't ride out the nap in their hands), sedates, and stages
 * the servo work. Nothing commits until finish_install().
 */
/obj/machinery/chrome_cradle/proc/begin_install(obj/item/organ/ware)
	var/mob/living/carbon/patient = occupant
	if(ware.loc != src && !patient.transferItemToLoc(ware, src))
		balloon_alert(patient, "[ware.name] is stuck to you!")
		return
	var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
	busy = TRUE
	busy_action = "install"
	busy_ware = ware
	busy_duration = CYBERWARE_INSTALL_TIME
	busy_until = world.time + busy_duration
	patient.Unconscious(CYBERWARE_INSTALL_TIME + 2 SECONDS)
	play_ripperdoc_bark(CRADLE_BARK_START, chrome.tier)
	run_sequence_stage()
	stage_timers += addtimer(CALLBACK(src, PROC_REF(run_sequence_stage)), CYBERWARE_INSTALL_TIME * 0.33, TIMER_STOPPABLE)
	stage_timers += addtimer(CALLBACK(src, PROC_REF(run_sequence_stage), TRUE), CYBERWARE_INSTALL_TIME * 0.66, TIMER_STOPPABLE)
	stage_timers += addtimer(CALLBACK(src, PROC_REF(finish_install)), CYBERWARE_INSTALL_TIME, TIMER_STOPPABLE)
	update_appearance()
	SStgui.update_uis(src)

/// One servo-thunk beat of the running sequence: sound, patient jitter, and
/// on the marked stage a spark shower plus Splice's mid-line.
/obj/machinery/chrome_cradle/proc/run_sequence_stage(mid_stage = FALSE)
	playsound(src, 'sound/effects/servostep.ogg', 60, TRUE)
	var/mob/living/patient = occupant
	if(istype(patient))
		patient.do_jitter_animation(60)
	if(mid_stage)
		do_sparks(2, TRUE, src)
		var/datum/component/cyberware/chrome = busy_ware?.GetComponent(/datum/component/cyberware)
		if(chrome)
			play_ripperdoc_bark(CRADLE_BARK_MID, chrome.tier)
	SStgui.update_uis(src)

/**
 * The commit point. Re-validates everything — the occupant may have been
 * yanked, the ware ejected, the slot filled by a mid-sequence DIY surgeon —
 * then evicts any incumbent to the tray and inserts. A refused insert parks
 * the ware in the tray; nothing is ever consumed on failure.
 */
/obj/machinery/chrome_cradle/proc/finish_install()
	var/mob/living/carbon/patient = occupant
	var/obj/item/organ/ware = busy_ware
	clear_busy_state()
	if(!istype(patient) || QDELETED(ware) || ware.loc != src)
		return
	var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
	if(!chrome)
		return
	// Same-slot incumbents come out into the tray first — never the floor.
	for(var/obj/item/organ/incumbent as anything in ware.cyberware_get_incumbents(patient))
		incumbent.Remove(patient, special = TRUE)
		incumbent.forceMove(src)
		tray += incumbent
		balloon_alert(patient, "[incumbent.name] racked in tray")
	tray -= ware
	chrome.grant_install_context(patient)
	if(!ware.Insert(patient))
		tray += ware
		balloon_alert(patient, "install refused!")
		playsound(src, 'sound/machines/scanner/scanbuzz.ogg', 40, TRUE)
		wake_patient(patient)
		return
	do_sparks(3, FALSE, src)
	patient.flash_act(visual = 1)
	if(chrome.tier >= CYBERWARE_TIER_4)
		visible_message(span_notice("The parlor's neon stutters for a moment."))
		// TODO(W4): flicker the actual parlor fixtures once the map exists.
	addtimer(CALLBACK(src, PROC_REF(play_ripperdoc_bark), CRADLE_BARK_DONE, chrome.tier), 1.5 SECONDS)
	wake_patient(patient)

/// The 3-second removal cycle: no sedation, one servo beat, organ to hands.
/obj/machinery/chrome_cradle/proc/begin_removal(obj/item/organ/ware)
	busy = TRUE
	busy_action = "remove"
	busy_ware = ware
	busy_duration = CYBERWARE_REMOVAL_TIME
	busy_until = world.time + busy_duration
	run_sequence_stage()
	stage_timers += addtimer(CALLBACK(src, PROC_REF(run_sequence_stage)), CYBERWARE_REMOVAL_TIME * 0.5, TIMER_STOPPABLE)
	stage_timers += addtimer(CALLBACK(src, PROC_REF(finish_removal)), CYBERWARE_REMOVAL_TIME, TIMER_STOPPABLE)
	update_appearance()
	SStgui.update_uis(src)

/obj/machinery/chrome_cradle/proc/finish_removal()
	var/mob/living/carbon/patient = occupant
	var/obj/item/organ/ware = busy_ware
	clear_busy_state()
	if(!istype(patient) || QDELETED(ware) || ware.owner != patient)
		return
	ware.Remove(patient)
	ware.forceMove(src)
	if(patient.put_in_hands(ware))
		balloon_alert(patient, "[ware.name] removed")
	else
		tray += ware
		balloon_alert(patient, "[ware.name] racked in tray")
	playsound(src, 'sound/effects/servostep.ogg', 50, TRUE)
	SStgui.update_uis(src)

/// Stop a running sequence without committing anything. The ware, if it was
/// already swallowed for an install, is parked in the tray; a sedated
/// patient is woken. Safe to call redundantly.
/obj/machinery/chrome_cradle/proc/cancel_sequence()
	if(!busy)
		return
	var/obj/item/organ/ware = busy_ware
	var/was_install = busy_action == "install"
	clear_busy_state()
	if(was_install && !QDELETED(ware) && ware.loc == src && !ware.owner && !(ware in tray))
		tray += ware
	wake_patient(occupant)
	SStgui.update_uis(src)

/obj/machinery/chrome_cradle/proc/clear_busy_state()
	for(var/timer in stage_timers)
		deltimer(timer)
	stage_timers.Cut()
	busy = FALSE
	busy_action = null
	busy_ware = null
	busy_until = 0
	busy_duration = 0
	update_appearance()

/// Ends our sedation early. Only ever clears sleep WE caused — the patient
/// was conscious at sequence start, that's the consent gate.
/obj/machinery/chrome_cradle/proc/wake_patient(mob/living/carbon/patient)
	if(istype(patient) && !QDELETED(patient))
		patient.SetUnconscious(0)

// ---- Tune-up -----------------------------------------------------------

/// Whether anything on the occupant would actually benefit from a tune-up,
/// or the reason nothing would. Brownouts are load problems — the fee can't
/// fix those and won't be taken for them.
/obj/machinery/chrome_cradle/proc/get_tuneup_denial(mob/living/carbon/patient)
	var/list/installed = get_installed_cyberware(patient)
	if(!length(installed))
		return "No chrome installed."
	var/only_brownout = TRUE
	var/any_repairable = FALSE
	for(var/obj/item/organ/ware as anything in installed)
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		if(chrome.emp_down || ware.damage > 0)
			any_repairable = TRUE
			only_brownout = FALSE
			break
		if((ware.organ_flags & ORGAN_FAILING) && !chrome.browned_out)
			any_repairable = TRUE
			only_brownout = FALSE
			break
		if(!chrome.browned_out)
			only_brownout = FALSE
	if(any_repairable)
		return null
	if(only_brownout && length(installed))
		return "That chrome is browned out, not broken — shed some load instead."
	return "Nothing needs a tune-up."

/obj/machinery/chrome_cradle/proc/try_tune_up(mob/living/carbon/patient)
	var/denial = get_tuneup_denial(patient)
	if(denial)
		balloon_alert(patient, "nothing to tune!")
		to_chat(patient, span_warning(denial))
		return
	if(!charge_fee(patient, CYBERWARE_TUNEUP_FEE, "chrome tune-up"))
		balloon_alert(patient, "needs [CYBERWARE_TUNEUP_FEE] cr!")
		return
	for(var/obj/item/organ/ware as anything in get_installed_cyberware(patient))
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		chrome.tune_up()
	do_sparks(2, TRUE, src)
	playsound(src, 'sound/machines/synth/synth_yes.ogg', 40, TRUE)
	balloon_alert(patient, "chrome tuned up")
	patient.log_message("bought a chrome tune-up at [src]", LOG_GAME)
	SStgui.update_uis(src)

// ---- Ripperdoc barks ---------------------------------------------------

/**
 * The parlor voice, tier-keyed. W4 overrides this to route through the
 * Splice NPC's trader_lines; until then the rig itself talks. T4 installs
 * run silent by design — the only line comes after the boot chime.
 */
/obj/machinery/chrome_cradle/proc/play_ripperdoc_bark(stage, tier)
	var/line
	switch(stage)
		if(CRADLE_BARK_START)
			switch(tier)
				if(CYBERWARE_TIER_1)
					line = "Cheap chrome. You won't even scar."
				if(CYBERWARE_TIER_2)
					line = "Decent pick. Hold still and it'll seat clean."
				if(CYBERWARE_TIER_3)
					line = "Military grade. Breathe out and don't move."
		if(CRADLE_BARK_MID)
			if(tier == CYBERWARE_TIER_3)
				line = "Hold still. This part matters."
		if(CRADLE_BARK_DONE)
			switch(tier)
				if(CYBERWARE_TIER_3)
					line = "Done. Walk it off before you trust it."
				if(CYBERWARE_TIER_4)
					line = "...Don't waste that."
	if(line)
		say(line)

// ---- UI ----------------------------------------------------------------

/obj/machinery/chrome_cradle/ui_status(mob/user, datum/ui_state/state)
	// The occupant operates from inside regardless of the frame being shut;
	// sedation mid-install downgrades them to watching. Everyone else gets
	// ordinary machine adjacency: view plus the tray, nothing more (ui_act
	// enforces the rest).
	if(user == occupant)
		return user.shared_ui_interaction(src)
	return ..()

/obj/machinery/chrome_cradle/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ChromeCradle", name)
		ui.open()

/obj/machinery/chrome_cradle/ui_data(mob/user)
	var/list/data = list()
	var/mob/living/carbon/patient = occupant
	var/has_patient = istype(patient)

	data["has_occupant"] = has_patient
	data["occupant_name"] = has_patient ? patient.name : null
	data["occupant_is_user"] = user == occupant
	data["can_operate"] = has_patient && occupant_can_consent()
	data["busy"] = busy
	data["busy_action"] = busy_action
	data["busy_timeleft"] = busy ? max(busy_until - world.time, 0) / 10 : 0
	data["busy_duration"] = busy_duration / 10
	data["loaded_credits"] = loaded_credits
	data["tuneup_fee"] = CYBERWARE_TUNEUP_FEE

	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	data["barred"] = outpost?.is_user_barred(patient) ? TRUE : FALSE

	var/datum/bank_account/account
	if(has_patient)
		var/obj/item/card/id/id_card = patient.get_idcard(TRUE)
		account = id_card?.registered_account
	data["account_credits"] = account ? account.account_balance : null

	data["load"] = has_patient ? get_chrome_load(patient) : 0
	data["capacity"] = has_patient ? get_chrome_capacity(patient) : 0
	data["brownout"] = has_patient && get_chrome_load(patient) > get_chrome_capacity(patient)

	var/list/installed = list()
	if(has_patient)
		for(var/obj/item/organ/ware as anything in get_installed_cyberware(patient))
			var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
			installed += list(list(
				"ref" = REF(ware),
				"name" = ware.name,
				"tier" = chrome.tier,
				"load" = chrome.chrome_load,
				"capacity_bonus" = chrome.capacity_bonus,
				"failing" = (ware.organ_flags & ORGAN_FAILING) ? TRUE : FALSE,
				"emp_down" = chrome.emp_down ? TRUE : FALSE,
			))
	data["installed"] = installed
	data["tuneup_denial"] = has_patient ? get_tuneup_denial(patient) : "No chrome installed."

	// Everything chrome the occupant brought in: hands, pockets, bags.
	var/list/carried = list()
	if(has_patient)
		for(var/obj/item/organ/ware in patient.get_all_contents())
			var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
			if(!chrome || ware.owner)
				continue
			carried += list(list(
				"ref" = REF(ware),
				"name" = ware.name,
				"tier" = chrome.tier,
				"load" = chrome.chrome_load,
				"capacity_bonus" = chrome.capacity_bonus,
				"fits" = cyberware_insert_check(ware, patient, silent = TRUE) ? TRUE : FALSE,
			))
	data["carried"] = carried

	var/list/tray_data = list()
	for(var/obj/item/organ/ware as anything in tray)
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		tray_data += list(list(
			"ref" = REF(ware),
			"name" = ware.name,
			"tier" = chrome ? chrome.tier : 1, // CYBERWARE_TIER_1
			"load" = chrome ? chrome.chrome_load : 0,
			"fits" = (has_patient && chrome) ? (cyberware_insert_check(ware, patient, silent = TRUE) ? TRUE : FALSE) : FALSE,
		))
	data["tray"] = tray_data

	return data

/obj/machinery/chrome_cradle/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	// Off the ui, never a tracked var — ui.close() nulls those.
	var/mob/living/acting = ui.user

	// Frame and tray controls are open to anyone the ui_status let in.
	switch(action)
		if("open_frame")
			open_machine()
			return TRUE
		if("eject_tray")
			eject_tray(acting)
			return TRUE
		if("eject_cash")
			if(busy)
				return TRUE
			eject_cash(acting)
			return TRUE

	// Everything below touches a body, and only its owner gets to order that.
	if(acting != occupant)
		balloon_alert(acting, "occupant's call!")
		return TRUE
	if(busy)
		balloon_alert(acting, "rig is working!")
		return TRUE
	if(!occupant_can_consent())
		balloon_alert(acting, "can't consent like that!")
		return TRUE
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	if(outpost?.is_user_barred(acting))
		balloon_alert(acting, "trade embargo!")
		return TRUE
	var/mob/living/carbon/patient = occupant

	switch(action)
		if("install")
			var/obj/item/organ/ware = locate(params["ref"]) in (patient.get_all_contents() | tray)
			if(!istype(ware) || ware.owner)
				return TRUE
			if(!ware.GetComponent(/datum/component/cyberware))
				balloon_alert(patient, "not chrome!")
				return TRUE
			if(!cyberware_insert_check(ware, patient, feedback_to = patient))
				return TRUE
			begin_install(ware)
			return TRUE

		if("remove")
			var/obj/item/organ/ware = locate(params["ref"]) in get_installed_cyberware(patient)
			if(!istype(ware))
				return TRUE
			begin_removal(ware)
			return TRUE

		if("tuneup")
			try_tune_up(patient)
			return TRUE

		if("configure")
			// TODO(W2 — Chromatic Dermis): pattern + colour picker for
			// configurable ware lands on this branch. Validate the ref against
			// get_installed_cyberware(patient), then hand off to the ware.
			balloon_alert(patient, "nothing to configure!")
			return TRUE

	return TRUE

// ---- Outpost aggression ------------------------------------------------

// Attacking outpost property is aggression, the cradle included.
/obj/machinery/chrome_cradle/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && !iscash(attacking_item) && !isorgan(attacking_item))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(user)
	return ..()

/obj/machinery/chrome_cradle/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE, blocked = 0)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

#undef CRADLE_BARK_START
#undef CRADLE_BARK_MID
#undef CRADLE_BARK_DONE
