// ===== OUTPOST PRISON: WILDCARD INCIDENTS AND WING EVENTS =====
// See outpost_prison_incidents.dm and outpost_prison_wing_events.dm. Owner decision 2026-09-25:
// trouble is not only mood. Even a well kept wing now and then has a stabbing, a prisoner who
// snaps and riots alone, or a fight; mood decides how often and how far it spreads. The wing's
// fixtures also fail now and then: lights blow, a vent backs up, a toilet overflows. None of it
// fines anyone by itself, and every clock here counts only while the crew is home.

// Incidents
/// Seconds of crew-home time per incident roll
#define PRISON_INCIDENT_ROLL_TIME 60
/// Percent chance per roll at tension PRISON_INCIDENT_CALM_TENSION or less, and at PRISON_INCIDENT_TENSE_TENSION.
/// It rises in a straight line between them and on past the second, up to PRISON_INCIDENT_CHANCE_MAX.
/// With PRISON_INCIDENT_GAP between incidents, a calm wing averages one incident per 10 + 100/6.7
/// = about 25 minutes of crew-home time, and a wing at tension 50 one per 10 + 100/20 = 15 minutes.
#define PRISON_INCIDENT_CHANCE_CALM 6.7
#define PRISON_INCIDENT_CHANCE_TENSE 20
#define PRISON_INCIDENT_CHANCE_MAX 30
#define PRISON_INCIDENT_CALM_TENSION 20
#define PRISON_INCIDENT_TENSE_TENSION 50
/// Seconds of crew-home time after an incident before the next can roll; a new wing starts with it
#define PRISON_INCIDENT_GAP 600
/// Prisoners in the cell block an incident needs
#define PRISON_INCIDENT_MIN_PRISONERS 2
/// How likely each kind is (integers)
#define PRISON_INCIDENT_WEIGHT_STAB 3
#define PRISON_INCIDENT_WEIGHT_SNAP 3
#define PRISON_INCIDENT_WEIGHT_FIGHT 4
/// While someone who could do it has a shiv under their mattress, a stabbing is this many times as likely,
/// and they are PRISON_INCIDENT_STASH_PICK_MULT times as likely to be the one: shakedowns cut stabbings
#define PRISON_INCIDENT_STASH_KIND_MULT 2
#define PRISON_INCIDENT_STASH_PICK_MULT 3
/// Seconds of tell before a stabbing or a snap
#define PRISON_INCIDENT_TELL_MIN 12
#define PRISON_INCIDENT_TELL_MAX 18
/// Seconds into the tell of the first mutter
#define PRISON_INCIDENT_MUTTER_AT 3
/// Seconds before the end of the tell that a stabber's hand goes under their shirt, and a snapper hits the wall
#define PRISON_INCIDENT_LAST_TELL 5
/// Seconds before the end of a snap's tell that they start shouting
#define PRISON_INCIDENT_SHOUT_AT 2
/// How close a stabber keeps to the one they are after, in tiles
#define PRISON_INCIDENT_SHADOW_RANGE 2

// Wing events
/// Seconds of crew-home time between wing events
#define PRISON_WING_EVENT_GAP_MIN 1200
#define PRISON_WING_EVENT_GAP_MAX 2400
/// Seconds before trying again when no event could start
#define PRISON_WING_EVENT_RETRY 60
/// How likely each kind is (integers)
#define PRISON_WING_EVENT_WEIGHT_LIGHTS 4
#define PRISON_WING_EVENT_WEIGHT_SCRUBBER 4
#define PRISON_WING_EVENT_WEIGHT_TOILET 2
/// Working lights that blow at once
#define PRISON_WING_LIGHTS_MIN 1
#define PRISON_WING_LIGHTS_MAX 3
/// Seconds a scrubber, vent or toilet gurgles before it backs up
#define PRISON_WING_GURGLE_TIME 5
/// Percent chance a second scrubber overflows along with the first
#define PRISON_OVERFLOW_SECOND_CHANCE 30
/// Units of reagent an overflowing scrubber brings up, and about how many tiles its foam covers (tg's event uses 50 across a station).
/// Each open tile the foam dies on is left with a piece of filth.
#define PRISON_OVERFLOW_FOAM 10
/// Pieces of filth a backed-up Kessler vent spews, and how many steps from a scrubber or vent the mess reaches
#define PRISON_VENT_MESS_MIN 6
#define PRISON_VENT_MESS_MAX 12
#define PRISON_VENT_MESS_RANGE 3
/// How far the smell and the prisoners' reactions reach, in tiles
#define PRISON_WING_EVENT_REACT_RANGE 5
/// Most prisoners who remark on a wing event
#define PRISON_WING_EVENT_MAX_LINES 2
/// How long an overflowing toilet leaves its cell's floor wet (it only slips people who run)
#define PRISON_TOILET_WET_TIME (30 SECONDS)
/// Dirt an overflowing toilet leaves in its cell
#define PRISON_TOILET_GRIME_MIN 1
#define PRISON_TOILET_GRIME_MAX 2
