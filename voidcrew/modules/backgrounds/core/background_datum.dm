/// Backgrounds: owned by P1.

/// Every background with a key, by key. One instance of each.
GLOBAL_LIST_INIT(backgrounds, init_backgrounds())

/**
 * Builds the registry: one instance of each background type that brings a key of its own.
 * A subtype that only inherits its parent's key (a test double, a variant) is never registered,
 * so it can never replace the real background under that key.
 */
/proc/init_backgrounds()
	var/list/registry = list()
	for(var/datum/background/background_type as anything in subtypesof(/datum/background))
		var/background_key = initial(background_type.key)
		if(!background_key)
			continue
		var/datum/background/parent_background = initial(background_type.parent_type)
		if(ispath(parent_background, /datum/background) && initial(parent_background.key) == background_key)
			continue
		registry[background_key] = new background_type
	return registry

/// The background for a key, or null
/proc/background_by_key(key)
	RETURN_TYPE(/datum/background)
	if(!key)
		return null
	return GLOB.backgrounds[key]

/// A start a player picks in character setup
/datum/background
	/// One of the BACKGROUND_* keys. Null on abstract types.
	var/key
	/// Display name
	var/name
	/// TRUE when the start is a place (the Penitentiary, the homestead) rather than a hull
	var/site = FALSE

/// Spawns these players at roundstart. Returns the players who could not start.
/datum/background/proc/roundstart(list/mob/dead/new_player/players)
	return players

/// The join menu entries this background offers right now (spec 5.2)
/datum/background/proc/latejoin_options(mob/dead/new_player/player)
	return list()

/// Spawns one player from the join menu. May sleep. TRUE on success.
/datum/background/proc/latejoin(mob/dead/new_player/player, option_id)
	return FALSE

/// Per-background setup once the state exists
/datum/background/proc/on_started(datum/mind/mind, datum/background_state/state)
	return

/// Cleanup when the state ends
/datum/background/proc/on_ended(datum/mind/mind, datum/background_state/state)
	return

/// The memory line for this state, or null
/datum/background/proc/goal_line(datum/background_state/state)
	return null

/// The round-end line for this state, or null for none. The base reads the line the goal was settled with.
/datum/background/proc/outcome_line(datum/background_state/state)
	return state?.outcome_line

/// Settles a standing goal once, just before the round-end report
/datum/background/proc/judge(datum/background_state/state)
	return

/**
 * A background that starts its players on a hull of its own (hunters, pirates).
 *
 * Its hulls are rolled like the roundstart fleet (random theme, random module in every slot) but
 * never through spawn_free_hull(), which rolls the Spacefarer pool and marks hulls spent, and never
 * into SSovermap.initial_ships, so Spacefarers are never dealt onto them.
 */
/datum/background/hull_start
	/// The hull template this start spawns
	var/hull_type

/// The overmap turf a new hull spawns on, or null for the green default
/datum/background/hull_start/proc/pick_spawn_turf()
	return null

/// Flags a freshly spawned hull
/datum/background/hull_start/proc/on_hull_spawned(obj/structure/overmap/ship/hull)
	return

/**
 * Mints one hull of this start, or returns null.
 *
 * The minted count is reserved before the load sleeps, so two players asking at once can never
 * mint past BACKGROUND_MAX_HULLS_PER_KIND, and it is given back when the load fails.
 */
/datum/background/hull_start/proc/spawn_hull()
	if(!hull_type || !background_hull_available(key))
		return null
	GLOB.background_hulls_minted[key] = (GLOB.background_hulls_minted[key] || 0) + 1
	var/datum/ship_theme/theme = roll_random_ship_theme(hull_type)
	var/list/selections = roll_random_upgrade_selections(find_ship_template_by_type("[hull_type]"), theme)
	var/obj/structure/overmap/ship/hull = SSshuttle.create_ship(hull_type, selections, theme, pick_spawn_turf())
	if(!istype(hull) || QDELETED(hull))
		GLOB.background_hulls_minted[key] = max(0, GLOB.background_hulls_minted[key] - 1)
		log_shuttle("Backgrounds: a [name] hull ([hull_type]) failed to load.")
		return null
	on_hull_spawned(hull)
	log_shuttle("Backgrounds: [name] hull [hull.name] minted ([GLOB.background_hulls_minted[key]] of [BACKGROUND_MAX_HULLS_PER_KIND] this round).")
	return hull

