/obj/machinery/rnd/production/Initialize(mapload)
	return ..()

/**
 * no_default_techweb_link is TRUE fork-wide, so a freshly built lathe has no techweb and its
 * Fabricator UI opens with an empty catalog and no explanation. Say why, and how to fix it.
 */
/obj/machinery/rnd/production/examine(mob/user)
	. = ..()
	if(isnull(stored_research))
		. += span_warning("It is not linked to a research server, so it has no designs. Link it using a multitool with a research server's data in its buffer.")

/obj/machinery/rnd/production/ui_interact(mob/user, datum/tgui/ui)
	// Only on a fresh open, so it doesn't repeat on every UI update
	if(isnull(stored_research) && !SStgui.get_open_ui(user, src))
		say("No research server linked. Upload a server techweb with a multitool to load designs.")
	return ..()
