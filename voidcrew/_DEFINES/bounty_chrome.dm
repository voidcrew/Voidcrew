// ===== BOUNTY CHROME (voidcrew/modules/bounties/bounty_chrome.dm) =====

/// Percent chance a criminal of each tier carries chrome at all
#define BOUNTY_CHROME_CHANCE_PETTY 10
#define BOUNTY_CHROME_CHANCE_WANTED 35
#define BOUNTY_CHROME_CHANCE_MOST_WANTED 60
/// Percent chance a Wanted or Most Wanted carrier has a second piece, if one fits
#define BOUNTY_CHROME_SECOND_CHANCE 30
/// A companion's chance is its criminal's tier chance divided by this, and it carries one piece at most
#define BOUNTY_CHROME_COMPANION_DIVISOR 3
/// The archetype a companion rolls chrome as (the criminal archetypes are BOUNTY_ARCHETYPE_*)
#define BOUNTY_CHROME_COMPANION "companion"

/// The chrome keys, one per /datum/bounty_chrome_piece subtype
#define BOUNTY_CHROME_CASCADE "cascade"
#define BOUNTY_CHROME_MANTIS "mantis"
#define BOUNTY_CHROME_GORILLA "gorilla"
#define BOUNTY_CHROME_REDLINE "redline"
#define BOUNTY_CHROME_PILEDRIVER "piledriver"
#define BOUNTY_CHROME_LAZARUS "lazarus"
#define BOUNTY_CHROME_DEADEYE "deadeye"

/// The shortest tell a chrome move may have before it fires the implant (owner decision 5)
#define BOUNTY_CHROME_TELL_MIN (0.8 SECONDS)
/// After a fight starts, how long before the first chrome move may start
#define BOUNTY_CHROME_OPENING (1.5 SECONDS)
/// The shortest gap between two chrome moves of one NPC
#define BOUNTY_CHROME_MOVE_GAP (4 SECONDS)
/// The outline a tell shows, unless the move picks its own colour
#define BOUNTY_CHROME_TELL_COLOR "#ff2079"
/// Trait source for standing still through a tell
#define BOUNTY_CHROME_TRAIT "bounty_chrome"

/// Why a tell was cut short (/datum/bounty_chrome_move/proc/cancel())
#define BOUNTY_CHROME_CANCEL_DOWNED "downed"
#define BOUNTY_CHROME_CANCEL_STUNNED "stunned"
#define BOUNTY_CHROME_CANCEL_RESTRAINED "restrained"
#define BOUNTY_CHROME_CANCEL_EMP "emp"
#define BOUNTY_CHROME_CANCEL_DEATH "death"
#define BOUNTY_CHROME_CANCEL_GONE "gone"

/// Sent on a carbon whose chrome a pair of cyber optics just read, if it felt the read (cyberware_scan.dm): (mob/living/carbon/reader)
#define COMSIG_CARBON_CHROME_READ "carbon_chrome_read"
/// How soon a bounty NPC answers another chrome read after answering one
#define BOUNTY_CHROME_READ_NOTICE_COOLDOWN (20 SECONDS)

/// A malfunction (bounty_chrome_malfunction_fx()): how often it twitches and spits sparks, its outline's name, and its chrome blue
#define BOUNTY_CHROME_MALFUNCTION_PULSE (0.4 SECONDS)
#define BOUNTY_CHROME_MALFUNCTION_FILTER "bounty_chrome_malfunction"
#define BOUNTY_CHROME_MALFUNCTION_COLOR "#7fd4ff"
/// A colour matrix turning tg's yellow arcs a hot chrome blue, their brightest parts near white
#define BOUNTY_CHROME_MALFUNCTION_MATRIX list(0.25, 0.45, 0.55, 0.25, 0.45, 0.55, 0.25, 0.45, 0.55, 0, 0, 0)

/// The Bounty Panel's chrome choices (bounty_admin.dm): roll it as usual, or every piece that fits
#define BOUNTY_ADMIN_CHROME_ROLL "roll"
#define BOUNTY_ADMIN_CHROME_ALL "all"
