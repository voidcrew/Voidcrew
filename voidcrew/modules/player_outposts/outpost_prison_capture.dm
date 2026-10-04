/**
 * # Prison capture: cuffs and lockdown
 *
 * Cuffs. A member of the wing can put any handcuffs, cable restraints or zipties on a prisoner.
 * One who is down takes PRISONER_CUFF_TIME_DOWN; one on their feet takes PRISONER_CUFF_TIME_STANDING,
 * holding still meanwhile, and only while making no trouble: rioters, runners, fighters, anyone
 * threatening staff and anyone wrecking their cell must be put down first. Cuffed, they drop what
 * they hold and do nothing but stand or sit where they are and complain: no blows, threats,
 * fights, climbing, smashing, eating or activities, and a runner's loose clock waits. Anyone can
 * drag them, and a member can take them through the wing's staff doors (outpost_prisoner_escorted()).
 * Cuffs kept on past PRISONER_CUFFED_GRACE sour them and stop their pay like a lock-in, unless it
 * is for good reason: the wing is in protective custody, or they owe lockdown. A member takes the
 * cuffs off from the talk menu ("Uncuff"), or with an empty hand while they are down: real cuffs go
 * to the member's hand, cable and zipties are cut away.
 * The cuffs drop to the floor when the prisoner dies, beams out or is deleted.
 *
 * Lockdown. A rioter shut in a cell, and a runner caught after getting out during a riot, owes
 * PRISON_RIOT_LOCKDOWN_TIME of lockdown. It counts down only while they are shut in a cell, and
 * meanwhile being shut in or cuffed costs them nothing. Out of a cell, on their feet and uncuffed,
 * for more than PRISON_LOCKDOWN_GRACE before it is served, they were let out early: they riot
 * again, joining a riot that is on or starting one, whatever the quiet after the last. The grace
 * gives staff time to open the door and treat them.
 *
 * A riot is over once every rioter is shut in a cell, cuffed, down, dead or gone (riot_handled(),
 * outpost_prison_riot.dm). Only the ones shut in a cell owe lockdown.
 */

/// Trait source for the cuffs holding a prisoner still
#define PRISONER_CUFFS_TRAIT "outpost_prisoner_cuffs"

/mob/living/basic/outpost_prisoner
	/// The cuffs on them, held in their contents
	var/obj/item/restraints/handcuffs/cuffs
	/// Seconds cuffed without good reason; falls PRISONER_LOCKED_IN_RECOVERY seconds a second once uncuffed
	var/cuffed_seconds = 0
	/// Someone is putting cuffs on them or taking them off
	var/cuff_work = FALSE
	/// Seconds of lockdown they still owe, served only shut in a cell
	var/lockdown_left = 0
	/// Seconds out of a cell on their feet and uncuffed while they owe lockdown
	var/lockdown_out = 0
	/// The cell they last served lockdown in: out of it while it is still bolted, nobody let them out
	var/datum/weakref/lockdown_cell_ref
	/// They got out of the cell block during a riot; caught, they owe lockdown
	var/escaped_rioting = FALSE

// ===== CUFFING =====

/// Why `user` can't put `restraints` on them now, as a balloon alert, or null if they can
/mob/living/basic/outpost_prisoner/proc/cuff_refusal(mob/living/user, obj/item/restraints/handcuffs/restraints)
	if(!prison || !prison.is_member(user))
		return "members only"
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return "can't cuff [p_them()]"
	if(cuffs)
		return "already cuffed"
	if(istype(restraints, /obj/item/restraints/handcuffs/cable/zipties/used))
		return "used up"
	// On their feet only when they are making no trouble; rioters and runners go down first.
	if(!is_down() && (trouble || threat_ref || swing_ref || climb_ref))
		return "won't hold still"
	return null

/// How long cuffing them takes: quicker when they are down
/mob/living/basic/outpost_prisoner/proc/cuff_time()
	return (is_down() ? PRISONER_CUFF_TIME_DOWN : PRISONER_CUFF_TIME_STANDING) * bounty_cuff_mult()

