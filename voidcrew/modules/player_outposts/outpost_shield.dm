/**
 * # Outpost Shield Generator
 *
 * Player-buildable siege defense for player outposts. While the generator is
 * anchored, powered and holds charge, incoming siege missiles detonate against
 * the shield envelope (the outpost's build region) and drain charge instead of
 * damaging the outpost. When the charge pool is empty, unpowered or the
 * generator is destroyed, missiles strike home as before.
 *
 * The charge pool recharges from outpost APC power, pausing for a short delay
 * after every absorbed hit, sustained bombardment outpaces regeneration.
 *
 * Only ONE generator holds the shield at a time (the first registered one that
 * is operational). Extra generators are cold standbys: they don't charge and
 * don't absorb until they inherit the role, so stacking generators never
 * multiplies effective shield charge.
 *
 * Obtained like the rest of the siege kit: board printed via research
 * (Shuttle Shield Systems node, see ship_combat/research.dm), built into a
 * machine frame, then wrenched down inside the outpost's build region.
 *
 * Interception hook: /obj/effect/ship_missile/try_outpost_shield_intercept
 * (bottom of this file), called from missile_effect.dm Moved()/impact().
 * Tuning defines live in voidcrew/_DEFINES/player_outposts.dm.
 */

/obj/machinery/outpost_shield_generator
	name = "outpost shield generator"
	desc = "A colonial-pattern deflector field projector. While powered and charged, it detonates incoming ordnance at the edge of the claim's survey bounds."
	icon = 'voidcrew/modules/player_outposts/icons/outpost.dmi'
	icon_state = "shieldgen"
	density = TRUE
	anchored = TRUE
	power_channel = AREA_USAGE_EQUIP
	idle_power_usage = OUTPOST_SHIELD_IDLE_POWER
	active_power_usage = OUTPOST_SHIELD_CHARGE_POWER
	circuit = /obj/item/circuitboard/machine/outpost_shield_generator
	/// The outpost whose z-level this generator sits on (set in LateInitialize; robust to rebuild)
	var/obj/structure/overmap/dynamic/player_outpost/outpost
	/// Current shield charge
	var/charge = 0
	/// Maximum shield charge (base + capacitor tiers, see RefreshParts)
	var/max_charge = OUTPOST_SHIELD_BASE_CHARGE
	/// Charge regained per second while powered and not suppressed (base + micro-laser tiers)
	var/recharge_rate = OUTPOST_SHIELD_BASE_RECHARGE
	/// Whether the shield read as "up" last tick, for icon/power updates
	var/was_shield_up = FALSE
	/// Recharge suppression after an absorbed hit
	COOLDOWN_DECLARE(recharge_suppressed)

/obj/machinery/outpost_shield_generator/LateInitialize()
	. = ..()
	link_to_outpost()

/obj/machinery/outpost_shield_generator/Destroy()
	if(outpost)
		outpost.unregister_shield_generator(src)
		outpost = null
	return ..()

/// Finds the player outpost owning this z-level and registers with it.
/// Same z-scan the outpost consoles use, so hand-rebuilt generators relink too.
/obj/machinery/outpost_shield_generator/proc/link_to_outpost()
	if(outpost)
		return
	for(var/obj/structure/overmap/dynamic/player_outpost/candidate as anything in GLOB.player_outposts)
		if(!candidate.mapzone)
			continue
		for(var/datum/space_level/level as anything in candidate.mapzone.z_levels)
			if(level.z_value == z)
				outpost = candidate
				candidate.register_shield_generator(src)
				return

/obj/machinery/outpost_shield_generator/RefreshParts()
	. = ..()
	max_charge = OUTPOST_SHIELD_BASE_CHARGE
	recharge_rate = OUTPOST_SHIELD_BASE_RECHARGE
	for(var/datum/stock_part/capacitor/capacitor in component_parts)
		max_charge += OUTPOST_SHIELD_BASE_CHARGE * OUTPOST_SHIELD_CAPACITOR_CHARGE_MULT * (capacitor.tier - 1)
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		recharge_rate += OUTPOST_SHIELD_BASE_RECHARGE * OUTPOST_SHIELD_LASER_RECHARGE_MULT * (laser.tier - 1)
	charge = min(charge, max_charge)

