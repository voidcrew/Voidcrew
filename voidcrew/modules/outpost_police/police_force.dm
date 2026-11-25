/**
 * # Outpost police: force
 *
 * Owner: P4. Who officers fight and how hard: the targeting strategy, the weapon mode for the current target,
 * hold-fire and body-block rules, and looking for a suspect who got away. Spec 8. Every "does this officer
 * see that suspect" test outside the targeting strategy goes through police.perception.sees().
 *
 * - Targeting (/datum/targeting_strategy/basic/human_npc/outpost_police): a person is a target at ARREST, STUN or
 *   LETHAL force by their warrant, or by what this officer saw and has not yet got out on the radio
 *   (force_level(target, officer)), and never in police custody; a stunned person is left for the cuffs. The
 *   stealth scan judges only those (spec-stealth 1.3), so a clean visitor is never noticed. A creature by the old
 *   turret rule: xenos always, otherwise not on the outpost's side, not TRAIT_OUTPOST_RESIDENT, and
 *   is_hostile_creature(). A mech when anyone aboard is a target.
 * - Force (outpost_police_force subtree, set_force()): the baton at ARREST, the energy gun on disable at STUN
 *   and on kill at LETHAL or for a creature, switched with the gun's own select_fire(). At ARREST an officer
 *   with no case on that person stands and watches them: the arrest is the case's job. The officer shoots
 *   through the human NPC base's shot (the real gun), but holds fire while anyone they would not shoot stands
 *   in the line (abuse M10), stepping aside instead.
 * - Giving up (gives_up(), police_holds_fire()): at STUN force is for someone who fights or gets away. Nobody fires on
 *   or strikes someone who stays where they are with empty hands and goes for nobody, before the order, in the time to
 *   comply, or with the cuffs coming: every officer but the arresting one keeps its aim on them from close by, and is
 *   on them again the moment they run, draw or hit out. The arresting officer's baton is the arrest's (police_arrest.dm).
 * - Body-blocking (M11): a person who stands in the line within 2 tiles of an officer firing to kill for
 *   OUTPOST_POLICE_BLOCK_TIME, or pulls an officer (police_dispatch.dm), resists, again every 5 seconds.
 * - Looking for someone is stealth's searching state (stealth_ai.dm); dispatch sends officers to search
 *   (police_dispatch.dm) and the lift is taken inside the walk (police_stealth.dm, stealth_walk()).
 */

// =========================================================================
// TARGETING
// =========================================================================

/// Whom an officer fights. Policy in police_will_fight(); range, sight and the downed rule from the base.
/datum/targeting_strategy/basic/human_npc/outpost_police

/datum/targeting_strategy/basic/human_npc/outpost_police/can_attack(mob/living/living_mob, atom/the_target, vision_range)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = living_mob
	if(!istype(officer) || !officer.police_will_fight(the_target))
		return FALSE
	return ..()

// A person shares no side with the police: their warrant decides (players' default faction is the officers' own)
/datum/targeting_strategy/basic/human_npc/outpost_police/faction_check(datum/ai_controller/controller, mob/living/living_mob, mob/living/the_target)
	if(the_target.mind || the_target.client)
		return FALSE
	return ..()

/**
 * Whether this officer would fight `target`, sight and range aside: a person by their warrant (STUN or LETHAL,
 * not in custody, not already stunned at STUN), a creature by the old turret rule, a mech by who is aboard.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_will_fight(atom/target)
	if(!police || QDELETED(target))
		return FALSE
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		for(var/mob/living/occupant in mech.occupants)
			if(police_will_fight(occupant))
				return TRUE
		return FALSE
	if(!isliving(target))
		return FALSE
	var/mob/living/living_target = target
	if(living_target == src || living_target.stat == DEAD)
		return FALSE
	if(istype(living_target, /mob/living/carbon/human/npc/ambient_npc/outpost/police) && !living_target.mind && !living_target.client)
		return FALSE
	if(living_target.mind || living_target.client)
		// Running off in the cuffs of an arrest this officer is on: stunned and taken hold of again (police_arrest.dm bolting())
		if(police.bolting_from(living_target, src))
			return TRUE
		if(police.in_custody(living_target))
			return FALSE
		// Down (crit, stamina crit, stunned): the cuffs are the arrest's job at every star, never a fight
		// (owner decision 37). Nobody goes back on alert over someone lying there; they are fought again once up.
		// Except where the zone finishes the downed at three stars and up (owner decision 39)
		if(police_suspect_down(living_target) && !police.finishes_downed(living_target, src))
			return FALSE
		var/level = force_for(living_target)
		if(level >= POLICE_FORCE_LETHAL)
			return TRUE
		if(level == POLICE_FORCE_STUN)
			return !HAS_TRAIT(living_target, TRAIT_RESTRAINED) || !police.arrest_on(living_target)
		// One star: noticed, watched and arrested, never fought (the force subtree holds)
		return level == POLICE_FORCE_ARREST && (!HAS_TRAIT(living_target, TRAIT_RESTRAINED) || !police.arrest_on(living_target))
	// Wildlife, by the rule the outpost turrets had
	if(isalien(living_target) || istype(living_target, /mob/living/basic/alien))
		return TRUE
	if(faction_check_atom(living_target))
		return FALSE
	if(HAS_TRAIT(living_target, TRAIT_OUTPOST_RESIDENT))
		return FALSE
	return is_hostile_creature(living_target)

/// How hard they go at `target`: a person or mech by warrant (a stun officer never past STUN), anything else to kill
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/force_for(atom/target)
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		var/best = POLICE_FORCE_NONE
		for(var/mob/living/occupant in mech.occupants)
			if(police_will_fight(occupant))
				best = max(best, force_for(occupant))
		return best
	var/mob/living/living_target = target
	if(isliving(living_target) && (living_target.mind || living_target.client))
		// Running off in its own arrest's cuffs: a stun, never more, at any stars (police_arrest.dm bolting())
		if(police?.bolting_from(living_target, src))
			return POLICE_FORCE_STUN
		var/level = police?.force_level(living_target, src) || POLICE_FORCE_NONE
		if(level >= POLICE_FORCE_LETHAL && police.role_of(src) == POLICE_ROLE_STUN)
			return POLICE_FORCE_STUN
		return level
	return POLICE_FORCE_LETHAL

/// Who aboard `target` this officer is fighting (highest force, then pilot), or `target` itself when not a mech
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_mech_suspect(atom/target)
	if(!ismecha(target))
		return target
	var/obj/vehicle/sealed/mecha/mech = target
	var/mob/living/best
	var/best_force = POLICE_FORCE_NONE
	for(var/mob/living/occupant in mech.occupants)
		if(!police_will_fight(occupant))
			continue
		var/level = force_for(occupant)
		if(isnull(best) || level > best_force)
			best = occupant
			best_force = level
	return best || bounty_ai_pilot_of(mech)

/// Whether `person` is down: in crit, or stunned or in stamina crit. Lying down by choice is not down.
/proc/police_suspect_down(mob/living/person)
	return person.stat != CONSCIOUS || HAS_TRAIT(person, TRAIT_CRITICAL_CONDITION) || HAS_TRAIT(person, TRAIT_INCAPACITATED)

/**
 * Owner decision 39: in a zone whose officers finish the downed (its profile's spares_downed is off: the red zone),
 * someone at lethal force (three stars and up, as `officer` knows it) who goes down is shot until dead, never
 * cuffed. Someone already in custody is not (force_level() is NONE for them). Everywhere else, and below three
 * stars, the downed are cuffed (decision 37).
 */
