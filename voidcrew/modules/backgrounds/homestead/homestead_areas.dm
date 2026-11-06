/// Backgrounds: owned by P6.

/area/voidcrew/homestead
	name = "\improper Homestead"
	icon_state = "away"
	area_flags = UNIQUE_AREA | NOTELEPORT
	default_gravity = STANDARD_GRAVITY

/area/voidcrew/homestead/house
	name = "\improper Farmhouse"
	requires_power = FALSE
	static_lighting = TRUE
	outdoors = FALSE

/area/voidcrew/homestead/barn
	name = "\improper Barn"
	requires_power = FALSE
	static_lighting = TRUE
	outdoors = FALSE

/area/voidcrew/homestead/cellar
	name = "\improper Storm Cellar"
	requires_power = FALSE
	static_lighting = TRUE
	outdoors = FALSE

/area/voidcrew/homestead/yard
	name = "\improper Yard"
	static_lighting = FALSE
	ambient_lighting = TRUE
	base_lighting_alpha = 255
	base_lighting_color = "#FFFFFF"
	outdoors = TRUE
	always_unpowered = TRUE
