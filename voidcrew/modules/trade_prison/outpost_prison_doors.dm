/**
 * # Prison wing doors
 *
 * The doors the prison wing's map places: the window doors on each side of a serving hatch, the
 * staff doors (Processing's pair included, outpost_prison_host.dm), the numbered cell doors and
 * their bolt buttons. All of them are protected outpost property.
 *
 * The airlocks follow owner decision O8 (police decisions 47 and 48): a screwdriver opens the
 * panel, wirecutters and a multitool work the wires, an airlock authentication override card opens
 * the door, a crowbar pries it with the power out and forces it the slow way with the power on, a
 * plain emag does nothing, and welders, wrenches, electronics removal and plating are refused. Any
 * door worked or forced this way mends after OUTPOST_CHECKPOINT_EMAG_TIME once its doorway is
 * clear: panel shut, wires whole, power and bolts back, and shut again. Opening one by hack or
 * force while the wing holds anyone reports OUTPOST_CRIME_JAILBREAK on the opener.
 *
 * Rioters can smash a serving hatch's window doors and batter a staff or Processing airlock on its
 * own damage counter until it swings open and stays open, mending by the same timer
 * (outpost_prison_breakout.dm); nothing is deleted and no frame is left in the doorway.
 */

// ===== LOCKUP AIRLOCK HACKING AND MENDING (O8) =====

/// Shared hacking, forcing and self-repair state for a lockup airlock (staff, Processing or cell)
/datum/lockup_door_state
	/// The airlock this state belongs to
	var/obj/machinery/door/airlock/door
	/// Set while an override card or a finished crowbar force swings the door open
	var/hack_opening = FALSE
	/// Set when a pulsed bolt wire lifts the bolts, so opening the unbolted door counts as the hack
	var/bolt_hacked = FALSE
	/// Set while the door stands open from a hack, override card, pry, force or rioter battering
	var/breached_open = FALSE
	/// Someone is working the door with a crowbar right now
	var/forcing = FALSE
	/// Set while mending, so repairing wires does not start another mend
	var/mending = FALSE
	/// Who last worked the panel, wires, card or crowbar
	var/datum/weakref/last_hacker
	/// What they last worked it with, kept as arrest evidence
	var/datum/weakref/last_hack_tool
	/// world.time they last worked it
	var/last_hack_at = 0
	/// Who pulsed WIRE_BOLTS to lift the bolts, kept until the door opens, re-bolts or mends
	var/datum/weakref/bolt_hacker
	/// Tool or assembly used when WIRE_BOLTS lifted the bolts
	var/datum/weakref/bolt_hack_tool

/datum/lockup_door_state/New(obj/machinery/door/airlock/owner)
	. = ..()
	door = owner

/datum/lockup_door_state/Destroy()
	door = null
	last_hacker = null
	last_hack_tool = null
	bolt_hacker = null
	bolt_hack_tool = null
	return ..()

/// Syncs `mend_pending` and `mend_due` on the airlock itself
/datum/lockup_door_state/proc/set_mend_state(pending, due = 0)
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		staff_door.mend_pending = pending
		staff_door.mend_due = due
	else if(istype(door, /obj/machinery/door/airlock/security/glass/outpost_prison_cell))
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		cell_door.mend_pending = pending
		cell_door.mend_due = due

/datum/lockup_door_state/proc/is_mend_pending()
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		return staff_door.mend_pending
	if(istype(door, /obj/machinery/door/airlock/security/glass/outpost_prison_cell))
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		return cell_door.mend_pending
	return FALSE

/// `who` worked on `door` with `tool`: they answer for what it does next, and the mend timer starts
/datum/lockup_door_state/proc/note_hack(mob/living/who, obj/item/tool = null)
	if(mending || QDELETED(door))
		return
	if(isliving(who))
		var/same_hacker = (last_hacker?.resolve() == who) && last_hack_at && (world.time - last_hack_at <= 10 SECONDS)
		last_hacker = WEAKREF(who)
		last_hack_at = world.time
		if(isitem(tool) && !QDELETED(tool))
			last_hack_tool = WEAKREF(tool)
		else if(!same_hacker || !last_hack_tool?.resolve())
			last_hack_tool = null
		if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
			get_outpost_prison(door)?.note_inmate_breakout(who, door)
	if(is_mend_pending())
		return
	set_mend_state(TRUE, world.time + OUTPOST_CHECKPOINT_EMAG_TIME)
	addtimer(CALLBACK(src, PROC_REF(mend_hack)), OUTPOST_CHECKPOINT_EMAG_TIME, TIMER_DELETE_ME)

