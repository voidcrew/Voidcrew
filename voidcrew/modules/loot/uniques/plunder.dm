/**
 * # Plunder Uniques: the quartermaster's strongbox
 *
 * Seven one-of-a-kind prizes for the PLUNDER uniques shelf (see
 * voidcrew/modules/loot/themes/plunder.dm, the `loot_uniques` shelf on
 * /datum/loot_theme/plunder, read by the quartermaster's strongbox).
 *
 * Sprites live in voidcrew/modules/loot/icons/uniques.dmi (item states) with
 * in-hands in uniques_lefthand.dmi / uniques_righthand.dmi and the oversized
 * in-hands in uniques_64x_*hand.dmi. Where an item subtypes something that
 * already had good art (the cutlass in-hands, the musket in-hands) the parent's
 * states are left alone on purpose.
 *
 * Every item here is a genuine one-off: Initialize() always adds
 * TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so the Helios pattern stamp
 * (and any future duplicator) refuses to copy it, and caches roll without
 * replacement so one strongbox can never pay the same prize twice.
 */

// =========================================================================
// Shared helpers: what a thing is worth, in this round's economy.
//
// Two independent sources, checked in this order:
//   1. A live outpost buyback (voidcrew/modules/trade/shop_buyback.dm), scanned
//      across every trader outpost on the overmap (GLOB.trader_outposts). This
//      is a real "the trader is buying this right now" price, and vouchers are
//      weighted heavily above credits since they can't be farmed safely.
//   2. The cargo export ledger (/datum/export, code/modules/cargo/exports.dm).
//      What the cargo shuttle pays for it. Far broader than the buyback list:
//      most manufactured goods, materials, tools, organs, fish and salvage have
//      an export datum, which is why the fence's eye prices nearly anything.
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

/**
 * What the cargo shuttle would pay for an item, in credits. Zero if no export
 * datum covers it.
 *
 * Deliberately priced off init_cost (apply_elastic = FALSE) rather than the
 * live elastic price: this is an appraisal, not a sale, and a number that
 * drifts every time somebody sells a crate of iron would read as broken.
 */
/proc/item_export_value(obj/item/checked_item)
	if(!istype(checked_item))
		return 0
	// VOIDCREW EDIT: setupExports() is gone - GLOB.exports_list is a GLOBAL_LIST_INIT built by
	// init_Exports() (code/_globalvars/lists/cargo.dm), so it is always populated on first read.
	for(var/datum/export/export as anything in GLOB.exports_list)
		if(!export.applies_to(checked_item, FALSE, list(EXPORT_MARKET_STATION)))
			continue
		return export.get_cost(checked_item, FALSE)
	return 0

/// A single comparable number for an item's trade value (vouchers dominate
/// credits, credits beat a plain export price). Zero if it's worthless.
/proc/item_trade_value_score(obj/item/checked_item)
	var/datum/shop_buyback/best = find_item_buyback(checked_item)
	if(best)
		return best.pay_vouchers * TRADE_VALUE_VOUCHER_WEIGHT + best.pay_credits
	return item_export_value(checked_item)

/// One line of plain English about what an item is worth, or null if nothing.
/proc/item_trade_value_text(obj/item/checked_item)
	var/datum/shop_buyback/best = find_item_buyback(checked_item)
	if(best)
		return "a trader [best.get_payment_text()] for this"
	var/export_value = item_export_value(checked_item)
	if(export_value > 0)
		return "cargo pays about [export_value] cr for this"
	return null

// =========================================================================
// GREEN: Cheat's deck
// A real 52-card deck (subtypes /obj/item/toy/cards/deck) with its own art in
// uniques.dmi. The parent picks its icon_state from the card count, so the
// four count states are mirrored below rather than fought with.
// deckstyle stays "nanotrasen" on purpose: the singlecards drawn out of the
// deck read their own states out of the stock playing_cards.dmi, so a custom
// deckstyle would leave every drawn card with a missing sprite.
// =========================================================================

#define CHEATS_DECK_COOLDOWN (30 SECONDS)
#define CHEATS_DECK_TRAIT_SOURCE "cheats_deck_luck"

/// A boost/jinx table drawn from on every card pulled from the deck, on a
/// cooldown. ~70% boon / ~30% jinx per the design doc.
/obj/item/toy/cards/deck/cheats
	name = "cheat's deck"
	desc = "Fifty-two cards, all of them marked. Drawing a card does something small to whoever drew it, good or bad, at most once every 30 seconds."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "cheats_deck_full"
	COOLDOWN_DECLARE(luck_cooldown)

