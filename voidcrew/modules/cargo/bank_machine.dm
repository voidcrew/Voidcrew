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
	tool.set_buffer(src)
	return TRUE

/obj/machinery/computer/bank_machine/ui_data(mob/user)
	var/list/data = ..()

	if(synced_bank_account)
		data["station_name"] = synced_bank_account.account_holder

	return data

// Was an attackby() override. Upstream moved the money-insert branch out of attackby
// and into /obj/machinery/computer/bank_machine/item_interaction (code/game/machinery/
// bank_machine.dm), which base_item_interaction runs BEFORE attackby - and that branch
// qdel()s the inserted stack whether or not an account is linked. An attackby guard is
// unreachable now, so the refusal has to sit in the same hook, ahead of upstream's body.
//
// Duplicate override on the same type: this file is included after the upstream one
// (tgstation.dme lines 2418 then 7401), so this body is the outermost and ..() runs
// upstream's. Same trick as process() and ui_act() below.
//
// Click trace (left or right click - item_interaction_secondary defaults to this proc,
// and item_interaction runs in BOTH combat modes, so every path lands here):
//   ID card                -> account bound, SUCCESS, no bash
//   cash/holochip, no acct -> refusal, BLOCKING, cash survives (upstream never sees it)
//   cash/holochip, acct    -> ..() deposits and consumes it, as upstream
//   coin/poker chip        -> ..() (unguarded pre-upgrade too, matrix left as it was)
//   anything else          -> ..() -> NONE -> normal attack chain
/obj/machinery/computer/bank_machine/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(isidcard(tool))
		var/obj/item/card/id/id_card = tool
		synced_bank_account = id_card.registered_account
		playsound(user, 'sound/machines/ding.ogg', 50, TRUE)
		balloon_alert_to_viewers(user, "account updated")
		return ITEM_INTERACT_SUCCESS

	if(!synced_bank_account && (istype(tool, /obj/item/stack/spacecash) || istype(tool, /obj/item/holochip)))
		//don't let them continue the interaction chain because they'll waste money on a machine with no account
		balloon_alert(user, "no account linked!")
		return ITEM_INTERACT_BLOCKING

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
