/**
 * # WARDROBE uniques: couturier's trunk
 *
 * Five unique loot items for the wardrobe (`loot_uniques`) zone-loot
 * tables (voidcrew/modules/loot/themes/wardrobe.dm). Identity loot: nothing
 * here is a bigger number, every piece is a mechanic. All of them carry
 * TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so duplicators (Helios
 * pattern stamp and friends) refuse to copy them.
 *
 * 2026-07-28 playtest pass:
 * - The understudy's cravat was cut. Its only workable implementation was a
 *   flat getFlatIcon() overlay that never interacted with anything, so the
 *   green tier is one item lighter rather than carrying a dud.
 * - Winter's loafers and the heirloom coat got custom art: "winters_loafers"
 *   and "heirloom_coat" in uniques.dmi (obj) and uniques_worn.dmi (worn, 4
 *   dirs). Both worn states are drawn on the matching vanilla worn pixel
 *   masks, feet.dmi "laceups" and suits/armor.dmi "hostrench", so the body
 *   zones line up exactly, recoloured (oxblood leather, charcoal-green wool
 *   with brass fittings). Neither donor is GAGS-drawn, so no greyscale vars
 *   are involved.
 * - Stage presence, the heirloom coat and "the Occasion" all print their real
 *   numbers now, on examine and in their refusal messages.
 * - The third hand kit and "the Occasion" were both broken; root causes are
 *   documented on the types themselves.
 */

// =========================================================================
// GREEN
// =========================================================================

/**
 * Winter's loafers: negates worn-gear slowdown, silences footsteps.
 *
 * Subtypes /obj/item/clothing/shoes/laceup (code/modules/clothing/shoes/laceup.dm)
 * for the shoe class behaviour (laces, fishing penalty, armor_type) but
 * carries its own art. In-hand sprites are left as the stock laceup ones,
 * i.e. none, laceups have no state in shoes_lefthand.dmi upstream either.
 *
 * Deviation: there's no per-item hook in this codebase that zeroes only
 * *equipment* slowdown while leaving terrain/status slowdown alone (see
 * /mob/living/carbon/human/get_movespeed_modifiers(),
 * code/modules/mob/living/carbon/human/human_movement.dm). The closest real
 * lever is TRAIT_IGNORESLOWDOWN, applied/removed via the existing
 * ignore_slowdown()/unignore_slowdown() pair
 * (code/modules/mob/living/status_procs.dm), it strips *all* slowdown
 * sources that lack the IGNORE_NOSLOW flag, not just clothing.
 *
 * Footstep silence is full TRAIT_SILENT_FOOTSTEPS while worn
 * (code/__DEFINES/footsteps.dm), not surface-restricted, there's no
 * "silent on this footstep type only" trait to key off.
 */
/obj/item/clothing/shoes/laceup/winters_loafers
	name = "Winter's loafers"
	desc = "Oxblood leather loafers, resoled more times than anyone can count. Nothing you're wearing slows you down in them, and nobody hears you coming."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "winters_loafers"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "winters_loafers"
	custom_price = PAYCHECK_CREW * 4

/obj/item/clothing/shoes/laceup/winters_loafers/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/shoes/laceup/winters_loafers/examine(mob/user)
	. = ..()
	. += span_notice("While you've got them on, nothing you're wearing slows you down.")
	. += span_notice("They also make your footsteps silent.")

/obj/item/clothing/shoes/laceup/winters_loafers/equipped(mob/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_FEET))
		return
	var/mob/living/wearer = user
	if(!istype(wearer))
		return
	wearer.ignore_slowdown(REF(src))
	ADD_TRAIT(wearer, TRAIT_SILENT_FOOTSTEPS, REF(src))

/obj/item/clothing/shoes/laceup/winters_loafers/dropped(mob/user)
	. = ..()
	var/mob/living/wearer = user
	if(!istype(wearer))
		return
	wearer.unignore_slowdown(REF(src))
	REMOVE_TRAIT(wearer, TRAIT_SILENT_FOOTSTEPS, REF(src))

// =========================================================================
// YELLOW
// =========================================================================

