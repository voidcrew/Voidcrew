// Ship damage signals

/// Sent when ship integrity changes: (new_integrity, max_integrity, display_percent)
#define COMSIG_SHIP_INTEGRITY_CHANGED "ship_integrity_changed"

/// Sent when ship reaches a damage threshold: (threshold_name, display_percent)
#define COMSIG_SHIP_DAMAGE_THRESHOLD "ship_damage_threshold"
	#define SHIP_THRESHOLD_MINOR "minor"         // 80% displayed
	#define SHIP_THRESHOLD_MODERATE "moderate"   // 60% displayed
	#define SHIP_THRESHOLD_SERIOUS "serious"     // 40% displayed
	#define SHIP_THRESHOLD_CRITICAL "critical"   // 20% displayed
	#define SHIP_THRESHOLD_EMERGENCY "emergency" // 10% displayed

/// Sent when ship is about to be destroyed: ()
#define COMSIG_SHIP_DESTROYING "ship_destroying"

/// Sent when ship has been destroyed and is crash landing: ()
#define COMSIG_SHIP_DESTROYED "ship_destroyed"
