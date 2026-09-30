/**
 * # World population: stranded on a planet (owner item 6)
 *
 * Owner: PC (strays). P0 made this file as a stub; only PC edits it.
 *
 * One person at a crashed escape pod (spec 5.2): the pod's torn-out seat and bent frame, an empty
 * emergency crate, a fire (or a lantern where a fire won't burn), a flare and SOS written big on
 * the ground. They keep the fire going, check the flare, pace about, sit in the pod seat, and wave
 * down anyone from a ship who comes into view. A crew member can take them aboard (recruit.dm).
 *
 * The site is rolled by SSambient_npcs like any planet site. The camp is built once and stays; the
 * person comes and goes with the planet's fauna and is the same person on every visit. Killed or
 * taken aboard, they never come back.
 */

/// Tiles around the site's middle the camp is laid out in
#define STRANDED_CAMP_RADIUS 3

// =========================================================================
// THE SITE
// =========================================================================

/datum/ambient_site_kind/stranded
	name = "crashed pod"
	planet_types = list(
		/datum/overmap/planet/jungle,
		/datum/overmap/planet/lava,
		/datum/overmap/planet/beach,
		/datum/overmap/planet/ice,
		/datum/overmap/planet/wasteland,
	)
	chance = 5
	spot_room = 2
	npc_type = /mob/living/basic/ambient_npc/stray/stranded

// Oceanic planets see a few more pods come down (spec 4.1)
/datum/ambient_site_kind/stranded/chance_on(datum/ambient_planet/record)
	. = ..()
	if(. && record.planet_type == /datum/overmap/planet/beach)
		return 7

/datum/ambient_site_kind/stranded/realize(datum/ambient_place/site/site)
	if(site.data["taken"] || !site.npcs_missing())
		return FALSE
	var/atom/fire = build_camp(site)
	var/turf/where = (fire && ambient_free_turf_near(get_turf(fire), 1)) || ambient_free_turf_near(site.center, 2) || site.center
	var/mob/living/basic/ambient_npc/stray/stranded/npc = new npc_type(where, site.data["identity"])
	npc.set_place(site)
	npc.scale_health(site.health_multiplier())
	site.state = AMBIENT_SITE_ACTIVE
	site.data["identity"] = npc.stray_identity()
	ambient_offer_recruit(npc)
	return TRUE

// Nobody to feed it: the fire burns down
/datum/ambient_site_kind/stranded/on_depopulated(datum/ambient_place/site/site)
	var/obj/structure/bonfire/fire = site.get_prop(/obj/structure/bonfire)
	if(fire?.burning)
		fire.extinguish()

/**
 * The camp around `site`'s middle, built the first time: the fire at the middle, the pod seat
 * beside it, the bent frame with glass and debris round it, the emergency crate, a lit flare and
 * SOS on open ground. Later visits only light the fire again. Returns the fire (or lantern).
 */
