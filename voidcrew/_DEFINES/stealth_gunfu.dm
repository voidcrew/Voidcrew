// Gun-fu (stealth step 3c, owner decisions 14-17 and 22). voidcrew/modules/stealth/stealth_gunfu.dm.
// Balance notes for developers; none of these numbers go in player text.

/// Close-quarters combat chips, head. The gun kata chip; martial arts chips compete for it later (decision 16).
#define ORGAN_SLOT_CYBERWARE_COMBAT_CHIP "cyberware_combat_chip"

/// The moves, as their admin tool and logs name them.
#define GUNFU_MOVE_HIP_THROW "hip throw"
#define GUNFU_MOVE_FLIP "shoulder flip"
#define GUNFU_MOVE_WALL_SLAM "wall slam"
#define GUNFU_MOVE_DISARM "disarm"
#define GUNFU_MOVE_SHIELD "human shield"

/// One move every this long, all moves shared.
#define GUNFU_MOVE_COOLDOWN (3 SECONDS)
/// How long after a move the mover's shots on that victim get the gun-fu crit bonus.
#define GUNFU_MARK_TIME (3 SECONDS)
/// Added to the aimed crit roll of the mover's shots on a marked victim (on top of tg's helpless bonus for a body on the floor).
#define GUNFU_CRIT_BONUS 10
/// Added again when the shot is aimed at the head.
#define GUNFU_CRIT_HEAD_BONUS 10

/// Hip throw: how far the victim goes, and how long tg's knockdown holds them when they land.
#define GUNFU_HIP_THROW_RANGE 2
#define GUNFU_HIP_THROW_KNOCKDOWN (2 SECONDS)
/// Hip throw: brute on landing, through tg's armour (melee).
#define GUNFU_HIP_THROW_DAMAGE 5

/// Shoulder flip: lands on the next tile, flat on their back.
#define GUNFU_FLIP_KNOCKDOWN (3 SECONDS)
#define GUNFU_FLIP_DAMAGE 8

/// Wall slam: brute from the wall, on top of tg's own shove knockdown into something solid.
#define GUNFU_SLAM_DAMAGE 8

/// Disarm: how far the knocked-away item skids.
#define GUNFU_DISARM_THROW_RANGE 2

/// Human shield: how far in front of the holder the held body is drawn, in pixels.
#define GUNFU_SHIELD_SHIFT 12
/// Human shield: shots within this many degrees of the holder's facing hit the held body.
#define GUNFU_SHIELD_ARC 67.5

// ---- Hostages (step 5, decision 47+) ----

/// Guards never stand closer than this to someone holding one of their own.
#define STEALTH_HOSTAGE_HOLD_RANGE 3
/// "Back off" sends them to at least this far.
#define STEALTH_HOSTAGE_BACK_OFF_RANGE 6
/// How far a guard hears a demand.
#define STEALTH_HOSTAGE_DEMAND_RANGE 7
/// Between standoff lines.
#define STEALTH_HOSTAGE_BARK_INTERVAL (6 SECONDS)

#define STEALTH_BARK_HOSTAGE "stealth_hostage"
#define STEALTH_BARK_HOSTAGE_DROP "stealth_hostage_drop"
#define STEALTH_BARK_HOSTAGE_BACK "stealth_hostage_back"
#define STEALTH_BARK_HOSTAGE_EXECUTED "stealth_hostage_executed"
#define STEALTH_BARK_HOSTAGE_RELEASED "stealth_hostage_released"