/**
 * Stage presence: activation taunt: turns heads, pulls hostile aggro, amplifies voice.
 *
 * No cavalier/musketeer/plumed hat type exists anywhere in this codebase, so
 * this is a fresh root under /obj/item/clothing/head with custom art:
 * "stage_presence" in uniques.dmi (obj) and uniques_worn.dmi (worn).
 *
 * Playtest fix (2026-07-28): the not-ready refusal said "needs a moment"
 * without a number. It now prints the real remaining cooldown, and examine
 * shows it too.
 */
/obj/item/clothing/head/stage_presence
	name = "stage presence"
	desc = "A plumed cavalier hat. Sweep it off and every head in the room turns your way, friendly or not."
	// Custom obj icon; custom worn sprite derived from the same cavalier-hat art
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "stage_presence"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "stage_presence"
	inhand_icon_state = null
	lefthand_file = 'icons/mob/inhands/clothing/hats_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/clothing/hats_righthand.dmi'
	custom_price = PAYCHECK_CREW * 6
	// Worn-slot activation path: attack_self alone is unreachable while the
	// hat is on your head, so the action button (which routes back into
	// attack_self via ui_action_click) is the reachable path
	actions_types = list(/datum/action/item_action/toggle)
	/// Chat span(s) applied to the wearer's speech during the amplified window, megaphone-style
	var/list/voicespan = list(SPAN_COMMAND)
	/// How long the amplified-voice window lasts once triggered
	var/amplify_duration = 6 SECONDS
	/// How far the taunt reaches for retarget/turn-heads purposes
	var/taunt_range = 7
	/// How long between taunts
	var/presence_cooldown_time = 1 MINUTES
	COOLDOWN_DECLARE(presence_cooldown)

/obj/item/clothing/head/stage_presence/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/head/stage_presence/examine(mob/user)
	. = ..()
	. += span_notice("Wear it and use the action button to take the stage: everyone nearby turns to face you, hostile creatures switch to you as their target, and your voice carries for [DisplayTimeText(amplify_duration)].")
	. += span_notice("The hat comes off into your hand when you do it.")
	if(COOLDOWN_FINISHED(src, presence_cooldown))
		. += span_notice("It's ready to use.")
	else
		. += span_warning("It's ready again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, presence_cooldown))].")

/obj/item/clothing/head/stage_presence/attack_self(mob/user)
	. = ..()
	var/mob/living/wearer = user
	if(!istype(wearer) || wearer.get_item_by_slot(ITEM_SLOT_HEAD) != src)
		balloon_alert(user, "not worn!")
		return
	if(!COOLDOWN_FINISHED(src, presence_cooldown))
		var/time_left = DisplayTimeText(COOLDOWN_TIMELEFT(src, presence_cooldown))
		balloon_alert(user, "ready in [time_left]")
		to_chat(user, span_warning("[src] isn't ready. You can take the stage again in [time_left]."))
		return
	COOLDOWN_START(src, presence_cooldown, presence_cooldown_time)
	take_the_stage(wearer)

/// The doff-and-taunt: heads turn, hostiles retarget, voice carries for a few seconds.
/obj/item/clothing/head/stage_presence/proc/take_the_stage(mob/living/wearer)
	wearer.visible_message(
		span_bolddanger("[wearer] sweeps off [src] with a flourish, every eye in the room follows!"),
		span_boldnotice("You take the stage. Your voice carries for the next [DisplayTimeText(amplify_duration)]."),
	)
	for(var/mob/onlooker in view(taunt_range, wearer))
		if(onlooker == wearer)
			continue
		onlooker.setDir(get_dir(onlooker, wearer))
		if(!istype(onlooker, /mob/living/basic))
			continue
		var/mob/living/basic/beast = onlooker
		if(!beast.ai_controller || faction_check(wearer.faction, beast.faction))
			continue
		beast.ai_controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, wearer)

	RegisterSignal(wearer, COMSIG_MOB_SAY, PROC_REF(amplify_speech), override = TRUE)
	addtimer(CALLBACK(src, PROC_REF(end_amplify), wearer), amplify_duration)

	// Doff, theatrically: the hat leaves the head into a free hand (or the floor).
	wearer.temporarilyRemoveItemFromInventory(src)
	if(!wearer.put_in_hands(src))
		src.forceMove(get_turf(wearer))

