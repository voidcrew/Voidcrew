/**
 * # Outpost floors: the shell
 *
 * Owner: P1. The ground a floor is made of, the fixtures that come with the lease, and the link that ties a loaded
 * shell to its floor and its host.
 *
 * - The deck is the bottom of every turf stack on a floor (A4): nothing scrapes, blasts, melts or burns through it,
 *   and whatever a crew lays or builds on it comes back off to bare deck. It is plating: tiles go on it.
 * - The hull is a /turf/closed/wall subtype because wall mounts only take /turf/closed/wall (try_wallmount(),
 *   /obj/item/sign). It refuses every way a wall can be broken (A93).
 * - The mains tap, the front door and everything else the shell map places are outpost property, and never saved
 *   on a ship (GLOB.outpost_checkpoint_excluded).
 *
 * What a shell map must hold (link_shell() below reads it; build plan P7):
 * - a ring of hull, deck inside, one /area/voidcrew/player_outpost/floor over all of it;
 * - /obj/effect/landmark/outpost_floor_alcove on each tile of the lift alcove, and one /obj/machinery/outpost_elevator;
 * - the landing: the OUTPOST_FLOOR_LANDING_WIDTH by OUTPOST_FLOOR_LANDING_HEIGHT box just inside the south hull,
 *   centred on the alcove's middle column, its own walls included. Its one door is the front door, on the box's
 *   edge, with deck on its far side;
 * - /obj/effect/landmark/outpost_floor_goods on each goods lift tile;
 * - a management console, a construction console, a supply console, a bank terminal, a cryopod and an arrival
 *   landmark (install_home_bundle() needs all of them), an ore silo, an APC and a mains tap wired to it.
 */

/// One instance per floor (not unique), covering hull, deck and landing. Rooms bring their own areas.
/area/voidcrew/player_outpost/floor
	name = "\improper Outpost Floor"

// ===== THE DECK =====

/// The deck of a leased floor
/turf/open/floor/plating/outpost_deck
	name = "deck"
	desc = "The deck of the outpost. Tiles go down on it. Nothing goes through it."
	baseturfs = /turf/open/floor/plating/outpost_deck
	rcd_proof = TRUE
	rust_resistance = RUST_RESISTANCE_ABSOLUTE
	heat_capacity = INFINITY

/// Nothing is under the deck: whatever its stack says, it never comes up
/turf/open/floor/plating/outpost_deck/ScrapeAway(amount = 1, flags)
	return src

/// A blast leaves the deck alone. EX_ACT() has already passed it on to whatever stands here.
/turf/open/floor/plating/outpost_deck/ex_act(severity, target)
	return FALSE

/turf/open/floor/plating/outpost_deck/acid_act(acidpwr, acid_volume, acid_id)
	return FALSE

/turf/open/floor/plating/outpost_deck/acid_melt()
	return

/turf/open/floor/plating/outpost_deck/Melt()
	to_be_destroyed = FALSE
	return src

/turf/open/floor/plating/outpost_deck/singularity_act()
	return

/turf/open/floor/plating/outpost_deck/TerraformTurf(path, new_baseturf, flags)
	return

/turf/open/floor/plating/outpost_deck/rust_heretic_act(rust_strength = 1)
	return

/turf/open/floor/plating/outpost_deck/rust_turf()
	return

/// The Undertow's decks have seen more boots
/turf/open/floor/plating/outpost_deck/rundown
	desc = "The deck of the outpost, rusted where the paint gave up. Nothing goes through it."
	icon_state = "plating_rust"
	baseturfs = /turf/open/floor/plating/outpost_deck/rundown

// ===== THE HULL =====

/// The hull of a leased floor: looks like a wall, takes wall mounts, cannot be broken
/turf/closed/wall/outpost_floor_hull
	name = "hull"
	desc = "The outpost's hull. A nail goes in. Nothing else does."
	icon = 'icons/turf/walls/reinforced_wall.dmi'
	icon_state = "reinforced_wall-0"
	base_icon_state = "reinforced_wall"
	baseturfs = /turf/closed/wall/outpost_floor_hull
	explosive_resistance = 50
	rust_resistance = RUST_RESISTANCE_ABSOLUTE
	heat_capacity = INFINITY
	rad_insulation = RAD_HEAVY_INSULATION
	// prob(hardness) is the chance a hulk or a mech goes through
	hardness = 0
	can_engrave = FALSE
	sheet_amount = 0
	girder_type = null

