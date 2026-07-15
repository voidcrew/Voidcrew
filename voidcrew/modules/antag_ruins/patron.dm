/**
 * # Vestige Patron
 *
 * The remnant of a dead antagonist, mapped into its vestige ruin. Unkillable
 * and immovable, same treatment as the outpost traders: godmode makes
 * violence pointless and NOMOBSWAP stops walk-throughs.
 *
 * Clicking a patron opens a radial — Speak / Pact. Supplicants don't browse
 * trials: the patron assigns each mind ONE trial, rolled at random from its
 * remaining pool, and the assignment holds through declines and renunciations
 * (no rerolling until it's fulfilled). Fulfilment pays out a choice of boons
 * via the claim button (boon.dm); a patron won't strike a new pact while a
 * claim sits unspent.
 *
 * Patrons are STATELESS. The ruin interior (and this mob with it) is wiped
 * whenever everyone leaves, so everything about a supplicant's pact lives on
 * their mind (see trial.dm) and the patron rediscovers it by lookup.
 */

#define PATRON_OPTION_SPEAK "Speak"
#define PATRON_OPTION_PACT "Pact"

/mob/living/basic/vestige_patron
	name = "vestige"
	desc = "Something that used to be someone."
	icon = 'icons/mob/simple/simple_human.dmi'
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	density = TRUE
	move_resist = INFINITY
	basic_mob_flags = NONE
	faction = list(FACTION_NEUTRAL)
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

	/// Trial typepaths this patron can assign (one rolled per supplicant, sticky until fulfilled)
	var/list/trial_types = list()
	/// Boon typepaths this patron pays out of (see boon.dm; upgrades gate themselves via upgrades_from)
	var/list/boon_types = list()
	/// Outfit dressed onto the appearance dummy
	var/outfit_path
	/// Color applied over the whole sprite after dressing (silhouettes, wrong pallor)
	var/appearance_tint
	/// Random lines for Speak
	var/list/idle_lines = list()
	/// Said when a pact is struck
	var/accept_line = "It is agreed."
	/// Said when the supplicant already carries a different unfinished pact
	var/busy_line = "Finish what you began, or renounce it."
	/// Said about a trial already fulfilled
	var/fulfilled_line = "That debt is paid."
	/// Said when a pact is renounced
	var/renounce_line = "Weakness."
	/// Said when the supplicant has an unclaimed boon owed to them
	var/claim_line = "You are owed. Claim it before you ask for more."
	/// Said when no boon remains that this patron could pay out
	var/exhausted_line = "You have taken all I had to give."
	/// Said when a respawned soul's lost vestige legacy is restored
	var/remember_line = "The pact outlives the flesh. What was yours returns to you."
	COOLDOWN_DECLARE(speak_cooldown)

/mob/living/basic/vestige_patron/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	if(outfit_path)
		apply_dynamic_human_appearance(src, outfit_path = outfit_path)
	if(appearance_tint)
		color = appearance_tint

/mob/living/basic/vestige_patron/examine(mob/user)
	. = ..()
	. += span_notice("A tap on the shoulder — if you dare — opens negotiations.")
	var/datum/vestige_trial/active = user.mind?.active_vestige_trial
	if(active && (active.type in trial_types))
		. += span_boldnotice("Your pact: [active.name]. [active.get_progress_text()]")
	var/datum/action/vestige_reward/pending = user.mind?.vestige_pending_reward
	if(pending && pending.patron_name == name)
		. += span_boldnotice("A debt is owed to you. Speak, and claim it.")

/mob/living/basic/vestige_patron/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(user.combat_mode)
		return ..()
	// show_radial_menu sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(open_patron_menu), user)
	return TRUE

/mob/living/basic/vestige_patron/proc/open_patron_menu(mob/living/user)
	if(!user.mind)
		to_chat(user, span_warning("[src] looks through you as if you weren't there at all."))
		return
	var/list/options = list(
		PATRON_OPTION_SPEAK = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
		PATRON_OPTION_PACT = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_lore"),
	)
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user), require_near = TRUE, tooltips = TRUE)
	if(!choice || !check_menu(user))
		return
	switch(choice)
		if(PATRON_OPTION_SPEAK)
			speak_line()
		if(PATRON_OPTION_PACT)
			offer_pact(user)

/// Radial validity: supplicant still there, still conscious, still adjacent
/mob/living/basic/vestige_patron/proc/check_menu(mob/living/user)
	if(!istype(user))
		return FALSE
	if(IS_DEAD_OR_INCAP(user) || !user.Adjacent(src))
		return FALSE
	return TRUE

/**
 * The pact conversation: settle an unclaimed debt, report progress on the
 * running pact, or offer the one trial this patron has assigned this mind.
 */
