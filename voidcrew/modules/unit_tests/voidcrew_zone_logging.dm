/// Boarding in red must remain distinguishable from beginning combat in green.
/datum/unit_test/voidcrew_zone_logging
	var/list/original_areas = list()
	var/list/ship_areas = list()
	var/list/ships = list()
	var/list/overmap_turfs = list()
	var/zones_were_active

/datum/unit_test/voidcrew_zone_logging/Destroy()
	SSovermap_zones.zones_active = zones_were_active
	for(var/obj/structure/overmap/ship/ship as anything in ships)
		var/obj/docking_port/mobile/voidcrew/port = ship.shuttle
		ship.shuttle = null
		port.current_ship = null
		qdel(port, force = TRUE)
	for(var/turf/changed_turf as anything in original_areas)
		changed_turf.change_area(get_area(changed_turf), original_areas[changed_turf])
	QDEL_LIST(ship_areas)
	for(var/turf/open/overmap/changed_turf as anything in overmap_turfs)
		changed_turf.current_zone = null
		changed_turf.ChangeTurf(overmap_turfs[changed_turf])
	return ..()

/datum/unit_test/voidcrew_zone_logging/proc/make_ship(turf/ship_turf, turf/token_turf)
	var/area/shuttle/voidcrew/ship_area = new
	ship_areas += ship_area
	original_areas[ship_turf] = get_area(ship_turf)
	ship_turf.change_area(get_area(ship_turf), ship_area)
	var/obj/docking_port/mobile/voidcrew/port = new(ship_turf)
	port.shuttle_areas[ship_area] = TRUE
	port.register()
	ship_area.shuttle_port = port
	var/obj/structure/overmap/ship/ship = allocate(/obj/structure/overmap/ship, token_turf)
	ship.shuttle = port
	port.current_ship = ship
	ships += ship
	return ship

/datum/unit_test/voidcrew_zone_logging/proc/make_zone_turf(turf/location, zone_type)
	var/old_type = location.type
	var/turf/open/overmap/zone_turf = location.ChangeTurf(/turf/open/overmap)
	overmap_turfs[zone_turf] = old_type
	zone_turf.current_zone = allocate(/datum/overmap_zone, zone_type)
	return zone_turf

/datum/unit_test/voidcrew_zone_logging/proc/attack_history(mob/subject)
	var/list/entries = subject.logging["[LOG_ATTACK]"]
	var/list/messages = list()
	for(var/entry in entries)
		messages += entries[entry]
	return jointext(messages, "\n")

