// Voidcrew extensions to code/modules/mob/living/carbon/inventory.dm.

/**
 * Records why an open air tank was cut off, plus everything invalid_internals() reads.
 * Cutoffs have been reported during shuttle docking with the tank still slotted and the mask
 * still worn, which no call path explains - this dumps the state at the moment it happens.
 * Goes to the shuttle log so it lands next to the dock entries for the same tick.
 */
/mob/living/carbon/proc/log_internals_cutoff(reason)
	var/obj/item/tank/closing = external || internal
	var/atom/tank_loc = closing.loc
	log_shuttle("INTERNALS CUTOFF: [key_name(src)] at [AREACOORD(src)] reason=[reason] tank=[closing.type] ([external ? "external" : "internal"]) tank_loc=[tank_loc] ([tank_loc?.type]) loc_is_mob=[tank_loc == src ? "yes" : "NO"] apparatus=[can_breathe_internals() || "NONE"] mask=[wear_mask ? "[wear_mask.type] up=[wear_mask.up] flags=[wear_mask.clothing_flags]" : "NONE"] head=[head ? "[head.type] flags=[head.clothing_flags]" : "NONE"] tube=[can_breathe_tube() ? "yes" : "no"] stat=[stat]")
