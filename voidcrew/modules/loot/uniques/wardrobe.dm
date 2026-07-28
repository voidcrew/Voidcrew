/**
 * # WARDROBE uniques — couturier's trunk
 *
 * Six unique loot items for the wardrobe (`rare_loot_wardrobe`) zone-loot
 * tables (voidcrew/modules/loot/zone_loot.dm). Identity loot: nothing here
 * is a bigger number, every piece is a mechanic. All six carry
 * TRAIT_NO_REPLICATE (voidcrew/_DEFINES/loot.dm) so duplicators (Helios
 * pattern stamp and friends) refuse to copy them.
 *
 * No new sprites: every item below either subtypes an existing clothing
 * item (inheriting its icon/worn_icon/inhand states for free) or, where no
 * thematically close donor type exists in this codebase, copies a real
 * donor's icon vars verbatim onto a fresh root type. See per-item comments
 * for the exact donor.
 *
 * Not yet wired into voidcrew/modules/loot/zone_loot.dm's rare_loot_wardrobe
 * tables, and not yet added to tgstation.dme — both are hand-edits left to
 * the coordinator per the cross-cutting implementation notes.
 */

// =========================================================================
// GREEN
// =========================================================================

/**
 * Understudy's cravat — cosmetic-only disguise.
 *
 * Subtypes /obj/item/clothing/neck/tie (code/modules/clothing/neck/_neck.dm)
 * verbatim: same greyscale-driven icon/worn_icon/post_init_icon_state
 * machinery as the stock tie, nothing new to render.
 *
 * Mechanic deviation from the doc: true per-slot appearance mutation (copy
 * each equipped item's icon_state/worn_icon onto the wearer's own gear) is
 * infeasible from a single new file — DM does not allow overriding an
 * existing type's rendering procs (worn_overlays(), etc.) from a second
 * file, and every clothing slot would need that override on its own type.
 * Implemented instead as the doc's sanctioned fallback: a single flattened
 * cosmetic overlay of the studied target's whole worn appearance
 * (getFlatIcon(), code/__HELPERS/icons.dm), stuck on the wearer with
 * add_overlay() and stripped with cut_overlay(). Nothing about the
 * wearer's actual equipped items changes, so armor stays armor and rags
 * stay rags exactly as specified — the disguise is a purely visual mask
 * layered on top.
 */
/obj/item/clothing/neck/tie/understudys_cravat
	name = "understudy's cravat"
	desc = "A silk cravat that's a slightly different color every time you look away."
	custom_price = PAYCHECK_CREW * 4
	// attack_self only fires in-hand, but the disguise requires the cravat
	// worn — the action button (default click routes to attack_self) is the
	// only reachable activation path while it's on your neck
	actions_types = list(/datum/action/item_action/toggle)
	/// Last mob this wearer examined, candidate for the next disguise
	var/datum/weakref/studied_target
	/// Mob currently wearing our disguise overlay, if any
	var/datum/weakref/disguised_wearer
	/// The overlay image currently applied to disguised_wearer
	var/image/disguise_overlay
	/// Throttle on getFlatIcon() calls — it's an expensive helper
	COOLDOWN_DECLARE(study_cooldown)

/obj/item/clothing/neck/tie/understudys_cravat/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/neck/tie/understudys_cravat/Destroy()
	clear_disguise()
	studied_target = null
	return ..()

/obj/item/clothing/neck/tie/understudys_cravat/equipped(mob/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_NECK))
		return
	RegisterSignal(user, COMSIG_MOB_EXAMINATE, PROC_REF(on_examinate))

/obj/item/clothing/neck/tie/understudys_cravat/dropped(mob/user)
	. = ..()
	UnregisterSignal(user, COMSIG_MOB_EXAMINATE)
	clear_disguise()

/// Remembers whoever the wearer last looked over — the next "take their part."
/obj/item/clothing/neck/tie/understudys_cravat/proc/on_examinate(mob/examiner, atom/examinify)
	SIGNAL_HANDLER
	if(!isliving(examinify) || examinify == examiner)
		return
	studied_target = WEAKREF(examinify)

