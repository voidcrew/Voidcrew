/// Existing loose tanks must not suppress the refill fallback; repeat audits add nothing.
/datum/unit_test/voidcrew_launch_oxygen

/datum/unit_test/voidcrew_launch_oxygen/Run()
	var/obj/docking_port/mobile/voidcrew/port = allocate(/obj/docking_port/mobile/voidcrew)
	port.width = 1
	port.height = 1
	port.shuttle_areas = list(get_area(port) = TRUE)
	var/obj/item/tank/internals/oxygen/tank = allocate(/obj/item/tank/internals/oxygen)
	port.ensure_starter_supplies()
	var/turf/tile = get_turf(port)
	var/obj/machinery/portable_atmospherics/canister/oxygen/refill = locate() in tile
	var/obj/structure/closet/crate/internals/ship_reserve/reserve = locate() in tile
	TEST_ASSERT_NOTNULL(refill, "Loose oxygen tank prevented the missing refill canister from spawning")
	TEST_ASSERT_NULL(reserve, "Existing tank unnecessarily gained a reserve crate")
	port.ensure_starter_supplies()
	var/count = 0
	for(var/obj/machinery/portable_atmospherics/canister/oxygen/canister in tile)
		count++
	TEST_ASSERT_EQUAL(count, 1, "Repeated starter audit duplicated the oxygen canister")
	qdel(refill)
	qdel(tank)
	allocate(/obj/machinery/portable_atmospherics/canister/air)
	allocate(/obj/structure/closet/emcloset)
	port.ensure_starter_supplies()
	refill = locate() in tile
	TEST_ASSERT_NULL(refill, "Existing air canister was not accepted as a refill source")
	qdel(port, force = TRUE)

/// Force the sampling pass to miss so the exhaustive preferred-zone fallback is exercised.
/datum/mission_target/coords/launch_access_samples
	var/rejections_left = 30

/datum/mission_target/coords/launch_access_samples/try_coordinates(turf/candidate)
	if(rejections_left > 0)
		rejections_left--
		return FALSE
	return ..()

/datum/unit_test/voidcrew_launch_safe_offers
	var/datum/overmap_zone/saved_green
	var/list/saved_types
	var/turf/open/overmap/target_tile
	var/old_turf_type
	var/saved_blocked

/datum/unit_test/voidcrew_launch_safe_offers/Destroy()
	if(saved_types)
		SSmissions.mission_types = saved_types
	SSovermap_zones.zone_green = saved_green
	if(target_tile)
		if(saved_blocked)
			GLOB.overmap_blocked_turfs[target_tile] = saved_blocked
		else
			GLOB.overmap_blocked_turfs -= target_tile
		target_tile.current_zone = null
		target_tile.ChangeTurf(old_turf_type)
	return ..()

/datum/unit_test/voidcrew_launch_safe_offers/Run()
	saved_green = SSovermap_zones.zone_green
	saved_types = SSmissions.mission_types
	SSmissions.mission_types = list(/datum/mission/exploration)
	// Fork defines follow test includes: green=1; overmap is51 tiles high.
	var/turf/location = locate(10, world.maxy - 40, run_loc_floor_bottom_left.z)
	old_turf_type = location.type
	target_tile = location.ChangeTurf(/turf/open/overmap)
	saved_blocked = GLOB.overmap_blocked_turfs[target_tile]
	GLOB.overmap_blocked_turfs -= target_tile
	var/datum/overmap_zone/green = allocate(/datum/overmap_zone, 1)
	green.turfs = list(target_tile)
	target_tile.current_zone = green
	SSovermap_zones.zone_green = green

	var/datum/mission_target/coords/launch_access_samples/fallback = allocate(/datum/mission_target/coords/launch_access_samples)
	fallback.preferred_zone = 1
	fallback.zone_weights = list("1" = 1)
	TEST_ASSERT(fallback.resolve(), "Preferred exploration failed after sampling missed the only valid tile")
	TEST_ASSERT(fallback.is_valid(), "Resolved safe coordinates are not valid")
	GLOB.overmap_blocked_turfs[target_tile] = TRUE
	TEST_ASSERT(!fallback.is_valid(), "A newly blocked destination remained valid")
	TEST_ASSERT(!fallback.resolve(), "Blocked coordinates were accepted by the exhaustive fallback")
	GLOB.overmap_blocked_turfs -= target_tile

	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship)
	for(var/index in 1 to 5)
		ship.available_missions += allocate(/datum/mission)
	SSmissions.refresh_ship_missions(ship)
	TEST_ASSERT_EQUAL(length(ship.available_missions), 5, "Safe reservation grew or shrank a full five-slot board")
	var/datum/mission/exploration/safe_offer = locate() in ship.available_missions
	TEST_ASSERT_NOTNULL(safe_offer, "Full unsafe board did not reserve an exploration slot")
	TEST_ASSERT_EQUAL(safe_offer.target.get_zone_type(), 1, "Reserved job is outside green space")
	TEST_ASSERT(safe_offer.value >= 400 && safe_offer.value <= 700, "Reserved job changed the existing green payout")
	SSmissions.refresh_ship_missions(ship)
	TEST_ASSERT(safe_offer in ship.available_missions, "Refresh replaced an existing valid safe offer")
	SSmissions.force_refresh_ship_missions(ship)
	TEST_ASSERT(QDELETED(safe_offer), "Reroll retained the old offer")
	safe_offer = locate() in ship.available_missions
	TEST_ASSERT_NOTNULL(safe_offer, "Reroll omitted the reserved exploration offer")
	TEST_ASSERT_EQUAL(safe_offer.target.get_zone_type(), 1, "Reroll's first exploration job is not green")
	TEST_ASSERT(length(ship.available_missions) <= 5, "Reroll exceeded the board cap")
	// An impossible map is an honest generation failure, not a dangerous substitute.
	green.turfs = list()
	QDEL_LIST(ship.available_missions)
	TEST_ASSERT(!SSmissions.ensure_safe_exploration_offer(ship), "Safe-offer guarantee invented a target when green space was unavailable")

