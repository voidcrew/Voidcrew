/**
 * # World population: Nanotrasen and Syndicate recruiters (owner item 14)
 *
 * Owner: PD (faction recruiters). P0 made this file as a stub; only PD edits it.
 *
 * Owner decision D2: recruiters are flavour only. Pamphlets and talk; nothing is recorded, no pin,
 * no stored choice, no sign-up. PD builds here (spec 3.5): the two recruiters as
 * /mob/living/basic/ambient_npc subtypes with their /datum/ambient_outpost_role subtypes (which
 * outposts), their pamphlets and posters (capped per outpost), their barbs at Quartermain, and
 * their lines in strings/faction_recruiters.json (AMBIENT_STRINGS_RECRUITERS).
 *
 * Where: Nanotrasen at Halcyon (trader_outpost/general) and Quartermain (trader_outpost/outfitter);
 * the Syndicate at Quartermain and the Undertow (trader_outpost/black_market). One of each per
 * outpost (/datum/ambient_outpost_role, max_count 1), already at their post when players come.
 */

/// A player who talks to a recruiter may have another pamphlet after this
#define RECRUITER_PAMPHLET_COOLDOWN (10 MINUTES)
/// Posters of one side kept up near a recruiter's usual ground before they stop adding more
#define RECRUITER_POSTER_CAP 2

// =========================================================================
// PAMPHLETS: harmless paper, nothing recorded
// =========================================================================

/obj/item/paper/pamphlet/nanotrasen
	name = "Nanotrasen pamphlet"
	desc = "A recruitment pamphlet, creased from a lot of handling."
	default_raw_text = "<p style=\"text-align:center\"><b>NANOTRASEN IS HIRING</b></p><p>Pilots, engineers, medics, cooks.</p><p>Steady pay. A real doctor. A ship that isn't held together with tape.</p><p>Ask for the recruiter on the concourse.</p>"

/obj/item/paper/pamphlet/syndicate
	name = "folded flyer"
	desc = "A cheaply printed flyer, folded small enough to pocket."
	default_raw_text = "<p style=\"text-align:center\"><b>FREE CREWS. FREE LANES.</b></p><p>No inspections. No landlord.</p><p>Keep your ship, your cargo, and your name off their forms.</p><p>Ask around. Somebody knows somebody.</p>"

// =========================================================================
// THE BASE RECRUITER
// =========================================================================

/**
 * Stands near the lift lobby with a stack of pamphlets, puts up posters, tears the rival's down,
 * and trades barbs with the rival recruiter when one is nearby. Talking to them gets a pitch and,
 * once per ten minutes, a pamphlet. Nothing about a player is kept afterwards (D2).
 */
/mob/living/basic/ambient_npc/recruiter
	name = "recruiter"
	desc = "Someone working the crowd with a clipboard and a smile."
	dialogue_file = AMBIENT_STRINGS_RECRUITERS
	routine = list(
		/datum/ambient_activity/idle = 3,
		/datum/ambient_activity/wander = 2,
		/datum/ambient_activity/recruit_poster = 2,
		/datum/ambient_activity/recruit_barb = 2,
		/datum/ambient_activity/chat = 1,
	)
	/// The pamphlet item type handed to a player who talks to them
	var/pamphlet_type
	/// This side's approved posters, put up on bare concourse walls
	var/list/poster_types = list()
	/// The rival side's posters, torn down on sight
	var/list/rival_poster_types = list()
	/// The rival recruiter's concrete type, for barbs
	var/rival_type
	/// REF of a player -> world.time they may have another pamphlet
	var/list/pamphlet_cooldowns

/mob/living/basic/ambient_npc/recruiter/Destroy()
	pamphlet_cooldowns = null
	return ..()

