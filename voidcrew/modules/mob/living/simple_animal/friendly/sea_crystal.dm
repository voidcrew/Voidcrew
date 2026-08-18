/**
 * The beach worlds' spawning nexus, ported from Voidcrew-LRP's
 * `/obj/structure/spawner/sea_crystal`: a structure that keeps a couple of sharks
 * in the water around it and answers being broken into with telegraphed waves of
 * crystal hivelords. Breaking it drops the sea crystal item, which Barnaby buys
 * and which hard outpost contracts ask for - see
 * voidcrew/modules/trade/shop_catalog_general.dm.
 *
 * Changes forced by the modern codebase: the `sleep()` telegraph in
 * summon_minions() is an addtimer chain now so an attacker doesn't have their
 * click chain slept for three and a half seconds, the drop hook is
 * handle_deconstruct() because `/obj/deconstruct` is SHOULD_NOT_OVERRIDE, and the
 * spawned sharks are the basic-mob beach carp.
 *
 * LRP's numbers are deliberately not kept. LRP ran `spawn_time = 10` deciseconds
 * and the spawner component frees a slot the instant a mob dies, so a cleared
 * shark was back one second later and the water around the crystal was never
 * empty. On top of that every point of damage to a 1350 integrity structure fed
 * one shared twenty second timer that dropped three hivelords, and a hivelord
 * spits an extra brood every time it is hit. A fight that long against a faucet
 * that fast can only end in a carpet of mobs.
 *
 * So the crystal now has a fixed, finite number of waves in it, they land at
 * fixed points in the fight (see summon_thresholds) rather than on a timer that
 * runs for as long as the fight does, and it will not add to the field while the
 * hivelords it already summoned are still alive.
 */
/obj/structure/spawner/sea_crystal
	name = "sea crystal"
	desc = "A large crystal. Terrible monsters are pouring out from all around it."
	icon = 'voidcrew/icons/obj/seacrystal.dmi'
	icon_state = "seacrystal"
	faction = list(FACTION_BEACH)
	max_mobs = 2
	spawn_time = 45 SECONDS
	max_integrity = 600
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
	/// Fractions of max_integrity that each set off one hivelord wave, highest first.
	/// Consumed as they are crossed, so this list is also the total wave count.
	var/list/summon_thresholds = list(0.75, 0.5, 0.25)
	/// How many hivelords a single wave lands.
	var/summon_count = 2
	/// A wave is skipped outright while this many of our own hivelords are alive.
	var/max_live_hivelords = 3
	/// Minimum gap between waves, so one big hit can't cash in every threshold at once.
	var/cooldown_time = 20 SECONDS
	/// Hivelords this crystal put on the field which are still up.
	var/list/live_hivelords = list()
	var/newcolor = "#1302ad"

	COOLDOWN_DECLARE(summon_cooldown)

/obj/structure/spawner/sea_crystal/Initialize(mapload)
	. = ..()
	for(var/turf/adjacent in RANGE_TURFS(1, src))
		if(ismineralturf(adjacent))
			var/turf/closed/mineral/mineral = adjacent
			mineral.ScrapeAway(flags = CHANGETURF_IGNORE_AIR)
	RegisterSignal(src, COMSIG_ATOM_INTEGRITY_CHANGED, PROC_REF(on_integrity_changed))

