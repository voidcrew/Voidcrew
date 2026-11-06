/area/voidcrew/penitentiary
	name = "\improper Meridian Penitentiary"
	icon_state = "away"
	area_flags = UNIQUE_AREA | NOTELEPORT | NO_BOH
	requires_power = FALSE
	static_lighting = TRUE
	default_gravity = STANDARD_GRAVITY
	repels_megafauna = TRUE

/area/voidcrew/penitentiary/lobby
	name = "Meridian Visitor Hall"

/area/voidcrew/penitentiary/intake
	name = "Meridian Intake"

/area/voidcrew/penitentiary/warden
	name = "\improper Warden's Office"

/area/voidcrew/penitentiary/staff
	name = "\improper Staff Quarters"

/area/voidcrew/penitentiary/armory
	name = "\improper Armory"

/area/voidcrew/penitentiary/evidence
	name = "\improper Evidence Vault"

/area/voidcrew/penitentiary/infirmary
	name = "\improper Infirmary"

/area/voidcrew/penitentiary/morgue
	name = "\improper Morgue"

/area/voidcrew/penitentiary/podbay
	name = "\improper Pod Bay"

/area/voidcrew/penitentiary/escape_wing
	name = "\improper Cell Block D"

/area/voidcrew/penitentiary/capture_wing
	name = "\improper Secure Holding"

/area/voidcrew/penitentiary/service
	name = "\improper Service Corridor"

/// The NPC wing. One area instance: the prison wing code reads it as one.
/area/voidcrew/player_outpost/prison/penitentiary
	name = "\improper General Population"
	area_flags = UNIQUE_AREA | NOTELEPORT | NO_BOH
	requires_power = FALSE
