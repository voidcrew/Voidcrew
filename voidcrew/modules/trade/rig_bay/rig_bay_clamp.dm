// The Rig Bay's two locks on a mech: the chains while it hangs for sale, and the buyer's hold after the sale.
// See data/rig-bay/spec.md section 5. Both save every flag they change and put it back when removed.

/// Tools that open, pry, cut, weld, bolt or pulse a mech. A chained mech refuses them all.
#define RIG_BAY_BLOCKED_TOOLS list(TOOL_CROWBAR, TOOL_SCREWDRIVER, TOOL_WRENCH, TOOL_WELDER, TOOL_WIRECUTTER, TOOL_MULTITOOL)
/// What a chained mech gets on top of its own resistance flags.
#define RIG_BAY_PROTECTION_FLAGS (INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF)
/// Mech flags that let something take a mech over without climbing in. Off while it hangs on the chains.
#define RIG_BAY_REMOTE_FLAGS (AI_COMPATIBLE | MMI_COMPATIBLE | BEACON_CONTROLLABLE)

/**
 * # Rig Bay clamp
 *
 * On a display mech from the moment its stand spawns it until the sale. Nobody gets in, opens it,
 * fits anything to it, damages it, EMPs it, moves it or teleports it. Hostile hits still count as
 * aggression at the outpost, like hits on any outpost property.
 */
/datum/component/rig_bay_clamp
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The stand the mech hangs from.
	var/datum/weakref/stand_ref
	/// The mech's resistance flags before the chains went on.
	var/saved_resistance_flags = NONE
	/// Which RIG_BAY_REMOTE_FLAGS the mech had before the chains went on.
	var/saved_remote_flags = NONE

/datum/component/rig_bay_clamp/Initialize(obj/structure/rig_bay_stand/stand)
	if(!ismecha(parent))
		return COMPONENT_INCOMPATIBLE
	stand_ref = WEAKREF(stand)

/datum/component/rig_bay_clamp/RegisterWithParent()
	var/obj/vehicle/sealed/mecha/mech = parent
	saved_resistance_flags = mech.resistance_flags
	mech.resistance_flags |= RIG_BAY_PROTECTION_FLAGS
	saved_remote_flags = mech.mecha_flags & RIG_BAY_REMOTE_FLAGS
	mech.mecha_flags &= ~RIG_BAY_REMOTE_FLAGS
	mech.AddElement(/datum/element/empprotection, EMP_PROTECT_ALL)
	ADD_TRAIT(mech, TRAIT_RIG_BAY_CLAMPED, RIG_BAY_TRAIT)

	var/list/tool_signals = list()
	for(var/tool in RIG_BAY_BLOCKED_TOOLS)
		tool_signals += COMSIG_ATOM_TOOL_ACT(tool)
		tool_signals += COMSIG_ATOM_SECONDARY_TOOL_ACT(tool)
	RegisterSignals(mech, tool_signals, PROC_REF(block_tool))
	// Sent before the mech's own item_interaction and the item's interact_with_atom, in and out of
	// combat mode: ID cards, MMIs, intellicards, equipment, ammo, cells, stock parts, weapons.
	RegisterSignals(mech, list(COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_ITEM_INTERACTION_SECONDARY), PROC_REF(block_item))
	RegisterSignal(mech, COMSIG_MECHA_TRY_ENTER, PROC_REF(block_entry))
	RegisterSignal(mech, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(block_move))
	RegisterSignal(mech, COMSIG_MOVABLE_TELEPORTING, PROC_REF(block_teleport))
	RegisterSignal(mech, COMSIG_ATOM_EXAMINE, PROC_REF(on_examine))
	RegisterSignal(mech, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(mech, COMSIG_ATOM_PREHITBY, PROC_REF(on_thrown_hit))
	RegisterSignal(mech, COMSIG_ATOM_HULK_ATTACK, PROC_REF(on_hulk_attack))
	RegisterSignal(mech, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_mech_attack))

