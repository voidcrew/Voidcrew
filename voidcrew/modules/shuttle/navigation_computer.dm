/obj/machinery/computer/camera_advanced/shuttle_docker/survey
	name = "Planet survey computer"
	desc = "Used to survey planets and allow you to land anywhere on them."
	view_range = 20
	x_offset = 0
	y_offset = -5
	see_hidden = TRUE
	circuit = /obj/item/circuitboard/computer/syndicate_shuttle_docker
	whitelist_turfs = list()
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/turf/docking_location

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/Initialize(mapload)
	. = ..()

	actions = list()
	actions += new /datum/action/innate/shuttledocker_rotate/voidcrew(src)
	actions += new /datum/action/innate/shuttledocker_place/voidcrew(src)
	actions += new /datum/action/innate/camera_off/voidcrew(src)

	set_init_ports()

	ship_port = SSshuttle.get_containing_shuttle(src)

	if (ship_port)
		shuttleId = ship_port.shuttle_id
		shuttlePortId = "[ship_port.shuttle_id]_custom"

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/refresh(mob/user)
	if (ship_port)
		if (ship_port.current_ship.close_overmap_objects)
			for (var/obj/structure/overmap/object in ship_port.current_ship.close_overmap_objects)
				if (istype(object, /obj/structure/overmap/planet))
					var/obj/structure/overmap/planet/planet = object
					if (planet.reserve_dock)
						add_jumpable_port(planet.reserve_dock.shuttle_id)
						docking_location = planet.reserve_dock.loc
		else
			remove_old_ports()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/attack_hand(mob/user, list/modifiers)
	refresh()
	if (!jump_to_ports.len)
		balloon_alert(user, "no planets in orbit!")
		return
		. = ..()
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

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/checkLandingTurf(turf/T, list/overlappers)
	. = ..()

	// Won't land on any area that isn't overmap_encounter (Player areas or ruins)
	if (!istype(get_area(T), /area/overmap_encounter))
		return SHUTTLE_DOCKER_BLOCKED_BY_AREA

	// Allows you to restrict landing on certain mobs
	var/list/blacklisted_mobs = list(
		/mob/living/simple_animal/hostile/megafauna
	)

	if (T.contents.len)
		for (var/content in T.contents)
			for (var/mob in blacklisted_mobs)
				if (istype(content, mob))
					return SHUTTLE_DOCKER_BLOCKED_BY_MEGAFAUNA

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

	///Make one use port that deleted after fly off, to don't lose info that need on to properly fly off.
	if(my_port?.get_docked())
		my_port.unregister()
		my_port.delete_after = TRUE
		my_port.shuttle_id = null
		my_port.name = "Old [my_port.name]"
		my_port = null

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

	// Set our port destination with the custom port so we can dock on the custom port
	ship_port.port_destinations = my_port

	return TRUE


/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/remove_old_ports(port_id)
	jump_to_ports = list()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/add_jumpable_port(port_id)
	jump_to_ports = list(port_id)
	jump_to_ports[port_id] = TRUE

/datum/action/innate/shuttledocker_place/voidcrew
	scaling = 3
	offset_x = 7
	offset_y = 54

/datum/action/innate/shuttledocker_rotate/voidcrew
	scaling = 3
	offset_x = 10
	offset_y = 54

/datum/action/innate/camera_off/voidcrew
	scaling = 3
	offset_x = 13
	offset_y = 54
