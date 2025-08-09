/obj/structure/closet/supplypod/drop_pod
	name = "orbital drop pod"
	desc = "A device that lets you travel to celestial objects under your ship"
	stay_after_drop = TRUE
	specialised = TRUE
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF | UNACIDABLE
	style = /datum/pod_style/drop_pod
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/used = FALSE
	var/datum/techweb/linked_techweb
	var/mob/living/ui_user = null
	var/mob/living/map_user = null
	var/list/blacklisted_mob_types = list(/mob/living/simple_animal/hostile/megafauna)
	var/list/whitelisted_areas = list(/area/overmap_encounter, /area/space)
	var/mob/eye/camera/drop_pod/eyeobj
	var/eye_initialized = FALSE
	/// List of all actions to give to a user when they're well, granted actions
	var/list/actions = list()
	var/list/locked_traits = list(ZTRAIT_RESERVED, ZTRAIT_CENTCOM, ZTRAIT_AWAY)
	var/enter_time = 2 SECONDS
	anchorable = TRUE
	anchored = TRUE
	reverse_option_list = list("Mobs"=TRUE,"Objects"=TRUE,"Anchored"=FALSE,"Underfloor"=FALSE,"Wallmounted"=FALSE,"Floors"=FALSE,"Walls"=FALSE, "Mecha"=FALSE)
	var/turf/targeted_turf
	var/obj/machinery/quantumpad/linked_pad
	var/teleporting = FALSE
	var/teleport_speed = 3 SECONDS
	var/teleport_used = FALSE
	var/debug_enabled = FALSE
	density = TRUE
	var/ignore_next_open = FALSE

/obj/structure/closet/supplypod/drop_pod/advanced
	name = "advanced orbital drop pod"
	desc = "An improved drop pod with extra armor and insulation from the outside environment. It doesn't open automatically upon landing."
	contents_pressure_protection = 1
	contents_thermal_insulation = 1
	max_integrity = 600

/datum/crafting_recipe/drop_pod
	name = "Orbital Drop Pod"
	result = /obj/structure/closet/supplypod/drop_pod
	reqs = list(/obj/item/stack/sheet/iron = 30, // the backboard
				/obj/item/stack/rods = 5)
	time = 10 SECONDS
	category = CAT_EQUIPMENT

/datum/crafting_recipe/drop_pod/advanced
	name = "Advanced Orbital Drop Pod"
	result = /obj/structure/closet/supplypod/drop_pod/advanced
	reqs = list(/obj/item/stack/sheet/plasteel = 15,
				/obj/item/stack/sheet/iron = 15, // the backboard
				/obj/item/stack/rods = 10)

/obj/structure/closet/supplypod/drop_pod/advanced/open_pod(atom/movable/holder, broken = FALSE, forced = FALSE)
	if(ignore_next_open)
		ignore_next_open = FALSE
		return
	. = ..()

/obj/structure/closet/supplypod/drop_pod/get_remote_view_fullscreens(mob/user)
	return

/obj/structure/closet/supplypod/drop_pod/attackby(obj/item/I, mob/user, params)
	if(I.tool_behaviour == TOOL_CROWBAR)
		if(opened == FALSE)
			open_pod(src, FALSE, FALSE)
			return TRUE
		else
			setClosed()
			return TRUE
	if(I.tool_behaviour == TOOL_WRENCH)
		set_anchored(!anchored)
		return TRUE
	if(I.tool_behaviour == TOOL_MULTITOOL)
		var/obj/item/multitool/tool = I
		if(tool.buffer)
			linked_pad  = tool.buffer
			balloon_alert(user, "Data uploaded from buffer")
			return TRUE
		else
			balloon_alert(user, "No quantum pad data found!")
			return TRUE
	return ..()

/obj/structure/closet/supplypod/drop_pod/proc/teleport()
	if(teleport_used)
		return
	if(!linked_pad)
		return
	playsound(get_turf(src), 'sound/weapons/flash.ogg', 25, TRUE)
	teleporting = TRUE

	addtimer(CALLBACK(src, PROC_REF(teleport_contents)), teleport_speed)

