/**
 * Voidcrew Cargo Shuttle System
 * Spawns a cargo shuttle that docks next to the player's ship using ship-to-ship docking
 * Shuttle is ephemeral - created fresh each time, deleted after departure
 */

/**
 * Cargo Shuttle Controller
 * Manages the state machine and docking of the cargo shuttle
 */
/datum/voidcrew_cargo_shuttle
	/// Current state of the cargo shuttle
	var/state = CARGO_SHUTTLE_AWAY
	/// Reference to the shuttle's mobile docking port
	var/obj/docking_port/mobile/shuttle_port
	/// A queued or running template load must return before another dispatch can begin.
	var/load_pending = FALSE
	/// The cargo console this shuttle is linked to (for callbacks)
	var/obj/machinery/computer/voidcrew_cargo/linked_console
	/// Timer ID for warmup periods
	var/warmup_timer
	/// The empty space we're docking to
	var/obj/structure/overmap/planet/empty/docked_at
	/// The turf reservation the shuttle is parked in while "in transit". Held BARE on
	/// this datum on purpose - never wrapped in an /obj/docking_port/stationary/transit.
	/// See the doc comment on spawn_shuttle() for why the dock was fatal.
	var/datum/turf_reservation/transit_reservation
	/// Time when warmup started (for timer display)
	var/warmup_started
	/// world.time past which an unresolved warmup is treated as stalled. 0 when idle or docked.
	var/stall_deadline = 0
	/// Consecutive "encounter still loading" retries complete_arrival() has burned this trip
	var/load_retries = 0
	/// Reference to the player's ship we're docking with
	var/obj/structure/overmap/ship/target_ship
	/// Which reserve dock we're using (1 or 2)
	var/cargo_dock_index = 0
	/// Transaction history - list of lists with keys: type, name, amount, value, time
	var/list/transaction_history = list()
	/// Maximum history entries to keep
	var/max_history = 50
	/// Current pending shuttle loan offer (if any)
	var/datum/voidcrew_shuttle_loan/pending_loan
	/// Whether a loan was accepted and items should spawn on arrival
	var/loan_accepted = FALSE

/**
 * Records a transaction in the history
 */
/datum/voidcrew_cargo_shuttle/proc/record_transaction(type, name, amount, value)
	var/list/entry = list(
		"type" = type,
		"name" = name,
		"amount" = amount,
		"value" = value,
		"time" = station_time_timestamp()
	)
	transaction_history.Insert(1, list(entry)) // Insert at beginning (newest first)
	if(length(transaction_history) > max_history)
		transaction_history.len = max_history

/datum/voidcrew_cargo_shuttle/Destroy()
	cleanup_shuttle()
	linked_console = null
	target_ship = null
	QDEL_NULL(pending_loan)
	return ..()

/**
 * Receives a new shuttle loan offer
 * Returns TRUE if offer was received successfully
 */
/datum/voidcrew_cargo_shuttle/proc/receive_loan_offer(datum/voidcrew_shuttle_loan/loan_type)
	if(pending_loan)
		return FALSE // Already have a pending offer
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE // Shuttle is busy

	pending_loan = new loan_type()
	return TRUE

/**
 * Accepts the current shuttle loan offer
 * Returns TRUE if accepted successfully
 */
/datum/voidcrew_cargo_shuttle/proc/accept_loan()
	if(!pending_loan)
		return FALSE
	if(state != CARGO_SHUTTLE_AWAY)
		return FALSE

	loan_accepted = TRUE

	// Add bonus credits to the linked bank account
	if(linked_console?.bank_account_holder?.synced_bank_account && pending_loan.bonus_credits > 0)
		linked_console.bank_account_holder.synced_bank_account.adjust_money(pending_loan.bonus_credits)
		record_transaction("loan", pending_loan.logging_desc, 1, pending_loan.bonus_credits)

	// Announce acceptance
	if(target_ship)
		target_ship.ship_notify(pending_loan.thanks_msg, "CARGO", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)

	return TRUE

/**
 * Declines/clears the current shuttle loan offer
 */
/datum/voidcrew_cargo_shuttle/proc/decline_loan()
	QDEL_NULL(pending_loan)
	loan_accepted = FALSE

/**
 * Marks one of the encounter's two reserve docks as ours.
 *
 * Claimed when the order is placed rather than on arrival: the dock used to sit unclaimed
 * through the whole warmup, so a ship arriving at this encounter mid-flight could take the
 * berth and the delivery would only discover it at the last moment. Holding the flag turns
 * that into an ordinary "no free dock" refusal for the arriving ship, which every docking
 * path already handles.
 */
/datum/voidcrew_cargo_shuttle/proc/claim_berth(index)
	release_berth()
	if(!docked_at || !index)
		return
	cargo_dock_index = index
	if(index == 1)
		docked_at.first_dock_taken = TRUE
	else if(index == 2)
		docked_at.second_dock_taken = TRUE

