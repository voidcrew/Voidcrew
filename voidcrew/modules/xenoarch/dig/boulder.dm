/**
 * # Veined boulder
 *
 * What a large find sits in once its site wall is mined. Ported from NovaSector (5ce2bd2215c0)
 * modular_nova/modules/xenoarchartifacts/artifacts/artifact.dm (/obj/structure/boulder), reworked:
 * - All state lives in a /datum/dig_boulder_record held by the planet's dig reserve, so a rebuilt
 *   planet puts the boulder back exactly as the crew left it.
 * - One depth scanner sounds and measures it (Nova's scanner plus tape measure); the advanced one
 *   reads the exact depth and the stabilising field on site, skipping the spectrometer trip.
 * - One hammer with a fitted head, a pick or drill for rough work, and the brush to finish:
 *   brushing never overshoots, it only takes a centimetre at a time until the find shows.
 * - Cutting past the find loses it. Freeing it without the right stabilising field loses it half
 *   the time and damages it otherwise. A lost find leaves nothing behind: no artifact is made and
 *   no burst fires (Nova spawned and deleted one, setting off its destroy effect).
 * - It shrinks visibly by depth cut (never by depth left, which would give the find away), chips
 *   and dusts on every strike, and the find comes out of a settling cloud of grit.
 */
/obj/structure/xenoarch_boulder
	name = "veined boulder"
	desc = "A heavy block of veined rock, cut loose from the face. Something harder sits inside it."
	icon = 'voidcrew/modules/xenoarch/icons/dig_site.dmi'
	icon_state = "boulder1_0"
	anchored = TRUE
	density = TRUE
	max_integrity = 150
	resistance_flags = FIRE_PROOF | LAVA_PROOF
	/// Everything about this boulder; kept in its site's record while it is unopened
	var/datum/dig_boulder_record/record
	/// The dig site it came from (weakref to /datum/dig_site_record), if any
	var/datum/weakref/site_ref
	/// Next world.time a working tool makes its noise
	var/next_work_noise = 0

/obj/structure/xenoarch_boulder/Initialize(mapload, datum/dig_boulder_record/new_record, datum/dig_site_record/site)
	. = ..()
	record = new_record || new /datum/dig_boulder_record(xenoarch_band_for_turf(src))
	if(site)
		site_ref = WEAKREF(site)
	color = record.rock_color || "#8f8a83"
	if(record.tagged)
		AddComponent(/datum/component/gps, "[record.serial] dig")
	update_appearance()

/obj/structure/xenoarch_boulder/Destroy()
	var/datum/dig_site_record/site = site_ref?.resolve()
	if(record && !record.settled && site && (record in site.loose))
		// Torn down with its planet: the record stays in the reserve and the next build puts the
		// boulder back as it was. Deleted any other way on a live planet (an admin, a ship setting
		// down on it), it is gone for good.
		if(!xenoarch_boulder_kept_on_delete(loc))
			settle()
			record_metric(METRIC_RESEARCH, XENOARCH_METRIC_LOST, subject = "[record.find_type]", zone = xenoarch_band_name(record.band), details = list("size" = "large", "reason" = "removed"), location = loc)
	if(record && (record.settled || !site || !(record in site.loose)))
		QDEL_NULL(record)
	record = null
	site_ref = null
	return ..()

/// Whether a boulder deleted at `place` keeps its record for the next build: its planet is being
/// torn down, or no planet holds it at all (nothing would rebuild it, so nothing is lost either).
/proc/xenoarch_boulder_kept_on_delete(atom/place)
	var/turf/here = get_turf(place)
	if(!here)
		return TRUE
	var/obj/structure/overmap/planet/planet = SSovermap_zones?.get_overmap_object_for_turf(here)
	return !istype(planet) || planet.unloading

/// How far it has been cut down, by depth cut: 0 untouched to 3 a stub of rock.
/obj/structure/xenoarch_boulder/proc/cut_stage()
	switch(record?.dug)
		if(140 to INFINITY)
			return 3
		if(80 to 140)
			return 2
		if(30 to 80)
			return 1
	return 0

/obj/structure/xenoarch_boulder/update_icon_state()
	icon_state = "boulder[record?.variant || 1]_[cut_stage()]"
	return ..()

/obj/structure/xenoarch_boulder/update_overlays()
	. = ..()
	if(!record)
		return
	. += mutable_appearance(icon, "boulder[record.variant]_[cut_stage()]_vein", appearance_flags = RESET_COLOR)
	if(record.sounded)
		. += mutable_appearance(icon, "survey_pin", appearance_flags = RESET_COLOR)
	if(record.tagged)
		. += mutable_appearance(icon, "holotag", appearance_flags = RESET_COLOR)
	if(record.field_applied)
		. += mutable_appearance(icon, "field", appearance_flags = RESET_COLOR)

