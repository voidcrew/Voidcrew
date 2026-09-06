/** Full ordinary routes: real kit interactions earn every stage; travel positions are fixture setup. */
/datum/unit_test/vestige_exterior_route
	abstract_type = /datum/unit_test/vestige_exterior_route
	var/datum/turf_reservation/route_region
	var/turf/center
	var/mob/living/carbon/human/consistent/user
	var/datum/vestige_trial/route_trial
	var/obj/structure/window/reinforced/fulltile/pane

/datum/unit_test/vestige_exterior_route/New()
	..()
	route_region = SSmapping.request_turf_block_reservation(31, 31, 1)
	if(!route_region)
		return
	var/turf/bottom = route_region.bottom_left_turfs[1]
	var/turf/top = route_region.top_right_turfs[1]
	initialize_uninitialized_block_turfs(bottom, top)
	for(var/turf/spot as anything in block(bottom, top))
		spot.ChangeTurf(/turf/open/space)
	center = locate(bottom.x + 15, bottom.y + 15, bottom.z)
	// A sealed one-tile cabin supplies a stable air-to-vacuum window for the full nine-second route.
	for(var/turf/spot in RANGE_TURFS(1, center))
		spot.ChangeTurf(/turf/closed/wall)
	center = locate(bottom.x + 15, bottom.y + 15, bottom.z)
	center = center.ChangeTurf(/turf/open/floor/plating)
	var/turf/window_floor = get_step(center, EAST)
	window_floor = window_floor.ChangeTurf(/turf/open/floor/plating)
	pane = allocate(/obj/structure/window/reinforced/fulltile, window_floor)
	var/turf/open/inside = center
	var/datum/gas_mixture/air = SSair.parse_gas_string(inside.initial_gas_mix, /datum/gas_mixture/turf)
	inside.copy_air(air)
	inside.air_update_turf(update = FALSE, remove = FALSE)
	user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	user.equipOutfit(/datum/outfit/space)
	user.open_internals(user.back)

/datum/unit_test/vestige_exterior_route/Destroy()
	QDEL_NULL(route_trial)
	QDEL_NULL(user)
	QDEL_NULL(pane)
	// The standard test cleanup only sweeps its own z-level; these atoms live in a separate reservation.
	if(route_region)
		for(var/turf/spot as anything in block(route_region.bottom_left_turfs[1], route_region.top_right_turfs[1]))
			for(var/atom/movable/content as anything in spot.contents)
				qdel(content)
	QDEL_NULL(route_region)
	return ..()

/datum/unit_test/vestige_exterior_route/proc/prepare(trial_type)
	route_trial = allocate(trial_type, user.mind)
	user.mind.active_vestige_trial = route_trial
	route_trial.on_accepted(user)
	return route_trial

/datum/unit_test/vestige_exterior_route/long_dark/Run()
	TEST_ASSERT(route_region && user, "The exterior route needs an allocated EVA fixture.")
	var/datum/vestige_trial/long_dark/trial = prepare(/datum/vestige_trial/long_dark)
	trial.shard.attack_self(user, list())
	TEST_ASSERT(trial.home_beacon && trial.echo, "Activating the held shard on the pressurized floor must place the home and a random exterior echo.")
	var/turf/first
	var/turf/second
	// Choose a legal pair around the actual random echo without setting any reading or revelation state.
	for(var/turf/open/space/candidate in range(7, trial.echo))
		if(get_dist(candidate, trial.echo) < 3 || !can_see(candidate, trial.echo, 12))
			continue
		if(!first)
			first = candidate
		else if(trial.valid_baseline(first, candidate, get_turf(trial.echo)))
			second = candidate
			break
	TEST_ASSERT(first && second, "The generated echo must have two reachable open-space bearing positions.")
	user.forceMove(first)
	trial.shard.attack_self(user, list())
	TEST_ASSERT(trial.first_reading && !trial.revealed, "The first actual activation must record one bearing without revealing the echo.")
	user.forceMove(second)
	trial.shard.attack_self(user, list())
	TEST_ASSERT(trial.revealed && !trial.echo.invisibility, "The second actual bearing must reveal the echo.")
	user.forceMove(get_step(trial.echo, NORTH))
	TEST_ASSERT(trial.echo.base_item_interaction(user, trial.shard, list()) & ITEM_INTERACT_SUCCESS, "Touching the echo with the held shard must finish its real recovery channel.")
	TEST_ASSERT(trial.recovered, "The recovery channel must put the echo in the shard.")
	user.forceMove(center)
	TEST_ASSERT(trial.home_beacon.base_item_interaction(user, trial.shard, list()) & ITEM_INTERACT_SUCCESS, "Returning the recovered shard must deliver it.")
	TEST_ASSERT(/datum/vestige_trial/long_dark in user.mind.completed_vestige_trials, "Two bearings, recovery and delivery must complete Long Dark.")
	TEST_ASSERT(QDELETED(trial), "Completing the exterior route must reclaim its trial and loans.")

