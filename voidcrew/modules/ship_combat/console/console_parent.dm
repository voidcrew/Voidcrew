// ========== MAIN CONSOLE ==========

/obj/machinery/computer/camera_advanced/ship_combat
	name = "weapons system"
	desc = "A tactical weapons system for ship-to-ship combat. Link missile launchers with a multitool, select a target ship, then use the targeting system to aim and fire."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "targeting"
	icon_keyboard = "syndie_key"
	circuit = /obj/item/circuitboard/computer/ship_combat_console
	light_color = LIGHT_COLOR_INTENSE_RED
	networks = list() // We don't use the camera network
	appearance_flags = KEEP_TOGETHER

	/// Our ship reference
	var/obj/structure/overmap/ship/current_ship
	/// Currently targeted enemy ship (fully locked)
	var/obj/structure/overmap/ship/target_ship
	/// Ship we're currently acquiring a lock on
	var/obj/structure/overmap/ship/targeting_ship
	/// Are we currently acquiring a target lock?
	var/is_targeting = FALSE
	/// World time when targeting started
	var/targeting_start_time
	/// Timer ID for the targeting process
	var/targeting_timer_id
	/// List of linked missile launchers (weakrefs)
	var/list/linked_launchers = list()
	/// List of linked laser turrets (weakrefs)
	var/list/linked_turrets = list()
	/// Linked shield generator (weakref)
	var/datum/weakref/linked_shield_ref
	/// Global power level for all turrets (0.25 to 2.0)
	var/turret_power_level = 1
	/// Is cloaking device active on our ship?
	var/cloak_active = FALSE
	/// The targeting reticle shown on screen
	var/atom/movable/screen/ship_combat/targeting_reticle/reticle
	/// Are we currently in attack mode (camera view)?
	var/attack_mode = FALSE
	/// Currently selected missile type filter (null = fire any)
	var/selected_missile_type
	/// Selected approach direction for missiles and lasers (NORTH/SOUTH/EAST/WEST or null for auto)
	var/selected_approach_direction
	/// UI theme preference
	var/theme

	// ===== INTERDICTOR VARIABLES =====
	/// Linked interdictor machine (weakref)
	var/datum/weakref/linked_interdictor_ref

	// ===== CLOAKING DEVICE VARIABLES =====
	/// Linked cloaking device machine (weakref)
	var/datum/weakref/linked_cloak_ref

	// ===== SIPHON VARIABLES =====
	/// Linked ship data siphon (weakref)
	var/datum/weakref/linked_siphon_ref

	// ===== UI CACHING =====
	/// Cached shield status data (for performance)
	var/list/cached_shield_status
	/// Whether shield cache needs refresh
	var/shield_status_dirty = TRUE
	/// Last time shield status was refreshed (world.time)
	var/shield_status_last_update = 0

	/// Console ambient sounds
	var/datum/console_ambience/console_ambience

	jump_action = null
	off_action = null  // We use TGUI to exit attack mode, not the parent's camera_off action

/obj/machinery/computer/camera_advanced/ship_combat/Initialize(mapload)
	. = ..()
	// Add our custom actions
	actions += new /datum/action/innate/ship_combat/exit_camera(src)  // Exit first so it's easily accessible
	actions += new /datum/action/innate/ship_combat/select_missile(src)
	actions += new /datum/action/innate/ship_combat/select_direction(src)
	actions += new /datum/action/innate/ship_combat/fire_missile(src)
	actions += new /datum/action/innate/ship_combat/fire_all(src)
	actions += new /datum/action/innate/ship_combat/fire_laser(src)
	actions += new /datum/action/innate/ship_combat/fire_all_lasers(src)
	actions += new /datum/action/innate/ship_combat/adjust_laser_power(src)

	reticle = new(null, src)

	// Console ambient sounds
	console_ambience = new(src, get_console_ambience_sounds())
	console_ambience.start()

