/**
 * # Trader outpost weapons checkpoint
 *
 * Every way into a trader outpost's interior runs through a scan chamber: a small room between an
 * outer door (the lobby or the exterior) and an inner door (the concourse).
 *
 * - Only one of the two doors is ever open. The outer door opens for anyone while the inner door is
 *   shut; when it closes on people, or someone in the chamber walks into the inner door, the chamber
 *   scans everything on its floor: every person and everything they carry (bags, pockets, implants
 *   and organs included), plus whatever lies loose. Contraband-shielded storage (a smuggler's satchel)
 *   still hides what is inside it.
 * - Clean (or carried by someone holding a weapons permit, see outpost_trespass.dm): the inner door
 *   opens for a few seconds. Not clean, or anyone in there barred by the outpost: the inner door stays
 *   shut, the guard says so, and the outer door opens to let them back out. Loose contraband is put
 *   back out at once; anyone refused twice in a row is walked out.
 * - Someone on the concourse side can walk into the inner door to cycle the chamber outward the same
 *   way (the exterior hatches need that; the lobby checkpoints have a one-way exit gate as well).
 * - The inner door can be pried open with a crowbar or jaws of life, or hacked with an emag. It takes
 *   OUTPOST_CHECKPOINT_FORCE_TIME and raises the alarm; anyone who then goes through it from the
 *   chamber is flagged as an armed trespasser (outpost_trespass.dm).
 *
 * The parts are mapped (doors, a scan arch on every chamber tile, the exit gate and lockers) and tied
 * together by checkpoint_id when the outpost links its interior (build_checkpoints()). Nothing is
 * stored on the doors between cycles: permission to open is handed to one open() call at a time.
 * Tiles of the chamber, its doors, the lobby and the exit gate belong to
 * /area/voidcrew/trader_outpost/checkpoint, which is outside the checkpoint as far as the outpost's
 * armed-trespass rules are concerned.
 */

/// The checkpoint lobby, scan chambers and exterior hatches: outpost ground that is not past the checkpoint
/area/voidcrew/trader_outpost/checkpoint
	name = "\improper Outpost Checkpoint"

/// Where a trader concourse puts its public network pad (outpost_network.dm). The tile beside it is the arrival spot.
/obj/effect/landmark/outpost_network_pad_spot
	name = "outpost network pad spot"

/// Whether `thing` is something the checkpoint stops at the door
/proc/outpost_checkpoint_weapon(atom/movable/thing)
	return is_ladder_combat_gun(thing?.type) || istype(thing, /obj/item/mecha_parts/mecha_equipment/weapon)

/// The living person carrying `thing` anywhere on them (hands, bags, pockets, implants), or null when nobody is
/proc/outpost_weapon_carrier(atom/movable/thing)
	var/atom/location = thing?.loc
	while(location && !isturf(location))
		if(isliving(location))
			return location
		location = location.loc
	return null

// =========================================================================
// THE CHECKPOINT
// =========================================================================

/datum/outpost_checkpoint
	/// The id the mapped parts share
	var/checkpoint_id
	/// The outpost that built this checkpoint
	var/obj/structure/overmap/trader_outpost/outpost
	/// Opens onto the lobby or the exterior
	var/obj/machinery/door/airlock/outpost/checkpoint/outer/outer_door
	/// Opens onto the concourse
	var/obj/machinery/door/airlock/outpost/checkpoint/inner/inner_door
	/// The chamber: every tile with a linked scan arch
	var/list/turf/chamber_turfs = list()
	/// The scan arches, one per chamber tile
	var/list/obj/machinery/outpost_checkpoint_scanner/scanners = list()
	/// The tile in front of the outer door, outside the chamber
	var/turf/lobby_turf
	/// The tile beyond the inner door, on the concourse
	var/turf/secured_turf
	/// The guard at the desk, if this checkpoint has one
	var/mob/living/basic/outpost_trader/checkpoint_guard/guard
	/// CHECKPOINT_IDLE, _SCANNING, _PASSING, _REJECTING or _FORCED
	var/state = CHECKPOINT_IDLE
	/// The timer ending the current state
	var/phase_timer
	/// Whoever (or whatever) the last scan refused and has not left the chamber yet
	var/list/datum/weakref/last_refused = list()
	/// Someone is prying or hacking the inner door right now
	var/forcing = FALSE
	/// Scan as soon as the outer door has closed (someone asked to go through)
	var/scan_when_closed = FALSE
	/// The current cycle was asked for from the concourse side
	var/exit_request = FALSE
	COOLDOWN_DECLARE(line_cooldown)

