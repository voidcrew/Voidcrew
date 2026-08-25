/**
 * # Vestige trial
 *
 * A pact between one player and a patron: a bespoke objective tracked on the
 * trial datum, paying out a boon (boon.dm) the moment it's fulfilled.
 *
 * All pact state rides the MIND. Ruin interiors (and their patron mobs)
 * unload whenever everyone leaves, so nothing here may hold a reference to
 * the patron or the map. Trial kit items follow the same rule from the other
 * side: they never store trial references, they resolve the wielder's
 * mind.active_vestige_trial at interaction time and istype-check it.
 *
 * One active trial per mind, each trial fulfillable once. Completion pays out
 * a CHOICE of boons, up to VESTIGE_REWARD_CHOICES rolled from the patron's
 * pool, carried on a claim button (boon.dm). Wherever the player is; there is
 * no return trip that a despawned ruin could strand.
 */

/datum/mind
	/// The vestige trial currently underway, if any (at most one per mind)
	var/datum/vestige_trial/active_vestige_trial
	/// Typepaths of vestige trials this mind has fulfilled
	var/list/completed_vestige_trials
	/// Typepaths of vestige boons this mind has been granted
	var/list/vestige_boons
	/// Sticky per-patron trial assignments (patron typepath -> trial typepath); rerolled only after fulfilment
	var/list/vestige_trial_assignments
	/// The unclaimed boon choice from a fulfilled pact, if any (see boon.dm)
	var/datum/action/vestige_reward/vestige_pending_reward

/**
 * # Vestige record
 *
 * The soul's copy of a player's vestige ledger, keyed by ckey and round-scoped.
 * Mind state dies with the mind when a player respawns into a new character;
 * this record does not. Every mutation of vestige mind-state writes through to
 * it, and any patron restores a mind that has fallen behind its record (see
 * restore_lost_legacy in patron.dm), so death loses your powers only until
 * you walk back into a vestige and ask.
 *
 * Doubling as the anti-refarm ledger: completions and assignments restore
 * along with the boons, so dying can't reroll an assignment or reopen a
 * fulfilled trial.
 */
GLOBAL_LIST_EMPTY(vestige_records)

/datum/vestige_record
	/// Typepaths of trials fulfilled by this soul
	var/list/completed_trials = list()
	/// Typepaths of boons granted to this soul, in grant order (bases before their upgrades)
	var/list/boons = list()
	/// Sticky trial assignments (patron typepath -> trial typepath)
	var/list/trial_assignments = list()
	/// Candidate boon typepaths of an unclaimed reward, if they died holding one
	var/list/pending_candidates
	/// Name of the patron owing that reward
	var/pending_patron_name

/// The vestige record for the soul behind a mind, made on demand when create is set
/proc/get_vestige_record(datum/mind/mind, create = FALSE)
	var/record_key = mind?.key ? ckey(mind.key) : null
	if(!record_key)
		return null
	var/datum/vestige_record/record = GLOB.vestige_records[record_key]
	if(!record && create)
		record = new
		GLOB.vestige_records[record_key] = record
	return record

/datum/vestige_trial
	/// Name shown when the patron assigns it
	var/name = "Trial"
	/// The patron's pitch, shown before accepting
	var/desc = "Prove yourself."
	/// Boon typepaths the patron pays out of, snapshotted at accept, the mob unloads with the ruin
	var/list/boon_pool
	/// The mind undertaking this trial
	var/datum/mind/owner
	/// Name of the offering patron, kept as text, the mob unloads with the ruin
	var/patron_name = "the patron"
	/// HUD reminder action, granted on accept and cleared with the pact (see below)
	var/datum/action/vestige_pact/tracker

/datum/vestige_trial/New(datum/mind/owner_mind, offering_patron_name, list/reward_pool)
	. = ..()
	owner = owner_mind
	if(offering_patron_name)
		patron_name = offering_patron_name
	boon_pool = reward_pool

/datum/vestige_trial/Destroy()
	QDEL_NULL(tracker)
	if(owner?.active_vestige_trial == src)
		owner.active_vestige_trial = null
	owner = null
	return ..()

/**
 * Called once when the pact is struck. Stands up the HUD reminder, then runs
 * the trial's own accept hook. The tracker is mind-targeted so it rides across
 * body swaps like the boons do; the trial owns it and qdels it on Destroy, so
 * the reminder appears and disappears exactly with the pact.
 */
/datum/vestige_trial/proc/begin(mob/living/user)
	tracker = new(owner)
	tracker.Grant(user)
	on_accepted(user)

/// Hands out the trial kit and any parting words. Called once, on accept.
/datum/vestige_trial/proc/on_accepted(mob/living/user)
	return

/// Pushes fresh progress into the HUD reminder's tooltip. Call after progress changes.
/datum/vestige_trial/proc/refresh_tracker()
	tracker?.build_all_button_icons(UPDATE_BUTTON_NAME)

