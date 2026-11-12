/**
 * # Chrome finishers: #509's finisher engine for a player's bare hands
 *
 * #509's /datum/hv_finisher was built for bosses with a weapon in hand and NPC factions. A chrome
 * finisher (a player's or a boss's own arms) changes four things, and nothing else:
 * - No weapon needed: the start and the safety check never ask for one.
 * - Anyone can be finished, as with a gun execution: two players share a faction, so the faction test
 *   only stops an NPC finishing its own side. Players and boss-rank NPCs only (hv_can_execute()).
 * - Down means in crit or stunned, never just lying there. A victim whose stun wears off before the
 *   kill twists free.
 * - No red mark over the victim (owner D34): the wind-up is the two bodies.
 * - The one doing it can't walk away mid-way: any step lets go.
 *
 * Kept in its own file so the other chrome finishers (Mantis, monowire) can share it.
 */

/mob/living
	/// The chrome finisher this mob is doing now, if any.
	var/datum/hv_finisher/chrome/chrome_finisher

/datum/hv_finisher/chrome
	name = "chrome finisher"
	interrupt_damage = GORILLA_FINISHER_INTERRUPT
	/// Set when the victim came out of their stun before the kill
	var/twisted_free = FALSE

/datum/hv_finisher/chrome/Destroy()
	if(user?.chrome_finisher == src)
		user.chrome_finisher = null
	return ..()

/datum/hv_finisher/chrome/start()
	. = ..()
	if(. && user)
		user.chrome_finisher = src

/datum/hv_finisher/chrome/can_start()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED) || HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return FALSE
	if(HAS_TRAIT(user, TRAIT_PACIFISM) || !user_may_finish())
		return FALSE
	if(user.chrome_finisher && user.chrome_finisher != src)
		return FALSE
	if(!chrome_finisher_valid_victim(user, victim))
		return FALSE
	return get_dist(user, victim) <= 1 && user.Adjacent(victim)

/// Who may do this finisher at all. Players and boss-rank NPCs, as with gun executions; a chrome line can route
/// this through its own gate.
/datum/hv_finisher/chrome/proc/user_may_finish()
	return user.hv_can_execute()

/datum/hv_finisher/chrome/safety_check()
	if(QDELETED(user) || user.stat != CONSCIOUS || HAS_TRAIT(user, TRAIT_INCAPACITATED))
		return HV_FINISHER_ATTACKER_DOWN
	if(QDELETED(victim))
		return HV_FINISHER_VICTIM_GONE
	if(!completed && victim.stat == DEAD)
		return HV_FINISHER_VICTIM_GONE
	if(!isturf(user.loc) || !isturf(victim.loc) || user.z != victim.z || get_dist(user, victim) > 1)
		return HV_FINISHER_LOST_GRIP
	if(!victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return HV_FINISHER_LOST_GRIP
	if(completed)
		return 0
	if(HAS_TRAIT(user, TRAIT_HANDS_BLOCKED))
		return HV_FINISHER_ATTACKER_DOWN
	if(gripped && (user.pulling != victim || user.grab_state < GRAB_AGGRESSIVE))
		return HV_FINISHER_LOST_GRIP
	if(!chrome_finisher_is_down(victim))
		twisted_free = TRUE
		return HV_FINISHER_LOST_GRIP
	return 0

// The one doing it takes a step, is shoved or is thrown: it lets go. The victim moving is #509's rule.
/datum/hv_finisher/chrome/on_moved(datum/source)
	SIGNAL_HANDLER
	if(source == user && running)
		end_early(HV_FINISHER_LOST_GRIP)
		return
	return ..()

/datum/hv_finisher/chrome/interrupt(reason)
	if(running && !completed && reason == HV_FINISHER_LOST_GRIP && twisted_free && !QDELETED(victim) && !QDELETED(user))
		for(var/datum/hv_finisher_stage/stage as anything in stages)
			if(stage.entered)
				stage.on_interrupt()
		victim.visible_message(span_danger("[victim] twists free of [user]'s grip!"), span_userdanger("You twist free of [user]'s grip!"))
		stop(reason)
		return
	return ..()

/datum/hv_finisher/chrome/stop(reason)
	if(!running)
		return
	. = ..()
	if(user?.chrome_finisher == src)
		user.chrome_finisher = null
	// Nothing owns a chrome finisher but its own timers, and its stages point back at it: it has to delete
	// itself once it is over, or the pair would hold both bodies forever.
	if(!QDELETED(src))
		qdel(src)

/**
 * Whether [user] may start a chrome finisher on [victim]: a humanoid body that is alive, in crit or
 * stunned, on the floor beside them, not strapped to anything and not already being finished. A player
 * can finish anyone, as with a gun execution; an NPC never finishes its own side.
 */
/proc/chrome_finisher_valid_victim(mob/living/user, mob/living/carbon/victim)
	if(!iscarbon(victim) || !isliving(user) || QDELETED(victim) || QDELETED(user) || victim == user)
		return FALSE
	if(!ishuman(victim) && !(victim.mob_biotypes & MOB_HUMANOID))
		return FALSE
	if(victim.stat == DEAD || HAS_TRAIT(victim, TRAIT_GODMODE))
		return FALSE
	if(!chrome_finisher_is_down(victim))
		return FALSE
	if(victim.has_status_effect(/datum/status_effect/hv_finisher_hold))
		return FALSE
	if(victim.buckled || !isturf(victim.loc) || !isturf(user.loc) || victim.z != user.z)
		return FALSE
	// An NPC (anything run by an AI) never finishes its own side
	if(user.ai_controller && user.faction_check_atom(victim))
		return FALSE
	return TRUE

/// Down, for a chrome finisher: in crit, or stunned. Lying there isn't enough.
/proc/chrome_finisher_is_down(mob/living/victim)
	return victim.stat >= SOFT_CRIT || HAS_TRAIT(victim, TRAIT_INCAPACITATED)

/**
 * Whether [victim] is square on to [user]: straight north, south, east or west, never on a corner. The
 * Gorilla finishers and the Mantis scissor draw both bodies along one straight line, so they only start
 * square on; from a corner the click is an ordinary blow and the bearer steps round to finish.
 */
/proc/finisher_square_on(atom/user, atom/victim)
	return (get_dir(user, victim) in GLOB.cardinals)

/// Whether [victim] has ended up on a corner from [user] mid-move: dragged there or the like. The rigs above
/// can't draw that, so it lets go. The same tile is fine (the clap brings the body in).
/proc/finisher_on_corner(atom/user, atom/victim)
	return (get_dir(user, victim) in GLOB.diagonals)
