// Hyperviolence aimed crits on humanoid basic mobs: NPC pirates, troopers, bounty criminals and
// the like. They have no limbs, organs or worn armour, so a crit is a status effect instead of a
// wound: a blow sized to the mob's max health (so health scaling at the spawn site still works),
// a short stun for some, and a bleed for the throat and aorta. The effect stays on the mob so the
// same crit cannot land on it twice.
//
// Bosses are humanoid basic mobs too. The damage is worked out from at most
// HV_BASIC_CRIT_HEALTH_CAP of their health, so a crit hurts a 2,000 health boss about as much as a
// tough pirate, and boss-sized mobs are never stunned or silenced by one.

/// Crit damage on a basic mob is a share of its max health, but never of more than this.
#define HV_BASIC_CRIT_HEALTH_CAP 200
/// Mobs with more max health than this are boss-sized: no stun, no silencing.
#define HV_BASIC_CRIT_BOSS_HEALTH 300

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
		owner.adjustBruteLoss(crit_health() * blow_share)
	if(stun_time && owner.stat != DEAD && !boss_sized())
		owner.Stun(stun_time)
	owner.hv_blood_spray(attack_direction, 2)
	owner.add_splatter_floor(get_turf(owner)) // NPCs have blood since the hit-lines part (npc_blood.dm)
	return TRUE

/// The health the crit's damage is worked out from.
/datum/status_effect/hv_crit_basic/proc/crit_health()
	return min(owner.maxHealth, HV_BASIC_CRIT_HEALTH_CAP)

/datum/status_effect/hv_crit_basic/proc/boss_sized()
	return owner.maxHealth > HV_BASIC_CRIT_BOSS_HEALTH

/datum/status_effect/hv_crit_basic/eye
	id = "hv_crit_basic_eye"
	blow_share = 0.15
	stun_time = 1.5 SECONDS

/datum/status_effect/hv_crit_basic/tongue
	id = "hv_crit_basic_tongue"
	blow_share = 0.1

/datum/status_effect/hv_crit_basic/tongue/on_apply()
	. = ..()
	if(!boss_sized())
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
	owner.adjustBruteLoss(crit_health() * bleed_share * bled)
	if(prob(50))
		owner.hv_blood_spray(pick(GLOB.alldirs), 2)
	else
		owner.add_splatter_floor(get_turf(owner), small_drip = TRUE)
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

#undef HV_BASIC_CRIT_HEALTH_CAP
#undef HV_BASIC_CRIT_BOSS_HEALTH
