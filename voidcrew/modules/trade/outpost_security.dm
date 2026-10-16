/**
 * # Outpost Security
 *
 * The economic-deterrent enforcement arm of a trader outpost: indestructible
 * lethal turrets that engage people who attacked outpost property or another
 * visitor (plus xenos and hostile wildlife, on sight), and the indestructible
 * airlocks of the sanctuary interior.
 *
 * Aggression accrues warning strikes (see trader_outpost.register_aggression);
 * the early hits only issue a warning, and only once the offender crosses
 * OUTPOST_AGGRESSION_STRIKES is their mind marked and shot on sight.
 */

// =========================================================================
// PVP ENFORCEMENT
// =========================================================================

/**
 * NPC markets protect their entire concourse and allocated hangars, including
 * docked ship turfs. Never use a z-level check: unrelated sites share levels.
 * The area fallback also covers the concourse while its template initializes.
 * Player-founded outposts share the hangar area type but not this protection.
 */
/proc/is_trader_outpost_protected(atom/target)
	var/turf/location = get_turf(target)
	if(!location)
		return FALSE
	return istype(get_area(location), /area/voidcrew/trader_outpost) || !isnull(get_trader_outpost_for_turf(location))

/// Engine hazards transported into a market, or into a player outpost's service room, must stop before processing damage.
/proc/neutralize_trader_outpost_hazard(atom/movable/hazard)
	if(!is_trader_outpost_protected(hazard) && !is_outpost_service_tile(hazard))
		return FALSE
	log_game("OUTPOST PROTECTION: Neutralized [hazard] ([hazard.type]) at [AREACOORD(hazard)].")
	qdel(hazard)
	return TRUE

/**
 * Watches every living mob for player-on-player attacks. Whether an attack is
 * protected is resolved from the victim's turf at impact time, rather than by
 * area Entered/Exited events: admin teleports and docked ships retain their own
 * areas, so those lifecycle events cannot reliably describe who is at an
 * outpost.
 */
GLOBAL_DATUM_INIT(outpost_pvp_enforcement, /datum/outpost_pvp_enforcement, new)

/datum/outpost_pvp_enforcement/New()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_CREATED, PROC_REF(on_mob_created))
	// Usually empty this early, but covers any living globals created first.
	for(var/mob/living/living_mob as anything in GLOB.mob_living_list)
		monitor_mob(living_mob)

/datum/outpost_pvp_enforcement/proc/on_mob_created(datum/source, mob/created_mob)
	SIGNAL_HANDLER
	if(isliving(created_mob))
		monitor_mob(created_mob)

/datum/outpost_pvp_enforcement/proc/monitor_mob(mob/living/living_mob)
	RegisterSignal(living_mob, COMSIG_ATOM_AFTER_ATTACKEDBY, PROC_REF(on_outpost_pvp_item_attack))
	RegisterSignals(living_mob, list(
			COMSIG_ATOM_ATTACK_HAND,
			COMSIG_ATOM_ATTACK_PAW,
			COMSIG_MOB_ATTACK_ALIEN,
		), PROC_REF(on_outpost_pvp_unarmed_attack))
	RegisterSignals(living_mob, list(
			COMSIG_ATOM_ATTACK_BASIC_MOB,
			COMSIG_ATOM_ATTACK_ANIMAL,
		), PROC_REF(on_outpost_pvp_npc_attack))
	RegisterSignal(living_mob, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_outpost_pvp_projectile))
	RegisterSignal(living_mob, COMSIG_ATOM_PREHITBY, PROC_REF(on_outpost_pvp_thrown_item))
	RegisterSignal(living_mob, COMSIG_ATOM_HULK_ATTACK, PROC_REF(on_outpost_pvp_hulk_attack))
	RegisterSignal(living_mob, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_outpost_pvp_mech_attack))

/**
 * Checks personal self-defense before applying strikes and embargoes. Both
 * parties need minds so outpost NPCs, fauna, and ordinary interactions with
 * them retain their existing behavior.
 */