/// Deleting a temporary same-id node must not unregister the canonical techweb.
/datum/unit_test/voidcrew_launch_node_registry

/datum/unit_test/voidcrew_launch_node_registry/Run()
	var/datum/techweb_node/canonical = SSresearch.techweb_nodes[TECHWEB_NODE_ALIENTECH]
	TEST_ASSERT_NOTNULL(canonical, "Live research node registry was lost before the test")
	var/datum/techweb_node/temporary = allocate(/datum/techweb_node/alientech)
	TEST_ASSERT_NOTEQUAL(temporary, canonical, "Fixture must be separate from the canonical node")
	qdel(temporary)
	TEST_ASSERT_EQUAL(SSresearch.techweb_nodes[TECHWEB_NODE_ALIENTECH], canonical, "Temporary node deletion unregistered the live same-id research node")
	// The actual owner must still be removed when it is deleted.
	temporary = allocate(/datum/techweb_node)
	temporary.id = "launch_registry_deletion_test"
	SSresearch.techweb_nodes[temporary.id] = temporary
	qdel(temporary)
	TEST_ASSERT_NULL(SSresearch.techweb_nodes["launch_registry_deletion_test"], "Deleting the registered node left a stale entry")

/datum/unit_test/voidcrew_launch_analyzer

/datum/unit_test/voidcrew_launch_analyzer/Run()
	TEST_ASSERT_NOTNULL(SSresearch.techweb_nodes[TECHWEB_NODE_ALIENTECH], "Analyzer requires the initialized canonical research registry")
	var/obj/machinery/rnd/destructive_analyzer/analyzer = allocate(/obj/machinery/rnd/destructive_analyzer)
	var/datum/techweb/research = allocate(/datum/techweb)
	analyzer.connect_techweb(research)
	analyzer.set_is_operational(TRUE)
	analyzer.machine_stat = NONE
	var/obj/item/crowbar/ordinary = allocate(/obj/item/crowbar, analyzer)
	analyzer.loaded_item = ordinary
	TEST_ASSERT(!analyzer.user_try_decon_id(TECHWEB_NODE_ALIENTECH), "Forged alien node ID accepted an ordinary crowbar")
	TEST_ASSERT_EQUAL(analyzer.loaded_item, ordinary, "Rejected forged request consumed its item")
	TEST_ASSERT(research.hidden_nodes[TECHWEB_NODE_ALIENTECH], "Rejected forged request revealed alien research")
	qdel(ordinary)
	var/obj/item/crowbar/abductor/sample = allocate(/obj/item/crowbar/abductor, analyzer)
	analyzer.loaded_item = sample
	TEST_ASSERT(!analyzer.user_try_decon_id(TECHWEB_NODE_SYNDICATE_BASIC), "Alien sample unlocked unrelated illegal technology")
	TEST_ASSERT(!analyzer.user_try_decon_id("invalid-node-test"), "Unknown node ID was accepted")
	analyzer.busy = TRUE
	TEST_ASSERT(!analyzer.user_try_decon_id(TECHWEB_NODE_ALIENTECH), "Busy analyzer consumed a sample")
	analyzer.busy = FALSE
	analyzer.connect_techweb(null)
	TEST_ASSERT(!analyzer.user_try_decon_id(TECHWEB_NODE_ALIENTECH), "Disconnected analyzer consumed a sample")
	analyzer.connect_techweb(research)
	TEST_ASSERT_EQUAL(analyzer.loaded_item, sample, "Rejected requests consumed the alien sample")
	TEST_ASSERT(analyzer.user_try_decon_id(TECHWEB_NODE_ALIENTECH), "Actual alien crowbar did not reveal its permitted field")
	TEST_ASSERT(QDELETED(sample), "Successful discovery did not consume the sample")
	TEST_ASSERT(!research.hidden_nodes[TECHWEB_NODE_ALIENTECH], "Successful discovery did not unhide the selected field")
	TEST_ASSERT(research.hidden_nodes[TECHWEB_NODE_ALIEN_ENGI], "One sample revealed more than the selected field")
	analyzer.busy = FALSE
	sample = allocate(/obj/item/crowbar/abductor, analyzer)
	analyzer.loaded_item = sample
	TEST_ASSERT(!analyzer.user_try_decon_id(TECHWEB_NODE_ALIENTECH), "Repeated discovery consumed another sample")
	TEST_ASSERT_EQUAL(analyzer.loaded_item, sample, "Already-discovered field destroyed the replacement sample")
	TEST_ASSERT(analyzer.user_try_decon_id("research_points"), "Explicit item destruction stopped working")
	TEST_ASSERT(QDELETED(sample), "Explicit destruction did not consume its item")

