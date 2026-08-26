/**
 * # EXPEDITION uniques: prospector's claim chest
 *
 * Six unique prizes for the expedition uniques shelf
 * (voidcrew/modules/loot/zone_loot.dm, `loot_uniques` on /datum/loot_theme/expedition).
 * Tiers: green = "nice find," yellow = build-around, red = round-changing.
 * None of this is antag gear. These are found-in-the-world prizes for
 * anyone working a planet.
 *
 * Every item here carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so
 * duplicators (Helios pattern stamp, any future replicator) refuse to copy
 * it, see that define's doc comment.
 *
 * Wired into the expedition uniques shelf in
 * voidcrew/modules/loot/themes/expedition.dm.
 */

// =========================================================================
// GREEN
// =========================================================================

/**
 * Old hand's compass: GREEN. A prospector's compass, glass sanded to
 * frost.
 *
 * Subtypes /obj/item/pinpointer (code/game/objects/items/pinpointer.dm)
 * for its full sprite kit and "point toward a tracked atom" scaffolding
 * (get_direction_icon(), the pinon* icon states, toggle_on()/process()).
 * The tracked atom is the nearest space ruin signal that hasn't been
 * visited yet (GLOB.space_ruin_signals, a global per-ruin flag set the
 * moment any ship docks there, see
 * voidcrew/modules/overmap/code/modules/overmap/space_ruin.dm), measured
 * from the wearer's ship's overmap position
 * (/proc/get_ship_from_atom(), ship.dm), falling back to whatever
 * overmap object currently contains the wearer
 * (SSovermap_zones.get_overmap_object_for_turf()) when they're on foot
 * with no ship (e.g. already boarded a ruin).
 *
 * The base pinpointer's overlay logic compares z-levels between "here"
 * (the item's own turf) and "there" (the target's turf), which would
 * always fail here, since the item sits on whatever z the wearer's ship
 * interior is on while the ruin sits on the single overmap z-level.
 * update_overlays() is overridden to instead measure between the two
 * OVERMAP-z reference turfs directly, reusing the inherited
 * get_direction_icon() proc unchanged once both are confirmed to be on
 * that shared z.
 *
 * Deviations from the doc:
 * - "Visited" reuses the ruin's own global `visited` flag (set once any
 *   ship docks there) rather than per-player tracking, there is no
 *   existing per-player "have I been here" bookkeeping anywhere in this
 *   codebase, and the task brief calls a simple substitute acceptable.
 * - "Point of interest" is scoped to ruins only (space_ruin signals).
 *   Trader/player outposts don't carry a `visited` var in this codebase,
 *   so folding them in would mean inventing new bookkeeping.
 * - When the wearer can't be resolved to *any* overmap position (holding
 *   it on CentCom, say), it shows the normal "no signal" pinpointer icon
 *   rather than pointing north. North is reserved specifically for
 *   "every reachable ruin has been visited," matching the doc's "when
 *   you've been everywhere" framing.
 *
 * PLAYTEST FIX (2026-07-28), "doesn't seem to work, not sure how it works".
 * The tracking itself resolves fine; the problem was that the *only* output
 * was the needle overlay on the item icon, and that needle points along
 * OVERMAP axes. Standing in a ship interior, a north-east needle means
 * nothing about the room you're in, and it doesn't move at all while the
 * ship is parked, so a working compass is indistinguishable from a dead
 * one. On top of that, `scan_for_target()` is throttled to one scan per
 * `scan_interval`, and switching the compass on did not force a scan, so
 * the first thing you saw after clicking it could be up to 3 seconds of the
 * "no signal" needle. Fixes: activation forces an immediate scan and prints
 * a readout, examine() prints the same readout any time, and the compass
 * speaks up in chat whenever the tracked signal changes or you arrive on
 * top of it. The needle overlay is unchanged.
 */
/obj/item/pinpointer/old_hands_compass
	name = "old hand's compass"
	desc = "A prospector's compass with the glass sanded to frost. Switched on, the needle points at the nearest space ruin nobody's docked at yet. Click it in hand to switch it on or off; examine it for the bearing and range."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "brass_compass"
	// Bare-string overlays (the "pinon*" needle states the parent appends) resolve
	// against this atom's own icon, not the base pinpointer's tracker.dmi, so the
	// needle set is mirrored into uniques.dmi under this suffix, exactly as the
	// "_hunter" pinpointer variant does inside tracker.dmi. Without it the compass
	// renders no needle at all, not even the "no signal" state.
	icon_suffix = "_compass"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 2)
	/// Cached overmap turf of whatever's carrying the compass, set by scan_for_target()
	var/turf/cached_reference_turf
	/// Cached overmap turf of the target ruin, set by scan_for_target()
	var/turf/cached_target_turf
	/// TRUE once every reachable ruin signal has been visited
	var/found_everything = FALSE
	/// Throttle: the expensive GLOB.space_ruin_signals scan only runs this often
	var/next_scan_time = 0
	/// How often that scan runs. Printed in the examine text.
	var/scan_interval = 3 SECONDS
	/// Last signal reported to whoever's carrying it, so chat only fires on a change
	var/atom/movable/last_reported
	/// TRUE once the "you're on top of it" line has been printed for last_reported
	var/reported_arrival = FALSE

/obj/item/pinpointer/old_hands_compass/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/pinpointer/old_hands_compass/Destroy()
	cached_reference_turf = null
	cached_target_turf = null
	last_reported = null
	return ..()

