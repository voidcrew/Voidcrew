/**
 * # Outpost floors: the console (tenancy, settings, identity, hands)
 *
 * Owner: P3 (spec 3b.3, 3b.4, 5, 7). The management console is player_outposts/outpost_management_ui.dm; on any host
 * it merges floor_ui_data() into its data and hands actions it does not know to floor_ui_act(). The base procs on
 * /obj/structure/overmap/dynamic/player_outpost (player_outpost.dm) answer as before floors; this file overrides
 * can_take_over(), claim_denial(), announce_abandoned(), floor_ui_data() and floor_ui_act() on the host, and with them
 * can_claim(), transfer_ownership(), abandon() and set_outpost_name(), which is where a lease changes hands.
 * floor_ui_act() also shuts the docking actions a floor has no use for.
 *
 * A floor is never lost (owner decision 5): there is no vacancy clock here. A floor changes hands three ways only.
 * Its owner gives it up (then anyone may take it, in person), gives it away, or has had no client for
 * OUTPOST_FLOOR_OWNER_ABSENT and one of their own ship crew takes over the lease on the floor (A26).
 * One floor a crew holds on each of them (A24).
 *
 * Private state is prefixed tenancy_. Nobody else reads it.
 */

// What the console calls an entry of the guest list, the barred list or the candidates
#define TENANCY_KIND_PERSON "person"
#define TENANCY_KIND_CREW "crew"
/// People and ships the console offers at once
#define TENANCY_CANDIDATES_MAX 40

/datum/outpost_floor
	/// world.time before which the floor cannot be renamed again
	var/tenancy_rename_ready_at = 0
	/// ckey of whoever is still answering this floor's offer of work, or null. One offer out at a time.
	var/tenancy_hire_ckey
	/// Their name, for the console
	var/tenancy_hire_name
	/// world.time that offer lapses
	var/tenancy_hire_until = 0
	/// ckey -> world.time this floor last offered them work
	var/list/tenancy_hire_asked = list()

/obj/structure/overmap/dynamic/player_outpost/floor
	/// world.time from which the owner counts as gone, or 0 while they are about. Read it through tenancy_owner_gone_since().
	var/tenancy_owner_gone_at = 0
	/// Whether this host is listening for its owner coming back
	var/tenancy_watching = FALSE

// ===== IDENTITY (L31) =====

/// Typed text made fit to show: one line, cut to `max_length`, and nothing reject_bad_text() refuses. Null when it will not do.
/datum/outpost_floor/proc/tenancy_clean(text, max_length)
	if(!istext(text))
		return null
	var/static/regex/gaps = regex(@"\s+", "g")
	text = trim(replacetext(text, gaps, " "))
	text = trim(copytext_char(text, 1, max_length + 1))
	return reject_bad_text(text, max_length)

/// Whether `user` holds the lease, in the body that holds it
/datum/outpost_floor/proc/tenancy_is_owner(mob/user)
	return !!host?.is_owner(user) && !!host.is_current_management_user(user)

/// Whether `user` runs the floor: its owner or a steward, in their own body
/datum/outpost_floor/proc/tenancy_may_manage(mob/user)
	return !!host?.is_current_management_user(user)

/// The floor's name, everywhere it is kept. The host carries it too: its treasury, its bills and its windows read the host's.
/datum/outpost_floor/proc/tenancy_apply_name(new_name)
	floor_name = new_name
	if(host)
		host.name = new_name
		host.display_name = new_name
		if(host.treasury)
			host.treasury.account_holder = "[new_name] Treasury"
	tenancy_identity_changed()

/// The name or the colour has just changed, or the holder has: open lift windows show it at once. The board reads them
/// when asked. Anything that draws them once (the nameplate, the floor signs) is to be redrawn from here.
/datum/outpost_floor/proc/tenancy_identity_changed()
	outpost?.refresh_elevator_uis()

/**
 * Names the floor: one line, OUTPOST_FLOOR_NAME_MAX, reject_bad_text(), then PLAYER_OUTPOST_RENAME_COOLDOWN before the
 * next. Never announced. With a `user` it is the owner's to do; without one it is the registry's own (a new lease).
 */
