/obj/machinery/computer/dna_console/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/computer/dna_console/unsync_research_servers()
	if(stored_research)
		stored_research.connected_machines -= src
		stored_research = null

/obj/machinery/computer/dna_console/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		balloon_alert(user, "no techweb in buffer!")
		return TRUE
	if(!can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	if(stored_research)
		stored_research.connected_machines -= src
	. = ..()
	if(. && stored_research == tool.buffer)
		stored_research.connected_machines |= src
		say("Linked to Server!")
		return TRUE
