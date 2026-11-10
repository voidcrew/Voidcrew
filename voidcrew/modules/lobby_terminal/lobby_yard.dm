/**
 * # Dock terminal: SHIPYARD (backend)
 *
 * Overrides the shipyard section procs declared in _lobby_terminal.dm.
 *
 * - yard_static(): the hull catalog, sent only after the player opens SHIPYARD.
 * - yard_data(): parts, ownership and requisition state. DB-backed values are cached on the
 *   terminal and refreshed off the UI tick (yard_refresh()), never inside ui_data().
 * - yard_act(): yard_open, yard_preview (per-hull lazy preview images), yard_commission
 *   (one bill for the hull, finish and modules not owned yet, then launch), yard_requisition
 *   and yard_load (the ship-saves hook).
 *
 * The client sends a configuration, never a price. Every bill is rebuilt here from the shelf.
 */

/// Cached DB values older than this are fetched again on the next shipyard action.
#define LOBBY_YARD_REFRESH_INTERVAL (60 SECONDS)
/// A join lock older than this, with no spawn in flight, is left over from a runtime and is dropped.
#define LOBBY_YARD_STALE_LOCK (3 MINUTES)

/// The shelf as catalog entries for the terminal. Same for everyone; rebuilt when FREE_SHIPS changes.
GLOBAL_LIST(lobby_yard_catalog)
/// FREE_SHIPS value the catalog was built with.
GLOBAL_VAR(lobby_yard_catalog_free)
/// Hull type string -> preview image names for that hull, filled with the catalog.
GLOBAL_LIST_EMPTY(lobby_yard_preview_files)

/datum/lobby_terminal
	/// TRUE once this player opened SHIPYARD; the catalog is only sent after that.
	var/yard_opened = FALSE
	/// Cached parts account: class -> count, or null when there is no ledger (no DB, guest).
	var/list/yard_account
	/// Cached ownership: list("hulls" = list(), "finishes" = list(hull = ids), "modules" = list(hull = ids)).
	var/list/yard_owned
	/// world.time of the last finished refresh.
	var/yard_refreshed_at = 0
	/// TRUE while a refresh is waiting on the DB.
	var/yard_refreshing = FALSE
	/// Hull type strings whose preview images were already sent to this client.
	var/list/yard_previews_sent = list()
	/// TRUE once the preview URL mappings went to the browser.
	var/yard_mappings_sent = FALSE

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

/datum/lobby_terminal/yard_static(mob/user)
	if(!yard_opened)
		return null
	return list("catalog" = lobby_yard_catalog())

/datum/lobby_terminal/yard_data(mob/user)
	if(!yard_opened)
		return null
	return list(
		"account" = yard_account,
		"owned" = yard_owned,
		"free_ships" = !!CONFIG_GET(flag/free_ships),
		"can_requisition" = !!(SSticker?.IsRoundInProgress() && can_requisition_hull(user)),
		"crew_change" = crew_change_name(user),
	)

/// Fetches parts and ownership from the DB (sleeps) and caches them on the terminal.
/datum/lobby_terminal/proc/yard_refresh()
	set waitfor = FALSE
	if(yard_refreshing || !owner?.ckey)
		return
	yard_refreshing = TRUE
	var/player_ckey = owner.ckey
	var/datum/ship_economy_db/economy = GLOB.ship_economy_db
	var/list/parts = economy?.get_parts(player_ckey)
	var/list/hulls = get_effective_unlocked_ships(player_ckey)
	var/list/theme_rows = economy?.get_unlocked_themes(player_ckey) || list()
	var/list/module_rows = economy?.get_unlocked_upgrades(player_ckey) || list()
	if(QDELETED(src))
		return
	yard_refreshing = FALSE
	yard_refreshed_at = world.time
	yard_account = parts
	var/list/owned_modules = lobby_yard_split_unlocks(module_rows)
	// Builder Bay was merged into Engineering Bay; honour old purchases as the selector does.
	var/list/pill_modules = owned_modules["[/datum/map_template/shuttle/voidcrew/pill]"]
	if(pill_modules && ("pill_extra_builder" in pill_modules))
		pill_modules |= "pill_extra_engineering"
	yard_owned = list(
		"hulls" = hulls,
		"finishes" = lobby_yard_split_unlocks(theme_rows),
		"modules" = owned_modules,
	)
	if(ui && !QDELETED(ui))
		SStgui.update_uis(src)

