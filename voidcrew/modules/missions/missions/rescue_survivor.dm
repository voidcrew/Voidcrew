/**
 * # Rescue survivor
 *
 * The person a rescue contract sends a crew to fetch. They are an ambient NPC (the world population
 * core in voidcrew/modules/ambient_npcs/), so they get its looks, its walking, its activities and
 * its dialogue cooldowns, and they behave like a frightened person:
 *
 * - placed somewhere sheltered in the wreck (a locker, a corner, an alcove), out of sight of
 *   whatever is loose in there (mission_survivor_hiding_place());
 * - hiding: crouched and quiet, fidgeting now and then; inside a locker, silent;
 * - before anyone has found them, their beacon crackles a distress call to the contract crew's
 *   radios when they are a few screens away;
 * - when they see a person, they call out and wave (or bang on the locker), and come over if
 *   nothing is about;
 * - a hostile close by, or one going for them: they run, away from it, and hide again where they
 *   stop; one further off: they keep still, and if there are people about they shout a warning;
 * - an empty hand makes them follow (or wait); following, they stay at their rescuer's side,
 *   duck and yelp at danger instead of running, climb out of anything they are shut in, and wait
 *   where they are if their rescuer goes;
 * - they never fight;
 * - removed by the contract (delivered, timed out, abandoned, re-targeted), they are taken up from
 *   orbit in the transporter's column of light (beam_out()), or deleted at once if nobody sees.
 *
 * Immune to air, cold and heat on purpose (see the old note in the rescue contract's history):
 * the contract puts them inside airless wrecks, and only violence should kill them.
 */

/// How far they see people and threats
#define SURVIVOR_SIGHT 7
/// How often they look around
#define SURVIVOR_LOOK_INTERVAL (1 SECONDS)
/// A threat this close, or one going for them, sends them running (until they have a rescuer)
#define SURVIVOR_FLEE_DISTANCE 4
/// How far they run at most, per run
#define SURVIVOR_FLEE_RANGE 6
/// How long one flight lasts before they settle wherever they got to
#define SURVIVOR_FLEE_TIME (12 SECONDS)
/// A threat that keeps coming can send them running this many more times in one flight
#define SURVIVOR_FLEE_RUNS 3
/// The contract crew hear the distress call within this many tiles
#define SURVIVOR_DISTRESS_RANGE 30
/// Between two distress calls
#define SURVIVOR_DISTRESS_GAP_LOW (50 SECONDS)
#define SURVIVOR_DISTRESS_GAP_HIGH (90 SECONDS)
/// Somebody they spotted this close (or nearer) gets walked up to, if nothing else is about
#define SURVIVOR_APPROACH_RANGE 6
/// Somebody this close counts as right there (they stand up, they plead)
#define SURVIVOR_NEAR_RANGE 3
/// Inside a locker they hear people this close
#define SURVIVOR_HEARING_RANGE 3
/// Following: a leader further than this, or gone, or dead, is out of reach
#define SURVIVOR_FOLLOW_RANGE 14
/// Following: a leader out of reach this long, and they stop and wait where they are
#define SURVIVOR_LOST_TIME (45 SECONDS)
/// Following outranks every reaction: nothing makes them run off from their rescuer
#define SURVIVOR_FOLLOW_PRIORITY 60
/// Running outranks calling out
#define SURVIVOR_FLEE_PRIORITY 55
/// Following: how long they stay down when they duck, and how soon they may duck again
#define SURVIVOR_DUCK_TIME (3 SECONDS)
#define SURVIVOR_DUCK_COOLDOWN (8 SECONDS)
/// Hiding place search: how far from the site's spawn point it looks
#define SURVIVOR_SHELTER_RADIUS 20
/// Hiding place search: nothing hostile within this many tiles of it
#define SURVIVOR_SHELTER_THREAT_GAP 6
/// Hiding place search: blocked neighbours (of 8) a floor tile needs to count as a corner or alcove
#define SURVIVOR_SHELTER_MIN_COVER 5
/// The beam: the column comes down, they come apart in it, and they are gone this long after it started
#define SURVIVOR_BEAM_TIME (3 SECONDS)
/// The beam: how long the column takes to come down before they start to come apart
#define SURVIVOR_BEAM_DROP (0.4 SECONDS)
/// The beam is only drawn for someone with a client within this many tiles; otherwise they are deleted at once
#define SURVIVOR_BEAM_WATCH_RANGE 10
/// Trait source for what the survivor puts on themselves
#define SURVIVOR_TRAIT "mission_survivor"

// =========================================================================
// THE SURVIVOR
// =========================================================================

