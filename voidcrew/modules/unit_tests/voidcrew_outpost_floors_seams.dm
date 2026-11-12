/**
 * Outpost floors (voidcrew/modules/trade_floors/): P0's seam tests.
 * Owner: P0. They prove the three things the design could not: the host lives off the overmap, its overrides run
 * from where the module is included, and a blast stays on the floor it went off on. The rest check that every seam
 * answers as the game did before floors.
 *
 * On include order, measured once with a probe type in this file (which compiles before player_outposts/): a
 * subtype's override of a proc declared later does run, and the compiler says nothing. Only a redefinition on the
 * same type written before the proc's declaration is dead (warning override_before_def).
 */

// ===== THE HOST LIVES OFF THE OVERMAP =====

/// Made in nullspace, the host initialises, answers every lookup that walks the outpost and overmap lists, and deletes
/datum/unit_test/voidcrew_outpost_floors/seam_host_off_overmap

/datum/unit_test/voidcrew_outpost_floors/seam_host_off_overmap/Run()
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = new(null)
	made_hosts += host
	TEST_ASSERT(host.flags_1 & INITIALIZED_1, "A host made off the map did not initialise")
	TEST_ASSERT_NULL(host.loc, "A host made off the map is somewhere")
	TEST_ASSERT(host in GLOB.player_outposts, "A floor host is not a player outpost")
	TEST_ASSERT(host in GLOB.overmap_objects, "A floor host is not in the overmap registry")
	TEST_ASSERT(!host.sensor_detectable, "A floor host can be charted")
	TEST_ASSERT_NULL(host.mapzone, "A floor host has a level of its own")

	// With no floor it owns nothing, and none of these may runtime on a host that is nowhere
	var/turf/somewhere = run_loc_floor_bottom_left
	TEST_ASSERT(!host.is_turf_buildable(somewhere), "A host with no floor calls a stray tile buildable")
	TEST_ASSERT(!host.contains_service_turf(somewhere), "A host with no floor claims a stray tile")
	TEST_ASSERT(get_outpost_from_atom(somewhere) != host, "A stray tile resolves to a floor host")
	TEST_ASSERT(player_outpost_on_level(somewhere.z) != host, "A floor host claims a whole level")
	TEST_ASSERT(SSovermap_zones.get_overmap_object_for_turf(somewhere) != host, "A floor host is found as the owner of a stray tile")
	TEST_ASSERT_NULL(host.upgrade_level_z(), "A floor host with no ground names a level for its rooms")
	TEST_ASSERT_EQUAL(length(host.announcement_listeners(null)), 0, "A floor host with no ground has listeners")
	TEST_ASSERT_NULL(host.get_relative_overmap_coords(), "A floor host has overmap coordinates")
	TEST_ASSERT_NULL(host.advert_coords(), "A floor host gives an advert coordinates of its own")
	TEST_ASSERT_NULL(host.network_zone_turf(), "A floor host has an overmap turf for the network")
	TEST_ASSERT_NULL(get_turf(host), "A floor host has a turf")
	host.sync_close_overmap_objects()
	host.adopt_built_turfs()
	host.ship_notify("test")
	TEST_ASSERT(!length(host.close_overmap_objects), "A floor host is beside something on the overmap")

	// A sensor sweep of the whole chart from any contact never finds it
	var/turf/chart_tile
	for(var/obj/structure/overmap/contact in GLOB.overmap_objects)
		if(isturf(contact.loc))
			chart_tile = contact.loc
			break
	if(chart_tile)
		TEST_ASSERT(!(host in overmap_sensor_range(200, chart_tile)), "A sensor sweep found a floor host")

	// A floor of its own: its ground is the host's, the landing and the hull are not for building
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	host.floor = floor
	floor.host = host
	var/turf/deck = deck_tile(floor)
	TEST_ASSERT_EQUAL(get_outpost_from_atom(deck), host, "A service on a floor's deck does not find the floor")
	TEST_ASSERT_EQUAL(get_outpost_from_atom(floor.alcove_turfs[1]), host, "A service on a floor's landing does not find the floor")
	TEST_ASSERT_EQUAL(SSovermap_zones.get_overmap_object_for_turf(deck), outpost, "A floor's deck is not part of its trader outpost for the overmap")
	TEST_ASSERT(host.is_turf_buildable(deck), "A floor's deck is not buildable")
	TEST_ASSERT(!host.is_turf_buildable(floor.alcove_turfs[1]), "A floor's landing is buildable (A5)")
	TEST_ASSERT(!host.is_turf_buildable(floor_tile(floor, 0, 3)), "A floor's hull is buildable")
	TEST_ASSERT(!host.is_turf_buildable(somewhere), "A floor host calls a tile off its floor buildable")

	// Deleting it unlinks both ways and leaves every list
	qdel(host)
	TEST_ASSERT_NULL(floor.host, "A deleted host is still its floor's")
	TEST_ASSERT(!(host in GLOB.player_outposts), "A deleted floor host is still a player outpost")
	TEST_ASSERT(!(host in GLOB.overmap_objects), "A deleted floor host is still in the overmap registry")
	TEST_ASSERT_NULL(get_outpost_from_atom(deck), "A floor with no host still resolves to one")

