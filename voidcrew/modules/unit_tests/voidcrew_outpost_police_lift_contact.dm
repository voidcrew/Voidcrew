/**
 * Outpost police tests: a wave forming up on its lift point that comes under fire or sees someone armed goes at once
 * (police_dispatch.dm dispatch_wave_contact()). Helpers are in voidcrew_outpost_police_dispatch.dm and _helpers.dm.
 */

/// A wave of two on a lift point: one is shot while it forms up, and both go at once; one already fighting is not sent to search
/datum/unit_test/voidcrew_outpost_police_lift_hit_releases_wave

/datum/unit_test/voidcrew_outpost_police_lift_hit_releases_wave/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	police.dispatch_build_now = TRUE
	dispatch_two_lifts(outpost)
	var/mob/living/suspect = dispatch_suspect(outpost, 50)
	var/datum/outpost_police_wave/wave = police.dispatch_send_wave(3, 2, "concourse", police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(wave, "No wave was sent")
	var/list/members = wave.living_members()
	TEST_ASSERT_EQUAL(length(members), 2, "A wave of two built [length(members)]")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/first = members[1]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/second = members[2]
	TEST_ASSERT(HAS_TRAIT_FROM(first, TRAIT_AI_PAUSED, "outpost_police_wave"), "Setup: the wave is not forming up")
	// Long before it would leave on its own
	wave.release_at = world.time + 60 SECONDS
	first.apply_damage(10, BRUTE, BODY_ZONE_CHEST)
	TEST_ASSERT(wave.released_at, "A wave whose member was shot at the lift went on forming up")
	TEST_ASSERT(!HAS_TRAIT_FROM(first, TRAIT_AI_PAUSED, "outpost_police_wave"), "The officer shot at the lift was left frozen there")
	TEST_ASSERT(!HAS_TRAIT_FROM(second, TRAIT_AI_PAUSED, "outpost_police_wave"), "The rest of the wave stayed frozen behind the door when one of it was shot")
	dispatch_clear(police)

	// A member already fighting when the wave goes keeps at it rather than being sent to search
	suspect = dispatch_suspect(outpost, 50)
	wave = police.dispatch_send_wave(3, 1, "concourse", police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(wave, "No second wave was sent")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/fighter = wave.living_members()[1]
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = fighter.ai_controller
	TEST_ASSERT(istype(brain), "Setup: an officer without the stealth brain")
	brain.stealth_go_alert(suspect)
	police.dispatch_release_wave(wave)
	TEST_ASSERT_EQUAL(brain.stealth_state(), "alert", "An officer fighting at the lift was sent off to search when its wave went") // STEALTH_ALERT
	dispatch_clear(police)

/// A wave forming up goes at once when one of it sees someone wanted with a gun in hand, and not for someone wanted and empty-handed
/datum/unit_test/voidcrew_outpost_police_lift_armed_sight_releases_wave

/datum/unit_test/voidcrew_outpost_police_lift_armed_sight_releases_wave/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	dispatch_clear(police)
	police.dispatch_build_now = TRUE
	var/list/turf/row = dispatch_row(outpost)
	if(!row)
		TEST_NOTICE(src, "No three free tiles in a row on the concourse")
		return
	police.lift_turfs = list(row[1])
	var/mob/living/carbon/human/suspect = dispatch_suspect(outpost, 50, row[3])
	var/datum/outpost_police_wave/wave = police.dispatch_send_wave(3, 1, "concourse", police.get_warrant(suspect.mind))
	TEST_ASSERT_NOTNULL(wave, "No wave was sent")
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/member = wave.living_members()[1]
	TEST_ASSERT_EQUAL(get_turf(member), row[1], "Setup: the wave did not form up on the lift point")
	TEST_ASSERT(police.perception.sees(member, suspect), "Setup: the officer at the lift cannot see the suspect two tiles off")
	wave.release_at = world.time + 60 SECONDS
	police.dispatch_check_waves()
	TEST_ASSERT(!wave.released_at, "A wave left early for someone wanted with empty hands")
	var/obj/item/gun/ballistic/automatic/pistol/gun = allocate(/obj/item/gun/ballistic/automatic/pistol)
	TEST_ASSERT(suspect.put_in_hands(gun), "Setup: the suspect could not take the pistol")
	police.dispatch_check_waves()
	TEST_ASSERT(wave.released_at, "A wave stood frozen at its lift with someone wanted and armed in sight")
	TEST_ASSERT(!HAS_TRAIT_FROM(member, TRAIT_AI_PAUSED, "outpost_police_wave"), "The officer facing an armed suspect at the lift stayed frozen")
	dispatch_clear(police)
