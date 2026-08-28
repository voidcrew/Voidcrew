/**
 * # Weather presentation channels are scoped to the site, not the z-level
 *
 * Companion to voidcrew_weather_sites.dm, which covers the fork's own scoping layer
 * (impacted areas, overlays, alerts, mob effects). This file covers the channels that
 * layer does NOT reach, and the contracts a merge can quietly break.
 *
 * The incident these guard: "all weather types at once on a packed planet z-level",
 * 2026-08 tg upgrade. Encounter packing puts up to four planets on one z-level, each with
 * its own /datum/weather_site and its own climate, storming independently - that part is
 * intended. What broke is that upstream added presentation channels keyed by z-level and
 * nothing else, on the (true, for upstream) premise that one z-level is one place:
 *
 *  - particle holders were indexed by z-stack alone, and the plane they hang on is
 *    alpha-masked by the UNION of every particle storm's area overlays, so a crew standing
 *    in their own ash storm's mask had the co-tenant's rain drawn through it too;
 *  - manually_setup_sound_manager() handed an area_sound_manager to every mob in the round
 *    for any storm on a level lacking its climate trait - which on a packed level is three
 *    tenants in four, every storm - and the component is COMPONENT_DUPE_ALLOWED, so they
 *    stacked one audio loop per concurrent storm;
 *  - the new doppler tower summoned unscoped weather when off-station, and every planet
 *    storm shares area_type = /area/overmap_encounter/planetoid, so one crew's summon
 *    stormed all four tenants;
 *  - run_weather() briefly carried a duplicated body in which the fork's site-passing call
 *    was dead code, so EVERY site-scheduled storm was built with site = null;
 *  - /datum/weather/rad_storm/planetary/end() is a hand-mirror of /datum/weather/end() and
 *    drifted three edits behind upstream.
 *
 * NOTE: unit-test files compile at their code/modules/unit_tests include position, which is
 * BEFORE voidcrew/_DEFINES/. Fork defines are not available here - see the header of
 * voidcrew_helpers.dm. Literals with a naming comment, per that convention.
 */

/// A third patch of the two site fixtures' area type, deliberately owned by NO site.
/// Without it a two-site test passes for the wrong reason: the z-wide get_areas(area_type)
/// sweep the scoping exists to prevent would return exactly the areas the sites own anyway.
/area/weather_site_unit_test/gamma

/// Only ash and rain are particle storms, and both carry real playlists, real GLOB sound
/// tables and thousands of particles. This is the same machinery with none of that.
/particles/weather/unit_test
	count = 1
	spawning = 0

/datum/weather/particle/unit_test_scoped
	name = "site test particle front"
	area_type = /area/weather_site_unit_test
	particle_type = /particles/weather/unit_test
	weather_flags = WEATHER_MOBS
	telegraph_duration = 0
	weather_duration_lower = 1 MINUTES
	weather_duration_upper = 1 MINUTES
	end_duration = 0

/datum/weather/particle/unit_test_scoped/beta
	name = "other site test particle front"

/**
 * Sound-manager fixture.
 *
 * `target_trait` is a string no z-level carries on purpose. That is the packed co-tenant's
 * situation exactly: only the FIRST tenant publishes its climate to the level (see
 * apply_planet_level_traits()), so tenants 2-4 run every storm on a level that lacks the
 * storm's trait, which is the branch manually_setup_sound_manager() exists to serve.
 *
 * The playlist is empty but NOT null: manually_setup_sound_manager() only refuses a null
 * one, and an empty one means area_sound_manager finds no loop for the mob's area and never
 * starts a sound in the test world.
 */
/datum/weather/unit_test/site_scoped/audible
	name = "audible site test front"
	target_trait = "unit-test-weather-trait"
	weather_flags = WEATHER_MOBS
	telegraph_duration = 0
	weather_duration_lower = 1 MINUTES
	weather_duration_upper = 1 MINUTES
	end_duration = 0
	var/list/test_playlist = list()

/datum/weather/unit_test/site_scoped/audible/get_playlist_ref()
	return test_playlist

/datum/weather/unit_test/site_scoped/audible/beta
	name = "other audible site test front"

/// Doppler tower whose summonable roster is the cheap site fixture rather than the four
/// real storms, so the test drives the real summon_weather() body without minting particles
/// or mutating the GLOB.*_storm_sounds playlists every other storm shares.
/obj/machinery/power/weather_tower/unit_test

/obj/machinery/power/weather_tower/unit_test/get_summonable_weather_types()
	return list(/datum/weather/unit_test/site_scoped)

/// TRUE when `listener` holds a `sig` registration on `target`. _listen_lookup stores a bare
/// datum for the first registrant and a list from the second on, so both shapes are handled.
/proc/vc_weather_test_is_listening(datum/listener, datum/target, sig)
	var/looked_up = target?._listen_lookup?[sig]
	if(isnull(looked_up))
		return FALSE
	if(islist(looked_up))
		return (listener in looked_up)
	return looked_up == listener

/**
 * The statement lines of a proc body, given the exact text of its signature line.
 *
 * Comments, blank lines and everything outside the proc are dropped; indentation is kept,
 * because two bodies that differ only in nesting are not the same body. Returns null when
 * the file or the signature cannot be found, so the caller can say which.
 */
