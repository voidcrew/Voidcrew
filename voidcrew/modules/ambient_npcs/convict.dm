/**
 * # World population: the escaped convict (owner item 13)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * Owner decision D3: the convict is a small private bounty for the first crew that sees them,
 * inside the existing two-offer limit, paid by the existing capture rules; recruiting them
 * withdraws it unpaid.
 *
 * The convict (spec 5.4) is the bounty module's meek criminal, a real human body
 * (voidcrew/modules/human_npcs/), in prison orange, with the meek AI: camping at a small fire on a
 * planet, or looking round a space ruin; running and hiding from anyone who comes at them armed; a
 * holdout pistol when cornered. This file only calls the bounty module's procs; it edits nothing there.
 * - Sighted: the first time someone of a ship crew comes into view, they give up the way a person
 *   does (npc_surrender(): the weapon put away, "Don't shoot!", tg's *surrender, a real 20 second
 *   Paralyze), and a private petty bounty on them is posted to that crew's ship, if the board would
 *   offer that ship another private bounty now (under BOUNTY_PRIVATE_MAX, and not in the gap after its
 *   last one ended). Only ever one bounty per convict. The crew cuff them and use their pad, and the
 *   bounty pays on their condition there by the usual rules.
 * - Talked down: an empty hand from a crew member while they are calm, and they ask to come along.
 *   "Come with us" and the SAME body goes with that crew (defaults 1.9, AM-6): its bounty is withdrawn
 *   unpaid, it is taken off the board for good (no posting, no leash, no teleport block, no sweep
 *   protection, off the convict count), and its AI and faction change: a small follower AI of its own
 *   (below) walks after whoever asked, keeps out of fights, and stays aboard once it has stepped onto
 *   their ship. Wounds, blood and everything else about the body carry on. A convict who is fleeing,
 *   hiding, down, stunned or cuffed won't talk.
 * - Left alone: when a bounty on a free convict ends unclaimed, they stay where they are, off the
 *   board for good.
 * Where they turn up: a planet site (/datum/ambient_site_kind/convict, yellow and red space) or,
 * rolled once per space ruin per round by SSambient_strays (stranded_lifeboat.dm), a loaded ruin
 * a crew has docked at. At most one per AMBIENT_CONVICT_SHIPS_PER active crews, and never more than
 * AMBIENT_CONVICTS_MAX alive.
 *
 * A talked-down convict is still a /bounty_criminal type: a mob can't change type and stay the same
 * body. What reads the posting (the pad, the board, proof of death, pay) leaves it alone, since it has
 * none. What reads the type alone still counts it as a bounty body: other criminals never pick it as a
 * target, and the core's transporter, bag-fold and contract-pad checks still refuse it while it is alive
 * (see the PHASE D CORE REQUEST below). Turrets leave it be: its follower AI has no target finding.
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
/// Beyond this many tiles (or off the level, or dead) a follower's leader is out of reach
#define CONVICT_FOLLOW_RANGE 12
/// A leader out of reach this long is lost: the follower waits where it is
#define CONVICT_LOST_TIME (60 SECONDS)
/// Further than this behind its leader, a follower runs to catch up
#define CONVICT_RUN_DISTANCE 4
/// How long a follower keeps clear of someone who hit it
#define CONVICT_SHY_TIME (10 SECONDS)
/// How close a fight has to be for a follower to back off from it
#define CONVICT_FIGHT_RANGE 5
/// Between a follower's idle lines aboard, while somebody is near
#define CONVICT_IDLE_LINE_LOW (90 SECONDS)
#define CONVICT_IDLE_LINE_HIGH (180 SECONDS)
/// Contexts a talked-down convict says from the strays file's deckhand section first
#define CONVICT_DECKHAND_CONTEXTS list("talk", "idle", "follow", "wait")

/// Blackboard: who a talked-down convict follows (null: it stays where it is)
#define BB_CONVICT_LEADER "convict_leader"
/// Blackboard: world.time its leader went out of reach, or null
#define BB_CONVICT_LOST_SINCE "convict_lost_since"
/// Blackboard: whoever last hit it, and the world.time it stops keeping clear of them
#define BB_CONVICT_HIT_BY "convict_hit_by"
#define BB_CONVICT_HIT_UNTIL "convict_hit_until"
/// Blackboard: what it is backing away from now (run_away_from_target clears it)
#define BB_CONVICT_AVOID "convict_avoid"

/// Weakrefs to every escaped convict's body still on the board (weakrefs: the bounty body's own Destroy() is not overridden here)
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
		var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = ref?.resolve()
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
 * camp on a planet and look round a ruin. One body, wanted back at once, so it is built now rather
 * than queued, in its record's face and name. Returns the convict, or null.
 */
