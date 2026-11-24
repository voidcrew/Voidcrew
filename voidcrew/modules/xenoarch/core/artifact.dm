/**
 * # Large alien artifact
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/artifacts/artifact_machine.dm,
 * reworked for Voidcrew:
 * - Effects roll by the band the find was dug in (tier odds and strength), and the find is
 *   stamped with that band, a catalogue serial, and later a crew's label.
 * - A stimulus wakes a matching effect for a while (ARTIFACT_WAKE_MIN to _MAX); level triggers
 *   (heat, cold, plasma or CO2 in the air, someone nearby) hold it awake while they last.
 *   Oxygen and nitrogen triggers are gone. Air is read with return_air_readonly(), so an idle
 *   artifact never gives a planet turf its own private air.
 * - It does nothing off a turf (crated, carried in a mech) or inside a trader outpost.
 * - Anyone can bolt it down with a wrench, except inside a trader outpost.
 * - Scan and harvest machines lock it through try_lock()/release_lock(); a lock frees itself
 *   when its holder is deleted or after ARTIFACT_LOCK_TIMEOUT (Nova's halt never unlocked it).
 * - Smashing it lets harmful effects off in one last burst, never helpful ones, and an admin
 *   delete or planet unload does nothing at all.
 *
 * Looks, sounds and examine text are in artifact_appearance.dm.
 */
/obj/machinery/artifact
	name = "alien artifact"
	desc = "A large object of no make you recognise."
	icon = 'voidcrew/modules/xenoarch/icons/artifacts.dmi'
	icon_state = "pylon"
	density = TRUE
	anchored = FALSE
	use_power = NO_POWER_USE
	// No UI and no power: a hand on it is a touch, nothing else.
	interaction_flags_atom = NONE
	interaction_flags_machine = INTERACT_MACHINE_OFFLINE
	max_integrity = 1000
	resistance_flags = LAVA_PROOF | FIRE_PROOF | ACID_PROOF

	/// ZONE_* it was dug in, or null if it never came out of the ground. Price and research read this.
	var/origin_band
	/// Catalogue number, such as "Kappa-4412"
	var/serial
	/// The label a crew stuck on it, if any
	var/datum/artifact_label/label
	/// Harvests a harvester may still drain from it
	var/harvests_left = ARTIFACT_MAX_HARVESTS
	/// Its first full analysis has paid research points. Stays with the artifact whichever crew holds it.
	var/research_paid = FALSE
	/// Came out of the rock unstabilised. Sells for less.
	var/damaged = FALSE
	/// The effect it is named and priced for
	var/datum/artifact_effect/main_effect
	/// A minor second effect, or null
	var/datum/artifact_effect/second_effect
	/// Rolls its own effects on Initialize. Finds that are not true artifacts turn this off.
	var/rolls_effects = TRUE

	/// How long one contact stimulus keeps an effect awake; rolled once per artifact
	var/wake_duration = ARTIFACT_WAKE_MIN
	/// Whoever last woke, struck, splashed or hauled it. Logged for any harm it does.
	var/datum/weakref/last_disturbed_by
	/// Last time a touch counted, so hauling and bumping count once per ARTIFACT_TOUCH_COOLDOWN
	var/last_touch_time = 0
	/// Effects are held asleep: it is off a turf or inside a trader outpost
	var/suppressed = FALSE

	/// The scan or harvest machine using it, if any
	var/datum/weakref/locked_by
	/// world.time the lock lapses if never released
	var/lock_expires = 0

/obj/machinery/artifact/Initialize(mapload, band)
	. = ..()
	serial = xenoarch_new_serial()
	wake_duration = rand(ARTIFACT_WAKE_MIN, ARTIFACT_WAKE_MAX)
	setup_shape()
	if(rolls_effects)
		roll_effects(band)
	if(!isnull(band))
		stamp_origin(band)
	suppressed = is_suppressed()
	update_activity_visuals()

/obj/machinery/artifact/Destroy()
	locked_by = null
	last_disturbed_by = null
	clear_activity_visuals()
	QDEL_NULL(main_effect)
	QDEL_NULL(second_effect)
	QDEL_NULL(label)
	return ..()

/// Both effects, skipping a missing second.
/obj/machinery/artifact/proc/effects()
	. = list()
	if(main_effect)
		. += main_effect
	if(second_effect)
		. += second_effect