/datum/outpost_floor/proc/set_name(new_name, mob/user)
	if(user && (!tenancy_is_owner(user) || world.time < tenancy_rename_ready_at))
		return FALSE
	new_name = tenancy_clean(new_name, OUTPOST_FLOOR_NAME_MAX)
	if(!new_name || new_name == floor_name)
		return FALSE
	var/old_name = floor_name
	tenancy_apply_name(new_name)
	if(user)
		tenancy_rename_ready_at = world.time + PLAYER_OUTPOST_RENAME_COOLDOWN
		log_game("OUTPOST FLOOR: [key_name(user)] renamed floor [number] of [outpost?.name] from '[old_name]' to '[new_name]'")
	return TRUE

/// Sets the floor's line for the board: one line, OUTPOST_FLOOR_LINE_MAX, reject_bad_text(). An empty line clears it.
/datum/outpost_floor/proc/set_line(new_line, mob/user)
	if(!istext(new_line) || (user && !tenancy_is_owner(user)))
		return FALSE
	if(!length(trim(new_line)))
		board_line = ""
		return TRUE
	new_line = tenancy_clean(new_line, OUTPOST_FLOOR_LINE_MAX)
	if(!new_line)
		return FALSE
	board_line = new_line
	if(user)
		log_game("OUTPOST FLOOR: [key_name(user)] set the board line of floor [number] of [outpost?.name] to '[new_line]'")
	return TRUE

/// Sets the accent. Anything but one of the eight ids is refused (A90). The owner's or a steward's to do.
/datum/outpost_floor/proc/set_accent(new_accent, mob/user)
	var/list/ids = OUTPOST_FLOOR_ACCENTS
	if(!istext(new_accent) || !ids[new_accent])
		return FALSE
	if(user && !tenancy_may_manage(user))
		return FALSE
	accent = new_accent
	tenancy_identity_changed()
	return TRUE

// ===== THE LISTS: GUESTS, BARRED, HANDS (spec 5.1, L33) =====

/// "person" for a mind, "crew" for a ship, null for anything else. The lists hold nothing else.
/datum/outpost_floor/proc/tenancy_kind(datum/entry)
	if(QDELETED(entry))
		return null
	if(istype(entry, /datum/mind))
		return TENANCY_KIND_PERSON
	if(istype(entry, /obj/structure/overmap/ship))
		return TENANCY_KIND_CREW
	return null

/// What the console calls `entry`, cut to the floor name's length
/datum/outpost_floor/proc/tenancy_entry_name(datum/entry)
	var/shown
	if(istype(entry, /datum/mind))
		var/datum/mind/person = entry
		shown = person.name
	else if(isatom(entry))
		var/atom/ship = entry
		shown = ship.name
	return copytext_char("[shown]", 1, OUTPOST_FLOOR_NAME_MAX + 1)

/// Drops what has been deleted out of the three lists (A36)
/datum/outpost_floor/proc/tenancy_prune()
	for(var/list/kept as anything in list(guests, barred, hands))
		// "as anything" on purpose: a hard-deleted entry is a null in the list, and a typed loop would step over it
		for(var/datum/entry as anything in kept)
			if(QDELETED(entry))
				kept -= entry

/// A listed mind or ship is being deleted: off every list it goes
/datum/outpost_floor/proc/tenancy_entry_deleted(datum/source)
	SIGNAL_HANDLER
	guests -= source
	barred -= source
	hands -= source

/// Call after putting `entry` on a list
/datum/outpost_floor/proc/tenancy_watch(datum/entry)
	RegisterSignal(entry, COMSIG_QDELETING, PROC_REF(tenancy_entry_deleted), override = TRUE)

/// Call after taking `entry` off a list
/datum/outpost_floor/proc/tenancy_unwatch(datum/entry)
	if(QDELETED(entry) || (entry in guests) || (entry in barred) || (entry in hands))
		return
	UnregisterSignal(entry, COMSIG_QDELETING)

/// Empties one of the three lists
/datum/outpost_floor/proc/tenancy_empty(list/emptied)
	var/list/gone = emptied.Copy()
	emptied.Cut()
	for(var/datum/entry in gone)
		tenancy_unwatch(entry)

