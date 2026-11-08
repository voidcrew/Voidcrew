// Hyperviolence blood part: blood in zero gravity.
//
// Art: icons/blood_weightless.dmi is the mfloor1-7 and mgibbl1-5 globules from Paradise
// (ParadiseSS13/Paradise at commit d2a2bb03d588, icons/effects/blood_weightless.dmi), licensed
// CC BY-SA 3.0, recoloured to greyscale so they take the blood's own colour.
// Idea: Paradise's weightless_icon / check_gravity / splat() in
// code/game/objects/effects/decals/Cleanable/humans.dm (AGPL-3.0).
//
// Blood that lands where nothing pulls it down hangs in the air as bobbing beads, does not dry,
// and falls into an ordinary splatter once gravity comes back. Gravity changes are announced by
// the mobs standing in them (refresh_gravity), which is how tg and Voidcrew's gravity failure
// already tell everyone aboard. A slow sweep covers changes nobody announces, such as a gravity
// field around a turf. Blood already on the floor when gravity goes stays where it is.

/// Blood that is hanging in the air right now.
GLOBAL_LIST_EMPTY(hv_floating_blood)
/// Timer for the sweep that catches gravity changes nothing announced.
GLOBAL_VAR(hv_blood_sweep_timer)

/obj/effect/decal/cleanable/blood
	/// Hanging in the air with no gravity to pull it down.
	var/hv_floating = FALSE

/// Whether blood here would hang in the air rather than lie on the floor.
/obj/effect/decal/cleanable/blood/proc/hv_blood_would_float()
	// Only the plain splatters float; trails, gibs, footprints and flying splatters keep their own handling.
	if(type != /obj/effect/decal/cleanable/blood && type != /obj/effect/decal/cleanable/blood/splatter)
		return FALSE
	if(dried || !isturf(loc))
		return FALSE
	return has_gravity() <= 0

/obj/effect/decal/cleanable/blood/Initialize(mapload, list/datum/disease/diseases, list/blood_or_dna = get_default_blood_type())
	. = ..()
	if(. == INITIALIZE_HINT_QDEL || mapload)
		return
	// A tick's grace: whatever made this decal may still be choosing its picture.
	if(hv_blood_would_float())
		addtimer(CALLBACK(src, PROC_REF(hv_blood_float_begin)), 1)

/obj/effect/decal/cleanable/blood/Destroy()
	GLOB.hv_floating_blood -= src
	return ..()

/// Floating blood only runs together with floating blood, and lying blood with lying blood.
/obj/effect/decal/cleanable/blood/replace_decal(obj/effect/decal/cleanable/blood/merger)
	if(istype(merger) && hv_blood_would_float() != merger.hv_floating)
		return FALSE
	return ..()

/// Lifts this blood into the air.
/obj/effect/decal/cleanable/blood/proc/hv_blood_float_begin()
	if(hv_floating || QDELETED(src) || !hv_blood_would_float())
		return
	hv_floating = TRUE
	// Weightless blood never dries.
	can_dry = FALSE
	STOP_PROCESSING(SSblood_drying, src)
	GLOB.hv_floating_blood += src
	hv_blood_arm_sweep()
	icon = HV_BLOOD_FLOAT_ICON
	icon_state = "float[rand(1, HV_BLOOD_FLOAT_VARIANTS)]"
	layer = ABOVE_MOB_LAYER
	SET_PLANE_IMPLICIT(src, GAME_PLANE)
	base_name = "globules of"
	// Drops the slow fade to dried that was set up when this was a splatter on the floor.
	update_atom_colour()
	update_appearance()
	hv_blood_float_bob()

