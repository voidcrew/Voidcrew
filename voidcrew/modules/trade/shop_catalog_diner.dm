/**
 * # The Chowder Pot: Roux, Halcyon's diner cook
 *
 * The waystation's diner: a full /datum/outpost_shop vendor stall (own stock,
 * own ledger, own voice) fronted by its own trader NPC, same wiring as Fern's
 * Potting Shed and Pike's tackle bench (see outpost.dm get_shop(),
 * trader_npc.dm for the mob). Lore closes a loop the outpost already had:
 * Barnaby buys "anything with fins for the chowder". Roux runs the pot he's
 * buying for.
 *
 * The menu is a quality ladder, and the rungs are mechanical, not just priced:
 * - COUNTER GRUB is factory food. No TRAIT_FOOD_CHEF_MADE, so eating it is
 *   "meh", cheap calories, nothing else (see edible.dm get_recipe_complexity).
 * - BLUE PLATE SPECIALS and the CHEF'S TABLE leave the pass with the chef-made
 *   trait added at dispense (the /plated SKU parent below), so they grant the
 *   real food-quality mood their crafting_complexity earns. That's the entire
 *   difference between a 40cr hot dog and a 260cr katsu curry.
 * - THE PANTRY sells the raw ingredients no other counter stocks (Barnaby has
 *   canned goods, Fern has seeds), so a ship galley can cook without a farm.
 *
 * Balance notes:
 * - The plated trait uses its own source key (TRAIT_SOURCE_OUTPOST_KITCHEN),
 *   and both the buyback ledger and the Kitchen Order contracts accept only
 *   HAS_TRAIT_NOT_FROM that source: Roux never buys her own plates back, and
 *   contracts can't be settled off her own counter.
 * - Every ledger payout sits below the cheapest plated SKU, so buy-to-sell-back
 *   loses money even before the source gate.
 * - Nothing here prints on a stock ship autolathe; dishes need a real kitchen.
 */

// =========================================================================
// THE CHOWDER POT: Roux, diner cook
// =========================================================================

/**
 * Roux: short-order, not haute cuisine. Grilling shorts and a ball cap instead
 * of a toque, because eleven years over the same pot is hot work and the hat
 * is about keeping hair out of the food. The ladle is the whole business.
 */
/datum/outfit/chowder_pot_roux
	name = "Diner cook"
	uniform = /obj/item/clothing/under/rank/civilian/cookjorts
	suit = /obj/item/clothing/suit/apron/chef
	head = /obj/item/clothing/head/soft/red
	shoes = /obj/item/clothing/shoes/sneakers/black
	r_hand = /obj/item/kitchen/spoon/soup_ladle

