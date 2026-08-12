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
