/**
 * # Outpost floors: breaching, and the walk-through
 *
 * Owner: P6 (spec 6.3, 6.5, 13). Lives here, after stealth_police, so it may fill the officers' planning subtrees
 * the brain lists (stealth_police/police_stealth.dm).
 *
 * ## Breaching (spec 6.5, L11, A15, A45)
 * During a warrant on a floor every door admits an officer (police_floors.dm) and anything else in the way is
 * breached: a real, telegraphed explosion. A blast works on every floor because a floor is never blast-protected
 * trader ground (trade/outpost_security.dm, is_trader_outpost_protected()), and it never leaves the floor
 * (outpost_floor_blast_excludes()).
 * - The route: breach_field() is one cheapest-cost search from the suspect's tile over the floor's rectangle. An
 *   open tile costs 1, a breakable blocked one POLICE_BREACH_BLOCKED_COST, the hull and outpost property are solid.
 *   A tile is judged on its first BREACH_ATOMS_PER_TILE atoms; more than that and it counts as blocked (A45). The
 *   squad shares one field a floor, made at most once every POLICE_BREACH_STALL.
 * - The subtree (outpost_police_breach, planned before stealth's reactions so a searching officer breaches too): an
 *   officer whose cheapest way to its 3+ star quarry on the floor crosses a blocked tile for POLICE_BREACH_STALL walks
 *   beside the first such tile, calls it, takes POLICE_BREACH_PLANT_TIME to set a charge (plant_breach()), and
 *   everyone of the squad within POLICE_BREACH_STANDOFF backs off that far. One charge at a time on a floor,
 *   POLICE_BREACH_GAP apart. With no route and nothing to breach for POLICE_BREACH_GIVE_UP the officer holds the
 *   reachable tile nearest the suspect (A15). Stars at three and up never fade while the suspect is at the outpost
 *   (police_wanted.dm tick_warrant()), so the hold costs the suspect nothing but time.
 * - The charge is a fixture, never an item. It beeps and blinks for POLICE_BREACH_FUSE, then goes off as a real
 *   explosion centred on its tile (devastation 1, heavy 0, light 2, no fire). Nobody armed it, so its blast is no
 *   crime against the officers (outpost_bomber_of()).
 *
 * ## The walk-through (spec 6.3, owner decision 8)
 * Now and then a beat officer with nothing to do rides the police lift up to an Open floor that has visitors,
 * walks a loop (the landing, the shop, the floor), and rides back to its beat. One officer of an outpost at a time,
 * only with another beat officer left and nobody wanted at the outpost. Nobody is made for it: the officer is one
 * already walking its beat. The floor narrowing (or losing its ground, or a warrant) sends it home at once.
 * Anything the police or stealth set it on comes first; the walk waits and carries on after. The police tick offers
 * the walk (stealth_tick_officer()); the brain walks it (outpost_police_floor_walk).
 *
 * Officer lines: "floor_warrant", "floor_breach" and "floor_walk" in AMBIENT_STRINGS_POLICE.
 * Private state is prefixed breach_.
 */

/// Atoms looked at on one tile before it counts as blocked (abuse A45)
#define BREACH_ATOMS_PER_TILE 20
/// What breach_read() finds: a clear way, a blocked tile on it, or no way at all
#define BREACH_ROUTE_OPEN "open"
#define BREACH_ROUTE_BLOCKED "blocked"
#define BREACH_ROUTE_SEALED "sealed"
/// Stealth walk purposes of this file (stealth_walk_failed() counts neither against a patrol stop)
#define BREACH_GOTO_BREACH "floor_breach"
#define BREACH_GOTO_WALK "floor_walk"
/// An officer told to set a charge gives up the job after this long
#define BREACH_PLANT_GIVE_UP (20 SECONDS)
/// "Security! Warrant!" once a floor this often
#define BREACH_CALL_GAP (2 MINUTES)
/// Officer line contexts (outpost_police.json)
#define POLICE_LINE_FLOOR_WARRANT "floor_warrant"
#define POLICE_LINE_FLOOR_BREACH "floor_breach"
#define POLICE_LINE_FLOOR_WALK "floor_walk"
/// The walk's stages
#define BREACH_WALK_UP "up"
#define BREACH_WALK_LOOP "loop"
#define BREACH_WALK_DOWN "down"
/// The first walk on a floor that has just opened comes this soon at the earliest
#define BREACH_WALK_FIRST (2 MINUTES)
/// The ride up is given up after this long
#define BREACH_WALK_UP_MAX (90 SECONDS)
/// How often the police look for a floor to walk through
#define BREACH_WALK_LOOK_GAP (10 SECONDS)
/// The least and most an officer stands at one stop of the walk
#define BREACH_WALK_STOP_MIN (8 SECONDS)
#define BREACH_WALK_STOP_MAX (30 SECONDS)
/// Tiles from the landing a walk's far stop is at the least
#define BREACH_WALK_FAR 6

// =========================================================================
// STATE
// =========================================================================

/datum/outpost_floor
	/// The charge set on this floor now, or null (one at a time)
	var/obj/structure/outpost_breach_charge/breach_charge
	/// world.time the next charge may be set here (POLICE_BREACH_GAP)
	var/breach_next_at = 0
	/// Weakref to the officer setting a charge here now, and since when
	var/datum/weakref/breach_planter
	var/breach_planter_since = 0
	/// world.time an officer last called the warrant here
	var/breach_called_at = 0
	/// The squad's shared route search (breach_field()), and when it was made
	var/list/breach_field_cache
	var/breach_field_at = 0
	/// Atoms looked at by the last search (A45; read by the tests)
	var/breach_atoms_looked = 0
	/// world.time the police next walk through this floor while it is Open, or 0 when no walk is due
	var/breach_walk_due_at = 0

