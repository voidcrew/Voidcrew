/**
 * Ways the crew gets through its own bluespace damper (teleport_blocker.dm). Both are keyed
 * to one damper's link_key, and resetting that key with a multitool revokes them.
 *
 * - A field pass clipped onto a worn uniform carries its wearer, and everything on them,
 *   through. In a bag or a pocket it does nothing. Something beamed separately still bounces.
 * - A transporter pad keyed to the damper carries its whole beam through, both ways. The pad
 *   sets GLOB.teleport_field_beam_ship around its own do_teleport() calls, so the bypass
 *   reaches that pad's beam and nothing else on TELEPORT_CHANNEL_QUANTUM.
 */

/// The ship a keyed transporter pad is beaming through right now. Set only for the length of one synchronous do_teleport().
GLOBAL_DATUM(teleport_field_beam_ship, /obj/structure/overmap/ship)
/// world.time the beam ship above was set, so a runtime mid-beam can't leave the bypass open past this tick
GLOBAL_VAR_INIT(teleport_field_beam_time, -1)

/// The ship an atom stands on, by the area under it, or null.
/proc/get_teleport_field_ship(atom/thing)
	var/area/here = get_area(thing)
	if(!here)
		return null
	var/obj/structure/overmap/ship/ship
	if(istype(here, /area/shuttle/voidcrew))
		var/area/shuttle/voidcrew/ship_area = here
		ship = ship_area.shuttle_port?.current_ship
	else
		ship = get_voidcrew_ship_for_turf(get_turf(thing))
	if(QDELETED(ship) || !ship.shuttle?.shuttle_areas[here])
		return null
	return ship

/// Whether a live damper on `ship` lets `teleported` through: a keyed pad is beaming it, or it wears a keyed pass.
/proc/teleport_field_lets_through(obj/structure/overmap/ship/ship, atom/movable/teleported)
	if(GLOB.teleport_field_beam_ship == ship && GLOB.teleport_field_beam_time == world.time)
		return TRUE
	if(!ishuman(teleported))
		return FALSE
	var/mob/living/carbon/human/wearer = teleported
	var/obj/item/clothing/under/uniform = wearer.w_uniform
	if(!istype(uniform))
		return FALSE
	for(var/obj/item/clothing/accessory/field_pass/pass in uniform.attached_accessories)
		if(pass.keyed_to_live_blocker(ship))
			return TRUE
	return FALSE

// ---------------------------------------------------------------------------
// Field pass
// ---------------------------------------------------------------------------

/obj/item/clothing/accessory/field_pass
	name = "field pass"
	desc = "A coded clip that tells a bluespace damper you're crew."
	icon_state = "lawyerbadge"
	/// The damper this pass was keyed to
	var/datum/weakref/blocker_ref
	/// The damper's link key when this pass was keyed
	var/link_key

/obj/item/clothing/accessory/field_pass/proc/link_to(obj/machinery/teleport_blocker/blocker)
	blocker_ref = WEAKREF(blocker)
	link_key = blocker.link_key

/// TRUE if this pass's damper still holds the same key and is shielding `ship` right now.
/obj/item/clothing/accessory/field_pass/proc/keyed_to_live_blocker(obj/structure/overmap/ship/ship)
	var/obj/machinery/teleport_blocker/blocker = blocker_ref?.resolve()
	if(!blocker || QDELETED(blocker) || !link_key || blocker.link_key != link_key)
		return FALSE
	return blocker.get_blocked_ship() == ship

/datum/design/field_pass
	name = "Field pass"
	desc = "A coded clip keyed to a bluespace damper."
	id = "field_pass"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SMALL_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SMALL_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/clothing/accessory/field_pass
	category = list(
		RND_CATEGORY_TOOLS + RND_SUBCATEGORY_TOOLS_ENGINEERING_ADVANCED,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_ENGINEERING

// ---------------------------------------------------------------------------
// Keyed transporter pads
// ---------------------------------------------------------------------------

/obj/machinery/transporter_pad
	/// The bluespace damper this pad is keyed to
	var/datum/weakref/field_blocker_ref
	/// The damper's link key when this pad was keyed
	var/field_link_key

/// The ship this pad stands on, for keying it to a damper.
/obj/machinery/transporter_pad/proc/get_protected_ship_for_link()
	return get_teleport_field_ship(src)

/obj/machinery/transporter_pad/proc/link_to_blocker(obj/machinery/teleport_blocker/blocker)
	field_blocker_ref = WEAKREF(blocker)
	field_link_key = blocker.link_key

/**
 * The ship whose live damper this pad's beams pass through, or null. The pad has to be on
 * that ship and still hold the damper's current key.
 */
/obj/machinery/transporter_pad/proc/get_field_beam_ship()
	var/obj/machinery/teleport_blocker/blocker = field_blocker_ref?.resolve()
	if(!blocker || QDELETED(blocker) || !field_link_key || blocker.link_key != field_link_key)
		return null
	var/obj/structure/overmap/ship/ship = blocker.get_blocked_ship()
	if(!ship || get_teleport_field_ship(src) != ship)
		return null
	return ship

/**
 * The pad's one do_teleport() per beamed atom, carrying `field_beam_ship`'s damper bypass for
 * exactly that call. Null `field_beam_ship` is a plain beam.
 */
/obj/machinery/transporter_pad/proc/field_beam_teleport(atom/movable/thing, atom/destination, obj/structure/overmap/ship/field_beam_ship)
	GLOB.teleport_field_beam_ship = field_beam_ship
	GLOB.teleport_field_beam_time = world.time
	. = do_teleport(thing, destination, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE)
	GLOB.teleport_field_beam_ship = null