/// Roux, who has run the chowder pot for eleven years and the diner incidentally
/datum/outpost_shop/vendor/diner
	outpost_name = "\improper The Chowder Pot"
	outpost_desc = "Halcyon's diner and short-order counter."
	trader_name = "Roux"
	trader_outfit = /datum/outfit/chowder_pot_roux
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_4"
	trader_voice_pitch = 1.05
	categories = list(
		"Counter Grub",
		"Blue Plate Specials",
		"Chef's Table",
		"The Pantry",
	)
	sku_types = list(
		// Counter Grub: factory food, honest about it
		/datum/shop_sku/diner/fries,
		/datum/shop_sku/diner/hotdog,
		/datum/shop_sku/diner/pretzel,
		/datum/shop_sku/diner/popcorn,
		/datum/shop_sku/diner/muffin,
		/datum/shop_sku/diner/donut,
		// Blue Plate Specials: real cooking at diner prices
		/datum/shop_sku/diner/plated/house_burger,
		/datum/shop_sku/diner/plated/omelette,
		/datum/shop_sku/diner/plated/mac_n_cheese,
		/datum/shop_sku/diner/plated/egg_fried_rice,
		/datum/shop_sku/diner/plated/meatball_spaghetti,
		/datum/shop_sku/diner/plated/fish_and_chips,
		// Chef's Table: the good plates
		/datum/shop_sku/diner/plated/carbonara,
		/datum/shop_sku/diner/plated/bibimbap,
		/datum/shop_sku/diner/plated/katsu_curry,
		/datum/shop_sku/diner/plated/tonkotsu_ramen,
		/datum/shop_sku/diner/plated/big_blue,
		/datum/shop_sku/diner/plated/meat_pizza,
		/datum/shop_sku/diner/plated/chocolate_cake,
		/datum/shop_sku/diner/plated/grilled_cheese,
		// The Pantry: galley staples no other counter stocks
		/datum/shop_sku/diner/flour,
		/datum/shop_sku/diner/rice,
		/datum/shop_sku/diner/sugar,
		/datum/shop_sku/diner/milk,
		/datum/shop_sku/diner/butter,
		/datum/shop_sku/diner/eggs,
		/datum/shop_sku/diner/enzyme,
		/datum/shop_sku/diner/meat_slab,
		/datum/shop_sku/diner/monkey_cubes,
	)
	// The specials board: a few of these rotate on each round
	rotating_pool = list(
		/datum/shop_sku/diner/plated/rotating/gumbo,
		/datum/shop_sku/diner/plated/rotating/risotto,
		/datum/shop_sku/diner/plated/rotating/pho,
		/datum/shop_sku/diner/plated/rotating/pad_thai,
		/datum/shop_sku/diner/plated/rotating/kitsune_udon,
		/datum/shop_sku/diner/rotating/mystery_crate,
	)
	rare_pool = list(
		/datum/shop_sku/diner/plated/rare/setagaya_curry,
		/datum/shop_sku/diner/plated/rare/birthday_cake,
		/datum/shop_sku/diner/plated/rare/berry_clafoutis,
	)
	buyback_types = list(
		/datum/shop_buyback/diner/home_cooking,
		/datum/shop_buyback/diner/pie_case,
		/datum/shop_buyback/diner/whole_cake,
		/datum/shop_buyback/diner/donk_recall,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Order up. Eat it while it's hot or don't tell me about it.",
			"There you go. Plate comes back, or the plate's price goes on your next one.",
			"Good choice. That one fought me all morning and lost.",
			"Order up! Careful, the plate's hotter than it has any right to be.",
		),
		TRADER_LINE_REFUSAL = list(
			"Barnaby flagged your ship, so the kitchen's closed. To you, specifically.",
			"No service for embargoed crews. House rule, and the house is a chowder pot.",
			"Square up with the waystation first. Then we can talk pie.",
		),
		TRADER_LINE_IDLE = list(
			"The chowder pot's been going eleven years. You don't clean a pot like that, you come to an understanding with it.",
			"Barnaby buys anything with fins and sends it straight through my hatch. The pot forgives. That's its whole job.",
			"Fern grows it, Pike catches it, Barnaby haggles over it, and I make it edible. The system works.",
			"Bring me a proper home-cooked dish and I'll pay real money. The factory stuff I already have. Crates of it.",
			"The specials board changes when the convoy brings something interesting in. Or when I drop the chalk.",
			"Counter grub fills you up and that's all it does. If you want a meal that means something, it comes off the pass.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. Pantry's full, new special on the board. Come hungry.",
			"Restock day. The pot got a top-up and only complained a little.",
			"That's the supply run. If the special looks unfamiliar, it's because it's new. Be brave.",
		),
	)

// ===== COUNTER GRUB =====
// Factory food, cheap and fast. No chef-made trait on purpose: this shelf is
// the "meh" rung of the ladder, and the menu says so out loud.

/datum/shop_sku/diner
	stock_min = 4
	stock_max = 8

/datum/shop_sku/diner/fries
	category = "Counter Grub"
	name = "basket of space fries"
	item_path = /obj/item/food/fries
	price_credits = 35

/datum/shop_sku/diner/hotdog
	category = "Counter Grub"
	item_path = /obj/item/food/hotdog
	price_credits = 45

