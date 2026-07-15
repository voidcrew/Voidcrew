// Trade economy defines (vouchers, trader outposts)

/// How long an outpost trade embargo against a ship lasts after aggression
#define OUTPOST_EMBARGO_DURATION (15 MINUTES)

/// How many violent infractions at an outpost it takes before turrets open fire.
/// Earlier offenses only issue a warning; the final strike marks the aggressor.
#define OUTPOST_AGGRESSION_STRIKES 3

/// Placement attempts when scattering trader outposts across the zone bands
#define MAX_OUTPOST_PLACEMENT_ATTEMPTS 300

/// Max simultaneous hangar berths per trader outpost (purely a gameplay/perf cap)
#define OUTPOST_MAX_BERTHS 6

/// Fake travel time of the hangar elevator between floors
#define OUTPOST_ELEVATOR_TRAVEL_TIME (3 SECONDS)

/// How long a freshly allocated berth waits for its ship to actually land
/// before self-freeing (dock warmup is 10s, plus shuttle transit and margin)
#define OUTPOST_BERTH_ARRIVAL_GRACE (45 SECONDS)

// Blueprint tiers — drive the neural imprinter's fee and the schematic's tint
#define BLUEPRINT_TIER_GREEN 1
#define BLUEPRINT_TIER_YELLOW 2
#define BLUEPRINT_TIER_RED 3

// Shop shelf kinds — how a SKU entered the shop's live list (drives UI styling,
// per-round supply caps and, later, restock behavior)
/// Always stocked, every round
#define SHELF_CORE "core"
/// Rolled from the shop's rotating pool this round; limited supply
#define SHELF_ROTATING "rotating"
/// Rolled from the shop's rare pool; single showcase unit
#define SHELF_RARE "rare"

/// How often a trader outpost's supply convoy tops the shelves back up
#define OUTPOST_RESTOCK_INTERVAL (22 MINUTES)

// Trader hologram speech line categories
#define TRADER_LINE_GREETING "greeting"
#define TRADER_LINE_SALE "sale"
#define TRADER_LINE_REFUSAL "refusal"
#define TRADER_LINE_AGGRESSION "aggression"
#define TRADER_LINE_WARNING "warning"
#define TRADER_LINE_IDLE "idle"
#define TRADER_LINE_RESTOCK "restock"
