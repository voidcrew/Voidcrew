/**
 * Outpost floors (voidcrew/modules/trade_floors/): the helpers every floors test uses.
 * Owner: P0 seams, frozen. Package tests live in voidcrew_outpost_floors_<package>.dm.
 *
 * Fork defines are included after the tests, so a test uses the literal value with a comment naming the define.
 * Tests pin other packages' outputs directly (floor.public_ground, floor.warrant_in_force, floor.entry_policy,
 * floor.hands, a host with founder_ckey set) and call a proc with the mobs already in place.
 *
 * A test floor is a plain box in a turf reservation of its own: a ring of hull, deck inside, a small landing at the
 * south wall with a three-tile lift alcove. It is not the shell map; a test that needs the consoles makes them.
 */

/// Parent of every outpost floors test. It never runs. Subtypes get the helpers below, and what they make is freed.
/datum/unit_test/voidcrew_outpost_floors
	abstract_type = /datum/unit_test/voidcrew_outpost_floors
	/// Floors made by test_floor(); each frees its own ground
	var/list/datum/outpost_floor/made_floors = list()
	/// Hosts made off the map, which allocate() cannot do
	var/list/obj/structure/overmap/made_hosts = list()
	/// Bare ground made by test_ground()
	var/list/datum/turf_reservation/made_ground = list()
	/// SSexplosions' queues as they were, put back afterwards (hold_blasts())
	var/list/saved_blast_queues

/datum/unit_test/voidcrew_outpost_floors/Destroy()
	if(saved_blast_queues)
		for(var/turf/thrown_turf as anything in SSexplosions.held_throwturf)
			thrown_turf.explosion_throw_details = null
		for(var/queue in saved_blast_queues)
			SSexplosions.vars[queue] = saved_blast_queues[queue]
		saved_blast_queues = null
	QDEL_LIST(made_floors)
	QDEL_LIST(made_hosts)
	QDEL_LIST(made_ground)
	return ..()

/// A trader outpost with no interior loaded: floors hang off it, the police datum exists, nothing walks about
/datum/unit_test/voidcrew_outpost_floors/proc/test_outpost(outpost_type = /obj/structure/overmap/trader_outpost/general)
	return allocate(outpost_type)

/**
 * A floor of `outpost` with ground: `width` by `height`, hull included. Its state is "owned" (OUTPOST_FLOOR_STATE_OWNED),
 * its setting "crew" (OUTPOST_FLOOR_ENTRY_CREW). With `with_host`, it has its player outpost object too, made off the
 * map as the real one is. Null, and the test failed, when the ground could not be reserved.
 */
/datum/unit_test/voidcrew_outpost_floors/proc/test_floor(obj/structure/overmap/trader_outpost/outpost, number = 1, width = 14, height = 12, with_host = FALSE)
	var/datum/turf_reservation/ground = SSmapping.request_turf_block_reservation(width, height, 1, requester = "outpost floors unit test")
	if(!ground)
		TEST_FAIL("No ground could be reserved for a test floor")
		return null
	var/datum/outpost_floor/floor = new(outpost, number)
	made_floors += floor
	if(length(outpost.floors) < number)
		outpost.floors.len = number
	outpost.floors[number] = floor
	floor.state = "owned" // OUTPOST_FLOOR_STATE_OWNED
	if(!floor.take_ground(ground))
		TEST_FAIL("A test floor would not take its ground")
		return null
	var/list/bounds = floor.bounds
	for(var/turf/tile as anything in block(bounds[1], bounds[2], bounds[5], bounds[3], bounds[4], bounds[5]))
		if(tile.x == bounds[1] || tile.y == bounds[2] || tile.x == bounds[3] || tile.y == bounds[4])
			tile.ChangeTurf(/turf/closed/wall/outpost_floor_hull)
		else
			tile.ChangeTurf(/turf/open/floor/plating/outpost_deck)
	// The landing: five wide and two deep at the middle of the south wall, the alcove its middle three tiles
	var/middle = round((bounds[1] + bounds[3]) / 2)
	floor.landing_bounds = list(middle - 2, bounds[2] + 1, middle + 2, bounds[2] + 2, bounds[5])
	floor.alcove_turfs = block(middle - 1, bounds[2] + 1, bounds[5], middle + 1, bounds[2] + 1, bounds[5])
	if(with_host)
		var/obj/structure/overmap/dynamic/player_outpost/floor/host = new(null)
		made_hosts += host
		host.floor = floor
		floor.host = host
	return floor

/// A bare turf reservation that is nobody's floor, freed with the test. Null, and the test failed, when none could be had.
/datum/unit_test/voidcrew_outpost_floors/proc/test_ground(width = 10, height = 10)
	var/datum/turf_reservation/ground = SSmapping.request_turf_block_reservation(width, height, 1, requester = "outpost floors unit test")
	if(!ground)
		TEST_FAIL("No bare ground could be reserved")
		return null
	made_ground += ground
	return ground

/// The tile of `floor` at `dx`, `dy` from its bottom left corner (0, 0 is hull; 1, 1 is the first deck tile)
/datum/unit_test/voidcrew_outpost_floors/proc/floor_tile(datum/outpost_floor/floor, dx, dy)
	return locate(floor.bounds[1] + dx, floor.bounds[2] + dy, floor.bounds[5])

/// A deck tile of `floor` north of the landing, `dx` tiles in from the west hull
/datum/unit_test/voidcrew_outpost_floors/proc/deck_tile(datum/outpost_floor/floor, dx = 2)
	return floor_tile(floor, dx, 5)

/// A person at `where`
/datum/unit_test/voidcrew_outpost_floors/proc/test_person(turf/where)
	return allocate(/mob/living/carbon/human/consistent, where)

/// Takes SSexplosions' queues aside so a blast set off in the test can be applied by hand. Put back in Destroy().
/datum/unit_test/voidcrew_outpost_floors/proc/hold_blasts()
	if(saved_blast_queues)
		return
	saved_blast_queues = list()
	for(var/queue in list("highturf", "medturf", "lowturf", "high_mov_atom", "med_mov_atom", "low_mov_atom", "flameturf", "held_throwturf"))
		saved_blast_queues[queue] = SSexplosions.vars[queue]
		SSexplosions.vars[queue] = list()

/// Every turf the last blast reached, before it is applied
/datum/unit_test/voidcrew_outpost_floors/proc/blasted_turfs()
	return SSexplosions.highturf + SSexplosions.medturf + SSexplosions.lowturf

/// Applies what the blast queued, turfs then movables, as SSexplosions.fire() does (throws are left out)
/datum/unit_test/voidcrew_outpost_floors/proc/apply_blast()
	for(var/list/pass in list(list("lowturf", EXPLODE_LIGHT), list("medturf", EXPLODE_HEAVY), list("highturf", EXPLODE_DEVASTATE)))
		var/list/queued = SSexplosions.vars[pass[1]]
		SSexplosions.vars[pass[1]] = list()
		var/severity = pass[2]
		for(var/turf/blasted as anything in queued)
			EX_ACT(blasted, severity)
	for(var/list/pass in list(list("high_mov_atom", EXPLODE_DEVASTATE), list("med_mov_atom", EXPLODE_HEAVY), list("low_mov_atom", EXPLODE_LIGHT)))
		var/list/queued = SSexplosions.vars[pass[1]]
		SSexplosions.vars[pass[1]] = list()
		var/severity = pass[2]
		for(var/atom/movable/blasted as anything in queued)
			if(!QDELETED(blasted))
				EX_ACT(blasted, severity)
