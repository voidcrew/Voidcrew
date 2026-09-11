/datum/survey_research/proc/merge_completed_surveys(datum/survey_research/source)
	if(!source || source == src)
		return
	for(var/category in source.survey_objects_by_type)
		var/list/destination = survey_objects_by_type[category]
		if(!destination)
			continue
		for(var/datum/surveyed_celestial_object/record as anything in source.survey_objects_by_type[category])
			if(!record.ref_id)
				continue
			var/datum/surveyed_celestial_object/existing
			for(var/datum/surveyed_celestial_object/candidate as anything in destination)
				if(candidate.ref_id == record.ref_id)
					existing = candidate
					break
			if(!existing)
				existing = new record.type
				record.copy(existing)
				destination += existing
			else if(record.recorded_at > existing.recorded_at)
				record.copy(existing)

/// RCD links work across ship boundaries and z levels; machines stay on their own service site.
/datum/component/remote_materials/check_z_level(obj/silo_to_check = silo)
	if(istype(parent, /obj/item/construction/rcd))
		var/turf/device_turf = get_turf(parent)
		var/turf/silo_turf = get_turf(silo_to_check)
		return device_turf && silo_turf
	return silo_to_check && same_service_site(parent, silo_to_check)

/// During a shuttle move, room ownership is already authoritative even while
/// the port's bounding box still points at the previous end of the move.
/proc/get_research_service_site(atom/machine)
	var/area/shuttle/voidcrew/ship_area = astype(get_area(machine))
	var/obj/structure/overmap/ship/ship = ship_area?.shuttle_port?.current_ship
	if(ship && (ship.state in list(OVERMAP_SHIP_DOCKING, OVERMAP_SHIP_UNDOCKING)) && (ship_area in ship.shuttle?.shuttle_areas))
		return ship
	return get_service_site(machine)

/proc/same_research_service_site(atom/first, atom/second)
	if(!first || !second)
		return FALSE
	var/obj/structure/overmap/first_site = get_research_service_site(first)
	var/obj/structure/overmap/second_site = get_research_service_site(second)
	if(first_site || second_site)
		return first_site && first_site == second_site
	return same_service_site(first, second)

/proc/can_link_site_techweb(atom/machine, datum/techweb/web)
	if(!web)
		return FALSE
	if(!web.requires_physical_server && !get_service_site(machine) && !length(web.techweb_servers))
		return TRUE
	for(var/obj/machinery/rnd/server/server as anything in web.techweb_servers)
		if(server.research_link_available(machine))
			return TRUE
	return FALSE

/// Preserve an existing link through temporary bounds/power changes during docking.
/// This does not authorize an operation or a new connection while the relay is offline.
/proc/research_link_in_transit(atom/machine, datum/techweb/web)
	for(var/obj/machinery/rnd/server/relay/relay in web?.techweb_servers)
		var/datum/outpost_research_link/link = relay.connection
		if(!QDELETED(link) && link.ship_approved && link.valid_endpoints() && link.ship_is_moving() && link.ship_contains_endpoint(relay) && link.ship_contains_endpoint(machine))
			return TRUE
	return FALSE

/obj/machinery/rnd/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()

/obj/machinery/mecha_part_fabricator/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()

/obj/machinery/component_printer/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	return ..()