/obj/item/toy/cards/deck/cheats/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// The parent sets icon_state from the card count against the stock deck
/// sheet ("deck_nanotrasen_full" and friends); re-point those four cases at
/// this deck's own art after it has run.
/obj/item/toy/cards/deck/cheats/update_icon_state()
	. = ..()
	switch(count_cards())
		if(27 to INFINITY)
			icon_state = "cheats_deck_full"
		if(11 to 27)
			icon_state = "cheats_deck_half"
		if(1 to 11)
			icon_state = "cheats_deck_low"
		else
			icon_state = "cheats_deck_empty"

/obj/item/toy/cards/deck/cheats/attack_hand(mob/living/user, list/modifiers, flip_card = FALSE)
	var/cards_before = count_cards()
	. = ..()
	// The parent can refuse the draw (no dexterity, telekinesis, etc),
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
			to_chat(user, span_notice("You feel quick on your feet for the next 5 seconds."))
			user.add_movespeed_modifier(/datum/movespeed_modifier/cheats_deck_luck)
			addtimer(CALLBACK(user, TYPE_PROC_REF(/mob, remove_movespeed_modifier), /datum/movespeed_modifier/cheats_deck_luck), 5 SECONDS)
		if("nerve")
			to_chat(user, span_notice("You feel steady. Nothing can knock you down for the next 4 seconds."))
			ADD_TRAIT(user, TRAIT_STUNIMMUNE, CHEATS_DECK_TRAIT_SOURCE)
			addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cheats_deck_clear_stunimmune), user), 4 SECONDS)
		if("heal")
			to_chat(user, span_notice("Old aches ease off."))
			user.adjust_brute_loss(-5)
			user.adjust_stamina_loss(-15)
		if("windfall")
			to_chat(user, span_notice("You find a coin in your pocket you don't remember putting there."))
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
// GREEN: The bottomless ration
// Sprite donor: the rum bottle ("rumbottle" out of the stock bottles.dmi).
//
// FIXED: this used to subtype the plain /cup/glass/bottle, which is the blank
// glass bottle, no list_reagents and the anonymous "glassbottle" sprite, so
// every one that ever rolled spawned empty and the refill code had nothing to
// top up. The rum bottle's icon_state and starting reagents are now set here
// explicitly rather than re-parenting, which would have changed the typepath
// the loot table spawns.
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
	desc = "A rum bottle with a false bottom. Every swig fills straight back up. A drink patches a scrape and keeps pain off you for 30 seconds, but it's still rum, and it stacks."
	icon_state = "rumbottle"
	list_reagents = list(/datum/reagent/consumable/ethanol/rum = 100)
	drink_type = ALCOHOL
	/// Recent swig timestamps, keyed by drinker ref, trimmed to the last minute.
	var/list/swig_log = list()

/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

// Was an attack() override, which chained onto /obj/item/reagent_containers/cup/attack -
// the proc that used to do the drinking. Upstream deleted cup/attack and moved the swig
// into cup/try_drink(), called from cup/interact_with_atom(), which base_item_interaction
// runs BEFORE the attack chain: interact_with_atom returns ITEM_INTERACT_SUCCESS, so
// melee_attack_chain never reaches attackby and attack() is dead code on a drink. The
// bottle stopped topping itself up (and stopped granting courage) the moment that landed.
// try_drink() is the direct replacement hook: one call per gulp, self-drink and
// force-feeding alike, and it reports whether the gulp actually went down.
//
// Click trace, clicking a carbon with this bottle in hand:
//   melee_attack_chain -> target.base_item_interaction -> (combat mode gates tool_act
//   only, and rum has no tool_behaviour) -> /mob/living/item_interaction (NONE) ->
//   tool.interact_with_atom -> cup/interact_with_atom -> isliving -> try_drink -> HERE.
//   Self-drink and feeding both land here; right-click routes through
//   interact_with_atom_secondary -> try_splash, which the bottle refuses (glassbottle.dm),
//   so a right-click still bottles them over the head instead of drinking.
/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/try_drink(mob/living/target_mob, mob/living/user)
	var/had_reagents = reagents && reagents.total_volume > 0
	var/gulp_amount = min(gulp_size, reagents?.total_volume || 0)
	. = ..()
	// A blocked swig (mouth covered, interrupted feed, empty bottle) transferred nothing,
	// so there is nothing to top back up - refilling there would overfill the bottle.
	if(!(. & ITEM_INTERACT_SUCCESS))
		return
	if(!had_reagents || !istype(target_mob) || !gulp_amount)
		return
	// Never runs empty, top it right back up to what it had before the swig.
	reagents.add_reagent(/datum/reagent/consumable/ethanol/rum, gulp_amount)
	grant_liquid_courage(target_mob)

