/**
 * # Research uniques — priority specimen cache
 *
 * Six unique prizes for the RESEARCH loot theme (see the "priority specimen
 * cache" rare_loot tables in voidcrew/modules/loot/zone_loot.dm — this file
 * does not touch those tables; slotting these in is a separate pass).
 * Design source: obsidian vault `Rare-loot-uniques.md`, "RESEARCH — priority
 * specimen cache" section.
 *
 * Every item here is a one-of-a-kind mechanic, not a stat stick, and every
 * one carries TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so future
 * duplicators (Helios pattern stamp, etc.) refuse to copy them.
 *
 * Tiers, per the design doc:
 * - GREEN ("nice find"): Calibration prism, Annex notebook vol. IX
 * - YELLOW ("build-around"): Entangled pair, Displacer fork
 * - RED ("round-changing"): Chronal splint, Eventide courier coat
 *
 * Typepath note: several of these subtype an existing item purely to inherit
 * its sprite (and, in the calibration prism's case, its reagent-scanner
 * trait) rather than nesting under the doc's suggested flat path. See the
 * per-item comments for the donor and the reasoning.
 */

// =========================================================================
// GREEN — Calibration prism
// =========================================================================

/**
 * Calibration prism — subtypes science goggles purely for the sprite AND
 * because /obj/item/clothing/glasses/science already carries
 * TRAIT_REAGENT_SCANNER (see code/modules/clothing/glasses/_glasses.dm),
 * which is the actual mechanism reagent containers use to decide whether an
 * examiner sees exact contents/volumes (code/modules/mob/mob_helpers.dm).
 * That means the doc's first bullet ("examine any reagent container to see
 * its exact contents") is inherited for free — no new examine hook needed.
 *
 * The second bullet (shimmer on cloaked/invisible/phased things) is
 * implemented as a straight see_invisible bump. The doc also asks for
 * "you can't target them" — that would need touching the click/targeting
 * pipeline, which is out of scope for a single new file and risky to get
 * right blind, so it's deliberately NOT implemented. Flagged in the report.
 *
 * Typepath nests under .../glasses/science/calibration_prism (not the doc's
 * flat .../glasses/calibration_prism) so it can subtype science goggles
 * directly instead of duplicating its vars.
 */
/obj/item/clothing/glasses/science/calibration_prism
	name = "calibration prism"
	desc = "Lab glasses with a wedge of doped crystal where the left lens should be. Property of E.E.A. — return if found, please."
	// invis_view gets min()'d against the wearer's base see_invisible in
	// carbon/update_sight() — it can only ever REDUCE what you see.
	// invis_override is the actual "see more" lever, so that's what we set.
	// Observer tier means ghosts shimmer at the edge of the lens too; the
	// E.E.A. would call that a feature.
	invis_override = SEE_INVISIBLE_OBSERVER

/obj/item/clothing/glasses/science/calibration_prism/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// =========================================================================
// GREEN — Annex notebook, vol. IX
// =========================================================================

/**
 * Annex notebook, vol. IX — subtypes a plain book for the sprite (no
 * "notebook" sprite exists in this codebase; /obj/item/book's library icon
 * is the closest reasonable stand-in and the type is safe to subtype, it's
 * spawned standalone elsewhere).
 *
 * Use on a machine: prints its parts manifest (machinery/display_parts(),
 * the same readout the RPED uses — code/game/machinery/_machinery.dm) and
 * upgrades one random stock part already inside by one tier, mirroring how
 * the RPED (code/modules/research/part_replacer.dm) exchanges parts, but
 * self-contained (no RPED storage needed). Three uses, then it's a diary.
 *
 * Only handles legacy /obj/item/stock_parts parts (capacitor, scanning
 * module, servo, micro laser, matter bin) — modern /datum/stock_part
 * machines are silently skipped by the typed for-loop below, same as the
 * doc's simplification allowance suggests for anything not cleanly
 * generalizable.
 */