/mob/living/basic/ambient_npc/mission_survivor
	name = "survivor"
	desc = "Somebody who has had a very long week and would love to see a ship interior again. Their emergency suit is patched in three places and still holding."
	maxHealth = 60
	health = 60
	// Quick on their feet: they keep up with whoever is getting them out
	speed = 1
	// Carried out like anyone else: pulled, bagged, boxed or beamed (the ambient core forbids all of that)
	move_resist = MOVE_RESIST_DEFAULT
	death_cash_low = 0
	death_cash_high = 0
	speak_emote = list("says")
	speech_pace = 1.5
	outfit_choices = list(
		/datum/outfit/mission_survivor,
		/datum/outfit/mission_survivor/bareheaded,
	)
	routine = list(/datum/ambient_activity/survivor_hide = 1)
	ai_controller = /datum/ai_controller/basic_controller/ambient_npc/mission_survivor
	/// The contract they belong to (a /datum/mission), for the distress call and to know its crew
	var/datum/weakref/contract_ref
	/// Who they were before this ("salvage tech"), from the contract
	var/story
	/// Where they keep their head down when they are not doing anything else
	var/turf/hide_spot
	/// The locker they were put in to hide, while they are still in it
	var/datum/weakref/hid_in_ref
	/// Someone has made them follow at least once
	var/rescued = FALSE
	/// They have seen a person: no more distress calls
	var/contacted = FALSE
	/// They said something on first stepping aboard a ship
	var/said_aboard = FALSE
	/// Being taken up in the beam: nothing else happens to them
	var/beaming_out = FALSE
	/// REFs of the people they already called out to
	var/list/greeted
	/// world.time they next look around, call for help on the radio, or fidget
	var/next_look = 0
	var/next_distress = 0
	var/next_fidget = 0
	/// world.time they last saw a threat
	var/last_threat_at = 0

/mob/living/basic/ambient_npc/mission_survivor/Initialize(mapload)
	. = ..()
	// The ambient core makes its people fixtures of their place. A survivor has no place: let them
	// be put in a locker or a body bag, drag-dropped and teleported, the way the contract always
	// allowed. They still refuse polymorph and type changes, which would only lose the contract.
	REMOVE_TRAIT(src, TRAIT_NO_CONTAINMENT, AMBIENT_NPC_TRAIT)
	UnregisterSignal(src, list(COMSIG_MOUSEDROP_ONTO, COMSIG_MOVABLE_TELEPORTING))
	hide_spot = get_turf(src)
	next_fidget = world.time + rand(20 SECONDS, 40 SECONDS)

/mob/living/basic/ambient_npc/mission_survivor/Destroy()
	contract_ref = null
	hide_spot = null
	hid_in_ref = null
	greeted = null
	return ..()

/// Ties them to `contract`: its crew hear their distress call, and they take its story
/mob/living/basic/ambient_npc/mission_survivor/proc/join_contract(datum/mission/contract)
	if(!contract)
		return
	contract_ref = WEAKREF(contract)
	story = contract.objective_name
	if(story)
		var/article = (LOWER_TEXT(copytext(story, 1, 2)) in list("a", "e", "i", "o", "u")) ? "An" : "A"
		desc = "[article] [story] who has had a very long week. [p_Their()] emergency suit is patched in three places and still holding."

