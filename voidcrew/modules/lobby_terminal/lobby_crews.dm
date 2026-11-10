/**
 * CREWS section of the dock terminal (package P2).
 *
 * Lists every joinable crew and runs the direct join path: SIGN ON, CODE, APPLY and PING.
 * This replaces select_job_on_ship()'s popups while the terminal is up. The classic
 * ShipJoinMenu stays as the fallback and is not touched.
 *
 * Every action re-validates on the server. Refs only resolve against get_joinable_ships()
 * and that ship's job_slots, never a bare locate().
 */

/// Ping cooldown, the same as ship_join_menu.dm's SHIP_JOIN_PING_COOLDOWN (undefined at the end of that file).
#define LOBBY_CREW_PING_COOLDOWN (2 MINUTES)
/// One application per ckey per this long, across every ship.
#define LOBBY_CREW_APPLY_COOLDOWN (10 SECONDS)
/// How long a cached job eligibility answer (ban, playtime) is trusted.
#define LOBBY_CREW_JOB_CHECK_TTL (5 MINUTES)

/datum/lobby_terminal
	/// REF(job) = list(ok, world.time checked). Eligibility can query the ban DB and sleep, so it never runs inside ui_data.
	var/list/crew_job_ok = list()
	/// TRUE while an eligibility refresh is running.
	var/crew_jobs_checking = FALSE
	/// Ckey = world.time of the next allowed application. Static, so a reconnect does not reset it.
	var/static/list/crew_apply_cooldowns = list()
	/// REF(ship) = md5 of the join code last seen, so a code change wipes everyone's wrong-code count.
	var/static/list/crew_code_seen = list()
	/// Shared instance of the old join menu, only to reach its static ping cooldown list.
	var/static/datum/ship_join_menu/crew_ping_menu

/datum/lobby_terminal/crews_data(mob/user)
	var/list/crews = list()
	var/ckey = user?.ckey
	var/list/to_check
	for(var/obj/structure/overmap/ship/ship as anything in get_joinable_ships())
		var/ship_ref = REF(ship)
		var/list/jobs = list()
		for(var/datum/job/job as anything in ship.job_slots)
			var/open = ship.job_slots[job]
			if(open <= 0)
				continue
			var/job_ref = REF(job)
			var/list/cached = crew_job_ok[job_ref]
			if(!cached || world.time - cached[2] > LOBBY_CREW_JOB_CHECK_TTL)
				LAZYOR(to_check, job)
			jobs += list(list(
				"ref" = job_ref,
				"title" = job.title,
				"open" = open,
				"ok" = cached ? cached[1] : TRUE,
			))
		crews += list(list(
			"ref" = ship_ref,
			"name" = ship.name,
			"cls" = ship.source_template?.short_name || "Unknown",
			"crew" = length(ship.manifest),
			"memo" = ship.memo || "",
			"locked" = !!ship.join_password,
			"cleared" = ship.is_password_cleared(ckey),
			"applied" = !isnull(ship.find_crew_application(ckey)),
			"doors" = !!ship.crew_only_airlocks,
			"ping_wait" = CEILING(crew_ping_wait(ckey, ship) / (1 SECONDS), 1),
			"rejoin_wait" = CEILING(cryo_rejoin_wait(ckey, ship) / (1 SECONDS), 1),
			"code_wait" = code_lock_wait(ckey, ship_ref),
			"jobs" = jobs,
		))
	if(to_check && !crew_jobs_checking && istype(user, /mob/dead/new_player))
		crew_jobs_checking = TRUE
		INVOKE_ASYNC(src, PROC_REF(refresh_crew_jobs), user, to_check)
	return list("crews" = crews)

/// Runs the job eligibility checks (ban DB, playtime, account age) off the UI tick and caches the answers.
/datum/lobby_terminal/proc/refresh_crew_jobs(mob/dead/new_player/user, list/jobs)
	for(var/datum/job/job as anything in jobs)
		if(QDELETED(src) || QDELETED(user) || !user.client)
			break
		if(QDELETED(job))
			continue
		var/ok = SSjob.check_job_eligibility(user, job, "Lobby terminal") == JOB_AVAILABLE
		if(ok && user.client)
			ok = job.special_check_latejoin(user.client)
		crew_job_ok[REF(job)] = list(!!ok, world.time)
	crew_jobs_checking = FALSE

/// Deciseconds until this ckey may ping this ship. Both the sender and the ship must be off cooldown.
/datum/lobby_terminal/proc/crew_ping_wait(ckey, obj/structure/overmap/ship/ship)
	var/list/cooldowns = crew_ping_cooldowns()
	return max(0, (cooldowns[ckey] || 0) - world.time, COOLDOWN_TIMELEFT(ship, join_ping_cooldown))