/// Whether `entry` is one of the floor's own: a member's mind, or a ship of the owner's crew. They are never guests or barred.
/datum/outpost_floor/proc/tenancy_is_ours(datum/entry)
	if(istype(entry, /datum/mind))
		var/datum/mind/person = entry
		return !!person.current && !!is_member(person.current)
	if(istype(entry, /obj/structure/overmap/ship))
		return !!host?.is_owner_crew_ship(entry)
	return FALSE

/// Puts a mind or a ship on the guest list. OUTPOST_FLOOR_LIST_MAX at most.
/datum/outpost_floor/proc/tenancy_add_guest(datum/entry, mob/user)
	if(!tenancy_may_manage(user) || !tenancy_kind(entry) || tenancy_is_ours(entry))
		return FALSE
	tenancy_prune()
	if((entry in guests) || length(guests) >= OUTPOST_FLOOR_LIST_MAX)
		return FALSE
	if(entry in barred)
		barred -= entry
	guests += entry
	tenancy_watch(entry)
	return TRUE

/// Takes a mind or a ship off the guest list
/datum/outpost_floor/proc/tenancy_remove_guest(datum/entry, mob/user)
	if(!entry || !tenancy_may_manage(user) || !(entry in guests))
		return FALSE
	guests -= entry
	tenancy_unwatch(entry)
	return TRUE

/// Bars a mind or a ship. OUTPOST_FLOOR_LIST_MAX at most. A barred guest is no guest, and a barred hand is let go.
/datum/outpost_floor/proc/tenancy_add_barred(datum/entry, mob/user)
	if(!tenancy_may_manage(user) || !tenancy_kind(entry) || tenancy_is_ours(entry))
		return FALSE
	tenancy_prune()
	if((entry in barred) || length(barred) >= OUTPOST_FLOOR_LIST_MAX)
		return FALSE
	if(entry in guests)
		guests -= entry
	if(entry in hands)
		let_go(entry, user)
	barred += entry
	tenancy_watch(entry)
	return TRUE

/// Lifts a bar
/datum/outpost_floor/proc/tenancy_remove_barred(datum/entry, mob/user)
	if(!entry || !tenancy_may_manage(user) || !(entry in barred))
		return FALSE
	barred -= entry
	tenancy_unwatch(entry)
	return TRUE

/**
 * Who the console offers for the guest list, the barred list and hire: ships docked at this outpost and the players
 * on it now, the floor's own left out. Minds and ships, TENANCY_CANDIDATES_MAX at most. Nothing is ever typed (A66).
 */
/datum/outpost_floor/proc/tenancy_candidates()
	var/list/found = list()
	if(!outpost)
		return found
	for(var/obj/structure/overmap/ship/ship in SSovermap.simulated_ships)
		if(length(found) >= TENANCY_CANDIDATES_MAX)
			return found
		if(QDELETED(ship) || ship.docked != outpost || ship.state != OVERMAP_SHIP_IDLE || tenancy_is_ours(ship))
			continue
		found += ship
	for(var/mob/living/person in GLOB.player_list)
		if(length(found) >= TENANCY_CANDIDATES_MAX)
			return found
		if(QDELETED(person.mind) || person.stat == DEAD || person.mind.current != person || (person.mind in found))
			continue
		if(!outpost.holds_turf(get_turf(person)) || is_member(person))
			continue
		found += person.mind
	return found

// ===== HANDS (L33, A80) =====

/// Why `target` cannot be taken on as a hand now, or null when they can. Asked when the offer is made and again on a yes.
/datum/outpost_floor/proc/tenancy_hire_refusal(mob/living/target)
	if(state != OUTPOST_FLOOR_STATE_OWNED || !host?.founder_ckey)
		return "no lease"
	if(!istype(target) || QDELETED(target) || target.stat == DEAD || !target.ckey || QDELETED(target.mind) || target.mind.current != target)
		return "nobody to ask"
	if(!outpost?.holds_turf(get_turf(target)))
		return "not at the outpost"
	if(is_member(target))
		return "one of the floor's own"
	if(target.mind in hands)
		return "a hand already"
	if((target.mind in barred) || is_barred(target))
		return "barred"
	tenancy_prune()
	if(length(hands) >= OUTPOST_FLOOR_HANDS_MAX)
		return "no more hands"
	return null