/obj/item/clothing/neck/tie/understudys_cravat/attack_self(mob/user)
	. = ..()
	var/mob/living/wearer = user
	if(!istype(wearer) || loc != wearer || wearer.get_item_by_slot(ITEM_SLOT_NECK) != src)
		balloon_alert(user, "not worn!")
		return
	if(!COOLDOWN_FINISHED(src, study_cooldown))
		balloon_alert(user, "still re-cutting!")
		return
	var/mob/living/target = studied_target?.resolve()
	if(!target || QDELETED(target) || !(target in view(7, wearer)))
		balloon_alert(user, "no one studied nearby!")
		return
	COOLDOWN_START(src, study_cooldown, 10 SECONDS)
	apply_disguise(wearer, target)

/// Lays a flattened copy of target's whole worn look over the wearer, purely visual.
/obj/item/clothing/neck/tie/understudys_cravat/proc/apply_disguise(mob/living/user, mob/living/target)
	clear_disguise()
	var/icon/flat = getFlatIcon(target)
	if(!flat)
		return
	var/image/mask = image(icon = flat)
	mask.appearance_flags = KEEP_TOGETHER | RESET_COLOR | RESET_ALPHA
	user.add_overlay(mask)
	disguise_overlay = mask
	disguised_wearer = WEAKREF(user)
	to_chat(user, span_notice("You re-cut your outfit to look like [target]'s. From across the room, you could be them."))

/// Strips any active disguise overlay back off its wearer.
/obj/item/clothing/neck/tie/understudys_cravat/proc/clear_disguise()
	if(!disguise_overlay)
		return
	var/mob/living/wearer = disguised_wearer?.resolve()
	if(wearer)
		wearer.cut_overlay(disguise_overlay)
	disguise_overlay = null
	disguised_wearer = null

/**
 * Winter's loafers — negates worn-gear slowdown, silences footsteps.
 *
 * Subtypes /obj/item/clothing/shoes/laceup (code/modules/clothing/shoes/laceup.dm)
 * verbatim for icon_state "laceups" and everything else the base shoe class
 * carries (icon, lefthand/righthand files, armor_type).
 *
 * Deviation: there's no per-item hook in this codebase that zeroes only
 * *equipment* slowdown while leaving terrain/status slowdown alone (see
 * /mob/living/carbon/human/get_movespeed_modifiers(),
 * code/modules/mob/living/carbon/human/human_movement.dm). The closest real
 * lever is TRAIT_IGNORESLOWDOWN, applied/removed via the existing
 * ignore_slowdown()/unignore_slowdown() pair
 * (code/modules/mob/living/status_procs.dm) — it strips *all* slowdown
 * sources that lack the IGNORE_NOSLOW flag, not just clothing. Broader than
 * "absorbs the clumsiness of armor" as written, but it's the only existing
 * mechanism that doesn't require editing mob code from this file. Flagged
 * for review.
 *
 * "Carpet never hears you coming" is implemented as full TRAIT_SILENT_FOOTSTEPS
 * while worn (code/__DEFINES/footsteps.dm), not surface-restricted — there's
 * no existing "silent on this footstep type only" trait to key off carpet
 * specifically.
 */
/obj/item/clothing/shoes/laceup/winters_loafers
	name = "Winter's loafers"
	desc = "Laceup loafers, resoled more times than anyone can count. Nothing you're wearing slows you down in them, and nobody hears you coming."
	custom_price = PAYCHECK_CREW * 4

/obj/item/clothing/shoes/laceup/winters_loafers/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

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
 * Stage presence — activation taunt: turns heads, pulls hostile aggro, amplifies voice.
 *
 * No cavalier/musketeer/plumed hat type exists anywhere in this codebase
 * (verified by grep — nothing matches cavalier, musketeer, plumed, or
 * tricorne). Rather than subtype the closest visual analog,
 * /obj/item/clothing/head/costume/pirate/captain, and fight its inherited
 * piratespeak-grant/fishing-difficulty behavior (both wired into that
 * type's own equipped()/dropped()/Initialize(), which can't be selectively
 * un-inherited), this is a fresh root under /obj/item/clothing/head.
 * Obj icon is the custom "stage_presence" state in uniques.dmi; the worn
 * sprite is a matching custom state in uniques_worn.dmi derived from the
 * same cavalier-hat art (previously borrowed "hgpiratecap").
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
	// Worn-slot activation path — attack_self alone is unreachable while the
	// hat is on your head (see the cravat's identical note)
	actions_types = list(/datum/action/item_action/toggle)
	/// Chat span(s) applied to the wearer's speech during the amplified window, megaphone-style
	var/list/voicespan = list(SPAN_COMMAND)
	/// How long the amplified-voice window lasts once triggered
	var/amplify_duration = 6 SECONDS
	/// How far the taunt reaches for retarget/turn-heads purposes
	var/taunt_range = 7
	COOLDOWN_DECLARE(presence_cooldown)

