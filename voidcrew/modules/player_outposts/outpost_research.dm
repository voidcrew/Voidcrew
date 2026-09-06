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

/// Physical links stay local even when another ship shares the same z level.
/datum/component/remote_materials/check_z_level(obj/silo_to_check = silo)
	return silo_to_check && same_service_site(parent, silo_to_check)

/proc/can_link_site_techweb(atom/machine, datum/techweb/web)
	if(!web)
		return FALSE
	if(!web.requires_physical_server && !get_service_site(machine) && !length(web.techweb_servers))
		return TRUE
	for(var/obj/machinery/rnd/server/server as anything in web.techweb_servers)
		if(server.research_link_available(machine))
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
