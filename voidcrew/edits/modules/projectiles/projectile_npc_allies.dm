// Voidcrew extension to code/modules/projectiles/projectile.dm: NPCs shoot past their own side.

/obj/projectile
	/// Set before fire() to keep an NPC's shot hitting its own side in the way (the mafia lair's machine).
	var/npc_shot_hits_allies = FALSE
	/// The NPC whose side this shot passes over. A shot reflected or parried by someone else stops passing over them.
	var/datum/weakref/npc_side_shooter

/**
 * A shot fired by an NPC (a mob nobody is playing) passes over anyone on its side, as tg's turrets already
 * do, through tg's own ignored_factions check in can_hit_target(). The mob it was aimed at is always hit,
 * whichever side it is on. Every NPC fires through here: human NPCs' guns (casing to projectile, shotgun
 * pellets included), basic mobs' ranged_attacks and simple mobs' Shoot().
 *
 * A player's shots are unchanged. The shared "neutral" faction is left out, so an NPC never shoots
 * through bystanders just because nobody gave them a side.
 */
/obj/projectile/fire(fire_angle, atom/direct_target)
	if(isnull(ignored_factions) && !npc_shot_hits_allies && ismob(firer))
		var/mob/firer_mob = firer
		if(!firer_mob.ckey && length(firer_mob.faction))
			var/list/sides = firer_mob.faction - FACTION_NEUTRAL
			if(length(sides))
				ignored_factions = sides
				npc_side_shooter = WEAKREF(firer_mob)
	return ..()

// A reflected, parried or deflected shot takes a new firer: it stops sparing the NPC's side.
// An ally held by the other side is a shield, not an ally: the shot can hit them (see npc_shot_shield()).
/obj/projectile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	if(npc_side_shooter && firer && firer.weak_reference != npc_side_shooter)
		npc_side_shooter = null
		ignored_factions = null
	if(npc_side_shooter && npc_shot_shield(target))
		var/list/sides = ignored_factions
		ignored_factions = null
		. = ..()
		ignored_factions = sides
		return .
	return ..()

/**
 * Whether `target` is one of the NPC's side held in an aggressive grab or tighter by a living mob that is
 * not on that side. tg's grab states are the only test: a passive pull (dragging a body or a cuffed
 * prisoner) is not a shield. tg's own rules still pass over a held body that is dead or lying helpless.
 */
/obj/projectile/proc/npc_shot_shield(atom/target)
	if(!isliving(target) || !length(ignored_factions))
		return FALSE
	var/mob/living/held = target
	var/mob/living/holder = held.pulledby
	if(!isliving(holder) || holder.grab_state < GRAB_AGGRESSIVE)
		return FALSE
	return faction_check(held.faction, ignored_factions) && !faction_check(holder.faction, ignored_factions)
