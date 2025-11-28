/**
 * Abyss Spawner - Mobs emerge from the ground like they came from hell itself
 *
 * Uses chasm visuals with an emergence animation effect when mobs spawn.
 * Has subclasses for different world types (lavaland, icemoon, jungle).
 */

// Temporary visual effect for mobs emerging from the abyss
/obj/effect/temp_visual/abyss_emerge
	name = "abyssal emergence"
	icon = 'icons/turf/floors/chasms.dmi'
	icon_state = "chasms-0"
	layer = BELOW_MOB_LAYER
	plane = GAME_PLANE
	duration = 12
	randomdir = FALSE

/obj/effect/temp_visual/abyss_emerge/Initialize(mapload, set_icon, set_icon_state)
	if(set_icon)
		icon = set_icon
	if(set_icon_state)
		icon_state = set_icon_state
	. = ..()
	alpha = 100
	transform = matrix() * 0.3
	animate(src, alpha = 255, transform = matrix(), time = 6, easing = ELASTIC_EASING)
	animate(alpha = 0, transform = matrix() * 1.5, time = 6, easing = QUAD_EASING)

/obj/effect/temp_visual/abyss_emerge/lavaland
	icon = 'icons/turf/floors/chasms.dmi'
	icon_state = "chasms-0"

/obj/effect/temp_visual/abyss_emerge/icemoon
	icon = 'icons/turf/floors/icechasms.dmi'
	icon_state = "icechasms-0"

/obj/effect/temp_visual/abyss_emerge/jungle
	icon = 'icons/turf/floors/junglechasm.dmi'
	icon_state = "junglechasm-0"

/obj/effect/temp_visual/abyss_claws
	name = "grasping claws"
	icon = 'icons/effects/effects.dmi'
	icon_state = "rift"
	layer = ABOVE_MOB_LAYER
	duration = 15
	randomdir = FALSE
	color = "#660000"

/obj/effect/temp_visual/abyss_claws/Initialize(mapload, set_color)
	if(set_color)
		color = set_color
	. = ..()
	pixel_y = -16
	alpha = 0
	animate(src, pixel_y = 0, alpha = 255, time = 8, easing = BACK_EASING)
	animate(alpha = 0, time = 7)

/obj/effect/temp_visual/abyss_claws/ice
	color = "#4444aa"

/obj/effect/temp_visual/abyss_claws/jungle
	color = "#224422"

/**
 * Base Abyss Spawner
 */
/obj/structure/spawner/abyss
	name = "abyssal rift"
	desc = "A tear in the ground leading to unfathomable depths. You can hear distant screams echoing from within."
	icon = 'icons/turf/floors/chasms.dmi'
	icon_state = "chasms-0"
	max_integrity = 200
	max_mobs = 3
	spawn_time = 45 SECONDS
	mob_types = list(/mob/living/basic/mining/goliath)
	spawn_text = "claws its way up from"
	faction = list(FACTION_MINING)
	anchored = TRUE
	density = FALSE
	layer = BELOW_OBJ_LAYER
	resistance_flags = FIRE_PROOF | LAVA_PROOF

	scanner_taggable = TRUE
	mob_gps_id = "ABY"
	spawner_gps_id = "Abyssal Rift"

	var/obj/effect/dummy/lighting_obj/emitted_light
	var/rift_light_color = LIGHT_COLOR_LAVA
	var/emergence_effect_type = /obj/effect/temp_visual/abyss_emerge
	var/claw_effect_type = /obj/effect/temp_visual/abyss_claws
	var/claw_color = "#660000"

/obj/structure/spawner/abyss/Initialize(mapload)
	. = ..()
	emitted_light = new(loc, 3, 1.5, rift_light_color)
	AddComponent(/datum/component/gps, "Ominous Signal")

/obj/structure/spawner/abyss/Destroy()
	QDEL_NULL(emitted_light)
	return ..()

/obj/structure/spawner/abyss/on_mob_spawn(atom/created_atom)
	. = ..()
	var/turf/spawn_turf = get_turf(created_atom)
	new emergence_effect_type(spawn_turf, icon, icon_state)
	new claw_effect_type(spawn_turf, claw_color)
	playsound(spawn_turf, 'sound/effects/magic/demon_consume.ogg', 50, TRUE)

	if(ismovable(created_atom))
		var/atom/movable/spawned = created_atom
		var/original_y = spawned.pixel_y
		spawned.pixel_y = -32
		spawned.alpha = 0
		animate(spawned, pixel_y = original_y, alpha = 255, time = 8, easing = BACK_EASING)

/obj/structure/spawner/abyss/examine(mob/user)
	. = ..()
	. += span_warning("Something stirs in the depths below...")