/// The name of whoever is still answering this floor's offer of work, or null. An offer nobody answered lapses here.
/datum/outpost_floor/proc/tenancy_hire_pending()
	if(!tenancy_hire_ckey)
		return null
	if(world.time > tenancy_hire_until)
		tenancy_cancel_offer()
		return null
	return tenancy_hire_name

/// Withdraws the offer of work that is out, if one is
/datum/outpost_floor/proc/tenancy_cancel_offer()
	tenancy_hire_ckey = null
	tenancy_hire_name = null
	tenancy_hire_until = 0

/// Whether this floor's own offers stop another being made to `player_key`: one out to them now, or one made within OUTPOST_FLOOR_HIRE_GAP
/datum/outpost_floor/proc/tenancy_offer_stands(player_key)
	if(tenancy_hire_ckey == player_key && tenancy_hire_pending())
		return TRUE
	var/asked_at = tenancy_hire_asked[player_key]
	if(isnull(asked_at))
		return FALSE
	if(world.time < asked_at + OUTPOST_FLOOR_HIRE_GAP)
		return TRUE
	tenancy_hire_asked -= player_key
	return FALSE

/// The same, over every floor of every outpost: one offer to a person at a time, whoever makes it
/datum/outpost_floor/proc/tenancy_offer_blocked(player_key)
	if(tenancy_offer_stands(player_key))
		return TRUE
	for(var/obj/structure/overmap/trader_outpost/building in GLOB.trader_outposts)
		for(var/datum/outpost_floor/other in building.floors)
			if(other != src && other.tenancy_offer_stands(player_key))
				return TRUE
	return FALSE

/**
 * Offers `target` work on this floor, for the owner or a steward. Nobody is hired without their own yes (A80): this
 * only asks. TRUE when the question went out. One offer out a floor, one to a person at a time, and
 * OUTPOST_FLOOR_HIRE_GAP between two to the same person. tenancy_hire_answer() is what hires.
 */
/datum/outpost_floor/proc/offer_hire(mob/living/target, mob/user)
	if(!tenancy_may_manage(user) || tenancy_hire_refusal(target))
		return FALSE
	if(tenancy_hire_pending() || tenancy_offer_blocked(target.ckey))
		return FALSE
	tenancy_hire_ckey = target.ckey
	tenancy_hire_name = tenancy_entry_name(target.mind)
	tenancy_hire_until = world.time + OUTPOST_FLOOR_HIRE_ANSWER_TIME
	tenancy_hire_asked[target.ckey] = world.time
	INVOKE_ASYNC(src, PROC_REF(tenancy_ask_hire), target, user)
	return TRUE

/// Puts the question to `target` and passes on what they say. Sleeps: called async. No answer is no hire, and the offer lapses by its clock.
/datum/outpost_floor/proc/tenancy_ask_hire(mob/living/target, mob/user)
	var/datum/mind/asked = target.mind
	// Nobody asked for this window: it must not take the keys from someone in the middle of something
	var/answer = tgui_alert(target, "[floor_name] offers you work.", "Work", list("Take it", "No thanks"), OUTPOST_FLOOR_HIRE_ANSWER_TIME, FALSE)
	if(QDELETED(src) || QDELETED(asked) || isnull(answer))
		return
	tenancy_hire_answer(asked, answer == "Take it", user)

/**
 * `asked` has answered this floor's offer of work. A yes is checked against everything again before it hires: the
 * offer must still be theirs and not have lapsed, and they must still be someone this floor could take on.
 * TRUE when they were hired.
 */
