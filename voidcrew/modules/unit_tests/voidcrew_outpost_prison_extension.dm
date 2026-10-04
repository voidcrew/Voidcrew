/**
 * Cell block extensions (outpost_prison_extension.dm): three more cells snapped onto a side wall
 * of the prison wing, at most two, for up to ten prisoners.
 *
 * The test wing is placed unrotated (prison_test_claim()), so authored map coordinates apply, and
 * prison_spot() reaches past its walls. The right-hand extension's map lies with its seam column
 * (x = 1) on the wing's east wall (x = 17), so its tile (x, y) is the wing's (16 + x, y); a second
 * one chained onto it is the wing's (28 + x, y). The left-hand map is the right-hand one mirrored,
 * its seam column (x = 13) on the wing's west wall, so its tile (x, y) is the wing's (x - 12, y).
 * Each wall opens at rows 3 (office), 8 and 10 (yard).
 *
 * Voidcrew defines are not visible from test files, so tuning values appear as literals with the
 * define named beside them. Fixtures are in voidcrew_outpost_prison_helpers.dm.
 */

/// An extension whose load fails, for the wall that must stay shut. No id on the type, so the shop
/// never lists it. It is outside both extension families, so it never stands in for a real room.
/datum/map_template/outpost_upgrade/prison_extension/failing
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_prison_extension_right_rundown.dmm"

/datum/map_template/outpost_upgrade/prison_extension/failing/load_rotated(turf/bottom_left, rotation = 0)
	return null

/datum/outpost_upgrade/prison_extension/failing
	id = null
	template_type = /datum/map_template/outpost_upgrade/prison_extension/failing
	left_template_type = /datum/map_template/outpost_upgrade/prison_extension/failing

/datum/outpost_upgrade/prison_extension/failing/New(obj/structure/overmap/dynamic/player_outpost/owner)
	id = "prison_extension"
	return ..()

