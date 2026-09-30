/**
 * # World population: the escaped convict (owner item 13)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * Owner decision D3: the convict is a small private bounty for the first crew that sees them,
 * inside the existing two-offer limit, paid by the existing capture rules; recruiting them
 * withdraws it unpaid.
 *
 * The convict (spec 5.4) is the bounty module's meek criminal in prison orange, with its own AI:
 * camping at a small fire on a planet, or looking round a space ruin; sprinting and hiding from
 * anyone who comes at them armed; a holdout when cornered. This file only calls the bounty
 * module's procs; it edits nothing there.
 * - Sighted: the first time someone of a ship crew comes into view, they put their hands up
 *   ("Don't shoot!") and a private petty bounty on them is posted to that crew's ship, if the board
 *   would offer that ship another private bounty now (under BOUNTY_PRIVATE_MAX, and not in the gap
 *   after its last one ended). Only ever one bounty per convict. The crew cuff them and use
 *   their pad, and the bounty pays by the usual rules.
 * - Talked down: an empty hand from a crew member while they are calm, and they ask to come along.
 *   "Come with us" turns them into a stray following that crew (recruit.dm), wearing the same face,
 *   and withdraws their bounty unpaid. A convict who is fleeing, hiding, down or cuffed won't talk.
 * - Left alone: when a bounty on a free convict ends unclaimed, they stay where they are, off the
 *   board for good.
 * Where they turn up: a planet site (/datum/ambient_site_kind/convict, yellow and red space) or,
 * rolled once per space ruin per round by SSambient_strays (stranded_lifeboat.dm), a loaded ruin
 * a crew has docked at. At most one per AMBIENT_CONVICT_SHIPS_PER active crews, and never more than
 * AMBIENT_CONVICTS_MAX alive.
 */

/// How far a convict sees a crew member coming
#define CONVICT_SIGHT_RANGE 7
/// How often a convict looks for crews
#define CONVICT_LOOK_INTERVAL (2 SECONDS)
/// Least time between a convict's own lines
#define CONVICT_LINE_COOLDOWN (8 SECONDS)
/// A player may talk to a convict again after this
#define CONVICT_TALK_COOLDOWN (4 SECONDS)
/// The reason a convict's bounty closes when a crew takes them in
#define CONVICT_CLOSE_RECRUITED "recruited"

/// Weakrefs to every escaped convict's body (weakrefs: the bounty body's own Destroy() is not overridden here)
GLOBAL_LIST_EMPTY(ambient_convicts)

// =========================================================================
// CAPS
// =========================================================================

/// How many convicts may be alive with `active_ships` crews playing
/proc/ambient_convict_cap(active_ships)
	return min(AMBIENT_CONVICTS_MAX, CEILING(max(active_ships, 0) / AMBIENT_CONVICT_SHIPS_PER, 1))

/// Player ships with an active crew
/proc/ambient_active_crews()
	. = 0
	for(var/obj/structure/overmap/ship/ship as anything in SSovermap.simulated_ships)
		if(QDELETED(ship) || ship.abandoned || istype(ship, /obj/structure/overmap/ship/npc))
			continue
		if(ship.has_active_crew())
			.++

/// Convicts alive now. Forgets the ones that are gone.
/proc/ambient_live_convicts()
	. = 0
	for(var/datum/weakref/ref as anything in GLOB.ambient_convicts.Copy())
		var/mob/living/basic/bounty_criminal/meek/convict/convict = ref?.resolve()
		if(QDELETED(convict))
			GLOB.ambient_convicts -= ref
			continue
		if(convict.stat != DEAD)
			.++

/// Whether another convict may turn up. `active_ships` overrides the count of active crews (tests).
/proc/ambient_convict_room(active_ships)
	if(isnull(active_ships))
		active_ships = ambient_active_crews()
	return ambient_live_convicts() < ambient_convict_cap(active_ships)

/**
 * A new convict at `where`, on site `site` (the overmap planet or ruin, or null), for a
 * `placement_kind` (BOUNTY_PLACEMENT_PLANET or _RUIN) site: `record`'s person, or someone new. They
 * camp on a planet and look round a ruin. Returns the convict, or null.
 */
