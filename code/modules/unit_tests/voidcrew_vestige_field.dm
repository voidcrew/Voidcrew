/** Regression tests for the portable field lessons and exterior interactions. */

/** Complete lesson routes use the actual kit dispatch, physical movement, and progress events. */
/datum/unit_test/vestige_field_route
	abstract_type = /datum/unit_test/vestige_field_route
	var/mob/living/carbon/human/consistent/user
	var/turf/center
	var/datum/vestige_trial/field_encounter/route_trial
	var/list/terrain_originals = list()

/datum/unit_test/vestige_field_route/New()
	..()
	// Rear approaches need the floor outside the five-by-five projection too.
	center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/center_x = center.x
	var/center_y = center.y
	var/center_z = center.z
	for(var/turf/spot in RANGE_TURFS(4, center))
		terrain_originals += list(list(spot.x, spot.y, spot.z, spot.type))
		var/turf/floor = spot.ChangeTurf(/turf/open/floor/plating)
		// Changing a space turf to plating retains /area/space and its no-gravity flag.
		floor.AddElement(/datum/element/forced_gravity, 1)
	center = locate(center_x, center_y, center_z)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	// The widened test room borders vacuum; the lesson is about its projections.
	ADD_TRAIT(user, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)

/datum/unit_test/vestige_field_route/Destroy()
	QDEL_NULL(route_trial)
	QDEL_NULL(user)
	for(var/list/record as anything in terrain_originals)
		var/turf/spot = locate(record[1], record[2], record[3])
		spot.RemoveElement(/datum/element/forced_gravity, 1)
		spot.ChangeTurf(record[4])
	return ..()

/datum/unit_test/vestige_field_route/proc/prepare(trial_type)
	route_trial = allocate(trial_type, user.mind)
	user.mind.active_vestige_trial = route_trial
	route_trial.on_accepted(user)
	route_trial.manual.attack_self(user, list())
	STOP_PROCESSING(SSfastprocess, route_trial.manual)
	user.dropItemToGround(route_trial.manual)
	return route_trial

/datum/unit_test/vestige_field_route/proc/spot(offset_x, offset_y)
	return locate(center.x + offset_x, center.y + offset_y, center.z)

/// Find a physical cardinal route. Avoiding sight is a navigation constraint, never forged mission progress.
/datum/unit_test/vestige_field_route/proc/path_to(turf/destination, avoid_sight = FALSE)
	var/turf/start = get_turf(user)
	var/list/queue = list(start)
	var/list/previous = list()
	previous[start] = TRUE
	for(var/queue_index in 1 to 81)
		if(queue_index > length(queue))
			return null
		var/turf/current = queue[queue_index]
		if(current == destination)
			var/list/path = list()
			while(current != start)
				path.Insert(1, current)
				current = previous[current]
			return path
		for(var/direction in GLOB.cardinals)
			var/turf/next = get_step(current, direction)
			if(!next || get_dist(next, center) > 4 || previous[next] || next.is_blocked_turf())
				continue
			if(avoid_sight && get_dist(route_trial.actor, next) <= 4 && is_source_facing_target(route_trial.actor, next) && can_see(route_trial.actor, next, 4))
				continue
			previous[next] = current
			queue += next
	return null

/datum/unit_test/vestige_field_route/proc/walk_route_to(turf/destination, avoid_sight = FALSE)
	var/list/path = path_to(destination, avoid_sight)
	if(isnull(path))
		return FALSE
	for(var/turf/next as anything in path)
		if(!user.Move(next, get_dir(user, next)))
			return FALSE
		if(avoid_sight && route_trial.in_sight(user))
			return FALSE
	return TRUE

/// Advance an ordinary scheduled patrol beat; never assign actor positions or travel credit.
/datum/unit_test/vestige_field_route/proc/patrol_beats(count)
	for(var/index in 1 to count)
		route_trial.next_step = world.time
		route_trial.manual.process(0.2)

/// Reproduce the old widened-room drift and prove the corrected floor holds an actual moved actor still.
/datum/unit_test/vestige_field_route/fixture_gravity/Run()
	for(var/turf/floor in RANGE_TURFS(4, center))
		floor.RemoveElement(/datum/element/forced_gravity, 1)
	user.forceMove(spot(1, 0))
	TEST_ASSERT(user.Move(spot(2, 0), EAST), "The actor must really walk onto the former exterior test floor.")
	TEST_ASSERT(!user.has_gravity(), "Plating in the original exterior area must reproduce the missing gravity.")
	TEST_ASSERT(user.drift_handler, "That real Move must start the drift that interrupted the lesson channels.")
	var/turf/entered = get_turf(user)
	sleep(1 SECONDS)
	TEST_ASSERT(get_turf(user) != entered, "The original fixture must actually move the waiting actor through inertia.")
	for(var/turf/floor in RANGE_TURFS(4, center))
		floor.AddElement(/datum/element/forced_gravity, 1)
	user.forceMove(spot(1, 0))
	user.refresh_gravity()
	TEST_ASSERT(user.Move(spot(2, 0), EAST), "The same ordinary move must still work with the corrected gravity.")
	TEST_ASSERT_EQUAL(user.has_gravity(), STANDARD_GRAVITY, "The restored fixture floor must have normal gravity.")
	entered = get_turf(user)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(user), entered, "The corrected fixture must preserve a waiting actor's actual position.")

/datum/unit_test/vestige_field_route/stillness/Run()
	var/datum/vestige_trial/stillness/trial = prepare(/datum/vestige_trial/stillness)
	TEST_ASSERT(trial.field_center, "The actual manual must deploy the instructor.")
	for(var/exchange in 1 to 3)
		TEST_ASSERT(walk_route_to(spot(2, 0)), "The student must walk to the two-tile bait position.")
		user.toggle_resting()
		trial.incense.attack_self(user, list())
		TEST_ASSERT_EQUAL(trial.phase, 1, "Rest plus incense activation must begin the feint.")
		sleep(3 SECONDS)
		trial.manual.process(0.2)
		TEST_ASSERT_EQUAL(trial.phase, 2, "Holding the real three-second feint must produce the sweep.")
		user.toggle_resting()
		TEST_ASSERT(walk_route_to(spot(1, 1)), "The student must leave both possible sweep lines.")
		sleep(3 SECONDS)
		trial.manual.process(0.2)
		TEST_ASSERT_EQUAL(trial.phase, 3, "Evading the real sweep must expose recovery.")
		TEST_ASSERT(trial.actor.base_item_interaction(user, trial.incense, list()) & ITEM_INTERACT_SUCCESS, "Touching the instructor with the held incense must counter.")
		if(exchange < 3)
			TEST_ASSERT_EQUAL(trial.counters, exchange, "Only the actual counter may advance the lesson.")
	TEST_ASSERT(/datum/vestige_trial/stillness in user.mind.completed_vestige_trials, "Three actual exchanges must complete Stillness.")

