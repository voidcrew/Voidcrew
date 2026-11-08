// Artifact effect: berserk.
// Rewritten from Polaris (6cd19fe0dec6) code/modules/xenoarcheaology/effects/berserk.dm, also in
// VOREStation (9335d66b9fdf). Voidcrew: a status effect instead of Polaris' /datum/modifier. Rage
// makes every punch land, weapons hit a quarter harder and swings come faster; when it ends the
// person is drained and slow for a while, and can't be enraged again until they recover. Polaris'
// brain damage per dose is dropped: the crash afterwards is the price. Works on people only.
// Logged like harm, since the crash is forced on whoever it touches.

/datum/artifact_effect/bestow/berserk
	label_name = "Rage"
	log_name = "Berserk"
	tier = ARTIFACT_TIER_UNCOMMON
	harmful = TRUE
	possible_kinds = list(ARTIFACT_ENERGY_PSIONIC, ARTIFACT_ENERGY_ORGANIC)
	status_type = /datum/status_effect/artifact/berserk
	touch_duration = 30 SECONDS
	pulse_duration = 25 SECONDS
	aura_duration = 10 SECONDS
	aura_chance = 6

/datum/artifact_effect/bestow/berserk/can_bestow(mob/living/target)
	return ..() && iscarbon(target) && target.stat == CONSCIOUS

/datum/artifact_effect/bestow/berserk/on_bestowed(mob/living/target)
	target.visible_message(
		span_warning("[target]'s face twists with sudden fury."),
		span_userdanger("Heat floods your face. Your hands want something to break."),
	)
	playsound(target, 'sound/effects/magic/demon_attack1.ogg', 15, TRUE, SILENCED_SOUND_EXTRARANGE)

/datum/artifact_effect/bestow/berserk/on_renewed(mob/living/target)
	to_chat(target, span_warning("Your anger flares up again."))

/datum/artifact_effect/bestow/berserk/on_refused(mob/living/target)
	to_chat(target, span_notice("A flash of anger comes and goes. You're too tired to hold onto it."))
