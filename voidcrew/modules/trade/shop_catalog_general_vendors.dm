/**
 * # Waystation Halcyon — vendor stalls
 *
 * Halcyon's side businesses: Fern in the conservatory running the Potting
 * Shed, and Pike selling tackle off a bench beside the pond he dug into the
 * deck plating. Each is a full /datum/outpost_shop (own stock, own buyback
 * ledger, own voice) fronted by its own trader NPC — same wiring as the
 * Undertow's stalls (see outpost.dm get_shop(), trader_npc.dm for the mobs).
 *
 * Balance notes:
 * - No overlap with Barnaby's counter: he keeps the starter fishing rod and
 *   the groceries; Fern owns seeds/botany kit, Pike owns tackle and the
 *   serious rods.
 * - Fern's produce buyback pays pocket change on purpose — it's the "sell
 *   your harvest at the waystation" fantasy, not an economy. Her real asks
 *   (grafts, ash flora) only come off planets.
 * - Pike never buys what his own pond stocks at meaningful prices; the
 *   trophy ledger wants the weird stuff.
 */

// =========================================================================
// THE POTTING SHED — Fern, conservatory keeper
// =========================================================================

/// Fern, who grows real food in real dirt on a metal station and will tell you about it
/datum/outpost_shop/vendor/potting_shed
	outpost_name = "\improper The Potting Shed"
	outpost_desc = "Halcyon's conservatory and seed counter."
	trader_name = "Fern"
	trader_outfit = /datum/outfit/job/botanist
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 1.22
	categories = list(
		"Seed Rack",
		"Grower's Supply",
		"The Apiary",
	)
	sku_types = list(
		// Seed Rack — honest staples for a ship galley
		/datum/shop_sku/potting/tomato,
		/datum/shop_sku/potting/potato,
		/datum/shop_sku/potting/carrot,
		/datum/shop_sku/potting/wheat,
		/datum/shop_sku/potting/chili,
		/datum/shop_sku/potting/watermelon,
		/datum/shop_sku/potting/apple,
		/datum/shop_sku/potting/sugarcane,
		/datum/shop_sku/potting/berry,
		// Grower's Supply
		/datum/shop_sku/potting/plant_analyzer,
		/datum/shop_sku/potting/watering_can,
		/datum/shop_sku/potting/cultivator,
		/datum/shop_sku/potting/secateurs,
		/datum/shop_sku/potting/plantbgone,
		/datum/shop_sku/potting/leather_gloves,
		/datum/shop_sku/potting/plant_bag,
		/datum/shop_sku/potting/ez_nutrient,
		/datum/shop_sku/potting/overalls,
		// The Apiary
		/datum/shop_sku/potting/honeycomb,
		/datum/shop_sku/potting/honey_frame,
		/datum/shop_sku/potting/queen_bee,
	)
	rotating_pool = list(
		/datum/shop_sku/potting/rotating/glowshroom,
		/datum/shop_sku/potting/rotating/towercap,
		/datum/shop_sku/potting/rotating/sunflower,
		/datum/shop_sku/potting/rotating/ambrosia,
		/datum/shop_sku/potting/rotating/banana,
		/datum/shop_sku/potting/rotating/cherry,
	)
	rare_pool = list(
		/datum/shop_sku/potting/rare/gaia,
		/datum/shop_sku/potting/rare/mystery_seeds,
	)
	buyback_types = list(
		/datum/shop_buyback/potting/graft,
		/datum/shop_buyback/potting/ash_flora,
		/datum/shop_buyback/potting/produce,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Water it, talk to it, don't let the mechanic near it. She means well.",
			"Lovely choice. That one likes low light and forgiveness.",
			"There you go. If it dies, it's the ship's fault. It's always the ship's fault.",
			"Sold! Bring me a cutting if it turns out interesting.",
		),
		TRADER_LINE_REFUSAL = list(
			"Barnaby says your ship's flagged, and I don't argue with Barnaby.",
			"No seeds for embargoed crews. Plants pick up on that sort of thing.",
			"Come back when your ledger's greener. Everything here is about being greener.",
		),
		TRADER_LINE_IDLE = list(
			"Every plant in this room has a name. The turrets don't, that felt wrong.",
			"Real dirt. Shipped in eighty crates, one apology to customs at a time.",
			"The bees know the way to the pond and back. Nobody taught them. I don't ask.",
			"Grafts! Bring me grafts. The weirder the plant, the better the tea.",
			"Ash flora seeds off the burning worlds — I pay proper credits. They grow ANYWHERE. It's terrifying. I love them.",
			"Pike keeps saying fish fertilizer would double my yield. Pike is banned from the conservatory.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in! New seed stock, and only slightly crushed this time.",
			"Fresh deliveries. The rotating rack's been replanted, come look.",
			"Restock day. The bees are excited. That's genuinely how I can tell.",
		),
	)

