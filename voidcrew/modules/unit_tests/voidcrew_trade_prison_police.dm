/**
 * The outpost lockup and the outpost's police and recovery crews (outpost_prison_police.dm, police_dispatch.dm,
 * recovery_*.dm).
 *
 * Voidcrew defines are included after the unit tests, so literal values appear with a comment naming the define.
 */

/datum/unit_test/voidcrew_trade_prison_police
	parent_type = /datum/unit_test/voidcrew_outpost_management

/// Ticks Processing until `door` reaches `open` (TRUE = open, FALSE = shut), asserting the two doors are never open together
/datum/unit_test/voidcrew_trade_prison_police/proc/cross_wait_door(datum/outpost_prison/prison, obj/machinery/door/airlock/door, open, seconds = 12)
	var/obj/machinery/door/airlock/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = prison.processing_door(FALSE)
	for(var/i in 1 to seconds * 2)
		TEST_ASSERT(inner.density || outer.density, "Both of Processing's doors were open at once")
		if(!door.operating && (open ? !door.density : door.density))
			return TRUE
		if(i % 2)
			prison.processing_tick(1)
		sleep(0.5 SECONDS)
	return FALSE

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

	// Response officer in the front room is kept, directed searching for a loose prisoner inside the wing, and cycled through Processing one door at a time
	var/turf/office_tile = prison.guard_office_spot()
	TEST_ASSERT_NOTNULL(office_tile, "No open office tile found in the lockup")
	runner.forceMove(office_tile)
	officer.dispatch_wave = wave
	TEST_ASSERT(police.lockup_keeps_officer(officer), "A response officer in the lockup was not kept while a prisoner was loose")
	TEST_ASSERT(police.lockup_direct_officer(officer), "An idle response officer in the front room was not sent searching for a loose prisoner")
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	TEST_ASSERT_EQUAL(brain.stealth_state(), "searching", "Directing the response officer did not put them into searching") // STEALTH_SEARCHING
	var/datum/ai_planning_subtree/outpost_police_lockup_cross/cross_tree = locate() in brain.planning_subtrees
	TEST_ASSERT_NOTNULL(cross_tree, "An officer's brain has no lockup-crossing subtree")
	brain.planned_behaviors.Cut()
	cross_tree.SelectBehaviors(brain, 1)
	TEST_ASSERT((locate(/datum/ai_behavior/outpost_police_lockup_step) in brain.planned_behaviors) || (locate(/datum/ai_behavior/stealth_stand) in brain.planned_behaviors), "The lockup-crossing subtree did not plan a step toward Processing")
	brain.planned_behaviors.Cut()

	ADD_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))
	var/obj/machinery/door/airlock/security/prison_staff/inner = prison.processing_door(TRUE)
	var/obj/machinery/door/airlock/security/prison_staff/outer = prison.processing_door(FALSE)
	var/turf/outer_wait = prison.processing_outside_turf(outer)
	var/turf/inner_wait = prison.processing_outside_turf(inner)
	TEST_ASSERT_NOTNULL(outer_wait, "Processing's outer door has no front-room approach tile")
	TEST_ASSERT_NOTNULL(inner_wait, "Processing's inner door has no yard-side approach tile")
	officer.forceMove(outer_wait)
	TEST_ASSERT_EQUAL(prison.processing_step_through(officer, TRUE), outer_wait, "An officer outside Processing did not wait at the outer door while it opened")
	TEST_ASSERT_EQUAL(prison.processing_state, "crossing", "Processing did not enter crossing state for the officer") // OUTPOST_PROCESSING_CROSS
	TEST_ASSERT(cross_wait_door(prison, outer, TRUE), "Processing's outer door did not open for the crossing officer")
	var/turf/inside_step = prison.processing_step_through(officer, TRUE)
	TEST_ASSERT(prison.in_processing(inside_step), "Processing did not step the officer into the sally port once the outer door opened")
	officer.forceMove(inside_step)
	TEST_ASSERT(cross_wait_door(prison, outer, FALSE), "Processing's outer door did not shut behind the crossing officer")
	TEST_ASSERT(cross_wait_door(prison, inner, TRUE), "Processing's inner door did not open once the outer door shut")
	TEST_ASSERT_EQUAL(prison.processing_step_through(officer, TRUE), inner_wait, "Processing did not step the officer out into the yard")
	officer.forceMove(inner_wait)
	prison.processing_tick(1)
	TEST_ASSERT_EQUAL(prison.processing_state, "idle", "Processing did not return to idle once the officer reached the yard") // OUTPOST_PROCESSING_IDLE
	TEST_ASSERT(cross_wait_door(prison, inner, FALSE), "Processing's inner door did not shut after the officer entered the yard")

	// Once the last loose prisoner is back in custody, the response officer is no longer kept and crosses back to the front room
	runner.forceMove(yard_tile)
	runner.back_in_custody()
	TEST_ASSERT(!police.lockup_keeps_officer(officer), "A response officer stayed kept in the lockup with no loose prisoners left")
	TEST_ASSERT_EQUAL(prison.processing_step_through(officer, FALSE), inner_wait, "An officer leaving the yard did not wait at Processing's inner door")
	TEST_ASSERT(cross_wait_door(prison, inner, TRUE), "Processing's inner door did not open for the officer leaving the yard")
	officer.forceMove(prison.processing_step_through(officer, FALSE))
	TEST_ASSERT(cross_wait_door(prison, inner, FALSE), "Processing's inner door did not shut behind the leaving officer")
	TEST_ASSERT(cross_wait_door(prison, outer, TRUE), "Processing's outer door did not open for the leaving officer")
	TEST_ASSERT_EQUAL(prison.processing_step_through(officer, FALSE), outer_wait, "Processing did not step the leaving officer into the front room")
	officer.forceMove(outer_wait)
	prison.processing_tick(1)
	TEST_ASSERT(prison.in_front_room(outer_wait) && cross_wait_door(prison, outer, FALSE), "Processing did not return the officer to the front room with both doors shut")
	REMOVE_TRAIT(officer, TRAIT_AI_PAUSED, REF(src))

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
