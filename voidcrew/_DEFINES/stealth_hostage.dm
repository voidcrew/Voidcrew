// Hostages (stealth step 5, decisions 47+). voidcrew/modules/stealth/stealth_hostage.dm.
// Balance notes for developers; none of these numbers go in player text.

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
