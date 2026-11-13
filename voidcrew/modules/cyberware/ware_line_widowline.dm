/**
 * # Widowline line: the Arc model
 *
 * The Widowline monowire (ware_military_arms.dm) with a capacitor stack on the
 * spool. Everything the plain wire does still happens, and every landed hit
 * adds a shock on top:
 *
 * - Living targets take a little burn and a short stagger. The current goes in
 *   through the wire itself, so it is run with SHOCK_NOGLOVES and insulated
 *   gloves do nothing. Everything else tg's shock code already honours still
 *   applies: TRAIT_SHOCKIMMUNE, insulating suits and species or physiology
 *   shock coefficients. A target the shock can't reach takes only the plain
 *   cut: no burn, no stagger, no arc.
 * - Silicons, mechs and robotic mobs (MOB_ROBOTIC) take a heavy burn bonus.
 *   The plain wire is nearly useless against them (its demolition_mod), and
 *   this is what makes up for it. Silicons shrug electrocute_act off by signal,
 *   so they get the bonus alone.
 * - A turret, a ship laser turret, a console or a camera is knocked out for a
 *   few seconds. Never a raw emp_act: an EMP blacks out an APC for a minute,
 *   pops airlocks open, drains a laser turret's cell and scrambles a
 *   porta-turret's targeting flags. Each family is cut through its own
 *   machinery (the Icepick Jack's precedent), consoles lose power briefly, and
 *   anything that answers tg's on_saboteur() hook (cameras) goes through that.
 *   Outpost property and the trader outposts' concourse are immune.
 *
 * The through-cut is untouched: the body behind takes the plain cut, not the shock.
 */

/// Burn of the shock itself, on top of the cut and the wire's own charge.
#define CYBERWARE_ARC_SHOCK_BURN 5
/// Stagger a landed shock leaves, and the most it stacks to.
#define CYBERWARE_ARC_STAGGER (2 SECONDS)
#define CYBERWARE_ARC_STAGGER_CAP (4 SECONDS)
/// Burn bonus on silicons, mechs and robotic mobs.
#define CYBERWARE_ARC_ROBOTIC_BONUS 25
/// How long a shorted turret, console or camera stays dark.
#define CYBERWARE_ARC_JAM_DURATION (5 SECONDS)
/// Gap before the same wire can short another machine.
#define CYBERWARE_ARC_JAM_RECHARGE (15 SECONDS)

/**
 * The wire. Plain Widowline numbers (force, burn, cleave, reach, armour
 * penetration, demolition_mod) are inherited as they are; the vars here are
 * the shock rider only. All of it keys off afterattack(), which only runs for
 * a swing that actually landed, on a mob or on an object that can be hit.
 */
/obj/item/melee/cyberware_monowire/live
	name = "\improper Widowline Arc monowire"
	desc = "A weighted spool of monomolecular line with a capacitor stack feeding it. It smells of ozone and ticks like a cooling engine."
	icon_state = "monowire_live"
	inhand_icon_state = "monowire_live"
	/// Burn of the shock on a living target.
	var/shock_burn = CYBERWARE_ARC_SHOCK_BURN
	/// Stagger a landed shock leaves.
	var/stagger_time = CYBERWARE_ARC_STAGGER
	/// Most stagger the shock stacks to.
	var/stagger_cap = CYBERWARE_ARC_STAGGER_CAP
	/// Burn bonus on silicons, mechs and robotic mobs.
	var/robotic_bonus = CYBERWARE_ARC_ROBOTIC_BONUS
	/// How long a shorted machine stays down.
	var/jam_duration = CYBERWARE_ARC_JAM_DURATION
	/// Gap before this wire can short another machine.
	var/jam_recharge = CYBERWARE_ARC_JAM_RECHARGE
	/// The stack recharging after a machine was shorted.
	COOLDOWN_DECLARE(jam_cooldown)

/obj/item/melee/cyberware_monowire/live/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!isliving(user) || QDELETED(target) || target == user)
		return
	// The lash out to what it hit is every wire's (ware_military_arms.dm); the shock is this one's.
	if(isliving(target))
		discharge_into_mob(target, user)
	else if(ismecha(target))
		discharge_into_mech(target, user)
	else if(ismachinery(target))
		discharge_into_machine(target, user)

