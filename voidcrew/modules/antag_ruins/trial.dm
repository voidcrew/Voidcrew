/**
 * # Vestige trial
 *
 * A pact between one player and a patron: a bespoke objective tracked on the
 * trial datum, paying out a boon (boon.dm) the moment it's fulfilled.
 *
 * All pact state rides the MIND. Ruin interiors (and their patron mobs)
 * unload whenever everyone leaves, so nothing here may hold a reference to
 * the patron or the map. Trial kit items follow the same rule from the other
 * side: they never store trial references — they resolve the wielder's
 * mind.active_vestige_trial at interaction time and istype-check it.
 *
 * One active trial per mind, each trial fulfillable once, each boon granted
 * once. Boons pay out immediately on completion, wherever the player is —
 * there is no return trip that a despawned ruin could strand.
 */

/datum/mind
	/// The vestige trial currently underway, if any (at most one per mind)
	var/datum/vestige_trial/active_vestige_trial
	/// Typepaths of vestige trials this mind has fulfilled
	var/list/completed_vestige_trials
	/// Typepaths of vestige boons this mind has been granted
	var/list/vestige_boons

/datum/vestige_trial
	/// Name shown in the patron's menu
	var/name = "Trial"
	/// The patron's pitch, shown before accepting
	var/desc = "Prove yourself."
	/// Boon typepath granted on completion (see boon.dm)
	var/boon_type
	/// The mind undertaking this trial
	var/datum/mind/owner
	/// Name of the offering patron, kept as text — the mob unloads with the ruin
	var/patron_name = "the patron"
	/// HUD reminder action, granted on accept and cleared with the pact (see below)
	var/datum/action/vestige_pact/tracker

/datum/vestige_trial/New(datum/mind/owner_mind, offering_patron_name)
	. = ..()
	owner = owner_mind
	if(offering_patron_name)
		patron_name = offering_patron_name

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
 * Fulfills the pact: bookkeeping, immediate boon payout, flavor.
 *
 * Deletes the trial datum — callers (kit items, ritual structures) must not
 * touch the trial after calling this.
 */
/datum/vestige_trial/proc/complete()
	if(!owner)
		return
	LAZYADD(owner.completed_vestige_trials, type)
	if(owner.active_vestige_trial == src)
		owner.active_vestige_trial = null

	var/mob/living/user = owner.current
	if(isliving(user))
		to_chat(user, span_bolddanger("[patron_name]'s voice crawls up the back of your skull: \"The pact is fulfilled.\""))
		playsound(user, 'sound/effects/magic/curse.ogg', 50, TRUE)
		if(boon_type && !(boon_type in owner.vestige_boons))
			var/datum/vestige_boon/boon = new boon_type()
			boon.grant(user, owner)
			LAZYADD(owner.vestige_boons, boon_type)
			qdel(boon)
	qdel(src)

/**
 * # Vestige pact tracker
 *
 * A HUD reminder of the pact you're bound to — the action-bar button the
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
	desc = "You carry an unfulfilled pact. Click to recall its terms."
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
		? "[trial.name] — [trial.patron_name]'s pact.\n[trial.get_progress_text()]\nClick to recall the full terms." \
		: initial(desc)
	return ..()

/datum/action/vestige_pact/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	var/datum/vestige_trial/trial = get_trial()
	if(!trial)
		return
	to_chat(owner, span_boldnotice("[trial.patron_name]'s pact — [trial.name]"))
	to_chat(owner, span_notice(trial.desc))
	to_chat(owner, span_boldnotice(trial.get_progress_text()))
