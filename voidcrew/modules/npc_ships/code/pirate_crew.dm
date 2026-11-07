/**
 * Pirate crews: the shared brain behind NPC ship crews and their boarding parties.
 *
 * One crew per side of an encounter:
 * - a defending crew for an NPC hull (its spawned crew), keyed on the hull;
 * - a raiding crew for a player ship being boarded (every boarder of every wave, from any
 *   pirate), keyed on the ship being boarded.
 *
 * Once alerted, a crew knows where every hostile on its battlefield is, refreshed every few
 * seconds, and sends its hunters after them. Players can dodge but can't hide. The captain
 * and one guard hold the helm until most of the crew is dead. The per-mob behaviour lives in
 * pirate_crew_ai.dm.
 */

/// Defending crews, by REF() of the NPC hull they crew
GLOBAL_LIST_EMPTY(pirate_defending_crews)
/// Raiding crews, by REF() of the ship they are boarding
GLOBAL_LIST_EMPTY(pirate_raiding_crews)

GLOBAL_LIST_INIT(pirate_crew_alert_lines, list(
	"Boarders!",
	"We've got company!",
	"They're aboard! Get them!",
	"Intruders on deck!",
))
GLOBAL_LIST_INIT(pirate_crew_spot_lines, list(
	"There!",
	"Over here!",
	"Found one!",
	"Contact!",
))
GLOBAL_LIST_INIT(pirate_crew_cross_lines, list(
	"Into their ship!",
	"Push through!",
	"Take the ship!",
))
GLOBAL_LIST_INIT(pirate_crew_captain_lines, list(
	"Fine. I'll do it myself.",
))

/// Enlists `recruit` in the crew defending `hull`, making the crew if it has none yet
/proc/pirate_crew_enlist_defender(mob/living/recruit, obj/structure/overmap/ship/hull, role = PIRATE_ROLE_HUNTER)
	if(QDELETED(hull) || !isbasicmob(recruit) || QDELETED(recruit))
		return FALSE
	var/datum/pirate_crew/crew = pirate_crew_of(hull, FALSE)
	if(!crew)
		crew = new(hull, FALSE)
	return crew.enlist(recruit, role)

/// Enlists `recruit` in the raid on `target`, making the raid if there is none yet
/proc/pirate_crew_enlist_raider(mob/living/recruit, obj/structure/overmap/ship/target)
	if(QDELETED(target) || !isbasicmob(recruit) || QDELETED(recruit))
		return FALSE
	var/datum/pirate_crew/crew = pirate_crew_of(target, TRUE)
	if(!crew)
		crew = new(target, TRUE)
	return crew.enlist(recruit, PIRATE_ROLE_HUNTER)

/// The crew defending (or, with `raiding`, boarding) `ship`, if there is one
/proc/pirate_crew_of(obj/structure/overmap/ship/ship, raiding = FALSE)
	if(isnull(ship))
		return null
	var/list/registry = raiding ? GLOB.pirate_raiding_crews : GLOB.pirate_defending_crews
	var/datum/pirate_crew/crew = registry[REF(ship)]
	return QDELETED(crew) ? null : crew

/// The controller a pirate gets when it joins a crew: ranged if it was a ranged trooper
/proc/pirate_crew_controller_type(mob/living/basic/recruit)
	var/datum/ai_controller/current = recruit?.ai_controller
	if(istype(current, /datum/ai_controller/basic_controller/trooper/ranged) || istype(current, /datum/ai_controller/basic_controller/pirate_crew/ranged))
		return /datum/ai_controller/basic_controller/pirate_crew/ranged
	return /datum/ai_controller/basic_controller/pirate_crew

/// What `speaker` says for a PIRATE_BARK_* moment. Faction pirates may carry their own lines.
/proc/pirate_crew_bark_lines(mob/living/speaker, kind)
	var/mob/living/basic/trooper/pirate/faction/faction_pirate = speaker
	if(istype(faction_pirate))
		switch(kind)
			if(PIRATE_BARK_ALERT)
				if(length(faction_pirate.crew_alert_lines))
					return faction_pirate.crew_alert_lines
			if(PIRATE_BARK_SPOT)
				if(length(faction_pirate.crew_spot_lines))
					return faction_pirate.crew_spot_lines
	switch(kind)
		if(PIRATE_BARK_ALERT)
			return GLOB.pirate_crew_alert_lines
		if(PIRATE_BARK_SPOT)
			return GLOB.pirate_crew_spot_lines
		if(PIRATE_BARK_CROSS)
			return GLOB.pirate_crew_cross_lines
		if(PIRATE_BARK_CAPTAIN)
			return GLOB.pirate_crew_captain_lines
	return null