/obj/item/clothing/head/stage_presence/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/clothing/head/stage_presence/attack_self(mob/user)
	. = ..()
	var/mob/living/wearer = user
	if(!istype(wearer) || wearer.get_item_by_slot(ITEM_SLOT_HEAD) != src)
		balloon_alert(user, "not worn!")
		return
	if(!COOLDOWN_FINISHED(src, presence_cooldown))
		balloon_alert(user, "needs a moment!")
		return
	COOLDOWN_START(src, presence_cooldown, 1 MINUTES)
	take_the_stage(wearer)

/// The doff-and-taunt: heads turn, hostiles retarget, voice carries for a few seconds.
/obj/item/clothing/head/stage_presence/proc/take_the_stage(mob/living/wearer)
	wearer.visible_message(
		span_bolddanger("[wearer] sweeps off [src] with a flourish — every eye in the room follows!"),
		span_boldnotice("You take the stage."),
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

	RegisterSignal(wearer, COMSIG_MOB_SAY, PROC_REF(amplify_speech))
	addtimer(CALLBACK(src, PROC_REF(end_amplify), wearer), amplify_duration)

	// Doff, theatrically — the hat leaves the head into a free hand (or the floor).
	wearer.temporarilyRemoveItemFromInventory(src)
	if(!wearer.put_in_hands(src))
		src.forceMove(get_turf(wearer))

/// Megaphone-style speech span injection (see code/game/objects/items/devices/megaphone.dm) while the stage window is open.
/obj/item/clothing/head/stage_presence/proc/amplify_speech(mob/living/speaker, list/speech_args)
	SIGNAL_HANDLER
	speech_args[SPEECH_SPANS] |= voicespan

/obj/item/clothing/head/stage_presence/proc/end_amplify(mob/living/wearer)
	UnregisterSignal(wearer, COMSIG_MOB_SAY)

/**
 * Third hand sewing kit — permanent appearance transplant between two garments.
 *
 * No sewing/tailoring item exists anywhere in this codebase (verified by
 * grep). Built as a fresh /obj/item root with icon vars copied verbatim
 * from /obj/item/storage/lockbox (code/game/objects/items/storage/lockbox.dm):
 * icon 'icons/obj/storage/case.dmi', icon_state "lockbox" (its own
 * icon_closed value — the plain case look, not the locked "lockbox+l"
 * state), inhand_icon_state "lockbox", and the briefcase in-hand files.
 * Not subtyped from lockbox itself so none of its lock/storage machinery
 * comes along for the ride.
 *
 * Two-click interaction, both legs on the kit itself via afterattack()
 * (code/_onclick/item_attack.dm): first click on a donor garment loads it
 * as the pattern, second click on a different, slot-compatible garment
 * copies the donor's visual vars onto it (permanently) and consumes the
 * donor. Stats, armor, and name are untouched — only the rendering vars
 * move.
 */
/obj/item/third_hand_kit
	name = "third hand sewing kit"
	desc = "A rosewood sewing kit with a needle that threads itself. Click one garment to pin it as a pattern, then click another to make it look exactly the same."
	icon = 'voidcrew/modules/loot/icons/uniques.dmi'
	icon_state = "third_hand_kit"
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	throwforce = 0
	custom_price = PAYCHECK_CREW * 5
	/// The garment currently pinned in as the donor pattern, if any
	var/datum/weakref/loaded_donor

/obj/item/third_hand_kit/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)