/datum/component/rig_bay_clamp/UnregisterFromParent()
	var/obj/vehicle/sealed/mecha/mech = parent
	var/list/tool_signals = list()
	for(var/tool in RIG_BAY_BLOCKED_TOOLS)
		tool_signals += COMSIG_ATOM_TOOL_ACT(tool)
		tool_signals += COMSIG_ATOM_SECONDARY_TOOL_ACT(tool)
	UnregisterSignal(mech, tool_signals + list(
		COMSIG_ATOM_ITEM_INTERACTION,
		COMSIG_ATOM_ITEM_INTERACTION_SECONDARY,
		COMSIG_MECHA_TRY_ENTER,
		COMSIG_MOVABLE_PRE_MOVE,
		COMSIG_MOVABLE_TELEPORTING,
		COMSIG_ATOM_EXAMINE,
		COMSIG_PROJECTILE_PREHIT,
		COMSIG_ATOM_PREHITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_MECH,
	))
	REMOVE_TRAIT(mech, TRAIT_RIG_BAY_CLAMPED, RIG_BAY_TRAIT)
	mech.RemoveElement(/datum/element/empprotection, EMP_PROTECT_ALL)
	mech.mecha_flags |= saved_remote_flags
	mech.resistance_flags = saved_resistance_flags

/datum/component/rig_bay_clamp/proc/block_tool(obj/vehicle/sealed/mecha/source, mob/living/user, obj/item/tool)
	SIGNAL_HANDLER
	source.balloon_alert(user, "chained up!")
	return ITEM_INTERACT_BLOCKING

