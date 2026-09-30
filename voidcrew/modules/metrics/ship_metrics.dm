// Round metrics for player ship lifecycle and crew, and encounters with NPC ships.
// See voidcrew/modules/metrics/metrics_helpers.dm for record_metric() and tally_metric().
//
// CONVENTIONS
//
// - METRIC_SHIP rows: `ship` is the player ship the row is about. A pirate hull counts as a
//   player ship from the moment players claim it.
// - METRIC_PIRATE rows: `ship` is always the NPC ship, so ship_id, ship_name and ship_class name
//   the pirate and its template. The player ship involved goes in details as player_ship_id and
//   player_ship. ckey is the player involved, when one is known.
// - credits on METRIC_PIRATE rows count money moving between players and the NPC, seen from the
//   NPC: positive when players lose it to the NPC (tribute, siphon), negative when players get it
//   (hold siphoned back, siphon loot, bounty payout). SUM(credits) over the category is what
//   pirates netted from players. Summary rows (npc_encounter_end) keep amounts in details only.
// - Ship ids come from the ship's shuttle, so nothing is written about a hull after its shuttle
//   is detached: ship_removed or npc_despawned is always a hull's last row.
// - "details: player ship" below means player_ship_id and player_ship.
//
// EVENT CATALOG
//
// METRIC_SHIP (ship = the player ship)
//   ship_spawned        A hull enters the round: roundstart fleet, lobby purchase, requisition,
//                       admin spawn or hand-built hull. subject = template type, credits = the
//                       commissioning funds put in its account, ckey = the builder of a hand-built
//                       hull. details: roundstart, source, theme, modules.
//   ship_purchased      A player launches a hull from the lobby. ckey = buyer, subject = template.
//   ship_requisitioned  A player with no seat in the fleet is given a free hull. ckey, subject.
//   ship_unlocked, ship_theme_unlocked, ship_module_unlocked
//                       A permanent hull, theme or module unlock bought with ship parts in the
//                       lobby. No ship. ckey, subject = template type, theme id or module id,
//                       points = parts spent. details: template, parts (by class).
//   crew_joined, crew_left
//                       A mind joins or leaves the crew roster. ckey, subject = job title,
//                       quantity = roster size afterwards.
//   command_changed     Command passes by transfer or election. ckey = new commander,
//                       other_ckey = the one relieved, subject = reason.
//   ship_claimed        An abandoned player hull is claimed at its helm. ckey = claimer.
//                       details: abandoned_seconds, claimer_ship_id, claimer_ship.
//   ship_abandoned      The hull went crewless long enough to be abandoned. quantity = roster
//                       size when it happened. details: age_seconds.
//   ship_destroyed      Hull integrity failed and the ship crash-lands (it can be repaired).
//                       Not written for the crash that abandonment itself causes. details:
//                       last_hit_by_id, last_hit_by, last_hit_by_npc, seconds_since_hit.
//   ship_repaired       A failed hull comes back into service.
//   ship_removed        The hull leaves the round. subject = reason: bluespace_jump,
//                       derelict_despawned, never_crewed_despawned or deleted. details:
//                       age_seconds, crew; parts_extracted and crew_aboard for a jump.
//   ship_force_docked   A ship's interdictor forces another player ship to dock with it.
//                       ship = the ship that did it, ckey = interdictor operator. details:
//                       target_ship_id, target_ship.
//   ship_siphoned       A player ship's data siphon finishes a run on another player ship.
//                       ship = the siphoning ship, credits = taken. details: target ship.
//   <weapon>_hit_<shield|hull>
//                       Weapon hits, tallied per minute. weapon is laser, missile or assault_pod.
//                       ship = the ship that fired (player or NPC), subject = ship_id of the ship
//                       hit, zone = the target's, quantity = hits, points = the weapon's damage.
//
// METRIC_PIRATE (ship = the NPC ship)
//   npc_spawned         A pirate or patrol hull is loaded and crewed. subject = type,
//                       quantity = crew spawned. details: hold (credits aboard), pool (pool
//                       pirate), replacement (spawned after roundstart), faction.
//   npc_encounter_start The NPC takes a player ship as its target: IDLE to any active state,
//                       or a new target mid-fight. zone = the target's. details: player ship,
//                       first_state (scanning, hailing, engaging, combat), encounter (count for
//                       this hull, 1 = first), player_started (the player ship targeted or locked
//                       it first), player_crew, player_credits.
//   npc_encounter_end   The encounter is over. subject = outcome. details: player ship, outcome,
//                       ended_from (last state), states (every state visited, in order), seconds,
//                       encounter, player_started, and when they happened: player_attacked
//                       (targeting or weapons_lock during the encounter), interdicted_by_player,
//                       tribute, items_paid, siphoned, boarders, waves, boss, npc_damage_taken,
//                       player_damage_taken.
//                       Outcomes: tribute_paid, boss_killed, player_crew_killed, fled (after its
//                       weapons were destroyed), left_after_siphon, raid_repelled (a yellow raid's
//                       waves were beaten), target_crew_dead, target_gone,
//                       target_docked_or_crashed, target_cloaked, target_reached_green,
//                       target_hidden, target_left_zone, target_out_of_range, scan_found_nothing,
//                       yielded_to_other_pirate, npc_docked_or_crashed, switched_target,
//                       hull_claimed, hull_removed, other.
//   npc_negotiation     A holopad negotiation ends. subject = paid_credits, paid_items, refused,
//                       timeout, player_moved, player_aggression, pirate_destroyed or
//                       holopad_destroyed. credits = tribute paid, quantity = items handed over.
//                       details: player ship, demand, item_demand, item_quantity, items_received,
//                       barter, preemptive, caught_fleeing, seconds.
//   npc_raid_started    Phased boarding begins. details: player ship, player_crew, waves planned.
//   npc_boarding_wave   A boarding wave lands. subject = wave number, quantity = boarders.
//                       details: player ship, wave, waves.
//   npc_boarding_wave_end
//                       A wave is cleared or times out. subject = cleared or timed_out.
//                       details: player ship, wave, seconds. Waves cut short by ship combat or
//                       by the raid ending show in npc_encounter_end instead.
//   npc_boss_deployed   The faction boss drops aboard the target. subject = boss type.
//   npc_boarding_pods   Boarding pods fired during ship combat, tallied per minute.
//                       subject = ship_id of the target, quantity = pods.
//   npc_retreated       The NPC breaks off and flees. subject = reason: no_weapons or
//                       siphon_goal. details: player ship, seconds into the encounter,
//                       integrity, npc_damage_taken.
//   npc_disabled        The boss was killed; the hull is dead in the water and claimable.
//                       details: player ship, seconds into the encounter.
//   npc_immobilized     Every real thruster aboard is gone. details: integrity, damage_taken,
//                       player ship if in an encounter.
//   npc_hull_destroyed  Hull integrity failed and the NPC crash-lands (not the crash abandonment
//                       causes). details: last_hit_by_id, last_hit_by, last_hit_by_npc,
//                       seconds_since_hit, crew_alive, damage_taken, player ship if in an
//                       encounter.
//   npc_crew_wiped      The last of the NPC's own crew died. details: crew_spawned,
//                       age_seconds, integrity, hull_destroyed, disabled, boarded_by.
//   npc_boarded         The first player of a crew sets foot aboard (once per crew, or per
//                       player without one). ckey. details: player ship, crew_alive, hull
//                       (flying, docked or crashed), disabled.
//   npc_force_docked    A player interdictor forces the NPC to dock with it. ckey = operator.
//                       details: player ship, crew_alive, disabled.
//   npc_claimed         Players take the hull. ckey = claimer, subject = key or abandoned_wreck.
//                       details: claimer ship, abandoned, disabled, crew_alive, hold,
//                       age_seconds, damage_taken, encounters.
//   npc_siphoned_player The NPC's data siphon finishes a run. credits = taken (positive).
//                       details: player ship.
//   npc_hold_siphoned   A player ship's siphon finishes a run on the NPC's hold.
//                       credits = taken (negative). details: player ship.
//   npc_siphon_looted   A player empties the NPC's siphon into a holochip. ckey,
//                       credits = amount (negative). details: player ship.
//   npc_abandoned       The hull is abandoned (a derelict anyone can claim). details: age_seconds.
//   npc_resolved        The pirate pool slot this hull held is freed. subject = reason (crew
//                       wiped, disarmed, claimed, abandoned, hull deleted, key claimed, key
//                       bounty_turned_in, key destroyed, the reconcile variants). details:
//                       age_seconds, integrity, damage_taken, pool_zone.
//   npc_despawned       The hull leaves the round. subject = reason: disarmed_salvage_expired,
//                       derelict_despawned, warped_out or deleted. details: age_seconds,
//                       pool_slot_freed, encounters, damage_taken, boarded_by.
//   npc_bounty_posted   A Mission Board bounty goes up for the hull. subject = heavy or light.
//                       details: reward.
//   npc_bounty_accepted A player ship takes the bounty. details: player ship, hunters.
//   npc_bounty_paid     The key is turned in. credits = -payout. subject = heavy or light.
//                       details: player ship, reward, tracking, items, hunters.
//   npc_bounty_failed   The bounty can no longer be paid. subject = the reason given.
//                       details: hunters.
//   Bounty rows leave `ship` empty and add npc_ship to details when the hull is already gone.

