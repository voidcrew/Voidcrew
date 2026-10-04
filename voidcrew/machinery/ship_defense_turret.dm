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
		recognises hostile wildlife and boarding parties, and the emitter is detuned so its \
		beams pass through people entirely. The housing is thin enough that anything with \
		claws can wreck it in a few swings, but a welder puts it back together."
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

	// Deliberately NOT FACTION_NEUTRAL, which the station turrets carry. FACTION_NEUTRAL is
	// the default on /mob, so every creature that never bothered to set a faction - bears,
	// polar bears, migos, geese, ants - would count as friendly. That cuts both ways through
	// in_faction(): the turret refuses to shoot them, and both AI targeting paths refuse to
	// let them fight back, so the turret is invulnerable to exactly the wildlife it exists
	// to shoot. Bots and other turrets are still spared by the two silicon factions, and
	// FACTION_STATION covers the crew's own hardware - only the minebot and the node drone
	// carry it, and both hunt fauna alongside the turret rather than against it.
	faction = list(FACTION_STATION, FACTION_SILICON, FACTION_TURRET)

	/// Swings from a creature needed to knock this out. Each one deals a flat share of max_integrity.
	var/mob_hits_to_disable = 3
	/// How long one pass with a welder takes.
	var/repair_time = 4 SECONDS
	/// How long it takes to bolt an unanchored turret into a wall by dragging it there.
	var/mount_time = 5 SECONDS
	/// Whether the turret engages hostile wildlife. Off means it holds fire for everything
	/// except boarding parties, so the crew can farm the local fauna themselves. Toggled by
	/// alt-clicking the housing; crew of the owning ship only.
	var/target_wildlife = TRUE

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
 * May this person work the turret's controls?
 *
 * A req_access lock is a dead letter here - voidcrew/edits/ship_access.dm opens every
 * access check inside a crewed hull for whoever is standing in it, boarders included,
 * and an anti-boarding gun that boarders can switch off is not doing its job. So the
 * gate is crew membership itself: the panel answers to minds on the owning ship's
 * team, which is exactly the set of people the turret exists to protect.
 *
 * Bolted to a player outpost it answers to the outpost's members instead: its owner,
 * stewards, treasurers, residents and builders. A hull docked there keeps the ship rule,
 * since get_outpost_from_atom() finds no outpost inside a hull.
 */
