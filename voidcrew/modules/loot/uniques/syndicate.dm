/**
 * # SYNDICATE unique loot: reinforced syndicate cache
 *
 * Six found-in-the-world prizes for the syndicate zone-loot cache
 * (voidcrew/modules/loot/zone_loot.dm). Not antag gear, nothing here
 * requires a role or grants a loadout, they're just very good pickups.
 *
 * Every item ADD_TRAITs TRAIT_NO_REPLICATE on itself so the Helios pattern
 * stamp (and any future duplicator) refuses to copy it.
 *
 * Not yet wired into any loot table, see the `loot_uniques` shelf in voidcrew/modules/loot/themes/.
 */

/// Bespoke, non-public radio frequency for the Ferryman coin/earpiece pair.
/// Sits well outside the 1441-1489 public retune band so nobody stumbles
/// onto it by hand-tuning a normal headset.
#define FREQ_LISTENING_COIN 1401

// =============================================================================
// GREEN: "Ferryman" listening coin
// =============================================================================

/**
 * A bugged coin. Mechanically it's just a radio: broadcasting = TRUE makes
 * the base /obj/item/radio class relay any speech it hears into its radio
 * channel (see set_broadcasting() in code/game/objects/items/devices/radio/radio.dm).
 * That's the whole trick, no custom Hear() override needed. It ships
 * paired with a locked-frequency earpiece.
 *
 * Deviation from the design doc: the doc's suggested typepath was
 * /obj/item/listening_coin, but the "relay nearby speech" mechanic only
 * exists on /obj/item/radio and its subtypes, so this inherits from radio
 * instead and wears a credit chit's sprite.
 */
/obj/item/radio/listening_coin
	name = "worn credit chit"
	desc = "A worn credit chit with a hairline seam down one side. It's heavier than a chit this size should be."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "credit_chit"
	inhand_icon_state = null // too small to draw in someone's hand, same as a coin
	// /obj/item/radio/update_overlays() adds its mic and speaker overlays
	// ("m_idle"/"s_idle") as bare state names, which resolve against the radio's
	// OWN icon file. Those states only exist in voice.dmi, so anywhere else
	// BYOND falls back to that file's default state - in economy.dmi that's the
	// magenta error sprite, which is what this used to render as. Headsets null
	// them out for the same reason (code/game/objects/items/devices/radio/headset.dm).
	// VOIDCREW EDIT: upstream deleted overlay_speaker_active; only these three remain.
	overlay_speaker_idle = null
	overlay_mic_idle = null
	overlay_mic_active = null
	// the inherited radio dog overlay would look for "credit_chit" in the corgi
	// icon file and come up empty
	dog_fashion = null
	w_class = WEIGHT_CLASS_TINY
	throw_speed = 3
	throw_range = 7
	slot_flags = NONE
	canhear_range = 2
	// Without freerange, set_frequency() sanitizes anything outside the public
	// 1441-1489 band, our 1401 would silently clamp onto a public channel
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
	if(IS_UNCONSCIOUS_OR_CRIT(user))
		return
	being_searched = TRUE
	to_chat(user, span_notice("You start prying at the chit's seam..."))
	if(!do_after(user, 2 SECONDS, src))
		being_searched = FALSE
		return
	if(QDELETED(src))
		return
	user.visible_message(
		span_warning("[user] cracks open [src], and a scorched hairline transmitter sparks and burns out inside!"),
		span_warning("You crack the chit open. There's a bugged transmitter wired inside, and it sparks and burns out in your hand."),
	)
	qdel(src)

/// The paired earpiece the coin "ships with", a normal headset, locked to
/// the coin's frequency and listen-only so it doesn't also broadcast the
/// wearer's own voice back into the channel.
/obj/item/radio/headset/listening_coin_earpiece
	name = "unmarked earpiece"
	desc = "A tiny earpiece with no manufacturer stamp. It's locked to one private frequency."
	// Same clamp-dodge as the coin: the pair lives outside the public band
	freerange = TRUE

/obj/item/radio/headset/listening_coin_earpiece/Initialize(mapload)
	. = ..()
	set_broadcasting(FALSE)
	set_listening(TRUE)
	set_frequency(FREQ_LISTENING_COIN)
	freqlock = RADIO_FREQENCY_LOCKED

// =============================================================================
// GREEN: Courier's palm
// =============================================================================

/**
 * Deviation from the design doc: the doc suggested hooking
 * COMSIG_ITEM_PRE_STRIPPED, which doesn't exist. The real hook is
 * COMSIG_TRY_STRIP (code/datums/elements/strippable.dm), sent to the
 * *stripper* at the very start of both try_equip() and try_unequip() before
 * any do_after or warning message fires. Returning COMPONENT_CANT_STRIP
 * there aborts the slow/loud vanilla path entirely, so we intercept there,
 * perform an instant silent transfer ourselves (restricted to hands and
 * pockets only), and cancel the normal one.
 */