/datum/outpost_checkpoint/New(obj/structure/overmap/trader_outpost/outpost, checkpoint_id)
	. = ..()
	src.outpost = outpost
	src.checkpoint_id = checkpoint_id

/datum/outpost_checkpoint/Destroy()
	deltimer(phase_timer)
	phase_timer = null
	if(outpost?.checkpoints[checkpoint_id] == src)
		outpost.checkpoints -= checkpoint_id
	if(outer_door?.checkpoint == src)
		outer_door.checkpoint = null
	if(inner_door?.checkpoint == src)
		inner_door.set_breached(FALSE)
		inner_door.checkpoint = null
	for(var/obj/machinery/outpost_checkpoint_scanner/scanner as anything in scanners)
		if(scanner.checkpoint == src)
			scanner.checkpoint = null
	if(guard?.checkpoint == src)
		guard.checkpoint = null
	outer_door = null
	inner_door = null
	guard = null
	outpost = null
	lobby_turf = null
	secured_turf = null
	scanners.Cut()
	chamber_turfs.Cut()
	last_refused.Cut()
	return ..()

/**
 * Ties the mapped parts together. Fails (and logs) unless there is exactly one outer and one inner
 * door, each touching the chamber on one side and open floor on the other.
 */
/datum/outpost_checkpoint/proc/assemble(list/doors, list/arches)
	for(var/obj/machinery/door/airlock/outpost/checkpoint/door as anything in doors)
		if(istype(door, /obj/machinery/door/airlock/outpost/checkpoint/outer))
			if(outer_door)
				return fail_assembly("two outer doors")
			outer_door = door
		else if(istype(door, /obj/machinery/door/airlock/outpost/checkpoint/inner))
			if(inner_door)
				return fail_assembly("two inner doors")
			inner_door = door
	if(!outer_door || !inner_door)
		return fail_assembly("a missing door")
	for(var/obj/machinery/outpost_checkpoint_scanner/scanner as anything in arches)
		scanners += scanner
		chamber_turfs |= get_turf(scanner)
	if(!length(chamber_turfs))
		return fail_assembly("no scan arches")
	lobby_turf = door_far_side(outer_door)
	secured_turf = door_far_side(inner_door)
	if(!isopenturf(lobby_turf) || !isopenturf(secured_turf))
		return fail_assembly("a door that does not lead from the chamber to open floor")
	outer_door.checkpoint = src
	inner_door.checkpoint = src
	for(var/obj/machinery/outpost_checkpoint_scanner/scanner as anything in scanners)
		scanner.checkpoint = src
	return TRUE

/datum/outpost_checkpoint/proc/fail_assembly(problem)
	log_mapping("OUTPOST CHECKPOINT: [outpost?.name] checkpoint '[checkpoint_id]' has [problem]; it is not linked.")
	outer_door = null
	inner_door = null
	scanners.Cut()
	chamber_turfs.Cut()
	return FALSE

/// The tile across `door` from the chamber, or null when the door does not touch the chamber on exactly one side
/datum/outpost_checkpoint/proc/door_far_side(obj/machinery/door/door)
	var/turf/door_turf = get_turf(door)
	var/turf/far_side
	for(var/direction in GLOB.cardinals)
		if(!(get_step(door_turf, direction) in chamber_turfs))
			continue
		if(far_side)
			return null
		far_side = get_step(door_turf, REVERSE_DIR(direction))
	return far_side

// ----- who and what is in there -----

/// Things on the chamber floor the scan looks at
/datum/outpost_checkpoint/proc/scannable(atom/movable/thing)
	if(iseffect(thing) || isobserver(thing) || thing.invisibility >= INVISIBILITY_ABSTRACT)
		return FALSE
	return !istype(thing, /obj/machinery/outpost_checkpoint_scanner)

/// Every living thing in the chamber, including anyone inside a mech, a locker or a bag in there
/datum/outpost_checkpoint/proc/chamber_people()
	. = list()
	for(var/turf/tile as anything in chamber_turfs)
		for(var/atom/movable/thing as anything in tile)
			if(!scannable(thing))
				continue
			for(var/mob/living/person in thing.get_all_contents())
				. |= person

