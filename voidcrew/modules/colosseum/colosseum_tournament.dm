/**
 * # Colosseum Tournament
 *
 * Successive-elimination free-for-all: each round runs on the open sand until
 * the round's cut quota has fallen, then the wardens close the gates, carry
 * the cut fighters (alive ones) out through the infirmary to spectate, sweep
 * and reset the arena, reseat the survivors and pop the gates again. The last
 * fighter standing takes a doubled prize pool, paid out at tournament end.
 *
 * The cut table is configurable via cut_fractions: entry i is the fraction of
 * the round-i field that must fall to end that round (minimum 1). Once the
 * field is at or below final_size, the last round runs to a single survivor.
 * Example, 10 fighters with the default table: round 1 cuts 2, round 2 cuts 4
 * of the remaining 8, then 4 fight the final.
 */
/datum/colosseum_game/tournament
	name = "Tournament"
	desc = "Rounds of elimination. Survive the cuts, win the final."
	min_players = 6
	max_players = 16
	weight = 6
	team_based = FALSE
	time_limit = 8 MINUTES // per round; re-armed at each round start
	reward_multiplier = 2
	arena_events = TRUE
	/// Fraction of the field cut per round (indexed by round, clamped to last)
	var/list/cut_fractions = list(0.2, 0.5)
	/// Field size at or below which the next round is the final
	var/final_size = 4
	/// Current round (1-based)
	var/round_number = 1
	/// Eliminations still needed to end the current round (0 in the final)
	var/cut_remaining = 0
	/// TRUE while the wardens are turning the arena around between rounds
	var/intermission = FALSE

/datum/colosseum_game/tournament/on_match_start()
	round_number = 1
	begin_round()

/// Arms the current round: computes its cut quota and re-arms the round clock.
/datum/colosseum_game/tournament/proc/begin_round()
	intermission = FALSE
	var/field = length(controller.live_entries())
	if(field <= final_size)
		cut_remaining = 0 // the final: fight until one remains
		controller.site.venue_message(span_boldannounce("THE FINAL! [field] fighters remain. Last one standing takes it all!"))
	else
		var/fraction = cut_fractions[min(round_number, length(cut_fractions))]
		cut_remaining = max(1, round(field * fraction))
		controller.site.venue_message(span_boldannounce("Round [round_number]: [field] fighters. The round ends when [cut_remaining] have fallen!"))
	controller.restart_match_timer(time_limit)

/datum/colosseum_game/tournament/on_elimination(datum/colosseum_contestant/entry)
	if(intermission || !cut_remaining)
		return // final-round eliminations ride the default victory check
	cut_remaining--
	if(cut_remaining > 0)
		return
	// Quota met: defer the turnaround out of the death-signal stack.
	intermission = TRUE
	addtimer(CALLBACK(src, PROC_REF(end_round)), 1 SECONDS, TIMER_UNIQUE)

/// Round over: gates shut, cut fighters released to spectate, arena turned around.
/datum/colosseum_game/tournament/proc/end_round()
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	var/obj/structure/overmap/colosseum/site = controller.site
	site.set_gates(COLOSSEUM_GATE_SOLO, FALSE)
	site.set_gates(COLOSSEUM_GATE_RED, FALSE)
	site.set_gates(COLOSSEUM_GATE_BLUE, FALSE)

	// Cut-but-breathing fighters leave through the infirmary to spectate
	var/list/infirmary = site.get_infirmary_turfs()
	for(var/datum/colosseum_contestant/entry as anything in controller.roster)
		if(!entry.eliminated || !isliving(entry.body) || entry.body.stat == DEAD)
			continue
		if(!istype(get_area(entry.body), /area/voidcrew/colosseum/arena) && !istype(get_area(entry.body), /area/voidcrew/colosseum/staging))
			continue
		if(length(infirmary))
			entry.body.forceMove(pick(infirmary))
			to_chat(entry.body, span_notice("Cut from the bracket. The wardens walk you out through the infirmary. Enjoy the stands."))

	// Survivors leave the sand FIRST: reseating them into their cells before
	// the sweep means the wardens never mistake a live fighter for a straggler
	// (being carried off the floor mid-LIVE would trip the area-departure
	// forfeit and eliminate the whole field).
	mode_reseat()
	controller.sweep_arena()
	controller.reset_arena()

	var/survivors = length(controller.live_entries())
	site.venue_message(span_boldannounce("Round [round_number] is over, [survivors] advance. The next round begins in [COLOSSEUM_TOURNAMENT_INTERMISSION / 10] seconds."))
	round_number++
	addtimer(CALLBACK(src, PROC_REF(next_round)), COLOSSEUM_TOURNAMENT_INTERMISSION, TIMER_UNIQUE)

/// Reseats the survivors into the cells (staging seals stay shut throughout).
/datum/colosseum_game/tournament/proc/mode_reseat()
	seat_contestants()

/// Intermission over: re-arm the round and pop the gates again.
/datum/colosseum_game/tournament/proc/next_round()
	if(QDELETED(src) || !controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	begin_round()
	for(var/gate_id in get_gate_ids())
		controller.site.set_gates(gate_id, TRUE)

/**
 * Round clock expiry with the quota unmet: the judges cut the stragglers at
 * random until the quota is met (the eliminate chain then runs end_round).
 * In the final, the clock falling silent hands victory to all survivors.
 */
/datum/colosseum_game/tournament/on_time_expiry()
	if(intermission)
		controller.restart_match_timer(time_limit) // clock rolled over mid-turnaround; re-arm
		return TRUE
	if(!cut_remaining)
		return FALSE // the final: controller resolves with expiry_winners()
	controller.site.venue_message(span_boldannounce("Time! The judges make their cuts."))
	while(cut_remaining > 0)
		var/list/live = controller.live_entries()
		if(length(live) <= 1)
			break
		var/datum/colosseum_contestant/victim = pick(live)
		controller.eliminate(victim, COLOSSEUM_ELIM_CUT)
	return TRUE

/// Final-round expiry: the survivors split the honors.
/datum/colosseum_game/tournament/expiry_winners()
	var/list/minds = list()
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		minds += entry.mind
	return minds