/proc/ambient_spawn_convict(turf/where, obj/structure/overmap/site, placement_kind = BOUNTY_PLACEMENT_PLANET, datum/bounty_record/record)
	where = get_turf(where)
	if(!where)
		return null
	record ||= generate_bounty_record(BOUNTY_TIER_PETTY, BOUNTY_ARCHETYPE_MEEK, placement_kind)
	if(!record)
		return null
	var/datum/human_npc_order/order = spawn_human_npc(/mob/living/carbon/human/npc/bounty_criminal/meek/convict, where, look = record, name = record.name, immediate = TRUE)
	var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = order?.spawned_ref?.resolve()
	qdel(order)
	if(QDELETED(convict))
		return null
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
	var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = convict_ref?.resolve()
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

/**
 * Prison orange and the escapee's shiv, with the meek criminal's kit (bounty_styles.dm's holdout): the
 * little Makarov in a pocket, its spare magazine and the stimpack they bolt on in a fanny pack. They run
 * and hide, and only shoot when cornered. Their own name stays on them: no prisoner number.
 */
/datum/outfit/prisoner/bounty_convict
	name = "Escaped convict"
	l_pocket = /obj/item/gun/ballistic/automatic/pistol
	belt = /obj/item/storage/belt/fannypack
	belt_contents = list(
		/obj/item/ammo_box/magazine/m9mm = 1,
		/obj/item/reagent_containers/hypospray/medipen/stimpack = 1,
	)

/datum/outfit/prisoner/bounty_convict/post_equip(mob/living/carbon/human/prisoner, visuals_only = FALSE)
	return

/mob/living/carbon/human/npc/bounty_criminal/meek/convict
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
	/// Talked down: off the board, going with a crew (the same body, a follower AI)
	var/convict_recruited = FALSE
	/// Weakref to the ship whose crew took them in
	var/datum/weakref/convict_ship_ref
	/// They have stepped aboard that ship, and stay aboard from now on
	var/convict_aboard = FALSE
	/// world.time of their next idle line aboard
	var/convict_next_idle_line = 0

/mob/living/carbon/human/npc/bounty_criminal/meek/convict/Initialize(mapload, datum/human_npc_order/order)
	. = ..()
	GLOB.ambient_convicts += WEAKREF(src)

// Prison orange, wherever they are (the human NPC base adds a sealed suit and air, a mask or warm
// clothes on top where the spot needs them)
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/bounty_build_outfit(zone)
	return /datum/outfit/prisoner/bounty_convict

/mob/living/carbon/human/npc/bounty_criminal/meek/convict/death(gibbed)
	var/was_alive = stat != DEAD
	. = ..()
	if(!was_alive)
		return
	var/datum/ambient_place/site/site = convict_site_ref?.resolve()
	if(site && !QDELETED(site))
		site.npc_died(src)

/// Their planet site knows they are gone for good (a bounty took them over, or a crew took them in)
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_mark_site_taken()
	var/datum/ambient_place/site/site = convict_site_ref?.resolve()
	if(!site || QDELETED(site))
		return
	site.data["taken"] = TRUE
	site.state = AMBIENT_SITE_SPENT

// ----- their own lines -----

