/**
 * Outpost recovery tests: spec-rehydrate.md 2 and 4 (recovery_core.dm). Owner: R2.
 *
 * The state table row by row with pinned times, the quiet clock, the 4.2 ladder, the crew wave's make-up, the body
 * cap (removes the oldest NPC body, never a player), the corpse-sweep switch and its fallback, the paused clock, the
 * loss cap, and R0's link_rooms() with a hand-placed morgue and closet.
 *
 * Defines are included after the tests: write values out with a comment naming the define. Police helpers:
 * voidcrew_outpost_police_helpers.dm; fake outposts: voidcrew_outpost_police_wanted.dm (wanted_outpost()).
 * Every test here writes the clocks (last_death_at, quiet_since, next_wave_at) and calls tick() by hand; none waits.
 * Tests are written, not run, by the package; the lead runs them once at integration.
 */

// ===== FIXTURES =====

/// A fake trader outpost (wanted_outpost()) whose ambient place is made and occupied, so the recovery's clock runs
/datum/unit_test/proc/recovery_outpost()
	var/obj/structure/overmap/trader_outpost/outpost = wanted_outpost()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	place.occupied = TRUE
	return outpost

/// A customer at `where` in `outpost`'s box, killed for real so the death signal reaches the police and the recovery
/datum/unit_test/proc/recovery_corpse(obj/structure/overmap/trader_outpost/outpost, turf/where)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, where)
	body.set_place(SSambient_npcs.outpost_place(outpost))
	body.death()
	return body

/// A morgue worker or janitor of the recovery's current wave, alive at `where`
/datum/unit_test/proc/recovery_worker(obj/structure/overmap/trader_outpost/outpost, turf/where, crew_type = /mob/living/carbon/human/npc/ambient_npc/outpost/recovery/morgue)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = allocate(crew_type, where)
	worker.set_place(SSambient_npcs.outpost_place(outpost))
	worker.outpost_recovery = outpost.recovery
	var/datum/weakref/worker_ref = WEAKREF(worker)
	outpost.recovery.crew += worker_ref
	outpost.recovery.wave_workers += worker_ref
	return worker

// ===== THE STATE TABLE =====

/// NORMAL -> TROUBLE -> CLEANUP -> RESTAFF -> REFILL -> NORMAL, each step on its own condition and clock
/datum/unit_test/voidcrew_outpost_recovery_states

