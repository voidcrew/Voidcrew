// Package: P6 NPCs. The plasma pistol and plasma rifle pirate loadouts.
//
// Yellow- and red-zone pirate gunners can roll a Cinder, red-zone ones a Furnace, and the red-zone
// Director Prime and Chief Auditor carry a Furnace. Their bolts are the real plasma bolts. Like every
// pirate gun these are hand sprites: nothing drops. Pirates are basic mobs firing through
// /datum/component/pirate_gun with no gun object, so a Furnace pirate keeps the rifle's heat on the component:
// the same heat a shot, the same cooling where it stands, the same overheat shutdown. When its coils are white-hot
// it vents and never times it, so it always gets the vent left to run out. Every block is a world.time deadline
// checked when it next tries to fire, so nothing can leave it stuck.

/datum/pirate_gun_loadout/plasma_pistol
	energy_shots = 15
	burst = 2
	burst_delay = 0.5 SECONDS
	cooldown = 6 SECONDS
	reload_time = 3 SECONDS
	reload_sound = 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg'
	reload_lines = list("Changing cartridges!", "Cartridge is dry!", "Cover me!")

/datum/pirate_gun_loadout/plasma_rifle
	energy_shots = 12
	burst = 1
	cooldown = 4 SECONDS
	reload_time = 4 SECONDS
	reload_sound = 'voidcrew/modules/plasma_weapons/sound/flask_load.ogg'
	reload_lines = list("Venting!", "She's cooking!", "New cartridge!")

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
	. = pirate_crew_arm(src, /datum/pirate_gun_loadout/plasma_rifle)
	if(!. || !l_hand)
		return
	// The Furnace takes both hands: whatever was in the other one goes
	l_hand = null
	if(use_dynamic_appearance)
		apply_dynamic_human_appearance(src, mob_spawn_path = mob_spawner, r_hand = r_hand)

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

// A Furnace pirate vents its rifle as it changes cartridges
/datum/component/pirate_gun/reload_effects()
	. = ..()
	if(!istype(loadout, /datum/pirate_gun_loadout/plasma_rifle))
		return
	var/mob/living/owner = parent
	if(QDELETED(owner) || owner.stat != CONSCIOUS)
		return
	plasma_vent_puff(get_turf(owner))

// A plasma pirate's shots carry as far as a player's (plasma_weapons_far_sound()), and a Furnace's heat up
/datum/component/pirate_gun/shoot_once(fire_serial)
	. = ..()
	if(!.)
		return
	plasma_heat_shot()
	var/obj/item/gun/energy/plasma_weapon/gun_path = loadout.gun_type
	if(ispath(gun_path, /obj/item/gun/energy/plasma_weapon))
		plasma_weapons_far_sound(parent, initial(gun_path.far_fire_sound))

/datum/component/pirate_gun
	/// Furnace heat, for a plasma rifle loadout
	var/plasma_heat = 0
	/// world.time cooling was last applied up to
	var/plasma_heat_at = 0
	/// world.time the running vent's sweep ends and its heat comes off, or 0
	var/plasma_vent_done_at = 0
	/// world.time until which the vent blocks firing
	var/plasma_vent_until = 0
	/// world.time until which an overheat blocks firing, or 0
	var/plasma_shutdown_until = 0

/// The Furnace's heat a shot, or 0 for a loadout that doesn't heat
/datum/component/pirate_gun/proc/plasma_heat_per_shot()
	var/obj/item/gun/energy/plasma_weapon/gun_path = loadout?.gun_type
	if(!ispath(gun_path, /obj/item/gun/energy/plasma_weapon))
		return 0
	return initial(gun_path.uses_heat) ? initial(gun_path.heat_per_shot) : 0

/// Brings the heat up to now: cooling, a finished vent's heat, a finished shutdown
/datum/component/pirate_gun/proc/plasma_heat_update()
	if(plasma_shutdown_until && world.time >= plasma_shutdown_until)
		plasma_shutdown_until = 0
		plasma_heat = PLASMA_OVERHEAT_END_HEAT
		plasma_heat_at = world.time
	if(plasma_vent_done_at && world.time >= plasma_vent_done_at)
		plasma_vent_done_at = 0
		plasma_heat = max(plasma_heat - PLASMA_VENT_COOL, 0)
	var/elapsed = (world.time - plasma_heat_at) / (1 SECONDS)
	plasma_heat_at = world.time
	if(plasma_shutdown_until || elapsed <= 0 || plasma_heat <= 0)
		return
	plasma_heat = plasma_heat_cooled(plasma_heat, plasma_heat_cool_rate(get_turf(parent)), elapsed)

/// TRUE while the Furnace's heat keeps it from firing. Starts a vent when the coils are white-hot.
/datum/component/pirate_gun/proc/plasma_heat_blocks()
	if(!plasma_heat_per_shot())
		return FALSE
	plasma_heat_update()
	if(plasma_shutdown_until || world.time < plasma_vent_until)
		return TRUE
	if(plasma_heat < PLASMA_HEAT_STEP_3)
		return FALSE
	// An NPC vents and lets it run out: the heat comes off when the sweep ends, then it vents a moment longer
	plasma_vent_done_at = world.time + PLASMA_VENT_SWEEP
	plasma_vent_until = plasma_vent_done_at + PLASMA_VENT_NONE_LOCK
	next_fire_at = max(next_fire_at, plasma_vent_until)
	var/mob/living/owner = parent
	playsound(owner, PLASMA_SOUND_VENT_GRACE, 50, TRUE)
	plasma_vent_puff(get_turf(owner))
	return TRUE

/// A Furnace shot's heat, and the overheat if it brings the barrel to the max
/datum/component/pirate_gun/proc/plasma_heat_shot()
	var/per_shot = plasma_heat_per_shot()
	if(!per_shot)
		return
	plasma_heat_update()
	plasma_heat += per_shot
	if(plasma_heat < PLASMA_HEAT_MAX)
		return
	plasma_heat = PLASMA_HEAT_MAX
	plasma_shutdown_until = world.time + PLASMA_OVERHEAT_SHUTDOWN
	next_fire_at = max(next_fire_at, plasma_shutdown_until)
	var/mob/living/owner = parent
	owner.visible_message(span_warning("[owner]'s rifle coils lock up!"))
	playsound(owner, PLASMA_SOUND_FURNACE_OVERHEAT, 50, TRUE)

/datum/component/pirate_gun/try_fire(atom/target)
	if(plasma_heat_blocks())
		return FALSE
	return ..()
