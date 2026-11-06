/// Backgrounds: owned by P1.

// The main menu, in the order it shows (spec 5.4)
#define BACKGROUND_ADMIN_MENU_LIST "List players"
#define BACKGROUND_ADMIN_MENU_START "Start a ghost as..."
#define BACKGROUND_ADMIN_MENU_JUMP "Jump to"
#define BACKGROUND_ADMIN_MENU_PROGRESS "Set progress"
#define BACKGROUND_ADMIN_MENU_SETTLE "Complete or fail goal"
#define BACKGROUND_ADMIN_MENU_CLOSE_WARRANT "Close a warrant"
#define BACKGROUND_ADMIN_MENU_MINT_WARRANT "Mint a warrant"
#define BACKGROUND_ADMIN_MENU_DELIVER "Deliver to the Penitentiary"
#define BACKGROUND_ADMIN_MENU_HULLS "Hull counts"
/// Most questions one opening asks before it closes itself: a guard, never reached by hand
#define BACKGROUND_ADMIN_MAX_STEPS 200

/// Set by the admin panel before a convict latejoin: the scenario to use instead of rolling one
/mob/dead/new_player/var/background_forced_scenario

ADMIN_VERB(background_panel, R_ADMIN, "Backgrounds Panel", "List and adjust background players.", ADMIN_CATEGORY_GAME)
	var/datum/background_admin_panel/panel = new(user.mob)
	BLACKBOX_LOG_ADMIN_VERB("Backgrounds Panel")
	panel.run_menu(user.mob)
	qdel(panel)

/**
 * One opening of the Backgrounds Panel by one admin, in the Bounty Panel pattern
 * (voidcrew/modules/bounties/bounty_admin.dm): menu_* procs ask, admin_* procs act on plain
 * arguments and check the admin again, so a test can drive either without an admin client by
 * overriding authorized(), log_action(), tell(), ask_list() and ask_number().
 */
/datum/background_admin_panel
	/// The admin who opened it
	var/mob/admin
	/// Why the last action was refused, or null
	var/error

/datum/background_admin_panel/New(mob/user)
	. = ..()
	admin = user

/datum/background_admin_panel/Destroy()
	admin = null
	return ..()

// ===== CHECKS, LOGS AND PROMPTS =====

/// Whether `user` may use it now: the admin who opened it, still holding R_ADMIN. Checked again after every prompt.
/datum/background_admin_panel/proc/authorized(mob/user)
	return !QDELETED(src) && !isnull(user) && user == admin && check_rights_for(user.client, R_ADMIN)

/datum/background_admin_panel/proc/log_action(mob/user, operation)
	log_admin("[key_name(user)] used the Backgrounds Panel to [operation].")
	message_admins("[key_name_admin(user)] used the Backgrounds Panel to [operation].")

/datum/background_admin_panel/proc/tell(mob/user, message)
	to_chat(user, message)

/// A choice from `options` (the keys of an assoc list, or plain entries), or null if cancelled
/datum/background_admin_panel/proc/ask_list(mob/user, message, title, list/options)
	if(!length(options))
		return null
	return tgui_input_list(user, message, title || "Backgrounds Panel", options)

/// A whole number from `min_value` to `max_value`, or null if cancelled
/datum/background_admin_panel/proc/ask_number(mob/user, message, title, default, max_value, min_value)
	return tgui_input_number(user, message, title || "Backgrounds Panel", default, max_value, min_value)

/// Keeps `text` as the reason in `error` and tells the admin. Returns null, for `return refuse(...)`.
/datum/background_admin_panel/proc/refuse(mob/user, text)
	error = text
	tell(user, span_warning(text))
	return null

// ===== THE MENU =====

