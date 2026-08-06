/**
 * Chemical infuser.
 *
 * Ported from monkestation's factory_type_beat atmos_chem module.
 *
 * Half plumbing machine, half atmospherics device: it pulls reagents in through a duct on
 * one face and gas in through a pipe on another, and where a recipe matches it burns both
 * into a new reagent. It is the only way to get gas into the reagent system.
 *
 * Plumbing on NORTH (demand) and SOUTH (supply); the gas pipe attaches to whichever side
 * the machine is facing away from, see set_init_directions().
 */
/obj/machinery/atmospherics/components/unary/chemical_infuser
	name = "chemical infuser"
	desc = "An affront to both chemists and atmospheric technicians."

	layer = BELOW_OBJ_LAYER

	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "reaction_chamber"

	initialize_directions = EAST

	/// name -> recipe datum, built once and shared by every infuser.
	var/static/list/chemical_infuser_recipes
	var/datum/chemical_infuser_recipe/chosen_recipe
	/// TRUE while a batch is bubbling away on its timer.
	var/processing = FALSE

/// How long a batch takes once its inputs are all present.
#define ATMOS_CHEM_REACTION_TIME (7 SECONDS)

/obj/machinery/atmospherics/components/unary/chemical_infuser/Initialize(mapload)
	. = ..()
	create_reagents(1000, TRANSPARENT)
	AddComponent(/datum/component/plumbing/chemical_infuser)

/*
 * The gas pipe goes on the face perpendicular to the plumbing ducts, so that a machine
 * dropped into a duct run doesn't try to put its pipe stub where a duct already is.
 */
/obj/machinery/atmospherics/components/unary/chemical_infuser/set_init_directions()
	. = ..()
	switch(dir)
		if(SOUTH)
			initialize_directions = EAST
		if(NORTH)
			initialize_directions = WEST
		if(WEST)
			initialize_directions = SOUTH
		if(EAST)
			initialize_directions = NORTH

/// Builds the shared recipe list on first use. Keyed by name so the picker reads sensibly.
/obj/machinery/atmospherics/components/unary/chemical_infuser/proc/create_recipes()
	if(chemical_infuser_recipes)
		return
	chemical_infuser_recipes = list()
	for(var/datum/chemical_infuser_recipe/recipe_type as anything in subtypesof(/datum/chemical_infuser_recipe))
		var/datum/chemical_infuser_recipe/recipe = new recipe_type
		chemical_infuser_recipes[recipe.name] = recipe

/obj/machinery/atmospherics/components/unary/chemical_infuser/ui_interact(mob/user, datum/tgui/ui)
	create_recipes()
	var/picked = tgui_input_list(user, "Choose a recipe to focus on.", name, chemical_infuser_recipes)
	if(isnull(picked) || QDELETED(src) || !user.can_perform_action(src))
		return
	chosen_recipe = chemical_infuser_recipes[picked]
	//A half-finished batch of the old recipe must not pay out under the new one.
	processing = FALSE
	balloon_alert(user, "set to [picked]")

/obj/machinery/atmospherics/components/unary/chemical_infuser/examine(mob/user)
	. = ..()
	if(!chosen_recipe)
		. += span_notice("No recipe is selected. Click it to choose one.")
		return

	. += span_notice("[chosen_recipe.name] requires:")
	for(var/datum/reagent/reagent as anything in chosen_recipe.required_reagents)
		. += span_notice("[initial(reagent.name)]: [reagents.get_reagent_amount(reagent)] / [chosen_recipe.required_reagents[reagent]]")

	var/datum/gas_mixture/mixture = airs[1]
	for(var/datum/gas/gas as anything in chosen_recipe.required_gases)
		mixture.assert_gas(gas)
		. += span_notice("[initial(gas.name)]: [mixture.gases[gas][MOLES]] / [chosen_recipe.required_gases[gas]]")

/obj/machinery/atmospherics/components/unary/chemical_infuser/process_atmos()
	if(!chosen_recipe || processing)
		return

	var/datum/gas_mixture/mixture = airs[1]
	for(var/datum/gas/gas as anything in chosen_recipe.required_gases)
		mixture.assert_gas(gas)
		if(mixture.gases[gas][MOLES] < chosen_recipe.required_gases[gas])
			return

	for(var/datum/reagent/reagent as anything in chosen_recipe.required_reagents)
		if(reagents.get_reagent_amount(reagent) < chosen_recipe.required_reagents[reagent])
			return

	playsound(src, 'sound/effects/bubbles/bubbles2.ogg', 25, TRUE)
	audible_message(span_notice("[icon2html(src, viewers(4, get_turf(src)))] The solution bubbles fiercely!"))
	processing = TRUE
	addtimer(CALLBACK(src, PROC_REF(create_recipe), chosen_recipe), ATMOS_CHEM_REACTION_TIME)

