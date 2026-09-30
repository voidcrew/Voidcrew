/**
 * # World population: the angler at Pike's pond (owner item 5)
 *
 * Owner: PA (trader outpost life). P0 made this file as a stub; only PA edits it.
 *
 * Built here (spec 3.3): one angler at Halcyon's pond, already fishing with a line out when players
 * come (settle_in()), part-way through their stay; one who goes home is replaced off the lift. They pick
 * a spot at the pond's edge (an empty chair there, or a folding chair they bring, which goes when
 * they do), and fish with /datum/ambient_activity/fish, which PB owns (planet_fishers.dm): the line,
 * the wait and the catches, anchored on the water turf. Until PB's activity lands its setup()
 * refuses, and the angler sits at the water with a rod instead (pond_sit). Now and then they walk
 * a catch over to Pike, who has something to say about it, and let it go with a splash; the fish
 * held up is a picture from the pond's own fish table, never an item, and the pond's stock is never
 * touched. They follow players fishing near them and have a word when one lands or loses a fish.
 * Lines are in strings/outpost_workers.json (AMBIENT_STRINGS_WORKERS), section "angler".
 */

/// How long an angler stays before going home
#define ANGLER_VISIT_LOW (10 MINUTES)
#define ANGLER_VISIT_HIGH (20 MINUTES)
/// Chance, once they have fished, that the next thing they do is show Pike a catch
#define ANGLER_SHOW_CHANCE 25
/// Least time between two catches shown to Pike
#define ANGLER_SHOW_COOLDOWN (3 MINUTES)
/// How often they look round for players fishing near them
#define ANGLER_WATCH_EVERY (20 SECONDS)
/// How far away a player's fishing still gets a word
#define ANGLER_WATCH_RANGE 7
/// Pond tiles tried when looking for a spot at the edge
#define ANGLER_SPOT_TRIES 40

/// Waders over a grey jumpsuit, a beanie, galoshes and fishing gloves
/datum/outfit/ambient_angler
	name = "Pond angler"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/apron/waders
	head = /obj/item/clothing/head/beanie
	gloves = /obj/item/clothing/gloves/fishing
	shoes = /obj/item/clothing/shoes/galoshes

/// Camo trousers, an old field jacket and a battered fishing hat
/datum/outfit/ambient_angler/camo
	name = "Pond angler (field jacket)"
	uniform = /obj/item/clothing/under/pants/camo
	suit = /obj/item/clothing/suit/jacket/miljacket
	head = /obj/item/clothing/head/soft/fishing_hat
	gloves = null
	shoes = /obj/item/clothing/shoes/workboots

/mob/living/basic/ambient_npc/outpost/angler
	desc = "Here for the fish, and the quiet."
	dialogue_file = AMBIENT_STRINGS_WORKERS
	dialogue_section = "angler"
	outfit_choices = list(
		/datum/outfit/ambient_angler,
		/datum/outfit/ambient_angler/camo,
	)
	routine = list(/datum/ambient_activity/idle = 1)
	/// The pond tile they fish into
	var/turf/water
	/// The tile at the edge they fish from
	var/turf/fishing_spot
	/// The chair at their spot: one that was there, or the folding chair they brought
	var/datum/weakref/chair_ref
	/// They brought a folding chair (once a visit; it goes when they do)
	var/chair_brought = FALSE
	/// How many times they started fishing
	var/fish_sessions = 0
	/// world.time they go home
	var/leave_at = 0
	/// world.time they next look round for players fishing
	var/next_watch_at = 0
	/// world.time they may show Pike another catch
	var/next_show_at = 0
	/// Weakrefs to the players whose fishing they follow
	var/list/watched

/mob/living/basic/ambient_npc/outpost/angler/Initialize(mapload)
	. = ..()
	leave_at = world.time + rand(ANGLER_VISIT_LOW, ANGLER_VISIT_HIGH)

/mob/living/basic/ambient_npc/outpost/angler/Destroy()
	for(var/datum/weakref/ref as anything in watched)
		var/mob/living/player = ref.resolve()
		if(player)
			UnregisterSignal(player, COMSIG_MOB_COMPLETE_FISHING)
	watched = null
	var/obj/structure/chair/seat = chair_ref?.resolve()
	chair_ref = null
	if(chair_brought && !QDELETED(seat))
		qdel(seat)
	water = null
	fishing_spot = null
	return ..()

