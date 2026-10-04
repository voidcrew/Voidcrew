/**
 * # World population: planet and field sites (owner items 1, 7 to 11)
 *
 * Owner: PB (planet and field NPCs).
 *
 * The shared half of PB. Each camp's own NPCs, props and realize() live beside it:
 * planet_miner.dm (the miner, and /datum/ambient_activity/mine), planet_jungle.dm (the cannibal
 * and the tribal band), planet_fishers.dm (/datum/ambient_activity/fish, the lava and boat
 * fishers) and planet_peddler.dm (the wandering trader's caravan).
 *
 * Here:
 * - /datum/ambient_site_kind/planet and its subtypes: which camps roll on which planet types and
 *   how often (spec 4.1), and how many people they have. The spot finders the core's does not
 *   cover (a rock face with ore, a lava bank, open water) sit beside each camp's realize().
 * - /mob/living/basic/ambient_npc/planet: the killable planet person every PB NPC builds on. Loot
 *   drops once, the body falls over, they fight back (or run) when attacked, a camp fights
 *   together, and a camp that watches for strangers does it in watch().
 * - Shared activities: fight, flee, follow, camp_chore and nap.
 * - Scenery (/obj/effect/ambient_camp_prop): lamps, rugs and mats nobody can carry off, so a camp
 *   that is put back each visit never becomes a loot pile.
 *
 * Seams (P0, frozen): SSambient_npcs rolls a planet's sites at the first arrival, brings each site
 * out whole or not at all on every visit out of the planet's fauna budget (site.spawn_npc()), and
 * the planet sweep takes the people away with the fauna. A site whose people were all killed is
 * spent for the round. Planet NPCs are never mapped: they only ever come from site data.
 */

/// Time between a fighter picking a fight and their first blow: the wind-up players see
#define PLANET_NPC_FIRST_BLOW_DELAY (1 SECONDS)
/// A fighter stops chasing anyone this far away
#define PLANET_NPC_CHASE_RANGE 14
/// A fighter whose target stays off their ground this long gives up and goes back
#define PLANET_NPC_GIVE_UP_TIME (8 SECONDS)
/// How far a frightened NPC runs
#define PLANET_NPC_FLEE_DISTANCE 7

// =========================================================================
// SITE KINDS
// =========================================================================

/**
 * PB's camps. Abstract: no npc_type and no chances, so it never rolls. A subtype sets
 * `planet_chances` (planet datum type -> percent) and its own realize().
 */
/datum/ambient_site_kind/planet
	name = "planet camp"
	/// Percent chance per planet datum type (/datum/overmap/planet/*), spec 4.1
	var/list/planet_chances = list()

/datum/ambient_site_kind/planet/New()
	. = ..()
	// For anyone reading the shared var: the planets this kind can roll on
	planet_types = list()
	for(var/planet_type in planet_chances)
		planet_types += planet_type

/datum/ambient_site_kind/planet/chance_on(datum/ambient_planet/record)
	if(!(record.band in bands))
		return 0
	return planet_chances[record.planet_type] || 0

/**
 * The rectangle a site's middle may be sampled from on `record`'s planet, the way the core's
 * find_spot() works it out: the planet's ground less its edge margin, clear of the dock strip.
 * list(min x, min y, max x, max y, z), or null.
 */
/datum/ambient_site_kind/planet/proc/spot_rect(datum/ambient_planet/record)
	var/list/bounds = record?.bounds
	if(length(bounds) < 5)
		return null
	var/low_x = bounds[1] + AMBIENT_SITE_EDGE_MARGIN
	var/high_x = bounds[3] - AMBIENT_SITE_EDGE_MARGIN
	var/low_y = bounds[2] + AMBIENT_SITE_EDGE_MARGIN
	if(!isnull(record.dock_top_y))
		low_y = max(low_y, record.dock_top_y + AMBIENT_SITE_DOCK_CLEARANCE)
	var/high_y = bounds[4] - AMBIENT_SITE_EDGE_MARGIN
	if(low_x > high_x || low_y > high_y)
		return null
	return list(low_x, low_y, high_x, high_y, bounds[5])