/// On a body while the Arc's charge goes into it: no shock shake (do_jitter_animation()).
#define TRAIT_ARC_NO_SHAKE "arc_no_shake"

/mob/living/do_jitter_animation(jitter_amount = 100)
	if(HAS_TRAIT(src, TRAIT_ARC_NO_SHAKE))
		return
	return ..()

/// The shock on whatever it went into: a small crackle where the wire touched
/// (cyberware_anim2.dm). The lash is the picture, never a bolt or a shower of sparks.
/obj/item/melee/cyberware_monowire/live/proc/arc_visuals(atom/target, mob/living/user)
	cyberware_arc_crackle_fx(user, target, lash_zone || check_zone(user?.zone_selected))
	playsound(target, SFX_SPARKS, 50, TRUE)
	cyberware_ink_pulse(user, CYBERWARE_INK_SOFT)

/**
 * The shock into a living target. Returns TRUE if anything landed.
 * Dead and shock-immune targets are skipped entirely; see the file header for
 * what counts as shock-immune.
 */
/obj/item/melee/cyberware_monowire/live/proc/discharge_into_mob(mob/living/target, mob/living/user)
	if(target.stat == DEAD || HAS_TRAIT(target, TRAIT_SHOCKIMMUNE))
		return FALSE
	var/jolted = FALSE
	var/is_silicon = issilicon(target)
	// No stun, no message, no skeleton flash, no jitter: the lash and its
	// crackle are the tell, and the stagger is the whole effect on the body.
	// tg's shock shakes a body for over two seconds whatever jitter it is
	// given, so the shake is held off while the charge goes in.
	if(!is_silicon)
		ADD_TRAIT(target, TRAIT_ARC_NO_SHAKE, REF(src))
		jolted = target.electrocute_act(shock_burn, user, 1, SHOCK_NOGLOVES | SHOCK_NOSTUN | SHOCK_SUPPRESS_MESSAGE | SHOCK_NO_HUMAN_ANIM, 0, 0, 0) ? TRUE : FALSE
		REMOVE_TRAIT(target, TRAIT_ARC_NO_SHAKE, REF(src))
	if(is_silicon || (target.mob_biotypes & MOB_ROBOTIC))
		var/bonus_zone = target.get_random_valid_zone(user.zone_selected)
		target.apply_damage(
			robotic_bonus,
			BURN,
			bonus_zone,
			target.run_armor_check(bonus_zone, ENERGY, armour_penetration = armour_penetration, silent = TRUE),
		)
		jolted = TRUE
	if(!jolted)
		return FALSE
	arc_visuals(target, user)
	if(!QDELETED(target))
		target.adjust_staggered_up_to(stagger_time, stagger_cap)
	return TRUE

/// The burn bonus into a mech's armour. The pilot is not touched.
/obj/item/melee/cyberware_monowire/live/proc/discharge_into_mech(obj/vehicle/sealed/mecha/mech, mob/living/user)
	if(QDELETED(mech) || mech.atom_integrity <= 0 || HAS_TRAIT(mech, TRAIT_OUTPOST_PROPERTY) || is_trader_outpost_protected(mech))
		return FALSE
	mech.take_damage(robotic_bonus, BURN, ENERGY, FALSE, get_dir(mech, user), armour_penetration)
	arc_visuals(mech, user)
	return TRUE

/**
 * Shorts a machine out for a few seconds, if it is one that can be. Returns
 * TRUE if it went dark. The recharge only starts on a machine that actually
 * went dark, so a wasted swing at a vending machine costs nothing.
 */
/obj/item/melee/cyberware_monowire/live/proc/discharge_into_machine(obj/machinery/machine, mob/living/user)
	if(QDELETED(machine) || HAS_TRAIT(machine, TRAIT_OUTPOST_PROPERTY) || is_trader_outpost_protected(machine))
		return FALSE
	if(!COOLDOWN_FINISHED(src, jam_cooldown) || !jam_machine(machine))
		// Still crackles, goes nowhere.
		do_sparks(1, TRUE, machine)
		return FALSE
	COOLDOWN_START(src, jam_cooldown, jam_recharge)
	arc_visuals(machine, user)
	machine.visible_message(span_warning("[machine] crackles and goes dark."))
	return TRUE