/// Megaphone-style speech span injection (see code/game/objects/items/devices/megaphone.dm) while the stage window is open.
/obj/item/clothing/head/stage_presence/proc/amplify_speech(mob/living/speaker, list/speech_args)
	SIGNAL_HANDLER
	speech_args[SPEECH_SPANS] |= voicespan

/obj/item/clothing/head/stage_presence/proc/end_amplify(mob/living/wearer)
	if(isnull(wearer))
		return
	UnregisterSignal(wearer, COMSIG_MOB_SAY)
	to_chat(wearer, span_notice("Your voice settles back to normal."))

/**
 * Third hand sewing kit: permanent appearance transplant between two garments.
 *
 * No sewing/tailoring item exists anywhere in this codebase. Built as a fresh
 * /obj/item root with the custom "third_hand_kit" state in uniques.dmi, and
 * the lockbox's in-hand sprite (icons/mob/inhands/equipment/briefcase_*.dmi,
 * state "lockbox") so it isn't invisible while you're carrying it.
 *
 * Two-click interaction: first click on a donor garment loads it as the
 * pattern, second click on a different, slot-compatible garment copies the
 * donor's visual vars onto it (permanently) and consumes the donor. Stats,
 * armor and name are untouched, only the rendering vars move.
 *
 * BUG FIX (2026-07-28, "doesnt actually work"): both legs used to live in
 * afterattack(), which never runs when you click another *item*.
 * /obj/item sets `obj_flags = NONE` (code/game/objects/items.dm), so items
 * don't carry CAN_BE_HIT; /obj/attackby() bails on that check before it ever
 * reaches attack_atom(), and attack_atom() is the only thing that calls
 * afterattack() for non-mob targets (code/_onclick/item_attack.dm). Clicking
 * a garment with the kit therefore did nothing at all, silently, in both
 * legs. Moved to interact_with_atom(), which base_item_interaction() calls on
 * every item-on-atom click before storage insertion or any combat handling,
 * the same path the other uniques in this module use.
 */
/obj/item/third_hand_kit
	name = "third hand sewing kit"
	desc = "A rosewood sewing kit with a needle that threads itself. Click one garment to pin it as a pattern, then click another to make it look exactly the same."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "third_hand_kit"
	inhand_icon_state = "lockbox"
	lefthand_file = 'icons/mob/inhands/equipment/briefcase_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/equipment/briefcase_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	throwforce = 0
	custom_price = PAYCHECK_CREW * 5
	/// How long the re-cut takes
	var/retailor_time = 3 SECONDS
	/// The garment currently pinned in as the donor pattern, if any
	var/datum/weakref/loaded_donor

/obj/item/third_hand_kit/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/third_hand_kit/examine(mob/user)
	. = ..()
	. += span_notice("Click a garment to pin it as the pattern, then click a second garment of the same kind to re-cut it. The re-cut takes [DisplayTimeText(retailor_time)].")
	. += span_notice("The pattern garment is used up. Only the look moves across - armor, pockets and name stay exactly as they were.")
	var/obj/item/clothing/donor = loaded_donor?.resolve()
	if(QDELETED(donor))
		. += span_notice("Nothing is pinned in it right now.")
	else
		. += span_notice("[donor] is pinned in as the pattern. Use the kit in your hand to unpin it.")

/// Using the kit in hand drops the pinned pattern back out of the frame.
/obj/item/third_hand_kit/attack_self(mob/user)
	. = ..()
	var/obj/item/clothing/donor = loaded_donor?.resolve()
	if(QDELETED(donor))
		balloon_alert(user, "nothing pinned")
		return
	loaded_donor = null
	balloon_alert(user, "pattern unpinned")
	to_chat(user, span_notice("You unpin [donor] from the kit."))