// ===== OVERRIDES RUN FROM WHERE THE MODULE IS INCLUDED =====

/// The host's override of a proc first declared in player_outposts/ runs: trade_floors/ is included after it
/datum/unit_test/voidcrew_outpost_floors/seam_override_order

/datum/unit_test/voidcrew_outpost_floors/seam_override_order/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	// The parent's is_turf_buildable() needs build_bounds and a mapzone, and a floor host has neither: only the
	// override can say yes. The same holds for contains_service_turf().
	TEST_ASSERT_NULL(host.build_bounds, "The test host has build bounds, so this proves nothing")
	TEST_ASSERT_NULL(host.mapzone, "The test host has a mapzone, so this proves nothing")
	TEST_ASSERT(host.is_turf_buildable(deck), "The floor host's is_turf_buildable() override did not run")
	TEST_ASSERT(host.contains_service_turf(deck), "The floor host's contains_service_turf() override did not run")

// ===== TWO LOOKUPS =====

/// The law finds a floor only while it is public ground or under warrant; the floor lookup always; blast protection never
/datum/unit_test/voidcrew_outpost_floors/seam_two_lookups

/datum/unit_test/voidcrew_outpost_floors/seam_two_lookups/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 3)
	if(!floor)
		return
	var/turf/deck = deck_tile(floor)
	var/turf/hull = floor_tile(floor, 0, 3)
	var/turf/elsewhere = run_loc_floor_bottom_left

	TEST_ASSERT_EQUAL(floor.lift_id(), 103, "Floor 3's lift id is not OUTPOST_FLOOR_ID_BASE + 3")
	TEST_ASSERT_EQUAL(outpost.floor_by_id(103), floor, "The outpost does not find floor 3 by its lift id")
	TEST_ASSERT_NULL(outpost.floor_by_id(101), "The outpost finds a floor it does not have")
	TEST_ASSERT_NULL(outpost.floor_by_id(3), "A berth's id finds a floor")
	TEST_ASSERT_EQUAL(get_outpost_floor_for_turf(deck), floor, "The floor lookup misses the deck")
	TEST_ASSERT_EQUAL(get_outpost_floor_for_turf(hull), floor, "The floor lookup misses the hull")
	TEST_ASSERT_NULL(get_outpost_floor_for_turf(elsewhere), "The floor lookup finds a floor where there is none")
	TEST_ASSERT_EQUAL(outpost.floor_at(deck), floor, "The outpost does not find its own floor")

	// Private: not the outpost's ground for the law, but still in the building
	TEST_ASSERT_NULL(get_trader_outpost_for_turf(deck), "A private floor is outpost ground for the law")
	TEST_ASSERT(outpost.holds_turf(deck), "Riding up to a private floor counts as leaving the outpost (A19)")
	TEST_ASSERT(!outpost.holds_turf(elsewhere), "The outpost holds a tile that is not its own")
	TEST_ASSERT(!is_trader_outpost_protected(deck), "A private floor is blast-protected")

	floor.public_ground = TRUE
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(deck), outpost, "Public ground is not outpost ground for the law (A55)")
	TEST_ASSERT(!is_trader_outpost_protected(deck), "A public floor is blast-protected (L28)")
	floor.public_ground = FALSE
	floor.warrant_in_force = TRUE
	TEST_ASSERT_EQUAL(get_trader_outpost_for_turf(deck), outpost, "A floor under warrant is not outpost ground for the law")
	TEST_ASSERT(!is_trader_outpost_protected(deck), "A floor under warrant is blast-protected: a breach would do nothing (A75)")
	floor.warrant_in_force = FALSE
	TEST_ASSERT_NULL(get_trader_outpost_for_turf(deck), "The law still covers a floor that is private again")

	// A deleted floor is nowhere
	qdel(floor)
	TEST_ASSERT_NULL(get_outpost_floor_for_turf(deck), "A deleted floor is still found")
	TEST_ASSERT(!(floor in GLOB.outpost_floors_on_ground), "A deleted floor still has ground")
	TEST_ASSERT_NULL(outpost.floors[3], "A deleted floor is still in its outpost's list")
	TEST_ASSERT_NULL(outpost.floor_by_id(103), "A deleted floor is still found by its lift id")