/datum/shop_sku/potting
	stock_min = 3
	stock_max = 6

// ===== SEED RACK =====

/datum/shop_sku/potting/tomato
	category = "Seed Rack"
	item_path = /obj/item/seeds/tomato
	price_credits = 40

/datum/shop_sku/potting/potato
	category = "Seed Rack"
	item_path = /obj/item/seeds/potato
	price_credits = 30

/datum/shop_sku/potting/carrot
	category = "Seed Rack"
	item_path = /obj/item/seeds/carrot
	price_credits = 30

/datum/shop_sku/potting/wheat
	category = "Seed Rack"
	item_path = /obj/item/seeds/wheat
	price_credits = 30

/datum/shop_sku/potting/chili
	category = "Seed Rack"
	item_path = /obj/item/seeds/chili
	price_credits = 40

/datum/shop_sku/potting/watermelon
	category = "Seed Rack"
	item_path = /obj/item/seeds/watermelon
	price_credits = 50

/datum/shop_sku/potting/apple
	category = "Seed Rack"
	item_path = /obj/item/seeds/apple
	price_credits = 50

/datum/shop_sku/potting/sugarcane
	category = "Seed Rack"
	item_path = /obj/item/seeds/sugarcane
	price_credits = 40

/datum/shop_sku/potting/berry
	category = "Seed Rack"
	item_path = /obj/item/seeds/berry
	price_credits = 40

// ===== GROWER'S SUPPLY =====

/datum/shop_sku/potting/plant_analyzer
	category = "Grower's Supply"
	item_path = /obj/item/plant_analyzer
	price_credits = 150
	stock_min = 2
	stock_max = 3

/datum/shop_sku/potting/watering_can
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/cup/watering_can
	price_credits = 60

/datum/shop_sku/potting/cultivator
	category = "Grower's Supply"
	item_path = /obj/item/cultivator
	price_credits = 50

/datum/shop_sku/potting/secateurs
	category = "Grower's Supply"
	item_path = /obj/item/secateurs
	price_credits = 80
	stock_min = 2
	stock_max = 3

/datum/shop_sku/potting/plantbgone
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/spray/plantbgone
	price_credits = 80

/datum/shop_sku/potting/leather_gloves
	category = "Grower's Supply"
	item_path = /obj/item/clothing/gloves/botanic_leather
	price_credits = 100
	stock_min = 2
	stock_max = 3

/datum/shop_sku/potting/plant_bag
	category = "Grower's Supply"
	item_path = /obj/item/storage/bag/plants
	price_credits = 100

/datum/shop_sku/potting/ez_nutrient
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/cup/bottle/nutrient/ez
	price_credits = 40
	stock_min = 4
	stock_max = 8

/datum/shop_sku/potting/overalls
	category = "Grower's Supply"
	item_path = /obj/item/clothing/suit/apron/overalls
	price_credits = 80
	stock_min = 1
	stock_max = 3

// ===== THE APIARY =====

/datum/shop_sku/potting/honeycomb
	category = "The Apiary"
	item_path = /obj/item/food/honeycomb
	price_credits = 80
	stock_min = 3
	stock_max = 6

/datum/shop_sku/potting/honey_frame
	category = "The Apiary"
	item_path = /obj/item/honey_frame
	price_credits = 60
	stock_min = 2
	stock_max = 4

/datum/shop_sku/potting/queen_bee
	category = "The Apiary"
	name = "packaged queen bee"
	desc = "A queen and her patience, boxed for transit. Fern includes handwritten care instructions whether you want them or not."
	item_path = /obj/item/queen_bee
	price_credits = 400
	stock_min = 1
	stock_max = 2

// ===== ROTATING RACK =====

/datum/shop_sku/potting/rotating
	category = "Seed Rack"
	stock_min = 1
	stock_max = 3

/datum/shop_sku/potting/rotating/glowshroom
	item_path = /obj/item/seeds/glowshroom
	price_credits = 120

/datum/shop_sku/potting/rotating/towercap
	item_path = /obj/item/seeds/tower
	price_credits = 100

/datum/shop_sku/potting/rotating/sunflower
	item_path = /obj/item/seeds/sunflower
	price_credits = 60

/datum/shop_sku/potting/rotating/ambrosia
	item_path = /obj/item/seeds/ambrosia
	price_credits = 150

/datum/shop_sku/potting/rotating/banana
	item_path = /obj/item/seeds/banana
	price_credits = 80

/datum/shop_sku/potting/rotating/cherry
	item_path = /obj/item/seeds/cherry
	price_credits = 100

// ===== RARE SHOWCASE =====

