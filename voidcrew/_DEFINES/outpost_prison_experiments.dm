// ===== OUTPOST PRISON: EXPERIMENTS (see outpost_prison_experiments.dm) =====
// The researcher's offers, serums, specimens and the creatures they make.
//
// A Kessler Biolabs researcher visits a well-kept wing now and then and offers a serum (blind:
// hulk, nightmare or fly person) or, from the second offer on, a specimen (the changeling). A
// manager may take it. The wing is paid a fee when the creature shows and a containment bonus
// when it is put down, if the crew did at least half of the damage. A creature stays until the
// crew puts it down or an admin ends the experiment. One taken off the outpost is recovered by
// Kessler for a fee that becomes the treasury's debt when it cannot pay. Every clock here counts
// only while a member is home.

/// The experiments core is compiled in. Also defined at the top of outpost_prison_experiments.dm;
/// defined here too so files included before that one (the changeling's) see it.
#define OUTPOST_EXPERIMENT_API

/// A mob that belongs to a prison experiment: its creatures, the researcher and the recovery team.
/// The damage ledger adds it to anything it is put on.
#define TRAIT_OUTPOST_EXPERIMENT "outpost_experiment"
/// The creatures' faction
#define FACTION_OUTPOST_EXPERIMENT "outpost_experiment"

// ----- The researcher's visits (seconds; the clocks count only while a member is home) -----
/// First visit, after the wing's first prisoner arrives
#define OUTPOST_EXPERIMENT_FIRST_VISIT_MIN (15 * 60)
#define OUTPOST_EXPERIMENT_FIRST_VISIT_MAX (25 * 60)
/// Later visits, after an experiment resolves or an offer is declined or lapses
#define OUTPOST_EXPERIMENT_GAP_MIN (35 * 60)
#define OUTPOST_EXPERIMENT_GAP_MAX (50 * 60)
/// A visit whose gates fail is tried again this much later
#define OUTPOST_EXPERIMENT_RETRY 120
/// How long the researcher waits, and the most while a manager has the offer open
#define OUTPOST_EXPERIMENT_STAY 180
#define OUTPOST_EXPERIMENT_STAY_OPEN 300
/// Conditions score a visit needs
#define OUTPOST_EXPERIMENT_MIN_CONDITIONS 60
/// Percent chance an offer is a specimen: never the wing's first offer, and it needs two prisoners
#define OUTPOST_EXPERIMENT_SPECIMEN_CHANCE 30
/// Serum outcomes, by weight. The offer does not say which.
#define OUTPOST_EXPERIMENT_WEIGHT_HULK 40
#define OUTPOST_EXPERIMENT_WEIGHT_NIGHTMARE 30
#define OUTPOST_EXPERIMENT_WEIGHT_FLY 30
/// Each declined or ignored offer raises the next one's pay by this share, up to the max; taking one resets it
#define OUTPOST_EXPERIMENT_SWEETENER 0.1
#define OUTPOST_EXPERIMENT_SWEETENER_MAX 0.3
/// Seconds between a waiting researcher's pitches, and between "management only" replies
#define OUTPOST_EXPERIMENT_PITCH_GAP 40
#define OUTPOST_EXPERIMENT_BRUSH_OFF_GAP (5 SECONDS)

// ----- Items -----
/// How long the serum, the specimen jar and the food it taints last, real time
#define OUTPOST_EXPERIMENT_ITEM_LIFETIME (10 MINUTES)
/// How long injecting the serum and tainting food take
#define OUTPOST_EXPERIMENT_DOSE_TIME (2 SECONDS)

// ----- The serum -----
/// Seconds from the dose to the change; the form's tells show in the last OUTPOST_EXPERIMENT_TELLS
#define OUTPOST_EXPERIMENT_TWITCH 60
#define OUTPOST_EXPERIMENT_TELLS 40
/// Seconds a dosed subject or host may spend outside the cell block before the experiment fails
#define OUTPOST_EXPERIMENT_OUTSIDE_LIMIT 60