/// Cuffs used on them (from the item interaction signal): refused with a balloon alert, or put on in the background
/mob/living/basic/outpost_prisoner/proc/on_cuffs_used(mob/living/user, obj/item/restraints/handcuffs/restraints)
	var/refusal = cuff_refusal(user, restraints)
	if(!refusal && cuff_work)
		refusal = "already busy"
	if(refusal)
		balloon_alert(user, refusal)
		return ITEM_INTERACT_BLOCKING
	INVOKE_ASYNC(src, PROC_REF(cuff_by), user, restraints)
	return ITEM_INTERACT_SUCCESS

/**
 * `user` puts `restraints` on them over cuff_time(), with tg's cuff sounds. They hold still
 * meanwhile (in_trouble() counts it, so their routine waits). Returns TRUE if they are cuffed. Sleeps.
 */
/mob/living/basic/outpost_prisoner/proc/cuff_by(mob/living/user, obj/item/restraints/handcuffs/restraints)
	if(cuff_work || cuff_refusal(user, restraints))
		return FALSE
	cuff_work = TRUE
	ai_controller?.CancelActions()
	user.visible_message(span_danger("[user] is trying to put [restraints] on [src]!"), span_danger("You try to put [restraints] on [src]."))
	playsound(src, restraints.cuffsound, 30, TRUE, -2)
	var/done = do_after(user, cuff_time(), target = src, timed_action_flags = IGNORE_SLOWDOWNS)
	cuff_work = FALSE
	if(QDELETED(src))
		return FALSE
	// A borg's cuffs are part of its module: it dispenses a pair, as tg's cuffs do for borgs.
	var/dispense = iscyborg(user)
	if(!done || QDELETED(restraints) || (restraints.loc != user && !dispense) || cuff_refusal(user, restraints))
		balloon_alert(user, "failed to cuff!")
		return FALSE
	var/success_sound = restraints.cuffsuccesssound
	if(!apply_cuffs(restraints, user, dispense))
		balloon_alert(user, "failed to cuff!")
		return FALSE
	playsound(src, success_sound, 30, TRUE, -2)
	user.visible_message(span_notice("[user] handcuffs [src]."), span_notice("You handcuff [src]."))
	log_combat(user, src, "handcuffed")
	return TRUE

/**
 * Puts `restraints` on them at once; zipties become their used pair, as on people. `user`, if
 * any, gives them up from their hands, unless `dispense` (a borg), which puts on a new pair of the
 * same kind instead. What they hold drops and whatever they were up to stops. Returns TRUE if they
 * are cuffed.
 */
/mob/living/basic/outpost_prisoner/proc/apply_cuffs(obj/item/restraints/handcuffs/restraints, mob/living/user, dispense = FALSE)
	if(cuffs || QDELETED(restraints) || stat == DEAD)
		return FALSE
	var/obj/item/restraints/handcuffs/worn = restraints
	if(dispense)
		var/dispensed_path = restraints.trashtype || restraints.type
		worn = new dispensed_path(src)
	else
		if(user && !user.temporarilyRemoveItemFromInventory(restraints))
			return FALSE
		if(restraints.trashtype)
			var/trash_path = restraints.trashtype
			worn = new trash_path(src)
			qdel(restraints)
		else
			restraints.forceMove(src)
	if(QDELETED(worn) || worn.loc != src)
		return FALSE
	cuffs = worn
	ADD_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_CUFFS_TRAIT)
	if(has_shiv())
		drop_shiv()
	else
		drop_held_item()
	end_activity()
	cancel_threat()
	stop_climb(fell = TRUE)
	// The breakout AI too: a caught runner stays put until walked home.
	ai_controller?.CancelActions()
	// Draggable now: whatever trouble they were in stops (on_downed()).
	update_drag_resistance()
	update_appearance(UPDATE_OVERLAYS)
	update_bubble()
	if(stat == CONSCIOUS)
		say_context("cuffed")
	return TRUE

// ===== UNCUFFING =====

/**
 * A member takes the cuffs off by hand, over PRISONER_UNCUFF_TIME. Returns TRUE if
 * they came off. Sleeps.
 */
