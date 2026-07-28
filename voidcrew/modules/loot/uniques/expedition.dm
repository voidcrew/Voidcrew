/**
 * # EXPEDITION uniques — prospector's claim chest
 *
 * Six unique prizes for the expedition rare-loot table
 * (voidcrew/modules/loot/zone_loot.dm, `/obj/structure/closet/crate/zone_loot/expedition/rare`).
 * Tiers: green = "nice find," yellow = build-around, red = round-changing.
 * None of this is antag gear — these are found-in-the-world prizes for
 * anyone working a planet.
 *
 * Every item here carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so
 * duplicators (Helios pattern stamp, any future replicator) refuse to copy
 * it — see that define's doc comment.
 *
 * Not wired into any loot table yet — that's the coordinating pass, not
 * this file. This file only defines the six typepaths.
 */

// =========================================================================
// GREEN
// =========================================================================

/**
 * Old hand's compass — GREEN. A prospector's compass, glass sanded to
 * frost.
 *
 * Subtypes /obj/item/pinpointer (code/game/objects/items/pinpointer.dm)
 * for its full sprite kit and "point toward a tracked atom" scaffolding
 * (get_direction_icon(), the pinon* icon states, toggle_on()/process()).
 * The tracked atom is the nearest space ruin signal that hasn't been
 * visited yet (GLOB.space_ruin_signals, a global per-ruin flag set the
 * moment any ship docks there — see
 * voidcrew/modules/overmap/code/modules/overmap/space_ruin.dm), measured
 * from the wearer's ship's overmap position
 * (/proc/get_ship_from_atom(), ship.dm) — falling back to whatever
 * overmap object currently contains the wearer
 * (SSovermap_zones.get_overmap_object_for_turf()) when they're on foot
 * with no ship (e.g. already boarded a ruin).
 *
 * The base pinpointer's overlay logic compares z-levels between "here"
 * (the item's own turf) and "there" (the target's turf) — which would
 * always fail here, since the item sits on whatever z the wearer's ship
 * interior is on while the ruin sits on the single overmap z-level.
 * update_overlays() is overridden to instead measure between the two
 * OVERMAP-z reference turfs directly, reusing the inherited
 * get_direction_icon() proc unchanged once both are confirmed to be on
 * that shared z.
 *
 * Deviations from the doc:
 * - "Visited" reuses the ruin's own global `visited` flag (set once any
 *   ship docks there) rather than per-player tracking — there is no
 *   existing per-player "have I been here" bookkeeping anywhere in this
 *   codebase, and the task brief calls a simple substitute acceptable.
 * - "Point of interest" is scoped to ruins only (space_ruin signals).
 *   Trader/player outposts don't carry a `visited` var in this codebase,
 *   so folding them in would mean inventing new bookkeeping.
 * - When the wearer can't be resolved to *any* overmap position (holding
 *   it on CentCom, say), it shows the normal "no signal" pinpointer icon
 *   rather than pointing north — north is reserved specifically for
 *   "every reachable ruin has been visited," matching the doc's "when
 *   you've been everywhere" framing.
 */
/obj/item/pinpointer/old_hands_compass
	name = "old hand's compass"
	desc = "A prospector's compass with the glass sanded to frost. The needle points toward the nearest ruin nobody's set foot in yet."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "brass_compass"
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 3, /datum/material/glass = SMALL_MATERIAL_AMOUNT * 2)
	/// Cached overmap turf of whatever's carrying the compass, set by scan_for_target()
	var/turf/cached_reference_turf
	/// Cached overmap turf of the target ruin, set by scan_for_target()
	var/turf/cached_target_turf
	/// TRUE once every reachable ruin signal has been visited
	var/found_everything = FALSE
	/// Throttle: the expensive GLOB.space_ruin_signals scan only runs this often
	var/next_scan_time = 0

