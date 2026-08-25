/**
 * # Voidcrew map-zone packing test
 *
 * A z-level used to hold exactly one tenant: /datum/space_level carried one rectangle,
 * /datum/map_zone carried one `taken` boolean, and every teardown reset the entire level.
 * Flat encounters (empty space, crashed ships, weak signals) therefore burned a whole
 * 255x255 z-level - and a 65,025-turf initialization sweep - for what is functionally two
 * 56x40 berths.
 *
 * They now share one level through a fixed 2x2 lattice of 123x123 slots. This test drives
 * the real allocation path twice and asserts the four properties packing depends on:
 *
 *  1. Two encounters land on the SAME level in DIFFERENT, non-overlapping slots, with a
 *     cordon in the gutter between them and their reserve berths on different tiles. (Both
 *     berths anchored off the level rather than the footprint is the failure that puts two
 *     ships on top of each other - it is the arrival path.)
 *  2. Releasing one leaves the other's turfs, area and berths untouched. The old
 *     clear_reservation() widened to the whole z before resetting, which mid-round with
 *     players on it is a co-tenant wipe.
 *  3. The released slot really is released: its ground goes back to uninitialized space
 *     while the neighbour's stays initialized.
 *  4. The last tenant out resets the entire level - cordon included - and hands the zone
 *     back with every slot free, so it can be recycled as any tenant class.
 *
 * Literals rather than the MAP_SLOT_* / MAP_TENANT_CLASS_* / RESERVE_DOCK_* defines: unit
 * tests are included at line ~6405 of the .dme and voidcrew/_DEFINES at ~6680, so none of
 * them exist yet here. Same reason voidcrew_ruin_reservation.dm spells its dock sizes out.
 */
/datum/unit_test/voidcrew_map_packing