/proc/vc_weather_test_proc_body(path, signature)
	var/text = vc_test_file_text(path)
	if(isnull(text))
		return null
	// DM has no "\r" escape, and a CRLF checkout would otherwise leave a carriage return on
	// the end of every line - harmless for the comparison, but it would print into failure
	// messages and break the "starts with a tab" test on nothing.
	var/static/carriage_return = ascii2text(13)
	var/list/lines = splittext(replacetext(text, carriage_return, ""), "\n")
	var/list/body = list()
	var/found_signature = FALSE
	for(var/line in lines)
		if(!found_signature)
			if(line == signature)
				found_signature = TRUE
			continue
		// Anything at column zero is the next definition, so the proc has ended.
		if(length(line) && copytext(line, 1, 2) != "\t")
			break
		var/trimmed = trim(line)
		if(!length(trimmed))
			continue
		if(copytext(trimmed, 1, 3) == "//")
			continue
		body += line
	return found_signature ? body : null

/**
 * # A particle storm's holders are its own site's, not its z-level's
 *
 * Guards: "all weather types at once on a packed planet z-level" - upstream keyed particle
 * holders by z-stack alone, 2026-08 tg upgrade.
 *
 * add_weather_objects() and both render_plate.dm consumers used to answer "should this
 * viewer see these particles?" with a bare `length(holder_zs & stack_levels)`. On a packed
 * level that is true for all four tenants' storms at once, and since the particle plane's
 * alpha mask is fed by the union of every particle storm's area overlays, a crew standing
 * inside their own storm's mask had the neighbour's particles drawn straight through it.
 * shows_on_turf() is the shared test all three now call; this drives it directly rather
 * than through a plane master, which needs a client.
 */
/datum/unit_test/weather_site_particle_scoping

/datum/unit_test/weather_site_particle_scoping/Run()
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

	// Two packed tenants: one z-level, one turf of ground each, disjoint footprints. The
	// footprints are what shows_on_turf() asks about, so both sites need one.
	var/datum/weather_site/alpha_site = new("unit-test-particle-alpha", test_z, list(), 1)
	alpha_site.set_owned_areas(list(alpha_area))
	alpha_site.add_footprint_rect(turf_alpha.x, turf_alpha.y, turf_alpha.x, turf_alpha.y)
	var/datum/weather_site/beta_site = new("unit-test-particle-beta", test_z, list(), 1)
	beta_site.set_owned_areas(list(beta_area))
	beta_site.add_footprint_rect(turf_beta.x, turf_beta.y, turf_beta.x, turf_beta.y)

	var/datum/weather/particle/storm_alpha = allocate(/datum/weather/particle/unit_test_scoped, list(test_z), null, alpha_site)
	var/datum/weather/particle/storm_beta = allocate(/datum/weather/particle/unit_test_scoped/beta, list(test_z), null, beta_site)

	// /datum/weather/particle/New() declares two parameters where /datum/weather/New()
	// declares three, and forwards the third only because a bare ..() passes the whole
	// argument list. An explicit ..(z_levels, weather_data) anywhere in that chain would
	// silently drop the site and put ash and rain - the only two particle storms - straight
	// back on z-scoping with nothing else failing.
	TEST_ASSERT_EQUAL(storm_alpha.weather_site, alpha_site, \
		"a particle storm did not receive the site it was launched from - /datum/weather/particle/New() stopped forwarding it to /datum/weather/New()")

	TEST_ASSERT(length(storm_alpha.weather_objects), \
		"a particle storm built no weather object lists, so the assertions below prove nothing")
	var/list/alpha_holders = storm_alpha.weather_objects[1]
	var/list/beta_holders = storm_beta.weather_objects[1]
	TEST_ASSERT(length(alpha_holders) && length(beta_holders), \
		"a particle storm built no particle holders, so the assertions below prove nothing")

	// Every holder must know whose storm it is. A refactor that drops the back-reference
	// reverts shows_on_turf() to the plain z-stack answer for every storm in the game.
	for(var/list/object_list as anything in storm_alpha.weather_objects)
		for(var/obj/effect/abstract/weather_holder/holder as anything in object_list)
			TEST_ASSERT_EQUAL(holder.storm, storm_alpha, \
				"a particle holder lost the back-reference to its own storm, so shows_on_turf() has no site to test against")

	var/obj/effect/abstract/weather_holder/alpha_holder = alpha_holders[1]
	var/obj/effect/abstract/weather_holder/beta_holder = beta_holders[1]
	var/list/alpha_holder_zs = alpha_holders[alpha_holder]
	var/list/beta_holder_zs = beta_holders[beta_holder]
	// What the plane masters compute for their viewer before calling shows_on_turf().
	var/list/stack_levels = SSmapping.get_connected_levels(turf_alpha) || list(test_z)

	TEST_ASSERT(alpha_holder.shows_on_turf(alpha_holder_zs, stack_levels, turf_alpha), \
		"a site's own particle holder was hidden from a viewer standing inside that site")
	TEST_ASSERT(!beta_holder.shows_on_turf(beta_holder_zs, stack_levels, turf_alpha), \
		"the neighbouring site's particle holder was shown to a viewer standing in alpha - particle weather is leaking across co-tenants again")
	TEST_ASSERT(beta_holder.shows_on_turf(beta_holder_zs, stack_levels, turf_beta), \
		"a site's own particle holder was hidden from a viewer standing inside that site")
	TEST_ASSERT(!alpha_holder.shows_on_turf(alpha_holder_zs, stack_levels, turf_beta), \
		"the neighbouring site's particle holder was shown to a viewer standing in beta - particle weather is leaking across co-tenants again")

	// Control: a storm with no site is admin weather, a station trait or the wizard's rain,
	// and upstream's plain z-stack answer is the right one for those. If this stops being
	// true the assertions above are passing because the z test broke, not because the site
	// test works.
	var/datum/weather/particle/storm_global = allocate(/datum/weather/particle/unit_test_scoped, list(test_z), null, null)
	var/list/global_holders = storm_global.weather_objects[1]
	var/obj/effect/abstract/weather_holder/global_holder = global_holders[1]
	TEST_ASSERT(global_holder.shows_on_turf(global_holders[global_holder], stack_levels, turf_alpha) \
		&& global_holder.shows_on_turf(global_holders[global_holder], stack_levels, turf_beta), \
		"a storm with no weather site stopped showing its particles to everybody on its z-stack")

	// And the z test itself still has to refuse a holder from another z-stack.
	TEST_ASSERT(!alpha_holder.shows_on_turf(list(test_z + 1000), stack_levels, turf_alpha), \
		"a particle holder from an unrelated z-stack was shown to a viewer")

	turf_alpha.change_area(alpha_area, original_alpha_area)
	turf_beta.change_area(beta_area, original_beta_area)
	qdel(alpha_area)
	qdel(beta_area)

