// # Bounty hunting: board, placement and turn-in defines
//
// Owner: P5 board (voidcrew/modules/bounties/bounty_board.dm, bounty_posting.dm,
// bounty_placement.dm, bounty_turn_in.dm). Only P5 edits this file. The shared enums are in
// bounties.dm. The pay and board numbers are the balance fold-in's (spec.md 12.1 and 12.3 C6/C11,
// data/bounties/balance/economy.md); the rest are the spec's (sections 1, 2, 6 and 10).
//
// Unit tests compile before this file: a test uses the literal value with the define named beside it.

// ===== PAY (spec 12.1, 12.3 C11) =====

/// Base credits by tier in green space, before the zone multiplier. Rolled once, when the bounty is posted.
#define BOUNTY_PAY_PETTY_MIN 1100
#define BOUNTY_PAY_PETTY_MAX 1500
#define BOUNTY_PAY_WANTED_MIN 1200
#define BOUNTY_PAY_WANTED_MAX 1600
#define BOUNTY_PAY_MOST_WANTED_MIN 3000
#define BOUNTY_PAY_MOST_WANTED_MAX 3800

/// Trade vouchers by tier, paid only on a full-share turn-in (below it, each voucher's worth joins the credits)
#define BOUNTY_VOUCHERS_PETTY 0
#define BOUNTY_VOUCHERS_WANTED 1
#define BOUNTY_VOUCHERS_MOST_WANTED 2

/// Credit multiplier by zone: the mission system's own (apply_zone_scaling() in _missions.dm)
#define BOUNTY_ZONE_MULT_GREEN 1
#define BOUNTY_ZONE_MULT_YELLOW 1.7
#define BOUNTY_ZONE_MULT_RED 2.6
/// Red space adds a voucher to anything that pays vouchers, as for missions
#define BOUNTY_RED_VOUCHER_BONUS 1

/// Percent of the value paid at the pad, by the WORST capture state the criminal reached (decision 14, spec 12.1)
#define BOUNTY_SHARE_RESTRAINED 100
#define BOUNTY_SHARE_STUNNED 100
#define BOUNTY_SHARE_DOWNED 60
#define BOUNTY_SHARE_DEAD 25

// ===== THE PUBLIC BOARD (spec 12.1) =====

/// Public bounties at once: BOUNTY_PUBLIC_CAP_BASE + active ships / BOUNTY_PUBLIC_CAP_PER_SHIPS, at most BOUNTY_MAX_PUBLIC
#define BOUNTY_PUBLIC_CAP_BASE 1
#define BOUNTY_PUBLIC_CAP_PER_SHIPS 4
#define BOUNTY_MAX_PUBLIC 4
/// Time between two public postings
#define BOUNTY_PUBLIC_POST_GAP (10 MINUTES)
/// When a public posting found no site, how soon the board tries again
#define BOUNTY_PUBLIC_POST_RETRY (1 MINUTES)
/// How long after the round starts the board fills without news: a Most Wanted posted then isn't announced
#define BOUNTY_OPENING_QUIET (5 MINUTES)
/// How long a public bounty stays up; the clock waits while any ship hunts it
#define BOUNTY_PUBLIC_EXPIRY (45 MINUTES)
/// How long one ship's hunt holds a public bounty's clock
#define BOUNTY_HUNT_PAUSE_LIMIT (30 MINUTES)
/// Tier weights for public bounties: Wanted, and the rarer Most Wanted. Petty ones are private offers only.
#define BOUNTY_PUBLIC_WEIGHT_WANTED 3
#define BOUNTY_PUBLIC_WEIGHT_MOST_WANTED 1
/// Public bounties one ship may hunt at once (D-A11); a hunt uses no mission slot
#define BOUNTY_MAX_HUNTS_PER_SHIP 1

// ===== PRIVATE PETTY OFFERS (spec 10, 12.1) =====

/// Private offers one ship holds at once, made when its board is viewed
#define BOUNTY_PRIVATE_MAX 2
/// An offer nobody took comes off the board after this long, like a mission offer (MISSION_BOARD_EXPIRY)
#define BOUNTY_PRIVATE_EXPIRY (20 MINUTES)
/// An accepted offer runs out after this long, like an accepted mission (DEFAULT_MISSION_DURATION)
#define BOUNTY_PRIVATE_DURATION (30 MINUTES)
/// Time between two private offers to the same ship, so dropping one never rerolls it at once
#define BOUNTY_PRIVATE_GAP (5 MINUTES)

// ===== WHERE (spec 2, 6) =====

