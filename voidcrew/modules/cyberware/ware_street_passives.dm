/**
 * # Street passives
 *
 * Six cheap pieces of chrome that do one quiet thing each and have no button:
 *
 * - Clotter node (heart aux, T1): bleed slower.
 * - Adrenal pump (heart aux, T2): answers a bad run of stamina damage once
 *   in a while. Shares the heart aux slot with the Clotter node.
 * - Medic's palms (hands, T1): nitrile-glove speed without the glove.
 * - Cuffer's wrists (hands, T1): quicker cuffing. Sideways to the Medic's
 *   palms and the Gecko Grip, which sit in the same slot.
 * - Subvocal mic (larynx, T1): radio talk goes no further than the speaker.
 * - Muffler ear (ears, T1): earmuff-grade protection from a bang. Sideways to
 *   the Heartbeat Doppler, same slot.
 *
 * Every effect rides the failing-gated passive layer (chrome_passives_on/off in
 * cyberware_base.dm), so an EMP, a brownout or a damage failure switches it off
 * and a tune-up hands it back. All tuning is in vars on the organ.
 *
 * The Subvocal mic needs two small hooks in the speech path. Both are chained
 * overrides at the bottom of this file, nothing upstream is edited.
 *
 * SKUs and trade-ins are defined at the bottom, listed on no vendor yet.
 */

/// Held by a mob whose radio talk is not overheard. Granted by the Subvocal mic.
#define TRAIT_CYBER_SUBVOCAL "cyber_subvocal"
/// The red the Adrenal pump leaves on its bearer for the length of the rush.
#define CYBERWARE_ADRENAL_FLUSH "#ff8f8f"

// =========================================================================
// CLOTTER NODE
// =========================================================================

/**
 * # Clotter node (T1, chest, heart aux slot, load 1)
 *
 * Halves the blood the bearer loses. The multiplier is mixed into the human
 * physiology, which survives species changes, so there is one multiply and one
 * divide per flip, and the factor actually applied is remembered so retuning the
 * var on a live organ cannot desync the pair. Rides the failing-gated passive
 * hooks like the Dermal Mesh does.
 */
/obj/item/organ/cyberimp/cyberware/clotter_node
	name = "\improper Clotter node"
	desc = "A reservoir of clotting gel plumbed into the heart. Cuts stop sooner than they should."
	icon_state = "clotter_node"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_HEART_AUX
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	/// Multiplier on the blood the bearer loses.
	var/bleed_multiplier = 0.5
	/// The multiplier currently mixed into the bearer, or null when none is.
	var/applied_bleed_multiplier

/obj/item/organ/cyberimp/cyberware/clotter_node/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(!isnull(applied_bleed_multiplier) || !ishuman(bearer))
		return
	var/mob/living/carbon/human/human_bearer = bearer
	applied_bleed_multiplier = bleed_multiplier
	human_bearer.physiology.bleed_mod *= applied_bleed_multiplier

/obj/item/organ/cyberimp/cyberware/clotter_node/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(isnull(applied_bleed_multiplier))
		return
	var/removed_multiplier = applied_bleed_multiplier
	applied_bleed_multiplier = null // reset before the validity skip, see Shock Coils
	if(!ishuman(bearer) || QDELETED(bearer))
		return
	var/mob/living/carbon/human/human_bearer = bearer
	human_bearer.physiology.bleed_mod /= removed_multiplier

// =========================================================================
// ADRENAL PUMP
// =========================================================================

/**
 * # Adrenal pump (T2, chest, heart aux slot, load 2)
 *
 * When a run of stamina damage takes the bearer to the trigger level, the pump
 * dumps a shot of adrenaline: part of the stamina loss comes off and the bearer
 * is quicker on their feet for a few seconds. The tell is deliberate: a heartbeat
 * thud anyone nearby can hear and a red flush on the bearer.
 *
 * The wait before it fires again is stored on the organ as the world.time it is
 * ready at, so pulling the pump and refitting it never resets the wait.
 *
 * It answers damage from outside only. The crashes of the Cascade and Redline
 * lines dump stamina as their own price, and a pump that took the sting out of
 * that price would make the cheap heart ware a cure for the legend ware's bill, so
 * the check runs one tick after the damage (the crash status is not on the bearer
 * yet at the moment of the dump) and stands down while either crash is running.
 */
