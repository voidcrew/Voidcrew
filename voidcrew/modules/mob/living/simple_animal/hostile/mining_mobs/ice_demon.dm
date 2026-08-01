/mob/living/basic/mining/ice_demon/random/Initialize()
	. = ..()
	if(prob(15))
		new /mob/living/simple_animal/hostile/asteroid/old_demon(loc)
		return INITIALIZE_HINT_QDEL

// Rare elite roll from ice demon spawns, ported from Voidcrew-LRP.
/mob/living/simple_animal/hostile/asteroid/old_demon
	name = "primordial demon"
	desc = "At the beginning, there was nothing but emptiness. \
	From the emptiness, there came monsters."
	icon = 'voidcrew/icons/mob/icemoon/icemoon_monsters.dmi'
	icon_state = "old_demon"
	icon_living = "old_demon"
	// icemoon_monsters.dmi has no dead sprite for this one, and del_on_death means
	// the corpse never renders anyway. Point at the living state so nothing can end
	// up with a blank icon.
	icon_dead = "old_demon"
	icon_gib = null
	mob_biotypes = MOB_ORGANIC|MOB_BEAST
	mouse_opacity = MOUSE_OPACITY_ICON
	speak_emote = list("telepathically shrieks")
	speed = 2
	move_to_delay = 2
	projectiletype = /obj/projectile/temp/ice_blast
	projectilesound = 'sound/items/weapons/pierce.ogg'
	ranged = TRUE
	ranged_message = "manifests ice"
	ranged_cooldown_time = 15
	minimum_distance = 3
	retreat_distance = 1
	maxHealth = 300
	health = 300
	obj_damage = 100
	environment_smash = ENVIRONMENT_SMASH_WALLS
	melee_damage_lower = 25
	melee_damage_upper = 25
	attack_verb_continuous = "cleaves"
	attack_verb_simple = "cleave"
	attack_sound = 'sound/items/weapons/bladeslice.ogg'
	vision_range = 8
	aggro_vision_range = 8
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG
	del_on_death = TRUE
	loot = list()
	death_message = "screeches in rage as it falls back into nullspace."
	death_sound = 'sound/effects/magic/demon_dies.ogg'
	stat_attack = HARD_CRIT
	movement_type = FLYING
	robust_searching = TRUE
	footstep_type = FOOTSTEP_MOB_CLAW

/obj/projectile/temp/ice_blast
	name = "ice blast"
	damage = 10
	temperature = -75

/mob/living/simple_animal/hostile/asteroid/old_demon/death(gibbed)
	move_force = MOVE_FORCE_DEFAULT
	move_resist = MOVE_RESIST_DEFAULT
	pull_force = PULL_FORCE_DEFAULT
	new /obj/item/stack/ore/bluespace_crystal(loc, 10)
	if(prob(20))
		new /obj/item/assembly/signaler/anomaly/bluespace(loc)
	return ..()