/obj/item/book/annex_notebook
	name = "Annex notebook, vol. IX"
	desc = "A lab notebook in three different handwritings. The third one was in a hurry."
	/// Legible pages left. Each successful use on a machine burns one.
	var/pages_left = 3

/obj/item/book/annex_notebook/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/book/annex_notebook/examine(mob/user)
	. = ..()
	if(pages_left > 0)
		. += span_notice("[pages_left] legible page[pages_left == 1 ? "" : "s"] left.")
	else
		. += span_notice("The legible pages are gone. It's just a diary now.")

/// Type -> next-tier type for the stock part families that actually have tiers in this codebase.
/obj/item/book/annex_notebook/proc/get_upgrade_map()
	var/static/list/upgrade_map
	if(!upgrade_map)
		upgrade_map = list(
			/obj/item/stock_parts/capacitor = /obj/item/stock_parts/capacitor/adv,
			/obj/item/stock_parts/capacitor/adv = /obj/item/stock_parts/capacitor/super,
			/obj/item/stock_parts/capacitor/super = /obj/item/stock_parts/capacitor/quadratic,
			/obj/item/stock_parts/scanning_module = /obj/item/stock_parts/scanning_module/adv,
			/obj/item/stock_parts/scanning_module/adv = /obj/item/stock_parts/scanning_module/phasic,
			/obj/item/stock_parts/scanning_module/phasic = /obj/item/stock_parts/scanning_module/triphasic,
			/obj/item/stock_parts/servo = /obj/item/stock_parts/servo/nano,
			/obj/item/stock_parts/servo/nano = /obj/item/stock_parts/servo/pico,
			/obj/item/stock_parts/servo/pico = /obj/item/stock_parts/servo/femto,
			/obj/item/stock_parts/micro_laser = /obj/item/stock_parts/micro_laser/high,
			/obj/item/stock_parts/micro_laser/high = /obj/item/stock_parts/micro_laser/ultra,
			/obj/item/stock_parts/micro_laser/ultra = /obj/item/stock_parts/micro_laser/quadultra,
			/obj/item/stock_parts/matter_bin = /obj/item/stock_parts/matter_bin/adv,
			/obj/item/stock_parts/matter_bin/adv = /obj/item/stock_parts/matter_bin/super,
			/obj/item/stock_parts/matter_bin/super = /obj/item/stock_parts/matter_bin/bluespace,
		)
	return upgrade_map

/obj/item/book/annex_notebook/interact_with_atom(obj/attacked_object, mob/living/user, list/modifiers)
	if(user.combat_mode)
		return ITEM_INTERACT_SKIP_TO_ATTACK
	if(!ismachinery(attacked_object))
		return NONE

	var/obj/machinery/target_machine = attacked_object
	if(!LAZYLEN(target_machine.component_parts))
		return NONE

	if(pages_left <= 0)
		to_chat(user, span_warning("[src] has nothing left to write on this. It's just a diary now."))
		return ITEM_INTERACT_BLOCKING

	to_chat(user, target_machine.display_parts(user))

	// Machines hold a mix of legacy /obj/item/stock_parts and modern
	// /datum/stock_part singletons — most tiered machines use the datums
	// now, so both families are upgrade candidates.
	var/list/upgrade_map = get_upgrade_map()
	var/list/candidates = list()
	for(var/entry in target_machine.component_parts)
		if(istype(entry, /obj/item/stock_parts))
			var/obj/item/stock_parts/part = entry
			if(upgrade_map[part.type])
				candidates += part
		else if(istype(entry, /datum/stock_part))
			if(get_next_tier_datum(entry))
				candidates += entry

	if(!length(candidates))
		// No page burned on a machine the notes can't improve
		to_chat(user, span_notice("The notes have nothing left to suggest for this unit."))
		return ITEM_INTERACT_SUCCESS

	pages_left--

	var/chosen = pick(candidates)
	if(istype(chosen, /datum/stock_part))
		var/datum/stock_part/old_part = chosen
		var/datum/stock_part/new_part = get_next_tier_datum(old_part)
		target_machine.component_parts -= old_part
		target_machine.component_parts += new_part
		target_machine.RefreshParts()
		to_chat(user, span_notice("A margin note describes a modification the manufacturer never approved — [new_part.name()] clicks into place."))
	else
		var/obj/item/stock_parts/old_item = chosen
		var/new_type = upgrade_map[old_item.type]
		target_machine.component_parts -= old_item
		qdel(old_item)
		var/obj/item/stock_parts/upgraded = new new_type()
		upgraded.forceMove(target_machine)
		target_machine.component_parts += upgraded
		target_machine.RefreshParts()
		to_chat(user, span_notice("A margin note describes a modification the manufacturer never approved — [upgraded.name] clicks into place."))

	return ITEM_INTERACT_SUCCESS