// Mirrors of module-local defines in voidcrew/modules/npc_ships/code/_defines.dm, which is
// compiled after this file. Keep them in step with NPC_COMBAT_* and the BB_NPC_* keys.
#define METRIC_NPC_IDLE "idle"
#define METRIC_NPC_SCANNING "scanning"
#define METRIC_NPC_RETREATING "retreating"
#define METRIC_NPC_BOARDING "boarding"
#define METRIC_NPC_BOARDING_COOLDOWN "boarding_cooldown"
#define METRIC_NPC_BOSS_PHASE "boss_phase"
#define METRIC_NPC_DISABLED "disabled"
#define METRIC_NPC_DISENGAGING "disengaging"
#define METRIC_BB_RETREAT_REASON "npc_retreat_reason"
#define METRIC_BB_BOARDING_CREW "npc_boarding_crew_count"
#define METRIC_BB_WAVE_START "npc_boarding_wave_start"

/obj/structure/overmap/ship
	/// world.time this hull's spawn row was written. Also marks it as spawned for metrics.
	var/metric_spawned_at
	/// TRUE once the removal row is written; nothing more is recorded about the hull.
	var/metric_removed = FALSE
	/// Why the hull is about to leave the round, when the caller knows (a bluespace jump).
	var/metric_removal_reason
	/// Extra details for the removal row, set with metric_removal_reason.
	var/list/metric_removal_details
	/// The last ship to land a weapon hit on this one, and when.
	var/metric_last_hit_by_id
	var/metric_last_hit_by_name
	var/metric_last_hit_by_npc = FALSE
	var/metric_last_hit_at

/obj/structure/overmap/ship/npc
	/// The encounter in progress, if any.
	var/datum/npc_metric_encounter/metric_encounter
	/// How many encounters this hull has started.
	var/metric_encounter_count = 0
	/// Crew spawned with the hull.
	var/metric_crew_spawned = 0
	/// Weapon damage this hull has taken in its life.
	var/metric_damage_taken = 0
	/// Crews (by ship id, or "ckey:" for a player with no ship) that have set foot aboard.
	var/list/metric_boarded_by
	/// The hull's own rooms, watched for boarders. Kept apart from shuttle_areas, which also
	/// takes in the rooms of any ship that docks to this one.
	var/list/metric_hull_areas
	/// Set once the loss of every real thruster has been recorded.
	var/metric_immobilized = FALSE
	/// The last player ship to start targeting or lock onto this hull, and when.
	var/metric_aggressor_id
	var/metric_aggression_at

/// What happened in one NPC encounter, written out as npc_encounter_end.
/datum/npc_metric_encounter
	var/started_at
	/// Which encounter of its hull this is, 1 for the first.
	var/number = 0
	var/datum/weakref/target_ref
	var/target_id
	var/target_name
	var/first_state
	/// Every combat state visited, in order.
	var/list/states = list()
	/// The player ship targeted or locked the NPC before it acted.
	var/player_started = FALSE
	/// targeting or weapons_lock, if the player ship turned on the NPC mid-encounter.
	var/player_attacked
	var/interdicted_by_player = FALSE
	/// Why the NPC retreated, from its blackboard.
	var/retreat_reason
	/// An outcome the state alone can't show, set by the code that knows it.
	var/outcome_hint
	var/tribute = 0
	var/items_paid = 0
	var/siphoned = 0
	var/boarders = 0
	var/waves = 0
	var/boss = FALSE
	var/npc_damage_taken = 0
	var/player_damage_taken = 0

// ========== SHARED HELPERS ==========

/// Zone name of an overmap ship, flying or docked.
/proc/ship_metric_zone(obj/structure/overmap/ship/ship)
	var/turf/overmap_turf = get_turf(ship)
	if(!overmap_turf)
		return null
	return metric_zone_name(SSovermap_zones.get_zone_type_anywhere(overmap_turf))

/// TRUE for a hull still run by the NPC AI. A claimed pirate hull is a player ship.
/proc/ship_metric_is_npc(obj/structure/overmap/ship/ship)
	if(!istype(ship, /obj/structure/overmap/ship/npc))
		return FALSE
	var/obj/structure/overmap/ship/npc/npc_ship = ship
	return !npc_ship.player_controlled

