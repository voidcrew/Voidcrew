// # Bounty hunting: the kingpin's defines
//
// Owner: P9 kingpin (voidcrew/modules/bounties/bounty_kingpin.dm). Only P9 edits this file. The
// shared enums are in bounties.dm. Numbers from spec sections 13 and 15, balance/kingpin.md
// (section 6) and balance/economy_v2.md (section 7).
//
// Unit tests compile before this file: a test uses the literal value with the define named beside it.

// ===== WHO HE IS =====

/// The kingpin's archetype on his record (spec 13). He is his own kind: not meek, normal or a mini-boss.
#define BOUNTY_ARCHETYPE_KINGPIN "kingpin"
/// His placement: the corp sofa in the black market's lounge, from the start of the round, never anywhere else
#define BOUNTY_PLACEMENT_KINGPIN "kingpin_lounge"
/// Trait source for everything the kingpin's crew puts on a mob
#define BOUNTY_KINGPIN_TRAIT "bounty_kingpin"
/// The faction his goons share; they also carry FACTION_TURRET, so the outpost turrets leave them alone
#define FACTION_BOUNTY_KINGPIN "bounty_kingpin"

/// His dialogue file, and where it lives
#define BOUNTY_KINGPIN_STRINGS_FILE "bounty_kingpin.json"
#define BOUNTY_KINGPIN_STRINGS_DIR "voidcrew/modules/bounties/strings"

// ===== HIS BODY =====

#define BOUNTY_KINGPIN_HEALTH 200
/// Stamina damage that stamcrits him: 5 disabler hits in 10 seconds, or 3 baton hits
#define BOUNTY_KINGPIN_STAMINA 150
/// Downed to up, uncuffed (the 10 s stirring tell is P2's, inside this)
#define BOUNTY_KINGPIN_RECOVERY (60 SECONDS)
/// After he gets up: stamina does nothing to him and he won't surrender (combat.md 5.6)
#define BOUNTY_KINGPIN_RALLY (20 SECONDS)
/// Below this percent of his health, with his crew down, he may surrender
#define BOUNTY_KINGPIN_SURRENDER_BELOW 40
/// Percent chance on the hit that crosses the line, and on each later hit
#define BOUNTY_KINGPIN_SURRENDER_FIRST 60
#define BOUNTY_KINGPIN_SURRENDER_LATER 25
/// At most one surrender roll per this
#define BOUNTY_KINGPIN_SURRENDER_GAP (5 SECONDS)

// ===== HIS REVOLVER =====

/// The revolver in his hand: its look, its rounds and its cylinder (bounty_real_weapon())
#define BOUNTY_KINGPIN_REVOLVER /obj/item/gun/ballistic/revolver
/// The aim line before each shot; he never fires without it
#define BOUNTY_KINGPIN_REVOLVER_AIM (0.5 SECONDS)
/// From one aim to the next
#define BOUNTY_KINGPIN_REVOLVER_COOLDOWN (1.2 SECONDS)
#define BOUNTY_KINGPIN_REVOLVER_RELOAD (3 SECONDS)

// ===== THE SHOOTOUT =====

/// "The goons reach for their guns": nobody in his crew fires in it
#define BOUNTY_KINGPIN_TELEGRAPH (0.6 SECONDS)
/// The goons' first shots are spread over this, after the telegraph
#define BOUNTY_KINGPIN_FIRST_SHOT_SPREAD (0.5 SECONDS)
/// A goon hit while drawing or winding up
#define BOUNTY_KINGPIN_FUMBLE (1 SECONDS)
/// Goons that may draw on one hunter at once, in the opening volley and whenever that hunter is in cover
#define BOUNTY_KINGPIN_MAX_ON_ONE 2
/// With no hunter in sight of anyone in his crew for this long, the crew stands down
#define BOUNTY_KINGPIN_STAND_DOWN (45 SECONDS)
/// A hunter's stray shot counts as part of the fight (no outpost strike) this long after they last fired at or hit his crew
#define BOUNTY_KINGPIN_EXCUSE_WINDOW (3 SECONDS)
/// Dragged further than this from his sofa, or onto another level, he is put back on it rather than walking
#define BOUNTY_KINGPIN_WALK_HOME_MAX 30
/// Between two tries at walking home
#define BOUNTY_KINGPIN_WALK_HOME_GAP (10 SECONDS)
/// Between two of his warnings about the furniture
#define BOUNTY_KINGPIN_TABLE_WARN_GAP (30 SECONDS)
/// How far his crew sees and shoots
#define BOUNTY_KINGPIN_SIGHT 9

// ===== THE GOONS =====

/// A fixed crew of six (kingpin.md 3.4), one per map post
#define BOUNTY_KINGPIN_GOONS 6
#define BOUNTY_GOON_HEALTH 150
/// A goon's stamina pool, the way P2 sets a criminal's: max_stamina 100, with a coefficient of 100 / BOUNTY_GOON_HEALTH, so 5 disabler hits stamcrit him. tg's basic mobs compare raw points with this percentage when the crit ends, so it must be 100.
#define BOUNTY_GOON_MAX_STAMINA 100
/// Percent of it that stamcrits him. Just under 100, for float rounding.
#define BOUNTY_GOON_STAMCRIT_AT 99.9
#define BOUNTY_GOON_WEAPON_PISTOL "pistol"
#define BOUNTY_GOON_WEAPON_SMG "smg"
#define BOUNTY_GOON_WEAPON_SHOTGUN "shotgun"