/// Whoever worked the door in the last few seconds, or null
/datum/lockup_door_state/proc/hack_culprit()
	if(!last_hack_at || world.time - last_hack_at > 10 SECONDS)
		return null
	var/mob/living/culprit = last_hacker?.resolve()
	return isliving(culprit) ? culprit : null

/// What they last worked the door with in the last few seconds, or null
/datum/lockup_door_state/proc/hack_tool()
	if(!last_hack_at || world.time - last_hack_at > 10 SECONDS)
		return null
	var/obj/item/tool = last_hack_tool?.resolve()
	return isitem(tool) && !QDELETED(tool) ? tool : null

/// Culprit for a hacked open: whoever worked the door just now, or whoever lifted its bolts with WIRE_BOLTS
/datum/lockup_door_state/proc/open_culprit()
	var/mob/living/culprit = hack_culprit()
	if(culprit)
		return culprit
	if(bolt_hacked)
		culprit = bolt_hacker?.resolve()
		if(isliving(culprit))
			return culprit
	return null

/// Tool for a hacked open: the recent hack tool, or the tool/assembly that lifted its bolts
/datum/lockup_door_state/proc/open_tool()
	var/obj/item/tool = hack_tool()
	if(tool)
		return tool
	if(bolt_hacked)
		tool = bolt_hack_tool?.resolve()
		if(isitem(tool) && !QDELETED(tool))
			return tool
	return null

/// Whether this door's steady-state bolts are down (a cell bolted from its wall button)
/datum/lockup_door_state/proc/wanted_bolts()
	if(istype(door, /obj/machinery/door/airlock/security/glass/outpost_prison_cell))
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = door
		return !!cell_door.staff_bolted
	return FALSE

/// Whether an open outer Processing door must wait for an outsider inside Processing to step out before mending shut
/datum/lockup_door_state/proc/processing_exit_blocked()
	if(QDELETED(door) || door.density || !istype(door, /obj/machinery/door/airlock/security/prison_staff/processing/outer))
		return FALSE
	var/datum/outpost_prison/prison = get_outpost_prison(door)
	return !!prison?.processing_outsider_inside()

/// Whether anyone (standing or lying) or anything bulky is in the doorway
/datum/lockup_door_state/proc/doorway_occupied()
	if(QDELETED(door))
		return FALSE
	for(var/atom/movable/thing in get_turf(door))
		if(thing == door || iseffect(thing))
			continue
		if(isliving(thing) || thing.density)
			return TRUE
	return FALSE

/// An open floor tile next to the door where detached wire assemblies can drop
/datum/lockup_door_state/proc/drop_turf()
	var/turf/here = get_turf(door)
	if(!here)
		return null
	for(var/direction in GLOB.cardinals)
		var/turf/neighbor = get_step(here, direction)
		if(neighbor && !neighbor.density)
			return neighbor
	return here

/// Whether anything from a hack, force or rioter battering still needs mending
/datum/lockup_door_state/proc/still_hacked()
	if(QDELETED(door))
		return FALSE
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		if(staff_door.rioter_broken || staff_door.rioter_damage > 0)
			return TRUE
	return door.panel_open || (door.obj_flags & EMAGGED) || length(door.wires?.cut_wires) || length(door.wires?.assemblies) || breached_open || bolt_hacked || (door.locked != wanted_bolts()) || !door.hasPower() || door.isElectrified() || !door.lights || !door.safe || !door.normalspeed || door.emergency || door.autoclose != initial(door.autoclose) || door.aiControlDisabled != initial(door.aiControlDisabled) || door.aiDisabledIdScanner != initial(door.aiDisabledIdScanner) || door.security_level != initial(door.security_level)