/obj/item/organ/cyberimp/cyberware/adrenal_pump
	name = "\improper Adrenal pump"
	desc = "A pump of synthetic adrenaline wired into the heart. The sort of thing a doctor tells you not to try at home."
	icon_state = "adrenal_pump"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_HEART_AUX
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 2
	tier = CYBERWARE_TIER_2
	/// Stamina loss at or above which the pump fires.
	var/trigger_stamina = 70
	/// Stamina loss taken off when it fires.
	var/stamina_relief = 40
	/// How long the bearer is quicker for.
	var/rush_duration = 3 SECONDS
	/// How long the pump takes to charge again after firing.
	var/recharge_time = 4 MINUTES
	/// world.time at which the pump is ready to fire. Lives on the organ, so
	/// removing and refitting it keeps the wait.
	var/ready_at = 0
	/// TRUE while a firing check is queued, so one volley of damage queues one check.
	var/discharge_queued = FALSE

/obj/item/organ/cyberimp/cyberware/adrenal_pump/examine(mob/user)
	. = ..()
	. += span_notice("Its status light is [world.time < ready_at ? "amber" : "green"].")

/obj/item/organ/cyberimp/cyberware/adrenal_pump/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(isnull(bearer))
		return
	RegisterSignal(bearer, COMSIG_LIVING_STAMINA_UPDATE, PROC_REF(on_stamina_update), override = TRUE)

/obj/item/organ/cyberimp/cyberware/adrenal_pump/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	discharge_queued = FALSE
	if(isnull(bearer))
		return
	UnregisterSignal(bearer, COMSIG_LIVING_STAMINA_UPDATE)

/// Signal proc for [COMSIG_LIVING_STAMINA_UPDATE]: cheap tests only, the pump
/// itself fires from the queued check.
/obj/item/organ/cyberimp/cyberware/adrenal_pump/proc/on_stamina_update(mob/living/source)
	SIGNAL_HANDLER
	if(discharge_queued || source != owner || world.time < ready_at)
		return
	if(source.stat != CONSCIOUS || source.getStaminaLoss() < trigger_stamina)
		return
	discharge_queued = TRUE
	addtimer(CALLBACK(src, PROC_REF(discharge)), 1) // next tick, see the header

/// The queued check. Everything is tested again: the bearer may have recovered,
/// been knocked out, lost the chrome or be riding out a crash.
/obj/item/organ/cyberimp/cyberware/adrenal_pump/proc/discharge()
	discharge_queued = FALSE
	var/mob/living/carbon/bearer = owner
	if(QDELETED(src) || QDELETED(bearer) || world.time < ready_at)
		return
	var/datum/component/cyberware/chrome = GetComponent(/datum/component/cyberware)
	if(!chrome?.is_running())
		return
	if(bearer.stat != CONSCIOUS || bearer.getStaminaLoss() < trigger_stamina)
		return
	if(bearer.has_status_effect(/datum/status_effect/cyberware_cascade_crash) || bearer.has_status_effect(/datum/status_effect/cyberware_redline_crash))
		return
	// Spent first: the relief below re-enters the stamina signal.
	ready_at = world.time + recharge_time
	bearer.adjustStaminaLoss(-stamina_relief)
	bearer.apply_status_effect(/datum/status_effect/cyberware_adrenal_rush, rush_duration)
	playsound(bearer, 'sound/effects/singlebeat.ogg', 100, TRUE, 2)
	bearer.visible_message(
		span_warning("[bearer] flushes red, heart thudding loud enough to hear."),
		span_userdanger("Your heart slams and the exhaustion drops away."),
	)
	bearer.balloon_alert(bearer, "adrenaline!")
	cyberware_ink_pulse(bearer, CYBERWARE_INK_HARD)

/// The burst of speed, and the flush that shows it.
/datum/status_effect/cyberware_adrenal_rush
	id = "cyberware_adrenal_rush"
	duration = 3 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/// Optional argument: how long the rush lasts, from the pump that fired it.
/datum/status_effect/cyberware_adrenal_rush/on_creation(mob/living/new_owner, rush_duration)
	if(isnum(rush_duration))
		duration = rush_duration
	return ..()

/datum/status_effect/cyberware_adrenal_rush/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/cyberware_adrenal_rush)
	owner.add_atom_colour(CYBERWARE_ADRENAL_FLUSH, TEMPORARY_COLOUR_PRIORITY)
	return TRUE

/datum/status_effect/cyberware_adrenal_rush/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/cyberware_adrenal_rush)
	owner.remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, CYBERWARE_ADRENAL_FLUSH)
	return ..()