/datum/unit_test/voidcrew_launch_bepis
	var/list/saved_deck
	var/obj/machinery/quantum_server/server
	var/datum/lazy_template/virtual_domain/borrowed_domain
	var/saved_disk_reward_spawned

/datum/unit_test/voidcrew_launch_bepis/Destroy()
	if(saved_deck)
		SSresearch.techweb_nodes_experimental = saved_deck
	// Domains are subsystem-owned singletons. Detach before machine cleanup,
	// which otherwise tries to delete its generated_domain, and restore our flag.
	if(!QDELETED(server))
		server.generated_domain = null
	if(!QDELETED(borrowed_domain))
		borrowed_domain.disk_reward_spawned = saved_disk_reward_spawned
	return ..()

/datum/unit_test/voidcrew_launch_bepis/Run()
	saved_deck = SSresearch.techweb_nodes_experimental
	SSresearch.techweb_nodes_experimental = list()
	refill_experimental_technology_deck()
	var/deck_size = length(SSresearch.techweb_nodes_experimental)
	TEST_ASSERT(deck_size > 1, "Experimental deck has no usable full cycle")
	server = allocate(/obj/machinery/quantum_server)
	for(var/datum/lazy_template/virtual_domain/ash_drake/domain in SSbitrunning.all_domains)
		if(!SSbitrunning.get_domain_holder(domain.key))
			borrowed_domain = domain
			break
	TEST_ASSERT_NOTNULL(borrowed_domain, "BEPIS fixture requires an available canonical medium domain")
	saved_disk_reward_spawned = borrowed_domain.disk_reward_spawned
	borrowed_domain.disk_reward_spawned = FALSE
	server.generated_domain = borrowed_domain
	var/datum/techweb/late_crew = allocate(/datum/techweb)
	for(var/cycle in 1 to 2)
		var/list/seen = list()
		for(var/draw in 1 to deck_size)
			TEST_ASSERT(server.can_generate_tech_disk("A"), "Bitrunning lost its disk route before cycle[cycle] draw[draw]")
			var/obj/item/disk/design_disk/bepis/remove_tech/disk = allocate(/obj/item/disk/design_disk/bepis/remove_tech)
			TEST_ASSERT_NOTNULL(disk.bepis_node, "An experimental draw made an empty disk")
			TEST_ASSERT(length(disk.blueprints), "Experimental disk has no usable designs")
			TEST_ASSERT(!(disk.bepis_node.id in seen), "Experimental reward repeated within one finite cycle")
			seen += disk.bepis_node.id
			TEST_ASSERT(length(SSresearch.techweb_nodes_experimental), "The last draw left bitrunning's pre-award check permanently empty")
			if(cycle == 2)
				disk.on_upload(late_crew, server)
				TEST_ASSERT(late_crew.researched_nodes[disk.bepis_node.id], "Second-cycle disk could not teach a later crew")
		TEST_ASSERT_EQUAL(length(SSresearch.techweb_nodes_experimental), deck_size, "Exhausted cycle did not refill the full roster")
	TEST_ASSERT(!server.can_generate_tech_disk("B"), "Refill bypassed bitrunning's grade requirement")
	server.generated_domain.disk_reward_spawned = TRUE
	TEST_ASSERT(!server.can_generate_tech_disk("A"), "Refill bypassed the one-disk-per-domain requirement")

