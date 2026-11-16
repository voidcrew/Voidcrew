/**
 * Terminal shell: the header data, the bezel keys and buttons, and the hooks that put the
 * terminal up on a new_player Login.
 *
 * Every bezel action does what the matching classic HUD button does
 * (code/_onclick/hud/new_player.dm). The HUD stays underneath as the fallback.
 */

/// Hide the control before anything else on connect. Whether Dream Seeker keeps skin
/// visibility across a reconnect is not known, so never trust it.
/client/New(TopicData)
	winset(src, "lobby_browser", "is-visible=false")
	return ..()

/mob/dead/new_player/Login()
	. = ..()
	if(!client || client.interviewee)
		return
	if(!client.lobby_terminal)
		client.lobby_terminal = new /datum/lobby_terminal(client)
	client.lobby_terminal.show_deferred(src)

/// The terminal is the join menu: when it is up, the old join paths land on CREWS instead.
/mob/dead/new_player/select_ship()
	var/datum/lobby_terminal/terminal = client?.lobby_terminal
	if(terminal?.is_active())
		terminal.goto_tab("crews")
		return
	return ..()

/// Art spec from the bezel art's bezel.json, or null for the placeholder bezel.
/proc/lobby_terminal_bezel_spec()
	var/static/list/spec
	var/static/checked = FALSE
	if(checked)
		return spec
	checked = TRUE
	var/path = "voidcrew/modules/lobby_terminal/html/bezel.json"
	if(!fexists(path))
		return null
	var/list/decoded = json_decode(file2text(path))
	spec = islist(decoded) ? decoded : null
	return spec

/datum/lobby_terminal/proc/shell_data(mob/dead/new_player/user, list/data)
	var/phase
	var/clock = 0
	if(SSticker.IsPostgame())
		phase = "ended"
	else
		switch(SSticker.current_state)
			if(GAME_STATE_STARTUP)
				phase = "loading"
			if(GAME_STATE_PREGAME)
				phase = "pregame"
			if(GAME_STATE_SETTING_UP)
				phase = "setup"
			if(GAME_STATE_PLAYING)
				phase = "playing"
			else
				phase = "ended"
	if(phase == "playing")
		clock = STATION_TIME_PASSED()
	else if(phase == "loading" || phase == "pregame")
		var/time_left = SSticker.GetTimeLeft()
		if(time_left == -10)
			clock = -1
		else
			clock = max(0, round(time_left / 10))
	data["phase"] = phase
	data["clock"] = clock
	data["online"] = LAZYLEN(GLOB.clients)
	data["ready"] = user.ready == PLAYER_READY_TO_PLAY
	data["prefs_ready"] = SSearly_assets.initialized == INITIALIZATION_INNEW_REGULAR || SSatoms.initialized == INITIALIZATION_INNEW_REGULAR
	data["can_observe"] = SSticker.current_state > GAME_STATE_STARTUP
	data["polls"] = polls_state
	data["queue"] = SSticker.queued_players.Find(user)
	data["queue_go"] = lobby_queue_go(user)
	var/datum/preferences/prefs = user.client?.prefs
	data["char_name"] = (data["prefs_ready"] && prefs) ? "[prefs.read_preference(/datum/preference/name/real_name)]" : ""
	data["admin_ready"] = (user.client?.holder && phase != "playing") ? list(SSticker.totalPlayersReady, SSticker.total_admins_ready, length(GLOB.admins)) : null
	data["notice"] = notice
	data["tab_request"] = tab_request ? list("tab" = tab_request, "serial" = tab_request_serial) : null
	// The start-up screen: 0 already seen this connection, 1 still to play, 2 play now (the terminal is on screen).
	data["boot"] = boot_done ? 0 : (visible ? 2 : 1)

/// world.time the client's display metrics were last logged.
/datum/lobby_terminal/var/metrics_logged_at = -1 MINUTES

