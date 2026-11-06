/// Backgrounds: owned by P2. See data/backgrounds/spec.md.

/**
 * # Convict goal things
 *
 * The Theft convict's haul in his evidence locker, the Smuggler's stash somewhere in the yellow
 * band, the Murderer's witness at a yellow site, and Vex's counter for the stash. Each is made once
 * per ckey per round [ECO-5] and is worth nothing to anyone else: no contents, no export value, no
 * buyback but the owner's own delivery. A stash or a witness waits for its site to load; no goal
 * ever starts a load [SPA-2]. A site that unloads takes them with it, and they are back the next
 * time it loads, until the goal is done.
 */

// ===== THE HAUL =====

/obj/item/convict_haul
	name = "sealed evidence pouch"
	desc = "A sealed pouch with an evidence tag and a name on it."
	icon = 'icons/obj/storage/storage.dmi'
	icon_state = "evidenceobj"
	w_class = WEIGHT_CLASS_SMALL
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The mind it belongs to
	var/datum/weakref/owner_mind
	var/owner_ckey

/obj/item/convict_haul/Destroy()
	owner_mind = null
	return ..()

/obj/item/convict_haul/pickup(mob/user)
	. = ..()
	var/datum/mind/owner = owner_mind?.resolve()
	if(!owner || user?.mind != owner)
		return
	var/datum/background_state/state = owner.background_state
	if(state && !state.ended && state.key == BACKGROUND_CONVICT && state.goal == CONVICT_GOAL_HAUL)
		state.complete("Took the haul back.")

/**
 * Puts `mind`'s haul in their evidence locker: the one minted for their ckey this round if it is
 * still about, else a new one if none was ever minted. Returns it, or null.
 */
/proc/convict_place_haul(datum/mind/mind)
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	var/datum/background_state/state = mind?.background_state
	if(!site || !state?.ckey)
		return null
	var/list/ledger = convict_ledger(state.ckey)
	var/datum/weakref/haul_ref = ledger["haul"]
	var/obj/item/convict_haul/haul = haul_ref?.resolve()
	if(QDELETED(haul))
		haul = null
	if(!haul && haul_ref)
		return null
	var/obj/structure/closet/secure_closet/penitentiary_evidence/locker = site.evidence_locker_for(mind, assign = TRUE)
	if(!locker)
		return null
	if(!haul)
		haul = new(locker)
		ledger["haul"] = WEAKREF(haul)
	else
		haul.forceMove(locker)
	haul.owner_mind = WEAKREF(mind)
	haul.owner_ckey = state.ckey
	haul.name = "sealed evidence pouch ([state.character_name])"
	return haul

// ===== THE STASH AND THE WITNESS =====

/obj/item/convict_stash
	name = "battered strongbox"
	desc = "A dented strongbox with the lock filed off and welded shut again."
	icon = 'icons/obj/storage/case.dmi'
	icon_state = "lockbox"
	w_class = WEIGHT_CLASS_NORMAL
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Whose stash it is
	var/owner_ckey

/mob/living/basic/ambient_npc/convict_witness
	name = "witness"
	desc = "Someone who keeps looking over their shoulder."
	random_name = FALSE
	dialogue_file = "convict_witness.json"
	dialogue_section = "witness"
	outfit_choices = list(/datum/outfit/job/assistant, /datum/outfit/job/cargo_tech, /datum/outfit/job/cook, /datum/outfit/job/botanist)
	speech_pace = 1.5
	routine = list(
		/datum/ambient_activity/idle = 3,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/sit = 2,
	)
	/// The lead that put them here
	var/datum/weakref/lead_ref

/mob/living/basic/ambient_npc/convict_witness/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	var/datum/convict_lead/lead = lead_ref?.resolve()
	lead?.witness_died()

// A witness off their leash walks back or stays put; they never slip away
/mob/living/basic/ambient_npc/convict_witness/give_up_leash()
	return

/// "[ckey]:[goal]" -> the /datum/convict_lead for that convict's stash or witness this round
GLOBAL_LIST_EMPTY(convict_leads)

