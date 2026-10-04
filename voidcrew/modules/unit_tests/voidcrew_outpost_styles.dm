/**
 * Outpost styles (outpost_styles.dm). Every shell a founder can pick loads and links; every upgrade
 * room, in every style and all four turns, works where it is placed (contract_problems() in
 * outpost_room_contracts.dm); every ship bay style loads and links.
 *
 * Voidcrew defines are not visible from test files, so style ids come from the templates themselves.
 */

/// The old compact habitat. Tests that are not about the shells build on it, so redrawing a shell
/// never moves their furniture. Founders are never offered it.
/datum/map_template/player_outpost/test_fixture
	name = "Test Habitat"
	mappath = "voidcrew/_maps/map_files/unit_tests/player_outpost_shell_fixture.dmm"

/// The shipyard console standing in a ship bay, or null
/proc/outpost_bay_shipyard_console(datum/outpost_berth/ship_bay/bay)
	if(QDELETED(bay))
		return null
	for(var/obj/machinery/computer/ship_checkpoint/console as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/ship_checkpoint))
		if(bay.contains_turf(get_turf(console)))
			return console
	return null

/// Every style a founder can pick, from the selectable shells
/proc/outpost_founder_styles()
	. = list()
	for(var/datum/map_template/player_outpost/shell_type as anything in outpost_selectable_shells())
		. |= initial(shell_type.outpost_style)

/// Catalog ids of the upgrades drawn once per style and placed freely: not the prison wing's
/// extensions, which only join its walls (voidcrew_outpost_prison_styles checks them in every style)
/proc/outpost_styled_upgrade_ids()
	. = list()
	for(var/upgrade_id in GLOB.outpost_upgrade_catalog)
		var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
		if(upgrade.snap_group)
			continue
		for(var/datum/map_template/map_type as anything in outpost_style_maps(upgrade.template_type))
			if(initial(map_type.outpost_style))
				. += upgrade_id
				break

/// Each style a founder can pick has a map for every upgrade and the ship bay; an unknown style falls back.
/datum/unit_test/voidcrew_outpost_style_resolution

/datum/unit_test/voidcrew_outpost_style_resolution/Run()
	var/list/styles = outpost_founder_styles()
	TEST_ASSERT(length(styles) >= 2, "Founders have fewer than two styles to pick from")
	var/list/styled = outpost_styled_upgrade_ids()
	TEST_ASSERT(length(styled), "No upgrade is drawn per style")
	for(var/style in styles)
		for(var/upgrade_id in styled)
			var/datum/outpost_upgrade/upgrade = GLOB.outpost_upgrade_catalog[upgrade_id]
			var/datum/map_template/room_map = outpost_style_map(upgrade.template_type, style)
			TEST_ASSERT(room_map && initial(room_map.outpost_style) == style, "The [upgrade.name] has no [style] map")
		var/datum/map_template/bay_map = outpost_style_map(/datum/map_template/outpost_hangar/ship_bay, style)
		TEST_ASSERT(bay_map && initial(bay_map.outpost_style) == style, "The ship bay has no [style] map")
	var/default_style = /datum/map_template/player_outpost::outpost_style
	var/datum/map_template/fallback = outpost_style_map(/datum/map_template/outpost_upgrade/shop, "no such style")
	TEST_ASSERT_EQUAL(initial(fallback.outpost_style), default_style, "An unknown style did not fall back to the default style's room")
	TEST_ASSERT_EQUAL(outpost_map_preview_name(/datum/map_template/outpost_upgrade/shop/clean), "outpost_upgrade_shop_clean", "A preview is not named after its map")

/// Every shell a founder can pick loads, links its machines and gives the same starting services.
/datum/unit_test/voidcrew_outpost_shell_contract

