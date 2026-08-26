/obj/machinery/computer/dna_console/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/computer/dna_console/unsync_research_servers()
	if(stored_research)
		stored_research.connected_machines -= src
		stored_research = null

/obj/machinery/computer/dna_console/multitool_act(mob/living/user, obj/item/multitool/tool)
	// The parent proc returns TRUE whether or not it linked anything, so an empty buffer used to
	// fall straight through to `stored_research.connected_machines` below on a null. Unlinked is
	// the normal state for a ship's DNA console, so this is the click people actually make.
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		balloon_alert(user, "no techweb in buffer!")
		return ITEM_INTERACT_BLOCKING
	if(stored_research) //disconnect old one
		stored_research.connected_machines -= src
	. = ..()
	if(.)
		stored_research.connected_machines += src //connect new one
		say("Linked to Server!")
		return TRUE
