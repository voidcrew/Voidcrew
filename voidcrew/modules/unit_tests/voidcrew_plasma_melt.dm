// Package: P1 bolt. Unit tests for the plasma melt-off (voidcrew/modules/plasma_weapons/plasma_melt.dm).

/// Counts things of `type` on `where`
/proc/voidcrew_plasma_melt_count(turf/where, type)
	. = 0
	for(var/atom/thing as anything in where)
		if(istype(thing, type))
			.++

/// Whether `victim` draws any overlay from the melt icon
/proc/voidcrew_plasma_melt_drawn(mob/living/carbon/victim)
	for(var/mutable_appearance/overlay as anything in victim.overlays)
		if(overlay.icon == 'voidcrew/modules/plasma_weapons/icons/plasma_melt.dmi')
			return TRUE
	return FALSE

/// A melted limb leaves no tg ash and no blood splatter, but the body still loses tg's blood
/datum/unit_test/voidcrew_plasma_melt_remains

/datum/unit_test/voidcrew_plasma_melt_remains/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/where = get_turf(victim)
	var/blood_before = victim.blood_volume
	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_R_LEG), SOUTH), "The leg did not melt off")
	TEST_ASSERT_NULL(victim.get_bodypart(BODY_ZONE_R_LEG), "The melted leg is still attached")
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(where, /obj/effect/decal/cleanable/ash), 0, "tg's ash pile was left under the melt")
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(where, /obj/effect/decal/cleanable/blood), 0, "The melt left a blood splatter")
	TEST_ASSERT(victim.blood_volume <= blood_before - 20, "The melt did not take tg's dismember blood loss ([blood_before] -> [victim.blood_volume])")
	TEST_ASSERT(voidcrew_plasma_melt_drawn(victim), "Nothing of the melt is drawn on the body")

	// the splatter guard is only for the body mid-melt, and only stops the splatter
	GLOB.plasma_melt_no_splatter = victim
	victim.add_splatter_floor(where)
	GLOB.plasma_melt_no_splatter = null
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(where, /obj/effect/decal/cleanable/blood), 0, "The guard let a splatter through")
	victim.add_splatter_floor(where)
	TEST_ASSERT(voidcrew_plasma_melt_count(where, /obj/effect/decal/cleanable/blood) > 0, "Splatter outside a melt was blocked")

	for(var/zone in victim.plasma_melts)
		qdel(victim.plasma_melts[zone])
	for(var/obj/effect/thing in where)
		if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/effect/plasma_melt_pool) || istype(thing, /obj/effect/plasma_melt_light))
			qdel(thing)

/// Slag is one decal per tile and capped globally, oldest first; it can be cleaned away
/datum/unit_test/voidcrew_plasma_slag_caps

/datum/unit_test/voidcrew_plasma_slag_caps/Run()
	var/list/start_slag = GLOB.plasma_slag_decals.Copy()
	var/turf/open/first_turf = run_loc_floor_bottom_left
	var/turf/open/second_turf = get_step(first_turf, EAST)
	var/turf/open/third_turf = get_step(second_turf, EAST)
	TEST_ASSERT(isopenturf(first_turf) && isopenturf(second_turf) && isopenturf(third_turf), "The test room has no three open floor tiles in a row")
	var/cap = length(start_slag) + 2

	var/obj/effect/decal/cleanable/plasma_slag/first = plasma_slag_at(first_turf, cap = cap)
	TEST_ASSERT_NOTNULL(first, "No slag was made on an open floor")
	TEST_ASSERT_EQUAL(plasma_slag_at(first_turf, cap = cap), first, "A second melt on the same tile made a second slag decal")
	var/obj/effect/decal/cleanable/plasma_slag/stray = new(first_turf)
	TEST_ASSERT(QDELETED(stray), "A second slag decal on one tile did not merge into the first")
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(first_turf, /obj/effect/decal/cleanable/plasma_slag), 1, "A tile holds more than one slag decal")

	var/obj/effect/decal/cleanable/plasma_slag/second = plasma_slag_at(second_turf, cap = cap)
	var/obj/effect/decal/cleanable/plasma_slag/third = plasma_slag_at(third_turf, cap = cap)
	TEST_ASSERT(QDELETED(first), "Slag over the cap did not drop the oldest decal")
	TEST_ASSERT(!QDELETED(second) && !QDELETED(third), "Slag over the cap dropped a newer decal")
	TEST_ASSERT_EQUAL(length(GLOB.plasma_slag_decals), cap, "The global slag list grew past its cap")

	second_turf.wash(CLEAN_SCRUB)
	TEST_ASSERT(QDELETED(second), "Scrubbing the floor left the slag")
	TEST_ASSERT(!(second in GLOB.plasma_slag_decals), "Cleaned slag stayed in the global list")
	qdel(third)
	TEST_ASSERT_EQUAL(length(GLOB.plasma_slag_decals), length(start_slag), "The global slag list kept test decals")

