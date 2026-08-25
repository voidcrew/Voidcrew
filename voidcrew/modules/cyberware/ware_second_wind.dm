/**
 * # Second Wind Bladder (T1, chest, seal slot, load 1)
 *
 * The framework's pilot ware: a polymer air bladder that quietly feeds you
 * when the room stops doing it. No tank object anywhere, organ-held tanks
 * fail invalid_internals(), so this rides COMSIG_CARBON_ATTEMPT_BREATHE and
 * simply supplies the blocked breath itself while reserve lasts. Reserve
 * covers ~3 minutes of vacuum and refills at twice that rate in air.
 *
 * Because it works by NOT letting anything happen to you, it needs to be
 * loud about being on, or the first you learn of it is when it runs out.
 * Engaging throws a HUD alert that reads like a set of internals and carries
 * the reserve in its tooltip, starts a mask-breathing loop you and anyone
 * next to you can hear, and lights the bearer's ink. The reserve warns once
 * on its way down and again when it's gone.
 *
 * Rung one of the `cyberware_seal` ladder; Coolant Loops evicts it later.
 */

/**
 * The engaged indicator. Deliberately tg's internals-on button rather than
 * an alert sprite of its own: everyone already reads that icon as "your air
 * is coming from hardware", which is exactly what the bladder is doing.
 * Alert re-styling only reskins states named "template" (alert.dm:1122), so
 * an explicit icon here survives every UI style.
 */
/atom/movable/screen/alert/cyberware_second_wind
	name = "Second Wind Engaged"
	desc = "Your Second Wind bladder is doing your breathing for you."
	icon = 'icons/hud/screen_gen.dmi'
	icon_state = "internal1"

/// The mask-breathing loop the bladder runs while it is feeding you. Quiet
/// and short-ranged, the wearer is meant to hear it, the room is meant to
/// only just notice.
/datum/looping_sound/breathing/cyberware_second_wind
	volume = 20
	mid_length = 5 SECONDS
	mid_length_vary = 0.5 SECONDS
	extra_range = -3

/obj/item/organ/cyberimp/cyberware/second_wind
	name = "\improper Second Wind bladder"
	desc = "A vacuum-cured polymer bladder plumbed around the lungs. When the air runs out it kicks in with a hiss and gives you about three minutes to do something about it, then refills off every breath you take normally. You'll know when it's running: the mask-breathing is loud and the indicator is hard to miss."
	icon_state = "second_wind"
	zone = BODY_ZONE_CHEST
	slot = ORGAN_SLOT_CYBERWARE_SEAL
	w_class = WEIGHT_CLASS_SMALL
	chrome_load = 1
	tier = CYBERWARE_TIER_1
	/// Breathable reserve remaining, in deciseconds of breathing covered.
	var/reserve = CYBERWARE_SECOND_WIND_RESERVE
	/// TRUE while feeding the owner from reserve, for the engage/disengage beats.
	var/engaged = FALSE
	/// Whether the low-reserve warning has already fired this engagement, so
	/// the bladder nags once rather than on every breath.
	var/low_warned = FALSE
	/// The breathing loop, minted with the bearer.
	var/datum/looping_sound/breathing/cyberware_second_wind/breath_loop

/obj/item/organ/cyberimp/cyberware/second_wind/Destroy()
	QDEL_NULL(breath_loop)
	return ..()

/obj/item/organ/cyberimp/cyberware/second_wind/examine(mob/user)
	. = ..()
	var/seconds_left = round(reserve / (1 SECONDS))
	. += span_notice("The reserve gauge reads <b>[seconds_left]</b> seconds of air[reserve < CYBERWARE_SECOND_WIND_RESERVE ? ", refilling while its bearer breathes normally" : " (full)"].")

/obj/item/organ/cyberimp/cyberware/second_wind/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_CARBON_ATTEMPT_BREATHE, PROC_REF(on_attempt_breathe))
	// A corpse stops breathing, so nothing would ever call the disengage path
	// and the indicator would sit on the HUD forever.
	RegisterSignal(organ_owner, COMSIG_LIVING_DEATH, PROC_REF(on_owner_death))
	breath_loop = new(organ_owner, FALSE)

/obj/item/organ/cyberimp/cyberware/second_wind/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, list(COMSIG_CARBON_ATTEMPT_BREATHE, COMSIG_LIVING_DEATH))
	shut_down(organ_owner)
	QDEL_NULL(breath_loop)

/// Signal proc for [COMSIG_LIVING_DEATH].
/obj/item/organ/cyberimp/cyberware/second_wind/proc/on_owner_death(mob/living/carbon/source)
	SIGNAL_HANDLER
	shut_down(source)

/// Everything the engaged state owns, torn down without the disengage beats.
/// For the paths (death, extraction) where nobody is left to hear them.
/obj/item/organ/cyberimp/cyberware/second_wind/proc/shut_down(mob/living/carbon/source)
	engaged = FALSE
	low_warned = FALSE
	breath_loop?.stop()
	source?.clear_alert(ALERT_CYBERWARE_SECOND_WIND)

/**
 * Signal proc for [COMSIG_CARBON_ATTEMPT_BREATHE]. Fires at the very top of
 * every breath: in breathable air we top the reserve up, in anything else we
 * spend reserve and block the breath outright. Blocking skips the whole
 * breathe() chain (including its alert bookkeeping) so we settle
 * failed_last_breath and the oxygen alert ourselves.
 */