/// Lets this blood fall: it joins the splatter already on the tile, or becomes one.
/obj/effect/decal/cleanable/blood/proc/hv_blood_land()
	if(!hv_floating || QDELETED(src))
		return
	hv_floating = FALSE
	GLOB.hv_floating_blood -= src
	animate(src)
	pixel_x = initial(pixel_x)
	pixel_y = initial(pixel_y)
	transform = null
	for(var/obj/effect/decal/cleanable/blood/lying in loc)
		if(lying == src || lying.type != type || lying.hv_floating || lying.dried || QDELETED(lying))
			continue
		handle_merge_decal(lying)
		qdel(src)
		return
	icon = initial(icon)
	icon_state = base_icon_state
	layer = initial(layer)
	SET_PLANE_IMPLICIT(src, initial(plane))
	base_name = initial(base_name)
	can_dry = initial(can_dry)
	if(!dried)
		START_PROCESSING(SSblood_drying, src)
	// Starts the fade to dried again, from the full drying time.
	update_atom_colour()
	update_appearance()
	hv_pool_tier = 0
	hv_update_pool_tier()

/// A slow rise and fall, a little different for every bead so they do not move together.
/obj/effect/decal/cleanable/blood/proc/hv_blood_float_bob()
	var/lift = rand(2, 5)
	var/drift = rand(-3, 3)
	var/tilt = rand(6, 14) * pick(-1, 1)
	var/period = rand(14, 26)
	animate(src, pixel_y = lift, pixel_x = drift, transform = matrix().Turn(tilt), time = period, loop = -1, easing = SINE_EASING)
	animate(pixel_y = 0, pixel_x = -drift, transform = matrix().Turn(-tilt), time = period, easing = SINE_EASING)

// tg stops every animation on a decal whenever its colour is recalculated; put the bobbing back.
/obj/effect/decal/cleanable/blood/update_blood_color()
	. = ..()
	if(hv_floating)
		hv_blood_float_bob()

/obj/effect/decal/cleanable/blood/update_desc(updates)
	. = ..()
	if(hv_floating)
		desc = "Beads of blood hang in the air."

/obj/effect/decal/cleanable/blood/process(seconds_per_tick)
	if(hv_floating)
		return PROCESS_KILL
	return ..()

// Nothing to step in, and nothing to crawl into.
/obj/effect/decal/cleanable/blood/on_entered(datum/source, atom/movable/AM)
	SIGNAL_HANDLER
	if(hv_floating)
		return
	return ..()

/obj/effect/decal/cleanable/blood/can_bloodcrawl_in()
	if(hv_floating)
		return FALSE
	return ..()

/// Without gravity a drip has nothing to fall onto: the blood hangs in the air as beads instead.
/datum/blood_type/make_blood_splatter(mob/living/bleeding, turf/blood_turf, drip = FALSE)
	if(drip && isturf(blood_turf) && !blood_turf.has_gravity())
		drip = FALSE
	return ..()

/// Lets every piece of floating blood that now has gravity under it fall.
/proc/hv_blood_recheck_floating()
	for(var/obj/effect/decal/cleanable/blood/floater as anything in GLOB.hv_floating_blood.Copy())
		if(QDELETED(floater))
			GLOB.hv_floating_blood -= floater
			continue
		if(floater.has_gravity() > 0)
			floater.hv_blood_land()

/// Starts the slow sweep if there is floating blood and no sweep already waiting.
/proc/hv_blood_arm_sweep()
	if(GLOB.hv_blood_sweep_timer || !length(GLOB.hv_floating_blood))
		return
	GLOB.hv_blood_sweep_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(hv_blood_gravity_sweep)), HV_BLOOD_FLOAT_SWEEP, TIMER_STOPPABLE)

/proc/hv_blood_gravity_sweep()
	GLOB.hv_blood_sweep_timer = null
	hv_blood_recheck_floating()
	hv_blood_arm_sweep()

/// Anyone whose gravity comes back tells the floating blood to look again, once however many of them there are.
/mob/living/refresh_gravity()
	var/old_gravity = gravity_state
	. = ..()
	if(gravity_state > 0 && !(old_gravity > 0) && length(GLOB.hv_floating_blood))
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(hv_blood_recheck_floating)), 1, TIMER_UNIQUE)
