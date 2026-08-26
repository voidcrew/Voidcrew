/**
 * # Transporter pad
 *
 * The working half of the transporter. Everything standing on it goes down; everything
 * being pulled up arrives on it. The console aims it, but the pad decides whether a
 * beam is possible, how long it takes, and what condition the passengers arrive in.
 *
 * A beam takes several seconds and only moves what is still standing in it when the
 * cycle ends, so both ends of a transport are a window where things can go wrong.
 */
/obj/machinery/transporter_pad
	name = "transporter pad"
	desc = "A bluespace pattern platform. It takes whatever is standing on it apart, throws the pattern at a planet, and puts it back together on the other end. The plating is warm."
	icon = 'voidcrew/modules/transporter/icons/transporter.dmi'
	icon_state = "transporter_pad"
	base_icon_state = "transporter_pad"
	density = FALSE
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 2
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION * 15
	circuit = /obj/item/circuitboard/machine/transporter_pad
	obj_flags = CAN_BE_HIT | UNIQUE_RENAME

	/// The console driving this pad.
	var/obj/machinery/computer/transporter/linked_console
	/// Transponders keyed to this pad, so the console can find their carriers.
	var/list/obj/item/transporter_transponder/paired_transponders = list()

	/// Length of one beam cycle. Servos.
	var/beam_time = TRANSPORTER_BASE_BEAM_TIME
	/// Recharge between cycles, before the biofilter node's discount. Capacitors.
	var/transport_cooldown = TRANSPORTER_BASE_COOLDOWN
	/// How many atoms one cycle can carry. Scanning modules.
	var/pattern_buffer = TRANSPORTER_BASE_BUFFER
	/// How badly the pattern degrades in transit, 0 to 3. Matter bins.
	var/biofilter_gap = 3
	/// Divides power draw. Capacitors.
	var/power_efficiency = 1

	/// TRUE while a cycle is running.
	var/transporting = FALSE
	/// The in-flight cycle's manifest, kept so a pad that dies mid-beam can still
	/// strip the effects off everyone it was holding. Without this the finish timer
	/// never fires and they stay masked and half-transparent for good.
	var/list/active_manifest

	COOLDOWN_DECLARE(transport_recharge)

/obj/machinery/transporter_pad/Initialize(mapload)
	. = ..()
	register_context()

/obj/machinery/transporter_pad/Destroy()
	release_manifest()
	if(linked_console?.linked_pad == src)
		linked_console.linked_pad = null
	linked_console = null
	for(var/obj/item/transporter_transponder/transponder as anything in paired_transponders)
		transponder.paired_pad = null
	paired_transponders.Cut()
	return ..()

/obj/machinery/transporter_pad/RefreshParts()
	. = ..()
	var/capacitor_tier = 0
	for(var/datum/stock_part/capacitor/capacitor in component_parts)
		capacitor_tier += capacitor.tier
	var/servo_tier = 0
	for(var/datum/stock_part/servo/servo in component_parts)
		servo_tier += servo.tier
	var/scanner_tier = 0
	for(var/datum/stock_part/scanning_module/scanner in component_parts)
		scanner_tier += scanner.tier
	var/bin_tier = 0
	for(var/datum/stock_part/matter_bin/bin in component_parts)
		bin_tier += bin.tier

	// Two capacitors and two servos, so those tiers run 2 to 8. One scanner and one
	// bin, so those run 1 to 4.
	power_efficiency = max(capacitor_tier, 1)
	transport_cooldown = max(TRANSPORTER_BASE_COOLDOWN - ((capacitor_tier - 2) * (10 SECONDS)), TRANSPORTER_MIN_COOLDOWN)
	beam_time = max(TRANSPORTER_BASE_BEAM_TIME - ((servo_tier - 2) * (1 SECONDS)), TRANSPORTER_MIN_BEAM_TIME)
	pattern_buffer = TRANSPORTER_BASE_BUFFER + max(scanner_tier - 1, 0)
	biofilter_gap = max(4 - bin_tier, 0)

/// The recharge this pad actually uses, once the console's research is accounted for.
/obj/machinery/transporter_pad/proc/get_cooldown()
	if(has_biofilter())
		return max(transport_cooldown - (20 SECONDS), TRANSPORTER_MIN_COOLDOWN)
	return transport_cooldown

/// TRUE when the linked console has researched the biofilter matrix.
/obj/machinery/transporter_pad/proc/has_biofilter()
	return linked_console?.has_research(TECHWEB_NODE_TRANSPORTER_BIOFILTER)

/obj/machinery/transporter_pad/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else if(!is_operational)
		icon_state = "[base_icon_state]_off"
	else if(transporting)
		icon_state = "[base_icon_state]_active"
	else
		icon_state = base_icon_state
	return ..()

