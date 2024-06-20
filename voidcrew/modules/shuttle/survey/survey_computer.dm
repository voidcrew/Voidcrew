/obj/item/circuitboard/computer/survey_shuttle_docker
	name = "Shuttle Controller"
	build_path = /obj/machinery/computer/camera_advanced/shuttle_docker/survey
	greyscale_colors = CIRCUIT_COLOR_SECURITY

/obj/machinery/computer/camera_advanced/shuttle_docker/survey
	name = "Planet survey computer"
	desc = "Used to survey planets and allow you to land anywhere on them."
	view_range = 20
	x_offset = 0
	y_offset = -5
	see_hidden = TRUE
	circuit = /obj/item/circuitboard/computer/survey_shuttle_docker
	whitelist_turfs = list()
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/turf/docking_location
	var/icon_scaling_amount = 3
	var/list/blacklisted_mob_types = list(/mob/living/simple_animal/hostile/megafauna)
	var/list/whitelisted_areas = list(/area/overmap_encounter, /area/space)
	var/datum/looping_sound/sonar/soundloop
	var/ui_user
	var/survey_in_progress = FALSE
	var/surveyed_planets = list()
	var/surveyed_planets_data = list()
	var/survey_value
	var/survey_timer
	var/banked_points = 0
	var/banked_cash = 0
	var/list/banking = list()
	var/default_survey_research_points = 500
	var/default_survey_cash_reward = 500
	var/datum/techweb/linked_techweb
	var/theme
	var/attached_to_ship = FALSE
	var/obj/item/disk/survey_data_disk/survey_disk

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Initialize(mapload)
	. = ..()

	actions = list()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)
	actions += new /datum/action/innate/camera_off(src)

	set_init_ports()

	ship_port = SSshuttle.get_containing_shuttle(src)
	if (ship_port.current_ship && !ship_port.current_ship.survey_console)
		ship_port.current_ship.survey_console = WEAKREF(src)
		attached_to_ship = TRUE
		shuttleId = ship_port.shuttle_id
		shuttlePortId = "[ship_port.shuttle_id]_custom"

	soundloop = new(src)

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
		linked_techweb.connected_machines += src //connect new one
		say("Linked to Server!")
		return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_research_tiers()
	if(!linked_techweb)
		return
	var/list/research_tiers = list("survey_console_simple", "survey_console_advanced", "survey_console_superior", "survey_console_elite")
	var/list/found_tiers = list()
	for(var/node_id in linked_techweb.researched_nodes)
		if(node_id in research_tiers)
			var/tier_type
			switch(node_id)
				if("survey_console_simple")
					tier_type = "basic"
				if("survey_console_advanced")
					tier_type = "advanced"
				if("survey_console_superior")
					tier_type = "superior"
				if("survey_console_elite")
					tier_type = "elite"
				else
					tier_type = "basic"

			found_tiers += tier_type
	return found_tiers

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Destroy()
	. = ..()
	var/datum/weakref/ship_link = ship_port.current_ship.survey_console
	if(!ship_link.resolve() || src == ship_link.resolve())
		ship_port.current_ship.survey_console = null
		attached_to_ship = FALSE
	if(survey_disk)
		survey_disk.forceMove(get_turf(src))
		survey_disk = null

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
		playsound(src, "sound/machines/terminal_insert_disc.ogg", 80)
		to_chat(user, span_notice("You insert [D] into \the [src]!"))
		return
	return ..()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui_user = user
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SurveyComputer", name)
		ui.open()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_data(mob/user)
	var/list/data = list()
	var/planet = get_current_planet()
	var/status = get_survey_status(planet)
	data["surveyStatus"] = status
	data["currentPlanet"] = add_planet_to_data_list(planet)
	data["surveyedPlanets"] = surveyed_planets_data
	data["shipMoving"] = ship_port.current_ship.is_still()
	data["bankedPoints"] = banked_points
	data["bankedCash"] = banked_cash
	data["surveyValue"] = get_survey_value(planet)
	data["theme"] = theme
	data["surveyDataDisk"] = survey_disk ? TRUE : FALSE

	return data

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("survey")
			survey_planet(ui_user)
		if("map")
			playsound(src, 'sound/machines/pda_button1.ogg', 100)
			activate_survey_map(ui_user)
		if("printResearch")
			print_survey_notes()
		if("cashOut")
			cash_out()
		if("setTheme")
			theme = params["theme"]
		if("saveData")
			save_survey_data()
		if("loadData")
			load_survey_data()
		if("eject")
			eject_disk()
		if("error")
			playsound(src, 'sound/machines/terminal_error.ogg', 100)

	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_status(obj/structure/overmap/planet/planet)
	if(!planet)
		return "planetless"
	if (survey_in_progress)
		return "in-progress"
	if (planet.loaded)
		var/already_surveyed = FALSE
		for(var/surveying_planet in surveyed_planets)
			if (surveying_planet == planet)
				already_surveyed = TRUE
		if(already_surveyed)
			return "complete"
	return "unsurveyed"

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_value(obj/structure/overmap/planet/planet)
	if(!planet)
		return

	var/point_list = list()
	var/cash = default_survey_cash_reward
	var/points = default_survey_research_points

	// Still needs logic for planet hostility
	if (!planet.surveyed)
		cash += 500
		points += 750

	point_list["cash"] = cash
	point_list["points"] = points
	return point_list

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_current_planet()
	if (ship_port)
		if (ship_port.current_ship.close_overmap_objects)
			for (var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
				// if (!istype(object, /obj/structure/overmap/planet/empty)) TEMPORARILY DISABLING FOR DEBUGGING / TESTING ENABLE BEFORE MERGE
				if (istype(object, /obj/structure/overmap/planet))
					var/obj/structure/overmap/planet/planet = object
					return planet
	return null

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/survey_planet(mob/user)

	var/obj/structure/overmap/planet/planet = get_current_planet()
	if (!planet || isnull(planet))
		playsound(src, 'sound/machines/terminal_error.ogg', 100)
		balloon_alert(user, "no planet found")
		return

	// Set our survey status to loading
	soundloop.start()
	survey_in_progress = TRUE

	// Register to the ship move signal and cancel survey if it's triggered
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(cancel_survey))

	// Check if planet is loaded
	var/loaded = planet.loaded
	if (!loaded)
		RegisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(planet_loaded))
		INVOKE_ASYNC(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, load_level))
		return
	else
		// survey_timer = addtimer(CALLBACK(src, PROC_REF(planet_loaded), planet), 60 SECONDS, TIMER_STOPPABLE)
		survey_timer = addtimer(CALLBACK(src, PROC_REF(planet_loaded), planet), 3 SECONDS, TIMER_STOPPABLE) // SETTING DEBUG TIMER FOR NOW, REMOVE ME BEFORE MERGING

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/cancel_survey()
	SIGNAL_HANDLER

	var/obj/structure/overmap/planet/planet = get_current_planet()
	if(survey_in_progress)
		UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
		deltimer(survey_timer)
		soundloop.stop()
		playsound(src, 'sound/machines/terminal_error.ogg', 100)
		survey_in_progress = FALSE


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/load_survey_data()
	if(!survey_disk)
		return
	if(survey_disk.surveyed_planets)
		surveyed_planets |= survey_disk.surveyed_planets
	if(survey_disk.surveyed_planets_data)
		for(var/surveyed_planet in survey_disk.surveyed_planets_data)
			surveyed_planets_data[surveyed_planet] = survey_disk.surveyed_planets_data[surveyed_planet]
	playsound(src, "sound/machines/high_tech_confirm.ogg", 40)
	balloon_alert(ui_user, "data downloaded from disk")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/save_survey_data()
	if(!survey_disk)
		return
	survey_disk.surveyed_planets |= surveyed_planets
	for(var/surveyed_planet in surveyed_planets_data)
		survey_disk.surveyed_planets_data[surveyed_planet] = surveyed_planets_data[surveyed_planet]
	playsound(src, "sound/machines/terminal_alert.ogg", 40)
	balloon_alert(ui_user, "data saved to disk")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/eject_disk()
	if(survey_disk)
		survey_disk.forceMove(get_turf(src))
		survey_disk = null
		playsound(src, "sound/machines/eject.ogg", 40)
		balloon_alert(ui_user, "disk ejected")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/planet_loaded(obj/structure/overmap/planet/planet)
	soundloop.stop()
	UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
	var/list/values = get_survey_value(planet)
	banked_points += values["points"]
	banked_cash += values["cash"]
	surveyed_planets += planet
	survey_in_progress = FALSE
	planet.surveyed = TRUE
	return

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/create_planet_data_list(var/obj/structure/overmap/planet/planet)

	var/list/planet_data = list()

	////// NEED TO FIGURE OUT HOW TO CHECK IF DATA ALREADY EXISTS AND THEN USE IT IF IT DOES
	if (length(surveyed_planets_data))
		for(var/sd in surveyed_planets_data)
			if (surveyed_planets_data[sd]["ref_id"] == ref(planet))
				planet_data = surveyed_planets_data[sd]
				break

	var/list/survey_research_tiers = get_survey_research_tiers()
	if("basic" in survey_research_tiers)
		planet_data["name"] = planet.name

	if("advanced" in survey_research_tiers)
		planet_data["testAdvData"] = "test"

	if("superior" in survey_research_tiers)
		planet_data["visited"] = planet.visited

	if("elite" in survey_research_tiers)
		planet_data["testEliteData"] = "test"

	planet_data["ref_id"] = ref(planet)
	planet_data["loaded"] = planet.loaded
	return planet_data

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/add_planet_to_data_list(var/obj/structure/overmap/planet/surveyed_planet)
	if(!surveyed_planet)
		return null
	var/planet_name = surveyed_planet.name
	var/surveyed_planet_ref = ref(surveyed_planet)
	var/planet_data = create_planet_data_list(surveyed_planet)
	if(get_survey_status(surveyed_planet) == "complete")
		if (planet_name in surveyed_planets_data)
			if(surveyed_planet_ref == surveyed_planets_data[planet_name]["ref_id"])
				surveyed_planets_data[planet_name] = planet_data
			else
				var/i = 1
				while(i)
					var/new_name = "[planet_name] [i]"
					if (!(new_name in surveyed_planets_data))
						surveyed_planets_data[new_name] = planet_data
						break
					else

						if(surveyed_planet_ref == surveyed_planets_data[new_name]["ref_id"])
							surveyed_planets_data[new_name] = planet_data
							planet_name = new_name
							break
						else
							i++
		else
			surveyed_planets_data[planet_name] = planet_data
	return planet_name

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/activate_survey_map(mob/user)
	refresh()
	if (!jump_to_ports.len)
		balloon_alert(user, "ship is not in orbit!")
		return
	if(.)
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
	if(!eyeobj.eye_initialized)
		var/camera_location
		var/turf/myturf = docking_location
		if(eyeobj.use_static != FALSE)
			if((!length(z_lock) || (myturf.z in z_lock)) && GLOB.cameranet.checkTurfVis(myturf))
				camera_location = myturf
			else
				for(var/obj/machinery/camera/C as anything in GLOB.cameranet.cameras)
					if(!C.can_use() || length(z_lock) && !(C.z in z_lock))
						continue
					var/list/network_overlap = networks & C.network
					if(length(network_overlap))
						camera_location = get_turf(C)
						break
		else
			camera_location = myturf
			if(length(z_lock) && !(myturf.z in z_lock))
				camera_location = locate(round(world.maxx/2), round(world.maxy/2), z_lock[1])

		if(camera_location)
			eyeobj.eye_initialized = TRUE
			give_eye_control(L)
			eyeobj.setLoc(camera_location)
		else
			unset_machine()
	else
		give_eye_control(L)
		eyeobj.setLoc(eyeobj.loc)
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(docked))
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED, PROC_REF(undocked))

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/print_survey_notes()
	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 60)
	new /obj/item/research_notes/loot/custom(src.loc, banked_points, "survey results")
	banked_points = 0

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/cash_out()
	if(banked_cash == 0)
		return

	var remaining_amount = banked_cash
	banked_cash = 0

	var/list/bill_types = list(
		/obj/item/stack/spacecash/c10000,
		/obj/item/stack/spacecash/c1000,
		/obj/item/stack/spacecash/c500,
		/obj/item/stack/spacecash/c200,
		/obj/item/stack/spacecash/c100,
		/obj/item/stack/spacecash/c50,
		/obj/item/stack/spacecash/c20,
		/obj/item/stack/spacecash/c10,
		/obj/item/stack/spacecash/c1
	)
	var/list/bill_values = list(
		10000,
		1000,
		500,
		200,
		100,
		50,
		20,
		10,
		1
	)

	playsound(src, 'sound/items/taperecorder/taperecorder_print.ogg', 60)
	var/obj/item/stack/spacecash/bill
	var/bill_value

	for (var/i = 1, i <= bill_types.len, i++)
		bill_value = bill_values[i]
		while (remaining_amount >= bill_value)
			remaining_amount -= bill_value
			bill = bill_types[i]
			playsound(src, 'sound/items/handling/paper_drop.ogg', 60)
			new bill(src.loc)
			sleep(1 SECONDS)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/checkLandingTurf(turf/T, list/overlappers)
	. = ..()

	if(!T)
		return SHUTTLE_DOCKER_BLOCKED


	var/allowed_mob = TRUE
	for(var/mob in T.contents)
		for(var/bad_mob in blacklisted_mob_types)
			if(istype(mob, bad_mob))
				allowed_mob = FALSE
	if(allowed_mob == FALSE)
		return SHUTTLE_DOCKER_BLOCKED_BY_MEGAFAUNA

	// Won't land on any area that isn't set in our whitelist
	var/allowed_area = FALSE

	for (var/whitelisted_area in whitelisted_areas)
		if (istype(get_area(T), whitelisted_area))
			allowed_area = TRUE

	if(allowed_area == FALSE)
		return SHUTTLE_DOCKER_BLOCKED_BY_AREA


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/checkLandingSpot()
	var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
	var/turf/eyeturf = get_turf(the_eye)
	if(!eyeturf)
		return SHUTTLE_DOCKER_BLOCKED
	if(!eyeturf.z || SSmapping.level_has_any_trait(eyeturf.z, locked_traits))
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
			if(SHUTTLE_DOCKER_BLOCKED_BY_MEGAFAUNA)
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED_BY_MEGAFAUNA
			else
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/placeLandingSpot()
	if(designating_target_loc || !current_user)
		return

	var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
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
			if(SHUTTLE_DOCKER_BLOCKED_BY_MEGAFAUNA)
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


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/remove_old_ports(port_id)
	jump_to_ports = list()
	ship_port.port_destinations = null

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/add_jumpable_port(port_id)
	jump_to_ports = list(port_id)
	jump_to_ports[port_id] = TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/set_action_scaling(var/mob/living/user, scaling_integer)
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
		var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
		var/list/to_add = list()
		to_add += the_eye.placement_images
		to_add += the_eye.placed_images
		if(!see_hidden)
			to_add += SSshuttle.hidden_shuttle_turf_images

		user.client.images += to_add
		user.client.view_size.setTo(view_range)
		set_action_scaling(user, icon_scaling_amount)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/remove_eye_control(mob/living/user)
	..()
	if(!QDELETED(user) && user.client)
		var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
		var/list/to_remove = list()
		to_remove += the_eye.placement_images
		to_remove += the_eye.placed_images
		if(!see_hidden)
			to_remove += SSshuttle.hidden_shuttle_turf_images

		user.client.images -= to_remove
		user.client.view_size.resetToDefault()
		set_action_scaling(user, 1)
		UnregisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_DOCKED)
		QDEL_NULL(eyeobj)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/docked()
	SIGNAL_HANDLER
	remove_eye_control(current_user)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/undocked()
	SIGNAL_HANDLER
	remove_old_ports(my_port)
	my_port.unregister()
	qdel(my_port)
	my_port = null
	var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
	LAZYCLEARLIST(the_eye.placed_images)
	UnregisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_UNDOCKED)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/refresh(mob/user)
	var/obj/structure/overmap/planet/planet = get_current_planet()
	if (!planet || isnull(planet))
		remove_old_ports()
		return
	if (planet.reserve_dock)
		add_jumpable_port(planet.reserve_dock.shuttle_id)
		docking_location = planet.reserve_dock.loc

