// # Bounty hunting: mini-boss defines
//
// Owner: P4 bosses (voidcrew/modules/bounties/bounty_boss.dm, bounty_boss_kits.dm). Only P4 edits
// this file. The shared enums are in bounties.dm. The numbers are the combat balance review's
// (balance/combat.md section 6.3, folded into spec.md 12.3 C8). A number marked (P4) is not in the
// review and was picked by P4.

// ===== COMMON RULES =====

/// Percent of max health at or below which a boss is tired: stamina works fully, it slows, its cooldowns stretch, and it can be stunned
#define BOUNTY_BOSS_TIRED_BELOW 40
/// Stamina damage coefficient while fresh (the Heavy's is BOUNTY_HEAVY_STAMINA_FRESH). 0 after review H3: combat.md's 0.2 only slowed a fresh boss under steady disabler fire and pre-loaded its pool, so capture took one hit instead of five.
#define BOUNTY_BOSS_STAMINA_FRESH 0
/// Stamina damage coefficient once tired
#define BOUNTY_BOSS_STAMINA_TIRED 1
/// Stamina damage it takes to stamina-crit a tired boss (the Heavy's is BOUNTY_HEAVY_STAMINA), counted from zero when it tires. max_stamina stays P2's 100 because of the stamcrit removal quirk; the pool is folded into the coefficient instead.
#define BOUNTY_BOSS_STAMINA 150
/// Below this pressure (kPa) on either side, a wall, window or door is not interior (P4)
#define BOUNTY_BOSS_INTERIOR_MIN_PRESSURE 20
/// More than this pressure difference (kPa) between its sides, and a wall, window or door is not interior (P4)
#define BOUNTY_BOSS_INTERIOR_MAX_PRESSURE_GAP 50
/// A dodge or miss message is shown at most this often (P4)
#define BOUNTY_BOSS_MESSAGE_COOLDOWN (1 SECONDS)
/// How much slower a tired boss moves
#define BOUNTY_BOSS_TIRED_SLOWDOWN 0.3
/// Ability cooldowns are this much longer while tired (P4: the spec says "longer" and gives no number)
#define BOUNTY_BOSS_TIRED_COOLDOWN_MULT 1.5
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

// ===== JUGGERNAUT =====

/// Health for 1, 2, 3 and 4+ engaged hunters
#define BOUNTY_JUGGERNAUT_HEALTH_1 300
#define BOUNTY_JUGGERNAUT_HEALTH_2 950
#define BOUNTY_JUGGERNAUT_HEALTH_3 1600
#define BOUNTY_JUGGERNAUT_HEALTH_4 2300
#define BOUNTY_JUGGERNAUT_BRUTE_MOD 0.7
#define BOUNTY_JUGGERNAUT_BURN_MOD 0.8
#define BOUNTY_JUGGERNAUT_SPEED 1.9
/// Its fists
#define BOUNTY_JUGGERNAUT_MELEE_MIN 20
#define BOUNTY_JUGGERNAUT_MELEE_MAX 26
#define BOUNTY_JUGGERNAUT_MELEE_AP 15
#define BOUNTY_JUGGERNAUT_MELEE_COOLDOWN (1.1 SECONDS)
/// Charge: a roar, a stamp and a cracked-floor line
#define BOUNTY_JUGGERNAUT_CHARGE_WINDUP (0.8 SECONDS)
#define BOUNTY_JUGGERNAUT_CHARGE_COOLDOWN (8 SECONDS)
/// Tiles it charges, at most
#define BOUNTY_JUGGERNAUT_CHARGE_RANGE 7
/// Time per tile of the charge (P4)
#define BOUNTY_JUGGERNAUT_CHARGE_STEP 1
#define BOUNTY_JUGGERNAUT_CHARGE_DAMAGE 25
#define BOUNTY_JUGGERNAUT_CHARGE_KNOCKDOWN (2 SECONDS)
/// Percent chance that someone else in the way is caught too
#define BOUNTY_JUGGERNAUT_CHARGE_BYSTANDER 25
/// Charged into something it can't break: it stands reeling this long, taking more damage
#define BOUNTY_JUGGERNAUT_WALL_STAGGER (2 SECONDS)
#define BOUNTY_JUGGERNAUT_WALL_VULNERABLE 1.25
/// Slam: both fists up, a red ring
#define BOUNTY_JUGGERNAUT_SLAM_WINDUP (0.7 SECONDS)
#define BOUNTY_JUGGERNAUT_SLAM_COOLDOWN (7 SECONDS)
#define BOUNTY_JUGGERNAUT_SLAM_DAMAGE 20
#define BOUNTY_JUGGERNAUT_SLAM_KNOCKDOWN (1.5 SECONDS)

// ===== PYROMANIAC =====

