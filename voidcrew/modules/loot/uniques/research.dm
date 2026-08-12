/**
 * # Research uniques: priority specimen cache
 *
 * Six unique prizes for the RESEARCH loot theme (see the "priority specimen
 * cache" `loot_uniques` shelf in voidcrew/modules/loot/themes/, this file
 * does not touch those tables; slotting these in is a separate pass).
 * Design source: obsidian vault `Rare-loot-uniques.md`, "RESEARCH: priority
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
// File-local defines, #undef'd at the bottom so they don't leak into the
// global namespace (same convention as occult.dm and zone_loot.dm).
// =========================================================================
/// Alpha at or below which the calibration prism's pulse treats something as
/// hiding. The MOD cloaking modules sit at 50 (prototype) and 20 (ninja), and
/// the guardian assassin's stealth at 15. Merely translucent things, the
/// heretic ascension buff at 180, say, are left alone.
#define PRISM_STEALTH_ALPHA 120
/// How far the prism's pulse reaches, in tiles.
#define PRISM_PULSE_RANGE 7
/// How long a target the pulse catches is held at full visibility.
#define PRISM_REVEAL_DURATION (12 SECONDS)
/// Time between pulses.
#define PRISM_PULSE_COOLDOWN (45 SECONDS)
/// add_filter() key for the outline the prism paints on whatever it reveals.
#define PRISM_OUTLINE_FILTER "prism_reveal_outline"
/// How long it takes to work something into the Eventide coat's inside pocket.
#define EVENTIDE_STASH_TIME (3 SECONDS)
/// How long it takes to get it back out again.
#define EVENTIDE_RUMMAGE_TIME (2 SECONDS)

// =========================================================================
// GREEN: Calibration prism
// =========================================================================

/// Action button: fire the reveal pulse. /datum/action/item_action's default
/// Trigger() routes through ui_action_click() to attack_self(), so the item
/// only needs the attack_self override below.
/datum/action/item_action/prism_pulse
	name = "Pulse Prism"
	desc = "Throw a band of hard light that forces anything cloaked nearby back into view."

/**
 * Calibration prism: subtypes science goggles purely for the sprite AND
 * because /obj/item/clothing/glasses/science already carries
 * TRAIT_REAGENT_SCANNER (see code/modules/clothing/glasses/_glasses.dm),
 * which is the actual mechanism reagent containers use to decide whether an
 * examiner sees exact contents/volumes (code/modules/mob/mob_helpers.dm).
 * That means the doc's first bullet ("examine any reagent container to see
 * its exact contents") is inherited for free, no new examine hook needed.
 *
 * The second bullet (see cloaked/invisible things) needs TWO mechanisms,
 * because this codebase hides people in two unrelated ways:
 *
 * 1. Invisibility. The atom's `invisibility` var is raised above the viewer's
 *    `see_invisible`: ghosts, revenants, jaunting mobs. `invis_override`
 *    below counters this passively, and that is the part that already worked.
 *    (`invis_view` would not: carbon/update_sight() min()s it against the
 *    wearer's base see_invisible, so it can only ever REDUCE what you see.)
 *
 * 2. Alpha. The mob's `alpha` is animated down toward 0 and its `invisibility`
 *    is never touched at all, /obj/item/mod/module/stealth (both the
 *    prototype and the ninja advanced module, code/modules/mod/modules/modules_ninja.dm)
 *    does exactly `animate(mod.wearer, alpha = stealth_alpha)` with
 *    stealth_alpha 50/20, and the guardian assassin's stealth status effect
 *    does the same at 15. Alpha is a render-blend property with no
 *    relationship to see_invisible whatsoever, so no amount of invis_override
 *    will ever reveal a ninja cloak. That was the playtest bug.
 *
 * The pulse below is the counter for case 2: it sweeps for nearby atoms that
 * have been faded out and forces them back to full opacity for a while. It
 * lives on an action button rather than attack_self alone, because attack_self
 * is unreachable while the prism is on your eyes.
 *
 * Not countered, and out of scope: appearance-swap stealth, which is a third
 * mechanism again, the heretic's shadow cloak (add_alt_appearance with an
 * override image) and the chameleon projector (walking around inside an
 * /obj/effect/dummy/chameleon) both leave alpha and invisibility completely
 * normal, so neither lever here touches them.
 *
 * Typepath nests under .../glasses/science/calibration_prism (not the doc's
 * flat .../glasses/calibration_prism) so it can subtype science goggles
 * directly instead of duplicating its vars.
 */