/obj/structure/spawner/abyss/atom_deconstruct(disassembled)
	visible_message(span_boldannounce("The rift seals shut with an otherworldly shriek!"))
	playsound(loc, 'sound/effects/magic/blind.ogg', 75, TRUE)
	var/turf/T = get_turf(src)
	new /obj/effect/temp_visual/abyss_emerge(T, icon, icon_state)

/**
 * Lavaland Abyss Spawner
 */
/obj/structure/spawner/abyss/lavaland
	name = "infernal rift"
	desc = "A crack in the volcanic rock glowing with hellish light. The heat emanating from it is unbearable."
	rift_light_color = LIGHT_COLOR_LAVA
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/lavaland
	claw_color = "#ff4400"
	mob_types = list(
		/mob/living/basic/mining/goliath,
		/mob/living/basic/mining/watcher,
		/mob/living/basic/mining/legion/spawner_made,
	)
	mob_gps_id = "INF"
	spawner_gps_id = "Infernal Rift"

/obj/structure/spawner/abyss/lavaland/goliath
	name = "goliath burrow"
	desc = "A massive hole torn through the volcanic rock. Something very large lives down there."
	mob_types = list(/mob/living/basic/mining/goliath)
	mob_gps_id = "GL|B"
	spawner_gps_id = "Goliath Burrow"

/obj/structure/spawner/abyss/lavaland/watcher
	name = "watcher nest"
	desc = "An eerie rift that seems to watch you back. Cold despite the surrounding lava."
	mob_types = list(/mob/living/basic/mining/watcher)
	mob_gps_id = "WT|N"
	spawner_gps_id = "Watcher Nest"

/obj/structure/spawner/abyss/lavaland/legion
	name = "legion pit"
	desc = "A writhing mass of skulls can be seen just below the surface. They hunger."
	mob_types = list(/mob/living/basic/mining/legion/spawner_made)
	mob_gps_id = "LG|P"
	spawner_gps_id = "Legion Pit"

/**
 * Icemoon Abyss Spawner
 */
/obj/structure/spawner/abyss/icemoon
	name = "frozen rift"
	desc = "A crack in the ice revealing an endless void below. The cold emanating from it chills you to the bone."
	icon = 'icons/turf/floors/icechasms.dmi'
	icon_state = "icechasms-0"
	rift_light_color = LIGHT_COLOR_PURPLE
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/icemoon
	claw_effect_type = /obj/effect/temp_visual/abyss_claws/ice
	claw_color = "#4444aa"
	mob_types = list(
		/mob/living/basic/mining/watcher/icewing,
		/mob/living/basic/mining/lobstrosity,
	)
	mob_gps_id = "FRZ"
	spawner_gps_id = "Frozen Rift"

/obj/structure/spawner/abyss/icemoon/watcher
	name = "icewing hollow"
	desc = "A frigid cavern entrance. Frost patterns form and reform around its edges."
	mob_types = list(/mob/living/basic/mining/watcher/icewing)
	mob_gps_id = "WT|I"
	spawner_gps_id = "Icewing Hollow"

/obj/structure/spawner/abyss/icemoon/lobstrosity
	name = "lobstrosity burrow"
	desc = "A hole in the ice surrounded by discarded shells and bones."
	mob_types = list(/mob/living/basic/mining/lobstrosity)
	mob_gps_id = "LB|B"
	spawner_gps_id = "Lobstrosity Burrow"

/**
 * Jungle Abyss Spawner
 */
/obj/structure/spawner/abyss/jungle
	name = "overgrown rift"
	desc = "A dark pit concealed by thick jungle vegetation. Strange sounds echo from within."
	icon = 'icons/turf/floors/junglechasm.dmi'
	icon_state = "junglechasm-0"
	rift_light_color = LIGHT_COLOR_GREEN
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/jungle
	claw_effect_type = /obj/effect/temp_visual/abyss_claws/jungle
	claw_color = "#224422"
	mob_types = list(
		/mob/living/basic/mining/goliath,
	)
	mob_gps_id = "JNG"
	spawner_gps_id = "Overgrown Rift"

/*
 * ===========================================
 * GROUND AMBUSH SYSTEM
 * ===========================================
 * Invisible trigger that spawns mobs bursting from the ground when stepped on.
 * One-time use - triggers once then deletes itself.
 */

