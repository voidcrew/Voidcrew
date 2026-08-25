/**
 * Faction Pirate Bosses
 *
 * Boss mobs that spawn after 3 waves of boarding parties are defeated.
 * Each boss has significantly higher stats and drops a unique faction-specific item.
 * Killing the boss disables the pirate ship, allowing players to board and claim it.
 */

// ==================== BASE BOSS ====================

/mob/living/basic/trooper/pirate/faction/boss
	name = "Pirate Boss"
	desc = "A fearsome pirate leader."
	maxHealth = 300
	health = 300
	melee_damage_lower = 25
	melee_damage_upper = 30
	armour_penetration = 30
	faction = list(FACTION_PIRATE)
	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	random_loot = null
	random_loot_2 = null
	/// Reference to the NPC ship that spawned this boss (for death tracking)
	var/obj/structure/overmap/ship/npc/pirate/parent_ship

/mob/living/basic/trooper/pirate/faction/boss/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_STUNIMMUNE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_PUSHIMMUNE, INNATE_TRAIT)

/mob/living/basic/trooper/pirate/faction/boss/death(gibbed)
	// Notify the parent ship that the boss is dead
	if(parent_ship?.ai_controller)
		var/datum/ai_controller/npc_ship/controller = parent_ship.ai_controller
		SEND_SIGNAL(controller, COMSIG_BOARDING_BOSS_KILLED, src)

	return ..()

// ==================== SILVERSCALE HIGHLORD ====================

/mob/living/basic/trooper/pirate/faction/boss/silverscale
	name = "Silverscale Highlord"
	desc = "The supreme ruler of the Silverscale noble house. A master duelist who has slain countless challengers."
	maxHealth = 350
	health = 350
	melee_damage_lower = 25
	melee_damage_upper = 35
	armour_penetration = 35
	attack_verb_continuous = "eviscerates"
	attack_verb_simple = "eviscerate"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 3
	light_power = 3
	light_color = "#C0C0C0"
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/highlord
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/silverscale/highlord
	r_hand = /obj/item/melee/energy/sword/pirate
	loot_pool = list(/obj/item/claymore/cutlass, /obj/item/clothing/suit/hooded/cloak/drake, /obj/item/clothing/head/hooded/cloakhood/drake)
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/silverscale/Initialize(mapload)
	. = ..()
	// The Highlord is exceptionally durable
	maxHealth = 400
	health = 400

// ==================== DAVY JONES (Skeleton) ====================

/mob/living/basic/trooper/pirate/faction/boss/skeleton
	name = "Davy Jones"
	desc = "Captain of the Flying Dutchman. His cursed compass always points to the greatest treasure... or the nearest victim."
	maxHealth = 400
	health = 400
	melee_damage_lower = 25
	melee_damage_upper = 30
	armour_penetration = 30
	attack_verb_continuous = "curses"
	attack_verb_simple = "curse"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 2
	light_power = 2
	light_color = "#4488FF"
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	r_hand = /obj/item/claymore/cutlass
	loot_pool = list(/obj/item/claymore/cutlass, /obj/item/gun/ballistic/shotgun/hook)
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/skeleton/Initialize(mapload)
	. = ..()
	// Davy Jones regenerates slowly - 2 HP per second
	AddComponent(/datum/component/regenerator, regeneration_delay = 0, outline_colour = "#4488FF", brute_per_second = 2, burn_per_second = 2)

// ==================== THE ROBUST ONE (Grey Tide) ====================

/mob/living/basic/trooper/pirate/faction/boss/grey
	name = "The Robust One"
	desc = "The ultimate assistant. The greyest tider to ever live. Their toolbox has seen things."
	maxHealth = 300
	health = 300
	melee_damage_lower = 30
	melee_damage_upper = 35
	armour_penetration = 25
	attack_verb_continuous = "ROBUSTS"
	attack_verb_simple = "ROBUST"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	speak_emote = list("GREYTIDES")
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	r_hand = /obj/item/storage/toolbox/mechanical/old/clean
	loot_pool = list(/obj/item/storage/toolbox/mechanical/old/clean, /obj/item/stack/telecrystal/five)
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/grey/Initialize(mapload)
	. = ..()
	// The Robust One moves fast
	speed = 0.8

