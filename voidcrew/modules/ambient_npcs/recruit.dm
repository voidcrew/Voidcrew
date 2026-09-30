/**
 * # World population: taking a stray aboard (spec 5.1)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * Owner decision D1: recruits are AI deckhands only. No ghost poll, no ghost role, no body swap.
 *
 * A stray (/mob/living/basic/ambient_npc/stray: the stranded survivor, the lifeboat survivor, a
 * convict who was talked down) goes through three states:
 * - wild: where they were found. An empty hand from a member of a ship crew is a plea and a
 *   choice, "Come with us" or "Not now". They wave down crew members they see.
 * - following: they agreed to join that crew's ship and follow whoever asked them. A leader out
 *   of reach for STRAY_LOST_TIME (dead, gone, off the level) loses them: they go back to being wild.
 * - deckhand: they stepped aboard that ship. They live there under the ship's
 *   /datum/ambient_place/ship, which keeps them aboard: they sit in chairs, wash at the sink, lie
 *   down in a bunk, look out of the windows, chat with each other and talk to the crew. A crew
 *   member can have them follow or stay, and let them go at a trader outpost.
 *
 * Limits (per ship, kept on its place): AMBIENT_RECRUITS_PENDING_PER_SHIP following at once,
 * AMBIENT_RECRUITS_PER_SHIP_ROUND taken aboard in a round. A stray taken aboard spends the site they
 * came from, so it never brings them back.
 *
 * Nothing here pays anything, and a deckhand drops nothing when killed.
 */

/// Where they were found, open to an offer
#define STRAY_WILD "wild"
/// Agreed to join a ship and following someone of its crew there
#define STRAY_FOLLOWING "following"
/// Aboard the ship they joined
#define STRAY_DECKHAND "deckhand"
/// A follower whose leader is out of reach this long goes back to being wild
#define STRAY_LOST_TIME (60 SECONDS)
/// Beyond this many tiles, a leader is out of reach
#define STRAY_FOLLOW_RANGE 12
/// A wild stray looks around for crew this often
#define STRAY_LOOK_INTERVAL (2 SECONDS)
/// How far a stray sees a crew member to wave them down
#define STRAY_GREET_RANGE 7
/// Following outranks a reaction (a storm does not stop it) and gives way to leaving
#define STRAY_FOLLOW_PRIORITY 60
/// A deckhand off their ship tries this many times to walk back aboard before they give up
#define STRAY_REHOME_TRIES 2
/// ...this far apart
#define STRAY_REHOME_COOLDOWN (30 SECONDS)
/// Trait source for what the recruit flow puts on a stray
#define STRAY_TRAIT "ambient_stray"

/// "[REF(ship)]" -> /datum/ambient_place/ship: every ship that took or is taking a stray this round
GLOBAL_LIST_EMPTY(ambient_ship_places)

// =========================================================================
// API
// =========================================================================

/**
 * Lets a crew member ask `stray` to come with them: opens a stray to offers, and the flow above
 * runs from their talked_to(). Returns TRUE for a stray, FALSE for anyone else.
 */
/proc/ambient_offer_recruit(mob/living/basic/ambient_npc/stray)
	var/mob/living/basic/ambient_npc/stray/recruit = stray
	if(!istype(recruit) || QDELETED(recruit))
		return FALSE
	recruit.recruit_open = TRUE
	return TRUE

/// The player ship `user` is crew of, or null: the first of their crews whose ship is still flying and not an NPC's
/proc/ambient_crew_ship(mob/living/user)
	if(!isliving(user) || !user.mind)
		return null
	for(var/datum/team/voidcrew/crew as anything in user.mind.ship_teams)
		var/obj/structure/overmap/ship/ship = crew?.ship
		if(QDELETED(ship) || ship.abandoned || istype(ship, /obj/structure/overmap/ship/npc))
			continue
		return ship
	return null

/// `ship`'s deckhand place, made the first time it is needed if `create`
/proc/ambient_ship_place(obj/structure/overmap/ship/ship, create = TRUE)
	if(QDELETED(ship))
		return null
	var/key = REF(ship)
	var/datum/ambient_place/ship/place = GLOB.ambient_ship_places[key]
	if(!place && create)
		place = new(ship)
		GLOB.ambient_ship_places[key] = place
	return place