/obj/item/clothing/gloves/courier
	name = "courier's palm"
	desc = "One thin kid-leather glove, fingertips shiny with use. Lifting something out of a person's hands or pockets takes no time at all, then the glove needs 30 seconds before it'll do it again."
	// Sprite copied via subtyping botanic_leather (code/modules/clothing/gloves/botany.dm)
	icon_state = "leather"
	inhand_icon_state = null
	greyscale_colors = null
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 0.5)
	/// Cooldown between instant strip/plant attempts.
	COOLDOWN_DECLARE(snatch_cooldown)
	var/snatch_cooldown_time = 30 SECONDS
	/// Who is currently being shown the recharge alert, so we can clear it off
	/// the right mob when the glove comes off.
	var/mob/living/alerted_wearer

/obj/item/clothing/gloves/courier/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/gloves/courier/Destroy()
	clear_recharge_alert()
	return ..()

/obj/item/clothing/gloves/courier/examine(mob/user)
	. = ..()
	if(COOLDOWN_FINISHED(src, snatch_cooldown))
		. += span_notice("It's ready.")
	else
		. += span_notice("It's recharging. [DisplayTimeText(COOLDOWN_TIMELEFT(src, snatch_cooldown))] left.")

/obj/item/clothing/gloves/courier/equipped(mob/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_GLOVES)
		RegisterSignal(user, COMSIG_TRY_STRIP, PROC_REF(on_try_strip), override = TRUE)
		// picking the glove back up mid-cooldown should pick the countdown back up too
		if(!COOLDOWN_FINISHED(src, snatch_cooldown))
			show_recharge_alert(user)
		return
	UnregisterSignal(user, COMSIG_TRY_STRIP)
	clear_recharge_alert()

/obj/item/clothing/gloves/courier/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_TRY_STRIP)
	clear_recharge_alert()

/// Puts the countdown alert on the wearer for whatever is left of the cooldown.
/obj/item/clothing/gloves/courier/proc/show_recharge_alert(mob/living/wearer)
	clear_recharge_alert()
	if(!isliving(wearer))
		return
	var/time_left = COOLDOWN_TIMELEFT(src, snatch_cooldown)
	if(time_left <= 0)
		return
	alerted_wearer = wearer
	wearer.apply_status_effect(/datum/status_effect/syndicate_recharge/courier_palm, time_left)

/// Takes the alert back off. Removing it early is silent - see the status
/// effect's on_remove().
/obj/item/clothing/gloves/courier/proc/clear_recharge_alert()
	if(isnull(alerted_wearer))
		return
	if(!QDELETED(alerted_wearer))
		alerted_wearer.remove_status_effect(/datum/status_effect/syndicate_recharge/courier_palm)
	alerted_wearer = null

/**
 * Signal handler for COMSIG_TRY_STRIP, fired on the wearer whenever they
 * open the strip menu's equip or unequip flow on somebody. Only handles
 * items currently sitting in the target's hands or pockets, everything
 * else (masks, armor, ears, etc.) is left to the normal slow/loud path.
 */
/obj/item/clothing/gloves/courier/proc/on_try_strip(mob/living/user, atom/strip_target, obj/item/relevant_item)
	SIGNAL_HANDLER

	if(!isliving(strip_target) || isnull(relevant_item))
		return NONE

	var/mob/living/target = strip_target
	// planting only works into a free pocket, same as try_plant(), so don't
	// claim the attempt (or moan about the cooldown) when there isn't one
	var/planting = (relevant_item.loc == user) && !isnull(free_pocket_slot(target))
	var/lifting = (relevant_item.loc == target && is_hand_or_pocket_item(target, relevant_item))
	// anything else (armor, masks, ears) was never ours to speed up, so don't
	// complain about the cooldown for it either
	if(!planting && !lifting)
		return NONE

	if(!COOLDOWN_FINISHED(src, snatch_cooldown))
		to_chat(user, span_warning("\The [src] is still recharging - [DisplayTimeText(COOLDOWN_TIMELEFT(src, snatch_cooldown))] left. You'll have to do this the slow way."))
		return NONE

	var/success = planting ? try_plant(user, target, relevant_item) : try_snatch(user, target, relevant_item)
	if(!success)
		return NONE

	to_chat(user, span_notice("You [planting ? "plant [relevant_item] on [target]" : "lift [relevant_item] off [target]"] in one motion. \The [src] needs [DisplayTimeText(snatch_cooldown_time)] to recharge."))
	COOLDOWN_START(src, snatch_cooldown, snatch_cooldown_time)
	show_recharge_alert(user)
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

