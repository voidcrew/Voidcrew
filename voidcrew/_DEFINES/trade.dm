// Trade economy defines (vouchers, trader outposts)

/// How long an outpost trade embargo against a ship lasts after aggression
#define OUTPOST_EMBARGO_DURATION (15 MINUTES)

/// How many infractions against outpost property it takes before turrets open
/// fire. Earlier hits only issue a warning; the final strike marks the aggressor.
#define OUTPOST_AGGRESSION_STRIKES 3

/// Placement attempts when scattering trader outposts across the zone bands
#define MAX_OUTPOST_PLACEMENT_ATTEMPTS 300

// Trader hologram speech line categories
#define TRADER_LINE_GREETING "greeting"
#define TRADER_LINE_SALE "sale"
#define TRADER_LINE_REFUSAL "refusal"
#define TRADER_LINE_AGGRESSION "aggression"
#define TRADER_LINE_WARNING "warning"
#define TRADER_LINE_IDLE "idle"