// ----- Kessler collection -----
/// Seconds a creature that was put down lies there before Kessler's team beams in for it
#define OUTPOST_EXPERIMENT_PICKUP 10
/// Seconds the console keeps showing how an experiment ended
#define OUTPOST_EXPERIMENT_RESULT_SHOWN 60

// ----- Pay (fee when the creature shows, bonus when it is put down with the crew doing half the damage) -----
#define OUTPOST_EXPERIMENT_PLAYER_SHARE 0.5
/// A creature put down with no damage on record pays the bonus only if a player attacked it this recently
#define OUTPOST_EXPERIMENT_PLAYER_RECENT (30 SECONDS)
#define OUTPOST_EXPERIMENT_FEE_FLY 300
#define OUTPOST_EXPERIMENT_FEE_HULK 600
#define OUTPOST_EXPERIMENT_FEE_NIGHTMARE 600
/// The specimen's fee, paid when the host bursts
#define OUTPOST_EXPERIMENT_FEE_CHANGELING 600
#define OUTPOST_EXPERIMENT_BONUS_FLY 700
#define OUTPOST_EXPERIMENT_BONUS_HULK 1900
#define OUTPOST_EXPERIMENT_BONUS_HULK_SUBDUED 2400
#define OUTPOST_EXPERIMENT_BONUS_NIGHTMARE 2400
#define OUTPOST_EXPERIMENT_BONUS_HEADSLUG 900
#define OUTPOST_EXPERIMENT_BONUS_HORROR 3900
/// What Kessler charges to recover a creature; the headslug is never recovered
#define OUTPOST_EXPERIMENT_RECOVERY_FLY 500
#define OUTPOST_EXPERIMENT_RECOVERY_HULK 1500
#define OUTPOST_EXPERIMENT_RECOVERY_NIGHTMARE 1500
#define OUTPOST_EXPERIMENT_RECOVERY_HORROR 2500

// ----- What the prisoners go through -----
/// Mood each prisoner who saw a death loses when the experiment ends, and tension per prisoner a creature killed
#define OUTPOST_EXPERIMENT_SAW_DEATH_MOOD 10
#define OUTPOST_EXPERIMENT_KILL_TENSION 15
/// How far away a prisoner sees a death
#define OUTPOST_EXPERIMENT_WITNESS_RANGE 7
/// Seconds between a panicking prisoner's calls to be locked in
#define OUTPOST_EXPERIMENT_PANIC_GAP 25
/// Mood lost watching the fly person throw up, at most once per OUTPOST_EXPERIMENT_FLY_DISGUST_GAP each
#define OUTPOST_EXPERIMENT_FLY_DISGUST_MOOD 2
#define OUTPOST_EXPERIMENT_FLY_DISGUST_GAP (60 SECONDS)

// ----- Running from creatures (outpost_prison_panic.dm) -----
/// A creature this close and in sight frightens a prisoner, as does one loose anywhere in the cell block
#define OUTPOST_PANIC_SIGHT_RANGE 7
/// A horror down regenerating frightens only prisoners this close to it
#define OUTPOST_PANIC_DOWNED_RANGE 2
/// Seconds with no creature in the cell block or in sight before a frightened prisoner calms down
#define OUTPOST_PANIC_CALM_TIME 60
/// A prisoner's move delay while they run (they walk at 2; the hulk moves at 1.8 and the horror at 2)
#define OUTPOST_PANIC_FLEE_SPEED 1.3
/// A way home that passes this close to the creature, and no farther from it than they stand, is no way home
#define OUTPOST_PANIC_PATH_MARGIN 2
/// Nowhere this close to the creature is somewhere to run to
#define OUTPOST_PANIC_SPOT_MARGIN 2
/// Seconds between looks at whether where they are running or hiding still holds
#define OUTPOST_PANIC_REPLAN_GAP 2
/// Rioters and fighters roll to run or fight when a creature comes this close
#define OUTPOST_PANIC_ROLL_RANGE 3
/// Seconds a rioter's or fighter's roll holds before they roll again
#define OUTPOST_PANIC_ROLL_HOLD (12 SECONDS)
/// Percent chance a rioter or fighter goes for the creature rather than running, at the middle mood;
/// higher below it and lower above, never outside the bounds
#define OUTPOST_PANIC_FIGHT_CHANCE 25
#define OUTPOST_PANIC_FIGHT_MID_MOOD 30
#define OUTPOST_PANIC_FIGHT_PER_MOOD 0.25
#define OUTPOST_PANIC_FIGHT_MIN 5
#define OUTPOST_PANIC_FIGHT_MAX 50
/// Grumpy prisoners go for it this many times as often, nervous and cheerful ones this many times less often
#define OUTPOST_PANIC_FIGHT_PERSONALITY_MULT 1.5
/// How long a rioter or fighter keeps going at a creature
#define OUTPOST_PANIC_STAND_TIME (20 SECONDS)
/// How long a rioter who runs has to get away before they riot on
#define OUTPOST_PANIC_RETREAT_TIME (15 SECONDS)

