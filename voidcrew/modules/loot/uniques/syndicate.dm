/**
 * # SYNDICATE unique loot — reinforced syndicate cache
 *
 * Six found-in-the-world prizes for the syndicate zone-loot cache
 * (voidcrew/modules/loot/zone_loot.dm). Not antag gear — nothing here
 * requires a role or grants a loadout, they're just very good pickups.
 *
 * Every item ADD_TRAITs TRAIT_NO_REPLICATE on itself so the Helios pattern
 * stamp (and any future duplicator) refuses to copy it.
 *
 * Not yet wired into any loot table — see zone_loot.dm's rare_loot_* lists.
 */

/// Bespoke, non-public radio frequency for the Ferryman coin/earpiece pair.
/// Sits well outside the 1441-1489 public retune band so nobody stumbles
/// onto it by hand-tuning a normal headset.
#define FREQ_LISTENING_COIN 1401

// =============================================================================
// GREEN — "Ferryman" listening coin
// =============================================================================

/**
 * A bugged coin. Mechanically it's just a radio: broadcasting = TRUE makes
 * the base /obj/item/radio class relay any speech it hears into its radio
 * channel (see set_broadcasting() in code/game/objects/items/devices/radio/radio.dm)
 * — that's the whole trick, no custom Hear() override needed. It ships
 * paired with a locked-frequency earpiece.
 *
 * Deviation from the design doc: the doc's suggested typepath was
 * /obj/item/listening_coin, but the "relay nearby speech" mechanic only
 * exists on /obj/item/radio and its subtypes, so this inherits from radio
 * instead and wears a coin's sprite.
 */
/obj/item/radio/listening_coin
	name = "worn credit chit"
	desc = "A worn credit-chit with a hairline seam. It's heavier than it should be."
	// Sprite copied verbatim from /obj/item/coin (code/modules/mining/ores_coins.dm)
	icon = 'icons/obj/economy.dmi'
	icon_state = "coin"
	worn_icon_state = "coin"
	inhand_icon_state = null // coins don't render an inhand sprite either
	w_class = WEIGHT_CLASS_TINY
	throw_speed = 3
	throw_range = 7
	slot_flags = NONE
	canhear_range = 2
	// Without freerange, set_frequency() sanitizes anything outside the public
	// 1441-1489 band — our 1401 would silently clamp onto a public channel
	freerange = TRUE
	/// Set once someone starts searching it for the bug.
	var/being_searched = FALSE

/obj/item/radio/listening_coin/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	set_broadcasting(TRUE)
	set_listening(FALSE)
	set_frequency(FREQ_LISTENING_COIN)
	freqlock = RADIO_FREQENCY_LOCKED
	new /obj/item/radio/headset/listening_coin_earpiece(loc)

/obj/item/radio/listening_coin/examine(mob/user)
	. = ..()
	if(in_range(user, src) || loc == user)
		. += span_notice("Something about the weight feels wrong. You could [EXAMINE_HINT("search")] it for wiring.")

/// Close-range search: reveals and destroys the bug. Adjacency is enforced
/// by "set src in oview(1)" (same idiom used by items.dm's own verbs).
/obj/item/radio/listening_coin/verb/search_for_bug()
	set name = "Search for Hidden Wiring"
	set category = "Object"
	set src in oview(1)

	var/mob/living/user = usr
	if(!istype(user) || being_searched)
		return
	if(user.stat != CONSCIOUS)
		return
	being_searched = TRUE
	to_chat(user, span_notice("You start prying at the coin's seam..."))
	if(!do_after(user, 2 SECONDS, src))
		being_searched = FALSE
		return
	if(QDELETED(src))
		return
	user.visible_message(
		span_warning("[user] cracks open [src], and a scorched hairline transmitter sparks and burns out inside!"),
		span_warning("You crack the coin open — there's a bugged transmitter wired inside. It sparks and burns out in your hand."),
	)
	qdel(src)

