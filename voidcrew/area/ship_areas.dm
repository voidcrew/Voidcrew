/area/centcom/asteroid/voidcrew
	area_flags = UNIQUE_AREA | CAVES_ALLOWED | MOB_SPAWN_ALLOWED
	// Nothing here is dark or uses placed lights, so the dynamic-lighting engine (corners,
	// light tracking) is pure overhead - but skipping it means these turfs get NO lighting
	// overlay at all, and the lighting plane renders anything it doesn't light as black.
	// Area luminosity = 1 does not cover this; it never touches the lighting plane. The
	// base lighting below is what actually lights the rock, matched to /area/space so the
	// field reads as starlit and has no seam against the vacuum around it (and so it tints
	// with the nebula, via the COLOR_STARLIGHT path in /area/add_base_lighting()).
	static_lighting = FALSE
	base_lighting_alpha = 255
	base_lighting_color = COLOR_STARLIGHT