/datum/unit_test/voidcrew_outpost_recovery_states/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	TEST_ASSERT_NOTNULL(recovery, "A trader outpost has no recovery")
	TEST_ASSERT_EQUAL(recovery.state, 0, "A new recovery is not NORMAL") // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT_NULL(recovery.tick_timer, "A NORMAL recovery has a running tick")

	// NORMAL -> TROUBLE: an NPC dies in the box. Its body is the crews' now: no corpse sweep.
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = recovery_corpse(outpost, wanted_spot(1, 1))
	TEST_ASSERT_EQUAL(recovery.state, 1, "An NPC death did not make trouble") // OUTPOST_RECOVERY_TROUBLE
	TEST_ASSERT(WEAKREF(body) in recovery.npc_dead, "A dead NPC is not on the outpost's list")
	TEST_ASSERT_EQUAL(body.npc_corpse_lifetime, 0, "A dead outpost NPC still has a corpse timer")
	TEST_ASSERT(!(body in SShuman_npcs.corpses), "A dead outpost NPC is on the base corpse sweep")
	TEST_ASSERT_NOTNULL(recovery.tick_timer, "Trouble did not start the tick")
	TEST_ASSERT_EQUAL(recovery.last_death_at, world.time, "The death time was not noted")

	// TROUBLE holds while anyone at the outpost has stars, however long ago the death was
	var/mob/living/carbon/human/offender = wanted_person(wanted_spot(5, 5))
	police_pin_warrant(outpost.police, offender.mind, 50)
	recovery.last_death_at = world.time - 10 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 1, "Stars at the outpost did not hold TROUBLE")
	TEST_ASSERT(!recovery.is_quiet(), "An outpost with a wanted person is quiet")
	TEST_ASSERT_EQUAL(recovery.last_shot_at, world.time, "Stars did not push the quiet clock")

	// ...and so does a death less than two minutes ago
	outpost.police.warrants -= offender.mind
	recovery.last_shot_at = world.time - 10 MINUTES
	recovery.last_death_at = world.time - 119 SECONDS // OUTPOST_RECOVERY_QUIET_TIME is 2 minutes
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 1, "A death 119 seconds ago was quiet")
	TEST_ASSERT(!recovery.is_quiet(), "119 seconds is quiet")

	// TROUBLE -> CLEANUP at two minutes: quiet
	recovery.last_death_at = world.time - 2 MINUTES
	TEST_ASSERT(recovery.is_quiet(), "Two minutes with no stars and no death is not quiet")
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "Quiet did not start the cleanup") // OUTPOST_RECOVERY_CLEANUP
	TEST_ASSERT_EQUAL(recovery.quiet_since, world.time, "The cleanup does not know when it went quiet")

	// CLEANUP waits while a body lies there, and calls no wave in the first minute
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "The cleanup ended with a body on the floor")
	TEST_ASSERT(!recovery.wave_active, "A wave was called in the first minute after quiet")
	// A stranger with stars comes back: CLEANUP goes back to TROUBLE
	police_pin_warrant(outpost.police, offender.mind, 30)
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 1, "Stars during the cleanup did not bring TROUBLE back")
	TEST_ASSERT_EQUAL(recovery.quiet_since, 0, "TROUBLE kept the old quiet time")
	outpost.police.warrants -= offender.mind
	recovery.last_shot_at = world.time - 10 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "The outpost did not go quiet again")

	// CLEANUP -> RESTAFF: the body is gone and every stop is clean (R4's stub: all of them)
	qdel(body)
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 3, "No body and clean stops did not end the cleanup") // OUTPOST_RECOVERY_RESTAFF
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 0, "A deleted body is still on the list")

	// RESTAFF -> REFILL: every counter is kept (this outpost has none)
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 4, "A kept outpost did not move on to REFILL") // OUTPOST_RECOVERY_REFILL

	// REFILL -> NORMAL: every role filled, or twenty minutes
	recovery.refill_started_at = world.time - 20 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 0, "REFILL did not end") // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT_NULL(recovery.tick_timer, "A NORMAL recovery left its tick running")

/// Abuse MF4: a wanted person logged off (or sat in their docked ship) holds TROUBLE three minutes at most; at the keys on the outpost's floor, as long as they stay
/datum/unit_test/voidcrew_outpost_recovery_stars_away

/datum/unit_test/voidcrew_outpost_recovery_stars_away/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery_corpse(outpost, wanted_spot(1, 1))
	TEST_ASSERT_EQUAL(recovery.state, 1, "An NPC death did not make trouble") // OUTPOST_RECOVERY_TROUBLE
	var/mob/living/carbon/human/offender = wanted_person(wanted_spot(5, 5))
	police_pin_warrant(outpost.police, offender.mind, 100)
	recovery.last_death_at = world.time - 10 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 1, "A wanted person on the floor did not hold TROUBLE")
	TEST_ASSERT_EQUAL(length(recovery.stars_away), 0, "A wanted person at the keys on the floor was counted as away")

	// Logged off where they stand: they hold it for a while, then not
	offender.mind.key = "outpost_recovery_test_ssd"
	TEST_ASSERT(recovery.stars_present(), "A wanted person just logged off no longer holds TROUBLE")
	TEST_ASSERT(offender.mind in recovery.stars_away, "A logged off wanted person was not noted as away")
	recovery.stars_away[offender.mind] = world.time - 3 MINUTES // RECOVERY_STARS_AWAY_MAX
	TEST_ASSERT(!recovery.stars_present(), "A wanted person logged off for three minutes still holds TROUBLE")
	recovery.last_shot_at = world.time - 10 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "TROUBLE did not end with only a long logged off wanted person about") // OUTPOST_RECOVERY_CLEANUP

	// Back at the keys: they hold it again, and the away clock starts over next time
	offender.mind.key = null
	TEST_ASSERT(recovery.stars_present(), "A wanted person back at the keys does not hold TROUBLE")
	TEST_ASSERT(!(offender.mind in recovery.stars_away), "A wanted person back at the keys is still counted as away")
	outpost.police.warrants -= offender.mind

