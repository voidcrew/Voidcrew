// # Bounty hunting: criminal body defines
//
// Owner: P2 body (voidcrew/modules/bounties/bounty_criminal.dm, bounty_restraints.dm). Only P2 edits
// this file. The shared enums are in bounties.dm. The numbers are balance/combat.md section 6, as
// consolidated in spec.md section 12.3 (C1-C9).
//
// Unit tests compile before voidcrew/_DEFINES and cannot see these: a test uses the literal value,
// with a comment naming the define.

// ===== TRAITS =====

/**
 * On a criminal while it is restrained or downed: its AI must plan nothing. P3's controller can
 * check it in its first subtree. P2 also adds TRAIT_AI_PAUSED under BOUNTY_BODY_HELD_TRAIT at the
 * same time, which stops the controller outright.
 */
#define TRAIT_BOUNTY_HELD "bounty_held"
/// A meek criminal sprinting, and neither winded nor cornered: P3 adds and removes it (source BOUNTY_TRAIT). P2 dodges projectiles while it is on (BOUNTY_MEEK_DODGE).
#define TRAIT_BOUNTY_SPRINTING "bounty_sprinting"
/**
 * A script is walking the criminal somewhere on purpose (a walk-out, a cutscene): the leash lets its
 * steps through. Godmode counts the same, which covers P6's walk out to the hangar lift.
 */
#define TRAIT_BOUNTY_SCRIPTED_MOVE "bounty_scripted_move"

/// Trait source for what the body always has (no teleports, no mob swaps)
#define BOUNTY_BODY_TRAIT "bounty_body"
/// Trait source for being downed: floored, incapacitated, immobilized
#define BOUNTY_BODY_DOWNED_TRAIT "bounty_body_downed"
/// Trait source for the restraints holding a criminal still
#define BOUNTY_BODY_CUFFS_TRAIT "bounty_body_cuffs"
/// Trait source for TRAIT_BOUNTY_HELD and TRAIT_AI_PAUSED while restrained or downed
#define BOUNTY_BODY_HELD_TRAIT "bounty_body_held"

// ===== BODY =====

/// sentience_type of every criminal: no sentience potion, no ghost role
#define BOUNTY_CRIMINAL_NO_SENTIENCE 0

/// Health of a meek criminal, every tier
#define BOUNTY_MEEK_HEALTH 120
/// Health of a normal criminal by tier, before the style's multiplier (C7)
#define BOUNTY_NORMAL_HEALTH_PETTY 140
#define BOUNTY_NORMAL_HEALTH_WANTED 180
#define BOUNTY_NORMAL_HEALTH_MOST 220
/// P0's name for the normal criminal's health: the Wanted value
#define BOUNTY_NORMAL_HEALTH BOUNTY_NORMAL_HEALTH_WANTED

/// Health multiplier by fighting style (combat.md 6.2)
#define BOUNTY_STYLE_HEALTH_BRAWLER 1.2
#define BOUNTY_STYLE_HEALTH_KNIFE 1
#define BOUNTY_STYLE_HEALTH_PISTOL 0.9
#define BOUNTY_STYLE_HEALTH_SHOTGUN 1
#define BOUNTY_STYLE_HEALTH_CLUB 1.1
#define BOUNTY_STYLE_HEALTH_BOTTLE 0.9
/// A brawler takes stamina damage x this
#define BOUNTY_STYLE_STAMINA_BRAWLER 0.8

/// Fire and heat (L3): a criminal on fire, or hotter than this, burns like a suited person, BOUNTY_CRIMINAL_BURN_DAMAGE a second. The mercy line and the automated floor still hold it. Mini-bosses keep P4's own fire rules.
#define BOUNTY_CRIMINAL_MAX_TEMP SPACE_SUIT_MAX_TEMP_PROTECT
#define BOUNTY_CRIMINAL_BURN_DAMAGE 3

/// An explosion counts as a player's when the explosive was last touched by one, or someone with a mind stands within this many tiles
#define BOUNTY_EXPLOSION_WITNESS_RANGE 7

/// Pace of a meek criminal: its sprint (P3 slows it while winded)
#define BOUNTY_BODY_MEEK_SPEED 1.1
/// Pace of a normal criminal with a melee style, and with a ranged one (pistol, bottle)
#define BOUNTY_BODY_NORMAL_SPEED_MELEE 1.25
#define BOUNTY_BODY_NORMAL_SPEED_RANGED 1.4