/**
 * Puts them in their hiding place: into `locker` (shut) if there is one, or down in a crouch where
 * they stand. Where they stand is where they come back to.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/take_shelter(obj/structure/closet/locker)
	hide_spot = get_turf(src)
	if(QDELETED(locker))
		crouch()
		return
	if(locker.opened)
		forceMove(locker.loc)
		locker.close()
	else
		forceMove(locker)
	if(loc == locker)
		hid_in_ref = WEAKREF(locker)

/mob/living/basic/ambient_npc/mission_survivor/examine(mob/user)
	. = ..()
	if(stat != CONSCIOUS)
		return
	var/datum/ambient_activity/survivor_follow/follow = activity
	var/mob/leader = istype(follow) ? follow.anchor() : null
	if(leader)
		. += span_notice("[p_Theyre()] sticking close to [leader].")
	else if(crouching)
		. += span_notice("[p_Theyre()] shaking.")

// =========================================================================
// FOLLOWING
// =========================================================================

/mob/living/basic/ambient_npc/mission_survivor/talked_to(mob/living/user)
	if(beaming_out || !talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	var/datum/ambient_activity/survivor_follow/follow = activity
	var/mob/living/leader = istype(follow) ? follow.anchor() : null
	if(leader == user)
		stop_following()
		speak_context("wait", user, force = TRUE)
		return
	// Whoever came for them keeps them: a stranger can't walk off with them
	if(leader && is_contract_crew(leader) && !is_contract_crew(user))
		speak_context("refuse", user, force = TRUE)
		return
	if(start_following(user))
		speak_context("follow", user, force = TRUE)

/// They follow `leader` from now on. Returns the activity, or null.
/mob/living/basic/ambient_npc/mission_survivor/proc/start_following(mob/living/leader)
	if(beaming_out || !isliving(leader))
		return null
	rescued = TRUE
	contacted = TRUE
	return start_activity(new /datum/ambient_activity/survivor_follow(src, leader))

/// They stop following and wait where they are
/mob/living/basic/ambient_npc/mission_survivor/proc/stop_following()
	hide_spot = get_turf(src)
	if(is_following())
		end_activity()

/mob/living/basic/ambient_npc/mission_survivor/proc/is_following()
	return istype(activity, /datum/ambient_activity/survivor_follow)

/// Their rescuer is out of reach: they wait where they are. Called by the follow activity as it ends.
/mob/living/basic/ambient_npc/mission_survivor/proc/lose_leader()
	hide_spot = get_turf(src)

/// Their rescuer went down in front of them
/mob/living/basic/ambient_npc/mission_survivor/proc/leader_fell(mob/living/leader)
	hide_spot = get_turf(src)
	if(!buckled)
		face_atom(leader)
	speak_context("leader_down", leader, force = TRUE)

/// Whether `person` is crew of the ship that took their contract
/mob/living/basic/ambient_npc/mission_survivor/proc/is_contract_crew(mob/living/person)
	var/datum/mission/contract = contract_ref?.resolve()
	if(!contract?.servant || !isliving(person))
		return FALSE
	return ambient_crew_ship(person) == contract.servant

/// Shut in something while following: they push it open, or bang on it if it won't
/mob/living/basic/ambient_npc/mission_survivor/proc/climb_out()
	var/obj/structure/closet/container = loc
	if(!istype(container) || !reaction_ready("climb_out", 3 SECONDS))
		return
	if(container.open())
		return
	if(reaction_ready("trapped", 12 SECONDS))
		bang_on(container)
		speak_context("trapped", null, force = TRUE)

/// Bangs on the inside of `container`
/mob/living/basic/ambient_npc/mission_survivor/proc/bang_on(obj/structure/closet/container)
	if(QDELETED(container))
		return
	container.Shake(2, 1, 0.5 SECONDS)
	playsound(container, 'sound/effects/bang.ogg', 30, TRUE, -2)

/// The first time they step aboard a crew's ship
/mob/living/basic/ambient_npc/mission_survivor/proc/check_aboard()
	if(said_aboard || !istype(get_area(src), /area/shuttle/voidcrew))
		return
	said_aboard = TRUE
	speak_context("aboard", null, force = TRUE)

// =========================================================================
// LOOKING AROUND
// =========================================================================

/**
 * About once a second while their AI is on: who and what can they see, and what do they do about
 * it. Starts reactions (calling out, running) as activities; never sleeps.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/look_around()
	if(beaming_out || !can_act() || world.time < next_look)
		return
	next_look = world.time + SURVIVOR_LOOK_INTERVAL
	var/turf/here = get_turf(src)
	if(!here)
		return
	var/obj/structure/closet/container = istype(loc, /obj/structure/closet) ? loc : null
	// Out of the locker they hid in: whoever let them out gets thanked
	if(hid_in_ref && !container)
		hid_in_ref = null
		var/mob/living/opener = nearest_person(here, 2)
		if(opener)
			mark_greeted(opener)
			contacted = TRUE
			face_atom(opener)
			speak_context("freed", opener, force = TRUE)
	var/mob/living/threat = container ? null : nearest_threat(here)
	if(threat)
		last_threat_at = world.time
	if(is_following())
		if(threat && reaction_ready("duck", SURVIVOR_DUCK_COOLDOWN))
			duck(threat)
		return
	if(threat)
		react_threat(threat, here)
		return
	var/mob/living/person = new_person_in_sight(here, container)
	if(person)
		contacted = TRUE
		start_activity(new /datum/ambient_activity/survivor_call(src, person))
		return
	if(!contacted)
		distress_call(here)

/**
 * A threat in sight, while nobody is leading them out. Close, or after them: they run. Further off:
 * they keep still, and warn anyone there.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/react_threat(mob/living/threat, turf/here)
	var/after_us = threat.ai_controller?.blackboard[BB_BASIC_MOB_CURRENT_TARGET] == src
	if(get_dist(here, threat) <= SURVIVOR_FLEE_DISTANCE || after_us)
		if(!istype(activity, /datum/ambient_activity/survivor_flee))
			start_activity(new /datum/ambient_activity/survivor_flee(src, threat))
		return
	if(istype(activity, /datum/ambient_activity/survivor_flee))
		return
	// Walking up to someone with that about? No.
	if(istype(activity, /datum/ambient_activity/survivor_call))
		end_activity()
	if(isturf(loc) && !crouching)
		crouch()
	var/mob/living/person = nearest_person(here, SURVIVOR_SIGHT)
	if(person)
		contacted = TRUE
		mark_greeted(person)
		if(reaction_ready("warn", 15 SECONDS))
			speak_context("warn", person, force = TRUE)
		return
	if(!reaction_ready("cower", 30 SECONDS))
		return
	if(prob(50))
		speak_context("cower", threat, force = TRUE)
	else
		manual_emote(pick("freezes.", "holds [p_their()] breath.", "presses [p_themselves()] against the wall."))

/// Following, and something is coming: they duck down and yelp, and stay with their rescuer
/mob/living/basic/ambient_npc/mission_survivor/proc/duck(mob/living/threat)
	if(!isturf(loc))
		return
	speak_context("duck", threat, force = TRUE)
	if(crouching || buckled)
		return
	crouch()
	addtimer(CALLBACK(src, PROC_REF(stop_ducking)), SURVIVOR_DUCK_TIME, TIMER_UNIQUE | TIMER_OVERRIDE)

/mob/living/basic/ambient_npc/mission_survivor/proc/stop_ducking()
	if(crouching && is_following())
		stand_up()

/// Whether `thing` is something they should be afraid of: awake, nobody's player, not a person, and out to hurt someone
/mob/living/basic/ambient_npc/mission_survivor/proc/is_threat(mob/living/thing)
	if(thing == src || thing.stat != CONSCIOUS || thing.client || istype(thing, /mob/living/basic/ambient_npc))
		return FALSE
	if(faction_check_atom(thing))
		return FALSE
	return mission_survivor_dangerous(thing)

/// The nearest threat they can see from `here`, or null
/mob/living/basic/ambient_npc/mission_survivor/proc/nearest_threat(turf/here)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/thing in hearers(SURVIVOR_SIGHT, here))
		if(!is_threat(thing))
			continue
		var/distance = get_dist(here, thing)
		if(distance < nearest_distance)
			nearest = thing
			nearest_distance = distance
	return nearest

/**
 * The nearest awake person (someone played) within `range` of `here` that they can see, or null.
 * From inside a locker they can't see out, so it goes by ear: anyone close enough counts.
 * `skip_greeted` leaves out people they already called out to.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/nearest_person(turf/here, range, by_ear = FALSE, skip_greeted = FALSE)
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, range))
		if(person == src || person.stat != CONSCIOUS)
			continue
		var/turf/there = get_turf(person)
		if(!there || there.z != here.z)
			continue
		var/distance = get_dist(here, there)
		if(distance > range || distance >= nearest_distance)
			continue
		if(skip_greeted && LAZYFIND(greeted, REF(person)))
			continue
		if(!by_ear && !can_see(here, there, range))
			continue
		nearest = person
		nearest_distance = distance
	return nearest

/// Someone they have not called out to yet, in sight (or in earshot from a locker), or null. They count as called out to from now.
/mob/living/basic/ambient_npc/mission_survivor/proc/new_person_in_sight(turf/here, obj/structure/closet/container)
	var/mob/living/person = container ? nearest_person(here, SURVIVOR_HEARING_RANGE, by_ear = TRUE, skip_greeted = TRUE) : nearest_person(here, SURVIVOR_SIGHT, skip_greeted = TRUE)
	if(person)
		mark_greeted(person)
	return person

/mob/living/basic/ambient_npc/mission_survivor/proc/mark_greeted(mob/living/person)
	var/key = REF(person)
	if(LAZYFIND(greeted, key))
		return
	LAZYADD(greeted, key)
	if(length(greeted) > 20)
		greeted.Cut(1, 2)

/**
 * Nobody has found them yet: their beacon picks up the contract crew's ship and they talk into it.
 * Heard on the radios of that crew within SURVIVOR_DISTRESS_RANGE, as a weak signal.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/distress_call(turf/here)
	if(world.time < next_distress)
		return
	var/datum/mission/contract = contract_ref?.resolve()
	var/obj/structure/overmap/ship/ship = contract?.servant
	if(!ship)
		return
	var/list/listeners = list()
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, SURVIVOR_DISTRESS_RANGE))
		if(person.stat == DEAD)
			continue
		var/turf/there = get_turf(person)
		if(!there || there.z != here.z || get_dist(here, there) > SURVIVOR_DISTRESS_RANGE)
			continue
		if(ambient_crew_ship(person) != ship)
			continue
		listeners += person
	if(!length(listeners))
		return
	next_distress = world.time + rand(SURVIVOR_DISTRESS_GAP_LOW, SURVIVOR_DISTRESS_GAP_HIGH)
	var/list/lines = get_lines("distress")
	if(!length(lines))
		return
	var/line = fill_line(pick(lines))
	for(var/mob/living/person as anything in listeners)
		to_chat(person, span_radio("\[Distress\] <b>[real_name]</b> says, \"[line]\""))
		person.playsound_local(get_turf(person), 'sound/misc/interference.ogg', 20, FALSE)

/**
 * Their hiding activity's tick: up on their feet when someone is right there, down again when
 * they are alone; a plea to whoever is close; otherwise a fidget now and then.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/hide_tick()
	var/turf/here = get_turf(src)
	if(!here)
		return
	if(!isturf(loc))
		return // shut in somewhere, keeping quiet
	var/mob/living/near = nearest_person(here, SURVIVOR_NEAR_RANGE)
	var/scared = world.time - last_threat_at < 5 SECONDS
	if(near && !scared)
		if(crouching)
			stand_up()
		if(!buckled)
			face_atom(near)
		if(reaction_ready("plead", 40 SECONDS))
			speak_context(rescued ? "wait_idle" : "plead", near, force = TRUE)
		return
	if(!near && !crouching && !buckled)
		crouch()
	if(world.time < next_fidget)
		return
	next_fidget = world.time + rand(40 SECONDS, 80 SECONDS)
	if(prob(40))
		speak_context(rescued ? "wait_idle" : "hide", null, force = TRUE)
		return
	manual_emote(pick(
		"hugs [p_their()] knees.",
		"shivers.",
		"taps at the beacon on [p_their()] wrist.",
		"listens, very still.",
		"rocks back and forth.",
	))

/**
 * Where to run from `threat`: a free tile within SURVIVOR_FLEE_RANGE, further from it than they are,
 * on their own side of it (so the way there doesn't pass it), in sight from where they stand (so
 * the way there is short), best out of its sight with a wall at their back. Null if nowhere.
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/flee_tile(mob/living/threat, list/avoid)
	var/turf/here = get_turf(src)
	var/turf/danger = get_turf(threat)
	if(!here || !danger || here.z != danger.z)
		return null
	var/start_gap = get_dist(here, danger)
	var/turf/best
	var/best_score = -INFINITY
	for(var/turf/tile as anything in RANGE_TURFS(SURVIVOR_FLEE_RANGE, here))
		var/gap = get_dist(tile, danger)
		if(gap < start_gap + 2 || get_dist(tile, here) >= gap)
			continue
		if(!standable(tile, avoid) || !can_see(here, tile, SURVIVOR_FLEE_RANGE + 1))
			continue
		var/score = gap + rand(0, 3)
		if(!can_see(danger, tile, SURVIVOR_SIGHT + 2))
			score += 4
		if(ambient_backed_by_wall_or_table(tile))
			score += 1
		if(score > best_score)
			best = tile
			best_score = score
	return best

/mob/living/basic/ambient_npc/mission_survivor/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading || beaming_out || !reaction_ready("attacked", 4 SECONDS))
		return
	var/mob/living/hitter = isliving(attacker) ? attacker : null
	speak_context(hitter?.client ? "hurt_by_person" : "hurt", attacker, force = TRUE)
	if(is_following())
		if(hitter)
			duck(hitter)
		return
	if(hitter)
		start_activity(new /datum/ambient_activity/survivor_flee(src, hitter))

// =========================================================================
// LEAVING: THE BEAM
// =========================================================================

/**
 * Taken up from orbit: a column of light comes down on them, they lift and come apart in it, and
 * they are gone. Nothing happens to them meanwhile. Somewhere nobody can see, they just go.
 * `farewell` has them say goodbye first (delivered home). `force_visual` draws the beam even
 * with nobody about (unit tests).
 */
