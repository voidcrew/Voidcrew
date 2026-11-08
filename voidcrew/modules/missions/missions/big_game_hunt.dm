/**
 * # Big Game Hunt
 *
 * "Something big has claimed the ashfields. Stake the lure we give you where
 * it hunts, kill what answers, and bring the guild a wall piece."
 *
 * A multi-stage trophy hunt for a named apex beast on a specific planet type:
 * [fly to the planet] -> [stake the dispensed lure on the surface] -> [kill
 * the beast the lure draws out] -> [carry the trophy home]. Generation only
 * offers hunts for planet types actually on the overmap this round (the
 * wanted_planet filter on the planet target), and the beast, its entourage,
 * its names and its trophy all come from a per-planet table. Elite tier is
 * the hard ceiling, never megafauna, never the /boss tier.
 *
 * Quest-atom chain: the lure kit until it's staked, the beast until it dies,
 * the trophy after that. Losing any of them voids the contract (FAIL policy,
 * with exactly one planet of each type per round, a filtered retarget has
 * nowhere to go, and set_lure's one kit can't re-arm a fresh site anyway).
 *
 * The staked lure stays behind as an anchored rig that thumps and stinks of
 * chum. It is scenery, not a quest atom. The beast does not appear beside it:
 * a roar rolls in from one side, then after a short wait the beast and its
 * entourage come into being out of every player's sight, a good way off, and
 * walk in on the stake (AI planning subtree at the bottom of this file). The
 * rig is trampled when the beast reaches it, or goes quiet when it dies.
 */

/// How long staking the hunting lure takes
#define LURE_STAKE_TIME (8 SECONDS)
/// Wait between the lure going in and its quarry setting out (the walk in comes on top)
#define LURE_ARRIVAL_MIN (9 SECONDS)
#define LURE_ARRIVAL_MAX (16 SECONDS)
/// How far from the stake the quarry starts out, in tiles. An AI drops a movement
/// goal more than 14 tiles away, so the far edge stays under that.
#define LURE_APPROACH_MIN 10
#define LURE_APPROACH_MAX 13
/// Nearest a player may stand to a starting tile. A screen reaches 7 tiles each way.
#define LURE_UNSEEN_RANGE 9
/// How long an animal keeps heading for the lure before it goes back to its own business
#define LURE_CHARGE_TIME (45 SECONDS)
/// The rumble before a beast climbs out of the ground (matches zone_mobs_arrival.dm)
#define LURE_EMERGE_TIME (2.5 SECONDS)
/// Blackboard key: world.time after which a lured animal stops heading for the lure
#define BB_LURE_CHARGE_EXPIRES "BB_lure_charge_expires"