/obj/item/third_hand_kit/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!istype(target, /obj/item/clothing))
		return
	var/obj/item/clothing/garment = target

	// First leg: pin the donor pattern.
	if(!loaded_donor)
		if(HAS_TRAIT(garment, TRAIT_NO_REPLICATE))
			balloon_alert(user, "too unique to copy!")
			return
		loaded_donor = WEAKREF(garment)
		balloon_alert(user, "pattern pinned")
		to_chat(user, span_notice("You pin [garment] into the kit as a pattern piece."))
		return

	// Second leg: re-cut the target off the pinned donor.
	var/obj/item/clothing/donor = loaded_donor.resolve()
	if(!donor || QDELETED(donor))
		loaded_donor = null
		balloon_alert(user, "pattern's gone - pin another")
		return
	if(donor == garment)
		balloon_alert(user, "that's the pattern piece!")
		return
	if(!(donor.slot_flags & garment.slot_flags))
		balloon_alert(user, "wrong shape for this pattern!")
		return
	if(!do_after(user, 3 SECONDS, target = garment))
		return
	retailor(garment, donor)
	to_chat(user, span_notice("[garment] takes on the exact look of [donor]."))
	qdel(donor)
	loaded_donor = null

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
	// config, not raw icon_state — without carrying these over, the copy
	// renders with the target's old config or not at all
	target.greyscale_config = donor.greyscale_config
	target.greyscale_config_worn = donor.greyscale_config_worn
	target.greyscale_config_inhand_left = donor.greyscale_config_inhand_left
	target.greyscale_config_inhand_right = donor.greyscale_config_inhand_right
	target.greyscale_colors = donor.greyscale_colors
	if(target.greyscale_config && target.greyscale_colors)
		target.update_greyscale()
	target.update_appearance()
	var/mob/wearer = target.loc
	if(istype(wearer))
		wearer.update_clothing(target.slot_flags)

// =========================================================================
// RED
// =========================================================================

/// Bare weave — the heirloom coat's day-one condition.
/datum/armor/heirloom_bare

/// Twenty minutes in — the weave starts setting.
/datum/armor/heirloom_light
	melee = 15
	bullet = 10
	laser = 10
	energy = 10
	bomb = 10
	fire = 20
	acid = 20
	wound = 5

/// Forty minutes — noticeably heavier, holding its shape.
/datum/armor/heirloom_vest
	melee = 30
	bullet = 25
	laser = 25
	energy = 25
	bomb = 20
	fire = 40
	acid = 40
	wound = 10

/// Sixty minutes — as close to plate as cloth gets.
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
 * The heirloom coat — armor that grows with unbroken wear-time.
 *
 * Subtypes /obj/item/clothing/suit/armor/hos/trenchcoat
 * (code/modules/clothing/suits/armor.dm) verbatim for icon_state
 * "hostrench" / inhand_icon_state "hostrench" and the inherited
 * icon/worn_icon files off armor.dmi. It's a Head-of-Security reskin
 * upstream but carries no HoS-specific procs or restrictions (confirmed —
 * that type is a pure sprite/flavor override), so subtyping it is safe.
 *
 * Four armor stages (bare -> light -> vest -> riot-ish), one step every 20
 * unbroken minutes worn, tracked via a self-rescheduling addtimer keyed to
 * the current wearer. Taking the coat off resets both the timer and the
 * armor tier to stage 0 — "it forgets you completely, and you start again
 * as strangers," per the doc.
 */
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat
	name = "the heirloom coat"
	desc = "A long coat, older than the shipping line that lost it. The longer you keep it on without taking it off, the tougher it gets."
	icon_state = "hostrench"
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
		to_chat(wearer, span_notice("[src] [wear_stage_messages[wear_stage]]."))
	schedule_next_stage()

/// Full reset on unequip — the coat forgets the wearer completely.
/obj/item/clothing/suit/armor/hos/trenchcoat/heirloom_coat/proc/reset_fit()
	deltimer(wear_timer_id)
	wear_timer_id = null
	wear_stage = 0
	set_armor(wear_stage_armors[1])
	current_wearer = null

/// Riot-grade while spotless — the doc's "clean" armor tier.
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
 * "The Occasion" — riot-rated formalwear that's only as good as its
 * laundering.
 *
 * Suit-slot type reusing /obj/item/clothing/under/suit/tuxedo's icon vars
 * verbatim (code/modules/clothing/under/suits.dm): icon
 * 'icons/obj/clothing/under/suits.dmi', icon_state "tuxedo", worn_icon
 * 'icons/mob/clothing/under/suits.dmi', inhand_icon_state null. Copied
 * across the slot categories deliberately (tuxedo is an /under item, this
 * is a /suit item) — lefthand_file/righthand_file need no override since
 * both /obj/item/clothing/suit and /obj/item/clothing/under already point
 * at the same 'icons/mob/inhands/clothing/suits_lefthand/righthand.dmi'
 * pair by default.
 *
 * Deviation: there's no push signal in this codebase for "an atom just got
 * dirtied" (add_blood_DNA()/the blood decal element, code/modules/forensics
 * and code/datums/elements/decals/blood.dm, fire no signal). Dirtying is
 * detected two ways: immediately via COMSIG_ATOM_EXPOSE_REAGENTS for
 * splashes (vomit, slime, chem spills), and via a 10-second self-rescheduling
 * poll of get_blood_dna_color() while worn, for combat blood that lands
 * without a reagent exposure. COMSIG_COMPONENT_CLEAN_ACT (washing
 * machine/mop) restores the clean tier instantly, per the doc. "Zero
 * slowdown … as long as it's clean" reuses the same TRAIT_IGNORESLOWDOWN
 * lever as Winter's loafers above, with the same broader-than-equipment
 * caveat — see that item's comment.
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
	/// Has the suit picked up blood/soot/slime/vomit since its last wash?
	var/soiled = FALSE
	/// Timer id for the next dirty-poll tick
	var/check_timer_id
	/// How often the coat checks itself over for blood while worn
	var/check_interval = 10 SECONDS

