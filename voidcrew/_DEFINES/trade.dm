// Trade economy defines (vouchers, trader outposts)

/// How long an outpost trade embargo against a ship lasts after aggression
#define OUTPOST_EMBARGO_DURATION (15 MINUTES)

/// How long a marked aggressor stays a turret target and is refused service.
/// Matches the embargo their crew serves for the same offense, so both lift
/// together. Also how long unspent warning strikes linger before they reset.
#define OUTPOST_AGGRESSION_MARK_DURATION OUTPOST_EMBARGO_DURATION

/// How many violent infractions at an outpost it takes before turrets open fire.
/// Earlier offenses only issue a warning; the final strike marks the aggressor.
#define OUTPOST_AGGRESSION_STRIKES 3

/// Grace window after an infraction during which further hits don't add strikes.
/// A single swing reaches register_aggression through more than one route (the
/// machine's own attacked_by override and the outpost_property relay), all in the
/// same tick. Kept under CLICK_CD_MELEE (0.8 s) so it only folds those duplicates
/// together: every real swing is its own strike.
#define OUTPOST_AGGRESSION_GRACE (0.5 SECONDS)

/// How long a victim may retaliate against their attacker after the latest unprovoked hit.
#define OUTPOST_SELF_DEFENSE_DURATION (2 MINUTES)

/// Placement attempts when scattering trader outposts across the zone bands
#define MAX_OUTPOST_PLACEMENT_ATTEMPTS 300

/// Max simultaneous hangar berths per trader outpost (purely a gameplay/perf cap)
#define OUTPOST_MAX_BERTHS 6

/// Clear deck kept between a standard berth's landing pad and each hangar wall
#define OUTPOST_BERTH_MARGIN 4

/// Shown when ship construction tries to extend a hull in a standard berth
#define OUTPOST_BERTH_CONSTRUCTION_DENIAL "Unavailable in standard hangar parking."

/// Fake travel time of the hangar elevator between floors
#define OUTPOST_ELEVATOR_TRAVEL_TIME (3 SECONDS)

/// How long a freshly allocated berth waits for its ship to actually land
/// before self-freeing (dock warmup is 10s, plus shuttle transit and margin)
#define OUTPOST_BERTH_ARRIVAL_GRACE (45 SECONDS)

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
// Favor and purchase caps live on the round-owned voidcrew_crew_record.
// Hull teams share that record; hull accounts and mission slots stay separate.

// Internal service permissions, never player-facing tier labels.
#define ZONE_PERMISSION_PUBLIC 0
#define ZONE_PERMISSION_YELLOW 1
#define ZONE_PERMISSION_ADVANCED 2
#define ZONE_PERMISSION_ELITE 3

#define ZONE_REPUTATION_GREEN_REQUIRED 3
#define ZONE_REPUTATION_YELLOW_REQUIRED 6
#define ZONE_REPUTATION_RED_REQUIRED 9
#define ZONE_REPUTATION_GREEN_FAMILY_CAP 1
#define ZONE_REPUTATION_DANGER_FAMILY_CAP 5

// Canonical progression families. Guarded prize families deliberately differ.
#define ZONE_FAMILY_NAMED_KILL "named_kill"
#define ZONE_FAMILY_HUNT "hunt"
#define ZONE_FAMILY_CAPTURE "capture"
#define ZONE_FAMILY_POACHERS "poachers"
#define ZONE_FAMILY_PYLONS "pylons"
#define ZONE_FAMILY_EXTRACTION "extraction"
#define ZONE_FAMILY_CRIMINAL_BOUNTY "criminal_bounty"
#define ZONE_FAMILY_LAIR "lair"

// Tier thresholds, in favor points
#define FAVOR_TIER_REGULAR 2
#define FAVOR_TIER_PARTNER 4
#define FAVOR_TIER_TRUSTED 6

// Credit-price discount per tier, in percent. Voucher prices are never
// discounted: favor is earned from contracts that PAY vouchers, so a voucher
// discount would double-dip and break the "scrip can't be farmed" doctrine.
#define FAVOR_DISCOUNT_REGULAR 5
#define FAVOR_DISCOUNT_PARTNER 10
#define FAVOR_DISCOUNT_TRUSTED 15

// Favor paid per completed board contract, by difficulty band
#define FAVOR_GAIN_EASY 1
#define FAVOR_GAIN_MEDIUM 2
#define FAVOR_GAIN_HARD 3

