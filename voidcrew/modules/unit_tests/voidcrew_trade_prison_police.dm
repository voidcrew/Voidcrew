/**
 * The outpost lockup and the outpost's police and recovery crews (outpost_prison_police.dm, police_dispatch.dm,
 * recovery_*.dm).
 *
 * Voidcrew defines are included after the unit tests, so literal values appear with a comment naming the define.
 */

/datum/unit_test/voidcrew_trade_prison_police
	parent_type = /datum/unit_test/voidcrew_outpost_management

/datum/unit_test/voidcrew_trade_prison_police/Run()
	var/obj/structure/overmap/trader_outpost/outpost = lockup_test_outpost()
	TEST_ASSERT_NOTNULL(outpost, "Quartermain Depot's interior did not load")
	var/datum/outpost_prison/prison = outpost.prison
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(prison, "Quartermain Depot has no lockup")
	TEST_ASSERT_NOTNULL(police, "Quartermain Depot has no police")

	var/turf/alcove_tile = prison.alcove_turfs[5]
	var/turf/front_tile
	for(var/turf/tile as anything in lockup_flood(prison.alcove_turfs[1], doors_open = FALSE))
		if(!(tile in prison.alcove_turfs) && tile != prison.claim_turf && !tile.is_blocked_turf())
			front_tile = tile
			break
	var/turf/yard_tile
	for(var/turf/tile as anything in prison.cell_block)
		if(!prison.cell_at(tile) && isopenturf(tile) && !tile.is_blocked_turf())
			yard_tile = tile
			break
	var/turf/lobby_tile = outpost.lobby_alcove_turfs[1]
	TEST_ASSERT_NOTNULL(front_tile, "No open front room tile found in the lockup")
	TEST_ASSERT_NOTNULL(yard_tile, "No open yard tile found in the lockup")
	TEST_ASSERT_NOTNULL(lobby_tile, "No lobby alcove tile found at the outpost")

	// The wing is a police sector of its own, ahead of the lobby check, with its alcove as its lift
	TEST_ASSERT_EQUAL(police.sector_of(yard_tile), prison, "A yard tile's police sector is not the lockup")
	TEST_ASSERT_EQUAL(police.sector_of(front_tile), prison, "A front room tile's police sector is not the lockup")
	TEST_ASSERT_EQUAL(police.sector_of(alcove_tile), prison, "A lockup alcove tile's police sector is not the lockup")
	TEST_ASSERT_EQUAL(police.sector_of(lobby_tile), "lobby", "A lobby tile's police sector changed from lobby") // POLICE_SECTOR_LOBBY
	TEST_ASSERT_EQUAL(police.dispatch_lift_tiles(prison), prison.alcove_turfs, "The lockup sector's lift tiles are not its alcove")
	TEST_ASSERT(police.dispatch_is_lift_tile(alcove_tile), "A lockup alcove tile is not a police lift tile")
	TEST_ASSERT(!police.dispatch_is_lift_tile(front_tile), "A front room tile outside the alcove counted as a lift tile")
	TEST_ASSERT_EQUAL(police.dispatch_elevator_floor(prison), 90, "The lockup sector's elevator floor is not 90") // OUTPOST_LIFT_LOCKUP
	TEST_ASSERT(prison.lift_panel in police.cameras(), "The lockup's lift panel is not a police witness camera")

	// Beat and idle ground never picks inside the lockup; a quiet yard prisoner is not hostile to an officer
	dispatch_clear(police)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, front_tile)
	TEST_ASSERT(!officer.standable(yard_tile) && !officer.standable(front_tile), "An officer picked a lockup tile as standable beat ground")
	var/mob/living/carbon/human/npc/outpost_prisoner/quiet = trouble_prisoner(prison, yard_tile)
	var/mob/living/carbon/human/npc/outpost_prisoner/runner = trouble_prisoner(prison, yard_tile)
	TEST_ASSERT(!is_hostile_creature(quiet), "A quiet prisoner in the yard counted as a hostile creature")
	TEST_ASSERT(officer.faction_check_atom(quiet), "An officer treated a quiet prisoner as outside neutral faction")
	TEST_ASSERT(!officer.police_will_fight(quiet), "An officer wanted to fight a quiet prisoner in the yard")
	qdel(officer)
	dispatch_clear(police)

	// Going loose with an audience orders one unit to the wing's alcove, and a second runner in the same riot orders none
	prison.trouble_enabled = TRUE
	TEST_ASSERT(breakout_riot(prison), "The riot did not start")
	TEST_ASSERT(!is_hostile_creature(runner), "A rioting prisoner still inside the cell block counted as loose")
	TEST_ASSERT_EQUAL(length(police.dispatch_orders), 0, "A riot inside the cell block ordered police before anyone got loose")

	runner.forceMove(front_tile)
	prison.tick(1)
	TEST_ASSERT_EQUAL(runner.trouble, "loose", "A rioter in the front room did not go loose") // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT(prison.riot_police_called, "Going loose with an audience did not set the riot police latch")
	TEST_ASSERT_EQUAL(length(police.dispatch_orders), 1, "One prisoner going loose ordered [length(police.dispatch_orders)] units, not 1")
	TEST_ASSERT_EQUAL(length(police.dispatch_waves), 1, "Going loose did not create one dispatch wave for the lockup")
	var/datum/outpost_police_wave/wave = police.dispatch_waves[1]
	TEST_ASSERT_EQUAL(wave.sector, prison, "The riot response wave was sent to [wave.sector], not the lockup")
	TEST_ASSERT(wave.point in prison.alcove_turfs, "The riot response wave's arrival point is not in the lockup's alcove")

	quiet.forceMove(front_tile)
	prison.tick(1)
	TEST_ASSERT_EQUAL(quiet.trouble, "loose", "The second rioter in the front room did not go loose") // PRISONER_TROUBLE_LOOSE
	TEST_ASSERT_EQUAL(length(police.dispatch_orders), 1, "A second prisoner going loose in the same riot ordered another unit")

	// A loose prisoner is hostile to an officer (even inside the lockup's front room); back in custody in the yard, not
	officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, front_tile)
	TEST_ASSERT(is_hostile_creature(runner), "A loose prisoner in the front room did not count as a hostile creature")
	TEST_ASSERT(!officer.faction_check_atom(runner), "An officer passed over a loose prisoner as a neutral ally")
	TEST_ASSERT(officer.police_will_fight(runner), "An officer would not fight a loose prisoner")
	TEST_ASSERT_EQUAL(officer.force_for(runner), 3, "An officer's force against a loose prisoner is [officer.force_for(runner)], not lethal (3)") // POLICE_FORCE_LETHAL
	quiet.forceMove(yard_tile)
	quiet.back_in_custody()
	TEST_ASSERT(!is_hostile_creature(quiet) && !officer.police_will_fight(quiet), "A recaptured prisoner in the yard stayed hostile to police")

	// Recovery skips bodies, the downed and mess inside the lockup
	var/datum/outpost_recovery/recovery = outpost.ensure_recovery()
	var/mob/living/wing_body = morgue_dead_npc(yard_tile)
	TEST_ASSERT(!(WEAKREF(wing_body) in recovery.npc_dead), "An NPC death inside the lockup was tracked by outpost recovery")
	recovery.npc_dead += WEAKREF(wing_body)
	TEST_ASSERT(!(wing_body in recovery.npc_bodies()), "A dead NPC in the lockup appeared in the morgue crew's list")
	var/turf/concourse_tile = morgue_floor(outpost)
	TEST_ASSERT_NOTNULL(concourse_tile, "No concourse floor found for the morgue worker")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue/worker = morgue_worker(outpost, concourse_tile)
	TEST_ASSERT_NULL(recovery.next_body(worker), "A morgue worker was given a dead NPC inside the lockup")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/downed = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost, yard_tile)
	downed.adjustBruteLoss(120)
	TEST_ASSERT(recovery_in_crit(downed), "Setup: 120 brute damage did not put the outpost NPC into crit")
	TEST_ASSERT(!(downed in recovery.patients()), "An outpost NPC in crit inside the lockup appeared on the medics' list")

	recovery.npc_dead.Cut()
	recovery.sleep_tick()
	prison.admin_calm()
	dispatch_clear(police)