/obj/machinery/transporter_pad/on_set_is_operational(old_value)
	. = ..()
	update_appearance(UPDATE_ICON_STATE)

/obj/machinery/transporter_pad/add_context(atom/source, list/context, obj/item/held_item, mob/user)
	. = ..()
	if(isnull(held_item))
		return
	if(istype(held_item, /obj/item/transporter_transponder))
		context[SCREENTIP_CONTEXT_LMB] = "Pair transponder"
		return CONTEXTUAL_SCREENTIP_SET
	if(held_item.tool_behaviour == TOOL_MULTITOOL)
		context[SCREENTIP_CONTEXT_LMB] = "Save to buffer"
		return CONTEXTUAL_SCREENTIP_SET

/obj/machinery/transporter_pad/examine(mob/user)
	. = ..()
	. += span_notice("It is [linked_console ? "slaved to a control console" : "waiting for a control console"].")
	. += span_notice("Pattern buffer holds <b>[pattern_buffer]</b> object[pattern_buffer == 1 ? "" : "s"] per cycle, and anything alive inside a container takes a slot of its own. A cycle runs <b>[DisplayTimeText(beam_time)]</b>, then recharges for <b>[DisplayTimeText(get_cooldown())]</b>.")
	if(biofilter_gap && !has_biofilter())
		. += span_warning("The biofilter is undersized for the buffer. Anything living that rides this pad is going to feel it.")
	if(!COOLDOWN_FINISHED(src, transport_recharge))
		. += span_warning("Recharging. [DisplayTimeText(COOLDOWN_TIMELEFT(src, transport_recharge))] remaining.")
	if(!panel_open)
		. += span_notice("The maintenance panel is <i>screwed</i> shut.")

/obj/machinery/transporter_pad/emag_act(mob/user, obj/item/card/emag/emag_card)
	if(obj_flags & EMAGGED)
		balloon_alert(user, "already tampered with")
		return FALSE
	obj_flags |= EMAGGED
	// Deliberately quiet. The whole point of sabotaging a pad is that the next person
	// to step on it doesn't know, so there's no visible message and no icon change.
	balloon_alert(user, "safety interlocks cut")
	playsound(src, 'sound/machines/terminal/terminal_alert.ogg', 25, TRUE)
	log_game("[key_name(user)] emagged [src] at [loc_name(src)].")
	return TRUE

/obj/machinery/transporter_pad/multitool_act(mob/living/user, obj/item/multitool/multi_tool)
	multi_tool.set_buffer(src)
	balloon_alert(user, "saved to buffer")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/transporter_pad/attackby(obj/item/weapon, mob/user, list/modifiers, list/attack_modifiers)
	if(istype(weapon, /obj/item/transporter_transponder))
		var/obj/item/transporter_transponder/transponder = weapon
		transponder.pair_to_pad(src, user)
		return TRUE

	if(default_deconstruction_screwdriver(user, weapon))
		update_appearance(UPDATE_ICON_STATE)
		return TRUE

	if(default_deconstruction_crowbar(user, weapon))
		return TRUE

	return ..()

/**
 * Strips the beam effects off everything in the in-flight manifest and forgets it.
 * Safe to call with no cycle running.
 */
/obj/machinery/transporter_pad/proc/release_manifest()
	if(!active_manifest)
		return
	for(var/atom/movable/thing as anything in active_manifest)
		var/list/record = active_manifest[thing]
		qdel(record[3])
		transporter_restore(thing, record[2])
	active_manifest = null

/**
 * Why this pad can't run a cycle right now, as a short string, or null if it can.
 */
/obj/machinery/transporter_pad/proc/blocking_reason()
	if(!is_operational)
		return "pad has no power"
	if(transporting)
		return "pad is mid-cycle"
	if(!COOLDOWN_FINISHED(src, transport_recharge))
		return "pad is recharging"
	return null

/**
 * Everyone riding inside the given atom. A crate is one object to a pattern buffer, but
 * the people in it are still people: they take up buffer space and they come out the
 * far end in whatever condition the pad leaves its passengers.
 *
 * Only containers are walked. A mob's own contents are its organs and its gear, and
 * riding in a closet is the loophole this closes.
 */
/obj/machinery/transporter_pad/proc/get_contained_passengers(atom/movable/thing)
	if(QDELETED(thing) || isliving(thing) || !length(thing.contents))
		return list()
	return thing.get_all_contents_type(/mob/living)

/**
 * Everything on the given turf that a pattern buffer can hold, living things first so
 * a pile of crates can't crowd a person out of a small buffer.
 *
 * Must stay free of side effects - the console calls this every UI tick to show the
 * operator what is standing on the pad.
 */
