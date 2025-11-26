#define ENGINE_HEAT_TARGET 600
#define ENGINE_HEATING_POWER 5000000

/**
  * ### Fueled engines
  * Shuttle engines that require a gas or gases to burn.
  */
/obj/machinery/power/shuttle_engine/ship/fueled
	name = "fueled thruster"
	desc = "A thruster that burns a specific gas that is stored in an adjacent heater."
	icon_state = "burst_plasma"
	icon_state_off = "burst_plasma_off"

	idle_power_usage = 0
	///The specific gas to burn out of the engine heater. If none, burns any gas.
	var/datum/gas/fuel_type
	///How much fuel (in mols) of the specified gas should be used in a full burn.
	var/fuel_use = 0
	///If this engine should create heat when burned.
	var/heat_creation = FALSE
	///A weakref of the connected engine heater with fuel.
	var/datum/weakref/attached_heater
	var/thrust = 0

/obj/machinery/power/shuttle_engine/ship/fueled/burn_engine(percentage = 100, ship_mass = REFERENCE_SHIP_MASS)
	..()
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/resolved_heater = attached_heater.resolve()
	if(heat_creation)
		heat_engine()
	var/mass_multiplier = get_mass_fuel_multiplier(ship_mass)
	var/to_use = fuel_use * (percentage / 100) * mass_multiplier
	var/actually_burned = resolved_heater?.consume_fuel(to_use, fuel_type)
	if(!actually_burned)
		return 0
	return (actually_burned / to_use) * thrust //This proc returns how much was actually burned, so let's use that and multiply it by the thrust to get all the thrust we CAN give.

/obj/machinery/power/shuttle_engine/ship/fueled/return_fuel()
	. = ..()
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/resolved_heater = attached_heater.resolve()
	return resolved_heater?.return_gas(fuel_type)

/obj/machinery/power/shuttle_engine/ship/fueled/return_fuel_cap()
	. = ..()
	var/obj/machinery/atmospherics/components/unary/shuttle/heater/resolved_heater = attached_heater.resolve()
	return resolved_heater?.return_gas_capacity()

/obj/machinery/power/shuttle_engine/ship/fueled/screwdriver_act(mob/living/user, obj/item/I)
	. = ..()
	if(!panel_open)
		update_icon_state()

///This proc makes the area the shuttle is in EXTREMELY hot. I don't know how it does this, but that's what it does.
/obj/machinery/power/shuttle_engine/proc/heat_engine()
	var/turf/heatTurf = loc
	if(!heatTurf)
		return
	var/datum/gas_mixture/env = heatTurf.return_air()
	var/heat_cap = env.heat_capacity()
	var/req_power = abs(env.return_temperature() - ENGINE_HEAT_TARGET) * heat_cap
	req_power = min(req_power, ENGINE_HEATING_POWER)
	if(heat_cap <= 0)
		return
	var/deltaTemperature = req_power / heat_cap
	if(deltaTemperature < 0)
		return
	env.temperature = env.return_temperature() + deltaTemperature
	air_update_turf()

/obj/machinery/power/shuttle_engine/ship/fueled/update_engine()
	. = ..()
	if(!.)
		return
	if(!attached_heater)
		if(!set_heater())
			thruster_active = FALSE
			return FALSE

/obj/machinery/power/shuttle_engine/ship/fueled/proc/set_heater()
	for(var/direction in GLOB.cardinals)
		for(var/obj/machinery/atmospherics/components/unary/shuttle/heater/found in get_step(get_turf(src), direction))
			if(found.dir != dir)
				continue
			if(found.panel_open)
				continue
			if(!found.anchored)
				continue
			attached_heater = WEAKREF(found)
			update_icon_state()
			return TRUE

/obj/machinery/power/shuttle_engine/ship/fueled/plasma
	name = "plasma thruster"
	desc = "A thruster that burns plasma from an adjacent heater to create thrust."
	circuit = /obj/item/circuitboard/machine/shuttle/engine/plasma
	fuel_type = /datum/gas/plasma
	fuel_use = 20
	thrust = 25

/obj/machinery/power/shuttle_engine/ship/fueled/expulsion
	name = "expulsion thruster"
	desc = "A thruster that expels gas inefficiently to create thrust."
	circuit = /obj/item/circuitboard/machine/shuttle/engine/expulsion
	fuel_use = 80
	thrust = 15
	//All fuel code already handled
