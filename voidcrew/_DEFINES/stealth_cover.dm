// ===== Cover: foliage that hides someone keeping still (voidcrew/modules/stealth/stealth_cover.dm) =====

/// Past this many tiles a guard can't make out someone keeping still in cover. Never less than its point-blank range.
#define STEALTH_COVER_RANGE 3
/// Someone who moved (or fired) this recently is moving: cover doesn't hide them. Crawling counts as keeping still.
#define STEALTH_COVER_SETTLE (1 SECONDS)
/// A guard's own beam this bright on the tile (get_lumcount() units) shows it what is in the cover
#define STEALTH_COVER_BEAM_LUM 0.15
/// The shortest time between two rustles from one person
#define STEALTH_COVER_RUSTLE_COOLDOWN (1 SECONDS)
/// tg volume of the rustle players hear (played at the silenced extra range: a player hears it 3 tiles off)
#define STEALTH_COVER_RUSTLE_VOLUME 30
/// The same for someone crawling (2 tiles)
#define STEALTH_COVER_RUSTLE_VOLUME_CRAWL 15

/// Someone pushing through foliage
#define STEALTH_NOISE_RUSTLE "rustle"
/// Reach of a rustle, walking or running (players hear the same sound further, abuse H2)
#define STEALTH_NOISE_RANGE_RUSTLE 2
/// Reach of a rustle crawling, or with the Light Step quirk
#define STEALTH_NOISE_RANGE_RUSTLE_CRAWL 1