/datum/component/rig_bay_clamp/proc/block_item(obj/vehicle/sealed/mecha/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	source.balloon_alert(user, "chained up!")
	return ITEM_INTERACT_BLOCKING

/datum/component/rig_bay_clamp/proc/block_entry(obj/vehicle/sealed/mecha/source, mob/entering)
	SIGNAL_HANDLER
	source.balloon_alert(entering, "chained up!")
	return COMPONENT_MECHA_BLOCK_ENTER

/datum/component/rig_bay_clamp/proc/block_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/component/rig_bay_clamp/proc/block_teleport(datum/source, atom/destination, channel)
	SIGNAL_HANDLER
	return TRUE

/datum/component/rig_bay_clamp/proc/on_examine(atom/source, mob/user, list/examine_list)
	SIGNAL_HANDLER
	examine_list += span_notice("It hangs from the gantry chains.")

/datum/component/rig_bay_clamp/proc/on_projectile_hit(atom/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(!hit_projectile.is_hostile_projectile() || hit_projectile.damage_type == STAMINA)
		return
	register_outpost_property_hit(source, hit_projectile.firer)

/datum/component/rig_bay_clamp/proc/on_thrown_hit(atom/source, atom/movable/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hit_atom))
		return
	var/obj/item/hit_item = hit_atom
	if(!hit_item.throwforce || hit_item.damtype == STAMINA)
		return
	register_outpost_property_hit(source, throwingdatum?.get_thrower())

/datum/component/rig_bay_clamp/proc/on_hulk_attack(atom/source, mob/attacker)
	SIGNAL_HANDLER
	register_outpost_property_hit(source, attacker)

/datum/component/rig_bay_clamp/proc/on_mech_attack(atom/source, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	register_outpost_property_hit(source, pilot)

/**
 * # Rig Bay hold
 *
 * On a sold mech while it is still on outpost ground, for RIG_BAY_HOLD_TIME at most. Only the buyer's
 * crew can climb in or load a brain or AI into it. While it is empty, unarmed and past the checkpoint
 * it can't be damaged, so nobody wrecks it before the crew gets it out; that drops as soon as someone
 * climbs in, a weapon is fitted, or it leaves the concourse. Hostile hits count as aggression while it
 * is on protected outpost ground. The hold ends when the mech leaves outpost ground or the time runs out.
 */
/datum/component/rig_bay_hold
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The buyer's crew. Null means nobody is locked out.
	var/datum/weakref/crew_ref
	/// TRUE once a weapon has been fitted. The mech never goes back to being protected.
	var/armed = FALSE
	/// TRUE while RIG_BAY_PROTECTION_FLAGS are on the mech.
	var/protecting = FALSE
	/// Which RIG_BAY_PROTECTION_FLAGS the mech had on its own before the hold protected it.
	var/saved_protection_flags = NONE

/datum/component/rig_bay_hold/Initialize(datum/voidcrew_crew_record/crew)
	if(!ismecha(parent))
		return COMPONENT_INCOMPATIBLE
	crew_ref = crew ? WEAKREF(crew) : null
	var/obj/vehicle/sealed/mecha/mech = parent
	for(var/obj/item/mecha_parts/mecha_equipment/equipment as anything in mech.flat_equipment)
		if(istype(equipment, /obj/item/mecha_parts/mecha_equipment/weapon))
			armed = TRUE
			break
	addtimer(CALLBACK(src, PROC_REF(expire)), RIG_BAY_HOLD_TIME, TIMER_DELETE_ME)

/datum/component/rig_bay_hold/RegisterWithParent()
	var/obj/vehicle/sealed/mecha/mech = parent
	RegisterSignal(mech, COMSIG_MECHA_TRY_ENTER, PROC_REF(on_try_enter))
	RegisterSignals(mech, list(COMSIG_ATOM_ITEM_INTERACTION, COMSIG_ATOM_ITEM_INTERACTION_SECONDARY), PROC_REF(on_item_interaction))
	RegisterSignal(mech, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(on_pre_move))
	RegisterSignal(mech, COMSIG_MOVABLE_MOVED, PROC_REF(on_moved))
	// Equipment is forceMoved into the mech when it attaches, whatever route fitted it.
	RegisterSignal(mech, COMSIG_ATOM_ENTERED, PROC_REF(on_entered))
	RegisterSignal(mech, COMSIG_ATOM_EXITED, PROC_REF(on_exited))
	RegisterSignal(mech, COMSIG_PROJECTILE_PREHIT, PROC_REF(on_projectile_hit))
	RegisterSignal(mech, COMSIG_ATOM_AFTER_ATTACKEDBY, PROC_REF(on_melee_attack))
	RegisterSignal(mech, COMSIG_ATOM_PREHITBY, PROC_REF(on_thrown_hit))
	RegisterSignal(mech, COMSIG_ATOM_HULK_ATTACK, PROC_REF(on_hulk_attack))
	RegisterSignal(mech, COMSIG_ATOM_ATTACK_MECH, PROC_REF(on_mech_attack))
	update_protection()

/datum/component/rig_bay_hold/UnregisterFromParent()
	set_protected(FALSE)
	UnregisterSignal(parent, list(
		COMSIG_MECHA_TRY_ENTER,
		COMSIG_ATOM_ITEM_INTERACTION,
		COMSIG_ATOM_ITEM_INTERACTION_SECONDARY,
		COMSIG_MOVABLE_PRE_MOVE,
		COMSIG_MOVABLE_MOVED,
		COMSIG_ATOM_ENTERED,
		COMSIG_ATOM_EXITED,
		COMSIG_PROJECTILE_PREHIT,
		COMSIG_ATOM_AFTER_ATTACKEDBY,
		COMSIG_ATOM_PREHITBY,
		COMSIG_ATOM_HULK_ATTACK,
		COMSIG_ATOM_ATTACK_MECH,
	))

/// The time ran out: the mech is anyone's.
/datum/component/rig_bay_hold/proc/expire()
	qdel(src)

/// Whether the mech is anywhere a trader outpost watches: its concourse or one of its hangars.
/datum/component/rig_bay_hold/proc/on_outpost_ground()
	return !isnull(get_trader_outpost_for_turf(get_turf(parent)))

/// Whether the mech is past the checkpoint, where a fresh sale sits until the crew drives it out.
/datum/component/rig_bay_hold/proc/on_secured_ground()
	var/turf/place = get_turf(parent)
	var/obj/structure/overmap/trader_outpost/outpost = get_trader_outpost_for_turf(place)
	return !!outpost?.is_secured_turf(place)

/// Whether `user` is on the buyer's crew. Always TRUE when the sale had no crew.
/datum/component/rig_bay_hold/proc/is_buyer_crew(mob/user)
	if(!crew_ref)
		return TRUE
	var/datum/voidcrew_crew_record/crew = crew_ref.resolve()
	if(QDELETED(crew))
		return TRUE
	return user?.mind?.get_reputation_crew() == crew

/datum/component/rig_bay_hold/proc/update_protection()
	var/obj/vehicle/sealed/mecha/mech = parent
	set_protected(!armed && !LAZYLEN(mech.occupants) && on_secured_ground())

/datum/component/rig_bay_hold/proc/set_protected(protect)
	if(protect == protecting)
		return
	var/obj/vehicle/sealed/mecha/mech = parent
	protecting = protect
	if(protect)
		saved_protection_flags = mech.resistance_flags & RIG_BAY_PROTECTION_FLAGS
		mech.resistance_flags |= RIG_BAY_PROTECTION_FLAGS
	else
		mech.resistance_flags = (mech.resistance_flags & ~RIG_BAY_PROTECTION_FLAGS) | saved_protection_flags

/datum/component/rig_bay_hold/proc/on_try_enter(obj/vehicle/sealed/mecha/source, mob/entering)
	SIGNAL_HANDLER
	if(!on_outpost_ground())
		qdel(src)
		return NONE
	// Still coming down off the chains
	if(source.anchored)
		source.balloon_alert(entering, "still lowering!")
		return COMPONENT_MECHA_BLOCK_ENTER
	if(is_buyer_crew(entering))
		return NONE
	source.balloon_alert(entering, "sold!")
	return COMPONENT_MECHA_BLOCK_ENTER

/// A brain in a jar or an AI card is another way in.
/datum/component/rig_bay_hold/proc/on_item_interaction(obj/vehicle/sealed/mecha/source, mob/living/user, obj/item/tool, list/modifiers)
	SIGNAL_HANDLER
	if(!istype(tool, /obj/item/mmi) && !istype(tool, /obj/item/aicard))
		return NONE
	if(!on_outpost_ground())
		qdel(src)
		return NONE
	if(!source.anchored && is_buyer_crew(user))
		return NONE
	source.balloon_alert(user, source.anchored ? "still lowering!" : "sold!")
	return ITEM_INTERACT_BLOCKING

/// Nothing moves the mech while the stand is still lowering it.
/datum/component/rig_bay_hold/proc/on_pre_move(atom/movable/source, atom/new_loc)
	SIGNAL_HANDLER
	if(source.anchored)
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE
	return NONE

/datum/component/rig_bay_hold/proc/on_moved(atom/movable/source, atom/old_loc, dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(!on_outpost_ground())
		qdel(src)
		return
	update_protection()

/datum/component/rig_bay_hold/proc/on_entered(atom/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(istype(arrived, /obj/item/mecha_parts/mecha_equipment/weapon))
		armed = TRUE
	else if(!ismob(arrived))
		return
	update_protection()

/datum/component/rig_bay_hold/proc/on_exited(atom/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	if(ismob(gone))
		update_protection()

/// Hostile hits on a sold mech count as aggression while it is on protected outpost ground.
/datum/component/rig_bay_hold/proc/register_hit(atom/source, atom/attacker)
	if(!is_trader_outpost_protected(source))
		return
	// The buyer's crew can bash their own mech about
	var/mob/hitter = attacker
	if(ismob(hitter) && crew_ref && hitter.mind?.get_reputation_crew() == crew_ref.resolve())
		return
	register_outpost_property_hit(source, attacker)

/datum/component/rig_bay_hold/proc/on_projectile_hit(atom/source, obj/projectile/hit_projectile)
	SIGNAL_HANDLER
	if(!hit_projectile.is_hostile_projectile() || hit_projectile.damage_type == STAMINA)
		return
	register_hit(source, hit_projectile.firer)

/datum/component/rig_bay_hold/proc/on_melee_attack(atom/source, obj/item/weapon, mob/attacker, list/modifiers, list/attack_modifiers)
	SIGNAL_HANDLER
	if(!weapon.force || weapon.damtype == STAMINA)
		return
	register_hit(source, attacker)

/datum/component/rig_bay_hold/proc/on_thrown_hit(atom/source, atom/movable/hit_atom, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(!isitem(hit_atom))
		return
	var/obj/item/hit_item = hit_atom
	if(!hit_item.throwforce || hit_item.damtype == STAMINA)
		return
	register_hit(source, throwingdatum?.get_thrower())

/datum/component/rig_bay_hold/proc/on_hulk_attack(atom/source, mob/attacker)
	SIGNAL_HANDLER
	register_hit(source, attacker)

/datum/component/rig_bay_hold/proc/on_mech_attack(atom/source, obj/vehicle/sealed/mecha/mecha_attacker, mob/living/pilot)
	SIGNAL_HANDLER
	register_hit(source, pilot)

#undef RIG_BAY_BLOCKED_TOOLS
#undef RIG_BAY_PROTECTION_FLAGS
#undef RIG_BAY_REMOTE_FLAGS
