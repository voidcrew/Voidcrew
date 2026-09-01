/// Marks a unique zone-loot prize (voidcrew/modules/loot/uniques/). Any
/// duplicator (Helios pattern stamp, future replicators) must refuse to
/// copy an item carrying this trait, so uniques stay unique.
#define TRAIT_NO_REPLICATE "no_replicate"

/**
 * Loot tiers. A theme (voidcrew/modules/loot/themes/) is one pool cut four
 * ways by how good the item is, NOT by which band it drops in. Keys are
 * stringified everywhere they index a weighted list: DM indexes an assoc
 * list by a bare number POSITIONALLY, so list(LOOT_TIER_COMMON = 64) would
 * read back the key instead of the weight.
 */
#define LOOT_TIER_COMMON "1"
#define LOOT_TIER_UNCOMMON "2"
#define LOOT_TIER_PRIME "3"
#define LOOT_TIER_UNIQUE "4"

/**
 * Per-band draw counts and tier odds, the whole balance surface of the zone
 * loot system on one screen (consumed by voidcrew/modules/loot/zone_loot.dm,
 * displayed by the "Loot: Preview Zone Tables" admin verb).
 *
 * Odds are relative weights per draw across the four tiers above; draws are
 * how many items the cache pays. Zone scales AMOUNT and ODDS, never the kinds
 * on offer, the same contract zones have with planet ore, fauna and weather
 * in overmap_zones.dm. Every band can reach every tier.
 *
 * Green is deliberately not a wasteland: 7-in-100 draws reach prime, so a
 * safe-space cache still turns up something worth carrying about one open in
 * five. Red pays nearly twice the items and lands roughly two prime each.
 *
 * The UNIQUE column is small on purpose, and it is small in a way that reads
 * wrong at a glance. Draw counts compound: a 7-weight unique tier in red is
 * not "7% of red caches", it is 28% of them, because a red cache draws 4-5
 * times. There is no global already-dropped registry (deliberate), so total
 * unique flow is the only lever keeping one-of-a-kind items feeling that way.
 * Before raising these three numbers, work out the per-CACHE rate, not the
 * per-draw one.
 */
#define ZONE_LOOT_DRAWS_MIN_GREEN 2
#define ZONE_LOOT_DRAWS_MAX_GREEN 3
#define ZONE_LOOT_DRAWS_MIN_YELLOW 3
#define ZONE_LOOT_DRAWS_MAX_YELLOW 4
#define ZONE_LOOT_DRAWS_MIN_RED 4
#define ZONE_LOOT_DRAWS_MAX_RED 5

#define ZONE_LOOT_ODDS_GREEN list(LOOT_TIER_COMMON = 64, LOOT_TIER_UNCOMMON = 28, LOOT_TIER_PRIME = 7, LOOT_TIER_UNIQUE = 1)
#define ZONE_LOOT_ODDS_YELLOW list(LOOT_TIER_COMMON = 34, LOOT_TIER_UNCOMMON = 44, LOOT_TIER_PRIME = 20, LOOT_TIER_UNIQUE = 2)
#define ZONE_LOOT_ODDS_RED list(LOOT_TIER_COMMON = 14, LOOT_TIER_UNCOMMON = 38, LOOT_TIER_PRIME = 45, LOOT_TIER_UNIQUE = 3)

/**
 * # Abandoned crate (the deca-code crate)
 *
 * The OTHER loot channel, and deliberately not the zone one. Where a zone
 * cache is themed content whose payout scales with how deep in the overmap a
 * mapper put it, the abandoned crate is unclaimed freight: a mixed manifest
 * nobody came back for, worth the same everywhere because freight is freight
 * everywhere. It carries ONE flat profile, no band lookup, no zone resolver.
 *
 * What justifies the payout is the lock, not the location. Loot spawns only
 * when somebody actually cracks the 4-digit deca-code
 * (code/modules/mining/abandoned_crates.dm): ten attempts, multitool
 * bulls-and-cows hints, and an anti-tamper bomb on the tenth miss. boom()
 * dumps an empty crate, so blowing it, cutting it or emagging it pays
 * nothing at all: the puzzle is this crate's gate, the way a guarded ruin
 * and a deep band are a zone cache's.
 *
 * Ceiling is deliberately below the themed caches. This crate turns up in
 * maintenance and in ruins that may have no guards at all, so its top tier is
 * "gear a crew is glad to have" (a loaded RCD, plasteel by the fifty, a combat
 * ship part, a shotgun or a laser, a blueprint at long odds) and never a
 * payday or a one-of-a-kind. Big cash, cyberware and the authored uniques stay
 * behind guarded zone caches, where the loot audit test
 * (code/modules/unit_tests/voidcrew_loot.dm) enforces a guard marker. There is
 * no UNIQUE tier here at all, on purpose.
 *
 * Robustness comes from DRAW COUNT, not from a higher ceiling: 5-7 items of
 * ordinary usefulness reads as a full crate, which is what the crate is.
 */
#define ABANDONED_CRATE_DRAWS_MIN 5
#define ABANDONED_CRATE_DRAWS_MAX 7

#define ABANDONED_CRATE_ODDS list(LOOT_TIER_COMMON = 45, LOOT_TIER_UNCOMMON = 35, LOOT_TIER_PRIME = 20)
