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
/// While it charges, red bolts jump off the body this often, more of them each time...
#define BOUNTY_LAZARUS_ARC_EVERY (0.25 SECONDS)
/// ...up to this many at once...
#define BOUNTY_LAZARUS_ARC_MOST 4
/// ...to tiles and things this far away
#define BOUNTY_LAZARUS_ARC_RANGE 3
/// The jolt throws this many bolts out at once...
#define BOUNTY_LAZARUS_BURST_BOLTS 8
/// ...this far
#define BOUNTY_LAZARUS_BURST_RANGE 4
/// The names of the filters it puts on its fighter: the outline and the halo while it charges, the glow fading after the jolt
#define BOUNTY_LAZARUS_FILTER "bounty_lazarus_charge"
#define BOUNTY_LAZARUS_HALO "bounty_lazarus_halo"
#define BOUNTY_LAZARUS_AFTERGLOW "bounty_lazarus_afterglow"
/// The red of the charge, its light and its bolts
#define BOUNTY_LAZARUS_COLOR "#ff2a2a"

/**
 * # Lazarus on a bounty fighter
 *
 * The player's Lazarus node (voidcrew/modules/cyberware/ware_military_body.dm) in a criminal or a
 * companion. When they are beaten it screams up to charge where the whole room can see and hear it:
 * the node's own whine, red lightning crawling over the body, a red halo flickering brighter, red bolts
 * jumping off them onto the floor, walls and things around, faster as it fills, and a red light. Then
 * it slams them back onto their feet with a thunderclap and a burst of red lightning in every direction:
 * a criminal or companion at BOUNTY_LAZARUS_HEAL_TO percent of their health, a mini-boss at its own
 * recovery health, rallying as it does whenever it gets up. A charge, however it ends, spends the node
 * for BOUNTY_LAZARUS_RECHARGE. Every bolt is only a picture: nothing is hurt, nothing is lit on fire.
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
	/// The timer for the next bolts off the body, and how many rounds of them this charge has thrown
	var/arc_timer
	var/arc_rounds = 0
	/// world.time after which a charge held by cuffs going on bleeds away
	var/hold_until = 0
	/// The red lightning crawling over the fighter while it charges, and its glow in the dark
	var/list/charge_overlays
	/// The red light it gives off while it charges
	var/obj/effect/dummy/lighting_obj/moblight/charge_light
	/// The timer that takes the glow off after the jolt
	var/afterglow_timer
	/// Spent until then
	COOLDOWN_DECLARE(recharge)

/datum/bounty_chrome/lazarus/Destroy(force)
	end_charge()
	return ..()

/datum/bounty_chrome/lazarus/detach()
	end_charge()
	end_afterglow()
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
	fighter.visible_message(span_warning("The red lightning on [fighter] cuts out."))

/datum/bounty_chrome/lazarus/on_death()
	end_charge()
	end_afterglow()

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

/// Starts the charge: the whine, the seizure, the red lightning. Spent from now, whether or not it gets to fire.
/datum/bounty_chrome/lazarus/proc/start_charge()
	var/mob/living/basic/fighter = owner
	charging = TRUE
	charge_serial++
	arc_rounds = 0
	hold_until = world.time + BOUNTY_LAZARUS_CHARGE + BOUNTY_LAZARUS_HOLD_MAX
	COOLDOWN_START(src, recharge, BOUNTY_LAZARUS_RECHARGE)
	end_afterglow()
	// Lightning crawling all over them, glowing in the dark too
	charge_overlays = bounty_lazarus_body_arcs(fighter)
	fighter.add_overlay(charge_overlays)
	// A red outline and a red halo, flickering brighter as it fills: how close it is, at a glance.
	// Colour animates cleanly; size doesn't (chromatic dermis, ware_street.dm).
	fighter.add_filter(BOUNTY_LAZARUS_HALO, 2, drop_shadow_filter(0, 0, 4, 0, "#ff000000"))
	fighter.add_filter(BOUNTY_LAZARUS_FILTER, 3, outline_filter(1, "#ff2a2a40"))
	bounty_lazarus_build_glow(fighter.get_filter(BOUNTY_LAZARUS_HALO), list("#ff000040", "#ff000020", "#ff000070", "#ff000050", "#ff0000a0", "#ff000080", "#ff1010d0", "#ff2020c0"))
	bounty_lazarus_build_glow(fighter.get_filter(BOUNTY_LAZARUS_FILTER), list("#ff2a2a80", "#ff2a2a50", "#ff2a2ab0", "#ff2a2a80", "#ff4040e0", "#ff3030b0", "#ff8080ff", "#ffb0b0ff"))
	charge_light = fighter.mob_light(3, 1, BOUNTY_LAZARUS_COLOR)
	// Cuffs closing, a carry, a locker, the pad: it dies the moment they are taken, not when it is due
	RegisterSignals(fighter, bounty_lazarus_capture_signals(), PROC_REF(on_taken))
	// Runs a little past the jolt: the aftershock
	fighter.do_jitter_animation(300)
	playsound(fighter, 'sound/machines/defib/defib_charge.ogg', 75, TRUE)
	playsound(fighter, 'sound/effects/magic/lightning_chargeup.ogg', 60, TRUE)
	fighter.visible_message(span_boldwarning("Red lightning crawls over [fighter], and something under [fighter.p_their()] ribs whines up to full charge!"))
	arc_timer = addtimer(CALLBACK(src, PROC_REF(arc_round), charge_serial), BOUNTY_LAZARUS_ARC_EVERY * 0.5, TIMER_STOPPABLE | TIMER_DELETE_ME)
	charge_timer = addtimer(CALLBACK(src, PROC_REF(discharge), charge_serial), BOUNTY_LAZARUS_CHARGE, TIMER_STOPPABLE | TIMER_DELETE_ME)

/**
 * One round of red bolts jumping off them while the charge under `serial` builds: more of them each
 * round, up to BOUNTY_LAZARUS_ARC_MOST, and the red light brighter. Only pictures. Runs until the
 * charge ends, a held charge included. Tests call it directly.
 */