/**
 * # Storm ambience is its own site's occupants', not the whole round's
 *
 * Guards: "all weather types at once on a packed planet z-level" - upstream keyed the sound
 * manager sweep by z-trait only, 2026-08 tg upgrade.
 *
 * manually_setup_sound_manager() exists because /datum/element/weather_listener sets up
 * ambience from z-level traits, so a storm forced onto a level that lacks its trait has to
 * hand out managers by hand. Upstream that is a rare admin event; on a packed level it is
 * every storm run by three tenants in four, and the sweep walked the entire round's mob
 * list. /datum/component/area_sound_manager is COMPONENT_DUPE_ALLOWED, so a player collected
 * one loop per concurrent storm anywhere in the sector.
 *
 * can_hear_weather() is the gate, and the assertions below check it refuses an out-of-site
 * mob BEFORE any component or signal registration is made, on all three entry points.
 */
/datum/unit_test/weather_site_sound_scoping

/datum/unit_test/weather_site_sound_scoping/Run()
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

	var/datum/weather_site/alpha_site = new("unit-test-audio-alpha", test_z, list(), 1)
	alpha_site.set_owned_areas(list(alpha_area))
	alpha_site.add_footprint_rect(turf_alpha.x, turf_alpha.y, turf_alpha.x, turf_alpha.y)
	var/datum/weather_site/beta_site = new("unit-test-audio-beta", test_z, list(), 1)
	beta_site.set_owned_areas(list(beta_area))
	beta_site.add_footprint_rect(turf_beta.x, turf_beta.y, turf_beta.x, turf_beta.y)

	var/mob/living/carbon/human/consistent/alpha_mob = allocate(/mob/living/carbon/human/consistent, turf_alpha)
	var/mob/living/carbon/human/consistent/beta_mob = allocate(/mob/living/carbon/human/consistent, turf_beta)

	// allocate()d, so /datum/unit_test/Destroy() ends and frees them even if an assertion
	// below returns early - end() is what pulls the COMSIG_MOB_LOGIN registrations back off
	// every mob in the world.
	var/datum/weather/storm_alpha = allocate(/datum/weather/unit_test/site_scoped/audible, list(test_z), null, alpha_site)
	var/datum/weather/storm_beta = allocate(/datum/weather/unit_test/site_scoped/audible/beta, list(test_z), null, beta_site)
	storm_alpha.stage = MAIN_STAGE
	storm_beta.stage = MAIN_STAGE

	// The level really must lack the storm's trait, or manually_setup_sound_manager() takes
	// its early return and every assertion below is vacuous.
	TEST_ASSERT(length(storm_alpha.get_impacted_zs_without_trait()), \
		"the test z-level acquired the fixture's target trait, so the sound manager sweep never runs and this test proves nothing")
	TEST_ASSERT(!isnull(storm_alpha.get_playlist_ref()), \
		"the fixture handed back a null playlist, so the sound manager sweep never runs and this test proves nothing")

	// 1. The gate.
	TEST_ASSERT(storm_alpha.can_hear_weather(alpha_mob), \
		"a storm's own site occupant was refused its ambience")
	TEST_ASSERT(!storm_alpha.can_hear_weather(beta_mob), \
		"a co-tenant mob was handed a sound manager for a storm on somebody else's planet")
	TEST_ASSERT(storm_beta.can_hear_weather(beta_mob), \
		"a storm's own site occupant was refused its ambience")
	TEST_ASSERT(!storm_beta.can_hear_weather(alpha_mob), \
		"a co-tenant mob was handed a sound manager for a storm on somebody else's planet")

	// 2. The round-wide sweep. Both fixtures are client-less, which is the branch that
	// registers COMSIG_MOB_LOGIN and defers the component until the player connects.
	storm_alpha.manually_setup_sound_manager()
	TEST_ASSERT(vc_weather_test_is_listening(storm_alpha, alpha_mob, COMSIG_MOB_LOGIN), \
		"the sound manager sweep skipped an occupant of the storm's own site")
	TEST_ASSERT(!vc_weather_test_is_listening(storm_alpha, beta_mob, COMSIG_MOB_LOGIN), \
		"the sound manager sweep registered a co-tenant's mob for a storm on somebody else's planet")

	// Control: without a site the sweep is upstream's, and upstream's answer is everybody.
	// If this stops reaching the beta mob, the assertion above is passing because the sweep
	// broke rather than because the site gate works.
	var/datum/weather/storm_global = allocate(/datum/weather/unit_test/site_scoped/audible, list(test_z), null, null)
	storm_global.stage = MAIN_STAGE
	storm_global.manually_setup_sound_manager()
	TEST_ASSERT(vc_weather_test_is_listening(storm_global, beta_mob, COMSIG_MOB_LOGIN), \
		"a storm with no weather site stopped handing sound managers to the whole round")

	// 3. The mid-storm arrival path refuses before it builds anything.
	storm_alpha.handle_new_mob_sound_manager(SSdcs, beta_mob)
	TEST_ASSERT(!length(beta_mob.GetComponents(/datum/component/area_sound_manager)), \
		"a co-tenant mob created mid-storm was given a sound manager for a storm on somebody else's planet")
	TEST_ASSERT(!vc_weather_test_is_listening(storm_alpha, beta_mob, COMSIG_MOB_LOGIN), \
		"a co-tenant mob created mid-storm was registered for a storm on somebody else's planet")

	// 4. The login path builds exactly one manager, and a co-tenant's concurrent storm adds
	// none on top of it. This is the assertion that pins COMPONENT_DUPE_ALLOWED stacking:
	// the component's dupe mode lets managers pile up, so the gate is the only thing
	// stopping four packed tenants from giving one player four ambience loops.
	storm_alpha.handle_mob_log_in(alpha_mob)
	TEST_ASSERT_EQUAL(length(alpha_mob.GetComponents(/datum/component/area_sound_manager)), 1, \
		"logging in inside a storm's own site did not produce exactly one sound manager")
	storm_beta.handle_mob_log_in(alpha_mob)
	TEST_ASSERT_EQUAL(length(alpha_mob.GetComponents(/datum/component/area_sound_manager)), 1, \
		"a co-tenant's concurrent storm stacked a second sound manager on a mob that is nowhere near it")
	TEST_ASSERT(!length(beta_mob.GetComponents(/datum/component/area_sound_manager)), \
		"a mob standing in site B collected a sound manager from site A's storm")

	// end() is what unregisters COMSIG_GLOB_MOB_CREATED and the per-mob login hooks. The
	// allocate()d storms would be ended by the test teardown anyway; doing it here keeps the
	// area swap below from happening under a live storm.
	storm_alpha.end()
	storm_beta.end()
	storm_global.end()
	TEST_ASSERT(!vc_weather_test_is_listening(storm_global, beta_mob, COMSIG_MOB_LOGIN), \
		"end() left its COMSIG_MOB_LOGIN registrations on every mob in the round")

	turf_alpha.change_area(alpha_area, original_alpha_area)
	turf_beta.change_area(beta_area, original_beta_area)
	qdel(alpha_area)
	qdel(beta_area)

