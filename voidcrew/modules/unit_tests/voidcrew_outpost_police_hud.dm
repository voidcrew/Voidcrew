/**
 * Outpost police tests: police_hud.dm (voidcrew/modules/outpost_police/). Owner: P8.
 * Helpers are in voidcrew_outpost_police_helpers.dm. Fork defines are included after the tests: use
 * literal values with a comment naming the define.
 */

/// The wanted alert shows one to five stars at the outpost, blinks while the suspect is unseen or away, follows a change of stars and goes at none
/datum/unit_test/voidcrew_outpost_police_hud

/datum/unit_test/voidcrew_outpost_police_hud/Run()
	var/obj/structure/overmap/trader_outpost/outpost = police_loaded_outpost()
	if(!outpost)
		return
	var/datum/outpost_police/police = outpost.police
	var/turf/floor = police_floor(outpost)
	TEST_ASSERT_NOTNULL(floor, "No free floor on the concourse for a suspect")
	var/mob/living/basic/suspect = allocate(/mob/living/basic, floor)
	suspect.mind_initialize()
	var/datum/mind/suspect_mind = suspect.mind
	var/list/star_heat = list(10, 25, 50, 90, 140) // OUTPOST_POLICE_STAR_HEAT
	var/alert_category = "outpost_wanted" // OUTPOST_WANTED_ALERT in police_hud.dm
	var/datum/outpost_warrant/warrant

	// One to five stars at the outpost: the plain set, named and described with nothing else
	for(var/stars in 1 to 5)
		warrant = police_pin_warrant(police, suspect_mind, star_heat[stars])
		police.update_hud(suspect_mind)
		var/atom/movable/screen/alert/outpost_wanted/alert = suspect.alerts[alert_category]
		TEST_ASSERT_NOTNULL(alert, "No wanted alert at [stars] stars")
		TEST_ASSERT(istype(alert, /atom/movable/screen/alert/outpost_wanted), "The wanted alert is not the outpost one")
		TEST_ASSERT_EQUAL(alert.icon_state, "wanted[stars]", "The alert at [stars] stars showed the wrong state")
		TEST_ASSERT_EQUAL(alert.name, "Wanted", "The wanted alert has the wrong name")
		TEST_ASSERT_EQUAL(alert.desc, "[police.profile.force_name].", "The wanted alert does not describe the force")
		TEST_ASSERT_EQUAL(length(suspect.alerts), 1, "Something else was put on the screen with the wanted alert")

	// Unseen or away: the blinking set, and back to the plain one when they are in sight again
	warrant = police_pin_warrant(police, suspect_mind, star_heat[3])
	warrant.unseen_since = world.time
	police.update_hud(suspect_mind)
	var/atom/movable/screen/alert/outpost_wanted/blinking = suspect.alerts[alert_category]
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3_fade", "An unseen suspect's stars did not blink")
	warrant.unseen_since = 0
	police.update_hud(suspect_mind)
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3", "A suspect in sight again still blinked")
	warrant.away_since = world.time
	police.update_hud(suspect_mind)
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3_fade", "A suspect marked away did not blink")
	warrant.away_since = 0
	police.update_hud(suspect_mind)
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3", "A suspect back at the outpost still blinked")
	suspect.forceMove(run_loc_floor_bottom_left)
	police.update_hud(suspect_mind)
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3_fade", "A suspect away from the outpost did not blink")
	suspect.forceMove(floor)
	police.update_hud(suspect_mind)
	TEST_ASSERT_EQUAL(blinking.icon_state, "wanted3", "A suspect back on the concourse still blinked")

	// Gone at no stars
	police_pin_warrant(police, suspect_mind, 0)
	police.update_hud(suspect_mind)
	TEST_ASSERT(!suspect.has_alert(alert_category), "The wanted alert stayed at no stars")

	// The wanted core's change of stars alone puts it up
	var/datum/outpost_warrant/changed = police_pin_warrant(police, suspect_mind, star_heat[2])
	police.stars_changed(changed, 0, 2)
	var/atom/movable/screen/alert/outpost_wanted/signalled = suspect.alerts[alert_category]
	TEST_ASSERT_NOTNULL(signalled, "A change of stars did not put the alert up")
	TEST_ASSERT_EQUAL(signalled.icon_state, "wanted2", "A change of stars showed the wrong state")

	// The alert reads its warrant again on its own: a blink that starts, then a warrant that is gone
	warrant = police_pin_warrant(police, suspect_mind, star_heat[2])
	warrant.unseen_since = world.time
	signalled.refresh()
	TEST_ASSERT_EQUAL(signalled.icon_state, "wanted2_fade", "The alert did not pick up an unseen suspect by itself")
	police_pin_warrant(police, suspect_mind, 0)
	signalled.refresh()
	TEST_ASSERT(!suspect.has_alert(alert_category), "The alert stayed up after the warrant ended")