/// "type|id" unlock rows -> list(type = list(ids)).
/proc/lobby_yard_split_unlocks(list/rows)
	var/list/by_hull = list()
	for(var/row in rows)
		var/list/row_parts = splittext(row, "|")
		if(length(row_parts) < 2)
			continue
		var/list/ids = by_hull[row_parts[1]]
		if(!ids)
			ids = list()
			by_hull[row_parts[1]] = ids
		ids |= row_parts[2]
	return by_hull

// ---------------------------------------------------------------------------
// Catalog
// ---------------------------------------------------------------------------

/// The shelf as sent to the terminal (static data). Built once and cached globally.
/proc/lobby_yard_catalog()
	var/free = !!CONFIG_GET(flag/free_ships)
	if(GLOB.lobby_yard_catalog && GLOB.lobby_yard_catalog_free == free)
		return GLOB.lobby_yard_catalog
	ensure_ship_upgrades_initialized()
	var/list/catalog = list()
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		catalog += list(lobby_yard_hull_entry(hull))
	GLOB.lobby_yard_catalog = catalog
	GLOB.lobby_yard_catalog_free = free
	return catalog

/// Part cost list with only the classes that cost something.
/proc/lobby_yard_cost(list/cost)
	var/list/out = list()
	for(var/part_class in cost)
		var/amount = cost[part_class]
		if(isnum(amount) && amount > 0)
			out[part_class] = amount
	return out

/// Job definitions (theme/module job_slots format) -> list(list(title, slots)).
/proc/lobby_yard_crew_lines(list/definitions)
	var/list/lines = list()
	for(var/list/definition in definitions)
		if(!definition["name"])
			continue
		lines += list(list("[definition["name"]]", definition["slots"] || 0))
	return lines

/// A slot key as players read it: the hull prefix dropped, words spaced, upper case.
/proc/lobby_yard_slot_label(datum/map_template/shuttle/voidcrew/hull, slot_key)
	var/label = lowertext("[slot_key]")
	var/list/path_parts = splittext("[hull.type]", "/")
	var/leaf = path_parts[length(path_parts)]
	var/underscore = findtext(leaf, "_")
	var/prefix = "[underscore ? copytext(leaf, 1, underscore) : leaf]_"
	if(findtext(label, prefix) == 1)
		label = copytext(label, length(prefix) + 1)
	label = replacetext(label, "_s_", "'s ")
	label = replacetext(label, "_", " ")
	return uppertext(label)

/proc/lobby_yard_hull_entry(datum/map_template/shuttle/voidcrew/hull)
	var/hull_id = "[hull.type]"
	var/list/themes = get_themes_for_ship(hull.type)
	var/list/modules = get_modules_for_ship(hull.type)

	var/list/slot_keys = list()
	for(var/slot_key in hull.upgrade_slot_ids)
		slot_keys |= slot_key

	var/list/finishes = list()
	for(var/theme_id in themes)
		var/datum/ship_theme/theme = themes[theme_id]
		var/list/theme_slots = get_upgrade_slot_ids_for_theme(hull, theme)
		for(var/slot_key in theme_slots)
			slot_keys |= slot_key
		finishes += list(list(
			"id" = theme.id,
			"name" = theme.name,
			"desc" = theme.desc,
			"cost" = lobby_yard_cost(theme.part_cost),
			"def" = !!theme.is_default,
			"slots" = theme_slots.Copy(),
			"jobs" = lobby_yard_crew_lines(theme.job_slots),
		))

	var/list/slots = list()
	for(var/slot_key in slot_keys)
		slots += list(list("key" = slot_key, "label" = lobby_yard_slot_label(hull, slot_key)))

	var/list/module_entries = list()
	for(var/module_id in modules)
		var/datum/ship_upgrade_module/module = modules[module_id]
		var/list/module_themes = null
		if(islist(module.for_theme))
			var/list/theme_list = module.for_theme
			module_themes = theme_list.Copy()
		else if(module.for_theme)
			module_themes = list("[module.for_theme]")
		var/list/jobs = list()
		jobs[""] = lobby_yard_crew_lines(module.job_slots_add)
		for(var/theme_key in module.job_slots_add_by_theme)
			jobs["[theme_key]"] = lobby_yard_crew_lines(module.job_slots_add_by_theme[theme_key])
		module_entries += list(list(
			"id" = module.id,
			"name" = module.name,
			"desc" = module.desc,
			"slot" = module.slot,
			"cost" = lobby_yard_cost(module.part_cost),
			"def" = !!module.is_default,
			"themes" = module_themes,
			"jobs" = jobs,
		))

	var/list/preview = build_ship_preview_data(hull)
	GLOB.lobby_yard_preview_files[hull_id] = lobby_yard_preview_names(preview)

	var/list/entry = list(
		"id" = hull_id,
		"name" = hull.name,
		"short" = hull.short_name || hull.name,
		"desc" = hull.catalog_desc || generate_ship_description(hull),
		"cost" = lobby_yard_cost(hull.part_requirements),
		"free" = !!is_ship_free(hull),
		"finishes" = finishes,
		"slots" = slots,
		"modules" = module_entries,
		"preview" = preview,
	)
	// Optional key (not in the shared types): a hull without finishes takes its crew from the template.
	if(!length(themes))
		entry["jobs"] = lobby_yard_crew_lines(hull.job_slots)
	return entry

