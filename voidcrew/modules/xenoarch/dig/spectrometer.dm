/**
 * # Radiocarbon spectrometer
 *
 * A bench machine aboard ship. Feed it a core sampler holding a boulder's core and it dates the
 * rock, notes what is mixed into it, and names the stabilising field its matrix holds under, on a
 * printed report. Then it hands the sampler back empty.
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarchartifacts/machines/
 * geosample_analyzer.dm, reworked: a timer instead of sleep(), the sampler comes back instead of
 * being kept (or destroyed on a power cut), and the report reads like lab paperwork.
 * Sprites: Nova machinery.dmi spectrometer states, with a drawn open panel.
 */
/obj/item/circuitboard/machine/xenoarch_spectrometer
	name = "Radiocarbon Spectrometer"
	greyscale_colors = CIRCUIT_COLOR_SCIENCE
	build_path = /obj/machinery/xenoarch_spectrometer
	req_components = list(
		/datum/stock_part/scanning_module = 2,
		/obj/item/stack/sheet/glass = 1,
	)

/obj/machinery/xenoarch_spectrometer
	name = "radiocarbon spectrometer"
	desc = "A bench spectrometer for rock cores. It dates the rock and reads the field its matrix will hold under."
	icon = 'voidcrew/modules/xenoarch/icons/dig_machines.dmi'
	icon_state = "spectrometer"
	base_icon_state = "spectrometer"
	density = TRUE
	circuit = /obj/item/circuitboard/machine/xenoarch_spectrometer
	use_power = IDLE_POWER_USE
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION
	active_power_usage = BASE_MACHINE_ACTIVE_CONSUMPTION
	/// The sampler being read
	var/obj/item/excavation/core_sampler/sampler
	/// The reading in progress
	var/scan_timer
	/// How long a reading takes; better scanning modules shorten it
	var/scan_time = 10 SECONDS

/obj/machinery/xenoarch_spectrometer/Destroy()
	if(scan_timer)
		deltimer(scan_timer)
		scan_timer = null
	if(sampler)
		sampler.forceMove(drop_location())
		sampler = null
	return ..()

/obj/machinery/xenoarch_spectrometer/RefreshParts()
	. = ..()
	var/rating = max(total_part_rating(/datum/stock_part/scanning_module), 2)
	// Two tier-1 modules read in 10 s; each tier past that takes off a second, down to 4 s.
	scan_time = max(4 SECONDS, (12 - rating) SECONDS)

/obj/machinery/xenoarch_spectrometer/update_icon_state()
	if(panel_open)
		icon_state = "[base_icon_state]_open"
	else if(scan_timer)
		icon_state = "[base_icon_state]_processing"
	else
		icon_state = base_icon_state
	return ..()

/obj/machinery/xenoarch_spectrometer/examine(mob/user)
	. = ..()
	if(scan_timer)
		. += "It is reading a core."

/obj/machinery/xenoarch_spectrometer/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!istype(tool, /obj/item/excavation/core_sampler))
		return NONE
	var/obj/item/excavation/core_sampler/new_sampler = tool
	if(panel_open)
		balloon_alert(user, "close the panel")
		return ITEM_INTERACT_BLOCKING
	if(!is_operational)
		balloon_alert(user, "no power")
		return ITEM_INTERACT_BLOCKING
	if(sampler)
		balloon_alert(user, "already reading")
		return ITEM_INTERACT_BLOCKING
	if(!new_sampler.sample_serial)
		balloon_alert(user, "sampler is empty")
		return ITEM_INTERACT_BLOCKING
	if(!user.transferItemToLoc(new_sampler, src))
		return ITEM_INTERACT_BLOCKING
	sampler = new_sampler
	user.visible_message(
		span_notice("[user] slots [new_sampler] into [src]."),
		span_notice("You slot [new_sampler] into [src]."),
	)
	begin_reading()
	return ITEM_INTERACT_SUCCESS

/obj/machinery/xenoarch_spectrometer/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(. || !sampler)
		return
	// Pulls the sampler out, abandoning a reading.
	stop_reading()
	eject_sampler(user)
	return TRUE