/datum/unit_test/vestige_field_route/thrown_star/Run()
	var/datum/vestige_trial/thrown_star/trial = prepare(/datum/vestige_trial/thrown_star)
	TEST_ASSERT(trial.field_center, "The actual manual must deploy the shield patrol.")
	var/list/firing_positions = list(spot(-2, -2), spot(-2, 2), spot(4, 1))
	var/obj/structure/vestige_field_node/focus = trial.field_nodes[2]
	for(var/throw_index in 1 to 3)
		patrol_beats(5)
		TEST_ASSERT_EQUAL(trial.actor_steps, 4 * throw_index, "The target must actually walk four tiles before each throw.")
		TEST_ASSERT(walk_route_to(firing_positions[throw_index]), "The thrower must physically reach the firing side.")
		user.swap_hand(user.get_held_index_of_item(trial.star))
		TEST_ASSERT(user.throw_item(trial.actor), "The normal held-item throw must launch the star.")
		for(var/tick in 1 to 30)
			if(QDELETED(trial) || !trial.star.throwing)
				break
			sleep(1)
		if(throw_index == 3)
			break
		TEST_ASSERT_EQUAL(length(trial.firing_sides), throw_index, "An actual rear impact must credit its new side.")
		TEST_ASSERT(walk_route_to(center), "The thrower must return to the recall focus.")
		focus.attack_hand(user, list())
		TEST_ASSERT(user.is_holding(trial.star), "The real empty-hand focus input must recall the grounded star.")
	TEST_ASSERT(/datum/vestige_trial/thrown_star in user.mind.completed_vestige_trials, "Three actual traveling-target throws must complete Thrown Star.")

/datum/unit_test/vestige_field_route/snuffed_flame/Run()
	var/datum/vestige_trial/snuffed_flame/trial = prepare(/datum/vestige_trial/snuffed_flame)
	TEST_ASSERT_EQUAL(length(trial.field_nodes), 9, "The manual must deploy all nine linked lamps.")
	var/initial_mask = 0
	var/list/press_masks = list()
	for(var/index in 1 to 9)
		var/obj/structure/vestige_field_node/pressed = trial.field_nodes[index]
		if(pressed.lit)
			initial_mask |= 1 << (index - 1)
		var/press_mask = 0
		for(var/neighbor_index in 1 to 9)
			var/obj/structure/vestige_field_node/neighbor = trial.field_nodes[neighbor_index]
			if(neighbor == pressed || (get_dist(pressed, neighbor) == 2 && (pressed.x == neighbor.x || pressed.y == neighbor.y)))
				press_mask |= 1 << (neighbor_index - 1)
		press_masks += press_mask
	var/solution
	for(var/candidate in 0 to 511)
		var/result = initial_mask
		for(var/index in 1 to 9)
			if(candidate & (1 << (index - 1)))
				result ^= press_masks[index]
		if(!result)
			solution = candidate
			break
	TEST_ASSERT(!isnull(solution), "The deployed random puzzle must have a solution using legal linked-lamp moves.")
	var/list/lamps = trial.field_nodes.Copy()
	for(var/index in 1 to 9)
		if(!(solution & (1 << (index - 1))))
			continue
		var/obj/structure/vestige_field_node/lamp = lamps[index]
		TEST_ASSERT(walk_route_to(get_turf(lamp)), "The solver must physically reach each selected lamp.")
		TEST_ASSERT(lamp.base_item_interaction(user, trial.censer, list()) & ITEM_INTERACT_SUCCESS, "The held censer must toggle through actual item dispatch.")
	TEST_ASSERT(/datum/vestige_trial/snuffed_flame in user.mind.completed_vestige_trials, "Solving the live lamp circuit must complete Snuffed Flame.")

/datum/unit_test/vestige_field_route/unseen_hand/Run()
	var/datum/vestige_trial/unseen_hand/trial = prepare(/datum/vestige_trial/unseen_hand)
	TEST_ASSERT(trial.field_center, "The actual manual must deploy the sentry and bells.")
	var/obj/structure/vestige_field_node/northwest_bell = trial.field_nodes[2]
	var/obj/structure/vestige_field_node/southeast_bell = trial.field_nodes[3]
	var/obj/structure/vestige_field_node/focus = trial.field_nodes[4]
	// Initial deployment can expose the student; no progress exists until they leave sight.
	TEST_ASSERT(walk_route_to(get_turf(southeast_bell)), "The student must walk out of the initial cone to the southeast bell.")
	southeast_bell.attack_hand(user, list())
	TEST_ASSERT_EQUAL(length(trial.silenced), 1, "The real empty-hand bell input must silence the first alarm.")
	TEST_ASSERT(walk_route_to(spot(4, -4), TRUE), "The student must withdraw beyond the patrol's sight.")
	patrol_beats(10)
	TEST_ASSERT(walk_route_to(get_turf(northwest_bell), TRUE), "The student must approach the other bell outside the sentry's forward cone.")
	northwest_bell.attack_hand(user, list())
	TEST_ASSERT_EQUAL(length(trial.silenced), 2, "Both actual bell interactions must be required.")
	TEST_ASSERT(walk_route_to(spot(2, 3), TRUE), "The student must reach the back of the northeast corner patrol.")
	user.swap_hand(user.get_held_index_of_item(trial.seal))
	TEST_ASSERT(trial.actor.base_item_interaction(user, trial.seal, list()) & ITEM_INTERACT_SUCCESS, "The actual held seal must finish its rear channel during the corner pause.")
	TEST_ASSERT(trial.marked, "The real seal channel must mark the sentry.")
	TEST_ASSERT(walk_route_to(spot(4, 4), TRUE), "The marked student must first escape the patrol.")
	patrol_beats(13)
	TEST_ASSERT_EQUAL(get_turf(trial.actor), spot(-2, 1), "The sentry must physically patrol to the extraction opening.")
	TEST_ASSERT(walk_route_to(center, TRUE), "The student must physically reach extraction without entering sight.")
	user.swap_hand(user.get_inactive_hand_index())
	focus.attack_hand(user, list())
	TEST_ASSERT(/datum/vestige_trial/unseen_hand in user.mind.completed_vestige_trials, "Both bells, the actual seal channel, and unseen extraction must complete Unseen Hand.")