/datum/outpost_police/proc/finishes_downed(mob/living/target, mob/living/officer)
	if(!profile || profile.spares_downed || !isliving(target))
		return FALSE
	return force_level(target, officer) >= POLICE_FORCE_LETHAL

// =========================================================================
// ROLES (owner decision 37)
// =========================================================================

/mob/living/carbon/human/npc/ambient_npc/outpost/police
	/// At three stars and up: POLICE_ROLE_STUN (baton and disabler, takes the suspect alive) or POLICE_ROLE_LETHAL. Null
	/// below three stars, where everyone works by the warrant. Kept until the outpost's alert drops below three.
	var/police_role

/**
 * `officer`'s role, given on first need: the squad gets one stun officer in OUTPOST_POLICE_STUN_SHARE of its
 * members at the outpost's stars (at least one in a squad of two or more; a lone officer is lethal), counted over
 * the officers given a role.
 * A long gun is a lethal officer's.
 */
/datum/outpost_police/proc/role_of(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(officer.police_role)
		return officer.police_role
	// A zone that finishes the downed sends no stun officers: everyone is lethal (owner decision 39). Heavy weapons
	// officers are lethal too: their anti-armour weapon fires only at lethal force (police_units_heavy.dm)
	if((profile && !profile.spares_downed) || officer.unit_kind == POLICE_UNIT_ARMOUR)
		officer.police_role = POLICE_ROLE_LETHAL
		return officer.police_role
	var/squad = 1
	var/stun = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in officers)
		if(other == officer || !other.police_role || other.stat == DEAD || other.npc_exit)
			continue
		squad++
		if(other.police_role == POLICE_ROLE_STUN)
			stun++
	var/list/shares = OUTPOST_POLICE_STUN_SHARE
	var/stars = clamp(dispatch_active_level(), 3, 5)
	// A lone officer is a lethal one; from two up, at least one of them takes the suspect alive
	var/wanted = squad >= 2 ? max(1, floor(squad / shares[stars - 2] + 0.5)) : 0
	if(stun < wanted && !officer.get_longgun())
		officer.police_role = POLICE_ROLE_STUN
	else
		officer.police_role = POLICE_ROLE_LETHAL
	return officer.police_role

/// Everyone's role goes: the outpost is below three stars
/datum/outpost_police/proc/clear_roles()
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		officer.police_role = null

// =========================================================================
// FIRE DISCIPLINE
// =========================================================================

/// The tiles a shot from `start_turf` at `end_turf` crosses: the human NPC base's own line (human_npc_ai.dm)
/proc/outpost_police_shot_line(turf/start_turf, turf/end_turf)
	return human_npc_shot_path(start_turf, end_turf)

/// Whether this officer firing at `shot_force` would shoot `other` too, rather than hold fire for them
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_would_shoot(atom/other, shot_force)
	if(ismecha(other))
		var/obj/vehicle/sealed/mecha/mech = other
		var/any_alive = FALSE
		for(var/mob/living/occupant in mech.occupants)
			if(occupant.stat == DEAD)
				continue
			any_alive = TRUE
			if(!police_would_shoot(occupant, shot_force))
				return FALSE
		return any_alive
	if(!police_will_fight(other))
		return FALSE
	var/other_force = force_for(other)
	if(other_force < POLICE_FORCE_STUN)
		return FALSE
	// Given the order, or giving up: nobody shoots them, and nobody shoots through them at someone else
	var/mob/living/person = other
	if(isliving(person) && police_holds_fire(person))
		return FALSE
	if(shot_force >= POLICE_FORCE_LETHAL && other_force < POLICE_FORCE_LETHAL)
		return FALSE
	return TRUE

