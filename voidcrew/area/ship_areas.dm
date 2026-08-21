/area/centcom/asteroid/voidcrew
	// Deliberately NOT UNIQUE_AREA. Every landable asteroid field used to be carved into
	// the ONE singleton instance of this type, so all of them - on different z-levels, in
	// different corners of the overmap - were a single /area as far as teardown, lighting,
	// ambience, power and get_area_turfs() were concerned. Each field now mints its own
	// (events.dm field_area), which is also what lets reap_emptied_areas() collect the
	// shell when the field is torn down; UNIQUE_AREA instances are skipped there because
	// deleting one would null out every future GLOB.areas_by_type lookup of the type.
	// The same invariant /area/overmap_encounter rests on.
	area_flags = CAVES_ALLOWED | MOB_SPAWN_ALLOWED
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
