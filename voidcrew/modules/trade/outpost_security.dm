/**
 * # Outpost Security
 *
 * How violence at a trader outpost reaches its police (voidcrew/modules/outpost_police/):
 * a watcher on every living mob for player-on-player attacks, the indestructible airlocks
 * and walls of the sanctuary interior, and outpost property. Each route names its crime
 * (OUTPOST_CRIME_*) and the item it was done with; the police decide what it costs.
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
	RegisterSignal(living_mob, COMSIG_MOB_FIRED_GUN, PROC_REF(on_outpost_gun_fired))

/**
 * Checks personal self-defense before the police hear of it. Both parties need
 * minds so outpost NPCs, fauna, and ordinary interactions with them retain their
 * existing behavior. `crime` is an OUTPOST_CRIME_*; `source` the item used, if any.
 */
/datum/outpost_pvp_enforcement/proc/register_pvp_aggression(mob/living/victim, mob/living/offender, crime = OUTPOST_CRIME_ASSAULT_ARMED, obj/item/source)
	if(!victim.mind || !offender?.mind || victim == offender)
		return
	var/obj/structure/overmap/trader_outpost/guarding_outpost = get_trader_outpost_for_turf(get_turf(victim))
	guarding_outpost?.register_pvp_aggression(victim, offender, crime, source)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_item_attack(mob/living/victim, obj/item/weapon, mob/living/offender, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(weapon.force)
		register_pvp_aggression(victim, offender, OUTPOST_CRIME_ASSAULT_ARMED, weapon)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_unarmed_attack(mob/living/victim, mob/living/offender, list/modifiers)
	SIGNAL_HANDLER
	if(offender.combat_mode || LAZYACCESS(modifiers, RIGHT_CLICK))
		register_pvp_aggression(victim, offender, OUTPOST_CRIME_ASSAULT_UNARMED)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_npc_attack(mob/living/victim, mob/living/offender)
	SIGNAL_HANDLER
	if(offender.melee_damage_upper > 0)
		register_pvp_aggression(victim, offender, OUTPOST_CRIME_ASSAULT_ARMED)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_projectile(mob/living/victim, obj/projectile/hitting_projectile)
	SIGNAL_HANDLER
	if(hitting_projectile.is_hostile_projectile() && isliving(hitting_projectile.firer))
		var/obj/item/fired_from = hitting_projectile.fired_from
		register_pvp_aggression(victim, hitting_projectile.firer, OUTPOST_CRIME_ASSAULT_SHOT, isitem(fired_from) ? fired_from : null)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_thrown_item(mob/living/victim, atom/movable/hitting_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hitting_atom))
		return
	var/obj/item/thrown_item = hitting_atom
	var/mob/living/offender = throwingdatum?.get_thrower()
	if(thrown_item.throwforce && istype(offender))
		register_pvp_aggression(victim, offender, OUTPOST_CRIME_ASSAULT_ARMED, thrown_item)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_hulk_attack(mob/living/victim, mob/living/offender)
	SIGNAL_HANDLER
	register_pvp_aggression(victim, offender, OUTPOST_CRIME_ASSAULT_ARMED)