/obj/structure/closet/supplypod/drop_pod/proc/teleport_contents()
	// teleporting = FALSE
	teleport_used = TRUE
	if(QDELETED(linked_pad) || linked_pad.machine_stat & (BROKEN|NOPOWER))
		if(ui_user)
			to_chat(ui_user, span_warning("Linked pad is not responding to ping. Teleport aborted."))
		return
	// last_teleport = world.time

	// use a lot of power
	// use_energy(active_power_usage / power_efficiency)
	sparks()
	linked_pad.sparks()

	// flick("qpad-beam", src)
	playsound(get_turf(src), 'sound/weapons/emitter2.ogg', 25, TRUE)
	flick("qpad-beam", linked_pad)
	playsound(get_turf(linked_pad), 'sound/weapons/emitter2.ogg', 25, TRUE)
	var/list/atom/pod_contents = opened ? get_turf(src) : contents
	for(var/atom/movable/ROI in pod_contents)
		if(QDELETED(ROI))
			continue //sleeps in CHECK_TICK

		// if is anchored, don't let through
		if(ROI.anchored)
			continue

		if(isliving(ROI))
			var/mob/living/living_subject = ROI
			//only TP living mobs buckled to non anchored items
			if(living_subject.buckled && living_subject.buckled.anchored)
				continue

		do_teleport(ROI, get_turf(linked_pad), no_effects = TRUE, channel = TELEPORT_CHANNEL_QUANTUM, forced = TRUE)
		CHECK_TICK

/obj/structure/closet/supplypod/drop_pod/proc/sparks()
	var/datum/effect_system/spark_spread/quantum/s = new /datum/effect_system/spark_spread/quantum
	s.set_up(5, 1, get_turf(src))
	s.start()

/obj/structure/closet/supplypod/drop_pod/Initialize(mapload, customStyle)
	. = ..()
	ship_port = SSshuttle.get_containing_shuttle(src)
	actions += new /datum/action/innate/drop_pod(src)
	actions += new /datum/action/innate/drop_pod_close_map(src)

/datum/action/innate/drop_pod_close_map
	name = "Close Map"
	button_icon = 'icons/mob/actions/actions_silicon.dmi'
	button_icon_state = "camera_off"

/datum/action/innate/drop_pod_close_map/Activate()
	if(!owner || !isliving(owner))
		return
	var/mob/eye/camera/drop_pod/remote_eye = owner.remote_control
	var/obj/structure/closet/supplypod/drop_pod/pod = remote_eye.pod_origin
	pod.remove_eye_control(owner)

/obj/structure/closet/supplypod/drop_pod/Destroy()
	. = ..()
	unsync_research_servers()

/obj/structure/closet/supplypod/drop_pod/setClosed()
	if(opened == FALSE)
		return
	opened = FALSE
	playsound(src, close_sound, soundVolume*0.75, TRUE, -3)
	set_density(TRUE)
	take_contents(src)
	update_appearance()
	after_close(null, FALSE)

/obj/structure/closet/supplypod/drop_pod/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null

/obj/structure/closet/supplypod/drop_pod/multitool_act(mob/living/user, obj/item/multitool/tool)
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

/obj/structure/closet/supplypod/drop_pod/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	if(!isliving(user))
		return
	if((ui_user && ui_user != user) || (map_user && map_user != user))
		balloon_alert(user, "drop pod in use!")
		return
	ui_user = user
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "DropPod", name)
		ui.open()

/obj/structure/closet/supplypod/drop_pod/ui_close(mob/user)
	ui_user = null
	. = ..()

/obj/structure/closet/supplypod/drop_pod/ui_data(mob/user)
	var/list/tgui_data = list()
	var/obj/structure/overmap/planet/current_planet = get_current_planet()
	tgui_data["overPlanet"] = current_planet && current_planet.loaded ? TRUE : FALSE
	tgui_data["teleporterUsed"] = teleport_used
	return tgui_data

/obj/structure/closet/supplypod/drop_pod/ui_static_data(mob/user)
	. = ..()
	if(debug_enabled)
		.["mappingEnabled"] = TRUE
	else
		if(linked_techweb)
			if("survey_console_advanced" in linked_techweb.researched_nodes)
				.["mappingEnabled"] = TRUE
			else
				.["mappingEnabled"] = FALSE
		else
			.["mappingEnabled"] = FALSE

	// Has the pod already been launched?
	.["used"] = used
	.["teleporterLinked"] = linked_pad ? TRUE : FALSE

/obj/structure/closet/supplypod/drop_pod/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return
	switch(action)
		if("randomDrop")
			if(opened)
				balloon_alert(ui_user, "close doors first!")
				to_chat(ui_user, text = "cannot launch pod as doors are not closed")
				return
			ui.close()
			choose_random_drop_location(ui_user)
		if("map")
			if(opened)
				balloon_alert(ui_user, "close doors first!")
				to_chat(ui_user, text = "cannot use pod mapping as doors are not closed")
				return
			map_user = ui_user
			ui.close()
			activate_map(map_user)
		if("open")
			open_pod(src, FALSE, FALSE)
		if("close")
			setClosed()
		if("teleport")
			teleport()
		if("refresh")
			refresh()
	return TRUE

