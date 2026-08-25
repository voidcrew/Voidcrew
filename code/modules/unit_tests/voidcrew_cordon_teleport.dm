/**
 * # Voidcrew cordon teleport containment test
 *
 * /turf/cordon is the world border: dense, opaque, airless and genuinely indestructible -
 * ScrapeAway() returns itself, Melt() no-ops, and explosions, acid and jaunts do nothing.
 * A mob that ARRIVES inside one is not stuck in a diggable wall. Unless it happens to land
 * on the single ring of band that touches live ground it is walled in on all four sides by
 * more cordon, so it cannot step out either, and the turf carries no air.
 *
 * Upstream never needed a guard for that, because upstream only ever paints cordon around a
 * turf reservation and generate_cordon() moves those turfs into /area/misc/cordon - a
 * NOTELEPORT area, which every teleport filter already refuses, and whose Entered() dusts
 * trespassers so the case is at least loud. Packed lattice levels paint their inter-slot
 * band with a raw turf swap that deliberately leaves the AREA alone (place_cordon_turf(),
 * voidcrew/datums/map_zones.dm), so the band is /turf/cordon standing in plain /area/space:
 * no NOTELEPORT flag, no Entered() handler, and nothing in check_teleport_valid() keyed on
 * anything but the area. The footprint test in that proc does not cover it either - the
 * gutter belongs to no tenant, map_region_for_turf() answers null, and null means
 * "unclaimed ground, let it through".
 *
 * The observed failure was a planet's bluespace anomaly. It relocates anyone within a tile
 * to a random turf up to 4 away (8 on a Bumped()), a planet's ground runs to the very edge
 * of its 123x123 slot, and the band starts one turf later - so standing near the edge of
 * the world put a crewmember inside it, silently, with no way out and no air.
 *
 * Both halves of the fix are asserted here, because they fail independently:
 *
 *  1. get_teleport_turfs() must not OFFER a cordon turf, so an imprecise teleport lands
 *     somewhere else rather than being refused outright and doing nothing.
 *  2. check_teleport_valid() must REFUSE one, which is the only guard on the precision-0
 *     path - get_teleport_turfs() returns list(center) unfiltered when precision is 0, so
 *     every direct-destination teleporter (pad, hand tele, eigenstate, MOD link) reaches
 *     the destination turf without passing through the filter at all.
 */
/datum/unit_test/voidcrew_cordon_teleport

/datum/unit_test/voidcrew_cordon_teleport/Run()
	var/mob/living/carbon/human/consistent/traveller = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

	var/turf/border_site = run_loc_floor_top_right
	var/original_type = border_site.type
	var/list/original_baseturfs = islist(border_site.baseturfs) ? border_site.baseturfs.Copy() : border_site.baseturfs
	var/turf/cordon = border_site.ChangeTurf(/turf/cordon)

	TEST_ASSERT(istype(cordon, /turf/cordon), "The test turf did not become cordon ([cordon?.type]) - the rest of this test would assert nothing")

	// The premise: this cordon is NOT in /area/misc/cordon, exactly like a packed level's
	// band. If it were, the upstream NOTELEPORT test would carry the whole thing and the
	// guards under test here would never be reached.
	var/area/cordon_area = get_area(cordon)
	TEST_ASSERT(!(cordon_area.area_flags & NOTELEPORT), "The test cordon landed in a NOTELEPORT area ([cordon_area.type]), so this test is not exercising the case it exists for")

	// 1. Never offered as a landing spot.
	var/precision = get_dist(run_loc_floor_bottom_left, cordon)
	TEST_ASSERT(precision > 0, "The two test landmarks are the same turf - there is no radius that reaches the cordon")
	// get_teleport_turfs() became get_valid_teleport_turf(), which picks ONE turf out of the
	// candidates rather than handing back the list, so the exclusion is sampled instead of
	// asserted against a list. 200 draws over a radius this small covers every candidate many
	// times over; a cordon that could be offered would show up in the first handful.
	var/offered_any = FALSE
	for(var/attempt in 1 to 200)
		var/turf/landing = get_valid_teleport_turf(run_loc_floor_bottom_left, run_loc_floor_bottom_left, precision)
		if(isnull(landing))
			continue
		offered_any = TRUE
		TEST_ASSERT(landing != cordon, "get_valid_teleport_turf() offered the world border as a landing spot - an imprecise teleport can seal somebody inside it")
	TEST_ASSERT(offered_any, "get_valid_teleport_turf() returned nothing at all, so the exclusion above proves nothing")

	// 2. Refused outright, which is the only guard the precision-0 path has.
	TEST_ASSERT(!check_teleport_valid(traveller, cordon), "check_teleport_valid() accepted a cordon turf as a destination")
	TEST_ASSERT(!do_teleport(traveller, cordon, channel = TELEPORT_CHANNEL_BLUESPACE, no_effects = TRUE), "do_teleport() reported success teleporting into the world border")
	TEST_ASSERT_EQUAL(get_turf(traveller), run_loc_floor_bottom_left, "The traveller moved despite the teleport into cordon being refused")

	// A normal destination still works - the guard must not be refusing everything.
	TEST_ASSERT(check_teleport_valid(traveller, run_loc_floor_bottom_left), "check_teleport_valid() refused an ordinary floor turf, so the cordon guard is over-broad")

	border_site.ChangeTurf(original_type, original_baseturfs)
