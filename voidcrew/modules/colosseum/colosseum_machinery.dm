/**
 * # Colosseum service machinery
 *
 * The concourse signup console and the spoils vault. Both are indestructible
 * venue fixtures (matching the building's indestructible fiction) and both
 * tolerate deferred linking: the site wires their `site` var in
 * link_interior(), and every interaction re-checks it.
 */

// ===== SIGNUP CONSOLE =====

/obj/machinery/computer/colosseum_signup
	name = "colosseum registration console"
	desc = "The Master of Games' registration ledger. Sign here, fight there, get carried out somewhere in between."
	icon_screen = "id"
	use_power = NO_POWER_USE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The venue this console registers contestants for (wired by link_interior)
	var/obj/structure/overmap/colosseum/site

/obj/machinery/computer/colosseum_signup/Destroy()
	if(site?.signup_console == src)
		site.signup_console = null
	site = null
	return ..()

/// Refreshes any open interaction feedback after state flips. (The console is
/// alert-driven, not TGUI, so this is just a hook kept symmetric with the vault.)
/obj/machinery/computer/colosseum_signup/proc/update_static_ui()
	return

/obj/machinery/computer/colosseum_signup/examine(mob/user)
	. = ..()
	var/datum/colosseum_controller/controller = site?.controller
	if(!controller)
		. += span_warning("The ledger is blank — the venue is dormant.")
		return
	switch(controller.state)
		if(COLOSSEUM_STATE_IDLE)
			. += span_notice("Registration is closed. [controller.can_open_signup() ? "Anyone may petition the Master of Games to open it." : "The wardens are still preparing the venue."]")
		if(COLOSSEUM_STATE_SIGNUP)
			. += span_boldnotice("Registration is OPEN — [DisplayTimeText(controller.signup_closes_at - world.time)] remaining.")
		if(COLOSSEUM_STATE_SEATING)
			. += span_notice("The roster is locked. Contestants are being seated.")
		if(COLOSSEUM_STATE_LIVE)
			. += span_notice("A [controller.mode?.name || "match"] is in progress.")
		if(COLOSSEUM_STATE_RESOLVED, COLOSSEUM_STATE_RESET)
			. += span_notice("The match is over; the wardens are raking the sand.")
	if(length(controller.roster))
		var/list/lines = list("The roster reads:")
		for(var/datum/colosseum_contestant/entry as anything in controller.roster)
			lines += "— [entry.display_name], of [entry.ship_name][entry.eliminated ? " (eliminated)" : ""]"
		. += span_info(jointext(lines, "\n"))

// The machinery interact chain (attack_hand -> _try_interact -> interact) is
// the reliable hook for a non-TGUI console; attack_hand overrides get eaten.
/obj/machinery/computer/colosseum_signup/interact(mob/user)
	. = ..()
	if(isliving(user))
		interact_with_ledger(user)

/obj/machinery/computer/colosseum_signup/proc/interact_with_ledger(mob/living/user)
	var/datum/colosseum_controller/controller = site?.controller
	if(!controller)
		balloon_alert(user, "venue dormant!")
		return
	if(!isliving(user) || !user.mind)
		return
	switch(controller.state)
		if(COLOSSEUM_STATE_IDLE)
			if(!controller.can_open_signup())
				balloon_alert(user, "venue not ready yet!")
				return
			var/choice = tgui_alert(user, "Petition the Master of Games to open registration? The whole sector will hear the call.", "Open Registration", list("Open Registration", "Cancel"))
			if(choice != "Open Registration" || !site?.controller)
				return
			if(controller.open_signup(user))
				balloon_alert(user, "registration open!")
		if(COLOSSEUM_STATE_SIGNUP)
			if(user.stat == DEAD)
				balloon_alert(user, "the dead may only spectate!")
				return
			if(controller.entry_for_mind(user.mind))
				var/choice = tgui_alert(user, "You are on the roster. Withdraw?", "Withdraw", list("Withdraw", "Stay In"))
				if(choice == "Withdraw" && site?.controller)
					controller.withdraw_contestant(user)
					balloon_alert(user, "withdrawn")
				return
			var/datum/colosseum_contestant/preview = new(user.mind)
			var/affiliation = preview.ship_name
			qdel(preview)
			var/choice = tgui_alert(user, "Register for the next match as [user.real_name] of [affiliation]? Fights are to the death; the Colosseum keeps what falls on the sand.", "Register", list("Sign Up", "Cancel"))
			if(choice != "Sign Up" || !site?.controller)
				return
			if(controller.register_contestant(user))
				balloon_alert(user, "registered!")
		else
			balloon_alert(user, "registration closed!")