/**
 * Whoever stands in this officer's line of fire at `target` and is not someone they would shoot: anyone up
 * and living (shots pass over the lying), or aboard a mech in the way. `within` > 0 looks only that many tiles out.
 * Null if clear.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/bystander_in_line(atom/target, within = 0)
	var/turf/from = get_turf(src)
	var/turf/end_turf = get_turf(target)
	if(!from || !end_turf)
		return null
	var/shot_force = max(force, force_for(target))
	for(var/turf/line_turf as anything in outpost_police_shot_line(from, end_turf))
		if(line_turf == from || line_turf == end_turf)
			continue
		if(within && get_dist(from, line_turf) > within)
			continue
		for(var/mob/living/other in line_turf)
			if(other == target || other.stat == DEAD || other.body_position == LYING_DOWN)
				continue
			if(police_would_shoot(other, shot_force))
				continue
			return other
		for(var/obj/vehicle/sealed/mecha/mech in line_turf)
			if(mech == target || police_would_shoot(mech, shot_force))
				continue
			for(var/mob/living/occupant in mech.occupants)
				if(occupant != target && occupant.stat != DEAD && !police_would_shoot(occupant, shot_force))
					return occupant
	return null

/**
 * Abuse M11, once a second from dispatch: a person in the line of fire within 2 tiles of an officer firing to
 * kill, for OUTPOST_POLICE_BLOCK_TIME, resists; again each OUTPOST_POLICE_BLOCK_TIME they stay. Someone who cannot
 * move away (stunned, tied up, dragged, carried, logged off) never does (abuse SF2).
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/check_body_block()
	var/mob/living/blocker
	var/atom/target = ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(force == POLICE_FORCE_LETHAL && stat == CONSCIOUS && !QDELETED(target))
		blocker = bystander_in_line(target, 2)
		if(blocker && !blocker.mind)
			blocker = null
		// Abuse SF2: only someone who chose to stand there resists, never the stunned, the tied up, the dragged or the logged off
		if(blocker && (blocker.incapacitated || HAS_TRAIT(blocker, TRAIT_RESTRAINED) || blocker.pulledby || blocker.buckled || (blocker.mind.key && !blocker.client)))
			blocker = null
	if(!blocker)
		dispatch_block_ref = null
		dispatch_block_since = 0
		return
	if(dispatch_block_ref?.resolve() != blocker)
		dispatch_block_ref = WEAKREF(blocker)
		dispatch_block_since = world.time
		return
	if(world.time - dispatch_block_since >= OUTPOST_POLICE_BLOCK_TIME)
		dispatch_block_since = world.time
		police?.report_crime(blocker, OUTPOST_CRIME_RESIST, src)

// =========================================================================
// GIVING UP (two stars: force is for someone who fights or gets away)
// =========================================================================

/datum/outpost_police
	/// What the officers have seen of the people they may stun: the mind's weakref -> /datum/outpost_police_stance
	var/list/stances

/// What the officers have seen of someone they may stun, a moment ago
/datum/outpost_police_stance
	/// Where they stand: a step to the next tile is not walking off (pulling away from the cuffs, any step is)
	var/turf/spot
	/// world.time they were last seen further than that from it, or 0
	var/moved_at = 0
	/// world.time they last went for someone, fired a gun or had a weapon in their hands, or 0
	var/fought_at = 0
	/// world.time an officer last looked
	var/looked_at = 0
	/// Whether their arrest was going for the cuffs at that look
	var/cuffing = FALSE
	/// Whether they had pulled away from those cuffs by then (a step of their own since the cuffs came out)
	var/away = FALSE
	/// world.time an officer holding its fire last told them to stay where they are
	var/told_at = 0
	/// world.time someone else last shoved them (their arrest hears it: police_arrest.dm on_suspect_shoved()), or 0
	var/shoved_at = 0

/**
 * One look at `person`: where they are against where they stood, and whether their arrest has come to the cuffs.
 * Returns what is known of them. With nobody having looked for OUTPOST_POLICE_STANCE_STALE, where they are is where
 * they stand. The moment the cuffs come out the same holds, and what they did before is past: from then on it is
 * pulling away from the cuffs, a weapon or a blow that counts. tg's cuffing breaks on any step of theirs, so once
 * they have taken one from the cuffs every further tile counts: lying there shuffling a tile at a time would
 * otherwise keep the cuffs off for good with everyone else holding their fire.
 */
/datum/outpost_police/proc/stance_of(mob/living/person)
	var/datum/weakref/key = WEAKREF(person.mind)
	var/datum/outpost_police_stance/stance = LAZYACCESS(stances, key)
	if(!stance)
		stance = new
		LAZYSET(stances, key, stance)
	var/turf/here = get_turf(person)
	var/cuffing = arrest_cuffing(person)
	var/cuffs_out = cuffing && !stance.cuffing
	var/away = cuffing && arrest_pulled_away(person)
	if(isnull(stance.spot) || cuffs_out || world.time - stance.looked_at > OUTPOST_POLICE_STANCE_STALE)
		stance.spot = here
		stance.moved_at = 0
		if(cuffs_out)
			stance.fought_at = 0
	else if(here && here.z != stance.spot.z)
		// On another level: a lift carried them there (the public lift came back up with a suspect and the officer
		// cuffing them on it, and the officers at the top fired). Standing on a lift is no step of theirs.
		stance.spot = here
	else if(here && get_dist(here, stance.spot) > (away ? 0 : 1))
		stance.spot = here
		// Pulled along, by an officer or anyone else, they are going nowhere of their own (whoever pulls a suspect off
		// answers for it: police_arrest.dm check_interference()). And with the cuffs coming the arrest knows their own
		// steps exactly: until it has counted one, being somewhere else is being pushed, carried or traded places with.
		// Nor shoved along by someone else: a shove is an ordinary step to tg
		if(!person.pulledby && (!cuffing || away) && world.time - stance.shoved_at > 1 SECONDS)
			stance.moved_at = world.time
	// Their first step from the cuffs, wherever it left them
	if(away && !stance.away && !cuffs_out)
		stance.moved_at = world.time
	stance.cuffing = cuffing
	stance.away = away
	stance.looked_at = world.time
	return stance

