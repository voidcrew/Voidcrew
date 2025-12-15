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
	light_range = 2
	light_power = 0.5
	light_color = LIGHT_COLOR_BLUE

	/// Reference to the shield generator controlling this wall
	var/datum/weakref/generator_ref

/obj/structure/ship_shield_wall/Destroy()
	generator_ref = null
	return ..()

/// Called when something bumps into the shield wall
/obj/structure/ship_shield_wall/Bumped(atom/movable/AM)
	. = ..()
	var/obj/machinery/ship_combat/shield_generator/gen = generator_ref?.resolve()
	if(!gen)
		return

	var/damage = 0
	var/turf/impact_loc = get_turf(src)

	// Determine damage based on what hit us and destroy the projectile
	if(istype(AM, /obj/effect/ship_missile))
		var/obj/effect/ship_missile/missile = AM
		damage = missile.damage
		// Mark as exploded so it doesn't detonate, then delete
		missile.exploded = TRUE
		qdel(missile)
	else if(istype(AM, /obj/effect/meteor))
		var/obj/effect/meteor/meteor = AM
		damage = get_meteor_damage(meteor)
		// Destroy the meteor - it was absorbed by shields
		qdel(meteor)

	if(damage > 0)
		// Distribute damage across all active generators on the ship
		var/obj/structure/overmap/ship/ship = gen.linked_ship_ref?.resolve()
		if(ship && length(ship.linked_shield_generators))
			distribute_damage_to_generators(ship, damage, impact_loc)
		else
			gen.absorb_damage(damage, impact_loc)

/// Distributes damage evenly across all active shield generators
/obj/structure/ship_shield_wall/proc/distribute_damage_to_generators(obj/structure/overmap/ship/ship, damage, turf/impact_loc)
	// Get list of active generators
	var/list/active_generators = list()
	for(var/obj/machinery/ship_combat/shield_generator/gen in ship.linked_shield_generators)
		if(gen.is_shield_active())
			active_generators += gen

	if(!length(active_generators))
		return

	// Split damage evenly across active generators
	var/damage_per_gen = damage / length(active_generators)
	for(var/obj/machinery/ship_combat/shield_generator/gen in active_generators)
		gen.absorb_damage(damage_per_gen, impact_loc)

/// Returns the shield damage for a meteor based on its type
/obj/structure/ship_shield_wall/proc/get_meteor_damage(obj/effect/meteor/M)
	if(istype(M, /obj/effect/meteor/big))
		return 600
	if(istype(M, /obj/effect/meteor/medium))
		return 400
	return 200

// NO CanAllowThrough() - blocks EVERYTHING including people
// Players must turn shields off to enter/exit ship