/obj/machinery/computer/camera_advanced/ship_combat/LateInitialize()
	. = ..()
	attempt_ship_connection()

/obj/machinery/computer/camera_advanced/ship_combat/Destroy()
	QDEL_NULL(console_ambience)
	cancel_targeting()
	// Unlink interdictor
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	if(interdictor)
		interdictor.unlink_console()
	linked_interdictor_ref = null
	// Unlink cloaking device
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	if(cloak)
		cloak.unlink_console()
	linked_cloak_ref = null
	// Unlink siphon
	var/obj/machinery/shuttle_scrambler/ship_siphon/siphon = linked_siphon_ref?.resolve()
	if(siphon)
		siphon.unlink_console()
	linked_siphon_ref = null
	clear_target()
	for(var/datum/weakref/ref in linked_launchers)
		var/obj/machinery/ship_combat/missile_launcher/launcher = ref.resolve()
		if(launcher)
			launcher.unlink_console()
	linked_launchers.Cut()
	for(var/datum/weakref/ref in linked_turrets)
		var/obj/machinery/ship_combat/laser_turret/turret = ref.resolve()
		if(turret)
			turret.unlink_console()
	linked_turrets.Cut()
	QDEL_NULL(reticle)
	current_ship = null
	return ..()

/obj/machinery/computer/camera_advanced/ship_combat/examine(mob/user)
	. = ..()
	. += span_notice("Linked launchers: [length(linked_launchers)]")
	. += span_notice("Linked laser turrets: [length(linked_turrets)]")
	var/obj/machinery/ship_combat/interdictor/interdictor = linked_interdictor_ref?.resolve()
	if(interdictor)
		. += span_notice("Linked interdictor: [interdictor.name]")
	else
		. += span_warning("No interdictor linked. Use a multitool to link an interdiction system.")
	var/obj/machinery/ship_combat/cloak_device/cloak = linked_cloak_ref?.resolve()
	if(cloak)
		. += span_notice("Linked cloaking device: [cloak.name]")
	else
		. += span_warning("No cloaking device linked. Use a multitool to link a cloaking device.")
	var/obj/machinery/shuttle_scrambler/ship_siphon/siphon = linked_siphon_ref?.resolve()
	if(siphon)
		. += span_notice("Linked data siphon: [siphon.name]")
	else
		. += span_warning("No data siphon linked. Use a multitool to link a siphon.")
	if(target_ship)
		. += span_notice("Current target: [target_ship.display_name]")
	else
		. += span_warning("No target selected. Use the console to select a target ship.")
	if(!is_crew_member(user))
		. += span_warning("You are not authorized to use this console.")

// ========== GHOST ADMIN OVERRIDES ==========

/obj/machinery/computer/camera_advanced/ship_combat/can_use(mob/user)
	// Allow admin ghosts with AI interact
	if(isAdminGhostAI(user))
		return TRUE
	// Allow the current camera user to keep using the console while in attack mode
	// This prevents process() from kicking them out due to distance checks
	if(attack_mode && current_user == user && eyeobj && user.remote_control == eyeobj)
		return TRUE
	return ..()

/// Override to allow granting actions to non-living mobs (admin ghosts)
/obj/machinery/computer/camera_advanced/ship_combat/GrantActions(mob/user)
	for(var/datum/action/to_grant as anything in actions)
		to_grant.Grant(user)

// ========== CREW MEMBERSHIP CHECK ==========

/// Checks if the given user is a member of this ship's crew (admin ghosts with AI interact bypass)
/obj/machinery/computer/camera_advanced/ship_combat/proc/is_crew_member(mob/user)
	if(!ismob(user))
		return FALSE
	// Admin ghosts with AI interact toggle have access
	if(isAdminGhostAI(user))
		return TRUE
	var/mob/living/living_user = user
	if(!istype(living_user) || !living_user.mind)
		return FALSE
	if(!current_ship?.ship_team)
		return TRUE // No ship team set up, allow access
	return (living_user.mind in current_ship.ship_team.members)
