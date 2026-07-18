/**
 * # Recovery Mission
 *
 * A mission that targets a specific space ruin on the overmap. The objective
 * (an item, or a marked mob for the proof-of-kill variant) is spawned inside
 * the ruin when its interior loads, and the turn-in item is delivered on the
 * mission pad. Rewards include trade vouchers.
 *
 * Ruin interiors are lazily loaded and ruins delete/respawn elsewhere once
 * abandoned (see space_ruin.dm check_and_respawn), so the mission listens for
 * its target being destroyed and retargets a new ruin a limited number of
 * times before failing.
 */

/// How many times a recovery mission may retarget after losing its objective while active
#define MAX_RECOVERY_RETARGETS 2

/datum/mission/recovery
	name = "Recovery Contract"
	desc = "Recover an item from a ruin."
	weight = 10
	mission_limit = 3
	requires_item = TRUE
	voucher_count = 1

	/// The ruin this mission targets
	var/obj/structure/overmap/space_ruin/target_ruin
	/// Relative overmap coordinates of the target ruin (cached for display)
	var/target_x = 0
	var/target_y = 0
	/// Display name of the target's zone at generation time
	var/target_zone_name = "Unknown Zone"
	/// Flavor name of the thing being recovered (item name, or target mob name for kill missions)
	var/objective_name = "objective"
	/// The spawned objective (quest item; for kill missions the mob, then the proof item)
	var/atom/movable/objective_atom
	/// Whether the objective has been spawned into the world
	var/objective_spawned = FALSE
	/// Reservation bounds captured when the objective spawned: list(min_x, min_y, max_x, max_y, z).
	/// Used to tell "stranded in the dead ruin" from "safely extracted" when the ruin is deleted.
	var/list/objective_bounds
	/// Retargets remaining before the mission fails
	var/retargets_left = MAX_RECOVERY_RETARGETS
	/// GPS beacon tag shown on units the beacon is uploaded to
	var/gps_tag
	/// Weakrefs of /datum/component/gps/item units this mission's beacon was uploaded to
	var/list/datum/weakref/linked_gps_units = list()

/datum/mission/recovery/Destroy()
	clear_gps_signals()
	target_ruin = null
	objective_atom = null
	return ..()

/datum/mission/recovery/generate_mission_details()
	if(!pick_target_ruin())
		generation_failed = TRUE
		return

	// Difficulty, payment and voucher count follow the target's zone
	var/zone_type = SSovermap_zones?.get_zone_type(get_turf(target_ruin)) || ZONE_GREEN
	switch(zone_type)
		if(ZONE_GREEN)
			target_zone_name = ZONE_NAME_GREEN
			difficulty = MISSION_DIFFICULTY_EASY
			value_min = 700
			value_max = 1000
		if(ZONE_YELLOW)
			target_zone_name = ZONE_NAME_YELLOW
			difficulty = MISSION_DIFFICULTY_MEDIUM
			value_min = 1200
			value_max = 1700
		if(ZONE_RED)
			target_zone_name = ZONE_NAME_RED
			difficulty = MISSION_DIFFICULTY_HARD
			value_min = 1800
			value_max = 2600
			voucher_count = 2

	gps_tag = "[gps_tag_prefix()]-[uppertext(random_string(3, GLOB.hex_characters))]"
	generate_objective_details()

	. = ..()
	update_text()

/**
 * Prefix for the GPS beacon tag. Override in subtypes.
 */
/datum/mission/recovery/proc/gps_tag_prefix()
	return "RCVRY"

/**
 * Picks the flavor of the objective. Override in subtypes.
 */
/datum/mission/recovery/proc/generate_objective_details()
	var/static/list/recovery_items = list(
		"flight recorder",
		"encrypted data core",
		"sealed sample crate",
		"prototype targeting module",
		"salvaged ship ledger",
	)
	objective_name = pick(recovery_items)

/**
 * Rebuilds the mission name and description from current state.
 * Called at generation and again after retargeting.
 */
/datum/mission/recovery/proc/update_text()
	name = "Recovery Contract: [objective_name]"
	desc = "Recover the [objective_name] from the signal at ([target_x], [target_y]) in the [target_zone_name], and return it to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the objective's beacon ([gps_tag])."

/**
 * Picks a target ruin from the overmap and hooks its deletion.
 * Returns TRUE on success.
 */
/datum/mission/recovery/proc/pick_target_ruin()
	var/list/candidates = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin))
			continue
		if(ruin == target_ruin)
			continue
		if(!istype(get_turf(ruin), /turf/open/overmap))
			continue
		candidates += ruin
	if(!length(candidates))
		return FALSE

	target_ruin = pick(candidates)
	target_x = target_ruin.x
	target_y = target_ruin.y - OVERMAP_SOUTH_SIDE_COORD + 1
	RegisterSignal(target_ruin, COMSIG_QDELETING, PROC_REF(on_ruin_deleted))
	return TRUE