/// Every image name a hull's preview block refers to.
/proc/lobby_yard_preview_names(list/preview)
	var/list/names = list()
	if(!islist(preview))
		return names
	var/list/hulls = preview["hulls"]
	for(var/theme_id in hulls)
		var/list/hull_entry = hulls[theme_id]
		if(islist(hull_entry) && hull_entry["png"])
			names |= hull_entry["png"]
	var/list/modules = preview["modules"]
	for(var/module_id in modules)
		var/list/module_entry = modules[module_id]
		if(!islist(module_entry))
			continue
		if(module_entry["png"])
			names |= module_entry["png"]
		var/list/variants = module_entry["themes"]
		for(var/theme_id in variants)
			var/list/variant = variants[theme_id]
			if(islist(variant) && variant["png"])
				names |= variant["png"]
	return names

/// A hull type string from the client, resolved only against the shelf.
/proc/lobby_yard_find_hull(hull_id)
	if(!istext(hull_id) || !hull_id)
		return null
	for(var/datum/map_template/shuttle/voidcrew/hull as anything in get_purchasable_ship_templates())
		if("[hull.type]" == hull_id)
			return hull
	return null

/**
 * Turns a client fit into a theme and slot selections, the way the selector validates
 * them. Unnamed slots take their default module. Returns list(theme, selections), or a
 * string saying why the fit is refused.
 */
/proc/lobby_yard_resolve_fit(datum/map_template/shuttle/voidcrew/hull, finish_id, list/module_ids)
	var/list/themes = get_themes_for_ship(hull.type)
	var/datum/ship_theme/theme = null
	if(length(themes))
		if(finish_id)
			theme = themes["[finish_id]"]
			if(!theme)
				return "That finish isn't offered on this hull."
		else
			theme = get_default_theme_for_ship(hull.type)
	var/list/modules = get_modules_for_ship(hull.type)
	var/list/selections = list()
	for(var/slot_key in get_upgrade_slot_ids_for_theme(hull, theme))
		var/module_id = islist(module_ids) ? module_ids[slot_key] : null
		if(module_id)
			var/datum/ship_upgrade_module/module = modules["[module_id]"]
			if(!module || module.slot != slot_key || !is_module_available_for_theme(module, theme?.id))
				return "That fit isn't offered on this hull."
			selections[slot_key] = module
			continue
		var/datum/ship_upgrade_module/default_module = get_default_module_for_ship_slot(hull.type, slot_key)
		if(default_module && is_module_available_for_theme(default_module, theme?.id))
			selections[slot_key] = default_module
	return list(theme, selections)

// ---------------------------------------------------------------------------
// The bill
// ---------------------------------------------------------------------------

/**
 * Lines of a commission bill: every item in the fit the player doesn't own yet and that
 * costs parts. Each line is list("kind" = "hull"/"finish"/"module", "id", "name", "cost").
 * Pure: the caller supplies ownership, so the math can be tested without a database.
 */
/proc/lobby_yard_bill_lines(datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, list/selections, hull_owned, list/owned_theme_ids, list/owned_module_ids)
	var/list/lines = list()
	if(!hull_owned && !is_ship_free(hull))
		var/list/hull_cost = lobby_yard_cost(hull.part_requirements)
		if(length(hull_cost))
			lines += list(list("kind" = "hull", "id" = "[hull.type]", "name" = hull.name, "cost" = hull_cost))
	if(theme && !theme.is_default && !(theme.id in owned_theme_ids))
		var/list/theme_cost = lobby_yard_cost(theme.part_cost)
		if(length(theme_cost))
			lines += list(list("kind" = "finish", "id" = theme.id, "name" = theme.name, "cost" = theme_cost))
	for(var/slot_key in selections)
		var/datum/ship_upgrade_module/module = selections[slot_key]
		if(!istype(module) || module.is_default || (module.id in owned_module_ids))
			continue
		var/list/module_cost = lobby_yard_cost(module.part_cost)
		if(length(module_cost))
			lines += list(list("kind" = "module", "id" = module.id, "name" = module.name, "cost" = module_cost))
	return lines

