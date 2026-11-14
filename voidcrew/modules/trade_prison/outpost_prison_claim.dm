/**
 * # Outpost lockup: live bounty hand-in
 *
 * A live criminal bounty catch is handed in at any trader outpost's lockup (`design.md` section 9, `waves.md` Wave 5):
 * - A hunter in the front room pulling a restrained, stunned or downed `/mob/living/carbon/human/npc/bounty_criminal`
 *   bumps or clicks Processing's outer door while the warden is up at `desk_turf` and Processing is free.
 * - Processing's outer door opens (never the inner door). Only the hunter and that catch may step in from outside
 *   (`processing/outer/lets_prisoner()`).
 * - Once the catch is inside Processing and no player or other outsider stands inside (if a player lingers for 10 s,
 *   the warden tells them to step out once and waits), the outer door shuts.
 * - With both Processing doors shut and no player inside, `posting.lockup_claim()` reads `capture_state()` once,
 *   closes the posting before paying or deleting the body, pays credits to the deliverer's ship (preferring a crew
 *   ship berthed at this outpost) or drops a holochip on `claim_turf` when they have no ship, drops trade vouchers,
 *   the CAPTURED poster and any crew items on `claim_turf`, reserves the bounty record in the prisoner pool for this
 *   wing, deletes the catch inside the closed room, and has the warden speak the payout line.
 */

/datum/outpost_prison
	/// Weakref to the hunter handing a catch into Processing (`OUTPOST_PROCESSING_CLAIM`)
	var/datum/weakref/claim_deliverer_ref
	/// Weakref to the bounty criminal being handed into Processing (`OUTPOST_PROCESSING_CLAIM`)
	var/datum/weakref/claim_criminal_ref
	/// Whether the warden has already told a lingering hunter inside Processing to step out
	var/claim_prompted = FALSE
	/// Whether the current hand-in was aborted (catch stood free, died, or lost its posting) and is letting everyone out
	var/claim_aborting = FALSE

/// Clears transient hand-in state when Processing finishes or the wing is deleted
/datum/outpost_prison/proc/claim_clear()
	claim_deliverer_ref = null
	claim_criminal_ref = null
	claim_prompted = FALSE
	claim_aborting = FALSE

/// Whether `mover` may step into `processing/outer` from the front room as part of the active bounty hand-in
/datum/outpost_prison/proc/claim_lets_enter(atom/movable/mover)
	if(processing_state != OUTPOST_PROCESSING_CLAIM || claim_aborting || !mover)
		return FALSE
	return claim_deliverer_ref?.resolve() == mover || claim_criminal_ref?.resolve() == mover

/// Whether `ship` is berthed at `outpost` (docked directly or occupying one of its hangar berths)
/proc/is_ship_berthed_at_outpost(obj/structure/overmap/ship/ship, obj/structure/overmap/trader_outpost/outpost)
	if(QDELETED(ship) || QDELETED(outpost))
		return FALSE
	if(ship.docked == outpost)
		return TRUE
	for(var/datum/outpost_berth/berth as anything in outpost.berths)
		if(berth?.ship == ship)
			return TRUE
	return FALSE

/// Picks which ship a lockup hand-in pays for `deliverer`: of their crew ships, one berthed at `prison.outpost`, else the first
/proc/resolve_lockup_claim_ship(mob/living/deliverer, datum/outpost_prison/prison)
	if(QDELETED(deliverer))
		return null
	var/obj/structure/overmap/trader_outpost/outpost = prison?.outpost
	var/obj/structure/overmap/ship/first_ship
	var/list/datum/team/voidcrew/teams = list()
	for(var/datum/team/voidcrew/own_team as anything in deliverer.mind?.ship_teams)
		teams |= own_team
	var/datum/voidcrew_crew_record/crew = deliverer.mind?.get_reputation_crew()
	for(var/datum/team/voidcrew/crew_team as anything in crew?.teams)
		teams |= crew_team
	for(var/datum/team/voidcrew/team as anything in teams)
		var/obj/structure/overmap/ship/candidate = team?.ship
		if(QDELETED(candidate) || candidate.abandoned)
			continue
		if(!first_ship)
			first_ship = candidate
		if(outpost && is_ship_berthed_at_outpost(candidate, outpost))
			return candidate
	if(first_ship)
		return first_ship
	var/obj/structure/overmap/ship/fallback = get_crew_ship(deliverer)
	if(!QDELETED(fallback) && !fallback.abandoned)
		return fallback
	return null

