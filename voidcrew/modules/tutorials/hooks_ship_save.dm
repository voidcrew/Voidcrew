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