/// The paired earpiece the coin "ships with" — a normal headset, locked to
/// the coin's frequency and listen-only so it doesn't also broadcast the
/// wearer's own voice back into the channel.
/obj/item/radio/headset/listening_coin_earpiece
	name = "unmarked earpiece"
	desc = "A tiny earpiece with no manufacturer stamp. Tuned to something."
	// Same clamp-dodge as the coin — the pair lives outside the public band
	freerange = TRUE

/obj/item/radio/headset/listening_coin_earpiece/Initialize(mapload)
	. = ..()
	set_broadcasting(FALSE)
	set_listening(TRUE)
	set_frequency(FREQ_LISTENING_COIN)
	freqlock = RADIO_FREQENCY_LOCKED

// =============================================================================
// GREEN — Courier's palm
// =============================================================================

/**
 * Deviation from the design doc: the doc suggested hooking
 * COMSIG_ITEM_PRE_STRIPPED, which doesn't exist. The real hook is
 * COMSIG_TRY_STRIP (code/datums/elements/strippable.dm), sent to the
 * *stripper* at the very start of both try_equip() and try_unequip() before
 * any do_after or warning message fires. Returning COMPONENT_CANT_STRIP
 * there aborts the slow/loud vanilla path entirely — so we intercept there,
 * perform an instant silent transfer ourselves (restricted to hands and
 * pockets only), and cancel the normal one.
 */
/obj/item/clothing/gloves/courier
	name = "courier's palm"
	desc = "One thin glove, kid leather, fingertips shiny with use. The other one is wherever the courier is."
	// Sprite copied via subtyping botanic_leather (code/modules/clothing/gloves/botany.dm)
	icon_state = "leather"
	inhand_icon_state = null
	greyscale_colors = null
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.5)
	/// Cooldown between instant strip/plant attempts.
	COOLDOWN_DECLARE(snatch_cooldown)
	var/snatch_cooldown_time = 30 SECONDS

/obj/item/clothing/gloves/courier/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/courier/equipped(mob/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_GLOVES)
		RegisterSignal(user, COMSIG_TRY_STRIP, PROC_REF(on_try_strip))
		return
	UnregisterSignal(user, COMSIG_TRY_STRIP)

/obj/item/clothing/gloves/courier/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_TRY_STRIP)

/**
 * Signal handler for COMSIG_TRY_STRIP, fired on the wearer whenever they
 * open the strip menu's equip or unequip flow on somebody. Only handles
 * items currently sitting in the target's hands or pockets — everything
 * else (masks, armor, ears, etc.) is left to the normal slow/loud path.
 */
/obj/item/clothing/gloves/courier/proc/on_try_strip(mob/living/user, atom/strip_target, obj/item/relevant_item)
	SIGNAL_HANDLER

	if(!COOLDOWN_FINISHED(src, snatch_cooldown))
		return NONE
	if(!isliving(strip_target) || isnull(relevant_item))
		return NONE

	var/mob/living/target = strip_target
	var/success = FALSE
	if(relevant_item.loc == user)
		success = try_plant(user, target, relevant_item)
	else if(relevant_item.loc == target && is_hand_or_pocket_item(target, relevant_item))
		success = try_snatch(user, target, relevant_item)

	if(!success)
		return NONE

	COOLDOWN_START(src, snatch_cooldown, snatch_cooldown_time)
	return COMPONENT_CANT_STRIP

/obj/item/clothing/gloves/courier/proc/is_hand_or_pocket_item(mob/living/target, obj/item/relevant_item)
	return (relevant_item == target.get_active_held_item()) || \
		(relevant_item == target.get_inactive_held_item()) || \
		(relevant_item == target.get_item_by_slot(ITEM_SLOT_LPOCKET)) || \
		(relevant_item == target.get_item_by_slot(ITEM_SLOT_RPOCKET))

/obj/item/clothing/gloves/courier/proc/try_snatch(mob/living/user, mob/living/target, obj/item/relevant_item)
	if(!target.temporarilyRemoveItemFromInventory(relevant_item))
		return FALSE
	user.put_in_hands(relevant_item)
	return TRUE