/obj/item/third_hand_kit/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!istype(interacting_with, /obj/item/clothing))
		return NONE
	var/obj/item/clothing/garment = interacting_with

	var/obj/item/clothing/donor = loaded_donor?.resolve()
	if(QDELETED(donor))
		loaded_donor = null
		// First leg: pin the donor pattern.
		if(HAS_TRAIT(garment, TRAIT_NO_REPLICATE))
			balloon_alert(user, "too unique to copy!")
			return ITEM_INTERACT_BLOCKING
		loaded_donor = WEAKREF(garment)
		balloon_alert(user, "pattern pinned")
		to_chat(user, span_notice("You pin [garment] into the kit as a pattern piece. Now click a garment worn in the same slot to re-cut it."))
		return ITEM_INTERACT_SUCCESS

	// Second leg: re-cut the target off the pinned donor.
	if(donor == garment)
		balloon_alert(user, "that's the pattern piece!")
		return ITEM_INTERACT_BLOCKING
	if(!(donor.slot_flags & garment.slot_flags))
		balloon_alert(user, "wrong shape for this pattern!")
		to_chat(user, span_warning("[donor] and [garment] aren't worn in the same place. The pattern won't fit."))
		return ITEM_INTERACT_BLOCKING

	balloon_alert(user, "re-cutting...")
	if(!do_after(user, retailor_time, target = garment))
		return ITEM_INTERACT_BLOCKING
	// The pattern can be destroyed or moved out of reach mid-stitch.
	donor = loaded_donor?.resolve()
	if(QDELETED(donor) || QDELETED(garment))
		loaded_donor = null
		balloon_alert(user, "pattern's gone!")
		return ITEM_INTERACT_BLOCKING

	retailor(garment, donor)
	user.visible_message(
		span_notice("[user] re-cuts [garment] on [src]."),
		span_notice("[garment] takes on the exact look of [donor], which comes apart into scraps."),
	)
	playsound(src, 'sound/items/handling/cloth/cloth_drop1.ogg', 40, TRUE)
	qdel(donor)
	loaded_donor = null
	return ITEM_INTERACT_SUCCESS

/// Copies the donor's rendering vars onto the target garment, permanently. Stats untouched.
/obj/item/third_hand_kit/proc/retailor(obj/item/clothing/target, obj/item/clothing/donor)
	target.icon = donor.icon
	target.icon_state = donor.icon_state
	target.worn_icon = donor.worn_icon
	target.worn_icon_state = donor.worn_icon_state
	target.inhand_icon_state = donor.inhand_icon_state
	target.lefthand_file = donor.lefthand_file
	target.righthand_file = donor.righthand_file
	// GAGS-rendered donors (most basic clothing) draw from their greyscale
	// config, not raw icon_state, without carrying these over, the copy
	// renders with the target's old config or not at all. update_appearance()
	// re-runs update_greyscale() for us.
	target.greyscale_config = donor.greyscale_config
	target.greyscale_config_worn = donor.greyscale_config_worn
	target.greyscale_config_inhand_left = donor.greyscale_config_inhand_left
	target.greyscale_config_inhand_right = donor.greyscale_config_inhand_right
	target.greyscale_colors = donor.greyscale_colors
	target.update_appearance()
	var/mob/wearer = target.loc
	if(ismob(wearer))
		wearer.update_clothing(target.slot_flags)
		wearer.update_held_items()

// =========================================================================
// RED
// =========================================================================

/// Bare weave: the heirloom coat's day-one condition.
/datum/armor/heirloom_bare

/// Twenty minutes in: the weave starts setting.
/datum/armor/heirloom_light
	melee = 15
	bullet = 10
	laser = 10
	energy = 10
	bomb = 10
	fire = 20
	acid = 20
	wound = 5

/// Forty minutes: noticeably heavier, holding its shape.
/datum/armor/heirloom_vest
	melee = 30
	bullet = 25
	laser = 25
	energy = 25
	bomb = 20
	fire = 40
	acid = 40
	wound = 10

/// Sixty minutes, as close to plate as cloth gets.
/datum/armor/heirloom_riot
	melee = 50
	bullet = 35
	laser = 25
	energy = 20
	bomb = 30
	fire = 60
	acid = 60
	wound = 15

