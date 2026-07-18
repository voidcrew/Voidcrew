// Voidcrew dynamic events — ship-scoped ports of /tg/ random events.
// See voidcrew/modules/dynamic_events/ and voidcrew/GUIDES/dynamic_events_port_spec.md

/// Event picks one crewed ship and confines all effects to that ship's shuttle areas.
#define EVENT_SCOPE_SHIP "ship"
/// Event has no single victim — it touches galaxy-wide systems (economy, comms, fluff).
#define EVENT_SCOPE_GALAXY "galaxy"

/// Immunity window after a ship is hit by a dynamic event, so one crew isn't hammered back to back.
#define DYNAMIC_EVENT_SHIP_COOLDOWN (4 MINUTES)
