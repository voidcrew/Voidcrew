#define AIRLOCK_FRAME_CLOSED "closed"
#define AIRLOCK_FRAME_CLOSING "closing"
#define AIRLOCK_FRAME_OPEN "open"
#define AIRLOCK_FRAME_OPENING "opening"

/obj/machinery/door/airlock
	doorOpen = 'voidcrew/sound/machines/doors/open.ogg'
	doorClose = 'voidcrew/sound/machines/doors/close.ogg'
	boltUp = 'voidcrew/sound/machines/doors/bolts_up.ogg'
	boltDown = 'voidcrew/sound/machines/doors/bolts_down.ogg'
	var/forcedOpen = 'voidcrew/sound/machines/doors/open_force.ogg' //Come on guys, why aren't all the sound files like this.
	var/forcedClosed = 'voidcrew/sound/machines/doors/close_force.ogg'

	/// For those airlocks you might want to have varying "fillings" for, without having to
	/// have an icon file per door with a different filling.
	var/fill_state_suffix = null
	/// For the airlocks that use a greyscale accent door color, set this color to the accent color you want it to be.
	var/greyscale_accent_color = null
	/// Does this airlock emit a light?
	var/has_environment_lights = TRUE
	/// Is this door external? E.g. does it lead to space? Shuttle docking systems bolt doors with this flag.
	var/external = FALSE

/obj/machinery/door/airlock/external
	external = TRUE

/obj/machinery/door/airlock/shuttle
	external = TRUE

/obj/machinery/door/airlock/power_change()
	..()
	update_icon()

/obj/machinery/door/airlock/update_overlays()
	. = ..()
	if(QDELETED(src))
		return
	if(isnull(overlays_file))
		return
	var/frame_state
	var/light_state = AIRLOCK_LIGHT_POWERON
	if(machine_stat & MAINT) // in the process of being emagged
		frame_state = AIRLOCK_FRAME_CLOSED
	else switch(airlock_state)
		if(AIRLOCK_CLOSED)
			frame_state = AIRLOCK_FRAME_CLOSED
			if(locked)
				light_state = AIRLOCK_LIGHT_BOLTS
			else if(emergency)
				light_state = AIRLOCK_LIGHT_EMERGENCY

		if(AIRLOCK_DENY)
			frame_state = AIRLOCK_FRAME_CLOSED
			light_state = AIRLOCK_LIGHT_DENIED
		if(AIRLOCK_CLOSING)
			frame_state = AIRLOCK_FRAME_CLOSING
			light_state = AIRLOCK_LIGHT_CLOSING
		if(AIRLOCK_OPEN)
			frame_state = AIRLOCK_FRAME_OPEN
			if(locked)
				light_state = AIRLOCK_LIGHT_BOLTS
			else if(emergency)
				light_state = AIRLOCK_LIGHT_EMERGENCY

			light_state += "_open"
		if(AIRLOCK_OPENING)
			frame_state = AIRLOCK_FRAME_OPENING
			light_state = AIRLOCK_LIGHT_OPENING

	. += get_airlock_overlay(frame_state, icon, src, em_block = TRUE)
	if(airlock_material)
		. += get_airlock_overlay("[airlock_material]_[frame_state]", overlays_file, src, em_block = TRUE)
	else
		. += get_airlock_overlay("fill_[frame_state + fill_state_suffix]", icon, src, em_block = TRUE)

	if(hasPower() && has_environment_lights)
		. += get_airlock_overlay("lights_[light_state]", overlays_file, src, em_block = FALSE)
		. += emissive_appearance(overlays_file, "lights_[light_state]", src, alpha = src.alpha)

	if(panel_open)
		. += get_airlock_overlay("panel_[frame_state][security_level ? "_protected" : null]", overlays_file, src, em_block = TRUE)

	if(frame_state == AIRLOCK_FRAME_CLOSED && welded)
		. += get_airlock_overlay("welded", overlays_file, src, em_block = TRUE)

	if(machine_stat & MAINT) // in the process of being emagged
		. += get_airlock_overlay("sparks", overlays_file, src, em_block = FALSE)

	if(hasPower())
		if(frame_state == AIRLOCK_FRAME_CLOSED)
			if(atom_integrity < integrity_failure * max_integrity)
				. += get_airlock_overlay("sparks_broken", overlays_file, src, em_block = FALSE)
			else if(atom_integrity < (0.75 * max_integrity))
				. += get_airlock_overlay("sparks_damaged", overlays_file, src, em_block = FALSE)
		else if(frame_state == AIRLOCK_FRAME_OPEN)
			if(atom_integrity < (0.75 * max_integrity))
				. += get_airlock_overlay("sparks_open", overlays_file, src, em_block = FALSE)

	if(note)
		. += get_airlock_overlay(get_note_state(frame_state), note_overlay_file, src, em_block = TRUE)

	if(frame_state == AIRLOCK_FRAME_CLOSED && seal)
		. += get_airlock_overlay("sealed", overlays_file, src, em_block = TRUE)

	if(hasPower() && unres_sides)
		for(var/heading in list(NORTH,SOUTH,EAST,WEST))
			if(!(unres_sides & heading))
				continue
			var/mutable_appearance/floorlight = mutable_appearance('icons/obj/doors/airlocks/station/overlays.dmi', "unres_[heading]", FLOAT_LAYER, src, ABOVE_LIGHTING_PLANE)
			switch (heading)
				if (NORTH)
					floorlight.pixel_x = 0
					floorlight.pixel_y = 32
				if (SOUTH)
					floorlight.pixel_x = 0
					floorlight.pixel_y = -32
				if (EAST)
					floorlight.pixel_x = 32
					floorlight.pixel_y = 0
				if (WEST)
					floorlight.pixel_x = -32
					floorlight.pixel_y = 0
			. += floorlight

