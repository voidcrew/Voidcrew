// Buyback ledgers for Dram, Sawbones and Splice: each rare good lands on its
// rare line and never on the cheap one, and a common good never reaches the
// rare line. Fork defines compile after tests, so trait names are literals.

/datum/unit_test/voidcrew_buyback_vex_drinks

/datum/unit_test/voidcrew_buyback_vex_drinks/proc/pour(drink, amount, filler_amount = 0)
	var/obj/item/reagent_containers/cup/glass/drinkingglass/glass = allocate(/obj/item/reagent_containers/cup/glass/drinkingglass)
	glass.reagents.add_reagent(drink, amount)
	if(filler_amount)
		glass.reagents.add_reagent(/datum/reagent/water, filler_amount)
	return glass

/datum/unit_test/voidcrew_buyback_vex_drinks/Run()
	var/datum/shop_buyback/juice = allocate(/datum/shop_buyback/dregs/cocktail/the_juice)
	var/datum/shop_buyback/coffee = allocate(/datum/shop_buyback/dregs/cocktail/hot_ice_coffee)
	var/datum/shop_buyback/house = allocate(/datum/shop_buyback/dregs/cocktail/house)
	var/datum/shop_buyback/fancy = allocate(/datum/shop_buyback/dregs/cocktail/fancy)

	var/obj/item/juice_glass = pour(/datum/reagent/consumable/ethanol/the_juice, 50)
	TEST_ASSERT(juice.matches(juice_glass), "A full glass of The Juice missed its line")
	TEST_ASSERT(!house.matches(juice_glass) && !fancy.matches(juice_glass), "The Juice also sold on a credit line")

	var/obj/item/coffee_glass = pour(/datum/reagent/consumable/hot_ice_coffee, 40)
	TEST_ASSERT(coffee.matches(coffee_glass), "Hot Ice Coffee missed its line")
	TEST_ASSERT(!house.matches(coffee_glass) && !juice.matches(coffee_glass), "Hot Ice Coffee sold on another line")

	var/obj/item/watered = pour(/datum/reagent/consumable/ethanol/the_juice, 20, 30)
	TEST_ASSERT(!juice.matches(watered), "Watered-down Juice sold as The Juice")
	var/obj/item/splash = pour(/datum/reagent/consumable/ethanol/the_juice, 10)
	TEST_ASSERT(!juice.matches(splash), "A splash of The Juice sold as a full glass")

	var/obj/item/blaster = pour(/datum/reagent/consumable/ethanol/gargle_blaster, 50)
	TEST_ASSERT(house.matches(blaster), "A Gargle Blaster missed the house cocktail line")
	TEST_ASSERT(!juice.matches(blaster) && !coffee.matches(blaster) && !fancy.matches(blaster), "A house cocktail reached a rarer line")

	var/obj/item/neuro = pour(/datum/reagent/consumable/ethanol/neurotoxin, 50)
	TEST_ASSERT(fancy.matches(neuro) && !house.matches(neuro), "Neurotoxin landed on the wrong line")

	var/obj/item/bottle = allocate(/obj/item/reagent_containers/cup/glass/bottle/kong)
	TEST_ASSERT(!house.matches(bottle), "A bottle sold as a cocktail")

/datum/unit_test/voidcrew_buyback_vex_organs

