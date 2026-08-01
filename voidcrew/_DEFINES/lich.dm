// The Verdigris — galaxy-wide lich raid event.
// See voidcrew/modules/lich/lich_site.dm for the site + ritual engine.

// ===== SPAWN SCHEDULE =====

/// Earliest the lair may surface. Deliberately late-round — later even than the
/// Grand Colosseum's 40 minute gate (COLOSSEUM_EARLIEST_SPAWN) — because this is
/// a strictly heavier ask than the colosseum: a four-layer assault on a
/// megafauna-tier boss, and until someone clears it the ritual ramp is making the
/// whole galaxy worse. Crews need to be armed, fed, flying and ideally willing to
/// cooperate across ships before it lands.
///
/// Note the ramp tail this implies: potency caps at LICH_MAX_POTENCY roughly
/// LICH_FIRST_RITUAL_DELAY + (LICH_MAX_POTENCY * LICH_RITUAL_INTERVAL) after the
/// lair surfaces (~30 min), so the worst of the galaxy-wide pressure starts
/// landing around the two hour mark. Pushing this define later shifts that whole
/// tail with it.
#define LICH_FIRST_SPAWN_TIME (90 MINUTES)
/// Retry delay when the scheduler can't yet surface the lair (no free overmap
/// square, or not enough players aboard — see LICH_MIN_PLAYERS).
#define LICH_SPAWN_RETRY (5 MINUTES)
/// Living, non-AFK players required before the lair will surface. Mirrors the
/// Grand Colosseum's min_players (colosseum_event.dm), and matters more here:
/// late-round frequently means LOW POPULATION, and an unanswerable galaxy threat
/// is worse than no threat. A skeleton crew cannot clear four defense layers, so
/// the ritual ramp would just grind the rest of the round down with no counter.
/// The scheduler retries on LICH_SPAWN_RETRY rather than giving up, so a round
/// that fills back up still gets its lich.
#define LICH_MIN_PLAYERS 4
/// One lich per round, ever. GLOB.lich_lair enforces it; this documents it.
#define LICH_MAX_PER_ROUND 1

// ===== RITUAL CLOCK =====

/// Grace period between the lair surfacing and the first ritual firing, so the
/// galaxy gets the announcement (and a chance to move) before the ramp starts.
#define LICH_FIRST_RITUAL_DELAY (2 MINUTES)
/// Cadence of the ritual clock. Each tick raises potency by one until the cap
/// and fires one eligible event from the roster.
#define LICH_RITUAL_INTERVAL (4 MINUTES)
/// Potency ceiling. Matches upstream's wizard grand-ritual scale
/// (min/max_wizard_trigger_potency, code/modules/events/_event.dm:28-31), which
/// the ritual roster reuses as its ramp gate.
#define LICH_MAX_POTENCY 7

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
