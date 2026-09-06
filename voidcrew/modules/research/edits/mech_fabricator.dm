/obj/machinery/mecha_part_fabricator/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/mecha_part_fabricator/unsync_research_servers()
	if(stored_research)
		UnregisterSignal(stored_research, list(COMSIG_TECHWEB_ADD_DESIGN, COMSIG_TECHWEB_REMOVE_DESIGN))
		stored_research.connected_machines -= src
		stored_research = null
	// Locally installed designs and already-paid work do not belong to the disk.
	cached_designs.Cut()
	cached_designs |= illegal_local_designs
	if(!QDELETED(src))
		update_static_data_for_all_viewers()

/obj/machinery/mecha_part_fabricator/connect_techweb(datum/techweb/new_techweb)
	if(new_techweb && !can_link_site_techweb(src, new_techweb))
		return FALSE
	unsync_research_servers()
	. = ..()
	if(stored_research)
		stored_research.connected_machines |= src

/obj/machinery/mecha_part_fabricator/multitool_act(mob/living/user, obj/item/multitool/tool)
	var/has_techweb_buffer = !QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb)
	if(has_techweb_buffer && !can_link_site_techweb(src, tool.buffer))
		balloon_alert(user, "server belongs to another site")
		return FALSE
	. = ..()
	if(. && has_techweb_buffer && stored_research == tool.buffer)
		say("Linked to Server!")

/**
 * Output-direction affordances the exofab was missing.
 *
 * The autolathe and protolathe both let you drag them towards a tile to aim
 * where prints drop, alt-click to reset, and say so on examine. The exofab
 * supported the drag but never said so, and had no reset at all - playtest
 * rounds 14/15 had multiple players asking how to "rotate" it and how to make
 * it stop dropping sideways, with no answer available in game. These overrides
 * bring it to parity. Reset means drop_direction = 0: parts land on the
 * fabricator's own tile, same as a reset autolathe (the upstream examine line
 * in code/modules/vehicles/mecha/mech_fabricator.dm covers that state).
 */
/obj/machinery/mecha_part_fabricator/examine(mob/user)
	. = ..()
	if(!in_range(user, src) && !isobserver(user))
		return
	if(drop_direction)
		. += span_notice("[EXAMINE_HINT("Alt-click")] to reset, dropping printed objects onto its own tile.")
	. += span_notice("[EXAMINE_HINT("Drag")] towards a direction (while next to it) to change drop direction.")

/obj/machinery/mecha_part_fabricator/click_alt(mob/user)
	if(!drop_direction)
		return CLICK_ACTION_BLOCKING
	if(being_built)
		balloon_alert(user, "busy printing!")
		return CLICK_ACTION_BLOCKING
	balloon_alert(user, "drop direction reset")
	drop_direction = 0
	return CLICK_ACTION_SUCCESS

/obj/machinery/mecha_part_fabricator/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(drop_direction)
		context[SCREENTIP_CONTEXT_ALT_LMB] = "Reset Drop"
		return CONTEXTUAL_SCREENTIP_SET
