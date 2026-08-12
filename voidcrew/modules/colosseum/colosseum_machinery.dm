/**
 * # Colosseum service machinery
 *
 * The concourse signup console, the spoils vault, the venue doors, the ETA
 * boards and the arena camera net. Everything here is an indestructible venue
 * fixture (matching the building's indestructible fiction) and everything
 * tolerates deferred linking: the site wires `site` vars in link_interior(),
 * and every interaction re-checks them (or falls back to GLOB.colosseum_site.
 * Safe, the venue is one-per-round).
 */

// ===== VENUE DOORS =====

/**
 * The venue's interior airlocks. Same hardening recipe as the trader-outpost
 * sanctuary doors: no damage, no hacking, no emag, the fiction says the
 * building has shrugged off worse than your weapons.
 */
/obj/machinery/door/airlock/sandstone/colosseum
	name = "colosseum door"
	desc = "A sandstone-faced door hung on mechanisms far older and far tougher than it looks."
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	damage_deflection = 100
	explosion_block = 3
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	security_level = 6
	normal_integrity = 1000

/obj/machinery/door/airlock/sandstone/colosseum/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "the mechanism shrugs it off!")
	return FALSE

/// The referee box door. Access comes from the mapped access helper.
/obj/machinery/door/airlock/sandstone/colosseum/admin
	name = "referee box door"
	desc = "The Master of Games' box. The plaque reads: 'If you can read this, you are not invited.'"

/**
 * The spoils chamber door. While a claim window runs it answers only to the
 * match's winners; the rest of the time it opens for anyone, matching the
 * vault's public-after-the-window behavior.
 */
/obj/machinery/door/airlock/sandstone/colosseum/vault
	name = "spoils chamber door"
	desc = "A heavy sandstone door onto the trophy chamber. While a claim window is running it only opens for the winners."

/obj/machinery/door/airlock/sandstone/colosseum/vault/allowed(mob/M)
	var/datum/colosseum_controller/controller = GLOB.colosseum_site?.controller
	if(controller?.claim_window_active())
		return M.mind && controller.winner_minds[M.mind]
	return ..()

/// Glass variant of the hardened venue door (concourse side rooms).
/obj/machinery/door/airlock/sandstone/glass/colosseum
	name = "colosseum door"
	desc = "A glazed sandstone-faced door hung on mechanisms far older and far tougher than it looks."
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	damage_deflection = 100
	explosion_block = 3
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	security_level = 6
	normal_integrity = 1000

/obj/machinery/door/airlock/sandstone/glass/colosseum/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "the mechanism shrugs it off!")
	return FALSE

// ===== ETA BOARDS =====

/// "M:SS" countdown text for the ETA boards (deciseconds in, clamped at zero).
/proc/colosseum_timer_text(deciseconds)
	var/seconds = max(0, round(deciseconds / 10))
	return "[round(seconds / 60)]:[add_leading(num2text(seconds % 60), 2, "0")]"

/**
 * Venue ETA board: shows the match loop's current phase and, above all, when
 * the fighting starts. Driven two ways, a tick on SSmachines while any
 * countdown is running, and site.update_status_displays() kicks on every
 * state flip so the boards never show a stale phase.
 */
/obj/machinery/status_display/colosseum
	name = "games board"
	desc = "An ancient annunciator board, retrofitted a dozen times over. It counts down to the next fight."
	current_mode = SD_MESSAGE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The venue this board serves (wired by link_interior; GLOB fallback)
	var/obj/structure/overmap/colosseum/site

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/status_display/colosseum, 32)

/obj/machinery/status_display/colosseum/Initialize(mapload)
	. = ..()
	update()

/obj/machinery/status_display/colosseum/Destroy()
	if(site)
		site.status_displays -= src
		site = null
	return ..()

// Venue fixture: no tool does anything, not unboltable, not deconstructable.
/obj/machinery/status_display/colosseum/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour)
		balloon_alert(user, "set into the stone!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/status_display/colosseum/process()
	var/datum/colosseum_controller/controller = (site || GLOB.colosseum_site)?.controller
	if(!controller)
		set_messages("- GAMES -", "DORMANT")
		return PROCESS_KILL
	switch(controller.state)
		if(COLOSSEUM_STATE_IDLE)
			// The claim window (5 min) outlives the arena reset (15 s), keep
			// the winners' countdown up until it lapses.
			if(controller.claim_window_active())
				set_messages("- SPOILS -", "CLAIM [colosseum_timer_text(controller.claim_until - world.time)]")
				return
			if(world.time < controller.next_signup_at)
				set_messages("- GAMES -", "NEXT [colosseum_timer_text(controller.next_signup_at - world.time)]")
				return
			set_messages("- GAMES -", "SIGNUP AT THE CONCOURSE")
			return PROCESS_KILL
		if(COLOSSEUM_STATE_SIGNUP)
			set_messages("SIGNUP [colosseum_timer_text(controller.signup_closes_at - world.time)]", "FIGHT [colosseum_timer_text(controller.time_to_gates())]")
		if(COLOSSEUM_STATE_SEATING)
			set_messages("SEATING", "FIGHT [colosseum_timer_text(controller.time_to_gates())]")
		if(COLOSSEUM_STATE_LIVE)
			var/clock = controller.match_timer ? timeleft(controller.match_timer) : 0
			set_messages("LIVE [colosseum_timer_text(clock)]", uppertext(controller.mode?.name || "match"))
		if(COLOSSEUM_STATE_RESOLVED, COLOSSEUM_STATE_RESET)
			if(controller.claim_window_active())
				set_messages("- SPOILS -", "CLAIM [colosseum_timer_text(controller.claim_until - world.time)]")
			else
				set_messages("- ARENA -", "RESETTING")

// ===== ARENA CAMERAS =====

/**
 * Arena camera: fixed network so the observation consoles list exactly the
 * fight and nothing else. Long view range. The arena is 28 tiles across and
 * the cameras hang on its perimeter. The voidcrew camera edit auto-names
 * these per-area ("Colosseum Arena #1", ...) and leaves the network alone
 * because the venue isn't a shuttle.
 */
/obj/machinery/camera/colosseum
	network = list(COLOSSEUM_CAMERA_NETWORK)
	view_range = 14
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/camera/colosseum, 0)

