/// Backgrounds: owned by P2.

/**
 * # The Penitentiary's NPC wing
 *
 * The player-outpost prison run without an outpost: the inmates' routines, social life, pastimes
 * and the yard's feel, and the NPC guards, all reused as they are. What needs an outpost or makes
 * work is off [TIM-1]: no treasury, pay, fines, intake from the transfer pool, experiments, riots,
 * fights or breakouts, and no random mess [PERF-1]. Sentences are for life. Members of the wing
 * are its own staff mobs; presence is any player inside the Penitentiary.
 *
 * Eight inmates are admitted into NPC cells 1-8 and six guards hired free when it starts; a cell
 * emptied by a death takes a new inmate PENITENTIARY_REFILL_TIME later while someone is there.
 *
 * Player convicts are never prisoners of this wing. A guard on duty goes after one loose in the
 * wing (never one in his own cell [MP-10]) and batons him like an inmate on the run.
 */

/// How long an emptied NPC cell waits for a new inmate, and how long a dead inmate lies before the morgue takes them
#define PENITENTIARY_REFILL_TIME (10 MINUTES)
/// Seconds between the site's slow checks: capture bodies, pods, refills
#define PENITENTIARY_SITE_CHECK_SECONDS 60
/// The guard response to a loose player convict: below the leash and shelter, above fights
#define PENITENTIARY_GUARD_PRIORITY_CONVICT 6
/// The staff dialogue file, in AMBIENT_STRINGS_DIR
#define PENITENTIARY_STAFF_DIALOGUE "penitentiary_staff.json"

/// The Penitentiary's NPC wing, run without an outpost
/datum/outpost_prison/penitentiary
	trouble_enabled = FALSE
	visitors_allowed = FALSE
	/// The site this wing belongs to
	var/obj/structure/overmap/penitentiary/site
	/// Seconds since the site's slow checks last ran
	var/site_clock = 0
	/// NPC cell number -> world.time it takes a new inmate
	var/list/refill_at = list()

// No ..(): the parent's New() reads an outpost upgrade this prison does not have
/datum/outpost_prison/penitentiary/New(obj/structure/overmap/penitentiary/new_site, area/voidcrew/player_outpost/prison/wing_area)
	site = new_site
	wing = wing_area
	wing.prison = src
	find_cells()
	capacity = BACKGROUND_PEN_INMATES
	last_crew_home_at = world.time
	refresh_cell_block()
	refresh_conditions()
	START_PROCESSING(SSprocessing, src)

/datum/outpost_prison/penitentiary/Destroy()
	if(site?.prison == src)
		site.prison = null
	site = null
	refill_at.Cut()
	return ..()

/// Fills NPC cells 1-8 with inmates and hires the six guards. Never the transfer pool.
/datum/outpost_prison/penitentiary/proc/populate()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(length(prisoners) >= BACKGROUND_PEN_INMATES)
			break
		if(cell.occupant || cell.number > BACKGROUND_PEN_INMATES)
			continue
		admit_inmate(cell)
	for(var/i in 1 to BACKGROUND_PEN_GUARDS)
		add_guard_record(TRUE, /mob/living/basic/outpost_prison_guard/penitentiary)
	add_log("The Meridian's wing opened with [length(prisoners)] inmates and [length(guard_records)] guards.")

/// One new inmate in `cell`, booked in. Returns them, or null.
/datum/outpost_prison/penitentiary/proc/admit_inmate(datum/outpost_prison_cell/cell)
	var/turf/spot = cell?.arrival_turf()
	if(!spot)
		return null
	var/mob/living/basic/outpost_prisoner/inmate = new(spot, null)
	admit(inmate, cell)
	return inmate

// ===== THE WING =====

/datum/outpost_prison/penitentiary/wing_turfs()
	if(!wing)
		return list()
	if(isnull(wing_block_cache))
		wing_block_cache = list()
		for(var/turf/tile as anything in site?.interior_turfs())
			if(tile.loc == wing)
				wing_block_cache += tile
	var/list/turfs = list()
	for(var/turf/tile as anything in wing_block_cache)
		if(tile.loc == wing)
			turfs += tile
	return turfs

/datum/outpost_prison/penitentiary/in_wing_bounds(turf/tile)
	return !!tile && tile.loc == wing

/datum/outpost_prison/penitentiary/wing_z()
	return site?.template_bottom_left?.z || 0

// ===== TIME =====

// The parent's process() less make_mess() [PERF-1], plus the site's slow checks
/datum/outpost_prison/penitentiary/process(seconds_per_tick)
	if(QDELETED(site) || !wing)
		return
	tick(seconds_per_tick)
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.phase != PRISONER_PRESENT)
			continue
		prisoner.maybe_drip(seconds_per_tick)
		if(prisoner.stat != CONSCIOUS)
			continue
		if(prisoner.ai_running())
			prisoner.speech_tick()
	site_clock += seconds_per_tick
	if(site_clock >= PENITENTIARY_SITE_CHECK_SECONDS)
		site_clock = 0
		site_checks()

