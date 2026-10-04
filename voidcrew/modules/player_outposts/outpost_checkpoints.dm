/obj/structure/overmap/dynamic/player_outpost
	var/list/datum/ship_checkpoint/checkpoints = list()

/obj/structure/overmap/ship
	var/datum/weakref/checkpoint_ref
	/// Prevent claiming the old hull while its paid replacement is loading.
	var/checkpoint_rebuilding = FALSE
	var/retired_by_checkpoint = FALSE

/// Every ship bay map has a shipyard console; the board replaces a lost one.
/obj/item/circuitboard/computer/ship_checkpoint
	name = "Shipyard Console (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/ship_checkpoint

/// The outpost shipyard: new ships built to order, and ship checkpoints. The type path predates
/// the shop and is kept so maps and boards stay valid.
/obj/machinery/computer/ship_checkpoint
	name = "shipyard console"
	desc = "Orders new ships for the outpost ship bay and keeps checkpoints of ships docked there, for rebuilding one that is lost."
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

/// One checkpoint per captain at this outpost, even when updating from a new ship.
/obj/structure/overmap/dynamic/player_outpost/proc/checkpoint_for(mob/user)
	return checkpoint_for_ckey(user?.ckey)

/obj/structure/overmap/dynamic/player_outpost/proc/checkpoint_for_ckey(owner_ckey)
	if(!owner_ckey)
		return null
	for(var/datum/ship_checkpoint/snapshot as anything in checkpoints)
		if(snapshot.captain_ckey == owner_ckey)
			return snapshot

/datum/ship_checkpoint_ui
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	var/datum/weakref/host_ref
	var/datum/weakref/user_ref
	var/turf/host_turf
	var/datum/ship_checkpoint/quote
	var/datum/weakref/quoted_bay
	var/datum/weakref/quoted_account
	var/datum/weakref/quoted_checkpoint
	var/quoted_owner
	var/quoted_fee
	var/error
	var/notice
	var/working = FALSE

/datum/ship_checkpoint_ui/New(obj/structure/overmap/dynamic/player_outpost/home, obj/machinery/computer/host, mob/user)
	outpost = home
	host_ref = WEAKREF(host)
	user_ref = WEAKREF(user)
	host_turf = get_turf(host)
	RegisterSignal(home, COMSIG_QDELETING, PROC_REF(on_outpost_deleted))

/datum/ship_checkpoint_ui/Destroy()
	SStgui.close_uis(src)
	var/obj/machinery/computer/host = host_ref?.resolve()
	if(istype(host, /obj/machinery/computer/ship_checkpoint))
		var/obj/machinery/computer/ship_checkpoint/console = host
		console.checkpoint_panels -= src
	if(outpost)
		UnregisterSignal(outpost, COMSIG_QDELETING)
	outpost = null
	QDEL_NULL(quote)
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

/// Only a physically present, captain-owned bay can supply a snapshot or payment.
/datum/ship_checkpoint_ui/proc/save_denial(mob/living/user, datum/outpost_berth/ship_bay/bay)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Checkpoint console unavailable."
	if(QDELETED(bay) || bay.outpost != outpost || !(bay in outpost.bay_berths) || !bay.is_ship_present())
		return "Dock your ship in a ship bay first."
	var/obj/structure/overmap/ship/ship = bay.ship
	if(!ship.is_ship_captain(user) || ship.abandoned || ship.retired_by_checkpoint)
		return "Only the ship's current captain can save it."
	if(ship.checkpoint_rebuilding)
		return "Recovery is already in progress."
	var/datum/ship_checkpoint/previous = outpost.checkpoint_for(user)
	if(previous?.busy)
		return "Your checkpoint is being rebuilt."
	var/datum/ship_checkpoint/ship_checkpoint = ship.checkpoint_ref?.resolve()
	if(ship_checkpoint && ship_checkpoint != previous)
		return "This ship already has another checkpoint."
	if(length(outpost.checkpoints) >= OUTPOST_MAX_CHECKPOINTS && !previous)
		return "This outpost's checkpoint storage is full."
	if(QDELETED(ship.ship_account))
		return "The ship bank account is unavailable."
	return null

/datum/ship_checkpoint_ui/proc/prepare_save(mob/living/user, datum/outpost_berth/ship_bay/bay)
	error = save_denial(user, bay)
	if(error || working)
		return FALSE
	working = TRUE
	notice = null
	QDEL_NULL(quote)
	var/datum/ship_checkpoint/snapshot = new
	error = snapshot.capture(bay.ship, user)
	if(!error)
		error = save_denial(user, bay)
	if(error || QDELETED(src))
		qdel(snapshot)
		working = FALSE
		return FALSE
	quote = snapshot
	quoted_bay = WEAKREF(bay)
	quoted_account = WEAKREF(bay.ship.ship_account)
	var/datum/ship_checkpoint/previous = outpost.checkpoint_for(user)
	quoted_checkpoint = previous ? WEAKREF(previous) : null
	quoted_owner = outpost.founder_ckey
	quoted_fee = previous ? OUTPOST_CHECKPOINT_UPDATE_COST : OUTPOST_CHECKPOINT_SAVE_COST
	working = FALSE
	return TRUE

