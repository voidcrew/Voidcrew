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
/obj/projectile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	if(npc_side_shooter && firer && firer.weak_reference != npc_side_shooter)
		npc_side_shooter = null
		ignored_factions = null
	return ..()
