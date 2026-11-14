// Package: P3 heat. Furnace heat: gain per shot, cooling from turf air, the overheat shutdown, the timed vent
// (the vent key, its bar and its four results) and the coil overlay steps.
// Only guns with uses_heat gain heat. Cooling is applied for the time since heat_updated_at whenever heat is
// read or changed, so it doesn't depend on how often SSobj ticks; the gun processes on SSobj only while it is hot,
// venting or shut down, to keep the coil overlay current and end a shutdown whose timer was lost.

/// The cooling rate where `where` is, in heat a second, from its air. Negative in hot surroundings.
/// Shared by the gun and by NPCs that fire one without holding it (plasma_pirates.dm).
/proc/plasma_heat_cool_rate(turf/where)
	. = PLASMA_COOL_BASE
	var/datum/gas_mixture/air = where?.return_air()
	if(!air)
		return
	var/kelvin = air.return_temperature()
	var/pressure_factor = min(air.return_pressure() / PLASMA_COOL_PRESSURE_REF, PLASMA_COOL_PRESSURE_CAP)
	var/temp_factor = clamp((PLASMA_COOL_HOT_TEMP - kelvin) / PLASMA_COOL_TEMP_SPAN, 0, PLASMA_COOL_TEMP_CAP)
	. += PLASMA_COOL_CONVECT * pressure_factor * temp_factor
	if(kelvin > PLASMA_COOL_HOT_TEMP)
		. -= min(PLASMA_HEAT_GAIN_MAX, (kelvin - PLASMA_COOL_HOT_TEMP) / PLASMA_HEAT_GAIN_SPAN)

/// `heat` after `seconds` at cooling `rate`. Hot surroundings bring it up to the max, never past; only a shot overheats.
/proc/plasma_heat_cooled(heat, rate, seconds)
	var/new_heat = heat - rate * seconds
	if(rate < 0)
		new_heat = min(new_heat, max(heat, PLASMA_HEAT_MAX))
	return max(new_heat, 0)

/// The vent bar zone a tap `elapsed` deciseconds into the sweep lands in. PLASMA_VENT_RESULT_NONE past the end.
/// ----yyyyxxxyyyy----: fail, grace, gold, grace, fail.
/proc/plasma_vent_zone(elapsed)
	if(elapsed < 0 || elapsed >= PLASMA_VENT_SWEEP)
		return PLASMA_VENT_RESULT_NONE
	var/unit = elapsed * PLASMA_VENT_UNITS / PLASMA_VENT_SWEEP
	if(unit < PLASMA_VENT_FAIL_END)
		return PLASMA_VENT_RESULT_FAIL
	if(unit < PLASMA_VENT_GRACE_END)
		return PLASMA_VENT_RESULT_GRACE
	if(unit < PLASMA_VENT_GOLD_END)
		return PLASMA_VENT_RESULT_GOLD
	if(unit < PLASMA_VENT_GRACE2_END)
		return PLASMA_VENT_RESULT_GRACE
	return PLASMA_VENT_RESULT_FAIL

/// Raises heat by `amount` (less in a gold window), overheats the gun if that brings it to the max, and starts processing.
/obj/item/gun/energy/plasma_weapon/proc/add_heat(amount)
	if(!uses_heat || QDELETED(src))
		return
	cool_to_now()
	if(is_shut_down())
		return
	if(amount > 0 && world.time < gold_until)
		amount *= PLASMA_VENT_GOLD_HEAT_MULT
	barrel_heat = max(barrel_heat + amount, 0)
	if(barrel_heat >= PLASMA_HEAT_MAX)
		overheat()
	if(barrel_heat > 0)
		START_PROCESSING(SSobj, src)
	update_heat_step()

/// Applies the cooling since heat_updated_at. A cold gun and a shut-down one don't change.
/obj/item/gun/energy/plasma_weapon/proc/cool_to_now()
	var/elapsed = (world.time - heat_updated_at) / (1 SECONDS)
	heat_updated_at = world.time
	if(elapsed > 0)
		cool(elapsed)

