/// Drones build a saved ship in a ship bay. Everything but the source is the checkpoint rebuild's.
/datum/checkpoint_construction/saved
	status_verb = "Building"
	build_noun = "Construction"
	/// The player's save slot this ship is being built from.
	var/save_slot

/datum/checkpoint_construction/saved/New(datum/ship_checkpoint_ui/terminal, datum/ship_checkpoint/blueprint, mob/living/user, slot, manual_drive = FALSE)
	save_slot = slot
	blueprint.outpost = terminal.outpost
	// There is no hull to retire: this one was saved rounds ago.
	..(terminal, blueprint, user, manual_drive, TRUE)

/// The snapshot is this job's own decoded copy. The save itself is in the table.
/datum/checkpoint_construction/saved/Destroy(force)
	var/datum/ship_checkpoint/transient = snapshot
	. = ..()
	if(. == QDEL_HINT_LETMELIVE)
		return
	if(transient)
		qdel(transient)

/datum/checkpoint_construction/saved/source_denial()
	if(QDELETED(snapshot))
		return "This record can't be read."
	return null

/datum/checkpoint_construction/saved/unspent_note()
	return "Your saved ship is safe."

/// The parent clears the template's blueprint and deletes the snapshot; there is no original to retire.
/datum/checkpoint_construction/saved/consume_source()
	. = ..()
	GLOB.ship_saves.spend(captain_ckey, save_slot)
	log_game("[captain_ckey] spent ship save slot [save_slot] on [ship_name] at [home.name].")

/// A build stopped before its first piece leaves the save as it was. After that it stays spent.
/datum/checkpoint_construction/saved/release_source()
	if(!committed)
		GLOB.ship_saves.cancel_retrieval(captain_ckey, save_slot)

/datum/checkpoint_construction/saved/after_ship_loaded()
	place_ship_landmarks(port)

/datum/checkpoint_construction/saved/finished_text()
	return "launched from a saved ship"
