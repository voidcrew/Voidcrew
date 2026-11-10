/**
 * # Dock terminal: CHARACTER section (package C1)
 *
 * A thin adapter over /datum/preferences for the terminal's CHARACTER tab. Overrides the
 * seams declared in _lobby_terminal.dm without the `proc/` keyword: char_data(), char_act(),
 * char_changed(), char_push(), char_save().
 *
 * Owns: every char_* action except the preview's, the char/char_static pushes, saving,
 * sync with tg's character window, the species confirm flow, the native colour pick and the
 * shared roundstart job pool GLOB (C2 reads it for the preview's outfits).
 *
 * Preference adapters (is_accessible override, lobby_char_writes, ui_act sync) live in
 * lobby_character_prefs.dm; the preview in lobby_character_preview.dm.
 *
 * Every value goes through tg's own validation (update_preference(), the quirk and loadout
 * middleware); this file only checks the shape of what the client sent and replaces tg's popups.
 */

/// Most char_* actions one terminal takes in a second; the rest are dropped.
#define LOBBY_CHAR_ACTS_PER_SECOND 20
/// Edits are written to disk this long after the last one (and on slot switch, hide and Destroy).
#define LOBBY_CHAR_SAVE_DELAY (5 SECONDS)
/// A native colour dialog left open longer than this no longer blocks a new one.
#define LOBBY_CHAR_PICK_TIMEOUT (2 MINUTES)

/// Every job a roundstart ship can spawn with (job datums), built once. Read through lobby_char_job_pool().
GLOBAL_LIST_EMPTY(lobby_char_job_pool)
/// char_static, built once per round by lobby_char_static().
GLOBAL_LIST_EMPTY(lobby_char_static)

/datum/lobby_terminal
	/// Edits not yet written to disk.
	var/char_dirty = FALSE
	/// char_static goes out with the next push (once per page, on char_open).
	var/char_static_due = FALSE
	/// Species change waiting on char_confirm: list("value", "quirks", "slot"), or null. Any other edit clears it.
	var/list/char_confirm_state
	/// The facing the client last asked for (char_turn), so edits re-render the side on screen.
	var/char_facing = SOUTH
	/// Action spam guard: start of the current one-second window and the actions taken in it.
	var/char_act_window = 0
	var/char_act_count = 0

/// Builds (once) and returns the roundstart job pool as a flat list of job datums.
/proc/lobby_char_job_pool()
	if(!length(GLOB.lobby_char_job_pool))
		var/list/pool = build_roundstart_job_pool()
		for(var/datum/job/job as anything in pool)
			GLOB.lobby_char_job_pool += job
	return GLOB.lobby_char_job_pool

/// The small per-round catalog the terminal adds to preferences.json: role examples and kit colour slot counts.
/proc/lobby_char_static()
	if(length(GLOB.lobby_char_static))
		return GLOB.lobby_char_static
	var/list/roles = list()
	for(var/category in GLOB.job_categories)
		var/list/slots_by_title = list()
		for(var/datum/job/job as anything in lobby_char_job_pool())
			if(job.job_category != category || !job.title)
				continue
			slots_by_title[job.title] += 1
		sortTim(slots_by_title, GLOBAL_PROC_REF(cmp_numeric_dsc), associative = TRUE)
		var/list/examples = list()
		for(var/title in slots_by_title)
			examples += title
			if(length(examples) >= 3)
				break
		roles += list(list(category, jointext(examples, ", ")))
	var/list/kit_colors = list()
	for(var/path in GLOB.all_loadout_datums)
		var/datum/loadout_item/item = GLOB.all_loadout_datums[path]
		var/count = lobby_char_kit_color_count(item)
		if(count)
			kit_colors["[item.item_path]"] = count
	GLOB.lobby_char_static = list("roles" = roles, "kit_colors" = kit_colors)
	return GLOB.lobby_char_static

/// Number of GAGS colour slots a recolourable loadout item has, or 0.
/proc/lobby_char_kit_color_count(datum/loadout_item/item)
	if(!istype(item) || !item.can_be_greyscale)
		return 0
	var/obj/item/item_path = item.item_path
	var/config_path = initial(item_path.greyscale_config)
	if(!config_path)
		return 0
	var/datum/greyscale_config/config = SSgreyscale.configurations["[config_path]"]
	return config?.expected_colors || 0

