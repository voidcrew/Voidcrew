// ===== OUTPOST PRISON: CONDITIONS (see outpost_prison_conditions.dm) =====
// The wing's clean, lit and powered scores, what they do to moods, and the riot strobe.
//
// Clean: mess on the cell block's floor (cells, cell doors, yard, the mess tables and serving
// hatches), each tile's pieces weighted and capped, per 100 floor tiles counted when the wing was
// placed. Lit: light measured on the tiles prisoners stand on. Power: the equipment channel, with
// a grace for blips. Conditions = PRISON_WEIGHT_CLEAN x Clean + PRISON_WEIGHT_LIT x Lit +
// PRISON_WEIGHT_POWER x Power, and pay is scaled by OUTPOST_PRISON_CONDITIONS_PAY_FLOOR +
// (1 - OUTPOST_PRISON_CONDITIONS_PAY_FLOOR) x Conditions / 100.

/// Mood lost per minute at a wing score of 0: dirty and dark scale down to nothing at
/// PRISON_WING_MOOD_LINE; no power scales with how far Power is below 100
#define PRISONER_MOOD_DARK 5
#define PRISONER_MOOD_DIRTY_WING 5
#define PRISONER_MOOD_NO_POWER 4
/// Two light samples in a row below this lit score put the wing on edge; a cell below it is dark
#define PRISON_DARK_BELOW 50
/// The clean score below which the wing counts as dirty for complaints
#define PRISON_DIRTY_BELOW 60
/// Mood gained per minute while Clean and Lit are at least PRISON_GOOD_CONDITIONS and Power is 100
#define PRISONER_MOOD_GOOD_WING 2
#define PRISON_GOOD_CONDITIONS 80

/// Mess units per 100 floor tiles that cost nothing, and the load at which Clean reaches 0
#define PRISON_MESS_FREE 2
#define PRISON_MESS_SQUALID 14
/// Mess units one tile can count for
#define PRISON_MESS_TILE_CAP 2
/// Mess units of crumbs and drips, of dirt and litter, and of blood pools and vomit
#define PRISON_MESS_WEIGHT_TRACE 0.25
#define PRISON_MESS_WEIGHT_LIGHT 0.5
#define PRISON_MESS_WEIGHT_HEAVY 1.5
/// Light level at which a tile counts as fully lit
#define PRISON_LIT_ENOUGH 0.3
/// Seconds of power cut that cost nothing, then seconds over which Power falls to 0
#define PRISON_POWER_GRACE 30
#define PRISON_POWER_RAMP 90
/// Outage debt lost per powered second
#define PRISON_POWER_DEBT_RECOVERY 0.5
/// Weights of the clean, lit and powered scores in conditions
#define PRISON_WEIGHT_CLEAN 0.45
#define PRISON_WEIGHT_LIT 0.35
#define PRISON_WEIGHT_POWER 0.20
/// Share of pay a wing at conditions 0 still earns
#define OUTPOST_PRISON_CONDITIONS_PAY_FLOOR 0.5
/// Atoms looked at per mess scan; the next scan carries on where it stopped
#define PRISON_SCAN_BUDGET 3000
/// Seconds between light samples, and between furniture refreshes
#define PRISON_LIGHT_REFRESH 10
#define PRISON_FIXTURE_REFRESH 30
/// Most lights the riot strobe drives, nearest the cell block first
#define PRISON_STROBE_MAX_LIGHTS 12
/// More lights that strobe for each cell block extension joined to the wing
#define PRISON_STROBE_LIGHTS_PER_EXTENSION 6
/// Wing mood losses start below this score
#define PRISON_WING_MOOD_LINE 70
/// Mood lost per minute by a prisoner whose own cell is dark
#define PRISONER_MOOD_DARK_CELL 2
/// Heavy mess left this long draws flies, up to this many tiles
#define PRISON_FLY_AFTER (5 MINUTES)
#define PRISON_FLY_MAX 6
/// Rats: Clean held below PRISON_RAT_CLEAN_BELOW for PRISON_RAT_AFTER gives PRISON_RAT_CHANCE percent a minute
/// of a rat, at most PRISON_RAT_MAX, until Clean is back above PRISON_RAT_STOP_ABOVE
#define PRISON_RAT_CLEAN_BELOW 40
#define PRISON_RAT_STOP_ABOVE 60
#define PRISON_RAT_AFTER (3 MINUTES)
#define PRISON_RAT_CHANCE 20
#define PRISON_RAT_MAX 2
/// Brute per 5 seconds on unsafe air, never below PRISON_AIR_HEALTH_FLOOR percent health
#define PRISON_AIR_DAMAGE 1
#define PRISON_AIR_HEALTH_FLOOR 30
/// Unsafe air: pressure (kPa), temperature (K) and plasma (mol) limits
#define PRISON_AIR_PRESSURE_MIN 60
#define PRISON_AIR_PRESSURE_MAX 150
#define PRISON_AIR_TEMP_MIN 260
#define PRISON_AIR_TEMP_MAX 330
#define PRISON_AIR_PLASMA_MAX 1
/// Battery percent at which prisoners notice the lights flicker
#define PRISON_BATTERY_WARNING 40