/datum/ambient_site_kind/stranded/proc/build_camp(datum/ambient_place/site/site)
	var/atom/fire = site.get_prop(/obj/structure/bonfire) || site.get_prop(/obj/structure/bounty_camp_lamp)
	if(site.data["camp_built"])
		var/obj/structure/bonfire/bonfire = fire
		if(istype(bonfire) && !bonfire.burning)
			bonfire.start_burning()
		return fire
	site.data["camp_built"] = TRUE
	var/turf/center = site.center
	if(!center)
		return null
	var/list/free = list()
	for(var/turf/tile as anything in RANGE_TURFS(STRANDED_CAMP_RADIUS, center))
		if(tile != center && ambient_ground_ok(tile) && !(locate(/obj/structure) in tile))
			free += tile

	// The fire, or a lantern where a fire won't burn
	var/obj/structure/bonfire/stranded/bonfire = new(center)
	bonfire.start_burning()
	if(bonfire.burning)
		fire = bonfire
	else
		qdel(bonfire)
		fire = new /obj/structure/bounty_camp_lamp(center)
	site.add_prop(fire)

	// The seat, torn out of the pod, facing the fire
	var/turf/seat_turf = stranded_pick_tile(free, center, 1, 1)
	if(seat_turf)
		var/obj/structure/chair/comfy/shuttle/seat = new(seat_turf)
		seat.setDir(get_dir(seat_turf, center))
		site.add_prop(seat)
		site.shelter = seat_turf

	// What is left of the pod
	var/turf/frame_turf = stranded_pick_tile(free, center, 2, 3)
	if(frame_turf)
		site.add_prop(new /obj/structure/girder/displaced(frame_turf))
		new /obj/effect/decal/cleanable/glass/titanium(frame_turf)
		var/turf/debris_turf = stranded_pick_tile(free, frame_turf, 1, 1, FALSE)
		if(debris_turf)
			new /obj/effect/decal/cleanable/generic(debris_turf)
	var/turf/crate_turf = stranded_pick_tile(free, center, 2, 2)
	if(crate_turf)
		site.add_prop(new /obj/structure/closet/crate/internals(crate_turf))

	// The flare, to be seen from above
	var/turf/flare_turf = stranded_pick_tile(free, center, 2, 3)
	if(flare_turf)
		var/obj/item/flashlight/flare/flare = new(flare_turf)
		flare.ignition()
		site.add_prop(flare)

	// SOS, big, on open ground
	for(var/attempt in 1 to 6)
		var/turf/start = stranded_pick_tile(free, center, 2, STRANDED_CAMP_RADIUS, FALSE)
		if(!start)
			break
		var/turf/middle = locate(start.x + 1, start.y, start.z)
		var/turf/last = locate(start.x + 2, start.y, start.z)
		if(!(middle in free) || !(last in free))
			continue
		var/list/letters = list("s", "o", "s")
		var/list/tiles = list(start, middle, last)
		for(var/i in 1 to 3)
			free -= tiles[i]
			new /obj/effect/decal/cleanable/crayon(tiles[i], "#f0f0f0", letters[i], "writing", null, null, "A big letter, drawn to be seen from above.")
		break
	return fire

/**
 * A tile from `free` between `low` and `high` tiles of `from`, taken out of `free` if `take`, or
 * null. The fire's own neighbours are left for sitting at, except for the seat.
 */
/proc/stranded_pick_tile(list/free, turf/from, low, high, take = TRUE)
	var/list/options = list()
	for(var/turf/tile as anything in free)
		var/distance = get_dist(tile, from)
		if(distance >= low && distance <= high)
			options += tile
	if(!length(options))
		return null
	var/turf/picked = pick(options)
	if(take)
		free -= picked
	return picked

/// A camp's fire: solid, so nobody walks into it and catches light
/obj/structure/bonfire/stranded
	density = TRUE

// =========================================================================
// THE STRANDED SURVIVOR
// =========================================================================

/mob/living/basic/ambient_npc/stray/stranded
	name = "stranded spacer"
	desc = "Sunburnt, grubby and very glad to see a ship."
	outfit_choices = list(
		/datum/outfit/ambient_stranded,
		/datum/outfit/ambient_stranded/hauler,
		/datum/outfit/ambient_stranded/engineer,
	)
	dialogue_section = "stranded"
	routine = list(
		/datum/ambient_activity/stray_fire = 3,
		/datum/ambient_activity/stray_flare = 1,
		/datum/ambient_activity/wander/stray_pace = 2,
		/datum/ambient_activity/sit = 2,
		/datum/ambient_activity/idle = 1,
	)

/// A freighter hand's work clothes, worn for eleven days
/datum/outfit/ambient_stranded
	name = "Stranded Spacer"
	uniform = /obj/item/clothing/under/color/grey
	suit = /obj/item/clothing/suit/jacket/leather
	gloves = /obj/item/clothing/gloves/fingerless
	shoes = /obj/item/clothing/shoes/workboots

/datum/outfit/ambient_stranded/hauler
	name = "Stranded Hauler"
	uniform = /obj/item/clothing/under/rank/cargo/tech
	suit = /obj/item/clothing/suit/hazardvest
	gloves = null

/datum/outfit/ambient_stranded/engineer
	name = "Stranded Engineer"
	uniform = /obj/item/clothing/under/rank/engineering/engineer
	suit = null

// =========================================================================
// WHAT THEY DO
// =========================================================================