/// Which pocket, if either, is empty on the target. Null if both are full.
/obj/item/clothing/gloves/courier/proc/free_pocket_slot(mob/living/target)
	if(isnull(target.get_item_by_slot(ITEM_SLOT_LPOCKET)))
		return ITEM_SLOT_LPOCKET
	if(isnull(target.get_item_by_slot(ITEM_SLOT_RPOCKET)))
		return ITEM_SLOT_RPOCKET
	return null

/obj/item/clothing/gloves/courier/proc/try_plant(mob/living/user, mob/living/target, obj/item/relevant_item)
	var/free_slot = free_pocket_slot(target)
	if(isnull(free_slot))
		return FALSE
	if(!user.temporarilyRemoveItemFromInventory(relevant_item))
		return FALSE
	if(!target.equip_to_slot_if_possible(relevant_item, free_slot, qdel_on_fail = FALSE, disable_warning = TRUE, bypass_equip_delay_self = TRUE))
		user.put_in_hands(relevant_item) // couldn't fit it, give it back
		return FALSE
	return TRUE

// =============================================================================
// YELLOW: Static cuff
// =============================================================================

/**
 * Deviation from the design doc: cameras can't selectively render "static"
 * to one viewer while showing everyone else a clean feed, that would
 * require touching the camera rendering pipeline itself. What's real and
 * feasible from a worn item:
 *  - COMSIG_LIVING_CAN_TRACK -> COMPONENT_CANT_TRACK (verified in
 *    code/game/machinery/camera/trackable.dm and reused by e.g. the MOD
 *    camera-vision module), this is the actual mechanism AI/console
 *    "track" lookups check, and blocking it is the mechanically important
 *    half of "AI tracking on you fails".
 *  - Hiding from silicon AI huds, mirroring /datum/element/digitalcamo's
 *    HideFromAIHuds/UnhideFromAIHuds pattern.
 *  - As a cosmetic stand-in for "cameras show static", every operational
 *    camera in range is held on its own existing EMP-look icon state
 *    (base_icon_state + "_emp", see /obj/machinery/camera/update_icon_state())
 *    for as long as the cuff is on. This is purely the physical camera prop's
 *    sprite, it does not touch camera_enabled/network, so the feed itself
 *    keeps working for everyone watching it.
 *    The hold works by listening to COMSIG_ATOM_UPDATE_ICON_STATE, which the
 *    camera sends at the END of its own update_icon_state(), so our write is
 *    the last one and nothing can flip it back mid-effect.
 * Fresh root type: sprite copied verbatim from /obj/item/restraints/handcuffs
 * (code/game/objects/items/handcuffs.dm) rather than subtyping it, since
 * inheriting handcuffs would also inherit "cuff other people" combat behavior
 * this item was never meant to have.
 */
/obj/item/static_cuff
	name = "static cuff"
	desc = "A wrist unit with no branding and a single switch, labeled in grease pencil: NO. Switched on, the AI and camera consoles can't track you, and every camera around you sits there showing static. Runs about 4 minutes on a charge and recharges slowly while it's off."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "static_cuff"
	worn_icon_state = "handcuff"
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = ITEM_SLOT_BELT
	custom_materials = list(/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2)
	// Belt-worn items can't be attack_self'd from the belt slot, the action
	// button routes to attack_self via the default ui_action_click, so the
	// switch stays reachable while worn
	actions_types = list(/datum/action/item_action/toggle)
	/// Currently toggled on.
	var/active = FALSE
	/// Who the tracking shield is currently registered on, unregistration
	/// must target them, not whatever loc happens to be after a drop.
	var/mob/living/shielded_wearer
	/// Remaining runtime, in deciseconds.
	var/charge
	/// Max runtime on a full cell (~4 minutes).
	var/max_charge = 4 MINUTES
	/// Recharge speed while off, as a fraction of real time.
	var/recharge_rate = 0.25
	/// Cameras currently held on their static sprite, so we can put every one
	/// of them back exactly when we let go.
	var/list/jammed_cameras
	/// How far the static reaches, in tiles.
	var/camera_range = 7
	/// Accumulated seconds since the last sweep for cameras entering or leaving range.
	var/camera_sweep_accum = 0
	/// How often, in real seconds (matches camera_sweep_accum's unit, not
	/// deciseconds), we re-sweep for cameras as the wearer moves around.
	var/camera_sweep_interval = 2

/obj/item/static_cuff/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	charge = max_charge

/obj/item/static_cuff/Destroy()
	set_active(FALSE)
	release_all_cameras() // set_active() early-returns if it was already off
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
		camera_sweep_accum = 0
		sweep_cameras()
		if(user)
			to_chat(user, span_notice("You flip the switch. \The [src] hums faintly, and the cameras around you drop to static."))
	else
		active = FALSE
		if(shielded_wearer)
			UnregisterSignal(shielded_wearer, COMSIG_LIVING_CAN_TRACK)
			unhide_from_ai_huds(shielded_wearer)
			shielded_wearer = null
		release_all_cameras()
		if(user)
			to_chat(user, span_notice("You flip the switch off. The cameras clear up."))
	update_processing()

