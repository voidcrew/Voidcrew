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
