/**
 * Pressurized reaction chamber.
 *
 * Ported from monkestation's factory_type_beat atmos_chem module.
 *
 * The infuser's sibling: instead of consuming a gas it just needs the gas already in its
 * pipe to be above a threshold pressure. Nothing is taken out of the mixture, so one
 * well-pressurised loop can drive a whole bank of these.
 */
/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber
	name = "pressurized reaction chamber"
	desc = "An affront to both chemists and atmospheric technicians."

	layer = BELOW_OBJ_LAYER

	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "reaction_chamber"

	initialize_directions = EAST

	/// name -> recipe datum, built once and shared by every chamber.
	var/static/list/pressurized_reaction_recipes
	var/datum/pressurized_reaction/chosen_recipe
	/// TRUE while a batch is bubbling away on its timer.
	var/processing = FALSE

/// How long a batch takes once its inputs are all present.
#define ATMOS_CHEM_REACTION_TIME (7 SECONDS)

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/Initialize(mapload)
	. = ..()
	create_reagents(1000, TRANSPARENT)
	AddComponent(/datum/component/plumbing/pressurized_reaction_chamber)

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/set_init_directions()
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

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/proc/create_recipes()
	if(pressurized_reaction_recipes)
		return
	pressurized_reaction_recipes = list()
	for(var/datum/pressurized_reaction/recipe_type as anything in subtypesof(/datum/pressurized_reaction))
		var/datum/pressurized_reaction/recipe = new recipe_type
		pressurized_reaction_recipes[recipe.name] = recipe

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/ui_interact(mob/user, datum/tgui/ui)
	create_recipes()
	var/picked = tgui_input_list(user, "Choose a recipe to focus on.", name, pressurized_reaction_recipes)
	if(isnull(picked) || QDELETED(src) || !user.can_perform_action(src))
		return
	chosen_recipe = pressurized_reaction_recipes[picked]
	processing = FALSE
	balloon_alert(user, "set to [picked]")

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/examine(mob/user)
	. = ..()
	if(!chosen_recipe)
		. += span_notice("No recipe is selected. Click it to choose one.")
		return

	. += span_notice("[chosen_recipe.name] requires:")
	for(var/datum/reagent/reagent as anything in chosen_recipe.required_reagents)
		. += span_notice("[initial(reagent.name)]: [reagents.get_reagent_amount(reagent)] / [chosen_recipe.required_reagents[reagent]]")

	var/datum/gas_mixture/mixture = airs[1]
	. += span_notice("Pressure: [round(mixture.return_pressure(), 0.1)] / [chosen_recipe.required_pressure] kPa.")

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/process_atmos()
	if(!chosen_recipe || processing)
		return

	for(var/datum/reagent/reagent as anything in chosen_recipe.required_reagents)
		if(reagents.get_reagent_amount(reagent) < chosen_recipe.required_reagents[reagent])
			return

	var/datum/gas_mixture/mixture = airs[1]
	if(mixture.return_pressure() < chosen_recipe.required_pressure)
		return

	playsound(src, 'sound/effects/bubbles/bubbles2.ogg', 25, TRUE)
	audible_message(span_notice("[icon2html(src, viewers(4, get_turf(src)))] The solution bubbles fiercely!"))
	processing = TRUE
	addtimer(CALLBACK(src, PROC_REF(create_recipe), chosen_recipe), ATMOS_CHEM_REACTION_TIME)

/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/proc/create_recipe(datum/pressurized_reaction/recipe)
	processing = FALSE
	if(QDELETED(src) || !recipe || recipe != chosen_recipe)
		return

	//Re-checked because the plumbing can drain us, and the pipe can vent, during the wait.
	for(var/datum/reagent/reagent as anything in recipe.required_reagents)
		if(reagents.get_reagent_amount(reagent) < recipe.required_reagents[reagent])
			return
	var/datum/gas_mixture/mixture = airs[1]
	if(mixture.return_pressure() < recipe.required_pressure)
		return

	for(var/datum/reagent/reagent as anything in recipe.required_reagents)
		reagents.remove_reagent(reagent, recipe.required_reagents[reagent])
	for(var/datum/reagent/reagent as anything in recipe.outputs)
		reagents.add_reagent(reagent, recipe.outputs[reagent])

/datum/component/plumbing/pressurized_reaction_chamber
	demand_connects = NORTH
	supply_connects = SOUTH

//VOIDCREW ADAPTATION: matches this fork's /datum/component/plumbing/Initialize signature,
//including extend_pipe_to_edge, which monkestation's version predated.
/datum/component/plumbing/pressurized_reaction_chamber/Initialize(start = TRUE, ducting_layer, turn_connects = TRUE, datum/reagents/custom_receiver, extend_pipe_to_edge = FALSE)
	. = ..()
	if(!istype(parent, /obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber))
		return COMPONENT_INCOMPATIBLE

/// VOIDCREW FIX: see the same proc on /datum/component/plumbing/chemical_infuser - upstream
/// read `.emptying` off a type this machine is not.
/datum/component/plumbing/pressurized_reaction_chamber/can_give(amount, reagent, datum/ductnet/net)
	. = ..()
	if(!.)
		return FALSE

	var/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/chamber = parent
	if(chamber.processing)
		return FALSE
	if(!chamber.chosen_recipe)
		return TRUE

	if(reagent)
		return !chamber.chosen_recipe.required_reagents[reagent]
	for(var/datum/reagent/contained as anything in reagents.reagent_list)
		if(!chamber.chosen_recipe.required_reagents[contained.type])
			return TRUE
	return FALSE

/datum/component/plumbing/pressurized_reaction_chamber/send_request(dir)
	var/obj/machinery/atmospherics/components/unary/pressurized_reaction_chamber/chamber = parent
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
