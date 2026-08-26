/mob/living/basic/bot/medbot/Destroy()
	unsync_research_servers()
	return ..()

/mob/living/basic/bot/medbot/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null

/mob/living/basic/bot/medbot/multitool_act(mob/living/user, obj/item/multitool/tool)
	// The parent proc returns ITEM_INTERACT_SUCCESS whether or not it linked anything, so an empty
	// buffer used to fall straight through to `linked_techweb.connected_machines` below on a null.
	// Unlinked is the normal state for a ship's medbot, so this is the click people actually make.
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		balloon_alert(user, "no techweb in buffer!")
		return ITEM_INTERACT_BLOCKING
	if(linked_techweb) //disconnect old one
		linked_techweb.connected_machines -= src
	. = ..()
	if(.)
		linked_techweb.connected_machines += src //connect new one
		say("Linked to Server!")
		return TRUE