/obj/structure/spawner/sea_crystal/Destroy()
	for(var/mob/living/hivelord as anything in live_hivelords)
		if(QDELETED(hivelord))
			continue
		UnregisterSignal(hivelord, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	live_hivelords = null
	return ..()

/obj/structure/spawner/sea_crystal/handle_deconstruct(disassembled)
	playsound(loc, 'sound/effects/tendril_destroyed.ogg', 100, FALSE, 20, TRUE)
	new /obj/effect/temp_visual/seacrystal/sparks(loc)
	new /obj/item/sea_crystal(loc)
	return ..()

/**
 * Waves are keyed off how broken the crystal is rather than off being hit, which
 * is what makes the total finite: three thresholds, three waves, however long the
 * fight takes. Crossing more than one threshold inside the wave cooldown spends
 * them all for a single wave, so burst damage is rewarded instead of punished.
 */
/obj/structure/spawner/sea_crystal/proc/on_integrity_changed(datum/source, old_value, new_value)
	SIGNAL_HANDLER
	if(new_value >= old_value || !length(summon_thresholds))
		return
	if(new_value <= 0)
		return // The blow that breaks it doesn't get to answer back.
	var/remaining = new_value / max_integrity
	var/crossed = FALSE
	while(length(summon_thresholds) && remaining <= summon_thresholds[1])
		summon_thresholds.Cut(1, 2)
		crossed = TRUE
	if(crossed)
		summon_minions()

/obj/structure/spawner/sea_crystal/proc/summon_minions()
	if(QDELETED(src) || !COOLDOWN_FINISHED(src, summon_cooldown))
		return
	live_hivelords -= null // A hard deleted mob nulls its list entries in place.
	if(length(live_hivelords) >= max_live_hivelords)
		return

	// LRP picked landing spots with three overlapping pick()s - pick(EAST, NORTHEAST)
	// and pick(NORTHEAST, WEST) could both land on NORTHEAST, and nothing checked
	// whether the turf was a wall. Take real open neighbours instead.
	var/turf/center = get_turf(src)
	var/list/summon_turfs = list()
	for(var/turf/candidate as anything in shuffle(RANGE_TURFS(1, center) - center))
		if(candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		summon_turfs += candidate
		if(length(summon_turfs) >= summon_count)
			break
	if(!length(summon_turfs))
		return

	COOLDOWN_START(src, summon_cooldown, cooldown_time)
	crystal_power()
	addtimer(CALLBACK(src, PROC_REF(summon_telegraph), summon_turfs), 2.5 SECONDS)

/// Sparks and camera shake, one second before the hivelords actually land.
/obj/structure/spawner/sea_crystal/proc/summon_telegraph(list/summon_turfs)
	if(QDELETED(src))
		return
	for(var/mob/mob in range(10, src))
		if(mob.client)
			shake_camera(mob, 2, 1)
	playsound(loc, 'sound/effects/magic/exit_blood.ogg', 70, TRUE)
	for(var/turf/summon_turf as anything in summon_turfs)
		new /obj/effect/temp_visual/seacrystal/sparks(summon_turf)
		new /obj/effect/temp_visual/seacrystal/arrival(summon_turf)
	addtimer(CALLBACK(src, PROC_REF(summon_hivelords), summon_turfs), 1 SECONDS)

/obj/structure/spawner/sea_crystal/proc/summon_hivelords(list/summon_turfs)
	if(QDELETED(src))
		return
	for(var/turf/summon_turf as anything in summon_turfs)
		var/mob/living/basic/mining/hivelord/beach/hivelord = new(summon_turf)
		live_hivelords += hivelord
		RegisterSignals(hivelord, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_hivelord_gone))
	crystal_depower()

/// Free the slot on death rather than on deletion - a corpse is not a threat.
/obj/structure/spawner/sea_crystal/proc/on_hivelord_gone(datum/source)
	SIGNAL_HANDLER
	live_hivelords -= source
	UnregisterSignal(source, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))

/obj/structure/spawner/sea_crystal/proc/crystal_power()
	playsound(loc, 'sound/effects/magic/clockwork/narsie_attack.ogg', 70, TRUE)
	add_atom_colour(newcolor, TEMPORARY_COLOUR_PRIORITY)
	for(var/i in 1 to 8)
		new /obj/effect/temp_visual/seacrystal/sparks(get_step(src, i))

/obj/structure/spawner/sea_crystal/proc/crystal_depower()
	remove_atom_colour(TEMPORARY_COLOUR_PRIORITY, newcolor)

/obj/effect/temp_visual/seacrystal
	icon = 'voidcrew/icons/effects/crystal_effects.dmi'
	randomdir = FALSE
	duration = 1 SECONDS

/obj/effect/temp_visual/seacrystal/sparks
	name = "sea sparks"
	icon_state = "sparkles"
	randomdir = TRUE

/// Plays on a landing tile during the windup, before a hivelord occupies it.
/obj/effect/temp_visual/seacrystal/arrival
	name = "sea rift"
	duration = 1.2 SECONDS
	icon_state = "dustin"

/**
 * The reward for breaking the structure. It is a trade good and nothing else:
 * Barnaby's Trapper & Angler counter buys it and hard outpost contracts request
 * it. LRP had crushing it teach Great Crystal Form, a shapeshift into a crystal
 * that carried Voice of God, a jaunt and a hivelord summon; that whole package is
 * gone, along with the shapeshift mob and the two spell subtypes only it used.
 */
/obj/item/sea_crystal
	name = "sea crystal"
	desc = "A shard of the spawning nexus that grows on the beach worlds' ocean floor. Cold to the touch and still faintly humming. Worth a great deal to the right buyer, and nothing at all to anyone else."
	icon = 'voidcrew/icons/obj/lavaland/newlavalandplants.dmi'
	icon_state = "unnamed_crystal"
	color = COLOR_DARK_CYAN
	w_class = WEIGHT_CLASS_SMALL
