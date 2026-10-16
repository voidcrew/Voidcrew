/// The ordinary yellow melee shelf, also used by faction pirates.
/proc/npc_ladder_yellow_melee()
	var/static/list/weapons = list(
		/obj/item/knife/combat,
		/obj/item/claymore/shortsword,
		/obj/item/melee/baseball_bat/ablative,
		/obj/item/fireaxe,
		/obj/item/melee/cleric_mace,
		/obj/item/melee/sabre,
	)
	return weapons

/// A probability, never an associative death-loot quantity.
/proc/npc_ladder_red_drop(roll = rand(1, 100))
	return roll <= 25

/mob/living
	var/npc_weapon_ladder_applied = FALSE
	var/npc_red_weapon_drop = FALSE

/// Called after construction and again when a deferred source zone resolves.
/mob/living/proc/apply_npc_weapon_ladder()
	if(npc_weapon_ladder_applied || !npc_zone_initialization_complete || isnull(npc_spawn_context?.zone_type))
		return FALSE
	npc_weapon_ladder_applied = TRUE
	return TRUE

/mob/living/basic/trooper/pirate/faction/apply_npc_weapon_ladder()
	if(!..())
		return FALSE
	initialize_weapon_loot(npc_spawn_context.zone_type)
	return TRUE

// Each bespoke element pays independently (corpse and combat loot are separate).
// Detaching before creation also covers reentrant deaths and resurrection.
/datum/element/death_drops/on_death(mob/living/target, gibbed)
	SIGNAL_HANDLER
	if(istype(target, /mob/living/basic/trooper) || istype(target, /mob/living/basic/skeleton) || istype(target, /mob/living/basic/stickman))
		Detach(target)
	return ..()

/datum/element/death_drops/create_loot(typepath, atom/loot_loc, mob/living/dead, gibbed, spread_px = 4)
	if(ispath(typepath, /obj/item/gun) && (dead.npc_spawn_context?.suppress_gun_loot || (dead.flags_1 & ADMIN_SPAWNED_1)))
		return
	return ..()

// Legacy simple animals bypass death_drops. Filter a private copy so a summon
// cannot change the loot of the next naturally spawned mob of the same type.
/mob/living/simple_animal/drop_loot()
	if(npc_spawn_context?.suppress_gun_loot || (flags_1 & ADMIN_SPAWNED_1))
		var/list/original_loot = loot
		loot = loot?.Copy()
		for(var/loot_type in original_loot)
			if(ispath(loot_type, /obj/item/gun))
				loot -= loot_type
	return ..()

/// Use the existing pistol/knife archetype on low-zone placements. Keep the
/// original body, source references, atmos immunity and source-specific setup.
/mob/living/basic/trooper/apply_npc_weapon_ladder()
	if(!..())
		return FALSE
	if(is_npc_zone_exempt())
		return TRUE
	var/zone = npc_spawn_context.zone_type
	var/pistol_type
	if(istype(src, /mob/living/basic/trooper/nanotrasen/ranged))
		if((zone == ZONE_GREEN && (istype(src, /mob/living/basic/trooper/nanotrasen/ranged/smg) || istype(src, /mob/living/basic/trooper/nanotrasen/ranged/assault))) || (zone != ZONE_RED && istype(src, /mob/living/basic/trooper/nanotrasen/ranged/elite)))
			pistol_type = /mob/living/basic/trooper/nanotrasen/ranged
		if(zone != ZONE_RED && (istype(src, /mob/living/basic/trooper/nanotrasen/ranged/smg/customs) || istype(src, /mob/living/basic/trooper/nanotrasen/ranged/assault/customs)))
			pistol_type = /mob/living/basic/trooper/nanotrasen/ranged
	else if(istype(src, /mob/living/basic/trooper/syndicate/ranged))
		if(zone != ZONE_RED && (istype(src, /mob/living/basic/trooper/syndicate/ranged/smg) || istype(src, /mob/living/basic/trooper/syndicate/ranged/shotgun) || (zone == ZONE_GREEN && istype(src, /mob/living/basic/trooper/syndicate/ranged/space/stormtrooper))))
			pistol_type = /mob/living/basic/trooper/syndicate/ranged
	if(pistol_type)
		use_ladder_pistol(pistol_type)
	if(zone == ZONE_GREEN && istype(src, /mob/living/basic/trooper/syndicate/melee/sword))
		var/mob/living/basic/trooper/syndicate/melee/guard = src
		var/mob/living/basic/trooper/knife_profile = /mob/living/basic/trooper/syndicate/melee
		guard.projectile_deflect_chance = 0
		armour_penetration = 0
		set_npc_zone_health(initial(knife_profile.maxHealth))
		set_npc_zone_melee(15, 15)
		r_hand = /obj/item/knife/combat/survival
		l_hand = null
		set_light(0)
		if(use_dynamic_appearance)
			apply_dynamic_human_appearance(src, mob_spawn_path = mob_spawner, r_hand = r_hand)
	return TRUE

