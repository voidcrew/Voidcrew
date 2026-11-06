/**
 * # The Penitentiary's fittings
 *
 * Two families of door:
 * - secure: outpost airlocks that open for the Penitentiary's own staff mobs only. No card opens
 *   them, emags do nothing, and the link sweep (and their own Initialize) makes them outpost
 *   property, so no tool gets a panel open;
 * - the escape line: ordinary tg airlocks a screwdriver, a multitool and wirecutters get through.
 *   The link sweep leaves them alone on purpose.
 * Plus the intake counter's windoor, the warden's console (locked), the evidence lockers (one
 * owner each) and the intake pad. Landmarks are read once by the site's link sweep.
 */

/// Whether `accessor` is one of the Penitentiary's own staff: the warden, the clerk, or one of its guards on duty
/proc/is_penitentiary_staff(mob/accessor)
	if(istype(accessor, /mob/living/basic/ambient_npc/penitentiary))
		return accessor.stat == CONSCIOUS
	if(is_outpost_prison_guard(accessor, on_duty = TRUE))
		var/mob/living/basic/outpost_prison_guard/guard = accessor
		return istype(guard.prison, /datum/outpost_prison/penitentiary)
	return FALSE

// ===== SECURE DOORS =====

/obj/machinery/door/airlock/outpost/penitentiary
	name = "secure airlock"
	req_access = list(ACCESS_PENITENTIARY)

/obj/machinery/door/airlock/outpost/penitentiary/Initialize(mapload)
	. = ..()
	// The link sweep adds it too; a door spawned some other way is still sealed
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/airlock/outpost/penitentiary/allowed(mob/accessor)
	if(isAdminGhostAI(accessor))
		return TRUE
	return is_penitentiary_staff(accessor)

/obj/machinery/door/airlock/outpost/penitentiary/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "locked")
	return FALSE

/obj/machinery/door/airlock/outpost/penitentiary/glass
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/penitentiary/armory
	req_access = list(ACCESS_PENITENTIARY_ARMORY)

// No card and no mob carries armory access
/obj/machinery/door/airlock/outpost/penitentiary/armory/allowed(mob/accessor)
	return isAdminGhostAI(accessor)

/obj/machinery/door/airlock/outpost/penitentiary/capture
	name = "cell door"
	icon = 'icons/obj/doors/airlocks/station/security.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = FALSE
	glass = TRUE
	/// Which capture cell this door closes, set on the map
	var/cell_number = 0

/obj/machinery/door/airlock/outpost/penitentiary/capture/Initialize(mapload)
	. = ..()
	if(cell_number)
		name = "Cell [cell_number]"

// ===== THE ESCAPE LINE =====

/obj/machinery/door/airlock/security/glass/penitentiary_escape
	name = "cell door"
	req_access = list(ACCESS_PENITENTIARY)
	/// Which escape cell this door closes, set on the map
	var/cell_number = 0

/obj/machinery/door/airlock/security/glass/penitentiary_escape/Initialize(mapload)
	. = ..()
	if(cell_number)
		name = "Cell [cell_number]"

/obj/machinery/door/airlock/security/penitentiary_service
	req_access = list(ACCESS_PENITENTIARY)

/obj/machinery/door/airlock/security/penitentiary_service/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/security/glass/penitentiary_podbay
	req_access = list(ACCESS_PENITENTIARY_PODBAY)

/// Doors the link sweep leaves breakable: the escape line and the prison wing's own staff doors
GLOBAL_LIST_INIT(penitentiary_escape_line_doors, typecacheof(list(
	/obj/machinery/door/airlock/security/glass/penitentiary_escape,
	/obj/machinery/door/airlock/security/penitentiary_service,
	/obj/machinery/door/airlock/security/glass/penitentiary_podbay,
	/obj/machinery/door/airlock/security/prison_staff,
)))

// ===== THE INTAKE COUNTER =====

/obj/machinery/door/window/brigdoor/penitentiary
	req_access = list(ACCESS_PENITENTIARY)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/brigdoor/penitentiary, 0)

/obj/machinery/door/window/brigdoor/penitentiary/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/window/brigdoor/penitentiary/allowed(mob/accessor)
	if(isAdminGhostAI(accessor))
		return TRUE
	return is_penitentiary_staff(accessor)

/obj/machinery/door/window/brigdoor/penitentiary/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "locked")
	return FALSE

// ===== THE WARDEN'S CONSOLE =====

/// The guards' anchor in the wing's office. It has no outpost to manage, so it stays locked.
/obj/machinery/computer/outpost_prison_warden/penitentiary

/obj/machinery/computer/outpost_prison_warden/penitentiary/interact(mob/user)
	balloon_alert(user, "locked")
	return TRUE

// No window opens by any route (an AI, an admin's ghost), so nothing here ever acts
/obj/machinery/computer/outpost_prison_warden/penitentiary/ui_status(mob/user, datum/ui_state/state)
	return UI_CLOSE

// ===== EVIDENCE =====