/// Shared by the invoice and transaction; rechecked after captain confirmation.
/datum/ship_checkpoint_ui/proc/quote_denial(mob/living/user)
	if(QDELETED(quote))
		return "Prepare a quote first."
	var/datum/outpost_berth/ship_bay/bay = quoted_bay?.resolve()
	var/denial = save_denial(user, bay)
	if(denial)
		return denial
	var/obj/structure/overmap/ship/ship = quote.source_ship.resolve()
	if(bay.ship != ship || quote.captain_ckey != user.ckey)
		return "The docked ship changed. Try again."
	if(quoted_owner != outpost.founder_ckey || quoted_account?.resolve() != ship.ship_account)
		return "The payment account changed. Try again."
	var/datum/ship_checkpoint/previous = outpost.checkpoint_for(user)
	if(quoted_checkpoint != (previous ? WEAKREF(previous) : null))
		return "Your checkpoint changed. Try again."
	if(!ship.ship_account.has_money(quoted_fee))
		return "The ship account has insufficient credits."
	return null

/datum/ship_checkpoint_ui/proc/confirm_save(mob/user, prompt_text)
	return tgui_alert(user, prompt_text, "Ship checkpoint", list("Confirm", "Cancel")) == "Confirm"

/datum/ship_checkpoint_ui/proc/save_quote(mob/living/user)
	if(working || !quote)
		return FALSE
	error = quote_denial(user)
	if(error)
		return FALSE
	var/datum/ship_checkpoint/snapshot = quote
	working = TRUE
	var/accepted = confirm_save(user, "[quoted_checkpoint ? "Update" : "Save"] your checkpoint for [quoted_fee] credits from the ship account? This service fee is spent, not deposited into the outpost treasury. Save [snapshot.ship_name] as your checkpoint[quoted_checkpoint ? ", replacing the previous one" : ""]. One prepaid rebuild includes constructible machinery and fitted upgrades, charged batteries and engine fuel. Cargo, ammunition, stored materials and other supplies are excluded.")
	if(QDELETED(src))
		return FALSE
	working = FALSE
	if(!accepted || quote != snapshot || QDELETED(snapshot))
		return FALSE
	error = quote_denial(user)
	if(error)
		return FALSE
	var/obj/structure/overmap/ship/ship = snapshot.source_ship.resolve()
	// No yields between the final checks, payment and replacing the checkpoint.
	if(!ship.ship_account.adjust_money(-quoted_fee, "Ship checkpoint at [outpost.name], approved by [user.ckey]"))
		error = "The ship account payment was declined."
		return FALSE
	var/datum/ship_checkpoint/previous = outpost.checkpoint_for(user)
	if(previous)
		qdel(previous)
	snapshot.outpost = outpost
	outpost.checkpoints += snapshot
	ship.checkpoint_ref = WEAKREF(snapshot)
	quote = null
	notice = "Checkpoint saved for [snapshot.ship_name]. One prepaid rebuild available."
	log_game("[key_name(user)] saved a checkpoint for [ship.name] at [outpost.name] for [quoted_fee] credits.")
	return TRUE

/datum/ship_checkpoint_ui/ui_data(mob/user)
	var/list/bays = list()
	for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
		if(!bay?.ship?.is_ship_captain(user))
			continue
		bays += list(list("ref" = REF(bay), "name" = bay.ship.name, "number" = bay.bay_number, "denial" = save_denial(user, bay), "balance" = bay.ship.ship_account?.account_balance || 0))
	var/list/blueprints = list()
	for(var/datum/ship_checkpoint/snapshot as anything in outpost.checkpoints)
		if(snapshot.captain_ckey != user.ckey)
			continue
		blueprints += list(list("ref" = REF(snapshot), "name" = snapshot.ship_name, "width" = snapshot.width, "height" = snapshot.height, "denial" = rebuild_denial(user, snapshot)))
	var/list/rebuilds = list()
	for(var/datum/checkpoint_construction/job as anything in outpost.checkpoint_jobs)
		if(job.captain_ckey == user.ckey)
			rebuilds += list(job.rebuild_ui_data())
	return list(
		"outpost" = outpost.name,
		"bays" = bays,
		"blueprints" = blueprints,
		"rebuilds" = rebuilds,
		"working" = working,
		"error" = error,
		"notice" = notice,
		"save_cost" = OUTPOST_CHECKPOINT_SAVE_COST,
		"update_cost" = OUTPOST_CHECKPOINT_UPDATE_COST,
		"has_checkpoint" = !!outpost.checkpoint_for(user),
		"shop" = shop_data(user),
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
		if("save", "update")
			var/has_checkpoint = !!outpost.checkpoint_for(user)
			if((action == "update") != has_checkpoint)
				error = "Your checkpoint changed. Please try again."
				return TRUE
			var/datum/outpost_berth/ship_bay/bay = locate(params["ref"]) in outpost.bay_berths
			if(prepare_save(user, bay))
				save_quote(user)
		if("rebuild")
			var/datum/ship_checkpoint/snapshot = locate(params["ref"]) in outpost.checkpoints
			rebuild(user, snapshot)
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
	display_name = "Ship Checkpoints"
	description = "Save and recover ships at outposts."
	starting_node = TRUE
	design_ids = list("ship_checkpoint")