/proc/ambient_spawn_convict(turf/where, obj/structure/overmap/site, placement_kind = BOUNTY_PLACEMENT_PLANET, datum/bounty_record/record)
	where = get_turf(where)
	if(!where)
		return null
	record ||= generate_bounty_record(BOUNTY_TIER_PETTY, BOUNTY_ARCHETYPE_MEEK, placement_kind)
	if(!record)
		return null
	var/mob/living/basic/bounty_criminal/meek/convict/convict = new(where)
	convict.body_setup(record, null)
	if(site)
		convict.body_set_site(site)
	// Friends with what lives where they hide, as a posted criminal is (never the players' own side)
	var/list/sides = list(FACTION_HOSTILE, FACTION_MINING)
	if(istype(site, /obj/structure/overmap/space_ruin))
		sides |= list(FACTION_PIRATE, ROLE_SYNDICATE)
	convict.faction |= sides
	convict.start_activity(placement_kind == BOUNTY_PLACEMENT_PLANET ? BOUNTY_ACTIVITY_CAMP : BOUNTY_ACTIVITY_EXPLORE, null)
	log_game("AMBIENT: an escaped convict, [convict.real_name], turned up at [AREACOORD(where)]")
	return convict

// =========================================================================
// SPACE RUINS
// =========================================================================

/// Whether `ruin` could hold a convict now: an ordinary ruin (no chart, contract or event owns it), loaded, docked at, in yellow or red space
/proc/ambient_ruin_convict_ok(obj/structure/overmap/space_ruin/ruin)
	if(QDELETED(ruin) || ruin.type != /obj/structure/overmap/space_ruin)
		return FALSE
	if(ruin.rare || ruin.mission_locked || ruin.mission_exclusive || !ruin.visited || !ruin.is_loaded())
		return FALSE
	var/band = SSovermap.get_zone_band_for_turf(get_turf(ruin))
	return band == ZONE_YELLOW || band == ZONE_RED

/// A convict somewhere in `ruin` out of everyone's sight. Returns the convict, or null.
/proc/ambient_place_ruin_convict(obj/structure/overmap/space_ruin/ruin)
	for(var/attempt in 1 to 10)
		var/turf/spot = ruin.get_random_interior_turf()
		if(!spot || !bounty_spawn_turf_ok(spot) || ambient_any_player_near(spot, CONVICT_SIGHT_RANGE + 2))
			continue
		return ambient_spawn_convict(spot, ruin, BOUNTY_PLACEMENT_RUIN)
	return null

/// Whether a living player is within `range` of `spot`
/proc/ambient_any_player_near(turf/spot, range)
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(spot, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, range))
		if(person.stat != DEAD)
			return TRUE
	return FALSE

// =========================================================================
// THE PLANET SITE
// =========================================================================

/**
 * A convict's hideout on a planet: just them, and the little camp they make. The convict is a bounty
 * body, not an ambient NPC, so the site keeps them itself (data["convict"]) and brings the same
 * person back on a later visit until someone has seen them.
 */
/datum/ambient_site_kind/convict
	name = "escaped convict"
	planet_types = list(
		/datum/overmap/planet/jungle,
		/datum/overmap/planet/lava,
		/datum/overmap/planet/ice,
		/datum/overmap/planet/wasteland,
	)
	bands = list(ZONE_YELLOW, ZONE_RED)
	chance = 5
	spot_room = 2

// Spec 4.1: lava 10%, wasteland 20%, jungle and ice 15%; none past the cap
/datum/ambient_site_kind/convict/chance_on(datum/ambient_planet/record)
	. = ..()
	if(!.)
		return
	if(!has_room())
		return 0
	switch(record.planet_type)
		if(/datum/overmap/planet/lava)
			return 4
		if(/datum/overmap/planet/wasteland)
			return 7