/**
 * # run_weather() hands the scheduling site to the storm it builds
 *
 * Guards: the duplicated run_weather() body from the 2026-08 tg upgrade, in which upstream's
 * rewritten call ran and returned and the fork's site-passing call sat below it as
 * unreachable code. Every site-scheduled storm was therefore built with weather_site = null
 * and scoped_areas = null, and setup_weather_areas() fell through to the world-wide
 * get_areas(area_type) sweep - which, because every voidcrew planet storm shares
 * area_type = /area/overmap_encounter/planetoid, impacted all four co-tenants on the level.
 *
 * The existing suite could not catch this: its two sites owned the only areas of their type
 * in the test zone, so the z-wide sweep happened to return the right answer. The third,
 * unowned area below is what removes that accident.
 */
/datum/unit_test/weather_site_launch_carries_site

/datum/unit_test/weather_site_launch_carries_site/Run()
	var/datum/controller/subsystem/weather/unit_test/scheduler = allocate(/datum/controller/subsystem/weather/unit_test)

	var/turf/turf_alpha = run_loc_floor_bottom_left
	var/turf/turf_beta = locate(turf_alpha.x + 1, turf_alpha.y, turf_alpha.z)
	var/turf/turf_gamma = locate(turf_alpha.x + 2, turf_alpha.y, turf_alpha.z)
	TEST_ASSERT(isturf(turf_beta) && isturf(turf_gamma), "the unit test zone had no third turf to build a weather site on")
	var/test_z = turf_alpha.z

	var/area/original_alpha_area = turf_alpha.loc
	var/area/original_beta_area = turf_beta.loc
	var/area/original_gamma_area = turf_gamma.loc
	var/area/weather_site_unit_test/alpha/alpha_area = new
	var/area/weather_site_unit_test/beta/beta_area = new
	var/area/weather_site_unit_test/gamma/gamma_area = new
	turf_alpha.change_area(original_alpha_area, alpha_area)
	turf_beta.change_area(original_beta_area, beta_area)
	turf_gamma.change_area(original_gamma_area, gamma_area)

	var/datum/weather_site/alpha_site = new("unit-test-launch-alpha", test_z, list(/datum/weather/unit_test/site_scoped = 100), 1)
	alpha_site.set_owned_areas(list(alpha_area))
	alpha_site.set_area_scoped()

	var/datum/weather/storm = scheduler.run_weather(/datum/weather/unit_test/site_scoped, list(test_z), null, alpha_site)

	TEST_ASSERT_EQUAL(storm.weather_site, alpha_site, \
		"run_weather() did not pass the scheduling site to the storm - setup_weather_areas() will fall back to the world-wide get_areas(area_type) sweep")
	TEST_ASSERT(!isnull(storm.scoped_areas), \
		"a site-launched storm was built with no scoped_areas")
	TEST_ASSERT_EQUAL(length(storm.scoped_areas), 1, \
		"a site-launched storm was handed area instances its site does not own")
	TEST_ASSERT(storm.scoped_areas[1] == alpha_area, \
		"a site-launched storm was handed an area instance its site does not own")

	// The impacted set must be the site's owned areas, not the type sweep.
	TEST_ASSERT(storm.impacted_areas_lookup[alpha_area], \
		"a site-launched storm did not impact the area its site owns")
	TEST_ASSERT(!storm.impacted_areas_lookup[beta_area], \
		"a site-launched storm impacted a co-tenant site's area on the same z-level")
	TEST_ASSERT(!storm.impacted_areas_lookup[gamma_area], \
		"a site-launched storm swept up an unowned area of its own area_type - it is using get_areas(area_type) rather than the site's areas")
	TEST_ASSERT_EQUAL(length(storm.impacted_areas), 1, \
		"a site-launched storm impacted [length(storm.impacted_areas)] areas where its site owns 1")

	// Control: with no site, the sweep is upstream's answer and finds all three. If it
	// stopped doing so, the three assertions above would pass for the wrong reason.
	var/datum/weather/unscoped = scheduler.run_weather(/datum/weather/unit_test/site_scoped, list(test_z), null, null)
	TEST_ASSERT(unscoped.impacted_areas_lookup[alpha_area] && unscoped.impacted_areas_lookup[beta_area] && unscoped.impacted_areas_lookup[gamma_area], \
		"a storm with no weather site stopped falling back to get_areas(area_type), so the site-scoping assertions above prove nothing")

	storm.end()
	unscoped.end()

	turf_alpha.change_area(alpha_area, original_alpha_area)
	turf_beta.change_area(beta_area, original_beta_area)
	turf_gamma.change_area(gamma_area, original_gamma_area)
	qdel(alpha_area)
	qdel(beta_area)
	qdel(gamma_area)

