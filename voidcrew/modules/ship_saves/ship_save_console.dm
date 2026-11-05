/// Why this user can't save the ship in this bay, or null. Only checks caches, so ui_data can use it.
/datum/ship_checkpoint_ui/proc/saved_ship_denial(mob/living/user, datum/outpost_berth/ship_bay/bay)
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
	if(!GLOB.ship_saves.free_slot(user.ckey))
		return "All three slots are full."
	return null

/// The denial, plus whether the ship we captured is still the one in the bay.
/datum/ship_checkpoint_ui/proc/saved_ship_changed_denial(mob/living/user, datum/outpost_berth/ship_bay/bay, obj/structure/overmap/ship/ship)
	var/denial = saved_ship_denial(user, bay)
	if(denial)
		return denial
	if(bay.ship != ship)
		return "The docked ship changed. Try again."
	return null

/// Captures the ship, asks the captain, and charges them. Sleeps at every step, so everything is
/// checked again afterwards.
/datum/ship_checkpoint_ui/proc/save_ship(mob/living/user, datum/outpost_berth/ship_bay/bay)
	error = saved_ship_denial(user, bay)
	if(error)
		return FALSE
	working = TRUE
	notice = null
	var/obj/structure/overmap/ship/ship = bay.ship
	var/ship_name = ship.name
	var/player_ckey = user.ckey
	var/datum/ship_checkpoint/snapshot = new
	snapshot.persistent = TRUE
	var/failure = snapshot.capture(ship, user) || saved_ship_changed_denial(user, bay, ship)
	if(!failure)
		var/price = GLOB.ship_saves.price_for(snapshot.owned_tile_count())
		if(!confirm_save(user, "Save [ship_name] for [price] ship parts?", "Shipyard"))
			qdel(snapshot)
			working = FALSE
			return FALSE
		failure = saved_ship_changed_denial(user, bay, ship)
	if(!failure)
		failure = GLOB.ship_saves.commit_save(player_ckey, snapshot, user)
	qdel(snapshot)
	if(QDELETED(src))
		return !failure
	working = FALSE
	error = failure
	if(failure)
		return FALSE
	notice = "[ship_name] saved."
	return TRUE

/// What the Saved Ships tab shows. Reads only caches; ui_data must not touch the database.
/datum/ship_checkpoint_ui/proc/saved_ships_data(mob/user)
	var/list/saves = list()
	for(var/list/row as anything in GLOB.ship_saves.saves_for(user.ckey))
		saves += list(list("slot" = row["slot"], "name" = row["ship_name"], "class" = row["ship_class"], "denial" = null))
	var/list/ships = list()
	for(var/datum/outpost_berth/ship_bay/bay as anything in outpost.bay_berths)
		if(!bay?.ship?.is_ship_captain(user))
			continue
		ships += list(list(
			"ref" = REF(bay),
			"name" = bay.ship.name,
			"price" = GLOB.ship_saves.price_for(hull_owned_tile_count(bay.ship.shuttle)),
			"denial" = saved_ship_denial(user, bay),
		))
	return list(
		"online" = !!GLOB.ship_save_store.online(),
		"parts" = GLOB.ship_economy_db.cached_parts_total(user.ckey),
		"slots" = SHIP_SAVE_SLOTS,
		"saves" = saves,
		"ships" = ships,
	)
