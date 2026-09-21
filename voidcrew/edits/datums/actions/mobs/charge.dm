// Voidcrew extensions to code/datums/actions/mobs/charge.dm.

/datum/action/cooldown/mob_cooldown/charge/Destroy()
	stop_charges()
	restore_charge_actions()
	return ..()

/datum/action/cooldown/mob_cooldown/charge/Remove(mob/removed_from)
	stop_charges()
	restore_charge_actions()
	return ..()

/datum/action/cooldown/mob_cooldown/charge/proc/stop_charges()
	for(var/atom/movable/charger as anything in charging.Copy())
		finish_charge(charger, notify_owner = FALSE)

/datum/action/cooldown/mob_cooldown/charge/proc/restore_charge_actions()
	charge_activator = null
	for(var/datum/action/cooldown/ability as anything in charge_disabled_actions)
		if(!QDELETED(ability))
			ability.enable()
	charge_disabled_actions.Cut()
	// A cancelled wind-up must not leave the inherited melee lock on its new owner.
	next_melee_use_time = min(next_melee_use_time, world.time)
// VOIDCREW EDIT END

/datum/action/cooldown/mob_cooldown/charge/proc/finish_charge(atom/movable/charger, notify_owner = TRUE)
	if(!charger || !(charger in charging))
		return
	charging -= charger
	UnregisterSignal(charger, list(COMSIG_MOVABLE_BUMP, COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH))
	if(charger != owner)
		UnregisterSignal(charger, COMSIG_QDELETING)
	var/datum/move_loop/charge_loop = charge_loops[charger]
	charge_loops -= charger
	if(charge_loop)
		UnregisterSignal(charge_loop, list(COMSIG_MOVELOOP_PREPROCESS_CHECK, COMSIG_MOVELOOP_POSTPROCESS, COMSIG_QDELETING))
		if(!QDELETED(charge_loop))
			qdel(charge_loop)
	actively_moving = FALSE
	if(notify_owner && !QDELETED(owner))
		SEND_SIGNAL(owner, COMSIG_FINISHED_CHARGE)
// VOIDCREW EDIT END

/datum/action/cooldown/mob_cooldown/charge
	/// Charger -> its own move loop; never stop unrelated higher-priority movement.
	var/list/charge_loops = list()
	/// Distinguishes a cancelled warm-up from a replacement charge on the same mob.
	var/charge_serial = 0
	var/mob/charge_activator
	var/list/charge_disabled_actions = list()
