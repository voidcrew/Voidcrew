/**
 * === Ship gas harvesting ===
 *
 * The two renewable fuel channels of the gas economy (see the Gas-economy
 * design doc): the nebula ram scoop (sit still inside a nebula, drink its gas)
 * and the plasma sublimation chamber (bake mined plasma sheets into gas).
 *
 * Both are unary atmos components in the engine heater's family: they output
 * into whatever pipenet they're wrenched onto. The intended flow is
 * scoop/sublimator -> ship pipe network -> engine heater (in pipe mode) ->
 * thrusters; crews can equally route the pipenet to a connector port and fill
 * canisters or tanks for trade.
 *
 * Scooping is deliberately loud: every harvest tick calls the ship's
 * notify_scoop_activity(), which blocks and breaks nebula concealment
 * (ship.dm), the fuel stop is also the ambush spot.
 */

/// Moles of plasma gas one plasma sheet bakes down into (the open-beaker jank
/// yields 20/sheet; the purpose-built chamber is meant to beat it)
#define SUBLIMATOR_MOLES_PER_SHEET 30
/// How many plasma sheets the sublimator's hopper holds
#define SUBLIMATOR_MAX_SHEETS 50
/// Moles per second a rating-1 sublimator trickles into its pipenet
#define SUBLIMATOR_BASE_RATE 2.5

/obj/machinery/atmospherics/components/unary/shuttle/scoop
	name = "nebula ram scoop"
	desc = "An external intake manifold that skims gas out of a nebula while the ship sits still inside one. Feeds whatever pipe network it's wrenched onto."
	icon_state = "scoop"
	idle_power_usage = 25
	circuit = /obj/item/circuitboard/machine/shuttle/scoop

	density = TRUE
	max_integrity = 300
	layer = OBJ_LAYER
	move_resist = MOVE_RESIST_DEFAULT
	pipe_flags = PIPING_ONE_PER_TURF | PIPING_DEFAULT_LAYER_ONLY

	/// Whether the intake is open. A closed intake never harvests and never breaks concealment
	var/intake_open = TRUE
	/// Harvest rate multiplier from stock micro-lasers
	var/efficiency_multiplier = 1

/obj/machinery/atmospherics/components/unary/shuttle/scoop/Initialize(mapload)
	initialize_directions = dir // Set pipe direction before parent reads it
	. = ..()
	RefreshParts()

/obj/machinery/atmospherics/components/unary/shuttle/scoop/on_construction()
	..(dir, dir)
	set_init_directions()

/obj/machinery/atmospherics/components/unary/shuttle/scoop/RefreshParts()
	// Two T1 lasers = x1, two T4 lasers = x4
	efficiency_multiplier = max(total_part_rating(/datum/stock_part/micro_laser) / 2, 1)

/obj/machinery/atmospherics/components/unary/shuttle/scoop/examine(mob/user)
	. = ..()
	. += span_notice("The intake is [intake_open ? "open" : "closed"]. Click to toggle it.")
	. += span_notice("It only harvests while the ship is sitting still inside a nebula, and running it lights the ship up on everyone's sensors.")
	. += span_notice("Harvested gas feeds the connected pipe network; run it to an engine heater in pipe mode, or to a connector port to fill tanks and canisters.")

/obj/machinery/atmospherics/components/unary/shuttle/scoop/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return
	intake_open = !intake_open
	balloon_alert(user, "intake [intake_open ? "opened" : "closed"]")

/obj/machinery/atmospherics/components/unary/shuttle/scoop/process_atmos(seconds_per_tick)
	if(!intake_open || panel_open || !anchored || !is_operational)
		return
	var/obj/structure/overmap/ship/ship = get_ship_from_atom(src)
	if(!ship || ship.state != OVERMAP_SHIP_FLYING || !ship.is_still())
		return
	var/turf/overmap_turf = get_turf(ship)
	if(!overmap_turf)
		return
	var/obj/structure/overmap/event/nebula/cloud = locate() in overmap_turf
	if(!cloud?.gas_type)
		return

	var/datum/gas_mixture/air_contents = airs[1]
	if(!air_contents || air_contents.return_pressure() >= MAX_OUTPUT_PRESSURE)
		return

	var/moles = cloud.get_scoop_rate() * efficiency_multiplier * seconds_per_tick
	if(moles <= 0)
		return
	if(air_contents.temperature <= 0)
		air_contents.temperature = T20C
	air_contents.assert_gas(cloud.gas_type)
	air_contents.moles[cloud.gas_type] += moles
	update_parents()

	// Harvesting is loud: this blocks/breaks nebula concealment on the ship
	ship.notify_scoop_activity()