/datum/outpost_police
	/// world.time the police may next look for a floor to walk through
	var/breach_walk_look_at = 0
	/// Weakref to the officer walking a floor now
	var/datum/weakref/breach_walker

/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police
	/// world.time its way to its quarry first showed blocked or gone, or 0
	var/breach_stuck_since = 0
	/// The tile it is to blow, the open tile beside it to set the charge from, and since when
	var/turf/breach_target_turf
	var/turf/breach_plant_spot
	var/breach_plant_since = 0
	/// Mid-way through setting a charge
	var/breach_planting = FALSE
	/// Where it backs off to from a live charge, and until when
	var/turf/breach_back_turf
	var/breach_back_until = 0
	/// The tile it holds when nothing can be breached (A15)
	var/turf/breach_hold_turf
	/// It changed its movement to pathfinding for a breach job while alert
	var/breach_paths = FALSE
	/// The walk-through: its floor (weakref), its stage, where it set out from, its stops
	var/datum/weakref/breach_walk_ref
	var/breach_walk_stage
	var/turf/breach_walk_from
	var/list/turf/breach_walk_stops
	var/breach_walk_index = 1
	/// world.time its wait at the current stop ends, or 0 while it walks there
	var/breach_walk_wait_until = 0
	/// world.time the loop on the floor ends, and when the current stage began
	var/breach_walk_until = 0
	var/breach_walk_stage_at = 0
	/// It has spoken to a visitor this walk
	var/breach_walk_spoke = FALSE

// =========================================================================
// THE ROUTE (pure)
// =========================================================================

/// Whether `door`, closed, opens for an officer under warrant: not welded, bolted, sealed or dead. Shutters and fire doors never do.
/proc/outpost_breach_door_opens(obj/machinery/door/door)
	if(door.welded)
		return FALSE
	if(istype(door, /obj/machinery/door/airlock))
		var/obj/machinery/door/airlock/airlock = door
		return !airlock.locked && !airlock.seal && airlock.hasPower()
	if(istype(door, /obj/machinery/door/window))
		return door.hasPower()
	return FALSE

/**
 * What it costs to go through `tile` on this floor: 1 when it is open, POLICE_BREACH_BLOCKED_COST when something
 * breakable is in the way, 0 when nothing gets through (the hull, outpost property, anything indestructible, off the
 * floor). With `doors_open`, a closed door that opens for an officer is open; without, every closed door blocks.
 * Mobs never block. Only the first BREACH_ATOMS_PER_TILE atoms are looked at; past that the tile is blocked (A45).
 */
/datum/outpost_floor/proc/breach_tile_cost(turf/tile, doors_open = TRUE)
	if(!contains_turf(tile))
		return 0
	if(istype(tile, /turf/closed/wall/outpost_floor_hull) || istype(tile, /turf/closed/indestructible) || (tile.resistance_flags & INDESTRUCTIBLE))
		return 0
	if(isclosedturf(tile))
		return POLICE_BREACH_BLOCKED_COST
	var/blocked = FALSE
	var/looked = 0
	for(var/atom/movable/thing as anything in tile)
		if(looked >= BREACH_ATOMS_PER_TILE)
			breach_atoms_looked += looked
			return POLICE_BREACH_BLOCKED_COST
		looked++
		if(ismob(thing) || !thing.density)
			continue
		if(HAS_TRAIT(thing, TRAIT_OUTPOST_PROPERTY) || (thing.resistance_flags & INDESTRUCTIBLE))
			breach_atoms_looked += looked
			return 0
		if(doors_open && istype(thing, /obj/machinery/door) && outpost_breach_door_opens(thing))
			continue
		blocked = TRUE
	breach_atoms_looked += looked
	return blocked ? POLICE_BREACH_BLOCKED_COST : 1

/**
 * The cheapest way from every tile of this floor to `goal`: list("goal", "dist" (turf to cost), "next" (turf to the
 * next turf toward the goal), "costs" (turf to breach_tile_cost())). A tile missing from "dist" has no way there.
 * The goal itself counts as open: the quarry stands on it. One search over the floor's rectangle.
 */
/datum/outpost_floor/proc/breach_field(turf/goal, doors_open = TRUE)
	var/list/dist = list()
	var/list/next = list()
	var/list/costs = list()
	goal = get_turf(goal)
	. = list("goal" = goal, "dist" = dist, "next" = next, "costs" = costs)
	breach_atoms_looked = 0
	if(!contains_turf(goal))
		return
	// Dial's search: every step costs 1 or POLICE_BREACH_BLOCKED_COST, so a ring of buckets keeps it in order
	var/ring = POLICE_BREACH_BLOCKED_COST + 1
	var/list/buckets = list()
	for(var/i in 1 to ring)
		buckets += list(list())
	dist[goal] = 0
	costs[goal] = 1
	var/list/first = buckets[1]
	first += goal
	var/pending = 1
	var/at = 0
	var/last = (bounds[3] - bounds[1] + 1) * (bounds[4] - bounds[2] + 1) * POLICE_BREACH_BLOCKED_COST
	while(pending > 0 && at <= last)
		var/list/bucket = buckets[(at % ring) + 1]
		while(length(bucket))
			var/turf/here = bucket[length(bucket)]
			bucket.len--
			pending--
			if(dist[here] != at)
				continue
			// Going on from here means going through here: the cost of this tile
			var/through = at + costs[here]
			for(var/direction in GLOB.cardinals)
				var/turf/near = get_step(here, direction)
				if(!near || !contains_turf(near))
					continue
				var/near_cost = costs[near]
				if(isnull(near_cost))
					near_cost = breach_tile_cost(near, doors_open)
					costs[near] = near_cost
				if(!near_cost)
					continue
				var/known = dist[near]
				if(!isnull(known) && known <= through)
					continue
				dist[near] = through
				next[near] = here
				var/list/into = buckets[(through % ring) + 1]
				into += near
				pending++
		at++

