/**
 * # Plunder Uniques — the quartermaster's strongbox
 *
 * Seven one-of-a-kind prizes for the PLUNDER rare loot tables (see
 * voidcrew/modules/loot/zone_loot.dm, the `/obj/structure/closet/crate/zone_loot/plunder/rare`
 * config). Each item is a subtype of an existing, already-sprited item so no
 * new art is required — see the header comment on each item for its sprite
 * donor.
 *
 * Every item here is a genuine one-off: Initialize() always adds
 * TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so the Helios pattern stamp
 * (and any future duplicator) refuses to copy it.
 *
 * Not wired into any loot table yet — that's a follow-up pass alongside the
 * other cache themes (see the TODO in zone_loot.dm).
 */

// =========================================================================
// Shared helpers — trade value lookups against the live outpost economy.
// The "trade-in value" of an item is whatever an outpost's shop is
// currently paying for it this round (voidcrew/modules/trade/shop_buyback.dm),
// scanned across every trader outpost on the overmap (GLOB.trader_outposts,
// voidcrew/modules/trade/outpost.dm). Vouchers are weighted heavily above
// credits since they're the currency that can't be farmed safely.
// =========================================================================

#define TRADE_VALUE_VOUCHER_WEIGHT 1000

/// Finds the best-paying live buyback entry for an item, across every
/// trader outpost's shops. Returns null if nobody's buying.
/proc/find_item_buyback(obj/item/checked_item)
	if(!istype(checked_item))
		return null
	var/datum/shop_buyback/best
	var/best_score = 0
	for(var/obj/structure/overmap/trader_outpost/outpost as anything in GLOB.trader_outposts)
		for(var/datum/outpost_shop/shop as anything in outpost.get_all_shops())
			if(!shop)
				continue
			for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
				if(!buyback.matches(checked_item))
					continue
				var/score = buyback.pay_vouchers * TRADE_VALUE_VOUCHER_WEIGHT + buyback.pay_credits
				if(!best || score > best_score)
					best = buyback
					best_score = score
	return best

/// A single comparable number for an item's trade value (vouchers dominate
/// credits). Zero if nobody's buying it right now.
/proc/item_trade_value_score(obj/item/checked_item)
	var/datum/shop_buyback/best = find_item_buyback(checked_item)
	if(!best)
		return 0
	return best.pay_vouchers * TRADE_VALUE_VOUCHER_WEIGHT + best.pay_credits

/// Ascending comparator on trade value, for sortTim().
/proc/cmp_trade_value_asc(obj/item/item_a, obj/item/item_b)
	return item_trade_value_score(item_a) - item_trade_value_score(item_b)

// =========================================================================
// GREEN — Cheat's deck
// Sprite donor: /obj/item/toy/cards/deck (52-card standard deck, unmodified
// sprite/inhand/worn states). The vanilla deck already tracks a real 52-card
// count, so "fifty-two draws then it's spent" falls out of the base deck's
// own card-count logic for free — no separate charge counter needed.
// =========================================================================

#define CHEATS_DECK_COOLDOWN (30 SECONDS)
#define CHEATS_DECK_TRAIT_SOURCE "cheats_deck_luck"

/// A boost/jinx table drawn from on every card pulled from the deck, on a
/// cooldown. ~70% boon / ~30% jinx per the design doc.
/obj/item/toy/cards/deck/cheats
	name = "cheat's deck"
	desc = "Fifty-two cards, all of them marked, none of them consistently."
	COOLDOWN_DECLARE(luck_cooldown)

/obj/item/toy/cards/deck/cheats/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/toy/cards/deck/cheats/attack_hand(mob/living/user, list/modifiers, flip_card = FALSE)
	var/cards_before = count_cards()
	. = ..()
	// The parent can refuse the draw (no dexterity, telekinesis, etc) —
	// fortune only flows when a card actually left the deck
	if(count_cards() >= cards_before || !ishuman(user))
		return
	if(!COOLDOWN_FINISHED(src, luck_cooldown))
		return
	COOLDOWN_START(src, luck_cooldown, CHEATS_DECK_COOLDOWN)
	roll_fortune(user)

