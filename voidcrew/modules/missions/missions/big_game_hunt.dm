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
 */

/// How long staking the hunting lure takes
#define LURE_STAKE_TIME (8 SECONDS)

/datum/mission/big_game_hunt
	name = "Big Game Hunt"
	weight = 7
	mission_limit = 1
	duration = 40 MINUTES
	voucher_count = 2
	quest_lost_policy = MISSION_QUEST_LOST_FAIL
	gps_tag_prefix = "TROPHY"
	// Green-band pay a notch over field_expedition: staking a lure and killing
	// an apex beast beats pulling a probe core. The zone table makes a
	// Lawless-zone hunt a serious payday.
	value_min = 1000
	value_max = 1400

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
	// Only offer hunts for planet types actually on the overmap this round
	var/list/present_types = list()
	for(var/obj/structure/overmap/planet/candidate as anything in GLOB.overmap_planets)
		if(QDELETED(candidate))
			continue
		if(!istype(get_turf(candidate), /turf/open/overmap))
			continue
		if(!candidate.planet || !hunt_tables[candidate.planet])
			continue
		present_types |= candidate.planet
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
	approach.arrival_message = "On station over the hunting ground. Take the lure down to the surface and stake it in open ground."
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
	desc = "[flavor_line] \
		[objective_name] holds the [hunt_row["ground"]] of the [planet_name] at ([target.target_x], [target.target_y]) in the [target_zone_name]. \
		A hunting lure lands on your mission pad when you accept. Fly out, use the lure in hand to stake it in open ground on the surface, and kill [objective_name] when it arrives. \
		The guild pays on the [trophy_part] - bring it back to the mission pad. \
		Payment includes [voucher_count] trade voucher[voucher_count > 1 ? "s" : ""]. \
		Tap a GPS unit on the mission board to follow the hunt's beacon ([gps_tag])."

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
 * stake position for the kill step and completes; the beast's spawn devours
 * the kit. Assumes the FAIL loss policy: the one kit can't re-arm after a
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
	kit.objective_ref = WEAKREF(src)
	// Losing the lure voids the hunt (and points the GPS chain at it meanwhile)
	mission.register_quest_atom(kit)
	notify_crew("Hunting lure delivered to your mission pad. Stake it in open ground on the hunt planet's surface.")
	return TRUE

/// The lure was staked: record the spot for the kill step and advance
/datum/mission_objective/set_lure/proc/on_planted(mob/living/user, turf/where)
	if(completed || !active || !where || !mission || mission.failed || mission.completed)
		return
	if(hunt_objective)
		hunt_objective.lure_turf = where
	// The staked lure stops being the tracked objective; the beast that
	// answers takes over the slot as soon as complete() advances the chain
	mission.forget_quest_atom(kit)
	QDEL_NULL(kit)
	notify_crew("Lure staked. Something big is moving toward it - stand ready.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')
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
 * beast (a trophy-grade specimen of the planet's apex fauna) breaks cover
 * next to the stake the moment the lure objective completes, with its
 * entourage of lesser fauna. Death drops the mission-bound trophy.
 */
/datum/mission_objective/field/kill_named/big_game
	/// Where the lure was staked; the beast breaks cover next to it
	var/turf/lure_turf
	/// The trophy the beast drops ("tendril-crowned skull"), set by the mission
	var/trophy_part = "trophy"
	/// Trophy-grade specimen: raise maxHealth/health to this on spawn (0 = leave alone).
	/// A plain var-level scale-up, no new buff system.
	var/health_override = 0

/datum/mission_objective/field/kill_named/big_game/reset()
	. = ..()
	lure_turf = null

/// The beast answers the lure, not a random spawn point
/datum/mission_objective/field/kill_named/big_game/do_field_spawn()
	if(!lure_turf)
		return ..()
	spawned = TRUE
	spawn_field_objects(get_nearby_open_turf(lure_turf, 4))

/datum/mission_objective/field/kill_named/big_game/spawn_field_objects(turf/spawn_turf)
	var/mob/living/beast = new target_mob_type(spawn_turf)
	beast.name = mission.objective_name
	beast.desc += " This one is old, scarred, and much too big. The guild wants it as a wall piece."
	if(health_override > beast.maxHealth)
		beast.maxHealth = health_override
		beast.health = health_override
	target_mob = beast
	protect_field_mob(beast)
	RegisterSignal(beast, COMSIG_LIVING_DEATH, PROC_REF(on_target_death))
	mission.register_quest_atom(beast)
	// The entourage: lesser fauna drawn in by the blood on the wind. Killing
	// them pays nothing - the contract is the name on the trophy.
	for(var/guard_type in guard_types)
		var/mob/living/guard = new guard_type(get_nearby_open_turf(spawn_turf))
		guard.desc += " It followed something much bigger here."
	beast.visible_message(span_boldwarning("[beast] comes crashing in and goes straight for the lure!"))
	notify_crew("The lure's been taken. [mission.objective_name] is out in the open - good hunting.", type = SHIP_NOTIFY_WARNING, sound = 'voidcrew/sound/notify2.ogg')

/**
 * The beast died: drop the bound trophy, track it instead, and advance.
 * Full override of kill_named's proof drop - same signal, hunt flavor.
 */
/datum/mission_objective/field/kill_named/big_game/on_target_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(target_killed || !mission || mission.failed || mission.completed)
		return
	target_killed = TRUE
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	target_mob = null

	var/obj/item/mission_recovery/trophy/trophy = new(source.drop_location())
	trophy.name = "[mission.objective_name]'s [trophy_part]"
	mission.bind_item(trophy)
	mission.register_quest_atom(trophy)

	notify_crew("[mission.objective_name] is down. Recover the [trophy_part] and return it to the mission pad.")
	complete()

/datum/mission_objective/field/kill_named/big_game/get_progress_string()
	if(!spawned)
		return "Draw [mission?.objective_name || "the beast"] out with the lure"
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
 * contracted planet's surface; the staking channel is not subtle, and the
 * thing it calls arrives immediately.
 */
/obj/item/hunting_lure
	name = "apex hunting lure"
	desc = "A folding guild lure rig: chum reservoir, pheromone wicks and a seismic thumper. \
		Use it in hand to stake it in open ground on the contracted planet, then get somewhere defensible."
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
 * # Hunting Trophy
 *
 * The proof the guild pays on: dropped by the named beast, bound to its
 * mission and retarget era like every recovery item.
 */
/obj/item/mission_recovery/trophy
	name = "hunting trophy"
	desc = "A field-dressed piece of something enormous, tagged and sealed for the guild's assayer. The mission pad will accept it."
	icon_state = "recovery"
	w_class = WEIGHT_CLASS_BULKY

#undef LURE_STAKE_TIME
