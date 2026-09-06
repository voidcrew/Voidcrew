/**
 * # Vestige trial
 *
 * A pact between one player and a patron: a bespoke objective tracked on the
 * trial datum, paying out a boon (boon.dm) the moment it's fulfilled.
 *
 * All pact state rides the MIND. Ruin interiors (and their patron mobs)
 * unload whenever everyone leaves, so nothing here may hold a reference to
 * the patron or the map. Trial kit items follow the same rule from the other
 * side: resolve the wielder's mind.active_vestige_trial at interaction time.
 * Encounter actors may additionally bind a weakref to the exact attempt,
 * so a stale callback cannot progress a replacement trial.
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
	/// Identifies which completed pact an outstanding claim belongs to.
	var/reward_generation = 0
	/// Different old/new-body trials can finish after respawn. Every completion still pays.
	var/list/queued_rewards = list()

/// Retain the oldest unpaid roll when a previous body's work finishes late.
/datum/vestige_record/proc/queue_reward(list/candidates, patron_name)
	if(length(pending_candidates))
		queued_rewards += list(list("candidates" = candidates.Copy(), "patron_name" = patron_name))
		return
	reward_generation++
	pending_candidates = candidates.Copy()
	pending_patron_name = patron_name

/// Settling a debt advances once; old buttons no longer match the new generation.
/datum/vestige_record/proc/settle_reward()
	pending_candidates = null
	pending_patron_name = null
	if(!length(queued_rewards))
		return
	var/list/next_reward = queued_rewards[1]
	queued_rewards.Cut(1, 2)
	reward_generation++
	pending_candidates = next_reward["candidates"]
	pending_patron_name = next_reward["patron_name"]

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
	/// Only trial-created equipment/actors belong here, never borrowed player property.
	var/list/loan_refs = list()
	/// Completion callbacks may arrive more than once in the same tick.
	var/fulfilled = FALSE

/datum/vestige_trial/New(datum/mind/owner_mind, offering_patron_name, list/reward_pool)
	. = ..()
	owner = owner_mind
	if(owner)
		RegisterSignal(owner, COMSIG_QDELETING, PROC_REF(on_owner_deleted))
	if(offering_patron_name)
		patron_name = offering_patron_name
	boon_pool = reward_pool

/datum/vestige_trial/Destroy()
	QDEL_NULL(tracker)
	if(owner)
		UnregisterSignal(owner, COMSIG_QDELETING)
	if(owner?.active_vestige_trial == src)
		owner.active_vestige_trial = null
	release_occupied_loans()
	// Containers delete their contents. Return anything the player added after
	// the kit was issued before reclaiming the original loans.
	for(var/datum/weakref/loan_ref as anything in loan_refs)
		var/atom/movable/loan = loan_ref.resolve()
		if(!loan)
			continue
		var/turf/drop_turf = get_turf(loan) || get_turf(owner?.current)
		if(istype(loan, /obj/item/bodypart/chest))
			var/obj/item/bodypart/chest/chest = loan
			if(chest.cavity_item && !(WEAKREF(chest.cavity_item) in loan_refs))
				chest.cavity_item = null // Chest destruction also deletes this cached reference.
		for(var/atom/movable/content as anything in loan.contents.Copy())
			if(!(WEAKREF(content) in loan_refs) && drop_turf)
				return_player_property(content, drop_turf)
	for(var/datum/weakref/loan_ref as anything in loan_refs)
		var/atom/movable/loan = loan_ref.resolve()
		if(loan)
			qdel(loan)
	loan_refs = null
	owner = null
	return ..()

/// A supplied actor can become somebody's body through ordinary brain surgery.
/// Reclaim loose equipment, but never reclaim a person or their installed anatomy.
/datum/vestige_trial/proc/release_occupied_loans()
	for(var/datum/weakref/loan_ref as anything in loan_refs.Copy())
		var/atom/movable/loan = loan_ref.resolve()
		var/mob/living/occupant
		if(isliving(loan))
			occupant = loan
		else if(isorgan(loan))
			var/obj/item/organ/organ = loan
			occupant = organ.owner || organ.bodypart_owner?.owner
			if(istype(organ, /obj/item/organ/brain))
				var/obj/item/organ/brain/brain = organ
				// Brain Destroy deletes this cached mob even if it was moved outside.
				if(brain.brainmob?.mind || brain.brainmob?.client)
					loan_refs -= loan_ref
					continue
		else if(istype(loan, /obj/item/bodypart))
			var/obj/item/bodypart/limb = loan
			occupant = limb.owner
		if(occupant?.mind || occupant?.client)
			loan_refs -= loan_ref

/// The attempt owns its loans; deleting its mind must not orphan them.
/datum/vestige_trial/proc/on_owner_deleted(datum/mind/source)
	SIGNAL_HANDLER
	qdel(src)

/// Anatomy must detach before movement, or its callbacks can strand it in nullspace.
/datum/vestige_trial/proc/return_player_property(atom/movable/property, turf/drop_turf)
	if(isorgan(property))
		var/obj/item/organ/organ = property
		if(organ.owner)
			organ.Remove(organ.owner, special = TRUE)
		else if(organ.bodypart_owner)
			organ.bodypart_remove(organ.bodypart_owner)
	else if(istype(property, /obj/item/bodypart))
		var/obj/item/bodypart/limb = property
		// Special limb removal moves organs out but leaves them on the mob's
		// registry. Return player transplants before that registry is destroyed.
		for(var/obj/item/organ/organ in limb.contents.Copy())
			if(!(WEAKREF(organ) in loan_refs))
				return_player_property(organ, drop_turf)
		if(limb.owner)
			limb.drop_limb(special = TRUE, dismembered = FALSE, move_to_floor = FALSE)
	property.forceMove(drop_turf)

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
	register_loan(kit)
	if(!user.put_in_hands(kit))
		kit.forceMove(get_turf(user))
	return kit

/// Track a newly created loan, including the original contents of a supplied kit.
/// Deployed structures and actors must register separately. Weakrefs ensure a
/// consumed item never keeps the trial or its owner alive.
/datum/vestige_trial/proc/register_loan(atom/movable/loan)
	if(!loan || QDELETED(loan))
		return null
	var/already_registered = (WEAKREF(loan) in loan_refs)
	loan_refs |= WEAKREF(loan)
	if(isstack(loan) && !already_registered)
		RegisterSignal(loan, COMSIG_STACK_SPLIT, PROC_REF(on_loan_stack_split))
		RegisterSignals(loan, list(COMSIG_STACK_CAN_MERGE, COMSIG_STACK_CAN_RECEIVE_MERGE), PROC_REF(check_loan_stack_merge))
	for(var/obj/item/part in loan.contents)
		register_loan(part)
	return loan

/// Splitting a loan does not turn its contents into permanent player property.
/datum/vestige_trial/proc/on_loan_stack_split(obj/item/stack/source, obj/item/stack/split)
	SIGNAL_HANDLER
	register_loan(split)

/// Mixing player supplies into a loan would delete them when the pact ends.
/datum/vestige_trial/proc/check_loan_stack_merge(obj/item/stack/source, obj/item/stack/other, inhand)
	SIGNAL_HANDLER
	if(!(WEAKREF(other) in loan_refs))
		return CANCEL_STACK_MERGE
	return NONE

/// Recover a lost or failed kit without rerolling the assigned trial or its reward pool.
/datum/vestige_trial/proc/restart(mob/living/user)
	if(QDELETED(src) || fulfilled || owner?.current != user || owner.active_vestige_trial != src || user.stat != CONSCIOUS)
		return FALSE
	var/datum/mind/keeper = owner
	var/trial_type = type
	var/patron = patron_name
	var/list/pool = boon_pool?.Copy()
	qdel(src)
	var/datum/vestige_trial/replacement = new trial_type(keeper, patron, pool)
	keeper.active_vestige_trial = replacement
	replacement.begin(user)
	to_chat(user, span_notice("The pact begins again. Its old equipment and progress are gone."))
	return TRUE

/**
 * Fulfills the pact: bookkeeping, the reward roll, flavor.
 *
 * Deletes the trial datum: callers (kit items, ritual structures) must not
 * touch the trial after calling this.
 */
