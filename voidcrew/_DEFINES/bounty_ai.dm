// # Bounty hunting: criminal AI defines
//
// Owner: P3 AI (voidcrew/modules/bounties/bounty_ai.dm, bounty_ai_meek.dm, bounty_ai_normal.dm,
// bounty_styles.dm, bounty_activities.dm, bounty_companions.dm). Only P3 edits this file. The shared
// enums are in bounties.dm. Criminals and companions are real human bodies (voidcrew/modules/human_npcs/):
// nothing here sets health, stamina or speed. A pace is only a walk or a run (ai_set_pace()).

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
/// Holding up a potted plant (tg's own disguise: the plant's tactical component)
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
/// world.time the current wind-up ends
#define BB_BOUNTY_WINDUP_UNTIL "bb_bounty_windup_until"
/// world.time the current wind-up began
#define BB_BOUNTY_WINDUP_FROM "bb_bounty_windup_from"
/// Their stamina loss when the wind-up began: more by the end of it and they fumble
#define BB_BOUNTY_WINDUP_STAMINA "bb_bounty_windup_stamina"
/// world.time they last took a hit
#define BB_BOUNTY_HIT_AT "bb_bounty_hit_at"
/// world.time of the last shot or throw
#define BB_BOUNTY_LAST_SHOT "bb_bounty_last_shot"
/// world.time they may next pull the trigger or throw
#define BB_BOUNTY_NEXT_SHOT "bb_bounty_next_shot"
/// world.time a ranged fighter may next step back from someone too close
#define BB_BOUNTY_BACKSTEP_AT "bb_bounty_backstep_at"
/// Trigger pulls still to come in the burst under way (a burst is that many separate pulls, bounty_styles.dm)
#define BB_BOUNTY_BURST_LEFT "bb_bounty_burst_left"
/// world.time their style's gun last came out of its holster, off their back or out of a bag (the draw)
#define BB_BOUNTY_DRAWN_AT "bb_bounty_drawn_at"
/// Shots fired in the pistol's current string, and the magazine they came from (a new one starts the count again)
#define BB_BOUNTY_STRING_SHOTS "bb_bounty_string_shots"
#define BB_BOUNTY_STRING_MAGAZINE "bb_bounty_string_magazine"
/// world.time the body may take its next step by hand (bounty_ai_step()): its last step, AI walk or by hand, plus its own move delay
#define BB_BOUNTY_NEXT_STEP_AT "bb_bounty_next_step_at"

// ===== ACTIVITY STEPS =====

/// The activity carries on where they are
#define BOUNTY_STEP_CONTINUE 0
/// The activity set a new spot to walk to
#define BOUNTY_STEP_MOVE 1
/// The activity is over; a new one of the same kind is set up
#define BOUNTY_STEP_DONE 2

// ===== SHARED =====

/// The pace while going about their business, and while blended in (the fugitive and every decoy walk
/// alike). Anything quicker than this is a run (ai_set_pace()).
#define BOUNTY_CALM_SPEED 2.5
/// The pace of anyone running: running, as a person runs. There is no faster sprint.
#define BOUNTY_RUN_SPEED 1.5
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
/// Glasses a criminal leaves about at the bar (on a table or the floor) before a finished glass just goes
#define BOUNTY_BAR_GLASSES_MAX 2
/// Drunk this much (tg's drunkenness), they nurse their drink instead of drinking it
#define BOUNTY_BAR_SOBER_LIMIT 30
/// Spots an activity remembers as out of reach
#define BOUNTY_FAILED_SPOTS_MAX 8
/// How long a trader outpost's public floor is reused between its patrons before it is worked out again
#define BOUNTY_OUTPOST_FLOOR_CACHE (1 MINUTES)
/// A wind-up left this long past its end is stale: the next shot telegraphs again
#define BOUNTY_WINDUP_STALE (1 SECONDS)
/// After a fumble, this long before they try again
#define BOUNTY_FUMBLE_PAUSE (1 SECONDS)

// ===== MEEK (combat.md 6.1, spec C6) =====

/// Stamina loss at which tg's own slowdown starts (human updatehealth(): 40): they are winded
#define BOUNTY_MEEK_WINDED_STAMINA 40
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
/// Trigger pulls in the holdout's volley, a magazine at most
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

/// Noticed at this range (someone armed, cuffs or a warrant in hand)
#define BOUNTY_NORMAL_NOTICE_RANGE 6
/// Someone with a weapon drawn this close, while they are aware of them, starts the fight
#define BOUNTY_NORMAL_THREAT_RANGE 6
/// Aware, but the person has been out of sight this long: back to what they were doing
#define BOUNTY_NORMAL_AWARE_FORGET (15 SECONDS)
/// Fighting, but nobody on the grudge list seen for this long: the fight is over
#define BOUNTY_NORMAL_CALM_AFTER (30 SECONDS)
/// Surrender (defaults CR-10, /datum/human_npc_surrender/bounty): at or below this share of health,
#define BOUNTY_SURRENDER_BELOW 0.4
/// a percent chance on the first roll of a fight,
#define BOUNTY_SURRENDER_CHANCE 60
/// less this for each companion still standing,
#define BOUNTY_SURRENDER_PER_COMPANION 20
/// then this on later rolls,
#define BOUNTY_SURRENDER_RETRY 25
/// at most this often,
#define BOUNTY_SURRENDER_RETRY_GAP (5 SECONDS)
/// with this many hunters around them,
#define BOUNTY_SURRENDER_HUNTERS 2
/// within this range, in view
#define BOUNTY_SURRENDER_HUNTER_RANGE 7
/// Below this share of health with no hunter near, they break off and retreat
#define BOUNTY_NORMAL_RETREAT_BELOW 0.4
/// How far they try to get away when retreating
#define BOUNTY_NORMAL_RETREAT_DISTANCE 10