/// A melted arm burns its jumpsuit sleeve away; a melted leg doesn't touch the uniform. Putting the arm back
/// brings the sleeve back and takes the stump off the body.
/datum/unit_test/voidcrew_plasma_melt_sleeve

/datum/unit_test/voidcrew_plasma_melt_sleeve/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	victim.equipOutfit(/datum/outfit/job/assistant/consistent)
	var/mutable_appearance/uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_NOTNULL(uniform, "The test body has no jumpsuit drawn")
	var/filters_before = length(uniform.filters)

	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_L_LEG), SOUTH), "The leg did not melt off")
	var/datum/plasma_melt/leg_melt = victim.plasma_melts[BODY_ZONE_L_LEG]
	leg_melt.pose_melt()
	TEST_ASSERT(!leg_melt.sleeve_burned, "A melted leg burned a sleeve")
	uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_EQUAL(length(uniform.filters), filters_before, "A melted leg masked the uniform")

	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_R_ARM), SOUTH), "The arm did not melt off")
	var/datum/plasma_melt/arm_melt = victim.plasma_melts[BODY_ZONE_R_ARM]
	TEST_ASSERT_NOTNULL(arm_melt, "The melted arm has no melt on the body")
	uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_EQUAL(length(uniform.filters), filters_before, "The sleeve burned before the arm started melting")
	arm_melt.pose_melt()
	TEST_ASSERT(arm_melt.sleeve_burned, "The melting arm did not burn its sleeve")
	uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_EQUAL(length(uniform.filters), filters_before + 1, "The burned sleeve is not masked off the uniform")
	victim.update_worn_undersuit()
	uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_EQUAL(length(uniform.filters), filters_before + 1, "Redrawing the jumpsuit lost or doubled the sleeve mask")

	arm_melt.pose_stump("stump", FALSE)
	TEST_ASSERT(length(arm_melt.shown), "The cooled stump is not drawn")
	victim.regenerate_limb(BODY_ZONE_R_ARM)
	TEST_ASSERT_NOTNULL(victim.get_bodypart(BODY_ZONE_R_ARM), "The arm did not regrow")
	TEST_ASSERT(QDELETED(arm_melt), "The arm's melt outlived the regrown arm")
	TEST_ASSERT_NULL(LAZYACCESS(victim.plasma_melts, BODY_ZONE_R_ARM), "The body still tracks a melt on the regrown arm")
	uniform = victim.overlays_standing[UNIFORM_LAYER]
	TEST_ASSERT_EQUAL(length(uniform.filters), filters_before, "The sleeve mask stayed after the arm came back")

	victim.regenerate_limb(BODY_ZONE_L_LEG)
	TEST_ASSERT(QDELETED(leg_melt), "The leg's melt outlived the regrown leg")
	TEST_ASSERT(!voidcrew_plasma_melt_drawn(victim), "A stump stayed on the body after both limbs came back")
	var/turf/where = get_turf(victim)
	for(var/obj/effect/thing in where)
		if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/effect/plasma_melt_pool) || istype(thing, /obj/effect/plasma_melt_light) || istype(thing, /obj/effect/temp_visual))
			qdel(thing)

/// The pool stays on the tile where the melt started; melt that runs off a body that moved on lands under it as a
/// short-lived drip, not as a second pool or slag
/datum/unit_test/voidcrew_plasma_melt_moving