/obj/machinery/atmospherics/components/unary/shuttle/scoop/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, "scoop_open", "scoop", tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/unary/shuttle/scoop/wrench_act(mob/living/user, obj/item/tool)
	if(!panel_open)
		balloon_alert(user, "open panel first!")
		return ITEM_INTERACT_SUCCESS
	var/result = default_unfasten_wrench(user, tool)
	if(result == SUCCESSFUL_UNFASTEN)
		change_pipe_connection(!anchored)
	if(result)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/atmospherics/components/unary/shuttle/scoop/crowbar_act(mob/living/user, obj/item/tool)
	if(default_pry_open(tool))
		return ITEM_INTERACT_SUCCESS
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/unary/shuttle/sublimator
	name = "plasma sublimation chamber"
	desc = "A sealed retort that bakes raw plasma sheets down into clean plasma gas. Feeds whatever pipe network it's wrenched onto."
	icon_state = "sublimator"
	idle_power_usage = 50
	circuit = /obj/item/circuitboard/machine/shuttle/sublimator

	density = TRUE
	max_integrity = 300
	layer = OBJ_LAYER
	move_resist = MOVE_RESIST_DEFAULT
	pipe_flags = PIPING_ONE_PER_TURF | PIPING_DEFAULT_LAYER_ONLY

	/// Plasma sheets waiting in the hopper
	var/stored_sheets = 0
	/// Moles of the sheet currently being baked that haven't been released yet
	var/buffered_moles = 0
	/// Output rate multiplier from stock micro-lasers
	var/efficiency_multiplier = 1

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/Initialize(mapload)
	initialize_directions = dir // Set pipe direction before parent reads it
	. = ..()
	RefreshParts()

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/on_construction()
	..(dir, dir)
	set_init_directions()

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/RefreshParts()
	efficiency_multiplier = max(total_part_rating(/datum/stock_part/micro_laser), 1)

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/examine(mob/user)
	. = ..()
	. += span_notice("The hopper holds [stored_sheets]/[SUBLIMATOR_MAX_SHEETS] plasma sheets. Feed it sheets by hand, or alt-click to empty it. Each sheet bakes down into [SUBLIMATOR_MOLES_PER_SHEET] moles of plasma gas.")
	. += span_notice("Output feeds the connected pipe network; run it to an engine heater in pipe mode, or to a connector port to fill tanks and canisters.")

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/attackby(obj/item/attacking_item, mob/living/user, params)
	if(istype(attacking_item, /obj/item/stack/sheet/mineral/plasma))
		var/obj/item/stack/sheet/mineral/plasma/sheets = attacking_item
		var/space_left = SUBLIMATOR_MAX_SHEETS - stored_sheets
		if(space_left <= 0)
			balloon_alert(user, "hopper full!")
			return
		var/to_load = min(space_left, sheets.amount)
		if(!sheets.use(to_load))
			return
		stored_sheets += to_load
		balloon_alert(user, "loaded [to_load] sheet[to_load > 1 ? "s" : ""]")
		return
	return ..()

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/click_alt(mob/living/user)
	. = ..()
	if(!stored_sheets)
		balloon_alert(user, "hopper empty!")
		return
	new /obj/item/stack/sheet/mineral/plasma(drop_location(), stored_sheets)
	balloon_alert(user, "hopper emptied")
	stored_sheets = 0

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/process_atmos(seconds_per_tick)
	if(panel_open || !anchored || !is_operational)
		return
	if(buffered_moles <= 0 && stored_sheets > 0)
		stored_sheets--
		buffered_moles += SUBLIMATOR_MOLES_PER_SHEET
	if(buffered_moles <= 0)
		return

	var/datum/gas_mixture/air_contents = airs[1]
	if(!air_contents || air_contents.return_pressure() >= MAX_OUTPUT_PRESSURE)
		return

	var/moles = min(buffered_moles, SUBLIMATOR_BASE_RATE * efficiency_multiplier * seconds_per_tick)
	if(moles <= 0)
		return
	buffered_moles -= moles
	if(air_contents.temperature <= 0)
		air_contents.temperature = T20C
	air_contents.assert_gas(/datum/gas/plasma)
	air_contents.moles[/datum/gas/plasma] += moles
	update_parents()

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/screwdriver_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_screwdriver(user, "sublimator_open", "sublimator", tool))
		return ITEM_INTERACT_SUCCESS

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/wrench_act(mob/living/user, obj/item/tool)
	if(!panel_open)
		balloon_alert(user, "open panel first!")
		return ITEM_INTERACT_SUCCESS
	var/result = default_unfasten_wrench(user, tool)
	if(result == SUCCESSFUL_UNFASTEN)
		change_pipe_connection(!anchored)
	if(result)
		return ITEM_INTERACT_SUCCESS
	return ITEM_INTERACT_BLOCKING

/obj/machinery/atmospherics/components/unary/shuttle/sublimator/crowbar_act(mob/living/user, obj/item/tool)
	if(default_pry_open(tool))
		return ITEM_INTERACT_SUCCESS
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS

#undef SUBLIMATOR_MOLES_PER_SHEET
#undef SUBLIMATOR_MAX_SHEETS
#undef SUBLIMATOR_BASE_RATE
