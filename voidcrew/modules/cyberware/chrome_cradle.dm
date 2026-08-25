/**
 * # Chrome Cradle
 *
 * The ripperdoc parlor's operating chair: an outpost machine that installs,
 * removes and services cyberware. Fast, safe and dramatic where DIY table
 * surgery is slow and fail-prone, the premium path, and in v1 the only
 * legit rig besides a real organ-manipulation operation.
 *
 * Outpost furniture rules apply: no power draw, indestructible, tools bounce
 * off, attacking it is aggression. The patient lies ON TOP of the slab,
 * buckled, stasis-bed style, never sealed inside anything, and bystanders
 * may look on and pop the tray. This is a PvP server, so consent is
 * structural, Install, Remove and Tune-up can only ever be initiated by the
 * occupant, on their own conscious, unrestrained body. Forced-buckle chrome
 * robbery dies right there. A sequence commits only at its very end; getting
 * up (or being hauled off) mid-cycle cancels cleanly with the ware safe in
 * the tray.
 *
 * Evicted incumbents go to the machine tray, never the floor, and the tray
 * ejects on demand (anyone adjacent. A logged-off occupant can't hold your
 * chrome hostage).
 */

/// Bark stages for play_ripperdoc_bark(); W4 wires these to the Splice NPC.
#define CRADLE_BARK_START "start"
#define CRADLE_BARK_MID "mid"
#define CRADLE_BARK_DONE "done"

/obj/machinery/chrome_cradle
	name = "chrome cradle"
	desc = "A salvaged alien operating slab wired into a six-armed surgical rig. Whatever the original owners used it on has long since been scrubbed off the alloy. The arms twitch when you get close."
	icon = 'icons/obj/antags/abductor.dmi'
	icon_state = "bed"
	// A slab, not a cabinet: you walk onto it and lie down. Buckling IS the
	// occupancy, nothing is ever sealed inside.
	density = FALSE
	anchored = TRUE
	can_buckle = TRUE
	buckle_lying = 90
	buckle_dir = SOUTH
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
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
	/// The ware the occupant has highlighted in the racks: what the detail
	/// panel describes.
	var/obj/item/organ/selected_ware

/obj/machinery/chrome_cradle/Initialize(mapload)
	. = ..()
	// INDESTRUCTIBLE doesn't stop tool acts, block deconstruction outright.
	var/static/list/blocked_tools = list(TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_CROWBAR, TOOL_WELDER, TOOL_WIRECUTTER, TOOL_MULTITOOL)
	for(var/tool_type in blocked_tools)
		RegisterSignal(src, COMSIG_ATOM_TOOL_ACT(tool_type), PROC_REF(block_tool_act))
		RegisterSignal(src, COMSIG_ATOM_SECONDARY_TOOL_ACT(tool_type), PROC_REF(block_tool_act))
	// The patient rides visually on top of the slab, stasis-bed style.
	AddElement(/datum/element/elevation, pixel_shift = 6)

/obj/machinery/chrome_cradle/Destroy()
	cancel_sequence()
	selected_ware = null
	var/turf/drop_turf = drop_location()
	if(drop_turf)
		// Snapshot: forceMove fires Exited(), which cuts the leaving organ out
		// of tray underneath us and would make a live iteration skip every
		// other piece, leaving them in contents to be qdel'd with the machine.
		for(var/obj/item/organ/ware in tray.Copy())
			ware.forceMove(drop_turf)
	tray.Cut()
	return ..()