/obj/item/clothing/glasses/science/calibration_prism
	name = "calibration prism"
	desc = "Lab glasses with a wedge of doped crystal where the left lens should be. Property of E.E.A. Return if found, please."
	// Counters invisibility-based hiding (ghosts and the like). Observer tier
	// means ghosts shimmer at the edge of the lens too; the E.E.A. would call
	// that a feature. Alpha-based cloaks are handled by the pulse instead.
	invis_override = SEE_INVISIBLE_OBSERVER
	// attack_self only fires with the item in hand, and this is worn on the
	// eyes, the action button is the only reachable activation path.
	actions_types = list(/datum/action/item_action/prism_pulse)
	COOLDOWN_DECLARE(pulse_cooldown)

/obj/item/clothing/glasses/science/calibration_prism/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/glasses/science/calibration_prism/examine(mob/user)
	. = ..()
	. += span_notice("Pulsing the prism forces anything cloaked within [PRISM_PULSE_RANGE] tiles back into view for [DisplayTimeText(PRISM_REVEAL_DURATION)].")
	if(COOLDOWN_FINISHED(src, pulse_cooldown))
		. += span_notice("It's charged.")
	else
		. += span_notice("It's recharging. Ready in [DisplayTimeText(COOLDOWN_TIMELEFT(src, pulse_cooldown))].")

/obj/item/clothing/glasses/science/calibration_prism/attack_self(mob/user, modifiers)
	. = ..()
	if(!COOLDOWN_FINISHED(src, pulse_cooldown))
		to_chat(user, span_warning("[src] hasn't recharged. Ready in [DisplayTimeText(COOLDOWN_TIMELEFT(src, pulse_cooldown))]."))
		return
	COOLDOWN_START(src, pulse_cooldown, PRISM_PULSE_COOLDOWN)
	pulse_reveal(user)

/// Sweeps nearby turfs for atoms that have been faded out by an alpha cloak and forces them back to full visibility.
/obj/item/clothing/glasses/science/calibration_prism/proc/pulse_reveal(mob/user)
	var/turf/origin = get_turf(user)
	if(!origin)
		return

	playsound(src, 'sound/effects/stealthoff.ogg', 50, TRUE)
	user.visible_message(span_notice("[src] throws off a hard band of light."), \
		span_notice("You pulse [src]."))

	var/revealed = 0
	for(var/mob/living/hidden_mob in view(PRISM_PULSE_RANGE, origin))
		if(hidden_mob == user || hidden_mob.alpha > PRISM_STEALTH_ALPHA)
			continue
		hidden_mob.apply_status_effect(/datum/status_effect/prism_revealed)
		revealed++

	for(var/obj/hidden_object in view(PRISM_PULSE_RANGE, origin))
		// /obj/effect covers a great deal of deliberately translucent scenery
		// and visual-only atoms. None of it is hiding anybody, and repainting
		// it opaque would just look broken.
		if(istype(hidden_object, /obj/effect) || hidden_object.alpha > PRISM_STEALTH_ALPHA)
			continue
		// Already caught by an earlier pulse: re-revealing would overwrite the
		// saved alpha with 255 and strand it there when the timer fires.
		// (Mobs don't need this guard. The status effect is STATUS_EFFECT_UNIQUE
		// and refreshes rather than stacking.)
		if(hidden_object.get_filter(PRISM_OUTLINE_FILTER))
			continue
		reveal_object(hidden_object)
		revealed++

	if(!revealed)
		to_chat(user, span_notice("Nothing within [PRISM_PULSE_RANGE] tiles is hiding."))
		return
	to_chat(user, span_notice("[revealed] hidden thing[revealed == 1 ? "" : "s"] light[revealed == 1 ? "s" : ""] up."))