/datum/outpost_pvp_enforcement/proc/register_pvp_aggression(mob/living/victim, mob/living/offender)
	if(!victim.mind || !offender?.mind || victim == offender)
		return
	var/obj/structure/overmap/trader_outpost/guarding_outpost = get_trader_outpost_for_turf(get_turf(victim))
	guarding_outpost?.register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_item_attack(mob/living/victim, obj/item/weapon, mob/living/offender, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(weapon.force)
		register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_unarmed_attack(mob/living/victim, mob/living/offender, list/modifiers)
	SIGNAL_HANDLER
	if(offender.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_npc_attack(mob/living/victim, mob/living/offender)
	SIGNAL_HANDLER
	if(offender.melee_damage_upper > 0)
		register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_projectile(mob/living/victim, obj/projectile/hitting_projectile)
	SIGNAL_HANDLER
	if(hitting_projectile.is_hostile_projectile() && isliving(hitting_projectile.firer))
		register_pvp_aggression(victim, hitting_projectile.firer)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_thrown_item(mob/living/victim, atom/movable/hitting_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hitting_atom))
		return
	var/obj/item/thrown_item = hitting_atom
	var/mob/living/offender = throwingdatum?.get_thrower()
	if(thrown_item.throwforce && istype(offender))
		register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_hulk_attack(mob/living/victim, mob/living/offender)
	SIGNAL_HANDLER
	register_pvp_aggression(victim, offender)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_mech_attack(mob/living/victim, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	register_pvp_aggression(victim, pilot)

/obj/machinery/porta_turret/outpost
	name = "outpost defense turret"
	desc = "An over-engineered defense turret bearing a polite brass plaque: 'Violence is bad for business.'"
	installation = null
	uses_stored = FALSE // without this, process() PROCESS_KILLs over the null stored_gun and the turret never scans
	max_integrity = 500
	always_up = TRUE
	has_cover = FALSE
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	scan_range = 9
	stun_projectile = /obj/projectile/beam/laser/outpost
	lethal_projectile = /obj/projectile/beam/laser/outpost
	lethal_projectile_sound = 'sound/items/weapons/plasma_cutter.ogg'
	stun_projectile_sound = 'sound/items/weapons/plasma_cutter.ogg'
	icon_state = "syndie_off"
	base_icon_state = "syndie"
	// Players' default faction IS "neutral", including FACTION_NEUTRAL here (like
	// the pacifist centcom turrets do) would faction-exempt every player from targeting
	faction = list(FACTION_TURRET)
	mode = 1 // TURRET_LETHAL, the define is file-local to portable_turret.dm
	turret_flags = NONE

	/// The outpost this turret defends (set by the outpost on interior load)
	var/obj/structure/overmap/trader_outpost/outpost

/obj/machinery/porta_turret/outpost/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/empprotection, EMP_PROTECT_SELF | EMP_PROTECT_WIRES)

/obj/machinery/porta_turret/outpost/Destroy()
	outpost = null
	return ..()

/obj/machinery/porta_turret/outpost/setup()
	return

// No ID unlocks the controls: the inherited ACCESS_SECURITY req_access would let
// any captain or security crew swipe the enforcement offline. Keeping the swipe
// denied also keeps `on` TRUE forever, which is what blocks the wrench-unanchor
// path to walking off with an indestructible lethal turret.
/obj/machinery/porta_turret/outpost/allowed(mob/accessor)
	return FALSE

// No settings UI at all: the power toggle in ui_act() isn't gated on `locked`,
// so the panel must never open in the first place
/obj/machinery/porta_turret/outpost/ui_interact(mob/user, datum/tgui/ui)
	return

/obj/machinery/porta_turret/outpost/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/**
 * Is this something the turret is willing to shoot?
 *
 * Three kinds of target, checked in order:
 * - Anyone the outpost has barred: marked aggressors and embargoed crews. Resolved
 *   per-mind by the outpost, so it covers players riding a xeno or a spider just as
 *   well as a human with a gun.
 * - Xenomorphs, on sight. No warning strikes, no faction pass, player-driven or not;
 *   a hive does not shop here.
 * - Wild hostiles: NPC creatures whose own AI goes looking for a fight (carp, spiders,
 *   boarding troopers, ...). Judged by is_hostile_creature(), so a shopper's corgi or a
 *   pet carp is left alone. Anything with a player behind it is not a wild creature
 *   and only becomes a target through the strike ladder above.
 *
 * Everything else shops in peace.
 */
/obj/machinery/porta_turret/outpost/proc/valid_target(mob/living/creature)
	if(!istype(creature) || creature.stat == DEAD)
		return FALSE
	if(creature.invisibility > SEE_INVISIBLE_LIVING)
		return FALSE
	if(outpost?.is_turret_target(creature))
		return TRUE
	if(isalien(creature) || istype(creature, /mob/living/basic/alien)) // Player xenos and the NPC hive alike.
		return TRUE
	if(creature.client || creature.mind) // Player-driven, so the strike ladder decides, not the wildlife rule.
		return FALSE
	if(in_faction(creature)) // Traders, ambient outpost NPCs, bots and the other turrets.
		return FALSE
	if(HAS_TRAIT(creature, TRAIT_OUTPOST_RESIDENT)) // Whatever the outpost was built with.
		return FALSE
	return is_hostile_creature(creature)

// The stock scan only ever asks assess_perp() about humans; with turret_flags NONE it
// never so much as looks at an animal or a xeno. Run our own scan over every living
// mob in range instead, plus the stock mech sweep so a marked aggressor cannot hide in
// a ripley.
/obj/machinery/porta_turret/outpost/process()
	if(!on || (machine_stat & (NOPOWER|BROKEN)))
		return PROCESS_KILL

	var/list/targets = list()
	for(var/mob/living/creature in view(scan_range, base))
		if(valid_target(creature))
			targets += creature

	for(var/obj/vehicle/sealed/mecha/mech as anything in GLOB.mechas_list)
		if(get_dist(mech, base) >= scan_range || !can_see(base, mech, scan_range))
			continue
		for(var/mob/living/occupant as anything in mech.occupants)
			if(valid_target(occupant))
				targets += mech
				break

	if(length(targets))
		tryToShootAt(targets)

// Shooting the turret itself is also aggression
/obj/machinery/porta_turret/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/porta_turret/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/**
 * # Outpost Defense Laser
 *
 * Fired only by outpost turrets. Phases harmlessly through bystanders and only
 * impacts valid turret targets (marked aggressors, embargoed crew, xenos and
 * hostile wildlife) so enforcement never catches innocent shoppers in the
 * crossfire. Dense obstacles (walls, structures) still stop it as normal.
 */
/obj/projectile/beam/laser/outpost
	name = "outpost defense laser"

/obj/projectile/beam/laser/outpost/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	// Let bystanders through: skip any living mob the firing turret would not shoot at.
	// The aimed offender arrives as direct_target and any other valid target in the
	// path passes valid_target(), so both are still hit by the parent check.
	if(isliving(target) && !direct_target)
		var/obj/machinery/porta_turret/outpost/turret = firer
		if(istype(turret) && !turret.valid_target(target))
			return FALSE
	return ..()

/**
 * # Outpost Airlock
 *
 * Indestructible, always-powered sanctuary doors. Attacking one flags you.
 */
/obj/machinery/door/airlock/outpost
	name = "outpost airlock"
	desc = "A blast-rated airlock kept in better repair than most warship hulls."
	icon = 'icons/obj/doors/airlocks/external/external.dmi'
	overlays_file = 'icons/obj/doors/airlocks/external/overlays.dmi'
	use_power = NO_POWER_USE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	damage_deflection = 100
	explosion_block = 3
	hackProof = TRUE
	aiControlDisabled = AI_WIRE_DISABLED
	security_level = 6
	normal_integrity = 1000

	/// The berth host this door belongs to (set by the outpost on interior/hangar load)
	var/obj/structure/overmap/outpost

// See-through variant for storefronts that want their interior on display,
// the Chop Shop's parlor door. Same sanctuary armor, glass panes.
/obj/machinery/door/airlock/outpost/glass
	name = "outpost glass airlock"
	desc = "A blast-rated airlock with armored glass panes. You can window-shop through it; you cannot get through it any other way."
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/outpost/Destroy()
	outpost = null
	return ..()

/obj/machinery/door/airlock/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/door/airlock/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

/// Trader entrance scanners retain Guns-mode storage shielding, but never exempt an ID or mindshield.
/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint
	name = "outpost scanner"
	desc = "A sealed weapons scanner."
	base_false_beep = 0
	move_resist = INFINITY
	var/checkpoint_id
	var/datum/weakref/checkpoint_door

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/Destroy()
	var/obj/machinery/door/airlock/outpost/checkpoint/door = checkpoint_door?.resolve()
	door?.unlink_scanner(src)
	checkpoint_door = null
	return ..()

// ID swipes and emags must not unlock configuration. Tools still follow the property protection signals.
/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.GetID())
		return TRUE
	return ..()

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/emag_act(mob/user, obj/item/card/emag/emag_card)
	return FALSE

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	return FALSE

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/examine(mob/user)
	// The base scanner appends configuration instructions that do not apply to this sealed model.
	return list("[icon2html(src, user)] [name]", desc)

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/proc/checkpoint_operational()
	return !QDELETED(src) && anchored && !panel_open && !(machine_stat & (BROKEN | NOPOWER))