/mob/living/basic/ambient_npc/outpost/angler/pick_activity()
	if(world.time >= leave_at)
		if(prob(40))
			speak_context(AMBIENT_LINE_LEAVE)
		return start_activity(new /datum/ambient_activity/leave(src))
	if(!find_pond_spot())
		return start_activity(new /datum/ambient_activity/wander(src))
	if(fish_sessions > 0 && world.time >= next_show_at && prob(ANGLER_SHOW_CHANCE))
		next_show_at = world.time + ANGLER_SHOW_COOLDOWN
		if(start_activity(new /datum/ambient_activity/show_catch(src)))
			return activity
	// PB's fishing, anchored on the water (planet_fishers.dm)
	if(start_activity(new /datum/ambient_activity/fish(src, water)))
		fish_sessions++
		return activity
	return start_activity(new /datum/ambient_activity/pond_sit(src))

/// Here a while already: at the pond's edge in their chair with a line out, part-way through their stay
/mob/living/basic/ambient_npc/outpost/angler/settle_in()
	leave_at = ambient_part_way(leave_at)
	if(find_pond_spot())
		// PB's fishing, anchored on the water (planet_fishers.dm)
		if(settle_at(/datum/ambient_activity/fish, water, 1))
			fish_sessions++
			return TRUE
		if(settle_at(/datum/ambient_activity/pond_sit, null, 1))
			return TRUE
	return ..()

/mob/living/basic/ambient_npc/outpost/angler/shift_times(delay)
	. = ..()
	leave_at = ambient_shifted(leave_at, delay)
	next_watch_at = ambient_shifted(next_watch_at, delay)
	next_show_at = ambient_shifted(next_show_at, delay)

/// Whether `tile` is a place at the pond's edge they could fish from into `pond`
/mob/living/basic/ambient_npc/outpost/angler/proc/fishing_spot_ok(turf/tile, turf/open/water/pond)
	if(!tile || !istype(pond) || !isopenturf(tile) || istype(tile, /turf/open/water))
		return FALSE
	if(tile != loc && !standable(tile))
		return FALSE
	return tile.Adjacent(pond)

/**
 * Their spot at the pond's edge: the one they have while it still works, or a new one beside a pond
 * tile on the concourse floor. An empty chair already there is theirs to use; otherwise they bring
 * a folding chair, once a visit. FALSE when there is no pond or no room at it.
 */
/mob/living/basic/ambient_npc/outpost/angler/proc/find_pond_spot()
	if(water && fishing_spot && fishing_spot_ok(fishing_spot, water))
		return TRUE
	var/datum/ambient_place/outpost/outpost_place = place
	if(!istype(outpost_place))
		return FALSE
	var/list/floor = outpost_place.get_public_floor()
	var/list/ponds = list()
	for(var/turf/open/water/outpost_pond/pond in floor)
		ponds += pond
	for(var/attempt in 1 to min(ANGLER_SPOT_TRIES, length(ponds)))
		var/turf/open/water/pond = pick_n_take(ponds)
		for(var/direction in GLOB.cardinals)
			var/turf/stand = get_step(pond, direction)
			if(!fishing_spot_ok(stand, pond))
				continue
			water = pond
			fishing_spot = stand
			take_chair(stand, pond)
			return TRUE
	water = null
	fishing_spot = null
	return FALSE

/// A chair at `stand`: an empty one already there, their own folding chair moved over, or a new folding chair (once a visit)
/mob/living/basic/ambient_npc/outpost/angler/proc/take_chair(turf/stand, turf/pond)
	var/obj/structure/chair/seat = locate() in stand
	if(seat && seat_usable(seat))
		chair_ref = WEAKREF(seat)
		return seat
	var/obj/structure/chair/own = chair_ref?.resolve()
	if(chair_brought)
		if(!QDELETED(own) && isturf(own.loc) && !own.has_buckled_mobs())
			own.forceMove(stand)
			own.setDir(get_dir(stand, pond))
			return own
		return null
	chair_brought = TRUE
	var/obj/structure/chair/plastic/folding = new(stand)
	folding.setDir(get_dir(stand, pond))
	chair_ref = WEAKREF(folding)
	return folding