/// Deleting a trader outpost deletes its floors and their hosts first (A35)
/datum/unit_test/voidcrew_outpost_floors/seam_outpost_takes_floors

/datum/unit_test/voidcrew_outpost_floors/seam_outpost_takes_floors/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/floor = test_floor(outpost, 1, with_host = TRUE)
	if(!floor)
		return
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = floor.host
	var/turf/deck = deck_tile(floor)
	qdel(outpost)
	TEST_ASSERT(QDELETED(floor), "A deleted trader outpost left a floor behind")
	TEST_ASSERT(QDELETED(host), "A deleted trader outpost left a floor's host behind")
	TEST_ASSERT_NULL(get_outpost_floor_for_turf(deck), "A deleted outpost's floor is still found")
	TEST_ASSERT_NULL(get_outpost_from_atom(deck), "A deleted outpost's floor still has a host")

// ===== A BLAST STAYS ON ITS FLOOR =====

/// What the cordon between two turf reservations does to a blast on its own, with and without reactionary explosions
/datum/unit_test/voidcrew_outpost_floors/seam_cordon_alone

/datum/unit_test/voidcrew_outpost_floors/seam_cordon_alone/Run()
	var/datum/turf_reservation/first = test_ground(10, 10)
	var/datum/turf_reservation/second = test_ground(10, 10)
	if(!first || !second)
		return
	var/turf/first_low = first.bottom_left_turfs[1]
	var/turf/first_high = first.top_right_turfs[1]
	var/turf/second_low = second.bottom_left_turfs[1]
	var/turf/second_high = second.top_right_turfs[1]
	TEST_ASSERT_EQUAL(first_low.z, second_low.z, "Two reservations made together are on different levels: the cordon between them cannot be tested")
	// The bomb goes in the corner of the first block nearest the second
	var/turf/epicenter = locate(second_low.x > first_high.x ? first_high.x : first_low.x, second_low.y > first_high.y ? first_high.y : first_low.y, first_low.z)
	var/gap = max(max(second_low.x - epicenter.x, epicenter.x - second_high.x), max(second_low.y - epicenter.y, epicenter.y - second_high.y))
	TEST_ASSERT(gap >= 2 && gap <= 40, "Two reservations made together are [gap] tiles apart: too far to test the cordon between them")
	hold_blasts()
	var/was_reactionary = CONFIG_GET(flag/reactionary_explosions)
	var/list/crossed = list()
	for(var/reactionary in list(TRUE, FALSE))
		CONFIG_SET(flag/reactionary_explosions, reactionary)
		explosion(epicenter, devastation_range = 2, heavy_impact_range = 4, light_impact_range = gap + 6, flame_range = 0, flash_range = 0, adminlog = FALSE, ignorecap = TRUE, silent = TRUE)
		var/reached = 0
		for(var/turf/hit as anything in blasted_turfs())
			if(second.contains_turf(hit))
				reached++
		crossed["[reactionary]"] = reached
		for(var/queue in list("highturf", "medturf", "lowturf", "high_mov_atom", "med_mov_atom", "low_mov_atom", "flameturf", "held_throwturf"))
			SSexplosions.vars[queue] = list()
	CONFIG_SET(flag/reactionary_explosions, was_reactionary)
	log_test("OUTPOST FLOORS seam_cordon_alone: gap [gap], turfs of the next reservation reached with reactionary explosions [crossed["1"]], without [crossed["0"]]")
	TEST_ASSERT_EQUAL(crossed["1"], 0, "With reactionary explosions the cordon let a blast into the next reservation ([crossed["1"]] turfs)")
	TEST_ASSERT(crossed["0"] > 0, "Without reactionary explosions the blast still stopped at the cordon: the floor's own containment is not what holds it")

