/**
 * # Prison wildcard incidents
 *
 * Owner decision 2026-09-25: trouble is not only mood. Even a well kept wing now and then has a
 * prisoner go for another with a blade, snap and riot on their own, or pick a fight. Mood decides
 * how often (the chance rises with tension) and how far it spreads (others join a riot only below
 * their usual lines). Numbers in voidcrew/_DEFINES/outpost_prison_incidents.dm. They are called
 * "wildcards" in the code, since "incident" already names a riot's run of fines
 * (outpost_prison_economy.dm).
 *
 * The clock rolls once a minute, and only while a member of the wing is home, trouble is on, at
 * least PRISON_INCIDENT_MIN_PRISONERS are in the cell block, and nothing else is going on: no riot,
 * nobody loose, no quiet after a riot, no wildcard already under way. An experiment under way holds
 * nothing (owner, 2026-09-25). After each one, PRISON_INCIDENT_GAP of crew-home time passes before
 * the next can roll.
 *
 * Every kind shows before it hurts:
 * - A stabbing: the attacker stares at the victim and keeps close to them, mutters, and slips a hand
 *   under their shirt; then pulls a shiv (the one under their mattress if they have one) and goes
 *   for them. The attack is a fight (outpost_prison_riot.dm) already past its argument; a shiv
 *   hits harder (strike()). Rivals are picked first, and a stashed shiv makes a stabbing likelier
 *   and its owner likelier to be the one, so shakedowns cut stabbings. Talking the attacker down,
 *   batoning, cuffing or flooring them during the tell stops it. Afterwards they drop the shiv.
 * - A snap: one prisoner paces and mutters, hits the wall, shouts, then riots. Others join only
 *   below their usual lines, so in a happy wing it stays one rioter for the crew to capture and
 *   bolt in. The same things stop it during the tell.
 * - A fight: two prisoners argue, then fight, whatever their mood; the argument is the tell, and a
 *   talk ends it as usual.
 * Examining someone in a tell shows it too (wildcard_examine()). A riot that starts meanwhile, or the
 * one they were after going out of reach, lets it blow over; a creature that has them running holds
 * the tell until they calm down (outpost_prison_panic.dm).
 * No wildcard fines anyone by itself; what follows (a riot, an escape, a death, injuries to treat)
 * has its usual consequences. The XF rule that shivs only come out in riots has this one
 * exception, at the owner's request.
 */

// What an activity's tick() wants next, as in outpost_prison_routine.dm (which undefines its own)
#define ACTIVITY_CONTINUE 0
#define ACTIVITY_DONE 1
#define ACTIVITY_MOVE 2
/// A wildcard's stages
#define WILDCARD_TELL "tell"
#define WILDCARD_ATTACK "attack"

/datum/outpost_prison
	/// Whether wildcards happen at all; the tests' prison fixture turns them off
	var/wildcards_enabled = TRUE
	/// The stabbing or snap under way, in its tell or (a stabbing) its attack
	var/datum/outpost_prison_wildcard/wildcard
	/// Seconds of crew-home time before another wildcard can roll
	var/wildcard_gap_left = PRISON_INCIDENT_GAP
	/// Seconds counted toward the next roll
	var/wildcard_roll_clock = 0
	/// Tests only: TRUE or FALSE decides every roll; null rolls the dice
	var/wildcard_force_roll = null

// ===== THE CLOCK =====

/// Percent chance per PRISON_INCIDENT_ROLL_TIME of a wildcard, at `tension`
/proc/outpost_prison_wildcard_chance(tension)
	if(tension <= PRISON_INCIDENT_CALM_TENSION)
		return PRISON_INCIDENT_CHANCE_CALM
	var/slope = (PRISON_INCIDENT_CHANCE_TENSE - PRISON_INCIDENT_CHANCE_CALM) / (PRISON_INCIDENT_TENSE_TENSION - PRISON_INCIDENT_CALM_TENSION)
	return min(PRISON_INCIDENT_CHANCE_MAX, PRISON_INCIDENT_CHANCE_CALM + slope * (tension - PRISON_INCIDENT_CALM_TENSION))