//STATION AIRLOCKS
/obj/machinery/door/airlock
	icon = 'voidcrew/icons/obj/doors/airlocks/station/public.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/station/overlays.dmi'

/obj/machinery/door/airlock/command
	icon = 'voidcrew/icons/obj/doors/airlocks/station/command.dmi'

/obj/machinery/door/airlock/security
	icon = 'voidcrew/icons/obj/doors/airlocks/station/security.dmi'

/obj/machinery/door/airlock/engineering
	icon = 'voidcrew/icons/obj/doors/airlocks/station/engineering.dmi'

/obj/machinery/door/airlock/medical
	icon = 'voidcrew/icons/obj/doors/airlocks/station/medical.dmi'

/obj/machinery/door/airlock/maintenance
	icon = 'voidcrew/icons/obj/doors/airlocks/station/maintenance.dmi'

/obj/machinery/door/airlock/maintenance/external
	icon = 'voidcrew/icons/obj/doors/airlocks/station/maintenanceexternal.dmi'

/obj/machinery/door/airlock/mining
	icon = 'voidcrew/icons/obj/doors/airlocks/station/mining.dmi'

/obj/machinery/door/airlock/atmos
	icon = 'voidcrew/icons/obj/doors/airlocks/station/atmos.dmi'

/obj/machinery/door/airlock/research
	icon = 'voidcrew/icons/obj/doors/airlocks/station/research.dmi'

/obj/machinery/door/airlock/freezer
	icon = 'voidcrew/icons/obj/doors/airlocks/station/freezer.dmi'

/obj/machinery/door/airlock/science
	icon = 'voidcrew/icons/obj/doors/airlocks/station/science.dmi'

/obj/machinery/door/airlock/virology
	icon = 'voidcrew/icons/obj/doors/airlocks/station/virology.dmi'

//STATION CUSTOM ARILOCKS
/obj/machinery/door/airlock/solgov
	name = "solgov airlock"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/solgov.dmi'
	assemblytype = /obj/structure/door_assembly/door_assembly_solgov
	normal_integrity = 450

