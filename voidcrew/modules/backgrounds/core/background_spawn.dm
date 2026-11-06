/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// Spawns every ready player who picked a start other than Spacefarer. Returns the players left to ship out with a crew.
/datum/controller/subsystem/ticker/proc/start_background_players(list/ready_players)
	return ready_players

/// Puts this lobby player into the world at a background's site. Returns the living character, or null.
/mob/dead/new_player/proc/background_site_arrival(datum/job/job, atom/destination)
	return null