/// Any effect awake.
/obj/machinery/artifact/proc/is_active()
	return main_effect?.activated || second_effect?.activated

// ===== Rolling =====

/// Rolls a main effect from the band's tier odds and, half the time, a minor second effect.
/obj/machinery/artifact/proc/roll_effects(band)
	var/main_type = xenoarch_pick_effect_type(xenoarch_roll_tier(band), band)
	var/second_type
	if(main_type && prob(ARTIFACT_SECOND_EFFECT_CHANCE))
		second_type = xenoarch_pick_effect_type(null, band, minor_only = TRUE, exclude = main_type)
	replace_effects(main_type, second_type, band)

/// Swaps both effects for new ones of the given types (second may be null). For rolling, tests and admins.
/obj/machinery/artifact/proc/replace_effects(main_type, second_type, band)
	QDEL_NULL(main_effect)
	QDEL_NULL(second_effect)
	if(main_type)
		main_effect = new main_type(src, band)
	if(second_type)
		second_effect = new second_type(src, band)
	update_activity_visuals(force = TRUE)

// ===== Seams read by other parts =====

/// Whether it came out of a dig site. Buyers refuse anything else.
/obj/machinery/artifact/proc/is_dug()
	return !isnull(origin_band)

/// How many harvests have been drained from it.
/obj/machinery/artifact/proc/harvests_taken()
	return clamp(ARTIFACT_MAX_HARVESTS - harvests_left, 0, ARTIFACT_MAX_HARVESTS)

/// 0 to 1: how right its label is. 0 with no label.
/obj/machinery/artifact/proc/label_accuracy()
	if(!label || !main_effect)
		return 0
	. = 0
	if(label.effect_name == main_effect.label_name)
		. += ARTIFACT_LABEL_SHARE_EFFECT
	if(label.trigger_name == artifact_trigger_name(main_effect.trigger))
		. += ARTIFACT_LABEL_SHARE_TRIGGER
	var/second_truth = second_effect ? second_effect.label_name : ARTIFACT_LABEL_NONE
	if(label.second_name == second_truth)
		. += ARTIFACT_LABEL_SHARE_SECOND

/// Sticks a new label on, replacing any old one.
/obj/machinery/artifact/proc/apply_label(datum/artifact_label/new_label, mob/user)
	if(label && label != new_label)
		QDEL_NULL(label)
	label = new_label
	SEND_SIGNAL(src, COMSIG_ARTIFACT_LABEL_CHANGED, new_label, user)
	update_appearance()

/// Scrapes the label off.
/obj/machinery/artifact/proc/remove_label(mob/user)
	if(!label)
		return FALSE
	QDEL_NULL(label)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_LABEL_CHANGED, null, user)
	update_appearance()
	return TRUE

/// Marks it as dug in `band`. Only the first stamp counts.
/obj/machinery/artifact/proc/stamp_origin(band)
	if(!isnull(origin_band))
		return FALSE
	origin_band = XENOARCH_BAND_INDEX(band)
	SEND_SIGNAL(src, COMSIG_ARTIFACT_STAMPED, origin_band)
	return TRUE

// ===== Scan and harvest lock =====

/**
 * Claims it for a scan or harvest. Fails while another live machine holds it. The lock frees
 * itself when its holder is deleted or after `duration`, so a crashed or halted scan can never
 * lock an artifact for good.
 */
/obj/machinery/artifact/proc/try_lock(datum/locker, duration = ARTIFACT_LOCK_TIMEOUT)
	if(!locker)
		return FALSE
	if(is_being_used() && locked_by.resolve() != locker)
		return FALSE
	locked_by = WEAKREF(locker)
	lock_expires = world.time + duration
	return TRUE

/// Frees the lock. With a `locker`, only if that is who holds it.
/obj/machinery/artifact/proc/release_lock(datum/locker)
	if(!locked_by)
		return FALSE
	var/datum/holder = locked_by.resolve()
	if(locker && holder && holder != locker)
		return FALSE
	locked_by = null
	lock_expires = 0
	return TRUE

/// Whether a live machine holds the lock (Nova's being_used).
/obj/machinery/artifact/proc/is_being_used()
	if(!locked_by)
		return FALSE
	var/datum/holder = locked_by.resolve()
	if(QDELETED(holder) || world.time >= lock_expires)
		locked_by = null
		lock_expires = 0
		return FALSE
	return TRUE