/obj/structure/xenoarch_boulder/examine(mob/user)
	. = ..()
	if(!record)
		return
	if(record.tagged)
		. += "A holotag on it reads <b>[record.serial]</b>."
	switch(record.sounded)
		if(1)
			. += "A survey tag pinned to it reads: <i>find at [max(1, record.rough_depth - XENOARCH_SCAN_ERROR)] to [record.rough_depth + XENOARCH_SCAN_ERROR] cm. Cut [record.dug] cm.</i>"
		if(2)
			. += "A survey tag pinned to it reads: <i>find at [record.target_depth] cm. Cut [record.dug] cm.</i>"
	if(record.field_applied)
		. += span_notice("A faint lattice of light holds it, set to the [lowertext(record.field_applied)].")

// ===== Tools =====

/obj/structure/xenoarch_boulder/item_interaction(mob/living/user, obj/item/tool, list/modifiers)
	if(!record || record.settled)
		return NONE
	if(istype(tool, /obj/item/mining_scanner) || istype(tool, /obj/item/t_scanner/adv_mining_scanner))
		return tag_with(tool, user)
	if(istype(tool, /obj/item/excavation/hammer))
		return hammer_with(tool, user)
	if(istype(tool, /obj/item/excavation/brush))
		return brush_with(tool, user)
	if(istype(tool, /obj/item/excavation/depth_scanner))
		return sound_with(tool, user)
	if(istype(tool, /obj/item/excavation/core_sampler))
		return sample_with(tool, user)
	if(istype(tool, /obj/item/excavation/stabiliser))
		return stabilise_with(tool, user)
	if(tool.tool_behaviour == TOOL_MINING)
		return rough_cut_with(tool, user)
	return NONE