/obj/machinery/porta_turret/ship_defense/proc/allowed_operator(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	var/area/shuttle/voidcrew/ship_area = get_area(src)
	if(!istype(ship_area))
		var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
		// Workshop floor, ruin, or a claim nobody holds: nobody's lock, like a derelict.
		if(isnull(home) || !home.founder_ckey)
			return TRUE
		return home.can_manage(user) || home.can_spend(user) || home.is_resident(user) || home.can_build(user)
	var/obj/structure/overmap/ship/ship = ship_area.shuttle_port?.current_ship
	if(isnull(ship))
		return TRUE
	if(ship.ai_controller) // An NPC hull's defenses answer to nobody until the hull is claimed.
		return FALSE
	if(isnull(ship.ship_team) || ship.abandoned) // A derelict is run by whoever is standing in it.
		return TRUE
	return !isnull(user.mind) && LAZYFIND(user.mind.ship_teams, ship.ship_team)

/**
 * Clicking the housing is the on/off switch. This replaces the stock station-turret
 * TGUI, whose settings (criminals, unauthorized weapons, mindshields) are all about
 * shooting people - the one thing this turret refuses to do - and whose panel players
 * reported not being able to find at all. Everything the turret can be told to do is
 * on the housing itself and spelled out in its examine text.
 */
/// No TGUI at all: every remaining path to the stock panel (ghost clicks included) dead-ends
/// here, so the housing controls in interact() and click_alt() are the whole interface.
/obj/machinery/porta_turret/ship_defense/ui_interact(mob/user, datum/tgui/ui)
	return

/obj/machinery/porta_turret/ship_defense/interact(mob/user)
	update_last_used(user)
	if(!allowed_operator(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	toggle_on(!on)
	balloon_alert(user, on ? "turret switched on" : "turret switched off")
	user.visible_message(
		span_notice("[user] switches [src] [on ? "on" : "off"]."),
		span_notice("You switch [src] [on ? "on" : "off"]."),
	)
	return TRUE

/**
 * Swiping an ID does nothing, and says so.
 *
 * The stock turret's ID branch flips `locked`, which used to gate the TGUI panel. There is
 * no panel any more and allowed_operator() decides who may work the controls, so a swipe
 * would have printed "Controls are now locked." and changed nothing at all - the worst kind
 * of feedback, since a crew would think they had secured the gun.
 *
 * The parent's other branches, unbolting a switched-off turret with a wrench and prying a
 * wrecked one apart with a crowbar, answer to allowed_operator() as the controls do, or a
 * visitor could carry off or scrap a turret that only needed switching off first.
 */
/obj/machinery/porta_turret/ship_defense/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(!(machine_stat & BROKEN) && attacking_item.GetID())
		balloon_alert(user, "no card reader")
		to_chat(user, span_notice("[src] has no card reader. Its controls answer to the crew of the ship it is bolted to, or to the members of the outpost it is bolted to."))
		return TRUE
	var/unbolting = anchored && !on && !(machine_stat & BROKEN) && attacking_item.tool_behaviour == TOOL_WRENCH
	var/salvaging = (machine_stat & BROKEN) && attacking_item.tool_behaviour == TOOL_CROWBAR
	if((unbolting || salvaging) && !allowed_operator(user))
		balloon_alert(user, "controls locked!")
		return TRUE
	return ..()

/// Saving it to a multitool links it to a turret control panel, which can switch it off from anywhere.
/obj/machinery/porta_turret/ship_defense/multitool_act(mob/living/user, obj/item/multitool/tool)
	if(!allowed_operator(user))
		balloon_alert(user, "controls locked!")
		return ITEM_INTERACT_BLOCKING
	return ..()

/// Alt-click toggles wildlife targeting, leaving the turret watching for boarders only.
/obj/machinery/porta_turret/ship_defense/click_alt(mob/user)
	if(machine_stat & BROKEN)
		balloon_alert(user, "it's wrecked!")
		return CLICK_ACTION_BLOCKING
	if(!allowed_operator(user))
		balloon_alert(user, "controls locked!")
		return CLICK_ACTION_BLOCKING
	target_wildlife = !target_wildlife
	balloon_alert(user, target_wildlife ? "targeting wildlife" : "holding fire on wildlife")
	user.visible_message(
		span_notice("[user] adjusts [src]'s targeting computer."),
		span_notice("You set [src] to [target_wildlife ? "fire on hostile wildlife and boarders" : "fire on boarding parties only"]."),
	)
	return CLICK_ACTION_SUCCESS

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
	// With wildlife targeting off the turret only watches for boarding parties, which are
	// all trooper-type humanoids (pirates and their kin). Lets the crew hunt the local
	// fauna themselves without the turret stealing every kill.
	// Escaped outpost prisoners count as boarders (outpost_prison_riot.dm).
	if(!target_wildlife && !istype(creature, /mob/living/basic/trooper) && !is_loose_outpost_prisoner(creature))
		return FALSE
	if(!is_hostile_creature(creature)) // Livestock, pets and passive fauna get left alone.
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

	if(!(machine_stat & BROKEN))
		. += span_notice("It is switched [on ? "on" : "off"], and set to fire on [target_wildlife ? "hostile wildlife and boarding parties" : "boarding parties only"].")
	. += span_notice("Click the housing to switch it on or off, or alt-click it to toggle wildlife targeting. The controls only answer to the crew of the ship it is bolted to, or to the members of the outpost it is bolted to.")

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
	// The turret is sunk into hull plating and fires along the outside of its own ship, so
	// most of what sits between the muzzle and a target is the ship itself - a corner of
	// plating on a diagonal shot, an airlock, a window, a crate someone left on the pad.
	// Phasing through all of it means the turret never burns holes in the hull it is bolted
	// to and never loses a shot to a wall the target is walking past. Nothing in this set is
	// a creature, so the crew-safety rules in can_hit_target() are unaffected.
	projectile_phasing = PASSTABLE | PASSGLASS | PASSGRILLE | PASSCLOSEDTURF | PASSMACHINE | PASSSTRUCTURE | PASSDOORS

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
