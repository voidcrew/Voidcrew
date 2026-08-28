/**
 * # Colosseum game modes
 *
 * /datum/colosseum_game defines one way to fight: eligibility bounds, team
 * structure, staging assignment, which gates open, the win condition and the
 * time-limit resolution. The controller instantiates one at roster lock
 * (weighted random among modes eligible for the signup count) and consults it
 * through the hooks below.
 *
 * A mode with a null name is abstract and never picked.
 */
/datum/colosseum_game
	/// Display name. Null marks an abstract base that mode selection skips.
	var/name
	var/desc
	/// Roster-size eligibility bounds
	var/min_players = 2
	var/max_players = 16
	/// Selection weight among eligible modes
	var/weight = 10
	/// Whether contestants fight as red/blue teams (assigned per-ship)
	var/team_based = FALSE
	/// Match clock; 0 falls back to COLOSSEUM_DEFAULT_TIME_LIMIT
	var/time_limit = COLOSSEUM_DEFAULT_TIME_LIMIT
	/// Prize pool scale factor
	var/reward_multiplier = 1
	/// Whether the dynamic arena event scheduler runs during this mode
	/// (crate drops, hazards, pop-up cover, see colosseum_arena_events.dm)
	var/arena_events = FALSE
	/// Back-reference, set by the controller at roster lock
	var/datum/colosseum_controller/controller

/datum/colosseum_game/Destroy()
	controller = null
	return ..()

/// Which gate ids pop when the match goes live.
/datum/colosseum_game/proc/get_gate_ids()
	if(team_based)
		return list(COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE)
	return list(COLOSSEUM_GATE_SOLO, COLOSSEUM_GATE_RED, COLOSSEUM_GATE_BLUE)

/**
 * Team assignment at roster lock. Team modes keep shipmates together:
 * contestants are grouped by crew team and whole groups are dealt to the
 * smaller team, largest group first. Unaffiliated contestants are each their
 * own group (keyed by their own entry, grouping them by the shared
 * "Unaffiliated" ship NAME would deal every random to one side as a block).
 * Solo modes leave everyone COLOSSEUM_TEAM_SOLO.
 */
/datum/colosseum_game/proc/assign_teams(list/datum/colosseum_contestant/entries)
	if(!team_based)
		for(var/datum/colosseum_contestant/entry as anything in entries)
			entry.team = COLOSSEUM_TEAM_SOLO
		return
	var/list/by_ship = list()
	for(var/datum/colosseum_contestant/entry as anything in entries)
		LAZYADDASSOCLIST(by_ship, entry.crew_team || entry, entry)
	// Largest crews first so the balancer has room to even things out
	var/list/groups = list()
	for(var/group_key in by_ship)
		groups += list(by_ship[group_key])
	sortTim(groups, GLOBAL_PROC_REF(cmp_colosseum_group_desc))
	var/red_count = 0
	var/blue_count = 0
	for(var/list/group as anything in groups)
		var/team = (red_count <= blue_count) ? COLOSSEUM_TEAM_RED : COLOSSEUM_TEAM_BLUE
		for(var/datum/colosseum_contestant/entry as anything in group)
			entry.team = team
		if(team == COLOSSEUM_TEAM_RED)
			red_count += length(group)
		else
			blue_count += length(group)

/proc/cmp_colosseum_group_desc(list/a, list/b)
	return length(b) - length(a)

// ===== SEATING =====

/// Landmark-marked spots of the given type, with DESIGN.md coordinate fallbacks.
/datum/colosseum_game/proc/get_spots(landmark_type, list/fallback_coords)
	var/list/spots = controller.site.get_landmark_turfs(landmark_type)
	if(length(spots))
		return spots
	spots = list()
	for(var/list/xy as anything in fallback_coords)
		var/turf/spot = controller.site.local_turf(xy[1], xy[2])
		if(spot)
			spots += spot
	return spots

/// The six solo-cell seats (one per cell, in front of each solo gate).
/datum/colosseum_game/proc/cell_spots()
	return get_spots(/obj/effect/landmark/colosseum/spawn_cell, list(list(19, 49), list(23, 49), list(27, 49), list(36, 49), list(40, 49), list(44, 49)))

/// Red ready-room seats, nearest the gate first.
/datum/colosseum_game/proc/red_spots()
	return get_spots(/obj/effect/landmark/colosseum/spawn_red, list(list(15, 32), list(15, 33), list(14, 32), list(14, 33), list(13, 32), list(13, 33), list(12, 32), list(12, 33)))

/// Blue ready-room seats, nearest the gate first.
/datum/colosseum_game/proc/blue_spots()
	return get_spots(/obj/effect/landmark/colosseum/spawn_blue, list(list(48, 32), list(48, 33), list(49, 32), list(49, 33), list(50, 32), list(50, 33), list(51, 32), list(51, 33)))

