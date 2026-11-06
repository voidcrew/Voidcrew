/**
 * # Warrant console
 *
 * A mission board that takes no contracts. It shows what the plain board's Wanted section shows (the
 * criminals visible to its ship) plus every open warrant on a player convict or pirate, which live in
 * GLOB.background_warrants and nowhere else, so no other board lists them. NPC pirate-ship bounties and
 * player-posted bounties are unchanged. Anyone at the console may use it: a looted console works for
 * any crew, and the pad and the warrant's own checks decide a turn-in.
 *
 * No /datum/design builds its board and nothing converts a plain board into it.
 */
/obj/machinery/computer/mission_board/bounty
	name = "warrant console"
	desc = "A bounty office terminal. Warrants, wanted posters and contracts on outlaw crews."
	circuit = /obj/item/circuitboard/computer/mission_board/bounty

/obj/item/circuitboard/computer/mission_board/bounty
	name = "Warrant Console"
	greyscale_colors = CIRCUIT_COLOR_SECURITY
	build_path = /obj/machinery/computer/mission_board/bounty

/// Every open warrant
/obj/machinery/computer/mission_board/bounty/proc/open_warrants()
	var/list/open = list()
	for(var/datum/criminal_bounty/warrant in GLOB.background_warrants)
		if(warrant.is_open())
			open += warrant
	return open

/// Every posting this console lists for `ship`: the plain board's, then the warrants
/obj/machinery/computer/mission_board/bounty/proc/listed_postings(obj/structure/overmap/ship/ship)
	var/list/postings = list()
	if(ship)
		for(var/datum/criminal_bounty/posting in GLOB.criminal_bounties)
			if(posting.is_open() && posting.board_visible_to(ship))
				postings += posting
	postings += open_warrants()
	return postings

/obj/machinery/computer/mission_board/bounty/ui_static_data(mob/user)
	var/list/data = ..()
	data["board_flavour"] = "bounty"
	return data

/obj/machinery/computer/mission_board/bounty/ui_data(mob/user)
	var/list/data = ..()
	if(!data["has_ship"])
		return data
	data["available_missions"] = list()
	data["active_missions"] = list()
	return data

/obj/machinery/computer/mission_board/bounty/ui_act(action, params, datum/tgui/ui)
	// No contracts here; the window hides them, and a hand-made request gets nothing
	var/static/list/contract_actions = list("accept", "turn_in", "refresh")
	if(action in contract_actions)
		return TRUE
	return ..()

// ===== THE WANTED SECTION (bounty_board.dm's procs, with the warrants added) =====
// The signature, mugshot and pending procs are whole rewrites over listed_postings(), not ..() plus extra:
// the parent's pending check forgets every record it didn't list itself, so a warrant's would never settle.

/obj/machinery/computer/mission_board/bounty/board_static_signature(obj/structure/overmap/ship/ship)
	if(!ship)
		return ""
	var/list/parts = list()
	for(var/datum/criminal_bounty/posting as anything in listed_postings(ship))
		if(posting.record)
			parts += "[posting.record.id]:[posting.static_data_serial]"
	return parts.Join(",")

/obj/machinery/computer/mission_board/bounty/board_wanted_mugshots(obj/structure/overmap/ship/ship)
	var/list/mugshots = list()
	if(!ship)
		return mugshots
	for(var/datum/criminal_bounty/posting as anything in listed_postings(ship))
		if(posting.record)
			mugshots[posting.record.id] = bounty_mugshot_asset(posting.record) || ""
	return mugshots

/obj/machinery/computer/mission_board/bounty/board_add_wanted_data(list/data, obj/structure/overmap/ship/ship, mob/user)
	. = ..()
	var/list/wanted = data["wanted"]
	for(var/datum/criminal_bounty/warrant as anything in open_warrants())
		var/list/entry = warrant.board_ui_entry(ship, linked_pad)
		entry["warrant"] = 1
		wanted += list(entry)
	return data

/obj/machinery/computer/mission_board/bounty/board_mugshots_pending(obj/structure/overmap/ship/ship)
	. = FALSE
	var/list/listed = list()
	for(var/datum/criminal_bounty/posting as anything in listed_postings(ship))
		var/datum/bounty_record/record = posting.record
		if(!record)
			continue
		listed[record.id] = TRUE
		if(record.mugshot)
			continue
		if(!board_mugshots_asked[record.id])
			board_mugshots_asked[record.id] = world.time
			bounty_queue_mugshot(record)
		if(world.time - board_mugshots_asked[record.id] < BOUNTY_BOARD_MUGSHOT_WAIT)
			. = TRUE
	// Forget postings that left the board
	for(var/id in board_mugshots_asked)
		if(!listed[id])
			board_mugshots_asked -= id

/obj/machinery/computer/mission_board/bounty/board_wanted_act(action, list/params, obj/structure/overmap/ship/ship, mob/user)
	var/datum/criminal_bounty/warrant = locate(params["ref"]) in GLOB.background_warrants
	if(!warrant)
		return ..()
	if(!warrant.is_open())
		balloon_alert(user, "bounty not available!")
		return TRUE
	switch(action)
		if("hunt_wanted")
			var/result = warrant.hunt(ship)
			if(result == TRUE)
				balloon_alert(user, "hunting!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			else
				balloon_alert(user, "[result]!")
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
		if("abandon_wanted")
			var/result = warrant.abandon(ship)
			if(result == TRUE)
				balloon_alert(user, "bounty dropped")
			else
				balloon_alert(user, "[result]!")
		if("print_warrant")
			board_print_warrant(warrant, ship, user)
		if("turn_in_wanted")
			var/result = warrant.turn_in(linked_pad, ship, user)
			if(islist(result))
				balloon_alert(user, "[result[1]] credits awarded!")
				playsound(src, 'sound/effects/cashregister.ogg', 50, TRUE)
			else
				balloon_alert(user, "[result]!")
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
	return TRUE