/// A blast on a floor reaches nothing off that floor, in either config, and a blast off a floor reaches nothing on one (A3).
/// It still breaks what a crew built, on public ground too (L28, A75).
/datum/unit_test/voidcrew_outpost_floors/seam_blast_contained

/datum/unit_test/voidcrew_outpost_floors/seam_blast_contained/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/first = test_floor(outpost, 1)
	var/datum/outpost_floor/second = test_floor(outpost, 2)
	if(!first || !second)
		return
	hold_blasts()
	first.public_ground = TRUE
	var/turf/epicenter = floor_tile(first, 6, 6)
	var/turf/crew_wall = floor_tile(first, 8, 6)
	crew_wall.place_on_top(/turf/closed/wall)
	var/obj/structure/table/near_table = allocate(/obj/structure/table, floor_tile(first, 6, 8))
	var/obj/structure/table/far_table = allocate(/obj/structure/table, deck_tile(second))
	var/list/second_ground = list()
	for(var/turf/tile as anything in block(second.bounds[1], second.bounds[2], second.bounds[5], second.bounds[3], second.bounds[4], second.bounds[5]))
		second_ground[tile] = tile.type
	var/was_reactionary = CONFIG_GET(flag/reactionary_explosions)
	for(var/reactionary in list(TRUE, FALSE))
		CONFIG_SET(flag/reactionary_explosions, reactionary)
		// Far bigger than the floor: light range 40 over a 14 by 12 box
		explosion(epicenter, devastation_range = 2, heavy_impact_range = 5, light_impact_range = 40, flame_range = 0, flash_range = 0, adminlog = FALSE, ignorecap = TRUE, silent = TRUE)
		var/list/turf/hit_turfs = blasted_turfs()
		TEST_ASSERT(length(hit_turfs) > 0, "A bomb on a public floor did not go off (reactionary [reactionary])")
		for(var/turf/hit as anything in hit_turfs)
			if(!first.contains_turf(hit))
				CONFIG_SET(flag/reactionary_explosions, was_reactionary)
				TEST_FAIL("A blast on a floor reached [hit.x],[hit.y] off the floor (reactionary [reactionary])")
				return
		apply_blast()
	CONFIG_SET(flag/reactionary_explosions, was_reactionary)
	TEST_ASSERT(!istype(crew_wall, /turf/closed/wall), "A blast on a public floor left a crew-built wall standing two tiles away (A75)")
	TEST_ASSERT(QDELETED(near_table) || near_table.get_integrity() < near_table.max_integrity, "A blast on a floor left a table two tiles away untouched")
	TEST_ASSERT(!QDELETED(far_table) && far_table.get_integrity() == far_table.max_integrity, "A blast on one floor hurt a table on the next")
	for(var/turf/tile as anything in second_ground)
		TEST_ASSERT_EQUAL(tile.type, second_ground[tile], "A blast on one floor changed the next floor's ground at [tile.x],[tile.y]")

	// The other way: a blast off any floor never enters one
	var/datum/turf_reservation/outside = test_ground(10, 10)
	if(!outside)
		return
	var/turf/outside_low = outside.bottom_left_turfs[1]
	explosion(locate(outside_low.x + 5, outside_low.y + 5, outside_low.z), devastation_range = 2, heavy_impact_range = 5, light_impact_range = 250, flame_range = 0, flash_range = 0, adminlog = FALSE, ignorecap = TRUE, silent = TRUE)
	for(var/turf/hit as anything in blasted_turfs())
		if(first.contains_turf(hit) || second.contains_turf(hit))
			TEST_FAIL("A blast off every floor reached [hit.x],[hit.y] on a floor")
			return