/**
 * Moves every live contestant to their assigned staging position (the staging
 * areas are NOTELEPORT: explicit forceMove is the sanctioned way to seat).
 * Teams fill their ready rooms; solos fill the six cells and overflow into the
 * ready rooms (all three gate sets open for solo modes).
 */
/datum/colosseum_game/proc/seat_contestants()
	var/list/entries = controller.live_entries()
	if(team_based)
		var/list/red = red_spots()
		var/list/blue = blue_spots()
		var/red_i = 0
		var/blue_i = 0
		for(var/datum/colosseum_contestant/entry as anything in entries)
			if(entry.team == COLOSSEUM_TEAM_RED && length(red))
				red_i++
				seat_entry(entry, red[((red_i - 1) % length(red)) + 1])
			else if(length(blue))
				blue_i++
				seat_entry(entry, blue[((blue_i - 1) % length(blue)) + 1])
		return
	var/list/cells = cell_spots()
	var/list/overflow = red_spots() + blue_spots()
	for(var/i in 1 to length(entries))
		var/datum/colosseum_contestant/entry = entries[i]
		if(i <= length(cells))
			seat_entry(entry, cells[i])
		else if(length(overflow))
			seat_entry(entry, overflow[((i - length(cells) - 1) % length(overflow)) + 1])

/datum/colosseum_game/proc/seat_entry(datum/colosseum_contestant/entry, turf/spot)
	if(!isliving(entry.body) || !spot)
		return
	entry.body.forceMove(spot)
	to_chat(entry.body, span_boldnotice("You're seated for the [name]. [desc] When the gate opens, fight!"))

// ===== MATCH HOOKS =====

/// Called when the gates pop (LIVE). Modes start clocks, spawn flags, etc.
/datum/colosseum_game/proc/on_match_start()
	return

/// Called after each elimination during LIVE, before check_victory().
/datum/colosseum_game/proc/on_elimination(datum/colosseum_contestant/entry)
	return

/**
 * Victory test, called after every elimination (and at LIVE start).
 * Return null while undecided; a list of winning minds to resolve (an empty
 * list resolves as a draw).
 */
/datum/colosseum_game/proc/check_victory()
	var/list/live = controller.live_entries()
	if(team_based)
		var/team_seen
		for(var/datum/colosseum_contestant/entry as anything in live)
			if(isnull(team_seen))
				team_seen = entry.team
			else if(entry.team != team_seen)
				return null // both teams still standing
		return live_team_minds(team_seen)
	if(length(live) > 1)
		return null
	if(length(live) == 1)
		var/datum/colosseum_contestant/last = live[1]
		return list(last.mind)
	return list() // mutual destruction

/// The surviving minds of one team (used when that team wins).
/datum/colosseum_game/proc/live_team_minds(team)
	var/list/minds = list()
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		if(entry.team == team)
			minds += entry.mind
	return minds

/**
 * Time-limit hook. Return TRUE if the mode consumed the expiry itself
 * (tournaments cut and continue); FALSE to let the controller resolve with
 * expiry_winners().
 */
/datum/colosseum_game/proc/on_time_expiry()
	return FALSE

/// Winners when the clock runs out (empty list = draw).
/datum/colosseum_game/proc/expiry_winners()
	return list()

/// Called once at resolution, before announcements. Cleanup (flags, clocks).
/datum/colosseum_game/proc/on_match_end()
	return

/// One-line stakes description for the roster-lock announcement.
/datum/colosseum_game/proc/stakes_text(contestant_count)
	var/list/tier = controller.get_prize_tier(contestant_count)
	var/list/parts_text = list("[tier[1] * reward_multiplier] ship part\s in champion's cases")
	if(tier[2])
		parts_text += "[round(tier[2] * reward_multiplier)] credits"
	if(tier[3])
		parts_text += "[round(tier[3] * reward_multiplier)] trade voucher\s"
	return "[english_list(parts_text)], split between the winners, plus everything that falls on the sand"

// ===== FREE-FOR-ALL DEATHMATCH =====

/**
 * The classic: solo cells, every gate opens, last fighter standing takes the
 * purse. Clock expiry is a draw. Hiding out the timer pays nobody.
 */
/datum/colosseum_game/deathmatch
	name = "Free-for-All Deathmatch"
	desc = "Every fighter for themselves. Last one standing wins."
	min_players = 2
	max_players = 12
	weight = 20
	team_based = FALSE
	arena_events = TRUE

// ===== TEAM DEATHMATCH =====

