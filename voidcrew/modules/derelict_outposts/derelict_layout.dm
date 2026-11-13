/**
 * # Derelict outpost: layout and dead power
 *
 * Owner: P2. Every cell drained, the fuel hidden, dark berths and the ambience.
 */

/// Drains every APC, SMES and light emergency cell, empties the generator and hides its fuel
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/drain_derelict_power()
	for(var/area/place as anything in derelict_areas())
		for(var/obj/machinery/light/fixture in place)
			var/obj/item/stock_parts/power_store/cell = fixture.get_cell()
			cell?.use(cell.charge, force = TRUE)
			fixture.update(FALSE)
		for(var/obj/machinery/power/smes/smes in place)
			smes.adjust_charge(-smes.charge)
			smes.update_appearance()
	var/obj/machinery/power/port_gen/pacman/generator = derelict_generator()
	if(generator)
		if(generator.active)
			generator.TogglePower()
		generator.sheets = 0
		generator.sheet_left = 0
		if(generator.anchored)
			generator.set_anchored(FALSE)
	if(outpost_area)
		for(var/turf/tile as anything in outpost_area.get_turfs_by_zlevel(upgrade_level_z()))
			for(var/obj/item/stack/sheet/mineral/plasma/mapped_plasma in tile)
				qdel(mapped_plasma)
	for(var/area/place as anything in derelict_areas())
		for(var/obj/machinery/power/apc/apc in place)
			apc.cell?.use(apc.cell.charge, force = TRUE)
			apc.late_process(1)
	stash_derelict_fuel()

/// Hides the shell's plasma as DERELICT_FUEL_STACKS stacks of DERELICT_FUEL_SHEETS sheets about the habitat
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/stash_derelict_fuel()
	derelict_fuel_spots = list()
	var/z = upgrade_level_z()
	if(!z)
		return
	var/obj/machinery/power/port_gen/pacman/generator = derelict_generator()
	var/list/habitat_tiles = list()
	if(outpost_area)
		for(var/turf/open/floor/tile in outpost_area.get_turfs_by_zlevel(z))
			if(is_derelict_protected_turf(tile))
				continue
			if(generator && get_dist(tile, generator) < DERELICT_FUEL_MIN_DISTANCE)
				continue
			habitat_tiles += tile
	var/list/spots = list()
	if(length(habitat_tiles))
		spots += pick(habitat_tiles)
	if(length(spots) < DERELICT_FUEL_STACKS && length(habitat_tiles))
		var/list/remaining = habitat_tiles - spots
		if(length(remaining))
			spots += pick(remaining)
	var/obj/item/stack/sheet/mineral/plasma/last_stack
	for(var/turf/spot as anything in spots)
		last_stack = new(spot, DERELICT_FUEL_SHEETS)
		derelict_fuel_spots += spot
	if(length(spots) && length(spots) < DERELICT_FUEL_STACKS)
		last_stack.add(DERELICT_FUEL_SHEETS * (DERELICT_FUEL_STACKS - length(spots)))
		log_mapping("DERELICT OUTPOST: '[name]' had only [length(spots)] fuel spot(s) for [DERELICT_FUEL_STACKS] stacks; the rest of the plasma went on the last one")

/// Makes a berth dark (lights off, no floodlight, blank signs, spooky ambience) or lights it again
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/set_berth_dark(datum/outpost_berth/berth, dark)
	if(!berth?.has_ground())
		return
	var/list/areas = list()
	for(var/turf/tile as anything in berth.get_block())
		var/area/voidcrew/outpost_hangar/place = get_area(tile)
		if(!istype(place))
			continue
		areas[place] = TRUE
	for(var/area/voidcrew/outpost_hangar/place as anything in areas)
		place.lightswitch = !dark
		place.set_base_lighting(new_alpha = dark ? 0 : initial(place.base_lighting_alpha))
		place.ambientsounds = dark ? GLOB.ambience_assoc[AMBIENCE_SPOOKY] : GLOB.ambience_assoc[initial(place.ambience_index)]
		place.ambient_buzz = dark ? null : initial(place.ambient_buzz)
		place.update_appearance()
		place.power_change()
	for(var/turf/tile as anything in berth.get_block())
		for(var/obj/machinery/status_display/display in tile)
			if(dark)
				display.current_mode = SD_BLANK
			else
				display.current_mode = SD_MESSAGE
				if(istype(display, /obj/machinery/status_display/outpost_berth))
					display.set_messages("BERTH [berth.berth_number]", berth.ship?.name || "FREIGHT")
				else if(istype(display, /obj/machinery/status_display/outpost_sign))
					var/obj/machinery/status_display/outpost_sign/sign = display
					display.set_messages(sign.top_line, sign.bottom_line)
			display.update_appearance()

/// Lights every berth again
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/relight_berths()
	for(var/datum/outpost_berth/berth as anything in berths)
		if(berth)
			set_berth_dark(berth, FALSE)

/// Spooky ambience and no ship hum in the derelict's areas, or their own sounds back
/obj/structure/overmap/dynamic/player_outpost/derelict/proc/set_derelict_ambience(spooky)
	for(var/area/place as anything in derelict_areas())
		place.ambientsounds = spooky ? GLOB.ambience_assoc[AMBIENCE_SPOOKY] : GLOB.ambience_assoc[initial(place.ambience_index)]
		place.ambient_buzz = spooky ? null : initial(place.ambient_buzz)