/datum/background_admin_panel/proc/run_menu(mob/user)
	var/static/list/menu = list(
		BACKGROUND_ADMIN_MENU_LIST,
		BACKGROUND_ADMIN_MENU_START,
		BACKGROUND_ADMIN_MENU_JUMP,
		BACKGROUND_ADMIN_MENU_PROGRESS,
		BACKGROUND_ADMIN_MENU_SETTLE,
		BACKGROUND_ADMIN_MENU_CLOSE_WARRANT,
		BACKGROUND_ADMIN_MENU_MINT_WARRANT,
		BACKGROUND_ADMIN_MENU_DELIVER,
		BACKGROUND_ADMIN_MENU_HULLS,
	)
	for(var/asked in 1 to BACKGROUND_ADMIN_MAX_STEPS)
		if(!authorized(user))
			return
		var/choice = ask_list(user, summary_text(), "Backgrounds Panel", menu)
		if(!choice || !authorized(user))
			return
		error = null
		switch(choice)
			if(BACKGROUND_ADMIN_MENU_LIST)
				admin_list(user)
			if(BACKGROUND_ADMIN_MENU_START)
				menu_start(user)
			if(BACKGROUND_ADMIN_MENU_JUMP)
				menu_jump(user)
			if(BACKGROUND_ADMIN_MENU_PROGRESS)
				menu_progress(user)
			if(BACKGROUND_ADMIN_MENU_SETTLE)
				menu_settle(user)
			if(BACKGROUND_ADMIN_MENU_CLOSE_WARRANT)
				menu_close_warrant(user)
			if(BACKGROUND_ADMIN_MENU_MINT_WARRANT)
				menu_mint_warrant(user)
			if(BACKGROUND_ADMIN_MENU_DELIVER)
				menu_deliver(user)
			if(BACKGROUND_ADMIN_MENU_HULLS)
				menu_hulls(user)

/// The menu's heading: how many play each background now
/datum/background_admin_panel/proc/summary_text()
	var/list/counts = list()
	for(var/key in BACKGROUND_ALL_KEYS)
		if(key == BACKGROUND_SPACEFARER)
			continue
		var/datum/background/background = background_by_key(key)
		if(background)
			counts += "[background.name]: [length(background_active_minds(key))]"
	return "Active: [jointext(counts, ", ")]."

/// A label -> state list of every state this round (`active_only` leaves out ended ones)
/datum/background_admin_panel/proc/state_choices(active_only = TRUE)
	var/list/choices = list()
	for(var/datum/background_state/state as anything in GLOB.background_states)
		if(active_only && state.ended)
			continue
		var/datum/background/background = state.get_background()
		var/label = "[state.ckey || "no ckey"]: [state.character_name] ([background?.name || state.key])[state.ended ? " (ended)" : ""]"
		choices[background_unique_label(label, choices)] = state
	return choices

/datum/background_admin_panel/proc/ask_state(mob/user, title, active_only = TRUE)
	var/list/choices = state_choices(active_only)
	if(!length(choices))
		return refuse(user, "No background players[active_only ? " are active" : " this round"].")
	var/choice = ask_list(user, "Which player?", title, choices)
	if(!choice || !authorized(user))
		return null
	return choices[choice]

/// `label`, or "label (2)" and so on when `choices` already has it as a key
/proc/background_unique_label(label, list/choices)
	var/candidate = label
	var/count = 1
	while(candidate in choices)
		candidate = "[label] ([++count])"
	return candidate

// ===== LIST =====

/datum/background_admin_panel/proc/admin_list(mob/user)
	if(!authorized(user))
		return FALSE
	var/list/lines = list()
	for(var/datum/background_state/state as anything in GLOB.background_states)
		var/datum/background/background = state.get_background()
		var/datum/mind/mind = state.get_mind()
		var/mob/body = mind?.current
		var/goal = background?.goal_line(state)
		var/list/parts = list(
			"<b>[state.ckey || "no ckey"]</b>",
			state.character_name,
			background?.name || state.key,
		)
		if(state.crime)
			parts += "crime: [state.crime]"
		if(goal)
			parts += "goal: [goal] ([state.progress]/[state.goal_target])"
		parts += "outcome: [state.outcome][state.ended ? " (ended)" : ""]"
		if(body)
			parts += "[ADMIN_VERBOSEJMP(body)] [ADMIN_LOOKUPFLW(body)]"
		lines += jointext(parts, " - ")
	if(!length(lines))
		lines += "Nobody has played a background this round."
	tell(user, boxed_message("<b>Backgrounds</b><br>[jointext(lines, "<br>")]"))
	return TRUE

// ===== START A GHOST =====

