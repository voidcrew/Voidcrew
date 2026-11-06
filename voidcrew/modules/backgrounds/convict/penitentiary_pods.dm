/**
 * # Escape pods
 *
 * A pod is the hidden two-seat escape_pod hull, spawned on demand 10 to 20 overmap tiles from the
 * Penitentiary on a random bearing, on a square with nothing on it: by a launch console in
 * the pod bay, or for the Adrift start. Never docked in a berth, never allowed back. A
 * convict gets one pod out at a time and two a round; a pod nobody living has been aboard
 * for BACKGROUND_POD_SCUTTLE_TIME goes, through the derelict teardown so a site it is docked at is
 * let go. Pods are never seated through AttemptSpawnOnShip(), so they grant no Ship Management,
 * and the Mutiny goal never counts them.
 */

/// The pod's battery at launch: a quarter of a ship SMES. The pod map sets it as the SMES's charge var-edit.
#define PENITENTIARY_POD_CHARGE (5 * STANDARD_BATTERY_CHARGE)

/// ckey -> weakref to the last pod that convict took out
GLOBAL_LIST_EMPTY(penitentiary_last_pods)
/// Weakref to every live pod -> world.time it was first seen with nobody living aboard (0 while someone is)
GLOBAL_LIST_EMPTY(penitentiary_pods)

/// A random overmap square BACKGROUND_POD_DISTANCE_MIN to _MAX tiles from the Penitentiary with no overmap object on it, or null
/proc/penitentiary_pod_turf()
	var/turf/center = get_turf(GLOB.penitentiary)
	if(!center)
		return null
	for(var/attempt in 1 to 40)
		var/distance = rand(BACKGROUND_POD_DISTANCE_MIN, BACKGROUND_POD_DISTANCE_MAX)
		var/bearing = rand(0, 359)
		var/x = clamp(round(center.x + distance * cos(bearing)), OVERMAP_LEFT_SIDE_COORD + 1, OVERMAP_RIGHT_SIDE_COORD - 1)
		var/y = clamp(round(center.y + distance * sin(bearing)), OVERMAP_SOUTH_SIDE_COORD + 1, OVERMAP_NORTH_SIDE_COORD - 1)
		var/turf/spot = locate(x, y, center.z)
		if(!spot || get_dist(spot, center) < BACKGROUND_POD_DISTANCE_MIN)
			continue
		if(locate(/obj/structure/overmap) in spot)
			continue
		return spot
	return null

/// Pods this ckey has taken out this round
/proc/penitentiary_pods_used(ckey)
	if(!ckey)
		return 0
	var/list/ledger = convict_ledger(ckey)
	return ledger["pods"] || 0

/// This ckey's last pod, if it still exists
/proc/penitentiary_last_pod(ckey)
	var/datum/weakref/ref = ckey ? GLOB.penitentiary_last_pods[ckey] : null
	var/obj/structure/overmap/ship/pod = ref?.resolve()
	return QDELETED(pod) ? null : pod

/// Why this ckey may not take a pod out now, or null
/proc/penitentiary_pod_refusal(ckey)
	if(penitentiary_last_pod(ckey))
		return "pod still out"
	if(penitentiary_pods_used(ckey) >= BACKGROUND_PODS_PER_CKEY)
		return "no pods left"
	return null

/**
 * Spawns one pod out from the Penitentiary for `ckey` and counts it against them. Sleeps while
 * the hull loads. Returns the pod, or null.
 */
/proc/penitentiary_spawn_pod(ckey)
	var/turf/spot = penitentiary_pod_turf()
	if(!spot)
		return null
	var/obj/structure/overmap/ship/pod = SSshuttle.create_ship(/datum/map_template/shuttle/voidcrew/escape_pod, null, null, spot)
	if(!istype(pod) || QDELETED(pod))
		return null
	if(ckey)
		var/list/ledger = convict_ledger(ckey)
		ledger["pods"] = (ledger["pods"] || 0) + 1
		GLOB.penitentiary_last_pods[ckey] = WEAKREF(pod)
	GLOB.penitentiary_pods[WEAKREF(pod)] = 0
	record_metric(METRIC_BACKGROUND, "pod_launched", ckey = ckey, ship = pod, subject = BACKGROUND_CONVICT)
	log_game("BACKGROUNDS: an escape pod launched for [ckey || "nobody"] at ([spot.x], [spot.y])")
	return pod

/// The pod's seats: its cryopod's turf first, then the turf of each chair aboard
/proc/penitentiary_pod_seats(obj/structure/overmap/ship/pod)
	var/list/turf/seats = list()
	var/obj/docking_port/mobile/voidcrew/port = pod?.shuttle
	if(!port)
		return seats
	for(var/obj/machinery/cryopod/cryo in port.spawn_points)
		seats += get_turf(cryo)
		break
	for(var/turf/tile as anything in port.return_turfs())
		if(locate(/obj/structure/chair) in tile)
			seats |= tile
	return seats

