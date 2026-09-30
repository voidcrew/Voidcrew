/**
 * # Prison wing doors
 *
 * The doors the prison wing's map places: the window doors on each side of a serving hatch, the
 * staff doors prisoners cannot use, the numbered cell doors and their bolt buttons. The window
 * doors and bolt buttons are protected outpost property, though rioters can smash the window doors
 * (outpost_prison_breakout.dm); the airlocks can be broken, and one built where a staff or cell door
 * stood becomes that door again, as does a window door fitted to a hatch. Staff doors and the office side of a
 * hatch open for members of the wing, or for anyone but prisoners while the warden lets visitors
 * in; bolt buttons work for members only. A prisoner in custody passes a staff door only dragged by
 * a member, down or cuffed (outpost_prisoner_escorted()). A loose one (out of the cell block and on
 * the run) goes through an open one like anyone else, and has to break a shut one down. Who counts
 * as a member, where prisoners can stand and what counts as their cell are in
 * outpost_prison_containment.dm.
 */

// ===== SERVING HATCH WINDOW DOORS =====

/// The yard side of a serving hatch. Anyone may open it, prisoners included.
/obj/machinery/door/window/outpost_prison_yard
	name = "hatch window"
	desc = "The yard side of a serving hatch."

/obj/machinery/door/window/outpost_prison_yard/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/outpost_prison_yard, 0)

/// The office side of a serving hatch. It opens for members of the wing, never for prisoners; no ID needed.
/obj/machinery/door/window/brigdoor/outpost_prison_staff
	name = "hatch window"
	desc = "The office side of a serving hatch. It won't open for prisoners."

/obj/machinery/door/window/brigdoor/outpost_prison_staff/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/window/brigdoor/outpost_prison_staff/allowed(mob/accessor)
	if(!may_use_outpost_prison_staff_door(src, accessor))
		return FALSE
	return ..()

/obj/machinery/door/window/brigdoor/outpost_prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(is_outpost_prisoner(pass_info.requester_ref?.resolve()))
		return FALSE
	return ..()

/**
 * Staff can toss things onto the counter from the office: an item thrown by someone this window opens
 * for gets through it shut, and the yard side, if shut, stops it on the counter. Never a thrown person.
 */
/obj/machinery/door/window/brigdoor/outpost_prison_staff/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(. || border_dir != dir || !isitem(mover) || !mover.throwing)
		return
	var/mob/thrower = mover.throwing.get_thrower()
	return !isnull(thrower) && may_use_outpost_prison_staff_door(src, thrower)

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/brigdoor/outpost_prison_staff, 0)

// ===== STAFF DOORS =====

/// The prison's office and entrance doors. Members of the wing may use them; prisoners never can.
/obj/machinery/door/airlock/security/prison_staff
	name = "prison staff airlock"

/obj/machinery/door/airlock/security/prison_staff/allowed(mob/accessor)
	if(!may_use_outpost_prison_staff_door(src, accessor))
		return FALSE
	return ..()

// Broken down rather than taken apart, the frame goes too, so rioters are not left facing a solid frame in the doorway.
/obj/machinery/door/airlock/security/prison_staff/on_deconstruction(disassembled)
	var/turf/spot = loc
	var/list/frames_before = list()
	if(!disassembled && isturf(spot))
		for(var/obj/structure/door_assembly/frame in spot)
			frames_before += frame
	. = ..()
	if(disassembled || !isturf(spot))
		return
	for(var/obj/structure/door_assembly/frame in spot)
		if(!(frame in frames_before) && !QDELETED(frame))
			frame.deconstruct(FALSE)

// Open or closed, a prisoner in custody cannot walk through on their own. A member of the wing may
// drag one through who is down or cuffed; nobody else may, visitors let in included. A loose
// prisoner is out already: an open staff door is only a door to them.
/obj/machinery/door/airlock/security/prison_staff/CanAllowThrough(atom/movable/mover, border_dir)
	if(is_outpost_prisoner(mover) && !outpost_prisoner_loose(mover) && !outpost_prisoner_escorted(src, mover))
		return FALSE
	return ..()

// Their own AI never paths through, dragged or not, until they are loose.
/obj/machinery/door/airlock/security/prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	var/atom/requester = pass_info.requester_ref?.resolve()
	if(is_outpost_prisoner(requester) && !outpost_prisoner_loose(requester))
		return FALSE
	return ..()

/// Whether `thing` is a loose prisoner: out of the cell block and on the run
/proc/outpost_prisoner_loose(atom/thing)
	var/mob/living/basic/outpost_prisoner/prisoner = thing
	return istype(prisoner) && prisoner.trouble == PRISONER_TROUBLE_LOOSE

/obj/machinery/door/airlock/security/prison_staff/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

// ===== CELLS =====

/// A cell's front door. Prisoners come and go through it unless its bolt button bolts it.
/obj/machinery/door/airlock/security/glass/outpost_prison_cell
	name = "cell door"
	/// Which cell this door closes, set on the map
	var/cell_number = 0

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/Initialize(mapload)
	. = ..()
	if(cell_number)
		name = "Cell [cell_number]"

/// Bolts or unbolts the door of one cell of its own prison wing, found through the wing's prison.
/obj/machinery/button/outpost_prison_bolt
	name = "cell bolt button"
	desc = "Bolts or unbolts the door of the cell beside it."
	skin = "-warning"
	can_alter_skin = FALSE
	/// The cell whose door this button bolts, set on the map
	var/cell_number = 0

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/button/outpost_prison_bolt, 24)

/obj/machinery/button/outpost_prison_bolt/Initialize(mapload, ndir = 0, built = 0)
	. = ..()
	AddElement(/datum/element/outpost_property)
	if(cell_number)
		name = "cell [cell_number] bolt button"

// Members of the wing only, whether or not visitors are let in.
/obj/machinery/button/outpost_prison_bolt/allowed(mob/accessor)
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(prison && !isAdminGhostAI(accessor) && !prison.is_member(accessor))
		return FALSE
	return ..()

/obj/machinery/button/outpost_prison_bolt/attempt_press(mob/user)
	. = ..()
	if(!.)
		return
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(!prison?.toggle_cell_bolts(cell_number, user))
		balloon_alert(user, "no cell door")
		return FALSE