/// Zone band weights for a new bounty, the mix the economy review simulated (green, yellow, red)
#define BOUNTY_ZONE_WEIGHT_GREEN 45
#define BOUNTY_ZONE_WEIGHT_YELLOW 40
#define BOUNTY_ZONE_WEIGHT_RED 15
/// Chance an offer to a ship with no combat research stays in green space (MISSION_UNARMED_GREEN_BIAS_PROB)
#define BOUNTY_UNARMED_GREEN_BIAS 70
/// Placement kind weights, where the tier allows the kind
#define BOUNTY_PLACEMENT_WEIGHT_PLANET 4
#define BOUNTY_PLACEMENT_WEIGHT_RUIN 3
#define BOUNTY_PLACEMENT_WEIGHT_NPC_SHIP 2
#define BOUNTY_PLACEMENT_WEIGHT_TRADER_OUTPOST 2
/// Percent chance a petty criminal is meek (else normal), and a wanted one normal (else meek) (spec 2).
/// The board's roll is the one in use: every posting passes its archetype to generate_bounty_record().
#define BOUNTY_BOARD_PETTY_MEEK_CHANCE 70
#define BOUNTY_BOARD_WANTED_NORMAL_CHANCE 70
/// Fugitives one trader outpost may hold at once (AR-C9): the board's pick counts open postings there, P6's setup counts those set up to blend in
#define BOUNTY_MAX_FUGITIVES_PER_OUTPOST 2
/// Open postings one pirate ship may hold at once
#define BOUNTY_MAX_PER_NPC_SHIP 1

/// Criminals alive at once, server-wide (AR-G3). A posting over the cap waits on the board.
#define BOUNTY_MAX_LIVE_CRIMINALS 8
/// Companions alive at once, server-wide (AR-G3)
#define BOUNTY_MAX_LIVE_COMPANIONS 12
/// Companions a normal criminal brings, at most (spec 3). The same in every zone: the zone scales pay, never the fight (12.3 C9).
#define BOUNTY_MAX_COMPANIONS 2

/// Tiles between an NPC ship criminal's spawn and every helm aboard (spec 6)
#define BOUNTY_NPC_SHIP_HELM_DISTANCE 5
/// Tiles a spawn prefers to keep from any player (AR-B5)
#define BOUNTY_PLAYER_CLEARANCE 12
/// Tiles a planet spawn keeps from the site's sides (the mission field margin)
#define BOUNTY_PLANET_MARGIN 12
/// Tiles around a ruin landmark or loot container a spawn looks in
#define BOUNTY_ANCHOR_RADIUS 4
/// Board ticks a loaded site may fail to give a spawn turf before the bounty moves somewhere else
#define BOUNTY_SPAWN_ATTEMPTS 12

/// Tiles from where a criminal was destroyed that its proof of death may land, to keep it out of a chasm or lava (H1)
#define BOUNTY_PROOF_EDGE_RADIUS 3

/// A bounty whose criminal was destroyed with nothing left lists again at a new site after this long (AR-A6)
#define BOUNTY_RELIST_DELAY (5 MINUTES)

// ===== SIGHTINGS (spec 6, 12.3 C6) =====

/// How often the sighting marker moves to where the criminal is
#define BOUNTY_SIGHTING_INTERVAL (120 SECONDS)
/// How far, in tiles, the sighting marker may land from the criminal
#define BOUNTY_SIGHTING_OFFSET 5
/// Prefix of the sighting beacon's tag on a GPS
#define BOUNTY_GPS_TAG_PREFIX "WANTED"

// ===== WARRANTS (AR-G2) =====

/// Between two warrants printed at one console
#define BOUNTY_WARRANT_PRINT_COOLDOWN (30 SECONDS)
/// Warrants one ship may print for one bounty
#define BOUNTY_WARRANT_MAX_PER_SHIP 3

// ===== THE PAD =====

/// How long the pad's beam takes to take the criminal (OUTPOST_PRISON_BEAM_TIME, the prisoner beam)
#define BOUNTY_BEAM_TIME (3 SECONDS)
/// Between two lines the pad says about a bounty target landing on it, so dragging on and off doesn't spam
#define BOUNTY_PAD_ANNOUNCE_COOLDOWN (5 SECONDS)
/// On a criminal the pad or the board is taking away (turned in, expired, relisted, gone with its site): nothing it leaves behind is proof of death
#define TRAIT_BOUNTY_REMOVED "bounty_removed"
/// Trait source for what the pad and the board put on a criminal they take: the removal mark, and the pad holding it still for the beam
#define BOUNTY_PAD_TRAIT "bounty_pad"

/// close() reason (beside the shared BOUNTY_CLOSE_*): the ship a private offer was for dropped it
#define BOUNTY_CLOSE_ABANDONED "abandoned"

// ===== WHAT THE BOARD SHOWS =====

/// A posting's state on the board (the UI's `status`)
#define BOUNTY_BOARD_OFFERED "offered"
#define BOUNTY_BOARD_OPEN "open"
#define BOUNTY_BOARD_RELISTING "relisting"

/// How long a mission board holds back its static data for pictures it asked for, before sending without them
#define BOUNTY_BOARD_MUGSHOT_WAIT (5 SECONDS)