/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/perform_scan(atom/movable/thing)
	if(!thing || !checkpoint_operational())
		return
	// This is tg's recursive Guns search with only the personnel exemptions removed.
	var/armed = isgun(thing)
	if(!armed)
		for(var/obj/item/content in thing.get_all_contents_skipping_traits(TRAIT_CONTRABAND_BLOCKER))
			if(isgun(content))
				armed = TRUE
				break
	playsound(src, SFX_INDUSTRIAL_SCAN, 20, TRUE, -2, TRUE, FALSE)
	if(armed)
		alarm_beep("Weapons")
		SEND_SIGNAL(src, COMSIG_SCANGATE_PASS_TRIGGER, thing)
	else
		SEND_SIGNAL(src, COMSIG_SCANGATE_PASS_NO_TRIGGER, thing)
		set_scanline("scanning", 1 SECONDS)
	use_energy(active_power_usage)

/// Permission is an argument to one immediate opening call; there is no stored clean result to rebuild or reuse.
/obj/machinery/door/airlock/outpost/checkpoint
	name = "outpost checkpoint"
	desc = "An armored checkpoint door."
	move_resist = INFINITY
	var/checkpoint_id
	var/list/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/checkpoint_scanners = list()

// Match the public concourses without losing the checkpoint's scan gate.
/obj/machinery/door/airlock/outpost/checkpoint/glass
	icon = 'icons/obj/doors/airlocks/public/glass.dmi'
	overlays_file = 'icons/obj/doors/airlocks/public/overlays.dmi'
	opacity = FALSE
	glass = TRUE

