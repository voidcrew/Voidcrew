// Planet landing view (voidcrew/modules/landing_animation): what a crew sees around their hull while it lands
// on a planet or leaves one.

/// The plane the view draws on: over space and its parallax, under the whole world. Cut to
/// LANDING_VIEW_MASK_PLANE, so it only shows on tiles the viewer can really see.
#define LANDING_VIEW_PLANE -19
/// Draws nothing itself. Whatever is on it becomes the mask LANDING_VIEW_PLANE is cut to.
#define LANDING_VIEW_MASK_PLANE -44
#define LANDING_VIEW_MASK_RENDER_TARGET "*LANDING_VIEW_MASK"
/// A white tile on every turf of transit space around a landing hull, and none on the hull: what the ground's light is cut to
#define LANDING_VIEW_OUTSIDE_PLANE -43
#define LANDING_VIEW_OUTSIDE_RENDER_TARGET "*LANDING_VIEW_OUTSIDE"
/// The light on the ground in the landing view, laid over the lighting of the transit space around the hull
#define LANDING_VIEW_LIGHT_PLANE 18

/// The sky's textures, and their size in pixels
#define LANDING_VIEW_ICON 'voidcrew/icons/effects/landing_view.dmi'
#define LANDING_VIEW_ICON_SIZE 480

// Layers on LANDING_VIEW_PLANE, back to front. Pictures locked to the world are images; BYOND draws those
// under every screen object on the same plane, whatever their layers.
/// The real ground, far below
#define LANDING_VIEW_LAYER_GROUND 10
/// The hull's shadow on that ground
#define LANDING_VIEW_LAYER_SHADOW 11
/// Deep space, covering the starfield
#define LANDING_VIEW_LAYER_SPACE 20
/// The planet seen whole
#define LANDING_VIEW_LAYER_PLANET 22
/// Its glow of air
#define LANDING_VIEW_LAYER_AIR 23
/// The sky inside its air: one colour, over the planet and under the ground's haze
#define LANDING_VIEW_LAYER_SKY 24
/// Haze between the ship and the ground
#define LANDING_VIEW_LAYER_HAZE 30
/// Cloud deck and the clouds rushing past
#define LANDING_VIEW_LAYER_CLOUD 32
/// Heat of entry over everything
#define LANDING_VIEW_LAYER_HEAT 40

// How a landing view track gets from one key to the next
#define LANDING_CURVE_LINEAR 0
/// Fast, then settling
#define LANDING_CURVE_OUT 1
/// Slow, then rushing
#define LANDING_CURVE_IN 2
/// Slow at both ends
#define LANDING_CURVE_BOTH 3

/// The sizes of the whole planet between which its closer-up texture takes over (see chain_detail())
#define LANDING_PLANET_DETAIL list(list(1.7, 3.3))
/// The size of the planet under a ship that is flying over it, and the size it comes up from and falls away to
#define LANDING_HOVER_SIZE 1.5
#define LANDING_HOVER_FAR 0.08

// Which part of the ground around a berth a call to bake_ground() draws
#define LANDING_GROUND_ALL 0
/// Everything but the chunks the hull's own box touches
#define LANDING_GROUND_AROUND 1
/// Only those
#define LANDING_GROUND_UNDER 2
