// Hyperviolence blood part: directional blood spray.
//
// Art: icons/blood_spray.dmi holds the squirt_greyscale, splatter_greyscale and
// splatterbloodalt_greyscale states copied from Azure Peak (Azure-Peak/Azure-Peak at commit
// 023a346, icons/effects/blood.dmi), licensed CC BY-SA 3.0.
// Code: the spray line, wall splatter and drench are adapted from the same repository's
// code/modules/mob/living/blood.dm (blood_spray, blood_squirt, drench, add_splatter_wall),
// licensed AGPL-3.0. tg's flying hitsplatter is left alone; a hit that already threw one this
// tick does not throw a second spray.

/mob/living
	/// World time before which this mob will not throw another spray, unless it is a stronger one.
	var/hv_blood_spray_until = 0
	/// How far the last spray reached, so a stronger one inside the window can still go.
	var/hv_blood_spray_strength = 0
	/// The tick tg's own wound spray last fired from this mob, so one hit does not spray twice.
	var/hv_blood_tg_spray_tick = -1
	/// Direction of the last brute hit this mob took, and when.
	var/hv_blood_hit_dir = 0
	var/hv_blood_hit_time = -100000
	/// World time before which this mob is not told again that blood spattered across it.
	var/hv_blood_drench_until = 0

/mob/living/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/hv_blood_hooks)

/// Listens for hits and lost limbs on a mob and sprays its blood. An element rather than the mob
/// registering on itself: a mob holds one handler per signal per listener, so a self-registration
/// would replace (or be replaced by) the mob's own handlers for the same signals.
/datum/element/hv_blood_hooks

/datum/element/hv_blood_hooks/Attach(datum/target)
	. = ..()
	if(!isliving(target))
		return ELEMENT_INCOMPATIBLE
	RegisterSignal(target, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_damaged))
	if(iscarbon(target))
		RegisterSignal(target, COMSIG_CARBON_REMOVE_LIMB, PROC_REF(on_limb_removed))

/datum/element/hv_blood_hooks/Detach(datum/source)
	UnregisterSignal(source, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_CARBON_REMOVE_LIMB))
	return ..()

