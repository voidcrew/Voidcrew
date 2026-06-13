/**
 * # Outpost Shops
 *
 * One /datum/outpost_shop instance per trader outpost, holding the per-round
 * shared stock all of that outpost's terminals sell from. SKUs have fixed,
 * simple prices: vouchers and/or credits, or an item barter — never a mixed
 * freeform payment UI.
 *
 * Vouchers are deliberately the only road to the best stock ("the currency
 * that can't be farmed safely"); credits cover the mundane shelf.
 */
/datum/outpost_shop
	/// Display name the outpost takes on the overmap
	var/outpost_name = "trader outpost"
	/// Overmap description
	var/outpost_desc = "An independent trade station."
	/// Name the trader hologram introduces itself with
	var/trader_name = "Trader"
	/// Preset holoimage the trader's projection is built from
	var/trader_holoimage_type = /datum/preset_holoimage/outpost_trader/general
	/// SKU typepaths stocked here
	var/list/sku_types = list()
	/// Live SKU instances (hold the shared per-round stock)
	var/list/datum/shop_sku/skus = list()
	/// The outpost this shop belongs to
	var/obj/structure/overmap/trader_outpost/outpost
	/// Personality lines, keyed by TRADER_LINE_* category
	var/list/trader_lines = list()

/datum/outpost_shop/New(obj/structure/overmap/trader_outpost/outpost)
	..()
	src.outpost = outpost
	for(var/sku_type in sku_types)
		skus += new sku_type

/datum/outpost_shop/Destroy()
	QDEL_LIST(skus)
	outpost = null
	return ..()

/**
 * Returns a random personality line for the given TRADER_LINE_* category.
 */
/datum/outpost_shop/proc/get_line(category)
	var/list/lines = trader_lines[category]
	if(!length(lines))
		return null
	return pick(lines)

/**
 * # Shop SKU
 *
 * One purchasable line item. Stock is rolled once on creation and shared
 * between all terminals of the outpost.
 */
/datum/shop_sku
	/// Display name (defaults to the item's name)
	var/name
	/// Display description (defaults to the item's desc)
	var/desc
	/// What you get
	var/obj/item/item_path
	/// Price in credits (0 = credits play no part)
	var/price_credits = 0
	/// Price in trade vouchers (0 = vouchers play no part)
	var/price_vouchers = 0
	/// Per-round stock roll bounds
	var/stock_min = 2
	var/stock_max = 4
	/// Remaining stock this round
	var/stock = 0

/datum/shop_sku/New()
	..()
	stock = rand(stock_min, stock_max)
	if(item_path)
		var/obj/item/cast = item_path
		if(!name)
			name = initial(cast.name)
		if(!desc)
			desc = initial(cast.desc)

/**
 * Human-readable price tag, e.g. "3 vouchers + 500 cr".
 */
/datum/shop_sku/proc/get_price_text()
	var/list/parts = list()
	if(price_vouchers > 0)
		parts += "[price_vouchers] voucher[price_vouchers > 1 ? "s" : ""]"
	if(price_credits > 0)
		parts += "[price_credits] cr"
	if(!length(parts))
		return "free"
	return parts.Join(" + ")

/**
 * Whether the user can pay right now (does not charge).
 */
/datum/shop_sku/proc/can_afford(mob/living/user)
	if(price_vouchers > 0 && !find_voucher_stack(user))
		return FALSE
	if(price_credits > 0)
		var/datum/bank_account/account = get_account(user)
		if(!account || !account.has_money(price_credits))
			return FALSE
	return TRUE

/**
 * Why the user can't buy — shown as a tooltip / chat line.
 */
/datum/shop_sku/proc/get_denial_reason(mob/living/user)
	if(stock <= 0)
		return "Out of stock."
	if(price_vouchers > 0 && !find_voucher_stack(user))
		return "Hold [price_vouchers] trade voucher[price_vouchers > 1 ? "s" : ""] in hand."
	if(price_credits > 0)
		var/datum/bank_account/account = get_account(user)
		if(!account)
			return "No bank account on your ID."
		if(!account.has_money(price_credits))
			return "Insufficient credits ([price_credits] cr needed)."
	return null

