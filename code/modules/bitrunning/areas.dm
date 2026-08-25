/// Station side

/area/station/cargo/bitrunning
	name = "Bitrunning"

/area/station/cargo/bitrunning/den
	name = "Bitrunning Den"
	desc = "Office of bitrunners, houses their equipment."
	icon_state = "bit_den"

/// VDOM

/**
 * Every area below sets allow_shuttle_docking explicitly, even where FALSE is already
 * the /area default. Three of these subtype off space/lavaland/icemoon, all of which
 * whitelist docking, so they inherited TRUE - a crew could frame up a shuttle inside a
 * domain and fly their loot home. The redundant lines on the rest are the reminder that
 * a domain area is a containment boundary, not just a paint colour.
 */
/area/virtual_domain
	name = "Virtual Domain Ruins"
	icon_state = "bit_ruin"
	icon = 'icons/area/areas_station.dmi'
	area_flags = LOCAL_TELEPORT | EVENT_PROTECTED | HIDDEN_AREA | UNLIMITED_FISHING
	area_flags_mapping = VIRTUAL_AREA
	default_gravity = STANDARD_GRAVITY
	requires_power = FALSE
	allow_shuttle_docking = FALSE

/area/virtual_domain/fullbright
	static_lighting = FALSE
	base_lighting_alpha = 255

/// Safehouse

/area/virtual_domain/safehouse
	name = "Virtual Domain Safehouse"
	area_flags = LOCAL_TELEPORT | EVENT_PROTECTED | UNLIMITED_FISHING
	area_flags_mapping = UNIQUE_AREA | VIRTUAL_AREA | VIRTUAL_SAFE_AREA
	icon_state = "bit_safe"
	requires_power = FALSE
	sound_environment = SOUND_ENVIRONMENT_ROOM
	allow_shuttle_docking = FALSE

/// Custom subtypes

/area/lavaland/surface/outdoors/virtual_domain
	name = "Virtual Domain Lava Ruins"
	icon_state = "bit_ruin"
	area_flags = /area/virtual_domain::area_flags
	area_flags_mapping = /area/virtual_domain::area_flags_mapping

/area/icemoon/underground/explored/virtual_domain
	name = "Virtual Domain Ice Ruins"
	icon_state = "bit_ice"
	area_flags = /area/virtual_domain::area_flags
	area_flags_mapping = /area/virtual_domain::area_flags_mapping

/area/ruin/space/virtual_domain
	name = "Virtual Domain Unexplored Location"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "bit_ruin"
	area_flags = /area/virtual_domain::area_flags
	area_flags_mapping = /area/virtual_domain::area_flags_mapping

/area/space/virtual_domain
	name = "Virtual Domain Space"
	icon = 'icons/area/areas_station.dmi'
	icon_state = "bit_space"
	area_flags = /area/virtual_domain::area_flags
	area_flags_mapping = /area/virtual_domain::area_flags_mapping

///Areas that virtual entities should not be in

/area/virtual_domain/protected_space
	name = "Virtual Domain Safe Zone"
	area_flags = /area/virtual_domain/safehouse::area_flags
	area_flags_mapping = /area/virtual_domain/safehouse::area_flags_mapping
	icon_state = "bit_safe"
	allow_shuttle_docking = FALSE

/area/virtual_domain/protected_space/fullbright
	static_lighting = FALSE
	base_lighting_alpha = 255

/// A hash lookup list of all the virtual area types
GLOBAL_LIST_INIT_TYPED(virtual_areas, /area, populate_virtual_areas())

/// Constructs the list of virtual areas
/proc/populate_virtual_areas()
	RETURN_TYPE(/list/area)
	var/list/area/virtual_areas = list()
	for(var/area/area_type as anything in subtypesof(/area))
		if (area_type::area_flags_mapping & VIRTUAL_AREA)
			virtual_areas[area_type] = TRUE
	return virtual_areas
