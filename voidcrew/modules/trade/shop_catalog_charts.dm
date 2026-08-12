/**
 * # Chart & Intel Catalog
 *
 * Every chart line sold anywhere in the galaxy, in one file, because charts are
 * the one shelf that is not tied to the shop selling it.
 *
 * The three main outposts each draw the same `chart_pool` (see shop.dm), so any
 * outpost can stock a chart for any zone band. A tip bought over a green-band
 * counter can point straight into the lawless deep. That is deliberate: the old
 * arrangement sold every trader the map of the band they were already standing
 * in, which meant you had to make the dangerous flight before you could buy the
 * intel about it. Charts are now something you buy *before* you commit.
 *
 * Because the buyer can no longer read the danger off which outpost sold it,
 * every line here names its band in the text, and the generic rumor tip names
 * the band of whatever it rolled at purchase.
 *
 * Ruin charts are dealt globally without repeats (GLOB.dealt_rumor_charts) so
 * two outposts never stock a tip to the same named ruin. Star charts and the
 * generic rumor are ordinary restockable goods.
 */

/**
 * # Star chart SKU
 *
 * The bulk certainty channel: one slate charts every contact in a whole band.
 * Priced by how much the information is worth, which is to say by how far out
 * the band is.
 */
/datum/shop_sku/chart
	category = "Intel & Charts"
	is_chart = TRUE
	stock_min = 1
	stock_max = 2

// The neutral ring is cheap to survey and mostly already known, so this is the
// low rung of the ladder.
/datum/shop_sku/chart/green
	item_path = /obj/item/disk/star_chart/green
	price_credits = 1200

/datum/shop_sku/chart/yellow
	item_path = /obj/item/disk/star_chart/yellow
	price_credits = 2400

// Nobody surveys the lawless deep for credits.
/datum/shop_sku/chart/red
	item_path = /obj/item/disk/star_chart/red
	price_vouchers = 2

/**
 * # Rumor SKU
 *
 * Intel over the counter: no goods change hands. The trader marks one uncharted
 * ruin signal onto the buyer ship's helm readout under a "Rumors" category. The
 * certainty ladder's cheapest rung, below star charts and above flying blind.
 *
 * The tip can land anywhere in the galaxy, so the mark names the zone band it
 * sits in, otherwise the buyer has no way to tell a short hop from a run into
 * the deep.
 */
/datum/shop_sku/rumor
	name = "word on the lanes"
	desc = "Traders hear from everyone who comes through, and somebody always mentions something parked where it shouldn't be. One uncharted signal anywhere in the galaxy gets marked on your helm, with its zone band named so you know what you're flying into."
	category = "Intel & Charts"
	icon_override = 'icons/obj/scrolls.dmi'
	icon_state_override = "blueprints"
	is_chart = TRUE
	// One price at every outpost, since all three now sell the same galaxy-wide
	// tip rather than their own band's local gossip.
	price_credits = 1500
	stock_min = 2
	stock_max = 4

/**
 * Picks an uncharted ruin signal to sell. Candidates are drawn from the whole
 * overmap: a rumor is hearsay passed between crews, and there is no reason a
 * trader would only ever hear about their own neighbourhood.
 */
/datum/shop_sku/rumor/proc/find_rumor_target(obj/structure/overmap/ship/ship)
	var/list/candidates = list()
	for(var/obj/structure/overmap/space_ruin/ruin as anything in GLOB.space_ruin_signals)
		if(QDELETED(ruin) || !istype(get_turf(ruin), /turf/open/overmap))
			continue
		if(ship.get_waypoint(REF(ruin)) || ship.get_waypoint("rumor_[REF(ruin)]"))
			continue
		candidates += ruin
	if(!length(candidates))
		return null
	return pick(candidates)

/**
 * Player-facing name of a zone band, for tips that could have come from any of
 * them. Falls back to a vague label rather than nothing when the signal sits on
 * a turf the zone controller can't place.
 */
/datum/shop_sku/rumor/proc/zone_band_name(zone_type)
	switch(zone_type)
		if(ZONE_GREEN)
			return ZONE_NAME_GREEN
		if(ZONE_YELLOW)
			return ZONE_NAME_YELLOW
		if(ZONE_RED)
			return ZONE_NAME_RED
	return "an uncharted band"

