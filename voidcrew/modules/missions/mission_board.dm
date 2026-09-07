/**
 * # Mission Board Console
 *
 * Computer console for viewing and managing ship missions.
 * - View available and active missions
 * - Accept new missions
 * - Turn in completed missions
 */
/obj/machinery/computer/mission_board
	name = "mission board"
	desc = "A console for managing ship contracts and missions."
	icon = 'voidcrew/modules/shuttle/icons/computer.dmi'
	icon_screen = "mission"
	icon_keyboard = "rd_key"
	circuit = /obj/item/circuitboard/computer/mission_board
	light_color = COLOR_BRIGHT_ORANGE

	/// Linked mission pad for item turn-in
	var/obj/machinery/mission_pad/linked_pad

/obj/machinery/computer/mission_board/Initialize(mapload)
	. = ..()
	// Try to find a linked pad nearby
	find_linked_pad()

/obj/machinery/computer/mission_board/Destroy()
	if(linked_pad)
		linked_pad.linked_console = null
		linked_pad = null
	return ..()

/**
 * Searches for a mission pad within range and links to it.
 */
/obj/machinery/computer/mission_board/proc/find_linked_pad()
	for(var/obj/machinery/mission_pad/pad in range(3, src))
		if(!pad.linked_console)
			link_to_pad(pad)
			return

/**
 * Links this console to a mission pad.
 * * pad - The pad to link to
 */
/obj/machinery/computer/mission_board/proc/link_to_pad(obj/machinery/mission_pad/pad)
	if(!pad)
		return
	if(linked_pad)
		linked_pad.linked_console = null
	linked_pad = pad
	pad.linked_console = src

/**
 * Gets the ship this console is on.
 */
/obj/machinery/computer/mission_board/proc/get_ship()
	return get_ship_from_atom(src)

/**
 * Tapping a handheld GPS on the console uploads the active missions' objective
 * beacons to that specific unit.
 *
 * A contract can be linked and still have nothing to point at: the beacon tracks
 * the objective's physical mark, and field objectives don't place theirs until
 * the site's interior loads. Reporting the link as an upload in that state reads
 * as a broken GPS, so the three cases are called apart - signals on the unit, a
 * link with no mark out there yet, and nothing linked at all.
 */
/obj/machinery/computer/mission_board/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	var/datum/component/gps/item/gps_unit = tool.GetComponent(/datum/component/gps/item)
	if(!gps_unit)
		return ..()
	return upload_mission_beacons(user, gps_unit)

/// Resolve only a GPS actually installed in this user's currently worn MODsuit.
/obj/machinery/computer/mission_board/proc/get_worn_mod_gps(mob/user)
	var/obj/item/mod/control/suit = user?.get_item_by_slot(ITEM_SLOT_BACK)
	if(!istype(suit) || QDELETED(suit) || suit.wearer != user)
		return null
	for(var/obj/item/mod/module/gps/module in suit.modules)
		if(!QDELETED(module) && module.mod == suit && module.loc == suit)
			return module.GetComponent(/datum/component/gps/item)
	return null

/// The UI resolves the worn module on every click, so dropped or removed suits cannot be targeted.
/obj/machinery/computer/mission_board/proc/link_worn_mod_gps(mob/user)
	if(!is_operational || !user.can_perform_action(src, FORBID_TELEKINESIS_REACH))
		return FALSE
	var/datum/component/gps/item/gps_unit = get_worn_mod_gps(user)
	if(!gps_unit)
		balloon_alert(user, "no worn MOD GPS!")
		return FALSE
	return upload_mission_beacons(user, gps_unit) == ITEM_INTERACT_SUCCESS

/// Both handheld units and worn MOD modules use the same mission registration and feedback.
/obj/machinery/computer/mission_board/proc/upload_mission_beacons(mob/user, datum/component/gps/item/gps_unit)
	var/obj/structure/overmap/ship/ship = get_ship()
	if(!ship)
		balloon_alert(user, "console not on a ship!")
		return ITEM_INTERACT_BLOCKING

	var/linked = 0
	for(var/datum/mission/mission as anything in ship.active_missions)
		if(QDELETED(mission))
			continue
		if(mission.link_gps_unit(gps_unit))
			linked++

	var/live_beacons = LAZYLEN(gps_unit.linked_mission_signals)
	if(live_beacons)
		balloon_alert(user, "[live_beacons] beacon[live_beacons > 1 ? "s" : ""] linked")
		playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
	else if(linked)
		balloon_alert(user, "linked - no objective marked yet")
	else
		balloon_alert(user, "no beacons to upload!")
	return ITEM_INTERACT_SUCCESS

/obj/machinery/computer/mission_board/ui_interact(mob/user, datum/tgui/ui)
	. = ..()
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "MissionBoard", name)
		ui.open()

