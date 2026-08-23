// teleatom: atom to teleport
// destination: destination to teleport to
// precision: teleport precision (0 is most precise, the default)
// effectin: effect to show right before teleportation
// effectout: effect to show right after teleportation
// asoundin: soundfile to play before teleportation
// asoundout: soundfile to play after teleportation
// no_effects: disable the default effectin/effectout of sparks
// forced: whether or not to ignore no_teleport
/proc/do_teleport(atom/movable/teleatom, atom/destination, precision=null, datum/effect_system/effectin=null, datum/effect_system/effectout=null, asoundin=null, asoundout=null, no_effects=FALSE, channel=TELEPORT_CHANNEL_BLUESPACE, forced = FALSE)
	// teleporting most effects just deletes them
	var/static/list/delete_atoms = zebra_typecacheof(list(
		/obj/effect = TRUE,
		/obj/effect/dummy/chameleon = FALSE,
		/obj/effect/wisp = FALSE,
		/obj/effect/mob_spawn = FALSE,
		/obj/effect/immovablerod = FALSE,
		/obj/effect/meteor = FALSE,
	))
	if(delete_atoms[teleatom.type])
		qdel(teleatom)
		return FALSE

	// argument handling
	// if the precision is not specified, default to 0, but apply BoH penalties
	if(isnull(precision))
		precision = 0

	switch(channel)
		if(TELEPORT_CHANNEL_BLUESPACE)
			if(istype(teleatom, /obj/item/storage/backpack/holding))
				precision = rand(1,100)

			var/static/list/bag_cache = typecacheof(/obj/item/storage/backpack/holding)
			var/list/bagholding = typecache_filter_list(teleatom.get_all_contents(), bag_cache)
			if(bagholding.len)
				precision = max(rand(1,100)*bagholding.len,100)
				if(isliving(teleatom))
					var/mob/living/MM = teleatom
					to_chat(MM, span_warning("The bluespace interface on your bag of holding interferes with the teleport!"))

			// if effects are not specified and not explicitly disabled, sparks
			if((!effectin || !effectout) && !no_effects)
				var/datum/effect_system/spark_spread/sparks = new
				sparks.set_up(5, 1, teleatom)
				if (!effectin)
					effectin = sparks
				if (!effectout)
					effectout = sparks
		if(TELEPORT_CHANNEL_QUANTUM)
			// if effects are not specified and not explicitly disabled, rainbow sparks
			if ((!effectin || !effectout) && !no_effects)
				var/datum/effect_system/spark_spread/quantum/sparks = new
				sparks.set_up(5, 1, teleatom)
				if (!effectin)
					effectin = sparks
				if (!effectout)
					effectout = sparks

	// perform the teleport
	var/turf/curturf = get_turf(teleatom)
	var/turf/destturf = get_teleport_turf(get_turf(destination), precision)

	if(!destturf || !curturf || destturf.is_transition_turf())
		return FALSE

	if(!forced)
		if(!check_teleport_valid(teleatom, destturf, channel, original_destination = destination))
			if(ismob(teleatom))
				teleatom.balloon_alert(teleatom, "something holds you back!")
			return FALSE

	if(SEND_SIGNAL(teleatom, COMSIG_MOVABLE_TELEPORTING, destination, channel))
		return FALSE
	if(SEND_SIGNAL(destturf, COMSIG_ATOM_INTERCEPT_TELEPORTING, channel, curturf))
		return FALSE

	if(isobserver(teleatom))
		teleatom.abstract_move(destturf)
		return TRUE

	tele_play_specials(teleatom, curturf, effectin, asoundin)

	var/success = teleatom.forceMove(destturf)
	if(!success)
		return FALSE

	. = TRUE
	/* Past this point, the teleport is successful and you can assume that they're already there */

	log_game("[key_name(teleatom)] has teleported from [loc_name(curturf)] to [loc_name(destturf)]")
	tele_play_specials(teleatom, destturf, effectout, asoundout)

	if(ismob(teleatom))
		var/mob/M = teleatom
		teleatom.log_message("teleported from [loc_name(curturf)] to [loc_name(destturf)].", LOG_GAME, log_globally = FALSE)
		M.cancel_camera()

	SEND_SIGNAL(teleatom, COMSIG_MOVABLE_POST_TELEPORT, destination, channel)

	//We need to be sure that the buckled mobs can teleport too
	if(teleatom.has_buckled_mobs())
		for(var/mob/living/rider in teleatom.buckled_mobs)
			//just in case it fails, but the mob gets unbuckled anyways even if it passes
			teleatom.unbuckle_mob(rider, TRUE, FALSE)

			var/rider_success = do_teleport(rider, destturf, precision, channel=channel, no_effects=TRUE)
			if(!rider_success)
				continue

			if(get_turf(rider) != destturf) //precision made them teleport somewhere else
				to_chat(rider, span_warning("As you reorient your senses, you realize you aren't riding [teleatom] anymore!"))
				continue

			// [mob/living].forceMove() forces mobs to unbuckle, so we need to buckle them again
			teleatom.buckle_mob(rider, force=TRUE)