/// "#rgb", "rrggbb" or "#rrggbb" to "#rrggbb" (lower case), or null when it isn't a colour.
/proc/lobby_char_clean_hex(value)
	if(!istext(value))
		return null
	var/static/regex/hex6 = regex(@"^#?([0-9a-fA-F]{6})$")
	var/static/regex/hex3 = regex(@"^#?([0-9a-fA-F])([0-9a-fA-F])([0-9a-fA-F])$")
	if(hex6.Find(value))
		return lowertext("#[hex6.group[1]]")
	if(hex3.Find(value))
		return lowertext("#[hex3.group[1]][hex3.group[1]][hex3.group[2]][hex3.group[2]][hex3.group[3]][hex3.group[3]]")
	return null

/// Whole number out of a JSON param (number or numeric text), or null.
/proc/lobby_char_int(value)
	if(istext(value))
		value = text2num(value)
	if(!isnum(value) || value != round(value))
		return null
	return value

/// The prefs this terminal edits. A proc so the unit test can hand in a mock client's prefs.
/datum/lobby_terminal/proc/char_get_prefs(mob/user)
	return user?.client?.prefs

/datum/lobby_terminal/char_data(mob/user)
	return list("char_rev" = char_rev)

/datum/lobby_terminal/char_act(action, list/params, mob/user)
	var/datum/preferences/prefs = char_get_prefs(user)
	if(!prefs)
		return FALSE
	prefs.lobby_char_writes = 0 // in case a runtime left it set
	if(world.time >= char_act_window + 1 SECONDS)
		char_act_window = world.time
		char_act_count = 0
	if(++char_act_count > LOBBY_CHAR_ACTS_PER_SECOND)
		return FALSE
	if(!islist(params))
		params = list()

	switch(action)
		if("char_open")
			return char_open_tab(user, prefs)
		if("char_slot")
			return char_switch_slot(user, prefs, lobby_char_int(params["slot"]))
		if("char_set")
			// params["confirm"] is ignored: only char_confirm can apply a species change that drops quirks.
			return char_set_pref(user, prefs, params["key"], params["value"])
		if("char_random_name")
			var/datum/preference/name/real_name/name_pref = GLOB.preference_entries[/datum/preference/name/real_name]
			return char_apply(user, prefs, name_pref, name_pref.create_random_value(prefs))
		if("char_color_pick")
			return char_start_color_pick(user, prefs, params["key"])
		if("char_voice_play")
			var/datum/preference_middleware/bark/bark = locate() in prefs.middleware
			if(bark)
				INVOKE_ASYNC(bark, TYPE_PROC_REF(/datum/preference_middleware/bark, play_bark), list(), user)
			return TRUE
		if("char_role")
			return char_set_role(user, prefs, params["category"], lobby_char_int(params["level"]))
		if("char_quirk")
			return char_set_quirk(user, prefs, params["quirk"], !!lobby_char_int(params["on"]))
		if("char_kit")
			return char_set_kit(user, prefs, params["path"], !!lobby_char_int(params["on"]))
		if("char_kit_color")
			return char_set_kit_color(user, prefs, params["path"], lobby_char_int(params["slot"]), params["color"])
		if("char_kit_name")
			return char_set_kit_name(user, prefs, params["path"], params["name"])
		if("char_kit_skin")
			return char_set_kit_skin(user, prefs, params["path"], params["skin"])
		if("char_dress")
			return char_set_dress(user, prefs, params["category"])
		if("char_turn")
			var/dir = lobby_char_int(params["dir"])
			if(!(dir in GLOB.cardinals))
				return FALSE
			char_facing = dir
			char_preview_request(dir)
			return TRUE
		if("char_confirm")
			return char_answer_confirm(user, prefs, !!lobby_char_int(params["ok"]))
	return FALSE

/// Bookkeeping after any change to the character: rev, save timer, pushes to both windows, the preview.
/datum/lobby_terminal/proc/char_edited(mob/user, datum/preferences/prefs)
	char_rev++
	char_dirty = TRUE
	char_confirm_state = null
	addtimer(CALLBACK(src, PROC_REF(char_save)), LOBBY_CHAR_SAVE_DELAY, TIMER_UNIQUE | TIMER_OVERRIDE)
	char_push(user)
	char_preview_request(char_facing)
	if(user && SStgui.get_open_ui(user, prefs))
		addtimer(CALLBACK(src, PROC_REF(char_sync_tg_window)), 0.5 SECONDS, TIMER_UNIQUE)

