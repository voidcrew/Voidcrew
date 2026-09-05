/** Regression tests for the portable field lessons and exterior interactions. */

/datum/unit_test/vestige_field_ranged_haunting/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, center)
	user.mind_initialize()
	var/datum/vestige_trial/the_watched/trial = allocate(/datum/vestige_trial/the_watched, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	STOP_PROCESSING(SSfastprocess, trial.manual)
	trial.field_center = WEAKREF(center)
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
	trial.field_center = WEAKREF(center)
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
	trial.field_center = WEAKREF(center)
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

/datum/unit_test/vestige_field_patrol_collision/Run()
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/datum/vestige_trial/thrown_star/trial = allocate(/datum/vestige_trial/thrown_star)
	trial.field_center = WEAKREF(center)
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
	var/turf/center = locate(run_loc_floor_bottom_left.x + 4, run_loc_floor_bottom_left.y + 4, run_loc_floor_bottom_left.z)
	var/mob/living/carbon/human/consistent/user = allocate(/mob/living/carbon/human/consistent, get_step(center, WEST))
	user.mind_initialize()
	var/datum/vestige_trial/little_moon/trial = allocate(/datum/vestige_trial/little_moon, user.mind)
	user.mind.active_vestige_trial = trial
	trial.on_accepted(user)
	trial.cargo = allocate(/obj/structure/vestige_tumbling_keepsake, get_step(center, EAST))
	trial.cargo.drift_x = 2
	trial.cargo.drift_y = 2
	var/original_type = center.type
	center = center.ChangeTurf(/turf/open/space)
	var/result = trial.cargo.base_ranged_item_interaction(user, trial.tether, list())
	var/drift_after = trial.cargo.drift_x
	var/moved = get_turf(trial.cargo) == center
	center.ChangeTurf(original_type)
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
