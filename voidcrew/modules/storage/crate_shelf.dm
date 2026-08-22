/**
 * Crate shelves.
 *
 * Ships run out of floor long before they run out of crates. A shelf takes a stack of
 * closed crates off the deck and keeps them on one tile, and gives them all back when
 * you want them (or when somebody shoots the shelf apart).
 *
 * Crates are held in the shelf's contents and drawn as stacked overlays. They are not
 * openable while shelved - pull one off the shelf first.
 */

/// How many crates a standard shelf holds.
#define CRATE_SHELF_CAPACITY 3
/// Vertical pixel gap between each crate drawn on the shelf.
#define CRATE_SHELF_STACK_OFFSET 8
/// How long it takes to heave a crate onto / off of a shelf.
#define CRATE_SHELF_HANDLING_TIME (1 SECONDS)
/// Iron sheets a shelf is worth.
#define CRATE_SHELF_SHEET_COST 5

/obj/structure/crate_shelf
	name = "crate shelf"
	desc = "A heavy duty shelving unit sized for supply crates. Drag a closed crate onto it to stow it, click the shelf to pull the top one back off."
	icon = 'icons/obj/structures.dmi'
	icon_state = "rack"
	base_icon_state = "rack"
	density = TRUE
	anchored = TRUE
	max_integrity = 100
	/// How many crates this shelf can hold at once.
	var/capacity = CRATE_SHELF_CAPACITY
	/// Vertical pixel gap between each stacked crate.
	var/stack_offset = CRATE_SHELF_STACK_OFFSET

/obj/structure/crate_shelf/Initialize(mapload)
	. = ..()
	register_context()

/obj/structure/crate_shelf/Destroy()
	// Backstop for a plain qdel: never take the crates (and whatever is in them) with us.
	unload_all()
	return ..()

/obj/structure/crate_shelf/examine(mob/user)
	. = ..()
	. += span_notice("It is holding [length(contents)] of [capacity] crates.")
	if(length(contents))
		. += span_notice("Crates have to come off the shelf before they can be opened.")
	. += span_info("It's held together by a couple of [EXAMINE_HINT("bolts")].")

/obj/structure/crate_shelf/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	var/context_set = FALSE

	if(length(contents))
		context[SCREENTIP_CONTEXT_LMB] = "Take top crate"
		context_set = TRUE

	if(held_item?.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_RMB] = "Disassemble"
		context_set = TRUE

	return context_set ? CONTEXTUAL_SCREENTIP_SET : NONE

/// Crates that have no business being stacked on a shelf, even though they are crates.
/obj/structure/crate_shelf/proc/is_shelvable(obj/structure/closet/crate/crate)
	var/static/list/unshelvable_crates
	if(isnull(unshelvable_crates))
		unshelvable_crates = typecacheof(list(
			/obj/structure/closet/crate/grave, // a hole in the ground, not a box
			/obj/structure/closet/crate/miningcar, // belongs on rails
		))
	return !is_type_in_typecache(crate, unshelvable_crates)

/// The crate on top of the stack, or null if the shelf is empty.
/obj/structure/crate_shelf/proc/top_crate()
	var/crate_count = length(contents)
	if(!crate_count)
		return null
	return contents[crate_count]

/// Whether this crate can go on the shelf right now. Complains to `user` if not.
/obj/structure/crate_shelf/proc/can_load(obj/structure/closet/crate/crate, mob/user)
	if(!istype(crate) || QDELETED(crate))
		return FALSE
	if(length(contents) >= capacity)
		balloon_alert(user, "shelf is full!")
		return FALSE
	if(crate.opened)
		balloon_alert(user, "close it first!")
		return FALSE
	if(crate.anchored)
		balloon_alert(user, "it's anchored!")
		return FALSE
	if(!is_shelvable(crate))
		balloon_alert(user, "won't fit!")
		return FALSE
	return TRUE