/datum/unit_test/vestige_exterior_route/other_side/Run()
	TEST_ASSERT(route_region && user, "The exterior route needs an allocated EVA fixture.")
	var/datum/vestige_trial/other_side/trial = prepare(/datum/vestige_trial/other_side)
	TEST_ASSERT(!trial.card.void_side(center), "The cabin must begin pressurized.")
	TEST_ASSERT(pane.base_item_interaction(user, trial.card, list()) & ITEM_INTERACT_SUCCESS, "The actual three-second inside press must leave a reflection.")
	TEST_ASSERT_EQUAL(trial.phase, 1, "Only the completed first press may begin the exterior leg.")
	var/turf/outside = trial.outside_turf()
	TEST_ASSERT(isspaceturf(outside), "The marked full-tile pane must identify its vacuum face.")
	user.forceMove(outside)
	TEST_ASSERT(pane.base_item_interaction(user, trial.card, list()) & ITEM_INTERACT_SUCCESS, "The actual exterior press must collect the reply.")
	TEST_ASSERT_EQUAL(trial.phase, 2, "The second completed press must require a return inside.")
	user.forceMove(center)
	TEST_ASSERT(pane.base_item_interaction(user, trial.card, list()) & ITEM_INTERACT_SUCCESS, "The actual final inside press must deliver the reply.")
	TEST_ASSERT(/datum/vestige_trial/other_side in user.mind.completed_vestige_trials, "All three timed presses against one intact pressure seal must complete Other Side.")
	TEST_ASSERT(!QDELETED(pane) && pane.density, "The player's real window must survive the trial cleanup.")

/datum/unit_test/vestige_exterior_route/little_moon/Run()
	TEST_ASSERT(route_region && user, "The exterior route needs an allocated EVA fixture.")
	var/datum/vestige_trial/little_moon/trial = prepare(/datum/vestige_trial/little_moon)
	user.forceMove(locate(center.x + 5, center.y, center.z))
	trial.tether.attack_self(user, list())
	TEST_ASSERT(trial.cradle && trial.cargo, "The actual tether activation must launch the random tumbling keepsake.")
	var/turf/home = get_turf(trial.cradle)
	for(var/pull in 1 to 4)
		var/obj/structure/vestige_tumbling_keepsake/cargo = trial.cargo
		TEST_ASSERT(cargo, "Every unsolved drift component must retain the cargo.")
		var/direction = cargo.drift_x ? (cargo.drift_x > 0 ? WEST : EAST) : (cargo.drift_y > 0 ? SOUTH : NORTH)
		var/turf/approach = get_turf(cargo)
		for(var/step_index in 1 to 3)
			approach = get_step(approach, direction)
		user.forceMove(approach)
		var/turf/destination = get_step(cargo, direction)
		var/turf/recoil = get_step(user, REVERSE_DIR(direction))
		// Make only the one-second input throttle due; the real cable interaction earns movement and drift changes.
		trial.tether.next_pull = world.time
		TEST_ASSERT(cargo.base_ranged_item_interaction(user, trial.tether, list()) & ITEM_INTERACT_SUCCESS, "Each real cardinal cable pull must succeed.")
		TEST_ASSERT_EQUAL(get_turf(user), recoil, "The actual pull must recoil the EVA user one tile toward the cargo.")
		if(pull < 4)
			TEST_ASSERT_EQUAL(get_turf(cargo), destination, "The real cargo Move must follow the cable by one tile.")
	TEST_ASSERT(trial.keepsake && !trial.cargo, "Four correct impulses must stabilize both random drift components.")
	user.forceMove(get_turf(trial.keepsake))
	user.swap_hand() // Ordinary pickup uses the active hand; the tether remains held in the other hand.
	trial.keepsake.attack_hand(user, list())
	TEST_ASSERT(user.is_holding(trial.keepsake), "The stabilized keepsake must be collectible through ordinary pickup.")
	user.forceMove(home)
	TEST_ASSERT(trial.cradle.base_item_interaction(user, trial.keepsake, list()) & ITEM_INTERACT_SUCCESS, "The held keepsake must deliver to its actual launch cradle.")
	TEST_ASSERT(/datum/vestige_trial/little_moon in user.mind.completed_vestige_trials, "Launch, four real pulls, pickup and delivery must complete Little Moon.")