/// Hands our reserve dock back. Safe to call when we never claimed one.
/datum/voidcrew_cargo_shuttle/proc/release_berth()
	if(!docked_at || !cargo_dock_index)
		cargo_dock_index = 0
		return
	if(cargo_dock_index == 1)
		docked_at.first_dock_taken = FALSE
	else if(cargo_dock_index == 2)
		docked_at.second_dock_taken = FALSE
	cargo_dock_index = 0

/**
 * Cleans up all shuttle resources (for error states, not normal departure)
 *
 * Forces state back to AWAY, and does it first. This proc used to clear the timer, the
 * deadline and docked_at while leaving state wherever it happened to be - but the helm
 * gates undock on state alone, so a delivery that got cleaned up mid-claim stayed
 * "present" forever. That was the round 7 (2026-08-16) stranding: ten "send" clicks in
 * thirteen seconds raced through spawn_shuttle() on this per-ship singleton, one
 * invocation's cleanup nulled docked_at under another's berth lookup, and the runtime
 * left state parked at ARRIVING with nothing left armed to notice. Every caller that
 * reaches for this proc wants the console back at AWAY; call_shuttle()'s post-spawn
 * check relies on it to catch a spawn that was torn down while it yielded.
 */
/datum/voidcrew_cargo_shuttle/proc/cleanup_shuttle()
	state = CARGO_SHUTTLE_AWAY
	if(warmup_timer)
		deltimer(warmup_timer)
		warmup_timer = null
	warmup_started = null
	stall_deadline = 0
	load_retries = 0

	release_berth()

	// Don't move to transit before destroying - just destroy where it is
	// Moving causes baseturfs accumulation issues
	destroy_shuttle()

	// Restore the freed reserve dock's default geometry - we left it resized and
	// parked right against the player ship's dock
	docked_at?.reset_free_reserve_docks()

	docked_at = null

/**
 * Spawns the cargo shuttle into a bare turf reservation
 * Returns TRUE on success
 *
 * The parking ground is deliberately held on this datum as a naked reservation and NOT
 * wrapped in an /obj/docking_port/stationary/transit. SSshuttle.transit_docking_ports
 * has a contract - "a shuttle is flying through this hyperspace zone" - and SSshuttle's
 * fire() enforces it: once transit_utilized crosses SOFT_TRANSIT_RESERVATION_THRESHOLD
 * (90k tiles, ~31 concurrent ships), every transit dock whose owner is SHUTTLE_IDLE and
 * not physically docked to it is force-qdel'd to reclaim the space. The ferry never
 * docks to a transit port and its mode never leaves SHUTTLE_IDLE, so the dock this proc
 * used to build was always reclaimable by construction: past the threshold the sweep
 * released the reservation mid-warmup, the release emptied every hull turf, and the
 * surviving zero-turf port went on to "dock" with DOCKING_SUCCESS and deliver nothing
 * while the console announced an arrival (round 12, 2026-08-23 - cargo dead fleet-wide
 * for the rest of the round, permanently, since ship count only grows). Nothing ever
 * consumed the dock: the ferry docks straight onto the encounter berth on arrival, and
 * departure destroys it in place (complete_departure()), so the dock's only real job
 * was owning the reservation - which the datum now does directly, out of the sweep's
 * reach. Nothing force-releases a live bare reservation.
 */
/datum/voidcrew_cargo_shuttle/proc/spawn_shuttle()
	if(load_pending)
		return FALSE
	load_pending = TRUE
	. = SSshuttle.run_template_load(CALLBACK(src, PROC_REF(spawn_shuttle_impl)), wait_timeout = CARGO_SHUTTLE_STALL_GRACE)
	load_pending = FALSE