/// CLEANUP is over fifteen minutes after quiet at the latest, body or no body
/datum/unit_test/voidcrew_outpost_recovery_cleanup_cap

/datum/unit_test/voidcrew_outpost_recovery_cleanup_cap/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = recovery_corpse(outpost, wanted_spot(1, 1))
	recovery.last_death_at = world.time - 3 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "The outpost did not go quiet") // OUTPOST_RECOVERY_CLEANUP
	recovery.quiet_since = world.time - 15 MINUTES + 1 SECONDS // OUTPOST_RECOVERY_CLEANUP_MAX
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 2, "The cleanup ended before fifteen minutes with a body about")
	TEST_ASSERT_NOTNULL(body, "The test body is gone")
	recovery.quiet_since = world.time - 15 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 3, "The cleanup did not end after fifteen minutes") // OUTPOST_RECOVERY_RESTAFF

// ===== THE SWEEP SWITCH =====

/// The outpost's dead are off the 10 minute corpse sweep; a body nobody collected goes back to it after 20 minutes of quiet, and at NORMAL
/datum/unit_test/voidcrew_outpost_recovery_sweep

/datum/unit_test/voidcrew_outpost_recovery_sweep/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = recovery_corpse(outpost, wanted_spot(1, 1))
	TEST_ASSERT_EQUAL(body.npc_corpse_lifetime, 0, "The outpost's dead have a corpse timer")
	var/mob/living/carbon/human/dead_player = wanted_person(wanted_spot(2, 2))
	dead_player.death()
	TEST_ASSERT(WEAKREF(dead_player) in recovery.player_dead, "A dead player is not on the outpost's list")
	TEST_ASSERT(!(WEAKREF(dead_player) in recovery.npc_dead), "A dead player is on the NPC list")

	recovery.quiet_since = world.time - 19 MINUTES
	recovery.hand_back_bodies()
	TEST_ASSERT_EQUAL(body.npc_corpse_lifetime, 0, "A body went back to the sweep before twenty minutes")
	recovery.quiet_since = world.time - 20 MINUTES // OUTPOST_RECOVERY_SWEEP_FALLBACK
	recovery.hand_back_bodies()
	TEST_ASSERT_EQUAL(body.npc_corpse_lifetime, 6000, "A body left over after twenty minutes was not handed back") // HUMAN_NPC_CORPSE_LIFETIME is 10 minutes
	TEST_ASSERT(body in SShuman_npcs.corpses, "A handed-back body is not on the corpse sweep")
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 0, "A handed-back body is still on the outpost's list")
	TEST_ASSERT(WEAKREF(dead_player) in recovery.player_dead, "A player's body was handed to the sweep")

	// Back to NORMAL hands back whatever is left
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/second = recovery_corpse(outpost, wanted_spot(2, 1))
	TEST_ASSERT_EQUAL(second.npc_corpse_lifetime, 0, "A second death left a corpse timer")
	recovery.set_state(0) // OUTPOST_RECOVERY_NORMAL
	TEST_ASSERT_EQUAL(second.npc_corpse_lifetime, 6000, "NORMAL did not hand the last body back") // HUMAN_NPC_CORPSE_LIFETIME

/// A body its own system cleans up (corpse timer 0 already) is not the crews'
/datum/unit_test/voidcrew_outpost_recovery_foreign_body

/datum/unit_test/voidcrew_outpost_recovery_foreign_body/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	// A human NPC that is not an ambient outpost person and cleans itself up
	var/mob/living/carbon/human/npc/stranger = allocate(/mob/living/carbon/human/npc, wanted_spot(1, 1))
	stranger.npc_corpse_lifetime = 0
	stranger.death()
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 0, "A body with its own cleanup is on the outpost's list")
	TEST_ASSERT_EQUAL(recovery.state, 0, "A body with its own cleanup made trouble") // OUTPOST_RECOVERY_NORMAL
	// ...and one outside the box (a hangar, a ship) is left to the base sweep
	var/mob/living/carbon/human/npc/outsider = allocate(/mob/living/carbon/human/npc, wanted_spot(30, 30))
	outsider.death()
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 0, "A body outside the outpost is on its list")