/// A random turf inside `rect` (from spot_rect()), or null
/proc/ambient_random_turf_in(list/rect)
	if(length(rect) < 5)
		return null
	return locate(rand(rect[1], rect[3]), rand(rect[2], rect[4]), rect[5])

/// Forgets what one visit knew (who was warned, who traded). Called as each visit's people come out.
/datum/ambient_site_kind/planet/proc/new_visit(datum/ambient_place/site/site)
	site.data["visit"] = list()

/// The per-visit memory of `site`: a list, made if missing
/proc/ambient_site_visit(datum/ambient_place/site/site)
	if(!istype(site))
		return list()
	var/list/visit = site.data["visit"]
	if(!islist(visit))
		visit = list()
		site.data["visit"] = visit
	return visit

/datum/ambient_site_kind/planet/on_depopulated(datum/ambient_place/site/site)
	new_visit(site)

/// Makes `prop_type` at `where` and remembers it as part of `site` (it stays when the people go). Returns the prop.
/datum/ambient_site_kind/planet/proc/make_prop(datum/ambient_place/site/site, prop_type, turf/where)
	if(!where || !ispath(prop_type, /atom/movable))
		return null
	return site.add_prop(new prop_type(where))

/// `site`'s prop of `prop_type`, made at `where` (or near the middle) if it is gone
/datum/ambient_site_kind/planet/proc/ensure_prop(datum/ambient_place/site/site, prop_type, turf/where)
	var/atom/movable/prop = site.get_prop(prop_type)
	if(prop)
		return prop
	where = where || ambient_free_turf_near(site.center, 2)
	return make_prop(site, prop_type, where)

// ----- the table (spec 4.1). PC's stranded and convict sites roll alongside these. -----

/// Owner item 1: a miner slowly working a rock face. Planets with rock, and asteroid fields.
/datum/ambient_site_kind/planet/miner
	name = "miner's camp"
	planet_chances = list(
		/datum/overmap/planet/jungle = 8,
		/datum/overmap/planet/lava = 12,
		/datum/overmap/planet/beach = 5,
		/datum/overmap/planet/ice = 12,
		/datum/overmap/planet/wasteland = 12,
	)
	field_chance = 10
	spot_room = 1
	npc_type = /mob/living/basic/ambient_npc/planet/miner

/// Owner item 7: a cannibal cooking a man over a fire. Jungle worlds.
/datum/ambient_site_kind/planet/cannibal
	name = "cannibal's fire"
	planet_chances = list(/datum/overmap/planet/jungle = 8)
	spot_room = 2
	npc_type = /mob/living/basic/ambient_npc/planet/cannibal

/// Owner item 8: a band of hunters with spears. Jungle worlds; bigger bands deeper out.
/datum/ambient_site_kind/planet/tribal
	name = "hunters' camp"
	planet_chances = list(/datum/overmap/planet/jungle = 12)
	min_npcs = 3
	max_npcs = 5
	spot_room = 3
	npc_type = /mob/living/basic/ambient_npc/planet/tribal

/datum/ambient_site_kind/planet/tribal/npc_count(band)
	switch(band)
		if(ZONE_RED)
			return 5
		if(ZONE_YELLOW)
			return 4
	return 3

/// Owner item 9: a miner fishing a lava river. Lava worlds.
/datum/ambient_site_kind/planet/lava_fisher
	name = "lava fisher's bank"
	planet_chances = list(/datum/overmap/planet/lava = 15)
	npc_type = /mob/living/basic/ambient_npc/planet/lava_fisher

/// Owner item 10: a fisher in a boat out on the ocean. Beach worlds.
/datum/ambient_site_kind/planet/boat_fisher
	name = "fishing boat"
	planet_chances = list(/datum/overmap/planet/beach = 18)
	spot_on_water = TRUE
	npc_type = /mob/living/basic/ambient_npc/planet/boat_fisher

/// Owner item 11: a peddler crossing the planet with a pack pony, and a guard deeper out.
/datum/ambient_site_kind/planet/peddler
	name = "peddler's caravan"
	planet_chances = list(
		/datum/overmap/planet/jungle = 6,
		/datum/overmap/planet/lava = 4,
		/datum/overmap/planet/beach = 8,
		/datum/overmap/planet/ice = 6,
		/datum/overmap/planet/wasteland = 6,
	)
	min_npcs = 2
	max_npcs = 3
	spot_room = 1
	npc_type = /mob/living/basic/ambient_npc/planet/peddler