// ===== WHO IS HERE =====

/// On a floor "the players here" are the players on that floor, not everyone on its level (A1)
/datum/unit_test/voidcrew_outpost_floors/seam_site_clients

/datum/unit_test/voidcrew_outpost_floors/seam_site_clients/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/first = test_floor(outpost, 1)
	var/datum/outpost_floor/second = test_floor(outpost, 2)
	if(!first || !second)
		return
	var/mob/living/upstairs = test_person(deck_tile(first))
	var/mob/living/next_door = test_person(deck_tile(second))
	var/mob/living/away = test_person(run_loc_floor_bottom_left)
	// Stand-ins for clients: the list SSmobs keeps of them by level
	var/list/added = list()
	for(var/mob/living/person as anything in list(upstairs, next_door, away))
		var/z = person.z
		if(length(SSmobs.clients_by_zlevel) < z || (person in SSmobs.clients_by_zlevel[z]))
			continue
		SSmobs.clients_by_zlevel[z] += person
		added[person] = z
	var/list/on_first = outpost_site_clients(deck_tile(first, 4))
	// Off a floor the proc hands back SSmobs' own list: copy it before the stand-ins are taken out again
	var/list/off_floor = outpost_site_clients(run_loc_floor_bottom_left).Copy()
	var/list/on_first_level = SSmobs.clients_by_zlevel[first.bounds[5]]
	var/both_on_level = (upstairs in on_first_level) && (next_door in on_first_level)
	for(var/mob/living/person as anything in added)
		SSmobs.clients_by_zlevel[added[person]] -= person
	TEST_ASSERT(both_on_level, "The two test floors are on different levels, so nothing is proven")
	TEST_ASSERT(upstairs in on_first, "Someone on a floor is not counted as being there")
	TEST_ASSERT(!(next_door in on_first), "Someone on the next floor of the same level counts as being on this one (A1)")
	TEST_ASSERT(!(away in on_first), "Someone off the floor counts as being on it")
	TEST_ASSERT(away in off_floor, "Off a floor, the level's players are no longer counted")
	TEST_ASSERT_EQUAL(length(outpost_site_clients(null)), 0, "Nowhere has players")

// ===== THE SEAMS ANSWER AS BEFORE =====

/// With no floors the lift's host answers as it always has, and a panel on a floor knows where it is
/datum/unit_test/voidcrew_outpost_floors/seam_lift_defaults