/// Rolls one small effect, good or bad, and applies it to the drawer.
/obj/item/toy/cards/deck/cheats/proc/roll_fortune(mob/living/user)
	var/static/list/fortune_table = list(
		"speed" = 18,
		"nerve" = 18,
		"heal" = 17,
		"windfall" = 17,
		"tangle" = 15,
		"fumble" = 15,
	)
	switch(pick_weight(fortune_table))
		if("speed")
			to_chat(user, span_notice("A burst of nerve! You feel quick on your feet."))
			user.add_movespeed_modifier(/datum/movespeed_modifier/cheats_deck_luck)
			addtimer(CALLBACK(user, TYPE_PROC_REF(/mob, remove_movespeed_modifier), /datum/movespeed_modifier/cheats_deck_luck), 5 SECONDS)
		if("nerve")
			to_chat(user, span_notice("Luck holds the door for you, just this once."))
			ADD_TRAIT(user, TRAIT_STUNIMMUNE, CHEATS_DECK_TRAIT_SOURCE)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cheats_deck_clear_stunimmune), user), 4 SECONDS)
		if("heal")
			to_chat(user, span_notice("Old aches ease, just for a moment."))
			user.adjustBruteLoss(-5)
			user.adjustStaminaLoss(-15)
		if("windfall")
			to_chat(user, span_notice("A coin turns up in your pocket you don't remember having."))
			var/obj/item/stack/spacecash/c10/found_coin = new(get_turf(user))
			user.put_in_hands(found_coin)
		if("tangle")
			to_chat(user, span_warning("Your shoelaces are tied together!"))
			user.Knockdown(2 SECONDS)
		if("fumble")
			var/obj/item/dropped = user.get_active_held_item()
			if(dropped)
				to_chat(user, span_warning("[dropped] slips right out of your grip."))
				user.dropItemToGround(dropped)

/// Removes the cheat's deck stun immunity from a user after its window ends.
/// Standalone since ADD/REMOVE_TRAIT need a stable source and target pair.
/proc/cheats_deck_clear_stunimmune(mob/living/user)
	if(!QDELETED(user))
		REMOVE_TRAIT(user, TRAIT_STUNIMMUNE, CHEATS_DECK_TRAIT_SOURCE)

/datum/movespeed_modifier/cheats_deck_luck
	multiplicative_slowdown = -0.5

#undef CHEATS_DECK_TRAIT_SOURCE
#undef CHEATS_DECK_COOLDOWN

// =========================================================================
// GREEN — The bottomless ration
// Sprite donor: /obj/item/reagent_containers/cup/glass/bottle/rum
// (rumbottle icon/inhand/worn, unmodified).
// =========================================================================

#define RATION_TRAIT_SOURCE "bottomless_ration"
#define RATION_PAIN_FREE_TIME (30 SECONDS)
#define RATION_SWIG_WINDOW (60 SECONDS)

/// A rum bottle with a false bottom that never actually runs dry: every
/// gulp is immediately topped back up. A swig heals a touch of brute and
/// grants 30s of pain-immunity; drinking it again inside a minute starts
/// stacking real drunkenness on top (it's still just rum).
/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration
	name = "the bottomless ration"
	desc = "A rum bottle with a false bottom that turned out not to be false enough."
	/// Recent swig timestamps, keyed by drinker ref, trimmed to the last minute.
	var/list/swig_log = list()

/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/attack(mob/living/target_mob, mob/living/user, obj/target)
	var/had_reagents = reagents && reagents.total_volume > 0
	var/gulp_amount = min(gulp_size, reagents?.total_volume || 0)
	. = ..()
	if(!had_reagents || !istype(target_mob) || !gulp_amount)
		return
	// Never runs empty — top it right back up to what it had before the swig.
	reagents.add_reagent(/datum/reagent/consumable/ethanol/rum, gulp_amount)
	grant_liquid_courage(target_mob)

