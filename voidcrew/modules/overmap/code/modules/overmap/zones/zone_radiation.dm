// Zone Radiation Processing
// Extends SSovermap_zones to apply solar radiation to crew on unshielded ships

// Extend the zone controller with radiation processing
/datum/controller/subsystem/overmap_zones
	/// How often to check for radiation application
	var/radiation_check_interval = 2 SECONDS
	/// Last time we checked radiation
	var/last_radiation_check = 0

/datum/controller/subsystem/overmap_zones/fire(resumed)
	// Skip if zones aren't active
	if(!zones_active)
		return

	// Radiation checks on interval
	if(world.time >= last_radiation_check + radiation_check_interval)
		last_radiation_check = world.time
		process_zone_radiation()

/// Processes radiation for all ships in Contested and Lawless zones
/datum/controller/subsystem/overmap_zones/proc/process_zone_radiation()
	// Check ships in Contested zone
	for(var/obj/structure/overmap/ship/ship as anything in zone_yellow.get_ships())
		var/hits = ship.get_radiation_hits(ZONE_RADIATION_MODERATE)
		if(hits > 0)
			apply_radiation_to_ship_crew(ship, hits, "solar radiation")

	// Check ships in Lawless zone
	for(var/obj/structure/overmap/ship/ship as anything in zone_red.get_ships())
		var/hits = ship.get_radiation_hits(ZONE_RADIATION_HEAVY)
		if(hits > 0)
			apply_radiation_to_ship_crew(ship, hits, "intense solar radiation")

/// Applies solar radiation exposure component to all crew on a ship
/datum/controller/subsystem/overmap_zones/proc/apply_radiation_to_ship_crew(obj/structure/overmap/ship/ship, radiation_hits, source_name)
	if(!ship?.shuttle)
		return

	// Get all living humans on the ship's shuttle
	var/list/humans = ship.shuttle.get_all_humans()
	for(var/mob/living/carbon/human/crewmate as anything in humans)
		// Skip if they already have the solar radiation exposure component
		if(crewmate.GetComponent(/datum/component/solar_radiation_exposure))
			continue

		// Apply the solar radiation exposure component
		crewmate.AddComponent(/datum/component/solar_radiation_exposure, \
			SOLAR_RADIATION_MINIMUM_EXPOSURE, \
			SOLAR_RADIATION_CHECK_INTERVAL, \
			radiation_hits, \
			source_name, \
			ship \
		)