/// Abuse SF3: an NPC body a player is in is a person's body, never on the NPC list; nobody in what an NPC body holds goes down the lift with it
/datum/unit_test/voidcrew_outpost_recovery_player_in_npc

/datum/unit_test/voidcrew_outpost_recovery_player_in_npc/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/possessed = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, wanted_spot(1, 1))
	possessed.set_place(SSambient_npcs.outpost_place(outpost))
	possessed.mind_initialize()
	allocated += possessed.mind
	possessed.death()
	TEST_ASSERT(!(WEAKREF(possessed) in recovery.npc_dead), "An NPC body a player was in is on the NPC list")
	TEST_ASSERT(WEAKREF(possessed) in recovery.player_dead, "An NPC body a player was in is not kept as a person's")

	// A box in an NPC's hand with a person in it comes out before the body goes (alive here: a death would drop it anyway)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/carrier = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, wanted_spot(2, 2))
	var/obj/item/storage/box/box = allocate(/obj/item/storage/box)
	TEST_ASSERT(carrier.put_in_hands(box), "Setup: the NPC could not hold the box")
	var/mob/living/carbon/human/stowaway = wanted_person(wanted_spot(2, 2))
	stowaway.forceMove(box)
	morgue_drop_persons(carrier, wanted_spot(3, 3))
	TEST_ASSERT_EQUAL(box.loc, wanted_spot(3, 3), "Something holding a person stayed on an NPC body")
	TEST_ASSERT_EQUAL(stowaway.loc, box, "The person was taken out of what held them")
	stowaway.forceMove(wanted_spot(3, 3))

// ===== THE BODY CAP =====

/// 24 NPC bodies at most (officers' included): the 25th takes the oldest, a player's body is never touched
/datum/unit_test/voidcrew_outpost_recovery_body_cap

/datum/unit_test/voidcrew_outpost_recovery_body_cap/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/list/players = list()
	for(var/i in 1 to 3)
		var/mob/living/carbon/human/player = wanted_person(wanted_spot(i, 0))
		player.death()
		players += player
	var/list/mob/living/carbon/human/npc/bodies = list()
	for(var/i in 1 to 26)
		bodies += recovery_corpse(outpost, wanted_spot(i % 4, 2))
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 26, "Not every NPC death was noted")
	recovery.enforce_body_cap()
	TEST_ASSERT_EQUAL(length(recovery.npc_dead), 24, "The cap did not bring the bodies down to 24") // OUTPOST_RECOVERY_BODY_CAP
	TEST_ASSERT(QDELETED(bodies[1]) && QDELETED(bodies[2]), "The two oldest bodies were not collected")
	TEST_ASSERT(!QDELETED(bodies[3]) && !QDELETED(bodies[26]), "The cap took a newer body")
	for(var/mob/living/carbon/human/player as anything in players)
		TEST_ASSERT(!QDELETED(player), "The body cap deleted a player's body")
	TEST_ASSERT_EQUAL(length(recovery.player_dead), 3, "The body cap changed the player list")

	// An officer's body is one of the 24
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/beat/officer = police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, wanted_spot(3, 3))
	officer.death()
	TEST_ASSERT(WEAKREF(officer) in recovery.npc_dead, "A dead officer is not on the outpost's list")
	TEST_ASSERT_EQUAL(officer.npc_corpse_lifetime, 0, "A dead officer kept the police's own three minute timer")

// ===== THE LADDER =====

/// 4.2: crews killed in a row delay the next wave (2, 4, 8 minutes), bring a bigger escort, and the fourth shuts the port
/datum/unit_test/voidcrew_outpost_recovery_ladder

