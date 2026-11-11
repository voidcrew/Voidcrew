/**
 * Wick's routine in the Rig Bay (voidcrew/modules/trade/rig_bay/rig_bay_wick.dm), on a layout built in
 * the test room rather than the outfitter map:
 *
 *   y+4  .  [S]  .  .  .     S: a stand facing south, a mech hanging on it
 *   y+3  .   L   .  .  .     L: the stand's front tile (its lane)
 *   y+2  .   .   .  .  W     W: Wick's spawn tile
 *   y+1  T   T   T  T  T     T: work thresholds, the edge of his room
 *   y+0  .   .   .  .  .     a stand-in player, outside the room
 *
 * Voidcrew defines are not visible from test files: the trait on a hanging mech is "rig_bay_clamped"
 * (TRAIT_RIG_BAY_CLAMPED), his serve range is 3 tiles and he waits 30 s after a customer leaves.
 */
/datum/unit_test/voidcrew_rig_bay_wick
	/// Stand-ins for players, counted on their level so his AI runs
	var/list/mob/living/present = list()

/datum/unit_test/voidcrew_rig_bay_wick/Destroy()
	for(var/mob/living/someone as anything in present)
		for(var/level in 1 to length(SSmobs.clients_by_zlevel))
			SSmobs.clients_by_zlevel[level] -= someone
	present = null
	return ..()

/datum/unit_test/voidcrew_rig_bay_wick/proc/at(dx, dy)
	return locate(run_loc_floor_bottom_left.x + dx, run_loc_floor_bottom_left.y + dy, run_loc_floor_bottom_left.z)