/datum/unit_test/voidcrew_outpost_floors/seam_lift_defaults/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/mob/living/rider = test_person(run_loc_floor_bottom_left)
	TEST_ASSERT(outpost.may_enter_floor(0, rider), "The concourse refuses a rider")
	TEST_ASSERT(outpost.may_enter_floor(1, rider), "A vacant berth refuses a rider")
	TEST_ASSERT_EQUAL(length(outpost.extra_floor_rows(rider)), 0, "An outpost with no floors lists some")
	TEST_ASSERT(!outpost.lift_leaves_behind(rider, 1, rider), "The lift leaves a rider behind")
	TEST_ASSERT(!outpost.on_lift_emagged(null, rider), "An emag does something to a lift with no floors")
	TEST_ASSERT_EQUAL(outpost.lift_refusal_text(3), "crew only!", "The lift's refusal balloon changed")
	TEST_ASSERT_EQUAL(outpost.lift_refusal_text(3, TRUE), "Berth 3 is crew only.", "The lift's spoken refusal changed")
	outpost.on_lift_ride(null, 1, rider, list(rider))
	TEST_ASSERT_NULL(outpost.get_floor_alcove(101), "An outpost with no floors has an alcove for floor 1")
	TEST_ASSERT_EQUAL(outpost.floor_count, 6, "A trader outpost does not have OUTPOST_FLOORS_PER_OUTPOST floors")

	var/datum/outpost_floor/floor = test_floor(outpost, 2)
	if(!floor)
		return
	var/obj/machinery/outpost_elevator/panel = allocate(/obj/machinery/outpost_elevator, floor.alcove_turfs[1])
	panel.outpost = outpost
	panel.floor = floor
	floor.panel = panel
	TEST_ASSERT_EQUAL(panel.get_current_floor(), 102, "A panel on floor 2 does not know its floor")
	TEST_ASSERT_EQUAL(panel.get_own_alcove(), floor.alcove_turfs, "A panel on a floor does not use the floor's alcove")
	TEST_ASSERT(panel.may_ride_to(0, rider), "A panel on a floor will not go down to the concourse")
	var/list/data = panel.ui_data(rider)
	TEST_ASSERT_EQUAL(data["current_floor"], 102, "A floor panel's window does not know its floor")
	qdel(panel)
	TEST_ASSERT_NULL(floor.panel, "A deleted panel is still its floor's")

/// A player outpost's new hooks answer as an outpost always has, and the stubs answer as if there were no floors
/datum/unit_test/voidcrew_outpost_floors/seam_host_defaults

/datum/unit_test/voidcrew_outpost_floors/seam_host_defaults/Run()
	var/obj/structure/overmap/dynamic/player_outpost/floor/host = new(null)
	made_hosts += host
	var/mob/living/someone = test_person(run_loc_floor_bottom_left)
	TEST_ASSERT_NULL(host.claim_denial(someone), "An outpost refuses a claim for a floors reason")
	TEST_ASSERT(!host.can_take_over(someone), "A lease can be taken over before the rule is written")
	TEST_ASSERT_NULL(host.floor_ui_data(someone), "The management console has floor data with no floor section")
	TEST_ASSERT(!host.floor_ui_act("floor_set_entry", list("entry" = "open"), someone), "An unknown console action was handled")
	TEST_ASSERT(host.pad_follows_dock_modes(), "An outpost's pad no longer follows its docking modes")
	TEST_ASSERT(host.pad_admits(someone), "An outpost's pad has a new lock")
	TEST_ASSERT_EQUAL(host.advert_place(), host.name, "An advert no longer names its outpost")
	TEST_ASSERT(!host.owns_till(null), "An outpost has tills")
	TEST_ASSERT(!host.is_shop_hand(someone), "An outpost has hired hands")
	host.shop_state_changed(null, someone)
	host.on_upgrade_placed(null)

	var/datum/outpost_upgrade/service/shop/room = new
	TEST_ASSERT(host.offers_upgrade(room), "An outpost does not sell the Shop room")
	room.floors_only = TRUE
	TEST_ASSERT(!host.offers_upgrade(room), "An outpost sells a floors-only room before a floor says it may")
	qdel(room)

	TEST_ASSERT(outpost_floor_build_allowed(someone, run_loc_floor_bottom_left), "Building is refused off any floor")
	TEST_ASSERT(outpost_service_build_allowed(someone, run_loc_floor_bottom_left), "The build guard refuses a plain tile")
	TEST_ASSERT(!police_floor_door_override(null, someone), "A door opens for the police with no warrant written")

/// A floor's accent is one of the eight ids and nothing else (A90), and neighbours start with different colours
/datum/unit_test/voidcrew_outpost_floors/seam_accent

