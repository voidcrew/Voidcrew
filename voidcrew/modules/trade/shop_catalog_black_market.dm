/**
 * # Undertow Exchange — the red-zone black market
 *
 * Syndicate hardware, sealed mystery cargo and things with the serial numbers
 * filed off. The top shelf only moves for vouchers — the currency you can't
 * farm in safety.
 * Shop machinery lives in shop.dm; this file is pure catalog.
 */
/datum/outpost_shop/black_market
	outpost_name = "\improper Undertow Exchange"
	outpost_desc = "A heavily armored den of fences and quartermasters who don't ask questions. Somehow, nobody has ever managed to rob it."
	trader_name = "Vex"
	trader_holoimage_type = /datum/preset_holoimage/outpost_trader/black_market
	trader_voice_pack = "goon.speak_2"
	trader_voice_pitch = 0.92
	categories = list(
		"Weapons",
		"Explosives",
		"Infiltration",
		"Combat Medical",
		"Intel & Charts",
		"Blueprints",
		"Mystery Cargo",
		"Sundries",
	)
	sku_types = list(
		// Weapons
		/datum/shop_sku/black_market/pistol,
		/datum/shop_sku/black_market/pistol_mag,
		/datum/shop_sku/black_market/revolver,
		/datum/shop_sku/black_market/speedloader,
		/datum/shop_sku/black_market/suppressor,
		/datum/shop_sku/black_market/combat_knife,
		/datum/shop_sku/black_market/switchblade,
		// Explosives
		/datum/shop_sku/black_market/c4,
		/datum/shop_sku/black_market/emp_grenade,
		/datum/shop_sku/black_market/frag_grenade,
		/datum/shop_sku/black_market/smoke_bomb,
		// Infiltration
		/datum/shop_sku/black_market/emag,
		/datum/shop_sku/black_market/agent_id,
		/datum/shop_sku/black_market/thermals,
		/datum/shop_sku/black_market/noslips,
		/datum/shop_sku/black_market/syndie_key,
		/datum/shop_sku/black_market/sleepy_pen,
		/datum/shop_sku/black_market/chameleon_mask,
		// Combat Medical
		/datum/shop_sku/black_market/tactical_medkit,
		/datum/shop_sku/black_market/stimulants,
		// Intel & Charts
		/datum/shop_sku/black_market/star_chart,
		/datum/shop_sku/rumor/black_market,
		// Blueprints
		/datum/shop_sku/black_market/saw_blueprint,
		/datum/shop_sku/black_market/sniper_blueprint,
		/datum/shop_sku/black_market/bulldog_blueprint,
		// Mystery Cargo
		/datum/shop_sku/black_market/mystery_cache,
		/datum/shop_sku/black_market/mystery_cache_rare,
		// Sundries
		/datum/shop_sku/black_market/soap,
		/datum/shop_sku/black_market/donk_pockets,
		/datum/shop_sku/black_market/syndie_cigarettes,
	)
	rotating_pool = list(
		/datum/shop_sku/black_market/rotating/mateba,
		/datum/shop_sku/black_market/rotating/ebow,
		/datum/shop_sku/black_market/rotating/minibomb,
		/datum/shop_sku/black_market/rotating/dart_pistol,
	)
	rare_pool = list(
		/datum/shop_sku/black_market/rare/energy_sword,
		/datum/shop_sku/black_market/rare/energy_shield,
	)
	// The consignment window: Vex fences planet exotics and ruin loot at the
	// best rates in the system. Voucher payouts are strictly planet/danger-gated.
	buyback_types = list(
		/datum/shop_buyback/black_market/telecrystal,
		/datum/shop_buyback/black_market/legion_core,
		/datum/shop_buyback/black_market/bluespace_crystals,
		/datum/shop_buyback/black_market/syndicate_documents,
		/datum/shop_buyback/black_market/hot_iron,
	)
	// Vex's supply requests want the rare stuff — the free item makes it worth it
	mission_requests = list(
		list("type" = /obj/item/stack/ore/uranium, "name" = "uranium ore", "amount" = 8, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/diamond, "name" = "diamonds", "amount" = 4, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/ore/bluespace_crystal, "name" = "bluespace crystals", "amount" = 2, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/stack/sheet/mineral/plasma, "name" = "plasma sheets", "amount" = 20, "difficulty" = MISSION_DIFFICULTY_MEDIUM),
		list("type" = /obj/item/stack/telecrystal_raw, "name" = "raw telecrystal", "amount" = 10, "difficulty" = MISSION_DIFFICULTY_HARD),
		list("type" = /obj/item/organ/monster_core/regenerative_core/legion, "name" = "legion core", "amount" = 1, "difficulty" = MISSION_DIFFICULTY_HARD),
	)
	// The back shelf: hard contracts only, never sold
	exclusive_rewards = list(
		/obj/item/storage/box/syndie_kit/chameleon,
		/obj/item/pen/edagger,
		/obj/item/clothing/suit/hooded/explorer/syndicate,
	)
	trader_lines = list(
		TRADER_LINE_GREETING = list(
			"Welcome to the Undertow. Touch nothing you can't pay for.",
			"Fresh faces. Vouchers up front, questions never.",
			"You found us. That's the hard part done. Now spend.",
			"Come in, come in. Leave the airlock drama outside — that's a dock problem.",
			"Ah, customers. Or corpses with good timing. The red zone blurs the line.",
		),
		TRADER_LINE_SALE = list(
			"Pleasure doing business. Forget you saw me.",
			"Sold. It was never here, and neither were you.",
			"A fine choice. No refunds, no receipts, no memories.",
			"Wrap it yourself. Discretion is complimentary.",
			"That one has a history. Congratulations — now it has a future.",
		),
		TRADER_LINE_REFUSAL = list(
			"Your money's no good here. Literally — check your embargo notice.",
			"We don't serve your kind. 'Your kind' meaning people who shoot at my stock.",
			"Come back when your ship's ledger is clean.",
			"The Undertow forgives everything except property damage. Wait it out.",
		),
		TRADER_LINE_WARNING = list(
			"Easy, killer. The turrets have a temper and a long memory.",
			"That's one. Keep swinging and you'll meet the expensive part of this station.",
			"Read the plaque. Violence is bad for business — mostly yours.",
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
			"Raw telecrystal. The burning worlds are full of it, and the fools who mine it. Bring me both. Just kidding. Just the crystal.",
			"The mystery caches? Sealed when they got here. I make a point of not knowing.",
			"Somebody asked what the imprinter does with the schematics. Confetti. Expensive confetti.",
			"Legion cores keep better than legionnaires. Cooler's under the counter.",
		),
		TRADER_LINE_RESTOCK = list(
			"Convoy's in. Don't ask which flag it flew — new stock on the shelves.",
			"Fresh inventory, straight off a manifest that never existed.",
			"The warehouse door opens once a cycle. It just did. Shop.",
		),
	)

