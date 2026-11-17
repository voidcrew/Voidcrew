/**
 * # Exotic particle harvester
 *
 * Draws one awake effect off an alien artifact standing next to it and packs it into an exotic
 * battery, which a utilizer can then run. Each artifact gives ARTIFACT_MAX_HARVESTS harvests in
 * all, and every harvest taken lowers its sale price (core pricing reads harvests_taken()).
 *
 * Rewritten from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/machines/artifact_harvester.dm,
 * with its HTML window replaced by tgui (ArtifactHarvester.tsx). Voidcrew changes:
 * - A harvest is spent the moment the first charge reaches the battery, so stopping early or
 *   losing power partway never refunds it, and a draw that never started costs nothing.
 *   Nova copied the effect for free, forever.
 * - The find's lock (try_lock()/release_lock()) is held for the whole draw and released on
 *   finish, on halt and in Destroy(). Nova anchored the find and never let go of it on halt.
 * - It reads any find on the eight tiles around it, so it works beside a scan pad or without one.
 * - Effects marked unharvestable won't come off; two effects awake at once can't be separated.
 * - A battery can be topped up only from the effect it already holds; an empty one takes anything.
 * - While it draws, a stream of motes in the energy's colour runs from the find to the dome, the
 *   find throbs and crackles with its own sound, and the console hums.
 *
 * Art: Nova's machinery.dmi harvester states (CC BY-SA 3.0, pixel-checked clean against Goon),
 * a dome mask drawn for Voidcrew, and tg's drain_life beam made greyscale so it can be tinted.
 *
 * Ship saves: the harvester is rebuilt from its board with an empty slot (its battery is an item
 * and clear_stock() deletes it) and no draw in progress, so a save never copies a charge.
 */

/// What the readout says about the find beside it.
#define HARVEST_SOURCE_READY "ready"
#define HARVEST_SOURCE_QUIET "quiet"
#define HARVEST_SOURCE_TANGLED "tangled"
#define HARVEST_SOURCE_UNFIT "unfit"
#define HARVEST_SOURCE_SPENT "spent"
#define HARVEST_SOURCE_BUSY "busy"
#define HARVEST_SOURCE_MISMATCH "mismatch"
#define HARVEST_SOURCE_DRAWING "drawing"

/obj/machinery/artifact_harvester
	name = "exotic particle harvester"
	desc = "A console wired to a collector dome. It pulls the energy off an alien find and packs it into a battery."
	icon = 'voidcrew/modules/xenoarch/icons/use.dmi'
	icon_state = "harvester"
	base_icon_state = "harvester"
	density = TRUE
	anchored = TRUE
	circuit = /obj/item/circuitboard/machine/artifact_harvester
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 2
	processing_flags = START_PROCESSING_MANUALLY
	// Its window opens unpowered too (dark scope, no draw), so a battery is never stuck inside.
	interaction_flags_machine = INTERACT_MACHINE_WIRES_IF_OPEN | INTERACT_MACHINE_ALLOW_SILICON | INTERACT_MACHINE_OPEN_SILICON | INTERACT_MACHINE_OFFLINE
	/// The battery in its slot
	var/obj/item/anomaly_battery/battery
	/// Drawing right now
	var/drawing = FALSE
	/// The find it draws from, while it draws
	var/datum/weakref/source_ref
	/// The effect it draws, while it draws
	var/datum/weakref/drawn_ref
	/// Whoever started the draw, for the harvest record
	var/datum/weakref/operator_ref
	/// This draw has already taken one of the find's harvests
	var/draw_counted = FALSE
	/// Charge per second, from its capacitors
	var/draw_rate = ARTIFACT_HARVEST_DRAW_RATE
	/// The stream of motes between the find and the dome
	var/datum/beam/draw_beam
	/// The hum while it draws
	var/datum/looping_sound/artifact_harvester/soundloop
	/// world.time of the next crackle off the find
	var/next_crackle = 0