/// Whether `ship` may take another stray now (nobody else on the way, and under the round's limit)
/proc/ambient_ship_can_take(obj/structure/overmap/ship/ship)
	if(QDELETED(ship))
		return FALSE
	var/datum/ambient_place/ship/place = ambient_ship_place(ship, create = FALSE)
	return !place || place.can_take()

// =========================================================================
// THE SHIP'S PLACE
// =========================================================================

/**
 * The strays a ship took aboard: their leash (the ship's own rooms), their speech clock, and the
 * ship's limits. Made the first time a stray agrees to join the ship; kept for the round.
 */
/datum/ambient_place/ship
	name = "a ship"
	/// The ship
	var/datum/weakref/ship_ref
	/// Strays taken aboard this round
	var/taken = 0
	/// The stray on their way aboard, if any
	var/datum/weakref/pending_ref

/datum/ambient_place/ship/New(obj/structure/overmap/ship/ship)
	. = ..()
	if(!ship)
		return
	ship_ref = WEAKREF(ship)
	name = ship.name
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_ship_deleted))

/datum/ambient_place/ship/Destroy()
	var/obj/structure/overmap/ship/ship = ship()
	if(ship)
		UnregisterSignal(ship, COMSIG_QDELETING)
	for(var/key in GLOB.ambient_ship_places.Copy())
		if(GLOB.ambient_ship_places[key] == src)
			GLOB.ambient_ship_places -= key
	pending_ref = null
	return ..()

/// The ship, if it is still there
/datum/ambient_place/ship/proc/ship()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	return QDELETED(ship) ? null : ship

/// The stray on their way aboard, if they still are
/datum/ambient_place/ship/proc/pending()
	var/mob/living/basic/ambient_npc/stray/stray = pending_ref?.resolve()
	if(QDELETED(stray) || stray.stat == DEAD || !stray.is_following())
		pending_ref = null
		return null
	return stray

/// Whether it may take another stray now
/datum/ambient_place/ship/proc/can_take()
	var/on_the_way = pending() ? 1 : 0
	if(on_the_way >= AMBIENT_RECRUITS_PENDING_PER_SHIP)
		return FALSE
	return taken + on_the_way < AMBIENT_RECRUITS_PER_SHIP_ROUND

/// Whether `tile` is aboard the ship. Override (tests).
/datum/ambient_place/ship/proc/aboard(turf/tile)
	var/obj/structure/overmap/ship/ship = ship()
	return !!ship?.is_aboard(tile)

/// The trader outpost the ship is docked at, if any
/datum/ambient_place/ship/proc/docked_outpost()
	var/obj/structure/overmap/ship/ship = ship()
	var/obj/structure/overmap/trader_outpost/outpost = ship?.docked
	return istype(outpost) ? outpost : null

// Aboard, and nowhere else
/datum/ambient_place/ship/leash_ok(turf/tile, mob/living/basic/ambient_npc/npc)
	return aboard(tile)

/datum/ambient_place/ship/spot_allowed(turf/tile, mob/living/basic/ambient_npc/npc)
	return aboard(tile)

/datum/ambient_place/ship/describe()
	return "[name]: [length(living_npcs())] aboard, [taken] taken this round[pending() ? ", one on the way" : ""]"

/// The ship is gone: so are the strays who lived on it
/datum/ambient_place/ship/proc/on_ship_deleted(datum/source)
	SIGNAL_HANDLER
	for(var/mob/living/basic/ambient_npc/npc as anything in npcs.Copy())
		if(!QDELETED(npc) && !npc.ckey)
			npc.fade_out(instant = TRUE)
	qdel(src)

// =========================================================================
// THE STRAY
// =========================================================================

/**
 * Someone found far from anywhere who will join a ship's crew if asked. Killable, drops nothing
 * (not even cash: a crew's own deckhands are no purse).
 * Subtypes set their look, their dialogue section and what they do while wild.
 */
