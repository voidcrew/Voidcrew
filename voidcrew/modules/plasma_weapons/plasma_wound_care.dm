// Plasma burn care: field picks, the slag surgery and the slag bead. Seam stubs.

/// Picks slag out of a plasma burn with a tool.
/datum/wound/burn/flesh/plasma/proc/pick_slag(obj/item/tool, mob/user)
	return FALSE

/obj/item/plasma_slag
	name = "slag bead"
	desc = "A bead of cooled plasma slag."
	icon = 'icons/obj/debris.dmi'
	icon_state = "plasmatiny"
	w_class = WEIGHT_CLASS_TINY