/datum/movespeed_modifier/cyberware_adrenal_rush
	multiplicative_slowdown = -0.4

// =========================================================================
// MEDIC'S PALMS
// =========================================================================

/**
 * # Medic's palms (T1, arm, hands slot, load 1)
 *
 * The nitrile-glove pair of traits (quicker chemistry, quicker fireman carry)
 * without taking up the glove slot. Same slot as the Gecko Grip and the Cuffer's
 * wrists, so a body wears one of the three.
 */
/obj/item/organ/cyberimp/cyberware/medic_palms
	name = "\improper Medic's palms"
	desc = "Sterile palm plates with a better grip than any nitrile glove. Saves a trip to the glove dispenser."
	icon_state = "medic_palms"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_CYBERWARE_HANDS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_FASTMED, TRAIT_QUICKER_CARRY)

// =========================================================================
// CUFFER'S WRISTS
// =========================================================================

/**
 * # Cuffer's wrists (T1, arm, hands slot, load 1)
 *
 * Cuffs go on in three quarters of the time (TRAIT_FAST_CUFFING, the same trait
 * as combat gloves). For bounty hunters and anyone else who ties people up for a
 * living.
 */
/obj/item/organ/cyberimp/cyberware/cuffer_wrists
	name = "\improper Cuffer's wrists"
	desc = "Reinforced wrist actuators with a lot of practice at closing around other people's wrists."
	icon_state = "cuffer_wrists"
	zone = BODY_ZONE_R_ARM
	slot = ORGAN_SLOT_CYBERWARE_HANDS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_FAST_CUFFING)

// =========================================================================
// SUBVOCAL MIC
// =========================================================================

/**
 * # Subvocal mic (T1, head, larynx slot, load 1)
 *
 * Radio talk is whispered at range 1 today, so the person next to you hears it.
 * With the mic it goes no further than the speaker. The trait is the whole ware;
 * the speech hooks at the bottom of this file read it.
 */
/obj/item/organ/cyberimp/cyberware/subvocal_mic
	name = "\improper Subvocal mic"
	desc = "A throat mic sutured to the vocal cords. Radio chatter goes out the wire instead of the room."
	icon_state = "subvocal_mic"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_LARYNX
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	organ_traits = list(TRAIT_CYBER_SUBVOCAL)

/// TRUE between a radio line the Subvocal mic quieted and the send_speech() call
/// that carries it, which follows straight on with no wait in between.
/mob/living/var/cyberware_subvocal_pending = FALSE

/**
 * Chained override of the human radio branch (base definition:
 * code/modules/mob/living/carbon/human/human_say.dm, which sets the whisper
 * range when it returns REDUCE_RANGE). A bearer's radio line is marked here;
 * the send_speech() override below spends the mark. A line the radio swallowed
 * (NOPASS) never reaches send_speech and is not marked.
 */
/mob/living/carbon/human/radio(message, list/message_mods = list(), list/spans, language)
	cyberware_subvocal_pending = FALSE
	. = ..()
	if((. & REDUCE_RANGE) && !(. & NOPASS) && HAS_TRAIT(src, TRAIT_CYBER_SUBVOCAL))
		cyberware_subvocal_pending = TRUE

/**
 * Chained override of living speech output. A marked radio line is spoken at
 * range 0: the bearer and anyone on their tile hear it, a neighbour one tile off
 * gets the usual eavesdropper's garble, nobody else hears anything. The voice
 * bark layer wraps this one and still plays its blip at the old range.
 */
/mob/living/send_speech(message_raw, message_range = 6, obj/source = src, bubble_type = bubble_icon, list/spans, datum/language/message_language = null, list/message_mods = list(), forced = null, tts_message, list/tts_filter)
	if(cyberware_subvocal_pending)
		cyberware_subvocal_pending = FALSE
		message_range = 0
	return ..(message_raw, message_range, source, bubble_type, spans, message_language, message_mods, forced, tts_message, tts_filter)

// =========================================================================
// MUFFLER EAR
// =========================================================================

/**
 * # Muffler ear (T1, head, ears slot, load 1)
 *
 * Takes one point off the intensity of a bang, which is exactly what earmuffs do
 * (code/datums/components/earprotection.dm, sender soundbang_act in
 * carbon_defense.dm). The listener is registered by the passive hooks, so an
 * offline ear hears the bang in full. Same slot as the Heartbeat Doppler.
 */