/// Sum of a bill's lines: class -> parts.
/proc/lobby_yard_bill_total(list/lines)
	var/list/total = list()
	for(var/list/line in lines)
		var/list/cost = line["cost"]
		for(var/part_class in cost)
			total[part_class] = (total[part_class] || 0) + cost[part_class]
	return total

/**
 * Pays a commission bill: reads ownership and parts (sleeps on the DB), spends the total
 * once, then records every unlock. Returns TRUE when paid (or nothing was owed), or a
 * short line saying why not. An unlock write that fails after paying is logged and
 * reported to admins; the commission still goes ahead, since the player has paid.
 */
/datum/lobby_terminal/proc/yard_settle(mob/user, player_ckey, datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, list/selections, datum/ship_economy_db/economy = GLOB.ship_economy_db)
	if(CONFIG_GET(flag/free_ships))
		return TRUE
	var/hull_id = "[hull.type]"
	var/hull_owned = is_ship_free(hull)
	if(!hull_owned)
		if(!economy)
			return "The shipyard ledger is offline."
		hull_owned = economy.is_ship_unlocked(player_ckey, hull_id)
	var/list/owned_themes = economy?.get_unlocked_themes_for_ship(player_ckey, hull_id) || list()
	var/list/owned_modules = economy?.get_unlocked_upgrades_for_ship(player_ckey, hull_id) || list()
	if(hull.type == /datum/map_template/shuttle/voidcrew/pill && ("pill_extra_builder" in owned_modules))
		owned_modules |= "pill_extra_engineering"

	var/list/lines = lobby_yard_bill_lines(hull, theme, selections, hull_owned, owned_themes, owned_modules)
	if(!length(lines))
		return TRUE
	if(!economy)
		return "The shipyard ledger is offline."
	var/list/total = lobby_yard_bill_total(lines)
	var/list/parts = economy.get_parts(player_ckey)
	if(!parts)
		return "The shipyard ledger is offline."
	for(var/part_class in total)
		if((parts[part_class] || 0) < total[part_class])
			return "Not enough parts for this bill."
	if(!economy.spend_parts(player_ckey, total))
		return "The payment didn't go through. Nothing was charged."

	var/list/total_text = list()
	for(var/part_class in total)
		total_text += "[total[part_class]] [part_class]"
	log_game("SHIP_CATALOG: [player_ckey] paid a lobby bill of [total_text.Join(", ")] for [hull_id] ([length(lines)] item\s)")

	for(var/list/line in lines)
		var/written = FALSE
		switch(line["kind"])
			if("hull")
				written = economy.unlock_ship(player_ckey, hull_id)
				if(written)
					log_game("SHIP_CATALOG: [player_ckey] unlocked ship [hull_id] ([hull.name])")
					ship_metric_hull_unlocked(user, hull)
			if("finish")
				written = economy.unlock_theme(player_ckey, hull_id, line["id"])
				if(written)
					log_game("SHIP_UPGRADE: [player_ckey] purchased theme '[line["id"]]' for [hull_id]")
					ship_metric_unlocked("ship_theme_unlocked", user, hull.type, line["id"], line["cost"], FALSE)
			if("module")
				written = economy.unlock_upgrade(player_ckey, hull_id, line["id"])
				if(written)
					log_game("SHIP_UPGRADE: [player_ckey] purchased upgrade '[line["id"]]' for [hull_id]")
					ship_metric_unlocked("ship_module_unlocked", user, hull.type, line["id"], line["cost"], FALSE)
		if(!written)
			log_game("SHIP_CATALOG ERROR: [player_ckey] paid for [line["kind"]] [line["id"]] on [hull_id] but the unlock was not recorded")
			message_admins("Ship unlock failed for [player_ckey]: paid for [line["kind"]] [line["id"]] on [hull_id], but it was not recorded. Check the game log.")
	return TRUE

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

