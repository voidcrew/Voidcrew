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

/// The chrome keys, one per /datum/bounty_chrome subtype
#define BOUNTY_CHROME_CASCADE "cascade"
#define BOUNTY_CHROME_MANTIS "mantis"
#define BOUNTY_CHROME_GORILLA "gorilla"
#define BOUNTY_CHROME_REDLINE "redline"
#define BOUNTY_CHROME_PILEDRIVER "piledriver"
#define BOUNTY_CHROME_LAZARUS "lazarus"
#define BOUNTY_CHROME_DEADEYE "deadeye"
