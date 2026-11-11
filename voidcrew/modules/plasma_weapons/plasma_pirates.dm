// Package: P6 NPCs. The plasma pistol and plasma rifle pirate loadouts.
//
// Yellow- and red-zone pirate gunners can roll a Cinder, red-zone ones a Furnace, and the red-zone
// Director Prime and Chief Auditor carry a Furnace. Their bolts are the real plasma bolts. Like every
// pirate gun these are hand sprites: nothing drops. Pirates are basic mobs firing through
// /datum/component/pirate_gun, so they don't run the rifle's heat model.

/datum/pirate_gun_loadout/plasma_pistol
	energy_shots = 15
	burst = 2
	burst_delay = 0.5 SECONDS
	cooldown = 6 SECONDS
	reload_time = 3 SECONDS
	reload_sound = 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg'
	reload_lines = list("Changing flasks!", "Flask's dry!", "Cover me!")

/datum/pirate_gun_loadout/plasma_rifle
	energy_shots = 12
	burst = 1
	cooldown = 4 SECONDS
	reload_time = 4 SECONDS
	reload_sound = 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg'
	reload_lines = list("Venting!", "She's cooking!", "Changing flasks!")

/// The overmap zone `gunner` was spawned for, or null if it isn't known yet
/proc/plasma_pirate_zone(mob/living/gunner)
	var/datum/npc_spawn_context/context = gunner?.get_npc_spawn_context()
	if(!context)
		return null
	return context.zone_type || SSovermap_zones?.get_zone_type_anywhere(context.source_turf)

/// `weights` with the plasma loadouts added for a gunner from a yellow or red zone. Never changes `weights`.
/proc/plasma_pirate_gun_weights(mob/living/gunner, list/weights)
	var/zone = plasma_pirate_zone(gunner)
	if(zone != ZONE_YELLOW && zone != ZONE_RED)
		return weights
	var/list/plasma_weights = weights.Copy()
	plasma_weights[/datum/pirate_gun_loadout/plasma_pistol] = 2
	if(zone == ZONE_RED)
		plasma_weights[/datum/pirate_gun_loadout/plasma_rifle] = 1
	return plasma_weights

/// Hands a red-zone boss a Furnace in place of its stock shot. Returns the loadout, or null.
/mob/living/basic/trooper/pirate/faction/boss/proc/arm_plasma_rifle()
	if(plasma_pirate_zone(src) != ZONE_RED)
		return null
	return pirate_crew_arm(src, /datum/pirate_gun_loadout/plasma_rifle)

// A boss's zone can resolve after Initialize; the weapon ladder runs again when it does.
/mob/living/basic/trooper/pirate/faction/boss/interdyne/apply_npc_weapon_ladder()
	. = ..()
	if(.)
		arm_plasma_rifle()

/mob/living/basic/trooper/pirate/faction/boss/irs/apply_npc_weapon_ladder()
	. = ..()
	if(.)
		arm_plasma_rifle()

// The Old Furnace is a red-zone prize: a boss met anywhere else loses the roll before its loot is set
/mob/living/basic/trooper/pirate/faction/boss/initialize_weapon_loot(zone)
	if(!weapon_loot_initialized && zone != ZONE_RED && rolled_rare_loot)
		rolled_rare_loot -= /obj/item/gun/energy/plasma_weapon/rifle/old_furnace
	return ..()

// A Furnace pirate vents its rifle as it changes flasks
/datum/component/pirate_gun/reload_effects()
	. = ..()
	if(!istype(loadout, /datum/pirate_gun_loadout/plasma_rifle))
		return
	var/mob/living/owner = parent
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	plasma_vent_puff(get_turf(owner))
