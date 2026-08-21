/obj/item/circuitboard/computer/survey_shuttle_docker
	name = "Orbital survey console board"
	build_path = /obj/machinery/computer/camera_advanced/shuttle_docker/survey
	greyscale_colors = CIRCUIT_COLOR_SECURITY

/obj/machinery/computer/camera_advanced/shuttle_docker/survey
	name = "Orbital survey console"
	desc = "Gather data, earn research points, and control how your ship docks on celestial objects around the void. Surveys only need the ship parked on the same overmap tile as the target, not docked or landed; storms can also be scanned from a few tiles away at reduced yield."
	view_range = 10
	x_offset = 0
	y_offset = -5
	see_hidden = TRUE
	circuit = /obj/item/circuitboard/computer/survey_shuttle_docker
	whitelist_turfs = list()
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/turf/docking_location
	var/icon_scaling_amount = 2
	var/list/blacklisted_mob_types = list(/mob/living/simple_animal/hostile/megafauna)
	var/list/whitelisted_areas = list(/area/overmap_encounter, /area/space)
	var/datum/looping_sound/sonar/soundloop
	var/survey_in_progress = FALSE
	/// The celestial object the in-progress survey was started on
	var/obj/structure/overmap/current_survey_target
	var/datum/survey_research/data
	var/survey_value
	/// Payout multiplier when the survey target sits on a nearby tile instead of
	/// our own (storms only, see get_survey_target). Parking inside stays the
	/// greedy play; scanning from outside is the safe one.
	var/range_survey_value_mult = 0.6
	/// How many overmap tiles out the at-range storm scan reaches. The helm chart
	/// draws severity-scaled glyphs over overlapping cluster contacts, so players
	/// cannot reliably park exactly one tile from a storm's anchor turf - this is
	/// deliberately a short ring, not strict adjacency.
	var/range_survey_distance = 3
	var/survey_timer
	var/banked_points = 0
	var/banked_cash = 0
	var/list/banking = list()
	var/datum/techweb/linked_techweb
	var/theme
	var/attached_to_ship = FALSE
	var/obj/item/disk/survey_data_disk/survey_disk
	var/mapping_enabled = FALSE
	var/mob_sight = FALSE
	var/obj_sight = FALSE
	var/debug_mode = FALSE
	var/list/survey_research_tiers
	var/mode = "shuttle" // can also be "pod"
	var/list/modified_turfs = list()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Initialize(mapload)
	. = ..()

	actions = list()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)
	actions += new /datum/action/innate/camera_off(src)

	set_init_ports()

	ship_port = SSshuttle.get_containing_shuttle(src)

	if (ship_port?.current_ship)

		data = ship_port.current_ship.survey_data

		if(!ship_port.current_ship.survey_console)
			ship_port.current_ship.survey_console = WEAKREF(src)
			attached_to_ship = TRUE
			shuttleId = ship_port.shuttle_id
			shuttlePortId = "[ship_port.shuttle_id]_custom"
			// Registered once here (not per-survey) - cancels in-progress surveys and
			// clears stale custom ports whenever the ship moves
			RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(cancel_survey))

	soundloop = new(src)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/update_survey_data()
	var/obj/structure/overmap/object = get_current_celestial_object()
	if(!object)
		return
	data.update_survey_data(object)
	update_static_data_for_all_viewers()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb))
		if(linked_techweb)
			if(linked_techweb == tool.buffer)
				say("Already linked!")
				return
			unsync_research_servers()

		linked_techweb = tool.buffer
		linked_techweb.survey_data = data
		linked_techweb.connected_machines += src //connect new one
		say("Linked to Server!")
		return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_research_tiers()
	var/list/research_tiers = list("survey_console_simple", "survey_console_advanced", "survey_console_superior", "survey_console_elite")
	var/list/found_tiers = list()
	if(debug_mode)
		mob_sight = TRUE
		obj_sight = TRUE
		view_range = 20
		icon_scaling_amount = 3
		mapping_enabled = TRUE
		found_tiers |= list("advanced", "superior", "elite", "basic")
	else
		if(!linked_techweb)
			return
		for(var/node_id in linked_techweb.researched_nodes)
			if(node_id in research_tiers)
				var/tier_type
				switch(node_id)
					if("survey_console_advanced")
						tier_type = "advanced"
						mapping_enabled = TRUE
						view_range = 10
						icon_scaling_amount = 2
					if("survey_console_superior")
						tier_type = "superior"
						obj_sight = TRUE
						view_range = 15
						icon_scaling_amount = 2.5
					if("survey_console_elite")
						tier_type = "elite"
						mob_sight = TRUE
						view_range = 20
						icon_scaling_amount = 3
					else
						tier_type = "basic"

				found_tiers += tier_type
	return found_tiers

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Destroy()
	unsync_research_servers()
	QDEL_NULL(soundloop)
	if(ship_port?.current_ship)
		var/datum/weakref/ship_link = ship_port.current_ship.survey_console
		if(!ship_link || !ship_link.resolve() || src == ship_link.resolve())
			ship_port.current_ship.survey_console = null
	attached_to_ship = FALSE
	current_survey_target = null
	if(survey_disk)
		survey_disk.forceMove(get_turf(src))
		survey_disk = null
	return ..()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/attack_hand(mob/user, list/modifiers)
	if(!attached_to_ship)
		balloon_alert(user, "can't connect to shuttle.")
		to_chat(user, "Could not connect survey console to the shuttle network. Perhaps there is already a survey console on this ship?")
		return
	ui_interact(user)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/attackby(obj/item/D, mob/user, params)
	if(istype(D, /obj/item/disk))
		if(istype(D, /obj/item/disk/survey_data_disk))
			if(survey_disk)
				to_chat(user, span_warning("A survey data disk is already loaded!"))
				return
			if(!user.transferItemToLoc(D, src))
				to_chat(user, span_warning("[D] is stuck to your hand!"))
				return
			survey_disk = D
		else
			to_chat(user, span_warning("Survey console cannot accept disks in that format."))
			return
		playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 80)
		to_chat(user, span_notice("You insert [D] into \the [src]!"))
		return
	return ..()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SurveyComputer", name)
		ui.open()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_data(mob/user)
	var/list/tgui_data = list()
	var/obj/structure/overmap/celestial_object = get_survey_target()
	survey_research_tiers = get_survey_research_tiers()
	tgui_data["surveyStatus"] = get_survey_status(celestial_object)
	tgui_data["currentCelestialRef"] = celestial_object ? ref(celestial_object) : null
	tgui_data["currentCelestialType"] = celestial_object ? data.get_related_celestial_list(celestial_object.type) : null
	tgui_data["shipMoving"] = ship_port.current_ship.is_still()
	tgui_data["bankedPoints"] = banked_points
	tgui_data["bankedCash"] = banked_cash
	tgui_data["surveyValue"] = get_survey_value(celestial_object)
	tgui_data["surveyAtRange"] = is_survey_at_range(celestial_object)
	// So the UI can state the range rule with the real numbers instead of folklore
	tgui_data["rangeSurveyDistance"] = range_survey_distance
	tgui_data["rangeSurveyPercent"] = round(range_survey_value_mult * 100)
	tgui_data["theme"] = theme
	tgui_data["surveyDataDisk"] = survey_disk ? TRUE : FALSE
	tgui_data["mappingEnabled"] = (istype(celestial_object, /obj/structure/overmap/planet) || istype(celestial_object, /obj/structure/overmap/space_ruin) || istype(celestial_object, /obj/structure/overmap/event/meteor)) ? mapping_enabled : FALSE

	// Everything surveyable from here, for the UI's target picker
	var/turf/ship_turf = ship_port?.current_ship ? get_turf(ship_port.current_ship) : null
	var/list/targets = list()
	for(var/obj/structure/overmap/candidate as anything in get_survey_candidates())
		var/list/values = get_survey_value(candidate)
		var/at_range = is_survey_at_range(candidate)
		targets += list(list(
			"ref" = ref(candidate),
			"name" = candidate.name,
			"status" = get_survey_status(candidate),
			"atRange" = at_range,
			"dist" = (at_range && ship_turf) ? get_dist(ship_turf, get_turf(candidate)) : 0,
			"points" = values ? values["points"] : 0,
			"cash" = values ? values["cash"] : 0,
			"mappable" = (istype(candidate, /obj/structure/overmap/planet) || istype(candidate, /obj/structure/overmap/space_ruin) || istype(candidate, /obj/structure/overmap/event/meteor)) ? mapping_enabled : FALSE,
		))
	tgui_data["surveyTargets"] = targets

	return tgui_data

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_static_data(mob/user)
	. = ..()
	.["surveyData"] = data.tgui_serialize()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	switch(action)
		if("survey")
			survey_celestial_object(ui.user, params["target_ref"])
		if("map")
			playsound(src, 'sound/machines/pda_button/pda_button1.ogg', 100)
			activate_survey_map(ui.user)
		if("printResearch")
			print_survey_notes()
		if("cashOut")
			cash_out()
		if("setTheme")
			theme = params["theme"]
		if("saveData")
			save_survey_data(ui.user)
		if("downloadData")
			download_survey_data(ui.user)
		if("refresh")
			update_survey_data()
		if("eject")
			eject_disk(ui.user)
		if("error")
			playsound(src, 'sound/machines/terminal/terminal_error.ogg', 100)

	return TRUE