/**
 * The heirloom coat: armor that grows with unbroken wear-time.
 *
 * Subtypes /obj/item/clothing/suit/armor/hos/trenchcoat
 * (code/modules/clothing/suits/armor.dm) for its coverage and cold/heat
 * protection. It's a Head-of-Security reskin upstream but carries no
 * HoS-specific procs or restrictions, so subtyping it is safe. Art is
 * custom as of 2026-07-28: "heirloom_coat" in uniques.dmi (obj) and
 * uniques_worn.dmi (worn, 4 dirs, drawn on the vanilla "hostrench" worn
 * mask). In-hand sprites stay on the stock "hostrench" states.
 *
 * Four armor stages (bare -> light -> vest -> riot-ish), one step every 20
 * unbroken minutes worn, tracked via a self-rescheduling addtimer keyed to
 * the current wearer. Taking the coat off resets both the timer and the
 * armor tier to stage 0.
 *
 * Playtest fix (2026-07-28): examine now prints the current stage, the actual
 * armor numbers, and the time left on the current stage.
 */
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat
	name = "the heirloom coat"
	desc = "A long wool coat, older than the shipping line that lost it. The longer you keep it on without taking it off, the tougher it gets."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "heirloom_coat"
	worn_icon = 'voidcrew/modules/loot/icons/uniques_worn.dmi'
	worn_icon_state = "heirloom_coat"
	inhand_icon_state = "hostrench"
	flags_inv = 0
	armor_type = /datum/armor/heirloom_bare
	custom_price = PAYCHECK_CREW * 8
	/// Current fitting stage: 0 (bare) through length(wear_stage_armors) - 1 (riot-ish)
	var/wear_stage = 0
	/// How long an unbroken stage takes to set
	var/wear_stage_time = 20 MINUTES
	/// Armor datum typepaths per stage, index 1 == stage 0
	var/static/list/wear_stage_armors = list(
		/datum/armor/heirloom_bare,
		/datum/armor/heirloom_light,
		/datum/armor/heirloom_vest,
		/datum/armor/heirloom_riot,
	)
	/// Short name for each stage, index 1 == stage 0
	var/static/list/wear_stage_names = list(
		"loose",
		"broken in",
		"heavy",
		"stiff as plate",
	)
	/// Flavor message printed on stepping into stage 1/2/3 (index 1 == stage 1)
	var/static/list/wear_stage_messages = list(
		"settles in around your shoulders and stops feeling borrowed",
		"has gone noticeably heavier, and it's holding your shape now",
		"has gone stiff at every seam, closer to plate than cloth",
	)
	/// Timer id for the next stage step, so it can be cancelled on unequip
	var/wear_timer_id
	/// Weakref to whoever is currently earning stages on this coat
	var/datum/weakref/current_wearer

/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/Destroy()
	deltimer(wear_timer_id)
	wear_timer_id = null
	current_wearer = null
	return ..()

/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/examine(mob/user)
	. = ..()
	var/max_stage = length(wear_stage_armors) - 1
	. += span_notice("Fit: [wear_stage_names[wear_stage + 1]] (stage [wear_stage] of [max_stage]).")

	var/datum/armor/current = get_armor()
	. += span_notice("Armor right now - melee [current.get_rating(MELEE)], bullet [current.get_rating(BULLET)], laser [current.get_rating(LASER)], energy [current.get_rating(ENERGY)], bomb [current.get_rating(BOMB)], fire [current.get_rating(FIRE)], acid [current.get_rating(ACID)], wound [current.get_rating(WOUND)].")

	if(wear_stage >= max_stage)
		. += span_notice("It's as broken in as it gets.")
	else
		var/time_left = wear_timer_id ? timeleft(wear_timer_id) : null
		if(isnum(time_left) && time_left > 0)
			. += span_notice("Next stage in [DisplayTimeText(time_left)] of unbroken wear.")
		else
			. += span_notice("Each stage takes [DisplayTimeText(wear_stage_time)] of unbroken wear. Put it on to start the clock.")
	. += span_warning("Taking it off drops it back to stage 0.")

/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/equipped(mob/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_OCLOTHING))
		return
	current_wearer = WEAKREF(user)
	schedule_next_stage()

/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/dropped(mob/user)
	. = ..()
	reset_fit()

