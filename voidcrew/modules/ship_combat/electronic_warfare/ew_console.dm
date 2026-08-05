/**
 * Electronic Warfare - weapons console integration
 *
 * Adds the EW suite link, UI data, and UI actions to the ship combat console
 * WITHOUT editing any file under voidcrew/modules/ship_combat/console/.
 * Everything here is var addition and duplicate-override chaining: this file
 * MUST be included after the console/ files in tgstation.dme (alphabetically
 * "electronic_warfare" sorts after "console", so the natural order works),
 * making these overrides the outermost link in each proc chain.
 *
 * Console deletion is handled from the suite's side (COMSIG_QDELETING handler,
 * siphon pattern) - no console Destroy override is needed here.
 */
/obj/machinery/computer/camera_advanced/ship_combat
	/// Linked electronic warfare suite (weakref)
	var/datum/weakref/linked_ew_ref

/obj/machinery/computer/camera_advanced/ship_combat/examine(mob/user)
	. = ..()
	var/obj/machinery/ship_combat/ew_suite/suite = linked_ew_ref?.resolve()
	if(suite)
		. += span_notice("Linked electronic warfare suite: [suite.name]")
	else
		. += span_warning("No electronic warfare suite linked. Use a multitool to link one.")

// ========== LINKING ==========

// Chained in front of console_linking.dm's multitool_act: consume an EW suite
// buffer here, pass everything else down the chain untouched.
/obj/machinery/computer/camera_advanced/ship_combat/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!istype(tool) || !istype(tool.buffer, /obj/machinery/ship_combat/ew_suite))
		return ..()

	var/obj/machinery/ship_combat/ew_suite/suite = tool.buffer

	// Check if already linked
	var/obj/machinery/ship_combat/ew_suite/current = linked_ew_ref?.resolve()
	if(current == suite)
		balloon_alert(user, "already linked")
		return ITEM_INTERACT_BLOCKING

	// Link the suite
	if(link_ew_suite(suite))
		balloon_alert(user, "ew suite linked")
		to_chat(user, span_notice("Linked [suite] to [src]."))
	else
		balloon_alert(user, "link failed")

	return ITEM_INTERACT_SUCCESS

/// Links an electronic warfare suite to this console
/obj/machinery/computer/camera_advanced/ship_combat/proc/link_ew_suite(obj/machinery/ship_combat/ew_suite/suite)
	if(!suite)
		return FALSE

	// Unlink any existing suite
	var/obj/machinery/ship_combat/ew_suite/old_suite = linked_ew_ref?.resolve()
	if(old_suite && old_suite != suite)
		old_suite.unlink_console()

	linked_ew_ref = WEAKREF(suite)
	suite.link_console(src)

	return TRUE

// ========== UI DATA ==========

/obj/machinery/computer/camera_advanced/ship_combat/ui_data(mob/user)
	var/list/data = ..()

	// Attacker-side suite panel
	var/obj/machinery/ship_combat/ew_suite/suite = linked_ew_ref?.resolve()
	if(!suite)
		linked_ew_ref = null
	data["ew_linked"] = !!suite
	data["ew"] = suite ? suite.get_status() : null

	// Target-side intrusion panel (null when clean)
	var/datum/component/ship_ew_intrusion/intrusion = current_ship?.GetComponent(/datum/component/ship_ew_intrusion)
	data["ew_intrusion"] = intrusion ? intrusion.get_status() : null

	return data

// ========== UI ACTIONS ==========

// The parent chain (console_ui.dm) runs its is_crew_member check before its
// switch and returns TRUE on failure, so a falsy return from ..() means the
// crew check already passed - no second guard here.
/obj/machinery/computer/camera_advanced/ship_combat/ui_act(action, list/params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	switch(action)
		if("ew_execute")
			var/obj/machinery/ship_combat/ew_suite/suite = linked_ew_ref?.resolve()
			if(!suite)
				to_chat(ui.user, span_warning("No electronic warfare suite linked! Link one with a multitool."))
				return FALSE
			var/obj/item/ew_exploit/chip = locate(params["chip_ref"]) in suite.loaded_chips
			if(!chip)
				to_chat(ui.user, span_warning("That cartridge is no longer loaded."))
				return FALSE
			return suite.execute_payload(chip, ui.user, params["mode"])

		if("ew_cancel")
			var/obj/machinery/ship_combat/ew_suite/suite = linked_ew_ref?.resolve()
			suite?.cancel_execution(ui.user)
			return TRUE

		if("ew_eject_chip")
			var/obj/machinery/ship_combat/ew_suite/suite = linked_ew_ref?.resolve()
			if(!suite)
				return FALSE
			var/obj/item/ew_exploit/chip = locate(params["chip_ref"]) in suite.loaded_chips
			if(!chip)
				return FALSE
			return suite.eject_chip(chip, ui.user)

		if("ew_purge_intrusion")
			var/datum/component/ship_ew_intrusion/intrusion = current_ship?.GetComponent(/datum/component/ship_ew_intrusion)
			if(!intrusion)
				to_chat(ui.user, span_notice("No active intrusion detected."))
				return TRUE
			intrusion.purge(ui.user)
			return TRUE

	return FALSE