/// Heals a touch of brute and grants a short pain-immunity window; tracks
/// repeat swigs inside a minute for flavor (the drunkenness itself stacks
/// naturally from the real rum being re-dosed each time).
/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/proc/grant_liquid_courage(mob/living/target_mob)
	target_mob.adjustBruteLoss(-3)
	ADD_TRAIT(target_mob, TRAIT_ANALGESIA, RATION_TRAIT_SOURCE)
	addtimer(CALLBACK(src, PROC_REF(clear_liquid_courage), target_mob), RATION_PAIN_FREE_TIME, TIMER_OVERRIDE|TIMER_UNIQUE)
	// Log the swig NOW — the repeat-swig warnings have to land as you drink,
	// not thirty seconds later when the courage wears off
	var/drinker_ref = REF(target_mob)
	var/list/recent = swig_log[drinker_ref]
	if(!recent)
		recent = list()
		swig_log[drinker_ref] = recent
	recent += world.time
	for(var/timestamp in recent)
		if(world.time - timestamp > RATION_SWIG_WINDOW)
			recent -= timestamp
	switch(length(recent))
		if(2)
			to_chat(target_mob, span_warning("The rum's really working now."))
		if(3 to INFINITY)
			to_chat(target_mob, span_userdanger("Third swig — you're in no shape to be trusted with the rigging."))

/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/proc/clear_liquid_courage(mob/living/target_mob)
	if(!QDELETED(target_mob))
		REMOVE_TRAIT(target_mob, TRAIT_ANALGESIA, RATION_TRAIT_SOURCE)

#undef RATION_SWIG_WINDOW
#undef RATION_PAIN_FREE_TIME
#undef RATION_TRAIT_SOURCE

// =========================================================================
// YELLOW — Marlinspike
// Subtypes the real meat hook (/obj/item/gun/magic/hook,
// code/modules/projectiles/guns/special/meat_hook.dm) so it inherits its
// icon, inhand sprites and the proven hook_and_move pull datum verbatim —
// tuned down per the design doc ("like the meat hook, tuned down").
// DEVIATION: doc suggested typepath /obj/item/marlinspike_hook; this
// subtypes /obj/item/gun/magic/hook/marlinspike instead so the pull
// mechanic (and sprite) come for free from the real thing.
// =========================================================================

#define MARLINSPIKE_MAX_RANGE 4

/// A boarding hook, tuned down from the meat hook: yanks a loose target to
/// you, or — if you hook something anchored — hauls you to it instead.
/obj/item/gun/magic/hook/marlinspike
	name = "marlinspike"
	desc = "A boarding hook on six meters of braided line. The knots have names."
	ammo_type = /obj/item/ammo_casing/magic/hook/marlinspike
	force = 10

/obj/item/gun/magic/hook/marlinspike/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// Range is capped short of the meat hook's full reach — refuse to even
/// fire past it rather than let the projectile travel and fizzle.
/obj/item/gun/magic/hook/marlinspike/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(get_dist(user, target) > MARLINSPIKE_MAX_RANGE)
		balloon_alert(user, "too far!")
		return
	return ..()

/obj/item/ammo_casing/magic/hook/marlinspike
	name = "hook"
	desc = "A hook."
	projectile_type = /obj/projectile/hook/marlinspike

/// Tuned-down hook projectile: less damage/stamina than the real meat hook,
/// and reverses the pull when it snags something anchored.
/obj/projectile/hook/marlinspike
	damage = 8
	stamina = 15
	armour_penetration = 30

/obj/projectile/hook/marlinspike/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..() // handles base hit effects, and pulls the target to the firer if it's not anchored
	if(!ismovable(target) || !isliving(firer))
		return
	var/atom/movable/anchor = target
	if(!anchor.anchored)
		return
	var/mob/living/puller = firer
	var/turf/landing = get_step(anchor, get_dir(anchor, puller))
	if(!landing)
		return
	anchor.visible_message(span_danger("The line snaps taut and [puller] is hauled toward [anchor]!"))
	var/datum/hook_and_move/reverse_pull = new
	reverse_pull.begin_pulling(anchor, puller, landing)

#undef MARLINSPIKE_MAX_RANGE

// =========================================================================
// YELLOW — Fence's eye
// Sprite donor: /obj/item/clothing/glasses/eyepatch (already stocked in
// this same cache's green table — a single-eye pirate accessory).
// DEVIATION: doc suggested a bespoke "jeweler's monocle" sprite, which
// doesn't exist in this codebase. Subtyping the eyepatch means it visually
// reads as a patch, not a lens — flagged for review; flip_eyepatch()'s
// cosmetic toggle (inherited) is left alone.
// The "examine anything for its trade value" beat is implemented on the
// existing double-examine ("look closer") extension point
// (COMSIG_MOB_EXAMINING_MORE, code/game/atom/atom_examine.dm) rather than a
// hook into every item's primary examine() — there is no generic per-user
// hook on the main single-look examine in this codebase, only per-atom
// signals, so double-examine is the closest real integration point.
// =========================================================================

