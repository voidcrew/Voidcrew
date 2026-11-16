// # Bounty hunting: mini-boss defines
//
// Owner: P4 bosses (voidcrew/modules/bounties/bounty_boss.dm, bounty_boss_kits.dm). Only P4 edits
// this file. The shared enums are in bounties.dm. The ability numbers are the combat balance review's
// (balance/combat.md section 6.3, folded into spec.md 12.3 C8). A number marked (P4) is not in the
// review and was picked by P4; one marked (phase D) came with the move to real human bodies and is a
// starting value for the balance pass (defaults 1.16).
//
// A boss is a real human (voidcrew/modules/human_npcs/): its health, stamina and stuns are tg's. There
// are no health tables, stamina pools or damage coefficients here, and there must never be.

// ===== COMMON RULES =====

/// Brute and burn a boss takes, as a multiple of a person's, through its physiology (npc_damage_taken, defaults 1.5). Its armour does the rest. (phase D)
#define BOUNTY_BOSS_DAMAGE_TAKEN 0.6
/// Its combat stimulant: one at the start of a fight, a second for its second wind (defaults 1.6, CR-4). Ephedrine: baton resistance, speed and quicker recovery from stuns, never immunity, so a crew can still stun and cuff a worn-out boss. (phase D)
#define BOUNTY_BOSS_STIMULANT /obj/item/reagent_containers/hypospray/medipen/stimpack
/// How many of BOUNTY_BOSS_STIMULANT it carries. (phase D)
#define BOUNTY_BOSS_STIMULANTS 2
/// Worn out: stamina loss over this share of its max stamina... (phase D, CB-2)
#define BOUNTY_BOSS_WORN_OUT_STAMINA 0.5
/// ...or health under this share of its max health. (phase D, CB-2)
#define BOUNTY_BOSS_WORN_OUT_HEALTH 0.4
/// Worn out, it falls back from its target this long before its second wind. (phase D)
#define BOUNTY_BOSS_FALLBACK_TIME (8 SECONDS)
/// Below this pressure (kPa) on either side, a wall, window or door is not interior (P4)
#define BOUNTY_BOSS_INTERIOR_MIN_PRESSURE 20
/// More than this pressure difference (kPa) between its sides, and a wall, window or door is not interior (P4)
#define BOUNTY_BOSS_INTERIOR_MAX_PRESSURE_GAP 50
/// Pause after one ability before the next may start, so telegraphs never overlap
#define BOUNTY_BOSS_ABILITY_GAP_MIN (1 SECONDS)
#define BOUNTY_BOSS_ABILITY_GAP_MAX (2 SECONDS)
/// FALSE (set by the coordinator, matching the balance sim): skip the last ability only while another is ready, so a kit's main ability can repeat when its other one is on cooldown or not worth using. TRUE: never the same ability twice in a row, even when it is the only one ready (the hoarfrost rotation).
#define BOUNTY_BOSS_STRICT_ROTATION FALSE
/// Interior walls and doors one boss may break in its fight, all abilities together
#define BOUNTY_BOSS_WALL_BUDGET 2
/// Structures (tables, chairs, windows, grilles, doors, walls) one use of an ability may damage (P4)
#define BOUNTY_BOSS_ABILITY_STRUCTURE_CAP 4
/// Players within this many tiles who can see a boss when it turns hostile join its posse
#define BOUNTY_BOSS_POSSE_RANGE 9
/// How far a hostile boss looks for hunters on its site once it has lost sight of everyone (P4)
#define BOUNTY_BOSS_HUNT_RANGE 30
/// How often a hunting boss looks again for the nearest hunter (P4)
#define BOUNTY_BOSS_HUNT_INTERVAL (2 SECONDS)
/// A hostile boss that finds no hunter on its site for this long calms down and waits again (P4)
#define BOUNTY_BOSS_CALM_TIME (60 SECONDS)
/// A hunter who hit the boss this recently is its first choice of target (P4)
#define BOUNTY_BOSS_REVENGE_TIME (10 SECONDS)

