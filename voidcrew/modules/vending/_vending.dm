/obj/machinery/vending/Initialize(mapload)
	. = ..()
	onstation = FALSE
	//if(circuit)
	//	circuit.onstation = FALSE // TODO: Fix circuit.onstation

/**
 * tg's sustenance vendor turns away anyone without a prisoner ID unless it carries an
 * access list. Ship hulls map it in mess halls and brigs where nobody has one, and the
 * crewed-ship access waiver only applies to machines that have req_access at all.
 */
/obj/machinery/vending/sustenance
	req_access = list(ACCESS_BRIG)