/obj/item/static_cuff/proc/update_processing()
	if(active || charge < max_charge)
		START_PROCESSING(SSobj, src)
	else
		STOP_PROCESSING(SSobj, src)

/obj/item/static_cuff/process(seconds_per_tick)
	if(active)
		charge = max(charge - (seconds_per_tick SECONDS), 0)
		camera_sweep_accum += seconds_per_tick
		if(camera_sweep_accum >= camera_sweep_interval)
			camera_sweep_accum = 0
			sweep_cameras()
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

/// Brings the set of held cameras in line with what's actually in range right
/// now: cameras that just came into range get pinned, anything the wearer
/// walked away from gets released. Cosmetic only (see the class doc comment)
/// for why this can't touch the actual feed.
/obj/item/static_cuff/proc/sweep_cameras()
	var/turf/here = get_turf(src)
	var/list/should_be_jammed = list()
	if(here)
		for(var/obj/machinery/camera/nearby_camera in view(camera_range, here))
			if(!nearby_camera.can_use())
				continue
			should_be_jammed += nearby_camera

	// copy first: release_camera() edits jammed_cameras out from under us
	for(var/obj/machinery/camera/old_camera as anything in jammed_cameras?.Copy())
		if(!(old_camera in should_be_jammed))
			release_camera(old_camera)

	for(var/obj/machinery/camera/new_camera as anything in should_be_jammed)
		jam_camera(new_camera)

/// Pins one camera on its static sprite until we let go of it.
/obj/item/static_cuff/proc/jam_camera(obj/machinery/camera/target_camera)
	if(LAZYFIND(jammed_cameras, target_camera))
		return
	LAZYADD(jammed_cameras, target_camera)
	RegisterSignal(target_camera, COMSIG_ATOM_UPDATE_ICON_STATE, PROC_REF(on_jammed_camera_update))
	RegisterSignal(target_camera, COMSIG_QDELETING, PROC_REF(on_jammed_camera_deleted))
	target_camera.update_appearance(UPDATE_ICON_STATE)

/// Hands one camera back and lets it draw itself normally again.
/obj/item/static_cuff/proc/release_camera(obj/machinery/camera/target_camera)
	if(!LAZYFIND(jammed_cameras, target_camera))
		return
	LAZYREMOVE(jammed_cameras, target_camera)
	UnregisterSignal(target_camera, list(COMSIG_ATOM_UPDATE_ICON_STATE, COMSIG_QDELETING))
	if(!QDELETED(target_camera))
		target_camera.update_appearance(UPDATE_ICON_STATE)

/obj/item/static_cuff/proc/release_all_cameras()
	for(var/obj/machinery/camera/held_camera as anything in jammed_cameras?.Copy())
		release_camera(held_camera)
	jammed_cameras = null

/// COMSIG_ATOM_UPDATE_ICON_STATE fires at the tail of the camera's own
/// update_icon_state(), so writing icon_state here is the last word and the
/// static look holds steady instead of flickering.
/obj/item/static_cuff/proc/on_jammed_camera_update(obj/machinery/camera/source)
	SIGNAL_HANDLER
	source.icon_state = "[source.isXRay(TRUE) ? "xray" : ""][source.base_icon_state]_emp"

/obj/item/static_cuff/proc/on_jammed_camera_deleted(obj/machinery/camera/source)
	SIGNAL_HANDLER
	LAZYREMOVE(jammed_cameras, source)

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
// YELLOW: "Housecall"
// =============================================================================

/**
 * Subtypes the .38 revolver (code/modules/projectiles/guns/ballistic/revolver.dm)
 * for its icon/sprite and ammo economy. The design doc calls it a ".38",
 * matching the c38 revolver rather than the .357 base one. Its magazine
 * subtypes cylinder/rev38 specifically (not the .357 base cylinder) so the
 * caliber stays consistent with the c38 casings it's loaded with.
 */
/obj/item/gun/ballistic/revolver/c38/housecall
	name = "\"Housecall\""
	desc = "An integrally-suppressed .38 revolver with a doctor's-bag handle. Its rounds carry an anesthetic dart instead of a slug: 15 seconds of silence, 8 seconds of staggering, confusion, a chunk of stamina, and enough sedative to leave the target drowsy."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "housecall"
	// c38 sets base_icon_state = "c38" and ballistic/update_icon_state() rebuilds
	// icon_state from it on every update, without this the gun turns invisible.
	base_icon_state = "housecall"
	inhand_icon_state = "housecall"
	lefthand_file = 'voidcrew/modules/loot/icons/uniques_lefthand.dmi'
	righthand_file = 'voidcrew/modules/loot/icons/uniques_righthand.dmi'
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
	desc = "A .38 bullet casing loaded with a hair-fine anesthetic dart instead of a slug. Whoever it hits can't talk for 15 seconds and has a hard time staying upright."
	projectile_type = /obj/projectile/bullet/c38/housecall