/// TRUE while rows may be written about a ship: metrics are on, it has its shuttle (which gives
/// its id) and its removal row has not been written.
/proc/ship_metric_live(obj/structure/overmap/ship/ship)
	return SSmetrics.accepting && ship?.shuttle && !ship.metric_removed

/// Adds another ship's id and name to a details list, keyed with the given prefix.
/proc/ship_metric_add_ship(list/details, obj/structure/overmap/ship/other, prefix = "player")
	if(other)
		details["[prefix]_ship_id"] = metric_ship_id(other)
		details["[prefix]_ship"] = other.name
	return details

/// Whole seconds since a world.time stamp, or null without one.
/proc/ship_metric_seconds_since(stamp)
	if(!stamp)
		return null
	return round((world.time - stamp) / 10)

/// The ship a player crews, other than `except` (claiming or boarding puts them aboard that one).
/proc/ship_metric_home_ship(mob/player, obj/structure/overmap/ship/except)
	for(var/datum/team/voidcrew/team as anything in player?.mind?.ship_teams)
		if(team.ship && team.ship != except)
			return team.ship
	return null

// ========== PLAYER SHIPS ==========

/// A hull entered the round, with its shuttle attached. Records the commissioning funds.
/proc/ship_metric_spawned(obj/structure/overmap/ship/ship, datum/ship_theme/theme, mob/creator, source)
	if(!ship_metric_live(ship) || ship.metric_spawned_at)
		return
	ship.metric_spawned_at = world.time
	var/list/details = list("roundstart" = !SSticker.HasRoundStarted())
	if(source)
		details["source"] = source
	var/theme_id = theme?.id || ship.theme
	if(theme_id)
		details["theme"] = "[theme_id]"
	var/list/modules = list()
	for(var/slot in ship.upgrade_selections)
		var/datum/ship_upgrade_module/module = ship.upgrade_selections[slot]
		if(istype(module))
			modules += "[module.id]"
	if(length(modules))
		details["modules"] = modules
	var/commissioning = ship.ship_account ? max(ship.starting_credits, 0) : 0
	record_metric(METRIC_SHIP, "ship_spawned", ckey = metric_ckey(creator), ship = ship, zone = ship_metric_zone(ship), subject = ship.source_template?.type, credits = commissioning, details = details)

/// A player launched a hull from the lobby, or was handed a free one.
/proc/ship_metric_purchased(obj/structure/overmap/ship/ship, mob/buyer, requisition = FALSE)
	if(!ship_metric_live(ship))
		return
	record_metric(METRIC_SHIP, requisition ? "ship_requisitioned" : "ship_purchased", ckey = metric_ckey(buyer), ship = ship, zone = ship_metric_zone(ship), subject = ship.source_template?.type)

/// A permanent unlock was bought with ship parts. `waived` when the server gives parts away.
/proc/ship_metric_unlocked(event, mob/buyer, template_type, item_id, list/part_cost, waived = FALSE)
	if(!SSmetrics.accepting)
		return
	var/parts = 0
	var/list/details = list("template" = "[template_type]")
	if(!waived && length(part_cost))
		for(var/part_class in part_cost)
			parts += part_cost[part_class]
		details["parts"] = part_cost.Copy()
	record_metric(METRIC_SHIP, event, ckey = metric_ckey(buyer), subject = item_id || template_type, points = parts, details = details)

/// A hull was unlocked in the lobby. Free hulls come unlocked and cost nothing, so they are skipped.
/proc/ship_metric_hull_unlocked(mob/buyer, datum/map_template/shuttle/voidcrew/template)
	if(!template || is_ship_free(template))
		return
	var/list/cost = list()
	for(var/part_class in template.part_requirements)
		var/count = template.part_requirements[part_class] || 0
		if(count > 0)
			cost[part_class] = count
	ship_metric_unlocked("ship_unlocked", buyer, template.type, null, cost)

/// A mind joined or left a crew roster. Runs after the roster changed, and for a leave, before
/// the mind forgets the team (so a remove for someone who was never aboard is not counted).
/proc/ship_metric_crew_changed(datum/team/voidcrew/team, datum/mind/member, joined)
	var/obj/structure/overmap/ship/ship = team?.ship
	if(!ship_metric_live(ship) || !member?.key)
		return
	if(!joined && !LAZYFIND(member.ship_teams, team))
		return
	record_metric(METRIC_SHIP, joined ? "crew_joined" : "crew_left", ckey = ckey(member.key), ship = ship, zone = ship_metric_zone(ship), subject = member.assigned_role?.title, quantity = length(team.members))

/// Command passed to another crewmember.
/proc/ship_metric_command_changed(obj/structure/overmap/ship/ship, mob/living/new_captain, mob/living/former, reason)
	if(!ship_metric_live(ship))
		return
	record_metric(METRIC_SHIP, "command_changed", ckey = metric_ckey(new_captain), other_ckey = metric_ckey(former), ship = ship, zone = ship_metric_zone(ship), subject = reason)

/// An abandoned hull is being claimed at its helm. Runs before the abandoned state is cleared.
/proc/ship_metric_claimed_abandoned(obj/structure/overmap/ship/ship, mob/living/claimer)
	if(!ship_metric_live(ship))
		return
	if(ship_metric_is_npc(ship))
		npc_metric_claimed(ship, claimer, "abandoned_wreck")
		return
	var/list/details = list("abandoned_seconds" = ship_metric_seconds_since(ship.abandoned_at))
	ship_metric_add_ship(details, ship_metric_home_ship(claimer, ship), "claimer")
	record_metric(METRIC_SHIP, "ship_claimed", ckey = metric_ckey(claimer), ship = ship, zone = ship_metric_zone(ship), details = details)

/// The hull is being abandoned. Runs before its roster is emptied.
/proc/ship_metric_abandoned(obj/structure/overmap/ship/ship)
	if(!ship_metric_live(ship))
		return
	var/list/details = list("age_seconds" = ship_metric_seconds_since(ship.metric_spawned_at))
	if(ship_metric_is_npc(ship))
		record_metric(METRIC_PIRATE, "npc_abandoned", ship = ship, zone = ship_metric_zone(ship), details = details)
		return
	record_metric(METRIC_SHIP, "ship_abandoned", ship = ship, zone = ship_metric_zone(ship), quantity = LAZYLEN(ship.ship_team?.members), details = details)