/turf/closed/wall/outpost_floor_hull/deconstruction_hints(mob/user)
	return span_notice("There is no seam to work at.")

/// Every tool, fist, drill and smasher that takes a wall down ends here (walls.dm), and here nothing happens
/turf/closed/wall/outpost_floor_hull/dismantle_wall(devastated = FALSE, explode = FALSE, disassembled = FALSE)
	return

/turf/closed/wall/outpost_floor_hull/ScrapeAway(amount = 1, flags)
	return src

/turf/closed/wall/outpost_floor_hull/ex_act(severity, target)
	return FALSE

/turf/closed/wall/outpost_floor_hull/try_decon(obj/item/I, mob/user)
	if(I.tool_behaviour == TOOL_WELDER)
		balloon_alert(user, "too thick!")
	return FALSE

/turf/closed/wall/outpost_floor_hull/drill_act(obj/item/mecha_parts/mecha_equipment/drill/drill, mob/user)
	return

/turf/closed/wall/outpost_floor_hull/blob_act(obj/structure/blob/B)
	add_dent(WALL_DENT_HIT)

/turf/closed/wall/outpost_floor_hull/wall_singularity_pull(current_size)
	return

/turf/closed/wall/outpost_floor_hull/singularity_act()
	return

/turf/closed/wall/outpost_floor_hull/narsie_act(force, ignore_mobs, probability = 20)
	return FALSE

/turf/closed/wall/outpost_floor_hull/acid_act(acidpwr, acid_volume, acid_id)
	return FALSE

/turf/closed/wall/outpost_floor_hull/acid_melt()
	return

/turf/closed/wall/outpost_floor_hull/Melt()
	to_be_destroyed = FALSE
	return src

/turf/closed/wall/outpost_floor_hull/TerraformTurf(path, new_baseturf, flags)
	return

/turf/closed/wall/outpost_floor_hull/rust_heretic_act(rust_strength = 1)
	return

/turf/closed/wall/outpost_floor_hull/rust_turf()
	return

/// An RCD hangs a wall mount on the hull and takes nothing off it
/turf/closed/wall/outpost_floor_hull/rcd_vals(mob/user, obj/item/construction/rcd/the_rcd)
	if(the_rcd.mode == RCD_DECONSTRUCT)
		return FALSE
	return ..()

/turf/closed/wall/outpost_floor_hull/rcd_act(mob/user, obj/item/construction/rcd/the_rcd, list/rcd_data)
	if(rcd_data["[RCD_DESIGN_MODE]"] == RCD_DECONSTRUCT)
		return FALSE
	return ..()

/turf/closed/wall/outpost_floor_hull/rundown
	desc = "The outpost's hull, rusted over. A nail goes in. Nothing else does."
	icon = 'icons/turf/walls/rusty_reinforced_wall.dmi'
	icon_state = "rusty_reinforced_wall-0"
	base_icon_state = "rusty_reinforced_wall"
	baseturfs = /turf/closed/wall/outpost_floor_hull/rundown

// ===== FIXTURES =====

/// A fixed supply wired to the floor's APC: power comes with the lease
/obj/machinery/power/outpost_mains
	name = "mains tap"
	desc = "The outpost's mains, brought up through the deck. The bill is in the lease."
	icon = 'icons/obj/pipes_n_cables/structures.dmi'
	icon_state = "cablerelay-off"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	/// Watts put on the wire while one is connected
	var/supply = OUTPOST_FLOOR_MAINS_WATTS

/obj/machinery/power/outpost_mains/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	connect_to_network()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/power/outpost_mains/process()
	var/live = !!add_avail(power_to_energy(supply))
	if(live != (icon_state == "cablerelay-on"))
		update_appearance(UPDATE_ICON_STATE)

/obj/machinery/power/outpost_mains/update_icon_state()
	icon_state = powernet ? "cablerelay-on" : "cablerelay-off"
	return ..()

