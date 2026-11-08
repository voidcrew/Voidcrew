/**
 * # Scan pad
 *
 * Machine art: NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/icons/machinery.dmi,
 * by way of TauCetiClassic, CC BY-SA 3.0. The unpowered, open and glow states in icons/study.dmi
 * were edited from it for Voidcrew. The code is new.
 *
 * A floor plate under a low arch of sensor rods. A large find stands under the arch for the
 * analyser beside it to read (and for the harvester to drain). The pad only knows what stands on
 * it: the moment a find arrives or leaves it tells whatever is listening, so a reading can never
 * outlive its subject (COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED, defined in analyser.dm, which compiles
 * first). Whichever machine holds the find's lock drives the beam with set_beam().
 */

/obj/machinery/artifact_scanpad
	name = "scan pad"
	desc = "A floor plate under a low arch of sensor rods. The rods are tipped with violet glass."
	icon = 'voidcrew/modules/xenoarch/icons/study.dmi'
	icon_state = "scanpad"
	base_icon_state = "scanpad"
	// The arch draws over whatever stands under it; the plate is an overlay beneath.
	layer = ABOVE_MOB_LAYER
	density = FALSE
	anchored = TRUE
	circuit = /obj/item/circuitboard/machine/artifact_scanpad
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.5
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	/// The scanning beam is sweeping
	var/beam_on = FALSE
	/// Hum while the beam sweeps
	var/datum/looping_sound/artifact_scanpad/scan_hum

/obj/machinery/artifact_scanpad/Initialize(mapload)
	. = ..()
	var/static/list/loc_connections = list(
		COMSIG_ATOM_ENTERED = PROC_REF(on_entered),
		// A find made right on the pad (an admin, a test) never "enters" it.
		COMSIG_ATOM_AFTER_SUCCESSFUL_INITIALIZED_ON = PROC_REF(on_entered),
		COMSIG_ATOM_EXITED = PROC_REF(on_exited),
	)
	AddElement(/datum/element/connect_loc, loc_connections)
	scan_hum = new(src)
	update_appearance()

/obj/machinery/artifact_scanpad/post_machine_initialize()
	. = ..()
	// An analyser built before its pad finds it now.
	for(var/obj/machinery/artifact_analyser/analyser in orange(1, src))
		analyser.find_pad()

/obj/machinery/artifact_scanpad/Destroy()
	beam_on = FALSE
	QDEL_NULL(scan_hum)
	return ..()

/// The large find standing on the pad, if any.
/obj/machinery/artifact_scanpad/proc/get_specimen()
	if(!isturf(loc))
		return null
	for(var/obj/machinery/artifact/find in loc)
		if(!QDELETED(find))
			return find
	return null

/// Ready to read a find: powered, bolted down and closed up.
/obj/machinery/artifact_scanpad/proc/can_scan()
	return is_operational && anchored && !panel_open

/obj/machinery/artifact_scanpad/proc/on_entered(datum/source, atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	SIGNAL_HANDLER
	if(istype(arrived, /obj/machinery/artifact))
		SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)

/obj/machinery/artifact_scanpad/proc/on_exited(datum/source, atom/movable/gone, direction)
	SIGNAL_HANDLER
	if(istype(gone, /obj/machinery/artifact))
		SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)

/obj/machinery/artifact_scanpad/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	// connect_loc follows us, but whoever was reading the old tile has to start over.
	SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)

/// Starts or stops the sweeping beam.
/obj/machinery/artifact_scanpad/proc/set_beam(on)
	if(on == beam_on || QDELETED(src))
		return
	beam_on = on
	if(beam_on)
		update_use_power(ACTIVE_POWER_USE)
		playsound(src, 'sound/machines/destructive_scanner/TubeUp.ogg', 40, TRUE)
		scan_hum?.start()
		set_light(2, 0.8, "#a34de0")
	else
		update_use_power(IDLE_POWER_USE)
		scan_hum?.stop()
		set_light(0)
	update_appearance()

/obj/machinery/artifact_scanpad/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational)
		set_beam(FALSE)
	update_appearance()
	SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)

/obj/machinery/artifact_scanpad/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else if(!is_operational)
		icon_state = "[base_icon_state]_off"
	else
		icon_state = base_icon_state
	return ..()

/obj/machinery/artifact_scanpad/update_overlays()
	. = ..()
	// The plate sits below anything standing on it.
	. += mutable_appearance(icon, "[base_icon_state]_bottom", LOW_OBJ_LAYER)
	if(panel_open || !is_operational)
		return
	. += emissive_appearance(icon, "[base_icon_state]_lights", src, alpha = 200)
	if(beam_on)
		. += mutable_appearance(icon, "[base_icon_state]_beam")
		. += emissive_appearance(icon, "[base_icon_state]_beam", src)

/obj/machinery/artifact_scanpad/screwdriver_act(mob/living/user, obj/item/tool)
	if(beam_on)
		balloon_alert(user, "it's scanning!")
		return ITEM_INTERACT_BLOCKING
	if(!default_deconstruction_screwdriver(user, "[base_icon_state]_open", base_icon_state, tool))
		return NONE
	update_appearance()
	SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact_scanpad/crowbar_act(mob/living/user, obj/item/tool)
	if(default_deconstruction_crowbar(tool))
		return ITEM_INTERACT_SUCCESS
	return NONE

/obj/machinery/artifact_scanpad/wrench_act(mob/living/user, obj/item/tool)
	if(beam_on)
		balloon_alert(user, "it's scanning!")
		return ITEM_INTERACT_BLOCKING
	if(default_unfasten_wrench(user, tool) == SUCCESSFUL_UNFASTEN)
		SEND_SIGNAL(src, COMSIG_XENOARCH_PAD_SPECIMEN_CHANGED)
	return ITEM_INTERACT_SUCCESS

/obj/machinery/artifact_scanpad/examine(mob/user)
	. = ..()
	var/obj/machinery/artifact/find = get_specimen()
	if(find)
		. += "[find] stands under the arch."
	if(beam_on)
		. += span_notice("A violet line sweeps slowly up and down under the arch.")

/// The arch's hum while it sweeps.
/datum/looping_sound/artifact_scanpad
	mid_sounds = list(
		'sound/machines/tcomms/tcomms_mid1.ogg' = 1,
		'sound/machines/tcomms/tcomms_mid3.ogg' = 1,
		'sound/machines/tcomms/tcomms_mid5.ogg' = 1,
	)
	mid_length = 1.8 SECONDS
	volume = 20
	extra_range = -6
	falloff_distance = 2
	falloff_exponent = 5
	ignore_walls = FALSE

/obj/item/circuitboard/machine/artifact_scanpad
	name = "Scan Pad"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/artifact_scanpad
	req_components = list(
		/datum/stock_part/scanning_module = 2,
		/datum/stock_part/micro_laser = 1,
		/obj/item/stack/cable_coil = 2,
	)