/// The old join menu's static ping cooldown list, shared so the two menus can't be used to double a ping.
/datum/lobby_terminal/proc/crew_ping_cooldowns()
	if(!crew_ping_menu)
		crew_ping_menu = new /datum/ship_join_menu(null)
	return crew_ping_menu.ping_cooldowns

/// Finds a joinable ship by ref. Never a bare locate().
/datum/lobby_terminal/proc/crew_find_ship(ship_ref)
	if(!istext(ship_ref))
		return null
	var/obj/structure/overmap/ship/ship = locate(ship_ref)
	if(!istype(ship) || QDELETED(ship) || !(ship in get_joinable_ships()))
		return null
	return ship

/// Finds the job datum for a ref among this ship's berths.
/datum/lobby_terminal/proc/crew_find_job(obj/structure/overmap/ship/ship, job_ref)
	if(!istext(job_ref))
		return null
	for(var/datum/job/job as anything in ship.job_slots)
		if(REF(job) == job_ref)
			return job
	return null

/datum/lobby_terminal/crews_act(action, list/params, mob/user)
	var/mob/dead/new_player/player = user
	if(!istype(player) || !player.ckey)
		return FALSE
	var/obj/structure/overmap/ship/ship = crew_find_ship(params["ship"])
	if(!ship)
		set_notice("That ship has left.", "warn")
		return TRUE
	switch(action)
		if("crew_sign_on")
			return crew_sign_on(player, ship, params["job"])
		if("crew_code")
			return crew_enter_code(player, ship, params["code"])
		if("crew_apply")
			return crew_apply(player, ship, params["note"])
		if("crew_ping")
			return crew_ping(player, ship)
	return FALSE

/**
 * Port is full: the classic Join button's rule plus the old late join's "first in line"
 * rule, and unlike select_job_on_ship() it actually stops the join. Admins skip it.
 * Puts the player in line and returns TRUE when they have to wait.
 */
/datum/lobby_terminal/proc/crew_port_full(mob/dead/new_player/player)
	if(ckey(player.key) in GLOB.admin_datums)
		return FALSE
	var/relevant_cap
	var/hard_popcap = CONFIG_GET(number/hard_popcap)
	var/extreme_popcap = CONFIG_GET(number/extreme_popcap)
	if(hard_popcap && extreme_popcap)
		relevant_cap = min(hard_popcap, extreme_popcap)
	else
		relevant_cap = max(hard_popcap, extreme_popcap)
	var/over_cap = relevant_cap && living_player_count() >= relevant_cap
	var/behind = length(SSticker.queued_players) && SSticker.queued_players[1] != player
	if(!over_cap && !behind)
		return FALSE
	var/queue_position = SSticker.queued_players.Find(player)
	if(!queue_position)
		SSticker.queued_players += player
		queue_position = length(SSticker.queued_players)
	set_notice("Port is full. You are number [queue_position] in line.", "warn")
	return TRUE

/// The gates SIGN ON checks before and after its sleep. Returns a short denial line, or null.
/datum/lobby_terminal/proc/crew_sign_on_denial(mob/dead/new_player/player, obj/structure/overmap/ship/ship, datum/job/job)
	if(!SSticker?.IsRoundInProgress())
		return "The port is not open yet."
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		return "No berths are being assigned right now."
	if(QDELETED(ship) || !(ship in get_joinable_ships()))
		return "That ship has left."
	if(!job || !(job in ship.job_slots) || ship.job_slots[job] <= 0)
		return "That berth was just taken."
	if(!ship.is_password_cleared(player.ckey))
		return "Their doors are locked."
	if(cryo_rejoin_wait(player.ckey, ship))
		return "You left that crew too recently."
	return null

/datum/lobby_terminal/proc/crew_sign_on(mob/dead/new_player/player, obj/structure/overmap/ship/ship, job_ref)
	var/datum/job/job = crew_find_job(ship, job_ref)
	var/denial = crew_sign_on_denial(player, ship, job)
	if(denial)
		set_notice(denial, "warn")
		return TRUE
	if(crew_port_full(player))
		return TRUE
	var/list/cached = crew_job_ok[REF(job)]
	if(cached && !cached[1])
		set_notice("You aren't cleared for that job.", "warn")
		return TRUE
	if(!try_join_lock(player))
		return FALSE
	INVOKE_ASYNC(src, PROC_REF(crew_finish_sign_on), player, ship, job)
	return TRUE