/datum/unit_test/voidcrew_map_packing/Run()
	var/slot_side = 123 // MAP_SLOT_SIDE (= PLANET_MIN_SIZE)
	var/slot_margin = 2 // MAP_SLOT_MARGIN
	var/slot_gutter = 5 // MAP_SLOT_GUTTER
	var/flat_class = "flat" // MAP_TENANT_CLASS_FLAT

	// The whole scheme rests on this fitting. If world.maxx ever changes, the lattice has
	// to be re-derived rather than silently overflowing into the world edge.
	var/lattice_span = (slot_margin * 2) + (slot_side * 2) + slot_gutter
	if(lattice_span != world.maxx || lattice_span != world.maxy)
		TEST_FAIL("The 2x2 slot lattice needs [lattice_span] turfs per axis but the world is [world.maxx]x[world.maxy]. \
			Slots would run off the map edge - re-derive MAP_SLOT_SIDE/MARGIN/GUTTER in voidcrew/_DEFINES/planet_defines.dm.")
		return

	// ---- Build two flat encounters through the real allocation path ------------------

	var/list/first_values = SSovermap.spawn_dynamic_encounter(null, FALSE)
	if(length(first_values) < 4)
		TEST_FAIL("spawn_dynamic_encounter() did not return a footprint for the first encounter - packing cannot be tested")
		return
	var/list/second_values = SSovermap.spawn_dynamic_encounter(null, FALSE)
	if(length(second_values) < 4)
		TEST_FAIL("spawn_dynamic_encounter() did not return a footprint for the second encounter")
		return

	var/datum/map_zone/first_zone = first_values[1]
	var/obj/docking_port/stationary/first_dock = first_values[2]
	var/obj/docking_port/stationary/first_dock_secondary = first_values[3]
	var/datum/map_footprint/first_footprint = first_values[4]

	var/datum/map_zone/second_zone = second_values[1]
	var/obj/docking_port/stationary/second_dock = second_values[2]
	var/obj/docking_port/stationary/second_dock_secondary = second_values[3]
	var/datum/map_footprint/second_footprint = second_values[4]

	if(!first_footprint || !second_footprint)
		TEST_FAIL("A flat encounter was built without a map footprint")
		return

	// ---- 1. Same level, different slots, no overlap ----------------------------------

	if(first_zone != second_zone)
		TEST_FAIL("Two flat encounters were dealt different map zones ([first_zone?.name] vs [second_zone?.name]). \
			find_free_slot() must prefer a partially-filled zone of the same tenant class, or every encounter still burns a z-level.")
	if(first_footprint.z_value != second_footprint.z_value)
		TEST_FAIL("Two flat encounters landed on different z-levels (z[first_footprint.z_value] and z[second_footprint.z_value]) - they are not packing")

	if(first_footprint.tenant_class != flat_class || second_footprint.tenant_class != flat_class)
		TEST_FAIL("Flat encounters were dealt tenant classes '[first_footprint.tenant_class]'/'[second_footprint.tenant_class]', expected '[flat_class]'")

	if(first_footprint.slot_index == second_footprint.slot_index)
		TEST_FAIL("Both flat encounters were dealt slot [first_footprint.slot_index] of the same zone - the slot register handed the same rectangle out twice")

	if(first_footprint.get_width() != slot_side || first_footprint.get_height() != slot_side)
		TEST_FAIL("Slot [first_footprint.slot_index] is [first_footprint.get_width()]x[first_footprint.get_height()], expected [slot_side]x[slot_side]")

	var/overlaps = first_footprint.low_x <= second_footprint.high_x \
		&& second_footprint.low_x <= first_footprint.high_x \
		&& first_footprint.low_y <= second_footprint.high_y \
		&& second_footprint.low_y <= first_footprint.high_y
	if(overlaps)
		TEST_FAIL("Footprints overlap: [first_footprint.describe()] and [second_footprint.describe()]")

	// Neither may claim a turf the other owns, in either direction.
	if(first_footprint.contains_coords(second_footprint.low_x, second_footprint.low_y, second_footprint.z_value))
		TEST_FAIL("contains_coords(): footprint [first_footprint.describe()] claims the neighbour's origin turf")
	if(second_footprint.contains_coords(first_footprint.low_x, first_footprint.low_y, first_footprint.z_value))
		TEST_FAIL("contains_coords(): footprint [second_footprint.describe()] claims the neighbour's origin turf")

	// The gutter between them has to be cordon, not bare space - bare space beside a
	// pressurised turf is a permanent self-renewing pressure delta, and cordon is the only
	// thing that blocks movement, sight, air, reach and projectiles between tenants.
	var/turf/gutter_turf = locate(min(first_footprint.high_x, second_footprint.high_x) + 1, first_footprint.low_y, first_footprint.z_value)
	if(first_footprint.low_y == second_footprint.low_y && gutter_turf && !istype(gutter_turf, /turf/cordon))
		TEST_FAIL("The gutter turf at ([gutter_turf.x],[gutter_turf.y],[gutter_turf.z]) between the two slots is [gutter_turf.type], not /turf/cordon")

	// ---- 2. Berths must not stack ----------------------------------------------------

	if(!first_dock || !second_dock)
		TEST_FAIL("A flat encounter was built without a primary reserve berth")
		return
	var/turf/first_dock_turf = get_turf(first_dock)
	var/turf/second_dock_turf = get_turf(second_dock)
	if(first_dock_turf == second_dock_turf)
		TEST_FAIL("Both encounters' primary reserve berths were built on the same turf ([first_dock_turf?.x],[first_dock_turf?.y]) - \
			berths are anchored off the z-level instead of the footprint, and two ships would materialise on top of each other")
	if(!first_footprint.contains_turf(first_dock_turf))
		TEST_FAIL("The first encounter's berth at ([first_dock_turf?.x],[first_dock_turf?.y]) is outside its own footprint [first_footprint.describe()]")
	if(!second_footprint.contains_turf(second_dock_turf))
		TEST_FAIL("The second encounter's berth at ([second_dock_turf?.x],[second_dock_turf?.y]) is outside its own footprint [second_footprint.describe()]")
	if(!second_footprint.contains_turf(get_turf(second_dock_secondary)))
		TEST_FAIL("The second encounter's secondary berth is outside its own footprint [second_footprint.describe()] - a 56-wide berth pair does not fit the slot")

	// ---- 2b. A ruin may never be stamped over those berths ---------------------------

	test_ruin_slot_placement(first_footprint, first_dock, first_dock_secondary)

	// ---- Give each tenant its own area, per footprint ---------------------------------

	var/datum/space_level/level = first_zone.z_levels[1]
	var/area/first_area = level.fill_in(area_override = /area/overmap_encounter, throttled = FALSE, footprint = first_footprint)
	var/area/second_area = level.fill_in(area_override = /area/overmap_encounter, throttled = FALSE, footprint = second_footprint)
	if(!first_area || !second_area || first_area == second_area)
		TEST_FAIL("fill_in() did not give the two footprints separate area instances - /area/overmap_encounter must stay non-UNIQUE_AREA for packing to work")
		return

	var/turf/first_center = first_footprint.get_center_turf()
	var/turf/second_center = second_footprint.get_center_turf()
	if(get_area(first_center) != first_area || get_area(second_center) != second_area)
		TEST_FAIL("fill_in() painted outside its footprint - the two tenants' areas bled into each other")

	// ---- 3. Release the first tenant; the second must survive untouched ---------------

	var/first_center_x = round((first_footprint.low_x + first_footprint.high_x) / 2)
	var/first_center_y = round((first_footprint.low_y + first_footprint.high_y) / 2)
	var/second_z = second_footprint.z_value
	var/second_low_x = second_footprint.low_x
	var/second_low_y = second_footprint.low_y
	var/second_high_x = second_footprint.high_x
	var/second_high_y = second_footprint.high_y

	first_zone.clear_to_uninitialized_space(first_footprint)
	qdel(first_dock, force = TRUE)
	qdel(first_dock_secondary, force = TRUE)
	first_zone.release_slot(first_footprint)
	first_footprint = null

	if(first_zone.used_slot_count() != 1)
		TEST_FAIL("After releasing one of two tenants the zone reports [first_zone.used_slot_count()] occupied slots, expected 1")
	if(first_zone.tenant_class != flat_class)
		TEST_FAIL("Releasing one tenant cleared the zone's tenant class while a co-tenant was still resident")
	if(!first_zone.taken)
		TEST_FAIL("Releasing one tenant marked the whole zone free while a co-tenant was still resident - the next encounter would build on top of it")

	if(second_footprint.low_x != second_low_x || second_footprint.low_y != second_low_y \
		|| second_footprint.high_x != second_high_x || second_footprint.high_y != second_high_y \
		|| second_footprint.z_value != second_z)
		TEST_FAIL("The surviving tenant's footprint moved during the neighbour's teardown: now [second_footprint.describe()]")

	second_center = second_footprint.get_center_turf()
	if(!second_center)
		TEST_FAIL("The surviving tenant's footprint no longer resolves a centre turf")
		return
	if(get_area(second_center) != second_area)
		TEST_FAIL("The surviving tenant's ground was repainted into [get_area(second_center)] during the neighbour's teardown - clear_reservation() widened past the departing slot")
	if(!(second_center.flags_1 & INITIALIZED_1))
		TEST_FAIL("The surviving tenant's turfs were reset to uninitialized space during the neighbour's teardown - players could no longer build or throw on them")
	if(QDELETED(second_dock) || QDELETED(second_dock_secondary))
		TEST_FAIL("The surviving tenant's reserve berths were deleted by the neighbour's teardown")
	if(get_turf(second_dock) != second_dock_turf)
		TEST_FAIL("The surviving tenant's reserve berth moved during the neighbour's teardown")

	// The released slot really did go back
	var/turf/released_center = locate(first_center_x, first_center_y, second_z)
	if(released_center && (released_center.flags_1 & INITIALIZED_1))
		TEST_FAIL("The released slot's ground at ([released_center.x],[released_center.y]) is still initialized [released_center.type] - clear_to_uninitialized_space() did not cover the departing footprint")
	if(released_center && get_area(released_center) == first_area)
		TEST_FAIL("The released slot's ground is still in the departed tenant's area instance")

	// ---- 4. Last tenant out resets the level and frees every slot ---------------------

	second_zone.clear_to_uninitialized_space(second_footprint)
	qdel(second_dock, force = TRUE)
	qdel(second_dock_secondary, force = TRUE)
	second_zone.release_slot(second_footprint)
	second_footprint = null

	if(second_zone.used_slot_count())
		TEST_FAIL("After the last tenant left, the zone still reports [second_zone.used_slot_count()] occupied slots")
	if(second_zone.taken)
		TEST_FAIL("After the last tenant left, the zone is still marked taken and would never be recycled")
	if(!isnull(second_zone.tenant_class))
		TEST_FAIL("After the last tenant left, the zone kept tenant class '[second_zone.tenant_class]' - it could never be re-dealt to another class")
	if(length(level.footprints))
		TEST_FAIL("[length(level.footprints)] footprint(s) are still registered on the level after every tenant left")
	if(level.cordon_placed)
		TEST_FAIL("The level still reports its cordon as placed after a full reset - the next occupant's slots would never be walled off")
	if(level.low_x != 1 || level.low_y != 1 || level.high_x != world.maxx || level.high_y != world.maxy)
		TEST_FAIL("The level's bounds did not go back to the whole z after every tenant left: ([level.low_x],[level.low_y])-([level.high_x],[level.high_y])")

	if(gutter_turf)
		var/turf/reset_gutter = locate(gutter_turf.x, gutter_turf.y, gutter_turf.z)
		if(istype(reset_gutter, /turf/cordon))
			TEST_FAIL("The cordon band survived the last tenant's teardown - a recycled zone would hand its next occupant a level walled in half")

	var/turf/reset_center = locate(second_low_x + 1, second_low_y + 1, second_z)
	if(reset_center && (reset_center.flags_1 & INITIALIZED_1))
		TEST_FAIL("The last tenant's ground at ([reset_center.x],[reset_center.y]) is still initialized [reset_center.type] after teardown")

	test_planet_class_packing()

