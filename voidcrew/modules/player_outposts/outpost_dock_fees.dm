/**
 * # Ship bay docking fee and bay eviction
 *
 * The ship bay charges visiting ships a docking fee set on the Pricing tab. The flow:
 *
 * 1. **Quote.** ship_act() asks dock_fee_denial(). With a fee owed and no approval covering it,
 *    the ship holds position and its helm shows the quote.
 * 2. **Approve.** The captain (or, with no captain available, any crew member) approves the quote
 *    at the helm. The approval is a ceiling: a later, higher fee is quoted again, never charged.
 * 3. **Escrow.** Just before dock(), take_dock_fee() moves the fee out of the ship account into a
 *    /datum/outpost_dock_fee_hold. The escrow is neither ship nor outpost money, so the owner
 *    cannot withdraw a fee that may have to be returned.
 * 4. **Capture or refund.** The hold resolves exactly once: paid into the treasury when the ship
 *    arrives in the bay (COMSIG_VOIDCREW_SHIP_DOCKED), refunded to the ship on every other exit
 *    (dock refused, warmup denial, stalled dock, ship or outpost deleted, owner changed, the cap).
 *
 * Bay eviction lets the outpost's managers order a docked ship out: the fee is refunded when the
 * ship arrived less than 30 minutes ago, and after a warning the ship is undocked. A hull with no
 * crew aboard while its crew is ashore here is moved to a hangar berth instead, because an
 * undocked empty hull goes derelict and the owner could claim it.
 *
 * Seams are called from ship_act() and Destroy() (player_outpost.dm) and on_ship_undock_complete()
 * (outpost_services.dm). The helm side is in _helm.dm.
 */

// ===== STATE =====

/obj/structure/overmap/ship
	/// The fee an outpost is asking before this ship may dock: list("outpost" = weakref, "variant", "amount", "expires")
	var/list/dock_fee_quote
	/// The approved quote, spent at escrow: list("outpost" = weakref, "variant", "amount", "expires", "approver")
	var/list/dock_fee_consent
	/// The escrowed fee of this ship's current dock, if any. At most one at a time.
	var/datum/outpost_dock_fee_hold/dock_fee_hold

/obj/structure/overmap/dynamic/player_outpost
	/// Escrowed docking fees still waiting for their ship to arrive
	var/list/datum/outpost_dock_fee_hold/dock_fee_holds = list()
	/// weakref to a ship -> list("amount", "time") of the fee it paid for its current visit, for eviction refunds
	var/list/bay_visit_fees = list()
	/// weakref to a ship -> list("bay" = weakref, "timer", "retries", "by", "relocating") of a running eviction
	var/list/bay_evictions = list()

// ===== FEES =====

/// Whether `ship` docks in the bay free: ownerless outposts and the owner's own crews
/obj/structure/overmap/dynamic/player_outpost/proc/dock_fee_exempt(obj/structure/overmap/ship/ship)
	if(!founder_ckey)
		return TRUE
	if(!is_owner_crew_ship(ship))
		return FALSE
	// The admin testing aid bills a ship carrying the playtest visitor like any visitor's
	if(playtest_visitor_ckey)
		for(var/datum/mind/member as anything in ship.ship_team?.members)
			if(ckey(member.key) == playtest_visitor_ckey)
				return FALSE
	return TRUE

/// The fee `ship` owes to dock here with `dock_variant`: 0 when free or exempt. Only the ship bay charges.
/obj/structure/overmap/dynamic/player_outpost/proc/dock_fee_for(obj/structure/overmap/ship/ship, dock_variant)
	if(dock_variant != OUTPOST_DOCK_VARIANT_BAY || QDELETED(ship) || !ship_bay_installed)
		return 0
	if(dock_fee_exempt(ship))
		return 0
	return max(0, get_price(OUTPOST_PRICE_DOCK_BAY))

/// The ship's approval for docking here with `dock_variant`, or null when it has none or it expired
/obj/structure/overmap/dynamic/player_outpost/proc/valid_dock_fee_consent(obj/structure/overmap/ship/ship, dock_variant)
	var/list/consent = ship.dock_fee_consent
	if(!consent)
		return null
	var/datum/weakref/outpost_ref = consent["outpost"]
	if(outpost_ref?.resolve() != src || consent["variant"] != dock_variant || world.time >= consent["expires"])
		return null
	return consent