/// How many of each favor-shelf unique one crew may buy per round
#define FAVOR_UNIQUE_CREW_LIMIT 3

/// How often a trader outpost's supply convoy tops the shelves back up
#define OUTPOST_RESTOCK_INTERVAL (22 MINUTES)

// ===== CONTRACT PAY BANDS =====
// Total quote, before archetype multipliers and supply service ceilings.
#define CONTRACT_PAY_EASY_MIN 600
#define CONTRACT_PAY_EASY_MAX 900
#define CONTRACT_PAY_MEDIUM_MIN 1300
#define CONTRACT_PAY_MEDIUM_MAX 1800
#define CONTRACT_PAY_HARD_MIN 2400
#define CONTRACT_PAY_HARD_MAX 3200

/// A contract must beat selling the same goods over the counter by this much,
/// or accepting it is strictly worse than walking to the buyback window.
#define CONTRACT_ASK_PREMIUM 1.15

#define CONTRACT_SERVICE_EASY 200
#define CONTRACT_SERVICE_MEDIUM 350
#define CONTRACT_SERVICE_HARD 500
#define CONTRACT_EXCEPTION_MULT 0.4
#define CONTRACT_EXCEPTION_PREMIUM 1.10
#define CONTRACT_SHELF_SHARE 0.6
#define CONTRACT_COURIER_DISTANCE_PAY 10

/// Shared board vacancies wait for the next scheduled refill.
#define OUTPOST_SHOP_OFFER_COUNT 4
#define OUTPOST_CONTRACT_REFILL_INTERVAL (11 MINUTES)
#define OUTPOST_CONTRACT_EXPIRY (22 MINUTES)

/// Imputed credit worth of one trade voucher, for valuing voucher-priced stock
/// and for paying out a bundle's shortfall in scrip instead of money.
#define VOUCHER_CREDIT_VALUE 1200

/// Credit worth assumed for a back-room exclusive, which no shelf prices
#define CONTRACT_EXCLUSIVE_VALUE 3600

/// Never hand over more than this many separate items for one contract
#define CONTRACT_MAX_REWARD_ITEMS 2

/// Trait source for TRAIT_FOOD_CHEF_MADE on dishes sold over an outpost
/// kitchen's counter (the Chowder Pot's plated shelves). Kept distinct from
/// player mind-ref sources so the diner's ledger and the Kitchen Order
/// contracts can refuse the outpost's own plates: they demand the trait from
/// any source EXCEPT this one (HAS_TRAIT_NOT_FROM).
#define TRAIT_SOURCE_OUTPOST_KITCHEN "outpost_kitchen"

/// Marks a machine or structure claimed as trader outpost property (see
/// /datum/element/outpost_property). Doubles as the element's attach guard:
/// the load-time sweep and a subtype's own Initialize can both add it.
#define TRAIT_OUTPOST_PROPERTY "outpost_property"

/// A creature that was there when a trader outpost loaded (see outpost_residents.dm).
/// Outpost turrets leave it alone.
#define TRAIT_OUTPOST_RESIDENT "outpost_resident"

// Trader hologram speech line categories
#define TRADER_LINE_GREETING "greeting"
#define TRADER_LINE_SALE "sale"
#define TRADER_LINE_REFUSAL "refusal"
#define TRADER_LINE_AGGRESSION "aggression"
#define TRADER_LINE_WARNING "warning"
#define TRADER_LINE_IDLE "idle"
#define TRADER_LINE_RESTOCK "restock"

