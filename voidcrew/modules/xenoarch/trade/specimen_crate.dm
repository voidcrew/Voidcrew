/**
 * # Specimen crate
 *
 * A heavy crate built to hold one large find. Effects stop while it is shut inside (an
 * artifact off a turf never stirs), so a crew can haul a dangerous find without it going off.
 * Any shut crate gets a find past an outpost checkpoint and up to a buyer; this one takes only
 * the find and small things, never people or other machines, and shows the find's field tag on
 * the lid so a hold full of crates can be told apart.
 *
 * It is also the only crate a large find can be loaded into. Open crates are dense here and the
 * usual drag-to-stuff only takes items and people, so a find gets in one of two ways: drag it onto
 * the open crate to heave it in (the lid shuts on it), or push it onto the open crate and shut the
 * lid like any other crate.
 *
 * Art: a recolour of tg's plain crate (icons/obj/storage/crates.dmi "crate"/"crateopen"), lead
 * grey with padded straps; "manifest" and "welded" are tg's own, copied so crate overlays line up.
 */
/obj/structure/closet/crate/specimen
	name = "specimen crate"
	desc = "A padded, lead-lined crate big enough for one large find."
	icon = 'voidcrew/modules/xenoarch/icons/specimen_crate.dmi'
	icon_state = "specimen"
	base_icon_state = "specimen"
	allow_dense = TRUE
	allow_objects = TRUE
	storage_capacity = 10
	// Its own sprite sheet holds no other crate's states
	paint_jobs = null

/obj/structure/closet/crate/specimen/insertion_allowed(atom/movable/thing)
	// The only dense thing it takes is one artifact. No people, no other machines.
	if(istype(thing, /obj/machinery/artifact))
		var/obj/machinery/artifact/find = thing
		if(find.anchored || (locate(/obj/machinery/artifact) in contents))
			return FALSE
		return TRUE
	if(ismob(thing) || (isobj(thing) && thing.density))
		return FALSE
	return ..()

/// How long it takes to heave a large find into the crate.
#define SPECIMEN_CRATE_HEAVE_TIME (3 SECONDS)

// A find dragged onto the open crate is heaved in.
/obj/structure/closet/crate/specimen/mouse_drop_receive(atom/movable/dropped, mob/living/user, params)
	if(!istype(dropped, /obj/machinery/artifact))
		return ..()
	heave_in(dropped, user)

// The open crate lets a find be pushed onto it, so shutting the lid takes it in.
/obj/structure/closet/crate/specimen/CanAllowThrough(atom/movable/mover, border_dir)
	. = ..()
	if(!. && opened && istype(mover, /obj/machinery/artifact) && has_room_for(mover))
		return TRUE

/// No other find is already in it or sitting in it, and `find` is loose.
/obj/structure/closet/crate/specimen/proc/has_room_for(obj/machinery/artifact/find)
	if(find.anchored || (locate(/obj/machinery/artifact) in contents))
		return FALSE
	for(var/obj/machinery/artifact/other in loc)
		if(other != find)
			return FALSE
	return TRUE

/**
 * Whether `find` can be heaved in by `user` right now. Says why not unless `quiet` (the check a
 * heave in progress keeps making).
 */
/obj/structure/closet/crate/specimen/proc/can_heave(obj/machinery/artifact/find, mob/living/user, quiet = FALSE)
	var/reason
	if(QDELETED(src) || QDELETED(find) || !isturf(loc) || !isturf(find.loc))
		reason = "can't get at it!"
	else if(!opened)
		reason = "the lid's shut!"
	else if(find.anchored)
		reason = "it's bolted down!"
	else if(find.z != z || get_dist(find, src) > 1)
		reason = "too far away!"
	else if(!has_room_for(find))
		reason = "no room!"
	else if(!can_close())
		reason = "something's in the way!"
	if(reason && user && !quiet)
		balloon_alert(user, reason)
	return !reason

/// Heaves `find` into the open crate and drops the lid on it. Sleeps. Returns TRUE if it went in.
/obj/structure/closet/crate/specimen/proc/heave_in(obj/machinery/artifact/find, mob/living/user)
	if(!isliving(user) || DOING_INTERACTION(user, DOAFTER_SOURCE_XENOARCH))
		return FALSE
	if(!can_heave(find, user))
		return FALSE
	user.visible_message(
		span_notice("[user] gets a grip on [find] and starts heaving it into [src]."),
		span_notice("You get a grip on [find] and start heaving it into [src]."),
	)
	// Getting your arms round it is a touch, like hauling it.
	find.touched_by(user, accidental = TRUE)
	if(!do_after(user, SPECIMEN_CRATE_HEAVE_TIME, find, extra_checks = CALLBACK(src, PROC_REF(can_heave), find, user, TRUE), interaction_key = DOAFTER_SOURCE_XENOARCH))
		return FALSE
	return load_find(find, user)

/// Sets `find` down in the open crate and shuts the lid on it. Returns TRUE if it ended up inside.
/obj/structure/closet/crate/specimen/proc/load_find(obj/machinery/artifact/find, mob/living/user)
	if(!can_heave(find, user))
		return FALSE
	if(user?.pulling == find)
		user.stop_pulling()
	find.forceMove(loc)
	// The lid takes whatever sits in the crate, the find included, through the usual closing path.
	if(!close(user) || find.loc != src)
		return FALSE
	playsound(src, 'sound/effects/bang.ogg', 25, TRUE)
	if(user)
		user.visible_message(
			span_notice("[user] heaves [find] into [src] and drops the lid on it."),
			span_notice("You heave [find] into [src] and drop the lid on it."),
		)
	return TRUE

#undef SPECIMEN_CRATE_HEAVE_TIME

/obj/structure/closet/crate/specimen/examine(mob/user)
	. = ..()
	if(opened)
		return
	var/obj/machinery/artifact/find = locate() in contents
	if(!find)
		return
	. += "Something heavy is strapped in."
	if(find.is_dug())
		. += "A field tag clipped to the lid reads <b>[find.serial]</b>."

// Printed in the field-gear node ("Xenoarchaeology", study/techweb.dm). It costs more iron than
// it breaks down into.
/datum/design/specimen_crate
	name = "Specimen Crate"
	desc = "A padded, lead-lined crate big enough for one large find."
	id = "xenoarch_specimen_crate"
	build_type = PROTOLATHE | AWAY_LATHE
	materials = list(
		/datum/material/iron = SHEET_MATERIAL_AMOUNT * 5,
		/datum/material/plastic = SHEET_MATERIAL_AMOUNT * 2,
	)
	build_path = /obj/structure/closet/crate/specimen
	category = list(
		RND_CATEGORY_EQUIPMENT + RND_SUBCATEGORY_EQUIPMENT_SCIENCE,
	)
	departmental_flags = DEPARTMENT_BITFLAG_SCIENCE | DEPARTMENT_BITFLAG_CARGO