/datum/shop_sku/diner/pretzel
	category = "Counter Grub"
	item_path = /obj/item/food/ballpark_pretzel
	price_credits = 30

/datum/shop_sku/diner/popcorn
	category = "Counter Grub"
	item_path = /obj/item/food/popcorn
	price_credits = 25

/datum/shop_sku/diner/muffin
	category = "Counter Grub"
	item_path = /obj/item/food/muffin/berry
	price_credits = 35

/datum/shop_sku/diner/donut
	category = "Counter Grub"
	item_path = /obj/item/food/donut/plain
	price_credits = 30

// ===== THE PLATED SHELVES =====
// Everything below leaves the pass with Roux's mark on it. The chef-made
// trait is what turns crafting_complexity into a real food-quality mood on
// eating, without it a 300cr plate would chew exactly like a 30cr donut.
// The dedicated trait source is load-bearing: her ledger and the Kitchen
// Order contracts refuse anything carrying the trait ONLY from this source,
// which is what stops buy-from-Roux-sell-to-Roux round trips.

/datum/shop_sku/diner/plated
	stock_min = 2
	stock_max = 4

/datum/shop_sku/diner/plated/dispense(mob/living/user, mob/living/basic/outpost_trader/vendor)
	var/atom/movable/goods = ..()
	if(!isnull(goods))
		ADD_TRAIT(goods, TRAIT_FOOD_CHEF_MADE, TRAIT_SOURCE_OUTPOST_KITCHEN)
	return goods

// ===== BLUE PLATE SPECIALS =====

/datum/shop_sku/diner/plated/house_burger
	category = "Blue Plate Specials"
	name = "house burger"
	desc = "The Chowder Pot's standing burger. Nothing on it needs explaining, which around here is a selling point."
	item_path = /obj/item/food/burger/plain
	price_credits = 90

/datum/shop_sku/diner/plated/omelette
	category = "Blue Plate Specials"
	item_path = /obj/item/food/omelette
	price_credits = 90

/datum/shop_sku/diner/plated/mac_n_cheese
	category = "Blue Plate Specials"
	item_path = /obj/item/food/spaghetti/mac_n_cheese
	price_credits = 100

/datum/shop_sku/diner/plated/egg_fried_rice
	category = "Blue Plate Specials"
	item_path = /obj/item/food/salad/egg_fried_rice
	price_credits = 100

/datum/shop_sku/diner/plated/meatball_spaghetti
	category = "Blue Plate Specials"
	item_path = /obj/item/food/spaghetti/meatballspaghetti
	price_credits = 120

/datum/shop_sku/diner/plated/fish_and_chips
	category = "Blue Plate Specials"
	desc = "Whatever the anglers brought in, battered and honest. The fish changes daily; the chips do not."
	item_path = /obj/item/food/fishandchips
	price_credits = 130

// ===== CHEF'S TABLE =====

/datum/shop_sku/diner/plated/carbonara
	category = "Chef's Table"
	item_path = /obj/item/food/spaghetti/carbonara
	price_credits = 220
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/bibimbap
	category = "Chef's Table"
	item_path = /obj/item/food/salad/bibimbap
	price_credits = 240
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/katsu_curry
	category = "Chef's Table"
	item_path = /obj/item/food/salad/katsu_curry
	price_credits = 260
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/tonkotsu_ramen
	category = "Chef's Table"
	item_path = /obj/item/food/spaghetti/shoyu_tonkotsu_ramen
	price_credits = 260
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/big_blue
	category = "Chef's Table"
	item_path = /obj/item/food/burger/big_blue
	price_credits = 280
	stock_min = 1
	stock_max = 2

