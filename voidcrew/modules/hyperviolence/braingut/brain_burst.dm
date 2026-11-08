// Brain burst (hyperviolence, braingut part): a head that bursts rather than coming off whole. It
// comes apart in gibs and the brain is thrown out intact, still holding its owner's mind, so the
// victim can be revived later like any other loose brain.
// The idea is Septic Shock's brain spill (modular_septic wounds/organic/spilling.dm). Nothing of its
// code, art or sound is used: the burst is built from tg's gibs, blood splatter and throwing.

/obj/item/bodypart/head
	/// Set while a blow that is allowed to burst this head instead of knocking it off is being resolved.
	var/hv_burst_pending = FALSE
	/// Direction of the blow being resolved, from the attacker toward this head.
	var/hv_blow_dir

/// Bursts the head: gibs, a spray of blood, a burst of splatter, and the brain thrown intact along burst_dir.
/// announce is off when the caller has already said what happened. Called by hv_burst_head() in _core.dm.
/// Returns TRUE if the head burst.
/mob/living/carbon/proc/hv_burst_head_apart(burst_dir, announce = TRUE)
	if(HAS_TRAIT(src, TRAIT_GODMODE))
		return FALSE
	var/obj/item/bodypart/head/head = get_bodypart(BODY_ZONE_HEAD)
	if(!head || !head.can_dismember())
		return FALSE
	if(!burst_dir)
		burst_dir = pick(GLOB.alldirs)
	var/turf/here = get_turf(src)
	var/organic = IS_ORGANIC_LIMB(head)
	var/bleeds = head.can_bleed()
	var/list/blood_dna = bleeds ? get_blood_dna_list() : null
	var/blood_color = bleeds ? get_bloodtype()?.get_color() : null
	// everything inside the head that can come out: brain, eyes, ears, tongue, and whatever was implanted
	var/list/obj/item/organ/loose = list()
	for(var/obj/item/organ/organ in head)
		if(!(organ.organ_flags & ORGAN_UNREMOVABLE))
			loose += organ

	hv_blood_spray(burst_dir, 4)
	if(!head.dismember(BRUTE, silent = TRUE))
		return FALSE
	// no violent_removal: that would damage the brain, and it has to stay good for revival
	head.drop_organs()
	qdel(head)

	if(isturf(here))
		if(!organic)
			new /obj/effect/gibspawner/robot(here, src)
		else if(bleeds)
			hv_spawn_head_gibs(here, burst_dir, blood_dna)
			hv_head_burst_splatter(here, burst_dir, blood_color)
		playsound(here, 'sound/effects/wounds/splatter.ogg', 80, TRUE)

	for(var/obj/item/organ/organ as anything in loose)
		if(QDELETED(organ) || !isturf(organ.loc))
			continue
		if(istype(organ, /obj/item/organ/brain))
			var/datum/callback/landed = blood_dna ? CALLBACK(organ, TYPE_PROC_REF(/obj/item/organ, hv_landed), blood_dna) : null
			hv_fling_organ(organ, burst_dir, HV_BRAIN_FLING_MIN, HV_BRAIN_FLING_MAX, landed)
		else
			hv_fling_organ(organ, turn(burst_dir, pick(-45, 0, 45)), 1, 2)

	if(announce)
		hv_add_hit_line(pick("[src]'s head bursts apart!", "[src]'s skull bursts open!"), HV_LINE_HUGE, range = DEFAULT_MESSAGE_RANGE)
	return TRUE

/// Throws a loose organ min_dist to max_dist tiles along fling_dir. It lands as an ordinary item.
/// It never goes over a hole or lava: a brain lost in either is a player lost for good, so the throw stops short.
/proc/hv_fling_organ(obj/item/organ/organ, fling_dir, min_dist, max_dist, datum/callback/on_landed)
	var/turf/start = get_turf(organ)
	if(!start || isgroundlessturf(start))
		return
	var/distance = 0
	var/turf/ahead = start
	for(var/tile in 1 to rand(min_dist, max_dist))
		ahead = get_step(ahead, fling_dir)
		if(!ahead || isgroundlessturf(ahead) || islava(ahead))
			break
		distance = tile
	if(!distance)
		return
	organ.throw_at(get_ranged_target_turf(start, fling_dir, distance), distance, 2, callback = on_landed)

