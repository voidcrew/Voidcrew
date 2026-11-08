/**
 * # Finishers: the bosses that have one
 *
 * - The hoarfrost matriarch (Big Game Hunt, frozen worlds) pins, bites and tears off an arm.
 * - The Black Knight (medieval pirate boss) pins with a boot and cleaves through the hips.
 * - The alien empress of a derelict xeno nest pins and bites the head off.
 * - The Robust One (grey tide pirate boss) kneels on the chest and beats the head in.
 *
 * Each comes to about six seconds from the wind-up to the kill, with a minute between tries.
 *
 * Each boss gets its finisher from a second Initialize() on its type, here, so the files that own
 * those bosses stay untouched. DM chains duplicate overrides: both bodies run, and both call ..().
 */

// ===== The hoarfrost matriarch =====

/mob/living/basic/hoarfrost_matriarch/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/hoarfrost)

/datum/hv_finisher/hoarfrost
	name = "hoarfrost maul"
	// She has 800 health; the crew need a real volley to make her let go
	interrupt_damage = 60
	telegraph_state = "bite"
	zone_preference = list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM, BODY_ZONE_R_LEG, BODY_ZONE_L_LEG)
	stages = list(
		/datum/hv_finisher_stage/windup/hoarfrost,
		/datum/hv_finisher_stage/hold/hoarfrost,
		/datum/hv_finisher_stage/maul/hoarfrost,
		/datum/hv_finisher_stage/kill/rip_limb/hoarfrost,
		/datum/hv_finisher_stage/recover,
	)

/// Either arm, else either leg
/datum/hv_finisher/hoarfrost/pick_zone()
	var/list/arms = shuffle(list(BODY_ZONE_R_ARM, BODY_ZONE_L_ARM))
	var/list/legs = shuffle(list(BODY_ZONE_R_LEG, BODY_ZONE_L_LEG))
	zone_preference = arms + legs
	return ..()

/datum/hv_finisher_stage/windup/hoarfrost
	enter_sound = 'sound/effects/hallucinations/growl1.ogg'

/datum/hv_finisher_stage/windup/hoarfrost/enter_message()
	return "[host.user] lowers [host.user.p_their()] head over [host.victim] and growls."

/datum/hv_finisher_stage/hold/hoarfrost
	enter_sound = 'sound/effects/gravhit.ogg'

/datum/hv_finisher_stage/hold/hoarfrost/enter_message()
	return "[host.user] slams a paw down on [host.victim] and pins [host.victim.p_them()] to the ground!"

/datum/hv_finisher_stage/hold/hoarfrost/enter_self_message()
	return "A huge paw slams you into the ground!"

/datum/hv_finisher_stage/maul/hoarfrost
	duration = 2.5 SECONDS
	lunge = 10
	effect_sound = 'sound/items/weapons/bite.ogg'

/datum/hv_finisher_stage/maul/hoarfrost/effect_message()
	return "[host.user] sinks [host.user.p_their()] teeth into [host.victim]'s [target_limb_name()]!"

/datum/hv_finisher_stage/maul/hoarfrost/effect_self_message()
	return "[host.user] sinks [host.user.p_their()] teeth into your [target_limb_name()]!"

/datum/hv_finisher_stage/kill/rip_limb/hoarfrost
	lunge = -2
	rise = 4
	effect_sound = 'sound/effects/wounds/crackandbleed.ogg'

/datum/hv_finisher_stage/kill/rip_limb/hoarfrost/effect_message()
	return "[host.user] wrenches [host.user.p_their()] head back and tears [host.victim]'s [target_limb_name()] off!"

/datum/hv_finisher_stage/kill/rip_limb/hoarfrost/effect_self_message()
	return "[host.user] tears your [target_limb_name()] off!"

// ===== The Black Knight =====

/mob/living/basic/trooper/pirate/faction/boss/medieval/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/black_knight)

/datum/hv_finisher/black_knight
	name = "black knight cleave"
	telegraph_state = "skull"
	stages = list(
		/datum/hv_finisher_stage/windup/black_knight,
		/datum/hv_finisher_stage/hold/black_knight,
		/datum/hv_finisher_stage/hold/black_knight_raise,
		/datum/hv_finisher_stage/kill/bisect/black_knight,
		/datum/hv_finisher_stage/recover,
	)

/datum/hv_finisher_stage/windup/black_knight
	rise = 4
	enter_sound = 'sound/items/unsheath.ogg'
	say_line = "None shall pass."

/datum/hv_finisher_stage/windup/black_knight/enter_message()
	return "[host.user] raises [host.user.p_their()] claymore high over [host.victim]."

/datum/hv_finisher_stage/hold/black_knight
	enter_sound = 'sound/effects/hit_kick.ogg'

/datum/hv_finisher_stage/hold/black_knight/enter_message()
	return "[host.user] plants an armoured boot on [host.victim]'s chest."

/datum/hv_finisher_stage/hold/black_knight/enter_self_message()
	return "An armoured boot pins you to the floor!"

/datum/hv_finisher_stage/hold/black_knight_raise
	duration = 2 SECONDS
	lunge = 4
	rise = 8

/datum/hv_finisher_stage/hold/black_knight_raise/enter_message()
	return "[host.user] turns the blade point-down."

/datum/hv_finisher_stage/kill/bisect/black_knight
	effect_delay = 0.4 SECONDS
	lunge = 8
	rise = -2
	effect_sound = 'sound/items/weapons/bladeslice.ogg'