/obj/item/pinpointer/old_hands_compass/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/pinpointer/old_hands_compass/attack_self(mob/living/user)
	toggle_on()
	user.visible_message(span_notice("[user] [active ? "" : "de"]activates [user.p_their()] compass."), span_notice("You [active ? "" : "de"]activate your compass."))

/obj/item/pinpointer/old_hands_compass/scan_for_target()
	if(world.time < next_scan_time)
		return
	next_scan_time = world.time + 3 SECONDS

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
	// The parent's overlay logic compares the item's z to the target's z —
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
 * Claim stake — GREEN. A steel stake with a brass claim-plate.
 *
 * Use in hand to drive it into solid ground: while deployed, wild fauna
 * within a 5-tile claim radius get the local planet factions
 * (FACTION_WASTELAND/FACTION_BEACH/FACTION_CRYSTAL,
 * voidcrew/_DEFINES/mobfactions.dm) temporarily added to their own faction
 * list, which is exactly the check `basic_targeting_strategy/can_attack()`
 * already uses to skip attacking friendlies (non-exact faction overlap —
 * code/datums/ai/basic_mobs/targeting_strategies/basic_targeting_strategy.dm)
 * — no new safe-zone infrastructure, just the same lever the codebase uses
 * everywhere else to make a faction-driven mob leave something alone. It
 * also carries a GPS beacon (/datum/component/gps) tagged with the
 * driving prospector's name.
 *
 * "One claim per stake": a stake can only be deployed in one place at a
 * time (it's a single physical object), and pulling it up clears the
 * entire claim in one shot — there's no lingering aura after retrieval.
 *
 * Deviation: fauna already mid-retaliation bypass the faction check by
 * design — `target_retaliate` sets BB_TEMPORARILY_IGNORE_FACTION when
 * picking a target off its "recently attacked me" list
 * (code/datums/ai/basic_mobs/basic_subtrees/target_retaliate.dm) — so the
 * claim keeps fauna from *starting* a fight inside the radius, it doesn't
 * pull them off one already underway. Stripping that list would mean
 * touching shared AI code outside this file's scope.
 */
/obj/item/claim_stake
	name = "claim stake"
	desc = "A steel stake with a brass claim-plate. Drive it into the ground and local wildlife won't start fights nearby."
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

/obj/item/claim_stake/examine(mob/user)
	. = ..()
	if(deployed)
		. += span_notice("It's driven into the ground, claim radius [claim_radius] tiles, staked under [owner_name].")
	else
		. += span_notice("Use in hand to drive it into solid ground.")

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
		return
	var/list/currently_in_range = list()
	for(var/mob/living/nearby_mob in range(claim_radius, src))
		if(nearby_mob.stat == DEAD)
			continue
		currently_in_range += nearby_mob
		if(!(nearby_mob in protected_mobs))
			protect_mob(nearby_mob)
	for(var/mob/living/protected_mob as anything in protected_mobs.Copy())
		if(!(protected_mob in currently_in_range))
			release_mob(protected_mob)

/obj/item/claim_stake/proc/protect_mob(mob/living/target_mob)
	var/list/added = list()
	for(var/faction_string in claimed_factions)
		if(!(faction_string in target_mob.faction))
			target_mob.faction += faction_string
			added += faction_string
	protected_mobs[target_mob] = added

/obj/item/claim_stake/proc/release_mob(mob/living/target_mob)
	var/list/added = protected_mobs[target_mob]
	if(added)
		for(var/faction_string in added)
			target_mob.faction -= faction_string
	protected_mobs -= target_mob

// =========================================================================
// YELLOW
// =========================================================================

/**
 * "Second Season" — YELLOW. A duster gone the color of every planet it's
 * been on.
 *
 * Subtypes /obj/item/clothing/suit/hooded/explorer
 * (code/modules/mining/equipment/explorer_gear.dm) for its sprite, hood,
 * and armor — already reused as loot-table content in this same crate's
 * green table (voidcrew/modules/loot/zone_loot.dm), so it stays visually
 * consistent with "expedition gear."
 *
 * Weather immunity uses the idiomatic path: `clothing_traits`
 * (auto-applied/removed by the base equipped()/dropped() in
 * code/modules/clothing/clothing.dm) covers every planet-relevant weather
 * immunity trait that exists in declarations.dm, skipping the blanket
 * TRAIT_WEATHER_IMMUNE (that also cancels effects this item was never
 * meant to touch, like void storms).
 *
 * Rough-terrain immunity can't reuse TRAIT_IGNORESLOWDOWN — verified that
 * trait strips *every* non-IGNORE_NOSLOW movespeed modifier, including
 * armor/equipment slowdown, which this item must leave alone. Instead it
 * hooks COMSIG_MOVABLE_MOVED on the wearer and clears exactly the
 * `/datum/movespeed_modifier/turf_slowdown` entry after every step — the
 * same modifier `update_turf_movespeed()` re-applies on each move
 * (code/modules/mob/living/living_movement.dm) — via the public
 * `/mob/proc/remove_movespeed_modifier()`. That's surgical: it never
 * touches equipment_speedmod or anything else.
 *
 * Deviation: this fork's planet weather roster
 * (voidcrew/modules/overmap/code/modules/overmap/behaviour/planets.dm) is
 * ash_storm (lava) / snow_storm (ice) / sand_storm (wasteland) /
 * rain_storm (beach, jungle) — there is no "rad squall" planet weather in
 * this codebase to be immune to (rad_storm exists only as a station-level
 * random event). Rad-storm immunity is granted anyway since the trait is
 * real and free; it just never fires on a planet in this fork.
 */
/obj/item/clothing/suit/hooded/explorer/second_season_duster
	name = "\"Second Season\""
	desc = "A duster gone the color of every planet it's been on. Storms don't touch you in it, and rough ground doesn't slow you down."
	clothing_traits = list(TRAIT_ASHSTORM_IMMUNE, TRAIT_SNOWSTORM_IMMUNE, TRAIT_SANDSTORM_IMMUNE, TRAIT_RAINSTORM_IMMUNE, TRAIT_RADSTORM_IMMUNE)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/equipped(mob/user, slot, initial)
	. = ..()
	if(slot_flags & slot)
		RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(on_wearer_moved))
		user.remove_movespeed_modifier(/datum/movespeed_modifier/turf_slowdown)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/dropped(mob/user, silent)
	. = ..()
	UnregisterSignal(user, COMSIG_MOVABLE_MOVED)