/mob/living/basic/trooper/proc/use_ladder_pistol(mob/living/basic/trooper/profile)
	var/datum/component/ranged_attacks/ranged = GetComponent(/datum/component/ranged_attacks)
	if(!ranged)
		return
	// Use the base archetype's unchanged cadence, rather than retuning a gun.
	ranged.casing_type = initial(profile:casingtype)
	ranged.projectile_type = null
	ranged.projectile_sound = initial(profile:projectilesound)
	ranged.burst_shots = initial(profile:burst_shots)
	ranged.cooldown_time = initial(profile:ranged_cooldown)
	vars["casingtype"] = ranged.casing_type
	vars["projectilesound"] = ranged.projectile_sound
	vars["burst_shots"] = ranged.burst_shots
	vars["ranged_cooldown"] = ranged.cooldown_time
	set_npc_zone_health(initial(profile.maxHealth))
	if(!GetComponent(/datum/component/ranged_mob_full_auto))
		AddComponent(/datum/component/ranged_mob_full_auto)
	if(ai_controller)
		ai_controller.set_ai_status(AI_STATUS_OFF)
		QDEL_NULL(ai_controller)
	ai_controller = new /datum/ai_controller/basic_controller/trooper/ranged(src)
	r_hand = initial(profile.r_hand)
	if(use_dynamic_appearance)
		apply_dynamic_human_appearance(src, mob_spawn_path = mob_spawner, r_hand = r_hand, l_hand = l_hand)

// Copy both lists before trimming them: crusher kills must use the very same
// construction-time roll, and must keep trophies and the mining accelerator.
/mob/living/simple_animal/hostile/megafauna/Initialize(mapload)
	. = ..()
	npc_red_weapon_drop = npc_ladder_red_drop()
	loot = loot?.Copy()
	crusher_loot = crusher_loot?.Copy()
	if(!npc_red_weapon_drop)
		if(istype(src, /mob/living/simple_animal/hostile/megafauna/blood_drunk_miner))
			loot -= /obj/item/melee/cleaving_saw
			crusher_loot -= /obj/item/melee/cleaving_saw
		else if(istype(src, /mob/living/simple_animal/hostile/megafauna/hierophant))
			loot -= /obj/item/hierophant_club
			crusher_loot -= /obj/item/hierophant_club

/mob/living/simple_animal/hostile/megafauna
	var/npc_death_loot_spent = FALSE

/mob/living/simple_animal/hostile/megafauna/drop_loot()
	if(npc_death_loot_spent)
		return
	npc_death_loot_spent = TRUE
	return ..()

// Colossus contents are lazy. Pass the boss's roll into its chest before opening.
/mob/living/simple_animal/hostile/megafauna/colossus/drop_loot()
	if(npc_death_loot_spent)
		return
	npc_death_loot_spent = TRUE
	// Deliberately replace the bare parent constructor to carry the original roll.
	for(var/loot_type in loot)
		var/obj/structure/closet/crate/necropolis/colossus/chest = new loot_type(drop_location())
		chest.ladder_weapon_drop = npc_red_weapon_drop
	loot = list()

/mob/living/basic/lich/Initialize(mapload)
	. = ..()
	npc_red_weapon_drop = npc_ladder_red_drop()