/obj/machinery/door/airlock/solgov/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/syndicate
	name = "suspicious airlock"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/syndicate.dmi'
	assemblytype = /obj/structure/door_assembly/door_assembly_syndicate
	normal_integrity = 450

/obj/machinery/door/airlock/syndicate/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/corporate
	name = "corporate airlock"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/corporate.dmi'
	assemblytype = /obj/structure/door_assembly/door_assembly_corporate
	normal_integrity = 450

/obj/machinery/door/airlock/corporate/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/centcom_new
	name = "centcom airlock"
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom_new.dmi'
	assemblytype = /obj/structure/door_assembly/door_assembly_centcom_new
	normal_integrity = 450

/obj/machinery/door/airlock/centcom_new/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/service
	icon = 'voidcrew/icons/obj/doors/airlocks/station/service.dmi'
	assemblytype = /obj/structure/door_assembly/door_assembly_service

/obj/machinery/door/airlock/service/glass
	opacity = FALSE
	glass = TRUE

/obj/machinery/door/airlock/captain
	icon = 'voidcrew/icons/obj/doors/airlocks/cap.dmi'

/obj/machinery/door/airlock/hop
	icon = 'voidcrew/icons/obj/doors/airlocks/hop.dmi'

/obj/machinery/door/airlock/hos
	icon = 'voidcrew/icons/obj/doors/airlocks/hos.dmi'

/obj/machinery/door/airlock/hos/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/ce
	icon = 'voidcrew/icons/obj/doors/airlocks/ce.dmi'

/obj/machinery/door/airlock/ce/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/rd
	icon = 'voidcrew/icons/obj/doors/airlocks/rd.dmi'

/obj/machinery/door/airlock/rd/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/qm
	icon = 'voidcrew/icons/obj/doors/airlocks/qm.dmi'

/obj/machinery/door/airlock/qm/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/cmo
	icon = 'voidcrew/icons/obj/doors/airlocks/cmo.dmi'

/obj/machinery/door/airlock/cmo/glass
	opacity = FALSE
	glass = TRUE
	normal_integrity = 400

/obj/machinery/door/airlock/psych
	icon = 'voidcrew/icons/obj/doors/airlocks/psych.dmi'

/obj/machinery/door/airlock/asylum
	icon = 'voidcrew/icons/obj/doors/airlocks/asylum.dmi'

/obj/machinery/door/airlock/bathroom
	icon = 'voidcrew/icons/obj/doors/airlocks/bathroom.dmi'

//STATION MINERAL AIRLOCKS
/obj/machinery/door/airlock/gold
	icon = 'voidcrew/icons/obj/doors/airlocks/station/gold.dmi'

/obj/machinery/door/airlock/silver
	icon = 'voidcrew/icons/obj/doors/airlocks/station/silver.dmi'

/obj/machinery/door/airlock/diamond
	icon = 'voidcrew/icons/obj/doors/airlocks/station/diamond.dmi'

/obj/machinery/door/airlock/uranium
	icon = 'voidcrew/icons/obj/doors/airlocks/station/uranium.dmi'

/obj/machinery/door/airlock/plasma
	icon = 'voidcrew/icons/obj/doors/airlocks/station/plasma.dmi'

/obj/machinery/door/airlock/bananium
	icon = 'voidcrew/icons/obj/doors/airlocks/station/bananium.dmi'

/obj/machinery/door/airlock/sandstone
	icon = 'voidcrew/icons/obj/doors/airlocks/station/sandstone.dmi'

/obj/machinery/door/airlock/wood
	icon = 'voidcrew/icons/obj/doors/airlocks/station/wood.dmi'

//STATION 2 AIRLOCKS

/obj/machinery/door/airlock/public
	icon = 'voidcrew/icons/obj/doors/airlocks/station2/glass.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/station2/overlays.dmi'

/obj/machinery/door/airlock/public/glass/no_lights
	has_environment_lights = FALSE

