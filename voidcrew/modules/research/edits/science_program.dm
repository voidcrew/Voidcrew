/// A program is a consumer of the physical disk, while its installed tablet determines its site.
/datum/computer_file/program/science/Destroy()
	unsync_research_servers()
	return ..()

/datum/computer_file/program/science/unsync_research_servers()
	if(stored_research)
		stored_research.connected_machines -= src
		stored_research = null

/datum/computer_file/program/science/on_install(datum/computer_file/source, obj/item/modular_computer/computer_installing)
	. = ..()
	if(validate_research_link())
		stored_research.connected_machines |= src

/datum/computer_file/program/science/proc/validate_research_link()
	if(!stored_research)
		return FALSE
	if(computer && length(stored_research.techweb_servers) && can_link_site_techweb(computer, stored_research))
		return TRUE
	if(!research_link_in_transit(computer, stored_research))
		unsync_research_servers()
	return FALSE

/datum/computer_file/program/science/multitool_act(mob/living/user, obj/item/multitool/used_multitool)
	if(!computer || QDELETED(used_multitool.buffer) || !istype(used_multitool.buffer, /datum/techweb))
		return ITEM_INTERACT_BLOCKING
	var/datum/techweb/new_web = used_multitool.buffer
	if(!length(new_web.techweb_servers) || !can_link_site_techweb(computer, new_web))
		computer.balloon_alert(user, "no local research server")
		return ITEM_INTERACT_BLOCKING
	unsync_research_servers()
	. = ..()
	if(stored_research == new_web)
		stored_research.connected_machines |= src

/datum/computer_file/program/science/ui_data(mob/user)
	validate_research_link()
	return ..()

/datum/computer_file/program/science/enqueue_node(id, mob/user)
	if(!validate_research_link())
		return FALSE
	return ..()

/datum/computer_file/program/science/dequeue_node(id, mob/user)
	if(!validate_research_link())
		return FALSE
	return ..()

/datum/computer_file/program/science/research_node(id, mob/user)
	if(!validate_research_link())
		return FALSE
	return ..()
