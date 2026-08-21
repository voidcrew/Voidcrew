/**
 * Lobby button that opens the server wiki in the player's browser.
 *
 * Sits at the left end of the bottom button row, next to the poll button. New players
 * spend their first minutes on this screen, so it is the one place a wiki link is
 * guaranteed to be seen before they pick a ship.
 */
/atom/movable/screen/lobby/button/bottom/wiki
	name = "Open the Wiki"
	icon_state = "wiki"
	base_icon_state = "wiki"
	screen_loc = "TOP:-122,CENTER:-54"

/atom/movable/screen/lobby/button/bottom/wiki/SlowInit()
	. = ..()
	//No URL configured means there is nothing to open - grey the button out instead of
	//handing people a button that only ever errors at them.
	if(!CONFIG_GET(string/wikiurl))
		set_button_status(FALSE)

/atom/movable/screen/lobby/button/bottom/wiki/Click(location, control, params)
	. = ..()
	if(!.)
		return
	usr.client?.wiki()

/**
 * Fullscreen static starfield behind the lobby menu, drawn with the overmap's own
 * turf sprite so the lobby keeps its "floating over the star chart" look.
 *
 * The lobby used to sit on a live overmap tile, letting people watch real ships and
 * planets from the title menu (and metagame off it). The lobby anchor now parks over
 * empty space far away from the overmap (see SSovermap.relocate_lobby()); this
 * backdrop supplies the view, with no live tactical information behind it.
 *
 * Instantiated automatically by /datum/hud/new_player/New alongside every other
 * /atom/movable/screen/lobby subtype. always_shown so it does not slide off-screen
 * with the buttons when the lobby menu is collapsed.
 */
/atom/movable/screen/lobby/starfield
	name = "space"
	icon = 'voidcrew/modules/overmap/icons/turf/overmap.dmi'
	icon_state = "overmap"
	screen_loc = "WEST,SOUTH to EAST,NORTH"
	// Below every lobby element AND below cinematics (CINEMATIC_LAYER), so a round-end
	// cinematic still draws over the backdrop for anyone watching from the lobby
	layer = CINEMATIC_LAYER - 1
	always_shown = TRUE

/datum/latejoin_menu/ui_interact(mob/dead/new_player/user, datum/tgui/ui)
	user.select_ship() //override ui_interact and send to our latejoin menu instead
	return TRUE

/**
 * Latejoin menu - opens the ship join TGUI
 */
/mob/dead/new_player/proc/select_ship()
	var/datum/ship_join_menu/menu = new(src)
	menu.ui_interact(src)

/**
 * Job selection after choosing a ship from the join menu
 */
/mob/dead/new_player/proc/select_job_on_ship(obj/structure/overmap/ship/ship)
	if(!istype(ship))
		return select_ship()

	// Show memo if present
	if(ship.memo)
		var/memo_accept = tgui_alert(src, "Current ship memo: [ship.memo]", "[ship.name] Memo", list("OK", "Cancel"))
		if(memo_accept != "OK")
			return select_ship() // Send them back to ship selection

	// Password gate. Cleared ckeys (the buyer, past crew, invitees) are never asked.
	// encode = FALSE: captains set the password through raw TGUI params, so the attempt
	// must stay raw too or any password with an HTML-special character never matches.
	if(!ship.is_password_cleared(ckey))
		var/attempt = tgui_input_text(src, "This ship is password-locked by its crew. Enter the join password.", "[ship.name] - Join Password", max_length = SHIP_JOIN_PASSWORD_MAX_LEN, encode = FALSE, timeout = 60 SECONDS)
		if(isnull(attempt) || QDELETED(ship))
			return select_ship() // Cancelled, timed out, or the ship died mid-prompt
		if(!ship.check_join_password(attempt))
			to_chat(src, span_warning("Incorrect join password for [ship.name]."))
			return select_ship()
		ship.password_cleared_ckeys[ckey] = TRUE

	// Build job choices
	var/list/job_choices = list()
	for(var/datum/job/job as anything in ship.job_slots)
		if(ship.job_slots[job] < 1)
			continue
		job_choices["[job.title] ([ship.job_slots[job]] positions)"] = job

	if(!job_choices.len)
		to_chat(usr, span_danger("There are no jobs available on this ship!"))
		return select_ship() // Send them back to ship selection

	var/datum/job/selected_job = job_choices[tgui_input_list(src, "Select your role.", "[ship.name]", job_choices)]
	if(!selected_job)
		return select_ship() // Send them back to ship selection

	if(!SSticker?.IsRoundInProgress())
		to_chat(usr, span_danger("The round is either not ready, or has already finished..."))
		return

	var/relevant_cap
	var/hpc = CONFIG_GET(number/hard_popcap)
	var/epc = CONFIG_GET(number/extreme_popcap)
	if(hpc && epc)
		relevant_cap = min(hpc, epc)
	else
		relevant_cap = max(hpc, epc)

	if(SSticker.queued_players.len && !(ckey(key) in GLOB.admin_datums))
		if((living_player_count() >= relevant_cap) || (src != SSticker.queued_players[1]))
			to_chat(usr, span_warning("Server is full."))

	AttemptSpawnOnShip(selected_job, ship)