/datum/unit_test/voidcrew_buyback_vex_organs/Run()
	var/datum/shop_buyback/donor_heart = allocate(/datum/shop_buyback/clinic/heart)
	var/datum/shop_buyback/donor_lungs = allocate(/datum/shop_buyback/clinic/lungs)
	var/datum/shop_buyback/species = allocate(/datum/shop_buyback/clinic_exotic/species)
	var/datum/shop_buyback/voltaic = allocate(/datum/shop_buyback/clinic_exotic/voltaic_heart)
	var/datum/shop_buyback/meridian = allocate(/datum/shop_buyback/clinic_exotic/meridian_heart)

	var/obj/item/organ/heart/ethereal/crystal = allocate(/obj/item/organ/heart/ethereal)
	TEST_ASSERT(species.matches(crystal), "An ethereal heart missed the off-world line")
	TEST_ASSERT(!donor_heart.matches(crystal), "An ethereal heart also sold as a plain donor heart")
	var/obj/item/organ/lungs/plasmaman/bone_lungs = allocate(/obj/item/organ/lungs/plasmaman)
	TEST_ASSERT(species.matches(bone_lungs) && !donor_lungs.matches(bone_lungs), "Plasmaman lungs landed on the wrong line")

	var/obj/item/organ/heart/plain = allocate(/obj/item/organ/heart)
	TEST_ASSERT(donor_heart.matches(plain), "A plain heart missed the donor line")
	TEST_ASSERT(!species.matches(plain) && !voltaic.matches(plain) && !meridian.matches(plain), "A plain heart reached an exotic line")

	var/obj/item/organ/tongue/lizard/printed = allocate(/obj/item/organ/tongue/lizard)
	ADD_TRAIT(printed, "printed_organ", INNATE_TRAIT)
	TEST_ASSERT(!species.matches(printed), "A limbgrower lizard tongue sold as a donor organ")

	var/obj/item/organ/heart/cybernetic/anomalock/empty = allocate(/obj/item/organ/heart/cybernetic/anomalock)
	TEST_ASSERT(!voltaic.matches(empty), "A coreless voltaic shell sold as a cored heart")
	var/obj/item/organ/heart/cybernetic/anomalock/prebuilt/cored = allocate(/obj/item/organ/heart/cybernetic/anomalock/prebuilt)
	TEST_ASSERT(voltaic.matches(cored), "A cored voltaic heart missed its line")
	TEST_ASSERT(!donor_heart.matches(cored), "A voltaic heart sold as a donor heart")

	var/obj/item/organ/heart/cybernetic/meridian/found = allocate(/obj/item/organ/heart/cybernetic/meridian)
	TEST_ASSERT(meridian.matches(found) && !donor_heart.matches(found) && !voltaic.matches(found), "The Meridian heart landed on the wrong line")

/datum/unit_test/voidcrew_buyback_vex_chrome

/datum/unit_test/voidcrew_buyback_vex_chrome/Run()
	var/datum/shop_buyback/fitted = allocate(/datum/shop_buyback/found_chrome/fitted)
	var/datum/shop_buyback/pro = allocate(/datum/shop_buyback/found_chrome/pro)
	var/datum/shop_buyback/military = allocate(/datum/shop_buyback/found_chrome/military)
	var/datum/shop_buyback/legend = allocate(/datum/shop_buyback/found_chrome/legend)

	var/obj/item/organ/ronin = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin)
	TEST_ASSERT(military.matches(ronin), "A found Ronin arm missed the military line")
	TEST_ASSERT(!pro.matches(ronin) && !fitted.matches(ronin) && !legend.matches(ronin), "A Ronin arm sold on a cheaper line")

	var/obj/item/organ/blade = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/mantis/scorch/left)
	TEST_ASSERT(pro.matches(blade) && !military.matches(blade), "A single scorch blade landed on the wrong line")

	var/obj/item/organ/pick = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/icepick)
	TEST_ASSERT(fitted.matches(pick) && !pro.matches(pick), "A found Icepick landed on the wrong line")

	var/obj/item/organ/bought = allocate(/obj/item/organ/cyberimp/arm/toolkit/cyberware/ronin)
	mark_trader_goods(bought)
	TEST_ASSERT(!military.matches(bought), "Splice paid vouchers for shop stock")

	var/obj/item/organ/printed = allocate(/obj/item/organ/eyes/robotic/thermals)
	for(var/datum/shop_buyback/band as anything in list(fitted, pro, military, legend))
		TEST_ASSERT(!band.matches(printed), "Lathe-printed thermal eyes sold as chrome on [band.type]")

	// Every installable piece fits at most one row on each ripperdoc's ledger,
	// found or bought, and Ratchet never pays vouchers.
	var/list/all_ware = list()
	for(var/ware_type in subtypesof(/obj/item/organ/cyberimp/cyberware) + subtypesof(/obj/item/organ/eyes/robotic/cyberware) + subtypesof(/obj/item/organ/cyberimp/arm/toolkit/cyberware))
		all_ware += allocate(ware_type)
	for(var/shop_type in list(/datum/outpost_shop/vendor/ripperdoc, /datum/outpost_shop/vendor/street_doc))
		var/datum/outpost_shop/shop = allocate(shop_type)
		for(var/datum/shop_buyback/row as anything in shop.buybacks)
			if(shop_type == /datum/outpost_shop/vendor/street_doc)
				TEST_ASSERT(!row.pay_vouchers, "[row.type] at the street doc pays vouchers")
		for(var/obj/item/organ/found as anything in all_ware)
			var/list/hits = list()
			for(var/datum/shop_buyback/row as anything in shop.buybacks)
				if(row.matches(found))
					hits += row.type
			TEST_ASSERT(length(hits) <= 1, "[found.type] fits [length(hits)] rows at [shop_type]: [jointext(hits, ", ")]")
