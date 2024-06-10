/obj/machinery/computer/camera_advanced/shuttle_docker/voidcrew
	name = "Ship navigation computer"
	desc = "Used to designate a precise transit location for your ship."
	view_range = 20
	x_offset = 0
	y_offset = 0
	see_hidden = TRUE
	circuit = /obj/item/circuitboard/computer/syndicate_shuttle_docker
	whitelist_turfs = list()

/obj/machinery/computer/camera_advanced/shuttle_docker/voidcrew/connect_to_shuttle(mapload, port_id, obj/docking_port/stationary/dock)
	. = ..()
	if(port_id)
		shuttleId = port_id
		shuttlePortId = "[port_id]_custom"
	if(dock)
		add_jumpable_port(dock.shuttle_id)
	return TRUE

/obj/machinery/computer/camera_advanced/shuttle_docker/voidcrew/Initialize(mapload)
	. = ..()
	actions += new /datum/action/innate/shuttledocker_rotate(src)
	actions += new /datum/action/innate/shuttledocker_place(src)

	set_init_ports()

	var/obj/docking_port/mobile/voidcrew/ship_port = SSshuttle.get_containing_shuttle(src)
	if (ship_port.current_ship)
		if (ship_port.current_ship.close_overmap_objects.len)
			for (var/obj/structure/overmap/o in ship_port.current_ship.close_overmap_objects)
				if (istype(o, /obj/structure/overmap/planet))
					var/obj/structure/overmap/planet/p = o
					var/obj/docking_port/stationary/d = p.reserve_dock
					if (d)
						connect_to_shuttle(mapload, ship_port.shuttle_id, d)

/obj/machinery/computer/camera_advanced/shuttle_docker/placeLandingSpot()
	. = ..()
	var/obj/docking_port/mobile/voidcrew/mobile_port = SSshuttle.get_containing_shuttle(src)
	mobile_port.port_destinations = my_port
