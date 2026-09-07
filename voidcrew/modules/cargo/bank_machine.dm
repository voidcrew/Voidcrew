/obj/machinery/computer/bank_machine
	circuit = /obj/item/circuitboard/computer/bank_machine

/obj/machinery/computer/bank_machine/Initialize(mapload)
	. = ..()
	//clear the account immediately
	synced_bank_account = null
	register_context()
	connect_to_shuttle(mapload, SSshuttle.get_containing_shuttle(src))

/obj/machinery/computer/bank_machine/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(istype(held_item, /obj/item/card/id))
		context[SCREENTIP_CONTEXT_LMB] = get_outpost_from_atom(src) ? "Treasury transfer instructions" : "Connect Account"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/computer/bank_machine/examine(mob/user)
	resolve_outpost_bank()
	. = ..()
	if(synced_bank_account)
		. += span_notice("It is connected to [synced_bank_account.account_holder]'s account.")
	else
		. += span_notice("It is not connected to an account. Use an ID to connect it")

/obj/machinery/computer/bank_machine/multitool_act(mob/living/user, obj/item/multitool/tool)
	user.balloon_alert(user, "buffer saved in storage")
	tool.buffer = src
	return TRUE

/obj/machinery/computer/bank_machine/ui_data(mob/user)
	var/obj/structure/overmap/dynamic/player_outpost/site = resolve_outpost_bank()
	var/list/data = ..()

	if(synced_bank_account)
		data["station_name"] = synced_bank_account.account_holder
	data["is_outpost"] = !!site
	data["user_account"] = null
	data["can_withdraw"] = FALSE
	data["history"] = null
	if(site)
		var/mob/living/account_user = isliving(user) ? user : null
		var/datum/bank_account/user_account = account_user?.get_idcard(TRUE)?.registered_account
		data["user_account"] = user_account?.account_holder
		data["can_withdraw"] = site.can_spend(user)
		data["history"] = synced_bank_account.transaction_history

	return data

/obj/machinery/computer/bank_machine/attackby(obj/item/weapon, mob/user, params)
	var/obj/structure/overmap/dynamic/player_outpost/site = resolve_outpost_bank()
	if(site && isidcard(weapon))
		to_chat(user, span_notice("This terminal serves [site.treasury.account_holder]. Keep your ID in hand and use the terminal interface for account transfers."))
		return
	if(isidcard(weapon))
		var/obj/item/card/id/id_weapon = weapon
		synced_bank_account = id_weapon.registered_account
		playsound(user, 'sound/machines/ding.ogg', 50, TRUE)
		balloon_alert_to_viewers(user, "account updated")

	if(!synced_bank_account && (istype(weapon, /obj/item/stack/spacecash) || istype(weapon, /obj/item/holochip) || istype(weapon, /obj/item/coin)))
		return //don't let them continue the attack chain because they'll waste money on a machine with no account

	var/previous_balance = site?.treasury.account_balance
	. = ..()
	if(site && site.treasury.account_balance > previous_balance)
		site.treasury.add_log_to_history(0, "Physical deposit of [site.treasury.account_balance - previous_balance] cr from [user.ckey] to [site.treasury.account_holder]")

// A pirate siphon on the ship's accounts locks the vault. Emptying the balance into a
// holochip is the fastest way to make a robbery come up empty, so it is the one path
// that has to refuse loudly rather than fail somewhere down in the economy code.
/obj/machinery/computer/bank_machine/ui_act(action, params, datum/tgui/ui)
	var/obj/structure/overmap/dynamic/player_outpost/site = resolve_outpost_bank()
	if(site && (action in list("deposit", "withdraw")))
		if(!ui || ui.user != usr || ui.status != UI_INTERACTIVE)
			return TRUE
		var/amount = isnum(params["amount"]) ? params["amount"] : text2num(params["amount"])
		var/success = transfer_outpost_account(ui?.user, action, amount)
		if(!success)
			say("Transfer refused: check your ID account, authority, whole credit amount and available funds.")
		return TRUE
	if(site && action == "siphon")
		say("Use the withdrawal control for an authorized transfer to your ID account.")
		return TRUE
	if(action == "siphon" && synced_bank_account?.is_siphon_locked())
		say("Error: hostile intrusion detected on the account. Withdrawals are locked out.")
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
		return TRUE
	return ..()

/obj/machinery/computer/bank_machine/proc/transfer_outpost_account(mob/living/user, action, amount)
	var/obj/structure/overmap/dynamic/player_outpost/site = resolve_outpost_bank()
	if(!site || !istype(user) || QDELETED(user) || QDELETED(src) || !user.can_perform_action(src) \
		|| (machine_stat & (BROKEN | NOPOWER)) || !(action in list("deposit", "withdraw")))
		return FALSE
	return action == "deposit" ? site.deposit_from(user, amount) : site.withdraw_to(user, amount)

// A withdrawal already running when the pirate's tap lands gets cut off. Upstream's
// process() would stop it anyway once has_money() starts refusing, but it announces
// "depleted", which is a lie when the balance is untouched and merely frozen. Credits
// already pulled stay pulled - end_siphon() drops them as a holochip.
/obj/machinery/computer/bank_machine/process(seconds_per_tick)
	if(siphoning && resolve_outpost_bank())
		end_siphon()
		return
	if(siphoning && synced_bank_account?.is_siphon_locked())
		say("Hostile intrusion detected on the account. Halting withdrawal.")
		end_siphon()
		return
	return ..()

/obj/machinery/computer/bank_machine/connect_to_shuttle(mapload, obj/docking_port/mobile/voidcrew/port, obj/docking_port/stationary/dock)
	. = ..()
	if(!istype(port))
		return
	if(port.current_ship?.ship_account)
		synced_bank_account = port.current_ship.ship_account
		return
	// At roundstart this hook fires inside action_load(), before the subsystem
	// assigns port.current_ship - finish the link when the ship load completes.
	RegisterSignal(port, COMSIG_VOIDCREW_SHIP_LOADED, PROC_REF(on_ship_loaded), override = TRUE)

/obj/machinery/computer/bank_machine/proc/on_ship_loaded(obj/docking_port/mobile/voidcrew/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_SHIP_LOADED)
	if(!synced_bank_account && source.current_ship?.ship_account)
		synced_bank_account = source.current_ship.ship_account

/**
 * CIRCUIT BOARD
 */
/obj/item/circuitboard/computer/bank_machine
	name = "Bank Machine"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/computer/bank_machine

/datum/design/board/bankmachine
	name = "Bank Machine Console Board"
	desc = "Allows for the construction of a Bank Machine circuit board to interact with your Ship's budget."
	id = "bankmachine"
	build_path = /obj/item/circuitboard/computer/bank_machine
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO
