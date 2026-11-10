/**
 * # Ground pound
 *
 * A chrome wheel chip the synced pair grants. The bearer crouches for a beat, then drives both fists into
 * the floor: a ring and cracks, dust, a shake for anyone close. Everyone on the tiles around the bearer,
 * bar the bearer's own crew, staggers, is dazed (the next shove knocks them down) and loses some wind; it
 * does no brute. Loose things on the floor nearby hop a tile outward. They are moved, never thrown, so a
 * ring of knives never becomes a ring of thrown knives, and they never hop into a hazard or through glass.
 *
 * Brawler myomers' synced pair gets a lighter one (the /brawler chip): a shorter stagger, less wind, no daze,
 * nothing hops, a smaller ring and one crack, on a longer clock. Same crouch, so it reads the same.
 */

/datum/action/cooldown/cyberware/gorilla_pound
	name = "Ground pound"
	desc = "Drive both fists into the floor."
	button_icon = GORILLA_GORE_ICON
	button_icon_state = "chip_pound"
	check_flags = AB_CHECK_CONSCIOUS | AB_CHECK_INCAPACITATED | AB_CHECK_HANDS_BLOCKED | AB_CHECK_IMMOBILE | AB_CHECK_LYING
	cooldown_time = GORILLA_POUND_COOLDOWN
	/// The crouch before the slam
	var/crouch_timer
	/// The bearer's arm rig while the pound is drawn (chrome_puppet_rig.dm)
	var/datum/chrome_rig/rig
	/// The longest stagger it leaves
	var/stagger = GORILLA_POUND_STAGGER
	/// Daze on everyone it hits; 0 for none
	var/daze = GORILLA_POUND_DAZE
	/// Stamina it takes from everyone it hits
	var/stamina = GORILLA_POUND_STAMINA
	/// Whether loose things nearby hop outward, and the full crash, ring and cracks
	var/full_pound = TRUE

/// Brawler myomers' pound: a shove-off, no daze, nothing hops.
/datum/action/cooldown/cyberware/gorilla_pound/brawler
	cooldown_time = BRAWLER_POUND_COOLDOWN
	stagger = BRAWLER_POUND_STAGGER
	daze = 0
	stamina = BRAWLER_POUND_STAMINA
	full_pound = FALSE

/// Whether the pair this chip belongs to is synced.
/datum/action/cooldown/cyberware/gorilla_pound/proc/pair_synced()
	return gorilla_synced(owner)

/datum/action/cooldown/cyberware/gorilla_pound/brawler/pair_synced()
	return brawler_synced(owner)

/datum/action/cooldown/cyberware/gorilla_pound/Destroy()
	if(crouch_timer)
		deltimer(crouch_timer)
		crouch_timer = null
	drop_rig()
	return ..()

/// Draws the bearer crouching with both arms up. Returns TRUE if the rig is up.
/datum/action/cooldown/cyberware/gorilla_pound/proc/raise_rig(mob/living/carbon/human/bearer)
	drop_rig()
	rig = new(bearer, bearer.dir)
	if(!rig.rig_arms())
		QDEL_NULL(rig)
		return FALSE
	// Moved, knocked down or gone: the drawing comes down at once
	RegisterSignals(bearer, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING), PROC_REF(drop_rig))
	// Arms first: a crouch runs alongside, and a swing started after it would cut it short
	for(var/side in list("l", "r"))
		rig.swing_arm(side, 150, GORILLA_POUND_CROUCH, 0, SINE_EASING)
	rig.crouch(0.88, 2, GORILLA_POUND_CROUCH, SINE_EASING | EASE_OUT)
	return TRUE

/// Takes the rig down and shows the real body.
/datum/action/cooldown/cyberware/gorilla_pound/proc/drop_rig(datum/source)
	SIGNAL_HANDLER
	if(rig?.body)
		UnregisterSignal(rig.body, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_SET_BODY_POSITION, COMSIG_QDELETING))
	QDEL_NULL(rig)

