/**
 * # Second Wind Bladder (T1, chest, seal slot, load 1)
 *
 * The framework's pilot ware: a polymer air bladder that quietly feeds you
 * when the room stops doing it. No tank object anywhere — organ-held tanks
 * fail invalid_internals(), so this rides COMSIG_CARBON_ATTEMPT_BREATHE and
 * simply supplies the blocked breath itself while reserve lasts. Reserve
 * covers ~3 minutes of vacuum and refills at twice that rate in air.
 *
 * Rung one of the `cyberware_seal` ladder; Coolant Loops and the Void-Rated
 * Chassis evict it later.
 */
/obj/item/organ/cyberimp/cyberware/second_wind
	name = "\improper Second Wind bladder"
	desc = "A vacuum-cured polymer bladder plumbed around the lungs. When the air runs out it kicks in with a hiss and buys you three minutes to fix that; it tops itself back up off every breath you don't need it for."
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

/obj/item/organ/cyberimp/cyberware/second_wind/examine(mob/user)
	. = ..()
	var/seconds_left = round(reserve / (1 SECONDS))
	. += span_notice("The reserve gauge reads <b>[seconds_left]</b> seconds of air[reserve < CYBERWARE_SECOND_WIND_RESERVE ? " and climbing when its bearer breathes freely" : " — full"].")

/obj/item/organ/cyberimp/cyberware/second_wind/on_mob_insert(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	RegisterSignal(organ_owner, COMSIG_CARBON_ATTEMPT_BREATHE, PROC_REF(on_attempt_breathe))

/obj/item/organ/cyberimp/cyberware/second_wind/on_mob_remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	UnregisterSignal(organ_owner, COMSIG_CARBON_ATTEMPT_BREATHE)
	engaged = FALSE

/**
 * Signal proc for [COMSIG_CARBON_ATTEMPT_BREATHE]. Fires at the very top of
 * every breath: in breathable air we top the reserve up, in anything else we
 * spend reserve and block the breath outright. Blocking skips the whole
 * breathe() chain — including its alert bookkeeping — so we settle
 * failed_last_breath and the oxygen alert ourselves.
 */
/obj/item/organ/cyberimp/cyberware/second_wind/proc/on_attempt_breathe(mob/living/carbon/source, seconds_per_tick, times_fired)
	SIGNAL_HANDLER
	if(organ_flags & ORGAN_FAILING) // browned out or EMP-scrambled: dead weight
		return NONE
	if(HAS_TRAIT(source, TRAIT_NOBREATH))
		return NONE
	if(source.internal || source.external) // on tank internals — their air, not ours
		return NONE
	if(environment_is_breathable(source))
		if(engaged)
			set_engaged(source, FALSE)
		if(reserve < CYBERWARE_SECOND_WIND_RESERVE)
			reserve = min(reserve + CYBERWARE_SECOND_WIND_REFILL, CYBERWARE_SECOND_WIND_RESERVE)
		return NONE
	if(reserve <= 0)
		if(engaged)
			set_engaged(source, FALSE)
			source.balloon_alert(source, "air reserve empty!")
		return NONE
	if(!engaged)
		set_engaged(source, TRUE)
	reserve = max(reserve - CYBERWARE_SECOND_WIND_DRAIN, 0)
	// This IS a successful breath as far as the body is concerned.
	source.failed_last_breath = FALSE
	source.clear_alert(ALERT_NOT_ENOUGH_OXYGEN)
	return COMSIG_CARBON_BLOCK_BREATH

/// The engage/disengage transition beats: the design's sharp-intake moment.
/obj/item/organ/cyberimp/cyberware/second_wind/proc/set_engaged(mob/living/carbon/source, new_state)
	if(engaged == new_state)
		return
	engaged = new_state
	if(engaged)
		INVOKE_ASYNC(source, TYPE_PROC_REF(/mob, emote), "gasp")
		source.balloon_alert(source, "second wind engages")
		playsound(source, 'sound/machines/hiss.ogg', 30, TRUE)
	else
		source.balloon_alert(source, "second wind disengages")

/**
 * Whether the mob's surroundings hold enough oxygen to breathe unassisted:
 * environmental O2 partial pressure (plus pluoxium at its usual 8x weight)
 * against the lungs' 16 kPa floor. Deliberately O2-only — exotic breathers
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
	var/list/env_gases = environment.gases
	var/oxygen_moles = env_gases[/datum/gas/oxygen] ? env_gases[/datum/gas/oxygen][MOLES] : 0
	var/pluoxium_moles = env_gases[/datum/gas/pluoxium] ? env_gases[/datum/gas/pluoxium][MOLES] : 0
	var/oxygen_pp = environment.return_pressure() * ((oxygen_moles + PLUOXIUM_PROPORTION * pluoxium_moles) / total_moles)
	return oxygen_pp >= CYBERWARE_BREATHABLE_O2_KPA
