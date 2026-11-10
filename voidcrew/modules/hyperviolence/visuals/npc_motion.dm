// Hyperviolence visuals: people who are losing. These read the same on players and human NPCs: an
// NPC that surrenders, pleads or injects itself does so through the same tg actions.
// 19. Surrender (tg's *surrender emote): down on the floor with hands on head, trembling until they
//     get up.
// 20. In soft crit, anything a body says
//     comes with a pleading lean up toward whoever last hurt it. Injecting yourself with a medipen
//     or hypospray while badly hurt is shaky.

/// How long the surrender tremble runs: tg's surrender paralyses for 20 seconds.
#define HV_VIS_SURRENDER_TIME (20 SECONDS)

/mob/living/proc/hv_vis_surrender()
	if(stat == DEAD)
		return
	hv_vis_tremble(HV_VIS_SURRENDER_TIME, 1)
	hv_vis_hold(list(HV_VIS_TAG_TREMBLE), HV_VIS_END_STAND|HV_VIS_END_DEATH|HV_VIS_END_MOVE, HV_VIS_SURRENDER_TIME + 1 SECONDS)

/mob/living/proc/hv_vis_on_stat_change(new_stat, old_stat)
	return

/mob/living/carbon/hv_vis_on_stat_change(new_stat, old_stat)
	if(new_stat == SOFT_CRIT && old_stat != SOFT_CRIT)
		AddComponent(/datum/component/hv_downed)

/**
 * A body in soft crit: whatever it says comes with a lean up toward whoever last hurt it. Goes when the body leaves soft crit.
 */
/datum/component/hv_downed
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/hv_downed/Initialize()
	if(!iscarbon(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/hv_downed/RegisterWithParent()
	RegisterSignal(parent, COMSIG_MOB_SAY, PROC_REF(on_say))
	RegisterSignal(parent, COMSIG_MOB_STATCHANGE, PROC_REF(on_stat_change))

/datum/component/hv_downed/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_MOB_SAY, COMSIG_MOB_STATCHANGE))

/datum/component/hv_downed/proc/on_stat_change(mob/living/source, new_stat, old_stat)
	SIGNAL_HANDLER
	if(new_stat != SOFT_CRIT)
		source.hv_vis_stop(list(HV_VIS_TAG_LEAN))
		qdel(src)

/datum/component/hv_downed/proc/on_say(mob/living/carbon/source, list/speech_args)
	SIGNAL_HANDLER
	if(source.stat != SOFT_CRIT || !isturf(source.loc))
		return
	source.hv_vis_plead(source.hv_vis_hit_by?.resolve())

/// Leans up toward `toward` (or the way it faces) for a moment: a body on the floor begging.
/mob/living/proc/hv_vis_plead(atom/toward)
	var/plead_dir = dir
	if(toward && get_dist(src, toward) <= 7 && toward.z == z)
		plead_dir = get_dir(src, toward) || dir
	var/dx = HV_VIS_DX(plead_dir)
	var/dy = HV_VIS_DY(plead_dir)
	var/matrix/base = matrix(transform)
	hv_vis_play(HV_VIS_TAG_LEAN, list(
		list(pixel_w + dx * 3, pixel_z + dy * 3 + 2, base, 4, SINE_EASING),
		list(pixel_w + dx * 3, pixel_z + dy * 3 + 2, base, 8, LINEAR_EASING),
		list(pixel_w, pixel_z, base, 5, SINE_EASING),
	))

// ---- Shaky self-injection ----

/obj/item/reagent_containers/hypospray/inject(mob/living/affected_mob, mob/user)
	. = ..()
	if(!. || user != affected_mob || !isliving(user))
		return
	var/mob/living/patient = user
	if(patient.stat >= SOFT_CRIT || patient.health < patient.maxHealth * 0.5)
		patient.hv_vis_shaky_inject()

/// Hands shaking as they jab themselves, then a sag of relief.
/mob/living/proc/hv_vis_shaky_inject()
	if(!isturf(loc))
		return
	var/matrix/base = matrix(transform)
	var/list/steps = list()
	for(var/i in 1 to 6)
		var/side = i % 2 ? 1 : -1
		steps += list(list(pixel_w + side, pixel_z, hv_vis_turned(base, side * 2, hv_vis_pivot()), 0.6, LINEAR_EASING))
	steps += list(list(pixel_w, pixel_z - 1, hv_vis_local(base, 1, 0.97), 4, SINE_EASING))
	steps += list(list(pixel_w, pixel_z, base, 5, SINE_EASING))
	hv_vis_play(HV_VIS_TAG_SHAKE, steps)

#undef HV_VIS_SURRENDER_TIME