// The peddler and the pony; a guard joins them in yellow and red
/datum/ambient_site_kind/planet/peddler/npc_count(band)
	return (band == ZONE_YELLOW || band == ZONE_RED) ? 3 : 2

// =========================================================================
// HELPERS
// =========================================================================

/// Living players with a client within `range` of `center`, on its level. Cheap: only the players on that level are looked at.
/proc/ambient_players_near(atom/center, range)
	. = list()
	var/turf/middle = get_turf(center)
	if(!middle || !islist(SSmobs.clients_by_zlevel) || middle.z > length(SSmobs.clients_by_zlevel))
		return
	for(var/mob/living/player in SSmobs.clients_by_zlevel[middle.z])
		if(player.stat == DEAD || !player.client || istype(player, /mob/living/basic/ambient_npc))
			continue
		var/turf/where = get_turf(player)
		if(where && get_dist(where, middle) <= range)
			. += player

/// Whether `who` has a weapon in hand: a gun, or anything that hits like a spear or harder
/proc/ambient_holds_weapon(mob/living/who)
	if(!who)
		return FALSE
	for(var/obj/item/held in who.held_items)
		if(istype(held, /obj/item/gun) || held.force >= 10)
			return TRUE
	return FALSE

/// A key for `user`'s crew (their ship), or for them alone if they have none
/proc/ambient_crew_key(mob/user)
	var/obj/structure/overmap/ship/ship = get_crew_ship(user)
	return ship ? REF(ship) : REF(user)

/// Whether `tile` belongs to a ruin or a ship: planet NPCs never work or camp there
/proc/ambient_off_limits(turf/tile)
	var/area/tile_area = get_area(tile)
	return !tile_area || istype(tile_area, /area/ruin) || istype(tile_area, /area/shuttle)

/// A square leash of `radius` around `center`, as list(min x, min y, max x, max y, z)
/proc/ambient_square_bounds(turf/center, radius)
	center = get_turf(center)
	if(!center)
		return null
	return list(center.x - radius, center.y - radius, center.x + radius, center.y + radius, center.z)

// =========================================================================
// THE PLANET PERSON
// =========================================================================

/**
 * Someone living on a planet or an asteroid: killable (health scaled by band where they spawn,
 * site.spawn_npc()), their loot dropped once, their body falling over. Fighters fight back when
 * attacked and their camp joins in; everyone else runs. A camp that watches for strangers does it
 * in watch(), about every two seconds while they are awake.
 */
/mob/living/basic/ambient_npc/planet
	name = "drifter"
	desc = "Someone living rough."
	dialogue_file = AMBIENT_STRINGS_PLANETS
	dialogue_section = "any"
	routine = list(
		/datum/ambient_activity/idle = 2,
		/datum/ambient_activity/wander = 2,
	)
	/// Fights back when attacked. Otherwise they run.
	var/fights_back = FALSE
	/// Joins in when someone at their camp is attacked
	var/joins_camp_fights = FALSE
	/// The real item they fight with (its numbers, bounty_real_weapon()); null for fists
	var/weapon_type
	/// What they hold when nothing is going on (a spear, a club), or null
	var/idle_held
	/// Time between their blows
	var/blow_interval = 1.2 SECONDS
	/// Below this share of their health a fighter runs instead (0: never)
	var/flee_below = 0
	/// Their camp looks out for strangers (watch())
	var/watches = FALSE
	/// Asleep: they see nothing until woken
	var/sleeping = FALSE

/mob/living/basic/ambient_npc/planet/Initialize(mapload)
	. = ..()
	arm(weapon_type)
	show_idle_held()

/// Their blows hit like `item_type` (null: fists), and it is the weapon they show in a fight
/mob/living/basic/ambient_npc/planet/proc/arm(item_type)
	weapon_type = item_type
	var/datum/bounty_real_weapon/weapon = bounty_real_weapon(item_type)
	weapon.apply_melee(src)