/// Overmap types the console refuses to treat as survey targets
/// Callers must treat the returned list as READ-ONLY - both are shared statics.
/// get_current_celestial_object() is now on the per-landing-turf path (see
/// checkLandingTurf()), which runs for every tile of the projected berth on every eye
/// step, so this may not allocate a list per call any more.
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_blacklisted_overmap_types()
	var/static/list/debug_blacklist = list(
		/obj/structure/overmap/ship,
	)
	var/static/list/normal_blacklist = list(
		/obj/structure/overmap/ship,
		/obj/structure/overmap/planet/empty,
	)
	return debug_mode ? debug_blacklist : normal_blacklist

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_current_celestial_object()
	var/list/blacklisted_types = get_blacklisted_overmap_types()
	if (ship_port)
		if (ship_port.current_ship.close_overmap_objects)
			for (var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
				if(!is_type_in_list(object, blacklisted_types))
					return object
	return null

/**
 * Every object a survey could target right now, ordered: objects sharing our
 * overmap tile first (in close-list order), then storms within
 * range_survey_distance tiles sorted nearest-first. Storms are the only at-range
 * targets - the hazard IS the tile, so scanning one without flying into it is
 * the intended counterplay - while landable content (planets, ruins, meteor
 * fields) still requires being on the tile.
 *
 * Only the survey path uses this. The docking paths (refresh, checkLandingTurf)
 * must keep using get_current_celestial_object(), or the docking camera could be
 * aimed into the reservation of a field the ship isn't on.
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_candidates()
	var/list/candidates = list()
	if(!ship_port?.current_ship)
		return candidates
	// Everything sharing our tile - there can be more than one, and the old
	// single-target flow only ever exposed the first
	var/list/blacklisted_types = get_blacklisted_overmap_types()
	for(var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
		if(!is_type_in_list(object, blacklisted_types))
			candidates |= object
	// Storms within the scan ring, nearest first. Same range()-over-turf sweep
	// the sensor contact push uses (ship_sensors.dm)
	var/turf/ship_turf = get_turf(ship_port.current_ship)
	if(!ship_turf)
		return candidates
	var/list/storms_by_dist = list()
	for(var/obj/structure/overmap/event/storm in range(range_survey_distance, ship_turf))
		if(!istype(storm, /obj/structure/overmap/event/electric) && !istype(storm, /obj/structure/overmap/event/emp))
			continue
		storms_by_dist[storm] = get_dist(ship_turf, get_turf(storm))
	sortTim(storms_by_dist, GLOBAL_PROC_REF(cmp_numeric_asc), associative = TRUE)
	for(var/storm in storms_by_dist)
		candidates |= storm
	return candidates

/**
 * The object an unqualified survey click targets: the first on-tile object,
 * else the nearest unsurveyed storm in scan range, else the nearest surveyed
 * one. The UI's target list lets the player override this via target_ref.
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_target()
	var/list/candidates = get_survey_candidates()
	if(!length(candidates))
		return null
	// The candidate list is ordered on-tile first, then storms nearest-first
	var/obj/structure/overmap/first = candidates[1]
	if(!is_survey_at_range(first))
		return first
	for(var/obj/structure/overmap/candidate as anything in candidates)
		if(!is_object_surveyed(candidate))
			return candidate
	return first

/// TRUE when the survey target sits on a neighbouring tile rather than sharing ours
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/is_survey_at_range(obj/structure/overmap/object)
	if(!object || !ship_port?.current_ship)
		return FALSE
	return get_turf(object) != get_turf(ship_port.current_ship)

/// Whether this object already has an entry in the survey records
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/is_object_surveyed(obj/structure/overmap/object)
	var/celestial_type = data.get_related_celestial_list(object.type)
	if(!celestial_type)
		return FALSE
	for(var/datum/surveyed_celestial_object/celestial in data.survey_objects_by_type[celestial_type])
		if(celestial.ref_id == ref(object))
			return TRUE
	return FALSE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_status(obj/structure/overmap/object)
	if(!object || isnull(object))
		return "no-orbit"
	if (survey_in_progress)
		return "in-progress"

	if(!data.get_related_celestial_list(object.type))
		log_runtime("Not found [object.type]")
	if(is_object_surveyed(object))
		return "complete"
	return "unsurveyed"

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/survey_celestial_object(mob/user, target_ref)
	if(survey_in_progress)
		return
	var/obj/structure/overmap/current_object
	if(target_ref)
		// Resolve the client's pick against the live candidate list, never as a raw ref
		for(var/obj/structure/overmap/candidate as anything in get_survey_candidates())
			if(ref(candidate) == target_ref)
				current_object = candidate
				break
	else
		current_object = get_survey_target()
	if(!current_object)
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 100)
		// Say WHY there is nothing to survey - a ship contact sharing the tile is
		// the usual confusion ("why won't it survey this ship?")
		var/has_ship_contact = FALSE
		var/has_empty_space = FALSE
		for(var/obj/structure/overmap/object in ship_port?.current_ship?.close_overmap_objects)
			if(istype(object, /obj/structure/overmap/ship))
				has_ship_contact = TRUE
			else if(istype(object, /obj/structure/overmap/planet/empty))
				has_empty_space = TRUE
		if(has_ship_contact)
			balloon_alert(user, "can't survey ships")
			to_chat(user, span_warning("Vessels are not valid survey targets. The console only surveys celestial objects: planets, signals, storms, and stars."))
		else if(has_empty_space)
			balloon_alert(user, "empty space, nothing to survey")
		else
			balloon_alert(user, "no surveyable celestial object found")
		return

	soundloop.start()
	survey_in_progress = TRUE
	current_survey_target = current_object

	if(istype(current_object, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = current_object
		// Unloaded planets have no data to survey yet - load first, then run the survey
		if (!planet.loaded)
			RegisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_survey_planet_loaded))
			INVOKE_ASYNC(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, load_level))
			return

	survey_timer = addtimer(CALLBACK(src, PROC_REF(complete_survey), current_object), (debug_mode ? 1 : 60) SECONDS, TIMER_STOPPABLE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/on_survey_planet_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_VOIDCREW_PLANET_LOADED)
	// Hop out of signal context via timer so completion shares the normal cancel path
	survey_timer = addtimer(CALLBACK(src, PROC_REF(complete_survey), source), 1, TIMER_STOPPABLE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/complete_survey(obj/structure/overmap/object)
	soundloop.stop()
	survey_in_progress = FALSE
	survey_timer = null
	current_survey_target = null
	if(QDELETED(object))
		return
	var/list/values = get_survey_value(object)
	if(values)
		banked_points += values["points"]
		banked_cash += values["cash"]
	data.update_survey_data(object)
	update_static_data_for_all_viewers()

	// Send signal to ship for mission tracking
	var/celestial_type = data.get_related_celestial_list(object.type)
	if(ship_port?.current_ship && celestial_type)
		SEND_SIGNAL(ship_port.current_ship, COMSIG_VOIDCREW_SURVEY_COMPLETED, celestial_type)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_value(obj/structure/overmap/object)
	if(!object)
		return

	var/point_list = list()

	// The payout lives on the overmap object (survey_value, see _overmap.dm) rather than
	// in a table keyed by type name here - almost nothing spawns as its family's base
	// type, so storm severities, planet terrains, fixed-gas nebulas and star classes all
	// used to fall through to nothing. 0 is anything that isn't a celestial body.
	var/points = object.survey_value
	var/cash = object.survey_value

	if(!points)
		point_list["cash"] = 0
		point_list["points"] = 0
		return point_list

	// Extra rewards for being the first to survey an object
	if (!object.surveyed)
		cash *= 1.2
		points *= 1.2

	if("elite" in survey_research_tiers)
		cash *= 2
		points *= 2
	else if("superior" in survey_research_tiers)
		cash *= 1.5
		points *= 1.5
	else if("advanced" in survey_research_tiers)
		cash *= 1.2
		points *= 1.2

	// Scanning a storm from a neighbouring tile is safe, so it pays less
	if(is_survey_at_range(object))
		cash *= range_survey_value_mult
		points *= range_survey_value_mult

	point_list["cash"] = cash
	point_list["points"] = points
	return point_list

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/cancel_survey()
	SIGNAL_HANDLER

	if(survey_in_progress)
		// Unregister from the object the survey actually started on - the ship has
		// already moved, so get_current_celestial_object() may be null or different
		if(istype(current_survey_target, /obj/structure/overmap/planet))
			UnregisterSignal(current_survey_target, COMSIG_VOIDCREW_PLANET_LOADED)
		if(survey_timer)
			deltimer(survey_timer)
			survey_timer = null
		soundloop.stop()
		playsound(src, 'sound/machines/terminal/terminal_error.ogg', 50)
		survey_in_progress = FALSE
		current_survey_target = null
	remove_old_ports(my_port)

/// Copies every surveyed celestial from one survey datum into another, matching entries by ref_id
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/transfer_survey_data(datum/survey_research/source, datum/survey_research/destination)
	if(!source || !destination)
		return

	for(var/type_key in source.survey_objects_by_type)
		var/list/source_list = source.survey_objects_by_type[type_key]
		var/list/destination_list = destination.survey_objects_by_type[type_key]
		for(var/datum/surveyed_celestial_object/celestial_data as anything in source_list)
			var/datum/surveyed_celestial_object/celestial
			for(var/datum/surveyed_celestial_object/existing_celestial as anything in destination_list)
				if(existing_celestial.ref_id == celestial_data.ref_id)
					celestial = existing_celestial
					break
			if(!celestial)
				celestial = new celestial_data.type
			celestial_data.copy(celestial)
			destination_list |= celestial

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/save_survey_data(mob/user)
	if(!survey_disk || !data)
		return

	transfer_survey_data(data, survey_disk.data)
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 40)
	if(user)
		balloon_alert(user, "data saved to disk")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/download_survey_data(mob/user)
	if(!survey_disk || !data)
		return

	transfer_survey_data(survey_disk.data, data)
	update_static_data_for_all_viewers()
	playsound(src, 'sound/machines/high_tech_confirm.ogg', 40)
	if(user)
		balloon_alert(user, "data downloaded from disk")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/eject_disk(mob/user)
	if(!survey_disk)
		return
	survey_disk.forceMove(get_turf(src))
	survey_disk = null
	playsound(src, 'sound/machines/eject.ogg', 40)
	if(user)
		balloon_alert(user, "disk ejected")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/activate_survey_map(mob/user)
	refresh()
	if(length(ship_port.current_ship.close_overmap_objects) == 0)
		balloon_alert(user, "ship is not in orbit!")
		return
	if(!can_use(user))
		return
	if(isnull(user.client))
		return
	if(!QDELETED(current_user))
		to_chat(user, span_warning("The console is already in use!"))
		return
	var/mob/living/L = user
	if(!eyeobj)
		CreateEye()
	if(!eyeobj) //Eye creation failed
		return

	// Use the docking_location set by refresh() for camera placement
	var/turf/camera_location = docking_location
	if(!camera_location)
		camera_location = eyeobj.loc

	give_eye_control(L)
	eyeobj.setLoc(camera_location)
	// override - opening the map again before docking/undocking re-registers these
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(docked), override = TRUE)
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(undocked), override = TRUE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/print_survey_notes()
	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 60)
	new /obj/item/research_notes/loot/custom(src.loc, banked_points, "survey results")
	banked_points = 0

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/cash_out()
	if(banked_cash <= 0)
		return

	var/remaining_amount = banked_cash
	banked_cash = 0

	var/static/list/bill_denominations = list(
		/obj/item/stack/spacecash/c10000 = 10000,
		/obj/item/stack/spacecash/c1000 = 1000,
		/obj/item/stack/spacecash/c500 = 500,
		/obj/item/stack/spacecash/c200 = 200,
		/obj/item/stack/spacecash/c100 = 100,
		/obj/item/stack/spacecash/c50 = 50,
		/obj/item/stack/spacecash/c20 = 20,
		/obj/item/stack/spacecash/c10 = 10,
		/obj/item/stack/spacecash/c1 = 1,
	)

	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 60)
	playsound(src, 'sound/items/handling/paper_drop.ogg', 60)

	for(var/bill_type in bill_denominations)
		var/bill_value = bill_denominations[bill_type]
		while(remaining_amount >= bill_value)
			remaining_amount -= bill_value
			new bill_type(loc)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/checkLandingTurf(turf/T, list/overlappers)
	. = ..()

	if(!T)
		return SHUTTLE_DOCKER_BLOCKED

	// Reserved z-levels stay off-limits outright. There used to be an exception for the
	// orbited space ruin's own reservation; ruins and asteroid fields are map-zone tenants
	// now and never sit on a ZTRAIT_RESERVED level, so nothing a player can legally land
	// on is behind this gate any more. Their own co-tenant scoping is the footprint test
	// in checkLandingSpot().
	if(SSmapping.level_has_any_trait(T.z, locked_traits))
		return SHUTTLE_DOCKER_BLOCKED

	// The gate above evaporated for packed sites - lattice levels carry ZTRAIT_MINING, none
	// of locked_traits - and checkLandingSpot()'s footprint test only judges the EYE's own
	// tile, while this proc is called for every tile of the projected berth. Without this
	// the only thing between a hull and the neighbour's slot is /area/misc/cordon failing
	// the whitelisted_areas test below, i.e. the cordon's area type. A site with no
	// footprint is unscoped and behaves exactly as it did before packing.
	var/datum/map_footprint/site_footprint = get_current_site_footprint()
	if(site_footprint && !site_footprint.contains_turf(T))
		return SHUTTLE_DOCKER_BLOCKED

	var/allowed_mob = TRUE
	for(var/mob in T.contents)
		for(var/bad_mob in blacklisted_mob_types)
			if(istype(mob, bad_mob))
				allowed_mob = FALSE
	if(allowed_mob == FALSE)
		return SHUTTLE_DOCKER_BLOCKED_BY_MOB

	// Won't land on any area that isn't set in our whitelist
	var/allowed_area = FALSE

	for (var/whitelisted_area in whitelisted_areas)
		if (istype(get_area(T), whitelisted_area))
			allowed_area = TRUE

	if(allowed_area == FALSE)
		return SHUTTLE_DOCKER_BLOCKED_BY_AREA


/**
 * The slot the orbited site occupies on its z-level, or null when it has none.
 *
 * This replaced turf_in_current_ruin_reservation(), which let the custom-docking gate make
 * an exception for turfs inside the orbited space ruin's turf reservation. Ruins and
 * asteroid fields are map-zone tenants now, so none of them sits on a ZTRAIT_RESERVED
 * level and the exception has nothing left to grant - but their level IS shared with up to
 * three co-tenants, separated by a strip of cordon the camera eye passes straight through,
 * which is what this scopes. See /datum/map_footprint.
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_current_site_footprint()
	var/obj/structure/overmap/celestial = get_current_celestial_object()
	return celestial?.get_interior_footprint()

/**
 * Keeps the survey eye off a co-tenant's ground.
 *
 * checkLandingSpot() refuses to DESIGNATE outside the orbited site, but the eye itself was
 * never bounded - and with the research-tier mapping upgrades this console grants (mob_sight,
 * obj_sight, see_hidden) an operator who scrolls across the cordon reads exactly who is
 * aboard next door. A five-turf gutter of /turf/cordon stops air, sight, bullets and
 * movement; it does not stop a camera eye.
 *
 * The rule is "never somebody else's", not "only mine": inside our own footprint is the fast
 * path, and anything the site resolver cannot place - the gutter, raw space, a site with
 * neither footprint nor reservation - stays reachable, so no console can be wedged by a
 * lookup that comes back empty. Overrides the TRUE-by-default hook on the base console type,
 * so upstream navigation, syndicate, whiteship and caravan consoles keep their full reach.
 */
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/eye_may_enter(turf/destination)
	if(!destination)
		return FALSE
	var/obj/structure/overmap/celestial = get_current_celestial_object()
	if(isnull(celestial))
		return TRUE
	var/datum/map_footprint/site_footprint = get_current_site_footprint()
	if(site_footprint?.contains_turf(destination))
		return TRUE
	var/obj/structure/overmap/owner = SSovermap_zones?.get_overmap_object_for_turf(destination)
	return isnull(owner) || owner == celestial

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/checkLandingSpot()
	var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
	var/turf/eyeturf = get_turf(the_eye)
	if(!eyeturf)
		return SHUTTLE_DOCKER_BLOCKED
	if(!eyeturf.z)
		return SHUTTLE_DOCKER_BLOCKED
	if(SSmapping.level_has_any_trait(eyeturf.z, locked_traits))
		return SHUTTLE_DOCKER_BLOCKED
	// The designated landing site has to be on the object we are actually orbiting, not on
	// whoever is sharing its z-level. A site with no footprint is unscoped and keeps the
	// behaviour it had before packing.
	var/datum/map_footprint/site_footprint = get_current_site_footprint()
	if(site_footprint && !site_footprint.contains_turf(eyeturf))
		return SHUTTLE_DOCKER_BLOCKED

	. = SHUTTLE_DOCKER_LANDING_CLEAR
	var/list/bounds = shuttle_port.return_coords(the_eye.x - x_offset, the_eye.y - y_offset, the_eye.dir)
	var/list/overlappers = SSshuttle.get_dock_overlap(bounds[1], bounds[2], bounds[3], bounds[4], the_eye.z)
	var/list/image_cache = the_eye.placement_images
	for(var/i in 1 to image_cache.len)
		var/image/I = image_cache[i]
		var/list/coords = image_cache[I]
		var/turf/T = locate(eyeturf.x + coords[1], eyeturf.y + coords[2], eyeturf.z)
		I.loc = T
		switch(checkLandingTurf(T, overlappers))
			if(SHUTTLE_DOCKER_LANDING_CLEAR)
				I.icon_state = "green"
			if(SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT)
				I.icon_state = "green"
				if(. == SHUTTLE_DOCKER_LANDING_CLEAR)
					. = SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT
			if(SHUTTLE_DOCKER_BLOCKED_BY_AREA)
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED_BY_AREA
			if(SHUTTLE_DOCKER_BLOCKED_BY_MOB)
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED_BY_MOB
			else
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/placeLandingSpot()
	if(designating_target_loc || !current_user)
		return

	var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
	var/landing_clear = checkLandingSpot()
	if(designate_time && (landing_clear != SHUTTLE_DOCKER_BLOCKED))
		to_chat(current_user, span_warning("Targeting transit location, please wait [DisplayTimeText(designate_time)]..."))
		designating_target_loc = the_eye.loc
		var/wait_completed = do_after(current_user, designate_time, designating_target_loc, timed_action_flags = IGNORE_HELD_ITEM, extra_checks = CALLBACK(src, TYPE_PROC_REF(/obj/machinery/computer/camera_advanced/shuttle_docker, canDesignateTarget)))
		designating_target_loc = null
		if(!current_user)
			return
		if(!wait_completed)
			to_chat(current_user, span_warning("Operation aborted."))
			return
		landing_clear = checkLandingSpot()

	if(landing_clear != SHUTTLE_DOCKER_LANDING_CLEAR)
		switch(landing_clear)
			if(SHUTTLE_DOCKER_BLOCKED_BY_AREA)
				to_chat(current_user, span_warning("Landing zone has an unnatural structure inside of it. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT)
				to_chat(current_user, span_warning("Unknown object detected in landing zone. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED_BY_MOB)
				to_chat(current_user, span_warning("Giant biological entity is blocking the landing zone. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED)
				to_chat(current_user, span_warning("Invalid transit location."))
		return

	if(!my_port)
		my_port = new()
		my_port.unregister()
		my_port.name = shuttlePortName
		my_port.shuttle_id = shuttlePortId
		my_port.height = shuttle_port.height
		my_port.width = shuttle_port.width
		my_port.dheight = shuttle_port.dheight
		my_port.dwidth = shuttle_port.dwidth
		my_port.hidden = shuttle_port.hidden
		my_port.register(TRUE)
	my_port.setDir(the_eye.dir)
	my_port.forceMove(locate(eyeobj.x - x_offset, eyeobj.y - y_offset, eyeobj.z))

	if(current_user.client)
		current_user.client.images -= the_eye.placed_images

	LAZYCLEARLIST(the_eye.placed_images)

	for(var/image/place_spots as anything in the_eye.placement_images)
		var/image/newI = image('icons/effects/alphacolors.dmi', the_eye.loc, "blue")
		newI.loc = place_spots.loc //It is highly unlikely that any landing spot including a null tile will get this far, but better safe than sorry.
		newI.layer = NAVIGATION_EYE_LAYER
		SET_PLANE_EXPLICIT(newI, ABOVE_GAME_PLANE, place_spots)
		newI.mouse_opacity = 0
		the_eye.placed_images += newI

	if(current_user.client)
		current_user.client.images += the_eye.placed_images
		to_chat(current_user, span_notice("Transit location designated."))

	// Set our port destination with the custom port so we can dock on it
	ship_port.port_destinations = my_port

	return TRUE

/// Sets up lighting around ships when they dock
/// Converts non static lighting to static lighting and
/// Ensures lighting objects exist around all nearby turfs
/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/setup_lighting()
	// Time to calculate the area around the ship
	// So we can convert turfs to static lighting objects
	// So we don't have awful lighting around ships
	var/list/coords = my_port.return_coords()
	var/x1
	var/y1
	var/x2
	var/y2

	// Have to do some convoluted indexing based off the direction of the port
	switch(my_port.dir)
		if(1)
			x1 = coords[1]
			y1 = coords[4]

			x2 = coords[3]
			y2 = coords[2]
		if(2)
			x1 = coords[3]
			y1 = coords[2]

			x2 = coords[1]
			y2 = coords[4]
		if(4)
			x1 = coords[1]
			y1 = coords[2]

			x2 = coords[3]
			y2 = coords[4]
		if(8)
			x1 = coords[3]
			y1 = coords[4]

			x2 = coords[1]
			y2 = coords[2]


	// Subtract 8 tiles from each corner of our ship so we can
	// light the area AROUND our ship rather than just our ship
	// Doing 8 because that's the average max strength of a ship light source
	var/bottom_left_corner_x = x1 - 8
	var/bottom_left_corner_y = y2 - 8
	// Add 16 to width and height to account for the -8 and then another 8 as a buffer
	var/width = ((x2 - x1) + 1) + 16
	var/height = (abs(y2 - y1) + 1) + 16
	var/turf/bottom_corner = locate(bottom_left_corner_x, bottom_left_corner_y, my_port.z)

	// Actually do something with the turfs we found
	for(var/turf/t as anything in CORNER_BLOCK(bottom_corner, width, height))
		var/area/turf_area = get_area(t)
		if(istype(turf_area, /area/overmap_encounter/planetoid))
			var/list/turf_properties = list(t.light_range, t.light_color, t.light_power, t.lighting_object ? TRUE : FALSE)
			modified_turfs[t] = turf_properties
			if(!t.lighting_object)
				t.lighting_object = new(t)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/undo_lighting()
	for(var/turf/t in modified_turfs)
		var/l_range = modified_turfs[t][1]
		var/l_color = modified_turfs[t][2]
		var/l_power = modified_turfs[t][3]
		var/had_l_object = modified_turfs[t][4]
		var/area/turf_area = get_area(t)
		if(istype(turf_area, /area/overmap_encounter/planetoid))
			t.set_light(l_range, l_power, l_color)
			if(!had_l_object)
				t.lighting_object = null
			modified_turfs -= t

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/remove_old_ports(port_id)
	jump_to_ports = list()
	ship_port.port_destinations = null

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/add_jumpable_port(port_id)
	jump_to_ports = list(port_id)
	jump_to_ports[port_id] = TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/set_action_scaling(mob/living/user, scaling_integer)
	if(!user)
		return
	if(!scaling_integer)
		return

	var/list/datum/action_group/button_group_list = list(
		user.hud_used.listed_actions,
		user.hud_used.palette_actions
	)

	for (var/datum/action_group/button_group in button_group_list)

		// Scale out action buttons
		for (var/atom/movable/screen/scaleable_action in button_group.actions)
			scaleable_action.scale_to(scaling_integer, scaling_integer)

		// Set scaling values for the groups (used in refresh_actions)
		button_group.scale_x = scaling_integer
		button_group.scale_y = scaling_integer

		// Refresh our actions with their new values
		button_group.refresh_actions()

	// Floating actions isn't an action group so handle it differently (why tho)
	for (var/atom/movable/screen/movable/floating_button in user.hud_used.floating_actions)
		floating_button.scale_to(scaling_integer, scaling_integer)

	// Update the size of the toggle palette
	user.hud_used.toggle_palette.scale_to(scaling_integer, scaling_integer)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/give_eye_control(mob/user)
	..()
	if(!QDELETED(user) && user.client)
		var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
		var/list/to_add = list()
		to_add += the_eye.placement_images
		to_add += the_eye.placed_images
		if(!see_hidden)
			to_add += SSshuttle.hidden_shuttle_turf_images

		user.client.images += to_add
		user.client.view_size.setTo(view_range)
		if(obj_sight)
			user.add_sight(SEE_OBJS)
		if(mob_sight)
			user.add_sight(SEE_MOBS)
		set_action_scaling(user, icon_scaling_amount)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/remove_eye_control(mob/living/user)
	..()
	if(!QDELETED(user) && user.client)
		var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
		var/list/to_remove = list()
		to_remove += the_eye.placement_images
		to_remove += the_eye.placed_images
		if(!see_hidden)
			to_remove += SSshuttle.hidden_shuttle_turf_images

		user.client.images -= to_remove
		user.client.view_size.resetToDefault()
		set_action_scaling(user, 1)
	// Always drop the eye, even if the user disconnected mid-control
	QDEL_NULL(eyeobj)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/docked()
	SIGNAL_HANDLER
	UnregisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_DOCKED)
	// No custom port means we docked somewhere else (outpost, another ship) - nothing to light
	if(!my_port)
		return
	setup_lighting()
	if(current_user)
		remove_eye_control(current_user)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/undocked()
	SIGNAL_HANDLER
	UnregisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED)
	undo_lighting()
	remove_old_ports(my_port)
	if(my_port)
		my_port.unregister()
		// Forced, or docking_port/Destroy answers with QDEL_HINT_LETMELIVE and the
		// just-unregistered port lives on as an orphan
		qdel(my_port, force = TRUE)
		my_port = null
	var/mob/eye/camera/remote/shuttle_docker/the_eye = eyeobj
	if(the_eye)
		LAZYCLEARLIST(the_eye.placed_images)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/refresh(mob/user)
	var/o = get_current_celestial_object()
	if(istype(o, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = o
		if (!planet || isnull(planet))
			remove_old_ports()
			return
		// Ensure planet has docking ports created. Refreshing a camera view is no reason
		// to hold the worldgen queue, so if something else is mid-build we say so and let
		// the player try again rather than freezing the console until it finishes.
		planet.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!planet.mapzone)
			to_chat(user, span_warning("Survey systems are busy resolving another location. Try again in a moment."))
			return
		// Use the reserve dock location for camera placement
		if(planet.reserve_dock)
			docking_location = get_turf(planet.reserve_dock)
		else
			// The middle of the planet's own slot. (1,1) is the cordon band outside every
			// tenant's footprint, so the camera opened onto ground the console then
			// refuses to designate - and on a packed level it is not even this planet's.
			var/turf/planet_center = planet.footprint?.get_center_turf()
			if(planet_center)
				docking_location = planet_center
			else
				var/datum/space_level/lvl = planet.mapzone.z_levels[1]
				docking_location = locate(1, 1, lvl.z_value)
	else if(istype(o, /obj/structure/overmap/space_ruin))
		var/obj/structure/overmap/space_ruin/ruin = o
		// Ensure the ruin's map slot and docking ports exist. Same rule as the planet
		// branch above: ruin loads queue now, and a camera refresh is no reason to hold
		// this console open behind somebody else's survey - take the queue only if free.
		ruin.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!ruin.mapzone)
			if(user)
				to_chat(user, span_warning("Survey systems are busy resolving another location. Try again in a moment."))
			remove_old_ports()
			docking_location = null
			return
		// Use the reserve dock location for camera placement
		if(ruin.reserve_dock)
			docking_location = get_turf(ruin.reserve_dock)
		else
			docking_location = ruin.footprint?.get_center_turf()
	else if(istype(o, /obj/structure/overmap/event/meteor))
		var/obj/structure/overmap/event/meteor/field = o
		// Ensure the field's map slot and docking ports exist - same no-wait rule as above
		field.load_level(queue_timeout = WORLDGEN_QUEUE_NO_WAIT)
		if(!field.mapzone)
			if(user)
				to_chat(user, span_warning("Survey systems are busy resolving another location. Try again in a moment."))
			remove_old_ports()
			docking_location = null
			return
		// Use the reserve dock location for camera placement
		if(field.reserve_dock)
			docking_location = get_turf(field.reserve_dock)
		else
			docking_location = field.footprint?.get_center_turf()
	else
		// No dockable celestial in orbit - don't reuse a stale location from a previous target
		docking_location = null
