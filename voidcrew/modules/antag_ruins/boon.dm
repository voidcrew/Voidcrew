/**
 * # Vestige boon
 *
 * A ported antagonist ability, chosen as payment when a trial completes. Boon
 * datums are stateless granters: instantiated, grant() called, deleted.
 *
 * Every boon must work on a plain human with no antag datum attached, either
 * an ability that's already standalone (wizard spells, shadow walk) or a
 * standalone reimplementation (see the theme files).
 *
 * Boons form upgrade chains via upgrades_from: an upgrade only enters the
 * offer pool once the boon it grows from is owned, and granting it replaces
 * the old ability rather than stacking a second copy.
 */

/datum/vestige_boon
	/// Display name, shown in the reward menu
	var/name = "Boon"
	/// One-line pitch shown before the supplicant commits to this boon
	var/desc
	/// Flavor line printed when granted
	var/grant_text
	/// Boon typepath this one grows out of. Offered only once that boon is owned; granting this replaces it.
	var/upgrades_from
	/// Explicit reward-radial icon file, for boons that are neither spells nor items (spell/item boons derive theirs)
	var/radial_icon
	/// Icon state paired with radial_icon
	var/radial_icon_state

/// Manifests the boon on the supplicant. user is owner.current at grant time.
/datum/vestige_boon/proc/grant(mob/living/user, datum/mind/owner)
	if(grant_text)
		to_chat(user, span_boldnotice(grant_text))

/**
 * Grants an action (spell or otherwise). Mind-targeted, so it follows the
 * player across bodies, the same mechanism as learned wizard spells.
 */
/datum/vestige_boon/spell
	/// Typepath of the /datum/action to grant
	var/spell_type

/datum/vestige_boon/spell/grant(mob/living/user, datum/mind/owner)
	..()
	if(!spell_type)
		return
	remove_replaced_spell(user)
	// Stripping the old ability can reshape its owner, removing a shapeshift
	// boon mid-form unshifts the claimant and DELETES the shape mob we were
	// handed as user. Re-resolve the body before granting the replacement.
	if(owner?.current)
		user = owner.current
	var/datum/action/granted = new spell_type(owner || user)
	granted.Grant(user)

/// An upgrade takes the old ability's place: strip the action granted by the boon this one grew from
/datum/vestige_boon/spell/proc/remove_replaced_spell(mob/living/user)
	if(!ispath(upgrades_from, /datum/vestige_boon/spell))
		return
	var/datum/vestige_boon/spell/prior_boon = upgrades_from
	var/prior_spell_type = initial(prior_boon.spell_type)
	if(!prior_spell_type)
		return
	for(var/datum/action/old_action as anything in user.actions)
		if(old_action.type == prior_spell_type)
			qdel(old_action)
			return

/// Conjures a physical item into the supplicant's hands
/datum/vestige_boon/item
	/// Typepath of the item to spawn
	var/item_type

/datum/vestige_boon/item/grant(mob/living/user, datum/mind/owner)
	..()
	if(!item_type)
		return
	var/obj/item/prize = new item_type(get_turf(user))
	user.put_in_hands(prize)

/**
 * The boons in pool the given mind could be offered right now: not yet owned,
 * and (for upgrades) growing out of a boon that IS owned.
 */
/proc/get_eligible_vestige_boons(datum/mind/owner, list/pool)
	var/list/eligible = list()
	for(var/datum/vestige_boon/boon_type as anything in pool)
		if(boon_type in owner.vestige_boons)
			continue
		var/prerequisite = initial(boon_type.upgrades_from)
		if(prerequisite && !(prerequisite in owner.vestige_boons))
			continue
		eligible += boon_type
	return eligible

/// Radial menu icon for a boon typepath, the granted spell's or item's own icon where possible
/proc/vestige_boon_radial_image(datum/vestige_boon/boon_type)
	if(initial(boon_type.radial_icon))
		return image(icon = initial(boon_type.radial_icon), icon_state = initial(boon_type.radial_icon_state))
	if(ispath(boon_type, /datum/vestige_boon/spell))
		var/datum/vestige_boon/spell/spell_boon = boon_type
		var/datum/action/spell_type = initial(spell_boon.spell_type)
		if(spell_type)
			return image(icon = initial(spell_type.button_icon), icon_state = initial(spell_type.button_icon_state))
	else if(ispath(boon_type, /datum/vestige_boon/item))
		var/datum/vestige_boon/item/item_boon = boon_type
		var/obj/item/item_type = initial(item_boon.item_type)
		if(item_type)
			return image(icon = initial(item_type.icon), icon_state = initial(item_type.icon_state))
	return image(icon = 'voidcrew/icons/hud/radial.dmi', icon_state = "radial_boon")

/**
 * # Vestige boon claim
 *
 * The debt a fulfilled pact leaves behind: an action-bar button carrying the
 * boon candidates rolled when the trial completed. Mind-targeted like the pact
 * tracker so the claim follows the player across bodies, and usable while
 * downed or dead, choosing a payment is not a power.
 *
 * Clicking it opens a radial of the candidates anchored on the claimant;
 * picking one shows the boon's pitch behind a confirm, so a stray click can't
 * spend the choice. The button (and the debt) persists until a boon is taken.
 * Patrons refuse to strike new pacts while one of these is outstanding.
 */
