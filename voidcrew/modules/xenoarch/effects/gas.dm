// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/gas.dm.
// Voidcrew: oxygen, nitrogen or carbon dioxide only (plasma and nitrous oxide are their own
// effects); room-temperature gas; vents indoors only, never into planet air; stops at a modest
// pressure; no destroy burst. Like the Polaris vents (effects_polaris/plasma_vent.dm) it holds a
// finite reserve, less than one gas contract asks for, shared with any battery drawn off it, so it
// is never a free nitrogen well for gas contracts.

/datum/artifact_effect/gas
	label_name = "Vents gas"
	log_name = "Gas"
	tier = ARTIFACT_TIER_COMMON
	possible_kinds = list(ARTIFACT_ENERGY_PARTICLE, ARTIFACT_ENERGY_SYNTHESIS)
	/// The gas it vents
	var/gas_type = /datum/gas/oxygen
	/// It stops venting once its tile reaches this pressure (kPa)
	var/max_pressure = ONE_ATMOSPHERE
	/// Moles left in it; it runs dry for good when this hits zero
	var/reserve = 0
	/// Said it was dry
	var/announced_dry = FALSE

/datum/artifact_effect/gas/setup()
	var/static/list/gas_weights = list(
		/datum/gas/oxygen = 4,
		/datum/gas/nitrogen = 4,
		/datum/gas/carbon_dioxide = 2,
	)
	gas_type = pick_weight(gas_weights)
	max_pressure = rand(105, 150)
	reserve = rand(150, 300)

// Half of what is left goes with a harvest copy, so the reserve is shared, never doubled.
/datum/artifact_effect/gas/copy_settings_to(datum/artifact_effect/gas/copy)
	copy.gas_type = gas_type
	copy.max_pressure = max_pressure
	copy.reserve = round(reserve / 2)
	reserve -= copy.reserve

/datum/artifact_effect/gas/is_spent()
	return reserve <= 0

/datum/artifact_effect/gas/do_effect_touch(mob/living/user)
	if(vent(rand(2, 8)))
		to_chat(user, span_warning("Gas hisses out of [holder] around your hand."))

/datum/artifact_effect/gas/do_effect_aura(seconds_per_tick)
	vent(rand(0, 3) * seconds_per_tick)

/datum/artifact_effect/gas/do_effect_pulse(power)
	if(vent(power / 2))
		playsound(holder, 'sound/effects/spray.ogg', 40, TRUE)

/datum/artifact_effect/gas/do_effect_destroy()
	return

/// Lets up to `moles` of its gas out onto its tile, from its reserve. Returns TRUE if any came out.
/datum/artifact_effect/gas/proc/vent(moles)
	if(moles <= 0)
		return FALSE
	var/turf/open/here = source_turf()
	if(!istype(here) || here.planetary_atmos || isspaceturf(here))
		return FALSE
	if(reserve <= 0)
		run_dry(here)
		return FALSE
	var/datum/gas_mixture/air = here.return_air()
	if(!air || air.return_pressure() >= max_pressure)
		return FALSE
	moles = min(moles, reserve)
	reserve -= moles
	var/datum/gas_mixture/puff = new
	puff.assert_gas(gas_type)
	puff.gases[gas_type][MOLES] = moles
	puff.temperature = T20C
	here.assume_air(puff)
	return TRUE

/// Its reserve is spent: one last hiss, then nothing ever again.
/datum/artifact_effect/gas/proc/run_dry(turf/here)
	if(announced_dry)
		return
	announced_dry = TRUE
	here.visible_message(span_notice("[holder] gives a thin hiss, and nothing more comes out."))
	playsound(here, 'sound/effects/spray3.ogg', 25, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)