/**
 * Attempts the purchase: validates, charges, decrements stock and dispenses
 * at the terminal. Returns TRUE on success.
 */
/datum/shop_sku/proc/try_purchase(mob/living/user, obj/machinery/computer/outpost_shop_terminal/terminal)
	if(stock <= 0)
		return FALSE
	if(!can_afford(user))
		return FALSE

	// Charge vouchers first (physical, can't fail after the check), then credits
	if(price_vouchers > 0)
		var/obj/item/stack/trade_voucher/vouchers = find_voucher_stack(user)
		if(!vouchers || !vouchers.use(price_vouchers))
			return FALSE
	if(price_credits > 0)
		var/datum/bank_account/account = get_account(user)
		if(!account || !account.adjust_money(-price_credits, "Trader Outpost: [name]"))
			return FALSE

	stock--
	dispense(user, terminal)
	return TRUE

/**
 * Spawns the goods at the terminal.
 */
/datum/shop_sku/proc/dispense(mob/living/user, obj/machinery/computer/outpost_shop_terminal/terminal)
	var/atom/drop_loc = terminal?.drop_location() || user.drop_location()
	var/obj/item/goods = new item_path(drop_loc)
	if(user.put_in_hands(goods))
		to_chat(user, span_notice("You receive [goods]."))
	else
		to_chat(user, span_notice("[goods] is dispensed at your feet."))

/**
 * Finds a voucher stack covering the price in the user's hands.
 */
/datum/shop_sku/proc/find_voucher_stack(mob/living/user)
	for(var/obj/item/stack/trade_voucher/vouchers in user.held_items)
		if(vouchers.amount >= price_vouchers)
			return vouchers
	return null

/**
 * The bank account on the user's ID card.
 */
/datum/shop_sku/proc/get_account(mob/living/user)
	var/obj/item/card/id/id_card = user.get_idcard(TRUE)
	return id_card?.registered_account

/**
 * # Barter SKU
 *
 * Item-for-item trade as its own SKU type: hand over the asked item, get the
 * goods. No vouchers or credits involved.
 */
/datum/shop_sku/barter
	/// The item the trader wants
	var/obj/item/barter_path
	/// How many (only meaningful when barter_path is a stack type)
	var/barter_amount = 1
	/// Display name of the wanted item (defaults to the item's name)
	var/barter_name

/datum/shop_sku/barter/New()
	. = ..()
	if(barter_path && !barter_name)
		var/obj/item/cast = barter_path
		barter_name = initial(cast.name)

/datum/shop_sku/barter/get_price_text()
	if(barter_amount > 1)
		return "barter: [barter_amount]x [barter_name]"
	return "barter: [barter_name]"

/datum/shop_sku/barter/proc/find_barter_item(mob/living/user)
	for(var/obj/item/offered in user.held_items)
		if(!istype(offered, barter_path))
			continue
		if(isstack(offered))
			var/obj/item/stack/offered_stack = offered
			if(offered_stack.amount < barter_amount)
				continue
		return offered
	return null

/datum/shop_sku/barter/can_afford(mob/living/user)
	return !!find_barter_item(user)

/datum/shop_sku/barter/get_denial_reason(mob/living/user)
	if(stock <= 0)
		return "Out of stock."
	if(!find_barter_item(user))
		return "Hold the asked item in hand: [get_price_text()]."
	return null

/datum/shop_sku/barter/try_purchase(mob/living/user, obj/machinery/computer/outpost_shop_terminal/terminal)
	if(stock <= 0)
		return FALSE
	var/obj/item/offered = find_barter_item(user)
	if(!offered)
		return FALSE
	if(isstack(offered))
		var/obj/item/stack/offered_stack = offered
		if(!offered_stack.use(barter_amount))
			return FALSE
	else
		qdel(offered)
	stock--
	dispense(user, terminal)
	return TRUE