/**
 * Whether `person` is giving up, as the officers see it: for OUTPOST_POLICE_YIELD_TIME they have stayed where they
 * are (a step to the next tile aside; with the cuffs coming, no step of their own at all), on their feet or on the
 * floor, with no gun or weapon in their hands, and gone for nobody. Someone first seen standing there is taken to
 * be. Hands up or fists up is the arresting officer's to judge (police_arrest.dm suspect_complied()); what everyone
 * else sees is whether they fight or get away.
 */
/datum/outpost_police/proc/gives_up(mob/living/person)
	if(!isliving(person) || !person.mind || person.stat == DEAD || !isturf(person.loc))
		return FALSE
	var/datum/outpost_police_stance/stance = stance_of(person)
	if(outpost_police_armed(person))
		stance.fought_at = world.time
	if(stance.fought_at && world.time - stance.fought_at < OUTPOST_POLICE_YIELD_TIME)
		return FALSE
	return !stance.moved_at || world.time - stance.moved_at >= OUTPOST_POLICE_YIELD_TIME

/// `person` went for someone, or fired a gun (police_wanted.dm report_crime(), seen or not): they have not given up
/datum/outpost_police/proc/note_fought(mob/living/person)
	if(!isliving(person) || !person.mind)
		return
	var/datum/outpost_police_stance/stance = stance_of(person)
	stance.fought_at = world.time

/// Someone else shoved `person`: the tile it moves them is not theirs to answer for
/datum/outpost_police/proc/note_shoved(mob/living/person)
	if(!isliving(person) || !person.mind)
		return
	var/datum/outpost_police_stance/stance = LAZYACCESS(stances, WEAKREF(person.mind))
	if(stance)
		stance.shoved_at = world.time

/// Whether `person` went for someone, fired a gun or was seen with a weapon out within the last `within`
/datum/outpost_police/proc/fought_within(mob/living/person, within)
	if(!isliving(person) || !person.mind)
		return FALSE
	var/datum/outpost_police_stance/stance = LAZYACCESS(stances, WEAKREF(person.mind))
	return !!stance?.fought_at && world.time - stance.fought_at <= within

/// Forgets what was seen of anyone nobody has looked at for OUTPOST_POLICE_STANCE_KEEP (once a second, police_stealth.dm stealth_tick_squad())
/datum/outpost_police/proc/prune_stances()
	if(!length(stances))
		return
	for(var/datum/weakref/key as anything in stances.Copy())
		var/datum/outpost_police_stance/stance = stances[key]
		if(!key.resolve() || world.time - max(stance.looked_at, stance.fought_at) > OUTPOST_POLICE_STANCE_KEEP)
			LAZYREMOVE(stances, key)

/// Whether `person` has a gun or a melee weapon in their hands
/proc/outpost_police_armed(mob/living/person)
	for(var/obj/item/held in person.held_items)
		if(isgun(held) || human_npc_is_melee_weapon(held))
			return TRUE
	return FALSE