/// Heals a touch of brute and grants a short pain-immunity window; tracks
/// repeat swigs inside a minute for flavor (the drunkenness itself stacks
/// naturally from the real rum being re-dosed each time).
/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/proc/grant_liquid_courage(mob/living/target_mob)
	target_mob.adjust_brute_loss(-3)
	ADD_TRAIT(target_mob, TRAIT_ANALGESIA, RATION_TRAIT_SOURCE)
	addtimer(CALLBACK(src, PROC_REF(clear_liquid_courage), target_mob), RATION_PAIN_FREE_TIME, TIMER_OVERRIDE|TIMER_UNIQUE)
	// Log the swig NOW: the repeat-swig warnings have to land as you drink,
	// not thirty seconds later when the courage wears off
	var/drinker_ref = REF(target_mob)
	var/list/recent = swig_log[drinker_ref]
	if(!recent)
		recent = list()
		swig_log[drinker_ref] = recent
	// Rebuilt rather than trimmed in place: removing entries from a list while
	// iterating it skips the element after each removal.
	var/list/still_fresh = list()
	for(var/timestamp in recent)
		if(world.time - timestamp <= RATION_SWIG_WINDOW)
			still_fresh += timestamp
	still_fresh += world.time
	swig_log[drinker_ref] = still_fresh
	switch(length(still_fresh))
		if(2)
			to_chat(target_mob, span_warning("The rum's really working now."))
		if(3 to INFINITY)
			to_chat(target_mob, span_userdanger("Third swig, and you're properly drunk now."))

/obj/item/reagent_containers/cup/glass/bottle/bottomless_ration/proc/clear_liquid_courage(mob/living/target_mob)
	if(!QDELETED(target_mob))
		REMOVE_TRAIT(target_mob, TRAIT_ANALGESIA, RATION_TRAIT_SOURCE)

#undef RATION_SWIG_WINDOW
#undef RATION_PAIN_FREE_TIME
#undef RATION_TRAIT_SOURCE

// =========================================================================
// YELLOW: Marlinspike
// Subtypes the real meat hook (/obj/item/gun/magic/hook,
// code/modules/projectiles/guns/special/meat_hook.dm) so it inherits its
// in-hand sprites and the proven hook_and_move pull datum verbatim, tuned
// down. Its own ground sprite lives in uniques.dmi.
//
// FIXED: the "haul yourself to something bolted down" leg never fired. Walls
// are /turf, not /atom/movable, so the ismovable(target) guard threw away the
// single most obvious thing to hook, and turfs are exactly what the
// projectile reports when it stops against a wall (see /atom/bullet_act ->
// on_hit). Both legs now report what happened.
// =========================================================================

#define MARLINSPIKE_MAX_RANGE 4

/// A boarding hook, tuned down from the meat hook: yanks a loose target to
/// you, or (if you hook something anchored) hauls you to it instead.
/obj/item/gun/magic/hook/marlinspike
	name = "marlinspike"
	desc = "A boarding hook on braided line, good for 4 tiles. Hook something loose and it comes to you. Hook a wall, a floor tile, or anything bolted down, and you go to it."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "marlinspike"
	ammo_type = /obj/item/ammo_casing/magic/hook/marlinspike
	force = 10

/obj/item/gun/magic/hook/marlinspike/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/// Range is capped short of the meat hook's full reach, refuse to even
/// fire past it rather than let the projectile travel and fizzle.
/obj/item/gun/magic/hook/marlinspike/process_fire(atom/target, mob/living/user, message = TRUE, params = null, zone_override = "", bonus_spread = 0)
	if(get_dist(user, target) > MARLINSPIKE_MAX_RANGE)
		balloon_alert(user, "too far! (4 tiles)")
		return
	return ..()

/obj/item/ammo_casing/magic/hook/marlinspike
	name = "hook"
	desc = "A hook."
	projectile_type = /obj/projectile/hook/marlinspike

/// Tuned-down hook projectile: less damage/stamina than the real meat hook,
/// and reverses the pull when it snags something that won't move.
/obj/projectile/hook/marlinspike
	damage = 8
	stamina = 15
	armour_penetration = 30
	/// Lets a deliberate click on open floor register as a hook point too,
	/// instead of the line sailing through it.
	can_hit_turfs = TRUE

