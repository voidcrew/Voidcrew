/obj/structure/overmap/ship
	/// Prevent claiming the old hull while its replacement is loading.
	var/checkpoint_rebuilding = FALSE
	var/retired_by_checkpoint = FALSE

/**
 * A new hull has replaced this one: nobody can claim or fly it from here on, and its money goes to
 * the replacement. A record whose hull is already gone goes with it.
 * Returns the balance it took, for the caller to pay to the replacement.
 */
/obj/structure/overmap/ship/proc/retire_replaced_hull()
	. = 0
	retired_by_checkpoint = TRUE
	checkpoint_rebuilding = FALSE
	var/balance = ship_account?.account_balance
	if(balance > 0 && ship_account.adjust_money(-balance, "Ship replaced"))
		. = balance
	if(QDELETED(shuttle))
		qdel(src)

/// Every ship bay map has a shipyard console; the board replaces a lost one.
/obj/item/circuitboard/computer/ship_checkpoint
	name = "Shipyard Console (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/ship_checkpoint

/// The outpost shipyard: new ships built to order, and saved ships. The type path predates
/// the shop and is kept so maps and boards stay valid.
/obj/machinery/computer/ship_checkpoint
	name = "shipyard console"
	desc = "Orders new ships for the outpost ship bay and keeps records of ships saved there."
	icon_screen = "id"
	icon_keyboard = "id_key"
	circuit = /obj/item/circuitboard/computer/ship_checkpoint
	light_color = LIGHT_COLOR_ORANGE
	var/list/datum/ship_checkpoint_ui/checkpoint_panels = list()

/obj/machinery/computer/ship_checkpoint/Destroy()
	var/list/closing_panels = checkpoint_panels
	checkpoint_panels = list()
	QDEL_LIST(closing_panels)
	return ..()

/obj/machinery/computer/ship_checkpoint/ui_interact(mob/user, datum/tgui/ui)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!home?.ship_bay_installed)
		balloon_alert(user, "no outpost ship bays")
		return
	for(var/datum/ship_checkpoint_ui/panel as anything in checkpoint_panels.Copy())
		if(panel.user_ref.resolve() != user)
			continue
		if(panel.outpost == home && panel.host_turf == get_turf(src))
			panel.ui_interact(user)
			return
		qdel(panel)
	var/datum/ship_checkpoint_ui/panel = new(home, src, user)
	checkpoint_panels += panel
	panel.ui_interact(user)

/obj/machinery/computer/ship_checkpoint/checkpoint_type()
	return null

/datum/ship_checkpoint_ui
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/datum/weakref/host_ref
	var/datum/weakref/user_ref
	var/turf/host_turf
	var/error
	var/notice
	var/working = FALSE

/datum/ship_checkpoint_ui/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/computer/host, mob/user)
	outpost = home
	host_ref = WEAKREF(host)
	user_ref = WEAKREF(user)
	host_turf = get_turf(host)
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))
	GLOB.ship_saves.refresh(user?.ckey)

/datum/ship_checkpoint_ui/Destroy()
	SStgui.close_uis(src)
	var/obj/machinery/computer/host = host_ref?.resolve()
	if(istype(host, /obj/machinery/computer/ship_checkpoint))
		var/obj/machinery/computer/ship_checkpoint/console = host
		console.checkpoint_panels -= src
	if(outpost)
		UnregisterSignal(outpost, COMSIG_QDELETING)
	outpost = null
	QDEL_NULL(cart)
	return ..()

/datum/ship_checkpoint_ui/proc/on_outpost_deleted()
	SIGNAL_HANDLER
	qdel(src)

/datum/ship_checkpoint_ui/ui_host(mob/user)
	return host_ref?.resolve()

/datum/ship_checkpoint_ui/ui_state(mob/user)
	return GLOB.always_state

/datum/ship_checkpoint_ui/ui_status(mob/user, datum/ui_state/state)
	var/obj/machinery/computer/host = host_ref?.resolve()
	if(QDELETED(outpost) || !outpost.ship_bay_installed || QDELETED(host) || get_turf(host) != host_turf || user_ref.resolve() != user || !isliving(user) || !user.ckey)
		return UI_CLOSE
	if(!istype(host, /obj/machinery/computer/ship_checkpoint) || get_outpost_from_atom(host) != outpost)
		return UI_CLOSE
	return host.ui_status(user, host.ui_state(user))

/datum/ship_checkpoint_ui/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipCheckpoint", "[outpost.name] Shipyard")
		ui.open()

/datum/ship_checkpoint_ui/ui_close(mob/user)
	qdel(src)

/datum/ship_checkpoint_ui/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/ship_previews))

/datum/ship_checkpoint_ui/ui_static_data(mob/user)
	return shop_static_data()

/// Which of the options (label -> payment) the captain picked, or null if they backed out.
/datum/ship_checkpoint_ui/proc/choose_save_payment(mob/user, prompt_text, list/options)
	var/list/buttons = list()
	for(var/label in options)
		buttons += label
	var/choice = tgui_alert(user, prompt_text, "Shipyard", buttons + "Cancel")
	return options[choice] ? choice : null

/datum/ship_checkpoint_ui/ui_data(mob/user)
	var/list/rebuilds = list()
	for(var/datum/checkpoint_construction/job as anything in outpost.checkpoint_jobs)
		if(job.captain_ckey == user.ckey)
			rebuilds += list(job.rebuild_ui_data())
	return list(
		"outpost" = outpost.name,
		"rebuilds" = rebuilds,
		"working" = working,
		"error" = error,
		"notice" = notice,
		"shop" = shop_data(user),
		"saved_ships" = saved_ships_data(user),
	)

/datum/ship_checkpoint_ui/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = usr
	if(!istype(user) || ui.user != user || ui.src_object != src || ui_status(user, state) != UI_INTERACTIVE)
		return
	if(working)
		return
	switch(action)
		if("ship_save_store")
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			save_ship(user, bay, text2num(params["slot"]), params["funds_parts"] ? text2num(params["funds_parts"]) : 0)
		if("ship_save_retrieve")
			retrieve_ship(user, text2num(params["slot"]))
		else
			shop_act(user, action, params)
	return TRUE

/datum/design/board/ship_checkpoint
	name = "Shipyard Console Board"
	desc = "Allows construction of an outpost shipyard console."
	id = "ship_checkpoint"
	build_path = /obj/item/circuitboard/computer/ship_checkpoint
	category = list(RND_CATEGORY_COMPUTER + RND_SUBCATEGORY_COMPUTER_ENGINEERING)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING

/datum/techweb_node/ship_checkpoint
	id = "ship_checkpoint"
	display_name = "Outpost Shipyards"
	description = "Order and save ships at outposts."
	starting_node = TRUE
	design_ids = list("ship_checkpoint")
