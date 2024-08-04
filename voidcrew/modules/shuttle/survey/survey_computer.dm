/obj/item/circuitboard/computer/survey_shuttle_docker
	name = "Orbital survey console board"
	build_path = /obj/machinery/computer/camera_advanced/shuttle_docker/survey
	greyscale_colors = CIRCUIT_COLOR_SECURITY

/obj/machinery/computer/camera_advanced/shuttle_docker/survey
	name = "Orbital survey console"
	desc = "Gather data, earn research points, and control how your ship docks on celestial objects around the void."
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
	var/ui_user
	var/survey_in_progress = FALSE
	var/datum/survey_research/data
	var/survey_value
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

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Initialize(mapload)
	. = ..()

	actions = list()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)
	actions += new /datum/action/innate/camera_off(src)

	set_init_ports()

	ship_port = SSshuttle.get_containing_shuttle(src)

	if (ship_port.current_ship)

		data = ship_port.current_ship.survey_data

		if(!ship_port.current_ship.survey_console)
			ship_port.current_ship.survey_console = WEAKREF(src)
			attached_to_ship = TRUE
			shuttleId = ship_port.shuttle_id
			shuttlePortId = "[ship_port.shuttle_id]_custom"

	soundloop = new(src)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/update_survey_data()
	var/obj/structure/overmap/object = get_current_celestial_object()
	data.update_survey_data(object)
	update_static_data(ui_user)

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
	. = ..()
	var/datum/weakref/ship_link = ship_port.current_ship.survey_console
	unsync_research_servers()
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
	var/list/tgui_data = list()
	var/obj/structure/overmap/celestial_object = get_current_celestial_object()
	survey_research_tiers = get_survey_research_tiers()
	tgui_data["surveyStatus"] = get_survey_status(celestial_object)
	tgui_data["currentCelestialRef"] = celestial_object ? ref(celestial_object) : null
	tgui_data["currentCelestialType"] = celestial_object ? data.get_related_celestial_list(celestial_object.type) : null
	tgui_data["shipMoving"] = ship_port.current_ship.is_still()
	tgui_data["bankedPoints"] = banked_points
	tgui_data["bankedCash"] = banked_cash
	tgui_data["surveyValue"] = get_survey_value(celestial_object)
	tgui_data["theme"] = theme
	tgui_data["surveyDataDisk"] = survey_disk ? TRUE : FALSE
	tgui_data["mappingEnabled"] = istype(celestial_object, /obj/structure/overmap/planet) ? mapping_enabled : FALSE

	return tgui_data

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_static_data(mob/user)
	. = ..()
	.["surveyData"] = data.tgui_serialize()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/ui_act(action, params)
	. = ..()
	if(.)
		return
	switch(action)
		if("survey")
			survey_celestial_object(ui_user)
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
		if("downloadData")
			download_survey_data()
		if("refresh")
			update_survey_data()
		if("eject")
			eject_disk()
		if("error")
			playsound(src, 'sound/machines/terminal_error.ogg', 100)

	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_current_celestial_object()
	var/list/blacklisted_types = list(
		/obj/structure/overmap/ship,
	)
	if(!debug_mode)
		blacklisted_types += /obj/structure/overmap/planet/empty
	if (ship_port)
		if (ship_port.current_ship.close_overmap_objects)
			for (var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
				if(!is_type_in_list(object, blacklisted_types))
					return object
	return null

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_status(obj/structure/overmap/object)
	if(!object || isnull(object))
		return "no-orbit"
	if (survey_in_progress)
		return "in-progress"

	var/already_surveyed = FALSE
	var/current_celestial_type = data.get_related_celestial_list(object.type)
	if(!current_celestial_type)
		log_runtime("Not found [object.type]")
	for(var/datum/surveyed_celestial_object/celestial in data.survey_objects_by_type[current_celestial_type])
		if (celestial.ref_id == ref(object))
			already_surveyed = TRUE
	if(already_surveyed)
		return "complete"
	return "unsurveyed"

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/survey_celestial_object(mob/user)
	var/current_object = get_current_celestial_object()
	if(!current_object || isnull(current_object))
		playsound(src, 'sound/machines/terminal_error.ogg', 100)
		balloon_alert(user, "no surveyable celestial object found")
		return

	soundloop.start()
	survey_in_progress = TRUE

	// Register to the ship move signal and cancel survey if it's triggered
	RegisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_MOVED, PROC_REF(cancel_survey))

	if(istype(current_object, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = current_object
		// Check if planet is loaded
		var/loaded = planet.loaded
		if (!loaded)
			RegisterSignal(planet, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(complete_survey))
			INVOKE_ASYNC(planet, TYPE_PROC_REF(/obj/structure/overmap/planet, load_level))
			return

	survey_timer = addtimer(CALLBACK(src, PROC_REF(complete_survey), current_object), (debug_mode ? 1 : 60) SECONDS, TIMER_STOPPABLE)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/complete_survey(obj/structure/overmap/object)
	soundloop.stop()
	if(istype(object, /obj/structure/overmap/planet))
		UnregisterSignal(object, COMSIG_VOIDCREW_PLANET_LOADED)
	var/list/values = get_survey_value(object)
	banked_points += values["points"]
	banked_cash += values["cash"]
	data.update_survey_data(object)
	survey_in_progress = FALSE
	update_static_data(ui_user)
	return

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/get_survey_value(obj/structure/overmap/object)
	if(!object)
		return

	var/list/point_values = list(
		nebula = list(
			points = 50,
			cash = 50
		),
		meteor = list(
			points = 100,
			cash = 100
		),
		electric = list(
			points = 250,
			cash = 250
		),
		emp = list(
			points = 400,
			cash = 400
		),
		planet = list(
			points = 500,
			cash = 500
		),
		star = list(
			points = 1000,
			cash = 1000
		),
	)

	var/point_list = list()

	var/type_split = splittext("[object.type]", "/")
	var/celestial_object_type = type_split[length(type_split)]

	// Check if the celestial type is invalid
	if(!celestial_object_type || isnull(celestial_object_type) || !(celestial_object_type in point_values))
		point_list["cash"] = 0
		point_list["points"] = 0
		return point_list

	var/points = point_values[celestial_object_type]["points"]
	var/cash = point_values[celestial_object_type]["cash"]

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

	point_list["cash"] = cash
	point_list["points"] = points
	return point_list

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/cancel_survey()
	SIGNAL_HANDLER

	var/obj/structure/overmap/object = get_current_celestial_object()
	if(survey_in_progress)
		UnregisterSignal(object, COMSIG_VOIDCREW_PLANET_LOADED)
		deltimer(survey_timer)
		soundloop.stop()
		playsound(src, 'sound/machines/terminal_error.ogg', 50)
		survey_in_progress = FALSE
	remove_old_ports(my_port)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/save_survey_data()
	if(!survey_disk)
		return

	if(!data)
		return

	for(var/datum/surveyed_celestial_object/nebula/celestial_data in data.survey_objects_by_type["nebulas"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/nebula/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/nebula/existing_celestial in survey_disk.data.survey_objects_by_type["nebulas"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["nebulas"] |= celestial

	for(var/datum/surveyed_celestial_object/asteroid/celestial_data in data.survey_objects_by_type["asteroids"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/asteroid/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/asteroid/existing_celestial in survey_disk.data.survey_objects_by_type["asteroids"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["asteroids"] |= celestial

	for(var/datum/surveyed_celestial_object/electric_storm/celestial_data in data.survey_objects_by_type["electric_storms"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/electric_storm/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/electric_storm/existing_celestial in survey_disk.data.survey_objects_by_type["electric_storms"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["electric_storms"] |= celestial

	for(var/datum/surveyed_celestial_object/emp_storm/celestial_data in data.survey_objects_by_type["emp_storms"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/emp_storm/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/emp_storm/existing_celestial in survey_disk.data.survey_objects_by_type["emp_storms"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["emp_storms"] |= celestial

	for(var/datum/surveyed_celestial_object/planet/celestial_data in data.survey_objects_by_type["planets"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/planet/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/planet/existing_celestial in survey_disk.data.survey_objects_by_type["planets"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["planets"] |= celestial

	for(var/datum/surveyed_celestial_object/star/celestial_data in data.survey_objects_by_type["stars"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/star/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/star/existing_celestial in survey_disk.data.survey_objects_by_type["stars"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our survey console's celestial to our disk
		celestial_data.copy(celestial)
		survey_disk.data.survey_objects_by_type["stars"] |= celestial


	playsound(src, "sound/machines/terminal_alert.ogg", 40)
	balloon_alert(ui_user, "data saved to disk")


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/download_survey_data()
	if(!survey_disk)
		return

	for(var/datum/surveyed_celestial_object/nebula/celestial_data in survey_disk.data.survey_objects_by_type["nebulas"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/nebula/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/nebula/existing_celestial in data.survey_objects_by_type["nebulas"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["nebulas"] |= celestial

	for(var/datum/surveyed_celestial_object/asteroid/celestial_data in survey_disk.data.survey_objects_by_type["asteroids"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/asteroid/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/asteroid/existing_celestial in data.survey_objects_by_type["asteroids"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["asteroids"] |= celestial

	for(var/datum/surveyed_celestial_object/electric_storm/celestial_data in survey_disk.data.survey_objects_by_type["electric_storms"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/electric_storm/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/electric_storm/existing_celestial in data.survey_objects_by_type["electric_storms"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["electric_storms"] |= celestial

	for(var/datum/surveyed_celestial_object/emp_storm/celestial_data in survey_disk.data.survey_objects_by_type["emp_storms"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/emp_storm/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/emp_storm/existing_celestial in data.survey_objects_by_type["emp_storms"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["emp_storms"] |= celestial

	for(var/datum/surveyed_celestial_object/planet/celestial_data in survey_disk.data.survey_objects_by_type["planets"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/planet/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/planet/existing_celestial in data.survey_objects_by_type["planets"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["planets"] |= celestial

	for(var/datum/surveyed_celestial_object/star/celestial_data in survey_disk.data.survey_objects_by_type["stars"])
		// Create a placeholder celestial var
		var/datum/surveyed_celestial_object/star/celestial

		// Check to see if our celestial is already in our disk's survey data
		for(var/datum/surveyed_celestial_object/star/existing_celestial in data.survey_objects_by_type["stars"])
			if(existing_celestial.ref_id == celestial_data.ref_id || existing_celestial == celestial_data)
				celestial = existing_celestial

		// If it isn't, instantiate it
		if(!celestial)
			celestial = new()

		// Copy data from our disk to our survey console
		celestial_data.copy(celestial)
		data.survey_objects_by_type["stars"] |= celestial

	update_static_data(ui_user)
	playsound(src, "sound/machines/high_tech_confirm.ogg", 40)
	balloon_alert(ui_user, "data downloaded from disk")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/eject_disk()
	if(survey_disk)
		survey_disk.forceMove(get_turf(src))
		survey_disk = null
		playsound(src, "sound/machines/eject.ogg", 40)
		balloon_alert(ui_user, "disk ejected")

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/activate_survey_map(mob/user)
	refresh()
	if(length(ship_port.current_ship.close_overmap_objects) == 0)
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
		return SHUTTLE_DOCKER_BLOCKED_BY_MOB

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
			if(SHUTTLE_DOCKER_BLOCKED_BY_MOB)
				I.icon_state = "red"
				. = SHUTTLE_DOCKER_BLOCKED_BY_MOB
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
		if(obj_sight)
			user.add_sight(SEE_OBJS)
		if(mob_sight)
			user.add_sight(SEE_MOBS)
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
		QDEL_NULL(eyeobj)

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/docked()
	SIGNAL_HANDLER
	UnregisterSignal(ship_port.current_ship, COMSIG_VOIDCREW_SHIP_DOCKED)
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
	var/o = get_current_celestial_object()
	if(istype(o, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = o
		if (!planet || isnull(planet))
			remove_old_ports()
			return
		var/datum/space_level/lvl = planet.mapzone.z_levels[1]
		docking_location = locate(1, 1, lvl.z_value)


