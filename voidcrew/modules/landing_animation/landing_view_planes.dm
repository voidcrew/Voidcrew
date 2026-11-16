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
