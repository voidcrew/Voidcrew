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
 * Callback when player selects a ship from the catalog
 * The catalog has already handled unlocking/part deduction
 */
/mob/dead/new_player/proc/on_ship_catalog_selection(datum/map_template/shuttle/voidcrew/template)
	if(!template)
		return select_ship() // Cancelled, return to menu

	// Check if this ship has upgrade slots OR themes - if so, open upgrade selector
	// (Theme selection happens in the upgrade selector UI)
	if((template.has_upgrade_slots && length(template.upgrade_slot_ids)) || length(template.available_themes))
		var/datum/callback/cb = CALLBACK(src, PROC_REF(on_upgrades_confirmed))
		var/datum/ship_upgrade_selector/selector = new(src, template, cb)
		selector.ui_interact(src)
		return

	// No upgrades or themes, spawn directly with default theme if available
	var/datum/ship_theme/default_theme = get_default_theme_for_ship(template.type)
	spawn_ship_with_upgrades(template, list(), default_theme)

/**
 * Callback when player confirms upgrade selections
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
		to_chat(src, span_danger("There was an error loading the ship. Please contact admins!"))
		return select_ship()

	SSblackbox.record_feedback("tally", "ship_purchased", 1, template.name)
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

	//Removes a job slot
	joined_ship.job_slots[job]--

	//Remove the player from the join queue if he was in one and reset the timer
	SSticker.queued_players -= src
	SSticker.queue_delay = 4

	if(!SSjob.assign_role(src, job, TRUE))
		tgui_alert(usr, "There was an unexpected error putting you into your requested job. If you cannot join with any job, you should contact an admin.")
		return FALSE

	var/atom/destination = pick(joined_ship.shuttle.spawn_points)
	if(!destination)
		CRASH("Failed to find a latejoin spawn point.")
	var/mob/living/character = create_character(destination)
	if(!character)
		CRASH("Failed to create a character for latejoin.")
	transfer_character()

	// Check for custom slot swap on this job (only applies if the spawning player made the swap)
	var/list/custom_slot_swap = null
	if(joined_ship.shuttle.cryo_console && character.client?.ckey)
		custom_slot_swap = joined_ship.shuttle.cryo_console.get_custom_slot_for_job(job)
		// Only use the swap if this player made it
		if(custom_slot_swap && custom_slot_swap["ckey"] != character.client.ckey)
			custom_slot_swap = null

	SSjob.equip_rank(character, job, character.client)
	job.after_latejoin_spawn(character)

	// Apply custom slot loadout if swapped by this player
	if(custom_slot_swap)
		var/slot_index = custom_slot_swap["slot_index"]
		var/list/custom_loadout = GLOB.custom_slot_manager.get_slot_loadout(character.client.ckey, slot_index)
		if(length(custom_loadout))
			apply_custom_slot_loadout(character, custom_loadout)
			to_chat(character, span_notice("Your custom slot '[custom_slot_swap["slot_name"]]' loadout has been applied."))

	SSticker.minds += character.mind
	character.client.init_verbs() // init verbs for the late join
	var/mob/living/carbon/human/humanc
	if(ishuman(character))
		humanc = character //Let's retypecast the var to be human,

	if(humanc) //These procs all expect humans
		joined_ship.manifest_inject(humanc, job)
		GLOB.manifest.inject(humanc)

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
		var/datum/action/innate/captain_management/captain_action = new(humanc, joined_ship)
		captain_action.Grant(humanc)

	// Show ship memo after spawn (with a small delay so they're fully loaded in)
	if(joined_ship.memo && humanc)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(show_ship_memo_to_player), humanc, joined_ship), 3 SECONDS)

	return TRUE

/**
 * Apply custom slot loadout items to a character
 * This is called after normal job equip when a cryo console has swapped the job to use a custom slot
 */
/proc/apply_custom_slot_loadout(mob/living/carbon/human/character, list/loadout_list)
	if(!istype(character) || !length(loadout_list))
		return FALSE

	var/list/loadout_datums = loadout_list_to_datums(loadout_list)
	if(!length(loadout_datums))
		return FALSE

	var/update = NONE

	for(var/datum/loadout_item/item as anything in loadout_datums)
		// Try to equip each loadout item
		var/obj/item/spawned = new item.item_path(character.loc)
		if(spawned)
			// Try to put in the appropriate slot
			if(!character.equip_to_appropriate_slot(spawned))
				// If can't equip to slot, try backpack storage
				var/stored = FALSE
				if(character.back?.atom_storage)
					stored = character.back.atom_storage.attempt_insert(spawned, character, override = TRUE)
				// If still not stored, put in hands
				if(!stored)
					character.put_in_hands(spawned)

			// Handle any special on_equip behavior
			update |= item.on_equip_item(
				equipped_item = spawned,
				preference_source = character.client?.prefs,
				preference_list = loadout_list,
				equipper = character,
				visuals_only = FALSE,
			)

	if(update)
		character.update_clothing(update)

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