/obj/machinery/artifact_harvester/Initialize(mapload)
	. = ..()
	soundloop = new(src)

/obj/machinery/artifact_harvester/Destroy()
	stop_draw()
	QDEL_NULL(soundloop)
	QDEL_NULL(battery)
	return ..()

/obj/machinery/artifact_harvester/RefreshParts()
	. = ..()
	var/capacitor_tier = max(total_part_rating(/datum/stock_part/capacitor) / 2, 1)
	// Tier-1 capacitors fill a battery in 80 seconds, tier-4 in 40.
	draw_rate = ARTIFACT_HARVEST_DRAW_RATE * (1 + (capacitor_tier - 1) / 3)

/obj/machinery/artifact_harvester/examine(mob/user)
	. = ..()
	if(battery)
		. += "An exotic battery is seated under the dome."
	if(drawing)
		. += span_notice("Its dome hums, and a thin stream of light runs into it.")

// ===== Battery slot =====

/obj/machinery/artifact_harvester/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/anomaly_battery))
		return NONE
	if(battery)
		balloon_alert(user, "slot's taken!")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(tool, src))
		return ITEM_INTERACT_BLOCKING
	battery = tool
	user.visible_message(
		span_notice("[user] seats [tool] under the dome of [src]."),
		span_notice("You seat [tool] under the dome of [src]."),
	)
	playsound(src, 'sound/machines/terminal/terminal_insert_disc.ogg', 40, TRUE)
	update_appearance()
	SStgui.update_uis(src)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact_harvester/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone != battery)
		return
	battery = null
	stop_draw()
	if(!QDELETED(src))
		update_appearance()

/// Hands the battery back, or drops it in front of the harvester.
/obj/machinery/artifact_harvester/proc/eject_battery(mob/living/user)
	if(!battery)
		return FALSE
	if(drawing)
		balloon_alert(user, "it's drawing!")
		return FALSE
	var/obj/item/anomaly_battery/ejected = battery
	ejected.forceMove(drop_location())
	if(user && Adjacent(user))
		user.put_in_hands(ejected)
	playsound(src, 'sound/machines/terminal/terminal_eject.ogg', 40, TRUE)
	return TRUE

/// Vents the battery: its charge and the effect it held are gone, and it can take anything again.
/obj/machinery/artifact_harvester/proc/purge_battery(mob/living/user)
	if(!battery || drawing || !battery.held_effect)
		return FALSE
	var/datum/artifact_energy_kind/kind = battery.lit_kind()
	battery.purge()
	if(kind)
		visible_message(span_notice("[src]'s dome flares [anomaly_glow_word(kind.key)] and goes dark with a hiss."))
		flick_dome(kind.color)
	playsound(src, 'sound/machines/steam_hiss.ogg', 40, TRUE)
	update_appearance()
	return TRUE

// ===== Reading the find =====

/// The find it would draw from: an artifact on a tile around it, preferring one that is awake.
/obj/machinery/artifact_harvester/proc/find_source()
	var/obj/machinery/artifact/fallback
	for(var/obj/machinery/artifact/candidate in orange(1, src))
		if(QDELETED(candidate) || !isturf(candidate.loc))
			continue
		if(candidate.is_active())
			return candidate
		fallback ||= candidate
	return fallback

/// Whether a find is still close enough to draw from.
/obj/machinery/artifact_harvester/proc/in_reach(obj/machinery/artifact/source)
	return !QDELETED(source) && isturf(source.loc) && source.z == z && get_dist(src, source) <= 1

/// The one awake effect a draw would take, or null when none or both are awake.
/obj/machinery/artifact_harvester/proc/awake_effect(obj/machinery/artifact/source)
	var/datum/artifact_effect/found
	for(var/datum/artifact_effect/effect as anything in source.effects())
		if(!effect.activated)
			continue
		if(found)
			return null
		found = effect
	return found

