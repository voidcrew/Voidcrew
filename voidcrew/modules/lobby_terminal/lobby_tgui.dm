/**
 * The terminal's tgui. Same as /datum/tgui except open(): instead of a pooled popup it uses
 * the terminal's own unpooled window bound to the lobby_browser control.
 *
 * The body below copies /datum/tgui/open() (code/modules/tgui/tgui.dm). If upstream changes
 * that proc, change this one to match. Unpooled windows never suspend
 * (/datum/tgui_window/can_be_suspended() needs `pooled`), which matters here: a suspend
 * would winset the control to 1x1 off-screen and wreck the map pane.
 */
/datum/tgui/lobby_terminal

/datum/tgui/lobby_terminal/open()
	if(!user.client)
		return FALSE
	if(window)
		return FALSE
	var/datum/lobby_terminal/terminal = src_object
	if(!istype(terminal) || !terminal.window || terminal.owner != user.client)
		return FALSE
	process_status()
	if(status < UI_UPDATE)
		return FALSE
	window = terminal.window
	opened_at = world.time
	window.acquire_lock(src)
	if(!window.is_ready())
		window.initialize(
			strict_mode = TRUE,
			fancy = FALSE,
			assets = list(
				get_asset_datum(/datum/asset/simple/tgui),
			))
	else
		window.send_message("ping")
	send_assets()
	window.send_message("update", get_payload(
		with_data = TRUE,
		with_static_data = TRUE))
	SStgui.on_open(src)
	return TRUE

/**
 * Only the owner's new_player body may use the terminal. Anything else closes it, which is
 * what stops SStgui.on_transfer() from carrying the lobby onto a freshly spawned body.
 */
/datum/ui_state/lobby_terminal

GLOBAL_DATUM_INIT(lobby_terminal_state, /datum/ui_state/lobby_terminal, new)

/datum/ui_state/lobby_terminal/can_use_topic(src_object, mob/user)
	var/datum/lobby_terminal/terminal = src_object
	if(!istype(terminal) || !istype(user, /mob/dead/new_player) || !user.client || user.client != terminal.owner)
		return UI_CLOSE
	return UI_INTERACTIVE

/datum/lobby_terminal/ui_state(mob/user)
	return GLOB.lobby_terminal_state

/datum/lobby_terminal/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new /datum/tgui/lobby_terminal(user, src, "LobbyTerminal")
		if(!ui.open())
			qdel(ui)
			return
		src.ui = ui

/datum/lobby_terminal/ui_close(mob/user)
	. = ..()
	ui = null
	visible = FALSE
	hide_control()

/datum/lobby_terminal/ui_assets(mob/user)
	return list(get_asset_datum(/datum/asset/simple/namespaced/lobby_terminal))

/datum/lobby_terminal/ui_static_data(mob/user)
	var/list/data = list()
	data["wiki"] = !!CONFIG_GET(string/wikiurl)
	data["localhost_admin"] = !!(user.client?.is_localhost() && check_rights_for(user.client, R_SERVER))
	data["port"] = null
	data["bezel"] = lobby_terminal_bezel_spec()
	merge_section(data, yard_static(user))
	return data

/datum/lobby_terminal/ui_data(mob/user)
	var/list/data = list()
	shell_data(user, data)
	data["saves"] = saved_ships_data()
	merge_section(data, crews_data(user))
	merge_section(data, yard_data(user))
	merge_section(data, housing_data(user))
	merge_section(data, char_data(user))
	return data

/// Copies a section's keys into the payload. Sections may return null.
/datum/lobby_terminal/proc/merge_section(list/data, list/section)
	if(!islist(section))
		return
	for(var/key in section)
		data[key] = section[key]

/datum/lobby_terminal/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/user = ui.user
	if(!istype(user, /mob/dead/new_player) || user.client != owner)
		return FALSE
	var/prefix = copytext(action, 1, 6)
	if(prefix == "crew_")
		return crews_act(action, params, user)
	if(prefix == "yard_")
		return yard_act(action, params, user)
	if(prefix == "home_")
		return housing_act(action, params, user)
	if(prefix == "char_")
		// Same guard as tg's character window: no prefs edits before the preference assets exist.
		if(!user.client?.prefs || SSearly_assets.initialized != INITIALIZATION_INNEW_REGULAR)
			return FALSE
		return char_act(action, params, user)
	return shell_act(action, params, user)
