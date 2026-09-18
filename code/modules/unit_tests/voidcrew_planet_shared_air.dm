/**
 * # Shared planetary turf air
 *
 * A planetary_atmos turf starts on one shared mixture per gas string and only takes a
 * private /datum/gas_mixture/turf on its first write (voidcrew/edits/planetary_shared_air.dm).
 * These tests pin down the boundary: reads never allocate, every write does, LINDA
 * materializes both sides of a share, and gas is neither conjured nor lost at the seam.
 *
 * The whole 5x5 test room becomes /turf/open/misc/dirt/dry (OPENTURF_DEFAULT_ATMOS,
 * planetary), so every turf's neighbours are planetary too and nothing outside the room
 * can excite them. LINDA is driven by hand with process_cell(); Run() never sleeps.
 */
/datum/unit_test/voidcrew_planet_shared_air
	abstract_type = /datum/unit_test/voidcrew_planet_shared_air
	var/turf/open/center
	/// x, y, z, type per original room turf, so Destroy() can put the room back
	var/list/room_originals = list()

/datum/unit_test/voidcrew_planet_shared_air/New()
	..()
	if(!planetary_atmos_shared_mix_enabled())
		return
	center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	for(var/turf/spot in RANGE_TURFS(2, center))
		room_originals += list(list(spot.x, spot.y, spot.z, spot.type))
		spot.ChangeTurf(/turf/open/misc/dirt/dry, flags = CHANGETURF_IGNORE_AIR | CHANGETURF_RECALC_ADJACENT)
	center = locate(center.x, center.y, center.z)