/// What the readout says about `source` right now (a HARVEST_SOURCE_* key).
/obj/machinery/artifact_harvester/proc/source_state(obj/machinery/artifact/source)
	if(source.harvests_left <= 0)
		return HARVEST_SOURCE_SPENT
	if(source.is_being_used() && source.locked_by?.resolve() != src)
		return HARVEST_SOURCE_BUSY
	if(source.suppressed)
		return HARVEST_SOURCE_QUIET
	var/awake = 0
	for(var/datum/artifact_effect/effect as anything in source.effects())
		if(effect.activated)
			awake++
	if(awake > 1)
		return HARVEST_SOURCE_TANGLED
	var/datum/artifact_effect/effect = awake_effect(source)
	if(!effect)
		return HARVEST_SOURCE_QUIET
	if(!effect.harvestable)
		return HARVEST_SOURCE_UNFIT
	if(battery && !battery.can_take(effect) && !battery.is_full())
		return HARVEST_SOURCE_MISMATCH
	return HARVEST_SOURCE_READY

// ===== Drawing =====

/// Starts a draw from the find beside it. Returns TRUE if it started.
/obj/machinery/artifact_harvester/proc/start_draw(mob/living/user)
	if(drawing)
		return FALSE
	if(!is_operational)
		return refuse(user, "no power!")
	if(!battery)
		return refuse(user, "no battery!")
	if(battery.is_full())
		return refuse(user, "battery's full!")
	var/obj/machinery/artifact/source = find_source()
	if(!source)
		return refuse(user, "nothing to draw from!")
	if(source_state(source) != HARVEST_SOURCE_READY)
		return refuse(user, "no clean signal!")
	var/datum/artifact_effect/effect = awake_effect(source)
	if(!effect || !source.try_lock(src))
		return refuse(user, "no clean signal!")

	battery.load_from(effect, source.serial)
	drawing = TRUE
	draw_counted = FALSE
	source_ref = WEAKREF(source)
	drawn_ref = WEAKREF(effect)
	operator_ref = user ? WEAKREF(user) : null
	next_crackle = world.time + 3 SECONDS

	var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
	QDEL_NULL(draw_beam)
	// The motes run from the find into the collector dome on the right of the sprite.
	draw_beam = Beam(source, icon_state = "harvest_draw", icon = 'voidcrew/modules/xenoarch/icons/use.dmi', beam_color = kind.color, override_origin_pixel_x = 7, override_origin_pixel_y = 10)
	soundloop.start()
	playsound(src, 'sound/machines/terminal/terminal_prompt_confirm.ogg', 40, TRUE)
	visible_message(span_notice("[src] hums, and a thin stream of [anomaly_glow_word(kind.key)] light reaches out to [source]."))
	update_use_power(ACTIVE_POWER_USE)
	begin_processing()
	update_appearance()
	return TRUE

/// Buzzes and says why it won't start. Always FALSE.
/obj/machinery/artifact_harvester/proc/refuse(mob/living/user, reason)
	playsound(src, 'sound/machines/buzz/buzz-two.ogg', 30, TRUE)
	if(user)
		balloon_alert(user, reason)
	return FALSE

/obj/machinery/artifact_harvester/process(seconds_per_tick)
	if(!drawing)
		return PROCESS_KILL
	var/obj/machinery/artifact/source = source_ref?.resolve()
	var/datum/artifact_effect/effect = drawn_ref?.resolve()
	if(!is_operational)
		stop_draw("[src]'s dome flickers and goes dark.")
		return
	if(!battery || QDELETED(effect) || !in_reach(source) || !source.try_lock(src))
		stop_draw("[src] whines down as the stream of light snaps.")
		return
	var/added = battery.add_charge(draw_rate * seconds_per_tick)
	if(added > 0 && !draw_counted)
		count_harvest(source, effect)
	if(world.time >= next_crackle)
		next_crackle = world.time + rand(5 SECONDS, 8 SECONDS)
		var/datum/artifact_energy_kind/kind = artifact_energy_kind(effect.energy_kind)
		playsound(source, kind.pulse_sound, 25, TRUE)
		source.throb(1.06)
		flick_dome(kind.color)
	if(battery.is_full())
		finish_draw()

