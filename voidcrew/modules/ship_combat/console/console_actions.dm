// ========== ACTION BUTTONS ==========

/datum/action/innate/ship_combat
	button_icon = 'icons/mob/actions/actions_mecha.dmi'
	check_flags = NONE
	var/obj/machinery/computer/camera_advanced/ship_combat/console

/datum/action/innate/ship_combat/New(Target)
	. = ..()
	console = Target

/datum/action/innate/ship_combat/IsAvailable(feedback = FALSE)
	if(!console || QDELETED(console))
		return FALSE
	if(!console.attack_mode)
		return FALSE
	return ..()

// Select missile type
/datum/action/innate/ship_combat/select_missile
	name = "Select Missile"
	desc = "Select which type of missile to fire from loaded launchers."
	button_icon_state = "mech_cycle_equip_off"

/datum/action/innate/ship_combat/select_missile/Activate()
	if(!console || !ismob(owner))
		return
	console.open_missile_radial(owner)

// Select approach direction for missiles and lasers
/datum/action/innate/ship_combat/select_direction
	name = "Select Direction"
	desc = "Select which direction missiles and lasers will approach from."
	button_icon_state = "change_direction"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/select_direction/Activate()
	if(!console || !ismob(owner))
		return
	console.open_direction_radial(owner)

// Fire single missile
/datum/action/innate/ship_combat/fire_missile
	name = "Fire Missile"
	desc = "Fire one missile at the targeted location."
	button_icon_state = "missile"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_missile/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_one(owner)

// Fire all missiles
/datum/action/innate/ship_combat/fire_all
	name = "Fire All Missiles"
	desc = "Fire all ready missiles at the targeted location."
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'
	button_icon_state = "missiles"

/datum/action/innate/ship_combat/fire_all/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_all(owner)

// Fire single laser
/datum/action/innate/ship_combat/fire_laser
	name = "Fire Laser"
	desc = "Fire one laser turret at the targeted location."
	button_icon_state = "laser"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_laser/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_laser_one(owner)

// Fire all lasers
/datum/action/innate/ship_combat/fire_all_lasers
	name = "Fire All Lasers"
	desc = "Fire all ready laser turrets at the targeted location."
	button_icon_state = "lasers"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/fire_all_lasers/Activate()
	if(!console || !ismob(owner))
		return
	console.fire_all_lasers(owner)

// Adjust laser power
/datum/action/innate/ship_combat/adjust_laser_power
	name = "Laser Power"
	desc = "Adjust power level for all laser turrets. Higher power = more damage but more power usage."
	button_icon_state = "power"
	button_icon = 'voidcrew/icons/mob/actions/ship_combat.dmi'

/datum/action/innate/ship_combat/adjust_laser_power/Activate()
	if(!console || !ismob(owner))
		return
	console.open_laser_power_radial(owner)

// Launch a crewed assault pod at the aimed tile
/datum/action/innate/ship_combat/launch_pod
	name = "Launch Assault Pod"
	desc = "Throw a loaded assault pod at the targeted location. It cuts its own way in - unless the target's shields are up."
	button_icon_state = "mech_eject"
	button_icon = 'icons/mob/actions/actions_mecha.dmi'

/datum/action/innate/ship_combat/launch_pod/Activate()
	if(!console || !ismob(owner))
		return
	console.launch_pod(owner)

// Exit camera mode - doesn't inherit attack_mode check from parent
/datum/action/innate/ship_combat/exit_camera
	name = "Exit Camera"
	desc = "Exit the targeting camera and return to normal view."
	button_icon_state = "camera_off"
	button_icon = 'icons/mob/actions/actions_silicon.dmi'

/datum/action/innate/ship_combat/exit_camera/IsAvailable(feedback = FALSE)
	// Override parent's check - exit should always be available when granted
	if(!console || QDELETED(console))
		return FALSE
	return TRUE

/datum/action/innate/ship_combat/exit_camera/Activate()
	if(!console || !ismob(owner))
		return
	console.exit_attack_mode(owner)