/datum/unit_test/vestige_field_route/the_watched/Run()
	var/datum/vestige_trial/the_watched/trial = prepare(/datum/vestige_trial/the_watched)
	TEST_ASSERT(trial.field_center, "The actual manual must deploy the watchman's circuit.")
	var/obj/structure/vestige_field_node/northwest_lamp = trial.field_nodes[3]
	var/obj/structure/vestige_field_node/southeast_lamp = trial.field_nodes[5]
	var/obj/structure/vestige_field_node/focus = trial.field_nodes[6]
	user.swap_hand(user.get_held_index_of_item(trial.eye))
	TEST_ASSERT(walk_route_to(get_turf(northwest_lamp), TRUE), "The observer must reach the first lamp behind the watchman.")
	TEST_ASSERT(northwest_lamp.base_item_interaction(user, trial.eye, list()) & ITEM_INTERACT_SUCCESS, "The held eye must extinguish the actual lamp.")
	TEST_ASSERT(walk_route_to(spot(2, 2), TRUE), "The observer must move away before the watchman investigates.")
	patrol_beats(3)
	TEST_ASSERT_EQUAL(trial.repair_target, northwest_lamp, "The watchman's own search must select the extinguished lamp.")
	TEST_ASSERT_EQUAL(get_turf(trial.actor), get_turf(northwest_lamp), "The watchman must physically reach the lamp before repairs.")
	TEST_ASSERT(trial.actor.base_ranged_item_interaction(user, trial.eye, list()) & ITEM_INTERACT_SUCCESS, "The first rear haunting must use the real ranged channel.")
	TEST_ASSERT_EQUAL(length(trial.haunted_corners), 1, "The actual first repair haunting must count once.")
	TEST_ASSERT(walk_route_to(spot(4, -4), TRUE), "The observer must escape the search for their previous position.")
	for(var/beat in 1 to 5)
		sleep(1 SECONDS)
		trial.manual.process(1)
	TEST_ASSERT(world.time >= trial.search_until, "The actual first five-second search must expire.")
	TEST_ASSERT(walk_route_to(get_turf(southeast_lamp), TRUE), "The observer must safely approach a different lamp.")
	TEST_ASSERT(southeast_lamp.base_item_interaction(user, trial.eye, list()) & ITEM_INTERACT_SUCCESS, "The second real lamp must be extinguished through the eye.")
	TEST_ASSERT(walk_route_to(spot(-2, 2), TRUE), "The observer must get behind the second repair approach.")
	patrol_beats(5)
	TEST_ASSERT_EQUAL(trial.repair_target, southeast_lamp, "The watchman's own search must select the second lamp.")
	TEST_ASSERT_EQUAL(get_turf(trial.actor), get_turf(southeast_lamp), "The watchman must physically walk to the second repair.")
	TEST_ASSERT(trial.actor.base_ranged_item_interaction(user, trial.eye, list()) & ITEM_INTERACT_SUCCESS, "The second rear haunting must use a new real repair channel.")
	TEST_ASSERT_EQUAL(length(trial.haunted_corners), 2, "Two distinct real repairs must supply both hauntings.")
	TEST_ASSERT(walk_route_to(spot(4, 4), TRUE), "The observer must escape the second search.")
	for(var/beat in 1 to 5)
		sleep(1 SECONDS)
		trial.manual.process(1)
	for(var/scan in 1 to 4)
		if(walk_route_to(center, TRUE))
			break
		patrol_beats(1)
	TEST_ASSERT_EQUAL(get_turf(user), center, "The observer must return to the center during a real scanning opening.")
	TEST_ASSERT(focus.base_item_interaction(user, trial.eye, list()) & ITEM_INTERACT_SUCCESS, "The real eye input must finish the encounter after both searches.")
	TEST_ASSERT(/datum/vestige_trial/the_watched in user.mind.completed_vestige_trials, "Two complete lamp-repair-search routes must complete the Watched.")

/// Solve the visible five-phase beam schedule with cardinal walks and safe waits.
/datum/unit_test/vestige_field_route/proc/beam_route(datum/vestige_trial/long_night/trial, turf/destination)
	var/list/queue = list(list(get_turf(user), trial.beam_step % 5, 0, FALSE))
	var/list/seen = list()
	seen["[user.x],[user.y],[trial.beam_step % 5]"] = TRUE
	for(var/index in 1 to 125)
		if(index > length(queue))
			return null
		var/list/state = queue[index]
		var/turf/current = state[1]
		if(current == destination)
			var/list/route = list()
			while(state[3])
				route.Insert(1, list(state))
				state = queue[state[3]]
			return route
		for(var/direction in list(NORTH, SOUTH, EAST, WEST, NONE))
			var/turf/next = direction ? get_step(current, direction) : current
			var/phase = direction ? state[2] : (state[2] + 1) % 5
			if(!next || get_dist(center, next) > 2)
				continue
			var/is_refuge = abs(next.x - center.x) == 2 && abs(next.y - center.y) == 2
			if(!is_refuge && trial.beam_hits(next, phase))
				continue
			var/key = "[next.x],[next.y],[phase]"
			if(seen[key])
				continue
			seen[key] = TRUE
			queue += list(list(next, phase, index, !direction))
	return null

/datum/unit_test/vestige_field_route/long_night/Run()
	var/datum/vestige_trial/long_night/trial = prepare(/datum/vestige_trial/long_night)
	TEST_ASSERT(trial.field_center, "The actual manual must deploy all beams and refuges.")
	user.swap_hand(user.get_held_index_of_item(trial.glass))
	var/obj/structure/vestige_field_node/first_refuge = trial.refuges[1]
	TEST_ASSERT(walk_route_to(get_turf(first_refuge)), "The carrier must walk onto the first refuge.")
	TEST_ASSERT(first_refuge.base_item_interaction(user, trial.glass, list()) & ITEM_INTERACT_SUCCESS, "The actual glass input must charge at refuge one.")
	TEST_ASSERT_EQUAL(trial.route_index, 1, "The first real refuge must start the route.")
	for(var/transfer in 2 to 4)
		var/obj/structure/vestige_field_node/refuge = trial.refuges[trial.refuge_route[transfer]]
		var/list/route = beam_route(trial, get_turf(refuge))
		TEST_ASSERT(!isnull(route), "The current visible beam schedule must admit a charged route to the next refuge.")
		for(var/list/state as anything in route)
			if(state[4])
				sleep(max(1, trial.next_beam - world.time))
				trial.manual.process(0.2)
			else
				var/turf/destination = state[1]
				TEST_ASSERT(user.Move(destination, get_dir(user, destination)), "Each planned step must execute normal physical movement.")
			TEST_ASSERT_EQUAL(trial.beam_step % 5, state[2], "Actual movement and waits must follow the visible beam schedule.")
			TEST_ASSERT_EQUAL(trial.charge, 1, "Every actual move and wait must preserve the held glass's charge.")
		TEST_ASSERT(refuge.base_item_interaction(user, trial.glass, list()) & ITEM_INTERACT_SUCCESS, "The held glass must transfer through the actual next-refuge input.")
		if(transfer < 4)
			TEST_ASSERT_EQUAL(trial.route_index, transfer, "Only reaching and touching the actual refuge may advance the route.")
	TEST_ASSERT(/datum/vestige_trial/long_night in user.mind.completed_vestige_trials, "The complete charged 1-3-2-4 journey must finish Long Night.")

