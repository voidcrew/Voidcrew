/// How long the node charges, crackling, between going down and the jolt: the window to cuff them, finish them or EMP them
#define BOUNTY_LAZARUS_CHARGE (1.5 SECONDS)
/// Once it has started a charge, it is spent for this long: the player node's own clock (CYBERWARE_LAZARUS_COOLDOWN), in practice once a fight
#define BOUNTY_LAZARUS_RECHARGE (6 MINUTES)
/// Percent of max health a criminal or companion stands back up with. A mini-boss gets up with its own recovery health (BOUNTY_RECOVER_TO) instead.
#define BOUNTY_LAZARUS_HEAL_TO 50
/// With someone putting cuffs on them when the charge is due, it waits: checked this often...
#define BOUNTY_LAZARUS_HOLD_CHECK (0.5 SECONDS)
/// ...for at most this long past the charge (one try with cuffs, BOUNTY_CUFF_TIME, and some), before it bleeds away
#define BOUNTY_LAZARUS_HOLD_MAX (3 SECONDS)
/// The name of the glow filter on its fighter while it charges
#define BOUNTY_LAZARUS_FILTER "bounty_lazarus_charge"
/// The colour of the charge: a defibrillator's blue-white
#define BOUNTY_LAZARUS_COLOR "#7fdcff"

/**
 * # Lazarus on a bounty fighter
 *
 * The player's Lazarus node (voidcrew/modules/cyberware/ware_military_body.dm) in a criminal or a
 * companion. When they are beaten it screams up to charge where everyone can see and hear it (the
 * node's own whine, a blue glow and crackling arcs on the body, a seizure), then slams them back onto
 * their feet with a thunderclap: a criminal or companion at BOUNTY_LAZARUS_HEAL_TO percent of their
 * health, a mini-boss at its own recovery health, rallying as it does whenever it gets up. A charge,
 * however it ends, spends the node for BOUNTY_LAZARUS_RECHARGE.
 *
 * When it fires: a criminal (mini-bosses too) when it goes down at the downed line
 * (COMSIG_BOUNTY_CRIMINAL_DOWNED), as the player node fires on going into crit. Taken down with
 * stamina it never fires: only a failing body sets it off. A companion when it gives up (stamina
 * crit, the framework's downed moment for them), standing them back up to fight.
 *
 * Counterplay, besides the EMP every piece answers to: cuff them during the charge (cuffs already
 * going on when the charge is due hold it, and it fizzles if they close), finish them during the
 * charge (a downed criminal can be killed; dead is the dead share, never revived), or take them down
 * with stamina so it never fires. An EMP during the charge dumps it.
 *
 * It never breaks a capture. No charge starts, and a charge under way fizzles, while they are cuffed,
 * carried or buckled, inside anything (a locker, a crate, a body bag), on a mission pad, being beamed
 * out, given up, off their own ground (dragged aboard a ship), hidden, or blending in. Dead, it does
 * nothing.
 *
 * Nothing shows on the body while it waits: the node sits inside the chest, and the player's has no
 * worn sprite either. Examine is its tell: a hum while it is ready, a tick while it recharges.
 */
/datum/bounty_chrome/lazarus
	key = BOUNTY_CHROME_LAZARUS
	name = "Lazarus"
	// Rarer than the fighting chrome: a second round in one fight is a lot.
	weight = 8
	min_tier = BOUNTY_TIER_WANTED
	// Not the meek: a runner back on its feet only runs again. Every mini-boss kit: it gets up at its own recovery health, so the kit's tired window still comes.
	archetypes = list(BOUNTY_ARCHETYPE_NORMAL, BOUNTY_ARCHETYPE_BOSS, BOUNTY_CHROME_COMPANION)
	organ_looks = list(/obj/item/organ/cyberimp/cyberware/lazarus)
	/// Charging now, between going down and the jolt
	var/charging = FALSE
	/// Goes up with every charge, so a stale timer does nothing
	var/charge_serial = 0
	/// The timer for the jolt, or for the next look at cuffs going on
	var/charge_timer
	/// world.time after which a charge held by cuffs going on bleeds away
	var/hold_until = 0
	/// The arcs, and their glow in the dark, on the fighter while it charges
	var/mutable_appearance/charge_arcs
	var/mutable_appearance/charge_arcs_glow
	/// The light it gives off while it charges
	var/obj/effect/dummy/lighting_obj/moblight/charge_light
	/// Spent until then
	COOLDOWN_DECLARE(recharge)