/**
 * Whether this officer, at `level` on `target`, takes its baton to them rather than firing: stun force, no case of
 * its own (the arrest's officer has its own steps), and `target` an unarmed, uncuffed person on their feet beside it,
 * whom it may fight now (police_holds_fire()). A disabler every few seconds may never put down someone in armour or
 * on stimulants, and an officer who stands beside them firing plugs a one-tile lane for the rest of the squad
 * (Quartermain's checkpoint, pass 11 F); the baton is what tg's security officer would use from there.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_baton_reach(atom/target, level)
	if(level != POLICE_FORCE_STUN || case || HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) || LAZYLEN(do_afters))
		return FALSE
	var/mob/living/person = target
	if(!isliving(person) || person != police_mech_suspect(target) || person.stat != CONSCIOUS || person.body_position != STANDING_UP)
		return FALSE
	if(!isturf(person.loc) || !isturf(loc) || !Adjacent(person))
		return FALSE
	if(HAS_TRAIT(person, TRAIT_RESTRAINED) || outpost_police_armed(person) || police_holds_fire(person))
		return FALSE
	return outpost_police_baton_usable(get_baton())

/// Puts any gun away and takes the baton in hand, switched on. TRUE if it is ready.
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_take_baton()
	var/obj/item/baton = get_baton()
	var/obj/item/gun/energy/gun = get_sidearm()
	var/obj/item/gun/longgun = get_longgun()
	if(longgun && is_holding(longgun))
		police_put_away(longgun)
	if(!police_draw(baton, gun || longgun))
		return FALSE
	human_npc_ready_weapon(src, baton)
	force = POLICE_FORCE_STUN
	return is_holding(baton)

/**
 * Whether this officer holds its fire, and its baton, for `person`: someone of two stars (as it knows them) who has
 * been given an arrest's order and is in the time to comply, or who is giving up (gives_up()). At three stars and up
 * only someone down is taken alive (owner decision 37); at one star nobody is fought in the first place.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_holds_fire(mob/living/person)
	if(!police || !isliving(person) || !person.mind)
		return FALSE
	if(police.force_level(person, src) != POLICE_FORCE_STUN)
		return FALSE
	return police.order_pending(person) || police.gives_up(person)

/**
 * Holds its aim on `target` without firing: weapon out, facing them, within OUTPOST_POLICE_COVER_RANGE and in sight of
 * them. The first officer to do so before the arrest has spoken to them tells them to stay where they are.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_hold_aim(datum/ai_controller/controller, atom/target, mob/living/person)
	police_let_arrest_past(person)
	if(!HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) && !LAZYLEN(do_afters) && isturf(loc))
		face_atom(target)
	if(!case && !police.order_pending(person) && !police.arrest_cuffing(person))
		var/datum/outpost_police_stance/stance = police.stance_of(person)
		if((!stance.told_at || world.time - stance.told_at >= OUTPOST_POLICE_HOLD_LINE_GAP) && police_say(POLICE_LINE_WARN))
			stance.told_at = world.time
	if(get_dist(src, target) > OUTPOST_POLICE_COVER_RANGE || !can_see(src, target, OUTPOST_POLICE_COVER_RANGE))
		controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, OUTPOST_POLICE_COVER_RANGE)
	else
		controller.queue_behavior(/datum/ai_behavior/outpost_police_watch)

/mob/living/carbon/human/npc/ambient_npc/outpost/police
	/// Until when it does not trade places again to let an arresting officer past (police_let_arrest_past())
	COOLDOWN_DECLARE(police_let_past_cooldown)

/**
 * The officer making the arrest goes first. This one, standing beside it and between it and `person` (in a doorway,
 * at the mouth of a dead end: the only way in), trades places with it, tg's own swap. Standing still with its aim on
 * them it is otherwise walked round, and where there is no way round the cuffs never got there: the arresting
 * officer went round and round it (the Undertow's corner by the Exchange). TRUE if they traded.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_let_arrest_past(mob/living/person)
	if(!police || !isliving(person) || !person.mind || !isturf(loc) || !isturf(person.loc))
		return FALSE
	var/datum/outpost_police_case/their_case = police.cases[person.mind]
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/arresting = QDELETED(their_case) ? null : their_case.arresting()
	if(isnull(arresting) || arresting == src || arresting.stat != CONSCIOUS || !isturf(arresting.loc) || arresting.z != z || get_dist(src, arresting) > 1)
		return FALSE
	// Beside them already, cuffing them or walking them in: it is where it needs to be
	if(arresting.Adjacent(person) || arresting.pulling || LAZYLEN(arresting.do_afters) || LAZYLEN(do_afters))
		return FALSE
	if(!outpost_npc_can_make_room(src) || !(arresting.mobility_flags & MOBILITY_MOVE) || arresting.moving_diagonally || arresting.buckled)
		return FALSE
	// In its way: nearer to them than it is, or the tile its walk takes next, or what it last walked into
	var/in_the_way = get_dist(src, person) < get_dist(arresting, person)
	in_the_way ||= outpost_npc_next_step(arresting) == get_turf(src)
	in_the_way ||= arresting.bump_blocker?.resolve() == src && world.time - arresting.bump_last <= 1.5 SECONDS
	// Once: it does not trade with the same officer again for a while, or the two would go round each other
	if(!in_the_way || !COOLDOWN_FINISHED(src, police_swap_cooldown) || !COOLDOWN_FINISHED(src, police_let_past_cooldown))
		return FALSE
	// POLICE_SWAP_COOLDOWN (police_movement.dm, compiled after this file)
	COOLDOWN_START(src, police_swap_cooldown, 1 SECONDS)
	if(!pirate_crew_swap_places(arresting, src))
		return FALSE
	COOLDOWN_START(src, police_let_past_cooldown, 20 SECONDS)
	arresting.police_note_trade(src)
	return TRUE

// =========================================================================
// FORCE
// =========================================================================

/**
 * The weapon mode for the current target, then the shot with fire discipline. With nothing to fight the weapons go
 * away. A person of one star is the arrest's job: an officer with no case on them, baton out, stands and watches
 * (spec-stealth 1.3). A person of two stars who is doing as told is watched over its sights, never fired on
 * (police_holds_fire()). With no loaded gun it leaves the target to the base's arm and melee subtrees (the baton).
 */
/datum/ai_planning_subtree/outpost_police_force

