// Hyperviolence aimed crits on humanoid basic mobs: NPC pirates, troopers, bounty criminals and
// the like. They have no limbs, organs or worn armour, so a crit is a status effect instead of a
// wound: a blow sized to the mob's max health (so health scaling at the spawn site still works),
// a short stun for some, and a bleed for the throat and aorta. The effect stays on the mob so the
// same crit cannot land on it twice.

/datum/status_effect/hv_crit_basic
	id = "hv_crit_basic"
	alert_type = null
	duration = STATUS_EFFECT_PERMANENT
	tick_interval = STATUS_EFFECT_NO_TICK
	status_type = STATUS_EFFECT_UNIQUE
	remove_on_fullheal = TRUE
	/// Brute damage dealt when it lands, as a share of max health.
	var/blow_share = 0.1
	/// Stun when it lands.
	var/stun_time = 0
	/// Which way the blow went, for blood.
	var/attack_direction

/datum/status_effect/hv_crit_basic/on_creation(mob/living/new_owner, attack_direction)
	src.attack_direction = attack_direction
	return ..()

/datum/status_effect/hv_crit_basic/on_apply()
	if(blow_share)
		owner.adjustBruteLoss(owner.maxHealth * blow_share)
	if(stun_time && owner.stat != DEAD)
		owner.Stun(stun_time)
	owner.hv_blood_spray(attack_direction, 2)
	return TRUE

/datum/status_effect/hv_crit_basic/eye
	id = "hv_crit_basic_eye"
	blow_share = 0.15
	stun_time = 1.5 SECONDS

/datum/status_effect/hv_crit_basic/tongue
	id = "hv_crit_basic_tongue"
	blow_share = 0.1

/datum/status_effect/hv_crit_basic/tongue/on_apply()
	. = ..()
	ADD_TRAIT(owner, TRAIT_MUTE, HV_CRIT_TRAIT)

/datum/status_effect/hv_crit_basic/tongue/on_remove()
	REMOVE_TRAIT(owner, TRAIT_MUTE, HV_CRIT_TRAIT)
	return ..()

/datum/status_effect/hv_crit_basic/jaw
	id = "hv_crit_basic_jaw"
	blow_share = 0.15
	stun_time = 1 SECONDS

/datum/status_effect/hv_crit_basic/skull
	id = "hv_crit_basic_skull"
	blow_share = 0.3
	stun_time = 3 SECONDS

/// The throat and aorta: a share of max health bled away each second until the budget runs out.
/datum/status_effect/hv_crit_basic/bleed
	tick_interval = 2 SECONDS
	blow_share = 0.05
	/// Share of max health lost per second while bleeding.
	var/bleed_share = 0.02
	/// Seconds of bleeding left.
	var/bleed_left = 30

/datum/status_effect/hv_crit_basic/bleed/tick(seconds_between_ticks)
	if(owner.stat == DEAD || bleed_left <= 0)
		return
	var/bled = min(seconds_between_ticks, bleed_left)
	bleed_left -= bled
	owner.adjustBruteLoss(owner.maxHealth * bleed_share * bled)
	if(prob(50))
		owner.hv_blood_spray(pick(GLOB.alldirs), 2)
	if(bleed_left <= 0)
		// Stays on as a marker so the crit cannot land again, but stops ticking.
		tick_interval = STATUS_EFFECT_NO_TICK
		STOP_PROCESSING(SSfastprocess, src)

/datum/status_effect/hv_crit_basic/bleed/throat
	id = "hv_crit_basic_throat"
	bleed_share = 0.025

/datum/status_effect/hv_crit_basic/bleed/aorta
	id = "hv_crit_basic_aorta"
	bleed_share = 0.02
