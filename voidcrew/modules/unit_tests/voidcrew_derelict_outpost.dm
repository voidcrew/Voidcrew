/// Derelict outpost tests. Owner: P1. Voidcrew defines are not visible here: literals, with the define named beside them.

/// T1.1: round-start placement, one per round, presentation while dormant, and the claim gate.
/datum/unit_test/voidcrew_derelict_spawn
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_spawn/Run()
	TEST_ASSERT_NULL(GLOB.derelict_outpost, "A derelict outpost already exists before this test ran")
	// ZONE_YELLOW = 2, ZONE_RED = 3
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = SSovermap.spawn_derelict_outpost("haunted", /datum/map_template/player_outpost/rundown, 3)
	allocated += site
	TEST_ASSERT_NOTNULL(site, "spawn_derelict_outpost() returned null")
	TEST_ASSERT_EQUAL(site.derelict_state, "dormant", "A freshly spawned derelict is not dormant") // DERELICT_STATE_DORMANT
	TEST_ASSERT(!site.loaded, "A freshly spawned derelict is already loaded")
	TEST_ASSERT_EQUAL(SSovermap.get_zone_band_for_turf(get_turf(site)), 3, "The derelict did not spawn in the requested band")
	TEST_ASSERT_EQUAL(site.name, "unknown signal", "A dormant derelict does not look like an unknown signal")
	TEST_ASSERT_EQUAL(site.icon_state, "strange_event", "A dormant derelict does not look like a ruin")
	TEST_ASSERT_EQUAL(site.sensor_category, "Ruins", "A dormant derelict is not sensor-categorized as a ruin")
	TEST_ASSERT_NULL(site.get_contact_variant(), "A dormant derelict has a contact variant")
	TEST_ASSERT_EQUAL(site.survey_value, 0, "A dormant derelict has a nonzero survey value") // F1
	TEST_ASSERT(length(site.true_name), "The derelict has no true name")
	TEST_ASSERT(!site.founder_ckey, "A freshly spawned derelict already has an owner")
	TEST_ASSERT_EQUAL(GLOB.derelict_outpost, site, "GLOB.derelict_outpost does not point at the spawned site")
	TEST_ASSERT_NULL(SSovermap.spawn_derelict_outpost("cult", /datum/map_template/player_outpost/clean, 2), "A second derelict outpost was allowed to spawn")
	var/mob/living/carbon/human/consistent/claimant = make_player(run_loc_floor_bottom_left, "derelictspawntest")
	TEST_ASSERT(!site.transfer_ownership(claimant, claimant), "A dormant derelict allowed a claim") // F16

/// T1.2: the lazy build itself - dock signal, timing out the wait, and the built state.
/datum/unit_test/voidcrew_derelict_lazy_build
	parent_type = /datum/unit_test/voidcrew_derelict
	var/list/finished_results = list()

/datum/unit_test/voidcrew_derelict_lazy_build/proc/on_finished(obj/structure/overmap/site, success)
	SIGNAL_HANDLER
	finished_results += success

/datum/unit_test/voidcrew_derelict_lazy_build/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict)
	site.setup_derelict(/datum/map_template/player_outpost/clean, "cult", 2)
	site.derelict_skip_theme = TRUE
	RegisterSignal(site, "voidcrew_site_load_finished", PROC_REF(on_finished)) // COMSIG_VOIDCREW_SITE_LOAD_FINISHED
	site.start_level_load(null, null)
	var/deadline = world.time + 2 MINUTES
	while(site.is_loading() && world.time < deadline)
		sleep(1)
	UnregisterSignal(site, "voidcrew_site_load_finished") // COMSIG_VOIDCREW_SITE_LOAD_FINISHED
	TEST_ASSERT_EQUAL(length(finished_results), 1, "The derelict did not send exactly one load-finished signal")
	TEST_ASSERT_EQUAL(finished_results[1], TRUE, "The derelict's load-finished signal reported failure")
	TEST_ASSERT_EQUAL(site.derelict_state, "ready", "The derelict is not ready after building") // DERELICT_STATE_READY
	TEST_ASSERT(site.is_loaded(), "is_loaded() is false after building")
	TEST_ASSERT_EQUAL(site.name, site.true_name, "The derelict's name is not its true name after building")
	TEST_ASSERT_EQUAL(site.display_name, site.true_name, "The derelict's display name is not its true name after building")
	TEST_ASSERT_EQUAL(site.treasury.account_holder, "[site.true_name] Treasury", "The derelict's treasury is not named after its true name")
	TEST_ASSERT(site.has_hangar_elevator(), "The derelict has no working hangar elevator")
	var/datum/outpost_upgrade/wing = site.outpost_upgrades["prison"]
	TEST_ASSERT(wing?.installed, "The derelict has no prison wing after building")
	TEST_ASSERT_EQUAL(length(site.derelict_fuel_spots), 2, "The derelict's fuel was not hidden in two places") // DERELICT_FUEL_STACKS
	TEST_ASSERT_EQUAL(site.get_dock_description(), "[site.true_name] (boarding)", "The derelict's dock description is wrong while unclaimed")

