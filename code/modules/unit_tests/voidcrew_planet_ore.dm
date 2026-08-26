/**
 * # Mid-round sites must still get their ore, and only their own
 *
 * Upstream's ore rework grades a wall by its distance to open air and rolls it in ONE pass at
 * the bottom of SSore_generation.Initialize(). A rock with `exposure_based` set does not roll
 * in its own Initialize() at all - it appends itself to SSore_generation.ore_turfs and waits
 * for that pass. Every planet in this fork is built when a ship flies to it, hours after that
 * pass has run, so its rock waits forever: an ice planet generates with no ore in any wall,
 * a lava planet with about a sixth of its intended ore, and the planetary trade goods keyed
 * off those same tables (glacial cores, telecrystal veins) go with them.
 *
 * randomize_site_ore() (voidcrew/turfs/closed/minerals.dm) runs the same two passes at build
 * time over the site's own footprint. This asserts both halves of that, and the property
 * packing needs:
 *
 *  1. Rock built mid-round really does queue and really does not roll on its own - if a retune
 *     ever changes that, this test stops guarding anything and says so instead of passing.
 *  2. The footprint-scoped depth walk grades our rock exactly as upstream's z-wide one would
 *     (touching open air is depth 1, one wall further in is depth 2), and the roll drains our
 *     rock out of the queue so nothing can roll it twice.
 *  3. A CO-TENANT's rock on the same z-level is not graded, not rolled, and not drained. Up to
 *     four sites share a packed level; upstream's pass walks whole z-levels, so an unscoped
 *     port of it would grade and roll the neighbour's ground - possibly while a crew is
 *     standing on it, and possibly before that site has finished generating.
 *
 * Its own minted level, for the same reason voidcrew_map_packing.dm mints one: the planet slot
 * pool is shared with whatever the live round is already holding, and this test rewrites turfs.
 *
 * Literals rather than the MAP_TENANT_CLASS_* defines - unit tests are included well before
 * voidcrew/_DEFINES in the .dme, so none of them exist yet here. Same reason
 * voidcrew_map_packing.dm spells its slot geometry out.
 */
/datum/unit_test/voidcrew_planet_ore

/// Side of the square rock patch stamped inside each footprint. Three is the smallest that
/// produces both depths: a ring of walls touching open space, and one wall that does not.
#define ORE_TEST_PATCH_SIDE 3

