// Hyperviolence blood part: blood pools that grow as a bleeder stands in their own blood.
//
// Art: icons/blood_pool.dmi is original, drawn for this part, greyscale so the decal takes the
// bleeder's blood colour. Every picture is 64x64 and drawn centred on its tile (pixel_x and pixel_y
// of -16), so a big pool's rounded edge wanders over the tiles around it instead of stopping dead at
// the tile line. All of them are shaded from one tiling texture, so neighbouring pools join without
// a seam.
//
// A pool is the ordinary blood decal tg already leaves under a bleeding mob: one per tile, picked
// up by cleaning, merging with new blood, drying out like any other. It only gets bigger. The
// extra blood a standing bleeder loses is added to it, and its picture steps up as it fills. A big
// pool also runs onto the open tiles beside it, a few times at most: each one gets an ordinary
// decal of its own (blood DNA, mopable) drawn as the end of the pool running onto it.

/// How much blood the plain splatter on a tile holds before it grows into each pool size.
GLOBAL_LIST_INIT(hv_blood_pool_thresholds, list(90, 140, 200, 260))

/obj/effect/decal/cleanable/blood
	/// How far this splatter has grown into a pool, 0 being the stock splatter.
	var/hv_pool_tier = 0
	/// The way the blood flowed when this is only the end of a bigger pool running onto the tile, else 0.
	var/hv_pool_lobe_dir = 0
	/// Neighbouring tiles this pool has already tried to run onto, as directions. Each is tried once.
	var/hv_pool_lobe_tried = 0
	/// How many tiles this pool has run onto.
	var/hv_pool_lobes = 0

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
	hv_pool_lobe_dir = 0
	// A pool beside open space keeps to a size that stays on its own tile.
	var/art_tier = new_tier
	if(new_tier > HV_BLOOD_POOL_CONTAINED_TIER && !hv_pool_can_overflow())
		art_tier = HV_BLOOD_POOL_CONTAINED_TIER
	hv_pool_show("pool[art_tier]_[rand(1, 3)]")
	if(new_tier >= HV_BLOOD_POOL_LOBE_TIER)
		hv_pool_run_onto_neighbours(new_tier)

/// Puts this decal's picture on a state of the pool art, drawn centred on the tile.
/obj/effect/decal/cleanable/blood/proc/hv_pool_show(state)
	icon = HV_BLOOD_POOL_ICON
	icon_state = state
	pixel_x = base_pixel_x + HV_BLOOD_POOL_OFFSET
	pixel_y = base_pixel_y + HV_BLOOD_POOL_OFFSET
	update_appearance()

/// Forgets everything about being a pool, for blood that starts over as a plain splatter.
/obj/effect/decal/cleanable/blood/proc/hv_pool_reset()
	hv_pool_tier = 0
	hv_pool_lobe_dir = 0
	hv_pool_lobe_tried = 0
	hv_pool_lobes = 0

/// Whether a pool's big picture, which reaches over the edges of its tile, would lie over open space.
/obj/effect/decal/cleanable/blood/proc/hv_pool_can_overflow()
	var/turf/here = loc
	if(!isturf(here))
		return FALSE
	for(var/direction in GLOB.alldirs)
		var/turf/around = get_step(here, direction)
		if(!around || isgroundlessturf(around))
			return FALSE
	return TRUE

/// Lets a big pool run onto the open tiles beside it: one at the first big size, more at the biggest.
/// Each side is tried once, so a pool does this a few times in its life and no more.
/obj/effect/decal/cleanable/blood/proc/hv_pool_run_onto_neighbours(tier)
	var/turf/here = loc
	if(!isturf(here))
		return
	var/wanted = tier >= HV_BLOOD_POOL_BIGGEST_TIER ? HV_BLOOD_POOL_LOBES_BIGGEST : HV_BLOOD_POOL_LOBES_BIG
	for(var/direction in shuffle(GLOB.cardinals))
		if(hv_pool_lobes >= wanted)
			return
		if(hv_pool_lobe_tried & direction)
			continue
		hv_pool_lobe_tried |= direction
		if(hv_pool_run_onto(get_step(here, direction), direction, tier))
			hv_pool_lobes++

/// Whether blood could run from this pool onto the tile beside it: open floor with gravity, no wall,
/// window or closed door in the way.
/obj/effect/decal/cleanable/blood/proc/hv_pool_can_run_onto(turf/target, direction)
	var/turf/here = loc
	if(!isturf(here) || !target || target.z != here.z)
		return FALSE
	if(!isopenturf(target) || isgroundlessturf(target) || islava(target) || ischasm(target) || iswaterturf(target) || target.has_gravity() <= 0)
		return FALSE
	if(hv_blood_spray_blocked(target) || !here.Adjacent(target))
		return FALSE
	return TRUE

/// Runs this pool onto the tile beside it. Returns TRUE if it did.
/obj/effect/decal/cleanable/blood/proc/hv_pool_run_onto(turf/target, direction, tier)
	if(!hv_pool_can_run_onto(target, direction))
		return FALSE
	var/obj/effect/decal/cleanable/blood/lobe
	for(var/obj/effect/decal/cleanable/blood/found in target)
		if(found.type != /obj/effect/decal/cleanable/blood || found.dried || found.hv_floating || QDELETED(found))
			continue
		// A pool or an earlier lobe is blood enough already; a plain splatter is stretched into this one.
		if(found.hv_pool_tier || found.hv_pool_lobe_dir)
			return FALSE
		lobe = found
		break
	var/list/blood_dna = GET_ATOM_BLOOD_DNA(src)
	if(lobe)
		if(length(blood_dna))
			lobe.add_blood_DNA(blood_dna)
	else
		if(length(blood_dna))
			lobe = new /obj/effect/decal/cleanable/blood(target, null, blood_dna)
		else
			lobe = new /obj/effect/decal/cleanable/blood(target)
		if(QDELETED(lobe))
			return FALSE
	lobe.hv_pool_lobe_dir = direction
	lobe.hv_pool_show("lobe[tier >= HV_BLOOD_POOL_BIGGEST_TIER ? HV_BLOOD_POOL_BIGGEST_TIER : HV_BLOOD_POOL_LOBE_TIER]_[dir2text(direction)]_[rand(1, 2)]")
	return TRUE

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