/// Mends the door once nobody stands in the doorway: panel shut, wires whole, power and bolts back, and closed
/datum/lockup_door_state/proc/mend_hack()
	if(QDELETED(door))
		return
	if(!still_hacked() && door.density)
		set_mend_state(FALSE, 0)
		return
	if(door.operating || doorway_occupied() || processing_exit_blocked())
		addtimer(CALLBACK(src, PROC_REF(mend_hack)), 3 SECONDS, TIMER_UNIQUE | TIMER_DELETE_ME)
		return
	set_mend_state(FALSE, 0)
	mending = TRUE
	door.obj_flags &= ~EMAGGED
	door.panel_open = FALSE
	if(door.wires && length(door.wires.assemblies))
		var/turf/drop_at = drop_turf()
		for(var/color in door.wires.assemblies.Copy())
			var/obj/item/assembly/attached = door.wires.detach_assembly(color)
			if(attached && drop_at)
				attached.forceMove(drop_at)
	door.wires?.repair()
	door.security_level = initial(door.security_level)
	door.set_electrified(MACHINE_NOT_ELECTRIFIED)
	door.regainMainPower()
	door.regainBackupPower()
	door.lights = TRUE
	door.safe = TRUE
	door.normalspeed = TRUE
	door.autoclose = initial(door.autoclose)
	door.emergency = FALSE
	door.aiControlDisabled = initial(door.aiControlDisabled)
	door.aiDisabledIdScanner = initial(door.aiDisabledIdScanner)
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = door
		staff_door.rioter_broken = FALSE
		staff_door.rioter_damage = 0
	breached_open = FALSE
	bolt_hacked = FALSE
	bolt_hacker = null
	bolt_hack_tool = null
	if(door.density)
		if(wanted_bolts())
			if(!door.locked)
				door.bolt()
		else if(door.locked)
			door.unbolt()
	else if(door.locked)
		door.unbolt()
	mending = FALSE
	last_hacker = null
	last_hack_tool = null
	last_hack_at = 0
	do_sparks(2, TRUE, door)
	door.visible_message(span_notice("[door] sparks, and its lights come back on."))
	door.update_appearance()
	if(!door.density)
		INVOKE_ASYNC(src, PROC_REF(finish_mend_close))
	else
		get_outpost_prison(door)?.refresh_reach()

/// Closes an open mended airlock; re-schedules mending if someone blocked the swing, or restores staff bolts once shut
/datum/lockup_door_state/proc/finish_mend_close()
	if(QDELETED(door))
		return
	if(!door.density && !door.operating)
		door.close()
	if(QDELETED(src) || QDELETED(door))
		return
	if(!door.density)
		breached_open = TRUE
		set_mend_state(TRUE, world.time + 3 SECONDS)
		addtimer(CALLBACK(src, PROC_REF(mend_hack)), 3 SECONDS, TIMER_UNIQUE | TIMER_DELETE_ME)
		get_outpost_prison(door)?.refresh_reach()
		return
	if(wanted_bolts() && !door.locked)
		door.bolt()
	get_outpost_prison(door)?.refresh_reach()

