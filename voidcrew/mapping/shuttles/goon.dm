/**
 * Goon-class Repurposed Emergency Shuttle
 *
 * * A homage to Goonstation's emergency shuttle: four colour-coded pods bolted
 *   onto a central corridor spine. Free starter hull, 19x11.
 * * Converted to the modular standard with 5 upgrade slots - every room on the
 *   ship except the spine, the nacelles and the bridge's service column.
 * * 4 themes: NT Standard (the colour-pod homage, default), Void Runner,
 *   Syndicate Cutter, Slumber Party.
 * * No slot gets its own area. Each pocket sits in the hull area it was carved
 *   out of and rides that area's APC, which stays on a permanent tile:
 *   (7,7) for the port pod, (7,3) for engineering, (9,6) for commons, (16,7)
 *   for the bridge. Modules must cover those tiles with /turf/template_noop.
 * * Trunk runs that cross a pocket to serve rooms beyond it stay in the hull -
 *   the engineering distro main on y4, the commons waste riser up column 12,
 *   the port pod's service spine on y8 - along with the vents and scrubbers
 *   sitting on them. Module loading never clears a tile, so modules simply
 *   leave those tiles' plumbing alone rather than re-laying it.
 */
/datum/map_template/shuttle/voidcrew/goon
	name = "Goon-class Repurposed Emergency Shuttle"
	suffix = "goon_a" // Default suffix, overridden by selected theme
	short_name = "Goon-class"
	catalog_desc = "Four colour-coded pods bolted onto a central corridor, salvaged from an \
		old emergency shuttle. The cheapest hull with real rooms, and nearly all of it is \
		modular: the port pod, engineering, the mining bay, the lounge and the cockpit \
		annex all swap out. A good first ship for three or four crew."
	part_requirements = list(PART_CLASS_TRADE = 5, PART_CLASS_MISC = 3, PART_CLASS_SCIENCE = 2)
	has_upgrade_slots = TRUE
	upgrade_slot_ids = list(
		"goon_port",
		"goon_engineering",
		"goon_mining",
		"goon_lounge",
		"goon_cockpit",
	)
	available_themes = list("standard", "void", "syndicate", "slumber")
	// job_slots come from the selected theme, not defined here

/// DOCKING PORT ///

/obj/docking_port/mobile/voidcrew/goon // Brewing up something awful here
	name = "Goon-class Repurposed Emergency Shuttle"
	area_type = /area/shuttle/voidcrew/goon
	// The port is mapped on the port-side boarding airlock at (10,11) aimed inboard, so a
	// hard dock mates the airlock instead of the bridge windows on the nose. Off the port
	// beam of an east-facing hull, so WEST - same as kilo and delta.
	port_direction = 8
	// The hull is 19x11 and the port faces south, so the shuttle measures 19 fore to aft
	// against 11 abeam and the aspect-ratio guess in adjust_reserve_dock_to_shuttle comes
	// out EAST. This must match it or the ship spins 90 degrees on every dock.
	preferred_direction = 4

/obj/docking_port/mobile/voidcrew/goon/a
	name = "Goon-class Repurposed Emergency Shuttle A"

/obj/docking_port/mobile/voidcrew/goon/b
	name = "Goon-class Repurposed Emergency Shuttle B"

/obj/docking_port/mobile/voidcrew/goon/c
	name = "Goon-class Repurposed Emergency Shuttle C"

/obj/docking_port/mobile/voidcrew/goon/d
	name = "Goon-class Repurposed Emergency Shuttle D"


/// AREAS ///

/// Command ///

/area/shuttle/voidcrew/goon/bridge
	name = "Bridge"
	icon_state = "bridge"

/area/shuttle/voidcrew/goon/bridge/a

/area/shuttle/voidcrew/goon/bridge/b

/area/shuttle/voidcrew/goon/bridge/c

/area/shuttle/voidcrew/goon/bridge/d

/// Engineering ///

/area/shuttle/voidcrew/goon/engineering
	name = "Engineering"
	icon_state = "engine"

/area/shuttle/voidcrew/goon/engineering/a

/area/shuttle/voidcrew/goon/engineering/b

/area/shuttle/voidcrew/goon/engineering/c

/area/shuttle/voidcrew/goon/engineering/d

/// Medbay ///

/area/shuttle/voidcrew/goon/medbay
	name = "Port Pod"
	icon_state = "medbay"

/area/shuttle/voidcrew/goon/medbay/a

/area/shuttle/voidcrew/goon/medbay/b

/area/shuttle/voidcrew/goon/medbay/c

/area/shuttle/voidcrew/goon/medbay/d

/// Misc ///

/area/shuttle/voidcrew/goon/commons
	name = "Commons"
	icon_state = "station"

/area/shuttle/voidcrew/goon/commons/a

/area/shuttle/voidcrew/goon/commons/b

/area/shuttle/voidcrew/goon/commons/c

/area/shuttle/voidcrew/goon/commons/d