/// The sleeping half of SIGN ON: eligibility (may hit the ban DB), every gate again, then the spawn. Holds the join lock throughout.
/datum/lobby_terminal/proc/crew_finish_sign_on(mob/dead/new_player/player, obj/structure/overmap/ship/ship, datum/job/job)
	var/player_ckey = player.ckey
	var/eligible = SSjob.check_job_eligibility(player, job, "Lobby terminal sign on") == JOB_AVAILABLE
	if(QDELETED(player) || !player.client || QDELETED(src))
		release_join_lock(player_ckey)
		return
	if(eligible)
		eligible = job.special_check_latejoin(player.client)
	if(!QDELETED(job))
		crew_job_ok[REF(job)] = list(!!eligible, world.time)
	if(!eligible)
		release_join_lock(player_ckey)
		set_notice("You aren't cleared for that job.", "warn")
		return
	var/denial = crew_sign_on_denial(player, ship, job)
	if(denial)
		release_join_lock(player_ckey)
		set_notice(denial, "warn")
		return
	if(crew_port_full(player))
		release_join_lock(player_ckey)
		return
	player.auto_deadmin_on_ready_or_latejoin()
	set_notice("Waking aboard [ship.name] as [job.title].", "ok")
	var/joined = player.AttemptSpawnOnShip(job, ship)
	release_join_lock(player_ckey)
	if(QDELETED(src))
		return
	if(joined)
		// Don't greet them with this if they come back to the lobby later.
		notice = null
	else if(!QDELETED(player) && player.client)
		set_notice("Could not sign on. Try another berth.", "bad")

/datum/lobby_terminal/proc/crew_enter_code(mob/dead/new_player/player, obj/structure/overmap/ship/ship, code)
	if(!ship.join_password || ship.is_password_cleared(player.ckey))
		return TRUE
	var/ship_ref = REF(ship)
	// A new code on the ship wipes everyone's wrong-code count for it.
	var/code_hash = md5(lowertext(ship.join_password))
	if(crew_code_seen[ship_ref] != code_hash)
		crew_code_seen[ship_ref] = code_hash
		clear_code_failures(null, ship_ref)
	if(code_lock_wait(player.ckey, ship_ref))
		set_notice("Too many wrong codes. Wait a minute.", "bad")
		return TRUE
	// Raw on purpose: captains set the code through raw TGUI params, so the attempt stays raw
	// too (as select_job_on_ship() does). It is only compared, never shown or logged.
	var/attempt = trim("[code || ""]", SHIP_JOIN_PASSWORD_MAX_LEN + 1)
	if(!length(attempt))
		return FALSE
	if(!ship.check_join_password(attempt))
		if(note_code_failure(player.ckey, ship_ref))
			set_notice("Too many wrong codes. Wait a minute.", "bad")
		else
			set_notice("Wrong code.", "bad")
		return TRUE
	ship.password_cleared_ckeys[player.ckey] = TRUE
	clear_code_failures(player.ckey, ship_ref)
	log_game("[key_name(player)] entered the join code of ship [ship.name] at the lobby terminal")
	set_notice(null)
	return TRUE

/datum/lobby_terminal/proc/crew_apply(mob/dead/new_player/player, obj/structure/overmap/ship/ship, note)
	if(!ship.join_password || ship.is_password_cleared(player.ckey) || ship.find_crew_application(player.ckey))
		return TRUE
	if(world.time < (crew_apply_cooldowns[player.ckey] || 0))
		set_notice("Wait a moment before applying again.", "warn")
		return TRUE
	// Raw on purpose, as the old menu does (encode = FALSE): the captain's TGUI escapes it,
	// and it is html_encode()d at the one place it reaches chat.
	note = trim("[note || ""]", SHIP_APPLICATION_MESSAGE_MAX_LEN + 1)
	if(!length(note))
		set_notice("Write a note for the captain.", "warn")
		return TRUE
	crew_apply_cooldowns[player.ckey] = world.time + LOBBY_CREW_APPLY_COOLDOWN
	ship.file_crew_application(player, note)
	return TRUE

/// PING CREW: the old join menu's ping, with the same shared cooldowns.
/datum/lobby_terminal/proc/crew_ping(mob/dead/new_player/player, obj/structure/overmap/ship/ship)
	if(ship_has_open_slots(ship))
		return TRUE
	if(crew_ping_wait(player.ckey, ship) > 0)
		return TRUE
	var/list/cooldowns = crew_ping_cooldowns()
	cooldowns[player.ckey] = world.time + LOBBY_CREW_PING_COOLDOWN
	COOLDOWN_START(ship, join_ping_cooldown, LOBBY_CREW_PING_COOLDOWN)
	ship.ship_notify("Someone wants to join [html_encode(ship.name)]. Please open a job slot at the cryogenic oversight console.", "CREW REQUEST", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)
	to_chat(player, span_notice("Ping sent to [html_encode(ship.name)]'s crew."))
	log_game("[key_name(player)] pinged ship [ship.name] to request an open job slot.")
	return TRUE

#undef LOBBY_CREW_PING_COOLDOWN
#undef LOBBY_CREW_APPLY_COOLDOWN
#undef LOBBY_CREW_JOB_CHECK_TTL
