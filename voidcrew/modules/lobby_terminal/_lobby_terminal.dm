/**
 * # Dock terminal lobby
 *
 * The new-player lobby drawn as a dock terminal: tgui rendered into the `lobby_browser`
 * BROWSER control that sits over the map pane (interface/skin.dmf, window "mapwindow").
 *
 * One /datum/lobby_terminal per client. It owns the unpooled tgui_window bound to that
 * control, the open /datum/tgui, the per-client notice and cached DB values.
 *
 * The classic HUD lobby (/datum/hud/new_player) is still built, unchanged, but its buttons
 * are taken off the screen while the terminal is in charge, so they never show around or
 * before it. If the browser never comes up (for example during a 516 resource download
 * stall), the load timeout puts the classic buttons back as the fallback.
 *
 * Sections: the shell (this file, lobby_tgui.dm, lobby_bezel.dm) declares every section
 * proc below. Section owners override them in their own file without the `proc/` keyword:
 * lobby_crews.dm (crew_* actions), lobby_yard.dm (yard_* actions), lobby_housing.dm
 * (home_* actions) and lobby_character*.dm (char_* actions). Those files sort after this
 * one, so their overrides win.
 */

/// How long to wait for the browser to report itself visible before offering a reload link.
#define LOBBY_TERMINAL_LOAD_TIMEOUT (30 SECONDS)
/// Wrong codes allowed per ckey per lock (a ship or an outpost) before a lockout.
#define LOBBY_CODE_MAX_FAILURES 5
/// How long a code lockout lasts.
#define LOBBY_CODE_LOCKOUT (60 SECONDS)
/// Lockouts in one round for one ckey before admins are told.
#define LOBBY_CODE_ADMIN_NOTICE_LOCKOUTS 3

/client/var/datum/lobby_terminal/lobby_terminal

/// Code failures keyed "[ckey]|[lock key]" = list(failures, locked_until). Keyed by ckey, so a reconnect does not reset it.
GLOBAL_LIST_EMPTY(lobby_code_failures)
/// Lockouts this round per ckey, for the admin notice.
GLOBAL_LIST_EMPTY(lobby_code_lockouts)
/// Ckeys with a join route in flight (sign on, commission, requisition, load, move in). Keyed by ckey so a reconnect cannot double it.
GLOBAL_LIST_EMPTY(lobby_join_locks)

/datum/lobby_terminal
	/// The client this terminal belongs to.
	var/client/owner
	/// Unpooled tgui window bound to the lobby_browser control.
	var/datum/tgui_window/window
	/// The open tgui, if any.
	var/datum/tgui/lobby_terminal/ui
	/// TRUE once the browser has reported itself visible since the last show().
	var/visible = FALSE
	/// Current notice: list("text", "kind" = "ok"/"warn"/"bad", "at" = world.time), or null.
	var/list/notice
	/// Cached poll lamp: 0 none or disabled, 1 open polls, 2 new polls. Filled async at show().
	var/polls_state = 0
	/// Tab the shell asks the client to switch to, and a serial so the client can tell a repeat request apart.
	var/tab_request
	var/tab_request_serial = 0
	/// Load timeout timer id.
	var/load_timer
	/// The skin.dmf BROWSER control the terminal renders into.
	var/control_id = "lobby_browser"

	// CHARACTER section (lobby_character*.dm). Declared here so every owner shares them.
	/// Job category the preview wears (preview only, never saved). Null: the top role.
	var/char_dress
	/// Bumped on every character edit and slot switch, so the client and async work can spot stale state.
	var/char_rev = 0
	/// TRUE once char_open has sent the catalog and the first push to this window.
	var/char_open = FALSE
	/// A native colour pick is waiting on input(): list("key", "slot", "rev"), or null.
	var/list/char_pending_pick
	/// Preview renders: appearance key -> list("[dir]" = base64 png). Owned by lobby_character_preview.dm.
	var/list/char_preview_cache

/datum/lobby_terminal/New(client/owner)
	. = ..()
	src.owner = owner
	window = new /datum/tgui_window(owner, control_id)
	RegisterSignal(window, COMSIG_TGUI_WINDOW_VISIBLE, PROC_REF(on_window_visible))
	RegisterSignal(owner, COMSIG_CLIENT_MOB_LOGIN, PROC_REF(on_mob_login))