/// Modest damage; the payload is the anesthetic, not the hole. The dart mutes,
/// staggers, muddles and pushes the target toward sleep, enough to take
/// someone out of a fight without killing them outright.
/obj/projectile/bullet/c38/housecall
	name = "subdermal dart"
	damage = 15
	stamina = 25
	/// How long the anesthetic silences a hit target for.
	var/mute_duration = 15 SECONDS
	/// How long the target staggers for.
	var/stagger_duration = 8 SECONDS
	/// Confusion added on hit.
	var/confusion_duration = 6 SECONDS
	/// Drowsiness added on hit, capped so repeat hits can't stack it forever.
	var/drowsy_duration = 10 SECONDS
	/// Ceiling for the drowsiness this dart will push someone to.
	var/drowsy_cap = 30 SECONDS

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
	victim.adjust_staggered_up_to(stagger_duration, stagger_duration * 2)
	victim.adjust_confusion(confusion_duration)
	victim.adjust_drowsiness_up_to(drowsy_duration, drowsy_cap)
	to_chat(victim, span_danger("Your throat closes up and the room tilts."))
	return .

// =============================================================================
// RED: Second Shadow
// =============================================================================

/**
 * Deviation from the design doc: there's no ready-made "spawn a decoy mob
 * that eats the hit for you" mechanic in this codebase. What's real and
 * reused here:
 *  - The exact signal set /datum/status_effect/stun_absorption listens to
 *    (code/datums/status_effects/buffs/stun_absorption.dm), knockdown,
 *    stun, paralyze, immobilize, incapacitate, all resolve through
 *    SEND_SIGNAL(..., amount, ignore_canstun) and respect COMPONENT_NO_STUN
 *    as a cancel. We hook those five signals directly (rather than reusing
 *    the shared status effect class itself, to avoid interacting with other
 *    unrelated stun_absorption stacking priority elsewhere in the game).
 *  - The appearance-copy technique from /datum/component/reflection
 *    (code/datums/components/reflection.dm): copy_appearance_filter_overlays()
 *    onto a temp_visual effect placed where the wearer stood.
 *  - "Crit-threshold hit" specifically isn't its own signal in this
 *    codebase, attacks that would put someone in crit generally also
 *    apply a knockdown/stun as part of the same swing, so the five
 *    incapacitation signals are the closest real hook and cover the
 *    intended cases in practice.
 *  - "Slip one tile in a direction of your choosing" is simplified to a
 *    random open adjacent tile: the interception happens synchronously
 *    inside a signal handler mid-attack, with no opportunity for a
 *    do_after/UI prompt to ask the (about to be stunned) player anything.
 */
// The cloak's hood, tinted to match, an untinted goliath hood renders bright red.
/obj/item/clothing/head/hooded/cloakhood/goliath/second_shadow
	color = "#3a3a45"

/obj/item/clothing/suit/hooded/cloak/second_shadow
	name = "Second Shadow"
	desc = "A heavy dark cloak that seems to move half a second after you do. With the hood up, a hit that would put you down leaves a decoy standing there instead. 3 minute cooldown between saves."
	// Custom folded-cloak obj icon. The worn sprite borrows the goliath cloak,
	// darkened to match the flavor, copied into uniques_worn.dmi: the hood
	// component (toggle_attached_clothing) overwrites worn_icon_state with
	// icon_state on every toggle, so both files must share state names
	// (shadow_cloak / shadow_cloak_t) or the worn sprite silently breaks.
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "shadow_cloak"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "shadow_cloak"
	hoodtype = /obj/item/clothing/head/hooded/cloakhood/goliath/second_shadow
	color = "#3a3a45"
	/// Whether the hood is currently deployed on the wearer's head.
	var/hood_up = FALSE
	/// Cooldown between decoy triggers.
	COOLDOWN_DECLARE(decoy_cooldown)
	var/decoy_cooldown_time = 3 MINUTES
	/// Stops "still recharging" from printing on every single hit in a beating.
	COOLDOWN_DECLARE(fail_message_cooldown)
	var/fail_message_cooldown_time = 10 SECONDS
	/// How long the wearer stays invisible/displaced after triggering.
	var/decoy_effect_duration = 3 SECONDS
	/// Who is currently being shown the recharge alert, so we can clear it off
	/// the right mob when the cloak comes off.
	var/mob/living/alerted_wearer
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