/**
 * A stash or a witness for one ckey this round: its host site, chosen at the start among the yellow
 * band's ruins and planets, and the thing itself once the host has loaded.
 */
/datum/convict_lead
	/// CONVICT_GOAL_STASH or CONVICT_GOAL_WITNESS
	var/goal
	var/owner_ckey
	var/datum/weakref/host_ref
	/// The host's name as the goal line says it
	var/host_name
	/// The stash or the witness, while it is about
	var/datum/weakref/thing_ref
	/// The witness's name and sex, fixed when the lead is made so the goal line can name them
	var/witness_name
	var/witness_gender
	/// The goal was done; nothing comes back
	var/done = FALSE

/datum/convict_lead/New(goal, owner_ckey)
	. = ..()
	src.goal = goal
	src.owner_ckey = owner_ckey
	if(goal == CONVICT_GOAL_WITNESS)
		witness_gender = pick(MALE, FEMALE)
		witness_name = generate_random_name(witness_gender)
	var/obj/structure/overmap/host = convict_pick_host()
	if(!host)
		return
	host_ref = WEAKREF(host)
	host_name = host.display_name || host.name
	RegisterSignal(host, COMSIG_VOIDCREW_SITE_LOAD_FINISHED, PROC_REF(on_host_loaded))
	RegisterSignal(host, COMSIG_QDELETING, PROC_REF(on_host_deleted))
	if(host.is_loaded())
		INVOKE_ASYNC(src, PROC_REF(place))

/datum/convict_lead/Destroy()
	var/obj/structure/overmap/host = host_ref?.resolve()
	if(host)
		UnregisterSignal(host, list(COMSIG_VOIDCREW_SITE_LOAD_FINISHED, COMSIG_QDELETING))
	host_ref = null
	thing_ref = null
	return ..()

/// The lead for `ckey`'s `goal` this round: the one already made, or a new one
/proc/convict_lead_for(ckey, goal)
	if(!ckey || !(goal in list(CONVICT_GOAL_STASH, CONVICT_GOAL_WITNESS)))
		return null
	var/key = "[ckey]:[goal]"
	var/datum/convict_lead/lead = GLOB.convict_leads[key]
	if(!lead)
		lead = new(goal, ckey)
		GLOB.convict_leads[key] = lead
		var/list/ledger = convict_ledger(ckey)
		ledger[goal == CONVICT_GOAL_STASH ? "stash" : "witness"] = TRUE
	return lead

/// A yellow ruin or planet to hide a stash or a witness at; any band when yellow has none
/proc/convict_pick_host()
	var/list/yellow = list()
	var/list/anywhere = list()
	for(var/obj/structure/overmap/space_ruin/ruin in GLOB.space_ruin_signals)
		if(QDELETED(ruin))
			continue
		anywhere += ruin
		if(SSovermap.get_zone_band_for_turf(get_turf(ruin)) == ZONE_YELLOW)
			yellow += ruin
	for(var/obj/structure/overmap/planet/planet in GLOB.overmap_planets)
		if(QDELETED(planet) || istype(planet, /obj/structure/overmap/planet/empty))
			continue
		anywhere += planet
		if(SSovermap.get_zone_band_for_turf(get_turf(planet)) == ZONE_YELLOW)
			yellow += planet
	if(length(yellow))
		return pick(yellow)
	return length(anywhere) ? pick(anywhere) : null

/datum/convict_lead/proc/host()
	var/obj/structure/overmap/host = host_ref?.resolve()
	return QDELETED(host) ? null : host

/datum/convict_lead/proc/thing()
	var/atom/movable/thing = thing_ref?.resolve()
	return QDELETED(thing) ? null : thing

/datum/convict_lead/proc/on_host_loaded(datum/source, loaded)
	SIGNAL_HANDLER
	if(loaded)
		INVOKE_ASYNC(src, PROC_REF(place))

/datum/convict_lead/proc/on_host_deleted(datum/source)
	SIGNAL_HANDLER
	host_ref = null