/// A queued ferry must still be wanted when the previous template load finishes.
/datum/voidcrew_cargo_shuttle/proc/spawn_shuttle_impl(datum/shuttle_template_load/load_owner)
	if(QDELETED(src) || state != CARGO_SHUTTLE_ARRIVING)
		return FALSE
	// Always spawn fresh - clean up any existing shuttle first
	if(shuttle_port && !QDELETED(shuttle_port))
		cleanup_shuttle()
		// cleanup_shuttle() just forced the whole datum back to AWAY, watchdog included -
		// but the caller claimed ARRIVING before calling us and the work below yields for
		// seconds. Re-assert the claim and its deadline so the console and helm keep
		// reading this spawn as in-flight, and so a spawn that never returns is recovered.
		state = CARGO_SHUTTLE_ARRIVING
		warmup_started = world.time
		stall_deadline = world.time + CARGO_SHUTTLE_WARMUP + CARGO_SHUTTLE_STALL_GRACE
	shuttle_port = null // Ensure it's null even if QDELETED

	// Use the existing cargo_box template
	var/datum/map_template/shuttle/cargo/box/template = new()

	if(!template.width || !template.height)
		qdel(template)
		return FALSE

	// Space for the shuttle to sit in while it is "in transit". Held as a local, not on a
	// transit port, until there is a port to own it.
	var/datum/turf_reservation/reservation = SSmapping.request_turf_block_reservation(
		template.width + SHUTTLE_TRANSIT_BORDER * 2,
		template.height + SHUTTLE_TRANSIT_BORDER * 2,
		1,
		reservation_type = /datum/turf_reservation/transit,
	)

	if(!reservation)
		qdel(template)
		return FALSE

	// The block we were just granted is recycled ground and can contain docking ports
	// stranded by an earlier tenant: /turf/proc/empty() excludes /obj/docking_port from
	// every reservation sweep, so stale ports survive release. The locate() below adopts
	// the first mobile port it finds, ghost or not (round 12, 2026-08-23: a stranded port
	// hijacked every delivery that landed on its coordinates). Reap them by name first.
	reap_reservation_docking_ports(reservation)

	var/turf/transit_turf = reservation.bottom_left_turfs[1]
	// Offset by border to center shuttle in reservation
	transit_turf = locate(transit_turf.x + SHUTTLE_TRANSIT_BORDER, transit_turf.y + SHUTTLE_TRANSIT_BORDER, transit_turf.z)

	// Load the shuttle template - register = TRUE so shuttle_areas get populated
	template.load(transit_turf, centered = FALSE, register = TRUE)

	// Find the mobile docking port that was loaded
	var/list/affected = template.get_affected_turfs(transit_turf, centered = FALSE)
	for(var/turf/T in affected)
		shuttle_port = locate(/obj/docking_port/mobile) in T
		if(shuttle_port)
			break

	if(!shuttle_port)
		qdel(reservation)
		qdel(template)
		return FALSE

	// The stock supply shuttle map locks both of its airlocks to ACCESS_CARGO - each one
	// carries /obj/effect/mapping_helpers/airlock/access/all/supply/general, which is a
	// station assumption: a quartermaster hands out the card. Here the shuttle docks
	// against a hull whose crew is issued no cargo access at all, so the delivery arrived
	// sealed and the order it was carrying could not be unloaded.
	//
	// The blanket ship waiver in voidcrew/edits/ship_access.dm does not cover this: it is
	// scoped to /area/shuttle/voidcrew, and this template loads into /area/shuttle/supply.
	// Clear the locks on the doors themselves instead. The helpers are `late = TRUE`, so
	// they have already run by the time template.load() returns and this overwrites them.
	for(var/turf/shuttle_turf as anything in affected)
		for(var/obj/machinery/door/shuttle_door in shuttle_turf)
			shuttle_door.req_access = null
			shuttle_door.req_one_access = null

	// Don't let this become SSshuttle.supply
	if(SSshuttle.supply == shuttle_port)
		SSshuttle.supply = null

	// Make shuttle_id unique
	shuttle_port.shuttle_id = "voidcrew_cargo_[REF(src)]"
	shuttle_port.name = "Voidcrew Cargo Shuttle"

	// Take ownership of the parking ground directly - no transit dock, no
	// assigned_transit (see the doc comment above). The only consumer either ever had
	// was the SSshuttle sweep that kept reclaiming us.
	transit_reservation = reservation

	template.post_load(shuttle_port)
	qdel(template)

	return TRUE

/**
 * Returns the cargo bay turf for spawning items
 */
/datum/voidcrew_cargo_shuttle/proc/get_cargo_bay_turf()
	if(!shuttle_port)
		return null

	// Find any open turf in the shuttle area
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/open/floor/T in shuttle_area)
			if(!T.is_blocked_turf())
				return T

	return null

/**
 * Returns all cargo bay turfs for exporting
 */
/datum/voidcrew_cargo_shuttle/proc/get_cargo_bay_turfs()
	var/list/turfs = list()
	if(!shuttle_port)
		log_shuttle("LOAN DEBUG: get_cargo_bay_turfs - shuttle_port is null!")
		return turfs

	var/area_count = 0
	var/turf_count = 0
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		area_count++
		for(var/turf/T in shuttle_area)
			turf_count++
			if(istype(T, /turf/open/floor))
				turfs += T

	log_shuttle("LOAN DEBUG: get_cargo_bay_turfs - areas=[area_count], total_turfs=[turf_count], floor_turfs=[length(turfs)]")
	return turfs

/**
 * Gets remaining warmup time in seconds
 */
/datum/voidcrew_cargo_shuttle/proc/get_remaining_time()
	if(!warmup_started)
		return 0
	var/elapsed = world.time - warmup_started
	var/warmup_duration = (state == CARGO_SHUTTLE_DEPARTING) ? CARGO_SHUTTLE_DEPARTURE_WARMUP : CARGO_SHUTTLE_WARMUP
	var/remaining = max(0, warmup_duration - elapsed)
	return round(remaining / 10) // Convert to seconds

/**
 * Calls the cargo shuttle to dock next to the player's ship.
 *
 * Returns null when the shuttle is on its way, or a crew-facing reason for the refusal -
 * the same contract /obj/structure/overmap/ship/dock() uses. Everything it can refuse for
 * costs the crew a 30-second warmup if it is left to complete_arrival() to discover.
 */