/datum/bounty_chrome/lazarus/proc/arc_round(serial)
	arc_timer = null
	if(!charging || serial != charge_serial || QDELETED(owner))
		return
	arc_rounds++
	var/bolts = min(1 + round(arc_rounds / 2), BOUNTY_LAZARUS_ARC_MOST)
	for(var/atom/struck as anything in bounty_lazarus_arc_targets(owner, BOUNTY_LAZARUS_ARC_RANGE, bolts))
		bounty_lazarus_bolt(owner, struck, 0.2 SECONDS)
	charge_light?.set_light_power(min(1 + arc_rounds * 0.4, 3.5))
	if(arc_rounds == 3)
		charge_light?.set_light_range(4)
	playsound(owner, SFX_SPARKS, min(25 + arc_rounds * 6, 70), TRUE)
	arc_timer = addtimer(CALLBACK(src, PROC_REF(arc_round), serial), BOUNTY_LAZARUS_ARC_EVERY, TIMER_STOPPABLE | TIMER_DELETE_ME)

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

/// The charge came to nothing: the lightning gutters out with a defibrillator's buzz
/datum/bounty_chrome/lazarus/proc/fizzle()
	var/mob/living/fighter = owner
	end_charge()
	if(QDELETED(fighter) || fighter.stat == DEAD)
		return
	playsound(fighter, 'sound/machines/defib/defib_failed.ogg', 50, FALSE)
	fighter.visible_message(span_notice("The red lightning on [fighter] gutters out."))

/**
 * The discharge, as the player node's: stuns and stamina gone, health back, and up on their feet with
 * a thunderclap and a burst of red lightning. A criminal gets up through the body's own stand-up (its
 * recovery clock stopped first), so everything that follows getting up (its AI, a mini-boss's rally)
 * follows this too.
 */