/// Already at their post when players come: a few steps from the lift lobby, working the crowd
/mob/living/basic/ambient_npc/recruiter/settle_in()
	var/datum/ambient_place/outpost/outpost_place = place
	var/obj/structure/overmap/trader_outpost/outpost = istype(outpost_place) ? outpost_place.outpost() : null
	var/turf/post = length(outpost?.lobby_alcove_turfs) ? ambient_waiting_spot(src, pick(outpost.lobby_alcove_turfs), 3, 6) : null
	if(post)
		forceMove(post)
	else if(!standable(get_turf(src)))
		move_to_settle_tile()
	// Standing about: no posters go up with nobody there to read them
	return !!start_activity(new /datum/ambient_activity/idle(src)) && settle_here()

// An empty hand gets a pitch, and a pamphlet once every ten minutes
/mob/living/basic/ambient_npc/recruiter/talked_to(mob/living/user)
	if(!talk_ready(user))
		return
	if(!buckled)
		face_atom(user)
	speak_context(AMBIENT_LINE_TALK, user, force = TRUE)
	if(pamphlet_type && pamphlet_ready(user))
		addtimer(CALLBACK(src, PROC_REF(offer_pamphlet), WEAKREF(user)), rand(AMBIENT_REPLY_DELAY_LOW, AMBIENT_REPLY_DELAY_HIGH), TIMER_DELETE_ME)

/// Whether `user` may have another pamphlet yet, and starts their wait if so
/mob/living/basic/ambient_npc/recruiter/proc/pamphlet_ready(mob/living/user)
	var/key = REF(user)
	if(LAZYACCESS(pamphlet_cooldowns, key) > world.time)
		return FALSE
	LAZYSET(pamphlet_cooldowns, key, world.time + RECRUITER_PAMPHLET_COOLDOWN)
	// A long round meets many people; forget the oldest
	if(length(pamphlet_cooldowns) > 20)
		pamphlet_cooldowns.Cut(1, 2)
	return TRUE

/mob/living/basic/ambient_npc/recruiter/proc/offer_pamphlet(datum/weakref/user_ref)
	var/mob/living/user = user_ref?.resolve()
	if(QDELETED(user) || stat != CONSCIOUS || fading || get_dist(src, user) > 3)
		return
	speak_context("pamphlet", user, force = TRUE)
	var/obj/item/paper/leaflet = new pamphlet_type(get_turf(user))
	user.put_in_hands(leaflet)

/// A random two-line barb from their section's "barbs": opener said by this side, reply in the rival's voice
/mob/living/basic/ambient_npc/recruiter/proc/pick_barb()
	var/list/entry = ambient_dialogue_section(dialogue_file, dialogue_section)
	var/list/barbs = entry?["barbs"]
	if(!length(barbs))
		return null
	var/list/barb = pick(barbs)
	if(!islist(barb) || !istext(barb["opener"]))
		return null
	var/list/replies = barb["replies"]
	return list(barb["opener"], length(replies) ? pick(replies) : null)

// The supply convoy arrived: a comment, not a reaction
/mob/living/basic/ambient_npc/recruiter/react_convoy(obj/structure/overmap/trader_outpost/outpost)
	speak_context("convoy", outpost, force = TRUE)

/// The nearest poster of `types` within `range`, or null
/mob/living/basic/ambient_npc/recruiter/proc/find_poster(list/types, range = AMBIENT_ACTIVITY_RANGE)
	if(!length(types))
		return null
	var/turf/here = get_turf(src)
	if(!here)
		return null
	for(var/obj/structure/sign/poster/poster in range(range, here))
		if(poster.type in types)
			return poster
	return null

/// How many of this side's posters are already up within `range`
/mob/living/basic/ambient_npc/recruiter/proc/count_own_posters(range = AMBIENT_ACTIVITY_RANGE)
	. = 0
	if(!length(poster_types))
		return
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/obj/structure/sign/poster/poster in range(range, here))
		if(poster.type in poster_types)
			.++

