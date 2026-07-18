/**
  * ### Liquid Fuel Engines
  * Turns a specific reagent or reagents into thrust.
  */
/obj/machinery/power/shuttle_engine/ship/liquid
	name = "liquid thruster"
	desc = "A thruster that burns reagents stored in the engine for fuel."

	///How much fuel can be loaded into the engine.
	var/max_reagents = 0
	///What reagent is consumed to burn the engine, and how much is needed.
	var/list/datum/reagent/fuel_reagents
	///Used to store how much total of any reagent is needed per burn. Don't set anywhere but /Initialize()
	var/reagent_amount_holder = 0

/obj/machinery/power/shuttle_engine/ship/liquid/oil
	name = "oil thruster"
	desc = "A highly inefficient thruster that burns oil as a propellant."
	circuit = /obj/item/circuitboard/machine/engine/oil
	engine_power = 20

	max_reagents = 1000
	fuel_reagents = list(/datum/reagent/fuel/oil = 50)


/obj/machinery/power/shuttle_engine/ship/liquid/Initialize(mapload)
	. = ..()
	create_reagents(max_reagents, OPENCONTAINER)
	AddComponent(/datum/component/plumbing/simple_demand)
	for(var/reagent in fuel_reagents)
		reagent_amount_holder += fuel_reagents[reagent]

/obj/machinery/power/shuttle_engine/ship/liquid/burn_engine(percentage = 100, ship_mass = REFERENCE_SHIP_MASS, burn_seconds = 1)
	. = ..()
	var/mass_multiplier = get_mass_fuel_multiplier(ship_mass)
	var/true_percentage = 1
	for(var/reagent in fuel_reagents)
		var/to_use = fuel_reagents[reagent] * (percentage / 100) * mass_multiplier * burn_seconds
		if(to_use <= 0)
			return 0
		true_percentage *= reagents.remove_reagent(reagent, to_use) / to_use
	return engine_power * true_percentage

/obj/machinery/power/shuttle_engine/ship/liquid/return_fuel()
	if(!length(fuel_reagents))
		return 0
	var/true_percentage = INFINITY
	for(var/reagent in fuel_reagents)
		true_percentage = min(reagents.get_reagent_amount(reagent) / fuel_reagents[reagent], true_percentage)
	return reagent_amount_holder * true_percentage //Multiplies the total amount needed by the smallest percentage of any reagent in the recipe

/obj/machinery/power/shuttle_engine/ship/liquid/return_fuel_cap()
	return reagents.maximum_volume