// ==================== THE RADIANT ONE (Lustrous) ====================

/mob/living/basic/trooper/pirate/faction/boss/lustrous
	name = "The Radiant One"
	desc = "A blindingly luminous ethereal. The crystalline matrix of their body phases in and out of realspace."
	maxHealth = 280
	health = 280
	melee_damage_lower = 25
	melee_damage_upper = 30
	armour_penetration = 35
	attack_verb_continuous = "phases through"
	attack_verb_simple = "phase through"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 6
	light_power = 4
	light_color = "#9966FF"
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/radiant
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/lustrous/radiant
	r_hand = /obj/item/melee/energy/sword/pirate
	loot_pool = list(/obj/item/grenade/gas_crystal/nitrous_oxide_crystal, /obj/item/cain_and_abel)
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/lustrous/Initialize(mapload)
	. = ..()
	// The Radiant One moves fast and is hard to hit
	speed = 0.7

// ==================== DIRECTOR PRIME (Interdyne) ====================

/mob/living/basic/trooper/pirate/faction/boss/interdyne
	name = "Director Prime"
	desc = "The head of all Interdyne black site operations. Their hypospray contains experimental compounds."
	maxHealth = 320
	health = 320
	melee_damage_lower = 20
	melee_damage_upper = 25
	armour_penetration = 25
	attack_verb_continuous = "injects"
	attack_verb_simple = "inject"
	attack_sound = 'sound/items/hypospray.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/prime
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/prime
	r_hand = /obj/item/reagent_containers/hypospray/combat
	l_hand = /obj/item/gun/syringe/syndicate
	loot_pool = list(/obj/item/reagent_containers/hypospray/combat, /obj/item/gun/syringe/syndicate, /obj/item/grenade/gluon)
	plunder_credits = 3000
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 2
	var/ranged_cooldown = 6 SECONDS

/mob/living/basic/trooper/pirate/faction/boss/interdyne/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

// ==================== CHIEF AUDITOR (IRS) ====================

/mob/living/basic/trooper/pirate/faction/boss/irs
	name = "Chief Auditor"
	desc = "The supreme authority of the Space IRS. No one escapes their audits. NO ONE."
	maxHealth = 350
	health = 350
	melee_damage_lower = 20
	melee_damage_upper = 25
	armour_penetration = 25
	attack_verb_continuous = "audits"
	attack_verb_simple = "audit"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/chief
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/chief
	r_hand = /obj/item/gun/energy/e_gun/lethal
	loot_pool = list(/obj/item/gun/energy/e_gun/nuclear, /obj/item/storage/bag/money/dutchmen)
	plunder_credits = 3000
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 3
	var/ranged_cooldown = 5 SECONDS

/mob/living/basic/trooper/pirate/faction/boss/irs/Initialize(mapload)
	. = ..()
	AddComponent(\
		/datum/component/ranged_attacks,\
		projectile_type = projectiletype,\
		projectile_sound = projectilesound,\
		cooldown_time = ranged_cooldown,\
		burst_shots = burst_shots,\
	)

// ==================== THE BLACK KNIGHT (Medieval) ====================

/mob/living/basic/trooper/pirate/faction/boss/medieval
	name = "The Black Knight"
	desc = "A massive armored warrior. 'Tis but a scratch!' No really, they refuse to die."
	maxHealth = 500
	health = 500
	melee_damage_lower = 35
	melee_damage_upper = 40
	armour_penetration = 40
	attack_verb_continuous = "SMITES"
	attack_verb_simple = "SMITE"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/blackknight
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/blackknight
	r_hand = /obj/item/claymore
	loot_pool = list(/obj/item/claymore/weak, /obj/item/shield/kite)
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/medieval/Initialize(mapload)
	. = ..()
	// The Black Knight refuses to use guns
	ADD_TRAIT(src, TRAIT_NOGUNS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TOSS_GUN_HARD, INNATE_TRAIT)
	// Visual gigantism
	transform = transform.Scale(1.3, 1.3)