/// One-line progress readout, shown by the patron and on patron examine
/datum/vestige_trial/proc/get_progress_text()
	return "The pact is unfulfilled."

/// Puts a freshly created kit item into the supplicant's hands, or at their feet
/datum/vestige_trial/proc/hand_over(mob/living/user, obj/item/kit)
	if(!user.put_in_hands(kit))
		kit.forceMove(get_turf(user))
	return kit

/**
 * Fulfills the pact: bookkeeping, the reward roll, flavor.
 *
 * Deletes the trial datum: callers (kit items, ritual structures) must not
 * touch the trial after calling this.
 */
/datum/vestige_trial/proc/complete()
	if(!owner)
		return
	LAZYADD(owner.completed_vestige_trials, type)
	if(owner.active_vestige_trial == src)
		owner.active_vestige_trial = null
	var/datum/vestige_record/record = get_vestige_record(owner, create = TRUE)
	record?.completed_trials |= type

	var/mob/living/user = owner.current
	if(isliving(user))
		to_chat(user, span_bolddanger("You hear [patron_name] in the back of your head: \"The pact is done.\""))
		playsound(user, 'sound/effects/magic/curse.ogg', 50, TRUE)
	// Runs body or no body. Deferred completions (the egg's hatch beat, the Red
	// Road's concluding beat) can land after the keeper has been gibbed, and the
	// pact is spent either way, so the debt has to be booked regardless.
	offer_reward(user)
	qdel(src)

/**
 * Rolls the boon candidates this fulfilled pact pays out and leaves the owner
 * holding the claim button (see boon.dm). The choice is made at the player's
 * leisure, mid-fight completions shouldn't force a menu through the chaos.
 */
/datum/vestige_trial/proc/offer_reward(mob/living/user)
	if(owner.vestige_pending_reward) // can't normally happen. Patrons refuse pacts while a debt is unclaimed
		return
	var/list/eligible = get_eligible_vestige_boons(owner, boon_pool)
	if(!length(eligible))
		if(isliving(user))
			to_chat(user, span_notice("\"You've already taken everything I had to give.\""))
		return
	var/list/candidates = list()
	for(var/pick_count in 1 to min(VESTIGE_REWARD_CHOICES, length(eligible)))
		candidates += pick_n_take(eligible)
	// The ledger is written FIRST, so the debt survives both death and a completion
	// that fires with no body left to hand the button to. Either way the next patron
	// rebuilds the claim from it (restore_lost_legacy in patron.dm).
	var/datum/vestige_record/record = get_vestige_record(owner, create = TRUE)
	if(record)
		record.pending_candidates = candidates.Copy()
		record.pending_patron_name = patron_name
	if(!isliving(user)) // nobody to hand it to; the ledger holds it until they come back
		return
	var/datum/action/vestige_reward/reward = new(owner, candidates, patron_name)
	reward.Grant(user)
	owner.vestige_pending_reward = reward
	to_chat(user, span_boldnotice("\"Now for your payment. Pick one.\""))
	INVOKE_ASYNC(reward, TYPE_PROC_REF(/datum/action/vestige_reward, open_reward_menu), user)

/**
 * # Vestige pact tracker
 *
 * A HUD reminder of the pact you're bound to, the action-bar button the
 * patron leaves you with. Mind-targeted so it follows you across bodies like
 * the boons and learned spells do, and it holds no trial reference: it resolves
 * the mind's active pact whenever it's read, the same rule the kit items obey.
 *
 * Hovering the button shows the pact's live terms and progress; clicking it
 * prints the full pitch and progress to chat. It is a readout, not a power, so
 * it stays usable while downed or dead.
 */
/datum/action/vestige_pact
	name = "Vestige Pact"
	desc = "You have an unfinished pact. Click to review it."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "eye"
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	check_flags = NONE

/// Resolves the bound mind's current pact, or null if it has somehow ended
/datum/action/vestige_pact/proc/get_trial()
	var/datum/mind/mind = target
	return istype(mind) ? mind.active_vestige_trial : null

/datum/action/vestige_pact/update_button_name(atom/movable/screen/movable/action_button/button, force)
	var/datum/vestige_trial/trial = get_trial()
	// Keep the tooltip title stable (the button's saved position keys off name);
	// the live details ride in the description, which the tooltip reads on hover.
	desc = trial \
		? "[trial.name]: [trial.patron_name]'s pact.\n[trial.get_progress_text()]\nClick to review the full terms." \
		: initial(desc)
	return ..()

/datum/action/vestige_pact/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	var/datum/vestige_trial/trial = get_trial()
	if(!trial)
		return
	to_chat(owner, span_boldnotice("[trial.patron_name]'s pact: [trial.name]"))
	to_chat(owner, span_notice(trial.desc))
	to_chat(owner, span_boldnotice(trial.get_progress_text()))