/// Objects can't carry status effects, so a revealed one gets the same treatment on a plain timer.
/obj/item/clothing/glasses/science/calibration_prism/proc/reveal_object(obj/hidden_object)
	var/old_alpha = hidden_object.alpha
	animate(hidden_object, alpha = 255, time = 0.3 SECONDS)
	hidden_object.add_filter(PRISM_OUTLINE_FILTER, 2, outline_filter(1, COLOR_CYAN))
	addtimer(CALLBACK(src, PROC_REF(unreveal_object), hidden_object, old_alpha), PRISM_REVEAL_DURATION)

/// Puts a revealed object back how it was. Objects, unlike mobs, do get their old alpha restored. Plenty of them are translucent for reasons that have nothing to do with stealth.
/obj/item/clothing/glasses/science/calibration_prism/proc/unreveal_object(obj/hidden_object, old_alpha)
	if(QDELETED(hidden_object))
		return
	hidden_object.remove_filter(PRISM_OUTLINE_FILTER)
	animate(hidden_object, alpha = old_alpha, time = 0.3 SECONDS)

/**
 * Forced visibility, applied by the calibration prism's pulse.
 *
 * Alpha-based stealth is not invisibility, so the only counter is to push the
 * target's alpha back up and hold it there. A cloak switched back on during
 * the window re-runs its own animate() against the same var, so this
 * re-asserts on every tick, a non-parallel animate() replaces whatever
 * animation is pending, so the prism wins inside a second.
 */
/datum/status_effect/prism_revealed
	id = "prism_revealed"
	duration = PRISM_REVEAL_DURATION
	tick_interval = 1 SECONDS
	alert_type = null

/datum/status_effect/prism_revealed/on_apply()
	. = ..()
	if(!.)
		return FALSE
	animate(owner, alpha = 255, time = 0.3 SECONDS)
	owner.add_filter(PRISM_OUTLINE_FILTER, 2, outline_filter(1, COLOR_CYAN))
	to_chat(owner, span_warning("A band of light washes over you. Anything hiding you stops working for the next [DisplayTimeText(PRISM_REVEAL_DURATION)]."))
	return TRUE

/datum/status_effect/prism_revealed/tick(seconds_between_ticks)
	if(owner.alpha < 255)
		animate(owner, alpha = 255, time = 0.3 SECONDS)

/datum/status_effect/prism_revealed/on_remove()
	owner.remove_filter(PRISM_OUTLINE_FILTER)
	// The alpha found on the way in is deliberately not restored. The point of
	// the pulse is that the cloak stops working, and putting the old value
	// back would re-hide someone who had already switched their cloak off in
	// the meantime. Anyone who re-activates their stealth animates their own
	// alpha back down.
	to_chat(owner, span_notice("The glare fades."))
	return ..()

// =========================================================================
// GREEN: Annex notebook, vol. IX
// =========================================================================

/**
 * Annex notebook, vol. IX: subtypes a plain book for its behaviour (the type
 * is safe to subtype, it's spawned standalone elsewhere) with a custom
 * "annex_notebook" state in uniques.dmi over the top, since the library book
 * sprite read as generic set dressing in playtest. Overriding icon_state is
 * safe here: /obj/item/book only ever reassigns it via gen_random_icon_state(),
 * which is called from /obj/item/book/random and the library machines, never
 * from the plain book's own Initialize().
 *
 * Use on a machine: prints its parts manifest (machinery/display_parts(),
 * the same readout the RPED uses, code/game/machinery/_machinery.dm) and
 * upgrades one random stock part already inside by one tier, mirroring how
 * the RPED (code/modules/research/part_replacer.dm) exchanges parts, but
 * self-contained (no RPED storage needed). Three uses, then it's a diary.
 *
 * Only handles legacy /obj/item/stock_parts parts (capacitor, scanning
 * module, servo, micro laser, matter bin), modern /datum/stock_part
 * machines are silently skipped by the typed for-loop below, same as the
 * doc's simplification allowance suggests for anything not cleanly
 * generalizable.
 */
/obj/item/book/annex_notebook
	name = "Annex notebook, vol. IX"
	desc = "A lab notebook in three different handwritings. The third one was in a hurry."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "annex_notebook"
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
	// /datum/stock_part singletons, most tiered machines use the datums
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
		to_chat(user, span_notice("A margin note describes a modification the manufacturer never approved, [new_part.name()] clicks into place."))
	else
		var/obj/item/stock_parts/old_item = chosen
		var/new_type = upgrade_map[old_item.type]
		target_machine.component_parts -= old_item
		qdel(old_item)
		var/obj/item/stock_parts/upgraded = new new_type()
		upgraded.forceMove(target_machine)
		target_machine.component_parts += upgraded
		target_machine.RefreshParts()
		to_chat(user, span_notice("A margin note describes a modification the manufacturer never approved, [upgraded.name] clicks into place."))

	return ITEM_INTERACT_SUCCESS