/**
 * Terrain planets pack four to a level, and their BIOMES may differ.
 *
 * Every terrain planet takes the same tenant class (MAP_TENANT_CLASS_PLANET, "planet"), so a
 * lava planet and an ice planet share a z-level. The thing that used to forbid that is
 * ZTRAIT_BASETURF: it is published once per z-level and it is what a dug-up patch of ground,
 * a blown-out ruin floor or a scraped-away wall bottoms out into, so on a mixed level one of
 * the two crews would find the other planet's ground under every hole they made.
 *
 * The fix is that the footprint, not the level, is the authority. This test drives that
 * chain end to end:
 *
 *   /datum/map_footprint.baseturf   (stamped by build_planet)
 *     -> footprint_baseturf_for_turf(turf)
 *       -> /turf/ChangeTurf(/turf/baseturf_bottom)   [voidcrew/edits/turf.dm]
 *
 * and asserts that the level's own ZTRAIT_BASETURF - deliberately set to a THIRD turf type
 * here - is used only where no footprint answers, i.e. in the cordon gutter.
 *
 * Driven through the slot register directly rather than through build_planet(): a real planet
 * build generates terrain, seeds ruins and runs rivers, which is minutes of work per planet
 * and has no business inside a unit test. What is under test here is allocation and ground
 * resolution.
 */