/// Finds the /datum/stock_part singleton one tier above the given one (same physical base type), or null.
/obj/item/book/annex_notebook/proc/get_next_tier_datum(datum/stock_part/part)
	for(var/datum_type in GLOB.stock_part_datums)
		var/datum/stock_part/candidate = GLOB.stock_part_datums[datum_type]
		if(candidate.physical_object_base_type == part.physical_object_base_type && candidate.tier == part.tier + 1)
			return candidate
	return null

// =========================================================================
// YELLOW — Entangled pair
// =========================================================================

/**
 * Entangled pair — subtypes a plain beaker for the sprite. Spawns linked:
 * the first instance's Initialize() spawns its twin alongside it and links
 * both weakrefs in one pass (an explicit `..(mapload)` keeps the twin's
 * partner arg from leaking further up the beaker/reagent_containers
 * Initialize chain).
 *
 * Mechanic: hooks the same on_reagent_change() signal handler every
 * reagent_containers item already uses for its fill-icon update
 * (code/modules/reagents/reagent_containers.dm, wired to
 * COMSIG_REAGENTS_HOLDER_UPDATED in create_reagents()). Whenever this
 * beaker's contents change and it isn't already relaying, it moves its
 * entire volume to the twin via reagents.trans_to() (default move
 * semantics, not copy) — "poured into one, exists in the other instead."
 * A `relaying` guard on both beakers (set before the transfer, cleared
 * after) stops the reentrant COMSIG_REAGENTS_HOLDER_UPDATED firing on
 * either side from bouncing the volume back and forth forever.
 */
/obj/item/reagent_containers/cup/beaker/entangled
	name = "entangled beaker"
	desc = "Two beakers, serial numbers identical. The manual says not to separate them. There is no manual."
	/// Weakref to this beaker's paired twin.
	var/datum/weakref/linked_twin
	/// Reentrancy guard so a relay doesn't relay itself back and forth forever.
	var/relaying = FALSE

/obj/item/reagent_containers/cup/beaker/entangled/Initialize(mapload, obj/item/reagent_containers/cup/beaker/entangled/partner)
	// Explicit arg forwarding: only mapload goes to the beaker/reagent_containers
	// chain above us, so `partner` never leaks into an unrelated formal param
	// further up (reagent_containers/Initialize takes a numeric `vol` there).
	. = ..(mapload)
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	if(partner)
		linked_twin = WEAKREF(partner)
		partner.linked_twin = WEAKREF(src)
	else
		// First of the pair: spawn the second beaker alongside us and let
		// its own Initialize() (the `if(partner)` branch above) link both
		// directions in one shot.
		new type(loc, src)

/obj/item/reagent_containers/cup/beaker/entangled/on_reagent_change(datum/reagents/holder, ...)
	. = ..()
	if(relaying || !linked_twin)
		return
	if(!reagents || !reagents.total_volume)
		return
	var/obj/item/reagent_containers/cup/beaker/entangled/twin = linked_twin.resolve()
	if(!twin || QDELETED(twin))
		return
	relaying = TRUE
	twin.relaying = TRUE
	reagents.trans_to(twin, reagents.total_volume)
	twin.relaying = FALSE
	relaying = FALSE