/mob/living/basic/ambient_npc/mission_survivor/proc/beam_out(farewell = FALSE, force_visual = FALSE)
	if(beaming_out || QDELETED(src))
		return
	var/turf/spot = get_turf(src)
	if(!spot || (!force_visual && !mission_survivor_watched(spot)))
		beaming_out = TRUE
		qdel(src)
		return
	var/was_awake = stat == CONSCIOUS && isturf(loc)
	if(was_awake)
		setDir(SOUTH) // face front, so the dissolve reads
		if(farewell)
			speak_context("goodbye", null, force = TRUE)
			manual_emote("waves.")
		else
			manual_emote("looks up.")
	beaming_out = TRUE
	fading = TRUE
	end_activity()
	stand_up()
	add_traits(list(TRAIT_AI_PAUSED, TRAIT_GODMODE, TRAIT_IMMOBILIZED, TRAIT_NO_FLOATING_ANIM), SURVIVOR_TRAIT)
	pulledby?.stop_pulling()
	stop_pulling()
	buckled?.unbuckle_mob(src, force = TRUE)
	set_anchored(TRUE)
	move_resist = INFINITY
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT
	playsound(spot, 'sound/effects/magic/teleport_diss.ogg', 40, TRUE)
	new /obj/effect/temp_visual/transporter_beam(spot, SURVIVOR_BEAM_TIME + 0.5 SECONDS)
	addtimer(CALLBACK(src, PROC_REF(beam_dissolve)), SURVIVOR_BEAM_DROP)
	addtimer(CALLBACK(src, PROC_REF(beam_gone)), SURVIVOR_BEAM_TIME)