// Trader outpost weapons checkpoint (voidcrew/modules/trade/outpost_checkpoint.dm, outpost_trespass.dm)
/// How long the scan chamber hums before its verdict
#define OUTPOST_CHECKPOINT_SCAN_TIME (2 SECONDS)
/// How long the inner door stays open after a clean scan
#define OUTPOST_CHECKPOINT_PASS_TIME (5 SECONDS)
/// How long the outer door stays open before it closes and the chamber scans
#define OUTPOST_CHECKPOINT_OUTER_HOLD (4 SECONDS)
/// How long the outer door stays open at least after a refusal, to let the refused group back out
#define OUTPOST_CHECKPOINT_REJECT_HOLD (6 SECONDS)
/// After that, how often a refusing chamber looks again for whatever it refused; the outer door shuts once it is gone
#define OUTPOST_CHECKPOINT_REJECT_RECHECK (2 SECONDS)
/// A door waits this long before trying again to close on a doorway someone is standing in
#define OUTPOST_CHECKPOINT_DOORWAY_WAIT (1 SECONDS)
/// The same line from the checkpoint is not said again within this long
#define OUTPOST_CHECKPOINT_REPEAT_LINE (20 SECONDS)
/// A refused walk into a checkpoint door shows at most once this often
#define OUTPOST_CHECKPOINT_DENY_COOLDOWN (2 SECONDS)
/// An ambient NPC off the lift gives up going through the checkpoint after this long
#define OUTPOST_CHECKPOINT_NPC_PATIENCE (90 SECONDS)
/// An ambient NPC waiting at a checkpoint asks a door at most once this often
#define OUTPOST_CHECKPOINT_NPC_ASK_GAP (4 SECONDS)
/// On an NPC going through a checkpoint (outpost_checkpoint_npcs.dm): pathing lets them through its open doors
#define TRAIT_CHECKPOINT_CROSSING "checkpoint_crossing"
/// How long prying (or hacking) the inner door open takes
#define OUTPOST_CHECKPOINT_FORCE_TIME (20 SECONDS)
/// How long a forced inner door stays open before it shuts again
#define OUTPOST_CHECKPOINT_FORCED_OPEN_TIME (10 SECONDS)
/// Minimum gap between two lines from the checkpoint about the same thing
#define OUTPOST_CHECKPOINT_LINE_COOLDOWN (4 SECONDS)
/// Turrets treat an armed trespasser as hostile until this long after they were last seen armed inside
#define OUTPOST_TRESPASS_HOSTILE_DURATION (10 MINUTES)
/// An armed trespasser is refused by the traders, the permit desk and the checkpoint until this long after they were last seen armed inside
#define OUTPOST_TRESPASS_BAR_DURATION (30 MINUTES)
/// How often the outpost looks for drawn guns past the checkpoint
#define OUTPOST_ARMED_SWEEP_INTERVAL (2 SECONDS)
/// A gun has to stay in hand this long before it counts as drawn (a gun shoved into someone's hand can be dropped)
#define OUTPOST_ARMED_SIGHTING_GRACE (2 SECONDS)
/// A weapons permit lasts this long
#define OUTPOST_WEAPONS_PERMIT_DURATION (20 MINUTES)
/// A weapons permit costs this many credits
#define OUTPOST_WEAPONS_PERMIT_PRICE 1000
/// After a permit runs out, a gun still in hand is overlooked for this long
#define OUTPOST_WEAPONS_PERMIT_GRACE (30 SECONDS)

// Checkpoint states (/datum/outpost_checkpoint)
#define CHECKPOINT_IDLE "idle"
#define CHECKPOINT_SCANNING "scanning"
#define CHECKPOINT_PASSING "passing"
#define CHECKPOINT_REJECTING "rejecting"
#define CHECKPOINT_FORCED "forced"

// Checkpoint guard speech line categories (read from the guard shop's trader_lines)
#define CHECKPOINT_LINE_PASS "checkpoint_pass"
#define CHECKPOINT_LINE_ARMED "checkpoint_armed"
#define CHECKPOINT_LINE_BARRED "checkpoint_barred"
#define CHECKPOINT_LINE_FORCING "checkpoint_forcing"
#define CHECKPOINT_LINE_INTRUDER "checkpoint_intruder"
#define CHECKPOINT_LINE_PERMIT_LAPSED "checkpoint_permit_lapsed"

/// Original shop deliveries cannot be sold to cargo or a trader's wanted ledger.
#define TRAIT_TRADER_GOODS "trader_goods"
/// Limbgrower organs share their type with natural donor organs.
#define TRAIT_PRINTED_ORGAN "printed_organ"

// Settled materials-market asks, in credits per sheet.
#define MATERIAL_BUY_FLOOR_DIAMOND 230
#define MATERIAL_BUY_FLOOR_BLUESPACE 160
#define MATERIAL_BUY_FLOOR_GOLD 80
#define MATERIAL_BUY_FLOOR_TITANIUM 80
#define MATERIAL_BUY_FLOOR_URANIUM 60
#define MATERIAL_BUY_FLOOR_SILVER 30
#define MATERIAL_BUY_FLOOR_PLASMA 15
#define MATERIAL_BUY_FLOOR_IRON 5
#define MATERIAL_BUY_FLOOR_GLASS 5