/obj/item/clothing/suit/hooded/explorer/second_season_duster/proc/on_wearer_moved(mob/source, atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	SIGNAL_HANDLER
	source.remove_movespeed_modifier(/datum/movespeed_modifier/turf_slowdown)

/**
 * Divining pick — YELLOW. A pickaxe with a forked tip and opinions.
 *
 * Directly subtypes /obj/item/pickaxe (code/modules/mining/equipment/
 * mining_tools.dm) for its sprite and mining behavior — no changes to how
 * it actually breaks rock.
 *
 * "Hums when you're warm": examine() reads nearby /turf/closed/mineral
 * tiles' `mineralAmt` (the vanilla richness/yield var) and reports a hum
 * intensity plus a compass direction toward the richest one.
 *
 * "Cracks the seam wider": while held, it listens on its wielder for
 * COMSIG_MOB_MINED — the signal every successful `gets_drilled()` call
 * sends to the mining mob regardless of tool
 * (code/game/turfs/closed/minerals.dm) — and, on that signal, rolls a
 * one-hop cascade into the mined turf's immediate neighbors with a
 * decaying per-tile chance, the same orange(1, turf) neighbor-walk idiom
 * the resonator's burst() uses
 * (code/modules/mining/equipment/resonator.dm). This is done via signal
 * registration on the *wielder*, not by overriding
 * `/turf/closed/mineral/gets_drilled()` itself — that proc lives in
 * upstream code this file must not edit, and the signal hook reaches the
 * exact same event without touching it.
 */
/obj/item/pickaxe/divining
	name = "divining pick"
	desc = "A pickaxe with a forked tip that hums when there's good rock nearby. Breaking one seam tends to crack open the ones next to it."
	toolspeed = 0.8
	force = 16
	/// Chance the first adjacent mineral turf cascades in
	var/cascade_base_chance = 55
	/// How much the chance drops for each further neighbor checked this trigger
	var/cascade_decay = 15

/obj/item/pickaxe/divining/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/pickaxe/divining/equipped(mob/user, slot, initial)
	. = ..()
	// only while actually wielded — belted/backpacked shouldn't cascade off a different tool's mining
	if(slot & ITEM_SLOT_HANDS)
		RegisterSignal(user, COMSIG_MOB_MINED, PROC_REF(on_wielder_mined))

/obj/item/pickaxe/divining/dropped(mob/user, silent)
	. = ..()
	UnregisterSignal(user, COMSIG_MOB_MINED)

/obj/item/pickaxe/divining/proc/on_wielder_mined(datum/source, turf/closed/mineral/rock, exp_multiplier)
	SIGNAL_HANDLER
	if(!istype(rock))
		return
	var/mob/user = source
	var/chance = cascade_base_chance
	var/stagger = 0
	for(var/turf/closed/mineral/neighbor in orange(1, rock))
		if(!prob(chance))
			continue
		chance = max(chance - cascade_decay, 0)
		stagger += 3
		addtimer(CALLBACK(src, PROC_REF(cascade_drill), neighbor, user), stagger)

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
		if(nearby_rock.mineralAmt > best_amount)
			best_amount = nearby_rock.mineralAmt
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
 * Deepwell — RED. A core sampler crated in claim-office gray, deploying
 * into an autonomous mining machine.
 *
 * No autonomous/deployable mining machine exists anywhere in this
 * codebase (verified) — this is new machinery, but every mechanic it
 * uses is a direct reuse of an existing pattern:
 * - Flood-fill: a breadth-first queue seeded from orange(1, turf) and
 *   re-seeded from each drilled tile's own neighbors, the same
 *   neighbor-walk idiom as the resonator's burst()
 *   (code/modules/mining/equipment/resonator.dm).
 * - Drilling: calls the turf's own `gets_drilled()` — the universal
 *   mining entry point ~30 other sources already call
 *   (code/game/turfs/closed/minerals.dm).
 * - Auto-smelting: converts the dropped ore stack to sheets via the ore
 *   stack's own `refined_type` var — the same 1:1 lookup
 *   `/obj/item/stack/ore/welder_act()` uses to self-refine
 *   (code/modules/mining/ores_coins.dm) — rather than wiring up a full
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
 * anywhere in this codebase (verified — nothing hooks mob hearing to AI
 * targeting; `/datum/element/hostile_machine`, the closest purpose-built
 * "make wildlife attack a fixed machine" lever, requires editing the
 * shared basic_targeting_strategy `can_attack()` proc to special-case a
 * new object type, which is out of scope for a single-new-file change).
 * The closest feasible substitute, and what's implemented here, is a
 * direct, repeating `ai_controller.set_movement_target()` ping on nearby
 * fauna — a pull, not a summon or a true noise mechanic. A fauna's own
 * planning tick can override it moments later (chasing something else,
 * fleeing, etc.), so the ping repeats periodically rather than being
 * fire-and-forget.
 */
/obj/item/deepwell_sampler
	name = "core sampler"
	desc = "A core sampler crated in claim-office gray. Deploy it on a mineral seam and it works the whole vein by itself."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "deepwell_item"
	w_class = WEIGHT_CLASS_BULKY
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 3, /datum/material/glass = SHEET_MATERIAL_AMOUNT)