/datum/unit_test/voidcrew_outpost_shell_contract/Run()
	var/list/shells = outpost_selectable_shells()
	TEST_ASSERT(length(shells) >= 2, "Founders have fewer than two shells to pick from")
	var/list/seen_styles = list()
	for(var/datum/map_template/player_outpost/shell_type as anything in shells)
		var/label = initial(shell_type.name)
		var/style = initial(shell_type.outpost_style)
		TEST_ASSERT(style, "The [label] has no style")
		TEST_ASSERT(!(style in seen_styles), "Two shells share the [style] style")
		seen_styles += style
		var/obj/structure/overmap/dynamic/player_outpost/home = allocate(/obj/structure/overmap/dynamic/player_outpost)
		home.shell_template = allocate(shell_type)
		TEST_ASSERT(home.load_level(), "The [label] did not load")
		TEST_ASSERT_EQUAL(home.outpost_style, style, "The [label] did not give the outpost its style")
		TEST_ASSERT(home.home_bundle_installed, "The [label] lacks its cargo console, bank terminal or cryopod")
		TEST_ASSERT_NOTNULL(home.management_console, "The [label] has no management console")
		TEST_ASSERT_NOTNULL(home.construction_console, "The [label] has no construction console")
		TEST_ASSERT_NOTNULL(home.arrival_turf, "The [label] has no arrival point")
		TEST_ASSERT(!home.arrival_turf.is_blocked_turf(exclude_mobs = TRUE), "The [label]'s arrival point is blocked")
		TEST_ASSERT_EQUAL(length(home.lobby_alcove_turfs), 9, "The [label]'s elevator nook is not nine tiles")
		TEST_ASSERT_EQUAL(length(home.lobby_panels), 1, "The [label] has [length(home.lobby_panels)] elevator panels")
		TEST_ASSERT_NOTNULL(home.ship_bay_silo(), "The [label] has no single ore silo")
		// The shipyard console stands in the ship bay, never in the habitat
		TEST_ASSERT_NULL(locate(/obj/machinery/computer/ship_checkpoint) in home.outpost_area, "The [label] has a shipyard console")
		assert_outpost_cargo_bundle(home)
		TEST_ASSERT_NOTNULL(home.available_resident_pod(), "The [label] has no resident arrival point")
		TEST_ASSERT_EQUAL(home.treasury.account_balance, 0, "The [label] came with money")
		var/obj/machinery/power/apc/apc = home.outpost_area?.apc
		var/obj/machinery/power/smes/smes = locate() in home.outpost_area
		var/obj/machinery/power/port_gen/pacman/generator = locate() in home.outpost_area
		TEST_ASSERT_NOTNULL(apc, "The [label] has no APC")
		TEST_ASSERT(smes?.terminal, "The [label]'s SMES has no terminal")
		TEST_ASSERT_NOTNULL(generator, "The [label] has no generator")
		// It ships loose, like any portable generator: the owner bolts it down to run it
		generator.set_anchored(TRUE)
		TEST_ASSERT(generator.powernet && generator.powernet == smes.terminal.powernet, "The [label]'s generator does not feed the SMES once bolted down")
		TEST_ASSERT(apc.terminal?.powernet && apc.terminal.powernet == smes.powernet, "The [label]'s SMES does not feed the APC")
		// Every outer external airlock carries protected trunk cable on the SMES's net.
		var/list/outer_airlocks = outpost_outer_airlocks(home)
		TEST_ASSERT(length(outer_airlocks), "The [label] has no outer external airlock")
		for(var/list/candidate as anything in outer_airlocks)
			var/turf/door_turf = get_turf(candidate[1])
			var/obj/structure/cable/outpost/trunk = locate() in door_turf
			TEST_ASSERT_NOTNULL(trunk, "The [label] has no trunk cable under the outer airlock at [door_turf.x],[door_turf.y]")
			TEST_ASSERT_EQUAL(trunk.powernet, smes.powernet, "The [label]'s trunk cable at [door_turf.x],[door_turf.y] is not on the SMES's net")

