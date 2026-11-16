/**
 * # Prison capture: cuffs and lockdown
 *
 * Cuffs are tg's own handcuffs, cable restraints and zipties, put on through tg's cuffing (4 seconds,
 * its sounds and messages). Only a member of the wing may cuff a prisoner (COMSIG_CARBON_CUFF_ATTEMPTED).
 * Anyone making trouble on their feet (a rioter, a runner, a fighter, anyone squaring up to staff or
 * climbing out) won't hold still: they step out of the cuffer's reach, which breaks the cuffing, so
 * they get put down first. Cuffed, they can walk, as anyone can, but they choose to stand or sit where
 * they are and complain: no blows, threats, fights, climbing, smashing, eating or activities, and a
 * runner's loose clock waits. Anyone can drag them, and a member can take them through the wing's staff
 * doors (outpost_prisoner_escorted()). Cuffs kept on past PRISONER_CUFFED_GRACE sour them and stop
 * their pay like a lock-in, unless it is for good reason: the wing is in protective custody, or they owe
 * lockdown. A member takes the cuffs off from the talk menu ("Uncuff"), or through the strip menu like
 * anyone's: real cuffs go to the member's hand, cable and zipties are cut away. A body keeps its cuffs.
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

/mob/living/carbon/human/npc/outpost_prisoner
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

/// Why `user` can't put cuffs on them now, as a balloon alert, or null if they can
/mob/living/carbon/human/npc/outpost_prisoner/proc/cuff_refusal(mob/living/user)
	if(!prison || !prison.is_member(user))
		return "members only"
	if(stat == DEAD || phase != PRISONER_PRESENT)
		return "can't cuff [p_them()]"
	return null

/// Making trouble on their feet: they won't stand still for the cuffs
/mob/living/carbon/human/npc/outpost_prisoner/proc/fights_the_cuffs()
	return !is_down() && (trouble || threat_ref || swing_ref || climb_ref)

/**
 * Someone starts cuffing them with tg's cuffs. Not a member: refused. Making trouble on their feet:
 * they pull away out of reach, which breaks tg's cuffing do_after. Otherwise they hold still, and their
 * routine waits while the cuffs go on.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/on_cuff_attempt(datum/source, mob/living/user)
	SIGNAL_HANDLER
	var/refusal = cuff_refusal(user)
	if(refusal)
		balloon_alert(user, refusal)
		return COMSIG_CARBON_CUFF_PREVENT
	if(fights_the_cuffs() && !HAS_TRAIT(src, TRAIT_IMMOBILIZED))
		INVOKE_ASYNC(src, PROC_REF(pull_away_from), user)
		return NONE
	cuff_work = TRUE
	ai_controller?.CancelActions()
	addtimer(VARSET_CALLBACK(src, cuff_work, FALSE), PRISONER_CUFF_TIME_STANDING + 1 SECONDS, TIMER_UNIQUE | TIMER_OVERRIDE)
	return NONE

/// A step out of `user`'s reach, as anyone twists away from someone with cuffs
/mob/living/carbon/human/npc/outpost_prisoner/proc/pull_away_from(mob/living/user)
	if(QDELETED(src) || QDELETED(user) || stat != CONSCIOUS)
		return
	step_away(src, user)

/**
 * Cuffs went on: what they were up to stops. Called once the cuffs are on (the restrained trait
 * handler, outpost_prison_prisoner.dm); their line comes from npc_bark().
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/on_cuffed()
	cuff_work = FALSE
	end_activity()
	cancel_threat()
	stop_climb(fell = TRUE)
	// The breakout AI too: a caught runner stays put until walked home.
	ai_controller?.CancelActions()
	update_bubble()

// ===== UNCUFFING =====

/**
 * A member takes the cuffs off by hand from the talk menu, over PRISONER_UNCUFF_TIME. Returns TRUE if
 * they came off. Sleeps.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/uncuff_by(mob/living/user)
	var/obj/item/restraints/handcuffs/worn = handcuffed
	if(!worn || cuff_work)
		return FALSE
	cuff_work = TRUE
	user.visible_message(span_notice("[user] starts taking [worn] off [src]."), span_notice("You start taking [worn] off [src]."))
	var/done = do_after(user, PRISONER_UNCUFF_TIME, target = src)
	cuff_work = FALSE
	if(!done || QDELETED(src) || handcuffed != worn || !prison?.is_member(user))
		return FALSE
	var/cut = istype(worn, /obj/item/restraints/handcuffs/cable)
	user.visible_message(span_notice("[user] [cut ? "cuts" : "takes"] [worn] off [src]."), span_notice("You [cut ? "cut" : "take"] [worn] off [src]."))
	remove_cuffs(user)
	return TRUE

/**
 * Takes their cuffs off through tg's uncuff(). With `user`, real cuffs go to their hands (or the floor)
 * and cable restraints and zipties are cut away; without, the cuffs drop where they are. Returns the
 * cuffs still about, or null.
 */
