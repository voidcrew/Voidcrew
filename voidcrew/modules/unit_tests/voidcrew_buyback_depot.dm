// Quartermain Depot buybacks: rare goods reach their own rows and nothing else,
// commons stay on the plain rows. Fork defines compile after tests, so prices
// and colours are never read here, only which row matches what.

/datum/unit_test/voidcrew_buyback_depot
	abstract_type = /datum/unit_test/voidcrew_buyback_depot

/// A seller to carry the goods: matching only takes loose, carried items.
/datum/unit_test/voidcrew_buyback_depot/proc/seller()
	return allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)

/datum/unit_test/voidcrew_buyback_depot/sarge/Run()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_buyback/salvage = allocate(/datum/shop_buyback/outfitter/salvage_armor)
	var/datum/shop_buyback/officer = allocate(/datum/shop_buyback/outfitter/listed/officer_armor)
	var/datum/shop_buyback/military = allocate(/datum/shop_buyback/outfitter/listed/military_armor)
	var/datum/shop_buyback/service = allocate(/datum/shop_buyback/outfitter/listed/service_arms)
	var/datum/shop_buyback/heavy = allocate(/datum/shop_buyback/outfitter/listed/heavy_arms)
	var/datum/shop_buyback/arms = allocate(/datum/shop_buyback/outfitter/listed/military_arms)
	var/datum/shop_buyback/pieces = allocate(/datum/shop_buyback/outfitter/listed/collector_pieces)

	var/obj/item/marine = allocate(/obj/item/clothing/suit/armor/vest/marine, user)
	TEST_ASSERT(military.matches(marine), "Military armor refused a marine vest")
	TEST_ASSERT(!salvage.matches(marine), "Plain salvage also bought a marine vest")
	TEST_ASSERT(!officer.matches(marine), "Officer's armor bought a marine vest")

	var/obj/item/plain_vest = allocate(/obj/item/clothing/suit/armor/vest, user)
	TEST_ASSERT(salvage.matches(plain_vest), "Plain salvage refused a plain vest")
	TEST_ASSERT(!military.matches(plain_vest), "Military armor bought a plain vest")
	TEST_ASSERT(!officer.matches(plain_vest), "Officer's armor bought a plain vest")

	var/obj/item/hos_coat = allocate(/obj/item/clothing/suit/armor/hos, user)
	TEST_ASSERT(officer.matches(hos_coat), "Officer's armor refused a commander's coat")
	TEST_ASSERT(!salvage.matches(hos_coat), "Plain salvage also bought a commander's coat")

	// The ship's own kit sells as salvage only
	var/obj/item/issued = allocate(/obj/item/clothing/suit/armor/vest/marine, user)
	issued.buyback_hull_issue = TRUE
	TEST_ASSERT(!military.matches(issued), "Military armor bought a hull's own marine vest")
	TEST_ASSERT(salvage.matches(issued), "Plain salvage refused a hull's own marine vest")

	var/obj/item/saw = allocate(/obj/item/gun/ballistic/automatic/l6_saw/unrestricted, user)
	TEST_ASSERT(arms.matches(saw), "Military arms refused an L6 SAW")
	TEST_ASSERT(!heavy.matches(saw) && !service.matches(saw), "A cheaper row also bought an L6 SAW")

	var/obj/item/toy_saw = allocate(/obj/item/gun/ballistic/automatic/l6_saw/toy/unrestricted/riot, user)
	TEST_ASSERT(!arms.matches(toy_saw), "Military arms bought a foam SAW")

	var/obj/item/laser = allocate(/obj/item/gun/energy/laser, user)
	TEST_ASSERT(service.matches(laser), "Service arms refused a laser gun")
	TEST_ASSERT(!heavy.matches(laser) && !arms.matches(laser) && !pieces.matches(laser), "A rare row bought a plain laser gun")
	mark_trader_goods(laser)
	TEST_ASSERT(!service.matches(laser), "Service arms bought back a shop laser")

	var/obj/item/practice = allocate(/obj/item/gun/energy/laser/practice, user)
	TEST_ASSERT(!service.matches(practice), "Service arms bought a practice laser")

	var/obj/item/club = allocate(/obj/item/hierophant_club, user)
	TEST_ASSERT(pieces.matches(club), "One-of-a-kind pieces refused the hierophant club")