/datum/unit_test/voidcrew_planet_shared_air/Destroy()
	for(var/list/record as anything in room_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.ChangeTurf(record[4], flags = CHANGETURF_IGNORE_AIR | CHANGETURF_RECALC_ADJACENT)
	for(var/list/record as anything in room_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.air_update_turf(update = FALSE, remove = FALSE)
	return ..()

/// The turf `dx`,`dy` from the room centre.
/datum/unit_test/voidcrew_planet_shared_air/proc/at_offset(dx, dy)
	return locate(center.x + dx, center.y + dy, center.z)

/// The shared mix every untouched OPENTURF_DEFAULT_ATMOS planetary turf holds.
/datum/unit_test/voidcrew_planet_shared_air/proc/shared_planet_mix()
	return GLOB.planetary_shared_turf_air[OPENTURF_DEFAULT_ATMOS]

/// Total moles of `gas` across the room.
/datum/unit_test/voidcrew_planet_shared_air/proc/room_moles(gas)
	var/total = 0
	for(var/turf/open/spot in RANGE_TURFS(2, center))
		var/list/gas_data = spot.air.gases[gas]
		if(gas_data)
			total += gas_data[MOLES]
	return total

/// Runs one LINDA cycle for `spot` the way SSair would, without waiting for the subsystem.
/datum/unit_test/voidcrew_planet_shared_air/proc/cycle(turf/open/spot)
	SSair.times_fired += 1
	spot.process_cell(SSair.times_fired)

/datum/unit_test/voidcrew_planet_shared_air/proc/room_is_pristine()
	if(!planetary_atmos_shared_mix_enabled())
		return TRUE
	var/datum/gas_mixture/shared = shared_planet_mix()
	for(var/turf/open/spot in RANGE_TURFS(2, center))
		if(spot.air != shared)
			return FALSE
	return TRUE

/**
 * Fresh planetary turfs own nothing: all 25 hold the one shared mix, every read-only
 * accessor reports the planet mix, and an idle LINDA cycle leaves them that way.
 */
/datum/unit_test/voidcrew_planet_shared_air/pristine

/datum/unit_test/voidcrew_planet_shared_air/pristine/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/gas_mixture/immutable/planetary/shared_turf/shared = shared_planet_mix()
	TEST_ASSERT(istype(shared), "no shared mix was registered for OPENTURF_DEFAULT_ATMOS")
	var/private_mixes = 0
	for(var/turf/open/spot in RANGE_TURFS(2, center))
		TEST_ASSERT(spot.planetary_atmos, "[spot] at [spot.x],[spot.y] is not planetary")
		if(spot.air != shared)
			private_mixes += 1
	TEST_ASSERT_EQUAL(private_mixes, 0, "generating 25 planetary turfs allocated private gas mixtures")
	TEST_ASSERT(center.has_shared_planet_air(), "the centre turf does not report the shared mix")
	TEST_ASSERT_EQUAL(center.return_air_readonly(), shared, "return_air_readonly() did not hand out the shared mix")
	TEST_ASSERT_EQUAL(center.return_analyzable_air(), shared, "return_analyzable_air() did not hand out the shared mix")
	TEST_ASSERT_EQUAL(center.air.temperature, T20C, "the shared mix is not at the gas string's temperature")
	TEST_ASSERT_EQUAL(center.air.gases[/datum/gas/oxygen][MOLES], 22, "the shared mix has the wrong oxygen")
	TEST_ASSERT_EQUAL(center.air.gases[/datum/gas/nitrogen][MOLES], 82, "the shared mix has the wrong nitrogen")
	TEST_ASSERT_EQUAL(center.air.return_pressure(), center.create_gas_mixture().return_pressure(), "the shared mix and a private mix from the same string disagree on pressure")
	TEST_ASSERT_EQUAL(length(center.atmos_adjacent_turfs), 4, "a turf on the shared mix lost its atmos adjacency")

	// Reads that must not allocate.
	var/datum/gas_mixture/copied = center.air.copy()
	TEST_ASSERT(istype(copied, /datum/gas_mixture/turf), "copy() of the shared mix is not a mutable turf mixture")
	TEST_ASSERT_EQUAL(copied.total_moles(), 104, "copy() of the shared mix lost gas")
	var/datum/gas_mixture/removed = center.air.remove(10)
	TEST_ASSERT(istype(removed, /datum/gas_mixture/turf), "remove() off the shared mix is not a mutable turf mixture")
	TEST_ASSERT_EQUAL(removed.total_moles(), 10, "remove() off the shared mix returned the wrong amount")
	TEST_ASSERT_EQUAL(shared.total_moles(), 104, "remove() drained the shared mix itself")
	TEST_ASSERT(room_is_pristine(), "reading the shared mix materialized something")

	// A LINDA cycle over identical neighbours shares nothing and allocates nothing.
	SSair.add_to_active(center)
	cycle(center)
	TEST_ASSERT(room_is_pristine(), "an idle LINDA cycle materialized a turf")
	TEST_ASSERT(!center.excited_group, "identical shared neighbours formed an excited group")
	TEST_ASSERT_EQUAL(shared.temperature, T20C, "the LINDA cycle changed the shared mix's temperature")

/**
 * The first write materializes exactly the turf written to, and a LINDA cycle then
 * materializes the neighbours it shares into (and only those) without touching the
 * shared mix or losing the gas.
 */
/datum/unit_test/voidcrew_planet_shared_air/write_and_share

/datum/unit_test/voidcrew_planet_shared_air/write_and_share/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/gas_mixture/shared = shared_planet_mix()
	var/datum/gas_mixture/plasma = new
	plasma.assert_gas(/datum/gas/plasma)
	plasma.gases[/datum/gas/plasma][MOLES] = 40
	plasma.temperature = T20C
	center.assume_air(plasma)

	TEST_ASSERT(!center.has_shared_planet_air(), "assume_air() did not materialize a private mix")
	TEST_ASSERT(istype(center.air, /datum/gas_mixture/turf), "the materialized mix is not a /datum/gas_mixture/turf")
	TEST_ASSERT_EQUAL(center.air.gases[/datum/gas/plasma][MOLES], 40, "assume_air() lost the plasma")
	TEST_ASSERT_EQUAL(center.air.gases[/datum/gas/oxygen][MOLES], 22, "materializing changed the oxygen")
	TEST_ASSERT_NULL(shared.gases[/datum/gas/plasma], "assume_air() wrote plasma into the shared mix")
	for(var/turf/open/spot in RANGE_TURFS(2, center) - center)
		TEST_ASSERT_EQUAL(spot.air, shared, "a write to the centre materialized [spot] at [spot.x],[spot.y]")

	// return_air() is a write handle and materializes; return_air_readonly() never does.
	var/turf/open/corner = at_offset(2, 2)
	TEST_ASSERT_EQUAL(corner.return_air_readonly(), shared, "return_air_readonly() materialized a corner turf")
	TEST_ASSERT(corner.return_air() != shared, "return_air() handed out the shared mix to a potential writer")
	TEST_ASSERT(!corner.has_shared_planet_air(), "return_air() did not leave a private mix behind")
	TEST_ASSERT_EQUAL(corner.air.total_moles(), 104, "return_air() materialized the wrong amount of gas")

	// One LINDA cycle: the centre shares with its four cardinal neighbours (materializing
	// them) and with the atmosphere above. Diagonals are never shared into.
	cycle(center)
	TEST_ASSERT(center.excited_group, "sharing plasma did not form an excited group")
	for(var/dir in GLOB.cardinals)
		var/turf/open/neighbour = get_step(center, dir)
		TEST_ASSERT(!neighbour.has_shared_planet_air(), "LINDA shared into [neighbour] at [neighbour.x],[neighbour.y] without materializing it")
		TEST_ASSERT(neighbour.air.gases[/datum/gas/plasma]?[MOLES] > 0, "LINDA share left no plasma on [neighbour] at [neighbour.x],[neighbour.y]")
		TEST_ASSERT_EQUAL(neighbour.excited_group, center.excited_group, "[neighbour] did not join the centre's excited group")
	for(var/dir in GLOB.diagonals)
		var/turf/open/diagonal = get_step(center, dir)
		if(diagonal == corner)
			continue
		TEST_ASSERT_EQUAL(diagonal.air, shared, "LINDA materialized diagonal [diagonal] at [diagonal.x],[diagonal.y]")
	TEST_ASSERT_NULL(shared.gases[/datum/gas/plasma], "a LINDA share leaked plasma into the shared mix")
	TEST_ASSERT_EQUAL(shared.total_moles(), 104, "a LINDA share changed the shared mix")
	// The atmosphere above took its 4/5 cut of the remaining difference; what is left is
	// spread over the five turfs and nothing else in the room has any.
	var/room_plasma = room_moles(/datum/gas/plasma)
	TEST_ASSERT(room_plasma > 0 && room_plasma < 40, "plasma after one cycle should be reduced but present, got [room_plasma]")
	TEST_ASSERT(center.air.gases[/datum/gas/plasma][MOLES] < 40, "the centre did not give any plasma away")

/**
 * A hotspot dropped on a pristine planetary turf burns off a private copy: the turf's
 * gas is removed and put back rather than removed from the shared mix and added on top,
 * and a fire on a materialized planetary turf ignites and burns.
 */
/datum/unit_test/voidcrew_planet_shared_air/fire

/datum/unit_test/voidcrew_planet_shared_air/fire/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/gas_mixture/shared = shared_planet_mix()

	// No fuel in the planet air: the hotspot samples, finds nothing, and dies. What it
	// sampled must have come back to the turf.
	var/turf/open/bare = at_offset(-2, -2)
	var/obj/effect/hotspot/dud = new(bare, CELL_VOLUME, 1000)
	TEST_ASSERT(!bare.has_shared_planet_air(), "a hotspot exposed the shared mix instead of a private copy")
	TEST_ASSERT_EQUAL(round(bare.air.total_moles(), 0.01), 104, "a hotspot on a pristine turf changed its gas total to [bare.air.total_moles()]")
	TEST_ASSERT_EQUAL(shared.total_moles(), 104, "a hotspot drained or filled the shared mix")
	TEST_ASSERT_EQUAL(shared.temperature, T20C, "a hotspot heated the shared mix")
	if(!QDELETED(dud))
		qdel(dud)

	// Fuel on a planetary turf: the fire lights and consumes it.
	center.atmos_spawn_air("[GAS_PLASMA]=30;TEMP=1000")
	TEST_ASSERT(!center.has_shared_planet_air(), "atmos_spawn_air() did not materialize the turf")
	var/plasma_before = center.air.gases[/datum/gas/plasma][MOLES]
	var/temperature_before = center.air.temperature
	center.hotspot_expose(1000, CELL_VOLUME)
	TEST_ASSERT(center.active_hotspot, "a hotspot did not light on a planetary turf holding plasma and oxygen")
	TEST_ASSERT(center.air.gases[/datum/gas/plasma][MOLES] < plasma_before, "the fire burnt no plasma")
	TEST_ASSERT(center.air.temperature > temperature_before, "the fire did not heat the turf")
	TEST_ASSERT_NULL(shared.gases[/datum/gas/plasma], "the fire wrote plasma into the shared mix")
	TEST_ASSERT_EQUAL(shared.temperature, T20C, "the fire heated the shared mix")
	if(center.active_hotspot)
		qdel(center.active_hotspot)

/**
 * Breathing on a pristine planetary turf gives the planet mix. Life() itself, without
 * a breath, reads the environment through the read-only accessor and allocates nothing.
 */
/datum/unit_test/voidcrew_planet_shared_air/breathing

/datum/unit_test/voidcrew_planet_shared_air/breathing/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/gas_mixture/shared = shared_planet_mix()
	var/mob/living/carbon/human/lab_rat = allocate(/mob/living/carbon/human/consistent, center)

	// Environment handling is read-only.
	ADD_TRAIT(lab_rat, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	lab_rat.Life(SSMOBS_DT, 1)
	TEST_ASSERT(room_is_pristine(), "a mob's Life() materialized the turf it stood on without breathing")
	REMOVE_TRAIT(lab_rat, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)

	// A breath comes off the planet mix. The turf now owns what is left of it.
	lab_rat.breathe(SSMOBS_DT, 1)
	TEST_ASSERT(!lab_rat.failed_last_breath && !lab_rat.has_alert(ALERT_NOT_ENOUGH_OXYGEN), "a human could not breathe the planet mix off a pristine planetary turf")
	TEST_ASSERT(!center.has_shared_planet_air(), "breathing did not materialize the turf")
	TEST_ASSERT_EQUAL(round(center.air.total_moles(), 0.01), 104, "breathing changed the turf's gas total to [center.air.total_moles()]")
	TEST_ASSERT_EQUAL(shared.total_moles(), 104, "breathing drained the shared mix")
	TEST_ASSERT_NULL(shared.gases[/datum/gas/carbon_dioxide], "exhaled CO2 ended up in the shared mix")
	for(var/turf/open/other in RANGE_TURFS(2, center) - center)
		TEST_ASSERT_EQUAL(other.air, shared, "breathing on the centre materialized [other] at [other.x],[other.y]")

/**
 * ChangeTurf keeps the invariants: inheriting air off a pristine turf yields a private
 * copy of the planet mix, a new planetary turf on the same mix stays shared, and
 * Assimilate_Air() over nothing but the same shared mix writes nothing.
 */
/datum/unit_test/voidcrew_planet_shared_air/change_turf

/datum/unit_test/voidcrew_planet_shared_air/change_turf/Run()
	if(!planetary_atmos_shared_mix_enabled())
		return
	var/datum/gas_mixture/shared = shared_planet_mix()

	// Pristine planetary -> station plating, inheriting air: a private copy of the planet mix.
	var/turf/open/became_plating = at_offset(-2, 2)
	became_plating = became_plating.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_INHERIT_AIR | CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT(!became_plating.planetary_atmos, "plating came out planetary")
	TEST_ASSERT(istype(became_plating.air, /datum/gas_mixture/turf), "inherited air is not a private turf mixture")
	TEST_ASSERT_EQUAL(became_plating.air.temperature, T20C, "inherited air lost the planet temperature")
	TEST_ASSERT_EQUAL(became_plating.air.total_moles(), 104, "inherited air lost gas")

	// Written planetary -> another planetary type, inheriting air: the write survives.
	var/turf/open/written = at_offset(2, -2)
	written.atmos_spawn_air("[GAS_PLASMA]=5;TEMP=293.15")
	written = written.ChangeTurf(/turf/open/misc/wasteland, flags = CHANGETURF_INHERIT_AIR | CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT(written.planetary_atmos, "the wasteland came out non-planetary")
	TEST_ASSERT(!written.has_shared_planet_air(), "inherited plasma was dropped for the shared mix")
	TEST_ASSERT_EQUAL(written.air.gases[/datum/gas/plasma]?[MOLES], 5, "inherited plasma was lost")

	// Pristine planetary -> same mix, inheriting air: nothing to write, still shared.
	var/turf/open/same_mix = at_offset(2, 2)
	same_mix = same_mix.ChangeTurf(/turf/open/misc/wasteland, flags = CHANGETURF_INHERIT_AIR | CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT_EQUAL(same_mix.air, shared, "inheriting the shared mix onto the same mix materialized it")

	// Wall -> planetary ground with pristine neighbours: Assimilate_Air() has nothing to do.
	var/turf/mined = at_offset(0, 0)
	mined.ChangeTurf(/turf/closed/wall, flags = CHANGETURF_RECALC_ADJACENT)
	var/turf/open/reopened = mined.ChangeTurf(/turf/open/misc/dirt/dry, flags = CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT_EQUAL(reopened.air, shared, "reopening ground among identical shared neighbours materialized it")
	for(var/dir in GLOB.cardinals)
		var/turf/open/neighbour = get_step(reopened, dir)
		TEST_ASSERT_EQUAL(neighbour.air, shared, "Assimilate_Air() materialized [neighbour] at [neighbour.x],[neighbour.y] for nothing")
	center = reopened

	// Airless plating opened among pristine planetary neighbours: every turf written to
	// takes a private mix and the average is what the old code produced.
	var/turf/open/plating = at_offset(0, 0)
	var/moles_before = 0
	for(var/dir in GLOB.cardinals)
		var/turf/open/party = get_step(plating, dir)
		moles_before += party.air.total_moles()
	plating = plating.ChangeTurf(/turf/open/floor/plating/airless, flags = CHANGETURF_RECALC_ADJACENT)
	TEST_ASSERT(istype(plating.air, /datum/gas_mixture/turf), "assimilated plating does not own its air")
	var/moles_after = plating.air.total_moles()
	for(var/dir in GLOB.cardinals)
		var/turf/open/neighbour = get_step(plating, dir)
		TEST_ASSERT(!neighbour.has_shared_planet_air(), "Assimilate_Air() wrote into the shared mix through [neighbour] at [neighbour.x],[neighbour.y]")
		TEST_ASSERT_EQUAL(round(neighbour.air.total_moles(), 0.01), round(moles_before / 5, 0.01), "[neighbour] at [neighbour.x],[neighbour.y] did not take the averaged gas")
		moles_after += neighbour.air.total_moles()
	// Four planet tiles plus one empty tile went in and nothing was invented.
	TEST_ASSERT_EQUAL(round(moles_after, 0.01), round(moles_before, 0.01), "Assimilate_Air() changed the gas total from [moles_before] to [moles_after]")
	TEST_ASSERT_EQUAL(shared.total_moles(), 104, "Assimilate_Air() changed the shared mix")
	TEST_ASSERT_EQUAL(shared.temperature, T20C, "Assimilate_Air() cooled the shared mix")
