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
 */
/obj/machinery/porta_turret/ship_defense/proc/allowed_operator(mob/user)
	if(isAdminGhostAI(user))
		return TRUE
	var/area/shuttle/voidcrew/ship_area = get_area(src)
	if(!istype(ship_area))
		return TRUE // Workshop floor, outpost, ruin - nobody's ship, nobody's lock.
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
		balloon_alert(user, "controls locked to crew!")
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
 * of feedback, since a crew would think they had secured the gun. Every other branch of the
 * parent (crowbar salvage, wrench bolts) is left alone.
 */
/obj/machinery/porta_turret/ship_defense/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(!(machine_stat & BROKEN) && attacking_item.GetID())
		balloon_alert(user, "no card reader")
		to_chat(user, span_notice("[src] has no card reader. Its controls answer to the crew of the ship it is bolted to."))
		return TRUE
	return ..()

/// Alt-click toggles wildlife targeting, leaving the turret watching for boarders only.
/obj/machinery/porta_turret/ship_defense/click_alt(mob/user)
	if(machine_stat & BROKEN)
		balloon_alert(user, "it's wrecked!")
		return CLICK_ACTION_BLOCKING
	if(!allowed_operator(user))
		balloon_alert(user, "controls locked to crew!")
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

/// This creature's AI goes looking for something to attack.
#define SHIP_TURRET_AI_AGGRESSIVE (1<<0)
/// It picks a target only to run away from it.
#define SHIP_TURRET_AI_SKITTISH (1<<1)
/// It only fights back once something has started on it.
#define SHIP_TURRET_AI_PROVOKED (1<<2)
/// Depth guard on the tree walk: a malformed (or cyclic) tree must not hang the sweep.
/// Generous, because a subtree that binds subtrees into its slots stacks up quickly - the
/// carp tree reaches its target-picking leaf around a dozen levels below the controller.
#define SHIP_TURRET_BT_MAX_DEPTH 32

// The 2026 upstream merge replaced planning_subtrees with compiled behavior trees, so the
// three buckets below name BT node types and the walker further down reads the live tree
// instead of a flat subtree list. Same question either way: does this creature's AI go
// looking for a fight, only answer one, or just run?
//
// Naming the reusable /subtree wrappers is not enough on its own. Roughly half the roster -
// the bear, the goliath, the carp and every trooper among them - has its target acquisition
// written straight into its own .bt.json as an `acquire_target` leaf rather than pulled in
// as a shared subtree, so a subtree-only sweep classified all of them as harmless and the
// turret held fire on the exact creatures it is bolted to the hull for. The leaf behaviours
// are listed alongside the subtrees for that reason; typecacheof() covers their subtypes
// (update_combat_targets/nearest, /prioritize_trait, /most_wounded).

/// Behavior-tree nodes that mean "this creature goes looking for something to attack".
GLOBAL_LIST_INIT(ship_turret_aggressive_nodes, typecacheof(list(
	/datum/bt_node/ai_behavior/acquire_target/update_combat_targets,
	/datum/bt_node/subtree/basic_find_target,
	/datum/bt_node/subtree/simple_hostile_combat,
	/datum/bt_node/subtree/simple_ranged_combat,
	/datum/bt_node/subtree/simple_ability_combat,
	/datum/bt_node/subtree/move_to_and_hunt,
	/datum/bt_node/subtree/dog_harassment,
)))

/// Nodes that pick a target only to run away from it. Checked first, because the fearful
/// combat subtrees sit under the same families as the aggressive ones and typecacheof()
/// covers subtypes.
GLOBAL_LIST_INIT(ship_turret_fleeing_nodes, typecacheof(list(
	/datum/bt_node/subtree/run_away_from_target,
	/datum/bt_node/subtree/simple_fearful_combat,
)))

/// Nodes that only pick a fight once something has already picked one with them.
GLOBAL_LIST_INIT(ship_turret_retaliating_nodes, typecacheof(list(
	/datum/bt_node/ai_behavior/acquire_target/target_from_retaliate_list,
	/datum/bt_node/subtree/pick_retaliate_target,
	/datum/bt_node/subtree/capricious_pick_target,
	/datum/bt_node/subtree/forage_and_retaliate,
	/datum/bt_node/subtree/simple_hostile_combat_with_retaliate,
	/datum/bt_node/subtree/simple_ranged_retaliate_combat,
	/datum/bt_node/subtree/simple_ability_retaliate_combat,
)))