/obj/structure/closet/supplypod/drop_pod/proc/refresh()
	update_static_data(ui_user)

/obj/structure/closet/supplypod/drop_pod/insertion_allowed(atom/to_insert)
	if(to_insert.invisibility == INVISIBILITY_ABSTRACT)
		return FALSE
	if(ismob(to_insert))
		if(!reverse_option_list["Mobs"])
			return FALSE
		if(!isliving(to_insert)) //let's not put ghosts or camera mobs inside
			return FALSE
		var/mob/living/mob_to_insert = to_insert
		if(mob_to_insert.anchored || mob_to_insert.incorporeal_move)
			return FALSE
		mob_to_insert.stop_pulling()

	else if(isobj(to_insert))
		var/obj/obj_to_insert = to_insert
		if(issupplypod(obj_to_insert))
			return FALSE
		if(istype(obj_to_insert, /obj/effect/supplypod_smoke))
			return FALSE
		if(istype(obj_to_insert, /obj/effect/pod_landingzone/drop_pod))
			return FALSE
		if(istype(obj_to_insert, /obj/effect/supplypod_rubble))
			return FALSE

		if(HAS_TRAIT(obj_to_insert, TRAIT_UNDERFLOOR))
			return !!reverse_option_list["Underfloor"]
		if(isProbablyWallMounted(obj_to_insert))
			return !!reverse_option_list["Wallmounted"]

		if(!obj_to_insert.anchored && reverse_option_list["Unanchored"])
			return TRUE
		if(obj_to_insert.anchored && !ismecha(obj_to_insert) && reverse_option_list["Anchored"]) //Mecha are anchored but there is a separate option for them
			return TRUE
		if(ismecha(obj_to_insert) && reverse_option_list["Mecha"])
			return TRUE
		return TRUE

	else if (isturf(to_insert))
		if(isfloorturf(to_insert) && reverse_option_list["Floors"])
			return TRUE
		if(isfloorturf(to_insert) && !reverse_option_list["Floors"])
			return FALSE
		if(isclosedturf(to_insert) && reverse_option_list["Walls"])
			return TRUE
		if(isclosedturf(to_insert) && !reverse_option_list["Walls"])
			return FALSE
		return FALSE
	return TRUE

/obj/structure/closet/supplypod/drop_pod/proc/get_current_planet()
	if(!ship_port)
		return
	var/obj/structure/overmap/planet/current_planet
	var/list/current_overmap_objects = ship_port.current_ship.close_overmap_objects

	for(var/obj/structure/overmap/object in current_overmap_objects)
		if(object.type in typesof(/obj/structure/overmap/planet))
			if(istype(object, /obj/structure/overmap/planet/empty))
				if(debug_enabled)
					current_planet = object
					return current_planet
			else
				current_planet = object
				return current_planet
	return

/obj/structure/closet/supplypod/drop_pod/proc/get_planet_z(obj/structure/overmap/planet/current_planet)
	if(!current_planet || !current_planet.mapzone || !(length(current_planet.mapzone.z_levels)))
		return null
	var/planet_z_level = current_planet.mapzone.z_levels[1].z_value

	return planet_z_level

/obj/structure/closet/supplypod/drop_pod/proc/can_use(mob/living/user)
	if(QDELETED(user))
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	if(!isliving(user))
		return FALSE //no ghosts allowed, sorry
	return TRUE

/obj/structure/closet/supplypod/drop_pod/proc/activate_map(mob/living/user)
	if(!can_use(user))
		return
	if(isnull(user.client))
		return
	var/obj/structure/overmap/planet/current_planet = get_current_planet()
	if(!current_planet)
		balloon_alert(user, "no current planet!")
		return
	var/planet_z_level = get_planet_z(current_planet)
	if(!planet_z_level)
		balloon_alert(user, "planet not surveyed!")
		return
	var/mob/living/L = user
	if(!eyeobj)
		CreateEye()
	if(!eyeobj) //Eye creation failed
		return
	if(!eye_initialized)
		var/camera_location
		var/turf/myturf = locate(1, 1, planet_z_level)

		camera_location = myturf

		if(camera_location)
			eye_initialized = TRUE
			give_eye_control(L)
			eyeobj.setLoc(camera_location)
		else
			remove_eye_control(L)
	else
		give_eye_control(L)
		eyeobj.setLoc(eyeobj.loc)