/// Reads `field` from `start`: list(BREACH_ROUTE_*, the first blocked tile on the way or null, the tile before it or null)
/datum/outpost_floor/proc/breach_read(list/field, turf/start)
	start = get_turf(start)
	var/list/dist = field?["dist"]
	if(!start || isnull(dist?[start]))
		return list(BREACH_ROUTE_SEALED, null, null)
	var/list/next = field["next"]
	var/list/costs = field["costs"]
	var/turf/goal = field["goal"]
	var/turf/before = start
	var/turf/step = next[start]
	var/steps = 0
	while(step && step != goal && steps++ < length(dist))
		if(costs[step] == POLICE_BREACH_BLOCKED_COST)
			return list(BREACH_ROUTE_BLOCKED, step, before)
		before = step
		step = next[step]
	return list(BREACH_ROUTE_OPEN, null, null)

/**
 * The first blocked tile on the cheapest way from `start` to `goal` over this floor, or null when there is none:
 * a clear way, or none at all (a sealed pocket). Pure: it searches again on every call.
 */
/datum/outpost_floor/proc/breach_target(turf/start, turf/goal)
	var/list/read = breach_read(breach_field(goal), start)
	return read[2]

/// The squad's view of the way from `start` to `goal`: breach_read() on the floor's shared field, made again at most once every POLICE_BREACH_STALL (A45)
/datum/outpost_floor/proc/breach_route(turf/start, turf/goal)
	goal = get_turf(goal)
	if(isnull(breach_field_cache) || (world.time >= breach_field_at + POLICE_BREACH_STALL && breach_field_cache["goal"] != goal) || world.time >= breach_field_at + POLICE_BREACH_STALL * 2)
		breach_field_cache = breach_field(goal)
		breach_field_at = world.time
	return breach_read(breach_field_cache, start)

/**
 * The open tiles `start` reaches on this floor, nearest first, `start` included. `doors_open` as breach_tile_cost().
 * `avoid` is never entered. At most `limit` tiles.
 */
/datum/outpost_floor/proc/breach_reach(turf/start, doors_open = TRUE, turf/avoid, limit = 2000)
	var/list/turf/reached = list()
	start = get_turf(start)
	if(!contains_turf(start))
		return reached
	var/list/seen = list()
	seen[start] = TRUE
	reached += start
	var/index = 1
	while(index <= length(reached) && length(reached) < limit)
		var/turf/here = reached[index]
		index++
		for(var/direction in GLOB.cardinals)
			var/turf/near = get_step(here, direction)
			if(!near || seen[near] || near == avoid)
				continue
			seen[near] = TRUE
			if(breach_tile_cost(near, doors_open) == 1)
				reached += near
	return reached

/// The tile `start` can reach that is nearest `goal`: where the squad holds when nothing can be breached (A15)
/datum/outpost_floor/proc/breach_hold_point(turf/start, turf/goal)
	var/turf/best
	var/best_distance = INFINITY
	for(var/turf/tile as anything in breach_reach(start))
		var/distance = get_dist(tile, goal)
		if(distance < best_distance)
			best = tile
			best_distance = distance
	return best

/// The nearest tile `start` can reach that is POLICE_BREACH_STANDOFF or more from `charge_turf`, or null
/datum/outpost_floor/proc/breach_back_off_point(turf/start, turf/charge_turf)
	for(var/turf/tile as anything in breach_reach(start, TRUE, charge_turf, 400))
		if(get_dist(tile, charge_turf) >= POLICE_BREACH_STANDOFF)
			return tile
	return null

// =========================================================================
// THE CHARGE
// =========================================================================

/**
 * `officer` sets a charge on `target`, beside it: only on a floor of this outpost under warrant, on a tile that is
 * blocked and breakable, with no other charge live there and POLICE_BREACH_GAP since the last. The squad near it
 * backs off. TRUE if the charge is set. Never sleeps (the two seconds of setting it are the officer's do_after).
 */
/datum/outpost_police/proc/plant_breach(mob/living/officer, turf/target)
	target = get_turf(target)
	var/turf/here = get_turf(officer)
	if(QDELETED(src) || !outpost || !target || !here || QDELETED(officer) || officer.stat != CONSCIOUS)
		return FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/police_officer = officer
	if(!istype(police_officer) || police_officer.police != src)
		return FALSE
	var/datum/outpost_floor/floor = outpost.floor_at(target)
	if(!floor?.warrant_in_force || !floor.contains_turf(here) || here.z != target.z || get_dist(here, target) > 1)
		return FALSE
	if(!QDELETED(floor.breach_charge) || world.time < floor.breach_next_at)
		return FALSE
	if(floor.breach_tile_cost(target) != POLICE_BREACH_BLOCKED_COST)
		return FALSE
	var/obj/structure/outpost_breach_charge/charge = new(target, floor)
	floor.breach_charge = charge
	floor.breach_next_at = world.time + POLICE_BREACH_GAP
	floor.breach_planter = null
	breach_scatter(floor, target)
	log_game("OUTPOST POLICE: [key_name(officer)] set a breaching charge on floor [floor.number] of [outpost] at [AREACOORD(target)].")
	return TRUE