//EXTERNAL AIRLOCKS
/obj/machinery/door/airlock/external
	icon = 'voidcrew/icons/obj/doors/airlocks/external/external.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/external/overlays.dmi'

//CENTCOM
/obj/machinery/door/airlock/centcom
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/centcom/overlays.dmi'

/obj/machinery/door/airlock/grunge
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/centcom/overlays.dmi'

//VAULT
/obj/machinery/door/airlock/vault
	icon = 'voidcrew/icons/obj/doors/airlocks/vault/vault.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/vault/overlays.dmi'

//HATCH
/obj/machinery/door/airlock/hatch
	icon = 'voidcrew/icons/obj/doors/airlocks/hatch/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/hatch/overlays.dmi'

/obj/machinery/door/airlock/maintenance_hatch
	icon = 'voidcrew/icons/obj/doors/airlocks/hatch/maintenance.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/hatch/overlays.dmi'

//HIGH SEC
/obj/machinery/door/airlock/highsecurity
	icon = 'voidcrew/icons/obj/doors/airlocks/highsec/highsec.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/highsec/overlays.dmi'

//TITANIUM / SHUTTLE
/obj/machinery/door/airlock/titanium
	icon = 'voidcrew/icons/obj/doors/airlocks/shuttle/shuttle.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/shuttle/overlays.dmi'

/obj/machinery/door/airlock/shuttle
	icon = 'voidcrew/icons/obj/doors/airlocks/shuttle/shuttle.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/shuttle/overlays.dmi'

//SHUTTLE2
/obj/machinery/door/airlock/shuttle/ferry
	icon = 'voidcrew/icons/obj/doors/airlocks/shuttle2/erokez.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/shuttle2/overlays.dmi'

/obj/machinery/door/airlock/external/wagon
	icon = 'voidcrew/icons/obj/doors/airlocks/shuttle2/wagon.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/shuttle2/overlays.dmi'

//SURVIVAL
/obj/machinery/door/airlock/survival_pod
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/survival/overlays.dmi'

//ABDUCTOR
/obj/machinery/door/airlock/abductor
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/abductor/overlays.dmi'

//CULT
/obj/machinery/door/airlock/cult
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/cult/runed/overlays.dmi'

/obj/machinery/door/airlock/cult/unruned
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/cult/unruned/overlays.dmi'

//CLOCKWORK
/obj/machinery/door/airlock/bronze
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/clockwork/overlays.dmi'

//MULTI-TILE

/obj/machinery/door/airlock/multi_tile
	icon = 'voidcrew/icons/obj/doors/airlocks/multi_tile/glass.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/multi_tile/glass_overlays.dmi'

/obj/machinery/door/airlock/multi_tile/glass
	icon = 'voidcrew/icons/obj/doors/airlocks/multi_tile/glass.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/multi_tile/glass_overlays.dmi'

/obj/machinery/door/airlock/multi_tile/metal
	icon = 'voidcrew/icons/obj/doors/airlocks/multi_tile/metal.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/multi_tile/metal_overlays.dmi'

//TRAM

/obj/machinery/door/airlock/tram
	name = "tram door"
	icon = 'voidcrew/icons/obj/doors/airlocks/tram/tram.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/tram/tram_overlays.dmi'
	doorOpen = 'sound/machines/tram/tramopen.ogg'
	doorClose = 'sound/machines/tram/tramclose.ogg'

/obj/machinery/door/airlock/tram/set_light(l_range, l_power, l_color = NONSENSICAL_VALUE, l_angle, l_dir, l_height, l_on)
	return

//ASSEMBLYS
/obj/structure/door_assembly/door_assembly_public
	icon = 'voidcrew/icons/obj/doors/airlocks/station2/glass.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/station2/overlays.dmi'

/obj/structure/door_assembly/door_assembly_com
	icon = 'voidcrew/icons/obj/doors/airlocks/station/command.dmi'

/obj/structure/door_assembly/door_assembly_sec
	icon = 'voidcrew/icons/obj/doors/airlocks/station/security.dmi'