/**
 * # One storm per site, and a site keeps its storm until it is over
 *
 * Guards: the packed-level scheduling invariant, 2026-08 tg upgrade. Two sites on one
 * z-level storm independently (voidcrew_weather_sites.dm covers that), but a single site
 * must never hold two storms at once - concurrent storms on one patch of ground stack
 * overlays, ambience and mob damage, which is what "all weather types at once" looked like
 * from inside. has_active_weather() is the gate and it has to stay true through every stage
 * of a running storm, not just the main one.
 */
/datum/unit_test/weather_site_one_storm_at_a_time

/datum/unit_test/weather_site_one_storm_at_a_time/Run()
	var/datum/controller/subsystem/weather/unit_test/scheduler = allocate(/datum/controller/subsystem/weather/unit_test)

	var/turf/turf_alpha = run_loc_floor_bottom_left
	var/test_z = turf_alpha.z
	var/area/original_alpha_area = turf_alpha.loc
	var/area/weather_site_unit_test/alpha/alpha_area = new
	turf_alpha.change_area(original_alpha_area, alpha_area)

	// An explicit downtime multiplier, so the scheduler never has to ask SSovermap_zones -
	// a CIBUILDING world has no overmap.
	var/datum/weather_site/alpha_site = new("unit-test-one-storm", test_z, list(/datum/weather/unit_test/site_scoped = 100), 1)
	alpha_site.set_owned_areas(list(alpha_area))
	alpha_site.set_area_scoped()
	scheduler.register_weather_site(alpha_site)

	TEST_ASSERT(alpha_site in scheduler.eligible_sites, \
		"a site registered with a weight table was not made eligible to roll a storm")

	scheduler.fire()
	var/datum/weather/first = alpha_site.active_weather
	TEST_ASSERT(!isnull(first), "an eligible site with a weight table did not roll a storm")
	TEST_ASSERT_EQUAL(first.weather_site, alpha_site, \
		"the scheduler rolled a storm without handing it the site that scheduled it")

	// A second attempt while the first storm is alive must be suppressed, at every stage the
	// storm passes through - telegraph, main, wind-down. Driven by assignment rather than by
	// waiting on the real timers, which are minutes long and random.
	for(var/running_stage in list(STARTUP_STAGE, MAIN_STAGE, WIND_DOWN_STAGE))
		first.stage = running_stage
		TEST_ASSERT(alpha_site.has_active_weather(), \
			"a site did not report its own storm as active at stage [running_stage]")
		scheduler.eligible_sites |= alpha_site
		scheduler.fire()
		TEST_ASSERT_EQUAL(alpha_site.active_weather, first, \
			"a second launch attempt was not suppressed while the site's storm was still running at stage [running_stage]")

	// And the other direction: once it is genuinely over, the site is free again.
	first.end()
	TEST_ASSERT_EQUAL(first.stage, END_STAGE, "end() did not take the storm to END_STAGE")
	TEST_ASSERT(!alpha_site.has_active_weather(), \
		"a site whose storm has finished was not free to schedule another one")

	scheduler.eligible_sites |= alpha_site
	scheduler.fire()
	var/datum/weather/second = alpha_site.active_weather
	TEST_ASSERT(!isnull(second), "a site whose storm had ended did not roll a replacement")
	TEST_ASSERT(second != first, "a site re-adopted its finished storm instead of rolling a new one")

	// Teardown ends the running storm and cancels the site's pending cooldown timer.
	scheduler.unregister_weather_site(alpha_site)
	TEST_ASSERT_EQUAL(second.stage, END_STAGE, "unregistering a weather site left its storm running")
	TEST_ASSERT(isnull(alpha_site.next_hit_timer), "unregistering a weather site left its cooldown timer armed")

	turf_alpha.change_area(alpha_area, original_alpha_area)
	qdel(alpha_area)

