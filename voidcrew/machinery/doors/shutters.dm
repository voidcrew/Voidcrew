/obj/machinery/door/poddoor/shutters
	gender = PLURAL
	name = "shutters"
	desc = "Heavy duty mechanical shutters with an atmospheric seal that keeps them airtight once closed."
	damage_deflection = 30
	max_integrity = 200
	assembly_type = /obj/machinery/door/poddoor/shutters/preopen/deconstructed

/obj/machinery/door/poddoor/shutters/on_deconstruction(disassembled)
	var/obj/structure/door_assembly/A
	if(assembly_type)
		A = new assembly_type(loc)
	else
		A = new /obj/structure/door_assembly(loc)

	if(!disassembled)
		A?.update_integrity(A.max_integrity * 0.5)
		// VOIDCREW: this exact wrecked frame belongs to the recorded destruction.
		record_ship_repair_wreckage(src, A)

/datum/armor/poddoor_shutters
	melee = 30
	bullet = 30
	laser = 30
	energy = 75
	bomb = 25
	fire = 100
	acid = 70