/// (Re)arms the next stage-up timer, unless we're already fully broken in.
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/proc/schedule_next_stage()
	deltimer(wear_timer_id)
	wear_timer_id = null
	if(wear_stage >= length(wear_stage_armors) - 1)
		return
	wear_timer_id = addtimer(CALLBACK(src, PROC_REF(advance_stage)), wear_stage_time, TIMER_STOPPABLE)

/// Steps the coat's armor up one tier, so long as it's still on the same wearer.
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/proc/advance_stage()
	wear_timer_id = null
	var/mob/living/wearer = current_wearer?.resolve()
	if(!wearer || wearer.get_item_by_slot(ITEM_SLOT_OCLOTHING) != src)
		return
	wear_stage++
	set_armor(wear_stage_armors[wear_stage + 1])
	if(wear_stage <= length(wear_stage_messages))
		to_chat(wearer, span_notice("[src] [wear_stage_messages[wear_stage]]. Examine it to see the new numbers."))
	schedule_next_stage()

/// Full reset on unequip, the coat forgets the wearer completely.
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/proc/reset_fit()
	deltimer(wear_timer_id)
	wear_timer_id = null
	wear_stage = 0
	set_armor(wear_stage_armors[1])
	current_wearer = null

/// Riot-grade while spotless: the doc's "clean" armor tier.
/datum/armor/occasion_clean
	melee = 50
	bullet = 10
	laser = 10
	energy = 10
	bomb = 10
	fire = 80
	acid = 80
	wound = 20

/// Near-nothing once it's ruined.
/datum/armor/occasion_dirty
	melee = 5
	fire = 10
	acid = 10

/**
 * "The Occasion", riot-rated formalwear that's only as good as its
 * laundering.
 *
 * Suit-slot type reusing /obj/item/clothing/under/suit/tuxedo's icon vars
 * verbatim (code/modules/clothing/under/suits.dm). Copied across the slot
 * categories deliberately (tuxedo is an /under item, this is a /suit item),
 * lefthand_file/righthand_file need no override since both
 * /obj/item/clothing/suit and /obj/item/clothing/under already point at the
 * same 'icons/mob/inhands/clothing/suits_lefthand/righthand.dmi' pair.
 *
 * BUG FIX (2026-07-28, "says it's ruined while spotless" / "washing it does
 * nothing"). Three separate faults, all of which made the suit's state
 * disagree with what the player could see:
 *
 * 1. The dirty check was `get_blood_dna_color()`
 *    (code/modules/forensics/forensics_helpers.dm). That proc memoises its
 *    answer in `atom.cached_blood_color`, and *nothing in the codebase ever
 *    invalidates that cache on cleaning*. Wipe_blood_DNA() clears the DNA
 *    list and leaves the cache alone. So once the suit had ever been bloody,
 *    the check returned a colour forever, the 10-second poll re-ruined the
 *    suit a few seconds after every wash, and no amount of laundering could
 *    ever restore it. The check is now
 *    GET_ATOM_BLOOD_DECAL_LENGTH(src), the visible-blood list, which
 *    wipe_blood_DNA() genuinely empties.
 *
 * 2. on_exposed() treated *any* TOUCH/VAPOR reagent exposure as soiling,
 *    including water from a shower and space cleaner from a cleaner grenade
 *    or foam. Cleaning the suit re-dirtied it in the same instant. Only the
 *    reagents in `dirtying_reagents` count now.
 *
 * 3. on_clean() returned COMPONENT_CLEANED. /atom/proc/wash()
 *    (code/game/atom/_atom.dm) returns early the moment the CLEAN_ACT signal
 *    reports a non-zero result, so the suit was claiming other people's
 *    cleaning work and suppressing the tail of the wash. It returns NONE now
 *    and simply observes.
 *
 * All state changes funnel through sync_condition(), so the flag, the armor,
 * the slowdown and the message can't drift apart. Both real cleaning paths
 * are covered: COMSIG_COMPONENT_CLEAN_ACT (soap, showers, cleaner grenades,
 * and the washing machine, which routes through wash()) plus an explicit
 * machine_wash() override for the washing machine's own hook.
 */
