// Ship Combat Shield Satellite
// Physical shield structures that intercept incoming missiles
// Based on the meteor shield satellite pattern
// First missile hit destroys the shield, second hit damages hull

/obj/machinery/satellite/ship_shield
	name = "ship shield satellite"
	desc = "A defensive shield satellite that intercepts incoming missiles. Will be destroyed after blocking one hit."
	icon = 'icons/obj/machines/satellite.dmi'
	icon_state = "intsat"
	mode = "SHIP-SHIELD"
	anchored = TRUE
	density = FALSE

	/// The range at which this shield can intercept missiles
	var/intercept_range = SHIP_SHIELD_RANGE
	/// Proximity monitor for detecting incoming missiles
	var/datum/proximity_monitor/proximity_monitor
	/// Whether the shield is currently active
	var/shield_active = TRUE
	/// Visual beam effect duration
	var/beam_duration = 5

/obj/machinery/satellite/ship_shield/Initialize(mapload)
	. = ..()
	proximity_monitor = new(src, 0)
	if(active)
		activate_shield()

/obj/machinery/satellite/ship_shield/Destroy()
	QDEL_NULL(proximity_monitor)
	return ..()

/obj/machinery/satellite/ship_shield/examine(mob/user)
	. = ..()
	if(active && shield_active)
		. += span_notice("The shield is [span_green("active")] and protecting the ship.")
		. += span_notice("Intercept range: [intercept_range] tiles")
	else
		. += span_warning("The shield is [span_red("inactive")].")

// ========== SHIELD ACTIVATION ==========

/obj/machinery/satellite/ship_shield/toggle(user)
	if(user)
		balloon_alert(user, "[active ? "deactivating" : "activating"]...")
	if(user && !do_after(user, 2 SECONDS, src, IGNORE_HELD_ITEM))
		return FALSE
	if(!..(user))
		return FALSE

	if(active)
		activate_shield()
	else
		deactivate_shield()

/obj/machinery/satellite/ship_shield/proc/activate_shield()
	shield_active = TRUE
	proximity_monitor?.set_range(intercept_range)
	update_appearance()

/obj/machinery/satellite/ship_shield/proc/deactivate_shield()
	shield_active = FALSE
	proximity_monitor?.set_range(0)
	update_appearance()

/obj/machinery/satellite/ship_shield/update_overlays()
	. = ..()
	if(active && shield_active)
		. += mutable_appearance('icons/effects/effects.dmi', "shield-flash")

// ========== MISSILE INTERCEPTION ==========

/obj/machinery/satellite/ship_shield/HasProximity(atom/movable/proximity_check_mob)
	. = ..()
	if(!active || !shield_active)
		return
	if(!istype(proximity_check_mob, /obj/effect/ship_missile))
		return

	var/obj/effect/ship_missile/missile = proximity_check_mob

	// Check line of sight
	if(!space_los(missile))
		return

	// Intercept the missile!
	intercept_missile(missile)

/// Checks if we have line of sight to the missile through space
/obj/machinery/satellite/ship_shield/proc/space_los(atom/target)
	for(var/turf/T in get_line(src, target))
		if(!isspaceturf(T) && !istype(T, /turf/open))
			// Allow some turfs that aren't strict space
			if(T.density)
				return FALSE
	return TRUE

/// Intercepts and destroys an incoming missile, then destroys self
/obj/machinery/satellite/ship_shield/proc/intercept_missile(obj/effect/ship_missile/missile)
	// Visual beam effect
	var/turf/beam_from = get_turf(src)
	var/turf/beam_to = get_turf(missile)
	beam_from.Beam(beam_to, icon_state = "sat_beam", time = beam_duration)

	// Play intercept sound
	playsound(src, 'sound/items/weapons/laser.ogg', 60, TRUE)

	// Announce interception
	visible_message(span_danger("[src] intercepts [missile]!"))

	// Send signal that shield was hit
	var/obj/structure/overmap/ship/target_ship = missile.target_ship
	if(target_ship)
		SEND_SIGNAL(target_ship, COMSIG_SHIP_SHIELD_HIT, missile)

	// Small visual explosion where missile was destroyed
	var/datum/effect_system/spark_spread/sparks = new
	sparks.set_up(5, TRUE, beam_to)
	sparks.start()

	// Destroy the missile
	missile.exploded = TRUE // Prevent normal explosion
	qdel(missile)

	// Shield is destroyed after blocking one hit
	visible_message(span_danger("[src] overloads and is destroyed!"))
	playsound(src, 'sound/effects/explosion/explosion1.ogg', 50, TRUE)

	// Visual destruction effect
	var/datum/effect_system/spark_spread/shield_sparks = new
	shield_sparks.set_up(8, TRUE, get_turf(src))
	shield_sparks.start()

	qdel(src)

// ========== CIRCUIT BOARD ==========

/obj/item/circuitboard/machine/ship_combat/ship_shield
	name = "Ship Shield Satellite"
	greyscale_colors = CIRCUIT_COLOR_ENGINEERING
	build_path = /obj/machinery/satellite/ship_shield
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 1,
	)
