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
	melee_damage_lower = 45
	melee_damage_upper = 55
	armour_penetration = 50
	faction = list(FACTION_PIRATE)
	unsuitable_atmos_damage = 0
	minimum_survivable_temperature = 0
	/// The unique item this boss drops on death
	var/boss_unique_drop = null
	/// The loot tier multiplier for this boss
	var/loot_tier = NPC_LOOT_TIER_BOSS
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
	melee_damage_lower = 50
	melee_damage_upper = 60
	armour_penetration = 55
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
	melee_damage_lower = 45
	melee_damage_upper = 55
	armour_penetration = 50
	attack_verb_continuous = "curses"
	attack_verb_simple = "curse"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	light_range = 2
	light_power = 2
	light_color = "#4488FF"
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/skeleton/davyjones
	r_hand = /obj/item/gun/magic/midas_hand
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
	melee_damage_lower = 55
	melee_damage_upper = 65
	armour_penetration = 40
	attack_verb_continuous = "ROBUSTS"
	attack_verb_simple = "ROBUST"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	speak_emote = list("GREYTIDES")
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/grey/robust
	r_hand = /obj/item/storage/toolbox/mechanical/old/clean
	l_hand = /obj/item/stack/telecrystal/five
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
	melee_damage_lower = 45
	melee_damage_upper = 55
	armour_penetration = 55
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
	melee_damage_lower = 40
	melee_damage_upper = 50
	armour_penetration = 45
	attack_verb_continuous = "injects"
	attack_verb_simple = "inject"
	attack_sound = 'sound/items/hypospray.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/interdyne/captain
	r_hand = /obj/item/reagent_containers/hypospray/combat
	plunder_credits = 3000
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 3
	var/ranged_cooldown = 4 SECONDS

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
	melee_damage_lower = 40
	melee_damage_upper = 50
	armour_penetration = 45
	attack_verb_continuous = "audits"
	attack_verb_simple = "audit"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_PUNCH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/irs/captain
	r_hand = /obj/item/gun/energy/e_gun/lethal
	plunder_credits = 3000
	ai_controller = /datum/ai_controller/basic_controller/trooper/ranged
	var/projectiletype = /obj/projectile/beam/laser
	var/projectilesound = 'sound/items/weapons/laser.ogg'
	var/burst_shots = 4
	var/ranged_cooldown = 3 SECONDS

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
	melee_damage_lower = 60
	melee_damage_upper = 75
	armour_penetration = 60
	attack_verb_continuous = "SMITES"
	attack_verb_simple = "SMITE"
	attack_sound = 'sound/items/weapons/smash.ogg'
	attack_vis_effect = ATTACK_EFFECT_SMASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/captain
	corpse = /obj/effect/mob_spawn/corpse/human/pirate/faction/medieval/captain
	r_hand = /obj/item/fireaxe/boardingaxe
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/medieval/Initialize(mapload)
	. = ..()
	// The Black Knight refuses to use guns
	ADD_TRAIT(src, TRAIT_NOGUNS, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TOSS_GUN_HARD, INNATE_TRAIT)
	// Visual gigantism - even bigger than warlord
	transform = transform.Scale(1.5, 1.5)

// ==================== ROGUES BOSS ====================

/mob/living/basic/trooper/pirate/faction/boss/rogues
	name = "Dread Pirate Roberts"
	desc = "The legendary pirate captain. There have been many before them, but this one has the mask."
	maxHealth = 320
	health = 320
	melee_damage_lower = 45
	melee_damage_upper = 55
	armour_penetration = 50
	attack_verb_continuous = "slashes"
	attack_verb_simple = "slash"
	attack_sound = 'sound/items/weapons/blade1.ogg'
	attack_vis_effect = ATTACK_EFFECT_SLASH
	mob_spawner = /obj/effect/mob_spawn/corpse/human/pirate
	corpse = /obj/effect/mob_spawn/corpse/human/pirate
	r_hand = /obj/item/melee/energy/sword/pirate
	plunder_credits = 3000

/mob/living/basic/trooper/pirate/faction/boss/rogues/Initialize(mapload)
	. = ..()
	// Dread Pirate Roberts is agile and fast
	speed = 0.8