/datum/unit_test/voidcrew_outpost_recovery_ladder/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery_corpse(outpost, wanted_spot(1, 1)) // something for a crew to do
	// Pinned: delay (OUTPOST_RECOVERY_LOST_DELAYS), escort (OUTPOST_RECOVERY_LOST_ESCORTS), and kind for the wave after each loss
	var/list/delays = list(2 MINUTES, 4 MINUTES, 8 MINUTES)
	var/list/escorts = list(2, 4, 4)

	// The first wave: no officer alive, so an escort of two
	recovery.call_wave()
	TEST_ASSERT(recovery.wave_active, "A body on the floor called no wave")
	TEST_ASSERT_EQUAL(recovery.wave_escort_size, 2, "The first wave with no officer alive has no escort of two") // OUTPOST_RECOVERY_ESCORT
	TEST_ASSERT_EQUAL(recovery.wave_escort_kind, "officer", "The first escort is not response officers") // POLICE_UNIT_OFFICER
	// A second call while the wave is out does nothing
	var/first_wave = recovery.wave_number
	recovery.call_wave()
	TEST_ASSERT_EQUAL(recovery.wave_number, first_wave, "A wave was called while one was out")

	for(var/lost in 1 to 3)
		recovery.wave_morgue_left = 0
		recovery.wave_janitors_left = 0
		var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = recovery_worker(outpost, wanted_spot(lost, 3))
		worker.death()
		TEST_ASSERT_EQUAL(recovery.waves_lost, lost, "Wave [lost] lost counted as [recovery.waves_lost]")
		TEST_ASSERT(!recovery.wave_active, "A lost wave is still out")
		TEST_ASSERT(abs(recovery.next_wave_at - (world.time + delays[lost])) <= 10, "The wave after loss [lost] does not wait [delays[lost] / 600] minutes")
		// Counting the same death again changes nothing
		recovery.crew_lost(worker)
		TEST_ASSERT_EQUAL(recovery.waves_lost, lost, "A worker was counted twice")
		// Too early: nothing
		recovery.call_wave()
		TEST_ASSERT(!recovery.wave_active, "A wave came before its delay")
		recovery.next_wave_at = world.time
		recovery.call_wave()
		TEST_ASSERT(recovery.wave_active, "The wave after loss [lost] did not come on time")
		TEST_ASSERT_EQUAL(recovery.wave_escort_size, escorts[lost], "The wave after loss [lost] has an escort of [recovery.wave_escort_size]")
		TEST_ASSERT_EQUAL(recovery.wave_escort_kind, lost >= 3 ? "tactical" : "officer", "The wave after loss [lost] has the wrong escort kind") // POLICE_UNIT_TACTICAL, POLICE_UNIT_OFFICER

	// The fourth loss shuts the port for fifteen minutes and starts the ladder again at its first row
	recovery.wave_morgue_left = 0
	recovery.wave_janitors_left = 0
	recovery_worker(outpost, wanted_spot(0, 3)).death()
	TEST_ASSERT(abs(recovery.port_shut_until - (world.time + 15 MINUTES)) <= 10, "The fourth loss did not shut the port for fifteen minutes") // OUTPOST_RECOVERY_PORT_SHUT_TIME
	TEST_ASSERT_EQUAL(recovery.waves_lost, 1, "The ladder did not start again at its first row")
	recovery.next_wave_at = 0
	recovery.call_wave()
	TEST_ASSERT(!recovery.wave_active, "A wave came while the port was shut")
	recovery.port_shut_until = world.time - 1
	recovery.next_wave_at = 0
	recovery.call_wave()
	TEST_ASSERT(recovery.wave_active, "No wave came after the port opened")
	TEST_ASSERT_EQUAL(recovery.wave_escort_size, 2, "The first wave after the shut has no escort of two")

/// A wave that is still at work at the end of the cleanup did its job: the ladder starts again
/datum/unit_test/voidcrew_outpost_recovery_ladder_resets

/datum/unit_test/voidcrew_outpost_recovery_ladder_resets/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery.waves_lost = 2
	recovery.wave_active = TRUE
	recovery.state = 2 // OUTPOST_RECOVERY_CLEANUP
	recovery.quiet_since = world.time - 15 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 3, "The cleanup did not end") // OUTPOST_RECOVERY_RESTAFF
	TEST_ASSERT_EQUAL(recovery.waves_lost, 0, "A wave that did its work left the ladder where it was")
	TEST_ASSERT(!recovery.wave_active, "The wave is still out after the cleanup")

