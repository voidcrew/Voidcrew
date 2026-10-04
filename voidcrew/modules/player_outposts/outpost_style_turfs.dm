/**
 * # Outpost style turfs
 *
 * Indestructible walls and floors for outpost service rooms and ship bays, so each outpost style
 * (voidcrew/_DEFINES/outpost_styles.dm) has more to build with than grey tile. They are the stock
 * indestructible turfs with other art and nothing else.
 */

// ===== WALLS =====

/turf/closed/indestructible/rusty
	name = "rusted wall"
	desc = "An old wall, rusted through its paint but not through its plating."
	icon = 'icons/turf/walls/rusty_wall.dmi'
	icon_state = "rusty_wall-0"
	base_icon_state = "rusty_wall"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_WALLS + SMOOTH_GROUP_CLOSED_TURFS
	canSmoothWith = SMOOTH_GROUP_WALLS

/turf/closed/indestructible/reinforced/rusty
	name = "rusted reinforced wall"
	desc = "A reinforced wall under a thick coat of rust."
	icon = 'icons/turf/walls/rusty_reinforced_wall.dmi'
	icon_state = "rusty_reinforced_wall-0"
	base_icon_state = "rusty_reinforced_wall"

// ===== TILE =====

/turf/open/indestructible/grimy
	icon_state = "grimy"

/turf/open/indestructible/cafeteria
	icon_state = "cafeteria"

/turf/open/indestructible/freezer
	icon_state = "freezerfloor"

/turf/open/indestructible/checker
	icon_state = "checker"

/turf/open/indestructible/small
	icon_state = "small"

/turf/open/indestructible/diagonal
	icon_state = "diagonal"

/turf/open/indestructible/herringbone
	icon_state = "herringbone"

/turf/open/indestructible/dark/small
	icon_state = "dark_small"

/turf/open/indestructible/dark/diagonal
	icon_state = "dark_diagonal"

/turf/open/indestructible/dark/herringbone
	icon_state = "dark_herringbone"

/turf/open/indestructible/white/small
	icon_state = "white_small"

/turf/open/indestructible/white/diagonal
	icon_state = "white_diagonal"

/turf/open/indestructible/white/herringbone
	icon_state = "white_herringbone"

/turf/open/indestructible/smooth
	icon_state = "smooth"

/turf/open/indestructible/smooth/large
	icon_state = "smooth_large"

/turf/open/indestructible/textured
	icon_state = "textured"

/turf/open/indestructible/textured/large
	icon_state = "textured_large"

/turf/open/indestructible/terracotta
	icon_state = "terracotta"

/turf/open/indestructible/terracotta/small
	icon_state = "terracotta_small"

/turf/open/indestructible/terracotta/diagonal
	icon_state = "terracotta_diagonal"

/turf/open/indestructible/terracotta/herringbone
	icon_state = "terracotta_herringbone"

// ===== PLATING =====

/turf/open/indestructible/plating/rusty
	name = "rusted plating"
	desc = "Plating streaked with rust. The attachment points are bent to uselessness."
	icon_state = "plating_rust"

// ===== WOOD =====

/turf/open/indestructible/wood
	name = "wooden floor"
	desc = "Wood planks over steel, fixed down for good."
	icon_state = "wood"
	footstep = FOOTSTEP_WOOD
	barefootstep = FOOTSTEP_WOOD_BAREFOOT
	clawfootstep = FOOTSTEP_WOOD_CLAW
	tiled_dirt = FALSE

/turf/open/indestructible/wood/parquet
	icon_state = "wood_parquet"

/turf/open/indestructible/wood/tile
	icon_state = "wood_tile"

/turf/open/indestructible/wood/large
	icon_state = "wood_large"

// ===== CARPET =====

