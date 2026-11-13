/**
 * # Outpost recovery: the trader stick-up
 *
 * Owner: R7 (spec-rehydrate.md section 10, M37, M38, M40). tg's own right-click hold-up
 * (/datum/component/gunpoint) on a trader at its counter: hands up, the till (or one cheap shelf item) handed
 * over when the hold steadies, and the alarm (OUTPOST_CRIME_ARMED_ROBBERY) when the robber leaves its sight,
 * 30 s after the hand-over, or the moment the robber fires or hits anyone. Takings count against the outpost's
 * shared loss cap (recovery.loss_room(), note_loss()). The gate emag (section 9) is R7's too, in
 * trade/outpost_checkpoint.dm.
 *
 * The trader's three procs are frozen one-line forwarders: R1's path rename changes their declaration lines and
 * R7 never edits them, so the two merge cleanly. R7's logic lives on the shop (the till is the shop's anyway) and
 * in outpost_holdup_hook(), below the forwarders. The trader type is never named below them (the trader is a
 * /mob/living, its shop found through the outpost), so R1's path rename leaves everything R7 wrote alone.
 *
 * The gate emag is in trade/outpost_checkpoint.dm. This file only tells the police that a scanner whose gate is
 * down is no camera (is_camera(), scanned()).
 */

/// The hold is steady (tg's gunpoint reaches stage 2) 2.5 s after it starts, then the trader hands over what it
/// has. The extra half second is margin: the stage itself is checked before anything is handed over.
#define OUTPOST_HOLDUP_STEADY (3 SECONDS)

/datum/outpost_shop
	/// world.time the till pays again; 0 = it is full (R7). On the shop, not the person: a replacement keeper
	/// has the same empty till (SU9).
	var/till_ready_at = 0
	/// Weakref to the mind that emptied the till last, or null (R7). A keeper robbed since the last convoy drops
	/// nothing when killed (R1 reads it in drop_from_shelf(), M37). Cleared by the convoy.
	var/datum/weakref/till_robbed_by
	/// What the empty till has handed over since it was emptied: 1 = its one cheap shelf item, and after that nothing (R7)
	var/till_extras = 0
	/// The stick-up in progress at this counter, if any (R7)
	var/datum/outpost_holdup/holdup

// =========================================================================
// THE TRADER'S SIDE: frozen forwarders (R0). R1 renames the path on these lines; R7 never edits them.
// =========================================================================

/// Called once from the trader's Initialize (trade/trader_npc.dm): registers what the stick-up listens to
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/hook_holdup()
	outpost_holdup_hook(src)

/// The trader reports the robbery from its counter (OUTPOST_CRIME_ARMED_ROBBERY, the gun as source)
/mob/living/carbon/human/npc/ambient_npc/outpost/trader/proc/raise_alarm()
	shop?.raise_holdup_alarm(src)

// =========================================================================
// THE STICK-UP (R7)
// =========================================================================

/// The one watcher for every trader in the world: it hears tg's hold-up land on a trader (below) and the supply convoy
GLOBAL_DATUM_INIT(outpost_holdups, /datum/outpost_holdup_watcher, new)

/datum/outpost_holdup_watcher
	/// Every stick-up in progress
	var/list/datum/outpost_holdup/active = list()

/**
 * `trader` was just made: register what tells it it is held up (tg's /datum/status_effect/grouped/heldup lands on
 * it; COMSIG_LIVING_STATUS_APPLIED). tg sends nothing of its own for a hold-up and applies that status from inside
 * the gunpoint component's Initialize, so the shooter is looked for a moment later. Runs from Initialize: never sleeps.
 */
/proc/outpost_holdup_hook(mob/living/trader)
	if(QDELETED(trader))
		return
	GLOB.outpost_holdups.watch(trader)

/datum/outpost_holdup_watcher/proc/watch(mob/living/trader)
	RegisterSignal(trader, COMSIG_LIVING_STATUS_APPLIED, PROC_REF(on_status_applied), override = TRUE)
	RegisterSignal(trader, COMSIG_CARBON_CUFF_ATTEMPTED, PROC_REF(on_cuff_attempted), override = TRUE)

