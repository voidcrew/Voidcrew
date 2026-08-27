//-----------------------------------------------
//--------------Engine Heaters-------------------
//This uses atmospherics, much like a thermomachine,
//but instead of changing temp, it stores plasma and uses
//it for the engine.
//-----------------------------------------------
/obj/machinery/atmospherics/components/unary/shuttle
	name = "shuttle atmospherics device"
	desc = "This does something to do with shuttle atmospherics"
	icon_state = "heater"
	icon = 'voidcrew/modules/shuttle/icons/shuttle.dmi'

/// Re-point the single pipe node after a rotation and rebuild the pipenet.
/// Shared by every unary shuttle atmos device so they can all be turned to
/// face their pipe network; the heater overrides this to also refresh engines.
/obj/machinery/atmospherics/components/unary/shuttle/default_change_direction_wrench(mob/user, obj/item/I)
	if(!..())
		return FALSE
	set_init_directions()
	var/obj/machinery/atmospherics/node = nodes[1]
	if(node)
		node.disconnect(src)
		nodes[1] = null
	if(!parents[1])
		return TRUE
	nullify_pipenet(parents[1])

	atmos_init()
	node = nodes[1]
	if(node)
		node.atmos_init()
		node.add_member(src)
	SSair.add_to_rebuild_queue(src)
	return TRUE