/obj/item/deepwell_sampler/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/deepwell_sampler/attack_self(mob/user)
	var/turf/target_turf = get_turf(user)
	var/list/mineral_neighbors = target_turf ? get_adjacent_mineral_turfs(target_turf) : list()
	if(!target_turf || (!length(mineral_neighbors) && !ismineralturf(target_turf)))
		to_chat(user, span_warning("[src] needs to go down on or right beside a mineral seam."))
		return
	to_chat(user, span_notice("You start bolting [src] down..."))
	if(!do_after(user, 3 SECONDS, target = src))
		return
	if(!isturf(user.loc) || QDELETED(src))
		return
	user.visible_message(span_notice("[user] deploys [src]."), span_notice("You deploy [src]. Somebody should stay with it."))
	new /obj/machinery/deepwell_sampler(get_turf(user))
	qdel(src)

/obj/item/deepwell_sampler/proc/get_adjacent_mineral_turfs(turf/center)
	. = list()
	for(var/turf/closed/mineral/neighbor in orange(1, center))
		. += neighbor

/obj/machinery/deepwell_sampler
	name = "deepwell sampler"
	desc = "A core sampler, bolted down and drilling the vein on its own. It's extremely loud, and the wildlife comes to look."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "deepwell"
	density = TRUE
	anchored = TRUE
	use_power = NO_POWER_USE
	/// Seconds between drill pulses — plain seconds, matching process()'s
	/// seconds_per_tick accumulator (a `X SECONDS` value here would be
	/// deciseconds and slow the drill down tenfold)
	var/pulse_interval = 4
	var/pulse_accumulator = 0
	/// Tile radius the fauna-attraction ping reaches
	var/attraction_range = 12
	/// Pulses between fauna-attraction pings
	var/pulses_since_ping = 0
	/// Turfs still queued to drill, breadth-first from the deploy point
	var/list/turf/closed/mineral/dig_queue = list()
	/// Turfs already queued or drilled, so the flood-fill doesn't loop
	var/list/turf/seen_turfs = list()