// A whole pie feeds a crew, and slices cut from a chef-made pizza inherit the
// trait (pizza.dm), so every slice eats like it came off the pass.
/datum/shop_sku/diner/plated/meat_pizza
	category = "Chef's Table"
	name = "meat-lover's pizza (whole)"
	item_path = /obj/item/food/pizza/meat
	price_credits = 320
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/chocolate_cake
	category = "Chef's Table"
	name = "chocolate cake (whole)"
	item_path = /obj/item/food/cake/chocolate
	price_credits = 330
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/grilled_cheese
	category = "Chef's Table"
	name = "actually grilled cheese"
	item_path = /obj/item/food/grilled_cheese
	price_credits = 240
	stock_min = 1
	stock_max = 2

// ===== THE PANTRY =====
// Raw galley staples. Deliberately no overlap with the neighbors: Barnaby
// keeps the canned goods, Fern the seeds. This shelf is what a ship kitchen
// needs that neither of them stocks.

/datum/shop_sku/diner/flour
	category = "The Pantry"
	item_path = /obj/item/reagent_containers/condiment/flour
	price_credits = 30
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/rice
	category = "The Pantry"
	item_path = /obj/item/reagent_containers/condiment/rice
	price_credits = 30
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/sugar
	category = "The Pantry"
	item_path = /obj/item/reagent_containers/condiment/sugar
	price_credits = 30
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/milk
	category = "The Pantry"
	item_path = /obj/item/reagent_containers/condiment/milk
	price_credits = 30
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/butter
	category = "The Pantry"
	item_path = /obj/item/food/butter
	price_credits = 40
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/eggs
	category = "The Pantry"
	name = "carton of eggs"
	item_path = /obj/item/storage/fancy/egg_box
	price_credits = 50
	stock_min = 2
	stock_max = 4

/datum/shop_sku/diner/enzyme
	category = "The Pantry"
	name = "universal enzyme"
	desc = "The bottle that turns milk into cheese and dough into more interesting dough. Roux refills it from a drum in the back she calls the mother bottle."
	item_path = /obj/item/reagent_containers/condiment/enzyme
	price_credits = 60
	stock_min = 2
	stock_max = 4

/datum/shop_sku/diner/meat_slab
	category = "The Pantry"
	name = "slab of meat"
	desc = "A butcher's slab off the convoy cold-crate. Roux does not specify the animal and considers the question rude."
	item_path = /obj/item/food/meat/slab
	price_credits = 60
	stock_min = 3
	stock_max = 6

/datum/shop_sku/diner/monkey_cubes
	category = "The Pantry"
	name = "box of monkey cubes"
	desc = "Just add water and look away. The renewable meat supply for any galley that can stomach the middle step."
	item_path = /obj/item/storage/box/monkeycubes
	price_credits = 300
	stock_min = 1
	stock_max = 2

// ===== THE SPECIALS BOARD (rotating shelf) =====

/datum/shop_sku/diner/plated/rotating
	stock_min = 1
	stock_max = 2

/datum/shop_sku/diner/plated/rotating/gumbo
	category = "Blue Plate Specials"
	desc = "The chowder pot's southern cousin. Roux insists they are different pots and refuses to elaborate."
	item_path = /obj/item/food/salad/gumbo
	price_credits = 180

/datum/shop_sku/diner/plated/rotating/risotto
	category = "Blue Plate Specials"
	item_path = /obj/item/food/salad/risotto
	price_credits = 180

/datum/shop_sku/diner/plated/rotating/pho
	category = "Chef's Table"
	item_path = /obj/item/food/spaghetti/pho
	price_credits = 220

/datum/shop_sku/diner/plated/rotating/pad_thai
	category = "Chef's Table"
	item_path = /obj/item/food/spaghetti/pad_thai
	price_credits = 220

/datum/shop_sku/diner/plated/rotating/kitsune_udon
	category = "Chef's Table"
	item_path = /obj/item/food/spaghetti/kitsune_udon
	price_credits = 200

// The one rotating slot that isn't a plate: a sealed ingredient crate off the
// convoy manifest. Factory goods, so no /plated parent.
/datum/shop_sku/diner/rotating/mystery_crate
	category = "The Pantry"
	name = "unlabeled ingredient box"
	desc = "A themed ingredient box with the label steamed off. Roux buys them by the pallet and sells the surprise at cost."
	item_path = /obj/item/storage/box/ingredients/random
	price_credits = 150
	stock_min = 1
	stock_max = 2

