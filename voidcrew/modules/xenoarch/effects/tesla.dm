// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/tesla.dm.
// Voidcrew: ZAP_GENERATES_POWER removed, so tesla coils get nothing from it; weaker arcs (Nova's
// reached 90 burn); not harvestable; logged.

/datum/artifact_effect/tesla
	label_name = "Lightning"
	log_name = "Tesla"
	tier = ARTIFACT_TIER_EXTREME
	harvestable = FALSE
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_ELECTROMAGNETIC, ARTIFACT_ENERGY_CONCENTRATED)
	allowed_release_methods = list(ARTIFACT_RELEASE_PULSE)
	/// Never ZAP_GENERATES_POWER: no running a ship off an artifact.
	var/zap_flags = ZAP_OBJ_DAMAGE | ZAP_MOB_DAMAGE | ZAP_MOB_STUN

/datum/artifact_effect/tesla/setup()
	maximum_charges = max(maximum_charges, 15)

/datum/artifact_effect/tesla/do_effect_pulse(power)
	if(QDELETED(holder))
		return
	var/reach = 3 + rand(0, 2)
	playsound(holder, 'sound/effects/magic/lightningshock.ogg', 60, TRUE, extrarange = 5)
	tesla_zap(source = holder, zap_range = reach, power = rand(12, 30) * 1000, cutoff = 1e4, zap_flags = zap_flags)
	for(var/mob/living/target in range(reach, source_turf()))
		log_harm(target)