/datum/unit_test/voidcrew_rig_bay_wick/Run()
	// Landmarks survive the test room sweep, so these go through allocate() to be cleaned up
	for(var/dx in 0 to 4)
		allocate(/obj/effect/landmark/outpost_work_threshold, at(dx, 1))
	var/turf/stand_tile = at(1, 4)
	var/obj/structure/rig_bay_stand/stand = allocate(/obj/structure/rig_bay_stand, stand_tile)
	stand.setDir(SOUTH)
	var/turf/lane = get_step(stand_tile, SOUTH)
	var/obj/vehicle/sealed/mecha/mech = allocate(/obj/vehicle/sealed/mecha/ripley, stand_tile)
	ADD_TRAIT(mech, "rig_bay_clamped", "rig_bay")
	stand.held_mech = mech
	// The chains' trait goes on as a mech starts beaming in: he leaves it alone until it hangs
	var/datum/outpost_ambient_work/mech_service/service = new
	stand.stand_state = "arriving"
	TEST_ASSERT(!service.accepts(mech), "Wick would work on a mech that is still beaming in")
	stand.stand_state = "clamped"
	TEST_ASSERT(service.accepts(mech), "Wick won't work on a hanging mech")
	qdel(service)
	var/turf/home = at(4, 2)
	var/mob/living/basic/outpost_trader/suit_fitter/wick = allocate(/mob/living/basic/outpost_trader/suit_fitter, home)
	wick.start_rig_bay_routine()
	var/datum/component/outpost_ambient_worker/rig_bay_wick/worker = wick.GetComponent(/datum/component/outpost_ambient_worker/rig_bay_wick)
	TEST_ASSERT_NOTNULL(worker, "Wick has no work routine")
	var/datum/ai_controller/basic_controller/rig_bay_wick/brain = wick.ai_controller
	TEST_ASSERT(istype(brain), "Wick has the wrong AI controller: [wick.ai_controller]")

	// His room: everything above the thresholds, less the stand and its lane
	var/list/room = worker.get_room()
	TEST_ASSERT(room[home], "Wick's spawn tile is not in his room")
	TEST_ASSERT(!room[stand_tile], "Wick's room takes in the stand")
	TEST_ASSERT(!room[lane], "Wick's room takes in the stand's front tile")
	for(var/turf/tile as anything in room)
		TEST_ASSERT(tile.y >= run_loc_floor_bottom_left.y + 2, "Wick's room runs past the threshold to [tile.x],[tile.y]")
	TEST_ASSERT_EQUAL(length(room), 13, "Wick's room has [length(room)] tiles, not 13")
	TEST_ASSERT(!worker.can_stand_at(lane), "Wick may stand on the stand's front tile")
	for(var/attempt in 1 to 30)
		var/turf/spot = worker.spot_for(mech)
		TEST_ASSERT_NOTNULL(spot, "Wick finds nowhere to stand to work on the mech")
		TEST_ASSERT(spot != lane, "Wick picked the stand's front tile to work on the mech from")

	// A player in the outpost, outside the bay, so his AI runs. No client: not a customer.
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, at(0, 0))
	present += bystander
	SSmobs.clients_by_zlevel[bystander.z] += bystander
	brain.can_idle = FALSE
	brain.reset_ai_status()
	TEST_ASSERT_EQUAL(brain.ai_status, AI_STATUS_ON, "Wick's AI does not run with a player near")

	// Free to work: he walks to the mech and works on it, and never leaves his room or stands in the lane
	worker.next_work_at = 0
	var/worked = FALSE
	for(var/beat in 1 to 60)
		sleep(0.5 SECONDS)
		check_place(wick, room, stand_tile, lane, "while working")
		if(istype(worker.work, /datum/outpost_ambient_work/mech_service))
			worked = TRUE
			break
	TEST_ASSERT(worked, "Wick never started work on the hanging mech")
	TEST_ASSERT(get_dist(wick, mech) == 1, "Wick is working on the mech from [get_dist(wick, mech)] tiles away")

	// A customer walks up: he stops, and takes no job however long they stay
	var/turf/customer_tile
	for(var/turf/tile as anything in room)
		if(tile != get_turf(wick) && get_dist(tile, wick) <= 3 && !tile.is_blocked_turf(exclude_mobs = FALSE))
			customer_tile = tile
			break
	TEST_ASSERT_NOTNULL(customer_tile, "No free tile near Wick for a customer")
	var/mob/living/carbon/human/customer = allocate(/mob/living/carbon/human/consistent, customer_tile)
	customer.mock_client = new /datum/client_interface()
	var/stopped = FALSE
	for(var/beat in 1 to 12)
		sleep(0.5 SECONDS)
		if(isnull(worker.work))
			stopped = TRUE
			break
	TEST_ASSERT(stopped, "Wick kept working with a customer [get_dist(wick, customer)] tiles away")
	for(var/beat in 1 to 16)
		// Whatever rest he was owed, he still waits on the customer
		worker.next_work_at = 0
		sleep(0.5 SECONDS)
		check_place(wick, room, stand_tile, lane, "while serving")
		TEST_ASSERT(isnull(worker.work) && isnull(worker.planned_work), "Wick took a job with a customer [get_dist(wick, customer)] tiles away")
	TEST_ASSERT_EQUAL(brain.blackboard["rig_bay_wick_customer"], customer, "Wick is not serving the customer beside him")

	// They leave: he holds off a while before the next job
	customer.mock_client = null
	qdel(customer)
	sleep(2 SECONDS)
	TEST_ASSERT(isnull(worker.work), "Wick went back to work the moment the customer left")
	TEST_ASSERT(worker.next_work_at >= world.time + 20 SECONDS, "Wick will be back at work [(worker.next_work_at - world.time) / 10] s after the customer left, not about 30 s")
	check_place(wick, room, stand_tile, lane, "after serving")

/datum/unit_test/voidcrew_rig_bay_wick/proc/check_place(mob/living/wick, list/room, turf/stand_tile, turf/lane, when)
	var/turf/here = get_turf(wick)
	TEST_ASSERT(room[here], "Wick left his room [when], to [here?.x],[here?.y]")
	TEST_ASSERT(here != lane, "Wick stood on the stand's front tile [when]")
	TEST_ASSERT(here != stand_tile, "Wick stood on the stand [when]")
