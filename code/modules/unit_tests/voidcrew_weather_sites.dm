/// Two disjoint patches of ground on one z-level, each owned by its own weather site.
/area/weather_site_unit_test
	name = "weather site test area"
	outdoors = TRUE
	requires_power = FALSE

/area/weather_site_unit_test/alpha
/area/weather_site_unit_test/beta

/datum/weather/unit_test/site_scoped
	name = "site test front"
	area_type = /area/weather_site_unit_test
	weather_flags = WEATHER_MOBS
	telegraph_duration = 0
	weather_duration_lower = 1 MINUTES
	weather_duration_upper = 1 MINUTES
	end_duration = 0

/datum/weather/unit_test/site_scoped/beta
	name = "other site test front"

/**
 * # Weather is scheduled per site, not per z-level
 *
 * Two places sharing a z-level each hold their own climate, their own storm and their own
 * cooldown. A storm launched from one must not reach into the other's areas, must not alert
 * anybody standing in them, and must not stop the other from storming at the same time.
 */
/datum/unit_test/weather_site_scheduling

/datum/unit_test/weather_site_scheduling/Run()
	var/datum/controller/subsystem/weather/unit_test/scheduler = allocate(/datum/controller/subsystem/weather/unit_test)

	var/turf/turf_alpha = run_loc_floor_bottom_left
	var/turf/turf_beta = locate(turf_alpha.x + 1, turf_alpha.y, turf_alpha.z)
	TEST_ASSERT(isturf(turf_beta), "the unit test zone had no second turf to build a weather site on")
	var/test_z = turf_alpha.z

	var/area/original_alpha_area = turf_alpha.loc
	var/area/original_beta_area = turf_beta.loc
	var/area/weather_site_unit_test/alpha/alpha_area = new
	var/area/weather_site_unit_test/beta/beta_area = new
	turf_alpha.change_area(original_alpha_area, alpha_area)
	turf_beta.change_area(original_beta_area, beta_area)

	// Two sites on ONE z-level, disjoint area sets, different weight tables.
	var/datum/weather_site/alpha_site = new("unit-test-alpha", test_z, list(/datum/weather/unit_test/site_scoped = 100))
	alpha_site.set_owned_areas(list(alpha_area))
	var/datum/weather_site/beta_site = new("unit-test-beta", test_z, list(/datum/weather/unit_test/site_scoped/beta = 100))
	beta_site.set_owned_areas(list(beta_area))
	scheduler.register_weather_site(alpha_site)
	scheduler.register_weather_site(beta_site)

	TEST_ASSERT_EQUAL(length(scheduler.get_weather_sites_on_z(test_z)), 2, \
		"two weather sites registered on one z-level did not both survive registration")
	TEST_ASSERT(alpha_site.weather_types[/datum/weather/unit_test/site_scoped] && !alpha_site.weather_types[/datum/weather/unit_test/site_scoped/beta], \
		"two sites sharing a z-level shared one weight table")
	TEST_ASSERT(beta_site.weather_types[/datum/weather/unit_test/site_scoped/beta] && !beta_site.weather_types[/datum/weather/unit_test/site_scoped], \
		"two sites sharing a z-level shared one weight table")

	// A storm launched from site A, exactly as the scheduler launches it.
	var/datum/weather/storm_alpha = allocate(/datum/weather/unit_test/site_scoped, list(test_z), null, alpha_site)
	alpha_site.active_weather = storm_alpha
	storm_alpha.stage = MAIN_STAGE
	storm_alpha.update_areas()

	TEST_ASSERT(storm_alpha.impacted_areas_lookup[alpha_area], \
		"a site-launched storm did not impact its own site's area")
	TEST_ASSERT(!storm_alpha.impacted_areas_lookup[beta_area], \
		"a site-launched storm impacted a neighbouring site's area on the same z-level")
	TEST_ASSERT(length(storm_alpha.overlay_cache), \
		"a running storm generated no weather overlays, so the overlay assertions below prove nothing")
	TEST_ASSERT(!length(beta_area.overlays), \
		"a site-launched storm painted weather overlays on a neighbouring site's area")

	// Mobs, both the effect path and the alert path.
	var/mob/living/carbon/human/consistent/beta_mob = allocate(/mob/living/carbon/human/consistent, turf_beta)
	beta_mob.mind_initialize()
	var/mob/living/carbon/human/consistent/alpha_mob = allocate(/mob/living/carbon/human/consistent, turf_alpha)
	alpha_mob.mind_initialize()

	TEST_ASSERT(storm_alpha.can_weather_act_mob(alpha_mob), \
		"a mob standing inside the storm's own site was not eligible for it")
	TEST_ASSERT(!storm_alpha.can_weather_act_mob(beta_mob), \
		"a mob standing in a neighbouring site's area was eligible for another site's storm")
	TEST_ASSERT(storm_alpha.can_get_alert(alpha_mob), \
		"a storm alert did not reach a mob inside the storm's impacted areas")
	TEST_ASSERT(!storm_alpha.can_get_alert(beta_mob), \
		"a storm alert leaked to a mob outside the storm's impacted areas")

	// One storm per SITE, not per z-level: B is free to storm while A's is running.
	TEST_ASSERT(alpha_site.has_active_weather(), \
		"the site that launched a storm did not report it as active")
	TEST_ASSERT(!beta_site.has_active_weather(), \
		"a storm on one site blocked scheduling on another site sharing its z-level")

	var/datum/weather/storm_beta = allocate(/datum/weather/unit_test/site_scoped/beta, list(test_z), null, beta_site)
	beta_site.active_weather = storm_beta
	storm_beta.stage = MAIN_STAGE
	storm_beta.update_areas()

	TEST_ASSERT(alpha_site.has_active_weather() && beta_site.has_active_weather(), \
		"two sites on one z-level could not hold concurrent storms")
	TEST_ASSERT(!storm_beta.impacted_areas_lookup[alpha_area], \
		"a concurrent storm on the second site reached into the first site's area")

	// Turf -> site resolution: a footprinted site claims its rect, everything else falls
	// through to the site covering the level.
	alpha_site.add_footprint_rect(turf_alpha.x, turf_alpha.y, turf_alpha.x, turf_alpha.y)
	TEST_ASSERT_EQUAL(scheduler.get_weather_site_for_turf(turf_alpha), alpha_site, \
		"a footprinted weather site did not claim a turf inside its own rect")
	TEST_ASSERT_EQUAL(scheduler.get_weather_site_for_turf(turf_beta), beta_site, \
		"a turf outside every footprint did not fall through to the level-wide weather site")

	// Teardown ends the site's storm and pulls its overlays back off the areas.
	scheduler.unregister_weather_site(alpha_site)
	scheduler.unregister_weather_site(beta_site)
	TEST_ASSERT_EQUAL(storm_alpha.stage, END_STAGE, \
		"unregistering a weather site left its storm running")
	TEST_ASSERT_EQUAL(storm_beta.stage, END_STAGE, \
		"unregistering a weather site left its storm running")
	TEST_ASSERT(!length(scheduler.get_weather_sites_on_z(test_z)), \
		"unregistered weather sites stayed in the z-level index")

	// A finished storm must not outlive its own end(). It used to sit on the site until the
	// 5-10 minute cooldown callback landed, and a storm holds three references to every area
	// INSTANCE it impacted - on a planet, the surface, every cave and every ruin area - so a
	// place torn down inside that window left its areas qdel'd and unfreeable.
	TEST_ASSERT(isnull(alpha_site.active_weather), \
		"a finished storm was still held by the weather site that scheduled it")
	TEST_ASSERT(isnull(storm_alpha.weather_site), \
		"a finished storm still pointed back at the site that scheduled it")
	TEST_ASSERT(!alpha_site.has_active_weather(), \
		"a site whose storm has finished was not free to schedule another one")
	TEST_ASSERT(!length(alpha_area.overlays), \
		"a finished storm left its weather overlays painted on an impacted area")

	// end() schedules the deletion a tick out, so subtype end() overrides that chain through
	// ..() still see their lists. Force it here rather than sleeping, and check that deletion
	// is what actually releases the areas.
	TEST_ASSERT(length(storm_alpha.impacted_areas) && length(storm_alpha.impacted_areas_lookup), \
		"the storm held no impacted areas going into deletion, so the assertions below prove nothing")
	qdel(storm_alpha)
	qdel(storm_beta)
	TEST_ASSERT(QDELETED(storm_alpha), \
		"a finished storm refused deletion")
	TEST_ASSERT(!length(storm_alpha.impacted_areas), \
		"a deleted storm still held the area instances it impacted, which stops them being GC'd")
	TEST_ASSERT(!length(storm_alpha.impacted_areas_lookup), \
		"a deleted storm still held its impacted-area lookup, which stops those areas being GC'd")
	TEST_ASSERT(isnull(storm_alpha.scoped_areas), \
		"a deleted storm still held the area instances its site handed it")

	turf_alpha.change_area(alpha_area, original_alpha_area)
	turf_beta.change_area(beta_area, original_beta_area)
	qdel(alpha_area)
	qdel(beta_area)