// Undertow uses the same interior plating as its bar access door.
/obj/machinery/door/airlock/outpost/checkpoint/grunge
	icon = 'icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'icons/obj/doors/airlocks/centcom/overlays.dmi'
	can_be_glass = FALSE

/obj/machinery/door/airlock/outpost/checkpoint/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/door/airlock/outpost/checkpoint/Destroy()
	for(var/obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner as anything in checkpoint_scanners.Copy())
		unlink_scanner(scanner)
	return ..()

/obj/machinery/door/airlock/outpost/checkpoint/proc/link_scanner(obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner)
	var/obj/structure/overmap/trader_outpost/host = outpost
	if(!istype(host) || !host.reservation?.contains_turf(get_turf(src)) || !host.reservation.contains_turf(get_turf(scanner)))
		return FALSE
	if(!checkpoint_id || scanner.checkpoint_id != checkpoint_id || get_dist(src, scanner) != 1 || !(get_dir(src, scanner) in GLOB.cardinals))
		return FALSE
	var/obj/machinery/door/airlock/outpost/checkpoint/old_door = scanner.checkpoint_door?.resolve()
	old_door?.unlink_scanner(scanner)
	checkpoint_scanners |= scanner
	scanner.checkpoint_door = WEAKREF(src)
	RegisterSignal(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER, PROC_REF(on_clean_scan))
	return TRUE