/**
 * # Every planet's climate rolls the storms that planet is scoped for
 *
 * Guards: the silent-reparenting failure mode, 2026-08 tg upgrade. Upstream moved ash_storm
 * and rain_storm under /datum/weather/particle. Getting those paths wrong fails silently -
 * DM happily creates the phantom type, voidcrew/datums/weather.dm compiles, and the real
 * storm simply never gets its area_type scoped to /area/overmap_encounter/planetoid, which
 * on a packed level means its overlays and effects land on every co-tenant.
 *
 * Rather than assert the paths, this walks each planet's climate trait through the same
 * weather_weights_for_traits() the scheduler uses and checks what actually comes back. A
 * reparented storm drops out of the table (the phantom keeps probability 0), and any new
 * upstream storm that starts matching a planet trait shows up in it unscoped.
 */
/datum/unit_test/weather_planet_climate_tables

/datum/unit_test/weather_planet_climate_tables/Run()
	// Size of the weight table each planet's climate trait produces, recorded so that an
	// upstream type quietly joining or leaving a planet's roster has to be looked at.
	// Update deliberately, with the reason.
	var/static/list/expected_table_size = list(
		/datum/overmap/planet/lava = 2, // ash storm + emberfall
		/datum/overmap/planet/ice = 1, // snow storm (forever_storm is probability 0)
		/datum/overmap/planet/beach = 1, // rain storm (every other rain variant is probability 0)
		/datum/overmap/planet/jungle = 1, // rain storm
		/datum/overmap/planet/wasteland = 2, // sand storm + its harmless sandfall variant
	)

	for(var/datum/overmap/planet/planet_type as anything in subtypesof(/datum/overmap/planet))
		var/climate_trait = initial(planet_type.weather_trait)
		if(isnull(climate_trait))
			continue // flat encounters: empty space, crashed ships, asteroids

		var/datum/weather/controller = initial(planet_type.weather_controller_type)
		TEST_ASSERT(ispath(controller, /datum/weather), \
			"[planet_type] names [controller || "null"] as its weather, which is not a /datum/weather")
		TEST_ASSERT(initial(controller.abstract_type) != controller, \
			"[planet_type] names the abstract type [controller] as its weather, which can never be instantiated")

		var/list/climate_traits = list()
		climate_traits[climate_trait] = TRUE
		var/list/table = SSweather.weather_weights_for_traits(climate_traits)

		TEST_ASSERT(table[controller] > 0, \
			"[planet_type]'s own storm [controller] is not in the weight table its climate trait [climate_trait] produces - it has probably been reparented upstream, leaving a phantom type behind")
		TEST_ASSERT(!isnull(expected_table_size[planet_type]), \
			"[planet_type] carries a weather trait but no recorded table size - record one, with the reason, so an upstream roster change has to be looked at")
		TEST_ASSERT_EQUAL(length(table), expected_table_size[planet_type], \
			"[planet_type]'s climate trait [climate_trait] now rolls [length(table)] weather types where [expected_table_size[planet_type]] were recorded - an upstream weather type started or stopped matching this planet's traits")

		// Everything a planet can roll has to be scoped to planet areas. Upstream's own
		// default is area_type = /area or /area/space, which on a bounded planet paints the
		// cordon and the empty space around it, and on a packed level paints the neighbours.
		for(var/datum/weather/rollable as anything in table)
			TEST_ASSERT_EQUAL(initial(rollable.area_type), /area/overmap_encounter/planetoid, \
				"[rollable] can roll on [planet_type] but is not scoped to /area/overmap_encounter/planetoid - it will impact every co-tenant packed onto the level")
			TEST_ASSERT(initial(rollable.abstract_type) != rollable, \
				"[planet_type] can roll the abstract type [rollable]")

		// Red-band planets carry radiation fronts on top of their own climate, weighted
		// against it. "Weather_Radstorm" is ZTRAIT_RADSTORM; fork defines are not available
		// at this include position.
		var/list/red_traits = climate_traits.Copy()
		red_traits["Weather_Radstorm"] = TRUE
		var/list/red_table = SSweather.weather_weights_for_traits(red_traits)
		TEST_ASSERT(red_table[/datum/weather/rad_storm/planetary] > 0, \
			"a red-band [planet_type] can no longer roll the planetary radiation front")
		TEST_ASSERT_EQUAL(length(red_table), length(table) + 1, \
			"a red-band [planet_type]'s table gained something other than the planetary radiation front")