/datum/unit_test/vestige_field_ranged_haunting/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/the_watched/trial = allocate(/datum/vestige_trial/the_watched, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, user)
	var/obj/structure/vestige_field_node/lamp = trial.field_nodes[2]
	lamp.light_state(FALSE)
	trial.actor.forceMove(get_turf(lamp))
	trial.actor.setDir(EAST)
	user.forceMove(locate(lamp.x - 2, lamp.y, lamp.z))
	trial.repair_target = lamp
	trial.repair_until = world.time + 20 SECONDS
	TEST_ASSERT(trial.can_haunt(user), "A two-tile rear approach during repairs must be eligible.")
	var/result = trial.actor.base_ranged_item_interaction(user, trial.eye, list())
	TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "A real ranged item dispatch must reach the haunting interaction.")
	TEST_ASSERT_EQUAL(length(trial.haunted_corners), 1, "The ranged channel must credit its repair corner.")
	TEST_ASSERT(trial.search_until > world.time, "A successful haunting must provoke a search, not leave a farmable stationary target.")
	TEST_ASSERT(!trial.can_haunt(user), "The same corner cannot be haunted again during the search.")

/datum/unit_test/vestige_field_charge_escape/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/long_night/trial = allocate(/datum/vestige_trial/long_night, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, user)
	trial.charge = 3
	trial.route_index = 1
	user.forceMove(locate(center.x + 8, center.y, center.z))
	trial.manual.process(0.2)
	TEST_ASSERT_EQUAL(trial.charge, 0, "Leaving the processing radius must empty charge before the field pauses.")
	user.forceMove(center)
	trial.charge = 3
	user.dropItemToGround(trial.glass)
	TEST_ASSERT_EQUAL(trial.charge, 0, "Dropping the glass must immediately empty its charge.")
	trial.charge = 3
	trial.field_tick(user, 0.2)
	TEST_ASSERT_EQUAL(trial.charge, 0, "A stowed or grounded glass must not preserve a charged leg.")

/datum/unit_test/vestige_field_star_qualification/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/thrown_star/trial = allocate(/datum/vestige_trial/thrown_star, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, user)
	trial.actor.forceMove(center)
	trial.actor.setDir(EAST)
	user.forceMove(locate(center.x - 3, center.y, center.z))
	var/datum/thrownthing/flight = allocate(/datum/thrownthing, trial.star, trial.actor, EAST, 7, 1, user, FALSE, 1, TRUE)
	TEST_ASSERT(!trial.strike(trial.actor, flight), "A parked target must not grant credit before moving.")
	trial.actor_steps = 2
	TEST_ASSERT(trial.strike(trial.actor, flight), "A three-tile rear throw must count.")
	TEST_ASSERT(!trial.strike(trial.actor, flight), "Repeated throws from the same firing side must not count.")
	flight.starting_turf = locate(center.x, center.y - 1, center.z)
	TEST_ASSERT(!trial.strike(trial.actor, flight), "A point-blank throw must not count.")
	flight.starting_turf = locate(center.x + 3, center.y, center.z)
	TEST_ASSERT(!trial.strike(trial.actor, flight), "The target's forward shield must block credit.")
	TEST_ASSERT_EQUAL(length(trial.firing_sides), 1, "Only the qualifying rear throw may advance the trial.")
	trial.field_center.setDir(EAST)
	TEST_ASSERT(findtext(trial.get_progress_text(), "Used: north"), "Used firing sides must display their current compass position after a ship turn.")
	TEST_ASSERT_EQUAL(trial.current_side_name("north"), "east", "A field's original north side must be labelled east after a clockwise quarter turn.")

/datum/unit_test/vestige_field_charge_crossing/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/long_night/trial = allocate(/datum/vestige_trial/long_night, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, user)
	trial.next_beam = world.time + 10 SECONDS
	user.forceMove(get_step(center, WEST))
	trial.charge = 1
	TEST_ASSERT(trial.beam_hits(center, trial.beam_step), "The crossed center tile must be a current beam.")
	TEST_ASSERT(user.Move(center, EAST), "The user must actually enter the beam tile.")
	TEST_ASSERT(user.Move(get_step(center, EAST), EAST), "The user must actually leave the beam between processing ticks.")
	TEST_ASSERT_EQUAL(trial.charge, 0, "Crossing a beam must immediately empty the glass even without a field tick.")

/datum/unit_test/vestige_field_stillness_bait/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/stillness/trial = allocate(/datum/vestige_trial/stillness, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, user)
	user.resting = TRUE
	user.forceMove(locate(center.x, center.y + 3, center.z))
	TEST_ASSERT(!trial.bait(user), "Bait outside the projected footprint cannot start an invisible sweep.")
	user.forceMove(locate(center.x, center.y + 2, center.z))
	TEST_ASSERT(trial.bait(user), "A kneeling bait on the field's edge must remain valid.")

/datum/unit_test/vestige_cosmic_dash_repeated_bump/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, start)
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent, get_step(start, EAST))
	victim.anchored = TRUE
	user.set_combat_mode(TRUE)
	victim.set_combat_mode(TRUE)
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/dash = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash)
	dash.Grant(user)
	dash.charge_delay = 0
	// Aim beyond an intervening victim: the blocked move loop repeatedly bumps it.
	var/turf/destination = locate(start.x + 4, start.y, start.z)
	dash.charge_sequence(user, destination, 0, 0)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), dash.charge_damage, "One dash must only damage the same intervening victim once.")
	dash.charge_sequence(user, destination, 0, 0)
	TEST_ASSERT_EQUAL(victim.getBruteLoss(), 2 * dash.charge_damage, "A later dash must be allowed to hit that victim again.")
	TEST_ASSERT(!length(dash.charging) && !length(dash.charge_loops), "A returned dash must not leave a movement loop waiting for body teardown.")

