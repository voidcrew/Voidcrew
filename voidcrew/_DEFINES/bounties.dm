// # Bounty hunting: shared enums, traits and signals
//
// Owner: P0 seams (frozen). Every bounty package reads these; none redefines them. A package's own
// numbers go in its own defines file: bounty_identity.dm (P1), bounty_criminals.dm (P2),
// bounty_ai.dm (P3), bounty_bosses.dm (P4), bounty_board.dm (P5), bounty_outpost.dm (P6) and
// outpost_prison_bounty.dm (P7). Change this file only through the integration lead.
//
// Unit tests compile before voidcrew/_DEFINES and cannot see these: use the literal value in a
// test, with a comment naming the define.

// ===== TIERS =====
// Numbers, so they order and index per-tier lists: list(petty, wanted, most wanted)[tier].

/// Petty: meek or normal; planets, ruins and trader outposts
#define BOUNTY_TIER_PETTY 1
/// Wanted: normal or meek; planets, ruins, trader outposts and pirate ships
#define BOUNTY_TIER_WANTED 2
/// Most Wanted: always a mini-boss; planets, ruins and pirate ships, never a trader outpost
#define BOUNTY_TIER_MOST_WANTED 3

// ===== ARCHETYPES (decision 11) =====

/// Runs, hides and blends in; draws the holdout pistol only when cornered
#define BOUNTY_ARCHETYPE_MEEK "meek"
/// Found doing something ordinary; fights back
#define BOUNTY_ARCHETYPE_NORMAL "normal"
/// A mini-boss with a kit (BOUNTY_KIT_*)
#define BOUNTY_ARCHETYPE_BOSS "boss"

// ===== FIGHTING STYLES =====
// A normal criminal fights in one of the first six; a meek one always carries the holdout.

#define BOUNTY_STYLE_BRAWLER "brawler"
#define BOUNTY_STYLE_KNIFE "knife"
#define BOUNTY_STYLE_PISTOL "pistol"
#define BOUNTY_STYLE_SHOTGUN "shotgun"
#define BOUNTY_STYLE_CLUB "club"
#define BOUNTY_STYLE_BOTTLE "bottle"
#define BOUNTY_STYLE_HOLDOUT "holdout"

// ===== MINI-BOSS KITS =====
// Also the prefix of each kit's dialogue contexts: "<kit>_intro", "<kit>_ability", "<kit>_exhausted".

#define BOUNTY_KIT_JUGGERNAUT "juggernaut"
#define BOUNTY_KIT_PYROMANIAC "pyromaniac"
#define BOUNTY_KIT_DEMOLITIONIST "demolitionist"
#define BOUNTY_KIT_GHOST "ghost"
#define BOUNTY_KIT_HEAVY "heavy"

// ===== PLACEMENT KINDS =====

#define BOUNTY_PLACEMENT_PLANET "planet"
#define BOUNTY_PLACEMENT_RUIN "ruin"
#define BOUNTY_PLACEMENT_NPC_SHIP "npc_ship"
#define BOUNTY_PLACEMENT_TRADER_OUTPOST "trader_outpost"

// ===== ACTIVITIES =====
// What a criminal is doing when found: start_activity(kind, anchor) (P3), chosen by placement (P5).

#define BOUNTY_ACTIVITY_BAR "bar"
#define BOUNTY_ACTIVITY_CHAT "chat"
#define BOUNTY_ACTIVITY_TRADE "trade"
#define BOUNTY_ACTIVITY_EXPLORE "explore"
#define BOUNTY_ACTIVITY_LOOT "loot"
#define BOUNTY_ACTIVITY_CAMP "camp"
/// Blending in among a trader outpost's patrons: the fugitive and its decoys share it (P3)
#define BOUNTY_ACTIVITY_BLEND "blend"

// ===== CAPTURE STATES =====
// What capture_state() (P2) returns, listed in the order it checks them. The pad pays by these (P5).

#define BOUNTY_STATE_DEAD "dead"
/// At or below the downed line, cuffed or not
#define BOUNTY_STATE_DOWNED "downed"
#define BOUNTY_STATE_RESTRAINED "restrained"
/// Stamina crit, knocked down, paralysed, or surrendered (TRAIT_BOUNTY_SURRENDERED)
#define BOUNTY_STATE_STUNNED "stunned"
/// Standing and free: the pad refuses it
#define BOUNTY_STATE_FREE "free"

// ===== RECORD STATUSES =====
// /datum/bounty_record's status, from posting to the end of its prison time. A closed record
// (released, escaped, dead or closed) never returns to the pool.

/// At large, on the board
#define BOUNTY_RECORD_WANTED "wanted"
/// Caught alive and waiting in GLOB.bounty_prisoner_pool for a prison
#define BOUNTY_RECORD_POOLED "pooled"
/// Held in an outpost prison
#define BOUNTY_RECORD_IMPRISONED "imprisoned"
/// Served their sentence
#define BOUNTY_RECORD_RELEASED "released"
/// Got away from a prison for good
#define BOUNTY_RECORD_ESCAPED "escaped"
#define BOUNTY_RECORD_DEAD "dead"
/// Anything else that ends it: transferred out, the outpost abandoned, removed by an admin, the prison deleted, dropped from a full pool
#define BOUNTY_RECORD_CLOSED "closed"

// ===== POSTINGS =====
// /datum/criminal_bounty's status, and the reasons close() (P5) takes.

#define BOUNTY_POSTING_OPEN "open"
#define BOUNTY_POSTING_CLOSED "closed"

/// Turned in at a ship's pad
#define BOUNTY_CLOSE_CLAIMED "claimed"
/// Ran out of time on the board
#define BOUNTY_CLOSE_EXPIRED "expired"
/// Gibbed or deleted: "confirmed dead, no body"
#define BOUNTY_CLOSE_NO_BODY "no_body"
/// Lost with the pirate ship it was aboard
#define BOUNTY_CLOSE_LOST "lost"
/// Closed from the admin panel (P8)
#define BOUNTY_CLOSE_ADMIN "admin"

// ===== TRAITS =====

/// Trait source for everything the bounty packages put on a mob
#define BOUNTY_TRAIT "bounty"
/// A normal criminal has given up (P3): it can't attack, and capture_state() (P2) reads it as BOUNTY_STATE_STUNNED
#define TRAIT_BOUNTY_SURRENDERED "bounty_surrendered"

// ===== SIGNALS =====

/// Sent by P2 on a criminal when its health falls to the downed line: ()
#define COMSIG_BOUNTY_CRIMINAL_DOWNED "bounty_criminal_downed"
/// Sent by P2 on a criminal when it gets back up after the recovery time: ()
#define COMSIG_BOUNTY_CRIMINAL_RECOVERED "bounty_criminal_recovered"
/// Sent by P2 on a criminal when restraints go on: (mob/user)
#define COMSIG_BOUNTY_CRIMINAL_RESTRAINED "bounty_criminal_restrained"
/// Sent by P2 on a criminal when its restraints come off or slip: (mob/user, or null when they slipped)
#define COMSIG_BOUNTY_CRIMINAL_UNRESTRAINED "bounty_criminal_unrestrained"
/// Sent by P5 on a /datum/criminal_bounty as it closes: (reason, obj/structure/overmap/ship/winner)
#define COMSIG_BOUNTY_POSTING_CLOSED "bounty_posting_closed"
