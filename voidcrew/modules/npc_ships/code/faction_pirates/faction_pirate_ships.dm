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

// ==================== ROGUES (Default Pirates) ====================
// Uses the base /obj/structure/overmap/ship/npc/pirate defined in npc_ship.dm
// Shuttle template: pirate_default

// ==================== SILVERSCALE (Aristocratic Lizards) ====================

/obj/structure/overmap/ship/npc/pirate/silverscale
	name = "silverscale noble vessel"
	desc = "An aristocratic vessel operated by the Silverscale lizard nobility. They demand tribute."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_silverscale
	ship_color = NPC_COLOR_SILVERSCALE

	// Detection range
	territory_range = 2

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

	// Negotiation - aristocrats want more
	negotiation_dialog_type = /datum/pirate_faction_dialog/silverscale
	min_negotiation_demand = 800
	max_negotiation_demand = 15000
	pirate_faction = "silverscale"

// ==================== SKELETON (Flying Dutchman) ====================

/obj/structure/overmap/ship/npc/pirate/skeleton
	name = "ghostship vessel"
	desc = "A haunted vessel crewed by the undead. The Flying Dutchman sails again."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_dutchman
	ship_color = NPC_COLOR_SKELETON

	// Detection range
	territory_range = 2

	// Combat stats - undead crew are relentless
	lock_time = 4 SECONDS
	laser_cooldown_time = 4 SECONDS

	// Yellow zone - stay to interdict/siphon even without weapons
	retreat_without_weapons = FALSE
	// Scan targets for wealth before engaging
	scan_before_engage = TRUE
	// Steal 25% of target's money then retreat
	siphon_goal_percent = 25

	crew_min = 3
	crew_max = 6
	captain_type = /mob/living/basic/trooper/pirate/faction/skeleton/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/melee,
		/mob/living/basic/trooper/pirate/faction/skeleton/ranged,
	)

	// Negotiation - undead will negotiate but are patient and ominous
	negotiation_dialog_type = /datum/pirate_faction_dialog/skeleton
	min_negotiation_demand = 400
	max_negotiation_demand = 8000
	pirate_faction = "skeleton"

// ==================== GREY TIDE (Rogue Assistants) ====================

/obj/structure/overmap/ship/npc/pirate/grey
	name = "toolbox salvage vessel"
	desc = "A ramshackle vessel operated by former assistants. GREYTIDE STATION WIDE."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_grey
	ship_color = NPC_COLOR_GREY

	// Grey tiders are opportunistic
	territory_range = 2

	// Weaker ship stats - they're assistants after all
	speed_limit = 0.4
	thrust_power = 0.25

	// Yellow zone - stay to interdict/siphon even without weapons
	retreat_without_weapons = FALSE
	// Scan targets for wealth before engaging
	scan_before_engage = TRUE
	// Steal 25% of target's money then retreat
	siphon_goal_percent = 25

	crew_min = 3
	crew_max = 5
	captain_type = /mob/living/basic/trooper/pirate/faction/grey/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/grey/melee,
		/mob/living/basic/trooper/pirate/faction/grey/ranged,
	)

	// Negotiation - assistants take what they can get
	negotiation_dialog_type = /datum/pirate_faction_dialog/grey
	min_negotiation_demand = 200
	max_negotiation_demand = 5000
	pirate_faction = "grey"

// ==================== LUSTROUS (Mutated Ethereals) ====================

/obj/structure/overmap/ship/npc/pirate/lustrous
	name = "geode crystal vessel"
	desc = "A strange crystalline vessel crewed by mutated ethereals obsessed with bluespace."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_geode
	ship_color = NPC_COLOR_LUSTROUS

	// Detection range
	territory_range = 2

	// Yellow zone - stay to interdict/siphon even without weapons
	retreat_without_weapons = FALSE
	// Scan targets for wealth before engaging
	scan_before_engage = TRUE
	// Steal 25% of target's money then retreat
	siphon_goal_percent = 25

	crew_min = 2
	crew_max = 4
	captain_type = /mob/living/basic/trooper/pirate/faction/lustrous/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/lustrous/melee,
		/mob/living/basic/trooper/pirate/faction/lustrous/ranged,
	)

	// Negotiation - ethereals are patient and mysterious
	negotiation_dialog_type = /datum/pirate_faction_dialog/lustrous
	min_negotiation_demand = 500
	max_negotiation_demand = 10000
	pirate_faction = "lustrous"

// ==================== INTERDYNE (Ex-Pharmacists) ====================

/obj/structure/overmap/ship/npc/pirate/interdyne
	name = "interdyne biocraft"
	desc = "A medical vessel operated by rogue pharmaceutical researchers. They need 'funding'."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_interdyne
	ship_color = NPC_COLOR_INTERDYNE

	// Detection range
	territory_range = 2

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

	// Negotiation - clinical and professional
	negotiation_dialog_type = /datum/pirate_faction_dialog/interdyne
	min_negotiation_demand = 700
	max_negotiation_demand = 12000
	pirate_faction = "interdyne"

// ==================== IRS (Tax Collectors) ====================

/obj/structure/overmap/ship/npc/pirate/irs
	name = "auditor enforcement vessel"
	desc = "A government vessel operated by the Space IRS. You haven't been paying your taxes."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_irs
	ship_color = NPC_COLOR_IRS

	// Detection range
	territory_range = 2

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

	// Negotiation - IRS is bureaucratic and demanding (no counter-offers!)
	negotiation_dialog_type = /datum/pirate_faction_dialog/irs
	min_negotiation_demand = 1000
	max_negotiation_demand = 20000
	pirate_faction = "irs"

// ==================== MEDIEVAL (Space Warmongers) ====================

/obj/structure/overmap/ship/npc/pirate/medieval
	name = "siege warship"
	desc = "A heavily armored warship crewed by medieval warriors. They don't know how it works either."

	shuttle_template = /datum/map_template/shuttle/voidcrew/pirate_medieval
	ship_color = NPC_COLOR_MEDIEVAL

	// Detection range
	territory_range = 2

	// Slow but tough - they don't really understand the engines
	speed_limit = 0.35
	thrust_power = 0.2

	// Longer lock times - medieval targeting systems
	lock_time = 6 SECONDS
	laser_cooldown_time = 6 SECONDS

	// Yellow zone - stay to interdict/siphon even without weapons
	retreat_without_weapons = FALSE
	// Scan targets for wealth before engaging
	scan_before_engage = TRUE
	// Steal 25% of target's money then retreat
	siphon_goal_percent = 25

	crew_min = 3
	crew_max = 6
	captain_type = /mob/living/basic/trooper/pirate/faction/medieval/captain
	crew_types = list(
		/mob/living/basic/trooper/pirate/faction/medieval/melee,
		/mob/living/basic/trooper/pirate/faction/medieval/melee,
		/mob/living/basic/trooper/pirate/faction/medieval/ranged,
	)

	// Negotiation - theatrical knights
	negotiation_dialog_type = /datum/pirate_faction_dialog/medieval
	min_negotiation_demand = 600
	max_negotiation_demand = 12000
	pirate_faction = "medieval"
