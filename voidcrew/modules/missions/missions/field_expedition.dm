/**
 * # Field Expedition
 *
 * "Our probe went down on a planet. Find the wreck, pull its core, mind the
 * local wildlife."
 *
 * The recovery pipeline pointed at a planet instead of a space ruin: the
 * bound core spawns on a random stretch of surface when the planet loads,
 * with the usual GPS beacon - and picking it up can wake whatever nests
 * nearby. Planets relocate rather than die, so the waypoint follows the
 * target and the standard retarget budget covers a wiped surface.
 */
/datum/mission/field_expedition
	name = "Field Expedition"
	weight = 9
	mission_limit = 2
	voucher_count = 1
	quest_lost_policy = MISSION_QUEST_LOST_RETARGET
	gps_tag_prefix = "XPDN"
	// Green-band pay, a notch over plain recovery: planets mean weather,
	// wildlife and a walk from the dock
	value_min = 800
	value_max = 1100

	/// zone_mobs theme that may answer the pickup
	var/wave_theme
	/// Chance (0-100) that lifting the core wakes the neighbors
	var/ambush_chance = 60

/datum/mission/field_expedition/setup_target()
	var/datum/mission_target/planet/planet_target = new(src)
	if(!planet_target.resolve())
		qdel(planet_target)
		return FALSE
	target = planet_target
	return TRUE

/datum/mission/field_expedition/generate_details()
	var/static/list/expedition_objects = list(
		"survey probe core",
		"crashed relay's flight computer",
		"seismic monitor archive",
		"atmospheric sampler array",
		"derelict rover's databank",
	)
	objective_name = pick(expedition_objects)
	wave_theme = pick_weight(list(
		/obj/effect/zone_mobs/wildlife = 6,
		/obj/effect/zone_mobs/bug = 4,
		/obj/effect/zone_mobs/pirate = 2,
	))

/datum/mission/field_expedition/build_objectives()
	add_objective(new /datum/mission_objective/field/plant_quest)
	add_objective(new /datum/mission_objective/deliver/bound)

/// Picking the core up can wake the neighborhood (once per era)
/datum/mission/field_expedition/on_quest_atom_registered(atom/movable/new_quest_atom)
	if(isitem(new_quest_atom))
		RegisterSignal(new_quest_atom, COMSIG_ITEM_PICKUP, PROC_REF(on_core_pickup))

/datum/mission/field_expedition/proc/on_core_pickup(obj/item/source, mob/taker)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_ITEM_PICKUP)
	if(failed || completed || !wave_theme || !prob(ambush_chance))
		return
	new wave_theme(get_turf(taker), list(1, 2))
	servant?.ship_notify("[name]: ground team disturbed something at the crash site.", "MISSION UPDATE", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)

/datum/mission/field_expedition/update_text()
	name = "Field Expedition: [objective_name]"
	desc = "Our [objective_name] is down on the planet at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		Land, locate the beacon-marked salvage and bring it to the mission pad. Picking it up may draw an ambush. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to receive the salvage's beacon ([gps_tag])."

/datum/mission/field_expedition/waypoint_label()
	return "Expedition: [objective_name]"