// ===== THE POSSE (OC-8): ONE MORE COMPANION PER EXTRA HUNTER =====

/// Most companions a posse brings in for one boss (four or more hunters). (phase D)
#define BOUNTY_BOSS_REINFORCEMENTS_MAX 3
/// Time between two companions coming in, and between tries to find a spot out of view. (phase D)
#define BOUNTY_BOSS_REINFORCE_DELAY (6 SECONDS)
/// A companion comes in at least this far from the boss... (phase D)
#define BOUNTY_BOSS_REINFORCE_MIN_DIST 5
/// ...and no further than this. (phase D)
#define BOUNTY_BOSS_REINFORCE_MAX_DIST 14
/// A spot any player within this many tiles can see is in view. (phase D)
#define BOUNTY_BOSS_REINFORCE_SIGHT 13

// ===== SUMMONED THINGS: CAPS AND LIFETIMES (P4) =====

/// Fire pools (flamer floors and molotovs) burning at once, server-wide
#define BOUNTY_BOSS_FIRE_POOL_CAP 16
/// Grenades and breaching charges live at once, server-wide
#define BOUNTY_BOSS_EXPLOSIVE_CAP 16
/// Heavy barricades standing at once, server-wide
#define BOUNTY_BOSS_BARRICADE_CAP 8
/// Heavy barricades one boss keeps standing; a new one folds up its oldest
#define BOUNTY_BOSS_BARRICADES_PER_BOSS 2
/// How long a Heavy barricade stands before it folds away
#define BOUNTY_BOSS_BARRICADE_LIFE (90 SECONDS)
/// Fire stacks (tg's) a boss's burning floor adds every second to anyone standing in it. (phase D, CB-8)
#define BOUNTY_BOSS_FIRE_TICK_STACKS 1

// ===== JUGGERNAUT =====

/// Charge: a roar, a stamp and a cracked-floor line
#define BOUNTY_JUGGERNAUT_CHARGE_WINDUP (0.8 SECONDS)
#define BOUNTY_JUGGERNAUT_CHARGE_COOLDOWN (8 SECONDS)
/// Tiles it charges, at most
#define BOUNTY_JUGGERNAUT_CHARGE_RANGE 7
/// Time per tile of the charge (P4)
#define BOUNTY_JUGGERNAUT_CHARGE_STEP 1
#define BOUNTY_JUGGERNAUT_CHARGE_DAMAGE 25
#define BOUNTY_JUGGERNAUT_CHARGE_KNOCKDOWN (2 SECONDS)
/// Armour penetration of the charge
#define BOUNTY_JUGGERNAUT_CHARGE_AP 15
/// Percent chance that someone else in the way is caught too
#define BOUNTY_JUGGERNAUT_CHARGE_BYSTANDER 25
/// Charged into something it can't break: brute to its head through its helmet, stamina, a moment's paralysis and a knockdown, as tg's tackle splat does (CB-6). (phase D)
#define BOUNTY_JUGGERNAUT_WALL_BRUTE 15
#define BOUNTY_JUGGERNAUT_WALL_STAMINA 30
#define BOUNTY_JUGGERNAUT_WALL_PARALYZE (1 SECONDS)
#define BOUNTY_JUGGERNAUT_WALL_KNOCKDOWN (3 SECONDS)
/// Slam: both fists up, a red ring
#define BOUNTY_JUGGERNAUT_SLAM_WINDUP (0.7 SECONDS)
#define BOUNTY_JUGGERNAUT_SLAM_COOLDOWN (7 SECONDS)
#define BOUNTY_JUGGERNAUT_SLAM_DAMAGE 20
#define BOUNTY_JUGGERNAUT_SLAM_KNOCKDOWN (1.5 SECONDS)

// ===== PYROMANIAC =====

