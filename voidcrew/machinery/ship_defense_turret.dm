/// portable_turret.dm #undefs its own TURRET_LETHAL at the bottom of the file, so we restate the value here.
#define SHIP_TURRET_LETHAL 1

/**
 * Hull defense turret.
 *
 * Short-ranged point defense meant to keep wildlife and boarders off a ship that has
 * put down somewhere unfriendly. It only ever engages non-player creatures, and its
 * beams pass straight through anyone else, so it cannot cross-fire into the crew or
 * into a rival ship's crew. The tradeoff is that it is flimsy - a few solid hits from
 * anything with claws will wreck it, and someone has to go outside with a welder.
 */
/obj/machinery/porta_turret/ship_defense
	name = "hull defense turret"
	desc = "A stubby laser mount bolted into the hull plating. The targeting computer only \
		recognises wildlife and boarding parties, and the emitter is detuned so its beams \
		pass through people entirely. The housing is thin enough that anything with claws \
		can wreck it in a few swings, but a welder puts it back together."
	icon_state = "standard_lethal"
	base_icon_state = "standard"
	mode = SHIP_TURRET_LETHAL

	// No cover and permanently deployed. Both AI targeting paths refuse to attack a
	// turret that is hiding under a cover, and we want mobs to be able to fight back.
	always_up = TRUE
	has_cover = FALSE

	installation = null
	uses_stored = FALSE
	use_power = NO_POWER_USE
	req_access = null
	locked = FALSE

	/// Deliberately much shorter than a station turret's 9 - this defends a doorway, not a room.
	scan_range = 4
	shot_delay = 12

	stun_projectile = /obj/projectile/beam/ship_defense
	stun_projectile_sound = 'sound/items/weapons/laser.ogg'
	lethal_projectile = /obj/projectile/beam/ship_defense
	lethal_projectile_sound = 'sound/items/weapons/laser.ogg'

	max_integrity = 100
	integrity_failure = 0.1
	armor_type = /datum/armor/machinery_ship_defense_turret

	faction = list(FACTION_NEUTRAL, FACTION_SILICON, FACTION_TURRET)

	/// Swings from a creature needed to knock this out. Each one deals a flat share of max_integrity.
	var/mob_hits_to_disable = 3
	/// How long one pass with a welder takes.
	var/repair_time = 4 SECONDS
	/// How long it takes to bolt an unanchored turret into a wall by dragging it there.
	var/mount_time = 5 SECONDS

/datum/armor/machinery_ship_defense_turret
	melee = 0 // Creature swings bypass armor entirely, see attack_generic().
	bullet = 20
	laser = 20
	energy = 20
	bomb = 20
	fire = 90
	acid = 90

/obj/machinery/porta_turret/ship_defense/Initialize(mapload)
	. = ..()
	// These are mapped into hull walls, so record which way the mapper aimed us. It is
	// only a preference - get_scan_origin() falls back if that side turns out to be solid.
	var/turf/our_turf = get_turf(src)
	if(!wall_turret_direction && our_turf?.density)
		wall_turret_direction = dir
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF | EMP_PROTECT_WIRES)

/obj/machinery/porta_turret/ship_defense/setup(obj/item/gun/turret_gun)
	return

/// Our process() never consults this, but keep it at zero so no inherited path can ever
/// talk itself into shooting a person.
/obj/machinery/porta_turret/ship_defense/assess_perp(mob/living/carbon/human/perp)
	return 0

/// Silicons hijacking a turret would let them put beams wherever they liked, including into people.
/obj/machinery/porta_turret/ship_defense/give_control(mob/controller)
	return FALSE

/**
 * Drag an unbolted turret onto an adjacent wall to mount it there.
 *
 * The stock portable-turret flow can only ever pull a turret *out* of a hull wall - a
 * turret is dense, so nothing can push or pull it back into a closed turf, and a hull
 * mount removed once was gone for good. Dragging it into the wall sidesteps the movement
 * problem entirely, and reads the way players expect.
 *
 * The turret ends up looking out the far side of the wall, i.e. the way you shoved it,
 * which is almost always the outboard side when you are standing inside your own ship.
 * If that side turns out to be solid, get_scan_origin() finds an open one anyway.
 */
/obj/machinery/porta_turret/ship_defense/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	var/turf/closed/wall = over
	if(!isclosedturf(wall))
		return

	if(anchored)
		balloon_alert(user, "unbolt it first")
		return

	var/mount_dir = get_dir(src, wall)
	if(!(mount_dir in GLOB.cardinals))
		balloon_alert(user, "move it beside the wall")
		return

	if(locate(/obj/machinery/porta_turret) in wall)
		balloon_alert(user, "already a turret there")
		return

	balloon_alert(user, "mounting...")
	if(!do_after(user, mount_time, target = src))
		return
	// Re-check: it is a long enough job that someone could have moved or bolted it.
	if(anchored || QDELETED(wall) || (locate(/obj/machinery/porta_turret) in wall))
		return

	forceMove(wall)
	setDir(mount_dir)
	wall_turret_direction = mount_dir
	set_anchored(TRUE)
	RemoveInvisibility(id = type)
	update_appearance()
	balloon_alert(user, "mounted")
	user.visible_message(
		span_notice("[user] bolts [src] into [wall]."),
		span_notice("You bolt [src] into [wall]. It still needs switching on."),
	)

/**
 * The turf the turret actually sees and fires from.
 *
 * A turret sunk into a hull wall is sitting on an opaque turf, so scanning from its own
 * location shows it almost nothing. Wall-mounted turrets scan from the tile they shoot
 * over instead, which is the same tile shootAt() picks.
 *
 * Mapped dirs are not trustworthy here - most of the hulls have `dir = 4` copy-pasted
 * onto every turret, including ones whose east side is solid hull - so a turret that
 * cannot see past its own facing falls back to any open side rather than going blind.
 */
