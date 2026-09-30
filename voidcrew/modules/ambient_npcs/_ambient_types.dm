/**
 * # World population: shared types
 *
 * Owner: P0 seams (frozen). Every package reads these; none redefines them.
 *
 * The types every package builds on, and every var they share. A package that needs a var only it
 * uses declares it in its own file on its own subtype. Procs live in:
 * - ambient_npc.dm: the base NPC (protections, looks, dialogue, reactions, leash);
 * - ambient_activity.dm: the routine base, the runner that drives it, and the generic activities;
 * - ambient_subsystem.dm: SSambient_npcs, the places (outposts, planet and field sites) and the
 *   planet records, site kinds and outpost roles.
 *
 * Packages add subtypes in their own files:
 * - PA (outpost_patrons.dm, outpost_workers.dm, outpost_angler.dm): /datum/ambient_outpost_role
 *   subtypes and their NPCs;
 * - PB (planet_*.dm): /datum/ambient_site_kind subtypes, their NPCs and props, the fish and mine
 *   activities;
 * - PC (recruit.dm, stranded*.dm, convict.dm): strays, the recruit flow;
 * - PD (faction_recruiters.dm): /datum/ambient_outpost_role subtypes for the recruiters.
 */

/// Every ambient NPC in the world, dead or alive, until it is deleted
GLOBAL_LIST_EMPTY(ambient_npcs)

// =========================================================================
// THE BASE NPC
// =========================================================================

/**
 * A person who lives in the world: dressed as a random person in an outfit, protected against
 * being dragged, boxed, teleported or turned into something else, environment-proof, kept to a
 * leash, talking from a dialogue file and going about a routine of activities.
 *
 * Anyone can be killed. A body drops a little cash (`death_cash_low` to `death_cash_high`, capped
 * by their place) and any `death_loot`, once: never again after a revive. Hurting one at a trader
 * outpost is violence there, like hurting a visitor.
 */
/mob/living/basic/ambient_npc
	name = "spacer"
	desc = "Someone passing through."
	icon = 'icons/mob/simple/simple_human.dmi'
	icon_state = ""
	gender = MALE
	unique_name = FALSE
	combat_mode = FALSE
	mob_biotypes = MOB_ORGANIC | MOB_HUMANOID
	sentience_type = SENTIENCE_HUMANOID
	// Nobody drags them off, and nobody pulls them out of their room
	move_resist = MOVE_FORCE_VERY_STRONG
	density = TRUE
	// A body stays where it fell (the planet sweep takes it with the fauna)
	basic_mob_flags = NONE
	maxHealth = 80
	health = 80
	// An unhurried walk
	speed = 2.5
	melee_damage_lower = 0
	melee_damage_upper = 0
	// Airless or frozen ground must not kill them in forty seconds (basic mob defaults do)
	unsuitable_atmos_damage = 0
	unsuitable_cold_damage = 0
	unsuitable_heat_damage = 0
	speak_emote = list("says")
	response_help_continuous = "talks to"
	response_help_simple = "talk to"
	ai_controller = /datum/ai_controller/basic_controller/ambient_npc

	// ----- Look -----
	/// The outfit whose worn look they wear
	var/outfit = /datum/outfit/job/assistant
	/// If set, one of these is picked for `outfit` when they are made
	var/list/outfit_choices
	/// Which person in that outfit (outpost_npc_looks.dm); random when null
	var/look_number
	/// Pick a random gender when made
	var/random_gender = TRUE
	/// Give them a random real name when made; a fixed `name` otherwise
	var/random_name = TRUE
	/// "idle", "weld" and "tool" looks, for NPCs that do work (built when `work_weights` is set)
	var/list/work_looks
	/// What they hold, drawn in their hand as part of their look: an /obj/item type, or null
	var/held_visual
	/// "weld", "tool" or "carry": the work look shown now (null for none)
	var/work_look
	/// Bumped by every look build; an async build applies only if it is still the latest one
	var/look_serial = 0
	/// A real item they carry for an activity (a drink), in their contents, never dropped by a hit
	var/obj/item/held_item

	// ----- Death -----
	/// Cash they carry, dropped on death once (their place may cap it: ambient_place/proc/cash_for()). 0 for none.
	var/death_cash_low = AMBIENT_DEATH_CASH_LOW
	var/death_cash_high = AMBIENT_DEATH_CASH_HIGH
	/// Item types dropped on death, once
	var/list/death_loot
	/// Their death loot has dropped: a revived NPC does not drop it again
	var/loot_dropped = FALSE
	/// Their place has counted their death: a revived NPC killed again is not counted twice
	var/death_counted = FALSE

	// ----- Where they belong -----
	/// The outpost, planet site or field site they belong to, if any
	var/datum/ambient_place/place
	/// The outpost role that brought them (a /datum/ambient_outpost_role type), if any
	var/role
	/// Where they were made; the leash's anchor
	var/turf/home
	/// A rectangle they keep to, list(min x, min y, max x, max y, z), or null for anywhere their place allows
	var/list/leash_bounds
	/// world.time they were first found off their leash with their AI on (0 while on it)
	var/leash_broken_at = 0

	// ----- Dialogue -----
	/// Their dialogue file in AMBIENT_STRINGS_DIR; contexts it lacks fall back to AMBIENT_STRINGS_CORE
	var/dialogue_file = AMBIENT_STRINGS_CORE
	/// Their section of that file
	var/dialogue_section = "default"
	/// Scales their pause between spontaneous lines: 0.5 is chatty, 2 is quiet
	var/speech_pace = 1
	/// world.time of their next spontaneous line
	var/next_line_at = 0
	/// REF of a player -> world.time they may get another answer
	var/list/talk_cooldowns
	/// Kind of reaction -> world.time it may happen again
	var/list/reaction_cooldowns

	// ----- Routine -----
	/// What they do when nothing else is going on: /datum/ambient_activity types with weights
	var/list/routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 3,
		/datum/ambient_activity/sit = 2,
		/datum/ambient_activity/chat = 2,
	)
	/// The work they do at objects (/datum/outpost_ambient_work types with weights), for /datum/ambient_activity/work
	var/list/work_weights
	/// What they are doing now
	var/datum/ambient_activity/activity
	/// world.time before which nothing new is set up after a failure
	var/activity_retry_at = 0
	/// Walks that ended stuck for the current activity's spot
	var/travel_failures = 0
	/// Weakref to the seat they sat down on, so only that one is ever left
	var/datum/weakref/seat_ref
	/// Sitting on the floor or ducking
	var/crouching = FALSE
	/// Glasses left on tables this visit (AMBIENT_GLASSES_MAX)
	var/glasses_left = 0
	/// Fading out: nothing starts any more
	var/fading = FALSE
	/// world.time they stopped where they were because nobody was at their outpost (pause_routine()), or 0 while they carry on
	var/paused_at = 0