/// The ship whose deck `where` is, if any
/proc/pirate_crew_ship_at(turf/where)
	var/area/shuttle/voidcrew/ship_area = get_area(where)
	if(!istype(ship_area))
		return null
	return ship_area.shuttle_port?.current_ship

/// Space, open space and anything else with no floor to stand on
/proc/pirate_turf_is_void(turf/where)
	return isspaceturf(where) || isopenspaceturf(where) || isgroundlessturf(where)

/// An open floor with nothing dense on it
/proc/pirate_turf_standable(turf/where)
	if(!isfloorturf(where) || where.density)
		return FALSE
	for(var/obj/thing in where)
		if(thing.density)
			return FALSE
	return TRUE

/datum/pirate_crew
	/// The ship whose deck this crew defends, or is raiding
	var/obj/structure/overmap/ship/home_ship
	/// REF(home_ship), kept for the registry after the ship is gone
	var/registry_key
	/// TRUE for a boarding party, FALSE for a hull's own crew
	var/raiding = FALSE
	/// Every member, mob -> PIRATE_ROLE_*
	var/list/members = list()
	/// Where each member spawned or landed, mob -> turf
	var/list/home_turfs = list()
	/// Whether the crew is fighting
	var/alerted = FALSE
	/// world.time a hostile was last known to be on the battlefield
	var/last_hostile_seen = 0
	/// world.time the crew last stood down
	var/calmed_at = 0
	/// Hostile mob -> list(last known turf, world.time it was seen there)
	var/list/known_hostiles = list()
	/// Where the captain stands: next to the hull's helm
	var/turf/post_turf
	/// Where the guard stands, next to the captain
	var/turf/guard_post_turf
	/// Non-captain members at spawn
	var/starting_crew = 0
	/// Set once the captain and the guard have joined the hunt
	var/promoted = FALSE
	/// The areas this crew hunts in, area -> TRUE
	var/list/battlefield_areas = list()
	/// The z-levels those areas are on
	var/list/battlefield_z = list()
	/// Set when the battlefield must be re-read on the next tick
	var/battlefield_dirty = TRUE
	/// Whether the raiding crew has had its arrival line
	var/arrival_barked = FALSE
	COOLDOWN_DECLARE(intel_cooldown)
	COOLDOWN_DECLARE(battlefield_cooldown)
	COOLDOWN_DECLARE(spot_bark_cooldown)
	COOLDOWN_DECLARE(cross_bark_cooldown)

/datum/pirate_crew/New(obj/structure/overmap/ship/ship, raiding = FALSE)
	. = ..()
	home_ship = ship
	src.raiding = raiding
	registry_key = REF(ship)
	var/list/registry = raiding ? GLOB.pirate_raiding_crews : GLOB.pirate_defending_crews
	registry[registry_key] = src
	RegisterSignal(ship, COMSIG_QDELETING, PROC_REF(on_home_ship_deleted))
	RegisterSignals(ship, list(COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_VOIDCREW_SHIP_DOCKED_BY), PROC_REF(on_home_ship_docked))
	if(!raiding)
		RegisterSignal(ship, COMSIG_SHIP_BOARDED, PROC_REF(on_home_ship_boarded))
	refresh_battlefield()
	START_PROCESSING(SSprocessing, src)
	if(raiding)
		// A boarding party is on the attack from the moment it lands
		alerted = TRUE
		last_hostile_seen = world.time
	log_shuttle("PIRATE_CREW: [raiding ? "raid on" : "crew of"] [ship] formed")