/// Whether a player is among `people` (the guard only talks to players)
/datum/outpost_checkpoint/proc/includes_player(list/people)
	for(var/mob/living/person as anything in people)
		if(person.client)
			return TRUE
	return FALSE

/**
 * What the scan refuses: chamber atom -> CHECKPOINT_LINE_ARMED or CHECKPOINT_LINE_BARRED. A weapon
 * passes when the person carrying it holds a valid permit; anything loose on the floor never does.
 */
/datum/outpost_checkpoint/proc/inspect_chamber()
	var/list/refused = list()
	for(var/turf/tile as anything in chamber_turfs)
		for(var/atom/movable/thing as anything in tile)
			if(!scannable(thing))
				continue
			for(var/atom/movable/content as anything in thing.get_all_contents_skipping_traits(TRAIT_CONTRABAND_BLOCKER))
				if(isliving(content))
					var/mob/living/person = content
					if(person.mind && outpost?.is_user_barred(person))
						refused[thing] = CHECKPOINT_LINE_BARRED
				else if(outpost_checkpoint_weapon(content) && !refused[thing])
					var/mob/living/carrier = outpost_weapon_carrier(content)
					if(!carrier || !outpost?.has_weapons_permit(carrier))
						refused[thing] = CHECKPOINT_LINE_ARMED
	return refused

// ----- speech and show -----

/datum/outpost_checkpoint/proc/set_scanlines(scanline, duration)
	for(var/obj/machinery/outpost_checkpoint_scanner/scanner as anything in scanners)
		scanner.set_scanline(scanline, duration)

/// The checkpoint's voice: the guard if there is one, else the first scan arch
/datum/outpost_checkpoint/proc/announce(category, urgent = FALSE)
	if(!urgent && !COOLDOWN_FINISHED(src, line_cooldown))
		return
	COOLDOWN_START(src, line_cooldown, OUTPOST_CHECKPOINT_LINE_COOLDOWN)
	if(!QDELETED(guard) && guard.shop)
		var/line = guard.shop.get_line(category)
		if(line)
			INVOKE_ASYNC(guard, TYPE_PROC_REF(/atom/movable, say), line)
		return
	var/obj/machinery/outpost_checkpoint_scanner/scanner = length(scanners) ? scanners[1] : null
	var/line = scanner?.machine_line(category)
	if(line)
		INVOKE_ASYNC(scanner, TYPE_PROC_REF(/atom/movable, say), line)

/datum/outpost_checkpoint/proc/sound_at_chamber(sound_file, volume = 40)
	var/turf/middle = length(chamber_turfs) ? chamber_turfs[1] : null
	if(middle)
		playsound(middle, sound_file, volume, FALSE)

// ----- doors -----

/// Hands `door` permission for exactly one opening
/datum/outpost_checkpoint/proc/open_door(obj/machinery/door/airlock/outpost/checkpoint/door)
	if(QDELETED(door) || !door.density)
		return
	door.opening_permitted = TRUE
	INVOKE_ASYNC(door, TYPE_PROC_REF(/obj/machinery/door, open))

/// Moves anyone standing (or lying) in `door`'s doorway out of it, onto the side they came from
/datum/outpost_checkpoint/proc/clear_doorway(obj/machinery/door/airlock/outpost/checkpoint/door)
	var/turf/push_to = (door == outer_door) ? lobby_turf : secured_turf
	if(!push_to)
		return
	for(var/atom/movable/blocker in get_turf(door))
		if(blocker == door || blocker.anchored || iseffect(blocker))
			continue
		if(isliving(blocker) || blocker.density)
			blocker.forceMove(push_to)

/// Closes `door`, clearing its doorway first, and keeps trying until it is shut
/datum/outpost_checkpoint/proc/close_door(obj/machinery/door/airlock/outpost/checkpoint/door)
	if(QDELETED(door) || QDELETED(src))
		return
	if(door.density)
		on_door_closed(door)
		return
	clear_doorway(door)
	INVOKE_ASYNC(src, PROC_REF(finish_close), door)

/datum/outpost_checkpoint/proc/finish_close(obj/machinery/door/airlock/outpost/checkpoint/door)
	var/closed = door.close(FORCING_DOOR_CHECKS)
	if(QDELETED(src) || QDELETED(door))
		return
	if(closed && door.density)
		on_door_closed(door)
	else
		addtimer(CALLBACK(src, PROC_REF(close_door), door), 1 SECONDS, TIMER_DELETE_ME)