/datum/ai_planning_subtree/outpost_police_force/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(officer) || !officer.police)
		return
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!isnull(target) && !officer.police_will_fight(target))
		controller.clear_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET)
		target = null
	if(isnull(target))
		if(officer.force != POLICE_FORCE_NONE && !officer.case && !officer.dispatch_responding())
			officer.set_force(POLICE_FORCE_NONE)
		return
	var/level = officer.force_for(target)
	// Within arm's reach of someone unarmed at stun force: the baton, not another disabler shot (police_baton_reach())
	if(officer.police_baton_reach(target, level) && officer.police_take_baton())
		controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/human_npc, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
		return SUBTREE_RETURN_FINISH_PLANNING
	officer.sync_force(level)
	if(level == POLICE_FORCE_ARREST && !officer.case)
		officer.police_let_arrest_past(officer.police_mech_suspect(target))
		if(!HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) && !LAZYLEN(officer.do_afters))
			officer.face_atom(target)
		controller.queue_behavior(/datum/ai_behavior/outpost_police_watch)
		return SUBTREE_RETURN_FINISH_PLANNING
	// Two stars and doing as told (in the time to comply with an arrest's order, or staying put with empty hands):
	// nobody fires on them or goes at them with a baton. The arresting officer has them; everyone else, the arrest's
	// cover included, keeps its aim on them from close by.
	var/mob/living/person = officer.police_mech_suspect(target)
	if(level == POLICE_FORCE_STUN && isliving(person) && officer.police_holds_fire(person))
		officer.police_hold_aim(controller, target, person)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(level < POLICE_FORCE_STUN || HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED) || LAZYLEN(officer.do_afters))
		return SUBTREE_RETURN_FINISH_PLANNING
	// Shut in a locker, crate or bag: stealth_closet opens one it saw them enter and holds fire on any other
	if(isliving(target) && stealth_closet_of(target))
		return
	var/obj/item/gun/ready_gun = officer.police_loaded_gun_for(level)
	if(isnull(ready_gun))
		// At stun force never fall through to human_npc_arm, which would draw a stowed lethal long gun; nor with a heavy
		// weapon that is not for this target (police_units_heavy.dm), which human_npc_arm would draw as a backup
		if(level == POLICE_FORCE_STUN || officer.police_heavy_barred(target))
			controller.queue_behavior(/datum/ai_behavior/basic_melee_attack/human_npc, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
			return SUBTREE_RETURN_FINISH_PLANNING
		return
	var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[BB_TARGETING_STRATEGY])
	var/fire_range = controller.blackboard[BB_HUMAN_NPC_FIRE_RANGE] || 7
	if(get_dist(officer, target) <= fire_range && strategy?.can_attack(officer, target, fire_range))
		// A locker, a crate or a vendor in the way: round it for a clear line, rather than shooting it
		if(officer.shot_obstacle(target))
			controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, 1)
			return SUBTREE_RETURN_FINISH_PLANNING
		var/keep_away = controller.blackboard[BB_HUMAN_NPC_KEEP_AWAY]
		if(keep_away && get_dist(officer, target) < keep_away)
			// Onto a free tile only, never back into a colleague (police_movement.dm)
			controller.queue_behavior(/datum/ai_behavior/outpost_police_step_back, BB_BASIC_MOB_CURRENT_TARGET)
		controller.queue_behavior(/datum/ai_behavior/human_npc_shoot/outpost_police, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY, BB_BASIC_MOB_CURRENT_TARGET_HIDING_LOCATION)
	else
		controller.queue_behavior(/datum/ai_behavior/human_npc_close_in, BB_BASIC_MOB_CURRENT_TARGET, fire_range)
	return SUBTREE_RETURN_FINISH_PLANNING

/// The base's shot, held while a bystander is in the line (abuse M10): a step aside instead
/datum/ai_behavior/human_npc_shoot/outpost_police