/**
 * # The hand-mirrored end() still says what upstream's says
 *
 * Guards: the drift found in the 2026-08 tg upgrade. /datum/weather/rad_storm/planetary/end()
 * is a deliberate verbatim copy of /datum/weather/end() - the parent cannot be reached,
 * because /datum/weather/rad_storm/end() announces to every player in the round including
 * crews several sectors away, and DM has no way to call a grandparent. The merge changed the
 * base proc three ways (bare `return` became `return FALSE`, a COMSIG_GLOB_MOB_CREATED
 * unregister was added, and a target_trait login-cleanup loop plus `return TRUE` were added)
 * and the copy got none of them.
 *
 * DM has no reflection over proc bodies, so this compares the source text: every statement
 * line of /datum/weather/end() must appear, in order, in the mirror. The report that found
 * the drift proposed this as a lint under tools/; it lives here instead so it runs in the
 * same place as the rest of the weather coverage.
 *
 * If upstream changes end() and the change genuinely does not belong in the mirror, add the
 * exception here explicitly rather than deleting the test.
 */
/datum/unit_test/weather_mirrored_end_source_sync

/datum/unit_test/weather_mirrored_end_source_sync/Run()
	var/base_path = "code/datums/weather/weather.dm"
	var/mirror_path = "voidcrew/datums/weather.dm"
	TEST_ASSERT(fexists(base_path) && fexists(mirror_path), \
		"this test compares proc source text and needs the repository checkout beside the .dmb; [base_path] or [mirror_path] was not readable")

	var/list/base_body = vc_weather_test_proc_body(base_path, "/datum/weather/proc/end()")
	var/list/mirror_body = vc_weather_test_proc_body(mirror_path, "/datum/weather/rad_storm/planetary/end()")
	TEST_ASSERT(length(base_body), "could not find the body of /datum/weather/proc/end() in [base_path]")
	TEST_ASSERT(length(mirror_body), "could not find the body of /datum/weather/rad_storm/planetary/end() in [mirror_path]")

	var/mirror_index = 1
	for(var/base_line in base_body)
		var/found = FALSE
		while(mirror_index <= length(mirror_body))
			var/mirror_line = mirror_body[mirror_index]
			mirror_index++
			if(mirror_line == base_line)
				found = TRUE
				break
		TEST_ASSERT(found, \
			"/datum/weather/rad_storm/planetary/end() has drifted from /datum/weather/end(): it is missing `[trim(base_line)]`. Re-mirror it (voidcrew/datums/weather.dm) or record the deliberate exception here.")

/**
 * # Both endings release everything a storm was holding
 *
 * The runtime half of the mirror guard above: whatever cleanup /datum/weather/end() is
 * observed to do, the hand-mirrored /datum/weather/rad_storm/planetary/end() must do too.
 * The drift found in the 2026-08 tg upgrade is exactly the class of change that lands in one
 * body and not the other, and a storm that survives its own ending keeps its site and every
 * area instance it impacted - on a planet that is the surface, every cave and every ruin
 * area - for the rest of the round.
 */
/datum/unit_test/weather_mirrored_end_invariants

/datum/unit_test/weather_mirrored_end_invariants/Run()
	var/turf/turf_alpha = run_loc_floor_bottom_left
	var/test_z = turf_alpha.z
	var/area/original_alpha_area = turf_alpha.loc
	var/area/weather_site_unit_test/alpha/alpha_area = new
	turf_alpha.change_area(original_alpha_area, alpha_area)

	// The control uses /datum/weather/end() itself; the subject uses the hand-mirror.
	for(var/datum/weather/storm_type as anything in list(/datum/weather/unit_test/site_scoped, /datum/weather/rad_storm/planetary))
		var/datum/weather_site/site = new("unit-test-end-[storm_type]", test_z, list(), 1)
		site.set_owned_areas(list(alpha_area))
		site.set_area_scoped()

		var/datum/weather/storm = allocate(storm_type, list(test_z), null, site)
		site.active_weather = storm
		storm.stage = MAIN_STAGE
		SSweather.processing |= storm
		storm.update_areas()

		TEST_ASSERT(storm.impacted_areas_lookup[alpha_area], \
			"[storm_type] did not impact the area its site owns, so the teardown assertions below prove nothing")
		TEST_ASSERT(length(storm.overlay_cache), \
			"[storm_type] painted no overlays while running, so the overlay assertion below proves nothing")

		TEST_ASSERT(storm.end(), \
			"[storm_type]'s end() did not report success on a real ending - upstream's end() returns TRUE and every caller that chains through ..() reads it")

		TEST_ASSERT_EQUAL(storm.stage, END_STAGE, \
			"[storm_type]'s end() did not take the storm to END_STAGE")
		TEST_ASSERT(!(storm in SSweather.processing), \
			"[storm_type]'s end() left the storm in SSweather.processing")
		TEST_ASSERT(isnull(storm.weather_site), \
			"[storm_type]'s end() left the storm pointing back at the site that scheduled it")
		TEST_ASSERT(isnull(site.active_weather), \
			"[storm_type]'s end() left the finished storm held by its weather site")
		TEST_ASSERT(!length(alpha_area.overlays), \
			"[storm_type]'s end() left its weather overlays painted on the area it impacted")
		TEST_ASSERT_EQUAL(storm.end(), FALSE, \
			"[storm_type]'s end() did not return FALSE on a redundant second call - a subtype chaining through ..() cannot tell a real ending from a repeat")

	turf_alpha.change_area(alpha_area, original_alpha_area)
	qdel(alpha_area)