// ===== COMPANIONS (combat.md 6.2, spec C7) =====

#define BOUNTY_COMPANIONS_MIN 0
#define BOUNTY_COMPANIONS_MAX 2
/// Below this share of health a companion may run (a BOUNTY_COMPANION_FLEE_CHANCE roll, once)
#define BOUNTY_COMPANION_FLEE_BELOW 0.3
#define BOUNTY_COMPANION_FLEE_CHANCE 50
/// Up from a stamina crit with hunters around: the chance a companion gives up rather than runs
#define BOUNTY_COMPANION_GIVE_UP_CHANCE 50
/// How far a companion keeps from its criminal while nothing is happening
#define BOUNTY_COMPANION_FOLLOW 2
/// How often a companion calls the rest of the gang in (the trooper's 30 s)
#define BOUNTY_REINFORCE_COOLDOWN (30 SECONDS)
/// A companion joining a fight gets up first: no weapon out, no blow or shot, for this long, so their criminal draws first
#define BOUNTY_COMPANION_DRAW_DELAY (1 SECONDS)
/// A companion's gun is backup: pistol strings this long (a criminal's are BOUNTY_PISTOL_STRING_SHOTS)...
#define BOUNTY_COMPANION_PISTOL_STRING 3
/// ...and SMG bursts this long (a criminal's are BOUNTY_SMG_BURST)
#define BOUNTY_COMPANION_SMG_BURST 2
/// Company keys (bounty_roll_company()): one companion's fighting style (BOUNTY_STYLE_*)...
#define BOUNTY_COMPANY_STYLE "style"
/// ...and their chrome keys (BOUNTY_CHROME_*), or null for none
#define BOUNTY_COMPANY_CHROME "chrome"

// ===== STYLES (combat.md 6.2, bounty_styles.dm) =====
// Every style is a real item the fighter carries and draws: blows and shots are the item's own, through
// the fighter's hands. These only set the timing: how often they pull the trigger or throw, the
// telegraph, and the distance they keep.

/// Chance a brawler's blow is a real shove instead of a punch
#define BOUNTY_BRAWLER_SHOVE_CHANCE 20

/// Getting a holstered or slung gun out at the start of a fight: the line, then at least this long before the first shot
#define BOUNTY_DRAW_TIME (0.6 SECONDS)
/// A burst whose next pull is this late was cut off (the AI stopped meanwhile): what is left of it never fires
#define BOUNTY_BURST_STALE (0.5 SECONDS)

/// Between trigger pulls: the Stechkin set to single shots with its own fire selector, twice a second
#define BOUNTY_PISTOL_INTERVAL (0.5 SECONDS)
/// Every bounty pistol (criminals, companions, the kingpin's goons, Club Volga's mobsters and the don) fires strings of this many shots...
#define BOUNTY_PISTOL_STRING_SHOTS 6
/// ...with this pause on top of the interval before the next string. A reload after an empty magazine is separate.
#define BOUNTY_PISTOL_STRING_PAUSE (1.5 SECONDS)
/// A gun fires at anyone it can see this far off, while its holder still walks in to its style's own distance (BOUNTY_PISTOL_RANGE). The shotgun's spread and the bottle's throw keep them to their own.
#define BOUNTY_GUN_FIRE_RANGE 7
/// Walks in to about this far away
#define BOUNTY_PISTOL_RANGE 5
#define BOUNTY_PISTOL_MIN_RANGE 3
/// Raising the gun before the first shot of a string
#define BOUNTY_PISTOL_WINDUP (0.2 SECONDS)
/// Shots further apart than this start a new string
#define BOUNTY_PISTOL_STRING_GAP (3 SECONDS)

/// The WT-550 at every tier: a burst is this many trigger pulls...
#define BOUNTY_SMG_BURST 4
/// ...this far apart, the gun's own full-auto rate
#define BOUNTY_SMG_BURST_GAP (0.3 SECONDS)
/// From a burst's last round to the next burst's spin-up
#define BOUNTY_SMG_INTERVAL (0.5 SECONDS)
/// The gun brought up level before each burst
#define BOUNTY_SMG_WINDUP (0.3 SECONDS)
#define BOUNTY_SMG_MIN_RANGE 2

/// A .38 revolver: one heavy shot a second, six in the cylinder, a speedloader to reload
#define BOUNTY_REVOLVER_INTERVAL (1 SECONDS)
#define BOUNTY_REVOLVER_MIN_RANGE 3
/// The hammer thumbed back before the first shot of a string
#define BOUNTY_REVOLVER_WINDUP (0.3 SECONDS)

#define BOUNTY_SHOTGUN_INTERVAL (1.2 SECONDS)
#define BOUNTY_SHOTGUN_RANGE 2
/// The pump before each blast
#define BOUNTY_SHOTGUN_WINDUP (0.3 SECONDS)
/// Spare shells on the bandolier
#define BOUNTY_SHOTGUN_SHELLS 8

#define BOUNTY_BOTTLE_INTERVAL (1.2 SECONDS)
#define BOUNTY_BOTTLE_RANGE 4
#define BOUNTY_BOTTLE_MIN_RANGE 2
/// The throwing arc before each throw
#define BOUNTY_BOTTLE_WINDUP (0.3 SECONDS)
/// Bottles in the bag, by tier: Petty, and above
#define BOUNTY_BOTTLES_PETTY 4
#define BOUNTY_BOTTLES_WANTED 6
