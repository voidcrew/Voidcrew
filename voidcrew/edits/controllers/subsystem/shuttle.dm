// Voidcrew extensions to code/controllers/subsystem/shuttle.dm.

/datum/controller/subsystem/shuttle/proc/action_load_impl(datum/map_template/shuttle/loading_template, obj/docking_port/stationary/destination_port, replace, datum/shuttle_template_load/load_owner)
	if(destination_port && QDELETED(destination_port))
		return FALSE
	// Check for an existing preview
	if(preview_shuttle && (loading_template != preview_template))
		preview_shuttle.jumpToNullSpace()
		preview_shuttle = null
		preview_template = null
		QDEL_NULL(preview_reservation)

	if(!preview_shuttle)
		load_template(loading_template, load_owner)
		// VOIDCREW EDIT: load_template() can now refuse gracefully (no transit
		// reservation free - see the capacity note in it). Without this bail the null
		// preview fell through to generate_transit_dock(null) and a CRASH of its own.
		if(!preview_shuttle)
			return
		preview_template = loading_template

	// get the existing shuttle information, if any
	var/timer = 0
	var/mode = SHUTTLE_IDLE
	var/obj/docking_port/stationary/dest_dock

	if(istype(destination_port))
		dest_dock = destination_port
	else if(existing_shuttle && replace)
		timer = existing_shuttle.timer
		mode = existing_shuttle.mode
		dest_dock = existing_shuttle.get_docked()

	if(!dest_dock)
		dest_dock = generate_transit_dock(preview_shuttle)

	if(!dest_dock)
		CRASH("No dock found for preview shuttle ([preview_template.name]), aborting.")

	var/result = preview_shuttle.canDock(dest_dock)
	// truthy value means that it cannot dock for some reason
	// but we can ignore the someone else docked error because we'll
	// be moving into their place shortly
	if((result != SHUTTLE_CAN_DOCK) && (result != SHUTTLE_SOMEONE_ELSE_DOCKED))
		CRASH("Template shuttle [preview_shuttle] cannot dock at [dest_dock] ([result]).")

	if(existing_shuttle && replace)
		existing_shuttle.jumpToNullSpace()

	preview_shuttle.register(replace)
	var/list/force_memory = preview_shuttle.movement_force
	preview_shuttle.movement_force = list("KNOCKDOWN" = 0, "THROW" = 0)
	preview_shuttle.mode = SHUTTLE_PREARRIVAL//No idle shuttle moving. Transit dock get removed if shuttle moves too long.
	preview_shuttle.initiate_docking(dest_dock)
	preview_shuttle.movement_force = force_memory

	. = preview_shuttle

	// Shuttle state involves a mode and a timer based on world.time, so
	// plugging the existing shuttles old values in works fine.
	preview_shuttle.timer = timer
	preview_shuttle.mode = mode

	preview_shuttle.postregister(replace)

	// TODO indicate to the user that success happened, rather than just
	// blanking the modification tab
	preview_shuttle = null
	preview_template = null
	existing_shuttle = null
	selected = null
	QDEL_NULL(preview_reservation)

/datum/controller/subsystem/shuttle/proc/load_template_impl(datum/map_template/shuttle/loading_template, datum/shuttle_template_load/load_owner)
	unload_preview(load_owner)
	. = FALSE
	// Load shuttle template to a fresh block reservation.
	preview_reservation = SSmapping.request_turf_block_reservation(
		loading_template.width,
		loading_template.height,
		1,
		reservation_type = /datum/turf_reservation/transit,
		requester = "shuttle template preview '[loading_template.name]'", // VOIDCREW EDIT: z-mint attribution
	)
	if(!preview_reservation)
		// VOIDCREW EDIT: a null here is usually request_turf_block_reservation() refusing
		// because world.maxz is at its configured ceiling and the reserved levels are
		// momentarily full - a capacity condition that clears in seconds as transits
		// recycle, not a code fault. The CRASH this used to be unwound create_ship() into
		// "there was an error, contact admins" for every buyer who clicked at the wrong
		// moment. Refuse gracefully instead; callers already handle a missing preview.
		log_mapping("SSshuttle: load_template refused - no transit reservation for [loading_template.width]x[loading_template.height] '[loading_template.name]'[SSmapping.at_z_level_ceiling() ? " (world.maxz at its ceiling)" : ""]")
		return FALSE
	var/turf/bottom_left = preview_reservation.bottom_left_turfs[1]
	loading_template.load(bottom_left, centered = FALSE, register = FALSE)

	var/affected = loading_template.get_affected_turfs(bottom_left, centered=FALSE)

	var/found = 0
	// Search the turfs for docking ports
	// - We need to find the mobile docking port because that is the heart of
	//   the shuttle.
	// - We need to check that no additional ports have slipped in from the
	//   template, because that causes unintended behaviour.
	for(var/affected_turfs in affected)
		for(var/obj/docking_port/port in affected_turfs)
			if(istype(port, /obj/docking_port/mobile))
				found++
				if(found > 1)
					qdel(port, force=TRUE)
					log_mapping("Shuttle Template [loading_template.mappath] has multiple mobile docking ports.")
				else
					preview_shuttle = port
			if(istype(port, /obj/docking_port/stationary))
				log_mapping("Shuttle Template [loading_template.mappath] has a stationary docking port.")
	if(!found)
		var/msg = "load_template(): Shuttle Template [loading_template.mappath] has no mobile docking port. Aborting import."
		for(var/affected_turfs in affected)
			var/turf/T0 = affected_turfs
			T0.empty()

		message_admins(msg)
		WARNING(msg)
		return
	//Everything fine
	loading_template.post_load(preview_shuttle)
	return TRUE

/datum/controller/subsystem/shuttle/proc/unload_preview_impl(datum/shuttle_template_load/load_owner)
	if(preview_shuttle)
		preview_shuttle.jumpToNullSpace()
	preview_shuttle = null
	preview_template = null
	if(preview_reservation)
		QDEL_NULL(preview_reservation)
