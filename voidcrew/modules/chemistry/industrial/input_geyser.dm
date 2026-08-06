/**
 * Geyser pump.
 *
 * Ported from monkestation's wiremod_chem module (components/inputs/geyser_input.dm).
 *
 * Sits on top of a geyser and slowly siphons it into a chemical input tank, so a circuit
 * can be fed by planetside chemistry instead of a synthesizer. Runs off the geyser's own
 * thermal energy, which is why it needs no power hookup - dragging two hundred cables out
 * to a geyser field was never the fun part.
 */
/obj/structure/chemical_input/liquid_pump
	name = "geyser pump"
	desc = "Pumps up those sweet liquids from under the surface. Uses thermal energy from geysers to power itself."
	icon = 'icons/obj/pipes_n_cables/hydrochem/plumbers.dmi'
	icon_state = "pump"
	base_icon_state = "pump"
	reagent_flags = TRANSPARENT | DRAINABLE
	component_name = "Geyser Input"

	/// Units pumped per second.
	var/pump_power = 1
	/// Set once we have looked for a geyser under us and found nothing, so we stop
	/// re-scanning the turf every single tick. Cleared when the pump is unwrenched.
	var/geyserless = FALSE
	var/obj/structure/geyser/geyser

/obj/structure/chemical_input/liquid_pump/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSmachines, src)

/obj/structure/chemical_input/liquid_pump/Destroy()
	//VOIDCREW FIX: monkestation chained to the parent before unregistering, leaving a
	//destroyed pump on the processing list.
	STOP_PROCESSING(SSmachines, src)
	geyser = null
	return ..()

/obj/structure/chemical_input/liquid_pump/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.tool_behaviour == TOOL_WRENCH)
		if(attacking_item.use_tool(src, user, 4 SECONDS, volume = 75))
			to_chat(user, span_notice("You [anchored ? "un" : ""]secure [src]."))
			set_anchored(!anchored)
			//Moving the pump means the answer to "is there a geyser here" changed.
			geyser = null
			geyserless = FALSE
			update_appearance()
			return
	return ..()

/obj/structure/chemical_input/liquid_pump/process(seconds_per_tick)
	if(!anchored || geyserless)
		return

	if(QDELETED(geyser))
		geyser = locate(/obj/structure/geyser) in loc
		if(!geyser) //we didn't find one, abort until we get moved
			geyserless = TRUE
			visible_message(span_warning("[src] makes a sad beep!"))
			playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50)
			return
		update_appearance()

	pump(seconds_per_tick)

/// Pump up that sweet geyser nectar.
/obj/structure/chemical_input/liquid_pump/proc/pump(seconds_per_tick)
	if(!geyser?.reagents)
		return
	geyser.reagents.trans_to(src, pump_power * seconds_per_tick)

/obj/structure/chemical_input/liquid_pump/update_icon_state()
	icon_state = geyser ? "[base_icon_state]-on" : base_icon_state
	return ..()
