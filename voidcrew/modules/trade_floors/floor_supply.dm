/**
 * # Outpost floors: supplies and the goods lift
 *
 * Owner: P13 (spec 3b.2, L30). The supply console is the old shells' (/obj/machinery/computer/voidcrew_cargo): on a
 * floor it already finds the host's freight (get_cargo_shuttle()) and pays from the host's treasury
 * (cargo_account()). A floor has no ferry and no cargo dock: its freight makes the ordered crates on the goods
 * lift's tiles (floor.goods_turfs) OUTPOST_FLOOR_GOODS_TIME after the order, OUTPOST_FLOOR_GOODS_CRATES at most, and
 * sends nothing back (A84). The fit-out supply packs live here too. The goods lift fixture is declared in floor_shell.dm.
 *
 * P0 declared the type so the host can make one; until P13 fills it, it behaves as the outpost's ferry does.
 */

/datum/voidcrew_cargo_shuttle/outpost/floor