/// Puts a crate on the shelf. Returns TRUE if it made it.
/obj/structure/crate_shelf/proc/load(obj/structure/closet/crate/crate, mob/living/user)
	if(!can_load(crate, user))
		return FALSE

	user.visible_message(
		span_notice("[user] starts heaving [crate] onto [src]."),
		span_notice("You start heaving [crate] onto [src]."),
	)
	if(!do_after(user, CRATE_SHELF_HANDLING_TIME, target = src))
		return FALSE
	// Everything can have changed over the do_after.
	if(QDELETED(src) || QDELETED(crate) || !isturf(crate.loc) || !can_load(crate, user))
		return FALSE

	crate.forceMove(src)
	add_fingerprint(user)
	playsound(src, 'sound/machines/crate/crate_close.ogg', 40, TRUE)
	user.visible_message(
		span_notice("[user] stows [crate] on [src]."),
		span_notice("You stow [crate] on [src]."),
	)
	update_appearance()
	return TRUE

/// Takes the top crate off the shelf and puts it on `destination` (or our own turf).
/obj/structure/crate_shelf/proc/unload(mob/living/user, turf/destination)
	var/obj/structure/closet/crate/crate = top_crate()
	if(isnull(crate))
		return FALSE

	if(!isturf(destination) || destination.density || get_dist(src, destination) > 1)
		destination = drop_location()
	if(!isturf(destination))
		return FALSE

	crate.forceMove(destination)
	if(user)
		add_fingerprint(user)
		user.visible_message(
			span_notice("[user] pulls [crate] off [src]."),
			span_notice("You pull [crate] off [src]."),
		)
	playsound(src, 'sound/machines/crate/crate_open.ogg', 40, TRUE)
	update_appearance()
	return TRUE

/// Dumps everything on the shelf onto the floor around it. Used when the shelf goes away.
/obj/structure/crate_shelf/proc/unload_all()
	var/turf/our_turf = drop_location()
	if(!isturf(our_turf))
		our_turf = get_turf(src)
	for(var/obj/structure/closet/crate/crate in contents.Copy())
		if(isturf(our_turf))
			crate.forceMove(our_turf)
		else
			crate.moveToNullspace()

/obj/structure/crate_shelf/Entered(atom/movable/arrived, atom/old_loc, list/atom/old_locs)
	. = ..()
	if(!QDELETED(src))
		update_appearance()

/obj/structure/crate_shelf/Exited(atom/movable/gone, direction)
	. = ..()
	if(!QDELETED(src))
		update_appearance()

/obj/structure/crate_shelf/update_overlays()
	. = ..()
	var/vertical_offset = 0
	for(var/obj/structure/closet/crate/crate in contents)
		// Copying the crate's own appearance keeps its paint job, labels and lid overlays.
		var/mutable_appearance/shelved_crate = new(crate.appearance)
		shelved_crate.plane = FLOAT_PLANE
		shelved_crate.layer = FLOAT_LAYER
		shelved_crate.pixel_x = 0
		shelved_crate.pixel_w = 0
		shelved_crate.pixel_y = vertical_offset
		shelved_crate.pixel_z = 0
		. += shelved_crate
		vertical_offset += stack_offset

/obj/structure/crate_shelf/attack_hand(mob/living/user, list/modifiers)
	. = ..()
	if(.)
		return .
	if(!length(contents))
		balloon_alert(user, "it's empty!")
		return TRUE
	unload(user, get_turf(user))
	return TRUE

/obj/structure/crate_shelf/attack_paw(mob/living/user, list/modifiers)
	return attack_hand(user, modifiers)

/obj/structure/crate_shelf/mouse_drop_receive(atom/dropped, mob/user, params)
	if(!isliving(user))
		return
	var/obj/structure/closet/crate/crate = dropped
	if(!istype(crate) || !isturf(crate.loc))
		return
	load(crate, user)

/obj/structure/crate_shelf/mouse_drop_dragged(atom/over, mob/user, src_location, over_location, params)
	if(!isliving(user) || !length(contents))
		return
	var/turf/destination = get_turf(over)
	if(!isturf(destination) || get_dist(src, destination) > 1)
		return
	unload(user, destination)