/obj/item/organ/cyberimp/cyberware/second_wind/proc/on_attempt_breathe(mob/living/carbon/source, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING) // browned out or EMP-scrambled: dead weight
		if(engaged)
			set_engaged(source, FALSE)
		return NONE
	if(HAS_TRAIT(source, TRAIT_NOBREATH))
		return NONE
	if(source.internal || source.external) // on tank internals, their air, not ours
		if(engaged)
			set_engaged(source, FALSE)
		return NONE
	if(environment_is_breathable(source))
		if(engaged)
			set_engaged(source, FALSE)
		if(reserve < CYBERWARE_SECOND_WIND_RESERVE)
			reserve = min(reserve + CYBERWARE_SECOND_WIND_REFILL, CYBERWARE_SECOND_WIND_RESERVE)
			low_warned = FALSE
		return NONE
	if(reserve <= 0)
		if(engaged)
			set_engaged(source, FALSE)
			source.balloon_alert(source, "air reserve empty!")
			to_chat(source, span_userdanger("Your Second Wind bladder collapses empty. You are breathing vacuum."))
			playsound(source, 'sound/machines/buzz/buzz-sigh.ogg', 40, TRUE)
		return NONE
	if(!engaged)
		set_engaged(source, TRUE)
	reserve = max(reserve - CYBERWARE_SECOND_WIND_DRAIN, 0)
	update_alert(source)
	if(!low_warned && reserve <= CYBERWARE_SECOND_WIND_LOW)
		low_warned = TRUE
		to_chat(source, span_warning("Your bladder gauge drops into the red, <b>[round(reserve / (1 SECONDS))]</b> seconds of air left."))
		playsound(source, 'sound/machines/buzz/buzz-two.ogg', 30, TRUE)
	// This IS a successful breath as far as the body is concerned.
	source.failed_last_breath = FALSE
	source.clear_alert(ALERT_NOT_ENOUGH_OXYGEN)
	return COMSIG_CARBON_BLOCK_BREATH

/// The engage/disengage transition beats: the design's sharp-intake moment,
/// plus everything that keeps the state legible while it lasts.
/obj/item/organ/cyberimp/cyberware/second_wind/proc/set_engaged(mob/living/carbon/source, new_state)
	if(engaged == new_state)
		return
	engaged = new_state
	if(engaged)
		INVOKE_ASYNC(source, TYPE_PROC_REF(/mob, emote), "gasp")
		source.balloon_alert(source, "second wind engages")
		source.visible_message(
			span_notice("[source] takes a sharp breath, and something under [source.p_their()] ribs starts working."),
			span_notice("<b>SEAL ENGAGED.</b> The bladder takes your breathing off you. You have [round(reserve / (1 SECONDS))] seconds of air."),
			span_hear("You hear a pneumatic hiss and the rhythm of mask breathing."),
			vision_distance = COMBAT_MESSAGE_RANGE,
		)
		playsound(source, 'sound/machines/hiss.ogg', 30, TRUE)
		cyberware_ink_pulse(source, CYBERWARE_INK_FLARE)
		breath_loop?.start(source)
		update_alert(source)
		return
	source.balloon_alert(source, "second wind disengages")
	to_chat(source, span_notice("<b>SEAL RELEASED.</b> You are breathing the room again."))
	cyberware_ink_pulse(source, CYBERWARE_INK_SOFT)
	breath_loop?.stop()
	source.clear_alert(ALERT_CYBERWARE_SECOND_WIND)
	low_warned = FALSE

/**
 * Keeps the HUD indicator honest: present only while engaged, amber once the
 * reserve is into its last [CYBERWARE_SECOND_WIND_LOW / (1 SECONDS)] seconds,
 * and carrying the live gauge in the tooltip either way.
 */
/obj/item/organ/cyberimp/cyberware/second_wind/proc/update_alert(mob/living/carbon/source)
	if(!engaged)
		source.clear_alert(ALERT_CYBERWARE_SECOND_WIND)
		return
	var/atom/movable/screen/alert/indicator = source.throw_alert(ALERT_CYBERWARE_SECOND_WIND, /atom/movable/screen/alert/cyberware_second_wind)
	if(!istype(indicator))
		return
	var/seconds_left = round(reserve / (1 SECONDS))
	var/running_low = reserve <= CYBERWARE_SECOND_WIND_LOW
	indicator.color = running_low ? "#ffb347" : "#4dd8e6"
	indicator.desc = "Your Second Wind bladder is doing your breathing for you. [seconds_left] second\s of reserve air left[running_low ? ". Find air." : "."]"

/**
 * Whether the mob's surroundings hold enough oxygen to breathe unassisted:
 * environmental O2 partial pressure (plus pluoxium at its usual 8x weight)
 * against the lungs' 16 kPa floor. Deliberately O2-only, exotic breathers
 * get little from a bladder that stores baseline air, and toxic-but-oxygenated
 * rooms are the Hemoglass Filter's problem, not the seal ladder's.
 */
/obj/item/organ/cyberimp/cyberware/second_wind/proc/environment_is_breathable(mob/living/carbon/source)
	var/datum/gas_mixture/environment = source.loc?.return_air()
	if(!environment)
		return FALSE
	var/total_moles = environment.total_moles()
	if(total_moles <= 0)
		return FALSE
	// The 2026 upstream merge flattened gas_mixture: the old `gases` list-of-lists
	// indexed by MOLES is now `moles`, a plain gas_id -> moles assoc list. A gas
	// that isn't present reads null, which is 0 for this arithmetic.
	var/list/env_gases = environment.moles
	var/oxygen_moles = env_gases[/datum/gas/oxygen] || 0
	var/pluoxium_moles = env_gases[/datum/gas/pluoxium] || 0
	var/oxygen_pp = environment.return_pressure() * ((oxygen_moles + PLUOXIUM_PROPORTION * pluoxium_moles) / total_moles)
	return oxygen_pp >= CYBERWARE_BREATHABLE_O2_KPA