/// Everyone of the squad on `floor` within POLICE_BREACH_STANDOFF of `target` backs off that far until the charge is gone
/datum/outpost_police/proc/breach_scatter(datum/outpost_floor/floor, turf/target)
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer in officers)
		if(officer.stat != CONSCIOUS || officer.client || get_dist(officer, target) >= POLICE_BREACH_STANDOFF || !floor.contains_turf(get_turf(officer)))
			continue
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
		if(!istype(brain))
			continue
		var/turf/back = floor.breach_back_off_point(get_turf(officer), target)
		if(!back)
			continue
		brain.breach_back_turf = back
		brain.breach_back_until = world.time + POLICE_BREACH_FUSE + 1 SECONDS

/// The officer says the line and takes POLICE_BREACH_PLANT_TIME over the charge; it is set if nothing stopped them. Sleeps.
/datum/outpost_police/proc/breach_set_charge(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, turf/target)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || brain.breach_planting)
		return
	brain.breach_planting = TRUE
	officer.face_atom(target)
	officer.police_say(POLICE_LINE_FLOOR_BREACH)
	var/done = do_after(officer, POLICE_BREACH_PLANT_TIME, target)
	if(QDELETED(brain))
		return
	brain.breach_planting = FALSE
	if(done && !QDELETED(src))
		plant_breach(officer, target)
	brain.breach_drop_job()

/**
 * The charge an officer sets: a fixture, never an item. Never saved on a ship (GLOB.outpost_checkpoint_excluded).
 * It beeps and blinks for POLICE_BREACH_FUSE, then goes off as a real explosion centred on its tile.
 */
/obj/structure/outpost_breach_charge
	name = "breaching charge"
	desc = "A shaped charge stuck fast, its light blinking."
	icon = 'icons/obj/weapons/grenade.dmi'
	icon_state = "plastic-explosive0_active"
	anchored = TRUE
	density = FALSE
	layer = ABOVE_OBJ_LAYER
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The floor it is on
	var/datum/weakref/floor_ref
	/// Its blinking ring over the tiles the blast reaches
	var/obj/effect/temp_visual/bounty_boss_mark/ring

/obj/structure/outpost_breach_charge/Initialize(mapload, datum/outpost_floor/floor)
	. = ..()
	floor_ref = floor ? WEAKREF(floor) : null
	ring = new(get_turf(src), POLICE_BREACH_FUSE, COLOR_RED, "target_circle")
	// The blast's light ring reaches one tile round its centre
	ring.transform = matrix() * 3
	ring.blink()
	visible_message(span_danger("[src] starts beeping!"))
	playsound(src, 'sound/machines/beep/beep.ogg', 60, TRUE)
	addtimer(CALLBACK(src, PROC_REF(beep)), 0.5 SECONDS, TIMER_LOOP | TIMER_DELETE_ME)
	addtimer(CALLBACK(src, PROC_REF(detonate)), POLICE_BREACH_FUSE, TIMER_DELETE_ME)

/obj/structure/outpost_breach_charge/Destroy()
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	if(floor?.breach_charge == src)
		floor.breach_charge = null
	floor_ref = null
	if(!QDELETED(ring))
		qdel(ring)
	ring = null
	return ..()

/obj/structure/outpost_breach_charge/proc/beep()
	playsound(src, 'sound/machines/beep/beep.ogg', 60, TRUE)

/// Goes off: devastation 1, heavy 0, light 2, no fire, on its own tile. Its floor searches its routes afresh.
/obj/structure/outpost_breach_charge/proc/detonate()
	var/turf/here = get_turf(src)
	var/datum/outpost_floor/floor = floor_ref?.resolve()
	if(floor)
		if(floor.breach_charge == src)
			floor.breach_charge = null
		floor.breach_field_at = 0
		floor.breach_field_cache = null
	if(here)
		explosion(here, devastation_range = 1, heavy_impact_range = 0, light_impact_range = 2, flame_range = 0, adminlog = FALSE, explosion_cause = src)
	qdel(src)

// =========================================================================
// THE SQUAD
// =========================================================================

/// The floor of this outpost `officer` stands on while a warrant is in force there, or null
/datum/outpost_police/proc/breach_floor_of(mob/living/officer)
	var/datum/outpost_floor/floor = outpost?.floor_at(get_turf(officer))
	return floor?.warrant_in_force ? floor : null