/// Hull integrity failed and the ship is about to crash-land.
/proc/ship_metric_hull_failed(obj/structure/overmap/ship/ship)
	// Abandonment crashes a flying hull on purpose; ship_abandoned already covers that.
	if(!ship_metric_live(ship) || ship.abandoned)
		return
	var/list/details = list()
	if(ship.metric_last_hit_by_id)
		details["last_hit_by_id"] = ship.metric_last_hit_by_id
		details["last_hit_by"] = ship.metric_last_hit_by_name
		details["last_hit_by_npc"] = ship.metric_last_hit_by_npc
		details["seconds_since_hit"] = ship_metric_seconds_since(ship.metric_last_hit_at)
	if(!ship_metric_is_npc(ship))
		record_metric(METRIC_SHIP, "ship_destroyed", ship = ship, zone = ship_metric_zone(ship), details = details)
		return
	var/obj/structure/overmap/ship/npc/npc_ship = ship
	details["crew_alive"] = npc_ship.count_live_crew_aboard()
	details["damage_taken"] = round(npc_ship.metric_damage_taken)
	var/datum/npc_metric_encounter/encounter = npc_ship.metric_encounter
	if(encounter?.target_id)
		details["player_ship_id"] = encounter.target_id
		details["player_ship"] = encounter.target_name
	record_metric(METRIC_PIRATE, "npc_hull_destroyed", ship = ship, zone = ship_metric_zone(ship), details = details)

/// A failed hull was repaired back into service.
/proc/ship_metric_hull_restored(obj/structure/overmap/ship/ship)
	if(!ship_metric_live(ship) || ship_metric_is_npc(ship))
		return
	record_metric(METRIC_SHIP, "ship_repaired", ship = ship, zone = ship_metric_zone(ship))

/// The helm is about to jump the ship out of the round.
/proc/ship_metric_jumping(obj/structure/overmap/ship/ship, parts_extracted)
	if(!ship)
		return
	ship.metric_removal_reason = "bluespace_jump"
	ship.metric_removal_details = list(
		"parts_extracted" = parts_extracted || 0,
		"crew_aboard" = length(ship.shuttle?.get_all_humans()),
	)

/**
 * The hull is leaving the round: its shuttle is about to be detached. Every removal path
 * (derelict despawn, bluespace jump, deletion) detaches the shuttle first, so this is the last
 * moment the hull still has its id. Closes any open NPC encounter first.
 */
