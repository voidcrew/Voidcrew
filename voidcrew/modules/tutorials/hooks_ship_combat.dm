// Tutorial checklist hooks: the Ship weapons and Ship combat items (voidcrew/modules/ship_combat).
// Overrides chain with any others of the same proc and keep the parent's return value.

// ---------------------------------------------------------------------------
// Ship weapons: building them. on_construction() runs for frame builds and flatpack
// deploys, never for mapped machines.
// ---------------------------------------------------------------------------

/obj/machinery/computer/camera_advanced/ship_combat/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_CONSOLE)

/obj/machinery/ship_combat/missile_launcher/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_LAUNCHER)

/obj/machinery/ship_combat/laser_turret/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_LASER)

/obj/machinery/ship_combat/shield_generator/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_SHIELD)

/obj/machinery/ship_combat/interdictor/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_INTERDICTOR)

/obj/machinery/ship_combat/ew_suite/on_construction(mob/user)
	. = ..()
	tutorial_credit(user, TUTORIAL_STEP_WEAPONS_EW)

/// The screwdriver seal moves a missile from PAYLOAD to ARMED inside the parent (after a do_after).
/obj/structure/ship_missile/attackby(obj/item/W, mob/user, list/modifiers)
	var/state_before = construction_state
	. = ..()
	if(state_before == MISSILE_STATE_PAYLOAD && construction_state == MISSILE_STATE_ARMED && !QDELETED(src))
		tutorial_credit(user, TUTORIAL_STEP_WEAPONS_MISSILE)

// ---------------------------------------------------------------------------
// Ship combat: using them.
// ---------------------------------------------------------------------------

/// The lock lands here. Credits the interdicting crew aboard.
/obj/machinery/ship_combat/interdictor/complete_warmup()
	. = ..()
	if(!interdiction_active)
		return
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(our_ship && !istype(our_ship, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(our_ship, TUTORIAL_STEP_COMBAT_INTERDICT, aboard_only = TRUE)

/// Player fire passes the user; NPC fire passes null.
/obj/machinery/ship_combat/missile_launcher/fire(turf/target, obj/structure/overmap/target_ship, obj/structure/overmap/ship/source_ship, mob/user, spawn_offset_x = 0, spawn_offset_y = 0, approach_dir = null)
	. = ..()
	if(. && user && istype(target_ship, /obj/structure/overmap/ship))
		tutorial_credit(user, TUTORIAL_STEP_COMBAT_MISSILE)

/// Credits the attacking crew when a hit takes a ship's shields from up to broken.
/proc/tutorial_check_shields_broken(obj/structure/overmap/ship/attacker, obj/structure/overmap/ship/target, shields_were_up)
	if(!shields_were_up || QDELETED(attacker) || QDELETED(target) || attacker == target)
		return
	if(!target.shields_broken || istype(attacker, /obj/structure/overmap/ship/npc))
		return
	tutorial_credit_crew(attacker, TUTORIAL_STEP_COMBAT_SHIELDS)

/// The beam can delete itself mid-proc, so its ships are read first.
/obj/effect/ship_laser_beam/fire_laser()
	var/obj/structure/overmap/ship/attacker = source_ship
	var/obj/structure/overmap/ship/target = target_ship
	var/shields_were_up = target?.shields_active
	. = ..()
	tutorial_check_shields_broken(attacker, target, shields_were_up)

/// Missiles break shields by bumping into a wall. The wall's ship is the target.
/obj/structure/ship_shield_wall/Bumped(atom/movable/AM)
	var/obj/effect/ship_missile/missile = AM
	var/obj/structure/overmap/ship/attacker = istype(missile) ? missile.source_ship : null
	var/obj/machinery/ship_combat/shield_generator/gen = generator_ref?.resolve()
	var/obj/structure/overmap/ship/target = gen?.linked_ship_ref?.resolve()
	var/shields_were_up = target?.shields_active
	. = ..()
	if(attacker)
		tutorial_check_shields_broken(attacker, target, shields_were_up)

/// A payload that launched is added to launched_payloads. A new weakref means one went out.
/obj/machinery/ship_combat/ew_suite/on_warmup_complete()
	var/datum/weakref/last_before = length(launched_payloads) ? launched_payloads[length(launched_payloads)] : null
	. = ..()
	var/datum/weakref/last_after = length(launched_payloads) ? launched_payloads[length(launched_payloads)] : null
	if(!last_after || last_after == last_before)
		return
	var/obj/structure/overmap/ship/owner = get_owner_ship()
	if(owner && !istype(owner, /obj/structure/overmap/ship/npc))
		tutorial_credit_crew(owner, TUTORIAL_STEP_COMBAT_HACK, aboard_only = TRUE)

/// Force-docking credits the user, and counts as boarding a pirate ship for the crew aboard.
/obj/machinery/ship_combat/interdictor/force_dock_target(mob/user)
	var/obj/structure/overmap/ship/target = interdicted_ship_ref?.resolve()
	. = ..()
	if(!.)
		return
	if(user)
		tutorial_credit(user, TUTORIAL_STEP_COMBAT_FORCE_DOCK)
	var/obj/structure/overmap/ship/our_ship = linked_ship_ref?.resolve()
	if(our_ship && tutorial_is_pirate_ship(target))
		tutorial_credit_crew(our_ship, TUTORIAL_STEP_PIRATES_BOARD, aboard_only = TRUE)