/obj/item/clothing/gloves/courier/proc/try_plant(mob/living/user, mob/living/target, obj/item/relevant_item)
	var/free_slot = NONE
	if(isnull(target.get_item_by_slot(ITEM_SLOT_LPOCKET)))
		free_slot = ITEM_SLOT_LPOCKET
	else if(isnull(target.get_item_by_slot(ITEM_SLOT_RPOCKET)))
		free_slot = ITEM_SLOT_RPOCKET
	if(!free_slot)
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(relevant_item))
		return FALSE
	if(!target.equip_to_slot_if_possible(relevant_item, free_slot, qdel_on_fail = FALSE, disable_warning = TRUE, bypass_equip_delay_self = TRUE))
		user.put_in_hands(relevant_item) // couldn't fit it, give it back
		return FALSE
	return TRUE

// =============================================================================
// YELLOW — Static cuff
// =============================================================================

/**
 * Deviation from the design doc: cameras can't selectively render "static"
 * to one viewer while showing everyone else a clean feed — that would
 * require touching the camera rendering pipeline itself. What's real and
 * feasible from a worn item:
 *  - COMSIG_LIVING_CAN_TRACK -> COMPONENT_CANT_TRACK (verified in
 *    code/game/machinery/camera/trackable.dm and reused by e.g. the MOD
 *    camera-vision module) — this is the actual mechanism AI/console
 *    "track" lookups check, and blocking it is the mechanically important
 *    half of "AI tracking on you fails".
 *  - Hiding from silicon AI huds, mirroring /datum/element/digitalcamo's
 *    HideFromAIHuds/UnhideFromAIHuds pattern.
 *  - As a cosmetic stand-in for "cameras show static", nearby operational
 *    cameras get their own existing EMP-look icon state (base_icon_state +
 *    "_emp", see /obj/machinery/camera/update_icon_state()) flicked on a
 *    pulse. This is purely a visible flick() on the physical camera prop —
 *    it does not touch camera_enabled/network, so the feed itself keeps
 *    working for everyone watching it.
 * Fresh root type: sprite copied verbatim from /obj/item/restraints/handcuffs
 * (code/game/objects/items/handcuffs.dm) rather than subtyping it, since
 * inheriting handcuffs would also inherit "cuff other people" combat behavior
 * this item was never meant to have.
 */
/obj/item/static_cuff
	name = "static cuff"
	desc = "A wrist unit with no branding and one switch. The switch position is labeled in grease pencil: NO."
	icon = 'icons/obj/weapons/restraints.dmi'
	icon_state = "handcuff"
	worn_icon_state = "handcuff"
	inhand_icon_state = "handcuff"
	lefthand_file = 'icons/mob/inhands/equipment/security_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/security_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2)
	// Belt-worn items can't be attack_self'd from the belt slot — the action
	// button routes to attack_self via the default ui_action_click, so the
	// switch stays reachable while worn
	actions_types = list(/datum/action/item_action/toggle)
	/// Currently toggled on.
	var/active = FALSE
	/// Who the tracking shield is currently registered on — unregistration
	/// must target them, not whatever loc happens to be after a drop.
	var/mob/living/shielded_wearer
	/// Remaining runtime, in deciseconds.
	var/charge
	/// Max runtime on a full cell (~4 minutes).
	var/max_charge = 4 MINUTES
	/// Recharge speed while off, as a fraction of real time.
	var/recharge_rate = 0.25
	/// Accumulated seconds since the last camera-static pulse.
	var/camera_pulse_accum = 0
	/// How often, in real seconds (matches camera_pulse_accum's unit, not deciseconds),
	/// nearby cameras get a static flicker while active.
	var/camera_pulse_interval = 4

/obj/item/static_cuff/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	charge = max_charge

/obj/item/static_cuff/Destroy()
	set_active(FALSE)
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/static_cuff/dropped(mob/user)
	. = ..()
	set_active(FALSE)

/obj/item/static_cuff/examine(mob/user)
	. = ..()
	. += span_notice("The switch is currently [active ? "ON" : "OFF"]. It's carrying about [round((charge / max_charge) * 100)]% charge.")