// ===== Stimuli =====

/// Remembers who set it off, for the combat log.
/obj/machinery/artifact/proc/note_disturbance(mob/user)
	if(ismob(user))
		last_disturbed_by = WEAKREF(user)

/**
 * A stimulus reached it. Wakes every effect whose trigger matches.
 * Returns TRUE if anything matched.
 */
/obj/machinery/artifact/proc/stimulate(trigger, mob/user)
	if(suppressed || QDELETED(src))
		return FALSE
	note_disturbance(user)
	var/woke = FALSE
	for(var/datum/artifact_effect/effect as anything in effects())
		if(effect.trigger == trigger)
			effect.wake(wake_duration)
			woke = TRUE
	SEND_SIGNAL(src, COMSIG_ARTIFACT_STIMULATED, trigger, user, woke)
	return woke

/// Wakes every effect a bitfield of triggers matches.
/obj/machinery/artifact/proc/stimulate_all(triggers, mob/user)
	. = FALSE
	for(var/trigger in ARTIFACT_ALL_TRIGGERS)
		if(triggers & trigger)
			. = stimulate(trigger, user) || .

/**
 * Someone laid a hand on it, or brushed it (bumped, hauled). A bare or non-latex hand wakes
 * touch effects; any touch lets an awake contact effect act on them.
 */
/obj/machinery/artifact/proc/touched_by(mob/living/user, accidental = FALSE)
	if(!isliving(user))
		return
	if(accidental && world.time < last_touch_time + ARTIFACT_TOUCH_COOLDOWN)
		return
	last_touch_time = world.time
	if(!accidental)
		to_chat(user, span_notice("You run your hand over [src]."))
	if(artifact_touch_counts(user))
		stimulate(ARTIFACT_TRIGGER_TOUCH, user)
	else
		note_disturbance(user)
	if(suppressed)
		return
	for(var/datum/artifact_effect/effect as anything in effects())
		if(accidental && prob(50))
			continue
		effect.touch(user)

/obj/machinery/artifact/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !user.Adjacent(src))
		return
	touched_by(user)
	return TRUE

/obj/machinery/artifact/attack_robot(mob/user)
	if(!user.Adjacent(src))
		return ..()
	touched_by(user)
	return TRUE

/obj/machinery/artifact/attack_paw(mob/living/user, list/modifiers)
	if(!user.Adjacent(src))
		return ..()
	touched_by(user)
	return TRUE

/obj/machinery/artifact/Bumped(atom/movable/bumped_atom)
	. = ..()
	if(isliving(bumped_atom))
		touched_by(bumped_atom, accidental = TRUE)

/obj/machinery/artifact/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	refresh_suppression()
	// Hauling it counts as touching it (Nova did this through Move() and Bumped()).
	if(isliving(pulledby))
		touched_by(pulledby, accidental = TRUE)

/obj/machinery/artifact/attacked_by(obj/item/attacking_item, mob/living/user, list/modifiers, list/attack_modifiers)
	note_disturbance(user)
	. = ..()
	if(QDELETED(src))
		return
	if(attacking_item.force > 0)
		stimulate(ARTIFACT_TRIGGER_IMPACT, user)
	if(artifact_tool_is_energetic(attacking_item))
		stimulate(ARTIFACT_TRIGGER_ENERGY, user)
	if(attacking_item.get_temperature() > ARTIFACT_HEAT_TOOL_KELVIN)
		stimulate(ARTIFACT_TRIGGER_HEAT, user)

/obj/machinery/artifact/hitby(atom/movable/hit_by, skipcatch, hitpush, blocked, datum/thrownthing/throwingdatum)
	var/mob/thrower = throwingdatum?.get_thrower()
	note_disturbance(thrower)
	. = ..()
	if(QDELETED(src))
		return
	var/hard_enough = isliving(hit_by)
	if(isobj(hit_by))
		var/obj/thrown_object = hit_by
		hard_enough = thrown_object.throwforce >= ARTIFACT_IMPACT_THROWFORCE
	if(hard_enough)
		stimulate(ARTIFACT_TRIGGER_IMPACT, thrower)

