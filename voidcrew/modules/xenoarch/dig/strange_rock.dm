/**
 * # Strange rock
 *
 * A lump of veined rock that drops out of a site wall, holding one small find. Worked by hand
 * like a boulder in miniature: sound it, chip it down with the hammer, brush the last of it away.
 * Cut too deep and the find goes with the rock.
 *
 * Ported from NovaSector (5ce2bd2215c0) modular_nova/modules/xenoarch/code/modules/research/
 * xenoarch/strange_rock.dm, reworked: finds come from the site's kind and band (curios.dm), not
 * Nova's loot tables; one scanner sounds and measures; the find is stamped with its band. Sprite
 * from Polaris (6cd19fe0dec6) icons/obj/xenoarchaeology.dmi "strange", carved down in two stages.
 */
/obj/item/strange_rock
	name = "strange rock"
	desc = "A lump of veined rock, heavier than it looks."
	icon = 'voidcrew/modules/xenoarch/icons/curios.dmi'
	icon_state = "strange_rock_0"
	w_class = WEIGHT_CLASS_NORMAL
	force = 6
	throwforce = 8
	/// ZONE_* its find is stamped with
	var/band = ZONE_GREEN
	/// XENOARCH_SITE_* it came out of
	var/site_kind
	/// 1 to 3
	var/tier = 1
	/// What is inside (a type path)
	var/find_type
	/// Depth of the find, in cm
	var/target_depth = 10
	/// What the plain depth scanner reads
	var/rough_depth = 10
	/// cm chipped off so far
	var/dug = 0
	/// 0 not sounded, 1 roughly, 2 exactly
	var/sounded = 0
	/// Next world.time a working tool makes its noise
	var/next_work_noise = 0

/obj/item/strange_rock/Initialize(mapload, band, site_kind)
	. = ..()
	src.band = XENOARCH_BAND_INDEX(isnull(band) ? xenoarch_band_for_turf(src) : band)
	src.site_kind = site_kind || pick(XENOARCH_SITE_GARDEN, XENOARCH_SITE_ANIMAL, XENOARCH_SITE_HOUSE, XENOARCH_SITE_TECHNICAL, XENOARCH_SITE_TEMPLE, XENOARCH_SITE_WAR)
	tier = xenoarch_roll_small_tier(src.band)
	find_type = xenoarch_small_find(src.site_kind, tier)
	target_depth = rand(6, 14) + tier * XENOARCH_ROCK_DEPTH_PER_TIER
	var/error = round(XENOARCH_SCAN_ERROR / 3)
	rough_depth = max(1, target_depth + rand(-error, error))
	pixel_x = base_pixel_x + rand(-6, 6)
	pixel_y = base_pixel_y + rand(-4, 4)

/obj/item/strange_rock/update_icon_state()
	switch(dug)
		if(20 to INFINITY)
			icon_state = "strange_rock_2"
		if(10 to 20)
			icon_state = "strange_rock_1"
		else
			icon_state = "strange_rock_0"
	return ..()

/obj/item/strange_rock/examine(mob/user)
	. = ..()
	var/error = round(XENOARCH_SCAN_ERROR / 3)
	switch(sounded)
		if(1)
			. += "A survey tag on it reads: <i>find at [max(1, rough_depth - error)] to [rough_depth + error] cm. Cut [dug] cm.</i>"
		if(2)
			. += "A survey tag on it reads: <i>find at [target_depth] cm. Cut [dug] cm.</i>"

/obj/item/strange_rock/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(istype(tool, /obj/item/excavation/hammer))
		return hammer_with(tool, user)
	if(istype(tool, /obj/item/excavation/brush))
		return brush_with(tool, user)
	if(istype(tool, /obj/item/excavation/depth_scanner))
		return sound_with(tool, user)
	return NONE

