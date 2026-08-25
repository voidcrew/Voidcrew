// Trade economy defines (vouchers, trader outposts)

/// How long an outpost trade embargo against a ship lasts after aggression
#define OUTPOST_EMBARGO_DURATION (15 MINUTES)

/// How many violent infractions at an outpost it takes before turrets open fire.
/// Earlier offenses only issue a warning; the final strike marks the aggressor.
#define OUTPOST_AGGRESSION_STRIKES 3

/// Grace window after an infraction during which further hits don't add strikes.
/// A single swing reaches register_aggression through more than one route (the
/// machine's own attacked_by override and the outpost_property relay), and an
/// autoattack burst would otherwise blow through the whole ladder before the
/// first warning is read.
#define OUTPOST_AGGRESSION_GRACE (2 SECONDS)

/// Placement attempts when scattering trader outposts across the zone bands
#define MAX_OUTPOST_PLACEMENT_ATTEMPTS 300

/// Max simultaneous hangar berths per trader outpost (purely a gameplay/perf cap)
#define OUTPOST_MAX_BERTHS 6

/// Fake travel time of the hangar elevator between floors
#define OUTPOST_ELEVATOR_TRAVEL_TIME (3 SECONDS)

/// How long a freshly allocated berth waits for its ship to actually land
/// before self-freeing (dock warmup is 10s, plus shuttle transit and margin)
#define OUTPOST_BERTH_ARRIVAL_GRACE (45 SECONDS)

// Blueprint tiers: drive the neural imprinter's fee and the schematic's tint
#define BLUEPRINT_TIER_GREEN 1
#define BLUEPRINT_TIER_YELLOW 2
#define BLUEPRINT_TIER_RED 3

// Shop shelf kinds: how a SKU entered the shop's live list (drives UI styling,
// per-round supply caps and, later, restock behavior)
/// Always stocked, every round
#define SHELF_CORE "core"
/// Rolled from the shop's rotating pool this round; limited supply
#define SHELF_ROTATING "rotating"
/// Rolled from the shop's rare pool; single showcase unit
#define SHELF_RARE "rare"
/// The back-room shelf: always listed, locked behind crew standing with the
/// trader. Supply is per-crew (FAVOR_UNIQUE_CREW_LIMIT), never shared stock.
#define SHELF_FAVOR "favor"

// ===== TRADER FAVOR =====
// Standing a crew (ship) earns with a trader by running their board contracts.
// Tracked per ship on ship.trader_favor, keyed by the outpost's MAIN shop type,
// so every stall on an outpost honors the same standing. Favor dies with the
// hull by design (losing the ship costs the crew its reputation too).

// Tier thresholds, in favor points
#define FAVOR_TIER_REGULAR 3
#define FAVOR_TIER_PARTNER 7
#define FAVOR_TIER_TRUSTED 12

// Credit-price discount per tier, in percent. Voucher prices are never
// discounted: favor is earned from contracts that PAY vouchers, so a voucher
// discount would double-dip and break the "scrip can't be farmed" doctrine.
#define FAVOR_DISCOUNT_REGULAR 5
#define FAVOR_DISCOUNT_PARTNER 10
#define FAVOR_DISCOUNT_TRUSTED 15

// Favor paid per completed board contract, by difficulty band
#define FAVOR_GAIN_EASY 1
#define FAVOR_GAIN_MEDIUM 2
#define FAVOR_GAIN_HARD 4

/// How many of each favor-shelf unique one crew may buy per round
#define FAVOR_UNIQUE_CREW_LIMIT 3

/// How often a trader outpost's supply convoy tops the shelves back up
#define OUTPOST_RESTOCK_INTERVAL (22 MINUTES)

// ===== CONTRACT PAY BANDS =====
// Outpost contracts settle in goods, not credits, so the bundle a contract pays
// has to be assembled to hit a credit-equivalent target. These are that target,
// in shop credits, per difficulty band. Anything below the EASY floor reads as
// an insult on the board, a 600cr box of shells for a 2000cr haul of cores was
// the bug these bands exist to prevent.
// Read these against the shelf ladder they buy from: a lethal shell box is
// 1200cr, an armor vest 1800, a laser gun or engine heater 3000, a plasma
// engine board 4800. An easy contract should settle for a real piece of kit, a
// medium one for a gun or a drive component, a hard one for the back room.
#define CONTRACT_PAY_EASY_MIN 1400
#define CONTRACT_PAY_EASY_MAX 2000
#define CONTRACT_PAY_MEDIUM_MIN 2600
#define CONTRACT_PAY_MEDIUM_MAX 3800
#define CONTRACT_PAY_HARD_MIN 5500
#define CONTRACT_PAY_HARD_MAX 8000

/// A contract must beat selling the same goods over the counter by this much,
/// or accepting it is strictly worse than walking to the buyback window.
#define CONTRACT_ASK_PREMIUM 1.6

/// Imputed credit worth of one trade voucher, for valuing voucher-priced stock
/// and for paying out a bundle's shortfall in scrip instead of money.
#define VOUCHER_CREDIT_VALUE 1200

/// Credit worth assumed for a back-room exclusive, which no shelf prices
#define CONTRACT_EXCLUSIVE_VALUE 3600

/// Shortfall below this is just rounding; above it, top the contract up in vouchers
#define CONTRACT_SHORTFALL_TOLERANCE 600

/// Never hand over more than this many separate items for one contract
#define CONTRACT_MAX_REWARD_ITEMS 3

/// Trait source for TRAIT_HANDMADE (upstream's rename of the old
/// TRAIT_FOOD_CHEF_MADE, same "food_made_by_chef" string) on dishes sold over an outpost
/// kitchen's counter (the Chowder Pot's plated shelves). Kept distinct from
/// player mind-ref sources so the diner's ledger and the Kitchen Order
/// contracts can refuse the outpost's own plates: they demand the trait from
/// any source EXCEPT this one (HAS_TRAIT_NOT_FROM).
#define TRAIT_SOURCE_OUTPOST_KITCHEN "outpost_kitchen"

/// Marks a machine or structure claimed as trader outpost property (see
/// /datum/element/outpost_property). Doubles as the element's attach guard:
/// the load-time sweep and a subtype's own Initialize can both add it.
#define TRAIT_OUTPOST_PROPERTY "outpost_property"

// Trader hologram speech line categories
#define TRADER_LINE_GREETING "greeting"
#define TRADER_LINE_SALE "sale"
#define TRADER_LINE_REFUSAL "refusal"
#define TRADER_LINE_AGGRESSION "aggression"
#define TRADER_LINE_WARNING "warning"
#define TRADER_LINE_IDLE "idle"
#define TRADER_LINE_RESTOCK "restock"