/obj/item/clothing/suit/the_occasion
	name = "\"the occasion\""
	desc = "Formalwear in a garment bag labeled only FOR THE OCCASION. Armored like a riot suit, right up until it gets dirty."
	icon = 'icons/obj/clothing/under/suits.dmi'
	icon_state = "tuxedo"
	worn_icon = 'icons/mob/clothing/under/suits.dmi'
	inhand_icon_state = null
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	slowdown = 1
	armor_type = /datum/armor/occasion_clean
	custom_price = PAYCHECK_CREW * 8
	/// Is the suit currently ruined? Mirrors is_dirty() at all times.
	var/soiled = FALSE
	/// Set when a mess lands on the suit that isn't blood, cleared by any wash.
	var/splashed = FALSE
	/// Timer id for the next dirty-poll tick
	var/check_timer_id
	/// How often the suit checks itself over while worn
	var/check_interval = 10 SECONDS
	/// Reagents that count as ruining the suit. Water, cleaner and medicine deliberately don't.
	var/static/list/dirtying_reagents = list(
		/datum/reagent/blood,
		/datum/reagent/consumable/liquidgibs,
		/datum/reagent/toxin/slimejelly,
		/datum/reagent/fuel/oil,
		/datum/reagent/ash,
		/datum/reagent/carbon,
	)

/obj/item/clothing/suit/the_occasion/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(on_exposed))
	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	// The garment bag is a set, the matched top hat arrives with the suit
	new /obj/item/clothing/head/hats/tophat/the_occasion(loc)

/obj/item/clothing/suit/the_occasion/Destroy()
	deltimer(check_timer_id)
	check_timer_id = null
	return ..()

/obj/item/clothing/suit/the_occasion/examine(mob/user)
	. = ..()
	// Re-read before printing: the poll only runs while the suit is worn, and
	// what examine says has to match what the suit is actually doing.
	sync_condition(announce = FALSE)
	var/datum/armor/current = get_armor()
	if(soiled)
		. += span_warning("It's ruined. Wash it - a washing machine, a shower, soap, a cleaner grenade - and the protection comes back.")
	else
		. += span_notice("It's spotless, and it's carrying full protection.")
	. += span_notice("Armor right now - melee [current.get_rating(MELEE)], bullet [current.get_rating(BULLET)], laser [current.get_rating(LASER)], energy [current.get_rating(ENERGY)], bomb [current.get_rating(BOMB)], fire [current.get_rating(FIRE)], acid [current.get_rating(ACID)], wound [current.get_rating(WOUND)].")
	if(soiled)
		var/datum/armor/spotless = get_armor_by_type(/datum/armor/occasion_clean)
		. += span_notice("Washed, it goes back to melee [spotless.get_rating(MELEE)] and fire [spotless.get_rating(FIRE)], and it stops slowing you down.")
	else
		var/datum/armor/ruined = get_armor_by_type(/datum/armor/occasion_dirty)
		. += span_notice("Blood or a bad splash drops it to melee [ruined.get_rating(MELEE)] until it's washed.")

/obj/item/clothing/suit/the_occasion/equipped(mob/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_OCLOTHING))
		return
	// Splashes land on the wearer, not the worn item, the same handoff the
	// vanilla clothing_dirt component does (code/datums/components/clothing_dirt.dm).
	RegisterSignal(user, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(on_exposed), override = TRUE)
	sync_condition(announce = FALSE)
	refresh_slowdown(user)
	schedule_check()
	if(soiled)
		to_chat(user, span_warning("[src] is still ruined, and it's slowing you down. Wash it and the protection comes back."))

/obj/item/clothing/suit/the_occasion/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_ATOM_EXPOSE_REAGENTS)
	deltimer(check_timer_id)
	check_timer_id = null
	var/mob/living/wearer = user
	if(istype(wearer))
		wearer.unignore_slowdown(REF(src))

/// Reschedules the next self-check, as long as we're still being worn.
/obj/item/clothing/suit/the_occasion/proc/schedule_check()
	deltimer(check_timer_id)
	check_timer_id = addtimer(CALLBACK(src, PROC_REF(poll_condition)), check_interval, TIMER_STOPPABLE)

/obj/item/clothing/suit/the_occasion/proc/poll_condition()
	check_timer_id = null
	sync_condition()
	if(worn_by())
		schedule_check()