/obj/machinery/computer/mission_board/ui_data(mob/user)
	var/list/data = list()

	var/obj/structure/overmap/ship/ship = get_ship()
	data["has_ship"] = !!ship
	if(!ship)
		return data

	data["max_missions"] = ship.max_missions
	data["active_count"] = length(ship.active_missions)
	data["has_pad"] = !!linked_pad
	data["has_mod_gps"] = !!get_worn_mod_gps(user)
	data["refresh_cooldown_remaining"] = max(0, round((MISSION_REFRESH_COOLDOWN - (world.time - ship.last_mission_refresh)) / 10))

	// Available missions
	data["available_missions"] = list()
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(QDELETED(mission))
			continue
		data["available_missions"] += list(mission.get_ui_data())

	// Active missions
	data["active_missions"] = list()
	for(var/datum/mission/mission as anything in ship.active_missions)
		if(QDELETED(mission))
			continue
		data["active_missions"] += list(mission.get_ui_data())

	// Pad contents (for item turn-in display)
	data["pad_contents"] = list()
	if(linked_pad)
		for(var/obj/item/item in linked_pad.get_items_on_pad())
			data["pad_contents"] += list(list(
				"name" = item.name,
				"ref" = REF(item),
			))

	// Bounties - global competitive pirate bounties
	data["bounties"] = SSbounty?.get_bounty_ui_data(ship) || list()
	data["has_active_bounty"] = SSbounty?.ship_has_active_bounty(ship) || FALSE

	// Player bounties
	data["player_bounties"] = SSbounty?.get_player_bounty_ui_data(ship) || list()
	data["has_created_bounty"] = SSbounty?.ship_has_active_player_bounty(ship) || FALSE
	data["has_claimed_player_bounty"] = SSbounty?.ship_has_claimed_player_bounty(ship) || FALSE
	data["ship_balance"] = ship.ship_account?.account_balance || 0

	// Live player-outpost advertisements (see voidcrew/modules/player_outposts/outpost_adverts.dm)
	data["outpost_adverts"] = list()
	for(var/datum/outpost_advert/advert as anything in GLOB.outpost_adverts)
		data["outpost_adverts"] += list(list(
			"name" = advert.outpost_name,
			"blurb" = advert.blurb,
			"x" = advert.coord_x,
			"y" = advert.coord_y,
			"remaining_minutes" = CEILING(advert.get_remaining_seconds() / 60, 1),
		))

	return data