// =========================================================================
// YELLOW — Displacer fork
// =========================================================================

/**
 * Displacer fork — fresh root type (no existing "tuning fork" sprite to
 * subtype, and the closest thematic donor, /obj/item/resonator, carries its
 * own mode/field vars and attack_self that would fight with this item's).
 * Per the sprite rules, its icon/icon_state/inhand fields are copied
 * verbatim from /obj/item/resonator (code/modules/mining/equipment/resonator.dm).
 *
 * Use in hand: walks up to 5 tiles along the user's facing direction (plain
 * get_step() calls, no density/line-of-sight checks — "walls don't
 * matter"), finds the first movable atom there, and swaps turfs with it via
 * forceMove(). Both ends get a brief dizzy status (set_dizzy_if_lower())
 * if they're living. 20-second cooldown via the same COOLDOWN_* macros the
 * godslayer armour uses.
 */
/obj/item/displacer_fork
	name = "displacer fork"
	desc = "A tuning fork machined from something that hums back."
	icon = 'icons/obj/mining.dmi'
	icon_state = "resonator"
	inhand_icon_state = "resonator"
	lefthand_file = 'icons/mob/inhands/equipment/mining_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/mining_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	throwforce = 0
	COOLDOWN_DECLARE(fork_cooldown)

/obj/item/displacer_fork/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/displacer_fork/examine(mob/user)
	. = ..()
	if(!COOLDOWN_FINISHED(src, fork_cooldown))
		. += span_notice("It's still humming down from the last strike. Ready again in [COOLDOWN_TIMELEFT(src, fork_cooldown) / 10] seconds.")

/obj/item/displacer_fork/attack_self(mob/user, modifiers)
	. = ..()
	if(!COOLDOWN_FINISHED(src, fork_cooldown))
		to_chat(user, span_warning("[src] hasn't finished settling from the last strike."))
		return

	var/atom/movable/target = find_swap_target(user)
	if(!target)
		to_chat(user, span_notice("[src] hums and finds nothing worth trading places with."))
		return

	COOLDOWN_START(src, fork_cooldown, 20 SECONDS)

	var/turf/user_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(!user_turf || !target_turf)
		return

	user.visible_message(span_notice("[user] strikes [src] against the air — [user] and [target] flicker and trade places!"), \
		span_notice("You strike [src]. The world lurches sideways."))

	user.forceMove(target_turf)
	target.forceMove(user_turf)

	if(isliving(user))
		var/mob/living/living_user = user
		living_user.set_dizzy_if_lower(3 SECONDS)
	if(isliving(target))
		var/mob/living/living_target = target
		living_target.set_dizzy_if_lower(3 SECONDS)

/// Walks up to 5 tiles along the user's facing direction and returns the first movable found (ignoring the user and anchored atoms). Deliberately ignores density — "walls don't matter, the fork doesn't care."
/obj/item/displacer_fork/proc/find_swap_target(mob/user)
	var/turf/current = get_turf(user)
	for(var/i in 1 to 5)
		if(!current)
			return null
		current = get_step(current, user.dir)
		if(!current)
			return null
		for(var/atom/movable/candidate in current)
			if(candidate == user || candidate.anchored)
				continue
			if(isliving(candidate) || isobj(candidate))
				return candidate
	return null

// =========================================================================
// RED — Chronal splint
// =========================================================================

