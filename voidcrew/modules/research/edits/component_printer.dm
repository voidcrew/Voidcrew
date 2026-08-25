/**
 * Component printer on ship techwebs.
 *
 * no_default_techweb_link is TRUE fork-wide (voidcrew/edits/config.dm), so machines start with no
 * techweb and get multitooled to a ship server's web instead. Upstream's component printer assumes
 * techweb is always set: ui_static_data() and ui_act("print") walk techweb.researched_designs
 * unguarded, so an unlinked printer runtimes during ui.open() and the window never appears.
 * It also never joins connected_machines, so a destroyed server disk left it holding a dead web.
 */

/obj/machinery/component_printer/Destroy()
	unsync_research_servers()
	return ..()

/obj/machinery/component_printer/unsync_research_servers()
	if(isnull(techweb))
		return
	UnregisterSignal(techweb, list(COMSIG_TECHWEB_ADD_DESIGN, COMSIG_TECHWEB_REMOVE_DESIGN))
	techweb.connected_machines -= src
	techweb = null
	current_unlocked_designs.Cut()
	update_static_data_for_all_viewers()

/obj/machinery/component_printer/connect_techweb(datum/techweb/new_techweb)
	if(techweb)
		techweb.connected_machines -= src
		current_unlocked_designs.Cut()
	. = ..()
	if(techweb)
		techweb.connected_machines += src
	update_static_data_for_all_viewers()

/obj/machinery/component_printer/multitool_act(mob/living/user, obj/item/multitool/tool)
	var/has_techweb_buffer = !QDELETED(tool.buffer) && istype(tool.buffer, /datum/techweb)
	. = ..()
	if(. && has_techweb_buffer)
		say("Linked to Server!")

/obj/machinery/component_printer/ui_static_data(mob/user)
	if(!isnull(techweb))
		return ..()
	var/list/data = materials.mat_container.ui_static_data()
	data["designs"] = list()
	return data

/obj/machinery/component_printer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	if(action == "print" && isnull(techweb))
		say("No research server linked.")
		return TRUE
	return ..()

// Reached by integrated circuits printing remotely; an unlinked printer has no designs, and
// techweb_design_by_id(null) would hand back something ui_act's checks never see.
/obj/machinery/component_printer/print_component(typepath, alist/user_data)
	if(isnull(current_unlocked_designs[typepath]))
		return
	return ..()