/// The column is down: they lift a little and come apart in it, head first
/mob/living/basic/ambient_npc/mission_survivor/proc/beam_dissolve()
	if(!isturf(loc))
		return // shut in a locker: the column takes them through it
	var/dissolve_time = SURVIVOR_BEAM_TIME - SURVIVOR_BEAM_DROP
	new /obj/effect/abstract/particle_holder(src, /particles/transporter_motes, PARTICLE_ATTACH_MOB)
	transporter_dematerialise(src, dissolve_time)
	animate(src, pixel_z = pixel_z + 8, time = dissolve_time, easing = SINE_EASING | EASE_IN, flags = ANIMATION_PARALLEL)

/// Gone: the last flash where they stood, and the column lifts back up without them
/mob/living/basic/ambient_npc/mission_survivor/proc/beam_gone()
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/temp_visual/transporter_flash/departure(spot)
		playsound(spot, 'sound/effects/magic/teleport_app.ogg', 50, TRUE)
	qdel(src)

/// Whether anyone with a client is close enough to `spot` to see a beam come down there
/proc/mission_survivor_watched(turf/spot)
	for(var/mob/viewer in SSspatial_grid.orthogonal_range_search(spot, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, SURVIVOR_BEAM_WATCH_RANGE))
		if(!viewer.client)
			continue
		var/turf/there = get_turf(viewer)
		if(there?.z == spot.z && get_dist(there, spot) <= SURVIVOR_BEAM_WATCH_RANGE)
			return TRUE
	return FALSE

// =========================================================================
// WHAT THEY SAY
// =========================================================================

