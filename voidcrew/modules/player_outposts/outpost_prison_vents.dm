/**
 * # Kessler vents
 *
 * The prison wing's sealed vents: seven floor vents (one in each cell, two in the yard, one in the
 * office) that the changeling experiment's headslug crawls between (outpost_prison_changeling.dm).
 * They are not atmospheric machinery and join nothing: no pipes, no air, no LINDA. Each is outpost
 * property: it cannot be damaged, welded, pried, unscrewed or cut, and construction drones leave it
 * alone.
 *
 * The one thing a player can do to a vent is put a wrench on its bolts. That takes
 * OUTPOST_KESSLER_VENT_WRENCH_TIME on any vent. On the vent the slug is in, the cover comes off and
 * the slug drops out, stunned; on any other vent the seal holds, and a slug that moved on while the
 * wrench was turning is gone deeper into the pipes. Guessing costs time, and there is no stripping
 * the vents in advance. A cover that comes off (wrenched, or blown out by the horror) is refitted
 * when the experiment ends.
 */

/// Every Kessler vent, for the changeling experiment's hops
GLOBAL_LIST_EMPTY(outpost_kessler_vents)

/obj/structure/outpost_kessler_vent
	name = "sealed vent"
	desc = "A floor vent in a sealed Kessler Biolabs fitting. It isn't connected to the outpost's air, and the bolts are stamped \"do not open\"."
	icon = 'icons/obj/machines/atmospherics/unary_devices.dmi'
	icon_state = "vent_off"
	// A floor grate: any facing reads the same, and a rotated wing turns it with the floor.
	dir = SOUTH
	density = FALSE
	anchored = TRUE
	layer = GAS_SCRUBBER_LAYER
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	/// The cover is off: wrenched off, or blown out from inside
	var/open = FALSE
	/// Dented outward by something in the duct
	var/dented = FALSE
	/// The headslug in the duct under this cover
	var/mob/living/basic/headslug/beakless/outpost/occupant
	/// Someone has a wrench on the bolts
	var/wrenching = FALSE

/obj/structure/outpost_kessler_vent/Initialize(mapload)
	. = ..()
	GLOB.outpost_kessler_vents += src
	// Outpost property without the element: the element blocks every wrench, and the wrench is
	// how the slug comes out. The trait keeps construction drones off it and the element off it.
	ADD_TRAIT(src, TRAIT_OUTPOST_PROPERTY, INNATE_TRAIT)
	AddElement(/datum/element/empprotection, EMP_PROTECT_ALL)

/obj/structure/outpost_kessler_vent/Destroy()
	GLOB.outpost_kessler_vents -= src
	// Only admins get this far. Whatever was in the duct comes out where it is.
	var/mob/living/basic/headslug/beakless/outpost/slug = occupant
	release_occupant()
	if(!QDELETED(slug))
		slug.forceMove(drop_location())
		slug.event?.slug_lost_vent(slug, src)
	return ..()

/obj/structure/outpost_kessler_vent/examine(mob/user)
	. = ..()
	if(open)
		. += span_warning("The cover is off. The duct under it is dark and wet.")
	else if(dented)
		. += span_warning("The cover is dented outward, and one corner has lifted.")

/obj/structure/outpost_kessler_vent/update_icon_state()
	icon_state = "vent_off"
	return ..()

/obj/structure/outpost_kessler_vent/update_overlays()
	. = ..()
	if(!open)
		return
	// The duct under a missing cover
	var/mutable_appearance/hole = mutable_appearance(icon, "vent_off")
	hole.color = "#141414"
	hole.alpha = 230
	. += hole

// ===== WHAT IS IN IT =====

/// The slug moves into the duct under this cover
/obj/structure/outpost_kessler_vent/proc/take_occupant(mob/living/basic/headslug/beakless/outpost/slug)
	if(occupant == slug)
		return
	occupant = slug
	slug.forceMove(src)

/// Forgets the slug, wherever it went
/obj/structure/outpost_kessler_vent/proc/release_occupant()
	occupant = null

/obj/structure/outpost_kessler_vent/Exited(atom/movable/gone, direction)
	. = ..()
	if(gone == occupant)
		occupant = null

/// The slug in the duct cannot push the cover up on its own
/obj/structure/outpost_kessler_vent/relaymove(mob/living/user, direction)
	return

/obj/structure/outpost_kessler_vent/container_resist_act(mob/living/user)
	return

// ===== THE COVER =====

/obj/structure/outpost_kessler_vent/proc/set_open(new_open)
	new_open = !!new_open
	if(open == new_open)
		return
	open = new_open
	if(open)
		dented = FALSE
		transform = matrix()
	update_appearance(UPDATE_OVERLAYS)

/// Dented outward from inside: the cover sits askew
/obj/structure/outpost_kessler_vent/proc/dent()
	if(dented || open)
		return
	dented = TRUE
	transform = matrix().Turn(pick(-9, 9))

/// Kessler puts a new cover on after the experiment
/obj/structure/outpost_kessler_vent/proc/refit()
	var/was_off = open || dented
	dented = FALSE
	transform = matrix()
	set_open(FALSE)
	return was_off

/// The cover blown out from inside
/obj/structure/outpost_kessler_vent/proc/blow_out()
	set_open(TRUE)
	playsound(src, 'sound/effects/bang.ogg', 90, TRUE, 6)
	playsound(src, 'sound/effects/meatslap.ogg', 70, TRUE, 3)
	var/turf/spot = get_turf(src)
	if(spot)
		new /obj/effect/decal/cleanable/blood/splatter/xeno(spot)