// ----- Creatures: health grows with the crew on the level when they appear -----
/// Most extra players counted
#define OUTPOST_EXPERIMENT_EXTRA_PLAYERS_MAX 3

// Hulk
#define OUTPOST_HULK_HEALTH 350
#define OUTPOST_HULK_HEALTH_PER_PLAYER 100
#define OUTPOST_HULK_SPEED 1.8
#define OUTPOST_HULK_EXHAUSTED_SPEED 2.5
#define OUTPOST_HULK_PUNCH_MIN 18
#define OUTPOST_HULK_PUNCH_MAX 22
#define OUTPOST_HULK_PUNCH_COOLDOWN (1.5 SECONDS)
/// Percent chance a punch throws its target OUTPOST_HULK_THROW_RANGE tiles
#define OUTPOST_HULK_THROW_CHANCE 25
#define OUTPOST_HULK_THROW_RANGE 2
/// The charge: wind-up, range, damage, knockdown, cooldown
#define OUTPOST_HULK_CHARGE_WINDUP (1.5 SECONDS)
#define OUTPOST_HULK_CHARGE_RANGE 6
#define OUTPOST_HULK_CHARGE_DAMAGE 20
#define OUTPOST_HULK_CHARGE_KNOCKDOWN (2 SECONDS)
#define OUTPOST_HULK_CHARGE_COOLDOWN (12 SECONDS)
/// Charging into a wall with nobody caught: stunned this long, taking this much more damage meanwhile
#define OUTPOST_HULK_WALL_STUN (2 SECONDS)
#define OUTPOST_HULK_WALL_VULNERABLE 1.25
/// Tearing through an interior wall, and forcing a door
#define OUTPOST_HULK_TEAR_TIME (3 SECONDS)
#define OUTPOST_HULK_DOOR_TIME (4 SECONDS)
/// Worn down to this percent of health, it stops charging and a baton or disabler can put it down
#define OUTPOST_HULK_EXHAUSTED_AT 25
/// Stamina it can take once exhausted: two baton hits or four disabler shots
#define OUTPOST_HULK_STAMINA 110

// Nightmare
#define OUTPOST_NIGHTMARE_HEALTH 225
#define OUTPOST_NIGHTMARE_HEALTH_PER_PLAYER 75
#define OUTPOST_NIGHTMARE_DARK_SPEED 1.5
#define OUTPOST_NIGHTMARE_LIGHT_SPEED 2.5
#define OUTPOST_NIGHTMARE_DAMAGE 20
#define OUTPOST_NIGHTMARE_ATTACK_COOLDOWN (1.2 SECONDS)
#define OUTPOST_NIGHTMARE_ARMOUR_PENETRATION 20
/// Percent chance a hit burns out a flashlight the target holds (never flares or glowsticks)
#define OUTPOST_NIGHTMARE_BURNOUT_CHANCE 35
/// Light level below which it is in the dark (SHADOW_SPECIES_LIGHT_THRESHOLD)
#define OUTPOST_NIGHTMARE_DARK 0.2
/// Health per second: regained in the dark, lost in the light
#define OUTPOST_NIGHTMARE_REGEN 2
#define OUTPOST_NIGHTMARE_BURN 2
/// Percent of shots it sidesteps in the dark
#define OUTPOST_NIGHTMARE_DODGE 60
/// The shadow jaunt: cooldown, the ripple that warns of it, what it does
#define OUTPOST_NIGHTMARE_JAUNT_COOLDOWN (12 SECONDS)
#define OUTPOST_NIGHTMARE_JAUNT_RIPPLE (1 SECONDS)
#define OUTPOST_NIGHTMARE_JAUNT_DAMAGE 25
#define OUTPOST_NIGHTMARE_JAUNT_KNOCKDOWN (1 SECONDS)
/// A handheld flash: burn and stagger
#define OUTPOST_NIGHTMARE_FLASH_DAMAGE 20
#define OUTPOST_NIGHTMARE_FLASH_STAGGER (2 SECONDS)
/// Seconds it spends breaking the lights first, ignoring people who leave it alone
#define OUTPOST_NIGHTMARE_OPENING_MIN 30
#define OUTPOST_NIGHTMARE_OPENING_MAX 45