/datum/pirate_crew/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	var/list/registry = raiding ? GLOB.pirate_raiding_crews : GLOB.pirate_defending_crews
	if(registry[registry_key] == src)
		registry -= registry_key
	if(home_ship)
		UnregisterSignal(home_ship, list(COMSIG_QDELETING, COMSIG_VOIDCREW_SHIP_DOCKED, COMSIG_VOIDCREW_SHIP_DOCKED_BY, COMSIG_SHIP_BOARDED))
		home_ship = null
	for(var/mob/living/member in members)
		UnregisterSignal(member, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
		var/datum/ai_controller/controller = member.ai_controller
		if(controller?.blackboard[BB_PIRATE_CREW] == src)
			controller.clear_blackboard_key(BB_PIRATE_CREW)
			controller.clear_blackboard_key(BB_PIRATE_HUNT_TARGET)
			controller.can_idle = TRUE
			if(!QDELETED(member))
				controller.reset_ai_status()
	members.Cut()
	home_turfs.Cut()
	for(var/mob/living/hostile in known_hostiles)
		UnregisterSignal(hostile, COMSIG_QDELETING)
	known_hostiles.Cut()
	battlefield_areas.Cut()
	battlefield_z.Cut()
	post_turf = null
	guard_post_turf = null
	return ..()

// ===== MEMBERS =====

/**
 * Takes `recruit` into the crew: swaps it onto the pirate crew controller and gives it its
 * role. A defending crew's first non-captain becomes the guard; a melee recruit takes the
 * job off a ranged guard while the crew is still calm.
 */
/datum/pirate_crew/proc/enlist(mob/living/basic/recruit, role = PIRATE_ROLE_HUNTER)
	if(QDELETED(recruit) || recruit.stat == DEAD)
		return FALSE
	if(raiding || isnull(role))
		role = PIRATE_ROLE_HUNTER
	var/already_member = !isnull(members[recruit])
	if(!already_member)
		home_turfs[recruit] = get_turf(recruit)
	if(!attach_controller(recruit, role))
		if(!already_member)
			home_turfs -= recruit
		return FALSE
	if(!already_member)
		RegisterSignal(recruit, COMSIG_LIVING_DEATH, PROC_REF(on_member_lost))
		RegisterSignal(recruit, COMSIG_QDELETING, PROC_REF(on_member_lost))
		if(!raiding && role != PIRATE_ROLE_CAPTAIN)
			starting_crew++
	set_role(recruit, role)
	if(role == PIRATE_ROLE_CAPTAIN)
		setup_post(recruit)
	else if(!raiding)
		consider_guard(recruit)
	if(raiding && !arrival_barked)
		arrival_barked = TRUE
		bark(recruit, PIRATE_BARK_CROSS)
	return TRUE

/// Puts `member` on a pirate crew controller wired to this crew. Returns the controller.
/datum/pirate_crew/proc/attach_controller(mob/living/basic/member, role)
	var/datum/ai_controller/basic_controller/pirate_crew/controller = swap_basic_ai_controller(member, pirate_crew_controller_type(member))
	if(!istype(controller))
		return null
	// A member handed over from another crew starts this crew's bookkeeping afresh
	if(controller.blackboard[BB_PIRATE_CREW] != src)
		controller.last_battlefield_turf = null
		controller.clear_blackboard_key(BB_PIRATE_HUNT_TARGET)
		controller.clear_blackboard_key(BB_PIRATE_HUNT_TURF)
		controller.clear_blackboard_key(BB_PIRATE_WAYPOINT)
	controller.set_blackboard_key(BB_PIRATE_CREW, src)
	controller.set_blackboard_key(BB_PIRATE_ROLE, role)
	var/turf/home = home_turfs[member]
	if(home)
		controller.set_blackboard_key(BB_PIRATE_HOME_TURF, home)
	if(alerted)
		wake(controller)
	return controller

/datum/pirate_crew/proc/set_role(mob/living/member, role)
	members[member] = role
	member.ai_controller?.set_blackboard_key(BB_PIRATE_ROLE, role)

/// The member holding `role`, if any
/datum/pirate_crew/proc/role_holder(role)
	for(var/mob/living/member in members)
		if(members[member] == role)
			return member
	return null

/datum/pirate_crew/proc/consider_guard(mob/living/recruit)
	var/mob/living/guard = role_holder(PIRATE_ROLE_GUARD)
	if(!guard)
		set_role(recruit, PIRATE_ROLE_GUARD)
		return
	if(alerted || guard == recruit)
		return
	if(pirate_crew_is_ranged(guard) && !pirate_crew_is_ranged(recruit))
		set_role(guard, PIRATE_ROLE_HUNTER)
		set_role(recruit, PIRATE_ROLE_GUARD)

/// Whether `member` fights at range
/proc/pirate_crew_is_ranged(mob/living/member)
	return istype(member?.ai_controller, /datum/ai_controller/basic_controller/pirate_crew/ranged)

/datum/pirate_crew/proc/on_member_lost(mob/living/source)
	SIGNAL_HANDLER
	remove_member(source)

/datum/pirate_crew/proc/remove_member(mob/living/member)
	if(isnull(members[member]))
		return
	UnregisterSignal(member, list(COMSIG_LIVING_DEATH, COMSIG_QDELETING))
	members -= member
	home_turfs -= member
	if(!length(members))
		qdel(src)

/// Whether `member` stands at the helm rather than hunting
/datum/pirate_crew/proc/holds_post(mob/living/member)
	if(raiding || promoted || !post_turf)
		return FALSE
	var/role = members[member]
	return role == PIRATE_ROLE_CAPTAIN || role == PIRATE_ROLE_GUARD

/// The turf `member` holds while it holds the post
/datum/pirate_crew/proc/post_for(mob/living/member)
	if(members[member] == PIRATE_ROLE_GUARD)
		return guard_post_turf || post_turf
	return post_turf

/// Where `member` goes back to when the crew stands down
/datum/pirate_crew/proc/rest_turf_for(mob/living/member)
	var/role = members[member]
	if(role == PIRATE_ROLE_CAPTAIN || role == PIRATE_ROLE_GUARD)
		var/turf/post = post_for(member)
		if(post)
			return post
	return home_turfs[member]

// ===== THE POST =====

/// The captain's post: the floor in front of the hull's helm, else any floor beside it, else where the captain spawned
/datum/pirate_crew/proc/setup_post(mob/living/captain)
	post_turf = find_post_turf() || get_turf(captain)
	guard_post_turf = null
	if(!post_turf)
		return
	for(var/dir in GLOB.alldirs)
		var/turf/beside = get_step(post_turf, dir)
		if(pirate_turf_standable(beside) && on_home_deck(beside))
			guard_post_turf = beside
			break

/datum/pirate_crew/proc/find_post_turf()
	var/list/hull_areas = home_ship?.shuttle?.shuttle_areas
	if(!length(hull_areas))
		return null
	var/obj/machinery/computer/helm/helm
	for(var/obj/machinery/computer/helm/console in home_ship.helm_consoles)
		if(hull_areas[get_area(console)])
			helm = console
			break
	if(!helm)
		for(var/area/hull_area in hull_areas)
			helm = locate(/obj/machinery/computer/helm) in hull_area
			if(helm)
				break
	if(!helm)
		return null
	var/list/candidates = list(get_step(helm, helm.dir))
	for(var/dir in GLOB.alldirs)
		candidates |= get_step(helm, dir)
	for(var/turf/candidate in candidates)
		if(pirate_turf_standable(candidate) && hull_areas[get_area(candidate)])
			return candidate
	return null

/// Whether `where` is on the deck of the crew's own ship
/datum/pirate_crew/proc/on_home_deck(turf/where)
	var/list/hull_areas = home_ship?.shuttle?.shuttle_areas
	return where && length(hull_areas) && hull_areas[get_area(where)]

// ===== BATTLEFIELD =====

/**
 * The battlefield: the crew's own ship and, for a hull's crew, every other ship berthed with it
 * at a ship-to-ship meeting point. A raid's battlefield is the boarded ship alone, so boarders
 * never follow anyone off it.
 */
/datum/pirate_crew/proc/refresh_battlefield()
	battlefield_dirty = FALSE
	COOLDOWN_START(src, battlefield_cooldown, PIRATE_CREW_BATTLEFIELD_INTERVAL)
	battlefield_areas = list()
	battlefield_z = list()
	if(QDELETED(home_ship))
		return
	add_ship_to_battlefield(home_ship)
	if(raiding || !istype(home_ship.docked, /obj/structure/overmap/planet/empty))
		return
	for(var/obj/structure/overmap/ship/other in SSovermap.simulated_ships)
		if(other != home_ship && other.docked == home_ship.docked)
			add_ship_to_battlefield(other)

/datum/pirate_crew/proc/add_ship_to_battlefield(obj/structure/overmap/ship/ship)
	if(!ship.shuttle)
		return
	for(var/area/ship_area in ship.shuttle.shuttle_areas)
		battlefield_areas[ship_area] = TRUE
	var/turf/port_turf = get_turf(ship.shuttle)
	if(port_turf)
		battlefield_z |= port_turf.z

/datum/pirate_crew/proc/turf_on_battlefield(turf/where)
	if(!where || !(where.z in battlefield_z))
		return FALSE
	return !!battlefield_areas[where.loc]

// ===== HOSTILES AND INTEL =====

/// A member to judge factions and sight by
/datum/pirate_crew/proc/reference_member()
	for(var/mob/living/member in members)
		if(!QDELETED(member) && member.stat != DEAD)
			return member
	return null

/**
 * Whether `player` is someone this crew hunts: a living player on the battlefield, in a mech or
 * not, who is no friend of the pirates and not hidden from them.
 */
/datum/pirate_crew/proc/is_hostile(mob/living/player, mob/living/viewer)
	if(QDELETED(player) || !isliving(player) || player.stat == DEAD || !GET_CLIENT(player))
		return FALSE
	if(HAS_TRAIT(player, TRAIT_GODMODE))
		return FALSE
	if(!turf_on_battlefield(get_turf(player)))
		return FALSE
	viewer ||= reference_member()
	if(viewer)
		if(viewer.faction_check_atom(player))
			return FALSE
		if(viewer.see_invisible < player.invisibility)
			return FALSE
	return TRUE

/datum/pirate_crew/proc/hostile_on_battlefield()
	var/mob/living/viewer = reference_member()
	for(var/mob/living/player in GLOB.alive_player_list)
		if(is_hostile(player, viewer))
			return TRUE
	return FALSE

/// Records that `hostile` was at `where` just now
/datum/pirate_crew/proc/note_hostile(mob/living/hostile, turf/where)
	if(!where)
		return
	if(isnull(known_hostiles[hostile]))
		RegisterSignal(hostile, COMSIG_QDELETING, PROC_REF(on_hostile_deleted))
	known_hostiles[hostile] = list(where, world.time)
	last_hostile_seen = world.time

/datum/pirate_crew/proc/forget_hostile(mob/living/hostile)
	if(isnull(known_hostiles[hostile]))
		return
	UnregisterSignal(hostile, COMSIG_QDELETING)
	known_hostiles -= hostile

/datum/pirate_crew/proc/on_hostile_deleted(mob/living/source)
	SIGNAL_HANDLER
	forget_hostile(source)

/// Where `hostile` was last known to be, if the crew knows of it
/datum/pirate_crew/proc/last_known_turf(mob/living/hostile)
	if(isnull(hostile))
		return null
	var/list/info = known_hostiles[hostile]
	return info ? info[1] : null

/// A member saw `target` at `where`, or was hurt by it
/datum/pirate_crew/proc/report_sighting(atom/target, turf/where)
	if(ismecha(target))
		var/obj/vehicle/sealed/mecha/mech = target
		for(var/mob/living/occupant in mech.occupants)
			report_sighting(occupant, where)
		return
	if(isliving(target) && is_hostile(target))
		note_hostile(target, where || get_turf(target))

/// Re-reads every hostile's position and hands out the hunts
/datum/pirate_crew/proc/refresh_intel()
	COOLDOWN_START(src, intel_cooldown, PIRATE_CREW_INTEL_INTERVAL)
	var/mob/living/viewer = reference_member()
	for(var/mob/living/hostile in known_hostiles.Copy())
		if(!is_hostile(hostile, viewer))
			forget_hostile(hostile)
	for(var/mob/living/player in GLOB.alive_player_list)
		if(is_hostile(player, viewer))
			note_hostile(player, get_turf(player))
	assign_hunts()

/**
 * Sends each hunter after the nearest known hostile. With two or more hostiles known, none of
 * them draws more than ceil(hunters / hostiles) + 1 hunters, so the crew spreads out.
 */
/datum/pirate_crew/proc/assign_hunts()
	var/list/hunters = list()
	for(var/mob/living/member in members)
		if(QDELETED(member) || member.stat == DEAD || !member.ai_controller)
			continue
		if(holds_post(member))
			member.ai_controller.clear_blackboard_key(BB_PIRATE_HUNT_TARGET)
			continue
		hunters += member
	var/list/quarry = list()
	for(var/mob/living/hostile in known_hostiles)
		quarry += hostile
	if(!length(quarry))
		for(var/mob/living/hunter as anything in hunters)
			hunter.ai_controller.clear_blackboard_key(BB_PIRATE_HUNT_TARGET)
		return
	var/cap = length(quarry) > 1 ? ROUND_UP(length(hunters) / length(quarry)) + 1 : INFINITY
	var/list/assigned = list()
	for(var/mob/living/hostile as anything in quarry)
		assigned[hostile] = 0
	for(var/mob/living/hunter as anything in hunters)
		var/turf/from = get_turf(hunter)
		var/mob/living/best
		var/best_dist = INFINITY
		for(var/mob/living/hostile as anything in quarry)
			if(assigned[hostile] >= cap)
				continue
			var/turf/known = last_known_turf(hostile)
			var/dist = (from && known && from.z == known.z) ? get_dist(from, known) : 1000
			if(dist < best_dist)
				best = hostile
				best_dist = dist
		best ||= quarry[1]
		assigned[best] += 1
		hunter.ai_controller.set_blackboard_key(BB_PIRATE_HUNT_TARGET, best)

// ===== ALERT AND CALM =====

/// Puts the crew on alert. `speaker` raises it, if given.
/datum/pirate_crew/proc/raise_alert(mob/living/speaker)
	last_hostile_seen = world.time
	if(alerted)
		return
	alerted = TRUE
	for(var/mob/living/member in members)
		wake(member.ai_controller)
	log_shuttle("PIRATE_CREW: crew of [home_ship] alerted")
	if(!raiding)
		if(QDELETED(speaker) || speaker.stat != CONSCIOUS || isnull(members[speaker]))
			speaker = reference_member()
		bark(speaker, PIRATE_BARK_ALERT)
	COOLDOWN_START(src, spot_bark_cooldown, PIRATE_CREW_SPOT_BARK_CREW)
	refresh_intel()

/// Keeps `controller` running even with nobody close by
/datum/pirate_crew/proc/wake(datum/ai_controller/controller)
	if(!controller)
		return
	controller.can_idle = FALSE
	controller.reset_ai_status()

/// Stands the crew down; members walk back to their posts and spawn points
/datum/pirate_crew/proc/calm()
	alerted = FALSE
	calmed_at = world.time
	for(var/mob/living/hostile in known_hostiles.Copy())
		forget_hostile(hostile)
	for(var/mob/living/member in members)
		var/datum/ai_controller/controller = member.ai_controller
		if(!controller)
			continue
		controller.clear_blackboard_key(BB_PIRATE_HUNT_TARGET)
		controller.clear_blackboard_key(BB_PIRATE_HUNT_TURF)
		controller.clear_blackboard_key(BB_PIRATE_WAYPOINT)
	log_shuttle("PIRATE_CREW: crew of [home_ship] stood down")

/// While calm, lets each member idle again once it's back home
/datum/pirate_crew/proc/settle_members()
	for(var/mob/living/member in members)
		var/datum/ai_controller/controller = member.ai_controller
		if(!controller || controller.can_idle)
			continue
		var/turf/rest = rest_turf_for(member)
		if(!rest || rest.z != member.z || get_dist(member, rest) <= PIRATE_CREW_IDLE_LEASH || world.time > calmed_at + PIRATE_CREW_SETTLE_TIMEOUT)
			controller.can_idle = TRUE
			controller.reset_ai_status()

/// The captain and the guard join the hunt once the rest of the crew is mostly dead
/datum/pirate_crew/proc/check_promotion()
	if(promoted || raiding)
		return
	var/living = 0
	for(var/mob/living/member in members)
		if(members[member] != PIRATE_ROLE_CAPTAIN && member.stat != DEAD)
			living++
	if(living > min(starting_crew / 3, 1))
		return
	promoted = TRUE
	bark(role_holder(PIRATE_ROLE_CAPTAIN), PIRATE_BARK_CAPTAIN)
	assign_hunts()

// ===== BARKS =====

/datum/pirate_crew/proc/bark(mob/living/speaker, kind)
	if(QDELETED(speaker) || speaker.stat != CONSCIOUS)
		return FALSE
	var/list/lines = pirate_crew_bark_lines(speaker, kind)
	if(!length(lines))
		return FALSE
	INVOKE_ASYNC(speaker, TYPE_PROC_REF(/atom/movable, say), message = pick(lines), forced = "pirate crew")
	return TRUE

/// `member` saw `target`: tell the crew, and maybe shout about it
/datum/pirate_crew/proc/on_member_spotted(mob/living/member, atom/target)
	report_sighting(target, get_turf(target))
	if(!alerted)
		raise_alert(member)
		return
	last_hostile_seen = world.time
	var/datum/ai_controller/basic_controller/pirate_crew/controller = member.ai_controller
	if(!istype(controller))
		return
	if(!COOLDOWN_FINISHED(src, spot_bark_cooldown) || !COOLDOWN_FINISHED(controller, spot_bark_cooldown))
		return
	if(bark(member, PIRATE_BARK_SPOT))
		COOLDOWN_START(src, spot_bark_cooldown, PIRATE_CREW_SPOT_BARK_CREW)
		COOLDOWN_START(controller, spot_bark_cooldown, PIRATE_CREW_SPOT_BARK_MOB)

/// `member` stepped onto another ship's deck
/datum/pirate_crew/proc/on_member_crossed(mob/living/member)
	if(!COOLDOWN_FINISHED(src, cross_bark_cooldown))
		return
	if(bark(member, PIRATE_BARK_CROSS))
		COOLDOWN_START(src, cross_bark_cooldown, PIRATE_CREW_CROSS_BARK_CREW)

// ===== PROCESSING =====

/datum/pirate_crew/process(seconds_per_tick)
	if(QDELETED(home_ship) || !length(members))
		qdel(src)
		return PROCESS_KILL
	if(battlefield_dirty || COOLDOWN_FINISHED(src, battlefield_cooldown))
		refresh_battlefield()
	check_members()
	if(QDELETED(src))
		return PROCESS_KILL
	if(!alerted)
		if(hostile_on_battlefield())
			raise_alert()
		else
			settle_members()
		return
	if(COOLDOWN_FINISHED(src, intel_cooldown))
		refresh_intel()
	check_promotion()
	if(!raiding && world.time > last_hostile_seen + PIRATE_CREW_CALM_DELAY)
		calm()

/**
 * Puts back any member whose controller something else replaced (the zone weapon ladder can
 * swap a trooper's controller after a late zone read), and hands defenders stranded aboard a
 * ship that is no longer berthed with their hull to the raid on that ship.
 */
/datum/pirate_crew/proc/check_members()
	var/list/stranded = list()
	for(var/mob/living/basic/member in members)
		if(QDELETED(member) || member.stat == DEAD || GET_CLIENT(member))
			continue
		var/datum/ai_controller/controller = member.ai_controller
		if(controller && !istype(controller, /datum/ai_controller/basic_controller/pirate_crew))
			attach_controller(member, members[member])
		if(raiding)
			continue
		var/turf/where = get_turf(member)
		if(!where || turf_on_battlefield(where))
			continue
		var/obj/structure/overmap/ship/other = pirate_crew_ship_at(where)
		if(other && other != home_ship)
			stranded[member] = other
	for(var/mob/living/basic/member as anything in stranded)
		var/obj/structure/overmap/ship/other = stranded[member]
		remove_member(member)
		pirate_crew_enlist_raider(member, other)
		if(QDELETED(src))
			return

// ===== HOME SHIP SIGNALS =====

/datum/pirate_crew/proc/on_home_ship_deleted(datum/source)
	SIGNAL_HANDLER
	qdel(src)

/datum/pirate_crew/proc/on_home_ship_docked(datum/source)
	SIGNAL_HANDLER
	battlefield_dirty = TRUE

/// A player assault pod hit the hull
/datum/pirate_crew/proc/on_home_ship_boarded(datum/source, atom/pod, obj/structure/overmap/ship/attacker)
	SIGNAL_HANDLER
	raise_alert()