/mob/living/basic/ambient_npc/stray
	name = "stranded spacer"
	desc = "Someone a long way from anywhere."
	death_cash_low = 0
	death_cash_high = 0
	rotate_on_lying = TRUE
	dialogue_file = AMBIENT_STRINGS_STRAYS
	dialogue_section = "stranded"
	routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/sit = 1,
	)
	/// A crew member may ask them along (ambient_offer_recruit())
	var/recruit_open = TRUE
	/// STRAY_WILD, STRAY_FOLLOWING or STRAY_DECKHAND
	var/stray_state = STRAY_WILD
	/// Their own section of the strays file, kept once they are a deckhand: their "aboard" line comes from it
	var/origin_section
	/// The ship they agreed to join
	var/datum/weakref/ship_ref
	/// Who they follow, if anyone
	var/datum/weakref/leader_ref
	/// world.time they next look around for crew
	var/next_look = 0
	/// REFs of the players they already waved down
	var/list/greeted
	/// Tries left to walk back aboard, and when the next may start
	var/rehome_tries = 0
	var/rehome_at = 0
	/// What they do aboard as a deckhand
	var/list/deckhand_routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/sit = 3,
		/datum/ambient_activity/chat = 1,
		/datum/ambient_activity/stray_wash = 1,
		/datum/ambient_activity/stray_rest = 1,
		/datum/ambient_activity/stray_window = 1,
		/datum/ambient_activity/stray_crew = 1,
	)

/**
 * `identity` (from stray_identity()) makes them the same person they were on an earlier visit:
 * list("name", "gender", "outfit", "look").
 */
/mob/living/basic/ambient_npc/stray/Initialize(mapload, list/identity)
	if(islist(identity))
		if(identity["gender"] == MALE || identity["gender"] == FEMALE)
			random_gender = FALSE
			gender = identity["gender"]
		if(ispath(identity["outfit"], /datum/outfit))
			outfit_choices = null
			outfit = identity["outfit"]
		if(isnum(identity["look"]))
			look_number = identity["look"]
	origin_section = dialogue_section
	. = ..()
	if(islist(identity) && istext(identity["name"]))
		name = identity["name"]
		real_name = name

/mob/living/basic/ambient_npc/stray/Destroy()
	release_pending()
	leader_ref = null
	ship_ref = null
	greeted = null
	return ..()

/// Who they are, to make the same person again later
/mob/living/basic/ambient_npc/stray/proc/stray_identity()
	return list("name" = real_name, "gender" = gender, "outfit" = outfit, "look" = look_number)

/mob/living/basic/ambient_npc/stray/proc/is_wild()
	return stray_state == STRAY_WILD

/mob/living/basic/ambient_npc/stray/proc/is_following()
	return stray_state == STRAY_FOLLOWING

/mob/living/basic/ambient_npc/stray/proc/is_deckhand()
	return stray_state == STRAY_DECKHAND

/// The ship they joined, if it is still there
/mob/living/basic/ambient_npc/stray/proc/get_ship()
	var/obj/structure/overmap/ship/ship = ship_ref?.resolve()
	return QDELETED(ship) ? null : ship

/// Who they follow, if anyone
/mob/living/basic/ambient_npc/stray/proc/get_leader()
	var/mob/living/leader = leader_ref?.resolve()
	return QDELETED(leader) ? null : leader

/// Frees their ship's place for someone else, if they were on their way aboard
/mob/living/basic/ambient_npc/stray/proc/release_pending()
	var/obj/structure/overmap/ship/ship = get_ship()
	var/datum/ambient_place/ship/deck = ship && ambient_ship_place(ship, create = FALSE)
	if(deck && deck.pending_ref?.resolve() == src)
		deck.pending_ref = null

/mob/living/basic/ambient_npc/stray/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(stat != CONSCIOUS || fading || QDELETED(src))
		return
	switch(stray_state)
		if(STRAY_FOLLOWING)
			var/obj/structure/overmap/ship/ship = get_ship()
			var/datum/ambient_place/ship/deck = ship && ambient_ship_place(ship)
			if(!deck)
				lose_leader()
			else if(deck.aboard(get_turf(src)))
				board(ship)
		if(STRAY_WILD)
			if(recruit_open && world.time >= next_look)
				next_look = world.time + STRAY_LOOK_INTERVAL
				look_for_crew()