/**
 * Chronal splint — subtypes fingerless gloves for the sprite/slot. There is
 * no wrist inventory slot in this codebase, so the "wrist brace" flavor is
 * kept as description text on a hand-slot item; flagged as a deviation.
 *
 * Mechanic: every SSobj tick (2 seconds, matching the doc's sample rate
 * exactly — code/controllers/subsystem/processing/obj.dm) while worn, it
 * snapshots the wearer's turf and the four damage types + stamina into a
 * 5-entry ring buffer (~10 seconds of history). On COMSIG_MOB_STATCHANGE
 * reaching HARD_CRIT or DEAD — the same signal/registration pattern the
 * godslayer armour uses (code/modules/mining/lavaland/mining_loot/godslayer.dm)
 * — it restores the oldest snapshot (position + damage values via the
 * mob/living setXLoss() setters, reviving first if the wearer died) and
 * then destroys itself. One rewind per splint.
 */
/obj/item/clothing/gloves/chronal_splint
	name = "chronal splint"
	desc = "A wrist brace of overlapping brass leaves, ticking very slightly out of sync with the room."
	/// The wearer currently being tracked, if any.
	var/mob/living/wearer
	/// Ring buffer of recent (turf, damage) snapshots, oldest first.
	var/list/snapshots = list()
	/// Ten seconds of history at one sample per SSobj tick (2 seconds).
	var/max_snapshots = 5
	/// One rewind per splint.
	var/used = FALSE

/obj/item/clothing/gloves/chronal_splint/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/chronal_splint/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(wearer)
		UnregisterSignal(wearer, COMSIG_MOB_STATCHANGE)
	wearer = null
	snapshots = null
	return ..()

/obj/item/clothing/gloves/chronal_splint/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	wearer = user
	START_PROCESSING(SSobj, src)
	RegisterSignal(user, COMSIG_MOB_STATCHANGE, PROC_REF(on_statchange))

/obj/item/clothing/gloves/chronal_splint/dropped(mob/user, silent = FALSE)
	. = ..()
	STOP_PROCESSING(SSobj, src)
	if(wearer)
		UnregisterSignal(wearer, COMSIG_MOB_STATCHANGE)
	wearer = null
	snapshots.Cut()

/obj/item/clothing/gloves/chronal_splint/process(seconds_per_tick)
	if(used || !wearer || QDELETED(wearer))
		return
	var/turf/wearer_turf = get_turf(wearer)
	if(!wearer_turf)
		return
	snapshots += list(list(
		"turf" = wearer_turf,
		"brute" = wearer.getBruteLoss(),
		"fire" = wearer.getFireLoss(),
		"tox" = wearer.getToxLoss(),
		"oxy" = wearer.getOxyLoss(),
		"stamina" = wearer.getStaminaLoss(),
	))
	if(length(snapshots) > max_snapshots)
		snapshots.Cut(1, 2)

/obj/item/clothing/gloves/chronal_splint/proc/on_statchange(mob/living/user, new_stat)
	SIGNAL_HANDLER
	if(used || new_stat < HARD_CRIT || !length(snapshots))
		return
	used = TRUE
	STOP_PROCESSING(SSobj, src)
	// Defer the rewind out of the stat-change call stack: this signal fires
	// from inside set_stat()/death() and rewriting health reentrantly while
	// death handling is still unwinding is asking for trouble (the godslayer
	// cloak dodges this by never triggering on DEAD at all; we do, so we defer).
	addtimer(CALLBACK(src, PROC_REF(rewind), user), 1)

/// Performs the one-shot rewind: position, then damage, then revival if needed.
/obj/item/clothing/gloves/chronal_splint/proc/rewind(mob/living/user)
	if(QDELETED(user) || !length(snapshots))
		qdel(src)
		return

	var/list/snap = snapshots[1]
	var/turf/target_turf = snap["turf"]
	if(target_turf)
		user.forceMove(target_turf)
	// Restore the snapshot's damage BEFORE reviving — revive() with no heal
	// flags leaves current damage in place, and a still-lethal total would
	// just kill the wearer again on the next health update
	user.setBruteLoss(snap["brute"])
	user.setFireLoss(snap["fire"])
	user.setToxLoss(snap["tox"])
	user.setOxyLoss(snap["oxy"])
	user.setStaminaLoss(snap["stamina"])
	if(user.stat == DEAD)
		user.revive(NONE)

	user.visible_message(span_warning("[user]'s wrist brace flares and cracks in half — [user.p_theyre()] weren't there a moment ago!"), \
		span_userdanger("The last ten seconds unwind. You're back where you were, and the splint is dead weight."))

	qdel(src)