/datum/unit_test/vestige_cosmic_dash_lifecycle/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, start)
	user.mind_initialize()
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/dash = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash, user.mind)
	dash.Grant(user)
	var/datum/action/cooldown/other_ability = allocate(/datum/action/cooldown, user.mind)
	other_ability.Grant(user)
	var/datum/action/cooldown/already_disabled = allocate(/datum/action/cooldown, user.mind)
	already_disabled.Grant(user)
	already_disabled.disable()
	dash.charge_delay = 2
	dash.charge_speed = 1
	var/turf/destination = locate(start.x + 8, start.y, start.z)
	INVOKE_ASYNC(dash, TYPE_PROC_REF(/datum/action/cooldown/mob_cooldown/charge, Activate), destination)
	TEST_ASSERT(user in dash.charging, "The real activation must be in its registered warm-up.")
	TEST_ASSERT(other_ability.action_disabled, "Charge must actually disable competing abilities while active.")
	var/mob/living/carbon/human/consistent/new_body = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTH))
	user.mind.transfer_to(new_body)
	TEST_ASSERT_EQUAL(dash.owner, new_body, "The actual mind transfer must migrate the charge action.")
	TEST_ASSERT(!length(dash.charging), "Removing the action from the old body must cancel its pending warm-up.")
	TEST_ASSERT(!other_ability.action_disabled, "Cancelled charge must restore the abilities it disabled.")
	TEST_ASSERT(already_disabled.action_disabled, "Cancellation must preserve an ability that was already disabled.")
	TEST_ASSERT(user.Move(get_step(start, EAST)), "The old body must not retain the charge's movement-blocking signals.")
	sleep(3)
	TEST_ASSERT(!length(dash.charge_loops), "A cancelled warm-up must not start a loop when its sleep resumes.")
	TEST_ASSERT_EQUAL(dash.next_melee_use_time, min(dash.next_melee_use_time, world.time), "The new body must not inherit the abandoned 100-second melee lock.")
	dash.charge_delay = 0
	INVOKE_ASYNC(dash, TYPE_PROC_REF(/datum/action/cooldown/mob_cooldown/charge, Activate), locate(start.x + 8, new_body.y, start.z))
	sleep(1)
	var/datum/move_loop/active_loop = dash.charge_loops[new_body]
	TEST_ASSERT(active_loop && !QDELETED(active_loop), "The second real activation must own a live movement loop.")
	qdel(dash)
	TEST_ASSERT(QDELETED(active_loop), "Deleting the action must immediately delete its owned movement loop.")
	TEST_ASSERT(!other_ability.action_disabled, "Deleting a running charge must restore other abilities.")
	TEST_ASSERT(new_body.Move(get_step(new_body, NORTH)), "Action deletion must immediately restore ordinary body movement.")

/datum/unit_test/vestige_cosmic_dash_deleted_owner/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, start)
	user.mind_initialize()
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/dash = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash, user.mind)
	dash.Grant(user)
	dash.charge_delay = 0
	dash.charge_speed = 1
	INVOKE_ASYNC(dash, TYPE_PROC_REF(/datum/action/cooldown/mob_cooldown/charge, Activate), locate(start.x + 8, start.y, start.z))
	sleep(1)
	var/datum/move_loop/active_loop = dash.charge_loops[user]
	TEST_ASSERT(active_loop && !QDELETED(active_loop), "The owner must really be charging when deleted.")
	qdel(user)
	TEST_ASSERT(QDELETED(active_loop), "Owner deletion must cancel its loop before atom movement-packet destruction.")
	TEST_ASSERT(!length(dash.charging) && !length(dash.charge_loops), "Deleting the owner must clear both charge registries.")
	TEST_ASSERT_NULL(dash.owner, "Charge registration must preserve the parent action's owner-deletion handler.")
	sleep(10) // Also exercise the pending Activate continuation after its owner disappeared.

/datum/unit_test/vestige_cosmic_dash_refused_loop/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, start)
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/dash = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash)
	dash.Grant(user)
	var/datum/move_loop/prior = GLOB.move_manager.move(user, EAST, delay = 10, priority = MOVEMENT_ABOVE_SPACE_PRIORITY + 1)
	TEST_ASSERT(prior, "A higher-priority movement loop must exist for the refusal fixture.")
	dash.do_charge(user, locate(start.x + 4, start.y, start.z), 0, 0)
	TEST_ASSERT(!length(dash.charging) && !length(dash.charge_loops), "A refused charge loop must release all movement-blocking state.")
	TEST_ASSERT(!QDELETED(prior), "Charge cleanup must not delete unrelated higher-priority movement.")
	TEST_ASSERT(user.Move(get_step(start, NORTH)), "Refusal must leave the user able to move normally.")
	qdel(prior)

/datum/unit_test/vestige_cosmic_dash_started_transfer
	var/mob/living/carbon/human/consistent/replacement

/datum/unit_test/vestige_cosmic_dash_started_transfer/Run()
	var/turf/start = run_loc_floor_bottom_left
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, start)
	user.mind_initialize()
	replacement = allocate(/mob/living/carbon/human/consistent, get_step(start, NORTH))
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/dash = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash, user.mind)
	dash.Grant(user)
	RegisterSignal(user, COMSIG_STARTED_CHARGE, PROC_REF(on_charge_started))
	TEST_ASSERT(!dash.Activate(locate(start.x + 4, start.y, start.z)), "A synchronous start-signal transfer must cancel the old body's activation.")
	TEST_ASSERT_EQUAL(dash.owner, replacement, "The start listener must perform a real mind transfer.")
	TEST_ASSERT(!length(dash.charging) && !length(dash.charge_loops), "The interrupted signal boundary must retain no old-body charge.")
	TEST_ASSERT(user.Move(get_step(start, EAST)), "A cancelled start callback must not install move blockers after Remove already cleaned the body.")

/datum/unit_test/vestige_cosmic_dash_started_transfer/proc/on_charge_started(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_STARTED_CHARGE)
	source.mind.transfer_to(replacement)

/// A sleeping clone variant must not reclassify its abandoned real body as a disposable clone.
/datum/unit_test/vestige_charge_hallucination_transfer/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/action/cooldown/mob_cooldown/charge/hallucination_charge/action = allocate(/datum/action/cooldown/mob_cooldown/charge/hallucination_charge, user.mind)
	action.Grant(user)
	action.destroy_objects = FALSE
	var/mob/living/carbon/human/consistent/replacement = allocate(/mob/living/carbon/human/consistent, get_step(center, NORTH))
	var/turf/target = get_step(get_step(center, EAST), EAST)
	INVOKE_ASYNC(action, TYPE_PROC_REF(/datum/action/cooldown/mob_cooldown/charge, do_charge), user, target, 2, 0)
	TEST_ASSERT(user in action.charging, "The original body must really enter the inherited hallucination warm-up.")
	user.mind.transfer_to(replacement)
	sleep(3)
	TEST_ASSERT(!QDELETED(user), "A real old body must never become a disposable clone merely because its action transferred.")
	TEST_ASSERT_EQUAL(action.owner, replacement, "The action must remain on the new body.")
	var/mob/living/carbon/human/consistent/clone = allocate(/mob/living/carbon/human/consistent, center)
	INVOKE_ASYNC(action, TYPE_PROC_REF(/datum/action/cooldown/mob_cooldown/charge, do_charge), clone, target, 2, 0)
	TEST_ASSERT(clone in action.charging, "The second invocation must really exercise a separate clone charger.")
	action.Remove(replacement)
	sleep(3)
	TEST_ASSERT(QDELETED(clone), "An actual disposable clone must still be reclaimed after cancellation.")
	TEST_ASSERT(!QDELETED(replacement), "Clone cleanup must preserve the current real body as well.")

