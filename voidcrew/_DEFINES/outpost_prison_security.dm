// ===== OUTPOST PRISON: BUILT TURRETS AND AMBIENCE (see outpost_prison_security.dm, outpost_prison_ambience.dm) =====
// Turrets players build follow the prison's rules on its mobs: prisoners only while they make real
// trouble, and only ever with a stun shot; never a guard or Kessler's people. Ambience values are
// from extras-plan.md 4.5 and 4.7.

/// What outpost_prison_turret_verdict() says about a mob: not the prison's, spare it, or shoot it
#define OUTPOST_PRISON_TURRET_NOT_MINE 0
#define OUTPOST_PRISON_TURRET_SPARE 1
#define OUTPOST_PRISON_TURRET_SHOOT 2
/// A turret holds fire this long after warning a prisoner, and warns the same prisoner again only after this
#define OUTPOST_PRISON_TURRET_WARN_TIME (2 SECONDS)
#define OUTPOST_PRISON_TURRET_REWARN_TIME (30 SECONDS)
/// What a warned prisoner does: give up (rioters only), back off, or carry on and take the stun
#define OUTPOST_PRISON_TURRET_GIVE_UP "give_up"
#define OUTPOST_PRISON_TURRET_BACK_OFF "back_off"
#define OUTPOST_PRISON_TURRET_DEFY "defy"
/// Swinging or fighting: percent chance to back off at mood 0 and at mood 100, straight between
#define OUTPOST_PRISON_TURRET_BACKOFF_AT_0 20
#define OUTPOST_PRISON_TURRET_BACKOFF_AT_100 85
/// No chance of backing off, or of climbing down, is ever below or above these
#define OUTPOST_PRISON_TURRET_CHANCE_MIN 5
#define OUTPOST_PRISON_TURRET_CHANCE_MAX 95
/// Climbing a hatch: percent chance to climb back down
#define OUTPOST_PRISON_TURRET_CLIMB_DOWN_CHANCE 70
/// Rioting: weights to give up, back off and defy at mood OUTPOST_PRISON_TURRET_RIOT_MID_MOOD
#define OUTPOST_PRISON_TURRET_RIOT_GIVE_UP 35
#define OUTPOST_PRISON_TURRET_RIOT_BACK_OFF 35
#define OUTPOST_PRISON_TURRET_RIOT_DEFY 30
#define OUTPOST_PRISON_TURRET_RIOT_MID_MOOD 40
/// Each point of mood above the middle adds this much to giving up and takes this much from defying (below it, the other way)
#define OUTPOST_PRISON_TURRET_RIOT_GIVE_UP_PER_MOOD 0.5
#define OUTPOST_PRISON_TURRET_RIOT_DEFY_PER_MOOD 0.4
/// No rioter's outcome weighs less than this, so every one stays possible at every mood
#define OUTPOST_PRISON_TURRET_RIOT_MIN_WEIGHT 5
/// Nervous and cheerful rioters give up this much more; grumpy ones defy this much more
#define OUTPOST_PRISON_TURRET_RIOT_PERSONALITY_MULT 1.5
/// Backing off: how long they have to walk away before the turret may shoot them again
#define OUTPOST_PRISON_TURRET_RETREAT_TIME (8 SECONDS)
/// How far a swinger or fighter steps back
#define OUTPOST_PRISON_TURRET_STEP_BACK 2
/// A rioter who backs off stays clear of what the turret sees this long; one who defies it goes for it this long
#define OUTPOST_PRISON_TURRET_AVOID_TIME (60 SECONDS)
#define OUTPOST_PRISON_TURRET_DEFY_TIME (30 SECONDS)
/// A rioter who gives up has this long to walk back to their cell before they stop where they are
#define OUTPOST_PRISON_TURRET_SURRENDER_WALK_TIME (20 SECONDS)
/// Percent chance someone watching comments on a hit, and the least time between those comments
#define OUTPOST_PRISON_TURRET_HIT_LINE_CHANCE 15
#define OUTPOST_PRISON_TURRET_HIT_LINE_GAP (20 SECONDS)
/// Least time between rioters shouting to go for a turret
#define OUTPOST_PRISON_TURRET_SMASH_LINE_GAP (10 SECONDS)

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
