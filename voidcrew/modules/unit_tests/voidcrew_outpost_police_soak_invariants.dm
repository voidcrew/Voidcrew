/**
 * Outpost police soak: the invariants. The harness is in voidcrew_outpost_police_soak.dm.
 *
 * Each subtype of /datum/police_soak_invariant is one thing that must never be seen at an outpost. check() runs
 * once a second on every run; it asks the run how long a condition has held (run.held(key, condition)) and reports
 * a break with run.breach(). To add one, add a subtype: nothing else lists them.
 *
 * Every threshold is a var with a comment saying what it stands for. Fork defines are included after the tests, so
 * stealth states are written out: "unaware", "suspicious", "alert", "searching" (STEALTH_*).
 */

/datum/police_soak_invariant
	/// Its name in break reports
	var/name
	/// Worst first: 1 is a fault a player sees at once, 2 is the squad doing something wrong, 3 is roughness
	var/rank = 2

/// Once a second. Report with run.breach(src, key, text, involved).
/datum/police_soak_invariant/proc/check(datum/police_soak/run)
	return

// ----- 1 -----

/// An officer alert on, or searching for, someone the police already hold: cuffed by an arrest, or in a cell
/datum/police_soak_invariant/alert_on_custody
	name = "alert_on_custody"
	rank = 1
	/// Seconds an officer may stay alert on or searching for someone in custody (word of the cuffs reaches the squad in a police tick or two)
	var/limit = 8

/datum/police_soak_invariant/alert_on_custody/check(datum/police_soak/run)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
		var/state = run.state_of(officer)
		var/mob/living/held_person
		if(state == "alert" || state == "searching")
			for(var/datum/mind/mind as anything in run.police.warrants)
				var/mob/living/body = mind.current
				if(isliving(body) && run.police.in_custody(body) && run.minds(officer, body))
					held_person = body
					break
		if(run.held("[name]|[REF(officer)]", !!held_person) > limit)
			run.breach(src, REF(officer), "[run.who(officer)] has been [state] on [run.who(held_person)], who is in custody, for over [limit]s", list(officer))

// ----- 2 -----

/// A wanted person at the outpost, not in custody, with no officer who sees them or is on the way to where they were last seen
/datum/police_soak_invariant/wanted_ignored
	name = "wanted_ignored"
	rank = 1
	/// Seconds a wanted person may be at large with nobody seeing them or coming (a fresh search is sent every OUTPOST_POLICE_RESEARCH_GAP, 20 s)
	var/limit = 30
	/// Tiles from the last sighting within which an officer counts as being there
	var/near = 7
	/// An officer counts as on its way if it got this many tiles nearer the last sighting...
	var/closing = 3
	/// ...over this many seconds
	var/window = 10

/datum/police_soak_invariant/wanted_ignored/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.at_large())
		var/datum/outpost_warrant/warrant = run.police.get_warrant(body.mind)
		var/turf/scene = warrant?.last_seen_turf
		// With no sighting at all nobody is sent, by design (owner decision 52)
		var/attended = !scene
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
			var/datum/police_soak_track/found = run.tracks[officer]
			if(!found || !scene)
				continue
			var/distance = officer.z == scene.z ? get_dist(officer, scene) : 999
			found.scene_dists += distance
			if(length(found.scene_dists) > window)
				found.scene_dists.Cut(1, 2)
			if(distance <= near || found.scene_dists[1] - distance >= closing || officer.dispatch_riding || run.police.perception.sees(officer, body))
				attended = TRUE
		if(run.held("[name]|[REF(body)]", !attended) > limit)
			run.breach(src, REF(body), "[run.who(body)] ([run.police.get_stars(body.mind)] stars, at [run.where(body)], last seen [run.where(scene)]) has had no officer in sight of them, within [near] tiles of that place or closing on it for over [limit]s", run.officers_up())

// ----- 3 -----

/// Two of them trading tiles again and again: trying to walk through each other
/datum/police_soak_invariant/tile_trading
	name = "tile_trading"
	rank = 2
	/// Times two bodies may trade tiles within `window` seconds (twice is passing and passing back)
	var/limit = 2
	var/window = 20