/datum/outpost_checkpoint/proc/on_door_closed(obj/machinery/door/airlock/outpost/checkpoint/door)
	if(door == inner_door)
		inner_door.set_breached(FALSE)
		if(state == CHECKPOINT_PASSING || state == CHECKPOINT_FORCED)
			set_state(CHECKPOINT_IDLE)
		return
	// The outer door
	switch(state)
		if(CHECKPOINT_FORCED)
			return
		if(CHECKPOINT_IDLE, CHECKPOINT_REJECTING)
			set_state(CHECKPOINT_IDLE)
			var/requested = scan_when_closed
			scan_when_closed = FALSE
			if(requested || length(chamber_people()))
				start_scan()

/datum/outpost_checkpoint/proc/set_state(new_state)
	state = new_state
	deltimer(phase_timer)
	phase_timer = null
	if(new_state == CHECKPOINT_IDLE)
		exit_request = FALSE
		set_scanlines("passive")

// ----- what people do to it -----

/// Someone walks into or clicks the outer door. Returns TRUE if it opens.
/datum/outpost_checkpoint/proc/request_outer(mob/user)
	if(QDELETED(outer_door) || QDELETED(inner_door) || outer_door.operating)
		return FALSE
	if(!outer_door.density)
		// A click on the open door shuts it, which starts the scan if anyone is inside
		if(state == CHECKPOINT_IDLE || state == CHECKPOINT_REJECTING)
			deltimer(phase_timer)
			phase_timer = null
			close_door(outer_door)
		return FALSE
	switch(state)
		if(CHECKPOINT_IDLE)
			if(!inner_door.density || inner_door.operating)
				return FALSE
			open_door(outer_door)
			phase_timer = addtimer(CALLBACK(src, PROC_REF(close_door), outer_door), OUTPOST_CHECKPOINT_OUTER_HOLD, TIMER_STOPPABLE | TIMER_DELETE_ME)
			return TRUE
		if(CHECKPOINT_FORCED)
			// The alarm is up and the interlock with it: anyone may follow through
			open_door(outer_door)
			return TRUE
	return FALSE

/// Someone walks into or clicks the inner door: cycle the chamber. Returns TRUE if a scan starts.
/datum/outpost_checkpoint/proc/request_cycle(mob/user)
	if(QDELETED(outer_door) || QDELETED(inner_door) || forcing || state != CHECKPOINT_IDLE)
		return FALSE
	if(!inner_door.density || inner_door.operating || outer_door.operating)
		return FALSE
	exit_request = !(get_turf(user) in chamber_turfs)
	// A guarded checkpoint has its own way out (the exit gate); only the exterior hatches cycle outward
	if(exit_request && guard)
		return FALSE
	if(!outer_door.density)
		scan_when_closed = TRUE
		deltimer(phase_timer)
		phase_timer = null
		close_door(outer_door)
		return TRUE
	start_scan()
	return TRUE

/datum/outpost_checkpoint/proc/start_scan()
	set_state(CHECKPOINT_SCANNING)
	set_scanlines("scanning")
	sound_at_chamber('sound/machines/scanner/scanner.ogg', 30)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(finish_scan)), OUTPOST_CHECKPOINT_SCAN_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/outpost_checkpoint/proc/finish_scan()
	phase_timer = null
	if(state != CHECKPOINT_SCANNING)
		return
	// Something opened mid-scan: nothing to decide about
	if(!outer_door.density || !inner_door.density)
		set_state(CHECKPOINT_IDLE)
		return
	var/list/refused = inspect_chamber()
	var/list/people = chamber_people()
	if(!length(refused))
		last_refused.Cut()
		if(length(people) || exit_request)
			pass(people)
		else
			set_state(CHECKPOINT_IDLE)
		return
	var/list/refused_before = list()
	for(var/datum/weakref/ref as anything in last_refused)
		var/atom/movable/thing = ref.resolve()
		if(thing)
			refused_before += thing
	last_refused.Cut()
	var/barred = FALSE
	for(var/atom/movable/thing as anything in refused)
		if(refused[thing] == CHECKPOINT_LINE_BARRED)
			barred = TRUE
		var/holds_someone = isliving(thing) || length(thing.get_all_contents_type(/mob/living))
		// Loose contraband goes straight back out; a person gets one warning first
		if(!forcing && (!holds_someone || (thing in refused_before)))
			eject(thing)
		else
			last_refused += WEAKREF(thing)
	reject(barred, people)