/// A bare wall within `range` with room for a poster and a floor tile to stand beside it, or null
/mob/living/basic/ambient_npc/recruiter/proc/find_bare_wall(range = AMBIENT_ACTIVITY_RANGE)
	var/turf/here = get_turf(src)
	if(!here)
		return null
	var/list/options = list()
	for(var/turf/closed/wall in range(range, here))
		var/stuff = 0
		var/has_poster = FALSE
		for(var/obj/contained in wall.contents)
			if(istype(contained, /obj/structure/sign/poster))
				has_poster = TRUE
				break
			stuff++
		if(has_poster || stuff >= 3)
			continue
		if(!free_tile_beside(wall, 1))
			continue
		options += wall
	return length(options) ? pick(options) : null

// =========================================================================
// ACTIVITIES
// =========================================================================

/// Tears a rival poster down within reach, else puts one of their own up on a bare wall, under the cap
/datum/ambient_activity/recruit_poster
	name = "working the walls"
	duration_low = 3 SECONDS
	duration_high = 5 SECONDS
	var/tearing = FALSE
	var/datum/weakref/target_ref

/datum/ambient_activity/recruit_poster/setup()
	var/mob/living/basic/ambient_npc/recruiter/recruiter = doer
	if(!istype(recruiter))
		return FALSE
	var/obj/structure/sign/poster/rival = recruiter.find_poster(recruiter.rival_poster_types)
	if(rival)
		tearing = TRUE
		target_ref = WEAKREF(rival)
		var/turf/stand = recruiter.free_tile_beside(rival, 1, failed_spots)
		if(!stand)
			return FALSE
		go_to(stand, 1)
		set_duration()
		return TRUE
	if(!length(recruiter.poster_types) || recruiter.count_own_posters() >= RECRUITER_POSTER_CAP)
		return FALSE
	var/turf/closed/wall = recruiter.find_bare_wall()
	if(!wall)
		return FALSE
	tearing = FALSE
	target_ref = WEAKREF(wall)
	var/turf/stand = recruiter.free_tile_beside(wall, 1, failed_spots)
	if(!stand)
		return FALSE
	go_to(stand, 1)
	set_duration()
	return TRUE

/datum/ambient_activity/recruit_poster/arrive()
	var/mob/living/basic/ambient_npc/recruiter/recruiter = doer
	var/atom/target = target_ref?.resolve()
	if(QDELETED(target))
		return
	if(!doer.buckled)
		doer.face_atom(target)
	if(tearing)
		var/obj/structure/sign/poster/rival = target
		if(!QDELETED(rival) && !rival.ruined)
			recruiter.speak_context("tear", rival, force = TRUE)
			rival.tear_poster(doer)
		return
	var/turf/closed/wall = target
	var/poster_type = pick(recruiter.poster_types)
	new poster_type(wall)
	recruiter.speak_context("poster", wall, force = TRUE)

/// Trades barbs with the rival recruiter when one is standing nearby
/datum/ambient_activity/recruit_barb
	name = "trading barbs"
	duration_low = 8 SECONDS
	duration_high = 14 SECONDS
	var/datum/weakref/rival_ref

/datum/ambient_activity/recruit_barb/setup()
	var/mob/living/basic/ambient_npc/recruiter/recruiter = doer
	if(!istype(recruiter) || !recruiter.rival_type)
		return FALSE
	var/mob/living/basic/ambient_npc/recruiter/rival = find_rival(recruiter)
	if(!rival)
		return FALSE
	rival_ref = WEAKREF(rival)
	var/turf/stand = recruiter.free_tile_beside(rival, 1, failed_spots)
	if(!stand)
		return FALSE
	go_to(stand, 1)
	set_duration()
	return TRUE

/datum/ambient_activity/recruit_barb/proc/find_rival(mob/living/basic/ambient_npc/recruiter/recruiter)
	var/turf/here = get_turf(recruiter)
	if(!here)
		return null
	for(var/mob/living/basic/ambient_npc/recruiter/other in range(AMBIENT_ACTIVITY_RANGE, here))
		if(other == recruiter || other.place != recruiter.place || !istype(other, recruiter.rival_type))
			continue
		if(other.stat != CONSCIOUS || istype(other.activity, /datum/ambient_activity/leave))
			continue
		return other
	return null