/datum/shop_sku/rumor/get_denial_reason(mob/living/user)
	. = ..()
	if(.)
		return
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return "No crew registration, you need a ship to chart the tip onto."

/datum/shop_sku/rumor/try_purchase(mob/living/user, mob/living/basic/outpost_trader/vendor)
	if(stock <= 0)
		return FALSE
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	if(!ship)
		return FALSE
	var/datum/outpost_shop/shop = vendor?.shop
	var/obj/structure/overmap/space_ruin/target = find_rumor_target(ship)
	if(!target)
		to_chat(user, span_warning("The lanes are quiet, no fresh rumors this shift."))
		return FALSE

	// Validate the credit half before consuming any vouchers. User passed so
	// the charge matches the favor-discounted price the UI shows them.
	var/credit_price = get_credit_price(user)
	var/datum/bank_account/account
	if(credit_price > 0)
		account = get_account(user)
		if(!account || !account.has_money(credit_price))
			return FALSE

	if(price_vouchers > 0 && !consume_trade_vouchers(user, price_vouchers))
		return FALSE
	if(credit_price > 0 && !account.adjust_money(-credit_price, "Trader Outpost: [name]"))
		return FALSE

	stock--
	var/list/coords = target.get_relative_overmap_coords()
	var/band = zone_band_name(SSovermap_zones?.get_zone_type(get_turf(target)))
	ship.add_waypoint("rumor_[REF(target)]", "[shop?.trader_name || "Trader"]'s tip: unknown signal ([band])", coords[1], coords[2], "Rumors")
	to_chat(user, span_notice("A new mark lands on [ship]'s helm readout: unknown signal at ([coords[1]], [coords[2]]), in the [band]."))
	return TRUE

/**
 * # Ruin charts
 *
 * Each names one rare ruin that exists nowhere until somebody buys the tip and
 * reveals it from their helm. One buyer per ruin, ever: once sold, the trail is
 * cold at every outpost. Prices encode danger, not distance, because spawn_zone
 * decides where the ruin actually lands.
 */

// ===== CONTESTED LANES (yellow) =====

/datum/shop_sku/ruin_chart/hospice
	name = "contested-lane tip: 'CSV Meridian'"
	desc = "A plague evacuation ship, scuttled under quarantine seal and never reopened. The wards are still full and the pharmacy was never rationed out. Uploaded sealed to your helm; reveal it when your crew has suits that seal."
	price_credits = 4800
	spawn_zone = ZONE_YELLOW
	ruin_template_path = /datum/map_template/ruin/space/rare/hospice
	rumor_name = "CSV Meridian"
	rumor_desc = "A hospice ship parked dark under a seal that never lifted. The wards are still full, and so is the pharmacy."

/datum/shop_sku/ruin_chart/biolab
	name = "contested-lane tip: 'Eventide'"
	desc = "An off-ledger xenobiology annex that stopped filing reports mid-shift. The specimens are loose and the extract vault was never emptied. Uploaded sealed to your helm; reveal it when your crew is kitted for what's inside."
	price_vouchers = 2
	price_credits = 3000
	spawn_zone = ZONE_YELLOW
	ruin_template_path = /datum/map_template/ruin/space/rare/biolab
	rumor_name = "Eventide"
	rumor_desc = "A xenobiology annex drifting dark on the contested lanes. Containment failed from the inside, and the extract vault is still sealed."

/datum/shop_sku/ruin_chart/liner
	name = "contested-lane tip: 'MV Ambassador'"
	desc = "A passenger liner that lost power mid-crossing and got written off with the luggage still aboard. Scavengers are working it now, and they haven't cracked the purser's hold. Uploaded sealed to your helm; the people already inside are the only thing between you and it."
	price_vouchers = 1
	price_credits = 3600
	spawn_zone = ZONE_YELLOW
	ruin_template_path = /datum/map_template/ruin/space/rare/liner
	rumor_name = "MV Ambassador"
	rumor_desc = "A derelict liner on the contested lanes with a salvage crew already aboard. The baggage hold is still sealed."

// ===== LAWLESS DEEP (red) =====

