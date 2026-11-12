/**
 * # Outpost floors: the shell
 *
 * Owner: P1. The ground a floor is made of and the fixtures that come with the lease. P0 declared the types so maps,
 * the save exclusion list and other packages can name them; P1 gives each its body.
 *
 * - The deck is its own baseturf (A4), rcd_proof, and ignores blasts, acid and melting. It is plating: tiles go on it.
 * - The hull is a /turf/closed/wall subtype because wall mounts only take /turf/closed/wall (try_wallmount(),
 *   /obj/item/sign). It must refuse every way a wall can be broken (A93).
 * - The mains tap, the front door, the goods lift and the nameplate are outpost property and never saved on a ship.
 */

/// One instance per floor (not unique), covering hull, deck and landing. Rooms bring their own areas.
/area/voidcrew/player_outpost/floor
	name = "\improper Outpost Floor"

/// The deck of a leased floor
/turf/open/floor/plating/outpost_deck
	name = "deck"
	baseturfs = /turf/open/floor/plating/outpost_deck
	rcd_proof = TRUE

/// The hull of a leased floor: looks like a wall, takes wall mounts, cannot be broken
/turf/closed/wall/outpost_floor_hull
	name = "hull"

/// A fixed supply wired to the floor's APC: power comes with the lease
/obj/machinery/power/outpost_mains
	name = "mains tap"

/// The landing's one door into the floor
/obj/machinery/door/airlock/outpost_floor_front
	name = "front door"

/// Marks one tile of a floor's lift alcove; the shell link collects them
/obj/effect/landmark/outpost_floor_alcove
	name = "floor lift alcove"

/// Marks one tile of the goods lift; the shell link collects them
/obj/effect/landmark/outpost_floor_goods
	name = "goods lift tile"

/// The goods lift's hatch: where ordered crates arrive (floor_supply.dm, P13, gives it its behaviour)
/obj/structure/outpost_goods_lift
	name = "goods lift"
	anchored = TRUE

/// A floor's shell. The two styles follow the outpost: clean at the Halcyon and Quartermain, rundown at the Undertow.
/datum/map_template/outpost_floor
	name = "Outpost Floor"

/datum/map_template/outpost_floor/clean
	name = "Outpost Floor (clean)"

/datum/map_template/outpost_floor/rundown
	name = "Outpost Floor (rundown)"
