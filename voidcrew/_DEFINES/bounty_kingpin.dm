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

/// Brute and burn he takes, as a multiple of a person's (the human NPC base's npc_damage_taken, boss rank). His armoured coat does the rest.
#define BOUNTY_KINGPIN_DAMAGE_TAKEN 0.6
/// At or below this percent of his health, with his crew down and a hunter in sight, he may give up
#define BOUNTY_KINGPIN_SURRENDER_BELOW 40
/// Percent chance on his first roll, and on each later one
#define BOUNTY_KINGPIN_SURRENDER_FIRST 60
#define BOUNTY_KINGPIN_SURRENDER_LATER 25
/// At most one surrender roll per this
#define BOUNTY_KINGPIN_SURRENDER_GAP (5 SECONDS)

// ===== HIS REVOLVER =====

/// The revolver he carries in his holster: a real .357, drawn when the guns come out
#define BOUNTY_KINGPIN_REVOLVER /obj/item/gun/ballistic/revolver
/// His spare rounds: real .357 speedloaders, two in the holster and one in a pocket
#define BOUNTY_KINGPIN_SPEEDLOADER /obj/item/ammo_box/a357
/// The aim line before each shot; he never fires without it
#define BOUNTY_KINGPIN_REVOLVER_AIM (0.5 SECONDS)
/// From one aim to the next
#define BOUNTY_KINGPIN_REVOLVER_COOLDOWN (1.2 SECONDS)

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
#define BOUNTY_GOON_WEAPON_PISTOL "pistol"
#define BOUNTY_GOON_WEAPON_SMG "smg"
#define BOUNTY_GOON_WEAPON_SHOTGUN "shotgun"

/// The real guns the goons carry, and their real spares
#define BOUNTY_GOON_PISTOL_GUN /obj/item/gun/ballistic/automatic/pistol/aps
#define BOUNTY_GOON_PISTOL_MAG /obj/item/ammo_box/magazine/m9mm_aps
#define BOUNTY_GOON_SMG_GUN /obj/item/gun/ballistic/automatic/mini_uzi
#define BOUNTY_GOON_SMG_MAG /obj/item/ammo_box/magazine/uzim9mm
/// The combat shotgun, its tube loaded with buckshot (bounty_kingpin.dm)
#define BOUNTY_GOON_SHOTGUN_GUN /obj/item/gun/ballistic/shotgun/automatic/combat/bounty_kingpin
/// What the shotguns are loaded with, and the loose shells a shotgun goon carries in his bandolier
#define BOUNTY_GOON_SHOTGUN_AMMO /obj/item/ammo_casing/shotgun/buckshot
#define BOUNTY_GOON_SHOTGUN_SHELLS 8

/// Between two trigger pulls of a goon's pistol: the Stechkin set to single shots with its own selector, in strings of
/// BOUNTY_PISTOL_STRING_SHOTS with BOUNTY_PISTOL_STRING_PAUSE on top between them, as every bounty pistol fires
#define BOUNTY_GOON_PISTOL_COOLDOWN (0.5 SECONDS)

/// Trigger pulls in a burst (each pull is the Uzi's own two-round burst), and the gap between them
#define BOUNTY_GOON_SMG_BURST 2
#define BOUNTY_GOON_SMG_BURST_GAP (0.3 SECONDS)
/// The spin-up: the gun comes up level, with a sound
#define BOUNTY_GOON_SMG_WINDUP (0.3 SECONDS)
#define BOUNTY_GOON_SMG_COOLDOWN (1 SECONDS)

/// Tiles: he walks in to this before he fires
#define BOUNTY_GOON_SHOTGUN_RANGE 2
/// The pump before each blast
#define BOUNTY_GOON_SHOTGUN_WINDUP (0.3 SECONDS)
#define BOUNTY_GOON_SHOTGUN_COOLDOWN (1.2 SECONDS)

/// Tiles from the sofa a goon ever walks while his crew holds the lounge
#define BOUNTY_GOON_LEASH 7
/// Percent of the goons left who run when he falls (in crit, cuffed, given up or dead)
#define BOUNTY_GOON_FLEE_ON_BOSS 50
/// The quickest a goon takes a step in a fight; his own body's slowdown (wounds, armour) can make it slower
#define BOUNTY_GOON_STEP (0.35 SECONDS)
/// A reload by hand gives up after this: a tube is fed a shell at a time
#define BOUNTY_KINGPIN_RELOAD_GIVE_UP (15 SECONDS)
/// Blackboard key on him and his goons: their guns are out (the crew is drawing or fighting), so a spent gun is reloaded
#define BB_BOUNTY_KINGPIN_ARMED "bounty_kingpin_armed"

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
/// Wanted dead or alive: alive pays in full however he is brought in (cuffed, stunned or in crit); dead pays 80%
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