/datum/unit_test/voidcrew_buyback_depot/boffin/Run()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_buyback/grey_row = allocate(/datum/shop_buyback/skunk/slime_extract)
	var/datum/shop_buyback/rare_row = allocate(/datum/shop_buyback/skunk/slime_extract/rare)
	var/datum/shop_buyback/rainbow_row = allocate(/datum/shop_buyback/skunk/slime_extract/rainbow)
	var/datum/shop_buyback/cross_row = allocate(/datum/shop_buyback/skunk/crossbred)
	var/datum/shop_buyback/rare_cross_row = allocate(/datum/shop_buyback/skunk/crossbred/rare)

	var/obj/item/slime_extract/grey = allocate(/obj/item/slime_extract/grey, user)
	TEST_ASSERT(grey_row.matches(grey), "Boffin refused a grey extract")
	TEST_ASSERT(!rainbow_row.matches(grey) && !rare_row.matches(grey), "A rare extract row bought a grey extract")

	var/obj/item/slime_extract/rainbow = allocate(/obj/item/slime_extract/rainbow, user)
	TEST_ASSERT(rainbow_row.matches(rainbow), "Boffin refused a rainbow extract")
	TEST_ASSERT(!grey_row.matches(rainbow) && !rare_row.matches(rainbow), "A cheaper row bought a rainbow extract")
	rainbow.extract_uses = 0
	TEST_ASSERT(!rainbow_row.matches(rainbow), "Boffin bought a spent rainbow extract")

	var/obj/item/slimecross/stabilized/rainbow/stable_rainbow = allocate(/obj/item/slimecross/stabilized/rainbow, user)
	TEST_ASSERT(rare_cross_row.matches(stable_rainbow), "Boffin refused a stabilized rainbow extract")
	TEST_ASSERT(!cross_row.matches(stable_rainbow), "The common crossbreed row bought a rainbow crossbreed")
	var/obj/item/slimecross/stabilized/grey/stable_grey = allocate(/obj/item/slimecross/stabilized/grey, user)
	TEST_ASSERT(cross_row.matches(stable_grey), "Boffin refused a grey crossbreed")
	TEST_ASSERT(!rare_cross_row.matches(stable_grey), "The rare crossbreed row bought a grey crossbreed")

	var/datum/shop_buyback/common_cores = allocate(/datum/shop_buyback/skunk/anomaly_core)
	var/datum/shop_buyback/rare_cores = allocate(/datum/shop_buyback/skunk/anomaly_core/rare)
	var/datum/shop_buyback/raw_rare = allocate(/datum/shop_buyback/skunk/anomaly_core/raw/rare)

	var/obj/item/vortex = allocate(/obj/item/assembly/signaler/anomaly/vortex, user)
	TEST_ASSERT(rare_cores.matches(vortex), "Boffin refused a vortex core")
	TEST_ASSERT(!common_cores.matches(vortex) && !raw_rare.matches(vortex), "Another core row bought a refined vortex core")

	var/obj/item/flux = allocate(/obj/item/assembly/signaler/anomaly/flux, user)
	TEST_ASSERT(common_cores.matches(flux), "Boffin refused a flux core")
	TEST_ASSERT(!rare_cores.matches(flux), "The rare core row bought a flux core")

	var/obj/item/raw_anomaly_core/vortex/raw = allocate(/obj/item/raw_anomaly_core/vortex, user)
	TEST_ASSERT(raw_rare.matches(raw), "Boffin refused a raw vortex core")
	TEST_ASSERT(!rare_cores.matches(raw), "The refined core row bought a raw core")

	// A core refined from a bought raw core is still shop stock
	mark_trader_goods(raw)
	var/obj/item/refined = raw.create_core(user)
	allocated += refined
	TEST_ASSERT(is_trader_good(refined), "Refining a bought raw core washed off the shop's stamp")
	TEST_ASSERT(!rare_cores.matches(refined), "Boffin bought back a core refined from his own stock")

	// A core seated in a module stays put
	var/obj/item/mod/module/anomaly_locked/antigrav/module = allocate(/obj/item/mod/module/anomaly_locked/antigrav, user)
	var/obj/item/assembly/signaler/anomaly/grav/seated = allocate(/obj/item/assembly/signaler/anomaly/grav)
	seated.forceMove(module)
	module.core = seated
	TEST_ASSERT(!common_cores.matches(seated), "Boffin pulled a core out of a module")
	var/datum/shop_buyback/anomaly_modules = allocate(/datum/shop_buyback/fitter/anomaly_module)
	TEST_ASSERT(anomaly_modules.matches(module), "Wick refused an anti-gravity module with its core")