#define BOUNTY_PYROMANIAC_HEALTH_1 580
#define BOUNTY_PYROMANIAC_HEALTH_2 1300
#define BOUNTY_PYROMANIAC_HEALTH_3 1950
#define BOUNTY_PYROMANIAC_HEALTH_4 2550
/// Fireproof, not laser-proof: fire and heat can't hurt it, and lasers (BURN) hit it at this
#define BOUNTY_PYROMANIAC_BRUTE_MOD 0.9
#define BOUNTY_PYROMANIAC_BURN_MOD 0.9
#define BOUNTY_PYROMANIAC_SPEED 1.8
/// Its torch: burn damage
#define BOUNTY_PYROMANIAC_MELEE_MIN 10
#define BOUNTY_PYROMANIAC_MELEE_MAX 14
#define BOUNTY_PYROMANIAC_MELEE_AP 15
#define BOUNTY_PYROMANIAC_MELEE_COOLDOWN (1 SECONDS)
/// Flamer: a pilot light hiss, an orange cone
#define BOUNTY_PYROMANIAC_FLAMER_WINDUP (0.5 SECONDS)
#define BOUNTY_PYROMANIAC_FLAMER_COOLDOWN (5 SECONDS)
#define BOUNTY_PYROMANIAC_FLAMER_RANGE 3
/// Full width of the cone, in degrees
#define BOUNTY_PYROMANIAC_FLAMER_ARC 90
#define BOUNTY_PYROMANIAC_FLAMER_DAMAGE 18
/// How long the floor the cone covered keeps burning
#define BOUNTY_PYROMANIAC_FLAMER_FLOOR (4 SECONDS)
/// Molotov: a lit rag, the throw, a ring where it lands
#define BOUNTY_PYROMANIAC_MOLOTOV_WINDUP (0.7 SECONDS)
#define BOUNTY_PYROMANIAC_MOLOTOV_COOLDOWN (7 SECONDS)
#define BOUNTY_PYROMANIAC_MOLOTOV_RANGE 7
#define BOUNTY_PYROMANIAC_MOLOTOV_DAMAGE 10
#define BOUNTY_PYROMANIAC_MOLOTOV_POOL (8 SECONDS)
/// Set alight by a boss's fire: burn damage every second for this long, renewed while standing in the flames
#define BOUNTY_BOSS_BURNING_TIME (4 SECONDS)
#define BOUNTY_BOSS_BURNING_DAMAGE 3

// ===== DEMOLITIONIST =====

#define BOUNTY_DEMOLITIONIST_HEALTH_1 870
#define BOUNTY_DEMOLITIONIST_HEALTH_2 1750
#define BOUNTY_DEMOLITIONIST_HEALTH_3 2300
#define BOUNTY_DEMOLITIONIST_HEALTH_4 2850
#define BOUNTY_DEMOLITIONIST_BRUTE_MOD 0.85
#define BOUNTY_DEMOLITIONIST_BURN_MOD 0.85
#define BOUNTY_DEMOLITIONIST_SPEED 1.7
/// Its crowbar: the look in its hand and every number of its blows (bounty_real_weapon())
#define BOUNTY_DEMOLITIONIST_CROWBAR /obj/item/crowbar/red
#define BOUNTY_DEMOLITIONIST_MELEE_COOLDOWN (1 SECONDS)
/// It keeps this far from its target unless someone is right on it
#define BOUNTY_DEMOLITIONIST_KEEP_MIN 4
#define BOUNTY_DEMOLITIONIST_KEEP_MAX 6
/// Grenade: the throw, then a fuse with a blinking ring
#define BOUNTY_DEMOLITIONIST_GRENADE_WINDUP (0.5 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_FUSE (1.5 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_COOLDOWN (4 SECONDS)
#define BOUNTY_DEMOLITIONIST_GRENADE_RANGE 8
#define BOUNTY_DEMOLITIONIST_GRENADE_RADIUS 2
/// Brute to anyone caught, against bomb armour
#define BOUNTY_DEMOLITIONIST_GRENADE_DAMAGE 35
#define BOUNTY_DEMOLITIONIST_GRENADE_KNOCKDOWN (1 SECONDS)
/// Damage to structures within BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_RADIUS
#define BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_DAMAGE 60
#define BOUNTY_DEMOLITIONIST_GRENADE_OBJECT_RADIUS 1
/// Percent chance of a second grenade after the first
#define BOUNTY_DEMOLITIONIST_SECOND_GRENADE 40
/// Breaching charge: pressed onto an interior wall or door, then a beeping fuse
#define BOUNTY_DEMOLITIONIST_BREACH_WINDUP (0.6 SECONDS)
#define BOUNTY_DEMOLITIONIST_BREACH_FUSE (5 SECONDS)
#define BOUNTY_DEMOLITIONIST_BREACH_COOLDOWN (18 SECONDS)
#define BOUNTY_DEMOLITIONIST_BREACH_DAMAGE 25
/// It breaches toward a target it can't see within this range
#define BOUNTY_DEMOLITIONIST_BREACH_RANGE 8

