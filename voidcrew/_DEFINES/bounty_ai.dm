// # Bounty hunting: criminal AI defines
//
// Owner: P3 AI (voidcrew/modules/bounties/bounty_ai.dm, bounty_ai_meek.dm, bounty_ai_normal.dm,
// bounty_activities.dm, bounty_companions.dm). Only P3 edits this file. The shared enums are in
// bounties.dm. The numbers come from balance/combat.md section 6 and spec section 12.3 (C4, C6,
// C7); the rest are the spec's section 3 values.

// ===== TRAITS =====

// P2 declares these two in bounty_criminals.dm with the same values. The guarded copies here let this
// package build on its own; once both are merged, these can go.
#ifndef TRAIT_BOUNTY_SPRINTING
/// A meek criminal running flat out, not winded, cornered or aiming. P2's projectile dodge reads it.
#define TRAIT_BOUNTY_SPRINTING "bounty_sprinting"
#endif
#ifndef TRAIT_BOUNTY_HELD
/// Restrained or downed (P2): the AI plans nothing
#define TRAIT_BOUNTY_HELD "bounty_held"
#endif
/// Trait source for what the criminal AI puts on a mob (TRAIT_BOUNTY_SPRINTING)
#define BOUNTY_AI_TRAIT "bounty_ai"

// ===== WHAT THEY ARE DOING =====

/// Going about their activity
#define BOUNTY_AI_CALM "calm"
/// Watching someone armed who came close (normal)
#define BOUNTY_AI_AWARE "aware"
/// Running from someone (meek, decoys, companions that broke)
#define BOUNTY_AI_FLEEING "fleeing"
/// Fighting their grudge list (normal, companions)
#define BOUNTY_AI_FIGHTING "fighting"
/// Badly hurt with nobody near: getting away and sitting it out (normal)
#define BOUNTY_AI_RETREATING "retreating"

// ===== HIDING (meek) =====

/// In a locker or a crate
#define BOUNTY_HIDE_CONTAINER "container"
/// Passing as a potted plant
#define BOUNTY_HIDE_PLANT "plant"
/// Standing still on a dark tile
#define BOUNTY_HIDE_DARK "dark"

// ===== BLACKBOARD KEYS =====

/// Where a meek criminal is running to hide: a closet, a potted plant or a dark turf
#define BB_BOUNTY_HIDE_SPOT "bb_bounty_hide_spot"
/// A turf they are walking to: their activity's spot, a retreat, a hiding place
#define BB_BOUNTY_DESTINATION "bb_bounty_destination"
/// A companion's criminal
#define BB_BOUNTY_LEADER "bb_bounty_leader"
/// Their fighting style's key (BOUNTY_STYLE_*)
#define BB_BOUNTY_STYLE "bb_bounty_style"
/// The real item they fight with (a typepath: bounty_real_weapon()), or null for bare fists
#define BB_BOUNTY_WEAPON "bb_bounty_weapon"
/// Rounds left in the magazine
#define BB_BOUNTY_AMMO "bb_bounty_ammo"
/// world.time a reload ends
#define BB_BOUNTY_RELOAD_UNTIL "bb_bounty_reload_until"
/// world.time the current wind-up ends
#define BB_BOUNTY_WINDUP_UNTIL "bb_bounty_windup_until"
/// world.time of the last shot
#define BB_BOUNTY_LAST_SHOT "bb_bounty_last_shot"
/// world.time a ranged fighter may next step back from someone too close
#define BB_BOUNTY_BACKSTEP_AT "bb_bounty_backstep_at"

// ===== ACTIVITY STEPS =====

/// The activity carries on where they are
#define BOUNTY_STEP_CONTINUE 0
/// The activity set a new spot to walk to
#define BOUNTY_STEP_MOVE 1
/// The activity is over; a new one of the same kind is set up
#define BOUNTY_STEP_DONE 2

// ===== SHARED =====

/// Speed while going about their business, and while blended in (the fugitive and every decoy move alike)
#define BOUNTY_CALM_SPEED 2.5
/// How often they look around for hunters
#define BOUNTY_NOTICE_INTERVAL (0.5 SECONDS)
/// Held items at least this strong count as a weapon drawn
#define BOUNTY_WEAPON_FORCE 10
/// How far they run each leg when fleeing
#define BOUNTY_FLEE_DISTANCE 9
/// How far they look for their grudge list in a fight
#define BOUNTY_FIGHT_VISION 9
/// How often a ranged fighter steps back from someone inside its style's min_range
#define BOUNTY_BACKSTEP_GAP (0.8 SECONDS)
/// How many times a walk may fail before they give up on where they were going
#define BOUNTY_TRAVEL_GIVE_UP 3
/// How long before trying an activity again after it could not be set up
#define BOUNTY_ACTIVITY_RETRY (30 SECONDS)
/// How far an activity looks for its seat, stall, containers or partner
#define BOUNTY_ACTIVITY_RANGE 8
/// How far exploring looks for things to look at
#define BOUNTY_EXPLORE_RANGE 10
/// Glasses a criminal leaves on tables at the bar before a finished glass just goes
#define BOUNTY_BAR_GLASSES_MAX 2
/// Spots an activity remembers as out of reach
#define BOUNTY_FAILED_SPOTS_MAX 8
/// How long a trader outpost's public floor is reused between its patrons before it is worked out again
#define BOUNTY_OUTPOST_FLOOR_CACHE (1 MINUTES)

