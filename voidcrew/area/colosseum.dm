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
	area_flags = NOTELEPORT // UNIQUE_AREA is the area_flags_mapping default
	flags_1 = NONE
	ambience_index = AMBIENCE_AWAY

/// Elevator arrival alcove + public concourse.
/area/voidcrew/colosseum/lobby
	name = "\improper Colosseum Concourse"

/// Sealed team/solo ready rooms; released into the arena by gate poddoors.
/area/voidcrew/colosseum/staging
	name = "\improper Colosseum Staging"

/**
 * Staging is contestants-only, enforced at the area boundary: the controller
 * seats the roster by teleport, so anyone else stepping (or being dragged) in
 * gets carried straight back to the concourse by the wardens. Mindless,
 * clientless mobs (arena beasts) are left to the gates, bouncing them into
 * the lobby would be worse than where they are.
 */
/area/voidcrew/colosseum/staging/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(!isliving(arrived))
		return
	var/mob/living/visitor = arrived
	if(!visitor.mind && !visitor.client)
		return
	var/obj/structure/overmap/colosseum/site = GLOB.colosseum_site
	if(!site?.controller)
		return
	if(visitor.mind && site.controller.entry_for_mind(visitor.mind))
		return
	// Deferred: ejecting inside Entered would reenter movement code mid-move.
	addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/colosseum, bounce_to_lobby), visitor, "Colosseum wardens drag you out of the staging halls. Contestants only."), 1)

/// The fighting floor itself.
/area/voidcrew/colosseum/arena
	name = "\improper Colosseum Arena"

/// Stands behind indestructible glass, plus the referee box.
/area/voidcrew/colosseum/spectator
	name = "\improper Colosseum Stands"

/// The glass-walled spoils chamber on the north promenade. Winners-only while
/// a claim window runs; opens to the public once it lapses.
/area/voidcrew/colosseum/vault
	name = "\improper Colosseum Spoils Chamber"

/// Same boundary enforcement as staging: during a claim window only winners
/// may be inside, however they got in.
/area/voidcrew/colosseum/vault/Entered(atom/movable/arrived, area/old_area)
	. = ..()
	if(!isliving(arrived))
		return
	var/mob/living/visitor = arrived
	if(!visitor.mind && !visitor.client)
		return
	var/obj/structure/overmap/colosseum/site = GLOB.colosseum_site
	var/datum/colosseum_controller/controller = site?.controller
	if(!controller?.claim_window_active())
		return
	if(visitor.mind && controller.winner_minds[visitor.mind])
		return
	addtimer(CALLBACK(site, TYPE_PROC_REF(/obj/structure/overmap/colosseum, bounce_to_lobby), visitor, "Colosseum wardens shove you out of the spoils chamber. Winners only until the claim window closes."), 1)