/datum/unit_test/voidcrew_map_packing/proc/test_planet_class_packing()
	var/slot_side = 123 // MAP_SLOT_SIDE (= PLANET_MIN_SIZE)
	var/lattice_capacity = 4 // MAP_SLOT_LATTICE_CAPACITY
	var/planet_class = "planet" // MAP_TENANT_CLASS_PLANET

	// Three distinct, cheap, unambiguous turf types standing in for two biomes' ground and
	// for whatever the level happens to publish. Real biome grounds (basalt, snow, dirt)
	// would drag their smoothing and weather behaviour into a test about lookup order.
	var/turf/alpha_ground = /turf/open/floor/plating
	var/turf/beta_ground = /turf/open/floor/iron
	var/turf/level_ground = /turf/open/floor/wood

	// ---- 1. Packing preference: the next planet joins the first while there is room ----

	// Deliberately state-independent. This suite runs inside a live round whose roundstart
	// planets already hold planet-class slots - build_planet() claims MAP_TENANT_CLASS_PLANET
	// too, and the per-biome classes that used to keep a test's slots to itself are gone - so
	// "the planet pool starts empty" is not a fact this test may assume. What it CAN assert
	// is the invariant: while a planet-class zone has room, the next planet lands in it.
	var/datum/map_footprint/first_claim = SSovermap.claim_free_slot(planet_class, null, zone_name = "Map packing preference test")
	if(!first_claim)
		TEST_FAIL("A planet-class slot could not be claimed at all - map_slot_capacity_for_class() is not treating '[planet_class]' as a packed class")
		return
	var/datum/map_zone/preference_zone = first_claim.zone
	if(preference_zone.slot_capacity != lattice_capacity)
		TEST_FAIL("A planet-class map zone deals [preference_zone.slot_capacity] slots, expected [lattice_capacity] - terrain planets are still one to a z-level")
	var/free_after_first = preference_zone.first_free_slot_index()
	var/datum/map_footprint/second_claim = null
	if(free_after_first)
		second_claim = SSovermap.claim_free_slot(planet_class, null, zone_name = "Map packing preference test")
		if(second_claim && second_claim.zone != preference_zone)
			TEST_FAIL("find_free_slot() sent the next planet to a different zone while '[preference_zone.name]' still had slot [free_after_first] free - planets never pack")
	preference_zone.release_slot(first_claim)
	if(second_claim)
		second_claim.zone?.release_slot(second_claim)

	// ---- 2. A full lattice: four tenants, one z, four disjoint rectangles -------------

	// The zone is minted here rather than dealt from the pool, so the four tenants under
	// test are the only ones on their level whatever else the round is already holding.
	// Order matters: add_new_zlevel() sleeps, so the level is made BEFORE the zone exists
	// and no other claimant can be handed a slot of it behind our back.
	var/datum/space_level/planet_level = SSmapping.add_new_zlevel("Map packing test", list())
	var/datum/map_zone/planet_zone = SSovermap.create_map_zone("Map packing test")
	planet_zone.add_space_level(planet_level)

	var/list/planet_footprints = list()
	for(var/index in 1 to lattice_capacity)
		var/datum/map_footprint/claimed = planet_zone.claim_slot(planet_class, null)
		if(!claimed)
			TEST_FAIL("Planet slot [index] of [lattice_capacity] could not be claimed from a freshly minted zone - map_slot_capacity_for_class() is not treating '[planet_class]' as a packed class")
			break
		planet_footprints += claimed

	if(length(planet_footprints) != lattice_capacity)
		TEST_FAIL("Only [length(planet_footprints)] of [lattice_capacity] planet slots were dealt - the rest of this test cannot run")
		release_test_footprints(planet_footprints)
		return

	if(planet_zone.slot_capacity != lattice_capacity)
		TEST_FAIL("A planet-class map zone deals [planet_zone.slot_capacity] slots, expected [lattice_capacity] - terrain planets are still one to a z-level")
	if(planet_zone.used_slot_count() != lattice_capacity)
		TEST_FAIL("After [lattice_capacity] claims the zone reports [planet_zone.used_slot_count()] occupied slots")

	var/list/seen_slot_indices = list()
	for(var/datum/map_footprint/checked as anything in planet_footprints)
		if(checked.zone != planet_zone)
			TEST_FAIL("Planet tenants were split across map zones - find_free_slot() must prefer a partially-filled zone of the same class, or planets never pack")
		if(checked.z_value != planet_level.z_value)
			TEST_FAIL("Planet tenant in slot [checked.slot_index] landed on z[checked.z_value], expected z[planet_level.z_value]")
		if(seen_slot_indices[num2text(checked.slot_index)])
			TEST_FAIL("Slot [checked.slot_index] was handed out twice - two planets would build on the same rectangle")
		seen_slot_indices[num2text(checked.slot_index)] = TRUE
		if(checked.get_width() != slot_side || checked.get_height() != slot_side)
			TEST_FAIL("Planet slot [checked.slot_index] is [checked.get_width()]x[checked.get_height()], expected [slot_side]x[slot_side] - planet_size must be MAP_SLOT_SIDE, not 128")

	for(var/outer in 1 to length(planet_footprints))
		for(var/inner in (outer + 1) to length(planet_footprints))
			var/datum/map_footprint/first = planet_footprints[outer]
			var/datum/map_footprint/second = planet_footprints[inner]
			var/overlaps = first.low_x <= second.high_x && second.low_x <= first.high_x \
				&& first.low_y <= second.high_y && second.low_y <= first.high_y
			if(overlaps)
				TEST_FAIL("Planet footprints overlap: [first.describe()] and [second.describe()]")

	// ---- 3. Capacity is honoured: a fifth planet needs its own level ------------------

	if(planet_zone.first_free_slot_index())
		TEST_FAIL("A full planet zone still reports slot [planet_zone.first_free_slot_index()] free")
	if(planet_zone.has_free_slot(planet_class))
		TEST_FAIL("A full planet zone still answers has_free_slot() - a fifth planet would be dealt an occupied rectangle")
	var/datum/map_footprint/overflow_from_zone = planet_zone.claim_slot(planet_class, null)
	if(overflow_from_zone)
		TEST_FAIL("A full planet zone dealt slot [overflow_from_zone.slot_index] a second time - two planets would build on the same rectangle")
		planet_zone.release_slot(overflow_from_zone)

	var/datum/map_footprint/fifth_footprint = SSovermap.claim_free_slot(planet_class, null, zone_name = "Map packing test overflow")
	if(!fifth_footprint)
		TEST_FAIL("The fifth planet tenant could not be placed at all - claim_free_slot() must mint a new zone when the lattice is full")
	else if(fifth_footprint.zone == planet_zone)
		TEST_FAIL("The fifth planet tenant was dealt slot [fifth_footprint.slot_index] of a zone that already holds [lattice_capacity]")

	// ---- 4. Mixed-biome ground resolution ---------------------------------------------

	var/datum/map_footprint/alpha_footprint = planet_footprints[1]
	var/datum/map_footprint/beta_footprint = planet_footprints[2]
	var/planet_z = planet_level.z_value

	var/turf/alpha_probe = locate(alpha_footprint.low_x + 5, alpha_footprint.low_y + 5, planet_z)
	var/turf/beta_probe = locate(beta_footprint.low_x + 5, beta_footprint.low_y + 5, planet_z)
	if(!alpha_probe || !beta_probe)
		TEST_FAIL("Could not resolve a probe turf inside each planet footprint on z[planet_z]")
		release_test_footprints(planet_footprints)
		if(fifth_footprint)
			fifth_footprint.zone?.release_slot(fifth_footprint)
		return

	// A gutter turf: on the lattice, between two slots and inside neither. This is the only
	// place on a packed level where the z-level's ZTRAIT_BASETURF is still the answer.
	var/turf/gutter_probe = null
	if(alpha_footprint.low_y == beta_footprint.low_y)
		gutter_probe = locate(min(alpha_footprint.high_x, beta_footprint.high_x) + 1, alpha_footprint.low_y + 5, planet_z)

	// Negative control: with no ground stamped on any footprint the resolver must stay out
	// of the way entirely, or every flat encounter and player outpost in the game changes
	// behaviour the moment it is packed.
	if(!isnull(footprint_baseturf_for_turf(alpha_probe)))
		TEST_FAIL("footprint_baseturf_for_turf() answered '[footprint_baseturf_for_turf(alpha_probe)]' for a footprint with no ground of its own - a flat encounter's turfs must still bottom out through the z-level")

	alpha_footprint.baseturf = alpha_ground
	beta_footprint.baseturf = beta_ground
	var/previous_level_ground = planet_level.traits ? planet_level.traits[ZTRAIT_BASETURF] : null
	planet_level.set_trait(ZTRAIT_BASETURF, level_ground)

	if(footprint_baseturf_for_turf(alpha_probe) != alpha_ground)
		TEST_FAIL("footprint_baseturf_for_turf() returned '[footprint_baseturf_for_turf(alpha_probe)]' inside [alpha_footprint.describe()], expected '[alpha_ground]'")
	if(footprint_baseturf_for_turf(beta_probe) != beta_ground)
		TEST_FAIL("footprint_baseturf_for_turf() returned '[footprint_baseturf_for_turf(beta_probe)]' inside [beta_footprint.describe()], expected '[beta_ground]' - one planet is being handed its neighbour's ground")
	if(gutter_probe && !isnull(footprint_baseturf_for_turf(gutter_probe)))
		TEST_FAIL("footprint_baseturf_for_turf() claimed the cordon gutter turf at ([gutter_probe.x],[gutter_probe.y]) for a tenant - the rect test is leaking past the footprint edge")

	// The real chain: ChangeTurf resolving the /turf/baseturf_bottom sentinel. Probes are
	// initialized first because a level minted here is raw /turf/open/space/basic.
	var/list/probes_to_init = list()
	for(var/turf/probe as anything in list(alpha_probe, beta_probe, gutter_probe))
		if(probe && !(probe.flags_1 & INITIALIZED_1))
			probes_to_init += probe
	if(length(probes_to_init))
		SSatoms.InitializeAtoms(probes_to_init)

	var/turf/alpha_result = alpha_probe.ChangeTurf(/turf/baseturf_bottom)
	var/turf/beta_result = beta_probe.ChangeTurf(/turf/baseturf_bottom)
	if(alpha_result?.type != alpha_ground)
		TEST_FAIL("ChangeTurf(/turf/baseturf_bottom) inside [alpha_footprint.describe()] produced [alpha_result?.type], expected [alpha_ground]. A crew digging here would surface the wrong biome's ground.")
	if(beta_result?.type != beta_ground)
		TEST_FAIL("ChangeTurf(/turf/baseturf_bottom) inside [beta_footprint.describe()] produced [beta_result?.type], expected [beta_ground]. A crew digging here would surface the wrong biome's ground.")
	if(alpha_result?.type == level_ground || beta_result?.type == level_ground)
		TEST_FAIL("A packed planet's scrape resolved to the z-level's ZTRAIT_BASETURF ([level_ground]) instead of its own footprint's ground - the footprint is not the authority")

	if(gutter_probe)
		var/turf/gutter_result = gutter_probe.ChangeTurf(/turf/baseturf_bottom)
		if(gutter_result?.type != level_ground)
			TEST_FAIL("ChangeTurf(/turf/baseturf_bottom) outside every footprint produced [gutter_result?.type], expected the z-level's ZTRAIT_BASETURF [level_ground] - the level fallback is broken, which is what every unpacked level in the game relies on")
		gutter_result?.ChangeTurf(/turf/open/space)

	// Put the probes and the level trait back before the level is handed on.
	alpha_result?.ChangeTurf(/turf/open/space)
	beta_result?.ChangeTurf(/turf/open/space)
	planet_level.set_trait(ZTRAIT_BASETURF, previous_level_ground)

	// ---- 5. Releasing every tenant hands the level back clean -------------------------

	// Cached before the release: the footprints are qdel'd below and must not be read after.
	var/alpha_probe_x = alpha_probe.x
	var/alpha_probe_y = alpha_probe.y

	release_test_footprints(planet_footprints)
	if(fifth_footprint)
		fifth_footprint.zone?.release_slot(fifth_footprint)

	if(planet_zone.used_slot_count())
		TEST_FAIL("After every planet tenant left, the zone still reports [planet_zone.used_slot_count()] occupied slots")
	if(planet_zone.taken)
		TEST_FAIL("After every planet tenant left, the zone is still marked taken and would never be recycled")
	if(!isnull(planet_zone.tenant_class))
		TEST_FAIL("After every planet tenant left, the zone kept tenant class '[planet_zone.tenant_class]' - it could never be re-dealt to another class")
	if(length(planet_level.footprints))
		TEST_FAIL("[length(planet_level.footprints)] footprint(s) are still registered on the planet level after every tenant left")
	if(planet_level.low_x != 1 || planet_level.low_y != 1 || planet_level.high_x != world.maxx || planet_level.high_y != world.maxy)
		TEST_FAIL("The planet level's bounds did not go back to the whole z after every tenant left: ([planet_level.low_x],[planet_level.low_y])-([planet_level.high_x],[planet_level.high_y])")

	// The released footprints are gone, so nothing on the level can name a ground any more.
	// A stale answer here means a recycled z-level would hand its next occupant the previous
	// planet's ground under every hole - the exact bug the level trait used to have.
	var/turf/released_probe = locate(alpha_probe_x, alpha_probe_y, planet_z)
	if(released_probe && !isnull(footprint_baseturf_for_turf(released_probe)))
		TEST_FAIL("footprint_baseturf_for_turf() still answers '[footprint_baseturf_for_turf(released_probe)]' on a level with no tenants left - a released slot is still naming its ground")