/// T1.3: the claim itself - console power gates it, a live hostile does not, and D7 multi-ownership.
/datum/unit_test/voidcrew_derelict_claim
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_claim/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = built_derelict(/datum/map_template/player_outpost/clean, null)
	TEST_ASSERT_NOTNULL(site, "The derelict did not build")
	var/obj/structure/overmap/dynamic/player_outpost/other = allocate(/obj/structure/overmap/dynamic/player_outpost)
	other.founder_ckey = "derelictclaimer"

	var/mob/living/carbon/human/consistent/claimer = make_player(get_turf(site.management_console), "derelictclaimer")

	var/obj/machinery/power/apc/apc = site.outpost_area.apc
	apc.cell.use(apc.cell.charge, force = TRUE)
	apc.late_process(1)
	TEST_ASSERT(!site.management_console.can_interact(claimer), "The management console has power before the habitat's APC is fed")

	apc.cell.give(apc.cell.maxcharge)
	apc.late_process(1)
	TEST_ASSERT(site.management_console.can_interact(claimer), "The management console still has no power after the habitat's APC is fed")

	var/mob/living/basic/skeleton/hostile = allocate(/mob/living/basic/skeleton, site.arrival_turf)
	site.derelict_hostiles += WEAKREF(hostile)
	TEST_ASSERT(!site.shelters_docked_hulls(), "An unclaimed derelict shelters docked hulls") // F3

	var/datum/player_outpost_management_ui/management_test/panel = allocate(/datum/player_outpost_management_ui/management_test, site, claimer, site.management_console)
	act(panel, claimer, "claim", null)

	TEST_ASSERT(site.is_owner(claimer), "The claim did not register the claimer as owner")
	TEST_ASSERT_EQUAL(site.derelict_state, "claimed", "The derelict is not claimed after a successful claim") // DERELICT_STATE_CLAIMED
	TEST_ASSERT_EQUAL(site.icon_state, "station", "A claimed derelict does not look like a station")
	TEST_ASSERT_EQUAL(site.sensor_category, "Outposts", "A claimed derelict is not sensor-categorized as an outpost")
	TEST_ASSERT_EQUAL(site.get_contact_variant(), "colony", "A claimed derelict does not present as a colony")
	TEST_ASSERT(site.shelters_docked_hulls(), "A claimed derelict does not shelter docked hulls")
	TEST_ASSERT_EQUAL(site.get_dock_description(), "[site.name] (hangar berth)", "A claimed derelict's dock description is wrong")
	TEST_ASSERT_EQUAL(other.founder_ckey, "derelictclaimer", "Claiming the derelict stripped ownership of another outpost") // D7

/// T1.4: F13, the derelict answers a name only to a researched or surveying helm, only while dormant.
/datum/unit_test/voidcrew_derelict_contact_name
	parent_type = /datum/unit_test/voidcrew_derelict

/datum/unit_test/voidcrew_derelict_contact_name/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict)
	site.setup_derelict(/datum/map_template/player_outpost/rundown, "xeno", 2)
	TEST_ASSERT_NULL(site.identified_contact_name(null), "A dormant, unsurveyed derelict answers its true name")
	site.surveyed = TRUE
	TEST_ASSERT_EQUAL(site.identified_contact_name(null), site.true_name, "A surveyed dormant derelict does not answer its true name")
	site.derelict_state = "ready" // DERELICT_STATE_READY (pinned, not built)
	TEST_ASSERT_NULL(site.identified_contact_name(null), "A built derelict still answers a name through identified_contact_name")

/// T1.5: F3, an unclaimed derelict does not shelter a docked hull from the crewless clock; a claimed one does.
/datum/unit_test/voidcrew_derelict_hull_clocks
	parent_type = /datum/unit_test/voidcrew_derelict
	var/obj/structure/overmap/ship/ship
	var/obj/docking_port/mobile/voidcrew/port

/datum/unit_test/voidcrew_derelict_hull_clocks/Destroy()
	// Bounds-only fixtures, not allocations of the live map (voidcrew_ship_abandonment_sites pattern).
	if(ship)
		ship.shuttle = null
		ship.docked = null
	if(port)
		port.current_ship = null
		port.shuttle_areas = list()
		qdel(port, force = TRUE)
	return ..()

/datum/unit_test/voidcrew_derelict_hull_clocks/Run()
	var/obj/structure/overmap/dynamic/player_outpost/derelict/site = allocate(/obj/structure/overmap/dynamic/player_outpost/derelict)

	port = allocate(/obj/docking_port/mobile/voidcrew, run_loc_floor_bottom_left)
	port.shuttle_areas = list()
	port.register()
	ship = allocate(/obj/structure/overmap/ship)
	ship.shuttle = port
	ship.state = "idle" // OVERMAP_SHIP_IDLE; fork defines follow unit test includes.
	ship.ship_team = new /datum/team/voidcrew // no members: has_active_crew() must read FALSE
	ship.ship_team.ship = ship

	ship.docked = site // dormant derelict
	ship.crewless_since = world.time - 1 MINUTES
	var/list/previous_ships = SSovermap.simulated_ships
	SSovermap.simulated_ships = list(ship)
	SSovermap.sweep_derelicts()
	SSovermap.simulated_ships = previous_ships
	TEST_ASSERT(ship.crewless_since != 0, "An unclaimed derelict sheltered a docked hull from the crewless clock") // F3

	site.derelict_state = "claimed" // DERELICT_STATE_CLAIMED (pinned)
	ship.crewless_since = world.time - 1 MINUTES
	previous_ships = SSovermap.simulated_ships
	SSovermap.simulated_ships = list(ship)
	SSovermap.sweep_derelicts()
	SSovermap.simulated_ships = previous_ships
	TEST_ASSERT_EQUAL(ship.crewless_since, 0, "A claimed derelict did not shelter its docked hull from the crewless clock")