/datum/police_soak_invariant/tile_trading/check(datum/police_soak/run)
	for(var/pair in run.swaps)
		var/list/times = run.swaps[pair]
		while(length(times) && world.time - times[1] > window SECONDS)
			times.Cut(1, 2)
		if(length(times) > limit)
			var/list/ids = splittext(pair, "|")
			// Two townspeople doing it is theirs, not the squad's
			if(findtext(ids[1], "N") == 1 && findtext(ids[2], "N") == 1)
				continue
			run.breach(src, pair, "[ids[1]] and [ids[2]] traded tiles [length(times)] times in [window]s", ids)

/// One of them stepping back and forth between the same two tiles
/datum/police_soak_invariant/pacing
	name = "pacing"
	rank = 3
	/// Seconds within which three round trips between the same two tiles count as pacing
	var/window = 15

/datum/police_soak_invariant/pacing/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.tracks)
		var/datum/police_soak_track/found = run.tracks[body]
		var/count = length(found.steps)
		if(count < 6 || !is_outpost_police_npc(body))
			continue
		// Two of them trading tiles is tile_trading's
		var/trading = FALSE
		for(var/pair in run.swaps)
			if((found.id in splittext(pair, "|")) && length(run.swaps[pair]) && world.time - run.swaps[pair][length(run.swaps[pair])] < window SECONDS)
				trading = TRUE
				break
		if(trading)
			continue
		var/turf/a = found.steps[count]
		var/turf/b = found.steps[count - 1]
		if(a == b || found.steps[count - 2] != a || found.steps[count - 4] != a || found.steps[count - 3] != b || found.steps[count - 5] != b)
			continue
		if(world.time - found.step_times[count - 5] > window SECONDS)
			continue
		run.breach(src, REF(body), "[found.id] stepped back and forth between [run.where(a)] and [run.where(b)] three times in [window]s", list(body))

// ----- 4 -----

/// An officer standing still in a doorway with no work there
/datum/police_soak_invariant/door_loiter
	name = "door_loiter"
	rank = 2
	/// Seconds an officer awake may stand still on a door's tile
	var/limit = 10
	/// Seconds since an officer's last trigger pull within which it is in a fight, shooting from the doorway (officers fire about every 3 s)
	var/firing_gap = 5

/datum/police_soak_invariant/door_loiter/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.tracks)
		var/datum/police_soak_track/found = run.tracks[body]
		var/turf/here = get_turf(body)
		var/obj/machinery/door/airlock/door = (here && body.stat == CONSCIOUS && isturf(body.loc)) ? (locate(/obj/machinery/door/airlock) in here) : null
		// The clock counts only the seconds spent there with no reason to be, on this tile: a spell excused (below) is
		// not loitering, and once it ends the officer gets its own `limit` to move on (it used to fire the second an
		// arrest moved off, on a clock that had run through the cuffing and the search)
		var/prefix = "[name]|[REF(body)]|"
		var/key = "[prefix][run.where(here)]"
		for(var/old_key in run.held_since)
			if(old_key != key && findtext(old_key, prefix) == 1)
				run.held_since -= old_key
		if(door && door_loiter_excused(run, body, door))
			door = null
		if(run.held(key, door) > limit)
			run.breach(src, REF(body), "[found.id] ([body.real_name]) has stood still in the doorway of [door] at [run.where(here)] for over [limit]s", list(body))

