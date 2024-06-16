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
	var/info_level
	var/ui_user
	var/survey_in_progress = FALSE
	var/surveyed_planets = list()
	var/surveyed_planets_data = list()
	var/survey_value
	var/gathered_loot = FALSE
	var/survey_timer
	var/survey_progress

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Initialize(mapload)
	. = ..()

	actions = list()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)
	actions += new /datum/action/innate/camera_off(src)

	set_init_ports()

	ship_port = SSshuttle.get_containing_shuttle(src)

	if (ship_port)
		shuttleId = ship_port.shuttle_id
		shuttlePortId = "[ship_port.shuttle_id]_custom"

	soundloop = new(src)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Destroy()
	. = ..()
	QDEL_NULL(soundloop)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/attack_hand(mob/user, list/modifiers)
	ui_interact(user)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui_user = user
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "SurveyComputer", name)
		ui.open()

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

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/create_planet_data_list(var/obj/structure/overmap/planet/planet)
	var/list/planet_data = list()
	planet_data["ref_id"] = ref(planet)
	planet_data["visited"] = planet.visited
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
					planet_name = "[planet_name] [i]"
					if (!(planet_name in surveyed_planets_data))
						surveyed_planets_data[planet_name] = planet_data
						break
					else

						if(surveyed_planet_ref == surveyed_planets_data[planet_name]["ref_id"])
							surveyed_planets_data[planet_name] = planet_data
							break
						else
							i++
		else
			surveyed_planets_data[planet_name] = planet_data
	return planet_name

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_data(mob/user)
	var/list/data = list()
	var/planet = get_current_planet()
	var/status = get_survey_status(planet)
	data["surveyStatus"] = status
	data["currentPlanet"] = add_planet_to_data_list(planet)
	data["surveyedPlanets"] = surveyed_planets_data
	data["shipMoving"] = ship_port.current_ship.is_still()
	data["surveyProgress"] = survey_progress
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
		if("reward")
			print_survey_notes(params["level"])
		if("error")
			playsound(src, 'sound/machines/terminal_error.ogg', 100)
	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_current_planet()
	if (ship_port)
		if (ship_port.current_ship.close_overmap_objects)
			for (var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
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
	gathered_loot = FALSE
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


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/planet_loaded(obj/structure/overmap/planet/planet)
	soundloop.stop()
	UnregisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED)
	surveyed_planets += planet
	survey_in_progress = FALSE

	return


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
	new /obj/item/research_notes/loot/small(src.loc)
	gathered_loot = TRUE

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