/datum/mission/recovery/get_waypoint_info()
	return list("Recovery: [objective_name]", target_x, target_y)

/datum/mission/recovery/start_mission(obj/structure/overmap/ship/ship)
	// The target may have been destroyed while the mission sat in the available list
	if(QDELETED(target_ruin) && !pick_target_ruin())
		return FALSE
	. = ..()
	if(!.)
		return FALSE
	arm_objective()
	return TRUE

/**
 * Spawns the objective now if the ruin is loaded, otherwise waits for it to load.
 */
/datum/mission/recovery/proc/arm_objective()
	if(QDELETED(target_ruin) || objective_spawned)
		return
	if(target_ruin.loaded)
		spawn_objective()
	else
		RegisterSignal(target_ruin, COMSIG_VOIDCREW_PLANET_LOADED, PROC_REF(on_ruin_loaded))

/datum/mission/recovery/proc/on_ruin_loaded(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(target_ruin, COMSIG_VOIDCREW_PLANET_LOADED)
	spawn_objective()

/**
 * Spawns the objective inside the loaded ruin. Override in subtypes.
 */
/datum/mission/recovery/proc/spawn_objective()
	if(objective_spawned || QDELETED(target_ruin))
		return
	var/turf/spawn_turf = target_ruin.get_random_interior_turf() || target_ruin.ruin_bottom_left
	if(!spawn_turf)
		return
	var/obj/item/mission_recovery/quest_item = new(spawn_turf)
	quest_item.name = objective_name
	quest_item.mission_ref = WEAKREF(src)
	register_objective(quest_item)

/**
 * Tracks a spawned objective atom and captures the ruin's bounds.
 */
/datum/mission/recovery/proc/register_objective(atom/movable/new_objective)
	objective_atom = new_objective
	objective_spawned = TRUE
	RegisterSignal(objective_atom, COMSIG_QDELETING, PROC_REF(on_objective_destroyed))
	capture_objective_bounds()
	push_gps_signal()

/datum/mission/recovery/link_gps_unit(datum/component/gps/item/gps_unit)
	if(failed || completed || !gps_unit)
		return FALSE
	linked_gps_units |= WEAKREF(gps_unit)
	if(objective_atom && !QDELETED(objective_atom))
		gps_unit.add_mission_signal(gps_tag, objective_atom)
	return TRUE

/**
 * (Re)points the beacon at the current objective on every linked GPS unit.
 * Called when the objective spawns or changes (kill missions swap mob -> tag).
 */
/datum/mission/recovery/proc/push_gps_signal()
	if(!objective_atom || QDELETED(objective_atom))
		return
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		if(!unit)
			linked_gps_units -= unit_ref
			continue
		unit.add_mission_signal(gps_tag, objective_atom)

/**
 * Removes this mission's beacon from every linked GPS unit.
 */
/datum/mission/recovery/proc/clear_gps_signals()
	for(var/datum/weakref/unit_ref as anything in linked_gps_units)
		var/datum/component/gps/item/unit = unit_ref.resolve()
		unit?.remove_mission_signal(gps_tag)
	linked_gps_units.Cut()

/**
 * Records the target ruin's reservation bounds so we can later tell whether
 * the objective was left behind when the ruin despawned.
 */
/datum/mission/recovery/proc/capture_objective_bounds()
	objective_bounds = null
	var/datum/turf_reservation/reservation = target_ruin?.reservation
	if(!reservation || !length(reservation.bottom_left_turfs))
		return
	var/turf/bottom_left = reservation.bottom_left_turfs[1]
	objective_bounds = list(
		bottom_left.x,
		bottom_left.y,
		bottom_left.x + reservation.width - 1,
		bottom_left.y + reservation.height - 1,
		bottom_left.z,
	)

/**
 * Whether the objective is still physically inside the (now dying) ruin's reservation.
 */
/datum/mission/recovery/proc/is_objective_stranded()
	if(!objective_atom || QDELETED(objective_atom) || !length(objective_bounds))
		return FALSE
	var/turf/objective_turf = get_turf(objective_atom)
	if(!objective_turf)
		return FALSE
	return objective_turf.z == objective_bounds[5] \
		&& objective_turf.x >= objective_bounds[1] && objective_turf.x <= objective_bounds[3] \
		&& objective_turf.y >= objective_bounds[2] && objective_turf.y <= objective_bounds[4]

/**
 * The target ruin is being deleted (it was abandoned and is respawning elsewhere).
 */
/datum/mission/recovery/proc/on_ruin_deleted(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(target_ruin, list(COMSIG_QDELETING, COMSIG_VOIDCREW_PLANET_LOADED))
	target_ruin = null
	if(failed || completed)
		return
	if(objective_spawned)
		// Reservation teardown doesn't reliably delete contents; if the objective
		// was left behind in the dead ruin, destroy it ourselves so the
		// objective-destruction path handles the retarget.
		if(is_objective_stranded())
			qdel(objective_atom)
		// Otherwise the objective was extracted and the mission can still finish
		return
	retarget()

/**
 * The objective was destroyed before being turned in.
 */
/datum/mission/recovery/proc/on_objective_destroyed(datum/source)
	SIGNAL_HANDLER
	objective_atom = null
	objective_spawned = FALSE
	objective_bounds = null
	if(failed || completed)
		return
	retarget()

/**
 * Picks a new target ruin after the old one (or the objective) was lost.
 * Free while the mission is still on the board; limited while active.
 */
/datum/mission/recovery/proc/retarget()
	if(target_ruin)
		UnregisterSignal(target_ruin, list(COMSIG_QDELETING, COMSIG_VOIDCREW_PLANET_LOADED))
		target_ruin = null
	if(active)
		retargets_left--
		if(retargets_left < 0)
			fail("Recovery target lost - contract void.")
			return
	if(!pick_target_ruin())
		fail("Recovery target lost - contract void.")
		return
	update_text()
	if(active)
		arm_objective()
		push_waypoint()
		if(servant)
			servant.ship_notify("[name]: target signal relocated to ([target_x], [target_y]), [target_zone_name].", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/datum/mission/recovery/can_turn_in(obj/item/item)
	if(failed || completed)
		return FALSE
	if(!istype(item, /obj/item/mission_recovery))
		return FALSE
	var/obj/item/mission_recovery/recovery_item = item
	return recovery_item.mission_ref?.resolve() == src

/datum/mission/recovery/get_failure_reason(obj/item/item)
	if(failed)
		return "Mission already failed."
	if(completed)
		return "Mission already completed."
	if(!item)
		return "No item provided."
	if(!istype(item, /obj/item/mission_recovery))
		return "Wrong item type."
	var/obj/item/mission_recovery/recovery_item = item
	if(recovery_item.mission_ref?.resolve() != src)
		return "That item belongs to a different contract."
	return ..()

/datum/mission/recovery/get_progress_string()
	if(!objective_spawned)
		return "Signal at ([target_x], [target_y])"
	return "Return the [objective_name] to the pad"

/datum/mission/recovery/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target_x
	data["target_y"] = target_y
	return data

/**
 * # Proof-of-Kill Mission
 *
 * Recovery variant: a named target mob is spawned in the ruin; killing it
 * drops an identification tag, which is the turn-in item.
 */
/datum/mission/recovery/kill
	name = "Kill Contract"
	weight = 8
	mission_limit = 2

	/// Mob type pools per difficulty (space-capable faction pirates).
	/// Hard pool is the real faction bosses — red-zone bounties are the
	/// named monsters of the sector, not just another captain.
	var/static/list/easy_targets = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/grey/melee,
	)
	var/static/list/medium_targets = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		/mob/living/basic/trooper/pirate/faction/grey/captain,
	)
	var/static/list/hard_targets = list(
		/mob/living/basic/trooper/pirate/faction/boss/silverscale,
		/mob/living/basic/trooper/pirate/faction/boss/skeleton,
		/mob/living/basic/trooper/pirate/faction/boss/grey,
		/mob/living/basic/trooper/pirate/faction/boss/lustrous,
		/mob/living/basic/trooper/pirate/faction/boss/interdyne,
		/mob/living/basic/trooper/pirate/faction/boss/medieval,
	)
	/// Entourage pools: bounty targets above easy keep hired muscle around
	var/static/list/medium_guards = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
	)
	var/static/list/hard_guards = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
		/mob/living/basic/trooper/pirate/faction/interdyne/ranged,
	)
	/// Whether the target has been killed (the proof item exists)
	var/target_killed = FALSE