// =========================================================================
// BLACK MARKET (red zone) — syndicate gear, voucher-priced at the top end
// =========================================================================

/datum/outpost_shop/black_market
	outpost_name = "\improper Undertow Exchange"
	outpost_desc = "A heavily armored den of fences and quartermasters who don't ask questions. Somehow, nobody has ever managed to rob it."
	trader_name = "Vex"
	trader_holoimage_type = /datum/preset_holoimage/outpost_trader/black_market
	sku_types = list(
		/datum/shop_sku/black_market/energy_sword,
		/datum/shop_sku/black_market/emag,
		/datum/shop_sku/black_market/pistol,
		/datum/shop_sku/black_market/pistol_mag,
		/datum/shop_sku/black_market/revolver,
		/datum/shop_sku/black_market/speedloader,
		/datum/shop_sku/black_market/suppressor,
		/datum/shop_sku/black_market/c4,
		/datum/shop_sku/black_market/emp_grenade,
		/datum/shop_sku/black_market/noslips,
		/datum/shop_sku/black_market/agent_id,
		/datum/shop_sku/black_market/syndie_key,
		/datum/shop_sku/black_market/thermals,
		/datum/shop_sku/black_market/sleepy_pen,
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/black_market/star_chart,
		/datum/shop_sku/black_market/saw_blueprint,
		/datum/shop_sku/black_market/sniper_blueprint,
		/datum/shop_sku/black_market/soap,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Welcome to the Undertow. Touch nothing you can't pay for.",
			"Fresh faces. Vouchers up front, questions never.",
			"You found us. That's the hard part done. Now spend.",
		),
		TRADER_LINE_SALE = list(
			"Pleasure doing business. Forget you saw me.",
			"Sold. It was never here, and neither were you.",
			"A fine choice. No refunds, no receipts, no memories.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your money's no good here. Literally — check your embargo notice.",
			"We don't serve your kind. 'Your kind' meaning people who shoot at my stock.",
			"Come back when your ship's ledger is clean.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Bad call. The turrets were the cheap part of this station.",
			"Violence! In MY shop! Embargo their ship and paint them, girls.",
			"You just made the blacklist. It's laminated.",
		),
		TRADER_LINE_IDLE = list(
			"I once sold a fleet admiral his own stolen flagship. Twice.",
			"Everything's legal in the red zone. That's the whole pitch.",
			"Stock's limited. The galaxy is not a reliable supplier.",
		),
	)

/datum/shop_sku/black_market
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/energy_sword
	item_path = /obj/item/melee/energy/sword/saber
	price_vouchers = 4
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/emag
	name = "cryptographic sequencer"
	item_path = /obj/item/card/emag
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/pistol
	item_path = /obj/item/gun/ballistic/automatic/pistol
	price_vouchers = 2
	price_credits = 500
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/pistol_mag
	item_path = /obj/item/ammo_box/magazine/m9mm
	price_credits = 300
	stock_min = 4
	stock_max = 8

/datum/shop_sku/black_market/revolver
	item_path = /obj/item/gun/ballistic/revolver
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/speedloader
	item_path = /obj/item/ammo_box/a357
	price_credits = 600
	stock_min = 2
	stock_max = 5

/datum/shop_sku/black_market/suppressor
	item_path = /obj/item/suppressor
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/c4
	item_path = /obj/item/grenade/c4
	price_vouchers = 1
	price_credits = 250
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/emp_grenade
	item_path = /obj/item/grenade/empgrenade
	price_vouchers = 1
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/noslips
	item_path = /obj/item/clothing/shoes/chameleon/noslip
	price_vouchers = 2
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/agent_id
	item_path = /obj/item/card/id/advanced/chameleon
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/syndie_key
	item_path = /obj/item/encryptionkey/syndicate
	price_vouchers = 1
	price_credits = 300
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/thermals
	item_path = /obj/item/clothing/glasses/thermal/syndi
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/sleepy_pen
	item_path = /obj/item/pen/sleepy
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/tactical_medkit
	item_path = /obj/item/storage/medkit/tactical
	price_vouchers = 1
	price_credits = 500
	stock_min = 1
	stock_max = 3

