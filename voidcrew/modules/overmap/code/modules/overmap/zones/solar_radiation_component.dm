// Solar Radiation Exposure Component
// Applied to crew members on ships in unshielded zones

/// Alert key for solar radiation
#define ALERT_SOLAR_RADIATION "solar_radiation"

/// Component for applying solar radiation to crew in unshielded zones
/// Unlike radioactive_exposure, this checks ship shielding and zone status
/datum/component/solar_radiation_exposure
	dupe_mode = COMPONENT_DUPE_UNIQUE

	/// Time between radiation applications
	var/irradiation_interval
	/// Number of radiation hits per tick (based on zone + shielding)
	var/radiation_hits
	/// Source description for logging
	var/source
	/// The ship this crew member is on
	var/obj/structure/overmap/ship/source_ship

/datum/component/solar_radiation_exposure/Initialize(
	minimum_exposure_time,
	irradiation_interval,
	radiation_hits,
	source,
	obj/structure/overmap/ship/source_ship
)
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

	src.irradiation_interval = irradiation_interval
	src.radiation_hits = radiation_hits
	src.source = source
	src.source_ship = source_ship

	// Start applying radiation after minimum exposure time
	addtimer(CALLBACK(src, PROC_REF(apply_radiation)), minimum_exposure_time)

	// Register for shielding changes on our ship
	if(source_ship)
		RegisterSignal(source_ship, COMSIG_SHIP_SHIELDING_CHANGED, PROC_REF(on_shielding_changed))
		RegisterSignal(source_ship, COMSIG_SHIP_ZONE_CHANGED, PROC_REF(on_zone_changed))

	// Show alert to player
	var/mob/living/living_parent = parent
	living_parent.throw_alert(ALERT_SOLAR_RADIATION, /atom/movable/screen/alert/solar_radiation)

/datum/component/solar_radiation_exposure/Destroy()
	var/mob/living/living_parent = parent
	if(living_parent)
		living_parent.clear_alert(ALERT_SOLAR_RADIATION)

	if(source_ship)
		UnregisterSignal(source_ship, list(COMSIG_SHIP_SHIELDING_CHANGED, COMSIG_SHIP_ZONE_CHANGED))
		source_ship = null

	return ..()

/// Check if we should still be irradiating
/datum/component/solar_radiation_exposure/proc/should_continue()
	var/mob/living/carbon/carbon_parent = parent
	if(!carbon_parent || QDELETED(carbon_parent))
		return FALSE

	// Check if we're still on the same ship
	var/obj/structure/overmap/ship/current_ship = get_ship_from_atom(carbon_parent)
	if(!current_ship || current_ship != source_ship)
		return FALSE

	// Check if the ship is still exposed to radiation
	if(!source_ship.is_crew_exposed_to_radiation())
		return FALSE

	return TRUE

/// Apply radiation to the parent
/datum/component/solar_radiation_exposure/proc/apply_radiation()
	// Check if we should still be active
	if(!should_continue())
		qdel(src)
		return

	var/mob/living/carbon/carbon_parent = parent

	// Check for rad protection clothing - radsuits still protect
	if(!SSradiation.wearing_rad_protected_clothing(carbon_parent) && SSradiation.can_irradiate_basic(carbon_parent))
		for(var/i in 1 to radiation_hits)
			SSradiation.irradiate(carbon_parent)
		carbon_parent.investigate_log("was irradiated by [source].", INVESTIGATE_RADIATION)

	// Schedule next application
	addtimer(CALLBACK(src, PROC_REF(apply_radiation)), irradiation_interval)

/// Handler for when ship shielding changes
/datum/component/solar_radiation_exposure/proc/on_shielding_changed(datum/source, old_level, new_level)
	SIGNAL_HANDLER

	// Always qdel when shielding changes - subsystem will recreate with correct hit count if needed
	qdel(src)

/// Handler for when ship enters a different zone
/datum/component/solar_radiation_exposure/proc/on_zone_changed(datum/source, old_zone_type, new_zone_type)
	SIGNAL_HANDLER

	// Always qdel when zone changes - subsystem will recreate with correct hit count if needed
	qdel(src)

// ========== ALERT ==========

/atom/movable/screen/alert/solar_radiation
	name = "Solar Radiation"
	desc = "Intense solar radiation is penetrating the ship's hull! Get radiation protection, research better shielding, or leave this zone!"
	icon_state = ALERT_RADIOACTIVE_AREA // Reuse existing radiation area icon

#undef ALERT_SOLAR_RADIATION
