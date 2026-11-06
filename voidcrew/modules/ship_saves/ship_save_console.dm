/// Why this user can't save the ship in this bay to any slot, or null. Only checks caches, so ui_data can use it.
/datum/ship_checkpoint_ui/proc/saved_ship_bay_denial(mob/living/user, datum/outpost_berth/ship_bay/bay)
	if(QDELETED(src) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Shipyard console unavailable."
	if(QDELETED(bay) || bay.outpost != outpost || !(bay in outpost.bay_berths) || !bay.is_ship_present())
		return "Dock your ship in a ship bay first."
	var/obj/structure/overmap/ship/ship = bay.ship
	if(!ship.is_ship_captain(user) || ship.abandoned || ship.retired_by_checkpoint)
		return "Only the ship's current captain can save it."
	if(ship.checkpoint_rebuilding)
		return "Recovery is already in progress."
	if(!length(ship.shuttle.spawn_points))
		return "This hull has no cryopods."
	// Unloaded is not the same as empty: a failed read must not look like three free slots.
	if(!GLOB.ship_save_store.online() || isnull(GLOB.ship_saves.saves_for(user.ckey)))
		return "Shipyard records are offline."
	return null

/// Why this user can't save the ship in this bay to this slot, or null.
/datum/ship_checkpoint_ui/proc/saved_ship_denial(mob/living/user, datum/outpost_berth/ship_bay/bay, slot)
	return saved_ship_bay_denial(user, bay) || GLOB.ship_saves.slot_denial(user.ckey, slot)

/// The denial, plus whether the ship we captured is still the one in the bay.
/datum/ship_checkpoint_ui/proc/saved_ship_changed_denial(mob/living/user, datum/outpost_berth/ship_bay/bay, obj/structure/overmap/ship/ship, slot)
	var/denial = saved_ship_denial(user, bay, slot)
	if(denial)
		return denial
	if(bay.ship != ship)
		return "The docked ship changed. Try again."
	return null

/// Captures the ship, asks the captain, and charges them for what it holds. Sleeps at every step, so
/// everything is checked again afterwards.
/datum/ship_checkpoint_ui/proc/save_ship(mob/living/user, datum/outpost_berth/ship_bay/bay, slot)
	error = saved_ship_denial(user, bay, slot)
	if(error)
		return FALSE
	working = TRUE
	notice = null
	var/obj/structure/overmap/ship/ship = bay.ship
	var/ship_name = ship.name
	var/player_ckey = user.ckey
	var/datum/ship_checkpoint/snapshot = new
	var/failure = snapshot.capture(ship, user) || saved_ship_changed_denial(user, bay, ship, slot)
	var/list/survey
	if(!failure)
		survey = ship.save_survey(fresh = TRUE)
		if(!survey)
			failure = "The source hull is no longer available."
	if(!failure)
		var/list/old_row = GLOB.ship_saves.saved_row(player_ckey, slot)
		var/old_name = old_row?["ship_name"]
		var/old_round = old_row?["saved_round"]
		var/cost_text = ship_save_cost_text(survey["cost"])
		var/question = old_row ? "Overwrite [old_name] with [ship_name] for [cost_text]?" : "Save [ship_name] to slot [slot] for [cost_text]?"
		if(!confirm_save(user, question, "Shipyard"))
			qdel(snapshot)
			working = FALSE
			return FALSE
		failure = saved_ship_changed_denial(user, bay, ship, slot)
		if(!failure)
			var/list/new_row = GLOB.ship_saves.saved_row(player_ckey, slot)
			if(new_row?["ship_name"] != old_name || new_row?["saved_round"] != old_round)
				failure = "That slot changed. Try again."
	if(!failure)
		failure = GLOB.ship_saves.commit_save(player_ckey, snapshot, user, slot, survey)
	qdel(snapshot)
	if(QDELETED(src))
		return !failure
	working = FALSE
	error = failure
	if(failure)
		return FALSE
	notice = "[ship_name] saved."
	return TRUE

/// Why this save can't be built in this outpost's bay, or null. Only checks caches, so ui_data can use it.
/datum/ship_checkpoint_ui/proc/saved_ship_retrieve_denial(mob/living/user, slot, allow_busy = FALSE)
	if(QDELETED(src) || QDELETED(outpost) || ui_status(user, GLOB.always_state) != UI_INTERACTIVE)
		return "Shipyard console unavailable."
	var/denial = GLOB.ship_saves.retrieve_denial(user.ckey, slot, allow_busy)
	if(denial)
		return denial
	if(!outpost.available_ship_bay())
		return "The ship bay is occupied."
	return null

/datum/ship_checkpoint_ui/proc/create_retrieval_job(mob/living/user, datum/ship_checkpoint/snapshot, slot)
	return new /datum/checkpoint_construction/saved(src, snapshot, user, slot)

/// Reads a saved ship back and starts the drones on it. The save is spent at the first piece.
/// Sleeps at the read and in the loader's queue, so everything is checked again afterwards.
/datum/ship_checkpoint_ui/proc/retrieve_ship(mob/living/user, slot)
	if(working)
		return FALSE
	error = saved_ship_retrieve_denial(user, slot)
	if(error)
		return FALSE
	var/player_ckey = user.ckey
	if(!GLOB.ship_saves.begin_retrieval(player_ckey, slot))
		error = "Already under way."
		return FALSE
	working = TRUE
	notice = null
	var/datum/ship_checkpoint/snapshot = GLOB.ship_saves.read_save(player_ckey, slot)
	var/failure
	if(istext(snapshot))
		failure = snapshot
		snapshot = null
	else
		failure = saved_ship_retrieve_denial(user, slot, allow_busy = TRUE)
		// Another save of the same hull may have started building during the read. The job takes this
		// lock itself, with no wait in between, so two can't hold it.
		var/obj/structure/overmap/ship/original = snapshot.source_ship?.resolve()
		if(!failure && original?.checkpoint_rebuilding)
			failure = "Already under way."
	if(failure)
		qdel(snapshot)
		GLOB.ship_saves.cancel_retrieval(player_ckey, slot)
		if(!QDELETED(src))
			working = FALSE
			error = failure
		return FALSE
	// The job claims the bay before waiting for the shared shuttle loader.
	var/datum/checkpoint_construction/saved/job = create_retrieval_job(user, snapshot, slot)
	var/started = FALSE
	if(job.bay)
		started = job.prepare()
	else
		job.error = "The ship bay is occupied."
		GLOB.ship_saves.cancel_retrieval(player_ckey, slot)
		qdel(job)
	if(!QDELETED(src))
		working = FALSE
		if(started)
			error = null
			notice = "Construction started."
		else
			error = job.error || "Construction failed. [job.unspent_note()]"
	return started

/// What the Saved Ships tab shows. Reads only caches; ui_data must not touch the database.
/datum/ship_checkpoint_ui/proc/saved_ships_data(mob/user)
	var/list/saves = list()
	for(var/list/row as anything in GLOB.ship_saves.saves_for(user.ckey))
		saves += list(GLOB.ship_saves.saved_ship_entry(user.ckey, row, saved_ship_retrieve_denial(user, row["slot"])))
	var/list/ships = list()
	for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
		var/obj/structure/overmap/ship/ship = bay?.ship
		if(!ship?.is_ship_captain(user))
			continue
		ships += list(ship_save_add_survey(list(
			"ref" = REF(bay),
			"name" = ship.name,
			"class" = ship.source_template?.short_name,
			"denial" = saved_ship_bay_denial(user, bay),
		), ship.save_survey()))
	return list(
		"online" = !!GLOB.ship_save_store.online(),
		"parts" = GLOB.ship_economy_db.cached_parts(user.ckey),
		"slots" = SHIP_SAVE_SLOTS,
		"saves" = saves,
		"ships" = ships,
	)