/obj/projectile/hook/marlinspike/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..() // handles base hit effects, and pulls the target to the firer if it's loose
	if(!isliving(firer))
		return
	var/mob/living/puller = firer
	// A movable that isn't anchored was already yanked in by the parent.
	if(ismovable(target))
		var/atom/movable/movable_target = target
		if(!movable_target.anchored)
			return
	else if(!isturf(target))
		return
	// Anything left is a wall or something bolted down: reel the firer in.
	var/turf/landing = get_step(target, get_dir(target, puller))
	if(!landing)
		balloon_alert(puller, "nothing to land on!")
		return
	if(landing == get_turf(puller))
		balloon_alert(puller, "already up against it")
		return
	if(landing.is_blocked_turf(TRUE, puller))
		balloon_alert(puller, "no room to land!")
		return
	// The hook immobilizes its firer for a fraction of a second on the way out
	// so nobody can walk out from under their own line; drop that now, the
	// same way the parent does when its own pull lands.
	REMOVE_TRAIT(puller, TRAIT_IMMOBILIZED, REF(src))
	puller.visible_message(
		span_danger("The line snaps taut and [puller] is hauled toward [target]!"),
		span_notice("The hook bites, the line snaps taut, and you're hauled in."),
	)
	var/datum/hook_and_move/reverse_pull = new
	reverse_pull.begin_pulling(target, puller, landing)

#undef MARLINSPIKE_MAX_RANGE

// =========================================================================
// YELLOW: Fence's eye
// A jeweler's monocle with its own art in uniques.dmi / uniques_worn.dmi.
// The "examine anything for its trade value" beat rides the double-examine
// ("look closer") extension point (COMSIG_MOB_EXAMINING_MORE,
// code/game/atom/atom_examine.dm). There is no generic per-user hook on the
// single-look examine in this codebase, only per-atom signals.
//
// FIXED: it used to price things against live outpost buybacks only, which is
// a list of maybe eighty ores and organs, so almost everything came back
// worthless. It now falls back to the cargo export ledger, which covers most
// of the game. The squint also reaches into sealed crates and lockers (and
// fills lazily-populated loot caches first, or there is nothing in them to
// find), reports the top three finds instead of one, and outlines the
// container rather than an item nobody can see.
// =========================================================================

#define FENCES_EYE_SQUINT_COOLDOWN (2 MINUTES)
#define FENCES_EYE_SQUINT_RANGE 9
#define FENCES_EYE_GLINT_DURATION (8 SECONDS)
#define FENCES_EYE_MAX_FINDS 3
#define FENCES_EYE_SCAN_CAP 300

/// A jeweler's monocle that prices anything you look twice at, and on a
/// two-minute cooldown picks out the most valuable things nearby, including
/// what's sitting inside closed crates and lockers.
/obj/item/clothing/glasses/eyepatch/fences_eye
	name = "fence's eye"
	desc = "A jeweler's monocle on a chain cobbled together from five other chains. Look twice at anything to see what it sells for. Once every 2 minutes it can pick out the three best things within 9 tiles, sealed containers included."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "monocle"
	base_icon_state = "monocle"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	// The squint lives on the action button, not attack_self: an in-hand
	// click flips the patch (inherited behavior) and must not burn the
	// cooldown. Item actions are granted in the hands as well as in the eye
	// slot, so the button covers both cases.
	actions_types = list(/datum/action/item_action/toggle)
	COOLDOWN_DECLARE(squint_cooldown)

/obj/item/clothing/glasses/eyepatch/fences_eye/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/glasses/eyepatch/fences_eye/examine(mob/user)
	. = ..()
	if(COOLDOWN_FINISHED(src, squint_cooldown))
		. += span_notice("The lens is clear. The squint is ready.")
	else
		. += span_warning("The lens is still fogged. [DisplayTimeText(COOLDOWN_TIMELEFT(src, squint_cooldown))] until you can squint again.")

/obj/item/clothing/glasses/eyepatch/fences_eye/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(slot & ITEM_SLOT_EYES)
		RegisterSignal(user, COMSIG_MOB_EXAMINING_MORE, PROC_REF(on_examine_more), override = TRUE)

/obj/item/clothing/glasses/eyepatch/fences_eye/dropped(mob/user, silent = FALSE)
	. = ..()
	if(user)
		UnregisterSignal(user, COMSIG_MOB_EXAMINING_MORE)

/// Look-closer hook: appends what the thing is worth to whoever is wearing it.
/obj/item/clothing/glasses/eyepatch/fences_eye/proc/on_examine_more(mob/source, atom/examined, list/examine_list)
	SIGNAL_HANDLER
	if(!isitem(examined))
		return
	var/value_text = item_trade_value_text(examined)
	if(!value_text)
		examine_list += span_notice("Fence's eye: nobody's buying this.")
		return
	examine_list += span_notice("Fence's eye: [value_text].")

/// The click-to-use "call the market" squint. Hung off the action button
/// rather than attack_self: attack_self is the parent eyepatch's cosmetic
/// flip, and flipping the patch must not burn the cooldown.
/obj/item/clothing/glasses/eyepatch/fences_eye/ui_action_click(mob/user, actiontype)
	squint(user)