/datum/unit_test/voidcrew_planet_ore/Run()
	var/planet_class = "planet" // MAP_TENANT_CLASS_PLANET
	var/patch_turfs = ORE_TEST_PATCH_SIDE * ORE_TEST_PATCH_SIDE

	// The premise. /turf/closed/mineral/random/snow is what the ice biomes lay down and the
	// type the bug emptied; if it ever stops being exposure-based it rolls at Initialize like
	// any other rock and everything below would pass while testing nothing.
	var/defers_its_roll = /turf/closed/mineral/random/snow::exposure_based
	if(!defers_its_roll)
		TEST_FAIL("/turf/closed/mineral/random/snow is no longer exposure_based, so it rolls its ore in Initialize() and this test guards nothing. \
			Point it at whichever rock type the planet biomes now defer, or retire it.")
		return

	// A level and a zone nobody else is on. Order matters: add_new_zlevel() sleeps, so the
	// level is made before the zone exists and no other claimant can be dealt a slot of it
	// behind our back. No ZTRAIT_MINING deliberately - the build-time pass must not depend on
	// the level trait upstream's own pass selects on.
	var/datum/space_level/ore_level = SSmapping.add_new_zlevel("Planet ore test", list())
	var/datum/map_zone/ore_zone = SSovermap.create_map_zone("Planet ore test")
	ore_zone.add_space_level(ore_level)

	var/datum/map_footprint/ours = ore_zone.claim_slot(planet_class, null)
	var/datum/map_footprint/neighbour = ore_zone.claim_slot(planet_class, null)
	if(!ours || !neighbour)
		TEST_FAIL("Could not claim two planet slots on one level, so co-tenant isolation cannot be tested")
		release_ore_test_slots(ore_zone, list(ours, neighbour))
		return
	if(ours.z_value != neighbour.z_value)
		TEST_FAIL("The two planet slots landed on different z-levels (z[ours.z_value] and z[neighbour.z_value]) - they are not packing, so this test is not guarding anything")
		release_ore_test_slots(ore_zone, list(ours, neighbour))
		return

	// Set in from the slot corner so every wall of the patch has open ground around it, and so
	// nothing lands in the cordon gutter or on the far side of a footprint edge.
	var/list/turf/our_rock = build_ore_test_patch(ours)
	var/list/turf/their_rock = build_ore_test_patch(neighbour)
	if(length(our_rock) != patch_turfs || length(their_rock) != patch_turfs)
		TEST_FAIL("Could not stamp two [ORE_TEST_PATCH_SIDE]x[ORE_TEST_PATCH_SIDE] rock patches ([length(our_rock)] and [length(their_rock)] turfs) - the rest of this test cannot run")
		clear_ore_test_patch(our_rock)
		clear_ore_test_patch(their_rock)
		release_ore_test_slots(ore_zone, list(ours, neighbour))
		return

	// ---- 1. The premise: mid-round rock queues, ungraded and oreless -------------------

	for(var/turf/closed/mineral/random/rock as anything in (our_rock + their_rock))
		if(!istype(rock))
			TEST_FAIL("A stamped test wall came back as [rock?.type], not a random mineral turf")
			continue
		if(rock.mineral_type)
			TEST_FAIL("[rock.type] at ([rock.x],[rock.y]) rolled '[rock.mineral_type]' during Initialize(). It is exposure_based, so it must defer to the depth pass - if this changed upstream, randomize_site_ore() is now double-rolling every wall on every planet.")
		if(rock.open_turf_distance != initial(rock.open_turf_distance))
			TEST_FAIL("[rock.type] at ([rock.x],[rock.y]) was graded to depth [rock.open_turf_distance] by something other than the build-time pass")
		if(!(rock in SSore_generation.ore_turfs))
			TEST_FAIL("[rock.type] at ([rock.x],[rock.y]) did not queue itself into SSore_generation.ore_turfs. Nothing will ever roll it: the subsystem's own pass ran once, at roundstart.")

	// ---- 2. The depth walk, bounded to our slot ----------------------------------------

	// Run on its own first, so the assertions below are about grading alone. A roll can
	// ChangeTurf a wall into a gibtonite or trade-good vein turf, and the replacement starts
	// with a fresh (ungraded) depth - reading depths after rolling would be a coin flip.
	calculate_rock_edges_in_rect(ours.low_x, ours.low_y, ours.high_x, ours.high_y, ours.z_value, FALSE)

	var/turf/closed/mineral/patch_centre = centre_of_patch(our_rock)
	for(var/turf/closed/mineral/rock as anything in our_rock)
		var/expected_depth = (rock == patch_centre) ? 2 : 1
		if(rock.open_turf_distance != expected_depth)
			TEST_FAIL("The wall at ([rock.x],[rock.y]) was graded depth [rock.open_turf_distance], expected [expected_depth]. \
				Depth is what picks the ore table (randomize_ore()'s vein_distance factor), so a wrong depth is the wrong ore at the wrong rate.")

	for(var/turf/closed/mineral/rock as anything in their_rock)
		if(rock.open_turf_distance != initial(rock.open_turf_distance))
			TEST_FAIL("The CO-TENANT's wall at ([rock.x],[rock.y]) in [neighbour.describe()] was graded to depth [rock.open_turf_distance] by a pass run for [ours.describe()]. \
				The depth walk is escaping its footprint - on a packed level that grades a neighbour's rock, mid-build or mid-round.")

	// ---- 3. The roll, and the drain -----------------------------------------------------

	var/rolled = randomize_site_ore(ours, ore_level, FALSE)
	if(rolled != patch_turfs)
		TEST_FAIL("randomize_site_ore() rolled [rolled] of [patch_turfs] queued walls inside [ours.describe()]")

	for(var/turf/closed/mineral/rock as anything in our_rock)
		if(rock in SSore_generation.ore_turfs)
			TEST_FAIL("The wall at ([rock.x],[rock.y]) is still queued in SSore_generation.ore_turfs after being rolled. \
				The queue is never drained, so it grows for the whole round and a second pass over this ground would roll the same wall twice.")

	for(var/turf/closed/mineral/random/rock as anything in their_rock)
		if(!istype(rock))
			TEST_FAIL("The co-tenant's wall at ([rock?.x],[rock?.y]) was turned into [rock?.type] by a roll run for the neighbouring slot")
			continue
		if(rock.mineral_type)
			TEST_FAIL("The CO-TENANT's wall at ([rock.x],[rock.y]) in [neighbour.describe()] was given '[rock.mineral_type]' by a roll run for [ours.describe()]")
		if(!(rock in SSore_generation.ore_turfs))
			TEST_FAIL("The CO-TENANT's wall at ([rock.x],[rock.y]) was drained out of SSore_generation.ore_turfs by a roll run for [ours.describe()]. \
				Its own build will never roll it, and the site generates barren.")

	// A second pass over the same ground must be a no-op rather than a re-roll.
	var/second_pass = randomize_site_ore(ours, ore_level, FALSE)
	if(second_pass)
		TEST_FAIL("A second randomize_site_ore() over the same footprint rolled [second_pass] more walls - the first pass did not drain what it rolled")

	// ---- Cleanup -------------------------------------------------------------------------

	// The neighbour's walls are still queued, on purpose - that is what the test asserts - so
	// take them out by hand before the ground goes away under them.
	SSore_generation.ore_turfs -= their_rock
	clear_ore_test_patch(our_rock)
	clear_ore_test_patch(their_rock)
	release_ore_test_slots(ore_zone, list(ours, neighbour))