/datum/action/vestige_reward
	name = "Claim Your Boon"
	desc = "A patron owes you. Click to choose your payment."
	button_icon = 'icons/mob/actions/actions_ecult.dmi'
	button_icon_state = "mansus_grasp"
	background_icon_state = "bg_heretic"
	overlay_icon_state = "bg_heretic_border"
	check_flags = NONE
	/// Boon typepaths on offer, rolled once when the pact completed
	var/list/candidates
	/// Name of the owing patron, kept as text, the mob unloads with the ruin
	var/patron_name = "the patron"
	/// Guards against stacked radial menus
	var/choosing = FALSE
	/// Also guards callbacks from menus already open when another claim settles the debt.
	var/paid = FALSE

/datum/action/vestige_reward/New(Target, list/boon_candidates, offering_patron_name)
	. = ..()
	candidates = boon_candidates
	if(offering_patron_name)
		patron_name = offering_patron_name

/datum/action/vestige_reward/Destroy()
	var/datum/mind/mind = target
	if(istype(mind) && mind.vestige_pending_reward == src)
		mind.vestige_pending_reward = null
	return ..()

/datum/action/vestige_reward/Trigger(mob/clicker, trigger_flags)
	. = ..()
	if(!.)
		return
	INVOKE_ASYNC(src, PROC_REF(open_reward_menu), owner)

/// Menu validity: the claim still exists and still belongs to this mob. Death doesn't void a debt.
/datum/action/vestige_reward/proc/menu_check(mob/living/user)
	return !QDELETED(src) && !QDELETED(user) && (src in user.actions)

/// Runs the full claim conversation. Sleeps; call via INVOKE_ASYNC from click chains.
/datum/action/vestige_reward/proc/open_reward_menu(mob/living/user)
	if(choosing || QDELETED(src) || !isliving(user))
		return
	var/datum/mind/mind = target
	if(!istype(mind))
		return
	// The soul's ledger is the one authority on whether a debt is still outstanding.
	// A claim button can outlive the debt it was made for: dying strands one on the
	// old mind while restore_lost_legacy (patron.dm) builds a fresh one on the new
	// mind, and both read the same ckey-keyed record. Whichever is spent first clears
	// the record, and this voids the other instead of paying the boon out twice.
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(record && !length(record.pending_candidates))
		to_chat(user, span_notice("[patron_name] has already settled this debt."))
		qdel(src)
		return
	// The roll may have gone stale since completion; drop anything now owned or out of reach
	var/list/live_candidates = get_eligible_vestige_boons(mind, candidates)
	if(!length(live_candidates))
		to_chat(user, span_notice("[patron_name] has nothing left to give you."))
		clear_recorded_pending(mind)
		qdel(src)
		return
	choosing = TRUE
	var/choice_type = run_reward_menu(user, live_candidates)
	choosing = FALSE
	if(!choice_type || !menu_check(user))
		return
	claim(user, mind, choice_type)

/// Radial pick + confirm loop. Returns the chosen boon typepath, or null if the claimant backed out.
/datum/action/vestige_reward/proc/run_reward_menu(mob/living/user, list/live_candidates)
	var/list/options = list()
	var/list/by_name = list()
	for(var/datum/vestige_boon/boon_type as anything in live_candidates)
		var/boon_name = initial(boon_type.name)
		options[boon_name] = vestige_boon_radial_image(boon_type)
		by_name[boon_name] = boon_type
	while(TRUE)
		var/choice = show_radial_menu(user, user, options, custom_check = CALLBACK(src, PROC_REF(menu_check), user), tooltips = TRUE)
		if(!choice || !menu_check(user))
			return null
		var/datum/vestige_boon/chosen = by_name[choice]
		var/pitch = initial(chosen.desc) || "It doesn't elaborate."
		var/confirm = tgui_alert(user, pitch, "[patron_name] offers: [choice]", list("Take it", "Reconsider"))
		if(confirm == "Take it")
			return menu_check(user) ? chosen : null
		// A single offer would just autopick itself again. Let go and let them re-click the button
		if(length(options) < 2)
			return null

/// Pays out the chosen boon and settles the debt
/datum/action/vestige_reward/proc/claim(mob/living/user, datum/mind/mind, datum/vestige_boon/choice_type)
	if(QDELETED(src) || paid || mind != target || user != owner || !menu_check(user))
		return
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(record && !(choice_type in record.pending_candidates))
		return
	if(!(choice_type in get_eligible_vestige_boons(mind, candidates)))
		return
	paid = TRUE
	// Settle before granting: grants can invoke callbacks, and an old body's
	// open menu must never turn one completed trial into two different boons.
	clear_recorded_pending(mind)
	var/datum/vestige_boon/boon = new choice_type()
	boon.grant(user, mind)
	LAZYADD(mind.vestige_boons, choice_type)
	qdel(boon)
	// Write the grant through to the soul's ledger and mark the debt settled
	record = get_vestige_record(mind, create = TRUE)
	if(record)
		record.boons |= choice_type
	clear_recorded_pending(mind)
	playsound(user, 'sound/effects/magic/curse.ogg', 50, TRUE)
	to_chat(user, span_bolddanger("[patron_name] sounds satisfied. \"Paid in full.\""))
	qdel(src)

/// Settles the pending entry on the soul's ledger, NOT called from Destroy, which
/// also runs on death cleanup, where the record must keep the debt for restoration
/datum/action/vestige_reward/proc/clear_recorded_pending(datum/mind/mind)
	var/datum/vestige_record/record = get_vestige_record(mind)
	if(!record)
		return
	record.pending_candidates = null
	record.pending_patron_name = null
