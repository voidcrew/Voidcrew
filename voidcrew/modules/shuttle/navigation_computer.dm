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
	if (istype(get_area(T), /area/ruin))
		return SHUTTLE_DOCKER_BLOCKED

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/placeLandingSpot()
	. = ..()
	var/obj/docking_port/mobile/voidcrew/mobile_port = SSshuttle.get_containing_shuttle(src)
	mobile_port.port_destinations = my_port

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/proc/remove_old_ports(port_id)
	jump_to_ports = list()

/obj/machinery/computer/camera_advanced/shuttle_docker/survey/add_jumpable_port(port_id)
	jump_to_ports = list(port_id)
	jump_to_ports[port_id] = TRUE

// /obj/machinery/computer/camera_advanced/shuttle_docker/survey/give_eye_control(mob/user)
// 	..()
// 	if(!QDELETED(user) && user.client)
// 		var/mob/camera/ai_eye/remote/shuttle_docker/the_eye = eyeobj
// 		var/list/to_add = list()
// 		to_add += the_eye.placement_images
// 		to_add += the_eye.placed_images
// 		if(!see_hidden)
// 			to_add += SSshuttle.hidden_shuttle_turf_images

// 		user.client.images += to_add
// 		user.client.view_size.setTo(view_range)
// 		the_eye.setLoc(docking_location)

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