/datum/outpost_floor/proc/tenancy_hire_answer(datum/mind/asked, accepted, mob/offerer)
	if(QDELETED(asked) || !tenancy_hire_pending())
		return FALSE
	var/mob/living/target = asked.current
	if(!istype(target) || !target.ckey || target.ckey != tenancy_hire_ckey)
		return FALSE
	tenancy_cancel_offer()
	if(!accepted)
		if(!QDELETED(offerer))
			to_chat(offerer, span_notice("[target.real_name] turns it down."))
		return FALSE
	if(tenancy_hire_refusal(target))
		return FALSE
	hands += asked
	tenancy_watch(asked)
	to_chat(target, span_notice("You work at [floor_name] now."))
	if(!QDELETED(offerer))
		to_chat(offerer, span_notice("[target.real_name] takes the job."))
	log_game("OUTPOST FLOOR: [key_name(target)] was hired as a hand on floor [number] of [outpost?.name] by [key_name(offerer)]")
	record_floor_metric("floor_hand", src, target)
	return TRUE

/// Lets a hand go, for the owner or a steward
/datum/outpost_floor/proc/let_go(datum/mind/hand, mob/user)
	if(!hand || !tenancy_may_manage(user) || !(hand in hands))
		return FALSE
	hands -= hand
	tenancy_unwatch(hand)
	if(!QDELETED(hand) && hand.current)
		to_chat(hand.current, span_notice("[floor_name] lets you go."))
	return TRUE

// ===== THE LEASE CHANGES HANDS (spec 7) =====

/// Says `message` to every player on the outpost's own deck, the lobby and the concourse, and nowhere else
/datum/outpost_floor/proc/tenancy_concourse_call(message)
	var/turf/corner = outpost?.template_bottom_left
	var/datum/map_template/shape = outpost?.outpost_template
	if(!corner || !shape)
		return
	for(var/mob/listener in GLOB.player_list)
		var/turf/where = get_turf(listener)
		if(!where || where.z != corner.z)
			continue
		if(where.x < corner.x || where.y < corner.y || where.x >= corner.x + shape.width || where.y >= corner.y + shape.height)
			continue
		to_chat(listener, span_boldnotice("[outpost.name]: [message]"))

/// The lease has a new holder: no hands, no offer out, a fresh name clock. A floor taken while vacant starts as a new one does.
/datum/outpost_floor/proc/tenancy_let_to(mob/living/new_owner, was_vacant)
	tenancy_empty(hands)
	tenancy_cancel_offer()
	tenancy_rename_ready_at = 0
	state = OUTPOST_FLOOR_STATE_OWNED
	if(!was_vacant)
		tenancy_identity_changed()
		return
	set_entry(OUTPOST_FLOOR_ENTRY_CREW)
	if(entry_policy != OUTPOST_FLOOR_ENTRY_CREW)
		entry_policy = OUTPOST_FLOOR_ENTRY_CREW
	// Named as a floor is when it is first let: after its holder's ship, or by its number
	var/obj/structure/overmap/ship/new_ship = get_crew_ship(new_owner)
	var/new_name = tenancy_clean(new_ship?.name, OUTPOST_FLOOR_NAME_MAX) || "Floor [number]"
	if(new_name != floor_name)
		tenancy_apply_name(new_name)
	else
		tenancy_identity_changed()
	record_floor_metric("floor_claimed", src, new_owner)

/// The owner has given the floor up. It stands vacant, as it is, and anyone may come up to take it.
/datum/outpost_floor/proc/tenancy_vacated(mob/user)
	tenancy_empty(hands)
	tenancy_empty(guests)
	tenancy_empty(barred)
	tenancy_cancel_offer()
	tenancy_rename_ready_at = 0
	board_line = ""
	state = OUTPOST_FLOOR_STATE_VACANT
	set_entry(OUTPOST_FLOOR_ENTRY_OPEN)
	if(entry_policy != OUTPOST_FLOOR_ENTRY_OPEN)
		entry_policy = OUTPOST_FLOOR_ENTRY_OPEN
	tenancy_identity_changed()
	record_floor_metric("floor_given_up", src, user)