/obj/machinery/door/airlock/outpost/checkpoint/proc/unlink_scanner(obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner)
	UnregisterSignal(scanner, COMSIG_SCANGATE_PASS_NO_TRIGGER)
	// A weakref already stops resolving once this door enters Destroy().
	if((scanner in checkpoint_scanners) || scanner.checkpoint_door?.resolve() == src)
		scanner.checkpoint_door = null
	checkpoint_scanners -= scanner

/obj/machinery/door/airlock/outpost/checkpoint/proc/on_clean_scan(obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner, atom/movable/thing)
	SIGNAL_HANDLER
	if(isliving(thing))
		INVOKE_ASYNC(src, PROC_REF(open), DEFAULT_DOOR_CHECKS, scanner, thing)

/obj/machinery/door/airlock/outpost/checkpoint/open(forced = DEFAULT_DOOR_CHECKS, obj/machinery/scanner_gate/preset_guns/outpost_checkpoint/scanner, mob/living/actor, safety_reopen = FALSE)
	if(safety_reopen)
		if(!safe || !(locate(/mob/living) in get_turf(src)))
			return FALSE
	else
		var/obj/structure/overmap/trader_outpost/host = outpost
		if(!istype(host) || !isliving(actor) || QDELETED(actor) || QDELETED(scanner) || !(scanner in checkpoint_scanners))
			return FALSE
		if(scanner.checkpoint_door?.resolve() != src || !scanner.checkpoint_operational() || scanner.checkpoint_id != checkpoint_id)
			return FALSE
		if(!host.reservation?.contains_turf(get_turf(src)) || !host.reservation.contains_turf(get_turf(scanner)))
			return FALSE
		if(actor.loc != scanner.loc || get_dist(src, scanner) != 1 || !(get_dir(src, scanner) in GLOB.cardinals) || !allowed(actor))
			return FALSE
	return ..(forced)

/obj/machinery/door/airlock/outpost/checkpoint/CheckForMobs()
	// A living obstruction arriving during the close animation must still be released.
	if(safe && (locate(/mob/living) in get_turf(src)))
		SLEEP_NOT_DEL(0.1 SECONDS)
		open(safety_reopen = TRUE)

/**
 * # Outpost Wall
 *
 * The sanctuary shell. Turfs have no back-reference to the outpost, so hits
 * resolve it through get_trader_outpost_for_turf().
 */
/turf/closed/indestructible/reinforced/titanium/outpost
	name = "outpost wall"
	desc = "Layered torpedo-rated plating. The scorch marks are from people who needed convincing."

/turf/closed/indestructible/reinforced/titanium/outpost/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && isliving(user))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(user)
	return ..()

/turf/closed/indestructible/reinforced/titanium/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

/turf/closed/indestructible/syndicate/outpost/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && isliving(user))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(user)
	return ..()

/turf/closed/indestructible/syndicate/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(isliving(hitting_projectile.firer))
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(src)
		outpost?.register_aggression(hitting_projectile.firer)
	return ..()

// =========================================================================
// OUTPOST PROPERTY
// =========================================================================