/datum/shop_sku/black_market
	stock_min = 1
	stock_max = 3

// ===== WEAPONS =====

/datum/shop_sku/black_market/pistol
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/automatic/pistol
	price_vouchers = 2
	price_credits = 500
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/pistol_mag
	category = "Weapons"
	item_path = /obj/item/ammo_box/magazine/m9mm
	price_credits = 300
	stock_min = 4
	stock_max = 8

/datum/shop_sku/black_market/revolver
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/revolver
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/speedloader
	category = "Weapons"
	item_path = /obj/item/ammo_box/a357
	price_credits = 600
	stock_min = 2
	stock_max = 5

/datum/shop_sku/black_market/suppressor
	category = "Weapons"
	item_path = /obj/item/suppressor
	price_credits = 400
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/combat_knife
	category = "Weapons"
	item_path = /obj/item/knife/combat
	price_credits = 350
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/switchblade
	category = "Weapons"
	item_path = /obj/item/switchblade
	price_credits = 300
	stock_min = 2
	stock_max = 4

// ===== EXPLOSIVES =====

/datum/shop_sku/black_market/c4
	category = "Explosives"
	item_path = /obj/item/grenade/c4
	price_vouchers = 1
	price_credits = 250
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/emp_grenade
	category = "Explosives"
	item_path = /obj/item/grenade/empgrenade
	price_vouchers = 1
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/frag_grenade
	category = "Explosives"
	item_path = /obj/item/grenade/frag
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/smoke_bomb
	category = "Explosives"
	item_path = /obj/item/grenade/smokebomb
	price_credits = 300
	stock_min = 2
	stock_max = 4

