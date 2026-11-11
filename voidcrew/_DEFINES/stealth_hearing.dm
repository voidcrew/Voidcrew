// Stealth guards: hearing (voidcrew/modules/stealth/stealth_noise.dm and friends). Step 2 of the stealth layer.

// ===== Noise kinds (stealth_noise()) =====
#define STEALTH_NOISE_GUN_QUIET "gun_quiet"
#define STEALTH_NOISE_GUN_PISTOL "gun_pistol"
#define STEALTH_NOISE_GUN_SMG "gun_smg"
#define STEALTH_NOISE_GUN_LONG "gun_long"
#define STEALTH_NOISE_IMPACT "impact"
#define STEALTH_NOISE_BLAST "blast"
#define STEALTH_NOISE_GLASS "glass"
#define STEALTH_NOISE_THROWN "thrown"
#define STEALTH_NOISE_KNOCK "knock"
#define STEALTH_NOISE_BASH "bash"
#define STEALTH_NOISE_DOOR "door"
#define STEALTH_NOISE_THUD "thud"
#define STEALTH_NOISE_VOICE "voice"
#define STEALTH_NOISE_SCREAM "scream"
#define STEALTH_NOISE_SHOUT "shout"
/// A step on broken glass or a dropped bulb (decision 37)
#define STEALTH_NOISE_CRUNCH "crunch"

/// Every kind, for the admin verb and the tests
#define STEALTH_NOISE_KINDS list(\
	STEALTH_NOISE_GUN_QUIET,\
	STEALTH_NOISE_GUN_PISTOL,\
	STEALTH_NOISE_GUN_SMG,\
	STEALTH_NOISE_GUN_LONG,\
	STEALTH_NOISE_IMPACT,\
	STEALTH_NOISE_BLAST,\
	STEALTH_NOISE_GLASS,\
	STEALTH_NOISE_THROWN,\
	STEALTH_NOISE_KNOCK,\
	STEALTH_NOISE_BASH,\
	STEALTH_NOISE_DOOR,\
	STEALTH_NOISE_THUD,\
	STEALTH_NOISE_VOICE,\
	STEALTH_NOISE_SCREAM,\
	STEALTH_NOISE_SHOUT,\
	STEALTH_NOISE_CRUNCH,\
)

// ===== What a guard does about a noise =====
/// Turns to face it and carries on
#define STEALTH_HEAR_GLANCE 1
/// One guard goes to look, then two, then everyone
#define STEALTH_HEAR_INVESTIGATE 2
/// The nearest few run to it and search; the rest hold, wary
#define STEALTH_HEAR_ALARM 3
/// A friend calling: whoever hears it runs to the one shouting
#define STEALTH_HEAR_SHOUT 4

// Fields of a stealth_noise_profile() list
#define STEALTH_PROFILE_REACH 1
#define STEALTH_PROFILE_LEVEL 2
#define STEALTH_PROFILE_FLAGS 3

// ===== Noise flags =====
/// Unheard through any wall or closed door
#define STEALTH_NOISE_LOS_ONLY (1<<0)
/// Walls and doors take half as much off it
#define STEALTH_NOISE_LOUD (1<<1)
/// Heard even when one of their own made it
#define STEALTH_NOISE_ALLIES_COUNT (1<<2)
/// Heard only by the group of the guard that made it
#define STEALTH_NOISE_GROUP_ONLY (1<<3)

// ===== Radio call kinds, lowest first: a pending call is only replaced by a more urgent one =====
#define STEALTH_CALL_REPORT 1
#define STEALTH_CALL_MISSING 2
#define STEALTH_CALL_ALARM 3

// Fields of a controller's pending_call
#define STEALTH_CALL_KIND 1
#define STEALTH_CALL_WHERE 2
#define STEALTH_CALL_DUE 3
#define STEALTH_CALL_NAME 4

// ===== Bark kinds =====
#define STEALTH_BARK_HEARD "stealth_heard"
#define STEALTH_BARK_HEARD_AGAIN "stealth_heard_again"
#define STEALTH_BARK_GUNFIRE "stealth_gunfire"
#define STEALTH_BARK_HOLD "stealth_hold"
#define STEALTH_BARK_HELP "stealth_help"
#define STEALTH_BARK_MISSING "stealth_missing"
#define STEALTH_BARK_RADIO_REPORT "stealth_radio_report"
#define STEALTH_BARK_RADIO_ALARM "stealth_radio_alarm"
#define STEALTH_BARK_RADIO_MISSING "stealth_radio_missing"
#define STEALTH_BARK_COPY "stealth_copy"
#define STEALTH_BARK_RADIO_DEAD "stealth_radio_dead"