/// Puts the stash or the witness at a random open spot on the loaded host, unless it is already there or done
/datum/convict_lead/proc/place()
	if(done || thing())
		return null
	var/obj/structure/overmap/host = host()
	if(!host?.is_loaded())
		return null
	var/turf/spot = convict_host_spot(host)
	if(!spot)
		log_game("BACKGROUNDS: no spot for [owner_ckey]'s [goal] at [host_name]")
		return null
	var/atom/movable/thing
	if(goal == CONVICT_GOAL_STASH)
		var/obj/item/convict_stash/stash = new(spot)
		stash.owner_ckey = owner_ckey
		thing = stash
	else
		var/mob/living/basic/ambient_npc/convict_witness/witness = new(spot)
		witness.gender = witness_gender
		witness.name = witness_name
		witness.real_name = witness_name
		witness.lead_ref = WEAKREF(src)
		witness.leash_bounds = list(spot.x - 6, spot.y - 6, spot.x + 6, spot.y + 6, spot.z)
		thing = witness
	thing_ref = WEAKREF(thing)
	return thing

/// A random open interior turf of a loaded host, clear of the dock strip on a planet
/proc/convict_host_spot(obj/structure/overmap/host)
	var/datum/map_footprint/footprint = host.get_interior_footprint()
	if(!footprint)
		return null
	var/list/bounds = list(footprint.low_x + 2, footprint.low_y + 2, footprint.high_x - 2, footprint.high_y - 2, footprint.z_value)
	if(istype(host, /obj/structure/overmap/planet))
		var/obj/structure/overmap/planet/planet = host
		var/datum/space_level/level = length(planet.mapzone?.z_levels) ? planet.mapzone.z_levels[1] : null
		var/dock_top = level ? planet.get_dock_strip_top_y(level) : null
		if(!isnull(dock_top))
			bounds[2] = max(bounds[2], dock_top + 1)
	return bounty_sample_bounds(bounds)

/// The witness is dead: the score is settled for the convict whose lead this is
/datum/convict_lead/proc/witness_died()
	if(done)
		return
	done = TRUE
	convict_lead_complete(owner_ckey, CONVICT_GOAL_WITNESS, "Settled the score.")

/// The stash reached Vex
/datum/convict_lead/proc/stash_delivered()
	if(done)
		return
	done = TRUE
	convict_lead_complete(owner_ckey, CONVICT_GOAL_STASH, "Delivered the stash.")

/// Completes `goal` for the active convict playing `ckey`, if they have it
/proc/convict_lead_complete(ckey, goal, line)
	for(var/datum/mind/mind as anything in background_active_minds(BACKGROUND_CONVICT))
		var/datum/background_state/state = mind?.background_state
		if(state?.ckey == ckey && state.goal == goal)
			state.complete(line)
			return TRUE
	return FALSE

// ===== VEX TAKES THE STASH =====

/datum/shop_buyback/black_market/convict_stash
	item_path = /obj/item/convict_stash
	category = "Sundries"
	match_subtypes = FALSE
	pay_credits = 0
	demand_min = 8
	demand_max = 8

/// Only the seller's own stash counts
/datum/shop_buyback/black_market/convict_stash/find_offered_items(mob/living/user)
	var/list/found = ..()
	var/seller_ckey = user?.ckey
	for(var/obj/item/convict_stash/stash as anything in found.Copy())
		if(!seller_ckey || stash.owner_ckey != seller_ckey)
			found -= stash
	return found

/datum/shop_buyback/black_market/convict_stash/try_sell(mob/living/user, mob/living/basic/outpost_trader/vendor, quiet = FALSE)
	var/seller_ckey = user?.ckey
	. = ..()
	if(!.)
		return
	// Vex keeps taking deliveries: one per convict, never a shortage
	demand++
	var/datum/convict_lead/lead = seller_ckey ? GLOB.convict_leads["[seller_ckey]:[CONVICT_GOAL_STASH]"] : null
	lead?.stash_delivered()

/datum/outpost_shop/black_market/New(obj/structure/overmap/trader_outpost/outpost)
	// Backgrounds: the Clean Slate counter service and the convict's stash (voidcrew/modules/backgrounds/convict)
	favor_sku_types += /datum/shop_sku/black_market/clean_slate
	buyback_types += /datum/shop_buyback/black_market/convict_stash
	return ..()