// =========================================================================
// ACTIVITIES
// =========================================================================

/**
 * Something an NPC does. setup() finds what it uses once and sets `spot`; the NPC walks there and
 * arrive() runs; act() runs about once a second and returns AMBIENT_STEP_*; finish() puts
 * everything back. A higher `priority` activity replaces a lower one (reactions, leaving).
 */
/datum/ambient_activity
	/// Short text for the admin verb
	var/name = "standing around"
	/// Who is doing it
	var/mob/living/basic/ambient_npc/doer
	/// Weakref to what it happens at, if anything
	var/datum/weakref/anchor_ref
	/// Where to go, or null where they stand
	var/turf/spot
	/// How close to `spot` counts as there: 0 on it, 1 beside it
	var/spot_distance = 0
	/// arrive() has run for this spot
	var/arrived = FALSE
	/// AMBIENT_PRIORITY_*
	var/priority = AMBIENT_PRIORITY_ROUTINE
	/// world.time it ends by itself (0: when act() says so)
	var/ends_at = 0
	/// How long it lasts, when it lasts a set time
	var/duration_low = 30 SECONDS
	var/duration_high = 90 SECONDS
	/// world.time of the next line
	var/next_line = 0
	/// Another NPC may pull them into a chat while this runs
	var/accepts_company = FALSE
	/// Turfs this activity could not walk to (turf = TRUE)
	var/list/failed_spots

// =========================================================================
// PLACES
// =========================================================================

/**
 * Where ambient NPCs live: a trader outpost's concourse, or one planet or field site. Holds its NPCs
 * and a speech clock shared by all of them, so a full room never talks over itself.
 */
/datum/ambient_place
	/// Short text for the admin verb
	var/name = "somewhere"
	/// The NPCs here, dead or alive, until they are deleted
	var/list/mob/living/basic/ambient_npc/npcs = list()
	/// world.time anyone here may say a spontaneous line
	var/next_line_at = 0
	/// The zone band (ZONE_*) it lies in, if known
	var/band

/**
 * A trader outpost's concourse and the people who are there all round. Made the first time
 * SSambient_npcs sees the outpost loaded; kept for the round (outposts never unload). Its roles
 * are filled in place while nobody is on the concourse, and its people hold still until someone
 * comes; while players are there, anyone who leaves is replaced by the lift.
 */