/obj/structure/closet/supplypod/drop_pod/proc/choose_random_drop_location(mob/user)
	if(used)
		return
	var/obj/structure/overmap/planet/current_planet = get_current_planet()
	if(!current_planet)
		return
	var/planet_z_level = get_planet_z(current_planet)
	if(!planet_z_level)
		return
	var/list/area/planet_areas = list()
	for (var/area/area in SSmapping.areas_in_z["[planet_z_level]"])
		if(istype(area, /area/overmap_encounter/planetoid/cave))
			continue
		// if(area.type in typesof(/area/overmap_encounter/planetoid))
		if(istype(area, /area/overmap_encounter/planetoid))
			planet_areas += area
	if(length(planet_areas) < 1)
		if(debug_enabled)
			if(istype(current_planet, /obj/structure/overmap/planet/empty))
				var/area/space/space_area = get_area_instance_from_text("/area/space")
				planet_areas += space_area
		else
			balloon_alert(user, "nowhere to land")
			return
	for (var/i in 1 to 5)
		var/list/turf_list = get_area_turfs(pick(planet_areas), planet_z_level)
		var/turf/target
		while (turf_list.len && !target)
			var/I = rand(1, turf_list.len)
			var/turf/checked_turf = turf_list[I]
			if(debug_enabled)
				target = checked_turf
				break
			if(!checked_turf.density && !isgroundlessturf(checked_turf))
				var/clear = TRUE
				for(var/obj/checked_object in checked_turf)
					if(checked_object.density)
						clear = FALSE
						break
				if(clear)
					target = checked_turf
			if (!target)
				turf_list.Cut(I, I + 1)
		if (target)
			set_anchored(TRUE)
			new /obj/effect/pod_landingzone/drop_pod(target, src)
			used = TRUE
			update_static_data(user)
			return

/mob/eye/camera/drop_pod
	use_visibility = FALSE
	var/image/placed_image = null
	var/image/placement_image = null
	var/obj/structure/closet/supplypod/drop_pod/pod_origin

/mob/eye/camera/drop_pod/Initialize(mapload, obj/structure/closet/supplypod/drop_pod/origin)
	src.pod_origin = origin
	return ..()

/mob/eye/camera/drop_pod/setLoc(turf/destination, force_update = FALSE)
	. = ..()
	if(pod_origin)
		pod_origin.checkLandingSpot(destination)

/obj/structure/closet/supplypod/drop_pod/proc/CreateEye()
	if(!ship_port)
		return
	if(QDELETED(ship_port))
		ship_port = null
		return
	eyeobj = new /mob/eye/camera/drop_pod(null, src)
	eyeobj.pod_origin = src
	var/turf/ship_port_location = locate(ship_port.x, ship_port.y, ship_port.z)
	var/image/I = image('icons/effects/alphacolors.dmi', ship_port_location, "red")
	if(!I)
		return

	I.loc = ship_port_location
	I.layer = ABOVE_NORMAL_TURF_LAYER
	SET_PLANE_EXPLICIT(I, ABOVE_GAME_PLANE, src)
	I.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	eyeobj.placement_image = I