/mob/living/basic/ambient_npc/stray/death(gibbed)
	. = ..()
	release_pending()
	leader_ref = null

// ----- leash -----

// Following, they go wherever their leader leads that they can cross; aboard, the ship's place keeps them there
/mob/living/basic/ambient_npc/stray/leash_ok(turf/tile)
	if(stray_state == STRAY_FOLLOWING && istype(activity, /datum/ambient_activity/stray_follow))
		tile = get_turf(tile)
		return !!tile?.can_cross_safely(src)
	return ..()

// A deckhand off their ship walks back aboard if they can, a couple of times, before they give up
/mob/living/basic/ambient_npc/stray/give_up_leash()
	if(stray_state == STRAY_DECKHAND && rehome_tries < STRAY_REHOME_TRIES)
		if(world.time < rehome_at)
			return
		rehome_tries++
		rehome_at = world.time + STRAY_REHOME_COOLDOWN
		var/obj/structure/overmap/ship/ship = get_ship()
		var/turf/aboard = ship?.get_random_open_ship_turf()
		if(aboard && isturf(loc) && aboard.z == z && get_dist(src, aboard) <= AMBIENT_PATH_LENGTH)
			home = aboard
			if(start_activity(new /datum/ambient_activity/go_home(src)))
				return
	return ..()

// Aboard, where they are now is home
/mob/living/basic/ambient_npc/stray/pick_activity()
	if(stray_state == STRAY_DECKHAND && leash_ok(loc))
		home = get_turf(src)
		rehome_tries = 0
	return ..()

// ----- talking -----

/mob/living/basic/ambient_npc/stray/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	speak_context(AMBIENT_LINE_TALK, user, force = TRUE)
	var/obj/structure/overmap/ship/ship = ambient_crew_ship(user)
	if(!ship)
		return
	switch(stray_state)
		if(STRAY_WILD)
			if(recruit_open && ambient_ship_can_take(ship))
				INVOKE_ASYNC(src, PROC_REF(offer_menu), user, ship)
		if(STRAY_DECKHAND)
			if(ship == get_ship())
				INVOKE_ASYNC(src, PROC_REF(crew_menu), user)

/// "Come with us" or "Not now", for `user` of `ship`. Sleeps.
/mob/living/basic/ambient_npc/stray/proc/offer_menu(mob/living/user, obj/structure/overmap/ship/ship)
	var/list/choices = list(
		"Come with us" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes"),
		"Not now" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no"),
	)
	var/choice = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(QDELETED(src) || QDELETED(user) || !can_act() || stray_state != STRAY_WILD)
		return
	switch(choice)
		if("Come with us")
			if(get_dist(src, user) <= 2 && ambient_crew_ship(user) == ship)
				accept_offer(user, ship)
		if("Not now")
			speak_context("refused", user, force = TRUE)

/// Follow or stay, and at a trader outpost, going their own way: for `user` of their ship. Sleeps.
/mob/living/basic/ambient_npc/stray/proc/crew_menu(mob/living/user)
	var/list/choices = list()
	if(get_leader() == user && istype(activity, /datum/ambient_activity/stray_follow))
		choices["Stay here"] = image(icon = 'icons/hud/radial.dmi', icon_state = "guard")
	else
		choices["Follow me"] = image(icon = 'icons/hud/radial.dmi', icon_state = "move")
	var/datum/ambient_place/ship/deck = place
	if(istype(deck) && deck.docked_outpost())
		choices["Time to go"] = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_eject")
	var/choice = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE, autopick_single_option = FALSE)
	if(QDELETED(src) || QDELETED(user) || !can_act() || stray_state != STRAY_DECKHAND || ambient_crew_ship(user) != get_ship())
		return
	switch(choice)
		if("Follow me")
			if(start_follow(user))
				speak_context("follow", user, force = TRUE)
		if("Stay here")
			stop_follow()
			speak_context("wait", user, force = TRUE)
		if("Time to go")
			dismiss(user)

// ----- joining -----

/**
 * They agree to join `ship`, and follow `leader` there. Returns TRUE, or FALSE if they can't now
 * (not wild, not open to offers, or the ship has no room).
 */
