// Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/effects/noise.dm.
// Voidcrew: eerie sounds only (Nova's list mixed in bike horns and sitcom laughter); any trigger
// (Nova fixed it to oxygen, which is gone); not harvestable.

/datum/artifact_effect/noise
	label_name = "Noise"
	log_name = "Noise"
	tier = ARTIFACT_TIER_COMMON
	minor = TRUE
	harvestable = FALSE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC)
	allowed_release_methods = list(ARTIFACT_RELEASE_PULSE)

/datum/artifact_effect/noise/do_effect_pulse(power)
	var/static/list/noises = list(
		'sound/effects/hallucinations/wail.ogg',
		'sound/effects/hallucinations/far_noise.ogg',
		'sound/effects/hallucinations/veryfar_noise.ogg',
		'sound/effects/hallucinations/growl1.ogg',
		'sound/effects/hallucinations/growl2.ogg',
		'sound/effects/hallucinations/growl3.ogg',
		'sound/effects/hallucinations/radio_static.ogg',
		'sound/effects/screech.ogg',
		'sound/effects/gong.ogg',
		'sound/effects/clang.ogg',
		'sound/effects/magic/curse.ogg',
		'sound/ambience/misc/signal.ogg',
		'sound/machines/airlock/airlock_alien_prying.ogg',
		'sound/misc/scary_horn.ogg',
	)
	playsound(holder, pick(noises), 60, TRUE, extrarange = 6)

/datum/artifact_effect/noise/do_effect_destroy()
	playsound(holder, 'sound/effects/hallucinations/wail.ogg', 80, TRUE, extrarange = 20, pressure_affected = FALSE)
