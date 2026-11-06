/// Backgrounds: owned by P6. See data/backgrounds/spec.md.

/**
 * # Raids
 *
 * A party of hermit gunslingers rides on the homestead every BACKGROUND_RAID_INTERVAL, only while a
 * homesteader is alive on the Frontier and the last party is dead or gone (ECO-14). Their dust shows
 * BACKGROUND_RAID_TELEGRAPH before they come, and a child calls it out to the yard; then they walk
 * in from BACKGROUND_RAID_SPAWN_DIST out until their own eyes find someone to shoot. With no
 * homesteader left on the planet they go.
 */

/// How far the call of riders on the ridge carries
#define HOMESTEAD_RAID_CALL_RANGE 30

/// One beat of the raids
/datum/homestead/proc/tend_raids()
	prune_raiders()
	if(!homesteader_on_frontier())
		if(raid_spot || length(raiders))
			end_raid()
		next_raid_at = 0
		return
	if(raid_spot)
		new /obj/effect/temp_visual/mook_dust(raid_spot)
		if(world.time >= raid_arrives_at)
			spawn_raiders()
		return
	if(length(raiders))
		steer_raiders()
		raiders_loot()
		return
	if(!next_raid_at)
		next_raid_at = world.time + BACKGROUND_RAID_INTERVAL
		return
	// A new party only rides on someone who is actually there to meet it
	if(world.time >= next_raid_at && homesteader_on_frontier(TRUE))
		start_raid()

/// Whether a homesteader is alive on either of the Frontier's levels (and connected, if `connected`)
/datum/homestead/proc/homesteader_on_frontier(connected = FALSE)
	for(var/datum/mind/mind as anything in background_active_minds(BACKGROUND_HOMESTEADER))
		var/mob/living/settler = mind.current
		if(QDELETED(settler) || settler.stat == DEAD || !on_frontier(settler))
			continue
		if(connected && !settler.client)
			continue
		return TRUE
	return FALSE

/// The party's riders who are still alive and on the surface
/datum/homestead/proc/living_raiders()
	. = list()
	for(var/datum/weakref/raider_ref as anything in raiders)
		var/mob/living/raider = raider_ref.resolve()
		var/turf/raider_turf = get_turf(raider)
		if(!QDELETED(raider) && raider.stat != DEAD && raider_turf?.z == surface_z)
			. += raider

/// Forgets riders who died, left or were deleted
/datum/homestead/proc/prune_raiders()
	var/list/still_riding = list()
	for(var/mob/living/raider as anything in living_raiders())
		still_riding += WEAKREF(raider)
	raiders = still_riding

/**
 * Dust on the ridge: picks where the party comes from and starts the telegraph. Returns TRUE if a
 * raid is on its way.
 */
/datum/homestead/proc/start_raid()
	next_raid_at = world.time + BACKGROUND_RAID_INTERVAL
	var/turf/spot = raid_origin()
	if(!spot)
		next_raid_at = world.time + 5 MINUTES
		return FALSE
	raid_spot = spot
	raid_arrives_at = world.time + BACKGROUND_RAID_TELEGRAPH
	raiders_looted = list()
	for(var/turf/puff as anything in RANGE_TURFS(1, spot))
		new /obj/effect/temp_visual/mook_dust(puff)
	var/mob/living/basic/ambient_npc/homestead/lookout = family_speaker(/mob/living/basic/ambient_npc/homestead/child)
	if(lookout)
		var/list/lines = lookout.get_lines("riders")
		if(length(lines))
			INVOKE_ASYNC(lookout, TYPE_PROC_REF(/atom/movable, say), pick(lines), null, list(), TRUE, null, FALSE, null, FALSE, HOMESTEAD_RAID_CALL_RANGE)
	record_metric(METRIC_BACKGROUND, "homestead_raid", location = spot)
	return TRUE

/// Open ground BACKGROUND_RAID_SPAWN_DIST from the house on a random bearing, or null
/datum/homestead/proc/raid_origin()
	if(!centre)
		return null
	for(var/attempt in 1 to 12)
		var/bearing = rand(0, 359)
		var/turf/spot = locate(clamp(round(centre.x + BACKGROUND_RAID_SPAWN_DIST * cos(bearing)), 2, world.maxx - 1), clamp(round(centre.y + BACKGROUND_RAID_SPAWN_DIST * sin(bearing)), 2, world.maxy - 1), surface_z)
		if(!spot || !istype(spot.loc, /area/overmap_encounter/planetoid))
			continue
		if(!ambient_ground_ok(spot))
			continue
		return spot
	return null

/// The party arrives at the dust and walks for the house
/datum/homestead/proc/spawn_raiders()
	var/turf/spot = raid_spot
	raid_spot = null
	if(!spot)
		return
	var/static/list/party = list(
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger,
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/gunslinger,
		/mob/living/simple_animal/hostile/asteroid/hermit/ranged/hunter,
	)
	var/list/turf/ground = list()
	for(var/turf/tile as anything in RANGE_TURFS(1, spot))
		if(ambient_ground_ok(tile))
			ground += tile
	if(!length(ground))
		ground += spot
	for(var/index in 1 to min(BACKGROUND_RAID_SIZE, length(party)))
		var/rider_type = party[index]
		var/mob/living/simple_animal/hostile/raider = new rider_type(pick(ground))
		raiders += WEAKREF(raider)
		GLOB.move_manager.move_to(raider, raid_target(), 1, raider.move_to_delay)

/// Where the riders head: the kitchen, or the middle of the house
/datum/homestead/proc/raid_target()
	var/obj/machinery/smartfridge/fridge = house_fridge()
	return fridge ? get_turf(fridge) : centre

/// Riders with nobody in their sights keep walking for the kitchen
/datum/homestead/proc/steer_raiders()
	var/turf/target = raid_target()
	for(var/mob/living/simple_animal/hostile/raider in living_raiders())
		if(raider.target || raider.move_packet || get_dist(raider, target) <= 1)
			continue
		GLOB.move_manager.move_to(raider, target, 1, raider.move_to_delay)

/**
 * Riders who reach the kitchen take food: one thing each, from the table or the fridge. With the
 * family down in the cellar, a raid costs the larder rather than lives.
 */
/datum/homestead/proc/raiders_loot()
	refresh_fixtures()
	var/obj/machinery/smartfridge/fridge = house_fridge()
	for(var/mob/living/raider as anything in living_raiders())
		var/key = REF(raider)
		if(raiders_looted[key])
			continue
		var/at_kitchen = fridge && get_dist(raider, fridge) <= 1
		if(!at_kitchen)
			for(var/datum/weakref/table_ref as anything in table_refs)
				var/obj/structure/table/table = table_ref.resolve()
				if(!QDELETED(table) && get_dist(raider, table) <= 1)
					at_kitchen = TRUE
					break
		if(!at_kitchen)
			continue
		var/obj/item/food/meal = find_food()
		if(!meal)
			continue
		raiders_looted[key] = TRUE
		raider.visible_message(span_warning("[raider] grabs [meal]!"))
		qdel(meal)

/// Calls the raid off: the dust settles and the riders go
/datum/homestead/proc/end_raid()
	raid_spot = null
	for(var/mob/living/raider as anything in living_raiders())
		qdel(raider)
	raiders = list()
	raiders_looted = list()

#undef HOMESTEAD_RAID_CALL_RANGE
