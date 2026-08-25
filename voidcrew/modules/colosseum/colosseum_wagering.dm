/**
 * # Colosseum wagering
 *
 * Parimutuel betting on match contestants, run from the bookmaker console in
 * the wagering hall. Bets are cash-in (hard-light holochips only) and pay out
 * as physical betting slips, stealable, tradeable, ransomable, exactly as a
 * voidcrew financial instrument should be.
 *
 * The book opens at roster lock and closes when the gates open. Winning bets
 * return their stake plus a share of the losing pool (minus the house's 10%
 * rake on that pool. A won bet never pays less than its stake). In team
 * modes a bet on any member of the winning team pays. Draws and cancelled
 * matches refund face value. Settled books are archived on the controller so
 * old slips stay redeemable for the rest of the round.
 */

/// House rake, taken from the losing pool only.
#define COLOSSEUM_BOOK_RAKE 0.1
#define COLOSSEUM_BET_MIN 10
#define COLOSSEUM_BET_MAX 5000

/datum/colosseum_book
	/// The venue's controller
	var/datum/colosseum_controller/controller
	/// Which match this book covers (controller.matches_run + 1 at creation)
	var/match_number
	/// Whether bets are currently accepted
	var/open = FALSE
	/// Whether the match has been decided and payouts computed
	var/settled = FALSE
	/// Draw/cancel: every slip refunds at face value
	var/refunding = FALSE
	/// Total staked per contestant mind (mind -> credits)
	var/list/stakes = list()
	/// Every credit in the book
	var/total_pool = 0
	/// Sum staked on winners, computed at settle
	var/winning_stakes = 0
	/// Winning minds at settle (assoc mind -> TRUE)
	var/list/winners = list()
	/// Minds scratched before the fight: no-shows struck from the roster.
	/// Their stakes leave the pool and their slips refund at face value.
	var/list/scratched = list()

/datum/colosseum_book/New(datum/colosseum_controller/controller)
	src.controller = controller
	match_number = controller.matches_run + 1

/datum/colosseum_book/Destroy()
	controller = null
	stakes.Cut()
	winners.Cut()
	scratched.Cut()
	return ..()

/// Records a paid stake. Money handling is the console's problem.
/datum/colosseum_book/proc/record_stake(datum/mind/target, amount)
	if(!open || settled || !target || amount <= 0)
		return FALSE
	if(scratched[target]) // struck from the roster while the bet dialog was open
		return FALSE
	stakes[target] += amount
	total_pool += amount
	return TRUE

/datum/colosseum_book/proc/close_book()
	open = FALSE

/**
 * A backed fighter never made it to the sand (no-show struck at seating close,
 * or knocked out before the gates opened). Standard parimutuel: their stakes
 * leave the pool and their slips refund at face value. Bettors shouldn't eat
 * a loss on a fight that never happened.
 */
/datum/colosseum_book/proc/scratch(datum/mind/target)
	if(!target || settled)
		return
	var/amount = stakes[target]
	if(!amount)
		return
	scratched[target] = TRUE
	stakes -= target
	total_pool -= amount

/**
 * Locks in the result. Empty winner list = refunds. If nobody backed a
 * winner, everyone refunds too. The house doesn't keep orphaned pools.
 */
/datum/colosseum_book/proc/settle(list/datum/mind/winner_minds)
	if(settled)
		return
	open = FALSE
	settled = TRUE
	winners = list()
	for(var/datum/mind/winner as anything in winner_minds)
		winners[winner] = TRUE
	// Team victories pay the whole side: a bet on any member of the winning
	// team pays, dead or alive, the fighter's team won the match they backed.
	var/datum/colosseum_game/mode = controller?.mode
	if(length(winners) && mode?.team_based)
		var/list/winning_teams = list()
		for(var/datum/mind/team_winner as anything in winners)
			var/datum/colosseum_contestant/winner_entry = controller.entry_for_mind(team_winner)
			if(winner_entry)
				winning_teams[winner_entry.team] = TRUE
		for(var/datum/colosseum_contestant/entry as anything in controller.roster)
			if(entry.mind && winning_teams[entry.team])
				winners[entry.mind] = TRUE
	if(!length(winners))
		refunding = TRUE
		return
	winning_stakes = 0
	for(var/datum/mind/target as anything in stakes)
		if(winners[target])
			winning_stakes += stakes[target]
	if(!winning_stakes && total_pool)
		refunding = TRUE

