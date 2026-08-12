/**
 * # Combat Objectives
 *
 * Killing things for money: the named proof-of-kill hunt, and the open
 * suppression counter.
 */

// =========================================================================
// FIELD OBJECTIVE MIXIN: steps that place things inside the mission target
// =========================================================================

/**
 * Shared base for objectives that spawn something physical inside the
 * mission's target site (named targets, quest items, pylons, survivors).
 * On activation it spawns immediately if the site's interior is loaded,
 * otherwise it asks the target to call back when a ship docks and the
 * interior comes up. A retarget reset clears the spawned flag so the fresh
 * site gets armed again.
 */
/datum/mission_objective/field
	/// Whether the field spawn has happened at the current target
	var/spawned = FALSE
	/// How many times the site has refused to hand over a spawn turf
	var/spawn_attempts = 0

/datum/mission_objective/field/activate()
	. = ..()
	arm()

/datum/mission_objective/field/reset()
	. = ..()
	spawned = FALSE
	spawn_attempts = 0

/// Spawns now if possible, otherwise waits for the interior to load
/datum/mission_objective/field/proc/arm()
	var/datum/mission_target/target = mission?.target
	if(spawned || !target || !target.is_valid())
		return
	if(target.is_interior_loaded())
		do_field_spawn()
	else
		target.notify_when_loaded()

/// The mission relays the target's interior-loaded callback here
/datum/mission_objective/field/proc/on_interior_loaded()
	if(!spawned && active)
		do_field_spawn()

/**
 * Places this objective's things at the site.
 *
 * A site that can't offer a clear turf right now is not a site that never
 * can, the sampler rejects blocked and closed tiles, and a ruin, a landed
 * ship or a passing storm can hold every roll it makes. Bailing out silently
 * (which is what this used to do) leaves the contract live on the board with
 * nothing in the world to find and no beacon to follow: the crew flies out,
 * searches the whole planet, taps a GPS on the board and gets an empty list,
 * and the only thing that ever ends it is the 35-minute timeout. Retry, then
 * fail loudly enough to show up in a round's logs.
 */
/datum/mission_objective/field/proc/do_field_spawn()
	if(spawned)
		return
	var/turf/spawn_turf = mission?.target?.get_spawn_turf()
	if(!spawn_turf)
		spawn_attempts++
		if(spawn_attempts < MISSION_FIELD_SPAWN_TRIES)
			addtimer(CALLBACK(src, PROC_REF(retry_field_spawn)), MISSION_FIELD_SPAWN_RETRY_DELAY)
			return
		stack_trace("[mission?.type || "?"]: [type] could not find a spawn turf at [mission?.target?.type || "no target"] in [spawn_attempts] attempts - the contract had nothing to find")
		mission?.fail("Site survey can't place the objective - contract void.")
		return
	spawned = TRUE
	spawn_field_objects(spawn_turf)

/// Timed re-attempt at a site that had no clear turf a moment ago
/datum/mission_objective/field/proc/retry_field_spawn()
	if(spawned || !active || !mission || mission.failed || mission.completed)
		return
	if(!mission.target?.is_interior_loaded())
		// The site unloaded out from under the retry - wait for it to come back
		// rather than burning attempts on a place that isn't there
		spawn_attempts--
		mission.target?.notify_when_loaded()
		return
	do_field_spawn()

/// Actually places this objective's things. Override.
/datum/mission_objective/field/proc/spawn_field_objects(turf/spawn_turf)
	return

/**
 * Marks a mob the contract can't finish without, so the planet's fauna sweep
 * leaves it alone (SSplanet_mobs clears every unclaimed living mob off an empty
 * planet after its grace period, and does not know a mission put this one here).
 * Untracked flavour mobs (entourage guards, caged critters) are deliberately
 * NOT marked: losing those costs nothing and they should age out like any other
 * wildlife.
 */
/datum/mission_objective/field/proc/protect_field_mob(mob/living/protected)
	if(QDELETED(protected))
		return
	ADD_TRAIT(protected, TRAIT_MISSION_FIELD_MOB, INNATE_TRAIT)

/// Open turfs near a spot for scattering extra spawns
/datum/mission_objective/field/proc/get_nearby_open_turf(turf/around, radius = 2)
	var/list/open_turfs = list()
	for(var/turf/open/tile in RANGE_TURFS(radius, around))
		if(!tile.is_blocked_turf(exclude_mobs = TRUE))
			open_turfs += tile
	return length(open_turfs) ? pick(open_turfs) : around

// =========================================================================
// NAMED KILL, hunt the name, bring back the tag
// =========================================================================

/datum/mission_objective/field/kill_named
	/// Mob typepath of the target (set by the mission at generation)
	var/target_mob_type
	/// Guard typepaths spawned around the target (may repeat; may be empty)
	var/list/guard_types
	/// Whether the named target is dead (the proof tag exists)
	var/target_killed = FALSE
	/// The live target, while they're alive
	var/mob/living/target_mob

