// ===== OUTPOST PRISON: INTERROGATION AND LEADS (see outpost_prison_leads.dm) =====
// Owner: XG. Values from extras-plan.md 4.16. A lead is a Rumors waypoint on the asker's ship: an
// uncharted ruin that already exists, never new loot and never credits. Lies are the owner's
// approved exception to "deceptions are atmosphere": only unhappy prisoners lie, and every lie can
// be caught before or during the flight.

/// Percent of arrivals who carry a lead
#define OUTPOST_PRISON_LEAD_CHANCE 30
/// A wing gives at most one lead (true or not) per this, stored as a ready time never shortened
#define OUTPOST_PRISON_LEAD_GAP (40 MINUTES)
/// Face to face for this long to ask
#define OUTPOST_PRISON_LEAD_ASK_TIME (3 SECONDS)
/// Between questions to one prisoner
#define OUTPOST_PRISON_LEAD_ASK_COOLDOWN (2 MINUTES)
/// At or above this mood a prisoner never lies
#define OUTPOST_PRISON_LEAD_TRUE_MOOD 70
/// Below this mood the lie chance is OUTPOST_PRISON_LEAD_LIE_HOSTILE, else OUTPOST_PRISON_LEAD_LIE_UNEASY
#define OUTPOST_PRISON_LEAD_HOSTILE_MOOD 40
#define OUTPOST_PRISON_LEAD_LIE_UNEASY 15
#define OUTPOST_PRISON_LEAD_LIE_HOSTILE 50
/// Below this mood they refuse, and keep the lead
#define OUTPOST_PRISON_LEAD_REFUSE_MOOD 25
/// Percentage points added to the lie chance for a "brute" asker, and taken off for a "fair" one
#define OUTPOST_PRISON_LEAD_BRUTE_LIE 20
#define OUTPOST_PRISON_LEAD_FAIR_LIE 10
/// The lie chance is scaled by these for grumpy and for nervous prisoners, after the asker's reputation
#define OUTPOST_PRISON_LEAD_GRUMPY_LIE_MULT 1.3
#define OUTPOST_PRISON_LEAD_NERVOUS_LIE_MULT 0.7
/// A prisoner the asker hit unprovoked within this refuses
#define OUTPOST_PRISON_LEAD_HIT_MEMORY (10 MINUTES)
/// Percent chance a liar shows a tell when answering, and that someone telling the truth shows the same tell
#define OUTPOST_PRISON_LEAD_TELL_LIE 60
#define OUTPOST_PRISON_LEAD_TELL_TRUTH 10
/// Percent chance a prisoner who saw a lead given chips in about it, and the mood they need to
#define OUTPOST_PRISON_LEAD_GOSSIP_CHANCE 50
#define OUTPOST_PRISON_LEAD_GOSSIP_MOOD 50
/// How far a gossip must see both the teller and the asker, and how long after the tip they chip in
#define OUTPOST_PRISON_LEAD_GOSSIP_RANGE 7
#define OUTPOST_PRISON_LEAD_GOSSIP_DELAY_MIN (5 SECONDS)
#define OUTPOST_PRISON_LEAD_GOSSIP_DELAY_MAX (10 SECONDS)
/// After a lead, other prisoners can be asked about it for this long; at OUTPOST_PRISON_LEAD_GOSSIP_MOOD or more they answer truly
#define OUTPOST_PRISON_LEAD_VOUCH_TIME (20 MINUTES)
/// Percent of a carrier's extra speech picks that hint at what they know, while a member is this close
#define OUTPOST_PRISON_LEAD_HINT_CHANCE 20
#define OUTPOST_PRISON_LEAD_HINT_RANGE 5
/// A caught liar owns up once the asker is this close
#define OUTPOST_PRISON_LEAD_CAUGHT_RANGE 5
/// Seconds between checks of open lies against the asking ships' positions
#define OUTPOST_PRISON_LEAD_CHECK_INTERVAL 10
/// Open leads a wing keeps track of, and for how long
#define OUTPOST_PRISON_LEAD_OPEN_MAX 5
#define OUTPOST_PRISON_LEAD_TRACK_TIME (60 MINUTES)
// Where a lie points: an empty overmap tile with no ruin, planet or outpost within SHIP_VIEW_RANGE,
// out of the asking ship's sight, in a band drawn with the true candidates' weights. Every tile is
// checked in one pass against a grid stamped from the sites; with no tile clear, they tell the
// truth. Hazard fields cover hundreds of overmap tiles, so "nothing at all in sight" would almost
// never find a spot, and a tip in empty void would give the lie away by itself.