/// What a slip of `amount` on `target` pays right now. 0 = lost (or unsettled).
/datum/colosseum_book/proc/payout_for(datum/mind/target, amount)
	if(target && scratched[target])
		return amount // scratched fighters refund immediately, even mid-match
	if(!settled)
		return 0
	if(refunding)
		return amount
	if(!target || !winners[target])
		return 0
	var/losing_pool = total_pool - winning_stakes
	return amount + round(losing_pool * (1 - COLOSSEUM_BOOK_RAKE) * amount / winning_stakes)

// ===== BETTING SLIP =====

/obj/item/colosseum_bet_slip
	name = "betting slip"
	desc = "A stamped wager chit from the Grand Colosseum's wagering hall. Redeem it at the bookmaker after the match, if you picked right."
	icon = 'icons/obj/service/bureaucracy.dmi'
	icon_state = "paper"
	w_class = WEIGHT_CLASS_TINY
	/// The book this slip belongs to
	var/datum/weakref/book_ref
	/// The backed contestant's mind
	var/datum/weakref/target_ref
	/// Display details stamped at purchase
	var/target_name
	var/amount = 0
	var/match_number = 0

/obj/item/colosseum_bet_slip/examine(mob/user)
	. = ..()
	. += span_notice("Match [match_number]: [amount] cr on <b>[target_name]</b>.")
	var/datum/colosseum_book/book = book_ref?.resolve()
	if(!book)
		. += span_warning("The book stamp has faded. This wager can't be redeemed.")
		return
	var/datum/mind/backed = target_ref?.resolve()
	if(backed && book.scratched[backed])
		. += span_notice("SCRATCHED: [target_name] never made it to the sand. This slip refunds [amount] credits at the bookmaker.")
	else if(!book.settled)
		. += span_notice("The match is not yet settled.")
	else
		var/payout = book.payout_for(backed, amount)
		. += payout ? span_boldnotice("It pays [payout] credits at the bookmaker.") : span_warning("It pays nothing.")

// ===== BOOKMAKER CONSOLE =====

/obj/machinery/computer/colosseum_bookmaker
	name = "bookmaker's console"
	desc = "The wagering hall's odds engine. It takes hard-light credits, issues stamped slips, and always remembers the house's cut."
	icon_screen = "commsyndie"
	use_power = NO_POWER_USE
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The venue this console books for (wired by link_interior)
	var/obj/structure/overmap/colosseum/site

/obj/machinery/computer/colosseum_bookmaker/Destroy()
	if(site?.bookmaker == src)
		site.bookmaker = null
	site = null
	return ..()