/// Finds the /datum/stock_part singleton one tier above the given one (same physical base type), or null.
/obj/item/book/annex_notebook/proc/get_next_tier_datum(datum/stock_part/part)
	for(var/datum_type in GLOB.stock_part_datums)
		var/datum/stock_part/candidate = GLOB.stock_part_datums[datum_type]
		if(candidate.physical_object_base_type == part.physical_object_base_type && candidate.tier == part.tier + 1)
			return candidate
	return null

// =========================================================================
// YELLOW: Entangled pair
// =========================================================================

/**
 * Entangled pair: subtypes a plain beaker. Spawns linked: the first
 * instance's Initialize() spawns its twin alongside it and links both
 * weakrefs in one pass (an explicit `..(mapload)` keeps the twin's partner
 * arg from leaking further up the beaker/reagent_containers Initialize
 * chain). Both halves are the same type, so the custom sprite covers both.
 *
 * Sprite note: the "entangled_beaker" state in uniques.dmi is drawn on the
 * vanilla beaker's exact silhouette, tinted violet with a brass collar and
 * serial tag. That geometry is load-bearing, not laziness, the liquid
 * overlay does NOT come from `icon`. reagent_containers/update_overlays()
 * builds it from a separate file, `fill_icon`
 * ('icons/obj/medical/reagent_fillings.dmi'), keyed "[fill_icon_state ||
 * icon_state][threshold]". A custom icon_state with no fill_icon_state would
 * therefore look for "entangled_beaker20" in that file and silently render
 * nothing, so fill_icon_state is pinned to "beaker" and the body is kept
 * where the "beaker20".."beaker100" art expects it.
 *
 * Mechanic: hooks the same on_reagent_change() signal handler every
 * reagent_containers item already uses for its fill-icon update
 * (code/modules/reagents/reagent_containers.dm, wired to
 * COMSIG_REAGENTS_HOLDER_UPDATED in create_reagents()). Whenever this
 * beaker's contents change and it isn't already relaying, it moves its
 * entire volume to the twin via reagents.trans_to() (default move
 * semantics, not copy), "poured into one, exists in the other instead."
 * A `relaying` guard on both beakers (set before the transfer, cleared
 * after) stops the reentrant COMSIG_REAGENTS_HOLDER_UPDATED firing on
 * either side from bouncing the volume back and forth forever.
 */
/obj/item/reagent_containers/cup/beaker/entangled
	name = "entangled beaker"
	desc = "Two beakers with identical serial numbers. Anything you pour into one turns up in the other instead."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "entangled_beaker"
	// Keeps the liquid overlay pointed at the vanilla beaker fill art, see
	// the sprite note above.
	fill_icon_state = "beaker"
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
// YELLOW: Displacer fork
// =========================================================================

/**
 * Displacer fork: fresh root type (no existing "tuning fork" sprite to
 * subtype, and the closest thematic donor, /obj/item/resonator, carries its
 * own mode/field vars and attack_self that would fight with this item's).
 * Per the sprite rules, its icon/icon_state/inhand fields are copied
 * verbatim from /obj/item/resonator (code/modules/mining/equipment/resonator.dm).
 *
 * Use in hand: walks up to 5 tiles along the user's facing direction (plain
 * get_step() calls, no density/line-of-sight checks, "walls don't
 * matter"), finds the first movable atom there, and swaps turfs with it via
 * forceMove(). Both ends get a brief dizzy status (set_dizzy_if_lower())
 * if they're living. 20-second cooldown via the same COOLDOWN_* macros the
 * godslayer armour uses.
 */
