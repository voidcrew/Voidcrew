/obj/structure/closet/supplypod/drop_pod
	name = "orbital drop pod"
	desc = "A one-shot pod for getting off the ship the hard way. Ride it down to a celestial body below, or load it into an assault pod tube and let the weapons officer put you through somebody else's hull."
	stay_after_drop = TRUE
	specialised = TRUE
	icon = 'voidcrew/icons/obj/supplypods.dmi'
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF | UNACIDABLE
	style = /datum/pod_style/drop_pod
	// Small enough that the arrival doesn't set the compartment on fire. The pod
	// hitting the deck is the thump; a hull breach is cut by the tube launch, not
	// blasted (see ship_combat/assault_pod.dm).
	explosionSize = list(0, 0, 1, 0)
	var/obj/docking_port/mobile/voidcrew/ship_port
	var/used = FALSE
	var/mob/living/ui_user = null
	var/mob/living/map_user = null
	// Both halves of ismegafauna(): /mob/living/basic/boss is this fork's tier
	var/list/blacklisted_mob_types = list(/mob/living/simple_animal/hostile/megafauna, /mob/living/basic/boss)
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
	desc = "An improved drop pod with extra armor and insulation from the outside environment. It doesn't open automatically upon landing - you choose when to be seen."
	contents_pressure_protection = 1
	contents_thermal_insulation = 1
	max_integrity = 600

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
		if(istype(tool.buffer, /obj/machinery/quantumpad))
			linked_pad = tool.buffer
			balloon_alert(user, "quantum pad linked")
			return TRUE
		balloon_alert(user, "no quantum pad data found!")
		return TRUE
	return ..()

/obj/structure/closet/supplypod/drop_pod/proc/teleport()
	if(teleport_used || teleporting)
		return
	if(!linked_pad)
		return
	playsound(get_turf(src), 'sound/items/weapons/flash.ogg', 25, TRUE)
	teleporting = TRUE

	addtimer(CALLBACK(src, PROC_REF(teleport_contents)), teleport_speed)

/obj/structure/closet/supplypod/drop_pod/proc/teleport_contents()
	teleporting = FALSE
	if(teleport_used)
		return
	if(QDELETED(linked_pad) || linked_pad.machine_stat & (BROKEN|NOPOWER))
		// Failed ping doesn't consume the one-shot teleport
		if(ui_user)
			to_chat(ui_user, span_warning("Linked pad is not responding to ping. Teleport aborted."))
		return
	teleport_used = TRUE

	sparks()
	linked_pad.sparks()

	playsound(get_turf(src), 'sound/items/weapons/emitter2.ogg', 25, TRUE)
	flick("qpad-beam", linked_pad)
	playsound(get_turf(linked_pad), 'sound/items/weapons/emitter2.ogg', 25, TRUE)
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
	if(map_user)
		remove_eye_control(map_user)
	QDEL_NULL(eyeobj)
	QDEL_LIST(actions)
	linked_pad = null
	return ..()

/obj/structure/closet/supplypod/drop_pod/setClosed()
	if(opened == FALSE)
		return
	opened = FALSE
	playsound(src, close_sound, soundVolume*0.75, TRUE, -3)
	set_density(TRUE)
	take_contents(src)
	update_appearance()
	after_close(null, FALSE)
	var/obj/machinery/ship_combat/pod_launcher/tube = in_launch_tube()
	tube?.update_appearance()

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
	// Loaded into an assault pod tube: the orbital drop is off the table, the
	// weapons officer owns the launch now.
	tgui_data["inTube"] = in_launch_tube() ? TRUE : FALSE
	// Has the pod already been launched?
	tgui_data["used"] = used
	return tgui_data

/obj/structure/closet/supplypod/drop_pod/ui_static_data(mob/user)
	. = ..()
	.["teleporterLinked"] = linked_pad ? TRUE : FALSE

/// The tube this pod is sitting in, if any. A pod in a tube is ordnance and
/// can't fire its own descent - see ship_combat/assault_pod.dm.
/obj/structure/closet/supplypod/drop_pod/proc/in_launch_tube()
	return istype(loc, /obj/machinery/ship_combat/pod_launcher) ? loc : null

/// Moving inside a tube-racked pod climbs back out through the open hatch.
/// A sealed hatch stays sealed - opening it is a deliberate act, not a fidget,
/// because an open hatch takes the tube off the weapons console's ready list.
/obj/structure/closet/supplypod/drop_pod/relaymove(mob/living/user, direction)
	var/obj/machinery/ship_combat/pod_launcher/tube = in_launch_tube()
	if(!tube)
		return ..()
	if(user.stat)
		return
	if(!opened)
		if(message_cooldown <= world.time)
			message_cooldown = world.time + 5 SECONDS
			to_chat(user, span_warning("The hatch is sealed. Open it through the pod's interface to climb out."))
		return
	user.forceMove(tube.drop_location())
	user.visible_message(
		span_notice("[user] climbs out of [tube]."),
		span_notice("You climb out of [tube]."),
	)