/datum/unit_test/vestige_charge_replaced_loop_callback
	var/datum/action/cooldown/mob_cooldown/charge/vestige_dash/action
	var/mob/living/carbon/human/consistent/user
	var/datum/move_loop/replacement_loop

/datum/unit_test/vestige_charge_replaced_loop_callback/proc/on_prior_loop_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	replacement_loop = user.move_packet.existing_loops[SSmovement]
	action.Remove(user)

/datum/unit_test/vestige_charge_replaced_loop_callback/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	action = allocate(/datum/action/cooldown/mob_cooldown/charge/vestige_dash, user.mind)
	action.Grant(user)
	var/datum/move_loop/prior = GLOB.move_manager.move(user, NORTH, delay = 10, priority = MOVEMENT_DEFAULT_PRIORITY)
	TEST_ASSERT(prior, "The fixture must have a real lower-priority loop for home_onto to replace.")
	RegisterSignal(prior, COMSIG_QDELETING, PROC_REF(on_prior_loop_deleted))
	TEST_ASSERT(!action.do_charge(user, get_step(get_step(center, EAST), EAST), 0, 0), "Removal during old-loop deletion must cancel the actual charge setup.")
	TEST_ASSERT(replacement_loop && replacement_loop != prior, "The callback must run after the new loop was installed but before home_onto returned.")
	TEST_ASSERT(QDELETED(replacement_loop), "Cancellation must delete the newly returned charge loop even though it was not registered yet.")
	TEST_ASSERT(!length(action.charging) && !length(action.charge_loops), "A rejected returned loop must leave no charge registry behind.")
	TEST_ASSERT(!GLOB.move_manager.processing_on(user, SSmovement), "The removed charge must not continue moving its abandoned owner.")
	TEST_ASSERT(user.Move(get_step(user, NORTH), NORTH), "The abandoned owner must have no leftover charge movement block.")

/datum/unit_test/vestige_charge_hallucination_callbacks
	var/datum/action/cooldown/mob_cooldown/charge/hallucination_charge/action
	var/mob/living/replacement
	var/mob/living/first_clone
	var/start_signals = 0

/datum/unit_test/vestige_charge_hallucination_callbacks/proc/remove_during_placement(mob/living/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_MOVABLE_MOVED)
	action.Remove(source)

/datum/unit_test/vestige_charge_hallucination_callbacks/proc/transfer_during_clone_start(mob/living/source)
	SIGNAL_HANDLER
	start_signals++
	UnregisterSignal(source, COMSIG_STARTED_CHARGE)
	first_clone = action.charging[1]
	source.mind.transfer_to(replacement)

/datum/unit_test/vestige_charge_hallucination_callbacks/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	action = allocate(/datum/action/cooldown/mob_cooldown/charge/hallucination_charge, user.mind)
	action.Grant(user)
	action.destroy_objects = FALSE
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(remove_during_placement))
	action.hallucination_charge(center, 3, 2, 0, 2, TRUE)
	TEST_ASSERT_NULL(action.owner, "The helper's actual forced placement must synchronously remove its action.")
	TEST_ASSERT(!length(action.charging), "Removed placement must not continue into real or clone warm-ups.")
	TEST_ASSERT(!QDELETED(user), "Stopping a hallucination helper must preserve its real caster.")
	user.forceMove(center)
	action.Grant(user)
	replacement = allocate(/mob/living/carbon/human/consistent, get_step(center, NORTH))
	var/turf/replacement_start = get_turf(replacement)
	RegisterSignal(user, COMSIG_STARTED_CHARGE, PROC_REF(transfer_during_clone_start))
	action.hallucination_charge(center, 3, 2, 0, 2, FALSE)
	TEST_ASSERT_EQUAL(start_signals, 1, "The first actual clone's started callback must perform the transfer.")
	TEST_ASSERT(first_clone && first_clone != user, "The callback must come from an actual spawned hallucination charge.")
	TEST_ASSERT(QDELETED(first_clone), "The cancelled first clone must be reclaimed by its own invocation.")
	TEST_ASSERT_EQUAL(action.owner, replacement, "The helper must preserve the action's transferred owner.")
	TEST_ASSERT_EQUAL(get_turf(replacement), replacement_start, "Remaining helper iterations must not move the new body.")
	TEST_ASSERT(!length(action.charging), "The helper must not start more clones after the casting body changes.")

