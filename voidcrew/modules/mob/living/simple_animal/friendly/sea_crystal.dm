/mob/living/simple_animal/sea_crystal
	name = "sea crystal"
	desc = "A large, clearly dangerous crystal."
	icon = 'voidcrew/icons/obj/seacrystal.dmi'
	icon_state = "seacrystal"
	icon_dead = "seacrystal"
	maxHealth = 450
	health = 450
	pixel_x = -18
	pixel_y = -10
	faction = list(FACTION_CRYSTAL)
	friendly_verb_continuous = "bumps"
	friendly_verb_simple = "bump"
	speed = 3
	weather_immunities = list("acid", "ash", "lava", "snow")
	pixel_x = -18
	pixel_y = -5
	/// The crystal's combat abilities, granted on Initialize and only usable while player-controlled.
	var/list/datum/action/cooldown/spell/crystal_spells

/mob/living/simple_animal/sea_crystal/Initialize(mapload)
	. = ..()
	crystal_spells = list(
		new /datum/action/cooldown/spell/voice_of_god(src),
		new /datum/action/cooldown/spell/jaunt/ethereal_jaunt/crystal(src),
		new /datum/action/cooldown/spell/conjure/crystal_hivelord(src),
	)
	for(var/datum/action/cooldown/spell/spell as anything in crystal_spells)
		spell.Grant(src)

/mob/living/simple_animal/sea_crystal/Destroy()
	QDEL_LIST(crystal_spells)
	return ..()

/**
 * Combat abilities ported from Voidcrew-LRP, where the sea crystal held
 * Voice of God, Crystal Jaunt and Summon Hivelord Swarm. LRP ran on the
 * pre-refactor `/obj/effect/proc_holder/spell` system; these are the same
 * three spells rebuilt on `/datum/action/cooldown/spell`, with cooldowns
 * converted from deciseconds and the summons pointed at the basic-mob
 * hivelord. Voice of God needs no subtype - upstream's type already has
 * `spell_requirements = NONE`, so a simple mob can cast it as-is.
 */

/obj/effect/temp_visual/seacrystal
	icon = 'voidcrew/icons/effects/crystal_effects.dmi'
	randomdir = FALSE
	duration = 1 SECONDS

/obj/effect/temp_visual/seacrystal/sparks
	name = "sea sparks"
	icon_state = "sparkles"
	randomdir = TRUE

/obj/effect/temp_visual/seacrystal/jaunt // The traditional teleport
	name = "sea jaunt"
	duration = 1.2 SECONDS
	icon_state = "dustin"

/obj/effect/temp_visual/seacrystal/jaunt/out
	icon_state = "dustout"

/datum/action/cooldown/spell/jaunt/ethereal_jaunt/crystal
	name = "Crystal Jaunt"
	cooldown_time = 45 SECONDS // LRP charge_max 450
	spell_requirements = NONE
	jaunt_duration = 2 SECONDS // LRP jaunt_duration 20
	jaunt_in_type = /obj/effect/temp_visual/seacrystal/jaunt
	jaunt_out_type = /obj/effect/temp_visual/seacrystal/jaunt/out

// LRP's jaunt had no steam; the effect predates it being added to the base type.
/datum/action/cooldown/spell/jaunt/ethereal_jaunt/crystal/do_steam_effects(turf/loc)
	return

/datum/action/cooldown/spell/conjure/crystal_hivelord
	name = "Summon Hivelord Swarm"
	desc = "This spell tears the fabric of reality, allowing crystal hivelords to spill forth."
	sound = 'sound/effects/magic/summonitems_generic.ogg'

	cooldown_time = 60 SECONDS // LRP charge_max 600
	spell_requirements = NONE

	invocation = "SKEST ZA!"
	invocation_type = INVOCATION_SHOUT

	summon_amount = 3
	summon_radius = 3
	summon_type = list(/mob/living/basic/mining/hivelord/beach)

/**
 * The encounter half of LRP's sea crystal: a spawner structure that trickles
 * out beach sharks, and answers any damage by summoning a trio of crystal
 * hivelords over a telegraphed windup. Breaking it drops the sea crystal
 * item, which is how a player gets the shapeshift spell below.
 *
 * Ported from Voidcrew-LRP's `/obj/structure/spawner/sea_crystal`. Changes
 * forced by the modern codebase: the `sleep()` telegraph in summon_minions()
 * is an addtimer chain now so an attacker doesn't have their click chain
 * slept for three and a half seconds, the drop hook is handle_deconstruct()
 * because `/obj/deconstruct` is SHOULD_NOT_OVERRIDE, and the spawned sharks
 * are the basic-mob beach carp. Every number is LRP's, including the
 * one-second shark tick - LRP's spawner component counted spawn_time in
 * deciseconds, so `spawn_time = 10` really did mean 1 SECOND.
 */