/datum/lobby_terminal/yard_act(action, list/params, mob/user)
	var/mob/dead/new_player/player = user
	if(!istype(player))
		return FALSE
	switch(action)
		if("yard_open")
			if(!yard_opened)
				yard_opened = TRUE
				if(ui && !QDELETED(ui))
					update_static_data(player, ui)
			yard_refresh()
			return TRUE
		if("yard_preview")
			yard_send_preview(params["hull"])
			return FALSE
		if("yard_commission")
			return yard_commission(player, params)
		if("yard_requisition")
			return yard_requisition(player, params)
		if("yard_load")
			return yard_load(player, params)
	return FALSE

/// Sends one hull's preview images to this client, once.
/datum/lobby_terminal/proc/yard_send_preview(hull_id)
	if(!yard_opened || !owner || !istext(hull_id) || (hull_id in yard_previews_sent))
		return
	lobby_yard_catalog() // fills the preview file index
	var/list/names = GLOB.lobby_yard_preview_files[hull_id]
	if(isnull(names)) // not on the shelf
		return
	yard_previews_sent += hull_id
	if(!length(names))
		return
	var/datum/asset/previews = get_asset_datum(/datum/asset/simple/ship_previews)
	SSassets.transport.send_assets(owner, names)
	if(!yard_mappings_sent && window)
		yard_mappings_sent = TRUE
		window.send_raw_message(previews.get_serialized_url_mappings())

/**
 * Why a join route can't start right now, or null. Same gates as the Join key: round
 * running, admin late-join switch, popcap queue.
 */
/datum/lobby_terminal/proc/yard_route_denial(mob/dead/new_player/player)
	if(!SSticker?.IsRoundInProgress())
		return "The port is not open yet."
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		return "No berths are being assigned right now."
	if(ckey(player.key) in GLOB.admin_datums)
		return null
	var/relevant_cap
	var/hard_popcap = CONFIG_GET(number/hard_popcap)
	var/extreme_popcap = CONFIG_GET(number/extreme_popcap)
	if(hard_popcap && extreme_popcap)
		relevant_cap = min(hard_popcap, extreme_popcap)
	else
		relevant_cap = max(hard_popcap, extreme_popcap)
	var/full = relevant_cap && living_player_count() >= relevant_cap
	if(SSticker.queued_players.len)
		if(full || player != SSticker.queued_players[1])
			return "Port is full. Wait for your turn in line."
	else if(full)
		return "Port is full. Press JOIN to get in line."
	return null

/**
 * Takes the shared join lock, dropping one left over from a runtime first. FALSE when
 * another route is running for this player.
 */
/datum/lobby_terminal/proc/yard_take_lock(mob/dead/new_player/player)
	var/locked_at = GLOB.lobby_join_locks[player.ckey]
	if(locked_at && world.time - locked_at > LOBBY_YARD_STALE_LOCK && !player.spawning && !player.spawning_ship)
		release_join_lock(player.ckey)
	return try_join_lock(player)

/**
 * The crew-leave answer for a founding route. Returns TRUE (found a new crew and leave the
 * old one), FALSE (nothing to leave), or null after asking the client to confirm.
 */
/datum/lobby_terminal/proc/yard_form_new(mob/dead/new_player/player, list/params)
	var/crew_name = crew_change_name(player)
	if(!crew_name)
		return FALSE
	if(text2num("[params["leave_crew"]]") == 1)
		return TRUE
	set_notice("This leaves [crew_name].", "warn")
	return null

/datum/lobby_terminal/proc/yard_commission(mob/dead/new_player/player, list/params)
	var/denial = yard_route_denial(player)
	if(denial)
		set_notice(denial, "warn")
		return TRUE
	var/datum/map_template/shuttle/voidcrew/hull = lobby_yard_find_hull(params["hull"])
	if(!hull)
		set_notice("That hull isn't on the shelf.", "bad")
		return TRUE
	var/fit = lobby_yard_resolve_fit(hull, params["finish"], params["modules"])
	if(!islist(fit))
		set_notice(fit, "bad")
		return TRUE
	var/list/fit_list = fit
	var/form_new = yard_form_new(player, params)
	if(isnull(form_new))
		return TRUE
	if(!yard_take_lock(player))
		set_notice("Your ship is already being prepared.", "warn")
		return TRUE
	set_notice("Preparing your [hull.name].", "ok")
	INVOKE_ASYNC(src, PROC_REF(run_commission), player, player.ckey, hull, fit_list[1], fit_list[2], form_new)
	return TRUE

/**
 * Pays the bill and launches. The caller holds the join lock; this releases it on every
 * path. Sleeps on the DB and on the ship load.
 */