/// Resends tg's character window after terminal edits (its autoupdate is off).
/datum/lobby_terminal/proc/char_sync_tg_window()
	var/mob/user = owner?.mob
	var/datum/preferences/prefs = owner?.prefs
	if(!user || !prefs)
		return
	prefs.update_static_data(user)

/// One preference value through tg's update_preference(), then the middleware's post hooks.
/datum/lobby_terminal/proc/char_apply(mob/user, datum/preferences/prefs, datum/preference/preference, value)
	if(!prefs.lobby_update_preference(preference, value))
		return FALSE
	if(istype(preference, /datum/preference/name))
		prefs.tainted_character_profiles = TRUE
	for(var/datum/preference_middleware/preference_middleware as anything in prefs.middleware)
		preference_middleware.post_set_preference(user, preference.savefile_key, value)
	char_edited(user, prefs)
	return TRUE

/datum/lobby_terminal/proc/char_open_tab(mob/user, datum/preferences/prefs)
	if(ui && !QDELETED(ui) && ui.window)
		if(ui.send_asset(get_asset_datum(/datum/asset/json/preferences)))
			owner?.browse_queue_flush()
		if(QDELETED(src) || !ui || QDELETED(ui))
			return FALSE
	char_open = TRUE
	char_static_due = TRUE
	char_push(user)
	char_preview_request(char_facing)
	return TRUE

/datum/lobby_terminal/proc/char_switch_slot(mob/user, datum/preferences/prefs, slot)
	if(isnull(slot) || char_pending_pick)
		return FALSE
	if(slot == prefs.default_slot)
		return FALSE
	if(!prefs.lobby_switch_to_slot(slot, user))
		return FALSE
	char_edited(user, prefs)
	char_save()
	return TRUE

/datum/lobby_terminal/proc/char_set_pref(mob/user, datum/preferences/prefs, key, value)
	if(!istext(key))
		return FALSE
	var/datum/preference/preference = GLOB.preference_entries_by_key[key]
	if(!prefs.lobby_char_key_allowed(preference))
		return FALSE
	if(istype(preference, /datum/preference/color))
		value = lobby_char_clean_hex(value)
		if(!value)
			return FALSE
	if(istype(preference, /datum/preference/choiced/species))
		var/list/dropped = char_quirks_dropped_by(prefs, value)
		if(length(dropped))
			char_confirm_state = list("value" = value, "quirks" = dropped, "slot" = prefs.default_slot)
			char_rev++
			char_push(user)
			return TRUE
	return char_apply(user, prefs, preference, value)

/// Names of the taken quirks the species with that id can't keep.
/datum/lobby_terminal/proc/char_quirks_dropped_by(datum/preferences/prefs, species_id)
	var/list/dropped = list()
	if(!istext(species_id))
		return dropped
	var/species_type = GLOB.species_list[species_id]
	if(!species_type || !GLOB.species_prototypes[species_type])
		return dropped
	for(var/quirk_name in prefs.all_quirks)
		var/datum/quirk/prototype = SSquirks.quirk_prototypes[SSquirks.quirks[quirk_name]]
		if(prototype && !prototype.is_species_appropriate(species_type))
			dropped += quirk_name
	return dropped

/datum/lobby_terminal/proc/char_answer_confirm(mob/user, datum/preferences/prefs, ok)
	var/list/state = char_confirm_state
	if(!state)
		return FALSE
	char_confirm_state = null
	if(!ok || state["slot"] != prefs.default_slot)
		char_rev++
		char_push(user)
		return TRUE
	// post_set_preference -> validate_quirks() drops what no longer fits, as in tg.
	if(!char_apply(user, prefs, GLOB.preference_entries[/datum/preference/choiced/species], state["value"]))
		char_rev++
		char_push(user)
	return TRUE

