/// Drones build a saved ship in a ship bay. Everything but the source is the base construction's.
/datum/checkpoint_construction/saved
	status_verb = "Building"
	build_noun = "Construction"
	/// The player's save slot this ship is being built from.
	var/save_slot
	/// Credits the save holds. They join the old hull's balance when the save is spent.
	var/carried_funds = 0

/datum/checkpoint_construction/saved/New(datum/ship_checkpoint_ui/terminal, datum/ship_checkpoint/blueprint, mob/living/user, slot, manual_drive = FALSE)
	save_slot = slot
	carried_funds = blueprint.carried_funds
	blueprint.outpost = terminal.outpost
	..(terminal, blueprint, user, manual_drive)

/// Refused at the first piece, the save is still there, and the player should know.
/datum/checkpoint_construction/saved/source_denial()
	. = ..()
	if(.)
		return "[.] [unspent_note()]"

/datum/checkpoint_construction/saved/unspent_note()
	return "Your saved ship is safe."

/// The parent clears the template's blueprint, deletes the snapshot and retires the hull this was saved
/// from, if it is still about, holding its balance for the new ship.
/datum/checkpoint_construction/saved/consume_source()
	. = ..()
	if(!.)
		return
	held_balance += carried_funds
	GLOB.ship_saves.spend(captain_ckey, save_slot)
	log_game("[captain_ckey] spent ship save slot [save_slot] on [ship_name] at [home.name].")

/// A build stopped before its first piece leaves the save as it was. After that it stays spent, though
/// the parent still gives the old hull back its balance.
/datum/checkpoint_construction/saved/release_source()
	..()
	if(!committed)
		GLOB.ship_saves.cancel_retrieval(captain_ckey, save_slot)

/datum/checkpoint_construction/saved/prepare_copy()
	..()
	snapshot.restore_progress(port)
	mark_phase("restore_progress")

/datum/checkpoint_construction/saved/after_ship_loaded()
	place_ship_landmarks(port)
	vessel.settle_saved_research()

/datum/checkpoint_construction/saved/finished_text()
	return "launched from a saved ship"