/// The landing's one door into the floor. The outpost keeps it powered and mends it; the crew keys it.
/obj/machinery/door/airlock/outpost_floor_front
	name = "front door"
	desc = "The door between the lift and the floor."
	use_power = NO_POWER_USE
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	normal_integrity = 1000

/obj/machinery/door/airlock/outpost_floor_front/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/**
 * tg's emag leaves an airlock open, bolted and dark for good, and nobody can take a tool to outpost property to
 * put it right. The door comes back as the outpost's own doors do (trade/outpost_security.dm).
 */
/obj/machinery/door/airlock/outpost_floor_front/finish_emag_act()
	. = ..()
	if(!QDELETED(src) && (obj_flags & EMAGGED))
		addtimer(CALLBACK(src, PROC_REF(mend_emag)), OUTPOST_CHECKPOINT_EMAG_TIME, TIMER_UNIQUE | TIMER_DELETE_ME)

/// The emag wears off: lights, power and bolts back, then the door shuts once nobody is in the way
/obj/machinery/door/airlock/outpost_floor_front/proc/mend_emag()
	if(QDELETED(src) || !(obj_flags & EMAGGED))
		return
	obj_flags &= ~EMAGGED
	lights = TRUE
	regainMainPower()
	regainBackupPower()
	unbolt()
	do_sparks(2, TRUE, src)
	visible_message(span_notice("[src] sparks, and its lights come back on."))
	update_appearance()
	close_when_clear()

/// Shuts once nothing stands in the doorway, trying again every few seconds
/obj/machinery/door/airlock/outpost_floor_front/proc/close_when_clear()
	if(QDELETED(src) || density || locked)
		return
	for(var/atom/movable/thing in get_turf(src))
		if(thing != src && !iseffect(thing) && (isliving(thing) || thing.density))
			addtimer(CALLBACK(src, PROC_REF(close_when_clear)), 3 SECONDS, TIMER_UNIQUE | TIMER_DELETE_ME)
			return
	INVOKE_ASYNC(src, PROC_REF(close))

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

// ===== THE MAPS =====

/// A floor's shell. The two styles follow the outpost: clean at the Halcyon and Quartermain, rundown at the Undertow.
/datum/map_template/outpost_floor
	name = "Outpost Floor"
	// Laid straight onto the reserved ground, not stacked on its space turfs
	should_place_on_top = FALSE

/datum/map_template/outpost_floor/clean
	name = "Outpost Floor (clean)"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_floor_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/map_template/outpost_floor/rundown
	name = "Outpost Floor (rundown)"
	mappath = "voidcrew/_maps/map_files/outposts/outpost_floor_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/// The shell this floor loads: its own pick (tests), else its outpost's style
/datum/outpost_floor/proc/pick_shell_type()
	if(shell_type)
		return shell_type
	if(istype(outpost, /obj/structure/overmap/trader_outpost/black_market))
		return /datum/map_template/outpost_floor/rundown
	return /datum/map_template/outpost_floor/clean

// ===== THE LINK =====

/**
 * Ties a freshly loaded shell to this floor and its host: the lift alcove and panel, the landing, the goods lift,
 * the consoles, the arrival point, the area and the front door. Everything the shell placed becomes outpost
 * property, and the deck becomes the bottom of every turf stack. Returns FALSE when the shell is missing a part
 * the floor cannot work without; the caller then gives the ground back.
 */