/datum/lobby_terminal/proc/char_start_color_pick(mob/user, datum/preferences/prefs, key)
	var/static/list/native_keys = list("hair_color", "hair_gradient_color", "facial_hair_color", "feature_mcolor", "eye_color")
	if(!istext(key) || !(key in native_keys))
		return FALSE
	var/datum/preference/color/preference = GLOB.preference_entries_by_key[key]
	if(!istype(preference) || !prefs.lobby_char_key_allowed(preference))
		return FALSE
	prefs.lobby_char_writes = 1
	var/accessible = preference.is_accessible(prefs)
	prefs.lobby_char_writes = 0
	if(!accessible)
		return FALSE
	if(char_pending_pick && world.time < char_pending_pick["at"] + LOBBY_CHAR_PICK_TIMEOUT)
		return FALSE
	char_pending_pick = list("key" = key, "slot" = prefs.default_slot, "rev" = char_rev, "at" = world.time)
	INVOKE_ASYNC(src, PROC_REF(char_wait_color_pick), user, prefs, preference, char_pending_pick)
	return TRUE

/// The native colour dialog (tg's own free picker). Sleeps on input(); everything is re-checked after.
/datum/lobby_terminal/proc/char_wait_color_pick(mob/user, datum/preferences/prefs, datum/preference/color/preference, list/pick)
	var/new_color = input(user, "Select new color", null, prefs.read_preference(preference.type) || COLOR_WHITE) as color|null
	if(QDELETED(src))
		return
	if(char_pending_pick == pick)
		char_pending_pick = null
	if(!new_color || QDELETED(user) || char_get_prefs(user) != prefs)
		return
	if(prefs.default_slot != pick["slot"] || char_rev != pick["rev"])
		return
	new_color = lobby_char_clean_hex(new_color)
	if(!new_color)
		return
	char_apply(user, prefs, preference, new_color)

/datum/lobby_terminal/proc/char_set_role(mob/user, datum/preferences/prefs, category, level)
	if(!istext(category) || !(category in GLOB.job_categories))
		return FALSE
	if(level != 0 && level != JP_LOW && level != JP_MEDIUM && level != JP_HIGH)
		return FALSE
	var/new_level = level || null
	if(prefs.ship_category_preferences[category] == new_level)
		return FALSE
	if(new_level == JP_HIGH)
		// One HIGH role: the old one drops to MED.
		for(var/other in prefs.ship_category_preferences)
			if(other != category && prefs.ship_category_preferences[other] == JP_HIGH)
				prefs.ship_category_preferences[other] = JP_MEDIUM
	if(!prefs.set_ship_category_preference(category, new_level))
		return FALSE
	char_edited(user, prefs)
	return TRUE

/// A quirk's name from either its name or its quirk_info key (sanitize_css_class_name), or null.
/datum/lobby_terminal/proc/char_quirk_name(quirk)
	if(!istext(quirk))
		return null
	var/list/all = SSquirks.get_quirks()
	if(all[quirk])
		return quirk
	for(var/quirk_name in all)
		if(sanitize_css_class_name(quirk_name) == quirk)
			return quirk_name
	return null

/datum/lobby_terminal/proc/char_set_quirk(mob/user, datum/preferences/prefs, quirk, on)
	var/quirk_name = char_quirk_name(quirk)
	if(!quirk_name)
		return FALSE
	var/datum/preference_middleware/quirks/manager = locate() in prefs.middleware
	if(!manager)
		return FALSE
	if(on)
		if(quirk_name in prefs.all_quirks)
			return FALSE
		var/datum/quirk/prototype = SSquirks.quirk_prototypes[SSquirks.quirks[quirk_name]]
		if(!prototype?.is_species_appropriate(prefs.read_preference(/datum/preference/choiced/species)))
			return FALSE
		// give_quirk runs SSquirks.filter_invalid_quirks(): points, positive cap, blacklist pairs, mood.
		manager.give_quirk(list("quirk" = quirk_name), user)
		if(!(quirk_name in prefs.all_quirks))
			char_push(user) // snap the client back
			return FALSE
	else
		if(!(quirk_name in prefs.all_quirks))
			return FALSE
		// remove_quirk refuses a removal that would leave an invalid set (tg's rule).
		manager.remove_quirk(list("quirk" = quirk_name), user)
		if(quirk_name in prefs.all_quirks)
			char_push(user)
			return FALSE
	char_edited(user, prefs)
	return TRUE

/// The loadout item datum for a typepath string, or null. Only GLOB.all_loadout_datums items exist here.
/datum/lobby_terminal/proc/char_kit_item(path)
	if(!istext(path))
		return null
	var/item_path = text2path(path)
	if(!ispath(item_path, /obj/item))
		return null
	var/datum/loadout_item/item = GLOB.all_loadout_datums[item_path]
	return istype(item) ? item : null