/datum/bounty_chrome/lazarus/proc/jolt()
	var/mob/living/basic/fighter = owner
	end_charge()
	playsound(fighter, 'sound/machines/defib/defib_zap.ogg', 100, TRUE)
	playsound(fighter, 'sound/effects/magic/lightningbolt.ogg', 80, TRUE)
	bounty_lazarus_burst(fighter)
	// The body glows red a moment longer, fading
	fighter.add_filter(BOUNTY_LAZARUS_AFTERGLOW, 3, outline_filter(1, "#ffb0b0ff"))
	var/afterglow = fighter.get_filter(BOUNTY_LAZARUS_AFTERGLOW)
	if(afterglow)
		animate(afterglow, color = "#ff000000", time = 1 SECONDS)
	afterglow_timer = addtimer(CALLBACK(src, PROC_REF(end_afterglow)), 1 SECONDS, TIMER_STOPPABLE | TIMER_DELETE_ME)
	fighter.visible_message(span_boldwarning("[fighter] jolts bolt upright with a thunderclap of red lightning!"))
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

/// Ends any charge: its timers, the halo, the lightning, the light. Safe to call at any time, the fighter being deleted included.
/datum/bounty_chrome/lazarus/proc/end_charge()
	charging = FALSE
	deltimer(charge_timer)
	charge_timer = null
	deltimer(arc_timer)
	arc_timer = null
	hold_until = 0
	var/mob/living/fighter = owner
	if(fighter)
		UnregisterSignal(fighter, bounty_lazarus_capture_signals())
		if(charge_overlays)
			fighter.cut_overlay(charge_overlays)
		fighter.remove_filter(list(BOUNTY_LAZARUS_FILTER, BOUNTY_LAZARUS_HALO))
	charge_overlays = null
	QDEL_NULL(charge_light)

/// Takes the glow left by a jolt off its fighter
/datum/bounty_chrome/lazarus/proc/end_afterglow()
	deltimer(afterglow_timer)
	afterglow_timer = null
	owner?.remove_filter(BOUNTY_LAZARUS_AFTERGLOW)

/// What a charging Lazarus listens for on its fighter: the moments it may be being taken in
/proc/bounty_lazarus_capture_signals()
	return list(
		COMSIG_BOUNTY_CRIMINAL_RESTRAINED,
		COMSIG_LIVING_SET_BUCKLED,
		COMSIG_MOVABLE_MOVED,
		SIGNAL_ADDTRAIT(TRAIT_BOUNTY_REMOVED),
	)

/// A colour matrix turning any of tg's lightning art (yellow, blue or white) a vicious red, its brightest parts nearly pink
/proc/bounty_lazarus_red()
	return list(0.55, 0.1, 0.1, 0.55, 0.1, 0.1, 0.55, 0.1, 0.1, 0, 0, 0)

/**
 * The red lightning that crawls over a fighter while their Lazarus charges: a thick bolt of tg's
 * lightning running through the body, two layers of its arcs, one a little larger than the body so it
 * crawls off the edges, and their glow in the dark (emissive) when `fighter` is given. For the overlays
 * and the renders test.
 */
/proc/bounty_lazarus_body_arcs(atom/fighter)
	. = list()
	var/core_state = "lightning[rand(1, 12)]"
	var/mutable_appearance/core = mutable_appearance('icons/effects/beam.dmi', core_state, ABOVE_MOB_LAYER)
	core.color = bounty_lazarus_red()
	. += core
	var/mutable_appearance/inner = mutable_appearance('icons/effects/effects.dmi', "electricity", ABOVE_MOB_LAYER)
	inner.color = bounty_lazarus_red()
	. += inner
	var/mutable_appearance/outer = mutable_appearance('icons/effects/effects.dmi', "electricity3", ABOVE_MOB_LAYER)
	outer.color = bounty_lazarus_red()
	outer.transform = matrix().Scale(1.3)
	. += outer
	if(!fighter)
		return
	. += emissive_appearance('icons/effects/beam.dmi', core_state, fighter)
	. += emissive_appearance('icons/effects/effects.dmi', "electricity", fighter)
	var/mutable_appearance/outer_glow = emissive_appearance('icons/effects/effects.dmi', "electricity3", fighter)
	outer_glow.transform = matrix().Scale(1.3)
	. += outer_glow

