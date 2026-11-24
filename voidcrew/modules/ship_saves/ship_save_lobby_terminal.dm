// Joins ship saves to the dock terminal's SHIPYARD (voidcrew/modules/lobby_terminal/lobby_yard.dm).
// Overrides the saved-ship hooks declared in lobby_terminal/_lobby_terminal.dm. It is included after
// that file, so these bodies win.

/// Most entries a save card's carries list holds.
#define SHIP_SAVE_CARD_CARRIES 12

/**
 * TRUE when loading this save puts the player back in the crew they are in now: a save made this round
 * goes back to its own crew. The same test launch() makes after its read. Only reads caches.
 */
/datum/ship_saves/proc/restores_crew(ckey, slot, datum/mind/commander)
	SHOULD_NOT_SLEEP(TRUE)
	var/datum/weakref/crew_ref = live_crews[slot_key(ckey, slot)]
	var/datum/voidcrew_crew_record/saved_crew = crew_ref?.resolve()
	if(!saved_crew)
		return FALSE
	var/player_ckey = ckey(ckey)
	return (commander?.recover_reputation_crew() || GLOB.voidcrew_crew_roster[player_ckey]) == saved_crew

/// What a save carries, for its card: the credits aboard, the research, then each counted item of its bill.
/proc/ship_save_card_carries(list/entry)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/carries = list()
	var/funds = entry["funds"]
	if(isnum(funds) && funds > 0)
		carries += ship_save_credits_text(funds)
	var/research = entry["research"]
	if(isnum(research) && research > 0)
		carries += "Research, [research] nodes"
	for(var/list/bill_class as anything in entry["bill"])
		if(!islist(bill_class))
			continue
		for(var/list/item as anything in bill_class["items"])
			if(!islist(item) || !isnum(item["count"]) || item["count"] <= 0)
				continue
			carries += "[item["count"]] [item["name"]]"
	if(length(carries) > SHIP_SAVE_CARD_CARRIES)
		carries.Cut(SHIP_SAVE_CARD_CARRIES + 1)
	return carries

/**
 * player_ckey and commander default to the terminal's own player; the unit tests pass them, having no client.
 */
/datum/lobby_terminal/saved_ship_card(slot, player_ckey, datum/mind/commander)
	SHOULD_NOT_SLEEP(TRUE)
	if(!player_ckey)
		player_ckey = owner?.ckey
		commander = owner?.mob?.mind
	if(!player_ckey)
		return null
	var/list/row = GLOB.ship_saves.saved_row(player_ckey, slot)
	if(!row)
		return null
	var/list/entry = GLOB.ship_saves.saved_ship_entry(player_ckey, row, GLOB.ship_saves.retrieve_denial(player_ckey, slot))
	return list(
		"slot" = slot,
		"name" = entry["name"],
		"class" = entry["class"],
		"crew" = isnum(entry["crew"]) ? entry["crew"] : 0,
		"carries" = ship_save_card_carries(entry),
		"denial" = entry["denial"],
		"locked" = entry["locked"] ? 1 : 0,
		"restores" = GLOB.ship_saves.restores_crew(player_ckey, slot, commander) ? 1 : 0,
	)

/// Runs inside ui_data: only reads caches. Null until the player's saves have been read once.
/datum/lobby_terminal/saved_ships_data(player_ckey, datum/mind/commander)
	SHOULD_NOT_SLEEP(TRUE)
	if(!player_ckey)
		player_ckey = owner?.ckey
		commander = owner?.mob?.mind
	if(!player_ckey || isnull(GLOB.ship_saves.saves_for(player_ckey)))
		return null
	var/list/cards = list()
	for(var/slot in 1 to SHIP_SAVE_SLOTS)
		cards += list(saved_ship_card(slot, player_ckey, commander))
	return cards

/**
 * Loads the save under the join lock run_load() holds: launch() runs in line, so the lock lasts the whole
 * load and is released when this returns. A refusal brings the player back to the yard with the reason.
 * player is the terminal's own lobby body; the unit tests pass one, having no client.
 */
/datum/lobby_terminal/load_saved_ship(slot, form_new, mob/dead/new_player/player)
	if(!player)
		player = owner?.mob
	if(!istype(player) || !player.ckey)
		return FALSE
	var/player_ckey = player.ckey
	var/had_save = !!GLOB.ship_saves.saved_row(player_ckey, slot)
	GLOB.ship_saves.launch(player, slot, form_new)
	// Aboard, or gone: nothing to say here.
	if(QDELETED(src) || QDELETED(player) || player.spawning || player.spawning_ship)
		return TRUE
	if(player.client && !istype(player.client.mob, /mob/dead/new_player))
		return TRUE
	GLOB.ship_saves.refresh(player_ckey)
	goto_tab("shipyard")
	// Only a spend takes the row out of the cache while launch() runs: the ship was built, but the player
	// couldn't take a berth on it.
	if(had_save && !GLOB.ship_saves.saved_row(player_ckey, slot))
		set_notice("Your ship is ready, but no berth is free aboard.", "bad")
		return FALSE
	var/denial = GLOB.ship_saves.retrieve_denial(player_ckey, slot)
	if(denial)
		set_notice(denial, "bad")
	else if(SSmapping.at_z_level_ceiling())
		set_notice("Yard congested. Your record is kept. Try again shortly.", "bad")
	else
		set_notice("The yard could not build your ship. Your record is kept.", "bad")
	return FALSE

#undef SHIP_SAVE_CARD_CARRIES