/datum/shop_sku/ruin_chart/armory
	name = "deep-lane tip: 'Bastion-6'"
	desc = "A mothballed munitions barge. Nobody ever emptied the vault, and nobody ever switched off the security grid. Uploaded sealed to your helm; reveal it when your crew can handle a live grid."
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/armory
	rumor_name = "Bastion-6"
	rumor_desc = "A deadstock munitions barge parked dark in the lawless deep. The grid is still live and the vault is still full."

/datum/shop_sku/ruin_chart/pirate_cove
	name = "deep-lane tip: 'The Scuppers'"
	desc = "A smugglers' freeport dug into a hollow asteroid. The crews shot each other over the split, and the survivors are still holding the door on the quartermaster's hoard. Uploaded sealed to your helm; reveal it when your crew is ready to take that door."
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/pirate_cove
	rumor_name = "The Scuppers"
	rumor_desc = "A freeport gone quiet in a hollow asteroid. The survivors are still holding the door on an undivided hoard."

/datum/shop_sku/ruin_chart/reliquary
	name = "deep-lane tip: 'Pilgrim's Vow'"
	desc = "A votive barge that went dark on pilgrimage a generation ago. The congregation is still holding service, and nobody has ever robbed the crypt. Uploaded sealed to your helm; reveal it when your crew is ready to go in armed."
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/reliquary
	rumor_name = "Pilgrim's Vow"
	rumor_desc = "A pilgrim barge adrift with every candle still burning. The service never ended, and the grave-goods never left."

/datum/shop_sku/ruin_chart/foundry
	name = "deep-lane tip: 'Helios-Betna'"
	desc = "An automated foundry that never heard its owners went under. The line still runs and the custodians still patrol. Uploaded sealed to your helm; reveal it when your crew is ready to take on a factory full of machines."
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/foundry
	rumor_name = "Helios-Betna"
	rumor_desc = "A dead company's foundry running blind in the lawless deep. The custodians hold the line, and the vault holds decades of alloy nobody came to collect."

/datum/shop_sku/ruin_chart/survey
	name = "deep-lane tip: 'Longwatch Station'"
	desc = "A survey post that kept transmitting for eleven years after its last resupply. Something it collected got out of its container and is still aboard. The sample vault was never opened. Uploaded sealed to your helm; reveal it when your crew can handle whatever the samples turned into."
	price_vouchers = 3
	ruin_template_path = /datum/map_template/ruin/space/rare/survey
	rumor_name = "Longwatch Station"
	rumor_desc = "A survey post in the lawless deep that outlived its own recall order. The sample vault is intact and so is what got loose inside."

// Top of the ladder. Same three-voucher toll every deep-lane tip carries, plus
// the largest credit premium on the shelf: the guard is the hardest thing any
// chart points at, and the prize is a working machine rather than a locker.
/datum/shop_sku/ruin_chart/bitrunner_den
	name = "deep-lane tip: 'Nullstack Arcade'"
	desc = "An unlicensed netpod parlour that ran its server past what the cooling could take. The safeties failed with a domain live and the forge started printing the domain's hostiles into the room. Nobody has stripped the place, server included. Uploaded sealed to your helm; reveal it when your crew is ready to fight what came out of it."
	price_vouchers = 3
	price_credits = 4000
	ruin_template_path = /datum/map_template/ruin/space/rare/bitrunner_den
	rumor_name = "Nullstack Arcade"
	rumor_desc = "A bitrunning parlour gone quiet in the lawless deep. Its server malfunctioned with runners plugged in, and what it printed is still on the floor."

/datum/shop_sku/ruin_chart/blacksite
	name = "deep-lane tip: 'Kestrel Anchorage'"
	desc = "A Syndicate forward depot that stopped answering its handlers two years ago. The garrison never stood down, so nothing has been looted and nothing has been abandoned. Uploaded sealed to your helm; reveal it when your crew is ready to fight soldiers who are still on duty."
	price_vouchers = 3
	price_credits = 3000
	ruin_template_path = /datum/map_template/ruin/space/rare/blacksite
	rumor_name = "Kestrel Anchorage"
	rumor_desc = "A Syndicate depot in the lawless deep, still garrisoned and still following orders nobody has updated. The equipment lockers were never stripped."
