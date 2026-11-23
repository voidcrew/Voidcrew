/**
 * # Outpost police: paying your way back in
 *
 * A crew banned from an outpost (the embargo of a four or five star incident, police_wanted.dm) or a person barred
 * from it (the bar a three star record leaves) can ask the checkpoint guard at his desk
 * (trade/outpost_checkpoint_guard.dm open_trader_menu()). He says how long is left and names a price to clear it
 * now. Pay takes the money from the crew's ship accounts together (charge_crew(), the fine's routine), ends the
 * incident, lifts the embargo on every ship of the crew and the payer's own bar. The money leaves the economy and
 * never comes back.
 *
 * Nothing is told or sold to someone with stars: they are refused as before, and arrested. Nothing happens while the
 * guard is not serving at his desk (shop.is_open(): dead, out cold, away from it, held up, or a player in his body).
 * The time and no price: an embargo the police did not lay (an admin's), which is not theirs to sell. Neither: a
 * crewmate still at four stars or more here, whose stars would lay the ban again on the next tick (tick_warrants()).
 *
 * Each pay-off a crew makes at one outpost doubles its next one there, OUTPOST_POLICE_PAYOFF_DOUBLINGS times at the
 * most (payoff_paid: by the crew's id, and by the ckeys on the crew when it paid, so leaving and coming back or
 * moving to another crew keeps the count). A crime afterwards is a crime like any other: at four stars the crew is
 * banned again.
 *
 * Round metric (METRIC_COMBAT): police_payoff. ckey = the payer, subject = "ban" or "bar", points = the ban's stars
 * (0 for a bar), quantity = how many pay-offs that crew has now made here. The money shows as the ship accounts' own
 * ship_account_change rows ("Entry fee: <force name>").
 */

/datum/outpost_police
	/// Pay-offs made here: "crew <crew_id>", and the ckey of everyone on a crew when it paid -> how many
	var/list/payoff_paid = list()
	/// Offers out now: weakref to a mind -> list(the price named, OUTPOST_POLICE_PAYOFF_KIND_*)
	var/list/payoff_offers = list()
	/// Who the guard has just answered: weakref to a mind -> world.time he will answer them again
	var/list/payoff_wait = list()

/// How many pay-offs `payer`'s crew has made here, or `payer` with any crew they were on
/datum/outpost_police/proc/payoff_times(datum/mind/payer)
	. = 0
	var/datum/voidcrew_crew_record/crew = payer?.get_reputation_crew()
	if(crew)
		. = payoff_paid["crew [crew.crew_id]"] || 0
	var/player = ckey(payer?.key)
	if(player)
		. = max(., payoff_paid[player] || 0)

/**
 * What refuses `user` here that time or money would clear, or null: someone with stars is arrested, not served, and
 * someone nothing refuses has nothing to ask. A list: "kind" (OUTPOST_POLICE_PAYOFF_KIND_*), "left" (deciseconds
 * until they may come in), "stars" (the ban's, 0 for a bar), "price" (what the guard takes to clear it now, or 0 with
 * "why": OUTPOST_POLICE_PAYOFF_NOT_OURS or OUTPOST_POLICE_PAYOFF_CREW_WANTED).
 */
/datum/outpost_police/proc/payoff_quote(mob/living/user)
	var/datum/mind/mind = user?.mind
	if(!mind || !outpost || get_stars(mind) >= 1)
		return null
	var/datum/outpost_warrant/warrant = warrants[mind]
	var/until = (warrant && warrant.barred_until > world.time) ? warrant.barred_until : 0
	var/datum/voidcrew_crew_record/crew = mind.get_reputation_crew()
	var/datum/outpost_incident/incident = crew ? incidents[crew] : null
	if(incident && world.time >= incident.ends_at)
		incident = null
	var/banned = FALSE
	var/ours = TRUE
	for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(crew))
		if(!outpost.is_ship_embargoed(ship))
			continue
		banned = TRUE
		var/ship_until = outpost.embargoed_ships[ship]
		until = max(until, ship_until)
		// An embargo with no incident behind it, or one that outlasts it, is an admin's
		if(!incident || ship_until > incident.ends_at)
			ours = FALSE
	if(until <= world.time)
		return null
	. = list(
		"kind" = banned ? OUTPOST_POLICE_PAYOFF_KIND_BAN : OUTPOST_POLICE_PAYOFF_KIND_BAR,
		"left" = until - world.time,
		"stars" = (banned && incident) ? incident.stars : 0,
		"price" = 0,
	)
	var/base = OUTPOST_POLICE_PAYOFF_BAR
	if(banned)
		if(!ours)
			.["why"] = OUTPOST_POLICE_PAYOFF_NOT_OURS
			return
		// Typed: a hard-deleted mind leaves a null in the list
		for(var/datum/mind/mate in crew.minds)
			if(get_stars(mate) >= 4)
				.["why"] = OUTPOST_POLICE_PAYOFF_CREW_WANTED
				return
		var/list/prices = OUTPOST_POLICE_PAYOFF_BAN
		base = prices[clamp(incident.stars - 3, 1, length(prices))]
	.["price"] = round(base * (profile?.fine_multiplier || 1)) * (2 ** min(payoff_times(mind), OUTPOST_POLICE_PAYOFF_DOUBLINGS))