/mob/living/carbon/human/npc/outpost_prisoner/proc/remove_cuffs(mob/living/user)
	var/obj/item/restraints/handcuffs/worn = handcuffed
	if(!worn)
		return null
	uncuff()
	if(QDELETED(worn))
		return null
	if(user && istype(worn, /obj/item/restraints/handcuffs/cable))
		qdel(worn)
		return null
	user?.put_in_hands(worn)
	return worn

/// The cuffs are off, however they came off
/mob/living/carbon/human/npc/outpost_prisoner/proc/uncuffed()
	if(QDELETED(src))
		return
	prison?.refresh_prisoner_reach(src)

/// Cuffs on or off (tg's TRAIT_RESTRAINED)
/mob/living/carbon/human/npc/outpost_prisoner/proc/on_restraint_changed()
	if(QDELETED(src))
		return
	if(handcuffed)
		INVOKE_ASYNC(src, PROC_REF(on_cuffed))
	else
		INVOKE_ASYNC(src, PROC_REF(uncuffed))

// ===== CUFFED =====

/// Whether their cuffs are souring them and stopping their pay: on past PRISONER_CUFFED_GRACE, and not for good reason
/mob/living/carbon/human/npc/outpost_prisoner/proc/cuffs_souring()
	return cuffed_seconds > PRISONER_CUFFED_GRACE && !prison?.restraint_justified(src)

/// Whether restraining a prisoner is for good reason right now, so it costs them nothing: protective custody, or lockdown they owe
/datum/outpost_prison/proc/restraint_justified(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
	return prisoner.lockdown_left > 0 || protective_custody()

/**
 * Advances a prisoner's cuffed clock by `seconds`: up while cuffed without good reason, and down
 * PRISONER_LOCKED_IN_RECOVERY seconds a second once the cuffs are off, like the lock-in clock.
 */
/datum/outpost_prison/proc/update_cuffed(mob/living/carbon/human/npc/outpost_prisoner/prisoner, seconds)
	if(prisoner.handcuffed)
		if(!restraint_justified(prisoner))
			prisoner.cuffed_seconds += seconds
		return
	prisoner.cuffed_seconds = max(0, prisoner.cuffed_seconds - PRISONER_LOCKED_IN_RECOVERY * seconds)

/// Cuffed, they choose to plan nothing: no routine, no trouble, no patrol, no doors. First on both prisoner controllers.
/datum/ai_planning_subtree/outpost_prisoner_cuffed

/datum/ai_planning_subtree/outpost_prisoner_cuffed/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/outpost_prisoner/prisoner = controller.pawn
	if(istype(prisoner) && prisoner.handcuffed)
		return SUBTREE_RETURN_FINISH_PLANNING

// ===== LOCKDOWN =====

/// They owe PRISON_RIOT_LOCKDOWN_TIME of lockdown from now. `quiet` leaves the line to the caller.
/datum/outpost_prison/proc/start_lockdown(mob/living/carbon/human/npc/outpost_prisoner/prisoner, quiet = FALSE)
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
/datum/outpost_prison/proc/lockdown_tick(mob/living/carbon/human/npc/outpost_prisoner/prisoner, seconds)
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
/datum/outpost_prison/proc/lockdown_served(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
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
/datum/outpost_prison/proc/let_out_early(mob/living/carbon/human/npc/outpost_prisoner/prisoner)
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

/mob/living/carbon/human/npc/outpost_prisoner/examine(mob/user)
	. = ..()
	if(stat == DEAD)
		return
	if(lockdown_left > 0)
		. += span_notice("On lockdown for [outpost_prison_lockdown_text(lockdown_left)].")

/obj/machinery/button/outpost_prison_bolt/examine(mob/user)
	. = ..()
	var/datum/outpost_prison/prison = get_outpost_prison(src)
	var/datum/outpost_prison_cell/cell = prison?.cell_by_number(cell_number)
	if(!cell)
		return
	for(var/mob/living/carbon/human/npc/outpost_prisoner/prisoner in prison.prisoners)
		if(prisoner.lockdown_left <= 0 || prisoner.stat == DEAD || prisoner.phase != PRISONER_PRESENT)
			continue
		var/inside = cell.contains(prisoner)
		if(!inside && cell.occupant != prisoner)
			continue
		var/line = "[prisoner.real_name] is on lockdown for [outpost_prison_lockdown_text(prisoner.lockdown_left)]."
		if(!inside)
			line += " [prisoner.p_They()] [prisoner.p_are()] not in the cell."
		. += span_notice(line)

