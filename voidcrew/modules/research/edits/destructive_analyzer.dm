/**
 * Destructive analyzer on ship techwebs.
 *
 * no_default_techweb_link is TRUE fork-wide (voidcrew/edits/config.dm), so an analyzer has no
 * techweb until someone uses a multitool carrying a server's web on it, like every other R&D
 * machine. Two upstream assumptions broke that:
 * - Upstream loads any held item before the tool acts run, so a left-click with the multitool
 *   loaded the multitool into the analyzer instead of linking it. Only a right-click linked.
 * - ui_data() reads stored_research for any loaded item, so an unlinked analyzer holding an item
 *   runtimed while its window opened, and the window never appeared.
 */

/// A multitool carrying a new research web links on a left-click instead of being loaded as a sample.
/obj/machinery/rnd/destructive_analyzer/base_item_interaction(mob/living/user, obj/item/weapon, list/modifiers)
	if(!LAZYACCESS(modifiers, RIGHT_CLICK) && !user.combat_mode && is_techweb_link_tool(weapon))
		return tool_act(user, weapon, modifiers) || ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/rnd/destructive_analyzer/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	. = ..()
	if(!panel_open && is_techweb_link_tool(held_item?.get_proxy_attacker_for(src, user)))
		context[SCREENTIP_CONTEXT_LMB] = "Upload Techweb"
		return CONTEXTUAL_SCREENTIP_SET

/**
 * Whether this item is a multitool holding a research web we are not linked to yet.
 * Once linked to that web, the same multitool loads as a sample again, so alien multitools can
 * still be analyzed.
 */
/obj/machinery/rnd/destructive_analyzer/proc/is_techweb_link_tool(obj/item/tool)
	var/obj/item/multitool/linker = tool
	if(!istype(linker) || QDELETED(linker.buffer) || !istype(linker.buffer, /datum/techweb))
		return FALSE
	return linker.buffer != stored_research

/obj/machinery/rnd/destructive_analyzer/ui_data(mob/user)
	if(!QDELETED(stored_research))
		return ..()
	return list(
		"server_connected" = FALSE,
		"loaded_item" = null,
		"node_data" = list(),
	)

/// Nothing is broken down without a web to record it.
/obj/machinery/rnd/destructive_analyzer/destroy_item(gain_research_points = FALSE)
	if(QDELETED(stored_research))
		return FALSE
	return ..()