/datum/voidcrew_cargo_shuttle/proc/call_shuttle(obj/structure/overmap/ship/ship)
	if(state != CARGO_SHUTTLE_AWAY || load_pending)
		return "Cargo shuttle is not available"

	if(!istype(ship?.docked, /obj/structure/overmap/planet/empty))
		return "Must be docked in space"

	target_ship = ship
	docked_at = ship.docked

	// The shuttle berths one tile off the ship's own docking port, so any hull built out
	// past that port is exactly where it lands. complete_arrival() checks this again at
	// the berth itself, but the scan walks every hull turf - too heavy for the console's
	// per-tick error message - so placing the order is the first cheap place to catch it.
	if(hull_overhangs_port(ship.shuttle))
		target_ship = null
		docked_at = null
		return "Ship hull extends past its docking port. Move the docking port to the \
			outermost hull door before ordering a delivery"

	// Lock the state before spawn_shuttle() yields for the template load: the console
	// credit-checked the cart already, but buy() charges at dock time, so the cart must
	// read as dispatched from this point on. Failure paths below hand it back to AWAY.
	// The claim cannot wait for the spawn's return. spawn_shuttle() yields for seconds and
	// this datum is a per-ship singleton, so every "send" click landing in that window used
	// to pass the guard above and start a second concurrent spawn on it: round 7
	// (2026-08-16) logged ten calls in thirteen seconds, the interleaved spawns ran
	// cleanup_shuttle() on each other, and the berth lookup below dereferenced the
	// docked_at that cleanup had just nulled. The runtime returned null to the console,
	// which reports null as success - so every failed call was announced as "Cargo shuttle
	// called" while the datum sat parked at ARRIVING and the helm refused to undock.
	// Nothing between the guard and this block yields (hull_overhangs_port() is a pure
	// turf scan), so the guard and the claim are atomic as a pair.
	state = CARGO_SHUTTLE_ARRIVING
	warmup_started = world.time
	// Deliberately the full warmup plus grace, not grace alone, and armed in the same
	// block as the state. spawn_shuttle() below can legitimately run long - a reservation
	// UNTIL() plus a template load - and the console the orderer is staring at polls
	// check_stalled() every ui_data tick. check_stalled() now reads a non-terminal state
	// with no deadline as a stall to recover on sight, so claiming ARRIVING while leaving
	// stall_deadline at 0 would tear down this healthy in-flight delivery at the next
	// tick; a watchdog that merely expired inside the spawn would do the same.
	stall_deadline = world.time + CARGO_SHUTTLE_WARMUP + CARGO_SHUTTLE_STALL_GRACE

	// Spawn shuttle fresh
	if(!spawn_shuttle())
		state = CARGO_SHUTTLE_AWAY
		warmup_started = null
		stall_deadline = 0
		target_ship = null
		docked_at = null
		return "Could not prepare a cargo shuttle"

	// spawn_shuttle() yielded, so the watchdog may have torn the order down while we were
	// inside it - and cleanup_shuttle() now resets state and docked_at on ANY teardown it
	// performs, including the stale-port branch at the top of the spawn. Bail rather than
	// runtime on the null below; the refusal returns the datum to AWAY and consistent.
	if(!docked_at || state != CARGO_SHUTTLE_ARRIVING)
		state = CARGO_SHUTTLE_AWAY
		cleanup_shuttle()
		target_ship = null
		return "Cargo shuttle preparation was interrupted"

	// Claim the berth now and hold it for the whole flight. Re-checked here rather than
	// trusting the console's pre-click check because spawn_shuttle() yields while it
	// loads the template, which is time enough for another ship to arrive.
	var/list/berth = docked_at.get_cargo_berth(ship.shuttle)
	var/berth_error = berth["error"]
	if(berth_error)
		state = CARGO_SHUTTLE_AWAY
		cleanup_shuttle() // tears the fresh shuttle back down; we hold no berth to release
		target_ship = null
		return berth_error
	claim_berth(berth["index"])

	// Start warmup
	warmup_started = world.time
	load_retries = 0
	stall_deadline = world.time + CARGO_SHUTTLE_WARMUP + CARGO_SHUTTLE_STALL_GRACE
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), CARGO_SHUTTLE_WARMUP, TIMER_STOPPABLE)
	return null