/// Whether `mover` is an eligible hunter (not staff, not a held inmate, not an NPC) standing in the front room
/datum/outpost_prison/proc/can_hunter_deliver(mob/living/mover)
	if(QDELETED(mover) || !isliving(mover) || mover.stat != CONSCIOUS || !in_front_room(mover))
		return FALSE
	if(is_staff(mover) || is_inmate(mover) || is_outpost_prisoner(mover) || ishumannpc(mover))
		return FALSE
	return !!(mover.client || mover.mind || ishuman(mover))

/**
 * Checks whether `mover` (a player in the front room pulling `mover.pulling` to Processing's outer door) can start a
 * live bounty hand-in. Speaks the warden's refusal when someone brings a corpse or an unwanted person; stays silent
 * for a lone player or when the warden is down/away or Processing is busy. Opens `processing/outer` on success.
 */
/datum/outpost_prison/proc/try_start_processing_claim(mob/living/mover)
	if(!can_hunter_deliver(mover))
		return FALSE
	var/mob/living/pulled = mover.pulling
	if(!isliving(pulled) || QDELETED(pulled) || (!in_front_room(pulled) && !in_processing(pulled)))
		return FALSE
	if(!warden_at_desk())
		return FALSE
	if(processing_state == OUTPOST_PROCESSING_CLAIM && !claim_aborting && claim_criminal_ref?.resolve() == pulled)
		var/obj/machinery/door/airlock/existing_outer = processing_door(FALSE)
		if(existing_outer?.density && processing_shut(processing_door(TRUE)))
			processing_work_door(existing_outer, TRUE)
		return TRUE
	if(!processing_free())
		return FALSE

	if(pulled.client || pulled.mind)
		warden_say("Nobody's asking for that one.")
		return FALSE
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = pulled
	if(!istype(criminal) || istype(criminal, /mob/living/carbon/human/npc/bounty_criminal/decoy) || criminal.npc_ever_played())
		if(pulled.stat == DEAD)
			warden_say("We don't take bodies.")
		else
			warden_say("Nobody's asking for that one.")
		return FALSE
	if(criminal.stat == DEAD)
		warden_say("We don't take bodies.")
		return FALSE

	var/datum/criminal_bounty/posting = criminal.posting()
	var/obj/structure/overmap/ship/ship = resolve_lockup_claim_ship(mover, src)
	if(!posting || !posting.is_open() || posting.criminal() != criminal || istype(posting, /datum/criminal_bounty/kill_only))
		warden_say("Nobody's asking for that one.")
		return FALSE
	if((posting.private_to && (!ship || posting.offered_to() != ship)) || posting.lockup_bound_refusal(ship, mover))
		warden_say("Nobody's asking for that one.")
		return FALSE

	var/state = criminal.capture_state()
	if(state == BOUNTY_STATE_DEAD)
		warden_say("We don't take bodies.")
		return FALSE
	if(state == BOUNTY_STATE_FREE || !posting.board_share_for(state))
		return FALSE

	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(!outer || !processing_shut(processing_door(TRUE)))
		return FALSE
	processing_state = OUTPOST_PROCESSING_CLAIM
	claim_deliverer_ref = WEAKREF(mover)
	claim_criminal_ref = WEAKREF(criminal)
	claim_prompted = FALSE
	claim_aborting = FALSE
	processing_seconds = 0
	processing_work_door(outer, TRUE)
	return TRUE