/datum/mission_objective/field/kill_named/deactivate()
	if(target_mob)
		UnregisterSignal(target_mob, COMSIG_LIVING_DEATH)
		target_mob = null
	return ..()

/datum/mission_objective/field/kill_named/reset()
	. = ..()
	target_killed = FALSE
	target_mob = null

/datum/mission_objective/field/kill_named/spawn_field_objects(turf/spawn_turf)
	var/mob/living/target = new target_mob_type(spawn_turf)
	target.name = mission.objective_name
	target.desc += " They look like they're worth something dead."
	target_mob = target
	protect_field_mob(target)
	RegisterSignal(target, COMSIG_LIVING_DEATH, PROC_REF(on_target_death))
	mission.register_quest_atom(target)
	// The entourage: untracked muscle around the target. Killing them pays
	// nothing - the contract is the name on the tag.
	for(var/guard_type in guard_types)
		var/mob/living/guard = new guard_type(get_nearby_open_turf(spawn_turf))
		guard.desc += " They're on somebody's payroll."

/**
 * The target died: drop the proof item, track it instead, and advance.
 */
/datum/mission_objective/field/kill_named/proc/on_target_death(mob/living/source, gibbed)
	SIGNAL_HANDLER
	if(target_killed || !mission || mission.failed || mission.completed)
		return
	target_killed = TRUE
	UnregisterSignal(source, COMSIG_LIVING_DEATH)
	target_mob = null

	var/obj/item/mission_recovery/proof/proof = new(source.drop_location())
	proof.name = "[mission.objective_name]'s identification tag"
	mission.bind_item(proof)
	mission.register_quest_atom(proof)

	notify_crew("[mission.objective_name] eliminated. Recover the identification tag and return it to the mission pad.")
	complete()

/datum/mission_objective/field/kill_named/get_progress_string()
	if(!spawned)
		return "Track down the target"
	return "Eliminate [mission?.objective_name || "the target"]"

// =========================================================================
// KILL COUNT, suppression sweeps
// =========================================================================

/**
 * Counts qualifying hostile deaths anywhere in the galaxy: right mob family,
 * dangerous-enough zone, and attributable to the servant crew (the killer's
 * ckey, or a living crew member close enough to confirm the kill). No
 * turn-in item - the mission auto-completes like a survey.
 */
/datum/mission_objective/kill_count
	/// Base typepath of mobs that count
	var/mob_base_type = /mob/living/basic/trooper/pirate/faction
	/// Minimum zone the kill must happen in (design guard: no green farming)
	var/minimum_zone = ZONE_YELLOW
	/// Kills required / confirmed
	var/required_kills = 8
	var/kill_count = 0
	/// How close (tiles) a living crew member must be to confirm a kill
	var/confirm_range = 9

/datum/mission_objective/kill_count/reset()
	. = ..()
	kill_count = 0

/datum/mission_objective/kill_count/activate()
	. = ..()
	RegisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH, PROC_REF(on_any_death))

/datum/mission_objective/kill_count/deactivate()
	UnregisterSignal(SSdcs, COMSIG_GLOB_MOB_DEATH)
	return ..()

/datum/mission_objective/kill_count/proc/on_any_death(datum/source, mob/living/victim, gibbed)
	SIGNAL_HANDLER
	if(completed || !istype(victim, mob_base_type))
		return
	var/turf/where = get_turf(victim)
	if(!where)
		return
	var/zone_type = SSovermap_zones?.get_zone_type_anywhere(where)
	if(isnull(zone_type) || zone_type < minimum_zone)
		return
	if(!kill_attributable_to_crew(victim, where))
		return
	kill_count++
	if(kill_count >= required_kills)
		notify_crew("Suppression quota met ([kill_count]/[required_kills]). Return to the mission board to collect payment.")
		complete()
		return
	notify_crew("Kill confirmed: [kill_count]/[required_kills].", sound = 'voidcrew/sound/notify2.ogg')

/**
 * Whether this kill belongs to the servant crew: the last attacker's ckey is
 * a crew member's, or a living crew member is close enough to have done it
 * (covers gunfire and environmental kills, which never set attacker ckeys).
 */
/datum/mission_objective/kill_count/proc/kill_attributable_to_crew(mob/living/victim, turf/where)
	var/obj/structure/overmap/ship/ship = get_servant()
	var/datum/team/crew_team = ship?.ship_team
	if(!crew_team)
		return FALSE
	for(var/datum/mind/member as anything in crew_team.members)
		var/mob/living/crew_mob = member?.current
		if(!istype(crew_mob) || crew_mob.stat == DEAD)
			continue
		if(victim.lastattackerckey && crew_mob.ckey == victim.lastattackerckey)
			return TRUE
		if(crew_mob.z == where.z && get_dist(crew_mob, victim) <= confirm_range)
			return TRUE
	return FALSE

/datum/mission_objective/kill_count/get_progress_string()
	return "[kill_count]/[required_kills] kills confirmed"