/// The one wall in a square patch with no open neighbour: the middle of its bounding box.
/// Derived from the turfs rather than indexed out of the list, so it does not rest on block()'s
/// iteration order.
/datum/unit_test/voidcrew_planet_ore/proc/centre_of_patch(list/turf/patch)
	var/min_x = INFINITY
	var/min_y = INFINITY
	var/max_x = 0
	var/max_y = 0
	var/z_value = 0
	for(var/turf/tile as anything in patch)
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
		max_y = max(max_y, tile.y)
		z_value = tile.z
	if(!z_value)
		return null
	return locate(round((min_x + max_x) / 2), round((min_y + max_y) / 2), z_value)

/**
 * Stamps a square of exposure-based rock inside a footprint and hands back the walls.
 *
 * The source turfs are initialized first: a freshly minted z-level is raw, uninitialized
 * /turf/open/space/basic, and ChangeTurf qdel()s the turf it replaces.
 */
/datum/unit_test/voidcrew_planet_ore/proc/build_ore_test_patch(datum/map_footprint/footprint)
	. = list()
	if(isnull(footprint?.low_x))
		return
	// Ten turfs in from the corner: clear of the slot edge, the cordon gutter and the reserve
	// berth strip, so the patch is surrounded by this site's own open ground.
	var/turf/bottom_left = locate(footprint.low_x + 10, footprint.low_y + 10, footprint.z_value)
	var/turf/top_right = locate(footprint.low_x + 10 + ORE_TEST_PATCH_SIDE - 1, footprint.low_y + 10 + ORE_TEST_PATCH_SIDE - 1, footprint.z_value)
	if(!bottom_left || !top_right)
		return

	var/list/turf/ground = block(bottom_left, top_right)
	var/list/turf/to_initialize = list()
	for(var/turf/tile as anything in ground)
		if(!(tile.flags_1 & INITIALIZED_1))
			to_initialize += tile
	if(length(to_initialize))
		SSatoms.InitializeAtoms(to_initialize)

	for(var/turf/tile as anything in ground)
		. += tile.ChangeTurf(/turf/closed/mineral/random/snow)

/// Puts a stamped patch back to bare space.
/datum/unit_test/voidcrew_planet_ore/proc/clear_ore_test_patch(list/turf/patch)
	for(var/turf/tile as anything in patch)
		// A turf ref retargets onto whatever stands at the coordinate now, so a wall that
		// rolled itself into a vein turf is still reachable through the same entry.
		tile?.ChangeTurf(/turf/open/space)

/// Hands claimed slots back, tolerating nulls.
/datum/unit_test/voidcrew_planet_ore/proc/release_ore_test_slots(datum/map_zone/zone, list/footprints)
	for(var/datum/map_footprint/claimed as anything in footprints)
		if(!claimed)
			continue
		var/datum/map_zone/owning_zone = claimed.zone || zone
		if(owning_zone)
			owning_zone.release_slot(claimed)

#undef ORE_TEST_PATCH_SIDE