/obj/machinery/artifact/bullet_act(obj/projectile/hitting_projectile, def_zone, piercing_hit = FALSE)
	var/mob/firer = hitting_projectile.firer
	note_disturbance(firer)
	. = ..()
	if(QDELETED(src))
		return
	if(hitting_projectile.armor_flag == LASER || hitting_projectile.armor_flag == ENERGY)
		stimulate(ARTIFACT_TRIGGER_ENERGY, firer)
	else if(hitting_projectile.damage > 0)
		stimulate(ARTIFACT_TRIGGER_IMPACT, firer)

/obj/machinery/artifact/take_damage(damage_amount, damage_type = BRUTE, damage_flag = "", sound_effect = TRUE, attack_dir, armour_penetration = 0)
	. = ..()
	if(QDELETED(src))
		return
	// Hits with a known culprit are handled where they land; these are fires, blasts and arcs.
	switch(damage_flag)
		if(FIRE)
			stimulate(ARTIFACT_TRIGGER_HEAT)
		if(ENERGY, LASER)
			stimulate(ARTIFACT_TRIGGER_ENERGY)
		if(BOMB)
			stimulate(ARTIFACT_TRIGGER_IMPACT)
			stimulate(ARTIFACT_TRIGGER_HEAT)

/obj/machinery/artifact/emp_act(severity)
	. = ..()
	if(!(. & EMP_PROTECT_SELF))
		stimulate(ARTIFACT_TRIGGER_ENERGY)

/obj/machinery/artifact/fire_act(exposed_temperature, exposed_volume)
	. = ..()
	if(exposed_temperature > ARTIFACT_HEAT_AIR_KELVIN)
		stimulate(ARTIFACT_TRIGGER_HEAT)

/obj/machinery/artifact/expose_reagents(list/reagents, datum/reagents/source, methods = TOUCH, volume_modifier = 1, show_message = TRUE)
	. = ..()
	if(. & COMPONENT_NO_EXPOSE_REAGENTS)
		return
	stimulate_all(artifact_reagent_triggers(reagents))

/obj/machinery/artifact/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(is_reagent_container(tool) && tool.is_drainable())
		return splash_with(tool, user)
	if(artifact_tool_is_energetic(tool))
		user.visible_message(
			span_notice("[user] presses [tool] against [src]."),
			span_notice("You press [tool] against [src]."),
		)
		playsound(src, 'sound/effects/sparks/sparks1.ogg', 40, TRUE)
		stimulate(ARTIFACT_TRIGGER_ENERGY, user)
		if(tool.get_temperature() > ARTIFACT_HEAT_TOOL_KELVIN)
			stimulate(ARTIFACT_TRIGGER_HEAT, user)
		return ITEM_INTERACT_SUCCESS
	if(tool.get_temperature() > ARTIFACT_HEAT_TOOL_KELVIN)
		return heat_with(tool, user)
	return NONE

/obj/machinery/artifact/welder_act(mob/living/user, obj/item/tool)
	if(tool.get_temperature() <= ARTIFACT_HEAT_TOOL_KELVIN)
		return NONE
	return heat_with(tool, user)

/// Holds a hot tool to it.
/obj/machinery/artifact/proc/heat_with(obj/item/tool, mob/living/user)
	user.visible_message(
		span_notice("[user] holds [tool] to [src]."),
		span_notice("You hold [tool] to [src] until the surface ticks with heat."),
	)
	playsound(src, 'sound/items/tools/welder.ogg', 30, TRUE)
	stimulate(ARTIFACT_TRIGGER_HEAT, user)
	return ITEM_INTERACT_SUCCESS