/**
 * Recovers a warmup that never resolved.
 *
 * CARGO_SHUTTLE_ARRIVING and CARGO_SHUTTLE_DEPARTING are each driven by exactly one timer
 * callback, and both callbacks can be lost: a runtime unwinds the proc before it sets a
 * state, and complete_arrival() yields inside initiate_docking(), so a stall there never
 * returns to set one either. The datum is then parked in a non-AWAY state permanently -
 * which the helm reads as "cargo shuttle present" and refuses to undock on, stranding the
 * whole ship with no crew-facing way out (round 837, 2026-08-04, cleared by an admin
 * deleting the datum by hand).
 *
 * Deliberately polled from the two UIs that gate on the state rather than armed as a
 * second timer: the failure mode being covered IS a lost callback, so the recovery path
 * must not depend on one.
 *
 * The order of the checks below is the point. Terminal states are excused first; a
 * non-terminal state with no deadline armed is then treated as already stalled, not as
 * nothing-to-watch. State and deadline are always armed in the same assignment block, so
 * one without the other is wreckage, not calm - and the old order (`if(!stall_deadline)
 * return FALSE` first) read exactly that wreckage as calm, which is how the round 7
 * (2026-08-16) stranding survived every poll for the rest of the round.
 *
 * Returns TRUE if it tore a stalled delivery down.
 */
/datum/voidcrew_cargo_shuttle/proc/check_stalled()
	// Terminal states first. DOCKED is a legitimate resting state - the shuttle sits at
	// its berth with no timer running while the crew unloads - and AWAY means resolved.
	if(state == CARGO_SHUTTLE_AWAY || state == CARGO_SHUTTLE_DOCKED)
		stall_deadline = 0 // resolved normally; nothing to watch
		return FALSE
	// A non-terminal state with no deadline armed is not "nothing to watch" - it IS the
	// lost callback. Every path into ARRIVING/DEPARTING arms stall_deadline in the same
	// block as the state (call_shuttle(), send_shuttle(), the complete_*() re-arms), so
	// a zero here means whatever armed it was torn down underneath the delivery. There is
	// no deadline left to wait for, and waiting is what stranded round 7: recover now.
	if(stall_deadline && world.time <= stall_deadline)
		return FALSE

	var/tardiness = stall_deadline ? "[(world.time - stall_deadline) / 10]s past its deadline" : "no deadline armed"
	log_shuttle("CARGO SHUTTLE STALL: delivery to [target_ship || "unknown ship"] stuck in state [state], \
		[tardiness] (shuttle_port=[shuttle_port ? "live" : "gone"], \
		transit=[transit_reservation ? "live" : "gone"]) - forcing recovery")
	state = CARGO_SHUTTLE_AWAY
	target_ship?.ship_notify("Cargo shuttle failed to arrive and has been recalled. Re-order when ready.", \
		"CARGO", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 50)
	linked_console?.say("Cargo shuttle transit aborted.")
	cleanup_shuttle() // hands the reserve berth back and clears the deadline
	target_ship = null
	return TRUE

/**
 * Timer callback - docks the shuttle after warmup using ship-to-ship docking system
 */