/// Whether `body` standing in `door` is at work there, not loitering
/datum/police_soak_invariant/door_loiter/proc/door_loiter_excused(datum/police_soak/run, mob/living/body, obj/machinery/door/airlock/door)
	// One of the outpost's people in a doorway is the townsfolk's routine, not the squad's (as tile_trading has it). One
	// stood in an officer's way shows on the officer as frozen_walk.
	if(!is_outpost_police_npc(body))
		return TRUE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = body
	// An officer in a doorway of the scan chamber the police are at work in (someone wanted or held is in it) is at that
	// work: in a chamber one tile wide the doorway is the only place beside the suspect to cuff them from
	var/obj/machinery/door/airlock/outpost/checkpoint/gate_door = door
	if(istype(gate_door) && gate_door.checkpoint?.police_at_work())
		return TRUE
	// Shooting from the doorway: a fight, not a wait (Quartermain kill_then_hide, O1 firing on S every 3 s from Locker Rentals)
	var/list/pull = run.trigger_pulls[officer]
	if(pull && world.time - pull[1] < firing_gap SECONDS)
		return TRUE
	// Alert on its target with them in sight, holding its aim from the doorway: a standoff with someone holding a
	// hostage (Halcyon's Potting Shed), or its line spoiled by someone until it clears (police_reposition() holds when
	// no tile beside it has a clear shot; Quartermain's Locker Rentals). One stuck on a walk shows as frozen_walk.
	var/datum/ai_controller/brain = officer.ai_controller
	var/mob/living/target = brain?.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	if(isliving(target) && brain.blackboard["stealth_state"] == "alert" && run.police.perception.sees(officer, target) && (stealth_hostage_of(target) || officer.bystander_in_line(target)))
		return TRUE
	// Making or covering an arrest with its suspect beside it or in its hand: cuffing and searching are done where the
	// suspect was caught, a doorway or not
	var/mob/living/suspect = QDELETED(officer.case) ? null : officer.case.get_suspect()
	if(suspect && (officer.case.arresting() == officer || officer.case.cover() == officer) && (officer.pulling == suspect || officer.Adjacent(suspect)))
		return TRUE
	return FALSE

// ----- 5 -----

/// An arrest that sits in one step past its own timeout, or keeps going back to the start
/datum/police_soak_invariant/case_stuck
	name = "case_stuck"
	rank = 1
	/// Seconds past OUTPOST_POLICE_STEP_TIMEOUT (60 s) the case's own step clock may read before it counts as stuck
	var/grace = 5
	/// Seconds an arrest may stay on one step by the sampler's clock, whatever its own clock says (closing in on a walk keeps the case's clock fresh)
	var/own_limit = 120
	/// Times an arrest may go back to the start
	var/resets = 1
	/// Seconds an arrest may have nobody on it (its own clock stands still then); dispatch calls at 5 s, a wave forms up for up to 15 s and walks from its lift
	var/unstaffed_limit = 45

/datum/police_soak_invariant/case_stuck/check(datum/police_soak/run)
	for(var/datum/mind/mind as anything in run.police.cases)
		var/datum/outpost_police_case/case = run.police.cases[mind]
		if(QDELETED(case))
			continue
		var/list/officers = list()
		if(case.arresting())
			officers += case.arresting()
		if(case.cover())
			officers += case.cover()
		// "hold" (CASE_STEP_HOLD) waits for a cell on purpose; an action running (cuffing, the search, booking) has its own limit
		var/on_clock = (world.time - case.step_started_at) / (1 SECONDS)
		if(case.step != "hold" && !case.acting && on_clock > 60 + grace)
			run.breach(src, "[REF(case)]|clock|[case.step]", "the arrest of [run.who(mind.current)] has sat in \"[case.step]\" for [round(on_clock)]s by its own clock, past its 60s timeout", officers)
		if(case.unstaffed_since && (world.time - case.unstaffed_since) / (1 SECONDS) > unstaffed_limit)
			run.breach(src, "[REF(case)]|unstaffed", "the arrest of [run.who(mind.current)] has had nobody on it for [round((world.time - case.unstaffed_since) / (1 SECONDS))]s (step \"[case.step]\")", run.officers_up())
		if(case.step != "hold" && run.held("[name]|[REF(case)]|[case.step]|[case.resets]", TRUE) > own_limit)
			run.breach(src, "[REF(case)]|own|[case.step]", "the arrest of [run.who(mind.current)] has been on \"[case.step]\" for over [own_limit]s", officers)
		if(case.resets > resets)
			run.breach(src, "[REF(case)]|resets", "the arrest of [run.who(mind.current)] has gone back to the start [case.resets] times", officers)

// ----- 6 -----

/// A "body" line (a fallen colleague, a corpse) said with nobody dead or out cold anywhere near
/datum/police_soak_invariant/body_line
	name = "body_line_about_the_living"
	rank = 1
	/// Tiles round the speaker searched for someone dead, out cold or in crit (a little past an officer's sight)
	var/reach = 12