// =========================================================================
// RED — Eventide courier coat
// =========================================================================

/**
 * Eventide courier coat — subtypes the plain labcoat for the sprite.
 *
 * There's no storage-component way to hold an object "of any size"
 * (max_specific_storage caps by w_class, and mobs/structures aren't
 * insertable into /datum/storage at all), so — per the doc's own fallback
 * suggestion — this uses a bespoke single-slot holder instead, the same
 * pattern body bags use for arbitrary-size contents
 * (code/game/objects/items/bodybag.dm's bluespace variant forceMoves
 * anything in `contents` directly).
 *
 * Insertion: drag the target atom onto the coat (mouse_drop_receive() —
 * the same drag-and-drop hook /obj/structure/closet uses to accept items
 * and mobs dragged into it, code/game/objects/structures/crates_lockers/closets.dm).
 * Works whether the coat is on the ground or worn (dragging onto the
 * inventory slot icon routes to the same proc). Retrieval: click the worn
 * coat with an empty hand (attack_hand()) to start a 2-second rummage.
 *
 * Blocklist, per spec: no anchored objects, no live-and-conscious
 * ("unwilling") mobs, exactly one object at a time.
 */
/obj/item/clothing/suit/toggle/labcoat/eventide_courier
	name = "Eventide courier coat"
	desc = "A lab coat with one inside pocket the tailor refuses to discuss."
	/// The one object stashed in the inside pocket, if any.
	var/atom/movable/stashed_object

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/Destroy()
	if(stashed_object && !QDELETED(stashed_object))
		stashed_object.forceMove(drop_location())
	stashed_object = null
	return ..()

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/examine(mob/user)
	. = ..()
	if(stashed_object)
		. += span_notice("Something's tucked into the inside pocket. It weighs exactly the same as the coat without it.")

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/mouse_drop_receive(atom/movable/dropped, mob/user, params)
	. = ..()
	if(!istype(dropped) || dropped == src || dropped == user)
		return

	if(stashed_object)
		to_chat(user, span_warning("[src]'s inside pocket is already full."))
		return
	if(dropped.anchored)
		to_chat(user, span_warning("[dropped] won't budge."))
		return
	if(isliving(dropped))
		var/mob/living/living_dropped = dropped
		if(living_dropped.stat == CONSCIOUS)
			to_chat(user, span_warning("[living_dropped] isn't going to just climb in there."))
			return

	user.visible_message(span_notice("[user] tucks [dropped] into [src]'s inside pocket."), \
		span_notice("You tuck [dropped] into the inside pocket."))
	dropped.forceMove(src)
	stashed_object = dropped

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/attack_hand(mob/user, list/modifiers)
	if(loc == user && stashed_object)
		rummage(user)
		return TRUE
	return ..()

/// 2-second rummage that produces the stashed object at the user's feet.
/obj/item/clothing/suit/toggle/labcoat/eventide_courier/proc/rummage(mob/user)
	if(!stashed_object)
		to_chat(user, span_notice("The inside pocket is empty."))
		return
	to_chat(user, span_notice("You rummage through the inside pocket..."))
	if(!do_after(user, 2 SECONDS, src))
		return
	if(!stashed_object || QDELETED(stashed_object))
		stashed_object = null
		return
	var/atom/movable/produced = stashed_object
	stashed_object = null
	produced.forceMove(get_turf(user))
	user.visible_message(span_notice("[user] draws [produced] out of [src]'s inside pocket."), \
		span_notice("You draw [produced] out of the inside pocket."))
