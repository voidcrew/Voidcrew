// The Verdigris: galaxy-announced, opt-in lich raid event.
// See voidcrew/modules/lich/lich_site.dm for the site + status beacon.

// ===== SPAWN SCHEDULE =====

/// Earliest the lair may surface. Deliberately late-round, later even than the
/// Grand Colosseum's 40 minute gate (COLOSSEUM_EARLIEST_SPAWN), because this is
/// a strictly heavier ask than the colosseum: a four-layer assault on a
/// megafauna-tier boss. Crews need to be armed, fed, flying and ideally willing
/// to cooperate across ships before it lands.
#define LICH_FIRST_SPAWN_TIME (120 MINUTES)
/// Percent chance, rolled ONCE per round at overmap init, that the lich happens at
/// all. He is a round-defining set piece, a standing raid offer the whole galaxy
/// is invited to answer, and a set piece that shows up every single round stops
/// being one. At 30% a crew sees him occasionally rather than as a scheduled
/// fixture, and the rounds he skips are quieter on purpose.
///
/// The roll is a one-shot: lose it and the scheduler is never armed, so no amount of
/// waiting or repopulating brings him back. It does NOT gate the admin verb
/// (surface_lich_lair()), which force-surfaces him regardless.
#define LICH_SPAWN_CHANCE 30
/// Retry delay when the scheduler can't yet surface the lair (no free overmap
/// square, or not enough players aboard, see LICH_MIN_PLAYERS).
#define LICH_SPAWN_RETRY (5 MINUTES)
/// Living, non-AFK players required before the lair will surface. Mirrors the
/// Grand Colosseum's min_players (colosseum_event.dm), and matters more here:
/// late-round frequently means LOW POPULATION, and a skeleton crew cannot clear
/// four defense layers, so the site would just sit there unanswerable for the
/// rest of the round. The scheduler retries on LICH_SPAWN_RETRY rather than
/// giving up, so a round that fills back up still gets its lich.
#define LICH_MIN_PLAYERS 4
/// One lich per round, ever. GLOB.lich_lair enforces it; this documents it.
#define LICH_MAX_PER_ROUND 1

// ===== STATUS BEACON =====

/// Cadence of the galaxy-wide status beat. The site has no mechanical effect on
/// anyone who stays away; the beacon exists so crews that formed after he
/// surfaced (or cleared their helm marker) still know he is out there. Each beat
/// re-broadcasts one plain status line and re-pushes the fleet waypoint, and the
/// first beat lands one interval after the surface announcement.
#define LICH_BEACON_INTERVAL (15 MINUTES)

// ===== DEFENSE LAYERS =====
// Ward poddoor ids, mapped on /obj/machinery/door/poddoor in lich_lair.dmm and
// collected at interior link like the colosseum's arena gates.

#define LICH_WARD_ATRIUM "lich_ward_atrium"
#define LICH_WARD_OSSUARY "lich_ward_ossuary"
#define LICH_WARD_WARRENS "lich_ward_warrens"
#define LICH_WARD_SANCTUM "lich_ward_sanctum"

/// How often a sealed ward sweeps its layer for surviving garrison. Cheap
/// (a GLOB.mob_living_list pass), but there is no reason to do it every tick.
#define LICH_WARD_SCAN_INTERVAL (3 SECONDS)
/// Grace period before a freshly loaded ward takes its first reading. SSatoms
/// gives no ordering guarantee between a ward and the mobs in its hall, and a
/// ward that scans an empty-looking layer unseals it permanently.
#define LICH_WARD_STARTUP_GRACE (10 SECONDS)

// ===== FLAVOR =====

/// Faction shared by Ilthuun and everything he raises, so the garrison never
/// infights and the wards can tell his dead from a crew's pet.
#define FACTION_LICH "verdigris"

/// The one green. Used by the overmap token, the ward runes and the site's
/// announcement color so the whole event reads as a single hand.
#define LICH_GREEN "#3fdd6a"

/// How Ilthuun signs every galaxy-wide broadcast.
#define LICH_ANNOUNCER "Ilthuun, the Verdigris Lich"