/datum/vestige_trial/proc/complete()
	if(!owner || QDELETED(src) || fulfilled || owner.active_vestige_trial != src || (type in owner.completed_vestige_trials))
		return
	var/datum/vestige_record/record = get_vestige_record(owner, create = TRUE)
	// A deferred old-body attempt can finish after this soul has respawned
	// and begun the same assignment again. The round ledger decides once.
	if(type in record?.completed_trials)
		LAZYOR(owner.completed_vestige_trials, type)
		qdel(src)
		return
	fulfilled = TRUE
	LAZYADD(owner.completed_vestige_trials, type)
	if(owner.active_vestige_trial == src)
		owner.active_vestige_trial = null
	record?.completed_trials |= type

	var/mob/living/user = owner.current
	if(isliving(user))
		to_chat(user, span_bolddanger("You hear [patron_name] in the back of your head: \"The pact is done.\""))
		playsound(user, 'sound/effects/magic/curse.ogg', 50, TRUE)
	// Runs body or no body. Deferred combat callbacks can land after the keeper
	// has been gibbed; the spent pact must still book its reward debt.
	offer_reward(user)
	qdel(src)

/**
 * Rolls the boon candidates this fulfilled pact pays out and leaves the owner
 * holding the claim button (see boon.dm). The choice is made at the player's
 * leisure, mid-fight completions shouldn't force a menu through the chaos.
 */