/obj/structure/closet/supplypod/drop_pod/proc/placeLandingSpot()
	if(!map_user)
		return

	var/turf/target = get_turf(eyeobj)
	if(!target)
		return
	var/landing_clear = checkLandingSpot(target)

	if(landing_clear != SHUTTLE_DOCKER_LANDING_CLEAR)
		switch(landing_clear)
			if(SHUTTLE_DOCKER_BLOCKED_BY_AREA)
				to_chat(map_user, span_warning("Landing zone has an unnatural structure inside of it. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT)
				to_chat(map_user, span_warning("Unknown object detected in landing zone. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED_BY_MOB)
				to_chat(map_user, span_warning("Giant biological entity is blocking the landing zone. Please designate another location."))
			if(SHUTTLE_DOCKER_BLOCKED)
				to_chat(map_user, span_warning("Invalid transit location."))
		return

	remove_eye_control(map_user)
	set_anchored(TRUE)
	new /obj/effect/pod_landingzone/drop_pod(target, src)
	used = TRUE
	update_static_data(map_user)

/obj/effect/pod_landingzone/drop_pod
	var/leaving_sound = 'sound/effects/podwoosh.ogg'

/obj/effect/pod_landingzone/drop_pod/endLaunch()
	if(istype(pod, /obj/structure/closet/supplypod/drop_pod/advanced))
		var/obj/structure/closet/supplypod/drop_pod/advanced/adv_pod = pod
		adv_pod.ignore_next_open = TRUE
	. = ..()

/obj/effect/pod_landingzone/drop_pod/proc/playLeavingSound(obj/structure/closet/supplypod/pod)
	playsound(get_turf(pod), leaving_sound, pod.soundVolume, TRUE, 6)

/obj/effect/pod_landingzone/drop_pod/beginLaunch(effectCircle)
	if(!pod.effectQuiet)
		playLeavingSound(pod)
	. = ..()

/obj/structure/closet/supplypod/drop_pod/proc/checkLandingSpot(turf/eyeturf)
	if(!eyeturf)
		return SHUTTLE_DOCKER_BLOCKED
	if(!eyeturf.z || SSmapping.level_has_any_trait(eyeturf.z, locked_traits))
		return SHUTTLE_DOCKER_BLOCKED

	. = SHUTTLE_DOCKER_LANDING_CLEAR
	// var/list/bounds = shuttle_port.return_coords(the_eye.x - x_offset, the_eye.y - y_offset, the_eye.dir)
	// var/list/overlappers = SSshuttle.get_dock_overlap(bounds[1], bounds[2], bounds[3], bounds[4], the_eye.z)
	// var/list/image_cache = the_eye.placement_images
	// for(var/i in 1 to image_cache.len)
	// var/image/I = image_cache[1]
	var/image/I = eyeobj.placement_image
	var/turf/T = locate(eyeturf.x, eyeturf.y, eyeturf.z)
	I.loc = T
	switch(checkLandingTurf(T))
		if(SHUTTLE_DOCKER_LANDING_CLEAR)
			I.icon_state = "green"
		// if(SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT)
		// 	I.icon_state = "green"
		// 	if(. == SHUTTLE_DOCKER_LANDING_CLEAR)
		// 		. = SHUTTLE_DOCKER_BLOCKED_BY_HIDDEN_PORT
		if(SHUTTLE_DOCKER_BLOCKED_BY_AREA)
			I.icon_state = "red"
			. = SHUTTLE_DOCKER_BLOCKED_BY_AREA
		if(SHUTTLE_DOCKER_BLOCKED_BY_MOB)
			I.icon_state = "red"
			. = SHUTTLE_DOCKER_BLOCKED_BY_MOB
		else
			I.icon_state = "red"
			. = SHUTTLE_DOCKER_BLOCKED

/obj/structure/closet/supplypod/drop_pod/proc/checkLandingTurf(turf/T)
	. = SHUTTLE_DOCKER_LANDING_CLEAR

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

/obj/structure/closet/supplypod/drop_pod/proc/give_eye_control(mob/user)
	if(isnull(user?.client))
		return
	GrantActions(user)
	eyeobj.name = "Camera Eye ([user.name])"
	user.remote_control = eyeobj
	user.reset_perspective(eyeobj)
	eyeobj.setLoc(eyeobj.loc)
	user.set_sight(BLIND | SEE_TURFS)
	user.client.images += eyeobj.placement_image
	if(linked_techweb)
		var/mob_sight = FALSE
		var/obj_sight = FALSE
		for(var/node in linked_techweb.researched_nodes)
			if(node == "survey_console_superior")
				user.add_sight(SEE_OBJS)
				obj_sight = TRUE

			if(node == "survey_console_elite")
				user.add_sight(SEE_MOBS)
				mob_sight = TRUE

			if(obj_sight && mob_sight)
				break
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(check_if_user_in_range))

/obj/structure/closet/supplypod/drop_pod/proc/check_if_user_in_range()
	SIGNAL_HANDLER
	remove_eye_control(map_user)

/obj/structure/closet/supplypod/drop_pod/proc/remove_eye_control(mob/living/user)
	if(isnull(user?.client))
		return

	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)

	for(var/datum/action/actions_removed as anything in actions)
		actions_removed.Remove(user)
	eyeobj.clear_camera_chunks()

	user.reset_perspective(null)
	user.client.images -= eyeobj.placed_image
	user.client.images -= eyeobj.placement_image
	user.remote_control = null
	map_user = null
	playsound(src, 'sound/machines/terminal_off.ogg', 25, FALSE)
	QDEL_NULL(eyeobj)

/obj/structure/closet/supplypod/drop_pod/proc/GrantActions(mob/living/user)
	for(var/datum/action/to_grant as anything in actions)
		to_grant.Grant(user)

/datum/action/innate/drop_pod
	name = "Place"
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	button_icon_state = "mech_zoom_off"

/datum/action/innate/drop_pod/Activate()
	if(QDELETED(owner) || !isliving(owner))
		return
	var/mob/eye/camera/drop_pod/remote_eye = owner.remote_control
	var/obj/structure/closet/supplypod/drop_pod/origin = remote_eye.pod_origin
	origin.placeLandingSpot(owner)