/**
 * world.time from which this floor's owner counts as gone, or 0 while they have a client (or there is no owner).
 * Nothing ticks: the time is worked out when somebody asks. An owner who left a body or a ghost behind went when
 * that mob lost its client; one who left from the lobby left nothing, and counts from the first time anybody asked.
 * It never reads earlier than the owner really went, so a lease is never taken over early.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/proc/tenancy_owner_gone_since()
	if(!founder_ckey || GLOB.directory[founder_ckey])
		tenancy_owner_gone_at = 0
		return 0
	if(!tenancy_owner_gone_at)
		var/mob/left_behind = get_mob_by_ckey(founder_ckey)
		tenancy_owner_gone_at = left_behind?.last_logout_time || world.time
		if(!tenancy_watching)
			tenancy_watching = TRUE
			RegisterSignal(SSdcs, COMSIG_GLOB_CLIENT_CONNECT, PROC_REF(tenancy_client_connected))
	return tenancy_owner_gone_at

/// Somebody connected. If it is the owner, they are back, and the count starts again the next time they go.
/obj/structure/overmap/dynamic/player_outpost/floor/proc/tenancy_client_connected(datum/source, client/connected)
	SIGNAL_HANDLER
	if(founder_ckey && connected?.ckey == founder_ckey)
		tenancy_owner_gone_at = 0

/**
 * Whether `person` is on a ship crew with this floor's owner. Sharing a ship with them is one way; being of their
 * crew is the other, because an owner in cryo is on no ship's roster and their crew is still theirs.
 * A resident who moved in from the lobby is neither (A26).
 */
/obj/structure/overmap/dynamic/player_outpost/floor/proc/tenancy_on_owner_crew(mob/person)
	if(!founder_ckey || QDELETED(person?.mind))
		return FALSE
	var/datum/mind/owner_mind = founder_mind?.resolve()
	if(owner_mind)
		for(var/datum/team/voidcrew/team in person.mind.ship_teams)
			if(team in owner_mind.ship_teams)
				return TRUE
	var/datum/voidcrew_crew_record/owner_crew = GLOB.voidcrew_crew_roster[founder_ckey]
	return !QDELETED(owner_crew) && person.mind.get_reputation_crew() == owner_crew

/**
 * The one-floor-a-crew rule (A24), which is floor_holder_denial() wherever a lease is had: bought, claimed, given
 * or taken over. This floor is left out of the count. It is the one changing hands, and a lease passing to one of
 * its own crew would otherwise always be refused for the floor it is.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/claim_denial(mob/living/user)
	return floor_holder_denial(user, floor)

/**
 * Whether `user` may take over the lease: the owner has had no client for OUTPOST_FLOOR_OWNER_ABSENT, and `user` is
 * one of the owner's ship crew, alive, in their own body and standing on the floor. Residents from the lobby,
 * stewards and guests may not (A26), and nor may anyone whose crew holds another floor (A24).
 */
/obj/structure/overmap/dynamic/player_outpost/floor/can_take_over(mob/living/user)
	if(!floor || !founder_ckey || !istype(user) || QDELETED(user) || user.stat == DEAD)
		return FALSE
	if(!user.ckey || QDELETED(user.mind) || user.mind.current != user || is_owner(user))
		return FALSE
	if((user.ckey in blocked_residents) || !floor.contains_turf(get_turf(user)) || !tenancy_on_owner_crew(user))
		return FALSE
	var/gone_at = tenancy_owner_gone_since()
	if(!gone_at || world.time - gone_at < OUTPOST_FLOOR_OWNER_ABSENT)
		return FALSE
	return !claim_denial(user)

/// A floor is claimed as an outpost is when it stands vacant, and by its owner's crew when the owner has gone. The
/// console opens its controls to whoever this names, and transfer_ownership() lets them through as a claimant.
/obj/structure/overmap/dynamic/player_outpost/floor/can_claim(mob/living/user)
	return ..() || can_take_over(user)

/**
 * Every way the lease changes hands ends here: a gift from its owner, a claim on a vacant floor, a crewmate taking
 * over from an owner who has gone, an admin's say-so. A gift must leave its new holder's crew with one floor (A24);
 * the other two were tested by can_claim(). The hands go with the old holder (A80, A98).
 */
