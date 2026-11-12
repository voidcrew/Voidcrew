/**
 * # Outpost floors: quarters, workshop and canteen
 *
 * Owner: P14 (spec 3b.5, L35). Three service rooms (outpost_service_rooms.dm) sold only on a leased floor, at
 * OUTPOST_FLOOR_QUARTERS_COST, OUTPOST_FLOOR_WORKSHOP_COST and OUTPOST_FLOOR_CANTEEN_COST, each drawn once per
 * outpost style (outpost_styles.dm). They are bought, placed and powered like every other room, and what stands
 * in them is outpost property (protect_fixtures()): nothing in a room can be taken apart or carried to a ship.
 *
 * Nothing here pays anybody. The quarters add two resident cryopods; the workshop and the canteen are machines a
 * crew could build by hand, already wired and bolted down. No room maps a tool, a weapon or stock in
 * (contract_problems() checks the maps).
 */

// ===== AREAS =====
// One instance per installed room (no UNIQUE_AREA), like the other service rooms (outpost_room_power.dm)

/area/voidcrew/player_outpost/service_room/quarters
	name = "\improper Quarters"

/area/voidcrew/player_outpost/service_room/workshop
	name = "\improper Workshop"

/area/voidcrew/player_outpost/service_room/canteen
	name = "\improper Canteen"

// ===== MAPS =====
// Each is authored with its entrance on the south edge; placement rotates it.

/datum/map_template/outpost_upgrade/quarters
	name = "Outpost Quarters"

/datum/map_template/outpost_upgrade/quarters/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_quarters_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/quarters/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_quarters_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/map_template/outpost_upgrade/workshop
	name = "Outpost Workshop"

/datum/map_template/outpost_upgrade/workshop/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_workshop_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/workshop/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_workshop_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/datum/map_template/outpost_upgrade/canteen
	name = "Outpost Canteen"

/datum/map_template/outpost_upgrade/canteen/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_canteen_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/canteen/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_canteen_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

// ===== THE ROOMS =====

/// A room sold only on a leased floor. Abstract: no id, so it never enters the catalog.
/datum/outpost_upgrade/service/floor_room
	floors_only = TRUE
	/// The entrance starts at Members, not Public: the room is the crew's own (bunks a visitor could claim, the
	/// crew's lathe). The crew can open it up with the Door Access tool like any other door.
	var/members_door = FALSE

/// floors_only keeps these out of a player outpost's catalogue (offers_upgrade()); this refuses one bought any other way
/datum/outpost_upgrade/service/floor_room/purchase_requirement(obj/structure/overmap/dynamic/player_outpost/home)
	if(!istype(home, /obj/structure/overmap/dynamic/player_outpost/floor))
		return "Not sold here."
	return ..()

/// Called at install and on abandonment (reset_door_access()). With nobody owning the place there are no members
/// to let in, so an unowned host gets the ordinary public default.
/datum/outpost_upgrade/service/floor_room/apply_door_defaults()
	if(!members_door || QDELETED(outpost) || !outpost.founder_ckey)
		return ..()
	for(var/datum/weakref/door_ref as anything in doors)
		var/obj/machinery/door/airlock/outpost/service/door = door_ref.resolve()
		if(!QDELETED(door))
			outpost.apply_door_access(door, OUTPOST_DOOR_MEMBERS, outpost_door_first_side(door.unres_sides))

/// How many machines and structures of `fixture_type` stand in the placed room
/datum/outpost_upgrade/service/floor_room/proc/count_fixtures(fixture_type)
	var/count = 0
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/fixture in tile)
			if(istype(fixture, fixture_type))
				count++
	return count

/// One problem line for each type in `wanted` (type -> least count) the placed room is short of
/datum/outpost_upgrade/service/floor_room/proc/fixture_problems(list/wanted)
	. = list()
	for(var/obj/fixture_type as anything in wanted)
		var/found = count_fixtures(fixture_type)
		if(found < wanted[fixture_type])
			. += "[found] [initial(fixture_type.name)], not [wanted[fixture_type]]"

/// A tool, a gun or a blade lying in the room: these rooms sell furniture and machines, never gear. A pen is sharp but does no harm.
/datum/outpost_upgrade/service/floor_room/proc/is_mapped_gear(obj/item/thing)
	return thing.tool_behaviour || isgun(thing) || (thing.get_sharpness() && thing.force) \
		|| istype(thing, /obj/item/melee) || istype(thing, /obj/item/storage/toolbox) || istype(thing, /obj/item/storage/belt)

/datum/outpost_upgrade/service/floor_room/contract_problems()
	. = ..()
	if(!installed)
		return
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/item/thing in tile)
			if(is_mapped_gear(thing))
				. += "the [thing.name] at [tile.x],[tile.y] is a tool or a weapon"
		// A machine nobody bolted down can be dragged out of the room, and outpost property never breaks
		for(var/obj/machinery/machine in tile)
			if(!machine.anchored)
				. += "the [machine.name] at [tile.x],[tile.y] is not bolted down"

// ===== QUARTERS =====