/datum/voidcrew_cargo_shuttle/proc/complete_arrival()
	warmup_timer = null
	warmup_started = null
	// The docking work below yields. Re-arm the watchdog on the grace window alone so it
	// can't fire mid-move, but keep it armed - this proc failing to return is one of the
	// two ways the state machine strands (see check_stalled()).
	stall_deadline = world.time + CARGO_SHUTTLE_STALL_GRACE

	if(state != CARGO_SHUTTLE_ARRIVING || !docked_at || !target_ship)
		state = CARGO_SHUTTLE_AWAY
		cleanup_shuttle()
		return FALSE

	// Make sure the empty space level is loaded
	if(!docked_at.loaded)
		// A level that never finishes loading would otherwise re-arm this retry forever,
		// and every retry pushes the stall deadline back out - the watchdog would never
		// see it. Give up instead of holding the berth and the ship's undock hostage.
		if(++load_retries > CARGO_SHUTTLE_MAX_LOAD_RETRIES)
			state = CARGO_SHUTTLE_AWAY
			linked_console?.say("Error: Destination failed to load.")
			cleanup_shuttle()
			return FALSE
		if(!docked_at.loading)
			docked_at.load_level()
		// Schedule retry
		warmup_started = world.time // Reset for timer display
		stall_deadline = world.time + CARGO_SHUTTLE_WARMUP + CARGO_SHUTTLE_STALL_GRACE
		warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_arrival)), 1 SECONDS, TIMER_STOPPABLE)
		return FALSE
	load_retries = 0

	log_shuttle("CARGO SHUTTLE: arrival for [target_ship] at [docked_at] - berth=[cargo_dock_index], \
		shuttle_port=[shuttle_port || "GONE"], reservation=[transit_reservation ? "live" : "GONE"], retries=[load_retries]")

	// Find the player's ship shuttle
	var/obj/docking_port/mobile/voidcrew/ship_shuttle = target_ship.shuttle
	if(!ship_shuttle)
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Could not locate ship.")
		cleanup_shuttle()
		return FALSE

	// Re-check the berth we claimed back at call_shuttle(). Passing our own claim keeps it
	// from reading as another ship's; an error here means the ship we are delivering to
	// moved off its dock during the warmup, not that somebody took ours.
	var/list/berth = docked_at.get_cargo_berth(ship_shuttle, cargo_dock_index)
	var/berth_error = berth["error"]
	if(berth_error)
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: [berth_error].")
		cleanup_shuttle()
		return FALSE

	var/obj/docking_port/stationary/ship_dock = berth["ship_dock"]
	var/obj/docking_port/stationary/cargo_dock = berth["cargo_dock"]
	// Normally the dock we are already holding. Re-assert rather than assume, so a ship
	// that undocked and re-berthed on the other port mid-warmup can't leave us holding a
	// claim on a dock we no longer use.
	if(cargo_dock_index != berth["index"])
		claim_berth(berth["index"])

	// The cargo shuttle berths one tile off the ship's own docking port, so any plating the
	// ship has built out past that port is exactly where the shuttle lands - it would be
	// overwritten (see hull_port_overhang() in hull_survey.dm). Refuse the delivery instead.
	// call_shuttle() already refused the order for this, so reaching it here means the hull
	// grew during the warmup; cleanup_shuttle() hands the berth back off cargo_dock_index.
	if(!ship_port_clear_to_berth(ship_shuttle, "cargo delivery to [target_ship]"))
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Ship hull extends past its docking port. Move the docking port \
			to the outermost hull door before ordering a delivery.")
		cleanup_shuttle()
		return FALSE

	// A shuttle "docks" by transplanting the turfs of its areas, so a ferry whose turfs
	// were deleted out from under it during the warmup still gets DOCKING_SUCCESS - and
	// then delivers nothing while the console announces an arrival. The reservation fix
	// in spawn_shuttle() removes the known cause; this guard makes any unknown one cost a
	// single refused, retryable delivery instead of a silent round-long outage (round 12,
	// 2026-08-23: forty minutes of phantom "docked" reports before a player report).
	if(!length(get_cargo_bay_turfs()))
		log_shuttle("CARGO SHUTTLE: refusing arrival for [target_ship] - shuttle hull has no turfs left (reservation=[transit_reservation ? "live" : "GONE"])")
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Cargo shuttle was lost in transit. Re-order when ready.")
		cleanup_shuttle()
		return FALSE

	// Calculate the correct dir for ship_dock based on ship_shuttle's current geometry
	// We can't call adjust_dock_to_shuttle because it also moves the dock
	// This is necessary because construction console port relocation updates port_direction
	// but doesn't update the stationary dock's dir
	var/shuttle_true_height = ship_shuttle.height
	var/shuttle_true_width = ship_shuttle.width
	if(EWCOMPONENT(ship_shuttle.port_direction))
		shuttle_true_height = ship_shuttle.width
		shuttle_true_width = ship_shuttle.height
	var/ship_facing_dir = angle2dir(dir2angle(shuttle_true_height > shuttle_true_width ? EAST : NORTH) + dir2angle(ship_shuttle.port_direction) + 180)
	ship_dock.dir = ship_facing_dir

	// Set cargo_dock dimensions to match the cargo shuttle
	cargo_dock.width = shuttle_port.width
	cargo_dock.height = shuttle_port.height

	// Position the cargo dock adjacent to the player's ship (without moving the ship)
	position_cargo_dock_next_to_ship(ship_dock, cargo_dock, ship_shuttle, shuttle_port)

	// Only dock the cargo shuttle - don't touch the player's ship.
	//
	// Bracketed by logs on purpose. initiate_docking() yields (CHECK_TICK through the turf
	// transplant), so a stall in there returns to nobody: no runtime, no console message,
	// and the datum sits in CARGO_SHUTTLE_ARRIVING forever, which the helm refuses to
	// undock on. Round 837 ended exactly that way and the logs could not tell whether the
	// move was even attempted. An "attempting dock" with no matching "dock returned" is
	// that stall; both lines present with a non-success code is an ordinary refusal.
	log_shuttle("CARGO SHUTTLE: attempting dock for [target_ship] - shuttle=[shuttle_port] at [AREACOORD(shuttle_port)] \
		currently on [shuttle_port.get_docked() || "NO DOCK"], reservation=[transit_reservation ? "live" : "GONE"], \
		target dock [cargo_dock] at [AREACOORD(cargo_dock)] dir=[cargo_dock.dir] berth=[cargo_dock_index]")
	var/cargo_result = shuttle_port.initiate_docking(cargo_dock, force = TRUE)
	log_shuttle("CARGO SHUTTLE: dock returned [cargo_result] for [target_ship]")

	if(cargo_result != DOCKING_SUCCESS)
		state = CARGO_SHUTTLE_AWAY
		linked_console?.say("Error: Shuttle docking failed.")
		cleanup_shuttle()
		return FALSE

	state = CARGO_SHUTTLE_DOCKED
	stall_deadline = 0
	linked_console?.say("Cargo shuttle has arrived.")

	// Now that docking succeeded, process purchases and spawn items
	if(linked_console)
		linked_console.buy()
		linked_console.print_requisition_form()

	// Play docking sound to all mobs on the ship
	if(target_ship?.shuttle)
		for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
			for(var/mob/M in ship_area)
				M.playsound_local(M, 'voidcrew/sound/cargodock1.ogg', 50, FALSE)
		addtimer(CALLBACK(src, PROC_REF(play_dock_sound_2)), 1 SECONDS)

	// If a loan was accepted, spawn the loan items
	if(loan_accepted && pending_loan)
		var/list/cargo_turfs = get_cargo_bay_turfs()
		log_shuttle("LOAN DEBUG: Spawning loan items. shuttle_port=[shuttle_port ? "valid" : "null"], turfs_found=[length(cargo_turfs)], loan_type=[pending_loan.type]")
		if(!length(cargo_turfs))
			log_shuttle("LOAN DEBUG: No cargo turfs found! shuttle_areas=[shuttle_port?.shuttle_areas ? length(shuttle_port.shuttle_areas) : "null"]")
		pending_loan.spawn_items(src)
		target_ship?.ship_notify(pending_loan.shuttle_transit_text, "CARGO", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
		QDEL_NULL(pending_loan)
		loan_accepted = FALSE

	return TRUE

/**
 * Sends the cargo shuttle away
 */
/datum/voidcrew_cargo_shuttle/proc/send_shuttle()
	if(state != CARGO_SHUTTLE_DOCKED)
		return FALSE

	// Check for living mobs on the shuttle
	if(has_living_mobs())
		return FALSE

	state = CARGO_SHUTTLE_DEPARTING
	warmup_started = world.time
	stall_deadline = world.time + CARGO_SHUTTLE_DEPARTURE_WARMUP + CARGO_SHUTTLE_STALL_GRACE
	warmup_timer = addtimer(CALLBACK(src, PROC_REF(complete_departure)), CARGO_SHUTTLE_DEPARTURE_WARMUP, TIMER_STOPPABLE)
	return TRUE

/**
 * Checks if there are any living mobs on the cargo shuttle
 */
/datum/voidcrew_cargo_shuttle/proc/has_living_mobs()
	if(!shuttle_port)
		return FALSE

	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			for(var/mob/living/L in T)
				if(L.stat != DEAD)
					return TRUE
	return FALSE

/**
 * Timer callback - processes cargo and cleans up shuttle
 */
/datum/voidcrew_cargo_shuttle/proc/complete_departure()
	warmup_timer = null
	warmup_started = null
	// sell() and destroy_shuttle() below both yield; same reasoning as complete_arrival().
	stall_deadline = world.time + CARGO_SHUTTLE_STALL_GRACE

	if(state != CARGO_SHUTTLE_DEPARTING)
		return FALSE

	// Release the reserve dock first
	release_berth()

	// Export cargo while shuttle is still docked (sell() uses shuttle_areas, doesn't need transit)
	linked_console?.sell()

	// Now fully destroy the shuttle (don't move to transit first - causes baseturfs issues)
	destroy_shuttle()

	// Restore the freed reserve dock's default geometry - we left it resized and
	// parked right against the player ship's dock
	docked_at?.reset_free_reserve_docks()

	state = CARGO_SHUTTLE_AWAY
	stall_deadline = 0
	load_retries = 0
	target_ship = null
	docked_at = null
	linked_console?.say("Cargo shuttle has departed.")
	return TRUE

/**
 * Completely destroys the shuttle - deletes all turfs and objects
 */
/datum/voidcrew_cargo_shuttle/proc/destroy_shuttle()
	// Hand the parking ground back first. The reservation is held bare on this datum
	// (see spawn_shuttle()) - Release() via qdel is its whole teardown, with none of the
	// force/QDEL_HINT_LETMELIVE dance the old transit dock needed.
	if(transit_reservation && !QDELETED(transit_reservation))
		qdel(transit_reservation)
	transit_reservation = null

	if(!shuttle_port || QDELETED(shuttle_port))
		shuttle_port = null
		return

	// Clear SSshuttle references
	if(SSshuttle.supply == shuttle_port)
		SSshuttle.supply = null


	// Get all turfs in shuttle areas before we delete the port
	var/list/shuttle_turfs = list()
	for(var/area/shuttle_area as anything in shuttle_port.shuttle_areas)
		for(var/turf/T in shuttle_area)
			shuttle_turfs += T

	// Delete all movable objects on shuttle turfs (except the docking port itself)
	for(var/turf/T as anything in shuttle_turfs)
		for(var/atom/movable/AM in T)
			if(AM == shuttle_port)
				continue
			if(isliving(AM))
				continue // Don't delete mobs
			qdel(AM)

	// Take the ferry's deck back off the berth and move what is left out of the shuttle area.
	//
	// This has to POP the hull off the baseturf stack, not stamp space over the top of it.
	// The ferry never flies away - it is destroyed where it sits - so the ScrapeAway() that
	// /turf/afterShuttleMove() performs on a departing shuttle's old tiles never runs for it,
	// and /turf/ChangeTurf() called with no explicit baseturfs list keeps the existing one
	// ("Just to be safe", change_turf.dm). So the old line left every berth tile carrying the
	// whole stack the landing pushed on: the tile's own former type, the ferry's deck, and a
	// /turf/baseturf_skipover/shuttle marker - permanently, because the berth outlives the
	// delivery whenever the crew stays docked in the same empty space.
	//
	// Each further delivery to that berth ran CopyOnTop() over the fattened stack and added
	// three more entries (1 > 4 > 7 > 10 > 13). At >10 baseturfs_string_list() gives up and
	// ChangeTurfs the tile to /turf/closed/indestructible/baseturfs_ded - the magenta "Report
	// this" wall - so the fifth cargo run in one berth replaced the entire landing zone with
	// indestructible flashing walls (round 14, 2026-08-24: 51 tiles of the Solo Surfer's berth
	// at (160-168, 36-42) went at once, all reporting 13).
	//
	// Scraping to the skipover restores exactly the tile that was there before the ferry
	// landed, which is what a real departure would have left behind, so nothing accumulates.
	// Tiles with no skipover were never decked - they were only adopted into the ferry's area
	// because they sit inside its bounding box - and keep the old blanket space conversion.
	var/area/space/space_area = locate(/area/space) in GLOB.areas
	if(!space_area)
		space_area = new /area/space
	for(var/turf/T as anything in shuttle_turfs)
		var/shuttle_depth = T.depth_to_find_baseturf(/turf/baseturf_skipover/shuttle)
		// A skipover sitting on the bottom of the stack is unscrapeable (ScrapeAway() CRASHes
		// on it rather than removing the only baseturf a tile has); fall back to the old
		// behaviour rather than take a runtime in the middle of a teardown.
		if(shuttle_depth && shuttle_depth < T.count_baseturfs())
			T.ScrapeAway(shuttle_depth, flags = CHANGETURF_DEFER_CHANGE)
		else
			T.ChangeTurf(/turf/open/space, flags = CHANGETURF_DEFER_CHANGE)
		// Restore the same area as a normal shuttle departure. Direct contents
		// assignment leaves this turf registered in the ferry's area forever.
		var/area/underlying_area = shuttle_port.underlying_areas_by_turf[T]
		if(QDELETED(underlying_area))
			underlying_area = space_area
		T.change_area(T.loc, underlying_area)

	// Delete the shuttle port (force = TRUE to actually delete it)
	qdel(shuttle_port, force = TRUE)
	shuttle_port = null

/**
 * Positions the cargo dock adjacent to the player's ship dock
 * This finds where the ship already is and places the cargo dock next to it,
 * without moving the player's ship at all.
 *
 * * ship_dock - The stationary dock the player's ship is using
 * * cargo_dock - The stationary dock for the cargo shuttle
 * * ship_shuttle - The player's ship mobile dock (for reference)
 * * cargo_shuttle - The cargo shuttle mobile dock
 */
/**
 * Plays the second docking sound after a delay
 */
/datum/voidcrew_cargo_shuttle/proc/play_dock_sound_2()
	if(!target_ship?.shuttle)
		return
	for(var/area/ship_area as anything in target_ship.shuttle.shuttle_areas)
		for(var/mob/M in ship_area)
			M.playsound_local(M, 'voidcrew/sound/cargodock2.ogg', 50, FALSE)

/datum/voidcrew_cargo_shuttle/proc/position_cargo_dock_next_to_ship(obj/docking_port/stationary/ship_dock, obj/docking_port/stationary/cargo_dock, obj/docking_port/mobile/ship_shuttle, obj/docking_port/mobile/cargo_shuttle_port)
	// For exit-to-exit docking (airlocks facing each other):
	// - ship_dock.dir points INTO the ship
	// - cargo_dock.dir must point INTO the cargo shuttle (OPPOSITE direction)
	// This way both shuttle bodies extend AWAY from the docking point

	// Cargo dock faces opposite to ship dock (exit-to-exit)
	cargo_dock.dir = REVERSE_DIR(ship_dock.dir)

	// Set up cargo dock offsets to match the cargo shuttle
	cargo_dock.dwidth = cargo_shuttle_port.dwidth
	cargo_dock.dheight = cargo_shuttle_port.dheight

	// The docks should be placed 1 tile apart in the direction the ship faces out
	// ship_dock.dir points INTO ship, so REVERSE_DIR is where ship's exit is
	var/offset_dir = REVERSE_DIR(ship_dock.dir)

	var/cargo_dock_x = ship_dock.x
	var/cargo_dock_y = ship_dock.y

	switch(offset_dir)
		if(NORTH)
			cargo_dock_y = ship_dock.y + 1
		if(SOUTH)
			cargo_dock_y = ship_dock.y - 1
		if(EAST)
			cargo_dock_x = ship_dock.x + 1
		if(WEST)
			cargo_dock_x = ship_dock.x - 1

	var/turf/new_loc = locate(cargo_dock_x, cargo_dock_y, ship_dock.z)
	if(new_loc)
		cargo_dock.forceMove(new_loc)
