#define COMSIG_VOIDCREW_PLANET_LOADED "voidcrew_planet_loaded"

/// Sent on a space ruin as its interior is torn down, BEFORE the reservation is
/// freed and while the signal object itself lives on. Anything holding a claim on
/// the site (a live contract with an objective standing in there) gets its chance
/// to let go of what is about to be wiped, instead of reading the wipe as a loss.
#define COMSIG_VOIDCREW_RUIN_UNLOADING "voidcrew_ruin_unloading"

/// Sent by every site load_level() on EVERY exit past the point where it claimed the
/// job (success AND failure: queue timeout, reservation failure, template failure).
/// Arg is TRUE on success, FALSE on failure. Distinct from COMSIG_VOIDCREW_PLANET_LOADED,
/// which only ever fires on success and has listeners (missions, survey consoles) whose
/// semantics must not change - ships waiting to auto-resume a docking approach listen to
/// this one instead (see /obj/structure/overmap/ship/proc/request_site_load).
#define COMSIG_VOIDCREW_SITE_LOAD_FINISHED "voidcrew_site_load_finished"

/**
 * Smallest a planet's bounded region may be.
 *
 * Two reserve docks sit side by side along the bottom edge, so the width has to
 * cover padding + dock + padding + dock + padding:
 * (RESERVE_DOCK_DEFAULT_PADDING * 3) + (RESERVE_DOCK_MAX_SIZE_LONG * 2) + border.
 * set_bounds() clamps to this, so a planet_size below it silently rounds up.
 */
#define PLANET_MIN_SIZE 123

/// Turfs of breathing room left around the reserve docks that ruins may not be placed in.
/// Matches EVENT_FIELD_DOCK_CLEARANCE - a ship parked flush against a ruin wall is as bad
/// as one parked on top of it.
#define PLANET_DOCK_RUIN_CLEARANCE 3

/// How long after the last ship undocks before an abandoned planet releases its z-levels
#define PLANET_DESPAWN_TIMER 5 MINUTES
