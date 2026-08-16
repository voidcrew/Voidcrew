/obj/machinery/mecha_part_fabricator/multitool_act(mob/living/user, obj/item/multitool/tool)
	. = ..()
	on_techweb_update()

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
