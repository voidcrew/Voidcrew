// The lockup as a place on a trader outpost's own map (voidcrew/modules/trade_prison/outpost_prison_host.dm,
// outpost_prison_processing.dm): its lift stop, Processing, the galley and what becomes of its dead.

/// The lift id of the Lockup stop. Berths are 1 to OUTPOST_MAX_BERTHS, ship bays follow them, leased floors are 101 and up.
#define OUTPOST_LIFT_LOCKUP 90

/// Seconds between the galley's rounds: each serving hatch below capacity gains one item a round
#define OUTPOST_PRISON_GALLEY_GAP 60
/// Seconds between looks for a mess to call the wing's idle cleanbot to
#define OUTPOST_PRISON_BOT_CALL_GAP 60
/// Seconds a dead prisoner or guard lies with no client able to see it before it is cleared away
#define OUTPOST_PRISON_BODY_UNSEEN 60
/// Seconds someone leaving through Processing keeps trying, with no client able to see them, before they are gone from where they stand
#define OUTPOST_PRISON_LEAVE_UNSEEN 60
/// Seconds Processing gives an arrival to step out into the yard before the wing stops waiting on them
#define OUTPOST_PRISON_PROCESSING_WAIT 60
/// How far a client mob sees, for "can anyone see this" (a wide screen)
#define OUTPOST_PRISON_SEEN_RANGE 10

/// Processing is shut and empty
#define OUTPOST_PROCESSING_IDLE "idle"
/// Processing is letting an arrival into the yard
#define OUTPOST_PROCESSING_IN "going_in"
/// Processing is taking someone out of the wing
#define OUTPOST_PROCESSING_OUT "going_out"
/// Processing is cycling a member of staff between the front room and the yard
#define OUTPOST_PROCESSING_CROSS "crossing"
/// Processing is walking a newly booked player inmate in from the front room
#define OUTPOST_PROCESSING_BOOK "booking"
/// Processing is cycling a released player inmate out to the front room
#define OUTPOST_PROCESSING_RELEASE "releasing"
/// Processing is cycling a carried-out player inmate back in from the front room
#define OUTPOST_PROCESSING_RETURN "returning"
/// Processing is cycling a visitor in or out one door at a time to recover a dead inmate
#define OUTPOST_PROCESSING_CORPSE "corpse"
/// Processing is taking a live bounty hand-in at the outer door
#define OUTPOST_PROCESSING_CLAIM "claiming"
/// Seconds a hunter may stand inside Processing with a live catch before the warden tells them to step out
#define OUTPOST_PROCESSING_CLAIM_PROMPT 10

/// Trait source for awake-inmate containment resistance
#define OUTPOST_PRISON_INMATE_TRAIT "outpost_prison_inmate"
/// Self-defense window after an inmate is hit first in the cell block
#define OUTPOST_PRISON_INMATE_DEFENSE_WINDOW (10 SECONDS)
/// How long an unprovoked blow or breakout act keeps an inmate flagged for the guard's baton
#define OUTPOST_PRISON_INMATE_BATON_WINDOW (15 SECONDS)
/// Minimum gap between guards remarking on inmate work ("That's time off.")
#define OUTPOST_PRISON_WORK_SAY_GAP (20 SECONDS)

// Inmate work kinds and seconds knocked off sentence (capped at a third of total_seconds)
#define OUTPOST_PRISON_WORK_MOP "mop"
#define OUTPOST_PRISON_WORK_WASH "wash"
#define OUTPOST_PRISON_WORK_LETTER "letter"
#define OUTPOST_PRISON_WORK_WOUND "wound"
#define OUTPOST_PRISON_WORK_CONTRABAND "contraband"

#define OUTPOST_PRISON_WORK_MOP_SECONDS 10
#define OUTPOST_PRISON_WORK_WASH_SECONDS 30
#define OUTPOST_PRISON_WORK_LETTER_SECONDS 20
#define OUTPOST_PRISON_WORK_WOUND_SECONDS 30
#define OUTPOST_PRISON_WORK_CONTRABAND_SECONDS 60