// ===== OFF THE MENU (rare showcase) =====

/datum/shop_sku/diner/plated/rare/setagaya_curry
	category = "Chef's Table"
	desc = "The recipe is a guarded secret among cafe owners across human space, and Roux will not say what she traded for it. Eating it is said to replenish the soul. The pot has opinions about that claim."
	item_path = /obj/item/food/salad/setagaya_curry
	price_credits = 600

/datum/shop_sku/diner/plated/rare/birthday_cake
	category = "Chef's Table"
	name = "birthday cake"
	desc = "Somebody on your crew has a birthday coming. Statistically."
	item_path = /obj/item/food/cake/birthday
	price_credits = 400

/datum/shop_sku/diner/plated/rare/berry_clafoutis
	category = "Chef's Table"
	item_path = /obj/item/food/pie/berryclafoutis
	price_credits = 300

// ===== ROUX'S ORDER WHEEL (buybacks) =====
// She pays for real cooking only: TRAIT_FOOD_CHEF_MADE from any source except
// her own pass (see matches below). Payouts all sit below the cheapest plated
// SKU, so round-tripping her own stock loses money twice over.

/datum/shop_buyback/diner/home_cooking
	name = "home-cooked meal (any proper dish)"
	desc = "Any dish somebody actually cooked, two steps or better. It goes under the heat lamp with a MADE FRESH LOCALLY card and sells out by close."
	category = "Kitchen Orders"
	item_path = /obj/item/food
	pay_credits = 60
	demand_min = 5
	demand_max = 8
	/// Minimum crafting_complexity for a dish to count as real cooking
	var/min_complexity = FOOD_COMPLEXITY_2

/datum/shop_buyback/diner/home_cooking/matches(obj/item/offered)
	if(!..())
		return FALSE
	// Cooked by an actual person, and not by this kitchen
	if(!HAS_TRAIT_NOT_FROM(offered, TRAIT_FOOD_CHEF_MADE, TRAIT_SOURCE_OUTPOST_KITCHEN))
		return FALSE
	var/obj/item/food/dish = offered
	return dish.crafting_complexity >= min_complexity

/datum/shop_buyback/diner/pie_case
	name = "pie for the counter case"
	desc = "The glass case by the till holds six pies and is currently holding fewer than six pies. Any filling, baked by hand."
	category = "Kitchen Orders"
	item_path = /obj/item/food/pie
	pay_credits = 120
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/diner/pie_case/matches(obj/item/offered)
	if(!..())
		return FALSE
	return HAS_TRAIT_NOT_FROM(offered, TRAIT_FOOD_CHEF_MADE, TRAIT_SOURCE_OUTPOST_KITCHEN)

/datum/shop_buyback/diner/whole_cake
	name = "whole cake, any kind"
	desc = "Uncut and hand-made. Waystation birthdays outrun Roux's oven by about two cakes a week."
	category = "Kitchen Orders"
	item_path = /obj/item/food/cake
	pay_credits = 180
	demand_min = 1
	demand_max = 3

/datum/shop_buyback/diner/whole_cake/matches(obj/item/offered)
	if(!..())
		return FALSE
	return HAS_TRAIT_NOT_FROM(offered, TRAIT_FOOD_CHEF_MADE, TRAIT_SOURCE_OUTPOST_KITCHEN)

// The scavenger's rung: no chef gate, pocket change. Donk Co. pays a standing
// recall bounty and Roux passes it along, minus handling.
/datum/shop_buyback/diner/donk_recall
	name = "donk-pockets (factory recall)"
	desc = "Donk Co. recalled a production run out this way years ago and never stopped paying the bounty. Roux ships them back by the crate and does not eat them."
	category = "Kitchen Orders"
	item_path = /obj/item/food/donkpocket
	pay_credits = 20
	demand_min = 6
	demand_max = 12