/datum/shop_sku/potting/rare/gaia
	category = "Seed Rack"
	name = "ambrosia gaia seeds"
	desc = "The good ambrosia. Fern keeps these behind the counter, next to a photo of the plant like it's family."
	item_path = /obj/item/seeds/ambrosia/gaia
	price_vouchers = 1
	price_credits = 800

/datum/shop_sku/potting/rare/mystery_seeds
	category = "Seed Rack"
	name = "unlabeled seed packet"
	desc = "Fell off a convoy manifest with the label scorched away. Fern has theories. Fern always has theories."
	item_path = /obj/item/seeds/random
	price_credits = 300

// ===== FERN'S CUTTINGS LEDGER (buybacks) =====

/datum/shop_buyback/potting/graft
	name = "plant graft (any)"
	desc = "A snipped cutting carrying a trait worth keeping. Fern trades credits for genetics and considers it a bargain."
	category = "Cuttings & Curiosities"
	item_path = /obj/item/graft
	pay_credits = 200
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/potting/ash_flora
	name = "ash flora seeds (any)"
	desc = "Seed stock off the burning worlds — cactus, mushroom, moss, whatever survives down there. It all grows up here, which keeps Fern awake at night in a good way."
	category = "Cuttings & Curiosities"
	item_path = /obj/item/seeds/lavaland
	pay_credits = 150
	demand_min = 2
	demand_max = 5

/datum/shop_buyback/potting/produce
	name = "home-grown produce (any)"
	desc = "Anything off a hydroponics tray, paid at farm-stand rates. It goes in the waystation stew, the waystation preserves, and occasionally the waystation compost."
	category = "The Farm Stand"
	item_path = /obj/item/food/grown
	pay_credits = 15
	demand_min = 8
	demand_max = 15

// =========================================================================
// PIKE'S BAIT & TACKLE — Pike, resident angler
// =========================================================================

/// Pike, who dug a pond into a space station and dares you to say something
/datum/outpost_shop/vendor/bait_shop
	outpost_name = "\improper Pike's Bait & Tackle"
	outpost_desc = "Halcyon's tackle bench, beside the pond."
	trader_name = "Pike"
	trader_outfit = /datum/outfit/job/assistant/gimmick/fisher
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.95
	categories = list(
		"Rods & Reels",
		"Bait & Tackle",
		"Aquarist Corner",
	)
	sku_types = list(
		// Rods & Reels — Barnaby sells the starter rod; Pike sells the ones that catch
		/datum/shop_sku/bait/telescopic_rod,
		// Bait & Tackle
		/datum/shop_sku/bait/hook_box,
		/datum/shop_sku/bait/line_box,
		/datum/shop_sku/bait/tackle_box,
		/datum/shop_sku/bait/worms,
		/datum/shop_sku/bait/premium_worms,
		/datum/shop_sku/bait/fishing_hat,
		// Aquarist Corner
		/datum/shop_sku/bait/aquarium_kit,
		/datum/shop_sku/bait/fish_feed,
		/datum/shop_sku/bait/fish_case,
	)
	rotating_pool = list(
		/datum/shop_sku/bait/rotating/rescue_rod,
		/datum/shop_sku/bait/rotating/super_baits,
		/datum/shop_sku/bait/rotating/carp_plushie,
		/datum/shop_sku/bait/rotating/stocked_aquarium,
	)
	rare_pool = list(
		/datum/shop_sku/bait/rare/tech_rod,
	)
	buyback_types = list(
		/datum/shop_buyback/bait/pike,
		/datum/shop_buyback/bait/donkfish,
		/datum/shop_buyback/bait/goldfish,
	)
	trader_lines = list(
		TRADER_LINE_SALE = list(
			"Good gear. The rest is patience, and I can't sell you that.",
			"That'll do. Keep your line wet and your mouth shut, fish hear everything.",
			"Sold. Pond's right there if you want to embarrass yourself immediately.",
			"There you are. Mind the bees on your backswing.",
		),
		TRADER_LINE_REFUSAL = list(
			"Barnaby flagged your ship. I don't make the rules, I just fish next to them.",
			"No tackle for embargoed crews. Take it up with the till.",
			"Come back when you're square with the house. The fish will wait. Fish are good at that.",
		),
		TRADER_LINE_IDLE = list(
			"Nobody approved the pond. That was forty years ago. It has a name now.",
			"Caught a pike in there once. That's why it's me telling you and not him.",
			"The fish come in with the water recyclers. Nobody believes me. The fish don't care.",
			"Bring me a donkfish and I'll pay stupid money. I have a THEORY.",
			"Barnaby buys anything with fins for the chowder. I buy the ones worth mounting.",
			"Fern's banned me from the conservatory. All I said was her koi pond had potential.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. Fresh worms. Premium ones this time, don't waste them.",
			"New tackle on the bench. The good hooks go first, move quick.",
			"Restocked. Even got aquarium glass in. Somebody always breaks one. Somebody being me.",
		),
	)