// ===== INFILTRATION =====

/datum/shop_sku/black_market/emag
	category = "Infiltration"
	name = "cryptographic sequencer"
	item_path = /obj/item/card/emag
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/agent_id
	category = "Infiltration"
	item_path = /obj/item/card/id/advanced/chameleon
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/thermals
	category = "Infiltration"
	item_path = /obj/item/clothing/glasses/thermal/syndi
	price_vouchers = 3
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/noslips
	category = "Infiltration"
	item_path = /obj/item/clothing/shoes/chameleon/noslip
	price_vouchers = 2
	price_credits = 400
	stock_min = 1
	stock_max = 2

/datum/shop_sku/black_market/syndie_key
	category = "Infiltration"
	item_path = /obj/item/encryptionkey/syndicate
	price_vouchers = 1
	price_credits = 300
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/sleepy_pen
	category = "Infiltration"
	item_path = /obj/item/pen/sleepy
	price_vouchers = 3
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/chameleon_mask
	category = "Infiltration"
	name = "chameleon mask"
	desc = "A shape-shifting mask with a built-in voice modulator. Be anyone, sound like them too."
	item_path = /obj/item/clothing/mask/chameleon
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

// ===== COMBAT MEDICAL =====

/datum/shop_sku/black_market/tactical_medkit
	category = "Combat Medical"
	item_path = /obj/item/storage/medkit/tactical
	price_vouchers = 1
	price_credits = 500
	stock_min = 1
	stock_max = 3

/datum/shop_sku/black_market/stimulants
	category = "Combat Medical"
	item_path = /obj/item/reagent_containers/hypospray/medipen/stimulants
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

// ===== INTEL & CHARTS =====

// Charts the lawless deep — the discovery certainty channel, voucher-priced
/datum/shop_sku/black_market/star_chart
	category = "Intel & Charts"
	item_path = /obj/item/disk/star_chart/red
	price_vouchers = 2
	stock_min = 1
	stock_max = 2

// Vex's tips run expensive and deep — red-band signals only
/datum/shop_sku/rumor/black_market
	name = "whisper from the deep lanes"
	desc = "Vex hears things. Terrible things, profitable things. One uncharted red-band signal, marked on your helm. What's parked there is your problem."
	price_credits = 500

// ===== BLUEPRINTS =====
// The only trader route to these guns; build them via their schematics.
// Reusable, so priced at the top of the ladder.

/datum/shop_sku/black_market/saw_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/l6_saw
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/sniper_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/sniper_rifle
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

/datum/shop_sku/black_market/bulldog_blueprint
	category = "Blueprints"
	item_path = /obj/item/blueprint/gun/bulldog
	price_vouchers = 5
	stock_min = 1
	stock_max = 1

// ===== MYSTERY CARGO =====
// The gamble channel, sold over the counter: sealed caches rolling the zone
// loot tables. The crate pins its table to the spawn turf — bought at the
// Undertow, it rolls red-band loot.

/datum/shop_sku/black_market/mystery_cache
	category = "Mystery Cargo"
	name = "sealed cache"
	desc = "A locked syndicate supply cache, contents sight-unseen. Vex guarantees it's worth something. Vex guarantees nothing else."
	item_path = /obj/structure/closet/crate/zone_loot/syndicate
	price_vouchers = 2
	stock_min = 2
	stock_max = 3

/datum/shop_sku/black_market/mystery_cache_rare
	category = "Mystery Cargo"
	name = "reinforced cache"
	desc = "The good crate. The one from the back room. Even Vex looks curious when one moves."
	item_path = /obj/structure/closet/crate/zone_loot/syndicate/rare
	price_vouchers = 4
	stock_min = 1
	stock_max = 1

// ===== SUNDRIES =====

