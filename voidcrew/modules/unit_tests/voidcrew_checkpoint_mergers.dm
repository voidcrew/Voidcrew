/**
 * Firelocks and stationary tanks group with the like atoms beside them. A rebuild moves them
 * one at a time, so after every visit a placed member must belong to a group of placed members
 * only, and the finished hull's groups must match what is adjacent to what.
 */
/datum/unit_test/voidcrew_checkpoints/merge_groups

/datum/unit_test/voidcrew_checkpoints/merge_groups/Run()
	var/obj/structure/overmap/dynamic/player_outpost/registry_test/home = allocate(__IMPLIED_TYPE__)
	home.shell_template = allocate(/datum/map_template/player_outpost/test_fixture)
	home.founder_ckey = "mergefounder"
	TEST_ASSERT(home.load_level(), "The outpost did not load")
	TEST_ASSERT_NULL(home.enable_ship_bays(), "The ship bay did not load")
	var/mob/living/carbon/human/captain = make_player(run_loc_floor_bottom_left, "mergecaptain")
	// Rows of firelocks and a bank of stationary tanks.
	var/datum/ship_checkpoint/snapshot = save_class(home, captain, /datum/map_template/shuttle/voidcrew/osprey)
	TEST_ASSERT(istype(snapshot), "The test hull could not be saved: [snapshot]")
	var/obj/structure/overmap/ship/original = snapshot.source_ship.resolve()
	var/list/before = group_census(original.shuttle)
	TEST_ASSERT(before["firelocks in groups of two or more"], "The test hull has no adjacent firelocks")
	TEST_ASSERT(before["tanks in groups of two or more"], "The test hull has no adjacent stationary tanks")
	TEST_ASSERT(lose_original(home, original), "The original could not be removed")
	var/datum/outpost_berth/ship_bay/bay = home.bay_berths[1]
	var/datum/checkpoint_construction/job = new(null, snapshot, captain, TRUE)
	TEST_ASSERT(job.prepare(), "The rebuild did not start: [job.error]")
	job.begin_building()
	var/list/turf/bay_side = list()
	for(var/turf/tile as anything in job.bay_turfs)
		bay_side[tile] = TRUE
	var/list/problems = list()
	while(job.state == "building")
		var/datum/checkpoint_visit/visit = job.next_visit()
		if(!visit)
			var/stage_before = job.stage
			job.advance_stage()
			if(job.state != "building" || job.stage == stage_before)
				break
			continue
		job.execute_visit(visit)
		// What firelock alarms and tank pressure do between visits: ask each placed piece for its group.
		for(var/datum/weakref/piece_ref as anything in visit.pieces)
			var/atom/movable/piece = piece_ref.resolve()
			var/id = merger_id_of(piece)
			if(!id || QDELETED(piece))
				continue
			var/datum/merger/group = piece.GetMergeGroup(id, merger_types_of(piece))
			if(!group)
				problems += "[piece] at [COORD(piece)] has no group after it was placed"
				continue
			for(var/atom/member as anything in group.members)
				if(!bay_side[get_turf(member)])
					problems += "[piece] at [COORD(piece)] shares a group with [member] still in the hidden copy at [COORD(member)]"
					break
		job.advance_stage()
	TEST_ASSERT(!length(problems), "Placed pieces joined broken groups: [problems.Copy(1, min(6, length(problems) + 1)).Join("; ")]")
	if(!QDELETED(job))
		job.hand_over_now()
	var/obj/structure/overmap/ship/rebuilt = bay.ship
	TEST_ASSERT(QDELETED(job) && rebuilt, "The rebuild was not handed over")
	test_ships += rebuilt
	var/list/after = group_census(rebuilt.shuttle)
	for(var/key in (before | after))
		if(before[key] != after[key])
			TEST_FAIL("[key]: [before[key] || 0] before, [after[key] || 0] rebuilt")

/datum/unit_test/voidcrew_checkpoints/merge_groups/proc/merger_id_of(atom/thing)
	if(istype(thing, /obj/machinery/door/firedoor))
		var/obj/machinery/door/firedoor/firelock = thing
		return firelock.merger_id
	if(istype(thing, /obj/machinery/atmospherics/components/tank))
		var/obj/machinery/atmospherics/components/tank/tank = thing
		return tank.merger_id
	return null

/datum/unit_test/voidcrew_checkpoints/merge_groups/proc/merger_types_of(atom/thing)
	// Both keep their typecache in a static var of the same name.
	return thing:merger_typecache

/// Counts grouped atoms, and every way a hull's groups disagree with its layout.
/datum/unit_test/voidcrew_checkpoints/merge_groups/proc/group_census(obj/docking_port/mobile/port)
	var/list/census = list()
	var/list/turf/hull = list()
	for(var/turf/tile as anything in port.return_turfs())
		if(get_area(tile) in port.shuttle_areas)
			hull[tile] = TRUE
	for(var/turf/tile as anything in hull)
		for(var/atom/movable/thing in tile)
			var/id = merger_id_of(thing)
			if(!id)
				continue
			var/label = istype(thing, /obj/machinery/door/firedoor) ? "firelocks" : "tanks"
			var/datum/merger/group = thing.mergers?[id]
			if(!group)
				census["[label] without a group"]++
				continue
			if(!group.members[thing])
				census["[label] missing from their own group"]++
			var/list/types = merger_types_of(thing)
			for(var/atom/member as anything in group.members)
				if(!hull[get_turf(member)])
					census["[label] grouped with something off the hull"]++
					break
			// Groups are the connected runs of like atoms, sharing a tile or side by side.
			var/list/turf/nearby_turfs = list(tile)
			for(var/direction in GLOB.cardinals)
				nearby_turfs += get_step(tile, direction)
			for(var/turf/nearby as anything in nearby_turfs)
				for(var/atom/movable/other in nearby)
					if(other != thing && types[other.type] && other.mergers?[id] != group)
						census["[label] split from a neighbour"]++
			if(length(group.members) > 1)
				census["[label] in groups of two or more"]++
	return census