/datum/lobby_terminal/Destroy()
	char_save()
	if(owner)
		UnregisterSignal(owner, COMSIG_CLIENT_MOB_LOGIN)
		if(owner.lobby_terminal == src)
			owner.lobby_terminal = null
	if(window)
		UnregisterSignal(window, COMSIG_TGUI_WINDOW_VISIBLE)
	if(ui)
		ui.close(can_be_suspended = FALSE)
	ui = null
	window = null
	owner = null
	return ..()

/// TRUE when the terminal is up and drawing over the map for this client.
/datum/lobby_terminal/proc/is_active()
	return ui && !QDELETED(ui) && visible

/// Opens the terminal over the map. Safe to call again; it reuses an open UI.
/datum/lobby_terminal/proc/show(mob/dead/new_player/user)
	if(!owner || !istype(user) || user.client != owner)
		return
	if(!ui || QDELETED(ui))
		visible = FALSE
		// A fresh page has none of the yard's previews or URL mappings yet.
		yard_mappings_sent = FALSE
		yard_previews_sent = list()
		// Nor the character catalog or its first push.
		char_open = FALSE
	set_classic_lobby(FALSE)
	refresh_polls(user)
	ui_interact(user)
	if(load_timer)
		deltimer(load_timer)
	load_timer = addtimer(CALLBACK(src, PROC_REF(on_load_timeout)), LOBBY_TERMINAL_LOAD_TIMEOUT, TIMER_STOPPABLE)

/// show() one tick later, after the client constructor has finished (as the chat panel does).
/datum/lobby_terminal/proc/show_deferred(mob/dead/new_player/user)
	set waitfor = FALSE
	sleep(1 TICKS)
	if(QDELETED(src) || QDELETED(user) || !owner || user.client != owner)
		return
	show(user)

/// Takes the terminal off the map and closes its UI. The classic HUD (or the game) shows again.
/datum/lobby_terminal/proc/hide()
	char_save()
	visible = FALSE
	if(load_timer)
		deltimer(load_timer)
		load_timer = null
	if(ui && !QDELETED(ui))
		ui.close(can_be_suspended = FALSE) // ui_close() below does the skin work
	else
		hide_control()

/// Skin side of hiding: control off, status bar back.
/datum/lobby_terminal/proc/hide_control()
	if(!owner)
		return
	winset(owner, control_id, "is-visible=false")
	winset(owner, "mapwindow.status_bar", "is-visible=true")

/datum/lobby_terminal/proc/on_window_visible(datum/source, client/client)
	SIGNAL_HANDLER
	if(!ui || QDELETED(ui) || !istype(owner?.mob, /mob/dead/new_player))
		hide_control()
		return
	visible = TRUE
	if(load_timer)
		deltimer(load_timer)
		load_timer = null
	set_classic_lobby(FALSE)
	winset(owner, null, list(
		"[control_id].is-visible" = "true",
		"mapwindow.status_bar.is-visible" = "false",
	))

/**
 * Puts the classic HUD lobby's buttons on or off the owner's screen. The starfield backdrop
 * always stays. Only touches this client's screen, never the shared HUD lists.
 */
/datum/lobby_terminal/proc/set_classic_lobby(shown)
	var/mob/dead/new_player/player = owner?.mob
	if(!istype(player) || !player.hud_used)
		return
	for(var/atom/movable/screen/lobby/element in player.hud_used.static_inventory)
		if(istype(element, /atom/movable/screen/lobby/starfield))
			continue
		if(shown)
			owner.screen |= element
		else
			owner.screen -= element

/// Any mob change. A new_player Login shows the terminal itself (lobby_bezel.dm); anything else hides it.
/datum/lobby_terminal/proc/on_mob_login(datum/source, mob/new_mob)
	SIGNAL_HANDLER
	if(istype(new_mob, /mob/dead/new_player))
		return
	hide()

/datum/lobby_terminal/proc/on_load_timeout()
	load_timer = null
	if(visible || !owner || !istype(owner.mob, /mob/dead/new_player))
		return
	log_tgui(owner, "Lobby terminal did not report visible in time", window = window)
	set_classic_lobby(TRUE)
	to_chat(owner, span_warning("The dock terminal didn't load. <a href='byond://?src=[REF(src)];lobby_reload=1'>Try again</a>."))

/datum/lobby_terminal/Topic(href, list/href_list)
	. = ..()
	if(!href_list["lobby_reload"] || !owner || usr?.client != owner)
		return
	var/mob/dead/new_player/player = owner.mob
	if(!istype(player))
		return
	if(ui && !QDELETED(ui))
		ui.close(can_be_suspended = FALSE)
	show(player)

