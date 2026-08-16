/**
  * ### Ion Engines
  * Engines that convert electricity to thrust. Yes, I know that's not how it works, it needs a propellant, but this is a video game.
  */
/obj/machinery/power/shuttle_engine/ship/electric
	name = "ion thruster"
	desc = "A thruster that expels charged particles to generate thrust."
	icon_state = "burst"
	circuit = /obj/item/circuitboard/machine/engine/electric
	engine_power = 10

	icon_state_off = "burst_off"
	icon_state_closed = "burst"
	icon_state_open = "burst_open"

	///Amount, in kilojoules, needed for a full burn.
	var/power_per_burn = 50000

/obj/machinery/power/shuttle_engine/ship/electric/update_engine()
	. = ..()
	if(!.)
		return FALSE
	thruster_active = !!powernet
	return thruster_active

/obj/machinery/power/shuttle_engine/ship/electric/on_construction()
	. = ..()
	connect_to_network()

/obj/machinery/power/shuttle_engine/ship/electric/examine(mob/user)
	. = ..()
	if(!powernet)
		. += span_warning("It is not connected to a power grid. It needs a cable under it.")
	else if(!avail() && !newavail())
		. += span_warning("Its power grid is supplying nothing. Burns draw live power off the wire, \
			not stored charge - check the SMES output and the cabling.")

/obj/machinery/power/shuttle_engine/ship/electric/thrust_refusal_reason()
	if(!powernet)
		return "no powered cable under it."
	if(!avail() && !newavail())
		return "its power grid is supplying nothing. Burns draw live power off the wire, not stored \
			charge - check the SMES output and the cabling."
	return ..()

/obj/machinery/power/shuttle_engine/ship/electric/burn_engine(percentage = 100, ship_mass = REFERENCE_SHIP_MASS, burn_seconds = 1)
	. = ..()
	var/mass_multiplier = get_mass_fuel_multiplier(ship_mass)
	var/power_needed = power_per_burn * (percentage / 100) * mass_multiplier * burn_seconds
	if(power_needed <= 0)
		return 0
	var/available_power = max(avail(), newavail())
	var/true_percentage = min(available_power / power_needed, 1)
	add_delayedload(power_needed * true_percentage)
	return engine_power * true_percentage

/obj/machinery/power/shuttle_engine/ship/electric/return_fuel()
	// Burns draw live wattage off the wire (see burn_engine), not stored charge. A
	// full SMES with its output disabled would otherwise read 100% on the helm while
	// the engine produces nothing, report a dead wire as an empty tank instead.
	if(!avail() && !newavail())
		return 0
	if(length(powernet?.nodes) >= 1)
		for(var/obj/machinery/power/smes/S in powernet.nodes)
			return S.total_charge()
	return avail()

/obj/machinery/power/shuttle_engine/ship/electric/return_fuel_cap()
	if(length(powernet?.nodes) >= 1)
		for(var/obj/machinery/power/smes/S in powernet.nodes)
			return S.total_capacity
	return power_per_burn