// ===== Numbers (first playtest defaults; the owner tunes them) =====
// Reach in open air, in tiles. Each is at or under how far a player hears the same tg sound.
#define STEALTH_NOISE_RANGE_GUN_QUIET 4
#define STEALTH_NOISE_RANGE_GUN_PISTOL 9
#define STEALTH_NOISE_RANGE_GUN_SMG 11
#define STEALTH_NOISE_RANGE_GUN_LONG 14
#define STEALTH_NOISE_RANGE_IMPACT 5
#define STEALTH_NOISE_RANGE_IMPACT_QUIET 1
#define STEALTH_NOISE_RANGE_BLAST 16
#define STEALTH_NOISE_RANGE_GLASS 8
#define STEALTH_NOISE_RANGE_THROWN_SMALL 4
#define STEALTH_NOISE_RANGE_THROWN_MEDIUM 6
#define STEALTH_NOISE_RANGE_THROWN_HEAVY 8
#define STEALTH_NOISE_RANGE_KNOCK 5
#define STEALTH_NOISE_RANGE_BASH 7
#define STEALTH_NOISE_RANGE_DOOR 4
#define STEALTH_NOISE_RANGE_THUD 4
#define STEALTH_NOISE_RANGE_VOICE 5
#define STEALTH_NOISE_RANGE_SCREAM 9
#define STEALTH_NOISE_RANGE_SHOUT 9
/// A step on glass (tg plays it at 50: a player hears it 12 tiles off)
#define STEALTH_NOISE_RANGE_CRUNCH 4
/// The same with TRAIT_LIGHT_STEP (tg plays it at 30: 9 tiles)
#define STEALTH_NOISE_RANGE_CRUNCH_LIGHT 2
/// Tiles of reach a wall eats
#define STEALTH_MUFFLE_WALL 3
/// Tiles of reach a closed solid door eats
#define STEALTH_MUFFLE_DOOR 2
/// Gunfire and blasts go through walls better
#define STEALTH_MUFFLE_LOUD_MULT 0.5
/// Past this many walls and doors nothing is heard
#define STEALTH_MUFFLE_MAX_BLOCKERS 3
/// Inside this many muffled tiles a guard knows the spot
#define STEALTH_NOISE_EXACT_RANGE 6
/// One tile of error per this many tiles past exact
#define STEALTH_NOISE_FUZZ_STEP 3
#define STEALTH_NOISE_FUZZ_MAX 3
/// The same kind of noise this soon and this near an earlier one is the same noise (a volley is one event, decision 31)
#define STEALTH_NOISE_COALESCE (3 SECONDS)
#define STEALTH_NOISE_COALESCE_RANGE 3
#define STEALTH_GLANCE_TIME (3 SECONDS)
/// How long a guard told to hold faces the noise before it goes back to its round
#define STEALTH_HOLD_TIME (10 SECONDS)
/// A search moves to a newer noise at most this often
#define STEALTH_RECENTRE_COOLDOWN (4 SECONDS)
/// "The same spot" for counting lures
#define STEALTH_LURE_RADIUS 6
#define STEALTH_LURE_MEMORY (3 MINUTES)
/// A sentry leaves its post only for a noise this close
#define STEALTH_SENTRY_INVESTIGATE_RANGE 4
/// How long a guard that went to look has before its friends miss it
#define STEALTH_CHECKIN_TIME (30 SECONDS)
#define STEALTH_ALARM_RESPONDERS 4
/// After two alarms in memory
#define STEALTH_ALARM_RESPONDERS_LATER 2
#define STEALTH_ALARM_MEMORY (3 MINUTES)
/// While alert with its target in view
#define STEALTH_SHOUT_INTERVAL (10 SECONDS)
/// Hand to the earpiece, then this long before the call goes out
#define STEALTH_RADIO_CALL_TIME (3 SECONDS)
/// A call this far past due (its level slept) is never made
#define STEALTH_RADIO_CALL_STALE (5 SECONDS)
/// One alarm delivery per group per this long
#define STEALTH_RADIO_GROUP_COOLDOWN (10 SECONDS)
/// Carriers that move on a call
#define STEALTH_RADIO_RESPONDERS 4
/// Who a carrier's answer carries to, in muffled tiles
#define STEALTH_RELAY_VOICE_RANGE 5
#define STEALTH_RELAY_VOICE_RESPONDERS 2
/// How far a running step on plain floor in shoes carries to a guard
#define STEALTH_FOOTSTEP_RANGE 5
/// How far a player hears that same step (tg: volume 75, range 17 - 1 - 6)
#define STEALTH_FOOTSTEP_PLAYER_RANGE 8
/// The furthest any step is listened for
#define STEALTH_FOOTSTEP_MAX_RANGE 7
#define STEALTH_FOOTSTEP_CRAWL_RANGE 2
/// Notice a heard step adds
#define STEALTH_FOOTSTEP_NOTICE 0.5
/// How long the admin noise view keeps one event on screen
#define STEALTH_NOISE_VIEW_TIME (4 SECONDS)
/// icon_state of the empty grey "?" over a guard that heard something (stealth_meter.dmi)
#define STEALTH_METER_HEARD_STATE "q_y0"