/datum/unit_test/voidcrew_launch_venue_deadline
	var/saved_round_start
	var/list/saved_controls
	var/saved_enabled
	var/saved_attempted

/datum/unit_test/voidcrew_launch_venue_deadline/Destroy()
	SSticker.round_start_time = saved_round_start
	SSdynamic_events.control = saved_controls
	SSdynamic_events.enabled = saved_enabled
	SSdynamic_events.colosseum_deadline_attempted = saved_attempted
	return ..()

/datum/unit_test/voidcrew_launch_venue_deadline/Run()
	saved_round_start = SSticker.round_start_time
	saved_controls = SSdynamic_events.control
	saved_enabled = SSdynamic_events.enabled
	saved_attempted = SSdynamic_events.colosseum_deadline_attempted
	var/datum/round_event_control/voidcrew/grand_colosseum/venue = allocate(/datum/round_event_control/voidcrew/grand_colosseum)
	SSdynamic_events.control = list(venue)
	SSdynamic_events.enabled = TRUE
	SSdynamic_events.colosseum_deadline_attempted = FALSE
	SSticker.round_start_time = world.time - (179 MINUTES)
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(1), "Venue deadline fired before180 minutes")
	SSticker.round_start_time = world.time - (180 MINUTES)
	TEST_ASSERT_EQUAL(SSdynamic_events.get_due_colosseum(1), venue, "Venue deadline still depended on a lucky roll or four players")
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(0), "Empty server bypassed the venue population guard")
	venue.triggering = TRUE
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(1), "Deadline duplicated an in-flight event")
	venue.triggering = FALSE
	venue.occurrences = venue.max_occurrences
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(1), "Deadline bypassed the one-venue occurrence cap")
	venue.occurrences = 0
	SSdynamic_events.colosseum_deadline_attempted = TRUE
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(1), "Deadline retried a previously offered/cancelled event")
	SSdynamic_events.colosseum_deadline_attempted = FALSE
	SSdynamic_events.enabled = FALSE
	TEST_ASSERT_NULL(SSdynamic_events.get_due_colosseum(1), "Deadline bypassed the subsystem's disabled switch")

/// Exercise actual reveal and map-slot teardown without loading a ruin template interior.
/datum/unit_test/voidcrew_launch_fresh_charts
	var/list/spawned_sites = list()

/datum/unit_test/voidcrew_launch_fresh_charts/Destroy()
	for(var/obj/structure/overmap/space_ruin/site as anything in spawned_sites)
		if(!QDELETED(site))
			// On assertion failure, release only this fixture's ports/slot.
			// Space-ruin Destroy releases any footprint still owned by the signal.
			site.remove_docks()
			qdel(site)
	return ..()

