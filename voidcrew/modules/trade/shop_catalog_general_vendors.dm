/**
 * # Waystation Halcyon: vendor stalls
 *
 * Halcyon's side businesses: Fern in the conservatory running the Potting
 * Shed, and Pike selling tackle off a bench beside the pond he dug into the
 * deck plating. Each is a full /datum/outpost_shop (own stock, own buyback
 * ledger, own voice) fronted by its own trader NPC, same wiring as the
 * Undertow's stalls (see outpost.dm get_shop(), trader_npc.dm for the mobs).
 *
 * Balance notes:
 * - No overlap with Barnaby's counter: he keeps the groceries, Fern owns seeds
 *   and grower's supply, Pike owns tackle and the rods. Pike's stall stocks
 *   nothing a stock ship autolathe prints for free, that ruled out the
 *   aquarium kit and fish case.
 * - Fern's hand tools ARE autolathe designs, and they're priced like it: pocket
 *   change, sold for the crew that wants a garden running before they've built
 *   a lathe or walked back to one. Her tray board is the real sale, it sits
 *   behind the hydroponics techweb node, so a ship with no R&D bay has no other
 *   way to add a tray.
 * - Fern's produce and graft buybacks pay pocket change on purpose: it's the
 *   "sell your harvest at the waystation" fantasy, not an economy. Her graft
 *   ledger refuses plain repeated-harvest cuttings so a tray of wheat can't be
 *   farmed into credits; see the matches() override below.
 * - Pike never buys what his own pond stocks at meaningful prices; the
 *   trophy ledger wants the weird stuff.
 */

// =========================================================================
// THE POTTING SHED: Fern, conservatory keeper
// =========================================================================

/**
 * Fern: dressed for soil, not for a shop. Leather waders and leather gloves
 * are what you wear to work a bed by hand, the straw hat is a joke about
 * sunlight nobody on a station gets, and the watering can never gets put down.
 */
/datum/outfit/potting_shed_fern
	name = "Conservatory keeper"
	uniform = /obj/item/clothing/under/rank/civilian/hydroponics
	suit = /obj/item/clothing/suit/apron/waders
	gloves = /obj/item/clothing/gloves/botanic_leather
	head = /obj/item/clothing/head/costume/rice_hat
	shoes = /obj/item/clothing/shoes/workboots
	r_hand = /obj/item/reagent_containers/cup/watering_can/wood