/obj/item/pinpointer/old_hands_compass/attack_self(mob/living/user)
	toggle_on()
	user.visible_message(span_notice("[user] [active ? "" : "de"]activates [user.p_their()] compass."), span_notice("You [active ? "" : "de"]activate your compass."))
	last_reported = null
	reported_arrival = FALSE
	if(!active)
		cached_target_turf = null
		return
	// Scan right now instead of waiting out the throttle on the next process
	// tick, so switching it on always produces a readout immediately.
	next_scan_time = 0
	scan_for_target()
	update_appearance()
	to_chat(user, span_notice(needle_readout()))
	last_reported = target

/**
 * One plain sentence describing what the needle is doing right now. Shared by
 * examine(), the activation message and the in-chat updates so they can never
 * disagree with each other.
 */
/obj/item/pinpointer/old_hands_compass/proc/needle_readout()
	if(!active)
		return "The needle sits loose in the housing. Click it in hand to switch it on."
	if(found_everything)
		return "The needle holds due north and won't move. Every signal on the map has been docked at least once."
	if(!cached_reference_turf)
		return "The needle wanders. It only gets a bearing aboard a ship or somewhere charted on the overmap."
	if(!target || !cached_target_turf)
		return "The needle wanders. There's nothing for it to point at."
	var/distance = get_dist(cached_reference_turf, cached_target_turf)
	if(distance <= 0)
		return "The needle points straight down. You're on top of the signal."
	return "The needle points [dir2text(get_dir(cached_reference_turf, cached_target_turf))], [distance] tile\s out on the overmap."

/obj/item/pinpointer/old_hands_compass/examine(mob/user)
	. = ..()
	. += span_notice(needle_readout())
	if(active)
		. += span_notice("It re-checks the map every [DisplayTimeText(scan_interval)].")

/obj/item/pinpointer/old_hands_compass/process(seconds_per_tick)
	. = ..()
	if(!active)
		return
	var/mob/holder = get(src, /mob)
	if(!holder)
		return
	if(target != last_reported)
		last_reported = target
		reported_arrival = FALSE
		balloon_alert(holder, "needle swings")
		to_chat(holder, span_notice("[src] ticks over. [needle_readout()]"))
		return
	if(reported_arrival || !target || !cached_reference_turf || !cached_target_turf)
		return
	if(get_dist(cached_reference_turf, cached_target_turf) > 0)
		return
	reported_arrival = TRUE
	to_chat(holder, span_notice("[src]'s needle drops flat. You're on top of the signal."))

/obj/item/pinpointer/old_hands_compass/scan_for_target()
	if(world.time < next_scan_time)
		return
	next_scan_time = world.time + scan_interval

	var/obj/structure/overmap/reference_obj = get_ship_from_atom(src)
	var/turf/here = get_turf(src)
	if(!reference_obj && here)
		reference_obj = SSovermap_zones.get_overmap_object_for_turf(here)

	var/turf/reference_turf = reference_obj ? get_turf(reference_obj) : null
	if(!istype(reference_turf, /turf/open/overmap))
		cached_reference_turf = null
		cached_target_turf = null
		target = null
		found_everything = FALSE
		return

	cached_reference_turf = reference_turf
	found_everything = FALSE

	var/best_distance = INFINITY
	var/obj/structure/overmap/space_ruin/nearest_unvisited
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(ruin.visited)
			continue
		var/turf/ruin_turf = get_turf(ruin)
		if(!istype(ruin_turf, /turf/open/overmap))
			continue
		var/distance = get_dist(reference_turf, ruin_turf)
		if(distance < best_distance)
			best_distance = distance
			nearest_unvisited = ruin

	if(!nearest_unvisited)
		cached_target_turf = null
		target = null
		found_everything = TRUE
		return

	cached_target_turf = get_turf(nearest_unvisited)
	target = nearest_unvisited

/obj/item/pinpointer/old_hands_compass/update_overlays()
	. = ..()
	if(!active)
		return
	// The parent's overlay logic compares the item's z to the target's z,
	// always a mismatch here (ship interior vs overmap), so it appends its
	// "no signal" overlay every time; strip it before adding the real needle
	. -= "pinon[alert ? "alert" : ""]null[icon_suffix]"
	if(found_everything)
		setDir(NORTH)
		. += "pinon[alert ? "alert" : ""]direct[icon_suffix]"
		return
	if(!cached_reference_turf || !cached_target_turf)
		. += "pinon[alert ? "alert" : ""]null[icon_suffix]"
		return
	. += get_direction_icon(cached_reference_turf, cached_target_turf)

/**
 * Claim stake: GREEN. A steel stake with a brass claim-plate.
 *
 * Use in hand to drive it into solid ground: while deployed, wild fauna
 * within a 5-tile claim radius get the local planet factions
 * (FACTION_WASTELAND/FACTION_BEACH/FACTION_CRYSTAL,
 * voidcrew/_DEFINES/mobfactions.dm) temporarily added to their own faction
 * list, which is exactly the check `basic_targeting_strategy/can_attack()`
 * already uses to skip attacking friendlies (non-exact faction overlap,
 * code/datums/ai/basic_mobs/targeting_strategies/basic_targeting_strategy.dm),
 * no new safe-zone infrastructure, just the same lever the codebase uses
 * everywhere else to make a faction-driven mob leave something alone. It
 * also carries a GPS beacon (/datum/component/gps) tagged with the
 * driving prospector's name.
 *
 * "One claim per stake": a stake can only be deployed in one place at a
 * time (it's a single physical object), and pulling it up clears the
 * entire claim in one shot. There's no lingering aura after retrieval.
 *
 * PLAYTEST FIX (2026-07-28), "seems like it keeps the effect after you pull
 * it out". The teardown was only wired to two paths: attack_hand() and
 * Destroy(). A planted stake is anchored, which stops `/obj/item/attack_hand`
 * from picking it up, but it does NOT stop the other pickup routes.
 * Mouse-dragging it onto yourself calls `attempt_pickup()` directly (no
 * anchored check, see code/game/objects/items.dm), and storage inserts,
 * explosions, telekinesis and singularity pulls all just move the object.
 * Any of those left `deployed` TRUE with the stake in someone's hand: it kept
 * processing, kept the GPS beacon, and kept lending planet factions to
 * everything within 5 tiles of the *carrier*, which is exactly the reported
 * "effect follows you around after you pull it out". Fixed by hanging the
 * teardown off Moved() instead, so the claim strictly tracks "the stake is
 * sitting on the turf it was driven into".
 *
 * Deviation: fauna already mid-retaliation bypass the faction check by
 * design, `target_retaliate` sets BB_TEMPORARILY_IGNORE_FACTION when
 * picking a target off its "recently attacked me" list
 * (code/datums/ai/basic_mobs/basic_subtrees/target_retaliate.dm), so the
 * claim keeps fauna from *starting* a fight inside the radius, it doesn't
 * pull them off one already underway. Stripping that list would mean
 * touching shared AI code outside this file's scope.
 */