// ===== STAMINA =====
// max_stamina stays at 100 on every criminal: basic mobs leave stamina crit by comparing raw stamina
// with a percentage (stamcrit.dm), which only agree at 100. A pool of any other size is the stamina
// damage coefficient: 100 / pool.

#define BOUNTY_CRIMINAL_MAX_STAMINA 100
/// Stamina crit at this much stamina: a hair under 100, so a pool that divides evenly (three 30-point disabler shots on a 90 pool) still crits through float rounding
#define BOUNTY_CRIMINAL_STAMCRIT_AT 99.9
/// A meek criminal's stamina pool: three disabler shots or two batons (C5)
#define BOUNTY_MEEK_STAMINA 90
/// A meek criminal's slowdown with no stamina left (tg's is 3): one hit must not end the chase (C5)
#define BOUNTY_MEEK_STAMINA_SLOWDOWN 0.5
/// How long stamina crit lasts after the last stamina hit: meek (C5), and everyone else (tg's default, as simulated)
#define BOUNTY_MEEK_STAMCRIT_TIME (12 SECONDS)
#define BOUNTY_NORMAL_STAMCRIT_TIME (10 SECONDS)
/// P0's name for the stamina crit time
#define BOUNTY_STAMCRIT_TIME BOUNTY_NORMAL_STAMCRIT_TIME
/// P0's names for the stamina coefficients. The pool sets the real one (100 / pool); these stay 1.
#define BOUNTY_MEEK_STAMINA_COEFF 1
#define BOUNTY_NORMAL_STAMINA_COEFF 1

/// Percent of projectiles a sprinting meek criminal ducks (C5)
#define BOUNTY_MEEK_DODGE 50
/// No ducking within this long of being shot
#define BOUNTY_MEEK_DODGE_AFTER_HIT (1 SECONDS)

// ===== DOWNED AND RECOVERY (C1, C3) =====

/// Percent of max health at or below which a criminal is downed
#define BOUNTY_DOWNED_BELOW 25
/// P0's name for the downed line, as a fraction
#define BOUNTY_DOWNED_FRACTION (BOUNTY_DOWNED_BELOW / 100)
/// Percent of max health a downed criminal gets up with (more if it was healed while down)
#define BOUNTY_RECOVER_TO 35
/// How long a downed, uncuffed criminal stays down, by archetype
#define BOUNTY_RECOVER_TIME_MEEK (60 SECONDS)
#define BOUNTY_RECOVER_TIME_NORMAL (75 SECONDS)
#define BOUNTY_RECOVER_TIME_BOSS (45 SECONDS)
/// The last stretch of the recovery, when it groans and tries to rise
#define BOUNTY_BODY_STIRRING_TELL (10 SECONDS)
/// A mini-boss that gets up shrugs off stamina for this long (C1); P4 shows it
#define BOUNTY_BODY_RALLY_TIME (20 SECONDS)

// ===== AUTOMATED DAMAGE (AR-D3) =====

/// On its site, damage with nobody's mind behind it (turrets, traps, fire, fauna) stops at this percent of max health
#define BOUNTY_AUTOMATED_FLOOR 40

// ===== RESTRAINTS (C2) =====

/// Putting restraints on a downed, stunned or surrendered criminal
#define BOUNTY_CUFF_TIME (2 SECONDS)
/// Taking them off
#define BOUNTY_UNCUFF_TIME (2 SECONDS)
/// Cable restraints and zipties slip after this long; handcuffs never do
#define BOUNTY_CABLE_SLIP (3 MINUTES)
#define BOUNTY_ZIPTIE_SLIP (5 MINUTES)
/// Joke cuffs and zipties
#define BOUNTY_FAKE_CUFF_SLIP (5 SECONDS)
/// A mini-boss gets out of cable and zipties in this share of the time (combat.md 6.4)
#define BOUNTY_BOSS_SLIP_MULT 0.5
/// The visible struggle starts this long before they slip
#define BOUNTY_SLIP_WARNING (20 SECONDS)

// ===== LEASH AND TARGETS (AR-D1, AR-D2) =====

/// Environment damage is refused within this many tiles of a ship, a hangar, a player outpost or a planet's dock strip
#define BOUNTY_ENV_SAFE_RANGE 7
/// Leash half-width around the spawn point when the site has no bounds of its own
#define BOUNTY_BODY_FALLBACK_LEASH 40
/// Most mobs a criminal remembers as fair game; the oldest go first
#define BOUNTY_GRUDGE_MAX 12