/// The slow checks: bodies in Secure Holding, empty pods, refilling the wing, life sentences
/datum/outpost_prison/penitentiary/proc/site_checks()
	site.capture_sweep()
	site.pods_tick()
	refill_tick()
	for(var/mob/living/basic/outpost_prisoner/inmate in prisoners)
		// Life sentences: the clock never runs out, so nobody talks about getting out
		if(inmate.sentence_left < OUTPOST_PRISON_SENTENCE_MIN)
			inmate.sentence_left = rand(OUTPOST_PRISON_SENTENCE_MIN, OUTPOST_PRISON_SENTENCE_MAX)

/// The dead are taken away after a while; an emptied cell takes a new inmate later, while someone is there to see it
/datum/outpost_prison/penitentiary/proc/refill_tick()
	for(var/mob/living/basic/outpost_prisoner/inmate in prisoners.Copy())
		if(inmate.stat != DEAD || !inmate.died_at || world.time - inmate.died_at < PENITENTIARY_REFILL_TIME)
			continue
		var/turf/spot = get_turf(inmate)
		if(spot)
			new /obj/effect/temp_visual/transporter_flash/departure(spot)
		qdel(inmate)
	var/home = crew_home()
	for(var/datum/outpost_prison_cell/cell as anything in cells)
		if(cell.number > BACKGROUND_PEN_INMATES)
			continue
		var/key = "[cell.number]"
		if(cell.occupant)
			refill_at -= key
			continue
		if(isnull(refill_at[key]))
			refill_at[key] = world.time + PENITENTIARY_REFILL_TIME
			continue
		if(!home || world.time < refill_at[key] || length(prisoners) >= BACKGROUND_PEN_INMATES)
			continue
		refill_at -= key
		var/mob/living/basic/outpost_prisoner/fresh = admit_inmate(cell)
		fresh?.beam_in()

/datum/outpost_prison/penitentiary/extras_tick(seconds)
	// The extras that reach an outpost or start incidents stay off [TIM-1]
	guards_tick(seconds)
	ambience_tick(seconds)
	social_tick(seconds)
	life_tick(seconds)
	pastimes_tick(seconds)

/datum/outpost_prison/penitentiary/accrue_pay(mob/living/basic/outpost_prisoner/prisoner, served)
	return

/datum/outpost_prison/penitentiary/pay_tick(seconds)
	return

/datum/outpost_prison/penitentiary/guard_wages_tick(seconds)
	return

/datum/outpost_prison/penitentiary/guards_quit_unpaid()
	return 0

/datum/outpost_prison/penitentiary/trouble_tick(seconds)
	return

/datum/outpost_prison/penitentiary/experiments_tick(seconds)
	return

/datum/outpost_prison/penitentiary/intake_tick(seconds)
	return

// Life sentences
/datum/outpost_prison/penitentiary/check_release(mob/living/basic/outpost_prisoner/prisoner)
	return

// ===== MONEY AND NOTICES: there are none =====

/datum/outpost_prison/penitentiary/pay_treasury(amount, reason)
	return FALSE

/datum/outpost_prison/penitentiary/charge_fine(amount, reason, incident = FALSE)
	return 0

/datum/outpost_prison/penitentiary/treasury_debt()
	return 0

/datum/outpost_prison/penitentiary/pay_treasury_debt(mob/user)
	return 0

/datum/outpost_prison/penitentiary/announce(message, level = SHIP_NOTIFY_WARNING)
	return

// ===== WHO BELONGS =====

/datum/outpost_prison/penitentiary/is_member(mob/user)
	if(!ismob(user) || is_outpost_prisoner(user))
		return FALSE
	if(isAdminGhostAI(user))
		return TRUE
	if(istype(user, /mob/living/basic/ambient_npc/penitentiary))
		return user.stat == CONSCIOUS
	if(is_outpost_prison_guard(user, on_duty = TRUE))
		var/mob/living/basic/outpost_prison_guard/guard = user
		return guard.prison == src
	return FALSE

/datum/outpost_prison/penitentiary/is_owner_shipmate(mob/user)
	return FALSE

/// Whether a player is awake and playing inside the Penitentiary: the wing's clocks wait for one
/datum/outpost_prison/penitentiary/find_crew_home()
	var/z = wing_z()
	if(!z || z > length(SSmobs.clients_by_zlevel) || QDELETED(site))
		return FALSE
	for(var/mob/living/person as anything in SSmobs.clients_by_zlevel[z])
		if(QDELETED(person) || !person.client || person.stat != CONSCIOUS || is_outpost_prisoner(person))
			continue
		if(site.contains_site_turf(get_turf(person)))
			return TRUE
	return FALSE

// ===== GUARDS AND PLAYER CONVICTS =====

/datum/outpost_prison/penitentiary/dispatch_guards()
	assign_convict_responses()
	return ..()

/**
 * Whether a guard should go after `person`: a player convict, awake, on his feet and free, in the
 * NPC wing, and not in a cell of his own [MP-10].
 */