/// Takes one of the find's harvests. Runs once per draw, when the first charge arrives.
/obj/machinery/artifact_harvester/proc/count_harvest(obj/machinery/artifact/source, datum/artifact_effect/effect)
	draw_counted = TRUE
	source.harvests_left = max(source.harvests_left - 1, 0)
	var/mob/user = operator_ref?.resolve()
	SEND_SIGNAL(source, COMSIG_ARTIFACT_HARVESTED, effect, user)
	record_metric(
		category = METRIC_RESEARCH,
		event = XENOARCH_METRIC_HARVESTED,
		zone = xenoarch_band_name(source.origin_band),
		subject = "[effect.type]",
		details = list(
			"serial" = source.serial,
			"harvests_taken" = source.harvests_taken(),
			"kind" = effect.energy_kind,
			"release" = effect.release_method,
			"strength" = effect.strength,
		),
		actor = user,
		location = src,
	)
	log_game("[user ? key_name(user) : "Nobody"] drew [effect.log_name] off artifact [source.serial] with [src] at [AREACOORD(src)]; [source.harvests_left] harvests left.")

/obj/machinery/artifact_harvester/proc/finish_draw()
	var/datum/artifact_energy_kind/kind = battery?.held_kind()
	stop_draw()
	playsound(src, 'sound/machines/chime.ogg', 40, FALSE)
	if(kind)
		visible_message(span_notice("[src] chimes, and its dome settles to a steady [anomaly_glow_word(kind.key)] glow."))
	else
		visible_message(span_notice("[src] chimes."))

/**
 * Ends a draw: lets go of the find, cuts the stream and the hum. Safe to call when idle and from
 * Destroy(). `message` is shown to anyone watching.
 */
/obj/machinery/artifact_harvester/proc/stop_draw(message)
	if(!drawing)
		return
	drawing = FALSE
	var/obj/machinery/artifact/source = source_ref?.resolve()
	source?.release_lock(src)
	source_ref = null
	drawn_ref = null
	operator_ref = null
	draw_counted = FALSE
	QDEL_NULL(draw_beam)
	soundloop?.stop()
	end_processing()
	if(QDELETED(src))
		return
	update_use_power(IDLE_POWER_USE)
	update_appearance()
	SStgui.update_uis(src)
	if(message)
		visible_message(span_warning(message))
		playsound(src, 'sound/machines/terminal/terminal_off.ogg', 40, TRUE)

// ===== Looks =====

/obj/machinery/artifact_harvester/update_icon_state()
	if(drawing)
		icon_state = "[base_icon_state]_on"
	else if(battery)
		icon_state = "[base_icon_state]_loaded"
	else
		icon_state = base_icon_state
	return ..()

/obj/machinery/artifact_harvester/update_overlays()
	. = ..()
	if(!battery)
		return
	var/datum/artifact_energy_kind/kind
	var/fraction = battery.charge_fraction()
	if(drawing)
		var/datum/artifact_effect/effect = drawn_ref?.resolve()
		kind = effect ? artifact_energy_kind(effect.energy_kind) : battery.held_kind()
		// The dome is lit the whole draw, even while the battery is still nearly empty.
		fraction = max(fraction, 0.6)
	else
		kind = battery.lit_kind()
	. += anomaly_core_overlays(src, "harvester_dome", kind, fraction)

/// A brief flare of the dome in `color` that fades back to whatever it shows.
/obj/machinery/artifact_harvester/proc/flick_dome(color)
	var/mutable_appearance/flare = mutable_appearance(icon, "harvester_dome")
	flare.color = color
	var/atom/movable/flare_visual = flick_overlay_view(flare, 0.8 SECONDS)
	if(flare_visual)
		animate(flare_visual, alpha = 0, time = 0.8 SECONDS, easing = SINE_EASING | EASE_IN)