/// Back to holding what they hold when nothing is going on
/mob/living/basic/ambient_npc/planet/proc/show_idle_held()
	if(stat == DEAD)
		return
	set_held(idle_held)

// A body lies down, and gets up again if they are revived
/mob/living/basic/ambient_npc/planet/look_dead()
	. = ..()
	transform = matrix().Turn(90)

/mob/living/basic/ambient_npc/planet/look_alive()
	. = ..()
	transform = matrix()

/mob/living/basic/ambient_npc/planet/Life(seconds_per_tick = SSMOBS_DT, times_fired)
	. = ..()
	if(!watches || sleeping || stat != CONSCIOUS || fading || !place || HAS_TRAIT(src, TRAIT_AI_PAUSED))
		return
	watch()

/**
 * Looks out for strangers: `players`, or the players near them when null (tests pass their own).
 * Override. Runs from Life(), so it must not sleep.
 */
/mob/living/basic/ambient_npc/planet/proc/watch(list/players)
	return

/// Wakes them from a nap
/mob/living/basic/ambient_npc/planet/proc/wake_up()
	if(!sleeping)
		return
	sleeping = FALSE
	if(istype(activity, /datum/ambient_activity/nap))
		end_activity()

/// Whether they could go after `target`: someone alive and near, never one of their own camp
/mob/living/basic/ambient_npc/planet/proc/can_fight(mob/living/target)
	if(!fights_back || QDELETED(target) || !isliving(target) || target.stat == DEAD || target == src)
		return FALSE
	if(istype(target, /mob/living/basic/ambient_npc))
		var/mob/living/basic/ambient_npc/other = target
		if(other.place == place)
			return FALSE
	var/turf/here = get_turf(src)
	var/turf/there = get_turf(target)
	return here && there && here.z == there.z && get_dist(here, there) <= PLANET_NPC_CHASE_RANGE

/// Goes after `target`, unless already fighting them. Returns the fight, or null.
/mob/living/basic/ambient_npc/planet/proc/engage(mob/living/target)
	if(!can_fight(target))
		return null
	var/datum/ambient_activity/fight/current = activity
	if(istype(current) && current.target() == target)
		return current
	wake_up()
	return start_activity(new /datum/ambient_activity/fight(src, target))

/// Everyone at their camp who fights joins them against `target`
/mob/living/basic/ambient_npc/planet/proc/camp_alert(mob/living/target)
	if(!place)
		return
	for(var/mob/living/basic/ambient_npc/planet/mate in place.living_npcs())
		if(mate == src || !mate.joins_camp_fights || istype(mate.activity, /datum/ambient_activity/fight))
			continue
		mate.engage(target)

/// One blow at `target`, with their weapon's own numbers and one of its verbs
/mob/living/basic/ambient_npc/planet/proc/strike(mob/living/target)
	var/datum/bounty_real_weapon/weapon = bounty_real_weapon(weapon_type)
	weapon.pick_verb(src)
	melee_attack(target, null, TRUE)

/// How far they could throw something right now (their spear), or 0
/mob/living/basic/ambient_npc/planet/proc/throw_reach()
	return 0

/// A try at hitting `target` from where they stand (a thrown spear). TRUE if they did something.
/mob/living/basic/ambient_npc/planet/proc/try_ranged(mob/living/target)
	return FALSE

/// Runs from `threat`
/mob/living/basic/ambient_npc/planet/proc/run_from(atom/threat)
	if(istype(activity, /datum/ambient_activity/flee))
		return activity
	return start_activity(new /datum/ambient_activity/flee(src, threat))

// Fighters fight and their camp joins in; everyone else says something and gets away
/mob/living/basic/ambient_npc/planet/react_attacked(atom/attacker)
	if(stat != CONSCIOUS || fading)
		return
	var/mob/living/foe = isliving(attacker) ? attacker : null
	wake_up()
	if(reaction_ready("attacked", 4 SECONDS))
		speak_context(AMBIENT_LINE_ATTACKED, foe, force = TRUE)
	if(!foe)
		return
	if(!fights_back || (flee_below && health < maxHealth * flee_below))
		run_from(foe)
		return
	engage(foe)
	camp_alert(foe)