// ===== THE WAVE'S MAKE-UP =====

/// Two morgue workers and two janitors; four and four past twelve bodies; the escort follows whether an officer is alive; nothing to do, no wave
/datum/unit_test/voidcrew_outpost_recovery_wave_makeup

/datum/unit_test/voidcrew_outpost_recovery_wave_makeup/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery.call_wave()
	TEST_ASSERT(!recovery.wave_active, "A wave was called with nothing to do")

	for(var/i in 1 to 3)
		recovery_corpse(outpost, wanted_spot(i, 1))
	recovery.call_wave()
	TEST_ASSERT(recovery.wave_active, "Three bodies called no wave")
	TEST_ASSERT_EQUAL(recovery.wave_morgue_left, 2, "A normal wave is not two morgue workers") // OUTPOST_RECOVERY_CREW_SMALL
	TEST_ASSERT_EQUAL(recovery.wave_janitors_left, 2, "A normal wave is not two janitors")
	TEST_ASSERT_EQUAL(recovery.wave_escort_size, 2, "No officer alive and no escort of two")


/// More than twelve bodies: a double crew; an officer alive: no escort
/datum/unit_test/voidcrew_outpost_recovery_wave_big

/datum/unit_test/voidcrew_outpost_recovery_wave_big/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	police_officer(outpost, /mob/living/carbon/human/npc/ambient_npc/outpost/police/beat, wanted_spot(0, 0))
	for(var/i in 1 to 13)
		recovery_corpse(outpost, wanted_spot(i % 4, 1))
	recovery.call_wave()
	TEST_ASSERT(recovery.wave_active, "Thirteen bodies called no wave")
	TEST_ASSERT_EQUAL(recovery.wave_morgue_left, 4, "A big wave is not four morgue workers") // OUTPOST_RECOVERY_CREW_BIG
	TEST_ASSERT_EQUAL(recovery.wave_janitors_left, 4, "A big wave is not four janitors")
	TEST_ASSERT_EQUAL(recovery.wave_escort_size, 0, "A living officer did not do away with the escort")

/// Only the wave's own people can lose it: an escort officer's death, or a body that is not crew, does not
/datum/unit_test/voidcrew_outpost_recovery_wave_not_lost

/datum/unit_test/voidcrew_outpost_recovery_wave_not_lost/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	recovery_corpse(outpost, wanted_spot(1, 1))
	recovery.call_wave()
	recovery.wave_morgue_left = 0
	recovery.wave_janitors_left = 0
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/first = recovery_worker(outpost, wanted_spot(0, 3))
	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/second = recovery_worker(outpost, wanted_spot(1, 3), /mob/living/carbon/human/npc/ambient_npc/outpost/recovery/janitor)
	first.death()
	TEST_ASSERT_EQUAL(recovery.waves_lost, 0, "One worker down lost the wave")
	TEST_ASSERT(recovery.wave_active, "One worker down ended the wave")
	second.death()
	TEST_ASSERT_EQUAL(recovery.waves_lost, 1, "Both workers down did not lose the wave")

// ===== THE PAUSED CLOCK =====

/// Nobody on the concourse: the recovery stands still, and its clocks move on by as long as it stood
/datum/unit_test/voidcrew_outpost_recovery_paused

/datum/unit_test/voidcrew_outpost_recovery_paused/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/datum/ambient_place/outpost/place = SSambient_npcs.outpost_place(outpost)
	recovery_corpse(outpost, wanted_spot(1, 1))
	recovery.last_death_at = world.time - 90 SECONDS
	var/death_at = recovery.last_death_at

	place.occupied = FALSE
	recovery.tick()
	TEST_ASSERT(recovery.paused_at, "An empty concourse did not stop the clock")
	TEST_ASSERT_EQUAL(recovery.state, 1, "An empty outpost changed state") // OUTPOST_RECOVERY_TROUBLE
	recovery.last_shot_at = world.time - 10 MINUTES
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.state, 1, "An empty outpost went quiet while nobody was there to see it")

	// Ten minutes pass with nobody there, then someone comes: the two minutes are not up yet
	recovery.paused_at = world.time - 10 MINUTES
	place.occupied = TRUE
	recovery.tick()
	TEST_ASSERT_EQUAL(recovery.paused_at, 0, "The clock did not start again")
	TEST_ASSERT(abs(recovery.last_death_at - (death_at + 10 MINUTES)) <= 10, "The last death was not moved on by the ten minutes nobody was there")
	TEST_ASSERT_EQUAL(recovery.state, 1, "The ten empty minutes counted toward the quiet")