/obj/structure/overmap/dynamic/player_outpost/floor/transfer_ownership(mob/living/new_owner, mob/user, admin_override = FALSE)
	if(!floor)
		return ..()
	var/was_vacant = !founder_ckey
	var/taking_over = !admin_override && !was_vacant && new_owner == user && can_take_over(user)
	if(!admin_override && !taking_over && is_owner(user) && istype(new_owner) && claim_denial(new_owner))
		to_chat(user, span_warning("[new_owner.real_name] already holds a floor."))
		return FALSE
	// A crewmate taking over carries the floor on: the people living on it stay on its books
	var/list/datum/mind/stayed = taking_over ? residents.Copy() : null
	. = ..()
	if(!.)
		return
	if(stayed)
		residents |= stayed
	tenancy_owner_gone_at = 0
	floor.tenancy_let_to(new_owner, was_vacant)
	log_game("OUTPOST FLOOR: [key_name(new_owner)] now holds floor [floor.number] of [floor.outpost?.name] ([was_vacant ? "taken vacant" : (taking_over ? "taken over" : "handed over by [key_name(user)]")])")

/// Giving the floor up. Nothing is refunded and nothing is cleared out: it stands vacant as it is (spec 7).
/obj/structure/overmap/dynamic/player_outpost/floor/abandon(mob/user, admin_override = FALSE)
	var/had_owner = !!founder_ckey
	..()
	if(!floor || !had_owner || founder_ckey)
		return
	tenancy_owner_gone_at = 0
	floor.tenancy_vacated(user)

/// Said on the concourse and nowhere else: a floor is not the galaxy's news
/obj/structure/overmap/dynamic/player_outpost/floor/announce_abandoned()
	if(!floor)
		return
	floor.tenancy_concourse_call("Floor [floor.number] stands vacant.")

/// An outpost's rename is announced to every ship. A floor's name is its floor's, and is not (L31). An admin's goes
/// through as the registry's own.
/obj/structure/overmap/dynamic/player_outpost/floor/set_outpost_name(new_name, mob/user)
	if(!floor)
		return ..()
	if(user && !is_owner(user) && check_rights_for(user.client, R_ADMIN))
		return floor.set_name(new_name)
	return floor.set_name(new_name, user)

// ===== THE CONSOLE (build plan, section 5) =====

/// Rows for a list of minds and ships: the guest list, the barred list, the hands or the candidates
/datum/outpost_floor/proc/tenancy_rows(list/entries)
	var/list/rows = list()
	for(var/datum/entry in entries)
		var/kind = tenancy_kind(entry)
		if(kind)
			rows += list(list("ref" = REF(entry), "name" = tenancy_entry_name(entry), "kind" = kind))
	return rows

/**
 * The floor's part of the management console's data. The settings are no secret (the lift and the board show them);
 * the lists, the candidates and the count of visitors are for whoever runs the floor.
 * `floor_candidates` is the contract's `candidates`: the console already sends a `candidates` of its own.
 */
/obj/structure/overmap/dynamic/player_outpost/floor/floor_ui_data(mob/user)
	if(!floor)
		return null
	var/static/list/accent_rows
	if(!accent_rows)
		accent_rows = list()
		var/list/ids = OUTPOST_FLOOR_ACCENTS
		for(var/id in ids)
			accent_rows += list(list("id" = id, "hex" = ids[id]))
	var/list/data = list()
	data["is_floor"] = TRUE
	data["floor_number"] = floor.number
	data["floor_name"] = floor.floor_name || ""
	data["floor_entry"] = floor.entry_policy
	data["board_line"] = floor.board_line || ""
	data["accent"] = floor.accent
	data["accents"] = accent_rows
	data["floor_rename_wait"] = max(0, round((floor.tenancy_rename_ready_at - world.time) / 10))
	var/runs_it = !!is_current_management_user(user)
	if(runs_it)
		floor.tenancy_prune()
	data["guests"] = runs_it ? floor.tenancy_rows(floor.guests) : list()
	data["barred"] = runs_it ? floor.tenancy_rows(floor.barred) : list()
	data["hands"] = runs_it ? floor.tenancy_rows(floor.hands) : list()
	data["floor_candidates"] = runs_it ? floor.tenancy_rows(floor.tenancy_candidates()) : list()
	data["hire_pending"] = runs_it ? floor.tenancy_hire_pending() : null
	data["visitors"] = runs_it ? length(floor.visitors_upstairs()) : 0
	data["can_take_over"] = !!can_take_over(user)
	data["can_give_up"] = runs_it && !!is_owner(user)
	data["floor_claim_denial"] = founder_ckey ? null : claim_denial(user)
	return data

