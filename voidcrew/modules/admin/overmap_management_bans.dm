/**
 * # Outpost bans in Overmap Management
 *
 * One list of everyone an outpost is refusing, across every trader outpost and player outpost, so an
 * admin can lift a restriction or impose one without hunting through variables.
 *
 * Trader outposts (voidcrew/modules/trade/outpost.dm):
 * - "embargo": a ship under trade embargo. Its crew are refused service.
 * Wanted people at trader outposts are the outpost police's (voidcrew/modules/outpost_police/).
 * Player outposts (voidcrew/modules/player_outposts/):
 * - "ship_ban": a ship the owners denied docking.
 */

#define OUTPOST_BAN_MAX_MINUTES 720

/datum/overmap_management
	/// Whether the window is showing the outpost bans view, so its lists are only built while someone looks
	var/viewing_bans = FALSE

/// Every outpost that can refuse anyone
/datum/overmap_management/proc/ban_outposts()
	var/list/outposts = list()
	for(var/obj/structure/overmap/trader_outpost/trader as anything in GLOB.trader_outposts)
		if(!QDELETED(trader))
			outposts += trader
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(!QDELETED(home))
			outposts += home
	return outposts

/// Minds of player characters that can be restricted, including offline and dead bodies
/datum/overmap_management/proc/ban_candidate_minds()
	var/list/minds = list()
	for(var/mob/living/body as anything in GLOB.mob_living_list)
		var/datum/mind/body_mind = body.mind
		if(QDELETED(body) || !body_mind?.key || body_mind.current != body)
			continue
		minds |= body_mind
	return minds

/proc/outpost_ban_mind_label(datum/mind/target)
	if(!target)
		return "Unknown"
	return target.key ? "[target.name] ([target.key])" : target.name

/proc/outpost_ban_seconds_left(ends_at)
	return max(0, round((ends_at - world.time) / 10))

/datum/overmap_management/proc/ban_entry(obj/structure/overmap/outpost, kind, datum/target, name, label, seconds)
	return list(
		"id" = "[REF(outpost)]:[kind]:[REF(target)]",
		"outpost_ref" = REF(outpost),
		"outpost" = outpost.admin_name(),
		"kind" = kind,
		"target_ref" = REF(target),
		"name" = name,
		"label" = label,
		"seconds" = seconds,
	)

/datum/overmap_management/proc/ban_data()
	var/list/entries = list()
	var/list/outpost_options = list()
	for(var/obj/structure/overmap/outpost as anything in ban_outposts())
		var/obj/structure/overmap/trader_outpost/trader = astype(outpost)
		outpost_options += list(list("ref" = REF(outpost), "name" = outpost.admin_name(), "trader" = !!trader))
		if(!trader)
			var/obj/structure/overmap/dynamic/player_outpost/home = outpost
			for(var/obj/structure/overmap/ship/banned as anything in home.banned_ships.Copy())
				if(QDELETED(banned))
					home.banned_ships -= banned
					continue
				entries += list(ban_entry(home, "ship_ban", banned, banned.name, "Denied docking", null))
			continue
		// The is_* checks prune lapsed entries, so walk copies.
		for(var/obj/structure/overmap/ship/embargoed as anything in trader.embargoed_ships.Copy())
			if(QDELETED(embargoed))
				trader.embargoed_ships -= embargoed
				continue
			if(trader.is_ship_embargoed(embargoed))
				entries += list(ban_entry(trader, "embargo", embargoed, embargoed.name, "Trade embargo", outpost_ban_seconds_left(trader.embargoed_ships[embargoed])))

	var/list/ships = list()
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(!QDELETED(ship))
			ships += list(list("ref" = REF(ship), "name" = ship.name))
	var/list/people = list()
	for(var/datum/mind/candidate as anything in ban_candidate_minds())
		people += list(list("ref" = REF(candidate), "name" = outpost_ban_mind_label(candidate)))
	return list(
		"entries" = entries,
		"outposts" = outpost_options,
		"ships" = ships,
		"people" = people,
		"max_minutes" = OUTPOST_BAN_MAX_MINUTES,
	)