/mob/living/basic/ambient_npc/stray/proc/accept_offer(mob/living/leader, obj/structure/overmap/ship/ship)
	if(stray_state != STRAY_WILD || !recruit_open || !can_act() || QDELETED(ship) || QDELETED(leader))
		return FALSE
	var/datum/ambient_place/ship/deck = ambient_ship_place(ship)
	if(!deck?.can_take())
		return FALSE
	ship_ref = WEAKREF(ship)
	deck.pending_ref = WEAKREF(src)
	stray_state = STRAY_FOLLOWING
	// Out through the airlock and across to the ship, whatever lies between
	ADD_TRAIT(src, TRAIT_SPACEWALK, STRAY_TRAIT)
	if(!start_follow(leader))
		release_pending()
		ship_ref = null
		leader_ref = null
		stray_state = STRAY_WILD
		REMOVE_TRAIT(src, TRAIT_SPACEWALK, STRAY_TRAIT)
		return FALSE
	on_joined(ship)
	speak_context("accepted", leader, force = TRUE)
	log_game("AMBIENT: [src] agreed to join the [ship.name], asked by [key_name(leader)] at [AREACOORD(src)]")
	return TRUE

/// They agreed to join `ship`. Override (the lifeboat stops calling).
/mob/living/basic/ambient_npc/stray/proc/on_joined(obj/structure/overmap/ship/ship)
	return

/**
 * They stepped aboard `ship`: a deckhand now, living there under its place, and the site they came
 * from is spent. Returns TRUE.
 */
/mob/living/basic/ambient_npc/stray/proc/board(obj/structure/overmap/ship/ship)
	var/datum/ambient_place/ship/deck = ambient_ship_place(ship)
	if(!deck)
		return FALSE
	if(deck.pending_ref?.resolve() == src)
		deck.pending_ref = null
	deck.taken++
	// The site they were found at never brings them back
	var/datum/ambient_place/site/old_site = place
	if(istype(old_site))
		old_site.data["taken"] = TRUE
		old_site.state = AMBIENT_SITE_SPENT
	stray_state = STRAY_DECKHAND
	ship_ref = WEAKREF(ship)
	leader_ref = null
	end_activity()
	set_place(deck)
	home = get_turf(src)
	leash_bounds = null
	routine = deckhand_routine.Copy()
	dialogue_section = "deckhand"
	var/list/lines = ambient_dialogue_lines(dialogue_file, origin_section, "aboard")
	if(length(lines))
		say_line(fill_line(pick(lines)))
	log_game("AMBIENT: [src] came aboard the [ship.name] as a deckhand")
	return TRUE

/// They follow `leader` from now on. Returns the activity, or null.
/mob/living/basic/ambient_npc/stray/proc/start_follow(mob/living/leader)
	if(QDELETED(leader))
		return null
	leader_ref = WEAKREF(leader)
	return start_activity(new /datum/ambient_activity/stray_follow(src, leader))

/// They stop following whoever it was
/mob/living/basic/ambient_npc/stray/proc/stop_follow()
	leader_ref = null
	if(istype(activity, /datum/ambient_activity/stray_follow))
		end_activity()

/**
 * Their leader is out of reach. A follower on the way to a ship goes back to being wild (and walks
 * back to where they were found, or slips away); a deckhand stays where they are.
 */
/mob/living/basic/ambient_npc/stray/proc/lose_leader()
	leader_ref = null
	if(stray_state == STRAY_FOLLOWING)
		release_pending()
		ship_ref = null
		stray_state = STRAY_WILD
		REMOVE_TRAIT(src, TRAIT_SPACEWALK, STRAY_TRAIT)
	if(istype(activity, /datum/ambient_activity/stray_follow))
		end_activity()
	speak_context("lost", null, force = TRUE)

/// Let go at a trader outpost by `user`: a goodbye, and they are off
/mob/living/basic/ambient_npc/stray/proc/dismiss(mob/living/user)
	speak_context("dismissed", user, force = TRUE)
	var/obj/structure/overmap/ship/ship = get_ship()
	log_game("AMBIENT: [src] left the [ship?.name || "ship"], let go by [key_name(user)]")
	start_activity(new /datum/ambient_activity/leave(src, null, 3 SECONDS))