/// Every upgrade room in every style works where it lands, in each of the four turns.
/datum/unit_test/voidcrew_outpost_room_styles
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_room_styles/Run()
	var/list/upgrade_ids = list()
	// A placed prison wing runs a prison; voidcrew_outpost_prison_styles places it in every style.
	for(var/upgrade_id in outpost_styled_upgrade_ids())
		if(!istype(GLOB.outpost_upgrade_catalog[upgrade_id], /datum/outpost_upgrade/prison))
			upgrade_ids += upgrade_id
	var/rooms = length(upgrade_ids)
	TEST_ASSERT(rooms, "The upgrade catalog is empty")
	var/static/list/rotations = list(0, 90, 180, 270)
	for(var/style in outpost_founder_styles())
		// One claim per room, each taking four rooms, one per side of the shell and so one per turn.
		// Across the claims every room lands once in every turn.
		for(var/claim in 1 to rooms)
			var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("roomstyles[claim]")
			TEST_ASSERT_NOTNULL(home, "The room style test claim did not load")
			home.outpost_style = style
			var/list/placed_turfs = list()
			for(var/side in 1 to length(rotations))
				var/upgrade_id = upgrade_ids[((claim + side - 2) % rooms) + 1]
				var/rotation = rotations[side]
				var/datum/outpost_upgrade/prototype = GLOB.outpost_upgrade_catalog[upgrade_id]
				var/result = place_test_service_room(home, prototype.type, list(rotation))
				if(!istype(result, /datum/outpost_upgrade))
					TEST_FAIL("The [style] [prototype.name] could not be placed turned [rotation]: [result]")
					continue
				var/datum/outpost_upgrade/room = result
				placed_turfs += block(room.footprint_bounds[1], room.footprint_bounds[2], room.footprint_bounds[5], room.footprint_bounds[3], room.footprint_bounds[4], room.footprint_bounds[5])
				for(var/problem in room.contract_problems())
					TEST_FAIL("The [style] [prototype.name], turned [rotation]: [problem]")
			settle_room_air(placed_turfs)

/// Every ship bay style loads into its reservation and links its dock, consoles, lift and signs.
/datum/unit_test/voidcrew_outpost_ship_bay_styles
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_outpost_ship_bay_styles/Run()
	var/list/bays = outpost_style_maps(/datum/map_template/outpost_hangar/ship_bay)
	TEST_ASSERT(length(bays) >= 2, "Fewer than two ship bay styles")
	for(var/datum/map_template/bay_type as anything in bays)
		var/style = initial(bay_type.outpost_style)
		var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("baystyle[style]")
		TEST_ASSERT_NOTNULL(home, "The [style] bay test claim did not load")
		home.outpost_style = style
		TEST_ASSERT_EQUAL(outpost_ship_bay_template(style)?.type, bay_type, "The [style] outpost would not build the [style] bay")
		TEST_ASSERT_NULL(home.enable_ship_bays(), "The [style] ship bay did not load")
		var/datum/outpost_berth/ship_bay/bay = LAZYACCESS(home.bay_berths, 1)
		TEST_ASSERT(bay?.dock, "The [style] ship bay has no dock")
		TEST_ASSERT_NOTNULL(bay.console, "The [style] ship bay has no construction console")
		TEST_ASSERT_NOTNULL(bay.panel, "The [style] ship bay has no elevator panel")
		TEST_ASSERT_EQUAL(length(bay.alcove_turfs), 9, "The [style] ship bay's elevator is not nine tiles")
		TEST_ASSERT(length(bay.status_signs), "The [style] ship bay has no berth signs")
		// Ship orders and checkpoints go through the bay's own shipyard console: the habitat has none.
		var/obj/machinery/computer/ship_checkpoint/shipyard = outpost_bay_shipyard_console(bay)
		TEST_ASSERT_NOTNULL(shipyard, "The [style] ship bay has no shipyard console")
		TEST_ASSERT_EQUAL(get_outpost_from_atom(shipyard), home, "The [style] ship bay's shipyard console does not serve its outpost")
		var/mob/living/carbon/human/clerk = make_player(get_turf(shipyard), "baystyleclerk[style]")
		var/datum/ship_checkpoint_ui/shipyard_panel = allocate(/datum/ship_checkpoint_ui, home, shipyard, clerk)
		TEST_ASSERT_EQUAL(shipyard_panel.ui_status(clerk, GLOB.always_state), UI_INTERACTIVE, "The [style] ship bay's shipyard console cannot be used")
		for(var/turf/tile as anything in bay.dock.return_turfs())
			for(var/obj/thing in tile)
				if(thing.density && thing.anchored)
					TEST_FAIL("The [style] ship bay has [thing] on its pad at [tile.x],[tile.y]")
