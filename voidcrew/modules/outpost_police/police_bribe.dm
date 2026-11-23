/**
 * # Outpost police: the warden's price
 *
 * Owner decision 64. A prisoner serving a jail term in a station cell calls out, by saying anything or by trying the
 * cell door (police_cell.dm called_out()); the warden (code name: sergeant, police_units.dm) hears it (police_life.dm
 * life_answer_cell()), walks to the cell door, names a price and the prisoner answers Pay or No. He also comes once of
 * his own accord, OUTPOST_POLICE_BRIBE_FIRST into a jail term (tick_bribes()). Paid, the money comes from the prisoner's crew's pooled
 * ship accounts (charge_crew(), the fine's routine) before anything else happens, the cell's own door control opens
 * the door, and the cell lets them go exactly as a served term does (release()). If the door will not open the
 * money goes back. Nothing is owed after a short payment.
 *
 * No offer: a paid hold (only a jail term), a prisoner in crit or being booked or out of the cell, anyone wanted
 * still at large at the outpost, a warden who is busy or has lost his card (he says so), or within
 * OUTPOST_POLICE_BRIBE_WAIT of the last offer to that prisoner. The bar and the crew ban stand (close_warrant()
 * as served, as any release).
 */

/datum/outpost_police
	/// Prisoners the warden will not come to again until then: mind -> world.time
	var/list/bribe_wait = list()
	/// Offers out now: mind -> the price named
	var/list/bribe_offers = list()

/// The warden's price for `prisoner`: per star at arrest (it never drops as the term runs down), times the zone, with a floor
/datum/outpost_police/proc/bribe_price(datum/mind/prisoner)
	var/datum/outpost_warrant/warrant = get_warrant(prisoner)
	var/stars = clamp(max(get_stars(prisoner), warrant ? stars_of(warrant.peak) : 0), 1, 5)
	return round(max(OUTPOST_POLICE_BRIBE_MIN, OUTPOST_POLICE_BRIBE_PER_STAR * stars * (profile?.fine_multiplier || 1)))

/**
 * The cell `prisoner` could be bought out of now, or null: serving a jail term (not a paid hold) in a station cell,
 * booked and inside it, awake and not in crit, with a warrant, nobody wanted at large here, and (unless `ignore_wait`)
 * not offered lately.
 */
/datum/outpost_police/proc/bribe_cell_for(mob/living/prisoner, ignore_wait = FALSE)
	var/datum/mind/mind = prisoner?.mind
	if(!mind || QDELETED(prisoner) || prisoner.stat != CONSCIOUS || HAS_TRAIT(prisoner, TRAIT_CRITICAL_CONDITION))
		return null
	var/datum/outpost_police_cell/cell = cell_holding(mind)
	if(!cell || !cell.jailed[mind] || !isnull(cell.booking[mind]) || (mind in cell.return_by) || cell.body_of(mind) != prisoner)
		return null
	if(!(get_turf(prisoner) in cell.tiles) || QDELETED(cell.door) || !cell.outside_turf)
		return null
	var/datum/outpost_warrant/warrant = get_warrant(mind)
	if(!warrant || warrant.heat <= 0)
		return null
	if(!ignore_wait && bribe_wait[mind] > world.time)
		return null
	if(stealth_anyone_at_large())
		return null
	return cell

/// `prisoner`'s answer to the price the warden named. Pay: the money first, then the door, then the release. Sleeps.
/// TRUE if they walked out on it.
/datum/outpost_police/proc/bribe_answer(mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden, mob/living/prisoner, datum/outpost_police_cell/cell, pay)
	var/datum/mind/mind = prisoner?.mind
	if(!mind || isnull(bribe_offers[mind]))
		return FALSE
	var/price = bribe_offers[mind]
	bribe_offers -= mind
	. = FALSE
	if(pay)
		. = bribe_take(warden, prisoner, cell, price)
	// He goes back to his desk either way
	if(!QDELETED(warden) && istype(warden.activity, /datum/ambient_activity/warden_bribe))
		warden.end_activity()