/obj/effect/mob_ambush
	name = "disturbed ground"
	desc = "The ground here looks slightly disturbed..."
	icon = 'icons/turf/floors/chasms.dmi'
	icon_state = "chasms-0"
	layer = ABOVE_OPEN_TURF_LAYER
	anchored = TRUE
	invisibility = INVISIBILITY_ABSTRACT // Hidden until triggered
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

	/// List of mob types to spawn
	var/list/mob_types = list(/mob/living/basic/zombie)
	/// How many mobs to spawn
	var/spawn_count = 1
	/// Faction for spawned mobs
	var/list/spawn_faction = list(FACTION_MINING)
	/// Has this ambush been triggered?
	var/triggered = FALSE
	/// Chance to trigger when crossed (0-100)
	var/trigger_chance = 100
	/// Emergence effect type
	var/emergence_effect_type = /obj/effect/temp_visual/abyss_emerge

/obj/effect/mob_ambush/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
	)
	AddElement(/datum/element/connect_loc, loc_connections)

/obj/effect/mob_ambush/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(triggered)
		return
	if(!isliving(arrived))
		return
	var/mob/living/victim = arrived
	if(victim.stat == DEAD)
		return
	// Don't trigger for mobs of the same faction
	if(faction_check(spawn_faction, victim.faction, FALSE))
		return
	if(!prob(trigger_chance))
		return
	triggered = TRUE
	INVOKE_ASYNC(src, PROC_REF(spring_ambush), victim)

/obj/effect/mob_ambush/proc/spring_ambush(mob/living/victim)
	var/turf/victim_turf = get_turf(victim)

	// Play emergence sound
	playsound(victim_turf, 'voidcrew/sound/mob/earthchurn.ogg', 80, TRUE)

	// Brief delay for tension
	sleep(0.2 SECONDS)

	// Find the cluster center point (4 tiles away, or closer if needed)
	var/turf/cluster_center = find_spawn_turf(victim_turf, 4)
	if(!cluster_center)
		cluster_center = victim_turf

	// Determine how many zombies to spawn (1 main + 2-4 extras = 3-5 total)
	var/extra_zombies = rand(2, 4)
	var/total_zombies = 1 + extra_zombies

	// Gather all spawn turfs within 1 tile of cluster center (tight clump)
	var/list/cluster_turfs = list(cluster_center)
	for(var/turf/T in orange(1, cluster_center))
		if(is_valid_spawn_turf(T))
			cluster_turfs += T

	// Spawn all zombies simultaneously
	for(var/i in 1 to total_zombies)
		var/turf/spawn_turf = pick(cluster_turfs)

		// Create emergence effect at spawn location
		new emergence_effect_type(spawn_turf, icon, icon_state)

		// Spawn the mob
		var/mob_type = pick(mob_types)
		var/mob/living/spawned = new mob_type(spawn_turf)
		spawned.faction = spawn_faction.Copy()

	// Play sound at cluster center
	playsound(cluster_center, 'voidcrew/sound/mob/earthchurn.ogg', 70, TRUE)

	// Flavor text about being alerted
	var/alert_message = pick(
		"Your footsteps disturbed something beneath the surface...",
		"The ground trembles as something stirs below!",
		"You feel the earth shift beneath your feet!",
		"Something heard you coming...",
		"The dead have been awakened by your presence!",
		"Your movement has attracted unwanted attention...",
		"They were waiting just beneath the surface...",
	)
	to_chat(victim, span_userdanger(alert_message))

	// Alert message
	visible_message(span_userdanger("Creatures burst from the ground!"))

	// Clean up
	qdel(src)

/// Find a valid spawn turf, starting at max_dist tiles away and decreasing until one is found
/obj/effect/mob_ambush/proc/find_spawn_turf(turf/center, max_dist = 4)
	for(var/dist in max_dist to 1 step -1)
		var/list/valid_turfs = list()
		for(var/turf/T in orange(dist, center))
			if(get_dist(center, T) != dist)
				continue
			if(is_valid_spawn_turf(T))
				valid_turfs += T
		if(length(valid_turfs))
			return pick(valid_turfs)
	return null

/// Check if a turf is valid for spawning
/obj/effect/mob_ambush/proc/is_valid_spawn_turf(turf/T)
	if(T.density)
		return FALSE
	for(var/obj/O in T)
		if(O.density)
			return FALSE
	return TRUE

/**
 * Lavaland ground ambush
 */
/obj/effect/mob_ambush/lavaland
	icon = 'icons/turf/floors/chasms.dmi'
	icon_state = "chasms-0"
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/lavaland

/**
 * Icemoon ground ambush
 */
/obj/effect/mob_ambush/icemoon
	icon = 'icons/turf/floors/icechasms.dmi'
	icon_state = "icechasms-0"
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/icemoon

/**
 * Jungle ground ambush
 */
/obj/effect/mob_ambush/jungle
	icon = 'icons/turf/floors/junglechasm.dmi'
	icon_state = "junglechasm-0"
	emergence_effect_type = /obj/effect/temp_visual/abyss_emerge/jungle