/mob/living/basic/outpost_prisoner/proc/uncuff_by(mob/living/user)
	if(!cuffs || cuff_work)
		return FALSE
	cuff_work = TRUE
	user.visible_message(span_notice("[user] starts taking [cuffs] off [src]."), span_notice("You start taking [cuffs] off [src]."))
	var/done = do_after(user, PRISONER_UNCUFF_TIME, target = src)
	cuff_work = FALSE
	if(!done || QDELETED(src) || !cuffs || !prison?.is_member(user))
		return FALSE
	var/cut = istype(cuffs, /obj/item/restraints/handcuffs/cable)
	user.visible_message(span_notice("[user] [cut ? "cuts" : "takes"] [cuffs] off [src]."), span_notice("You [cut ? "cut" : "take"] [cuffs] off [src]."))
	remove_cuffs(user)
	if(stat == CONSCIOUS)
		say_context("cuffs_off")
	return TRUE

/**
 * Takes their cuffs off. With `user`, real cuffs go to their hands (or the floor) and cable
 * restraints and zipties are cut away; without, the cuffs drop where they are. Returns the cuffs
 * still about, or null.
 */
/mob/living/basic/outpost_prisoner/proc/remove_cuffs(mob/living/user)
	var/obj/item/restraints/handcuffs/worn = cuffs
	if(!worn)
		return null
	// Cleared first, so Exited() leaves the rest to this proc.
	cuffs = null
	if(user && istype(worn, /obj/item/restraints/handcuffs/cable))
		qdel(worn)
		worn = null
	else
		worn.forceMove(drop_location())
		if(user)
			user.put_in_hands(worn)
	uncuffed()
	return worn

/// The cuffs are off, however they came off
/mob/living/basic/outpost_prisoner/proc/uncuffed()
	REMOVE_TRAIT(src, TRAIT_IMMOBILIZED, PRISONER_CUFFS_TRAIT)
	if(QDELETED(src))
		return
	update_drag_resistance()
	update_appearance(UPDATE_OVERLAYS)
	prison?.refresh_prisoner_reach(src)

// ===== CUFFED =====

// Cuffed hands throw no punches, whatever their AI wants.
/mob/living/basic/outpost_prisoner/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(cuffs)
		return FALSE
	return ..()

/// Whether their cuffs are souring them and stopping their pay: on past PRISONER_CUFFED_GRACE, and not for good reason
/mob/living/basic/outpost_prisoner/proc/cuffs_souring()
	return cuffed_seconds > PRISONER_CUFFED_GRACE && !prison?.restraint_justified(src)

/// Whether restraining a prisoner is for good reason right now, so it costs them nothing: protective custody, or lockdown they owe
/datum/outpost_prison/proc/restraint_justified(mob/living/basic/outpost_prisoner/prisoner)
	return prisoner.lockdown_left > 0 || protective_custody()

/**
 * Advances a prisoner's cuffed clock by `seconds`: up while cuffed without good reason, and down
 * PRISONER_LOCKED_IN_RECOVERY seconds a second once the cuffs are off, like the lock-in clock.
 */
/datum/outpost_prison/proc/update_cuffed(mob/living/basic/outpost_prisoner/prisoner, seconds)
	if(prisoner.cuffs)
		if(!restraint_justified(prisoner))
			prisoner.cuffed_seconds += seconds
		return
	prisoner.cuffed_seconds = max(0, prisoner.cuffed_seconds - PRISONER_LOCKED_IN_RECOVERY * seconds)

/// Cuffed, they plan nothing: no routine, no trouble, no patrol, no doors. First on both prisoner controllers.
/datum/ai_planning_subtree/outpost_prisoner_cuffed

/datum/ai_planning_subtree/outpost_prisoner_cuffed/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/outpost_prisoner/prisoner = controller.pawn
	if(istype(prisoner) && prisoner.cuffs)
		return SUBTREE_RETURN_FINISH_PLANNING

// ===== LOCKDOWN =====

/// They owe PRISON_RIOT_LOCKDOWN_TIME of lockdown from now. `quiet` leaves the line to the caller.
/datum/outpost_prison/proc/start_lockdown(mob/living/basic/outpost_prisoner/prisoner, quiet = FALSE)
	prisoner.lockdown_left = PRISON_RIOT_LOCKDOWN_TIME
	prisoner.lockdown_out = 0
	add_log("[prisoner.real_name] is on lockdown.")
	if(!quiet && prisoner.stat == CONSCIOUS)
		prisoner.say_context("lockdown")