// No sheltering from the weather in the middle of a fight
/mob/living/basic/ambient_npc/planet/react_storm(datum/weather/storm)
	if(istype(activity, /datum/ambient_activity/fight) || istype(activity, /datum/ambient_activity/flee))
		return
	return ..()

/**
 * Whether `user`'s crew has had `what` from this site yet; marks it if not. TRUE only the first
 * time for a crew, for as long as the site lasts (the planet's life).
 */
/mob/living/basic/ambient_npc/planet/proc/first_for_crew(mob/user, what)
	var/datum/ambient_place/site/site = place
	if(!istype(site) || !user)
		return FALSE
	var/list/given = site.data[what]
	if(!islist(given))
		given = list()
		site.data[what] = given
	var/key = ambient_crew_key(user)
	if(given[key])
		return FALSE
	given[key] = TRUE
	return TRUE

// =========================================================================
// SHARED ACTIVITIES
// =========================================================================

/**
 * A fight with one person: up to them and blows at the fighter's pace, a throw from range for
 * those who can (throw_reach(), try_ranged()), and back to the routine when they die, stay off the
 * fighter's ground, or get out of reach. `spot` is the target itself, so the walk follows them.
 */
/datum/ambient_activity/fight
	name = "fighting"
	priority = AMBIENT_PRIORITY_REACTION
	/// Who they fight
	var/datum/weakref/target_ref
	/// world.time of the next blow
	var/next_blow = 0
	/// world.time the target was last somewhere the fighter could follow
	var/last_reachable = 0
	/// The walk to the target failed too often: they give up
	var/gave_up = FALSE

/datum/ambient_activity/fight/New(mob/living/basic/ambient_npc/new_doer, atom/target)
	. = ..()
	target_ref = WEAKREF(target)

/// Who they fight, while that is still someone to fight
/datum/ambient_activity/fight/proc/target()
	var/mob/living/target = target_ref?.resolve()
	if(QDELETED(target) || !isliving(target) || target.stat == DEAD)
		return null
	return target

/datum/ambient_activity/fight/setup()
	var/mob/living/basic/ambient_npc/planet/fighter = doer
	var/mob/living/target = target()
	if(!istype(fighter) || !target || !fighter.can_fight(target))
		return FALSE
	fighter.stand_up()
	fighter.set_held(fighter.weapon_type)
	next_blow = world.time + PLANET_NPC_FIRST_BLOW_DELAY
	last_reachable = world.time
	chase(target)
	return TRUE

/// Heads for the target: near enough to throw for someone who can, right beside them otherwise
/datum/ambient_activity/fight/proc/chase(mob/living/target)
	var/mob/living/basic/ambient_npc/planet/fighter = doer
	go_to(target, max(1, fighter.throw_reach()))

/datum/ambient_activity/fight/act(seconds)
	var/mob/living/basic/ambient_npc/planet/fighter = doer
	var/mob/living/target = target()
	if(gave_up || !target || !fighter.can_fight(target))
		return AMBIENT_STEP_DONE
	if(fighter.flee_below && fighter.health < fighter.maxHealth * fighter.flee_below)
		// This replaces the fight: nothing here may touch it after
		fighter.run_from(target)
		return AMBIENT_STEP_CONTINUE
	if(fighter.leash_ok(get_turf(target)))
		last_reachable = world.time
	else if(world.time - last_reachable > PLANET_NPC_GIVE_UP_TIME)
		return AMBIENT_STEP_DONE
	if(get_dist(fighter, target) <= 1 && fighter.Adjacent(target))
		fighter.face_atom(target)
		if(world.time >= next_blow)
			next_blow = world.time + fighter.blow_interval
			fighter.strike(target)
		return AMBIENT_STEP_CONTINUE
	if(fighter.try_ranged(target))
		return AMBIENT_STEP_CONTINUE
	chase(target)
	// In throwing range with nothing to throw: walk right up
	if(at_spot())
		go_to(target, 1)
	return AMBIENT_STEP_MOVE

/datum/ambient_activity/fight/spot_unreachable()
	gave_up = TRUE
	spot = null
	arrived = FALSE

/datum/ambient_activity/fight/finish()
	var/mob/living/basic/ambient_npc/planet/fighter = doer
	. = ..()
	if(istype(fighter) && !QDELETED(fighter))
		fighter.show_idle_held()

