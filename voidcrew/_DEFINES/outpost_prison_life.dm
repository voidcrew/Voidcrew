// ===== OUTPOST PRISON: FRIENDS, GAMES AND BIRTHDAYS (see outpost_prison_life.dm, outpost_prison_pastimes.dm) =====
// Owner: XD. Values from extras-plan.md 4.4, 4.6, 4.9, 4.12 and 4.13. Everything here moves mood,
// speech and trouble, never pay.

// ----- Friends and rivals (4.4) -----

/// How two prisoners get on runs from this...
#define PRISON_AFFINITY_MIN -100
/// ...to this
#define PRISON_AFFINITY_MAX 100
/// At or above this, two prisoners are friends
#define PRISON_AFFINITY_FRIEND 25
/// At or below this, they are rivals
#define PRISON_AFFINITY_RIVAL -25
/// At or below this, a fight with no other cause is over a grudge
#define PRISON_AFFINITY_GRUDGE -30
/// The most pairs a wing remembers; four prisoners make six
#define PRISON_AFFINITY_MAX_PAIRS 6
/// A finished chat
#define PRISON_AFFINITY_CHAT 4
/// Each pair of diners who got a shared meal's lift
#define PRISON_AFFINITY_SHARED_MEAL 3
/// Each full minute two prisoners play basketball together
#define PRISON_AFFINITY_BASKETBALL 2
/// A spat
#define PRISON_AFFINITY_SPAT -6
/// A fight
#define PRISON_AFFINITY_FIGHT -20
/// Percent chance an arrival crewed with someone already inside...
#define PRISON_CREW_FRIEND_CHANCE 25
/// ...and, failing that, percent chance they fell out with someone inside
#define PRISON_CREW_RIVAL_CHANCE 10
/// How far either way an arrival starts with that prisoner
#define PRISON_CREW_TIE 30
/// Fight chance between rivals, and between friends, as a multiplier
#define PRISON_FIGHT_MULT_RIVAL 1.5
#define PRISON_FIGHT_MULT_FRIEND 0.5
/// How much likelier a spat is between rivals than between any other pair
#define PRISON_SPAT_RIVAL_WEIGHT 3
/// Chat partner weights are 1 + affinity / 25, held between these
#define PRISON_CHAT_WEIGHT_MIN 0.2
#define PRISON_CHAT_WEIGHT_MAX 5
/// Percent chance friends or rivals open with one of their own conversations rather than the usual pool
#define PRISON_TIE_CONVERSATION_CHANCE 70
/// A friend this close to an arguing fighter, at this mood or better, may break it up, with this percent chance, once per fight
#define PRISON_BREAKUP_RANGE 3
#define PRISON_BREAKUP_MOOD 50
#define PRISON_BREAKUP_CHANCE 40
/// Friends this close say goodbye at a release, and it costs them this much mood
#define PRISON_FAREWELL_RANGE 7
#define PRISON_FAREWELL_MOOD 3
/// A stay averaging this care x conditions or better ends in thanks; this or worse, in a bitter word
#define PRISON_RELEASE_THANKS_AVERAGE 0.9
#define PRISON_RELEASE_BITTER_AVERAGE 0.4
/// Seconds after beaming in that an arrival names the crewmate or rival they found inside
#define PRISON_CREW_LINE_DELAY 1

// ----- Cards and dice (4.6) -----