/**
 * One convict's confiscated gear, and a Theft convict's haul. Opens for its owner's mind only,
 * relocks itself on closing, and cannot be broken, emagged or taken apart.
 */
/obj/structure/closet/secure_closet/penitentiary_evidence
	name = "evidence locker"
	// Bolted down: outpost property stops tools, not a pull out of the vault
	anchored = TRUE
	/// The mind whose gear this holds, or null while it is free
	var/datum/weakref/owner_mind

/obj/structure/closet/secure_closet/penitentiary_evidence/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/structure/closet/secure_closet/penitentiary_evidence/Destroy()
	owner_mind = null
	return ..()

/obj/structure/closet/secure_closet/penitentiary_evidence/allowed(mob/accessor)
	if(isAdminGhostAI(accessor))
		return TRUE
	var/datum/mind/owner = owner_mind?.resolve()
	return !!owner && accessor?.mind == owner

/obj/structure/closet/secure_closet/penitentiary_evidence/emag_act(mob/user, obj/item/card/emag/emag_card)
	balloon_alert(user, "locked")
	return FALSE

/obj/structure/closet/secure_closet/penitentiary_evidence/close(mob/living/user)
	. = ..()
	if(. && owner_mind && !locked)
		locked = TRUE
		update_appearance()

/// The mind this locker holds gear for, if it still exists
/obj/structure/closet/secure_closet/penitentiary_evidence/proc/owner()
	return owner_mind?.resolve()

/// Gives the locker to `mind`, named for them
/obj/structure/closet/secure_closet/penitentiary_evidence/proc/assign_to(datum/mind/mind)
	owner_mind = WEAKREF(mind)
	name = "evidence locker ([mind.current?.real_name || mind.name])"
	if(!opened)
		locked = TRUE
	update_appearance()

/// Frees the locker: whatever it held goes, and its name with it
/obj/structure/closet/secure_closet/penitentiary_evidence/proc/release()
	owner_mind = null
	name = initial(name)
	for(var/atom/movable/held in contents)
		qdel(held)
	if(!opened)
		locked = TRUE
	update_appearance()

// ===== THE INTAKE PAD =====

/**
 * A hunter docked at the Meridian hands a warrant target over here: the target on the pad, the
 * hunter beside it. Same pay as their own pad, through the warrant's claim.
 */
/obj/machinery/penitentiary_intake_pad
	name = "intake pad"
	desc = "A booking pad set into the floor in front of the counter."
	icon = 'icons/obj/machines/telepad.dmi'
	icon_state = "lpad-idle"
	density = FALSE
	anchored = TRUE
	use_power = NO_POWER_USE
	layer = LOW_OBJ_LAYER
	COOLDOWN_DECLARE(intake_cooldown)

/obj/machinery/penitentiary_intake_pad/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/penitentiary_intake_pad/interact(mob/user)
	. = ..()
	if(!isliving(user) || !COOLDOWN_FINISHED(src, intake_cooldown))
		return
	COOLDOWN_START(src, intake_cooldown, 2 SECONDS)
	var/result = penitentiary_intake(user)
	if(istext(result))
		balloon_alert(user, result)

/**
 * `user` hands over whoever stands on the pad with an open warrant. Returns the pay list from the
 * claim, or why not.
 */
/obj/machinery/penitentiary_intake_pad/proc/penitentiary_intake(mob/living/user)
	var/datum/criminal_bounty/warrant/warrant
	var/mob/living/carbon/human/target
	for(var/mob/living/carbon/human/person in loc)
		if(person == user)
			continue
		warrant = background_warrant_for_body(person)
		if(warrant)
			target = person
			break
	if(!warrant)
		return "nothing on the pad for this bounty"
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "no ship"
	var/refusal = warrant.warrant_crew_refusal(ship)
	if(refusal)
		return refusal
	var/state = warrant.warrant_capture_state(target)
	var/result = warrant.claim_body(target, ship, null, state, user)
	if(islist(result))
		for(var/mob/living/basic/ambient_npc/penitentiary/clerk/clerk in range(3, src))
			clerk.speak_context("intake", force = TRUE)
			break
	return result

// ===== LANDMARKS =====

/obj/effect/landmark/penitentiary

/obj/effect/landmark/penitentiary/arrival
	name = "penitentiary arrival"

/obj/effect/landmark/penitentiary/escape_cell
	name = "penitentiary escape cell"
	/// Which escape cell this bed is in, set on the map
	var/cell_number = 0

/obj/effect/landmark/penitentiary/capture_cell
	name = "penitentiary capture cell"
	/// Which capture cell this bed is in, set on the map
	var/cell_number = 0

/obj/effect/landmark/penitentiary/massacre_body
	name = "penitentiary massacre body"

/obj/effect/landmark/penitentiary/convict_massacre
	name = "penitentiary massacre convict"

/obj/effect/landmark/penitentiary/pod_cradle
	name = "penitentiary pod cradle"

/obj/effect/landmark/penitentiary/morgue
	name = "penitentiary morgue"
