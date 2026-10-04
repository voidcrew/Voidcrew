// # Outpost prison: the bounty bosses' riot moves
//
// Numbers for voidcrew/modules/player_outposts/outpost_prison_boss_moves.dm. The wind-ups sit close
// to the field kits' telegraphs (voidcrew/_DEFINES/bounty_bosses.dm); the harm is sized for a riot,
// where a prisoner has 150 health and the crew has no posse bonus to spare.
//
// Unit tests compile before these: a test uses the literal value, with the define named beside it.

// ===== EVERY MOVE =====

/// Trait source for a boss prisoner holding still while they wind up a move
#define PRISON_BOSS_MOVE_TRAIT "prison_boss_move"
/// How often a wind-up checks that the boss is still free to finish it (a knockdown or a drag stops it)
#define PRISON_BOSS_MOVE_WATCH (0.5 SECONDS)
/// How far a boss looks for staff to use a move on
#define PRISON_BOSS_SIGHT 7

// ===== JUGGERNAUT: SHOULDER CHARGE =====

/// Head down and the line marked (field charge: 0.8 seconds)
#define PRISON_BOSS_CHARGE_WINDUP (1 SECONDS)
#define PRISON_BOSS_CHARGE_COOLDOWN (20 SECONDS)
/// Tiles the line runs, at most, and the nearest staff he charges at
#define PRISON_BOSS_CHARGE_RANGE 4
#define PRISON_BOSS_CHARGE_MIN_RANGE 2
/// Deciseconds per tile of the run
#define PRISON_BOSS_CHARGE_STEP 1
/// Brute, against melee armour, and the knockdown for the first member of staff he hits
#define PRISON_BOSS_CHARGE_DAMAGE 10
#define PRISON_BOSS_CHARGE_KNOCKDOWN (2 SECONDS)
/// Run into a wall, a door or anything solid: he stands reeling this long
#define PRISON_BOSS_CHARGE_REEL (2 SECONDS)

// ===== PYROMANIAC: A BUNK ALIGHT =====

/// The match struck and the bunk marked (field molotov: 0.7 seconds and the throw)
#define PRISON_BOSS_FIRE_WINDUP (1 SECONDS)
#define PRISON_BOSS_FIRE_COOLDOWN (30 SECONDS)
/// How far off a bunk may be
#define PRISON_BOSS_FIRE_RANGE 4
/// How long the bunk and the tiles beside it burn (field molotov: 8 seconds)
#define PRISON_BOSS_FIRE_TIME (8 SECONDS)
/// Burn to staff standing in it when it goes up; after that, the field kit's burning (3 a second for 4 seconds, renewed in the flames)
#define PRISON_BOSS_FIRE_DAMAGE 8

// ===== DEMOLITIONIST: A RIGGED CHARGE =====

/// Kneeling to pack it (field breaching charge: 0.6 seconds)
#define PRISON_BOSS_RIG_WINDUP (0.6 SECONDS)
/// The beeping fuse (field breaching charge: 5 seconds)
#define PRISON_BOSS_RIG_FUSE (5 SECONDS)
/// Percent of the fixture's full integrity the bang takes off it
#define PRISON_BOSS_RIG_SHARE 60
/// Brute, against bomb armour, and the knockdown for staff right beside it
#define PRISON_BOSS_RIG_DAMAGE 10
#define PRISON_BOSS_RIG_KNOCKDOWN (2 SECONDS)

// ===== GHOST: SLIPPING THE CUFFS =====

/// Cuffed this long before they start on the cuffs
#define PRISON_BOSS_SLIP_DELAY (3 SECONDS)
/// Working at the cuffs
#define PRISON_BOSS_SLIP_TIME (5 SECONDS)
/// Stopped before they were free: they may try again after this
#define PRISON_BOSS_SLIP_RETRY (15 SECONDS)
/// The shimmer afterwards (field cloak: 6 seconds, half of all hits miss)
#define PRISON_BOSS_SHIMMER_TIME (6 SECONDS)
#define PRISON_BOSS_SHIMMER_MISS 50
#define PRISON_BOSS_SHIMMER_ALPHA 90

// ===== HEAVY: A BARRICADE =====

/// A grip on the table or a shoulder to the locker (field barricade: 0.6 seconds)
#define PRISON_BOSS_BARRICADE_WINDUP (1 SECONDS)
#define PRISON_BOSS_BARRICADE_COOLDOWN (25 SECONDS)
/// How far off the staff he builds against may be
#define PRISON_BOSS_BARRICADE_SIGHT 6
/// Staff within this many tiles of a staff door are coming through it
#define PRISON_BOSS_DOORWAY_RANGE 3
/// Tiles a locker is shoved, at most, and deciseconds per tile
#define PRISON_BOSS_SHOVE_STEPS 4
#define PRISON_BOSS_SHOVE_STEP 2

// ===== KINGPIN: THE WORD AND THE PAYOFF =====

/// Mood points added to a prisoner's riot line when the kingpin gives the word
#define PRISON_BOSS_WORD_BONUS 15
/// The look and the tap on the pocket
#define PRISON_BOSS_BRIBE_WINDUP (2 SECONDS)
/// A try that was stopped may come again after this
#define PRISON_BOSS_BRIBE_RETRY (10 SECONDS)
/// How far off the guard may be
#define PRISON_BOSS_BRIBE_RANGE 7
/// How long a paid guard stays out of the fight
#define PRISON_BOSS_BRIBE_TIME (30 SECONDS)
