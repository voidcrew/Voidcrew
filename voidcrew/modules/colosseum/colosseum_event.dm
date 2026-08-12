/**
 * # Grand Colosseum: spawn event + admin controls
 *
 * The venue is never a roundstart fixture: it surfaces mid-round through the
 * dynamic event scheduler as a rare galaxy-scope event, hard-gated to no
 * earlier than COLOSSEUM_EARLIEST_SPAWN. Admins get a force-spawn verb (which
 * ignores the time gate) plus match-control debug verbs (colosseum_controller.dm).
 */

/datum/round_event_control/voidcrew/grand_colosseum
	name = "Grand Colosseum"
	typepath = /datum/round_event/voidcrew/grand_colosseum
	weight = 4 // rare: roughly a fifth of a standard-weight event
	max_occurrences = 1
	earliest_start = COLOSSEUM_EARLIEST_SPAWN
	min_players = 4 // a venue with nobody to fight in it is just sad
	event_scope = EVENT_SCOPE_GALAXY
	category = EVENT_CATEGORY_FRIENDLY
	description = "Surfaces the Grand Colosseum PvP venue on the overmap for the rest of the round."

/datum/round_event_control/voidcrew/grand_colosseum/can_spawn_event(players_amt, allow_magic = FALSE)
	. = ..()
	if(!.)
		return FALSE
	if(GLOB.colosseum_site) // one venue per round, ever
		return FALSE
	return TRUE

/datum/round_event/voidcrew/grand_colosseum
	fakeable = FALSE
	announce_chance = 0 // the site does its own galaxy-wide announcing

/datum/round_event/voidcrew/grand_colosseum/start()
	spawn_colosseum_site()

/**
 * Places the venue on an unused overmap square (mid-band preferred: reachable
 * from everywhere, not parked in the deadly core) and opens it. Shared by the
 * natural event and the admin force-spawn. Returns the site or null.
 */
/proc/spawn_colosseum_site(template_type = /datum/map_template/colosseum)
	if(GLOB.colosseum_site)
		return null
	var/turf/spawn_turf = SSovermap.get_unused_overmap_square_in_zone_band(ZONE_YELLOW)
	if(!spawn_turf)
		spawn_turf = SSovermap.get_unused_overmap_square()
	if(!spawn_turf)
		log_mapping("COLOSSEUM: no unused overmap square found, cannot surface the venue.")
		return null
	var/obj/structure/overmap/colosseum/site = new(spawn_turf)
	if(QDELETED(site))
		return null
	site.template_type = template_type
	// Async: open_venue() loads a 62x58 template, which can sleep, never
	// block the event subsystem's fire on it.
	INVOKE_ASYNC(site, TYPE_PROC_REF(/obj/structure/overmap/colosseum, open_venue))
	return site

ADMIN_VERB(spawn_colosseum, R_ADMIN, "Spawn Grand Colosseum", "Force-surface the Grand Colosseum PvP venue on the overmap, ignoring the usual 40-minute gate.", ADMIN_CATEGORY_EVENTS)
	if(GLOB.colosseum_site)
		to_chat(user, span_warning("The Grand Colosseum already exists this round (at [GLOB.colosseum_site.coords_text()])."))
		return
	var/obj/structure/overmap/colosseum/site = spawn_colosseum_site()
	if(!site)
		to_chat(user, span_warning("Failed to place the Grand Colosseum, no free overmap square?"))
		return
	message_admins("[key_name_admin(user)] force-spawned the Grand Colosseum.")
	log_admin("[key_name(user)] force-spawned the Grand Colosseum.")
	BLACKBOX_LOG_ADMIN_VERB("Spawn Grand Colosseum")