/datum/unit_test/voidcrew_buyback_depot/wick/Run()
	var/mob/living/carbon/human/user = seller()
	var/datum/shop_buyback/scrap = allocate(/datum/shop_buyback/fitter/scrap_control)
	var/datum/shop_buyback/armored = allocate(/datum/shop_buyback/fitter/rare_suit)
	var/datum/shop_buyback/syndicate = allocate(/datum/shop_buyback/fitter/rare_suit/syndicate)
	var/datum/shop_buyback/elite = allocate(/datum/shop_buyback/fitter/rare_suit/elite)

	var/obj/item/mod/control/elite_suit = allocate(/obj/item/mod/control/pre_equipped/empty/elite, user)
	TEST_ASSERT(elite.matches(elite_suit), "Wick refused an elite suit")
	TEST_ASSERT(!scrap.matches(elite_suit), "The scrap row also bought an elite suit")
	TEST_ASSERT(!syndicate.matches(elite_suit) && !armored.matches(elite_suit), "Another suit row bought an elite suit")

	var/obj/item/mod/control/civilian = allocate(/obj/item/mod/control/pre_equipped/civilian, user)
	TEST_ASSERT(scrap.matches(civilian), "The scrap row refused a civilian suit")
	TEST_ASSERT(!elite.matches(civilian) && !armored.matches(civilian) && !syndicate.matches(civilian), "A rare suit row bought a civilian suit")

	// The hull's own elite suit only sells as scrap
	var/obj/item/mod/control/issued = allocate(/obj/item/mod/control/pre_equipped/empty/elite, user)
	issued.buyback_hull_issue = TRUE
	TEST_ASSERT(!elite.matches(issued), "Wick paid vouchers for a hull's own elite suit")
	TEST_ASSERT(scrap.matches(issued), "The scrap row refused a hull's own elite suit")

	// A suit built around a shop core is scrap nowhere
	var/obj/item/mod/control/syndie = allocate(/obj/item/mod/control/pre_equipped/empty/syndicate, user)
	TEST_ASSERT(syndicate.matches(syndie), "Wick refused a syndicate suit")
	mark_trader_goods(syndie.core)
	TEST_ASSERT(!syndicate.matches(syndie), "Wick paid vouchers for a suit around a shop core")
	TEST_ASSERT(!scrap.matches(syndie), "The scrap row bought a suit around a shop core")

	var/datum/shop_buyback/rare_modules = allocate(/datum/shop_buyback/fitter/rare_module)
	var/obj/item/magboots = allocate(/obj/item/mod/module/magboot/advanced, user)
	TEST_ASSERT(rare_modules.matches(magboots), "Wick refused advanced magboots")
	var/obj/item/plain_magboots = allocate(/obj/item/mod/module/magboot, user)
	TEST_ASSERT(!rare_modules.matches(plain_magboots), "Wick bought printable magboots as a rare module")