/obj/machinery/deepwell_sampler/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	seed_queue()

/obj/machinery/deepwell_sampler/Destroy()
	dig_queue = null
	seen_turfs = null
	return ..()

/obj/machinery/deepwell_sampler/proc/seed_queue()
	var/turf/here = get_turf(src)
	seen_turfs[here] = TRUE
	for(var/turf/closed/mineral/adjacent in orange(1, here))
		if(seen_turfs[adjacent])
			continue
		seen_turfs[adjacent] = TRUE
		dig_queue += adjacent

/obj/machinery/deepwell_sampler/process(seconds_per_tick)
	pulse_accumulator += seconds_per_tick
	if(pulse_accumulator < pulse_interval)
		return
	pulse_accumulator = 0
	do_pulse()

/obj/machinery/deepwell_sampler/proc/do_pulse()
	playsound(src, 'sound/effects/break_stone.ogg', 100, TRUE, 20)
	pulses_since_ping++
	if(pulses_since_ping >= 3)
		pulses_since_ping = 0
		attract_fauna()
	if(!length(dig_queue))
		seed_queue()
		if(!length(dig_queue))
			return
	var/turf/closed/mineral/vein_turf = dig_queue[1]
	dig_queue.Cut(1, 2)
	if(!ismineralturf(vein_turf))
		return
	for(var/turf/closed/mineral/neighbor in orange(1, vein_turf))
		if(seen_turfs[neighbor])
			continue
		seen_turfs[neighbor] = TRUE
		dig_queue += neighbor
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
	qdel(raw_ore)

/obj/machinery/deepwell_sampler/proc/attract_fauna()
	for(var/mob/living/fauna in orange(attraction_range, src))
		if(fauna.stat == DEAD || !fauna.ai_controller)
			continue
		fauna.ai_controller.set_movement_target(type, src, /datum/ai_movement/basic_avoidance)

/obj/machinery/deepwell_sampler/wrench_act(mob/living/user, obj/item/tool)
	tool.play_tool_sound(src)
	to_chat(user, span_notice("You unbolt [src]."))
	new /obj/item/deepwell_sampler(get_turf(src))
	qdel(src)
	return ITEM_INTERACT_SUCCESS

