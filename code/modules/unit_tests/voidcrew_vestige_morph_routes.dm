/** Full Morph performances with real deployment, movement, custody and timed item interactions. */
/datum/unit_test/vestige_morph_route
	abstract_type = /datum/unit_test/vestige_morph_route
	var/mob/living/carbon/human/consistent/user
	var/turf/center
	var/datum/vestige_trial/morph_scenario/route_trial
	var/list/terrain_originals = list()

/datum/unit_test/vestige_morph_route/New()
	..()
	center = locate(run_loc_floor_bottom_left.x + 8, run_loc_floor_bottom_left.y + 8, run_loc_floor_bottom_left.z)
	var/center_x = center.x
	var/center_y = center.y
	var/center_z = center.z
	// Seal the perimeter before filling the larger room; opening the stock room to vacuum
	// otherwise lets real pressure pushes interrupt the performance's timed channels.
	for(var/turf/spot in RANGE_TURFS(9, center))
		var/datum/gas_mixture/saved_air
		if(isopenturf(spot))
			var/turf/open/open_spot = spot
			if(open_spot.air)
				saved_air = new
				saved_air.copy_from(open_spot.air)
		terrain_originals += list(list(spot.x, spot.y, spot.z, spot.type, saved_air, spot.temperature))
	for(var/turf/spot in RANGE_TURFS(9, center))
		if(get_dist(spot, center) == 9)
			spot.ChangeTurf(/turf/closed/wall, flags = CHANGETURF_RECALC_ADJACENT)
	for(var/list/record as anything in terrain_originals)
		if(abs(record[1] - center_x) == 9 || abs(record[2] - center_y) == 9)
			continue
		var/turf/spot = locate(record[1], record[2], record[3])
		var/turf/open/floor = spot.ChangeTurf(/turf/open/floor/plating, flags = CHANGETURF_IGNORE_AIR)
		floor.AddElement(/datum/element/forced_gravity, 1)
	var/datum/gas_mixture/room_air = SSair.parse_gas_string(OPENTURF_DEFAULT_ATMOS, /datum/gas_mixture/turf)
	for(var/turf/open/floor in RANGE_TURFS(8, locate(center_x, center_y, center_z)))
		floor.copy_air(room_air)
		floor.air.archive()
		floor.temperature = room_air.temperature
		floor.immediate_calculate_adjacent_turfs()
		SSair.high_pressure_delta -= floor
		floor.pressure_difference = 0
		floor.pressure_direction = NONE
		floor.air_update_turf(update = FALSE, remove = FALSE)
	qdel(room_air)
	center = locate(center_x, center_y, center_z)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()