/datum/mission/recovery/kill/generate_objective_details()
	var/static/list/target_titles = list("Dread Captain", "Warlord", "Butcher", "Reaver-Lord", "Hexmaster", "Iron Boss")
	var/static/list/target_names = list("Vask", "Korr", "Mirelle", "Ozym", "Sundance", "Grell", "Halix", "Renn")
	objective_name = "[pick(target_titles)] [pick(target_names)]"

/datum/mission/recovery/kill/update_text()
	name = "Kill Contract: [objective_name]"
	desc = "Hunt down [objective_name], holed up at the signal at ([target_x], [target_y]) in the [target_zone_name]. \
		Return their identification tag to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the target's transponder beacon ([gps_tag])."

/datum/mission/recovery/kill/gps_tag_prefix()
	return "HUNT"

/datum/mission/recovery/kill/get_waypoint_info()
	return list("Hunt: [objective_name]", target_x, target_y)

/datum/mission/recovery/kill/spawn_objective()
	if(objective_spawned || QDELETED(target_ruin))
		return
	var/turf/spawn_turf = target_ruin.get_random_interior_turf() || target_ruin.ruin_bottom_left
	if(!spawn_turf)
		return
	var/mob_type
	var/list/guard_pool
	var/guard_count = 0
	switch(difficulty)
		if(MISSION_DIFFICULTY_EASY)
			mob_type = pick(easy_targets)
		if(MISSION_DIFFICULTY_MEDIUM)
			mob_type = pick(medium_targets)
			guard_pool = medium_guards
			guard_count = 1
		else
			mob_type = pick(hard_targets)
			guard_pool = hard_guards
			guard_count = 2
	var/mob/living/target = new mob_type(spawn_turf)
	target.name = objective_name
	target.desc += " They look like they're worth something dead."
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_target_death))
	register_objective(target)
	// The entourage: untracked muscle around the target. Killing them pays
	// nothing — the contract is the name on the tag.
	for(var/_ in 1 to guard_count)
		var/guard_type = pick(guard_pool)
		var/turf/guard_turf = spawn_turf
		var/list/open_neighbors = list()
		for(var/turf/open/tile in RANGE_TURFS(2, spawn_turf))
			if(!tile.is_blocked_turf(exclude_mobs = TRUE))
				open_neighbors += tile
		if(length(open_neighbors))
			guard_turf = pick(open_neighbors)
		var/mob/living/guard = new guard_type(guard_turf)
		guard.desc += " They're on somebody's payroll."

