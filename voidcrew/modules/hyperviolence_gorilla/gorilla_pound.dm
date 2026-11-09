/**
 * # Ground pound
 *
 * A chrome wheel chip the synced pair grants. The bearer crouches for a beat, then drives both fists into
 * the floor: a ring and cracks, dust, a shake for anyone close. Everyone on the tiles around the bearer,
 * bar the bearer's own crew, staggers, is dazed (the next shove knocks them down) and loses some wind; it
 * does no brute. Loose things on the floor nearby hop a tile outward. They are moved, never thrown, so a
 * ring of knives never becomes a ring of thrown knives, and they never hop into a hazard or through glass.
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

/datum/action/cooldown/cyberware/gorilla_pound/Destroy()
	if(crouch_timer)
		deltimer(crouch_timer)
		crouch_timer = null
	return ..()

/datum/action/cooldown/cyberware/gorilla_pound/IsAvailable(feedback = FALSE)
	. = ..()
	if(!.)
		return
	if(!gorilla_synced(owner) || !gorilla_may_use_heavy_moves(owner))
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
	gorilla_cooldown(bearer, COOLDOWN_GORILLA_POUND, GORILLA_POUND_COOLDOWN)
	// The crouch: down and wide
	animate(bearer, pixel_z = -2, time = GORILLA_POUND_CROUCH, easing = SINE_EASING | EASE_OUT, flags = ANIMATION_RELATIVE | ANIMATION_PARALLEL)
	animate(pixel_z = 2, time = 0.1 SECONDS, flags = ANIMATION_RELATIVE)
	crouch_timer = addtimer(CALLBACK(src, PROC_REF(slam), get_turf(bearer)), GORILLA_POUND_CROUCH, TIMER_STOPPABLE|TIMER_DELETE_ME)
	return TRUE

/// A ground pound from [bearer], as the chip would. For an AI. Returns TRUE if it began.
/proc/gorilla_try_pound(mob/living/carbon/human/bearer)
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in gorilla_heavy_arms(bearer))
		for(var/datum/action/cooldown/cyberware/gorilla_pound/pound in arm.actions)
			if(pound.owner == bearer)
				return !!pound.Trigger()
	return FALSE

/// The fists hit the floor, if the bearer is still crouched where they began.
/datum/action/cooldown/cyberware/gorilla_pound/proc/slam(turf/where)
	crouch_timer = null
	var/mob/living/carbon/human/bearer = owner
	if(!ishuman(bearer) || bearer.loc != where || bearer.stat != CONSCIOUS || HAS_TRAIT(bearer, TRAIT_INCAPACITATED) || HAS_TRAIT(bearer, TRAIT_HANDS_BLOCKED))
		return
	gorilla_ground_pound(bearer, where)

/// Both fists into the floor at [where]: the shock, the stagger and the hop. Returns the mobs it hit.
/proc/gorilla_ground_pound(mob/living/carbon/human/bearer, turf/where)
	. = list()
	cyberware_camo_drop(bearer, "ground pound")
	bearer.do_attack_animation(where, ATTACK_EFFECT_SMASH)
	bearer.visible_message(span_danger("[bearer] drives both fists into the floor!"), span_danger("You drive both fists into the floor!"), vision_distance = DEFAULT_MESSAGE_RANGE)
	playsound(where, 'sound/effects/meteorimpact.ogg', 80, TRUE, 8)
	cyberware_piledriver_impact_fx(where, 1.5)
	cyberware_grey_dust(where)
	for(var/mob/living/shaken in range(3, where))
		if(shaken.client && shaken != bearer)
			shake_camera(shaken, 3, get_dist(shaken, where) <= 1 ? 2 : 1)
	shake_camera(bearer, 2, 1)
	for(var/mob/living/hit in orange(1, where))
		// Not through glass or a door edge, and never the bearer's own crew
		if(hit == bearer || hit.stat == DEAD || !hit.Adjacent(bearer) || cyberware_is_ally(bearer, hit))
			continue
		hit.adjust_staggered_up_to(STAGGERED_SLOWDOWN_LENGTH, 10 SECONDS)
		hit.apply_status_effect(/datum/status_effect/dazed, GORILLA_POUND_DAZE)
		hit.apply_damage(GORILLA_POUND_STAMINA, STAMINA)
		gorilla_register_aggression(hit, bearer)
		log_combat(bearer, hit, "ground-pounded", "gorilla arms")
		. += hit
	gorilla_pound_scatter(where)

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

// The set bonus grants the chip to the right arm, or whichever real arm there is.

/datum/status_effect/organ_set_bonus/cyberware_gorilla
	/// The ground pound chip, while the pair is synced
	var/datum/action/cooldown/cyberware/gorilla_pound/pound

/datum/status_effect/organ_set_bonus/cyberware_gorilla/proc/grant_pound()
	if(pound && !QDELETED(pound))
		return
	var/list/arms = gorilla_heavy_arms(owner)
	if(!length(arms))
		return
	var/obj/item/organ/cyberimp/cyberware/gorilla_arms/carrier = arms[1]
	for(var/obj/item/organ/cyberimp/cyberware/gorilla_arms/arm as anything in arms)
		if(arm.zone == BODY_ZONE_R_ARM)
			carrier = arm
	pound = carrier.add_item_action(/datum/action/cooldown/cyberware/gorilla_pound)
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