/obj/machinery/transporter_pad/proc/gather_payload(turf/source)
	var/list/payload = list()
	if(!source)
		return payload

	var/list/candidates = list()
	for(var/mob/living/subject in source)
		candidates += subject
	for(var/obj/thing in source)
		candidates += thing

	var/slots_used = 0
	for(var/atom/movable/thing as anything in candidates)
		if(QDELETED(thing) || thing == src)
			continue
		if(thing.anchored || thing.invisibility == INVISIBILITY_ABSTRACT)
			continue
		if(istype(thing, /obj/effect))
			continue
		if(GLOB.transporter_mass_blacklist[thing.type])
			continue
		if(isliving(thing))
			var/mob/living/subject = thing
			// Someone strapped to a bolted chair isn't going anywhere.
			if(subject.buckled?.anchored)
				continue
		// A container costs a slot for itself and one for everybody inside it, so a
		// locker full of people can't ride a two-slot buffer as a single object. One
		// that won't fit is skipped rather than ending the sweep, so whatever else is
		// on the pad can still use the slots that are left.
		var/cost = 1 + length(get_contained_passengers(thing))
		if(slots_used + cost > pattern_buffer)
			continue
		payload += thing
		slots_used += cost
		if(slots_used >= pattern_buffer)
			break

	return payload

/**
 * Starts a beam cycle between two turfs. Direction doesn't matter to the pad - beaming
 * down means source is the pad's own turf, beaming up means destination is.
 *
 * Returns TRUE if a cycle started.
 */
