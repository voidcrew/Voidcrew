// Event Horizon rifle rebalance. It is a rare loot find rather than a research print:
// three shots that never recharge, a minute between shots, on-screen range only, and a
// reality tear that eats the room but not the people in it.

/datum/techweb_node/unregulated_bluespace
	design_ids = list(
		"desynchronizer",
	)

/obj/item/gun/energy/event_horizon
	selfcharge = FALSE
	can_charge = FALSE
	/// Time between shots.
	var/shot_cooldown_time = 1 MINUTES
	COOLDOWN_DECLARE(shot_cooldown)

/obj/item/gun/energy/event_horizon/get_cell(atom/movable/interface, mob/user)
	return null // Nothing may reach the cell to top it up.

/obj/item/gun/energy/event_horizon/process_fire(atom/target, mob/living/user, message, params, zone_override, bonus_spread)
	if(!COOLDOWN_FINISHED(src, shot_cooldown))
		balloon_alert(user, "ready in [round(COOLDOWN_TIMELEFT(src, shot_cooldown) / (1 SECONDS))]s!")
		return
	. = ..()
	if(.)
		COOLDOWN_START(src, shot_cooldown, shot_cooldown_time)

/obj/item/gun/energy/event_horizon/examine(mob/user)
	. = ..()
	if(!COOLDOWN_FINISHED(src, shot_cooldown))
		. += span_notice("It is still cycling. It can fire again in [DisplayTimeText(COOLDOWN_TIMELEFT(src, shot_cooldown))].")

/obj/item/ammo_casing/energy/event_horizon
	e_cost = LASER_SHOTS(3, STANDARD_CELL_CHARGE)

/obj/projectile/beam/event_horizon
	range = 9

/obj/reality_tear/temporary/start_disaster()
	. = ..()
	var/datum/component/singularity/singularity = GetComponent(/datum/component/singularity)
	singularity?.consume_callback = CALLBACK(src, PROC_REF(consume_without_gibbing))

/// Consumes everything the tear reaches except living mobs, which it only throws around.
/obj/reality_tear/temporary/proc/consume_without_gibbing(atom/thing, datum/component/singularity/source)
	if(isliving(thing))
		return
	thing.singularity_act(source.singularity_size, src)
