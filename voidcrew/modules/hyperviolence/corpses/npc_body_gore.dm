// Hyperviolence: gore on human-looking NPCs that keep their own body.
//
// Bounty criminals and their companions, ambient townsfolk, outpost prisoners, mission survivors and
// the like are basic mobs that stay where they fall. Other systems need that body as it is: a dead
// criminal's body is the bounty proof, a prisoner's body feeds the prison's mood and riots, ambient
// bodies are faded by their own clean-up. So they are not swapped for a human corpse; their own body
// shows the fight instead, all of it drawing and decals:
// - the player's deathgasp, and a shudder as they die;
// - a skull wound drawn on the head when the head took a beating (the same art and levels as on a
//   person, gore_overlays.dm);
// - a head burst by a heavy crushing or piercing killing blow or an execution, as the corpse handoff
//   rolls it (npc_corpse_gore.dm): the head is cut out of their sprite, a neck stump drawn in, gibs
//   and blood thrown. No organs come out; nothing about the body changes but how it looks;
// - a pool of blood under a body that took a real beating.
// Coming back to life (a Lazarus injector, strange reagent) clears it all.

/// Icons for NPC body gore: the mask that cuts the head out of a sprite.
#define HV_BODY_GORE_ICON 'voidcrew/modules/hyperviolence/corpses/icons/npc_body_gore.dmi'
/// Filter name of the mask that cuts the head out of a sprite.
#define HV_BODY_HEADLESS_FILTER "hv_headless"

/mob/living
	/// Hyperviolence: a human-looking NPC whose own body stays and shows the gore (npc_body_gore.dm).
	var/hv_gory_own_body = FALSE
	/// Hyperviolence: the skull wound drawn on that body, 0 (none) to 3.
	var/hv_body_skull = 0
	/// Hyperviolence: that body's head has been blown off.
	var/hv_body_headless = FALSE

/// Whether this mob is drawn as a person (a dressed human look copied onto it).
/mob/living/proc/hv_looks_human()
	return icon == 'icons/mob/human/human.dmi'

/mob/living/basic/Initialize(mapload)
	. = ..()
	if(!(basic_mob_flags & DEL_ON_DEATH) && hv_is_fleshy_humanoid_npc())
		AddElement(/datum/element/hv_npc_wounds)
		AddElement(/datum/element/hv_npc_body_gore)

// The deathgasp goes out from tg's death() itself, before the body is marked dead.
/mob/living/basic/death(gibbed)
	if(!gibbed && stat != DEAD && hv_gory_own_body && !death_message && !death_sound && hv_looks_human())
		var/datum/emote/living/deathgasp/gasp = /datum/emote/living/deathgasp
		death_message = initial(gasp.message)
	return ..()

/// Draws the fight on the body of a human-looking NPC that keeps it.
/datum/element/hv_npc_body_gore

/datum/element/hv_npc_body_gore/Attach(datum/target)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE
	var/mob/living/npc = target
	npc.hv_gory_own_body = TRUE
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(target, COMSIG_LIVING_REVIVE, PROC_REF(on_revive))
	RegisterSignal(target, COMSIG_ATOM_UPDATE_OVERLAYS, PROC_REF(on_update_overlays))

/datum/element/hv_npc_body_gore/Detach(mob/living/source)
	UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_ATOM_UPDATE_OVERLAYS))
	source.hv_gory_own_body = FALSE
	if(!QDELETED(source))
		source.hv_clear_body_gore()
	return ..()

/datum/element/hv_npc_body_gore/proc/on_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(!gibbed)
		source.hv_own_body_death()

/datum/element/hv_npc_body_gore/proc/on_revive(mob/living/source, full_heal_flags)
	SIGNAL_HANDLER
	source.hv_clear_body_gore()

/datum/element/hv_npc_body_gore/proc/on_update_overlays(mob/living/source, list/overlays)
	SIGNAL_HANDLER
	if(source.hv_body_headless || source.hv_body_skull)
		overlays += source.hv_body_gore_images()

/// The NPC just died: settle the head and the blood from the tally (npc_wounds.dm), then shudder.
/mob/living/proc/hv_own_body_death()
	if(!hv_looks_human())
		return
	var/datum/hv_npc_wounds/wounds = hv_npc_wounds
	if(wounds)
		// The head as a person's would be: their share of the tally out of a person's health.
		var/scale = 100 / max(maxHealth, 1)
		var/head_damage = (wounds.brute_by_zone[BODY_ZONE_HEAD] || 0) * scale
		if(wounds.was_executed())
			if(wounds.execution_blow >= HV_EXECUTION_BURST_DAMAGE)
				hv_burst_body_head(wounds.execution_dir, !wounds.execution_said)
			else
				if(!wounds.execution_said)
					hv_add_hit_line("The shot blows out the back of [src]'s skull.", HV_LINE_HUGE, null, DEFAULT_MESSAGE_RANGE)
				hv_body_skull = 3
		else if(hv_body_blow_bursts_head(wounds, head_damage))
			hv_burst_body_head(wounds.last_dir)
		if(!hv_body_headless && !hv_body_skull && wounds.max_head_hit * scale >= HV_SKULL_OPEN_HIT)
			hv_body_skull = hv_skull_level_for(head_damage)
		var/beaten = counterlist_sum(wounds.brute_by_zone) / max(maxHealth, 1)
		if(beaten >= HV_CORPSE_BLOOD_HANDS_SHARE && can_bleed())
			add_splatter_floor(get_turf(src))
	hv_death_throes()
	update_appearance(UPDATE_OVERLAYS)

