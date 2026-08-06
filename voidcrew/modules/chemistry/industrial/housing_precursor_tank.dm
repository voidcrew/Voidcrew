/**
 * Precursor tank.
 *
 * Ported from monkestation's wiremod_chem module (housing/precursor_tank.dm).
 *
 * Feedstock for the chemical manufacturer. Refilled by walking it up to a chem dispenser
 * and draining that dispenser's cell into it, which is what ties automated chemistry back
 * to the station's power budget instead of letting it run on nothing.
 */
/obj/item/precursor_tank
	name = "precursor tank"
	desc = "A bulky tank of chemical precursor feedstock. Slots into a chemical manufacturer."

	icon = 'voidcrew/icons/obj/industrial_chem_items.dmi'
	icon_state = "precursor_tank"

	w_class = WEIGHT_CLASS_HUGE
	force = 10
	throwforce = 13
	throw_speed = 2
	throw_range = 4
	item_flags = NO_PIXEL_RANDOM_DROP

	var/stored_precursor = 2500
	var/max_precursor = 2500

/// Cell energy spent per unit of precursor drawn out of a chem dispenser.
#define PRECURSOR_ENERGY_PER_UNIT 10

/obj/item/precursor_tank/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/two_handed, require_twohands = TRUE, force_unwielded = 10, force_wielded = 10)

/obj/item/precursor_tank/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!istype(target, /obj/machinery/chem_dispenser))
		return ..()

	var/obj/machinery/chem_dispenser/dispenser = target
	var/missing = max_precursor - stored_precursor
	if(missing <= 0)
		balloon_alert(user, "already full!")
		return TRUE
	if(!dispenser.cell)
		balloon_alert(user, "no cell in dispenser!")
		return TRUE

	if(!do_after(user, 3 SECONDS, dispenser))
		return TRUE

	//Re-check after the do_after: the cell can be swapped out or drained while we wait.
	if(!dispenser.cell)
		return TRUE
	var/max_units = round(dispenser.cell.charge / PRECURSOR_ENERGY_PER_UNIT)
	var/drawn = min(missing, max_units)
	if(drawn <= 0)
		balloon_alert(user, "dispenser is flat!")
		return TRUE

	dispenser.cell.charge -= drawn * PRECURSOR_ENERGY_PER_UNIT
	stored_precursor += drawn
	user.visible_message(
		span_notice("[user] fills up [src] from [dispenser]."),
		span_notice("You fill up [src] from [dispenser]."),
	)
	return TRUE

/obj/item/precursor_tank/examine(mob/user)
	. = ..()
	. += span_notice("It currently holds <b>[stored_precursor]</b> out of [max_precursor] units of precursor.")
	. += span_notice("It can be refilled from a chemical dispenser's power cell.")

#undef PRECURSOR_ENERGY_PER_UNIT