/// The mob wearing this suit in its own slot, if any.
/obj/item/clothing/suit/the_occasion/proc/worn_by()
	RETURN_TYPE(/mob/living)
	var/mob/living/wearer = loc
	if(!istype(wearer) || wearer.get_item_by_slot(ITEM_SLOT_OCLOTHING) != src)
		return null
	return wearer

/**
 * The one source of truth: is there anything on this suit right now?
 *
 * Visible blood decals only: GET_ATOM_BLOOD_DECAL_LENGTH reads the list that
 * wipe_blood_DNA() actually empties, unlike get_blood_dna_color(), whose
 * cache is never invalidated by cleaning.
 */
/obj/item/clothing/suit/the_occasion/proc/is_dirty()
	return splashed || GET_ATOM_BLOOD_DECAL_LENGTH(src) > 0

/**
 * Brings the flag, the armor, the slowdown and the wearer's messages back in
 * line with is_dirty(). Safe to call as often as you like; it only does
 * anything on an actual change.
 */
/obj/item/clothing/suit/the_occasion/proc/sync_condition(announce = TRUE)
	var/dirty = is_dirty()
	var/mob/living/wearer = worn_by()
	if(dirty == soiled)
		// Still refresh the slowdown - the suit may have just been put on.
		refresh_slowdown(wearer)
		return
	soiled = dirty
	set_armor(soiled ? /datum/armor/occasion_dirty : /datum/armor/occasion_clean)
	refresh_slowdown(wearer)
	if(!announce || !wearer)
		return
	if(soiled)
		to_chat(wearer, span_warning("[src] is ruined. Until it's washed, it's just a very nice suit."))
	else
		to_chat(wearer, span_notice("[src] comes out spotless, good as new."))

/// Zero equipment slowdown, but only while it's actually worn and actually clean.
/obj/item/clothing/suit/the_occasion/proc/refresh_slowdown(mob/living/wearer)
	if(!isliving(wearer))
		return
	if(soiled)
		wearer.unignore_slowdown(REF(src))
	else
		wearer.ignore_slowdown(REF(src))

/// Splashes of the genuinely messy stuff ruin the suit. Water and cleaner don't.
/obj/item/clothing/suit/the_occasion/proc/on_exposed(datum/source, list/reagents, datum/reagents/source_reagents, methods)
	SIGNAL_HANDLER
	if(splashed || !(methods & (TOUCH|VAPOR)))
		return
	for(var/datum/reagent/splash as anything in reagents)
		if(!is_type_in_list(splash, dirtying_reagents))
			continue
		splashed = TRUE
		sync_condition()
		return

/**
 * Any real cleaning pass clears the splash flag and re-reads the suit.
 *
 * The re-read is deferred by one tick on purpose: the forensics datum's own
 * CLEAN_ACT handler (code/modules/forensics/_forensics.dm) is a separate
 * listener on this same signal, so blood may not be wiped yet when we run.
 * Returns NONE, claiming COMPONENT_CLEANED here would make
 * /atom/proc/wash() return early and skip the rest of the wash.
 */
/obj/item/clothing/suit/the_occasion/proc/on_clean(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!(clean_types & CLEAN_TYPE_BLOOD))
		return NONE
	splashed = FALSE
	addtimer(CALLBACK(src, PROC_REF(sync_condition)), 0, TIMER_UNIQUE|TIMER_OVERRIDE)
	return NONE

/// The washing machine's own hook, on top of the wash() it already does.
/obj/item/clothing/suit/the_occasion/machine_wash(obj/machinery/washing_machine/washer)
	. = ..()
	splashed = FALSE
	sync_condition()

/**
 * The Occasion's matched top hat.
 *
 * Straight subtype of /obj/item/clothing/head/hats/tophat
 * (code/modules/clothing/head/tophat.dm), full icon/worn_icon/inhand
 * inheritance, no icon vars invented. Purely a cosmetic matched piece; no
 * mechanic of its own.
 */
/obj/item/clothing/head/hats/tophat/the_occasion
	name = "\"the occasion\" top hat"
	desc = "The matching top hat from the garment bag. Purely for show."
	custom_price = PAYCHECK_CREW * 2

/obj/item/clothing/head/hats/tophat/the_occasion/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