/obj/structure/door_assembly/door_assembly_eng
	icon = 'voidcrew/icons/obj/doors/airlocks/station/engineering.dmi'

/obj/structure/door_assembly/door_assembly_min
	icon = 'voidcrew/icons/obj/doors/airlocks/station/mining.dmi'

/obj/structure/door_assembly/door_assembly_atmo
	icon = 'voidcrew/icons/obj/doors/airlocks/station/atmos.dmi'

/obj/structure/door_assembly/door_assembly_research
	icon = 'voidcrew/icons/obj/doors/airlocks/station/research.dmi'

/obj/structure/door_assembly/door_assembly_science
	icon = 'voidcrew/icons/obj/doors/airlocks/station/science.dmi'

/obj/structure/door_assembly/door_assembly_viro
	icon = 'voidcrew/icons/obj/doors/airlocks/station/virology.dmi'

/obj/structure/door_assembly/door_assembly_med
	icon = 'voidcrew/icons/obj/doors/airlocks/station/medical.dmi'

/obj/structure/door_assembly/door_assembly_mai
	icon = 'voidcrew/icons/obj/doors/airlocks/station/maintenance.dmi'

/obj/structure/door_assembly/door_assembly_extmai
	icon = 'voidcrew/icons/obj/doors/airlocks/station/maintenanceexternal.dmi'

/obj/structure/door_assembly/door_assembly_ext
	icon = 'voidcrew/icons/obj/doors/airlocks/external/external.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/external/overlays.dmi'

/obj/structure/door_assembly/door_assembly_fre
	icon = 'voidcrew/icons/obj/doors/airlocks/station/freezer.dmi'

/obj/structure/door_assembly/door_assembly_hatch
	icon = 'voidcrew/icons/obj/doors/airlocks/hatch/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/hatch/overlays.dmi'

/obj/structure/door_assembly/door_assembly_mhatch
	icon = 'voidcrew/icons/obj/doors/airlocks/hatch/maintenance.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/hatch/overlays.dmi'

/obj/structure/door_assembly/door_assembly_highsecurity
	icon = 'voidcrew/icons/obj/doors/airlocks/highsec/highsec.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/highsec/overlays.dmi'

/obj/structure/door_assembly/door_assembly_vault
	icon = 'voidcrew/icons/obj/doors/airlocks/vault/vault.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/vault/overlays.dmi'


/obj/structure/door_assembly/door_assembly_centcom
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/centcom/overlays.dmi'

/obj/structure/door_assembly/door_assembly_grunge
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/centcom/overlays.dmi'

/obj/structure/door_assembly/door_assembly_gold
	icon = 'voidcrew/icons/obj/doors/airlocks/station/gold.dmi'

/obj/structure/door_assembly/door_assembly_silver
	icon = 'voidcrew/icons/obj/doors/airlocks/station/silver.dmi'

/obj/structure/door_assembly/door_assembly_diamond
	icon = 'voidcrew/icons/obj/doors/airlocks/station/diamond.dmi'

/obj/structure/door_assembly/door_assembly_uranium
	icon = 'voidcrew/icons/obj/doors/airlocks/station/uranium.dmi'

/obj/structure/door_assembly/door_assembly_plasma
	icon = 'voidcrew/icons/obj/doors/airlocks/station/plasma.dmi'

/obj/structure/door_assembly/door_assembly_bananium
	icon = 'voidcrew/icons/obj/doors/airlocks/station/bananium.dmi'

/obj/structure/door_assembly/door_assembly_sandstone
	icon = 'voidcrew/icons/obj/doors/airlocks/station/sandstone.dmi'

/obj/structure/door_assembly/door_assembly_wood
	icon = 'voidcrew/icons/obj/doors/airlocks/station/wood.dmi'

/obj/structure/door_assembly/door_assembly_solgov
	name = "solgov airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/solgov.dmi'
	glass_type = /obj/machinery/door/airlock/solgov/glass
	airlock_type = /obj/machinery/door/airlock/solgov

