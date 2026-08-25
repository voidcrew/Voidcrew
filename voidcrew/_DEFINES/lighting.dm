/**
 * Ambient bleed - see voidcrew/edits/lighting.dm.
 *
 * These two numbers are the only tuning knobs the mechanism has, and neither of them is
 * a brightness. Brightness is always derived from the area being bled from, so a dim
 * orange lava planet gets a dim orange edge and a bright beach gets a bright warm one.
 *
 * Both were calibrated against the real corner falloff, not intuition:
 * falloff_at_coord() gives a corner at distance d from a turf light (light_height 0)
 * a multiplier of (1 - d / range). A turf's own corners sit at sqrt(0.5) ~= 0.707, the
 * next ring out at ~1.58. First calibration used range 1.4 / divisor 3 and rendered
 * near-black: at range 1.4 the own-corner multiplier is only 0.495, the second ring is
 * out of range entirely, and a straight-boundary corner is inside just TWO edge sources
 * (the diagonals fall outside 1.4) - peak lum ~0.26 against an ambient of ~0.78.
 */

/// Range of an ambient bleed light source. 1.85 puts the source turf's own corners at a
/// 0.618 falloff multiplier and keeps the second corner ring (~1.58) faintly inside
/// range, so the static side of a boundary gets a real two-step gradient instead of a
/// one-corner smudge. It also doubles as the marker that a turf's light is one of ours -
/// no turf type in the codebase declares a light range below 1.9 (space itself declares
/// exactly 2) - so a self-lit turf like lava or a chasm is never clobbered. Keep it
/// BELOW 1.9 for that reason.
#define AMBIENT_BLEED_RANGE 1.85

/// Divisor applied to the area's own brightness when deriving an edge light's power.
/// A lighting corner on the static side of a straight boundary sits inside two edge
/// sources, each contributing at the 0.618 own-corner multiplier: 2 x 0.618 = 1.24. So
/// dividing the target brightness by 1.25 makes the boundary corner's summed lum land on
/// the area's own ambient level - continuous with the daylight, not a halo above it. An
/// inside corner stacks a third source and saturates slightly (normalising to the same
/// hue, so it reads brighter-not-wrong); an outside corner stacks less and reads softer.
#define AMBIENT_BLEED_OVERLAP_FACTOR 1.25

/**
 * Ruin daylight - see /obj/structure/overmap/planet/proc/light_ruin_terrain.
 *
 * A ruin brings its own areas, and those areas are statically lit on purpose: darkness
 * inside a ruin is a mechanic. But a ruin footprint is not all interior. The yard around
 * a hunting lodge, the snow an ore vent sits in, the strip of ground a mining site is
 * pitched on - all of that is mapped into the ruin's own OUTDOOR areas, and it is open to
 * the sky. Before this experiment it was daylit for free, because the planet ground
 * around it was made of /lit turfs whose range-2 light reached in. Ambient area lighting
 * does not reach in at all: it is painted on the SURFACE area and stops at its border.
 *
 * So the ground inside an outdoor ruin area gets the daylight put back on the turf, which
 * is what these two numbers describe. It is the same light the /lit biome turfs emitted,
 * because it is standing in for exactly them - and a few hundred turfs per planet is a
 * rounding error against the ~14,000 the surface used to carry.
 */

/// Range of a ruin-ground daylight source, matching the /lit biome turfs it replaces
/// (all of them declared range 2). Being >= 1.9 also marks it as "this turf lights
/// itself" to ambient bleed and skips_lighting_object(), which is exactly right - it
/// must never be mistaken for a bleed light and switched off.
#define RUIN_DAYLIGHT_RANGE 2

/// Power of a ruin-ground daylight source, as a fraction of the planet's own ambient
/// alpha. At the stock alpha of 255 this is power 1, which is what the /lit turfs used,
/// and it keeps ruin ground level with the surface if the planet is ever tuned dimmer.
#define RUIN_DAYLIGHT_POWER(alpha) ((alpha) / 255)