/obj/item/static_cuff/attack_self(mob/user)
	. = ..()
	if(!isliving(user) || user.get_item_by_slot(ITEM_SLOT_BELT) != src)
		to_chat(user, span_warning("[src] needs to be worn on your belt to switch on."))
		return
	if(!active && charge <= 0)
		to_chat(user, span_warning("[src]'s light blinks red. It's drained."))
		return
	set_active(!active, user)

/obj/item/static_cuff/proc/set_active(new_active, mob/user)
	if(active == new_active)
		return
	if(new_active)
		var/mob/living/wearer = loc
		if(!isliving(wearer))
			return
		active = TRUE
		shielded_wearer = wearer
		RegisterSignal(wearer, COMSIG_LIVING_CAN_TRACK, PROC_REF(on_can_track))
		hide_from_ai_huds(wearer)
		if(user)
			to_chat(user, span_notice("You flip the switch. [src] hums faintly."))
	else
		active = FALSE
		if(shielded_wearer)
			UnregisterSignal(shielded_wearer, COMSIG_LIVING_CAN_TRACK)
			unhide_from_ai_huds(shielded_wearer)
			shielded_wearer = null
		if(user)
			to_chat(user, span_notice("You flip the switch off."))
	update_processing()

/obj/item/static_cuff/proc/update_processing()
	if(active || charge < max_charge)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)

/obj/item/static_cuff/process(seconds_per_tick)
	if(active)
		charge = max(charge - (seconds_per_tick SECONDS), 0)
		camera_pulse_accum += seconds_per_tick
		if(camera_pulse_accum >= camera_pulse_interval)
			camera_pulse_accum = 0
			pulse_nearby_cameras()
		if(charge <= 0)
			set_active(FALSE)
			return
	else if(charge < max_charge)
		charge = min(charge + (seconds_per_tick SECONDS * recharge_rate), max_charge)
	if(!active && charge >= max_charge)
		STOP_PROCESSING(SSobj, src)

/obj/item/static_cuff/proc/on_can_track(datum/source, mob/user)
	SIGNAL_HANDLER
	return COMPONENT_CANT_TRACK

/// Cosmetic-only flicker of nearby cameras' existing EMP look — see the
/// class doc comment for why this can't touch the actual feed.
/obj/item/static_cuff/proc/pulse_nearby_cameras()
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/obj/machinery/camera/nearby_camera in view(7, here))
		if(!nearby_camera.can_use())
			continue
		flick("[nearby_camera.base_icon_state]_emp", nearby_camera)

/// Mirrors /datum/element/digitalcamo's AI hud hiding (code/datums/elements/digitalcamo.dm).
/obj/item/static_cuff/proc/hide_from_ai_huds(mob/living/target)
	for(var/mob/living/silicon/ai/ai_mob in GLOB.ai_list)
		for(var/hud_type in ai_mob.silicon_huds)
			var/datum/atom_hud/silicon_hud = GLOB.huds[hud_type]
			silicon_hud.hide_single_atomhud_from(ai_mob, target)

/obj/item/static_cuff/proc/unhide_from_ai_huds(mob/living/target)
	for(var/mob/living/silicon/ai/ai_mob in GLOB.ai_list)
		for(var/hud_type in ai_mob.silicon_huds)
			var/datum/atom_hud/silicon_hud = GLOB.huds[hud_type]
			silicon_hud.unhide_single_atomhud_from(ai_mob, target)

// =============================================================================
// YELLOW — "Housecall"
// =============================================================================

/**
 * Subtypes the .38 revolver (code/modules/projectiles/guns/ballistic/revolver.dm)
 * for its icon/sprite and ammo economy — the design doc calls it a ".38",
 * matching the c38 revolver rather than the .357 base one. Its magazine
 * subtypes cylinder/rev38 specifically (not the .357 base cylinder) so the
 * caliber stays consistent with the c38 casings it's loaded with.
 */
/obj/item/gun/ballistic/revolver/c38/housecall
	name = "\"Housecall\""
	desc = "An integrally-suppressed .38 revolver with a doctor's-bag handle. For patients who talk too much."
	suppressed = TRUE
	spawn_magazine_type = /obj/item/ammo_box/magazine/internal/cylinder/rev38/housecall