/obj/item/clothing/suit/hooded/cloak/second_shadow/Destroy()
	clear_recharge_alert()
	return ..()

/obj/item/clothing/suit/hooded/cloak/second_shadow/examine(mob/user)
	. = ..()
	if(COOLDOWN_FINISHED(src, decoy_cooldown))
		. += span_notice("It's ready. Put the hood up and it'll take the next hit that would put you down.")
	else
		. += span_notice("It's recharging. [DisplayTimeText(COOLDOWN_TIMELEFT(src, decoy_cooldown))] left.")

/obj/item/clothing/suit/hooded/cloak/second_shadow/on_hood_up(obj/item/clothing/head/hooded/hood)
	. = ..()
	hood_up = TRUE

/obj/item/clothing/suit/hooded/cloak/second_shadow/on_hood_down(obj/item/clothing/head/hooded/hood)
	. = ..()
	hood_up = FALSE

/obj/item/clothing/suit/hooded/cloak/second_shadow/equipped(mob/user, slot)
	. = ..()
	if(slot & ITEM_SLOT_OCLOTHING)
		RegisterSignals(user, intercepted_signals, PROC_REF(try_intercept), override = TRUE)
		// putting the cloak back on mid-cooldown picks the countdown back up
		if(!COOLDOWN_FINISHED(src, decoy_cooldown))
			show_recharge_alert(user)
		return
	UnregisterSignal(user, intercepted_signals)
	clear_recharge_alert()
	hood_up = FALSE

/obj/item/clothing/suit/hooded/cloak/second_shadow/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, intercepted_signals)
	clear_recharge_alert()
	hood_up = FALSE

/// Puts the countdown alert on the wearer for whatever is left of the cooldown.
/obj/item/clothing/suit/hooded/cloak/second_shadow/proc/show_recharge_alert(mob/living/wearer)
	clear_recharge_alert()
	if(!isliving(wearer))
		return
	var/time_left = COOLDOWN_TIMELEFT(src, decoy_cooldown)
	if(time_left <= 0)
		return
	alerted_wearer = wearer
	wearer.apply_status_effect(/datum/status_effect/syndicate_recharge/second_shadow, time_left)

/// Takes the alert back off. Removing it early is silent - see the status
/// effect's on_remove().
/obj/item/clothing/suit/hooded/cloak/second_shadow/proc/clear_recharge_alert()
	if(isnull(alerted_wearer))
		return
	if(!QDELETED(alerted_wearer))
		alerted_wearer.remove_status_effect(/datum/status_effect/syndicate_recharge/second_shadow)
	alerted_wearer = null

/// Signal handler for the incapacitation signals, see intercepted_signals.
/// All five share the (source, amount, ignore_canstun) shape.
/obj/item/clothing/suit/hooded/cloak/second_shadow/proc/try_intercept(mob/living/source, amount, ignore_canstun)
	SIGNAL_HANDLER

	if(!hood_up || amount <= 0 || ignore_canstun)
		return NONE
	if(!COOLDOWN_FINISHED(src, decoy_cooldown))
		// tell them why the cloak didn't save them, but not once per punch
		if(COOLDOWN_FINISHED(src, fail_message_cooldown))
			COOLDOWN_START(src, fail_message_cooldown, fail_message_cooldown_time)
			to_chat(source, span_warning("The cloak hangs dead on your shoulders. It's still recharging - [DisplayTimeText(COOLDOWN_TIMELEFT(src, decoy_cooldown))] left."))
		return NONE

	COOLDOWN_START(src, decoy_cooldown, decoy_cooldown_time)
	show_recharge_alert(source)
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
		span_warning("The blow passes clean through [wearer], and the shape flickers and slips aside!"),
		span_userdanger("The cloak snaps you out of the way. The hit lands on empty air!"),
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
/// the moment of interception. Purely cosmetic, see spawn_decoy().
/obj/effect/temp_visual/second_shadow_decoy
	name = "flickering shape"
	randomdir = FALSE
	duration = 3 SECONDS

// =============================================================================
// RED: "Understudy"
// =============================================================================

