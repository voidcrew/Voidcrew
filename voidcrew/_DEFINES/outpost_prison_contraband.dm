// ===== OUTPOST PRISON: CONTRABAND AND MAIL (see outpost_prison_contraband.dm, outpost_prison_mail.dm) =====
// Owner: XF. Values from extras-plan.md 4.14 and 4.15. Neither pays or costs credits. Stashes form
// only from sustained unhappiness (or unopened contraband mail) while someone is on the level to
// see the tells; a shiv stash only matters in a riot (decision 8: shivs come out in riots only).

// ----- Stashes -----
/// Seconds between rolls for making a shiv or brewing, and between looks at the cells' beds and toilets
#define OUTPOST_CONTRABAND_CLOCK 30
/// Below this mood, held for OUTPOST_CONTRABAND_SOUR_TIME, a prisoner may make a shiv
#define OUTPOST_CONTRABAND_SHIV_MOOD 40
/// At or above this mood the sour clock resets
#define OUTPOST_CONTRABAND_SOUR_RESET 45
/// Seconds under OUTPOST_CONTRABAND_SHIV_MOOD before the first try
#define OUTPOST_CONTRABAND_SOUR_TIME 300
/// Percent chance per minute of starting a shiv, with no staff in sight
#define OUTPOST_CONTRABAND_SHIV_CHANCE 10
/// Seconds of scraping on the bed edge before the shiv goes under the mattress
#define OUTPOST_CONTRABAND_SHIV_TIME 25
/// Seconds between scrapes while they sharpen it
#define OUTPOST_CONTRABAND_SCRAPE_GAP 4
/// How far a prisoner making or stashing contraband watches for staff
#define OUTPOST_CONTRABAND_WATCH_RANGE 7
/// Below this mood, held for OUTPOST_CONTRABAND_BREW_SOUR_TIME, a prisoner may brew pruno
#define OUTPOST_CONTRABAND_BREW_MOOD 55
#define OUTPOST_CONTRABAND_BREW_RESET 60
#define OUTPOST_CONTRABAND_BREW_SOUR_TIME 180
/// Percent chance per minute of brewing, with no staff in sight
#define OUTPOST_CONTRABAND_BREW_CHANCE 8
/// Seconds at the toilet tank to start a bag of pruno, and to drink one
#define OUTPOST_CONTRABAND_BREW_TIME 6
#define OUTPOST_CONTRABAND_DRINK_TIME 5
/// Weight of drinking a fermented bag from their own cistern, while under OUTPOST_CONTRABAND_DRINK_MOOD
#define OUTPOST_CONTRABAND_DRINK_WEIGHT 6
#define OUTPOST_CONTRABAND_DRINK_MOOD 70
/// Mood the drinker gains, once
#define OUTPOST_CONTRABAND_PRUNO_MOOD 8
/// Seconds drunk after a bag of pruno
#define OUTPOST_CONTRABAND_DRUNK_TIME 120
/// Seconds between a drunk's sways, at random between these
#define OUTPOST_CONTRABAND_SWAY_MIN 10
#define OUTPOST_CONTRABAND_SWAY_MAX 20
/// Fight chance multiplier when either prisoner is drunk, and the wing's spat chance multiplier while anyone is
#define OUTPOST_CONTRABAND_DRUNK_FIGHT_MULT 1.5
#define OUTPOST_CONTRABAND_DRUNK_SPAT_MULT 2
/// Tension each shiv hidden in an occupied cell adds, and the most all of them add
#define OUTPOST_CONTRABAND_SHIV_TENSION 2
#define OUTPOST_CONTRABAND_TENSION_MAX 4
/// How much higher a shiv stash's owner's riot line is
#define OUTPOST_CONTRABAND_RIOT_JOIN_BONUS 10
/// Percent chance a new arrival remarks on the stash the last occupant left, and how long after arriving
#define OUTPOST_CONTRABAND_INHERIT_CHANCE 50
#define OUTPOST_CONTRABAND_INHERIT_DELAY (10 SECONDS)