/// Whether anyone with a mind is alive aboard the pod
/proc/penitentiary_pod_crewed(obj/structure/overmap/ship/pod)
	var/obj/docking_port/mobile/voidcrew/port = pod?.shuttle
	if(!port)
		return FALSE
	for(var/turf/tile as anything in port.return_turfs())
		for(var/mob/living/aboard in tile.get_all_contents())
			if(aboard.mind && aboard.stat != DEAD)
				return TRUE
	return FALSE

/// The minute's check on every pod: one nobody living has been aboard for BACKGROUND_POD_SCUTTLE_TIME goes
/obj/structure/overmap/penitentiary/proc/pods_tick()
	for(var/datum/weakref/pod_ref as anything in GLOB.penitentiary_pods.Copy())
		var/obj/structure/overmap/ship/pod = pod_ref?.resolve()
		if(QDELETED(pod))
			GLOB.penitentiary_pods -= pod_ref
			continue
		if(penitentiary_pod_crewed(pod))
			GLOB.penitentiary_pods[pod_ref] = 0
			continue
		var/empty_since = GLOB.penitentiary_pods[pod_ref]
		if(!empty_since)
			GLOB.penitentiary_pods[pod_ref] = world.time
			continue
		if(world.time - empty_since < BACKGROUND_POD_SCUTTLE_TIME)
			continue
		log_game("BACKGROUNDS: an empty escape pod scuttled at [AREACOORD(pod)]")
		pod.despawn_derelict()

// ===== THE LAUNCH CONSOLE =====

/obj/machinery/computer/penitentiary_launch
	name = "launch console"
	desc = "Pod launch controls. A cradle, a rail and a big red lever."
	icon_screen = "shuttle"
	icon_keyboard = "tech_key"
	circuit = null
	use_power = NO_POWER_USE
	/// A launch is being prepared at this console
	var/launching = FALSE

/obj/machinery/computer/penitentiary_launch/Initialize(mapload)
	. = ..()
	AddElement(/datum/element/outpost_property)

/obj/machinery/computer/penitentiary_launch/ui_status(mob/user, datum/ui_state/state)
	return UI_CLOSE

/obj/machinery/computer/penitentiary_launch/interact(mob/user)
	var/mob/living/carbon/human/convict = user
	var/refusal = launch_refusal(convict)
	if(refusal)
		balloon_alert(user, refusal)
		return
	launching = TRUE
	balloon_alert(user, "launching...")
	if(!do_after(user, BACKGROUND_POD_LAUNCH_TIME, src))
		launching = FALSE
		return
	refusal = launch_refusal(convict, launching_now = TRUE)
	if(refusal)
		launching = FALSE
		balloon_alert(user, refusal)
		return
	INVOKE_ASYNC(src, PROC_REF(launch), convict)

/// Why `convict` cannot launch a pod from here now, or null
/obj/machinery/computer/penitentiary_launch/proc/launch_refusal(mob/living/carbon/human/convict, launching_now = FALSE)
	if(!ishuman(convict) || convict.stat != CONSCIOUS || !convict.mind)
		return "no response"
	var/datum/background_state/state = convict.mind.background_state
	if(!state || state.ended || state.key != BACKGROUND_CONVICT)
		return "no response"
	if(launching && !launching_now)
		return "busy"
	return penitentiary_pod_refusal(state.ckey || ckey(convict.mind.key))

/// The cradle this console launches from: the nearest one
/obj/machinery/computer/penitentiary_launch/proc/cradle()
	var/obj/structure/overmap/penitentiary/site = GLOB.penitentiary
	var/turf/best
	for(var/turf/cradle as anything in site?.pod_cradles)
		if(!best || get_dist(src, cradle) < get_dist(src, best))
			best = cradle
	return best || get_turf(src)

/// Spawns the pod and puts the convict, and one other convict on the cradle, aboard
/obj/machinery/computer/penitentiary_launch/proc/launch(mob/living/carbon/human/convict)
	var/turf/cradle = cradle()
	var/launch_ckey = convict?.mind?.background_state?.ckey || ckey(convict?.mind?.key)
	var/obj/structure/overmap/ship/pod = penitentiary_spawn_pod(launch_ckey)
	launching = FALSE
	if(!pod)
		balloon_alert(convict, "no response")
		return FALSE
	var/list/turf/seats = penitentiary_pod_seats(pod)
	var/list/mob/living/carbon/human/aboard = list()
	if(!QDELETED(convict) && convict.stat != DEAD)
		aboard += convict
	for(var/mob/living/carbon/human/rider in cradle)
		if(length(aboard) >= BACKGROUND_POD_SEATS)
			break
		if(rider == convict || rider.stat == DEAD || !HAS_TRAIT(rider, TRAIT_BACKGROUND_CONVICT))
			continue
		aboard += rider
	playsound(cradle, 'sound/machines/hiss.ogg', 50, TRUE)
	for(var/i in 1 to length(aboard))
		var/mob/living/carbon/human/escapee = aboard[i]
		var/turf/seat = length(seats) ? seats[min(i, length(seats))] : null
		if(!seat)
			break
		escapee.buckled?.unbuckle_mob(escapee, force = TRUE)
		escapee.pulledby?.stop_pulling()
		escapee.forceMove(seat)
		pod.enlist_crewmember(escapee)
	return TRUE