/// Someone tries to cuff a living trader: assault on the staff, as grabbing one is (abuse SF6: cuffs never silence a stick-up for free)
/datum/outpost_holdup_watcher/proc/on_cuff_attempted(mob/living/source, mob/living/user)
	SIGNAL_HANDLER
	if(source.stat == DEAD || !isliving(user) || user == source)
		return
	var/mob/living/carbon/human/npc/ambient_npc/outpost/trader/trader = source
	if(istype(trader))
		trader.outpost?.register_aggression(user, OUTPOST_CRIME_ASSAULT_STAFF, trader)

/// Registers once per outpost, at its first stick-up: the supply convoy forgets who emptied a till (M37)
/datum/outpost_holdup_watcher/proc/watch_convoy(obj/structure/overmap/trader_outpost/outpost)
	if(outpost)
		RegisterSignal(outpost, COMSIG_TRADER_OUTPOST_CONVOY, PROC_REF(on_convoy), override = TRUE)

/datum/outpost_holdup_watcher/proc/on_convoy(obj/structure/overmap/trader_outpost/source)
	SIGNAL_HANDLER
	for(var/datum/outpost_shop/shop as anything in source.get_all_shops())
		if(shop)
			shop.till_robbed_by = null

/datum/outpost_holdup_watcher/proc/on_status_applied(mob/living/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(!istype(effect, /datum/status_effect/grouped/heldup))
		return
	// The shooter is on the effect's sources only once the component has finished, and the component is on the shooter
	addtimer(CALLBACK(src, PROC_REF(resolve_hold), WEAKREF(source), WEAKREF(effect)), 1, TIMER_DELETE_ME)

/// Finds who holds `trader_ref` up and hands the hold to the trader's shop
/datum/outpost_holdup_watcher/proc/resolve_hold(datum/weakref/trader_ref, datum/weakref/effect_ref)
	var/mob/living/trader = trader_ref.resolve()
	var/datum/status_effect/effect = effect_ref.resolve()
	if(QDELETED(trader) || QDELETED(effect) || effect.owner != trader)
		return
	// The gunpoint keeps its shooter within 2 tiles of the target
	for(var/mob/living/candidate in orange(3, trader))
		var/datum/component/gunpoint/hold = candidate.GetComponent(/datum/component/gunpoint)
		if(hold?.target != trader)
			continue
		var/datum/outpost_shop/shop = outpost_holdup_shop(trader)
		shop?.held_up(trader, candidate, hold.weapon)
		return

/// A crime counted against `robber` is the robbery of one of the stick-ups in progress: the trader's alarm need not count it again
/datum/outpost_holdup_watcher/proc/note_counted(mob/living/robber)
	for(var/datum/outpost_holdup/holdup in active)
		if(holdup.robber_ref?.resolve() == robber)
			holdup.counted = TRUE

/// The shop `trader` keeps, or null (found through the outpost, so no trader type is named here)
/proc/outpost_holdup_shop(mob/living/trader)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(trader))
	if(!outpost)
		return null
	for(var/datum/outpost_shop/shop as anything in outpost.get_all_shops())
		if(shop && shop.trader_npc == trader)
			return shop
	return null

/**
 * One line of `key` (ROBBERY_LINE_*) in the zone's voice, with `values` ("place", "look") filled in, or null. The
 * lines are in ambient_npcs/strings/outpost_robbery.json, one section per zone (the police profile's voice_section).
 */
/proc/outpost_robbery_line(datum/outpost_police/police, key, list/values)
	var/section = police?.profile?.voice_section || "halcyon"
	var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_ROBBERY, section, key)
	if(!length(lines))
		return null
	return outpost_police_pick_line(lines, outpost_police_values(values))

// ----- the shop's side -----

/**
 * `trader`, keeping this shop, is held up by `robber` with `weapon`: hands up, then the hand-over when the hold steadies.
 * Only a trader at its counter (the keeper, awake) with a till pays: not a gate guard (he has permits and nothing
 * else, M40), not a player, and not for anyone without a mind (nobody could be wanted for it).
 */
/datum/outpost_shop/proc/held_up(mob/living/trader, mob/living/robber, obj/item/gun/weapon)
	if(QDELETED(src) || QDELETED(trader) || QDELETED(robber) || !robber.mind || !outpost?.police)
		return
	if(istype(src, /datum/outpost_shop/vendor/checkpoint) || trader.client || trader.mind)
		return
	if(trader.stat != CONSCIOUS || keeper?.resolve() != trader || get_dist(trader, holdup_counter(trader)) > 1)
		return
	if(holdup)
		// The same robber pointing again while the alarm is still out: another hand-over (an empty till gives less)
		if(holdup.robber_ref?.resolve() == robber)
			holdup.rehold(weapon)
			return
		if(holdup.holding)
			return
		// First robber lowered their gun while the alarm is still pending: leave that holdup in active so its alarm
		// still fires, and start a fresh hold so the trader pauses for the new gunpoint instead of getting shot.
		holdup = null
	GLOB.outpost_holdups.watch_convoy(outpost)
	holdup = new /datum/outpost_holdup(src, trader, robber, weapon)