/obj/machinery/porta_turret/ship_defense/proc/get_scan_origin()
	var/turf/our_turf = get_turf(base)
	if(!our_turf?.density)
		return our_turf

	if(wall_turret_direction)
		var/turf/muzzle = get_step(our_turf, wall_turret_direction)
		if(istype(muzzle) && !muzzle.density)
			return muzzle

	for(var/checking_dir in GLOB.cardinals)
		var/turf/muzzle = get_step(our_turf, checking_dir)
		if(istype(muzzle) && !muzzle.density)
			return muzzle

	return our_turf

/**
 * Is this something the turret is willing to shoot?
 *
 * The rule is players are never targets, full stop - not the crew, not a rival ship's
 * crew, not a ghost role riding an animal. That leaves hostile fauna and NPC boarders,
 * which is the whole job.
 */
/obj/machinery/porta_turret/ship_defense/proc/valid_target(mob/living/creature)
	if(creature.stat == DEAD)
		return FALSE
	if(creature.client || creature.mind) // Anything a player is driving, or was driving.
		return FALSE
	if(iscarbon(creature) || issilicon(creature)) // People, monkeys, xenos, borgs, pAIs.
		return FALSE
	if(creature.invisibility > SEE_INVISIBLE_LIVING)
		return FALSE
	if(in_faction(creature)) // Bots, pets and other turrets.
		return FALSE
	if(!creature.melee_damage_upper) // Passive wildlife gets left alone.
		return FALSE
	return TRUE

/obj/machinery/porta_turret/ship_defense/process()
	if(!on || (machine_stat & (NOPOWER|BROKEN)))
		return PROCESS_KILL

	var/list/targets = list()
	for(var/mob/living/creature in view(scan_range, get_scan_origin()))
		if(!valid_target(creature))
			continue
		targets += creature

	if(length(targets))
		tryToShootAt(targets)

/obj/machinery/porta_turret/ship_defense/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	// Once wrecked it stays wrecked and weldable rather than being pulped into nothing.
	if(machine_stat & BROKEN)
		return 0
	return ..()

/// Flat damage per creature swing, sized so exactly mob_hits_to_disable of them land on the break threshold.
/obj/machinery/porta_turret/ship_defense/proc/creature_hit_damage()
	return (max_integrity - (max_integrity * integrity_failure)) / mob_hits_to_disable

/obj/machinery/porta_turret/ship_defense/attack_generic(mob/user, damage_amount = 0, damage_type = BRUTE, damage_flag = 0, sound_effect = TRUE, armor_penetration = 0)
	user.do_attack_animation(src)
	user.changeNext_move(CLICK_CD_MELEE)
	// Whatever the creature hits for, the housing takes a fixed number of swings. No armor
	// flag is passed, so nothing softens it and the count stays predictable.
	return take_damage(creature_hit_damage(), BRUTE, sound_effect = sound_effect, attack_dir = get_dir(src, user))

/obj/machinery/porta_turret/ship_defense/atom_fix()
	. = ..()
	update_appearance()

/obj/machinery/porta_turret/ship_defense/welder_act(mob/living/user, obj/item/welder)
	if(atom_integrity >= max_integrity)
		balloon_alert(user, "not damaged")
		return ITEM_INTERACT_BLOCKING
	if(!welder.tool_start_check(user, amount = 1))
		return ITEM_INTERACT_BLOCKING

	balloon_alert(user, "repairing...")
	if(!welder.use_tool(src, user, repair_time, volume = 50))
		return ITEM_INTERACT_BLOCKING

	// One pass buys back one creature's worth of punishment, so a wrecked turret takes
	// as many welds to restore as it took swings to drop.
	repair_damage(creature_hit_damage())
	user.visible_message(
		span_notice("[user] welds some of the damage out of [src]."),
		span_notice("You weld [src] back to [round(get_integrity_percentage() * 100)]% integrity."),
		span_hear("You hear welding."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/porta_turret/ship_defense/examine(mob/user)
	. = ..()
	if(machine_stat & BROKEN)
		. += span_warning("It has been smashed apart. Welding the housing back together would fix it.")
	else if(atom_integrity < max_integrity)
		. += span_notice("The housing is dented and scorched. A welder would sort that out.")

	if(anchored)
		. += span_notice("It is bolted down. Switch it off and use a wrench to free it.")
	else
		. += span_notice("It is loose. Drag it onto a wall to bolt it back into the hull.")

/**
 * Turret beam.
 *
 * Phases through anyone the firing turret would not have shot at in the first place, so
 * crew and rival crew can stand in the line of fire safely - same approach as the outpost
 * enforcement laser. Dense obstacles (walls, structures) still stop it normally.
 *
 * Ricochets are off for the same reason: a bounced beam has no idea who it may hit.
 */
/obj/projectile/beam/ship_defense
	name = "defense laser"
	damage = 20
	armour_penetration = 25
	range = 7
	ricochets_max = 0
	ricochet_chance = 0
	reflectable = FALSE

/obj/projectile/beam/ship_defense/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	// Deliberately not exempting direct_target: if the thing we were aimed at stopped
	// being a legal target mid-flight (died, or a player took it over) the shot should
	// whiff rather than land. Anything else the turret WOULD shoot is still fair game,
	// so a second animal wandering into the beam still gets hit.
	if(isliving(target))
		var/obj/machinery/porta_turret/ship_defense/turret = firer
		if(!istype(turret) || !turret.valid_target(target))
			return FALSE
	return ..()

#undef SHIP_TURRET_LETHAL
