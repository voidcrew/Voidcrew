// Tutorial checklist hooks: the Save your ship item (voidcrew/modules/ship_saves and the
// player outpost ship bays). Overrides chain with any others of the same proc.

/// The bay's own arrival handler. Same guard as the parent: the hull must be in this bay's dock.
/datum/outpost_berth/ship_bay/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	. = ..()
	if(QDELETED(ship) || dock?.get_docked() != ship.shuttle)
		return
	tutorial_credit_crew(ship, TUTORIAL_STEP_SHIP_SAVE_DOCK, aboard_only = TRUE)

/datum/ship_checkpoint_ui/save_ship(mob/living/user, datum/outpost_berth/ship_bay/bay, slot, funds_parts = 0)
	. = ..()
	if(. && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_SHIP_SAVE_SAVE)

/// A save is spent once its hull exists or starts building, from the lobby or a shipyard console.
/datum/ship_saves/spend(ckey, slot)
	. = ..()
	var/player_ckey = ckey(ckey)
	if(player_ckey && !SSvc_tutorials.has_key(player_ckey, TUTORIAL_STEP_SHIP_SAVE_LOAD))
		SSvc_tutorials.credit_ckey(player_ckey, TUTORIAL_STEP_SHIP_SAVE_LOAD, get_mob_by_ckey(player_ckey))

// ---------------------------------------------------------------------------
// Panel helpers for the Save your ship steps (tutorial_catalog.dm). Cheap: they run in ui_data.
// ---------------------------------------------------------------------------

/// How long the list of outposts with ship bays is kept. There are only a few outposts.
#define TUTORIAL_SAVE_BAY_CACHE (30 SECONDS)

/// Names of the outposts a ship can dock in a bay at right now, and when they were read.
GLOBAL_LIST_EMPTY(tutorial_save_bay_names)
GLOBAL_VAR_INIT(tutorial_save_bay_read_at, -INFINITY)

/// Outposts whose helm entry offers "Dock at ship bay", the same test the helm uses.
/proc/tutorial_save_bay_outposts()
	if(world.time < GLOB.tutorial_save_bay_read_at + TUTORIAL_SAVE_BAY_CACHE)
		return GLOB.tutorial_save_bay_names
	var/list/names = list()
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(!QDELETED(home) && home.ship_bay_installed && home.has_hangar_elevator())
			names += home.name
	GLOB.tutorial_save_bay_names = names
	GLOB.tutorial_save_bay_read_at = world.time
	return names

/// The ship bay this ship is docked in, or null.
/proc/tutorial_save_bay_of(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return null
	var/obj/structure/overmap/dynamic/player_outpost/home = ship.docked
	if(!istype(home))
		return null
	for(var/datum/outpost_berth/ship_bay/bay as anything in home.bay_berths)
		if(bay.ship == ship && bay.is_ship_present())
			return bay
	return null

/// The shipyard consoles inside one bay.
/proc/tutorial_save_bay_consoles(datum/outpost_berth/ship_bay/bay)
	. = list()
	if(QDELETED(bay))
		return
	for(var/obj/machinery/computer/ship_checkpoint/console as anything in SSmachines.get_machines_by_type_and_subtypes(/obj/machinery/computer/ship_checkpoint))
		if(bay.contains_turf(get_turf(console)))
			. += console

#undef TUTORIAL_SAVE_BAY_CACHE