/// The holotag: a GPS signal under its catalogue number, so the crew (and anyone else) can find it again.
/obj/structure/xenoarch_boulder/proc/tag_with(obj/item/scanner, mob/living/user)
	if(record.tagged)
		balloon_alert(user, "already tagged")
		return ITEM_INTERACT_BLOCKING
	record.tagged = TRUE
	AddComponent(/datum/component/gps, "[record.serial] dig")
	playsound(src, 'sound/machines/beep/twobeep.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] fixes a holotag to [src]."),
		span_notice("You fix a holotag to [src]. It blinks to life: <b>[record.serial]</b>."),
	)
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/hammer_with(obj/item/excavation/hammer/hammer, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	var/cm = hammer.head
	user.visible_message(
		span_notice("[user] starts chipping at [src] with [hammer]."),
		span_notice("You start chipping at [src] with the [cm] cm head."),
		blind_message = span_hear("You hear steady chipping."),
	)
	if(!do_after(user, cm * XENOARCH_HAMMER_TIME_PER_CM, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_ROCK_TAP, 0.6 SECONDS, TRUE), interaction_key = DOAFTER_SOURCE_XENOARCH))
		// Stopping mid-swing is how a careful hand slips.
		if(!QDELETED(src) && record && !record.settled && prob(50))
			to_chat(user, span_warning("Your hammer glances off and takes a chip out of [src]."))
			cut(rand(1, 2), user)
		return ITEM_INTERACT_BLOCKING
	cut(cm, user)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/rough_cut_with(obj/item/tool, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_notice("[user] starts breaking rock off [src] with [tool]."),
		span_notice("You start breaking rock off [src]."),
		blind_message = span_hear("You hear rock being broken."),
	)
	if(!tool.use_tool(src, user, 2.5 SECONDS, volume = 50, extra_checks = CALLBACK(src, PROC_REF(work_noise), 'sound/effects/pickaxe/picaxe1.ogg', 0.8 SECONDS, TRUE)))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	cut(rand(XENOARCH_PICK_CUT_MIN, XENOARCH_PICK_CUT_MAX), user)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/brush_with(obj/item/excavation/brush/brush, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(!do_after(user, brush.brush_time, src, extra_checks = CALLBACK(src, PROC_REF(work_noise), SFX_RUSTLE, 0.9 SECONDS, FALSE), interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	if(record.dug > record.target_depth)
		lose_find(user, "cut too deep")
		return ITEM_INTERACT_SUCCESS
	if(record.dug == record.target_depth)
		free_find(user)
		return ITEM_INTERACT_SUCCESS
	record.dug++
	dust_puff(small = TRUE)
	if(record.sounded)
		balloon_alert(user, "[record.dug] cm")
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/sound_with(obj/item/excavation/depth_scanner/scanner, mob/living/user)
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/effects/industrial_scan/industrial_scan1.ogg', 35, TRUE)
	if(!do_after(user, scanner.scan_time, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	record.sounded = max(record.sounded, scanner.exact ? 2 : 1)
	playsound(src, 'sound/machines/beep/twobeep.ogg', 30, TRUE)
	var/list/reading = list()
	if(scanner.exact)
		reading += "Find at [record.target_depth] cm."
	else
		reading += "Find at [max(1, record.rough_depth - XENOARCH_SCAN_ERROR)] to [record.rough_depth + XENOARCH_SCAN_ERROR] cm."
	reading += "Cut [record.dug] cm."
	if(scanner.reads_field)
		reading += "Field: [record.field]."
	to_chat(user, span_notice("[scanner] pins a survey tag to [src] and reads: <i>[jointext(reading, " ")]</i>"))
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/sample_with(obj/item/excavation/core_sampler/sampler, mob/living/user)
	if(sampler.sample_serial)
		balloon_alert(user, "sampler is full")
		return ITEM_INTERACT_BLOCKING
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	playsound(src, 'sound/effects/rock/rocktap2.ogg', 40, TRUE)
	if(!do_after(user, 2 SECONDS, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled || sampler.sample_serial)
		return ITEM_INTERACT_BLOCKING
	sampler.take_core(record)
	playsound(src, 'sound/machines/click.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] drives [sampler] into [src] and draws out a core of rock."),
		span_notice("You drive [sampler] into [src] and draw out a core of rock."),
	)
	return ITEM_INTERACT_SUCCESS

/obj/structure/xenoarch_boulder/proc/stabilise_with(obj/item/excavation/stabiliser/stabiliser, mob/living/user)
	if(!stabiliser.selected_field)
		balloon_alert(user, "no field set")
		return ITEM_INTERACT_BLOCKING
	if(DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	user.visible_message(
		span_notice("[user] sweeps [stabiliser] slowly over [src]."),
		span_notice("You sweep [stabiliser] over [src], laying down the [lowertext(stabiliser.selected_field)]."),
		blind_message = span_hear("You hear a low electrical hum."),
	)
	playsound(src, 'sound/effects/magic/forcewall.ogg', 25, TRUE)
	if(!do_after(user, 5 SECONDS, src, interaction_key = DOAFTER_SOURCE_XENOARCH))
		return ITEM_INTERACT_BLOCKING
	if(QDELETED(src) || record.settled)
		return ITEM_INTERACT_BLOCKING
	// Correct or not, the field looks the same. Only the spectrometer or a field reading can tell.
	record.field_applied = stabiliser.selected_field
	record.stabilised = (record.field_applied == record.field)
	playsound(src, 'sound/machines/clockcult/steam_whoosh.ogg', 25, TRUE)
	to_chat(user, span_notice("A faint lattice of light settles over [src]."))
	update_appearance()
	return ITEM_INTERACT_SUCCESS

/// Plays a tool's noise, with a chip of rock and a puff of dust for striking tools, at most every `interval`. Always TRUE (a do_after check).
/obj/structure/xenoarch_boulder/proc/work_noise(noise, interval, striking)
	if(world.time < next_work_noise)
		return TRUE
	next_work_noise = world.time + interval
	playsound(src, noise, striking ? 45 : 30, TRUE)
	if(striking)
		dust_puff(small = TRUE)
		Shake(1, 0, 0.15 SECONDS)
	return TRUE

// ===== Cutting down =====

/// Takes `cm` off the boulder. Past the find, the find is lost.
/obj/structure/xenoarch_boulder/proc/cut(cm, mob/living/user)
	var/old_stage = cut_stage()
	record.dug += cm
	if(record.dug > record.target_depth)
		lose_find(user, "cut too deep")
		return
	dust_puff(small = FALSE)
	if(cut_stage() != old_stage)
		// A whole slab comes away: the boulder is visibly smaller.
		playsound(src, 'sound/effects/rock/rock_break.ogg', 40, TRUE)
		visible_message(span_notice("A slab of rock breaks away from [src]."))
		new /obj/effect/temp_visual/xenoarch_dust(get_turf(src), color, FALSE)
	if(record.sounded && user)
		balloon_alert(user, "[record.dug] cm")
	update_appearance()

/// A puff of dust off the cut face, tinted like the rock.
/obj/structure/xenoarch_boulder/proc/dust_puff(small = TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(get_turf(src), color, small)

/// The settle: brushed clean at the right depth. Without the right field it may come apart anyway.
/obj/structure/xenoarch_boulder/proc/free_find(mob/living/user)
	var/turf/spot = get_turf(src)
	var/damaged = FALSE
	if(!record.stabilised)
		if(prob(XENOARCH_UNSTABLE_CRUMBLE_CHANCE))
			lose_find(user, "unstabilised")
			return null
		damaged = TRUE
	var/find_type = record.find_type
	var/band = record.band
	var/serial = record.serial
	settle()
	playsound(spot, 'sound/effects/break_stone.ogg', 50, TRUE)
	playsound(spot, 'sound/effects/rustle/rustle3.ogg', 40, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(spot, color, FALSE)
	new /obj/effect/decal/cleanable/rubble(spot)
	var/atom/movable/find = xenoarch_spawn_large_find(find_type, spot, band, damaged, serial)
	if(find)
		// It comes up out of the grit.
		find.alpha = 0
		find.pixel_z = -6
		animate(find, alpha = 255, pixel_z = 0, time = 1.2 SECONDS, easing = SINE_EASING | EASE_OUT)
		visible_message(span_notice("The last of the rock sloughs away, and [find] stands clear of the dust."))
		if(damaged)
			visible_message(span_warning("Cracks run through [find] where the rock let go of it badly."))
	record_metric(METRIC_RESEARCH, XENOARCH_METRIC_DUG, subject = "[find_type]", zone = xenoarch_band_name(band), details = list("size" = "large", "damaged" = damaged), actor = user, location = spot)
	xenoarch_dig_ambush(spot, band, user)
	qdel(src)
	return find

/**
 * The find is gone: cut into, come apart unheld, smashed or blown up. Nothing is made and
 * nothing goes off. `reason` is for the round metrics.
 */
/obj/structure/xenoarch_boulder/proc/lose_find(mob/living/user, reason, delete_self = TRUE)
	var/turf/spot = get_turf(src)
	var/find_type = record.find_type
	var/band = record.band
	settle()
	switch(reason)
		if("cut too deep")
			visible_message(
				span_warning("Something deep inside [src] gives a dull crunch, and the whole boulder splits along a fault. Whatever was in there is gravel now."),
				blind_message = span_hear("You hear rock crunch and split."),
			)
		if("unstabilised")
			visible_message(
				span_warning("As the last grit comes away, [src] shudders and slumps to pieces. Nothing was holding it together."),
				blind_message = span_hear("You hear rock slump and slide."),
			)
		else
			visible_message(
				span_warning("[src] bursts apart in a spray of grit."),
				blind_message = span_hear("You hear rock burst apart."),
			)
	playsound(spot, 'sound/effects/break_stone.ogg', 60, TRUE)
	playsound(spot, 'sound/effects/rock/rock_break.ogg', 50, TRUE)
	new /obj/effect/temp_visual/xenoarch_dust(spot, color, FALSE)
	new /obj/effect/decal/cleanable/rubble(spot)
	record_metric(METRIC_RESEARCH, XENOARCH_METRIC_LOST, subject = "[find_type]", zone = xenoarch_band_name(band), details = list("size" = "large", "reason" = reason), actor = user, location = spot)
	if(delete_self)
		qdel(src)

/// Done with: out of its site's record for good.
/obj/structure/xenoarch_boulder/proc/settle()
	if(record.settled)
		return
	record.settled = TRUE
	var/datum/dig_site_record/site = site_ref?.resolve()
	site?.settle_boulder(record)

/obj/structure/xenoarch_boulder/atom_destruction(damage_flag)
	if(record && !record.settled)
		lose_find(null, damage_flag == BOMB ? "blast" : "smashed", delete_self = FALSE)
	return ..()

/**
 * # Dig dust
 *
 * A short puff of grit tinted like the rock it came off. Small for each strike, big when a slab
 * comes away or the boulder lets go. Reuses the mook leap cloud.
 */
/obj/effect/temp_visual/xenoarch_dust
	name = "dust"
	icon = 'icons/mob/simple/jungle/mook.dmi'
	icon_state = "mook_leap_cloud"
	layer = ABOVE_MOB_LAYER
	plane = GAME_PLANE
	pixel_x = -16
	pixel_y = -16
	base_pixel_x = -16
	base_pixel_y = -16
	duration = 1 SECONDS
	mouse_opacity = MOUSE_OPACITY_TRANSPARENT

/obj/effect/temp_visual/xenoarch_dust/Initialize(mapload, dust_color, small = TRUE)
	. = ..()
	if(dust_color)
		color = dust_color
	var/matrix/size = matrix()
	if(small)
		size.Scale(0.35)
		size.Translate(rand(-6, 6), rand(-2, 8))
		alpha = 170
	else
		size.Scale(0.8)
	transform = size
	animate(src, alpha = 0, time = duration, easing = EASE_IN)
