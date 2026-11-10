/**
 * # Exotic utilizer
 *
 * A handheld emitter that runs whatever effect its exotic battery holds. Switched on from its
 * own small window (attack_self), never from an action button.
 *
 * - A field effect runs without a break; a burst effect builds up and lets go on its own rhythm,
 *   at twice the rate the artifact itself refilled. Either costs ARTIFACT_UTILIZER_DRAIN charge a
 *   second, so a full battery lasts about six and a half minutes.
 * - A contact effect waits until the holder presses the prongs to someone (themselves included),
 *   at ARTIFACT_UTILIZER_TOUCH_COST a use: ten uses from a full battery.
 * - Whoever switched it on answers for the harm it does (set_responsible), and every contact use
 *   is logged like a weapon hit. Its holder and anyone else in reach are affected alike.
 * - It goes dark inside a trader outpost, as artifacts do.
 * - Healing, cell charge and air effects run through the effect's own code, so the shared heal
 *   cap, the cell rules and the planet-air guard all still apply. It makes no charge of its own.
 *
 * Rewritten from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/obj/particle_battery.dm
 * (/obj/item/xenoarch/xenoarch_utilizer), with its HTML window replaced by tgui (AnomalyUtilizer.tsx)
 * and its timer mode dropped. Art: Nova's machinery.dmi utilizer states (CC BY-SA 3.0, pixel-checked
 * clean against Goon), with core and prong masks drawn for Voidcrew. Sounds and hums are the
 * energy kind's own (core/artifact_energy_kinds.dm).
 *
 * Ship saves delete it like any item, battery and all, so it can never come back charged.
 */

/// How long each process keeps the battery's effect awake: well past the next SSobj tick, so it
/// never lapses while on, even when the server lags. Switching off puts it to sleep at once.
#define UTILIZER_WAKE_MARGIN (10 SECONDS)

/obj/item/anomaly_utilizer
	name = "exotic utilizer"
	desc = "A pronged emitter on a squat grip, with a slot for an exotic battery."
	icon = 'voidcrew/modules/xenoarch/icons/use.dmi'
	icon_state = "utilizer"
	base_icon_state = "utilizer"
	inhand_icon_state = "electronic"
	lefthand_file = 'icons/mob/inhands/items/devices_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/devices_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	item_flags = NOBLUDGEON
	light_system = OVERLAY_LIGHT
	light_range = 2
	light_power = 0.8
	light_on = FALSE
	custom_materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
	)
	/// The battery in its slot
	var/obj/item/anomaly_battery/battery
	/// Switched on and giving off its effect
	var/emitting = FALSE
	/// The energy kind's hum while it runs
	var/datum/looping_sound/hum

/obj/item/anomaly_utilizer/Destroy(force)
	switch_off(quiet = TRUE)
	QDEL_NULL(battery)
	QDEL_NULL(hum)
	return ..()

/// The effect it would run, or null with no battery or an empty one.
/obj/item/anomaly_utilizer/proc/loaded_effect()
	return battery?.held_effect

/// Whether it may run here: never inside a trader outpost.
/obj/item/anomaly_utilizer/proc/is_damped()
	return is_trader_outpost_protected(src)

// ===== Battery slot =====

/obj/item/anomaly_utilizer/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/anomaly_battery))
		return NONE
	if(battery)
		balloon_alert(user, "slot's taken!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	battery = tool
	to_chat(user, span_notice("You slide [tool] into [src] until it clicks."))
	playsound(src, 'sound/items/weapons/gun/general/magazine_insert_full.ogg', 30, TRUE)
	update_appearance()
	SStgui.update_uis(src)
	return ITEM_INTERACT_SUCCESS

/obj/item/anomaly_utilizer/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != battery)
		return
	switch_off(quiet = QDELETED(src))
	battery = null
	if(!QDELETED(src))
		update_appearance()
		SStgui.update_uis(src)

/obj/item/anomaly_utilizer/proc/eject_battery(mob/living/user)
	if(!battery)
		return FALSE
	var/obj/item/anomaly_battery/ejected = battery
	switch_off()
	ejected.forceMove(drop_location())
	if(user)
		user.put_in_hands(ejected)
	playsound(src, 'sound/items/weapons/gun/general/magazine_remove_full.ogg', 30, TRUE)
	return TRUE

// ===== Switching =====