/obj/item/displacer_fork
	name = "displacer fork"
	desc = "A tuning fork machined out of some dark alloy. Strike it and you trade places with whatever's in front of you."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "displacer_fork"
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
		to_chat(user, span_notice("[src] hums, but there's nothing ahead of you to swap with."))
		return

	COOLDOWN_START(src, fork_cooldown, 20 SECONDS)

	var/turf/user_turf = get_turf(user)
	var/turf/target_turf = get_turf(target)
	if(!user_turf || !target_turf)
		return

	user.visible_message(span_notice("[user] strikes [src] against the air, [user] and [target] flicker and trade places!"), \
		span_notice("You strike [src]. The world lurches sideways."))

	user.forceMove(target_turf)
	target.forceMove(user_turf)

	if(isliving(user))
		var/mob/living/living_user = user
		living_user.set_dizzy_if_lower(3 SECONDS)
	if(isliving(target))
		var/mob/living/living_target = target
		living_target.set_dizzy_if_lower(3 SECONDS)

/// Walks up to 5 tiles along the user's facing direction and returns the first movable found (ignoring the user and anchored atoms). Deliberately ignores density, "walls don't matter, the fork doesn't care."
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
// RED: Chronal splint
// =========================================================================

/**
 * Chronal splint: subtypes fingerless gloves for the slot. There is no wrist
 * inventory slot in this codebase, so the "wrist brace" flavor is kept as
 * description text on a hand-slot item; flagged as a deviation.
 *
 * Sprite: custom "chronal_splint" states in uniques.dmi (item) and
 * uniques_worn.dmi (worn, 4 dirs, drawn on the vanilla fingerless-glove hand
 * mask so the hands land in the right places). worn_icon_state MUST be set
 * alongside icon_state, build_worn_icon() resolves the worn state as
 * `worn_icon_state || icon_state` (code/modules/mob/living/carbon/human/human_update_icons.dm),
 * so a custom icon_state on its own would send the glove layer looking for
 * "chronal_splint" in the stock hands.dmi and render nothing. Overriding the
 * icon fields is safe on this type: /obj/item/clothing/gloves only wires
 * greyscale_config_inhand_left/right, so its GAGS setup feeds the inhand
 * sprites and nothing else (same reasoning as the pallbearer's gloves in
 * occult.dm).
 *
 * Mechanic: every SSobj tick (2 seconds, matching the doc's sample rate
 * exactly, code/controllers/subsystem/processing/obj.dm) while worn, it
 * snapshots the wearer's turf and the four damage types + stamina into a
 * 5-entry ring buffer (~10 seconds of history). On COMSIG_MOB_STATCHANGE
 * reaching HARD_CRIT or DEAD, the same signal/registration pattern the
 * godslayer armour uses (code/modules/mining/lavaland/mining_loot/godslayer.dm),
 * it restores the oldest snapshot (position + damage values via the
 * mob/living setXLoss() setters, reviving first if the wearer died) and
 * then destroys itself. One rewind per splint.
 */
/obj/item/clothing/gloves/fingerless/chronal_splint
	name = "chronal splint"
	desc = "A wrist brace of overlapping brass leaves, ticking slightly out of time with everything else. If you go down, it rewinds you ten seconds and snaps in half."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "chronal_splint"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "chronal_splint"
	/// The wearer currently being tracked, if any.
	var/mob/living/wearer
	/// Ring buffer of recent (turf, damage) snapshots, oldest first.
	var/list/snapshots = list()
	/// Ten seconds of history at one sample per SSobj tick (2 seconds).
	var/max_snapshots = 5
	/// One rewind per splint.
	var/used = FALSE

/obj/item/clothing/gloves/fingerless/chronal_splint/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/fingerless/chronal_splint/Destroy()
	STOP_PROCESSING(SSobj, src)
	if(wearer)
		UnregisterSignal(wearer, COMSIG_MOB_STATCHANGE)
	wearer = null
	snapshots = null
	return ..()

/obj/item/clothing/gloves/fingerless/chronal_splint/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(!(slot & ITEM_SLOT_GLOVES))
		return
	// equipped() can fire again without an intervening dropped() (equipping
	// straight from one wearer's hands into another's glove slot, say), so
	// drop the old hook first and let the new one overwrite rather than
	// stacking a duplicate registration.
	if(wearer && wearer != user)
		UnregisterSignal(wearer, COMSIG_MOB_STATCHANGE)
	wearer = user
	START_PROCESSING(SSobj, src)
	RegisterSignal(user, COMSIG_MOB_STATCHANGE, PROC_REF(on_statchange), override = TRUE)

