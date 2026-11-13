// Package: P2 guns and cartridges. The sealed plasma chamber cell: refuses outside charge, magic charge,
// corruption, explosion and reagents.
//
// Its charge is mol of plasma, and plasma only comes in from a seated cartridge (plasma_guns.dm).
// Everything that would charge a normal cell is refused here. The gun also keeps the chamber out of
// its contents (plasma_weapon/Initialize), because some tg code writes `charge` straight onto every
// power_store in a mob's contents (battery plants, yellow regenerative extracts, the experimentor),
// and no override can catch a raw var write.

/obj/item/stock_parts/power_store/cell/plasma_chamber
	desc = "A sealed glass chamber."
	maxcharge = PLASMA_CARTRIDGE_CAPACITY
	empty = TRUE
	ratingdesc = FALSE
	charge_light_type = null
	connector_type = null

/obj/item/stock_parts/power_store/cell/plasma_chamber/give(amount)
	return 0

/obj/item/stock_parts/power_store/cell/plasma_chamber/change(amount)
	return 0

/obj/item/stock_parts/power_store/cell/plasma_chamber/on_magic_charge(datum/source, datum/action/cooldown/spell/charge/spell, mob/living/caster)
	SIGNAL_HANDLER
	return NONE

/obj/item/stock_parts/power_store/cell/plasma_chamber/corrupt(force)
	return

/obj/item/stock_parts/power_store/cell/plasma_chamber/explode()
	return

/// No reagent holder, so nothing can rig it
/obj/item/stock_parts/power_store/cell/plasma_chamber/create_reagents(max_vol, flags)
	return

/// Plasma isn't charge; an EMP leaves it alone
/obj/item/stock_parts/power_store/cell/plasma_chamber/emp_act(severity)
	var/held = charge
	. = ..()
	charge = held