/datum/outpost_prison/penitentiary/proc/convict_loose_target(mob/living/carbon/human/person)
	if(!istype(person) || QDELETED(person) || person.stat != CONSCIOUS)
		return FALSE
	if(!HAS_TRAIT(person, TRAIT_BACKGROUND_CONVICT))
		return FALSE
	if(person.handcuffed || person.body_position == LYING_DOWN || person.has_status_effect(/datum/status_effect/incapacitating/stamcrit))
		return FALSE
	var/turf/here = get_turf(person)
	if(!here || here.loc != wing)
		return FALSE
	return !site?.in_own_cell(person)

/// Gives each loose player convict in the wing to the nearest free guard, one guard each
/datum/outpost_prison/penitentiary/proc/assign_convict_responses()
	var/list/on_duty = list()
	for(var/mob/living/basic/outpost_prison_guard/penitentiary/guard in guard_mobs)
		if(guard.on_duty() && guard.ai_running())
			on_duty += guard
	if(!length(on_duty))
		return
	for(var/datum/mind/convict_mind as anything in background_active_minds(BACKGROUND_CONVICT))
		var/mob/living/carbon/human/convict = convict_mind?.current
		if(!convict_loose_target(convict))
			continue
		var/key = "convict:[REF(convict)]"
		var/handled = FALSE
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response?.key == key)
				handled = TRUE
				break
		if(handled)
			continue
		var/mob/living/basic/outpost_prison_guard/best
		for(var/mob/living/basic/outpost_prison_guard/guard as anything in on_duty)
			if(guard.response && guard.response.priority >= PENITENTIARY_GUARD_PRIORITY_CONVICT)
				continue
			if(guard.skipping(key))
				continue
			if(!best || get_dist(guard, convict) < get_dist(best, convict))
				best = guard
		best?.give_response("convict_loose", PENITENTIARY_GUARD_PRIORITY_CONVICT, key, convict, null)

/// The Meridian's guards: the wing's own guards, who also go after loose player convicts
/mob/living/basic/outpost_prison_guard/penitentiary
	desc = "A Meridian corrections officer."

// A response to a loose player convict runs here; every other kind runs as it always has
/mob/living/basic/outpost_prison_guard/penitentiary/perform_response()
	if(response?.kind == "convict_loose")
		return perform_convict_response()
	return ..()

/**
 * After a loose player convict: up to him, one line, then the baton every
 * OUTPOST_GUARD_BATON_COOLDOWN until he is down, cuffed or out of the wing.
 */
/mob/living/basic/outpost_prison_guard/penitentiary/proc/perform_convict_response()
	var/datum/outpost_guard_response/job = response
	var/datum/outpost_prison/penitentiary/penitentiary = prison
	if(!job || !on_duty() || !istype(penitentiary))
		end_response()
		return FALSE
	var/mob/living/carbon/human/target = job.target()
	if(!penitentiary.convict_loose_target(target))
		end_response()
		return FALSE
	if(!Adjacent(target))
		job.set_goal(target)
		if(!job.reached && world.time > job.expires_at)
			LAZYSET(response_skips, job.key, world.time + OUTPOST_GUARD_RESPONSE_TIMEOUT)
			end_response()
			return FALSE
		return TRUE
	job.set_goal(null)
	job.reached = TRUE
	face_atom(target)
	if(!job.said)
		job.said = TRUE
		say_convict_line()
		return TRUE
	strike_convict(target)
	return TRUE

/// A line at a loose convict, from the staff dialogue file
/mob/living/basic/outpost_prison_guard/penitentiary/proc/say_convict_line()
	if(QDELETED(src) || stat == DEAD || phase != OUTPOST_GUARD_PRESENT)
		return FALSE
	var/list/lines = ambient_dialogue_lines(PENITENTIARY_STAFF_DIALOGUE, "guard", "convict_loose")
	if(!length(lines))
		return FALSE
	var/line = pick(lines)
	last_line = line
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), line)
	return TRUE

/**
 * One stun baton strike on a player convict: the same numbers as strike() on an inmate, never
 * through melee_attack(). Returns TRUE if it landed.
 */
/mob/living/basic/outpost_prison_guard/penitentiary/proc/strike_convict(mob/living/carbon/human/target)
	if(!COOLDOWN_FINISHED(src, baton_cooldown) || !on_duty() || QDELETED(target) || target.stat != CONSCIOUS || !Adjacent(target))
		return FALSE
	COOLDOWN_START(src, baton_cooldown, OUTPOST_GUARD_BATON_COOLDOWN)
	set_baton(TRUE)
	face_atom(target)
	do_attack_animation(target)
	playsound(target, 'sound/items/weapons/egloves.ogg', 50, TRUE)
	target.visible_message(span_danger("[src] strikes [target] with a stun baton!"), span_userdanger("[src] strikes you with a stun baton!"))
	target.apply_damage(OUTPOST_GUARD_BATON_STAMINA, STAMINA)
	return TRUE

#undef PENITENTIARY_REFILL_TIME
#undef PENITENTIARY_SITE_CHECK_SECONDS
#undef PENITENTIARY_GUARD_PRIORITY_CONVICT
