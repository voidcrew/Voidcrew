/**
 * # Yard droids
 *
 * The ship bays' working droids: labour and welding droids at the wrecks and walls, a loader
 * shifting boxes between crates, a bartender wiping down the bar, a cleaner with a mop. Each keeps
 * to the room it is mapped in and looks busy (outpost_ambient_work.dm).
 *
 * They are fixtures, not creatures: anchored, not dense, indestructible outpost property. Nobody can
 * pull, push, carry, buckle, box, teleport or take one apart, a person walks straight past one, and
 * a droid never gives or drops anything.
 */
/obj/structure/outpost_yard_droid
	name = "yard droid"
	desc = "A general purpose yard droid."
	icon = 'icons/mob/silicon/robots.dmi'
	icon_state = "robot_old"
	density = FALSE
	anchored = TRUE
	move_resist = INFINITY
	layer = BELOW_MOB_LAYER
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	can_buckle = FALSE
	ai_controller = /datum/ai_controller/outpost_yard_droid
	/// The droid's lit eyes, from the same icon
	var/eye_state = "eyes_old"
	/// The work it does: /datum/outpost_ambient_work types, each with a weight
	var/list/work_weights = list(/datum/outpost_ambient_work/weld = 1)

/obj/structure/outpost_yard_droid/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	AddComponent(/datum/component/outpost_ambient_worker, work_weights)
	update_appearance(UPDATE_OVERLAYS)

/obj/structure/outpost_yard_droid/update_overlays()
	. = ..()
	if(!eye_state)
		return
	. += mutable_appearance(icon, eye_state)
	. += emissive_appearance(icon, eye_state, src)

/// Nothing to salvage, whatever reaches it
/obj/structure/outpost_yard_droid/atom_deconstruct(disassembled = TRUE)
	return

/obj/structure/outpost_yard_droid/labour
	name = "labour droid"
	desc = "A general labour droid. One arm ends in a welding torch, the other in a socket wrench."
	icon_state = "robot_old"
	eye_state = "eyes_old"
	work_weights = list(
		/datum/outpost_ambient_work/weld = 3,
		/datum/outpost_ambient_work/wrench = 2,
		/datum/outpost_ambient_work/pipe = 1,
	)

/obj/structure/outpost_yard_droid/welder
	name = "welding droid"
	desc = "A heavy welding droid with a scorched faceplate and a torch arm."
	icon_state = "engineer"
	eye_state = "engineer_e"
	work_weights = list(
		/datum/outpost_ambient_work/weld = 4,
		/datum/outpost_ambient_work/panel = 1,
	)

/obj/structure/outpost_yard_droid/loader
	name = "loader droid"
	desc = "A cargo loader droid, built to shift the crates nobody else wants to lift."
	icon_state = "engineer"
	eye_state = "engineer_e"
	work_weights = list(/datum/outpost_ambient_work/haul = 1)

/obj/structure/outpost_yard_droid/bartender
	name = "bartender droid"
	desc = "A serving droid in a pressed jacket."
	icon_state = "service_m"
	eye_state = "service_e"
	work_weights = list(
		/datum/outpost_ambient_work/wipe = 3,
		/datum/outpost_ambient_work/pour = 2,
	)

/obj/structure/outpost_yard_droid/cleaner
	name = "cleaning droid"
	desc = "A floor-cleaning droid with a mop arm. It has given up on the oil."
	icon_state = "janitor"
	eye_state = "janitor_e"
	work_weights = list(/datum/outpost_ambient_work/mop = 1)

/**
 * Works while a living player is near, rests otherwise. Unlike tg's default for objects, it turns
 * off when nobody is on its level and idles when nobody is near, exactly as a mob's AI does.
 */
/datum/ai_controller/outpost_yard_droid
	movement_delay = OUTPOST_WORK_STEP_TIME
	ai_movement = /datum/ai_movement/basic_avoidance
	max_target_distance = OUTPOST_WORK_RANGE * 2
	planning_subtrees = list(/datum/ai_planning_subtree/outpost_ambient_work)

/datum/ai_controller/outpost_yard_droid/TryPossessPawn(atom/new_pawn)
	if(!istype(new_pawn, /obj/structure/outpost_yard_droid))
		return AI_CONTROLLER_INCOMPATIBLE
	return ..()

/datum/ai_controller/outpost_yard_droid/get_expected_ai_status()
	var/turf/pawn_turf = get_turf(pawn)
	if(isnull(pawn_turf) || !able_to_run || on_failed_planning_timeout || !length(SSmobs.clients_by_zlevel[pawn_turf.z]))
		return AI_STATUS_OFF
	return should_idle() ? AI_STATUS_IDLE : AI_STATUS_ON