// Their own lines only: none of the ambient core's chatter fits someone in this state
/mob/living/basic/ambient_npc/mission_survivor/get_lines(context)
	var/static/list/lines = list(
		// Hiding alone, under their breath
		"hide" = list(
			"#Come on. Somebody heard it.",
			"#Stay quiet. Stay quiet.",
			"#Please, please, please.",
			"#Beacon's still on. It's still on.",
		),
		// A threat about and nobody there
		"cower" = list(
			"#Don't see me. Don't see me.",
			"#Go away. Please go away.",
			"#Oh no. Oh no.",
		),
		// A threat about, and people there
		"warn" = list(
			"Look out!",
			"There's more of them!",
			"Watch it, they're coming!",
		),
		// First sight of someone
		"call" = list(
			"Over here!",
			"Hey! Hey, over here!",
			"Is someone there? Please!",
			"Here! I'm over here!",
			"You came. You actually came.",
		),
		// First sound of someone, from a locker
		"call_locker" = list(
			"In here! I'm in here!",
			"Is someone out there? Let me out!",
			"Don't go! I'm in here!",
		),
		// Let out of the locker
		"freed" = list(
			"Oh, thank god.",
			"Thank you. Thank you.",
			"I thought you were one of them.",
		),
		// Someone right there, not taking them yet
		"plead" = list(
			"Please, get me out of here.",
			"Are you taking me out? Please say yes.",
			"Can we go? Please?",
		),
		"flee" = list(
			"No no no!",
			"Get away from me!",
			"Help! Help!",
			"Somebody help!",
		),
		"hurt" = list(
			"Agh!",
			"Ow! Help!",
			"Please! Stop!",
		),
		"hurt_by_person" = list(
			"Hey! I'm on your side!",
			"Ow! What was that for?",
			"Watch where you're shooting!",
		),
		"follow" = list(
			"Right behind you.",
			"Okay. Okay. Let's go.",
			"Don't leave me behind.",
			"Right behind you. Please don't be wrong about the way out.",
		),
		"wait" = list(
			"I'll... wait right here.",
			"Don't be long.",
			"Okay. I'll be here.",
		),
		"refuse" = list(
			"I'm with them.",
			"No. I'm going with them.",
		),
		// Following, now and then
		"follow_idle" = list(
			"Is your ship far?",
			"I thought nobody was coming.",
			"How long was I in there?",
			"Thank you. Really.",
			"Do you have any water?",
		),
		// Following, and something is coming
		"duck" = list(
			"What was that?",
			"Something's moving!",
			"Don't let it near me!",
			"Get down!",
		),
		"lost" = list(
			"Hello? Where'd you go?",
			"Don't leave me here!",
			"Hello?",
		),
		"leader_down" = list(
			"No. No, no, no.",
			"Get up. Please, get up.",
		),
		"trapped" = list(
			"Let me out!",
			"Hey! Open this!",
		),
		"aboard" = list(
			"Is this your ship? Oh, thank god.",
			"A real ship. Lights and everything.",
		),
		// Waiting where they were told, or near someone after being rescued
		"wait_idle" = list(
			"Is it much further?",
			"I'll stay right here.",
			"Are we leaving soon?",
		),
		"goodbye" = list(
			"Thank you. I mean it.",
			"I owe you. All of you.",
			"Thank you. Really.",
		),
		// Over the radio, before anyone has found them
		"distress" = list(
			"Is anyone out there? Please.",
			"This is {name}. I'm still here.",
			"I can hear a ship. Please don't leave.",
			"Hello? Anyone? Please.",
			"Still here. Still here. Please.",
		),
	)
	var/list/found = lines[context]
	return islist(found) ? found : list()

// =========================================================================
// THEIR LOOK
// =========================================================================

/// What they have been living in: an orange emergency suit over their work clothes
/datum/outfit/mission_survivor
	name = "Rescue Survivor"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/space/fragile
	head = /obj/item/clothing/head/helmet/space/fragile
	shoes = /obj/item/clothing/shoes/workboots

/datum/outfit/mission_survivor/bareheaded
	name = "Rescue Survivor (Helmet Off)"
	head = null

// =========================================================================
// THEIR BRAIN
// =========================================================================

/// The ambient routine runner, with their senses in front of it
/datum/ai_controller/basic_controller/ambient_npc/mission_survivor
	planning_subtrees = list(
		/datum/ai_planning_subtree/mission_survivor_senses,
		/datum/ai_planning_subtree/ambient_routine,
	)
	// Awake while a crew is still a few screens off, for the distress call
	interesting_dist = 24

/// Looks around and reacts; the routine subtree after it does the walking
/datum/ai_planning_subtree/mission_survivor_senses

/datum/ai_planning_subtree/mission_survivor_senses/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = controller.pawn
	if(istype(survivor) && controller.ai_status == AI_STATUS_ON)
		survivor.look_around()

// =========================================================================
// WHAT THEY DO
// =========================================================================

/// Keeping their head down where they are told to stay, or where they last stopped
/datum/ambient_activity/survivor_hide
	name = "hiding"

/datum/ambient_activity/survivor_hide/setup()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	var/turf/hide_at = istype(survivor) ? survivor.hide_spot : null
	if(isturf(doer.loc) && hide_at && hide_at != doer.loc && hide_at.z == doer.z && get_dist(doer, hide_at) <= SURVIVOR_FOLLOW_RANGE && doer.standable(hide_at, failed_spots))
		go_to(hide_at)
	return TRUE

/datum/ambient_activity/survivor_hide/act(seconds)
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(istype(survivor))
		survivor.hide_tick()
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/survivor_hide/spot_unreachable()
	. = ..()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(istype(survivor))
		survivor.hide_spot = get_turf(doer)

/// Calling out to someone they spotted, waving, and coming over if it is safe; from a locker, banging on it
/datum/ambient_activity/survivor_call
	name = "calling out"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 15 SECONDS
	duration_high = 20 SECONDS

/datum/ambient_activity/survivor_call/setup()
	var/mob/living/person = anchor()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(!isliving(person) || !istype(survivor))
		return FALSE
	set_duration()
	if(istype(doer.loc, /obj/structure/closet))
		survivor.bang_on(doer.loc)
		doer.speak_context("call_locker", person, force = TRUE)
		return TRUE
	doer.stand_up()
	doer.face_atom(person)
	doer.manual_emote(pick("waves both arms.", "waves.", "waves weakly."))
	doer.speak_context("call", person, force = TRUE)
	var/distance = get_dist(doer, person)
	if(distance > 2 && distance <= SURVIVOR_APPROACH_RANGE)
		go_to(get_turf(person), 2)
	return TRUE

/datum/ambient_activity/survivor_call/act(seconds)
	var/mob/living/person = anchor()
	var/turf/there = get_turf(person)
	if(!person || person.stat == DEAD || there?.z != doer.z)
		return AMBIENT_STEP_DONE
	var/obj/structure/closet/container = doer.loc
	if(istype(container))
		var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
		// Right outside: they push it open themselves
		if(get_dist(container, person) <= 1 && container.open())
			return AMBIENT_STEP_DONE
		if(istype(survivor) && survivor.reaction_ready("bang", 6 SECONDS))
			survivor.bang_on(container)
		return AMBIENT_STEP_CONTINUE
	if(spot && get_dist(doer, person) > 2)
		if(LAZYACCESS(failed_spots, there))
			return AMBIENT_STEP_DONE
		go_to(there, 2)
		return AMBIENT_STEP_MOVE
	if(!doer.buckled)
		doer.face_atom(person)
	return AMBIENT_STEP_DONE

