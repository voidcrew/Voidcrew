/**
 * Outpost recovery tests: spec-rehydrate.md 3.1. Owner: R3.
 *
 * A worker bags a dead NPC and the bag is gone after the lift; a dead player ends in a tray, still exists and
 * keeps every item, and never goes down a lift; a body with a conscious player within 2 tiles is skipped; a
 * living mob is never bagged (M32); the crew bag can't be folded and goes when shut empty.
 *
 * Defines are included after the tests: write values out with a comment naming the define (OUTPOST_TRADER_MOB is
 * /mob/living/carbon/human/npc/ambient_npc/outpost/trader). Police helpers: voidcrew_outpost_police_helpers.dm.
 * Tests are written, not run, by the package; the lead runs them once at integration. Each test calls the job's
 * steps directly with the mobs already in place; none waits for an AI walk.
 */

/// A morgue worker at `where`, working for `outpost`'s recovery
/datum/unit_test/proc/morgue_worker(obj/structure/overmap/trader_outpost/outpost, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue, where)
	worker.outpost_recovery = outpost.ensure_recovery()
	return worker

/// A free open tile beside `center` (cardinal), not one of `avoid`, or null
/datum/unit_test/proc/morgue_beside(turf/center, list/avoid)
	for(var/direction in GLOB.cardinals)
		var/turf/candidate = get_step(center, direction)
		if(isopenturf(candidate) && !candidate.is_blocked_turf() && !(candidate in avoid))
			return candidate
	return null

/// A concourse floor tile of `outpost` that is not one of `avoid`
/datum/unit_test/proc/morgue_floor(obj/structure/overmap/trader_outpost/outpost, list/avoid)
	for(var/i in 1 to 20)
		var/turf/tile = police_floor(outpost)
		if(tile && !(tile in avoid))
			return tile
	return null

/// A dead outpost NPC at `where`, leaving no cash
/datum/unit_test/proc/morgue_dead_npc(turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/body = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, where)
	body.death_cash_low = 0
	body.death_cash_high = 0
	body.death()
	return body

/// Bags a dead NPC, then sends it down the lift: bag and body are gone
/datum/unit_test/voidcrew_outpost_recovery_morgue_npc

/datum/unit_test/voidcrew_outpost_recovery_morgue_npc/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/datum/outpost_police/police = outpost.police
	var/turf/lift = morgue_floor(outpost)
	var/turf/body_turf = morgue_floor(outpost, list(lift))
	TEST_ASSERT_NOTNULL(body_turf, "No concourse floor for the body")
	police.lift_turfs = list(lift)
	var/mob/living/body = morgue_dead_npc(body_turf)
	recovery.npc_dead += WEAKREF(body)
	var/turf/stand = morgue_beside(body_turf, list(lift))
	TEST_ASSERT_NOTNULL(stand, "No floor beside the body")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = morgue_worker(outpost, stand)

	TEST_ASSERT(recovery.body_free(body), "A dead NPC with nobody about is not free")
	TEST_ASSERT_EQUAL(recovery.next_body(worker), body, "The worker was not given the dead NPC")
	var/datum/ambient_activity/recover_body/job = worker.start_activity(new /datum/ambient_activity/recover_body(worker))
	TEST_ASSERT_NOTNULL(job, "The worker could not start on the body")
	TEST_ASSERT_EQUAL(job.body(), body, "The job is not for the dead NPC")

	// One worker per body
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/other = morgue_worker(outpost, lift)
	TEST_ASSERT(!recovery.claim_body(body, other), "A second worker took a body already claimed")
	TEST_ASSERT_NULL(recovery.next_body(other), "A second worker was given a body already claimed")
	qdel(other)

	TEST_ASSERT(job.bag_body(), "The worker did not bag the body")
	var/obj/structure/closet/body_bag/outpost_morgue/bag = body.loc
	TEST_ASSERT(istype(bag), "The body is in [body.loc], not a crew body bag")
	TEST_ASSERT(!bag.opened, "The crew bag was left open")

	worker.forceMove(lift)
	bag.forceMove(lift)
	worker.start_pulling(bag)
	TEST_ASSERT(job.send_down(), "The bag was not sent down the lift")
	TEST_ASSERT(QDELETED(bag), "The bag is still here after the lift")
	TEST_ASSERT(QDELETED(body), "The NPC's body is still here after the lift")
	worker.end_activity()

/// A dead player is bagged, never sent down a lift, and ends in a tray with everything they carried
/datum/unit_test/voidcrew_outpost_recovery_morgue_player