/datum/police_soak_invariant/body_line/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.tracks)
		var/datum/police_soak_track/found = run.tracks[body]
		// "stealth_body" (STEALTH_BARK_BODY): it found one of its own down; "body" (POLICE_LINE_BODY): a corpse on the floor
		if(!found.said_unchecked || (found.said_kind != "stealth_body" && found.said_kind != "body"))
			continue
		var/someone_down = FALSE
		var/list/on_floor = list()
		for(var/mob/living/carbon/human/near in range(reach, body))
			if(near.stat != CONSCIOUS || HAS_TRAIT(near, TRAIT_CRITICAL_CONDITION))
				someone_down = TRUE
				break
			if(near.body_position == LYING_DOWN)
				on_floor += "[run.who(near)] at [run.where(near)]"
		if(!someone_down)
			run.breach(src, "[REF(body)]|[found.said_at]", "[found.id] said \"[found.said_text]\" ([found.said_kind]) with nobody dead or out cold within [reach] tiles. Awake on the floor: [length(on_floor) ? on_floor.Join(", ") : "nobody"]", list(body))

// ----- 7 -----

/// A wanted person at large and in an officer's sight while the squad does nothing
/datum/police_soak_invariant/calm_in_sight
	name = "calm_in_sight"
	rank = 1
	/// Seconds the whole squad may stay calm with a wanted person in an officer's sight (a radio call is 3 s, the police tick 1 s)
	var/squad_limit = 8
	/// Seconds one officer may look at a wanted person nobody is arresting and stay calm itself
	var/officer_limit = 15

/// Calm: unaware, with no target, no arrest and nobody it was sent after
/datum/police_soak_invariant/calm_in_sight/proc/calm(datum/police_soak/run, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain))
		return TRUE
	return brain.stealth_state() == "unaware" && !brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET) && !officer.case && !officer.dispatch_mind?.resolve()

/datum/police_soak_invariant/calm_in_sight/check(datum/police_soak/run)
	var/list/officers = run.officers_up()
	var/squad_calm = TRUE
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in officers)
		if(!calm(run, officer))
			squad_calm = FALSE
			break
	for(var/mob/living/body as anything in run.at_large())
		var/list/seers = list()
		for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in officers)
			var/sees = run.police.perception.sees(officer, body)
			if(sees)
				seers += officer
			if(run.held("[name]|[REF(body)]|[REF(officer)]", sees && !run.police.arrest_on(body) && calm(run, officer)) > officer_limit)
				run.breach(src, "[REF(body)]|[REF(officer)]", "[run.who(officer)] has had [run.who(body)] ([run.police.get_stars(body.mind)] stars, at large, no arrest open) in sight for over [officer_limit]s and stayed calm", list(officer))
		if(run.held("[name]|[REF(body)]|squad", squad_calm && length(seers)) > squad_limit)
			run.breach(src, "[REF(body)]|squad", "every officer has been calm for over [squad_limit]s with [run.who(body)] ([run.police.get_stars(body.mind)] stars, at large) in sight of [run.who(seers[1])]", officers)

// ----- 8 -----

/// Officers still alert or searching after the last wanted person is in custody, dead or gone
/datum/police_soak_invariant/alert_after_clear
	name = "alert_after_clear"
	rank = 1
	/// Seconds an officer may stay alert or searching once nobody wanted is at large (the all clear goes out on the next police tick)
	var/limit = 10

/datum/police_soak_invariant/alert_after_clear/check(datum/police_soak/run)
	var/clear = run.ever_wanted && !length(run.at_large())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
		var/state = run.state_of(officer)
		if(run.held("[name]|[REF(officer)]", clear && (state == "alert" || state == "searching")) > limit)
			var/datum/ai_controller/brain = officer.ai_controller
			run.breach(src, REF(officer), "[run.who(officer)] is still [state] (target [run.who(brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET])]) [limit]s after nobody wanted was left at large", list(officer))

// ----- what the code suggests -----