/obj/item/clothing/glasses/eyepatch/fences_eye/proc/squint(mob/living/user)
	if(!COOLDOWN_FINISHED(src, squint_cooldown))
		balloon_alert(user, "still fogged")
		to_chat(user, span_warning("[src] needs another [DisplayTimeText(COOLDOWN_TIMELEFT(src, squint_cooldown))] before it can squint again."))
		return
	COOLDOWN_START(src, squint_cooldown, FENCES_EYE_SQUINT_COOLDOWN)

	var/list/obj/item/candidates = list()
	for(var/atom/movable/nearby in view(FENCES_EYE_SQUINT_RANGE, user))
		if(length(candidates) >= FENCES_EYE_SCAN_CAP)
			break
		// Skip the living: a mob's contents are its worn gear and its organs,
		// and neither is treasure the eye should be pricing up.
		if(isliving(nearby))
			continue
		if(isitem(nearby))
			candidates += nearby
		// Loot caches don't roll their contents until something opens them, so
		// there is literally nothing inside to find until we ask for it. Same
		// hand-off the manufactorio unloader uses.
		if(istype(nearby, /obj/structure/closet))
			var/obj/structure/closet/container = nearby
			if(!container.contents_initialized)
				container.contents_initialized = TRUE
				container.PopulateContents()
				SEND_SIGNAL(container, COMSIG_CLOSET_CONTENTS_INITIALIZED)
		// get_all_contents() includes the thing itself, which an item container
		// would already have contributed above.
		for(var/obj/item/stashed in nearby.get_all_contents())
			if(stashed == nearby)
				continue
			candidates += stashed

	var/list/obj/item/finds = list()
	var/list/values = list()
	for(var/obj/item/candidate as anything in candidates)
		var/value = item_trade_value_score(candidate)
		if(value <= 0)
			continue
		// Straight insertion sort into a list that never grows past three.
		var/placed = FALSE
		for(var/i in 1 to length(finds))
			if(value <= values[i])
				continue
			finds.Insert(i, candidate)
			values.Insert(i, value)
			placed = TRUE
			break
		if(!placed && length(finds) < FENCES_EYE_MAX_FINDS)
			finds += candidate
			values += value
		if(length(finds) > FENCES_EYE_MAX_FINDS)
			finds.Cut(FENCES_EYE_MAX_FINDS + 1)
			values.Cut(FENCES_EYE_MAX_FINDS + 1)

	if(!length(finds))
		balloon_alert(user, "nothing worth a thing")
		to_chat(user, span_warning("Nothing within [FENCES_EYE_SQUINT_RANGE] tiles is worth selling."))
		return

	to_chat(user, span_notice("You squint through [src]. Best of what's within [FENCES_EYE_SQUINT_RANGE] tiles:"))
	for(var/obj/item/find as anything in finds)
		var/atom/holder = find
		// Walk out to whatever is actually on the floor, outlining an item
		// sealed inside a crate would light up something nobody can see.
		while(holder.loc && !isturf(holder.loc))
			holder = holder.loc
		var/where = (holder == find) ? "" : " (inside [holder])"
		to_chat(user, span_notice("- [find][where]: [item_trade_value_text(find) || "worth something"]."))
		holder.add_filter("fences_eye_glint", 2, list("type" = "outline", "color" = COLOR_GOLD, "size" = 1))
		addtimer(CALLBACK(src, PROC_REF(clear_glint), holder), FENCES_EYE_GLINT_DURATION)

/obj/item/clothing/glasses/eyepatch/fences_eye/proc/clear_glint(atom/target)
	if(!QDELETED(target))
		target.remove_filter("fences_eye_glint")

#undef FENCES_EYE_SCAN_CAP
#undef FENCES_EYE_MAX_FINDS
#undef FENCES_EYE_GLINT_DURATION
#undef FENCES_EYE_SQUINT_RANGE
#undef FENCES_EYE_SQUINT_COOLDOWN

// =========================================================================
// RED: "Parley"
// Subtypes /obj/item/claymore/cutlass for the block-chance and hit_reaction
// machinery (block_chance = 50 comes down from /obj/item/claymore); its ground
// sprite is its own, its in-hands stay the stock cutlass ones.
//
// CHANGED: the disarm used to be a 20% base roll with bonuses for hitting a
// staggered target or following up a block, which meant it almost never fired,
// and the stagger bonus only paid out against people who were already dropping
// their weapon from being knocked over. It is now one flat roll on any landed
// hit.
// =========================================================================

#define PARLEY_DISARM_COOLDOWN (8 SECONDS)
#define PARLEY_DISARM_CHANCE 65