/** Copy both randomized roles using storage custody and actual actor approaches. */
/datum/unit_test/vestige_morph/perfect_copy_route/Run()
	open_test_corridor(8)
	var/datum/vestige_trial/perfect_copy/trial = prepare(/datum/vestige_trial/perfect_copy)
	// Widened test terrain borders vacuum; this route checks performance and storage visibility.
	ADD_TRAIT(user, TRAIT_NOBREATH, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTLOWPRESSURE, TRAIT_SOURCE_UNIT_TESTS)
	ADD_TRAIT(user, TRAIT_RESISTCOLD, TRAIT_SOURCE_UNIT_TESTS)
	user.put_in_hands(trial.invitation)
	trial.invitation.attack_self(user, list())
	TEST_ASSERT(trial.actor && get_dist(user, trial.actor) >= 3, "The real invitation must provide the required approach distance.")
	user.dropItemToGround(trial.invitation)
	var/obj/item/storage/backpack/bag = allocate(/obj/item/storage/backpack, center)
	for(var/role in 1 to 2)
		var/obj/item/original
		for(var/datum/weakref/loan_ref as anything in trial.loan_refs)
			var/obj/item/loan = loan_ref.resolve()
			if(!isitem(loan))
				continue
			if(loan != trial.skin && trial.matches_role(loan))
				original = loan
				break
		TEST_ASSERT(original, "The issued kit must contain an ordinary original for each requested role.")
		TEST_ASSERT(original.base_item_interaction(user, trial.skin, list()) & ITEM_INTERACT_SUCCESS, "The held skin must copy the requested original through actual item dispatch.")
		TEST_ASSERT(bag.atom_storage.attempt_insert(original, user, messages = FALSE), "Ordinary backpack storage must hide the copied original.")
		for(var/beat in 1 to 8)
			trial.next_action = world.time
			trial.invitation.process(0.2)
			if(trial.inspection_until > world.time)
				break
		TEST_ASSERT(trial.inspection_until > world.time && trial.approach_steps >= 2, "The real scavenger must physically approach and announce inspection.")
		trial.skin.attack_self(user, list())
		if(role == 1)
			TEST_ASSERT_EQUAL(trial.role_index, 2, "The first actual reveal must select the other role.")
			for(var/beat in 1 to 8)
				trial.next_action = world.time
				trial.invitation.process(0.2)
				if(get_turf(trial.actor) == get_turf(trial.home_ref))
					break
			TEST_ASSERT(get_dist(trial.actor, user) >= 3, "The real scavenger must retreat far enough for its second approach.")
	TEST_ASSERT(/datum/vestige_trial/perfect_copy in user.mind.completed_vestige_trials, "Both randomized roles must complete through actual storage, approach and reveal events.")