/**
 * Shows `ship` the fee it owes. The crew is told once per new or changed quote, so repeated dock
 * attempts do not spam them. Returns the refusal to show whoever tried to dock.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/quote_dock_fee(obj/structure/overmap/ship/ship, dock_variant, fee)
	var/list/old_quote = ship.dock_fee_quote
	var/datum/weakref/old_ref = old_quote?["outpost"]
	var/same_quote = old_quote && old_ref?.resolve() == src && old_quote["variant"] == dock_variant \
		&& old_quote["amount"] == fee && world.time < old_quote["expires"]
	if(!same_quote)
		ship.dock_fee_quote = list(
			"outpost" = WEAKREF(src),
			"variant" = dock_variant,
			"amount" = fee,
			"expires" = world.time + OUTPOST_DOCK_FEE_QUOTE_LIFETIME,
		)
		ship.ship_notify("[name] traffic control: docking fee [fee] cr.", "DOCKING", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 40)
		ship.push_helm_frame()
	return "[name] traffic control: docking fee [fee] cr."

/// A refusal to show the helm while a docking fee waits for the captain's approval, or null to go on docking
/obj/structure/overmap/dynamic/player_outpost/proc/dock_fee_denial(obj/structure/overmap/ship/ship, dock_variant)
	var/fee = dock_fee_for(ship, dock_variant)
	if(fee <= 0)
		return null
	// A full bay refuses at allocation as it always has; no point quoting for it
	if(!available_ship_bay())
		return null
	var/list/consent = valid_dock_fee_consent(ship, dock_variant)
	if(consent && consent["amount"] >= fee)
		return null
	return quote_dock_fee(ship, dock_variant, fee)

/// The ship bay `ship` has been given for its current dock, if any
/obj/structure/overmap/dynamic/player_outpost/proc/ship_bay_of(obj/structure/overmap/ship/ship)
	for(var/datum/outpost_berth/ship_bay/bay as anything in bay_berths)
		if(bay && bay.ship == ship)
			return bay
	return null

/**
 * Escrows the approved fee just before dock(). Null when nothing is owed or it was taken, else a
 * refusal (ship_act() then releases the berth and restores the ship). Never sleeps.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/take_dock_fee(obj/structure/overmap/ship/ship, dock_variant)
	// A ship only starts a dock from flight, so an older escrow's dock is over. Unless that dock
	// is still under way (dock() set `docked` and nothing has cleared it): never start a second.
	var/datum/outpost_dock_fee_hold/old_hold = ship.dock_fee_hold
	if(old_hold)
		if(ship.docked && ship.docked == old_hold.outpost)
			return "[name] traffic control: a docking sequence is already in progress."
		old_hold.refund("a new dock started")
	var/fee = dock_fee_for(ship, dock_variant)
	if(fee <= 0)
		return null
	var/list/consent = valid_dock_fee_consent(ship, dock_variant)
	// The approval is a ceiling: a fee raised after it was given is quoted again, never charged
	if(!consent || consent["amount"] < fee)
		return quote_dock_fee(ship, dock_variant, fee)
	var/datum/outpost_berth/ship_bay/bay = ship_bay_of(ship)
	if(!bay)
		return "[name] traffic control: no ship bay berth is available. Try again later."
	var/datum/bank_account/account = ship.ship_account
	if(QDELETED(account))
		return "[name] traffic control: docking fee refused, your ship has no account."
	if(!account.has_money(fee) || !account.adjust_money(-fee, "Docking fee (held): [name]"))
		return "[name] traffic control: docking fee of [fee] cr refused, insufficient ship funds."
	var/approver = consent["approver"]
	ship.dock_fee_consent = null
	ship.dock_fee_quote = null
	new /datum/outpost_dock_fee_hold(src, ship, bay, fee, dock_variant, approver)
	log_econ("[fee] cr docking fee held from [ship.name] ([account.account_holder]) for [name], approved by [approver]")
	ship.push_helm_frame()
	return null

/// Returns the ship's escrowed fee to its account (a dock that never arrived)
/obj/structure/overmap/dynamic/player_outpost/proc/refund_dock_fee_hold(obj/structure/overmap/ship/ship, reason)
	var/datum/outpost_dock_fee_hold/hold = ship?.dock_fee_hold
	if(hold && hold.outpost == src)
		hold.refund(reason)

/**
 * A ship finished undocking, or its dock was turned away: refund any unresolved hold and forget
 * every record of the ship here (quotes, approvals, the visit fee and any eviction).
 */
