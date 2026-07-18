/// Areas for the Grand Colosseum PvP event venue. The map itself is
/// runtime-loaded (voidcrew/_maps/map_files/events/); event logic will drive
/// the id-tagged arena gates later. Flags mirror /area/voidcrew/trader_outpost:
/// requires_power = FALSE so mapped lights just work, NOTELEPORT so nobody
/// scroll-of-teleports out of a match.
/area/voidcrew/colosseum
	name = "\improper Grand Colosseum"
	icon_state = "away"
	static_lighting = TRUE
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY
	area_flags = UNIQUE_AREA | NOTELEPORT
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY

/// Elevator arrival alcove + public concourse.
/area/voidcrew/colosseum/lobby
	name = "\improper Colosseum Concourse"

/// Sealed team/solo ready rooms; released into the arena by gate poddoors.
/area/voidcrew/colosseum/staging
	name = "\improper Colosseum Staging"

/// The fighting floor itself.
/area/voidcrew/colosseum/arena
	name = "\improper Colosseum Arena"

/// Stands behind indestructible glass, plus the referee box.
/area/voidcrew/colosseum/spectator
	name = "\improper Colosseum Stands"
