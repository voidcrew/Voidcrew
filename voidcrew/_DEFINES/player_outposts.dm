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

/// One permanent construction bay per outpost.
#define OUTPOST_SHIP_BAY_SLOTS 1
#define OUTPOST_SHIP_BAY_COST 10000
#define OUTPOST_DOCK_VARIANT_BAY "ship_bay"

/// Round-local, prepaid hull recovery. A ship has at most one current registration.
#define OUTPOST_MAX_CHECKPOINTS 12
#define OUTPOST_CHECKPOINT_MAX_TEXT (1024 * 1024)
#define OUTPOST_CHECKPOINT_SAVE_COST 10000
#define OUTPOST_CHECKPOINT_UPDATE_COST 5000

/// New ships built to order in the ship bay (outpost_ship_orders.dm). Credits replace parts:
/// every part a hull, theme or module would cost in the lobby shipyard is this many credits.
#define OUTPOST_SHIP_ORDER_PART_PRICE 2500
/// Charged on every order, on top of the hull's parts.
#define OUTPOST_SHIP_ORDER_FEE 10000

// ===== STAGED CHECKPOINT RECONSTRUCTION (see outpost_checkpoint_construction.dm) =====
/// The saved ship is loaded and waiting for its survey markers.
#define CHECKPOINT_BUILD_PREPARING "preparing"
/// Warning markers are down; no recoverable piece exists yet.
#define CHECKPOINT_BUILD_MARKING "marking"
/// Pieces are being placed one visit at a time.
#define CHECKPOINT_BUILD_BUILDING "building"
/// Every visit has run; the hull is waiting for its captain and handover.
#define CHECKPOINT_BUILD_COMMISSIONING "commissioning"
#define CHECKPOINT_BUILD_COMPLETE "complete"
#define CHECKPOINT_BUILD_FAILED "failed"

/// Build stages, in order. Each stage finishes before the next begins.
#define CHECKPOINT_STAGE_DECK 1
#define CHECKPOINT_STAGE_HULL 2
#define CHECKPOINT_STAGE_SYSTEMS 3
#define CHECKPOINT_STAGE_MACHINERY 4
#define CHECKPOINT_STAGE_FITTINGS 5
#define CHECKPOINT_STAGE_COUNT 5

/// How long the survey markers show before the first drone starts work.
#define CHECKPOINT_BUILD_SURVEY_TIME (4 SECONDS)
/// Time a drone spends on one tile before its pieces appear.
#define CHECKPOINT_BUILD_WORK_TIME (0.4 SECONDS)
/// Played once to everyone in the bay when the drones leave, and when the last one docks.
#define CHECKPOINT_YARD_LAUNCH_SOUND 'voidcrew/sound/checkpoint/drone_launch.ogg'
#define CHECKPOINT_YARD_DOCK_SOUND 'voidcrew/sound/checkpoint/drone_dock.ogg'
#define CHECKPOINT_BUILD_MIN_DRONES 8
#define CHECKPOINT_BUILD_MAX_DRONES 16
/// Tiles a drone crosses in one hop.
#define CHECKPOINT_DRONE_TILES_PER_TICK 3
/// How often a drone makes that hop. The glide between hops takes the same time.
#define CHECKPOINT_DRONE_FLIGHT_INTERVAL (0.4 SECONDS)
/// Roughly one extra drone per this many visits, between the limits above.
#define CHECKPOINT_BUILD_VISITS_PER_DRONE 100
/// Upper bound on tile visits completed in one controller tick, across all drones.
#define CHECKPOINT_BUILD_VISIT_BUDGET 8
/// Visits per tick when an admin rushes a build (a few seconds for a Box-class hull).
#define CHECKPOINT_BUILD_RUSH_BUDGET 40
/// Ambient light on a hull while it is built, matching the hangar floodlights.
#define CHECKPOINT_BUILD_FLOODLIGHT_ALPHA 110
#define CHECKPOINT_BUILD_FLOODLIGHT_COLOR "#d5e3ff"
/// A build that stops advancing for this long is finished with the pieces it has.
#define CHECKPOINT_BUILD_STALL_TIME (1 MINUTES)
/// How long a finished hull waits for its captain before being left claimable.

// ===== OUTPOST UPGRADES (see outpost_upgrades.dm) =====
/// A placed upgrade needs a tile within this many tiles (Chebyshev) of outpost ground
#define OUTPOST_UPGRADE_MAX_GAP 8
/// The longest floor path the feeder lays cable along to join a room to the grid (outpost_room_power.dm)
#define OUTPOST_ROOM_FEEDER_MAX 32
/// How long a placement-map survey is reused before it is taken again
#define OUTPOST_UPGRADE_SURVEY_LIFETIME (30 SECONDS)

// ===== OUTPOST PRISON =====
// The prison wing's defines are in outpost_prison_economy.dm, outpost_prison_needs.dm,
// outpost_prison_conditions.dm, outpost_prison_trouble.dm and outpost_prison_experiments.dm.

// ===== ONE LEVEL PER OUTPOST (see outpost_level_layout.dm) =====
/// Cordon rows round the edge of an outpost's level
#define OUTPOST_LEVEL_EDGE 2
/// Cordon between neighbouring zones, and between the zones and the build region
#define OUTPOST_LEVEL_GUTTER 3
/// Hangar berth zones on an outpost's level. Each fits the largest ship-sized berth.
#define OUTPOST_LEVEL_BERTHS 4
#define OUTPOST_BERTH_ZONE_WIDTH 66
#define OUTPOST_BERTH_ZONE_HEIGHT 59
/// The ship bay zone: both bay maps are exactly this size
#define OUTPOST_BAY_ZONE_WIDTH 63
#define OUTPOST_BAY_ZONE_HEIGHT 55
/// The hidden shipyard where a checkpoint rebuild or a ship order loads its hull copy.
/// Hull templates reach 56 tiles on either axis; a tile of margin all round.
#define OUTPOST_YARD_ZONE_SIZE 58
/// Where the incoming cargo ferry waits: the 7x12 ferry with room round it
#define OUTPOST_PEN_ZONE_WIDTH 15
#define OUTPOST_PEN_ZONE_HEIGHT 20

/// Zone kinds; a berth zone's key is the kind plus its berth number ("berth1")
#define OUTPOST_ZONE_BERTH "berth"
#define OUTPOST_ZONE_BAY "bay"
#define OUTPOST_ZONE_YARD "yard"
#define OUTPOST_ZONE_PEN "pen"
/// Layout key of the build region (not a zone)
#define OUTPOST_LEVEL_BUILD_REGION "build"

/// Zone states
#define OUTPOST_ZONE_VACANT "vacant"
#define OUTPOST_ZONE_BUILDING "building"
#define OUTPOST_ZONE_IN_USE "in use"
#define OUTPOST_ZONE_WIPING "wiping"