/obj/machinery/xenoarch_spectrometer/proc/begin_reading()
	update_use_power(ACTIVE_POWER_USE)
	playsound(src, 'sound/effects/industrial_scan/industrial_scan3.ogg', 40, TRUE)
	scan_timer = addtimer(CALLBACK(src, PROC_REF(finish_reading)), scan_time, TIMER_STOPPABLE | TIMER_DELETE_ME)
	update_appearance()

/obj/machinery/xenoarch_spectrometer/proc/stop_reading()
	if(scan_timer)
		deltimer(scan_timer)
		scan_timer = null
	update_use_power(IDLE_POWER_USE)
	update_appearance()

/obj/machinery/xenoarch_spectrometer/proc/finish_reading()
	scan_timer = null
	update_use_power(IDLE_POWER_USE)
	if(QDELETED(src) || !sampler)
		update_appearance()
		return
	if(!is_operational)
		visible_message(span_warning("[src] whines down and pushes the sampler back out."))
		eject_sampler()
		update_appearance()
		return
	print_report(sampler)
	sampler.clear_core()
	eject_sampler()
	update_appearance()

/// Power lost mid-reading: the sampler comes back with its core still in it.
/obj/machinery/xenoarch_spectrometer/on_set_is_operational(old_value)
	. = ..()
	if(!is_operational && scan_timer)
		stop_reading()
		visible_message(span_warning("[src] whines down and pushes the sampler back out."))
		eject_sampler()

/obj/machinery/xenoarch_spectrometer/proc/eject_sampler(mob/living/user)
	if(!sampler)
		return
	var/obj/item/excavation/core_sampler/out = sampler
	sampler = null
	out.forceMove(drop_location())
	if(user)
		user.put_in_hands(out)

/obj/machinery/xenoarch_spectrometer/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == sampler)
		sampler = null
		stop_reading()

/// Prints the lab report for the core in `core_sampler`.
/obj/machinery/xenoarch_spectrometer/proc/print_report(obj/item/excavation/core_sampler/core_sampler)
	var/obj/item/paper/report = new(drop_location())
	report.name = "spectrometer report ([core_sampler.sample_serial])"
	report.add_raw_text(xenoarch_spectrometer_text(core_sampler.sample_serial, core_sampler.sample_age, core_sampler.sample_field, core_sampler.sample_site_kind))
	var/datum/asset/spritesheet_batched/sheet = get_asset_datum(/datum/asset/spritesheet/simple/paper)
	report.add_stamp(sheet.icon_class_name("stamp-ok"), rand(180, 260), rand(330, 380), rand(-15, 15), "stamp-ok")
	report.update_appearance()
	playsound(src, 'sound/machines/printer.ogg', 40, FALSE)
	visible_message(span_notice("[src] chatters and feeds out a report."))
	return report

/// What a site's rock is mixed with, as the spectrometer reads it.
GLOBAL_LIST_INIT(xenoarch_core_inclusions, list(
	XENOARCH_SITE_GARDEN = "carbonised plant matter, pollen",
	XENOARCH_SITE_ANIMAL = "mineralised bone, collagen traces",
	XENOARCH_SITE_HOUSE = "fired clay, hearth ash",
	XENOARCH_SITE_TECHNICAL = "corroded alloy, trace rare earths",
	XENOARCH_SITE_TEMPLE = "pigment, worked stone dust",
	XENOARCH_SITE_WAR = "slag, spent propellant residue",
))

/// The report text: lab paperwork, nothing about how to use it.
/proc/xenoarch_spectrometer_text(serial, age, field, site_kind)
	var/age_text
	if(age >= 1000000000)
		age_text = "[round(age / 1000000000, 0.1)] billion years"
	else if(age >= 1000000)
		age_text = "[round(age / 1000000)] million years"
	else
		age_text = "[round(age / 1000)] thousand years"
	var/inclusions = GLOB.xenoarch_core_inclusions[site_kind] || "none of note"
	. = "<center><b>RADIOCARBON SPECTROMETRY</b><br>Core sample <b>[serial]</b></center><hr>"
	. += "<b>Matrix age:</b> about [age_text]<br>"
	. += "<b>Inclusions:</b> [inclusions]<br>"
	. += "<b>Exotic signature:</b> present, unresolved<br>"
	. += "<b>Matrix holds under:</b> [field]<br>"
	. += "<hr><i>Bench copy. File with the find.</i>"
