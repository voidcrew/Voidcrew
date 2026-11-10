// ========== PATTERN BLEED (pattern_bleed) ==========

/**
 * Electronic warfare payload that holds every bluespace damper on the target ship down for
 * its duration. The hold is a deadline on the ship (teleport_field_hacked_until), so a lost
 * on_expire() still lets the dampers come back on their own.
 */
/datum/ew_payload/pattern_bleed
	id = "pattern_bleed"
	name = "Pattern Bleed"
	desc = "Drowns the target's bluespace dampers in their own noise, so beams pass through the hull."
	subsystem_name = "bluespace dampers"
	tier = 3
	warmup = 10 SECONDS
	duration = 40 SECONDS
	signature_cost = 35
	/// world.time our hold ends, so a later Pattern Bleed keeps its own longer hold
	var/imposed_end = 0

/datum/ew_payload/pattern_bleed/can_apply(obj/structure/overmap/ship/target, obj/structure/overmap/ship/attacker)
	if(!target)
		return "No target."
	if(!length(get_ship_teleport_blockers(target)))
		return "Target has no bluespace dampers to attack."
	return TRUE

/datum/ew_payload/pattern_bleed/on_apply(mode)
	var/obj/structure/overmap/ship/target = get_target()
	if(!target)
		return
	imposed_end = world.time + duration
	target.teleport_field_hacked_until = max(target.teleport_field_hacked_until, imposed_end)
	for(var/obj/machinery/teleport_blocker/blocker as anything in get_ship_teleport_blockers(target))
		blocker.update_appearance(UPDATE_ICON_STATE)
		if(blocker.is_running())
			do_sparks(3, FALSE, blocker)
	target.ship_notify("Damper control compromised - bluespace field down.", "DAMPERS", SHIP_NOTIFY_DANGER, 'voidcrew/sound/alert2.ogg', 30)

/datum/ew_payload/pattern_bleed/on_expire()
	var/obj/structure/overmap/ship/target = get_target()
	if(!target || QDELETED(target))
		return
	if(target.teleport_field_hacked_until > imposed_end)
		// A later Pattern Bleed holds them longer and owns the restore
		return
	target.teleport_field_hacked_until = 0
	for(var/obj/machinery/teleport_blocker/blocker as anything in get_ship_teleport_blockers(target))
		blocker.update_appearance(UPDATE_ICON_STATE)
	target.ship_notify("Damper control restored.", "DAMPERS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 25)

/obj/item/ew_exploit/pattern_bleed
	name = "exploit cartridge (Pattern Bleed)"
	desc = "Intrusion software that knocks a target ship's bluespace dampers offline."
	icon_state = "datadisk2"
	payload_type = /datum/ew_payload/pattern_bleed
	charges = 3
	max_charges = 3
