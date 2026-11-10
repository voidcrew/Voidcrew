// HOUSING section of the dock terminal (lobby_terminal). Lists player outposts and moves the player in
// through /mob/dead/new_player/join_outpost() (voidcrew/modules/player_outposts/outpost_residents.dm),
// which stays the authority on admission. Codes go through the shared limiter in _lobby_terminal.dm.

/// How long a ckey waits before asking the same outpost again.
#define LOBBY_HOUSING_REQUEST_COOLDOWN (3 MINUTES)
/// How long a ckey waits between asking any two outposts.
#define LOBBY_HOUSING_REQUEST_GAP (10 SECONDS)

/// Move-in requests: "[ckey]|[outpost ref]" = world.time asked, and "[ckey]" = world.time of the last request anywhere.
GLOBAL_LIST_EMPTY(lobby_housing_requests)

/// Outposts a lobby player can see: loaded and owned.
/datum/lobby_terminal/proc/housing_outposts()
	. = list()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(QDELETED(home) || !home.loaded || !home.founder_ckey)
			continue
		. += home

/// Resolves a client ref only inside the live outpost list.
/datum/lobby_terminal/proc/housing_find(ref)
	if(!istext(ref))
		return null
	var/obj/structure/overmap/dynamic/player_outpost/home = locate(ref) in GLOB.player_outposts
	if(QDELETED(home) || !home.loaded || !home.founder_ckey)
		return null
	return home

/// Limiter key for an outpost's code. The access revision is part of it, so a new code clears old failures.
/datum/lobby_terminal/proc/housing_code_key(obj/structure/overmap/dynamic/player_outpost/home)
	return "outpost:[REF(home)]:[home.resident_access_revision]"

/**
 * Short in-character reason this player can't move in, or null. Mirrors the order of
 * resident_admission_error(). A password outpost the player isn't cleared for reads as
 * null here: the code field is the gate, and join_outpost() checks the code itself.
 */
/datum/lobby_terminal/proc/housing_denial(obj/structure/overmap/dynamic/player_outpost/home, player_key)
	if(!SSticker.IsRoundInProgress())
		return "Opens when the shift starts."
	if(home.resident_mode == "closed")
		return "Not taking residents."
	if(player_key in home.blocked_residents)
		return "You're barred from here."
	var/cleared = home.has_resident_clearance(player_key)
	if(home.dock_mode == OUTPOST_DOCK_MODE_LOCKDOWN && !cleared)
		return "Locked down. Residents only."
	if(home.resident_mode == "approved" && !cleared)
		return "Residents by invitation."
	if(home.resident_mode == "password" && !cleared && !length(home.resident_password))
		return "Not taking residents."
	var/wait = cryo_rejoin_wait(player_key, home)
	if(wait)
		return "Still in cryo for [DisplayTimeText(wait)]."
	if(!home.available_resident_pod())
		return "No free cryopods."
	return null

/// TRUE while this ckey's request to this outpost is still fresh.
/datum/lobby_terminal/proc/housing_asked(obj/structure/overmap/dynamic/player_outpost/home, player_key)
	var/asked_at = GLOB.lobby_housing_requests["[player_key]|[REF(home)]"]
	return asked_at && world.time < asked_at + LOBBY_HOUSING_REQUEST_COOLDOWN

/datum/lobby_terminal/housing_data(mob/user)
	var/player_key = user?.ckey
	var/list/outposts = list()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in housing_outposts())
		outposts += list(list(
			"ref" = REF(home),
			"name" = home.name,
			"mode" = home.resident_mode,
			"residents" = home.active_resident_count(),
			"cleared" = !!home.has_resident_clearance(player_key),
			"denial" = housing_denial(home, player_key),
			"code_wait" = code_lock_wait(player_key, housing_code_key(home)),
			"can_ask" = !!(home.resident_mode == "approved" && SSticker.IsRoundInProgress() && !home.has_resident_clearance(player_key) && !(player_key in home.blocked_residents)),
			"asked" = !!housing_asked(home, player_key),
		))
	return list("outposts" = outposts)