/**
 * Marks a machine or structure as outpost property: it can't be damaged,
 * unbolted, unscrewed, pried apart or stripped for parts, and hitting it is
 * aggression.
 *
 * INDESTRUCTIBLE covers damage (and the RCD, whose deconstruct mode checks the
 * flag) and nothing else, tool deconstruction never consults resistance flags,
 * which is the same trap the berth display's wrench fell into (see
 * outpost_hangar.dm). Blocking on COMSIG_ATOM_TOOL_ACT closes every route at
 * one point: that signal fires inside tool_act() ahead of
 * crowbar_act/screwdriver_act/wrench_act, and a blocking return there ends the
 * click chain before attackby ever runs, so the machines that deconstruct out
 * of attackby instead (the food processor and the deep fryer both do) need no
 * special handling here. Right clicks raise COMSIG_ATOM_SECONDARY_TOOL_ACT,
 * a separate signal, so both are blocked, tables and chairs deconstruct from
 * their _secondary tool acts.
 *
 * Attached per-type by the outpost machine subtypes, and swept over everything
 * the interior/hangar templates placed at link time, so bare tg types on the
 * maps (the door fans, seating, lockers) are covered without a subtype each.
 * Attach is guarded by TRAIT_OUTPOST_PROPERTY, so those two paths can overlap
 * in either order.
 */
/datum/element/outpost_property

/datum/element/outpost_property/Attach(datum/target)
	. = ..()
	if(!ismachinery(target) && !isstructure(target))
		return ELEMENT_INCOMPATIBLE
	if(HAS_TRAIT(target, TRAIT_OUTPOST_PROPERTY))
		return
	ADD_TRAIT(target, TRAIT_OUTPOST_PROPERTY, ELEMENT_TRAIT(type))

	// Never restored on Detach, which only ever runs at qdel
	var/obj/property = target
	property.resistance_flags |= INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	property.AddElement(/datum/element/empprotection, EMP_PROTECT_ALL)
	// The RPD's unwrench upgrade and the construction console's Remove Pipe call wrench_act()
	// directly, skipping the tool signal below; both still ask can_unwrench()
	if(istype(target, /obj/machinery/atmospherics))
		var/obj/machinery/atmospherics/atmos_part = target
		atmos_part.can_unwrench = FALSE
	// A seat dragged onto someone folds into a carried chair (chair.dm)
	if(istype(target, /obj/structure/chair))
		var/obj/structure/chair/seat = target
		seat.item_chair = null

	RegisterSignals(target, list(
		COMSIG_ATOM_TOOL_ACT(TOOL_CROWBAR),
		COMSIG_ATOM_TOOL_ACT(TOOL_SCREWDRIVER),
		COMSIG_ATOM_TOOL_ACT(TOOL_WRENCH),
		COMSIG_ATOM_TOOL_ACT(TOOL_WELDER),
		COMSIG_ATOM_TOOL_ACT(TOOL_WIRECUTTER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_CROWBAR),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_SCREWDRIVER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WRENCH),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WELDER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WIRECUTTER),
	), PROC_REF(block_tool))
	RegisterSignals(target, list(
		COMSIG_ATOM_ITEM_INTERACTION,
		COMSIG_ATOM_ITEM_INTERACTION_SECONDARY,
	), PROC_REF(block_part_replacer))

	// Deliberately NOT /datum/element/relay_attackers: its bare-hand route
	// (COMSIG_ATOM_ATTACK_HAND) reports *any* empty-handed click as a damaging
	// attack as long as combat mode is on, and attack_hand is also the click that
	// opens a machine's UI. Riding the hangar elevator with combat mode left on
	// therefore cost the rider an aggression strike per floor. Empty hands can't
	// scratch INDESTRUCTIBLE property anyway, so only the routes that carry real
	// force count here.
	RegisterSignal(target, COMSIG_ATOM_AFTER_ATTACKEDBY, PROC_REF(on_melee_attack))
	RegisterSignal(target, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(target, COMSIG_ATOM_PREHITBY, PROC_REF(on_thrown_hit))
	RegisterSignal(target, COMSIG_ATOM_HULK_ATTACK, PROC_REF(on_hulk_attack))
	RegisterSignal(target, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_mech_attack))