/**
 * Classifies a controller's compiled behavior tree: does its AI go looking for a fight, only
 * answer one, or just run?
 *
 * Composites hold `children`, decorators a single `child`, and a subtree node its own `root`,
 * so a flat scan of `behavior_nodes` would only ever see the top of the tree - the
 * target-picking nodes this turret cares about usually sit several levels down, and on a
 * subtree that binds its slots at the call site (the carp tree binds four) deeper still.
 * The descent goes through `get_children()` rather than an istype ladder so it follows
 * whatever the node kind actually exposes, an installed subtree override included. An
 * unresolved subtree root (nothing has ticked that controller yet) is skipped rather than
 * built: a turret sweep is not the place to compile somebody's AI.
 *
 * Returns a bitfield of SHIP_TURRET_AI_* flags.
 */
/proc/ship_turret_classify_bt(datum/bt_node/node, depth = 0)
	if(isnull(node) || depth > SHIP_TURRET_BT_MAX_DEPTH)
		return NONE
	. = NONE
	if(GLOB.ship_turret_fleeing_nodes[node.type])
		. |= SHIP_TURRET_AI_SKITTISH
	else if(GLOB.ship_turret_aggressive_nodes[node.type])
		. |= SHIP_TURRET_AI_AGGRESSIVE
	else if(GLOB.ship_turret_retaliating_nodes[node.type])
		. |= SHIP_TURRET_AI_PROVOKED

	for(var/datum/bt_node/child as anything in node.get_children())
		. |= ship_turret_classify_bt(child, depth + 1)

/**
 * Would this creature's own targeting strategy ever pick a person-sized mob?
 *
 * Stoats and crabs hunt, but only things strictly smaller than themselves - mice, roaches.
 * They cannot lay a finger on the crew and are not what the turret is out here for. This
 * mirrors /datum/targeting_strategy/basic/of_size/can_attack() with the target's size
 * pinned to a person's, so it stays honest if that strategy gains more variants.
 */
/obj/machinery/porta_turret/ship_defense/proc/threatens_people(mob/living/creature)
	var/datum/targeting_strategy/basic/of_size/sizer = GET_TARGETING_STRATEGY(creature.ai_controller?.blackboard[BB_TARGETING_STRATEGY])
	if(!istype(sizer)) // Anything not size-gated will take a swing at whatever it can reach.
		return TRUE
	if(sizer.inclusive && creature.mob_size == MOB_SIZE_HUMAN)
		return TRUE
	if(creature.mob_size > MOB_SIZE_HUMAN)
		return sizer.find_smaller
	return !sizer.find_smaller

/**
 * Would this creature start a fight on its own?
 *
 * A goat, a goose, an ant or a stoat has teeth and will use them if you shove it, but it
 * is not a threat to a landed ship and the turret has no business shooting it. What makes
 * something a threat is how its AI picks targets, not how hard it hits - a ranged trooper
 * with no melee attack at all is exactly what these are for.
 *
 * Read off the live behavior tree rather than the mob's type, so a controller that inherits
 * its tree from a parent (the viscerator, most of the trooper tree) still classifies
 * correctly.
 */
/obj/machinery/porta_turret/ship_defense/proc/is_hostile_creature(mob/living/creature)
	// The /hostile branch of the old simple animal tree is aggressive by definition; its
	// retaliate-only subtypes were all moved over to /mob/living/basic long ago.
	if(istype(creature, /mob/living/simple_animal/hostile))
		return TRUE

	// Somebody's pet, whatever its AI says. Cats and foxes both carry a full hunting
	// subtree - the cat's is for squabbling over territory with other cats - and would
	// otherwise read as aggressive.
	if(istype(creature, /mob/living/basic/pet))
		return FALSE

	if(!threatens_people(creature))
		return FALSE

	var/datum/ai_controller/controller = creature.ai_controller
	if(!controller)
		return FALSE

	var/ai_shape = NONE
	for(var/datum/bt_node/node as anything in controller.behavior_nodes)
		ai_shape |= ship_turret_classify_bt(node)
	var/skittish = ai_shape & SHIP_TURRET_AI_SKITTISH
	var/provoked = ai_shape & SHIP_TURRET_AI_PROVOKED
	if((ai_shape & SHIP_TURRET_AI_AGGRESSIVE) && !skittish)
		return TRUE

	// Retaliators are left alone until they have actually settled on someone to maul, at
	// which point they are as much of a problem as anything else out there. Skittish mobs
	// are excluded because some of them park what they are running away from in the same
	// blackboard key an attacker would go in.
	return provoked && !skittish && !isnull(controller.blackboard[BB_CURRENT_TARGET])

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
	if(!target_wildlife && !istype(creature, /mob/living/basic/trooper))
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
	. += span_notice("Click the housing to switch it on or off, or alt-click it to toggle wildlife targeting. The controls only answer to the crew of the ship it is bolted to.")

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
#undef SHIP_TURRET_AI_AGGRESSIVE
#undef SHIP_TURRET_AI_SKITTISH
#undef SHIP_TURRET_AI_PROVOKED
#undef SHIP_TURRET_BT_MAX_DEPTH