/**
 * Deviation from the design doc: full DNA/species-level identity swap (the
 * changeling "transform" power, code/modules/antagonists/changeling/powers/transform.dm)
 * is built entirely around the changeling antag datum and an absorbed-DNA
 * profile list, there's no standalone entry point to reuse it for a plain
 * loot item. Instead this copies the three independently real, lighter
 * levers this codebase exposes:
 *  - display name (mob/name)
 *  - "voice" identity used by get_voice()/radio recognition, via the real
 *    override_voice var on human mobs
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
	desc = "A chameleon-finish knife that never has fingerprints on it, including yours. Put someone down with it and you have 10 seconds to take their face and voice for 10 minutes. Use it in your hand again to drop the disguise."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "understudy"
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

/obj/item/knife/understudy/Destroy()
	deltimer(mark_timer_id)
	mark_timer_id = null
	marked_target_ref = null
	return ..()

/obj/item/knife/understudy/examine(mob/user)
	. = ..()
	var/mob/living/carbon/human/actor = user
	if(ishuman(actor) && actor.has_status_effect(/datum/status_effect/understudy_disguise))
		. += span_notice("You're wearing someone else's face right now. Use this in your hand to drop it.")
		return
	var/mob/living/carbon/human/marked = marked_target_ref?.resolve()
	if(istype(marked))
		. += span_notice("[marked]'s face is still fresh enough to copy. Use this in your hand to take it.")

/obj/item/knife/understudy/attack(mob/living/target_mob, mob/living/user, list/modifiers, list/attack_modifiers)
	// This was `stat < UNCONSCIOUS` / `stat >= UNCONSCIOUS`. The post-merge sweep
	// swapped UNCONSCIOUS for HARD_CRIT, which preserved the enum's NUMBER (both 2)
	// but not its meaning: upstream deleted the stat and made being out cold a trait,
	// so the knife stopped marking anyone it merely knocked unconscious and only fired
	// on a hard-crit transition. IS_UNCONSCIOUS() is upstream's replacement.
	var/was_downed = istype(target_mob) && target_mob.stat != DEAD && !IS_UNCONSCIOUS(target_mob)
	. = ..()
	if(!istype(target_mob) || !ishuman(target_mob))
		return .
	if(target_mob.stat == DEAD || (was_downed && IS_UNCONSCIOUS(target_mob)))
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
		to_chat(user, span_warning("You'd need a human face to pull this off."))
		return

	var/mob/living/carbon/human/actor = user
	var/datum/status_effect/understudy_disguise/existing = actor.has_status_effect(/datum/status_effect/understudy_disguise)
	// second use drops the act - the disguise used to have no off switch at all
	if(existing)
		qdel(existing)
		return

	if(isnull(marked_target_ref))
		to_chat(user, span_warning("You haven't put anyone down recently enough to copy."))
		return
	var/mob/living/carbon/human/target = marked_target_ref.resolve()
	if(!istype(target))
		to_chat(user, span_warning("Whoever you had in mind is gone."))
		clear_mark()
		return

	actor.apply_status_effect(/datum/status_effect/understudy_disguise, target, disguise_duration)
	to_chat(actor, span_notice("You take on [target]'s face and voice for [DisplayTimeText(disguise_duration)]. Use [src] in your hand again to drop it."))
	deltimer(mark_timer_id)
	clear_mark()

/datum/status_effect/understudy_disguise
	id = "understudy_disguise"
	alert_type = /atom/movable/screen/alert/status_effect/understudy_disguise
	show_duration = TRUE
	tick_interval = STATUS_EFFECT_NO_TICK
	remove_on_fullheal = FALSE
	/// The name we're overriding, restored on removal.
	var/old_name
	/// Who we copied: held only long enough to apply the effect.
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
	wear_appearance(actor, copied_from)
	actor.name = copied_from.name
	// VOIDCREW EDIT: upstream deleted SetSpecialVoice()/UnsetSpecialVoice() and the special_voice
	// var; get_voice() now reads override_voice directly, which is what the changeling uses too.
	actor.override_voice = copied_from.real_name
	copied_from = null // done with it, don't hold the ref for the full 10 minutes
	return TRUE

/**
 * Puts the target's look on the actor without dragging along the vars that
 * describe the actor's own body rather than their appearance.
 *
 * A BYOND /appearance carries transform, dir, layer, plane, pixel offsets and
 * a pile of other atom vars with it. Copying someone who was lying down when
 * you knifed them used to hand you their rotation matrix permanently: nothing
 * ever resets transform from scratch, update_transform() applies each later
 * lying/standing change on top of whatever matrix is already on the mob, so
 * the borrowed rotation stuck for the rest of the round. Keeping our own copies
 * of those vars across the assignment means the body never desyncs in the first
 * place, and removal only has to put the name, voice and overlays back.
 */