/// Whether the killing blow bursts the head, by the same rule a corpse gets (npc_corpse_gore.dm):
/// a huge crushing or piercing blow always does; a heavy one gets tg's dismember odds on a head
/// already half gone.
/mob/living/proc/hv_body_blow_bursts_head(datum/hv_npc_wounds/wounds, head_damage)
	if(!wounds.has_killing_blow() || wounds.last_zone != BODY_ZONE_HEAD || wounds.last_type != BRUTE)
		return FALSE
	if(wounds.last_wound_bonus == CANT_WOUND || hv_crit_wounding_type(wounds.last_sharpness) == WOUND_SLASH)
		return FALSE
	var/blow = wounds.last_damage
	if(blow >= HV_CORPSE_HEAD_BURST_DAMAGE)
		return TRUE
	if(blow < HV_CORPSE_HEAVY_SEVER_DAMAGE || head_damage < LIMB_MAX_HP_CORE * HV_HEAD_BURST_MIN_HEAD_DAMAGE)
		return FALSE
	return prob(blow + head_damage / LIMB_MAX_HP_CORE * 50)

/// The skull wound level (0 to 3) a person's head with this much brute damage shows.
/proc/hv_skull_level_for(head_brute)
	if(head_brute >= HV_SKULL_HEAVY_BRUTE)
		return 3
	if(head_brute >= HV_SKULL_MEDIUM_BRUTE)
		return 2
	if(head_brute >= HV_SKULL_LIGHT_BRUTE)
		return 1
	return 0

/// Whether this body still has a head that could burst.
/mob/living/proc/hv_body_head_can_burst()
	return hv_gory_own_body && !hv_body_headless && hv_looks_human()

/**
 * Blows this body's head off: gibs and blood along `burst_dir`, the head cut out of the sprite and a
 * neck stump drawn in. `announce` adds the line. Returns TRUE if the head burst.
 */
/mob/living/proc/hv_burst_body_head(burst_dir, announce = TRUE)
	if(!hv_body_head_can_burst())
		return FALSE
	if(!burst_dir)
		burst_dir = pick(GLOB.alldirs)
	hv_body_headless = TRUE
	hv_body_skull = 0
	add_filter(HV_BODY_HEADLESS_FILTER, 1, alpha_mask_filter(icon = icon(HV_BODY_GORE_ICON, "headless_mask")))
	var/turf/here = get_turf(src)
	if(can_bleed())
		hv_blood_spray(burst_dir, 4)
		if(isturf(here))
			hv_spawn_head_gibs(here, burst_dir, get_blood_dna_list())
			hv_head_burst_splatter(here, burst_dir, get_bloodtype()?.get_color())
	if(isturf(here))
		playsound(here, 'sound/effects/wounds/splatter.ogg', 80, TRUE)
	if(announce)
		hv_add_hit_line(pick("[src]'s head bursts apart!", "[src]'s skull bursts open!"), HV_LINE_HUGE, range = DEFAULT_MESSAGE_RANGE)
	update_appearance(UPDATE_OVERLAYS)
	return TRUE

/// The neck stump or skull wound drawn on this body, tinted to its blood.
/mob/living/proc/hv_body_gore_images()
	var/blood_color = can_bleed() ? (get_bloodtype()?.get_color() || BLOOD_COLOR_RED) : null
	if(hv_body_headless)
		return hv_gore_image_pair("stump_head", HV_STUMP_FRESH_LAYER, blood_color)
	if(hv_body_skull)
		return hv_gore_image_pair(hv_skull_wound_state(hv_body_skull), HV_SKULL_WOUND_LAYER, blood_color)
	return list()

/// Back to an unhurt look, for a body brought back to life.
/mob/living/proc/hv_clear_body_gore()
	if(!hv_body_headless && !hv_body_skull)
		return
	hv_body_headless = FALSE
	hv_body_skull = 0
	remove_filter(HV_BODY_HEADLESS_FILTER)
	update_appearance(UPDATE_OVERLAYS)

#undef HV_BODY_GORE_ICON
#undef HV_BODY_HEADLESS_FILTER