/turf/open/indestructible/carpet
	name = "carpet"
	desc = "Carpet glued down over steel. It isn't coming up."
	icon = 'icons/turf/floors/carpet.dmi'
	icon_state = "carpet-255"
	base_icon_state = "carpet"
	smoothing_flags = SMOOTH_BITMASK
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET
	canSmoothWith = SMOOTH_GROUP_CARPET
	footstep = FOOTSTEP_CARPET
	barefootstep = FOOTSTEP_CARPET_BAREFOOT
	clawfootstep = FOOTSTEP_CARPET_BAREFOOT
	heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	tiled_dirt = FALSE

/turf/open/indestructible/carpet/black
	icon = 'icons/turf/floors/carpet_black.dmi'
	icon_state = "carpet_black-255"
	base_icon_state = "carpet_black"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_BLACK
	canSmoothWith = SMOOTH_GROUP_CARPET_BLACK

/turf/open/indestructible/carpet/blue
	icon = 'icons/turf/floors/carpet_blue.dmi'
	icon_state = "carpet_blue-255"
	base_icon_state = "carpet_blue"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_BLUE
	canSmoothWith = SMOOTH_GROUP_CARPET_BLUE

/turf/open/indestructible/carpet/green
	icon = 'icons/turf/floors/carpet_green.dmi'
	icon_state = "carpet_green-255"
	base_icon_state = "carpet_green"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_GREEN
	canSmoothWith = SMOOTH_GROUP_CARPET_GREEN

/turf/open/indestructible/carpet/orange
	icon = 'icons/turf/floors/carpet_orange.dmi'
	icon_state = "carpet_orange-255"
	base_icon_state = "carpet_orange"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_ORANGE
	canSmoothWith = SMOOTH_GROUP_CARPET_ORANGE

/turf/open/indestructible/carpet/purple
	icon = 'icons/turf/floors/carpet_purple.dmi'
	icon_state = "carpet_purple-255"
	base_icon_state = "carpet_purple"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_PURPLE
	canSmoothWith = SMOOTH_GROUP_CARPET_PURPLE

/turf/open/indestructible/carpet/red
	icon = 'icons/turf/floors/carpet_red.dmi'
	icon_state = "carpet_red-255"
	base_icon_state = "carpet_red"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_RED
	canSmoothWith = SMOOTH_GROUP_CARPET_RED

/turf/open/indestructible/carpet/royalblack
	icon = 'icons/turf/floors/carpet_royalblack.dmi'
	icon_state = "carpet_royalblack-255"
	base_icon_state = "carpet_royalblack"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_ROYAL_BLACK
	canSmoothWith = SMOOTH_GROUP_CARPET_ROYAL_BLACK

/turf/open/indestructible/carpet/royalblue
	icon = 'icons/turf/floors/carpet_royalblue.dmi'
	icon_state = "carpet_royalblue-255"
	base_icon_state = "carpet_royalblue"
	smoothing_groups = SMOOTH_GROUP_TURF_OPEN + SMOOTH_GROUP_CARPET_ROYAL_BLUE
	canSmoothWith = SMOOTH_GROUP_CARPET_ROYAL_BLUE

// ===== RUST FOR THE OWNER'S OWN TURFS =====
// Shells and the cargo dock are the owner's to rebuild, so they use ordinary turfs. The stock rust
// turfs add /datum/element/rust, whose signals stay on a turf when it changes, so a rusted map loaded
// where another stood before (a recycled outpost level) warns for every signal on every tile. These
// draw the rusty sprite instead. They build, break and strip like the plain versions.

/turf/closed/wall/rusted
	name = "rusted wall"
	desc = "A wall gone orange with rust. It still holds."
	icon = 'icons/turf/walls/rusty_wall.dmi'
	icon_state = "rusty_wall-0"
	base_icon_state = "rusty_wall"

/turf/closed/wall/r_wall/rusted
	name = "rusted reinforced wall"
	desc = "A reinforced wall under a thick coat of rust."
	icon = 'icons/turf/walls/rusty_reinforced_wall.dmi'
	icon_state = "rusty_reinforced_wall-0"
	base_icon_state = "rusty_reinforced_wall"
	base_decon_state = "rusty_wall"

/turf/open/floor/plating/rusted
	name = "rusted plating"
	icon_state = "plating_rust"