/datum/outpost_upgrade/service/floor_room/quarters
	id = "quarters"
	name = "Quarters"
	desc = "Four bunks, four lockers and two cryopods."
	price = OUTPOST_FLOOR_QUARTERS_COST
	template_type = /datum/map_template/outpost_upgrade/quarters
	area_type = /area/voidcrew/player_outpost/service_room/quarters
	members_door = TRUE
	/// Weakrefs to the room's cryopods
	var/list/datum/weakref/pods

/datum/outpost_upgrade/service/floor_room/quarters/Destroy()
	pods = null
	return ..()

/// The room's cryopods take resident arrivals beside the shell's own (available_resident_pod()). A pod loaded
/// from a map never links itself, so each is linked here, as install_home_bundle() links the shell's.
/datum/outpost_upgrade/service/floor_room/quarters/on_service_installed(mob/user)
	pods = list()
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/machinery/cryopod/pod in tile)
			pod.relink_to_ship()
			pods += WEAKREF(pod)

/// The room's cryopods that still exist
/datum/outpost_upgrade/service/floor_room/quarters/proc/room_pods()
	var/list/found = list()
	for(var/datum/weakref/pod_ref as anything in pods)
		var/obj/machinery/cryopod/pod = pod_ref.resolve()
		if(!QDELETED(pod))
			found += pod
	return found

/datum/outpost_upgrade/service/floor_room/quarters/contract_problems()
	. = ..()
	if(!installed)
		return
	var/static/list/wanted = list(
		/obj/structure/bed = 4,
		/obj/structure/closet/secure_closet/personal/bunk = 4,
		/obj/machinery/cryopod = 2,
	)
	. += fixture_problems(wanted)
	for(var/obj/machinery/cryopod/pod as anything in room_pods())
		if(pod.linked_outpost != outpost || !(pod in outpost.resident_pods))
			. += "the cryopod at [pod.x],[pod.y] takes no resident arrivals"
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/structure/closet/locker in tile)
			// Closets fill on first opening; opened or not, a locker here must hold nothing
			if(length(locker.contents))
				. += "the [locker.name] at [tile.x],[tile.y] is not empty"

/// A bunk's locker. A personal closet comes with a pack and a headset; this one comes with nothing.
/obj/structure/closet/secure_closet/personal/bunk
	name = "bunk locker"
	desc = "A locker for whoever has the bunk beside it."

/obj/structure/closet/secure_closet/personal/bunk/PopulateContents()
	return

/// The same locker in old wood
/obj/structure/closet/secure_closet/personal/bunk/cabinet
	name = "bunk cabinet"
	desc = "A wooden cabinet for whoever has the bunk beside it."
	icon_state = "cabinet"
	resistance_flags = FLAMMABLE
	open_sound = 'sound/machines/closet/wooden_closet_open.ogg'
	close_sound = 'sound/machines/closet/wooden_closet_close.ogg'
	open_sound_volume = 25
	close_sound_volume = 50
	door_anim_time = 0 // the cabinet sprite has no door animation

// ===== WORKSHOP =====

/datum/outpost_upgrade/service/floor_room/workshop
	id = "workshop"
	name = "Workshop"
	desc = "An autolathe, workbenches, racks and a cell charger."
	price = OUTPOST_FLOOR_WORKSHOP_COST
	template_type = /datum/map_template/outpost_upgrade/workshop
	area_type = /area/voidcrew/player_outpost/service_room/workshop
	members_door = TRUE

/datum/outpost_upgrade/service/floor_room/workshop/contract_problems()
	. = ..()
	if(!installed)
		return
	var/static/list/wanted = list(
		/obj/machinery/autolathe = 1,
		/obj/machinery/cell_charger = 1,
		/obj/structure/table = 4,
		/obj/structure/rack = 3,
	)
	. += fixture_problems(wanted)
	// The room sells an empty lathe and an empty charger: materials and cells are the crew's to bring
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/machinery/cell_charger/charger in tile)
			if(charger.charging)
				. += "the cell charger at [tile.x],[tile.y] holds a cell"
		for(var/obj/machinery/autolathe/lathe in tile)
			if(lathe.materials?.total_amount())
				. += "the autolathe at [tile.x],[tile.y] holds materials"

// ===== CANTEEN =====

/datum/outpost_upgrade/service/floor_room/canteen
	id = "canteen"
	name = "Canteen"
	desc = "A bar, a kitchen, tables and a jukebox."
	price = OUTPOST_FLOOR_CANTEEN_COST
	template_type = /datum/map_template/outpost_upgrade/canteen
	area_type = /area/voidcrew/player_outpost/service_room/canteen

/datum/outpost_upgrade/service/floor_room/canteen/contract_problems()
	. = ..()
	if(!installed)
		return
	var/static/list/wanted = list(
		/obj/machinery/jukebox = 1,
		/obj/machinery/chem_dispenser/drinks = 2,
		/obj/machinery/microwave = 1,
		/obj/machinery/griddle = 1,
		/obj/machinery/oven = 1,
		/obj/structure/table = 6,
		/obj/structure/chair = 8,
	)
	. += fixture_problems(wanted)
	// Anyone the crew lets in may put a song on
	for(var/turf/tile as anything in room_turfs())
		for(var/obj/machinery/jukebox/player in tile)
			if(length(player.req_access) || length(player.req_one_access))
				. += "the jukebox at [tile.x],[tile.y] asks for access"