/// A copy of the loadout list with its own copy of that item's details, or null when the item isn't packed.
/datum/lobby_terminal/proc/char_kit_copy(datum/preferences/prefs, datum/loadout_item/item)
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	if(!islist(loadout) || !(item.item_path in loadout))
		return null
	loadout = loadout.Copy()
	var/list/details = loadout[item.item_path]
	loadout[item.item_path] = islist(details) ? details.Copy() : list()
	return loadout

/datum/lobby_terminal/proc/char_kit_has(datum/preferences/prefs, datum/loadout_item/item)
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	return islist(loadout) && (item.item_path in loadout)

/datum/lobby_terminal/proc/char_set_kit(mob/user, datum/preferences/prefs, path, on)
	var/datum/loadout_item/item = char_kit_item(path)
	if(!item)
		return FALSE
	var/datum/preference_middleware/loadout/manager = locate() in prefs.middleware
	if(!manager || char_kit_has(prefs, item) == on)
		return FALSE
	prefs.lobby_char_writes = 1
	if(on)
		manager.select_item(item) // the category's duplicate rule may drop an older pick
	else
		manager.deselect_item(item)
	prefs.lobby_char_writes = 0
	if(char_kit_has(prefs, item) != on)
		char_push(user)
		return FALSE
	char_edited(user, prefs)
	return TRUE

/datum/lobby_terminal/proc/char_set_kit_color(mob/user, datum/preferences/prefs, path, slot, color)
	var/datum/loadout_item/item = char_kit_item(path)
	var/count = lobby_char_kit_color_count(item)
	if(!count || isnull(slot) || slot < 0 || slot >= count)
		return FALSE
	color = lobby_char_clean_hex(color)
	if(!color)
		return FALSE
	var/list/loadout = char_kit_copy(prefs, item)
	if(!loadout)
		return FALSE
	var/list/details = loadout[item.item_path]
	var/obj/item/item_path = item.item_path
	var/list/colors = SSgreyscale.ParseColorString(details[INFO_GREYSCALE] || initial(item_path.greyscale_colors) || "")
	if(length(colors) != count)
		colors = SSgreyscale.ParseColorString(initial(item_path.greyscale_colors) || "")
	colors.len = count
	for(var/i in 1 to count)
		colors[i] = lobby_char_clean_hex(colors[i]) || COLOR_WHITE
	colors[slot + 1] = color
	details[INFO_GREYSCALE] = colors.Join("")
	if(!prefs.lobby_update_preference(GLOB.preference_entries[/datum/preference/loadout], loadout))
		return FALSE
	char_edited(user, prefs)
	return TRUE

/datum/lobby_terminal/proc/char_set_kit_name(mob/user, datum/preferences/prefs, path, name)
	var/datum/loadout_item/item = char_kit_item(path)
	if(!item?.can_be_named || !istext(name))
		return FALSE
	var/list/loadout = char_kit_copy(prefs, item)
	if(!loadout)
		return FALSE
	var/list/details = loadout[item.item_path]
	name = trim(name)
	if(name == "")
		details -= INFO_NAMED
	else
		// Same limits as tg's popup (tgui_input_text, MAX_NAME_LEN), stored HTML-encoded as it does.
		if(length_char(name) > MAX_NAME_LEN || !reject_bad_text(name, MAX_NAME_LEN))
			return FALSE
		details[INFO_NAMED] = html_encode(name)
	if(!prefs.lobby_update_preference(GLOB.preference_entries[/datum/preference/loadout], loadout))
		return FALSE
	char_edited(user, prefs)
	return TRUE

/datum/lobby_terminal/proc/char_set_kit_skin(mob/user, datum/preferences/prefs, path, skin)
	var/datum/loadout_item/item = char_kit_item(path)
	if(!item?.can_be_reskinned || !istext(skin) || !item.cached_reskin_options?[skin])
		return FALSE
	var/datum/preference_middleware/loadout/manager = locate() in prefs.middleware
	if(!manager || !char_kit_has(prefs, item))
		return FALSE
	prefs.lobby_char_writes = 1
	item.handle_loadout_action(manager, user, "set_skin", list("skin" = skin))
	prefs.lobby_char_writes = 0
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	var/list/details = loadout?[item.item_path]
	if(!islist(details) || details[INFO_RESKIN] != skin)
		return FALSE
	char_edited(user, prefs)
	return TRUE