/// An officer's shot or blow landing on someone the police already have, or who is doing as told
/datum/police_soak_invariant/force_on_the_held
	name = "force_on_the_held"
	rank = 1

/datum/police_soak_invariant/force_on_the_held/check(datum/police_soak/run)
	var/from = run.force_checked
	run.force_checked = length(run.force_events)
	for(var/index in (from + 1) to length(run.force_events))
		var/list/event = run.force_events[index]
		if(!event[4])
			continue
		run.breach(src, "[REF(event[2])]|[event[4]]", "[run.who(event[2])] hit [run.who(run.suspect)] with its [event[3]] while they were [event[4]]", list(event[2]))

/// A wanted person down (stunned, out cold, in crit) with an officer near and no arrest opened on them
/datum/police_soak_invariant/downed_unattended
	name = "downed_unattended"
	rank = 1
	/// Seconds a downed wanted person may lie near an officer with no arrest on them (dispatch opens cases once a second)
	var/limit = 10
	/// Tiles within which an officer counts as near
	var/near = 7

/datum/police_soak_invariant/downed_unattended/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.at_large())
		var/mob/living/nearby
		// Where the zone finishes the downed (the Undertow at three stars and up) nobody cuffs them, by design
		if(police_suspect_down(body) && !run.police.arrest_on(body) && !run.police.finishes_downed(body, null))
			for(var/mob/living/officer as anything in run.officers_up())
				if(officer.z == body.z && get_dist(officer, body) <= near)
					nearby = officer
					break
		if(run.held("[name]|[REF(body)]", !!nearby) > limit)
			run.breach(src, REF(body), "[run.who(body)] ([run.police.get_stars(body.mind)] stars) has been down at [run.where(body)] for over [limit]s with [run.who(nearby)] within [near] tiles and no arrest opened", run.officers_up())

/// Someone in police cuffs, not in a cell, with no officer anywhere near: cuffed and left
/datum/police_soak_invariant/cuffed_and_left
	name = "cuffed_and_left"
	rank = 1
	/// Seconds someone in police cuffs outside a cell may be without an officer within `near` tiles
	var/limit = 20
	var/near = 3

/datum/police_soak_invariant/cuffed_and_left/check(datum/police_soak/run)
	for(var/datum/mind/mind as anything in run.police.warrants)
		var/mob/living/carbon/body = mind.current
		var/alone = FALSE
		if(istype(body) && body.stat != DEAD && istype(body.handcuffed, /obj/item/restraints/handcuffs/outpost_police) && !run.police.cell_holding(mind))
			alone = TRUE
			for(var/mob/living/officer as anything in run.officers_up())
				if(officer.z == body.z && get_dist(officer, body) <= near)
					alone = FALSE
					break
		if(run.held("[name]|[REF(mind)]", alone) > limit)
			run.breach(src, REF(mind), "[run.who(body)] has been in police cuffs at [run.where(body)] with no officer within [near] tiles for over [limit]s", run.officers_up())

/// A prisoner in a cell still in cuffs long after they were brought in
/datum/police_soak_invariant/cuffed_in_cell
	name = "cuffed_in_cell"
	rank = 2
	/// Seconds a prisoner may be in a cell with the cuffs still on (the walk in, the strip and the cuffs coming off)
	var/limit = 45

/datum/police_soak_invariant/cuffed_in_cell/check(datum/police_soak/run)
	for(var/datum/outpost_police_cell/cell as anything in run.police.cells)
		for(var/datum/mind/prisoner as anything in cell.prisoners)
			var/mob/living/carbon/body = prisoner.current
			if(run.held("[name]|[REF(prisoner)]", istype(body) && !!body.handcuffed && (get_turf(body) in cell.tiles)) > limit)
				run.breach(src, REF(prisoner), "[run.who(body)] has been in cell [cell.cell_id] with the cuffs on for over [limit]s", run.officers_up())

/// An officer held still (its AI paused) while someone wanted is at large
/datum/police_soak_invariant/paused_with_work
	name = "paused_with_work"
	rank = 2
	/// Seconds an officer's AI may be paused with a wanted person at large (a wave forms up for at most POLICE_WAVE_WAIT_MAX, 15 s)
	var/limit = 20

