/mob/living/basic/mining/legion/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/mining/legion/large/wasteland
	faction = list(FACTION_WASTELAND)

// Reebe's corrupted legion, ported from Voidcrew-LRP's "disfigured legion".
/mob/living/basic/mining/legion/crystal
	name = "disfigured legion"
	desc = "Disfigured, contorted, and corrupted. This thing was once part of the legion, now it has a different vile and twisted allegiance."
	icon = 'voidcrew/icons/mob/lavaland_monsters.dmi'
	icon_state = "disfigured_legion"
	icon_living = "disfigured_legion"
	icon_dead = "disfigured_legion"
	icon_gib = null
	maxHealth = 90
	health = 90
	brood_type = /mob/living/basic/legion_brood/crystal

/mob/living/basic/mining/legion/crystal/wasteland
	faction = list(FACTION_WASTELAND)

/mob/living/basic/legion_brood/crystal
	name = "disfigured legion"
	desc = "One of none."
	icon = 'voidcrew/icons/mob/lavaland_monsters.dmi'
	icon_state = "disfigured_legion_head"
	icon_living = "disfigured_legion_head"

// Crystal broods burst into shards when destroyed.
/mob/living/basic/legion_brood/crystal/death(gibbed)
	var/turf/origin = get_turf(src)
	for(var/i in 0 to 4)
		var/obj/projectile/shard = new /obj/projectile/bullet/shrapnel/short_range(origin)
		shard.aim_projectile(get_step(src, pick(GLOB.alldirs)), origin)
		shard.firer = src
		shard.fire(i * (360 / 5))
	return ..()

/mob/living/basic/mining/hivelord/beach
	name = "crystal hivelord"
	icon = 'voidcrew/icons/mob/beach/beach_hivelord.dmi'
	icon_state = "hivelord"
	icon_living = "hivelord"
	icon_dead = "hivelord_dead"
	icon_gib = null
	faction = list(FACTION_BEACH, FACTION_CRYSTAL)
	death_spawn_type = /mob/living/basic/hivelord_brood/beach

/mob/living/basic/hivelord_brood/beach
	icon = 'voidcrew/icons/mob/beach/beach_hivelord.dmi'
	icon_state = "hivelord_tentacle"
	icon_living = "hivelord_tentacle"
	icon_dead = "hivelord_tentacle"
	icon_gib = null
	pixel_x = 6
	color = COLOR_BRIGHT_BLUE
	faction = list(FACTION_BEACH, FACTION_CRYSTAL)