// ----- reactions -----

// Hit by the crew they are following, they stop following
/mob/living/basic/ambient_npc/stray/react_attacked(atom/attacker)
	var/was_ready = LAZYACCESS(reaction_cooldowns, "attacked") <= world.time
	. = ..()
	if(!was_ready || stat != CONSCIOUS || stray_state != STRAY_FOLLOWING)
		return
	var/mob/living/hitter = attacker
	if(isliving(hitter) && ambient_crew_ship(hitter) == get_ship())
		lose_leader()

// ----- waving crew down -----

/// Waves down a crew member they can see and have not greeted yet
/mob/living/basic/ambient_npc/stray/proc/look_for_crew()
	if(!can_act() || activity?.priority >= AMBIENT_PRIORITY_REACTION)
		return FALSE
	var/turf/here = get_turf(src)
	if(!here)
		return FALSE
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, STRAY_GREET_RANGE))
		if(person == src || person.stat != CONSCIOUS)
			continue
		var/key = REF(person)
		if(LAZYFIND(greeted, key))
			continue
		if(!ambient_crew_ship(person) || !can_see(here, get_turf(person), STRAY_GREET_RANGE))
			continue
		LAZYADD(greeted, key)
		if(length(greeted) > 20)
			greeted.Cut(1, 2)
		return !!start_activity(new /datum/ambient_activity/stray_greet(src, person))
	return FALSE

// =========================================================================
// ACTIVITIES
// =========================================================================

/// Following their leader: to their side as they move, facing them when they stop
/datum/ambient_activity/stray_follow
	name = "following"
	priority = STRAY_FOLLOW_PRIORITY
	spot_distance = 1
	/// world.time their leader went out of reach, or 0
	var/lost_since = 0

/datum/ambient_activity/stray_follow/setup()
	if(!isliving(anchor()))
		return FALSE
	next_line = world.time + rand(60 SECONDS, 120 SECONDS)
	return TRUE

/// Whether `leader` can still be followed: alive, on this level, near enough
/datum/ambient_activity/stray_follow/proc/in_reach(mob/living/leader)
	var/turf/there = get_turf(leader)
	return leader && leader.stat != DEAD && there && isturf(doer.loc) && there.z == doer.z && get_dist(doer, there) <= STRAY_FOLLOW_RANGE

// Where they go is wherever their leader is now
/datum/ambient_activity/stray_follow/at_spot()
	var/mob/living/leader = anchor()
	if(!in_reach(leader) || get_dist(doer, leader) <= 1)
		return TRUE
	var/turf/there = get_turf(leader)
	// Not off the ship they live on
	if(!doer.leash_ok(there))
		return TRUE
	if(spot != there)
		go_to(there, 1)
	return FALSE

/datum/ambient_activity/stray_follow/act(seconds)
	var/mob/living/basic/ambient_npc/stray/stray = doer
	var/mob/living/leader = anchor()
	if(!in_reach(leader))
		if(!lost_since)
			lost_since = world.time
		if(world.time - lost_since >= STRAY_LOST_TIME)
			if(istype(stray))
				stray.lose_leader()
			return AMBIENT_STEP_DONE
		return AMBIENT_STEP_CONTINUE
	lost_since = 0
	if(get_dist(doer, leader) <= 2 && !doer.buckled)
		doer.face_atom(leader)
	chatter(AMBIENT_LINE_IDLE, 60 SECONDS, 120 SECONDS)
	return AMBIENT_STEP_CONTINUE

// A spot they could not reach is just their leader's last one: they try again from where they are
/datum/ambient_activity/stray_follow/spot_unreachable()
	spot = null
	arrived = FALSE

/// Waving down a crew member they spotted, and walking up to meet them
/datum/ambient_activity/stray_greet
	name = "waving someone down"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 25 SECONDS
	duration_high = 25 SECONDS
	spot_distance = 2

/datum/ambient_activity/stray_greet/setup()
	var/mob/living/person = anchor()
	if(!isliving(person))
		return FALSE
	set_duration()
	if(!doer.buckled)
		doer.face_atom(person)
	doer.manual_emote(pick("waves both arms over [doer.p_their()] head.", "waves.", "jumps and waves."))
	doer.speak_context("greet", person, force = TRUE)
	go_to(get_turf(person), 2)
	return TRUE

