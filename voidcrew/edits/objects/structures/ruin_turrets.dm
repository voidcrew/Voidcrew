/// Keep the installed gun's firing properties without leaving a recoverable weapon.
/obj/machinery/porta_turret/ruin
	installation = /obj/item/gun/energy/lasercannon
	uses_stored = FALSE

/obj/machinery/porta_turret/ruin/setup(obj/item/gun/turret_gun)
	. = ..()
	QDEL_NULL(stored_gun)

/obj/machinery/porta_turret/ai/ruin
	uses_stored = FALSE

/obj/machinery/porta_turret/ai/ruin/setup(obj/item/gun/turret_gun)
	. = ..()
	QDEL_NULL(stored_gun)