/datum/lobby_terminal/proc/char_set_dress(mob/user, datum/preferences/prefs, category)
	if(!category)
		category = null
	else if(!istext(category) || !(category in GLOB.job_categories) || category == JOB_CAT_SILICON)
		return FALSE
	if(char_dress == category)
		return FALSE
	char_dress = category
	char_rev++
	char_push(user)
	char_preview_request(char_facing)
	return TRUE

/// The category the preview wears: the chosen one, else the HIGH role, else the highest set, else Assistant.
/datum/lobby_terminal/proc/char_resolved_dress(datum/preferences/prefs)
	if(char_dress)
		return char_dress
	var/best
	var/best_level = 0
	for(var/category in GLOB.job_categories)
		var/level = prefs?.ship_category_preferences[category]
		if(level > best_level)
			best = category
			best_level = level
	if(!best || best == JOB_CAT_SILICON)
		return JOB_CAT_ASSISTANT
	return best

/// The char block (CharData in types.ts).
/datum/lobby_terminal/proc/char_build(datum/preferences/prefs, mob/user)
	SHOULD_NOT_SLEEP(TRUE)
	var/list/quirks = list()
	for(var/quirk_name in prefs.all_quirks)
		quirks += sanitize_css_class_name(quirk_name)
	var/list/quirks_blocked = list()
	var/species_type = prefs.read_preference(/datum/preference/choiced/species)
	for(var/quirk_type in SSquirks.quirk_prototypes)
		var/datum/quirk/prototype = SSquirks.quirk_prototypes[quirk_type]
		if(!prototype.is_species_appropriate(species_type))
			quirks_blocked += sanitize_css_class_name(prototype.name)
	var/list/kit = list()
	var/list/loadout = prefs.read_preference(/datum/preference/loadout)
	for(var/item_path in loadout)
		var/list/details = loadout[item_path]
		var/list/entry = list()
		if(islist(details))
			if(details[INFO_GREYSCALE])
				entry["greyscale"] = details[INFO_GREYSCALE]
			if(details[INFO_NAMED])
				entry["name"] = details[INFO_NAMED]
			if(details[INFO_RESKIN])
				entry["reskin"] = details[INFO_RESKIN]
		kit["[item_path]"] = entry
	var/list/confirm
	if(char_confirm_state)
		confirm = list("kind" = "species", "value" = char_confirm_state["value"], "quirks" = char_confirm_state["quirks"])
	return list(
		"rev" = char_rev,
		"slot" = prefs.default_slot,
		"slots" = prefs.create_character_profiles(),
		"prefs" = prefs.lobby_compile_char(user),
		"quirks" = quirks,
		"quirks_blocked" = quirks_blocked,
		"roles" = prefs.ship_category_preferences.Copy(),
		"kit" = kit,
		"dress" = char_resolved_dress(prefs),
		"confirm" = confirm,
	)

/datum/lobby_terminal/char_push(mob/user)
	if(!char_open || !ui || QDELETED(ui))
		return
	if(!user)
		user = owner?.mob
	var/datum/preferences/prefs = char_get_prefs(user)
	if(!prefs)
		return
	var/list/payload = list("char_rev" = char_rev, "char" = char_build(prefs, user))
	if(char_static_due)
		char_static_due = FALSE
		payload["char_static"] = lobby_char_static()
		var/static/sizes_logged = FALSE
		if(!sizes_logged)
			sizes_logged = TRUE
			log_world("Lobby terminal CHARACTER: char block [length(json_encode(payload["char"]))] B, char_static [length(json_encode(payload["char_static"]))] B.")
	ui.send_update(payload)

/datum/lobby_terminal/char_changed()
	if(!char_open)
		return
	char_rev++
	char_confirm_state = null
	addtimer(CALLBACK(src, PROC_REF(char_changed_push)), 0.2 SECONDS, TIMER_UNIQUE)

/datum/lobby_terminal/proc/char_changed_push()
	char_push()
	char_preview_request(char_facing)

/datum/lobby_terminal/char_save()
	SHOULD_NOT_SLEEP(TRUE)
	if(!char_dirty)
		return
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs?.savefile)
		return
	char_dirty = FALSE
	prefs.save_character()
	prefs.save_preferences()

#undef LOBBY_CHAR_ACTS_PER_SECOND
#undef LOBBY_CHAR_SAVE_DELAY
#undef LOBBY_CHAR_PICK_TIMEOUT