// The tube's sprite tracks the racked pod's hatch, so every path that touches
// the door has to poke it - UI buttons, crowbars and landings alike.
/obj/structure/closet/supplypod/drop_pod/setOpened()
	. = ..()
	var/obj/machinery/ship_combat/pod_launcher/tube = in_launch_tube()
	tube?.update_appearance()

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
			if(in_launch_tube())
				balloon_alert(ui_user, "loaded in tube!")
				to_chat(ui_user, span_warning("The pod is racked in a launch tube - the weapons system controls this launch."))
				return
			// ui.close() nulls ui_user via ui_close - grab the user first
			var/mob/living/drop_user = ui_user
			ui.close()
			choose_random_drop_location(drop_user)
		if("map")
			if(opened)
				balloon_alert(ui_user, "close doors first!")
				to_chat(ui_user, text = "cannot use pod mapping as doors are not closed")
				return
			if(in_launch_tube())
				balloon_alert(ui_user, "loaded in tube!")
				to_chat(ui_user, span_warning("The pod is racked in a launch tube - the weapons system controls this launch."))
				return
			// ui.close() nulls ui_user via ui_close - grab the user first. map_user is
			// only claimed inside activate_map once the eye is actually granted, so a
			// failed activation can't leave the pod flagged "in use" forever.
			var/mob/living/eye_user = ui_user
			ui.close()
			activate_map(eye_user)
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

		if(!obj_to_insert.anchored && reverse_option_list["Objects"])
			return TRUE
		if(obj_to_insert.anchored && !ismecha(obj_to_insert) && reverse_option_list["Anchored"]) //Mecha are anchored but there is a separate option for them
			return TRUE
		if(ismecha(obj_to_insert) && reverse_option_list["Mecha"])
			return TRUE
		return FALSE

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

/**
 * The mobile port this pod is currently inside, resolved on demand.
 *
 * Must not be cached from Initialize(). Lathes build designs in nullspace
 * (`new design.build_path(null)`, _production.dm) and only move them onto a turf
 * afterwards, so an Initialize()-time lookup runs with no turf at all and
 * get_containing_shuttle() can never match a port - leaving every lathe-printed pod
 * with a null ship_port for the rest of the round, reporting "no celestial body
 * below" over a fully loaded planet. Pods also get dragged between ships, which a
 * one-shot cache never sees either.
 */
/obj/structure/closet/supplypod/drop_pod/proc/get_ship_port()
	if(ship_port && !QDELETED(ship_port) && ship_port.is_in_shuttle_bounds(src))
		return ship_port
	ship_port = SSshuttle.get_containing_shuttle(src)
	return ship_port

/obj/structure/closet/supplypod/drop_pod/proc/get_current_planet()
	var/obj/docking_port/mobile/voidcrew/port = get_ship_port()
	if(!port)
		return
	var/obj/structure/overmap/ship/our_ship = port.current_ship
	if(!our_ship)
		return
	var/obj/structure/overmap/planet/current_planet
	var/list/current_overmap_objects = our_ship.close_overmap_objects

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
	if(!eyeobj) //Eye creation failed - the pod isn't aboard a ship, so there's no orbit to drop from
		balloon_alert(user, "pod not aboard a ship!")
		return
	map_user = L
	if(!eye_initialized)
		var/turf/camera_location = get_map_start_turf(current_planet, planet_z_level)
		if(camera_location)
			eye_initialized = TRUE
			give_eye_control(L)
			eyeobj.setLoc(camera_location)
		else
			remove_eye_control(L)
	else
		give_eye_control(L)
		eyeobj.setLoc(eyeobj.loc)

/**
 * The slot the planet below occupies on its z-level, or null when it has none.
 *
 * A planet z-level is shared with up to three co-tenants, separated only by a strip of
 * cordon (see /datum/map_footprint). "The planet below" therefore means this rectangle,
 * not this z - `SSmapping.areas_in_z` and the camera eye both cross the gutter happily.
 * Null falls every caller back to the whole-z behaviour they had before packing.
 */
/obj/structure/closet/supplypod/drop_pod/proc/get_target_footprint()
	var/obj/structure/overmap/planet/current_planet = get_current_planet()
	return current_planet?.footprint

/**
 * Where the targeting camera starts. Dynamic planets occupy a bounded footprint
 * centered in their z-level, with a dense cordon filling the rest - so (1,1) sits
 * inside the cordon, not on the planet. The reserve dock is always on the surface;
 * fall back to the center of the planet's own footprint if it's somehow gone.
 */
/obj/structure/closet/supplypod/drop_pod/proc/get_map_start_turf(obj/structure/overmap/planet/current_planet, planet_z_level)
	if(current_planet.reserve_dock)
		return get_turf(current_planet.reserve_dock)
	// The footprint, not the level: on a packed level the level's bounds describe the
	// whole z, whose centre is the gutter between tenants.
	var/turf/center = current_planet.footprint?.get_center_turf()
	if(center)
		return center
	var/datum/space_level/level = current_planet.mapzone.z_levels[1]
	if(!isnull(level.low_x))
		return locate(round((level.low_x + level.high_x) / 2), round((level.low_y + level.high_y) / 2), planet_z_level)
	return locate(round(world.maxx / 2), round(world.maxy / 2), planet_z_level)