/datum/ambient_activity/stray_greet/act(seconds)
	var/mob/living/person = anchor()
	var/turf/there = get_turf(person)
	if(!person || person.stat == DEAD || there?.z != doer.z)
		return AMBIENT_STEP_DONE
	if(get_dist(doer, person) > 2)
		if(LAZYACCESS(failed_spots, get_turf(person)))
			return AMBIENT_STEP_DONE
		go_to(get_turf(person), 2)
		return AMBIENT_STEP_MOVE
	if(!doer.buckled)
		doer.face_atom(person)
	return AMBIENT_STEP_DONE

/// Washing up at a sink
/datum/ambient_activity/stray_wash
	name = "washing up"
	accepts_company = TRUE
	duration_low = 8 SECONDS
	duration_high = 15 SECONDS
	var/datum/weakref/sink_ref

/datum/ambient_activity/stray_wash/setup()
	var/turf/center = get_turf(doer)
	if(!center)
		return FALSE
	var/obj/structure/sink/best
	var/turf/best_stand
	var/best_distance = INFINITY
	for(var/obj/structure/sink/sink in range(AMBIENT_ACTIVITY_RANGE, center))
		var/turf/sink_turf = get_turf(sink)
		if(!isturf(sink.loc) || !doer.leash_ok(sink_turf))
			continue
		var/turf/stand = doer.standable(sink_turf, failed_spots) ? sink_turf : doer.free_tile_beside(sink, 1, failed_spots)
		var/distance = get_dist(doer, sink)
		if(stand && distance < best_distance)
			best = sink
			best_stand = stand
			best_distance = distance
	if(!best)
		return FALSE
	sink_ref = WEAKREF(best)
	go_to(best_stand)
	set_duration()
	next_line = world.time + rand(3 SECONDS, 6 SECONDS)
	return TRUE

/datum/ambient_activity/stray_wash/arrive()
	var/obj/structure/sink/sink = sink_ref?.resolve()
	if(!sink)
		return
	if(!doer.buckled && get_turf(sink) != doer.loc)
		doer.face_atom(sink)
	doer.manual_emote("washes [doer.p_their()] hands in [sink].")
	playsound(sink, 'sound/machines/sink-faucet.ogg', 25, TRUE)

