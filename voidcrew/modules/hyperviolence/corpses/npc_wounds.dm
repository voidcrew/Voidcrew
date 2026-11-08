// Hyperviolence: the fight an NPC carries onto its corpse.
//
// Pirates, troopers and the other human-looking NPCs are basic mobs. Most are deleted when they die
// and leave a fresh human corpse in their place, so the blood and damage of the fight used to vanish
// with them. This file keeps a cheap tally on the living NPC: one damage signal, no ticking, nothing
// stored until the first hit. It holds the damage by body zone and the last blow. When the corpse is
// made (npc_corpse_handoff.dm), npc_corpse_gore.dm puts all of it onto the corpse.

/// What a human-looking NPC went through, kept for the human corpse it will leave. Made on the first hit.
/datum/hv_npc_wounds
	/// Body zone -> brute damage taken there
	var/list/brute_by_zone = list()
	/// Body zone -> burn damage taken there
	var/list/burn_by_zone = list()
	/// The heaviest single brute hit to the head, for whether the skull was opened
	var/max_head_hit = 0
	// The last hit. It is the killing blow if it landed in the tick the NPC died.
	/// Body zone it landed on
	var/last_zone
	/// Damage it dealt, after armour and the NPC's own damage modifiers
	var/last_damage = 0
	/// BRUTE or BURN
	var/last_type
	/// Its sharpness flags
	var/last_sharpness = NONE
	/// Its wound bonus (CANT_WOUND for hits that can't wound)
	var/last_wound_bonus = 0
	/// Its wound bonus against bare skin
	var/last_exposed_bonus = 0
	/// The way it travelled, from the attacker toward the NPC
	var/last_dir
	/// world.time it landed
	var/last_time = -1
	/// Force of the execution shot, after armour and the point-blank bonus (executions.dm)
	var/execution_blow = 0
	/// The way the execution shot travelled
	var/execution_dir
	/// world.time of the execution shot, -1 if it was never executed
	var/execution_time = -1
	/// Whether the NPC's own hit line already said how the execution ended
	var/execution_said = FALSE

/// Total damage of both kinds in the tally.
/datum/hv_npc_wounds/proc/total()
	return counterlist_sum(brute_by_zone) + counterlist_sum(burn_by_zone)

/// Whether the last hit landed this tick, and so is what killed it.
/datum/hv_npc_wounds/proc/has_killing_blow()
	return last_time == world.time && last_damage > 0 && (last_type == BRUTE || last_type == BURN)

/// Whether it died to an execution: the shot was noted just now (a burst of rounds lands over a few ticks).
/datum/hv_npc_wounds/proc/was_executed()
	return execution_time >= 0 && world.time - execution_time <= 1 SECONDS

/mob/living
	/// Hyperviolence: the tally for the human corpse this NPC leaves (corpses/). Null until it is first hurt.
	var/datum/hv_npc_wounds/hv_npc_wounds
	/// Hyperviolence: set on human-looking NPCs whose death leaves a human corpse for the fight to be carried onto.
	var/hv_leaves_human_corpse = FALSE

/// Whether this mob is a human-looking NPC of flesh and blood, the kind whose corpse can carry the fight.
/mob/living/proc/hv_is_fleshy_humanoid_npc()
	return FALSE

/mob/living/basic/hv_is_fleshy_humanoid_npc()
	if(!(mob_biotypes & MOB_HUMANOID) || !(mob_biotypes & MOB_ORGANIC))
		return FALSE
	return !(mob_biotypes & (MOB_ROBOTIC|MOB_UNDEAD|MOB_SPIRIT|MOB_MINERAL|MOB_PLANT|MOB_SLIME))

/// How much of a hit of this damage type this mob really takes: basic mobs scale it by their damage coefficients.
/mob/living/proc/hv_damage_share(damagetype)
	return 1

/mob/living/basic/hv_damage_share(damagetype)
	return damage_coeff?[damagetype] || 0

/// The body zone a hit with this def_zone (a zone, a bodypart or nothing) counts against.
/proc/hv_tally_zone(def_zone)
	if(isbodypart(def_zone))
		var/obj/item/bodypart/part = def_zone
		return part.body_zone
	if(istext(def_zone))
		return check_zone(def_zone)
	return BODY_ZONE_CHEST

/// Keeps the tally of every hit on a human-looking NPC: one that leaves a human corpse
/// (npc_corpse_handoff.dm), or one whose own body shows the gore (npc_body_gore.dm).
/datum/element/hv_npc_wounds

/datum/element/hv_npc_wounds/Attach(datum/target)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOB_APPLY_DAMAGE, PROC_REF(on_damage))

/datum/element/hv_npc_wounds/Detach(mob/living/source)
	UnregisterSignal(source, COMSIG_MOB_APPLY_DAMAGE)
	return ..()

// Sent before the damage goes in, so a hit that kills is noted before the corpse is made.
/datum/element/hv_npc_wounds/proc/on_damage(mob/living/source, damage, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(source.stat == DEAD || (damagetype != BRUTE && damagetype != BURN) || HAS_TRAIT(source, TRAIT_GODMODE))
		return
	source.hv_note_npc_hit(damage * source.hv_damage_share(damagetype), damagetype, def_zone, wound_bonus, exposed_wound_bonus, sharpness, attack_direction)

/// Adds one hit to this NPC's tally.
/mob/living/proc/hv_note_npc_hit(damage, damagetype, def_zone, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction)
	if(damage <= 0)
		return
	if(!hv_npc_wounds)
		hv_npc_wounds = new
	var/datum/hv_npc_wounds/wounds = hv_npc_wounds
	var/zone = hv_tally_zone(def_zone)
	if(damagetype == BRUTE)
		wounds.brute_by_zone[zone] += damage
		if(zone == BODY_ZONE_HEAD)
			wounds.max_head_hit = max(wounds.max_head_hit, damage)
	else
		wounds.burn_by_zone[zone] += damage
	wounds.last_zone = zone
	wounds.last_damage = damage
	wounds.last_type = damagetype
	wounds.last_sharpness = sharpness
	wounds.last_wound_bonus = wound_bonus
	wounds.last_exposed_bonus = exposed_wound_bonus
	wounds.last_dir = attack_direction
	wounds.last_time = world.time

/// Notes that this NPC is being executed, for the corpse it leaves. `said` when its hit line tells how it ended.
/mob/living/proc/hv_note_npc_execution(blow, shot_dir, said = FALSE)
	if(!hv_npc_wounds)
		hv_npc_wounds = new
	hv_npc_wounds.execution_blow = blow
	hv_npc_wounds.execution_dir = shot_dir
	hv_npc_wounds.execution_time = world.time
	hv_npc_wounds.execution_said = said