/datum/unit_test/voidcrew_launch_fresh_charts/Run()
	var/chart_type = /datum/map_template/ruin/space/rare/hospice
	var/obj/structure/overmap/ship/first_ship = allocate(/obj/structure/overmap/ship)
	var/obj/structure/overmap/ship/second_ship = allocate(/obj/structure/overmap/ship)
	var/datum/rumor_chart/first_chart = allocate(/datum/rumor_chart)
	first_chart.ruin_template_path = chart_type
	first_chart.spawn_zone = 1 // ZONE_GREEN, defined after the unit-test includes.
	var/signals_before = length(GLOB.space_ruin_signals)
	var/obj/structure/overmap/space_ruin/first = first_chart.reveal(first_ship)
	TEST_ASSERT_NOTNULL(first, "A registered chart could not reveal a fresh ruin")
	spawned_sites += first
	// The real teardown yields: keep background contracts out of this fixture.
	first.mission_exclusive = TRUE
	TEST_ASSERT(first.rare && !first.loaded && !first.visited, "Fresh chart inherited an explored interior")
	TEST_ASSERT_EQUAL(first.ruin_template.type, chart_type, "Chart revealed the wrong template")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), signals_before + 1, "Reveal did not create exactly one signal")
	var/datum/ship_waypoint/first_waypoint = first_ship.get_waypoint("rumor_[REF(first)]")
	TEST_ASSERT_EQUAL(first_waypoint?.tracked_target?.resolve(), first, "First crew's waypoint does not track its own new ruin")
	TEST_ASSERT_NULL(first_chart.reveal(first_ship), "One paid chart revealed twice")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), signals_before + 1, "Repeated reveal spawned another signal")

	var/datum/rumor_chart/second_chart = allocate(/datum/rumor_chart)
	second_chart.ruin_template_path = chart_type
	second_chart.spawn_zone = 1
	var/obj/structure/overmap/space_ruin/second = second_chart.reveal(second_ship)
	TEST_ASSERT_NOTNULL(second, "Another chart could not reveal the same template again")
	spawned_sites += second
	second.mission_exclusive = TRUE
	TEST_ASSERT(first != second, "Second buyer received the first crew's encounter")
	TEST_ASSERT(get_turf(first) != get_turf(second), "Fresh encounter overlapped the first ruin's occupied coordinates")
	TEST_ASSERT(!second.loaded && !second.visited, "Second chart reused a visited interior")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), signals_before + 2, "Second chart did not create its own signal")
	var/datum/ship_waypoint/second_waypoint = second_ship.get_waypoint("rumor_[REF(second)]")
	TEST_ASSERT_EQUAL(second_waypoint?.tracked_target?.resolve(), second, "Second crew was sent to the old encounter")

	// Give the actual first signal a real empty interior allocation and docks.
	// No .dmm is loaded, but release_interior and slot/dock deletion run unchanged.
	var/list/interior = SSovermap.spawn_dynamic_encounter(null, FALSE)
	TEST_ASSERT(length(interior) >= 4, "Could not allocate the chart cleanup fixture")
	first.mapzone = interior[1]
	first.reserve_dock = interior[2]
	first.reserve_dock_secondary = interior[3]
	first.footprint = interior[4]
	first.loaded = TRUE
	first.visited = TRUE
	var/datum/map_zone/zone = first.mapzone
	var/datum/map_footprint/footprint = first.footprint
	var/obj/docking_port/stationary/primary_dock = first.reserve_dock
	var/obj/docking_port/stationary/secondary_dock = first.reserve_dock_secondary
	var/slots_before = zone.used_slot_count()
	first.first_dock_taken = TRUE
	TEST_ASSERT(!first.can_release_interior(), "Cleanup ignored an occupied berth")
	first.first_dock_taken = FALSE
	first.mission_locked = TRUE
	first.check_and_respawn()
	TEST_ASSERT(!QDELETED(first) && first.loaded, "Chart cleanup bypassed a live mission lock")
	first.mission_locked = FALSE
	TEST_ASSERT_EQUAL(first.mission_claims, 0, "A background contract claimed the cleanup fixture")
	first.check_and_respawn()
	TEST_ASSERT(QDELETED(first), "An abandoned chart ruin retained its old signal")
	TEST_ASSERT(QDELETED(footprint), "Chart cleanup did not release its map footprint")
	TEST_ASSERT_EQUAL(zone.used_slot_count(), slots_before - 1, "Chart cleanup kept its map slot allocated")
	TEST_ASSERT(QDELETED(primary_dock) && QDELETED(secondary_dock), "Chart cleanup left its docking ports behind")
	TEST_ASSERT(!QDELETED(second), "Cleaning the first encounter deleted another buyer's fresh ruin")
	TEST_ASSERT_EQUAL(length(GLOB.space_ruin_signals), signals_before + 1, "Chart cleanup automatically spawned an unpaid replacement")

	// A failed placement keeps the paid chart sealed; a retry creates another fresh site.
	var/datum/rumor_chart/retry_chart = allocate(/datum/rumor_chart)
	retry_chart.ruin_template_path = chart_type
	retry_chart.spawn_zone = 99 // No real zone can match this value.
	TEST_ASSERT_NULL(first_ship.reveal_pending_rumor(retry_chart), "A foreign chart was accepted as this ship's pending purchase")
	first_ship.add_pending_rumor(retry_chart)
	TEST_ASSERT_NULL(first_ship.reveal_pending_rumor(retry_chart), "Impossible placement unexpectedly succeeded")
	TEST_ASSERT(!retry_chart.revealed && (retry_chart in first_ship.pending_rumors), "Failed reveal consumed its paid chart")
	retry_chart.spawn_zone = 1
	var/obj/structure/overmap/space_ruin/retried = first_ship.reveal_pending_rumor(retry_chart)
	TEST_ASSERT_NOTNULL(retried, "A valid retry could not generate a fresh encounter after cleanup")
	spawned_sites += retried
	TEST_ASSERT(retried != second && !retried.visited && !retried.loaded, "Retry reused another crew's ruin state")
	TEST_ASSERT(QDELETED(retry_chart) && !(retry_chart in first_ship.pending_rumors), "Successful reveal did not consume the sealed chart")
