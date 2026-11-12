/**
 * # Outpost floors: round metrics
 *
 * Owner: P9 (spec 10). One helper every floors package calls: record_floor_metric(). Every row is category "floor"
 * (METRIC_FLOOR below), written once per occurrence through record_metric(). Round metrics must be on and the
 * round_metric table present; with either missing the call costs one variable read and does nothing.
 *
 * Event catalog. `credits` and `vouchers` are signed from the player's or the floor's side: money gained is
 * positive, money spent is negative. Every row has subject "<outpost>, floor <n>" and details: floor (the number),
 * entry ("crew", "invited" or "open", as it stands when the row is written). `ckey` is the person the row is about,
 * empty when it is about nobody (a delivery, a sale to an NPC). `other_ckey` is the floor's owner when that is not
 * the same person, so a visit reads ckey = the visitor, other_ckey = whose floor. `ship` is the person's crew ship,
 * or the owner's ship when the row has no person. `zone` is the outpost's.
 *
 * * floor_bought: a floor was let. ckey = buyer, credits = minus the price, vouchers = minus the vouchers, quantity 1.
 *   Overlaps the buyer's shop_purchase row and ship_account_change; sum one of the three, never all.
 * * floor_given_up: the owner gave the lease up. ckey = the owner.
 * * floor_claimed: someone took a vacant or abandoned floor. ckey = the new owner.
 * * floor_setting: the entry setting was changed. ckey = who changed it, details.entry = the new setting.
 * * floor_visit: a lift arrived with people who are not the floor's own. ckey = the rider, quantity = how many
 *   visitors stepped out. One row a ride.
 * * floor_lift_forced: a lift took someone up that the setting would not have. ckey = the rider.
 * * floor_warrant: the squad went up after a wanted suspect. quantity = what the caller passes (the stars).
 * * floor_breach: a breaching charge was planted. quantity = charges.
 * * floor_npc_sale: an NPC customer bought something on the floor. credits = what the floor's treasury took, quantity 1.
 *   Overlaps outpost_account_change. The one new source of credits in the design (L23).
 * * floor_fitting: a till, shelf or floor sign kit was set down. ckey = who, quantity = how many (1).
 * * floor_supply_order: an order reached the goods lift. credits = minus what the treasury paid, quantity 1.
 *   Overlaps cargo_order and outpost_account_change.
 * * floor_hand: someone took a job as a hired hand. ckey = the hand.
 *
 * `amount` is the number the caller has to hand: credits for floor_bought, floor_supply_order and floor_npc_sale,
 * otherwise a count that goes in `quantity`. An event name not listed above is still written, as a count, so a typo
 * shows up in the table and is not lost.
 *
 * Trap: record_metric() takes named arguments, and no positional string may equal one of its parameter names.
 * The category and the events here never do.
 */

/// The category of every row in this file (voidcrew/_DEFINES/metrics.dm has the others)
#define METRIC_FLOOR "floor"

/**
 * Records `event` for `floor`: `actor` is the person it is about (null when it is about nobody), `amount` is the
 * number the event carries (see the catalog above). Safe to call from anywhere: it only queues a row.
 */
/proc/record_floor_metric(event, datum/outpost_floor/floor, mob/actor, amount = 0)
	if(!SSmetrics.accepting || !istext(event) || QDELETED(floor))
		return
	var/credits = 0
	var/vouchers = 0
	var/quantity = 0
	switch(event)
		if("floor_bought")
			credits = -amount
			vouchers = -OUTPOST_FLOOR_COST_VOUCHERS
			quantity = 1
		if("floor_supply_order")
			credits = -amount
			quantity = 1
		if("floor_npc_sale")
			credits = amount
			quantity = 1
		else
			quantity = amount
	var/obj/structure/overmap/trader_outpost/building = floor.outpost
	var/place = QDELETED(building) ? "no outpost" : format_text(building.name)
	var/obj/structure/overmap/dynamic/player_outpost/floor/floor_host = floor.host
	var/owner_key = QDELETED(floor_host) ? null : floor_host.founder_ckey
	var/person_key = actor ? metric_ckey(actor) : null
	var/obj/structure/overmap/ship/crew_ship = (actor || QDELETED(floor_host)) ? null : floor_host.get_owner_ship()
	record_metric(METRIC_FLOOR, event, ckey = person_key, other_ckey = (owner_key && owner_key != person_key) ? owner_key : null, ship = crew_ship, zone = QDELETED(building) ? null : metric_zone(building), subject = "[place], floor [floor.number]", credits = credits, vouchers = vouchers, quantity = quantity, details = list("floor" = floor.number, "entry" = floor.entry_policy), actor = actor)

#undef METRIC_FLOOR