/// The tile `trader` keeps the counter on: the ambient NPC's home (the keeper's counter tile, set when it takes the counter), else wherever it stands
/datum/outpost_shop/proc/holdup_counter(mob/living/trader)
	if(istype(trader, /mob/living/carbon/human/npc/ambient_npc))
		var/mob/living/carbon/human/npc/ambient_npc/keeper_npc = trader
		if(keeper_npc.home)
			return keeper_npc.home
	return get_turf(trader)

/// The emptied till is full again (OUTPOST_HOLDUP_TILL_REFILL after it was emptied): nobody has "robbed" this counter any more, and the death drop is back (M37)
/datum/outpost_shop/proc/till_refilled()
	if(QDELETED(src) || world.time < till_ready_at)
		return
	till_robbed_by = null
	till_extras = 0

/**
 * `trader` reports the robbery of this shop: OUTPOST_CRIME_ARMED_ROBBERY against the robber, the gun as source. A
 * trader who is dead, out cold, tied up or off its counter reports nothing (decision 19). Counts once per stick-up.
 */
/datum/outpost_shop/proc/raise_holdup_alarm(mob/living/trader)
	holdup?.try_alarm(TRUE)
	for(var/datum/outpost_holdup/past as anything in GLOB.outpost_holdups.active.Copy())
		if(!QDELETED(past) && past.shop == src)
			past.try_alarm(TRUE)

/**
 * Whether `trader` can still work the counter and the alarm under it: awake, not tied up or stunned, still the
 * keeper, and within a tile of the counter tile `counter` it was held up on.
 */
/datum/outpost_shop/proc/holdup_trader_able(mob/living/trader, turf/counter)
	if(QDELETED(src) || QDELETED(trader) || trader.stat != CONSCIOUS || keeper?.resolve() != trader)
		return FALSE
	if(counter && get_dist(trader, counter) > 1)
		return FALSE
	return outpost?.police ? outpost.police.perception.can_report(trader) : TRUE

/**
 * What the till gives `robber` now, put in their free hand or else on the counter between them: a holochip of
 * OUTPOST_HOLDUP_TILL times the zone's multiplier while the till is full; once it is empty (until
 * OUTPOST_HOLDUP_TILL_REFILL later) one shelf item worth at most OUTPOST_HOLDUP_ITEM_CAP; after that nothing. All of it
 * within the outpost's shared loss room, and none of it for anyone whose stock was never the shop's to give.
 * Returns the thing handed over, or null.
 */