/// A thrown organ has come down: it hits the floor with a wet sound and leaves a smear of the victim's blood.
/obj/item/organ/proc/hv_landed(list/blood_dna)
	if(QDELETED(src) || !isturf(loc))
		return
	playsound(src, 'sound/misc/moist_impact.ogg', 50, TRUE)
	new /obj/effect/decal/cleanable/blood/splatter(loc, null, blood_dna)

/// Chunks of head thrown across the burst's cone, and a core, using tg's own gib decals so they merge and clean up like any others.
/proc/hv_spawn_head_gibs(turf/where, burst_dir, list/blood_dna)
#ifndef UNIT_TESTS
	var/list/cone = list(burst_dir, turn(burst_dir, 45), turn(burst_dir, -45))
#endif
	for(var/i in 1 to HV_HEAD_BURST_GIBS)
// These might streak off into space and cause annoying flaky failures with mapping nearstation tests
#ifndef UNIT_TESTS
		var/obj/effect/decal/cleanable/blood/gibs/gib = new(where, null, blood_dna)
		gib.streak(cone)
#else
		new /obj/effect/decal/cleanable/blood/gibs(where, null, blood_dna)
#endif
	new /obj/effect/decal/cleanable/blood/gibs/core(where, null, blood_dna)

/// The short burst itself: blood and a pale smear of brain thrown out of the head along the blow.
/proc/hv_head_burst_splatter(turf/where, burst_dir, blood_color)
	for(var/angle in list(0, 45, -45))
		new /obj/effect/temp_visual/dir_setting/bloodsplatter(where, turn(burst_dir, angle), blood_color)
	new /obj/effect/temp_visual/dir_setting/bloodsplatter(where, burst_dir, "#c9a0ac")

/// Whether a blow that is about to knock this head off should burst it instead. Rare on purpose: the
/// victim must already be dead or in hard crit, the head already half destroyed, and the blow a heavy
/// crushing or piercing one. Cuts and burns never burst a head.
/obj/item/bodypart/head/proc/hv_blow_bursts(wounding_type, wounding_dmg)
	if(!owner || wounding_type == WOUND_SLASH || wounding_type == WOUND_BURN)
		return FALSE
	if(wounding_dmg < HV_HEAD_BURST_MIN_DAMAGE || owner.stat < HARD_CRIT)
		return FALSE
	return get_damage() >= max_damage * HV_HEAD_BURST_MIN_HEAD_DAMAGE

/obj/item/bodypart/head/receive_damage(brute = 0, burn = 0, blocked = 0, updating_health = TRUE, forced = FALSE, required_bodytype = null, wound_bonus = 0, exposed_wound_bonus = 0, sharpness = NONE, attack_direction = null, damage_source, wound_clothing = TRUE)
	hv_blow_dir = attack_direction
	. = ..()
	hv_blow_dir = null

/obj/item/bodypart/head/try_dismember(wounding_type, wounding_dmg, wound_bonus, exposed_wound_bonus)
	hv_burst_pending = hv_blow_bursts(wounding_type, wounding_dmg)
	. = ..()
	hv_burst_pending = FALSE

/// The loss wound announces what happened to the head, so a burst gets its own wording there.
/obj/item/bodypart/head/get_dismember_message(wounding_type, outright)
	if(hv_burst_pending)
		return "bursts apart!"
	return ..()

/obj/item/bodypart/head/dismember(dam_type = BRUTE, silent = TRUE, wounding_type)
	if(hv_burst_pending && owner)
		hv_burst_pending = FALSE
		// the wound that got us here has already said the head burst, so no second line
		if(owner.hv_burst_head_apart(hv_blow_dir, FALSE))
			return TRUE
	return ..()