/**
 * Their lines for `context` from the strays file: the convict section, and once a crew has taken them
 * in the deckhand section too (first for its everyday contexts, CONVICT_DECKHAND_CONTEXTS).
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_lines(context)
	var/list/sections = list("convict")
	if(convict_recruited)
		if(context in CONVICT_DECKHAND_CONTEXTS)
			sections.Insert(1, "deckhand")
		else
			sections += "deckhand"
	for(var/section in sections)
		var/list/lines = ambient_dialogue_lines(AMBIENT_STRINGS_STRAYS, section, context)
		if(length(lines))
			return lines
	return list()

/// Says a line for `context` from the strays file, now and then; `force` skips the wait. TRUE if they spoke.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_say(context, force = FALSE)
	if(stat != CONSCIOUS || (!force && world.time < convict_next_line))
		return FALSE
	var/list/lines = convict_lines(context)
	if(!length(lines))
		return FALSE
	convict_next_line = world.time + CONVICT_LINE_COOLDOWN
	INVOKE_ASYNC(src, TYPE_PROC_REF(/atom/movable, say), pick(lines))
	return TRUE

// Their own words where the strays file has them (seen and giving up, at the camp, cornered, cuffed),
// the bounty module's otherwise
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/bounty_say(context, list/values, force = FALSE)
	// The human NPC base's surrender bark: theirs is "Don't shoot! I'm not armed."
	if(context == HUMAN_NPC_BARK_SURRENDER)
		context = "sighted"
	if(!length(convict_lines(context)))
		return ..(context, values, force)
	return convict_say(context, force)

// ----- being seen -----

// Each look round for hunters is also a look for crews they have not seen yet. Giving up to one, they
// notice nobody else this look: they are lying there with their hands on their head.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/ai_look_around()
	if(convict_recruited)
		return null
	if(convict_look_for_crews() || npc_surrendering)
		return null
	return ..()

/// The first time someone of a ship crew comes into view: they give up, and maybe their bounty. TRUE if they saw a new crew.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_look_for_crews()
	if(convict_recruited || world.time < convict_next_look || hidden || !ai_can_act())
		return FALSE
	convict_next_look = world.time + CONVICT_LOOK_INTERVAL
	var/turf/here = get_turf(src)
	if(!here)
		return FALSE
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
		return TRUE
	return FALSE

/**
 * `person` of `ship` saw them. They give up the way a person does (npc_surrender(): whatever weapon is
 * in their hands goes in a pocket, "Don't shoot!", tg's *surrender, a real 20 second Paralyze, the cuff
 * window), and that crew may get a private bounty on them. If nobody cuffs them before they get up, the
 * meek AI carries on: calm, they can be talked to; at someone armed, they run.
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_sighted(mob/living/person, obj/structure/overmap/ship/ship)
	if(QDELETED(src) || stat != CONSCIOUS || convict_recruited)
		return
	if(!QDELETED(person))
		face_atom(person)
	npc_surrender()
	convict_post_bounty(ship)

/**
 * Their private petty bounty, for `ship`: once ever, and only if the ship has room for another
 * private offer. board_post() rolls a record of its own, so the posting takes theirs instead, and
 * the card shows who the crew actually saw. Returns the posting, or null.
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_post_bounty(obj/structure/overmap/ship/ship)
	if(convict_posted || convict_recruited || QDELETED(ship) || !record || posting() || stat == DEAD)
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
 * ground (not dead, in crit, cuffed or aboard a ship): they stay where they are, off the board.
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_on_posting_closed(datum/source, reason, obj/structure/overmap/ship/winner)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_BOUNTY_POSTING_CLOSED)
	var/datum/criminal_bounty/posting = source
	if(reason == BOUNTY_CLOSE_CLAIMED || QDELETED(src) || posting.criminal() != src)
		return
	if(stat == DEAD || is_downed() || is_restrained() || get_ship_from_atom(src))
		return
	posting.board_detach_criminal()
	posting_ref = null
	REMOVE_TRAIT(src, TRAIT_MISSION_FIELD_MOB, BOUNTY_TRAIT)

// ----- being talked down -----

/// Whether they would talk: awake, calm, on their feet, not hidden, stunned or cuffed, and not taken in already
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_can_talk()
	if(convict_recruited || stat != CONSCIOUS || hidden || is_downed() || is_restrained() || HAS_TRAIT(src, TRAIT_BOUNTY_REMOVED))
		return FALSE
	return ai_can_act() && ai_mode == BOUNTY_AI_CALM

// An empty hand: the plea while they are wild, follow or stay once a crew has them. Anything else (they
// are down, asleep or on fire) is tg's own help: CPR, shaking them awake, patting them out.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/attack_hand(mob/living/carbon/human/user, list/modifiers)
	if(istype(user) && !user.combat_mode && !LAZYACCESS(modifiers, RIGHT_CLICK))
		if(convict_recruited)
			var/obj/structure/overmap/ship/ship = convict_ship()
			if(ship && convict_follower_can_talk() && ambient_crew_ship(user) == ship)
				INVOKE_ASYNC(src, PROC_REF(convict_crew_menu), user)
				return TRUE
		else if(convict_can_talk())
			INVOKE_ASYNC(src, PROC_REF(convict_talk), user)
			return TRUE
	return ..()

/// A word with `user`, and to a crew member with room aboard, the plea. Sleeps.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_talk(mob/living/user)
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
 * They go with `leader` to `ship`, in the same body (defaults 1.9): their bounty is withdrawn unpaid,
 * they come off the board for good, their side changes to the people's (FACTION_NEUTRAL, as a player's)
 * and their AI to the follower's, set on `leader`. The ship counts them as one of the strays it took this
 * round (recruit.dm's limits). Returns them, or null if they can't go now.
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_join(mob/living/leader, obj/structure/overmap/ship/ship)
	if(convict_recruited || stat == DEAD || !isturf(loc) || QDELETED(ship) || QDELETED(leader))
		return null
	// Off its posting first, so closing it takes nobody away
	var/datum/criminal_bounty/posting = posting()
	if(posting)
		UnregisterSignal(posting, COMSIG_BOUNTY_POSTING_CLOSED)
		posting.board_detach_criminal()
	posting_ref = null
	convict_mark_site_taken()
	convict_site_ref = null
	ai_put_out_camp()
	ai_end_activity()
	// Withdrawn unpaid: the crew who saw them are told, as for any offer that ends
	posting?.close(CONVICT_CLOSE_RECRUITED)
	convict_leave_board()
	convict_recruited = TRUE
	convict_ship_ref = WEAKREF(ship)
	var/datum/ambient_place/ship/deck = ambient_ship_place(ship)
	if(deck)
		deck.taken++
	faction = list(FACTION_NEUTRAL)
	new /datum/ai_controller/basic_controller/convict_follower(src)
	convict_follow(leader)
	convict_say("accepted", force = TRUE)
	log_game("AMBIENT: the escaped convict [real_name] went with the [ship.name], talked down by [key_name(leader)]")
	return src

/**
 * Takes the bounty body's rules off them, for a convict who is no criminal any more: the sweep
 * protection, the teleport and mob-swap block, the body's signal hooks (teleport, polymorph and
 * type-change refusals, grudges), any container's teleport block, the leash and the grudge list. Off the
 * convict count. Its corpse is an ordinary human NPC's from now on: the corpse sweep may clear it.
 */
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_leave_board()
	REMOVE_TRAIT(src, TRAIT_MISSION_FIELD_MOB, BOUNTY_TRAIT)
	remove_traits(list(TRAIT_NO_TELEPORT, TRAIT_NOMOBSWAP), BOUNTY_BODY_TRAIT)
	qdel(GetComponent(/datum/component/bounty_body))
	body_set_holder(null)
	body_set_site(null)
	grudge.Cut()
	ai_set_mode(BOUNTY_AI_CALM)
	GLOB.ambient_convicts -= WEAKREF(src)
	npc_corpse_lifetime = HUMAN_NPC_CORPSE_LIFETIME