/// Splashes a little of an open container over it.
/obj/machinery/artifact/proc/splash_with(obj/item/container, mob/living/user)
	var/datum/reagents/held = container.reagents
	if(!held?.total_volume)
		balloon_alert(user, "empty!")
		return ITEM_INTERACT_BLOCKING
	note_disturbance(user)
	var/amount = min(held.total_volume, 10)
	user.visible_message(
		span_notice("[user] splashes [src] with the contents of [container]."),
		span_notice("You splash [src] with [container]."),
	)
	playsound(src, 'sound/effects/slosh.ogg', 25, TRUE)
	held.expose(src, TOUCH, amount / held.total_volume)
	held.remove_all(amount)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact/wrench_act(mob/living/user, obj/item/tool)
	if(istype(get_area(src), /area/voidcrew/trader_outpost))
		balloon_alert(user, "the deck won't take bolts!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool, 4 SECONDS) == SUCCESSFUL_UNFASTEN)
		playsound(src, 'sound/machines/clockcult/integration_cog_install.ogg', 30, TRUE)
	return ITEM_INTERACT_SUCCESS

/// Whether a tool counts as electrical contact: a live stun baton or a lit energy blade.
/proc/artifact_tool_is_energetic(obj/item/tool)
	if(istype(tool, /obj/item/melee/baton/security))
		var/obj/item/melee/baton/security/baton = tool
		return baton.active
	if(istype(tool, /obj/item/melee/energy))
		return HAS_TRAIT(tool, TRAIT_TRANSFORM_ACTIVE)
	return FALSE

// ===== Processing =====

/obj/machinery/artifact/process(seconds_per_tick)
	for(var/datum/artifact_effect/effect as anything in effects())
		effect.recharge(seconds_per_tick)
	if(refresh_suppression())
		return
	check_level_triggers()
	for(var/datum/artifact_effect/effect as anything in effects())
		effect.tick(seconds_per_tick)

/// Off a turf, or inside a trader outpost, it does nothing at all.
/obj/machinery/artifact/proc/is_suppressed()
	return !isturf(loc) || is_trader_outpost_protected(src)

/// Re-reads suppression; puts everything to sleep when it starts. Returns TRUE while suppressed.
/obj/machinery/artifact/proc/refresh_suppression()
	var/now_suppressed = is_suppressed()
	if(now_suppressed == suppressed)
		return suppressed
	suppressed = now_suppressed
	if(suppressed)
		// A crate lid or an outpost's dampers: it goes still without a show.
		for(var/datum/artifact_effect/effect as anything in effects())
			effect.deactivate(quiet = !isturf(loc))
	update_activity_visuals()
	return suppressed

/**
 * Air and proximity triggers. Reads the tile's air without materializing it: a planet turf
 * still on its shared mix stays on it.
 */
/obj/machinery/artifact/proc/check_level_triggers()
	var/wanted = NONE
	for(var/datum/artifact_effect/effect as anything in effects())
		if(effect.trigger & ARTIFACT_TRIGGERS_LEVEL)
			wanted |= effect.trigger
	if(!wanted)
		return
	var/met = NONE
	if(wanted & ARTIFACT_TRIGGERS_AIR)
		var/turf/here = get_turf(src)
		var/datum/gas_mixture/air = here?.return_air_readonly()
		if(air)
			if(air.temperature > ARTIFACT_HEAT_AIR_KELVIN)
				met |= ARTIFACT_TRIGGER_HEAT
			if(air.temperature < ARTIFACT_COLD_AIR_KELVIN)
				met |= ARTIFACT_TRIGGER_COLD
			var/list/gases = air.gases
			if(gases[/datum/gas/plasma]?[MOLES] >= ARTIFACT_GAS_TRIGGER_MOLES)
				met |= ARTIFACT_TRIGGER_PLASMA
			if(gases[/datum/gas/carbon_dioxide]?[MOLES] >= ARTIFACT_GAS_TRIGGER_MOLES)
				met |= ARTIFACT_TRIGGER_CO2
	if(wanted & ARTIFACT_TRIGGER_PROXIMITY)
		for(var/mob/living/nearby in view(ARTIFACT_PROXIMITY_RANGE, src))
			if(nearby.stat != DEAD)
				met |= ARTIFACT_TRIGGER_PROXIMITY
				break
	if(!met)
		return
	for(var/datum/artifact_effect/effect as anything in effects())
		if(effect.trigger & met)
			effect.wake(ARTIFACT_LEVEL_LINGER)

// ===== Destruction =====

/obj/machinery/artifact/atom_destruction(damage_flag)
	var/mob/culprit = last_disturbed_by?.resolve()
	visible_message(
		span_danger("[src] cracks apart with a sound like a bell breaking!"),
		blind_message = span_hear("You hear something ring and shatter."),
	)
	playsound(src, 'sound/effects/glass/glassbr3.ogg', 70, TRUE)
	if(!suppressed)
		log_game("Artifact [serial] ([main_effect?.log_name]) was smashed at [AREACOORD(src)][culprit ? " after [key_name(culprit)] disturbed it" : ""].")
		for(var/datum/artifact_effect/effect as anything in effects())
			effect.do_effect_destroy()
	return ..()