/obj/item/clothing/gloves/fingerless/chronal_splint/dropped(mob/user, silent = FALSE)
	. = ..()
	STOP_PROCESSING(SSobj, src)
	if(wearer)
		UnregisterSignal(wearer, COMSIG_MOB_STATCHANGE)
	wearer = null
	snapshots.Cut()

/obj/item/clothing/gloves/fingerless/chronal_splint/process(seconds_per_tick)
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

/obj/item/clothing/gloves/fingerless/chronal_splint/proc/on_statchange(mob/living/user, new_stat)
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
/obj/item/clothing/gloves/fingerless/chronal_splint/proc/rewind(mob/living/user)
	if(QDELETED(user) || !length(snapshots))
		qdel(src)
		return

	var/list/snap = snapshots[1]
	var/turf/target_turf = snap["turf"]
	if(target_turf)
		user.forceMove(target_turf)
	// Restore the snapshot's damage BEFORE reviving, revive() with no heal
	// flags leaves current damage in place, and a still-lethal total would
	// just kill the wearer again on the next health update
	user.setBruteLoss(snap["brute"])
	user.setFireLoss(snap["fire"])
	user.setToxLoss(snap["tox"])
	user.setOxyLoss(snap["oxy"])
	user.setStaminaLoss(snap["stamina"])
	if(user.stat == DEAD)
		user.revive(NONE)

	user.visible_message(span_warning("[user]'s wrist brace flares and cracks in half, and suddenly [user.p_theyre()] standing somewhere else!"), \
		span_userdanger("The last ten seconds unwind. You're back where you were, and the splint is scrap."))

	qdel(src)

// =========================================================================
// RED: Eventide courier coat
// =========================================================================

/**
 * Eventide courier coat: subtypes the plain labcoat.
 *
 * Sprite: custom states in uniques.dmi (item) and uniques_worn.dmi (worn,
 * 4 dirs, drawn on the vanilla labcoat's worn pixel mask so the body zones
 * line up), recoloured to dark slate canvas with a tan courier strap.
 * BOTH a closed and an open state are required, and they must be named
 * "<state>" and "<state>_t": /obj/item/clothing/suit/toggle adds
 * /datum/component/toggle_icon, whose do_icon_toggle() flips icon_state
 * between base_icon_state and "[base_icon_state]_t" on alt-click. This type
 * deliberately does NOT set worn_icon_state, exactly like the vanilla
 * labcoat, so build_worn_icon()'s `worn_icon_state || icon_state` fallback
 * lets the worn sprite follow the toggle too. Pinning worn_icon_state would
 * freeze the worn sprite in the closed state forever.
 *
 * There's no storage-component way to hold an object "of any size"
 * (max_specific_storage caps by w_class, and mobs/structures aren't
 * insertable into /datum/storage at all), so, per the doc's own fallback
 * suggestion, this uses a bespoke single-slot holder instead, the same
 * pattern body bags use for arbitrary-size contents
 * (code/game/objects/items/bodybag.dm's bluespace variant forceMoves
 * anything in `contents` directly).
 *
 * Insertion: drag the target atom onto the coat (mouse_drop_receive().
 * The same drag-and-drop hook /obj/structure/closet uses to accept items
 * and mobs dragged into it, code/game/objects/structures/crates_lockers/closets.dm).
 * Works whether the coat is on the ground or worn (dragging onto the
 * inventory slot icon routes to the same proc). Getting something in takes a
 * visible do_after; nothing moves until it completes, so an interrupted
 * stash simply leaves the target where it was. Retrieval: click the worn coat
 * with an empty hand (attack_hand()) to start a rummage.
 *
 * Blocklist, per spec: no anchored objects, no live-and-conscious
 * ("unwilling") mobs, exactly one object at a time.
 */