/**
 * `user` is at `guard`'s desk. If something refuses them that time or money would clear, the guard says how long is
 * left and, where it is his to sell, his price. Returns null when there is nothing of the kind (the caller carries
 * on: the menu, or the usual refusal); the words of a priced offer now out to `user` (payoff_offers, answered
 * through payoff_answer()); or "" when he has dealt with them and there is nothing to answer. Never waits.
 */
/datum/outpost_police/proc/payoff_ask(mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard, mob/living/user)
	// Only at his desk, serving, with them at it (dead, out cold, away, held up or played, he deals with nobody)
	if(QDELETED(guard) || !guard.shop || !guard.check_menu(user))
		return null
	var/list/quote = payoff_quote(user)
	if(!quote)
		return null
	var/datum/weakref/who = WEAKREF(user.mind)
	// He has just told them, is waiting on their answer, or is still talking
	if(!isnull(payoff_offers[who]) || payoff_wait[who] > world.time || !COOLDOWN_FINISHED(guard, speak_cooldown))
		return ""
	for(var/datum/weakref/asked as anything in payoff_wait)
		if(payoff_wait[asked] <= world.time)
			payoff_wait -= asked
	payoff_wait[who] = world.time + OUTPOST_POLICE_PAYOFF_WAIT
	if(!guard.buckled)
		guard.face_atom(user)
	if(quote["why"] == OUTPOST_POLICE_PAYOFF_CREW_WANTED)
		guard.payoff_say(POLICE_LINE_PAYOFF_CREW)
		return ""
	var/time = outpost_police_wait_text(quote["left"])
	if(!quote["price"])
		guard.payoff_say(POLICE_LINE_PAYOFF_TIME, list("time" = time))
		return ""
	var/text = guard.payoff_say(POLICE_LINE_PAYOFF_OFFER, list("time" = time, "price" = outpost_police_price_text(quote["price"])))
	if(!text)
		return ""
	payoff_offers[who] = list(quote["price"], quote["kind"])
	return text

/// Shows `user` the price the guard just said, and hands their answer back. Sleeps (the prompt).
/datum/outpost_police/proc/payoff_prompt(mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard, mob/living/user, text)
	var/datum/mind/payer = user.mind
	var/answer = tgui_alert(user, text, guard.name, list("Pay", "No"), OUTPOST_POLICE_PAYOFF_ANSWER)
	if(QDELETED(src))
		return
	payoff_answer(guard, payer, answer == "Pay")

/// `payer`'s answer to the price the guard named: one answer to one offer. TRUE if they paid and it was lifted.
/datum/outpost_police/proc/payoff_answer(mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard, datum/mind/payer, pay)
	var/datum/weakref/who = WEAKREF(payer)
	var/list/offer = who ? payoff_offers[who] : null
	if(!offer)
		return FALSE
	payoff_offers -= who
	if(!pay || QDELETED(payer))
		return FALSE
	return payoff_take(guard, payer.current, offer[1], offer[2])

/// Takes `price` from `user`'s crew for the `kind` the guard named it for and lifts that, or takes nothing. Never waits.
/datum/outpost_police/proc/payoff_take(mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/guard, mob/living/user, price, kind)
	// Looked at again from the top: he still serves at his desk, they still stand at it, and the deal is the one he named
	if(QDELETED(guard) || QDELETED(user) || !guard.shop || !guard.check_menu(user))
		return FALSE
	var/datum/mind/payer = user.mind
	var/list/quote = payoff_quote(user)
	if(!quote || quote["price"] != price || quote["kind"] != kind)
		// Something changed while they made up their mind (a crewmate paid, the ban ran out or grew): asked again, he says how it stands
		if(payer)
			payoff_wait -= WEAKREF(payer)
		return FALSE
	var/list/taken = payoff_charge(payer, price, "Entry fee: [profile?.force_name || "outpost security"]")
	if(isnull(taken))
		guard.payoff_say(POLICE_LINE_PAYOFF_SHORT)
		return FALSE
	// The money is gone, and nothing below can fail
	var/datum/voidcrew_crew_record/crew = payer.get_reputation_crew()
	var/times = payoff_times(payer) + 1
	var/list/players = list()
	if(crew)
		payoff_paid["crew [crew.crew_id]"] = times
		players += crew.ckeys
	players |= ckey(payer.key)
	for(var/player in players)
		if(player)
			payoff_paid[player] = max(payoff_paid[player] || 0, times)
	if(kind == OUTPOST_POLICE_PAYOFF_KIND_BAN)
		payoff_lift_ban(crew)
	var/datum/outpost_warrant/warrant = warrants[payer]
	if(warrant)
		warrant.barred_until = 0
	log_game("OUTPOST POLICE: [key_name(user)] paid the checkpoint guard [price] cr to lift a [kind] at [outpost] ([AREACOORD(guard)]), pay-off [times] of their crew here.")
	record_metric(METRIC_COMBAT, "police_payoff", actor = user, subject = kind, points = quote["stars"], quantity = times)
	guard.payoff_say(POLICE_LINE_PAYOFF_TAKEN)
	return TRUE