/datum/lobby_terminal/proc/run_commission(mob/dead/new_player/player, player_ckey, datum/map_template/shuttle/voidcrew/hull, datum/ship_theme/theme, list/selections, form_new, datum/ship_economy_db/economy = GLOB.ship_economy_db)
	var/paid = yard_settle(player, player_ckey, hull, theme, selections, economy)
	if(QDELETED(src))
		release_join_lock(player_ckey)
		return
	yard_refresh_after_purchase()
	if(paid != TRUE)
		release_join_lock(player_ckey)
		set_notice(paid, "bad")
		return
	// The player may have left or spawned while the DB answered. Their unlocks are kept.
	if(QDELETED(player) || !player.client || player.client != owner)
		release_join_lock(player_ckey)
		return
	// The crew they agreed to leave may have changed while the DB answered.
	var/crew_name = crew_change_name(player)
	if(!crew_name)
		form_new = FALSE
	else if(!form_new)
		release_join_lock(player_ckey)
		set_notice("This leaves [crew_name].", "warn")
		return
	log_game("[key_name(player)] commissioned [hull.name] ([hull.type]) from the dock terminal[theme ? " in [theme.id]" : ""]")
	player.spawn_ship_with_upgrades(hull, selections, theme, form_new)
	release_join_lock(player_ckey)
	yard_report_failed_launch(player)

/// Re-reads ownership after something may have been bought.
/datum/lobby_terminal/proc/yard_refresh_after_purchase()
	if(yard_opened)
		yard_refresh()

/// After a launch call returns: if the player is still in the lobby, say why.
/datum/lobby_terminal/proc/yard_report_failed_launch(mob/dead/new_player/player)
	if(QDELETED(src) || QDELETED(player) || !player.client || !istype(player.client.mob, /mob/dead/new_player))
		return
	goto_tab("shipyard")
	if(player.spawning_ship)
		set_notice("Your ship is ready, but no berth is free aboard.", "bad")
	else if(SSmapping.at_z_level_ceiling())
		set_notice("The shipyard is congested. What you paid for stays yours; try again shortly.", "bad")
	else
		set_notice("The shipyard could not prepare your ship. What you paid for stays yours.", "bad")

/datum/lobby_terminal/proc/yard_requisition(mob/dead/new_player/player, list/params)
	var/denial = yard_route_denial(player)
	if(denial)
		set_notice(denial, "warn")
		return TRUE
	if(!can_requisition_hull(player))
		set_notice("A berth has opened aboard the fleet.", "warn")
		return TRUE
	var/form_new = yard_form_new(player, params)
	if(isnull(form_new))
		return TRUE
	if(!yard_take_lock(player))
		set_notice("Your ship is already being prepared.", "warn")
		return TRUE
	set_notice("Requisitioning a hull.", "ok")
	INVOKE_ASYNC(src, PROC_REF(run_requisition), player, player.ckey, form_new)
	return TRUE

/// requisition_free_hull() with the terminal's crew answer. Releases the join lock.
/datum/lobby_terminal/proc/run_requisition(mob/dead/new_player/player, player_ckey, form_new)
	if(QDELETED(player))
		release_join_lock(player_ckey)
		return
	player.lobby_form_new = form_new
	player.requisition_free_hull()
	if(!QDELETED(player))
		player.lobby_form_new = null
	release_join_lock(player_ckey)
	yard_report_failed_launch(player)

/datum/lobby_terminal/proc/yard_load(mob/dead/new_player/player, list/params)
	var/denial = yard_route_denial(player)
	if(denial)
		set_notice(denial, "warn")
		return TRUE
	var/slot = text2num("[params["slot"]]")
	if(!isnum(slot) || slot < 1 || slot != round(slot))
		return FALSE
	var/form_new = yard_form_new(player, params)
	if(isnull(form_new))
		return TRUE
	if(!yard_take_lock(player))
		set_notice("Your ship is already being prepared.", "warn")
		return TRUE
	INVOKE_ASYNC(src, PROC_REF(run_load), player.ckey, slot, form_new)
	return TRUE

/// The ship-saves hook under the join lock. Releases it.
/datum/lobby_terminal/proc/run_load(player_ckey, slot, form_new)
	load_saved_ship(slot, form_new)
	release_join_lock(player_ckey)

#undef LOBBY_YARD_REFRESH_INTERVAL
#undef LOBBY_YARD_STALE_LOCK