// ===== Tools =====

/obj/machinery/artifact_harvester/screwdriver_act(mob/living/user, obj/item/tool)
	if(drawing)
		balloon_alert(user, "it's drawing!")
		return ITEM_INTERACT_BLOCKING
	if(default_deconstruction_screwdriver(user, icon_state, icon_state, tool))
		update_appearance()
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/machinery/artifact_harvester/crowbar_act(mob/living/user, obj/item/tool)
	if(drawing && panel_open)
		balloon_alert(user, "it's drawing!")
		return ITEM_INTERACT_BLOCKING
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS
	return NONE

// ===== Window =====

/obj/machinery/artifact_harvester/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "ArtifactHarvester", name)
		ui.open()

/obj/machinery/artifact_harvester/ui_data(mob/user)
	var/list/data = list()
	data["powered"] = is_operational
	data["drawing"] = drawing
	var/obj/machinery/artifact/source = drawing ? source_ref?.resolve() : find_source()
	if(source)
		var/datum/artifact_effect/effect = drawing ? drawn_ref?.resolve() : awake_effect(source)
		var/datum/artifact_energy_kind/kind = effect ? artifact_energy_kind(effect.energy_kind) : null
		data["source"] = list(
			"serial" = source.serial || "untagged",
			"state" = drawing ? HARVEST_SOURCE_DRAWING : source_state(source),
			"color" = kind?.color,
		)
	else
		data["source"] = null
	if(battery)
		var/datum/artifact_energy_kind/kind = battery.lit_kind()
		data["cell"] = list(
			"fill" = round(battery.charge_fraction(), 0.01),
			"color" = kind?.color,
			"kind" = kind?.report_name,
			"serial" = battery.source_serial,
		)
	else
		data["cell"] = null
	return data

/obj/machinery/artifact_harvester/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return
	var/mob/living/user = ui.user
	switch(action)
		if("draw")
			start_draw(user)
			return TRUE
		if("halt")
			if(drawing)
				stop_draw("[src] whines down.")
			return TRUE
		if("eject")
			eject_battery(user)
			return TRUE
		if("purge")
			purge_battery(user)
			return TRUE

// ===== Board, design and sound =====

/obj/item/circuitboard/machine/artifact_harvester
	name = "Exotic Particle Harvester"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/artifact_harvester
	req_components = list(
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/scanning_module = 1,
		/datum/stock_part/micro_laser = 1,
	)

/datum/design/board/artifact_harvester
	name = "Exotic Particle Harvester Board"
	desc = "The circuit board for an exotic particle harvester."
	id = "xenoarch_harvester"
	build_path = /obj/item/circuitboard/machine/artifact_harvester
	category = list(
		RND_CATEGORY_MACHINE + RND_SUBCATEGORY_MACHINE_RESEARCH
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE

/datum/looping_sound/artifact_harvester
	start_sound = 'sound/machines/gravgen/grav_gen_start.ogg'
	start_length = 1 SECONDS
	mid_sounds = list(
		'sound/machines/gravgen/grav_gen_mid1.ogg' = 12,
		'sound/machines/gravgen/grav_gen_mid2.ogg' = 1,
	)
	mid_length = 1.1 SECONDS
	end_sound = 'sound/machines/gravgen/grav_gen_end.ogg'
	volume = 30
	extra_range = -4
	falloff_distance = 2
	falloff_exponent = 5
	vary = TRUE

#undef HARVEST_SOURCE_READY
#undef HARVEST_SOURCE_QUIET
#undef HARVEST_SOURCE_TANGLED
#undef HARVEST_SOURCE_UNFIT
#undef HARVEST_SOURCE_SPENT
#undef HARVEST_SOURCE_BUSY
#undef HARVEST_SOURCE_MISMATCH
#undef HARVEST_SOURCE_DRAWING
