/**
 * The two planes the landing view draws with (see landing_view.dm).
 *
 * The view is big pictures: a planet, a cloud deck, the real ground scaled down. They have to show
 * everywhere a viewer can see space past the hull and nowhere else: not over the hull, and not in the black of
 * rooms and tiles out of their sight. The mask plane does that. Every area of a landing ship (its own rooms and
 * the transit space around it) carries a white overlay on the mask plane, so the mask is exactly the tiles of
 * that ship the viewer can see. The view plane is cut to it, and sits under the floor plane, so the hull covers
 * the rest.
 */
/atom/movable/screen/plane_master/landing_view_mask
	name = "Landing view mask"
	documentation = "Holds a white tile for every turf of a landing ship (hull and the transit space around it) the viewer can see.\
		<br>Never drawn itself: it is the alpha mask of the landing view plane, so that plane's big pictures stop at the edge of sight."
	plane = LANDING_VIEW_MASK_PLANE
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = LANDING_VIEW_MASK_RENDER_TARGET
	render_relay_planes = list()
	// one view at a time, always on the viewer's own level
	offsetting_flags = BLOCKS_PLANE_OFFSETTING
	multiz_scaled = FALSE

/atom/movable/screen/plane_master/landing_view
	name = "Landing view"
	documentation = "What a crew sees around their hull as it lands on a planet or leaves one: the planet, its sky and clouds, the real ground below.\
		<br>Drawn over space and parallax and under the world, and cut to the landing view mask."
	plane = LANDING_VIEW_PLANE
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_relay_planes = list(RENDER_PLANE_UNLIT_GAME)
	offsetting_flags = BLOCKS_PLANE_OFFSETTING
	multiz_scaled = FALSE

/atom/movable/screen/plane_master/landing_view/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	add_filter("landing_view_mask", 1, alpha_mask_filter(render_source = OFFSET_RENDER_TARGET(LANDING_VIEW_MASK_RENDER_TARGET, offset)))

/atom/movable/screen/plane_master/landing_view_outside
	name = "Landing view outside mask"
	documentation = "Holds a white tile for every turf of transit space around a landing ship the viewer can see, and none for its hull.\
		<br>Never drawn itself: it is the alpha mask of the landing view light plane, so the ground's light never falls on the ship."
	plane = LANDING_VIEW_OUTSIDE_PLANE
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_target = LANDING_VIEW_OUTSIDE_RENDER_TARGET
	render_relay_planes = list()
	offsetting_flags = BLOCKS_PLANE_OFFSETTING
	multiz_scaled = FALSE

/atom/movable/screen/plane_master/landing_view_outside/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	// space draws itself as something that glows, which cuts it out of the lighting altogether: no light of
	// ours could darken it. Around a landing hull it is ground that is seen there, so there it is blocked
	add_relay_to(GET_NEW_PLANE(RENDER_PLANE_EMISSIVE, offset), relay_layer = EMISSIVE_SPACE_LAYER + 0.5, relay_color = GLOB.em_block_color)

/atom/movable/screen/plane_master/landing_view_light
	name = "Landing view light"
	documentation = "The light on the ground a landing ship's crew see under them: a picture of it, drawn over the lighting of the transit space around the hull.\
		<br>The landing view is lit like everything else, by the lighting plate; in transit that is full light everywhere. This puts the ground's own light there instead,\
		so the ground shows as the game's lighting will show it once the hull is down, to every kind of eye."
	plane = LANDING_VIEW_LIGHT_PLANE
	appearance_flags = PLANE_MASTER|NO_CLIENT_COLOR
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	render_relay_planes = list(RENDER_PLANE_LIGHTING)
	offsetting_flags = BLOCKS_PLANE_OFFSETTING
	multiz_scaled = FALSE

/atom/movable/screen/plane_master/landing_view_light/Initialize(mapload, datum/hud/hud_owner, datum/plane_master_group/home, offset)
	. = ..()
	add_filter("landing_view_outside", 1, alpha_mask_filter(render_source = OFFSET_RENDER_TARGET(LANDING_VIEW_OUTSIDE_RENDER_TARGET, offset)))
