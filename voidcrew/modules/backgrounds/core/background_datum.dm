/// Backgrounds: owned by P1. See data/backgrounds/spec.md.

/// Every background with a key, by key. One instance of each.
GLOBAL_LIST_INIT(backgrounds, init_backgrounds())

/proc/init_backgrounds()
	var/list/registry = list()
	for(var/datum/background/background_type as anything in subtypesof(/datum/background))
		if(!initial(background_type.key))
			continue
		var/datum/background/background = new background_type
		registry[background.key] = background
	return registry

/// The background for a key, or null
/proc/background_by_key(key)
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

/// The join menu entries this background offers right now
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

/// The round-end line for this state
/datum/background/proc/outcome_line(datum/background_state/state)
	return "[name]"

/// Settles a standing goal once, just before the round-end report
/datum/background/proc/judge(datum/background_state/state)
	return

/// A background that starts its players on a hull of its own
/datum/background/hull_start
	/// The hull template this start spawns
	var/hull_type

/// The overmap turf a new hull spawns on, or null for the green default
/datum/background/hull_start/proc/pick_spawn_turf()
	return null

/// Flags a freshly spawned hull
/datum/background/hull_start/proc/on_hull_spawned(obj/structure/overmap/ship/hull)
	return

/datum/background/spacefarer
	key = BACKGROUND_SPACEFARER
	name = "Spacefarer"