/obj/item/claim_stake
	name = "claim stake"
	desc = "A steel stake with a brass claim-plate. Driven into the ground it keeps local wildlife from starting fights within 5 tiles. The claim ends the moment the stake leaves the ground."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "claim_stake"
	worn_icon_state = "marker"
	w_class = WEIGHT_CLASS_SMALL
	force = 5
	throwforce = 5
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 5)
	/// Currently driven into the ground and running its claim
	var/deployed = FALSE
	/// Tile radius fauna won't start a fight inside
	var/claim_radius = 5
	/// Planet fauna factions the claim temporarily lends to anyone standing inside it
	var/static/list/claimed_factions = list(FACTION_WASTELAND, FACTION_BEACH, FACTION_CRYSTAL)
	/// mob -> list of faction strings we added to them, so release_mob() removes exactly what we gave
	var/list/protected_mobs = list()
	/// Name recorded on the GPS beacon when driven in
	var/owner_name

/obj/item/claim_stake/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/claim_stake/Destroy()
	clear_claim()
	return ..()

/**
 * The claim only exists while the stake is standing in the ground, so any move
 * at all ends it. drive_claim() forceMoves the stake onto the turf *before* it
 * sets deployed, and retract_claim() clears the claim before put_in_hands(), so
 * neither of the intended paths trips this, it only catches the ones that
 * bypass attack_hand() (drag-to-hand, storage inserts, explosions, telekinesis).
 */
/obj/item/claim_stake/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if(!deployed)
		return
	visible_message(span_notice("[src] comes out of the ground. The claim ends."))
	clear_claim()

/obj/item/claim_stake/examine(mob/user)
	. = ..()
	if(deployed)
		. += span_notice("It's in the ground under [owner_name]. Wildlife won't start fights within [claim_radius] tiles of it.")
		. += span_notice("Click it with an empty hand to pull it back out. Takes 2 seconds, and the claim ends the moment it's out.")
	else
		. += span_notice("Use it in hand to drive it into solid ground. Takes 3 seconds.")
		. += span_notice("While it's planted, wildlife won't start fights within [claim_radius] tiles of it. Picking it up ends the claim.")