/datum/unit_test/voidcrew_zone_logging/Run()
	zones_were_active = SSovermap_zones.zones_active
	SSovermap_zones.zones_active = TRUE
	var/turf/hull = run_loc_floor_bottom_left
	var/turf/other_hull = get_step(hull, EAST)
	var/turf/shore = get_step(other_hull, EAST)
	// Voidcrew defines are included after unit tests: GREEN = 1, RED = 3.
	var/turf/red_tile = make_zone_turf(get_step(hull, NORTH), 3)
	var/turf/green_tile = make_zone_turf(get_step(red_tile, NORTH), 1)
	var/obj/structure/overmap/ship/ship = make_ship(hull, red_tile)
	var/obj/structure/overmap/ship/other_ship = make_ship(other_hull, red_tile)
	var/mob/living/basic/hidden = allocate(/mob/living/basic, shore)
	var/mob/living/basic/fighter = allocate(/mob/living/basic, shore)
	var/mob/living/basic/victim = allocate(/mob/living/basic, hull)
	var/datum/component/ship_zone_logging/hidden_tracker = hidden.LoadComponent(/datum/component/ship_zone_logging)
	var/datum/component/ship_zone_logging/fighter_tracker = fighter.LoadComponent(/datum/component/ship_zone_logging)

	// A player carried in a closed container must get the same boarding record.
	var/obj/structure/closet/container = allocate(/obj/structure/closet, shore)
	hidden.forceMove(container)
	container.forceMove(hull)
	fighter.forceMove(hull)
	TEST_ASSERT_EQUAL(hidden_tracker.ship_ref?.resolve(), ship, "A container concealed the player's boarding")
	TEST_ASSERT(findtext(hidden_tracker.boarding_context, "boarded") && findtext(hidden_tracker.boarding_context, "RED"), "Boarding did not retain the red zone")
	var/original_boarding = hidden_tracker.boarding_context
	var/entry_count = length(hidden.logging["[LOG_ATTACK]"])
	hidden.forceMove(hull)
	hidden.forceMove(container)
	TEST_ASSERT_EQUAL(length(hidden.logging["[LOG_ATTACK]"]), entry_count, "Moving inside the same ship produced another boarding event")
	TEST_ASSERT_EQUAL(hidden.LoadComponent(/datum/component/ship_zone_logging), hidden_tracker, "Reconnecting replaced the boarding history")

	// A pending/cancelled crossing is still red, and produces no crossing record.
	ship.zone_transitioning = TRUE
	ship.zone_transition_target = green_tile
	log_combat(fighter, victim, "test-red-attack")
	TEST_ASSERT(findtext(attack_history(fighter), "zone=RED"), "Combat used the pending destination's zone")
	ship.cancel_zone_transition()
	TEST_ASSERT_EQUAL(length(hidden.logging["[LOG_ATTACK]"]), entry_count, "Cancelling a crossing logged it as completed")

	ship.forceMove(green_tile)
	TEST_ASSERT_EQUAL(hidden_tracker.boarding_context, original_boarding, "The zone crossing overwrote where the player boarded")
	TEST_ASSERT(findtext(attack_history(hidden), "remained aboard"), "The hidden player was omitted from the crossing")
	log_combat(hidden, victim, "test-first-green-attack")
	log_combat(fighter, victim, "test-continued-green-attack")
	var/hidden_history = attack_history(hidden)
	var/fighter_history = attack_history(fighter)
	TEST_ASSERT(findtext(hidden_history, "remained aboard") < findtext(hidden_history, "test-first-green-attack"), "The first attack did not follow the crossing in the log")
	TEST_ASSERT(findtext(fighter_history, "test-red-attack") < findtext(fighter_history, "remained aboard"), "The red attack did not precede the crossing")
	TEST_ASSERT(findtext(fighter_history, "remained aboard") < findtext(fighter_history, "test-continued-green-attack"), "Continuing combat did not follow the crossing")
	TEST_ASSERT(findtext(hidden_history, "zone=GREEN"), "The first attack in green did not name its zone")
	TEST_ASSERT(findtext(fighter_tracker.boarding_context, "RED"), "Ongoing combat lost the original boarding zone")

	// Hull identity must change even between ships on the same interior z-level.
	fighter.forceMove(other_hull)
	TEST_ASSERT_EQUAL(fighter_tracker.ship_ref?.resolve(), other_ship, "Crossing to a different hull was missed")
	TEST_ASSERT(findtext(attack_history(fighter), "departed"), "Leaving the first hull was not logged")
	fighter.forceMove(shore)
	TEST_ASSERT_NULL(fighter_tracker.ship_ref, "Leaving the second hull retained its boarding state")
	fighter.forceMove(hull)
	TEST_ASSERT(findtext(fighter_tracker.boarding_context, "GREEN"), "Reboarding reused the previous red visit")

	// Docked ships inherit their carrier's crossings without receiving Moved().
	other_ship.forceMove(ship)
	ship.shuttle.shuttle_areas |= other_ship.shuttle.shuttle_areas
	fighter.forceMove(other_hull)
	TEST_ASSERT_EQUAL(zone_log_ship_for_atom(fighter), other_ship, "A rider's occupant was attributed to its carrier")
	ship.forceMove(red_tile)
	TEST_ASSERT(findtext(attack_history(fighter), "remained aboard [other_ship.zone_log_identity()]"), "Carrier movement omitted the docked ship's passenger")