/// Sets the notice line. kind is "ok" (the CONFIRMED box), "warn" (amber line) or "bad" (red line). Null text clears it.
/datum/lobby_terminal/proc/set_notice(text, kind = "ok")
	if(!text)
		notice = null
	else
		notice = list("text" = "[text]", "kind" = kind, "at" = world.time)
	if(ui && !QDELETED(ui))
		SStgui.update_uis(src)

/// Asks the client to switch tabs ("crews", "shipyard", "housing", "character").
/datum/lobby_terminal/proc/goto_tab(tab)
	tab_request = tab
	tab_request_serial++
	if(ui && !QDELETED(ui))
		SStgui.update_uis(src)

/// Runs the new-poll query once, off the UI tick, and caches the lamp state.
/datum/lobby_terminal/proc/refresh_polls(mob/dead/new_player/user)
	set waitfor = FALSE
	polls_state = 0
	if(!user || is_guest_key(user.key) || !SSdbcore.Connect())
		return
	var/player_ckey = user.ckey
	var/datum/db_query/query_get_new_polls = SSdbcore.NewQuery({"
		SELECT id FROM [format_table_name("poll_question")]
		WHERE (adminonly = 0 OR :isadmin = 1)
		AND Now() BETWEEN starttime AND endtime
		AND deleted = 0
		AND id NOT IN (
			SELECT pollid FROM [format_table_name("poll_vote")]
			WHERE ckey = :ckey
			AND deleted = 0
		)
		AND id NOT IN (
			SELECT pollid FROM [format_table_name("poll_textreply")]
			WHERE ckey = :ckey
			AND deleted = 0
		)
	"}, list("isadmin" = user.client?.holder ? TRUE : FALSE, "ckey" = player_ckey))
	if(!query_get_new_polls.Execute())
		qdel(query_get_new_polls)
		return
	var/has_new = query_get_new_polls.NextRow()
	qdel(query_get_new_polls)
	if(QDELETED(src))
		return
	polls_state = has_new ? 2 : 1

// ---------------------------------------------------------------------------
// Shared helpers for every section
// ---------------------------------------------------------------------------

/**
 * Name of the crew the player would leave by founding a new one (commission, requisition,
 * saved ship), or null when nothing would change. Never prompts.
 */
/datum/lobby_terminal/proc/crew_change_name(mob/user)
	var/datum/voidcrew_crew_record/record = user?.mind?.recover_reputation_crew()
	if(!record || record.leader == user.mind)
		return null
	for(var/datum/team/voidcrew/team in record.teams)
		return team.name
	return "your crew"

/// Seconds left on a code lockout for this ckey and lock key (a ship or outpost ref), 0 when none.
/datum/lobby_terminal/proc/code_lock_wait(ckey, key)
	var/list/entry = GLOB.lobby_code_failures["[ckey]|[key]"]
	if(!entry)
		return 0
	var/left = entry[2] - world.time
	return left > 0 ? CEILING(left / 10, 1) : 0

/// Records a wrong code. Returns TRUE when this failure started a lockout.
/datum/lobby_terminal/proc/note_code_failure(ckey, key)
	var/entry_key = "[ckey]|[key]"
	var/list/entry = GLOB.lobby_code_failures[entry_key]
	if(!entry)
		entry = list(0, 0)
		GLOB.lobby_code_failures[entry_key] = entry
	entry[1]++
	log_game("[key_name(owner)] entered a wrong lobby code for [key] ([entry[1]] in a row)")
	if(entry[1] < LOBBY_CODE_MAX_FAILURES)
		return FALSE
	entry[1] = 0
	entry[2] = world.time + LOBBY_CODE_LOCKOUT
	var/lockouts = (GLOB.lobby_code_lockouts[ckey] || 0) + 1
	GLOB.lobby_code_lockouts[ckey] = lockouts
	log_game("[key_name(owner)] was locked out of lobby codes for [key] (lockout [lockouts] this round)")
	if(lockouts >= LOBBY_CODE_ADMIN_NOTICE_LOCKOUTS)
		message_admins("[key_name_admin(owner)] has been locked out of lobby join codes [lockouts] times this round.")
	return TRUE

/// Clears the failure count after a right code, or for every ckey when a lock's code changes (ckey null).
/datum/lobby_terminal/proc/clear_code_failures(ckey, key)
	if(ckey)
		GLOB.lobby_code_failures -= "[ckey]|[key]"
		return
	var/suffix = "|[key]"
	for(var/entry_key in GLOB.lobby_code_failures.Copy())
		if(copytext(entry_key, -length(suffix)) == suffix)
			GLOB.lobby_code_failures -= entry_key

/**
 * Takes the per-ckey join lock shared by every join route. FALSE when the player is already
 * spawning or another route holds the lock. Every caller must release_join_lock() on every path.
 */
/datum/lobby_terminal/proc/try_join_lock(mob/dead/new_player/user)
	if(!istype(user) || !user.ckey)
		return FALSE
	if(user.spawning || user.spawning_ship || GLOB.lobby_join_locks[user.ckey])
		return FALSE
	GLOB.lobby_join_locks[user.ckey] = world.time
	return TRUE

/datum/lobby_terminal/proc/release_join_lock(ckey)
	GLOB.lobby_join_locks -= ckey

// ---------------------------------------------------------------------------
// Section seams. Empty here; each owner overrides in its own file.
// Data procs return an assoc list merged into ui_data (or null). Act procs get the full
// action name and return TRUE when the UI should update.
// ---------------------------------------------------------------------------

/// CREWS (lobby_crews.dm): data.crews.
/datum/lobby_terminal/proc/crews_data(mob/user)
	return null

/// CREWS actions: crew_sign_on, crew_code, crew_apply, crew_ping.
/datum/lobby_terminal/proc/crews_act(action, list/params, mob/user)
	return FALSE

/// SHIPYARD (lobby_yard.dm): data.account, owned, free_ships, can_requisition, crew_change.
/datum/lobby_terminal/proc/yard_data(mob/user)
	return null

/// SHIPYARD static data: static.catalog, only after yard_open.
/datum/lobby_terminal/proc/yard_static(mob/user)
	return null

/// SHIPYARD actions: yard_open, yard_preview, yard_commission, yard_requisition, yard_load.
/datum/lobby_terminal/proc/yard_act(action, list/params, mob/user)
	return FALSE

/// HOUSING (lobby_housing.dm): data.outposts.
/datum/lobby_terminal/proc/housing_data(mob/user)
	return null

/// HOUSING actions: home_move_in.
/datum/lobby_terminal/proc/housing_act(action, list/params, mob/user)
	return FALSE

/// CHARACTER (lobby_character.dm): data.char_rev only. The char block goes out as one-off pushes (char_push).
/datum/lobby_terminal/proc/char_data(mob/user)
	return null

/**
 * CHARACTER actions (lobby_character.dm): char_open, char_slot, char_set, char_random_name,
 * char_color_pick, char_voice_play, char_role, char_quirk, char_kit, char_kit_color,
 * char_kit_name, char_kit_skin, char_dress, char_turn, char_confirm. The shell has already
 * checked that the player's prefs exist and the preference assets are built.
 */
/datum/lobby_terminal/proc/char_act(action, list/params, mob/user)
	return FALSE

/// CHARACTER: tg's character window changed a preference; push the terminal's copy soon (coalesced).
/datum/lobby_terminal/proc/char_changed()
	return

/// CHARACTER: sends the full char block (and char_static on the first open) as a one-off update.
/datum/lobby_terminal/proc/char_push(mob/user)
	return

/// CHARACTER preview (lobby_character_preview.dm): queue a render of the current look facing dir.
/datum/lobby_terminal/proc/char_preview_request(dir)
	return

/// CHARACTER preview: hash of everything that changes the look, the cache key for renders.
/datum/lobby_terminal/proc/char_appearance_key()
	return null

/// CHARACTER: writes the character slot and the savefile. Also runs from hide() (inside a signal handler) and Destroy(), so it must not sleep and must be safe with no client or prefs.
/datum/lobby_terminal/proc/char_save()
	SHOULD_NOT_SLEEP(TRUE)
	return

/// Saved ships hook (feature/ship-saving overrides it): list of save cards (null entries for empty slots), or null to hide the box.
/datum/lobby_terminal/proc/saved_ships_data()
	return null

/// Saved ships hook: loads the save in that slot. form_new is the crew-leave answer.
/datum/lobby_terminal/proc/load_saved_ship(slot, form_new)
	set_notice("Shipyard records are offline.", "warn")
	return FALSE

#undef LOBBY_TERMINAL_LOAD_TIMEOUT
#undef LOBBY_CODE_MAX_FAILURES
#undef LOBBY_CODE_LOCKOUT
#undef LOBBY_CODE_ADMIN_NOTICE_LOCKOUTS