/datum/status_effect/understudy_disguise/proc/wear_appearance(mob/living/carbon/human/actor, mob/living/carbon/human/target)
	var/matrix/own_transform = actor.transform
	var/own_dir = actor.dir
	var/own_layer = actor.layer
	var/own_plane = actor.plane
	var/own_pixel_x = actor.pixel_x
	var/own_pixel_y = actor.pixel_y
	var/own_pixel_w = actor.pixel_w
	var/own_pixel_z = actor.pixel_z
	var/own_alpha = actor.alpha
	var/own_invisibility = actor.invisibility
	var/own_opacity = actor.opacity
	var/own_luminosity = actor.luminosity
	var/own_mouse_opacity = actor.mouse_opacity
	var/own_render_target = actor.render_target
	var/own_render_source = actor.render_source
	var/own_gender = actor.gender
	var/own_desc = actor.desc
	var/own_maptext = actor.maptext
	var/own_maptext_width = actor.maptext_width
	var/own_maptext_height = actor.maptext_height
	var/own_maptext_x = actor.maptext_x
	var/own_maptext_y = actor.maptext_y

	actor.appearance = copy_appearance_filter_overlays(target.appearance)

	actor.transform = own_transform
	actor.setDir(own_dir)
	actor.layer = own_layer
	actor.plane = own_plane
	actor.pixel_x = own_pixel_x
	actor.pixel_y = own_pixel_y
	actor.pixel_w = own_pixel_w
	actor.pixel_z = own_pixel_z
	actor.alpha = own_alpha
	actor.invisibility = own_invisibility
	actor.opacity = own_opacity
	actor.luminosity = own_luminosity
	actor.mouse_opacity = own_mouse_opacity
	actor.render_target = own_render_target
	actor.render_source = own_render_source
	actor.gender = own_gender
	actor.desc = own_desc
	actor.maptext = own_maptext
	actor.maptext_width = own_maptext_width
	actor.maptext_height = own_maptext_height
	actor.maptext_x = own_maptext_x
	actor.maptext_y = own_maptext_y

/datum/status_effect/understudy_disguise/on_remove()
	if(!ishuman(owner))
		return
	var/mob/living/carbon/human/actor = owner
	actor.name = old_name
	actor.override_voice = "" // VOIDCREW EDIT: was UnsetSpecialVoice(), deleted upstream
	// Full rebuild: the disguise replaced the whole appearance snapshot, and
	// update_body() alone wouldn't restore worn gear / held item overlays
	actor.regenerate_icons()
	to_chat(actor, span_notice("You drop the act. Your own face comes back."))

/// HUD alert for the stolen face, with a countdown on how long it holds.
/atom/movable/screen/alert/status_effect/understudy_disguise
	name = "Borrowed Face"
	desc = "You're wearing someone else's face and voice. Use the knife in your hand to drop it early."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "alert_understudy"

// =============================================================================
// Shared: "this thing is recharging" HUD countdown
// =============================================================================

/**
 * Cooldowns on these items live on the item (COOLDOWN_DECLARE), which is
 * invisible to the player. This puts that timer on their screen: a HUD alert
 * with a live countdown for as long as the item is recharging, then one line
 * and a beep the moment it comes back.
 *
 * The item hands us the time remaining, so putting the item back on partway
 * through the cooldown picks the countdown back up where it left off. Removing
 * the effect early (taking the item off) is silent, only the countdown
 * actually running out counts as "ready".
 */
/datum/status_effect/syndicate_recharge
	id = "syndicate_recharge"
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_REPLACE
	show_duration = TRUE
	remove_on_fullheal = FALSE
	// Only ever applied through a subtype, and each of those brings its own alert.
	alert_type = null
	/// Printed to the owner when the countdown runs out.
	var/ready_message = "Your gear is ready again."

/datum/status_effect/syndicate_recharge/on_creation(mob/living/new_owner, duration = 30 SECONDS)
	src.duration = duration
	return ..()

/datum/status_effect/syndicate_recharge/on_remove()
	// duration is a world.time deadline by this point: still in the future
	// means something removed us early, which shouldn't announce anything
	if(duration != STATUS_EFFECT_PERMANENT && duration > world.time)
		return
	to_chat(owner, span_notice(ready_message))
	SEND_SOUND(owner, sound('sound/machines/beep/twobeep.ogg', volume = 25))

/datum/status_effect/syndicate_recharge/courier_palm
	id = "courier_palm_recharge"
	alert_type = /atom/movable/screen/alert/status_effect/courier_palm_recharge
	ready_message = "The courier's palm goes warm again. It's ready."

/atom/movable/screen/alert/status_effect/courier_palm_recharge
	name = "Palm Recharging"
	desc = "The courier's palm is recharging. Until it's done, lifting things off people takes the usual time."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "alert_courier_palm"

/datum/status_effect/syndicate_recharge/second_shadow
	id = "second_shadow_recharge"
	alert_type = /atom/movable/screen/alert/status_effect/second_shadow_recharge
	ready_message = "Second Shadow settles on your shoulders again. It'll take the next hit."

/atom/movable/screen/alert/status_effect/second_shadow_recharge
	name = "Cloak Recharging"
	desc = "Second Shadow is recharging. Until it's done, a hit that puts you down just puts you down."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "alert_second_shadow"

#undef FREQ_LISTENING_COIN