/obj/structure/closet/supplypod/drop_pod/proc/choose_random_drop_location(mob/user)
	if(used)
		return
	var/obj/structure/overmap/planet/current_planet = get_current_planet()
	if(!current_planet)
		// Same failure the map path messages at activate_map(); a silent return here
		// reads as the pod just not working (space ruins are not planets, so this is
		// the branch everyone hits trying to pod into one).
		balloon_alert(user, "no current planet!")
		return
	var/planet_z_level = get_planet_z(current_planet)
	if(!planet_z_level)
		balloon_alert(user, "planet not surveyed!")
		return
	// Every co-tenant's surface areas are registered under the same z, so this list is
	// "areas on the level", not "areas on the planet below". The footprint is what makes
	// the difference; the turf filter further down is where it is applied.
	var/datum/map_footprint/footprint = current_planet.footprint
	var/list/area/planet_areas = list()
	for (var/area/candidate_area in SSmapping.areas_in_z["[planet_z_level]"])
		if(istype(candidate_area, /area/overmap_encounter/planetoid/cave))
			continue
		if(istype(candidate_area, /area/overmap_encounter/planetoid))
			planet_areas |= candidate_area
	if(length(planet_areas) < 1)
		if(debug_enabled && istype(current_planet, /obj/structure/overmap/planet/empty))
			var/area/space/space_area = get_area_instance_from_text("/area/space")
			if(space_area)
				planet_areas += space_area
		if(length(planet_areas) < 1)
			balloon_alert(user, "nowhere to land")
			return
	// Planet z-levels are recycled, and areas_in_z still lists areas from previous
	// occupants that no longer hold any turfs here. Exhaust the list instead of a
	// fixed number of tries so stale areas can't eat every attempt.
	while (length(planet_areas))
		var/area/chosen_area = pick(planet_areas)
		planet_areas -= chosen_area
		var/list/turf_list = get_area_turfs(chosen_area, planet_z_level)
		// get_area_turfs() collapses its argument to a TYPEPATH, so it hands back every
		// area of that type on the z - including a same-biome co-tenant's ground. Without
		// this, "random drop on the planet below" lands on the neighbour.
		if(footprint && length(turf_list))
			var/list/turf/inside = list()
			for(var/turf/candidate_turf as anything in turf_list)
				if(footprint.contains_turf(candidate_turf))
					inside += candidate_turf
			turf_list = inside
		var/turf/target
		while (length(turf_list) && !target)
			var/list_index = rand(1, turf_list.len)
			var/turf/checked_turf = turf_list[list_index]
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
				turf_list.Cut(list_index, list_index + 1)
		if (target)
			set_anchored(TRUE)
			new /obj/effect/pod_landingzone/drop_pod(target, src)
			used = TRUE
			update_static_data(user)
			return
	balloon_alert(user, "nowhere to land")

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
	var/obj/docking_port/mobile/voidcrew/port = get_ship_port()
	if(!port)
		return
	eyeobj = new /mob/eye/camera/drop_pod(null, src)
	eyeobj.pod_origin = src
	var/turf/ship_port_location = locate(port.x, port.y, port.z)
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
				to_chat(map_user, span_warning("Landing site blocked. Pods can only drop onto open ground on the surface below - not solid rock, chasms, or restricted airspace. Pick a clear surface tile."))
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

	// The camera eye ignores density, so the cordon between two tenants does not stop it
	// from scrolling onto a neighbouring planet the crew never surveyed. This is the gate
	// that does - it colours the crosshair red as the eye crosses the gutter, and
	// placeLandingSpot() refuses anything that is not LANDING_CLEAR.
	var/datum/map_footprint/footprint = get_target_footprint()
	if(footprint && !footprint.contains_turf(eyeturf))
		var/image/out_of_range = eyeobj?.placement_image
		if(out_of_range)
			out_of_range.loc = eyeturf
			out_of_range.icon_state = "red"
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

	// Dense turfs are the planet cordon, mountains and unmined rock - a pod that
	// lands in one entombs its passengers. Groundless turfs drop them into nothing.
	// Dense objects stay targetable: supply pods crush what they land on.
	if(T.density || isgroundlessturf(T))
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
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(check_if_user_in_range))

/obj/structure/closet/supplypod/drop_pod/proc/check_if_user_in_range()
	SIGNAL_HANDLER
	remove_eye_control(map_user)

/obj/structure/closet/supplypod/drop_pod/proc/remove_eye_control(mob/living/user)
	// Clean up even if the user is gone or clientless - otherwise the pod stays
	// flagged as in-use forever and the eye leaks
	if(user)
		UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
		for(var/datum/action/actions_removed as anything in actions)
			actions_removed.Remove(user)
		user.reset_perspective(null)
		if(user.client && eyeobj)
			user.client.images -= eyeobj.placed_image
			user.client.images -= eyeobj.placement_image
		if(user.remote_control == eyeobj)
			user.remote_control = null

	eyeobj?.clear_camera_chunks()
	map_user = null
	eye_initialized = FALSE
	playsound(src, 'sound/machines/terminal/terminal_off.ogg', 25, FALSE)
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
