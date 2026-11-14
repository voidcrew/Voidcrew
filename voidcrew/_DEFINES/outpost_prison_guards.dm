// ===== OUTPOST PRISON: NPC GUARDS (see outpost_prison_guards.dm) =====
// Guards are security only: they never feed, clothe, treat, clean or light anything.

/// Guards on a wing's roster: one on the door, one in the yard
#define OUTPOST_GUARD_MAX 2
/// How long a guard, down or dead, can be out of the wing before they are off its roster: carried off
#define OUTPOST_GUARD_BODY_COLLECT_DELAY (60 SECONDS)
/// A guard whose baton went flat is back with a charged one after this
#define OUTPOST_GUARD_SHIFT_SWAP_TIME (1 MINUTES)
/// A guard with this much brute and burn damage or more patches up from the office first-aid kit when nothing is going on
#define OUTPOST_GUARD_TREAT_ABOVE 20
/// A downed or recalled guard comes back after this, while someone is there to see it
#define OUTPOST_GUARD_RETURN_TIME (10 MINUTES)
#define OUTPOST_GUARD_BATON_COOLDOWN (2 SECONDS)
/// Percent chance a guard arriving at an argument ends it with words
#define OUTPOST_GUARD_TALKDOWN_CHANCE 60
/// Below this health a guard in a riot falls back to the office
#define OUTPOST_GUARD_FALLBACK_BELOW 60
/// Mood each prisoner who sees a baton strike loses, once per 60 s each
#define OUTPOST_GUARD_ONLOOKER_MOOD 2
/// A response the guard cannot reach in this long is dropped
#define OUTPOST_GUARD_RESPONSE_TIMEOUT (30 SECONDS)
/// Per member: between reports of the wing's top problem, and between greetings
#define OUTPOST_GUARD_REPORT_GAP (3 MINUTES)
#define OUTPOST_GUARD_GREET_GAP (10 MINUTES)
/// Between rounds of the cell block
#define OUTPOST_GUARD_ROUNDS_GAP_MIN (8 MINUTES)
#define OUTPOST_GUARD_ROUNDS_GAP_MAX (12 MINUTES)

// ----- XA's own additions -----

/// How often, in seconds, the guards look for members to greet and report to, check their leash and nod at prisoners
#define OUTPOST_GUARD_CHECK_SECONDS 5
/// Seconds outside the wing before a guard walks back (or, with nobody on the level to see it, is recalled)
#define OUTPOST_GUARD_LEASH_SECONDS 30
/// Seconds a guard recalled from off the wing's level is away before coming back, free
#define OUTPOST_GUARD_OFF_LEVEL_AWAY 60
/// Seconds a dismissed guard has to walk back to the office before beaming out wherever they are
#define OUTPOST_GUARD_DISMISS_WALK 20
/// How close a member must come for a guard to greet them and report
#define OUTPOST_GUARD_REPORT_RANGE 4
/// A prisoner who struck someone this recently gets the baton rather than a warning
#define OUTPOST_GUARD_STRUCK_RECENT (10 SECONDS)
/// Who sees a strike, and how often seeing one costs a prisoner mood
#define OUTPOST_GUARD_ONLOOKER_RANGE 5
#define OUTPOST_GUARD_ONLOOKER_GAP (60 SECONDS)
/// How far a guard sees a spat from
#define OUTPOST_GUARD_SPAT_VIEW 7
/// How close to a member in the cell block a guard stays during a riot
#define OUTPOST_GUARD_FOLLOW_RANGE 2
/// How long a prisoner is left alone after a guard checked on them or they greeted a guard
#define OUTPOST_GUARD_CHECK_ON_GAP (5 MINUTES)

/// Seconds between a guard's own idle lines (post, coffee, the yard), before the wing's shared gap
#define OUTPOST_GUARD_SPEECH_GAP_MIN 40
#define OUTPOST_GUARD_SPEECH_GAP_MAX 90
/// Percent chance, each check, that a prisoner near an on-duty guard says hello to them
#define OUTPOST_GUARD_NOTICE_CHANCE 25
/// How near a guard a prisoner has to be to say hello
#define OUTPOST_GUARD_NOTICE_RANGE 3

// A guard's phase (text, so tests and the admin panel can read it)
/// Not yet on shift: a guard just made
#define OUTPOST_GUARD_ARRIVING "arriving"
/// On the wing and on duty
#define OUTPOST_GUARD_PRESENT "present"
/// Down in crit, or dead: a body on the floor
#define OUTPOST_GUARD_DOWN "down"
/// Off shift (dismissed, recalled, swapping): walking to the staff closet to go
#define OUTPOST_GUARD_DISMISSED "dismissed"

// Response priorities, most urgent highest. One guard per incident on the ladder (corpse, crit, threat,
// argument, fight, climb); a riot, an experiment and the leash take every guard they apply to. Spats and
// loose prisoners need no walk and are handled on the spot.
#define OUTPOST_GUARD_PRIORITY_CORPSE 1
#define OUTPOST_GUARD_PRIORITY_CRIT 2
#define OUTPOST_GUARD_PRIORITY_THREAT 3
#define OUTPOST_GUARD_PRIORITY_ARGUE 4
#define OUTPOST_GUARD_PRIORITY_FIGHT 5
#define OUTPOST_GUARD_PRIORITY_CLIMB 6
#define OUTPOST_GUARD_PRIORITY_RIOT 7
#define OUTPOST_GUARD_PRIORITY_LEASH 8

/// Trait source for what a guard on their feet refuses (lockers, bags)
#define OUTPOST_GUARD_UPRIGHT_TRAIT "outpost_guard_upright"
