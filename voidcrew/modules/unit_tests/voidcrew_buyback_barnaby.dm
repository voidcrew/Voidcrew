/// Halcyon's ledgers (Barnaby, Fern, Pike, Roux): rare goods hit their own
/// entry and never the catch-all, and commons never hit a rare entry.
/datum/unit_test/voidcrew_buyback_halcyon
	abstract_type = /datum/unit_test/voidcrew_buyback_halcyon

/// Fern: prize plants clear a potency bar; under it they go to the farm stand.
/datum/unit_test/voidcrew_buyback_halcyon/fern/Run()
	var/datum/shop_buyback/potting/produce/stand = allocate(/datum/shop_buyback/potting/produce)
	var/datum/shop_buyback/potting/prize/omega_weed/omega = allocate(/datum/shop_buyback/potting/prize/omega_weed)
	var/datum/shop_buyback/potting/prize/holymelon/melon_entry = allocate(/datum/shop_buyback/potting/prize/holymelon)

	var/obj/item/food/grown/cannabis/ultimate/weed = allocate(/obj/item/food/grown/cannabis/ultimate)
	TEST_ASSERT_NOTNULL(weed.seed, "Omega weed spawned without a seed")
	weed.seed.potency = 60
	TEST_ASSERT(omega.matches(weed), "Fern refused strong omega weed")
	TEST_ASSERT(!stand.matches(weed), "Strong omega weed also sold at the farm stand")
	weed.seed.potency = 20
	TEST_ASSERT(!omega.matches(weed), "Fern paid vouchers for weak omega weed")
	TEST_ASSERT(stand.matches(weed), "Weak omega weed sells nowhere")

	var/obj/item/food/grown/holymelon/melon = allocate(/obj/item/food/grown/holymelon)
	melon.seed.potency = 40
	TEST_ASSERT(melon_entry.matches(melon), "Fern refused a good holy melon")
	TEST_ASSERT(!stand.matches(melon), "A good holy melon also sold at the farm stand")

	var/obj/item/food/grown/tomato/tomato = allocate(/obj/item/food/grown/tomato)
	tomato.seed.potency = 100
	TEST_ASSERT(stand.matches(tomato), "The farm stand refused a tomato")
	TEST_ASSERT(!claimed_by_buyback_family(tomato, /datum/shop_buyback/potting/prize), "A plain tomato hit a prize entry")

/// Pike and Barnaby split the fish: trophies to Pike, everything else to the pot.
/datum/unit_test/voidcrew_buyback_halcyon/fish/Run()
	var/datum/shop_buyback/general/fresh_catch/pot = allocate(/datum/shop_buyback/general/fresh_catch)
	var/datum/shop_buyback/bait/nessie/nessie_entry = allocate(/datum/shop_buyback/bait/nessie)
	var/datum/shop_buyback/bait/moonfish/moon_entry = allocate(/datum/shop_buyback/bait/moonfish)
	var/datum/shop_buyback/bait/pike/pike_entry = allocate(/datum/shop_buyback/bait/pike)
	var/datum/shop_buyback/bait/armored_pike/armored_entry = allocate(/datum/shop_buyback/bait/armored_pike)

	var/obj/item/fish/fryish/nessie/nessie = allocate(/obj/item/fish/fryish/nessie)
	TEST_ASSERT(nessie_entry.matches(nessie), "Pike refused a nessie-fish")
	TEST_ASSERT(!pot.matches(nessie), "A nessie-fish went in Barnaby's chowder")

	var/obj/item/fish/moonfish/moonfish = allocate(/obj/item/fish/moonfish)
	var/obj/item/fish/moonfish/dwarf/dwarf = allocate(/obj/item/fish/moonfish/dwarf)
	TEST_ASSERT(moon_entry.matches(moonfish), "Pike refused a moonfish")
	TEST_ASSERT(!pot.matches(moonfish), "A moonfish went in Barnaby's chowder")
	TEST_ASSERT(!moon_entry.matches(dwarf), "Pike took a dwarf moonfish as a trophy")
	TEST_ASSERT(pot.matches(dwarf), "A dwarf moonfish sells nowhere")

	var/obj/item/fish/pike/armored/armored = allocate(/obj/item/fish/pike/armored)
	TEST_ASSERT(armored_entry.matches(armored), "Pike refused an armored pike")
	TEST_ASSERT(!pike_entry.matches(armored), "An armored pike also sold as a plain pike")
	TEST_ASSERT(!pot.matches(armored), "An armored pike went in Barnaby's chowder")

	var/obj/item/fish/goldfish/goldfish = allocate(/obj/item/fish/goldfish)
	TEST_ASSERT(pot.matches(goldfish), "Barnaby refused a goldfish")
	TEST_ASSERT(!claimed_by_buyback_family(goldfish, /datum/shop_buyback/bait), "A goldfish hit a trophy entry")

