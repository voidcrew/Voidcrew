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

// Ship key signals

/// Sent when a ship key is about to be destroyed: (obj/structure/overmap/ship/npc/linked_ship, reason)
/// Reasons: "destroyed", "claimed", "bounty_turned_in"
#define COMSIG_SHIP_KEY_DESTROYED "ship_key_destroyed"
	#define KEY_DESTROYED_UNKNOWN "destroyed"
	#define KEY_DESTROYED_CLAIMED "claimed"
	#define KEY_DESTROYED_BOUNTY "bounty_turned_in"

/// Sent when a ship key is used to claim a ship: (obj/structure/overmap/ship/npc/ship, mob/claimer)
#define COMSIG_SHIP_KEY_USED "ship_key_used"