/// Crouched by the camp's fire, feeding it, lighting it again if it went out
/datum/ambient_activity/stray_fire
	name = "keeping the fire going"
	accepts_company = TRUE
	duration_low = 60 SECONDS
	duration_high = 2 MINUTES
	var/datum/weakref/fire_ref
	/// world.time of their next small job at the fire
	var/next_tend = 0

/datum/ambient_activity/stray_fire/setup()
	var/datum/ambient_place/site/site = doer.place
	var/atom/fire = istype(site) ? (site.get_prop(/obj/structure/bonfire) || site.get_prop(/obj/structure/bounty_camp_lamp)) : null
	if(!fire)
		fire = locate(/obj/structure/bonfire) in range(AMBIENT_ACTIVITY_RANGE, doer)
	if(!fire || !isturf(fire.loc))
		return FALSE
	var/turf/stand = doer.free_tile_beside(fire, 1, failed_spots)
	if(!stand)
		return FALSE
	fire_ref = WEAKREF(fire)
	go_to(stand)
	set_duration()
	next_line = world.time + rand(15 SECONDS, 30 SECONDS)
	return TRUE

/datum/ambient_activity/stray_fire/arrive()
	var/atom/fire = fire_ref?.resolve()
	if(fire)
		doer.face_atom(fire)
	doer.crouch()
	next_tend = world.time + rand(5 SECONDS, 15 SECONDS)

/datum/ambient_activity/stray_fire/act(seconds)
	var/atom/fire = fire_ref?.resolve()
	if(!fire || !isturf(fire.loc))
		return AMBIENT_STEP_DONE
	if(world.time >= next_tend)
		next_tend = world.time + rand(20 SECONDS, 40 SECONDS)
		var/obj/structure/bonfire/bonfire = fire
		if(istype(bonfire) && !bonfire.burning)
			bonfire.start_burning()
			if(bonfire.burning)
				doer.manual_emote("gets the fire going again.")
		else if(istype(bonfire))
			doer.manual_emote(pick("feeds the fire.", "pokes at the fire.", "warms [doer.p_their()] hands by the fire."))
		else
			doer.manual_emote(pick("turns the lantern up.", "rubs [doer.p_their()] hands together."))
	chatter("fire", 40 SECONDS, 80 SECONDS)
	return AMBIENT_STEP_CONTINUE

/// A walk over to the flare, to see it is still burning
/datum/ambient_activity/stray_flare
	name = "checking the flare"
	duration_low = 8 SECONDS
	duration_high = 15 SECONDS
	var/datum/weakref/flare_ref

/datum/ambient_activity/stray_flare/setup()
	var/datum/ambient_place/site/site = doer.place
	var/obj/item/flashlight/flare/flare = istype(site) ? site.get_prop(/obj/item/flashlight/flare) : null
	if(!flare || !isturf(flare.loc) || !doer.leash_ok(flare.loc))
		return FALSE
	var/turf/stand = doer.free_tile_beside(flare, 1, failed_spots)
	if(!stand)
		return FALSE
	flare_ref = WEAKREF(flare)
	go_to(stand)
	set_duration()
	return TRUE

/datum/ambient_activity/stray_flare/arrive()
	var/obj/item/flashlight/flare/flare = flare_ref?.resolve()
	if(!flare)
		return
	doer.face_atom(flare)
	if(flare.light_on)
		doer.manual_emote("checks the flare.")
		doer.speak_context("flare", null)
	else
		doer.manual_emote("kicks at the burnt-out flare.")

/datum/ambient_activity/stray_flare/act(seconds)
	if(!flare_ref?.resolve())
		return AMBIENT_STEP_DONE
	if(prob(10) && !doer.buckled)
		doer.setDir(pick(GLOB.cardinals))
	return AMBIENT_STEP_CONTINUE

/// Pacing about near where they were found
/datum/ambient_activity/wander/stray_pace
	name = "pacing"
	radius = 3

/datum/ambient_activity/wander/stray_pace/setup()
	if(doer.home)
		anchor_ref = WEAKREF(doer.home)
	return ..()

#undef STRANDED_CAMP_RADIUS
