/**
 * # Teleporter room
 *
 * The service room that puts a player outpost on the teleporter network (outpost_network.dm):
 * a network pad, which people leave from and arrive on. Sold only as this upgrade; the pad has no board.
 *
 * The owner's levers are the arrival fare (Pricing tab), the arrival policy and allow list
 * (Services tab) and docking LOCKDOWN. The room's door stays public and the door tool refuses it
 * (abuse review F-33): keying it would strand people who arrived by pad outside the only way home.
 */

/// Authored with its entrance on the south edge; placement rotates it.
/datum/map_template/outpost_upgrade/teleporter
	name = "Outpost Teleporter"

/datum/map_template/outpost_upgrade/teleporter/rundown
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_teleporter_rundown.dmm"
	outpost_style = OUTPOST_STYLE_RUNDOWN

/datum/map_template/outpost_upgrade/teleporter/clean
	mappath = "voidcrew/_maps/map_files/outposts/outpost_upgrade_teleporter_clean.dmm"
	outpost_style = OUTPOST_STYLE_CLEAN

/// Marked where pad arrivals used to land, beside the pad. They land on the pad now; removed once the room is installed.
/obj/effect/landmark/outpost_network_arrival
	name = "network arrival spot"

/datum/outpost_upgrade/service/teleporter
	id = "teleporter"
	name = "Teleporter"
	desc = "A teleporter pad on the outpost network."
	price = OUTPOST_TELEPORTER_COST
	template_type = /datum/map_template/outpost_upgrade/teleporter
	area_type = /area/voidcrew/player_outpost/service_room/teleporter
	doors_stay_public = TRUE
	/// Who may arrive by pad: OUTPOST_NETWORK_ARRIVALS_*
	var/arrival_policy = OUTPOST_NETWORK_ARRIVALS_OPEN
	/// Network ids of source pads admitted under the allow list policy
	var/list/allowed_pads = list()
	/// The room's network pad
	var/datum/weakref/pad_ref
	var/trips_in = 0
	var/trips_out = 0

/datum/outpost_upgrade/service/teleporter/Destroy()
	var/obj/machinery/outpost_network_pad/pad = pad_ref?.resolve()
	// An admin deleting the room datum takes the pad off the network; the pad itself stays
	pad?.cancel_charge("The pad went offline.")
	pad_ref = null
	return ..()

/datum/outpost_upgrade/service/teleporter/on_service_installed(mob/user)
	var/obj/machinery/outpost_network_pad/pad
	for(var/turf/tile as anything in room_turfs())
		if(!pad)
			pad = locate(/obj/machinery/outpost_network_pad) in tile
		var/obj/effect/landmark/outpost_network_arrival/mark = locate() in tile
		if(mark)
			qdel(mark)
	if(!pad)
		log_mapping("OUTPOST NETWORK: the teleporter room at '[outpost]' loaded without its pad.")
		return
	pad_ref = WEAKREF(pad)
	pad.link_host(outpost)

/datum/outpost_upgrade/service/teleporter/on_outpost_abandoned()
	// The next owner starts from the defaults. Unowned, the pad takes no arrivals anyway.
	arrival_policy = OUTPOST_NETWORK_ARRIVALS_OPEN
	allowed_pads.Cut()

/// A pad row for the management card
/datum/outpost_upgrade/service/teleporter/proc/pad_row(obj/machinery/outpost_network_pad/pad)
	return list(
		"id" = pad.network_id,
		"name" = pad.site_name(),
	)

/datum/outpost_upgrade/service/teleporter/service_ui_data(mob/user)
	var/obj/machinery/outpost_network_pad/own_pad = pad_ref?.resolve()
	var/list/allow = list()
	var/list/candidates = list()
	for(var/obj/machinery/outpost_network_pad/pad as anything in GLOB.outpost_network_pads)
		if(pad == own_pad || !pad.network_host())
			continue
		if(pad.network_id in allowed_pads)
			allow += list(pad_row(pad))
		else
			candidates += list(pad_row(pad))
	return list(
		"kind" = "teleporter",
		"padName" = own_pad ? own_pad.site_name() : name,
		"arrivals" = arrival_policy,
		"allowlist" = allow,
		"candidates" = candidates,
		"can_edit" = !!outpost.is_current_management_user(user),
	)

/datum/outpost_upgrade/service/teleporter/service_ui_act(mob/user, action, list/params)
	switch(action)
		if("set_teleporter_arrivals", "teleporter_allow", "teleporter_disallow")
			if(!outpost.is_current_management_user(user))
				to_chat(user, span_warning("Not authorised."))
				return TRUE
		else
			return FALSE
	switch(action)
		if("set_teleporter_arrivals")
			var/policy = params["mode"]
			if(!istext(policy) || !(policy in list(OUTPOST_NETWORK_ARRIVALS_OPEN, OUTPOST_NETWORK_ARRIVALS_MEMBERS, OUTPOST_NETWORK_ARRIVALS_ALLOWLIST, OUTPOST_NETWORK_ARRIVALS_CLOSED)))
				return TRUE
			if(policy != arrival_policy)
				arrival_policy = policy
				log_game("PLAYER OUTPOST: [key_name(user)] set teleporter arrivals at '[outpost.name]' to [policy]")
		if("teleporter_allow")
			var/obj/machinery/outpost_network_pad/pad = network_pad_by_id(params["target"])
			if(pad && pad != pad_ref?.resolve() && pad.network_host() && !(pad.network_id in allowed_pads))
				allowed_pads += pad.network_id
				log_game("PLAYER OUTPOST: [key_name(user)] allowed teleporter arrivals from [pad.site_name()] at '[outpost.name]'")
		if("teleporter_disallow")
			var/id = params["target"]
			if(istext(id) && (id in allowed_pads))
				allowed_pads -= id
				log_game("PLAYER OUTPOST: [key_name(user)] removed [id] from the teleporter allow list at '[outpost.name]'")
	return TRUE

/datum/outpost_upgrade/service/teleporter/admin_ui_data()
	var/obj/machinery/outpost_network_pad/pad = pad_ref?.resolve()
	return list(
		list("label" = "Pad: [pad?.network_host() ? "online" : "offline"]", "action" = null, "ref" = null),
		list("label" = "Arrivals: [arrival_policy], [length(allowed_pads)] allowed", "action" = null, "ref" = null),
		list("label" = "Trips in [trips_in], out [trips_out]", "action" = null, "ref" = null),
	)

/// The registered pad with this network id, or null. UI params are decoded JSON: type-check first.
/proc/network_pad_by_id(id)
	if(!istext(id))
		return null
	for(var/obj/machinery/outpost_network_pad/pad as anything in GLOB.outpost_network_pads)
		if(pad.network_id == id)
			return pad
	return null