/// Prisoners who count for wildcards: present, alive, not loose, in the cell block
/datum/outpost_prison/proc/wildcard_prisoner_count()
	var/count = 0
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(counts_for_tension(prisoner) && in_cell_block(prisoner))
			count++
	return count

/**
 * Why the clock is not rolling now, in a few words for the admin panel, or null when it is.
 * The gap only counts down while the crew is home.
 */
/datum/outpost_prison/proc/wildcard_clock_paused()
	if(!wildcards_enabled)
		return "off"
	if(!trouble_enabled)
		return "trouble off"
	if(!crew_home())
		return "nobody home"
	if(wildcard)
		return "one under way"
	if(riot_active || breaking_out)
		return "riot"
	if(loose_count())
		return "someone loose"
	if(subdued_left > 0)
		return "subdued"
	if(wildcard_gap_left > 0)
		return "gap"
	if(wildcard_prisoner_count() < PRISON_INCIDENT_MIN_PRISONERS)
		return "too few prisoners"
	return null

/// A roll at `chance` percent, unless a test decides it
/datum/outpost_prison/proc/wildcard_roll(chance)
	return isnull(wildcard_force_roll) ? prob(chance) : wildcard_force_roll

/// Advances the wildcard under way, the gap and the clock by `seconds`; the extras' tick calls it
/datum/outpost_prison/proc/wildcard_tick(seconds)
	wildcard?.tick(seconds)
	if(crew_home())
		wildcard_gap_left = max(0, wildcard_gap_left - seconds)
	if(wildcard_clock_paused())
		return
	wildcard_roll_clock += seconds
	while(wildcard_roll_clock >= PRISON_INCIDENT_ROLL_TIME)
		wildcard_roll_clock -= PRISON_INCIDENT_ROLL_TIME
		if(wildcard_roll(outpost_prison_wildcard_chance(tension)) && start_wildcard())
			return

// ===== STARTING ONE =====

/**
 * Starts a wildcard of `kind` ("stab", "snap" or "fight"), or of a kind picked by weight among
 * those that can happen now. `skip_tell` goes straight to the attack, for the admin panel. Starts
 * the gap. Returns the kind started, or null.
 */
/datum/outpost_prison/proc/start_wildcard(kind, skip_tell = FALSE)
	if(wildcard || !trouble_enabled || riot_active)
		return null
	var/list/kinds = kind ? list((kind) = 1) : wildcard_kind_weights()
	while(length(kinds))
		var/chosen = pick_weight(kinds)
		if(!chosen)
			break
		kinds -= chosen
		var/started = FALSE
		switch(chosen)
			if("stab")
				started = start_stabbing(skip_tell)
			if("snap")
				started = start_snap(skip_tell)
			if("fight")
				started = start_wildcard_fight()
		if(started)
			wildcard_gap_left = PRISON_INCIDENT_GAP
			wildcard_roll_clock = 0
			return chosen
	return null

/// The kinds and their weights: a stabbing is likelier while someone who could do it has a shiv stashed
/datum/outpost_prison/proc/wildcard_kind_weights()
	var/stab_weight = PRISON_INCIDENT_WEIGHT_STAB
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(prisoner.cell?.stash_shiv && wildcard_can_act(prisoner))
			stab_weight *= PRISON_INCIDENT_STASH_KIND_MULT
			break
	return list(
		"stab" = stab_weight,
		"snap" = PRISON_INCIDENT_WEIGHT_SNAP,
		"fight" = PRISON_INCIDENT_WEIGHT_FIGHT,
	)

/// Why an admin can't start a wildcard of `kind` now, or null
/datum/outpost_prison/proc/wildcard_refusal(kind)
	if(!trouble_enabled)
		return "Trouble is off in this wing."
	if(wildcard)
		return "An incident is already under way."
	if(riot_active)
		return "A riot is on."
	return null

