// Artifact effect: plasma vent.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/gasphoron.dm.
// Voidcrew: vents plasma (Polaris' "phoron") indoors only: never into planet air, never into space.
// Each vent stops at a modest pressure on its tile, and holds a finite reserve, less than one gas
// contract asks for, so it can never become a free plasma well. Plasma air never wakes it, or it
// would feed itself. Everyone breathing near it is logged. Not harvestable.
//
// Also the shared parent for gas vents with a reserve (sleeping gas uses it).

/datum/artifact_effect/gas_vent
	harvestable = FALSE
	harmful = TRUE
	/// The /datum/gas it vents
	var/gas_type
	/// Gas puff colour
	var/puff_color = "#ffffff"
	/// Moles left in it; it runs dry for good when this hits zero
	var/reserve = 0
	var/reserve_low = 100
	var/reserve_high = 200
	/// It stops venting once its tile reaches this pressure (kPa)
	var/max_pressure = ONE_ATMOSPHERE
	/// Said it was dry
	var/announced_dry = FALSE

/datum/artifact_effect/gas_vent/setup()
	reserve = rand(reserve_low, reserve_high)
	max_pressure = rand(110, 140)

// Half of what is left goes with a copy, so the reserve is shared, never doubled.
/datum/artifact_effect/gas_vent/copy_settings_to(datum/artifact_effect/gas_vent/copy)
	copy.reserve = round(reserve / 2)
	reserve -= copy.reserve
	copy.max_pressure = max_pressure

/datum/artifact_effect/gas_vent/is_spent()
	return reserve <= 0

/datum/artifact_effect/gas_vent/do_effect_touch(mob/living/user)
	if(vent(rand(3, 8)))
		to_chat(user, span_warning("Gas hisses out of [holder] around your hand."))

/datum/artifact_effect/gas_vent/do_effect_aura(seconds_per_tick)
	if(SPT_PROB(50, seconds_per_tick))
		vent(rand(1, 3))

/datum/artifact_effect/gas_vent/do_effect_pulse(power)
	vent(clamp(power / 2, 3, 20))

/**
 * Lets up to `moles` of its gas out onto its tile, from its reserve. Indoors only: never a planet
 * turf (whose air is shared), never space. Returns the moles that came out.
 */
/datum/artifact_effect/gas_vent/proc/vent(moles)
	if(moles <= 0 || !gas_type)
		return 0
	var/turf/open/here = source_turf()
	if(!istype(here) || here.planetary_atmos || isspaceturf(here))
		return 0
	if(reserve <= 0)
		run_dry(here)
		return 0
	var/datum/gas_mixture/air = here.return_air()
	if(!air || air.return_pressure() >= max_pressure)
		return 0
	moles = min(moles, reserve)
	reserve -= moles
	var/datum/gas_mixture/puff = new
	puff.assert_gas(gas_type)
	puff.gases[gas_type][MOLES] = moles
	puff.temperature = T20C
	here.assume_air(puff)
	var/obj/effect/temp_visual/artifact_gas_puff/cloud = new(here)
	cloud.color = puff_color
	playsound(here, 'sound/effects/spray2.ogg', 20, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
	for(var/mob/living/breather in living_in_range())
		log_harm(breather)
	return moles

/// Its reserve is spent: one last wheeze, then nothing ever again.
/datum/artifact_effect/gas_vent/proc/run_dry(turf/here)
	if(announced_dry)
		return
	announced_dry = TRUE
	here.visible_message(span_notice("[holder] wheezes, and nothing more comes out."))
	playsound(here, 'sound/effects/spray3.ogg', 25, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)

/datum/artifact_effect/gas_vent/plasma
	label_name = "Vents plasma"
	log_name = "Plasma vent"
	tier = ARTIFACT_TIER_UNCOMMON
	possible_kinds = list(ARTIFACT_ENERGY_BLUESPACE, ARTIFACT_ENERGY_SYNTHESIS)
	// Every trigger but plasma air, which it would make itself.
	allowed_triggers = list(
		ARTIFACT_TRIGGER_TOUCH,
		ARTIFACT_TRIGGER_WATER,
		ARTIFACT_TRIGGER_ACID,
		ARTIFACT_TRIGGER_VOLATILE,
		ARTIFACT_TRIGGER_TOXIN,
		ARTIFACT_TRIGGER_IMPACT,
		ARTIFACT_TRIGGER_ENERGY,
		ARTIFACT_TRIGGER_HEAT,
		ARTIFACT_TRIGGER_COLD,
		ARTIFACT_TRIGGER_CO2,
		ARTIFACT_TRIGGER_PROXIMITY,
	)
	gas_type = /datum/gas/plasma
	puff_color = "#c95ad8"
	reserve_low = 150
	reserve_high = 300

/// A small cloud of vented gas.
/obj/effect/temp_visual/artifact_gas_puff
	icon_state = "smoke"
	alpha = 120
	duration = 1.2 SECONDS

/obj/effect/temp_visual/artifact_gas_puff/Initialize(mapload)
	. = ..()
	pixel_x = rand(-4, 4)
	animate(src, alpha = 0, pixel_y = 10, time = duration)
