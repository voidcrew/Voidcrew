/**
 * Ship Join Menu UI
 *
 * TGUI interface for selecting a ship to join or purchasing a new one.
 * Provides clear separation between starting your own ship and joining existing crews.
 */
/datum/ship_join_menu
	/// The player using this menu
	var/mob/dead/new_player/user

/datum/ship_join_menu/New(mob/dead/new_player/player)
	. = ..()
	user = player

/datum/ship_join_menu/Destroy()
	user = null
	return ..()

/datum/ship_join_menu/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ShipJoinMenu")
		ui.open()

/datum/ship_join_menu/ui_state(mob/user)
	return GLOB.always_state

/datum/ship_join_menu/ui_data(mob/user)
	var/list/data = list()

	// Player name for welcome message
	var/used_name = user.client?.prefs?.read_preference(/datum/preference/name/real_name) || "Spacer"
	data["player_name"] = used_name

	// Build list of active ships
	var/list/ships = list()
	for(var/obj/structure/overmap/ship/active_ship as anything in SSovermap.simulated_ships)
		if(isnull(active_ship.shuttle))
			continue
		// Skip ships that aren't accepting crew or have no spawn points
		if(length(active_ship.shuttle.spawn_points) <= 0 || !active_ship.joining_allowed)
			continue
		// Skip NPC ships unless they've been claimed by players
		var/obj/structure/overmap/ship/npc/npc_ship = active_ship
		if(istype(npc_ship) && !npc_ship.player_controlled)
			continue

		var/crew_count = length(active_ship.manifest)
		var/class_name = active_ship.source_template?.short_name || "Unknown Class"

		// Build job list with available slots
		var/list/jobs = list()
		for(var/datum/job/job as anything in active_ship.job_slots)
			var/slots = active_ship.job_slots[job]
			if(slots > 0)
				jobs += list(list(
					"name" = job.title,
					"slots" = slots
				))

		ships += list(list(
			"ref" = REF(active_ship),
			"name" = active_ship.name,
			"class_name" = class_name,
			"crew_count" = crew_count,
			"jobs" = jobs,
			"memo" = active_ship.memo
		))

	data["ships"] = ships
	return data

/datum/ship_join_menu/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(..())
		return TRUE

	. = TRUE

	switch(action)
		if("purchase_ship")
			// Close this menu and open ship catalog
			ui.close()
			var/datum/callback/cb = CALLBACK(user, TYPE_PROC_REF(/mob/dead/new_player, on_ship_catalog_selection))
			var/datum/ship_catalog_ui/catalog = new(user, latejoin = TRUE, selection_callback = cb)
			catalog.ui_interact(user)

		if("select_ship")
			var/ship_ref = params["ship_ref"]
			if(!ship_ref)
				return FALSE

			var/obj/structure/overmap/ship/ship = locate(ship_ref)
			if(!istype(ship))
				to_chat(user, span_warning("That ship is no longer available."))
				return FALSE

			// Verify ship is still accepting crew
			if(!ship.joining_allowed)
				to_chat(user, span_warning("That ship is not accepting new crew members."))
				return FALSE
			// Block unclaimed NPC ships
			var/obj/structure/overmap/ship/npc/npc_ship = ship
			if(istype(npc_ship) && !npc_ship.player_controlled)
				to_chat(user, span_warning("That ship is not accepting new crew members."))
				return FALSE

			if(length(ship.shuttle?.spawn_points) <= 0)
				to_chat(user, span_warning("That ship has no spawn points available."))
				return FALSE

			// Close menu and proceed to job selection
			ui.close()
			user.select_job_on_ship(ship)