/// Fern, who grows real food in real dirt on a metal station and will tell you about it
/datum/outpost_shop/vendor/potting_shed
	outpost_name = "\improper The Potting Shed"
	outpost_desc = "Halcyon's conservatory and seed counter."
	trader_name = "Fern"
	trader_outfit = /datum/outfit/potting_shed_fern
	trader_gender = FEMALE
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 1.22
	categories = list(
		"Seed Rack",
		"Grower's Supply",
		"The Apiary",
		"Job Packs",
	)
	sku_types = list(
		// Seed Rack: honest staples for a ship galley
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
		/datum/shop_sku/potting/plantbgone,
		/datum/shop_sku/potting/pestspray,
		/datum/shop_sku/potting/leather_gloves,
		/datum/shop_sku/potting/plant_bag,
		/datum/shop_sku/potting/ez_nutrient,
		/datum/shop_sku/potting/robust_harvest,
		/datum/shop_sku/potting/left4zed,
		/datum/shop_sku/potting/overalls,
		// Grower's Supply: hand tools
		/datum/shop_sku/potting/cultivator,
		/datum/shop_sku/potting/spade,
		/datum/shop_sku/potting/hatchet,
		/datum/shop_sku/potting/secateurs,
		/datum/shop_sku/potting/watering_can,
		/datum/shop_sku/potting/plant_analyzer,
		// Grower's Supply: the tray itself
		/datum/shop_sku/potting/tray_board,
		// The Apiary
		/datum/shop_sku/potting/honeycomb,
		/datum/shop_sku/potting/honey_frame,
		/datum/shop_sku/potting/queen_bee,
		// Job Packs: the crate lives in shop_catalog_job_packs.dm
		/datum/shop_sku/potting/job_pack_botany,
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
			"Come back when your ledger's a bit greener.",
		),
		TRADER_LINE_IDLE = list(
			"Every plant in this room has a name. The turrets don't, that felt wrong.",
			"Real dirt. Shipped in eighty crates, one apology to customs at a time.",
			"The bees know the way to the pond and back. Nobody taught them. I don't ask.",
			"Bring me grafts with something actually in them. A cutting off a wheat stalk is just a cutting.",
			"Tray boards are on the shelf behind me. Two bins, a servo, a sheet of glass, and you've got a garden.",
			"Take the tools while you're here. They're cheap, and I'd rather you weren't pulling weeds with your hands.",
			"Ash flora seeds off the burning worlds. I pay proper credits. They grow ANYWHERE. It's terrifying. I love them.",
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

/datum/shop_sku/potting/plantbgone
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/spray/plantbgone
	price_credits = 80

/datum/shop_sku/potting/pestspray
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/spray/pestspray
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

/datum/shop_sku/potting/robust_harvest
	name = "Robust Harvest bottle"
	desc = "Nutrient that pushes yield up and holds the plant's genes still. Fern's standard advice for anyone growing food rather than experiments."
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/cup/bottle/nutrient/rh
	price_credits = 90
	stock_min = 3
	stock_max = 6

/datum/shop_sku/potting/left4zed
	name = "Left 4 Zed bottle"
	desc = "Nutrient that makes a plant mutate far more often. Fern sells it with a warning she does not expect anyone to take."
	category = "Grower's Supply"
	item_path = /obj/item/reagent_containers/cup/bottle/nutrient/l4z
	price_credits = 90
	stock_min = 2
	stock_max = 4

/datum/shop_sku/potting/overalls
	category = "Grower's Supply"
	item_path = /obj/item/clothing/suit/apron/overalls
	price_credits = 80
	stock_min = 1
	stock_max = 3

// ----- Hand tools -----
// Every one of these is a service autolathe design, so a ship with a working
// lathe can print the set for scrap. Priced accordingly: this is the rack you
// grab on the way out rather than a supply line.

/datum/shop_sku/potting/cultivator
	category = "Grower's Supply"
	desc = "A hand rake for turning weeds out of a tray. Fern sells them by the bundle and still finds people pulling weeds by hand."
	item_path = /obj/item/cultivator
	price_credits = 30
	stock_min = 4
	stock_max = 8

/datum/shop_sku/potting/spade
	category = "Grower's Supply"
	desc = "For digging a plant out of a tray without killing it, and for repotting whatever you dug up."
	item_path = /obj/item/shovel/spade
	price_credits = 30
	stock_min = 4
	stock_max = 8

/datum/shop_sku/potting/hatchet
	category = "Grower's Supply"
	desc = "Chops down a tower cap, splits logs, and harvests anything too woody for bare hands. Fern would like it noted that it is a gardening tool."
	item_path = /obj/item/hatchet
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/potting/secateurs
	category = "Grower's Supply"
	desc = "Pruning shears sharp enough to take a clean graft off a stem. The cutting keeps whatever trait the parent was carrying."
	item_path = /obj/item/secateurs
	price_credits = 50
	stock_min = 3
	stock_max = 6

/datum/shop_sku/potting/watering_can
	category = "Grower's Supply"
	desc = "Holds enough water for a row of trays. Fill it at any sink, or at Pike's pond if you want to hear his opinion about it."
	item_path = /obj/item/reagent_containers/cup/watering_can
	price_credits = 40
	stock_min = 3
	stock_max = 6

/datum/shop_sku/potting/plant_analyzer
	category = "Grower's Supply"
	desc = "Reads a plant's stats and traits, and a tray's water, nutrients and pest level. Growing without one works, but you're guessing."
	item_path = /obj/item/plant_analyzer
	price_credits = 60
	stock_min = 3
	stock_max = 6

// ----- The tray itself -----
// Unlike the hand tools this one is genuinely gated: the design sits behind the
// hydroponics techweb node, so it's the only tray a ship without an R&D bay can
// get hold of. Priced so two boards plus the tools still cost more loose than
// the botany starter pack in shop_catalog_job_packs.dm.

/datum/shop_sku/potting/tray_board
	category = "Grower's Supply"
	name = "hydroponics tray board"
	desc = "The machine board for a hydroponics tray. Two matter bins, a servo and a sheet of glass and you have a garden, wherever you decided to put it."
	item_path = /obj/item/circuitboard/machine/hydroponics
	price_credits = 350
	stock_min = 2
	stock_max = 4

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
	desc = "A live queen and a starter retinue, boxed for transit. Fern includes handwritten care instructions whether you want them or not."
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

// Fern buys genetics, not clippings. Grafts taken off a plant with no
// graft_gene of its own come out carrying the default repeated-harvest trait,
// which she already has on everything and will not pay for, that closes the
// "buy a cheap seed, snip it forever" loop without touching the seed rack.
// Priced and demanded low on purpose: secateurs print free on a stock ship
// autolathe, so the supply side of this ledger can't be gated, only the
// payout.
/datum/shop_buyback/potting/graft
	name = "plant graft (with a trait)"
	desc = "A snipped cutting carrying a real trait. Fern pays for genetics she doesn't already have, so a cutting off a wheat stalk is worth nothing to her."
	category = "Cuttings & Curiosities"
	item_path = /obj/item/graft
	pay_credits = 150
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/potting/graft/matches(obj/item/offered)
	if(!..())
		return FALSE
	var/obj/item/graft/snip = offered
	return !istype(snip.stored_trait, /datum/plant_gene/trait/repeated_harvest)

/datum/shop_buyback/potting/ash_flora
	name = "ash flora seeds (any)"
	desc = "Seed stock off the burning worlds: cactus, mushroom, moss, whatever survives down there. All of it grows just fine up here, which Fern finds thrilling and slightly alarming."
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
	demand_min = 5
	demand_max = 10

// =========================================================================
// PIKE'S BAIT & TACKLE: Pike, resident angler
// =========================================================================

/**
 * Pike: overalls, rubber boots and a puffer vest. A man who expects to be
 * standing in water at some point today, indoors or not. The hat is the
 * genuine article and he will tell you so; the rod never leaves his hand.
 * Deliberately not in Fern's waders, since they share a corridor.
 */
/datum/outfit/bait_shop_pike
	name = "Resident angler"
	uniform = /obj/item/clothing/under/misc/overalls
	suit = /obj/item/clothing/suit/jacket/puffer/vest
	gloves = /obj/item/clothing/gloves/fishing
	head = /obj/item/clothing/head/soft/fishing_hat
	shoes = /obj/item/clothing/shoes/galoshes
	r_hand = /obj/item/fishing_rod

/// Pike, who dug a pond into a space station and dares you to say something
/datum/outpost_shop/vendor/bait_shop
	outpost_name = "\improper Pike's Bait & Tackle"
	outpost_desc = "Halcyon's tackle bench, beside the pond."
	trader_name = "Pike"
	trader_outfit = /datum/outfit/bait_shop_pike
	trader_gender = MALE
	trader_voice_pack = "goon.speak_3"
	trader_voice_pitch = 0.95
	categories = list(
		"Rods & Reels",
		"Bait & Tackle",
		"Aquarist Corner",
	)
	sku_types = list(
		// Rods & Reels: the basic rod prints on any ship lathe, so Pike only
		// stocks the ones worth carrying out to a planet
		/datum/shop_sku/bait/telescopic_rod,
		// Bait & Tackle
		/datum/shop_sku/bait/hook_box,
		/datum/shop_sku/bait/line_box,
		/datum/shop_sku/bait/lure_set,
		/datum/shop_sku/bait/tackle_box,
		/datum/shop_sku/bait/worms,
		/datum/shop_sku/bait/premium_worms,
		/datum/shop_sku/bait/fishing_hat,
		// Aquarist Corner
		/datum/shop_sku/bait/fish_feed,
		/datum/shop_sku/bait/fishy_reagent,
		/datum/shop_sku/bait/revival_kit,
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
			"Caught a pike in there once. Big one. That's how I got the name, more or less.",
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

// The one purchase that makes fishing for a *particular* fish possible. Lures
// are unconsumable omni-bait, and each one only interests a specific sort of
// fish, so the set is what turns the whole thing from luck into a choice.
// Priced between the cargo goody pack (400) and the box's own shelf price
// (450), buying it here means carrying it out today instead of waiting on a
// supply run.
/datum/shop_sku/bait/lure_set
	category = "Bait & Tackle"
	item_path = /obj/item/storage/box/fishing_lures
	desc = "One of every artificial lure, instruction sheet still in the lid. Nothing eats them, so a set lasts, but each one only interests a particular sort of fish and every one of them has to be spun while you wait."
	price_credits = 425
	stock_min = 1
	stock_max = 2

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

/datum/shop_sku/bait/fish_feed
	category = "Aquarist Corner"
	item_path = /obj/item/reagent_containers/cup/fish_feed
	price_credits = 40
	stock_min = 3
	stock_max = 6

/datum/shop_sku/bait/fishy_reagent
	name = "bottle of fishy reagent"
	desc = "Splash two to ten units on a dead fish and it comes back. Pike keeps a crate of it behind the bench and does not explain where it comes from."
	category = "Aquarist Corner"
	item_path = /obj/item/reagent_containers/cup/bottle/fishy_reagent
	price_credits = 90
	stock_min = 3
	stock_max = 6

/datum/shop_sku/bait/revival_kit
	name = "fish revival kit"
	desc = "A lazarus injector, a bottle of the fishy stuff and two transport cases. Everything you need to bring a rare catch home breathing."
	category = "Aquarist Corner"
	item_path = /obj/item/storage/box/fish_revival_kit
	price_credits = 350
	stock_min = 1
	stock_max = 2

// ===== ROTATING BENCH =====

/datum/shop_sku/bait/rotating
	stock_min = 1
	stock_max = 2

/datum/shop_sku/bait/rotating/rescue_rod
	category = "Rods & Reels"
	name = "rescue rod"
	desc = "A rod rigged with a rescue hook. It casts at people, not fish. Pike sells one every time somebody falls in the pond, which is more often than you'd think."
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