/// Whether any live person other than `criminal` (or an AI cleanbot) is inside Processing
/datum/outpost_prison/proc/processing_claim_other_inside(mob/living/criminal)
	if(processing_player_inside())
		return TRUE
	for(var/mob/living/person as anything in processing_occupants())
		if(person == criminal || QDELETED(person) || person.stat == DEAD)
			continue
		if(istype(person, /mob/living/basic/bot/cleanbot) && isnull(person.client) && isnull(person.mind))
			continue
		return TRUE
	return FALSE

/// Begins aborting the active hand-in by opening `outer` (with `inner` shut) until Processing clears
/datum/outpost_prison/proc/abort_processing_claim()
	claim_aborting = TRUE
	processing_seconds = 0
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(inner && !processing_shut(inner))
		processing_work_door(inner, FALSE)
		return
	if(outer?.density)
		processing_work_door(outer, TRUE)

/// Advances `OUTPOST_PROCESSING_CLAIM` once a second
/datum/outpost_prison/proc/processing_claim_tick(seconds)
	if(!has_processing())
		processing_done()
		return
	var/obj/machinery/door/airlock/inner = processing_door(TRUE)
	var/obj/machinery/door/airlock/outer = processing_door(FALSE)
	if(!processing_shut(inner))
		processing_work_door(inner, FALSE)
		return

	var/mob/living/carbon/human/npc/bounty_criminal/criminal = claim_criminal_ref?.resolve()
	if(claim_aborting)
		processing_seconds += seconds
		var/still_occupied = (!QDELETED(criminal) && in_processing(criminal)) || processing_claim_other_inside(criminal)
		if(!still_occupied || processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT)
			processing_done()
			processing_idle_tick()
			return
		if(outer.density)
			processing_work_door(outer, TRUE)
		return

	if(QDELETED(criminal))
		if(processing_claim_other_inside(null))
			abort_processing_claim()
		else
			processing_done()
			processing_idle_tick()
		return

	if(!in_processing(criminal))
		if(!warden_at_desk() || criminal.stat == DEAD || criminal.client || criminal.mind || criminal.npc_ever_played())
			if(criminal.stat == DEAD && warden_at_desk())
				warden_say("We don't take bodies.")
			if(processing_claim_other_inside(criminal))
				abort_processing_claim()
			else
				processing_done()
				processing_idle_tick()
			return
		var/datum/criminal_bounty/entering_posting = criminal.posting()
		var/entering_state = criminal.capture_state()
		if(!entering_posting?.is_open() || entering_posting.criminal() != criminal || entering_state == BOUNTY_STATE_FREE || !entering_posting.board_share_for(entering_state))
			if(processing_claim_other_inside(criminal))
				abort_processing_claim()
			else
				processing_done()
				processing_idle_tick()
			return
		processing_seconds += seconds
		if(processing_seconds >= OUTPOST_PRISON_PROCESSING_WAIT)
			if(processing_claim_other_inside(criminal))
				abort_processing_claim()
			else
				processing_done()
				processing_idle_tick()
			return
		if(outer.density)
			processing_work_door(outer, TRUE)
		return

	// The catch is inside Processing: if a player or another person is still inside (or standing in the outer doorway), keep outer open.
	var/doorway_occupied = !!(locate(/mob/living) in get_turf(outer))
	if(processing_claim_other_inside(criminal) || doorway_occupied)
		if(outer.density)
			processing_work_door(outer, TRUE)
		if(processing_claim_other_inside(criminal))
			processing_seconds += seconds
			if(!claim_prompted && processing_seconds >= OUTPOST_PROCESSING_CLAIM_PROMPT)
				claim_prompted = TRUE
				warden_say("Step out.")
		return

	// Catch is alone inside Processing: validate before shutting, then shut outer and settle the claim once shut.
	var/mob/living/deliverer = claim_deliverer_ref?.resolve()
	var/obj/structure/overmap/ship/ship = resolve_lockup_claim_ship(deliverer, src)
	var/datum/criminal_bounty/posting = criminal.posting()
	var/state = criminal.capture_state()
	if(!warden_at_desk() || criminal.client || criminal.mind || criminal.npc_ever_played() || !posting?.is_open() || posting.criminal() != criminal)
		abort_processing_claim()
		return
	if((posting.private_to && (!ship || posting.offered_to() != ship)) || posting.lockup_bound_refusal(ship, deliverer))
		warden_say("Nobody's asking for that one.")
		abort_processing_claim()
		return
	if(state == BOUNTY_STATE_DEAD || criminal.stat == DEAD)
		warden_say("We don't take bodies.")
		abort_processing_claim()
		return
	if(state == BOUNTY_STATE_FREE || !posting.board_share_for(state))
		abort_processing_claim()
		return

	if(!processing_shut(outer))
		processing_work_door(outer, FALSE)
		return
	if(processing_claim_other_inside(criminal))
		abort_processing_claim()
		return

	var/claimed_pay = posting.lockup_claim(src, criminal, deliverer)
	if(!islist(claimed_pay))
		abort_processing_claim()
		return
	processing_done()

