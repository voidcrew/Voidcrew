/**
 * Destructive analyzer on ship techwebs.
 *
 * no_default_techweb_link is TRUE fork-wide (voidcrew/edits/config.dm), so a freshly built
 * analyzer holds no techweb until someone multitools one into it - unlinked is its normal
 * starting state here, not an edge case. Upstream reports that state to the UI as
 * data["server_connected"] and then dereferences stored_research two lines later anyway:
 * ui_data() reads stored_research.deconstructed_items and .hidden_nodes, and
 * destroy_item_individual() writes to deconstructed_items. Loading an item into an unlinked
 * analyzer and opening it therefore runtimed, and the window came up with nothing in it and no
 * explanation.
 *
 * Rather than duplicate the whole of upstream's ui_data to guard it, keep the machine out of
 * that state: it refuses to load while unlinked, and gives the item back if its server goes away.
 */
/obj/machinery/rnd/destructive_analyzer/examine(mob/user)
	. = ..()
	if(isnull(stored_research))
		. += span_warning("It is not linked to a research server, so it cannot analyse anything. Link it using a multitool with a research server's data in its buffer.")

/obj/machinery/rnd/destructive_analyzer/is_insertion_ready(mob/user)
	if(isnull(stored_research))
		balloon_alert(user, "no server linked!")
		return FALSE
	return ..()

/obj/machinery/rnd/destructive_analyzer/unsync_research_servers()
	// Losing the server mid-load would leave the machine runtiming on every UI update, so hand
	// the item back. This also runs from Destroy(), where dropping it beats having
	// /atom/movable/Destroy() delete it along with the rest of the machine's contents.
	unload_item()
	return ..()