#define FENCES_EYE_SQUINT_COOLDOWN (10 MINUTES)
#define FENCES_EYE_SQUINT_RANGE 9
#define FENCES_EYE_GLINT_DURATION (4 SECONDS)

/// A jeweler's monocle (reskinned eyepatch) that prices anything you look
/// twice at, and once every ten minutes can make the priciest thing in
/// view glint through crates and containers.
/obj/item/clothing/glasses/eyepatch/fences_eye
	name = "fence's eye"
	desc = "A jeweler's monocle on a chain of five different broken chains."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "monocle"
	base_icon_state = "monocle"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	// attack_self only works in-hand; the action button keeps "call the
	// market" reachable while the monocle is actually being worn
	actions_types = list(/datum/action/item_action/toggle)
	COOLDOWN_DECLARE(squint_cooldown)

/obj/item/clothing/glasses/eyepatch/fences_eye/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/glasses/eyepatch/fences_eye/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(slot & ITEM_SLOT_EYES)
		RegisterSignal(user, COMSIG_MOB_EXAMINING_MORE, PROC_REF(on_examine_more))

/obj/item/clothing/glasses/eyepatch/fences_eye/dropped(mob/user, silent = FALSE)
	. = ..()
	if(user)
		UnregisterSignal(user, COMSIG_MOB_EXAMINING_MORE)

/// Look-closer hook: appends the trader's current price for whatever the
/// wearer just double-examined.
/obj/item/clothing/glasses/eyepatch/fences_eye/proc/on_examine_more(mob/source, atom/examined, list/examine_list)
	SIGNAL_HANDLER
	if(!isitem(examined))
		return
	var/datum/shop_buyback/best = find_item_buyback(examined)
	if(!best)
		return
	examine_list += span_notice("Fence's eye: the trader [best.get_payment_text()] for this.")

/// The click-to-use "call the market" squint: outlines the most valuable
/// visible item (even through crates/lockers) for a few seconds.
/obj/item/clothing/glasses/eyepatch/fences_eye/attack_self(mob/user, modifiers)
	. = ..() // preserves the inherited eyepatch flip toggle
	squint(user)

/// Worn-slot route to the squint — the action button's default would call
/// attack_self, which also flips the eyepatch; go straight to the squint.
/obj/item/clothing/glasses/eyepatch/fences_eye/ui_action_click(mob/user, actiontype)
	squint(user)

/obj/item/clothing/glasses/eyepatch/fences_eye/proc/squint(mob/living/user)
	if(!COOLDOWN_FINISHED(src, squint_cooldown))
		balloon_alert(user, "the market's still quiet")
		return
	COOLDOWN_START(src, squint_cooldown, FENCES_EYE_SQUINT_COOLDOWN)
	var/list/candidates = list()
	for(var/atom/movable/nearby in view(FENCES_EYE_SQUINT_RANGE, user))
		if(isitem(nearby))
			candidates += nearby
		for(var/obj/item/stashed in nearby.contents)
			candidates += stashed
	var/obj/item/best
	var/best_value = 0
	for(var/obj/item/candidate as anything in candidates)
		var/value = item_trade_value_score(candidate)
		if(value > best_value)
			best_value = value
			best = candidate
	if(!best)
		balloon_alert(user, "nothing worth calling about")
		return
	to_chat(user, span_notice("Something glints through the clutter: [best]."))
	best.add_filter("fences_eye_glint", 2, list("type" = "outline", "color" = COLOR_GOLD, "size" = 1))
	addtimer(CALLBACK(src, PROC_REF(clear_glint), best), FENCES_EYE_GLINT_DURATION)

/obj/item/clothing/glasses/eyepatch/fences_eye/proc/clear_glint(obj/item/target)
	if(!QDELETED(target))
		target.remove_filter("fences_eye_glint")

#undef FENCES_EYE_GLINT_DURATION
#undef FENCES_EYE_SQUINT_RANGE
#undef FENCES_EYE_SQUINT_COOLDOWN