// Taken in, nothing they sit in is held back from a teleport any more
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/body_set_holder(atom/movable/holder)
	return ..(convict_recruited ? null : holder)

// Taken in, they let their own crew cuff them
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/body_on_cuff_attempt(mob/living/user)
	if(convict_recruited)
		return
	return ..()

// =========================================================================
// THE CONVICT WHO WENT WITH A CREW
// =========================================================================

/// The ship whose crew took them in, if it is still there
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_ship()
	var/obj/structure/overmap/ship/ship = convict_ship_ref?.resolve()
	return QDELETED(ship) ? null : ship

/// That ship's deckhand place (recruit.dm), if any
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_deck()
	var/obj/structure/overmap/ship/ship = convict_ship()
	return ship ? ambient_ship_place(ship, create = FALSE) : null

/// Whether `spot` is aboard the ship that took them in
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_on_ship(turf/spot)
	var/datum/ambient_place/ship/deck = convict_deck()
	return !!deck?.aboard(get_turf(spot))

/// Who they follow, or null while they stay where they are
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_leader()
	var/mob/living/leader = ai_controller?.blackboard[BB_CONVICT_LEADER]
	return QDELETED(leader) ? null : leader

/// They follow `leader` from now on. TRUE if they will.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_follow(mob/living/leader)
	if(!isliving(leader) || QDELETED(leader) || !istype(ai_controller, /datum/ai_controller/basic_controller/convict_follower))
		return FALSE
	ai_controller.set_blackboard_key(BB_CONVICT_LEADER, leader)
	ai_controller.clear_blackboard_key(BB_CONVICT_LOST_SINCE)
	return TRUE

