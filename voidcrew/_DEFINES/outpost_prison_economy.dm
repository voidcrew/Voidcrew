// ===== OUTPOST LOCKUP: COMINGS AND GOINGS (see outpost_prison_economy.dm) =====
// Sentences, arrivals and releases. Nobody is paid for holding prisoners.
//
// One cell turns over every ~13 minutes: an 11.5 minute average sentence and a 60-120 second
// refill. On top of that, arrivals are 30-180 seconds apart, which an empty wing feels (filling it
// takes a few minutes) but staggered cells rarely do.
//
// How well a prisoner is kept (kept_well()) is their care against the wing's conditions:
// - care = mean(fed, clean uniform, health), 0 to 100 (the prisoner's care());
// - nothing at or below OUTPOST_PRISON_GRADE_FLOOR care, all of it from OUTPOST_PRISON_GRADE_FULL;
// - a filthy, dark, unpowered wing halves it.
// Averaged over a stay it decides how they say goodbye.

/// Prisoners the wing holds at once: one per cell
#define OUTPOST_PRISON_CAPACITY 4
/// The most prisoners a wing holds, however many cells it has
#define OUTPOST_PRISON_MAX_CAPACITY 10
/// Sentence range, in seconds
#define OUTPOST_PRISON_SENTENCE_MIN (8 * 60)
#define OUTPOST_PRISON_SENTENCE_MAX (15 * 60)
/// Seconds from opening intake to the first arrival
#define OUTPOST_PRISON_FIRST_ARRIVAL 5
/// Seconds between arrivals: after a prisoner arrives, the next waits this long however many cells are ready
#define OUTPOST_PRISON_ARRIVAL_GAP_MIN 30
#define OUTPOST_PRISON_ARRIVAL_GAP_MAX 180
/// Seconds before a freed cell takes a new arrival
#define OUTPOST_PRISON_REFILL_MIN 60
#define OUTPOST_PRISON_REFILL_MAX 120
/// Seconds of sentence left when a prisoner heads back to their cell to leave
#define OUTPOST_PRISON_RELEASE_WALK 30
/// Log entries the wing keeps
#define OUTPOST_PRISON_LOG_LENGTH 8

/// Care percent at or below which a prisoner is not kept well at all
#define OUTPOST_PRISON_GRADE_FLOOR 70
/// Care percent from which a prisoner is kept as well as can be
#define OUTPOST_PRISON_GRADE_FULL 95
/// How long the count of lost prisoners (escaped or moved on) looks back
#define OUTPOST_PRISON_LOST_WINDOW (30 MINUTES)
/// Seconds confined to a cell before a prisoner counts as badly kept
#define OUTPOST_PRISON_CONFINED_SOUR_AFTER 120
