// Player-built custom outposts

/// Credit cost of a first-time outpost deed at a trader outpost
#define OUTPOST_DEED_COST_CREDITS 10000
/// Trade voucher cost of a first-time outpost deed
#define OUTPOST_DEED_COST_VOUCHERS 3

/// How far beyond the shell footprint the buildable region extends, in turfs
#define PLAYER_OUTPOST_BUILD_MARGIN 15
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