/// They stay where they are
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_stay()
	ai_controller?.clear_blackboard_key(BB_CONVICT_LEADER)
	ai_controller?.clear_blackboard_key(BB_CONVICT_LOST_SINCE)

/// Their leader has been out of reach too long: they wait where they are for someone of the crew
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_lose_leader()
	convict_stay()
	convict_say("lost", force = TRUE)

/// Whether `leader` can still be followed: alive, on this level, near enough
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_leader_in_reach(mob/living/leader)
	var/turf/there = get_turf(leader)
	return !QDELETED(leader) && leader.stat != DEAD && there && isturf(loc) && there.z == z && get_dist(src, there) <= CONVICT_FOLLOW_RANGE

/// Whether they would answer a crew member: awake and on their feet
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_follower_can_talk()
	return stat == CONSCIOUS && !body_is_stunned()

/// Follow or stay, for `user` of their ship. Sleeps.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_crew_menu(mob/living/user)
	var/key = REF(user)
	if(LAZYACCESS(convict_talk_cooldowns, key) > world.time)
		return
	LAZYSET(convict_talk_cooldowns, key, world.time + CONVICT_TALK_COOLDOWN)
	if(!buckled)
		face_atom(user)
	convict_say("talk", force = TRUE)
	var/list/choices = list()
	if(convict_leader() == user)
		choices["Stay here"] = image(icon = 'icons/hud/radial.dmi', icon_state = "guard")
	else
		choices["Follow me"] = image(icon = 'icons/hud/radial.dmi', icon_state = "move")
	var/choice = show_radial_menu(user, src, choices, require_near = TRUE, tooltips = TRUE, autopick_single_option = FALSE)
	if(QDELETED(src) || QDELETED(user) || !convict_follower_can_talk() || ambient_crew_ship(user) != convict_ship())
		return
	switch(choice)
		if("Follow me")
			if(convict_follow(user))
				convict_say("follow", force = TRUE)
		if("Stay here")
			convict_stay()
			convict_say("wait", force = TRUE)