// ===== NOISE =====

/**
 * Something moves in the duct: a rattle and a shake of the cover that can be heard across the
 * wing and seen from anywhere with a line of sight. `level` 1-3 is how loud and violent.
 */
/obj/structure/outpost_kessler_vent/proc/rattle(level = 1)
	switch(level)
		if(1)
			playsound(src, 'sound/machines/ventcrawl.ogg', 30, TRUE, 3)
			Shake(1, 1, 0.6 SECONDS)
		if(2)
			playsound(src, 'sound/machines/ventcrawl.ogg', 45, TRUE, 5)
			playsound(src, 'sound/effects/clang.ogg', 25, TRUE, 3)
			Shake(2, 1, 0.8 SECONDS)
		else
			playsound(src, 'sound/effects/bang.ogg', 60, TRUE, 7)
			Shake(3, 2, 1 SECONDS)

/// The slug lands in this duct
/obj/structure/outpost_kessler_vent/proc/clang(level = 1)
	playsound(src, 'sound/effects/clang.ogg', 25 + 15 * level, TRUE, 2 + 2 * level)
	Shake(1, 1, 0.4 SECONDS)

/// The slug leaves this duct for another, heard faintly
/obj/structure/outpost_kessler_vent/proc/scuttle()
	playsound(src, 'sound/machines/ventcrawl.ogg', 15, TRUE, 1)

/// Something much bigger pushes at the cover: the loudest cue there is
/obj/structure/outpost_kessler_vent/proc/strain_pulse()
	playsound(src, 'sound/effects/bang.ogg', 90, TRUE, 10)
	playsound(src, pick('sound/effects/creak/creak1.ogg', 'sound/effects/meatslap.ogg'), 70, TRUE, 6)
	Shake(4, 3, 1 SECONDS)
	var/matrix/rest = matrix(transform)
	var/matrix/bulge = matrix(transform)
	bulge.Scale(1.25)
	// Parallel, so it runs alongside the shake instead of cutting it off
	animate(src, transform = bulge, time = 0.3 SECONDS, easing = SINE_EASING, flags = ANIMATION_PARALLEL)
	animate(transform = rest, time = 0.5 SECONDS, easing = SINE_EASING)

// ===== TOOLS =====

/**
 * A wrench on the bolts. On the vent the slug is in, the cover comes off and the slug drops out.
 * Anywhere else the seal holds, after the same wait.
 */
/obj/structure/outpost_kessler_vent/wrench_act(mob/living/user, obj/item/tool)
	if(open)
		balloon_alert(user, "the cover is off")
		return ITEM_INTERACT_BLOCKING
	if(wrenching)
		balloon_alert(user, "already being unbolted")
		return ITEM_INTERACT_BLOCKING
	var/mob/living/basic/headslug/beakless/outpost/was_inside = occupant
	wrenching = TRUE
	user.visible_message(
		span_notice("[user] puts a wrench to the bolts of [src]."),
		span_notice("You start unbolting the cover of [src]..."),
	)
	var/unbolted = tool.use_tool(src, user, OUTPOST_KESSLER_VENT_WRENCH_TIME, volume = 50)
	wrenching = FALSE
	if(!unbolted || QDELETED(src) || open)
		return ITEM_INTERACT_BLOCKING
	if(occupant)
		force_out(user)
		return ITEM_INTERACT_SUCCESS
	if(was_inside)
		to_chat(user, span_warning("The bolts give, but whatever was in there scrabbles away deeper into the pipes."))
		playsound(src, 'sound/machines/ventcrawl.ogg', 40, TRUE)
	else
		to_chat(user, span_notice("The seal holds. Nothing pushes back."))
	return ITEM_INTERACT_SUCCESS

/obj/structure/outpost_kessler_vent/wrench_act_secondary(mob/living/user, obj/item/tool)
	return wrench_act(user, tool)

/// The cover comes off and the slug drops out, stunned, and turns on whoever did it
/obj/structure/outpost_kessler_vent/proc/force_out(mob/living/user)
	var/mob/living/basic/headslug/beakless/outpost/slug = occupant
	release_occupant()
	set_open(TRUE)
	playsound(src, 'sound/items/deconstruct.ogg', 50, TRUE)
	playsound(src, 'sound/effects/splat.ogg', 60, TRUE)
	if(QDELETED(slug))
		return
	slug.forceMove(get_turf(src))
	visible_message(span_boldwarning("The cover comes off [src], and [slug] drops out in a spray of slime!"))
	log_game("PLAYER OUTPOST PRISON: [key_name(user)] wrenched the headslug out of a vent at [AREACOORD(src)]")
	slug.wrenched_out(user)

/// Anything but a wrench: the fitting is sealed
/obj/structure/outpost_kessler_vent/proc/refuse_tool(mob/living/user)
	balloon_alert(user, "sealed Kessler fitting!")
	return ITEM_INTERACT_BLOCKING

/obj/structure/outpost_kessler_vent/welder_act(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/welder_act_secondary(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/crowbar_act(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/crowbar_act_secondary(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/screwdriver_act(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/screwdriver_act_secondary(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/wirecutter_act(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/wirecutter_act_secondary(mob/living/user, obj/item/tool)
	return refuse_tool(user)

/obj/structure/outpost_kessler_vent/multitool_act(mob/living/user, obj/item/tool)
	return refuse_tool(user)