/datum/ambient_site_kind/convict/realize(datum/ambient_place/site/site)
	if(site.data["taken"] || site.state == AMBIENT_SITE_SPENT)
		return FALSE
	var/datum/weakref/convict_ref = site.data["convict"]
	var/mob/living/basic/bounty_criminal/meek/convict/convict = convict_ref?.resolve()
	if(!QDELETED(convict))
		return FALSE
	if(!has_room())
		return FALSE
	var/obj/structure/overmap/planet/planet = site.planet?.planet()
	convict = ambient_spawn_convict(site.center, planet, BOUNTY_PLACEMENT_PLANET, site.data["record"])
	if(!convict)
		return FALSE
	convict.convict_site_ref = WEAKREF(site)
	site.data["convict"] = WEAKREF(convict)
	site.data["record"] = convict.record
	site.state = AMBIENT_SITE_ACTIVE
	return TRUE

/// Whether another convict may turn up now. Override (tests).
/datum/ambient_site_kind/convict/proc/has_room()
	return ambient_convict_room()

// =========================================================================
// THE CONVICT
// =========================================================================

/mob/living/basic/bounty_criminal/meek/convict
	name = "escaped convict"
	desc = "Someone in prison orange, a long way from any prison."
	/// Weakref to the planet site (/datum/ambient_place/site) that keeps them, if any
	var/datum/weakref/convict_site_ref
	/// A bounty was posted on them. There is never a second one.
	var/convict_posted = FALSE
	/// REFs of ships whose crews they have seen
	var/list/convict_seen_by
	/// world.time they next look for crews
	var/convict_next_look = 0
	/// world.time of their next own line
	var/convict_next_line = 0
	/// REF of a player -> world.time they may talk to them again
	var/list/convict_talk_cooldowns

/mob/living/basic/bounty_criminal/meek/convict/Initialize(mapload)
	. = ..()
	GLOB.ambient_convicts += WEAKREF(src)

// Prison orange, wherever they are
/mob/living/basic/bounty_criminal/meek/convict/bounty_outfit()
	return /datum/outfit/prisoner

/mob/living/basic/bounty_criminal/meek/convict/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	var/datum/ambient_place/site/site = convict_site_ref?.resolve()
	if(site && !QDELETED(site))
		site.npc_died(src)

/// Their planet site knows they are gone for good (a bounty took them over, or a crew took them in)
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_mark_site_taken()
	var/datum/ambient_place/site/site = convict_site_ref?.resolve()
	if(!site || QDELETED(site))
		return
	site.data["taken"] = TRUE
	site.state = AMBIENT_SITE_SPENT

// ----- their own lines -----

/// Says a line for `context` from the strays file, now and then; `force` skips the wait. TRUE if they spoke.
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_say(context, force = FALSE)
	if(stat != CONSCIOUS || (!force && world.time < convict_next_line))
		return FALSE
	var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_STRAYS, "convict", context)
	if(!length(lines))
		return FALSE
	convict_next_line = world.time + CONVICT_LINE_COOLDOWN
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), pick(lines))
	return TRUE

// Their own words where the strays file has them (at the camp, cornered, cuffed), the bounty module's otherwise
/mob/living/basic/bounty_criminal/meek/convict/bounty_say(context, list/values, force = FALSE)
	if(!length(ambient_dialogue_lines(AMBIENT_STRINGS_STRAYS, "convict", context)))
		return ..()
	return convict_say(context, force)

// ----- being seen -----

// Each look round for hunters is also a look for crews they have not seen yet
/mob/living/basic/bounty_criminal/meek/convict/ai_look_around()
	convict_look_for_crews()
	return ..()

/// The first time someone of a ship crew comes into view: hands up, and maybe their bounty
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_look_for_crews()
	if(world.time < convict_next_look || hidden || !ai_can_act())
		return
	convict_next_look = world.time + CONVICT_LOOK_INTERVAL
	var/turf/here = get_turf(src)
	if(!here)
		return
	for(var/mob/living/person in SSspatial_grid.orthogonal_range_search(here, SPATIAL_GRID_CONTENTS_TYPE_CLIENTS, CONVICT_SIGHT_RANGE))
		if(!bounty_ai_is_hunter(person))
			continue
		var/obj/structure/overmap/ship/ship = ambient_crew_ship(person)
		if(!ship)
			continue
		var/key = REF(ship)
		if(LAZYFIND(convict_seen_by, key) || !bounty_ai_can_see(src, person, CONVICT_SIGHT_RANGE))
			continue
		LAZYADD(convict_seen_by, key)
		INVOKE_ASYNC(src, PROC_REF(convict_sighted), person, ship)
		return