/// Cools (or, in hot surroundings, heats) the barrel for `seconds` where it is now
/obj/item/gun/energy/plasma_weapon/proc/cool(seconds)
	if(!uses_heat || barrel_heat <= 0 || is_shut_down())
		return
	barrel_heat = plasma_heat_cooled(barrel_heat, heat_cool_rate(), seconds)

/// Heat lost per second where the gun is now. Negative in hot surroundings.
/obj/item/gun/energy/plasma_weapon/proc/heat_cool_rate()
	return plasma_heat_cool_rate(get_turf(src))

/obj/item/gun/energy/plasma_weapon/proc/is_shut_down()
	return world.time < shutdown_until

/// A shot brought the barrel to the max: the coils lock up and the gun can't fire or vent for a while
/obj/item/gun/energy/plasma_weapon/proc/overheat()
	cancel_vent()
	barrel_heat = PLASMA_HEAT_MAX
	gold_until = 0
	shutdown_until = world.time + PLASMA_OVERHEAT_SHUTDOWN
	addtimer(CALLBACK(src, PROC_REF(end_shutdown)), PLASMA_OVERHEAT_SHUTDOWN, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_DELETE_ME)
	var/turf/where = get_turf(src)
	if(where)
		where.visible_message(span_warning("[src]'s coils lock up!"))
	playsound(src, PLASMA_SOUND_FURNACE_OVERHEAT, 50, TRUE)

/// The shutdown is over: the gun comes back cooler and can fire
/obj/item/gun/energy/plasma_weapon/proc/end_shutdown()
	if(!shutdown_until || is_shut_down())
		return
	shutdown_until = 0
	barrel_heat = PLASMA_OVERHEAT_END_HEAT
	heat_updated_at = world.time
	playsound(src, PLASMA_SOUND_FURNACE_RECOVER, 40, TRUE, -2)
	update_heat_step()

/// FALSE while a vent or an overheat blocks firing
/obj/item/gun/energy/plasma_weapon/proc/can_fire_heat()
	// A shutdown whose timer was lost still ends on time
	if(shutdown_until && !is_shut_down())
		end_shutdown()
	return !vent_started_at && !is_shut_down() && world.time >= vent_lock_until

/// Takes up to `mol` from the chamber and releases it on the turf at the barrel's temperature. Returns mol released.
/// Only what left the chamber is released, so a short chamber vents what it has.
/obj/item/gun/energy/plasma_weapon/proc/vent_plasma(mol)
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

/// The vent key: starts a vent, or times the one running. TRUE if it did either.
/obj/item/gun/energy/plasma_weapon/proc/vent_key(mob/living/user)
	if(vent_started_at)
		if(user != vent_user)
			return FALSE
		vent_tap()
		return TRUE
	return start_vent(user)

/// Starts a vent if `user` holds this in the active hand and its coils glow. TRUE if it started.
/obj/item/gun/energy/plasma_weapon/proc/start_vent(mob/living/user)
	if(!uses_heat || vent_started_at || QDELETED(user) || user.stat != CONSCIOUS)
		return FALSE
	if(HAS_TRAIT(user, TRAIT_INCAPACITATED) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(user.get_active_held_item() != src || !can_fire_heat())
		return FALSE
	cool_to_now()
	// A barrel not hot enough to glow has nothing to vent
	if(barrel_heat < PLASMA_HEAT_STEP_1)
		return FALSE
	vent_started_at = world.time
	vent_user = user
	RegisterSignals(user, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_vent_user_lost))
	vent_timer = addtimer(CALLBACK(src, PROC_REF(finish_vent_sweep)), PLASMA_VENT_SWEEP, TIMER_STOPPABLE|TIMER_DELETE_ME)
	START_PROCESSING(SSobj, src)
	show_vent_bar(user)
	playsound(src, PLASMA_SOUND_VENT_START, 40, TRUE, -2)
	return TRUE