/// The first time they stand aboard their crew's ship: the line, and they live aboard from now on. TRUE if they just stepped aboard.
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_board_if_aboard()
	if(!convict_recruited || convict_aboard || !convict_on_ship(get_turf(src)))
		return FALSE
	convict_aboard = TRUE
	convict_next_idle_line = world.time + rand(CONVICT_IDLE_LINE_LOW, CONVICT_IDLE_LINE_HIGH)
	convict_say("aboard", force = TRUE)
	var/obj/structure/overmap/ship/ship = convict_ship()
	log_game("AMBIENT: the escaped convict [real_name] came aboard the [ship?.name || "ship"]")
	return TRUE

/// Aboard, now and then a word while somebody is near
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_idle_chatter()
	if(!convict_aboard || world.time < convict_next_idle_line)
		return
	convict_next_idle_line = world.time + rand(CONVICT_IDLE_LINE_LOW, CONVICT_IDLE_LINE_HIGH)
	var/turf/here = get_turf(src)
	if(here && ambient_any_player_near(here, 5))
		convict_say("idle")

/// Hit by someone of the crew they follow: they stop following and say so
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_hit_by(mob/living/attacker)
	if(QDELETED(src) || stat != CONSCIOUS || !isliving(attacker))
		return
	var/obj/structure/overmap/ship/ship = convict_ship()
	if(!ship || ambient_crew_ship(attacker) != ship || !convict_leader())
		return
	convict_stay()
	convict_say("attacked", force = TRUE)

/// Where they may take a step of their own: never into lava, a chasm or the like; aboard, never off the ship; never out into no air without a sealed suit, unless they are out in it already
/mob/living/carbon/human/npc/bounty_criminal/meek/convict/proc/convict_may_step(turf/next)
	next = get_turf(next)
	if(!next)
		return TRUE
	if(!next.can_cross_safely(src))
		return FALSE
	var/turf/here = get_turf(src)
	if(convict_aboard && convict_on_ship(here) && !convict_on_ship(next))
		return FALSE
	if(!is_atmos_sealed() && convict_airless(next) && !convict_airless(here))
		return FALSE
	return TRUE

/// Whether `spot` has too little air to stand in unsuited (read only: never materialises a planet turf's air)
/proc/convict_airless(turf/spot)
	if(!isopenturf(spot))
		return FALSE
	var/datum/gas_mixture/air = spot.return_air_readonly()
	return isnull(air) || air.return_pressure() < HAZARD_LOW_PRESSURE

// =========================================================================
// THE FOLLOWER'S AI
// =========================================================================

/**
 * A talked-down convict's AI: a human pawn (human_npc_ai_able_to_run(), so it stops while stunned,
 * knocked down or out, and in soft crit only crawls, pleads and uses a medipen). It never picks a fight:
 * no target finding at all, so turrets read it as harmless. It backs off from whoever hit it and from
 * anything fighting it or its leader, and otherwise walks after its leader (running to catch up), by a
 * pathfinder that keeps out of hazards and airless ground and, once it is aboard, on the ship.
 */
/datum/ai_controller/basic_controller/convict_follower
	ai_movement = /datum/ai_movement/jps/convict_follower
	planning_subtrees = list(
		/datum/ai_planning_subtree/human_npc_soft_crit,
		/datum/ai_planning_subtree/convict_keep_clear,
		/datum/ai_planning_subtree/convict_follow,
	)

/datum/ai_controller/basic_controller/convict_follower/TryPossessPawn(atom/new_pawn)
	if(!istype(new_pawn, /mob/living/carbon/human/npc/bounty_criminal/meek/convict))
		return AI_CONTROLLER_INCOMPATIBLE
	new_pawn.AddElement(/datum/element/relay_attackers)
	RegisterSignal(new_pawn, COMSIG_ATOM_WAS_ATTACKED, PROC_REF(on_pawn_attacked))
	return ..()

/datum/ai_controller/basic_controller/convict_follower/UnpossessPawn(destroy)
	if(pawn)
		UnregisterSignal(pawn, COMSIG_ATOM_WAS_ATTACKED)
	return ..()