/datum/lobby_terminal/proc/shell_act(action, list/params, mob/dead/new_player/user)
	switch(action)
		if("join")
			return act_join(user)
		if("ready")
			return act_ready(user)
		if("observe")
			// The classic path, with the native confirm. The terminal asks in its own window and sends observe_confirm.
			if(SSticker.current_state <= GAME_STATE_STARTUP)
				return FALSE
			INVOKE_ASYNC(user, TYPE_PROC_REF(/mob/dead/new_player, make_me_an_observer))
			return FALSE
		if("observe_confirm")
			if(SSticker.current_state <= GAME_STATE_STARTUP)
				return FALSE
			INVOKE_ASYNC(user, TYPE_PROC_REF(/mob/dead/new_player, make_me_an_observer), TRUE)
			return FALSE
		if("character")
			// The CHARACTER key opens the terminal's own CHARACTER tab (lobby_character.dm).
			goto_tab("character")
			return FALSE
		if("settings")
			var/datum/preferences/preferences = user.client?.prefs
			if(!preferences)
				return FALSE
			if(!(SSearly_assets.initialized == INITIALIZATION_INNEW_REGULAR || SSatoms.initialized == INITIALIZATION_INNEW_REGULAR))
				return FALSE
			preferences.current_window = PREFERENCE_TAB_GAME_PREFERENCES
			preferences.update_static_data(user)
			preferences.ui_interact(user)
			return FALSE
		if("wiki")
			if(CONFIG_GET(string/wikiurl))
				user.client?.wiki()
			return FALSE
		if("polls")
			if(!polls_state)
				return FALSE
			user.handle_player_polling()
			// The NEW mark clears once the player has voted: look again a little later.
			addtimer(CALLBACK(src, PROC_REF(recheck_polls)), 20 SECONDS, TIMER_UNIQUE)
			addtimer(CALLBACK(src, PROC_REF(recheck_polls)), 90 SECONDS, TIMER_UNIQUE)
			return FALSE
		if("manifest")
			user.ViewManifest()
			return FALSE
		if("changelog")
			user.client?.changelog()
			return FALSE
		if("start_now")
			if(!user.client?.is_localhost() || !check_rights_for(user.client, R_SERVER))
				return FALSE
			SSticker.start_immediately = TRUE
			if(SSticker.current_state == GAME_STATE_STARTUP)
				set_notice("Starting as soon as the port opens.", "warn")
			return TRUE
		if("dismiss")
			// With at, only the notice set at that time: a notice that clears itself never takes a newer one with it.
			if(!notice)
				return FALSE
			if(!isnull(params["at"]) && text2num(params["at"]) != notice["at"])
				return FALSE
			notice = null
			return TRUE
		if("boot_done")
			// LOGIN on the start-up screen. Logged once per connection, to tell whether clients get its sound.
			if(boot_done)
				return FALSE
			boot_done = TRUE
			var/sound_state = params["sound"]
			if(!(sound_state in list("running", "suspended", "none")))
				sound_state = "unknown"
			log_tgui(user, "Lobby start-up screen: sound [sound_state], [clamp(text2num(params["clips"]) || 0, 0, 99)] sounds loaded, dark for [clamp(text2num(params["wait"]) || 0, 0, 999999)] ms[params["failed"] ? ", stepped aside on an error" : ""]", window = window)
			return TRUE
		if("metrics")
			// Display metrics from the client (Windows scaling, pane size), logged once per load for tuning.
			// A client can send this as often as it likes, so at most once a minute reaches the log.
			if(world.time < metrics_logged_at + 1 MINUTES)
				return FALSE
			metrics_logged_at = world.time
			var/mode = params["mode"] == "bar" ? "bar" : "side"
			log_tgui(user, "Lobby terminal metrics: dpr [text2num(params["dpr"])], pane [text2num(params["w"])]x[text2num(params["h"])], scale [text2num(params["s"])], grid [text2num(params["cols"])]x[text2num(params["rows"])], [mode] mode", window = window)
			return FALSE
	return FALSE

/// JOIN: the popcap queue of the classic Join button, then CREWS. The terminal is the join menu.
/datum/lobby_terminal/proc/act_join(mob/dead/new_player/user)
	if(!SSticker?.IsRoundInProgress())
		set_notice("The port is not open yet.", "warn")
		return TRUE
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		set_notice("No berths are being assigned right now.", "warn")
		return TRUE
	var/relevant_cap
	var/hard_popcap = CONFIG_GET(number/hard_popcap)
	var/extreme_popcap = CONFIG_GET(number/extreme_popcap)
	if(hard_popcap && extreme_popcap)
		relevant_cap = min(hard_popcap, extreme_popcap)
	else
		relevant_cap = max(hard_popcap, extreme_popcap)
	if(SSticker.queued_players.len || (relevant_cap && living_player_count() >= relevant_cap && !(ckey(user.key) in GLOB.admin_datums)))
		if(!SSticker.queued_players.Find(user))
			SSticker.queued_players += user
		to_chat(user, span_danger("[CONFIG_GET(string/hard_popcap_message)]"))
		set_notice("Port is full. You are in line.", "warn")
		return TRUE
	user.auto_deadmin_on_ready_or_latejoin()
	goto_tab("crews")
	return TRUE

/// The popcap the classic Join button checks: the lower of the hard and extreme caps when both are set. 0 = none.
/proc/lobby_relevant_popcap()
	var/hard_popcap = CONFIG_GET(number/hard_popcap)
	var/extreme_popcap = CONFIG_GET(number/extreme_popcap)
	if(hard_popcap && extreme_popcap)
		return min(hard_popcap, extreme_popcap)
	return max(hard_popcap, extreme_popcap)

/// TRUE when the player is first in the popcap queue and a place is free: JOIN reads NOW.
/proc/lobby_queue_go(mob/dead/new_player/user)
	if(!length(SSticker.queued_players) || SSticker.queued_players[1] != user)
		return FALSE
	var/cap = lobby_relevant_popcap()
	return !cap || living_player_count() < cap

/// Looks for unanswered polls again after the player opened the poll window.
/datum/lobby_terminal/proc/recheck_polls()
	var/mob/dead/new_player/player = owner?.mob
	if(!istype(player))
		return
	refresh_polls(player)

/// READY: same as the classic Ready button, and keeps that button's own state in step.
/datum/lobby_terminal/proc/act_ready(mob/dead/new_player/user)
	if(SSticker.current_state > GAME_STATE_PREGAME)
		return FALSE
	var/now_ready = user.ready != PLAYER_READY_TO_PLAY
	if(now_ready)
		user.auto_deadmin_on_ready_or_latejoin()
		user.ready = PLAYER_READY_TO_PLAY
	else
		user.ready = PLAYER_NOT_READY
	var/datum/hud/hud = user.hud_used
	if(hud)
		for(var/atom/movable/screen/lobby/button/ready/ready_button in hud.static_inventory)
			ready_button.ready = now_ready
			ready_button.base_icon_state = now_ready ? "ready" : "not_ready"
			ready_button.update_appearance(UPDATE_ICON)
		SEND_SIGNAL(hud, COMSIG_HUD_PLAYER_READY_TOGGLE)
	return TRUE