/datum/ambient_activity/survivor_call/finish()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(istype(survivor) && isturf(survivor.loc))
		survivor.hide_spot = survivor.loc
	return ..()

/// Running from something, then down in a crouch wherever they got to
/datum/ambient_activity/survivor_flee
	name = "running"
	priority = SURVIVOR_FLEE_PRIORITY
	/// How many more times a threat that keeps coming can send them on
	var/runs_left = SURVIVOR_FLEE_RUNS

/datum/ambient_activity/survivor_flee/setup()
	var/mob/living/threat = anchor()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(!isliving(threat) || !istype(survivor))
		return FALSE
	ends_at = world.time + SURVIVOR_FLEE_TIME
	if(survivor.reaction_ready("flee_line", 6 SECONDS))
		doer.speak_context("flee", threat, force = TRUE)
	var/turf/away = isturf(doer.loc) ? survivor.flee_tile(threat, failed_spots) : null
	if(away)
		doer.stand_up()
		go_to(away)
	else
		// Nowhere to go: down, arms over their head
		doer.crouch()
	return TRUE

/datum/ambient_activity/survivor_flee/arrive()
	doer.crouch()

/datum/ambient_activity/survivor_flee/act(seconds)
	var/mob/living/threat = anchor()
	if(!threat || threat.stat != CONSCIOUS)
		return AMBIENT_STEP_DONE
	if(runs_left > 0 && get_dist(doer, threat) <= 2 && isturf(doer.loc))
		var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
		var/turf/away = survivor.flee_tile(threat, failed_spots)
		if(away)
			runs_left--
			doer.stand_up()
			go_to(away)
			return AMBIENT_STEP_MOVE
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/survivor_flee/finish()
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(istype(survivor) && isturf(survivor.loc))
		survivor.hide_spot = survivor.loc
	return ..()

/// At their rescuer's side as they move, facing them when they stop; out of anything they get shut in
/datum/ambient_activity/survivor_follow
	name = "following"
	priority = SURVIVOR_FOLLOW_PRIORITY
	spot_distance = 1
	/// world.time their rescuer went out of reach, or 0
	var/lost_since = 0
	/// They called out for their rescuer since losing them
	var/called_lost = FALSE

/datum/ambient_activity/survivor_follow/setup()
	if(!isliving(anchor()))
		return FALSE
	next_line = world.time + rand(40 SECONDS, 80 SECONDS)
	return TRUE

/// Whether `leader` can still be followed: alive, on this level, near enough
/datum/ambient_activity/survivor_follow/proc/in_reach(mob/living/leader)
	var/turf/there = get_turf(leader)
	var/turf/here = get_turf(doer)
	return leader && leader.stat != DEAD && there && here && there.z == here.z && get_dist(here, there) <= SURVIVOR_FOLLOW_RANGE

// Where they go is wherever their rescuer is now
/datum/ambient_activity/survivor_follow/at_spot()
	if(!isturf(doer.loc))
		return TRUE // act() gets them out first
	var/mob/living/leader = anchor()
	if(!in_reach(leader) || get_dist(doer, leader) <= 1)
		return TRUE
	if(doer.crouching)
		doer.stand_up()
	var/turf/there = get_turf(leader)
	if(spot != there)
		go_to(there, 1)
	return FALSE

/datum/ambient_activity/survivor_follow/act(seconds)
	var/mob/living/basic/ambient_npc/mission_survivor/survivor = doer
	if(!istype(survivor))
		return AMBIENT_STEP_DONE
	if(!isturf(doer.loc))
		survivor.climb_out()
		return AMBIENT_STEP_CONTINUE
	var/mob/living/leader = anchor()
	if(leader?.stat == DEAD && get_dist(doer, leader) <= SURVIVOR_SIGHT)
		survivor.leader_fell(leader)
		return AMBIENT_STEP_DONE
	if(!in_reach(leader))
		if(!lost_since)
			lost_since = world.time
		if(!called_lost && world.time - lost_since > 8 SECONDS)
			called_lost = TRUE
			doer.speak_context("lost", null, force = TRUE)
		if(world.time - lost_since >= SURVIVOR_LOST_TIME)
			survivor.lose_leader()
			return AMBIENT_STEP_DONE
		return AMBIENT_STEP_CONTINUE
	lost_since = 0
	called_lost = FALSE
	if(get_dist(doer, leader) <= 2 && !doer.buckled)
		doer.face_atom(leader)
	survivor.check_aboard()
	chatter("follow_idle", 60 SECONDS, 120 SECONDS)
	return AMBIENT_STEP_CONTINUE

// A spot they could not reach is just their rescuer's last one: they try again from where they are
/datum/ambient_activity/survivor_follow/spot_unreachable()
	spot = null
	arrived = FALSE

// =========================================================================
// WHERE THEY HIDE
// =========================================================================

/**
 * Where a survivor hides at `target`, looking around `near` (the site's spawn point): list(turf,
 * locker or null). Half the time a locker if there is one (they get in it), otherwise a corner or
 * an alcove, never beside open space or on a docked ship, and never within
 * SURVIVOR_SHELTER_THREAT_GAP of anything hostile already loose in there. Falls back to `near`.
 *
 * Bounded (a square of SURVIVOR_SHELTER_RADIUS around `near`) and never sleeps: it runs from the
 * site's loaded signal.
 */