/// Flag to prevent double-clicking ship spawn
/mob/dead/new_player/var/spawning_ship = FALSE

/**
 * Callback when player confirms their hull, theme and upgrade selections.
 * The selector has already handled the hull unlock and part deduction.
 */
/mob/dead/new_player/proc/on_upgrades_confirmed(datum/map_template/shuttle/voidcrew/template, list/upgrade_selections, datum/ship_theme/selected_theme)
	if(!template)
		return select_ship() // Cancelled, return to menu

	spawn_ship_with_upgrades(template, upgrade_selections, selected_theme)

/**
 * Actually spawn the ship with the given upgrade selections and theme
 */
/mob/dead/new_player/proc/spawn_ship_with_upgrades(datum/map_template/shuttle/voidcrew/template, list/upgrade_selections, datum/ship_theme/selected_theme)
	if(!template)
		return select_ship()

	// Prevent double-click spawning
	if(spawning_ship)
		to_chat(src, span_warning("Your ship is already being prepared. Please wait..."))
		return
	spawning_ship = TRUE

	to_chat(src, span_notice("Your [template.name] is being prepared. Please be patient!"))
	var/obj/structure/overmap/ship/target = SSshuttle.create_ship(template, upgrade_selections, selected_theme)
	if(!istype(target))
		spawning_ship = FALSE
		// A refusal at the map-volume ceiling is transient - transit space frees up in
		// seconds as ships move. Say so instead of sending the buyer to the admins for
		// a condition that fixes itself.
		if(SSmapping.at_z_level_ceiling())
			to_chat(src, span_warning("The shipyard is congested right now - hull assembly space frees up as ships move. Try again in a minute."))
		else
			to_chat(src, span_danger("There was an error loading the ship. Please contact admins!"))
		return select_ship()

	SSblackbox.record_feedback("tally", "ship_purchased", 1, template.name)

	// The buyer decides up front whether their hull is locked. Held off the join menu
	// while they type, or a stranger can take the captain's seat mid-prompt; the input
	// times out so a disconnect can't leave the hull closed forever.
	target.password_cleared_ckeys[ckey] = TRUE
	target.joining_allowed = FALSE
	var/wanted_password = tgui_input_text(src, "Set a join password for your ship, or leave blank to let anyone join. You can change it later from Ship Management; crew you invite never need it.", "[target.name] - Join Password", max_length = SHIP_JOIN_PASSWORD_MAX_LEN, encode = FALSE, timeout = 60 SECONDS)
	if(!QDELETED(target))
		target.joining_allowed = TRUE
		if(wanted_password)
			target.set_join_password(wanted_password, src)

	if(!AttemptSpawnOnShip(target.job_slots[1], target))
		to_chat(src, span_danger("Ship spawned, but you were unable to be spawned. You can likely try to spawn in the ship through joining normally, but if not, please contact an admin."))

/**
 * Spawns a free hull for a player the fleet has no room for, and seats them on it as
 * its officer.
 *
 * This is the same roll the roundstart fleet uses - a real modular hull with a theme
 * and a module in every slot, not a Pill - because someone who joins after the fleet
 * filled up or got destroyed should not be flying something worse than the round
 * started on. Nobody pays for it: on a fresh server nobody has the parts to, and a
 * player with no seat and no hull has no round.
 *
 * The gate is re-checked here rather than trusted from ui_act, since the fleet can
 * open up in the time it takes someone to read the menu.
 */
/mob/dead/new_player/proc/requisition_free_hull()
	if(!SSticker?.IsRoundInProgress())
		to_chat(src, span_danger("The round is either not ready, or has already finished..."))
		return

	if(!can_requisition_hull(src))
		to_chat(src, span_warning("A position opened up in the fleet while you were deciding. Join a crew instead."))
		return select_ship()

	// Prevent double-click spawning
	if(spawning_ship)
		to_chat(src, span_warning("Your ship is already being prepared. Please wait..."))
		return
	spawning_ship = TRUE

	to_chat(src, span_notice("No ship in the fleet has room for you. A hull is being prepared - please be patient!"))
	var/obj/structure/overmap/ship/target = SSovermap.spawn_free_hull(track_as_initial = FALSE)
	if(!istype(target))
		spawning_ship = FALSE
		to_chat(src, span_danger("There was an error loading the ship. Please contact admins!"))
		return select_ship()

	SSblackbox.record_feedback("tally", "ship_requisitioned", 1, target.source_template?.name || "[target.type]")
	log_shuttle("[key_name(src)] requisitioned a free hull: [target.name]")

	if(!AttemptSpawnOnShip(target.job_slots[1], target))
		to_chat(src, span_danger("Ship spawned, but you were unable to be spawned. You can likely try to spawn in the ship through joining normally, but if not, please contact an admin."))