// =========================================================================
// RED — "Parley"
// Sprite donor: /obj/item/claymore/cutlass (code/game/objects/items/weaponry.dm)
// — a real physical cutlass with block_chance = 50 inherited straight from
// /obj/item/claymore ("blocks like one" comes for free).
// DEVIATION: doc suggested /obj/item/melee/parley_cutlass; this subtypes
// /obj/item/claymore/cutlass instead, both for the sprite and because the
// claymore family already has the block-chance/hit_reaction machinery this
// item's disarm odds hook into.
// =========================================================================

#define PARLEY_DISARM_COOLDOWN (8 SECONDS)
#define PARLEY_BASE_DISARM_CHANCE 20
#define PARLEY_STAGGER_BONUS 30
#define PARLEY_BLOCK_BONUS 20
#define PARLEY_BLOCK_WINDOW (3 SECONDS)

/// A cutlass that, on a lucky landed hit, can twist a held weapon out of
/// its target's grip and into the wielder's off-hand. Better odds if the
/// target is staggered, or if Parley itself just blocked something.
/obj/item/claymore/cutlass/parley
	name = "\"Parley\""
	desc = "A cutlass with a swept guard full of notches. They're not kills. They're confiscations."
	COOLDOWN_DECLARE(disarm_cooldown)
	/// world.time of the last successful block with this blade.
	var/last_block_time = 0

/obj/item/claymore/cutlass/parley/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// Tracks successful blocks (parent hit_reaction returns TRUE only when the
/// block chance roll succeeds) to feed the disarm odds bonus.
/obj/item/claymore/cutlass/parley/hit_reaction(mob/living/carbon/human/owner, atom/movable/hitby, attack_text = "the attack", final_block_chance = 0, damage = 0, attack_type = MELEE_ATTACK, damage_type = BRUTE)
	. = ..()
	if(.)
		last_block_time = world.time

/obj/item/claymore/cutlass/parley/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!isliving(target) || target == user || !isliving(user))
		return
	try_disarm(target, user)

/obj/item/claymore/cutlass/parley/proc/try_disarm(mob/living/victim, mob/living/user)
	if(!COOLDOWN_FINISHED(src, disarm_cooldown))
		return
	var/obj/item/held_weapon = victim.get_active_held_item()
	if(!held_weapon)
		return
	COOLDOWN_START(src, disarm_cooldown, PARLEY_DISARM_COOLDOWN)
	var/chance = PARLEY_BASE_DISARM_CHANCE
	if(victim.IsKnockdown() || HAS_TRAIT(victim, TRAIT_FLOORED))
		chance += PARLEY_STAGGER_BONUS
	if(last_block_time && (world.time - last_block_time <= PARLEY_BLOCK_WINDOW))
		chance += PARLEY_BLOCK_BONUS
	if(!prob(chance))
		balloon_alert(user, "failed to disarm")
		return
	if(!victim.dropItemToGround(held_weapon))
		return // TRAIT_NODROP or similar refused the drop
	visible_message(span_danger("[user] twists [held_weapon] out of [victim]'s grip with [src]!"))
	if(!user.put_in_hands(held_weapon))
		held_weapon.forceMove(get_turf(user))

#undef PARLEY_BLOCK_WINDOW
#undef PARLEY_BLOCK_BONUS
#undef PARLEY_STAGGER_BONUS
#undef PARLEY_BASE_DISARM_CHANCE
#undef PARLEY_DISARM_COOLDOWN

// =========================================================================
// RED — Dead man's compass
// Sprite donor: /obj/item/gps (code/game/objects/items/devices/gps.dm,
// "gps-c" icon_state) — its GPS-broadcast component is disabled below since
// the compass shouldn't put a live marker of the holder on anyone's map.
// DEVIATION: doc suggested /obj/item/deadmans_compass scanning "the deck
// (z-level)"; true world-wide/z-wide item scans have no existing spatial
// index to query cheaply in this codebase, so this scans a wide but bounded
// radius around the holder instead (throttled, not every tick) — flagged
// for a reviewer to size for real map dimensions. The needle itself is a
// matrix rotation of the existing GPS sprite (no new art needed).
// =========================================================================

#define COMPASS_SCAN_RANGE 60
#define COMPASS_SCAN_INTERVAL (15 SECONDS)
#define COMPASS_SULK_TIME (1.5 SECONDS)