/datum/outpost_floor/proc/link_shell()
	if(!host || length(bounds) < 5)
		return FALSE
	var/z = bounds[5]
	var/deck_type
	var/turf/first_alcove
	var/turf/last_alcove
	var/obj/machinery/door/airlock/outpost_floor_front/front_door
	alcove_turfs = list()
	goods_turfs = list()
	// block() goes row by row, the order the lobby's and the berths' alcoves are collected in: the lift maps
	// alcove tile i to alcove tile i
	for(var/turf/tile as anything in block(bounds[1], bounds[2], z, bounds[3], bounds[4], z))
		if(!deck_type && istype(tile, /turf/open/floor/plating/outpost_deck))
			deck_type = tile.type
		if(!host.outpost_area && istype(tile.loc, /area/voidcrew/player_outpost/floor))
			host.outpost_area = tile.loc
		for(var/obj/effect/landmark/outpost_floor_alcove/mark in tile)
			alcove_turfs += tile
			first_alcove ||= tile
			last_alcove = tile
			qdel(mark)
		for(var/obj/effect/landmark/outpost_floor_goods/mark in tile)
			goods_turfs += tile
			qdel(mark)
		for(var/obj/effect/landmark/player_outpost_arrival/mark in tile)
			host.arrival_turf = tile
			qdel(mark)
		for(var/obj/fixture in tile)
			if(istype(fixture, /obj/machinery/computer/player_outpost_management))
				var/obj/machinery/computer/player_outpost_management/console = fixture
				console.outpost = host
				host.management_console = console
			else if(istype(fixture, /obj/machinery/computer/camera_advanced/base_construction/ship/outpost))
				var/obj/machinery/computer/camera_advanced/base_construction/ship/outpost/builder = fixture
				builder.outpost = host
				host.construction_console = builder
			else if(istype(fixture, /obj/machinery/outpost_elevator))
				// The car serves the trader outpost's lift, so that is the panel's host; the floor is where it stands
				var/obj/machinery/outpost_elevator/lift_panel = fixture
				lift_panel.outpost = outpost
				lift_panel.floor = src
				panel = lift_panel
			else if(istype(fixture, /obj/machinery/door/airlock/outpost_floor_front))
				front_door ||= fixture
			protect_shell_fixture(fixture)
	if(!length(alcove_turfs) || !panel || !host.outpost_area)
		log_mapping("OUTPOST FLOORS: the shell of floor [number] at [outpost] has no lift alcove, no lift panel or no floor area.")
		return FALSE
	// The landing: the box just inside the south hull, centred on the alcove (this file's header)
	var/landing_west = clamp(round((first_alcove.x + last_alcove.x) / 2) - round((OUTPOST_FLOOR_LANDING_WIDTH - 1) / 2), bounds[1] + 1, bounds[3] - 1)
	landing_bounds = list(
		landing_west,
		bounds[2] + 1,
		min(landing_west + OUTPOST_FLOOR_LANDING_WIDTH - 1, bounds[3] - 1),
		min(bounds[2] + OUTPOST_FLOOR_LANDING_HEIGHT, bounds[4] - 1),
		z,
	)
	for(var/turf/tile as anything in alcove_turfs)
		if(!in_landing(tile))
			log_mapping("OUTPOST FLOORS: the lift alcove of floor [number] at [outpost] reaches outside its landing at [tile.x],[tile.y].")
			break
	lay_ground(deck_type || /turf/open/floor/plating/outpost_deck)
	if(front_door)
		host.shell_front_door = WEAKREF(front_door)
		host.key_front_door()
	return TRUE

/**
 * Makes one machine or structure of the shell outpost property, as a service room does its fixtures
 * (/datum/outpost_upgrade/service/proc/protect_fixture()). Cable is left alone: the crew re-lays its own wiring,
 * and the element would stop the owner's wirecutters too.
 */
/datum/outpost_floor/proc/protect_shell_fixture(obj/fixture)
	if(QDELETED(fixture) || (!ismachinery(fixture) && !isstructure(fixture)) || istype(fixture, /obj/structure/cable))
		return
	fixture.AddElement(/datum/element/outpost_property)
	ADD_TRAIT(fixture, TRAIT_SINGULARITY_IMMUNE, OUTPOST_SERVICE_TRAIT)
	if(!isstructure(fixture))
		return
	if(!fixture.anchored)
		fixture.set_anchored(TRUE)
	if(istype(fixture, /obj/structure/closet))
		var/obj/structure/closet/closet = fixture
		closet.anchorable = FALSE

/**
 * Makes `deck_type` the bottom of every turf stack on the floor, and the hull its own. A map loader may stack
 * what it lays on the reserved space under it, and a mapped tile or wall keeps tg's own baseturfs: either would
 * open the floor to space the first time something was pried up or blown out (A4).
 */
/datum/outpost_floor/proc/lay_ground(deck_type)
	for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
		if(istype(tile, /turf/closed/wall/outpost_floor_hull) || istype(tile, /turf/open/floor/plating/outpost_deck))
			tile.baseturfs = tile.type
		else
			tile.baseturfs = deck_type