/// A desk bell dragged onto someone turns into a held bell (desk_bell.dm). Outpost property stays put.
/obj/structure/desk_bell/mouse_drop_dragged(atom/over_object, mob/user)
	if(HAS_TRAIT(src, TRAIT_OUTPOST_PROPERTY))
		return FALSE
	return ..()

/datum/element/outpost_property/Detach(datum/source, ...)
	UnregisterSignal(source, list(
		COMSIG_ATOM_TOOL_ACT(TOOL_CROWBAR),
		COMSIG_ATOM_TOOL_ACT(TOOL_SCREWDRIVER),
		COMSIG_ATOM_TOOL_ACT(TOOL_WRENCH),
		COMSIG_ATOM_TOOL_ACT(TOOL_WELDER),
		COMSIG_ATOM_TOOL_ACT(TOOL_WIRECUTTER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_CROWBAR),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_SCREWDRIVER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WRENCH),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WELDER),
		COMSIG_ATOM_SECONDARY_TOOL_ACT(TOOL_WIRECUTTER),
		COMSIG_ATOM_ITEM_INTERACTION,
		COMSIG_ATOM_ITEM_INTERACTION_SECONDARY,
		COMSIG_ATOM_AFTER_ATTACKEDBY,
		COMSIG_PROJECTILE_PREHIT,
		COMSIG_ATOM_PREHITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_MECH,
	))
	REMOVE_TRAIT(source, TRAIT_OUTPOST_PROPERTY, ELEMENT_TRAIT(type))
	return ..()

/datum/element/outpost_property/proc/block_tool(obj/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	source.balloon_alert(user, "outpost property!")
	return ITEM_INTERACT_BLOCKING

/**
 * A bluespace RPED skips the panel_open check in exchange_parts(), so blocking the
 * screwdriver doesn't keep the parts inside on its own. An RPD (pipe dispenser) clicked on
 * a pipe or atmos machine unwrenches, repaints or reprograms it without any tool signal.
 */
/datum/element/outpost_property/proc/block_part_replacer(obj/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	if(istype(tool, /obj/item/pipe_dispenser))
		source.balloon_alert(user, "outpost property!")
		return ITEM_INTERACT_BLOCKING
	if(!istype(tool, /obj/item/storage/part_replacer))
		return NONE
	source.balloon_alert(user, "casing is sealed!")
	return ITEM_INTERACT_BLOCKING

/// Shoves, bare hands and stamina hits aren't vandalism; only a real damaging hit is
/datum/element/outpost_property/proc/register_hit(obj/source, atom/attacker)
	if(!isliving(attacker))
		return
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(source))
	outpost?.register_aggression(attacker)

/datum/element/outpost_property/proc/on_melee_attack(obj/source, obj/item/weapon, mob/attacker, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!weapon.force || weapon.damtype == STAMINA)
		return
	register_hit(source, attacker)

/datum/element/outpost_property/proc/on_projectile_hit(obj/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(!hit_projectile.is_hostile_projectile() || hit_projectile.damage_type == STAMINA)
		return
	register_hit(source, hit_projectile.firer)

/datum/element/outpost_property/proc/on_thrown_hit(obj/source, atom/movable/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hit_atom))
		return
	var/obj/item/hit_item = hit_atom
	if(!hit_item.throwforce || hit_item.damtype == STAMINA)
		return
	register_hit(source, throwingdatum?.get_thrower())

/datum/element/outpost_property/proc/on_hulk_attack(obj/source, mob/attacker)
	SIGNAL_HANDLER
	register_hit(source, attacker)

/// The mecha is the attacker as far as the signal is concerned; the pilot is who the outpost blames
/datum/element/outpost_property/proc/on_mech_attack(obj/source, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	register_hit(source, pilot)