/obj/structure/spawner/sea_crystal
	name = "sea crystal"
	desc = "A large crystal. Terrible monsters are pouring out from all around it."
	icon = 'voidcrew/icons/obj/seacrystal.dmi'
	icon_state = "seacrystal"
	faction = list(FACTION_BEACH)
	max_mobs = 2
	spawn_time = 1 SECONDS // LRP spawn_time 10
	max_integrity = 1350
	pixel_x = -18
	pixel_y = -5
	mob_types = list(/mob/living/basic/carp/mega/beach)
	move_resist = INFINITY
	anchored = TRUE
	resistance_flags = FIRE_PROOF | LAVA_PROOF
	layer = FLY_LAYER
	light_color = LIGHT_COLOR_ELECTRIC_GREEN
	light_power = 1
	light_range = 4
	/// Time between hivelord counter-summons.
	var/cooldown_time = 20 SECONDS
	var/newcolor = "#1302ad"

	COOLDOWN_DECLARE(summon_cooldown)

/obj/structure/spawner/sea_crystal/Initialize(mapload)
	. = ..()
	for(var/turf/adjacent in RANGE_TURFS(1, src))
		if(ismineralturf(adjacent))
			var/turf/closed/mineral/mineral = adjacent
			mineral.ScrapeAway(flags = CHANGETURF_IGNORE_AIR)

/obj/structure/spawner/sea_crystal/handle_deconstruct(disassembled)
	playsound(loc, 'sound/effects/tendril_destroyed.ogg', 200, FALSE, 50, TRUE)
	new /obj/effect/temp_visual/seacrystal/sparks(loc)
	new /obj/item/sea_crystal(loc)
	return ..()

/obj/structure/spawner/sea_crystal/attackby(obj/item/item, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	summon_minions()

/obj/structure/spawner/sea_crystal/attack_animal(mob/living/simple_animal/user, list/modifiers)
	. = ..()
	summon_minions()

/obj/structure/spawner/sea_crystal/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	. = ..()
	summon_minions()

/obj/structure/spawner/sea_crystal/proc/summon_minions()
	if(QDELETED(src) || !COOLDOWN_FINISHED(src, summon_cooldown))
		return
	COOLDOWN_START(src, summon_cooldown, cooldown_time)
	crystal_power()
	var/turf/center = get_turf(src)
	var/list/summon_turfs = list(
		get_step(center, pick(NORTH, SOUTH)),
		get_step(center, pick(EAST, NORTHEAST)),
		get_step(center, pick(NORTHEAST, WEST)),
	)
	addtimer(CALLBACK(src, PROC_REF(summon_telegraph), summon_turfs), 2.5 SECONDS)

/// Sparks and camera shake, one second before the hivelords actually land.
/obj/structure/spawner/sea_crystal/proc/summon_telegraph(list/summon_turfs)
	if(QDELETED(src))
		return
	for(var/mob/mob in range(10, src))
		if(mob.client)
			shake_camera(mob, 2, 1)
	playsound(loc, 'sound/effects/magic/exit_blood.ogg', 200, TRUE)
	for(var/turf/summon_turf as anything in summon_turfs)
		new /obj/effect/temp_visual/seacrystal/sparks(summon_turf)
		new /obj/effect/temp_visual/seacrystal/jaunt(summon_turf)
	addtimer(CALLBACK(src, PROC_REF(summon_hivelords), summon_turfs), 1 SECONDS)

/obj/structure/spawner/sea_crystal/proc/summon_hivelords(list/summon_turfs)
	if(QDELETED(src))
		return
	for(var/turf/summon_turf as anything in summon_turfs)
		new /mob/living/basic/mining/hivelord/beach(summon_turf)
	crystal_depower()

/obj/structure/spawner/sea_crystal/proc/crystal_power()
	playsound(loc, 'sound/effects/magic/clockwork/narsie_attack.ogg', 200, TRUE)
	add_atom_colour(newcolor, TEMPORARY_COLOUR_PRIORITY)
	for(var/i in 1 to 8)
		new /obj/effect/temp_visual/seacrystal/sparks(get_step(src, i))

/obj/structure/spawner/sea_crystal/proc/crystal_depower()
	remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, newcolor)

/**
 * The reward for breaking the structure: crush the crystal to learn Great
 * Crystal Form, a shapeshift spell that puts the caster in the sea crystal
 * mob above, spells included. LRP granted it through `mind.AddSpell`; mind
 * actions are gone, so the spell is granted to the body with the body as
 * its target, which is what the shapechange status effect moves across on
 * shift and back.
 */
/obj/item/sea_crystal
	name = "sea crystal"
	desc = "It looks fragile"
	icon = 'voidcrew/icons/obj/lavaland/newlavalandplants.dmi'
	icon_state = "unnamed_crystal"
	color = COLOR_DARK_CYAN

/obj/item/sea_crystal/attack_self(mob/user, modifiers)
	if(!ishuman(user))
		return
	to_chat(user, span_danger("Power courses through you! You can now shift your form at will."))
	var/datum/action/cooldown/spell/shapeshift/sea_crystal/crystal = new(user)
	crystal.Grant(user)
	playsound(user, 'sound/effects/glass/glassbr1.ogg', 100, TRUE)
	qdel(src)

/datum/action/cooldown/spell/shapeshift/sea_crystal
	name = "Great Crystal Form"
	desc = "Take on the shape of a powerful crystal entity."
	cooldown_time = 15 SECONDS // LRP charge_max 150
	spell_requirements = NONE
	invocation = "COWER!"
	invocation_type = INVOCATION_SHOUT
	shapeshift_type = /mob/living/simple_animal/sea_crystal
	possible_shapes = list(/mob/living/simple_animal/sea_crystal)