/datum/bounty_chrome/lazarus/Destroy(force)
	end_charge()
	return ..()

/datum/bounty_chrome/lazarus/detach()
	end_charge()
	return ..()

/datum/bounty_chrome/lazarus/on_downed()
	if(charging || !COOLDOWN_FINISHED(src, recharge) || !may_jolt())
		return
	start_charge()

/datum/bounty_chrome/lazarus/on_emp(severity)
	if(!charging)
		return
	// The bank dumps: the charge is gone, and the clock it started still runs
	var/mob/living/fighter = owner
	end_charge()
	playsound(fighter, 'sound/machines/defib/defib_failed.ogg', 50, FALSE)
	fighter.visible_message(span_warning("The whine under [fighter]'s ribs cuts out."))

/datum/bounty_chrome/lazarus/on_death()
	end_charge()

/datum/bounty_chrome/lazarus/examine_line()
	if(!owner || owner.stat == DEAD || offline_until)
		return null
	if(charging || COOLDOWN_FINISHED(src, recharge))
		return "Something under %THEIR ribs hums."
	return "Something under %THEIR ribs ticks."

/**
 * Whether the node may stand its fighter up now: alive and beaten (a criminal down, a companion given
 * up), and nothing about where they are or what is being done to them makes it a capture (see the
 * header). Read when a charge would start and again when it would fire.
 */
/datum/bounty_chrome/lazarus/proc/may_jolt()
	var/mob/living/basic/fighter = owner
	if(QDELETED(fighter) || fighter.stat == DEAD || !isturf(fighter.loc) || fighter.buckled)
		return FALSE
	if(HAS_TRAIT(fighter, TRAIT_BOUNTY_REMOVED) || HAS_TRAIT(fighter, TRAIT_GODMODE))
		return FALSE
	if(locate(/obj/machinery/mission_pad) in fighter.loc)
		return FALSE
	if(istype(fighter, /mob/living/basic/bounty_companion))
		var/mob/living/basic/bounty_companion/companion = fighter
		return companion.ai_gave_up && !companion.ai_fled
	var/mob/living/basic/bounty_criminal/criminal = fighter
	if(!istype(criminal) || !criminal.is_downed() || criminal.is_restrained())
		return FALSE
	if(HAS_TRAIT(criminal, TRAIT_BOUNTY_SURRENDERED) || criminal.hidden || criminal.blended)
		return FALSE
	// Off its own ground (dragged aboard a ship), it is being taken in
	return criminal.body_on_site(criminal.loc)