// ----- Searches -----
/// A mattress search and a pat-down take this long
#define OUTPOST_CONTRABAND_SEARCH_TIME (4 SECONDS)
/// Mood the cell's owner loses when a search finds something, and when it finds nothing
#define OUTPOST_CONTRABAND_FOUND_MOOD 3
#define OUTPOST_CONTRABAND_EMPTY_MOOD 6
/// Mood each other prisoner who sees an empty search loses
#define OUTPOST_CONTRABAND_ONLOOKER_MOOD 1
/// Mood a pat-down that finds nothing costs
#define OUTPOST_CONTRABAND_PATDOWN_MOOD 3
/// A cell's search, or a prisoner's pat-down, costs mood at most once per this
#define OUTPOST_CONTRABAND_SEARCH_GAP (5 MINUTES)
/// Percent chance another prisoner within OUTPOST_CONTRABAND_ONLOOKER_RANGE speaks up for someone patted down for nothing
#define OUTPOST_CONTRABAND_PATDOWN_ONLOOKER_CHANCE 20
#define OUTPOST_CONTRABAND_ONLOOKER_RANGE 5

// ----- Mail -----
/// Between mail pods, counted only while the crew is home
#define OUTPOST_MAIL_WAVE_GAP_MIN (15 MINUTES)
#define OUTPOST_MAIL_WAVE_GAP_MAX (25 MINUTES)
/// Percent of the prisoners present a mail pod brings letters for, at random between these (at least one, never all)
#define OUTPOST_MAIL_WAVE_SHARE_MIN 33
#define OUTPOST_MAIL_WAVE_SHARE_MAX 50
/// Seconds of sentence a prisoner needs left to get a letter; one letter per stay
#define OUTPOST_MAIL_MIN_SENTENCE 180
/// An undelivered letter is returned (deleted) after this long with the crew home, and its prisoner loses OUTPOST_MAIL_EXPIRED_MOOD
#define OUTPOST_MAIL_EXPIRY (15 MINUTES)
#define OUTPOST_MAIL_EXPIRED_MOOD 3
/// Letter kinds by weight, and the mood each gives the reader (contraband reads as news)
#define OUTPOST_MAIL_WEIGHT_GOOD 30
#define OUTPOST_MAIL_WEIGHT_KID 15
#define OUTPOST_MAIL_WEIGHT_NEWS 20
#define OUTPOST_MAIL_WEIGHT_BAD 25
#define OUTPOST_MAIL_WEIGHT_CONTRABAND 10
#define OUTPOST_MAIL_MOOD_GOOD 8
#define OUTPOST_MAIL_MOOD_KID 10
#define OUTPOST_MAIL_MOOD_NEWS 4
#define OUTPOST_MAIL_MOOD_BAD -8
/// Extra mood a prisoner loses reading a letter someone opened first
#define OUTPOST_MAIL_OPENED_MOOD 6
/// Percent of contraband letters that feel hard on examine
#define OUTPOST_MAIL_HARD_TELL 70
/// Percent of contraband letters carrying a razor blade (a shiv stash); the rest carry yeast (pruno)
#define OUTPOST_MAIL_RAZOR_CHANCE 60
/// How long a prisoner takes to read a letter handed to them
#define OUTPOST_MAIL_READ_TIME (3 SECONDS)
/// Seconds a prisoner sits in their cell's chair (or on its bed) after bad news, at random between these
#define OUTPOST_MAIL_MULL_MIN 30
#define OUTPOST_MAIL_MULL_MAX 60
/// Percent of a prisoner's extra speech picks that ask after a waiting letter, with a member within OUTPOST_MAIL_ASK_RANGE
#define OUTPOST_MAIL_ASK_CHANCE 15
#define OUTPOST_MAIL_ASK_RANGE 5
/// Seconds between checks of where the letters are (off the level, on a hatch)
#define OUTPOST_MAIL_CHECK 5
