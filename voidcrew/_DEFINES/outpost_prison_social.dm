// ===== OUTPOST PRISON: STAFF REPUTATION AND THE TALK MENU (see outpost_prison_social.dm, outpost_prison_warden_tools.dm) =====
// Owner: XC. Values from extras-plan.md 4.3 and 4.8. Reputation never changes mood or pay; it
// moves who gets threatened, how well a talk works and whom rioters go for.

// ----- The record -----

/// A member's score runs from PRISON_REP_MIN to PRISON_REP_MAX
#define PRISON_REP_MIN -10
#define PRISON_REP_MAX 10
/// Records a wing keeps; past this the least recently seen member is forgotten
#define PRISON_REP_RECORDS 20
/// Every PRISON_REP_DECAY_SECONDS each score moves PRISON_REP_DECAY toward 0
#define PRISON_REP_DECAY_SECONDS 600
#define PRISON_REP_DECAY 1

// ----- What moves it -----

/// Feeding, clothing or treating a prisoner by hand: once per prisoner per PRISON_REP_CARE_GAP for each member
#define PRISON_REP_CARE 1
#define PRISON_REP_CARE_GAP (5 MINUTES)
/// Stocking a serving hatch: once per PRISON_REP_STOCK_GAP for each member
#define PRISON_REP_STOCK 0.5
#define PRISON_REP_STOCK_GAP (5 MINUTES)
/// A talk-down that worked (the talk's own cooldown limits it)
#define PRISON_REP_TALK 1
/// A basket sunk while prisoners played (the basket's own cooldown limits it)
#define PRISON_REP_BASKET 1
/// The most one kindness from another package (a card game, a cake) may add
#define PRISON_REP_KINDNESS_MAX 2
/// An unprovoked hit that cost the prisoner mood
#define PRISON_REP_HIT -3
/// An unprovoked beating down, on top of the hits
#define PRISON_REP_BEATEN -3
/// XF's events (note_staff_event()); mail_delivered counts once per prisoner per stay
#define PRISON_REP_MAIL_DELIVERED 0.5
#define PRISON_REP_MAIL_OPENED -1
#define PRISON_REP_SEARCH_FOUND 0
#define PRISON_REP_SEARCH_EMPTY -1
#define PRISON_REP_PATDOWN_FOUND 0
#define PRISON_REP_PATDOWN_EMPTY -0.5

// ----- Labels -----

/// "fair" from this score up, "brute" from PRISON_REP_BRUTE down
#define PRISON_REP_FAIR 5
#define PRISON_REP_BRUTE -5
/// Below this many interactions, and within PRISON_REP_KNOWN_SCORE of 0, a member is still a stranger
#define PRISON_REP_KNOWN_INTERACTIONS 3
#define PRISON_REP_KNOWN_SCORE 1

// ----- What it does -----

/// Prisoners square up to a fair member only below this mood, and to a brute below PRISON_REP_THREAT_BRUTE (anyone else: PRISONER_THREAT_MOOD)
#define PRISON_REP_THREAT_FAIR 25
#define PRISON_REP_THREAT_BRUTE 45
/// A talk-down from a fair member gives this much mood instead of PRISONER_MOOD_TALK
#define PRISON_REP_TALK_MOOD_FAIR 12
/// A brute's talk-down is refused below this mood
#define PRISON_REP_REFUSE_BRUTE_BELOW 50
/// Rioters picking whom to go for count a brute this many tiles nearer and a fair member this many farther
#define PRISON_REP_RIOT_BRUTE_NEARER 3
#define PRISON_REP_RIOT_FAIR_FARTHER 2
/// Percent chance a prisoner about to speak greets someone within PRISON_REP_GREET_RANGE tiles, once per person per PRISON_REP_GREET_GAP
#define PRISON_REP_GREET_CHANCE 30
#define PRISON_REP_GREET_RANGE 5
#define PRISON_REP_GREET_GAP (3 MINUTES)
/// Percent of arrivals who say what they heard about the most notable member at home, PRISON_REP_WORD_DELAY seconds after beaming in
#define PRISON_REP_WORD_CHANCE 50
#define PRISON_REP_WORD_DELAY 10
/// Seconds an arrival waits for a quiet moment to say it before they let it go
#define PRISON_REP_WORD_WAIT 60

// ----- The talk menu -----

/// The menu's own choices, as the radial names them
#define PRISON_TALK_HOW "How are you doing?"
#define PRISON_TALK_CRIME "What are you in for?"
/// Back to their cell; not offered in cuffs
#define PRISON_TALK_CELL "Back to your cell"
/// Offered only while they lie, sit or crouch
#define PRISON_TALK_GET_UP "Get up"
/// A talk-down (talk_down()), offered while they will listen
#define PRISON_TALK_CALM "Calm down"
/// Offered only while they are cuffed
#define PRISON_TALK_UNCUFF "Uncuff"
/// How long each choice's talk takes
#define PRISON_TALK_MENU_TIME (1.5 SECONDS)
/// Between answers to each question, per prisoner
#define PRISON_TALK_ASK_GAP (30 SECONDS)
/// Mood from being asked what they're in for, once per stay
#define PRISON_TALK_CRIME_MOOD 3
/// Between orders back to the cell, per prisoner
#define PRISON_TALK_ORDER_GAP (60 SECONDS)
/// The PRISON_TALK_ORDER_SPAM_COUNT-th order inside PRISON_TALK_ORDER_SPAM_WINDOW costs PRISON_TALK_ORDER_SPAM_MOOD and is refused
#define PRISON_TALK_ORDER_SPAM_WINDOW (5 MINUTES)
#define PRISON_TALK_ORDER_SPAM_COUNT 3
#define PRISON_TALK_ORDER_SPAM_MOOD 2
/// A prisoner goes back to their cell at or above this mood, by personality
#define PRISON_TALK_ORDER_LINE 40
#define PRISON_TALK_ORDER_LINE_GRUMPY 55
#define PRISON_TALK_ORDER_LINE_CHATTY 45
#define PRISON_TALK_ORDER_LINE_QUIET 40
#define PRISON_TALK_ORDER_LINE_CHEERFUL 35
#define PRISON_TALK_ORDER_LINE_NERVOUS 30
/// The line moves by this for a fair member and a brute
#define PRISON_TALK_ORDER_FAIR_SHIFT -10
#define PRISON_TALK_ORDER_BRUTE_SHIFT 15
/// How long a prisoner sent back sits in their cell's chair (or on its bed)
#define PRISON_SENT_TO_CELL_MIN (60 SECONDS)
#define PRISON_SENT_TO_CELL_MAX (90 SECONDS)
/// How long a prisoner told to get up stays where they stepped, so staff can search the bed
#define PRISON_TALK_GET_UP_HOLD (10 SECONDS)
/// Mood a sleeping prisoner loses when staff shake them awake
#define PRISON_TALK_WAKE_MOOD 3
/// How long a calm prisoner stays where they were left after a pull, before carrying on
#define PRISON_PULL_RELEASE_HOLD (3 SECONDS)