/// Running from something: well away from it, a breather, and away again if it follows
/datum/ambient_activity/flee
	name = "running"
	priority = AMBIENT_PRIORITY_REACTION
	duration_low = 20 SECONDS
	duration_high = 30 SECONDS
	/// What they run from
	var/datum/weakref/threat_ref

/datum/ambient_activity/flee/New(mob/living/basic/ambient_npc/new_doer, atom/threat)
	. = ..()
	threat_ref = WEAKREF(threat)

/datum/ambient_activity/flee/setup()
	if(!pick_refuge())
		return FALSE
	set_duration()
	doer.stand_up()
	doer.speak_context("flee", threat_ref?.resolve(), force = TRUE)
	return TRUE

/// Sends them somewhere away from the threat they could get to. FALSE when there is nowhere.
/datum/ambient_activity/flee/proc/pick_refuge()
	var/atom/threat = threat_ref?.resolve()
	var/turf/here = get_turf(doer)
	if(!here)
		return FALSE
	var/away = threat ? get_dir(threat, doer) : 0
	if(!away)
		away = pick(GLOB.alldirs)
	for(var/attempt in 1 to 6)
		var/heading = attempt <= 3 ? away : pick(GLOB.alldirs)
		var/turf/far = get_ranged_target_turf(here, heading, PLANET_NPC_FLEE_DISTANCE)
		var/turf/refuge = doer.random_tile_near(far, 2, failed_spots) || (doer.standable(far, failed_spots) ? far : null)
		if(refuge && (!threat || get_dist(refuge, threat) > get_dist(here, threat)))
			go_to(refuge)
			return TRUE
	return FALSE

/datum/ambient_activity/flee/act(seconds)
	var/atom/threat = threat_ref?.resolve()
	if(threat && get_dist(doer, threat) <= 3 && pick_refuge())
		return AMBIENT_STEP_MOVE
	if(prob(20))
		doer.setDir(pick(GLOB.cardinals))
	return AMBIENT_STEP_CONTINUE

/**
 * Keeping near someone (a caravan's leader, a hunting partner) until they are gone or it ends.
 * `keep` is how near; `duration` 0 follows for as long as the leader is there.
 */
/datum/ambient_activity/follow
	name = "following"
	accepts_company = TRUE
	/// How near they keep
	var/keep = 2

/datum/ambient_activity/follow/New(mob/living/basic/ambient_npc/new_doer, atom/leader, keep = 2, duration = 0)
	. = ..()
	src.keep = keep
	if(duration)
		ends_at = world.time + duration

/// Who they follow, while they are still there
/datum/ambient_activity/follow/proc/leader()
	var/mob/living/leader = anchor()
	if(!isliving(leader) || leader.stat == DEAD)
		return null
	var/mob/living/basic/ambient_npc/npc_leader = leader
	if(istype(npc_leader) && npc_leader.fading)
		return null
	return leader

/datum/ambient_activity/follow/setup()
	var/mob/living/leader = leader()
	if(!leader || leader == doer)
		return FALSE
	next_line = world.time + rand(20 SECONDS, 40 SECONDS)
	go_to(leader, keep)
	return TRUE