/datum/ambient_activity/stray_wash/act(seconds)
	if(!sink_ref?.resolve())
		return AMBIENT_STEP_DONE
	chatter("wash", 60 SECONDS, 120 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// Lying down in a free bunk for a while
/datum/ambient_activity/stray_rest
	name = "resting"
	duration_low = 90 SECONDS
	duration_high = 3 MINUTES
	var/datum/weakref/bed_ref

/datum/ambient_activity/stray_rest/setup()
	var/turf/center = get_turf(doer)
	if(!center)
		return FALSE
	var/obj/structure/bed/best
	var/best_distance = INFINITY
	for(var/obj/structure/bed/bed in range(AMBIENT_ACTIVITY_RANGE, center))
		if(!isturf(bed.loc) || bed.has_buckled_mobs() || !doer.standable(bed.loc, failed_spots))
			continue
		var/distance = get_dist(doer, bed)
		if(distance < best_distance)
			best = bed
			best_distance = distance
	if(!best)
		return FALSE
	bed_ref = WEAKREF(best)
	go_to(get_turf(best))
	set_duration()
	return TRUE

/datum/ambient_activity/stray_rest/arrive()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(!bed || doer.loc != bed.loc || bed.has_buckled_mobs())
		bed_ref = null
		return
	doer.stand_up()
	if(!bed.buckle_mob(doer, force = TRUE))
		bed_ref = null
		return
	doer.manual_emote("lies down on [bed].")

/datum/ambient_activity/stray_rest/act(seconds)
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(!bed || doer.buckled != bed)
		return AMBIENT_STEP_DONE
	if(prob(2))
		doer.manual_emote(pick("turns over.", "snores quietly."))
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/stray_rest/finish()
	var/obj/structure/bed/bed = bed_ref?.resolve()
	if(!QDELETED(doer) && bed && doer.buckled == bed)
		bed.unbuckle_mob(doer, force = TRUE)
	return ..()

/datum/ambient_activity/stray_rest/spot_unreachable()
	. = ..()
	bed_ref = null

/// Standing at a window, looking out
/datum/ambient_activity/stray_window
	name = "looking out"
	accepts_company = TRUE
	duration_low = 20 SECONDS
	duration_high = 45 SECONDS
	var/datum/weakref/window_ref

/datum/ambient_activity/stray_window/setup()
	var/turf/center = get_turf(doer)
	if(!center)
		return FALSE
	var/obj/structure/window/best
	var/turf/best_stand
	var/best_distance = INFINITY
	for(var/obj/structure/window/window in range(AMBIENT_ACTIVITY_RANGE, center))
		var/distance = get_dist(doer, window)
		if(distance >= best_distance || !isturf(window.loc))
			continue
		var/turf/stand = doer.free_tile_beside(window, 1, failed_spots)
		if(!stand)
			continue
		best = window
		best_stand = stand
		best_distance = distance
	if(!best)
		return FALSE
	window_ref = WEAKREF(best)
	go_to(best_stand)
	set_duration()
	next_line = world.time + rand(10 SECONDS, 20 SECONDS)
	return TRUE

/datum/ambient_activity/stray_window/arrive()
	var/obj/structure/window/window = window_ref?.resolve()
	if(window && !doer.buckled)
		doer.face_atom(window)
	if(prob(50))
		doer.manual_emote("looks out of the window.")

/datum/ambient_activity/stray_window/act(seconds)
	if(!window_ref?.resolve())
		return AMBIENT_STEP_DONE
	chatter("window", 45 SECONDS, 90 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// A word with someone of the crew they live with
/datum/ambient_activity/stray_crew
	name = "talking to the crew"
	duration_low = 20 SECONDS
	duration_high = 20 SECONDS
	spot_distance = 1
	/// They said their line
	var/spoke = FALSE

/datum/ambient_activity/stray_crew/setup()
	var/mob/living/basic/ambient_npc/stray/stray = doer
	var/obj/structure/overmap/ship/ship = istype(stray) ? stray.get_ship() : null
	var/turf/here = get_turf(doer)
	if(!ship || !here)
		return FALSE
	var/list/options = list()
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, AMBIENT_ACTIVITY_RANGE))
		if(person.stat != CONSCIOUS || person.combat_mode || ambient_crew_ship(person) != ship)
			continue
		if(!doer.leash_ok(get_turf(person)))
			continue
		options += person
	if(!length(options))
		return FALSE
	var/mob/living/person = pick(options)
	anchor_ref = WEAKREF(person)
	set_duration()
	go_to(get_turf(person), 1)
	return TRUE

/datum/ambient_activity/stray_crew/at_spot()
	var/mob/living/person = anchor()
	if(!person || get_dist(doer, person) <= 1)
		return TRUE
	var/turf/there = get_turf(person)
	if(!there || there.z != doer.z || !doer.leash_ok(there))
		return TRUE
	if(spot != there)
		go_to(there, 1)
	return FALSE

/datum/ambient_activity/stray_crew/act(seconds)
	var/mob/living/person = anchor()
	if(!person || person.stat != CONSCIOUS || get_dist(doer, person) > 1)
		return AMBIENT_STEP_DONE
	if(!doer.buckled)
		doer.face_atom(person)
	if(!spoke)
		spoke = TRUE
		doer.speak_context("crew", person, force = TRUE)
		ends_at = min(ends_at, world.time + 6 SECONDS)
	return AMBIENT_STEP_CONTINUE

#undef STRAY_WILD
#undef STRAY_FOLLOWING
#undef STRAY_DECKHAND
#undef STRAY_LOST_TIME
#undef STRAY_FOLLOW_RANGE
#undef STRAY_LOOK_INTERVAL
#undef STRAY_GREET_RANGE
#undef STRAY_FOLLOW_PRIORITY
#undef STRAY_REHOME_TRIES
#undef STRAY_REHOME_COOLDOWN
#undef STRAY_TRAIT
