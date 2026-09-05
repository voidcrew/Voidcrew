// Player-built custom outposts

/// Credit cost of a first-time outpost deed at a trader outpost
#define OUTPOST_DEED_COST_CREDITS 10000
/// Trade voucher cost of a first-time outpost deed
#define OUTPOST_DEED_COST_VOUCHERS 3

/// Hard cap on shell template dimensions
#define PLAYER_OUTPOST_MAX_SHELL_SIZE 40
/// How often the outpost sweeps its build region to adopt hand-built
/// structures into its powered area (drone builds adopt instantly)
#define PLAYER_OUTPOST_AREA_SWEEP_INTERVAL (30 SECONDS)

/// Cooldown between outpost renames
#define PLAYER_OUTPOST_RENAME_COOLDOWN (5 MINUTES)
/// Maximum length of the outpost memo/description
#define PLAYER_OUTPOST_MEMO_MAX_LEN 256

/// Credit cost of one galaxy-wide advertisement
#define OUTPOST_ADVERT_COST 2500
/// How long a purchased advertisement stays live
#define OUTPOST_ADVERT_DURATION (20 MINUTES)
/// Minimum time between advertisement purchases per outpost
#define OUTPOST_ADVERT_COOLDOWN (10 MINUTES)

/// Anyone may dock without asking
#define OUTPOST_DOCK_MODE_OPEN "open"
/// Docking requires owner approval per ship
#define OUTPOST_DOCK_MODE_REQUEST "request"
/// Only the owner's crew may dock
#define OUTPOST_DOCK_MODE_LOCKDOWN "lockdown"
/// How long a pending docking request stays valid
#define OUTPOST_DOCK_REQUEST_TIMEOUT (2 MINUTES)

/// If defined, missile launchers may fire in the yellow zone when locked onto a raidable player outpost
#define PLAYER_OUTPOST_YELLOW_SIEGE_ENABLED

// ===== OUTPOST SHIELD GENERATOR (see outpost_shield.dm) =====
// A siege missile drains charge equal to its damage: light 200 / standard 400 / heavy 600.
// Base pool of 1000 therefore stops ~2 standard missiles before depleting.

/// Base shield charge pool of an outpost shield generator (before capacitor upgrades)
#define OUTPOST_SHIELD_BASE_CHARGE 1000
/// Capacitor: +50% max charge per tier above 1
#define OUTPOST_SHIELD_CAPACITOR_CHARGE_MULT 0.5
/// Charge drained per point of missile damage (1 = full damage value)
#define OUTPOST_SHIELD_MISSILE_DRAIN_MULT 1
/// Minimum charge drained per absorbed missile (chemical missiles list ~0 damage)
#define OUTPOST_SHIELD_MIN_DRAIN 100
/// Base recharge rate in charge per second (full base pool from empty in ~3m20s)
#define OUTPOST_SHIELD_BASE_RECHARGE 5
/// Micro-laser: +30% recharge rate per tier above 1
#define OUTPOST_SHIELD_LASER_RECHARGE_MULT 0.3
/// Recharging pauses for this long after every absorbed hit (shields don't heal under fire)
#define OUTPOST_SHIELD_RECHARGE_DELAY (10 SECONDS)
/// APC equipment-channel power draw while actively recharging (watts)
#define OUTPOST_SHIELD_CHARGE_POWER (10 KILO WATTS)
/// APC equipment-channel power draw while holding a charged/idle field (watts)
#define OUTPOST_SHIELD_IDLE_POWER (1 KILO WATTS)