// ===== MEEK (combat.md 6.1, spec C6) =====

/// Speed while sprinting: the tg trooper's, faster than a running person (1.5)
#define BOUNTY_MEEK_SPRINT_SPEED 1.1
/// A lizard sprints a little faster (spec section 2)
#define BOUNTY_MEEK_LIZARD_SPRINT_BONUS 0.1
/// Speed while winded: clearly slower than a runner
#define BOUNTY_MEEK_WINDED_SPEED 2.2
/// How long they sprint before they are winded
#define BOUNTY_MEEK_SPRINT_TIME (8 SECONDS)
/// Resting still, the sprint comes back in this long
#define BOUNTY_MEEK_REST_TIME (8 SECONDS)
/// Sprint back per second spent hidden (full in about 5 s)
#define BOUNTY_MEEK_RECOVER_HIDDEN 1.5
/// Sprint back per second spent unseen but not hidden
#define BOUNTY_MEEK_RECOVER_WALKING 0.3
/// Someone armed, cuffs or a warrant in hand this close is noticed
#define BOUNTY_MEEK_NOTICE_RANGE 6
/// Someone running straight at them this close is noticed
#define BOUNTY_MEEK_RUSH_RANGE 4
/// How far they look for a hiding place, once per flight
#define BOUNTY_MEEK_HIDE_RADIUS 10
/// Dark tiles sampled per flight
#define BOUNTY_MEEK_DARK_SAMPLES 24
/// A tile is dark below this light level
#define BOUNTY_MEEK_DARK_LUMCOUNT 0.2
/// Their alpha while standing still in the dark
#define BOUNTY_MEEK_DARK_ALPHA 180
/// First restless tell after this long hidden
#define BOUNTY_MEEK_RESTLESS_AFTER (90 SECONDS)
/// Then one this often
#define BOUNTY_MEEK_RESTLESS_GAP (20 SECONDS)
/// Heard this far away
#define BOUNTY_MEEK_RESTLESS_RANGE 7
/// With nobody near for this long, they come out of hiding and carry on
#define BOUNTY_MEEK_COME_OUT_AFTER (3 MINUTES)
/// Out of sight this long, they stop running and calm down
#define BOUNTY_MEEK_CALM_AFTER (20 SECONDS)
/// Cornered means the hunter is at most this close
#define BOUNTY_MEEK_CORNER_RANGE 3
/// Running away failed this recently: still cornered (longer than a failed plan's 1.5 s pause)
#define BOUNTY_MEEK_RUN_FAIL_WINDOW (2 SECONDS)
/// Cornered this long before the gun comes out
#define BOUNTY_MEEK_CORNERED_TIME (0.8 SECONDS)
/// The aim before the shots: the telegraph
#define BOUNTY_MEEK_PISTOL_WINDUP (0.5 SECONDS)
/// Shots in the holdout's volley, a magazine at most
#define BOUNTY_MEEK_PISTOL_SHOTS 8
/// Between them
#define BOUNTY_MEEK_PISTOL_GAP (0.2 SECONDS)
/// One volley per cornering
#define BOUNTY_MEEK_PISTOL_COOLDOWN (6 SECONDS)
/// They only aim at someone this close
#define BOUNTY_MEEK_PISTOL_RANGE 6
/// Hiding place scores: what kind of place
#define BOUNTY_HIDE_SCORE_LOCKER 3
#define BOUNTY_HIDE_SCORE_PLANT 2
#define BOUNTY_HIDE_SCORE_CRATE 1
#define BOUNTY_HIDE_SCORE_DARK 0
/// A moth likes the dark (spec section 2: flies from bright light)
#define BOUNTY_HIDE_SCORE_MOTH_DARK 4
/// A place the hunter can't see from where they stand
#define BOUNTY_HIDE_SCORE_UNSEEN 8

// ===== NORMAL (combat.md 6.2, spec C7) =====

