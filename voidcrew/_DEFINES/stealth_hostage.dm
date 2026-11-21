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

/// Between two sounds from a body held up in front (a mumble under the hand, or a check for a scared line).
#define STEALTH_HOSTAGE_VOICE_MIN (3 SECONDS)
#define STEALTH_HOSTAGE_VOICE_MAX (5 SECONDS)
/// How far a mumble under the hand carries.
#define STEALTH_HOSTAGE_MUMBLE_RANGE 2
/// Between two scared lines from a hostage held at gunpoint who can talk.
#define STEALTH_HOSTAGE_PLEA_MIN (8 SECONDS)
#define STEALTH_HOSTAGE_PLEA_MAX (14 SECONDS)

/// What a hostage says at gunpoint, and what he tries to say under the hand (garbled).
#define STEALTH_BARK_HOSTAGE_PLEA "stealth_hostage_plea"
#define STEALTH_BARK_HOSTAGE_MUFFLED "stealth_hostage_muffled"