/datum/ambient_activity/follow/act(seconds)
	var/mob/living/leader = leader()
	if(!leader)
		return AMBIENT_STEP_DONE
	if(get_dist(doer, leader) > keep)
		go_to(leader, keep)
		return AMBIENT_STEP_MOVE
	if(prob(10))
		doer.face_atom(leader)
	chatter(low = 40 SECONDS, high = 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

// A leader who walked off where they cannot follow: they stop following
/datum/ambient_activity/follow/spot_unreachable()
	. = ..()
	ends_at = world.time

/**
 * A chore at the camp: at one of the site's props (or the anchor, or where they stand), with
 * something in hand, now and then an in-world emote and a sound, seated or crouched if the chore
 * wants it. Subtypes only set vars; do_chore() is there for more.
 */
/datum/ambient_activity/camp_chore
	name = "keeping camp"
	accepts_company = TRUE
	duration_low = 40 SECONDS
	duration_high = 90 SECONDS
	/// The site prop it happens at (site.get_prop()), when there is no anchor
	var/prop_type
	/// How near the prop they stand
	var/stand_distance = 1
	/// Sits on a seat near the prop instead
	var/sits = FALSE
	/// Crouches while doing it
	var/crouches = FALSE
	/// What they hold meanwhile (an item typepath), or null
	var/held_look
	/// What it looks like, now and then: "turns the spit." is shown as "[name] turns the spit."
	var/list/emotes
	var/emote_low = 8 SECONDS
	var/emote_high = 18 SECONDS
	/// A sound with each emote, or null
	var/list/sounds
	var/sound_volume = 30
	/// A swing at the prop with each emote (carving, a spear at a post)
	var/swings = FALSE
	/// Their chatter while at it
	var/line_context = AMBIENT_LINE_IDLE
	/// world.time of the next emote
	var/next_emote = 0
	var/datum/weakref/prop_ref
	var/datum/weakref/seat_ref

/// The prop it happens at, if it is still there
/datum/ambient_activity/camp_chore/proc/prop()
	var/atom/prop = prop_ref?.resolve()
	return QDELETED(prop) ? null : prop

/datum/ambient_activity/camp_chore/setup()
	var/atom/prop = anchor()
	if(!prop && prop_type)
		var/datum/ambient_place/site/site = doer.place
		prop = istype(site) ? site.get_prop(prop_type) : null
		if(!prop)
			return FALSE
	prop_ref = prop ? WEAKREF(prop) : null
	if(sits)
		var/obj/structure/chair/seat = doer.find_seat(prop || doer, 3, FALSE, failed_spots)
		if(seat)
			seat_ref = WEAKREF(seat)
			go_to(get_turf(seat))
	if(!seat_ref)
		if(prop && get_dist(doer, prop) > stand_distance)
			var/turf/stand = doer.free_tile_beside(prop, stand_distance, failed_spots)
			if(!stand)
				return FALSE
			go_to(stand)
		else
			go_to(null)
	set_duration()
	next_emote = world.time + rand(2 SECONDS, 6 SECONDS)
	next_line = world.time + rand(15 SECONDS, 40 SECONDS)
	return TRUE

/datum/ambient_activity/camp_chore/arrive()
	var/obj/structure/chair/seat = seat_ref?.resolve()
	if(seat && !doer.sit_on(seat))
		seat_ref = null
	var/atom/prop = prop()
	if(prop && !doer.buckled && get_turf(prop) != get_turf(doer))
		doer.face_atom(prop)
	if(held_look)
		doer.set_held(held_look)
	if(crouches && !doer.buckled)
		doer.crouch()

/datum/ambient_activity/camp_chore/act(seconds)
	if(world.time >= next_emote)
		next_emote = world.time + rand(emote_low, emote_high)
		do_chore()
	chatter(line_context)
	return AMBIENT_STEP_CONTINUE

/// One beat of the chore: a swing, a sound, an emote. Override for more.
/datum/ambient_activity/camp_chore/proc/do_chore()
	var/atom/prop = prop()
	if(swings && prop && doer.Adjacent(prop))
		doer.do_attack_animation(prop)
	if(length(sounds))
		playsound(doer, pick(sounds), sound_volume, TRUE, -3)
	if(length(emotes))
		doer.manual_emote(pick(emotes))

/datum/ambient_activity/camp_chore/spot_unreachable()
	. = ..()
	seat_ref = null

/datum/ambient_activity/camp_chore/finish()
	. = ..()
	if(QDELETED(doer))
		return
	var/mob/living/basic/ambient_npc/planet/planet_npc = doer
	if(istype(planet_npc))
		planet_npc.show_idle_held()
	else if(held_look)
		doer.set_held(null)

/**
 * A nap: they lie down (on the mat they are anchored to, or where they stand) and see nothing
 * until it ends or something wakes them (a fight at their camp, being hit).
 */
/datum/ambient_activity/nap
	name = "sleeping"
	duration_low = 2 MINUTES
	duration_high = 4 MINUTES

/datum/ambient_activity/nap/setup()
	var/atom/mat = anchor() || free_mat()
	if(mat)
		anchor_ref = WEAKREF(mat)
	if(mat && get_turf(mat) != get_turf(doer))
		var/turf/bed = get_turf(mat)
		if(!doer.standable(bed, failed_spots))
			return FALSE
		go_to(bed)
	set_duration()
	return TRUE

/// The nearest of their site's sleeping mats with nobody on it, or null
/datum/ambient_activity/nap/proc/free_mat()
	var/datum/ambient_place/site/site = doer.place
	if(!istype(site))
		return null
	var/obj/effect/ambient_camp_prop/mat/best
	var/best_distance = INFINITY
	for(var/datum/weakref/ref as anything in site.props)
		var/obj/effect/ambient_camp_prop/mat/mat = ref?.resolve()
		if(!istype(mat) || QDELETED(mat) || (locate(/mob/living) in get_turf(mat)))
			continue
		var/distance = get_dist(doer, mat)
		if(distance < best_distance)
			best = mat
			best_distance = distance
	return best

/datum/ambient_activity/nap/arrive()
	var/mob/living/basic/ambient_npc/planet/sleeper = doer
	doer.set_held(null)
	doer.manual_emote("lies down.")
	animate(doer, transform = matrix().Turn(90), time = 0.5 SECONDS)
	if(istype(sleeper))
		sleeper.sleeping = TRUE

/datum/ambient_activity/nap/act(seconds)
	if(prob(4))
		doer.manual_emote(pick("snores.", "turns over."))
	return AMBIENT_STEP_CONTINUE

/datum/ambient_activity/nap/finish()
	var/mob/living/basic/ambient_npc/planet/sleeper = doer
	if(istype(sleeper) && !QDELETED(sleeper))
		sleeper.sleeping = FALSE
		if(sleeper.stat != DEAD)
			animate(sleeper, transform = matrix(), time = 0.5 SECONDS)
	return ..()

// =========================================================================
// CAMP SCENERY
// =========================================================================

/**
 * Camp gear that is only scenery: nobody can pick it up, break it or take it apart, so a camp that
 * is put back every visit never turns into free loot.
 */
/obj/effect/ambient_camp_prop
	name = "camp gear"
	desc = "Someone's things, left out."
	anchored = TRUE
	density = FALSE
	layer = BELOW_OBJ_LAYER

/obj/effect/ambient_camp_prop/lamp
	name = "camp lantern"
	desc = "A battered lantern, turned low."
	icon = 'icons/obj/lighting.dmi'
	icon_state = "lantern-on"
	layer = OBJ_LAYER
	light_range = 4
	light_power = 1.2
	light_color = "#ffcc66"

/obj/effect/ambient_camp_prop/rug
	name = "rug"
	desc = "A threadbare rug spread over the dirt."
	icon = 'icons/obj/bedsheets.dmi'
	icon_state = "sheetbrown"
	layer = LOW_OBJ_LAYER

/obj/effect/ambient_camp_prop/mat
	name = "sleeping mat"
	desc = "Woven grass, flattened by someone's weight."
	icon = 'icons/obj/bedsheets.dmi'
	icon_state = "sheetbrown"
	layer = LOW_OBJ_LAYER
	color = "#b8a070"

/obj/effect/ambient_camp_prop/spear_rack
	name = "spear rack"
	desc = "Bamboo spears leaned against a crossbar, points up."
	icon = 'icons/obj/weapons/spear.dmi'
	icon_state = "bamboo_spear0"
	layer = OBJ_LAYER

/obj/effect/ambient_camp_prop/spear_rack/Initialize(mapload)
	. = ..()
	var/mutable_appearance/second = mutable_appearance(icon, icon_state)
	second.pixel_w = 6
	add_overlay(second)

/obj/effect/ambient_camp_prop/post
	name = "practice post"
	desc = "A bamboo pole driven into the ground, gouged all over."
	icon = 'icons/obj/structures.dmi'
	icon_state = "headpike-bamboo"
	layer = OBJ_LAYER

#undef PLANET_NPC_FIRST_BLOW_DELAY
#undef PLANET_NPC_CHASE_RANGE
#undef PLANET_NPC_GIVE_UP_TIME
#undef PLANET_NPC_FLEE_DISTANCE