/// Hands a list of claimed slots back, tolerating nulls. No turf teardown: the planet
/// section paints nothing beyond three probe turfs, which it puts back itself.
/datum/unit_test/voidcrew_map_packing/proc/release_test_footprints(list/footprints)
	for(var/datum/map_footprint/claimed as anything in footprints)
		if(claimed)
			claimed.zone?.release_slot(claimed)
	footprints.Cut()

/**
 * A slot's ruin region must not touch its own docking berths.
 *
 * A 123x123 slot spends its bottom rows on TWO 56x40 reserve berths laid side by side, so
 * the space actually free for a ruin template is 119x74 - not the 123x123 the slot looks
 * like. The placer used to measure the template DOWN from the slot's top edge
 * (`footprint.high_y - height - 6`), which puts any template 73 rows or taller straight on
 * top of both berths, and the class gate happily accepted templates up to 111 tall. A ship
 * then materialises inside ruin walls, or its berth is buried under one.
 *
 * Latent until space ruins started taking lattice slots, which is what this test guards.
 * Berth rectangles come from the REAL ports built by spawn_dynamic_encounter() rather than
 * from restated offsets, so the two cannot drift apart.
 */
/datum/unit_test/voidcrew_map_packing/proc/test_ruin_slot_placement(datum/map_footprint/footprint, obj/docking_port/stationary/primary_dock, obj/docking_port/stationary/secondary_dock)
	if(!footprint || !primary_dock || !secondary_dock)
		TEST_FAIL("Ruin placement cannot be checked: the test encounter is missing its footprint or a berth")
		return

	var/list/region = SSovermap.slot_build_region(footprint)
	if(length(region) != 4)
		TEST_FAIL("slot_build_region() returned [length(region)] values, expected list(min_x, min_y, max_x, max_y)")
		return
	var/region_min_x = region[1]
	var/region_min_y = region[2]
	var/region_max_x = region[3]
	var/region_max_y = region[4]
	var/region_width = region_max_x - region_min_x + 1
	var/region_height = region_max_y - region_min_y + 1

	if(region_width < 1 || region_height < 1)
		TEST_FAIL("slot_build_region() of [footprint.describe()] is [region_width]x[region_height] - no ruin could ever be placed in a slot")
		return

	// Inside its own slot, in both directions.
	if(!footprint.contains_coords(region_min_x, region_min_y, footprint.z_value) \
		|| !footprint.contains_coords(region_max_x, region_max_y, footprint.z_value))
		TEST_FAIL("The ruin region ([region_min_x],[region_min_y])-([region_max_x],[region_max_y]) escapes its own footprint [footprint.describe()] - a ruin would be stamped into the cordon gutter or onto the neighbour")

	// The property this test exists for.
	for(var/obj/docking_port/stationary/berth as anything in list(primary_dock, secondary_dock))
		var/list/berth_rect = berth.return_coords()
		var/berth_low_x = min(berth_rect[1], berth_rect[3])
		var/berth_low_y = min(berth_rect[2], berth_rect[4])
		var/berth_high_x = max(berth_rect[1], berth_rect[3])
		var/berth_high_y = max(berth_rect[2], berth_rect[4])
		var/overlaps = region_min_x <= berth_high_x && berth_low_x <= region_max_x \
			&& region_min_y <= berth_high_y && berth_low_y <= region_max_y
		if(overlaps)
			TEST_FAIL("The ruin region ([region_min_x],[region_min_y])-([region_max_x],[region_max_y]) overlaps the reserve berth at \
				([berth_low_x],[berth_low_y])-([berth_high_x],[berth_high_y]). Every ruin tall enough to reach down there is stamped over \
				a docking berth, and arriving ships materialise inside its walls.")

	// The class gate and the placement arithmetic must agree: no template may be classified
	// as fitting a slot and then fail to place, and none that fits may be sent to a whole
	// z-level it does not need. Both directions are checked against the SAME region above.
	var/accepted = 0
	var/widest = 0
	var/tallest = 0
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/ruin = SSmapping.space_ruins_templates[template_name]
		if(!istype(ruin) || !ruin.width || !ruin.height)
			continue
		var/fits_gate = SSovermap.ruin_fits_in_slot(ruin)
		var/fits_region = ruin.width <= region_width && ruin.height <= region_height
		if(fits_gate != fits_region)
			TEST_FAIL("ruin_fits_in_slot() says [fits_gate ? "yes" : "no"] for '[template_name]' ([ruin.width]x[ruin.height]) but the \
				[region_width]x[region_height] placement region says [fits_region ? "yes" : "no"]. A template classified FLAT that cannot be \
				placed loses its ruin silently; one classified SOLO that would have fitted burns a whole z-level.")
		if(!fits_gate)
			continue
		accepted++
		widest = max(widest, ruin.width)
		tallest = max(tallest, ruin.height)

	if(!accepted)
		TEST_FAIL("Not one space ruin template fits a lattice slot's [region_width]x[region_height] ruin region - every ruin would take a whole z-level and packing buys nothing")
		return

	// The worst case the gate lets through, placed at the region's bottom-left corner (the
	// closest a template can legally get to the berths), still has to clear them.
	var/worst_high_x = region_min_x + widest - 1
	var/worst_high_y = region_min_y + tallest - 1
	if(worst_high_x > region_max_x || worst_high_y > region_max_y)
		TEST_FAIL("The largest accepted template ([widest]x[tallest]) does not fit the [region_width]x[region_height] region it was accepted for")
	for(var/obj/docking_port/stationary/berth as anything in list(primary_dock, secondary_dock))
		var/list/berth_rect = berth.return_coords()
		var/berth_low_x = min(berth_rect[1], berth_rect[3])
		var/berth_low_y = min(berth_rect[2], berth_rect[4])
		var/berth_high_x = max(berth_rect[1], berth_rect[3])
		var/berth_high_y = max(berth_rect[2], berth_rect[4])
		var/overlaps = region_min_x <= berth_high_x && berth_low_x <= worst_high_x \
			&& region_min_y <= berth_high_y && berth_low_y <= worst_high_y
		if(overlaps)
			TEST_FAIL("The largest template the slot gate accepts ([widest]x[tallest]) placed at ([region_min_x],[region_min_y]) covers the \
				reserve berth at ([berth_low_x],[berth_low_y])-([berth_high_x],[berth_high_y])")

