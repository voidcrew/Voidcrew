///Signal sent when a ship is fully loaded in, with their ships set and all.
///This is best used when you need to connect something to the port, then check the ship through that, on creation.
#define COMSIG_VOIDCREW_SHIP_LOADED "voidcrew_ship_loaded"
/// Signal sent right before the shuttle physically moves to dock (after warmup/loading, before shuttle.request())
#define COMSIG_VOIDCREW_SHIP_ABOUT_TO_DOCK "voidcrew_ship_about_to_dock"
#define COMSIG_VOIDCREW_SHIP_DOCKED "voidcrew_ship_docked"
#define COMSIG_VOIDCREW_SHIP_UNDOCKED "voidcrew_ship_undocked"
#define COMSIG_VOIDCREW_SHIP_MOVED "voidcrew_ship_moved"
/// Signal sent TO the target ship when another ship docks to it (source = docking ship)
#define COMSIG_VOIDCREW_SHIP_DOCKED_BY "voidcrew_ship_docked_by"
/// Signal sent TO the target ship when a ship undocks from it (source = undocking ship)
#define COMSIG_VOIDCREW_SHIP_UNDOCKED_BY "voidcrew_ship_undocked_by"
/// Signal sent when a ship completes surveying a celestial object (args: celestial_type_key)
#define COMSIG_VOIDCREW_SURVEY_COMPLETED "voidcrew_survey_completed"
