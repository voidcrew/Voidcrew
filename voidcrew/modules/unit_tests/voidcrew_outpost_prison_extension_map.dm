/**
 * The cell block extension's two rooms (voidcrew/modules/player_outposts/outpost_prison_extension.dm),
 * in every style, loaded raw beside a raw prison wing of the same style the way they join it, before
 * any code opens a seam: a right-hand extension on the wing's east wall, a second one chained onto its
 * far wall, and a left-hand one on the wing's west wall.
 *
 * Voidcrew defines are not visible from test files, so values appear as literals.
 */

/// The rows of a joint wall that open once an extension joins, counted from the joint's own row as 1:
/// outpost_upgrade_snap's seam_openings, the office row and the two yard windows
/proc/vc_test_prison_joint_openings()
	return list(3, 8, 10)

/// Whether a prisoner could stand on `tile`: open ground with nothing dense and no door on it
/proc/vc_test_prison_standable(turf/tile)
	if(!tile || isclosedturf(tile))
		return FALSE
	for(var/obj/thing in tile)
		if(thing.density || istype(thing, /obj/machinery/door))
			return FALSE
	return TRUE

/// "wall", "window" or "open": the shape one tile of a joint wall gives
/proc/vc_test_prison_wall_shape(turf/tile)
	if(isclosedturf(tile))
		return "wall"
	if(locate(/obj/structure/window) in tile)
		return "window"
	return "open"

/// Whatever on `inner` hangs on its neighbour `wall`: a wall mount tied to it, a light facing it, or
/// anything drawn shifted onto it (sinks, buttons, signs). Null if nothing does.
/proc/vc_test_prison_hung_on(turf/inner, turf/wall)
	var/direction = get_dir(inner, wall)
	for(var/obj/thing in inner)
		for(var/datum/component/wall_mounted/mount as anything in thing.GetComponents(/datum/component/wall_mounted))
			if(mount.hanging_wall_turf == wall)
				return thing
		if(istype(thing, /obj/machinery/light) && thing.dir == direction)
			return thing
		var/shift = (direction & (EAST|WEST)) ? thing.pixel_x : thing.pixel_y
		if(direction & (WEST|SOUTH))
			shift = -shift
		if(shift >= 8)
			return thing
	return null

/// Anything on a tile that opens besides the window, its grille and landmarks. Null if it is bare.
/proc/vc_test_prison_opening_clutter(turf/opening)
	for(var/obj/thing in opening)
		if(iseffect(thing) || istype(thing, /obj/structure/window) || istype(thing, /obj/structure/grille))
			continue
		return thing
	return null

/datum/unit_test/voidcrew_outpost_prison_extension_map
	/// One canvas per style
	var/list/datum/turf_reservation/reservations = list()
	/// Canvas (0,0) of the style being checked, south-west of the left extension. Canvas x = wing x + 12:
	/// left extension 1-13, wing 13-29, right extension 29-41, chained extension 41-53.
	var/turf/origin
	/// The style being checked, for the failure messages
	var/style

/datum/unit_test/voidcrew_outpost_prison_extension_map/Destroy()
	QDEL_LIST(reservations)
	origin = null
	return ..()

/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/canvas(x, y)
	return locate(origin.x + x, origin.y + y, origin.z)

/// What a seam tile holds, to show the load left it alone
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/tile_state(turf/tile)
	var/list/held = list()
	for(var/atom/movable/thing as anything in tile)
		if(isobj(thing) || ismob(thing))
			held += REF(thing)
	return "[tile.type] in [tile.loc.type] holding [jointext(held, ",")]"

/// The tiles inside the cell `door` closes: the small room on the side with a bed. Null if none.
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/cell_room(obj/machinery/door/door)
	var/turf/door_turf = get_turf(door)
	for(var/direction in GLOB.cardinals)
		var/list/room = list()
		var/list/seen = list()
		seen[door_turf] = TRUE
		var/list/queue = list(get_step(door_turf, direction))
		while(length(queue) && length(room) <= 12)
			var/turf/tile = queue[1]
			queue.Cut(1, 2)
			if(!tile || seen[tile])
				continue
			seen[tile] = TRUE
			if(!vc_test_prison_standable(tile))
				continue
			room += tile
			for(var/step_dir in GLOB.cardinals)
				queue += get_step(tile, step_dir)
		if(length(room) > 12)
			continue
		for(var/turf/tile as anything in room)
			if(locate(/obj/structure/bed) in tile)
				return room
	return null