/// Live hulls of this start that a player could spawn on: loaded, with a cryopod, accepting crew
/datum/background/hull_start/proc/live_hulls()
	var/list/hulls = list()
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		if(QDELETED(ship) || isnull(ship.shuttle) || ship.background_key() != key)
			continue
		if(length(ship.shuttle.spawn_points) <= 0 || !ship.joining_allowed)
			continue
		hulls += ship
	return hulls

/**
 * Whether "new ship" is only offered while no hull of this start has a seat the player can take.
 * Hunters regroup onto an open Marshal the way Spacefarers regroup before a requisition; pirates
 * may always found a crew of their own, up to the minted cap (spec 5.2).
 */
/datum/background/hull_start/proc/new_hull_needs_full_fleet()
	return key == BACKGROUND_BOUNTY_HUNTER

/// The join menu's name for founding a new hull of this start (spec 5.2)
/datum/background/hull_start/proc/new_hull_name()
	switch(key)
		if(BACKGROUND_BOUNTY_HUNTER)
			return "New hunter ship"
		if(BACKGROUND_PIRATE)
			return "New pirate ship"
	return "New [lowertext(name)] ship"

/datum/background/hull_start/roundstart(list/mob/dead/new_player/players)
	var/list/mob/dead/new_player/waiting = list()
	for(var/mob/dead/new_player/player as anything in players)
		if(!QDELETED(player))
			waiting += player
	if(!length(waiting))
		return list()

	var/cap_left = BACKGROUND_MAX_HULLS_PER_KIND - (GLOB.background_hulls_minted[key] || 0)
	var/wanted = min(CEILING(length(waiting) / SSovermap.roundstart_crew_per_ship, 1), cap_left)
	var/list/obj/structure/overmap/ship/hulls = list()
	for(var/count in 1 to wanted)
		var/obj/structure/overmap/ship/hull = spawn_hull()
		// A refused load (the z ceiling) refuses every later one too
		if(!hull)
			break
		hulls += hull
	if(!length(hulls))
		return waiting

	// The loads slept: drop anyone who left meanwhile
	for(var/mob/dead/new_player/player as anything in waiting.Copy())
		if(QDELETED(player) || !GET_CLIENT(player))
			waiting -= player
	if(!length(waiting))
		return list()

	var/list/crews = SSticker.deal_roundstart_crews(waiting, length(hulls))
	var/list/mob/dead/new_player/stranded = list()
	for(var/index in 1 to length(hulls))
		var/obj/structure/overmap/ship/hull = hulls[index]
		if(QDELETED(hull))
			stranded += crews[index]
			continue
		stranded += SSticker.crew_roundstart_ship(crews[index], hull)

	// Their own hull had nothing left for them: try this start's other hulls
	for(var/mob/dead/new_player/player as anything in stranded.Copy())
		if(QDELETED(player) || !GET_CLIENT(player))
			stranded -= player
			continue
		for(var/obj/structure/overmap/ship/hull in hulls)
			if(QDELETED(hull))
				continue
			if(SSticker.try_assign_any_job(player, hull))
				stranded -= player
				break
		CHECK_TICK
	return stranded