/obj/machinery/computer/mission_board/ui_act(action, params, datum/tgui/ui)
	. = ..()
	if(.)
		return

	var/obj/structure/overmap/ship/ship = get_ship()
	if(!ship)
		balloon_alert(usr, "console not on a ship!")
		return TRUE

	switch(action)
		if("link_mod_gps")
			link_worn_mod_gps(ui.user)
			return TRUE

		if("accept")
			var/datum/mission/mission = locate(params["ref"]) in ship.available_missions
			if(!mission)
				balloon_alert(usr, "mission not found!")
				return TRUE

			var/result = ship.accept_mission(mission)
			if(result != TRUE)
				balloon_alert(usr, result)
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
			else
				balloon_alert(usr, "mission accepted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			return TRUE

		if("turn_in")
			var/datum/mission/mission = locate(params["ref"]) in ship.active_missions
			if(!mission)
				balloon_alert(usr, "mission not found!")
				return TRUE

			// Search the live pad contents using this contract's objective. The
			// first item on the pad may be unrelated or fall short of the ask.
			var/obj/item/turn_in_item = null
			if(linked_pad && mission.requires_item)
				turn_in_item = mission.pick_turn_in_item(linked_pad.get_items_on_pad())

			var/result = ship.complete_mission(mission, linked_pad, turn_in_item)
			if(result != TRUE)
				balloon_alert(usr, result)
				playsound(src, 'sound/machines/buzz/buzz-sigh.ogg', 50, TRUE)
			else
				// Counted hand-overs accept the item but keep the mission open
				balloon_alert(usr, QDELETED(mission) ? "mission completed!" : "turn-in accepted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			return TRUE

		if("refresh")
			var/cooldown_remaining = MISSION_REFRESH_COOLDOWN - (world.time - ship.last_mission_refresh)
			if(cooldown_remaining > 0)
				balloon_alert(usr, "wait [round(cooldown_remaining / 10)]s")
				return TRUE
			ship.last_mission_refresh = world.time
			SSmissions.force_refresh_ship_missions(ship)
			balloon_alert(usr, "missions refreshed!")
			return TRUE

		// ========== BOUNTY ACTIONS ==========

		if("accept_bounty")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			// Check specific failure reasons for better feedback
			if(bounty.has_abandoned(ship))
				balloon_alert(usr, "you abandoned this bounty!")
				return TRUE

			if(SSbounty?.ship_has_active_bounty(ship))
				balloon_alert(usr, "already hunting a bounty!")
				return TRUE

			if(bounty.add_claimant(ship))
				balloon_alert(usr, "bounty accepted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
				ship.ship_notify("BOUNTY ACCEPTED: [bounty.name] - [bounty.reward] credit reward", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			else
				balloon_alert(usr, "cannot accept bounty!")
			return TRUE

		if("cancel_bounty")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty)
				balloon_alert(usr, "bounty not found!")
				return TRUE

			if(bounty.remove_claimant(ship))
				balloon_alert(usr, "bounty cancelled")
				ship.ship_notify("BOUNTY CANCELLED: [bounty.name]", "MISSION CONTROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
			else
				balloon_alert(usr, "not hunting this bounty!")
			return TRUE

		if("enable_tracking")
			var/datum/pirate_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			if(!bounty.is_claimant(ship))
				balloon_alert(usr, "not hunting this bounty!")
				return TRUE

			if(bounty.has_tracking(ship))
				// Already paid - just re-chart the helm waypoint (free), in case it was cleared
				if(bounty.push_tracking_waypoint(ship))
					balloon_alert(usr, "waypoint re-charted!")
				else
					balloon_alert(usr, "already tracking!")
				return TRUE

			if(bounty.enable_tracking(ship))
				var/tracking_cost = bounty.get_tracking_cost()
				balloon_alert(usr, "tracking enabled! -[tracking_cost] cr")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
				ship.ship_notify("TRACKING ENABLED: [bounty.name] - Reward reduced by [tracking_cost] credits", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			else
				balloon_alert(usr, "cannot enable tracking!")
			return TRUE

		if("turn_in_bounty")
			// Find ship key on pad
			if(!linked_pad)
				balloon_alert(usr, "no mission pad linked!")
				return TRUE

			var/obj/item/ship_key/key = locate() in linked_pad.get_items_on_pad()
			if(!key)
				balloon_alert(usr, "place captain's key on pad!")
				return TRUE

			// Find what bounty this ship is hunting (ships can only have one)
			var/list/hunting = SSbounty?.get_bounties_for_claimant(ship)
			if(!length(hunting))
				balloon_alert(usr, "you have no active bounty!")
				return TRUE

			var/datum/pirate_bounty/bounty = hunting[1]

			// Verify the key matches the bounty we're hunting
			if(key != bounty.get_target_key())
				balloon_alert(usr, "wrong key! need [bounty.name]'s key")
				return TRUE

			if(!bounty.is_valid())
				balloon_alert(usr, "bounty no longer valid!")
				return TRUE

			// Move key off the pad before spawning loot (but don't delete yet - bounty needs valid key ref)
			key.forceMove(null)

			// Complete the bounty while key still exists (is_valid() requires non-QDELETED key)
			var/reward = bounty.complete(ship, linked_pad)

			// Now safe to destroy the key
			key.mark_destruction_reason(KEY_DESTROYED_BOUNTY)
			qdel(key)
			if(reward > 0)
				balloon_alert(usr, "[reward] credits awarded!")
				playsound(src, 'sound/effects/cashregister.ogg', 50, TRUE)
			else
				balloon_alert(usr, "bounty completion failed!")
			return TRUE

		// ========== PLAYER BOUNTY ACTIONS ==========

		if("create_bounty")
			if(SSbounty?.ship_has_active_player_bounty(ship))
				balloon_alert(usr, "already have active bounty!")
				return TRUE

			var/reward_amount = text2num(params["reward"])
			if(!reward_amount || reward_amount < 100)
				balloon_alert(usr, "minimum reward is 100 cr!")
				return TRUE

			// Escrowing the balance into a bounty and cancelling it later parks money out
			// of a pirate's reach, so a frozen account can't post one.
			if(ship.ship_account?.is_siphon_locked())
				balloon_alert(usr, "accounts locked - intrusion!")
				return TRUE

			if(ship.ship_account?.account_balance < reward_amount)
				balloon_alert(usr, "insufficient funds!")
				return TRUE

			var/bounty_name = params["name"]
			var/bounty_desc = params["desc"]

			if(!bounty_name || length(bounty_name) < 3)
				balloon_alert(usr, "name too short!")
				return TRUE

			if(!bounty_desc || length(bounty_desc) < 5)
				balloon_alert(usr, "description too short!")
				return TRUE

			// Sanitize inputs
			bounty_name = copytext(sanitize(bounty_name), 1, 64)
			bounty_desc = copytext(sanitize(bounty_desc), 1, 256)

			// Create the bounty
			var/datum/player_bounty/new_bounty = SSbounty?.create_player_bounty(ship, linked_pad, reward_amount)
			if(!new_bounty)
				balloon_alert(usr, "failed to create bounty!")
				return TRUE

			if(!new_bounty.setup(bounty_name, bounty_desc))
				new_bounty.cancel()
				balloon_alert(usr, "failed to setup bounty!")
				return TRUE

			balloon_alert(usr, "bounty created!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			ship.ship_notify("BOUNTY POSTED: [new_bounty.name] - [reward_amount] credit reward", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			return TRUE

		if("claim_player_bounty")
			var/datum/player_bounty/bounty = locate(params["ref"])
			if(!bounty || !bounty.is_valid())
				balloon_alert(usr, "bounty not available!")
				return TRUE

			var/result = bounty.claim(ship)
			if(result != TRUE)
				balloon_alert(usr, result)
				return TRUE

			balloon_alert(usr, "bounty accepted!")
			playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			ship.ship_notify("PLAYER BOUNTY ACCEPTED: [bounty.name] - [bounty.reward] credit reward", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
			return TRUE

		if("abandon_player_bounty")
			var/datum/player_bounty/bounty = locate(params["ref"])
			if(!bounty)
				balloon_alert(usr, "bounty not found!")
				return TRUE

			if(bounty.abandon(ship))
				balloon_alert(usr, "bounty abandoned")
				ship.ship_notify("PLAYER BOUNTY ABANDONED: [bounty.name]", "MISSION CONTROL", SHIP_NOTIFY_WARNING, 'voidcrew/sound/notify2.ogg', 50)
			else
				balloon_alert(usr, "not your bounty!")
			return TRUE

		if("cancel_player_bounty")
			var/datum/player_bounty/bounty = SSbounty?.get_ship_created_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no bounty to cancel!")
				return TRUE

			bounty.cancel()
			balloon_alert(usr, "bounty cancelled, funds refunded")
			return TRUE

		if("make_bounty_offer")
			// Contractor submits an offer
			if(!linked_pad)
				balloon_alert(usr, "no mission pad linked!")
				return TRUE

			var/datum/player_bounty/bounty = SSbounty?.get_ship_claimed_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no claimed bounty!")
				return TRUE

			if(bounty.has_pending_offer(ship))
				balloon_alert(usr, "you already have a pending offer!")
				return TRUE

			// Get items on pad
			var/list/items_on_pad = linked_pad.get_items_on_pad()
			if(!length(items_on_pad))
				balloon_alert(usr, "place items on pad first!")
				return TRUE

			// Create the offer
			if(bounty.make_offer(items_on_pad, linked_pad, ship))
				balloon_alert(usr, "offer submitted!")
				playsound(src, 'sound/machines/ding.ogg', 50, TRUE)
			else
				balloon_alert(usr, "failed to submit offer!")
			return TRUE

		if("withdraw_bounty_offer")
			// Contractor withdraws their pending offer
			var/datum/player_bounty/bounty = SSbounty?.get_ship_claimed_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no claimed bounty!")
				return TRUE

			if(bounty.withdraw_offer(ship))
				balloon_alert(usr, "offer withdrawn")
			else
				balloon_alert(usr, "no offer to withdraw!")
			return TRUE

		if("approve_bounty_offer")
			// Creator approves an offer
			var/datum/player_bounty/bounty = SSbounty?.get_ship_created_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no bounty found!")
				return TRUE

			// Find the ship whose offer to approve
			var/obj/structure/overmap/ship/offer_ship = locate(params["ship_ref"])
			if(!offer_ship)
				balloon_alert(usr, "invalid ship!")
				return TRUE

			var/result = bounty.approve_offer(offer_ship)
			if(result == TRUE)
				balloon_alert(usr, "offer approved!")
				playsound(src, 'sound/effects/cashregister.ogg', 50, TRUE)
			else
				balloon_alert(usr, "[result]")
			return TRUE

		if("reject_bounty_offer")
			// Creator rejects an offer
			var/datum/player_bounty/bounty = SSbounty?.get_ship_created_bounty(ship)
			if(!bounty)
				balloon_alert(usr, "no bounty found!")
				return TRUE

			// Find the ship whose offer to reject
			var/obj/structure/overmap/ship/offer_ship = locate(params["ship_ref"])
			if(!offer_ship)
				balloon_alert(usr, "invalid ship!")
				return TRUE

			if(bounty.reject_offer(offer_ship))
				balloon_alert(usr, "offer rejected")
			else
				balloon_alert(usr, "no offer to reject!")
			return TRUE

/**
 * Circuit board for the mission board console.
 */
/obj/item/circuitboard/computer/mission_board
	name = "Mission Board"
	greyscale_colors = CIRCUIT_COLOR_SUPPLY
	build_path = /obj/machinery/computer/mission_board