/// Roux: specials leave the catch-alls, and only real cooking counts.
/datum/unit_test/voidcrew_buyback_halcyon/diner/Run()
	var/datum/shop_buyback/diner/home_cooking/wheel = allocate(/datum/shop_buyback/diner/home_cooking)
	var/datum/shop_buyback/diner/whole_cake/cakes = allocate(/datum/shop_buyback/diner/whole_cake)
	var/datum/shop_buyback/diner/donk_recall/recall = allocate(/datum/shop_buyback/diner/donk_recall)
	var/datum/shop_buyback/diner/special/stuffed_legion/legion_entry = allocate(/datum/shop_buyback/diner/special/stuffed_legion)
	var/datum/shop_buyback/diner/special/energy_cake/cake_entry = allocate(/datum/shop_buyback/diner/special/energy_cake)
	var/datum/shop_buyback/diner/special/gondola_pocket/gondola_entry = allocate(/datum/shop_buyback/diner/special/gondola_pocket)

	var/obj/item/food/stuffedlegion/legion = allocate(/obj/item/food/stuffedlegion)
	TEST_ASSERT(!legion_entry.matches(legion), "Roux paid for a stuffed legion nobody cooked")
	ADD_TRAIT(legion, TRAIT_FOOD_CHEF_MADE, "unit_test")
	TEST_ASSERT(legion_entry.matches(legion), "Roux refused a cooked stuffed legion")
	TEST_ASSERT(!wheel.matches(legion), "A stuffed legion also sold as a home-cooked meal")

	var/obj/item/food/cake/birthday/energy/energy_cake = allocate(/obj/item/food/cake/birthday/energy)
	ADD_TRAIT(energy_cake, TRAIT_FOOD_CHEF_MADE, "unit_test")
	TEST_ASSERT(cake_entry.matches(energy_cake), "Roux refused an energy cake")
	TEST_ASSERT(!cakes.matches(energy_cake), "An energy cake also sold as a plain whole cake")

	var/obj/item/food/donkpocket/warm/gondola/gondola = allocate(/obj/item/food/donkpocket/warm/gondola)
	ADD_TRAIT(gondola, TRAIT_FOOD_CHEF_MADE, "unit_test")
	TEST_ASSERT(gondola_entry.matches(gondola), "Roux refused a warm gondola pocket")
	TEST_ASSERT(!recall.matches(gondola), "A gondola pocket also sold as a recalled donk-pocket")

	var/obj/item/food/burger/plain/burger = allocate(/obj/item/food/burger/plain)
	ADD_TRAIT(burger, TRAIT_FOOD_CHEF_MADE, "unit_test")
	TEST_ASSERT(wheel.matches(burger), "Roux refused a home-cooked burger")
	TEST_ASSERT(!claimed_by_buyback_family(burger, /datum/shop_buyback/diner/special), "A plain burger hit a special")

/// The convoy refills credit entries but never a voucher entry.
/datum/unit_test/voidcrew_buyback_halcyon/voucher_demand/Run()
	var/datum/outpost_shop/vendor/diner/shop = allocate(/datum/outpost_shop/vendor/diner)
	var/datum/shop_buyback/voucher_entry
	var/datum/shop_buyback/credit_entry
	for(var/datum/shop_buyback/buyback as anything in shop.buybacks)
		if(buyback.pay_vouchers > 0)
			voucher_entry ||= buyback
		else
			credit_entry ||= buyback
	TEST_ASSERT_NOTNULL(voucher_entry, "Roux has no voucher entry")
	TEST_ASSERT_NOTNULL(credit_entry, "Roux has no credit entry")
	voucher_entry.demand = 0
	credit_entry.demand = 0
	shop.convoy_restock()
	TEST_ASSERT_EQUAL(voucher_entry.demand, 0, "A convoy refilled a voucher buyback")
	TEST_ASSERT(credit_entry.demand > 0, "A convoy stopped refilling credit buybacks")