/**
 * Advances a prisoner's lockdown by `seconds`. Shut in a cell it counts down, whatever the crew
 * does. Out of one on their feet and uncuffed for more than PRISON_LOCKDOWN_GRACE, they were let
 * out early. Down, cuffed or loose, the grace waits, and so does it while the cell they were serving
 * in is still bolted: they got out through a hole, and nobody let them out.
 */
/datum/outpost_prison/proc/lockdown_tick(mob/living/basic/outpost_prisoner/prisoner, seconds)
	if(prisoner.lockdown_left <= 0)
		prisoner.lockdown_out = 0
		prisoner.lockdown_cell_ref = null
		return
	if(prisoner.is_confined())
		prisoner.lockdown_out = 0
		var/datum/outpost_prison_cell/serving = cell_at(get_turf(prisoner))
		prisoner.lockdown_cell_ref = serving ? WEAKREF(serving) : null
		prisoner.lockdown_left = max(0, prisoner.lockdown_left - seconds)
		if(prisoner.lockdown_left <= 0)
			lockdown_served(prisoner)
		return
	if(!trouble_enabled || prisoner.stat != CONSCIOUS || prisoner.can_be_dragged() || prisoner.trouble == PRISONER_TROUBLE_LOOSE)
		return
	var/datum/outpost_prison_cell/served_in = prisoner.lockdown_cell_ref?.resolve()
	if(served_in?.is_bolted())
		return
	prisoner.lockdown_out += seconds
	if(prisoner.lockdown_out > PRISON_LOCKDOWN_GRACE)
		let_out_early(prisoner)

/// Served: the warden's log notes it once, and the prisoner says so. The usual lock-in rules apply again.
/datum/outpost_prison/proc/lockdown_served(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.lockdown_left = 0
	prisoner.lockdown_out = 0
	prisoner.lockdown_cell_ref = null
	add_log("[prisoner.real_name]'s lockdown is over.")
	if(prisoner.stat == CONSCIOUS)
		prisoner.say_context("lockdown_over")

/**
 * Let out before the lockdown was served: logged once, and they riot again, joining a riot
 * that is on or starting one whatever the quiet after the last. Returns TRUE if they are rioting.
 */
/datum/outpost_prison/proc/let_out_early(mob/living/basic/outpost_prisoner/prisoner)
	prisoner.lockdown_left = 0
	prisoner.lockdown_out = 0
	add_log("[prisoner.real_name] was let out before their lockdown was up.")
	if(prisoner.is_rioting())
		return TRUE
	if(riot_active)
		if(!prisoner.can_join_riot())
			return FALSE
		prisoner.start_rioting()
		return TRUE
	return start_riot("[prisoner.real_name] was let out of lockdown early", forced = prisoner, ignore_quiet = TRUE)

/// "about 3 more minutes", "about a minute more" or "less than a minute more", for lockdown left
/proc/outpost_prison_lockdown_text(seconds)
	if(seconds >= 90)
		return "about [round(seconds / 60, 1)] more minutes"
	if(seconds >= 45)
		return "about a minute more"
	return "less than a minute more"

// ===== WHERE STAFF LOOK =====

/mob/living/basic/outpost_prisoner/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	if(cuffs)
		. += span_warning("[p_They()] [p_are()] handcuffed.")
	if(lockdown_left > 0)
		. += span_notice("On lockdown for [outpost_prison_lockdown_text(lockdown_left)].")

/obj/machinery/button/outpost_prison_bolt/examine(mob/user)
	. = ..()
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	var/datum/outpost_prison_cell/cell = prison?.cell_by_number(cell_number)
	if(!cell)
		return
	for(var/mob/living/basic/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.lockdown_left <= 0 || prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
			continue
		var/inside = cell.contains(prisoner)
		if(!inside && cell.occupant != prisoner)
			continue
		var/line = "[prisoner.real_name] is on lockdown for [outpost_prison_lockdown_text(prisoner.lockdown_left)]."
		if(!inside)
			line += " [prisoner.p_They()] [prisoner.p_are()] not in the cell."
		. += span_notice(line)

#undef PRISONER_CUFFS_TRAIT
