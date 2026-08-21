//the base mining mob
/mob/living/simple_animal/hostile/asteroid
	vision_range = 2
	atmos_requirements = null
	faction = list(FACTION_MINING)
	// VOIDCREW EDIT: TRAIT_SNOWSTORM_IMMUNE added. /mob/living/basic/mining - the newer
	// base every other icemoon mob already sits on - grants all THREE of these
	// (see its Initialize), and this one being two-thirds of that list is an oversight
	// upstream never felt because on icemoon the plasma rivers are mapped, not carved.
	//
	// Here they are carved, and TRAIT_SNOWSTORM_IMMUNE is not only about the weather:
	// /turf/open/lava/plasma - the ice planet's river turf - uses it as its `immunity_trait`.
	// Without it a polar bear (weight 35 in /datum/biome/snow, one of the commonest
	// spawns) that a river is carved through takes the full lava path: do_burn() gives it
	// TRAIT_NO_EXTINGUISH and a perma_fire_overlay, ignite_mob() hangs an
	// /obj/effect/dummy/lighting_obj/moblight/fire on it, and from then on every single
	// step it takes re-queues that light source into SSlighting forever. That is what made
	// wait_for_lighting_settle() never see the bottom of the queue on ice planets and only
	// on ice planets - a lava planet's rivers key off TRAIT_LAVA_IMMUNE, which this list
	// already had. Rivers are carved AFTER populate_terrain, so the mobs are standing there
	// before the plasma arrives; it is not a choice anything made.
	weather_immunities = list(TRAIT_LAVA_IMMUNE, TRAIT_ASHSTORM_IMMUNE, TRAIT_SNOWSTORM_IMMUNE)
	// END VOIDCREW EDIT (was: list(TRAIT_LAVA_IMMUNE,TRAIT_ASHSTORM_IMMUNE))
	obj_damage = 30
	environment_smash = ENVIRONMENT_SMASH_WALLS
	minbodytemp = 0
	maxbodytemp = INFINITY
	unsuitable_heat_damage = 20
	response_harm_continuous = "strikes"
	response_harm_simple = "strike"
	status_flags = 0
	combat_mode = TRUE
	var/throw_message = "bounces off of"
	/// Is this mob subtype from a spawner (e.g. necropolis tendril, demonic portal)? Can be used to affect what it drops (e.g. legions force-dropping ashen skeletons).
	var/from_spawner = FALSE
	// Pale purple, should be red enough to see stuff on lavaland
	lighting_cutoff_red = 25
	lighting_cutoff_green = 15
	lighting_cutoff_blue = 35
	mob_size = MOB_SIZE_LARGE
	var/icon_aggro = null

	///what trophy this mob drops
	var/crusher_loot
	///what is the chance the mob drops it if all their health was taken by crusher attacks
	var/crusher_drop_mod = 25

/mob/living/simple_animal/hostile/asteroid/Initialize(mapload)
	. = ..()
	if(crusher_loot)
		AddElement(/datum/element/crusher_loot, crusher_loot, crusher_drop_mod, del_on_death)
	AddElement(/datum/element/mob_killed_tally, "mobs_killed_mining")
	var/static/list/vulnerable_projectiles
	if(!vulnerable_projectiles)
		vulnerable_projectiles = string_list(MINING_MOB_PROJECTILE_VULNERABILITY)
	AddElement(\
		/datum/element/ranged_armour,\
		minimum_projectile_force = 30,\
		below_projectile_multiplier = 0.3,\
		vulnerable_projectile_types = vulnerable_projectiles,\
		minimum_thrown_force = 20,\
		throw_blocked_message = throw_message,\
	)

	RegisterSignals(src, list(COMSIG_PROJECTILE_PREHIT, COMSIG_ATOM_PREHITBY), PROC_REF(Aggro))

/mob/living/simple_animal/hostile/asteroid/Aggro()
	..()
	if(vision_range == aggro_vision_range && icon_aggro)
		icon_state = icon_aggro

/mob/living/simple_animal/hostile/asteroid/LoseAggro()
	..()
	if(stat == DEAD)
		return
	icon_state = icon_living