// Charts the lawless deep — the discovery certainty channel, voucher-priced
/datum/shop_sku/black_market/star_chart
	item_path = /obj/item/disk/star_chart/red
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

// The mandatory joke item; also the cheap "see how the shop works" SKU
/datum/shop_sku/black_market/soap
	item_path = /obj/item/soap/syndie
	price_credits = 150
	stock_min = 3
	stock_max = 6

// Weapon blueprints (loot-economy item 6) -- the only trader route to these guns;
// build them at a weapons bench. Reusable, so priced at the top of the ladder.
/datum/shop_sku/black_market/saw_blueprint
	item_path = /obj/item/gun_blueprint/l6_saw
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/sniper_blueprint
	item_path = /obj/item/gun_blueprint/sniper_rifle
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

// =========================================================================
// OUTFITTER (yellow zone) — mid-tier defensive/utility gear, credits-first
// =========================================================================

/datum/outpost_shop/outfitter
	outpost_name = "\improper Quartermain Depot"
	outpost_desc = "A fortified outfitter's depot serving the contested lanes. Armored like it expects its customers to be the problem."
	trader_name = "Sarge"
	trader_holoimage_type = /datum/preset_holoimage/outpost_trader/outfitter
	sku_types = list(
		/datum/shop_sku/outfitter/armor_vest,
		/datum/shop_sku/outfitter/helmet,
		/datum/shop_sku/outfitter/disabler,
		/datum/shop_sku/outfitter/energy_gun,
		/datum/shop_sku/outfitter/seclite,
		/datum/shop_sku/outfitter/handcuffs,
		/datum/shop_sku/outfitter/gas_mask,
		/datum/shop_sku/outfitter/brute_kit,
		/datum/shop_sku/outfitter/jaws,
		/datum/shop_sku/outfitter/star_chart,
		/datum/shop_sku/outfitter/smg_blueprint,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Quartermain Depot. State your needs, keep your sidearm holstered.",
			"Welcome in. Everything's rated for the yellow lanes and worse.",
		),
		TRADER_LINE_SALE = list(
			"Good kit. Try to bring it back in one piece. Or don't, repeat business is fine too.",
			"Sold. Inspect it before you need it, not after.",
		),
		TRADER_LINE_REFUSAL = list(
			"You're flagged. No sales until your embargo clears.",
			"Depot policy: no service to hostiles. Take it up with your captain.",
		),
		TRADER_LINE_AGGRESSION = list(
			"Weapons free. You were warned by the sign. There are several signs.",
			"That armor you're wearing? I sell the thing that beats it. To my turrets.",
		),
		TRADER_LINE_IDLE = list(
			"Inventory rotates when the convoys make it through. When.",
			"The yellow lanes eat the unprepared. Be a customer, not a statistic.",
		),
	)

/datum/shop_sku/outfitter
	stock_min = 2
	stock_max = 4

/datum/shop_sku/outfitter/armor_vest
	item_path = /obj/item/clothing/suit/armor/vest
	price_credits = 600

/datum/shop_sku/outfitter/helmet
	item_path = /obj/item/clothing/head/helmet
	price_credits = 400

/datum/shop_sku/outfitter/disabler
	item_path = /obj/item/gun/energy/disabler
	price_credits = 800
	stock_min = 1
	stock_max = 3

/datum/shop_sku/outfitter/energy_gun
	item_path = /obj/item/gun/energy/e_gun
	price_vouchers = 1
	price_credits = 800
	stock_min = 1
	stock_max = 2

/datum/shop_sku/outfitter/seclite
	item_path = /obj/item/flashlight/seclite
	price_credits = 150

