/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

/obj/machinery/computer/mission_board/criminal
	circuit = /obj/item/circuitboard/computer/mission_board/criminal

/obj/item/circuitboard/computer/mission_board/criminal
	build_path = /obj/machinery/computer/mission_board/criminal

/// Fills a pirate hull's board from the criminal pool. TRUE when it did.
/datum/controller/subsystem/missions/proc/refresh_criminal_missions(obj/structure/overmap/ship/ship)
	return FALSE