/// Switches it on. Returns TRUE if it started.
/obj/item/anomaly_utilizer/proc/switch_on(mob/living/user)
	if(emitting)
		return FALSE
	var/datum/artifact_effect/effect = loaded_effect()
	if(!effect || battery.stored_charge <= 0)
		playsound(src, 'sound/machines/click.ogg', 30, TRUE)
		if(user)
			balloon_alert(user, "nothing happens")
		return FALSE
	if(is_damped())
		playsound(src, 'sound/machines/click.ogg', 30, TRUE)
		if(user)
			to_chat(user, span_warning("[src] clicks, but its prongs stay dark."))
		return FALSE
	emitting = TRUE
	effect.set_responsible(user)
	effect.wake(UTILIZER_WAKE_MARGIN)
	START_PROCESSING(SSobj, src)

	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	playsound(src, kind.wake_sound, 40, TRUE)
	QDEL_NULL(hum)
	if(kind.hum_type)
		hum = new kind.hum_type(src)
		hum.start()
	visible_message(span_notice("[src] hums to life, its prongs glowing [anomaly_glow_word(kind.key)]."))
	if(user)
		user.log_message("switched on [src] holding [effect.log_name] ([effect.release_method], [effect.strength]).", effect.harmful ? LOG_ATTACK : LOG_GAME)
	update_glow()
	update_appearance()
	SStgui.update_uis(src)
	return TRUE

/// Switches it off. `message` is shown to anyone watching; `quiet` skips sound and updates (deletion).
/obj/item/anomaly_utilizer/proc/switch_off(message, quiet = FALSE)
	if(!emitting)
		return
	emitting = FALSE
	STOP_PROCESSING(SSobj, src)
	var/datum/artifact_effect/effect = loaded_effect()
	effect?.deactivate()
	hum?.stop()
	if(quiet)
		return
	if(message)
		visible_message(span_notice(message))
	playsound(src, 'sound/effects/stealthoff.ogg', 30, TRUE)
	update_glow()
	update_appearance()
	SStgui.update_uis(src)

/obj/item/anomaly_utilizer/process(seconds_per_tick)
	var/datum/artifact_effect/effect = loaded_effect()
	if(!emitting || !effect)
		switch_off()
		return PROCESS_KILL
	if(is_damped())
		switch_off("[src] crackles and goes dark.")
		return PROCESS_KILL
	var/old_level = battery.charge_level()
	switch(effect.release_method)
		if(ARTIFACT_RELEASE_AURA)
			battery.use_charge(ARTIFACT_UTILIZER_DRAIN * seconds_per_tick)
			// The battery pays for a field that never rests.
			effect.current_charge = effect.maximum_charges
		if(ARTIFACT_RELEASE_PULSE)
			battery.use_charge(ARTIFACT_UTILIZER_DRAIN * seconds_per_tick)
			effect.current_charge = min(effect.maximum_charges, effect.current_charge + ARTIFACT_UTILIZER_PULSE_FEED * seconds_per_tick)
	var/store_before = effect.current_charge
	effect.wake(UTILIZER_WAKE_MARGIN)
	effect.tick(seconds_per_tick)
	if(QDELETED(src))
		return PROCESS_KILL
	if(effect.release_method == ARTIFACT_RELEASE_PULSE && effect.current_charge < store_before)
		burst_visuals(artifact_energy_kind(effect.energy_kind))
	if(battery.stored_charge <= 0)
		switch_off("[src] sputters and goes dark.")
		return PROCESS_KILL
	if(battery.charge_level() != old_level)
		update_appearance()

// ===== Contact =====

/obj/item/anomaly_utilizer/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	var/datum/artifact_effect/effect = loaded_effect()
	if(!emitting || effect?.release_method != ARTIFACT_RELEASE_TOUCH)
		return NONE
	return touch_with(interacting_with, user)

/// Presses the prongs to `target`, letting the battery's contact effect act on them.
/obj/item/anomaly_utilizer/proc/touch_with(mob/living/target, mob/living/user)
	var/datum/artifact_effect/effect = loaded_effect()
	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	user.changeNext_move(CLICK_CD_MELEE)
	user.do_attack_animation(target)
	effect.set_responsible(user)
	effect.current_charge = max(effect.current_charge, effect.touch_cost)
	if(target == user)
		user.visible_message(
			span_warning("[user] presses [src] to [user.p_them()]self. Its prongs flare [anomaly_glow_word(kind.key)]."),
			span_warning("You press [src] to yourself. Its prongs flare [anomaly_glow_word(kind.key)]."),
		)
	else
		user.visible_message(
			span_warning("[user] presses [src] against [target]. Its prongs flare [anomaly_glow_word(kind.key)]."),
			span_warning("You press [src] against [target]. Its prongs flare [anomaly_glow_word(kind.key)]."),
			ignored_mobs = target,
		)
		to_chat(target, span_userdanger("[user] presses [src] against you!"))
	log_combat(user, target, "touched", src, "([effect.log_name])")
	effect.touch(target)
	battery?.use_charge(ARTIFACT_UTILIZER_TOUCH_COST)
	burst_visuals(kind)
	if(!battery || battery.stored_charge <= 0)
		switch_off("[src] sputters and goes dark.")
	else
		update_appearance()
	SStgui.update_uis(src)
	return ITEM_INTERACT_SUCCESS

