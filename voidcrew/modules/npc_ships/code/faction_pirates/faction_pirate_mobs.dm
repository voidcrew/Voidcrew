// Faction-specific pirate NPC mobs for Voidcrew NPC ships
// Each faction has melee, ranged, and captain variants
// All are space-capable (no atmos damage, spacewalk trait)

// ==================== BASE FACTION PIRATE ====================
// All faction pirates inherit from this - provides space capability

/mob/living/basic/trooper/pirate/faction
	name = "Faction Pirate"
	desc = "A pirate aligned with a specific faction."
	faction = list(FACTION_PIRATE)
	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	loot = null // NPC ship crew don't drop loot

/mob/living/basic/trooper/pirate/faction/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)

// ==================== SILVERSCALE (Aristocratic Lizards) ====================

/mob/living/basic/trooper/pirate/faction/silverscale
	name = "Silverscale Pirate"
	desc = "An aristocratic lizard pirate demanding tribute from lesser beings."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale

/mob/living/basic/trooper/pirate/faction/silverscale/melee
	name = "Silverscale Duelist"
	desc = "A noble lizard trained in the art of the blade."
	melee_damage_lower = 30
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 2
	light_power = 2.5
	light_color = COLOR_SOFT_RED
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/melee
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/silverscale/ranged
	name = "Silverscale Marksman"
	desc = "A noble lizard with impeccable aim."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/ranged
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/silverscale/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/silverscale/captain
	name = "Silverscale Noble"
	desc = "A high-born lizard of impeccable breeding and ruthless ambition."
	maxHealth = 150
	health = 150
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/captain
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 100

// ==================== SKELETON (Undead Pirates) ====================

/mob/living/basic/trooper/pirate/faction/skeleton
	name = "Skeleton Pirate"
	desc = "Yarr! An undead scourge of the space lanes."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton

/mob/living/basic/trooper/pirate/faction/skeleton/melee
	name = "Skeleton Swashbuckler"
	desc = "A skeletal swordsman that refuses to stay dead."
	melee_damage_lower = 30
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 2
	light_power = 2.5
	light_color = COLOR_SOFT_RED
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/melee
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/skeleton/ranged
	name = "Skeleton Gunner"
	desc = "A skeletal marksman with hollow eyes."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/ranged
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/skeleton/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/skeleton/captain
	name = "Skeleton Captain"
	desc = "The undead commander of the Flying Dutchman, wielder of the Midas Hand."
	maxHealth = 150
	health = 150
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/captain
	r_hand = /obj/item/gun/magic/midas_hand
	plunder_credits = 100

// ==================== GREY TIDE (Rogue Assistants) ====================

/mob/living/basic/trooper/pirate/faction/grey
	name = "Grey Tider"
	desc = "A former assistant turned space pirate. Robust."
	speak_emote = list("greytides")
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey

/mob/living/basic/trooper/pirate/faction/grey/melee
	name = "Grey Tider"
	desc = "Armed with a toolbox and bad intentions."
	melee_damage_lower = 25
	melee_damage_upper = 30
	attack_verb_continuous = "robusts"
	attack_verb_simple = "robust"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/melee
	r_hand = /obj/item/storage/toolbox/mechanical
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/grey/ranged
	name = "Grey Tider Gunner"
	desc = "Even assistants can find guns sometimes."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/ranged
	r_hand = /obj/item/gun/energy/laser
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/grey/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/grey/captain
	name = "Tidemaster"
	desc = "The greyest of them all. Maximum robustness achieved."
	maxHealth = 150
	health = 150
	melee_damage_lower = 35
	melee_damage_upper = 40
	attack_verb_continuous = "robusts"
	attack_verb_simple = "robust"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/captain
	r_hand = /obj/item/storage/toolbox/syndicate
	plunder_credits = 100

// ==================== LUSTROUS (Mutated Ethereals) ====================

/mob/living/basic/trooper/pirate/faction/lustrous
	name = "Lustrous Pirate"
	desc = "A mutated ethereal obsessed with bluespace crystals."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous

/mob/living/basic/trooper/pirate/faction/lustrous/melee
	name = "Lustrous Scintillant"
	desc = "A crystalline being with a sharp blade."
	melee_damage_lower = 30
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/melee
	r_hand = /obj/item/switchblade
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/lustrous/ranged
	name = "Lustrous Coruscant"
	desc = "A crystalline being channeling energy through strange weapons."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/ranged
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/lustrous/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/lustrous/captain
	name = "Lustrous Radiant"
	desc = "A blindingly bright ethereal, the leader of their crystalline kind."
	maxHealth = 150
	health = 150
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 4
	light_power = 3
	light_color = COLOR_VIVID_YELLOW
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/captain
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 100