/// Whether this unit can hold the shield role: anchored, powered, and sitting
/// inside its outpost's build region (a projector dragged onto a docked ship
/// or off the claim does nothing).
/obj/machinery/outpost_shield_generator/proc/is_operational_unit()
	if(!anchored || (machine_stat & (BROKEN | NOPOWER)))
		return FALSE
	return outpost?.is_turf_buildable(get_turf(src))

/// Whether this unit currently holds the outpost's shield role
/obj/machinery/outpost_shield_generator/proc/is_active_unit()
	return outpost && outpost.get_shield_generator() == src

/obj/machinery/outpost_shield_generator/process(seconds_per_tick)
	var/shield_up = is_active_unit() && charge > 0

	// Standbys and dead units don't charge
	if(!is_active_unit())
		set_charging(FALSE)
	else if(charge >= max_charge || !COOLDOWN_FINISHED(src, recharge_suppressed))
		// Full, or suppressed by recent hits. Hold the field, don't charge
		set_charging(FALSE)
	else
		set_charging(TRUE)
		charge = min(charge + recharge_rate * seconds_per_tick, max_charge)
		shield_up = charge > 0

	if(shield_up != was_shield_up)
		was_shield_up = shield_up
		update_appearance()

/// Toggles between active (recharging) and idle (holding) power draw
/obj/machinery/outpost_shield_generator/proc/set_charging(charging)
	update_use_power(charging ? ACTIVE_POWER_USE : IDLE_POWER_USE)

/**
 * Absorbs one siege hit: drains charge, suppresses recharging, and tells both
 * sides what happened. Called via outpost.try_absorb_siege_damage, which has
 * already verified this unit holds the role and has charge.
 */
/obj/machinery/outpost_shield_generator/proc/absorb_hit(damage, turf/impact_loc, obj/structure/overmap/ship/attacker)
	charge = max(charge - damage, 0)
	COOLDOWN_START(src, recharge_suppressed, OUTPOST_SHIELD_RECHARGE_DELAY)

	// Generator-side feedback
	playsound(src, 'voidcrew/sound/machines/forcefield/shieldgen.ogg', 60, TRUE, extrarange = 5)
	var/charge_percent = max_charge > 0 ? round(charge / max_charge * 100) : 0
	if(charge <= 0)
		was_shield_up = FALSE
		update_appearance()
		do_sparks(3, TRUE, src)
		visible_message(span_bolddanger("[src] whines as its deflector field collapses!"))
		playsound(src, 'sound/effects/empulse.ogg', 80, TRUE, extrarange = 10)
		outpost?.ship_notify("SHIELD DEPLETED - incoming fire will hit the outpost!", "SHIELD", SHIP_NOTIFY_DANGER, 'voidcrew/sound/warn.ogg', 40)
	else
		outpost?.ship_notify("Shield absorbed a missile strike. Charge at [charge_percent]%.", "SHIELD", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify.ogg', 25)

	// The besieger learns their shot was eaten
	if(attacker && outpost)
		attacker.ship_notify("Missile detonated against a shield protecting [outpost.display_name][charge <= 0 ? " - the shield has collapsed" : ""].", "WEAPONS", SHIP_NOTIFY_WARNING)

/obj/machinery/outpost_shield_generator/update_icon_state()
	. = ..()
	icon_state = "shieldgen"
	if(was_shield_up && !(machine_stat & (BROKEN | NOPOWER)))
		icon_state += "_on"
	if(panel_open)
		icon_state += "_open"

/obj/machinery/outpost_shield_generator/examine(mob/user)
	. = ..()
	if(!outpost)
		. += span_warning("Not linked to a claim registry. It has to be built on a player outpost.")
		return
	var/charge_percent = max_charge > 0 ? round(charge / max_charge * 100) : 0
	if(!is_operational_unit())
		if(!anchored)
			. += span_warning("It isn't secured to the deck. Wrench it down inside the claim's survey bounds.")
		else if(machine_stat & NOPOWER)
			. += span_warning("It has no power. The field is DOWN.")
		else if(!outpost.is_turf_buildable(get_turf(src)))
			. += span_warning("It's outside [outpost.name]'s survey bounds and can't project a field from here.")
		else
			. += span_warning("It is inoperable.")
	else if(!is_active_unit())
		. += span_notice("STANDBY: another generator currently holds [outpost.name]'s deflector field.")
	else if(charge <= 0)
		. += span_warning("Field DEPLETED. Recharging from outpost power.")
	else
		. += span_notice("Deflector field ACTIVE.")
	. += span_notice("Charge: [round(charge)]/[round(max_charge)] ([charge_percent]%).")
	. += span_notice("Recharge rate: [round(recharge_rate, 0.1)]/sec[COOLDOWN_FINISHED(src, recharge_suppressed) ? "" : " (suppressed by recent impacts)"].")

/obj/machinery/outpost_shield_generator/wrench_act(mob/living/user, obj/item/tool)
	. = ITEM_INTERACT_BLOCKING
	default_unfasten_wrench(user, tool)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/outpost_shield_generator/attackby(obj/item/attacking_item, mob/user, list/modifiers, list/attack_modifiers)
	if(default_deconstruction_screwdriver(user, attacking_item))
		update_appearance()
		return
	if(default_deconstruction_crowbar(user, attacking_item))
		return
	return ..()

// ========== CIRCUIT BOARD / RESEARCH ==========

/obj/item/circuitboard/machine/outpost_shield_generator
	name = "Outpost Shield Generator"
	greyscale_colors = CIRCUIT_COLOR_COMMAND
	build_path = /obj/machinery/outpost_shield_generator
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/micro_laser = 2,
	)