/proc/ship_metric_removed(obj/structure/overmap/ship/ship)
	if(istype(ship, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/watched = ship
		watched.metric_stop_watching() // even with metrics off, so no area refs outlive the hull
	if(!ship_metric_live(ship))
		return
	var/reason = ship.metric_removal_reason
	var/list/details = ship.metric_removal_details ? ship.metric_removal_details.Copy() : list()
	details["age_seconds"] = ship_metric_seconds_since(ship.metric_spawned_at)
	if(ship_metric_is_npc(ship))
		var/obj/structure/overmap/ship/npc/npc_ship = ship
		npc_metric_end_encounter(npc_ship, outcome = "hull_removed")
		if(!reason)
			if(!isnull(npc_ship.disarmed_despawn_at))
				reason = "disarmed_salvage_expired"
			else if(ship.abandoned)
				reason = "derelict_despawned"
			else if(istype(ship, /obj/structure/overmap/ship/npc/pirate/nt_patrol))
				var/obj/structure/overmap/ship/npc/pirate/nt_patrol/patrol = ship
				reason = patrol.warping_out ? "warped_out" : "deleted"
			else
				reason = "deleted"
		details["pool_slot_freed"] = npc_ship.spawner_resolved
		details["encounters"] = npc_ship.metric_encounter_count
		details["damage_taken"] = round(npc_ship.metric_damage_taken)
		details["boarded_by"] = LAZYLEN(npc_ship.metric_boarded_by)
		record_metric(METRIC_PIRATE, "npc_despawned", ship = ship, zone = ship_metric_zone(ship), subject = reason, details = details)
	else
		if(!reason)
			if(ship.abandoned)
				reason = "derelict_despawned"
			// The derelict sweep's fast path for hulls nobody ever crewed
			else if(ship.crewless_since && !length(ship.manifest) && !LAZYLEN(ship.ship_team?.members))
				reason = "never_crewed_despawned"
			else
				reason = "deleted"
		details["crew"] = LAZYLEN(ship.ship_team?.members)
		record_metric(METRIC_SHIP, "ship_removed", ship = ship, zone = ship_metric_zone(ship), subject = reason, details = details)
	ship.metric_removed = TRUE

/// An interdictor on `attacker` forced `target` to dock with it.
/proc/ship_metric_force_docked(obj/structure/overmap/ship/attacker, obj/structure/overmap/ship/target, mob/user)
	if(ship_metric_is_npc(target))
		if(!ship_metric_live(target))
			return
		var/obj/structure/overmap/ship/npc/npc_target = target
		var/list/details = list(
			"crew_alive" = npc_target.count_live_crew_aboard(),
			"disabled" = npc_target.is_disabled,
		)
		ship_metric_add_ship(details, attacker)
		record_metric(METRIC_PIRATE, "npc_force_docked", ckey = metric_ckey(user), ship = target, zone = ship_metric_zone(target), details = details)
		return
	if(!ship_metric_live(attacker))
		return
	record_metric(METRIC_SHIP, "ship_force_docked", ckey = metric_ckey(user), ship = attacker, zone = ship_metric_zone(attacker), details = ship_metric_add_ship(list(), target, "target"))

// ========== SHIP WEAPON HITS ==========

/// A ship laser beam reached its target, on a shield wall or on the hull.
/proc/ship_metric_laser_hit(obj/effect/ship_laser_beam/beam, hit_shield)
	ship_metric_weapon_hit(beam.source_ship, beam.target_ship, "laser", hit_shield ? "shield" : "hull", beam.damage)

/// A ship missile or assault pod struck a shield wall or the hull.
/proc/ship_metric_missile_hit(obj/effect/ship_missile/missile, layer)
	if(missile.exploded && layer == "shield")
		return // already went off; a stray second bump
	var/weapon = istype(missile, /obj/effect/ship_missile/assault_pod) ? "assault_pod" : "missile"
	ship_metric_weapon_hit(missile.source_ship, missile.target_ship, weapon, layer, missile.damage)

/**
 * Tallies one weapon hit and remembers the attacker on the target, for ship_destroyed and
 * npc_hull_destroyed. Hits on outposts and ruins are not counted.
 */
/proc/ship_metric_weapon_hit(obj/structure/overmap/ship/attacker, obj/structure/overmap/target, weapon, layer, damage)
	if(!SSmetrics.accepting || !istype(attacker) || !istype(target, /obj/structure/overmap/ship) || attacker == target)
		return
	var/obj/structure/overmap/ship/target_ship = target
	if(!ship_metric_live(target_ship) || !ship_metric_live(attacker))
		return
	damage = max(damage, 0)
	tally_metric(METRIC_SHIP, "[weapon]_hit_[layer]", ship = attacker, zone = ship_metric_zone(target_ship), subject = metric_ship_id(target_ship), points = damage)
	target_ship.metric_last_hit_by_id = metric_ship_id(attacker)
	target_ship.metric_last_hit_by_name = attacker.name
	target_ship.metric_last_hit_by_npc = ship_metric_is_npc(attacker)
	target_ship.metric_last_hit_at = world.time
	if(istype(target_ship, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_target = target_ship
		npc_target.metric_damage_taken += damage
		if(npc_target.metric_encounter)
			npc_target.metric_encounter.npc_damage_taken += damage
	if(istype(attacker, /obj/structure/overmap/ship/npc))
		var/obj/structure/overmap/ship/npc/npc_attacker = attacker
		if(npc_attacker.metric_encounter?.target_id == metric_ship_id(target_ship))
			npc_attacker.metric_encounter.player_damage_taken += damage

// ========== DATA SIPHONS ==========

/// A siphon run ended with `taken` credits drawn from `target` into `owner`'s siphon.
/proc/siphon_metric_run_ended(obj/structure/overmap/ship/owner, obj/structure/overmap/ship/target, taken)
	if(!SSmetrics.accepting || taken <= 0 || !owner)
		return
	if(ship_metric_is_npc(owner))
		if(!ship_metric_live(owner))
			return
		var/obj/structure/overmap/ship/npc/npc_owner = owner
		if(npc_owner.metric_encounter)
			npc_owner.metric_encounter.siphoned += taken
		record_metric(METRIC_PIRATE, "npc_siphoned_player", ship = owner, zone = target ? ship_metric_zone(target) : ship_metric_zone(owner), credits = taken, details = ship_metric_add_ship(list(), target))
		return
	if(ship_metric_is_npc(target))
		if(!ship_metric_live(target))
			return
		record_metric(METRIC_PIRATE, "npc_hold_siphoned", ship = target, zone = ship_metric_zone(target), credits = -taken, details = ship_metric_add_ship(list(), owner))
		return
	if(!ship_metric_live(owner))
		return
	record_metric(METRIC_SHIP, "ship_siphoned", ship = owner, zone = ship_metric_zone(owner), credits = taken, details = ship_metric_add_ship(list(), target, "target"))

/// A player emptied a siphon into a holochip. Only counted for siphons aboard NPC hulls.
/proc/siphon_metric_looted(obj/machinery/shuttle_scrambler/ship_siphon/siphon, mob/user, amount)
	if(!SSmetrics.accepting || amount <= 0)
		return
	var/obj/structure/overmap/ship/owner = siphon.get_owner_ship()
	if(!ship_metric_is_npc(owner) || !ship_metric_live(owner))
		return
	record_metric(METRIC_PIRATE, "npc_siphon_looted", ckey = metric_ckey(user), ship = owner, zone = ship_metric_zone(owner), credits = -amount, details = ship_metric_add_ship(list(), ship_metric_home_ship(user, owner)))

// ========== NPC SHIPS: LIFECYCLE ==========

/// The hull is loaded, its AI is up and its crew is aboard.
/proc/npc_metric_spawned(obj/structure/overmap/ship/npc/ship)
	if(!ship_metric_live(ship) || ship.metric_spawned_at)
		return
	ship.metric_spawned_at = world.time
	ship.metric_crew_spawned = length(ship.tracked_crew)
	var/list/details = list(
		"hold" = ship.ship_account?.account_balance || 0,
		"pool" = (ship.type in SSnpc_ships.all_factions) ? TRUE : FALSE,
		"replacement" = SSnpc_ships.initialized_pirates ? TRUE : FALSE,
	)
	if(istype(ship, /obj/structure/overmap/ship/npc/pirate))
		var/obj/structure/overmap/ship/npc/pirate/pirate_ship = ship
		if(pirate_ship.pirate_faction)
			details["faction"] = pirate_ship.pirate_faction
	record_metric(METRIC_PIRATE, "npc_spawned", ship = ship, zone = ship_metric_zone(ship), subject = ship.type, quantity = ship.metric_crew_spawned, details = details)
	ship.metric_watch_for_boarders()

/// Watches the hull's rooms for the first player of each crew to come aboard.
/obj/structure/overmap/ship/npc/proc/metric_watch_for_boarders()
	metric_hull_areas = list()
	for(var/area/hull_area as anything in shuttle?.shuttle_areas)
		metric_hull_areas[hull_area] = TRUE
		RegisterSignal(hull_area, COMSIG_AREA_ENTERED, PROC_REF(metric_on_area_entered), override = TRUE)

/// Stops watching for boarders once players own the hull or it leaves the round.
/obj/structure/overmap/ship/npc/proc/metric_stop_watching()
	for(var/area/hull_area as anything in metric_hull_areas)
		UnregisterSignal(hull_area, COMSIG_AREA_ENTERED)
	metric_hull_areas = null

/obj/structure/overmap/ship/npc/proc/metric_on_area_entered(area/source, atom/movable/arrived, area/old_area)
	SIGNAL_HANDLER
	if(player_controlled || !isliving(arrived))
		return
	var/mob/living/visitor = arrived
	if(!visitor.ckey || !metric_hull_areas?[source])
		return
	// Walking between rooms of the hull is not boarding it again
	if(old_area && metric_hull_areas[old_area])
		return
	npc_metric_boarded(src, visitor)

/// A player set foot aboard. Written once per crew.
/proc/npc_metric_boarded(obj/structure/overmap/ship/npc/ship, mob/living/visitor)
	if(!ship_metric_live(ship))
		return
	var/obj/structure/overmap/ship/home = ship_metric_home_ship(visitor, ship)
	var/boarder_key = home ? metric_ship_id(home) : "ckey:[visitor.ckey]"
	if(LAZYACCESS(ship.metric_boarded_by, boarder_key))
		return
	LAZYSET(ship.metric_boarded_by, boarder_key, TRUE)
	var/hull_state = "docked"
	if(ship.has_crash_landed)
		hull_state = "crashed"
	else if(ship.state == OVERMAP_SHIP_FLYING)
		hull_state = "flying"
	var/list/details = list(
		"crew_alive" = ship.count_live_crew_aboard(),
		"hull" = hull_state,
		"disabled" = ship.is_disabled,
	)
	ship_metric_add_ship(details, home)
	record_metric(METRIC_PIRATE, "npc_boarded", ckey = visitor.ckey, ship = ship, zone = ship_metric_zone(ship), details = details)

/// The last of the hull's own crew just died.
/proc/npc_metric_crew_wiped(obj/structure/overmap/ship/npc/ship)
	if(!ship_metric_live(ship) || ship.player_controlled)
		return
	var/list/details = list(
		"crew_spawned" = ship.metric_crew_spawned,
		"age_seconds" = ship_metric_seconds_since(ship.metric_spawned_at),
		"integrity" = ship.get_integrity_percent(),
		"hull_destroyed" = ship.has_crash_landed,
		"disabled" = ship.is_disabled,
		"boarded_by" = LAZYLEN(ship.metric_boarded_by),
	)
	record_metric(METRIC_PIRATE, "npc_crew_wiped", ship = ship, zone = ship_metric_zone(ship), details = details)

/// The hull's pirate pool slot was freed. Runs once, through the pool's own latch.
/proc/npc_metric_resolved(obj/structure/overmap/ship/npc/ship, reason)
	if(!ship_metric_live(ship))
		return
	var/list/details = list(
		"age_seconds" = ship_metric_seconds_since(ship.metric_spawned_at),
		"integrity" = ship.get_integrity_percent(),
		"damage_taken" = round(ship.metric_damage_taken),
	)
	var/pool_zone = metric_zone_name(ship.pool_zone_type)
	if(pool_zone)
		details["pool_zone"] = pool_zone
	record_metric(METRIC_PIRATE, "npc_resolved", ship = ship, zone = ship_metric_zone(ship), subject = reason, details = details)

/// Called on every thrust refresh. Records once, when no real thruster is left aboard.
/proc/npc_metric_check_immobilized(obj/structure/overmap/ship/npc/ship)
	if(ship.metric_immobilized || ship.cached_can_thrust || ship.baseline_engine_parts <= 0 || ship.player_controlled || !ship_metric_live(ship))
		return
	// can_thrust() is also false inside a nebula, under a drive lockout, or out of fuel. Only
	// count it once the thrusters themselves are gone.
	for(var/obj/machinery/power/shuttle_engine/ship/thruster in ship.shuttle.engine_list)
		if(!QDELETED(thruster) && thruster.anchored)
			return
	ship.metric_immobilized = TRUE
	var/list/details = list(
		"integrity" = ship.get_integrity_percent(),
		"damage_taken" = round(ship.metric_damage_taken),
	)
	var/datum/npc_metric_encounter/encounter = ship.metric_encounter
	if(encounter?.target_id)
		details["player_ship_id"] = encounter.target_id
		details["player_ship"] = encounter.target_name
	record_metric(METRIC_PIRATE, "npc_immobilized", ship = ship, zone = ship_metric_zone(ship), details = details)

/// Players are taking the hull. Runs before the claim changes anything.
/proc/npc_metric_claimed(obj/structure/overmap/ship/npc/ship, mob/living/claimer, method)
	if(!ship_metric_live(ship))
		return
	if(!ship_metric_is_npc(ship))
		// Re-claiming a hull players already owned: an ordinary abandoned-ship claim
		var/list/player_details = list("abandoned_seconds" = ship_metric_seconds_since(ship.abandoned_at))
		ship_metric_add_ship(player_details, ship_metric_home_ship(claimer, ship), "claimer")
		record_metric(METRIC_SHIP, "ship_claimed", ckey = metric_ckey(claimer), ship = ship, zone = ship_metric_zone(ship), details = player_details)
		return
	npc_metric_end_encounter(ship, outcome = "hull_claimed")
	ship.metric_stop_watching()
	var/list/details = list(
		"abandoned" = ship.abandoned,
		"disabled" = ship.is_disabled,
		"crew_alive" = ship.count_live_crew_aboard(),
		"hold" = ship.ship_account?.account_balance || 0,
		"age_seconds" = ship_metric_seconds_since(ship.metric_spawned_at),
		"damage_taken" = round(ship.metric_damage_taken),
		"encounters" = ship.metric_encounter_count,
	)
	ship_metric_add_ship(details, ship_metric_home_ship(claimer, ship), "claimer")
	record_metric(METRIC_PIRATE, "npc_claimed", ckey = metric_ckey(claimer), ship = ship, zone = ship_metric_zone(ship), subject = method, details = details)

/// A player interdictor caught the hull.
/proc/npc_metric_interdicted(obj/structure/overmap/ship/npc/ship)
	if(ship?.metric_encounter)
		ship.metric_encounter.interdicted_by_player = TRUE

// ========== NPC SHIPS: ENCOUNTERS ==========

/// A player ship started targeting or locked onto the hull.
/proc/npc_metric_player_aggression(obj/structure/overmap/ship/npc/ship, obj/structure/overmap/ship/aggressor, reason)
	if(!SSmetrics.accepting || !istype(ship) || !istype(aggressor) || ship.player_controlled)
		return
	var/aggressor_id = metric_ship_id(aggressor)
	ship.metric_aggressor_id = aggressor_id
	ship.metric_aggression_at = world.time
	var/datum/npc_metric_encounter/encounter = ship.metric_encounter
	if(encounter && !encounter.player_attacked && encounter.target_id == aggressor_id)
		encounter.player_attacked = reason

/**
 * Every NPC combat state change, from set_combat_state(). Opens an encounter when the NPC
 * takes a target, closes it when the NPC goes idle, is disabled or leaves a wiped crew, and
 * writes the milestones in between.
 */
/proc/npc_metric_combat_state(datum/ai_controller/npc_ship/controller, old_state, new_state)
	var/obj/structure/overmap/ship/npc/ship = controller?.get_ship()
	if(!istype(ship) || ship.player_controlled || !ship_metric_live(ship))
		return
	var/datum/npc_metric_encounter/encounter = ship.metric_encounter

	if(new_state == METRIC_NPC_IDLE || new_state == METRIC_NPC_DISABLED || new_state == METRIC_NPC_DISENGAGING)
		if(new_state == METRIC_NPC_DISABLED)
			var/list/disabled_details = list()
			if(encounter)
				disabled_details["player_ship_id"] = encounter.target_id
				disabled_details["player_ship"] = encounter.target_name
				disabled_details["seconds"] = ship_metric_seconds_since(encounter.started_at)
			record_metric(METRIC_PIRATE, "npc_disabled", ship = ship, zone = ship_metric_zone(ship), details = disabled_details)
		if(encounter)
			npc_metric_end_encounter(ship, controller, old_state, new_state)
		return

	var/obj/structure/overmap/ship/target = controller.get_target()
	if(encounter && target && encounter.target_ref?.resolve() != target)
		npc_metric_end_encounter(ship, controller, old_state, new_state, "switched_target")
		encounter = null
	if(!encounter)
		encounter = npc_metric_start_encounter(ship, controller, target, new_state)
	encounter.states |= new_state

	switch(new_state)
		if(METRIC_NPC_RETREATING)
			encounter.retreat_reason = controller.blackboard[METRIC_BB_RETREAT_REASON]
			var/list/retreat_details = list(
				"seconds" = ship_metric_seconds_since(encounter.started_at),
				"integrity" = ship.get_integrity_percent(),
				"npc_damage_taken" = round(encounter.npc_damage_taken),
			)
			if(encounter.target_id)
				retreat_details["player_ship_id"] = encounter.target_id
				retreat_details["player_ship"] = encounter.target_name
			record_metric(METRIC_PIRATE, "npc_retreated", ship = ship, zone = ship_metric_zone(ship), subject = encounter.retreat_reason, details = retreat_details)
		if(METRIC_NPC_BOARDING)
			// A fresh raid, not the next wave after a break
			if(old_state != METRIC_NPC_BOARDING_COOLDOWN && old_state != METRIC_NPC_BOSS_PHASE)
				var/list/raid_details = list(
					"player_crew" = controller.blackboard[METRIC_BB_BOARDING_CREW] || 0,
					"waves" = controller.get_boarding_wave_count(),
				)
				ship_metric_add_ship(raid_details, target)
				record_metric(METRIC_PIRATE, "npc_raid_started", ship = ship, zone = target ? ship_metric_zone(target) : ship_metric_zone(ship), details = raid_details)

/// Opens an encounter against `target` and writes npc_encounter_start.
/proc/npc_metric_start_encounter(obj/structure/overmap/ship/npc/ship, datum/ai_controller/npc_ship/controller, obj/structure/overmap/ship/target, first_state)
	var/datum/npc_metric_encounter/encounter = new
	ship.metric_encounter = encounter
	encounter.number = ++ship.metric_encounter_count
	encounter.started_at = world.time
	encounter.first_state = first_state
	var/list/details = list("first_state" = first_state, "encounter" = encounter.number)
	if(target)
		encounter.target_ref = WEAKREF(target)
		encounter.target_id = metric_ship_id(target)
		encounter.target_name = target.name
		// The aggression signal handlers note the aggressor just before they set the target
		encounter.player_started = (ship.metric_aggression_at == world.time && ship.metric_aggressor_id == encounter.target_id)
		ship_metric_add_ship(details, target)
		details["player_crew"] = controller.count_living_crew(target)
		details["player_credits"] = target.ship_account?.account_balance || 0
	details["player_started"] = encounter.player_started
	record_metric(METRIC_PIRATE, "npc_encounter_start", ship = ship, zone = target ? ship_metric_zone(target) : ship_metric_zone(ship), details = details)
	return encounter

/// Closes the open encounter, if any, and writes npc_encounter_end. Works out the outcome
/// from the live state unless one is given.
/proc/npc_metric_end_encounter(obj/structure/overmap/ship/npc/ship, datum/ai_controller/npc_ship/controller, old_state, new_state, outcome)
	var/datum/npc_metric_encounter/encounter = ship?.metric_encounter
	if(!encounter)
		return
	ship.metric_encounter = null
	if(!outcome)
		outcome = npc_metric_encounter_outcome(ship, controller, encounter, old_state, new_state)
	var/obj/structure/overmap/ship/target = encounter.target_ref?.resolve()
	var/list/details = list(
		"outcome" = outcome,
		"ended_from" = old_state,
		"states" = encounter.states,
		"seconds" = ship_metric_seconds_since(encounter.started_at),
		"encounter" = encounter.number,
		"player_started" = encounter.player_started,
	)
	if(encounter.target_id)
		details["player_ship_id"] = encounter.target_id
		details["player_ship"] = encounter.target_name
	if(encounter.player_attacked)
		details["player_attacked"] = encounter.player_attacked
	if(encounter.interdicted_by_player)
		details["interdicted_by_player"] = TRUE
	if(encounter.tribute)
		details["tribute"] = encounter.tribute
	if(encounter.items_paid)
		details["items_paid"] = encounter.items_paid
	if(encounter.siphoned)
		details["siphoned"] = encounter.siphoned
	if(encounter.boarders)
		details["boarders"] = encounter.boarders
	if(encounter.waves)
		details["waves"] = encounter.waves
	if(encounter.boss)
		details["boss"] = TRUE
	if(encounter.npc_damage_taken)
		details["npc_damage_taken"] = round(encounter.npc_damage_taken)
	if(encounter.player_damage_taken)
		details["player_damage_taken"] = round(encounter.player_damage_taken)
	var/zone = (target && !QDELETED(target)) ? ship_metric_zone(target) : ship_metric_zone(ship)
	record_metric(METRIC_PIRATE, "npc_encounter_end", ship = ship, zone = zone, subject = outcome, details = details)

/// Reads why an encounter ended off the NPC, its target and the state it ended from.
/proc/npc_metric_encounter_outcome(obj/structure/overmap/ship/npc/ship, datum/ai_controller/npc_ship/controller, datum/npc_metric_encounter/encounter, old_state, new_state)
	if(new_state == METRIC_NPC_DISABLED)
		return "boss_killed"
	if(new_state == METRIC_NPC_DISENGAGING)
		return "player_crew_killed"
	if(encounter.outcome_hint)
		return encounter.outcome_hint
	if(old_state == METRIC_NPC_RETREATING)
		return encounter.retreat_reason == "siphon_goal" ? "left_after_siphon" : "fled"
	if(ship.state != OVERMAP_SHIP_FLYING)
		return "npc_docked_or_crashed"
	var/obj/structure/overmap/ship/target = encounter.target_ref?.resolve()
	if(QDELETED(target))
		return "target_gone"
	if(target.state != OVERMAP_SHIP_FLYING)
		return "target_docked_or_crashed"
	if(target.invisibility > INVISIBILITY_NONE)
		return "target_cloaked"
	if(controller?.target_reached_sanctuary(target))
		return "target_reached_green"
	if(controller?.count_living_crew(target) == 0)
		return "target_crew_dead"
	// Boarding states skip the range checks; the only other way out is the raid being beaten
	if(old_state == METRIC_NPC_BOARDING || old_state == METRIC_NPC_BOARDING_COOLDOWN || old_state == METRIC_NPC_BOSS_PHASE)
		return "raid_repelled"
	if(!ship.has_los_to(target))
		return "target_hidden"
	if(ship.zone_confined && SSovermap_zones.get_zone(get_turf(ship)) != SSovermap_zones.get_zone(get_turf(target)))
		return "target_left_zone"
	if(get_dist(ship, target) > ship.territory_range)
		return "target_out_of_range"
	if(old_state == METRIC_NPC_SCANNING)
		return "scan_found_nothing"
	var/obj/structure/overmap/ship/npc/engaging = target.engaging_pirate_ref?.resolve()
	if(engaging && engaging != ship)
		return "yielded_to_other_pirate"
	return "other"

/// A holopad negotiation ended. Runs before the AI resumes or disengages.
/proc/npc_metric_negotiation_ended(datum/pirate_negotiation/negotiation, success, reason)
	var/obj/structure/overmap/ship/npc/pirate/pirate = negotiation?.pirate_ship
	if(!ship_metric_live(pirate))
		return
	var/outcome = reason
	var/credits_paid = 0
	var/items_paid = 0
	if(success && reason == "payment_complete")
		if(negotiation.demanded_item_quantity > 0 && negotiation.items_received >= negotiation.demanded_item_quantity)
			outcome = "paid_items"
			items_paid = negotiation.items_received
		else
			outcome = "paid_credits"
			credits_paid = negotiation.demanded_credits
		var/datum/npc_metric_encounter/encounter = pirate.metric_encounter
		if(encounter)
			encounter.tribute += credits_paid
			encounter.items_paid += items_paid
			encounter.outcome_hint = "tribute_paid"
	var/list/details = list(
		"demand" = negotiation.demanded_credits,
		"item_demand" = negotiation.demanded_item_name,
		"item_quantity" = negotiation.demanded_item_quantity,
		"items_received" = negotiation.items_received,
		"barter" = negotiation.barter_only,
		"preemptive" = negotiation.preemptive,
		"caught_fleeing" = negotiation.caught_fleeing,
		"seconds" = ship_metric_seconds_since(negotiation.time_started),
	)
	ship_metric_add_ship(details, negotiation.player_ship)
	var/zone = negotiation.player_ship ? ship_metric_zone(negotiation.player_ship) : ship_metric_zone(pirate)
	record_metric(METRIC_PIRATE, "npc_negotiation", ship = pirate, zone = zone, subject = outcome, credits = credits_paid, quantity = items_paid, details = details)

/// A boarding wave landed aboard the target.
/proc/npc_metric_boarding_wave(datum/ai_controller/npc_ship/controller, wave, boarders)
	var/obj/structure/overmap/ship/npc/ship = controller?.get_ship()
	if(!ship_metric_live(ship))
		return
	var/obj/structure/overmap/ship/target = controller.get_target()
	var/datum/npc_metric_encounter/encounter = ship.metric_encounter
	if(encounter)
		encounter.waves = max(encounter.waves, wave)
		encounter.boarders += boarders
	var/list/details = list("wave" = wave, "waves" = controller.get_boarding_wave_count())
	ship_metric_add_ship(details, target)
	record_metric(METRIC_PIRATE, "npc_boarding_wave", ship = ship, zone = target ? ship_metric_zone(target) : ship_metric_zone(ship), subject = "[wave]", quantity = boarders, details = details)

/// A boarding wave was cleared or ran out of time.
/proc/npc_metric_wave_ended(datum/ai_controller/npc_ship/controller, wave, how)
	var/obj/structure/overmap/ship/npc/ship = controller?.get_ship()
	if(!ship_metric_live(ship))
		return
	var/obj/structure/overmap/ship/target = controller.get_target()
	var/list/details = list(
		"wave" = wave,
		"seconds" = ship_metric_seconds_since(controller.blackboard[METRIC_BB_WAVE_START]),
	)
	ship_metric_add_ship(details, target)
	record_metric(METRIC_PIRATE, "npc_boarding_wave_end", ship = ship, zone = target ? ship_metric_zone(target) : ship_metric_zone(ship), subject = how, details = details)

/// The faction boss dropped aboard the target.
/proc/npc_metric_boss_deployed(datum/ai_controller/npc_ship/controller, mob/living/boss)
	var/obj/structure/overmap/ship/npc/ship = controller?.get_ship()
	if(!ship_metric_live(ship))
		return
	var/obj/structure/overmap/ship/target = controller.get_target()
	if(ship.metric_encounter)
		ship.metric_encounter.boss = TRUE
		ship.metric_encounter.boarders += 1
	record_metric(METRIC_PIRATE, "npc_boss_deployed", ship = ship, zone = target ? ship_metric_zone(target) : ship_metric_zone(ship), subject = boss?.type, details = ship_metric_add_ship(list(), target))

/// Boarding pods fired at the target during ship combat.
/proc/npc_metric_pods_fired(obj/structure/overmap/ship/npc/ship, obj/structure/overmap/ship/target, pods)
	if(!ship_metric_live(ship) || !target)
		return
	if(ship.metric_encounter)
		ship.metric_encounter.boarders += pods
	tally_metric(METRIC_PIRATE, "npc_boarding_pods", ship = ship, zone = ship_metric_zone(target), subject = metric_ship_id(target), quantity = pods)

// ========== NPC SHIPS: BOUNTIES ==========

/// Writes a bounty row, about the hull if it is still in the round.
/proc/npc_metric_bounty_row(datum/pirate_bounty/bounty, event, obj/structure/overmap/ship/player_ship, subject, credits = 0, list/details)
	if(!SSmetrics.accepting)
		return
	if(!details)
		details = list()
	var/obj/structure/overmap/ship/npc/target = bounty.get_target_ship()
	if(!ship_metric_live(target))
		target = null
		details["npc_ship"] = bounty.name
	ship_metric_add_ship(details, player_ship)
	var/zone = player_ship ? ship_metric_zone(player_ship) : (target ? ship_metric_zone(target) : null)
	record_metric(METRIC_PIRATE, event, ship = target, zone = zone, subject = subject, credits = credits, details = details)

/proc/npc_metric_bounty_posted(datum/pirate_bounty/bounty)
	npc_metric_bounty_row(bounty, "npc_bounty_posted", subject = bounty.is_heavy_bounty ? "heavy" : "light", details = list("reward" = bounty.reward))

/proc/npc_metric_bounty_accepted(datum/pirate_bounty/bounty, obj/structure/overmap/ship/hunter)
	npc_metric_bounty_row(bounty, "npc_bounty_accepted", hunter, details = list("hunters" = bounty.get_hunter_count()))

/proc/npc_metric_bounty_paid(datum/pirate_bounty/bounty, obj/structure/overmap/ship/winner, paid, list/items)
	var/list/details = list(
		"reward" = bounty.reward,
		"tracking" = winner ? bounty.has_tracking(winner) : FALSE,
		"hunters" = bounty.get_hunter_count(),
	)
	if(length(items))
		details["items"] = items.Copy()
	npc_metric_bounty_row(bounty, "npc_bounty_paid", winner, bounty.is_heavy_bounty ? "heavy" : "light", -paid, details)

/proc/npc_metric_bounty_failed(datum/pirate_bounty/bounty, reason)
	npc_metric_bounty_row(bounty, "npc_bounty_failed", subject = reason, details = list("hunters" = bounty.get_hunter_count()))

#undef METRIC_NPC_IDLE
#undef METRIC_NPC_SCANNING
#undef METRIC_NPC_RETREATING
#undef METRIC_NPC_BOARDING
#undef METRIC_NPC_BOARDING_COOLDOWN
#undef METRIC_NPC_BOSS_PHASE
#undef METRIC_NPC_DISABLED
#undef METRIC_NPC_DISENGAGING
#undef METRIC_BB_RETREAT_REASON
#undef METRIC_BB_BOARDING_CREW
#undef METRIC_BB_WAVE_START