/// Puts `thing` back on the lobby side of the outer door
/datum/outpost_checkpoint/proc/eject(atom/movable/thing)
	if(!lobby_turf || QDELETED(thing))
		return
	thing.forceMove(lobby_turf)
	if(isliving(thing))
		to_chat(thing, span_warning("You are steered back out of [outer_door]."))

/datum/outpost_checkpoint/proc/pass(list/people)
	set_state(CHECKPOINT_PASSING)
	set_scanlines("passive")
	sound_at_chamber('sound/machines/ping.ogg', 30)
	if(includes_player(people))
		announce(CHECKPOINT_LINE_PASS)
	open_door(inner_door)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(close_door), inner_door), OUTPOST_CHECKPOINT_PASS_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/outpost_checkpoint/proc/reject(barred, list/people)
	set_state(CHECKPOINT_REJECTING)
	set_scanlines("alarm")
	sound_at_chamber('sound/machines/scanner/scanbuzz.ogg', 40)
	if(includes_player(people))
		announce(barred ? CHECKPOINT_LINE_BARRED : CHECKPOINT_LINE_ARMED, urgent = TRUE)
	open_door(outer_door)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(end_reject)), OUTPOST_CHECKPOINT_REJECT_HOLD, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/outpost_checkpoint/proc/end_reject()
	phase_timer = null
	if(state != CHECKPOINT_REJECTING)
		return
	// Nobody is walked out from under someone working on the inner door
	if(forcing)
		phase_timer = addtimer(CALLBACK(src, PROC_REF(end_reject)), 2 SECONDS, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	close_door(outer_door)

// ----- forcing the inner door -----

/// `user` starts prying or hacking the inner door. Sleeps for the whole attempt; TRUE if it gave.
/datum/outpost_checkpoint/proc/force_inner(mob/living/user, obj/item/tool)
	if(forcing || state == CHECKPOINT_FORCED || QDELETED(inner_door) || !inner_door.density)
		return FALSE
	forcing = TRUE
	set_scanlines("alarm")
	playsound(inner_door, 'sound/machines/warning-buzzer.ogg', 60, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	announce(CHECKPOINT_LINE_FORCING, urgent = TRUE)
	log_game("OUTPOST CHECKPOINT: [key_name(user)] started forcing [inner_door] at [AREACOORD(inner_door)] with [tool].")
	var/succeeded = do_after(user, OUTPOST_CHECKPOINT_FORCE_TIME, target = inner_door, extra_checks = CALLBACK(src, PROC_REF(still_forceable)))
	if(QDELETED(src))
		return FALSE
	forcing = FALSE
	if(!succeeded)
		if(state == CHECKPOINT_IDLE)
			set_scanlines("passive")
		return FALSE
	breach(user)
	return TRUE

/datum/outpost_checkpoint/proc/still_forceable()
	return !QDELETED(inner_door) && inner_door.density && state != CHECKPOINT_FORCED

/// The inner door gives: it stays open for a while, and anyone going through it from the chamber is flagged
/datum/outpost_checkpoint/proc/breach(mob/living/user)
	log_game("OUTPOST CHECKPOINT: [key_name(user)] forced [inner_door] at [AREACOORD(inner_door)].")
	set_state(CHECKPOINT_FORCED)
	set_scanlines("alarm", OUTPOST_CHECKPOINT_FORCED_OPEN_TIME)
	playsound(inner_door, 'sound/machines/warning-buzzer.ogg', 70, FALSE, MEDIUM_RANGE_SOUND_EXTRARANGE)
	inner_door.set_breached(TRUE)
	open_door(inner_door)
	phase_timer = addtimer(CALLBACK(src, PROC_REF(end_breach)), OUTPOST_CHECKPOINT_FORCED_OPEN_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/outpost_checkpoint/proc/end_breach()
	phase_timer = null
	if(!QDELETED(outer_door) && !outer_door.density)
		close_door(outer_door)
	close_door(inner_door)

/// Someone stepped into the forced inner doorway
/datum/outpost_checkpoint/proc/on_breach_entry(atom/movable/arrived, atom/old_loc)
	if(state != CHECKPOINT_FORCED || !outpost)
		return
	var/turf/came_from = get_turf(old_loc)
	if(came_from && !(came_from in chamber_turfs))
		return // from the concourse side: already inside
	var/flagged = FALSE
	for(var/mob/living/person in arrived.get_all_contents())
		if(person.mind && outpost.flag_trespasser(person))
			flagged = TRUE
	if(flagged)
		announce(CHECKPOINT_LINE_INTRUDER, urgent = TRUE)

// =========================================================================
// THE DOORS
// =========================================================================

/**
 * A checkpoint door. Its ordinary opening routes (bumps, clicks, ID swipes, wires, silicons, magic,
 * prying) never open it; only its checkpoint does, one open() call at a time.
 */
/obj/machinery/door/airlock/outpost/checkpoint
	name = "checkpoint door"
	desc = "An armored checkpoint door."
	move_resist = INFINITY
	autoclose = FALSE
	/// Shared with the chamber's scan arches and (for the lobby checkpoints) the guard
	var/checkpoint_id
	/// The checkpoint this door belongs to (set when the outpost links its interior)
	var/datum/outpost_checkpoint/checkpoint
	/// Permission for the next open() call only
	var/opening_permitted = FALSE

/obj/machinery/door/airlock/outpost/checkpoint/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/airlock/outpost/checkpoint/Destroy()
	if(checkpoint)
		qdel(checkpoint)
		checkpoint = null
	return ..()

/obj/machinery/door/airlock/outpost/checkpoint/open(forced = DEFAULT_DOOR_CHECKS)
	if(!density)
		return TRUE
	if(!opening_permitted)
		return FALSE
	opening_permitted = FALSE
	return ..(BYPASS_DOOR_CHECKS)

// A body arriving in the doorway during the close is moved off it, not let back through
/obj/machinery/door/airlock/outpost/checkpoint/CheckForMobs()
	if(checkpoint)
		checkpoint.clear_doorway(src)

/obj/machinery/door/airlock/outpost/checkpoint/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/// The lobby (or exterior) side of a scan chamber
/obj/machinery/door/airlock/outpost/checkpoint/outer

/obj/machinery/door/airlock/outpost/checkpoint/outer/bumpopen(mob/user)
	if(operating || !density)
		return
	if(!checkpoint?.request_outer(user))
		run_animation(DOOR_DENY_ANIMATION)

/obj/machinery/door/airlock/outpost/checkpoint/outer/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	add_fingerprint(user)
	if(operating)
		return
	if(!checkpoint?.request_outer(user) && density)
		run_animation(DOOR_DENY_ANIMATION)

/// The concourse side of a scan chamber. Walking into it asks for a scan; prying or hacking it forces it.
/obj/machinery/door/airlock/outpost/checkpoint/inner
	/// Watching the doorway for anyone coming through while it is forced
	var/breached = FALSE

/obj/machinery/door/airlock/outpost/checkpoint/inner/Destroy()
	set_breached(FALSE)
	return ..()

/obj/machinery/door/airlock/outpost/checkpoint/inner/bumpopen(mob/user)
	if(operating || !density)
		return
	if(!checkpoint?.request_cycle(user))
		run_animation(DOOR_DENY_ANIMATION)

/obj/machinery/door/airlock/outpost/checkpoint/inner/try_to_activate_door(mob/living/user, access_bypass = FALSE)
	add_fingerprint(user)
	if(operating || !density)
		return
	if(!checkpoint?.request_cycle(user))
		run_animation(DOOR_DENY_ANIMATION)

// Outpost property lets a crowbar through to this one door (see /datum/element/outpost_property)
/obj/machinery/door/airlock/outpost/checkpoint/inner/outpost_forceable()
	return TRUE

// Pathing goes in through a guarded checkpoint and out through its exit gate, never back through the chamber
/obj/machinery/door/airlock/outpost/checkpoint/inner/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	if(checkpoint?.guard && !(get_step(src, to_dir) in checkpoint.chamber_turfs))
		return !density
	return ..()

/obj/machinery/door/airlock/outpost/checkpoint/inner/crowbar_act(mob/living/user, obj/item/tool)
	if(!density || !checkpoint)
		return ITEM_INTERACT_BLOCKING
	if(checkpoint.forcing)
		balloon_alert(user, "already being forced!")
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(checkpoint, TYPE_PROC_REF(/datum/outpost_checkpoint, force_inner), user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/door/airlock/outpost/checkpoint/inner/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(!density || !checkpoint || !isliving(user) || checkpoint.forcing)
		return FALSE
	INVOKE_ASYNC(checkpoint, TYPE_PROC_REF(/datum/outpost_checkpoint, force_inner), user, emag_card)
	return TRUE

/obj/machinery/door/airlock/outpost/checkpoint/inner/proc/set_breached(new_state)
	if(breached == new_state)
		return
	var/turf/doorway = get_turf(src)
	breached = new_state
	if(!doorway)
		return
	if(breached)
		RegisterSignal(doorway, COMSIG_ATOM_ENTERED, PROC_REF(on_doorway_entered))
	else
		UnregisterSignal(doorway, COMSIG_ATOM_ENTERED)

/obj/machinery/door/airlock/outpost/checkpoint/inner/proc/on_doorway_entered(turf/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(arrived == src || iseffect(arrived))
		return
	checkpoint?.on_breach_entry(arrived, old_loc)

// Door looks. Each map uses the style of the doors around its checkpoint.

/obj/machinery/door/airlock/outpost/checkpoint/outer/security
	icon = 'icons/obj/doors/airlocks/station/security.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/checkpoint/inner/security
	icon = 'icons/obj/doors/airlocks/station/security.dmi'
	overlays_file = 'icons/obj/doors/airlocks/station/overlays.dmi'
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/checkpoint/inner/glass
	icon = 'icons/obj/doors/airlocks/public/glass.dmi'
	overlays_file = 'icons/obj/doors/airlocks/public/overlays.dmi'
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/checkpoint/outer/grunge
	icon = 'icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'icons/obj/doors/airlocks/centcom/overlays.dmi'
	can_be_glass = FALSE

/obj/machinery/door/airlock/outpost/checkpoint/inner/grunge
	icon = 'icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'icons/obj/doors/airlocks/centcom/overlays.dmi'
	can_be_glass = FALSE

/// Whether outpost property lets a crowbar get to work on this. Only a checkpoint's inner door says yes.
/obj/proc/outpost_forceable()
	return FALSE

// =========================================================================
// THE SCAN ARCH
// =========================================================================

/// One per chamber tile. Marks the chamber and shows the scan; the checkpoint does the deciding.
/obj/machinery/outpost_checkpoint_scanner
	name = "scan arch"
	desc = "A weapons scanner built into the checkpoint."
	icon = 'icons/obj/machines/scangate.dmi'
	icon_state = "scangate"
	layer = ABOVE_MOB_LAYER
	density = FALSE
	anchored = TRUE
	move_resist = INFINITY
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	interaction_flags_machine = NONE
	/// Shared with the chamber's doors
	var/checkpoint_id
	/// Set when the outpost links its interior
	var/datum/outpost_checkpoint/checkpoint
	/// The light bars
	var/obj/effect/overlay/scanline
	var/scanline_timer

/obj/machinery/outpost_checkpoint_scanner/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	set_scanline("passive")

/obj/machinery/outpost_checkpoint_scanner/Destroy()
	deltimer(scanline_timer)
	QDEL_NULL(scanline)
	if(checkpoint)
		checkpoint.scanners -= src
		checkpoint = null
	return ..()

/obj/machinery/outpost_checkpoint_scanner/setDir(newdir)
	. = ..()
	scanline?.setDir(newdir)

/obj/machinery/outpost_checkpoint_scanner/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/// "passive" (green), "scanning" (blue) or "alarm" (red); back to green after `duration` if given
/obj/machinery/outpost_checkpoint_scanner/proc/set_scanline(scanline_type, duration)
	if(isnull(scanline))
		scanline = new(src)
		scanline.icon = icon
		scanline.mouse_opacity = MOUSE_OPACITY_TRANSPARENT
		scanline.layer = layer
		scanline.setDir(dir)
	vis_contents -= scanline
	deltimer(scanline_timer)
	scanline_timer = null
	scanline.icon_state = scanline_type
	vis_contents += scanline
	if(duration)
		scanline_timer = addtimer(CALLBACK(src, PROC_REF(set_scanline), "passive"), duration, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// What the arch says when there is no guard to say it
/obj/machinery/outpost_checkpoint_scanner/proc/machine_line(category)
	switch(category)
		if(CHECKPOINT_LINE_ARMED)
			return "Weapon detected."
		if(CHECKPOINT_LINE_BARRED)
			return "Entry refused."
		if(CHECKPOINT_LINE_FORCING)
			return "Tamper alarm."
		if(CHECKPOINT_LINE_INTRUDER)
			return "Armed intruder."
	return null

// =========================================================================
// THE EXIT GATE
// =========================================================================

/**
 * A one-way light curtain. People and things go through it only in its dir (from the concourse to
 * the lobby); from the other side nothing gets in, not even a thrown gun or a pulled crate. Anyone
 * stepping into it is carried straight out the far side, so nobody stands in it to be handed things.
 */
/obj/structure/outpost_exit_gate
	name = "exit gate"
	desc = "A one-way light curtain."
	icon = 'icons/obj/structures.dmi'
	icon_state = "oneway"
	anchored = TRUE
	density = FALSE
	move_resist = INFINITY
	layer = ABOVE_MOB_LAYER
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	light_range = 1.5
	light_power = 0.8
	light_color = COLOR_BIOLUMINESCENCE_BLUE
	// Not dense, so pathing would skip CanAStarPass() without this
	can_astar_pass = CANASTARPASS_ALWAYS_PROC

/obj/structure/outpost_exit_gate/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/structure/outpost_exit_gate/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(mover.movement_type & PHASING)
		return TRUE
	if(get_turf(mover) == get_turf(src))
		return TRUE
	return REVERSE_DIR(border_dir) == dir

/obj/structure/outpost_exit_gate/CanAStarPass(to_dir, datum/can_pass_info/pass_info)
	return REVERSE_DIR(to_dir) == dir

/obj/structure/outpost_exit_gate/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(isliving(arrived) || istype(arrived, /obj/vehicle))
		addtimer(CALLBACK(src, PROC_REF(carry_through), arrived), 1, TIMER_DELETE_ME)

/obj/structure/outpost_exit_gate/proc/carry_through(atom/movable/passer)
	if(QDELETED(passer) || passer.loc != loc)
		return
	var/turf/out = get_step(src, dir)
	if(!out)
		return
	if(!step(passer, dir) && passer.loc == loc)
		passer.forceMove(out)

// =========================================================================
// THE LOCKERS
// =========================================================================

/// Every checkpoint locker in the world, so a card claims only one per outpost
GLOBAL_LIST_EMPTY(outpost_checkpoint_lockers)

/**
 * A free locker in the checkpoint lobby: swiping an ID while it is shut and unclaimed locks it to that
 * ID. Emptied and shut, it is free again. One per card per outpost. Same armor as the rental stash.
 */
/obj/structure/closet/secure_closet/outpost_rental/checkpoint
	name = "checkpoint locker"
	desc = "A steel locker by the checkpoint, for whatever can't come along."

/obj/structure/closet/secure_closet/outpost_rental/checkpoint/Initialize(mapload)
	. = ..()
	GLOB.outpost_checkpoint_lockers += src

/obj/structure/closet/secure_closet/outpost_rental/checkpoint/Destroy()
	GLOB.outpost_checkpoint_lockers -= src
	return ..()

// The rental stash's fee line does not apply
/obj/structure/closet/secure_closet/outpost_rental/checkpoint/examine(mob/user)
	. = list("[icon2html(src, user)] That's \a [src].", desc)
	if(locked)
		. += span_notice("It's locked.")

/obj/structure/closet/secure_closet/outpost_rental/checkpoint/attackby(obj/item/weapon, mob/living/user, list/modifiers, list/attack_modifiers)
	var/obj/item/card/id/id = weapon.GetID()
	if(isnull(id) || opened || broken)
		return ..()
	if(id_card) // claimed: the lock handles the rest
		togglelock(user)
		return TRUE
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(src))
	for(var/obj/structure/closet/secure_closet/outpost_rental/checkpoint/other as anything in GLOB.outpost_checkpoint_lockers)
		if(other == src || other.id_card?.resolve() != id)
			continue
		if(get_trader_outpost_for_turf(get_turf(other)) == outpost)
			balloon_alert(user, "you have one already!")
			return TRUE
	id_card = WEAKREF(id)
	name = "[id.registered_name]'s locker"
	locked = TRUE
	play_closet_lock_sound()
	balloon_alert(user, "locked to your card")
	update_appearance()
	return TRUE

/obj/structure/closet/secure_closet/outpost_rental/checkpoint/close(mob/living/user)
	. = ..()
	if(!. || !id_card)
		return
	for(var/atom/movable/thing as anything in contents)
		if(!iseffect(thing))
			return
	// Shut empty: free for the next person
	id_card = null
	name = initial(name)
	locked = FALSE
	update_appearance()