/datum/police_soak_invariant/paused_with_work/check(datum/police_soak/run)
	var/work = length(run.at_large())
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
		if(run.held("[name]|[REF(officer)]", work && HAS_TRAIT(officer, TRAIT_AI_PAUSED)) > limit)
			run.breach(src, REF(officer), "[run.who(officer)] has been held still (paused by [jointext(GET_TRAIT_SOURCES(officer, TRAIT_AI_PAUSED), ", ")]) at [run.where(officer)] for over [limit]s with someone wanted at large", list(officer))

/// An officer with somewhere to walk to that does not move: a walk it cannot make
/datum/police_soak_invariant/frozen_walk
	name = "frozen_walk"
	rank = 3
	/// Seconds an officer may stand on one tile while it has a walk to somewhere more than `far` tiles off (the walk's target may blink off between plans, so the seconds need not be in a row)
	var/limit = 15
	var/far = 2

/datum/police_soak_invariant/frozen_walk/check(datum/police_soak/run)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer as anything in run.officers_up())
		var/datum/police_soak_track/found = run.tracks[officer]
		if(!found)
			continue
		var/turf/here = get_turf(officer)
		if(here != found.stuck_turf)
			found.stuck_turf = here
			found.stuck_ticks = 0
		var/datum/ai_controller/basic_controller/human_npc/stealth/brain = officer.ai_controller
		var/datum/outpost_police_case/case = officer.case
		// Standing off from someone holding a hostage is standing still on purpose
		if(istype(brain) && brain.standoff_holder?.resolve())
			continue
		// Where its AI is walking it, or where the arrest it is making wants it (the goal is the arresting officer's, not the cover's)
		var/turf/goal = get_turf(brain?.current_movement_target) || (case?.arresting() == officer ? get_turf(case.goal) : null)
		if(!goal || goal.z != officer.z || get_dist(officer, goal) <= far || HAS_TRAIT(officer, TRAIT_AI_PAUSED) || case?.acting || !isturf(officer.loc) || officer.buckled)
			continue
		found.stuck_ticks++
		if(found.stuck_ticks > limit)
			// Who stands round it, and where its pathfinder wants its next step: what it cannot get past
			var/list/around = list()
			for(var/mob/living/other in range(1, officer))
				if(other != officer)
					around += "[run.who(other)] at [run.where(other)][other.body_position == LYING_DOWN ? " (lying)" : ""][istype(other, /mob/living/carbon/human/npc) && !other.mind && !outpost_npc_can_make_room(other) ? " (cannot step aside)" : ""]"
			var/datum/move_loop/has_target/jps/loop = GLOB.move_manager.processing_on(officer, SSai_movement)
			var/next_step = (istype(loop) && length(loop.movement_path)) ? run.where(loop.movement_path[1]) : "none"
			// The officer making an arrest that stands still is the arrest not happening: worse than a stalled beat
			run.breach(src, "[REF(officer)]|[run.where(here)]", "[run.who(officer)] has stood at [run.where(officer)] for over [limit]s with a walk to [run.where(goal)] ([get_dist(officer, goal)] tiles off)[case ? ", on the arrest of [run.who(case.get_suspect())] (step \"[case.step]\")" : ""]. Beside it: [length(around) ? around.Join(", ") : "nobody"]; its path's next tile: [next_step]; it last walked into [run.who(officer.bump_blocker?.resolve())]", list(officer), case ? 2 : null)

/// An officer walking a cuffed suspect in keeps losing hold of them, though the suspect only stands where they are put
/datum/police_soak_invariant/escort_lets_go
	name = "escort_lets_go"
	rank = 2
	/// Times an escort may lose its hold on a suspect who is not moving, within `window` seconds (once is a bump in a crowd)
	var/limit = 1
	var/window = 30

/datum/police_soak_invariant/escort_lets_go/check(datum/police_soak/run)
	var/recent = 0
	for(var/time in run.hold_losses)
		if(world.time - time <= window SECONDS)
			recent++
	if(recent > limit)
		var/datum/outpost_police_case/case = run.police.cases[run.suspect?.mind]
		run.breach(src, "[run.hold_losses[1]]", "the officer walking [run.who(run.suspect)] in lost hold of them [recent] times in [window]s though they never took a step (arrest step \"[case?.step]\", pull breaks counted by the case: [case?.pull_breaks])", case?.arresting() ? list(case.arresting()) : null)

/// A wanted person who stands still on the spot where the police last saw them, and is still not in hand
/datum/police_soak_invariant/standing_suspect_not_taken
	name = "standing_suspect_not_taken"
	rank = 1
	/// Seconds a wanted person may stand on one tile, known to the police, before the cuffs are on or they have been put down (a walk across the biggest outpost is about 20 s)
	var/limit = 45
	/// Tiles between where they stand and where the police last saw them within which the police know where they are
	var/known = 2
	/// Seconds since an officer last fired or landed a blow within which the stand is the fight, not a wait (two waves reaching a suspect who shoots each one down come about 20 s apart)
	var/fight_gap = 30

/datum/police_soak_invariant/standing_suspect_not_taken/check(datum/police_soak/run)
	// A fight going on: an officer fired or landed a blow lately. The rule keeps no state of its own (invariants are shared across runs).
	var/last_exchange = 0
	for(var/list/event as anything in run.force_events)
		last_exchange = max(last_exchange, event[1])
	for(var/officer in run.trigger_pulls)
		var/list/pull = run.trigger_pulls[officer]
		last_exchange = max(last_exchange, pull[1])
	var/fighting = last_exchange && world.time - last_exchange < fight_gap SECONDS
	for(var/mob/living/body as anything in run.at_large())
		var/turf/scene = run.police.get_warrant(body.mind)?.last_seen_turf
		// Holding a hostage they are stood off from on purpose, for up to OUTPOST_POLICE_STANDOFF_MAX (a minute)
		var/waiting = scene && body.z == scene.z && get_dist(body, scene) <= known && length(run.officers_up()) && !stealth_hostage_of(body) && !fighting
		var/prefix = "[name]|[REF(body)]|"
		var/key = "[prefix][run.where(body)]"
		// Off a tile its clock is done: back on it, the clock starts again
		for(var/old_key in run.held_since.Copy())
			if(old_key != key && findtext(old_key, prefix) == 1)
				run.held_since -= old_key
		if(run.held(key, waiting) > limit)
			var/datum/outpost_police_case/case = run.police.cases[body.mind]
			run.breach(src, REF(body), "[run.who(body)] ([run.police.get_stars(body.mind)] stars) has stood at [run.where(body)], where the police last saw them, for over [limit]s and nobody has them (arrest: [case ? "\"[case.step]\", [case.resets] resets" : "none open"])", run.officers_up())