/datum/unit_test/voidcrew_outpost_prison_extension_kit
	parent_type = /datum/unit_test/voidcrew_outpost_prison_economy_kit
	abstract_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/**
 * Places a cell block extension on the wing's free joint on `side` (the one furthest out, chained
 * on an earlier extension if there is one), without the console: the unplaced blueprint if there is
 * one, else a new one of `upgrade_type`. Returns the placed upgrade, or why not.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_kit/proc/place_extension(obj/structure/overmap/dynamic/player_outpost/home, side, mob/user, upgrade_type = /datum/outpost_upgrade/prison_extension)
	var/datum/outpost_upgrade/prison_extension/blueprint = home.unplaced_upgrade("prison_extension")
	if(!blueprint)
		var/upgrade_key = home.free_upgrade_key("prison_extension", 2) // OUTPOST_PRISON_MAX_EXTENSIONS
		if(!upgrade_key)
			return "no key left for another extension"
		blueprint = new upgrade_type(home)
		blueprint.key = upgrade_key
		home.outpost_upgrades[upgrade_key] = blueprint
	var/list/offer = offer_on(blueprint.snap_offers(), side)
	if(!offer)
		return "no free [side] joint"
	var/turf/corner = offer["bottom_left"]
	var/error = home.place_outpost_upgrade(blueprint, corner, offer["rotation"], user)
	if(error)
		return "[error] [error == "Position obstructed." ? cargo_dock_blocker(home, blueprint, corner, offer["rotation"]) : ""]"
	return blueprint

/// Whether a tile of the joined wall is open floor in the wing, windows and grilles gone
/datum/unit_test/voidcrew_outpost_prison_extension_kit/proc/opened(datum/outpost_prison/prison, turf/tile)
	return isfloorturf(tile) && tile.loc == prison.wing && !(locate(/obj/structure/window) in tile) && !(locate(/obj/structure/grille) in tile)

/// Checks one joined wall, the column at wing x = `column`: rows 3, 8 and 10 open, the rest still wall, all of it the wing's
/datum/unit_test/voidcrew_outpost_prison_extension_kit/proc/check_seam(obj/structure/overmap/dynamic/player_outpost/home, datum/outpost_prison/prison, column, label)
	for(var/row in 1 to 16)
		var/turf/tile = prison_spot(home, column, row)
		TEST_ASSERT_EQUAL(tile.loc, prison.wing, "The [label] seam at row [row] is not in the wing's area")
		if(row in list(3, 8, 10))
			TEST_ASSERT(opened(prison, tile), "The [label] seam did not open at row [row]: [tile.type]")
		else
			TEST_ASSERT(isclosedturf(tile), "The [label] seam opened at row [row], which should stay wall")

/// Every tile of an upgrade's footprint
/datum/unit_test/voidcrew_outpost_prison_extension_kit/proc/footprint_tiles(datum/outpost_upgrade/upgrade)
	var/list/bounds = upgrade.footprint_bounds
	return block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5])

/// The things of `wanted_type` standing in an upgrade's footprint
/datum/unit_test/voidcrew_outpost_prison_extension_kit/proc/footprint_things(datum/outpost_upgrade/upgrade, wanted_type)
	var/list/found = list()
	for(var/turf/tile as anything in footprint_tiles(upgrade))
		for(var/atom/movable/thing as anything in tile)
			if(istype(thing, wanted_type))
				found += thing
	return found

/**
 * Two extensions chained on the right: the shop, cells 5 to 10 in order with buttons that bolt
 * their own doors, both joined walls opened exactly where declared, the temporary area gone, the
 * new yard in the cell block and the new office on the staff side, the new hatch a way out of the
 * cell block that the guards serve from the office, the riot strobe, the floor the mess is taken
 * over, the mail drop, the horror's ring, three arrival lanes, four guards and no loss of light.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_chain
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_chain/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extchainowner")
	TEST_ASSERT_NOTNULL(home, "The extension test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/outpost_upgrade/prison/wing_upgrade = home.outpost_upgrades["prison"]
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extchainowner")
	TEST_ASSERT_EQUAL(length(wing_upgrade.snap_points), 2, "The wing registered [length(wing_upgrade.snap_points)] joints, not one per side wall")
	TEST_ASSERT_EQUAL(prison.arrival_lanes(), 1, "A wing with no extension has [prison.arrival_lanes()] arrival lanes")
	TEST_ASSERT_EQUAL(prison.guards_payload(owner)["max"], 2, "A wing with no extension may hire [prison.guards_payload(owner)["max"]] guards") // OUTPOST_GUARD_MAX
	fix_wing(prison)
	var/lit_before = prison.lit_score
	var/floor_size_before = prison.mess_floor_size
	var/floor_count_before = length(prison.mess_floor)

	// The shop: 7,500 cr each (OUTPOST_PRISON_EXTENSION_COST), one blueprint waiting at a time.
	home.treasury.adjust_money(20000, "Extension test")
	TEST_ASSERT_NULL(home.buy_outpost_upgrade(owner, "prison_extension"), "The owner could not buy an extension")
	TEST_ASSERT_EQUAL(home.treasury.account_balance, 12500, "The extension did not cost 7,500 cr")
	var/datum/outpost_upgrade/prison_extension/first = home.outpost_upgrades["prison_extension"]
	TEST_ASSERT(istype(first), "The first extension is not under its plain id")
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "prison_extension"), "Blueprint already bought.", "A second extension was bought while the first waited")
	var/list/offers = first.snap_offers()
	TEST_ASSERT_EQUAL(length(offers), 2, "The wing offers [length(offers)] joints, not one per side wall")
	var/list/right_offer = offer_on(offers, "right")
	TEST_ASSERT_EQUAL(right_offer?["bottom_left"], prison_spot(home, 17, 1), "The right-hand joint does not put the extension on the east wall")
	TEST_ASSERT_EQUAL(offer_on(offers, "left")?["bottom_left"], prison_spot(home, -11, 1), "The left-hand joint does not put the extension on the west wall")

	// The first extension, on the east wall.
	var/placed = place_extension(home, "right", owner)
	TEST_ASSERT_EQUAL(placed, first, "The first extension was not placed: [placed]")
	TEST_ASSERT(first.joined, "The first extension did not join the wing")
	TEST_ASSERT_EQUAL(first.installed_area, prison.wing, "The extension's tiles are not the wing's")
	for(var/turf/tile as anything in footprint_tiles(first))
		TEST_ASSERT(!istype(tile.loc, /area/voidcrew/player_outpost/prison_extension), "An extension tile kept its temporary area at [tile.x],[tile.y]")
	TEST_ASSERT_EQUAL(length(prison.cells), 7, "The wing has [length(prison.cells)] cells with one extension, not 7")
	TEST_ASSERT_EQUAL(prison.capacity, 7, "The wing holds [prison.capacity] with one extension, not 7")
	check_seam(home, prison, 17, "first")
	TEST_ASSERT_EQUAL(prison.arrival_lanes(), 2, "A wing with one extension has [prison.arrival_lanes()] arrival lanes")
	TEST_ASSERT_EQUAL(prison.guards_payload(owner)["max"], 3, "A wing with one extension may hire [prison.guards_payload(owner)["max"]] guards")

	// Lit and Powered hold: every working light in the extension is on at once, off the wing's APC.
	TEST_ASSERT(prison.is_powered() && prison.powered_score == 100, "The wing lost power when the extension joined")
	for(var/obj/machinery/light/fixture as anything in footprint_things(first, /obj/machinery/light))
		if(fixture.status == LIGHT_OK)
			TEST_ASSERT(fixture.on, "An extension light at [fixture.x],[fixture.y] is off after joining")
	TEST_ASSERT(length(footprint_things(first, /obj/machinery/light)), "The extension has no lights")

	// The new yard is in the cell block, walkable from the old one; the new office is staff side.
	var/turf/new_yard = prison_spot(home, 18, 8)
	var/turf/new_office = prison_spot(home, 18, 3)
	TEST_ASSERT(prison.cell_block[new_yard], "The extension's yard is not in the cell block")
	TEST_ASSERT(!prison.cell_block[new_office] && prison.staff_ground[new_office], "The extension's office is not on the staff side")
	TEST_ASSERT(prison.staff_ground[prison_spot(home, 17, 3)], "The office opening is not on the staff side")
	var/mob/living/basic/outpost_prisoner/walker = test_prisoner(prison, prison_spot(home, 12, 8))
	prison.refresh_prisoner_reach(walker)
	TEST_ASSERT(walker.walkable[new_yard], "A prisoner in the wing's yard cannot walk into the extension's yard")
	TEST_ASSERT(!walker.walkable[new_office], "A prisoner in the wing's yard can walk into the extension's office")
	walker.forceMove(new_yard)
	TEST_ASSERT(prison.in_cell_block(walker), "A prisoner in the extension's yard counts as out of the cell block")

	// Cells 5-7 in order, each button bolting its own door and no other.
	var/list/buttons = footprint_things(first, /obj/machinery/button/outpost_prison_bolt)
	TEST_ASSERT_EQUAL(length(buttons), 3, "The extension has [length(buttons)] bolt buttons, not 3")
	for(var/number in 5 to 7)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT_EQUAL(cell.number, number, "The wing's cells are not in number order")
		TEST_ASSERT(first.contains_turf(cell.door_turf), "Cell [number] is not in the extension")
		var/obj/machinery/door/airlock/door = cell.door()
		TEST_ASSERT_EQUAL(door.name, "Cell [number]", "Cell [number]'s door is called [door.name]")
		TEST_ASSERT_NOTNULL(cell.bed(), "Cell [number] has no bed")
	for(var/obj/machinery/button/outpost_prison_bolt/button as anything in buttons)
		var/datum/outpost_prison_cell/own = prison.cell_by_number(button.cell_number)
		TEST_ASSERT_NOTNULL(own, "A bolt button is for cell [button.cell_number], which is not one of the wing's")
		TEST_ASSERT(button.cell_number >= 5 && button.cell_number <= 7, "An extension button bolts cell [button.cell_number]")
		TEST_ASSERT(button.attempt_press(owner), "Cell [button.cell_number]'s bolt button could not be pressed")
		TEST_ASSERT(own.is_bolted(), "Cell [button.cell_number]'s bolt button did not bolt it")
		for(var/datum/outpost_prison_cell/other as anything in prison.cells)
			if(other != own)
				TEST_ASSERT(!other.is_bolted(), "Cell [button.cell_number]'s bolt button bolted cell [other.number]")
		TEST_ASSERT(button.attempt_press(owner), "Cell [button.cell_number]'s bolt button could not be pressed again")
		TEST_ASSERT(!own.is_bolted(), "Cell [button.cell_number]'s bolt button did not unbolt it")

	// The new hatch: one of the wing's, a way out of the cell block, with its office side staff ground.
	var/list/new_hatches = footprint_things(first, /obj/structure/table/reinforced/prison_hatch)
	TEST_ASSERT_EQUAL(length(new_hatches), 1, "The extension has [length(new_hatches)] serving hatches, not 1")
	var/obj/structure/table/reinforced/prison_hatch/hatch = new_hatches[1]
	TEST_ASSERT(hatch in prison.hatches(), "The extension's hatch is not one of the wing's")
	TEST_ASSERT(prison.is_exit_tile(get_turf(hatch)), "The extension's hatch is not a way out of the cell block")
	TEST_ASSERT(prison.staff_ground[hatch.staff_side_turf()], "Guards cannot reach the extension's hatch from the office")

	// The floor the mess is taken over grows by exactly the new floor.
	TEST_ASSERT_EQUAL(prison.mess_floor_size - floor_size_before, length(prison.mess_floor) - floor_count_before, "The floor size grew by [prison.mess_floor_size - floor_size_before], the floor by [length(prison.mess_floor) - floor_count_before]")
	TEST_ASSERT(prison.mess_floor_size > floor_size_before, "The floor size did not grow")

	// The riot strobe turns the extension red too.
	prison.set_riot_lights(TRUE)
	var/red = FALSE
	for(var/obj/machinery/light/fixture as anything in footprint_things(first, /obj/machinery/light))
		if(fixture.major_emergency)
			red = TRUE
	prison.set_riot_lights(FALSE)
	TEST_ASSERT(red, "The riot strobe left the extension's lights alone")

	// Mail still comes to the wing's own entrance, south of its door at (9,1); the horror still
	// leaves the outer windows alone, the extension's included, but not the joined wall.
	TEST_ASSERT_EQUAL(prison.mail_entrance_front(), prison_spot(home, 9, 0), "Mail no longer comes to the wing's entrance")
	TEST_ASSERT(prison.on_outer_ring(prison_spot(home, 29, 8)), "The extension's outer window is not on the wing's outer ring")
	TEST_ASSERT(!prison.on_outer_ring(prison_spot(home, 17, 5)), "The joined wall still counts as the wing's outer ring")

	// The second, chained onto the first's far wall.
	TEST_ASSERT_NULL(home.buy_outpost_upgrade(owner, "prison_extension"), "The owner could not buy a second extension")
	var/datum/outpost_upgrade/prison_extension/second = home.outpost_upgrades["prison_extension_2"]
	TEST_ASSERT(istype(second), "The second extension is not under its own key")
	offers = second.snap_offers()
	TEST_ASSERT_EQUAL(length(offers), 2, "After one extension the wing offers [length(offers)] joints, not the west wall and the chain")
	TEST_ASSERT_EQUAL(offer_on(offers, "right")?["bottom_left"], prison_spot(home, 29, 1), "The chained joint is not on the first extension's far wall")
	placed = place_extension(home, "right", owner)
	TEST_ASSERT_EQUAL(placed, second, "The chained extension was not placed: [placed]")
	check_seam(home, prison, 29, "chained")
	TEST_ASSERT_EQUAL(length(prison.cells), 10, "The wing has [length(prison.cells)] cells with two extensions, not 10")
	TEST_ASSERT_EQUAL(prison.capacity, 10, "The wing holds [prison.capacity] with two extensions") // OUTPOST_PRISON_MAX_CAPACITY
	for(var/number in 1 to 10)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT_EQUAL(cell.number, number, "Cell [number] is numbered [cell.number]")
	for(var/obj/machinery/button/outpost_prison_bolt/button as anything in footprint_things(second, /obj/machinery/button/outpost_prison_bolt))
		TEST_ASSERT(button.cell_number >= 8 && button.cell_number <= 10, "A chained extension's button bolts cell [button.cell_number]")
		TEST_ASSERT(second.contains_turf(prison.cell_by_number(button.cell_number)?.door_turf), "Cell [button.cell_number]'s button is not in the extension its cell is in")
	TEST_ASSERT(prison.cell_block[prison_spot(home, 30, 8)], "The chained extension's yard is not in the cell block")
	TEST_ASSERT(prison.on_outer_ring(prison_spot(home, 41, 8)), "The chained extension's outer window is not on the outer ring")
	TEST_ASSERT(!prison.on_outer_ring(prison_spot(home, 29, 8)), "The first extension's far wall is still on the outer ring")
	TEST_ASSERT_EQUAL(prison.guards_payload(owner)["max"], 4, "A wing with two extensions may hire [prison.guards_payload(owner)["max"]] guards")

	// Two is the most, and each area counts once toward the outpost's ground.
	TEST_ASSERT_EQUAL(home.buy_outpost_upgrade(owner, "prison_extension"), "All 2 built.", "A third extension could be bought")
	var/list/owned = home.outpost_owned_turfs()
	var/list/unique = list()
	for(var/turf/tile as anything in owned)
		unique[tile] = TRUE
	TEST_ASSERT_EQUAL(length(owned), length(unique), "The outpost counts the wing's tiles more than once")

	// The warden's console shows ten cells.
	TEST_ASSERT_EQUAL(prison.ui_payload(owner)["capacity"], 10, "The warden console does not show ten cells")

	// Light: with every bulb working the wing is as lit as before.
	fix_wing(prison)
	TEST_ASSERT(prison.lit_score >= lit_before, "The wing is lit [prison.lit_score] with two extensions, [lit_before] before")

	// Three arrival lanes: three prisoners at once, then each lane waits its own gap. With the crew
	// home; voidcrew_outpost_prison_extension_lanes tests them away.
	prison.crew_home_override = TRUE
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(!cell.occupant)
			cell.ready_at = world.time
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")
	TEST_ASSERT_EQUAL(prison.arrival_lanes(), 3, "A ten-cell wing has [prison.arrival_lanes()] arrival lanes")
	prison.arrival_gap = 0
	prison.lane_gaps = list(0, 0)
	var/before = length(prison.prisoners)
	prison.intake_tick(0)
	TEST_ASSERT_EQUAL(length(prison.prisoners) - before, 3, "Three lanes brought [length(prison.prisoners) - before] prisoners at once")
	var/soonest = INFINITY
	for(var/lane in 1 to 3)
		var/gap = prison.lane_gap(lane)
		TEST_ASSERT(gap >= 30 && gap <= 180, "Lane [lane] waits [gap] s after its arrival, not 30-180") // OUTPOST_PRISON_ARRIVAL_GAP_MIN, _MAX
		soonest = min(soonest, gap)
	prison.intake_tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners) - before, 3, "A lane brought another prisoner before its gap was up")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, soonest - 1, "The console does not count down to the soonest lane")
	prison.set_intake(FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	settle_prison_air(home)

/**
 * The extensions' arrival lanes need staff to process the extra intake, so a wing left alone earns
 * next to nothing however big it is. With nobody home for longer than the grace
 * (OUTPOST_PRISON_EXTENSION_STAFFED_GRACE) only the wing's own lane brings prisoners, while the
 * others' gaps keep counting down; back home, each ready lane brings one at once, and no more than
 * one however long the crew was away. The console counts down to the lanes that are open.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_lanes
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_lanes/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extlanesowner")
	TEST_ASSERT_NOTNULL(home, "The extension lanes test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extlanesowner")
	for(var/i in 1 to 2)
		var/placed = place_extension(home, "right", owner)
		TEST_ASSERT(istype(placed, /datum/outpost_upgrade/prison_extension), "Extension [i] was not placed: [placed]")
	TEST_ASSERT_EQUAL(length(prison.cells), 10, "The lanes test wing has [length(prison.cells)] cells, not 10")
	TEST_ASSERT_EQUAL(prison.arrival_lanes(), 3, "A ten-cell wing has [prison.arrival_lanes()] arrival lanes")
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		cell.ready_at = world.time
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")

	// Nobody home, and nobody for a long while: every lane is due, and only the wing's own brings anyone.
	prison.crew_home_override = FALSE
	prison.last_crew_home_at = null
	prison.arrival_gap = 0
	prison.lane_gaps = list(0, 0)
	prison.intake_tick(0)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 1, "With nobody home [length(prison.prisoners)] prisoners arrived at once, not the wing's lane's one")
	TEST_ASSERT(prison.arrival_gap >= 30, "The wing's lane did not start its gap")
	TEST_ASSERT(prison.lane_gap(2) == 0 && prison.lane_gap(3) == 0, "An extension's lane used its turn with nobody home")
	// Its gap up again, the wing's lane brings the next; the extensions' lanes still wait.
	prison.intake_tick(prison.arrival_gap)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "The wing's lane did not bring its next prisoner with nobody home")
	TEST_ASSERT_EQUAL(prison.arrival_countdown, prison.arrival_gap, "With nobody home the console counts down to a closed lane")
	// The extensions' gaps count down while nobody is home.
	prison.lane_gaps = list(50, 120)
	prison.intake_tick(20)
	TEST_ASSERT(prison.lane_gap(2) == 30 && prison.lane_gap(3) == 100, "The extensions' lanes stopped counting down with nobody home ([prison.lane_gap(2)], [prison.lane_gap(3)])")
	// A long time away brings nobody through them, and back home each brings one, not a crowd.
	prison.arrival_gap = 3600
	prison.intake_tick(30 * 60)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 2, "The extensions' lanes brought prisoners over half an hour with nobody home")
	prison.crew_home_override = TRUE
	prison.intake_tick(0)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "Back home, the two ready extension lanes brought [length(prison.prisoners) - 2] prisoners, not one each")
	TEST_ASSERT(prison.lane_gap(2) >= 30 && prison.lane_gap(3) >= 30, "The extensions' lanes did not start their gaps")
	prison.intake_tick(1)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "A lane brought a second prisoner before its gap was up")
	prison.set_intake(FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	settle_prison_air(home)

/**
 * The extension cells need staff around too. With nobody from the wing home for longer than
 * OUTPOST_PRISON_EXTENSION_STAFFED_GRACE they take no new prisoners, though the wing's own cells
 * still do, and the warden's log says so; within the grace, or with someone home, they take them.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_staffing
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_staffing/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extstaffowner")
	TEST_ASSERT_NOTNULL(home, "The extension staffing test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extstaffowner")
	var/datum/outpost_upgrade/prison_extension/extension = place_extension(home, "right", owner)
	TEST_ASSERT(istype(extension), "The extension was not placed: [extension]")
	var/grace = 15 MINUTES // OUTPOST_PRISON_EXTENSION_STAFFED_GRACE
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		cell.ready_at = world.time
		TEST_ASSERT_EQUAL(cell.in_extension(), cell.number > 4, "Cell [cell.number] is [cell.in_extension() ? "" : "not "]taken for an extension cell")
	TEST_ASSERT(prison.set_intake(TRUE), "Intake would not open")

	// Nobody home for longer than the grace: the wing's own four cells fill, one at a time...
	prison.crew_home_override = FALSE
	prison.last_crew_home_at = world.time - grace - 10 SECONDS
	TEST_ASSERT(!prison.extension_staffed(), "The extensions counted as staffed past the grace")
	for(var/i in 1 to 6)
		prison.arrival_gap = 0
		prison.lane_gaps = list(0)
		prison.intake_tick(0)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 4, "With nobody home past the grace [length(prison.prisoners)] prisoners arrived, not the wing's four")
	for(var/datum/outpost_prison_cell/cell as anything in prison.cells)
		if(cell.number <= 4)
			TEST_ASSERT_NOTNULL(cell.occupant, "The wing's cell [cell.number] took nobody with the crew away")
		else
			TEST_ASSERT_NULL(cell.occupant, "Extension cell [cell.number] took a prisoner with nobody home past the grace")
	// ...no arrival is due with only extension cells free, and the log says why.
	TEST_ASSERT_NULL(prison.arrival_countdown, "The console shows an arrival due with only the unstaffed extension cells free")
	var/logged = FALSE
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "Extension cells closed to transfers: no staff on hand."))
			logged = TRUE
	TEST_ASSERT(logged, "The warden's log does not say the extension cells wait for staff")

	// Home within the grace: the extension cells take prisoners again, through both lanes.
	prison.last_crew_home_at = world.time - grace + 1 MINUTES
	TEST_ASSERT(prison.extension_staffed(), "The extensions did not count as staffed within the grace")
	prison.arrival_gap = 0
	prison.lane_gaps = list(0)
	prison.intake_tick(0)
	TEST_ASSERT_EQUAL(length(prison.prisoners), 6, "Within the grace the extension cells took [length(prison.prisoners) - 4] prisoners, not one per lane")
	logged = FALSE
	for(var/list/entry as anything in prison.entries)
		if(findtext(entry["text"], "Extension cells open to transfers again."))
			logged = TRUE
	TEST_ASSERT(logged, "The warden's log does not say the extension cells take prisoners again")
	// With someone home the grace starts again from now.
	prison.last_crew_home_at = null
	prison.crew_home_override = TRUE
	TEST_ASSERT(prison.extension_staffed(), "The extensions did not count as staffed with the crew home")
	TEST_ASSERT_EQUAL(prison.last_crew_home_at, world.time, "The crew being home was not noted")
	prison.set_intake(FALSE)
	TEST_ASSERT(wait_until(CALLBACK(src, TYPE_PROC_REF(/datum/unit_test/voidcrew_outpost_prison_economy_kit, all_present), prison), 8 SECONDS), "The arrivals never finished beaming in")
	for(var/mob/living/basic/outpost_prisoner/arrival as anything in prison.prisoners)
		ADD_TRAIT(arrival, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	settle_prison_air(home)

/**
 * Mess counts where the prisoners live: an extension's floor counts toward the mess density only as
 * far as its cells are occupied, so a wing cannot keep its Clean score up with empty extensions.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_mess_floor
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_mess_floor/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extmessowner")
	TEST_ASSERT_NOTNULL(home, "The extension mess test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/datum/outpost_upgrade/prison/wing_upgrade = home.outpost_upgrades["prison"]
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extmessowner")
	var/wing_floor = prison.mess_floor_size
	TEST_ASSERT_EQUAL(prison.mess_floor_size_now(), wing_floor, "A wing with no extension spreads its mess over [prison.mess_floor_size_now()] tiles, not its [wing_floor]")
	var/datum/outpost_upgrade/prison_extension/extension = place_extension(home, "right", owner)
	TEST_ASSERT(istype(extension), "The extension was not placed: [extension]")
	TEST_ASSERT_EQUAL(length(wing_upgrade.extension_floor_sizes), 1, "The extension's floor was not recorded")
	var/extension_floor = wing_upgrade.extension_floor_sizes[1]
	TEST_ASSERT_EQUAL(prison.mess_floor_size, wing_floor + extension_floor, "The floor size did not grow by the extension's floor")
	TEST_ASSERT(extension_floor > 0, "The extension added no floor")

	// Empty, the extension's floor counts for nothing; one cell of three taken, a third of it.
	TEST_ASSERT(abs(prison.mess_floor_size_now() - wing_floor) < 0.01, "With the extension empty the mess is spread over [prison.mess_floor_size_now()] tiles, not the wing's [wing_floor]")
	var/datum/outpost_prison_cell/fifth = prison.cells[5]
	var/mob/living/basic/outpost_prisoner/lodger = new(fifth.arrival_turf())
	prison.admit(lodger, fifth)
	ADD_TRAIT(lodger, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	var/expected = wing_floor + extension_floor / 3
	TEST_ASSERT(abs(prison.mess_floor_size_now() - expected) < 0.01, "With one extension cell of three taken the mess is spread over [prison.mess_floor_size_now()] tiles, not [expected]")

	// The Clean score uses that floor: the same mess reads dirtier than over the whole floor would.
	var/list/mess = list()
	for(var/x in 3 to 14)
		mess += allocate(/obj/effect/decal/cleanable/vomit, prison_spot(home, x, 8))
	prison.refresh_conditions()
	TEST_ASSERT(prison.mess_load > 0, "The test mess weighed nothing")
	TEST_ASSERT_EQUAL(prison.clean_score, conditions_expected_clean(prison.mess_load, expected), "Clean is [prison.clean_score] for [prison.mess_load] mess over [expected] tiles")
	TEST_ASSERT(prison.clean_score < conditions_expected_clean(prison.mess_load, prison.mess_floor_size), "The half-empty extension still thinned out the mess")
	for(var/obj/effect/decal/cleanable/vomit/spill as anything in mess)
		qdel(spill)
	settle_prison_air(home)

/**
 * One on each side: the left-hand extension first takes cells 5-7 on the west wall, the right-hand
 * one 8-10 on the east, and the left-hand one's own far wall is offered next.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_sides
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_sides/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extsidesowner")
	TEST_ASSERT_NOTNULL(home, "The extension test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extsidesowner")

	var/datum/outpost_upgrade/prison_extension/left = place_extension(home, "left", owner)
	TEST_ASSERT(istype(left), "The left-hand extension was not placed: [left]")
	TEST_ASSERT_EQUAL(left.snap_side, "left", "The west wall's extension does not know its side")
	TEST_ASSERT_EQUAL(left.footprint_bounds[1], prison_spot(home, -11, 1).x, "The left-hand extension is not west of the wing")
	check_seam(home, prison, 1, "west")
	for(var/number in 5 to 7)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT(left.contains_turf(cell.door_turf), "Cell [number] is not in the left-hand extension")
	TEST_ASSERT(prison.cell_block[prison_spot(home, 0, 8)], "The left-hand extension's yard is not in the cell block")
	TEST_ASSERT(prison.staff_ground[prison_spot(home, 0, 3)], "The left-hand extension's office is not on the staff side")
	TEST_ASSERT(prison.on_outer_ring(prison_spot(home, -11, 8)), "The left-hand extension's outer window is not on the outer ring")

	var/datum/outpost_upgrade/prison_extension/probe = new(home)
	var/list/offers = probe.snap_offers(home)
	qdel(probe)
	TEST_ASSERT_EQUAL(offer_on(offers, "left")?["bottom_left"], prison_spot(home, -23, 1), "The left-hand extension's far wall is not offered")
	TEST_ASSERT_EQUAL(offer_on(offers, "right")?["bottom_left"], prison_spot(home, 17, 1), "The east wall is not offered after the west one")

	var/datum/outpost_upgrade/prison_extension/right = place_extension(home, "right", owner)
	TEST_ASSERT(istype(right), "The right-hand extension was not placed: [right]")
	check_seam(home, prison, 17, "east")
	TEST_ASSERT_EQUAL(length(prison.cells), 10, "The wing has [length(prison.cells)] cells, not 10")
	for(var/number in 8 to 10)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT(right.contains_turf(cell.door_turf), "Cell [number] is not in the right-hand extension")
	TEST_ASSERT_EQUAL(prison.capacity, 10, "The wing holds [prison.capacity], not 10")
	settle_prison_air(home)

/**
 * No extension without a running prison; none placed during a riot or breakout, while prisoners
 * are loose, or through a broken wall; and a load that fails leaves the wall shut and the joint free.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_refusals
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_refusals/Run()
	// No prison wing, no extension.
	var/obj/structure/overmap/dynamic/player_outpost/bare = upgrade_test_claim("extbareowner")
	TEST_ASSERT_NOTNULL(bare, "The bare test outpost did not load")
	var/mob/living/carbon/human/bare_owner = make_player(get_turf(bare.management_console), "extbareowner")
	bare.ensure_home_services()
	bare.treasury.adjust_money(10000, "Extension test")
	TEST_ASSERT_EQUAL(bare.upgrade_purchase_denial(bare_owner, "prison_extension"), "Needs a prison wing.", "An extension was offered with no prison wing")

	var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("extrefuseowner")
	TEST_ASSERT_NOTNULL(home, "The extension test prison did not load")
	var/datum/outpost_prison/prison = test_prison(home)
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extrefuseowner")
	var/datum/outpost_upgrade/prison_extension/blueprint = new(home)
	home.outpost_upgrades["prison_extension"] = blueprint
	var/list/offer = offer_on(blueprint.snap_offers(), "right")
	TEST_ASSERT_NOTNULL(offer, "The wing offers no right-hand joint")
	var/turf/corner = offer["bottom_left"]

	// Not in the middle of trouble.
	prison.riot_active = TRUE
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, corner, 0, owner), "Not during a riot.", "An extension was placed during a riot")
	prison.riot_active = FALSE
	prison.breaking_out = TRUE
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, corner, 0, owner), "Not during a riot.", "An extension was placed during a breakout")
	prison.breaking_out = FALSE
	var/mob/living/basic/outpost_prisoner/runner = test_prisoner(prison, prison_spot(home, 12, 8))
	runner.trouble = "loose" // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, corner, 0, owner), "Not while prisoners are loose.", "An extension was placed with a prisoner loose")
	runner.trouble = null
	TEST_ASSERT(!blueprint.placing && !blueprint.installed && !blueprint.footprint_bounds, "A refused extension claimed its blueprint")

	// Not through a broken wall: a hole where the wall stays would let the cell block into the new office.
	var/turf/wall_spot = prison_spot(home, 17, 5)
	wall_spot.ChangeTurf(/turf/open/floor/plating)
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(blueprint, corner, 0, owner), "Prison wing wall blocked.", "An extension joined a broken wall")
	wall_spot.ChangeTurf(/turf/closed/wall)
	TEST_ASSERT_NULL(home.snap_seam_denial(blueprint, offer), "A repaired wall still refused the extension")
	qdel(blueprint)

	// A load that fails builds nothing and opens nothing.
	var/datum/outpost_upgrade/prison_extension/failing/doomed = new(home)
	home.outpost_upgrades["prison_extension"] = doomed
	TEST_ASSERT_EQUAL(home.place_outpost_upgrade(doomed, corner, 0, owner), "The upgrade could not be built.", "A failed load reported success")
	TEST_ASSERT(!doomed.installed && !doomed.placing && !doomed.footprint_bounds, "A failed load did not put the blueprint back on the shelf")
	TEST_ASSERT(isclosedturf(prison_spot(home, 17, 3)), "A failed load opened the office wall")
	TEST_ASSERT(locate(/obj/structure/window) in prison_spot(home, 17, 8), "A failed load took a yard window out")
	TEST_ASSERT(locate(/obj/structure/window) in prison_spot(home, 17, 10), "A failed load took a yard window out")
	TEST_ASSERT_EQUAL(length(prison.cells), 4, "A failed load changed the cells")
	TEST_ASSERT_NOTNULL(offer_on(doomed.snap_offers(), "right"), "A failed load used up the joint")
	qdel(doomed)
	settle_prison_air(home)

/**
 * A wing turned a quarter: its east wall is its bottom edge, so a right-hand extension goes south
 * of it, turned with it, and still opens the office and yard rows and brings cells 5-7.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_turned
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_extension_turned/Run()
	var/obj/structure/overmap/dynamic/player_outpost/home = upgrade_test_claim("extturnedowner")
	TEST_ASSERT_NOTNULL(home, "The turned extension test outpost did not load")
	var/datum/outpost_upgrade/prison/wing_upgrade = new(home)
	home.outpost_upgrades["prison"] = wing_upgrade
	// East of the shell, turned a quarter, as the map test puts its wing; the extension goes below it.
	var/turf/wing_corner = locate(home.template_bottom_left.x + home.shell_template.width + 3, home.template_bottom_left.y + 14, home.upgrade_level_z())
	var/error = home.place_outpost_upgrade(wing_upgrade, wing_corner, 90, null)
	TEST_ASSERT_NULL(error, "The prison wing was not placed turned: [error] [cargo_dock_blocker(home, wing_upgrade, wing_corner, 90)]")
	var/datum/outpost_prison/prison = wing_upgrade.prison
	STOP_PROCESSING(SSprocessing, prison)
	prison.trouble_enabled = FALSE
	var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "extturnedowner")

	var/datum/outpost_upgrade/prison_extension/extension = place_extension(home, "right", owner)
	TEST_ASSERT(istype(extension), "The extension was not placed on the turned wing: [extension]")
	TEST_ASSERT_EQUAL(extension.rotation, 90, "The extension was not turned with the wing")
	var/list/bounds = extension.footprint_bounds
	TEST_ASSERT_EQUAL(bounds[4], wing_corner.y, "The extension's top row is not the turned wing's bottom row")
	TEST_ASSERT_EQUAL(bounds[2], wing_corner.y - 12, "The extension is not 13 tiles tall below the turned wing")
	// The wing's authored (17, row) lies on its bottom row at x + row - 1.
	for(var/row in list(3, 8, 10))
		var/turf/opening = locate(wing_corner.x + row - 1, wing_corner.y, wing_corner.z)
		TEST_ASSERT(opened(prison, opening), "The turned wing's wall did not open at row [row]")
	TEST_ASSERT(isclosedturf(locate(wing_corner.x + 4, wing_corner.y, wing_corner.z)), "The turned wing's wall opened at row 5")
	TEST_ASSERT_EQUAL(length(prison.cells), 7, "The turned wing has [length(prison.cells)] cells with an extension")
	for(var/number in 5 to 7)
		var/datum/outpost_prison_cell/cell = prison.cells[number]
		TEST_ASSERT(extension.contains_turf(cell.door_turf), "Cell [number] is not in the turned extension")
	TEST_ASSERT(prison.cell_block[locate(wing_corner.x + 7, wing_corner.y - 1, wing_corner.z)], "The turned extension's yard is not in the cell block")
	TEST_ASSERT(prison.staff_ground[locate(wing_corner.x + 2, wing_corner.y - 1, wing_corner.z)], "The turned extension's office is not on the staff side")
	settle_prison_air(home)

/**
 * The prison wing and both extension rooms come in every style a founder can pick (outpost_styles.dm),
 * and every style's wing works the same: an outpost builds its own style's rooms, four cells, a clean
 * and fully lit cell block with no mess drawn on it, and extensions on both walls that open their
 * seams and bring the wing to ten cells. The other prison tests run on the test claim's own style.
 */
