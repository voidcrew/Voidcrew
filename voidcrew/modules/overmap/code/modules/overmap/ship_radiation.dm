// Ship Radiation Shielding System
// Handles techweb linking and radiation shielding upgrades

// ========== TECHWEB LINKING ==========

/// Links this ship to a techweb for radiation shielding auto-upgrades
/// Called when an R&D server is on the ship or multitools are used
/obj/structure/overmap/ship/proc/link_techweb(datum/techweb/new_techweb)
	if(!new_techweb)
		return

	if(linked_techweb == new_techweb)
		return  // Already linked to this techweb

	// Unregister from old techweb
	if(linked_techweb)
		UnregisterSignal(linked_techweb, COMSIG_TECHWEB_ADD_DESIGN)

	linked_techweb = new_techweb

	// Register for design additions (research completion)
	RegisterSignal(linked_techweb, COMSIG_TECHWEB_ADD_DESIGN, PROC_REF(on_techweb_design_added))

	// Check current research and apply existing upgrades
	check_and_apply_shielding_upgrades()

/// Unlinks this ship from its techweb
/obj/structure/overmap/ship/proc/unlink_techweb()
	if(linked_techweb)
		UnregisterSignal(linked_techweb, COMSIG_TECHWEB_ADD_DESIGN)
		linked_techweb = null

/// Signal handler: Called when a new design is researched on our techweb
/obj/structure/overmap/ship/proc/on_techweb_design_added(datum/source, datum/design/design, custom)
	SIGNAL_HANDLER

	if(!design)
		return

	// Check if this is a radiation shielding upgrade
	switch(design.id)
		if("radiation_shielding_standard_upgrade")
			upgrade_radiation_shielding(SHIP_SHIELDING_STANDARD)
		if("radiation_shielding_heavy_upgrade")
			upgrade_radiation_shielding(SHIP_SHIELDING_HEAVY)

/// Checks current techweb research and applies any unlocked shielding upgrades
/obj/structure/overmap/ship/proc/check_and_apply_shielding_upgrades()
	if(!linked_techweb)
		return

	// Check for heavy shielding first (higher tier takes precedence)
	if(linked_techweb.researched_designs["radiation_shielding_heavy_upgrade"])
		upgrade_radiation_shielding(SHIP_SHIELDING_HEAVY)
	else if(linked_techweb.researched_designs["radiation_shielding_standard_upgrade"])
		upgrade_radiation_shielding(SHIP_SHIELDING_STANDARD)

// ========== SHIELDING UPGRADES ==========

/// Upgrades the ship's radiation shielding to the specified level
/obj/structure/overmap/ship/proc/upgrade_radiation_shielding(new_level)
	if(new_level <= radiation_shielding_level)
		return  // Already at this level or higher

	var/old_level = radiation_shielding_level
	radiation_shielding_level = new_level

	// Announce to crew
	var/shielding_name = get_shielding_name(new_level)
	var/protection_desc = get_shielding_protection_desc(new_level)
	ship_announce("[shielding_name] has been installed. Crew are now protected from [protection_desc].", "Radiation Shielding Upgrade")

	SEND_SIGNAL(src, COMSIG_SHIP_SHIELDING_CHANGED, old_level, new_level)

/// Returns human-readable name for shielding level
/obj/structure/overmap/ship/proc/get_shielding_name(level)
	switch(level)
		if(SHIP_SHIELDING_STANDARD)
			return "Standard Radiation Shielding"
		if(SHIP_SHIELDING_HEAVY)
			return "Heavy Radiation Shielding"
	return "No Shielding"

/// Returns description of what the shielding protects against
/obj/structure/overmap/ship/proc/get_shielding_protection_desc(level)
	switch(level)
		if(SHIP_SHIELDING_STANDARD)
			return "moderate solar radiation (Contested Zone)"
		if(SHIP_SHIELDING_HEAVY)
			return "intense solar radiation (Contested and Lawless Zones)"
	return "nothing"

// ========== RADIATION PROTECTION CHECKS ==========

/// Returns TRUE if this ship is fully protected from the given radiation level
/obj/structure/overmap/ship/proc/is_protected_from_radiation(radiation_level)
	return get_radiation_hits(radiation_level) == 0

/// Returns how many radiation hits crew take per tick based on zone and shielding
/// Standard shielding provides partial protection in Lawless zone (2 hits -> 1 hit)
/obj/structure/overmap/ship/proc/get_radiation_hits(radiation_level)
	switch(radiation_level)
		if(ZONE_RADIATION_NONE)
			return 0
		if(ZONE_RADIATION_MODERATE)
			// Contested zone: 1 hit, Standard shielding blocks completely
			if(radiation_shielding_level >= SHIP_SHIELDING_STANDARD)
				return 0
			return 1
		if(ZONE_RADIATION_HEAVY)
			// Lawless zone: 2 hits base
			// Heavy shielding blocks completely
			if(radiation_shielding_level >= SHIP_SHIELDING_HEAVY)
				return 0
			// Standard shielding reduces to 1 hit
			if(radiation_shielding_level >= SHIP_SHIELDING_STANDARD)
				return 1
			return 2
	return 0

/// Returns the current zone's radiation level for this ship
/obj/structure/overmap/ship/proc/get_current_radiation_level()
	if(!SSovermap_zones?.zones_active)
		return ZONE_RADIATION_NONE

	var/turf/our_turf = get_turf(src)
	var/datum/overmap_zone/zone = SSovermap_zones.get_zone(our_turf)
	if(!zone)
		return ZONE_RADIATION_NONE

	return ZONE_RADIATION_LEVEL(zone.zone_type)

/// Returns TRUE if crew on this ship are currently exposed to radiation
/obj/structure/overmap/ship/proc/is_crew_exposed_to_radiation()
	var/radiation_level = get_current_radiation_level()
	return get_radiation_hits(radiation_level) > 0