/datum/ai_controller/basic_controller/convict_follower/get_able_to_run()
	return human_npc_ai_able_to_run(src)

/datum/ai_controller/basic_controller/convict_follower/on_stat_changed(mob/living/source, new_stat)
	. = ..()
	human_npc_ai_stat_changed(src, new_stat)

/// Someone hit it: it keeps clear of them for a while, and if it was its own crew, it stops following
/datum/ai_controller/basic_controller/convict_follower/proc/on_pawn_attacked(mob/living/source, atom/attacker, attack_flags)
	SIGNAL_HANDLER
	if(source == attacker || !isliving(attacker) || !(attack_flags & (ATTACKER_DAMAGING_ATTACK | ATTACKER_STAMINA_ATTACK | ATTACKER_SHOVING)))
		return
	set_blackboard_key(BB_CONVICT_HIT_BY, attacker)
	set_blackboard_key(BB_CONVICT_HIT_UNTIL, world.time + CONVICT_SHY_TIME)
	INVOKE_ASYNC(source, TYPE_PROC_REF(/mob/living/carbon/human/npc/bounty_criminal/meek/convict, convict_hit_by), attacker)

/// Backs off from a fight near it: whoever hit it lately, or anything set on it or its leader
/datum/ai_planning_subtree/convict_keep_clear

/datum/ai_planning_subtree/convict_keep_clear/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = controller.pawn
	if(!istype(convict) || convict.stat != CONSCIOUS)
		return
	var/mob/living/threat = convict_nearest_fight(controller)
	if(isnull(threat))
		return
	controller.set_blackboard_key(BB_CONVICT_AVOID, threat)
	controller.queue_behavior(/datum/ai_behavior/run_away_from_target, BB_CONVICT_AVOID)
	return SUBTREE_RETURN_FINISH_PLANNING

/// The fight `controller`'s pawn should keep clear of, or null
/proc/convict_nearest_fight(datum/ai_controller/controller)
	var/mob/living/pawn = controller.pawn
	var/mob/living/hitter = controller.blackboard[BB_CONVICT_HIT_BY]
	if(isliving(hitter) && !QDELETED(hitter) && hitter.stat == CONSCIOUS && world.time < controller.blackboard[BB_CONVICT_HIT_UNTIL] && can_see(pawn, hitter, CONVICT_FIGHT_RANGE))
		return hitter
	var/mob/living/leader = controller.blackboard[BB_CONVICT_LEADER]
	var/mob/living/closest
	var/closest_distance = INFINITY
	for(var/mob/living/other in oview(CONVICT_FIGHT_RANGE, pawn))
		var/datum/ai_controller/their_ai = other.ai_controller
		if(other.stat != CONSCIOUS || other.client || !istype(their_ai))
			continue
		var/atom/their_target = their_ai.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
		if(isnull(their_target) || (their_target != pawn && their_target != leader))
			continue
		var/distance = get_dist(pawn, other)
		if(distance < closest_distance)
			closest = other
			closest_distance = distance
	return closest

/// Walks after its leader, says its line on stepping aboard, and loses a leader out of reach too long
/datum/ai_planning_subtree/convict_follow

/datum/ai_planning_subtree/convict_follow/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = controller.pawn
	if(!istype(convict) || convict.stat != CONSCIOUS)
		return
	convict.convict_board_if_aboard()
	var/mob/living/leader = controller.blackboard[BB_CONVICT_LEADER]
	if(isnull(leader))
		convict.convict_idle_chatter()
		return
	if(!convict.convict_leader_in_reach(leader))
		var/lost_since = controller.blackboard[BB_CONVICT_LOST_SINCE]
		if(!lost_since)
			controller.set_blackboard_key(BB_CONVICT_LOST_SINCE, world.time)
		else if(world.time - lost_since >= CONVICT_LOST_TIME)
			convict.convict_lose_leader()
		return
	controller.clear_blackboard_key(BB_CONVICT_LOST_SINCE)
	var/distance = get_dist(convict, leader)
	var/run = distance > CONVICT_RUN_DISTANCE
	if((convict.move_intent == MOVE_INTENT_RUN) != run)
		convict.toggle_move_intent()
	if(distance <= 2)
		if(!convict.buckled)
			convict.face_atom(leader)
		convict.convict_idle_chatter()
		return
	// Aboard, it stays aboard: it waits for a leader who has gone off the ship
	if(convict.convict_aboard && !convict.convict_on_ship(get_turf(leader)))
		return
	controller.queue_behavior(/datum/ai_behavior/convict_follow, BB_CONVICT_LEADER)
	return SUBTREE_RETURN_FINISH_PLANNING