/**
 * The floor's actions at the management console, all named floor_*. Each checks who is asking at the moment it runs,
 * and a `ref` is only ever looked for among the candidates or on the list it names, so nothing typed is taken (A66).
 */
/obj/structure/overmap/dynamic/player_outpost/floor/floor_ui_act(action, list/params, mob/living/user)
	if(!floor || !istext(action))
		return FALSE
	// A floor has no docking, berths or ship bay. The console does not show them, and a message made by hand finds
	// them shut: a floor in lockdown would turn visitors away from its cloning bay, its pad and its cryopods.
	var/static/list/not_on_a_floor = list(
		"set_dock_mode", "approve_request", "deny_request", "ban_ship", "unban_ship", "revoke_approval",
		"install_ship_bay", "approve_bay_silo", "revoke_bay_silo",
	)
	if(action in not_on_a_floor)
		return TRUE
	if(findtext(action, "floor_") != 1)
		return FALSE
	. = TRUE
	if(!istype(user) || QDELETED(user) || !islist(params))
		return
	var/datum/outpost_floor/our_floor = floor
	switch(action)
		if("floor_take_over")
			if(can_take_over(user))
				transfer_ownership(user, user)
			return
		if("floor_give_up")
			if(!our_floor.tenancy_is_owner(user))
				return
			var/was_upstairs = our_floor.contains_turf(get_turf(user))
			if(tgui_alert(user, "Give up [our_floor.floor_name]?", "Lease", list("Give it up", "Cancel")) != "Give it up")
				return
			if(QDELETED(src) || QDELETED(user) || QDELETED(our_floor) || floor != our_floor || !our_floor.tenancy_is_owner(user) || user.stat != CONSCIOUS)
				return
			if(was_upstairs && !our_floor.contains_turf(get_turf(user)))
				return
			abandon(user)
			return
	// Everything else is the owner's or a steward's to do; the name and the line are the owner's alone
	if(!our_floor.tenancy_may_manage(user))
		return
	var/ref = params["ref"]
	switch(action)
		if("floor_set_entry")
			our_floor.set_entry(params["entry"], user)
		if("floor_set_accent")
			our_floor.set_accent(params["accent"], user)
		if("floor_set_name")
			our_floor.set_name(params["name"], user) // xss-safe: set_name() keeps nothing reject_bad_text() refuses (tenancy_clean())
		if("floor_set_line")
			our_floor.set_line(params["line"], user) // xss-safe: set_line() keeps nothing reject_bad_text() refuses (tenancy_clean())
		if("floor_guest_add", "floor_bar_add", "floor_hire")
			if(!istext(ref))
				return
			var/datum/picked = locate(ref) in our_floor.tenancy_candidates()
			if(!picked)
				return
			if(action == "floor_guest_add")
				our_floor.tenancy_add_guest(picked, user)
			else if(action == "floor_bar_add")
				our_floor.tenancy_add_barred(picked, user)
			else if(istype(picked, /datum/mind))
				var/datum/mind/wanted = picked
				if(!our_floor.offer_hire(wanted.current, user))
					to_chat(user, span_warning("[our_floor.tenancy_entry_name(wanted)] can't be asked just now."))
		if("floor_guest_remove")
			if(istext(ref))
				our_floor.tenancy_remove_guest(locate(ref) in our_floor.guests, user)
		if("floor_bar_remove")
			if(istext(ref))
				our_floor.tenancy_remove_barred(locate(ref) in our_floor.barred, user)
		if("floor_let_go")
			if(istext(ref))
				our_floor.let_go(locate(ref) in our_floor.hands, user)

#undef TENANCY_KIND_PERSON
#undef TENANCY_KIND_CREW
#undef TENANCY_CANDIDATES_MAX