/// A cutlass that, on a landed hit, usually twists a held weapon out of its
/// target's grip and into the wielder's hands.
/obj/item/claymore/cutlass/parley
	name = "\"Parley\""
	desc = "A cutlass with a swept guard full of notches. A hit has a 65% chance to twist whatever the target is holding out of their hand, once every 8 seconds."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "parley"
	COOLDOWN_DECLARE(disarm_cooldown)

/obj/item/claymore/cutlass/parley/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/claymore/cutlass/parley/examine(mob/user)
	. = ..()
	if(COOLDOWN_FINISHED(src, disarm_cooldown))
		. += span_notice("The guard is set. The next hit can disarm.")
	else
		. += span_warning("[DisplayTimeText(COOLDOWN_TIMELEFT(src, disarm_cooldown))] before it can disarm again.")

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
	if(!prob(PARLEY_DISARM_CHANCE))
		balloon_alert(user, "grip held!")
		return
	if(!victim.dropItemToGround(held_weapon))
		balloon_alert(user, "it won't come loose!")
		return // TRAIT_NODROP or similar refused the drop
	visible_message(span_danger("[user] twists [held_weapon] out of [victim]'s grip with [src]!"))
	if(!user.put_in_hands(held_weapon))
		held_weapon.forceMove(get_turf(user))

#undef PARLEY_DISARM_CHANCE
#undef PARLEY_DISARM_COOLDOWN

// =========================================================================
// RED: "Heave-Ho"
// The quartermaster's other job: moving the cargo. A stevedore's harness that
// shoulders a whole closed crate, locker or cache so it can be walked out of a
// ruin instead of emptied into a backpack one handful at a time, and swung at
// whoever objects.
//
// Replaces the dead man's compass, which pointed at the highest-value item in
// a radius and was unreadable in play.
// =========================================================================

#define HEAVE_HO_LIFT_TIME (3 SECONDS)
#define HEAVE_HO_SLOWDOWN 0.6
#define HEAVE_HO_SWING_COOLDOWN (15 SECONDS)
#define HEAVE_HO_SWING_KNOCKBACK 3
#define HEAVE_HO_SWING_FORCE 22

/// A carrying harness that shoulders one closed container at a time.
/obj/item/heave_ho
	name = "\"Heave-Ho\""
	desc = "A stevedore's harness and hook, worn shiny at the straps. Click a closed crate, locker or cache to shoulder it after 3 seconds; click the harness again to set it down. Carrying one slows you down, and a loaded swing knocks people back 3 tiles."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "heave_ho"
	inhand_icon_state = "heave_ho"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_righthand.dmi'
	w_class = WEIGHT_CLASS_NORMAL
	force = 8
	throwforce = 8
	attack_verb_continuous = list("hooks", "swings at", "clouts")
	attack_verb_simple = list("hook", "swing at", "clout")
	hitsound = 'sound/items/weapons/smash.ogg'
	item_flags = SLOWS_WHILE_IN_HAND
	/// The container currently slung on the harness, if any.
	var/obj/structure/closet/carried
	COOLDOWN_DECLARE(swing_cooldown)

/obj/item/heave_ho/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/heave_ho/Destroy()
	// Put the cargo back on the floor before the harness goes, or it gets
	// deleted along with whatever the crew was hauling.
	if(carried)
		var/obj/structure/closet/dropping = carried
		carried = null
		dropping.forceMove(drop_location() || get_turf(src))
	return ..()

/**
 * The one release path. Setting the container down, having it forced out, and
 * having it deleted out from under the harness all end up here, so the weight,
 * the slowdown and the sprite can only ever be undone once and can't be
 * stranded by a container that stops existing.
 */
/obj/item/heave_ho/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != carried)
		return
	carried = null
	slowdown = 0
	force = initial(force)
	update_weight_class(initial(w_class))
	update_appearance()
	if(ismob(loc))
		var/mob/holder = loc
		holder.update_equipment_speed_mods()

/obj/item/heave_ho/examine(mob/user)
	. = ..()
	if(carried)
		. += span_notice("[carried] is slung on the hook. Click the harness to set it down.")
	if(!COOLDOWN_FINISHED(src, swing_cooldown))
		. += span_warning("[DisplayTimeText(COOLDOWN_TIMELEFT(src, swing_cooldown))] before another loaded swing.")

/obj/item/heave_ho/update_icon_state()
	. = ..()
	icon_state = carried ? "heave_ho_loaded" : "heave_ho"

/obj/item/heave_ho/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	user.update_equipment_speed_mods()

/obj/item/heave_ho/dropped(mob/user, silent = FALSE)
	. = ..()
	user?.update_equipment_speed_mods()