/// Mood for everyone playing at the table, at most once per PRISON_CARDS_MOOD_GAP each
#define PRISON_CARDS_MOOD 3
#define PRISON_CARDS_MOOD_GAP (5 MINUTES)
/// Reputation for a member dealt in, once per game
#define PRISON_CARDS_KINDNESS 0.5
/// Between grumbles about a short deck
#define PRISON_CARDS_MISSING_GAP (10 MINUTES)
/// Hands in a card game
#define PRISON_CARDS_ROUNDS_MIN 3
#define PRISON_CARDS_ROUNDS_MAX 6
/// Percent chance someone at the table says something about a hand
#define PRISON_CARDS_TALK_CHANCE 60
/// Ticks (about seconds) a card game or dice game waits for someone to sit down before it is called off
#define PRISON_GAME_WAIT 15
/// Ticks between the host's calls for players while they wait
#define PRISON_GAME_INVITE_EVERY 5
/// Throws each in a dice game
#define PRISON_DICE_ROUNDS_MIN 2
#define PRISON_DICE_ROUNDS_MAX 3
/// Ticks a thrown die may take to come down before it is read where it lies
#define PRISON_DICE_FLIGHT_STEPS 5
/// The largest table a game or party counts as one, in tiles
#define PRISON_TABLE_MAX_TILES 8

// ----- Birthdays (4.9) -----

/// Percent of arrivals with a birthday
#define PRISON_BIRTHDAY_CHANCE 8
/// Seconds after beaming in that they say so
#define PRISON_BIRTHDAY_LINE_DELAY 10
/// Percent chance a second that a birthday prisoner free to talk brings it up (about a fifth of their idle lines)
#define PRISON_BIRTHDAY_IDLE_CHANCE 2
/// Seconds the cake is kept for the party before it is ordinary food again
#define PRISON_PARTY_RESERVE 600
/// The longest the party holds the floor, in seconds
#define PRISON_PARTY_SCENE_MAX 90
/// Seconds the guests get to sit down before the candles go out
#define PRISON_PARTY_GATHER 15
/// Seconds from the candles to the slices, and from the slices to the thanks
#define PRISON_PARTY_CANDLES_SECONDS 2
#define PRISON_PARTY_EAT_SECONDS 5
/// Mood for the birthday prisoner, and for each guest
#define PRISON_PARTY_HOST_MOOD 20
#define PRISON_PARTY_GUEST_MOOD 8
/// Reputation for whoever brought the cake
#define PRISON_PARTY_KINDNESS 2
/// Guests further than this from the table at serving time miss out
#define PRISON_PARTY_REACH 2

// ----- The courtside crowd (4.12) -----

/// A game with staff is played to this many baskets
#define PRISON_STAFF_GAME_POINTS 5
/// Seconds a game with staff lasts after the last staff shot
#define PRISON_STAFF_GAME_LAPSE 120
/// Mood for each prisoner playing with staff, at most once per PRISON_STAFF_GAME_MOOD_GAP each
#define PRISON_STAFF_GAME_MOOD 5
#define PRISON_STAFF_GAME_MOOD_GAP (5 MINUTES)
/// Between the crowd's cheers and heckles, and between rounds of applause
#define PRISON_CROWD_LINE_GAP (8 SECONDS)
#define PRISON_CROWD_CLAP_GAP (2 SECONDS)
/// Watchers stand this many tiles from the hoop, beside the court
#define PRISON_WATCH_NEAR 2
#define PRISON_WATCH_FAR 4

// ----- Marks on the wall (4.13) -----

/// Marks a cell keeps; the next replaces the oldest
#define PRISON_CELL_MARKS_MAX 4
/// Percent chance an arrival remarks on marks already on their cell's walls
#define PRISON_CELL_MARKS_LINE_CHANCE 30
/// Seconds after beaming in that they do
#define PRISON_CELL_MARKS_LINE_DELAY 6
/// Mood a prisoner loses when the mark they made is scrubbed off
#define PRISON_MARK_SCRUBBED_MOOD 3
/// Seconds between looks for scrubbed marks
#define PRISON_MARK_CHECK_SECONDS 10
/// A prisoner notices their mark gone once they are this close to its wall
#define PRISON_MARK_NOTICE_RANGE 3
/// Ticks (about seconds) of scratching before the mark is done
#define PRISON_MARK_STEPS 5
/// Percent chance a mark is the maker's initial rather than a doodle
#define PRISON_MARK_INITIAL_CHANCE 60
/// Scratched into paint, not drawn in crayon
#define PRISON_MARK_COLOUR "#bdb8ab"