/obj/item/gun/ballistic/revolver/c38/housecall/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	// 6 in the cylinder (see the magazine's max_ammo) + 6 loose spares = the
	// "12 bespoke rounds" from the design doc.
	for(var/i in 1 to 6)
		new /obj/item/ammo_casing/c38/housecall(loc)

/obj/item/ammo_box/magazine/internal/cylinder/rev38/housecall
	name = "\"Housecall\" cylinder"
	ammo_type = /obj/item/ammo_casing/c38/housecall

/obj/item/ammo_casing/c38/housecall
	name = "subdermal .38 bullet casing"
	desc = "A .38 bullet casing loaded with a hair-fine anesthetic dart instead of a slug."
	projectile_type = /obj/projectile/bullet/c38/housecall

/// Modest damage; the payload is the mute, not the hole.
/obj/projectile/bullet/c38/housecall
	name = "subdermal dart"
	damage = 15
	/// How long the anesthetic silences a hit target for.
	var/mute_duration = 15 SECONDS

/obj/projectile/bullet/c38/housecall/on_hit(atom/target, blocked, pierce_hit)
	. = ..()
	if(. != BULLET_ACT_HIT)
		return .
	if(!isliving(target))
		return .
	var/mob/living/victim = target
	if(victim.stat == DEAD)
		return .
	victim.apply_status_effect(/datum/status_effect/silenced, mute_duration)
	return .

// =============================================================================
// RED — Second Shadow
// =============================================================================

/**
 * Deviation from the design doc: there's no ready-made "spawn a decoy mob
 * that eats the hit for you" mechanic in this codebase. What's real and
 * reused here:
 *  - The exact signal set /datum/status_effect/stun_absorption listens to
 *    (code/datums/status_effects/buffs/stun_absorption.dm) — knockdown,
 *    stun, paralyze, immobilize, incapacitate — all resolve through
 *    SEND_SIGNAL(..., amount, ignore_canstun) and respect COMPONENT_NO_STUN
 *    as a cancel. We hook those five signals directly (rather than reusing
 *    the shared status effect class itself, to avoid interacting with other
 *    unrelated stun_absorption stacking priority elsewhere in the game).
 *  - The appearance-copy technique from /datum/component/reflection
 *    (code/datums/components/reflection.dm): copy_appearance_filter_overlays()
 *    onto a temp_visual effect placed where the wearer stood.
 *  - "Crit-threshold hit" specifically isn't its own signal in this
 *    codebase — attacks that would put someone in crit generally also
 *    apply a knockdown/stun as part of the same swing, so the five
 *    incapacitation signals are the closest real hook and cover the
 *    intended cases in practice.
 *  - "Slip one tile in a direction of your choosing" is simplified to a
 *    random open adjacent tile: the interception happens synchronously
 *    inside a signal handler mid-attack, with no opportunity for a
 *    do_after/UI prompt to ask the (about to be stunned) player anything.
 */
/obj/item/clothing/suit/hooded/cloak/second_shadow
	name = "Second Shadow"
	desc = "A cloak the color of a corridor at 3 AM. It moves a half-second after you do."
	// The bare cloak parent has no icon_state (invisible) and defaults its
	// hood to the winter hood — borrow the goliath cloak's sprite and hood,
	// darkened to match the flavor
	icon_state = "goliath_cloak"
	hoodtype = /obj/item/clothing/head/hooded/cloakhood/goliath
	color = "#3a3a45"
	/// Whether the hood is currently deployed on the wearer's head.
	var/hood_up = FALSE
	/// Cooldown between decoy triggers.
	COOLDOWN_DECLARE(decoy_cooldown)
	var/decoy_cooldown_time = 3 MINUTES
	/// How long the wearer stays invisible/displaced after triggering.
	var/decoy_effect_duration = 3 SECONDS
	/// The five "disabling hit" signals we intercept, mirroring stun_absorption's list.
	var/static/list/intercepted_signals = list(
		COMSIG_LIVING_STATUS_IMMOBILIZE,
		COMSIG_LIVING_STATUS_INCAPACITATE,
		COMSIG_LIVING_STATUS_KNOCKDOWN,
		COMSIG_LIVING_STATUS_PARALYZE,
		COMSIG_LIVING_STATUS_STUN,
	)