/// Sits in their chair if they are at it
/mob/living/basic/ambient_npc/outpost/angler/proc/sit_in_chair()
	if(buckled || fading)
		return
	var/obj/structure/chair/seat = chair_ref?.resolve()
	if(seat && seat.loc == loc && !seat.has_buckled_mobs())
		sit_on(seat)

/// Faces the water
/mob/living/basic/ambient_npc/outpost/angler/proc/face_water()
	if(water && !buckled && loc != water)
		face_atom(water)

/mob/living/basic/ambient_npc/outpost/angler/activity_step(seconds)
	. = ..()
	if(world.time >= next_watch_at)
		next_watch_at = world.time + ANGLER_WATCH_EVERY
		watch_players()
	// Back in their chair while they fish: the fishing stands them at the water's edge
	if(istype(activity, /datum/ambient_activity/fish) && activity.arrived)
		sit_in_chair()

/// Starts following the fishing of players near them, and stops for the ones who went
/mob/living/basic/ambient_npc/outpost/angler/proc/watch_players()
	for(var/datum/weakref/ref as anything in watched?.Copy())
		var/mob/living/player = ref.resolve()
		if(QDELETED(player) || get_dist(src, player) > ANGLER_WATCH_RANGE + 3)
			if(player)
				UnregisterSignal(player, COMSIG_MOB_COMPLETE_FISHING)
			LAZYREMOVE(watched, ref)
	for(var/mob/living/player in view(ANGLER_WATCH_RANGE, src))
		if(player.client && !istype(player, /mob/living/basic/ambient_npc))
			watch_player(player)

/// Follows `player`'s fishing
/mob/living/basic/ambient_npc/outpost/angler/proc/watch_player(mob/living/player)
	for(var/datum/weakref/ref as anything in watched)
		if(ref.resolve() == player)
			return
	RegisterSignal(player, COMSIG_MOB_COMPLETE_FISHING, PROC_REF(on_player_fished))
	LAZYADD(watched, WEAKREF(player))

/// A player near them finished reeling in: a word about the fish, or about the one that got away
/mob/living/basic/ambient_npc/outpost/angler/proc/on_player_fished(mob/living/source, datum/fishing_challenge/challenge, win)
	SIGNAL_HANDLER
	if(stat != CONSCIOUS || fading || get_dist(src, source) > ANGLER_WATCH_RANGE + 1 || !reaction_ready("player_fish", 20 SECONDS))
		return
	speak_context(win ? "player_catch" : "player_miss", source, force = TRUE)

/**
 * A fish to hold up: a type from the pond's own fish table, weighted as the pond would weigh it.
 * Only the picture is used; nothing is caught and the pond's stock is never touched.
 */
/mob/living/basic/ambient_npc/outpost/angler/proc/pond_fish_picture()
	var/turf/open/water/pond = water
	if(!istype(pond) || !pond.fishing_datum)
		return /obj/item/fish/goldfish
	var/datum/fish_source/source = GLOB.preset_fish_sources[pond.fishing_datum]
	if(!source)
		return /obj/item/fish/goldfish
	var/list/table = source.get_fish_table(pond)
	var/list/fish = list()
	for(var/result in table)
		if(ispath(result, /obj/item/fish))
			fish[result] = max(1, table[result])
	return length(fish) ? pick_weight(fish) : /obj/item/fish/goldfish

/**
 * Sitting at the pond with a rod: what the angler does when there is no fishing to be had (PB's
 * fishing refused). A word now and then about the fish.
 */
/datum/ambient_activity/pond_sit
	name = "watching the water"
	duration_low = 2 MINUTES
	duration_high = 4 MINUTES

/datum/ambient_activity/pond_sit/setup()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	if(!istype(angler) || !angler.fishing_spot)
		return FALSE
	go_to(angler.fishing_spot)
	set_duration()
	next_line = world.time + rand(20 SECONDS, 40 SECONDS)
	return TRUE

/datum/ambient_activity/pond_sit/arrive()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	angler.face_water()
	angler.sit_in_chair()
	doer.set_held(/obj/item/fishing_rod)