// ----- pass 6: fights -----

/**
 * The squad piling up round a fallen colleague while a wanted person is at large and no officer can see them: the
 * owner's round, where most of the squad stood in the lobby round dead colleagues instead of searching. Medics are
 * not officers and come by themselves. A fallen colleague near where the suspect was last seen is part of the search
 * there, so it does not count.
 */
/datum/police_soak_invariant/bunching_at_fallen
	name = "bunching_at_fallen"
	rank = 1
	/// Officers standing round one fallen colleague that make a pile
	var/crowd = 3
	/// Tiles from the fallen colleague an officer counts as standing round them
	var/radius = 3
	/// Seconds the pile may stand there (a walk past, or a look on the way, is shorter)
	var/limit = 12
	/// Tiles a fallen colleague must lie from the wanted person's last sighting to count: nearer, the search is there anyway
	var/scene_clear = 7

/datum/police_soak_invariant/bunching_at_fallen/check(datum/police_soak/run)
	var/list/officers = run.officers_up()
	// Wanted people at large whom no officer sees, by their last sighting
	var/list/turf/unseen_scenes = list()
	for(var/mob/living/body as anything in run.at_large())
		var/seen = FALSE
		for(var/mob/living/officer as anything in officers)
			if(run.police.perception.sees(officer, body))
				seen = TRUE
				break
		var/turf/scene = run.police.get_warrant(body.mind)?.last_seen_turf
		if(!seen && scene)
			unseen_scenes[scene] = body
	for(var/mob/living/fallen as anything in run.tracks)
		if(!is_outpost_police_npc(fallen) || QDELETED(fallen))
			continue
		var/down = fallen.stat != CONSCIOUS || HAS_TRAIT(fallen, TRAIT_CRITICAL_CONDITION)
		var/list/pile = list()
		var/turf/scene
		if(down && length(unseen_scenes))
			for(var/turf/place as anything in unseen_scenes)
				if(place.z != fallen.z || get_dist(place, fallen) > scene_clear)
					scene = place
					break
			if(scene)
				for(var/mob/living/officer as anything in officers)
					if(officer.z == fallen.z && get_dist(officer, fallen) <= radius)
						pile += officer
		if(run.held("[name]|[REF(fallen)]", length(pile) >= crowd) > limit)
			var/list/ids = list()
			for(var/mob/living/officer as anything in pile)
				ids += run.who(officer)
			var/mob/living/wanted = unseen_scenes[scene]
			run.breach(src, REF(fallen), "[length(pile)] officers ([ids.Join(", ")]) have stood within [radius] tiles of fallen [run.who(fallen)] at [run.where(fallen)] for over [limit]s while [run.who(wanted)] ([run.police.get_stars(wanted.mind)] stars) is at large, seen by nobody, last seen [run.where(scene)] ([get_dist(scene, fallen)] tiles away)", pile + fallen)

