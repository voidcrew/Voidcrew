// Contested cache: galaxy-wide announced PvP loot event.
// See voidcrew/modules/contested_cache/contested_cache.dm

/// Earliest the first contested cache may surface into the round.
#define CONTESTED_CACHE_FIRST_SPAWN_TIME (30 MINUTES)
/// Delay between caches: nominal arrivals at 30, 180 and 330 minutes in a long round.
#define CONTESTED_CACHE_SPAWN_INTERVAL (150 MINUTES)
/// Maximum contested caches per round.
#define CONTESTED_CACHE_MAX_PER_ROUND 3
/// The PvP window: time between the galaxy-wide announcement and the vault unsealing.
#define CONTESTED_CACHE_UNLOCK_DELAY (10 MINUTES)
/// On-site channel time to crack the unsealed vault open. Interrupted by moving away or taking damage.
#define CONTESTED_CACHE_OPEN_TIME (30 SECONDS)
/// Generous carry-out window after the vault is cracked before the site starts cleaning up.
#define CONTESTED_CACHE_LINGER_TIME (20 MINUTES)
/// Hard timeout: if nobody ever cracks the vault, clean up this long after it unsealed.
#define CONTESTED_CACHE_HARD_TIMEOUT (30 MINUTES)
/// Retry delay when cleanup finds ships still docked or players still on site.
#define CONTESTED_CACHE_CLEANUP_RETRY (3 MINUTES)

/// Ship parts in the contested cache prize crate. Priced above a heavy pirate bounty (3 parts).
#define SHIP_PART_PRIZE_COUNT 5
