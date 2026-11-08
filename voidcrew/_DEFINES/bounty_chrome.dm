// ===== BOUNTY CHROME (voidcrew/modules/bounties/bounty_chrome.dm) =====

/// Percent chance a criminal of each tier carries any chrome at all
#define BOUNTY_CHROME_CHANCE_PETTY 10
#define BOUNTY_CHROME_CHANCE_WANTED 35
#define BOUNTY_CHROME_CHANCE_MOST_WANTED 60
/// Percent chance a Wanted or Most Wanted criminal with chrome carries a second piece
#define BOUNTY_CHROME_SECOND_CHANCE 30
/// A companion's chance is its criminal's tier chance divided by this, and it never carries more than one piece
#define BOUNTY_CHROME_COMPANION_DIVISOR 3
/// How long a piece stays down after an EMP, unless the piece says otherwise
#define BOUNTY_CHROME_EMP_REBOOT (8 SECONDS)

/// The archetype a companion rolls chrome as (the criminal archetypes are BOUNTY_ARCHETYPE_*)
#define BOUNTY_CHROME_COMPANION "companion"

/// A malfunction (bounty_chrome_malfunction_fx()): how often it twitches and spits sparks, its outline's name, and its chrome blue
#define BOUNTY_CHROME_MALFUNCTION_PULSE (0.4 SECONDS)
#define BOUNTY_CHROME_MALFUNCTION_FILTER "bounty_chrome_malfunction"
#define BOUNTY_CHROME_MALFUNCTION_COLOR "#7fd4ff"
/// A colour matrix turning tg's yellow arcs a hot chrome blue, their brightest parts near white
#define BOUNTY_CHROME_MALFUNCTION_MATRIX list(0.25, 0.45, 0.55, 0.25, 0.45, 0.55, 0.25, 0.45, 0.55, 0, 0, 0)

/// The chrome keys, one per /datum/bounty_chrome subtype
#define BOUNTY_CHROME_CASCADE "cascade"
#define BOUNTY_CHROME_MANTIS "mantis"
#define BOUNTY_CHROME_GORILLA "gorilla"
#define BOUNTY_CHROME_REDLINE "redline"
#define BOUNTY_CHROME_PILEDRIVER "piledriver"
#define BOUNTY_CHROME_LAZARUS "lazarus"
#define BOUNTY_CHROME_DEADEYE "deadeye"

/// The admin spawn menu's "roll chrome as usual" choice (bounty_admin.dm)
#define BOUNTY_ADMIN_CHROME_ROLL "roll"