// Unlocked by the Shuttle Shield Systems techweb node (ship_combat/research.dm)
/datum/design/board/outpost_shield_generator
	name = "Outpost Shield Generator Board"
	desc = "Allows for the construction of a deflector shield generator for player-founded outposts."
	id = "outpost_shield_generator"
	research_icon = 'voidcrew/modules/player_outposts/icons/outpost.dmi'
	research_icon_state = "shieldgen"
	build_path = /obj/item/circuitboard/machine/outpost_shield_generator
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_ENGINEERING
	)
	departmental_flags = DEPARTMENT_BITFLAG_ENGINEERING | DEPARTMENT_BITFLAG_SECURITY | DEPARTMENT_BITFLAG_SCIENCE

// ========== MISSILE INTERCEPTION ==========

/**
 * Player-outpost shield interception. Called from missile_effect.dm: on every
 * Moved() step (so the missile detonates at the shield envelope's edge, the
 * outpost's build region, rather than on the target building) and as a
 * last-chance guard at the top of impact().
 *
 * Returns TRUE when the missile was absorbed; the missile then detonates via
 * shield_impact() (no structural damage; chemical payloads are destroyed).
 */
/obj/effect/ship_missile/proc/try_outpost_shield_intercept(turf/current)
	if(exploded || !current)
		return FALSE
	var/obj/structure/overmap/dynamic/player_outpost/outpost = target_ship
	if(!istype(outpost))
		return FALSE
	if(!outpost.is_turf_buildable(current))
		return FALSE // still outside the shield envelope
	// Chemical missiles can carry ~0 listed damage; the shield still pays a minimum toll to stop them
	var/drain = max(damage * OUTPOST_SHIELD_MISSILE_DRAIN_MULT, OUTPOST_SHIELD_MIN_DRAIN)
	if(!outpost.try_absorb_siege_damage(drain, current, source_ship))
		return FALSE
	new /obj/effect/temp_visual/ship_shield_hit(current)
	shield_impact()
	return TRUE