/// Cuts the machine through its own family's machinery. Returns TRUE if it was knocked out.
/obj/item/melee/cyberware_monowire/live/proc/jam_machine(obj/machinery/machine)
	if(machine.machine_stat & BROKEN)
		return FALSE
	if(istype(machine, /obj/machinery/porta_turret))
		var/obj/machinery/porta_turret/turret = machine
		if(!COOLDOWN_FINISHED(turret, disabled_time))
			return FALSE
		turret.set_disabled(jam_duration)
		return TRUE
	if(istype(machine, /obj/machinery/ship_combat/laser_turret))
		var/obj/machinery/ship_combat/laser_turret/laser = machine
		// Its fire cooldown is also its normal reload; never shorten that.
		if(COOLDOWN_TIMELEFT(laser, fire_cooldown) >= jam_duration)
			return FALSE
		COOLDOWN_START(laser, fire_cooldown, jam_duration)
		return TRUE
	if(istype(machine, /obj/machinery/computer))
		return cyberware_arc_power_cut(machine, jam_duration)
	// Cameras answer here; anything else with no answer is left alone.
	return !!machine.on_saboteur(src, jam_duration)

/**
 * Drops a machine's power for a moment, the same flag an area blackout sets
 * and the same way back: power_change() works the real state out again.
 * Returns FALSE for a machine that is already down or draws no power.
 */
/proc/cyberware_arc_power_cut(obj/machinery/machine, duration)
	if(machine.use_power == NO_POWER_USE || (machine.machine_stat & (NOPOWER | BROKEN | MAINT | EMPED)))
		return FALSE
	machine.set_machine_stat(machine.machine_stat | NOPOWER)
	SEND_SIGNAL(machine, COMSIG_MACHINERY_POWER_LOST)
	machine.update_appearance()
	machine.set_light(0)
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(cyberware_arc_power_restore), machine), duration)
	return TRUE

/// End of a power cut. Global so it survives the machine being deleted meanwhile.
/proc/cyberware_arc_power_restore(obj/machinery/machine)
	if(QDELETED(machine))
		return
	// power_change() leaves a broken machine's flags alone, so a machine that
	// broke while it was dark would stay unpowered after it was repaired.
	if(machine.machine_stat & BROKEN)
		machine.set_machine_stat(machine.machine_stat & ~NOPOWER)
	machine.power_change()

/**
 * # Widowline Arc spool housing (T3, one arm, aug slot, load 6)
 *
 * The Widowline spool housing, stepped up. Same slot, same arm, so installing
 * one evicts the other. Sold at the Chop Shop for vouchers and never bought
 * back, like the plain Widowline.
 */
/obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/live
	name = "\improper Widowline Arc spool housing"
	desc = "A wrist spool wound with monomolecular line, with a capacitor stack bolted on where the safety used to be."
	icon_state = "monowire_live"
	chrome_load = 6
	items_to_create = list(/obj/item/melee/cyberware_monowire/live)

/datum/shop_sku/ripperdoc/monowire_live
	zone_permission = ZONE_PERMISSION_ELITE
	category = "Military Chrome"
	item_path = /obj/item/organ/cyberimp/arm/toolkit/cyberware/monowire/live
	price_vouchers = 5
	stock_min = 1
	stock_max = 1
	convoys_per_unit = 3
	fixed_price = TRUE
	contract_reward = FALSE

#undef CYBERWARE_ARC_SHOCK_BURN
#undef CYBERWARE_ARC_STAGGER
#undef CYBERWARE_ARC_STAGGER_CAP
#undef CYBERWARE_ARC_ROBOTIC_BONUS
#undef CYBERWARE_ARC_JAM_DURATION
#undef CYBERWARE_ARC_JAM_RECHARGE
#undef TRAIT_ARC_NO_SHAKE