/obj/structure/overmap/dynamic/player_outpost/proc/release_dock_fee_state(obj/structure/overmap/ship/ship)
	if(!ship)
		return
	refund_dock_fee_hold(ship, "the dock ended")
	var/changed = FALSE
	var/datum/weakref/quote_ref = ship.dock_fee_quote?["outpost"]
	if(quote_ref && (quote_ref.resolve() == src || !quote_ref.resolve()))
		ship.dock_fee_quote = null
		changed = TRUE
	var/datum/weakref/consent_ref = ship.dock_fee_consent?["outpost"]
	if(consent_ref && (consent_ref.resolve() == src || !consent_ref.resolve()))
		ship.dock_fee_consent = null
		changed = TRUE
	forget_bay_ship(WEAKREF(ship))
	if(changed)
		ship.push_helm_frame()

/// Drops the visit fee and eviction records of a ship (weakref) and stops watching it
/obj/structure/overmap/dynamic/player_outpost/proc/forget_bay_ship(datum/weakref/ship_ref)
	if(!ship_ref)
		return
	var/had_eviction = !!bay_evictions[ship_ref]
	stop_bay_eviction(ship_ref)
	bay_visit_fees -= ship_ref
	var/obj/structure/overmap/ship/ship = ship_ref.resolve()
	if(ship)
		UnregisterSignal(ship, COMSIG_QDELETING)
	if(had_eviction)
		management_console?.on_dock_requests_changed()

/// A ship with a visit fee or eviction here was deleted (records never outlive the ship)
/obj/structure/overmap/dynamic/player_outpost/proc/on_bay_ship_deleted(obj/structure/overmap/ship/source)
	SIGNAL_HANDLER
	// WEAKREF() of a datum being deleted is null; the records are keyed by the weakref it already had
	forget_bay_ship(source.weak_reference)

/// Keeps per-ship records honest: they are dropped when the ship is deleted
/obj/structure/overmap/dynamic/player_outpost/proc/watch_bay_ship(obj/structure/overmap/ship/ship)
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_bay_ship_deleted), override = TRUE)

/// Called by a hold when its ship arrives in the bay: remember the fee for an eviction refund
/obj/structure/overmap/dynamic/player_outpost/proc/record_bay_visit_fee(obj/structure/overmap/ship/ship, amount)
	bay_visit_fees[WEAKREF(ship)] = list("amount" = amount, "time" = world.time)
	watch_bay_ship(ship)

/// The outpost is being deleted: refund every escrowed fee and stop every eviction
/obj/structure/overmap/dynamic/player_outpost/proc/refund_all_dock_fee_holds()
	for(var/datum/outpost_dock_fee_hold/hold as anything in dock_fee_holds.Copy())
		hold.refund("the outpost was deleted")
	dock_fee_holds.Cut()
	var/list/known_ships = bay_visit_fees | bay_evictions
	for(var/datum/weakref/ship_ref as anything in known_ships)
		forget_bay_ship(ship_ref)

// ===== HELM =====

/// Whether `user` may approve a docking fee for this ship: the ship rename rule (the captain, or any crew with no captain available)
/obj/structure/overmap/ship/proc/can_approve_dock_fee(mob/living/user)
	return isliving(user) && can_rename_ship(user)

/// The current quote, or null when there is none or it expired (expired quotes are dropped)
/obj/structure/overmap/ship/proc/current_dock_fee_quote()
	var/list/quote = dock_fee_quote
	if(!quote)
		return null
	var/datum/weakref/outpost_ref = quote["outpost"]
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost_ref?.resolve()
	if(QDELETED(home) || world.time >= quote["expires"])
		dock_fee_quote = null
		return null
	return quote

/// The helm's quote card (HelmComputer.tsx `dockFeeQuote`), or null
/obj/structure/overmap/ship/proc/dock_fee_quote_data(mob/user)
	var/list/quote = current_dock_fee_quote()
	if(!quote)
		return null
	var/datum/weakref/outpost_ref = quote["outpost"]
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost_ref.resolve()
	return list(
		"outpost" = home.name,
		"ref" = REF(home),
		"variant" = quote["variant"],
		"amount" = quote["amount"],
		"balance" = ship_account?.account_balance || 0,
		"canApprove" = !!can_approve_dock_fee(user),
	)