/// Walks to its leader's side, following them as they move
/datum/ai_behavior/convict_follow
	required_distance = 1
	action_cooldown = 0.5 SECONDS
	behavior_flags = AI_BEHAVIOR_REQUIRE_MOVEMENT | AI_BEHAVIOR_MOVE_AND_PERFORM | AI_BEHAVIOR_CAN_PLAN_DURING_EXECUTION

/datum/ai_behavior/convict_follow/setup(datum/ai_controller/controller, leader_key)
	. = ..()
	var/atom/leader = controller.blackboard[leader_key]
	if(QDELETED(leader))
		return FALSE
	set_movement_target(controller, leader)

/datum/ai_behavior/convict_follow/perform(seconds_per_tick, datum/ai_controller/controller, leader_key)
	var/mob/living/leader = controller.blackboard[leader_key]
	if(QDELETED(leader) || leader.stat == DEAD)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_FAILED
	if(get_dist(controller.pawn, leader) <= 1)
		return AI_BEHAVIOR_INSTANT | AI_BEHAVIOR_SUCCEEDED
	return AI_BEHAVIOR_DELAY

/// Smart pathing that keeps a follower out of hazards and airless ground, and aboard once it lives there
/datum/ai_movement/jps/convict_follower

/datum/ai_movement/jps/convict_follower/allowed_to_move(datum/move_loop/has_target/jps/source)
	. = ..()
	if(!.)
		return
	var/list/path = source.movement_path
	if(!length(path))
		return
	var/mob/living/carbon/human/npc/bounty_criminal/meek/convict/convict = source.moving
	if(istype(convict) && !convict.convict_may_step(path[1]))
		return FALSE

/*
 * PHASE D CORE REQUEST: bounty_blocks_transport(), bounty_holds_living_criminal() and
 * bounty_blocks_bag_fold() (bounty_turn_in.dm) and bounty_is_gang_body() (bounty_criminal.dm) go by type
 * alone, so a talked-down convict (still a /bounty_criminal type, posting_ref null, convict_recruited TRUE)
 * can't ride a transporter beam, be sent on a contract pad or be folded into a bluespace body bag while it
 * lives, and other criminals never take it for a target. A shared "is this body wanted on anything" check
 * (a posting, or not a recruited convict) in those procs would fix it; this file can't reach them.
 */

#undef CONVICT_SIGHT_RANGE
#undef CONVICT_LOOK_INTERVAL
#undef CONVICT_LINE_COOLDOWN
#undef CONVICT_TALK_COOLDOWN
#undef CONVICT_CLOSE_RECRUITED
#undef CONVICT_FOLLOW_RANGE
#undef CONVICT_LOST_TIME
#undef CONVICT_RUN_DISTANCE
#undef CONVICT_SHY_TIME
#undef CONVICT_FIGHT_RANGE
#undef CONVICT_IDLE_LINE_LOW
#undef CONVICT_IDLE_LINE_HIGH
#undef CONVICT_DECKHAND_CONTEXTS
#undef BB_CONVICT_LEADER
#undef BB_CONVICT_LOST_SINCE
#undef BB_CONVICT_HIT_BY
#undef BB_CONVICT_HIT_UNTIL
#undef BB_CONVICT_AVOID