// Computers deconstruct into frames via screwdriver regardless of
// resistance_flags; venue fixtures don't.
/obj/machinery/computer/colosseum_bookmaker/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(tool.tool_behaviour)
		balloon_alert(user, "set into the stone!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/obj/machinery/computer/colosseum_bookmaker/examine(mob/user)
	. = ..()
	var/datum/colosseum_book/book = site?.controller?.book
	if(!book)
		. += span_notice("The board is dark. Betting opens when a roster locks.")
		return
	. += book.open ? span_boldnotice("The book is OPEN for match [book.match_number]. Pool: [book.total_pool] cr.") : span_notice("The book for match [book.match_number] is closed. Pool: [book.total_pool] cr.")
	for(var/datum/mind/target as anything in book.stakes)
		var/datum/colosseum_contestant/entry = site.controller.entry_for_mind(target)
		. += span_info("- [entry ? "[entry.display_name] ([entry.ship_name])" : "unknown fighter"]: [book.stakes[target]] cr")

/obj/machinery/computer/colosseum_bookmaker/interact(mob/user)
	. = ..()
	if(isliving(user))
		take_bet(user)

/obj/machinery/computer/colosseum_bookmaker/proc/take_bet(mob/living/user)
	var/datum/colosseum_controller/controller = site?.controller
	var/datum/colosseum_book/book = controller?.book
	if(!book || !book.open)
		balloon_alert(user, "the book is closed!")
		return
	if(!user.mind)
		return
	var/list/choices = list()
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		choices["[entry.display_name] ([entry.ship_name]), [book.stakes[entry.mind] || 0] cr staked"] = entry
	if(!length(choices))
		balloon_alert(user, "no contestants!")
		return
	var/chosen_label = tgui_input_list(user, "Back a fighter (parimutuel: winners split the losing pool, house takes [COLOSSEUM_BOOK_RAKE * 100]% of it)", "Bookmaker", choices)
	if(!chosen_label || !site?.controller || site.controller.book != book || !book.open)
		return
	var/datum/colosseum_contestant/target = choices[chosen_label]
	var/amount = tgui_input_number(user, "Stake on [target.display_name]? Hard-light credits only.", "Bookmaker", 100, COLOSSEUM_BET_MAX, COLOSSEUM_BET_MIN)
	if(!amount || !site?.controller || site.controller.book != book || !book.open)
		return
	amount = round(amount)
	var/obj/item/holochip/chip = user.is_holding_item_of_type(/obj/item/holochip)
	if(!chip || chip.credits < amount)
		balloon_alert(user, "hold a [amount] cr holochip!")
		return
	if(!chip.spend(amount))
		balloon_alert(user, "payment failed!")
		return
	if(!book.record_stake(target.mind, amount))
		// The fighter was struck (or the book slammed shut) mid-dialog, hand
		// the money straight back rather than printing a dead slip.
		var/obj/item/holochip/refund = new(get_turf(user), amount)
		user.put_in_hands(refund)
		balloon_alert(user, "fighter withdrawn, refunded!")
		return
	var/obj/item/colosseum_bet_slip/slip = new(get_turf(user))
	slip.book_ref = WEAKREF(book)
	slip.target_ref = WEAKREF(target.mind)
	slip.target_name = "[target.display_name] ([target.ship_name])"
	slip.amount = amount
	slip.match_number = book.match_number
	slip.name = "betting slip, [amount] cr on [target.display_name]"
	user.put_in_hands(slip)
	balloon_alert(user, "wager placed!")
	playsound(src, 'sound/machines/ping.ogg', 40, TRUE)

/// Slips redeem by slapping them on the console.
/obj/machinery/computer/colosseum_bookmaker/attackby(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!istype(attacking_item, /obj/item/colosseum_bet_slip))
		return ..()
	var/obj/item/colosseum_bet_slip/slip = attacking_item
	var/datum/colosseum_book/book = slip.book_ref?.resolve()
	if(!book)
		to_chat(user, span_warning("The console rejects the slip. Its book no longer exists."))
		return TRUE
	var/datum/mind/backed = slip.target_ref?.resolve()
	if(!book.settled && !(backed && book.scratched[backed]))
		balloon_alert(user, "match not settled yet!")
		return TRUE
	var/payout = book.payout_for(backed, slip.amount)
	if(payout > 0)
		var/obj/item/holochip/winnings = new(get_turf(user), payout)
		user.put_in_hands(winnings)
		to_chat(user, span_boldnotice("The console stamps the slip PAID and dispenses [payout] credits."))
		playsound(src, 'sound/machines/ping.ogg', 50, TRUE)
	else
		to_chat(user, span_warning("The console stamps the slip VOID and shreds it. The house thanks you for your patronage."))
	qdel(slip)
	return TRUE

#undef COLOSSEUM_BOOK_RAKE
#undef COLOSSEUM_BET_MIN
#undef COLOSSEUM_BET_MAX