/// Its torch: lit, and it never goes out (a real tg torch, held from the start: it doesn't holster)
#define BOUNTY_PYROMANIAC_TORCH /obj/item/flashlight/flare/torch/everburning
/// Flamer: a pilot light hiss, an orange cone
#define BOUNTY_PYROMANIAC_FLAMER_WINDUP (0.5 SECONDS)
#define BOUNTY_PYROMANIAC_FLAMER_COOLDOWN (5 SECONDS)
#define BOUNTY_PYROMANIAC_FLAMER_RANGE 3
/// Full width of the cone, in degrees
#define BOUNTY_PYROMANIAC_FLAMER_ARC 90
#define BOUNTY_PYROMANIAC_FLAMER_DAMAGE 18
/// Fire stacks (tg's) the jet puts on anyone in the cone. (phase D, CB-8)
#define BOUNTY_PYROMANIAC_FLAMER_STACKS 4
/// How long the floor the cone covered keeps burning
#define BOUNTY_PYROMANIAC_FLAMER_FLOOR (4 SECONDS)
/// Molotov: a lit rag, the throw, a ring where it lands
#define BOUNTY_PYROMANIAC_MOLOTOV_WINDUP (0.7 SECONDS)
#define BOUNTY_PYROMANIAC_MOLOTOV_COOLDOWN (7 SECONDS)
#define BOUNTY_PYROMANIAC_MOLOTOV_RANGE 7
#define BOUNTY_PYROMANIAC_MOLOTOV_DAMAGE 10
/// Fire stacks (tg's) the bursting bottle puts on anyone it splashes. (phase D, CB-8)
#define BOUNTY_PYROMANIAC_MOLOTOV_STACKS 3
#define BOUNTY_PYROMANIAC_MOLOTOV_POOL (8 SECONDS)

// ===== DEMOLITIONIST =====

/// Its crowbar: carried in its bag until the fight starts
#define BOUNTY_DEMOLITIONIST_CROWBAR /obj/item/crowbar/large
/// It keeps this far from its target unless someone is right on it
#define BOUNTY_DEMOLITIONIST_KEEP_MIN 4
#define BOUNTY_DEMOLITIONIST_KEEP_MAX 6
/// Grenade: the throw, then a fuse with a blinking ring
#define BOUNTY_DEMOLITIONIST_GRENADE_WINDUP (0.5 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_FUSE (1.5 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_COOLDOWN (4 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_RANGE 8
#define BOUNTY_DEMOLITIONIST_GRENADE_RADIUS 2
/// Damage to a mech's hull it catches, against bomb armour. People in the ring take tg's light explosion (CB-10).
#define BOUNTY_DEMOLITIONIST_GRENADE_DAMAGE 35
/// Damage to structures within BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_RADIUS
#define BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_DAMAGE 60
#define BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_RADIUS 1
/// Percent chance of a second grenade after the first
#define BOUNTY_DEMOLITIONIST_SECOND_GRENADE 40
/// Breaching charge: pressed onto an interior wall or door, then a beeping fuse
#define BOUNTY_DEMOLITIONIST_BREACH_WINDUP (0.6 SECONDS)
#define BOUNTY_DEMOLITIONIST_BREACH_FUSE (5 SECONDS)
#define BOUNTY_DEMOLITIONIST_BREACH_COOLDOWN (18 SECONDS)
/// Damage to a mech's hull beside the charge. People beside it take tg's light explosion (CB-10).
#define BOUNTY_DEMOLITIONIST_BREACH_DAMAGE 25
/// It breaches toward a target it can't see within this range
#define BOUNTY_DEMOLITIONIST_BREACH_RANGE 8

// ===== GHOST =====