/obj/item/organ/cyberimp/cyberware/muffler_ear
	name = "\improper Muffler ear"
	desc = "Baffles set into the ear canal. Earmuffs you can't leave on the bridge."
	icon_state = "muffler_ear"
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_CYBERWARE_EARS
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	/// Intensity taken off a bang.
	var/bang_reduction = 1

/obj/item/organ/cyberimp/cyberware/muffler_ear/chrome_passives_on(mob/living/carbon/bearer)
	. = ..()
	if(isnull(bearer))
		return
	RegisterSignal(bearer, COMSIG_CARBON_SOUNDBANG, PROC_REF(on_soundbang), override = TRUE)

/obj/item/organ/cyberimp/cyberware/muffler_ear/chrome_passives_off(mob/living/carbon/bearer)
	. = ..()
	if(isnull(bearer))
		return
	UnregisterSignal(bearer, COMSIG_CARBON_SOUNDBANG)

/// Signal proc for [COMSIG_CARBON_SOUNDBANG]: the intensity rides in a list so
/// listeners can change it.
/obj/item/organ/cyberimp/cyberware/muffler_ear/proc/on_soundbang(datum/source, list/reflist)
	SIGNAL_HANDLER
	reflist[1] -= bang_reduction

// =========================================================================
// SHOP SKUS: not listed on any vendor yet, the integration pass adds them to
// the Chop Shop's sku_types and to the street doc's.
// =========================================================================

/datum/shop_sku/ripperdoc/clotter_node
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/clotter_node
	price_credits = 900

/datum/shop_sku/ripperdoc/adrenal_pump
	zone_permission = ZONE_PERMISSION_YELLOW
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/adrenal_pump
	price_credits = 2400

/datum/shop_sku/ripperdoc/medic_palms
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/medic_palms
	price_credits = 600

/datum/shop_sku/ripperdoc/cuffer_wrists
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/cuffer_wrists
	price_credits = 500

/datum/shop_sku/ripperdoc/subvocal_mic
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/subvocal_mic
	price_credits = 600

/datum/shop_sku/ripperdoc/muffler_ear
	category = "Street Chrome"
	item_path = /obj/item/organ/cyberimp/cyberware/muffler_ear
	price_credits = 700

// =========================================================================
// TRADE-IN: half list, credits only. Not listed on any buyback_types yet, same
// integration pass as above. Ratchet's entries (/street_doc) differ only in wording.
// =========================================================================

/datum/shop_buyback/ripperdoc/clotter_node
	name = "Clotter node (pulled)"
	desc = "A used clotting-gel reservoir."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/clotter_node
	match_subtypes = FALSE
	pay_credits = 450
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/clotter_node/street_doc
	desc = "A used gel reservoir. Still sticky."

/datum/shop_buyback/ripperdoc/adrenal_pump
	name = "Adrenal pump (pulled)"
	desc = "A used adrenaline pump. Credit toward something sturdier."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/adrenal_pump
	match_subtypes = FALSE
	pay_credits = 1200
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/ripperdoc/adrenal_pump/street_doc
	desc = "A used heart pump. Handle it gently."

/datum/shop_buyback/ripperdoc/medic_palms
	name = "Medic's palms (pulled)"
	desc = "Used sterile palm plates."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/medic_palms
	match_subtypes = FALSE
	pay_credits = 300
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/medic_palms/street_doc
	desc = "Used palm plates. Washed, mostly."

/datum/shop_buyback/ripperdoc/cuffer_wrists
	name = "Cuffer's wrists (pulled)"
	desc = "Used wrist actuators."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/cuffer_wrists
	match_subtypes = FALSE
	pay_credits = 250
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/cuffer_wrists/street_doc
	desc = "Used wrist actuators. They've seen some arrests."

/datum/shop_buyback/ripperdoc/subvocal_mic
	name = "Subvocal mic (pulled)"
	desc = "A used throat mic."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/subvocal_mic
	match_subtypes = FALSE
	pay_credits = 300
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/subvocal_mic/street_doc
	desc = "A used throat mic. Don't ask what it heard."

/datum/shop_buyback/ripperdoc/muffler_ear
	name = "Muffler ear (pulled)"
	desc = "Used ear baffles."
	category = "Trade-In"
	item_path = /obj/item/organ/cyberimp/cyberware/muffler_ear
	match_subtypes = FALSE
	pay_credits = 350
	demand_min = 2
	demand_max = 3

/datum/shop_buyback/ripperdoc/muffler_ear/street_doc
	desc = "Used ear baffles. Quiet ones."