/// `person` of `ship` saw them
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_sighted(mob/living/person, obj/structure/overmap/ship/ship)
	if(QDELETED(src) || stat != CONSCIOUS)
		return
	if(!QDELETED(person))
		face_atom(person)
	manual_emote("puts [p_their()] hands up.")
	convict_say("sighted", force = TRUE)
	convict_post_bounty(ship)

/**
 * Their private petty bounty, for `ship`: once ever, and only if the ship has room for another
 * private offer. board_post() rolls a record of its own, so the posting takes theirs instead, and
 * the card shows who the crew actually saw. Returns the posting, or null.
 */
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_post_bounty(obj/structure/overmap/ship/ship)
	if(convict_posted || QDELETED(ship) || !record || posting() || stat == DEAD)
		return null
	// Inside the board's own rules for private offers: at most BOUNTY_PRIVATE_MAX open, and none during the gap after one ends
	if(SScriminal_bounties.board_private_count(ship) >= BOUNTY_PRIVATE_MAX || world.time < SScriminal_bounties.board_private_next[WEAKREF(ship)])
		return null
	var/obj/structure/overmap/site = body_site()
	if(!site)
		return null
	var/datum/criminal_bounty/posting = SScriminal_bounties.board_post(BOUNTY_TIER_PETTY, null, site, ship, TRUE)
	if(!posting)
		return null
	convict_posted = TRUE
	var/datum/bounty_record/rolled = posting.record
	if(rolled != record)
		record.tier = BOUNTY_TIER_PETTY
		record.status = BOUNTY_RECORD_WANTED
		if(rolled)
			record.base_value = rolled.base_value
			posting.UnregisterSignal(rolled, COMSIG_BOUNTY_RECORD_MUGSHOT_READY)
		posting.record = record
		posting.RegisterSignal(record, COMSIG_BOUNTY_RECORD_MUGSHOT_READY, TYPE_PROC_REF(/datum/criminal_bounty, board_on_mugshot_ready))
		posting.board_gps_tag = "[BOUNTY_GPS_TAG_PREFIX]-[record.id]"
	// Wanted on it from now on, as a spawned criminal would be
	body_setup(record, posting)
	if(!posting.board_adopt_criminal(src, site, ai_activity_kind, null))
		posting.close(BOUNTY_CLOSE_ADMIN)
		return null
	RegisterSignal(posting, COMSIG_BOUNTY_POSTING_CLOSED, PROC_REF(convict_on_posting_closed))
	convict_mark_site_taken()
	ship.ship_notify("WANTED: [record.name], an escaped convict, was seen by your crew.", "MISSION CONTROL", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("AMBIENT: a private bounty on the escaped convict [record.name] was posted to the [ship.name]")
	return posting

/**
 * Their bounty closed. Claimed, the pad has them. Anything else while they are free on their own
 * ground (not dead, down, cuffed or aboard a ship): they stay where they are, off the board.
 */
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_on_posting_closed(datum/source, reason, obj/structure/overmap/ship/winner)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_BOUNTY_POSTING_CLOSED)
	var/datum/criminal_bounty/posting = source
	if(reason == BOUNTY_CLOSE_CLAIMED || QDELETED(src) || posting.criminal() != src)
		return
	if(stat == DEAD || downed || is_restrained() || get_ship_from_atom(src))
		return
	posting.board_detach_criminal()
	posting_ref = null
	REMOVE_TRAIT(src, TRAIT_MISSION_FIELD_MOB, BOUNTY_TRAIT)

// ----- being talked down -----

/// Whether they would talk: awake, calm, on their feet, not hidden or cuffed
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_can_talk()
	if(stat != CONSCIOUS || hidden || downed || is_restrained() || HAS_TRAIT(src, TRAIT_BOUNTY_REMOVED))
		return FALSE
	return ai_can_act() && ai_mode == BOUNTY_AI_CALM

/mob/living/basic/bounty_criminal/meek/convict/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(istype(user) && !user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK) && convict_can_talk())
		INVOKE_ASYNC(src, PROC_REF(convict_talk), user)
		return TRUE
	return ..()