/datum/ambient_activity/recruit_barb/arrive()
	var/mob/living/basic/ambient_npc/recruiter/recruiter = doer
	var/mob/living/basic/ambient_npc/recruiter/rival = rival_ref?.resolve()
	if(QDELETED(rival))
		return
	if(!doer.buckled)
		doer.face_atom(rival)
	var/list/barb = recruiter.pick_barb()
	if(!barb)
		return
	recruiter.say_line(recruiter.fill_line(barb[1], rival))
	rival.reply_to(recruiter, AMBIENT_LINE_REPLY, barb[2])

// =========================================================================
// OUTFITS (plain clothes, nothing worth stripping)
// =========================================================================

/datum/outfit/ambient/recruiter_nanotrasen
	name = "Nanotrasen recruiter"
	uniform = /obj/item/clothing/under/rank/civilian/head_of_personnel/suit
	neck = /obj/item/clothing/neck/tie/blue
	shoes = /obj/item/clothing/shoes/laceup

/datum/outfit/ambient/recruiter_syndicate
	name = "Syndicate recruiter"
	uniform = /obj/item/clothing/under/rank/civilian/lawyer/black
	neck = /obj/item/clothing/neck/tie/black/tied
	shoes = /obj/item/clothing/shoes/laceup
	glasses = /obj/item/clothing/glasses/sunglasses

// =========================================================================
// NANOTRASEN
// =========================================================================

/mob/living/basic/ambient_npc/recruiter/nanotrasen
	name = "Nanotrasen recruiter"
	desc = "A neatly pressed suit and a stack of pamphlets."
	outfit = /datum/outfit/ambient/recruiter_nanotrasen
	dialogue_section = "nanotrasen"
	pamphlet_type = /obj/item/paper/pamphlet/nanotrasen
	poster_types = list(
		/obj/structure/sign/poster/official/work_for_a_future,
		/obj/structure/sign/poster/official/enlist,
		/obj/structure/sign/poster/official/nanotrasen_logo,
	)
	rival_poster_types = list(
		/obj/structure/sign/poster/contraband/syndicate_recruitment,
		/obj/structure/sign/poster/contraband/gorlex_recruitment,
	)
	rival_type = /mob/living/basic/ambient_npc/recruiter/syndicate

/datum/ambient_outpost_role/recruiter/nanotrasen
	name = "Nanotrasen recruiter"
	npc_type = /mob/living/basic/ambient_npc/recruiter/nanotrasen
	outpost_types = list(
		/obj/structure/overmap/trader_outpost/general,
		/obj/structure/overmap/trader_outpost/outfitter,
	)
	max_count = 1

// =========================================================================
// SYNDICATE
// =========================================================================

/mob/living/basic/ambient_npc/recruiter/syndicate
	name = "sharp-dressed stranger"
	desc = "A dark suit, dark glasses, and a way of not quite looking at the cameras."
	outfit = /datum/outfit/ambient/recruiter_syndicate
	dialogue_section = "syndicate"
	pamphlet_type = /obj/item/paper/pamphlet/syndicate
	poster_types = list(
		/obj/structure/sign/poster/contraband/syndicate_recruitment,
		/obj/structure/sign/poster/contraband/gorlex_recruitment,
	)
	rival_poster_types = list(
		/obj/structure/sign/poster/official/work_for_a_future,
		/obj/structure/sign/poster/official/enlist,
		/obj/structure/sign/poster/official/nanotrasen_logo,
	)
	rival_type = /mob/living/basic/ambient_npc/recruiter/nanotrasen

/datum/ambient_outpost_role/recruiter/syndicate
	name = "Syndicate recruiter"
	npc_type = /mob/living/basic/ambient_npc/recruiter/syndicate
	outpost_types = list(
		/obj/structure/overmap/trader_outpost/outfitter,
		/obj/structure/overmap/trader_outpost/black_market,
	)
	max_count = 1

#undef RECRUITER_PAMPHLET_COOLDOWN
#undef RECRUITER_POSTER_CAP
