// Hyperviolence: handing a dying NPC over to the human corpse it leaves.
//
// tg's death_drops element makes the corpse of every trooper and other NPC that drops one: it spawns
// the /obj/effect/mob_spawn/corpse/human, then copies the NPC's total damage onto it, spread evenly.
// For a human-looking NPC of flesh and blood we make the corpse the same way, then hand the fight
// over (npc_corpse_gore.dm) in place of that even spread, give the player's deathgasp in the NPC's
// name, and let the corpse seize up on its feet before it falls. The NPC is still in the world while
// this runs: basic mobs are deleted after their death signal. (Wasteland hermits had hooks here too;
// they are human NPCs now, voidcrew/modules/human_npcs/ruins/, and die in their own bodies.)

/datum/element/death_drops/Attach(datum/target, list/loot)
	. = ..()
	if(. == ELEMENT_INCOMPATIBLE)
		return
	var/mob/living/npc = target
	if(npc.hv_leaves_human_corpse || !npc.hv_is_fleshy_humanoid_npc())
		return
	for(var/path in loot)
		if(hv_is_human_corpse_path(path))
			npc.hv_leaves_human_corpse = TRUE
			npc.AddElement(/datum/element/hv_npc_wounds)
			return

/// Whether `path` is a corpse spawner that makes a human.
/proc/hv_is_human_corpse_path(path)
	if(!ispath(path, /obj/effect/mob_spawn/corpse/human))
		return FALSE
	var/obj/effect/mob_spawn/corpse/human/spawner = path
	return ispath(initial(spawner.mob_type), /mob/living/carbon/human)

/datum/element/death_drops/handle_corpse(typepath, atom/loot_loc, mob/living/dead, gibbed)
	if(gibbed || !dead.hv_leaves_human_corpse || !hv_is_human_corpse_path(typepath))
		return ..()
	hv_make_npc_corpse(typepath, loot_loc, dead)

/**
 * Makes `dead`'s human corpse from the spawner `typepath` at `where` and hands the fight over.
 * `gasp_now` is off for an NPC that has not been marked dead yet: tg's death() gives the gasp then.
 * Returns the corpse.
 */
/proc/hv_make_npc_corpse(typepath, atom/where, mob/living/dead, gasp_now = TRUE)
	var/obj/effect/mob_spawn/corpse/human/spawner = new typepath(where, TRUE)
	var/mob/living/carbon/human/body = spawner.create()
	if(!istype(body))
		return null
	// As tg's handle_corpse() does for the kinds of damage that never show on a body.
	body.setToxLoss(dead.getToxLoss())
	body.setOxyLoss(dead.getOxyLoss())
	body.hv_take_npc_wounds(dead)
	body.hv_death_throes(rise = TRUE)
	dead.hv_npc_deathgasp(body, gasp_now)
	return body

// ---- Simple mobs ----

/mob/living/simple_animal/hv_damage_share(damagetype)
	return damage_coeff?[damagetype] || 0

// ---- Deathgasp and death throes ----

/**
 * The player's deathgasp ("seizes up and falls limp, their eyes dead and lifeless..."), given by an
 * NPC that has none of its own, once its corpse exists. It takes the corpse's sex and death sound
 * first, so the line and the body agree. An NPC with its own death message already gave it. Without
 * `emote_now` it is only made ready, for tg's death() to give.
 */
/mob/living/proc/hv_npc_deathgasp(mob/living/carbon/human/body, emote_now = TRUE)
	if(death_message || death_sound || !hv_is_fleshy_humanoid_npc())
		return
	if(body)
		gender = body.gender
		death_sound = body.death_sound
	var/datum/emote/living/deathgasp/gasp = /datum/emote/living/deathgasp
	death_message = initial(gasp.message)
	if(!emote_now)
		return
	// Forced (the last argument): it is already dead, which no emote allows. Async as tg's death() does
	// it; it runs at once, before the NPC is deleted, unless something in it sleeps.
	INVOKE_ASYNC(src, TYPE_PROC_REF(/mob, emote), "deathgasp", null, null, FALSE, FALSE, TRUE)

/**
 * A body shudders as it dies. With `rise` (a corpse that has just taken the place of a standing NPC)
 * it is first drawn upright over its lying pose, seizing, then falls the way tg lays a body down.
 */
/mob/living/proc/hv_death_throes(rise = FALSE)
	// How far it is turned now: tg lays a body down by turning it.
	var/angle = round(arctan(transform.a, transform.b))
	if(rise && angle)
		var/matrix/fallen = matrix(transform)
		var/matrix/upright = matrix(transform)
		upright.Turn(-angle)
		animate(src, transform = upright, time = 0)
		animate(transform = upright, time = HV_DEATH_THROES_TIME)
		animate(transform = fallen, time = UPDATE_TRANSFORM_ANIMATION_TIME, easing = EASE_IN|EASE_OUT)
	// The shudder: sideways offsets that die down, each step relative to the last, ending where it began.
	var/static/list/shudder = list(3, -3, 2, -2, 2, -1, 1, 0)
	var/step_time = HV_DEATH_THROES_TIME / length(shudder)
	var/offset = 0
	for(var/i in 1 to length(shudder))
		var/shift = shudder[i] - offset
		offset = shudder[i]
		if(i == 1)
			animate(src, pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL)
		else
			animate(pixel_w = shift, time = step_time, flags = ANIMATION_RELATIVE)