/obj/machinery/transporter_pad/proc/begin_transport(turf/source, turf/destination, mob/user)
	if(!source || !destination || blocking_reason())
		return FALSE

	var/list/payload = gather_payload(source)
	if(!length(payload))
		return FALSE

	transporting = TRUE
	update_appearance(UPDATE_ICON_STATE)
	use_energy(active_power_usage / power_efficiency)

	playsound(src, 'sound/machines/terminal/terminal_prompt_confirm.ogg', 40, TRUE)
	// The shimmering dissolve/appear pair, not the wizard thunder - both ends get
	// the dissolve as the columns come down, so the arrival side hears it coming.
	playsound(source, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
	playsound(destination, 'sound/effects/magic/teleport_diss.ogg', 30, TRUE)
	new /obj/effect/temp_visual/transporter_beam(source, beam_time)
	// The arrival side keeps its column up past the end of the cycle, so whatever
	// comes through materialises inside the light rather than after it's gone.
	new /obj/effect/temp_visual/transporter_beam(destination, beam_time + TRANSPORTER_MATERIALISE_TIME + TRANSPORTER_BEAM_WINDDOWN)

	// Atom to list(turf it must still be on, alpha to restore, its mote emitter).
	var/list/manifest = list()
	for(var/atom/movable/thing as anything in payload)
		var/obj/effect/abstract/particle_holder/motes = new(thing, /particles/transporter_motes, isliving(thing) ? PARTICLE_ATTACH_MOB : NONE)
		manifest[thing] = list(get_turf(thing), transporter_dematerialise(thing, beam_time), motes)
		if(isliving(thing))
			var/mob/living/subject = thing
			// Whatever they're dragging isn't in the buffer and won't come with them.
			subject.stop_pulling()
			to_chat(subject, span_notice("A column of light comes down around you and your edges start to come apart. Stay inside it and it will take you. Step out and it won't."))

	active_manifest = manifest
	log_game("[key_name(user)] started a transporter cycle from [loc_name(source)] to [loc_name(destination)] using [src].")
	addtimer(CALLBACK(src, PROC_REF(finish_transport), manifest, source, destination, user), beam_time)
	return TRUE

/// End of a beam cycle. Moves whatever stayed in the beam, if the pad survived.
/obj/machinery/transporter_pad/proc/finish_transport(list/manifest, turf/source, turf/destination, mob/user)
	transporting = FALSE
	// This proc owns the teardown from here on, so the destruction path must not
	// also try to run it.
	active_manifest = null
	update_appearance(UPDATE_ICON_STATE)

	// A pad that lost power mid-cycle drops the whole pattern. Nobody moves.
	var/dropped_lock = !is_operational || QDELETED(destination)

	var/list/arrived = list()
	for(var/atom/movable/thing as anything in manifest)
		var/list/record = manifest[thing]
		// The outbound motes stop either way - the pattern is no longer being taken
		// apart, whether that's because it left or because it stayed.
		qdel(record[3])
		if(dropped_lock || QDELETED(thing) || get_turf(thing) != record[1])
			// Anything not making the trip goes straight back to how it looked.
			transporter_restore(thing, record[2])
			if(!dropped_lock && !QDELETED(thing) && isliving(thing))
				to_chat(thing, span_warning("The light gutters out around you. You stepped clear of it in time."))
			continue
		arrived += thing

	if(dropped_lock)
		playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
		visible_message(span_warning("[src] loses its pattern lock."))
		return

	COOLDOWN_START(src, transport_recharge, get_cooldown())

	if(!length(arrived))
		playsound(src, 'sound/machines/buzz/buzz-two.ogg', 40, TRUE)
		return

	new /obj/effect/temp_visual/transporter_flash/departure(source)
	new /obj/effect/temp_visual/transporter_flash(destination)
	transporter_sparks(source)
	transporter_sparks(destination)
	playsound(source, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	playsound(destination, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)

	for(var/atom/movable/thing as anything in arrived)
		// Not forced. Encounter areas carry no blanket teleport block any more, so an
		// ordinary teleport reaches a planet surface on its own - which means the
		// engine's own checks can stay switched on as a backstop under the console's.
		// They cover TRAIT_NO_TELEPORT, shielded areas at both ends, and the
		// reservation boundary, and they balloon-alert the passenger on refusal.
		var/list/record = manifest[thing]
		if(!do_teleport(thing, destination, channel = TELEPORT_CHANNEL_QUANTUM, no_effects = TRUE))
			// Refused at the last moment - put it back the way it looked.
			transporter_restore(thing, record[2])
			continue
		// It arrived, so knit it back together at the far end.
		transporter_materialise(thing, record[2])
		// Anyone who rode inside a container went through the same beam and the same
		// buffer as someone standing on the plating, and gets the same treatment.
		var/list/passengers = get_contained_passengers(thing)
		if(isliving(thing))
			passengers += thing
		for(var/mob/living/passenger as anything in passengers)
			if(obj_flags & EMAGGED)
				scramble_pattern(passenger, user)
			else
				apply_transport_trauma(passenger)

/**
 * Residual damage from a buffer the biofilter can't keep up with. A stock pad stings,
 * a fully upgraded one doesn't, and the biofilter node removes it outright.
 */
/obj/machinery/transporter_pad/proc/apply_transport_trauma(mob/living/passenger)
	if(!biofilter_gap || has_biofilter())
		return
	passenger.adjust_fire_loss(biofilter_gap * 4, forced = TRUE)
	to_chat(passenger, span_warning("You come back together a beat behind yourself, and your skin stings where the filter missed."))

/**
 * What an emagged pad does to the people who trust it. The interlocks that check a
 * pattern against the one that went in are gone, so what arrives is close, but wrong.
 */
/obj/machinery/transporter_pad/proc/scramble_pattern(mob/living/victim, mob/saboteur)
	victim.log_message("was rematerialised by a sabotaged transporter pad ([src]).", LOG_ATTACK)
	victim.investigate_log("was rematerialised by a sabotaged transporter pad at [loc_name(src)].", INVESTIGATE_DEATHS)
	playsound(victim, 'sound/effects/magic/disintegrate.ogg', 60, TRUE)
	transporter_sparks(victim)

	if(prob(25))
		victim.visible_message(
			span_boldwarning("[victim] arrives as a spray of wet static and doesn't finish."),
			span_userdanger("You don't finish arriving."),
		)
		victim.gib()
		return

	victim.visible_message(
		span_boldwarning("[victim] rematerialises wrong, and keeps rematerialising."),
		span_userdanger("Something takes you apart and puts you back together in the wrong order. It does not stop when you are whole."),
	)
	victim.adjust_fire_loss(85, forced = TRUE)
	victim.adjust_tox_loss(60, forced = TRUE)
	victim.adjust_organ_loss(ORGAN_SLOT_BRAIN, 60)

/**
 * Circuit board. Bluespace crystals are the expensive half - a pad can't be improvised
 * out of the parts a ship already has lying around.
 */
/obj/item/circuitboard/machine/transporter_pad
	name = "Transporter Pad"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/transporter_pad
	// Mirrors /datum/design/board/transporter_pad; see the console board for the convention.
	custom_materials = list(
		/datum/material/glass = SHEET_MATERIAL_AMOUNT,
		/datum/material/gold = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/diamond = HALF_SHEET_MATERIAL_AMOUNT,
		/datum/material/bluespace = SHEET_MATERIAL_AMOUNT * 2,
	)
	req_components = list(
		/obj/item/stack/ore/bluespace_crystal = 6,
		/datum/stock_part/capacitor = 2,
		/datum/stock_part/servo = 2,
		/datum/stock_part/scanning_module = 1,
		/datum/stock_part/matter_bin = 1,
		/obj/item/stack/cable_coil = 10,
	)
	def_components = list(/obj/item/stack/ore/bluespace_crystal = /obj/item/stack/ore/bluespace_crystal/artificial)