/**
 * Approves the quoted docking fee from the helm. Every param is client data: the quote must still
 * exist and match the outpost, variant and amount the crew was shown. Returns null when approved,
 * else a refusal for the helm to say.
 */
/obj/structure/overmap/ship/proc/approve_dock_fee(mob/living/user, outpost_ref_text, variant, amount)
	var/list/quote = current_dock_fee_quote()
	if(!quote)
		return "No docking fee is waiting for approval."
	var/datum/weakref/outpost_ref = quote["outpost"]
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost_ref.resolve()
	if(!istext(outpost_ref_text) || outpost_ref_text != REF(home) || !istext(variant) || variant != quote["variant"])
		return "That quote has expired."
	if(!isnum(amount) || amount != quote["amount"])
		return "The docking fee is now [quote["amount"]] cr."
	if(!can_approve_dock_fee(user))
		return "Captain only."
	dock_fee_consent = list(
		"outpost" = outpost_ref,
		"variant" = variant,
		"amount" = amount,
		"expires" = world.time + OUTPOST_DOCK_FEE_CONSENT_LIFETIME,
		"approver" = key_name(user),
	)
	dock_fee_quote = null
	log_game("[key_name(user)] approved a [amount] cr docking fee for [name] at [home.name]")
	ship_notify("[user.real_name] approved the [amount] cr docking fee at [home.name].", "DOCKING", SHIP_NOTIFY_NOTICE)
	push_helm_frame()
	// Go on with the approach, under the same conditions an approved docking request resumes it
	if(home.loaded && get_turf(home) && loc == home.loc && state == OVERMAP_SHIP_FLYING && is_still() && !is_interdicted && !QDELETED(shuttle))
		overmap_object_act(user, home, dock_variant = variant)
	return null

/// Declines the quoted docking fee from the helm. Null when declined, else a refusal.
/obj/structure/overmap/ship/proc/decline_dock_fee(mob/living/user, outpost_ref_text)
	var/list/quote = current_dock_fee_quote()
	if(!quote)
		return "No docking fee is waiting for approval."
	var/datum/weakref/outpost_ref = quote["outpost"]
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost_ref.resolve()
	if(!istext(outpost_ref_text) || outpost_ref_text != REF(home))
		return "That quote has expired."
	if(!can_approve_dock_fee(user))
		return "Captain only."
	dock_fee_quote = null
	ship_notify("[user.real_name] declined the [quote["amount"]] cr docking fee at [home.name].", "DOCKING", SHIP_NOTIFY_NOTICE)
	push_helm_frame()
	return null

// ===== ESCROW =====

/**
 * One escrowed docking fee. It resolves exactly once: captured into the treasury when its ship
 * arrives in the bay, or refunded to the ship account on every other exit.
 */
/datum/outpost_dock_fee_hold
	var/obj/structure/overmap/ship/ship
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// The ship bay given to this dock
	var/datum/weakref/bay_ref
	var/amount = 0
	var/variant
	/// The owner when the fee was taken. A different owner at arrival refunds it.
	var/founder_ckey
	var/approver
	var/created_at
	var/check_timer
	var/resolved = FALSE

/datum/outpost_dock_fee_hold/New(obj/structure/overmap/dynamic/player_outpost/outpost, obj/structure/overmap/ship/ship, datum/outpost_berth/ship_bay/bay, amount, variant, approver)
	src.outpost = outpost
	src.ship = ship
	bay_ref = WEAKREF(bay)
	src.amount = amount
	src.variant = variant
	src.approver = approver
	founder_ckey = outpost.founder_ckey
	created_at = world.time
	outpost.dock_fee_holds += src
	ship.dock_fee_hold = src
	RegisterSignal(ship, COMSIG_VOIDCREW_SHIP_DOCKED, PROC_REF(on_ship_docked))
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))
	check_timer = addtimer(CALLBACK(src, PROC_REF(check_stall)), OUTPOST_DOCK_FEE_HOLD_CHECK, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/outpost_dock_fee_hold/Destroy()
	// Deleting an unresolved hold must never destroy money
	if(!resolved)
		refund("the hold was deleted")
	ship = null
	outpost = null
	return ..()

/// Detaches from the ship and outpost. Returns FALSE if the hold had already resolved.
/datum/outpost_dock_fee_hold/proc/finish()
	if(resolved)
		return FALSE
	resolved = TRUE
	if(check_timer)
		deltimer(check_timer)
		check_timer = null
	if(ship)
		UnregisterSignal(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_QDELETING))
		if(ship.dock_fee_hold == src)
			ship.dock_fee_hold = null
	outpost?.dock_fee_holds -= src
	return TRUE