/// Handles every "ban_" action. Returns TRUE to update the window.
/datum/overmap_management/proc/ban_act(action, list/params, mob/user)
	if(action == "ban_view")
		viewing_bans = !!text2num("[params["open"]]")
		return TRUE
	var/obj/structure/overmap/outpost = locate(params["outpost"]) in ban_outposts()
	if(!outpost)
		error = "That outpost no longer exists."
		return TRUE
	var/obj/structure/overmap/trader_outpost/trader = astype(outpost)
	var/obj/structure/overmap/dynamic/player_outpost/home = astype(outpost)
	var/kind = params["kind"]
	switch(action)
		if("ban_lift")
			ban_lift(user, outpost, trader, home, kind, params["target"])
		if("ban_add")
			var/minutes = clamp(round(text2num("[params["minutes"]]") || 0), 1, OUTPOST_BAN_MAX_MINUTES)
			ban_add(user, outpost, trader, home, kind, params["target"], minutes)
	return TRUE

/datum/overmap_management/proc/ban_lift(mob/user, obj/structure/overmap/outpost, obj/structure/overmap/trader_outpost/trader, obj/structure/overmap/dynamic/player_outpost/home, kind, target_ref)
	var/target_name
	switch(kind)
		if("embargo")
			var/obj/structure/overmap/ship/ship = trader && (locate(target_ref) in trader.embargoed_ships)
			if(ship)
				trader.embargoed_ships -= ship
				target_name = ship.name
				ship.ship_notify("[trader.admin_name()] has lifted the trade embargo on your vessel.", "TRADE EMBARGO", SHIP_NOTIFY_NOTICE)
		if("ship_ban")
			var/obj/structure/overmap/ship/ship = home && (locate(target_ref) in home.banned_ships)
			if(ship)
				home.banned_ships -= ship
				target_name = ship.name
	if(!target_name)
		error = "That restriction has already ended."
		return
	notice = "Lifted [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()]."
	log_admin("[key_name(user)] lifted [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()].")
	message_admins("[key_name_admin(user)] lifted [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()] via Overmap Management.")

/datum/overmap_management/proc/ban_add(mob/user, obj/structure/overmap/outpost, obj/structure/overmap/trader_outpost/trader, obj/structure/overmap/dynamic/player_outpost/home, kind, target_ref, minutes)
	var/target_name
	var/duration = minutes MINUTES
	switch(kind)
		if("embargo", "ship_ban")
			var/obj/structure/overmap/ship/ship = locate(target_ref) in SSovermap.simulated_ships
			if(QDELETED(ship) || (kind == "embargo" ? !trader : !home))
				error = "Choose a ship and an outpost that can take that restriction."
				return
			target_name = ship.name
			if(kind == "embargo")
				trader.embargo_ship(ship, duration)
			else
				home.banned_ships[ship] = TRUE
				home.approved_ships -= ship
				if(ship in home.pending_dock_requests)
					home.deny_dock_request(ship)
		else
			error = "Unknown restriction."
			return
	var/length_text = kind == "ship_ban" ? "" : " for [minutes] minute[minutes == 1 ? "" : "s"]"
	notice = "Added [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()][length_text]."
	log_admin("[key_name(user)] added [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()][length_text].")
	message_admins("[key_name_admin(user)] added [ban_kind_name(kind)] on [target_name] at [outpost.admin_name()][length_text] via Overmap Management.")

/datum/overmap_management/proc/ban_kind_name(kind)
	switch(kind)
		if("embargo")
			return "a trade embargo"
		if("ship_ban")
			return "a docking ban"
	return "a restriction"

#undef OUTPOST_BAN_MAX_MINUTES
