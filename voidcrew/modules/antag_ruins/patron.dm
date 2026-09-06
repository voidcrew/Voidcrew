/**
 * # Vestige Patron
 *
 * The remnant of a dead antagonist, mapped into its vestige ruin. Unkillable
 * and immovable, same treatment as the outpost traders: godmode makes
 * violence pointless and NOMOBSWAP stops walk-throughs.
 *
 * Clicking a patron opens a radial. Speak / Pact. Supplicants don't browse
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
#define PATRON_OPTION_ASCEND "Ascend"

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
	/**
	 * Boon typepaths this patron pays out of (see boon.dm; upgrades gate themselves
	 * via upgrades_from).
	 *
	 * POOLS MUST STAY DISJOINT. No boon typepath may appear in two patrons' lists.
	 * A trial snapshots its patron's pool when the pact is struck and only rechecks
	 * eligibility at completion, and a supplicant may hold only one pact and one
	 * unclaimed reward at a time. Together those keep a pool from emptying out
	 * underneath a running pact. Share a boon between two patrons and that breaks:
	 * the supplicant can take the shared boon elsewhere mid-pact, complete to an
	 * empty pool, and spend the trial for nothing (trial.dm, offer_reward) with no
	 * way to retake it. If you ever need two patrons to offer the same ability,
	 * give each its own /datum/vestige_boon subtype rather than sharing one.
	 */
	var/list/boon_types = list()
	/// Outfit dressed onto the appearance dummy
	var/outfit_path
	/// Color applied over the whole sprite after dressing (silhouettes, wrong pallor)
	var/appearance_tint
	/// Random lines for Speak
	var/list/idle_lines = list()
	/// Said when a pact is struck
	var/accept_line = "Then we have a deal."
	/// Said when the supplicant already carries a different unfinished pact
	var/busy_line = "Finish what you started, or renounce it."
	/// Said about a trial already fulfilled
	var/fulfilled_line = "You've done everything I had to ask."
	/// Said when a pact is renounced
	var/renounce_line = "Weakness."
	/// Said when the supplicant has an unclaimed boon owed to them
	var/claim_line = "I still owe you. Take your payment before you ask for more work."
	/// Said when no boon remains that this patron could pay out
	var/exhausted_line = "You've taken everything I had to give."
	/// Said when a respawned soul's lost vestige legacy is restored
	var/remember_line = "Dying doesn't cancel our deal. Take back what was yours."
	COOLDOWN_DECLARE(speak_cooldown)

/mob/living/basic/vestige_patron/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_GODMODE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOMOBSWAP, INNATE_TRAIT)
	// A patron belongs to its shrine. move_resist only stops pulling, so block the two
	// paths that ignore it: drag-drops onto beds/crates/disposals, and closets, which
	// sweep their own tile on close() rather than dragging anything (#131).
	RegisterSignal(src, COMSIG_MOUSEDROP_ONTO, PROC_REF(block_being_dragged))
	ADD_TRAIT(src, TRAIT_NO_CONTAINMENT, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NO_STORAGE_INSERT, INNATE_TRAIT)
	if(outfit_path)
		apply_dynamic_human_appearance(src, outfit_path = outfit_path)
	if(appearance_tint)
		color = appearance_tint

