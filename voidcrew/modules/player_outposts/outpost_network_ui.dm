/**
 * The network pad's traveller window (OutpostTeleporter.tsx). Everything is in ui_data: the list
 * is one row per linked pad (a handful), and it changes every second while a charge runs.
 * Nothing here scans mobs or crews; the derelict warning runs once, in the confirm prompt.
 */

/obj/machinery/outpost_network_pad/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "OutpostTeleporter", name)
		ui.open()

/obj/machinery/outpost_network_pad/ui_data(mob/user)
	var/list/data = list()
	var/mob/living/traveller = user
	var/online = !!network_host()
	data["padName"] = online ? site_name() : name
	data["online"] = online
	data["blocked"] = isliving(user) ? departure_denial(traveller) : "People only."
	var/mob/living/charging = charging_ref?.resolve()
	var/obj/machinery/outpost_network_pad/target = charge_target_ref?.resolve()
	if(charging && target)
		data["charging"] = list(
			"destination" = target.site_name(),
			"secondsLeft" = max(0, round((charge_ends - world.time) / (1 SECONDS), 0.1)),
			"total" = round((charge_ends - charge_started) / (1 SECONDS), 0.1),
			"mine" = charging == user,
		)
	else
		data["charging"] = null
	var/list/destinations = list()
	if(online && isliving(user))
		for(var/obj/machinery/outpost_network_pad/pad as anything in GLOB.outpost_network_pads)
			if(pad == src || !pad.network_host())
				continue
			if(is_trader && pad.is_trader)
				continue
			var/reason = pad.arrival_denial(traveller, src)
			var/obj/structure/overmap/dynamic/player_outpost/home = pad.player_host()
			// A closed outpost is not worth a row, except to its own members
			if(reason == "Closed" && !home?.is_outpost_member(user))
				continue
			destinations += list(list(
				"id" = pad.network_id,
				"name" = pad.site_name(),
				"zone" = pad.get_zone(),
				"zoneName" = outpost_network_zone_name(pad.get_zone()),
				"fee" = pad.arrival_fee(traveller),
				"available" = isnull(reason),
				"reason" = reason,
			))
	data["destinations"] = destinations
	return data

/obj/machinery/outpost_network_pad/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	if(!istype(user))
		return
	switch(action)
		if("depart")
			var/obj/machinery/outpost_network_pad/destination = network_pad_by_id(params["id"])
			var/shown_fee = params["fee"]
			if(!destination || !isnum(shown_fee))
				return TRUE
			// Someone asleep on the pad does not hold it for everyone else
			if(user.loc != get_turf(src))
				clear_idle_occupant(user)
			INVOKE_ASYNC(src, PROC_REF(confirm_trip), user, destination, shown_fee)
			return TRUE
		if("cancel")
			if(charging_ref?.resolve() == user)
				cancel_charge("You stopped the trip.")
				stamp_cancel_cooldown(user)
			return TRUE
		if("clear_pad")
			if(!clear_idle_occupant(user))
				balloon_alert(user, "nobody idle on the pad")
			return TRUE

/**
 * Asks the traveller to confirm, then starts the charge. Everything is checked again after the
 * prompt, including the fare they saw.
 */
/obj/machinery/outpost_network_pad/proc/confirm_trip(mob/living/user, obj/machinery/outpost_network_pad/destination, shown_fee)
	if(charging_ref?.resolve() == user)
		balloon_alert(user, "already charging")
		return
	var/denial = departure_denial(user) || destination.arrival_denial(user, src)
	if(!denial && destination.arrival_fee(user) != shown_fee)
		denial = "Price changed to [destination.arrival_fee(user)] cr."
	if(denial)
		balloon_alert(user, LOWER_TEXT(denial))
		to_chat(user, span_warning(denial))
		return
	var/list/lines = list("Travel to [destination.site_name()] ([outpost_network_zone_name(destination.get_zone())])?")
	if(shown_fee > 0)
		var/datum/bank_account/account = user.get_idcard(TRUE)?.registered_account
		lines += "Fare: [shown_fee] cr, from [account?.account_holder ? "[account.account_holder]'s account" : "your ID"]."
	else
		lines += "No fare."
	var/ship_warning = trader_parked_ship_warning(user, destination)
	if(ship_warning)
		lines += ship_warning
	if(tgui_alert(user, jointext(lines, "\n"), "Network pad", list("Travel", "Cancel")) != "Travel")
		return
	if(QDELETED(src) || QDELETED(destination) || QDELETED(user))
		return
	var/refusal = start_trip(user, destination, shown_fee)
	if(refusal)
		balloon_alert(user, LOWER_TEXT(refusal))
		to_chat(user, span_warning(refusal))
		return
	balloon_alert(user, "charging")

/// A warning when the traveller's ship waits at a trading outpost, where an empty hull is abandoned after a while
/obj/machinery/outpost_network_pad/proc/trader_parked_ship_warning(mob/living/user, obj/machinery/outpost_network_pad/destination)
	for(var/datum/team/voidcrew/team as anything in user.mind?.ship_teams)
		var/obj/structure/overmap/ship/ship = team.ship
		if(QDELETED(ship) || !istype(ship.docked, /obj/structure/overmap/trader_outpost))
			continue
		if(destination.host_ref?.resolve() == ship.docked)
			continue
		return "Your ship [ship.name] at [ship.docked.name] is unattended."
	return null