/obj/structure/crate_shelf/wrench_act_secondary(mob/living/user, obj/item/tool)
	if(length(contents))
		balloon_alert(user, "empty it first!")
		return ITEM_INTERACT_BLOCKING
	tool.play_tool_sound(src)
	deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/structure/crate_shelf/handle_deconstruct(disassembled = TRUE)
	// Crates come out whether we were unbolted or blown apart.
	unload_all()
	return ..()

/obj/structure/crate_shelf/atom_deconstruct(disassembled = TRUE)
	set_density(FALSE)
	if(disassembled)
		var/obj/item/crate_shelf/flatpack = new(drop_location())
		transfer_fingerprints_to(flatpack)
		return
	new /obj/item/stack/sheet/iron(drop_location(), CRATE_SHELF_SHEET_COST - 2)

/*
 * The flat-packed shelf. Craft it, carry it where you want it, unfold it.
 */

/obj/item/crate_shelf
	name = "crate shelf parts"
	desc = "A flat-packed crate shelf. Use it in your hand to unfold it where you're standing."
	icon = 'icons/obj/structures.dmi'
	icon_state = "rack_parts"
	inhand_icon_state = "rack_parts"
	// Too much frame to shove in a backpack, which also keeps it out of the crates it holds.
	w_class = WEIGHT_CLASS_BULKY
	obj_flags = CONDUCTS_ELECTRICITY
	custom_materials = list(/datum/material/iron = SHEET_MATERIAL_AMOUNT * CRATE_SHELF_SHEET_COST)
	/// Set while an assembly do_after is running, so you can't spam out a pile of shelves.
	var/building = FALSE

/obj/item/crate_shelf/Initialize(mapload)
	. = ..()
	register_context()

/obj/item/crate_shelf/add_context(atom/source, list/context, obj/item/held_item, mob/living/user)
	if(isnull(held_item))
		return NONE

	if(held_item == src)
		context[SCREENTIP_CONTEXT_LMB] = "Unfold shelf"
		return CONTEXTUAL_SCREENTIP_SET

	if(held_item.tool_behaviour == TOOL_WRENCH)
		context[SCREENTIP_CONTEXT_LMB] = "Break down"
		return CONTEXTUAL_SCREENTIP_SET

	return NONE

/obj/item/crate_shelf/wrench_act(mob/living/user, obj/item/tool)
	tool.play_tool_sound(src)
	deconstruct(TRUE)
	return ITEM_INTERACT_SUCCESS

/obj/item/crate_shelf/atom_deconstruct(disassembled = TRUE)
	new /obj/item/stack/sheet/iron(drop_location(), CRATE_SHELF_SHEET_COST)

/obj/item/crate_shelf/attack_self(mob/user)
	if(building)
		return
	var/turf/build_turf = get_turf(user)
	if(!isturf(build_turf))
		return
	if(locate(/obj/structure/crate_shelf) in build_turf)
		balloon_alert(user, "already a shelf here!")
		return

	building = TRUE
	to_chat(user, span_notice("You start unfolding [src]..."))
	if(do_after(user, 5 SECONDS, target = user, progress = TRUE))
		build_turf = get_turf(user)
		if(isturf(build_turf) && !(locate(/obj/structure/crate_shelf) in build_turf) && user.temporarilyRemoveItemFromInventory(src))
			var/obj/structure/crate_shelf/shelf = new(build_turf)
			user.visible_message(
				span_notice("[user] unfolds [shelf]."),
				span_notice("You unfold [shelf]."),
			)
			shelf.add_fingerprint(user)
			qdel(src)
			return
	building = FALSE

/*
 * Crafting
 */

/datum/crafting_recipe/crate_shelf
	name = "Crate Shelf Parts"
	result = /obj/item/crate_shelf
	reqs = list(/obj/item/stack/sheet/iron = CRATE_SHELF_SHEET_COST)
	time = 4 SECONDS
	category = CAT_FURNITURE

#undef CRATE_SHELF_CAPACITY
#undef CRATE_SHELF_STACK_OFFSET
#undef CRATE_SHELF_HANDLING_TIME
#undef CRATE_SHELF_SHEET_COST
