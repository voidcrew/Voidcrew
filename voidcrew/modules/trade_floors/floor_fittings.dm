/**
 * # Outpost floors: shop fittings and their kits
 *
 * Owner: P12 (spec 3b.4, L32). A kit is an item from the supply console. Set down on a buildable deck tile of a floor
 * with a Shop room, by someone who may build there and under the cap, it becomes a fitting: outpost property, never
 * dense (A94), never saved on a ship. A manager packs a fitting back into its kit. A hit on one goes to the police
 * (floor_fitting_hit(), P5). P0 declared the types so supply packs and the save exclusion list can name them.
 *
 * Stubs below are P0's.
 */

/// A fitting in its box
/obj/item/outpost_floor_kit
	name = "fitting kit"
	w_class = WEIGHT_CLASS_BULKY
	/// OUTPOST_FLOOR_FITTING_*
	var/kind

/obj/item/outpost_floor_kit/till
	name = "till kit"
	kind = OUTPOST_FLOOR_FITTING_TILL

/obj/item/outpost_floor_kit/shelf
	name = "sale shelf kit"
	kind = OUTPOST_FLOOR_FITTING_SHELF

/obj/item/outpost_floor_kit/sign
	name = "floor sign kit"
	kind = OUTPOST_FLOOR_FITTING_SIGN

/// A second register anywhere on the floor. It sells from the Shop room's stock (the host's owns_till()).
/obj/machinery/computer/outpost_shop_register/floor_till
	name = "till"

/// Shows one listing of the shop's stock and sells it
/obj/structure/outpost_floor_shelf
	name = "sale shelf"
	anchored = TRUE
	density = FALSE

/// The floor's name in its colour, and OPEN or SHUT under it. The nameplate by the front door is one of these.
/obj/structure/sign/outpost_floor
	name = "floor sign"

/// How many fittings of `kind` (OUTPOST_FLOOR_FITTING_*) are down on this floor. Stub: 0.
/datum/outpost_floor/proc/fitting_count(kind)
	return 0
