/// Temporary compatibility for outpost maps until their imprinter placements are removed.
/obj/machinery/blueprint_imprinter/Initialize(mapload)
	. = ..()
	return INITIALIZE_HINT_QDEL