/datum/action/cooldown/cyberware/gorilla_pound/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return
	if(!pair_synced() || !gorilla_may_use_heavy_moves(owner))
		if(feedback)
			owner.balloon_alert(owner, "arms out of sync!")
		return FALSE
	if(HAS_TRAIT(owner, TRAIT_PACIFISM))
		return FALSE
	if(!TIMER_COOLDOWN_FINISHED(owner, COOLDOWN_GORILLA_POUND))
		return FALSE
	var/turf/floor = get_turf(owner)
	if(!isfloorturf(floor) || !floor.has_gravity())
		if(feedback)
			owner.balloon_alert(owner, "nothing to hit!")
		return FALSE
	return TRUE

/datum/action/cooldown/cyberware/gorilla_pound/Activate(atom/target)
	var/mob/living/carbon/human/bearer = owner
	if(!ishuman(bearer) || crouch_timer)
		return FALSE
	StartCooldown()
	gorilla_cooldown(bearer, COOLDOWN_GORILLA_POUND, cooldown_time)
	// The crouch: down, both fists up. Without a rig (something huge worn) the body only dips.
	if(!raise_rig(bearer))
		animate(bearer, pixel_z = -2, time = GORILLA_POUND_CROUCH, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
		animate(pixel_z = 2, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
	crouch_timer = addtimer(CALLBACK(src, PROC_REF(slam), get_turf(bearer)), GORILLA_POUND_CROUCH, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// A ground pound from [bearer], as the chip would. For an AI. Returns TRUE if it began.
/proc/gorilla_try_pound(mob/living/carbon/human/bearer)
	if(!iscarbon(bearer))
		return FALSE
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm in bearer.organs)
		for(var/datum/action/cooldown/cyberware/gorilla_pound/pound in arm.actions)
			if(pound.owner == bearer)
				return !!pound.Trigger()
	return FALSE

/// The fists hit the floor, if the bearer is still crouched where they began.
/datum/action/cooldown/cyberware/gorilla_pound/proc/slam(turf/where)
	crouch_timer = null
	var/mob/living/carbon/human/bearer = owner
	if(!ishuman(bearer) || bearer.loc != where || bearer.stat != CONSCIOUS || HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || HAS_TRAIT(bearer, TRAIT_HANDS_BLOCKED))
		drop_rig()
		return
	if(rig)
		// Down hard, fists on the floor, then back up
		for(var/side in list("l", "r"))
			rig.swing_arm(side, 0, GORILLA_POUND_DRIVE, 3, NONE)
		rig.crouch(0.72, 6, GORILLA_POUND_DRIVE, SINE_EASING | EASE_IN)
		addtimer(CALLBACK(src, PROC_REF(rise)), GORILLA_POUND_DRIVE + 0.1 SECONDS, TIMER_DELETE_ME)
	gorilla_ground_pound(bearer, where, stagger, daze, stamina, full_pound)

/// The bearer stands back up after the pound.
/datum/action/cooldown/cyberware/gorilla_pound/proc/rise()
	if(!rig)
		return
	for(var/side in list("l", "r"))
		rig.swing_arm(side, 0, GORILLA_POUND_RISE, 0)
	rig.crouch(1, 0, GORILLA_POUND_RISE, SINE_EASING | EASE_OUT)
	addtimer(CALLBACK(src, PROC_REF(drop_rig)), GORILLA_POUND_RISE, TIMER_DELETE_ME)

/**
 * Both fists into the floor at [where]: the shock, the stagger and the hop. Returns the mobs it hit.
 * [full] is the Gorilla's: the big crash and ring, the cracks round it, and loose things hopping. Without it
 * (Brawler myomers) a smaller ring, one crack and nothing moved.
 */
/proc/gorilla_ground_pound(mob/living/carbon/human/bearer, turf/where, stagger = GORILLA_POUND_STAGGER, daze = GORILLA_POUND_DAZE, stamina = GORILLA_POUND_STAMINA, full = TRUE)
	. = list()
	cyberware_camo_drop(bearer, "ground pound")
	bearer.do_attack_animation(where, ATTACK_EFFECT_SMASH)
	bearer.visible_message(span_danger("[bearer] drives both fists into the floor!"), span_danger("You drive both fists into the floor!"), vision_distance = DEFAULT_MESSAGE_RANGE)
	playsound(where, 'sound/effects/meteorimpact.ogg', full ? 80 : 50, TRUE, full ? 8 : 2)
	gorilla_pound_impact_fx(where, full ? 1.5 : 1, full)
	cyberware_grey_dust(where)
	for(var/mob/living/shaken in range(full ? 3 : 2, where))
		if(shaken.client && shaken != bearer)
			shake_camera(shaken, 3, get_dist(shaken, where) <= 1 ? 2 : 1)
	shake_camera(bearer, 2, 1)
	for(var/mob/living/hit in orange(1, where))
		// Not through glass or a door edge, and never the bearer's own crew
		if(hit == bearer || hit.stat == DEAD || !hit.Adjacent(bearer) || cyberware_is_ally(bearer, hit))
			continue
		hit.adjust_staggered_up_to(STAGGERED_SLOWDOWN_LENGTH, stagger)
		if(daze > 0)
			hit.apply_status_effect(/datum/status_effect/dazed, daze)
		hit.apply_damage(stamina, STAMINA)
		gorilla_register_aggression(hit, bearer)
		log_combat(bearer, hit, "ground-pounded", "gorilla arms")
		. += hit
	if(full)
		gorilla_pound_scatter(where)

/// The ring and the cracks under a ground pound: the Piledriver's cross, gone sooner. Without [cross], the centre crack only.
/proc/gorilla_pound_impact_fx(turf/where, reach, cross = TRUE)
	if(isnull(where))
		return
	new /obj/effect/temp_visual/circle_wave/cyberware_slam(where, reach)
	new /obj/effect/temp_visual/cyberware_impact_cracks/gorilla_pound(where, "damaged1", cross ? 255 : 180)
	if(!cross)
		return
	for(var/direction in GLOB.cardinals)
		var/turf/next = get_step(where, direction)
		if(next)
			new /obj/effect/temp_visual/cyberware_impact_cracks/gorilla_pound(next, "damaged5", 140)

/obj/effect/temp_visual/cyberware_impact_cracks/gorilla_pound
	duration = 4 SECONDS

/// Loose things on the floor near [where] hop a tile outward, never into a hazard, glass or a door.
/proc/gorilla_pound_scatter(turf/where)
	var/moved = 0
	for(var/obj/item/loose in range(GORILLA_POUND_ITEM_REACH, where))
		if(moved >= 30)
			return
		if(loose.anchored || !isturf(loose.loc) || (loose.item_flags & ABSTRACT) || loose.invisibility)
			continue
		var/turf/here = loose.loc
		if(locate(/obj/structure/table) in here)
			continue
		var/out = get_dir(where, here) || pick(GLOB.cardinals)
		var/turf/next = get_step(here, out)
		if(isnull(next) || isclosedturf(next) || !isfloorturf(next) || gorilla_throw_stops_short(here, next, out))
			continue
		if(!loose.Move(next, out))
			continue
		moved++
		animate(loose, pixel_z = 5, time = 0.08 SECONDS, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
		animate(pixel_z = -5, time = 0.1 SECONDS, easing = SINE_EASING | EASE_IN, flags = ANIMATION_RELATIVE)

// The set bonus grants the chip to the right arm of its pair, or whichever arm there is.

/datum/status_effect/organ_set_bonus/cyberware_gorilla
	/// The ground pound chip, while the pair is synced
	var/datum/action/cooldown/cyberware/gorilla_pound/pound

/datum/status_effect/organ_set_bonus/cyberware_gorilla/proc/grant_pound()
	if(pound && !QDELETED(pound))
		return
	var/list/arms = gorilla_pair_arms(owner, type)
	if(!length(arms))
		return
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/carrier = arms[1]
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		if(arm.zone == BODY_ZONE_R_ARM)
			carrier = arm
	pound = carrier.add_item_action(pound_type)
	if(carrier.owner)
		pound.Grant(carrier.owner)

/datum/status_effect/organ_set_bonus/cyberware_gorilla/proc/take_pound()
	if(!pound)
		return
	var/datum/action/cooldown/cyberware/gorilla_pound/old = pound
	pound = null
	if(QDELETED(old))
		return
	var/obj/item/organ/carrier = old.organ
	if(istype(carrier))
		carrier.remove_item_action(old)
	else
		qdel(old)