/// Who `officer` is after on `floor`: its target, the mind it hunts or the one it was sent for, alive there, free, at three stars or more
/datum/outpost_police/proc/breach_quarry(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer, datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain, datum/outpost_floor/floor)
	var/list/datum/mind/minds = list()
	var/atom/target = brain.blackboard[BB_BASIC_MOB_CURRENT_TARGET]
	var/mob/living/target_mob = ismecha(target) ? bounty_ai_pilot_of(target) : target
	if(isliving(target_mob) && target_mob.mind)
		minds += target_mob.mind
	var/datum/mind/hunted = brain.police_hunt?.resolve()
	if(hunted)
		minds |= hunted
	var/datum/mind/sent_for = officer.dispatch_mind?.resolve()
	if(sent_for)
		minds |= sent_for
	for(var/datum/mind/mind as anything in minds)
		var/mob/living/body = mind.current
		if(!isliving(body) || body.stat == DEAD || !floor.contains_turf(get_turf(body)) || in_custody(body))
			continue
		if(get_stars(mind) >= POLICE_FLOOR_WARRANT_STARS)
			return body
	return null

/// The first officer of the squad on a floor under warrant calls it, once a floor every BREACH_CALL_GAP
/datum/outpost_police/proc/breach_call_warrant(datum/outpost_floor/floor, mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(floor.breach_called_at && world.time < floor.breach_called_at + BREACH_CALL_GAP)
		return
	floor.breach_called_at = world.time
	INVOKE_ASYNC(officer, TYPE_PROC_REF(/mob/living/carbon/human/npc/ambient_npc/outpost/police, police_say), POLICE_LINE_FLOOR_WARRANT)

/// `officer` takes the job of breaching on `floor`: nobody else is on one, no charge is live, the gap is past
/datum/outpost_police/proc/breach_claim(datum/outpost_floor/floor, mob/living/officer)
	if(!QDELETED(floor.breach_charge) || world.time < floor.breach_next_at)
		return FALSE
	var/mob/living/planter = floor.breach_planter?.resolve()
	if(planter && planter != officer && planter.stat == CONSCIOUS && world.time < floor.breach_planter_since + BREACH_PLANT_GIVE_UP && floor.contains_turf(get_turf(planter)))
		return FALSE
	floor.breach_planter = WEAKREF(officer)
	floor.breach_planter_since = world.time
	return TRUE

/// Plans a breach when an officer has had no way to a suspect on a floor under warrant (spec 6.5). Plans nothing anywhere else.
/datum/ai_planning_subtree/outpost_police_breach

/datum/ai_planning_subtree/outpost_police_breach/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(controller) || !istype(officer))
		return
	if(officer.stat != CONSCIOUS || officer.client || !officer.police || officer.case)
		controller.breach_reset()
		return
	var/datum/outpost_floor/floor = officer.police.breach_floor_of(officer)
	if(!floor)
		controller.breach_reset()
		return
	return controller.breach_plan(floor)

/// Drops every breach job it has, and gives back stealth's movement if it took it
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_reset()
	if(breach_target_turf || breach_back_turf || breach_hold_turf)
		stealth_drop_walk()
	breach_stuck_since = 0
	breach_target_turf = null
	breach_plant_spot = null
	breach_back_turf = null
	breach_back_until = 0
	breach_hold_turf = null
	breach_give_back_paths()

/// The charge job is over, set or not
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_drop_job()
	breach_target_turf = null
	breach_plant_spot = null
	breach_plant_since = 0
	breach_stuck_since = 0

/// Walks where a breach job needs it with pathfinding, even when alert
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_to(turf/dest)
	if(!breach_paths && stealth_state() == STEALTH_ALERT)
		breach_paths = TRUE
		human_npc_set_ai_movement(src, /datum/ai_movement/jps/stealth)
	stealth_walk(dest, BREACH_GOTO_BREACH)

/// Gives stealth's alert movement back once no breach job needs pathfinding
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_give_back_paths()
	if(!breach_paths)
		return
	breach_paths = FALSE
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(stealth_state() == STEALTH_ALERT && !(istype(officer) && officer.case))
		human_npc_set_ai_movement(src, /datum/ai_movement/basic_avoidance/stealth)

/// Stands where it is, facing `toward`
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_stand(atom/toward)
	var/mob/living/officer = pawn
	if(toward && get_turf(toward) != get_turf(officer))
		stand_dir = stealth_dir_to(officer, toward)
		officer.setDir(stand_dir)
	queue_behavior(/datum/ai_behavior/stealth_stand)
	return SUBTREE_RETURN_FINISH_PLANNING