/obj/item/heave_ho/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/structure/closet))
		return NONE
	var/obj/structure/closet/container = interacting_with
	if(carried)
		balloon_alert(user, "already carrying [carried]!")
		return ITEM_INTERACT_BLOCKING
	if(container.opened)
		balloon_alert(user, "close it first!")
		return ITEM_INTERACT_BLOCKING
	if(container.anchored)
		balloon_alert(user, "it's bolted down!")
		return ITEM_INTERACT_BLOCKING
	if(locate(/mob/living) in container)
		balloon_alert(user, "something's alive in there!")
		return ITEM_INTERACT_BLOCKING

	balloon_alert(user, "hooking on...")
	if(!do_after(user, HEAVE_HO_LIFT_TIME, container))
		return ITEM_INTERACT_BLOCKING
	// Everything can change over three seconds of hauling.
	if(QDELETED(container) || carried || container.opened || container.anchored)
		balloon_alert(user, "lost your grip!")
		return ITEM_INTERACT_BLOCKING

	carried = container
	container.forceMove(src)
	update_weight_class(WEIGHT_CLASS_BULKY)
	slowdown = HEAVE_HO_SLOWDOWN
	force = HEAVE_HO_SWING_FORCE
	user.update_equipment_speed_mods()
	update_appearance()
	user.visible_message(
		span_notice("[user] hooks [container] onto [src] and shoulders it."),
		span_notice("You shoulder [container]. It's heavy going, but it's coming with you."),
	)
	playsound(src, 'sound/items/handling/toolbox/toolbox_pickup.ogg', 50, TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/item/heave_ho/attack_self(mob/user, modifiers)
	. = ..()
	if(!carried)
		balloon_alert(user, "nothing on the hook")
		return
	var/turf/landing = get_turf(user)
	if(!landing || landing.is_blocked_turf(TRUE, user))
		balloon_alert(user, "no room here!")
		return
	var/obj/structure/closet/dropping = carried
	dropping.forceMove(landing) // Exited() undoes the weight and the slowdown
	user.visible_message(
		span_notice("[user] unhooks [dropping] and sets it down."),
		span_notice("You set [dropping] down."),
	)
	playsound(src, 'sound/items/handling/toolbox/toolbox_drop.ogg', 50, TRUE)

/// A swing with a loaded harness throws its weight around, literally.
/obj/item/heave_ho/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!carried || !isliving(target) || target == user || !isliving(user))
		return
	if(!COOLDOWN_FINISHED(src, swing_cooldown))
		return
	COOLDOWN_START(src, swing_cooldown, HEAVE_HO_SWING_COOLDOWN)
	var/mob/living/victim = target
	var/turf/landing = get_ranged_target_turf(victim, get_dir(user, victim), HEAVE_HO_SWING_KNOCKBACK)
	victim.visible_message(
		span_danger("[user] swings [carried] around on [src] and clouts [victim] with it!"),
		span_userdanger("[user] catches you with the full weight of [carried]!"),
	)
	playsound(victim, 'sound/effects/hit_kick.ogg', 60, TRUE)
	if(landing)
		victim.throw_at(landing, HEAVE_HO_SWING_KNOCKBACK, 2, user, force = MOVE_FORCE_STRONG)
	victim.Knockdown(1 SECONDS)

#undef HEAVE_HO_SWING_FORCE
#undef HEAVE_HO_SWING_KNOCKBACK
#undef HEAVE_HO_SWING_COOLDOWN
#undef HEAVE_HO_SLOWDOWN
#undef HEAVE_HO_LIFT_TIME

// =========================================================================
// RED: No Quarter
// Subtypes the Donk Co. Musket for its single-shot-then-rack loop and its
// oversized in-hand frame; the ground sprite and the 64x in-hands are its own
// (uniques.dmi / uniques_64x_*hand.dmi). Wall breaching calls
// turf/closed/wall/dismantle_wall() directly (the same call the wall_smasher
// element uses) rather than fighting obj_integrity math through
// demolition_mod, since walls aren't /obj instances.
//
// CHANGED: the reload used to take a full minute and demand a table, and its
// ammunition existed nowhere in the game. Reloading is now a flat 5 seconds
// anywhere, and the gun arrives with a bandolier of cartridges and the
// schematic to make more.
// =========================================================================

#define NO_QUARTER_RELOAD_TIME (5 SECONDS)
#define NO_QUARTER_THROW_RANGE 6
#define NO_QUARTER_BANDOLIER_SHELLS 12