/obj/structure/door_assembly/door_assembly_syndicate
	name = "suspicious airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/syndicate.dmi'
	glass_type = /obj/machinery/door/airlock/syndicate/glass
	airlock_type = /obj/machinery/door/airlock/syndicate

/obj/structure/door_assembly/door_assembly_corporate
	name = "corporate airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/corporate.dmi'
	glass_type = /obj/machinery/door/airlock/corporate/glass
	airlock_type = /obj/machinery/door/airlock/corporate

/obj/structure/door_assembly/door_assembly_centcom_new
	name = "centcom airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/centcom/centcom_new.dmi'
	glass_type = /obj/machinery/door/airlock/corporate/glass
	airlock_type = /obj/machinery/door/airlock/corporate

/obj/structure/door_assembly/door_assembly_service
	name = "service airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/station/service.dmi'
	base_name = "service airlock"
	glass_type = /obj/machinery/door/airlock/service/glass
	airlock_type = /obj/machinery/door/airlock/service

/obj/structure/door_assembly/door_assembly_captain
	name = "captain airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/cap.dmi'
	glass_type = /obj/machinery/door/airlock/command/glass
	airlock_type = /obj/machinery/door/airlock/captain

/obj/structure/door_assembly/door_assembly_hop
	name = "head of personnel airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/hop.dmi'
	glass_type = /obj/machinery/door/airlock/command/glass
	airlock_type = /obj/machinery/door/airlock/hop

/obj/structure/door_assembly/hos
	name = "head of security airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/hos.dmi'
	glass_type = /obj/machinery/door/airlock/hos/glass
	airlock_type = /obj/machinery/door/airlock/hos

/obj/structure/door_assembly/door_assembly_cmo
	name = "chief medical officer airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/cmo.dmi'
	glass_type = /obj/machinery/door/airlock/cmo/glass
	airlock_type = /obj/machinery/door/airlock/cmo

/obj/structure/door_assembly/door_assembly_ce
	name = "chief engineer airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/ce.dmi'
	glass_type = /obj/machinery/door/airlock/ce/glass
	airlock_type = /obj/machinery/door/airlock/ce

/obj/structure/door_assembly/door_assembly_rd
	name = "research director airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/rd.dmi'
	glass_type = /obj/machinery/door/airlock/rd/glass
	airlock_type = /obj/machinery/door/airlock/rd

/obj/structure/door_assembly/door_assembly_qm
	name = "quartermaster airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/qm.dmi'
	glass_type = /obj/machinery/door/airlock/qm/glass
	airlock_type = /obj/machinery/door/airlock/qm

/obj/structure/door_assembly/door_assembly_psych
	name = "psychologist airlock assembly"
	icon = 'voidcrew/icons/obj/doors/airlocks/psych.dmi'
	glass_type = /obj/machinery/door/airlock/medical/glass
	airlock_type = /obj/machinery/door/airlock/psych

/obj/structure/door_assembly/door_assembly_asylum
	icon = 'voidcrew/icons/obj/doors/airlocks/asylum.dmi'

/obj/structure/door_assembly/door_assembly_bathroom
	icon = 'voidcrew/icons/obj/doors/airlocks/bathroom.dmi'

/obj/machinery/door/airlock/hydroponics
	icon = 'voidcrew/icons/obj/doors/airlocks/station/botany.dmi'

/obj/structure/door_assembly/door_assembly_hydro
	icon = 'voidcrew/icons/obj/doors/airlocks/station/botany.dmi'

/obj/structure/door_assembly/
	icon = 'voidcrew/icons/obj/doors/airlocks/station/public.dmi'
	overlays_file = 'voidcrew/icons/obj/doors/airlocks/station/overlays.dmi'

#undef AIRLOCK_FRAME_CLOSED
#undef AIRLOCK_FRAME_CLOSING
#undef AIRLOCK_FRAME_OPEN
#undef AIRLOCK_FRAME_OPENING