/datum/unit_test/voidcrew_outpost_prison_styles
	parent_type = /datum/unit_test/voidcrew_outpost_prison_extension_kit

/datum/unit_test/voidcrew_outpost_prison_styles/Run()
	var/list/styles = outpost_founder_styles()
	TEST_ASSERT(length(styles) >= 2, "Founders have fewer than two styles to pick from")
	var/list/families = list(
		/datum/map_template/outpost_upgrade/prison,
		/datum/map_template/outpost_upgrade/prison_extension/right,
		/datum/map_template/outpost_upgrade/prison_extension/left,
	)
	for(var/style in styles)
		for(var/family in families)
			var/datum/map_template/map_type = outpost_style_map(family, style)
			TEST_ASSERT(map_type && initial(map_type.outpost_style) == style, "[family] has no [style] map")
		var/obj/structure/overmap/dynamic/player_outpost/home = prison_test_claim("prisonstyle[style]", style)
		TEST_ASSERT_NOTNULL(home, "The [style] test prison did not load")
		var/datum/outpost_upgrade/prison/wing_upgrade = home.outpost_upgrades["prison"]
		TEST_ASSERT_EQUAL(wing_upgrade.get_template()?.type, outpost_style_map(/datum/map_template/outpost_upgrade/prison, style), "The [style] outpost did not build the [style] wing")
		var/datum/outpost_prison/prison = test_prison(home)
		TEST_ASSERT_EQUAL(length(prison.cells), 4, "The [style] wing has [length(prison.cells)] cells")

		// Grime is drawn on the prisoners' side, never left there as mess the score would count.
		for(var/obj/machinery/light/fixture as anything in all_lights(prison))
			if(fixture.status != LIGHT_OK)
				fixture.fix()
		TEST_ASSERT(conditions_draw_lights(prison), "The [style] wing's lights were never drawn")
		prison.refresh_conditions()
		TEST_ASSERT_EQUAL(prison.mess_load, 0, "A fresh [style] wing has [prison.mess_load] mess on its cell block")
		TEST_ASSERT_EQUAL(prison.clean_score, 100, "A fresh [style] wing is [prison.clean_score] clean")
		TEST_ASSERT_EQUAL(prison.lit_score, 100, "A fresh [style] wing is [prison.lit_score] lit")

		var/mob/living/carbon/human/owner = make_player(get_turf(home.management_console), "prisonstyle[style]")
		for(var/side in list("left", "right"))
			var/datum/outpost_upgrade/prison_extension/extension = place_extension(home, side, owner)
			TEST_ASSERT(istype(extension), "The [style] [side]-hand extension was not placed: [extension]")
			var/room_family = (side == "left") ? /datum/map_template/outpost_upgrade/prison_extension/left : /datum/map_template/outpost_upgrade/prison_extension/right
			TEST_ASSERT_EQUAL(extension.get_template(side)?.type, outpost_style_map(room_family, style), "The [style] outpost did not build the [style] [side]-hand extension")
		check_seam(home, prison, 1, "[style] west")
		check_seam(home, prison, 17, "[style] east")
		TEST_ASSERT_EQUAL(length(prison.cells), 10, "The [style] wing has [length(prison.cells)] cells with two extensions")
		TEST_ASSERT_EQUAL(prison.capacity, 10, "The [style] wing holds [prison.capacity] with two extensions")
		prison.refresh_conditions()
		TEST_ASSERT_EQUAL(prison.mess_load, 0, "The [style] extensions brought [prison.mess_load] mess onto the cell block")
		for(var/problem in wing_upgrade.power_problems())
			TEST_FAIL("The [style] wing: [problem]")
		settle_prison_air(home)