/proc/tele_play_specials(atom/movable/teleatom, atom/location, datum/effect_system/effect, sound)
	if(!location)
		return

	if(sound)
		playsound(location, sound, 60, TRUE)
	if(effect)
		effect.attach(location)
		effect.start()

// Safe location finder
/proc/find_safe_turf(zlevel, list/zlevels, extended_safety_checks = FALSE, dense_atoms = FALSE)
	if(!zlevels)
		if (zlevel)
			zlevels = list(zlevel)
		else
			zlevels = SSmapping.levels_by_trait(ZTRAIT_STATION)
	var/cycles = 1000
	for(var/cycle in 1 to cycles)
		// DRUNK DIALLING WOOOOOOOOO
		var/x = rand(1, world.maxx)
		var/y = rand(1, world.maxy)
		var/z = pick(zlevels)
		var/random_location = locate(x,y,z)

		if(is_safe_turf(random_location, extended_safety_checks, dense_atoms, cycle < 300))//if the area is mostly NOTELEPORT (centcom) we gotta give up on this fantasy at some point.
			return random_location

/// Checks if a given turf is a "safe" location
/proc/is_safe_turf(turf/random_location, extended_safety_checks = FALSE, dense_atoms = FALSE, no_teleport = FALSE)
	. = FALSE
	if(!isfloorturf(random_location))
		return
	var/turf/open/floor/floor_turf = random_location
	var/area/destination_area = floor_turf.loc

	if(no_teleport && (destination_area.area_flags & NOTELEPORT))
		return

	var/datum/gas_mixture/floor_gas_mixture = floor_turf.air
	if(!floor_gas_mixture)
		return

	var/list/floor_gases = floor_gas_mixture.gases
	var/static/list/gases_to_check = list(
		/datum/gas/oxygen = list(16, 100),
		/datum/gas/nitrogen,
		/datum/gas/carbon_dioxide = list(0, 10)
	)
	if(!check_gases(floor_gases, gases_to_check))
		return FALSE

	// Aim for goldilocks temperatures and pressure
	if((floor_gas_mixture.temperature <= 270) || (floor_gas_mixture.temperature >= 360))
		return
	var/pressure = floor_gas_mixture.return_pressure()
	if((pressure <= 20) || (pressure >= 550))
		return

	if(extended_safety_checks)
		if(islava(floor_turf)) //chasms aren't /floor, and so are pre-filtered
			var/turf/open/lava/lava_turf = floor_turf // Cyberboss: okay, this makes no sense and I don't understand the above comment, but I'm too lazy to check history to see what it's supposed to do right now
			if(!lava_turf.is_safe())
				return

	// Check that we're not warping onto a table or window
	if(!dense_atoms)
		var/density_found = FALSE
		for(var/atom/movable/found_movable in floor_turf)
			if(found_movable.density)
				density_found = TRUE
				break
		if(density_found)
			return

	// DING! You have passed the gauntlet, and are "probably" safe.
	return TRUE

/proc/get_teleport_turfs(turf/center, precision = 0)
	if(!precision)
		return list(center)
	var/list/posturfs = list()
	for(var/turf/T as anything in RANGE_TURFS(precision,center))
		if(T.is_transition_turf())
			continue // Avoid picking these.
		// VOIDCREW EDIT ADDITION: never offer the world border as a landing spot. Upstream
		// only ever reaches cordon through /area/misc/cordon, which the NOTELEPORT test
		// below catches; packed lattice levels paint their band with a raw turf swap that
		// leaves the AREA alone (place_cordon_turf() in voidcrew/datums/map_zones.dm), so
		// the band is /turf/cordon standing in plain /area/space and the area test sees
		// nothing wrong with it. Filtering here rather than only refusing in
		// check_teleport_valid() means an imprecise teleport picks other ground instead of
		// failing outright. See the matching guard in check_teleport_valid().
		if(istype(T, /turf/cordon))
			continue
		// VOIDCREW EDIT END
		var/area/A = T.loc
		if(!(A.area_flags & NOTELEPORT))
			posturfs.Add(T)
	return posturfs

/proc/get_teleport_turf(turf/center, precision = 0)
	var/list/turfs = get_teleport_turfs(center, precision)
	if (length(turfs))
		return pick(turfs)

