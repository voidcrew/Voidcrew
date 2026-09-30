// # Bounty hunting: trader outpost defines
//
// Owner: P6 outposts (voidcrew/modules/bounties/bounty_outpost.dm). Only P6 edits this file. The
// shared enums are in bounties.dm. Values marked BAL are the spec's placeholders (spec.md section 7
// and the owner's assumed default D-A6) until a balance pass says otherwise.

/// Decoy patrons that spawn with a trader-outpost bounty
#define BOUNTY_DECOY_COUNT 3 // BAL: spec section 7
// The fugitives-per-outpost cap is the board's BOUNTY_MAX_FUGITIVES_PER_OUTPOST (_DEFINES/bounty_board.dm): one number for both checks.
/// The alert at which the fugitive slips away and the bounty relists at another outpost (D-A6)
#define BOUNTY_OUTPOST_ALERT_SLIP 2 // BAL: D-A6
/// How long a ship waits between showing warrants (D-A6)
#define BOUNTY_WARRANT_COOLDOWN (30 SECONDS) // BAL: D-A6
/// Blows on one decoy this close together are one scuffle, and raise the alert once
#define BOUNTY_OUTPOST_HIT_GRACE (5 SECONDS)
/// How far a decoy backs off from whoever hit it, in tiles
#define BOUNTY_DECOY_FLEE_DISTANCE 5
/// How long a decoy keeps backing off
#define BOUNTY_DECOY_FLEE_TIME (4 SECONDS)
/// Move delay of someone walking out to the hangar: a walk, not a run
#define BOUNTY_OUTPOST_EXIT_DELAY 4
/// Anyone still walking out after this fades where they are
#define BOUNTY_OUTPOST_EXIT_TIMEOUT (45 SECONDS)
/// How long the fade out takes
#define BOUNTY_OUTPOST_FADE_TIME (1 SECONDS)

/// Trait source for everything P6 puts on a mob
#define BOUNTY_OUTPOST_TRAIT "bounty_outpost"

// raise_alert() reasons, as the admin log shows them
#define BOUNTY_ALERT_WRONG_WARRANT "a wrong warrant"
#define BOUNTY_ALERT_DECOY_HIT "a hit on a decoy"

// What a trader can tell a ship about a fugitive: one kind per trader, per posting
/// Where the fugitive was seen
#define BOUNTY_CLUE_SEEN "seen"
/// How their hair differs from the mugshot
#define BOUNTY_CLUE_HAIR "hair"
/// One of their distinguishing features
#define BOUNTY_CLUE_FEATURE "feature"
/// One patron who is not them, by where they are
#define BOUNTY_CLUE_RULED_OUT "ruled_out"