// Fly person
#define OUTPOST_FLY_HEALTH 60
/// Its move delay: faster than a running person (1.5)
#define OUTPOST_FLY_SPEED 0.7
/// Percent of shots it jinks out of the way of while flying freely (not knocked down, held or subdued)
#define OUTPOST_FLY_DODGE 40
#define OUTPOST_FLY_BITE 5
/// It darts away from anyone this close
#define OUTPOST_FLY_FLEE_RANGE 3
/// Its darts: tiles, the pause between random ones, and how long one may take before it gives up on it
#define OUTPOST_FLY_DART_MIN 2
#define OUTPOST_FLY_DART_MAX 5
#define OUTPOST_FLY_DART_GAP_MIN (0.4 SECONDS)
#define OUTPOST_FLY_DART_GAP_MAX (1.2 SECONDS)
#define OUTPOST_FLY_DART_TIMEOUT (1.5 SECONDS)
/// How long it keeps away from whoever last hit it
#define OUTPOST_FLY_FLIT_TIME (3 SECONDS)
/// Trait source for its flight
#define OUTPOST_FLY_TRAIT "outpost_fly"
/// Seconds between throwing up, and the percent chance it gets someone beside it
#define OUTPOST_FLY_VOMIT_MIN 6
#define OUTPOST_FLY_VOMIT_MAX 10
#define OUTPOST_FLY_VOMIT_ON_CHANCE 25
/// A flyswatter hits it this many times harder, as it does tg's fly people
#define OUTPOST_FLY_SWATTER_MULT 30
/// Stamina it can take: two baton hits
#define OUTPOST_FLY_STAMINA 100

// ----- Trait sources and timings shared by the experiment files -----
/// Seconds a creature may chase its current target with no progress (not closer, not adjacent)
/// before it writes the target off as unreachable. Cheap: distance only, no pathfinding.
#define OUTPOST_EXPERIMENT_STUCK_TIME (4 SECONDS)
/// How long a target written off stays off find_light()'s and choose_target()'s lists
#define OUTPOST_EXPERIMENT_UNREACHABLE_TIME (30 SECONDS)
/// Most targets a creature keeps written off at once, oldest dropped first
#define OUTPOST_EXPERIMENT_UNREACHABLE_MAX 16
/// Trait source for the damage ledger's TRAIT_OUTPOST_EXPERIMENT
#define OUTPOST_EXPERIMENT_LEDGER_TRAIT "outpost_experiment_ledger"
/// Trait source for a creature Kessler is taking away
#define OUTPOST_KESSLER_TRAIT "outpost_kessler"
/// How long a Kessler recovery team stays before beaming out with the creature
#define OUTPOST_KESSLER_TEAM_TIME (5 SECONDS)
/// How long a Kessler beam takes, in and out
#define OUTPOST_KESSLER_BEAM_TIME (3 SECONDS)
/// The creatures' sentience type: it matches no potion, lazarus injector or ghost role (the spec's SENTIENCE_NONE)
#define OUTPOST_EXPERIMENT_NO_SENTIENCE 0
