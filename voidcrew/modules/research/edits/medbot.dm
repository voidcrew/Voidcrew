/mob/living/basic/bot/medbot/Destroy()
	unsync_research_servers()
	return ..()

/mob/living/basic/bot/medbot/unsync_research_servers()
	if(linked_techweb)
		linked_techweb.connected_machines -= src
		linked_techweb = null

/mob/living/basic/bot/medbot/ui_data(mob/user)
	validate_research_site(linked_techweb)
	return ..()

/mob/living/basic/bot/medbot/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "sync_tech" && !validate_research_site(linked_techweb))
		to_chat(ui.user, span_notice("No local research techweb connected."))
		return TRUE
	return ..()

/mob/living/basic/bot/medbot/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(QDELETED(tool.buffer) || !istype(tool.buffer, /datum/techweb))
		balloon_alert(user, "no techweb in buffer!")
		return TRUE
	if(!can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	if(linked_techweb)
		linked_techweb.connected_machines -= src
	. = ..()
	if(. && linked_techweb == tool.buffer)
		linked_techweb.connected_machines |= src
		say("Linked to Server!")
		return TRUE