/// An officer's shot or blow landing on one of the outpost's people, or on another officer
/datum/police_soak_invariant/friendly_fire
	name = "friendly_fire"
	rank = 1

/datum/police_soak_invariant/friendly_fire/check(datum/police_soak/run)
	var/from = run.stray_checked
	run.stray_checked = length(run.stray_events)
	for(var/index in (from + 1) to length(run.stray_events))
		var/list/event = run.stray_events[index]
		var/mob/living/victim = event[3]
		var/on_officer = is_outpost_police_npc(victim)
		run.breach(src, "[REF(event[2])]|[REF(victim)]", "[run.who(event[2])] hit [on_officer ? "fellow officer " : ""][run.who(victim)] ([victim?.real_name]) with its [event[4]]", list(event[2], victim), on_officer ? 2 : 1)

/**
 * A wanted person down (stunned, out cold, in crit) in an officer's sight, left lying: neither taken in hand nor
 * finished. downed_unattended covers the zones that take the downed alive; this one also covers a zone that finishes
 * them (the Undertow), where ten officers once stood round a five-star suspect in soft crit searching for a minute.
 */
/datum/police_soak_invariant/downed_in_sight
	name = "downed_in_sight"
	rank = 1
	/// Seconds a downed wanted person may lie in an officer's sight without being taken or finished (a cuffing is 4 s, a walk across a room 10)
	var/limit = 30
	/// Seconds since an officer's last trigger pull at the body within which it is being finished (officers fire about every 3 s)
	var/finishing_gap = 4

/datum/police_soak_invariant/downed_in_sight/check(datum/police_soak/run)
	for(var/mob/living/body as anything in run.at_large())
		var/mob/living/seer
		if(police_suspect_down(body))
			for(var/mob/living/officer as anything in run.officers_up())
				if(run.police.perception.sees(officer, body))
					seer = officer
					break
			// Still being shot where they lie is finishing, if slowly (the Undertow, M1 into a Nuclear Operative suit
			// every 3 s for 36 s, 1125002653bdc): those seconds don't count
			for(var/officer in run.trigger_pulls)
				var/list/pull = run.trigger_pulls[officer]
				if(pull[3] == body && world.time - pull[1] < finishing_gap SECONDS)
					seer = null
					break
		if(run.held("[name]|[REF(body)]", !!seer) > limit)
			run.breach(src, REF(body), "[run.who(body)] ([run.police.get_stars(body.mind)] stars) has lain down at [run.where(body)] in sight of [run.who(seer)] for over [limit]s, neither taken nor finished ([run.police.finishes_downed(body, null) ? "a zone that finishes the downed" : "a zone that takes them alive"])", run.officers_up())