/datum/background_admin_panel/proc/menu_start(mob/user)
	var/list/players = list()
	for(var/mob/dead/observer/ghost in GLOB.dead_mob_list)
		if(ghost.client)
			players[background_unique_label("[ghost.key] (ghost)", players)] = ghost
	for(var/mob/dead/new_player/lobby as anything in GLOB.new_player_list)
		if(lobby.client)
			players[background_unique_label("[lobby.key] (lobby)", players)] = lobby
	var/player_choice = ask_list(user, "Who?", "Start a ghost as...", players)
	if(!player_choice || !authorized(user))
		return
	var/list/backgrounds = list()
	for(var/key in BACKGROUND_ALL_KEYS)
		var/datum/background/background = background_by_key(key)
		if(background && key != BACKGROUND_SPACEFARER)
			backgrounds[background.name] = key
	var/background_choice = ask_list(user, "As what?", "Start a ghost as...", backgrounds)
	if(!background_choice || !authorized(user))
		return
	var/key = backgrounds[background_choice]
	var/scenario
	if(key == BACKGROUND_CONVICT)
		var/list/scenarios = list(
			"Cell" = BACKGROUND_CONVICT_SCENARIO_CELL,
			"Massacre" = BACKGROUND_CONVICT_SCENARIO_MASSACRE,
			"Adrift" = BACKGROUND_CONVICT_SCENARIO_ADRIFT,
		)
		var/scenario_choice = ask_list(user, "Which escape?", "Start a ghost as...", scenarios)
		if(!scenario_choice || !authorized(user))
			return
		scenario = scenarios[scenario_choice]
	var/mob/dead/new_player/lobby = admin_send_to_lobby(user, players[player_choice])
	if(!lobby)
		return
	var/datum/background/background = background_by_key(key)
	var/list/options = list()
	for(var/list/entry as anything in background.latejoin_options(lobby))
		var/label = "[entry["name"]][entry["detail"] ? " ([entry["detail"]])" : ""][entry["refusal"] ? " - [entry["refusal"]]" : ""]"
		options[background_unique_label(label, options)] = entry["id"]
	if(!length(options))
		return refuse(user, "[background.name] offers no start right now. [lobby.key] waits in the lobby.")
	var/option_choice = length(options) == 1 ? options[1] : ask_list(user, "Which start?", "Start a ghost as...", options)
	if(!option_choice || !authorized(user))
		return refuse(user, "Cancelled. [lobby.key] waits in the lobby.")
	admin_start(user, lobby, key, options[option_choice], scenario)

/// Returns this player to the lobby (a lobby player stays where they are) and returns the lobby mob
/datum/background_admin_panel/proc/admin_send_to_lobby(mob/user, mob/player)
	if(!authorized(user))
		return null
	if(isnewplayer(player))
		return player
	if(!isobserver(player) || !player.client)
		return refuse(user, "[player] is no longer a ghost with a player.")
	var/player_key = player.key
	player.client.screen.Cut()
	player.client.screen += player.client.void
	var/mob/dead/new_player/lobby = new
	lobby.PossessByPlayer(player_key)
	if(QDELETED(lobby) || !lobby.client)
		qdel(lobby)
		return refuse(user, "[player_key] disconnected.")
	log_action(user, "return [player_key] to the lobby for a background start")
	return lobby

/// Starts this lobby player as `key` through the same latejoin() the join menu uses
/datum/background_admin_panel/proc/admin_start(mob/user, mob/dead/new_player/lobby, key, option_id, scenario)
	if(!authorized(user))
		return FALSE
	var/datum/background/background = background_by_key(key)
	if(!background || QDELETED(lobby))
		return refuse(user, "That start is gone.")
	if(!SSticker.IsRoundInProgress())
		return refuse(user, "The round is not in progress.")
	lobby.background_forced_scenario = scenario
	log_action(user, "start [lobby.key] as [background.name] ([option_id][scenario ? ", scenario [scenario]" : ""])")
	INVOKE_ASYNC(background, TYPE_PROC_REF(/datum/background, latejoin), lobby, option_id)
	return TRUE

// ===== JUMP =====

/datum/background_admin_panel/proc/menu_jump(mob/user)
	var/list/targets = list()
	var/turf/penitentiary = penitentiary_jump_turf()
	if(penitentiary)
		targets["The Penitentiary"] = penitentiary
	var/turf/homestead = homestead_jump_turf()
	if(homestead)
		targets["The homestead"] = homestead
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		var/key = ship.background_key()
		if(!key)
			continue
		var/turf/bridge = ship_bridge_turf(ship)
		if(bridge)
			targets[background_unique_label("Hull: [ship.name] ([background_by_key(key)?.name || key])", targets)] = bridge
	for(var/datum/mind/mind as anything in background_active_minds())
		var/turf/where = get_turf(mind.current)
		if(where)
			targets[background_unique_label("Player: [mind.background_state.character_name] ([mind.key])", targets)] = where
	if(!length(targets))
		return refuse(user, "There is nowhere to jump to.")
	var/choice = ask_list(user, "Where?", "Jump to", targets)
	if(!choice || !authorized(user))
		return
	admin_jump(user, targets[choice], choice)