/datum/mission/big_game_hunt
	name = "Big Game Hunt"
	guarded_prize_family = "hunt"
	weight = 7
	mission_limit = 1
	duration = 40 MINUTES
	voucher_count = 0
	quest_lost_policy = MISSION_QUEST_LOST_FAIL
	gps_tag_prefix = "TROPHY"
	// Green-band pay a notch over field_expedition: staking a lure and killing
	// an apex beast beats pulling a probe core. The zone table makes a
	// Lawless-zone hunt a serious payday.
	value_min = 650
	value_max = 850

	/// Per-planet hunt tables, keyed by /datum/overmap/planet typepath:
	/// the apex beast, its entourage pool, its possible names, the trophy the
	/// guild pays on, the hunting-ground flavor, and the trophy-grade health.
	/// Elites are the ceiling - never megafauna, never the /boss tier (enforced by
	/// the voidcrew_loot unit test). Rows may front either a scaled-up existing mob
	/// (via "health") or a purpose-built boss with its own tuned kit (health 0).
	var/static/list/hunt_tables = list(
		/datum/overmap/planet/lava = list(
			"beast" = /mob/living/basic/mining/goliath/ancient,
			"guards" = list(/mob/living/basic/mining/watcher, /mob/living/basic/mining/brimdemon),
			"names" = list("Old Scarhide", "Cinderback", "Magmaw", "the Tyrant of the Ashfields", "Grandfather Basalt"),
			"trophy" = "tendril-crowned skull",
			"ground" = "ash wastes",
			"health" = 450,
		),
		// The Frozen row is the first hunt fronted by a PURPOSE-BUILT boss rather
		// than a scaled-up existing mob. The Matriarch's numbers are tuned against
		// her own 3-ability/2-phase kit, so health stays 0 ("leave alone") - see
		// health_override below. Do not reintroduce a health figure here.
		/datum/overmap/planet/ice = list(
			"beast" = /mob/living/basic/hoarfrost_matriarch,
			"guards" = list(/mob/living/basic/mining/wolf/random, /mob/living/basic/mining/ice_whelp),
			"names" = list("the Widow Beneath", "Hollowfrost", "the White Silence", "Old Grief", "Mother Midnight"),
			"trophy" = "hoarfrost crown",
			"ground" = "glacier fields",
			"health" = 0,
		),
		/datum/overmap/planet/jungle = list(
			// NOTE: entourage must share a faction with the beast or they
			// infight - gorilla/beach shares "beach" with the arachnid; the
			// plain tarantula (FACTION_SPIDER) does not
			"beast" = /mob/living/basic/mega_arachnid/beach,
			"guards" = list(/mob/living/basic/gorilla/beach),
			"names" = list("the Silk Duchess", "Palewhisper", "Old Needles", "the Green Between", "Bride-of-Vines"),
			"trophy" = "razored chelicera",
			"ground" = "deep canopy",
			"health" = 400,
		),
		/datum/overmap/planet/beach = list(
			"beast" = /mob/living/basic/carp/mega/beach,
			"guards" = list(/mob/living/basic/carp/beach, /mob/living/basic/carp/beach/small),
			"names" = list("Old Undertow", "the Gray Fin", "Deepmother", "Widowmaker", "the Last Tide"),
			"trophy" = "scarred jawbone",
			"ground" = "drowned shallows",
			"health" = 300,
		),
		/datum/overmap/planet/wasteland = list(
			"beast" = /mob/living/basic/mining/goliath/ancient/wasteland,
			"guards" = list(/mob/living/basic/mining/wolf/wasteland/random, /mob/living/basic/spider/giant/tarantula/wasteland),
			"names" = list("Rustmaw", "the Landlord", "Old Testament", "Overburden", "the Last Tenant"),
			"trophy" = "armor-plated scalp",
			"ground" = "dead highways",
			"health" = 450,
		),
	)

	/// /datum/overmap/planet typepath this hunt is themed on
	var/hunt_planet_type
	/// The rolled hunt table row (points into the static table, never mutate)
	var/list/hunt_row
	/// The rolled contract-grudge line (stable across text rebuilds)
	var/flavor_line
	/// The trophy the guild pays on ("tendril-crowned skull")
	var/trophy_part
	/// The lure objective (kit dispensing at start)
	var/datum/mission_objective/set_lure/lure
	/// The kill objective (fed the lure's stake position)
	var/datum/mission_objective/field/kill_named/big_game/hunt

/datum/mission/big_game_hunt/Destroy()
	lure = null
	hunt = null
	hunt_row = null
	return ..()

/datum/mission/big_game_hunt/get_archetype()
	return "bounty"

/datum/mission/big_game_hunt/setup_target()
	var/list/present_types = get_work_biomes(hunt_tables)
	if(!length(present_types))
		return FALSE
	hunt_planet_type = pick(present_types)
	hunt_row = hunt_tables[hunt_planet_type]

	var/datum/mission_target/planet/planet_target = new(src)
	planet_target.wanted_planet = hunt_planet_type
	if(!planet_target.resolve())
		qdel(planet_target)
		return FALSE
	target = planet_target
	return TRUE