/// Signal proc for [COMSIG_ATOM_TOOL_ACT]: the rig services itself.
/obj/machinery/chrome_cradle/proc/block_tool_act(datum/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	balloon_alert(user, "sealed unit!")
	return ITEM_INTERACT_BLOCKING

/obj/machinery/chrome_cradle/examine(mob/user)
	. = ..()
	. += span_notice("Drag yourself (or a patient) onto the slab to lie back on it. Whoever's on the slab runs their own install; the rig won't take orders from anyone else.")
	. += span_notice("Tune-ups run [CYBERWARE_TUNEUP_FEE] cr: EMP-scrambled and damaged chrome comes back to spec. Load cash into the slab or pay by ID.")
	if(loaded_credits)
		. += span_notice("The slab's cash slot holds <b>[loaded_credits] cr</b>.")
	if(length(tray))
		. += span_notice("The parts tray holds: <b>[english_list(tray)]</b>.")

// ---- Occupancy (buckling, the patient lies ON the slab) ----------------

// Only carbons fit the rig's restraint geometry.
/obj/machinery/chrome_cradle/is_buckle_possible(mob/living/target, force = FALSE, check_loc = TRUE)
	if(!iscarbon(target))
		return FALSE
	return ..()

/obj/machinery/chrome_cradle/post_buckle_mob(mob/living/patient)
	set_occupant(patient)
	playsound(src, 'sound/effects/servostep.ogg', 40, TRUE)
	ui_interact(patient)
	SStgui.update_uis(src)

/obj/machinery/chrome_cradle/post_unbuckle_mob(mob/living/patient)
	cancel_sequence()
	eject_cash()
	if(patient == occupant)
		set_occupant(null)
	selected_ware = null
	SStgui.update_uis(src)

// The base movable click unbuckles the occupant. On the cradle a click is
// always the console instead. Getting up is resist, moving, or the UI button;
// nobody yanks a sedated patient off the slab with a stray click.
/obj/machinery/chrome_cradle/attack_hand(mob/living/user, list/modifiers)
	if(occupant)
		add_fingerprint(user)
		ui_interact(user)
		return TRUE
	return ..()

/obj/machinery/chrome_cradle/Exited(atom/movable/gone, direction)
	. = ..()
	tray -= gone
	if(gone == selected_ware)
		selected_ware = null
	if(busy && gone == busy_ware)
		cancel_sequence()

/**
 * Whether the occupant is in a state to consent to chrome work: conscious
 * and unrestrained at sequence start. The install sequence itself sedates
 * them, that's fine, consent was given standing up.
 */
/obj/machinery/chrome_cradle/proc/occupant_can_consent()
	var/mob/living/carbon/patient = occupant
	if(!istype(patient))
		return FALSE
	if(patient.stat != STABLE)
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

/// Feed physical currency into the slab's cash reserve.
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

/// Dump the parts tray at the slab's feet, into the requester's hands when
/// they're close enough. Deliberately available to ANYONE adjacent, so an
/// evicted organ can't be held hostage by a logged-off occupant.
/obj/machinery/chrome_cradle/proc/eject_tray(mob/living/user)
	list_clear_nulls(tray)
	if(!length(tray))
		return
	for(var/obj/item/organ/ware in tray.Copy())
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
 * The commit point. Re-validates everything: the occupant may have been
 * yanked, the ware ejected, the slot filled by a mid-sequence DIY surgeon,
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
	// Same-slot incumbents come out into the tray first, never the floor.
	for(var/obj/item/organ/incumbent in ware.cyberware_get_incumbents(patient))
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
		visible_message(span_notice("The parlor's neon stutters as the rig pulls the current it needs."))
		flicker_parlor_lights()
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

/// Ends our sedation early. Only ever clears sleep WE caused, the patient
/// was conscious at sequence start, that's the consent gate.
/obj/machinery/chrome_cradle/proc/wake_patient(mob/living/carbon/patient)
	if(istype(patient) && !QDELETED(patient))
		patient.SetUnconscious(0)

// ---- Tune-up -----------------------------------------------------------

/// Whether anything on the occupant would actually benefit from a tune-up,
/// or the reason nothing would. Brownouts are load problems. The fee can't
/// fix those and won't be taken for them.
/obj/machinery/chrome_cradle/proc/get_tuneup_denial(mob/living/carbon/patient)
	var/list/installed = get_installed_cyberware(patient)
	if(!length(installed))
		return "No chrome installed."
	var/only_brownout = TRUE
	var/any_repairable = FALSE
	for(var/obj/item/organ/ware in installed)
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
		return "That chrome is browned out, not broken. Shed some load instead."
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
	for(var/obj/item/organ/ware in get_installed_cyberware(patient))
		var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
		chrome.tune_up()
	do_sparks(2, TRUE, src)
	playsound(src, 'sound/machines/synth/synth_yes.ogg', 40, TRUE)
	balloon_alert(patient, "chrome tuned up")
	patient.log_message("bought a chrome tune-up at [src]", LOG_GAME)
	SStgui.update_uis(src)

/// A T4 install pulls hard enough that the parlor's mood lighting browns out
/// with it, every mapped fixture near the cradle flickers, and the CHROME
/// sign stutters. Pure theatre, and the whole point of doing it at the parlor.
/obj/machinery/chrome_cradle/proc/flicker_parlor_lights()
	for(var/obj/machinery/light/fixture in view(6, src))
		fixture.flicker(rand(3, 6))
	for(var/obj/machinery/chrome_sign/sign in view(6, src))
		sign.flicker()

// ---- Ripperdoc barks ---------------------------------------------------

/**
 * The parlor voice, tier-keyed. Routed through the Splice NPC when one is in
 * view of the cradle (the ripperdoc talks you through the work) and falls
 * back to the rig's own speaker anywhere else (a cradle bought and mapped off
 * an outpost still has a bedside manner). T4 installs run silent by design;
 * the only line comes after the boot chime.
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
	if(!line)
		return
	for(var/mob/living/basic/outpost_trader/ripperdoc/splice in view(7, src))
		splice.say(line)
		return
	say(line)

// ---- UI ----------------------------------------------------------------

/obj/machinery/chrome_cradle/ui_status(mob/user, datum/ui_state/state)
	// The occupant operates while lying buckled on the slab;
	// sedation mid-install downgrades them to watching. Everyone else gets
	// ordinary machine adjacency: view plus the tray, nothing more (ui_act
	// enforces the rest).
	if(user == occupant)
		return user.shared_ui_interaction(src)
	return ..()

/obj/machinery/chrome_cradle/ui_assets(mob/user)
	return list(
		get_asset_datum(/datum/asset/simple/chrome_cradle_plate),
		get_asset_datum(/datum/asset/spritesheet_batched/chrome),
	)

/obj/machinery/chrome_cradle/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(ui)
		return
	ui = new(user, src, "ChromeCradle", name)
	ui.open()

/**
 * Every piece of chrome this console can act on, mapped to where it currently
 * is: "installed", "carried" (hands, pockets, bags) or "tray". Associative so
 * the rack builder gets the state for free and the ordering stays stable.
 */
/obj/machinery/chrome_cradle/proc/get_reachable_ware(mob/living/carbon/patient)
	var/list/found = list()
	if(istype(patient))
		for(var/obj/item/organ/ware in get_installed_cyberware(patient))
			found[ware] = "installed"
		for(var/obj/item/organ/ware in patient.get_all_contents())
			if(ware.owner || !ware.GetComponent(/datum/component/cyberware))
				continue
			found[ware] = "carried"
	// A hard-deleted organ (SSgarbage giving up on a ref it can't collect)
	// turns into a null IN PLACE inside every list still holding it, and the
	// tray holds strong refs. Scrub before reading, and use a typed loop so a
	// null that appears between the scrub and the read is filtered rather than
	// dereferenced, this proc runs from ui_data, so a runtime here blanks the
	// whole rack once a second.
	list_clear_nulls(tray)
	for(var/obj/item/organ/ware in tray)
		if(!ware.GetComponent(/datum/component/cyberware))
			continue
		found[ware] = "tray"
	return found

/**
 * The rack: one row per body system in head-down order, each holding whatever
 * chrome the console can see for its slots. Empty rows are kept, a system
 * with nothing to put in it is information too, and it is what makes the rack
 * read as a body rather than as a list.
 *
 * Identical spares stack onto a single card carrying a count, rather than
 * tiling the same sprite six times across a row. The stack key is everything
 * the card actually shows, so a damaged or EMP-scrambled copy never hides
 * inside a clean stack, and an installed piece never merges with a loose one,
 * they offer different buttons. Since only the representative of a stack has a
 * tile on screen, a highlight sitting on one of the folded-away copies is
 * snapped onto that representative here.
 */
/obj/machinery/chrome_cradle/proc/build_rack_data(mob/living/carbon/patient, list/available)
	var/list/grouped = list()
	/// stack key -> the card every copy in that stack shares.
	var/list/stack_cards = list()
	/// stack key -> the one piece of chrome that card addresses.
	var/list/stack_owners = list()
	for(var/obj/item/organ/ware in available)
		var/list/card = build_ware_data(ware, available[ware], patient)
		var/stack_key = "[ware.type]|[card["state"]]|[card["failing"]]|[card["emp_down"]]|[card["browned_out"]]|[card["damage"]]"
		var/list/stacked = stack_cards[stack_key]
		if(stacked)
			stacked["count"] += 1
			if(ware == selected_ware)
				selected_ware = stack_owners[stack_key]
			continue
		stack_cards[stack_key] = card
		stack_owners[stack_key] = ware
		var/group_id = get_cyberware_group_id(ware)
		if(!grouped[group_id])
			grouped[group_id] = list()
		var/list/bucket = grouped[group_id]
		bucket += list(card)

	var/list/rows = list()
	for(var/list/group as anything in GLOB.cyberware_ui_groups)
		var/group_id = group["id"]
		rows += list(list(
			"id" = group_id,
			"name" = group["name"],
			"region" = group["region"],
			"ware" = grouped[group_id] || list(),
		))
		grouped -= group_id
	// A slot with no home in the table still gets shown rather than vanishing.
	for(var/leftover_id in grouped)
		rows += list(list(
			"id" = leftover_id,
			"name" = "Other Hardware",
			"region" = "torso",
			"ware" = grouped[leftover_id],
		))
	return rows

/// One rack card: what it is, what it costs the body, what the parlor charges
/// for it, and whether this occupant can actually take it. `count` starts at
/// one and is bumped by build_rack_data() for every identical copy it folds in.
/obj/machinery/chrome_cradle/proc/build_ware_data(obj/item/organ/ware, state, mob/living/carbon/patient)
	var/datum/component/cyberware/chrome = ware.GetComponent(/datum/component/cyberware)
	var/list/price = get_cyberware_price(ware)
	var/installed = state == "installed"
	return list(
		"ref" = REF(ware),
		"name" = ware.name,
		"desc" = ware.desc,
		"icon" = get_cyberware_card_icon_key(ware.icon_state),
		"tier" = chrome ? chrome.tier : CYBERWARE_TIER_1,
		"load" = chrome ? chrome.chrome_load : 0,
		"capacity_bonus" = chrome ? chrome.capacity_bonus : 0,
		"state" = state,
		"count" = 1,
		"installed" = installed,
		"fits" = (installed || !istype(patient)) ? TRUE : (cyberware_insert_check(ware, patient, silent = TRUE) ? TRUE : FALSE),
		"failing" = (ware.organ_flags & ORGAN_FAILING) ? TRUE : FALSE,
		"emp_down" = chrome?.emp_down ? TRUE : FALSE,
		"browned_out" = chrome?.browned_out ? TRUE : FALSE,
		"damage" = round(ware.damage),
		"configurable" = istype(ware, /obj/item/organ/cyberimp/cyberware/chromatic_dermis),
		"price_credits" = price ? price["credits"] : 0,
		"price_vouchers" = price ? price["vouchers"] : 0,
		"price_paired" = price ? price["paired"] : FALSE,
	)

/**
 * The ink panel: the parlor's stock pigments and patterns, plus where the
 * highlighted suite currently sits, so the console can show a swatch grid
 * instead of a blocking prompt. Only offered for a suite already seated in the
 * occupant's chest, a sachet in a bag has no skin to re-key.
 */
/obj/machinery/chrome_cradle/proc/build_ink_data(mob/living/carbon/patient)
	var/obj/item/organ/cyberimp/cyberware/chromatic_dermis/dermis = selected_ware
	if(!istype(dermis) || dermis.owner != patient)
		return null
	var/list/palette = list()
	for(var/swatch_name in GLOB.cyberware_ink_palette)
		palette += list(list(
			"name" = swatch_name,
			"hex" = GLOB.cyberware_ink_palette[swatch_name],
		))
	var/list/patterns = list()
	for(var/pattern_name in GLOB.cyberware_ink_patterns)
		var/list/pattern = GLOB.cyberware_ink_patterns[pattern_name]
		patterns += list(list(
			"name" = pattern_name,
			"blurb" = pattern["blurb"],
		))
	return list(
		"color" = dermis.tattoo_color,
		"pattern" = dermis.tattoo_pattern,
		"palette" = palette,
		"patterns" = patterns,
	)

/**
 * Where the occupant's load budget lands if the highlighted piece goes in, or
 * comes out, when it is already installed, plus whatever that swap would
 * evict. This is the number the ladder design lives or dies on, so the console
 * shows it before anything is committed rather than after a refusal.
 */
/obj/machinery/chrome_cradle/proc/build_projection(mob/living/carbon/patient, state)
	if(!istype(patient) || isnull(selected_ware))
		return null
	var/datum/component/cyberware/chrome = selected_ware.GetComponent(/datum/component/cyberware)
	if(!chrome)
		return null
	var/projected_load = get_chrome_load(patient)
	var/projected_capacity = get_chrome_capacity(patient)
	var/list/evicts = list()
	if(state == "installed")
		projected_load -= chrome.chrome_load
		projected_capacity -= chrome.capacity_bonus
	else
		projected_load += chrome.chrome_load
		projected_capacity += chrome.capacity_bonus
		for(var/obj/item/organ/incumbent in selected_ware.cyberware_get_incumbents(patient))
			evicts += incumbent.name
			var/datum/component/cyberware/incumbent_chrome = incumbent.GetComponent(/datum/component/cyberware)
			if(!incumbent_chrome)
				continue
			projected_load -= incumbent_chrome.chrome_load
			projected_capacity -= incumbent_chrome.capacity_bonus
	return list(
		"load" = projected_load,
		"capacity" = projected_capacity,
		"evicts" = evicts,
	)

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
	data["busy_ware"] = busy_ware?.name
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
	data["tuneup_denial"] = has_patient ? get_tuneup_denial(patient) : "No chrome installed."

	// Settle the highlight before anything renders off it: the piece may have
	// been installed, ejected or lifted out of a pocket since it was picked.
	var/list/available = get_reachable_ware(patient)
	if(selected_ware && !(selected_ware in available))
		selected_ware = null
	// The rack runs first because stacking identical spares can move the
	// highlight onto the copy that owns the tile. Read it back afterwards or
	// the console lights up a card that isn't the one on screen.
	data["groups"] = build_rack_data(patient, available)
	data["selected"] = selected_ware ? REF(selected_ware) : null
	data["projection"] = build_projection(patient, selected_ware ? available[selected_ware] : null)
	data["ink"] = build_ink_data(patient)
	data["tray_count"] = length(tray)
	return data

/obj/machinery/chrome_cradle/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	// Off the ui, never a tracked var. Ui.close() nulls those.
	var/mob/living/acting = ui.user

	// Slab and tray controls are open to anyone the ui_status let in.
	switch(action)
		if("get_up")
			if(occupant)
				unbuckle_mob(occupant)
			return TRUE
		if("eject_tray")
			eject_tray(acting)
			return TRUE
		if("eject_cash")
			if(busy)
				return TRUE
			eject_cash(acting)
			return TRUE
		// Browsing the racks stays the occupant's alone: the highlight drives
		// the ghost and the inspector for every viewer, and a bystander
		// driving it would be fighting the person on the slab. Spinning the
		// mannequin is open to anyone watching, it changes nothing but the
		// shared facing, and the ripperdoc wants to see the back too.
		if("select")
			if(acting != occupant)
				return TRUE
			var/list/available = get_reachable_ware(occupant)
			var/obj/item/organ/ware = locate(params["ref"]) in available
			// Clicking the highlighted piece again clears it.
			selected_ware = (ware == selected_ware) ? null : ware
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

		// One swatch or one pattern per click, applied to the skin immediately.
		// The ink panel is a live picker, not a form with a commit button.
		if("set_ink")
			var/obj/item/organ/ware = locate(params["ref"]) in get_installed_cyberware(patient)
			if(!istype(ware, /obj/item/organ/cyberimp/cyberware/chromatic_dermis))
				balloon_alert(patient, "nothing to re-key!")
				return TRUE
			var/obj/item/organ/cyberimp/cyberware/chromatic_dermis/dermis = ware
			dermis.set_ink(patient, params["color"], params["pattern"])
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