// ===== SPOILS VAULT =====

/**
 * End-of-match repository: the arena sweep and the prize pool both deposit
 * here. Winners claim first (COLOSSEUM_CLAIM_WINDOW), then it unlocks for
 * everyone; corpses are laid out in the infirmary once the window closes.
 */
/obj/machinery/colosseum_vault
	name = "spoils vault"
	desc = "An armored prize vault. Everything that falls on the sand ends up in here — and the winners get first pick."
	icon = 'icons/obj/structures.dmi'
	icon_state = "safe"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The venue this vault serves (wired by link_interior)
	var/obj/structure/overmap/colosseum/site

/obj/machinery/colosseum_vault/Destroy()
	if(site?.spoils_vault == src)
		site.spoils_vault = null
	site = null
	// Don't delete the loot with the vault — spill it out instead
	var/turf/spill_turf = get_turf(src)
	if(spill_turf)
		for(var/atom/movable/thing as anything in contents.Copy())
			thing.forceMove(spill_turf)
	return ..()

/// Called by the controller when a match resolves (fresh spoils inside).
/obj/machinery/colosseum_vault/proc/on_match_resolved()
	playsound(src, 'sound/machines/ping.ogg', 50, TRUE)
	update_static_ui()

/obj/machinery/colosseum_vault/proc/update_static_ui()
	SStgui.update_uis(src)

/// Whether this user may take things out right now.
/obj/machinery/colosseum_vault/proc/can_claim(mob/user)
	var/datum/colosseum_controller/controller = site?.controller
	if(!controller)
		return TRUE
	if(controller.claim_until && world.time < controller.claim_until && length(controller.winner_minds))
		return user.mind && controller.winner_minds[user.mind]
	return TRUE

/obj/machinery/colosseum_vault/examine(mob/user)
	. = ..()
	var/datum/colosseum_controller/controller = site?.controller
	if(controller?.claim_until && world.time < controller.claim_until && length(controller.winner_minds))
		. += span_boldwarning("Winners-only claim window: [DisplayTimeText(controller.claim_until - world.time)] remaining.")
	else
		. += span_notice("The vault is unlocked to the public.")
	. += span_notice("[length(contents)] item\s inside.")

/obj/machinery/colosseum_vault/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ColosseumVault", name)
		ui.open()

/obj/machinery/colosseum_vault/ui_data(mob/user)
	var/list/data = list()
	var/datum/colosseum_controller/controller = site?.controller
	var/claim_active = controller?.claim_until && world.time < controller.claim_until && length(controller.winner_minds)
	data["claim_active"] = !!claim_active
	data["claim_seconds"] = claim_active ? round((controller.claim_until - world.time) / 10) : 0
	data["is_winner"] = !!(claim_active && user.mind && controller.winner_minds[user.mind])
	data["can_claim"] = can_claim(user)
	var/list/item_list = list()
	for(var/atom/movable/thing as anything in contents)
		item_list += list(list(
			"name" = thing.name,
			"ref" = REF(thing),
			"corpse" = ismob(thing),
		))
	data["items"] = item_list
	return data

/obj/machinery/colosseum_vault/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	if(action != "claim")
		return
	var/mob/user = ui.user
	if(!can_claim(user))
		balloon_alert(user, "winners only, for now!")
		return TRUE
	var/atom/movable/thing = locate(params["ref"]) in contents
	if(!thing)
		return TRUE
	var/turf/drop_turf = get_turf(user)
	if(!drop_turf)
		return TRUE
	thing.forceMove(drop_turf)
	if(isitem(thing) && isliving(user))
		var/mob/living/living_user = user
		living_user.put_in_hands(thing)
	balloon_alert(user, "claimed [thing.name]")
	update_static_ui()
	return TRUE