/**
 * Join as the given job
 */
/mob/dead/new_player/proc/AttemptSpawnOnShip(datum/job/job, obj/structure/overmap/ship/joined_ship)
	if(isnull(joined_ship) || isnull(joined_ship.shuttle))
		stack_trace("Tried to spawn ([ckey]) into a null ship! Please report this on Github.")
		return FALSE
	if(SSlag_switch.measures[DISABLE_NON_OBSJOBS])
		alert(src, "An administrator has disabled late join spawning.")
		return FALSE

	if(!joined_ship.job_slots[job])
		to_chat(usr, span_danger("There are no more [job.title] positions available on this ship!"))
		return FALSE

	// Every UI path prompts for this upstream; the check here covers the window where a
	// captain sets a password between the menu opening and the spawn going through.
	if(!joined_ship.is_password_cleared(ckey))
		to_chat(usr, span_warning("[joined_ship.name] is password-locked by its crew."))
		return FALSE

	//Removes a job slot
	joined_ship.job_slots[job]--

	//Remove the player from the join queue if he was in one and reset the timer
	SSticker.queued_players -= src
	SSticker.queue_delay = 4

	if(!SSjob.assign_role(src, job, TRUE))
		//Give back the job slot we took, or it leaks whenever assignment fails (job ban, playtime, etc.)
		joined_ship.job_slots[job]++
		tgui_alert(usr, "There was an unexpected error putting you into your requested job. If you cannot join with any job, you should contact an admin.")
		return FALSE

	var/atom/destination = pick(joined_ship.shuttle.spawn_points)
	if(!destination)
		CRASH("Failed to find a latejoin spawn point.")
	var/mob/living/character = create_character(destination)
	if(!character)
		CRASH("Failed to create a character for latejoin.")
	transfer_character()

	SSjob.equip_rank(character, job, character.client)
	job.after_latejoin_spawn(character)

	SSticker.minds += character.mind
	character.client.init_verbs() // init verbs for the late join
	var/mob/living/carbon/human/humanc
	if(ishuman(character))
		humanc = character //Let's retypecast the var to be human,

	if(humanc) //These procs all expect humans
		joined_ship.manifest_inject(humanc, job)
		GLOB.manifest.inject(humanc)

		// Bind their headset's ship channel to this ship so crew comms follow them off-ship
		var/obj/item/radio/spawned_headset = humanc.ears
		if(istype(spawned_headset))
			spawned_headset.bind_comms_to_ship(joined_ship.shuttle)

		humanc.increment_scar_slot()
		humanc.load_persistent_scars()

		if(GLOB.curse_of_madness_triggered)
			give_madness(humanc, GLOB.curse_of_madness_triggered)

	GLOB.joined_player_list += character.ckey

	if((job.job_flags & JOB_ASSIGN_QUIRKS) && humanc && CONFIG_GET(flag/roundstart_traits))
		SSquirks.AssignQuirks(humanc, humanc.client)

	log_manifest(character.mind.key, character.mind, character, latejoin = TRUE)
	log_shuttle("[character.mind.key] / [character.mind.name] has joined [joined_ship.name] as [job.title]")

	if(joined_ship.deletion_timer)
		joined_ship.end_deletion_timer()

	SEND_GLOBAL_SIGNAL(COMSIG_GLOB_CREWMEMBER_JOINED, character, job.title)

	// Grant captain management action if spawning as captain (officer job)
	if(job.officer && humanc)
		grant_captain_management(humanc, joined_ship)
		// A real captain's arrival ends any acting command over the ship
		joined_ship.clear_acting_captain(humanc)
	else if(humanc)
		// No captain aboard: the joiner holds acting command until one arrives
		joined_ship.make_acting_captain(humanc)

	// Show ship memo after spawn (with a small delay so they're fully loaded in)
	if(joined_ship.memo && humanc)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(show_ship_memo_to_player), humanc, joined_ship), 3 SECONDS)

	// First spawn of the round gets the orientation briefing, a beat after the
	// memo (voidcrew/modules/onboarding/orientation.dm)
	try_show_orientation_briefing(character)

	return TRUE

/**
 * Job availability
 */
/mob/dead/new_player/IsJobUnavailable(rank, obj/structure/overmap/ship/joined_ship, latejoin = FALSE)
	var/datum/job/job = SSjob.get_job(rank)
	if(!job)
		return JOB_UNAVAILABLE_GENERIC
	if(joined_ship.job_slots[job] <= 0)
		return JOB_UNAVAILABLE_SLOTFULL
	var/eligibility_check = SSjob.check_job_eligibility(src, job, "Mob IsJobUnavailable")
	if(eligibility_check != JOB_AVAILABLE)
		return eligibility_check
	if(latejoin && !job.special_check_latejoin(client))
		return JOB_UNAVAILABLE_GENERIC
	return JOB_AVAILABLE
