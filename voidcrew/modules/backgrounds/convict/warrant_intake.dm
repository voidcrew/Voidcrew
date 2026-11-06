/**
 * # Capture intake
 *
 * A warrant target handed in (at a hunter's pad, or the Meridian's own intake pad) is beamed to
 * the Meridian: stripped like the gulag teleporter strips a prisoner, gear into their evidence
 * locker, dressed in orange and put on a capture-cell bed, with the door sealed behind them. A
 * capture cell holds: no tools, no hackable door. Respawn is the way out. The dead go to the
 * morgue. Never through do_teleport(), so a teleport block cannot leave a captive on the pad.
 *
 * Every minute a capture-cell body nobody is playing any more, whose player started another life
 * BACKGROUND_CAPTURE_BODY_GRACE ago, and any body that died in a cell, goes to the morgue and
 * frees its bed.
 */

/// What a plasmaman keeps on through intake: their suit and air
GLOBAL_LIST_INIT(penitentiary_plasmaman_keeps, typecacheof(list(
	/obj/item/clothing/suit/space/eva/plasmaman,
	/obj/item/clothing/under/plasmaman,
	/obj/item/clothing/head/helmet/space/plasmaman,
	/obj/item/clothing/gloves/color/plasmaman,
	/obj/item/tank/internals,
	/obj/item/clothing/mask/breath,
	/obj/item/clothing/mask/gas,
)))

/// Delivers a captive to the Penitentiary. TRUE on success.
/proc/penitentiary_take_prisoner(mob/living/carbon/human/captive, obj/structure/overmap/ship/captor)
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	if(!istype(captive) || QDELETED(captive) || !site?.loaded)
		return FALSE
	var/turf/from = get_turf(captive)
	if(captive.stat == DEAD)
		if(!site.morgue_turf && !length(site.morgue_trays))
			return FALSE
	else if(!length(site.capture_cells))
		return FALSE
	if(from)
		new /obj/effect/temp_visual/transporter_flash/departure(from)
	captive.buckled?.unbuckle_mob(captive, force = TRUE)
	captive.pulledby?.stop_pulling()
	captive.stop_pulling()
	var/obj/structure/closet/secure_closet/penitentiary_evidence/locker = site.evidence_locker_for(captive.mind, assign = TRUE)
	penitentiary_strip(captive, locker)
	if(captive.stat == DEAD)
		site.send_to_morgue(captive)
		log_game("BACKGROUNDS: [key_name(captive)] was delivered dead to the Meridian[captor ? " by the [captor.name]" : ""]")
		return TRUE
	if(!isplasmaman(captive))
		var/suit_type = captive.jumpsuit_style == PREF_SKIRT ? /obj/item/clothing/under/rank/prisoner/skirt : /obj/item/clothing/under/rank/prisoner
		captive.equip_to_appropriate_slot(new suit_type(captive), qdel_on_fail = TRUE)
	captive.equip_to_appropriate_slot(new /obj/item/clothing/shoes/sneakers/orange(captive), qdel_on_fail = TRUE)
	var/datum/penitentiary_cell/cell = site.capture_cell_for_next()
	var/turf/spot = cell.next_spot()
	captive.forceMove(spot)
	cell.occupants += WEAKREF(captive)
	var/obj/machinery/door/airlock/door = cell.door()
	if(door?.density && !door.locked)
		door.set_bolt(TRUE)
		door.update_appearance()
	transporter_materialise(captive)
	to_chat(captive, span_warning("The cell door seals behind you."))
	log_game("BACKGROUNDS: [key_name(captive)] was delivered to Meridian capture cell [cell.number][captor ? " by the [captor.name]" : ""]")
	return TRUE

/**
 * Takes everything off the captive into `store` (their evidence locker), as the gulag teleporter
 * does: implants stay in, and a plasmaman keeps their suit and air. With no locker free the gear is
 * gone: it is never left where the captive could reach it.
 */
/proc/penitentiary_strip(mob/living/carbon/human/captive, atom/store)
	var/plasma = isplasmaman(captive)
	for(var/obj/item/thing in captive)
		if(istype(thing, /obj/item/implant))
			continue
		if(plasma && is_type_in_typecache(thing, GLOB.penitentiary_plasmaman_keeps))
			continue
		if(!captive.temporarilyRemoveItemFromInventory(thing))
			continue
		if(store)
			thing.forceMove(store)
		else
			qdel(thing)

/// Puts a body in an empty morgue tray, or on the morgue's floor mark when every tray is taken
/obj/structure/overmap/penitentiary/proc/send_to_morgue(mob/living/body)
	if(QDELETED(body))
		return FALSE
	var/obj/structure/bodycontainer/morgue/tray = free_morgue_tray()
	if(tray)
		body.forceMove(tray)
		tray.update_appearance()
		return TRUE
	var/turf/drop = morgue_turf || (length(morgue_trays) ? get_turf(morgue_trays[1]) : null) || arrival_turf
	if(!drop)
		return FALSE
	body.forceMove(drop)
	return TRUE

/// Whether `body` has a player behind it who has moved on to another life at least BACKGROUND_CAPTURE_BODY_GRACE ago
/proc/penitentiary_body_abandoned(mob/living/body)
	if(body.client)
		return FALSE
	var/datum/mind/mind = body.mind
	var/body_ckey = ckey(mind?.key || body.key)
	if(!body_ckey)
		return TRUE
	var/datum/background_state/latest
	for(var/datum/mind/other in GLOB.background_minds)
		var/datum/background_state/state = other.background_state
		if(state?.ckey != body_ckey)
			continue
		if(!latest || state.started_at > latest.started_at)
			latest = state
	if(!latest || latest.mind_ref?.resolve() == mind)
		return FALSE
	return world.time - latest.started_at >= BACKGROUND_CAPTURE_BODY_GRACE

/// The minute's sweep of Secure Holding: the dead and the abandoned go to the morgue and free their beds
/obj/structure/overmap/penitentiary/proc/capture_sweep()
	for(var/number in capture_cells)
		var/datum/penitentiary_cell/cell = capture_cells[number]
		for(var/mob/living/body as anything in cell.bodies_inside())
			if(body.stat != DEAD && !penitentiary_body_abandoned(body))
				continue
			send_to_morgue(body)
			for(var/datum/weakref/ref as anything in cell.occupants.Copy())
				if(ref?.resolve() == body)
					cell.occupants -= ref
			log_game("BACKGROUNDS: [key_name(body)]'s body was moved from Meridian capture cell [cell.number] to the morgue")

/// Whether `person` stands in a cell of their own: their escape cell, or any capture cell
/obj/structure/overmap/penitentiary/proc/in_own_cell(mob/living/person)
	if(!person)
		return FALSE
	for(var/number in escape_cells)
		var/datum/penitentiary_cell/cell = escape_cells[number]
		if(cell.owner() == person.mind && cell.contains(person))
			return TRUE
	return !!capture_cell_holding(person)