/datum/mission/big_game_hunt/generate_details()
	// Trophy contracts are Contested/Lawless work by nature: the guild
	// declines most hunts on Neutral-zone planets. Green offers stay possible
	// but rare (and green-band paying); the board just rolls another mission.
	if(difficulty == MISSION_DIFFICULTY_EASY && prob(65))
		generation_failed = TRUE
		return
	objective_name = pick(hunt_row["names"])
	trophy_part = hunt_row["trophy"]
	flavor_line = pick(list(
		"The last crew that took this contract came home as a salvage claim - [objective_name] is still wearing a piece of their hull.",
		"Three prospecting teams have gone quiet on this rock. The guild has stopped calling it bad luck and started calling it [objective_name].",
		"[objective_name] has been eating survey parties for two seasons. The lodge wants it dead and mounted on a wall.",
		"Our client watched [objective_name] take their business partner. Now they want it killed.",
		"Whatever [objective_name] can't eat, it breaks. The insurance underwriters are funding this hunt personally.",
	))
	author = pick(list(
		"Guildmaster Hale",
		"the Ashvane Hunting Lodge",
		"Master-of-Hunts Okonkwo",
		"Huntmistress Var",
		"the Sector Trophy Registry",
	))

/datum/mission/big_game_hunt/build_objectives()
	var/datum/mission_objective/goto_coords/approach = new
	approach.arrival_message = "On station over the hunting ground."
	add_objective(approach)

	lure = new
	add_objective(lure)

	hunt = new
	hunt.target_mob_type = hunt_row["beast"]
	hunt.trophy_part = trophy_part
	hunt.health_override = hunt_row["health"]
	// The entourage scales with the zone: a Lawless-zone apex hunts with company
	var/guard_count = 1
	switch(difficulty)
		if(MISSION_DIFFICULTY_MEDIUM)
			guard_count = 2
		if(MISSION_DIFFICULTY_HARD)
			guard_count = 3
	var/list/guard_pool = hunt_row["guards"]
	var/list/guards = list()
	for(var/_ in 1 to guard_count)
		guards += pick(guard_pool)
	hunt.guard_types = guards
	add_objective(hunt)
	lure.hunt_objective = hunt

	add_objective(new /datum/mission_objective/deliver/bound/trophy)

/datum/mission/big_game_hunt/on_mission_started()
	lure?.dispense_kit()

/datum/mission/big_game_hunt/update_text()
	var/datum/mission_target/planet/planet_target = target
	var/planet_name = istype(planet_target) ? (planet_target.planet?.name || "the planet") : "the planet"
	name = "Big Game Hunt: [objective_name]"
	desc = "Hunt [objective_name] on [planet_name] at ([target.target_x], [target.target_y]) in the [target_zone_name]. The guild wants its [trophy_part]."

/datum/mission/big_game_hunt/waypoint_label()
	return "Hunt: [objective_name]"

/datum/mission/big_game_hunt/get_ui_data()
	var/list/data = ..()
	data["target_x"] = target.target_x
	data["target_y"] = target.target_y
	return data

// =========================================================================
// SET THE LURE, stake the dispensed kit on the hunt planet's surface
// =========================================================================

/**
 * A lure kit is dispensed at the servant's mission pad on accept (the
 * prospect-stake kit pattern) and tracked as the quest atom, burn the lure,
 * void the hunt. Staking it in open ground on the target planet records the
 * stake position for the kill step, stands the rig on that spot and
 * completes. Assumes the FAIL loss policy: the one kit can't re-arm after a
 * retarget reset.
 */
/datum/mission_objective/set_lure
	/// The lure kit dispensed at accept
	var/obj/item/hunting_lure/kit
	/// The kill step this lure feeds its stake position to
	var/datum/mission_objective/field/kill_named/big_game/hunt_objective

/datum/mission_objective/set_lure/Destroy()
	kit = null // the item survives; it self-reports expiry on use
	hunt_objective = null
	return ..()

/// Called by the mission at start: hand the lure over at the ship's pad
/datum/mission_objective/set_lure/proc/dispense_kit()
	var/obj/structure/overmap/ship/ship = get_servant()
	var/turf/kit_turf
	for(var/obj/machinery/mission_pad/pad as anything in ship?.linked_mission_pads)
		if(!QDELETED(pad))
			kit_turf = get_turf(pad)
			break
	if(!kit_turf)
		mission.fail("No mission pad to dispense the hunting lure to.")
		return FALSE
	kit = new(kit_turf)
	mission_pad_delivery_effect(kit_turf)
	kit.objective_ref = WEAKREF(src)
	// Losing the lure voids the hunt (and points the GPS chain at it meanwhile)
	mission.register_quest_atom(kit)
	notify_crew("Hunting lure delivered.")
	return TRUE