/**
 * Whether `prisoner` can be the one a wildcard starts with: awake and on their feet in the cell
 * block, out of trouble and not busy with it, not shut in a cell, owing no lockdown, not an
 * experiment's subject, and not running from a creature
 */
/datum/outpost_prison/proc/wildcard_can_act(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
		return FALSE
	if(prisoner.in_trouble() || prisoner.can_be_dragged() || prisoner.pulledby || prisoner.experiment_subject || prisoner.lockdown_left > 0 || prisoner.is_panicking())
		return FALSE
	if(prisoner.activity?.sleeping)
		return FALSE
	return in_cell_block(prisoner) && !prisoner.is_confined()

/// Whether `prisoner` can be the one a stabbing is aimed at: as wildcard_can_act(), but asleep will do
/datum/outpost_prison/proc/wildcard_can_be_target(mob/living/basic/outpost_prisoner/prisoner)
	if(QDELETED(prisoner) || prisoner.prison != src || prisoner.phase != PRISONER_PRESENT || prisoner.stat != CONSCIOUS)
		return FALSE
	if(prisoner.in_trouble() || prisoner.can_be_dragged() || prisoner.pulledby || prisoner.experiment_subject)
		return FALSE
	return in_cell_block(prisoner) && !prisoner.is_confined()

/// Whether `one` can walk to where `two` stands
/datum/outpost_prison/proc/wildcard_can_reach(mob/living/basic/outpost_prisoner/one, mob/living/basic/outpost_prisoner/two)
	if(!one.walkable)
		refresh_prisoner_reach(one)
	return !!one.walkable?[get_turf(two)]

/// A pick by weight from parallel lists: the index chosen, or 0
/proc/outpost_prison_weighted_index(list/weights)
	var/total = 0
	for(var/weight in weights)
		total += weight
	if(total <= 0)
		return 0
	var/roll = rand() * total
	for(var/index in 1 to length(weights))
		roll -= weights[index]
		if(roll <= 0)
			return index
	return length(weights)

/**
 * Who stabs whom: list(attacker, victim), or null. Rivals only, when any pair of rivals can; else
 * any pair. A prisoner with a shiv under their mattress is PRISON_INCIDENT_STASH_PICK_MULT times as
 * likely to be the attacker.
 */
/datum/outpost_prison/proc/pick_stab_pair()
	var/list/pairs = list()
	var/list/weights = list()
	var/list/rival_pairs = list()
	var/list/rival_weights = list()
	for(var/mob/living/basic/outpost_prisoner/attacker in prisoners)
		if(!wildcard_can_act(attacker))
			continue
		var/weight = attacker.cell?.stash_shiv ? PRISON_INCIDENT_STASH_PICK_MULT : 1
		for(var/mob/living/basic/outpost_prisoner/victim in prisoners)
			if(victim == attacker || !wildcard_can_be_target(victim) || !wildcard_can_reach(attacker, victim))
				continue
			if(are_rivals(attacker, victim))
				rival_pairs += list(list(attacker, victim))
				rival_weights += weight
			else
				pairs += list(list(attacker, victim))
				weights += weight
	if(length(rival_pairs))
		pairs = rival_pairs
		weights = rival_weights
	var/index = outpost_prison_weighted_index(weights)
	return index ? pairs[index] : null

/// Who snaps: someone able to riot, the unhappier the likelier (up to three times). Null if nobody can.
/datum/outpost_prison/proc/pick_snapper()
	var/list/options = list()
	var/list/weights = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(!wildcard_can_act(prisoner) || !prisoner.can_join_riot())
			continue
		options += prisoner
		// A Most Wanted ringleader snaps more often (outpost_prison_bounty.dm).
		weights += (1 + (100 - prisoner.mood) / 50) * prisoner.bounty_snap_weight_mult()
	var/index = outpost_prison_weighted_index(weights)
	return index ? options[index] : null

/// Who fights whom: list(one, two), rivals first, or null
/datum/outpost_prison/proc/pick_fight_pair()
	var/list/able = list()
	for(var/mob/living/basic/outpost_prisoner/prisoner in prisoners)
		if(wildcard_can_act(prisoner) && !prisoner.fight)
			able += prisoner
	var/list/pairs = list()
	var/list/rival_pairs = list()
	for(var/first_index in 1 to length(able) - 1)
		var/mob/living/basic/outpost_prisoner/one = able[first_index]
		for(var/second_index in first_index + 1 to length(able))
			var/mob/living/basic/outpost_prisoner/two = able[second_index]
			if(!wildcard_can_reach(one, two))
				continue
			if(are_rivals(one, two))
				rival_pairs += list(list(one, two))
			else
				pairs += list(list(one, two))
	if(length(rival_pairs))
		return pick(rival_pairs)
	return length(pairs) ? pick(pairs) : null

/// A stabbing: the tell, or with `skip_tell` the attack at once. Returns TRUE if it started.
/datum/outpost_prison/proc/start_stabbing(skip_tell = FALSE)
	var/list/pair = pick_stab_pair()
	if(!pair)
		return FALSE
	var/datum/outpost_prison_wildcard/stab = new(src, "stab", pair[1], pair[2])
	wildcard = stab
	if(!skip_tell)
		stab.begin_tell()
		return TRUE
	if(stab.strike())
		return TRUE
	qdel(stab)
	return FALSE

/// A snap: the tell, or with `skip_tell` the riot at once. Returns TRUE if it started.
/datum/outpost_prison/proc/start_snap(skip_tell = FALSE)
	var/mob/living/basic/outpost_prisoner/snapper = pick_snapper()
	if(!snapper)
		return FALSE
	if(skip_tell)
		return snap(snapper)
	var/datum/outpost_prison_wildcard/brewing = new(src, "snap", snapper)
	wildcard = brewing
	brewing.begin_tell()
	return TRUE

/// `snapper` riots, alone unless others are unhappy enough to join. Returns TRUE if the riot started.
/datum/outpost_prison/proc/snap(mob/living/basic/outpost_prisoner/snapper)
	if(!snapper?.can_join_riot())
		return FALSE
	if(!start_riot("[snapper.real_name] snapped", forced = snapper, ignore_quiet = TRUE))
		return FALSE
	add_log("[snapper.real_name] snapped.")
	return TRUE

/// Two prisoners start an argument that turns into a fight, whatever their moods. Returns TRUE if it started.
/datum/outpost_prison/proc/start_wildcard_fight()
	var/list/pair = pick_fight_pair()
	if(!pair)
		return FALSE
	return !!start_fight(pair[1], pair[2], fight_cause(pair[1], pair[2]))

// ===== STOPPING ONE =====

/// Whether `prisoner` is working up to a stabbing or a snap right now
/datum/outpost_prison/proc/wildcard_brooding(mob/living/basic/outpost_prisoner/prisoner)
	return !!prisoner && wildcard?.stage == WILDCARD_TELL && wildcard.actor() == prisoner

/// The tell for examine, while `prisoner` works up to a stabbing or a snap; or null
/datum/outpost_prison/proc/wildcard_examine(mob/living/basic/outpost_prisoner/prisoner)
	if(!wildcard_brooding(prisoner))
		return null
	if(wildcard.kind != "stab")
		return "Paces and mutters, fists clenched."
	var/mob/living/basic/outpost_prisoner/target = wildcard.target()
	var/stare = target ? "Keeps staring at [target.speech_name()]" : "Keeps staring at someone"
	return wildcard.last_tell_shown ? "[stare], one hand under [prisoner.p_their()] shirt." : "[stare]."

/// A member talked `prisoner` down (talk_down()): a tell under way is called off. Returns TRUE if one was.
/datum/outpost_prison/proc/wildcard_talked_down(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(!wildcard_brooding(prisoner))
		return FALSE
	return wildcard.stopped_by_staff(user, "talk")

/// Staff batoned `prisoner` (a signal handler's call: nothing here sleeps): a tell under way is called off
/datum/outpost_prison/proc/wildcard_batoned(mob/living/basic/outpost_prisoner/prisoner, mob/living/user)
	if(!wildcard_brooding(prisoner))
		return FALSE
	return wildcard.stopped_by_staff(user, "baton")

// ===== COMINGS AND GOINGS =====

/// A prisoner is leaving the roster: a wildcard they are part of ends, and a stabber drops the shiv
/datum/outpost_prison/proc/wildcard_prisoner_leaving(mob/living/basic/outpost_prisoner/prisoner)
	if(!wildcard || (wildcard.actor() != prisoner && wildcard.target() != prisoner))
		return
	if(wildcard.stage == WILDCARD_ATTACK && wildcard.actor() != prisoner)
		wildcard.put_away_shiv(wildcard.actor())
	QDEL_NULL(wildcard)

/datum/outpost_prison/proc/wildcard_destroy()
	QDEL_NULL(wildcard)

// ===== ADMIN =====

/// The admin panel's wildcard numbers, with the wing events' (outpost_prison_wing_events.dm)
/datum/outpost_prison/proc/incidents_admin_payload()
	var/mob/living/basic/outpost_prisoner/actor = wildcard?.actor()
	var/mob/living/basic/outpost_prisoner/target = wildcard?.target()
	return list(
		"chance" = round(outpost_prison_wildcard_chance(tension), 0.1),
		"gap_left" = round(wildcard_gap_left),
		"paused" = wildcard_clock_paused(),
		"running" = wildcard?.kind,
		"actor" = actor?.real_name,
		"target" = target?.real_name,
		"tell_left" = wildcard?.stage == WILDCARD_TELL ? max(0, round(wildcard.tell_left)) : null,
		"wing_event_in" = isnull(wing_event_left) ? null : max(0, round(wing_event_left)),
		"wing_event_paused" = wing_event_clock_paused(),
		"wing_event_pending" = wing_event_pending,
	)

// ===== THE WILDCARD UNDER WAY =====

/// A stabbing or a snap: its tell, and a stabbing's attack
/datum/outpost_prison_wildcard
	var/datum/outpost_prison/prison
	/// "stab" or "snap"
	var/kind
	var/datum/weakref/actor_ref
	/// Whom a stabbing is aimed at
	var/datum/weakref/target_ref
	/// WILDCARD_TELL, then for a stabbing WILDCARD_ATTACK
	var/stage = WILDCARD_TELL
	/// Seconds of tell left, and gone
	var/tell_left = 0
	var/tell_elapsed = 0
	/// What of the tell has shown
	var/muttered = FALSE
	var/last_tell_shown = FALSE
	var/shouted = FALSE
	/// A stabbing's fight
	var/datum/weakref/fight_ref

/datum/outpost_prison_wildcard/New(datum/outpost_prison/owner, kind, mob/living/basic/outpost_prisoner/actor, mob/living/basic/outpost_prisoner/target)
	. = ..()
	prison = owner
	src.kind = kind
	actor_ref = WEAKREF(actor)
	target_ref = target ? WEAKREF(target) : null
	tell_left = rand(PRISON_INCIDENT_TELL_MIN, PRISON_INCIDENT_TELL_MAX)

/datum/outpost_prison_wildcard/Destroy()
	var/mob/living/basic/outpost_prisoner/actor = actor()
	if(actor && is_tell_activity(actor.activity))
		actor.end_activity()
	if(prison?.wildcard == src)
		prison.wildcard = null
	prison = null
	return ..()

/datum/outpost_prison_wildcard/proc/actor()
	return actor_ref?.resolve()

/datum/outpost_prison_wildcard/proc/target()
	return target_ref?.resolve()

/// Whether an activity is this wildcard's own (the shadowing or the pacing)
/datum/outpost_prison_wildcard/proc/is_tell_activity(datum/prisoner_activity/activity)
	return istype(activity, /datum/prisoner_activity/wildcard_shadow) || istype(activity, /datum/prisoner_activity/pace/wildcard)

/// Whether a stabbing's victim is still there to go for
/datum/outpost_prison_wildcard/proc/target_ok(mob/living/basic/outpost_prisoner/target)
	return !QDELETED(target) && target.prison == prison && (target in prison.prisoners) && target.phase == PRISONER_PRESENT && target.stat != DEAD && target.trouble != PRISONER_TROUBLE_LOOSE && !target.is_rioting()

/// The tell begins: a stare and the shadowing, or the pacing
/datum/outpost_prison_wildcard/proc/begin_tell()
	var/mob/living/basic/outpost_prisoner/actor = actor()
	var/mob/living/basic/outpost_prisoner/target = target()
	if(!actor)
		return
	actor.end_activity()
	actor.stand_up()
	if(kind == "stab")
		actor.face_atom(target)
		actor.manual_emote("stares at [target].")
	else
		actor.manual_emote("starts pacing, muttering under [actor.p_their()] breath.")
	restart_activity(actor)
	log_game("PLAYER OUTPOST PRISON: [actor.real_name] is working up to [kind == "stab" ? "stabbing [target?.real_name]" : "snapping"] at '[prison?.outpost?.name]'")

/// Starts the tell's activity again if something ended it
/datum/outpost_prison_wildcard/proc/restart_activity(mob/living/basic/outpost_prisoner/actor)
	if(is_tell_activity(actor.activity) || !actor.routine_allowed())
		return
	var/datum/prisoner_activity/tell_activity
	if(kind == "stab")
		tell_activity = new /datum/prisoner_activity/wildcard_shadow(actor, target())
	else
		tell_activity = new /datum/prisoner_activity/pace/wildcard(actor)
	if(tell_activity.setup())
		actor.start_activity(tell_activity)
	else
		qdel(tell_activity)

/// Advances the tell, or watches the attack until its fight is over
/datum/outpost_prison_wildcard/proc/tick(seconds)
	var/mob/living/basic/outpost_prisoner/actor = actor()
	var/mob/living/basic/outpost_prisoner/target = target()
	if(stage == WILDCARD_ATTACK)
		var/datum/outpost_prison_fight/brawl = fight_ref?.resolve()
		if(!QDELETED(brawl) && actor?.fight == brawl)
			return
		put_away_shiv(actor)
		qdel(src)
		return
	// Gone, in other trouble, or overtaken by a riot: it blows over unseen.
	if(QDELETED(actor) || actor.prison != prison || actor.phase != PRISONER_PRESENT || actor.stat != CONSCIOUS || actor.trouble || (kind == "stab" && !target_ok(target)))
		qdel(src)
		return
	if(prison.riot_active)
		qdel(src)
		return
	// Stunned, floored, beaten or cuffed: whoever did it stopped it.
	if(actor.can_be_dragged())
		var/mob/living/stopper = actor.staff_to_blame() ? actor.last_staff_attacker_ref?.resolve() : null
		stopped_by_staff(stopper, "down")
		return
	// Held while someone talks to them, while they square up to staff, or while a creature has them running (outpost_prison_panic.dm)
	if(actor.in_trouble() || actor.is_panicking())
		return
	restart_activity(actor)
	tell_elapsed += seconds
	tell_left -= seconds
	if(kind == "stab")
		tell_stab(actor, target)
	else
		tell_snap(actor)
	if(tell_left > 0)
		return
	if(kind == "stab")
		if(!strike())
			give_up(actor)
		return
	// Shut in a cell by now, or pulled into something else: it blows over.
	if(!prison.snap(actor))
		give_up(actor)
		return
	qdel(src)

/// A stabbing's tell: the stare, a mutter, the hand under the shirt
/datum/outpost_prison_wildcard/proc/tell_stab(mob/living/basic/outpost_prisoner/actor, mob/living/basic/outpost_prisoner/target)
	var/in_sight = (target in view(7, actor))
	if(in_sight)
		actor.face_atom(target)
	if(!muttered && tell_elapsed >= PRISON_INCIDENT_MUTTER_AT)
		muttered = TRUE
		actor.say_context("incident_brooding", in_sight ? target : null)
	if(!last_tell_shown && tell_left <= PRISON_INCIDENT_LAST_TELL)
		last_tell_shown = TRUE
		actor.manual_emote("slips a hand under [actor.p_their()] shirt.")

/// A snap's tell: muttering, a blow at the wall, then shouting
/datum/outpost_prison_wildcard/proc/tell_snap(mob/living/basic/outpost_prisoner/actor)
	if(!muttered && tell_elapsed >= PRISON_INCIDENT_MUTTER_AT)
		muttered = TRUE
		actor.say_context("incident_pacing")
	if(!last_tell_shown && tell_left <= PRISON_INCIDENT_LAST_TELL)
		last_tell_shown = TRUE
		var/turf/wall
		for(var/direction in GLOB.cardinals)
			var/turf/beside = get_step(actor, direction)
			if(isclosedturf(beside))
				wall = beside
				break
		if(wall)
			actor.face_atom(wall)
			playsound(wall, 'sound/effects/bang.ogg', 40, TRUE)
			actor.manual_emote("punches the wall.")
		else
			actor.manual_emote(pick("kicks at the floor.", "pulls at [actor.p_their()] hair."))
	if(!shouted && tell_left <= PRISON_INCIDENT_SHOUT_AT)
		shouted = TRUE
		actor.say_context("incident_snap")

/**
 * The stabbing itself: the shiv comes out (the stashed one if there is one) and they go for the
 * victim, a fight past its argument. Returns TRUE if it started.
 */
/datum/outpost_prison_wildcard/proc/strike()
	var/mob/living/basic/outpost_prisoner/actor = actor()
	var/mob/living/basic/outpost_prisoner/target = target()
	// Nobody goes for a prisoner who is already down, or busy fighting someone else.
	if(QDELETED(actor) || actor.stat != CONSCIOUS || actor.trouble || actor.can_be_dragged() || !target_ok(target) || target.stat != CONSCIOUS || target.can_be_dragged() || target.fight)
		return FALSE
	if(!prison.wildcard_can_reach(actor, target))
		return FALSE
	if(is_tell_activity(actor.activity))
		actor.end_activity()
	actor.stand_up()
	if(!prison.draw_stashed_shiv(actor))
		actor.draw_shiv()
		actor.manual_emote("pulls a shiv out from under [actor.p_their()] shirt!")
	var/datum/outpost_prison_fight/brawl = prison.start_fight(actor, target, "stab")
	if(!brawl)
		put_away_shiv(actor)
		return FALSE
	brawl.fighting = TRUE
	stage = WILDCARD_ATTACK
	fight_ref = WEAKREF(brawl)
	actor.face_atom(target)
	actor.say_context("incident_stab", target)
	actor.visible_message(span_danger("[actor] lunges at [target] with a shiv!"))
	prison.add_log("[actor.real_name] pulled a shiv on [target.real_name].")
	return TRUE

/// After a stabbing, the attacker lets go of the shiv, unless they are rioting or loose with it
/datum/outpost_prison_wildcard/proc/put_away_shiv(mob/living/basic/outpost_prisoner/actor)
	if(QDELETED(actor) || !actor.has_shiv() || actor.is_rioting() || actor.trouble == PRISONER_TROUBLE_LOOSE)
		return
	actor.drop_shiv()

/// It came to nothing (the victim out of reach, the snapper shut in): they think better of it
/datum/outpost_prison_wildcard/proc/give_up(mob/living/basic/outpost_prisoner/actor)
	if(!QDELETED(actor) && actor.stat == CONSCIOUS)
		actor.say_context("incident_stopped")
	qdel(src)

/**
 * Staff stopped the tell: talked down (`how` "talk"), batoned ("baton"), or put on the floor or in
 * cuffs ("down"), by `user` if known. Whatever was coming is off, and a hit that stopped it is not
 * held against staff. Called from a signal handler, so nothing here sleeps. Returns TRUE.
 */
/datum/outpost_prison_wildcard/proc/stopped_by_staff(mob/living/user, how)
	if(stage != WILDCARD_TELL)
		return FALSE
	var/mob/living/basic/outpost_prisoner/actor = actor()
	var/mob/living/basic/outpost_prisoner/target = target()
	if(actor)
		actor.note_trouble_ended()
		var/what = kind == "stab" ? "went for [target?.real_name || "someone"]" : "snapped"
		var/who = actor.real_name
		if(how == "talk")
			prison?.add_log("[user?.name || "Someone"] talked [who] down before [actor.p_they()] [what].")
		else
			prison?.add_log(user ? "[user.name] stopped [who] before [actor.p_they()] [what]." : "[who] was stopped before [actor.p_they()] [what].")
		INVOKE_ASYNC(actor, TYPE_PROC_REF(/mob/living/basic/outpost_prisoner, say_context), "incident_stopped")
	qdel(src)
	return TRUE

// ===== THE TELLS' ACTIVITIES =====

/// Staring someone down and keeping close to them: a stabbing's tell
/datum/prisoner_activity/wildcard_shadow
	name = "watching someone"
	context = "incident_brooding"
	weight = 0
	interruptible = FALSE
	var/datum/weakref/target_ref

/datum/prisoner_activity/wildcard_shadow/New(mob/living/basic/outpost_prisoner/doer, mob/living/basic/outpost_prisoner/target)
	. = ..()
	target_ref = target ? WEAKREF(target) : null

/// The one they are watching, for any line they say meanwhile
/datum/prisoner_activity/wildcard_shadow/chat_partner()
	return target_ref?.resolve()

/datum/prisoner_activity/wildcard_shadow/setup()
	if(!target_ref?.resolve())
		return FALSE
	pick_spot()
	return TRUE

/// Close enough already, or the nearest free tile within PRISON_INCIDENT_SHADOW_RANGE of them they can walk to
/datum/prisoner_activity/wildcard_shadow/proc/pick_spot()
	spot = null
	var/mob/living/target = target_ref?.resolve()
	if(!target || get_dist(prisoner, target) <= PRISON_INCIDENT_SHADOW_RANGE)
		return
	if(!prisoner.walkable)
		prisoner.prison?.refresh_prisoner_reach(prisoner)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile in range(PRISON_INCIDENT_SHADOW_RANGE, target))
		if(!prisoner.walkable?[tile] || prisoner.tile_taken(tile))
			continue
		var/distance = get_dist(prisoner, tile)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	spot = best

/datum/prisoner_activity/wildcard_shadow/begin()
	started = TRUE
	ends_at = INFINITY

/datum/prisoner_activity/wildcard_shadow/tick(seconds)
	var/mob/living/target = target_ref?.resolve()
	if(!target)
		return ACTIVITY_DONE
	if(get_dist(prisoner, target) > PRISON_INCIDENT_SHADOW_RANGE)
		pick_spot()
		if(spot)
			return ACTIVITY_MOVE
	prisoner.face_atom(target)
	return ACTIVITY_CONTINUE

/// Pacing up and down, muttering: a snap's tell
/datum/prisoner_activity/pace/wildcard
	name = "pacing, muttering"
	context = "incident_pacing"
	leisure = FALSE
	weight = 0
	interruptible = FALSE

/datum/prisoner_activity/pace/wildcard/setup()
	. = ..()
	exercising = FALSE
	name = initial(name)

/datum/prisoner_activity/pace/wildcard/begin()
	started = TRUE
	ends_at = INFINITY

#undef ACTIVITY_CONTINUE
#undef ACTIVITY_DONE
#undef ACTIVITY_MOVE
#undef WILDCARD_TELL
#undef WILDCARD_ATTACK