/// Takes `price` for `prisoner` and lets them out of `cell`, or takes nothing. Sleeps (the door).
/datum/outpost_police/proc/bribe_take(mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden, mob/living/prisoner, datum/outpost_police_cell/cell, price)
	var/datum/mind/mind = prisoner.mind
	if(bribe_cell_for(prisoner, ignore_wait = TRUE) != cell || !warden?.bribe_at_door(cell) || !warden.bribe_has_card())
		return FALSE
	var/reason = "Payment: [profile?.force_name || "outpost security"]"
	var/list/taken = charge_crew(get_warrant(mind), price, reason)
	if(isnull(taken))
		warden.bribe_say(POLICE_LINE_BRIBE_SHORT)
		return FALSE
	// The money is gone: the door opens or the money comes back. While it opens the cell's tick leaves them be, as it
	// does a booking, so a prisoner quick through the opening door is not counted as breaking out.
	cell.booking[mind] = world.time
	var/opened = cell.open_door(OUTPOST_POLICE_CELL_OPEN, wait = TRUE)
	if(!opened || QDELETED(prisoner) || prisoner.mind != mind || cell_holding(mind) != cell || prisoner.stat == DEAD)
		cell.booking -= mind
		refund_crew(taken, reason)
		if(!opened && !QDELETED(warden))
			warden.bribe_say(POLICE_LINE_BRIBE_DOOR)
		return FALSE
	log_game("OUTPOST POLICE: [key_name(prisoner)] paid the warden [price] cr to leave a cell at [AREACOORD(cell.door)].")
	cell.release(mind, prisoner, POLICE_LINE_BRIBE_TAKEN)
	return TRUE

/**
 * Once a second (police_cell.dm tick_cells()): the warden goes of his own accord, once, to each prisoner serving a
 * jail term, OUTPOST_POLICE_BRIBE_FIRST after it starts, and names his price as if called. While he cannot (busy,
 * trouble at the outpost, the prisoner down or being offered already) it waits for him.
 */
/datum/outpost_police/proc/tick_bribes()
	for(var/datum/outpost_police_cell/cell as anything in cells)
		for(var/datum/mind/prisoner in cell.visit_due)
			if(world.time < cell.visit_due[prisoner])
				continue
			var/mob/living/body = cell.body_of(prisoner)
			if(!body || bribe_cell_for(body) != cell)
				continue
			for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden in officers)
				if(warden.bribe_visit(body, cell))
					cell.visit_due -= prisoner
					return
			return // nobody free to go: the next tick tries again

/// Shows `prisoner` the price the warden just said, and hands their answer back. Sleeps (the prompt).
/datum/outpost_police/proc/bribe_ask(mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden, mob/living/prisoner, datum/outpost_police_cell/cell, text)
	var/answer = tgui_alert(prisoner, text, warden.name, list("Pay", "No"), OUTPOST_POLICE_BRIBE_ANSWER)
	bribe_answer(warden, prisoner, cell, answer == "Pay")

/// "1,500" for 1500
/proc/outpost_police_price_text(amount)
	var/digits = "[round(amount)]"
	var/grouped = ""
	while(length(digits) > 3)
		grouped = ",[copytext(digits, -3)][grouped]"
		digits = copytext(digits, 1, -3)
	return "[digits][grouped]"

// =========================================================================
// THE WARDEN
// =========================================================================

/**
 * A prisoner spoke and the warden heard (life_answer_cell()). If they could buy their way out he comes over (or says
 * he can't, without his card) and TRUE is returned; FALSE leaves him to his usual reply.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/bribe_heard(mob/living/prisoner)
	if(istype(activity, /datum/ambient_activity/warden_bribe))
		return TRUE // already on his way to someone
	var/datum/outpost_police_cell/cell = police?.bribe_cell_for(prisoner)
	if(!cell || !police_can_speak() || case || npc_exit || dispatch_riding || dispatch_responding())
		return FALSE
	if(!bribe_has_card())
		police.bribe_wait[prisoner.mind] = world.time + OUTPOST_POLICE_BRIBE_WAIT
		if(!buckled)
			face_atom(prisoner)
		bribe_say(POLICE_LINE_BRIBE_NO_CARD)
		return TRUE
	if(!start_activity(new /datum/ambient_activity/warden_bribe(src, prisoner)))
		return FALSE
	bribe_say(POLICE_LINE_BRIBE_COMING)
	return TRUE

/// He goes to `prisoner`'s door in `cell` without being called (tick_bribes()), if he is at ease, has his card and it is within his walk. TRUE if he set off.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/bribe_visit(mob/living/prisoner, datum/outpost_police_cell/cell)
	if(activity && istype(activity, /datum/ambient_activity/warden_bribe))
		return FALSE // at someone's door already
	if(stat != CONSCIOUS || client || mind || !police_can_speak() || case || npc_exit || dispatch_riding || dispatch_responding() || !bribe_has_card())
		return FALSE
	var/datum/ai_controller/basic_controller/human_npc/stealth/brain = ai_controller
	if(istype(brain) && (brain.stealth_state() != STEALTH_UNAWARE || brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET)))
		return FALSE
	if(!cell?.outside_turf || cell.outside_turf.z != z || get_dist(src, cell.outside_turf) > OUTPOST_POLICE_BRIBE_WALK_REACH)
		return FALSE
	return !!start_activity(new /datum/ambient_activity/warden_bribe(src, prisoner))

/// Whether his own cell card is on him and still good
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/bribe_has_card()
	var/obj/item/card/id/advanced/outpost_sergeant/card = wear_id
	return istype(card) && !card.voided && card.on_own_sergeant()

/// Whether he stands by `cell`'s door, awake and free to deal
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/bribe_at_door(datum/outpost_police_cell/cell)
	if(QDELETED(src) || !police_can_speak() || case || npc_exit || dispatch_riding || !cell?.outside_turf)
		return FALSE
	return z == cell.outside_turf.z && get_dist(src, cell.outside_turf) <= OUTPOST_POLICE_BRIBE_REACH

/// Says a line of `context` from his zone's section, `values` filled in, whatever was said lately. The words, or null.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/proc/bribe_say(context, list/values)
	if(!police_can_speak())
		return null
	var/list/clean_values = outpost_police_values(values)
	var/list/pool = list()
	for(var/raw in ambient_dialogue_lines(AMBIENT_STRINGS_POLICE, life_voice_section(), context))
		var/filled = outpost_police_fill_line(raw, clean_values)
		if(filled)
			pool += filled
	pool = outpost_fresh_lines(pool, last_line)
	if(!length(pool))
		return null
	var/text = pick(pool)
	last_line = text
	next_line_at = max(next_line_at, world.time + 6 SECONDS)
	life_speak(text, FALSE)
	return text

/**
 * The warden goes to a cell door, names his price to the prisoner who called and waits for the answer. Ends when it
 * is given (bribe_answer()), the time runs out, or the prisoner can no longer be dealt with. Outranks the desk.
 */
