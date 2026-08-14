// Faction-specific NPC pirate ship types
// Each faction has unique colors, crew types, and behaviors

// ==================== FACTION COLORS ====================

#define NPC_COLOR_SILVERSCALE "#C0C0C0"  // Silver
#define NPC_COLOR_SKELETON "#8B7355"      // Bone/brown
#define NPC_COLOR_GREY "#808080"          // Grey
#define NPC_COLOR_LUSTROUS "#9966FF"      // Purple/crystal
#define NPC_COLOR_INTERDYNE "#660066"     // Dark purple
#define NPC_COLOR_IRS "#FFD700"           // Gold
#define NPC_COLOR_MEDIEVAL "#8B0000"      // Dark red

// ==================== SILVERSCALE (Aristocratic Lizards) ====================

/obj/structure/overmap/ship/npc/pirate/silverscale
	name = "silverscale noble vessel"
	desc = "An aristocratic vessel operated by the Silverscale lizard nobility. They demand tribute."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_silverscale
	ship_color = NPC_COLOR_SILVERSCALE

	// Detection range
	territory_range = 3

	// Combat stats - aristocrats are methodical
	lock_time = 6 SECONDS          // Increased for balance
	laser_cooldown_time = 7 SECONDS // Increased for balance

	crew_min = 2
	crew_max = 4
	captain_type = /mob/living/basic/trooper/pirate/faction/silverscale/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
		/mob/living/basic/trooper/pirate/faction/silverscale/melee,
		/mob/living/basic/trooper/pirate/faction/silverscale/ranged,
	)

	// Boarding pods - aristocrats send their duelists
	boarding_pods_enabled = TRUE
	boarding_pods_min = 1
	boarding_pods_max = 2
	boarding_pod_cooldown_time = 35 SECONDS

	// Negotiation - aristocrats want more
	negotiation_dialog_type = /datum/pirate_faction_dialog/silverscale
	min_negotiation_demand = 800
	max_negotiation_demand = 15000
	// And carry more tribute to be relieved of
	hold_credits_min = 2200
	hold_credits_max = 4600
	pirate_faction = "silverscale"

	// Phased combat - aristocratic duelists
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/silverscale
	broke_lines = list(
		"Destitute. How disappointing. My retainers will see what else your hold contains.",
		"You have nothing to offer but cargo, then. And perhaps your lives.",
	)
	wave_taunts = list(
		list(
			"Your crew has spirit. A pity it will be broken.",
			"The nobles find your resistance... amusing.",
		),
		list(
			"You've slain my guards. Impressive. But futile.",
			"Prepare the honor guard. These ones have earned a proper death.",
		),
		list(
			"Very well. You shall face a Highlord in single combat.",
			"I shall deal with this rabble personally.",
		),
	)

// ==================== SKELETON (Flying Dutchman) ====================

/obj/structure/overmap/ship/npc/pirate/skeleton
	name = "ghostship vessel"
	desc = "A haunted vessel crewed by the undead. The Flying Dutchman sails again."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_dutchman
	ship_color = NPC_COLOR_SKELETON

	// Detection range
	territory_range = 3

	// Combat stats - undead crew are relentless
	lock_time = 4 SECONDS
	laser_cooldown_time = 4 SECONDS

	crew_min = 3
	crew_max = 6
	captain_type = /mob/living/basic/trooper/pirate/faction/skeleton/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
	)

	// Boarding pods - undead are relentless boarders
	boarding_pods_enabled = TRUE
	boarding_pods_min = 2
	boarding_pods_max = 4
	boarding_pod_cooldown_time = 25 SECONDS

	// Negotiation - undead will negotiate but are patient and ominous
	negotiation_dialog_type = /datum/pirate_faction_dialog/skeleton
	min_negotiation_demand = 400
	max_negotiation_demand = 8000
	hold_credits_min = 1100
	hold_credits_max = 2400
	pirate_faction = "skeleton"

	// Phased combat - undead hordes
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/skeleton
	broke_lines = list(
		"No coin on this wreck. No matter - we take flesh as readily as gold.",
		"Empty holds, empty pockets. We will settle for your crew.",
	)
	wave_taunts = list(
		list(
			"The dead do not tire. We will keep coming.",
			"Your souls will join our crew... eventually.",
		),
		list(
			"The Dutchman demands more souls...",
			"You cannot kill what is already dead. But we can kill you.",
		),
		list(
			"Davy Jones himself shall claim your vessel.",
			"The captain wishes to meet you... in person.",
		),
	)

// ==================== GREY TIDE (Rogue Assistants) ====================