/// Starts the charge: the whine, the seizure, the glow. Spent from now, whether or not it gets to fire.
/datum/bounty_chrome/lazarus/proc/start_charge()
	var/mob/living/basic/fighter = owner
	charging = TRUE
	charge_serial++
	hold_until = world.time + BOUNTY_LAZARUS_CHARGE + BOUNTY_LAZARUS_HOLD_MAX
	COOLDOWN_START(src, recharge, BOUNTY_LAZARUS_RECHARGE)
	charge_arcs = bounty_lazarus_arcs()
	charge_arcs_glow = emissive_appearance('icons/effects/effects.dmi', "electricity", fighter)
	fighter.add_overlay(charge_arcs)
	fighter.add_overlay(charge_arcs_glow)
	// Faint at first, white-hot when full: how close it is, at a glance. Colour animates cleanly; size doesn't (chromatic dermis, ware_street.dm).
	fighter.add_filter(BOUNTY_LAZARUS_FILTER, 2, outline_filter(1, "[BOUNTY_LAZARUS_COLOR]30"))
	var/glow = fighter.get_filter(BOUNTY_LAZARUS_FILTER)
	if(glow)
		animate(glow, color = "[BOUNTY_LAZARUS_COLOR]a0", time = BOUNTY_LAZARUS_CHARGE * 0.7)
		animate(color = "#e8faffff", time = BOUNTY_LAZARUS_CHARGE * 0.3)
	charge_light = fighter.mob_light(2, 1.5, BOUNTY_LAZARUS_COLOR)
	// Cuffs closing, a carry, a locker, the pad: it dies the moment they are taken, not when it is due
	RegisterSignals(fighter, bounty_lazarus_capture_signals(), PROC_REF(on_taken))
	// Runs a little past the jolt: the aftershock
	fighter.do_jitter_animation(200)
	playsound(fighter, 'sound/machines/defib/defib_charge.ogg', 75, TRUE)
	fighter.visible_message(span_boldwarning("[fighter] seizes, something under [fighter.p_their()] ribs whines up to full charge!"))
	charge_timer = addtimer(CALLBACK(src, PROC_REF(discharge), charge_serial), BOUNTY_LAZARUS_CHARGE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * The charge under `serial` is full: the jolt, if they may still get up. With someone putting cuffs on
 * them it waits to see how that goes, for up to BOUNTY_LAZARUS_HOLD_MAX. Anything else that stops it
 * (cuffed, carried, shut in something, on the pad) and it fizzles. Returns TRUE if they got up. Tests
 * call it directly instead of waiting.
 */
/datum/bounty_chrome/lazarus/proc/discharge(serial)
	if(!charging || serial != charge_serial)
		return FALSE
	charge_timer = null
	var/mob/living/basic/bounty_criminal/criminal = owner
	var/cuffing = istype(criminal) && criminal.body_cuff_work
	if(cuffing && world.time < hold_until && may_jolt())
		charge_timer = addtimer(CALLBACK(src, PROC_REF(discharge), serial), BOUNTY_LAZARUS_HOLD_CHECK, TIMER_STOPPABLE | TIMER_DELETE_ME)
		return FALSE
	if(cuffing || !online() || !may_jolt())
		fizzle()
		return FALSE
	jolt()
	return TRUE

/// Something happened to them mid-charge (cuffed, buckled, moved, beamed out): if that makes it a capture, the charge dies now
/datum/bounty_chrome/lazarus/proc/on_taken(datum/source)
	SIGNAL_HANDLER
	if(charging && !may_jolt())
		fizzle()

/// The charge came to nothing: it bleeds away with a defibrillator's buzz
/datum/bounty_chrome/lazarus/proc/fizzle()
	var/mob/living/fighter = owner
	end_charge()
	if(QDELETED(fighter) || fighter.stat == DEAD)
		return
	playsound(fighter, 'sound/machines/defib/defib_failed.ogg', 50, FALSE)
	fighter.visible_message(span_notice("The whine under [fighter]'s ribs dies away."))

/**
 * The discharge, as the player node's: stuns and stamina gone, health back, and up on their feet with
 * a thunderclap. A criminal gets up through the body's own stand-up (its recovery clock stopped
 * first), so everything that follows getting up (its AI, a mini-boss's rally) follows this too.
 */
/datum/bounty_chrome/lazarus/proc/jolt()
	var/mob/living/basic/fighter = owner
	end_charge()
	playsound(fighter, 'sound/machines/defib/defib_zap.ogg', 100, TRUE)
	do_sparks(3, TRUE, fighter)
	var/turf/here = get_turf(fighter)
	var/obj/effect/temp_visual/electricity/zap = new(here)
	zap.color = bounty_lazarus_arc_color()
	new /obj/effect/dummy/lighting_obj(here, 3, 3, BOUNTY_LAZARUS_COLOR, 0.3 SECONDS)
	fighter.visible_message(span_boldwarning("[fighter] jolts bolt upright with a thunderclap of current!"))
	if(fighter.staminaloss > 0)
		// Out of stamina crit with it
		fighter.adjustStaminaLoss(-fighter.staminaloss, forced = TRUE)
	// Ignoring stun immunity, so a stun that landed while it could be stunned still comes off
	fighter.SetStun(0, TRUE)
	fighter.SetKnockdown(0, TRUE)
	fighter.SetImmobilized(0, TRUE)
	fighter.SetParalyzed(0, TRUE)
	fighter.SetUnconscious(0, TRUE)
	if(!istype(fighter, /mob/living/basic/bounty_criminal/boss))
		var/stand_health = fighter.maxHealth * BOUNTY_LAZARUS_HEAL_TO / 100
		var/health_now = fighter.maxHealth - fighter.bruteloss
		if(health_now < stand_health)
			fighter.adjust_health(health_now - stand_health, forced = TRUE)
	if(istype(fighter, /mob/living/basic/bounty_companion))
		lazarus_rejoin(fighter)
		return
	var/mob/living/basic/bounty_criminal/criminal = fighter
	// Its recovery clock stops first: left running, it would stand it up early the next time it goes down
	criminal.body_cancel_recovery()
	criminal.body_stand_up()

/// A companion back on its feet: hands down, and with a hunter in sight, weapon out and after them
/datum/bounty_chrome/lazarus/proc/lazarus_rejoin(mob/living/basic/bounty_companion/companion)
	companion.ai_gave_up = FALSE
	companion.ai_over_head = bounty_ai_update_held(companion, companion.ai_over_head, null)
	var/mob/living/hunter = bounty_lazarus_nearest_hunter(companion)
	if(!hunter)
		return
	// Giving up dropped the weapon but left them in the fight, and ai_enter_fight() only draws for someone joining it
	companion.ai_in_fight = FALSE
	companion.ai_join_fight(hunter)

/// Ends any charge: the timer, the glow, the arcs, the light. Safe to call at any time, the fighter being deleted included.
/datum/bounty_chrome/lazarus/proc/end_charge()
	charging = FALSE
	deltimer(charge_timer)
	charge_timer = null
	hold_until = 0
	var/mob/living/fighter = owner
	if(fighter)
		UnregisterSignal(fighter, bounty_lazarus_capture_signals())
		if(charge_arcs)
			fighter.cut_overlay(charge_arcs)
		if(charge_arcs_glow)
			fighter.cut_overlay(charge_arcs_glow)
		fighter.remove_filter(BOUNTY_LAZARUS_FILTER)
	charge_arcs = null
	charge_arcs_glow = null
	QDEL_NULL(charge_light)

/// What a charging Lazarus listens for on its fighter: the moments it may be being taken in
/proc/bounty_lazarus_capture_signals()
	return list(
		COMSIG_BOUNTY_CRIMINAL_RESTRAINED,
		COMSIG_LIVING_SET_BUCKLED,
		COMSIG_MOVABLE_MOVED,
		SIGNAL_ADDTRAIT(TRAIT_BOUNTY_REMOVED),
	)

/// The crackling arcs drawn over a fighter while their Lazarus charges, in the charge's blue
/proc/bounty_lazarus_arcs()
	var/mutable_appearance/arcs = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	arcs.color = bounty_lazarus_arc_color()
	return arcs

/// A colour matrix turning tg's yellow electricity a defibrillator's blue-white
/proc/bounty_lazarus_arc_color()
	return list(0.3, 0.43, 0.5, 0.3, 0.43, 0.5, 0, 0, 0, 0, 0, 0)

/// The nearest hunter `fighter` can see and may hit, within a screen, or null
/proc/bounty_lazarus_nearest_hunter(mob/living/basic/fighter)
	var/turf/here = get_turf(fighter)
	if(!here)
		return null
	var/mob/living/nearest
	var/nearest_dist = INFINITY
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, DEFAULT_MESSAGE_RANGE))
		if(!bounty_ai_is_hunter(person) || !bounty_ai_may_hit(fighter, person))
			continue
		var/dist = get_dist(here, person)
		if(dist >= nearest_dist || !can_see(here, get_turf(person), DEFAULT_MESSAGE_RANGE))
			continue
		nearest = person
		nearest_dist = dist
	return nearest

#undef BOUNTY_LAZARUS_CHARGE
#undef BOUNTY_LAZARUS_RECHARGE
#undef BOUNTY_LAZARUS_HEAL_TO
#undef BOUNTY_LAZARUS_HOLD_CHECK
#undef BOUNTY_LAZARUS_HOLD_MAX
#undef BOUNTY_LAZARUS_FILTER
#undef BOUNTY_LAZARUS_COLOR
