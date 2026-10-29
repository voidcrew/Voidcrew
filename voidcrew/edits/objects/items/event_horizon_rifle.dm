// Keep the upstream rifle's behaviour, without its scope.
/obj/item/gun/energy/event_horizon/Initialize(mapload)
	. = ..()
	qdel(GetComponent(/datum/component/scope))

/obj/item/gun/energy/event_horizon/process_fire(atom/target, mob/living/user, message, params, zone_override, bonus_spread)
	// Deliberately bypass the upstream rifle's scope check, retaining the energy gun's firing chain.
	. = call(src, /obj/item/gun/energy::process_fire())(arglist(args))
	message_admins("[ADMIN_LOOKUPFLW(user)] has fired an anti-existential beam at [ADMIN_VERBOSEJMP(user)].")