/datum/unit_test/voidcrew_outpost_recovery_morgue_player/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/datum/outpost_police/police = outpost.police
	var/turf/lift = morgue_floor(outpost)
	var/turf/body_turf = morgue_floor(outpost, list(lift))
	TEST_ASSERT_NOTNULL(body_turf, "No concourse floor for the body")
	police.lift_turfs = list(lift)

	var/mob/living/carbon/human/body = allocate(/mob/living/carbon/human/consistent, body_turf)
	body.mind_initialize()
	body.equip_to_slot_or_del(new /obj/item/clothing/under/color/grey(body), ITEM_SLOT_ICLOTHING)
	body.equip_to_slot_or_del(new /obj/item/pen(body), ITEM_SLOT_LPOCKET)
	var/list/carried = body.get_all_contents_type(/obj/item)
	TEST_ASSERT(length(carried) >= 2, "The player did not get their kit")
	body.death()
	recovery.player_dead += WEAKREF(body)

	var/turf/stand = morgue_beside(body_turf, list(lift))
	TEST_ASSERT_NOTNULL(stand, "No floor beside the body")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = morgue_worker(outpost, stand)
	var/datum/ambient_activity/recover_body/job = worker.start_activity(new /datum/ambient_activity/recover_body(worker))
	TEST_ASSERT_NOTNULL(job, "The worker could not start on the player's body")
	TEST_ASSERT(job.bag_body(), "The worker did not bag the player's body")
	var/obj/structure/closet/body_bag/outpost_morgue/bag = body.loc
	TEST_ASSERT(istype(bag), "The body is in [body.loc], not a crew body bag")

	// Never down a lift
	worker.forceMove(lift)
	bag.forceMove(lift)
	worker.start_pulling(bag)
	TEST_ASSERT(!job.send_down(), "A player's body was sent down the lift")
	TEST_ASSERT(!QDELETED(body), "A player's body was deleted")
	worker.end_activity()

	// Into a tray (on the test floor: the tray step does not care where the room is)
	recovery.retry_at.Cut()
	job =worker.start_activity(new /datum/ambient_activity/recover_body(worker))
	TEST_ASSERT_NOTNULL(job, "The worker could not take the bagged body on")
	var/turf/corner = run_loc_floor_bottom_left
	var/obj/structure/bodycontainer/morgue/tray = allocate(/obj/structure/bodycontainer/morgue, locate(corner.x + 1, corner.y + 1, corner.z))
	tray.setDir(EAST)
	recovery.morgue_trays = list(tray)
	var/turf/beside_tray = locate(corner.x + 2, corner.y + 2, corner.z)
	worker.forceMove(beside_tray)
	bag.forceMove(beside_tray)
	worker.start_pulling(bag)
	job.tray_ref = WEAKREF(tray)
	TEST_ASSERT(job.put_in_tray(), "The bag did not go into the tray")
	TEST_ASSERT_EQUAL(bag.loc, tray, "The bag is not in the tray")
	TEST_ASSERT_EQUAL(body.loc, bag, "The body is not in its bag")
	TEST_ASSERT(!QDELETED(body), "A player's body was deleted")
	var/list/now_carried = body.get_all_contents()
	for(var/obj/item/item as anything in carried)
		TEST_ASSERT(!QDELETED(item) && (item in now_carried), "[item] was taken off the player's body")
	TEST_ASSERT(morgue_body_done(body), "A body in a tray is not done")
	TEST_ASSERT_NULL(recovery.next_body(worker), "A body in a tray was picked again")
	worker.end_activity()

/// The free-body rule (a conscious player within 2 tiles, the retry) and M32 (nobody living is bagged)
/datum/unit_test/voidcrew_outpost_recovery_morgue_free

/datum/unit_test/voidcrew_outpost_recovery_morgue_free/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/turf/body_turf = morgue_floor(outpost)
	TEST_ASSERT_NOTNULL(body_turf, "No concourse floor for the body")
	var/mob/living/body = morgue_dead_npc(body_turf)
	recovery.npc_dead += WEAKREF(body)
	var/turf/stand = morgue_beside(body_turf)
	TEST_ASSERT_NOTNULL(stand, "No floor beside the body")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = morgue_worker(outpost, stand)

	// A conscious player within 2 tiles (OUTPOST_RECOVERY_FREE_RANGE)
	var/mob/living/carbon/human/player = allocate(/mob/living/carbon/human/consistent, body_turf)
	player.mock_client = allocate(/datum/client_interface)
	TEST_ASSERT(!recovery.body_free(body), "A body with a conscious player beside it is free")
	TEST_ASSERT_NULL(recovery.next_body(worker), "A body with a conscious player beside it was picked")
	TEST_ASSERT(recovery.retry_at[WEAKREF(body)] > world.time, "A body that was not free has no retry time")
	var/turf/far
	for(var/i in 1 to 30)
		var/turf/tile = police_floor(outpost)
		if(tile && get_dist(tile, body_turf) > 3)
			far = tile
			break
	TEST_ASSERT_NOTNULL(far, "No concourse floor away from the body")
	player.forceMove(far)
	TEST_ASSERT(recovery.body_free(body), "The body is not free with the player gone")
	TEST_ASSERT_NULL(recovery.next_body(worker), "A body was picked before its retry time (OUTPOST_RECOVERY_BODY_RETRY)")
	recovery.retry_at.Cut()
	TEST_ASSERT_EQUAL(recovery.next_body(worker), body, "The body was not picked once free")

	// M32: someone alive on the body's tile is never bagged with it, and is never free
	var/mob/living/carbon/human/bystander = allocate(/mob/living/carbon/human/consistent, body_turf)
	TEST_ASSERT(!recovery.body_free(bystander), "A living person counts as a free body")
	var/datum/ambient_activity/recover_body/job = worker.start_activity(new /datum/ambient_activity/recover_body(worker))
	TEST_ASSERT_NOTNULL(job, "The worker could not start on the body")
	TEST_ASSERT(job.bag_body(), "The worker did not bag the body")
	TEST_ASSERT(istype(body.loc, /obj/structure/closet/body_bag/outpost_morgue), "The body is not in a crew bag")
	TEST_ASSERT(isturf(bystander.loc), "A living person was bagged with the body")
	worker.end_activity()

	// The crew bag can't be folded, and goes once shut with nothing in it
	var/obj/structure/closet/body_bag/outpost_morgue/bag = body.loc
	TEST_ASSERT(!bag.attempt_fold(worker), "A crew bag can be folded into an item")
	var/obj/structure/closet/body_bag/outpost_morgue/empty_bag = allocate(/obj/structure/closet/body_bag/outpost_morgue, run_loc_floor_bottom_left)
	empty_bag.open()
	empty_bag.close()
	TEST_ASSERT(QDELETED(empty_bag), "An empty crew bag stayed after it was shut")
