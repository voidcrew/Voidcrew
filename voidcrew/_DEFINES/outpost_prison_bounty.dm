// # Outpost prison: bounty prisoner defines
//
// Owner: P7 prison (voidcrew/modules/player_outposts/outpost_prison_bounty.dm). Only P7 edits this
// file. The shared enums are in bounties.dm. The numbers are the balance fold-in's: the pool and
// pay from spec.md 12.1 (balance/economy.md), the body and danger from spec.md 12.3 C10
// (balance/combat.md section 6.5). A Petty prisoner is the ordinary baseline. Values marked OWN
// are this package's where neither review gave one.
//
// Unit tests compile before these: a test uses the literal value, with the define named beside it.

// ===== THE POOL =====

/// Records the prisoner pool holds. A capture is never refused (the pad has paid): at the cap the oldest open record leaves.
#define BOUNTY_POOL_CAP 20
/// How long a record waits in the pool before it leaves, closed ("taken to a state facility")
#define BOUNTY_RECORD_LIFE (45 MINUTES)
/// How long a record waits for its captor's own prison before any prison may take it
#define BOUNTY_RECORD_RESERVE (10 MINUTES)
/// How long the captor's prison may go without a cell ready for an arrival before its records open to all sooner
#define BOUNTY_RECORD_RESERVE_NO_CELL (2 MINUTES)
/// How often the pool looks at the wings: names their next bounty arrivals, runs their no-ready-cell clocks and lets old records go. Only while the pool holds anyone.
#define BOUNTY_POOL_TICK (10 SECONDS)

// ===== INTAKE (D-A5) =====

/// The warden's bounty intake setting: every bounty prisoner, all but Most Wanted, or none
#define BOUNTY_PRISON_INTAKE_ALL "all"
#define BOUNTY_PRISON_INTAKE_NO_MOST_WANTED "no_most_wanted"
#define BOUNTY_PRISON_INTAKE_NONE "none"
/// A bounty arrival is named on the warden's console at least this long before it beams in
#define BOUNTY_PRISON_NOTICE_TIME (60 SECONDS)
/// Seconds before a wing's next arrival at which its next bounty arrival is picked and named. More than BOUNTY_PRISON_NOTICE_TIME plus a pool tick, so the notice has usually run by the time the arrival is due.
#define BOUNTY_PRISON_NOTICE_WINDOW 90
/// Bounty prisoners a wing holds at once: half its cells, rounded down
#define OUTPOST_PRISON_BOUNTY_MAX(cells) FLOOR((cells) / 2, 1)

// ===== PAY =====

/// What a bounty prisoner earns the outpost (stipend, pay rate and release bonus), as a percent of an ordinary prisoner's, by tier
#define OUTPOST_PRISON_BOUNTY_MULT_PETTY 150
#define OUTPOST_PRISON_BOUNTY_MULT_WANTED 200
#define OUTPOST_PRISON_BOUNTY_MULT_MOST_WANTED 250

// ===== BODY =====

/// A bounty prisoner's health, by tier. The stamina pool follows it.
#define BOUNTY_PRISONER_HEALTH_PETTY 100
#define BOUNTY_PRISONER_HEALTH_WANTED 120
#define BOUNTY_PRISONER_HEALTH_MOST_WANTED 150
/// A bounty prisoner arrives hurt as they were caught, but with at least this percent of their health (spec 12.3 C11): downed deliveries otherwise crash wings.
#define BOUNTY_PRISONER_MIN_ARRIVAL_HEALTH 50

// ===== DANGER, BY TIER =====