/// Whether the ship is in the bay this fee paid for, at the outpost and owner it paid
/datum/outpost_dock_fee_hold/proc/arrived()
	if(QDELETED(ship) || QDELETED(outpost) || ship.docked != outpost || outpost.founder_ckey != founder_ckey)
		return FALSE
	var/datum/outpost_berth/ship_bay/bay = bay_ref?.resolve()
	return !QDELETED(bay) && bay.ship == ship

/datum/outpost_dock_fee_hold/proc/capture()
	var/obj/structure/overmap/ship/paying_ship = ship
	var/obj/structure/overmap/dynamic/player_outpost/home = outpost
	if(!finish())
		return
	var/holder = paying_ship.ship_account?.account_holder || paying_ship.name
	home.receive_payment(amount, OUTPOST_PRICE_DOCK_BAY, "Docking fee", paying_ship.name, holder)
	home.record_bay_visit_fee(paying_ship, amount)
	log_game("[paying_ship.name] paid a [amount] cr docking fee at [home.name] (approved by [approver])")
	paying_ship.ship_notify("Docking fee of [amount] cr paid to [home.name].", "DOCKING", SHIP_NOTIFY_NOTICE)
	home.management_console?.on_dock_requests_changed()
	qdel(src)

/datum/outpost_dock_fee_hold/proc/refund(reason)
	var/obj/structure/overmap/ship/paying_ship = ship
	var/home_name = outpost?.name || "the outpost"
	if(!finish())
		return
	var/datum/bank_account/account = paying_ship?.ship_account
	if(QDELETED(account))
		// Only a ship with no account left gets here; the fee leaves the game with it
		log_econ("[amount] cr docking fee held for [paying_ship?.name || "a deleted ship"] at [home_name] was lost: no ship account to refund ([reason])")
	else
		account.adjust_money(amount, "Docking fee refund: [home_name]")
		log_econ("[amount] cr docking fee held for [paying_ship.name] at [home_name] refunded to [account.account_holder] ([reason])")
		if(!QDELETED(paying_ship))
			paying_ship.ship_notify("Docking fee of [amount] cr for [home_name] refunded: [reason].", "DOCKING", SHIP_NOTIFY_NOTICE)
	if(!QDELETED(src))
		qdel(src)

/datum/outpost_dock_fee_hold/proc/on_ship_docked(datum/source)
	SIGNAL_HANDLER
	if(arrived())
		capture()
	else if(!QDELETED(outpost) && ship.docked == outpost && outpost.founder_ckey != founder_ckey)
		refund("the outpost changed hands before you arrived")
	else
		refund("the ship docked somewhere else")

/datum/outpost_dock_fee_hold/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	// COMSIG_QDELETING comes before the ship's Destroy() deletes its account
	refund("the ship was lost")

/**
 * Covers docks that end with no outpost hook (abort_stalled_dock()). Short of the cap a hold never
 * refunds while its ship is still docking here, so a late arrival cannot dock free.
 */
/datum/outpost_dock_fee_hold/proc/check_stall()
	check_timer = null
	if(resolved)
		return
	if(QDELETED(ship) || QDELETED(outpost) || ship.docked != outpost)
		refund("the dock did not complete")
		return
	// Arrived without the signal reaching us: the bay itself knows
	var/datum/outpost_berth/ship_bay/bay = bay_ref?.resolve()
	if(arrived() && bay.is_ship_present())
		capture()
		return
	if(world.time >= created_at + OUTPOST_DOCK_FEE_HOLD_CAP)
		log_game("DOCK FEE: [ship.name]'s dock at [outpost.name] was still unresolved after [DisplayTimeText(OUTPOST_DOCK_FEE_HOLD_CAP)]; its [amount] cr fee was refunded and the dock, if it completes, is free.")
		message_admins("DOCK FEE: [ship.name]'s dock at [outpost.name] is stuck; its [amount] cr fee was refunded.")
		refund("the dock stalled")
		return
	check_timer = addtimer(CALLBACK(src, PROC_REF(check_stall)), OUTPOST_DOCK_FEE_HOLD_CHECK, TIMER_STOPPABLE | TIMER_DELETE_ME)