/datum/hv_finisher_stage/kill/bisect/black_knight/effect_message()
	return "[host.user] brings the claymore down and cleaves [host.victim] apart at the hips!"

/datum/hv_finisher_stage/kill/bisect/black_knight/effect_self_message()
	return "The claymore comes down across your hips!"

/datum/hv_finisher_stage/kill/bisect/black_knight/fallback_message()
	return "[host.user] drives the claymore down into [host.victim]!"

// ===== The alien empress of a derelict nest =====

/mob/living/basic/alien/queen/large/derelict/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/alien_empress)

/datum/hv_finisher/alien_empress
	name = "empress bite"
	telegraph_state = "bite"
	stages = list(
		/datum/hv_finisher_stage/windup/alien_empress,
		/datum/hv_finisher_stage/hold/alien_empress,
		/datum/hv_finisher_stage/hold/alien_empress_jaws,
		/datum/hv_finisher_stage/kill/decapitate/alien_empress,
		/datum/hv_finisher_stage/recover,
	)

/datum/hv_finisher_stage/windup/alien_empress
	rise = 8
	enter_sound = 'sound/mobs/non-humanoids/hiss/hiss5.ogg'

/datum/hv_finisher_stage/windup/alien_empress/enter_message()
	return "[host.user] rears up over [host.victim] with a long hiss."

/datum/hv_finisher_stage/hold/alien_empress
	enter_sound = 'sound/items/weapons/slash.ogg'

/datum/hv_finisher_stage/hold/alien_empress/enter_message()
	return "[host.user] pins [host.victim] down with [host.user.p_their()] claws."

/datum/hv_finisher_stage/hold/alien_empress/enter_self_message()
	return "Claws pin you to the floor!"

/datum/hv_finisher_stage/hold/alien_empress_jaws
	duration = 2 SECONDS
	lunge = 10
	// Dips her head down to the victim's
	rise = -4
	enter_sound = 'sound/mobs/non-humanoids/hiss/lowHiss1.ogg'

/datum/hv_finisher_stage/hold/alien_empress_jaws/enter_message()
	return "[host.user]'s jaws open over [host.victim]'s head."

/datum/hv_finisher_stage/hold/alien_empress_jaws/enter_self_message()
	return "[host.user]'s jaws open over your face."

/datum/hv_finisher_stage/kill/decapitate/alien_empress
	effect_delay = 0.4 SECONDS
	rise = 4
	effect_sound = 'sound/mobs/non-humanoids/alien/alien_eat.ogg'

/datum/hv_finisher_stage/kill/decapitate/alien_empress/effect_message()
	return "[host.user] bites through [host.victim]'s neck and tears [host.victim.p_their()] head off!"

/datum/hv_finisher_stage/kill/decapitate/alien_empress/fallback_message()
	return "[host.user] bites deep into [host.victim]!"

// ===== The Robust One =====

/mob/living/basic/trooper/pirate/faction/boss/grey/Initialize(mapload)
	. = ..()
	AddComponent(/datum/component/hv_finisher_user, /datum/hv_finisher/robust_one)

/datum/hv_finisher/robust_one
	name = "toolbox curb stomp"
	telegraph_state = "skull"
	stages = list(
		/datum/hv_finisher_stage/windup/robust_one,
		/datum/hv_finisher_stage/hold/robust_one,
		/datum/hv_finisher_stage/maul/robust_one,
		/datum/hv_finisher_stage/maul/robust_one/again,
		/datum/hv_finisher_stage/kill/burst_head/robust_one,
		/datum/hv_finisher_stage/recover,
	)

/datum/hv_finisher_stage/windup/robust_one
	rise = 4

/datum/hv_finisher_stage/windup/robust_one/enter_message()
	return "[host.user] raises [host.user.p_their()] toolbox over [host.victim]."

/datum/hv_finisher_stage/hold/robust_one
	duration = 1 SECONDS
	enter_sound = 'sound/effects/hit_kick.ogg'

/datum/hv_finisher_stage/hold/robust_one/enter_message()
	return "[host.user] kneels on [host.victim]'s chest."

/datum/hv_finisher_stage/hold/robust_one/enter_self_message()
	return "A knee crushes the air out of you!"

/datum/hv_finisher_stage/maul/robust_one
	duration = 1.5 SECONDS
	effect_delay = 0.3 SECONDS
	effect_sound = 'sound/items/weapons/smash.ogg'

/datum/hv_finisher_stage/maul/robust_one/effect_message()
	return "[host.user] brings the toolbox down on [host.victim]'s head!"

/datum/hv_finisher_stage/maul/robust_one/effect_self_message()
	return "[host.user] brings the toolbox down on your head!"

/datum/hv_finisher_stage/maul/robust_one/again
	effect_sound = 'sound/effects/wounds/crack1.ogg'

/datum/hv_finisher_stage/maul/robust_one/again/effect_message()
	return "[host.user] brings it down again!"

/datum/hv_finisher_stage/maul/robust_one/again/effect_self_message()
	return null

/datum/hv_finisher_stage/kill/burst_head/robust_one
	effect_delay = 0.3 SECONDS
	effect_sound = 'sound/items/weapons/smash.ogg'

/datum/hv_finisher_stage/kill/burst_head/robust_one/effect_message()
	return "[host.user] brings the toolbox down one last time."

/datum/hv_finisher_stage/kill/burst_head/robust_one/fallback_message()
	return "[host.user] caves in [host.victim]'s skull!"