/// One shot: breaches a normal wall outright, or throws a person six tiles.
/// Five seconds to load the next cartridge.
/obj/item/gun/ballistic/shotgun/musket/no_quarter
	name = "\"No Quarter\""
	desc = "A flintlock hand cannon dressed up as a boltloading musket. One shot: it punches a hole in a normal wall, or throws a person 6 tiles. Loading the next cartridge takes 5 seconds."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "no_quarter"
	// base musket sets inhand_icon_state = "donk_musket", override so the
	// custom states in the files below are actually used. inhand_x/y_dimension
	// stay inherited at 64 from the shotgun base, matching the 64x64 files.
	inhand_icon_state = "no_quarter"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_64x_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_64x_righthand.dmi'
	accepted_magazine_type = /obj/item/ammo_box/magazine/internal/shot/single/no_quarter
	// The ballistic parent appends a bare-string "[icon_state]_bolt" overlay for
	// locking bolts, which would resolve into this file and find nothing. A
	// flintlock has no bolt to draw anyway.
	show_bolt_icon = FALSE
	/// Whether the reload is currently in progress.
	var/priming = FALSE

/**
 * The gun is worthless without cartridges and there is nowhere else in the
 * game to get them, so it never arrives alone: a full bandolier and the
 * schematic for more land wherever the gun did (in the cache it rolled in, or
 * on the floor next to an admin who spawned it).
 */
/obj/item/gun/ballistic/shotgun/musket/no_quarter/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	// Spawned into a cache, the kit lands in the cache next to it. Spawned
	// into someone's hands, it lands on the floor rather than loose inside
	// the mob.
	var/atom/kit_location = loc
	if(ismob(kit_location))
		kit_location = get_turf(src)
	if(kit_location)
		new /obj/item/storage/belt/bandolier/no_quarter(kit_location)
		new /obj/item/blueprint/no_quarter_cartridge(kit_location)

/obj/item/gun/ballistic/shotgun/musket/no_quarter/examine(mob/user)
	. = ..()
	. += span_notice("Loading a cartridge takes 5 seconds and can be done anywhere.")

/// Slows the normal ammo-loading flow down to a five-second job, once that's
/// done, the real (unmodified) chambering logic takes over.
/obj/item/gun/ballistic/shotgun/musket/no_quarter/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!isammocasing(tool) && !istype(tool, /obj/item/ammo_box))
		return ..()
	if(priming)
		return ITEM_INTERACT_BLOCKING
	if(chambered?.loaded_projectile)
		balloon_alert(user, "already loaded!")
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

/// "Gunpowder and a metal slug, twisted shut", the one cartridge type
/// No Quarter feeds on. Subtypes the real shotgun slug casing (icon/caliber/
/// materials inherited verbatim) and just swaps the projectile it fires.
/obj/item/ammo_casing/shotgun/no_quarter
	name = "heavy cartridge"
	desc = "A paper cartridge bulging with gunpowder and a single lead slug, twisted shut. Only \"No Quarter\" takes them."
	projectile_type = /obj/projectile/bullet/shotgun_slug/no_quarter
	// It IS a paper cartridge - and the crafted-vs-spawned parity test wants the
	// blueprint recipe's paper accounted for on the spawned item too.
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2, /datum/material/paper = SMALL_MATERIAL_AMOUNT * 2.5)

/// The bandolier the gun turns up with. Twelve cartridges, then you make
/// your own off the schematic.
/obj/item/storage/belt/bandolier/no_quarter
	name = "hand cannon bandolier"
	desc = "A worn leather bandolier of heavy cartridges, cut wide for a hand cannon's bore."

/obj/item/storage/belt/bandolier/no_quarter/PopulateContents()
	for(var/i in 1 to NO_QUARTER_BANDOLIER_SHELLS)
		new /obj/item/ammo_casing/shotgun/no_quarter(src)

/// Carrying this puts the cartridge recipe in your crafting menu; an outpost
/// neural imprinter can burn it in for the round instead.
/obj/item/blueprint/no_quarter_cartridge
	name = "weapon schematic (heavy cartridge)"
	schematic_name = "heavy cartridge"
	recipe_type = /datum/crafting_recipe/blueprint/no_quarter_cartridge
	tier = BLUEPRINT_TIER_RED

/datum/crafting_recipe/blueprint/no_quarter_cartridge
	name = "Heavy Cartridge"
	result = /obj/item/ammo_casing/shotgun/no_quarter
	category = CAT_WEAPON_AMMO
	time = 3 SECONDS
	mass_craftable = TRUE
	reqs = list(
		/obj/item/stack/sheet/iron = 2,
		/obj/item/paper = 1,
	)

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

#undef NO_QUARTER_BANDOLIER_SHELLS
#undef NO_QUARTER_THROW_RANGE
#undef NO_QUARTER_RELOAD_TIME

#undef TRADE_VALUE_VOUCHER_WEIGHT