/**
 * A cell's contents tile by tile from its south-west corner, as text. `mirrored` flips it east to
 * west: offsets, facings and directional subtypes, the way the left-hand map mirrors the wing.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/cell_signature(list/room, mirrored = FALSE)
	var/min_x = INFINITY
	var/max_x = 0
	var/min_y = INFINITY
	for(var/turf/tile as anything in room)
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
	var/list/lines = list()
	for(var/turf/tile as anything in room)
		var/offset_x = mirrored ? max_x - tile.x : tile.x - min_x
		var/list/things = list()
		for(var/obj/thing in tile)
			if(iseffect(thing))
				continue
			var/path_text = "[thing.type]"
			var/facing = thing.dir
			if(mirrored)
				path_text = replacetext(path_text, "/directional/east", "/directional/MIRROR")
				path_text = replacetext(path_text, "/directional/west", "/directional/east")
				path_text = replacetext(path_text, "/directional/MIRROR", "/directional/west")
				if(facing == EAST)
					facing = WEST
				else if(facing == WEST)
					facing = EAST
			things += "[path_text] dir [facing]"
		lines += "([offset_x],[tile.y - min_y]) [tile.type]: [jointext(sort_list(things), ", ")]"
	return jointext(sort_list(lines), "; ")

/datum/unit_test/voidcrew_outpost_prison_extension_map/Run()
	var/list/wings = outpost_style_maps(/datum/map_template/outpost_upgrade/prison)
	TEST_ASSERT(length(wings) >= 2, "The prison wing has fewer than two styles")
	for(var/datum/map_template/wing_type as anything in wings)
		style = initial(wing_type.outpost_style)
		var/datum/map_template/right_type = outpost_style_map(/datum/map_template/outpost_upgrade/prison_extension/right, style)
		var/datum/map_template/left_type = outpost_style_map(/datum/map_template/outpost_upgrade/prison_extension/left, style)
		TEST_ASSERT(right_type && initial(right_type.outpost_style) == style, "The right-hand extension has no [style] map")
		TEST_ASSERT(left_type && initial(left_type.outpost_style) == style, "The left-hand extension has no [style] map")
		check_style(new wing_type, new right_type, new left_type)

/// Lays one style's wing and extensions on a canvas of their own and checks them
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/check_style(datum/map_template/wing, datum/map_template/right, datum/map_template/left)
	for(var/datum/map_template/extension as anything in list(right, left))
		TEST_ASSERT_EQUAL(extension.width, 13, "[extension.mappath] should be 13 wide, a 12-tile slice and its seam column")
		TEST_ASSERT_EQUAL(extension.height, wing.height, "[extension.mappath] should be as tall as the prison wing")
	var/datum/turf_reservation/reserved = SSmapping.request_turf_block_reservation(55, 18, 1)
	TEST_ASSERT_NOTNULL(reserved, "Could not reserve room for the [style] wing and three extensions")
	reservations += reserved
	origin = reserved.bottom_left_turfs[1]

	// The wing, then each extension with its seam column on the wall it joins, as placement would.
	TEST_ASSERT_NOTNULL(wing.load_rotated(canvas(13, 1), 0), "The [style] prison wing did not load")
	var/list/wing_cell = cell_room(locate(/obj/machinery/door/airlock/security/glass/outpost_prison_cell) in canvas(15, 12))
	TEST_ASSERT_NOTNULL(wing_cell, "The [style] wing's cell 1 was not found behind its door at (3,12)")
	check_extension(right, "right", 29, 29, wing_cell)
	check_extension(right, "right", 41, 29, wing_cell)
	check_extension(left, "left", 1, 13, wing_cell)

/**
 * Loads `template` with its bottom-left on canvas (`at_x`, 1) and checks it: the seam left alone,
 * three complete cells like the wing's `wing_cell`, their bolt buttons, one hatch, nothing that
 * leads out or powers the room, and a far wall the same shape as the wing's side wall at canvas
 * x `wing_wall_x`, with its joint and nothing in the way of its openings.
 */
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/check_extension(datum/map_template/template, side, at_x, wing_wall_x, list/wing_cell)
	var/right_hand = (side == "right")
	var/seam_x = right_hand ? at_x : at_x + 12
	var/far_x = right_hand ? at_x + 12 : at_x
	var/inward = right_hand ? EAST : WEST
	var/label = "The [style] [side]-hand extension at canvas x [at_x]"
	var/list/openings = vc_test_prison_joint_openings()

	// Its seam column is all template_noop: the wall it joins is untouched by the load.
	var/list/seam_before = list()
	for(var/y in 1 to 16)
		seam_before += tile_state(canvas(seam_x, y))
	TEST_ASSERT_NOTNULL(template.load_rotated(canvas(at_x, 1), 0), "[label] did not load")
	for(var/y in 1 to 16)
		TEST_ASSERT_EQUAL(tile_state(canvas(seam_x, y)), seam_before[y], "[label] changed the wall it joins at row [y]; its seam column must be all template_noop")

	var/list/doors = list()
	var/list/buttons = list()
	var/list/hatches = list()
	var/list/snaps = list()
	var/list/lockers = list()
	var/washers = 0
	var/scrubbers = 0
	var/kessler_vents = 0
	var/window_doors = 0
	for(var/x in at_x to at_x + 12)
		if(x == seam_x)
			continue
		for(var/y in 1 to 16)
			var/turf/tile = canvas(x, y)
			var/authored = "([x - at_x + 1],[y])"
			TEST_ASSERT(istype(tile.loc, /area/voidcrew/player_outpost/prison_extension), "[label]: [authored] is in [tile.loc.type], not the extension's own area")
			for(var/obj/thing in tile)
				TEST_ASSERT(!istype(thing, /obj/machinery/power/apc), "[label] has an APC at [authored]; it runs off the wing's")
				TEST_ASSERT(!istype(thing, /obj/machinery/light_switch), "[label] has a light switch at [authored]")
				TEST_ASSERT(!istype(thing, /obj/structure/cable), "[label] has a cable at [authored]")
				TEST_ASSERT(!istype(thing, /obj/structure/fans), "[label] has a fan at [authored]; it has no door out")
				if(istype(thing, /obj/machinery/door/airlock))
					TEST_ASSERT(istype(thing, /obj/machinery/door/airlock/security/glass/outpost_prison_cell), "[label] has a [thing.type] at [authored]; its only airlocks are its cell doors")
					doors += thing
				else if(istype(thing, /obj/machinery/door/window))
					window_doors++
				else if(istype(thing, /obj/machinery/button/outpost_prison_bolt))
					buttons += thing
				else if(istype(thing, /obj/structure/table/reinforced/prison_hatch))
					hatches += thing
				else if(istype(thing, /obj/effect/landmark/outpost_upgrade_snap))
					snaps += thing
				else if(thing.type == /obj/structure/closet)
					lockers += thing
				else if(istype(thing, /obj/machinery/washing_machine))
					washers++
				else if(istype(thing, /obj/machinery/atmospherics/components/unary/vent_scrubber))
					scrubbers++
				else if(istype(thing, /obj/structure/outpost_kessler_vent))
					kessler_vents++

	// Three complete cells, each the wing's cell tile for tile (mirrored on the left-hand map),
	// with a numbered slot and a bolt button of the same slot hung beside its door.
	TEST_ASSERT_EQUAL(length(doors), 3, "[label] should have three cell doors")
	TEST_ASSERT_EQUAL(length(buttons), 3, "[label] should have three bolt buttons")
	var/wing_signature = cell_signature(wing_cell, mirrored = !right_hand)
	var/list/slots_seen = list()
	var/list/cell_turfs = list()
	for(var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/door as anything in doors)
		var/turf/door_turf = get_turf(door)
		var/where = "([door_turf.x - canvas(at_x, 1).x + 1],[door_turf.y - canvas(at_x, 1).y + 1])"
		TEST_ASSERT_EQUAL(door.cell_number, 0, "[label]'s cell door at [where] carries a cell number; the prison numbers extension cells")
		TEST_ASSERT(door.extension_slot >= 1 && door.extension_slot <= 3, "[label]'s cell door at [where] has extension slot [door.extension_slot], not 1 to 3")
		TEST_ASSERT(!slots_seen["[door.extension_slot]"], "[label] has two cell doors in slot [door.extension_slot]")
		slots_seen["[door.extension_slot]"] = TRUE
		var/list/room = cell_room(door)
		TEST_ASSERT_NOTNULL(room, "[label] has no cell with a bed behind its door at [where]")
		cell_turfs += room
		TEST_ASSERT_EQUAL(cell_signature(room), wing_signature, "[label]'s cell behind [where] is not the wing's cell [right_hand ? "" : "mirrored "]tile for tile")
		var/obj/structure/chair/seat
		for(var/turf/tile as anything in room)
			seat = seat || (locate(/obj/structure/chair) in tile)
		TEST_ASSERT_NOTNULL(seat, "[label]'s cell behind [where] has no chair")
		TEST_ASSERT(room.Find(get_step(seat, seat.dir)), "[label]'s cell chair behind [where] faces out of the cell")
		var/obj/machinery/button/outpost_prison_bolt/matching
		for(var/obj/machinery/button/outpost_prison_bolt/button as anything in buttons)
			if(button.extension_slot == door.extension_slot)
				matching = button
		TEST_ASSERT_NOTNULL(matching, "[label] has no bolt button for slot [door.extension_slot]")
		TEST_ASSERT_EQUAL(matching.cell_number, 0, "[label]'s slot [door.extension_slot] bolt button carries a cell number")
		TEST_ASSERT(get_dist(matching, door) == 1 && !room.Find(get_turf(matching)), "[label]'s slot [door.extension_slot] bolt button is not beside its door on the yard side")
		var/turf/button_wall = get_step(matching, matching.dir)
		TEST_ASSERT(iswallturf(button_wall) && get_dist(button_wall, door_turf) == 1 && (button_wall.x == door_turf.x || button_wall.y == door_turf.y), "[label]'s slot [door.extension_slot] bolt button does not hang on the wall beside its door")

	// One serving hatch: the counter with a window door each side, and room to stand on both.
	TEST_ASSERT_EQUAL(length(hatches), 1, "[label] should have one serving hatch")
	TEST_ASSERT_EQUAL(window_doors, 2, "[label] should have just the hatch's two window doors")
	var/turf/hatch_turf = get_turf(hatches[1])
	var/obj/machinery/door/window/yard_side = locate(/obj/machinery/door/window/outpost_prison_yard) in hatch_turf
	var/obj/machinery/door/window/staff_side = locate(/obj/machinery/door/window/brigdoor/outpost_prison_staff) in hatch_turf
	TEST_ASSERT(yard_side?.dir == NORTH, "[label]'s hatch has no yard window door facing the yard")
	TEST_ASSERT(staff_side?.dir == SOUTH, "[label]'s hatch has no staff window door facing the office")
	var/turf/yard_step = get_step(hatch_turf, NORTH)
	var/turf/office_step = get_step(hatch_turf, SOUTH)
	TEST_ASSERT(vc_test_prison_standable(yard_step) && vc_test_prison_standable(office_step), "[label]'s hatch is blocked on one side")

	// The office holds the new uniforms and a washing machine; the yard's scrubbers and vent.
	TEST_ASSERT_EQUAL(length(lockers), 1, "[label] should have one uniform locker")
	var/obj/structure/closet/locker = lockers[1]
	var/suits = 0
	var/shoes = 0
	for(var/obj/item/thing in locker)
		if(istype(thing, /obj/item/clothing/under/rank/prisoner/outpost))
			suits++
		else if(istype(thing, /obj/item/clothing/shoes/sneakers/orange))
			shoes++
	TEST_ASSERT_EQUAL(suits, 6, "[label]'s locker should hold six prison uniforms")
	TEST_ASSERT_EQUAL(shoes, 6, "[label]'s locker should hold six pairs of shoes")
	TEST_ASSERT_EQUAL(washers, 1, "[label] should have one washing machine")
	TEST_ASSERT_EQUAL(scrubbers, 5, "[label] should have five air scrubbers, one per cell and two in the yard")
	TEST_ASSERT_EQUAL(kessler_vents, 4, "[label] should have four Kessler vents, one per cell and one in the yard")

	// The far wall is the wing's side wall again, so another extension can join it, and carries
	// the joint for that.
	for(var/y in 1 to 16)
		var/turf/far_tile = canvas(far_x, y)
		var/turf/wing_tile = canvas(wing_wall_x, y)
		TEST_ASSERT_EQUAL(vc_test_prison_wall_shape(far_tile), vc_test_prison_wall_shape(wing_tile), "[label]'s far wall at row [y] differs from the [style] wing's [side] wall")
		TEST_ASSERT_EQUAL(far_tile.type, wing_tile.type, "[label]'s far wall at row [y] is a different turf from the [style] wing's [side] wall")
	TEST_ASSERT_EQUAL(length(snaps), 1, "[label] should carry one joint, at the bottom of its far wall")
	var/obj/effect/landmark/outpost_upgrade_snap/snap = snaps[1]
	TEST_ASSERT_EQUAL(get_turf(snap), canvas(far_x, 1), "[label]'s joint is not at the bottom of its far wall")
	TEST_ASSERT(isclosedturf(get_turf(snap)), "[label]'s joint is not on a wall")
	TEST_ASSERT(istype(snap, right_hand ? /obj/effect/landmark/outpost_upgrade_snap/right : /obj/effect/landmark/outpost_upgrade_snap/left), "[label]'s joint is a [snap.type]")
	TEST_ASSERT_EQUAL(snap.side, side, "[label]'s joint is for the wrong side")
	TEST_ASSERT_EQUAL(snap.snap_group, "prison_cells", "[label]'s joint takes the wrong upgrades")
	TEST_ASSERT_EQUAL(snap.dir, right_hand ? EAST : WEST, "[label]'s joint faces the wrong way")
	TEST_ASSERT_EQUAL(jointext(snap.seam_openings, ","), jointext(openings, ","), "[label]'s joint opens the wrong rows")

	// Both ends of each opening row: nothing hangs on the tile that opens, and there is ground to
	// stand on inside it. The far wall's openings hold only their window.
	for(var/row in openings)
		var/turf/seam_opening = canvas(seam_x, row)
		var/turf/seam_inner = get_step(seam_opening, inward)
		var/obj/hung = vc_test_prison_hung_on(seam_inner, seam_opening)
		TEST_ASSERT(!hung, "[label]: [hung] hangs on the joined wall at row [row], which opens")
		TEST_ASSERT(vc_test_prison_standable(seam_inner), "[label]: nobody can stand inside the seam opening at row [row]")
		var/turf/far_opening = canvas(far_x, row)
		var/turf/far_inner = get_step(far_opening, REVERSE_DIR(inward))
		hung = vc_test_prison_hung_on(far_inner, far_opening)
		TEST_ASSERT(!hung, "[label]: [hung] hangs on its far wall at row [row], which opens")
		TEST_ASSERT(vc_test_prison_standable(far_inner), "[label]: nobody can stand inside the far wall's opening at row [row]")
		var/obj/clutter = vc_test_prison_opening_clutter(far_opening)
		TEST_ASSERT(!clutter, "[label]: [clutter] is on its far wall at row [row], which opens")

	// The office and the yard are each one walkable room from end to end, and apart.
	var/list/office = walkable_from(canvas(seam_x, 3), inward, seam_x, far_x)
	var/list/yard = walkable_from(canvas(seam_x, 8), inward, seam_x, far_x)
	TEST_ASSERT(office[get_step(canvas(far_x, 3), REVERSE_DIR(inward))], "[label]'s office does not reach from one opening to the other")
	TEST_ASSERT(office[office_step], "[label]'s hatch cannot be reached from its office")
	TEST_ASSERT(locker.loc && office[get_step(locker, SOUTH)], "[label]'s locker cannot be reached from its office")
	for(var/row in list(8, 10))
		TEST_ASSERT(yard[get_step(canvas(seam_x, row), inward)] && yard[get_step(canvas(far_x, row), REVERSE_DIR(inward))], "[label]'s yard does not reach both openings at row [row]")
	TEST_ASSERT(yard[yard_step], "[label]'s hatch cannot be reached from its yard")
	for(var/obj/machinery/door/door as anything in doors)
		TEST_ASSERT(yard[get_step(door, SOUTH)], "[label]'s cell door at [door.x - canvas(at_x, 1).x + 1] cannot be reached from its yard")
	for(var/turf/tile as anything in office)
		TEST_ASSERT(!yard[tile], "[label]'s office and yard are joined")
	for(var/turf/tile as anything in cell_turfs)
		TEST_ASSERT(!yard[tile] && !office[tile], "[label]'s cells are open to the yard or office without their doors")

/// The tiles a prisoner can walk to from the extension's side of the seam opening at `opening`,
/// staying inside the extension (seam column `seam_x` to far wall `far_x`), as tile = TRUE
/datum/unit_test/voidcrew_outpost_prison_extension_map/proc/walkable_from(turf/opening, inward, seam_x, far_x)
	var/list/reached = list()
	var/list/queue = list(get_step(opening, inward))
	var/low_x = min(seam_x, far_x) + 1
	var/high_x = max(seam_x, far_x) - 1
	while(length(queue))
		var/turf/tile = queue[1]
		queue.Cut(1, 2)
		if(!tile || reached[tile] || tile.x < origin.x + low_x || tile.x > origin.x + high_x || !vc_test_prison_standable(tile))
			continue
		reached[tile] = TRUE
		for(var/direction in GLOB.cardinals)
			queue += get_step(tile, direction)
	return reached
