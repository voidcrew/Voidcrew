/**
 * Express supply console, made safe to use inside a ship.
 *
 * The normal voidcrew order path (/obj/machinery/computer/voidcrew_cargo, see
 * purchasing.dm) spawns crates straight onto the cargo shuttle and never uses a pod,
 * so it cannot hurt anybody. TG's express console is a second, quieter order path:
 * the Energia hull maps an express console circuitboard on a rack in its cargo bay,
 * so any crew that builds it is ordering deliveries that arrive by supply pod.
 *
 * Two things about that were wrong for a ship:
 *
 * 1. Every pod it can fire lands with an explosion. The stock pod's explosionSize is
 *    list(0,0,2,3) - light 2, flame 3 - and the bluespace pod (the disk upgrade, and
 *    the "Empty Supplypod" pack's special_pod) is list(0,0,1,2). That is the same
 *    charge that broke an APC, a PACMAN generator and a door, burned a ship's plasma
 *    and ore, and gibbed two corpses across five stray-pod landings in round 4 of the
 *    14/15 playtest. A delivery the crew paid for must not damage their own hull, so
 *    both are zeroed here: the pods still whistle in, land, and boom on the speakers,
 *    but nothing at the drop turf takes damage.
 *
 * 2. The landing zone defaults to /area/station/cargo/storage, which resolves to the
 *    derelict station's cargo bay - a delivery ordered on a ship would arrive
 *    somewhere the crew cannot reach. A console standing in a ship area now delivers
 *    to that area instead.
 *
 * Deliberately dangerous pods (assault pods, drop pods, the deathmatch missile) are
 * not reachable from this console and are left alone.
 *
 * Not fixed here, and worth a look on its own: the express console spends the global
 * ACCOUNT_CAR department budget rather than the ship's bank account, and that budget
 * starts empty, so in practice the console cannot buy anything until someone funds it.
 */

/// Safe version of the stock supply pod, used for every express delivery.
/obj/structure/closet/supplypod/express
	explosionSize = list(0, 0, 0, 0)

// The bluespace pod is only ever reachable through this console (the bluespace disk
// upgrade and the "Empty Supplypod" pack), so it is disarmed at the source.
/obj/structure/closet/supplypod/bluespacepod
	explosionSize = list(0, 0, 0, 0)

/obj/machinery/computer/cargo/express
	pod_type = /obj/structure/closet/supplypod/express

/obj/machinery/computer/cargo/express/Initialize(mapload)
	. = ..()
	// Parent resolved landingzone to the station cargo bay. Ships get their own room.
	var/area/our_area = get_area(src)
	if(istype(our_area, /area/shuttle))
		landingzone = our_area