/obj/item/claim_stake/attack_self(mob/user)
	if(deployed)
		return
	if(!isturf(user.loc))
		to_chat(user, span_warning("You need solid ground to drive [src] in."))
		return
	to_chat(user, span_notice("You start driving [src] into the ground..."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	// still in the user's hand, on solid ground, and nobody beat them to it
	if(deployed || loc != user || !isturf(user.loc))
		return
	drive_claim(user)

/// Picking a deployed stake back up requires pulling it, not a normal grab
/obj/item/claim_stake/attack_hand(mob/user, list/modifiers)
	if(!deployed)
		return ..()
	to_chat(user, span_notice("You start pulling [src] back out of the ground..."))
	if(!do_after(user, 2 SECONDS, target = src))
		return
	if(!deployed)
		return
	retract_claim(user)
	user.put_in_hands(src)

/obj/item/claim_stake/proc/drive_claim(mob/user)
	forceMove(get_turf(user))
	deployed = TRUE
	anchored = TRUE
	owner_name = user.real_name || "an unnamed prospector"
	AddComponent(/datum/component/gps, "[owner_name]'s claim")
	START_PROCESSING(SSobj, src)
	user.visible_message(span_notice("[user] drives [src] into the ground."), span_notice("You drive [src] into the ground. The claim is yours."))
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)

/obj/item/claim_stake/proc/retract_claim(mob/user)
	if(user)
		to_chat(user, span_notice("You pull [src] back out of the ground. The claim ends."))
	clear_claim()

/obj/item/claim_stake/proc/clear_claim()
	deployed = FALSE
	anchored = FALSE
	owner_name = null
	var/datum/component/gps/beacon = GetComponent(/datum/component/gps)
	if(beacon)
		qdel(beacon)
	STOP_PROCESSING(SSobj, src)
	for(var/mob/living/protected_mob as anything in protected_mobs.Copy())
		release_mob(protected_mob)
	protected_mobs = list()

/obj/item/claim_stake/process(seconds_per_tick)
	if(!deployed)
		return PROCESS_KILL
	var/list/currently_in_range = list()
	for(var/mob/living/nearby_mob in range(claim_radius, src))
		if(nearby_mob.stat == DEAD)
			continue
		currently_in_range += nearby_mob
		if(!(nearby_mob in protected_mobs))
			protect_mob(nearby_mob)
	for(var/mob/living/protected_mob as anything in protected_mobs.Copy())
		// QDELETED mobs can't be in range any more, but drop the hard ref explicitly
		// rather than waiting on the range() check to notice
		if(QDELETED(protected_mob) || !(protected_mob in currently_in_range))
			release_mob(protected_mob)

// add_faction()/remove_faction() rather than += and -=: faction lists are interned by
// string_list() at Initialize(), so every mob with the same faction signature shares one list
// object. Editing it in place writes our claim into the shared entry and protects every mob of
// that type in the round. The API duplicates and re-interns instead, and add_faction() returns
// TRUE only when the token was not already there, which is the same test the old code did by
// hand - so `added` still records exactly what we put on and release_mob() strips no more.
/obj/item/claim_stake/proc/protect_mob(mob/living/target_mob)
	var/list/added = list()
	for(var/faction_string in claimed_factions)
		if(target_mob.add_faction(faction_string))
			added += faction_string
	protected_mobs[target_mob] = added

/obj/item/claim_stake/proc/release_mob(mob/living/target_mob)
	var/list/added = protected_mobs[target_mob]
	// a deleted mob has nothing left to strip, but its entry still has to go
	if(length(added) && !QDELETED(target_mob))
		target_mob.remove_faction(added)
	protected_mobs -= target_mob

// =========================================================================
// YELLOW
// =========================================================================

/**
 * "Second Season", YELLOW. A duster gone the color of every planet it's
 * been on.
 *
 * Subtypes /obj/item/clothing/suit/hooded/explorer
 * (code/modules/mining/equipment/explorer_gear.dm) for its hood and armor.
 *
 * Sprite (2026-07-28, was flagged in playtest as still wearing the stock
 * explorer suit art): custom "second_season" states in uniques.dmi (item) and
 * uniques_worn.dmi (worn, 4 dirs). The worn state is drawn on the vanilla
 * labcoat worn pixel mask (icons/mob/clothing/suits/labcoat.dmi) so the body
 * zones line up exactly, recoloured to sun-bleached tan canvas with dust
 * ground into the hem. `hood_up_affix` is blanked deliberately: the base
 * hooded-suit type otherwise points icon_state AND worn_icon_state at
 * "<state>_t" the moment the hood goes up (see
 * /datum/component/toggle_attached_clothing), and there is no
 * "second_season_t" state, the coat would vanish. With the affix blank the
 * coat sprite simply doesn't change, which is a supported mode of the base
 * type, and the hood itself still renders on the head.
 *
 * Weather immunity uses the idiomatic path: `clothing_traits`
 * (auto-applied/removed by the base equipped()/dropped() in
 * code/modules/clothing/clothing.dm) covers every planet-relevant weather
 * immunity trait that exists in declarations.dm, skipping the blanket
 * TRAIT_WEATHER_IMMUNE (that also cancels effects this item was never
 * meant to touch, like void storms).
 *
 * Rough-terrain immunity can't reuse TRAIT_IGNORESLOWDOWN, verified that
 * trait strips *every* non-IGNORE_NOSLOW movespeed modifier, including
 * armor/equipment slowdown, which this item must leave alone. Instead it
 * hooks COMSIG_MOVABLE_MOVED on the wearer and clears exactly the
 * `/datum/movespeed_modifier/turf_slowdown` entry after every step, the
 * same modifier `update_turf_movespeed()` re-applies on each move
 * (code/modules/mob/living/living_movement.dm), via the public
 * `/mob/proc/remove_movespeed_modifier()`. That's surgical: it never
 * touches equipment_speedmod or anything else.
 *
 * Deviation: this fork's planet weather roster
 * (voidcrew/modules/overmap/code/modules/overmap/behaviour/planets.dm) is
 * ash_storm (lava) / snow_storm (ice) / sand_storm (wasteland) /
 * rain_storm (beach, jungle), there is no "rad squall" planet weather in
 * this codebase to be immune to (rad_storm exists only as a station-level
 * random event). Rad-storm immunity is granted anyway since the trait is
 * real and free; it just never fires on a planet in this fork.
 */
/obj/item/clothing/suit/hooded/explorer/second_season_duster
	name = "\"Second Season\""
	desc = "A long canvas duster bleached by every planet it's been on. Storms don't touch you in it, and rough ground doesn't slow you down."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "second_season"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	hood_up_affix = ""
	clothing_traits = list(TRAIT_ASHSTORM_IMMUNE, TRAIT_SNOWSTORM_IMMUNE, TRAIT_SANDSTORM_IMMUNE, TRAIT_RAINSTORM_IMMUNE, TRAIT_RADSTORM_IMMUNE)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/examine(mob/user)
	. = ..()
	. += span_notice("Worn, it blocks ash, snow, sand and rain storms outright.")
	. += span_notice("Rough ground - sand, snow, mud - doesn't slow you down while you've got it on.")

/obj/item/clothing/suit/hooded/explorer/second_season_duster/equipped(mob/user, slot, initial)
	. = ..()
	if(slot_flags & slot)
		RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_wearer_moved), override = TRUE)
		user.remove_movespeed_modifier(/datum/movespeed_modifier/turf_slowdown)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/dropped(mob/user, silent)
	. = ..()
	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/proc/on_wearer_moved(mob/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	source.remove_movespeed_modifier(/datum/movespeed_modifier/turf_slowdown)

/**
 * Divining pick, YELLOW. A pickaxe with a forked tip and opinions.
 *
 * Directly subtypes /obj/item/pickaxe (code/modules/mining/equipment/
 * mining_tools.dm) for its sprite and mining behavior, no changes to how
 * it actually breaks rock.
 *
 * "Hums when you're warm": examine() reads nearby /turf/closed/mineral
 * tiles' `mineral_amt` (the vanilla richness/yield var) and reports a hum
 * intensity plus a compass direction toward the richest one.
 *
 * "Cracks the seam wider": while held, it listens on its wielder for
 * COMSIG_MOB_MINED: the signal every successful `gets_drilled()` call
 * sends to the mining mob regardless of tool
 * (code/game/turfs/closed/minerals.dm), and, on that signal, walks a
 * cascade outward from the mined tile, using the same orange(1, turf)
 * neighbor-walk idiom the resonator's burst() uses
 * (code/modules/mining/equipment/resonator.dm). This is done via signal
 * registration on the *wielder*, not by overriding
 * `/turf/closed/mineral/gets_drilled()` itself, that proc lives in
 * upstream code this file must not edit, and the signal hook reaches the
 * exact same event without touching it.
 *
 * PLAYTEST CHANGE (2026-07-28): "make it cascade even further, like up to 3
 * adjacent in each direction". The cascade was one hop: it only ever looked at
 * the eight tiles touching the one you broke. It's now a bounded
 * breadth-first walk out to `cascade_range` steps, where each tile that cracks
 * open becomes a new front for the next step, so a good roll reaches three
 * tiles out in every direction. It stays cheap because the walk is synchronous
 * over at most a 7x7 block, every tile is visited once (`seen`), and the total
 * is hard-capped at `cascade_max_tiles`.
 */
/obj/item/pickaxe/divining
	name = "divining pick"
	desc = "A pickaxe with a forked tip that hums when there's good rock nearby. Breaking a seam cracks open the rock around it, up to 3 tiles out in every direction."
	toolspeed = 0.8
	force = 16
	/// How many steps out from the mined tile the cascade can reach
	var/cascade_range = 3
	/// Chance a tile one step out cracks open
	var/cascade_base_chance = 65
	/// How much that chance drops for every further step out
	var/cascade_decay = 18
	/// Hard cap on tiles cracked open per swing, so a big field can't chain forever
	var/cascade_max_tiles = 24

/obj/item/pickaxe/divining/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/pickaxe/divining/equipped(mob/user, slot, initial)
	. = ..()
	// only while actually wielded. Belted/backpacked shouldn't cascade off a different tool's mining
	if(slot & ITEM_SLOT_HANDS)
		RegisterSignal(user, COMSIG_MOB_MINED, PROC_REF(on_wielder_mined), override = TRUE)

/obj/item/pickaxe/divining/dropped(mob/user, silent)
	. = ..()
	UnregisterSignal(user, COMSIG_MOB_MINED)

/obj/item/pickaxe/divining/proc/on_wielder_mined(datum/source, turf/closed/mineral/rock, exp_multiplier)
	SIGNAL_HANDLER
	if(!istype(rock))
		return
	var/mob/user = source
	// Breadth-first walk outward: `frontier` is the set of tiles that cracked
	// open on the previous step, and only those seed the next step, so the
	// cascade actually travels instead of only touching the first ring. `seen`
	// means no tile is ever rolled twice and the walk can't loop back.
	var/list/seen = list()
	seen[rock] = TRUE
	var/list/frontier = list(rock)
	var/list/cracked = list()
	for(var/step in 1 to cascade_range)
		var/chance = max(cascade_base_chance - (cascade_decay * (step - 1)), 5)
		var/list/next_frontier = list()
		for(var/turf/closed/mineral/front as anything in frontier)
			for(var/turf/closed/mineral/neighbor in orange(1, front))
				if(seen[neighbor])
					continue
				seen[neighbor] = TRUE
				if(!prob(chance))
					continue
				cracked += neighbor
				next_frontier += neighbor
				if(length(cracked) >= cascade_max_tiles)
					break
			if(length(cracked) >= cascade_max_tiles)
				break
		if(!length(next_frontier) || length(cracked) >= cascade_max_tiles)
			break
		frontier = next_frontier
	var/stagger = 0
	for(var/turf/closed/mineral/cracked_turf as anything in cracked)
		stagger += 2
		addtimer(CALLBACK(src, PROC_REF(cascade_drill), cracked_turf, user), stagger)

/obj/item/pickaxe/divining/proc/cascade_drill(turf/closed/mineral/target_turf, mob/user)
	if(!ismineralturf(target_turf))
		return
	// Null user on purpose: gets_drilled(mob) re-sends COMSIG_MOB_MINED, which
	// would re-trigger on_wielder_mined at full base chance and chain-react
	// across the whole connected field instead of the one-hop decaying cascade
	target_turf.gets_drilled(null, 0)

/obj/item/pickaxe/divining/examine(mob/user)
	. = ..()
	var/turf/here = get_turf(src)
	if(!here)
		return
	var/turf/closed/mineral/richest
	var/best_amount = 0
	for(var/turf/closed/mineral/nearby_rock in orange(5, here))
		if(nearby_rock.mineral_amt > best_amount)
			best_amount = nearby_rock.mineral_amt
			richest = nearby_rock
	if(!richest)
		. += span_notice("It sits quiet and cool.")
		return
	var/intensity = "hums faintly"
	if(best_amount >= 6)
		intensity = "thrums warm and insistent"
	else if(best_amount >= 3)
		intensity = "hums steadily"
	. += span_notice("It [intensity], leaning toward the [dir2text(get_dir(here, richest))].")

// =========================================================================
// RED
// =========================================================================

/**
 * Deepwell: RED. A core sampler crated in claim-office gray, deploying
 * into an autonomous mining machine.
 *
 * PLAYTEST REDESIGN (2026-07-28): "I'm not sure how this is actually
 * useful... it only works once? it only mines one time."
 *
 * Two things made it read as single-use. First, the rig only ever worked the
 * one seam it was bolted next to: the dig queue was a flood-fill through
 * *connected* mineral turfs, with a permanent `seen_turfs` list, so the moment
 * that seam ran out it went silent forever and nothing could ever put work
 * back in the queue. Planet ore seams are small, so that was usually a handful
 * of walls. Second, deploying consumed the item and nothing in the game told
 * you the machine could be wrenched back into its crate, so a spent rig looked
 * like a wasted red-tier prize.
 *
 * Redesign, keeping the identity (plant it, it deep-samples and auto-smelts):
 * - It is a RADIUS miner, not a vein-follower. It drills any mineral wall
 *   within `dig_radius` (7) tiles, nearest ring first, connected or not.
 * - One wall every `pulse_interval` (2) seconds: that's a full 7-tile field
 *   worked in a few minutes, unattended, with the ore already smelted.
 * - When it runs out it goes idle instead of dying: it rescans every
 *   `idle_rescan_interval` (15) seconds, so rock you blast open nearby later
 *   gets picked up without touching the rig.
 * - Wrenching it packs it back into the crate, and the examine text says so.
 * All the numbers above are stated in the item desc and the machine examine.
 *
 * No autonomous/deployable mining machine exists anywhere in this
 * codebase (verified), this is new machinery, but every mechanic it
 * uses is a direct reuse of an existing pattern:
 * - Drilling: calls the turf's own `gets_drilled()`: the universal
 *   mining entry point ~30 other sources already call
 *   (code/game/turfs/closed/minerals.dm).
 * - Auto-smelting: converts the dropped ore stack to sheets via the ore
 *   stack's own `refined_type` var, the same 1:1 lookup
 *   `/obj/item/stack/ore/welder_act()` uses to self-refine
 *   (code/modules/mining/ores_coins.dm), rather than wiring up a full
 *   material_container/ORM integration.
 * - Periodic work: plain /obj/machinery processing (default
 *   `processing_flags = START_PROCESSING_ON_INIT`, ticks every ~2s via
 *   SSmachines) with its own internal accumulator for the slower pulse
 *   rate, mirroring `/obj/machinery/mineral/processing_unit/process()`
 *   (code/modules/mining/machine_processing.dm).
 *
 * Balance knobs preserved: it's loud (large-radius playsound every
 * pulse) and it periodically re-points nearby fauna ai_controllers at
 * itself, so leaving it unattended draws wildlife.
 *
 * Deviation: there is no sound-propagation/noise-investigation AI system
 * anywhere in this codebase (verified, nothing hooks mob hearing to AI
 * targeting; `/datum/element/hostile_machine`, the closest purpose-built
 * "make wildlife attack a fixed machine" lever, requires editing the
 * shared basic_targeting_strategy `can_attack()` proc to special-case a
 * new object type, which is out of scope for a single-new-file change).
 * The closest feasible substitute, and what's implemented here, is a
 * direct, repeating `ai_movement.start_moving_towards()` ping on nearby
 * fauna — a pull, not a summon or a true noise mechanic. A fauna's own
 * planning tick can override it moments later (chasing something else,
 * fleeing, etc.), so the ping repeats periodically rather than being
 * fire-and-forget.
 */
/obj/item/deepwell_sampler
	name = "deepwell core sampler"
	desc = "A drill rig crated in claim-office gray. Bolted down, it drills one wall of rock every 2 seconds anywhere within 7 tiles and smelts what it pulls up into sheets at its feet. Wrench it to pack it back into the crate."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "deepwell_item"
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3, /datum/material/glass = SHEET_MATERIAL_AMOUNT)
	/// Must match the machine's dig_radius, checked before letting anyone bolt it down
	var/dig_radius = 7

