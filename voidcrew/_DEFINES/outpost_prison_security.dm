// ===== OUTPOST PRISON: AMBIENCE (see outpost_prison_ambience.dm) =====

// ----- the yard notices you (4.5) -----

/// A member coming into the cell block turns heads at most this often
#define OUTPOST_PRISON_NOTICE_GAP (60 SECONDS)
/// Each prisoner reacts to a newcomer at most this often
#define OUTPOST_PRISONER_NOTICE_COOLDOWN (3 MINUTES)
/// How far a prisoner looks for the newcomer
#define OUTPOST_PRISONER_NOTICE_RANGE 7
/// At or above this mood (or for a "fair" member) they greet or nod; below the stare line (or for a "brute") they stare
#define OUTPOST_PRISONER_NOTICE_GREET_MOOD 75
#define OUTPOST_PRISONER_NOTICE_STARE_MOOD 40
/// Percent chance a content prisoner says hello rather than nodding
#define OUTPOST_PRISONER_NOTICE_GREET_CHANCE 40
/// A stare keeps them quiet this long
#define OUTPOST_PRISONER_NOTICE_STARE_HUSH (20 SECONDS)
/// A running chat pauses this long while they look over
#define OUTPOST_PRISONER_NOTICE_CHAT_PAUSE (5 SECONDS)
/// Per notice: one spoken line and this many nods, waves and stares; the rest only turn their heads
#define OUTPOST_PRISON_NOTICE_MAX_EMOTES 2

// ----- examining a prisoner (4.5) -----

/// Examine says they are due out with less than this many seconds of sentence left
#define OUTPOST_PRISONER_EXAMINE_DUE_OUT 90
/// examine_more() rounds the sentence left to this many minutes; under it, "a few minutes"
#define OUTPOST_PRISONER_EXAMINE_ROUND_MINUTES 5

// ----- sulking and humming (4.5) -----

/// Sulking: leisure weight, only below this mood
#define OUTPOST_PRISONER_SULK_WEIGHT 4
#define OUTPOST_PRISONER_SULK_MOOD 45
/// No other prisoner within this many tiles of the spot
#define OUTPOST_PRISONER_SULK_ALONE_RANGE 2
/// Humming: at or above this mood, about once a minute (chance per second is 1 in this), at most once per cooldown
#define OUTPOST_PRISONER_HUM_MOOD 75
#define OUTPOST_PRISONER_HUM_ONE_IN 60
#define OUTPOST_PRISONER_HUM_COOLDOWN (3 MINUTES)

// ----- a riot you hear coming (4.7) -----

/// Gathered prisoners whisper at most this often each, with this percent chance a second once free
#define OUTPOST_PRISONER_HUDDLE_GAP (20 SECONDS)
#define OUTPOST_PRISONER_HUDDLE_CHANCE 10
/// Seconds between chant beats; the last OUTPOST_PRISON_CHANT_LATE_WINDOW seconds of the riot hold beat every second
#define OUTPOST_PRISON_CHANT_GAP 2
#define OUTPOST_PRISON_CHANT_GAP_LATE 1
#define OUTPOST_PRISON_CHANT_LATE_WINDOW 10
/// Prisoners slamming a table or door on each beat, and every how many beats one of them shouts
#define OUTPOST_PRISON_CHANT_SLAMMERS 2
#define OUTPOST_PRISON_CHANT_LINE_EVERY 3
/// The slam: quiet and short range, so it is heard from the office but not across the outpost
#define OUTPOST_PRISON_CHANT_VOLUME 35
#define OUTPOST_PRISON_CHANT_RANGE -3
/// Rioters roaring when a riot starts, at most
#define OUTPOST_PRISON_ROAR_MAX 4
