/**
 * # Outpost floors: the directory board
 *
 * Owner: P11 (spec 5.2, 12). One board on each concourse lists the building. Its window is OutpostDirectory.tsx
 * (build plan, data contracts). No prices, no rules, nothing typed but the floor's cleaned name and line.
 *
 * Stubs below are P0's.
 */

/// The board on a concourse wall
/obj/machinery/outpost_directory
	name = "directory"
	density = FALSE

/// Where a concourse map hangs its board; with none, the board hangs by the first lobby lift panel
/obj/effect/landmark/outpost_directory
	name = "outpost directory"

/// This floor's row for the board (build plan, OutpostDirectory). Stub: null.
/datum/outpost_floor/proc/directory_row()
	return null