/**
 * # A doppler tower storms the place it is standing on, and nowhere else
 *
 * Guards: the unscoped off-station summon, new upstream in the 2026-08 tg upgrade. The
 * tower's is_on_station() is false for a ship sitting on a planet - a planet z is not a
 * station level - so it took the off-station branch with affected_areas left null, and
 * setup_weather_areas() fell through to get_areas(area_type). Every voidcrew planet storm
 * shares area_type = /area/overmap_encounter/planetoid, so the crew that paid the charge got
 * the weather they asked for and up to three neighbouring crews got weather nobody asked
 * for. A tower is mapped on ship_irish.
 *
 * This registers its sites on the live SSweather, because summon_weather() resolves the site
 * under itself through SSweather directly. Results are captured and the registry is torn
 * down BEFORE any assertion, so a failure here cannot leave sites behind for later tests.
 */
/datum/unit_test/weather_doppler_tower_scoping

/datum/unit_test/weather_doppler_tower_scoping/Run()
	var/turf/turf_alpha = run_loc_floor_bottom_left
	var/turf/turf_beta = locate(turf_alpha.x + 1, turf_alpha.y, turf_alpha.z)
	var/turf/turf_gamma = locate(turf_alpha.x + 2, turf_alpha.y, turf_alpha.z)
	TEST_ASSERT(isturf(turf_beta) && isturf(turf_gamma), "the unit test zone had no third turf to build a weather site on")
	var/test_z = turf_alpha.z

	var/area/original_alpha_area = turf_alpha.loc
	var/area/original_beta_area = turf_beta.loc
	var/area/original_gamma_area = turf_gamma.loc
	var/area/weather_site_unit_test/alpha/alpha_area = new
	var/area/weather_site_unit_test/beta/beta_area = new
	var/area/weather_site_unit_test/gamma/gamma_area = new
	turf_alpha.change_area(original_alpha_area, alpha_area)
	turf_beta.change_area(original_beta_area, beta_area)
	turf_gamma.change_area(original_gamma_area, gamma_area)

	// Empty weight tables: these sites are registered so the tower can find one under
	// itself, and must never become eligible for the live scheduler to roll a storm on.
	var/datum/weather_site/alpha_site = new("unit-test-doppler-alpha", test_z, list(), 1)
	alpha_site.set_owned_areas(list(alpha_area))
	alpha_site.set_area_scoped()
	alpha_site.add_footprint_rect(turf_alpha.x, turf_alpha.y, turf_alpha.x, turf_alpha.y)
	var/datum/weather_site/beta_site = new("unit-test-doppler-beta", test_z, list(), 1)
	beta_site.set_owned_areas(list(beta_area))
	beta_site.set_area_scoped()
	beta_site.add_footprint_rect(turf_beta.x, turf_beta.y, turf_beta.x, turf_beta.y)
	SSweather.register_weather_site(alpha_site)
	SSweather.register_weather_site(beta_site)

	var/obj/machinery/power/weather_tower/unit_test/tower = allocate(/obj/machinery/power/weather_tower/unit_test, turf_alpha)
	tower.core = new /obj/item/assembly/signaler/anomaly/weather(tower)
	tower.active = TRUE

	var/on_station = tower.is_on_station()
	// Identify the storm by what appeared in SSweather.processing rather than by type, so a
	// storm left running by anything else cannot be mistaken for this one.
	var/list/already_running = SSweather.processing.Copy()
	var/summoned = tower.summon_weather(/datum/weather/unit_test/site_scoped)
	var/datum/weather/storm
	for(var/datum/weather/candidate as anything in SSweather.processing)
		if(candidate in already_running)
			continue
		storm = candidate
		break

	var/hit_own_site = !isnull(storm) && storm.impacted_areas_lookup[alpha_area]
	var/hit_co_tenant = !isnull(storm) && storm.impacted_areas_lookup[beta_area]
	var/hit_unowned = !isnull(storm) && storm.impacted_areas_lookup[gamma_area]
	var/impacted_count = isnull(storm) ? 0 : length(storm.impacted_areas)

	// Teardown first: everything above touched the live SSweather registry.
	storm?.end()
	SSweather.unregister_weather_site(alpha_site)
	SSweather.unregister_weather_site(beta_site)
	turf_alpha.change_area(alpha_area, original_alpha_area)
	turf_beta.change_area(beta_area, original_beta_area)
	turf_gamma.change_area(gamma_area, original_gamma_area)
	qdel(alpha_area)
	qdel(beta_area)
	qdel(gamma_area)

	TEST_ASSERT(!on_station, \
		"the unit test z-level became a station level, so the tower took its on-station branch and this test proves nothing about the off-station one")
	TEST_ASSERT(summoned, "the doppler tower refused to summon its test weather at all")
	TEST_ASSERT(!isnull(storm), "the doppler tower reported a successful summon but no storm reached SSweather.processing")
	TEST_ASSERT(hit_own_site, \
		"a doppler tower's summon did not reach the site the tower is standing on")
	TEST_ASSERT(!hit_co_tenant, \
		"a doppler tower's summon reached a co-tenant site on the same z-level - it is summoning unscoped weather again")
	TEST_ASSERT(!hit_unowned, \
		"a doppler tower's summon swept up an unowned area of the storm's area_type - it fell through to get_areas(area_type)")
	TEST_ASSERT_EQUAL(impacted_count, 1, \
		"a doppler tower's summon impacted [impacted_count] areas where the site under it owns 1")