// ===== BAY EVICTION =====

/// The fee a ship would get back if evicted now: what it paid this visit, within the refund window
/obj/structure/overmap/dynamic/player_outpost/proc/bay_eviction_refund(obj/structure/overmap/ship/ship)
	var/list/visit = bay_visit_fees[WEAKREF(ship)]
	if(!visit || world.time - visit["time"] >= OUTPOST_BAY_EVICTION_REFUND_WINDOW)
		return 0
	return visit["amount"]

/// Why `user` cannot evict the ship in `bay` now, or null
/obj/structure/overmap/dynamic/player_outpost/proc/bay_eviction_denial(mob/living/user, datum/outpost_berth/ship_bay/bay)
	if(!istype(bay) || !(bay in bay_berths))
		return "Unknown ship bay."
	if(!is_current_management_user(user))
		return "Not authorised."
	if(bay.rebuild_owner)
		return "A ship rebuild is using the bay."
	if(!bay.is_ship_present())
		return "No ship is docked in the bay."
	if(bay_evictions[WEAKREF(bay.ship)])
		return "Eviction already under way."
	return null

/// Eviction state of a ship bay for the Ships tab (merged into its ship's `ships_here` row)
/obj/structure/overmap/dynamic/player_outpost/proc/bay_eviction_row(datum/outpost_berth/ship_bay/bay, mob/user)
	var/list/eviction = istype(bay) && bay.ship ? bay_evictions[WEAKREF(bay.ship)] : null
	var/eta = 0
	if(eviction?["timer"])
		eta = max(0, round(timeleft(eviction["timer"]) / 10))
	return list(
		"evict_denial" = bay_eviction_denial(user, bay),
		"evicting" = !!eviction,
		"evict_eta" = eta,
	)

/// Orders the ship in `bay` out. Null when started, else a refusal.
/obj/structure/overmap/dynamic/player_outpost/proc/request_bay_eviction(mob/living/user, datum/outpost_berth/ship_bay/bay)
	var/denial = bay_eviction_denial(user, bay)
	if(denial)
		return denial
	var/obj/structure/overmap/ship/ship = bay.ship
	var/datum/weakref/ship_ref = WEAKREF(ship)
	var/refunded = 0
	var/refund = bay_eviction_refund(ship)
	if(refund > 0)
		// Consume the record before paying: evict, cancel, evict refunds once
		var/list/visit = bay_visit_fees[ship_ref]
		bay_visit_fees -= ship_ref
		if(!refund_payment(ship.ship_account, refund, OUTPOST_PRICE_DOCK_BAY, "Docking fee (bay eviction)"))
			bay_visit_fees[ship_ref] = visit
			return "The treasury cannot cover the [refund] cr docking fee refund."
		refunded = refund
	bay_evictions[ship_ref] = list(
		"bay" = WEAKREF(bay),
		"timer" = addtimer(CALLBACK(src, PROC_REF(enforce_bay_eviction), ship_ref), OUTPOST_BAY_EVICTION_GRACE, TIMER_STOPPABLE | TIMER_DELETE_ME),
		"retries" = 0,
		"by" = key_name(user),
		"relocating" = FALSE,
	)
	watch_bay_ship(ship)
	log_game("[key_name(user)] evicted [ship.name] from the ship bay at [name][refunded ? ", refunding its [refunded] cr docking fee" : ""]")
	to_chat(user, span_notice("[ship.name] ordered out of the ship bay.[refunded ? " [refunded] cr refunded." : ""]"))
	ship.ship_notify("Bay clearance revoked by [name]. Undock within [DisplayTimeText(OUTPOST_BAY_EVICTION_GRACE)].[refunded ? " [refunded] cr docking fee refunded." : ""]", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 40)
	management_console?.on_dock_requests_changed()
	return null