/obj/structure/overmap/ship/npc/pirate/grey
	name = "toolbox salvage vessel"
	desc = "A ramshackle vessel operated by former assistants. GREYTIDE STATION WIDE."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_grey
	ship_color = NPC_COLOR_GREY

	// Grey tiders are opportunistic
	territory_range = 3

	// Weaker ship stats - they're assistants after all
	speed_limit = 0.4
	thrust_power = 0.25

	crew_min = 3
	crew_max = 5
	captain_type = /mob/living/basic/trooper/pirate/faction/grey/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/grey/ranged,
	)

	// Boarding pods - grey tiders love swarming
	boarding_pods_enabled = TRUE
	boarding_pods_min = 2
	boarding_pods_max = 5
	boarding_pod_cooldown_time = 20 SECONDS

	// Negotiation - assistants take what they can get
	negotiation_dialog_type = /datum/pirate_faction_dialog/grey
	min_negotiation_demand = 200
	max_negotiation_demand = 5000
	pirate_faction = "grey"
	hold_credits_min = 700
	hold_credits_max = 1600

	// Phased combat - greytide swarm
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/grey
	broke_lines = list(
		"lmao ur broke? w/e. boys go grab whatever isnt bolted down",
		"no creds? fine. WE TAKE THE TOOLBOXES",
	)
	wave_taunts = list(
		list(
			"GREYTIDE STATION WIDE! MORE TIDERS INCOMING!",
			"lol u killed some greys? theres way more where that came from",
		),
		list(
			"valid salad incoming. prepare ur anus",
			"THE TOOLBOXES HUNGER FOR MORE",
		),
		list(
			"yo the ROBUST ONE is coming. ur so fucked lmao",
			"gg no re. tidemaster inbound",
		),
	)

// ==================== LUSTROUS (Mutated Ethereals) ====================

/obj/structure/overmap/ship/npc/pirate/lustrous
	name = "geode crystal vessel"
	desc = "A strange crystalline vessel crewed by mutated ethereals obsessed with bluespace."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_geode
	ship_color = NPC_COLOR_LUSTROUS

	// Detection range
	territory_range = 3

	crew_min = 2
	crew_max = 4
	captain_type = /mob/living/basic/trooper/pirate/faction/lustrous/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/lustrous/melee,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
	)

	// Boarding pods - ethereals prefer ranged combat, fewer boarders
	boarding_pods_enabled = TRUE
	boarding_pods_min = 1
	boarding_pods_max = 2
	boarding_pod_cooldown_time = 40 SECONDS

	// Negotiation - ethereals are patient and mysterious
	negotiation_dialog_type = /datum/pirate_faction_dialog/lustrous
	min_negotiation_demand = 500
	max_negotiation_demand = 10000
	pirate_faction = "lustrous"
	hold_credits_min = 1400
	hold_credits_max = 3000

	// Phased combat - crystalline beings
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/lustrous
	broke_lines = list(
		"You carry no wealth. We will take what matter you do carry.",
		"Nothing of value in your accounts. We will harvest from your hold instead.",
	)
	wave_taunts = list(
		list(
			"Your violence disturbs the crystal matrix. More shall come.",
			"The lattice remembers. The lattice sends more.",
		),
		list(
			"Interesting. You resist the inevitable crystallization.",
			"The Radiant One observes your struggle with curiosity.",
		),
		list(
			"The Radiant One shall phase into your reality now.",
			"Prepare for transcendence. The Radiant One comes.",
		),
	)

// ==================== INTERDYNE (Ex-Pharmacists) ====================

/obj/structure/overmap/ship/npc/pirate/interdyne
	name = "interdyne biocraft"
	desc = "A medical vessel operated by rogue pharmaceutical researchers. They need 'funding'."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_interdyne
	ship_color = NPC_COLOR_INTERDYNE

	// Detection range
	territory_range = 3

	// Better equipped but balanced
	lock_time = 5 SECONDS           // Increased from 4s for balance
	laser_cooldown_time = 6 SECONDS // Added for balance
	missile_cooldown_time = 15 SECONDS // Increased from 8s for balance

	crew_min = 3
	crew_max = 5
	captain_type = /mob/living/basic/trooper/pirate/faction/interdyne/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/interdyne/melee,
		/mob/living/basic/trooper/pirate/faction/interdyne/ranged,
		/mob/living/basic/trooper/pirate/faction/interdyne/ranged,
	)

	// Boarding pods - interdyne sends surgical strike teams
	boarding_pods_enabled = TRUE
	boarding_pods_min = 1
	boarding_pods_max = 3
	boarding_pod_cooldown_time = 30 SECONDS

	// Negotiation - clinical and professional
	negotiation_dialog_type = /datum/pirate_faction_dialog/interdyne
	min_negotiation_demand = 700
	max_negotiation_demand = 12000
	pirate_faction = "interdyne"
	hold_credits_min = 1800
	hold_credits_max = 3800

	// Phased combat - surgical strike teams
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/interdyne
	broke_lines = list(
		"Accounts empty. Switching to physical asset recovery. Deploying collection team.",
		"No liquid funds. Your cargo and your crew will serve as compensation.",
	)
	wave_taunts = list(
		list(
			"Subjects neutralized. Deploying backup extraction team.",
			"Your resistance has been documented. Increasing dosage.",
		),
		list(
			"Fascinating combat data. The Director will be pleased.",
			"Clinical trials proceeding as expected. Phase 2 initiated.",
		),
		list(
			"Director Prime is taking personal interest in your case.",
			"The Director will handle this... personally.",
		),
	)

