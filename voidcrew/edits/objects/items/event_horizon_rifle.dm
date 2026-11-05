// Keep the upstream rifle's behaviour, without its scope.
/obj/item/gun/energy/event_horizon/Initialize(mapload)
	. = ..()
	qdel(GetComponent(/datum/component/scope))