/**
 * # Packed ruin areas must be per-load instances
 *
 * /area/ruin carries UNIQUE_AREA (code/game/area/areas/ruins/_ruins.dm), so the map loader
 * hands every load of a template the SAME area instance unless told otherwise. That was
 * harmless while a space ruin owned a whole z-level. Under packing, two co-tenants that
 * roll the same template share one area straddling BOTH of their footprints, and every
 * area-scoped system - teardown, lighting, ambience, power, get_area_turfs() - then treats
 * the two sites as one place. get_area_turfs() is the worst of them: it collapses an area
 * INSTANCE argument back to its typepath, so even holding the right instance returns the
 * neighbour's ground.
 *
 * reader.dm already knows how to instance per load; the window is armed by
 * planet_ruin_area_instancing_begin()/_end(), and this asserts spawn_dynamic_encounter()
 * arms it around its own ruin stamp. Drives the real path with the real loader.
 */
/datum/unit_test/voidcrew_ruin_area_instancing

/datum/unit_test/voidcrew_ruin_area_instancing/Run()
	// The cheapest template that still brings an /area/ruin with it. Chosen by size rather
	// than by name so this keeps working when the ruin pool changes.
	var/datum/map_template/ruin/space/template = null
	var/smallest = 0
	for(var/template_name in SSmapping.space_ruins_templates)
		var/datum/map_template/ruin/space/candidate = SSmapping.space_ruins_templates[template_name]
		if(!istype(candidate) || !candidate.width || !candidate.height)
			continue
		if(!SSovermap.ruin_fits_in_slot(candidate))
			continue
		var/area_size = candidate.width * candidate.height
		if(!template || area_size < smallest)
			template = candidate
			smallest = area_size
	if(!template)
		TEST_FAIL("No space ruin template fits a lattice slot, so per-load area instancing cannot be tested")
		return

	var/list/first_values = SSovermap.spawn_dynamic_encounter(null, TRUE, ruin_type = template)
	var/list/second_values = SSovermap.spawn_dynamic_encounter(null, TRUE, ruin_type = template)
	if(length(first_values) < 5 || length(second_values) < 5)
		TEST_FAIL("spawn_dynamic_encounter() did not report where it stamped the ruin - per-load area instancing cannot be tested")
		release_ruin_encounter(first_values)
		release_ruin_encounter(second_values)
		return

	var/datum/map_footprint/first_footprint = first_values[4]
	var/datum/map_footprint/second_footprint = second_values[4]
	var/turf/first_ruin_corner = first_values[5]
	var/turf/second_ruin_corner = second_values[5]

	if(!first_ruin_corner || !second_ruin_corner)
		TEST_FAIL("One of the two encounters was built without its ruin ('[template.name]', [template.width]x[template.height]) - it passed ruin_fits_in_slot() but the placer refused it")
		release_ruin_encounter(first_values)
		release_ruin_encounter(second_values)
		return

	if(first_footprint.z_value != second_footprint.z_value)
		TEST_FAIL("The two ruin-bearing encounters landed on different z-levels (z[first_footprint.z_value] and z[second_footprint.z_value]) - they are not packing, so the shared-area case is untested")

	var/list/first_areas = ruin_areas_at(first_ruin_corner, template)
	var/list/second_areas = ruin_areas_at(second_ruin_corner, template)

	if(!length(first_areas) || !length(second_areas))
		TEST_FAIL("Template '[template.name]' brought no /area/ruin instance with it, so this test is not guarding anything. Point it at a template that does.")
		release_ruin_encounter(first_values)
		release_ruin_encounter(second_values)
		return

	for(var/area/ruin/shared as anything in first_areas)
		if(!(shared in second_areas))
			continue
		TEST_FAIL("Both copies of '[template.name]' were loaded into the SAME [shared.type] instance, straddling [first_footprint.describe()] and \
			[second_footprint.describe()]. Area-scoped teardown, lighting, ambience and power now conflate the two sites - \
			spawn_dynamic_encounter() must wrap its ruin load in planet_ruin_area_instancing_begin()/_end().")

	// An instanced area must not have replaced the type's singleton: the next loader to ask
	// for it (a station ruin, a planet, another encounter) would be handed this one's copy.
	for(var/area/ruin/instanced as anything in (first_areas + second_areas))
		if(!(instanced.area_flags & UNIQUE_AREA))
			continue
		if(GLOB.areas_by_type[instanced.type] == instanced)
			continue
		TEST_FAIL("[instanced.type] kept UNIQUE_AREA but is not the registered singleton - new_planet_ruin_area() must strip the flag from the instance it mints")

	test_packed_ruin_teardown_isolation(first_values, second_values, template)

	release_ruin_encounter(first_values)
	release_ruin_encounter(second_values)

/**
 * Tearing one packed ruin down must not touch the ruin next door.
 *
 * This is property 2 of the packing suite (a departing tenant leaves its neighbour's
 * ground alone) applied to the case that actually has something to lose. A flat encounter
 * owns bare space; a ruin owns walls, machinery and its own /area/ruin instances, and both
 * of the ways a teardown can widen past its slot - clear_reservation()/
 * clear_to_uninitialized_space() defaulting to the whole level, and an area instance shared
 * between the two loads - bite here and only here.
 *
 * The teardown runs the SAME sequence /obj/structure/overmap/space_ruin/remove_mapzone()
 * does, in the same order: ports first (while the footprint still knows where it is), then
 * the ground, then the slot.
 */