/datum/unit_test/voidcrew_plasma_melt_moving/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/turf/start = get_turf(victim)
	var/turf/next = get_step(start, EAST)
	TEST_ASSERT(isopenturf(next), "The test room has no open floor east of the victim")
	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_L_LEG), SOUTH), "The leg did not melt off")
	var/datum/plasma_melt/melt = victim.plasma_melts[BODY_ZONE_L_LEG]
	melt.pose_melt()

	victim.forceMove(next)
	melt.last_moved = world.time - 1 SECONDS // the body has finished sliding onto the next tile
	melt.grow_pool(2)
	TEST_ASSERT_NULL(melt.pool, "A pool started under a body that had moved off the melt's tile")
	TEST_ASSERT(voidcrew_plasma_melt_count(next, /obj/effect/temp_visual/plasma_melt_drip_spot) > 0, "Melt running off a moved body left no drip under it")
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(next, /obj/effect/decal/cleanable/plasma_slag), 0, "A drip made lasting slag")
	TEST_ASSERT(melt.limb_light && get_turf(melt.limb_light) == next, "The limb's light did not follow the body")

	victim.forceMove(start)
	melt.grow_pool(8)
	TEST_ASSERT_NOTNULL(melt.pool, "The pool did not grow on the start tile")
	TEST_ASSERT_EQUAL(get_turf(melt.pool), start, "The pool is not on the tile where the melt started")
	victim.forceMove(next)
	melt.pool_set()
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(start, /obj/effect/decal/cleanable/plasma_slag), 1, "The full pool did not set into slag on the start tile")
	TEST_ASSERT_EQUAL(voidcrew_plasma_melt_count(next, /obj/effect/decal/cleanable/plasma_slag), 0, "Slag followed the body")

	qdel(melt)
	for(var/turf/where in list(start, next))
		for(var/obj/effect/thing in where)
			if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/effect/plasma_melt_pool) || istype(thing, /obj/effect/plasma_melt_light) || istype(thing, /obj/effect/temp_visual))
				qdel(thing)

/// What tg drops off a melting limb really drops at once, but stays hidden until it falls out of the melt;
/// picking it up shows it straight away
/datum/unit_test/voidcrew_plasma_melt_dropped_items

/datum/unit_test/voidcrew_plasma_melt_dropped_items/Run()
	var/mob/living/carbon/human/consistent/victim = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/clothing/shoes/boots = allocate(/obj/item/clothing/shoes/sneakers/black)
	victim.equip_to_slot_or_del(boots, ITEM_SLOT_FEET)
	var/obj/item/tool = allocate(/obj/item/crowbar)
	victim.put_in_r_hand(tool)
	TEST_ASSERT_EQUAL(victim.shoes, boots, "The test body could not wear shoes")
	TEST_ASSERT_EQUAL(victim.get_item_for_held_index(victim.get_held_index_of_item(tool)), tool, "The test body could not hold the tool")

	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_R_LEG), SOUTH), "The leg did not melt off")
	TEST_ASSERT_NULL(victim.shoes, "tg's leg loss did not take the shoes off (the real drop must stay)")
	TEST_ASSERT_EQUAL(boots.alpha, 0, "The dropped shoes show before the leg has melted away")
	var/datum/plasma_melt/leg_melt = victim.plasma_melts[BODY_ZONE_R_LEG]
	leg_melt.pose_stump("stump_bubble", TRUE)
	TEST_ASSERT_EQUAL(boots.alpha, 255, "The shoes stayed hidden after the leg melted away")

	TEST_ASSERT(plasma_melt_limb(victim.get_bodypart(BODY_ZONE_R_ARM), SOUTH), "The arm did not melt off")
	TEST_ASSERT(tool.loc != victim, "The melted hand still holds the tool")
	TEST_ASSERT_EQUAL(tool.alpha, 0, "The dropped tool shows before the hand melts")
	tool.forceMove(get_step(get_turf(victim), EAST))
	TEST_ASSERT_EQUAL(tool.alpha, 255, "Moving the hidden tool did not show it")

	for(var/zone in victim.plasma_melts)
		qdel(victim.plasma_melts[zone])
	var/turf/where = get_turf(victim)
	for(var/obj/effect/thing in where)
		if(istype(thing, /obj/effect/decal/cleanable) || istype(thing, /obj/effect/plasma_melt_pool) || istype(thing, /obj/effect/plasma_melt_light) || istype(thing, /obj/effect/temp_visual))
			qdel(thing)