/datum/ambient_activity/warden_bribe
	name = "seeing a prisoner"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = OUTPOST_POLICE_BRIBE_WALK
	duration_high = OUTPOST_POLICE_BRIBE_WALK
	var/datum/weakref/prisoner_ref
	var/datum/weakref/cell_ref
	/// The price named, once the offer is out
	var/price

/datum/ambient_activity/warden_bribe/setup()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = doer
	var/mob/living/prisoner = anchor()
	if(!istype(warden) || !isliving(prisoner))
		return FALSE
	var/datum/outpost_police_cell/cell = warden.police?.bribe_cell_for(prisoner)
	if(!cell)
		return FALSE
	prisoner_ref = WEAKREF(prisoner)
	cell_ref = WEAKREF(cell)
	go_to(cell.outside_turf, 1)
	set_duration()
	return TRUE

/datum/ambient_activity/warden_bribe/Destroy()
	prisoner_ref = null
	cell_ref = null
	return ..()

/// No way to the door: he gives up where he stands
/datum/ambient_activity/warden_bribe/spot_unreachable()
	. = ..()
	ends_at = world.time

/datum/ambient_activity/warden_bribe/arrive()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = doer
	var/mob/living/prisoner = prisoner_ref?.resolve()
	var/datum/outpost_police_cell/cell = cell_ref?.resolve()
	var/datum/outpost_police/police = warden?.police
	if(!police || !cell || police.bribe_cell_for(prisoner) != cell || !warden.bribe_at_door(cell))
		ends_at = world.time
		return
	if(!warden.buckled)
		warden.face_atom(prisoner)
	var/datum/mind/mind = prisoner.mind
	// One offer per call, whatever comes of it
	police.bribe_wait[mind] = world.time + OUTPOST_POLICE_BRIBE_WAIT
	if(!warden.bribe_has_card()) // taken off him on the way
		warden.bribe_say(POLICE_LINE_BRIBE_NO_CARD)
		ends_at = world.time
		return
	var/asking = police.bribe_price(mind)
	var/text = warden.bribe_say(POLICE_LINE_BRIBE_OFFER, list("price" = outpost_police_price_text(asking)))
	if(!text)
		ends_at = world.time
		return
	price = asking
	police.bribe_offers[mind] = asking
	// He has been: no call of his own on them after this
	cell.visit_due -= mind
	ends_at = world.time + OUTPOST_POLICE_BRIBE_ANSWER + 2 SECONDS
	// Only the prisoner can answer; one with nobody at the keys never does, and the offer lapses
	if(prisoner.client)
		INVOKE_ASYNC(police, TYPE_PROC_REF(/datum/outpost_police, bribe_ask), warden, prisoner, cell, text)

/datum/ambient_activity/warden_bribe/act(seconds)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = doer
	var/mob/living/prisoner = prisoner_ref?.resolve()
	var/datum/outpost_police_cell/cell = cell_ref?.resolve()
	if(!prisoner || !cell || warden?.police?.cell_holding(prisoner.mind) != cell)
		return AMBIENT_STEP_DONE
	if(!doer.buckled)
		doer.face_atom(prisoner)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/warden_bribe/finish()
	// An offer nobody answered lapses with him
	var/mob/living/prisoner = prisoner_ref?.resolve()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/sergeant/warden = doer
	if(prisoner?.mind && istype(warden) && warden.police && warden.police.bribe_offers[prisoner.mind] == price)
		warden.police.bribe_offers -= prisoner.mind
	return ..()
