/// Subtype for escape pod ports so that we can give them trait behaviour
/obj/docking_port/stationary/escape_pod
	name = "escape pod loader"
	height = 5
	width = 3
	dwidth = 1
	roundstart_template = /datum/map_template/shuttle/escape_pod/default
	/// Set to true if you have a snowflake escape pod dock which needs to always have the normal pod or some other one
	var/enforce_specific_pod = FALSE

/obj/docking_port/stationary/escape_pod/Initialize(mapload)
	. = ..()
	if (enforce_specific_pod)
		return

	if (HAS_TRAIT(SSstation, STATION_TRAIT_SMALLER_PODS))
		roundstart_template = /datum/map_template/shuttle/escape_pod/cramped
		return
	if (HAS_TRAIT(SSstation, STATION_TRAIT_BIGGER_PODS))
		roundstart_template = /datum/map_template/shuttle/escape_pod/luxury

// should fit the syndicate infiltrator, and smaller ships like the battlecruiser corvettes and fighters
/obj/docking_port/stationary/syndicate
	name = "near the station"
	dheight = 1
	dwidth = 12
	height = 17
	width = 23
	shuttle_id = "syndicate_nearby"

/obj/docking_port/stationary/syndicate/northwest
	name = "northwest of station"
	shuttle_id = "syndicate_nw"

/obj/docking_port/stationary/syndicate/northeast
	name = "northeast of station"
	shuttle_id = "syndicate_ne"

/obj/docking_port/stationary/transit
	name = "In Transit"
	override_can_dock_checks = TRUE
	/// The turf reservation returned by the transit area request
	var/datum/turf_reservation/reserved_area
	/// The area created during the transit area reservation
	var/area/shuttle/transit/assigned_area
	/// The mobile port that owns this transit port
	var/obj/docking_port/mobile/owner

/obj/docking_port/stationary/transit/Initialize(mapload)
	. = ..()
	SSshuttle.transit_docking_ports += src

/obj/docking_port/stationary/transit/Destroy(force=FALSE)
	if(force)
		var/obj/docking_port/mobile/still_docked = get_docked()
		if(still_docked)
			log_world("A transit dock was destroyed while something was docked to it.")
		SSshuttle.transit_docking_ports -= src
		if(owner)
			if(owner.assigned_transit == src)
				owner.assigned_transit = null
			owner = null
		if(!QDELETED(reserved_area))
			qdel(reserved_area)
		reserved_area = null
		// VOIDCREW EDIT: free the area too. SSshuttle.generate_transit_dock() news an
		// /area/shuttle/transit per transit dock and nothing anywhere qdel'd it -
		// reap_emptied_areas() skips /area/shuttle by design, so every transit dock left one
		// behind permanently. The 52-cycle soak counted /area/shuttle/transit 5 -> 105
		// (+2.00/cycle) with 78 of them holding no resident turfs at the end.
		//
		// After reserved_area, not before: releasing the reservation is what hands the
		// ground back to the space area. The release drain is async, so this can qdel an
		// area that still nominally holds turfs - which is safe, because
		// SSmapping.fire()'s reservation drain already guards a dead area explicitly
		// (the isnull(old_area.turfs_to_uncontain_by_zlevel) branch).
		//
		// VOIDCREW EDIT: whatever is still standing here has to stop naming the area first.
		// A hull parked in hyperspace keeps `underlying_areas_by_turf[turf] = assigned_area`
		// for every tile it occupies (set by /area/onShuttleMove), and that is a hard ref: qdel
		// the area under a port that survives us - the ownerless-transit reaper, the admin
		// shuttle verbs - and the area cannot be collected, which is a hard delete of
		// /area/shuttle/transit and a dangling area on the hull's own tiles. The usual caller,
		// /obj/docking_port/mobile/Destroy(), now clears that map before it cascades into us, so
		// this loop is a no-op on the common path and only earns its keep on the ones where the
		// ship outlives its transit dock. A missing entry is already handled downstream
		// (`underlying_area || fallback_area`), so dropping these keys is the same outcome the
		// hull would get from a tile it never recorded.
		// Copy() because the subtraction below mutates the list being walked.
		if(assigned_area && still_docked)
			for(var/turf/tile as anything in still_docked.underlying_areas_by_turf.Copy())
				if(still_docked.underlying_areas_by_turf[tile] == assigned_area)
					still_docked.underlying_areas_by_turf -= tile
		if(!QDELETED(assigned_area))
			qdel(assigned_area)
		assigned_area = null
	return ..()

/obj/docking_port/stationary/picked
	///Holds a list of map name strings for the port to pick from
	var/list/shuttlekeys

/obj/docking_port/stationary/picked/Initialize(mapload)
	. = ..()
	if(!LAZYLEN(shuttlekeys))
		WARNING("Random docking port [shuttle_id] loaded with no shuttle keys")
		return
	var/selectedid = pick(shuttlekeys)
	roundstart_template = SSmapping.shuttle_templates[selectedid]

/obj/docking_port/stationary/picked/whiteship
	name = "Deep Space"
	shuttle_id = "whiteship_away"
	height = 45 //Width and height need to remain in sync with the size of whiteshipdock.dmm, otherwise we'll get overflow
	width = 45
	dheight = 14
	dwidth = 18
	dir = 2
	shuttlekeys = list(
		"whiteship_meta",
		"whiteship_pubby",
		"whiteship_box",
		"whiteship_cere",
		"whiteship_kilo",
		"whiteship_donut",
		"whiteship_delta",
		"whiteship_tram",
		"whiteship_personalshuttle",
		"whiteship_obelisk",
		"whiteship_birdshot",
	)