/// A word with `user`, and to a crew member with room aboard, the plea. Sleeps.
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_talk(mob/living/user)
	var/key = REF(user)
	if(LAZYACCESS(convict_talk_cooldowns, key) > world.time)
		return
	LAZYSET(convict_talk_cooldowns, key, world.time + CONVICT_TALK_COOLDOWN)
	face_atom(user)
	var/obj/structure/overmap/ship/ship = ambient_crew_ship(user)
	if(!ship || !ambient_ship_can_take(ship))
		convict_say("talk", force = TRUE)
		return
	convict_say("plea", force = TRUE)
	var/list/choices = list(
		"Come with us" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_yes"),
		"Not now" = image(icon = 'icons/hud/radial.dmi', icon_state = "radial_no"),
	)
	var/choice = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE)
	if(QDELETED(src) || QDELETED(user) || !convict_can_talk())
		return
	switch(choice)
		if("Come with us")
			if(get_dist(src, user) <= 2 && ambient_crew_ship(user) == ship && ambient_ship_can_take(ship))
				convict_join(user, ship)
		if("Not now")
			convict_say("refused", force = TRUE)

/**
 * They go with `leader` to `ship`: a stray with the same name and face takes their place, following
 * `leader` (recruit.dm), and their bounty is withdrawn unpaid. Returns the stray, or null.
 */
/mob/living/basic/bounty_criminal/meek/convict/proc/convict_join(mob/living/leader, obj/structure/overmap/ship/ship)
	var/turf/here = get_turf(src)
	if(!here || QDELETED(ship) || QDELETED(leader))
		return null
	var/mob/living/basic/ambient_npc/stray/convict/stray = new(here, list("name" = real_name, "gender" = gender), record)
	stray.setDir(dir)
	// Their face, carried over at once; build_look() puts the same one back on from the record
	stray.icon = icon
	stray.icon_state = icon_state
	stray.appearance_flags |= KEEP_TOGETHER
	stray.copy_overlays(src, cut_old = TRUE)
	var/datum/criminal_bounty/posting = posting()
	if(posting)
		UnregisterSignal(posting, COMSIG_BOUNTY_POSTING_CLOSED)
		posting.board_detach_criminal()
	convict_mark_site_taken()
	ai_put_out_camp()
	// Gone on purpose: no proof of death, nothing to turn in
	body_mark_removed()
	ADD_TRAIT(src, TRAIT_BOUNTY_REMOVED, BOUNTY_PAD_TRAIT)
	posting?.close(CONVICT_CLOSE_RECRUITED)
	ambient_offer_recruit(stray)
	stray.accept_offer(leader, ship)
	log_game("AMBIENT: the escaped convict [real_name] went with the [ship.name], talked down by [key_name(leader)]")
	qdel(src)
	return stray

// =========================================================================
// THE CONVICT WHO JOINED A CREW
// =========================================================================

/// A convict who went with a crew: the same face, a stray now (recruit.dm)
/mob/living/basic/ambient_npc/stray/convict
	name = "escaped convict"
	desc = "Someone in prison orange who has decided not to go back."
	outfit = /datum/outfit/prisoner
	dialogue_section = "convict"
	random_name = FALSE
	/// Who they are (/datum/bounty_record): their face comes from it
	var/datum/bounty_record/bounty_record

/mob/living/basic/ambient_npc/stray/convict/Initialize(mapload, list/identity, datum/bounty_record/from_record)
	bounty_record = from_record
	return ..(mapload, identity)

/mob/living/basic/ambient_npc/stray/convict/Destroy()
	bounty_record = null
	return ..()

/mob/living/basic/ambient_npc/stray/convict/build_look()
	if(QDELETED(src))
		return
	if(bounty_record)
		apply_bounty_look(src, bounty_record, /datum/outfit/prisoner)
		return
	return ..()

#undef CONVICT_SIGHT_RANGE
#undef CONVICT_LOOK_INTERVAL
#undef CONVICT_LINE_COOLDOWN
#undef CONVICT_TALK_COOLDOWN
#undef CONVICT_CLOSE_RECRUITED
