#define COMSIG_VOIDCREW_PLANET_LOADED "voidcrew_planet_loaded"

/**
 * Smallest a planet's bounded region may be.
 *
 * Two reserve docks sit side by side along the bottom edge, so the width has to
 * cover padding + dock + padding + dock + padding:
 * (RESERVE_DOCK_DEFAULT_PADDING * 3) + (RESERVE_DOCK_MAX_SIZE_LONG * 2) + border.
 * set_bounds() clamps to this, so a planet_size below it silently rounds up.
 */
#define PLANET_MIN_SIZE 123

/// How long after the last ship undocks before an abandoned planet releases its z-levels
#define PLANET_DESPAWN_TIMER 5 MINUTES