/*
 * The recipe is passed in rather than re-read, so swapping the machine's selection during
 * the seven seconds cannot make it pay out something it never had the inputs for. The
 * inputs are re-checked here too, since they can be drained through the plumbing meanwhile.
 */
/obj/machinery/atmospherics/components/unary/chemical_infuser/proc/create_recipe(datum/chemical_infuser_recipe/recipe)
	processing = FALSE
	if(QDELETED(src) || !recipe || recipe != chosen_recipe)
		return

	var/datum/gas_mixture/mixture = airs[1]
	for(var/datum/gas/gas as anything in recipe.required_gases)
		mixture.assert_gas(gas)
		if(mixture.gases[gas][MOLES] < recipe.required_gases[gas])
			return
	for(var/datum/reagent/reagent as anything in recipe.required_reagents)
		if(reagents.get_reagent_amount(reagent) < recipe.required_reagents[reagent])
			return

	for(var/datum/reagent/reagent as anything in recipe.required_reagents)
		reagents.remove_reagent(reagent, recipe.required_reagents[reagent])
	for(var/datum/gas/gas as anything in recipe.required_gases)
		mixture.remove_specific(gas, recipe.required_gases[gas])
	for(var/datum/reagent/reagent as anything in recipe.outputs)
		reagents.add_reagent(reagent, recipe.outputs[reagent])

/// Plumbing hookup: reagents demanded on the north face, product supplied on the south.
/datum/component/plumbing/chemical_infuser
	demand_connects = NORTH
	supply_connects = SOUTH

//VOIDCREW ADAPTATION: this fork's /datum/component/plumbing/Initialize takes
//(start, ducting_layer, turn_connects, custom_receiver, extend_pipe_to_edge). Monkestation's
//override predated extend_pipe_to_edge and used the older _ducting_layer/_turn_connects
//names; every default is reproduced here so no caller loses an argument.
/datum/component/plumbing/chemical_infuser/Initialize(start = TRUE, ducting_layer, turn_connects = TRUE, datum/reagents/custom_receiver, extend_pipe_to_edge = FALSE)
	. = ..()
	if(!istype(parent, /obj/machinery/atmospherics/components/unary/chemical_infuser))
		return COMPONENT_INCOMPATIBLE

/*
 * VOIDCREW FIX: monkestation's version cast parent to /obj/machinery/plumbing/reaction_chamber
 * and read `.emptying` off it, a var an atmospherics machine does not have - a guaranteed
 * runtime every time anything asked this machine for reagents. What it was reaching for was
 * "don't hand out reagents that are still an input", so that is what this does.
 */
/datum/component/plumbing/chemical_infuser/can_give(amount, reagent, datum/ductnet/net)
	. = ..()
	if(!.)
		return FALSE

	var/obj/machinery/atmospherics/components/unary/chemical_infuser/chamber = parent
	if(chamber.processing) //mid-batch, everything in here is spoken for
		return FALSE
	if(!chamber.chosen_recipe)
		return TRUE

	//Never supply out a reagent the selected recipe still needs.
	if(reagent)
		return !chamber.chosen_recipe.required_reagents[reagent]
	for(var/datum/reagent/contained as anything in reagents.reagent_list)
		if(!chamber.chosen_recipe.required_reagents[contained.type])
			return TRUE
	return FALSE

/datum/component/plumbing/chemical_infuser/send_request(dir)
	var/obj/machinery/atmospherics/components/unary/chemical_infuser/chamber = parent
	if(!chamber.chosen_recipe)
		return

	for(var/required_reagent in chamber.chosen_recipe.required_reagents)
		var/present = reagents.get_reagent_amount(required_reagent)
		var/needed = chamber.chosen_recipe.required_reagents[required_reagent] - present
		if(needed < CHEMICAL_QUANTISATION_LEVEL)
			continue
		process_request(min(needed, MACHINE_REAGENT_TRANSFER), required_reagent, dir)
		return

#undef ATMOS_CHEM_REACTION_TIME