/obj/item/clothing/suit/hooded/cloak/second_shadow/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/hooded/cloak/second_shadow/on_hood_up(obj/item/clothing/head/hooded/hood)
	. = ..()
	hood_up = TRUE

/obj/item/clothing/suit/hooded/cloak/second_shadow/on_hood_down(obj/item/clothing/head/hooded/hood)
	. = ..()
	hood_up = FALSE

/obj/item/clothing/suit/hooded/cloak/second_shadow/equipped(mob/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_OCLOTHING)
		RegisterSignals(user, intercepted_signals, PROC_REF(try_intercept))
		return
	UnregisterSignal(user, intercepted_signals)
	hood_up = FALSE

/obj/item/clothing/suit/hooded/cloak/second_shadow/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, intercepted_signals)
	hood_up = FALSE

/// Signal handler for the incapacitation signals — see intercepted_signals.
/// All five share the (source, amount, ignore_canstun) shape.
/obj/item/clothing/suit/hooded/cloak/second_shadow/proc/try_intercept(mob/living/source, amount, ignore_canstun)
	SIGNAL_HANDLER

	if(!hood_up || amount <= 0 || ignore_canstun)
		return NONE
	if(!COOLDOWN_FINISHED(src, decoy_cooldown))
		return NONE

	COOLDOWN_START(src, decoy_cooldown, decoy_cooldown_time)
	spawn_decoy(source)
	return COMPONENT_NO_STUN

/obj/item/clothing/suit/hooded/cloak/second_shadow/proc/spawn_decoy(mob/living/wearer)
	var/turf/origin = get_turf(wearer)
	if(!origin)
		return

	var/obj/effect/temp_visual/second_shadow_decoy/decoy = new(origin)
	decoy.appearance = copy_appearance_filter_overlays(wearer.appearance)
	decoy.setDir(wearer.dir)

	wearer.visible_message(
		span_warning("The blow passes clean through [wearer] as their shape flickers and slips aside!"),
		span_userdanger("The cloak snaps you out of the way — the hit lands on empty air!"),
	)

	var/old_alpha = wearer.alpha
	wearer.alpha = 0
	addtimer(VARSET_CALLBACK(wearer, alpha, old_alpha), decoy_effect_duration)

	var/list/open_dirs = list()
	for(var/dir_option in GLOB.cardinals)
		var/turf/step_turf = get_step(origin, dir_option)
		if(step_turf && !step_turf.density)
			open_dirs += dir_option
	if(length(open_dirs))
		step(wearer, pick(open_dirs))

/// A silent, non-interactive copy of the wearer's appearance left behind at
/// the moment of interception. Purely cosmetic — see spawn_decoy().
/obj/effect/temp_visual/second_shadow_decoy
	name = "flickering shape"
	randomdir = FALSE
	duration = 3 SECONDS

// =============================================================================
// RED — "Understudy"
// =============================================================================

/**
 * Deviation from the design doc: full DNA/species-level identity swap (the
 * changeling "transform" power, code/modules/antagonists/changeling/powers/transform.dm)
 * is built entirely around the changeling antag datum and an absorbed-DNA
 * profile list — there's no standalone entry point to reuse it for a plain
 * loot item. Instead this copies the three independently real, lighter
 * levers this codebase exposes:
 *  - display name (mob/name)
 *  - "voice" identity used by GetVoice()/radio recognition, via the real
 *    SetSpecialVoice()/UnsetSpecialVoice() hooks on human mobs
 *    (code/modules/mob/living/carbon/human/human_say.dm)
 *  - visual appearance, via the same copy_appearance_filter_overlays()
 *    helper /datum/component/reflection uses.
 * Caveat worth flagging: unlike a true DNA-level disguise, the appearance
 * copy is a one-time snapshot. If the wearer's own update_body()/
 * regenerate_icons() fires later for an unrelated reason (re-equipping
 * gear, a wound overlay, etc.), it can rebuild their real look over the
 * copied one. The name/voice layer is unaffected and persists for the full
 * duration regardless.
 */