/datum/outpost_shop/proc/holdup_take(mob/living/trader, mob/living/robber)
	var/datum/outpost_police/police = outpost?.police
	var/datum/outpost_recovery/recovery = outpost?.recovery
	if(!police || !recovery || !robber.mind)
		return null
	var/room = recovery.loss_room()
	var/turf/counter = get_step(trader, get_dir(trader, robber))
	if(!counter || counter.density)
		counter = get_turf(trader)
	var/obj/item/taken
	var/list/record = list("shop" = WEAKREF(src))
	if(world.time >= till_ready_at)
		till_extras = 0
		var/pay = min(round(OUTPOST_HOLDUP_TILL * (police.profile?.fine_multiplier || 1)), room)
		if(pay > 0)
			taken = new /obj/item/holochip(counter, pay)
			record["amount"] = pay
			recovery.note_loss(pay)
			till_ready_at = world.time + OUTPOST_HOLDUP_TILL_REFILL
			addtimer(CALLBACK(src, PROC_REF(till_refilled)), OUTPOST_HOLDUP_TILL_REFILL, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
	else if(till_extras < 1)
		var/datum/shop_sku/sku = holdup_pick_sku(room)
		if(sku)
			var/atom/movable/goods = create_trader_goods(sku.item_path, counter, sku.dispense_amount)
			var/atom/movable/handed = outpost_seal_goods(goods)
			mark_trader_goods(handed)
			if(isitem(handed))
				taken = handed
			sku.stock--
			record["sku"] = WEAKREF(sku)
			recovery.note_loss(sku.get_credit_price())
			till_extras++
	if(!taken)
		return null
	till_robbed_by = WEAKREF(robber.mind)
	// Stolen property: it goes back where it came from at the arrest (evidence_candidates(), evidence_empty_case())
	police.mark_stolen(taken, robber.mind)
	// Takings that were destroyed since the last stick-up are dropped here, so the list stays small all round
	for(var/datum/weakref/old_ref in police.takings?.Copy())
		if(QDELETED(old_ref.resolve()))
			police.takings -= old_ref
	LAZYSET(police.takings, WEAKREF(taken), record)
	if(!robber.put_in_hands(taken))
		taken.forceMove(counter)
	return taken

/// A random shelf item in stock that a quick grab could be: a plain item for credits, worth at most OUTPOST_HOLDUP_ITEM_CAP and `room`, no gun
/datum/outpost_shop/proc/holdup_pick_sku(room)
	var/list/datum/shop_sku/options = list()
	for(var/datum/shop_sku/sku as anything in skus)
		if(QDELETED(sku) || sku.shelf == SHELF_FAVOR || sku.is_chart || sku.zone_permission != ZONE_PERMISSION_PUBLIC)
			continue
		if(sku.stock - sku.reserved_stock <= 0 || sku.price_vouchers > 0 || istype(sku, /datum/shop_sku/barter))
			continue
		if(!ispath(sku.item_path, /obj/item) || is_ladder_combat_gun(sku.item_path))
			continue
		var/value = sku.get_credit_price()
		if(value <= 0 || value > OUTPOST_HOLDUP_ITEM_CAP || value > room)
			continue
		options += sku
	if(!length(options))
		return null
	return pick(options)

// ----- one stick-up -----

/**
 * One hold-up of one trader by one robber, from the moment tg's gunpoint lands until the alarm is settled and the
 * hold is over. It keeps the trader still (the gunpoint fires on a target that moves), hands over the takings when the
 * hold steadies, and raises the trader's alarm (spec-rehydrate.md 10): when the robber is out of the trader's sight or
 * more than OUTPOST_HOLDUP_ALARM_RANGE tiles off, OUTPOST_HOLDUP_ALARM_DELAY after the hand-over whatever happens, or
 * the moment the robber fires or hits anyone. A trader who is dead raises none; one out cold, tied up or off its
 * counter raises it once able again.
 */
/datum/outpost_holdup
	var/datum/outpost_shop/shop
	var/datum/weakref/trader_ref
	var/datum/weakref/robber_ref
	var/datum/weakref/weapon_ref
	/// The trader's counter tile: dragged more than a tile off it, it cannot reach the alarm
	var/turf/counter_turf
	/// tg's hold is still on the trader
	var/holding = TRUE
	/// Something (or nothing, from an empty till) has been handed over: the alarm clock is running
	var/handed_over = FALSE
	/// OUTPOST_CRIME_ARMED_ROBBERY has been counted against the robber for this (by anyone): count_crime() sets it
	var/counted = FALSE
	/// The alarm has gone out, or can never go out
	var/alarm_done = FALSE
	/// The alarm's time came while the trader could not reach it: it goes the moment they can (abuse SF6, M38)
	var/alarm_overdue = FALSE
	var/steady_timer
	var/steady_tries = 0
	var/alarm_timer
	var/watch_timer

/datum/outpost_holdup/New(datum/outpost_shop/new_shop, mob/living/trader, mob/living/robber, obj/item/gun/weapon)
	. = ..()
	shop = new_shop
	trader_ref = WEAKREF(trader)
	robber_ref = WEAKREF(robber)
	weapon_ref = WEAKREF(weapon)
	counter_turf = new_shop.holdup_counter(trader)
	GLOB.outpost_holdups.active += src
	// The gunpoint shoots a target that moves, so the trader holds still for it
	ADD_TRAIT(trader, TRAIT_AI_PAUSED, REF(src))
	RegisterSignal(trader, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(on_status_removed))
	RegisterSignal(robber, COMSIG_MOB_FIRED_GUN, PROC_REF(on_fired))
	RegisterSignal(robber, COMSIG_MOB_ITEM_ATTACK, PROC_REF(on_item_attack))
	RegisterSignal(robber, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	trader_says(ROBBERY_LINE_HANDS_UP)
	start_steady()
	report_to_others()

/datum/outpost_holdup/Destroy()
	deltimer(steady_timer)
	deltimer(alarm_timer)
	deltimer(watch_timer)
	steady_timer = alarm_timer = watch_timer = null
	GLOB.outpost_holdups.active -= src
	var/mob/living/trader = trader_ref?.resolve()
	if(trader)
		REMOVE_TRAIT(trader, TRAIT_AI_PAUSED, REF(src))
		UnregisterSignal(trader, COMSIG_LIVING_STATUS_REMOVED)
	var/mob/living/robber = robber_ref?.resolve()
	if(robber)
		UnregisterSignal(robber, list(COMSIG_MOB_FIRED_GUN, COMSIG_MOB_ITEM_ATTACK, COMSIG_LIVING_UNARMED_ATTACK))
	if(shop?.holdup == src)
		shop.holdup = null
	shop = null
	counter_turf = null
	return ..()

/// The same robber points again while the alarm is still out
/datum/outpost_holdup/proc/rehold(obj/item/gun/weapon)
	if(alarm_done)
		return
	holding = TRUE
	var/mob/living/trader = trader_ref?.resolve()
	if(trader)
		ADD_TRAIT(trader, TRAIT_AI_PAUSED, REF(src))
	if(weapon)
		weapon_ref = WEAKREF(weapon)
	trader_says(ROBBERY_LINE_HANDS_UP)
	start_steady()
	report_to_others()

/// Said by the trader in the zone's voice (outpost_robbery.json); nothing if it cannot speak
/datum/outpost_holdup/proc/trader_says(key)
	var/mob/living/trader = trader_ref?.resolve()
	if(QDELETED(trader) || trader.stat != CONSCIOUS)
		return
	var/line = outpost_robbery_line(shop?.outpost?.police, key)
	if(line)
		INVOKE_ASYNC(trader, TYPE_PROC_REF(/atom/movable, say), line)

/datum/outpost_holdup/proc/start_steady()
	deltimer(steady_timer)
	steady_tries = 0
	steady_timer = addtimer(CALLBACK(src, PROC_REF(check_steady)), OUTPOST_HOLDUP_STEADY, TIMER_STOPPABLE | TIMER_DELETE_ME)

/// tg's hold has run its course: over once nothing is held and the alarm is settled (or nothing was handed over)
/datum/outpost_holdup/proc/maybe_end()
	if(holding || (handed_over && !alarm_done))
		return
	qdel(src)

/// The hold ended (the robber lowered the gun, left, or the trader was moved or shot)
/datum/outpost_holdup/proc/on_status_removed(mob/living/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(!istype(effect, /datum/status_effect/grouped/heldup))
		return
	holding = FALSE
	REMOVE_TRAIT(source, TRAIT_AI_PAUSED, REF(src))
	deltimer(steady_timer)
	steady_timer = null
	maybe_end()

/// The hold has been on for OUTPOST_HOLDUP_STEADY: when tg says it is steady and the trader is still at its counter, it pays
/datum/outpost_holdup/proc/check_steady()
	steady_timer = null
	var/mob/living/trader = trader_ref?.resolve()
	var/mob/living/robber = robber_ref?.resolve()
	if(QDELETED(trader) || QDELETED(robber) || !holding)
		return settle_if_lost(trader)
	var/datum/component/gunpoint/hold = robber.GetComponent(/datum/component/gunpoint)
	if(hold?.target != trader)
		holding = FALSE
		return maybe_end()
	if(hold.stage < 2)
		if(++steady_tries <= 5)
			steady_timer = addtimer(CALLBACK(src, PROC_REF(check_steady)), 1 SECONDS, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return
	hand_over(trader, robber)

/// The trader or robber is gone: nothing more can be handed over, and a dead or deleted trader raises no alarm
/datum/outpost_holdup/proc/settle_if_lost(mob/living/trader)
	if(QDELETED(trader) || trader.stat == DEAD)
		settle()
		return
	maybe_end()

/// The till, or what is left of it, to the robber; the alarm clock starts with the first hand-over
/datum/outpost_holdup/proc/hand_over(mob/living/trader, mob/living/robber)
	if(!shop?.holdup_trader_able(trader, counter_turf))
		return
	handed_over = TRUE
	var/obj/item/taken = shop.holdup_take(trader, robber)
	trader_says(istype(taken, /obj/item/holochip) ? ROBBERY_LINE_HAND_OVER : ROBBERY_LINE_EMPTY)
	report_to_others()
	if(alarm_timer || alarm_done)
		return
	alarm_timer = addtimer(CALLBACK(src, PROC_REF(timed_alarm)), OUTPOST_HOLDUP_ALARM_DELAY, TIMER_STOPPABLE | TIMER_DELETE_ME)
	watch_timer = addtimer(CALLBACK(src, PROC_REF(watch_robber)), 1 SECONDS, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)

/// OUTPOST_HOLDUP_ALARM_DELAY after the hand-over: the alarm goes whatever the robber is doing, if the trader can still press it
/datum/outpost_holdup/proc/timed_alarm()
	alarm_timer = null
	try_alarm(TRUE)

/// Once a second after the hand-over: the robber out of the trader's sight, or too far off, and the alarm goes
/datum/outpost_holdup/proc/watch_robber()
	if(alarm_done)
		return
	var/mob/living/trader = trader_ref?.resolve()
	var/mob/living/robber = robber_ref?.resolve()
	if(QDELETED(trader) || QDELETED(robber))
		settle()
		return
	if(alarm_overdue)
		try_alarm()
		return
	var/datum/outpost_police_perception/perception = shop?.outpost?.police?.perception
	if(get_dist(trader, robber) > OUTPOST_HOLDUP_ALARM_RANGE || !perception?.sees(trader, robber))
		try_alarm()

/// The robber fired a gun: the alarm goes at once
/datum/outpost_holdup/proc/on_fired(datum/source)
	SIGNAL_HANDLER
	try_alarm()

/// The robber hit someone with something in hand
/datum/outpost_holdup/proc/on_item_attack(mob/living/source, mob/living/target, mob/living/user)
	SIGNAL_HANDLER
	if(isliving(target) && target != source)
		try_alarm()

/// The robber hit someone with a fist (the signal fires on every empty-hand click, so only combat mode counts)
/datum/outpost_holdup/proc/on_unarmed_attack(mob/living/source, atom/target, proximity, modifiers)
	SIGNAL_HANDLER
	if(source.combat_mode && isliving(target) && target != source)
		try_alarm()

/**
 * The trader raises the alarm: OUTPOST_CRIME_ARMED_ROBBERY against the robber with the gun as source, counted once, and
 * the desk relays it on the radio. A trader that is dead or gone never will; one that is stunned, tied up or dragged
 * off its counter is tried again by the next trigger, and after `final` (the 30 s timer) every second until it can
 * (abuse SF6, M38: "at 30 s regardless", so cuffing the trader for 30 seconds silences nothing).
 */
/datum/outpost_holdup/proc/try_alarm(final = FALSE)
	if(alarm_done)
		return
	var/mob/living/trader = trader_ref?.resolve()
	var/mob/living/robber = robber_ref?.resolve()
	if(QDELETED(trader) || QDELETED(robber) || !robber.mind || trader.stat == DEAD)
		settle()
		return
	if(!shop?.holdup_trader_able(trader, counter_turf))
		if(final && !alarm_overdue)
			alarm_overdue = TRUE
			if(!watch_timer)
				watch_timer = addtimer(CALLBACK(src, PROC_REF(watch_robber)), 1 SECONDS, TIMER_STOPPABLE | TIMER_LOOP | TIMER_DELETE_ME)
		return
	var/datum/outpost_police/police = shop.outpost?.police
	if(!counted && police)
		police.count_crime(robber, OUTPOST_CRIME_ARMED_ROBBERY, null, weapon_ref?.resolve())
		relay_alarm(trader, robber)
	settle()

/// The alarm is settled, rung or not: no more timers. Over with the hold.
/datum/outpost_holdup/proc/settle()
	alarm_done = TRUE
	deltimer(steady_timer)
	deltimer(alarm_timer)
	deltimer(watch_timer)
	steady_timer = alarm_timer = watch_timer = null
	maybe_end()

/// Whether a report of this robbery by this robber is already waiting on a witness (an officer's call, a townsperson's moment)
/datum/outpost_holdup/proc/pending_report()
	var/datum/outpost_police/police = shop?.outpost?.police
	var/mob/living/robber = robber_ref?.resolve()
	if(!police || !robber)
		return FALSE
	for(var/datum/outpost_pending_report/report as anything in police.pending_reports)
		if(!QDELETED(report) && report.crime == OUTPOST_CRIME_ARMED_ROBBERY && report.offender?.resolve() == robber)
			return TRUE
	return FALSE

/// The desk reads the shop's alarm out over the police radio: "Robbery at %PLACE%. %LOOK%, gone toward the lifts."
/datum/outpost_holdup/proc/relay_alarm(mob/living/trader, mob/living/robber)
	var/datum/outpost_police/police = shop?.outpost?.police
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/dispatcher = police?.life_dispatcher()
	if(!dispatcher)
		return
	var/list/values = list("place" = police.life_nearest_shop_name(get_turf(trader)), "look" = outpost_police_look(robber))
	var/line = outpost_robbery_line(police, ROBBERY_LINE_ALARM, values)
	if(line)
		dispatcher.life_speak(line, TRUE)

/**
 * Anyone but the trader who sees the gun pointed reports the robbery by the usual rules (townspeople after a moment,
 * officers by radio, players and cameras at once). The trader's own report is the alarm, so it is left out here.
 */
/datum/outpost_holdup/proc/report_to_others()
	if(counted || pending_report())
		return
	var/datum/outpost_police/police = shop?.outpost?.police
	var/mob/living/trader = trader_ref?.resolve()
	var/mob/living/robber = robber_ref?.resolve()
	if(!police || QDELETED(trader) || QDELETED(robber))
		return
	var/list/witnesses = police.perception.holdup_witnesses(robber, trader)
	if(!length(witnesses))
		return
	var/atom/first = witnesses[1]
	var/obj/item/gun/weapon = weapon_ref?.resolve()
	var/delay = police.perception.report_delay(first, OUTPOST_CRIME_ARMED_ROBBERY)
	if(delay > 0 || police.perception.reports_by_call(first))
		police.queue_report(robber, OUTPOST_CRIME_ARMED_ROBBERY, null, weapon, witnesses, delay)
	else
		police.count_crime(robber, OUTPOST_CRIME_ARMED_ROBBERY, null, weapon)

// ----- the police's side -----

/datum/outpost_police
	/// Stolen takings: weakref to the item -> list("shop" = weakref, "amount" = credits of a holochip, "sku" = weakref of a shelf item) (R7)
	var/list/takings

/// A robbery counted against someone is the one the stick-up in progress would have raised; its alarm and any pending witness report need not count it again
/datum/outpost_police/proc/note_robbery_counted(mob/living/offender)
	GLOB.outpost_holdups.note_counted(offender)
	absorb_pending_crime(offender, OUTPOST_CRIME_ARMED_ROBBERY)

/datum/outpost_police/count_crime(mob/living/offender, crime, atom/victim, obj/item/source, derived = FALSE)
	. = ..()
	if(crime == OUTPOST_CRIME_ARMED_ROBBERY)
		note_robbery_counted(offender)

/datum/outpost_police/apply_upgraded_crime(mob/living/offender, base_heat, crime, atom/victim, obj/item/source)
	. = ..()
	if(crime == OUTPOST_CRIME_ARMED_ROBBERY)
		note_robbery_counted(offender)

/// The Search step also takes stolen takings the suspect has on them or at their feet
/datum/outpost_police/evidence_candidates(mob/living/carbon/suspect, mob/living/officer)
	var/list/take = ..(suspect, officer)
	if(!islist(take))
		take = list()
	for(var/datum/weakref/ref in takings?.Copy())
		var/obj/item/stolen = ref.resolve()
		if(QDELETED(stolen))
			takings -= ref
			continue
		if(evidence_can_take(stolen, suspect, officer))
			take |= stolen
	return take

/// Stolen takings in an emptied evidence case go back where they came from (a holochip's credits to the till, a shelf item to its shelf); the rest is the case's business
/datum/outpost_police/evidence_empty_case(obj/item/outpost_sealed_case/evidence/case, turf/spill, obj/structure/closet/secure_closet/outpost_evidence/store)
	for(var/obj/item/thing as anything in case.contents.Copy())
		var/datum/weakref/ref = WEAKREF(thing)
		var/list/record = takings?[ref]
		if(!record)
			continue
		takings -= ref
		return_takings(thing, record, spill)
	return ..()

/// `thing` was stolen from a counter: back to it (the cap on what a counter loses in a round is not given back)
/datum/outpost_police/proc/return_takings(obj/item/thing, list/record, turf/spill)
	var/datum/weakref/shop_ref = record["shop"]
	var/datum/outpost_shop/shop = shop_ref?.resolve()
	if(QDELETED(shop) || QDELETED(thing))
		return
	var/amount = record["amount"]
	if(amount && istype(thing, /obj/item/holochip))
		var/obj/item/holochip/chip = thing
		var/returned = chip.spend(min(chip.credits, amount), TRUE)
		// Only what came back refills the till: a chip split down to 1 cr takes only its share off the wait
		if(returned >= amount || shop.till_ready_at <= world.time)
			shop.till_ready_at = 0
			shop.till_extras = 0
			shop.till_robbed_by = null
		else if(returned > 0)
			shop.till_ready_at = max(world.time + 1, shop.till_ready_at - round(OUTPOST_HOLDUP_TILL_REFILL * returned / amount))
			addtimer(CALLBACK(shop, TYPE_PROC_REF(/datum/outpost_shop, till_refilled)), shop.till_ready_at - world.time, TIMER_UNIQUE | TIMER_OVERRIDE | TIMER_DELETE_ME)
		// Whatever else was on the chip is theirs
		if(!QDELETED(chip) && spill)
			chip.forceMove(spill)
		return
	var/datum/weakref/sku_ref = record["sku"]
	var/datum/shop_sku/sku = sku_ref?.resolve()
	if(sku && !QDELETED(sku))
		sku.stock++
	// A sealed case spills what it holds when deleted: the stock went back on the shelf, so the goods go with it
	for(var/atom/movable/inside as anything in thing.contents.Copy())
		qdel(inside)
	qdel(thing)

// ----- what the police's witnesses make of it -----

/**
 * Who, other than the held-up trader (whose report is its alarm), sees `robber` hold `trader` up, in the order
 * witness_of() asks: the outpost's other traders, players not on the robber's crew, cameras, then every officer and
 * townsperson who saw. One witness, or those townspeople then those officers (the townspeople's report is on a timer);
 * empty if nobody did.
 */
/datum/outpost_police_perception/proc/holdup_witnesses(mob/living/robber, mob/living/trader)
	var/obj/structure/overmap/trader_outpost/outpost = police?.outpost
	if(!outpost || !robber)
		return list()
	for(var/mob/living/other in outpost.traders)
		if(other != trader && can_report(other) && sees(other, robber))
			return list(other)
	var/datum/voidcrew_crew_record/own_crew = robber.mind?.get_reputation_crew()
	for(var/mob/living/player in GLOB.alive_player_list)
		if(player == robber || player == trader || is_officer(player) || on_crew(player, own_crew))
			continue
		if(sees(player, robber) && get_trader_outpost_for_turf(get_turf(player)) == outpost)
			return list(player)
	for(var/atom/camera as anything in cameras())
		if(sees(camera, robber))
			return list(camera)
	var/list/officers_saw = list()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in police.officers)
		if(sees(officer, robber))
			officers_saw += officer
	var/list/civilians_saw = list()
	var/datum/ambient_place/outpost/place = SSambient_npcs.outposts?[outpost]
	if(place)
		for(var/mob/living/carbon/human/npc/ambient_npc/person in place.npcs)
			if(!person.mind && !person.client && !is_officer(person) && !(person in outpost.traders) && sees(person, robber))
				civilians_saw += person
	if(length(civilians_saw) && length(officers_saw))
		return civilians_saw + officers_saw
	if(length(officers_saw))
		return officers_saw
	return civilians_saw

// ----- the gate emag, to the police (spec-rehydrate.md 9) -----

/// A wall scanner whose gate is down (trade/outpost_checkpoint.dm disable()) is no camera: it sees nobody
/datum/outpost_police_perception/is_camera(atom/thing)
	if(istype(thing, /obj/machinery/outpost_checkpoint_sensor))
		var/obj/machinery/outpost_checkpoint_sensor/scanner = thing
		if(scanner.checkpoint?.is_disabled())
			return FALSE
	return ..()

/// ...and its chamber scans nobody
/datum/outpost_police_perception/scanned(mob/living/target)
	var/turf/where = get_turf(target)
	if(where && police?.outpost)
		for(var/checkpoint_id in police.outpost.checkpoints)
			var/datum/outpost_checkpoint/checkpoint = police.outpost.checkpoints[checkpoint_id]
			if(checkpoint?.is_disabled() && (where in checkpoint.chamber_turfs))
				return FALSE
	return ..()

#undef OUTPOST_HOLDUP_STEADY