/**
 * One plan on `floor`, under warrant: back off from a live charge, set the one it was given, or look at the way to
 * its quarry. A clear way leaves it to the fighting subtrees; a blocked one for POLICE_BREACH_STALL gives it a charge
 * to set; none for POLICE_BREACH_GIVE_UP makes it hold the nearest point (A15).
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_plan(datum/outpost_floor/floor)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/datum/outpost_police/police = officer.police
	var/turf/here = get_turf(officer)
	// Back off from a live charge
	if(breach_back_turf)
		if(world.time < breach_back_until && !QDELETED(floor.breach_charge))
			if(here != breach_back_turf && !stealth_walk_over(breach_back_turf))
				breach_walk_to(breach_back_turf)
				return SUBTREE_RETURN_FINISH_PLANNING
			return breach_stand(floor.breach_charge)
		stealth_drop_walk()
		breach_back_turf = null
		breach_back_until = 0
	if(breach_planting || LAZYLEN(officer.do_afters))
		return breach_target_turf ? breach_stand(breach_target_turf) : null
	var/mob/living/quarry = police.breach_quarry(officer, src, floor)
	if(!quarry)
		breach_stuck_since = 0
		breach_hold_turf = null
		if(breach_target_turf)
			stealth_drop_walk()
			breach_drop_job()
		breach_give_back_paths()
		return
	police.breach_call_warrant(floor, officer)
	// A charge to set
	if(breach_target_turf)
		var/still_blocked = floor.breach_tile_cost(breach_target_turf) == POLICE_BREACH_BLOCKED_COST
		if(!still_blocked || world.time >= breach_plant_since + BREACH_PLANT_GIVE_UP || !QDELETED(floor.breach_charge) || stealth_walk_gave_up(breach_plant_spot))
			stealth_drop_walk()
			breach_drop_job()
			return
		if(here == breach_plant_spot || (get_dist(here, breach_target_turf) <= 1 && stealth_walk_over(breach_plant_spot)))
			stealth_drop_walk()
			INVOKE_ASYNC(police, TYPE_PROC_REF(/datum/outpost_police, breach_set_charge), officer, breach_target_turf)
			return breach_stand(breach_target_turf)
		breach_walk_to(breach_plant_spot)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/list/route = floor.breach_route(here, get_turf(quarry))
	switch(route[1])
		if(BREACH_ROUTE_OPEN)
			breach_stuck_since = 0
			if(breach_hold_turf)
				breach_hold_turf = null
				stealth_drop_walk()
			breach_give_back_paths()
			return
		if(BREACH_ROUTE_BLOCKED)
			breach_hold_turf = null
			if(!breach_stuck_since)
				breach_stuck_since = world.time
			if(world.time < breach_stuck_since + POLICE_BREACH_STALL || !police.breach_claim(floor, officer))
				return
			breach_target_turf = route[2]
			breach_plant_spot = route[3]
			breach_plant_since = world.time
			stealth_drop_walk()
			breach_walk_to(breach_plant_spot)
			return SUBTREE_RETURN_FINISH_PLANNING
	// No way at all, and nothing to blow (A15): after POLICE_BREACH_GIVE_UP it holds the nearest point it can reach
	if(!breach_stuck_since)
		breach_stuck_since = world.time
	if(world.time < breach_stuck_since + POLICE_BREACH_GIVE_UP)
		return
	if(!breach_hold_turf)
		breach_hold_turf = floor.breach_hold_point(here, get_turf(quarry)) || here
	if(here != breach_hold_turf && !stealth_walk_over(breach_hold_turf))
		breach_walk_to(breach_hold_turf)
		return SUBTREE_RETURN_FINISH_PLANNING
	return breach_stand(quarry)

// =========================================================================
// THE WALK-THROUGH (spec 6.3)
// =========================================================================

/// The middle of the top row of `floor`'s landing, where a walk starts; else the alcove's middle
/datum/outpost_floor/proc/breach_walk_landing()
	if(length(landing_bounds) >= 5)
		var/turf/top = locate(round((landing_bounds[1] + landing_bounds[3]) / 2), landing_bounds[4], landing_bounds[5])
		if(top)
			return top
	if(!length(alcove_turfs))
		return null
	return alcove_turfs[round((length(alcove_turfs) + 1) / 2)]

/**
 * The stops of a walk through this floor from `start`: the landing, the shop if it has one, then the floor, far
 * from the landing. Only tiles reached without a closed door: the walk keeps to where the public is.
 */
/datum/outpost_floor/proc/breach_walk_stops_from(turf/start)
	var/list/turf/stops = list()
	var/list/turf/reach = breach_reach(start, FALSE)
	if(!length(reach))
		return stops
	var/turf/landing = breach_walk_landing()
	if(!(landing in reach))
		landing = reach[1]
	stops += landing
	for(var/atom/point as anything in npc_sale_points())
		var/turf/beside = null
		for(var/turf/tile as anything in reach)
			if(get_dist(tile, point) <= 1 && tile != get_turf(point))
				beside = tile
				break
		if(beside)
			stops += beside
			break
	var/list/turf/far = list()
	for(var/turf/tile as anything in reach)
		if(get_dist(tile, landing) >= BREACH_WALK_FAR && !in_landing(tile) && !(tile in alcove_turfs))
			far += tile
	var/far_stops = length(stops) > 1 ? 1 : 2
	while(far_stops-- > 0 && length(far))
		var/turf/chosen = pick_n_take(far)
		stops += chosen
		// The next far stop is somewhere else on the floor
		for(var/turf/near_chosen as anything in far.Copy())
			if(get_dist(near_chosen, chosen) < BREACH_WALK_FAR)
				far -= near_chosen
	return stops

/// The Open floor of this outpost due a walk-through now, with visitors on it, or null
/datum/outpost_police/proc/breach_walk_due_floor()
	for(var/datum/outpost_floor/floor in outpost?.floors)
		if(length(floor.bounds) < 5 || !length(floor.alcove_turfs))
			continue
		if(floor.entry_policy != OUTPOST_FLOOR_ENTRY_OPEN || !floor.public_ground || floor.warrant_in_force)
			floor.breach_walk_due_at = 0
			continue
		if(!floor.breach_walk_due_at)
			floor.breach_walk_due_at = world.time + rand(BREACH_WALK_FIRST, POLICE_FLOOR_WALKTHROUGH_LOW)
			continue
		if(world.time < floor.breach_walk_due_at || !length(floor.visitors_upstairs()))
			continue
		return floor
	return null