// The mandatory joke item; also the cheap "see how the shop works" SKU
/datum/shop_sku/black_market/soap
	category = "Sundries"
	item_path = /obj/item/soap/syndie
	price_credits = 150
	stock_min = 3
	stock_max = 6

/datum/shop_sku/black_market/donk_pockets
	category = "Sundries"
	item_path = /obj/item/storage/box/donkpockets
	price_credits = 200
	stock_min = 2
	stock_max = 4

/datum/shop_sku/black_market/syndie_cigarettes
	category = "Sundries"
	item_path = /obj/item/storage/fancy/cigarettes/cigpack_syndicate
	price_credits = 150
	stock_min = 2
	stock_max = 4

// ===== ROTATING SHELF =====

/datum/shop_sku/black_market/rotating/mateba
	category = "Weapons"
	item_path = /obj/item/gun/ballistic/revolver/mateba
	price_vouchers = 4

/datum/shop_sku/black_market/rotating/ebow
	category = "Weapons"
	name = "miniature energy crossbow"
	item_path = /obj/item/gun/energy/recharge/ebow
	price_vouchers = 6

/datum/shop_sku/black_market/rotating/minibomb
	category = "Explosives"
	item_path = /obj/item/grenade/syndieminibomb
	price_vouchers = 3

/datum/shop_sku/black_market/rotating/dart_pistol
	category = "Weapons"
	item_path = /obj/item/gun/syringe/syndicate
	price_vouchers = 2

// ===== RARE SHOWCASE =====

/datum/shop_sku/black_market/rare/energy_sword
	category = "Weapons"
	item_path = /obj/item/melee/energy/sword/saber
	price_vouchers = 4

/datum/shop_sku/black_market/rare/energy_shield
	category = "Weapons"
	item_path = /obj/item/shield/energy
	price_vouchers = 3

// ===== VEX'S CONSIGNMENT WINDOW (buybacks) =====
// Voucher payouts here must stay un-farmable: natural crystals only (the
// artificial subtype is lathe-printable), original syndicate docs only
// (photocopies are a different subtype and worthless).

// The flagship planetary good: raw telecrystal only comes out of hostile
// planet crust, so paying vouchers for it can't be farmed in safety.
/datum/shop_buyback/black_market/telecrystal
	name = "raw telecrystal"
	desc = "Vex doesn't say what the Undertow does with unrefined telecrystal, and you shouldn't ask. Veins hide in the rock of the burning and blasted worlds."
	category = "Planetary Exotics"
	item_path = /obj/item/stack/telecrystal_raw
	amount = 5
	pay_vouchers = 1
	demand_min = 4
	demand_max = 6

/datum/shop_buyback/black_market/legion_core
	name = "legion core"
	desc = "A still-warm regenerative core cut out of a legion. Vex keeps a cooler under the counter and a buyer list that's none of your business."
	category = "Planetary Exotics"
	item_path = /obj/item/organ/monster_core/regenerative_core/legion
	pay_vouchers = 1
	demand_min = 2
	demand_max = 4

/datum/shop_buyback/black_market/bluespace_crystals
	name = "natural bluespace crystals"
	desc = "Unrefined crystal straight out of dangerous rock. Vex can tell the lab-grown ones apart by smell, apparently."
	category = "Planetary Exotics"
	item_path = /obj/item/stack/ore/bluespace_crystal
	match_subtypes = FALSE
	amount = 3
	pay_vouchers = 1
	demand_min = 3
	demand_max = 5

/datum/shop_buyback/black_market/syndicate_documents
	name = "syndicate documents"
	desc = "Original classified paperwork. Photocopies are an insult and priced accordingly (zero)."
	category = "Intel"
	item_path = /obj/item/documents/syndicate
	pay_vouchers = 2
	demand_min = 1
	demand_max = 2

/datum/shop_buyback/black_market/hot_iron
	name = "firearm (any, no questions)"
	desc = "Vex buys guns with a past. Serial numbers optional. Preferably absent."
	category = "Fencing"
	item_path = /obj/item/gun
	pay_credits = 250
	demand_min = 4
	demand_max = 8