/// Animates a glow filter (`glow`, may be null) through `steps` (colours with alpha) over the charge: a flicker that builds
/proc/bounty_lazarus_build_glow(glow, list/steps)
	if(!glow || !length(steps))
		return
	var/step_time = BOUNTY_LAZARUS_CHARGE / length(steps)
	animate(glow, color = steps[1], time = step_time)
	for(var/i in 2 to length(steps))
		animate(color = steps[i], time = step_time)

/**
 * Where `count` bolts off `fighter` land, in sight within `range`: something solid nearby (a wall, a
 * machine, a crate) about half the time, else a floor tile. Never a person: the bolts are only
 * pictures, and must not look like they hurt anyone. May be fewer than `count`, or empty.
 */
/proc/bounty_lazarus_arc_targets(atom/fighter, range, count)
	. = list()
	var/turf/here = get_turf(fighter)
	if(!here)
		return
	var/list/floors = list()
	var/list/things = list()
	for(var/turf/spot as anything in RANGE_TURFS(range, here))
		if(spot == here || !can_see(here, spot, range))
			continue
		if(spot.density)
			things += spot
			continue
		floors += spot
		for(var/obj/thing in spot)
			if(thing.density && !thing.invisibility && !iseffect(thing))
				things += thing
	for(var/i in 1 to count)
		if(length(things) && (prob(50) || !length(floors)))
			. += pick(things)
		else if(length(floors))
			. += pick(floors)

/// One red bolt from `from` to `struck`, crackling where it lands, gone after `time`. Only a picture.
/proc/bounty_lazarus_bolt(atom/from, atom/struck, time)
	var/state = prob(25) ? "red_lightning" : "lightning[rand(1, 12)]"
	from.Beam(struck, icon_state = state, time = time, beam_color = BOUNTY_LAZARUS_COLOR)
	var/turf/landing = get_turf(struck)
	if(landing)
		var/obj/effect/temp_visual/electricity/crackle = new(landing)
		crackle.color = bounty_lazarus_red()

/// The jolt's burst: red bolts thrown out every way, a red ring, a red flash. Only pictures.
/proc/bounty_lazarus_burst(atom/fighter)
	var/turf/here = get_turf(fighter)
	if(!here)
		return
	for(var/atom/struck as anything in bounty_lazarus_arc_targets(fighter, BOUNTY_LAZARUS_BURST_RANGE, BOUNTY_LAZARUS_BURST_BOLTS))
		bounty_lazarus_bolt(fighter, struck, 0.5 SECONDS)
	var/obj/effect/temp_visual/emp/pulse/ring = new(here)
	ring.color = bounty_lazarus_red()
	ring.transform = matrix().Scale(3)
	var/obj/effect/temp_visual/electricity/crackle = new(here)
	crackle.color = bounty_lazarus_red()
	crackle.transform = matrix().Scale(2)
	new /obj/effect/dummy/lighting_obj(here, 5, 4, BOUNTY_LAZARUS_COLOR, 0.5 SECONDS)

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
#undef BOUNTY_LAZARUS_ARC_EVERY
#undef BOUNTY_LAZARUS_ARC_MOST
#undef BOUNTY_LAZARUS_ARC_RANGE
#undef BOUNTY_LAZARUS_BURST_BOLTS
#undef BOUNTY_LAZARUS_BURST_RANGE
#undef BOUNTY_LAZARUS_FILTER
#undef BOUNTY_LAZARUS_HALO
#undef BOUNTY_LAZARUS_AFTERGLOW
#undef BOUNTY_LAZARUS_COLOR