/datum/background_admin_panel/proc/admin_jump(mob/user, turf/destination, label)
	if(!authorized(user))
		return FALSE
	if(!isturf(destination))
		return refuse(user, "That place is gone.")
	log_action(user, "jump to [label || AREACOORD(destination)]")
	user.abstract_move(destination)
	return TRUE

/// The Penitentiary's arrival landmark, else the middle of its reservation, or null
/proc/penitentiary_jump_turf()
	var/obj/effect/landmark/penitentiary/arrival/arrival = locate() in GLOB.landmarks_list
	if(arrival)
		return get_turf(arrival)
	var/datum/turf_reservation/reservation = GLOB.penitentiary?.reservation
	var/turf/corner = length(reservation?.bottom_left_turfs) ? reservation.bottom_left_turfs[1] : null
	if(!corner)
		return null
	return locate(corner.x + round(reservation.width / 2), corner.y + round(reservation.height / 2), corner.z)

/// The homestead's settler landmark, else the middle of the Frontier surface, or null
/proc/homestead_jump_turf()
	var/obj/effect/landmark/homestead/settler/settler = locate() in GLOB.landmarks_list
	if(settler)
		return get_turf(settler)
	var/surface_z = frontier_surface_z()
	if(!surface_z)
		return null
	return locate(round(world.maxx / 2), round(world.maxy / 2), surface_z)

/// A hull's helm, else its docking port, or null
/proc/ship_bridge_turf(obj/structure/overmap/ship/ship)
	for(var/obj/machinery/computer/helm/helm in ship.helm_consoles)
		return get_turf(helm)
	return get_turf(ship.shuttle)

// ===== GOALS =====

/datum/background_admin_panel/proc/menu_progress(mob/user)
	var/datum/background_state/state = ask_state(user, "Set progress")
	if(!state)
		return
	if(state.goal_target <= 0)
		return refuse(user, "[state.character_name]'s goal has no count.")
	var/amount = ask_number(user, "Progress, 0 to [state.goal_target]:", "Set progress", state.progress, state.goal_target, 0)
	if(isnull(amount) || !authorized(user))
		return
	admin_set_progress(user, state, amount)

/datum/background_admin_panel/proc/admin_set_progress(mob/user, datum/background_state/state, amount)
	if(!authorized(user))
		return FALSE
	if(!state || state.ended)
		return refuse(user, "That background has ended.")
	amount = clamp(round(amount), 0, max(0, state.goal_target))
	var/old = state.progress
	state.progress = amount
	state.refresh_memory()
	log_action(user, "set [state.ckey]'s [state.key] progress from [old] to [amount]")
	return TRUE

/datum/background_admin_panel/proc/menu_settle(mob/user)
	var/datum/background_state/state = ask_state(user, "Complete or fail goal")
	if(!state)
		return
	var/choice = ask_list(user, "[state.character_name]'s goal:", "Complete or fail goal", list("Complete", "Fail"))
	if(!choice || !authorized(user))
		return
	admin_settle(user, state, choice == "Complete")

/datum/background_admin_panel/proc/admin_settle(mob/user, datum/background_state/state, done)
	if(!authorized(user))
		return FALSE
	if(!state || state.ended)
		return refuse(user, "That background has ended.")
	if(!(done ? state.complete() : state.fail()))
		return refuse(user, "That goal is already settled.")
	log_action(user, "[done ? "complete" : "fail"] [state.ckey]'s [state.key] goal")
	return TRUE

// ===== WARRANTS AND THE PENITENTIARY =====

/datum/background_admin_panel/proc/menu_close_warrant(mob/user)
	var/datum/background_state/state = ask_state(user, "Close a warrant", active_only = FALSE)
	if(!state)
		return
	admin_close_warrant(user, state.get_mind())