/**
 * Takes `amount` from the ship accounts of the crew `payer` is on, all or nothing: charge_crew(), which finds the crew
 * by a warrant. A crewmate of the banned with no record of their own is given one for the length of the call.
 */
/datum/outpost_police/proc/payoff_charge(datum/mind/payer, amount, reason)
	var/datum/outpost_warrant/warrant = warrants[payer]
	if(warrant)
		return charge_crew(warrant, amount, reason)
	warrant = new
	warrant.mind = payer
	. = charge_crew(warrant, amount, reason)
	qdel(warrant)

/// `crew`'s ban here is over: the incident is forgotten and every ship of theirs it holds is let go
/datum/outpost_police/proc/payoff_lift_ban(datum/voidcrew_crew_record/crew)
	if(QDELETED(crew))
		return
	for(var/obj/structure/overmap/ship/ship as anything in crew_ship_list(crew))
		if(!outpost.is_ship_embargoed(ship))
			continue
		outpost.embargoed_ships -= ship
		ship.ship_notify("[outpost.name] has lifted the trade embargo on your vessel.", "TRADE EMBARGO", SHIP_NOTIFY_NOTICE)
	var/datum/outpost_incident/incident = incidents[crew]
	if(incident)
		end_incident(incident)

/// How a person at a desk says how long `time` (deciseconds) is: "about ten minutes", "a quarter of an hour"
/proc/outpost_police_wait_text(time)
	var/minutes = time / (1 MINUTES)
	if(minutes <= 1.5)
		return "a minute or so"
	if(minutes <= 3.5)
		return "a couple of minutes"
	if(minutes <= 7.5)
		return "about five minutes"
	if(minutes <= 12.5)
		return "about ten minutes"
	if(minutes <= 17.5)
		return "a quarter of an hour"
	if(minutes <= 22.5)
		return "about twenty minutes"
	if(minutes <= 27.5)
		return "about twenty-five minutes"
	if(minutes <= 37.5)
		return "half an hour"
	if(minutes <= 52.5)
		return "about three quarters of an hour"
	if(minutes <= 90)
		return "about an hour"
	if(minutes <= 150)
		return "a couple of hours"
	return "a good few hours"

/// Fills %TIME% and %PRICE% in one of the guard's lines from `values`, or returns null when it needs one the caller lacks
/proc/outpost_police_payoff_fill(line, list/values)
	if(!istext(line))
		return null
	if(findtext(line, "%TIME%"))
		var/time = islist(values) ? values["time"] : null
		if(!time)
			return null
		line = replacetext(line, "%TIME%", time)
	return outpost_police_fill_line(line, values)

// =========================================================================
// THE GUARD
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard
	/// The last thing he said about a ban, so he does not say it twice running
	var/payoff_last_line

/// Says a line of `context` from his outpost's section of the police file, `values` filled in. The words, or null.
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/checkpoint_guard/proc/payoff_say(context, list/values)
	if(QDELETED(src) || !human_npc_can_talk(src))
		return null
	var/list/clean_values = outpost_police_values(values)
	var/list/pool = list()
	for(var/raw in ambient_dialogue_lines(AMBIENT_STRINGS_POLICE, outpost?.police?.profile?.voice_section || "halcyon", context))
		var/filled = outpost_police_payoff_fill(raw, clean_values)
		if(filled)
			pool += filled
	pool = outpost_fresh_lines(pool, payoff_last_line)
	if(!length(pool))
		return null
	var/text = pick(pool)
	payoff_last_line = text
	COOLDOWN_START(src, speak_cooldown, 3 SECONDS)
	say(text)
	return text