/// Subtype hook for postings with crew/user bindings (such as the kingpin)
/datum/criminal_bounty/proc/lockup_bound_refusal(obj/structure/overmap/ship/ship, mob/user)
	return null

/**
 * Pays for a live `criminal_mob` shut inside `prison`'s Processing room and closes the bounty for everyone.
 * Reads `capture_state()` once, refuses dead/free/player bodies and kill-only postings, closes the posting before
 * paying or deleting the mob, reserves the record in the prisoner pool for `prison`, drops vouchers, any CAPTURED
 * poster and crew items on `claim_turf` (plus a credit holochip when `deliverer` has no ship), deletes `criminal_mob`
 * inside the shut room, and speaks the warden's payout line. Returns `list(credits, vouchers)` or a refusal string.
 */
/datum/criminal_bounty/proc/lockup_claim(datum/outpost_prison/prison, mob/living/criminal_mob, mob/living/deliverer)
	SHOULD_NOT_SLEEP(TRUE)
	if(!is_open())
		return "that bounty is closed"
	if(QDELETED(prison) || QDELETED(criminal_mob) || istype(src, /datum/criminal_bounty/kill_only))
		return "nobody's asking for that one"
	var/mob/living/carbon/human/npc/bounty_criminal/criminal = criminal_mob
	if(!istype(criminal) || criminal != criminal())
		return "nobody's asking for that one"
	if(criminal.client || criminal.mind || criminal.npc_ever_played())
		return "nobody's asking for that one"
	if(criminal.stat == DEAD)
		return "we don't take bodies"
	var/state = criminal.capture_state()
	if(state == BOUNTY_STATE_DEAD)
		return "we don't take bodies"
	if(state == BOUNTY_STATE_FREE)
		return "they're standing free"
	var/share = board_share_for(state)
	if(!share)
		return "they're standing free"

	var/obj/structure/overmap/ship/ship = resolve_lockup_claim_ship(deliverer, prison)
	if(private_to && (!ship || offered_to() != ship))
		return "that offer is for another crew"
	var/bound_refusal = lockup_bound_refusal(ship, deliverer)
	if(bound_refusal)
		return bound_refusal

	var/list/pay = board_payout(share)
	var/datum/bounty_record/claimed = record
	var/wanted_name = claimed?.name || "the fugitive"
	var/most_wanted = claimed?.tier == BOUNTY_TIER_MOST_WANTED && !private_to
	var/poster_text = (share >= 100 && claimed?.tier >= BOUNTY_TIER_WANTED) ? board_poster_text(ship, deliverer) : null
	var/list/already_told = most_wanted ? hunter_ships() : list()
	var/reputation_gain = (ship && (pay[1] > 0 || pay[2] > 0)) ? board_claim_zone_work(ship) : 0

	board_detach_criminal()
	if(claimed)
		claimed.captor_name = ship ? ship.name : (deliverer?.real_name || null)
		claimed.captor_ship = ship ? WEAKREF(ship) : null
		claimed.hurt_fraction = clamp(1 - criminal.health / max(criminal.maxHealth, 1), 0, 1)
		claimed.preferred_prison = WEAKREF(prison)

	// Close the posting before anything else so a second claim can never pay twice (abuse 21)
	close(BOUNTY_CLOSE_CLAIMED, ship)

	if(claimed && bounty_pool_add(claimed) && claimed.status == BOUNTY_RECORD_WANTED)
		claimed.status = BOUNTY_RECORD_POOLED

	var/turf/drop_turf = prison.claim_turf || prison.desk_turf || get_turf(criminal)
	criminal.pulledby?.stop_pulling()
	criminal.stop_pulling()
	criminal.buckled?.unbuckle_mob(criminal, force = TRUE)
	var/list/not_gear = list()
	for(var/obj/item/item as anything in criminal.get_all_contents_type(/obj/item))
		if(!QDELETED(item) && is_type_in_typecache(item, GLOB.human_npc_not_gear))
			not_gear += item
	criminal.npc_drop_not_gear()
	if(drop_turf)
		for(var/obj/item/item as anything in not_gear)
			if(!QDELETED(item) && isturf(item.loc))
				item.forceMove(drop_turf)
	bounty_return_crew_items(criminal, drop_turf)

	var/paid_to_ship = FALSE
	if(ship?.ship_account)
		paid_to_ship = TRUE
		if(pay[1] > 0)
			ship.ship_account.adjust_money(pay[1])
	else if(pay[1] > 0 && drop_turf)
		new /obj/item/holochip(drop_turf, pay[1])
	if(pay[2] > 0 && drop_turf)
		new /obj/item/stack/trade_voucher(drop_turf, pay[2])
	if(poster_text && drop_turf)
		bounty_print_captured_poster(drop_turf, poster_text, wanted_name)

	REMOVE_TRAIT(criminal, TRAIT_MISSION_FIELD_MOB, BOUNTY_TRAIT)
	ADD_TRAIT(criminal, TRAIT_BOUNTY_REMOVED, BOUNTY_PAD_TRAIT)
	qdel(criminal)

	record_lockup_bounty_claim(src, TRUE, deliverer, ship, drop_turf, pay[1], pay[2], prison)

	if(!paid_to_ship)
		prison.warden_say("No ship on file. Take the chip.", forced = TRUE)
	else if(state == BOUNTY_STATE_DOWNED)
		prison.warden_say("Barely breathing. Paid to the [ship.name].", forced = TRUE)
	else
		prison.warden_say("Cuffed and breathing. Paid to the [ship.name].", forced = TRUE)

	if(ship)
		var/list/paid = list("[pay[1]] credits")
		if(pay[2] > 0)
			paid += "[pay[2]] trade voucher[pay[2] > 1 ? "s" : ""]"
		var/reputation_text = reputation_gain > 0 ? " Reputation +[reputation_gain]." : ""
		ship.ship_notify("BOUNTY: [wanted_name] turned in, [bounty_state_words(state)]. Paid [english_list(paid)].[reputation_text]", "BOUNTY COMPLETE", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	if(most_wanted)
		var/who_brought = ship ? "the crew of the [ship.name]" : "a bounty hunter"
		var/list/skip_ships = ship ? (already_told + ship) : already_told
		SScriminal_bounties.board_announce("BOUNTY: [who_brought] brought in [wanted_name], Most Wanted.", skip_ships)
	log_game("BOUNTY: [ship ? ship.name : (deliverer ? key_name(deliverer) : "no ship")] turned in [wanted_name] ([state], [share]%) at '[prison.outpost_log_name()]' lockup for [pay[1]] cr and [pay[2]] voucher(s)[deliverer ? ", delivered by [key_name(deliverer)]" : ""]")
	return pay
