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
		context[SCREENTIP_CONTEXT_LMB] = "Connect Account"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/computer/bank_machine/examine(mob/user)
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
	var/list/data = ..()

	if(synced_bank_account)
		data["station_name"] = synced_bank_account.account_holder

	return data

/obj/machinery/computer/bank_machine/attackby(obj/item/weapon, mob/user, params)
	if(isidcard(weapon))
		var/obj/item/card/id/id_weapon = weapon
		synced_bank_account = id_weapon.registered_account
		playsound(user, 'sound/machines/ding.ogg', 50, TRUE)
		balloon_alert_to_viewers(user, "account updated")

	if(!synced_bank_account && (istype(weapon, /obj/item/stack/spacecash) || istype(weapon, /obj/item/holochip)))
		return //don't let them continue the attack chain because they'll waste money on a machine with no account

	return ..()

// A pirate siphon on the ship's accounts locks the vault. Emptying the balance into a
// holochip is the fastest way to make a robbery come up empty, so it is the one path
// that has to refuse loudly rather than fail somewhere down in the economy code.
/obj/machinery/computer/bank_machine/ui_act(action, params, datum/tgui/ui)
	if(action == "siphon" && synced_bank_account?.is_siphon_locked())
		say("Error: hostile intrusion detected on the account. Withdrawals are locked out.")
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
		return TRUE
	return ..()

// A withdrawal already running when the pirate's tap lands gets cut off. Upstream's
// process() would stop it anyway once has_money() starts refusing, but it announces
// "depleted", which is a lie when the balance is untouched and merely frozen. Credits
// already pulled stay pulled - end_siphon() drops them as a holochip.
/obj/machinery/computer/bank_machine/process(seconds_per_tick)
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
	build_path = /obj/item/circuitboard/computer/bank_machine
	category = list(
		RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_CARGO
	)
	departmental_flags = DEPARTMENT_BITFLAG_CARGO