// ==================== IRS (Tax Collectors) ====================

/obj/structure/overmap/ship/npc/pirate/irs
	name = "auditor enforcement vessel"
	desc = "A government vessel operated by the Space IRS. You haven't been paying your taxes."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_irs
	ship_color = NPC_COLOR_IRS

	// Detection range
	territory_range = 3

	// Well-funded government agency - but still balanced
	lock_time = 5 SECONDS           // Increased from 3s for balance
	laser_cooldown_time = 6 SECONDS // Increased from 4s for balance
	missile_cooldown_time = 15 SECONDS // Increased from 8s for balance

	// Better engines
	speed_limit = 0.6
	thrust_power = 0.35

	crew_min = 3
	crew_max = 5
	captain_type = /mob/living/basic/trooper/pirate/faction/irs/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/irs/melee,
		/mob/living/basic/trooper/pirate/faction/irs/ranged,
		/mob/living/basic/trooper/pirate/faction/irs/ranged,
	)

	// Boarding pods - IRS sends auditors to seize assets
	boarding_pods_enabled = TRUE
	boarding_pods_min = 2
	boarding_pods_max = 4
	boarding_pod_cooldown_time = 25 SECONDS

	// Negotiation - IRS is bureaucratic and demanding (no counter-offers!)
	negotiation_dialog_type = /datum/pirate_faction_dialog/irs
	min_negotiation_demand = 1000
	max_negotiation_demand = 20000
	pirate_faction = "irs"
	// Collections vessel: the fullest coffers in the pool, and the best robbery
	hold_credits_min = 2800
	hold_credits_max = 6000

	// Phased combat - tax enforcement
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/irs
	broke_lines = list(
		"Insufficient funds for settlement. Proceeding directly to asset seizure.",
		"You cannot pay. Then we collect in kind. Agents are boarding now.",
	)
	wave_taunts = list(
		list(
			"Resistance to audit has been noted on your permanent record.",
			"Additional agents have been assigned to your case.",
		),
		list(
			"This is your FINAL NOTICE. Penalties are accumulating.",
			"Your tax liability increases with every agent you harm.",
		),
		list(
			"The Chief Auditor is reviewing your case PERSONALLY.",
			"Nobody escapes the Chief Auditor. NOBODY.",
		),
	)

// ==================== MEDIEVAL (Space Warmongers) ====================

/obj/structure/overmap/ship/npc/pirate/medieval
	name = "siege warship"
	desc = "A heavily armored warship crewed by medieval warriors. They don't know how it works either."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_medieval
	ship_color = NPC_COLOR_MEDIEVAL

	// Detection range
	territory_range = 3

	// Slow but tough - they don't really understand the engines
	speed_limit = 0.35
	thrust_power = 0.2

	// Longer lock times - medieval targeting systems
	lock_time = 6 SECONDS
	laser_cooldown_time = 6 SECONDS

	crew_min = 3
	crew_max = 6
	captain_type = /mob/living/basic/trooper/pirate/faction/medieval/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/medieval/melee,
		/mob/living/basic/trooper/pirate/faction/medieval/melee,
		/mob/living/basic/trooper/pirate/faction/medieval/ranged,
	)

	// Boarding pods - medieval warriors LOVE boarding actions
	boarding_pods_enabled = TRUE
	boarding_pods_min = 3
	boarding_pods_max = 5
	boarding_pod_cooldown_time = 20 SECONDS

	// Negotiation - theatrical knights
	negotiation_dialog_type = /datum/pirate_faction_dialog/medieval
	min_negotiation_demand = 600
	max_negotiation_demand = 12000
	pirate_faction = "medieval"
	hold_credits_min = 1500
	hold_credits_max = 3200

	// Phased combat - knights and men-at-arms
	boss_type = /mob/living/basic/trooper/pirate/faction/boss/medieval
	broke_lines = list(
		"No coin in thy coffers? Then we shall take thy goods by force of arms!",
		"A pauper's ship! Very well - the spoils shall be whatever thou carriest!",
	)
	wave_taunts = list(
		list(
			"HUZZAH! Your mettle is tested! Send forth more knights!",
			"The fallen shall be AVENGED! More soldiers, TO ARMS!",
		),
		list(
			"You fight with HONOR! But honor will not save thee!",
			"The siege continues! Bring forth the HEAVY INFANTRY!",
		),
		list(
			"So be it! THE BLACK KNIGHT SHALL END THIS!",
			"'TIS BUT A SCRATCH! The Black Knight challenges thee!",
		),
	)