/obj/machinery/atmospherics/components/unary/shuttle/wrench_act_secondary(mob/living/user, obj/item/tool)
	if(!panel_open)
		balloon_alert(user, "open panel first!")
		return ITEM_INTERACT_SUCCESS
	if(default_change_direction_wrench(user, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/datum/armor/shuttle_heater
	energy = 100
	bio = 100
	fire = 100
	acid = 30

/obj/machinery/atmospherics/components/unary/shuttle/heater
	name = "engine heater"
	desc = "Directs energy into compressed particles in order to power an attached thruster."
	icon_state = "heater_pipe"
	var/icon_state_closed = "heater_pipe"
	var/icon_state_open = "heater_pipe_open"
	idle_power_usage = 50
	circuit = /obj/item/circuitboard/machine/shuttle/heater

	density = TRUE
	max_integrity = 400
	armor_type = /datum/armor/shuttle_heater
	layer = OBJ_LAYER
	move_resist = MOVE_RESIST_DEFAULT
	//showpipe = TRUE // TODO: Fix showpipe

	pipe_flags = PIPING_ONE_PER_TURF | PIPING_DEFAULT_LAYER_ONLY

	var/efficiency_multiplier = 1
	var/gas_capacity = 0
	///Whether or not to draw from the attached internals tank
	var/use_tank = FALSE
	///The internals tank to draw from
	var/obj/item/tank/fuel_tank
	var/datum/gas_mixture/air

/obj/machinery/atmospherics/components/unary/shuttle/heater/Initialize(mapload)
	initialize_directions = dir // Set pipe direction before parent reads it
	. = ..()
	RefreshParts() // Ensure gas_capacity is set and airs[1] is properly configured
	update_adjacent_engines()

/obj/machinery/atmospherics/components/unary/shuttle/heater/Destroy()
	update_adjacent_engines() //must run before parent moves us to nullspace, or the engines are never told
	fuel_tank = null
	return ..()

/**
 * fuel_tank is a strong reference to an item sitting in our contents, and only the
 * attackby() swap ever cleared it. A tank that left any other way - qdel'd with the hull,
 * blown up, dumped by machinery deconstruction - left the pointer dangling and the tank
 * could never be collected (create_and_destroy 2026-08-25: /obj/item/tank/internals/plasma/full
 * hard deleted, held by this var). Exited() is the one hook every exit path runs through,
 * qdel included: /atom/movable/Destroy() nullspaces the item, which fires this on its loc.
 */
/obj/machinery/atmospherics/components/unary/shuttle/heater/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == fuel_tank)
		fuel_tank = null

/obj/machinery/atmospherics/components/unary/shuttle/heater/on_construction()
	..(dir, dir)
	set_init_directions()
	update_adjacent_engines()

/obj/machinery/atmospherics/components/unary/shuttle/heater/process_atmos(seconds_per_tick)
	if(!use_tank)
		update_parents()

/obj/machinery/atmospherics/components/unary/shuttle/heater/default_change_direction_wrench(mob/user, obj/item/I)
	if(!..())
		return FALSE
	set_init_directions()
	var/obj/machinery/atmospherics/node = nodes[1]
	if(node)
		node.disconnect(src)
		nodes[1] = null
	if(!parents[1])
		return
	nullify_pipenet(parents[1])

	atmos_init()
	node = nodes[1]
	if(node)
		node.atmos_init()
		node.add_member(src)
	SSair.add_to_rebuild_queue(src)
	return TRUE

/obj/machinery/atmospherics/components/unary/shuttle/heater/RefreshParts()
	. = ..()
	var/cap = max(total_part_rating(/datum/stock_part/matter_bin), 1)
	var/eff = max(total_part_rating(/datum/stock_part/micro_laser), 2)
	gas_capacity = 5000 * ((cap - 1) ** 2) + 1000
	efficiency_multiplier = round(((eff / 2) / 2.8) ** 2, 0.1)
	update_gas_stats()

/obj/machinery/atmospherics/components/unary/shuttle/heater/examine(mob/user)
	. = ..()
	. += "It is set to draw fuel from [use_tank ? "the attached tank" : "the atmospherics system"]. Looks like the fuel source can be toggled by hand."
	. += "The engine heater's gas dial reads [return_gas()] moles of gas.<br>"

/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/return_gas(gas_type)
	var/datum/gas_mixture/air_contents = use_tank ? fuel_tank?.air_contents : airs[1]
	if(!air_contents)
		return
	if(gas_type)
		air_contents.assert_gas(gas_type)
		return air_contents.moles[gas_type]
	else
		return air_contents.total_moles()

/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/return_gas_capacity()
	var/datum/gas_mixture/air_contents = use_tank ? fuel_tank?.air_contents : airs[1]
	if(!air_contents)
		return
	return air_contents.return_volume()

/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/update_gas_stats()
	var/datum/gas_mixture/air_contents = use_tank ? fuel_tank?.air_contents : airs[1]
	if(!air_contents)
		return
	air_contents.volume = gas_capacity
	air_contents.temperature = T20C

/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/has_fuel(required, datum/gas/gas_type)
	var/datum/gas_mixture/air_contents = use_tank ? fuel_tank?.air_contents : airs[1]
	if(!air_contents)
		return
	air_contents.assert_gas(gas_type)
	return air_contents.moles[gas_type] >= required

/**
  * Burns a specific amount of one type of gas. Returns how much was actually used.
  * * amount - The amount of mols of fuel to burn.
  * * gas_type - The gas type to burn.
  */
/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/consume_fuel(amount, datum/gas/gas_type)
	var/datum/gas_mixture/air_contents = use_tank ? fuel_tank?.air_contents : airs[1]
	if(!air_contents)
		return
	if(!gas_type)
		var/datum/gas_mixture/removed = air_contents.remove(amount)
		if(!removed)
			return 0
		return removed.total_moles()
	else
		air_contents.assert_gas(gas_type)
		var/starting_amt = air_contents.moles[gas_type]
		air_contents.moles[gas_type] = clamp(air_contents.moles[gas_type] + -amount,0,INFINITY)
		air_contents.garbage_collect() //VOIDCREW: the flat moles list requires a collect after subtracting
		return min(starting_amt, amount)

/obj/machinery/atmospherics/components/unary/shuttle/heater/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/unary/shuttle/heater/wrench_act(mob/living/user, obj/item/tool)
	if(!panel_open)
		balloon_alert(user, "open panel first!")
		return ITEM_INTERACT_SUCCESS
	var/result = default_unfasten_wrench(user, tool)
	if(result == SUCCESSFUL_UNFASTEN)
		change_pipe_connection(!anchored)
	if(result)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/atmospherics/components/unary/shuttle/heater/wrench_act_secondary(mob/living/user, obj/item/tool)
	if(!panel_open)
		balloon_alert(user, "open panel first!")
		return ITEM_INTERACT_SUCCESS
	if(default_change_direction_wrench(user, tool))
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/atmospherics/components/unary/shuttle/heater/crowbar_act(mob/living/user, obj/item/tool)
	if(default_pry_open(user, tool) & ITEM_INTERACT_SUCCESS)
		return ITEM_INTERACT_SUCCESS
	if(default_deconstruction_crowbar(user, tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/unary/shuttle/heater/attackby(obj/item/I, mob/living/user, params)
	update_adjacent_engines()
	if(istype(I, /obj/item/tank/internals))
		if (fuel_tank)
			try_put_in_hand(fuel_tank, user)
			fuel_tank = null
		user.transferItemToLoc(I, src)
		fuel_tank = I
		return
	return ..()

/obj/machinery/atmospherics/components/unary/shuttle/heater/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(panel_open)
		balloon_alert(user, "close panel first!")
		return TRUE
	toggle_fuel_source(user)
	return TRUE

/**
  * Flips the heater between drawing fuel from the pipe network and from an inserted tank,
  * and repoints the icon states so the sprite matches the source it is set to.
  */
/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/toggle_fuel_source(mob/user)
	use_tank = !use_tank
	icon_state_closed = use_tank ? "heater" : initial(icon_state)
	icon_state_open = use_tank ? "heater_open" : "[initial(icon_state)]_open"
	icon_state = panel_open ? icon_state_open : icon_state_closed
	if(user)
		to_chat(user, span_notice("You switch [src] to draw fuel from [use_tank ? "the attached tank" : "the atmospherics system"]."))

/obj/machinery/atmospherics/components/unary/shuttle/heater/proc/update_adjacent_engines()
	var/engine_turf
	switch(dir)
		if(NORTH)
			engine_turf = get_offset_target_turf(src, 0, -1)
		if(SOUTH)
			engine_turf = get_offset_target_turf(src, 0, 1)
		if(EAST)
			engine_turf = get_offset_target_turf(src, -1, 0)
		if(WEST)
			engine_turf = get_offset_target_turf(src, 1, 0)
	if(!engine_turf)
		return
	for(var/obj/machinery/power/shuttle_engine/ship/fueled/E in engine_turf)
		E.update_icon_state()

/obj/machinery/atmospherics/components/unary/shuttle/heater/tank/Initialize(mapload)
	. = ..()
	// Ships pipe plasma to their heaters, so this starts drawing from the atmospherics
	// system. The tank comes along as a backup for when the pipe line runs dry or breaks -
	// click the heater by hand to switch it over.
	fuel_tank = new /obj/item/tank/internals/plasma/full(src)