// ===== Looks =====

/// The swell and flash of a burst or a contact.
/obj/item/anomaly_utilizer/proc/burst_visuals(datum/artifact_energy_kind/kind)
	if(!kind)
		return
	playsound(src, kind.pulse_sound, 45, TRUE)
	var/matrix/swell = matrix()
	swell.Scale(1.2)
	animate(src, transform = swell, time = 0.12 SECONDS, easing = SINE_EASING | EASE_OUT)
	animate(transform = matrix(), time = 0.35 SECONDS, easing = SINE_EASING | EASE_IN)
	var/mutable_appearance/flare = mutable_appearance(icon, "utilizer_tips")
	flare.color = kind.color
	var/atom/movable/flare_visual = flick_overlay_view(flare, 0.6 SECONDS)
	if(flare_visual)
		flare_visual.add_filter("flare_glow", 1, drop_shadow_filter(0, 0, 3, 0, "[kind.color]cc"))
		animate(flare_visual, alpha = 0, time = 0.6 SECONDS, easing = SINE_EASING | EASE_IN)

/// The breathing glow and light while it runs.
/obj/item/anomaly_utilizer/proc/update_glow()
	var/datum/artifact_effect/effect = loaded_effect()
	if(!emitting || !effect)
		remove_filter("utilizer_glow")
		set_light_on(FALSE)
		return
	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	add_filter("utilizer_glow", 2, drop_shadow_filter(0, 0, 1.5, 0, "[kind.color]40"))
	transition_filter_chain("utilizer_glow", -1, \
		FilterChainStep(list("color" = "[kind.color]b0", "size" = 2), 0.8 SECONDS, SINE_EASING), \
		FilterChainStep(list("color" = "[kind.color]40", "size" = 1.5), 0.8 SECONDS, SINE_EASING))
	// A light or darkness effect lights its battery itself; the utilizer stays out of its way.
	if(effect.light_override())
		set_light_on(FALSE)
		return
	set_light_color(kind.color)
	set_light_on(TRUE)

/obj/item/anomaly_utilizer/update_icon_state()
	icon_state = battery ? "[base_icon_state][battery.charge_level()]" : base_icon_state
	return ..()

/obj/item/anomaly_utilizer/update_overlays()
	. = ..()
	if(!battery)
		return
	var/datum/artifact_energy_kind/kind = battery.lit_kind()
	. += anomaly_core_overlays(src, "utilizer_core", kind, battery.charge_fraction())
	if(emitting && kind)
		var/mutable_appearance/tips = mutable_appearance(icon, "utilizer_tips")
		tips.color = kind.color
		. += tips
		. += emissive_appearance(icon, "utilizer_tips", src)

/obj/item/anomaly_utilizer/examine(mob/user)
	. = ..()
	if(!battery)
		. += "Its battery slot is empty."
		return
	. += "An exotic battery sits in its slot."
	. += anomaly_core_description(battery.lit_kind(), battery.charge_fraction())
	if(emitting)
		var/datum/artifact_energy_kind/kind = battery.held_kind()
		. += span_notice("It hums, its prongs glowing [anomaly_glow_word(kind?.key)].")

// ===== Window =====

/obj/item/anomaly_utilizer/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AnomalyUtilizer", name)
		ui.open()

/obj/item/anomaly_utilizer/ui_data(mob/user)
	var/list/data = list()
	data["emitting"] = emitting
	if(battery)
		var/datum/artifact_effect/effect = loaded_effect()
		var/datum/artifact_energy_kind/kind = battery.lit_kind()
		var/mode
		switch(effect?.release_method)
			if(ARTIFACT_RELEASE_AURA)
				mode = "field"
			if(ARTIFACT_RELEASE_PULSE)
				mode = "burst"
			if(ARTIFACT_RELEASE_TOUCH)
				mode = "contact"
		data["cell"] = list(
			"fill" = round(battery.charge_fraction(), 0.01),
			"color" = kind?.color,
			"serial" = battery.source_serial,
			"mode" = kind ? mode : null,
		)
	else
		data["cell"] = null
	return data

/obj/item/anomaly_utilizer/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	switch(action)
		if("power")
			if(emitting)
				switch_off("[src] winds down.")
			else
				switch_on(user)
			return TRUE
		if("eject")
			eject_battery(user)
			return TRUE

/datum/design/anomaly_utilizer
	name = "Exotic Utilizer"
	desc = "A handheld emitter that runs whatever an exotic battery holds."
	id = "xenoarch_utilizer"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 2,
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = SHEET_MATERIAL_AMOUNT,
		/datum/material/plasma = SHEET_MATERIAL_AMOUNT,
	)
	build_path = /obj/item/anomaly_utilizer
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

#undef UTILIZER_WAKE_MARGIN