/// Points toward the most valuable item within its scan radius (by trade
/// value); shaking it cycles to the next most valuable. Never broadcasts a
/// GPS signal of its own.
/obj/item/gps/deadmans_compass
	name = "dead man's compass"
	desc = "The needle is a splinter of bone. It doesn't point north. It never claimed to."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "brass_compass"
	gpstag = null
	/// Ranked candidates from the last scan, most valuable first.
	var/list/obj/item/tracked_candidates = list()
	/// Which ranked candidate the needle currently points at.
	var/candidate_index = 0
	var/last_scan_time = 0
	/// world.time until which the needle ignores updates after a shake.
	var/sulking_until = 0

/obj/item/gps/deadmans_compass/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	START_PROCESSING(SSobj, src)

/obj/item/gps/deadmans_compass/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/// The compass never phones home — no live tracker component.
/obj/item/gps/deadmans_compass/add_gps_component()
	return

/obj/item/gps/deadmans_compass/process(seconds_per_tick)
	var/turf/holder_turf = get_turf(src)
	if(!holder_turf)
		return
	if(world.time - last_scan_time >= COMPASS_SCAN_INTERVAL)
		last_scan_time = world.time
		rescan(holder_turf)
	point_needle(holder_turf)

/// Ranks every valuable item within range, cheapest last.
/obj/item/gps/deadmans_compass/proc/rescan(turf/center)
	var/list/found = list()
	for(var/obj/item/candidate in range(COMPASS_SCAN_RANGE, center))
		if(candidate == src || !isturf(candidate.loc))
			continue
		if(item_trade_value_score(candidate) <= 0)
			continue
		found += candidate
	sortTim(found, GLOBAL_PROC_REF(cmp_trade_value_asc)) // ascending; read back-to-front for richest-first
	tracked_candidates = found
	if(candidate_index >= length(tracked_candidates))
		candidate_index = 0

/// Rotates the needle (a matrix transform on the existing sprite, no new
/// art) toward the currently tracked candidate.
/obj/item/gps/deadmans_compass/proc/point_needle(turf/holder_turf)
	if(world.time < sulking_until)
		return
	var/target_count = length(tracked_candidates)
	if(!target_count)
		return
	var/obj/item/target = tracked_candidates[target_count - candidate_index]
	if(QDELETED(target))
		return
	var/turf/target_turf = get_turf(target)
	if(!target_turf || target_turf == holder_turf)
		return
	// get_angle() types its args /atom/movable — turfs get runtime-filtered to
	// null and it always returns 0. The raw-coords variant takes plain numbers.
	var/angle = get_angle_raw(holder_turf.x, holder_turf.y, 0, 0, target_turf.x, target_turf.y, 0, 0)
	transform = turn(matrix(), -angle)

/// Shaking cycles to the next most valuable target and briefly "sulks".
/obj/item/gps/deadmans_compass/attack_self(mob/user, modifiers)
	. = ..()
	if(!length(tracked_candidates))
		balloon_alert(user, "the needle just drifts")
		return
	candidate_index = (candidate_index + 1) % length(tracked_candidates)
	sulking_until = world.time + COMPASS_SULK_TIME
	balloon_alert(user, "the needle sulks, then settles")

#undef COMPASS_SULK_TIME
#undef COMPASS_SCAN_INTERVAL
#undef COMPASS_SCAN_RANGE

// =========================================================================
// RED — No Quarter
// Sprite donor: /obj/item/gun/ballistic/shotgun/musket (the "Donk Co.
// Musket" — donk_musket icon/inhand/worn, single-shot boltloading frame,
// code/modules/projectiles/guns/ballistic/shotgun.dm). Its existing
// single-shot-then-rack loop is reused wholesale; only the reload is slowed
// down and re-costed.
// DEVIATION: doc suggested /obj/item/gun/ballistic/no_quarter loading "raw
// gunpowder and a metal slug." Rather than bolt a two-material crafting
// recipe onto the ballistic reload flow, this uses one bespoke pre-made
// cartridge item ("gunpowder and a slug, twisted into a paper cartridge")
// as the thing you feed it — same flavor, one consumed item instead of two,
// and it reuses the real ammo/chambering system unmodified. Wall breaching
// calls turf/closed/wall/dismantle_wall() directly (the same call the
// wall_smasher element uses) rather than trying to fight obj_integrity math
// through demolition_mod, since walls aren't /obj instances.
// =========================================================================