/obj/item/knife/understudy
	name = "\"Understudy\""
	desc = "A chameleon-finish knife that never has fingerprints on it, including yours."
	// Sprite inherited from /obj/item/knife/combat.
	/// Weakref to whoever we most recently downed/killed.
	var/datum/weakref/marked_target_ref
	/// Window during which "take their part" is available after a kill/knockdown.
	var/take_part_window = 10 SECONDS
	/// How long a stolen identity lasts.
	var/disguise_duration = 10 MINUTES
	/// Timer id clearing the mark when the window expires.
	var/mark_timer_id

/obj/item/knife/understudy/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/knife/understudy/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	var/was_downed = istype(target_mob) && target_mob.stat != DEAD && target_mob.stat < UNCONSCIOUS
	. = ..()
	if(!istype(target_mob) || !ishuman(target_mob))
		return .
	if(target_mob.stat == DEAD || (was_downed && target_mob.stat >= UNCONSCIOUS))
		mark_target(target_mob)
	return .

/obj/item/knife/understudy/proc/mark_target(mob/living/carbon/human/target)
	marked_target_ref = WEAKREF(target)
	deltimer(mark_timer_id)
	mark_timer_id = addtimer(CALLBACK(src, PROC_REF(clear_mark)), take_part_window, TIMER_STOPPABLE)

/obj/item/knife/understudy/proc/clear_mark()
	marked_target_ref = null
	mark_timer_id = null

/obj/item/knife/understudy/attack_self(mob/user)
	. = ..()
	if(!ishuman(user))
		to_chat(user, span_warning("You'd need a human face to sell this performance."))
		return
	if(isnull(marked_target_ref))
		to_chat(user, span_warning("There's nobody to take the part of right now."))
		return
	var/mob/living/carbon/human/target = marked_target_ref.resolve()
	if(!istype(target))
		to_chat(user, span_warning("Whoever you had in mind is gone."))
		clear_mark()
		return

	var/mob/living/carbon/human/actor = user
	var/datum/status_effect/understudy_disguise/existing = actor.has_status_effect(/datum/status_effect/understudy_disguise)
	if(existing)
		qdel(existing) // one performance at a time; taking a new face ends the old one
	actor.apply_status_effect(/datum/status_effect/understudy_disguise, target, disguise_duration)
	to_chat(actor, span_notice("You take on [target]'s part."))
	deltimer(mark_timer_id)
	clear_mark()

/datum/status_effect/understudy_disguise
	id = "understudy_disguise"
	alert_type = null
	remove_on_fullheal = FALSE
	/// The name we're overriding, restored on removal.
	var/old_name
	/// Who we copied — held only long enough to apply the effect.
	var/mob/living/carbon/human/copied_from

/datum/status_effect/understudy_disguise/on_creation(mob/living/new_owner, mob/living/carbon/human/target, duration = 10 MINUTES)
	src.duration = duration
	copied_from = target
	return ..()

/datum/status_effect/understudy_disguise/on_apply()
	if(!ishuman(owner) || !istype(copied_from))
		return FALSE
	var/mob/living/carbon/human/actor = owner
	old_name = actor.name
	actor.name = copied_from.name
	actor.SetSpecialVoice(copied_from.real_name)
	actor.appearance = copy_appearance_filter_overlays(copied_from.appearance)
	copied_from = null // done with it, don't hold the ref for the full 10 minutes
	return TRUE

/datum/status_effect/understudy_disguise/on_remove()
	if(!ishuman(owner))
		return
	var/mob/living/carbon/human/actor = owner
	actor.name = old_name
	actor.UnsetSpecialVoice()
	// Full rebuild: the disguise replaced the whole appearance snapshot, and
	// update_body() alone wouldn't restore worn gear / held item overlays
	actor.regenerate_icons()

#undef FREQ_LISTENING_COIN