/datum/background/hull_start/latejoin_options(mob/dead/new_player/player)
	var/list/entries = list()
	var/open_seat = FALSE
	for(var/obj/structure/overmap/ship/ship as anything in live_hulls())
		if(!ship_has_open_slots(ship))
			continue
		var/cleared = ship.is_password_cleared(player?.ckey)
		if(cleared)
			open_seat = TRUE
		entries += list(list(
			"id" = "[key]:[REF(ship)]",
			"kind" = key,
			"name" = ship.name,
			"detail" = ship.source_template?.short_name,
			"crew" = length(ship.manifest),
			"refusal" = cleared ? null : "Locked",
		))
	if(!open_seat || !new_hull_needs_full_fleet())
		entries += list(list(
			"id" = "[key]:new",
			"kind" = key,
			"name" = new_hull_name(),
			"detail" = null,
			"crew" = null,
			"refusal" = background_hull_available(key) ? null : "None left",
		))
	return entries

/datum/background/hull_start/latejoin(mob/dead/new_player/player, option_id)
	if(QDELETED(player) || !player.client)
		return FALSE
	var/list/id_parts = splittext("[option_id]", ":")
	if(length(id_parts) != 2 || id_parts[1] != key)
		return FALSE
	if(id_parts[2] == "new")
		return latejoin_new_hull(player)

	var/obj/structure/overmap/ship/ship = locate(id_parts[2]) in live_hulls()
	if(QDELETED(ship) || !ship_has_open_slots(ship))
		to_chat(player, span_warning("That ship is no longer available."))
		player.select_ship()
		return FALSE
	// The cryopod's anti-dupe rule, as the ship list applies it
	var/rejoin_wait = cryo_rejoin_wait(player.ckey, ship)
	if(rejoin_wait)
		to_chat(player, span_warning("You left this ship's crew for cryosleep too recently to rejoin it. Try again in [DisplayTimeText(rejoin_wait)], or join a different ship."))
		player.select_ship()
		return FALSE
	// Memo, password and job prompts are the ship list's own
	player.select_job_on_ship(ship)
	return QDELETED(player)

/// Mints a hull for a lobby player and seats them as its officer
/datum/background/hull_start/proc/latejoin_new_hull(mob/dead/new_player/player)
	if(!SSticker.IsRoundInProgress())
		to_chat(player, span_danger("The round is either not ready, or has already finished..."))
		return FALSE
	if(player.spawning || player.spawning_ship)
		to_chat(player, span_warning("Your ship is already being prepared. Please wait..."))
		return FALSE
	if(!background_hull_available(key))
		to_chat(player, span_warning("That ship is no longer available."))
		player.select_ship()
		return FALSE
	player.spawning_ship = TRUE
	var/datum/map_template/shuttle/voidcrew/template_type = hull_type
	to_chat(player, span_notice("Your [initial(template_type.name)] is being prepared. Please be patient!"))
	var/obj/structure/overmap/ship/hull = spawn_hull()
	if(QDELETED(player))
		return FALSE
	if(!hull)
		player.spawning_ship = FALSE
		if(SSmapping.at_z_level_ceiling())
			to_chat(player, span_warning("The shipyard is congested right now - hull assembly space frees up as ships move. Try again in a minute."))
		else
			to_chat(player, span_danger("There was an error loading the ship. Please contact admins!"))
		player.select_ship()
		return FALSE
	SSblackbox.record_feedback("tally", "background_hull_minted", 1, "[hull_type]")
	log_shuttle("[key_name(player)] founded [hull.name] as a [name] start.")
	ship_metric_purchased(hull, player, requisition = TRUE)
	hull.password_cleared_ckeys[player.ckey] = TRUE
	if(!player.AttemptSpawnOnShip(hull.job_slots[1], hull))
		if(!QDELETED(player))
			player.spawning_ship = FALSE
			to_chat(player, span_danger("Ship spawned, but you were unable to be spawned. You can likely try to spawn in the ship through joining normally, but if not, please contact an admin."))
		return FALSE
	return TRUE

/datum/background/spacefarer
	key = BACKGROUND_SPACEFARER
	name = "Spacefarer"

/// Spacefarers are not listed at round end
/datum/background/spacefarer/outcome_line(datum/background_state/state)
	return null