/obj/item/clothing/suit/the_occasion/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_REPLICATE, INNATE_TRAIT)
	RegisterSignal(src, COMSIG_ATOM_EXPOSE_REAGENTS, PROC_REF(on_exposed))
	RegisterSignal(src, COMSIG_COMPONENT_CLEAN_ACT, PROC_REF(on_clean))
	// The garment bag is a set — the matched top hat arrives with the suit
	new /obj/item/clothing/head/hats/tophat/the_occasion(loc)

/obj/item/clothing/suit/the_occasion/Destroy()
	deltimer(check_timer_id)
	check_timer_id = null
	return ..()

/obj/item/clothing/suit/the_occasion/equipped(mob/user, slot)
	. = ..()
	if(!(slot & ITEM_SLOT_OCLOTHING))
		return
	schedule_check()
	var/mob/living/wearer = user
	if(istype(wearer) && !soiled)
		wearer.ignore_slowdown(REF(src))

/obj/item/clothing/suit/the_occasion/dropped(mob/user)
	. = ..()
	deltimer(check_timer_id)
	check_timer_id = null
	var/mob/living/wearer = user
	if(istype(wearer))
		wearer.unignore_slowdown(REF(src))

/// Reschedules the next blood self-check, as long as we're still being worn.
/obj/item/clothing/suit/the_occasion/proc/schedule_check()
	deltimer(check_timer_id)
	check_timer_id = addtimer(CALLBACK(src, PROC_REF(poll_dirty)), check_interval, TIMER_STOPPABLE)

/obj/item/clothing/suit/the_occasion/proc/poll_dirty()
	check_timer_id = null
	if(!soiled && get_blood_dna_color())
		mark_soiled()
	var/mob/wearer = loc
	if(istype(wearer) && wearer.get_item_by_slot(ITEM_SLOT_OCLOTHING) == src)
		schedule_check()

/// Splashes (vomit, slime, chem spills) ruin the suit immediately.
/obj/item/clothing/suit/the_occasion/proc/on_exposed(datum/source, list/reagents, datum/reagents/source_reagents, methods)
	SIGNAL_HANDLER
	if(!soiled && (methods & (TOUCH|VAPOR)))
		mark_soiled()

/obj/item/clothing/suit/the_occasion/proc/mark_soiled()
	soiled = TRUE
	set_armor(/datum/armor/occasion_dirty)
	var/mob/living/wearer = loc
	if(istype(wearer))
		to_chat(wearer, span_warning("[src] is ruined. Until someone washes it, it's just a very nice suit."))
		wearer.unignore_slowdown(REF(src))

/// Washing machine / mop restores the clean tier on the spot.
/obj/item/clothing/suit/the_occasion/proc/on_clean(datum/source, clean_types)
	SIGNAL_HANDLER
	if(!soiled || !(clean_types & (CLEAN_WASH|CLEAN_SCRUB)))
		return NONE
	soiled = FALSE
	set_armor(/datum/armor/occasion_clean)
	var/mob/living/wearer = loc
	if(istype(wearer))
		to_chat(wearer, span_notice("[src] comes out spotless, good as new."))
		wearer.ignore_slowdown(REF(src))
	return COMPONENT_CLEANED

/**
 * The Occasion's matched top hat.
 *
 * Straight subtype of /obj/item/clothing/head/hats/tophat
 * (code/modules/clothing/head/tophat.dm) — full icon/worn_icon/inhand
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