/// The guns in the goons' hands: their looks, their rounds and their magazines (bounty_real_weapon())
#define BOUNTY_GOON_PISTOL_GUN /obj/item/gun/ballistic/automatic/pistol/aps
#define BOUNTY_GOON_SMG_GUN /obj/item/gun/ballistic/automatic/mini_uzi
#define BOUNTY_GOON_SHOTGUN_GUN /obj/item/gun/ballistic/shotgun/automatic/combat
/// What the shotguns are loaded with
#define BOUNTY_GOON_SHOTGUN_AMMO /obj/item/ammo_casing/shotgun/buckshot

#define BOUNTY_GOON_PISTOL_COOLDOWN (0.3 SECONDS)
#define BOUNTY_GOON_PISTOL_RELOAD (2 SECONDS)

/// Shots in a burst, and the gap between them
#define BOUNTY_GOON_SMG_BURST 5
#define BOUNTY_GOON_SMG_BURST_GAP (0.1 SECONDS)
/// The spin-up: the gun comes up level, with a sound
#define BOUNTY_GOON_SMG_WINDUP (0.3 SECONDS)
#define BOUNTY_GOON_SMG_COOLDOWN (1 SECONDS)
#define BOUNTY_GOON_SMG_RELOAD (2.5 SECONDS)

/// Tiles: he walks in to this before he fires
#define BOUNTY_GOON_SHOTGUN_RANGE 2
/// The pump before each blast
#define BOUNTY_GOON_SHOTGUN_WINDUP (0.3 SECONDS)
#define BOUNTY_GOON_SHOTGUN_COOLDOWN (1.2 SECONDS)
#define BOUNTY_GOON_SHOTGUN_RELOAD (3 SECONDS)

/// Tiles from the sofa a goon ever walks
#define BOUNTY_GOON_LEASH 7
/// Percent of the goons left who flee when he falls (downed, cuffed, surrendered or dead)
#define BOUNTY_GOON_FLEE_ON_BOSS 50
/// A fleeing goon is gone after this
#define BOUNTY_GOON_FLEE_TIME (6 SECONDS)
/// A goon's body fades after this (the outpost never unloads)
#define BOUNTY_GOON_FADE (60 SECONDS)
/// How long a goon's body takes to fade, and a leaving goon to walk out
#define BOUNTY_GOON_FADE_OUT (2 SECONDS)
#define BOUNTY_GOON_LEAVE_TIME (5 SECONDS)
/// Between a goon's steps in a fight
#define BOUNTY_GOON_STEP (0.35 SECONDS)

// ===== TALKING =====

/// Tiles: he talks across the coffee table
#define BOUNTY_KINGPIN_TALK_RANGE 2
/// His talk radial's options; the text is also what the radial shows
#define BOUNTY_KINGPIN_TALK_HERE "We're here for you."
#define BOUNTY_KINGPIN_TALK_WORK "Got any work?"
#define BOUNTY_KINGPIN_TALK_TAKE_JOB "I'll take it."
#define BOUNTY_KINGPIN_TALK_WALK "Walk away."

// ===== HIS BUSINESS =====

/// The job he gives out (the only place it is given out): a Drug Run, fenced at Vex's counter
#define BOUNTY_KINGPIN_JOB /datum/mission/drug_run
/// A crew he has offered his job may take it for this long
#define BOUNTY_KINGPIN_OFFER_TIME (3 MINUTES)
/// When no job could be made (the round's planets don't fit one), he tries again after this
#define BOUNTY_KINGPIN_JOB_RETRY (5 MINUTES)
/// Between his idle lines, and between a goon's idle actions
#define BOUNTY_KINGPIN_IDLE_MIN (40 SECONDS)
#define BOUNTY_KINGPIN_IDLE_MAX (90 SECONDS)
#define BOUNTY_GOON_IDLE_MIN (12 SECONDS)
#define BOUNTY_GOON_IDLE_MAX (30 SECONDS)
/// He greets the same person at most this often
#define BOUNTY_KINGPIN_GREET_GAP (5 MINUTES)
/// Between two of his lines, unless forced
#define BOUNTY_KINGPIN_SAY_COOLDOWN (4 SECONDS)

// ===== PAY AND THE BOARD =====

/// His band, before the zone multiplier (x2.6 at the black market)
#define BOUNTY_KINGPIN_PAY_MIN 2500
#define BOUNTY_KINGPIN_PAY_MAX 3500
/// Vouchers on a full-share turn-in; red adds BOUNTY_RED_VOUCHER_BONUS
#define BOUNTY_KINGPIN_VOUCHERS 1
/// Wanted dead or alive: restrained, stunned or downed is alive
#define BOUNTY_KINGPIN_PAY_ALIVE 100
#define BOUNTY_KINGPIN_PAY_DEAD 80
/// He goes on the board no earlier than 45 minutes into the round, and only with 3+ active ships
#define BOUNTY_KINGPIN_FIRST (45 MINUTES)
#define BOUNTY_KINGPIN_MIN_SHIPS 3
/// The next posting 60-90 minutes after the last one resolves
#define BOUNTY_KINGPIN_GAP_MIN (60 MINUTES)
#define BOUNTY_KINGPIN_GAP_MAX (90 MINUTES)
/// If he couldn't be posted (not seated yet, say), try again after this
#define BOUNTY_KINGPIN_RETRY (5 MINUTES)
/// On the board for this, paused while a shootout is on
#define BOUNTY_KINGPIN_EXPIRY (60 MINUTES)

// ===== HIS CREW'S STATES =====

/// Idling: talking, drinking, watching the room
#define BOUNTY_KINGPIN_CALM "calm"
/// "The goons reach for their guns": nobody fires
#define BOUNTY_KINGPIN_DRAWING "drawing"
/// The shootout
#define BOUNTY_KINGPIN_FIGHTING "fighting"
