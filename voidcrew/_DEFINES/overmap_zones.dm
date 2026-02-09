// Overmap Zone System Defines and Signals

// ========== ZONE TYPES ==========

/// Safe zone - no PvP allowed, ship weapons disabled
#define ZONE_GREEN 1
/// Caution zone - weapons disabled, but interdiction/boarding allowed
#define ZONE_YELLOW 2
/// Dangerous zone - full PvP, kill on sight
#define ZONE_RED 3

// Zone type names for display
#define ZONE_NAME_GREEN "Neutral Zone"
#define ZONE_NAME_YELLOW "Contested Zone"
#define ZONE_NAME_RED "Lawless Zone"

// Zone type descriptions
#define ZONE_DESC_GREEN "Safe space - ship weapons are disabled and PvP is prohibited."
#define ZONE_DESC_YELLOW "Caution - ship weapons are disabled, but interdiction and boarding are permitted."
#define ZONE_DESC_RED "Dangerous space - all combat is permitted. Enter at your own risk."

// Zone colors for UI/display
#define ZONE_COLOR_GREEN "#00ff00"
#define ZONE_COLOR_YELLOW "#ffff00"
#define ZONE_COLOR_RED "#ff0000"

// ========== ZONE CONFIGURATION ==========

/// How often zones rotate (in deciseconds) - default 30 minutes
#define ZONE_ROTATION_INTERVAL (2 MINUTES) // TODO: Change back to 30 MINUTES for production

/// How long before a zone shift to warn players (in deciseconds) - default 5 minutes
#define ZONE_SHIFT_WARNING_TIME (30 SECONDS) // TODO: Change back to 5 MINUTES for production

/// Additional warning at 1 minute
#define ZONE_SHIFT_FINAL_WARNING_TIME (10 SECONDS) // TODO: Change back to 1 MINUTES for production

/// Time required to cross between zones (in deciseconds) - 10 seconds
#define ZONE_TRANSITION_TIME (10 SECONDS)

/// Zone distribution ratios (distance from center, as percentage of max radius)
/// Inner ring: 0% to 33% = closest to sun (most dangerous due to sun + lawless zone)
/// Middle ring: 33% to 66%
/// Outer ring: 66% to 100%
#define ZONE_INNER_RING_RATIO 0.33
#define ZONE_MIDDLE_RING_RATIO 0.66
// Outer is implicitly 1.0

// ========== ZONE SIGNALS ==========

/// Sent when an overmap turf's zone changes: (old_zone_type, new_zone_type)
#define COMSIG_TURF_ZONE_CHANGED "turf_zone_changed"

/// Sent globally when any zone shift occurs: (list/affected_turfs)
#define COMSIG_GLOB_ZONE_SHIFT "!zone_shift"

/// Sent globally before a zone shift: (seconds_remaining)
#define COMSIG_GLOB_ZONE_SHIFT_WARNING "!zone_shift_warning"

/// Sent when a ship enters a new zone type: (old_zone_type, new_zone_type)
#define COMSIG_SHIP_ZONE_CHANGED "ship_zone_changed"

/// Sent when zone rotation completes
#define COMSIG_GLOB_ZONE_ROTATION_COMPLETE "!zone_rotation_complete"

// ========== ZONE WEAPON RESTRICTIONS ==========

/// Check if weapons are allowed in a zone type
#define ZONE_WEAPONS_ALLOWED(zone_type) (zone_type == ZONE_RED)

/// Check if interdiction is allowed in a zone type
#define ZONE_INTERDICTION_ALLOWED(zone_type) (zone_type != ZONE_GREEN)

/// Check if forced docking is allowed in a zone type
#define ZONE_FORCED_DOCKING_ALLOWED(zone_type) (zone_type != ZONE_GREEN)