/datum/ambient_place/outpost
	/// The outpost
	var/datum/weakref/outpost_ref
	/// A player is on the concourse: its people carry on, and anyone who leaves is replaced by the lift
	var/occupied = FALSE
	/// Living players with a client on the concourse at the last tick
	var/players = 0
	/// world.time the next arrival may step off the lift
	var/arrivals_at = 0
	/// Its roles may be short: they are filled in place while nobody is here
	var/needs_settling = TRUE
	/// world.time a killed person's place opens again and it is worth filling roles in place, or 0
	var/refill_at = 0
	/// Role type -> world.times its killed people's places stay empty until (AMBIENT_OUTPOST_KILLED_SLOT_TIME)
	var/list/killed_until = list()
	/// Cash its people have dropped when killed this round (AMBIENT_OUTPOST_CASH_CAP)
	var/cash_dropped = 0
	/// The concourse's public floor (turf = TRUE), from the lift, and when it was worked out
	var/list/public_floor
	var/floor_built_at = 0
	/// Role type -> world.time the next NPC of that role may arrive
	var/list/role_next_at = list()
	/// The kingpin's crew is fighting here, and everyone was sent to this turf
	var/turf/shootout_refuge
	/// The concourse, list(min x, min y, max x, max y, z), once the outpost has loaded
	var/list/concourse

/**
 * One planet or asteroid field site: a camp, a pod, a boat. Rolled once, with a kind; its NPCs come
 * and go with the planet's fauna. A site whose NPCs were all killed is spent for the round.
 */
/datum/ambient_place/site
	/// What it is (a shared /datum/ambient_site_kind instance)
	var/datum/ambient_site_kind/kind
	/// Where it is
	var/turf/center
	/// AMBIENT_SITE_DORMANT, _ACTIVE or _SPENT
	var/state = AMBIENT_SITE_DORMANT
	/// How many NPCs it has when nobody has died
	var/npc_total = 1
	/// How many of them were killed
	var/dead = 0
	/// Weakrefs to what the kind built here (a camp, a boat): kept when the NPCs go
	var/list/props = list()
	/// Where its NPCs take cover from a storm, if anywhere
	var/turf/shelter
	/// The planet it is on, or null on an asteroid field
	var/datum/ambient_planet/planet
	/// The asteroid field it is on, if any
	var/datum/weakref/field_ref
	/// Anything else the kind keeps about this site
	var/list/data = list()

/**
 * What SSambient_npcs knows about one loaded planet: its type, band and ground, and the sites rolled
 * at the first arrival. Forgotten when the planet unloads (its next build is a new planet).
 */
/datum/ambient_planet
	/// The SSplanet_mobs tracker key (the planet's REF)
	var/key
	/// The overmap planet
	var/datum/weakref/planet_ref
	/// The planet's datum type (/datum/overmap/planet/*)
	var/planet_type
	/// ZONE_GREEN, _YELLOW or _RED
	var/band
	/// Its ground: list(min x, min y, max x, max y, z)
	var/list/bounds
	/// The top row of its dock strip, or null
	var/dock_top_y
	/// Its sites were rolled
	var/rolled = FALSE
	/// Its sites (/datum/ambient_place/site)
	var/list/sites = list()

// =========================================================================
// WHAT CAN APPEAR
// =========================================================================

/**
 * One kind of planet or field site (PB, PC subtype it). Shared instances, one per type, made by
 * SSambient_npcs; a kind with no `planet_types` and no `field_chance` never rolls.
 */
/datum/ambient_site_kind
	/// Short text for the admin verb
	var/name = "site"
	/// Planet datum types it can roll on (/datum/overmap/planet/*)
	var/list/planet_types = list()
	/// Zone bands it can roll in
	var/list/bands = list(ZONE_GREEN, ZONE_YELLOW, ZONE_RED)
	/// Percent chance it rolls on a planet it fits
	var/chance = 0
	/// Percent chance it rolls on an asteroid field's one-time population
	var/field_chance = 0
	/// How many NPCs it has
	var/min_npcs = 1
	var/max_npcs = 1
	/// Radius of clear ground its spot needs around it
	var/spot_room = 1
	/// Its spot may be water (the fishers find their own water; see spot_ok())
	var/spot_on_water = FALSE
	/// The NPC type realize() spawns by default
	var/npc_type

/**
 * One kind of NPC at trader outposts (PA, PD subtype it). Shared instances, one per type; a role
 * with no `npc_type` never comes. Its people are already there, at what they do, when players
 * reach an outpost (settle()); while players are there, anyone who left is replaced off the lift
 * (arrive()).
 */
/datum/ambient_outpost_role
	/// Short text for the admin verb
	var/name = "visitor"
	/// The NPC type that comes
	var/npc_type
	/// Outpost types it comes to (/obj/structure/overmap/trader_outpost/*); empty for all
	var/list/outpost_types = list()
	/// Most of this role at one outpost at once
	var/max_count = 1
	/// Weight when several roles are due
	var/weight = 1
	/// Pause after one arrives before the next of this role may
	var/gap_low = 1 MINUTES
	var/gap_high = 3 MINUTES