/datum/lobby_terminal/housing_act(action, list/params, mob/user)
	var/mob/dead/new_player/player = user
	if(!istype(player) || !player.ckey)
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/home = housing_find(params["outpost"])
	if(!home)
		set_notice("That outpost is gone.", "warn")
		return TRUE
	switch(action)
		if("home_move_in")
			housing_move_in(player, home, params["code"])
			return TRUE
		if("home_request")
			housing_request(player, home)
			return TRUE
	return FALSE

/// Checks the code against the limiter, then hands off to join_outpost() off the UI tick.
/datum/lobby_terminal/proc/housing_move_in(mob/dead/new_player/player, obj/structure/overmap/dynamic/player_outpost/home, code)
	var/player_key = player.ckey
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		set_notice("No berths are being assigned right now.", "warn")
		return
	var/denial = housing_denial(home, player_key)
	if(denial)
		set_notice(denial, "warn")
		return
	var/attempt = ""
	if(home.resident_mode == "password" && !home.has_resident_clearance(player_key))
		var/lock_key = housing_code_key(home)
		var/wait = code_lock_wait(player_key, lock_key)
		if(wait)
			set_notice("Keypad locked. Try again in [wait] seconds.", "bad")
			return
		attempt = istext(code) ? trim(copytext(code, 1, 65)) : ""
		if(!length(attempt))
			set_notice("Enter the code.", "warn")
			return
		// Exact match, as resident_admission_error() compares it. The code is never echoed.
		if(attempt != home.resident_password)
			if(note_code_failure(player_key, lock_key))
				set_notice("Keypad locked.", "bad")
			else
				set_notice("Wrong code.", "bad")
			return
		clear_code_failures(player_key, lock_key)
	if(!try_join_lock(player))
		set_notice("Already on your way.", "warn")
		return
	set_notice("Moving in at [home.name].", "ok")
	INVOKE_ASYNC(src, PROC_REF(housing_finish_move_in), player, home, attempt, player_key)

/**
 * join_outpost() sleeps (eligibility, appearance). The join lock spans all of it.
 * attempt is never null here, so join_outpost() never opens its own password prompt.
 */
/datum/lobby_terminal/proc/housing_finish_move_in(mob/dead/new_player/player, obj/structure/overmap/dynamic/player_outpost/home, attempt, player_key)
	var/joined = FALSE
	if(!QDELETED(player) && !QDELETED(home))
		joined = player.join_outpost(home, attempt)
	release_join_lock(player_key)
	if(joined || QDELETED(src))
		return
	var/denial = (!QDELETED(home) && player_key) ? housing_denial(home, player_key) : null
	set_notice(denial || "Couldn't move in. Try again.", "warn")

/// INVITE outposts: tells the residents on shift that this player wants to move in.
/datum/lobby_terminal/proc/housing_request(mob/dead/new_player/player, obj/structure/overmap/dynamic/player_outpost/home)
	var/player_key = player.ckey
	if(home.resident_mode != "approved" || !SSticker.IsRoundInProgress() || home.has_resident_clearance(player_key) || (player_key in home.blocked_residents))
		return
	if(housing_asked(home, player_key))
		return
	var/last = GLOB.lobby_housing_requests[player_key]
	if(last && world.time < last + LOBBY_HOUSING_REQUEST_GAP)
		set_notice("Wait a moment.", "warn")
		return
	var/list/recipients = list()
	for(var/datum/mind/member as anything in home.residents)
		if(QDELETED(member) || !member.current?.client || member.current.stat == DEAD)
			continue
		recipients |= member.current
	if(!length(recipients))
		set_notice("Nobody's home at [home.name].", "warn")
		return
	GLOB.lobby_housing_requests[player_key] = world.time
	GLOB.lobby_housing_requests["[player_key]|[REF(home)]"] = world.time
	var/safe_name = html_encode(home.name)
	var/safe_key = html_encode(player.key)
	for(var/mob/resident as anything in recipients)
		to_chat(resident, span_notice("[safe_name] housing office: [safe_key] is asking to move in."))
	log_game("[key_name(player)] asked to move in at outpost [home.name] ([length(recipients)] residents told)")
	set_notice("Request sent to [home.name].", "ok")

#undef LOBBY_HOUSING_REQUEST_COOLDOWN
#undef LOBBY_HOUSING_REQUEST_GAP