/// The lure was staked: record the spot for the kill step and advance
/datum/mission_objective/set_lure/proc/on_planted(mob/living/user, turf/where)
	if(completed || !active || !where || !mission || mission.failed || mission.completed)
		return
	// The rig goes into the ground here and the kill step takes it from there
	hunt_objective?.plant_lure(where)
	// The staked lure stops being the tracked objective; the beast that
	// answers takes over the slot once it has been called in
	mission.forget_quest_atom(kit)
	QDEL_NULL(kit)
	notify_crew("Lure staked.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')
	complete()

/datum/mission_objective/set_lure/get_progress_string()
	var/datum/mission_target/target = mission?.target
	if(!target)
		return "Stake the lure on the surface"
	return "Stake the lure on the surface at ([target.target_x], [target.target_y])"

// =========================================================================
// THE KILL, the named beast answers the lure
// =========================================================================

/**
 * kill_named pointed at the lure instead of a random stretch of surface: the
 * beast (a trophy-grade specimen of the planet's apex fauna) answers the
 * stake with its entourage of lesser fauna. It is called in after a roar and a
 * short wait, starts well out of sight and heads for the stake; a site too
 * cramped to hide an approach gets the beast climbing out of the ground next
 * to it instead. Death drops the mission-bound trophy.
 */
/datum/mission_objective/field/kill_named/big_game
	proof_type = /obj/item/mission_recovery/trophy
	/// Where the lure was staked; the beast comes for it
	var/turf/lure_turf
	/// The rig standing on lure_turf (weak: it goes with the site)
	var/datum/weakref/lure_stake_ref
	/// Pending arrival timer: the wait before the quarry sets out, or the rumble before it digs out
	var/arrival_timer
	/// Whether the beast has been called but is not out yet
	var/arrival_pending = FALSE
	/// Where the first roar came from; the quarry comes in from the same side
	var/turf/approach_hint
	/// The trophy the beast drops ("tendril-crowned skull"), set by the mission
	var/trophy_part = "trophy"
	/// Trophy-grade specimen: raise maxHealth/health to this on spawn (0 = leave alone).
	/// A plain var-level scale-up, no new buff system.
	var/health_override = 0

/datum/mission_objective/field/kill_named/big_game/Destroy()
	cancel_arrival()
	// Never leave the rig behind for a contract that no longer exists
	var/obj/structure/hunting_lure_stake/stake = lure_stake_ref?.resolve()
	stake?.topple()
	lure_stake_ref = null
	approach_hint = null
	lure_turf = null
	return ..()

/datum/mission_objective/field/kill_named/big_game/deactivate()
	// Completed, failed or rewound: nothing is on its way and the rig goes quiet
	cancel_arrival()
	var/obj/structure/hunting_lure_stake/stake = lure_stake_ref?.resolve()
	stake?.topple()
	lure_stake_ref = null
	return ..()

/datum/mission_objective/field/kill_named/big_game/reset()
	. = ..()
	lure_turf = null
	approach_hint = null

/// Stops a call that is still waiting to be answered
/datum/mission_objective/field/kill_named/big_game/proc/cancel_arrival()
	if(arrival_timer)
		deltimer(arrival_timer)
		arrival_timer = null
	arrival_pending = FALSE

/// The kit went into the ground: remember the spot and stand the rig on it
/datum/mission_objective/field/kill_named/big_game/proc/plant_lure(turf/where)
	lure_turf = where
	var/obj/structure/hunting_lure_stake/stake = new(where)
	lure_stake_ref = WEAKREF(stake)

/// The beast answers the lure, not a random spawn point, and not at once
/datum/mission_objective/field/kill_named/big_game/do_field_spawn()
	if(spawned)
		return
	if(!lure_turf)
		return ..()
	spawned = TRUE
	arrival_pending = TRUE
	// First sign of it: a roar from the side it will come in on (or from the
	// ground itself where there is no hiding place)
	var/list/approaches = approach_turfs()
	approach_hint = length(approaches) ? pick(approaches) : null
	var/turf/roar_from = approach_hint || lure_turf
	playsound(roar_from, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 40, TRUE, extrarange = 20)
	for(var/mob/living/hearer in GLOB.player_list)
		if(hearer.z == lure_turf.z && get_dist(hearer, lure_turf) <= 14 && hearer.can_hear())
			to_chat(hearer, span_boldwarning("Something huge bellows in the distance."))
	arrival_timer = addtimer(CALLBACK(src, PROC_REF(answer_lure)), rand(LURE_ARRIVAL_MIN, LURE_ARRIVAL_MAX), TIMER_STOPPABLE | TIMER_DELETE_ME)

/// The wait is over: the beast and its entourage set out for the stake
/datum/mission_objective/field/kill_named/big_game/proc/answer_lure()
	arrival_timer = null
	if(!arrival_still_wanted())
		return
	var/datum/mission_target/site = mission.target
	if(!lure_turf || !site?.is_valid() || !site.is_interior_loaded() || !site.contains_turf(lure_turf))
		// The hunting ground went away during the wait; arm again the ordinary way
		cancel_arrival()
		spawned = FALSE
		lure_turf = null
		arm()
		return
	var/list/approaches = approach_turfs()
	if(!length(approaches))
		dig_out()
		return
	arrival_pending = FALSE
	// Start on the side the roar came from where there is room, and where a
	// straight run at the stake looks open
	var/list/same_side = list()
	for(var/turf/candidate as anything in approaches)
		if(approach_hint && get_dist(candidate, approach_hint) <= 6)
			same_side += candidate
	var/list/pool = length(same_side) ? same_side : approaches
	var/turf/lead = pick(pool)
	for(var/_ in 1 to 12)
		var/turf/candidate = pick(pool)
		if(approach_is_clear(candidate))
			lead = candidate
			break
	// The entourage trails in beside it, on tiles that are also out of sight
	var/list/guard_spots = list()
	for(var/_ in guard_types)
		var/list/beside = list()
		for(var/turf/candidate as anything in approaches)
			if(get_dist(candidate, lead) <= 4)
				beside += candidate
		guard_spots += length(beside) ? pick(beside) : lead
	spawn_field_objects(lead, guard_spots)
	playsound(lead, 'sound/mobs/non-humanoids/space_dragon/space_dragon_roar.ogg', 50, TRUE, extrarange = 20)

/// Whether a delayed arrival should still go ahead
/datum/mission_objective/field/kill_named/big_game/proc/arrival_still_wanted()
	return active && !completed && mission && !mission.failed && !mission.completed && !mission.named_kill_completed && !target_mob

/**
 * Open ground a good way from the stake that nobody is close enough to see:
 * the quarry's starting tiles. Empty where the site is too small, too crowded
 * or too cluttered to hide an approach.
 */
/datum/mission_objective/field/kill_named/big_game/proc/approach_turfs()
	. = list()
	var/datum/mission_target/site = mission?.target
	if(!lure_turf || !site)
		return
	var/list/watchers = list()
	for(var/mob/living/player in GLOB.player_list)
		var/turf/watcher_turf = get_turf(player)
		if(watcher_turf?.z == lure_turf.z && player.stat != DEAD)
			watchers += watcher_turf
	for(var/turf/open/candidate in RANGE_TURFS(LURE_APPROACH_MAX, lure_turf))
		if(get_dist(candidate, lure_turf) < LURE_APPROACH_MIN)
			continue
		if(isspaceturf(candidate) || islava(candidate) || ischasm(candidate))
			continue
		// Open planet ground only: no landed ship, no ruin, nothing past the site's edge
		if(!istype(get_area(candidate), /area/overmap_encounter/planetoid) || !site.contains_turf(candidate))
			continue
		// Not the docking strip: a ship coming in to land would crush whatever stands on it
		if((candidate.turf_flags & NO_RUINS) || candidate.is_blocked_turf(exclude_mobs = TRUE))
			continue
		var/seen = FALSE
		for(var/turf/watcher_turf as anything in watchers)
			if(get_dist(watcher_turf, candidate) < LURE_UNSEEN_RANGE)
				seen = TRUE
				break
		if(!seen)
			. += candidate

/// Whether a straight run from the tile to the stake is open ground
/datum/mission_objective/field/kill_named/big_game/proc/approach_is_clear(turf/from)
	for(var/turf/along as anything in get_line(from, lure_turf))
		if(!isopenturf(along) || islava(along) || ischasm(along) || along.is_blocked_turf(exclude_mobs = TRUE))
			return FALSE
	return TRUE

/**
 * No hiding place for an approach: the ground shakes beside the lure and the
 * pack climbs out of it, the same rumble the mission waves use.
 */
/datum/mission_objective/field/kill_named/big_game/proc/dig_out()
	var/turf/lead = get_nearby_open_turf(lure_turf, 4)
	var/list/guard_spots = list()
	for(var/_ in guard_types)
		guard_spots += get_nearby_open_turf(lure_turf, 4)
	for(var/turf/spot as anything in list(lead) + guard_spots)
		new /obj/effect/temp_visual/zone_mobs_emerge(spot)
	playsound(lead, 'sound/effects/break_stone.ogg', 60, TRUE)
	arrival_timer = addtimer(CALLBACK(src, PROC_REF(emerge_pack), lead, guard_spots), LURE_EMERGE_TIME, TIMER_STOPPABLE | TIMER_DELETE_ME)

/datum/mission_objective/field/kill_named/big_game/proc/emerge_pack(turf/lead, list/guard_spots)
	arrival_timer = null
	arrival_pending = FALSE
	if(!arrival_still_wanted())
		return
	spawn_field_objects(lead, guard_spots, emerge = TRUE)

/// The ground gives up a body: rubble underneath, then it rises out of the dirt
/datum/mission_objective/field/kill_named/big_game/proc/rise_from_ground(mob/living/body)
	if(QDELETED(body))
		return
	var/turf/where = get_turf(body)
	if(where)
		new /obj/effect/decal/cleanable/rubble(where)
		playsound(where, 'sound/effects/shovel_dig.ogg', 60, TRUE)
	// Parallel and relative so a mob's own idle animation (floating, bobbing) survives
	var/final_alpha = body.alpha
	body.alpha = 0
	body.pixel_z -= 16
	animate(body, pixel_z = 16, time = 0.6 SECONDS, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(body, alpha = final_alpha, time = 0.4 SECONDS, flags = ANIMATION_PARALLEL)

/**
 * Points a lured animal at the stake. It walks there whenever it has nothing
 * of its own to hunt, so it goes for the first crew member it sees and
 * otherwise comes straight in.
 */
/datum/mission_objective/field/kill_named/big_game/proc/send_to_lure(mob/living/body)
	var/datum/ai_controller/brain = body?.ai_controller
	if(QDELETED(body) || !istype(brain) || !lure_turf)
		return
	brain.set_blackboard_key(BB_TRAVEL_DESTINATION, lure_turf)
	brain.set_blackboard_key(BB_LURE_CHARGE_EXPIRES, world.time + LURE_CHARGE_TIME)
	var/list/subtrees = brain.planning_subtrees ? brain.planning_subtrees.Copy() : list()
	subtrees += GLOB.ai_subtrees[/datum/ai_planning_subtree/travel_to_point/lure_charge]
	brain.planning_subtrees = subtrees
	// An animal this far from anyone would otherwise stand about until somebody wandered close
	brain.can_idle = FALSE
	brain.reset_ai_status()

/datum/mission_objective/field/kill_named/big_game/spawn_field_objects(turf/spawn_turf, list/guard_spots, emerge = FALSE)
	if(mission.named_kill_completed)
		return ..()
	// Anything that did not climb out of the ground has come a long way to get here
	var/charging = !emerge && lure_turf
	var/mob/living/beast = spawn_field_npc(target_mob_type, spawn_turf, finalize = FALSE)
	beast.name = mission.objective_name
	beast.desc += " This one is old, scarred, and much too big. The guild wants it as a wall piece."
	if(health_override > beast.maxHealth)
		beast.maxHealth = health_override
		beast.health = health_override
	beast.npc_spawn_context.finalize()
	track_target(beast)
	// The entourage: lesser fauna drawn in by the blood on the wind. Killing
	// them pays nothing - the contract is the name on the trophy.
	for(var/guard_type in guard_types)
		var/turf/guard_turf = length(guard_spots) ? pick_n_take(guard_spots) : get_nearby_open_turf(spawn_turf)
		var/mob/living/guard = spawn_field_npc(guard_type, guard_turf, finalize = FALSE)
		guard.desc += " It followed something much bigger here."
		guard.npc_spawn_context.finalize()
		if(charging)
			send_to_lure(guard)
		if(emerge)
			rise_from_ground(guard)
	if(charging)
		send_to_lure(beast)
	if(emerge)
		rise_from_ground(beast)
	var/obj/structure/hunting_lure_stake/stake = lure_stake_ref?.resolve()
	stake?.watch(beast)

/datum/mission_objective/field/kill_named/big_game/get_proof_name()
	return "[mission.objective_name]'s [trophy_part]"

/datum/mission_objective/field/kill_named/big_game/get_progress_string()
	if(!spawned)
		return "Draw [mission?.objective_name || "the beast"] out with the lure"
	if(arrival_pending)
		return "[mission?.objective_name || "The beast"] is coming for the lure"
	return "Bring down [mission?.objective_name || "the beast"]"

// =========================================================================
// TROPHY TURN-IN, the bound carry-home step, hunt-flavored text
// =========================================================================

/datum/mission_objective/deliver/bound/trophy
	required_name = "the trophy"

/datum/mission_objective/deliver/bound/trophy/describe_ask()
	return "trophy of [mission?.objective_name || "the beast"]"

/**
 * # Hunting Lure
 *
 * The kit handed over at accept. Stake it in hand, in open ground on the
 * contracted planet's surface. The staking channel is not subtle; what it
 * calls takes a little while to get there.
 */
/obj/item/hunting_lure
	name = "apex hunting lure"
	desc = "A folding guild lure rig with a chum reservoir, pheromone wicks and a seismic thumper."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "recovery_anchored"
	w_class = WEIGHT_CLASS_NORMAL

	/// Weakref to the set_lure objective this kit serves
	var/datum/weakref/objective_ref

/obj/item/hunting_lure/attack_self(mob/user)
	. = ..()
	if(.)
		return
	var/datum/mission_objective/set_lure/objective = objective_ref?.resolve()
	if(!objective?.mission || objective.mission.failed || objective.mission.completed)
		balloon_alert(user, "contract expired!")
		return TRUE
	if(!objective.active)
		balloon_alert(user, "not the hunt's current step!")
		return TRUE
	var/turf/here = get_turf(user)
	// Open ground on the contracted planet only: surface or caves, never
	// aboard a docked ship or inside a planetary ruin
	if(!here || !istype(get_area(here), /area/overmap_encounter/planetoid) || !objective.mission.target?.contains_turf(here))
		balloon_alert(user, "stake it in open ground on the hunt planet!")
		return TRUE
	balloon_alert(user, "staking the lure...")
	playsound(src, 'sound/items/tools/ratchet.ogg', 60, TRUE)
	if(!do_after(user, LURE_STAKE_TIME, target = user))
		balloon_alert(user, "staking interrupted!")
		return TRUE
	if(!objective.active || objective.completed)
		return TRUE
	user.visible_message(span_warning("[user] stakes [src] into the ground. It starts pumping out blood scent and low, heavy thumps."))
	objective.on_planted(user, get_turf(user))
	return TRUE

/**
 * # Staked Hunting Lure
 *
 * What the kit turns into once it is in the ground: an anchored rig that
 * thumps and stinks of chum until the beast it called tramples it or dies.
 * Scenery only: not a quest atom, not an item, nothing to salvage, and the hunt
 * carries on whatever happens to it.
 */
/obj/structure/hunting_lure_stake
	name = "hunting lure"
	desc = "A guild lure rig staked into the dirt. It stinks of chum and thumps like a heartbeat."
	icon = 'voidcrew/modules/missions/icons/recovery.dmi'
	icon_state = "recovery_anchored"
	anchored = TRUE
	density = FALSE
	move_resist = INFINITY
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// Weakref to the beast that was called here
	var/datum/weakref/watched_ref
	/// Whether it is already coming down
	var/toppled = FALSE
	/// Process ticks since the last thump
	var/thump_ticks = 0

/obj/structure/hunting_lure_stake/Initialize(mapload)
	. = ..()
	START_PROCESSING(SSobj, src)

/obj/structure/hunting_lure_stake/Destroy()
	STOP_PROCESSING(SSobj, src)
	unwatch()
	return ..()

/obj/structure/hunting_lure_stake/process(seconds_per_tick)
	thump_ticks++
	if(thump_ticks < 2)
		return
	thump_ticks = 0
	playsound(src, 'sound/effects/singlebeat.ogg', 40, TRUE, extrarange = 6)
	animate(src, pixel_y = 2, time = 1)
	animate(pixel_y = 0, time = 2)

/// The beast it called is out: trample the rig when it gets here, drop it if the beast dies first
/obj/structure/hunting_lure_stake/proc/watch(mob/living/beast)
	if(toppled || QDELETED(beast))
		return
	unwatch()
	watched_ref = WEAKREF(beast)
	RegisterSignal(beast, COMSIG_MOVABLE_MOVED, PROC_REF(on_beast_moved))
	RegisterSignal(beast, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING), PROC_REF(on_beast_gone))

/obj/structure/hunting_lure_stake/proc/unwatch()
	var/mob/living/beast = watched_ref?.resolve()
	if(beast)
		UnregisterSignal(beast, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	watched_ref = null

/obj/structure/hunting_lure_stake/proc/on_beast_moved(mob/living/source, atom/old_loc, movement_dir, forced, list/old_locs)
	SIGNAL_HANDLER
	if(get_dist(source, src) <= 1)
		topple(source)

/obj/structure/hunting_lure_stake/proc/on_beast_gone(datum/source)
	SIGNAL_HANDLER
	topple()

/// The rig comes down and goes quiet, trampled by the beast if it got here
/obj/structure/hunting_lure_stake/proc/topple(mob/living/by)
	if(toppled)
		return
	toppled = TRUE
	STOP_PROCESSING(SSobj, src)
	unwatch()
	if(by)
		visible_message(span_danger("[by] tramples [src]."))
	else
		visible_message(span_warning("[src] topples over and goes quiet."))
	playsound(src, 'sound/effects/clang.ogg', 50, TRUE)
	animate(src, transform = turn(transform, 80), pixel_y = -4, alpha = 0, time = 1 SECONDS, easing = QUAD_EASING | EASE_IN)
	QDEL_IN(src, 1 SECONDS)

/**
 * # Hunting Trophy
 *
 * The proof the guild pays on: dropped by the named beast, bound to its
 * mission and retarget era like every recovery item.
 */
/obj/item/mission_recovery/trophy
	name = "hunting trophy"
	desc = "A field-dressed piece of something enormous, tagged for the guild's assayer."
	icon_state = "recovery"
	w_class = WEIGHT_CLASS_BULKY

// =========================================================================
// THE CHARGE, lured animals walk in on the stake
// =========================================================================

/**
 * The last thing a lured animal plans. Everything it can hunt on its own comes
 * first, so it goes for the first crew member it sees and otherwise heads for
 * the stake. Gives up after LURE_CHARGE_TIME and goes back to its own business.
 */
/datum/ai_planning_subtree/travel_to_point/lure_charge
	travel_behaviour = /datum/ai_behavior/travel_towards/lure_charge

/datum/ai_planning_subtree/travel_to_point/lure_charge/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	if(controller.blackboard[location_key] && world.time > controller.blackboard[BB_LURE_CHARGE_EXPIRES])
		controller.clear_blackboard_key(location_key)
		return
	return ..()

/// Close enough to the stake counts as there; the goal is dropped once it is reached
/datum/ai_behavior/travel_towards/lure_charge
	required_distance = 2

/datum/ai_behavior/travel_towards/lure_charge/finish_action(datum/ai_controller/controller, succeeded, target_key)
	. = ..()
	if(succeeded)
		controller.clear_blackboard_key(target_key)

#undef LURE_STAKE_TIME
#undef LURE_ARRIVAL_MIN
#undef LURE_ARRIVAL_MAX
#undef LURE_APPROACH_MIN
#undef LURE_APPROACH_MAX
#undef LURE_UNSEEN_RANGE
#undef LURE_CHARGE_TIME
#undef LURE_EMERGE_TIME
#undef BB_LURE_CHARGE_EXPIRES