// ===== LOSSES =====

/// The trader drop and the stick-up share 1 500 cr an outpost a round
/datum/unit_test/voidcrew_outpost_recovery_losses

/datum/unit_test/voidcrew_outpost_recovery_losses/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	TEST_ASSERT_EQUAL(recovery.loss_room(), 1500, "A fresh outpost does not have 1 500 cr of room") // OUTPOST_RECOVERY_LOSS_CAP
	recovery.note_loss(600)
	TEST_ASSERT_EQUAL(recovery.loss_room(), 900, "600 cr paid out left the wrong room")
	recovery.note_loss(-50)
	TEST_ASSERT_EQUAL(recovery.loss_room(), 900, "A negative loss changed the room")
	recovery.note_loss(2000)
	TEST_ASSERT_EQUAL(recovery.loss_room(), 0, "Room went below nothing")
	// A second outpost has its own
	var/obj/structure/overmap/trader_outpost/other = recovery_outpost()
	TEST_ASSERT_EQUAL(other.recovery.loss_room(), 1500, "Another outpost shares the cap")

// ===== THE ROOMS (R0's link_rooms()) =====

/// A morgue landmark with four trays near it and a closet landmark: the recovery records both and the landmarks go
/datum/unit_test/voidcrew_outpost_recovery_link_rooms

/datum/unit_test/voidcrew_outpost_recovery_link_rooms/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/turf/morgue_spot = wanted_spot(2, 2)
	var/list/trays = list()
	for(var/dx in 0 to 3)
		trays += allocate(/obj/structure/bodycontainer/morgue, wanted_spot(dx, 0))
	var/obj/effect/landmark/outpost_morgue/morgue_mark = allocate(/obj/effect/landmark/outpost_morgue, morgue_spot)
	var/obj/effect/landmark/outpost_janitor_closet/closet_mark = allocate(/obj/effect/landmark/outpost_janitor_closet, wanted_spot(8, 8))
	recovery.link_rooms(list(morgue_mark, closet_mark))
	TEST_ASSERT_EQUAL(recovery.morgue_turf, morgue_spot, "The morgue room's floor was not recorded")
	TEST_ASSERT_EQUAL(length(recovery.morgue_trays), 4, "The morgue room does not have its four trays")
	TEST_ASSERT_EQUAL(recovery.closet_turf, wanted_spot(8, 8), "The janitor closet's floor was not recorded")
	TEST_ASSERT(QDELETED(morgue_mark) && QDELETED(closet_mark), "The recovery landmarks were not consumed")

/// Each real outpost map links one morgue with four trays and one janitor closet, and both rooms are closed off
/datum/unit_test/voidcrew_outpost_recovery_real_rooms

/datum/unit_test/voidcrew_outpost_recovery_real_rooms/Run()
	for(var/outpost_type in list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	))
		var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost(outpost_type)
		if(!outpost)
			continue
		var/datum/outpost_recovery/recovery = outpost.recovery
		TEST_ASSERT_NOTNULL(recovery, "[outpost_type] has no recovery")
		TEST_ASSERT_NOTNULL(recovery.morgue_turf, "[outpost_type] linked no morgue")
		TEST_ASSERT_EQUAL(length(recovery.morgue_trays), 4, "[outpost_type]'s morgue does not have four trays")
		TEST_ASSERT_NOTNULL(recovery.closet_turf, "[outpost_type] linked no janitor closet")
		TEST_ASSERT(recovery.back_rooms[recovery.morgue_turf], "[outpost_type]'s morgue is not a closed room")
		TEST_ASSERT(recovery.back_rooms[recovery.closet_turf], "[outpost_type]'s janitor closet is not a closed room")
		// The morgue and closet are small rooms behind doors (RECOVERY_ROOM_MAX is 60): never the lobby with them
		TEST_ASSERT(length(recovery.back_rooms) <= 40, "[outpost_type]'s back rooms run out into the outpost ([length(recovery.back_rooms)] tiles)")