// ===== GHOST =====

#define BOUNTY_GHOST_HEALTH_1 250
#define BOUNTY_GHOST_HEALTH_2 850
#define BOUNTY_GHOST_HEALTH_3 1700
#define BOUNTY_GHOST_HEALTH_4 2450
#define BOUNTY_GHOST_BRUTE_MOD 1
#define BOUNTY_GHOST_BURN_MOD 1
#define BOUNTY_GHOST_SPEED 1.2
/// Its blade: the look in its hand and every number of its blows (bounty_real_weapon())
#define BOUNTY_GHOST_KNIFE /obj/item/knife/combat
#define BOUNTY_GHOST_MELEE_COOLDOWN (0.7 SECONDS)
/// Each cut bleeds this much brute a second for BOUNTY_GHOST_BLEED_TIME, up to BOUNTY_GHOST_BLEED_CAP a second
#define BOUNTY_GHOST_BLEED_PER_CUT 1
#define BOUNTY_GHOST_BLEED_CAP 2
#define BOUNTY_GHOST_BLEED_TIME (12 SECONDS)
/// Dash: a blur line to the target
#define BOUNTY_GHOST_DASH_WINDUP (0.3 SECONDS)
#define BOUNTY_GHOST_DASH_COOLDOWN (5 SECONDS)
#define BOUNTY_GHOST_DASH_RANGE 5
/// The dash's cut, its biggest hit (P4: combat.md B4 asks for the dash to be the biggest hit), and its armour penetration
#define BOUNTY_GHOST_DASH_DAMAGE 20
#define BOUNTY_GHOST_DASH_AP 10
/// Cloak: a shimmer, then a faint distortion
#define BOUNTY_GHOST_CLOAK_WINDUP (0.3 SECONDS)
#define BOUNTY_GHOST_CLOAK_TIME (6 SECONDS)
#define BOUNTY_GHOST_CLOAK_COOLDOWN (12 SECONDS)
#define BOUNTY_GHOST_CLOAK_ALPHA 50
/// Percent of hits that miss it while it is cloaked
#define BOUNTY_GHOST_CLOAK_MISS 50
/// Percent of projectiles it dodges while moving
#define BOUNTY_GHOST_DODGE 30
/// It counts as moving for this long after a step
#define BOUNTY_GHOST_MOVING_WINDOW (1 SECONDS)
/// Hit and run: after this many cuts it breaks off for a while
#define BOUNTY_GHOST_CUTS_BEFORE_BREAKOFF 2
#define BOUNTY_GHOST_BREAKOFF_TIME (4 SECONDS)

// ===== HEAVY =====

#define BOUNTY_HEAVY_HEALTH_1 340
#define BOUNTY_HEAVY_HEALTH_2 970
#define BOUNTY_HEAVY_HEALTH_3 1400
#define BOUNTY_HEAVY_HEALTH_4 1850
#define BOUNTY_HEAVY_BRUTE_MOD 0.55
#define BOUNTY_HEAVY_BURN_MOD 0.65
#define BOUNTY_HEAVY_SPEED 2.2
/// 0 after review H3, as BOUNTY_BOSS_STAMINA_FRESH (combat.md had 0.15)
#define BOUNTY_HEAVY_STAMINA_FRESH 0
#define BOUNTY_HEAVY_STAMINA 180
/// Its belt-fed gun: the look in its hand, the rounds of its burst and the blow of its butt (bounty_real_weapon())
#define BOUNTY_HEAVY_GUN /obj/item/gun/ballistic/automatic/l6_saw
#define BOUNTY_HEAVY_MELEE_COOLDOWN (1.1 SECONDS)
/// Suppressive burst: a spin-up whirr, a laser sight and a red cone
#define BOUNTY_HEAVY_BURST_WINDUP (0.7 SECONDS)
#define BOUNTY_HEAVY_BURST_COOLDOWN (4 SECONDS)
#define BOUNTY_HEAVY_BURST_RANGE 8
#define BOUNTY_HEAVY_BURST_SHOTS 10
/// How long the burst takes to fire
#define BOUNTY_HEAVY_BURST_TIME (1.5 SECONDS)
/// Full width of the cone the rounds go into, in degrees
#define BOUNTY_HEAVY_BURST_ARC 30
/// Extra width, in degrees, of the cone marked on the floor, so edge tiles a round can cross are marked too (P4)
#define BOUNTY_HEAVY_BURST_MARK_MARGIN 10
/// The rounds' damage to windows, grilles, tables and barricades it may break, as a share of their damage (none to anything else)
#define BOUNTY_HEAVY_BURST_DEMOLITION 0.25
/// Barricade: tg's security barrier, dropped in front of it
#define BOUNTY_HEAVY_BARRICADE_WINDUP (0.6 SECONDS)
#define BOUNTY_HEAVY_BARRICADE_COOLDOWN (20 SECONDS)
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