/datum/shop_sku/bait
	stock_min = 2
	stock_max = 4

// ===== RODS & REELS =====

/datum/shop_sku/bait/telescopic_rod
	category = "Rods & Reels"
	item_path = /obj/item/fishing_rod/telescopic
	price_credits = 400
	stock_min = 1
	stock_max = 2

// ===== BAIT & TACKLE =====

/datum/shop_sku/bait/hook_box
	category = "Bait & Tackle"
	item_path = /obj/item/storage/box/fishing_hooks
	price_credits = 150
	stock_min = 1
	stock_max = 3

/datum/shop_sku/bait/line_box
	category = "Bait & Tackle"
	item_path = /obj/item/storage/box/fishing_lines
	price_credits = 150
	stock_min = 1
	stock_max = 3

/datum/shop_sku/bait/tackle_box
	category = "Bait & Tackle"
	item_path = /obj/item/storage/toolbox/fishing
	price_credits = 250
	stock_min = 1
	stock_max = 2

/datum/shop_sku/bait/worms
	category = "Bait & Tackle"
	item_path = /obj/item/bait_can/worm
	price_credits = 60
	stock_min = 3
	stock_max = 6

/datum/shop_sku/bait/premium_worms
	category = "Bait & Tackle"
	item_path = /obj/item/bait_can/worm/premium
	price_credits = 150
	stock_min = 1
	stock_max = 3

/datum/shop_sku/bait/fishing_hat
	category = "Bait & Tackle"
	item_path = /obj/item/clothing/head/soft/fishing_hat
	price_credits = 75

// ===== AQUARIST CORNER =====

/datum/shop_sku/bait/aquarium_kit
	category = "Aquarist Corner"
	item_path = /obj/item/aquarium_kit
	price_credits = 200
	stock_min = 1
	stock_max = 3

/datum/shop_sku/bait/fish_feed
	category = "Aquarist Corner"
	item_path = /obj/item/reagent_containers/cup/fish_feed
	price_credits = 40
	stock_min = 3
	stock_max = 6

/datum/shop_sku/bait/fish_case
	category = "Aquarist Corner"
	item_path = /obj/item/storage/fish_case
	price_credits = 50
	stock_min = 3
	stock_max = 6

// ===== ROTATING BENCH =====

/datum/shop_sku/bait/rotating
	stock_min = 1
	stock_max = 2

/datum/shop_sku/bait/rotating/rescue_rod
	category = "Rods & Reels"
	name = "rescue rod"
	desc = "A rod rigged with a rescue hook — casts at people, not fish. Pike sells one every time somebody falls in the pond, which is more often than the pond deserves."
	item_path = /obj/item/fishing_rod/rescue
	price_credits = 350

/datum/shop_sku/bait/rotating/super_baits
	category = "Bait & Tackle"
	item_path = /obj/item/bait_can/super_baits
	price_credits = 250

/datum/shop_sku/bait/rotating/carp_plushie
	category = "Aquarist Corner"
	item_path = /obj/item/toy/plush/carpplushie
	price_credits = 150

/datum/shop_sku/bait/rotating/stocked_aquarium
	category = "Aquarist Corner"
	name = "stocked aquarium"
	desc = "A full aquarium, fish included, sold as-is off Pike's display shelf. Transporting it is your problem and the fish's."
	item_path = /obj/structure/aquarium/prefilled
	price_credits = 600

// ===== RARE SHOWCASE =====

/datum/shop_sku/bait/rare/tech_rod
	category = "Rods & Reels"
	desc = "A self-reeling smart rod. Pike calls it cheating and stocks it anyway, because cheating sells."
	item_path = /obj/item/fishing_rod/tech
	price_vouchers = 1
	price_credits = 600

// ===== PIKE'S TROPHY LEDGER (buybacks) =====
// The weird stuff only. Barnaby handles the by-the-fin chowder trade.

/datum/shop_buyback/bait/pike
	name = "pike (the fish)"
	desc = "He wants one for the wall. He is aware of the name situation. Do not bring up the name situation."
	category = "Trophy Wall"
	item_path = /obj/item/fish/pike
	pay_credits = 300
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/bait/donkfish
	name = "donk-fish"
	desc = "Pike has a THEORY about these and the theory requires specimens. He will not elaborate until he has more specimens."
	category = "Trophy Wall"
	item_path = /obj/item/fish/donkfish
	pay_credits = 400
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/bait/goldfish
	name = "goldfish"
	desc = "Pity rates. Everyone's first catch deserves a buyer, and Pike remembers his."
	category = "Trophy Wall"
	item_path = /obj/item/fish/goldfish
	pay_credits = 25
	demand_min = 3
	demand_max = 5