/proc/mission_survivor_hiding_place(turf/near, datum/mission_target/target)
	. = list(near, null)
	if(!near || !target)
		return
	var/list/dangers = list()
	for(var/mob/living/thing as anything in GLOB.mob_living_list)
		if(thing.z != near.z || thing.stat == DEAD || thing.client)
			continue
		if(get_dist(thing, near) > SURVIVOR_SHELTER_RADIUS + SURVIVOR_SHELTER_THREAT_GAP)
			continue
		if(FACTION_NEUTRAL in thing.faction)
			continue
		if(mission_survivor_dangerous(thing))
			dangers += get_turf(thing)
	var/list/lockers = list()
	var/list/nooks = list()
	var/best_cover = 0
	for(var/turf/open/tile in RANGE_TURFS(SURVIVOR_SHELTER_RADIUS, near))
		if(isspaceturf(tile) || isgroundlessturf(tile) || islava(tile) || ischasm(tile))
			continue
		if(istype(tile.loc, /area/shuttle) || !target.contains_turf(tile))
			continue
		if(length(dangers) && ambient_too_close(tile, dangers, SURVIVOR_SHELTER_THREAT_GAP))
			continue
		var/obj/structure/closet/locker = locate() in tile
		if(locker)
			if(mission_survivor_locker_ok(locker))
				lockers += locker
			continue
		if(tile.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/cover = mission_survivor_cover(tile)
		if(cover < SURVIVOR_SHELTER_MIN_COVER)
			continue
		nooks[tile] = cover
		best_cover = max(best_cover, cover)
	if(length(lockers) && (prob(50) || !length(nooks)))
		var/obj/structure/closet/locker = pick(lockers)
		return list(get_turf(locker), locker)
	if(!length(nooks))
		return
	// The snuggest spots, not always the single snuggest one
	var/list/best = list()
	for(var/turf/tile as anything in nooks)
		if(nooks[tile] >= best_cover - 1)
			best += tile
	return list(pick(best), null)

/// Neighbours (of 8) of `tile` that are walls or blocked, or 0 if it opens onto space or has no free way in
/proc/mission_survivor_cover(turf/tile)
	var/blocked = 0
	var/way_in = FALSE
	for(var/direction in GLOB.alldirs)
		var/turf/neighbour = get_step(tile, direction)
		if(!neighbour || isspaceturf(neighbour) || isgroundlessturf(neighbour))
			return 0
		if(neighbour.is_blocked_turf(exclude_mobs = TRUE))
			blocked++
		else if(direction in GLOB.cardinals)
			way_in = TRUE
	return way_in ? blocked : 0

/// A locker a survivor can shut themselves in, and that someone can get to and open
/proc/mission_survivor_locker_ok(obj/structure/closet/locker)
	if(locker.locked || locker.welded || locker.wall_mounted || locker.horizontal)
		return FALSE
	if(istype(locker, /obj/structure/closet/body_bag) || (locker.resistance_flags & INDESTRUCTIBLE))
		return FALSE
	if(locker.max_mob_size < MOB_SIZE_HUMAN || locker.mob_storage_capacity < 1 || (locate(/mob/living) in locker))
		return FALSE
	if(locker.opened && !locker.can_close())
		return FALSE
	for(var/direction in GLOB.cardinals)
		var/turf/neighbour = get_step(locker, direction)
		if(neighbour && !isspaceturf(neighbour) && !neighbour.is_blocked_turf(exclude_mobs = TRUE))
			return TRUE
	return FALSE

/**
 * Whether `thing` is out to hurt people: a hostile legacy animal, or a mob whose AI picks targets.
 * Faction is the caller's business.
 */
/proc/mission_survivor_dangerous(mob/living/thing)
	if(istype(thing, /mob/living/simple_animal/hostile))
		return TRUE
	return !!thing.ai_controller?.blackboard[BB_TARGETING_STRATEGY]

#undef SURVIVOR_SIGHT
#undef SURVIVOR_LOOK_INTERVAL
#undef SURVIVOR_FLEE_DISTANCE
#undef SURVIVOR_FLEE_RANGE
#undef SURVIVOR_FLEE_TIME
#undef SURVIVOR_FLEE_RUNS
#undef SURVIVOR_DISTRESS_RANGE
#undef SURVIVOR_DISTRESS_GAP_LOW
#undef SURVIVOR_DISTRESS_GAP_HIGH
#undef SURVIVOR_APPROACH_RANGE
#undef SURVIVOR_NEAR_RANGE
#undef SURVIVOR_HEARING_RANGE
#undef SURVIVOR_FOLLOW_RANGE
#undef SURVIVOR_LOST_TIME
#undef SURVIVOR_FOLLOW_PRIORITY
#undef SURVIVOR_FLEE_PRIORITY
#undef SURVIVOR_DUCK_TIME
#undef SURVIVOR_DUCK_COOLDOWN
#undef SURVIVOR_SHELTER_RADIUS
#undef SURVIVOR_SHELTER_THREAT_GAP
#undef SURVIVOR_SHELTER_MIN_COVER
#undef SURVIVOR_BEAM_TIME
#undef SURVIVOR_BEAM_DROP
#undef SURVIVOR_BEAM_WATCH_RANGE
#undef SURVIVOR_TRAIT