/**
 * The target died: drop the proof item and start tracking it instead.
 */
/datum/mission/recovery/kill/proc/on_target_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(failed || completed || target_killed)
		return
	target_killed = TRUE
	UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))

	var/obj/item/mission_recovery/proof/proof = new(source.drop_location())
	proof.name = "[objective_name]'s identification tag"
	proof.mission_ref = WEAKREF(src)
	// Track the proof item from here on; the corpse no longer matters
	objective_atom = proof
	RegisterSignal(proof, COMSIG_QDELETING, PROC_REF(on_objective_destroyed))
	capture_objective_bounds()
	push_gps_signal()

	if(servant)
		servant.ship_notify("[objective_name] eliminated. Recover the identification tag and return it to the mission pad.", "MISSION UPDATE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

/datum/mission/recovery/kill/retarget()
	// A new target means a new hunt; the old proof (if any) is void
	target_killed = FALSE
	return ..()

/datum/mission/recovery/kill/get_progress_string()
	if(!objective_spawned)
		return "Target at ([target_x], [target_y])"
	if(target_killed)
		return "Return the tag to the pad"
	return "Eliminate [objective_name]"

/**
 * # Mission Recovery Item
 *
 * The physical objective for recovery missions. Bound to its mission;
 * the mission pad only accepts it for the contract that spawned it.
 */
/obj/item/mission_recovery
	name = "recovery objective"
	desc = "Salvage flagged for recovery under a standing contract. The mission pad will accept it."
	icon = 'icons/obj/machines/telecomms.dmi'
	icon_state = "blackcube"
	inhand_icon_state = "blackcube"
	lefthand_file = 'icons/mob/inhands/items_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL

	/// Weakref to the mission this item satisfies
	var/datum/weakref/mission_ref

/obj/item/mission_recovery/examine(mob/user)
	. = ..()
	var/datum/mission/mission = mission_ref?.resolve()
	if(mission && !mission.failed && !mission.completed)
		. += span_notice("Wanted under contract: <b>[mission.name]</b>.")
	else
		. += span_warning("Whatever contract wanted this has expired.")

/obj/item/mission_recovery/proof
	name = "identification tag"
	desc = "Proof that somebody's career ended violently. The mission pad will accept it."
	icon = 'icons/obj/clothing/accessories.dmi'
	icon_state = "skull"
	inhand_icon_state = null
	w_class = WEIGHT_CLASS_TINY

/obj/item/mission_recovery/proof/Initialize(mapload)
	. = ..()
	update_appearance()

// Holochip-style two-part sprite: base state + colorable "-color" card overlay
/obj/item/mission_recovery/proof/update_overlays()
	. = ..()
	var/mutable_appearance/card_overlay = mutable_appearance('icons/obj/economy.dmi', "holochip-color")
	card_overlay.color = "#8E2E38"
	. += card_overlay

#undef MAX_RECOVERY_RETARGETS