/// Stops a running eviction of the ship in `bay`. Null when stopped, else a refusal.
/obj/structure/overmap/dynamic/player_outpost/proc/cancel_bay_eviction(mob/living/user, datum/outpost_berth/ship_bay/bay)
	if(!istype(bay) || !(bay in bay_berths))
		return "Unknown ship bay."
	if(!is_current_management_user(user))
		return "Not authorised."
	var/datum/weakref/ship_ref = bay.ship ? WEAKREF(bay.ship) : null
	if(!ship_ref || !bay_evictions[ship_ref])
		return "No eviction is under way."
	stop_bay_eviction(ship_ref)
	log_game("[key_name(user)] cancelled the eviction of [bay.ship.name] from the ship bay at [name]")
	to_chat(user, span_notice("[bay.ship.name] may stay."))
	bay.ship.ship_notify("[name] restored your bay clearance.", "DOCKING", SHIP_NOTIFY_NOTICE)
	management_console?.on_dock_requests_changed()
	return null

/// Drops an eviction and its timer
/obj/structure/overmap/dynamic/player_outpost/proc/stop_bay_eviction(datum/weakref/ship_ref)
	var/list/eviction = bay_evictions[ship_ref]
	if(!eviction)
		return
	if(eviction["timer"])
		deltimer(eviction["timer"])
	bay_evictions -= ship_ref

/// The owner abandoned or handed over the outpost: every running eviction ends and the ships keep their bays
/obj/structure/overmap/dynamic/player_outpost/proc/stop_all_bay_evictions()
	if(!length(bay_evictions))
		return
	for(var/datum/weakref/ship_ref as anything in bay_evictions.Copy())
		stop_bay_eviction(ship_ref)
		var/obj/structure/overmap/ship/ship = ship_ref.resolve()
		if(!QDELETED(ship))
			ship.ship_notify("[name] changed hands. Your bay clearance was restored.", "DOCKING", SHIP_NOTIFY_NOTICE)
	management_console?.on_dock_requests_changed()

/**
 * Tries again later, or gives up and tells the admins once the retries are spent. `endless` retries
 * never give up: an empty hull whose crew is alive waits in the bay until a hangar berth frees.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/retry_bay_eviction(datum/weakref/ship_ref, reason, endless = FALSE)
	var/list/eviction = bay_evictions[ship_ref]
	if(!eviction)
		return
	var/obj/structure/overmap/ship/ship = ship_ref.resolve()
	eviction["retries"] += 1
	if(!endless && eviction["retries"] > OUTPOST_BAY_EVICTION_RETRIES)
		log_game("BAY EVICTION: [ship?.name || "a ship"] could not be removed from the ship bay at [name] ([reason]). Eviction by [eviction["by"]] given up.")
		message_admins("BAY EVICTION: [ship?.name || "a ship"] could not be removed from the ship bay at [name] ([reason]).")
		notify_owner("[ship?.name || "The evicted ship"] could not be moved out of the ship bay: [reason].", "DOCKING")
		stop_bay_eviction(ship_ref)
		management_console?.on_dock_requests_changed()
		return
	eviction["timer"] = addtimer(CALLBACK(src, PROC_REF(enforce_bay_eviction), ship_ref), OUTPOST_BAY_EVICTION_RETRY, TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * TRUE when forcing `ship` out would launch a hull nobody is flying while its crew is still alive.
 * Only a connected, living crew member aboard counts as flying it. Crew alive anywhere else (ashore
 * here, off by pad, logged out aboard) count as ashore: an undocked hull with nobody at the helm goes
 * derelict, and the owner could then claim it.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/evicted_crew_ashore(obj/structure/overmap/ship/ship)
	var/list/hull_areas = ship.shuttle?.shuttle_areas
	var/crew_alive = FALSE
	for(var/datum/mind/member as anything in ship.ship_team?.members)
		var/mob/living/body = member?.current
		if(!isliving(body) || body.stat == DEAD)
			continue
		crew_alive = TRUE
		var/turf/location = get_turf(body)
		if(location && hull_areas && hull_areas[get_area(location)] && GET_CLIENT(body))
			return FALSE // someone is aboard to fly it
	return crew_alive

/// The grace (or a retry) ran out: undock the ship, or move it to a hangar berth while its crew is ashore
/obj/structure/overmap/dynamic/player_outpost/proc/enforce_bay_eviction(datum/weakref/ship_ref)
	var/list/eviction = bay_evictions[ship_ref]
	if(!eviction)
		return
	eviction["timer"] = null
	if(eviction["relocating"])
		return
	var/obj/structure/overmap/ship/ship = ship_ref.resolve()
	var/datum/weakref/bay_weakref = eviction["bay"]
	var/datum/outpost_berth/ship_bay/bay = bay_weakref?.resolve()
	if(QDELETED(ship) || QDELETED(bay) || bay.ship != ship)
		forget_bay_ship(ship_ref)
		return
	if(ship.state == OVERMAP_SHIP_UNDOCKING)
		retry_bay_eviction(ship_ref, "the ship is still undocking")
		return
	if(!bay.is_ship_present())
		retry_bay_eviction(ship_ref, "the ship is not settled in the bay")
		return
	if(evicted_crew_ashore(ship))
		eviction["relocating"] = TRUE
		INVOKE_ASYNC(src, PROC_REF(relocate_evicted_ship), ship_ref, eviction)
		return
	var/refusal = ship.undock()
	if(refusal)
		ship.ship_notify("Undock from [name] refused: [refusal]", "DOCKING", SHIP_NOTIFY_WARNING)
		retry_bay_eviction(ship_ref, refusal)
		return
	log_game("BAY EVICTION: [ship.name] was undocked from the ship bay at [name] (evicted by [eviction["by"]])")
	// Undock completion clears the eviction. Keep checking in case the undock stalls.
	retry_bay_eviction(ship_ref, "the undock did not complete")

/**
 * Moves an evicted ship whose crew is ashore from the bay to a free hangar berth. Sleeps: building
 * a berth loads a map. Retries while no berth is free.
 */