/datum/unit_test/voidcrew_ruin_area_instancing/proc/test_packed_ruin_teardown_isolation(list/first_values, list/second_values, datum/map_template/ruin/space/template)
	var/datum/map_zone/first_zone = first_values[1]
	var/datum/map_footprint/first_footprint = first_values[4]
	var/datum/map_footprint/second_footprint = second_values[4]
	var/turf/second_ruin_corner = second_values[5]
	if(!first_zone || !first_footprint || !second_footprint || !second_ruin_corner)
		return
	if(first_footprint.z_value != second_footprint.z_value)
		return // already reported; nothing shared to test

	// Snapshot the survivor's ruin: turf type and area instance, tile by tile.
	var/turf/second_top_right = locate(second_ruin_corner.x + template.width - 1, second_ruin_corner.y + template.height - 1, second_ruin_corner.z)
	if(!second_top_right)
		return
	var/list/turf/survivor_turfs = block(second_ruin_corner, second_top_right)
	var/list/expected_types = list()
	var/list/expected_areas = list()
	for(var/turf/tile as anything in survivor_turfs)
		expected_types[tile] = tile.type
		expected_areas[tile] = get_area(tile)

	// The real teardown sequence, minus the overmap object.
	for(var/index in 2 to 3)
		var/obj/docking_port/stationary/berth = first_values[index]
		if(berth)
			qdel(berth, force = TRUE)
	first_values[2] = null
	first_values[3] = null
	reap_footprint_docking_ports(first_footprint)
	first_zone.clear_reservation(FALSE, first_footprint)
	first_zone.release_slot(first_footprint)
	first_values[4] = null

	if(first_zone.used_slot_count() != 1)
		TEST_FAIL("After tearing one of two packed ruins down the zone reports [first_zone.used_slot_count()] occupied slots, expected 1")

	var/changed_turfs = 0
	var/changed_areas = 0
	var/turf/first_changed
	for(var/turf/tile as anything in survivor_turfs)
		// A raw turf swap retargets every reference onto the replacement, so re-resolve by
		// coordinate rather than trusting the cached ref to still be the same object.
		var/turf/current = locate(tile.x, tile.y, tile.z)
		if(!current || current.type != expected_types[tile])
			changed_turfs++
			if(!first_changed)
				first_changed = current || tile
			continue
		if(get_area(current) != expected_areas[tile])
			changed_areas++
			if(!first_changed)
				first_changed = current

	if(changed_turfs || changed_areas)
		TEST_FAIL("Tearing down the ruin in [first_footprint ? first_footprint.describe() : "slot 1"] changed [changed_turfs] turf(s) and \
			[changed_areas] area assignment(s) inside the NEIGHBOUR's ruin at [second_footprint.describe()] \
			(first at [first_changed ? "([first_changed.x],[first_changed.y],[first_changed.z])" : "unknown"]). \
			The teardown widened past the departing slot, or both loads shared one area instance.")

/// Every distinct /area/ruin instance inside a loaded template's bounding box.
/datum/unit_test/voidcrew_ruin_area_instancing/proc/ruin_areas_at(turf/bottom_left, datum/map_template/ruin/space/template)
	. = list()
	if(!bottom_left || !template)
		return
	var/turf/top_right = locate(bottom_left.x + template.width - 1, bottom_left.y + template.height - 1, bottom_left.z)
	if(!top_right)
		return
	for(var/turf/tile as anything in block(bottom_left, top_right))
		var/area/tile_area = get_area(tile)
		if(!istype(tile_area, /area/ruin))
			continue
		. |= tile_area

/// Tears one spawn_dynamic_encounter() result back down: berths by force (a non-forced
/// qdel on a docking port is a no-op), then the ground, then the slot.
/datum/unit_test/voidcrew_ruin_area_instancing/proc/release_ruin_encounter(list/encounter_values)
	if(length(encounter_values) < 4)
		return
	var/datum/map_zone/zone = encounter_values[1]
	var/datum/map_footprint/footprint = encounter_values[4]
	for(var/index in 2 to 3)
		var/obj/docking_port/stationary/berth = encounter_values[index]
		if(berth)
			qdel(berth, force = TRUE)
	if(!zone || !footprint)
		// Already released by the isolation test. Emphatically do NOT fall through with a
		// null footprint: clear_reservation(null) means "the whole level", which would wipe
		// the co-tenant this suite spent its whole run proving is untouchable.
		return
	reap_footprint_docking_ports(footprint)
	zone.clear_reservation(FALSE, footprint)
	zone.release_slot(footprint)

/**
 * # world.maxz ceiling
 *
 * BYOND never frees a z-level: every one ever minted keeps its full 255x255 turf plane for
 * the rest of the round - ~49 MB bare - and until this ceiling existed nothing in the tree
 * limited how many could be made. A round that churned encounters simply climbed until the
 * 32-bit wall killed it.
 *
 * The contract this asserts:
 *
 *  1. The ceiling is disableable (0 = no limit), because a host with the memory should be
 *     able to say so.
 *  2. At the ceiling, claim_free_slot() stops dealing rather than minting a new map zone -
 *     and world.maxz does not move.
 *  3. The refusal does not latch: raise the ceiling and the pool deals again immediately.
 *     A sticky refusal would be worse than no ceiling at all, since nothing would ever
 *     chart again for the rest of the round.
 *
 * Literals rather than defines - see the header of this file.
 */
/datum/unit_test/voidcrew_map_z_ceiling

/datum/unit_test/voidcrew_map_z_ceiling/Run()
	var/flat_class = "flat" // MAP_TENANT_CLASS_FLAT
	var/lattice_capacity = 4 // MAP_SLOT_LATTICE_CAPACITY
	var/original_ceiling = CONFIG_GET(number/max_z_levels)
	var/starting_maxz = world.maxz

	// ---- 1. Disableable -------------------------------------------------------------
	CONFIG_SET(number/max_z_levels, 0)
	if(SSmapping.at_z_level_ceiling())
		TEST_FAIL("at_z_level_ceiling() answered TRUE with MAX_Z_LEVELS set to 0. The ceiling has to be disableable, or a host with the memory for more levels cannot say so.")

	// ---- 2. Sitting exactly on it -----------------------------------------------------
	CONFIG_SET(number/max_z_levels, starting_maxz)
	if(!SSmapping.at_z_level_ceiling())
		TEST_FAIL("at_z_level_ceiling() answered FALSE with MAX_Z_LEVELS == world.maxz ([starting_maxz]) - the cap is not being enforced at all")
		CONFIG_SET(number/max_z_levels, original_ceiling)
		return

	var/list/claimed = list()
	var/refused = FALSE
	// Every zone deals at most `lattice_capacity` slots, so draining the whole pool takes
	// at most that many claims per zone. The slack covers a zone minted mid-test.
	var/attempt_budget = (length(SSovermap.map_zones) * lattice_capacity) + 8
	for(var/attempt in 1 to attempt_budget)
		var/datum/map_footprint/footprint = SSovermap.claim_free_slot(flat_class, null, zone_name = "Z ceiling test")
		if(isnull(footprint))
			refused = TRUE
			break
		claimed += footprint

	if(!refused)
		TEST_FAIL("claim_free_slot() kept dealing slots for all [attempt_budget] attempts with world.maxz already at its ceiling - it is still minting map zones past the cap")
	if(world.maxz != starting_maxz)
		TEST_FAIL("world.maxz grew from [starting_maxz] to [world.maxz] while sitting on the configured ceiling. A z-level was minted past the cap and can never be freed again.")

	for(var/datum/map_footprint/held as anything in claimed)
		held.zone?.release_slot(held)
	claimed.Cut()

	// ---- 3. Not sticky ----------------------------------------------------------------
	CONFIG_SET(number/max_z_levels, world.maxz + lattice_capacity)
	if(SSmapping.at_z_level_ceiling())
		TEST_FAIL("at_z_level_ceiling() still answers TRUE after the ceiling was raised above world.maxz")
	var/datum/map_footprint/after_raise = SSovermap.claim_free_slot(flat_class, null, zone_name = "Z ceiling test")
	if(isnull(after_raise))
		TEST_FAIL("claim_free_slot() refuses even with headroom above world.maxz - the ceiling refusal is latching, and nothing would ever be charted again")
	else
		after_raise.zone?.release_slot(after_raise)

	CONFIG_SET(number/max_z_levels, original_ceiling)