/mob/living/basic/vestige_patron/proc/offer_pact(mob/living/user)
	var/datum/mind/mind = user.mind
	if(!mind)
		return

	// The dead come back; their ledger never left. Restore first, then carry on —
	// a restored unclaimed reward falls straight through to the claim gate below.
	if(restore_lost_legacy(user))
		say(remember_line)
		playsound(src, 'sound/effects/magic/curse.ogg', 30, TRUE)

	// An unclaimed boon comes before any new bargain — reopen the claim for them
	var/datum/action/vestige_reward/pending = mind.vestige_pending_reward
	if(pending)
		say(claim_line)
		pending.open_reward_menu(user)
		return

	var/datum/vestige_trial/active = mind.active_vestige_trial
	// Their pact with us is underway: report progress, offer renunciation
	if(active && (active.type in trial_types))
		var/renounce = tgui_alert(user, "[active.get_progress_text()]", active.name, list("Continue", "Renounce"))
		if(renounce == "Renounce" && check_menu(user) && mind.active_vestige_trial == active)
			qdel(active) // Destroy clears mind.active_vestige_trial
			say(renounce_line)
		return
	// A pact with someone else is underway — one hunger at a time
	if(active)
		say(busy_line)
		return

	var/trial_type = get_assigned_trial(mind)
	if(!trial_type)
		say(fulfilled_line)
		return
	if(!length(get_eligible_vestige_boons(mind, boon_types)))
		say(exhausted_line)
		return

	// Offer the assignment. Declining doesn't reroll it — this is the trial they get.
	var/datum/vestige_trial/offered = new trial_type(mind, name, boon_types.Copy())
	var/accept = tgui_alert(user, offered.desc, offered.name, list("Accept", "Decline"))
	if(accept != "Accept" || !check_menu(user) || mind.active_vestige_trial)
		qdel(offered)
		return
	mind.active_vestige_trial = offered
	offered.begin(user)
	say(accept_line)
	playsound(src, 'sound/effects/magic/curse.ogg', 30, TRUE)

/**
 * The trial this patron has assigned the given mind, rolling a fresh one from
 * the not-yet-fulfilled pool when there's no live assignment. Sticky on the
 * mind so declining (or renouncing) and asking again can't fish for a
 * different trial. Null once every trial is fulfilled.
 */
/mob/living/basic/vestige_patron/proc/get_assigned_trial(datum/mind/mind)
	var/list/remaining = trial_types.Copy()
	if(mind.completed_vestige_trials)
		remaining -= mind.completed_vestige_trials
	if(!length(remaining))
		return null
	var/assigned = LAZYACCESS(mind.vestige_trial_assignments, type)
	if(assigned && (assigned in remaining))
		return assigned
	assigned = pick(remaining)
	LAZYSET(mind.vestige_trial_assignments, type, assigned)
	// Assignments follow the soul: dying can't reroll them
	var/datum/vestige_record/record = get_vestige_record(mind, create = TRUE)
	if(record)
		record.trial_assignments[type] = assigned
	return assigned

/**
 * Death does not void a ledger: when this player's soul (ckey record) carries
 * vestige history the current mind lacks — i.e. they respawned — copy the
 * bookkeeping back and re-grant every lost boon, in original grant order so
 * upgrade replacement lands correctly. An unclaimed reward they died holding
 * is recreated too. Any patron restores everything, not just its own theme —
 * whichever vestige you can reach settles all accounts.
 *
 * Returns TRUE if anything tangible (a boon or a pending claim) came back.
 */
/mob/living/basic/vestige_patron/proc/restore_lost_legacy(mob/living/user)
	var/datum/mind/mind = user.mind
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(!record)
		return FALSE

	// Bookkeeping restores silently — it prevents refarming, it isn't a gift
	for(var/trial_type in record.completed_trials)
		if(!(trial_type in mind.completed_vestige_trials))
			LAZYADD(mind.completed_vestige_trials, trial_type)
	for(var/patron_type in record.trial_assignments)
		LAZYSET(mind.vestige_trial_assignments, patron_type, record.trial_assignments[patron_type])

	var/regained = FALSE
	for(var/datum/vestige_boon/boon_type as anything in record.boons)
		if(boon_type in mind.vestige_boons)
			continue
		var/datum/vestige_boon/boon = new boon_type()
		boon.grant(user, mind)
		LAZYADD(mind.vestige_boons, boon_type)
		qdel(boon)
		regained = TRUE

	// The debt they died holding
	if(length(record.pending_candidates) && !mind.vestige_pending_reward)
		var/datum/action/vestige_reward/reward = new(mind, record.pending_candidates.Copy(), record.pending_patron_name)
		reward.Grant(user)
		mind.vestige_pending_reward = reward
		regained = TRUE

	return regained

/mob/living/basic/vestige_patron/proc/speak_line()
	if(!length(idle_lines) || !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(pick(idle_lines))

#undef PATRON_OPTION_SPEAK
#undef PATRON_OPTION_PACT