/obj/structure/overmap/dynamic/player_outpost/proc/relocate_evicted_ship(datum/weakref/ship_ref, list/eviction)
	var/obj/structure/overmap/ship/ship = ship_ref.resolve()
	var/datum/weakref/bay_weakref = eviction["bay"]
	var/datum/outpost_berth/ship_bay/bay = bay_weakref?.resolve()
	var/datum/outpost_berth/berth
	if(!QDELETED(ship) && !QDELETED(ship.shuttle) && has_hangar_elevator())
		berth = allocate_berth(ship)
	// Everything may have changed while the berth was built
	if(QDELETED(src))
		return
	if(bay_evictions[ship_ref] != eviction || QDELETED(ship) || QDELETED(bay) || bay.ship != ship || !bay.is_ship_present())
		if(berth && !QDELETED(berth) && berth.dock?.get_docked() != ship?.shuttle)
			berth.release(force = TRUE)
		if(bay_evictions[ship_ref] == eviction)
			eviction["relocating"] = FALSE
			retry_bay_eviction(ship_ref, "the ship left the bay while a berth was prepared")
		return
	var/failure
	if(!berth)
		failure = "no hangar berth is free"
	else
		adjust_reserve_dock_to_shuttle(berth.dock, ship.shuttle)
		if(ship.shuttle.width > berth.dock.width || ship.shuttle.height > berth.dock.height || ship.shuttle.canDock(berth.dock) != SHUTTLE_CAN_DOCK)
			failure = "the ship does not fit a hangar berth"
		else if(ship.shuttle.initiate_docking(berth.dock) != DOCKING_SUCCESS || berth.dock.get_docked() != ship.shuttle)
			failure = "the move to a hangar berth was blocked"
		if(failure && !QDELETED(berth) && berth.dock?.get_docked() != ship.shuttle)
			berth.release(force = TRUE)
	if(QDELETED(src))
		return
	if(failure)
		if(bay_evictions[ship_ref] == eviction)
			eviction["relocating"] = FALSE
			// Tell both sides once; the retries go on quietly until a berth frees or the crew undocks
			if(!eviction["waiting_notified"])
				eviction["waiting_notified"] = TRUE
				ship.ship_notify("[name] is clearing its ship bay, but your hull cannot be moved: [failure]. Return to your ship and undock.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 40)
				notify_owner("[ship.name] can't be moved out of the ship bay: [failure].", "DOCKING")
			retry_bay_eviction(ship_ref, failure, endless = TRUE)
		return
	// The hull now sits in the berth: hand the bay back and let the berth take the ship
	bay.release()
	berth.on_ship_docked(ship)
	forget_bay_ship(ship_ref)
	log_game("BAY EVICTION: [ship.name] had no crew aboard and crew ashore at [name]; it was moved from the ship bay to hangar berth [berth.berth_number]")
	ship.ship_notify("[name] moved your ship from the ship bay to Hangar Berth [berth.berth_number] while your crew is ashore.", "DOCKING", SHIP_NOTIFY_WARNING, 'voidcrew/sound/warn.ogg', 40)
	management_console?.on_dock_requests_changed()
