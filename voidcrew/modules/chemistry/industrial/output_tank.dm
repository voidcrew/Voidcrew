/**
 * Remote chemical tank.
 *
 * Ported from monkestation's wiremod_chem module (components/ouputs/tank_output.dm).
 *
 * The physical end of a circuit's chemical output. Alt-click it to pop out the circuit
 * component that writes into it. This is the parent of every "chemicals come out here"
 * structure - the injector, the patcher and the smoke machine are all just tanks that do
 * something to their contents in after_reagent_add().
 */
/obj/structure/chemical_tank
	name = "remote chemical tank"
	desc = "A chemical tank that can be remotely connected to the chemical manufacturer."

	icon = 'voidcrew/icons/obj/industrial_chem_structures.dmi'
	icon_state = "tank_output"

	max_integrity = 2500
	density = TRUE

	/// The circuit component currently writing into us.
	var/obj/item/circuit_component/chem/output/linked_output
	var/reagent_flags = TRANSPARENT | DRAINABLE
	var/buffer = 500
	/// What the popped-out component gets called.
	var/component_name = "Tank Output"

/obj/structure/chemical_tank/Initialize(mapload)
	. = ..()
	create_reagents(buffer, reagent_flags)

/obj/structure/chemical_tank/Destroy()
	//Both halves hold a hard reference to each other, so drop ours or the component
	//keeps us alive forever.
	if(linked_output)
		linked_output.chemical_tank = null
		linked_output = null
	return ..()

/obj/structure/chemical_tank/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.tool_behaviour == TOOL_WRENCH)
		if(attacking_item.use_tool(src, user, 4 SECONDS, volume = 75))
			to_chat(user, span_notice("You [anchored ? "un" : ""]secure [src]."))
			set_anchored(!anchored)
			return
	return ..()

/obj/structure/chemical_tank/examine(mob/user)
	. = ..()
	. += span_notice("The maximum volume display reads: <b>[reagents.maximum_volume] units</b>.")
	if(linked_output)
		. += span_notice("Is connected to an output device.")
	else
		. += span_notice("Alt-click to produce a circuit component linked to it.")

/// Pops out the circuit component that writes into us, if we haven't already.
/// Split out of click_alt so subtypes can reuse it without chaining to a parent that
/// is documented as SHOULD_CALL_PARENT(FALSE).
/obj/structure/chemical_tank/proc/create_linked_component()
	if(linked_output)
		return FALSE
	linked_output = new(drop_location())
	linked_output.chemical_tank = src
	linked_output.name = component_name
	linked_output.display_name = component_name
	return TRUE

/obj/structure/chemical_tank/click_alt(mob/living/user)
	create_linked_component()
	return CLICK_ACTION_SUCCESS

/// Called after a circuit has just pushed reagents into us. Subtypes do their thing here.
/obj/structure/chemical_tank/proc/after_reagent_add()
	return

/obj/structure/chemical_tank/plunger_act(obj/item/plunger/attacking_plunger, mob/living/user, reinforced)
	to_chat(user, span_notice("You start furiously plunging [src]."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	to_chat(user, span_notice("You finish plunging [src]."))
	reagents.expose(get_turf(src), TOUCH) //splash on the floor
	reagents.clear_reagents()

/**
 * The circuit half. Folds every chemical input together and dumps the result into the
 * linked structure at a chosen temperature.
 */
/obj/item/circuit_component/chem/output
	display_name = "Tank Output"
	desc = "Linked to a physical object, sends the chemicals to the tank."

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL
	ui_buttons = list(
		"plus" = "add",
		"minus" = "remove",
	)

	var/list/chemical_inputs
	var/datum/port/input/heat_input

	var/obj/structure/chemical_tank/chemical_tank

/obj/item/circuit_component/chem/output/Destroy()
	if(chemical_tank)
		chemical_tank.linked_output = null
		chemical_tank = null
	return ..()

/obj/item/circuit_component/chem/output/populate_ports()
	chemical_inputs = list()
	AddComponent(/datum/component/circuit_component_add_port, \
		port_list = chemical_inputs, \
		add_action = "add", \
		remove_action = "remove", \
		port_type = PORT_TYPE_CHEMICAL_LIST, \
		prefix = "Chemical Input", \
		minimum_amount = 2, \
	)
	heat_input = add_input_port("Desired Heat", PORT_TYPE_NUMBER, default = 275)

/obj/item/circuit_component/chem/output/input_received(datum/port/input/port, list/return_values)
	if(!chemical_tank)
		return

	var/list/chemical_list = collect_chemical_inputs(chemical_inputs)
	if(!length(chemical_list))
		return

	var/sane_heat = sanitize_heat(heat_input)
	chemical_tank.reagents.add_reagent_list(chemical_list, temperature = sane_heat)
	chemical_tank.after_reagent_add()

/obj/item/circuit_component/chem/output/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/output/clear_all_temp_ports()
	for(var/datum/port/input/input as anything in chemical_inputs)
		input.value = null
