/// Backgrounds: owned by P4. See data/backgrounds/spec.md.

/**
 * The Black Ledger: a mission board on a smugglers' network. It lists the hull's own offers (the
 * criminal pool while the hull is a pirate hull) and the NPC pirate and player bounties, never the
 * wanted criminals. No design prints its board and nothing converts a plain one (MP-12); a board
 * pried out of a Corsair and rebuilt elsewhere is loot, and works.
 */
/obj/machinery/computer/mission_board/criminal
	name = "Black Ledger"
	desc = "A battered terminal on a smugglers' network. Nobody signs their name."
	circuit = /obj/item/circuitboard/computer/mission_board/criminal

/obj/machinery/computer/mission_board/criminal/ui_static_data(mob/user)
	var/list/data = ..()
	data["board_flavour"] = "criminal"
	return data

/obj/machinery/computer/mission_board/criminal/board_wanted_mugshots(obj/structure/overmap/ship/ship)
	return list()

/obj/machinery/computer/mission_board/criminal/board_static_signature(obj/structure/overmap/ship/ship)
	return ""

/obj/machinery/computer/mission_board/criminal/board_add_wanted_data(list/data, obj/structure/overmap/ship/ship, mob/user)
	data["wanted"] = list()
	return data

/obj/machinery/computer/mission_board/criminal/board_wanted_act(action, list/params, obj/structure/overmap/ship/ship, mob/user)
	return TRUE

/obj/item/circuitboard/computer/mission_board/criminal
	name = "Black Ledger"
	build_path = /obj/machinery/computer/mission_board/criminal

/**
 * Fills a pirate hull's board from the criminal pool: no green reserve offer, no green bias.
 * Ordinary offers left over from before the hull was flagged come off. Returns TRUE.
 */
/datum/controller/subsystem/missions/proc/refresh_criminal_missions(obj/structure/overmap/ship/ship)
	if(!ship)
		return FALSE
	for(var/datum/mission/mission as anything in ship.available_missions)
		if(QDELETED(mission))
			ship.available_missions -= mission
			continue
		if(istype(mission, /datum/mission/criminal) && world.time - mission.posted_at <= MISSION_BOARD_EXPIRY)
			continue
		ship.available_missions -= mission
		tally_mission_offer(mission, ship, "mission_offer_expired") // round metrics, voidcrew/modules/metrics/mission_metrics.dm
		qdel(mission)

	// Criminal offers have no overmap target; the hull's own band sets their pay
	var/posting_zone = SSovermap_zones?.get_zone_type(get_turf(ship))
	var/missions_needed = BACKGROUND_CRIMINAL_OFFERS - length(ship.available_missions)
	for(var/i in 1 to missions_needed)
		var/datum/mission/offer = create_mission(pick_criminal_mission_type(), posting_zone)
		if(offer)
			ship.available_missions += offer
			tally_mission_offer(offer, ship, "mission_offered") // round metrics, voidcrew/modules/metrics/mission_metrics.dm
	return TRUE

/// Shakedown twice as often as Hijack; Hijack only while a hauler is flying
/datum/controller/subsystem/missions/proc/pick_criminal_mission_type()
	var/list/weights = list(/datum/mission/criminal/shakedown = 2)
	if(length(hauler_live_haulers()))
		weights[/datum/mission/criminal/hijack] = 1
	return pick_weight(weights)