// ==================== INTERDYNE (Ex-Pharmacists) ====================

/mob/living/basic/trooper/pirate/faction/interdyne
	name = "Interdyne Pirate"
	desc = "A former pharmaceutical employee turned bioterrorist."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne

/mob/living/basic/trooper/pirate/faction/interdyne/melee
	name = "Interdyne Enforcer"
	desc = "Enforces pharmaceutical compliance with surgical precision."
	melee_damage_lower = 30
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/melee
	r_hand = /obj/item/scalpel
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/interdyne/ranged
	name = "Interdyne Pharmacist"
	desc = "Dispenses death instead of medicine."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/ranged
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/interdyne/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/interdyne/captain
	name = "Interdyne Director"
	desc = "The head of this rogue pharmaceutical operation."
	maxHealth = 150
	health = 150
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 100

// ==================== IRS (Tax Collectors) ====================

/mob/living/basic/trooper/pirate/faction/irs
	name = "IRS Agent"
	desc = "The only thing certain in life is death and taxes. They're here for the taxes."
	faction = list(FACTION_PIRATE, FACTION_IRS)
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs

/mob/living/basic/trooper/pirate/faction/irs/melee
	name = "IRS Enforcer"
	desc = "Collects taxes the hard way."
	melee_damage_lower = 30
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "audits"
	attack_verb_simple = "audit"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/melee
	r_hand = /obj/item/melee/baton/telescopic
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/irs/ranged
	name = "IRS Agent"
	desc = "Armed and ready to collect."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/ranged
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/irs/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/irs/captain
	name = "IRS Head Auditor"
	desc = "The head of tax enforcement. Nobody escapes their audits."
	maxHealth = 150
	health = 150
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/captain
	r_hand = /obj/item/gun/energy/e_gun/lethal
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 3
	var/ranged_cooldown = 4 SECONDS
	plunder_credits = 100

/mob/living/basic/trooper/pirate/faction/irs/captain/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

// ==================== MEDIEVAL (Space Warmongers) ====================

/mob/living/basic/trooper/pirate/faction/medieval
	name = "Medieval Pirate"
	desc = "A space-faring knight who somehow operates a starship."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval

/mob/living/basic/trooper/pirate/faction/medieval/melee
	name = "Medieval Footsoldier"
	desc = "A knight who refuses to use guns. Throws them instead."
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/melee
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/melee
	r_hand = /obj/item/claymore/shortsword
	plunder_credits = 50

/mob/living/basic/trooper/pirate/faction/medieval/melee/Initialize(mapload)
	. = ..()
	// Medieval footsoldiers hate guns and throw them hard
	ADD_TRAIT(src, TRAIT_NOGUNS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TOSS_GUN_HARD, INNATE_TRAIT)
	// Unbreakable spirit - harder to keep down
	AddComponent(/datum/component/unbreakable)

/mob/living/basic/trooper/pirate/faction/medieval/ranged
	name = "Medieval Crossbowman"
	desc = "At least crossbows are period-appropriate. Sort of."
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/ranged
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/ranged
	r_hand = /obj/item/gun/energy/recharge/ebow/large
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/energy/bolt/large
	var/projectilesound = 'sound/items/weapons/punchmiss.ogg'
	var/burst_shots = 1
	var/ranged_cooldown = 4 SECONDS

/mob/living/basic/trooper/pirate/faction/medieval/ranged/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

/mob/living/basic/trooper/pirate/faction/medieval/captain
	name = "Medieval Warlord"
	desc = "A hulking brute of a knight. Massive, stun-immune, and very angry."
	maxHealth = 200
	health = 200
	melee_damage_lower = 50
	melee_damage_upper = 60
	armour_penetration = 50
	attack_verb_continuous = "crushes"
	attack_verb_simple = "crush"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/captain
	r_hand = /obj/item/fireaxe/boardingaxe
	plunder_credits = 150

/mob/living/basic/trooper/pirate/faction/medieval/captain/Initialize(mapload)
	. = ..()
	// Medieval warlords are hulking brutes
	ADD_TRAIT(src, TRAIT_STUNIMMUNE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_PUSHIMMUNE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_NOGUNS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TOSS_GUN_HARD, INNATE_TRAIT)
	// Visual gigantism
	transform = transform.Scale(1.3, 1.3)
