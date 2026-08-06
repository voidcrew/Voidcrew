/**
 * Remote chemical input tank.
 *
 * Ported from monkestation's wiremod_chem module (components/inputs/tank_input.dm).
 *
 * The physical end of a circuit's chemical intake. Fill it however you like - beaker,
 * plumbing, a grinder subtype - then alt-click it to pop out the circuit component that
 * reads from it. This is the parent of every "chemicals come in here" structure.
 */
/obj/structure/chemical_input
	name = "remote chemical input tank"
	desc = "A chemical tank that can be remotely connected to the chemical manufacturer to send chemicals."

	icon = 'voidcrew/icons/obj/industrial_chem_structures.dmi'
	icon_state = "tank_input"

	max_integrity = 2500
	density = TRUE

	/// The circuit component currently reading from us.
	var/obj/item/circuit_component/chem/input/linked_input
	var/reagent_flags = TRANSPARENT | REFILLABLE | DRAINABLE
	var/buffer = 500
	/// What the popped-out component gets called.
	var/component_name = "Tank Input"

/obj/structure/chemical_input/Initialize(mapload)
	. = ..()
	create_reagents(buffer, reagent_flags)

/obj/structure/chemical_input/Destroy()
	//Both halves hold a hard reference to each other, so drop ours or the component
	//keeps us alive forever.
	if(linked_input)
		linked_input.linked_input = null
		linked_input = null
	return ..()

/obj/structure/chemical_input/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.tool_behaviour == TOOL_WRENCH)
		if(attacking_item.use_tool(src, user, 4 SECONDS, volume = 75))
			to_chat(user, span_notice("You [anchored ? "un" : ""]secure [src]."))
			set_anchored(!anchored)
			return
	return ..()

/obj/structure/chemical_input/plunger_act(obj/item/plunger/attacking_plunger, mob/living/user, reinforced)
	to_chat(user, span_notice("You start furiously plunging [src]."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	to_chat(user, span_notice("You finish plunging [src]."))
	reagents.expose(get_turf(src), TOUCH) //splash on the floor
	reagents.clear_reagents()

/obj/structure/chemical_input/click_alt(mob/living/user)
	if(linked_input)
		return CLICK_ACTION_BLOCKING
	linked_input = new(drop_location())
	linked_input.linked_input = src
	linked_input.name = component_name
	linked_input.display_name = component_name
	return CLICK_ACTION_SUCCESS

/obj/structure/chemical_input/examine(mob/user)
	. = ..()
	. += span_notice("The maximum volume display reads: <b>[reagents.maximum_volume] units</b>.")
	if(linked_input)
		. += span_notice("Is connected to an input device.")
	else
		. += span_notice("Alt-click to produce a circuit component linked to it.")

/**
 * The circuit half. Draws a requested number of units out of its linked structure and
 * emits them, along with the temperature they were being held at.
 */
/obj/item/circuit_component/chem/input
	display_name = "Tank Input"
	desc = "Linked to a physical object, pulls the chemicals from the tank."

	circuit_flags = CIRCUIT_FLAG_INPUT_SIGNAL

	var/datum/port/output/chemical_output
	/// The temperature read off the input device.
	var/datum/port/output/chem_heat
	/// The structure we draw from.
	var/obj/structure/chemical_input/linked_input
	/// How much to draw per pulse.
	var/datum/port/input/units

	/// Scratch holder used to measure the draw.
	var/datum/reagents/reagent_holder

/obj/item/circuit_component/chem/input/Initialize(mapload)
	. = ..()
	reagent_holder = new /datum/reagents(10000)
	reagent_holder.my_atom = src

/obj/item/circuit_component/chem/input/Destroy()
	QDEL_NULL(reagent_holder)
	if(linked_input)
		linked_input.linked_input = null
		linked_input = null
	return ..()

/obj/item/circuit_component/chem/input/populate_ports()
	chemical_output = add_output_port("Chemical Output", PORT_TYPE_CHEMICAL_LIST, port_type = /datum/port/output/singular)
	chem_heat = add_output_port("Chemical Heat", PORT_TYPE_NUMBER)
	units = add_input_port("Units", PORT_TYPE_NUMBER)

/obj/item/circuit_component/chem/input/input_received(datum/port/input/port, list/return_values)
	if(!linked_input || !linked_input.reagents?.total_volume)
		return
	var/draw = clamp(units.value, 0, 1000)
	if(!draw)
		return

	var/read_heat = linked_input.reagents.chem_temp
	linked_input.reagents.trans_to(reagent_holder, draw)

	chemical_output.set_output(holder_to_chemical_list(reagent_holder))
	chem_heat.set_output(read_heat)
	reagent_holder.clear_reagents()

/obj/item/circuit_component/chem/input/after_work_call()
	clear_all_temp_ports()

/obj/item/circuit_component/chem/input/clear_all_temp_ports()
	chemical_output.value = null
	chem_heat.value = null
