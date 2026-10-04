// ===== OUTPOST PRISON: NPC GUARDS (see outpost_prison_guards.dm) =====
// Owner: XA. Values from extras-plan.md 4.1. Guards are security only: they never feed, clothe,
// treat, clean or light anything, so they cannot raise pay.

/// Guards a wing can hire: one on the door, one in the yard
#define OUTPOST_GUARD_MAX 2
/// Credits charged from the treasury before a hired guard beams in; refused if short, never debt
#define OUTPOST_GUARD_HIRE_COST 1000
/// Credits per minute per guard, only for time a wing member was home
#define OUTPOST_GUARD_WAGE 2
/// Wages skipped in a row (the treasury could not cover them) before the guards walk off
#define OUTPOST_GUARD_UNPAID_LEAVE 2
#define OUTPOST_GUARD_HEALTH 120
/// Health at which a guard goes down (godmode, lying) instead of taking more damage
#define OUTPOST_GUARD_DOWN_AT 30
/// From going down to beaming out
#define OUTPOST_GUARD_RECALL_DELAY (10 SECONDS)
/// A downed or recalled guard comes back free after this, if still hired and a member is home
#define OUTPOST_GUARD_RETURN_TIME (10 MINUTES)
/// Stamina damage per baton strike: prisoners crit at 100, so three strikes
#define OUTPOST_GUARD_BATON_STAMINA 35
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
/// Health a guard gets back per minute while not in a riot and not down
#define OUTPOST_GUARD_HEAL_PER_MINUTE 12
/// Movement: an unhurried walk on routine, a hurry on a response (basic mob speed)
#define OUTPOST_GUARD_SPEED_WALK 2
#define OUTPOST_GUARD_SPEED_HURRY 1
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
/// Beaming in
#define OUTPOST_GUARD_ARRIVING "arriving"
/// On the wing and on duty
#define OUTPOST_GUARD_PRESENT "present"
/// Down (godmode, lying) and waiting to be beamed out
#define OUTPOST_GUARD_DOWN "down"
/// Dismissed or quitting: walking back to the office to beam out
#define OUTPOST_GUARD_DISMISSED "dismissed"
/// Beaming out
#define OUTPOST_GUARD_LEAVING "leaving"

// Response priorities, most urgent highest. One guard per incident on the ladder (threat, argument, fight,
// climb); a riot, an experiment and the leash take every guard they apply to. Spats and loose prisoners
// need no walk and are handled on the spot.
#define OUTPOST_GUARD_PRIORITY_THREAT 3
#define OUTPOST_GUARD_PRIORITY_ARGUE 4
#define OUTPOST_GUARD_PRIORITY_FIGHT 5
#define OUTPOST_GUARD_PRIORITY_CLIMB 6
#define OUTPOST_GUARD_PRIORITY_RIOT 7
#define OUTPOST_GUARD_PRIORITY_LEASH 8
#define OUTPOST_GUARD_PRIORITY_SHELTER 9

/// Trait source for the beam holding a guard still
#define OUTPOST_GUARD_BEAM_TRAIT "outpost_guard_beam"
/// Trait source for a guard lying down, out of it
#define OUTPOST_GUARD_DOWN_TRAIT "outpost_guard_down"