/datum/ambient_activity/pond_sit/act(seconds)
	chatter("fishing", 40 SECONDS, 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/pond_sit/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/// Could not get to their spot: they look for another next time instead of sitting down wherever they are
/datum/ambient_activity/pond_sit/spot_unreachable()
	. = ..()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	if(istype(angler))
		angler.fishing_spot = null
	ends_at = world.time

/**
 * A good one for Pike: the fish held up (a picture), over to his counter, a word, his answer, then
 * back to the water to let it go with a splash.
 */
/datum/ambient_activity/show_catch
	name = "showing off a catch"
	/// Pike
	var/datum/weakref/pike_ref
	/// What they are holding up
	var/fish_type
	/// 0 on the way to Pike, 1 at his counter, 2 back at the water
	var/stage = 0
	/// world.time of the next step
	var/next_step_at = 0

/datum/ambient_activity/show_catch/setup()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	if(!istype(angler))
		return FALSE
	var/mob/living/basic/outpost_trader/pike = ambient_outpost_trader_of(doer.place, /datum/outpost_shop/vendor/bait_shop)
	if(!pike || ambient_counter_customer(pike) || ambient_counter_crowd(pike, doer) >= 2)
		return FALSE
	var/turf/spot = ambient_nearest_tile(doer, ambient_counter_spots(doer, pike, failed_spots))
	if(!spot)
		return FALSE
	fish_type = angler.pond_fish_picture()
	pike_ref = WEAKREF(pike)
	doer.set_held(fish_type)
	go_to(spot)
	return TRUE

/datum/ambient_activity/show_catch/Destroy()
	pike_ref = null
	return ..()

/datum/ambient_activity/show_catch/arrive()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	var/mob/living/basic/outpost_trader/pike = pike_ref?.resolve()
	switch(stage)
		if(0)
			stage = 1
			next_step_at = world.time + rand(4 SECONDS, 7 SECONDS)
			if(!pike || ambient_counter_customer(pike))
				// Pike's busy with someone: back to the water with it
				next_step_at = world.time
				return
			if(!doer.buckled)
				doer.face_atom(pike)
			doer.speak_context("catch_show", pike, force = TRUE)
			ambient_trader_reply(pike, doer, AMBIENT_STRINGS_WORKERS, "pike_catch")
		if(2)
			angler.face_water()
			next_step_at = world.time + rand(1 SECONDS, 2 SECONDS)

/datum/ambient_activity/show_catch/act(seconds)
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	if(world.time < next_step_at)
		return AMBIENT_STEP_CONTINUE
	switch(stage)
		if(1)
			stage = 2
			if(angler.fishing_spot)
				go_to(angler.fishing_spot)
				return AMBIENT_STEP_MOVE
			release()
			return AMBIENT_STEP_DONE
		if(2)
			release()
			return AMBIENT_STEP_DONE
	return AMBIENT_STEP_CONTINUE

/// Back into the pond it goes
/datum/ambient_activity/show_catch/proc/release()
	var/mob/living/basic/ambient_npc/outpost/angler/angler = doer
	playsound(angler.water || doer, 'sound/effects/fish_splash.ogg', 30, TRUE, -3)
	doer.set_held(null)
	if(prob(50))
		doer.speak_context("release", null, force = TRUE)

/datum/ambient_activity/show_catch/finish()
	if(!QDELETED(doer))
		doer.set_held(null)
	return ..()

/datum/ambient_activity/show_catch/spot_unreachable()
	. = ..()
	ends_at = world.time

/datum/ambient_activity/show_catch/shift_times(delay)
	. = ..()
	next_step_at = ambient_shifted(next_step_at, delay)

/// One angler at Halcyon's pond
/datum/ambient_outpost_role/angler
	name = "angler"
	npc_type = /mob/living/basic/ambient_npc/outpost/angler
	outpost_types = list(/obj/structure/overmap/trader_outpost/general)
	max_count = 1
	weight = 2
	gap_low = 2 MINUTES
	gap_high = 4 MINUTES

#undef ANGLER_VISIT_LOW
#undef ANGLER_VISIT_HIGH
#undef ANGLER_SHOW_CHANCE
#undef ANGLER_SHOW_COOLDOWN
#undef ANGLER_WATCH_EVERY
#undef ANGLER_WATCH_RANGE
#undef ANGLER_SPOT_TRIES