/// Validates that the teleport being attempted is valid or not
/proc/check_teleport_valid(atom/teleported_atom, atom/destination, channel, atom/original_destination = null)
	SHOULD_BE_PURE(TRUE)

	if(isnull(destination))
		return FALSE // Teleporting FROM nullspace is fine, but TO nullspace is not

	var/area/origin_area = get_area(teleported_atom)

	var/area/destination_area = get_area(destination)
	var/turf/destination_turf = get_turf(destination)

	if(HAS_TRAIT(teleported_atom, TRAIT_NO_TELEPORT))
		return FALSE

	// VOIDCREW EDIT ADDITION: never land anybody inside the world border.
	//
	// /turf/cordon is dense, opaque, airless and indestructible - ScrapeAway() returns
	// itself, Melt() no-ops, explosions and acid do nothing - so a mob that arrives inside
	// one is not "stuck in a wall" in the usual diggable-out sense. Unless it lands on the
	// single ring of band that touches live ground, every neighbour is cordon too, so it
	// cannot step out either, and the turf carries no air. It is a silent soft-lock ending
	// in suffocation, with no way for anyone but an admin to reach the body.
	//
	// Upstream never had to guard this because upstream cordon only exists around a turf
	// reservation, where generate_cordon() moves the turfs into /area/misc/cordon - a
	// NOTELEPORT area, refused a few lines below, whose Entered() dusts trespassers so the
	// case is at least loud. Packed lattice levels paint their band by raw turf swap and
	// never touch the area (place_cordon_turf(), voidcrew/datums/map_zones.dm), leaving
	// /turf/cordon sitting in plain /area/space: no NOTELEPORT, no Entered() handler.
	// The footprint test further down does not cover it either, since the gutter belongs to
	// no tenant and map_region_for_turf() answers null for it, which that check treats as
	// unclaimed ground and lets through.
	//
	// This is how a planet's bluespace anomaly put two crewmembers in the border in round 12:
	// it teleports anyone within a tile to a random turf up to 4 away (8 on a Bumped()), a
	// planet's ground runs to the very edge of its 123x123 slot, and the band starts one turf
	// later. Both were standing at x=134 on a slot whose western edge is x=131, both landed on
	// x=130 - the last column of the five-turf gutter, exactly 4 away - logged as plain
	// "Space", gasping, and neither could walk back out under their own power.
	//
	// Keyed on the turf type rather than the area so it holds wherever cordon is painted.
	if(istype(destination_turf, /turf/cordon))
		return FALSE
	// VOIDCREW EDIT END

	// prevent unprecise teleports from landing you outside of the destination's reserved area
	if(is_reserved_level(destination_turf.z) && istype(original_destination) \
		&& SSmapping.get_reservation_from_turf(destination_turf) != SSmapping.get_reservation_from_turf(get_turf(original_destination)))
		return FALSE

	// VOIDCREW EDIT ADDITION: the same containment, on the slot lattice.
	// The reserved-level test above was the ONLY thing keeping an imprecise teleport inside
	// the site it aimed at, and it only ever worked because ruins and asteroid fields lived
	// on ZTRAIT_RESERVED levels. Packed sites do not - lattice levels are minted
	// ZTRAIT_MINING + ZTRAIT_LINKAGE - so that test is skipped for them entirely. Meanwhile
	// a bag of holding pushes precision to at least 100 (see do_teleport() above), and
	// get_teleport_turfs() is RANGE_TURFS(precision, center): a 201x201 landing square that
	// covers every slot on a 255x255 packed level. The cordon band is excluded by the turf
	// test above - NOT, as this comment used to claim, because it is NOTELEPORT; a packed
	// level's band keeps whatever area it was painted over, which is normally plain
	// /area/space. A co-tenant's /area/space and /area/ruin carry no flag either.
	//
	// Refuses only ground that POSITIVELY resolves to a DIFFERENT region, so unclaimed
	// ground - a roundstart level, deep space, the gutter, a build-out - passes exactly as
	// it does today and this can never wedge a teleport that currently works.
	if(istype(original_destination) && destination_turf)
		var/turf/wanted_turf = get_turf(original_destination)
		var/datum/wanted_region = wanted_turf ? map_region_for_turf(wanted_turf) : null
		if(wanted_region)
			var/datum/landing_region = map_region_for_turf(destination_turf)
			if(landing_region && landing_region != wanted_region)
				return FALSE
	// VOIDCREW EDIT END

	if((origin_area.area_flags & NOTELEPORT) || (destination_area.area_flags & NOTELEPORT))
		return FALSE

	// If one of the areas you're trying to tp to has local_teleport, and they're not the same, return.
	if(((origin_area.area_flags & LOCAL_TELEPORT) || (destination_area.area_flags & LOCAL_TELEPORT)) && destination_area != origin_area)
		return FALSE

	// VOIDCREW EDIT ADDITION: bitrunning containment. The LOCAL_TELEPORT check above
	// only covers tiles a domain template painted an area onto - the untouched floor of
	// the reservation is plain /area/space, which has no such flag. A quantum pad built
	// on one of those tiles teleports real loot out of VR and past the byteforge, which
	// is the only sanctioned way anything leaves a domain. Gate on the reservation.
	if(SSbitrunning.is_domain_turf(get_turf(teleported_atom)) != SSbitrunning.is_domain_turf(destination_turf))
		return FALSE
	// VOIDCREW EDIT END

	return TRUE
