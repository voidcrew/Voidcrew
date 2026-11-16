/**
 * # Cargo shelf: slots follow the crates, parts cost what they return, saves keep it empty
 *
 * The shelf keeps one slot per level and nothing else holds a reference to a stored crate, so
 * Entered() and Exited() have to keep the slots, the display list and the crate's own
 * pixel_y and layer right however the crate came or went.
 *
 * The parts take four iron sheets to make, so taking them apart may never give back more than
 * the recipe asked for.
 *
 * A ship save keeps the shelf as a plain structure. Crates stored in it are not objects on the
 * tile, so they are not saved, and clear_stock() empties whatever a stored crate holds.
 */

/datum/unit_test/voidcrew_cargo_shelf_slots/Run()
	var/obj/structure/cargo_shelf/shelf = allocate(/obj/structure/cargo_shelf)
	var/list/obj/structure/closet/crate/crates = list()
	for(var/i in 1 to shelf.capacity + 1)
		crates += allocate(/obj/structure/closet/crate)
	var/obj/structure/closet/crate/extra = crates[length(crates)]
	for(var/level in 1 to shelf.capacity)
		var/obj/structure/closet/crate/crate = crates[level]
		TEST_ASSERT(shelf.insert_crate(crate), "Crate [level] would not go on an empty level")
		TEST_ASSERT_EQUAL(crate.loc, shelf, "Crate [level] is not inside the shelf")
		TEST_ASSERT_EQUAL(shelf.shelf_contents[level], crate, "Crate [level] is not in its slot")
		TEST_ASSERT_EQUAL(crate.pixel_y, 10 * (level - 1), "Crate [level] is not drawn on its level")
		TEST_ASSERT(crate in shelf.vis_contents, "Crate [level] is not displayed on the shelf")
	TEST_ASSERT(!shelf.insert_crate(extra), "A full shelf took another crate")
	TEST_ASSERT(isturf(extra.loc), "The refused crate was moved anyway")

	// A crate that leaves by any route frees its slot and goes back to looking like a floor crate.
	var/obj/structure/closet/crate/middle = crates[2]
	middle.forceMove(get_turf(shelf))
	TEST_ASSERT_NULL(shelf.shelf_contents[2], "A crate that left kept its slot")
	TEST_ASSERT(!(middle in shelf.vis_contents), "A crate that left is still displayed on the shelf")
	TEST_ASSERT_EQUAL(middle.pixel_y, initial(middle.pixel_y), "A crate that left kept its shelf offset")
	TEST_ASSERT_EQUAL(middle.layer, extra.layer, "A crate that left kept its shelf layer")
	TEST_ASSERT(shelf.insert_crate(extra), "The freed level took no crate")
	TEST_ASSERT_EQUAL(shelf.shelf_contents[2], extra, "A new crate did not take the lowest free level")

	// A crate that is deleted while stored must not leave a dead reference behind.
	var/obj/structure/closet/crate/bottom = crates[1]
	qdel(bottom)
	TEST_ASSERT_NULL(shelf.shelf_contents[1], "A deleted crate kept its slot")
	for(var/obj/structure/closet/crate/entry in shelf.shelf_contents)
		TEST_ASSERT(!QDELETED(entry), "The shelf list holds a deleted crate")

/datum/unit_test/voidcrew_cargo_shelf_disassembly/Run()
	var/obj/structure/cargo_shelf/shelf = allocate(/obj/structure/cargo_shelf)
	var/turf/floor = get_turf(shelf)
	var/obj/structure/closet/crate/first = allocate(/obj/structure/closet/crate)
	var/obj/structure/closet/crate/second = allocate(/obj/structure/closet/crate)
	TEST_ASSERT(shelf.insert_crate(first) && shelf.insert_crate(second), "The crates would not load")
	shelf.deconstruct(TRUE)
	TEST_ASSERT(QDELETED(shelf), "The shelf survived being taken apart")
	TEST_ASSERT(!QDELETED(first) && !QDELETED(second), "Taking a shelf apart destroyed a crate")
	TEST_ASSERT(isturf(first.loc) && isturf(second.loc), "Taking a shelf apart left a crate inside it")
	var/obj/item/rack_parts/cargo_shelf/parts = locate() in floor
	TEST_ASSERT_NOTNULL(parts, "Taking a shelf apart left no parts")

	// The recipe is offered on iron sheets, and the parts give back no more than it takes.
	var/obj/item/stack/sheet/iron/sheet = allocate(/obj/item/stack/sheet/iron, run_loc_floor_top_right)
	var/cost
	for(var/datum/stack_recipe/recipe in sheet.recipes)
		if(recipe.result_type == /obj/item/rack_parts/cargo_shelf)
			cost = recipe.req_amount
	TEST_ASSERT_NOTNULL(cost, "Iron sheets do not offer cargo shelf parts")
	parts.deconstruct(TRUE)
	var/returned = 0
	for(var/obj/item/stack/sheet/iron/dropped in floor)
		returned += dropped.amount
	TEST_ASSERT(returned <= cost, "Cargo shelf parts return [returned] iron sheets and cost [cost]")

/datum/unit_test/voidcrew_cargo_shelf_checkpoint
	var/obj/docking_port/mobile/voidcrew/stock_test/source_port

/datum/unit_test/voidcrew_cargo_shelf_checkpoint/Destroy()
	if(source_port)
		qdel(source_port, force = TRUE)
	source_port = null
	return ..()

/datum/unit_test/voidcrew_cargo_shelf_checkpoint/Run()
	source_port = new(run_loc_floor_bottom_left)
	source_port.shuttle_areas = list()
	source_port.shuttle_areas[get_area(run_loc_floor_bottom_left)] = TRUE
	var/datum/checkpoint_construction/stock_test/job = allocate(/datum/checkpoint_construction/stock_test)
	var/datum/ship_checkpoint/snapshot = allocate(/datum/ship_checkpoint)
	var/obj/structure/cargo_shelf/shelf = allocate(/obj/structure/cargo_shelf)
	var/obj/structure/closet/crate/crate = allocate(/obj/structure/closet/crate)
	var/obj/item/stored_item = allocate(/obj/item/screwdriver, crate)
	TEST_ASSERT(shelf.insert_crate(crate), "The crate would not go on the shelf")

	// The save keeps the shelf, as itself, and never sees the crate stored in it.
	TEST_ASSERT(snapshot.includes_object(shelf), "A ship save leaves the shelf behind")
	TEST_ASSERT(findtext(snapshot.atom_text(shelf), "/obj/structure/cargo_shelf"), "A saved shelf is not rebuilt as a shelf")
	TEST_ASSERT(!(crate in get_turf(shelf)), "A stored crate counts as an object on the tile")

	// Whatever a stored crate holds is scrubbed like the contents of any other container.
	job.clear_stock(source_port)
	TEST_ASSERT(QDELETED(stored_item), "Clearing stock left an item in a stored crate")
	TEST_ASSERT(crate.contents_initialized, "A stored crate may still generate stock when opened")