/// A player put into an NPC's corpse (a brain transplant after death) makes it a person's body: off the NPC list,
/// never handed to the corpse sweep; and a player's body already in a tray calls no crew wave
/datum/unit_test/voidcrew_outpost_recovery_corpse_taken_over

/datum/unit_test/voidcrew_outpost_recovery_corpse_taken_over/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/body = recovery_corpse(outpost, wanted_spot(1, 1))
	TEST_ASSERT(WEAKREF(body) in recovery.npc_dead, "Setup: the NPC body is not on the outpost's list")
	body.mind_initialize()
	allocated += body.mind
	recovery.prune_dead()
	TEST_ASSERT(!(WEAKREF(body) in recovery.npc_dead), "A corpse a player went into is still on the NPC list")
	TEST_ASSERT(WEAKREF(body) in recovery.player_dead, "A corpse a player went into is not kept as a person's")
	// Even if it is still on the NPC list when the bodies go back to the sweep
	recovery.npc_dead += WEAKREF(body)
	recovery.hand_back_bodies(force = TRUE)
	TEST_ASSERT_EQUAL(body.npc_corpse_lifetime, 0, "A corpse a player went into was handed to the corpse sweep")
	TEST_ASSERT(!(body in SShuman_npcs.corpses), "A corpse a player went into is on the corpse sweep")

	// In a tray it is done: no morgue crew is called for it
	var/obj/structure/bodycontainer/morgue/tray = allocate(/obj/structure/bodycontainer/morgue, wanted_spot(3, 3))
	body.forceMove(tray)
	TEST_ASSERT(morgue_body_done(body), "A body in a tray is not done")
	recovery.npc_dead.Cut()
	recovery.dirty_stops.Cut()
	TEST_ASSERT_EQUAL(length(recovery.player_bodies()), 0, "A body in a tray is still waiting for the morgue crew")
	TEST_ASSERT(!recovery.has_cleanup_work(), "A body in a tray is cleanup work")
	recovery.call_wave()
	TEST_ASSERT(!recovery.wave_active, "A body in a tray called a crew wave")
	body.forceMove(wanted_spot(1, 1))

/// The clocks stand still with the concourse: a patient's retry moves on too. A worker a player went into is
/// never faded out with the crew and does not keep a wave alive.
/datum/unit_test/voidcrew_outpost_recovery_paused_retry_and_played_worker

/datum/unit_test/voidcrew_outpost_recovery_paused_retry_and_played_worker/Run()
	var/obj/structure/overmap/trader_outpost/outpost = recovery_outpost()
	var/datum/outpost_recovery/recovery = outpost.recovery
	var/mob/living/carbon/human/npc/ambient_npc/outpost/customer/patient = allocate(/mob/living/carbon/human/npc/ambient_npc/outpost/customer, wanted_spot(2, 2))
	var/datum/weakref/patient_ref = WEAKREF(patient)
	var/retry = world.time + 30 SECONDS
	recovery.patient_retry[patient_ref] = retry
	recovery.shift_times(5 MINUTES)
	TEST_ASSERT_EQUAL(recovery.patient_retry[patient_ref], retry + 5 MINUTES, "A patient's retry ran on while nobody was on the concourse")

	var/mob/living/carbon/human/npc/ambient_npc/outpost/recovery/worker = recovery_worker(outpost, wanted_spot(3, 1))
	recovery.wave_active = TRUE
	TEST_ASSERT(worker in recovery.live_wave_workers(), "Setup: the worker is not on the wave")
	worker.mind_initialize()
	allocated += worker.mind
	TEST_ASSERT(!(worker in recovery.live_wave_workers()), "A worker a player went into still counts as the wave's")
	recovery.retire_crew()
	TEST_ASSERT(!worker.fading && !QDELETED(worker), "A worker a player went into was faded out with the crew")
