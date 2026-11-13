// Package: P3 heat. Furnace heat: gain per shot, cooling from turf air in process(), boiling, the
// manual vent, the post-vent firing lock, boil damage and the coil overlay steps.
// Only guns with uses_heat gain heat, and a gun processes on SSobj only while barrel_heat is above 0.

/// Raises heat by `amount`, boils if due, and starts cooling.
/obj/item/gun/energy/plasma_weapon/proc/add_heat(amount)
	if(!uses_heat || QDELETED(src))
		return
	barrel_heat = max(barrel_heat + amount, 0)
	if(barrel_heat >= PLASMA_HEAT_BOIL)
		boil()
		if(QDELETED(src))
			return
	if(barrel_heat > 0)
		START_PROCESSING(SSobj, src)
	update_heat_step()

/// Too hot after a shot: the chamber spits plasma and the gun takes damage, whether or not there was plasma to spit.
/obj/item/gun/energy/plasma_weapon/proc/boil()
	var/turf/where = get_turf(src)
	vent_plasma(PLASMA_BOIL_MOL, null, TRUE)
	barrel_heat = max(barrel_heat - PLASMA_BOIL_COOL, 0)
	if(where)
		where.visible_message(span_warning("[src] hisses and spits gas!"))
		playsound(where, PLASMA_SOUND_FURNACE_BOIL, 50, TRUE)
	take_damage(PLASMA_BOIL_INTEGRITY, sound_effect = FALSE)

/// Takes up to `mol` from the chamber and releases it on the turf at the barrel's temperature. Returns mol released.
/// Only what left the chamber is released, so a short chamber vents what it has.
/obj/item/gun/energy/plasma_weapon/proc/vent_plasma(mol, mob/user, boil = FALSE)
	var/turf/open/where = get_turf(src)
	if(!istype(where) || mol <= 0)
		return 0
	var/taken = take_mol(mol)
	if(taken <= 0)
		return 0
	var/gas_temp = min(T20C + barrel_heat * PLASMA_VENT_TEMP_PER_HEAT, PLASMA_VENT_TEMP_MAX)
	where.atmos_spawn_air("[GAS_PLASMA]=[taken];[TURF_TEMPERATURE(gas_temp)]")
	plasma_vent_puff(where)
	return taken

/// FALSE while a vent blocks firing
/obj/item/gun/energy/plasma_weapon/proc/can_fire_heat()
	return world.time >= vent_lock_until

/// Updates the coil overlay step and the inhand
/obj/item/gun/energy/plasma_weapon/proc/update_heat_step()
	var/new_step = 0
	if(barrel_heat >= PLASMA_HEAT_STEP_3)
		new_step = 3
	else if(barrel_heat >= PLASMA_HEAT_STEP_2)
		new_step = 2
	else if(barrel_heat >= PLASMA_HEAT_STEP_1)
		new_step = 1
	if(new_step == heat_step)
		return
	heat_step = new_step
	update_appearance(UPDATE_OVERLAYS)
	update_inhand_icon()

/obj/item/gun/energy/plasma_weapon/process(seconds_per_tick)
	if(!uses_heat || barrel_heat <= 0)
		barrel_heat = 0
		update_heat_step()
		STOP_PROCESSING(SSobj, src)
		return
	var/rate = heat_cool_rate()
	var/new_heat = barrel_heat - rate * seconds_per_tick
	// Hot surroundings bring the barrel up to the boil point, never past it; only a shot boils.
	if(rate < 0)
		new_heat = min(new_heat, max(barrel_heat, PLASMA_HEAT_BOIL))
	barrel_heat = max(new_heat, 0)
	update_heat_step()
	if(barrel_heat <= 0)
		STOP_PROCESSING(SSobj, src)

/// Heat lost per second where the gun is now, from its turf's air. Negative in hot surroundings.
/obj/item/gun/energy/plasma_weapon/proc/heat_cool_rate()
	. = PLASMA_COOL_BASE
	var/turf/where = get_turf(src)
	var/datum/gas_mixture/air = where?.return_air()
	if(!air)
		return
	var/kelvin = air.return_temperature()
	var/pressure_factor = min(air.return_pressure() / PLASMA_COOL_PRESSURE_REF, PLASMA_COOL_PRESSURE_CAP)
	var/temp_factor = clamp((PLASMA_COOL_HOT_TEMP - kelvin) / PLASMA_COOL_TEMP_SPAN, 0, PLASMA_COOL_TEMP_CAP)
	. += PLASMA_COOL_CONVECT * pressure_factor * temp_factor
	if(kelvin > PLASMA_COOL_HOT_TEMP)
		. -= min(PLASMA_HEAT_GAIN_MAX, (kelvin - PLASMA_COOL_HOT_TEMP) / PLASMA_HEAT_GAIN_SPAN)

/obj/item/gun/energy/plasma_weapon/attack_self(mob/living/user)
	. = ..()
	if(.)
		return
	// A barrel not hot enough to glow has nothing to vent
	if(!uses_heat || world.time < next_vent_at || barrel_heat < PLASMA_HEAT_STEP_1)
		return
	var/vented = vent_plasma(PLASMA_VENT_MOL, user)
	if(!vented)
		return
	next_vent_at = world.time + PLASMA_VENT_COOLDOWN
	vent_lock_until = world.time + PLASMA_VENT_LOCK
	// A short chamber vents less and cools less
	barrel_heat = max(barrel_heat - PLASMA_VENT_COOL * vented / PLASMA_VENT_MOL, 0)
	playsound(src, PLASMA_SOUND_FURNACE_VENT, 50, TRUE)
	update_heat_step()
	return TRUE

/obj/item/gun/energy/plasma_weapon/update_overlays()
	. = ..()
	if(!uses_heat || !heat_step)
		return
	. += mutable_appearance(icon, "furnace_glow_[heat_step]")
	. += emissive_appearance(icon, "furnace_glow_[heat_step]", src)

/obj/item/gun/energy/plasma_weapon/worn_overlays(mutable_appearance/standing, isinhands = FALSE, icon_file)
	. = ..()
	if(!isinhands || !uses_heat || !heat_step)
		return
	. += mutable_appearance(icon_file, "furnace_glow_[heat_step]")
	. += emissive_appearance(icon_file, "furnace_glow_[heat_step]", src)