/// Speed in a fight, by style
#define BOUNTY_NORMAL_SPEED_MELEE 1.25
#define BOUNTY_NORMAL_SPEED_RANGED 1.4
/// Noticed at this range (someone armed, cuffs or a warrant in hand)
#define BOUNTY_NORMAL_NOTICE_RANGE 6
/// Someone with a weapon drawn this close, while they are aware of them, starts the fight
#define BOUNTY_NORMAL_THREAT_RANGE 6
/// Aware, but the person has been out of sight this long: back to what they were doing
#define BOUNTY_NORMAL_AWARE_FORGET (15 SECONDS)
/// Fighting, but nobody on the grudge list seen for this long: the fight is over
#define BOUNTY_NORMAL_CALM_AFTER (30 SECONDS)
/// Share of max health at or below which they may give up
#define BOUNTY_SURRENDER_BELOW 0.4
/// Percent chance on the hit that crosses the line
#define BOUNTY_SURRENDER_CHANCE 60
/// Less for each companion still standing
#define BOUNTY_SURRENDER_PER_COMPANION 20
/// Percent chance on later hits
#define BOUNTY_SURRENDER_RETRY 25
/// At most this often
#define BOUNTY_SURRENDER_RETRY_GAP (5 SECONDS)
/// Hunters needed around them
#define BOUNTY_SURRENDER_HUNTERS 2
/// Within this range, in view
#define BOUNTY_SURRENDER_HUNTER_RANGE 7
/// Below this share of health with no hunter near, they break off and retreat. The spec's 25% is the
/// downed line, so a standing criminal is never below it; the surrender line is used instead.
#define BOUNTY_NORMAL_RETREAT_BELOW 0.4
/// How far they try to get away when retreating
#define BOUNTY_NORMAL_RETREAT_DISTANCE 10

// ===== COMPANIONS (combat.md 6.2, spec C7) =====

#define BOUNTY_COMPANIONS_MIN 0
#define BOUNTY_COMPANIONS_MAX 2
/// Health before the style's multiplier
#define BOUNTY_COMPANION_HEALTH 110
/// Below this share of health a companion may run (a BOUNTY_COMPANION_FLEE_CHANCE roll, once)
#define BOUNTY_COMPANION_FLEE_BELOW 0.3
#define BOUNTY_COMPANION_FLEE_CHANCE 50
/// How far a companion keeps from its criminal while nothing is happening
#define BOUNTY_COMPANION_FOLLOW 2
/// How often a companion calls the rest of the gang in (the trooper's 30 s)
#define BOUNTY_REINFORCE_COOLDOWN (30 SECONDS)

// ===== STYLES (combat.md 6.2) =====
// Every blow and shot is the real weapon's (bounty_weapons.dm): the item in their hand is each
// style's held_look, and a Wanted criminal carries its heavy_look where it has one.

#define BOUNTY_BRAWLER_HEALTH 1.2
#define BOUNTY_BRAWLER_STAMINA 0.8
#define BOUNTY_BRAWLER_INTERVAL (1 SECONDS)
/// Chance a punch shoves the target back a tile and staggers them for a second
#define BOUNTY_BRAWLER_SHOVE_CHANCE 20
#define BOUNTY_BRAWLER_STAGGER (1 SECONDS)

#define BOUNTY_KNIFE_HEALTH 1
#define BOUNTY_KNIFE_INTERVAL (0.8 SECONDS)

#define BOUNTY_PISTOL_HEALTH 0.9
#define BOUNTY_PISTOL_INTERVAL (0.25 SECONDS)
/// Keeps about this far away
#define BOUNTY_PISTOL_RANGE 5
#define BOUNTY_PISTOL_MIN_RANGE 3
/// The reload: the window to close in
#define BOUNTY_PISTOL_RELOAD (2 SECONDS)
/// Raising the gun before the first shot of a string
#define BOUNTY_PISTOL_WINDUP (0.2 SECONDS)
/// Shots further apart than this start a new string
#define BOUNTY_PISTOL_STRING_GAP (3 SECONDS)

#define BOUNTY_SHOTGUN_HEALTH 1
#define BOUNTY_SHOTGUN_INTERVAL (1.2 SECONDS)
#define BOUNTY_SHOTGUN_RANGE 2
/// The pump before each blast
#define BOUNTY_SHOTGUN_WINDUP (0.3 SECONDS)
/// Loading the tube again: the window to close in
#define BOUNTY_SHOTGUN_RELOAD (3 SECONDS)

#define BOUNTY_CLUB_HEALTH 1.1
#define BOUNTY_CLUB_INTERVAL (1.1 SECONDS)

#define BOUNTY_BOTTLE_HEALTH 0.9
#define BOUNTY_BOTTLE_INTERVAL (1.2 SECONDS)
#define BOUNTY_BOTTLE_RANGE 4
#define BOUNTY_BOTTLE_MIN_RANGE 2
/// Tiles a bottle flies
#define BOUNTY_BOTTLE_REACH 6
/// The throwing arc before each throw
#define BOUNTY_BOTTLE_WINDUP (0.3 SECONDS)