/obj/item/deepwell_sampler/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/deepwell_sampler/examine(mob/user)
	. = ..()
	. += span_notice("Use it in hand to bolt it down. Takes 3 seconds, and there has to be rock within [dig_radius] tiles.")
	. += span_notice("It keeps working on its own, and it's loud enough that wildlife comes to look. Wrench it to pack it up and move it.")

/obj/item/deepwell_sampler/attack_self(mob/user)
	var/turf/target_turf = get_turf(user)
	if(!target_turf || !length(mineral_turfs_in_range(target_turf, dig_radius)))
		to_chat(user, span_warning("[src] needs rock within [dig_radius] tiles to be worth bolting down. There's nothing here to drill."))
		return
	to_chat(user, span_notice("You start bolting [src] down..."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	if(!isturf(user.loc) || QDELETED(src))
		return
	user.visible_message(span_notice("[user] bolts [src] down."), span_notice("You bolt [src] down. It'll work the rock around it on its own - somebody should stay with it."))
	new /obj/machinery/deepwell_sampler(get_turf(user))
	qdel(src)

/// Every mineral wall within `radius` of `center`. Shared by the crate's deploy check and the rig's queue refill.
/proc/mineral_turfs_in_range(turf/center, radius)
	. = list()
	if(!center)
		return
	for(var/turf/closed/mineral/rock in range(radius, center))
		. += rock

/obj/machinery/deepwell_sampler
	name = "deepwell sampler"
	desc = "A core sampler bolted to the ground, drilling out the rock around it and smelting what it brings up. It's extremely loud, and the wildlife comes to look."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "deepwell"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	/// Tiles out from the rig it will drill. Any mineral wall in here is fair game,
	/// connected to the last one or not. That's what makes it a site miner
	/// rather than a one-seam machine.
	var/dig_radius = 7
	/// Seconds between drill pulses: plain seconds, matching process()'s
	/// seconds_per_tick accumulator (a `X SECONDS` value here would be
	/// deciseconds and slow the drill down tenfold)
	var/pulse_interval = 2
	/// Seconds between rescans once there's nothing left in range
	var/idle_rescan_interval = 15
	var/pulse_accumulator = 0
	/// TRUE while there's no rock left in range; it keeps rescanning, slower
	var/idle = FALSE
	/// Tile radius the fauna-attraction ping reaches
	var/attraction_range = 12
	/// Pulses between fauna-attraction pings
	var/pulses_since_ping = 0
	/// Sheets stacked up since it was bolted down, reported on examine
	var/sheets_produced = 0
	/// Walls still queued from the last scan, nearest ring first
	var/list/turf/closed/mineral/dig_queue = list()

/obj/machinery/deepwell_sampler/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	refill_queue()

/obj/machinery/deepwell_sampler/Destroy()
	dig_queue = null
	return ..()

/obj/machinery/deepwell_sampler/examine(mob/user)
	. = ..()
	. += span_notice("It drills one wall every [pulse_interval] seconds, anywhere within [dig_radius] tiles, and smelts what it brings up into sheets at its feet.")
	if(idle)
		. += span_warning("It's idle - no rock left within [dig_radius] tiles. It rechecks every [idle_rescan_interval] seconds, so blasting open more rock nearby will start it again.")
	else
		. += span_notice("[length(dig_queue)] wall\s left in this pass.")
	. += span_notice("It's smelted [sheets_produced] sheet\s so far. Wrench it to pack it back into its crate.")

/**
 * Rebuilds the whole dig queue from a fresh scan of the surrounding tiles,
 * nearest ring first so the rig eats outward instead of jumping around. Called
 * on deploy and every time the queue runs dry. The rescan is what lets a rig
 * pick up rock that got opened up after it was planted, instead of being
 * permanently spent the way the old connected-vein flood fill was.
 */
/obj/machinery/deepwell_sampler/proc/refill_queue()
	dig_queue = list()
	var/turf/here = get_turf(src)
	if(!here)
		return
	var/list/rings = list()
	for(var/ring in 1 to dig_radius)
		rings += list(list())
	for(var/turf/closed/mineral/rock as anything in mineral_turfs_in_range(here, dig_radius))
		var/distance = get_dist(here, rock)
		if(distance < 1 || distance > dig_radius)
			continue
		var/list/bucket = rings[distance]
		bucket += rock
	for(var/list/bucket as anything in rings)
		dig_queue += bucket

/obj/machinery/deepwell_sampler/process(seconds_per_tick)
	pulse_accumulator += seconds_per_tick
	if(pulse_accumulator < (idle ? idle_rescan_interval : pulse_interval))
		return
	pulse_accumulator = 0
	do_pulse()

/obj/machinery/deepwell_sampler/proc/do_pulse()
	if(!length(dig_queue))
		refill_queue()
	if(!length(dig_queue))
		if(!idle)
			idle = TRUE
			visible_message(span_notice("[src] winds down. There's no rock left within [dig_radius] tiles of it."))
		return
	if(idle)
		idle = FALSE
		visible_message(span_notice("[src] spins back up and bites into the rock."))
	pulses_since_ping++
	if(pulses_since_ping >= 5)
		pulses_since_ping = 0
		attract_fauna()
	// pop stale entries (someone else mined that wall since the last scan) rather
	// than burning a whole pulse on each one
	var/turf/closed/mineral/vein_turf
	while(length(dig_queue))
		var/turf/candidate = dig_queue[1]
		dig_queue.Cut(1, 2)
		if(ismineralturf(candidate))
			vein_turf = candidate
			break
	if(!vein_turf)
		return
	playsound(src, 'sound/effects/break_stone.ogg', 70, TRUE, 14)
	vein_turf.gets_drilled(null, 0)
	for(var/obj/item/stack/ore/dropped_ore in vein_turf)
		smelt_and_deposit(dropped_ore)

/obj/machinery/deepwell_sampler/proc/smelt_and_deposit(obj/item/stack/ore/raw_ore)
	if(!raw_ore.refined_type)
		qdel(raw_ore)
		return
	var/turf/base = get_turf(src)
	var/obj/item/stack/sheet/refined = locate(raw_ore.refined_type) in base
	if(refined)
		refined.add(raw_ore.amount)
	else
		new raw_ore.refined_type(base, raw_ore.amount)
	sheets_produced += raw_ore.amount
	qdel(raw_ore)

/obj/machinery/deepwell_sampler/proc/attract_fauna()
	for(var/mob/living/fauna in orange(attraction_range, src))
		if(fauna.stat == DEAD || !fauna.ai_controller)
			continue
		// VOIDCREW EDIT: upstream deleted /datum/ai_controller/set_movement_target(); the movement
		// datum now owns the target and starts the loop itself.
		fauna.ai_controller.change_ai_movement_type(/datum/ai_movement/basic_avoidance)
		fauna.ai_controller.ai_movement.start_moving_towards(fauna.ai_controller, src, min_distance = 1)

/obj/machinery/deepwell_sampler/wrench_act(mob/living/user, obj/item/tool)
	tool.play_tool_sound(src)
	to_chat(user, span_notice("You unbolt [src] and pack it back into its crate."))
	new /obj/item/deepwell_sampler(get_turf(src))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/**
 * Longwalk rig: RED. A leg harness of pistons and cable, trail-patched.
 *
 * Grants a dash action modeled directly on jump boots' dash
 * (code/modules/clothing/shoes/jumpboots.dm): `throw_at()` covering the
 * distance with `TRAIT_MOVE_FLOATING` (source-keyed `LEAPING_TRAIT`) set
 * for the duration, removed automatically by the throw's completion
 * callback. That trait maps to the FLOATING movement_type bit, which is
 * exactly what lava (code/game/turfs/open/lava.dm) and chasms
 * (code/datums/components/chasm.dm) check to skip their hazard logic,
 * so the dash clears lava, chasms, and water without any hazard-specific
 * code of its own. `jumpdistance = 5` matches jump boots' own "-1 to see
 * the actual distance" quirk, landing on exactly four tiles crossed, and
 * `recharging_rate` is the same manual world.time cooldown jump boots use
 * (~8s here instead of jump boots' 6s).
 *
 * Action wiring follows the same idiom as jump boots: a
 * `/datum/action/item_action` subtype purely for the button's name/icon,
 * whose base Trigger() calls `target.ui_action_click(owner, src)`
 * (code/datums/actions/item_action.dm), so the actual dash logic lives
 * in `ui_action_click()` on the item itself, exactly like
 * `/obj/item/clothing/shoes/bhop/ui_action_click()`. The button reuses
 * the existing "jetboot" icon state from actions_items.dmi (the same one
 * jump boots' own action uses) rather than inventing a new one.
 *
 * Sprite/slot deviation: worn at the belt (ITEM_SLOT_BELT), not the feet
 * slot, so it never competes with the wearer's actual boots, matches
 * the doc's own "belt/legs item" framing.
 *
 * PLAYTEST CHANGE (2026-07-28): "should make you move faster too". The rig
 * now grants /datum/movespeed_modifier/longwalk_rig while it's worn on the
 * belt: -0.25 multiplicative_slowdown, in the same band as the heretic shadow
 * cloak (-0.25) and berserk (-0.2), which is a clear step up in pace without
 * touching sprint-tier numbers like the sphere transformation (-0.5). It goes
 * through the movespeed modifier system rather than any slowdown var, so it
 * stacks and unstacks correctly with armour, gravity and turf slowdown. The
 * dash cooldown also moved onto the COOLDOWN_* macros so the "still resetting"
 * message can print the real time left.
 */
/datum/movespeed_modifier/longwalk_rig
	multiplicative_slowdown = -0.25

/obj/item/longwalk_rig
	name = "longwalk rig"
	desc = "A leg harness of pistons and cable, patched up on the trail. Worn on the belt it keeps you moving noticeably faster, and it can throw you four tiles forward straight over lava and chasms."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "longwalk_rig"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "longwalk_rig"
	inhand_icon_state = null
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_SMALL
	actions_types = list(/datum/action/item_action/longwalk_dash)
	/// Tiles thrown: matches jump boots' -1 quirk: 5 = 4 tiles crossed
	var/jumpdistance = 5
	var/jumpspeed = 3
	/// Wait between dashes
	var/dash_cooldown_length = 8 SECONDS
	COOLDOWN_DECLARE(dash_cooldown)

/datum/action/item_action/longwalk_dash
	name = "Longwalk Dash"
	desc = "Surge four tiles forward, clearing whatever's underfoot."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "jetboot"

/obj/item/longwalk_rig/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/longwalk_rig/Destroy()
	// destroyed while still strapped on: hand the speed back before we go
	var/mob/wearer = loc
	if(ismob(wearer))
		wearer.remove_movespeed_modifier(/datum/movespeed_modifier/longwalk_rig)
	return ..()

/obj/item/longwalk_rig/examine(mob/user)
	. = ..()
	. += span_notice("Worn on the belt, the pistons take some of your weight - you move noticeably faster with it on.")
	. += span_notice("Its dash throws you four tiles forward over anything underfoot: lava, chasms, open water. [DisplayTimeText(dash_cooldown_length)] between dashes.")
	if(!COOLDOWN_FINISHED(src, dash_cooldown))
		. += span_warning("The pistons are still resetting: [DisplayTimeText(COOLDOWN_TIMELEFT(src, dash_cooldown))] left.")

/obj/item/longwalk_rig/equipped(mob/user, slot, initial)
	. = ..()
	if(slot & slot_flags)
		user.add_movespeed_modifier(/datum/movespeed_modifier/longwalk_rig)
	else
		// picked up rather than strapped on, no speed from carrying it
		user.remove_movespeed_modifier(/datum/movespeed_modifier/longwalk_rig)

/obj/item/longwalk_rig/dropped(mob/user, silent)
	. = ..()
	user?.remove_movespeed_modifier(/datum/movespeed_modifier/longwalk_rig)

/obj/item/longwalk_rig/ui_action_click(mob/user, action)
	if(!isliving(user))
		return
	if(!COOLDOWN_FINISHED(src, dash_cooldown))
		to_chat(user, span_warning("The rig's pistons are still resetting - [DisplayTimeText(COOLDOWN_TIMELEFT(src, dash_cooldown))] left."))
		return

	var/atom/dash_target = get_edge_target_turf(user, user.dir)

	ADD_TRAIT(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)
	if(user.throw_at(dash_target, jumpdistance, jumpspeed, spin = FALSE, diagonals_first = TRUE, callback = TRAIT_CALLBACK_REMOVE(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)))
		playsound(src, 'sound/effects/stealthoff.ogg', 50, TRUE, TRUE)
		user.visible_message(span_warning("[user] surges forward on [user.p_their()] longwalk rig!"), span_notice("You dash forward, feet never touching down."))
		COOLDOWN_START(src, dash_cooldown, dash_cooldown_length)
	else
		REMOVE_TRAIT(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)
		to_chat(user, span_warning("Something blocks the rig's dash!"))
