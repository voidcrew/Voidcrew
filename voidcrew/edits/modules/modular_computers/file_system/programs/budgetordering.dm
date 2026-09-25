// Voidcrew extensions to code/modules/modular_computers/file_system/programs/budgetordering.dm.

/**
 * This app is a remote control for the station's supply shuttle and the department
 * budget that pays for it. Neither exists here: every hull runs its own cargo shuttle
 * through /obj/machinery/computer/voidcrew_cargo, and SSshuttle.supply is deliberately
 * left null (see voidcrew/modules/cargo/shipping/cargo_shuttle.dm). The app is still
 * preinstalled on the head and cargo PDA presets, and running it walked ui_data()
 * straight into `null.getStatusText()`. A runtime only unwinds the proc it happened in,
 * so the computer's own ui_data() carried on and returned nothing but header data -
 * which NtosCargo.tsx cannot render. The player got a tgui blue screen and the PDA was
 * left on a dead window until they relogged and cleared their cache.
 *
 * Refuse to start instead. The check is deliberately in front of the parent call: the
 * parent returns TRUE early for silicons, admin ghosts and emagged computers, and none
 * of those can conjure a supply shuttle either.
 */
/datum/computer_file/program/budgetorders/can_run(mob/user, loud = FALSE, access_to_check, downloading = FALSE, list/access)
	if(isnull(SSshuttle.supply))
		if(loud && user)
			to_chat(user, span_warning("\The [computer] flashes an \"NTNet Error - requisition network unreachable\" warning."))
		return FALSE
	return ..()