/datum/ai_behavior/human_npc_shoot/outpost_police/perform(seconds_per_tick, datum/ai_controller/controller, target_key, targeting_strategy_key, hiding_location_key)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	var/atom/target = controller.blackboard[target_key]
	if(!istype(officer) || QDELETED(target))
		return ..()
	if(isliving(target) && stealth_closet_of(target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	// Given the order, or given up, since this shot was planned: it is not taken
	var/mob/living/person = officer.police_mech_suspect(target)
	if(isliving(person) && officer.police_holds_fire(person))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	var/obj/item/gun/wanted_gun = officer.police_loaded_gun_for(officer.force)
	if(isnull(wanted_gun))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(officer.bystander_in_line(target))
		officer.police_reposition(target)
		return AI_BEHAVIOR_DELAY
	if(officer.shot_obstacle(target))
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	if(human_npc_loaded_gun(officer) != wanted_gun)
		var/datum/targeting_strategy/strategy = GET_TARGETING_STRATEGY(controller.blackboard[targeting_strategy_key])
		if(!strategy?.can_attack(officer, target))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		if(world.time < controller.blackboard[BB_HUMAN_NPC_NEXT_SHOT])
			return AI_BEHAVIOR_DELAY
		if(!human_npc_ready_item(officer, wanted_gun))
			return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
		officer.zone_selected = human_npc_pick_aim_zone()
		controller.ai_interact(target = target, combat_mode = TRUE)
		controller.set_blackboard_key(BB_HUMAN_NPC_NEXT_SHOT, world.time + (controller.blackboard[BB_HUMAN_NPC_SHOT_DELAY] || 3 SECONDS))
		return AI_BEHAVIOR_DELAY | AI_BEHAVIOR_SUCCEEDED
	return ..()

/**
 * Something solid on the line to `target` that a round would only hit: a wall, a locker, a crate, a vendor, a shut
 * door. Glass and grilles are left to the gun (a beam goes through them); rails, tables and anything a round passes
 * over are not in the way; people are bystander_in_line()'s.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/shot_obstacle(atom/target)
	var/turf/from = get_turf(src)
	var/turf/end_turf = get_turf(target)
	if(!from || !end_turf || from == end_turf)
		return null
	for(var/turf/line_turf as anything in outpost_police_shot_line(from, end_turf))
		if(line_turf == from || line_turf == end_turf)
			continue
		if(line_turf.density)
			return line_turf
		for(var/obj/thing in line_turf)
			if(!thing.density || thing == target || (thing.flags_1 & ON_BORDER_1) || (thing.pass_flags_self & PASSTABLE))
				continue
			if(istype(thing, /obj/structure/window) || istype(thing, /obj/structure/grille) || ismecha(thing))
				continue
			return thing
	return null

/// A bystander spoils this officer's shot at `target`: one step aside for a clear line (a heavy weapons officer may step back instead)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_reposition(atom/target)
	human_npc_sidestep(src, target)

/// Whether this officer carries a heavy weapon that is not for `target` (police_units_heavy.dm); nobody else does
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_heavy_barred(atom/target)
	return FALSE

/// Whether this officer has the working hands `gun` requires (two intact hands for WEAPON_HEAVY)
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_can_handle_gun(obj/item/gun/gun)
	if(QDELETED(gun))
		return FALSE
	var/working = 0
	for(var/i in 1 to length(held_items))
		if(has_hand_for_held_index(i))
			working++
	return working >= (gun.weapon_weight == WEAPON_HEAVY ? 2 : 1)

/// Whether `baton` can deliver a stun blow right now (a flat or EMP'd security stun baton would club with lethal brute)
/proc/outpost_police_baton_usable(obj/item/baton)
	if(QDELETED(baton))
		return FALSE
	var/obj/item/melee/baton/security/sec_baton = baton
	if(istype(sec_baton))
		return sec_baton.active || sec_baton.cell?.charge >= sec_baton.cell_hit_cost
	return TRUE

/// A held gun that may fire at `level` right now: stun energy mode at STUN, any killing gun at LETHAL, none below STUN
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_loaded_gun_for(level)
	if(level < POLICE_FORCE_STUN)
		return null
	if(level == POLICE_FORCE_STUN)
		for(var/obj/item/gun/energy/energy_gun in held_items)
			if(!outpost_police_mode_lethal(energy_gun) && police_can_handle_gun(energy_gun) && energy_gun.can_shoot())
				return energy_gun
		return null
	var/obj/item/gun/longgun = get_longgun()
	if(longgun && is_holding(longgun) && police_can_handle_gun(longgun) && (longgun.weapon_weight != WEAPON_HEAVY || get_num_held_items() == 1) && longgun.can_shoot())
		return longgun
	for(var/obj/item/gun/energy/energy_gun in held_items)
		if(outpost_police_mode_lethal(energy_gun) && police_can_handle_gun(energy_gun) && energy_gun.can_shoot())
			return energy_gun
	for(var/obj/item/gun/held_gun in held_items)
		if(!istype(held_gun, /obj/item/gun/energy) && police_can_handle_gun(held_gun) && (held_gun.weapon_weight != WEAPON_HEAVY || get_num_held_items() == 1) && held_gun.can_shoot())
			return held_gun
	return null

/// Keeps held weapons in line with `level`, falling back when a gun runs dry or stowing a rifle below LETHAL
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/sync_force(level)
	if(level != force)
		set_force(level)
		return
	if(HAS_TRAIT(src, TRAIT_HANDS_BLOCKED) || LAZYLEN(do_afters))
		return
	var/obj/item/baton = get_baton()
	var/obj/item/gun/energy/gun = get_sidearm()
	var/obj/item/gun/longgun = get_longgun()
	if(level < POLICE_FORCE_LETHAL && longgun && is_holding(longgun))
		police_put_away(longgun)
	switch(level)
		if(POLICE_FORCE_ARREST)
			if(baton && is_holding(baton))
				if(outpost_police_baton_usable(baton))
					human_npc_ready_weapon(src, baton)
				else
					police_put_away(baton)
			else if(outpost_police_baton_usable(baton))
				set_force(level)
		if(POLICE_FORCE_STUN)
			if(isnull(police_loaded_gun_for(level)))
				if(gun)
					outpost_police_set_gun_mode(gun, lethal = FALSE)
				if(gun && !outpost_police_mode_lethal(gun) && gun.can_shoot() && police_can_handle_gun(gun))
					set_force(level)
				else if(baton && is_holding(baton))
					if(outpost_police_baton_usable(baton))
						human_npc_ready_weapon(src, baton)
					else
						police_put_away(baton)
				else if(outpost_police_baton_usable(baton))
					set_force(level)
		if(POLICE_FORCE_LETHAL)
			if(isnull(police_loaded_gun_for(level)))
				var/retry_ok = world.time >= ai_controller?.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT]
				var/reloading_longgun = longgun && is_holding(longgun) && !longgun.can_shoot() && police_can_handle_gun(longgun) && human_npc_can_reload(src, longgun) && retry_ok
				if(reloading_longgun)
					return
				if(longgun && police_can_handle_gun(longgun) && (longgun.can_shoot() || (human_npc_can_reload(src, longgun) && retry_ok)))
					set_force(level)
					return
				if(gun)
					outpost_police_set_gun_mode(gun, lethal = TRUE)
				if(gun && outpost_police_mode_lethal(gun) && gun.can_shoot() && police_can_handle_gun(gun))
					set_force(level)
				else
					if(gun && is_holding(gun))
						police_put_away(gun)
					if(baton && !is_holding(baton))
						set_force(level)

/// Baton out at ARREST, gun on disable at STUN, gun on kill at LETHAL (POLICE_FORCE_*); all put away at NONE
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/set_force(level)
	force = level
	var/obj/item/baton = get_baton()
	var/obj/item/gun/energy/gun = get_sidearm()
	// The tactical officer's and the marshal's ballistic long gun (police_units.dm): theirs to kill with
	var/obj/item/gun/longgun = get_longgun()
	switch(level)
		if(POLICE_FORCE_ARREST)
			for(var/obj/item/firearm in list(longgun, gun))
				if(firearm && is_holding(firearm))
					police_put_away(firearm)
			if(outpost_police_baton_usable(baton) && police_draw(baton, longgun || gun))
				human_npc_ready_weapon(src, baton)
				var/obj/item/melee/baton/security/sec_baton = baton
				if(istype(sec_baton) && !sec_baton.active)
					police_put_away(sec_baton)
			else if(baton && is_holding(baton))
				police_put_away(baton)
		if(POLICE_FORCE_STUN)
			if(longgun && is_holding(longgun))
				police_put_away(longgun)
			if(gun)
				outpost_police_set_gun_mode(gun, lethal = FALSE)
			if(gun && !outpost_police_mode_lethal(gun) && gun.can_shoot() && police_can_handle_gun(gun))
				police_draw(gun, baton || longgun)
				if(baton && is_holding(baton))
					police_put_away(baton)
			else
				if(gun && is_holding(gun))
					police_put_away(gun)
				if(outpost_police_baton_usable(baton) && police_draw(baton, gun || longgun))
					human_npc_ready_weapon(src, baton)
					var/obj/item/melee/baton/security/sec_baton = baton
					if(istype(sec_baton) && !sec_baton.active)
						police_put_away(sec_baton)
				else if(baton && is_holding(baton))
					police_put_away(baton)
		if(POLICE_FORCE_LETHAL)
			var/retry_ok = world.time >= ai_controller?.blackboard[BB_HUMAN_NPC_ARMING_RETRY_AT]
			if(longgun && police_can_handle_gun(longgun) && (longgun.can_shoot() || (human_npc_can_reload(src, longgun) && retry_ok)))
				police_draw(longgun, gun || baton)
				for(var/obj/item/sidearm in list(gun, baton))
					if(sidearm && is_holding(sidearm))
						police_put_away(sidearm)
				if(longgun.weapon_weight == WEAPON_HEAVY && get_num_held_items() > 1)
					put_away_prop()
					for(var/obj/item/other in held_items)
						if(other == longgun)
							continue
						if(HAS_TRAIT(other, TRAIT_AMBIENT_PROP))
							qdel(other)
						else if(!police_put_away(other) && (istype(other, /obj/item/ammo_box) || isammocasing(other)))
							dropItemToGround(other, force = TRUE)
			else
				if(longgun && is_holding(longgun))
					police_put_away(longgun)
				if(gun)
					outpost_police_set_gun_mode(gun, lethal = TRUE)
				if(gun && outpost_police_mode_lethal(gun) && gun.can_shoot() && police_can_handle_gun(gun))
					police_draw(gun, baton || longgun)
					if(baton && is_holding(baton))
						police_put_away(baton)
				else
					if(gun && is_holding(gun))
						police_put_away(gun)
					if(baton && police_draw(baton, gun || longgun) && outpost_police_baton_usable(baton))
						human_npc_ready_weapon(src, baton)
		else
			for(var/obj/item/weapon in list(longgun, gun, baton))
				if(weapon && is_holding(weapon))
					police_put_away(weapon)

/**
 * Takes `weapon` in hand, making room first: a routine's prop goes, then `stow` (the other weapon) goes back on
 * the belt. Returns TRUE if it is in hand.
 */
/mob/living/carbon/human/npc/ambient_npc/outpost/police/proc/police_draw(obj/item/weapon, obj/item/stow)
	if(QDELETED(weapon))
		return FALSE
	if(is_holding(weapon))
		return TRUE
	if(!police_empty_hand())
		put_away_prop()
	if(!police_empty_hand() && stow && is_holding(stow))
		police_put_away(stow)
	if(!police_empty_hand())
		for(var/obj/item/held in held_items)
			if(held == weapon || held == stow)
				continue
			if(HAS_TRAIT(held, TRAIT_AMBIENT_PROP))
				qdel(held)
			else
				police_put_away(held)
			break
	var/hand = police_empty_hand()
	if(!hand)
		return FALSE
	swap_hand(hand, silent = TRUE)
	return human_npc_take_in_hand(src, weapon)

/// Switches `gun` with its own select_fire() to its first disabling (`lethal` FALSE) or killing mode
/proc/outpost_police_set_gun_mode(obj/item/gun/energy/gun, lethal)
	if(!istype(gun) || length(gun.ammo_type) < 2)
		return
	for(var/i in 1 to length(gun.ammo_type))
		if(outpost_police_mode_lethal(gun) == lethal)
			return
		gun.select_fire(null)

/// Whether `gun`'s selected mode kills (brute or burn) rather than disables (stamina)
/proc/outpost_police_mode_lethal(obj/item/gun/energy/gun)
	var/obj/item/ammo_casing/energy/shot = gun.ammo_type[gun.select]
	var/obj/projectile/projectile_type = ispath(shot) ? initial(shot.projectile_type) : shot.projectile_type
	if(!ispath(projectile_type, /obj/projectile))
		return FALSE
	return initial(projectile_type.damage_type) != STAMINA && initial(projectile_type.damage) > 0

/// Stands and keeps its eyes on its target: a one-star suspect it has no case on
/datum/ai_behavior/outpost_police_watch
	action_cooldown = 1 SECONDS
	behavior_flags = AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/outpost_police_watch/perform(seconds_per_tick, datum/ai_controller/controller)
	var/mob/living/officer = controller.pawn
	var/atom/target = controller.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(!QDELETED(target) && officer.stat == CONSCIOUS && isturf(officer.loc) && !HAS_TRAIT(officer, TRAIT_HANDS_BLOCKED))
		officer.face_atom(target)
	return AI_BEHAVIOR_DELAY