/// Multiplier on their punches
#define BOUNTY_PRISON_PUNCH_MULT_PETTY 1
#define BOUNTY_PRISON_PUNCH_MULT_WANTED 1.25
#define BOUNTY_PRISON_PUNCH_MULT_MOST_WANTED 1.5
/// Multiplier on their shiv blows
#define BOUNTY_PRISON_SHIV_MULT_PETTY 1
#define BOUNTY_PRISON_SHIV_MULT_WANTED 1.15
#define BOUNTY_PRISON_SHIV_MULT_MOST_WANTED 1.3
/// Multiplier on their mood losses
#define BOUNTY_PRISON_MOOD_SCALE_PETTY 1
#define BOUNTY_PRISON_MOOD_SCALE_WANTED 1.1
#define BOUNTY_PRISON_MOOD_SCALE_MOST_WANTED 1.2
/// Mood points added to the line below which they square up to staff
#define BOUNTY_PRISON_THREAT_BONUS_PETTY 0
#define BOUNTY_PRISON_THREAT_BONUS_WANTED 0
#define BOUNTY_PRISON_THREAT_BONUS_MOST_WANTED 0
/// Mood points added to the line below which they join a riot
#define BOUNTY_PRISON_RIOT_BONUS_PETTY 0
#define BOUNTY_PRISON_RIOT_BONUS_WANTED 5
#define BOUNTY_PRISON_RIOT_BONUS_MOST_WANTED 10
/// Multiplier on the damage their blows do to the wing's ways out
#define BOUNTY_PRISON_BREAKOUT_MULT_PETTY 1
#define BOUNTY_PRISON_BREAKOUT_MULT_WANTED 1.25
#define BOUNTY_PRISON_BREAKOUT_MULT_MOST_WANTED 1.5
/// Multiplier on how long cuffing them takes
#define BOUNTY_PRISON_CUFF_MULT_PETTY 1
#define BOUNTY_PRISON_CUFF_MULT_WANTED 1
#define BOUNTY_PRISON_CUFF_MULT_MOST_WANTED 1
/// How much likelier a Wanted or Most Wanted prisoner who is not meek is to hit back when hit (like a grumpy one)
#define BOUNTY_PRISON_HIT_BACK_MULT_WANTED 1.5
#define BOUNTY_PRISON_HIT_BACK_MULT_MOST_WANTED 1.5
/// Tension an awake, uncuffed Most Wanted prisoner adds while in the yard: the ringleader. OWN: combat.md gives the ringleader no tension term.
#define BOUNTY_PRISON_RINGLEADER_TENSION 5
/// A Most Wanted prisoner's weight as the wildcard "snap" prisoner, and they shout first when a riot starts
#define BOUNTY_PRISON_RINGLEADER_SNAP_MULT 2

// ===== MEEK BOUNTY PRISONERS =====

/// How much likelier they are to back off when hit (like a nervous prisoner)
#define BOUNTY_PRISON_MEEK_BACK_OFF_MULT 2
/// Below this mood they climb a serving hatch left open on both sides (others: PRISONER_CLIMB_MOOD)
#define BOUNTY_PRISON_MEEK_CLIMB_MOOD 65
/// Seconds the climb takes them (others: PRISONER_CLIMB_TIME)
#define BOUNTY_PRISON_MEEK_CLIMB_TIME 2
/// Leisure weight of the climb, so it comes first like a duty (with a member of the wing home). OWN.
#define BOUNTY_PRISON_MEEK_CLIMB_WEIGHT 100
/// Below this mood they hang about by the staff door, glancing at it
#define BOUNTY_PRISON_MEEK_DART_MOOD 50
/// How long they watch the door each time
#define BOUNTY_PRISON_MEEK_WATCH_TIME (20 SECONDS)
/// Leisure weight of watching the door, aiming at about 30% of their time below BOUNTY_PRISON_MEEK_DART_MOOD. OWN: tune in the playtest.
#define BOUNTY_PRISON_MEEK_WATCH_WEIGHT 30
/// A watcher stands this many tiles from the staff door (never right in front of it), and the door opening while they are that close may see them dart through
#define BOUNTY_PRISON_MEEK_DART_RANGE 2
/// Percent chance they dart through a door opened near them, once per watch
#define BOUNTY_PRISON_MEEK_DART_CHANCE 25
/// Deciseconds between the steps of a dart
#define BOUNTY_PRISON_MEEK_DART_STEP 2
/// Steps a dart takes at most, waits for the door to swing open or for someone to get out of the way included, before they give up on it
#define BOUNTY_PRISON_MEEK_DART_STEPS 10
/// Their speed while loose (others keep their own, 2)
#define BOUNTY_PRISON_MEEK_LOOSE_SPEED 1.6