/// Cancels any attempt to drag-drop the patron onto something (beds, crates, disposals).
/mob/living/basic/vestige_patron/proc/block_being_dragged(atom/over, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_MOUSEDROP_ONTO

/mob/living/basic/vestige_patron/examine(mob/user)
	. = ..()
	. += span_notice("Touch it if you want to talk.")
	var/datum/vestige_trial/active = user.mind?.active_vestige_trial
	if(active && (active.type in trial_types))
		. += span_boldnotice("Your pact: [active.name]. [active.get_progress_text()]")
	var/datum/action/vestige_reward/pending = user.mind?.vestige_pending_reward
	if(pending && pending.patron_name == name)
		. += span_boldnotice("It still owes you a boon. Talk to it to collect.")

/mob/living/basic/vestige_patron/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_paw(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_alien(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_larva(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_drone(mob/living/user)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_animal(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/handle_basic_attack(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_robot(mob/living/user, list/modifiers)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/mob/living/basic/vestige_patron/attack_ai(mob/living/user)
	if(try_open_patron_menu(user))
		return TRUE
	return ..()

/// Boons and resurrection can leave the soul in a body that does not use attack_hand.
/mob/living/basic/vestige_patron/proc/try_open_patron_menu(mob/living/user)
	if(!check_menu(user) || user.combat_mode)
		return FALSE
	// show_radial_menu sleeps; don't hold up the click chain
	INVOKE_ASYNC(src, PROC_REF(open_patron_menu), user)
	return TRUE

/mob/living/basic/vestige_patron/proc/open_patron_menu(mob/living/user)
	if(!check_menu(user))
		return
	if(!user.mind)
		to_chat(user, span_warning("[src] doesn't react to you at all."))
		return
	var/datum/mind/opening_mind = user.mind
	var/list/options = list(
		PATRON_OPTION_SPEAK = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_talk"),
		PATRON_OPTION_PACT = image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_quest"),
	)
	// The capstone option only exists once this patron has nothing left to ask
	// (ascension.dm). Every other refusal is spoken rather than hidden.
	if(should_offer_ascension(user))
		options[PATRON_OPTION_ASCEND] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_lore")
	var/choice = show_radial_menu(user, src, options, custom_check = CALLBACK(src, PROC_REF(check_menu), user, opening_mind), require_near = TRUE, tooltips = TRUE)
	if(!choice || !check_menu(user, opening_mind))
		return
	switch(choice)
		if(PATRON_OPTION_SPEAK)
			speak_line()
		if(PATRON_OPTION_PACT)
			offer_pact(user)
		if(PATRON_OPTION_ASCEND)
			offer_ascension(user)

/**
 * Whether to show the capstone option at all: this patron hosts one, and this
 * soul has fulfilled every trial it has. Deliberately NOT the full eligibility
 * check, the round-time gate and the one-capstone-per-soul lock are refusals the
 * patron says out loud, so a maxed-out supplicant always sees that the door exists.
 */
/mob/living/basic/vestige_patron/proc/should_offer_ascension(mob/living/user)
	if(!hosts_ascension())
		return FALSE
	var/datum/vestige_record/record = get_vestige_record(user?.mind)
	if(!record)
		return FALSE
	for(var/trial_type in trial_types)
		if(!(trial_type in record.completed_trials))
			return FALSE
	return TRUE

/// Radial validity: supplicant still there, still conscious, still adjacent
/mob/living/basic/vestige_patron/proc/check_menu(mob/living/user, datum/mind/expected_mind)
	if(QDELETED(src) || !istype(user) || QDELETED(user))
		return FALSE
	if(IS_DEAD_OR_INCAP(user) || !user.Adjacent(src))
		return FALSE
	if(expected_mind && (QDELETED(expected_mind) || user.mind != expected_mind || expected_mind.current != user))
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

	// The dead come back; their ledger never left. Restore first, then carry on.
	// A restored unclaimed reward falls straight through to the claim gate below.
	if(restore_lost_legacy(user))
		say(remember_line)
		playsound(src, 'sound/effects/magic/curse.ogg', 30, TRUE)
	// Restoring an upgraded shapeshift can delete the form that opened this conversation.
	user = mind.current
	if(!check_menu(user))
		return

	// An unclaimed boon comes before any new bargain, reopen the claim for them
	var/datum/action/vestige_reward/pending = mind.vestige_pending_reward
	if(pending)
		say(claim_line)
		pending.open_reward_menu(user)
		return

	var/datum/vestige_trial/active = mind.active_vestige_trial
	// Their pact with us is underway: report progress, offer renunciation
	if(active && (active.type in trial_types))
		var/renounce = tgui_alert(user, "[active.get_progress_text()]", active.name, list("Continue", "Renounce"))
		if(renounce == "Renounce" && check_menu(user, mind) && mind.active_vestige_trial == active)
			qdel(active) // Destroy clears mind.active_vestige_trial
			say(renounce_line)
		return
	// A pact with someone else is underway, one hunger at a time
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

	// Offer the assignment. Declining doesn't reroll it. This is the trial they get.
	var/datum/vestige_trial/offered = new trial_type(mind, name, boon_types.Copy())
	var/accept = tgui_alert(user, offered.desc, offered.name, list("Accept", "Decline"))
	if(accept != "Accept" || !can_accept_pact(user, offered))
		qdel(offered)
		return
	mind.active_vestige_trial = offered
	offered.begin(user)
	say(accept_line)
	playsound(src, 'sound/effects/magic/curse.ogg', 30, TRUE)

/// A dialog can outlive a body swap or a second dialog's completed pact.
/mob/living/basic/vestige_patron/proc/can_accept_pact(mob/living/user, datum/vestige_trial/offered)
	if(QDELETED(offered) || !check_menu(user))
		return FALSE
	var/datum/mind/mind = offered.owner
	if(QDELETED(mind) || user.mind != mind || mind.current != user)
		return FALSE
	if(mind.active_vestige_trial || mind.vestige_pending_reward || mind.active_ascension_run)
		return FALSE
	var/datum/vestige_record/record = get_vestige_record(mind)
	if((offered.type in mind.completed_vestige_trials) || (offered.type in record?.completed_trials) || length(record?.pending_candidates))
		return FALSE
	return length(get_eligible_vestige_boons(mind, offered.boon_pool)) > 0

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
 * vestige history the current mind lacks, i.e. they respawned, copy the
 * bookkeeping back and re-grant every lost boon, in original grant order so
 * upgrade replacement lands correctly. An unclaimed reward they died holding
 * is recreated too. Any patron restores everything, not just its own theme.
 * Whichever vestige you can reach settles all accounts.
 *
 * Returns TRUE if anything tangible (a boon or a pending claim) came back.
 */
/mob/living/basic/vestige_patron/proc/restore_lost_legacy(mob/living/user)
	var/datum/mind/mind = user.mind
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(!record)
		return FALSE

	// Bookkeeping restores silently: it prevents refarming, it isn't a gift
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
		user = mind.current
		LAZYADD(mind.vestige_boons, boon_type)
		qdel(boon)
		regained = TRUE

	// The debt they died holding
	if(restore_vestige_reward(mind))
		regained = TRUE

	return regained

/mob/living/basic/vestige_patron/proc/speak_line()
	if(!length(idle_lines) || !COOLDOWN_FINISHED(src, speak_cooldown))
		return
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(pick(idle_lines))

#undef PATRON_OPTION_SPEAK
#undef PATRON_OPTION_PACT
#undef PATRON_OPTION_ASCEND