/datum/element/hv_blood_hooks/proc/on_damaged(mob/living/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	source.hv_blood_on_damaged(source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)

/datum/element/hv_blood_hooks/proc/on_limb_removed(mob/living/carbon/source, obj/item/bodypart/removed_limb, special, dismembered)
	SIGNAL_HANDLER
	source.hv_blood_on_limb_removed(source, removed_limb, special, dismembered)

/// A fan of blood flung across a floor tile, facing the way it flew.
/obj/effect/decal/cleanable/blood/hv_spray
	name = "blood splatter"
	icon = HV_BLOOD_SPRAY_ICON
	icon_state = "splatter_greyscale"
	random_icon_states = list("splatter_greyscale", "splatterbloodalt_greyscale")
	// One per tile and direction: the spray helper refreshes an existing one instead of stacking.
	mergeable_decal = FALSE
	// Thin enough that walking through it does not leave footprints.
	bloodiness = 15
	drying_time = 3 MINUTES
	beauty = -30
	base_name = null
	base_suffix = "splatter"

/// Turns the decal to the way the blood flew.
/obj/effect/decal/cleanable/blood/hv_spray/proc/hv_aim(spray_dir)
	setDir(spray_dir)

// Too thin to dive into.
/obj/effect/decal/cleanable/blood/hv_spray/can_bloodcrawl_in()
	return FALSE

/// A thin streak of blood along the floor, the part of the line before the final splash.
/obj/effect/decal/cleanable/blood/hv_spray/streak
	name = "blood streak"
	icon_state = "squirt_greyscale"
	random_icon_states = null
	base_suffix = "streak"

/// Blood on the face of a wall or window. Sits on the floor tile in front of it, drawn onto the obstruction.
/obj/effect/decal/cleanable/blood/hv_spray/wall
	plane = GAME_PLANE
	layer = ABOVE_WINDOW_LAYER
	alpha = 200

/obj/effect/decal/cleanable/blood/hv_spray/wall/hv_aim(spray_dir)
	. = ..()
	pixel_x = 0
	pixel_y = 0
	if(spray_dir & NORTH)
		pixel_y = 32
	else if(spray_dir & SOUTH)
		pixel_y = -32
	if(spray_dir & EAST)
		pixel_x = 32
	else if(spray_dir & WEST)
		pixel_x = -32

/// tg's wound spray: note the tick, so the heavy-hit spray does not add a second one to the same hit.
/mob/living/carbon/spray_blood(splatter_direction, splatter_strength = 3)
	hv_blood_tg_spray_tick = world.time
	return ..()

/// Whether a spray stops at this tile: walls, windows and closed doors.
/proc/hv_blood_spray_blocked(turf/next)
	if(isclosedturf(next))
		return TRUE
	for(var/obj/blocker in next)
		if(!blocker.density)
			continue
		if(istype(blocker, /obj/structure/window) || istype(blocker, /obj/machinery/door) || istype(blocker, /obj/structure/falsewall))
			return TRUE
	return FALSE

/// Lays one spray decal on a floor tile, or turns the one already there. Returns it.
/proc/hv_blood_lay_spray(turf/target, decal_type, spray_dir, list/blood_dna, list/viruses)
	for(var/obj/effect/decal/cleanable/blood/hv_spray/existing in target)
		// A tile holds one floor spray, whatever shape it came in; wall smears are kept apart.
		if(istype(existing, /obj/effect/decal/cleanable/blood/hv_spray/wall) || existing.dried || QDELETED(existing))
			continue
		existing.add_blood_DNA(blood_dna, viruses)
		existing.hv_aim(spray_dir)
		return existing
	var/obj/effect/decal/cleanable/blood/hv_spray/fresh = new decal_type(target, viruses, blood_dna)
	if(QDELETED(fresh))
		return null
	fresh.hv_aim(spray_dir)
	return fresh

/**
 * Throws blood from src towards spray_dir: streaks along the floor, a splash at the end, a smear
 * on the first wall in the way, and anyone standing in the line is drenched. The hook the other
 * hyperviolence parts call for a spray; hit and dismember triggers are at the bottom of this file.
 *
 * spray_dir is the way the blow or shot travelled, away from the attacker. strength is how many
 * tiles the line reaches; big sprays also throw two flanking lines.
 * Returns TRUE if anything was sprayed.
 */
/mob/living/proc/hv_blood_throw(spray_dir, strength = 3)
	if(QDELETED(src) || !isturf(loc))
		return FALSE
	if(can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return FALSE
	strength = clamp(round(strength), 1, HV_BLOOD_MAX_RANGE)
	if(world.time < hv_blood_spray_until && strength <= hv_blood_spray_strength)
		return FALSE
	hv_blood_spray_until = world.time + HV_BLOOD_SPRAY_WINDOW
	hv_blood_spray_strength = strength
	if(!spray_dir)
		spray_dir = pick(GLOB.alldirs)

	var/list/blood_dna = get_blood_dna_list()
	var/list/viruses = get_static_viruses()
	var/list/drenched = list()
	hv_blood_spray_line(spray_dir, strength, blood_dna, viruses, drenched)
	if(strength >= HV_BLOOD_FAN_STRENGTH)
		hv_blood_spray_line(turn(spray_dir, 45), strength - 1, blood_dna, viruses, drenched)
		hv_blood_spray_line(turn(spray_dir, -45), strength - 1, blood_dna, viruses, drenched)
	for(var/mob/living/splashed as anything in drenched)
		splashed.hv_blood_drench(blood_dna, viruses)
	return TRUE

/// One line of spray out from src. Mobs it reaches are added to drenched. Returns TRUE if it hit a wall.
/mob/living/proc/hv_blood_spray_line(spray_dir, tiles, list/blood_dna, list/viruses, list/drenched)
	var/turf/current = get_turf(src)
	for(var/step in 1 to tiles)
		var/turf/next = get_step(current, spray_dir)
		if(!next)
			return FALSE
		if(hv_blood_spray_blocked(next))
			hv_blood_lay_wall_spray(current, spray_dir, blood_dna, viruses)
			return TRUE
		current = next
		var/mob/living/in_the_way = locate() in current
		if(in_the_way)
			if(!(in_the_way in drenched))
				drenched += in_the_way
			return FALSE
		if(isgroundlessturf(current))
			continue
		if(!current.has_gravity())
			// With nothing to pull it down the blood hangs in the air; the floating blood part takes over.
			new /obj/effect/decal/cleanable/blood(current, viruses, blood_dna)
			continue
		hv_blood_lay_spray(current, step < tiles ? /obj/effect/decal/cleanable/blood/hv_spray/streak : /obj/effect/decal/cleanable/blood/hv_spray, spray_dir, blood_dna, viruses)
	return FALSE

/// Blood on whatever blocks the spray, drawn from the floor tile in front of it.
/mob/living/proc/hv_blood_lay_wall_spray(turf/floor, spray_dir, list/blood_dna, list/viruses)
	if(isclosedturf(floor) || isgroundlessturf(floor))
		return
	for(var/obj/effect/decal/cleanable/blood/hv_spray/wall/existing in floor)
		if(existing.dir != spray_dir || existing.dried || QDELETED(existing))
			continue
		existing.add_blood_DNA(blood_dna, viruses)
		return existing
	var/obj/effect/decal/cleanable/blood/hv_spray/wall/fresh = new(floor, viruses, blood_dna)
	if(QDELETED(fresh))
		return null
	fresh.hv_aim(spray_dir)
	return fresh

/// Blood across this mob and what it wears, through the usual forensics path.
/mob/living/proc/hv_blood_drench(list/blood_dna, list/viruses)
	if(QDELETED(src) || !length(blood_dna))
		return
	add_blood_DNA(blood_dna, viruses)
	if(world.time < hv_blood_drench_until)
		return
	hv_blood_drench_until = world.time + 3 SECONDS
	to_chat(src, span_warning("Blood spatters across you."))

/// Big brute hits throw blood the way they travelled.
/mob/living/proc/hv_blood_on_damaged(datum/source, damage_dealt, damagetype, def_zone, blocked, wound_bonus, exposed_wound_bonus, sharpness, attack_direction, attacking_item, wound_clothing)
	SIGNAL_HANDLER
	if(damagetype != BRUTE || !attack_direction)
		return
	// Remembered for any limb this hit takes off a moment later.
	hv_blood_hit_dir = attack_direction
	hv_blood_hit_time = world.time
	if(damage_dealt < HV_BLOOD_MIN_HIT)
		return
	if(hv_blood_tg_spray_tick == world.time || world.time < hv_blood_spray_until)
		return
	if(blood_volume <= BLOOD_VOLUME_BAD || !isturf(loc))
		return
	if(isbodypart(def_zone))
		var/obj/item/bodypart/hit_part = def_zone
		if(!hit_part.can_bleed())
			return
	// A hard hit always sprays; a glancing one sometimes does. A body already down is hit less wetly.
	var/chance = clamp((damage_dealt - 8) * 4, 0, 100)
	if(stat == DEAD)
		chance *= 0.5
	if(!prob(chance))
		return
	hv_blood_throw(attack_direction, round(damage_dealt / HV_BLOOD_DAMAGE_PER_TILE))

/// The way the last brute hit travelled if it landed a moment ago, else null.
/mob/living/proc/hv_blood_recent_hit_dir()
	if(world.time - hv_blood_hit_time <= HV_BLOOD_HIT_MEMORY)
		return hv_blood_hit_dir

/// A limb torn off sprays the way the blow that took it travelled.
/mob/living/carbon/proc/hv_blood_on_limb_removed(datum/source, obj/item/bodypart/removed_limb, special, dismembered)
	SIGNAL_HANDLER
	if(special || !dismembered || !removed_limb.can_bleed())
		return
	var/spray_dir = (world.time - hv_blood_hit_time <= HV_BLOOD_HIT_MEMORY) ? hv_blood_hit_dir : pick(GLOB.alldirs)
	hv_blood_throw(spray_dir, HV_BLOOD_DISMEMBER_STRENGTH)