/obj/machinery/camera/colosseum/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF | EMP_PROTECT_WIRES)

// No panel, no rewiring, no upgrades: a contestant with a screwdriver must
// not be able to blind the stands (reset_arena can't rebuild machinery).
/obj/machinery/camera/colosseum/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour)
		balloon_alert(user, "sealed against tampering!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/// Spectator-side observation console: watch the whole fight from the stands.
/obj/machinery/computer/security/colosseum
	name = "arena observation console"
	desc = "A spectator's window onto the sand. Every angle of the arena, none of the shrapnel."
	icon_screen = "cameras"
	network = list(COLOSSEUM_CAMERA_NETWORK)
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF

/obj/machinery/computer/security/colosseum/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour)
		balloon_alert(user, "set into the stone!")
		return ITEM_INTERACT_BLOCKING
	return ..()

// ===== CHAMPION'S CASE =====

/// Champion's case storage: same ship-parts-only rule as the standard
/// extraction case, sized for a whole prize pool.
/datum/storage/briefcase/extraction/tournament
	max_slots = 16
	max_total_storage = 48

/**
 * The tournament prize case. Awarded through the spoils vault (one per
 * winner, the prize parts dealt between them) and extracted ALONGSIDE a
 * standard extraction case rather than competing with it for the
 * one-case-per-player rule, see extract_ship_parts_from_player().
 */
/obj/item/storage/briefcase/secure/extraction/tournament
	name = "champion's extraction case"
	desc = "A gilded extraction case stamped with the Grand Colosseum's laurels. It extracts on top of your normal extraction case, not instead of it."
	icon = 'voidcrew/modules/colosseum/icons/colosseum.dmi'
	icon_state = "tournament_case"
	// The lockable_storage component rewrites icon_state to
	// "[base_icon_state]_locked"/"_broken" on every update, so this has to
	// track our own icon file - inheriting "secure" renders us invisible.
	base_icon_state = "tournament_case"
	inhand_icon_state = "tournament_case"
	lefthand_file = 'voidcrew/modules/colosseum/icons/colosseum_lefthand.dmi'
	righthand_file = 'voidcrew/modules/colosseum/icons/colosseum_righthand.dmi'
	storage_type = /datum/storage/briefcase/extraction/tournament

/obj/item/storage/briefcase/secure/extraction/tournament/examine(mob/user)
	. = ..()
	. += span_boldnotice("Colosseum plunder: this case extracts in addition to your standard extraction case.")
	var/part_count = 0
	for(var/obj/item/ship_parts/part in contents)
		part_count++
	. += span_notice("Currently holding [part_count] ship part\s.")

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

// Computers deconstruct into frames via screwdriver regardless of
// resistance_flags; venue fixtures don't.
/obj/machinery/computer/colosseum_signup/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour)
		balloon_alert(user, "set into the stone!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/// Refreshes any open interaction feedback after state flips. (The console is
/// alert-driven, not TGUI, so this is just a hook kept symmetric with the vault.)
/obj/machinery/computer/colosseum_signup/proc/update_static_ui()
	return

/obj/machinery/computer/colosseum_signup/examine(mob/user)
	. = ..()
	var/datum/colosseum_controller/controller = site?.controller
	if(!controller)
		. += span_warning("The ledger is blank. The venue is dormant.")
		return
	switch(controller.state)
		if(COLOSSEUM_STATE_IDLE)
			. += span_notice("Registration is closed. [controller.can_open_signup() ? "Anyone may petition the Master of Games to open it." : "The wardens are still preparing the venue."]")
		if(COLOSSEUM_STATE_SIGNUP)
			. += span_boldnotice("Registration is OPEN. [DisplayTimeText(controller.signup_closes_at - world.time)] remaining.")
		if(COLOSSEUM_STATE_SEATING)
			. += span_notice("The roster is locked. Contestants are being seated.")
		if(COLOSSEUM_STATE_LIVE)
			. += span_notice("A [controller.mode?.name || "match"] is in progress.")
		if(COLOSSEUM_STATE_RESOLVED, COLOSSEUM_STATE_RESET)
			. += span_notice("The match is over; the wardens are raking the sand.")
	if(length(controller.roster))
		var/list/lines = list("The roster reads:")
		for(var/datum/colosseum_contestant/entry as anything in controller.roster)
			lines += "- [entry.display_name], of [entry.ship_name][entry.eliminated ? " (eliminated)" : ""]"
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
				balloon_alert(user, "dead can only spectate!")
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
	desc = "An armored prize vault. Everything left on the sand ends up in here, and the winners get first pick."
	icon = 'voidcrew/modules/colosseum/icons/colosseum.dmi'
	icon_state = "colosseum_vault"
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
	// Don't delete the loot with the vault, spill it out instead
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
	if(controller?.claim_window_active())
		return user.mind && controller.winner_minds[user.mind]
	return TRUE

/obj/machinery/colosseum_vault/examine(mob/user)
	. = ..()
	var/datum/colosseum_controller/controller = site?.controller
	if(controller?.claim_window_active())
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
	var/claim_active = controller?.claim_window_active()
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