/datum/shop_sku/outfitter/handcuffs
	item_path = /obj/item/restraints/handcuffs
	price_credits = 200

/datum/shop_sku/outfitter/gas_mask
	item_path = /obj/item/clothing/mask/gas
	price_credits = 150

/datum/shop_sku/outfitter/brute_kit
	item_path = /obj/item/storage/medkit/brute
	price_credits = 400

/datum/shop_sku/outfitter/jaws
	name = "jaws of life"
	item_path = /obj/item/crowbar/power
	price_vouchers = 1
	price_credits = 500
	stock_min = 1
	stock_max = 2

// Charts the contested lanes — discovery certainty for the middle ring
/datum/shop_sku/outfitter/star_chart
	item_path = /obj/item/disk/star_chart/yellow
	price_credits = 400
	stock_min = 1
	stock_max = 2

// Weapon blueprint (loot-economy item 6) -- yellow-tier gun, build at a weapons bench.
/datum/shop_sku/outfitter/smg_blueprint
	item_path = /obj/item/gun_blueprint/c20r
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

// =========================================================================
// GENERAL STORE (green zone) — sundries and starter resupply, credits only
// =========================================================================

/datum/outpost_shop/general
	outpost_name = "\improper Waystation Halcyon"
	outpost_desc = "A sleepy general store and rest stop on the safe outer ring. The coffee is bad and the prices are honest."
	trader_name = "Barnaby"
	sku_types = list(
		/datum/shop_sku/general/medkit,
		/datum/shop_sku/general/toolbelt,
		/datum/shop_sku/general/gps,
		/datum/shop_sku/general/oxygen_tank,
		/datum/shop_sku/general/mesons,
		/datum/shop_sku/general/diamond_pick,
		/datum/shop_sku/barter/plasma_for_medkit,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Welcome to Halcyon! Mind the gift shop on your way out. We are the gift shop.",
			"Come in, come in. Safest shop this side of the sun.",
		),
		TRADER_LINE_SALE = list(
			"There you are. Safe travels out there!",
			"Lovely. Do come again — we're literally always here.",
		),
		TRADER_LINE_REFUSAL = list(
			"Oh dear. Your ship's on the naughty list, I'm afraid.",
			"No no, I can't sell to you lot. Head office was very clear.",
		),
		TRADER_LINE_AGGRESSION = list(
			"In the GREEN zone?! Have you no shame? Turrets, please.",
			"Goodness! Right. Embargo. And I'm telling everyone.",
		),
		TRADER_LINE_IDLE = list(
			"They say the deep-ring traders sell terrible things. We sell sensible boots.",
			"Forty years on this rock and the sun hasn't moved once. Reliable, that.",
		),
	)

/datum/shop_sku/general
	stock_min = 3
	stock_max = 6

/datum/shop_sku/general/medkit
	item_path = /obj/item/storage/medkit/regular
	price_credits = 200

/datum/shop_sku/general/toolbelt
	item_path = /obj/item/storage/belt/utility/atmostech
	price_credits = 350

/datum/shop_sku/general/gps
	item_path = /obj/item/gps
	price_credits = 150

/datum/shop_sku/general/oxygen_tank
	item_path = /obj/item/tank/internals/oxygen
	price_credits = 100

/datum/shop_sku/general/mesons
	item_path = /obj/item/clothing/glasses/meson
	price_credits = 250

/datum/shop_sku/general/diamond_pick
	item_path = /obj/item/pickaxe/diamond
	price_credits = 800
	stock_min = 1
	stock_max = 2

// Barter demo SKU: Barnaby pays in kit for raw plasma
/datum/shop_sku/barter/plasma_for_medkit
	name = "first-aid kit (plasma trade)"
	item_path = /obj/item/storage/medkit/regular
	barter_path = /obj/item/stack/sheet/mineral/plasma
	barter_amount = 10
	stock_min = 2
	stock_max = 4