/obj/item/strange_rock/proc/hammer_with(obj/item/excavation/hammer/hammer, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, hammer.head * XENOARCH_HAMMER_TIME_PER_CM, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_ROCK_TAP, 0.6 SECONDS), interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	dug += hammer.head
	if(dug > target_depth)
		lose_find(user)
		return ITEM_INTERACT_SUCCESS
	if(sounded)
		balloon_alert(user, "[dug] cm")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/strange_rock/proc/brush_with(obj/item/excavation/brush/brush, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, brush.brush_time, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_RUSTLE, 0.9 SECONDS), interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	if(dug > target_depth)
		lose_find(user)
		return ITEM_INTERACT_SUCCESS
	if(dug == target_depth)
		free_find(user)
		return ITEM_INTERACT_SUCCESS
	dug++
	if(sounded)
		balloon_alert(user, "[dug] cm")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/item/strange_rock/proc/sound_with(obj/item/excavation/depth_scanner/scanner, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/effects/industrial_scan/industrial_scan2.ogg', 30, TRUE)
	if(!do_after(user, scanner.scan_time, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src))
		return ITEM_INTERACT_BLOCKING
	sounded = max(sounded, scanner.exact ? 2 : 1)
	playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
	var/error = round(XENOARCH_SCAN_ERROR / 3)
	var/depth_text = scanner.exact ? "[target_depth] cm" : "[max(1, rough_depth - error)] to [rough_depth + error] cm"
	to_chat(user, span_notice("[scanner] pins a survey tag to [src] and reads: <i>Find at [depth_text]. Cut [dug] cm.</i>"))
	return ITEM_INTERACT_SUCCESS

/// A tool's noise at most every `interval`. Always TRUE (a do_after check).
/obj/item/strange_rock/proc/work_noise(noise, interval)
	if(world.time < next_work_noise)
		return TRUE
	next_work_noise = world.time + interval
	playsound(src, noise, 35, TRUE)
	return TRUE

/// Brushed clean at the right depth: the find comes loose, into the hand that held the rock if any.
/obj/item/strange_rock/proc/free_find(mob/living/user)
	var/atom/drop_spot = drop_location()
	var/mob/living/holder = ismob(loc) ? loc : null
	var/atom/movable/find = xenoarch_spawn_small_find(find_type, drop_spot, band)
	playsound(drop_spot, 'sound/effects/rock/rock_break.ogg', 40, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(get_turf(drop_spot), "#9c8c78", TRUE)
	if(find)
		new /obj/effect/temp_visual/xenoarch_glint(get_turf(drop_spot))
		var/atom/speaker = holder || src
		speaker.visible_message(
			span_notice("The last crust of rock falls away from [find]."),
			blind_message = span_hear("You hear rock crumble."),
		)
		record_metric(METRIC_RESEARCH, XENOARCH_METRIC_DUG, subject = "[find.type]", zone = xenoarch_band_name(band), details = list("size" = "small", "tier" = tier), actor = user, location = drop_spot)
	qdel(src)
	if(!find)
		return null
	if(holder && isitem(find) && holder.put_in_hands(find))
		return find
	// On the ground it hops out of the grit.
	animate(find, pixel_z = 5, time = 0.15 SECONDS, easing = SINE_EASING | EASE_OUT)
	animate(pixel_z = 0, time = 0.3 SECONDS, easing = BOUNCE_EASING)
	return find

/// Cut too deep, or smashed: the find goes with the rock.
/obj/item/strange_rock/proc/lose_find(mob/living/user, reason = "cut too deep")
	var/atom/drop_spot = drop_location()
	var/atom/speaker = ismob(loc) ? loc : src
	speaker.visible_message(
		span_warning("Something inside [src] crunches, and it falls apart into gravel. Nothing in it survived."),
		blind_message = span_hear("You hear rock crunch."),
	)
	playsound(drop_spot, 'sound/effects/break_stone.ogg', 40, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(get_turf(drop_spot), "#9c8c78", TRUE)
	record_metric(METRIC_RESEARCH, XENOARCH_METRIC_LOST, subject = "[find_type]", zone = xenoarch_band_name(band), details = list("size" = "small", "reason" = reason), actor = user, location = drop_spot)
	qdel(src)

/obj/item/strange_rock/ex_act(severity, target)
	if(severity == EXPLODE_LIGHT && prob(50))
		return FALSE
	lose_find(null, "blast")
	return TRUE
