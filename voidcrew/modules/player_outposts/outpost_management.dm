/**
 * # Outpost Management Console
 *
 * A physical launcher for the same claim-bound panel as the owner HUD action.
 * Visitors can inspect the registry here; authority remains claim-owned.
 *
 * The circuit board exists so a raided or deconstructed console can be
 * rebuilt, a fresh console relinks to the outpost whose z-level it's on.
 */

/obj/item/circuitboard/computer/player_outpost_management
	name = "Outpost Management (Computer Board)"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/computer/player_outpost_management

/obj/machinery/computer/player_outpost_management
	name = "outpost management console"
	desc = "Colonial registry terminal for the outpost's owner: naming, docking control, broadcasts and builder authorization."
	icon_screen = "id"
	icon_keyboard = "id_key"
	circuit = /obj/item/circuitboard/computer/player_outpost_management
	light_color = LIGHT_COLOR_ORANGE
	/// The outpost this console manages (set by link_interior_machinery, or found on Initialize for rebuilt consoles)
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// Reused claim-bound UI; the console is only a compatible physical launcher.
	var/list/datum/player_outpost_management_ui/panels = list()

// Machinery always late-initializes; consoles the shell spawned get linked by
// link_interior_machinery, hand-rebuilt ones relink to their z-level's outpost here
/obj/machinery/computer/player_outpost_management/LateInitialize()
	. = ..()
	outpost = get_outpost_from_atom(src)
	if(outpost && !outpost.management_console)
		outpost.management_console = src

/obj/machinery/computer/player_outpost_management/Destroy()
	var/list/closing_panels = panels
	panels = list()
	QDEL_LIST(closing_panels)
	if(outpost?.management_console == src)
		outpost.management_console = null
	outpost = null
	return ..()

/// Docking requests changed server-side; refresh the physical views.
/obj/machinery/computer/player_outpost_management/proc/on_dock_requests_changed()
	for(var/datum/player_outpost_management_ui/panel as anything in panels)
		SStgui.update_uis(panel)

/obj/machinery/computer/player_outpost_management/ui_interact(mob/user, datum/tgui/ui)
	outpost = get_outpost_from_atom(src)
	if(!outpost)
		balloon_alert(user, "no outpost link")
		return
	for(var/datum/player_outpost_management_ui/panel as anything in panels.Copy())
		if(panel.manager != user)
			continue
		if(panel.outpost == outpost && panel.console_turf == get_turf(src))
			panel.ui_interact(user)
			return
		qdel(panel)
	var/datum/player_outpost_management_ui/new_panel = new(outpost, user, src)
	panels += new_panel
	new_panel.ui_interact(user)

/// Preserve the existing minded, non-dead player eligibility on every claim-owned site.
/obj/structure/overmap/dynamic/player_outpost/proc/is_management_candidate(mob/living/candidate)
	return istype(candidate) && !QDELETED(candidate) && !QDELETED(candidate.mind) && candidate.ckey \
		&& candidate.stat != DEAD && get_outpost_from_atom(candidate) == src
