// Hyperviolence blood part: blood pools that grow as a bleeder stands in their own blood.
//
// Art: icons/blood_pool.dmi is original, drawn for this part in the style of tg's blood decals,
// greyscale so the decal takes the bleeder's blood colour.
//
// A pool is the ordinary blood decal tg already leaves under a bleeding mob: one per tile, picked
// up by cleaning, merging with new blood, drying out like any other. It only gets bigger. The
// extra blood a standing bleeder loses is added to it, and its picture steps up as it fills.

/// How much blood the plain splatter on a tile holds before it grows into each pool size.
GLOBAL_LIST_INIT(hv_blood_pool_thresholds, list(90, 140, 200, 260))

/obj/effect/decal/cleanable/blood
	/// How far this splatter has grown into a pool, 0 being the stock splatter.
	var/hv_pool_tier = 0

/obj/effect/decal/cleanable/blood/adjust_bloodiness(by_amount, ignore_timer = FALSE)
	. = ..()
	if(. && by_amount > 0)
		hv_update_pool_tier()

/// Steps this splatter up to the next pool size once it holds enough blood. Never steps back down.
/obj/effect/decal/cleanable/blood/proc/hv_update_pool_tier()
	// Only the plain splatter grows; trails, gibs, footprints, sprays and the rest keep their own look.
	if(type != /obj/effect/decal/cleanable/blood || hv_floating || dried || QDELETED(src))
		return
	var/new_tier = 0
	for(var/tier in 1 to length(GLOB.hv_blood_pool_thresholds))
		if(bloodiness >= GLOB.hv_blood_pool_thresholds[tier])
			new_tier = tier
	if(new_tier <= hv_pool_tier)
		return
	hv_pool_tier = new_tier
	icon = HV_BLOOD_POOL_ICON
	icon_state = "pool[new_tier]_[rand(1, 3)]"
	update_appearance()

/mob/living
	/// Which tile this mob was on the last time it bled, packed into one number.
	var/hv_blood_pool_key = 0

/mob/living/bleed(amt)
	. = ..()
	if(amt > 0 && isturf(loc))
		hv_blood_feed_pool(amt)

/// Blood lost while standing still goes into the splatter on the tile, which grows into a pool.
/mob/living/proc/hv_blood_feed_pool(amt)
	var/turf/here = loc
	var/key = (here.z * 1000 + here.y) * 1000 + here.x
	var/stationary = (key == hv_blood_pool_key)
	hv_blood_pool_key = key
	// Moving leaves tg's drips and trails; only a bleeder who stays put builds a pool.
	if(!stationary || HAS_TRAIT(src, TRAIT_GODMODE) || can_bleed(BLOOD_COVER_TURFS) != BLEED_SPLATTER)
		return
	if(isgroundlessturf(here) || !here.has_gravity())
		return
	for(var/obj/effect/decal/cleanable/blood/pool in here)
		if(pool.type != /obj/effect/decal/cleanable/blood || pool.dried || pool.hv_floating || QDELETED(pool))
			continue
		pool.adjust_bloodiness(amt * HV_BLOOD_POOL_PER_UNIT)
		return