/datum/vestige_trial/proc/offer_reward(mob/living/user)
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
		record.queue_reward(candidates, patron_name)
	if(owner.vestige_pending_reward)
		return // The additional payment is safely queued behind its current button.
	if(!isliving(user)) // nobody to hand it to; the ledger holds it until they come back
		return
	// If another body's debt came first, this body settles that one before its own.
	var/datum/action/vestige_reward/reward = new(owner, record?.pending_candidates?.Copy() || candidates, record?.pending_patron_name || patron_name)
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
 * prints the full pitch and progress to chat. A conscious owner may also
 * restart the same assignment to recover a failed or missing kit.
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
	if(!isliving(owner) || owner.stat != CONSCIOUS)
		return
	var/choice = tgui_alert(owner, "[trial.get_progress_text()]\n\nRestarting resets all progress and reclaims the old trial equipment. You receive the same trial and a fresh kit.", trial.name, list("Keep going", "Restart trial"))
	if(choice == "Restart trial" && !QDELETED(src) && get_trial() == trial)
		trial.restart(owner)

/// A world turf stays at its coordinates when a shuttle leaves. Keep spatial
/// objectives attached to the deck instead, including when that deck rotates.
/datum/vestige_trial/proc/mark_turf(turf/location)
	if(!location)
		return null
	return register_loan(new /obj/effect/vestige_trial_marker(location))

/// An invisible reference point; ordinary shuttle movement carries it with its tile.
/obj/effect/vestige_trial_marker
	name = "vestige reference point"
	icon = null
	invisibility = INVISIBILITY_ABSTRACT
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	anchored = TRUE
	/// Committed shuttle movement lasts until every atom has its final direction.
	var/shuttle_moving = FALSE

/obj/effect/vestige_trial_marker/onShuttleMove(turf/newT, turf/oldT, list/movement_force, move_dir, obj/docking_port/stationary/old_dock, obj/docking_port/mobile/moving_dock)
	shuttle_moving = TRUE
	return ..()

/obj/effect/vestige_trial_marker/lateShuttleMove(turf/oldT, list/movement_force, move_dir)
	. = ..()
	shuttle_moving = FALSE