/// The vent key pressed again during the sweep: judged on the server's own clock against the sweep start
/obj/item/gun/energy/plasma_weapon/proc/vent_tap()
	if(!vent_started_at)
		return
	var/result = plasma_vent_zone(world.time - vent_started_at)
	// A tap after the end changes nothing; the sweep's end settles it
	if(result == PLASMA_VENT_RESULT_NONE)
		return
	resolve_vent(result)

/// The marker reached the end with no tap
/obj/item/gun/energy/plasma_weapon/proc/finish_vent_sweep()
	vent_timer = null
	if(vent_started_at)
		resolve_vent(PLASMA_VENT_RESULT_NONE)

/// Ends the running vent with `result`'s heat, lock, gas and sound
/obj/item/gun/energy/plasma_weapon/proc/resolve_vent(result)
	end_vent()
	cool_to_now()
	switch(result)
		if(PLASMA_VENT_RESULT_GOLD)
			barrel_heat = 0
			gold_until = world.time + PLASMA_VENT_GOLD_WINDOW
			playsound(src, PLASMA_SOUND_VENT_GOLD, 50, TRUE)
		if(PLASMA_VENT_RESULT_GRACE)
			barrel_heat = max(barrel_heat - PLASMA_VENT_COOL, 0)
			playsound(src, PLASMA_SOUND_VENT_GRACE, 50, TRUE)
		if(PLASMA_VENT_RESULT_NONE)
			barrel_heat = max(barrel_heat - PLASMA_VENT_COOL, 0)
			vent_lock_until = world.time + PLASMA_VENT_NONE_LOCK
			playsound(src, PLASMA_SOUND_VENT_GRACE, 50, TRUE)
		if(PLASMA_VENT_RESULT_FAIL)
			// The gas leaves at the barrel's heat before the vent cools it
			vent_plasma(PLASMA_VENT_MOL)
			barrel_heat = max(barrel_heat - PLASMA_VENT_COOL, 0)
			vent_lock_until = world.time + PLASMA_VENT_FAIL_LOCK
			var/turf/where = get_turf(src)
			if(where)
				where.visible_message(span_warning("[src] hisses and spits gas!"))
			playsound(src, PLASMA_SOUND_VENT_FAIL, 50, TRUE)
	update_heat_step()

/// Stops a running vent without a result: the gun left the hand, or its holder can't go on
/obj/item/gun/energy/plasma_weapon/proc/cancel_vent()
	if(vent_started_at)
		end_vent()

/obj/item/gun/energy/plasma_weapon/proc/on_vent_user_lost(datum/source)
	SIGNAL_HANDLER
	cancel_vent()

/// Clears the running vent's state, timer, signals and bar
/obj/item/gun/energy/plasma_weapon/proc/end_vent()
	vent_started_at = 0
	if(vent_timer)
		deltimer(vent_timer)
		vent_timer = null
	if(vent_user)
		UnregisterSignal(vent_user, list(COMSIG_MOB_SWAP_HANDS, COMSIG_MOB_LOGOUT, COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		vent_user = null
	hide_vent_bar()

/obj/item/gun/energy/plasma_weapon/dropped(mob/user, silent = FALSE)
	cancel_vent()
	return ..()

/obj/item/gun/energy/plasma_weapon/equipped(mob/user, slot, initial = FALSE)
	. = ..()
	if(vent_started_at && (user != vent_user || user.get_active_held_item() != src))
		cancel_vent()

/// Updates the coil overlay step and the inhand. The coil ticks as it reaches the last step before an overheat.
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
	if(new_step == 3 && heat_step < 3 && !is_shut_down())
		playsound(src, PLASMA_SOUND_FURNACE_WARN, 40, TRUE, -2)
	heat_step = new_step
	update_appearance(UPDATE_OVERLAYS)
	update_inhand_icon()

/obj/item/gun/energy/plasma_weapon/process(seconds_per_tick)
	if(!uses_heat)
		return PROCESS_KILL
	if(shutdown_until && !is_shut_down())
		end_shutdown()
	cool_to_now()
	update_heat_step()
	if(barrel_heat <= 0 && !shutdown_until && !vent_started_at)
		barrel_heat = 0
		return PROCESS_KILL

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