/// Whether `officer` may go and walk a floor: a beat officer on its route on the concourse, unaware, with nothing to do
/datum/outpost_police/proc/breach_walk_officer_free(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	if(!istype(brain) || officer.unit_kind != POLICE_UNIT_BEAT || isnull(brain.route_id) || brain.breach_walk_ref)
		return FALSE
	if(officer.client || officer.case || officer.dispatch_riding || officer.dispatch_responding() || !dispatch_can_respond(officer))
		return FALSE
	if(brain.stealth_state() != STEALTH_UNAWARE || brain.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return FALSE
	return sector_of(officer) == POLICE_SECTOR_CONCOURSE

/**
 * Called for each beat officer by the police tick (stealth_tick_officer()): sends `officer` through a floor that is
 * due a walk, when nobody else is walking one, another beat officer stays and nobody is wanted at the outpost.
 */
/datum/outpost_police/proc/breach_walk_offer(mob/living/carbon/human/npc/ambient_npc/outpost/police/officer)
	if(world.time < breach_walk_look_at || !breach_walk_officer_free(officer))
		return
	breach_walk_look_at = world.time + BREACH_WALK_LOOK_GAP
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/walker = breach_walker?.resolve()
	if(!QDELETED(walker) && walker.stat != DEAD)
		var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/walker_brain = walker.ai_controller
		if(istype(walker_brain) && walker_brain.breach_walk_ref)
			return
	breach_walker = null
	if(length(dispatch_active_suspects()))
		return
	var/beat = 0
	for(var/mob/living/carbon/human/npc/ambient_npc/outpost/police/other in officers)
		if(other.stat != DEAD && other.unit_kind == POLICE_UNIT_BEAT)
			beat++
	if(beat < 2)
		return
	var/datum/outpost_floor/floor = breach_walk_due_floor()
	if(!floor)
		return
	var/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/brain = officer.ai_controller
	brain.breach_walk_begin(floor, get_turf(officer))
	floor.breach_walk_due_at = world.time + rand(POLICE_FLOOR_WALKTHROUGH_LOW, POLICE_FLOOR_WALKTHROUGH_HIGH)
	breach_walker = WEAKREF(officer)
	log_game("OUTPOST POLICE: [officer] walks through floor [floor.number] of [outpost].")

/// Sets out to walk `floor`, from `from` on the concourse
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_begin(datum/outpost_floor/floor, turf/from)
	breach_walk_clear()
	breach_walk_ref = WEAKREF(floor)
	breach_walk_stage = BREACH_WALK_UP
	breach_walk_stage_at = world.time
	breach_walk_from = from
	breach_walk_spoke = FALSE
	stealth_drop_walk()
	var/mob/living/carbon/human/npc/ambient_npc/officer = pawn
	if(istype(officer) && officer.activity)
		officer.end_activity()

/// Forgets the walk
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_clear()
	breach_walk_ref = null
	breach_walk_stage = null
	breach_walk_from = null
	breach_walk_stops = null
	breach_walk_index = 1
	breach_walk_wait_until = 0
	breach_walk_until = 0
	breach_walk_stage_at = 0

/// Back on the concourse: the walk is over and it takes its beat again
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_end()
	breach_walk_clear()
	stealth_drop_walk()
	var/turf/here = get_turf(pawn)
	// The ride up dropped its route (a new level); it was kept for it meanwhile (outpost_police_route_taken())
	if(isnull(route_id) && !isnull(police_lost_route) && group && here?.z == group.home?.z && length(group.routes[police_lost_route]) && !outpost_police_route_taken(group, police_lost_route, pawn))
		route_id = police_lost_route
		police_lost_route = null
	if(route_id)
		stealth_rejoin_route()

/**
 * The stage the walk is at, from where it stands and what its floor is now; null once it is over. Any stage but
 * the way home turns into the way home when the floor narrows, loses its ground, comes under warrant, or time is up.
 */
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_review()
	if(isnull(breach_walk_ref))
		return null
	var/datum/outpost_floor/floor = breach_walk_ref.resolve()
	var/turf/here = get_turf(pawn)
	var/on_floor = floor?.contains_turf(here)
	if(breach_walk_stage != BREACH_WALK_DOWN)
		var/narrowed = !floor || length(floor.bounds) < 5 || floor.entry_policy != OUTPOST_FLOOR_ENTRY_OPEN || !floor.public_ground || floor.warrant_in_force
		var/late = (breach_walk_stage == BREACH_WALK_UP && world.time >= breach_walk_stage_at + BREACH_WALK_UP_MAX) || (breach_walk_until && world.time >= breach_walk_until)
		if(narrowed || late)
			breach_walk_stage = BREACH_WALK_DOWN
			breach_walk_stage_at = world.time
			stealth_drop_walk()
	if(breach_walk_stage == BREACH_WALK_UP && on_floor)
		breach_walk_stage = BREACH_WALK_LOOP
		breach_walk_stage_at = world.time
		breach_walk_until = world.time + rand(POLICE_FLOOR_WALKTHROUGH_STAY_LOW, POLICE_FLOOR_WALKTHROUGH_STAY_HIGH)
		breach_walk_stops = floor.breach_walk_stops_from(here)
		breach_walk_index = 1
		breach_walk_wait_until = 0
		stealth_drop_walk()
	if(breach_walk_stage == BREACH_WALK_DOWN && !on_floor)
		breach_walk_end()
		return null
	return breach_walk_stage

/// One plan of the walk (outpost_police_floor_walk)
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_plan()
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	var/stage = breach_walk_review()
	if(isnull(stage))
		return
	if(officer.activity)
		officer.end_activity()
	// In the car: stealth_walk() started the ride and holds the walk until it arrives
	if(officer.dispatch_riding)
		queue_behavior(/datum/ai_behavior/stealth_stand)
		return SUBTREE_RETURN_FINISH_PLANNING
	var/datum/outpost_floor/floor = breach_walk_ref.resolve()
	switch(stage)
		if(BREACH_WALK_UP)
			var/turf/landing = floor?.breach_walk_landing()
			if(!landing || stealth_walk_gave_up(landing))
				breach_walk_stage = BREACH_WALK_DOWN
				breach_walk_stage_at = world.time
				stealth_drop_walk()
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			stealth_walk(landing, BREACH_GOTO_WALK)
			return SUBTREE_RETURN_FINISH_PLANNING
		if(BREACH_WALK_LOOP)
			if(breach_walk_index > length(breach_walk_stops))
				breach_walk_stage = BREACH_WALK_DOWN
				breach_walk_stage_at = world.time
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			var/turf/stop = breach_walk_stops[breach_walk_index]
			if(breach_walk_wait_until)
				if(world.time < breach_walk_wait_until)
					queue_behavior(/datum/ai_behavior/stealth_stand)
					return SUBTREE_RETURN_FINISH_PLANNING
				breach_walk_wait_until = 0
				breach_walk_index++
				stealth_drop_walk()
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			if(stealth_walk_gave_up(stop))
				// Somewhere it could not get to: the next stop
				stealth_drop_walk()
				breach_walk_index++
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			if(stealth_walk_over(stop))
				stealth_drop_walk()
				var/left = max(1, length(breach_walk_stops) - breach_walk_index + 1)
				breach_walk_wait_until = world.time + clamp(round((breach_walk_until - world.time) / left), BREACH_WALK_STOP_MIN, BREACH_WALK_STOP_MAX)
				stand_dir = stealth_facing(officer)
				look_until = world.time + STEALTH_LOOK_AROUND_TIME
				breach_walk_greet(floor)
				queue_behavior(/datum/ai_behavior/stealth_stand)
				return SUBTREE_RETURN_FINISH_PLANNING
			stealth_walk(stop, BREACH_GOTO_WALK)
			return SUBTREE_RETURN_FINISH_PLANNING
	// Home: back to where it set out from, by the floor's alcove and the police lift (stealth_walk() rides)
	var/turf/home = breach_walk_from || officer.police?.dispatch_nearest_lift_point(POLICE_SECTOR_CONCOURSE, officer)
	if(!home)
		queue_behavior(/datum/ai_behavior/stealth_stand)
		return SUBTREE_RETURN_FINISH_PLANNING
	if(stealth_walk_gave_up(home))
		stealth_drop_walk()
	stealth_walk(home, BREACH_GOTO_WALK)
	return SUBTREE_RETURN_FINISH_PLANNING

/// At a stop: a word to the nearest visitor in sight, once a walk, now and then
/datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/proc/breach_walk_greet(datum/outpost_floor/floor)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = pawn
	if(breach_walk_spoke || !floor || !prob(60))
		return
	var/mob/living/nearest
	var/nearest_distance = INFINITY
	for(var/mob/living/visitor as anything in floor.visitors_upstairs())
		var/distance = get_dist(officer, visitor)
		if(visitor.stat == CONSCIOUS && distance <= 5 && distance < nearest_distance && can_see(officer, visitor, 5))
			nearest = visitor
			nearest_distance = distance
	if(!nearest)
		return
	breach_walk_spoke = TRUE
	officer.face_atom(nearest)
	stand_dir = officer.dir
	officer.police_say(POLICE_LINE_FLOOR_WALK)

/// A beat officer walking an Open floor (spec 6.3). Waits while anything else has it; plans nothing with no walk.
/datum/ai_planning_subtree/outpost_police_floor_walk

/datum/ai_planning_subtree/outpost_police_floor_walk/SelectBehaviors(datum/ai_controller/basic_controller/human_npc/stealth/outpost_police/controller, seconds_per_tick)
	var/mob/living/carbon/human/npc/ambient_npc/outpost/police/officer = controller.pawn
	if(!istype(controller) || !istype(officer) || isnull(controller.breach_walk_ref))
		return
	if(officer.stat != CONSCIOUS || officer.client)
		return
	if(officer.case || officer.npc_exit || officer.dispatch_responding() || controller.stealth_state() != STEALTH_UNAWARE || controller.blackboard_key_exists(BB_BASIC_MOB_CURRENT_TARGET))
		return
	return controller.breach_walk_plan()

#undef BREACH_ATOMS_PER_TILE
#undef BREACH_ROUTE_OPEN
#undef BREACH_ROUTE_BLOCKED
#undef BREACH_ROUTE_SEALED
#undef BREACH_GOTO_BREACH
#undef BREACH_GOTO_WALK
#undef BREACH_PLANT_GIVE_UP
#undef BREACH_CALL_GAP
#undef POLICE_LINE_FLOOR_WARRANT
#undef POLICE_LINE_FLOOR_BREACH
#undef POLICE_LINE_FLOOR_WALK
#undef BREACH_WALK_UP
#undef BREACH_WALK_LOOP
#undef BREACH_WALK_DOWN
#undef BREACH_WALK_FIRST
#undef BREACH_WALK_UP_MAX
#undef BREACH_WALK_LOOK_GAP
#undef BREACH_WALK_STOP_MIN
#undef BREACH_WALK_STOP_MAX
#undef BREACH_WALK_FAR
