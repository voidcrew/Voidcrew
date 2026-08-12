// Voidcrew dynamic events: ship-scoped ports of /tg/ random events.
// See voidcrew/modules/dynamic_events/ and voidcrew/GUIDES/dynamic_events_port_spec.md

/// Event picks one crewed ship and confines all effects to that ship's shuttle areas.
#define EVENT_SCOPE_SHIP "ship"
/// Event has no single victim, it touches galaxy-wide systems (economy, comms, fluff).
#define EVENT_SCOPE_GALAXY "galaxy"

/// Default immunity window after a ship is hit by a dynamic event, so one crew isn't
/// hammered back to back. This is a hard floor under the per-crew cadence, not the
/// cadence itself, SSdynamic_events.frequency_lower/upper set the intended spacing.
/// The live value is SSdynamic_events.ship_cooldown, which admins can tune mid-round.
#define DYNAMIC_EVENT_SHIP_COOLDOWN (20 MINUTES)

/**
 * Size bands for /datum/round_event_control/voidcrew/var/min_ship_mass.
 *
 * The unit is ship mass. The weighted shuttle-turf count maintained by
 * /obj/structure/overmap/ship/proc/calculate_mass() (reinforced wall 3, wall 2,
 * everything else 1, space 0). It measures how much hull the crew actually has to
 * survive an event in, which is the thing that matters here and is not the same
 * question as how many people are aboard.
 *
 * Mass tracks the hull as it currently stands rather than as it was mapped, so a
 * vessel that has been blown open counts as smaller than its intact self. That is
 * deliberate: a gutted ship deserves the same reprieve a small one gets.
 *
 * Measured across the fleet for scale: Pill-class 3, Goon-class ~270 with its modules
 * loaded, Kilo-class ~380, Delta-class ~550, Phalanx-class ~1400.
 */
/// No size requirement. The framework default.
#define SHIP_MASS_ANY 0
/// Anything larger than a Pill-class. Three tiles and an engine is not a hull you can
/// fight a fire, a boarder or a breach on, one pod ends the round for everyone aboard.
#define SHIP_MASS_SMALL 50
/// Goon-class and up: a real hull, with an airlock, compartments and somewhere to fall back to.
#define SHIP_MASS_MEDIUM 150
/// Delta-class and up. For the events that need real distance to be survivable at all.
#define SHIP_MASS_LARGE 400