/**
 * # Population-scaled z ceiling
 *
 * The flat ceiling was written for a 40-player round. A 118-player one found it sitting
 * comfortably ABOVE the actual memory wall: the levels were inside budget and the server
 * died anyway, because everything that is not turf plane - mobs, atoms, per-client
 * rendering state - scales with pop and the ceiling did not. effective_z_ceiling() takes a
 * level off per max_z_levels_pop_scale_per clients past max_z_levels_pop_scale_start.
 *
 * The curve is pure arithmetic over four config entries, so it is asserted directly rather
 * than by driving allocations - the allocation side is already covered above. `pop` is an
 * argument on the proc precisely so this can drive the whole curve with nobody connected.
 *
 * Also covers z_headroom(), the multi-level form the colosseum needs: a caller that mints a
 * stack in a loop cannot ask a single-level predicate, which is how the venue used to take
 * two levels past a gate that had only cleared it for one.
 *
 * Every entry is saved and restored, as the ceiling test above does.
 */
/datum/unit_test/voidcrew_map_z_ceiling_pop_scaling

/datum/unit_test/voidcrew_map_z_ceiling_pop_scaling/Run()
	var/original_ceiling = CONFIG_GET(number/max_z_levels)
	var/original_start = CONFIG_GET(number/max_z_levels_pop_scale_start)
	var/original_per = CONFIG_GET(number/max_z_levels_pop_scale_per)
	var/original_floor = CONFIG_GET(number/max_z_levels_pop_floor)

	// ---- 1. The curve, with a floor ---------------------------------------------------
	CONFIG_SET(number/max_z_levels, 24)
	CONFIG_SET(number/max_z_levels_pop_scale_start, 80)
	CONFIG_SET(number/max_z_levels_pop_scale_per, 10)
	CONFIG_SET(number/max_z_levels_pop_floor, 18)

	check_ceiling(0, 24, "an empty server must get the configured ceiling untouched")
	check_ceiling(79, 24, "one client below the scaling start is still below it")
	check_ceiling(80, 24, "the start is the last population that pays nothing, not the first that pays")
	check_ceiling(89, 24, "a partial step must not round up - the ceiling steps on whole multiples of `per` only")
	check_ceiling(90, 23, "start + per is the first whole step and must cost exactly one level")
	check_ceiling(120, 20, "four steps past the start must cost four levels")
	check_ceiling(300, 18, "the floor has to hold - 22 steps would leave 2 levels and strand the whole round")

	// ---- 2. No floor -------------------------------------------------------------------
	CONFIG_SET(number/max_z_levels_pop_floor, 0)
	check_ceiling(300, 2, "with the floor disabled the scaling has to actually run down")
	// <= 0 is the "ceiling disabled" signal. Scaling past zero would turn the cap OFF at
	// exactly the population it exists for, which is worse than having no cap at all.
	var/runaway = SSmapping.effective_z_ceiling(100000)
	if(runaway <= 0)
		TEST_FAIL("effective_z_ceiling() returned [runaway] for an absurd population with the floor disabled. \
			Callers read <= 0 as 'no ceiling', so this silently removes the cap at the pop it was written for.")

	// ---- 3. Scaling disabled -----------------------------------------------------------
	CONFIG_SET(number/max_z_levels_pop_floor, 18)
	CONFIG_SET(number/max_z_levels_pop_scale_start, 0)
	check_ceiling(500, 24, "a start of 0 disables pop scaling and must hand back the configured ceiling")
	// The `per <= 0` half of that guard is unreachable from the config API - the entry has
	// min_val 1 and Set() clamps - so it is defence against a VV edit only. Assert the clamp
	// rather than a branch that cannot be reached, so a future min_val change is noticed.
	CONFIG_SET(number/max_z_levels_pop_scale_per, 0)
	if(CONFIG_GET(number/max_z_levels_pop_scale_per) < 1)
		TEST_FAIL("max_z_levels_pop_scale_per accepted 0. It is the divisor of the scaling step - a zero divides by zero every allocation.")
	CONFIG_SET(number/max_z_levels_pop_scale_per, 10)

	// ---- 4. The floor never raises the ceiling -----------------------------------------
	CONFIG_SET(number/max_z_levels_pop_scale_start, 80)
	CONFIG_SET(number/max_z_levels, 10)
	check_ceiling(0, 10, "a floor of 18 over a configured ceiling of 10 must not hand out 18 - the host meant the smaller number")

	// ---- 5. Disabled ceiling stays disabled --------------------------------------------
	CONFIG_SET(number/max_z_levels, 0)
	check_ceiling(500, 0, "MAX_Z_LEVELS 0 disables the ceiling; scaling a disabled ceiling must not invent one")

	// ---- 6. z_headroom -----------------------------------------------------------------
	// Scaling off, so the headroom arithmetic is exact regardless of who is connected.
	CONFIG_SET(number/max_z_levels_pop_scale_start, 0)
	var/starting_maxz = world.maxz
	CONFIG_SET(number/max_z_levels, starting_maxz + 2)
	if(!SSmapping.z_headroom(1))
		TEST_FAIL("z_headroom(1) refused with 2 levels of room ([starting_maxz] of [starting_maxz + 2])")
	if(!SSmapping.z_headroom(2))
		TEST_FAIL("z_headroom(2) refused with exactly 2 levels of room ([starting_maxz] of [starting_maxz + 2]) - a stack that fits exactly must be allowed")
	if(SSmapping.z_headroom(3))
		TEST_FAIL("z_headroom(3) allowed a stack that ends at [starting_maxz + 3], one past the ceiling of [starting_maxz + 2]. \
			This is the colosseum bypass: a multi-level mint that clears a gate it does not fit through.")

	CONFIG_SET(number/max_z_levels, 0)
	if(!SSmapping.z_headroom(50))
		TEST_FAIL("z_headroom() refused with the ceiling disabled (MAX_Z_LEVELS 0)")

	CONFIG_SET(number/max_z_levels, original_ceiling)
	CONFIG_SET(number/max_z_levels_pop_scale_start, original_start)
	CONFIG_SET(number/max_z_levels_pop_scale_per, original_per)
	CONFIG_SET(number/max_z_levels_pop_floor, original_floor)

/// One point on the effective_z_ceiling() curve, with the reason it matters in the failure.
/datum/unit_test/voidcrew_map_z_ceiling_pop_scaling/proc/check_ceiling(pop, expected, why)
	var/got = SSmapping.effective_z_ceiling(pop)
	if(got == expected)
		return
	TEST_FAIL("effective_z_ceiling([pop]) returned [got], expected [expected] (base [CONFIG_GET(number/max_z_levels)], \
		start [CONFIG_GET(number/max_z_levels_pop_scale_start)], per [CONFIG_GET(number/max_z_levels_pop_scale_per)], \
		floor [CONFIG_GET(number/max_z_levels_pop_floor)]): [why].")