/**
 * Red vs blue from the team ready rooms, shipmates kept together. Wipe the
 * other team. Clock expiry goes to the team with more fighters standing.
 */
/datum/colosseum_game/team_deathmatch
	name = "Team Deathmatch"
	desc = "Two teams enter from opposing gates. One team leaves."
	min_players = 4
	max_players = 16
	weight = 15
	team_based = TRUE
	arena_events = TRUE

/datum/colosseum_game/team_deathmatch/expiry_winners()
	var/red_alive = length(live_team_minds(COLOSSEUM_TEAM_RED))
	var/blue_alive = length(live_team_minds(COLOSSEUM_TEAM_BLUE))
	if(red_alive == blue_alive)
		return list() // dead-even at the bell: draw
	return live_team_minds(red_alive > blue_alive ? COLOSSEUM_TEAM_RED : COLOSSEUM_TEAM_BLUE)

// ===== KING OF THE HILL =====

/// Cumulative uncontested seconds on the dais needed to win.
#define KOTH_HOLD_REQUIRED 60

/**
 * Hold the self-lit dais at arena center. Standing on it alone accrues hold
 * time; sharing it with a rival accrues nothing for anyone. First fighter to
 * KOTH_HOLD_REQUIRED cumulative seconds wins. The only mode that needs a
 * clock, so it opts into SSprocessing for the LIVE phase only.
 */
/datum/colosseum_game/king_of_the_hill
	name = "King of the Hill"
	desc = "Hold the central dais, alone, longer than anyone else."
	min_players = 2
	max_players = 8
	weight = 10
	team_based = FALSE
	time_limit = 8 MINUTES
	/// Cumulative uncontested dais seconds per contestant (mind -> seconds)
	var/list/hold_seconds = list()
	/// Cached dais turfs, resolved at match start
	var/list/turf/dais_turfs
	/// Progress thresholds already announced (mind -> last announced quarter)
	var/list/announced_quarter = list()
	/// Whether we've already called out the current contested standoff
	var/contested_announced = FALSE

/datum/colosseum_game/king_of_the_hill/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/// The dais: mapped koth landmarks, else the lit ring around arena center per DESIGN.md.
/datum/colosseum_game/king_of_the_hill/proc/resolve_dais()
	var/list/fallback = list()
	for(var/x in 30 to 33)
		for(var/y in 31 to 34)
			fallback += list(list(x, y))
	dais_turfs = get_spots(/obj/effect/landmark/colosseum/koth, fallback)

/datum/colosseum_game/king_of_the_hill/on_match_start()
	resolve_dais()
	hold_seconds = list()
	announced_quarter = list()
	START_PROCESSING(SSprocessing, src)

/datum/colosseum_game/king_of_the_hill/on_match_end()
	STOP_PROCESSING(SSprocessing, src)

/datum/colosseum_game/king_of_the_hill/process(seconds_per_tick)
	if(!controller || controller.state != COLOSSEUM_STATE_LIVE)
		return
	var/datum/colosseum_contestant/holder
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		if(!isliving(entry.body) || IS_UNCONSCIOUS_OR_CRIT(entry.body))
			continue
		if(!(get_turf(entry.body) in dais_turfs))
			continue
		if(holder) // contested, nobody accrues
			if(!contested_announced)
				contested_announced = TRUE
				controller.site.venue_message(span_notice("The dais is CONTESTED - nobody gains time!"))
			return
		holder = entry
	if(!holder)
		contested_announced = FALSE
		return
	contested_announced = FALSE
	var/total = (hold_seconds[holder.mind] || 0) + seconds_per_tick
	hold_seconds[holder.mind] = total
	if(total >= KOTH_HOLD_REQUIRED)
		controller.resolve(list(holder.mind))
		return
	var/quarter = round((total / KOTH_HOLD_REQUIRED) * 4)
	if(quarter > (announced_quarter[holder.mind] || 0))
		announced_quarter[holder.mind] = quarter
		controller.site.venue_message(span_boldannounce("[holder.display_name] holds the dais: [round(total)]/[KOTH_HOLD_REQUIRED] seconds!"))

/// Clock expiry: longest total hold takes it; a tie (or nobody ever holding) is a draw.
/datum/colosseum_game/king_of_the_hill/expiry_winners()
	var/best = 0
	var/datum/mind/leader
	var/tied = FALSE
	for(var/datum/colosseum_contestant/entry as anything in controller.live_entries())
		var/held = hold_seconds[entry.mind] || 0
		if(held > best)
			best = held
			leader = entry.mind
			tied = FALSE
		else if(held == best && best > 0)
			tied = TRUE
	if(!leader || tied)
		return list()
	return list(leader)

#undef KOTH_HOLD_REQUIRED