/datum/unit_test/vestige_morph_route/Destroy()
	QDEL_NULL(route_trial)
	QDEL_NULL(user)
	for(var/list/record as anything in terrain_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.RemoveElement(/datum/element/forced_gravity, 1)
		spot = spot.ChangeTurf(record[4], flags = CHANGETURF_IGNORE_AIR | CHANGETURF_RECALC_ADJACENT)
		spot.temperature = record[6]
		var/datum/gas_mixture/saved_air = record[5]
		if(isopenturf(spot) && saved_air)
			var/turf/open/open_spot = spot
			open_spot.copy_air(saved_air)
			open_spot.air.archive()
		qdel(saved_air)
	for(var/list/record as anything in terrain_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.immediate_calculate_adjacent_turfs()
		spot.air_update_turf(update = FALSE, remove = FALSE)
	return ..()

/datum/unit_test/vestige_morph_route/proc/prepare(trial_type)
	route_trial = allocate(trial_type, user.mind)
	user.mind.active_vestige_trial = route_trial
	route_trial.on_accepted(user)
	route_trial.invitation.attack_self(user, list())
	user.dropItemToGround(route_trial.invitation)
	return route_trial

/// Cardinal navigation around real walls and actors, without changing either or assigning mission state.
/datum/unit_test/vestige_morph_route/proc/walk_route_to(turf/destination)
	var/turf/start = get_turf(user)
	var/list/queue = list(start)
	var/list/previous = list()
	previous[start] = TRUE
	for(var/queue_index in 1 to 289)
		if(queue_index > length(queue))
			return FALSE
		var/turf/current = queue[queue_index]
		if(current == destination)
			var/list/path = list()
			while(current != start)
				path.Insert(1, current)
				current = previous[current]
			for(var/turf/next as anything in path)
				if(!user.Move(next, get_dir(user, next)))
					return FALSE
			return TRUE
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || get_dist(next, center) > 8 || previous[next] || next.is_blocked_turf())
				continue
			previous[next] = current
			queue += next
	return FALSE

/datum/unit_test/vestige_morph_route/snatched_meal/Run()
	// The west screen provides a real corner to break sight during the getaway.
	for(var/offset in -2 to 2)
		var/turf/screen = locate(center.x - 3, center.y + offset, center.z)
		screen.ChangeTurf(/turf/closed/wall)
	var/datum/vestige_trial/snatched_meal/trial = prepare(/datum/vestige_trial/snatched_meal)
	TEST_ASSERT(trial.actor && trial.pantry && trial.course, "The actual invitation must summon the guarded meal and porter.")
	var/turf/lure = locate(center.x + 3, center.y, center.z)
	TEST_ASSERT(lure.base_ranged_item_interaction(user, trial.maw, list()) & ITEM_INTERACT_SUCCESS, "The held maw must spit its real scent onto the nearest legal lure tile.")
	TEST_ASSERT(trial.decoy && !trial.decoy_ready, "Spitting must consume the one scent bolus.")
	for(var/beat in 1 to 12)
		trial.next_action = world.time
		trial.invitation.process(0.2)
		if(trial.investigate_until > world.time)
			break
	TEST_ASSERT(trial.investigate_until > world.time && get_turf(trial.actor) == lure, "The actual porter must walk all the way to the lure and begin investigating.")
	TEST_ASSERT(trial.pantry.base_item_interaction(user, trial.maw, list()) & ITEM_INTERACT_SUCCESS, "The real theft channel must remove the guarded course.")
	TEST_ASSERT_EQUAL(trial.course.loc, trial.maw, "The stolen meal must be physically inside the held maw.")
	var/turf/escape = locate(center.x - 6, center.y, center.z)
	TEST_ASSERT(walk_route_to(escape), "The laden keeper must walk around the opaque screen to the getaway tile.")
	TEST_ASSERT(trial.can_digest(user), "Distance and the real wall must provide a legal hidden digestion site.")
	user.swap_hand(user.get_held_index_of_item(trial.maw))
	var/digest_started = world.time
	// Normal scene processing remains enabled throughout the real three-second digestion channel.
	user.execute_mode()
	TEST_ASSERT_EQUAL(get_turf(user), escape, "The sealed room must preserve the getaway position throughout digestion.")
	TEST_ASSERT(world.time >= digest_started + 3 SECONDS, "The actual held activation must finish its three-second digestion; elapsed [world.time - digest_started], conscious [user.stat == CONSCIOUS].")
	TEST_ASSERT(/datum/vestige_trial/snatched_meal in user.mind.completed_vestige_trials, "Lure, real theft, walking escape and actual digestion must complete the Snatched Meal.")
	TEST_ASSERT(QDELETED(trial), "The finished performance must reclaim its temporary actors and kit.")

/datum/unit_test/vestige_morph_route/understudy/Run()
	var/datum/vestige_trial/understudy/trial = prepare(/datum/vestige_trial/understudy)
	TEST_ASSERT(trial.actor && trial.input && trial.left_dock && trial.right_dock, "The actual invitation must deploy the seven-tile balance dock.")
	TEST_ASSERT(trial.actor.base_item_interaction(user, trial.skin, list()) & ITEM_INTERACT_SUCCESS, "The first skin interaction must begin the custodian's real demonstration.")
	TEST_ASSERT(walk_route_to(get_step(center, NORTH)), "The observer must leave the center lane clear for the custodian.")
	for(var/beat in 1 to 64)
		trial.next_action = world.time
		trial.invitation.process(0.2)
		if(trial.ready)
			break
	TEST_ASSERT(trial.ready && trial.observed_deliveries == 3, "The real actor must carry and deliver all three practice parcels within the observer's sight.")
	TEST_ASSERT_EQUAL(trial.dock_load(trial.left_dock), 2 * trial.amber_share, "The physical amber load must express the randomly selected demonstration rule.")
	TEST_ASSERT_EQUAL(trial.dock_load(trial.right_dock), 2 * trial.violet_share, "The physical violet load must express the same demonstration rule.")
	TEST_ASSERT(walk_route_to(get_step(trial.actor, NORTH)), "The observer must walk back to the actual custodian to study it.")
	TEST_ASSERT(trial.actor.base_item_interaction(user, trial.skin, list()) & ITEM_INTERACT_SUCCESS, "The second skin interaction must finish its real identity-study channel.")
	TEST_ASSERT(trial.production && trial.has_identity(user), "Borrowing the custodian must issue the actual new shipment.")
	var/list/shipment = trial.parcels.Copy()
	TEST_ASSERT_EQUAL(length(shipment), 4, "The production shipment must contain four physical parcels.")
	var/total_load = 0
	for(var/obj/item/vestige_morph_parcel/parcel as anything in shipment)
		total_load += parcel.cargo_load
	var/amber_target = total_load * trial.amber_share / (trial.amber_share + trial.violet_share)
	var/solution = null
	// Solve the observed ratio from the actual randomized weights, without writing any load or progress state.
	for(var/subset in 0 to (2 ** length(shipment)) - 1)
		var/subtotal = 0
		for(var/index in 1 to length(shipment))
			if(subset & (1 << (index - 1)))
				var/obj/item/vestige_morph_parcel/parcel = shipment[index]
				subtotal += parcel.cargo_load
		if(subtotal == amber_target)
			solution = subset
			break
	TEST_ASSERT(!isnull(solution), "Every generated shipment must have a partition satisfying the demonstrated rule.")
	for(var/index in 1 to length(shipment))
		var/obj/item/vestige_morph_parcel/parcel = shipment[index]
		TEST_ASSERT(walk_route_to(get_turf(parcel)), "The borrowed custodian must walk to each real production parcel.")
		parcel.attack_hand(user, list())
		TEST_ASSERT(user.is_holding(parcel) && user.is_holding(trial.skin), "The parcel and skin must fit together in the keeper's ordinary hands.")
		var/obj/structure/vestige_morph_station/destination = solution & (1 << (index - 1)) ? trial.left_dock : trial.right_dock
		TEST_ASSERT(walk_route_to(get_turf(destination)), "The borrowed custodian must carry the parcel to its chosen receiving tray.")
		TEST_ASSERT(destination.base_item_interaction(user, parcel, list()) & ITEM_INTERACT_SUCCESS, "The real receiving-tray interaction must accept the held marked parcel.")
		TEST_ASSERT_EQUAL(parcel.loc, destination, "The credited load must physically reside inside its receiving tray.")
	TEST_ASSERT(walk_route_to(center), "The borrowed custodian must return to the central release.")
	TEST_ASSERT(trial.input.base_item_interaction(user, trial.skin, list()) & ITEM_INTERACT_SUCCESS, "The held skin must operate the actual release.")
	TEST_ASSERT(/datum/vestige_trial/understudy in user.mind.completed_vestige_trials, "Observation, borrowed identity and all real parcel deliveries must complete the Understudy.")