/**
 * Longwalk rig — RED. A leg harness of pistons and cable, trail-patched.
 *
 * Grants a dash action modeled directly on jump boots' dash
 * (code/modules/clothing/shoes/jumpboots.dm): `throw_at()` covering the
 * distance with `TRAIT_MOVE_FLOATING` (source-keyed `LEAPING_TRAIT`) set
 * for the duration, removed automatically by the throw's completion
 * callback. That trait maps to the FLOATING movement_type bit, which is
 * exactly what lava (code/game/turfs/open/lava.dm) and chasms
 * (code/datums/components/chasm.dm) check to skip their hazard logic —
 * so the dash clears lava, chasms, and water without any hazard-specific
 * code of its own. `jumpdistance = 5` matches jump boots' own "-1 to see
 * the actual distance" quirk, landing on exactly four tiles crossed, and
 * `recharging_rate` is the same manual world.time cooldown jump boots use
 * (~8s here instead of jump boots' 6s).
 *
 * Action wiring follows the same idiom as jump boots: a
 * `/datum/action/item_action` subtype purely for the button's name/icon,
 * whose base Trigger() calls `target.ui_action_click(owner, src)`
 * (code/datums/actions/item_action.dm) — so the actual dash logic lives
 * in `ui_action_click()` on the item itself, exactly like
 * `/obj/item/clothing/shoes/bhop/ui_action_click()`. The button reuses
 * the existing "jetboot" icon state from actions_items.dmi (the same one
 * jump boots' own action uses) rather than inventing a new one.
 *
 * Sprite/slot deviation: worn at the belt (ITEM_SLOT_BELT), not the feet
 * slot, so it never competes with the wearer's actual boots — matches
 * the doc's own "belt/legs item" framing. Since no distinct "leg rig"
 * sprite exists, it copies jump boots' icon fields verbatim (per the
 * sprite-reuse rule for fresh root types); this means it'll render as a
 * boot icon while belted/in-hand, which may look odd — flagged for
 * review.
 */
/obj/item/longwalk_rig
	name = "longwalk rig"
	desc = "A leg harness of pistons and cable, patched up on the trail. Dashes you four tiles forward, straight over lava and chasms."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "longwalk_rig"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "longwalk_rig"
	inhand_icon_state = null
	slot_flags = ITEM_SLOT_BELT
	w_class = WEIGHT_CLASS_SMALL
	actions_types = list(/datum/action/item_action/longwalk_dash)
	/// Tiles thrown — matches jump boots' -1 quirk: 5 = 4 tiles crossed
	var/jumpdistance = 5
	var/jumpspeed = 3
	/// Cooldown between dashes
	var/recharging_rate = 80
	var/recharging_time = 0

/datum/action/item_action/longwalk_dash
	name = "Longwalk Dash"
	desc = "Surge four tiles forward, clearing whatever's underfoot."
	button_icon = 'icons/mob/actions/actions_items.dmi'
	button_icon_state = "jetboot"

/obj/item/longwalk_rig/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/longwalk_rig/ui_action_click(mob/user, action)
	if(!isliving(user))
		return
	if(recharging_time > world.time)
		to_chat(user, span_warning("The rig's pistons are still resetting."))
		return

	var/atom/dash_target = get_edge_target_turf(user, user.dir)

	ADD_TRAIT(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)
	if(user.throw_at(dash_target, jumpdistance, jumpspeed, spin = FALSE, diagonals_first = TRUE, callback = TRAIT_CALLBACK_REMOVE(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)))
		playsound(src, 'sound/effects/stealthoff.ogg', 50, TRUE, TRUE)
		user.visible_message(span_warning("[user] surges forward on [user.p_their()] longwalk rig!"), span_notice("You dash forward, feet never touching down."))
		recharging_time = world.time + recharging_rate
	else
		REMOVE_TRAIT(user, TRAIT_MOVE_FLOATING, LEAPING_TRAIT)
		to_chat(user, span_warning("Something blocks the rig's dash!"))