/datum/unit_test/vestige_field_patrol_collision/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/datum/vestige_trial/thrown_star/trial = allocate(/datum/vestige_trial/thrown_star)
	trial.field_center = trial.mark_turf(center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(center, null)
	trial.patrol_corner = 2
	var/turf/start = get_turf(trial.actor)
	var/obj/structure/vestige_field_node/blocker = allocate(/obj/structure/vestige_field_node, get_step(start, NORTH))
	blocker.density = TRUE
	trial.patrol()
	TEST_ASSERT_EQUAL(get_turf(trial.actor), start, "The patrol must respect real dense obstructions.")
	TEST_ASSERT_EQUAL(trial.actor_steps, 0, "A blocked patrol must not accrue movement qualification.")
	qdel(blocker)
	trial.next_step = 0
	trial.patrol()
	TEST_ASSERT_EQUAL(get_turf(trial.actor), get_step(start, NORTH), "Removing an obstruction must let the patrol resume its route.")
	TEST_ASSERT_EQUAL(trial.actor_steps, 1, "A real patrol step must accrue movement qualification.")

/datum/unit_test/vestige_field_window_geometry/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	var/obj/item/vestige_calling_card/card = allocate(/obj/item/vestige_calling_card)
	var/obj/structure/window/pane = allocate(/obj/structure/window, center)
	pane.fulltile = FALSE
	pane.setDir(EAST)
	TEST_ASSERT_EQUAL(card.resolve_far_side(user, pane), get_step(center, EAST), "A directional pane's own tile is a valid inside contact.")
	user.forceMove(get_step(center, EAST))
	TEST_ASSERT_EQUAL(card.resolve_far_side(user, pane), center, "The same directional pane must resolve from its exterior face.")
	user.forceMove(get_step(center, NORTH))
	TEST_ASSERT_NULL(card.resolve_far_side(user, pane), "A directional pane cannot be contacted through an edge it does not seal.")
	pane.fulltile = TRUE
	user.forceMove(get_step(center, EAST))
	TEST_ASSERT_EQUAL(card.resolve_far_side(user, pane), get_step(center, WEST), "A full-tile pane must skip its occupied tile.")
	user.forceMove(get_step(center, NORTHEAST))
	TEST_ASSERT_NULL(card.resolve_far_side(user, pane), "Diagonal contacts must not accidentally cross a different face.")
	TEST_ASSERT(!card.void_side(null), "Missing turfs must not masquerade as a valid vacuum-side contact.")

/datum/unit_test/vestige_field_tether_dispatch/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(center, WEST))
	user.mind_initialize()
	var/datum/vestige_trial/little_moon/trial = allocate(/datum/vestige_trial/little_moon, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	trial.cargo = allocate(/obj/structure/vestige_tumbling_keepsake, get_step(center, EAST))
	trial.cargo.drift_x = 2
	trial.cargo.drift_y = 2
	var/turf/cargo_turf = get_turf(trial.cargo)
	var/turf/user_turf = get_turf(user)
	TEST_ASSERT(!cargo_turf.density && !user_turf.density, "The tether fixture must keep both endpoints out of the room's walls.")
	var/original_type = center.type
	center = center.ChangeTurf(/turf/open/space)
	var/obj/structure/vestige_field_node/blocker = allocate(/obj/structure/vestige_field_node, center)
	blocker.density = TRUE
	var/blocked_result = trial.cargo.base_ranged_item_interaction(user, trial.tether, list())
	var/blocked_drift = trial.cargo.drift_x
	qdel(blocker)
	var/result = trial.cargo.base_ranged_item_interaction(user, trial.tether, list())
	var/drift_after = trial.cargo.drift_x
	var/moved = get_turf(trial.cargo) == center
	center.ChangeTurf(original_type)
	TEST_ASSERT(blocked_result & ITEM_INTERACT_BLOCKING, "A cable through a dense obstruction must be rejected.")
	TEST_ASSERT_EQUAL(blocked_drift, 2, "A blocked pull cannot stabilize cargo or spend its impulse.")
	TEST_ASSERT(result & ITEM_INTERACT_SUCCESS, "A real remote click must dispatch to the recovery tether.")
	TEST_ASSERT(moved, "A credited tether impulse must physically move the cargo.")
	TEST_ASSERT_EQUAL(drift_after, 1, "A pull from the west must counter eastward drift.")
	TEST_ASSERT(!trial.cargo.apply_impulse(EAST), "A wrong-side impulse must not stabilize a tumbling keepsake.")
	TEST_ASSERT_EQUAL(trial.cargo.drift_x, 2, "A wrong-side impulse must increase drift again.")

/datum/unit_test/vestige_field_triangulation/Run()
	var/datum/vestige_trial/long_dark/trial = allocate(/datum/vestige_trial/long_dark)
	var/turf/first = run_loc_floor_bottom_left
	var/turf/source = locate(first.x + 6, first.y, first.z)
	var/turf/collinear = locate(first.x + 5, first.y, first.z)
	var/turf/cross_bearing = locate(first.x, first.y + 5, first.z)
	TEST_ASSERT(!trial.valid_baseline(first, collinear, source), "Walking toward a source on the original bearing supplies no triangulation.")
	TEST_ASSERT(trial.valid_baseline(first, cross_bearing, source), "A separated perpendicular bearing must resolve a usable baseline.")
	TEST_ASSERT(!trial.valid_baseline(first, get_step(first, NORTH), source), "Adjacent sensor clicks must not resolve the echo.")

/// A ship turn changes world axes, but the physical field keeps its own axes.
/datum/unit_test/vestige_field_transit_geometry/Run()
	var/turf/old_center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/new_center = get_step(old_center, NORTHEAST)
	var/datum/vestige_trial/long_night/night = allocate(/datum/vestige_trial/long_night)
	night.field_center = night.mark_turf(old_center)
	night.field_center.setDir(NORTH)
	TEST_ASSERT(night.beam_hits(get_step(old_center, NORTH), 0), "The original center column must be illuminated.")
	// The marker's position and direction are what a shuttle translates/rotates.
	night.field_center.forceMove(new_center)
	night.field_center.setDir(EAST)
	TEST_ASSERT_EQUAL(night.corner_turf(1), locate(new_center.x - 2, new_center.y + 2, new_center.z), "The patrol's first corner must rotate with its physical field.")
	TEST_ASSERT(night.beam_hits(get_step(new_center, EAST), 0), "A rotated beam must follow the rotated projections.")
	TEST_ASSERT(!night.beam_hits(get_step(new_center, SOUTH), 0), "The beam must not silently keep its old world column.")
	var/datum/vestige_trial/stillness/stillness = allocate(/datum/vestige_trial/stillness)
	stillness.field_center = stillness.mark_turf(old_center)
	stillness.field_center.setDir(NORTH)
	stillness.bait_turf = stillness.mark_turf(locate(old_center.x, old_center.y + 2, old_center.z))
	stillness.sweep_horizontal = TRUE
	stillness.field_center.forceMove(new_center)
	stillness.field_center.setDir(EAST)
	stillness.bait_turf.forceMove(locate(new_center.x + 2, new_center.y, new_center.z))
	TEST_ASSERT(stillness.on_sweep(locate(new_center.x + 2, new_center.y + 1, new_center.z)), "The committed sweep must rotate from a world row to a world column with its warning tiles.")
	TEST_ASSERT(!stillness.on_sweep(locate(new_center.x + 1, new_center.y + 2, new_center.z)), "The old world row must no longer inflict the rotated sweep.")

/datum/unit_test/vestige_field_moving_window/Run()
	var/turf/inside = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/datum/vestige_trial/other_side/trial = allocate(/datum/vestige_trial/other_side)
	trial.card = allocate(/obj/item/vestige_calling_card)
	trial.inside_ref = trial.mark_turf(inside)
	var/obj/structure/window/pane = allocate(/obj/structure/window, inside)
	pane.fulltile = FALSE
	pane.setDir(EAST)
	trial.pane_ref = WEAKREF(pane)
	TEST_ASSERT_EQUAL(trial.outside_turf(), get_step(inside, EAST), "The marked pane must initially find its matching exterior face.")
	var/turf/moved_inside = get_step(inside, NORTH)
	pane.forceMove(moved_inside)
	pane.setDir(NORTH)
	trial.inside_ref.forceMove(moved_inside)
	TEST_ASSERT_EQUAL(trial.outside_turf(), get_step(moved_inside, NORTH), "The exterior face must follow a translated and rotated pane even though exterior space did not move with the ship.")
	pane.forceMove(locate(moved_inside.x + 2, moved_inside.y, moved_inside.z))
	TEST_ASSERT_NULL(trial.outside_turf(), "Moving the pane away from its marked interior must invalidate the original contact.")

/// Replay the actual shuttle callbacks in their order: move, rotate, late hooks.
/datum/unit_test/vestige_field_shuttle_sequence/Run()
	var/turf/old_center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/turf/new_center = locate(old_center.x + 3, old_center.y, old_center.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(old_center, EAST))
	user.mind_initialize()
	var/datum/vestige_trial/long_night/trial = allocate(/datum/vestige_trial/long_night, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = trial.mark_turf(old_center)
	trial.field_center.setDir(NORTH)
	trial.setup_field(old_center, user)
	trial.next_beam = world.time + 10 SECONDS
	trial.charge = 1
	trial.field_center.beforeShuttleMove(new_center, 90, MOVE_CONTENTS, null)
	TEST_ASSERT(!trial.field_center.shuttle_moving, "Abortable preflight must not leave a trial permanently paused.")
	// The carrier's turf is processed before the origin's turf in this order.
	var/turf/old_user_turf = get_turf(user)
	user.onShuttleMove(get_step(new_center, SOUTH), old_user_turf, list(), EAST, null, null)
	TEST_ASSERT_EQUAL(trial.charge, 1, "Abstract shuttle relocation must not test the carrier against the unmoved origin.")
	trial.field_center.onShuttleMove(new_center, old_center, list(), EAST, null, null)
	TEST_ASSERT(trial.field_center.shuttle_moving, "Committed movement must pause the field until every projection is rotated.")
	for(var/obj/structure/vestige_field_node/node as anything in trial.field_nodes)
		var/turf/old_node_turf = get_turf(node)
		var/turf/new_node_turf = locate(new_center.x + old_node_turf.y - old_center.y, new_center.y - old_node_turf.x + old_center.x, new_center.z)
		node.onShuttleMove(new_node_turf, old_node_turf, list(), EAST, null, null)
		node.afterShuttleMove(old_node_turf, list(), NORTH, NORTH, EAST, 90)
	// cleanup_runway may yield here, before the origin's rotation is applied.
	trial.manual.process(0.2)
	TEST_ASSERT_EQUAL(trial.charge, 1, "Processing during partial rotation must not test the final position against stale axes.")
	trial.field_center.afterShuttleMove(old_center, list(), NORTH, NORTH, EAST, 90)
	trial.field_center.lateShuttleMove(old_center, list(), EAST)
	TEST_ASSERT(!trial.field_center.shuttle_moving, "Late shuttle cleanup must resume the field without a timer.")
	TEST_ASSERT_EQUAL(trial.field_center.dir, EAST, "The actual shuttle rotation callback must rotate the field's local north.")
	trial.manual.process(0.2)
	TEST_ASSERT_EQUAL(trial.charge, 1, "A safe relative position must remain safe after translation and rotation finish.")

/// A deleted actor, lamp, or refuge invalidates the whole portable projection.
/datum/unit_test/vestige_field_projection_loss/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	for(var/trial_type in list(/datum/vestige_trial/thrown_star, /datum/vestige_trial/unseen_hand, /datum/vestige_trial/stillness, /datum/vestige_trial/snuffed_flame, /datum/vestige_trial/the_watched, /datum/vestige_trial/long_night))
		var/datum/vestige_trial/field_encounter/trial = allocate(trial_type, user.mind)
		user.mind.active_vestige_trial = trial
		trial.on_accepted(user)
		STOP_PROCESSING(SSfastprocess, trial.manual)
		TEST_ASSERT(trial.deploy(user), "[trial_type] must deploy its complete initial field.")
		var/list/old_nodes = trial.field_nodes.Copy()
		qdel(trial.field_nodes[1])
		TEST_ASSERT_NULL(trial.field_center, "[trial_type] must discard its origin when a required projection disappears.")
		TEST_ASSERT_EQUAL(length(trial.field_nodes), 0, "[trial_type] must remove the remaining nodes after partial deletion.")
		for(var/obj/structure/vestige_field_node/node as anything in old_nodes)
			TEST_ASSERT(QDELETED(node), "[trial_type] must reclaim every surviving piece of the broken field.")
		trial.manual.process(0.2)
		trial.get_progress_text()
		TEST_ASSERT(trial.deploy(user), "[trial_type] must immediately accept redeployment after projection loss.")
		qdel(trial.field_center)
		TEST_ASSERT_EQUAL(length(trial.field_nodes), 0, "[trial_type] must also reclaim its projections when the origin is deleted.")
		qdel(trial)

/// Routine cleanup of temporary sweep warnings must not fold the instructor.
/datum/unit_test/vestige_field_sweep_cleanup/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 2, run_loc_floor_bottom_left.y + 2, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/stillness/trial = allocate(/datum/vestige_trial/stillness, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	TEST_ASSERT(trial.deploy(user), "The stillness field must deploy for its warning cleanup test.")
	trial.add_node(get_step(center, NORTH), "committed sweep: leave this line")
	trial.clear_sweep()
	TEST_ASSERT_EQUAL(length(trial.field_nodes), 1, "Clearing a spent sweep must preserve the instructor.")
	TEST_ASSERT(!QDELETED(trial.actor) && !QDELETED(trial.field_center), "Expected warning cleanup must preserve the active field.")

/// A mind-bound action can change its owner while do_after still watches the old body.
/datum/unit_test/vestige_glass_phase_transfer
	var/mob/living/replacement

/datum/unit_test/vestige_glass_phase_transfer/proc/transfer_during_channel(mob/living/source)
	SIGNAL_HANDLER
	source.mind.transfer_to(replacement)

/datum/unit_test/vestige_glass_phase_transfer/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 3, run_loc_floor_bottom_left.y + 3, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	replacement = allocate(/mob/living/carbon/human/consistent, locate(center.x + 4, center.y, center.z))
	var/turf/replacement_start = get_turf(replacement)
	var/obj/structure/window/pane = allocate(/obj/structure/window, get_step(center, NORTH))
	pane.fulltile = TRUE
	var/datum/action/cooldown/spell/pointed/vestige_glass_phase/spell = allocate(/datum/action/cooldown/spell/pointed/vestige_glass_phase, user.mind)
	spell.Grant(user)
	spell.phase_time = 0.2 SECONDS
	RegisterSignal(user, COMSIG_DO_AFTER_BEGAN, PROC_REF(transfer_during_channel))
	var/result = spell.before_cast(pane)
	UnregisterSignal(user, COMSIG_DO_AFTER_BEGAN)
	TEST_ASSERT_EQUAL(spell.owner, replacement, "The channel test must perform a real mind transfer of its boon action.")
	TEST_ASSERT(result & SPELL_CANCEL_CAST, "Changing bodies during the channel must cancel the original crossing.")
	TEST_ASSERT_EQUAL(get_turf(replacement), replacement_start, "The new body must not teleport to the old body's pane when its channel ends.")
	TEST_ASSERT_EQUAL(get_turf(user), center, "An abandoned body must not finish the crossing either.")
	TEST_ASSERT(!spell.phasing, "A canceled channel must release the action for a later attempt.")