#define NO_QUARTER_RELOAD_TIME (1 MINUTES)
#define NO_QUARTER_THROW_RANGE 6

/// One shot: breaches a (non-reinforced) wall outright, or throws a person
/// six tiles. A full minute, at a bench, to load the next cartridge.
/obj/item/gun/ballistic/shotgun/musket/no_quarter
	name = "\"No Quarter\""
	desc = "A flintlock hand cannon dressed up as a boltloading musket. The bore is wide enough to be a design statement."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "no_quarter"
	// base musket sets inhand_icon_state = "donk_musket" — override so the
	// custom states in the files below are actually used. inhand_x/y_dimension
	// stay inherited at 64 from the shotgun base, matching the 64x64 files.
	inhand_icon_state = "no_quarter"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_64x_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_64x_righthand.dmi'
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/single/no_quarter
	/// Whether the slow reload ritual is currently in progress.
	var/priming = FALSE

/obj/item/gun/ballistic/shotgun/musket/no_quarter/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// Gates the normal ammo-loading flow behind a minute-long bench ritual —
/// once that's done, the real (unmodified) chambering logic takes over.
/obj/item/gun/ballistic/shotgun/musket/no_quarter/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!isammocasing(tool) && !istype(tool, /obj/item/ammo_box))
		return ..()
	if(priming)
		return ITEM_INTERACT_BLOCKING
	if(chambered?.loaded_projectile)
		balloon_alert(user, "already loaded!")
		return ITEM_INTERACT_BLOCKING
	if(!(locate(/obj/structure/table) in range(1, user)))
		balloon_alert(user, "needs a bench!")
		return ITEM_INTERACT_BLOCKING
	priming = TRUE
	balloon_alert(user, "packing the charge...")
	var/loaded = do_after(user, NO_QUARTER_RELOAD_TIME, src)
	priming = FALSE
	if(!loaded)
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/item/ammo_box/magazine/internal/shot/single/no_quarter
	name = "\"No Quarter\" chamber"
	ammo_type = /obj/item/ammo_casing/shotgun/no_quarter

/// "Gunpowder and a metal slug, twisted shut" — the one cartridge type
/// No Quarter feeds on, standing in for a two-material craft recipe.
/// Subtypes the real shotgun slug casing (icon/caliber/materials inherited
/// verbatim) and just swaps the projectile it fires.
/obj/item/ammo_casing/shotgun/no_quarter
	name = "heavy cartridge"
	desc = "A paper cartridge bulging with gunpowder and a single lead slug, twisted shut."
	projectile_type = /obj/projectile/bullet/shotgun_slug/no_quarter

/// A slug that breaches walls outright or launches whoever it hits.
/// Subtypes the real 12g shotgun slug projectile (icon/base damage
/// inherited) and adds turf-targeting plus the breach/knockback follow-up.
/obj/projectile/bullet/shotgun_slug/no_quarter
	name = "heavy slug"
	desc = "A lead slug the size of a thumb."
	can_hit_turfs = TRUE

/obj/projectile/bullet/shotgun_slug/no_quarter/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	if(isliving(target))
		var/mob/living/victim = target
		var/atom/throw_target = get_ranged_target_turf(victim, angle2dir(angle), NO_QUARTER_THROW_RANGE)
		victim.throw_at(throw_target, NO_QUARTER_THROW_RANGE, 3, firer, force = MOVE_FORCE_EXTREMELY_STRONG)
		victim.Knockdown(2 SECONDS)
		return
	if(!iswallturf(target))
		return
	var/turf/closed/wall/wall_target = target
	if(istype(wall_target, /turf/closed/wall/r_wall))
		playsound(wall_target, 'sound/effects/bang.ogg', 50, TRUE)
		wall_target.balloon_alert(firer, "too tough!")
		return
	playsound(wall_target, 'sound/effects/meteorimpact.ogg', 100, TRUE)
	wall_target.dismantle_wall(devastated = TRUE)

#undef NO_QUARTER_THROW_RANGE
#undef NO_QUARTER_RELOAD_TIME

#undef TRADE_VALUE_VOUCHER_WEIGHT
