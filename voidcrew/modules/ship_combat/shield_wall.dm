// Ship Shield Wall Structure
// Physical forcefield barrier created by shield generator
// Blocks EVERYTHING - missiles, meteors, and people

/obj/structure/ship_shield_wall
	name = "ship shield"
	desc = "A shimmering energy barrier protecting the ship."
	icon = 'icons/effects/effects.dmi'
	icon_state = "shieldwall"  // 8-dir, 3-frame animated
	density = TRUE
	anchored = TRUE
	opacity = FALSE
	layer = ABOVE_MOB_LAYER
	resistance_flags = INDESTRUCTIBLE
	// INDESTRUCTIBLE only stops damage - strong fauna (move_force >= 2x move_resist) can
	// still force-push anchored structures via PushAM, and the attempted Move() re-points
	// dir even when blocked. dir IS this wall's connector shape, so any shove visibly
	// rotates the shield (or displaces the segment outright if the far turf is clear).
	move_resist = INFINITY
	light_range = 2
	light_power = 0.5
	light_color = LIGHT_COLOR_BLUE

	/// Reference to the shield generator controlling this wall
	var/datum/weakref/generator_ref

/obj/structure/ship_shield_wall/Initialize(mapload)
	. = ..()
	// Gib any living mobs caught in the shield when it activates
	for(var/mob/living/victim in loc)
		victim.gib()

/obj/structure/ship_shield_wall/Destroy()
	generator_ref = null
	return ..()

/// Called when something bumps into the shield wall
/obj/structure/ship_shield_wall/Bumped(atom/movable/AM)
	. = ..()
	var/obj/machinery/ship_combat/shield_generator/gen = generator_ref?.resolve()
	if(!gen)
		qdel(src)  // Orphaned wall with no generator - clean up
		return

	var/obj/structure/overmap/ship/ship = gen.linked_ship_ref?.resolve()
	if(!ship)
		return

	var/damage = 0
	var/shield_mult = 1  // Shield damage multiplier based on damage source
	var/turf/impact_loc = get_turf(src)

	// Determine damage based on what hit us and destroy the projectile
	if(istype(AM, /obj/effect/ship_missile))
		var/obj/effect/ship_missile/missile = AM
		damage = missile.damage
		shield_mult = SHIELD_DAMAGE_MULT_MISSILE  // Missiles do reduced shield damage
		// Let the missile explode against the shield (visual/audio feedback)
		// shield_impact() creates explosion effects but with reduced damage since shield absorbed it
		// Player assault pods ride the same effect type, so this is also what kills a
		// boarding party that launched before the shields were down - see assault_pod.dm.
		missile.shield_impact()
	// Note: NPC boarding pods use the supplypod drop-from-above system and don't
	// physically travel through space, so they can't hit shields. The AI checks if
	// shields are down before launching them.
	else if(istype(AM, /obj/effect/meteor))
		var/obj/effect/meteor/meteor = AM
		damage = get_meteor_damage(meteor)
		shield_mult = SHIELD_DAMAGE_MULT_METEOR  // Meteors do normal shield damage
		// Destroy the meteor - it was absorbed by shields
		qdel(meteor)

	if(damage > 0)
		// Apply shield damage multiplier and route to ship's shared shield pool
		damage *= shield_mult
		ship.absorb_shield_damage(damage, impact_loc)

/// Returns the shield damage for a meteor based on its type
/obj/structure/ship_shield_wall/proc/get_meteor_damage(obj/effect/meteor/M)
	if(istype(M, /obj/effect/meteor/big))
		return METEOR_SHIELD_DAMAGE_BIG
	if(istype(M, /obj/effect/meteor/medium))
		return METEOR_SHIELD_DAMAGE_MEDIUM
	return METEOR_SHIELD_DAMAGE_SMALL

// NO CanAllowThrough() - blocks EVERYTHING including people
// Players must turn shields off to enter/exit ship

/// Handles laser damage to the shield (called by laser beam effects)
/// Returns TRUE if shields absorbed the damage
/obj/structure/ship_shield_wall/proc/absorb_laser_damage(damage, turf/impact_loc)
	var/obj/machinery/ship_combat/shield_generator/gen = generator_ref?.resolve()
	if(!gen)
		return FALSE

	var/obj/structure/overmap/ship/ship = gen.linked_ship_ref?.resolve()
	if(!ship)
		return FALSE

	if(!impact_loc)
		impact_loc = get_turf(src)

	// Apply laser shield damage multiplier (lasers are effective against shields)
	damage *= SHIELD_DAMAGE_MULT_LASER

	// Route damage to ship's shared shield pool
	return ship.absorb_shield_damage(damage, impact_loc)