/// Its blade: a real combat knife, carried in a pocket until the fight starts, and every cut it lands is the knife's (CB-9)
#define BOUNTY_GHOST_KNIFE /obj/item/knife/combat
/// Dash: a blur line to the target, the Cascade lattice firing as it goes (OC-6 ruling)
#define BOUNTY_GHOST_DASH_WINDUP (0.3 SECONDS)
#define BOUNTY_GHOST_DASH_COOLDOWN (5 SECONDS)
#define BOUNTY_GHOST_DASH_RANGE 5
/// Cloak: a shimmer, then a faint distortion. Only how it looks: nothing misses it for it (OC-6 ruling, CB-12)
#define BOUNTY_GHOST_CLOAK_WINDUP (0.3 SECONDS)
#define BOUNTY_GHOST_CLOAK_TIME (6 SECONDS)
#define BOUNTY_GHOST_CLOAK_COOLDOWN (12 SECONDS)
#define BOUNTY_GHOST_CLOAK_ALPHA 50
/// Hit and run: after this many cuts it breaks off for a while
#define BOUNTY_GHOST_CUTS_BEFORE_BREAKOFF 2
#define BOUNTY_GHOST_BREAKOFF_TIME (4 SECONDS)

// ===== HEAVY =====

/// Its belt-fed gun: a real L6 held from the start (it has no sling, so it never holsters), with a real spare box (CB-13)
#define BOUNTY_HEAVY_GUN /obj/item/gun/ballistic/automatic/l6_saw/unrestricted
/// Its spare box magazine
#define BOUNTY_HEAVY_SPARE_AMMO /obj/item/ammo_box/magazine/m7mm
/// Suppressive burst: a spin-up whirr, a laser sight and a red cone
#define BOUNTY_HEAVY_BURST_WINDUP (0.7 SECONDS)
#define BOUNTY_HEAVY_BURST_COOLDOWN (4 SECONDS)
#define BOUNTY_HEAVY_BURST_RANGE 8
#define BOUNTY_HEAVY_BURST_SHOTS 10
/// How long the burst takes to fire. Each pull is a click, at least 2 deciseconds apart (a mob clicks once a decisecond at most). (phase D)
#define BOUNTY_HEAVY_BURST_TIME (2 SECONDS)
/// Full width of the cone the rounds go into, in degrees
#define BOUNTY_HEAVY_BURST_ARC 30
/// Extra width, in degrees, of the cone marked on the floor, so edge tiles a round can cross are marked too (P4)
#define BOUNTY_HEAVY_BURST_MARK_MARGIN 10
/// A hit of at least this much damage while it aims makes it fumble the burst. (phase D, CB-13)
#define BOUNTY_HEAVY_FUMBLE_DAMAGE 8
/// Barricade: a real barrier grenade, thrown in front of it (CB-26)
#define BOUNTY_HEAVY_BARRICADE_WINDUP (0.6 SECONDS)
#define BOUNTY_HEAVY_BARRICADE_COOLDOWN (20 SECONDS)
/// Barrier grenades it carries. (phase D)
#define BOUNTY_HEAVY_BARRIERS 2
/// Its barrier grenades' fuse, set short. (phase D)
#define BOUNTY_HEAVY_BARRIER_FUSE (1 SECONDS)
/// Percent of projectiles that pass its barricade (combat.md's number; tg's barrier lets 20 through)
#define BOUNTY_HEAVY_BARRICADE_PASS 50

// ===== AI BLACKBOARD KEYS =====

/// The ability the boss chose this plan (/datum/action/cooldown/mob_cooldown/bounty_boss)
#define BB_BOUNTY_BOSS_ABILITY "BB_bounty_boss_ability"
/// What it aims that ability at
#define BB_BOUNTY_BOSS_ABILITY_TARGET "BB_bounty_boss_ability_target"
/// The hunter it walks toward while nobody is in sight
#define BB_BOUNTY_BOSS_PREY "BB_bounty_boss_prey"
/// world.time it looks for prey again
#define BB_BOUNTY_BOSS_HUNT_AT "BB_bounty_boss_hunt_at"
/// Who it falls back from while worn out
#define BB_BOUNTY_BOSS_FALL_BACK_FROM "BB_bounty_boss_fall_back_from"
/// world.time a Heavy's belt change in progress gives up
#define BB_BOUNTY_BOSS_RELOAD_UNTIL "BB_bounty_boss_reload_until"