/datum/unit_test/voidcrew_outpost_floors/seam_accent/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_floor/first = new(outpost, 1)
	var/datum/outpost_floor/second = new(outpost, 2)
	made_floors += first
	made_floors += second
	TEST_ASSERT(first.accent != second.accent, "Floors 1 and 2 start with the same colour")
	TEST_ASSERT(first.set_accent("teal"), "A real accent id was refused") // OUTPOST_FLOOR_ACCENT_TEAL
	TEST_ASSERT_EQUAL(first.accent_colour(), "#2fb3a8", "Teal is not teal")
	for(var/bad in list("#ff0000", "<b>teal</b>", "", null, 3, "TEAL"))
		TEST_ASSERT(!first.set_accent(bad), "A floor took [isnull(bad) ? "null" : bad] for its accent")
	TEST_ASSERT_EQUAL(first.accent, "teal", "A refused accent changed the floor's colour")
	first.accent = "nonsense"
	TEST_ASSERT_EQUAL(first.accent_colour(), "#e0a030", "A broken accent does not fall back to amber")
	TEST_ASSERT(first.set_entry("open"), "A real entry setting was refused") // OUTPOST_FLOOR_ENTRY_OPEN
	TEST_ASSERT(!first.set_entry("everyone"), "A made-up entry setting was taken")
	TEST_ASSERT_EQUAL(first.entry_policy, "open", "A refused setting changed the floor")

/// The police tick runs its floors step, the two lift crimes are known, and the breach subtree plans before force
/datum/unit_test/voidcrew_outpost_floors/seam_police

/datum/unit_test/voidcrew_outpost_floors/seam_police/Run()
	var/obj/structure/overmap/trader_outpost/outpost = test_outpost()
	var/datum/outpost_police/police = outpost.police
	TEST_ASSERT_NOTNULL(police, "A trader outpost has no police")
	var/datum/outpost_floor/floor = test_floor(outpost, 1)
	if(!floor)
		return
	police.tick_floors()
	TEST_ASSERT(!police.has_work(), "The police have work on a floor before any is written")
	TEST_ASSERT_EQUAL(police.sector_of(deck_tile(floor)), "outside", "A floor with no warrant is a police sector") // POLICE_SECTOR_OUTSIDE
	TEST_ASSERT_EQUAL(length(police.dispatch_lift_tiles(floor)), 0, "A floor that is no sector has lift tiles")
	TEST_ASSERT(!police.dispatch_is_lift_tile(floor.alcove_turfs[1]), "A floor's alcove is a police lift tile before any warrant")
	TEST_ASSERT_EQUAL(length(police.floor_cameras()), 0, "A private floor's panel is a witness")
	TEST_ASSERT_EQUAL(length(floor.visitors_upstairs()), 0, "An empty floor has visitors")
	var/list/tamper = GLOB.outpost_crimes["lift_tamper"] // OUTPOST_CRIME_LIFT_TAMPER
	var/list/abduction = GLOB.outpost_crimes["abduction"] // OUTPOST_CRIME_ABDUCTION
	TEST_ASSERT(islist(tamper) && tamper[2] == 2 && tamper[3] == 2, "Forcing the lift is not two stars")
	TEST_ASSERT(islist(abduction) && abduction[2] == 3 && abduction[3] == 3, "An abduction is not three stars")

	var/datum/ai_controller/brain = new /datum/ai_controller/basic_controller/human_npc/stealth/outpost_police(null)
	var/breach_at = 0
	var/force_at = 0
	for(var/i in 1 to length(brain.planning_subtrees))
		if(istype(brain.planning_subtrees[i], /datum/ai_planning_subtree/outpost_police_breach))
			breach_at = i
		if(istype(brain.planning_subtrees[i], /datum/ai_planning_subtree/outpost_police_force))
			force_at = i
	qdel(brain)
	TEST_ASSERT(breach_at > 0, "An officer's brain has no breach subtree")
	TEST_ASSERT(force_at > breach_at, "An officer plans force before a breach")