/// The door was opened by a hack, override card, pry or crowbar force
/datum/lockup_door_state/proc/door_hacked_open(mob/living/culprit, obj/item/tool = null)
	if(QDELETED(door))
		return
	breached_open = TRUE
	bolt_hacked = FALSE
	bolt_hacker = null
	bolt_hack_tool = null
	door.autoclose = FALSE
	note_hack(culprit, tool)
	log_game("OUTPOST LOCKUP: [culprit ? key_name(culprit) : "nobody known"] hacked [door] open at [AREACOORD(door)].")
	var/datum/outpost_prison/prison = get_outpost_prison(door)
	prison?.refresh_reach()
	if(!prison?.holds_anyone())
		return
	record_lockup_break_in(prison, door, culprit)
	playsound(door, 'sound/machines/warning-buzzer.ogg', 60, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	if(culprit)
		prison.outpost?.police?.report_crime(culprit, OUTPOST_CRIME_JAILBREAK, null, QDELETED(tool) ? null : tool)

/// Shared open() wrapper: distinguishes a hack/force opening from ordinary use
/datum/lockup_door_state/proc/should_open_as_hack(forced)
	return !mending && (forced != DEFAULT_DOOR_CHECKS || hack_opening || bolt_hacked)

/// Whether a powered crowbar force can keep working on the door
/datum/lockup_door_state/proc/still_forceable()
	return !QDELETED(door) && door.density && !door.welded

/// Forces a powered or bolted lockup door open with a crowbar after OUTPOST_POLICE_CELL_FORCE_TIME
/datum/lockup_door_state/proc/force_door(mob/living/user, obj/item/tool)
	if(forcing || !still_forceable())
		return FALSE
	forcing = TRUE
	tool?.play_tool_sound(door, 50)
	if(tool)
		user.visible_message(
			span_warning("[user] wedges [tool] into [door] and starts forcing it!"),
			span_notice("You wedge [tool] into [door] and start forcing it."),
		)
	else
		user.visible_message(
			span_warning("[user] starts forcing [door]!"),
			span_notice("You start forcing [door]."),
		)
	var/datum/outpost_prison/prison = get_outpost_prison(door)
	if(istype(door, /obj/machinery/door/airlock/security/prison_staff))
		prison?.note_inmate_breakout(user, door)
	if(prison?.holds_anyone())
		playsound(door, 'sound/machines/warning-buzzer.ogg', 60, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	log_game("OUTPOST LOCKUP: [key_name(user)] started forcing [door] at [AREACOORD(door)] with [tool].")
	var/succeeded = do_after(user, OUTPOST_POLICE_CELL_FORCE_TIME, target = door, extra_checks = CALLBACK(src, PROC_REF(still_forceable)))
	if(QDELETED(src) || QDELETED(door))
		return FALSE
	forcing = FALSE
	if(!succeeded || !still_forceable())
		return FALSE
	tool?.play_tool_sound(door, 50)
	user.visible_message(
		span_danger("[user] forces [door] open!"),
		span_notice("You force [door] open."),
	)
	log_game("OUTPOST LOCKUP: [key_name(user)] forced [door] at [AREACOORD(door)].")
	note_hack(user, tool)
	if(door.locked)
		door.unbolt()
	hack_opening = TRUE
	var/opened = door.open(FORCING_DOOR_CHECKS)
	if(!opened && !QDELETED(door) && door.density)
		opened = door.open(BYPASS_DOOR_CHECKS)
	hack_opening = FALSE
	return opened

/// Returns the lockup hacking state datum of `holder`, if `holder` is a lockup airlock
/proc/lockup_door_state_of(atom/holder)
	if(istype(holder, /obj/machinery/door/airlock/security/prison_staff))
		var/obj/machinery/door/airlock/security/prison_staff/staff_door = holder
		return staff_door.lockup_hack
	if(istype(holder, /obj/machinery/door/airlock/security/glass/outpost_prison_cell))
		var/obj/machinery/door/airlock/security/glass/outpost_prison_cell/cell_door = holder
		return cell_door.lockup_hack
	return null

/// Wires for a lockup airlock: notes whoever cuts, pulses or wires an assembly onto it
/datum/wires/airlock/security/outpost_lockup
	/// Assembly weakref -> weakref of the mob who attached it, so a remote pulse still knows its hacker
	var/list/assembly_installers

/datum/wires/airlock/security/outpost_lockup/Destroy()
	assembly_installers = null
	return ..()

/datum/wires/airlock/security/outpost_lockup/cut(wire, mob/living/source)
	var/datum/lockup_door_state/state = lockup_door_state_of(holder)
	state?.note_hack(source, isliving(source) ? source.get_active_held_item() : null)
	return ..()

/datum/wires/airlock/security/outpost_lockup/on_cut(wire, mend = FALSE, mob/living/source = null)
	if(wire == WIRE_TIMING && mend)
		var/datum/lockup_door_state/state = lockup_door_state_of(holder)
		if(state?.mending)
			return
	return ..()

/datum/wires/airlock/security/outpost_lockup/pulse(wire, mob/living/user, force = FALSE)
	var/datum/lockup_door_state/state = lockup_door_state_of(holder)
	state?.note_hack(user, isliving(user) ? user.get_active_held_item() : null)
	return ..()

/datum/wires/airlock/security/outpost_lockup/on_pulse(wire)
	var/obj/machinery/door/airlock/door = holder
	if(wire == WIRE_OPEN && istype(door, /obj/machinery/door/airlock/security/prison_staff) && door.requiresID())
		return
	var/datum/lockup_door_state/state = lockup_door_state_of(door)
	var/unbolting = wire == WIRE_BOLTS && istype(door) && door.locked && door.hasPower()
	if(unbolting)
		if(state && !state.mending)
			state.bolt_hacked = TRUE
			var/mob/living/culprit = state.hack_culprit()
			var/obj/item/tool = state.hack_tool()
			state.bolt_hacker = culprit ? WEAKREF(culprit) : null
			state.bolt_hack_tool = tool ? WEAKREF(tool) : null
	else if(wire == WIRE_BOLTS && istype(door) && !door.locked && state)
		state.bolt_hacked = FALSE
		state.bolt_hacker = null
		state.bolt_hack_tool = null
	. = ..()
	if(unbolting && !QDELETED(door) && !door.locked)
		get_outpost_prison(door)?.refresh_reach()

/datum/wires/airlock/security/outpost_lockup/attach_assembly(color, obj/item/assembly/S)
	var/mob/living/holder_mob = isliving(S?.loc) ? S.loc : null
	. = ..()
	if(!.)
		return
	var/datum/lockup_door_state/state = lockup_door_state_of(holder)
	var/mob/living/installer = isliving(usr) ? usr : (holder_mob || state?.hack_culprit())
	if(installer)
		LAZYSET(assembly_installers, WEAKREF(S), WEAKREF(installer))
	state?.note_hack(installer, S)

/datum/wires/airlock/security/outpost_lockup/detach_assembly(color)
	. = ..()
	if(.)
		LAZYREMOVE(assembly_installers, WEAKREF(.))

/datum/wires/airlock/security/outpost_lockup/pulse_assembly(obj/item/assembly/S)
	var/datum/weakref/installer_ref = S ? LAZYACCESS(assembly_installers, WEAKREF(S)) : null
	var/mob/living/installer = installer_ref?.resolve()
	var/datum/lockup_door_state/state = lockup_door_state_of(holder)
	if(state && isliving(installer))
		state.note_hack(installer, S)
	return ..()

// ===== SERVING HATCH WINDOW DOORS =====

/// The yard side of a serving hatch. Anyone may open it, prisoners included.
/obj/machinery/door/window/outpost_prison_yard
	name = "hatch window"
	desc = "The yard side of a serving hatch."

/obj/machinery/door/window/outpost_prison_yard/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/window/outpost_prison_yard/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

MAPPING_DIRECTIONAL_HELPERS(/obj/machinery/door/window/outpost_prison_yard, 0)

/// The office side of a serving hatch. It opens for members of the wing, never for prisoners; no ID needed.
/obj/machinery/door/window/brigdoor/outpost_prison_staff
	name = "hatch window"
	desc = "The office side of a serving hatch. It won't open for prisoners."

/obj/machinery/door/window/brigdoor/outpost_prison_staff/Initialize(mapload, set_dir, unres_sides)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/window/brigdoor/outpost_prison_staff/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/obj/machinery/door/window/brigdoor/outpost_prison_staff/allowed(mob/accessor)
	if(!may_use_outpost_prison_staff_door(src, accessor))
		return FALSE
	return ..()

/obj/machinery/door/window/brigdoor/outpost_prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	var/atom/requester = pass_info?.requester_ref?.resolve()
	if(is_outpost_prisoner(requester))
		return FALSE
	if(density && dir == to_dir && !may_use_outpost_prison_staff_door(src, requester))
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

/// The prison's office, entrance and Processing doors. Members of the wing may use them; prisoners never can unless breached.
/obj/machinery/door/airlock/security/prison_staff
	name = "prison staff airlock"
	security_level = 0 // AIRLOCK_SECURITY_NONE (airlock.dm undefines it)
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	/// Shared hacking, forcing and self-repair state
	var/datum/lockup_door_state/lockup_hack
	/// Whether a self-repair timer is running
	var/mend_pending = FALSE
	/// world.time the first scheduled mend is due, or 0
	var/mend_due = 0
	/// Rioter damage accumulated on this door during a riot
	var/rioter_damage = 0
	/// Set once rioter blows batter this door open, until it mends
	var/rioter_broken = FALSE

/obj/machinery/door/airlock/security/prison_staff/Initialize(mapload)
	lockup_hack = new(src)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/airlock/security/prison_staff/Destroy()
	QDEL_NULL(lockup_hack)
	return ..()

/obj/machinery/door/airlock/security/prison_staff/get_wires()
	return new /datum/wires/airlock/security/outpost_lockup(src)

/obj/machinery/door/airlock/security/prison_staff/canAIControl(mob/user)
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/canAIHack()
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/check_access(obj/item/I)
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/allowed(mob/accessor)
	if(emergency)
		return TRUE
	return may_use_outpost_prison_staff_door(src, accessor) || lets_leaving_prisoner(accessor)

/// Whether `mover` is a departing prisoner on the staff side who must pass this door to reach Processing's yard door
/obj/machinery/door/airlock/security/prison_staff/proc/lets_leaving_prisoner(atom/movable/mover)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = mover
	if(!istype(prisoner) || prisoner.phase != PRISONER_LEAVING)
		return FALSE
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	var/turf/here = get_turf(prisoner)
	return !!prison && prisoner.prison == prison && prison.processing_on_yard_side(here) && (!prison.in_cell_block(here) || here == loc)

/// Whether this door has been opened by a hack, override card, crowbar or rioter blows and has not yet mended
/obj/machinery/door/airlock/security/prison_staff/proc/lockup_breached()
	return rioter_broken || !!lockup_hack?.breached_open

/obj/machinery/door/airlock/security/prison_staff/proc/note_hack(mob/living/who, obj/item/tool = null)
	lockup_hack?.note_hack(who, tool)

/obj/machinery/door/airlock/security/prison_staff/proc/door_hacked_open(mob/living/culprit, obj/item/tool = null)
	lockup_hack?.door_hacked_open(culprit, tool)

/obj/machinery/door/airlock/security/prison_staff/proc/doorway_occupied()
	return !!lockup_hack?.doorway_occupied()

/obj/machinery/door/airlock/security/prison_staff/proc/still_hacked()
	return !!lockup_hack?.still_hacked()

/obj/machinery/door/airlock/security/prison_staff/proc/mend_hack()
	lockup_hack?.mend_hack()

/obj/machinery/door/airlock/security/prison_staff/proc/mend_emag()
	if(QDELETED(src) || !(obj_flags & EMAGGED))
		return
	mend_hack()

/obj/machinery/door/airlock/security/prison_staff/should_try_removing_electronics()
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/try_reinforce(mob/user, obj/item/stack/sheet/material, amt_required, new_security_level)
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/outpost_hackable(obj/item/tool)
	return tool?.tool_behaviour == TOOL_SCREWDRIVER || tool?.tool_behaviour == TOOL_WIRECUTTER

/obj/machinery/door/airlock/security/prison_staff/outpost_forceable()
	return TRUE

/obj/machinery/door/airlock/security/prison_staff/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	note_hack(user, tool)

// Only an airlock authentication override card works here; a plain emag does nothing (police decision 48)
/obj/machinery/door/airlock/security/prison_staff/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(!istype(emag_card, /obj/item/card/emag/doorjack))
		return FALSE
	. = ..()
	if(.)
		note_hack(user, emag_card)

/obj/machinery/door/airlock/security/prison_staff/finish_emag_act()
	if(locked)
		unbolt()
	if(lockup_hack)
		lockup_hack.hack_opening = TRUE
	. = ..()
	if(lockup_hack)
		lockup_hack.hack_opening = FALSE

/obj/machinery/door/airlock/security/prison_staff/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	if(!density || hasPower() || isnull(tool))
		return
	note_hack(user, tool)
	return ..()

/obj/machinery/door/airlock/security/prison_staff/crowbar_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return
	if(!density)
		return ITEM_INTERACT_BLOCKING
	if(!hasPower() && !locked && !welded)
		return ..()
	if(!lockup_hack || lockup_hack.forcing || !lockup_hack.still_forceable())
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(lockup_hack, TYPE_PROC_REF(/datum/lockup_door_state, force_door), user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/door/airlock/security/prison_staff/open(forced = DEFAULT_DOOR_CHECKS)
	if(!density)
		return TRUE
	var/hacked = !rioter_broken && !!lockup_hack?.should_open_as_hack(forced)
	var/mob/living/culprit = hacked ? lockup_hack.open_culprit() : null
	var/obj/item/tool = culprit ? lockup_hack.open_tool() : null
	var/old_autoclose = autoclose
	var/old_breached = lockup_hack?.breached_open
	if(hacked || rioter_broken)
		autoclose = FALSE
		if(lockup_hack)
			lockup_hack.breached_open = TRUE
	. = ..()
	if(!.)
		if(hacked && !rioter_broken)
			autoclose = old_autoclose
			if(lockup_hack)
				lockup_hack.breached_open = old_breached
		return
	if(!QDELETED(src))
		if(hacked)
			door_hacked_open(culprit, tool)
		else if(rioter_broken)
			get_outpost_prison(src)?.refresh_reach()

/obj/machinery/door/airlock/security/prison_staff/try_to_force_door_open(force_type = DEFAULT_DOOR_CHECKS)
	if(rioter_broken || lockup_hack?.hack_opening)
		return ..(BYPASS_DOOR_CHECKS)
	return ..()

/obj/machinery/door/airlock/security/prison_staff/close(forced = DEFAULT_DOOR_CHECKS, force_crush = FALSE)
	if(rioter_broken && !lockup_hack?.mending)
		return FALSE
	. = ..()
	if(. && !QDELETED(src) && density)
		var/was_breached = !!lockup_hack?.breached_open
		if(lockup_hack)
			lockup_hack.breached_open = FALSE
		if(was_breached)
			get_outpost_prison(src)?.refresh_reach()

/**
 * Rioter blows accumulate on `rioter_damage` rather than `atom_integrity` (which on an airlock cuts
 * all wires at 25%). At `max_integrity` the door swings open, stays open, and mends on the O8 timer.
 */
/obj/machinery/door/airlock/security/prison_staff/proc/take_rioter_damage(damage, attack_dir)
	play_attack_sound(damage)
	rioter_damage = min(max_integrity, rioter_damage + damage)
	if(!rioter_broken && rioter_damage >= max_integrity)
		rioter_broken = TRUE
		autoclose = FALSE
		if(lockup_hack)
			lockup_hack.breached_open = TRUE
		visible_message(span_danger("[src] gives way!"))
		note_hack(null)
		INVOKE_ASYNC(src, PROC_REF(open_battered))
		return TRUE
	return FALSE

/obj/machinery/door/airlock/security/prison_staff/proc/open_battered()
	if(QDELETED(src))
		return
	autoclose = FALSE
	if(locked)
		unbolt()
	if(density && !open(FORCING_DOOR_CHECKS) && !QDELETED(src) && density)
		open(BYPASS_DOOR_CHECKS)
	if(!QDELETED(src))
		get_outpost_prison(src)?.refresh_reach()

/obj/machinery/door/airlock/security/prison_staff/examine(mob/user)
	. = ..()
	if(rioter_damage > 0 && max_integrity)
		var/percent = max(0, max_integrity - rioter_damage) / max_integrity * 100
		if(percent >= 50)
			. += "It looks slightly damaged."
		else if(percent >= 25)
			. += "It appears heavily damaged."
		else
			. += span_warning("It's falling apart!")

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

// Open or closed, a prisoner in custody cannot walk through on their own unless the door has been breached. A member
// of the wing may drag one through who is down or cuffed; nobody else may. A loose prisoner is out already.
/obj/machinery/door/airlock/security/prison_staff/CanAllowThrough(atom/movable/mover, border_dir)
	if(is_outpost_prisoner(mover) && !outpost_prisoner_loose(mover) && !outpost_prisoner_escorted(src, mover) && !lets_prisoner(mover))
		return FALSE
	return ..()

/// Whether this door lets a prisoner in custody walk through on their own: when breached, leaving from the staff side, or for Processing's subject.
/obj/machinery/door/airlock/security/prison_staff/proc/lets_prisoner(atom/movable/mover)
	return (lockup_breached() && (!density || rioter_broken)) || lets_leaving_prisoner(mover)

// Their own AI never paths through, dragged or not, until they are loose or the door lets them through.
/obj/machinery/door/airlock/security/prison_staff/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	var/atom/requester = pass_info?.requester_ref?.resolve()
	if(is_outpost_prisoner(requester) && !outpost_prisoner_loose(requester))
		if(lets_leaving_prisoner(requester))
			return ..()
		return (!density || rioter_broken) && lets_prisoner(requester)
	if(density && !may_use_outpost_prison_staff_door(src, requester))
		return FALSE
	return ..()

/// Whether `thing` is a loose prisoner: out of the cell block and on the run
/proc/outpost_prisoner_loose(atom/thing)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = thing
	return istype(prisoner) && prisoner.trouble == PRISONER_TROUBLE_LOOSE

/obj/machinery/door/airlock/security/prison_staff/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

// ===== CELLS =====

/// A cell's front door. Prisoners come and go through it unless its bolt button bolts it; hackable and self-mending (O8).
/obj/machinery/door/airlock/security/glass/outpost_prison_cell
	name = "cell door"
	security_level = 0 // AIRLOCK_SECURITY_NONE (airlock.dm undefines it)
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	/// Which cell this door closes, set on the map
	var/cell_number = 0
	/// Shared hacking, forcing and self-repair state
	var/datum/lockup_door_state/lockup_hack
	/// Whether a self-repair timer is running
	var/mend_pending = FALSE
	/// world.time the first scheduled mend is due, or 0
	var/mend_due = 0
	/// Set while bolted from the cell's bolt button, so self-repair keeps lockdown bolts down
	var/staff_bolted = FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/Initialize(mapload)
	lockup_hack = new(src)
	. = ..()
	AddElement(/datum/element/outpost_property)
	if(cell_number)
		name = "Cell [cell_number]"

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/Destroy()
	QDEL_NULL(lockup_hack)
	return ..()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/get_wires()
	return new /datum/wires/airlock/security/outpost_lockup(src)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/canAIControl(mob/user)
	return FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/canAIHack()
	return FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/lockup_breached()
	return !!lockup_hack?.breached_open

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/note_hack(mob/living/who, obj/item/tool = null)
	lockup_hack?.note_hack(who, tool)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/door_hacked_open(mob/living/culprit, obj/item/tool = null)
	lockup_hack?.door_hacked_open(culprit, tool)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/doorway_occupied()
	return !!lockup_hack?.doorway_occupied()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/still_hacked()
	return !!lockup_hack?.still_hacked()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/mend_hack()
	lockup_hack?.mend_hack()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/proc/mend_emag()
	if(QDELETED(src) || !(obj_flags & EMAGGED))
		return
	mend_hack()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/should_try_removing_electronics()
	return FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/try_reinforce(mob/user, obj/item/stack/sheet/material, amt_required, new_security_level)
	return FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/outpost_hackable(obj/item/tool)
	return tool?.tool_behaviour == TOOL_SCREWDRIVER || tool?.tool_behaviour == TOOL_WIRECUTTER

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/outpost_forceable()
	return TRUE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/screwdriver_act(mob/living/user, obj/item/tool)
	. = ..()
	note_hack(user, tool)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(!istype(emag_card, /obj/item/card/emag/doorjack))
		return FALSE
	. = ..()
	if(.)
		note_hack(user, emag_card)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/finish_emag_act()
	if(locked)
		unbolt()
	if(lockup_hack)
		lockup_hack.hack_opening = TRUE
	. = ..()
	if(lockup_hack)
		lockup_hack.hack_opening = FALSE

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/try_to_crowbar(obj/item/tool, mob/living/user, forced = FALSE)
	if(!density || hasPower() || isnull(tool))
		return
	note_hack(user, tool)
	return ..()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/crowbar_act(mob/living/user, obj/item/tool)
	if(user.combat_mode)
		return
	if(!density)
		return ITEM_INTERACT_BLOCKING
	if(!hasPower() && !locked && !welded)
		return ..()
	if(!lockup_hack || lockup_hack.forcing || !lockup_hack.still_forceable())
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(lockup_hack, TYPE_PROC_REF(/datum/lockup_door_state, force_door), user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/open(forced = DEFAULT_DOOR_CHECKS)
	if(!density)
		return TRUE
	var/hacked = !!lockup_hack?.should_open_as_hack(forced)
	var/mob/living/culprit = hacked ? lockup_hack.open_culprit() : null
	var/obj/item/tool = culprit ? lockup_hack.open_tool() : null
	var/old_autoclose = autoclose
	var/old_breached = lockup_hack?.breached_open
	if(hacked)
		autoclose = FALSE
		if(lockup_hack)
			lockup_hack.breached_open = TRUE
	. = ..()
	if(!.)
		if(hacked)
			autoclose = old_autoclose
			if(lockup_hack)
				lockup_hack.breached_open = old_breached
		return
	if(hacked && !QDELETED(src))
		door_hacked_open(culprit, tool)

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/try_to_force_door_open(force_type = DEFAULT_DOOR_CHECKS)
	if(lockup_hack?.hack_opening)
		return ..(BYPASS_DOOR_CHECKS)
	return ..()

/obj/machinery/door/airlock/security/glass/outpost_prison_cell/close(forced = DEFAULT_DOOR_CHECKS, force_crush = FALSE)
	. = ..()
	if(. && !QDELETED(src) && density)
		var/was_breached = !!lockup_hack?.breached_open
		if(lockup_hack)
			lockup_hack.breached_open = FALSE
		if(was_breached)
			get_outpost_prison(src)?.refresh_reach()

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

/obj/machinery/button/outpost_prison_bolt/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

// Members of the wing only, whether or not visitors are let in.
/obj/machinery/button/outpost_prison_bolt/allowed(mob/accessor)
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	if(prison && !isAdminGhostAI(accessor) && !prison.is_staff(accessor))
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