/obj/item/clothing/suit/toggle/labcoat/eventide_courier
	name = "Eventide courier coat"
	desc = "A lab coat with an inside pocket that holds absolutely anything, whatever the size. Drag something onto the coat to work it in."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "eventide_coat"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	/// The one object stashed in the inside pocket, if any.
	var/atom/movable/stashed_object

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/Destroy()
	if(stashed_object)
		UnregisterSignal(stashed_object, COMSIG_QDELETING)
		if(!QDELETED(stashed_object))
			stashed_object.forceMove(drop_location())
		stashed_object = null
	return ..()

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/examine(mob/user)
	. = ..()
	. += span_notice("Dragging something onto the coat works it into the inside pocket. Takes [DisplayTimeText(EVENTIDE_STASH_TIME)].")
	if(stashed_object)
		. += span_notice("Something's tucked into the inside pocket. It weighs exactly the same as the coat without it.")
		. += span_notice("Click the coat with an empty hand to dig it back out. Takes [DisplayTimeText(EVENTIDE_RUMMAGE_TIME)].")

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/mouse_drop_receive(atom/movable/dropped, mob/user, params)
	. = ..()
	if(!istype(dropped) || dropped == src || dropped == user)
		return
	if(!can_stash(dropped, user))
		return

	user.visible_message(span_notice("[user] starts working [dropped] into [src]'s inside pocket."), \
		span_notice("You start working [dropped] into the inside pocket."))

	if(!do_after(user, EVENTIDE_STASH_TIME, dropped))
		to_chat(user, span_warning("You stop before [dropped] is all the way in."))
		return

	// do_after slept, so everything checked before it has to be checked again:
	// the pocket may have been filled, the target may have woken up, been
	// anchored, been deleted, or been carried out of reach.
	if(QDELETED(src) || QDELETED(dropped) || !can_stash(dropped, user))
		return
	if(!user.can_perform_action(dropped, FORBID_TELEKINESIS_REACH))
		return

	dropped.forceMove(src)
	stashed_object = dropped
	// Without this the ref dangles (and holds a harddel) if whatever is in the
	// pocket gets deleted out from under us.
	RegisterSignal(dropped, COMSIG_QDELETING, PROC_REF(on_stash_deleted))
	user.visible_message(span_notice("[user] works [dropped] into [src]'s inside pocket."), \
		span_notice("You work [dropped] into the inside pocket."))

/// Shared gate for the stash checks, run both before and after the do_after.
/obj/item/clothing/suit/toggle/labcoat/eventide_courier/proc/can_stash(atom/movable/target, mob/user)
	if(stashed_object)
		to_chat(user, span_warning("[src]'s inside pocket is already full."))
		return FALSE
	if(target.anchored)
		to_chat(user, span_warning("[target] won't budge."))
		return FALSE
	if(isliving(target))
		var/mob/living/living_target = target
		if(living_target.stat == CONSCIOUS)
			to_chat(user, span_warning("[living_target] isn't going to just climb in there."))
			return FALSE
	return TRUE

/// Keeps stashed_object from dangling if the thing in the pocket is deleted.
/obj/item/clothing/suit/toggle/labcoat/eventide_courier/proc/on_stash_deleted(datum/source)
	SIGNAL_HANDLER
	stashed_object = null

/obj/item/clothing/suit/toggle/labcoat/eventide_courier/attack_hand(mob/user, list/modifiers)
	if(loc == user && stashed_object)
		rummage(user)
		return TRUE
	return ..()

/// Rummage that produces the stashed object at the user's feet.
/obj/item/clothing/suit/toggle/labcoat/eventide_courier/proc/rummage(mob/user)
	if(!stashed_object)
		to_chat(user, span_notice("The inside pocket is empty."))
		return
	to_chat(user, span_notice("You rummage through the inside pocket..."))
	if(!do_after(user, EVENTIDE_RUMMAGE_TIME, src))
		return
	if(QDELETED(stashed_object))
		stashed_object = null
		return
	var/atom/movable/produced = stashed_object
	UnregisterSignal(produced, COMSIG_QDELETING)
	stashed_object = null
	produced.forceMove(get_turf(user))
	user.visible_message(span_notice("[user] draws [produced] out of [src]'s inside pocket."), \
		span_notice("You draw [produced] out of the inside pocket."))

#undef PRISM_STEALTH_ALPHA
#undef PRISM_PULSE_RANGE
#undef PRISM_REVEAL_DURATION
#undef PRISM_PULSE_COOLDOWN
#undef PRISM_OUTLINE_FILTER
#undef EVENTIDE_STASH_TIME
#undef EVENTIDE_RUMMAGE_TIME