/datum/outpost_pvp_enforcement/proc/on_outpost_pvp_mech_attack(mob/living/victim, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	register_pvp_aggression(victim, pilot, OUTPOST_CRIME_ASSAULT_ARMED)

// Touch spells land through the hand item's own interaction signal, which none
// of the victim-side signals above see. Shock Touch is an attack on any living
// target; Mending Touch only when it smites instead of healing.
/datum/action/cooldown/spell/touch/shock/cast_on_hand_hit(obj/item/melee/touch_attack/hand, atom/victim, mob/living/carbon/caster)
	. = ..()
	if(. && isliving(victim))
		GLOB.outpost_pvp_enforcement.register_pvp_aggression(victim, caster)

/datum/action/cooldown/spell/touch/lay_on_hands/by_gods_light_i_smite_you(mob/living/carbon/smiter, mob/living/motherfucker_to_hurt, smite_multiplier)
	. = ..()
	GLOB.outpost_pvp_enforcement.register_pvp_aggression(motherfucker_to_hurt, smiter)

/// Firing a gun past a trader outpost's checkpoint without a permit is gunfire for the police; the gun is evidence
/datum/outpost_pvp_enforcement/proc/on_outpost_gun_fired(mob/living/shooter, obj/item/gun/gun, atom/target)
	SIGNAL_HANDLER
	if(!outpost_checkpoint_weapon(gun))
		return
	var/turf/where = get_turf(shooter)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(where)
	if(!outpost?.is_secured_turf(where) || !shooter.mind || outpost.has_weapons_permit(shooter, OUTPOST_WEAPONS_PERMIT_GRACE))
		return
	outpost.police?.report_crime(shooter, OUTPOST_CRIME_GUNFIRE, null, gun)

// =========================================================================
// BOMBS (decision 38)
// =========================================================================
// A blast at a trader outpost hurts people and wrecks loose and placed things as anywhere else. The outpost's own
// floors and walls never react to it (the EX_ACT wrapper in code/__DEFINES/explosions.dm) and its property shrugs
// it off (/datum/element/outpost_property). tg's explosion damage raises none of the attack signals above, so
// propagate_blastwave() hands over who it caught here, and the bomb is an attack on each of them.

/// Adds the living mobs on `blasted` to `victims` (made on first use) when it is trader outpost ground. Returns the list.
/proc/note_outpost_blast_victims(turf/blasted, list/victims)
	var/checked = FALSE
	for(var/mob/living/victim in blasted)
		if(!checked)
			if(!is_trader_outpost_protected(blasted))
				return victims
			checked = TRUE
		LAZYADD(victims, victim)
	return victims

// ----- who armed a bomb (abuse review 3 MF1) -----

/obj
	/// Who armed this as a bomb: primed a grenade, planted or signalled C4, shot or lit a fuel tank. Blame for its
	/// blast at a trader outpost (outpost_bomber_of()); never the last hand to touch it.
	var/datum/weakref/outpost_armed_by

/// `bomb` was armed by `user`
/proc/outpost_note_armed(obj/bomb, mob/user)
	if(isliving(user) && !QDELETED(bomb))
		bomb.outpost_armed_by = WEAKREF(user)

/obj/item/grenade/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	outpost_note_armed(src, user)
	return ..()

// Its own arm_grenade() never calls the base one
/obj/item/grenade/chem_grenade/arm_grenade(mob/user, delayoverride, msg = TRUE, volume = 60)
	outpost_note_armed(src, user)
	return ..()

// A grenade sewn into a plush is armed by whoever sewed it in. Petting the plush sets it off (tg arms it with the
// petter as the user), and the one petting it is its victim, never its bomber.
/obj/item/toy/plush/attackby(obj/item/I, mob/living/user, list/modifiers, list/attack_modifiers)
	var/obj/item/grenade/before = grenade
	. = ..()
	if(grenade && grenade != before)
		outpost_note_armed(grenade, user)

/obj/item/toy/plush/attack_self(mob/user)
	var/obj/item/grenade/trap = grenade
	var/was_active = trap?.active
	var/datum/weakref/sewn_by = trap?.outpost_armed_by
	. = ..()
	if(trap && !was_active && !QDELETED(trap) && trap.active)
		trap.outpost_armed_by = sewn_by

/obj/item/grenade/c4/plant_c4(atom/bomb_target, mob/living/user)
	. = ..()
	if(.)
		outpost_note_armed(src, user)

/// `bomb` was set off by `user` and nobody had armed it before: the one who set it off armed it
/proc/outpost_note_armed_unless_armed(obj/bomb, mob/user)
	if(!QDELETED(bomb) && !bomb.outpost_armed_by?.resolve())
		outpost_note_armed(bomb, user)

// A trigger (a signaller, a timer, a sensor) wired into C4 or a chem grenade arms it: whoever wired it in (usr, at the
// wires window). Whoever later presses the signaller, walks past the sensor or speaks to it is never blamed: tg runs
// those pulses with that person as usr, so usr at the pulse would frame a passer-by.
/datum/wires/explosive/attach_assembly(color, obj/item/assembly/S)
	. = ..()
	if(. && isobj(holder) && isliving(usr))
		outpost_note_armed(holder, usr)

// Pulsing or cutting C4's wires by hand sets it off: that hand armed it, unless a planter or a wired trigger already had
/datum/wires/explosive/c4/on_pulse(wire, mob/living/user)
	if(isliving(user))
		outpost_note_armed_unless_armed(holder, user)
	return ..()

/datum/wires/explosive/c4/on_cut(wire, mend, source)
	if(!mend && isliving(source))
		outpost_note_armed_unless_armed(holder, source)
	return ..()

/obj/structure/reagent_dispensers/fueltank/bullet_act(obj/projectile/hitting_projectile)
	var/datum/weakref/before = outpost_armed_by
	outpost_note_armed(src, hitting_projectile.firer)
	. = ..()
	// Still standing: the shot set nothing off
	if(!QDELETED(src))
		outpost_armed_by = before

/obj/structure/reagent_dispensers/fueltank/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	var/datum/weakref/before = outpost_armed_by
	outpost_note_armed(src, user)
	. = ..()
	if(!QDELETED(src))
		outpost_armed_by = before

/**
 * Who set off a blast: the firer of a projectile (a mech's pilot), otherwise whoever armed the explosive
 * (outpost_armed_by). An explosive nobody armed (one set off by another blast or a fire) is blamed on nobody: the
 * last hand to touch it (tg's fingerprintslast) may be anyone who moved it, so it is never asked. Null too when the
 * armer is no longer living, or the cause is not an atom (a chemical reaction).
 */
/proc/outpost_bomber_of(atom/explosion_cause)
	if(isprojectile(explosion_cause))
		var/obj/projectile/shot = explosion_cause
		if(isliving(shot.firer))
			return shot.firer
		if(ismecha(shot.firer))
			var/obj/vehicle/sealed/mecha/mech = shot.firer
			for(var/mob/living/pilot in mech.return_drivers())
				return pilot
			return null
		explosion_cause = shot.firer
	if(!isobj(explosion_cause))
		return null
	var/obj/bomb = explosion_cause
	var/mob/living/armer = bomb.outpost_armed_by?.resolve()
	return isliving(armer) ? armer : null

/**
 * A blast caught `victims` at a trader outpost: it is an attack by its bomber on each, through the same routes as a
 * blow. Officers first, then the outpost's other people, then visitors, so the gravest crime is the one counted and
 * the rest fold into it (report_crime()). Whether anyone saw the bomber is the police's call. Never sleeps.
 */
/datum/outpost_pvp_enforcement/proc/on_outpost_bombing(atom/explosion_cause, list/victims)
	var/mob/living/bomber = outpost_bomber_of(explosion_cause)
	if(!bomber?.mind)
		return
	var/obj/item/bomb = isitem(explosion_cause) ? explosion_cause : null
	var/list/officers = list()
	var/list/locals = list()
	var/list/visitors = list()
	for(var/mob/living/victim as anything in victims)
		if(QDELETED(victim) || victim == bomber)
			continue
		if(istype(victim, /mob/living/carbon/human/npc/ambient_npc/outpost/police))
			officers += victim
		else if(victim.mind && !istype(victim, /mob/living/carbon/human/npc))
			visitors += victim
		else
			locals += victim
	if(!length(officers) && !length(locals) && !length(visitors))
		return
	log_game("OUTPOST BOMBING: [key_name(bomber)] caught [length(officers) + length(locals) + length(visitors)] at [AREACOORD(victims[1])] with [explosion_cause].")
	for(var/mob/living/officer as anything in officers)
		// The bomb is the weapon. The signal alone would find none in the bomber's hands and call it resisting.
		var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(get_turf(officer))
		outpost?.police?.officer_struck(officer, bomber, ATTACKER_DAMAGING_ATTACK, bomb)
		SEND_SIGNAL(officer, COMSIG_ATOM_WAS_ATTACKED, bomber, ATTACKER_DAMAGING_ATTACK)
	for(var/mob/living/local as anything in locals)
		SEND_SIGNAL(local, COMSIG_ATOM_WAS_ATTACKED, bomber, ATTACKER_DAMAGING_ATTACK)
	for(var/mob/living/visitor as anything in visitors)
		register_pvp_aggression(visitor, bomber, OUTPOST_CRIME_ASSAULT_ARMED, bomb)

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

/**
 * tg's emag leaves an airlock open, bolted and dark for good. An outpost's doors are looked after: the door comes
 * back as the gate scanner does (OUTPOST_CHECKPOINT_EMAG_TIME), with a spark, its lights and bolts back, and shuts
 * once its doorway is clear (owner decision 33).
 */
/obj/machinery/door/airlock/outpost/finish_emag_act()
	. = ..()
	if(!QDELETED(src) && (obj_flags & EMAGGED))
		addtimer(CALLBACK(src, PROC_REF(mend_emag)), OUTPOST_CHECKPOINT_EMAG_TIME, TIMER_UNIQUE | TIMER_DELETE_ME)

/// The emag wears off: lights, power and bolts back, then the door shuts once nobody is in the way
/obj/machinery/door/airlock/outpost/proc/mend_emag()
	if(QDELETED(src) || !(obj_flags & EMAGGED))
		return
	obj_flags &= ~EMAGGED
	lights = TRUE
	regainMainPower()
	regainBackupPower()
	unbolt()
	do_sparks(2, TRUE, src)
	visible_message(span_notice("[src] sparks, and its lights come back on."))
	update_appearance()
	close_when_clear()

/// Shuts once nothing stands in the doorway, trying again every few seconds
/obj/machinery/door/airlock/outpost/proc/close_when_clear()
	if(QDELETED(src) || density || locked)
		return
	var/turf/doorway = get_turf(src)
	for(var/atom/movable/thing in doorway)
		if(thing != src && !iseffect(thing) && (isliving(thing) || thing.density))
			addtimer(CALLBACK(src, PROC_REF(close_when_clear)), 3 SECONDS, TIMER_UNIQUE | TIMER_DELETE_ME)
			return
	INVOKE_ASYNC(src, PROC_REF(close))

/obj/machinery/door/airlock/outpost/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	if(attacking_item.force && outpost)
		outpost.register_aggression(user)
	return ..()

/obj/machinery/door/airlock/outpost/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	if(outpost && isliving(hitting_projectile.firer))
		outpost.register_aggression(hitting_projectile.firer)
	return ..()

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
	// A bomb (decision 38) skips it and whatever it holds: some types blow up or spill from their own ex_act()
	// whatever their resistance flags, and a machine flagged after Initialize() misses its own parts guard
	property.flags_1 |= PREVENT_CONTENTS_EXPLOSION_1
	RegisterSignal(target, COMSIG_ATOM_PRE_EX_ACT, PROC_REF(block_blast))
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
		COMSIG_ATOM_PRE_EX_ACT,
	))
	REMOVE_TRAIT(source, TRAIT_OUTPOST_PROPERTY, ELEMENT_TRAIT(type))
	return ..()

/datum/element/outpost_property/proc/block_blast(obj/source, severity, target)
	SIGNAL_HANDLER
	return COMPONENT_CANCEL_EX_ACT

/datum/element/outpost_property/proc/block_tool(obj/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	// A checkpoint's inner door can be forced (outpost_checkpoint.dm)
	if(tool?.tool_behaviour == TOOL_CROWBAR && source.outpost_forceable())
		return NONE
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