/datum/background_admin_panel/proc/admin_close_warrant(mob/user, datum/mind/target)
	if(!authorized(user))
		return FALSE
	if(!target)
		return refuse(user, "That mind is gone.")
	if(!background_warrant_for_mind(target))
		return refuse(user, "[target.name] has no open warrant.")
	background_close_warrant(target, "admin")
	log_action(user, "close the warrant on [key_name(target)]")
	return TRUE

/datum/background_admin_panel/proc/menu_mint_warrant(mob/user)
	var/datum/background_state/state = ask_state(user, "Mint a warrant")
	if(!state)
		return
	var/kind = state.key
	if(kind != BACKGROUND_CONVICT && kind != BACKGROUND_PIRATE)
		var/list/kinds = list("As a convict" = BACKGROUND_CONVICT, "As a pirate" = BACKGROUND_PIRATE)
		var/choice = ask_list(user, "[state.character_name] is not a convict or a pirate. Wanted as:", "Mint a warrant", kinds)
		if(!choice || !authorized(user))
			return
		kind = kinds[choice]
	admin_mint_warrant(user, state.get_mind(), kind)

/datum/background_admin_panel/proc/admin_mint_warrant(mob/user, datum/mind/target, kind)
	if(!authorized(user))
		return FALSE
	if(!target)
		return refuse(user, "That mind is gone.")
	if(!background_mint_warrant(target, kind))
		return refuse(user, "No warrant was minted for [target.name].")
	log_action(user, "mint a [kind] warrant on [key_name(target)]")
	return TRUE

/datum/background_admin_panel/proc/menu_deliver(mob/user)
	var/list/captives = list()
	for(var/mob/living/carbon/human/person as anything in GLOB.human_list)
		if(QDELETED(person) || !person.mind?.key)
			continue
		captives[background_unique_label("[person.real_name] ([person.mind.key])[person.stat == DEAD ? " (dead)" : ""]", captives)] = person
	var/choice = ask_list(user, "Who goes to the Penitentiary?", "Deliver to the Penitentiary", captives)
	if(!choice || !authorized(user))
		return
	admin_deliver(user, captives[choice])

/datum/background_admin_panel/proc/admin_deliver(mob/user, mob/living/carbon/human/captive)
	if(!authorized(user))
		return FALSE
	if(QDELETED(captive))
		return refuse(user, "They are gone.")
	if(!penitentiary_take_prisoner(captive, null))
		return refuse(user, "The Penitentiary did not take [captive.real_name].")
	log_action(user, "deliver [key_name(captive)] to the Penitentiary")
	return TRUE

// ===== HULLS =====

/datum/background_admin_panel/proc/menu_hulls(mob/user)
	var/list/kinds = list()
	var/list/lines = list()
	for(var/key in BACKGROUND_ALL_KEYS)
		var/datum/background/hull_start/background = background_by_key(key)
		if(!istype(background))
			continue
		lines += "[background.name]: [GLOB.background_hulls_minted[key] || 0] of [BACKGROUND_MAX_HULLS_PER_KIND] minted"
		kinds["Reset [background.name]"] = key
	tell(user, boxed_message("<b>Background hulls</b><br>[jointext(lines, "<br>")]"))
	var/choice = ask_list(user, "Reset a count?", "Hull counts", kinds)
	if(!choice || !authorized(user))
		return
	admin_reset_hulls(user, kinds[choice])

/datum/background_admin_panel/proc/admin_reset_hulls(mob/user, key)
	if(!authorized(user))
		return FALSE
	if(!key)
		return refuse(user, "No such background.")
	var/old = GLOB.background_hulls_minted[key] || 0
	GLOB.background_hulls_minted[key] = 0
	log_action(user, "reset the [key] hull count from [old] to 0")
	return TRUE

#undef BACKGROUND_ADMIN_MENU_LIST
#undef BACKGROUND_ADMIN_MENU_START
#undef BACKGROUND_ADMIN_MENU_JUMP
#undef BACKGROUND_ADMIN_MENU_PROGRESS
#undef BACKGROUND_ADMIN_MENU_SETTLE
#undef BACKGROUND_ADMIN_MENU_CLOSE_WARRANT
#undef BACKGROUND_ADMIN_MENU_MINT_WARRANT
#undef BACKGROUND_ADMIN_MENU_DELIVER
#undef BACKGROUND_ADMIN_MENU_HULLS
#undef BACKGROUND_ADMIN_MAX_STEPS
